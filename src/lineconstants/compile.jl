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
resistivity [Ω·m], **frequency [Hz]** (required — no ambient default, no
rescaling; both 50 and 60 Hz are computed exactly from ω), and conductor
temperature [°C] are read from the geometry object. Note OpenDSS's default
earth model is **deri** — set it on the geometry when cross-validating
against OpenDSS. Physically impossible inputs (GMR > radius, overlapping
conductor circles, non-nesting cable layers) error; inputs that strain the
analytical models' validity domain (Carson truncation parameter, buried
conductors under `full_carson`, frequency above a wire's critical skin
frequency, implausible earth resistivity) warn here and surface as
`W.DOM.*` findings in [`analyze`](@ref).

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
    haskey(geo, "frequency") ||
        error("line_geometry '$geometry_id': `frequency` [Hz] is required — " *
              "there is no ambient default and no rescaling; state it " *
              "explicitly so the case is self-contained.")
    f = Float64(geo["frequency"])
    f > 0 || error("line_geometry '$geometry_id': `frequency` must be > 0 Hz.")
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

    # physical realizability: conductor circles must not overlap
    for i in 1:n, j in i+1:n
        d = hypot(xs[i] - xs[j], ys[i] - ys[j])
        rsum = wires[i].radius + wires[j].radius
        d < rsum - 1e-12 &&
            error("line_geometry '$geometry_id': conductors $i and $j " *
                  "overlap — centre distance $(round(d, sigdigits=4)) m < " *
                  "sum of radii $(round(rsum, sigdigits=4)) m.")
    end

    _warn_geometry_assumptions(geometry_id, wires, xs, ys, model, f, rho)

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

# Assumption-validity warnings at compile time — the same conditions the
# analysis pass reports as W.DOM findings (see validation/wire_geometry.jl,
# which also holds the thresholds and literature rationale).
function _warn_geometry_assumptions(geometry_id::String,
                                    wires::Vector{_ResolvedWire},
                                    xs::Vector{Float64}, ys::Vector{Float64},
                                    model::String, f::Float64, rho::Float64)
    n = length(wires)
    if !(_EARTH_RHO_RANGE[1] <= rho <= _EARTH_RHO_RANGE[2])
        @warn "line_geometry '$geometry_id': earth_resistivity = $rho Ω·m is " *
              "outside the practical soil range $(_EARTH_RHO_RANGE)."
    end
    if model in ("modified_carson", "full_carson")
        kmax = 0.0
        for i in 1:n
            kmax = max(kmax, _carson_k(max(2 * max(ys[i], 0.0), 1e-3), f, rho))
            for j in i+1:n
                S = hypot(xs[i] - xs[j], max(ys[i], 0.0) + max(ys[j], 0.0))
                kmax = max(kmax, _carson_k(max(S, 1e-3), f, rho))
            end
        end
        kmax > _CARSON_K_MAX &&
            @warn "line_geometry '$geometry_id': Carson series parameter k " *
                  "reaches $(round(kmax, sigdigits=3)) (> $(_CARSON_K_MAX)) — " *
                  "the $(model) truncation degrades (Carson 1926; Kersting & " *
                  "Green 2011); consider earth_model = \"deri\"."
    end
    if any(<(0.0), ys) && model == "full_carson"
        @warn "line_geometry '$geometry_id': buried conductor(s) with " *
              "full_carson are evaluated at the surface (Pollaczek regime " *
              "not implemented; negligible at power frequency)."
    end
    for w in wires
        rho_impl = w.r_ac * pi * w.radius^2
        fc = _f_critical(rho_impl, w.radius)
        if f > fc
            @warn "line_geometry '$geometry_id': frequency $(f) Hz exceeds " *
                  "the critical skin frequency $(round(fc, sigdigits=3)) Hz " *
                  "of wire '$(w.id)' — constant-r_ac/GMR assumptions degrade " *
                  "(Jensen et al. 2001)."
            break
        end
    end
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
