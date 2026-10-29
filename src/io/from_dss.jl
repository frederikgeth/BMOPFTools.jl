# io/from_dss.jl
#
# OpenDSS → BMOPF conversion via the PowerIO.jl package
# (eigenergy/PowerIO.jl, which binds the `powerio` Rust engine in-process).

# OpenDSS numeric terminal names → task-force phase labels.
# PSK-000002: a materialized node-0 reference must remain distinct from a
# conductor neutral. PowerIO names that reference max(4, highest node + 1),
# not necessarily 5. Its grounded-terminal declaration supplies the mapping.
const _DSS_TERMINAL_MAP = Dict(
    "1" => "a", "2" => "b", "3" => "c", "4" => "n")

# Source-only metadata is inspected through the public generation-2 IR contract.
function _powerio_audit_input(module_::PowerIO.PioModule{PowerIO.MulticonductorNetwork})
    document = JSON3.read(PowerIO.serialize(module_).text)
    document.schema == "pio-ir" && document.version == 2 ||
        throw(ArgumentError("source metadata audit requires PowerIO IR generation 2"))
    document.value.type == "powerio.MulticonductorNetwork" ||
        throw(ArgumentError("source metadata audit requires a multiconductor network"))
    return (module_ = module_, network = module_.value, data = document.value.data)
end

_powerio_diagnostic_line(d) = string(d.code, ": ", d.message)

function _powerio_extras(item)
    hasproperty(item, :extras) || return nothing
    extras = getproperty(item, :extras)
    return extras isa AbstractDict ? extras : nothing
end

# Scope keys join three independent `_meta` blocks (source metadata, field
# mapping, source semantics), and the mapping derives its names from PowerIO
# warning text rather than from the objects themselves. OpenDSS names are
# case-insensitive, so every producer has to fold case the same way or the join
# silently fails and a complete mapping reads as a partial one.
_powerio_scope(kind, name) = "$(kind):$(lowercase(strip(string(name))))"

function _powerio_item_name(item, position::Integer)
    hasproperty(item, :name) && return getproperty(item, :name)
    hasproperty(item, :id) && return getproperty(item, :id)
    return position
end

_powerio_collections(dn) = (
    ("bus", dn.data.buses),
    ("linecode", dn.data.linecodes),
    ("line", dn.data.lines),
    ("switch", dn.data.switches),
    ("transformer", dn.data.transformers),
    ("load", dn.data.loads),
    ("generator", dn.data.generators),
    ("shunt", dn.data.shunts),
    ("source", dn.data.sources),
)

"""Summarize source-only `extras` fields without copying raw source values."""
function _powerio_source_metadata(dn)
    groups = Dict{String,Any}()
    all_fields = String[]
    inspected = 0
    with_extras = 0
    for (kind, collection) in _powerio_collections(dn)
        for (position, item) in enumerate(collection)
            inspected += 1
            extras = _powerio_extras(item)
            extras === nothing && continue
            with_extras += 1
            fields = sort!(unique(String[string(key) for key in keys(extras)]))
            isempty(fields) && continue
            groups[_powerio_scope(kind, _powerio_item_name(item, position))] = fields
            append!(all_fields, fields)
        end
    end
    return Dict{String,Any}(
        "source_format" => something(dn.network.source_format, "unknown"),
        "field_count" => length(unique(all_fields)),
        "fields" => sort!(unique(all_fields)),
        "by_scope" => groups,
        # `no_extras_exposed` distinguishes "the source dropped nothing" from
        # "this build of PowerIO no longer reports what it dropped".
        "extras_status" => inspected == 0 ? "no_source_objects" :
            with_extras == 0 ? "no_extras_exposed" : "available",
        "objects_inspected" => inspected,
        "objects_with_extras" => with_extras,
    )
end

function _powerio_extra(item, field::AbstractString)
    extras = _powerio_extras(item)
    extras === nothing && return nothing
    return get(extras, field, get(extras, Symbol(field), nothing))
end

# Classification of a PowerIO "has no place in the BMOPF schema" warning.
# `blocking` means the drop moves the physics or the operating point, so a
# caller must not treat the converted case as physically ready.
#
# Some drops are benign only for one element kind: BMOPF models a switch as an
# ideal closure, so the `length` and `linecode` OpenDSS carries on a
# switch-as-line have nothing left to represent, while the same fields dropped
# from a *line* would change the series impedance. Keep those keyed by
# (kind, field) so the field name alone never decides.
const _POWERIO_KIND_FIELD_POLICY = Dict(
    ("switch", "length") => (impact = "representational", blocking = false,
        reason = "switch_is_an_ideal_closure_with_no_series_impedance"),
    ("switch", "linecode") => (impact = "representational", blocking = false,
        reason = "switch_is_an_ideal_closure_with_no_series_impedance"),
)

const _POWERIO_FIELD_POLICY = Dict(
    "leadlag" => (impact = "physical_or_operating_point", blocking = true,
        reason = "source_leadlag_clock_not_verified_or_differs_from_converted_clock"),
    "units" => (impact = "representational", blocking = false,
        reason = "source_units_have_no_direct_BMOPF_field"),
    "model" => (impact = "device_semantics", blocking = true,
        reason = "source_device_model_requires_an_explicit_component_contract"),
    "vminpu" => (impact = "physical_or_operating_point", blocking = true,
        reason = "load_voltage_behavior_threshold_is_not_a_bus_voltage_bound"),
    "vmaxpu" => (impact = "physical_or_operating_point", blocking = true,
        reason = "load_voltage_behavior_threshold_is_not_a_bus_voltage_bound"),
    "angle" => (impact = "physical_or_operating_point", blocking = true,
        reason = "source_physical_metadata_requires_an_explicit_BMOPF_mapping"),
    "basekv" => (impact = "physical_or_operating_point", blocking = true,
        reason = "source_physical_metadata_requires_an_explicit_BMOPF_mapping"),
    "kv" => (impact = "physical_or_operating_point", blocking = true,
        reason = "source_physical_metadata_requires_an_explicit_BMOPF_mapping"),
    "phases" => (impact = "physical_or_operating_point", blocking = true,
        reason = "source_physical_metadata_requires_an_explicit_BMOPF_mapping"),
    "zipv" => (impact = "physical_or_operating_point", blocking = true,
        reason = "source_physical_metadata_requires_an_explicit_BMOPF_mapping"),
)

"""
Classify `field` against the scopes it was dropped from. A (kind, field) rule
applies only when *every* affected scope is of that kind; a mixed footprint
falls back to the field-level rule, and an unrecognized field stays blocking.
"""
function _powerio_mapping_policy(field::AbstractString,
                                 scopes::AbstractVector = String[])
    kinds = unique(String[first(split(scope, ":"; limit = 2)) for scope in scopes])
    policies = unique([_POWERIO_KIND_FIELD_POLICY[(kind, field)] for kind in kinds
                       if haskey(_POWERIO_KIND_FIELD_POLICY, (kind, field))])
    # One rule only if it covers every affected kind and they agree on it;
    # anything else is a mixed footprint that the field-level rule must judge.
    length(policies) == 1 && length(kinds) == 1 && return only(policies)
    haskey(_POWERIO_FIELD_POLICY, field) && return _POWERIO_FIELD_POLICY[field]
    return (impact = "unknown", blocking = true,
        reason = "source_field_has_no_classified_BMOPF_mapping")
end

function _powerio_warning_scope(message)
    _, text = _split_powerio_line(strip(String(message)))
    tokens = split(text)
    length(tokens) >= 3 || return "unknown"
    if tokens[1] == "voltage" && tokens[2] == "source"
        return _powerio_scope("source", replace(tokens[3], ":" => ""))
    end
    return _powerio_scope(tokens[1], replace(tokens[2], ":" => ""))
end

function _powerio_float(value)
    value === nothing && return nothing
    value isa Real && return isfinite(Float64(value)) ? Float64(value) : nothing
    parsed = tryparse(Float64, strip(String(value)))
    parsed === nothing || !isfinite(parsed) ? nothing : parsed
end

# OpenDSS `LeadLag` (PSK-000006). Measured with OpenDSS for two-winding,
# three-phase units (winding 2 relative to winding 1): a mixed wye/delta pair
# gives clock 1 for `lag`/`ansi` (the OpenDSS default) and clock 11 for
# `lead`/`euro`; equal connections give clock 0 for every value. Any other
# shape or value has no source clock here.
function _dss_leadlag_source_clock(conns, leadlag)
    length(conns) == 2 && all(in(("wye", "delta")), conns) || return nothing
    conns[1] == conns[2] && return 0
    leadlag in ("lag", "ansi") && return 1
    leadlag in ("lead", "euro") && return 11
    nothing
end

"""
Compare each authored OpenDSS `leadlag` against the converted transformer's
ideal phase relation. The source clock comes from the source winding
connections and `leadlag`; the target clock comes from
[`transformer_phase_relation`](@ref) on the converted model. Nothing is
repaired or permuted: a disagreement is recorded as `known_mismatch`.
"""
function _dss_leadlag_records(dn, net)
    records = Dict{String,Any}[]
    for item in dn.data.transformers
        raw = _powerio_extra(item, "leadlag")
        raw === nothing && continue
        name = lowercase(strip(string(item.name)))
        leadlag = lowercase(strip(string(raw)))
        windings = collect(item.windings)
        conns = [lowercase(string(get(w, "conn", ""))) for w in windings]
        phases = try Int(item.phases) catch; nothing end
        source_clock = phases == 3 ? _dss_leadlag_source_clock(conns, leadlag) : nothing
        record = Dict{String,Any}(
            "scope" => _powerio_scope("transformer", name),
            "leadlag" => leadlag, "source_connections" => conns,
            "source_clock" => source_clock, "target_clock" => nothing,
            "target_subtype" => nothing,
            "representation" => "retained_source_only",
            "knowledge_ids" => ["PSK-000006"])
        push!(records, record)
        if phases == 3 && length(conns) == 2 && conns[1] == conns[2] && source_clock == 0
            record["status"] = "not_applicable"
            record["reason"] = "leadlag_has_no_effect_on_equal_winding_connections"
            continue
        end
        if source_clock === nothing
            record["status"] = "indeterminate"
            record["reason"] = leadlag in ("lag", "ansi", "lead", "euro") ?
                "transformer_shape_outside_measured_leadlag_domain" : "unrecognized_leadlag_value"
            continue
        end
        target = nothing
        for (subtype, group) in get(net, "transformer", Dict())
            group isa AbstractDict && haskey(group, name) && (target = (subtype, group[name]))
        end
        source_bus1 = lowercase(string(get(windings[1], "bus", "")))
        if target === nothing || !(target[2] isa AbstractDict) ||
           lowercase(string(get(target[2], "bus_from", ""))) != source_bus1
            record["status"] = "indeterminate"
            record["reason"] = "converted_transformer_or_winding_order_not_identified"
            continue
        end
        record["target_subtype"] = target[1]
        relation = transformer_phase_relation(net, target[1], target[2])
        record["target_clock"] = relation["clock"]
        if relation["status"] != "known"
            record["status"] = "indeterminate"
            record["reason"] = "converted_phase_relation_" * string(relation["status"])
        elseif relation["clock"] == source_clock
            record["status"] = "verified"
            record["reason"] = "converted_clock_matches_source_leadlag"
        else
            record["status"] = "known_mismatch"
            record["reason"] = "converted_clock_differs_from_source_leadlag"
        end
    end
    records
end

"""Retain normalized source semantics that have no active BMOPF field."""
function _powerio_source_semantics(dn; leadlag_records=Dict{String,Any}[])
    transformer_phase = deepcopy(leadlag_records)
    load_thresholds = Dict{String,Any}[]
    for item in dn.data.loads
        law = hasproperty(item, :voltage_model) ? item.voltage_model : nothing
        typed = law isa AbstractDict && get(law, "model", "") in ("bounded_zip", "bounded_exponential")
        vmin = _powerio_float(typed ? get(law, "v_min_pu", nothing) : _powerio_extra(item, "vminpu"))
        vmax = _powerio_float(typed ? get(law, "v_max_pu", nothing) : _powerio_extra(item, "vmaxpu"))
        (vmin === nothing && vmax === nothing) && continue
        status = if vmin !== nothing && vmax !== nothing && vmin <= vmax
            "observed_ordered"
        elseif vmin === nothing || vmax === nothing
            "observed_incomplete"
        else
            "observed_inverted"
        end
        push!(load_thresholds, Dict{String,Any}(
            "scope" => _powerio_scope("load", getproperty(item, :name)),
            "vminpu" => vmin,
            "vmaxpu" => vmax,
            "origin" => typed ? "powerio_typed_voltage_model" : "source_extras",
            "typed_voltage_model" => typed ? JSON3.read(JSON3.write(law), Dict{String,Any}) : nothing,
            "status" => status,
            "interpretation" => "load_voltage_behavior_threshold_not_bus_bound",
        ))
    end
    source_models = Dict{String,Any}[]
    for item in dn.data.sources
        raw_model = _powerio_extra(item, "model")
        raw_model === nothing && continue
        model = lowercase(strip(string(raw_model)))
        push!(source_models, Dict{String,Any}(
            "scope" => _powerio_scope("source", getproperty(item, :name)),
            "model" => model,
            "status" => model == "ideal" ?
                "represented_as_fixed_voltage_boundary" : "unmapped_source_model",
            "target" => model == "ideal" ?
                "voltage_source.v_magnitude/v_angle" : "unmapped",
        ))
    end
    return Dict{String,Any}(
        "transformer_phase_relations" => transformer_phase,
        "load_voltage_thresholds" => load_thresholds,
        "voltage_source_models" => source_models,
    )
end

"""
    powerio_source_behavior_contract(net; plan_auxiliary_constraints = false)

Return the explicit, non-mutating contract for source-side voltage-behavior
metadata retained by `from_dss`. OpenDSS `vminpu`/`vmaxpu` values describe a
load law's voltage-behavior domain; they are not silently promoted to BMOPF
bus bounds. The returned records expose enough topology and nominal-voltage
context for a caller or domain plugin to construct an auxiliary diagnostic
problem deliberately.

When `plan_auxiliary_constraints=true`, the same records are returned as
candidate terminal-voltage-ratio constraints. This is a plan only: no JuMP or
BMOPF model is modified and no constraint is active in the original model.
"""
function powerio_source_behavior_contract(
    net::AbstractDict;
    plan_auxiliary_constraints::Bool = false,
)
    meta = get(net, "_meta", get(net, :_meta, Dict{Any,Any}()))
    meta isa AbstractDict || (meta = Dict{Any,Any}())
    semantics = get(meta, "powerio_source_semantics",
                    get(meta, :powerio_source_semantics, Dict{Any,Any}()))
    semantics isa AbstractDict || (semantics = Dict{Any,Any}())
    raw_thresholds = get(semantics, "load_voltage_thresholds",
                         get(semantics, :load_voltage_thresholds, Any[]))
    thresholds = raw_thresholds isa AbstractVector ? raw_thresholds : Any[]
    loads = get(net, "load", get(net, :load, Dict{Any,Any}()))
    loads isa AbstractDict || (loads = Dict{Any,Any}())
    observations = Dict{String,Any}[]
    candidates = Dict{String,Any}[]
    eligible_count = 0
    for raw in thresholds
        raw isa AbstractDict || continue
        scope = string(get(raw, "scope", get(raw, :scope, "")))
        parts = split(scope, ":"; limit = 2)
        load_id = length(parts) == 2 ? lowercase(strip(parts[2])) : ""
        load = get(loads, load_id, get(loads, Symbol(load_id), nothing))
        load = load isa AbstractDict ? load : Dict{Any,Any}()
        status = string(get(raw, "status", get(raw, :status, "unknown")))
        vmin = get(raw, "vminpu", get(raw, :vminpu, nothing))
        vmax = get(raw, "vmaxpu", get(raw, :vmaxpu, nothing))
        bus = get(load, "bus", get(load, :bus, nothing))
        terminal_map = get(load, "terminal_map", get(load, :terminal_map, Any[]))
        nominal_voltage = get(load, "v_nom", get(load, :v_nom, Any[]))
        ordered = status == "observed_ordered" && bus !== nothing &&
            terminal_map isa AbstractVector && !isempty(terminal_map) &&
            nominal_voltage isa AbstractVector && !isempty(nominal_voltage)
        ordered && (eligible_count += 1)
        observation = Dict{String,Any}(
            "scope" => scope,
            "load" => load_id,
            "bus" => bus,
            "terminal_map" => terminal_map,
            "nominal_voltage" => nominal_voltage,
            "vminpu" => vmin,
            "vmaxpu" => vmax,
            "status" => status,
            "interpretation" => "load_voltage_behavior_threshold_not_bus_bound",
            "constraint_candidate_status" => ordered ?
                "eligible_terminal_voltage_ratio_candidate" :
                "requires_load_and_terminal_alignment",
        )
        push!(observations, observation)
        plan_auxiliary_constraints || continue
        push!(candidates, Dict{String,Any}(
            "scope" => scope,
            "load" => load_id,
            "bus" => bus,
            "terminal_map" => terminal_map,
            "nominal_voltage" => nominal_voltage,
            "vminpu" => vmin,
            "vmaxpu" => vmax,
            "status" => ordered ? "candidate" : "not_ready",
            "constraint_family" => "load_terminal_voltage_ratio_bounds",
            "constraint_form" => "vminpu <= abs(V_terminal) / v_nom <= vmaxpu",
            "active_in_original_model" => false,
            "materialization" => "not_materialized",
        ))
    end
    source_models = get(semantics, "voltage_source_models",
                         get(semantics, :voltage_source_models, Any[]))
    source_models = source_models isa AbstractVector ? source_models : Any[]
    return Dict{String,Any}(
        "contract_version" => "powerio_source_behavior/v1",
        "mutation_policy" => "non_mutating",
        "constraint_policy" => plan_auxiliary_constraints ?
            "candidate_plan" : "observation_only",
        "source_semantics_available" => !isempty(observations) || !isempty(source_models),
        "active_constraints_added" => false,
        "load_voltage_behavior" => observations,
        "auxiliary_constraint_candidates" => candidates,
        "threshold_observation_count" => length(observations),
        "eligible_candidate_count" => eligible_count,
        "voltage_source_models" => source_models,
    )
end

"""
Demonstrate that an OpenDSS load `pf` actually reached the converted load, by
reproducing it: BMOPF carries no power factor, so the only evidence that `pf`
was honoured is `q_nom` standing in the ratio `pf` prescribes to `p_nom`. A
weaker "both vectors are finite" test would be satisfied by every converted
load whether or not `pf` was read, which is exactly the silent fidelity gap the
ledger exists to rule out. Magnitudes only: the lead/lag sign convention is the
parser's, and a sign flip is not evidence that `pf` was ignored.
"""
function _powerio_pf_is_demonstrated(raw_pf, converted::AbstractDict)::Bool
    pf = _powerio_float(raw_pf)
    (pf === nothing || abs(pf) > 1.0) && return false
    p_nom = get(converted, "p_nom", nothing)
    q_nom = get(converted, "q_nom", nothing)
    (p_nom isa AbstractVector && q_nom isa AbstractVector) || return false
    (isempty(p_nom) || length(p_nom) != length(q_nom)) && return false
    tan_phi = tan(acos(abs(pf)))
    for (p_raw, q_raw) in zip(p_nom, q_nom)
        p = _powerio_float(p_raw)
        q = _powerio_float(q_raw)
        (p === nothing || q === nothing) && return false
        expected = abs(p) * tan_phi
        isapprox(abs(q), expected; rtol = 1e-6, atol = 1e-6 * (1.0 + abs(p))) ||
            return false
    end
    return true
end

# Validate static CVR emission (#333) and reconstruct source-declared winding
# resistance (#356) from PowerIO's public IR. Neither changes BMOPF JSON intake.
function _restore_dss_intake_fidelity!(net, dn)
    repairs = Dict{String,Any}[]
    for item in dn.data.loads
        _powerio_float(_powerio_extra(item, "model")) == 4.0 || continue
        name = lowercase(string(item.name))
        load = get(get(net, "load", Dict()), name, nothing)
        load isa AbstractDict || throw(ArgumentError("DSS CVR load $name has no explicit target"))
        curve = _powerio_extra(item, "cvrcurve")
        (curve === nothing || lowercase(strip(string(curve))) in ("", "none")) ||
            throw(ArgumentError("DSS CVR load $name has a time-varying CVRcurve; a static exponential import is inapplicable"))
        # PowerIO 0.11.7 carries CVR exponents in the typed voltage law and
        # emits them correctly. Validate the explicit source-to-load mapping;
        # never replace a typed exponent with a default from absent extras.
        law = hasproperty(item, :voltage_model) ? item.voltage_model : nothing
        law isa AbstractDict && get(law, "model", "") in ("exponential", "bounded_exponential") ||
            throw(ArgumentError("DSS CVR load $name lacks a typed static exponential law"))
        count = length(get(load, "p_nom", []))
        vnom = get(load, "v_nom", [])
        count > 0 && length(get(load, "q_nom", [])) == count &&
            vnom isa AbstractVector && length(vnom) == count &&
            all(v -> v isa Real && isfinite(v) && v > 0, vnom) ||
            throw(ArgumentError("DSS CVR load $name lacks aligned powers and positive nominal coil voltages"))
        get(load, "model", "") == "exponential" ||
            throw(ArgumentError("DSS CVR load $name was not emitted as exponential"))
        for field in ("gamma_p", "gamma_q")
            values = get(law, field, nothing)
            values isa AbstractVector && length(values) == count &&
                all(v -> v isa Real && isfinite(v), values) ||
                throw(ArgumentError("DSS CVR load $name has invalid typed $field"))
            get(load, field, nothing) == values ||
                throw(ArgumentError("DSS CVR load $name lost its typed $field on emission"))
        end
    end
    targets = get(get(net, "transformer", Dict()), "n_winding", Dict())
    for item in dn.data.transformers
        name = lowercase(string(item.name))
        target = get(targets, name, nothing)
        target isa AbstractDict || continue
        source = item.windings; windings = get(target, "windings", [])
        length(source) == length(windings) ||
            throw(ArgumentError("DSS transformer $name winding correspondence is incomplete"))
        phases = Int(item.phases)
        phases in (1,3) || throw(ArgumentError("DSS transformer $name resistance recovery supports one or three phases"))
        base = Float64(source[1].s_rating)
        isfinite(base) && base > 0 || throw(ArgumentError("DSS transformer $name has no positive first-winding power base"))
        for (k, (sw, tw)) in enumerate(zip(source, windings))
            # Winding array order and bus identity are explicit source mappings.
            lowercase(string(sw.bus)) == tw["bus"] ||
                throw(ArgumentError("DSS transformer $name winding $k bus correspondence is ambiguous"))
            conn = lowercase(string(sw.conn))
            conn in ("wye", "delta") || throw(ArgumentError("Unsupported DSS winding connection $conn"))
            voltage = Float64(sw.v_ref)
            coil = phases == 3 && conn == "wye" ? voltage / sqrt(3) : voltage
            percent = Float64(sw.r_pct)
            isfinite(coil) && coil > 0 && isfinite(percent) && percent >= 0 ||
                throw(ArgumentError("Invalid DSS winding voltage or resistance on $name winding $k"))
            resistance = percent / 100 * phases * coil^2 / base
            isfinite(resistance) || throw(ArgumentError("DSS winding resistance overflows on $name winding $k"))
            old = get(tw, "r_winding", nothing)
            if old === nothing || !isapprox(old, resistance; rtol=1e-12, atol=0)
                tw["r_winding"] = resistance
                push!(repairs, Dict("component"=>"transformer.n_winding.$name", "winding"=>k,
                    "rule"=>"dss_resistance_first_winding_power_base", "source_r_pct"=>percent,
                    "source_coil_voltage_V"=>coil, "source_power_base_VA"=>base,
                    "emitted_ohm"=>old, "restored_ohm"=>resistance))
            end
        end
    end
    isempty(repairs) || (get!(net, "_meta", Dict{String,Any}())["powerio_intake_repairs"] = repairs)
    net
end

"""Record source fields that are demonstrably represented by BMOPF fields."""
function _powerio_bmopf_field_mapping(dn, net; diagnostics=nothing,
                                      leadlag_records=Dict{String,Any}[])
    by_field = Dict{String,Any}()
    # leadlag counts as represented only where the converted clock was checked
    # against the source clock (or leadlag cannot act on the connection pair).
    leadlag_scopes = String[r["scope"] for r in leadlag_records
                            if r["status"] in ("verified", "not_applicable")]
    isempty(leadlag_scopes) || (by_field["leadlag"] = Dict{String,Any}(
        "status" => "mapped_with_verification",
        "target" => "transformer winding incidence (ideal clock)",
        "transform" => "opendss_leadlag_checked_against_converted_clock",
        "mapped_scopes" => sort!(unique(leadlag_scopes)),
        "knowledge_ids" => ["PSK-000006"]))
    load_net = get(net, "load", Dict{String,Any}())
    for (field, target, transform) in (
        ("kv", "load.v_nom", "kV_to_volts"),
        ("phases", "load.terminal_map/configuration", "source_phase_count_to_terminal_structure"),
        # PowerIO 0.9 drops `pf` from the BMOPF output (BMOPF has no power
        # factor field), so without a record here it would be classified by the
        # catch-all "unrecognized field stays blocking" rule — even though the
        # information is fully carried, as q_nom.
        ("pf", "load.p_nom/q_nom", "active_power_and_power_factor_to_reactive_power"),
    )
        scopes = String[]
        for item in dn.data.loads
            raw = _powerio_extra(item, field)
            raw === nothing && continue
            name = lowercase(string(getproperty(item, :name)))
            converted = get(load_net, name, nothing)
            converted isa AbstractDict || continue
            if field == "kv"
                haskey(converted, "v_nom") || continue
                vals = converted["v_nom"]
                vals isa AbstractVector && !isempty(vals) || continue
                all(value -> value isa Real && isfinite(Float64(value)), vals) || continue
            elseif field == "phases"
                haskey(converted, "terminal_map") && haskey(converted, "configuration") || continue
            else
                _powerio_pf_is_demonstrated(raw, converted) || continue
            end
            push!(scopes, _powerio_scope("load", name))
        end
        isempty(scopes) || (by_field[field] = Dict{String,Any}(
            "status" => "mapped",
            "target" => target,
            "transform" => transform,
            "mapped_scopes" => sort!(unique(scopes)),
        ))
    end
    # OpenDSS vminpu/vmaxpu are load-law validity/behavior thresholds, not
    # network-wide voltage bounds. Preserve them through the explicit source
    # behavior contract instead of either dropping them or silently adding
    # constraints to the production BMOPF model.
    for field in ("vminpu", "vmaxpu")
        scopes = String[]
        for item in dn.data.loads
            _powerio_float(_powerio_extra(item, field)) === nothing && continue
            name = lowercase(string(getproperty(item, :name)))
            converted = get(load_net, name, nothing)
            converted isa AbstractDict || continue
            push!(scopes, _powerio_scope("load", name))
        end
        isempty(scopes) || (by_field[field] = Dict{String,Any}(
            "status" => "mapped_with_contract",
            "target" => "_meta.powerio_source_semantics.load_voltage_thresholds",
            "transform" => "source_load_voltage_behavior_threshold_contract",
            "mapped_scopes" => sort!(unique(scopes)),
            "impact" => "physical_or_operating_point",
            "physical_readiness_blocking" => false,
            "reason" => "preserved_as_load_behavior_contract_not_bus_voltage_bound",
            "active_in_original_model" => false,
        ))
    end
    for (field, target, transform) in (
        ("model", "load.model", "opendss_load_model_to_bmopf_model"),
        ("cvrwatts", "load.gamma_p", "dss_static_cvr_active_exponent"),
        ("cvrvars", "load.gamma_q", "dss_static_cvr_reactive_exponent"),
        ("zipv", "load.model/alpha_z/alpha_i/alpha_p/beta_z/beta_i/beta_p",
            "opendss_zipv_to_bmopf_zip_parameters"),
    )
        scopes = String[]
        for item in dn.data.loads
            _powerio_extra(item, field) === nothing && continue
            name = lowercase(string(getproperty(item, :name)))
            converted = get(load_net, name, nothing)
            converted isa AbstractDict || continue
            if field == "model"
                model = lowercase(string(get(converted, "model", "")))
                model in ("constant_power", "constant_current", "constant_impedance", "zip", "exponential") || continue
                _powerio_float(_powerio_extra(item, "model")) == 4.0 && model != "exponential" && continue
            elseif field in ("cvrwatts", "cvrvars")
                get(converted, "model", "") == "exponential" || continue
                key = field == "cvrwatts" ? "gamma_p" : "gamma_q"
                all(==(_powerio_float(_powerio_extra(item, field))), get(converted, key, [])) || continue
            else
                lowercase(string(get(converted, "model", ""))) == "zip" || continue
                all(haskey(converted, key) for key in
                    ("alpha_z", "alpha_i", "alpha_p", "beta_z", "beta_i", "beta_p")) || continue
            end
            push!(scopes, _powerio_scope("load", name))
        end
        isempty(scopes) || (by_field[field] = Dict{String,Any}(
            "status" => "mapped",
            "target" => target,
            "transform" => transform,
            "mapped_scopes" => sort!(unique(scopes)),
        ))
    end
    source_net = get(net, "voltage_source", Dict{String,Any}())
    source_net isa AbstractDict || (source_net = Dict{String,Any}())
    source_model_scopes = String[]
    for item in dn.data.sources
        lowercase(string(_powerio_extra(item, "model"))) == "ideal" || continue
        name = lowercase(string(getproperty(item, :name)))
        converted = get(source_net, name, nothing)
        converted isa AbstractDict || continue
        values = (get(converted, "v_magnitude", nothing), get(converted, "v_angle", nothing))
        all(value -> value isa AbstractVector && !isempty(value) &&
            all(entry -> entry isa Real && isfinite(Float64(entry)), value), values) || continue
        push!(source_model_scopes, _powerio_scope("source", name))
    end
    if !isempty(source_model_scopes)
        if haskey(by_field, "model")
            entry = by_field["model"]
            entry["status"] = "mapped_with_contract"
            entry["target"] *= ";voltage_source.v_magnitude/v_angle"
            entry["transform"] *= ";source_model_ideal_to_fixed_voltage_boundary"
            entry["mapped_scopes"] =
                sort!(unique(vcat(entry["mapped_scopes"], source_model_scopes)))
        else
            by_field["model"] = Dict{String,Any}(
                "status" => "mapped_with_contract",
                "target" => "voltage_source.v_magnitude/v_angle",
                "transform" => "source_model_ideal_to_fixed_voltage_boundary",
                "mapped_scopes" => sort!(unique(source_model_scopes)),
            )
        end
    end
    for (field, target, transform) in (
        ("angle", "voltage_source.v_angle", "source_angle_with_phase_sequence"),
        ("basekv", "voltage_source.v_magnitude", "line_to_neutral_voltage_conversion"),
    )
        scopes = String[]
        for item in dn.data.sources
            _powerio_extra(item, field) === nothing && continue
            name = lowercase(string(getproperty(item, :name)))
            converted = get(source_net, name, nothing)
            converted isa AbstractDict || continue
            target_key = field == "angle" ? "v_angle" : "v_magnitude"
            values = get(converted, target_key, nothing)
            values isa AbstractVector && !isempty(values) || continue
            all(value -> value isa Real && isfinite(Float64(value)), values) || continue
            push!(scopes, _powerio_scope("source", name))
        end
        isempty(scopes) || (by_field[field] = Dict{String,Any}(
            "status" => "mapped_with_transform",
            "target" => target,
            "transform" => transform,
            "mapped_scopes" => sort!(unique(scopes)),
        ))
    end
    # Every conversion warning gets a ledger entry, including fields that are
    # intentionally not represented. This prevents the absence of a mapping
    # record from being mistaken for a completed mapping.
    meta = get(net, "_meta", Dict{String,Any}())
    warnings = meta isa AbstractDict ? get(meta, "powerio_warnings", Any[]) : Any[]
    warnings isa AbstractVector || (warnings = Any[warnings])
    warning_scopes = Dict{String,Vector{String}}()
    unclassified = String[]
    truncated = false
    for (position, message) in enumerate(warnings)
        text = String(message)
        diagnostic = diagnostics !== nothing && position <= length(diagnostics) ?
            diagnostics[position] : nothing
        details = diagnostic !== nothing && hasproperty(diagnostic, :details) ?
            diagnostic.details : nothing
        if diagnostic !== nothing && diagnostic.code == "EMIT.BMOPF.FIELD_DROPPED" &&
           details isa AbstractDict && haskey(details, "field")
            field = String(details["field"])
            elements = get(details, "elements", Any[])
            scopes = get!(warning_scopes, field, String[])
            for element in elements
                # Element locators precede the colon in single-element messages.
                push!(scopes, _powerio_warning_scope(string(element, ": field")))
            end
            incomplete = get(details, "elements_truncated", false) ||
                get(details, "count", length(elements)) != length(elements)
            if incomplete || isempty(elements)
                truncated = true
                push!(scopes, "unknown:unattributed")
            end
            continue
        end
        if diagnostic !== nothing && diagnostic.code == "EMIT.BMOPF.TRANSFORMER_EXTRA_DROPPED" &&
           details isa AbstractDict && haskey(details,"field")
            field = String(details["field"])
            scope = _powerio_warning_scope(text)
            push!(get!(warning_scopes,field,String[]),scope)
            continue
        end
        if diagnostic !== nothing && diagnostic.code != "EMIT.BMOPF.FIELD_DROPPED"
            push!(unclassified, text)
            continue
        end
        if occursin("warning list truncated at", text)
            truncated = true
            continue
        end
        match_result = match(r"`([^`]+)`", text)
        if isnothing(match_result)
            push!(unclassified, text)
            continue
        end
        field = String(match_result.captures[1])
        push!(get!(warning_scopes, field, String[]), _powerio_warning_scope(text))
    end
    classified = length(warnings) - length(unclassified) -
        count(message -> occursin("warning list truncated at", String(message)), warnings)
    # A ledger that cannot read all of its own input must not present an empty
    # `unmapped_fields`: that is indistinguishable from a clean conversion. The
    # warning text comes from PowerIO, so both a truncated list and a reformatted
    # message have to surface as a status here, not as silently perfect fidelity.
    warning_status = truncated ? "truncated_upstream" :
        isempty(warnings) ? "no_warnings" :
        classified == 0 ? "unrecognized_warning_format" :
        isempty(unclassified) ? "parsed" : "partially_classified"
    if warning_status in ("truncated_upstream", "unrecognized_warning_format")
        @warn "from_dss: the source field ledger on " *
              "net[\"_meta\"][\"powerio_source_mapping\"] is incomplete " *
              "($(warning_status)); its unmapped_fields under-reports what the " *
              "conversion dropped and must not be read as a fidelity proof"
    end

    unmapped_fields = String[]
    blocking_unmapped_fields = String[]
    # Reconcile the demonstrated mapping against the source footprint. Every
    # record ends up with the same keys, so a consumer never has to know
    # whether a warning happened to fire for the field it is reading:
    #   mapped_scopes   where the mapping was demonstrated on the output
    #   warned_scopes   where the source carried the field and PowerIO dropped it
    #   unmapped_scopes warned minus mapped — the actual fidelity gap
    #   scopes          the union: the field's full source footprint
    for field in sort!(union(collect(keys(by_field)), collect(keys(warning_scopes))))
        entry = get!(by_field, field) do
            Dict{String,Any}(
                "status" => "unmapped",
                "target" => "unmapped",
                "transform" => "none",
                "mapped_scopes" => String[],
            )
        end
        mapped_scopes = sort!(unique(String[string(scope) for scope in
            get(entry, "mapped_scopes", String[])]))
        warned_scopes = sort!(unique(get(warning_scopes, field, String[])))
        missing_scopes = sort!(setdiff(warned_scopes, mapped_scopes))
        entry["mapped_scopes"] = mapped_scopes
        entry["warned_scopes"] = warned_scopes
        entry["unmapped_scopes"] = missing_scopes
        entry["scopes"] = sort!(union(mapped_scopes, warned_scopes))
        entry["scope_count"] = length(entry["scopes"])
        if isempty(missing_scopes)
            # Contract-backed records carry their own classification; only fill
            # in the ones that have none.
            get!(entry, "impact", "represented")
            get!(entry, "physical_readiness_blocking", false)
            get!(entry, "reason", "mapping_covers_every_source_scope")
            continue
        end
        policy = _powerio_mapping_policy(field, missing_scopes)
        entry["status"] = isempty(mapped_scopes) ? "unmapped" : "partially_mapped"
        entry["impact"] = policy.impact
        entry["physical_readiness_blocking"] = policy.blocking
        entry["reason"] = isempty(mapped_scopes) ? policy.reason :
            "mapping_covers_some_source_scopes_but_not_all"
        push!(unmapped_fields, field)
        policy.blocking && push!(blocking_unmapped_fields, field)
    end
    fields = sort!(collect(keys(by_field)))
    mapped_fields = sort!([field for field in fields if
        get(get(by_field, field, Dict()), "status", "unmapped") in
            ("mapped", "mapped_with_transform", "mapped_with_contract",
             "mapped_with_verification")])
    return Dict{String,Any}(
        "fields" => mapped_fields,
        "unmapped_fields" => unmapped_fields,
        "blocking_unmapped_fields" => blocking_unmapped_fields,
        # A caller gating on `blocking_unmapped_fields` must read these too:
        # they say whether the field ledger saw the whole warning list.
        "warning_status" => warning_status,
        "warnings_seen" => length(warnings),
        "warnings_classified" => classified,
        "warnings_truncated_upstream" => truncated,
        "unclassified_warnings" => unclassified,
        "by_field" => by_field,
    )
end

"""
    from_dss(path::AbstractString; name=nothing) -> Dict{String,Any}

Parse an OpenDSS Master file directly to a BMOPF network dict using
[PowerIO.jl](https://github.com/eigenergy/PowerIO.jl).

This is the recommended path for reading OpenDSS networks: the Rust parser
(bound in-process by PowerIO.jl) parses a typed module and explicitly emits the
BMOPF 0.1.0 profile with diagnosed extension relocations. Conversion diagnostics remain separate from
schema validation and numerical validation against OpenDSS. Source metadata
is read through a generation-2 PowerIO IR snapshot for the conversion audit.

OpenDSS identifiers are case-insensitive but case-preserving, whereas BMOPF
keys are matched exactly. To reconcile the two, every identifier and every
reference to one (bus names, linecodes, component ids) is **case-folded to
lower case** on ingest, so references resolve regardless of the casing each
OpenDSS statement happened to use.

OpenDSS numeric terminal names (`"1"`, `"2"`, `"3"`, `"4"`) are remapped to
the task-force convention (`"a"`, `"b"`, `"c"`, `"n"`). Materialized node-0
returns remain distinct as perfectly grounded `"n_ref"` terminals; per-bus
`neutral_terminal` prefers the conductor neutral `"n"` when both are present.

# Arguments
- `path`: path to the OpenDSS Master.dss file (or any .dss entry point)
- `name`: optional network name string set on `net["name"]` after parsing.
  Defaults to the relative path of the Master file from the working directory.
- `frequency`: optional system frequency [Hz] override. By default the base
  frequency PowerIO parsed from the DSS circuit (`Set DefaultBaseFreq`, which
  itself defaults to 60 Hz in OpenDSS) is captured into `net["meta"]["frequency"]`.
  Pass this to override it — e.g. when the source file relied on a base
  frequency the deck never stated, or you know the intended value. The chosen
  value and its source (`"powerio"` or `"override"`) are recorded on
  `net["_meta"]["frequency_source"]`. The frequency is **never** used to
  rescale impedances (there is no OpenDSS-style base-frequency scaling in
  BMOPF); it is metadata that makes the case self-contained and feeds the
  cross-object consistency checks (`W.DOM.FREQUENCY_MISMATCH`).

- `findings`: optional `Vector{Finding}` to append the conversion's findings to
  (the same pattern the analysis passes follow). The findings are recorded on
  the network on success. A wrapped PowerIO failure appends available reader
  and failure diagnostic classes once before throwing, preserving existing
  entries. Failure Findings include the source path, conversion stage, and
  ungrouped upstream evidence; missing component targets are not inferred from
  message text. No entries are fabricated when PowerIO supplies no diagnostics.

# Conversion findings
PowerIO reports every piece of information that cannot be represented in BMOPF
JSON (e.g. shunt admittance, load shape time series, RegControl OLTC taps).
Two views of the same list are recorded on the returned dict:

- `_meta["powerio_warnings"]` — every diagnostic verbatim, as its
  `CODE: message` line, untruncated and ungrouped.
- `_meta["powerio_diagnostics"]` — the same diagnostics folded into one record
  per `(code, severity, component type)` class, which
  [`powerio_findings`](@ref) reads back as [`Finding`](@ref)s and
  [`analyze`](@ref) reports alongside every other finding.

# Errors
- [`DSSConversionError`](@ref) if PowerIO raises `PowerIOError` during parsing
  or BMOPF emission. The original exception is `err.cause`; its stable code,
  message and failure diagnostics are unchanged. Reader diagnostics captured
  before emission are retained separately. For unresolved geometry,
  `err.cause.code == "BUILD.DIST.ELECTRICAL_INCOMPLETE"`. No partial or
  substituted-impedance network is returned.
- `ArgumentError` if the DSS file does not exist.
- `ErrorException` if PowerIO produces no output (parse failure or schema error).
Other exceptions, including package audit/normalization errors, propagate
unchanged; the wrapper is limited to the named PowerIO parse/emit boundaries.

# Example
```julia
net = from_dss(joinpath(pkgdir(BMOPFTools), "test", "data", "pf_comparison", "pf_1ph_line.dss"))
report = analyze(net)
render(report, stdout)
```
"""
function from_dss(path::AbstractString;
                  name::Union{AbstractString,Nothing}=nothing,
                  frequency::Union{Real,Nothing}=nothing,
                  findings::Union{Vector{Finding},Nothing}=nothing)::Dict{String,Any}

    abspath_dss = abspath(path)
    isfile(abspath_dss) || throw(ArgumentError("DSS file not found: $abspath_dss"))

    # PowerIO parses to a MulticonductorNetwork handle, then emits BMOPF JSON
    # plus a list of fidelity-loss warnings.
    module_ = _with_dss_conversion_evidence(
        () -> PowerIO.parse(abspath_dss), abspath_dss, :parse; findings)
    module_ isa PowerIO.PioModule{PowerIO.MulticonductorNetwork} ||
        throw(ArgumentError("OpenDSS input must contain a multiconductor network"))
    dn = _powerio_audit_input(module_)
    emission = _with_dss_conversion_evidence(
        () -> PowerIO.emit(module_, "bmopf-json@0.1.0"), abspath_dss, :emit,
        module_.diagnostics; findings)
    json_raw = emission.text
    diagnostics = vcat(module_.diagnostics, emission.diagnostics)
    warnings_list = _powerio_diagnostic_line.(diagnostics)

    if isempty(json_raw)
        throw(ErrorException("PowerIO produced no output for $path"))
    end

    net = parse_bmopf(json_raw; from_string=true)
    _canonicalize_identifiers!(net)
    _remap_opendss_terminals!(net; grounded_references=Dict(
        lowercase(string(b.id)) => String.(b.grounded) for b in dn.data.buses))
    _normalize_transformer_no_load_shunts!(net, dn)
    _restore_dss_intake_fidelity!(net, dn)

    # n_ref is a perfectly grounded winding/source return, not a physical
    # earth wire. It remains separate from the conductor neutral n.
    # from_dss knows the mapping it just applied, so this is declared
    # rather than left to be inferred downstream (W.CONV.TERMINAL_ROLES_INFERRED).
    # PowerIO's own BMOPF export already carries a `terminal_conventions` block
    # keyed to ITS pre-remap numeric terminal names (e.g. phase=["1","2","4"],
    # neutral=[]) — stale the instant `_remap_opendss_terminals!` renames every
    # terminal to a/b/c/n. Discard it before recomputing, or `_terminal_roles`
    # treats the stale numeric block as authoritative (`get!` never overwrites an
    # existing key) and every a/b/c/n bus resolves to an empty neutral set.
    delete!(net, "terminal_conventions")
    net["terminal_conventions"] = _terminal_conventions_dict(net)

    # Record the conversion's fidelity losses both ways: verbatim lines for
    # provenance, and the diagnostic records that `powerio_findings` reads back
    # as Findings. Identifiers are folded to lower case above, so the records
    # name their components the way the rest of the dict does.
    net["_meta"] = get(net, "_meta", Dict{String,Any}())
    net["_meta"]["powerio_warnings"] = collect(String, warnings_list)
    net["_meta"]["powerio_diagnostic_details"] =
        _powerio_diagnostic_to_dict.(diagnostics)
    net["_meta"]["powerio_diagnostics"] =
        _powerio_diagnostic_records(diagnostics; fold_ids=true)
    net["_meta"]["powerio_source"]   = abspath_dss
    net["_meta"]["powerio_source_metadata"] = _powerio_source_metadata(dn)
    leadlag_records = _dss_leadlag_records(dn, net)
    source_mapping = _powerio_bmopf_field_mapping(dn, net; diagnostics=diagnostics,
                                                  leadlag_records=leadlag_records)
    net["_meta"]["powerio_source_mapped_fields"] = source_mapping["fields"]
    net["_meta"]["powerio_source_mapping"] = source_mapping
    net["_meta"]["powerio_source_semantics"] = _powerio_source_semantics(dn; leadlag_records=leadlag_records)
    findings === nothing || append!(findings, powerio_findings(net))

    # Capture the system frequency PowerIO parsed from the DSS circuit
    # (OpenDSS `Set DefaultBaseFreq`, itself defaulting to 60 Hz), or the
    # caller's override. OpenDSS files carry no explicit frequency very
    # often, so preserving it here keeps the case self-contained. Never used
    # to rescale — it is metadata that also feeds the frequency-consistency
    # checks. If PowerIO cannot report a base frequency, fall back silently
    # to the override or leave meta.frequency unset.
    f_powerio = try
        Float64(dn.network.base_frequency)
    catch
        nothing
    end
    f_chosen = frequency !== nothing ? Float64(frequency) : f_powerio
    if f_chosen !== nothing && f_chosen > 0
        meta = get!(net, "meta", Dict{String,Any}())
        meta["frequency"] = f_chosen
        net["_meta"]["frequency_source"] =
            frequency !== nothing ? "override" : "powerio"
        if frequency !== nothing && f_powerio !== nothing &&
           !isapprox(f_chosen, f_powerio; rtol=1e-9)
            net["_meta"]["frequency_powerio"] = f_powerio
            @warn "from_dss: overriding the parsed base frequency " *
                  "($(f_powerio) Hz) with $(f_chosen) Hz. Impedances are NOT " *
                  "rescaled — ensure the source matrices correspond to " *
                  "$(f_chosen) Hz."
        end
    end
    if !isempty(warnings_list)
        # One preview line per diagnostic class rather than the first five of a
        # list whose head is often five near-identical dropped fields.
        records = net["_meta"]["powerio_diagnostics"]
        preview = join(("$(r["code"]): $(r["message"])" for r in records), "\n  ")
        @warn "from_dss: $(length(warnings_list)) parsing and conversion diagnostic record(s) " *
              "in $(length(records)) class(es) " *
              "(full list on net[\"_meta\"][\"powerio_warnings\"]):\n  " * preview
    end
    if !isnothing(name)
        net["name"] = name
    elseif !haskey(net, "name") || isempty(get(net, "name", ""))
        net["name"] = relpath(abspath_dss)
    end

    net
end

"""
    powerio_version() -> String

Return the version of the PowerIO.jl package backing [`from_dss`](@ref),
e.g. `"PowerIO.jl 0.7.2"`. Useful for pinning test expectations and bug reports.
"""
function powerio_version()::String
    string("PowerIO.jl ", pkgversion(PowerIO))
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Top-level component collections whose KEYS are OpenDSS identifiers.
const _ID_COLLECTIONS = ("bus", "linecode", "line", "switch", "load",
                         "generator", "voltage_source", "shunt", "ibr",
                         "capacitor")

"""
    _canonicalize_identifiers!(net)

Case-fold every OpenDSS-sourced identifier (and every reference to one) to lower
case, so that references resolve under BMOPF's exact-match keys regardless of the
casing each OpenDSS statement used. OpenDSS identifiers are unique up to case, so
folding only reunites references to the same object — it never merges distinct
objects. If two keys in a collection do fold to the same value (which valid
OpenDSS cannot produce), an `ErrorException` is raised rather than silently
dropping one.

Folded: the keys of the component collections in `_ID_COLLECTIONS` and the
transformer subtype entries; the reference fields `bus`, `bus_from`, `bus_to`,
and `linecode`. Terminal names/maps are handled separately by
[`_remap_opendss_terminals!`](@ref).
"""
function _canonicalize_identifiers!(net::Dict{String,Any})
    fold = lowercase
    collisions = String[]

    foldkeys! = (parent, key) -> begin
        coll = get(parent, key, nothing)
        coll isa Dict || return
        folded = Dict{String,Any}()
        for (id, v) in coll
            fid = fold(string(id))
            haskey(folded, fid) &&
                push!(collisions, "$key: '$id' collides with another id as '$fid'")
            folded[fid] = v
        end
        parent[key] = folded
    end

    foldref! = (comp, k) ->
        (v = get(comp, k, nothing); v isa AbstractString && (comp[k] = fold(v)))

    # 1. Collection keys
    for k in _ID_COLLECTIONS
        foldkeys!(net, k)
    end
    xfmr = get(net, "transformer", nothing)
    if xfmr isa Dict
        for (subtype, sub) in xfmr
            sub isa Dict && foldkeys!(xfmr, subtype)
        end
    end

    # 2. Reference fields
    for ct in ("load", "generator", "voltage_source", "shunt", "ibr", "capacitor")
        for (_, c) in get(net, ct, Dict())
            c isa Dict && foldref!(c, "bus")
        end
    end
    for (_, c) in get(net, "line", Dict())
        c isa Dict || continue
        foldref!(c, "bus_from"); foldref!(c, "bus_to"); foldref!(c, "linecode")
    end
    for (_, c) in get(net, "switch", Dict())
        c isa Dict || continue
        foldref!(c, "bus_from"); foldref!(c, "bus_to")
    end
    if xfmr isa Dict
        for (subtype, sub) in xfmr
            sub isa Dict || continue
            for (_, c) in sub
                c isa Dict || continue
                foldref!(c, "bus_from"); foldref!(c, "bus_to")
                # Winding-list (n_winding) transformers reference their buses via
                # windings[i].bus, which the bus_from/bus_to fold does not reach.
                if subtype in WINDING_LIST_SUBTYPES
                    for w in get(c, "windings", Any[])
                        w isa AbstractDict && foldref!(w, "bus")
                    end
                end
            end
        end
    end

    isempty(collisions) || throw(ErrorException(
        "from_dss: case-folding identifiers produced collisions (OpenDSS " *
        "identifiers must be unique up to case):\n  " * join(collisions, "\n  ")))
    return net
end

"""
    _remap_opendss_terminals!(net)

Remap the supported OpenDSS phase/neutral labels (`1/2/3 → a/b/c`, `4 → n`).
PowerIO's materialized node-0 terminal is obtained from the source IR grounded
terminal list and becomes a distinct `n_ref`, with its perfect grounding intact.
`n_ref` is a winding/source return to the mathematical reference, not a transported
neutral or earth wire (PSK-000002). Maps, including n-winding maps, keep that
identity. `_meta.opendss_ground_references` records the explicit source mapping.
A grounded reference may be named 4, 5, or another number in the source IR; it
must never be identified by a fixed global `5 → n` substitution.

`grounded_references` maps each bus id to the source IR's grounded terminal
names. When it is omitted, no `n_ref` is created: a perfectly grounded `"4"`
stays the conductor neutral `n`, and a bus carrying an unexplained terminal
(such as `"5"`) is left unmapped rather than guessed.
"""
function _remap_opendss_terminals!(net::Dict{String,Any}; grounded_references=nothing)
    rename_maps = Dict{String,Dict{String,String}}()
    reference_records = Dict{String,Any}()

    for (bus_id, bus) in get(net, "bus", Dict())
        bus isa Dict || continue
        names = get(bus, "terminal_names", nothing)
        names isa Vector || continue
        str_names = string.(names)

        # This adapter's phase/neutral naming domain remains 1/2/3/4. The
        # synthetic reference label is supplied by PowerIO, never guessed as 5.
        # Without the source IR there is no evidence of node 0, so no terminal
        # becomes n_ref (a grounded "4" is a grounded conductor neutral).
        refs = grounded_references === nothing ? String[] :
            String.(get(grounded_references,bus_id,String[]))
        all(n -> haskey(_DSS_TERMINAL_MAP,n) || n in refs, str_names) || continue
        any(n -> n in ("1", "2", "3"), str_names) || continue
        length(refs) <= 1 || throw(ArgumentError("OpenDSS bus '$bus_id' has ambiguous materialized ground references"))

        rmap = Dict(n => n in refs ? _GROUNDED_REFERENCE_LABEL : _DSS_TERMINAL_MAP[n] for n in str_names)
        bus["terminal_names"] = unique(rmap[n] for n in str_names)
        delete!(bus,"neutral_terminal")
        "n" in values(rmap) ? (bus["neutral_terminal"]="n") :
            _GROUNDED_REFERENCE_LABEL in values(rmap) && (bus["neutral_terminal"]=_GROUNDED_REFERENCE_LABEL)
        g = get(bus,"perfectly_grounded_terminals",nothing)
        g isa AbstractVector && (bus["perfectly_grounded_terminals"] =
            unique(get(rmap,string(t),string(t)) for t in g))
        rename_maps[bus_id] = rmap
        isempty(refs) || (reference_records[bus_id] = Dict{String,Any}(
            "source_terminal"=>only(refs), "target_terminal"=>_GROUNDED_REFERENCE_LABEL,
            "source_node"=>"0", "perfectly_grounded"=>true,
            "physical_neutral_conductor"=>false))
    end

    isempty(rename_maps) && return

    _remap_terminal_maps!(net, rename_maps)

    if !isempty(reference_records)
        meta = get!(net, "_meta", Dict{String,Any}())
        meta["opendss_ground_references"] = Dict{String,Any}(
            "knowledge_ids"=>["PSK-000002"], "by_bus"=>reference_records,
            "status"=>"preserved_as_distinct_perfectly_grounded_returns")
    end
end

function _remap_terminal_maps!(net::Dict{String,Any},
                               rename_maps::Dict{String,Dict{String,String}})
    # Single-bus components: load, generator, voltage_source, shunt, ibr, capacitor
    for comp_type in ("load", "generator", "voltage_source", "shunt", "ibr", "capacitor")
        for (_, comp) in get(net, comp_type, Dict())
            comp isa Dict || continue
            rmap = get(rename_maps, get(comp, "bus", ""), nothing)
            rmap === nothing && continue
            tmap = get(comp, "terminal_map", nothing)
            tmap isa Vector &&
                (comp["terminal_map"] = [get(rmap, string(t), string(t)) for t in tmap])
        end
    end

    # Two-bus components: line, switch
    for comp_type in ("line", "switch")
        for (_, comp) in get(net, comp_type, Dict())
            comp isa Dict || continue
            for (tmap_key, bus_key) in (("terminal_map_from", "bus_from"),
                                        ("terminal_map_to",   "bus_to"))
                rmap = get(rename_maps, get(comp, bus_key, ""), nothing)
                rmap === nothing && continue
                tmap = get(comp, tmap_key, nothing)
                tmap isa Vector &&
                    (comp[tmap_key] = [get(rmap, string(t), string(t)) for t in tmap])
            end
        end
    end

    # Transformers — nested by subtype
    xfmr = get(net, "transformer", nothing)
    xfmr isa Dict || return
    for (_, subdict) in xfmr
        subdict isa Dict || continue
        for (_, comp) in subdict
            comp isa Dict || continue
            # Two-bus subtypes: terminal_map_from / terminal_map_to.
            for (tmap_key, bus_key) in (("terminal_map_from", "bus_from"),
                                        ("terminal_map_to",   "bus_to"))
                rmap = get(rename_maps, get(comp, bus_key, ""), nothing)
                rmap === nothing && continue
                tmap = get(comp, tmap_key, nothing)
                tmap isa Vector &&
                    (comp[tmap_key] = [get(rmap, string(t), string(t)) for t in tmap])
            end
            # n_winding subtype: each winding carries its own `bus` + `terminal_map`.
            windings = get(comp, "windings", nothing)
            windings isa Vector || continue
            for w in windings
                w isa Dict || continue
                rmap = get(rename_maps, get(w, "bus", ""), nothing)
                rmap === nothing && continue
                tmap = get(w, "terminal_map", nothing)
                tmap isa Vector &&
                    (w["terminal_map"] = [get(rmap, string(t), string(t)) for t in tmap])
            end
        end
    end
end

const _NO_LOAD_SHUNT_SUBTYPES = ("center_tap", "single_phase", "wye_delta", "delta_wye")

# PMD exchange supports numeric terminal 4 as the conventional neutral. A
# declared case convention or per-bus neutral takes precedence over that default.
function _pmd_winding_neutral_labels(net, bus_id)
    bus = get(get(net, "bus", Dict()), bus_id, Dict{String,Any}())
    neutral = get(bus, "neutral_terminal", nothing)
    neutral isa String && return Set([neutral])
    haskey(net, "terminal_conventions") && return _neutral_labels(net)
    Set(["n", "N", "4"])
end

function _legacy_excitation_voltage_divisor(xfmr, subtype, neutral_labels)
    subtype == "delta_wye" && return sqrt(3.0)
    if subtype == "single_phase"
        pairs = _xfmr_winding_pairs(get(xfmr, "terminal_map_to", String[]), neutral_labels)
        # A single L-N or L-L coil uses its rated coil voltage. Multi-coil wye
        # banks (including two coils and implicit ground returns) use V_LL/√3.
        length(pairs) > 1 && return sqrt(3.0)
    end
    1.0
end

function _normalize_transformer_no_load_shunts!(net::Dict{String,Any}, dn)
    xfmr = get(net, "transformer", nothing)
    xfmr isa Dict || return net
    any(get(xfmr, subtype, nothing) isa Dict for subtype in _NO_LOAD_SHUNT_SUBTYPES) ||
        return net

    local pmd
    try
        pmd_raw = PowerIO.emit(dn.module_, "pmd").text
        pmd = JSON3.read(pmd_raw)
    catch err
        @warn "from_dss: could not fetch PowerIO `pmd` export to normalise " *
              "transformer no-load shunts; core losses may differ from OpenDSS." err
        return net
    end

    _normalize_transformer_no_load_shunts_from_pmd!(net, pmd)
end

function _normalize_transformer_no_load_shunts_from_pmd!(net::Dict{String,Any}, pmd)
    xfmr = get(net, "transformer", Dict())
    pmd_tr = get(pmd, :transformer, nothing)
    pmd_tr === nothing && return net

    by_id = Dict{String,Any}()
    for (k, t) in pairs(pmd_tr)
        by_id[lowercase(String(k))] = t
        nm = get(t, :name, nothing)
        nm === nothing || (by_id[lowercase(String(nm))] = t)
    end

    for subtype in _NO_LOAD_SHUNT_SUBTYPES
        coll = get(xfmr, subtype, nothing)
        coll isa Dict || continue
        for (tid, c) in coll
            c isa Dict || continue
            materialized = get(get(net, "_meta", Dict()), "explicit_transformer_core_shunts", Dict())
            haskey(materialized, "$(lowercase(subtype))/$(lowercase(String(tid)))") && continue
            t = get(by_id, lowercase(String(tid)), nothing)
            t === nothing && continue
            noloadloss = Float64(get(t, :noloadloss, 0.0))
            cmag = Float64(get(t, :cmag, 0.0))
            if iszero(noloadloss) && iszero(cmag)
                # No voltage/tap base is needed to represent a zero shunt.
                c["g_no_load"] = 0.0
                c["b_no_load"] = 0.0
                continue
            end
            vmn = get(t, :vm_nom, nothing)
            smn = get(t, :sm_nom, nothing)
            (vmn isa AbstractVector && smn isa AbstractVector &&
             length(vmn) >= 2 && length(smn) >= 1) || continue

            s1 = Float64(smn[1]) * 1e3
            labels = _pmd_winding_neutral_labels(net, get(c, "bus_to", ""))
            divisor = _legacy_excitation_voltage_divisor(c, subtype, labels)
            tm = get(t, :tm_set, nothing)
            to_taps = tm isa AbstractVector && length(tm) >= 2 ? tm[2] : [1.0]
            to_taps isa AbstractVector || (to_taps = [to_taps])
            isempty(to_taps) && throw(ArgumentError("transformer $tid: missing winding-2 tap for excitation base"))
            all(==(first(to_taps)), to_taps) || throw(ArgumentError(
                "transformer $tid: unequal winding-2 coil taps cannot use a scalar legacy excitation; supply explicit coil shunts"))
            vstamp = Float64(vmn[2]) * 1e3 * Float64(first(to_taps)) /
                divisor
            vstamp > 0 || continue
            c["g_no_load"] = noloadloss * s1 / vstamp^2
            c["b_no_load"] = -cmag * s1 / vstamp^2
        end
    end
    return net
end

# Per-phase voltage angles must sit within this tolerance of a balanced +/-120
# degree rotation or 0 degrees to count as a coherent polyphase arrangement.
const _PHASE_BALANCE_TOL_RAD = deg2rad(30)

# Tighter tolerance for 90 degree and 180 degree separation classes.
const _PHASE_SEPARATION_TOL_RAD = deg2rad(15)

_wrap_pi(x::Real) = (y = mod(x + pi, 2pi) - pi; y == -pi ? pi : y)

function _separation_of_diff(d::Real)::Symbol
    a = abs(d)
    if a <= _PHASE_BALANCE_TOL_RAD
        return :zero
    elseif abs(a - pi / 2) <= _PHASE_SEPARATION_TOL_RAD
        return :quadrature
    elseif abs(a - 2pi / 3) <= _PHASE_BALANCE_TOL_RAD
        return d < 0 ? :positive : :negative
    elseif abs(a - pi) <= _PHASE_SEPARATION_TOL_RAD
        return :anti_phase
    else
        return :incoherent
    end
end

function _phase_separation_class(angles::AbstractVector{<:Real})::Symbol
    length(angles) >= 2 || return :incoherent
    diffs = [_wrap_pi(angles[i + 1] - angles[i]) for i in 1:length(angles)-1]
    classes = map(_separation_of_diff, diffs)
    all(==(first(classes)), classes) ? first(classes) : :incoherent
end
