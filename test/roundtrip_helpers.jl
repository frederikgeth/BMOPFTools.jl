# roundtrip_helpers.jl
#
# Shared machinery for the BMOPF ↔ OpenDSS round-trip fidelity study
# (DSS → BMOPF → DSS). Both the standalone diagnostic script
# (scripts/roundtrip_fidelity.jl) and the committed regression testset in
# test/runtests.jl `include` this file so they diagnose fidelity identically.
#
# The file references `from_dss`/`to_dss` (BMOPFTools, must be `using`-ed by the
# includer) and, for the optional power-flow gate, `OpenDSSDirect` — resolved
# lazily at call time, so this file includes cleanly even when OpenDSSDirect is
# absent. PF functions must simply not be *called* in that case.
#
# Three signal sources, in priority order:
#   1. PowerIO warnings  — from_dss parse warnings + to_dss export warnings.
#   2. Semantic diff     — structural diff of net1 (from original) vs net2 (from
#                          regenerated DSS); both normalized by from_dss, so any
#                          difference is real round-trip information loss.
#   3. PF cross-check    — solve original vs regenerated DSS in OpenDSS, compare
#                          node voltages (isolates export fidelity).

# ── Data structures ─────────────────────────────────────────────────────────

"""
A single structural difference between two `from_dss`-normalized network dicts.
`kind ∈ (:missing, :extra, :topology_mismatch, :numeric_mismatch, :type_mismatch)`.
`v1`/`v2` are the values in the original / regenerated net (`nothing` if absent).
"""
struct Diff
    path::String                       # e.g. "transformer.wye_delta.t1.r_series_to"
    component_type::Symbol             # :bus :line :transformer ...
    subtype::Union{Symbol,Nothing}    # transformer subtype, else nothing
    id::Union{String,Nothing}          # component id, nothing for collection-level miss
    field::Union{String,Nothing}       # leaf field, nothing for whole-component miss
    kind::Symbol
    v1::Any
    v2::Any
end

"Result of the OpenDSS power-flow cross-check for one case."
struct PFResult
    solved::Bool                       # regenerated DSS converged in OpenDSS
    matched::Bool                      # all compared nodes within tolerance
    skipped::Bool                      # OpenDSSDirect absent, or original didn't solve
    max_dV::Float64                    # max |V_orig - V_regen| over compared nodes (V)
    n_nodes_compared::Int
    over_tol_nodes::Vector{Tuple{String,Float64}}
    note::String
end

# A PF result is "clean" only when it solved and matched (or was legitimately not
# run). skipped results are neither pass nor fail — they carry no verdict.
pf_ok(pf::PFResult) = pf.skipped || (pf.solved && pf.matched)

"Full per-case diagnostic bundle across all three signal sources."
struct CaseReport
    case::String                       # stem, e.g. "pf_yd_xfmr"
    path::String                       # absolute source .dss path
    tier::Symbol                       # :A or :B
    parse_warnings::Vector{String}
    export_warnings::Vector{String}
    semantic_diffs::Vector{Diff}
    pf::PFResult
    errors::Vector{String}
end

# ── Field classification ────────────────────────────────────────────────────

# Top-level keys that are tool-private / non-semantic — never diffed.
const EXCLUDE_TOP_KEYS = Set(["_meta", "name", "meta"])

# Component collections walked by semantic_diff (transformer handled specially).
const COMPONENT_TYPES = [:bus, :linecode, :line, :transformer, :switch, :load,
                         :generator, :voltage_source, :shunt, :capacitor, :ibr]

# Fields that must match EXACTLY (structure/topology). Everything else numeric
# is compared with isapprox.
const TOPOLOGY_FIELDS = Set([
    "bus_from", "bus_to", "bus", "terminal_map", "terminal_map_from",
    "terminal_map_to", "terminal_names", "neutral_terminal",
    "perfectly_grounded_terminals", "configuration", "linecode", "open_switch",
    "model", "delta_roll", "prime_mover", "topology"])

_isnumberish(x::Number) = true
_isnumberish(x::AbstractArray) = !isempty(x) && all(_isnumberish, x)
_isnumberish(::Any) = false

# ── Semantic diff ───────────────────────────────────────────────────────────

"""
    semantic_diff(net1, net2; rtol=1e-6, atol=0.0) -> Vector{Diff}

Structurally diff two BMOPF network dicts, both assumed `from_dss`-normalized.
Topology fields compare exactly; numeric fields with `isapprox`. Any difference
is round-trip information loss localized to a component/field.
"""
function semantic_diff(net1::AbstractDict, net2::AbstractDict; rtol=1e-6, atol=0.0)::Vector{Diff}
    diffs = Diff[]
    for ctype in COMPONENT_TYPES
        c1 = get(net1, string(ctype), nothing)
        c2 = get(net2, string(ctype), nothing)
        (c1 === nothing && c2 === nothing) && continue
        if ctype == :transformer
            _diff_transformers(c1, c2, diffs; rtol, atol)
        elseif ctype == :voltage_source
            _diff_voltage_sources(c1, c2, diffs; rtol, atol)
        else
            _diff_collection(ctype, nothing, _asdict(c1), _asdict(c2), diffs; rtol, atol)
        end
    end
    diffs
end

_asdict(::Nothing) = Dict{String,Any}()
_asdict(d::AbstractDict) = d

# Flat collection: {id => component-dict}.
function _diff_collection(ctype::Symbol, subtype, c1::AbstractDict, c2::AbstractDict,
                          diffs::Vector{Diff}; rtol, atol)
    pfx = subtype === nothing ? string(ctype) : "$(ctype).$(subtype)"
    for id in union(keys(c1), keys(c2))
        in1, in2 = haskey(c1, id), haskey(c2, id)
        if in1 && !in2
            push!(diffs, Diff("$pfx.$id", ctype, subtype, id, nothing, :missing, c1[id], nothing))
        elseif in2 && !in1
            push!(diffs, Diff("$pfx.$id", ctype, subtype, id, nothing, :extra, nothing, c2[id]))
        else
            _diff_component("$pfx.$id", ctype, subtype, id, c1[id], c2[id], diffs; rtol, atol)
        end
    end
end

# One component: {field => value}.
function _diff_component(path::String, ctype::Symbol, subtype, id::String,
                         a::AbstractDict, b::AbstractDict, diffs::Vector{Diff}; rtol, atol)
    for field in union(keys(a), keys(b))
        ina, inb = haskey(a, field), haskey(b, field)
        fpath = "$path.$field"
        if ina && !inb
            push!(diffs, Diff(fpath, ctype, subtype, id, field, :missing, a[field], nothing))
        elseif inb && !ina
            push!(diffs, Diff(fpath, ctype, subtype, id, field, :extra, nothing, b[field]))
        else
            d = _cmp_field(fpath, ctype, subtype, id, field, a[field], b[field]; rtol, atol)
            d === nothing || push!(diffs, d)
        end
    end
end

# Leaf comparison: topology → exact, numeric → isapprox, nested dict → recurse.
function _cmp_field(fpath, ctype, subtype, id, field, v1, v2; rtol, atol)
    if v1 isa AbstractDict && v2 isa AbstractDict
        # Nested sub-dict (e.g. load "cost" or n_winding windings): recurse and
        # fold child diffs up under this field's kind if any differ.
        child = Diff[]
        _diff_component(fpath, ctype, subtype, id, v1, v2, child; rtol, atol)
        isempty(child) && return nothing
        return Diff(fpath, ctype, subtype, id, field, :numeric_mismatch, v1, v2)
    end
    if field in TOPOLOGY_FIELDS
        return isequal(v1, v2) ? nothing :
               Diff(fpath, ctype, subtype, id, field, :topology_mismatch, v1, v2)
    end
    if _isnumberish(v1) && _isnumberish(v2)
        if v1 isa AbstractArray || v2 isa AbstractArray
            if size(v1) != size(v2)
                return Diff(fpath, ctype, subtype, id, field, :topology_mismatch, v1, v2)
            end
            return all(isapprox.(v1, v2; rtol, atol)) ? nothing :
                   Diff(fpath, ctype, subtype, id, field, :numeric_mismatch, v1, v2)
        end
        return isapprox(v1, v2; rtol, atol) ? nothing :
               Diff(fpath, ctype, subtype, id, field, :numeric_mismatch, v1, v2)
    end
    # Fallback: differing types or non-numeric scalars (strings/bools).
    isequal(v1, v2) && return nothing
    kind = (typeof(v1) == typeof(v2)) ? :topology_mismatch : :type_mismatch
    Diff(fpath, ctype, subtype, id, field, kind, v1, v2)
end

# Transformers: nested by subtype. Match ids ACROSS subtypes first so a subtype
# change is reported as such, not as a drop+add.
function _diff_transformers(t1, t2, diffs::Vector{Diff}; rtol, atol)
    t1 = _asdict(t1); t2 = _asdict(t2)
    loc1 = _xfmr_locations(t1)          # id => subtype
    loc2 = _xfmr_locations(t2)
    for id in union(keys(loc1), keys(loc2))
        s1 = get(loc1, id, nothing)
        s2 = get(loc2, id, nothing)
        if s1 === nothing
            push!(diffs, Diff("transformer.$s2.$id", :transformer, Symbol(s2), id, nothing,
                              :extra, nothing, t2[s2][id]))
        elseif s2 === nothing
            push!(diffs, Diff("transformer.$s1.$id", :transformer, Symbol(s1), id, nothing,
                              :missing, t1[s1][id], nothing))
        elseif s1 != s2
            push!(diffs, Diff("transformer.$id.subtype", :transformer, Symbol(s1), id,
                              "subtype", :topology_mismatch, s1, s2))
        else
            _diff_component("transformer.$s1.$id", :transformer, Symbol(s1), id,
                            t1[s1][id], t2[s2][id], diffs; rtol, atol)
        end
    end
end

# id => subtype map across all transformer subtypes.
function _xfmr_locations(t::AbstractDict)
    loc = Dict{String,String}()
    for (subtype, bank) in t
        bank isa AbstractDict || continue
        for id in keys(bank)
            loc[id] = subtype
        end
    end
    loc
end

# Voltage sources: the DSS writer may rename/re-split merged sources, so match
# id-agnostically on (bus, sorted terminal_map) before falling back to id.
function _diff_voltage_sources(v1, v2, diffs::Vector{Diff}; rtol, atol)
    v1 = _asdict(v1); v2 = _asdict(v2)
    key(vs) = (get(vs, "bus", nothing), sort(string.(get(vs, "terminal_map", String[]))))
    idx2 = Dict(key(vs) => id for (id, vs) in v2)
    matched2 = Set{String}()
    for (id1, vs1) in v1
        k = key(vs1)
        if haskey(idx2, k)
            id2 = idx2[k]
            push!(matched2, id2)
            _diff_component("voltage_source.$id1", :voltage_source, nothing, id1,
                            vs1, v2[id2], diffs; rtol, atol)
        else
            push!(diffs, Diff("voltage_source.$id1", :voltage_source, nothing, id1,
                              nothing, :missing, vs1, nothing))
        end
    end
    for (id2, vs2) in v2
        id2 in matched2 && continue
        push!(diffs, Diff("voltage_source.$id2", :voltage_source, nothing, id2,
                          nothing, :extra, nothing, vs2))
    end
end

# ── Failure-mode taxonomy ───────────────────────────────────────────────────

"""
    classify_diff(d::Diff) -> Symbol

Map a structural Diff to an actionable failure mode.
"""
function classify_diff(d::Diff)::Symbol
    f = d.field
    if d.field == "subtype"
        return :transformer_subtype_changed
    elseif d.kind == :missing && d.field === nothing
        return d.component_type in (:shunt,) ? :grounding_neutral_lost : :component_dropped
    elseif d.kind == :extra && d.field === nothing
        return d.component_type == :voltage_source ? :source_split_mismatch : :component_added
    elseif f !== nothing && (occursin("terminal_map", f) || f == "terminal_names")
        return :terminal_map_altered
    elseif f in ("neutral_terminal", "perfectly_grounded_terminals")
        return :grounding_neutral_lost
    elseif f in ("configuration", "delta_roll")
        return :configuration_changed
    elseif f == "linecode"
        return :linecode_ref_broken
    elseif f == "model"
        return :load_model_changed
    elseif f !== nothing && (occursin("r_series", f) || occursin("x_series", f) ||
                             occursin("R_series", f) || occursin("X_series", f) ||
                             occursin("x_sc", f) || occursin("r_winding", f))
        return :impedance_drifted
    elseif f !== nothing && (occursin("no_load", f) || startswith(f, "G_") ||
                             startswith(f, "B_") || occursin("shunt", f))
        return :admittance_drifted
    elseif d.component_type == :voltage_source
        return :source_split_mismatch
    elseif d.component_type == :load
        return :load_model_changed
    else
        return :other_mismatch
    end
end

# Keyword → (component_type, failure_mode) for PowerIO warning strings.
const _WARN_RULES = [
    (r"reactor|phases\s*=\s*1|grounding|neutral"i, (:shunt, :grounding_neutral_lost)),
    (r"shunt admittance|susceptance|capacit"i,    (:shunt, :admittance_drifted)),
    (r"regcontrol|tap|regulator"i,                (:transformer, :unrepresentable_warned)),
    (r"loadshape|time.?series|profile"i,          (:load, :unrepresentable_warned)),
    (r"transformer|winding|leakage"i,             (:transformer, :impedance_drifted)),
]

"""
    classify_warning(w::String) -> Tuple{Symbol,Symbol}

Map a raw PowerIO warning string to (component_type, failure_mode). Falls back to
(:network, :unrepresentable_warned) for unmatched warnings.
"""
function classify_warning(w::AbstractString)::Tuple{Symbol,Symbol}
    for (re, tag) in _WARN_RULES
        occursin(re, w) && return tag
    end
    (:network, :unrepresentable_warned)
end

# ── OpenDSS power-flow gate ─────────────────────────────────────────────────
# References `OpenDSSDirect` (must be in the includer's scope when CALLED).

"""
    ods_solve_volts(dss_path) -> (converged::Bool, Dict{String,ComplexF64})

Clear, redirect and explicitly Solve the DSS file in OpenDSS. Returns whether the
solution converged and a dict of lowercased non-earth node name → complex volts.
Node names are lowercased so an original (mixed-case) and its regenerated
(case-folded) counterpart align.
"""
function ods_solve_volts(dss_path::String)
    OpenDSSDirect.dss("Clear")
    # Keep any Export/Show output the deck emits out of the working directory.
    OpenDSSDirect.dss("Set DataPath=\"$(tempdir())\"")
    OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
    OpenDSSDirect.dss("Solve")
    conv = OpenDSSDirect.Solution.Converged()
    names = OpenDSSDirect.Circuit.AllNodeNames()
    volts = OpenDSSDirect.Circuit.AllBusVolts()
    d = Dict{String,ComplexF64}(lowercase(n) => v for (n, v) in zip(names, volts))
    return conv, d
end

"""
    pf_cross_check(orig_path, regen_path; atol=0.3, rtol=1e-3) -> PFResult

Solve original and regenerated DSS in OpenDSS and compare node voltages. Skips
nodes with |V_orig| < 1e-4 (earth reference) and nodes not present in both.
"""
function pf_cross_check(orig_path::String, regen_path::String; atol=0.3, rtol=1e-3)::PFResult
    conv1, V1 = ods_solve_volts(orig_path)
    if !conv1
        return PFResult(false, false, true, NaN, 0, Tuple{String,Float64}[],
                        "original DSS did not converge; PF gate skipped")
    end
    local conv2, V2
    try
        conv2, V2 = ods_solve_volts(regen_path)
    catch e
        return PFResult(false, false, false, NaN, 0, Tuple{String,Float64}[],
                        "regenerated DSS failed to load/solve: $(sprint(showerror, e))")
    end
    if !conv2
        return PFResult(false, false, false, NaN, 0, Tuple{String,Float64}[],
                        "regenerated DSS did not converge")
    end
    max_dV = 0.0
    n = 0
    over = Tuple{String,Float64}[]
    for (node, v1) in V1
        haskey(V2, node) || continue
        abs(v1) < 1e-4 && continue
        n += 1
        dV = abs(v1 - V2[node])
        max_dV = max(max_dV, dV)
        isapprox(V2[node], v1; atol, rtol) || push!(over, (node, dV))
    end
    note = isempty(over) ? "" : "$(length(over)) node(s) over tolerance"
    PFResult(true, isempty(over), false, max_dV, n, over, note)
end

# ── Per-case runner ─────────────────────────────────────────────────────────

"""
    diagnose_case(dss_path; tier=:A, has_ods=false, workdir,
                  rtol_num=1e-6, atol_v=0.3, rtol_v=1e-3) -> CaseReport

Run the full DSS → BMOPF → DSS pipeline for one case, collecting all three signal
sources. Each stage is isolated so one failure degrades gracefully into `errors`.
"""
function diagnose_case(dss_path::String; tier::Symbol=:A, has_ods::Bool=false,
                       workdir::String=mktempdir(),
                       rtol_num=1e-6, atol_v=0.3, rtol_v=1e-3)::CaseReport
    stem = _case_stem(dss_path)
    errors = String[]
    parse_warnings = String[]
    export_warnings = String[]
    diffs = Diff[]
    pf = PFResult(false, false, true, NaN, 0, Tuple{String,Float64}[], "not run")

    net1 = nothing
    regen_path = joinpath(workdir, "$stem.dss")
    try
        net1 = from_dss(dss_path)
        append!(parse_warnings, _meta_warnings(net1))
    catch e
        push!(errors, "from_dss(original): $(sprint(showerror, e))")
        return CaseReport(stem, dss_path, tier, parse_warnings, export_warnings, diffs, pf, errors)
    end

    try
        export_warnings = to_dss(net1, regen_path)   # path form returns just warnings
    catch e
        push!(errors, "to_dss: $(sprint(showerror, e))")
        return CaseReport(stem, dss_path, tier, parse_warnings, export_warnings, diffs, pf, errors)
    end

    net2 = nothing
    try
        net2 = from_dss(regen_path)
        append!(parse_warnings, _meta_warnings(net2))
    catch e
        push!(errors, "from_dss(regenerated): $(sprint(showerror, e))")
    end

    if net2 !== nothing
        try
            diffs = semantic_diff(net1, net2; rtol=rtol_num)
        catch e
            push!(errors, "semantic_diff: $(sprint(showerror, e))")
        end
    end

    if has_ods
        # Tighten transformer cases to atol=0.1 V, mirroring powerflow_comparison_tests.
        atol = occursin(r"_(dy|yd)_", stem) ? 0.1 : atol_v
        try
            pf = pf_cross_check(dss_path, regen_path; atol, rtol=rtol_v)
        catch e
            push!(errors, "pf_cross_check: $(sprint(showerror, e))")
            pf = PFResult(false, false, false, NaN, 0, Tuple{String,Float64}[],
                          "PF gate errored")
        end
    end

    CaseReport(stem, dss_path, tier, parse_warnings, export_warnings, diffs, pf, errors)
end

_meta_warnings(net) = collect(String, get(get(net, "_meta", Dict{String,Any}()),
                                          "powerio_warnings", String[]))

# Case id from a DSS path. Generic entry-point names (Master.dss, master_scaled)
# are disambiguated by the parent directory so real networks don't all collapse
# to "Master".
function _case_stem(dss_path::String)::String
    stem = first(splitext(basename(dss_path)))
    if lowercase(stem) in ("master", "master_scaled")
        return "$(basename(dirname(dss_path)))/$stem"
    end
    stem
end

# ── Corpus driver ───────────────────────────────────────────────────────────

"""
    run_corpus(paths; has_ods=false, workdir, verbose=true, kwargs...) -> Vector{CaseReport}

`paths` is a vector of `(abspath, tier)` tuples. Runs `diagnose_case` over each,
isolating per-case exceptions so one bad case never aborts the run.
"""
function run_corpus(paths; has_ods::Bool=false, workdir::String=mktempdir(),
                    verbose::Bool=true, kwargs...)::Vector{CaseReport}
    reports = CaseReport[]
    for (path, tier) in paths
        r = try
            diagnose_case(path; tier, has_ods, workdir, kwargs...)
        catch e
            stem = _case_stem(path)
            CaseReport(stem, path, tier, String[], String[], Diff[],
                       PFResult(false, false, true, NaN, 0, Tuple{String,Float64}[], "harness error"),
                       ["diagnose_case threw: $(sprint(showerror, e))"])
        end
        push!(reports, r)
        if verbose
            pfstr = r.pf.skipped ? "–" : (pf_ok(r.pf) ? "✓" : "✗")
            @info "roundtrip" case=r.case tier=r.tier diffs=length(r.semantic_diffs) pf=pfstr max_dV=round(r.pf.max_dV, digits=3) warns=(length(r.parse_warnings)+length(r.export_warnings)) errs=length(r.errors)
        end
    end
    reports
end
