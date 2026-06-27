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
    _normalize_center_tap_transformers!(net)
    _recover_transformer_params_from_pmd!(net, dn)

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
                         "generator", "voltage_source", "shunt", "inverter",
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
    for ct in ("load", "generator", "voltage_source", "shunt", "inverter", "capacitor")
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
        # Remap a `perfectly_grounded_terminals` reference that PowerIO emits with
        # the raw OpenDSS *neutral* node number ("4"). The earth terminal ("5")
        # is handled by the earth-routing path below, so it is intentionally not
        # turned into a solid neutral ground here.
        let g = get(bus, "perfectly_grounded_terminals", nothing)
            g isa Vector &&
                (bus["perfectly_grounded_terminals"] =
                     unique(t == "4" ? "n" : string(t) for t in g))
        end
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
    # Single-bus components: load, generator, voltage_source, shunt, capacitor
    for comp_type in ("load", "generator", "voltage_source", "shunt", "capacitor")
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

"""
    _normalize_center_tap_transformers!(net)

Convert PowerIO's `center_tap` encoding to BMOPF's canonical convention.

PowerIO emits a split-phase (centre-tapped) transformer with the LV
`terminal_map_to` listing the two legs first and the centre tap (neutral) **last**
— e.g. `["a","b","n"]` — and `v_ref_to` set to the **full** secondary voltage
(the sum of both half-windings, e.g. 240 V for a 120-0-120 transformer).

The BMOPF OPF model ([`to_ybus`](@ref)'s `_yprim_center_tap`), the schema, the
spec-conformance arity `(2,3)` and every hand-authored fixture instead expect the
centre tap in the **middle** — `[leg1, "n", leg2]` — and `v_ref_to` to be the
**per-leg** (half-winding) voltage, since the turns ratio is computed per leg.
Left unconverted, the connection matrix wires the wrong nodes and the turns ratio
is 2× off, giving leg voltages 2–4× too high.

Both corrections are tied to the same detected condition — the neutral terminal
not already sitting in the middle — so the function is idempotent and a no-op on
data already in canonical form (e.g. hand-built nets or a future PowerIO that
adopts the BMOPF convention).
"""
function _normalize_center_tap_transformers!(net::Dict{String,Any})
    xfmr = get(net, "transformer", nothing)
    xfmr isa Dict || return net
    ct = get(xfmr, "center_tap", nothing)
    ct isa Dict || return net

    for (_, c) in ct
        c isa Dict || continue
        tm = get(c, "terminal_map_to", nothing)
        (tm isa Vector && length(tm) == 3) || continue
        tm = string.(tm)

        # PowerIO convention: centre tap (neutral) listed last instead of middle.
        # Canonical form already has "n" in the middle → leave untouched (no-op).
        tm[2] == "n" && continue
        ni = findfirst(==("n"), tm)
        ni === nothing && continue      # no identifiable centre tap; leave as-is

        legs = [t for t in tm if t != "n"]
        c["terminal_map_to"] = [legs[1], "n", legs[2]]

        # PowerIO's v_ref_to is the full secondary; the model wants per-leg.
        v = get(c, "v_ref_to", nothing)
        v isa Real && (c["v_ref_to"] = v / 2)
    end
    return net
end

# Transformer subtypes whose electrical parameters we re-derive from the `pmd`
# export. PowerIO's `bmopf` export is lossy for these: it drops the no-load shunt
# (every subtype), collapses the 3-winding `center_tap` leakage, and mis-refers
# the delta-side leakage of `delta_wye`. Regulators (`single_phase_autotransformer`,
# `open_delta_regulator`) and the already-faithful `n_winding` path are left as-is.
const _PMD_RECOVER_SUBTYPES = ("center_tap", "single_phase", "wye_delta", "delta_wye")

"""
    _recover_transformer_params_from_pmd!(net, dn)

Re-derive transformer leakage and the no-load (core) shunt from PowerIO's `pmd`
export, which retains the full electrical detail the `bmopf` export discards.

The `bmopf` export drops `g_no_load`/`b_no_load` for every transformer, collapses
the `center_tap` 3-winding leakage to a lossy 2-winding reduction (full `XHL` on
the HV side, `x_series_to = 0`), and mis-refers the `delta_wye` delta-side
leakage. The `pmd` export keeps the pairwise short-circuit set (`xsc`), the
per-winding resistances (`rw`), the winding bases (`vm_nom`/`sm_nom`), and the
core-loss fractions (`noloadloss`/`cmag`).

For each transformer of a subtype in [`_PMD_RECOVER_SUBTYPES`](@ref):

  * No-load shunt — `g_no_load = noloadloss·S₁ / V_stamp²` (core loss), where
    `V_stamp` is the phase-to-ground stamping voltage (`vm_nom₁` for a 1-phase
    from-side, `vm_nom₁/√3` for a 3-phase one). The magnetising susceptance is
    left at zero (see the code) and the shunt is skipped for phase-to-phase
    single-phase units, whose magnetising branch the OPF cannot place correctly.
  * `center_tap` (3-winding) — symmetric star arms
    `X1_star=(XHL+XHT−XLT)/2`, `X2_star=(XHL+XLT−XHT)/2`, each referred to its
    own winding base; resistances per winding.
  * 2-winding (`single_phase`/`wye_delta`/`delta_wye`) — half the through
    reactance referred to each side (`x_series_{from,to}=XHL/2·Z_base_{from,to}`)
    and the per-winding resistances; equivalent to the Γ lump but correctly
    referred on both sides.

No-op when there are no matching transformers.
"""
function _recover_transformer_params_from_pmd!(net::Dict{String,Any}, dn)
    xfmr = get(net, "transformer", nothing)
    xfmr isa Dict || return net
    any(haskey(xfmr, s) && !isempty(xfmr[s]) for s in _PMD_RECOVER_SUBTYPES) || return net

    local pmd
    try
        pmd_raw, _ = PowerIO.to_format(dn, "pmd")
        pmd = JSON3.read(pmd_raw)
    catch err
        @warn "from_dss: could not fetch PowerIO `pmd` export to recover " *
              "transformer leakage/core shunt; losses and split-phase legs may " *
              "be inaccurate." err
        return net
    end

    pmd_tr = get(pmd, :transformer, nothing)
    pmd_tr === nothing && return net
    # Index pmd transformers by their lower-cased key (and `name` field when
    # present) for matching against the canonicalised bmopf transformer keys.
    by_id = Dict{String,Any}()
    for (k, t) in pairs(pmd_tr)
        by_id[lowercase(String(k))] = t
        nm = get(t, :name, nothing)
        nm === nothing || (by_id[lowercase(String(nm))] = t)
    end

    zbase(vm, sm) = (Float64(vm) * 1e3)^2 / (Float64(sm) * 1e3)   # Ω, sm in kVA

    for subtype in _PMD_RECOVER_SUBTYPES
        coll = get(xfmr, subtype, nothing)
        coll isa Dict || continue
        for (tid, c) in coll
            c isa Dict || continue
            t = get(by_id, lowercase(String(tid)), nothing)
            t === nothing && continue
            xsc = get(t, :xsc, nothing);    rw  = get(t, :rw, nothing)
            vmn = get(t, :vm_nom, nothing); smn = get(t, :sm_nom, nothing)
            (xsc !== nothing && rw !== nothing && vmn !== nothing && smn !== nothing) || continue
            length(rw) >= 2 && length(vmn) >= 2 && length(smn) >= 2 && length(xsc) >= 1 || continue

            # No-load (core) shunt — phase-to-ground referral on the from-side.
            # `vm_nom` is the winding voltage: for a 1-phase L-N unit
            # (`single_phase`, `center_tap`) it IS the stamping voltage; for a
            # 3-phase wye/delta from-side the per-phase stamping voltage is the
            # line-to-ground value vm_nom/√3. The OPF stamps the shunt
            # phase-to-ground, so a phase-to-PHASE single-phase unit (no neutral
            # on the from-side, e.g. a SWER isolating transformer) would have its
            # magnetising branch placed wrong — skip the shunt there (a small
            # effect) rather than inject it across the wrong nodes.
            ll_single = subtype == "single_phase" &&
                        !("n" in string.(get(c, "terminal_map_from", String[])))
            if !ll_single
                three_phase = subtype in ("wye_delta", "delta_wye")
                s1   = Float64(smn[1]) * 1e3
                vstp = Float64(vmn[1]) * 1e3 / (three_phase ? sqrt(3) : 1.0)
                c["g_no_load"] = Float64(get(t, :noloadloss, 0.0)) * s1 / vstp^2
                # Only the resistive `g_no_load` (core loss) is recovered. The
                # magnetising susceptance `cmag` is left out (b_no_load = 0): it
                # affects only reactive power / voltage at the per-mille level
                # here, and the OPF's phase-to-ground shunt sign convention does
                # not cleanly carry an inductive magnetising branch.
                c["b_no_load"] = 0.0
            end

            # Leakage is only re-derived where the bmopf export is actually
            # wrong: `center_tap` (3-winding leakage dropped) and `delta_wye`
            # (delta-side leakage referred to the wrong base). `single_phase`
            # and `wye_delta` export correct leakage, so leave them untouched.
            z_fr = zbase(vmn[1], smn[1])
            z_to = zbase(vmn[2], smn[2])
            if subtype == "center_tap" && length(xsc) >= 3
                XHL, XHT, XLT = Float64(xsc[1]), Float64(xsc[2]), Float64(xsc[3])
                c["r_series_from"] = Float64(rw[1]) * z_fr
                c["x_series_from"] = (XHL + XHT - XLT) / 2 * z_fr
                c["r_series_to"]   = Float64(rw[2]) * z_to
                c["x_series_to"]   = (XHL + XLT - XHT) / 2 * z_to
            elseif subtype == "delta_wye"
                # Split the through reactance, referred to each winding base.
                XHL = Float64(xsc[1])
                c["r_series_from"] = Float64(rw[1]) * z_fr
                c["x_series_from"] = XHL / 2 * z_fr
                c["r_series_to"]   = Float64(rw[2]) * z_to
                c["x_series_to"]   = XHL / 2 * z_to
            end
        end
    end
    return net
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
