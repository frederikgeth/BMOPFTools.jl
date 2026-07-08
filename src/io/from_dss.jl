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
    _normalize_transformer_no_load_shunts!(net, dn)

    # Record the terminal-role convention explicitly (phases a/b/c…, neutral n;
    # no earth wire — the OpenDSS earth node is routed to neutral, ground stays
    # implicit). from_dss knows the mapping it just applied, so this is declared
    # rather than left to be inferred downstream (W.CONV.TERMINAL_ROLES_INFERRED).
    get!(net, "terminal_conventions", _terminal_conventions_dict(net))

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
                     unique(t == "4" ? "n" : string(t)
                            for t in g if string(t) != "5"))
            # "5" is the earth terminal: it is routed to the neutral and recorded
            # under _meta (grounded THROUGH the neutral, not solidly), so it must
            # be dropped here rather than left as a dangling reference to a
            # terminal that "5"→"n" removed from terminal_names.
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

const _NO_LOAD_SHUNT_SUBTYPES = ("center_tap", "single_phase", "wye_delta", "delta_wye")

function _normalize_transformer_no_load_shunts!(net::Dict{String,Any}, dn)
    xfmr = get(net, "transformer", nothing)
    xfmr isa Dict || return net
    any(get(xfmr, subtype, nothing) isa Dict for subtype in _NO_LOAD_SHUNT_SUBTYPES) ||
        return net

    local pmd
    try
        pmd_raw, _ = PowerIO.to_format(dn, "pmd")
        pmd = JSON3.read(pmd_raw)
    catch err
        @warn "from_dss: could not fetch PowerIO `pmd` export to normalise " *
              "transformer no-load shunts; core losses may differ from OpenDSS." err
        return net
    end

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
            t = get(by_id, lowercase(String(tid)), nothing)
            t === nothing && continue
            vmn = get(t, :vm_nom, nothing)
            smn = get(t, :sm_nom, nothing)
            (vmn isa AbstractVector && smn isa AbstractVector &&
             length(vmn) >= 2 && length(smn) >= 1) || continue

            s1 = Float64(smn[1]) * 1e3
            vstamp = Float64(vmn[2]) * 1e3 / (subtype == "delta_wye" ? sqrt(3) : 1.0)
            vstamp > 0 || continue
            c["g_no_load"] = Float64(get(t, :noloadloss, 0.0)) * s1 / vstamp^2
            c["b_no_load"] = -Float64(get(t, :cmag, 0.0)) * s1 / vstamp^2
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
