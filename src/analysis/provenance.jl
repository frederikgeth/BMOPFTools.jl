"""
    provenance_analysis(net, findings) -> Dict{String,Any}

Detect signatures of how the dataset was produced, and make implicit
modeling assumptions explicit:

1. **Linecode impedance classification** — per linecode, classify the phase
   block of the series impedance matrix:
   - `decoupled`        — diagonal matrix: positive-sequence-only data; the
                          three phases are mathematically independent.
   - `exactly_balanced` — equal self and equal mutual entries: constructed
                          from sequence parameters (r1,x1,r0,x0) or under a
                          transposition assumption. The implied Z1/Z0 are
                          recovered and reported.
   - `near_balanced`    — balanced within 1%: possibly physical (twisted /
                          bundled symmetric cable construction).
   - `distinct`         — consistent with first-principles geometry (Carson).
   Also checks reciprocity (Z symmetric) and passivity (R block PSD).

   The **π-model topology** of every line/linecode is classified separately
   (`series` / `symmetric_pi` / `asymmetric_pi` / `gamma`) and the case study
   is audited for model consistency: a network-wide model is reported as
   uniform, a mix of topologies is flagged for review, and asymmetric-π,
   Γ-sections and modelled shunt conductance are called out individually.

2. **Wires per voltage level** — 3-wire vs 4-wire classification. A 3-wire
   LV level is flagged as likely Kron-reduced (LV is physically 4-wire);
   3-wire MV is normal. A 4-wire network whose neutrals are all perfectly
   grounded is exactly Kron-reducible (redundant variables).

3. **Neutral grounding** — builds the neutral-conductor continuity graph and
   verifies every neutral section reaches a grounding (perfect grounding,
   grounding shunt, or a source that references the neutral). Floating
   neutral sections leave the zero-sequence path undefined.

The summary string under `"convention"` states the inferred modeling
convention explicitly; renderers print it in the report.
"""
function provenance_analysis(net::Dict{String,Any},
                              findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()
    vl = voltage_level_analysis(net, Finding[])   # duplicate findings discarded
    result["linecodes"]           = _classify_linecodes(net, findings)
    result["inline_line_matrices"] = _check_inline_line_matrices(net, findings)
    result["line_models"]         = _classify_line_models(net, findings)
    result["geometry_crosscheck"] = _crosscheck_geometry_linecodes(net, findings)
    result["wires_by_level"]      = _wires_by_level(net, findings, vl)
    result["grounding"]           = _grounding_analysis(net, findings)
    _check_ungrounded_wye_neutrals(net, findings)
    result["opendss_defaults"]    = _check_opendss_defaults(net, findings,
                                                              result["linecodes"])
    result["impedance_transform"] = _classify_impedance_transformation(
                                        net, findings, result["linecodes"])
    result["earthing_zones"]      = _earthing_zones(net, vl)
    _check_regulator_patterns(net, findings, vl)
    _check_bus_shunts(net, findings)
    result["capacitor_like_shunts"]       = _check_capacitor_like_shunts(net, findings)
    result["reactor_like_shunts"]         = _check_reactor_like_shunts(net, findings)
    result["line_voltage_level_bridges"]  = _check_line_voltage_level_bridges(
                                                net, findings,
                                                get(vl, "bus_voltage_map", Dict{String,Float64}()))
    result["redundant_voltage_bounds"]    = _check_bus_voltage_bound_redundancy(net, findings)
    result["inconsistent_bounds"]         = _check_bus_voltage_bound_consistency(net, findings)
    result["inapplicable_voltage_bounds"] = _check_bus_voltage_bound_applicability(net, findings)
    result["overlapping_voltage_bounds"]  = _check_bus_voltage_bound_overlap(net, findings)
    result["voltage_source_sequence"]     = _check_voltage_source_sequence(net, findings)
    result["i_max_incomplete"]            = _check_i_max_completeness(net, findings)
    result["switch_like_lines"]           = _check_switch_like_lines(net, findings)
    result["powerio_conversion"]          = _report_powerio_conversion(net, findings)
    result["convention"]          = _convention_statement(result)
    result
end

# ---------------------------------------------------------------------------
# PowerIO conversion fidelity
# ---------------------------------------------------------------------------

"""
Report what the PowerIO conversion that produced this network could not carry.
The diagnostics were recorded at ingest by [`from_dss`](@ref) and survive a
`write_bmopf` round trip, so a case loaded from a saved BMOPF file still reports
the losses of the OpenDSS import behind it. A network that never crossed the
PowerIO boundary reports nothing.
"""
function _report_powerio_conversion(net::Dict{String,Any},
                                    findings::Vector{Finding})::Dict{String,Any}
    fs = powerio_findings(net)
    append!(findings, fs)
    count_of(f) = get(something(f.detail, Dict{String,Any}()), "count", 1)
    Dict{String,Any}(
        "n_classes"     => length(fs),
        "n_diagnostics" => sum(count_of, fs; init=0),
        "source"        => get(get(net, "_meta", Dict{String,Any}()),
                               "powerio_source", nothing),
        "by_code"       => Dict{String,Any}(f.code => count_of(f) for f in fs),
    )
end

# ---------------------------------------------------------------------------
# Convention statement
# ---------------------------------------------------------------------------

function _convention_statement(result::Dict{String,Any})::String
    parts = String[]
    wl = get(result, "wires_by_level", Dict())
    for (label, info) in sort(collect(wl), by = x -> -x[2]["nominal_v"])
        w = info["wires"]
        note = w == "3-wire" && info["is_lv"] ? " (likely Kron-reduced)" : ""
        push!(parts, "$label: $w$note")
    end

    g = get(result, "grounding", Dict())
    if get(g, "n_buses_with_neutral", 0) > 0
        conv = get(g, "convention", "")
        ng   = get(g, "n_grounding_points", 0)
        nfl  = get(g, "n_floating", 0)
        gdesc = conv == "implicit" ? "implicit (Kron-style) grounding" :
                get(g, "all_perfectly_grounded", false) ?
                    "perfectly grounded at every bus (Kron-reducible)" :
                "$(ng) grounding point(s)" * (nfl > 0 ? ", $nfl floating neutral section(s)" : "")
        push!(parts, gdesc)
    end

    get(get(result, "opendss_defaults", Dict()), "length_normalized", false) &&
        push!(parts, "length-normalized lines")

    lm = get(get(result, "line_models", Dict()), "counts", Dict())
    if !isempty(lm) && sum(values(lm)) > 0
        present = [(m, lm[m]) for m in
                   ("series", "symmetric_pi", "asymmetric_pi", "gamma")
                   if get(lm, m, 0) > 0]
        _short = Dict("series" => "series", "symmetric_pi" => "symmetric π",
                      "asymmetric_pi" => "asymmetric π", "gamma" => "Γ")
        desc = length(present) == 1 ?
            "$(_short[present[1][1]])-only line model" :
            "mixed line models (" *
            join(["$c $(_short[m])" for (m, c) in present], " + ") * ")"
        push!(parts, desc)
    end

    isempty(parts) ? "undetermined" : join(parts, "; ")
end

# ---------------------------------------------------------------------------
# Sub-module includes
# ---------------------------------------------------------------------------

include("provenance/linecodes.jl")
include("provenance/wires_grounding.jl")
include("provenance/data_quality.jl")
