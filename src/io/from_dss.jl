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
                  name::Union{AbstractString,Nothing}=nothing,
                  frequency::Union{Real,Nothing}=nothing)::Dict{String,Any}

    abspath_dss = abspath(path)
    isfile(abspath_dss) || throw(ArgumentError("DSS file not found: $abspath_dss"))

    # PowerIO parses to a MulticonductorNetwork handle, then emits BMOPF JSON
    # plus a list of fidelity-loss warnings.
    dn = PowerIO.parse_file(PowerIO.MulticonductorNetwork, abspath_dss)
    json_raw, warnings_list = PowerIO.to_format(dn, "bmopf")

    if isempty(json_raw)
        throw(ErrorException("PowerIO produced no output for $path"))
    end

    net = parse_bmopf(json_raw; from_string=true)
    _canonicalize_identifiers!(net)
    _remap_opendss_terminals!(net)
    _merge_phase_voltage_sources!(net)
    _normalize_center_tap_transformers!(net)
    _normalize_nwinding_delta_roll!(net)
    _recover_transformer_params_from_pmd!(net, dn)

    # Store conversion warnings so callers can inspect fidelity losses, and
    # surface an aggregate @warn so the losses are visible even when the
    # caller never looks at _meta.
    net["_meta"] = get(net, "_meta", Dict{String,Any}())
    net["_meta"]["powerio_warnings"] = collect(String, warnings_list)
    net["_meta"]["powerio_source"]   = abspath_dss

    # Capture the system frequency PowerIO parsed from the DSS circuit
    # (OpenDSS `Set DefaultBaseFreq`, itself defaulting to 60 Hz), or the
    # caller's override. OpenDSS files carry no explicit frequency very
    # often, so preserving it here keeps the case self-contained. Never used
    # to rescale — it is metadata that also feeds the frequency-consistency
    # checks. If PowerIO cannot report a base frequency, fall back silently
    # to the override or leave meta.frequency unset.
    f_powerio = try
        Float64(PowerIO.base_frequency(dn))
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
        n_w = length(warnings_list)
        preview = join(first(collect(String, warnings_list), 5), "\n  ")
        n_w > 5 && (preview *= "\n  … and $(n_w - 5) more")
        @warn "from_dss: $n_w piece(s) of OpenDSS information could not be " *
              "represented in BMOPF (full list on net[\"_meta\"][\"powerio_warnings\"]):\n  " *
              preview
    end
    # rneut/xneut carry the transformer-INTERNAL winding neutral grounding;
    # PowerIO drops them from every export it produces (bmopf AND pmd), so the
    # affected neutral is left ungrounded — physically wrong for an
    # impedance-grounded wye. BMOPF has fields for it; surface a targeted,
    # actionable warning on top of the generic dropped-field list.
    if any(occursin("`rneut`", String(w)) || occursin("`xneut`", String(w))
           for w in warnings_list)
        @warn "from_dss: OpenDSS transformer rneut/xneut (internal winding " *
              "neutral grounding) was dropped by PowerIO — the affected " *
              "neutral(s) are left UNGROUNDED. Set r_neutral_from/to and " *
              "x_neutral_from/to on the transformer(s) manually; BMOPF models " *
              "the internal grounding branch (see the schema)."
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

"""
    _normalize_nwinding_delta_roll!(net)

Set `delta_roll = -1` on every DELTA winding of a PowerIO-exported `n_winding`
transformer that does not already carry the field.

PowerIO's bmopf export emits `n_winding` transformers directly (since v0.6) but
does not populate BMOPF's `delta_roll` field, so the winding falls back to the
`n_winding` model default of `+1`. OpenDSS's standard delta connection — the only
one PowerIO produces from a `.dss` deck — corresponds to `delta_roll = -1` (the
−30° vector-group rotation). This mirrors the convention BMOPF's own pmd
reconstruction sets explicitly (see `_reconstruct_nwinding_from_pmd!`), so a
natively-exported unit agrees with OpenDSS and with the hand-built fixtures. An
explicit `delta_roll` (should PowerIO ever emit one) is left untouched.
"""
function _normalize_nwinding_delta_roll!(net::Dict{String,Any})
    xfmr = get(net, "transformer", nothing)
    xfmr isa Dict || return
    nwd = get(xfmr, "n_winding", nothing)
    nwd isa Dict || return
    for (_, comp) in nwd
        comp isa Dict || continue
        windings = get(comp, "windings", nothing)
        windings isa Vector || continue
        for w in windings
            w isa Dict || continue
            get(w, "configuration", nothing) == "DELTA" || continue
            haskey(w, "delta_roll") || (w["delta_roll"] = -1)
        end
    end
end

"""
    _normalize_center_tap_transformers!(net)

Convert PowerIO's `center_tap` encoding to BMOPF's canonical convention.

PowerIO emits a split-phase (centre-tapped) transformer with the LV
`terminal_map_to` listing the two legs first and the centre tap (neutral) **last**
— e.g. `["a","b","n"]` — and `v_nom_to` set to the **full** secondary voltage
(the sum of both half-windings, e.g. 240 V for a 120-0-120 transformer).

The BMOPF OPF model ([`to_ybus`](@ref)'s `_yprim_center_tap`), the schema, the
spec-conformance arity `(2,3)` and every hand-authored fixture instead expect the
centre tap in the **middle** — `[leg1, "n", leg2]` — and `v_nom_to` to be the
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

        # PowerIO's v_nom_to is the full secondary; the model wants per-leg.
        v = get(c, "v_nom_to", nothing)
        v isa Real && (c["v_nom_to"] = v / 2)
    end
    return net
end

# Transformer subtypes whose electrical parameters we re-derive from the `pmd`
# export. PowerIO's `bmopf` export is lossy for these: it drops the no-load shunt
# (every subtype), drops fixed off-nominal taps (every subtype), collapses the
# 3-winding `center_tap` leakage, and mis-refers the delta-side leakage of
# `delta_wye`. Regulators (`single_phase_autotransformer`, `open_delta_regulator`)
# are left as-is. PowerIO emits NO `n_winding` transformers at all — any unit
# outside the four two-bus subtypes (3-phase 3+-winding, Dd, …) is dropped from
# the bmopf export entirely and is reconstructed from the pmd record by
# `_reconstruct_nwinding_from_pmd!`.
const _PMD_RECOVER_SUBTYPES = ("center_tap", "single_phase", "wye_delta", "delta_wye")

# First scalar of a pmd per-phase tap vector. BMOPF carries one tap per
# transformer side, so non-uniform per-phase taps collapse to phase 1 (warned).
function _pmd_tap_scalar(tm, tid, wdg)::Float64
    v = tm isa AbstractVector ? Float64.(tm) : Float64[Float64(tm)]
    isempty(v) && return 1.0
    all(x -> isapprox(x, v[1]; atol=1e-9), v) ||
        @warn "from_dss: transformer '$tid' winding $wdg has non-uniform per-phase " *
              "taps $v; using the phase-1 tap $(v[1])."
    v[1]
end

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
  * Fixed off-nominal taps — recovered from the pmd `tm_set` as the single
    from-side `tap` multiplier `t₁/t₂` (the bmopf export drops `taps=`
    entirely). `tap_min`/`tap_max` are deliberately NOT populated from OpenDSS
    `mintap`/`maxtap`: in BMOPF their presence opts the tap into optimisation,
    whereas in OpenDSS they are ubiquitous data defaults.

Transformers the bmopf export dropped entirely (3-phase 3+-winding units, Dd,
…) are rebuilt as `n_winding` via [`_reconstruct_nwinding_from_pmd!`](@ref) and
listed under `net["_meta"]["recovered_n_winding"]`.

No-op when there are no transformers in either export.
"""
function _recover_transformer_params_from_pmd!(net::Dict{String,Any}, dn)
    # The bmopf export may lack the "transformer" key entirely when its ONLY
    # transformer(s) were dropped (e.g. a single 3-winding unit), so the pmd
    # export must be consulted before concluding there is nothing to recover.
    had_xfmr_key = haskey(net, "transformer")
    xfmr = get!(net, "transformer", Dict{String,Any}())
    if !(xfmr isa Dict)
        return net
    end

    local pmd
    try
        pmd_raw, _ = PowerIO.to_format(dn, "pmd")
        pmd = JSON3.read(pmd_raw)
    catch err
        @warn "from_dss: could not fetch PowerIO `pmd` export to recover " *
              "transformer leakage/core shunt; losses and split-phase legs may " *
              "be inaccurate." err
        had_xfmr_key || delete!(net, "transformer")
        return net
    end

    pmd_tr = get(pmd, :transformer, nothing)
    if pmd_tr === nothing
        had_xfmr_key || delete!(net, "transformer")
        return net
    end
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

            # No-load (magnetising) shunt — OpenDSS places it across the
            # WINDING-2 (to-side) coil, referred to winding 2's coil voltage
            # (verified against its Yprim). V_stamp is that coil voltage:
            # line-to-neutral (vm_nom₂/√3) for a WYE winding 2 (`delta_wye`), and
            # the full line-to-line / winding voltage (vm_nom₂) otherwise
            # (`single_phase`, `center_tap`, `wye_delta`). Both the resistive
            # core loss (`noloadloss` → g_no_load) and the inductive magnetising
            # branch (`cmag` → b_no_load, NEGATIVE) are recovered — the
            # across-coil placement carries the susceptance cleanly, unlike the
            # earlier phase-to-ground stamp. pmd `noloadloss`/`cmag` are
            # fractions of the rated power.
            s1   = Float64(smn[1]) * 1e3
            vstp = Float64(vmn[2]) * 1e3 / (subtype == "delta_wye" ? sqrt(3) : 1.0)
            c["g_no_load"] =  Float64(get(t, :noloadloss, 0.0)) * s1 / vstp^2
            c["b_no_load"] = -Float64(get(t, :cmag, 0.0))       * s1 / vstp^2

            # Fixed off-nominal taps. PowerIO's bmopf export drops OpenDSS
            # `taps=` entirely (with only a warning), silently solving at the
            # nominal ratio, even though BMOPF has a `tap` field. Recover from
            # the pmd `tm_set`: BMOPF's single from-side multiplier carries
            # t₁/t₂ — exact for the ideal ratio; when t₂ ≠ 1 the to-winding
            # leakage referral stays at nominal turns (warned, small effect).
            # (`tap_min`/`tap_max` are NOT populated from OpenDSS mintap/maxtap:
            # in BMOPF their presence opts the tap into OPTIMISATION, whereas in
            # OpenDSS they are ubiquitous defaults, 0.9/1.1 on every unit.)
            tms = get(t, :tm_set, nothing)
            if tms isa AbstractVector && length(tms) >= 2 &&
               Float64(get(c, "tap", 1.0)) == 1.0
                t1 = _pmd_tap_scalar(tms[1], tid, 1)
                t2 = _pmd_tap_scalar(tms[2], tid, 2)
                if subtype == "center_tap" && length(tms) >= 3
                    t3 = _pmd_tap_scalar(tms[3], tid, 3)
                    isapprox(t2, t3; atol=1e-9) ||
                        @warn "from_dss: center_tap '$tid' has unequal LV leg " *
                              "taps ($t2, $t3); using the leg-1 tap."
                end
                isapprox(t2, 1.0; atol=1e-9) ||
                    @warn "from_dss: transformer '$tid' has an off-nominal " *
                          "TO-side tap ($t2), folded into the single from-side " *
                          "ratio (tap = t₁/t₂) — exact for the ideal ratio; the " *
                          "to-winding leakage referral stays at nominal turns."
                tap = t1 / t2
                isapprox(tap, 1.0; atol=1e-12) || (c["tap"] = tap)
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

    # Transformers PowerIO's bmopf export dropped ENTIRELY — any 3-phase unit
    # with 3+ windings, and any connection set outside the four two-bus
    # subtypes (e.g. Dd) — are rebuilt as BMOPF `n_winding` from the pmd
    # record, which carries everything needed.
    present = Set{String}()
    for (_, coll) in xfmr
        coll isa Dict || continue
        for id in keys(coll)
            push!(present, lowercase(String(id)))
        end
    end
    recovered = String[]
    for (k, t) in pairs(pmd_tr)
        id = lowercase(String(k))
        nm = get(t, :name, nothing)
        nm_l = nm === nothing ? id : lowercase(String(nm))
        (id in present || nm_l in present) && continue
        _reconstruct_nwinding_from_pmd!(net, nm_l, t) && push!(recovered, nm_l)
    end
    if !isempty(recovered)
        meta = get!(net, "_meta", Dict{String,Any}())
        meta["recovered_n_winding"] = sort(recovered)
        @info "from_dss: $(length(recovered)) transformer(s) dropped by PowerIO's " *
              "bmopf export were reconstructed as `n_winding` from the pmd " *
              "export: $(join(sort(recovered), ", "))"
    end

    (had_xfmr_key || !isempty(xfmr)) || delete!(net, "transformer")
    return net
end

"""
    _reconstruct_nwinding_from_pmd!(net, tid, t) -> Bool

Rebuild a transformer that PowerIO's `bmopf` export dropped (any 3-phase unit
with 3+ windings, or a connection pattern outside the four two-bus subtypes,
e.g. Dd) as a BMOPF `n_winding` transformer from its `pmd` record `t`.

Mapping — mirrors the hand-built `n_winding` fixtures validated against OpenDSS
in `test/powerflow_comparison_tests.jl`:

  * winding k: `bus`, `configuration` from pmd; `terminal_map` in natural phase
    order (`a`,`b`,`c`[,`n`]). PMD's rolled `connections` + `polarity` encoding
    of the OpenDSS vector group is deliberately NOT copied — the BMOPF
    `n_winding` model expresses the standard OpenDSS delta arrangement as
    `delta_roll = -1` on the DELTA winding(s) with natural terminal order.
  * `v_nom` = winding kV·tap — line-to-neutral (kv/√3) for a WYE winding, the
    coil line-to-line voltage for DELTA. Folding the fixed tap into the
    effective winding voltage scales the leakage referral by tap²
    (turns-scaled, as OpenDSS). Only 3-phase windings are reconstructed —
    dropped 1-/2-phase units (e.g. L-L regulator banks) refuse loudly.
  * `r_winding` = rw·z_coil with z_coil = n_ph·v_nom²/s_rating (the per-winding
    COIL base, see `src/io/nwinding.jl`); `x_sc["i_j"]` = xsc·z_coil₁, pmd pair
    order (1,2),(1,3),…,(1,n),(2,3),….
  * `g_no_load`/`b_no_load` = per-coil admittances on WINDING 2's coil base
    (`noloadloss`/`−cmag · S/(n_ph₂·v_nom₂²)`) — OpenDSS places the exciting
    branch on winding 2 (verified against its Yprim). The n_winding builders
    stamp them once per phase leg, so the total core loss is noloadloss·S;
    b_no_load is inductive (negative).

Buses missing from the bmopf export (possible when a bus served only the
dropped transformer) are synthesised from the winding terminal map, ungrounded.
Returns `false` (with a warning) when the pmd record is incomplete.
"""
function _reconstruct_nwinding_from_pmd!(net::Dict{String,Any}, tid::String, t)::Bool
    buses = get(t, :bus, nothing);   conf = get(t, :configuration, nothing)
    conns = get(t, :connections, nothing)
    vmn   = get(t, :vm_nom, nothing); smn = get(t, :sm_nom, nothing)
    rw    = get(t, :rw, nothing);     xsc = get(t, :xsc, nothing)
    ok = all(x -> x isa AbstractVector && !isempty(x),
             (buses, conf, conns, vmn, smn, rw, xsc))
    nW = ok ? length(buses) : 0
    if !ok || nW < 2 || length(conf) < nW || length(conns) < nW ||
       length(vmn) < nW || length(rw) < nW || length(xsc) < binomial(nW, 2)
        @warn "from_dss: transformer '$tid' was dropped by PowerIO's bmopf export " *
              "and its pmd record is incomplete; cannot reconstruct — the unit is " *
              "MISSING from the network."
        return false
    end
    tms = get(t, :tm_set, nothing)
    tapk(k) = (tms isa AbstractVector && length(tms) >= k) ?
              _pmd_tap_scalar(tms[k], tid, k) : 1.0
    s_rating = Float64(smn[1]) * 1e3           # kVA → VA

    phmap = Dict("1" => "a", "2" => "b", "3" => "c")
    windings = Dict{String,Any}[]
    for k in 1:nW
        terms  = [string(Int(c)) for c in conns[k]]
        phases = sort([c for c in terms if haskey(phmap, c)])
        has_n  = any(c -> c in ("4", "5"), terms)
        # Only 3-phase windings map cleanly onto the n_winding model (the
        # validated class: YYY/Dyn/Dyyn). A dropped 1- or 2-phase unit (e.g. a
        # bank of L-L regulator transformers) would need a different mapping —
        # the kv/√3 and per-leg conventions below do not apply — so refuse
        # loudly rather than build a wrong unit.
        if length(phases) != 3
            @warn "from_dss: transformer '$tid' was dropped by PowerIO's bmopf " *
                  "export and winding $k is not 3-phase; only 3-phase windings " *
                  "can be reconstructed as n_winding — the unit is MISSING " *
                  "from the network."
            return false
        end
        cfg    = uppercase(String(conf[k]))
        n_ph   = length(phases)
        kv_eff = Float64(vmn[k]) * 1e3 * tapk(k)
        v_nom  = (cfg == "WYE" && n_ph >= 2) ? kv_eff / sqrt(3) : kv_eff
        z_coil = n_ph * v_nom^2 / s_rating
        w = Dict{String,Any}(
            "bus"           => lowercase(String(buses[k])),
            "terminal_map"  => vcat([phmap[c] for c in phases],
                                    has_n ? ["n"] : String[]),
            "v_nom"         => v_nom,
            "configuration" => cfg,
            "r_winding"     => Float64(rw[k]) * z_coil)
        cfg == "DELTA" && (w["delta_roll"] = -1)
        push!(windings, w)
    end

    n_ph1  = count(x -> lowercase(x) in ("a", "b", "c"), windings[1]["terminal_map"])
    v_nom1 = Float64(windings[1]["v_nom"])
    z1     = n_ph1 * v_nom1^2 / s_rating
    x_sc = Dict{String,Any}()
    idx = 0
    for i in 1:nW-1, j in i+1:nW
        idx += 1
        x_sc["$(i)_$(j)"] = Float64(xsc[idx]) * z1
    end

    # No-load (magnetising) shunt on WINDING 2's coil — OpenDSS places the
    # exciting branch on winding 2 (verified against its Yprim), so g/b_no_load
    # are the PER-COIL admittances on winding 2's coil base (stamped once per
    # phase leg; total core loss = noloadloss·S). b_no_load is inductive
    # (negative). z_coil₂ = n_ph₂·v_nom₂² / S.
    n_ph2  = count(x -> lowercase(x) in ("a", "b", "c"), windings[2]["terminal_map"])
    v_nom2 = Float64(windings[2]["v_nom"])
    zc2    = n_ph2 * v_nom2^2 / s_rating
    nl = Float64(get(t, :noloadloss, 0.0))
    cm = Float64(get(t, :cmag, 0.0))
    xf = Dict{String,Any}(
        "windings"  => windings,
        "x_sc"      => x_sc,
        "s_rating"  => s_rating,
        "g_no_load" =>  nl > 0 ? nl * s_rating / zc2 : 0.0,
        "b_no_load" => -cm * s_rating / zc2)

    busd = get!(net, "bus", Dict{String,Any}())
    for w in windings
        b = get(busd, w["bus"], nothing)
        if b === nothing
            b = Dict{String,Any}("terminal_names" => copy(w["terminal_map"]))
            "n" in w["terminal_map"] && (b["neutral_terminal"] = "n")
            busd[w["bus"]] = b
            @warn "from_dss: bus '$(w["bus"])' was absent from the bmopf export " *
                  "(it served only the dropped transformer '$tid'); synthesised it " *
                  "from the winding terminal map, UNGROUNDED — check grounding."
        else
            # The dropped transformer was the only element using some of this
            # bus's conductors, so the bmopf export omitted them from
            # terminal_names — reinstate the winding's terminals.
            names  = string.(get(b, "terminal_names", String[]))
            absent = [t for t in w["terminal_map"] if !(t in names)]
            if !isempty(absent)
                b["terminal_names"] = vcat(names, absent)
                "n" in absent && !haskey(b, "neutral_terminal") &&
                    (b["neutral_terminal"] = "n")
            end
        end
    end

    nwd = get!(net["transformer"], "n_winding", Dict{String,Any}())
    nwd[tid] = xf
    return true
end

# Phase terminals in positive-sequence rotation (a precedes b precedes c). A
# merged source is always emitted in this order regardless of the order the
# per-phase VSource objects appeared in the OpenDSS file.
const _PHASE_TERMINALS = ("a", "b", "c")

# Per-phase voltage angles must sit within this tolerance of a balanced ±120°
# rotation (or 0°) for a bank of single-phase sources to count as one coherent
# polyphase source. Loose enough to admit mild export imbalance.
const _PHASE_BALANCE_TOL_RAD = deg2rad(30)

# Tighter tolerance for the 90° (quadrature / two-phase) and 180° (anti-phase /
# split-phase) classes: the canonical 90° and 120° separations are only 30°
# apart, so a wide band would conflate them.
const _PHASE_SEPARATION_TOL_RAD = deg2rad(15)

# Wrap an angle (radians) to (-π, π].
_wrap_pi(x::Real) = (y = mod(x + π, 2π) - π; y == -π ? π : y)

# Classify one wrapped successive angle difference `d` (rad, in (-π, π]) into a
# canonical phase separation by nearest canonical magnitude {0, 90, 120, 180}°.
# The 120°/0° classes keep the lenient ±30° band; 90°/180° use ±15° so the four
# canonical separations stay mutually distinguishable. Quadrature is tested
# before 120° so a difference closer to 90° than 120° (|d| ≤ ~105°) resolves to
# quadrature rather than being swallowed by the wide 120° band.
function _separation_of_diff(d::Real)::Symbol
    a = abs(d)
    if a <= _PHASE_BALANCE_TOL_RAD                      # ≈ 0°   (±30°)
        return :zero
    elseif abs(a - π/2) <= _PHASE_SEPARATION_TOL_RAD    # ≈ 90°  (±15°)
        return :quadrature
    elseif abs(a - 2π/3) <= _PHASE_BALANCE_TOL_RAD      # ≈ 120° (±30°)
        return d < 0 ? :positive : :negative            # a→b→c lags ⇒ positive
    elseif abs(a - π) <= _PHASE_SEPARATION_TOL_RAD      # ≈ 180° (±15°)
        return :anti_phase
    else
        return :incoherent
    end
end

"""
    _phase_separation_class(angles) -> Symbol

Classify the phasor arrangement of a label-ordered set of phase angles (radians)
from its successive differences. Returns the common separation class, or
`:incoherent` when the differences disagree or match no canonical separation:

- `:zero`       — all phases at ≈ the same angle (zero-sequence / co-phasal).
- `:quadrature` — ≈ 90° separation (two-phase, e.g. a Scott-T secondary).
- `:positive`   — ≈ 120° lag per successive phase (standard a→b→c rotation).
- `:negative`   — ≈ 120° lead (reversed rotation).
- `:anti_phase` — ≈ 180° separation (split-phase / single-phase three-wire legs).
- `:incoherent` — none of the above consistently.

Ordering is always by physical phase label, never by angle.
"""
function _phase_separation_class(angles::AbstractVector{<:Real})::Symbol
    length(angles) >= 2 || return :incoherent
    diffs   = [_wrap_pi(angles[i+1] - angles[i]) for i in 1:length(angles)-1]
    classes = map(_separation_of_diff, diffs)
    all(==(first(classes)), classes) ? first(classes) : :incoherent
end

"""
    _phase_sequence_class(order, phase_data) -> Symbol

Classify the phasor arrangement of a label-ordered (`a`,`b`,`c`) bank from its
per-phase angles by delegating to [`_phase_separation_class`](@ref). Ordering is
always by physical phase label, never by angle — the angles only decide which
arrangement the bank carries (and whether it is self-consistent enough to merge).
"""
function _phase_sequence_class(order::Vector{String},
                               phase_data::Dict{String,Tuple{Float64,Float64}})::Symbol
    length(order) >= 2 || return :incoherent
    _phase_separation_class([phase_data[p][2] for p in order])
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

        # Angle-coherence guard: collapse a bank whose per-phase angles form a
        # 3-phase-style arrangement (positive/negative/zero rotation about the
        # a,b,c labels). Quadrature (90°, two-phase) and anti-phase (180°,
        # split-phase) banks are NOT 3-phase sources and are left unmerged, as is
        # an incoherent set.
        seq = _phase_sequence_class(order, phase_data)
        if seq in (:incoherent, :quadrature, :anti_phase)
            reason = seq === :quadrature ?
                "per-phase voltage angles are a quadrature (≈90°, two-phase) set, " *
                "not a 3-phase rotation; left unmerged." :
                seq === :anti_phase ?
                "per-phase voltage angles are anti-phase (≈180°, split-phase) set, " *
                "not a 3-phase rotation; left unmerged." :
                "per-phase voltage angles are not a balanced ±120° rotation " *
                "(within $(round(rad2deg(_PHASE_BALANCE_TOL_RAD); digits=1))°); left unmerged."
            push!(declined_notes, Dict{String,Any}(
                "bus"        => bus,
                "candidates" => sort(member_ids),
                "phases"     => order,
                "arrangement"=> string(seq),
                "reason"     => reason,
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
        elseif seq === :zero
            note["warning"] = "all phases share one angle — zero-sequence; not a " *
                              "valid 3-phase supply; merged faithfully (angles " *
                              "preserved), verify the source."
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
