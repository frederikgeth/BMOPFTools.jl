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
    _remap_opendss_terminals!(net)

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
