# io/from_dss.jl
#
# OpenDSS → BMOPF conversion via the PowerIO.jl package
# (eigenergy/PowerIO.jl, which binds the `powerio` Rust engine in-process).

# OpenDSS numeric terminal names → task-force phase labels.
# 1/2/3 → phases a/b/c, 4 → neutral n. PowerIO renders the OpenDSS earth node
# (.0) as terminal "5"; it is routed to the bus neutral ("n") so that an earthed
# transformer star point is grounded through the bus's grounding impedance
# rather than left as a phantom phase terminal (BMOPF has no earth terminal).
const _DSS_TERMINAL_MAP = Dict(
    "1" => "a", "2" => "b", "3" => "c", "4" => "n", "5" => "n")

# Terminal names PowerIO can emit for an OpenDSS bus (phases, neutral, earth).
const _DSS_NUMERIC_TERMINALS = Set(("1", "2", "3", "4", "5"))

"""
    from_dss(path::AbstractString; name=nothing) -> Dict{String,Any}

Parse an OpenDSS Master file directly to a BMOPF network dict using
[PowerIO.jl](https://github.com/eigenergy/PowerIO.jl).

This is the recommended path for reading OpenDSS networks: the Rust parser
(bound in-process by PowerIO.jl) materialises every OpenDSS class default
explicitly, validates fidelity against the OpenDSS solver, and produces
schema-valid BMOPF JSON without going through PowerModelsDistribution.

OpenDSS identifiers are case-insensitive but case-preserving, whereas BMOPF
keys are matched exactly. To reconcile the two, every identifier and every
reference to one (bus names, linecodes, component ids) is **case-folded to
lower case** on ingest, so references resolve regardless of the casing each
OpenDSS statement happened to use.

OpenDSS numeric terminal names (`"1"`, `"2"`, `"3"`, `"4"`) are remapped to
the task-force convention (`"a"`, `"b"`, `"c"`, `"n"`) and `neutral_terminal`
is set to `"n"` on every affected bus.

# Arguments
- `path`: path to the OpenDSS Master.dss file (or any .dss entry point)
- `name`: optional network name string set on `net["name"]` after parsing.
  Defaults to the relative path of the Master file from the working directory.

# Conversion warnings
PowerIO reports every piece of information that cannot be represented in BMOPF
JSON (e.g. shunt admittance, load shape time series, RegControl OLTC taps).
These are surfaced on `_meta["powerio_warnings"]` in the returned dict, so
callers can inspect them without losing the converted data.

# Errors
- `ArgumentError` if the DSS file does not exist.
- `ErrorException` if PowerIO produces no output (parse failure or schema error).

# Example
```julia
net = from_dss("test/data/ENWL/network_1/Feeder_1/Master.dss")
report = analyze(net)
render(report, stdout)
```
"""
function from_dss(path::AbstractString;
                  name::Union{AbstractString,Nothing}=nothing)::Dict{String,Any}

    abspath_dss = abspath(path)
    isfile(abspath_dss) || throw(ArgumentError("DSS file not found: $abspath_dss"))

    # PowerIO parses to a DistNetwork handle, then emits BMOPF JSON plus a list
    # of fidelity-loss warnings.
    dn = PowerIO.parse_file(PowerIO.DistNetwork, abspath_dss)
    json_raw, warnings_list = PowerIO.to_format(dn, "bmopf")

    if isempty(json_raw)
        throw(ErrorException("PowerIO produced no output for $path"))
    end

    net = parse_bmopf(json_raw; from_string=true)
    _canonicalize_identifiers!(net)
    _remap_opendss_terminals!(net)
    _merge_phase_voltage_sources!(net)

    # Store conversion warnings so callers can inspect fidelity losses
    net["_meta"] = get(net, "_meta", Dict{String,Any}())
    net["_meta"]["powerio_warnings"] = collect(String, warnings_list)
    net["_meta"]["powerio_source"]   = abspath_dss

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
e.g. `"PowerIO.jl 0.2.0"`. Useful for pinning test expectations and bug reports.
"""
function powerio_version()::String
    string("PowerIO.jl ", pkgversion(PowerIO))
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Top-level component collections whose KEYS are OpenDSS identifiers.
const _ID_COLLECTIONS = ("bus", "linecode", "line", "switch", "load",
                         "generator", "voltage_source", "shunt", "inverter")

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
    for ct in ("load", "generator", "voltage_source", "shunt", "inverter")
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
        for (_, sub) in xfmr
            sub isa Dict || continue
            for (_, c) in sub
                c isa Dict || continue
                foldref!(c, "bus_from"); foldref!(c, "bus_to")
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

Remap OpenDSS numeric terminal names to the task-force phase labels
(`1,2,3 → a,b,c`, `4 → n`) throughout a BMOPF network dict, and route the
OpenDSS earth terminal `"5"` to the bus neutral `"n"`. A bus is remapped when
all of its terminal names are OpenDSS numerics (`⊆ {1,2,3,4,5}`) and it carries
at least one phase (`1`, `2` or `3`); `neutral_terminal => "n"` is set whenever
a neutral results. All component `terminal_map` and
`terminal_map_from`/`terminal_map_to` references are updated consistently, and
duplicate terminals introduced by the `4`/`5` → `n` collapse are removed.

Buses with other naming conventions (e.g. already `a/b/c/n`) are left unchanged.

When an earth terminal `"5"` is routed to neutral, a note is recorded under
`net["_meta"]["earth_terminal_routing"]` so the (slightly lossy) modeling choice
— an earthed star point becomes grounded through the bus neutral rather than
solidly — stays inspectable.
"""
function _remap_opendss_terminals!(net::Dict{String,Any})
    rename_maps = Dict{String,Dict{String,String}}()
    earth_routed = String[]

    for (bus_id, bus) in get(net, "bus", Dict())
        bus isa Dict || continue
        names = get(bus, "terminal_names", nothing)
        names isa Vector || continue
        str_names = string.(names)

        # Only OpenDSS-numeric buses carrying at least one phase conductor.
        all(n -> n in _DSS_NUMERIC_TERMINALS, str_names) || continue
        any(n -> n in ("1", "2", "3"), str_names) || continue

        rmap = Dict(n => _DSS_TERMINAL_MAP[n] for n in str_names)
        bus["terminal_names"] = unique(rmap[n] for n in str_names)
        "n" in values(rmap) && (bus["neutral_terminal"] = "n")
        rename_maps[bus_id] = rmap
        "5" in str_names && push!(earth_routed, bus_id)
    end

    isempty(rename_maps) && return

    _remap_terminal_maps!(net, rename_maps)

    if !isempty(earth_routed)
        meta = get!(net, "_meta", Dict{String,Any}())
        meta["earth_terminal_routing"] = Dict(
            "buses"   => sort(earth_routed),
            "message" => "OpenDSS earth terminal \"5\" routed to the bus neutral " *
                         "\"n\"; an earthed star point is grounded through the bus " *
                         "neutral rather than solidly.",
        )
    end
end

function _remap_terminal_maps!(net::Dict{String,Any},
                               rename_maps::Dict{String,Dict{String,String}})
    # Single-bus components: load, generator, voltage_source, shunt
    for comp_type in ("load", "generator", "voltage_source", "shunt")
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
end

# Phase terminals in positive-sequence rotation (a precedes b precedes c). A
# merged source is always emitted in this order regardless of the order the
# per-phase VSource objects appeared in the OpenDSS file.
const _PHASE_TERMINALS = ("a", "b", "c")

# Per-phase voltage angles must sit within this tolerance of a balanced ±120°
# rotation for a bank of single-phase sources to count as one coherent polyphase
# source. Loose enough to admit mild export imbalance, tight enough to reject
# incidental same-bus sources (e.g. all at 0°).
const _PHASE_BALANCE_TOL_RAD = deg2rad(30)

# Wrap an angle (radians) to (-π, π].
_wrap_pi(x::Real) = (y = mod(x + π, 2π) - π; y == -π ? π : y)

"""
    _phase_sequence_class(order, phase_data) -> Symbol

Classify the phasor rotation of a label-ordered (`a`,`b`,`c`) bank from its
per-phase angles. Returns `:positive` when each successive phase lags the
previous by ≈120° (the standard a→b→c rotation), `:negative` when each leads by
≈120°, or `:incoherent` when the angles are not a consistent balanced set
(within [`_PHASE_BALANCE_TOL_RAD`](@ref)). Ordering is always by physical phase
label, never by angle — the angles only decide whether the bank is self-
consistent enough to be one source, and which rotation it carries.
"""
function _phase_sequence_class(order::Vector{String},
                               phase_data::Dict{String,Tuple{Float64,Float64}})::Symbol
    length(order) >= 2 || return :incoherent
    angs  = [phase_data[p][2] for p in order]
    diffs = [_wrap_pi(angs[i+1] - angs[i]) for i in 1:length(angs)-1]
    step  = -2π / 3  # positive sequence: each successive phase lags 120°
    if all(d -> abs(_wrap_pi(d - step)) <= _PHASE_BALANCE_TOL_RAD, diffs)
        return :positive
    elseif all(d -> abs(_wrap_pi(d + step)) <= _PHASE_BALANCE_TOL_RAD, diffs)
        return :negative
    else
        return :incoherent
    end
end

"""
    _merge_phase_voltage_sources!(net)

Collapse a bank of co-located single-phase voltage sources into one polyphase
source. OpenDSS commonly models a three-phase substation source as a `Circuit`
element plus per-phase `VSource` objects (`…_phB`, `…_phC`), each a 1-phase
source wired to a single phase of a shared bus. PowerIO faithfully emits these
as separate single-phase `voltage_source` entries, but BMOPF's spec expects one
voltage source per bus, and the OPF reference convention is a single polyphase
slack — so the bank is reassembled here at the ingest boundary.

Sources on a common bus are merged when **every** member is single-phase (its
`terminal_map` carries exactly one of `a`/`b`/`c`, plus an optional neutral),
the members cover **distinct** phases (no two claim the same phase), none
carries `p_min`/`p_max`/`q_min`/`q_max`/`cost` (priced/bounded slacks are left
untouched — combining their per-phase limits is ambiguous), and the members'
angles form a coherent balanced rotation (see [`_phase_sequence_class`](@ref)).
A bus whose same-bus sources are *not* a coherent rotation is left unmerged and
recorded under `net["_meta"]["merged_voltage_sources"]["declined"]`.

The merged source keeps the member id that names the `Circuit` (the one whose id
is `"source"`) when present, otherwise the lexicographically first member id, and
gets a `terminal_map` of the covered phases in **physical label order**
(`a`,`b`,`c`) followed by `n`, with `v_magnitude`/`v_angle` aligned (neutral
pinned to 0). Phase order is always label-driven — the per-phase angles are
preserved verbatim, never used to permute conductors. When the angle rotation is
negative-sequence (it disagrees with the a→b→c label order), the bank is still
merged faithfully but the discrepancy is flagged on the group note as a likely
modeling error. A note is recorded under
`net["_meta"]["merged_voltage_sources"]`.

Groups that do not satisfy every condition are left exactly as parsed.
"""
function _merge_phase_voltage_sources!(net::Dict{String,Any})
    sources = get(net, "voltage_source", nothing)
    sources isa Dict || return

    # Group source ids by the bus they attach to.
    by_bus = Dict{String,Vector{String}}()
    for (id, vs) in sources
        vs isa Dict || continue
        bus = string(get(vs, "bus", ""))
        isempty(bus) && continue
        push!(get!(by_bus, bus, String[]), id)
    end

    merged_notes   = Vector{Dict{String,Any}}()
    declined_notes = Vector{Dict{String,Any}}()

    for (bus, ids) in by_bus
        length(ids) >= 2 || continue

        # Collect each member's single phase and aligned magnitude/angle.
        phase_data = Dict{String,Tuple{Float64,Float64}}()  # phase => (mag, ang)
        member_ids = String[]
        mergeable  = true

        for id in sort(ids)
            vs = sources[id]
            # Bounded/priced slacks: combining per-phase limits is ambiguous.
            if any(haskey(vs, k) for k in ("p_min", "p_max", "q_min", "q_max", "cost"))
                mergeable = false; break
            end
            tm  = Vector{String}(get(vs, "terminal_map", String[]))
            phs = [t for t in tm if lowercase(t) in _PHASE_TERMINALS]
            length(phs) == 1 || (mergeable = false; break)

            ph = lowercase(phs[1])
            haskey(phase_data, ph) && (mergeable = false; break)  # phase conflict

            k    = findfirst(==(phs[1]), tm)
            vmag = Float64.(get(vs, "v_magnitude", Float64[]))
            vang = Float64.(get(vs, "v_angle",     Float64[]))
            (k !== nothing && length(vmag) >= k && length(vang) >= k) ||
                (mergeable = false; break)

            phase_data[ph] = (vmag[k], vang[k])
            push!(member_ids, id)
        end

        (mergeable && length(phase_data) >= 2) || continue

        order = [p for p in _PHASE_TERMINALS if haskey(phase_data, p)]

        # Angle-coherence guard: only collapse a bank whose per-phase angles form
        # a balanced ±120° rotation — that is the evidence they are one source.
        seq = _phase_sequence_class(order, phase_data)
        if seq === :incoherent
            push!(declined_notes, Dict{String,Any}(
                "bus"        => bus,
                "candidates" => sort(member_ids),
                "phases"     => order,
                "reason"     => "per-phase voltage angles are not a balanced " *
                                "±120° rotation (within $(round(rad2deg(_PHASE_BALANCE_TOL_RAD); digits=1))°); " *
                                "left unmerged.",
            ))
            continue
        end

        # Assemble the merged polyphase source (physical label order: a,b,c,n).
        tm_new  = vcat(order, "n")
        vmag_new = vcat([phase_data[p][1] for p in order], 0.0)
        vang_new = vcat([phase_data[p][2] for p in order], 0.0)

        keep_id = "source" in member_ids ? "source" : first(sort(member_ids))
        template = sources[keep_id]

        for id in member_ids
            delete!(sources, id)
        end

        template["bus"]          = bus
        template["terminal_map"] = tm_new
        template["v_magnitude"]  = vmag_new
        template["v_angle"]      = vang_new
        template["configuration"] = "WYE"
        sources[keep_id] = template

        note = Dict{String,Any}(
            "bus"      => bus,
            "merged"   => sort(member_ids),
            "into"     => keep_id,
            "phases"   => order,
            "sequence" => string(seq),
        )
        if seq === :negative
            note["warning"] = "angle rotation is negative-sequence but phases are " *
                              "labelled a→b→c — likely a phase-labelling error; " *
                              "merged faithfully (angles preserved), verify the source."
        end
        push!(merged_notes, note)
    end

    if !isempty(merged_notes) || !isempty(declined_notes)
        meta = get!(net, "_meta", Dict{String,Any}())
        entry = Dict{String,Any}(
            "message" => "Per-phase single-phase OpenDSS voltage sources sharing a " *
                         "bus were merged into one polyphase source (Circuit + " *
                         "per-phase VSource idiom).",
        )
        isempty(merged_notes)   || (entry["groups"]   = merged_notes)
        isempty(declined_notes) || (entry["declined"] = declined_notes)
        meta["merged_voltage_sources"] = entry
    end
end
