# lineconstants/compile.jl
#
# Compile `line_geometry` assemblies into linecodes. This is the single
# bridge from construction data (wire_data + coordinates) to the linecode
# impedance representation the rest of the package consumes — lines never
# reference geometry directly, so the OPF/PF stack sees one impedance
# pathway regardless of whether a linecode came from geometry, FEM, a
# datasheet, or an import.

"""
    compile_linecode(net, geometry_id; id=geometry_id, force=false) -> String

Compute the per-metre series-impedance and shunt-susceptance matrices of
`net["line_geometry"][geometry_id]` and stamp them as
`net["linecode"][id]`, returning `id`.

The compiled linecode covers the **full primitive system** of the geometry's
circuit conductors, in the order they are listed — one matrix row per
conductor, matching a line's `terminal_map_*` of the geometry's `terminal`
labels. There is no Kron elimination of circuit conductors; grounding
belongs on bus `perfectly_grounded_terminals`. Cable (cn/ts) shield
subconductors — sub-terminal structure held at earth potential — are the
one exception: they are built internally and reduced into the cable's
equivalent conductors (Kersting treatment), recorded under
`derivation.shields_reduced`.

Earth model (`modified_carson` default | `full_carson` | `deri`), earth
resistivity [Ω·m], frequency [Hz], and conductor temperature [°C] are read
from the geometry object. Note OpenDSS's default earth model is **deri** —
set it on the geometry when cross-validating against OpenDSS.

Shunt susceptance: overhead conductors get the Maxwell potential-coefficient
capacitance (perfect-earth images, electrostatic radius); cables their
coaxial phase-to-shield capacitance (diagonal). Bare conductors at or below
ground level contribute zero shunt (warned).

Provenance is stamped on the linecode: `source="geometry"`, a
`line_geometry` back-reference, and a `derivation` block (method, ρ, f,
temperature, applied cross-defaults, tool version). The provenance analyzer
re-derives and cross-checks linecodes that carry these fields.

An existing linecode `id` is only overwritten with `force=true`.
"""
function compile_linecode(net::Dict{String,Any}, geometry_id::String;
                          id::String=geometry_id, force::Bool=false)::String
    geos = get(net, "line_geometry", Dict{String,Any}())
    haskey(geos, geometry_id) ||
        error("compile_linecode: unknown line_geometry '$geometry_id'.")
    geo = geos[geometry_id]

    linecodes = get!(net, "linecode", Dict{String,Any}())
    if haskey(linecodes, id) && !force
        error("compile_linecode: linecode '$id' already exists; " *
              "pass force=true to overwrite.")
    end

    model = string(get(geo, "earth_model", "modified_carson"))
    model in _EARTH_MODELS ||
        error("line_geometry '$geometry_id': unknown earth_model '$model' " *
              "(expected one of $(_EARTH_MODELS)).")
    rho  = Float64(get(geo, "earth_resistivity", 100.0))
    f    = Float64(get(geo, "frequency", 50.0))
    temperature = haskey(geo, "temperature") ? Float64(geo["temperature"]) : nothing

    entries = get(geo, "conductors", nothing)
    entries isa AbstractVector && !isempty(entries) ||
        error("line_geometry '$geometry_id': `conductors` must be a " *
              "non-empty array.")

    wire_lib = get(net, "wire_data", Dict{String,Any}())
    defaults = String[]
    resolved_cache = Dict{String,_ResolvedWire}()

    n = length(entries)
    wires = Vector{_ResolvedWire}(undef, n)
    xs = zeros(n); ys = zeros(n)
    terminals = String[]
    for (i, e) in enumerate(entries)
        e isa Dict || error("line_geometry '$geometry_id': conductor $i is " *
                            "not an object.")
        wid = string(get(e, "wire_data", ""))
        haskey(wire_lib, wid) ||
            error("line_geometry '$geometry_id': conductor $i references " *
                  "unknown wire_data '$wid'.")
        wires[i] = get!(resolved_cache, wid) do
            _resolve_wire(wid, wire_lib[wid], temperature, defaults)
        end
        xs[i] = Float64(e["x"]); ys[i] = Float64(e["y"])
        t = get(e, "terminal", nothing)
        t isa AbstractString ||
            error("line_geometry '$geometry_id': conductor $i has no " *
                  "`terminal` — every conductor must map to a circuit " *
                  "terminal (there is no elimination pathway; grounding " *
                  "belongs on bus perfectly_grounded_terminals).")
        push!(terminals, string(t))
        if wires[i].kind == "overhead" && ys[i] <= 0
            @warn "line_geometry '$geometry_id': bare conductor $i is at or " *
                  "below ground level (y = $(ys[i])) — no overhead " *
                  "capacitance is computed for it."
        end
    end
    length(unique(terminals)) == n ||
        error("line_geometry '$geometry_id': duplicate terminal labels " *
              "$(terminals) — one conductor per terminal.")

    # -- primitive system: circuit conductors, then cable shields -----------
    prims = [_PrimitiveConductor(w.r_ac, w.gmr, xs[i], ys[i], nothing, 0.0)
             for (i, w) in enumerate(wires)]
    shields_reduced = String[]
    for (i, w) in enumerate(wires)
        w.r_shield === nothing && continue
        push!(prims, _PrimitiveConductor(w.r_shield, w.gmr_shield,
                                         xs[i], ys[i], i, w.rad_shield))
        push!(shields_reduced,
              "$(w.kind == "cn_cable" ? "cn" : "ts"):$i")
    end

    Zprim = _primitive_z(prims, model, f, rho)
    Z = length(prims) == n ? Zprim : _kron_reduce(Zprim, collect(1:n))

    # internal sanity — a compiled matrix must be physically plausible
    all(real(Z[i, i]) > 0 for i in 1:n) ||
        error("compile_linecode('$geometry_id'): non-positive self " *
              "resistance in the compiled matrix — check wire_data inputs.")
    all(imag(Z[i, i]) > 0 for i in 1:n) ||
        error("compile_linecode('$geometry_id'): non-positive self " *
              "reactance in the compiled matrix — check GMR values.")

    C = _shunt_c(wires, xs, ys)
    omega = 2pi * f

    # -- stamp the linecode ---------------------------------------------------
    lc = Dict{String,Any}()
    for i in 1:n, j in 1:n
        lc["R_series_$(i)_$(j)"] = real(Z[i, j])
        lc["X_series_$(i)_$(j)"] = imag(Z[i, j])
    end
    if any(!iszero, C)
        # π model: half of the total shunt admittance at each end
        for i in 1:n, j in 1:n
            b = omega * C[i, j] / 2
            lc["B_from_$(i)_$(j)"] = b
            lc["B_to_$(i)_$(j)"]   = b
        end
    end
    if all(w.i_max !== nothing for w in wires)
        lc["i_max"] = [w.i_max for w in wires]
    end

    lc["source"]        = "geometry"
    lc["line_geometry"] = geometry_id
    derivation = Dict{String,Any}(
        "method"            => model,
        "earth_resistivity" => rho,
        "frequency"         => f,
        "tool"              => "BMOPFTools.jl",
        "tool_version"      => _BMOPFTOOLS_VERSION,
    )
    temperature === nothing || (derivation["temperature"] = temperature)
    isempty(shields_reduced) || (derivation["shields_reduced"] = shields_reduced)
    isempty(defaults) || (derivation["defaults_applied"] = sort(unique(defaults)))
    lc["derivation"] = derivation

    linecodes[id] = lc
    id
end

"""
    compile_linecodes!(net; force=false) -> Vector{String}

Compile every `line_geometry` in `net` into a same-id linecode (see
[`compile_linecode`](@ref)). Geometries whose linecode already exists are
skipped with a warning unless `force=true`. Returns the compiled ids.
"""
function compile_linecodes!(net::Dict{String,Any}; force::Bool=false)::Vector{String}
    compiled = String[]
    for gid in sort(collect(keys(get(net, "line_geometry", Dict{String,Any}()))))
        if haskey(get(net, "linecode", Dict{String,Any}()), gid) && !force
            @warn "compile_linecodes!: linecode '$gid' already exists — " *
                  "skipped (pass force=true to recompile)."
            continue
        end
        push!(compiled, compile_linecode(net, gid; force=force))
    end
    compiled
end
