# io/ybus_augmented.jl
#
# Augmented (bordered, MNA-style) system nodal admittance matrix.
#
# Extends the passive Ybus with linear constraint rows for IDEAL couplings —
# elements with no finite admittance form: closed switches (optionally) and
# zero-leakage transformers with a non-unity ratio (which `ybus_passive` can
# only stamp as a singular shunt-only block). Each coupling contributes one
# auxiliary current unknown `w` and one constraint row `a·V = 0`, giving the
# bordered system
#
#     K = [ Y   Aᵀ ]      K · [V; w] = [I_inj; 0]
#         [ A   0  ],
#
# where `Y` is the passive Ybus over the surviving nodes and `A` stacks the
# per-conductor constraint rows. The same (real-coefficient) vector is stamped
# as row AND column, so `K = transpose(K)` — the module-wide reciprocity
# convention (see ybus.jl: plain transpose, never the adjoint) is preserved,
# and the ideal element is exact: the constraint holds identically, with no
# penalty-admittance conditioning error, and the coupling current comes out as
# a first-class solution unknown.
#
# Constraint rows are scaled by a nominal admittance `y0` (the median passive
# diagonal magnitude) so the voltage-dimension rows are commensurate with the
# siemens-dimension KCL rows; the physical coupling current is `scale·w`.
#
# Ideal-transformer constraint rows are built from `_xfmr_winding_incidence`,
# the SAME seam the Yprim builders use — the constraint c·V = 0 with
# c = C_w1 − ratio·C_w2 is exactly the zero-leakage limit of the rank-1 series
# block yt·transpose(c)·c, so the admittance and constraint paths cannot drift.

"""
    IdealCoupling

One ideal coupling (per conductor / winding core) in an [`AugYbusResult`](@ref):
a linear constraint `Σ coeffs[k]·V[nodes[k]] = 0` with an auxiliary current
unknown occupying one bordered row/column of `K`.

Fields:
- `kind`      — `:switch` (closed switch conductor) or `:ideal_xfmr`
                (zero-leakage winding core).
- `id`        — element id; `"subtype/id"` for transformers.
- `conductor` — conductor / winding-core index within the element.
- `nodes`     — system node indices (earth-referenced entries already dropped;
                aliased terminals resolved to their representative).
- `coeffs`    — constraint coefficients: ±1 for switches, the winding
                incidence `C_w1 − ratio·C_w2` for ideal transformers.
- `scale`     — conditioning scale applied to the stamped row/column; the
                PHYSICAL coupling current is `scale · w`, where `w` is the
                bordered-row solution entry. Oriented so the coupling draws
                `scale·w·coeffs[k]` out of node `nodes[k]`.
"""
struct IdealCoupling
    kind::Symbol
    id::String
    conductor::Int
    nodes::Vector{Int}
    coeffs::Vector{ComplexF64}
    scale::Float64
end

"""
    AugYbusResult

Augmented system nodal admittance matrix (see [`ybus_augmented`](@ref)).

Fields:
- `K`         — `SparseMatrixCSC{ComplexF64,Int}`, `(n+m)×(n+m)` with `n`
                nodes and `m` couplings, `K = transpose(K)`. The leading `n×n`
                block is the passive Ybus (SI siemens, node-to-earth voltages);
                row/column `n+j` is coupling `j`'s scaled constraint.
- `nodes`     — `Vector{Tuple{String,String}}`, node order of the leading block
                (same rules as [`YbusResult`](@ref)).
- `index`     — `Dict{Tuple{String,String},Int}` from any `(bus, terminal)` to
                its node row (`0` = earth reference; aliased terminals share).
- `couplings` — `Vector{IdealCoupling}`, in bordered-row order.
"""
struct AugYbusResult
    K::SparseMatrixCSC{ComplexF64,Int}
    nodes::Vector{_Node}
    index::Dict{_Node,Int}
    couplings::Vector{IdealCoupling}
end

Base.show(io::IO, r::AugYbusResult) =
    print(io, "AugYbusResult($(length(r.nodes)) nodes, " *
              "$(length(r.couplings)) couplings, $(nnz(r.K)) nonzeros)")

# Conditioning scale for the constraint rows: the median passive diagonal
# magnitude, floored at 1 S. A global heuristic — revisit (per-coupling nominal
# admittance) if mixed-kV feeders show conditioning noise in the ideal-limit
# tests.
function _aug_scale(Ypass::SparseMatrixCSC{ComplexF64,Int})::Float64
    d = abs.(Vector(diag(Ypass)))   # densify: diag of sparse is a SparseVector
    filter!(>(0.0), d)
    isempty(d) && return 1.0
    max(1.0, sort!(d)[cld(length(d), 2)])
end

# Resolve a constraint row over `(bus, terminal)` tuples to system node indices:
# earth-referenced entries (index 0) drop, aliased terminals accumulate onto
# their representative. A row that cancels completely (e.g. a switch whose
# endpoints are already fused by a parallel negligible-Z line) returns empty —
# the caller skips it, which is the redundant-constraint dedupe.
function _aug_row(idx::_YbusIndex, nds::Vector{_Node}, cfs::Vector{Float64})
    acc = Dict{Int,ComplexF64}()
    for (nd, cf) in zip(nds, cfs)
        gi = get(idx.of, nd, 0)
        gi == 0 && continue
        acc[gi] = get(acc, gi, 0.0 + 0.0im) + cf
    end
    rn = Int[]; rc = ComplexF64[]
    for k in sort!(collect(keys(acc)))
        abs(acc[k]) <= 1e-12 && continue
        push!(rn, k); push!(rc, acc[k])
    end
    (rn, rc)
end

"""
    ybus_augmented(net; config=_DEFAULT_CONFIG,
                   switches=:alias, ideal_xfmrs=:constrain) -> AugYbusResult

Assemble the augmented (bordered, MNA-style) system nodal admittance matrix:
the passive Ybus of [`ybus_passive`](@ref) extended with one constraint row and
auxiliary current unknown per ideal coupling, `K·[V; w] = [I_inj; 0]`.

Keywords:
- `switches = :alias | :constrain` — `:alias` (default) fuses closed-switch
  terminals into shared nodes exactly like `ybus_passive`; `:constrain` keeps
  them distinct and ties them per conductor with `V_from − V_to = 0` rows, so
  each switch-conductor current is a solution unknown. Both modes yield
  identical node voltages. A switch is closed unless its `open_switch` field
  is `true`, as in `ybus_passive`; an open switch is neither fused nor
  constrained in either mode.
- `ideal_xfmrs = :constrain | :stamp` — `:constrain` (default) models every
  zero-leakage, NON-unity-ratio two-winding transformer (`single_phase`,
  `wye_delta`, `delta_wye`) exactly, as ideal winding-core constraints
  `u_w1 − ratio·u_w2 = 0` from `_xfmr_winding_incidence`; `:stamp`
  falls back to `ybus_passive`'s singular shunt-only block (with its warning).
  Unity-ratio zero-leakage transformers stay node-aliased in either mode
  (an exact identity — strictly better than a constraint).

The constraint coefficients must be real (they are, for all supported
subtypes — ratios are `v_nom` quotients times a real tap); this keeps
`K = transpose(K)`. A degenerate coil ratio (zero/non-finite, e.g. `tap = 0`)
raises an `ArgumentError`.

Non-source shunt-only networks aside, `K` is nonsingular whenever every node
group has a path to a voltage reference; islands and floating ideal deltas
surface as singular factorizations in the consuming solver, not here.
"""
function ybus_augmented(net::Dict{String,Any}; config=_DEFAULT_CONFIG,
                        switches::Symbol=:alias,
                        ideal_xfmrs::Symbol=:constrain)::AugYbusResult
    switches in (:alias, :constrain) ||
        throw(ArgumentError("switches must be :alias or :constrain, got $(repr(switches))"))
    ideal_xfmrs in (:constrain, :stamp) ||
        throw(ArgumentError("ideal_xfmrs must be :constrain or :stamp, got $(repr(ideal_xfmrs))"))

    thresh = _domain_thresholds(config)
    zmin = _ybus_xfmr_z_min(thresh)

    idx = _ybus_nodes(net; config, alias_switches=(switches === :alias))

    # Transformers promoted to ideal couplings: zero-leakage AND non-unity ratio
    # (the unity ones are node-aliased by `_ybus_nodes`), ideal-capable subtypes.
    promoted = Tuple{String,String,Dict{String,Any}}[]   # (subtype, id, xfmr)
    if ideal_xfmrs === :constrain
        xfmrs = get(net, "transformer", Dict())
        if xfmrs isa Dict
            for subtype in ("single_phase", "wye_delta", "delta_wye")
                sub = get(xfmrs, subtype, Dict())
                sub isa Dict || continue
                for xid in sort!(collect(String.(keys(sub))))
                    x = sub[xid]
                    _xfmr_is_ideal(x, zmin) || continue
                    isapprox(_xfmr_turns_ratio(x), 1.0; atol=1e-9) && continue
                    push!(promoted, (subtype, xid, x))
                end
            end
        end
    end
    skip = Set{Tuple{String,String}}((s, i) for (s, i, _) in promoted)

    # Passive block (promoted units bypass the singular Yprim stamp entirely).
    I = Int[]; J = Int[]; V = ComplexF64[]
    _stamp_passive!(I, J, V, net, idx, config; skip_transformers=skip)
    n = length(idx.nodes)
    Ypass = sparse(I, J, V, n, n)
    y0 = _aug_scale(Ypass)

    couplings = IdealCoupling[]

    # Closed switches → V_from − V_to = 0 per conductor.
    if switches === :constrain
        sws = get(net, "switch", Dict())
        for sid in sort!(collect(String.(keys(sws))))
            sw = sws[sid]
            _ybus_switch_is_open(sid, sw) && continue
            bfr = get(sw, "bus_from", ""); bto = get(sw, "bus_to", "")
            tmf = string.(get(sw, "terminal_map_from", String[]))
            tmt = string.(get(sw, "terminal_map_to", String[]))
            for k in 1:min(length(tmf), length(tmt))
                rn, rc = _aug_row(idx, [(bfr, tmf[k]), (bto, tmt[k])], [1.0, -1.0])
                isempty(rn) && continue    # deduped or fully earth-referenced
                push!(couplings, IdealCoupling(:switch, sid, k, rn, rc, y0))
            end
        end
    end

    # Ideal transformers → u_w1 − ratio·u_w2 = 0 per winding core.
    for (subtype, xid, x) in promoted
        for (k, ent) in enumerate(_xfmr_winding_incidence(x, subtype))
            r = ent.ratio
            (isfinite(r) && !iszero(r)) || throw(ArgumentError(
                "ideal transformer $subtype/$xid has a degenerate coil ratio $r " *
                "(check v_nom_from/v_nom_to and tap)"))
            nds = vcat(ent.w1_nodes, ent.w2_nodes)
            cfs = vcat(ent.w1_coeffs, -r .* ent.w2_coeffs)
            rn, rc = _aug_row(idx, nds, cfs)
            isempty(rn) && continue
            push!(couplings, IdealCoupling(:ideal_xfmr, "$subtype/$xid", k, rn, rc, y0))
        end
    end

    # Border: stamp each scaled constraint as row AND column (K = transpose(K)).
    for (j, c) in enumerate(couplings)
        row = n + j
        for (ni, cf) in zip(c.nodes, c.coeffs)
            v = y0 * cf
            push!(I, row); push!(J, ni); push!(V, v)
            push!(I, ni); push!(J, row); push!(V, v)
        end
    end

    m = length(couplings)
    AugYbusResult(sparse(I, J, V, n + m, n + m), idx.nodes, idx.of, couplings)
end
