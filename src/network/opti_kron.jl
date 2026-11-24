# network/opti_kron.jl
#
# PROTOTYPE — robust optimal Kron-based network reduction (robust Opti-KRON),
# following Mokhtari, Bagrow, Almassalkhi & Chevalier, "Robust Optimal Network
# Reduction for Distribution Systems", arXiv:2611.21313 (2026).
#
# The reduction keeps a subset of buses ("super-nodes"); every other bus is
# assigned to one super-node within `H` hops, its injections are aggregated
# (phase by phase) at that super-node, and the super-node voltage magnitude
# stands in for its own. The assignment with the fewest super-nodes is chosen
# such that, under a linear voltage-magnitude model `v = 1 + K u`, the error
#
#     e_j(A, u) = ṽ_{i}(A u) − v_j(u) = c_ij(A)ᵀ u,   A_ij = 1,
#
# stays within ±Ē for every injection `u` in an uncertainty set 𝒰 (box,
# convex hull, ellipsoid, or type-1 Wasserstein worst-case CVaR).
#
# This file holds the solver-free parts:
#
#   • `opti_kron_model`         — tree/zone structure, candidate pairs, and the
#                                 linear voltage-magnitude sensitivities K
#   • uncertainty sets          — `OptiKronBox`, `OptiKronHull`,
#                                 `OptiKronEllipsoid`, `OptiKronWasserstein`
#                                 with closed-form worst cases (paper Table I)
#   • `opti_kron_screen`        — presolve screening (paper §III-A)
#   • `opti_kron_errors`, `_opti_kron_adversary` — error evaluation and the
#                                 adversary of Algorithm 1 (paper §III-B)
#   • `opti_kron_load_injections`, `extract_downstream_network` — data helpers
#
# The MILP master problem and Algorithm 1 itself live in the JuMP extension
# (`ext/BMOPFOpfExt/opti_kron.jl`), entry point `opti_kron_reduction`.
#
# ── Deviations from the paper (prototype scope) ─────────────────────────────
#
# 1. Linear voltage model. The paper uses phase-coupled LinDistFlow
#    (K = Γᵀ diag(Z) Γ). Here K is the first-order sensitivity of the
#    phase-to-neutral voltage magnitudes to constant-power injections, taken
#    from the full multiphase passive Ybus (`ybus_passive`) at the no-load
#    operating point: ΔV = Y_ff⁻¹ ΔI, ΔI = conj(ΔS)/conj(U₀). For a single-phase
#    radial feeder with a flat 1∠0 p.u. no-load profile this reduces exactly to
#    LinDistFlow (K_P = shared path resistance, K_Q = shared path reactance);
#    in general it also captures neutrals, MEN groundings, transformers and
#    meshes. Voltages are in p.u. of each row's no-load magnitude.
# 2. Clusters do not cross transformers (pairs must share a voltage zone), so
#    phase labels keep a consistent meaning when injections are aggregated —
#    except for the slack, whose voltage is fixed (`slack_cross_zone=true`).
# 3. Meshed networks: hop distances, paths 𝒫_ij and the connectivity rule
#    (1b) use the BFS spanning tree from the source; the sensitivities still
#    come from the meshed Ybus.
# 4. Ellipsoid covariance: POET with eigenvalue-ratio factor choice (≤ 5)
#    and soft thresholding (C = 0.5); the paper does not state its POET
#    tuning. The Wasserstein radius ρ/ε is the requested quantile
#    of each training sample's distance to the d = 0 part of 𝒰_W built from the
#    OTHER samples (leave-one-out; in-sample the distance is zero whenever
#    1/(Nε) ≥ 1). For p ≠ 2 the distance is the smaller of the ℓ_p distances to
#    the ℓ2 projection and to the nearest other sample (an upper bound). `radius=:nearest` uses the cruder
#    nearest-sample distance.
# 5. Only Algorithm 1 (adversarial constraint generation) is implemented; the
#    "direct" robust counterpart is not built. Passing all training samples as
#    the initial set with `OptiKronHull` reproduces the direct convex-hull and
#    scenario-based models (the hull's worst case is attained at a sample).
# 6. The paper's structural constraints (1) do not state it, but its results
#    are reproduced only when the Kron-reduced network must stay radial
#    (`preserve_radial=true`, default): structural maximum 88.6% on the IEEE
#    European LV feeder, exactly as reported.
# 7. Screening test 2 (coefficient intervals) is implemented for the box and
#    convex hull; ellipsoid and Wasserstein sets use test 1 only.
#
# Not yet linked to a PSK identity or registered in knowledge/executable.toml.

# ════════════════════════════════════════════════════════════════════════════
# Model: tree, zones, rows, candidate pairs, sensitivities
# ════════════════════════════════════════════════════════════════════════════

"""
    OptiKronModel

Structure and linear voltage-magnitude model used by robust Opti-KRON
(prototype). Built by [`opti_kron_model`](@ref).

Rows ("node-phase pairs") index both the voltage magnitudes `v` and the nodal
injections: injection coordinate `c ∈ 1:2nrows` is the active power (`c ≤
nrows`) or reactive power (`c > nrows`) injected at row `mod1(c, nrows)`'s
phase terminal and returned through the bus neutral (or earth), in units of
`sbase` watts (vars). Positive injection = generation.

Fields (selection):
- `buses`, `parent`, `zone`, `phases` — BFS spanning tree from the source bus
  (`buses[1]`), voltage zone id per bus, and the phase terminals with a row.
- `rows`, `rowof`, `bus_rows` — `(bus index, phase terminal)` per row.
- `K` — `nrows × 2nrows` sensitivity `[K_P K_Q]` in p.u. voltage per `sbase`.
- `pair_i`, `pair_j`, `pair_path` — candidate pairs `(i, j)` (super-node `i`,
  node `j`) within `H` tree hops in one zone; `pair_path` lists the tree path
  from `j` to `i` inclusive.
- `Yr`, `M`, `Iinj` — sparse linearized network for the MILP master:
  `Yr·x = Re/Im(Iinj·s)`, `Δv = Re(M·ΔV)`.
"""
struct OptiKronModel
    buses::Vector{String}
    busof::Dict{String,Int}
    parent::Vector{Int}
    depth::Vector{Int}
    zone::Vector{Int}
    phases::Vector{Vector{String}}
    rows::Vector{Tuple{Int,String}}
    rowof::Dict{Tuple{Int,String},Int}
    bus_rows::Vector{Vector{Int}}
    K::Matrix{Float64}
    sbase::Float64
    H::Int
    pair_i::Vector{Int}
    pair_j::Vector{Int}
    pair_path::Vector{Vector{Int}}
    cand::Vector{Vector{Int}}          # cand[j] = pair indices with node j
    Yr::SparseMatrixCSC{Float64,Int}   # real form [G -B; B G] over free nodes
    M::SparseMatrixCSC{ComplexF64,Int} # nrows × nfree, Δv = Re(M ΔV)
    Iinj::SparseMatrixCSC{ComplexF64,Int} # nfree × nrows, ΔI per unit P (Q: × −j)
    n_mesh_edges::Int
    n_unreached::Int
    u0::Vector{Float64}                # no-load |U| per row (V), the p.u. base
end

Base.show(io::IO, m::OptiKronModel) = print(io,
    "OptiKronModel($(length(m.buses)) buses, $(length(m.rows)) rows, ",
    "$(length(m.pair_i)) candidate pairs, H=$(m.H))")

_ok_nrows(m::OptiKronModel) = length(m.rows)

# Bus references of one component entry (nothing when it references no bus).
function _ok_bus_refs(e::AbstractDict)
    haskey(e, "bus") && return [string(e["bus"])]
    if haskey(e, "bus_from") && haskey(e, "bus_to")
        return [string(e["bus_from"]), string(e["bus_to"])]
    end
    haskey(e, "buses") && e["buses"] isa AbstractVector && return string.(e["buses"])
    nothing
end

# Branch edges (a, b, is_transformer) of the network.
function _ok_edges(net::Dict{String,Any})
    edges = Tuple{String,String,Bool}[]
    for (_, l) in get(net, "line", Dict())
        push!(edges, (string(l["bus_from"]), string(l["bus_to"]), false))
    end
    for (_, s) in get(net, "switch", Dict())
        get(s, "open_switch", false) === true && continue
        push!(edges, (string(s["bus_from"]), string(s["bus_to"]), false))
    end
    for (_, sub) in get(net, "transformer", Dict())
        sub isa AbstractDict || continue
        for (_, t) in sub
            t isa AbstractDict || continue
            refs = _ok_bus_refs(t)
            refs === nothing && continue
            for k in 2:length(refs)
                push!(edges, (refs[1], refs[k], true))
            end
        end
    end
    edges
end

function _ok_source(net::Dict{String,Any})
    vs = get(net, "voltage_source", Dict())
    length(vs) == 1 || throw(ArgumentError(
        "opti_kron_model supports exactly one voltage source (found $(length(vs)))."))
    first(values(vs))
end

function _ok_phase_terminals(net, bus::AbstractDict)
    names = string.(get(bus, "terminal_names", String[]))
    grounded = Set(string.(get(bus, "perfectly_grounded_terminals", String[])))
    conv = get(net, "terminal_conventions", Dict())
    plabels = get(conv, "phase", nothing)
    nlabels = get(conv, "neutral", nothing)
    neutral = nlabels === nothing ? _neutral_terminal(bus) :
              _neutral_terminal(names, string.(nlabels))
    ph = String[]
    for t in names
        t in grounded && continue
        t == neutral && continue
        plabels !== nothing && !(t in string.(plabels)) && continue
        push!(ph, t)
    end
    ph, neutral
end

"""
    opti_kron_noload(net; config) -> (YbusResult, V)

Passive Ybus and no-load nodal voltages of `net`; pass the tuple as
`noload=` to [`extract_downstream_network`](@ref) to reuse it across roots.
"""
function opti_kron_noload(net::Dict{String,Any}; config=_DEFAULT_CONFIG)
    y = ybus_passive(net; config=config)
    V, _, _, _, _ = _ok_noload(net, y)
    y, V
end

# No-load nodal voltages with the source fixed: returns (V, fixed, free, F, Yff)
function _ok_noload(net, y::YbusResult)
    vs = _ok_source(net)
    n = size(y.Y, 1)
    fixed = Int[]
    Vs = ComplexF64[]
    for (k, t) in enumerate(vs["terminal_map"])
        idx = get(y.index, (string(vs["bus"]), string(t)), 0)
        idx == 0 && continue
        push!(fixed, idx)
        push!(Vs, vs["v_magnitude"][k] * cis(vs["v_angle"][k]))
    end
    isolated = [i for i in 1:n if y.Y[i, i] == 0 && !(i in fixed)]
    free = setdiff(1:n, fixed, isolated)
    Yff = y.Y[free, free]
    F = lu(Yff)
    V = zeros(ComplexF64, n)
    V[fixed] .= Vs
    V[free] .= -(F \ (y.Y[free, fixed] * Vs))
    V, fixed, free, F, Yff
end

"""
    opti_kron_model(net; H=5, sbase=1e3, config=_DEFAULT_CONFIG) -> OptiKronModel

Build the robust Opti-KRON structure for `net` (prototype; see the header of
`src/network/opti_kron.jl` for the modeling choices and deviations from the
paper). Requires exactly one voltage source; its bus is the slack super-node.

- `H` — hop limit for candidate pairs (paper default 5).
- `sbase` — injection unit in W/var (default kW / kvar).
- `slack_cross_zone` — let the slack bus represent buses within `H` hops
  across a transformer (all other pairs stay within one voltage zone). This
  reproduces the paper's 11,227 candidate pairs on the IEEE European LV
  feeder up to one pair.

Cost: one sparse LU of the passive Ybus plus one solve per row; the dense
sensitivity is `nrows × 2nrows`, so this is intended for feeders of up to a
few thousand buses (use [`extract_downstream_network`](@ref) for larger
models).
"""
function opti_kron_model(net::Dict{String,Any}; H::Int=5, sbase::Real=1e3,
                         slack_cross_zone::Bool=true, config=_DEFAULT_CONFIG)
    H ≥ 1 || throw(ArgumentError("H must be ≥ 1"))
    vs = _ok_source(net)
    root = string(vs["bus"])
    haskey(net["bus"], root) || throw(ArgumentError("source bus $root not found"))

    # ── BFS spanning tree ───────────────────────────────────────────────────
    adj = Dict{String,Vector{Tuple{String,Bool}}}()
    edges = _ok_edges(net)
    for (a, b, x) in edges
        a == b && continue
        push!(get!(adj, a, Tuple{String,Bool}[]), (b, x))
        push!(get!(adj, b, Tuple{String,Bool}[]), (a, x))
    end
    buses = [root]
    busof = Dict(root => 1)
    parent = [0]; depth = [0]; zone = [1]; nz = 1
    head = 1
    while head ≤ length(buses)
        u = buses[head]; ui = head; head += 1
        for (w, isx) in sort!(collect(get(adj, u, Tuple{String,Bool}[])))
            haskey(busof, w) && continue
            push!(buses, w); busof[w] = length(buses)
            push!(parent, ui); push!(depth, depth[ui] + 1)
            if isx
                nz += 1; push!(zone, nz)
            else
                push!(zone, zone[ui])
            end
        end
    end
    nb = length(buses)
    n_tree = nb - 1
    n_edges_in = count(e -> haskey(busof, e[1]) && haskey(busof, e[2]) && e[1] != e[2], edges)
    n_mesh = n_edges_in - n_tree
    n_unreached = length(net["bus"]) - nb

    # ── linear voltage-magnitude model ──────────────────────────────────────
    y = ybus_passive(net; config=config)
    V, fixed, free, F, Yff = _ok_noload(net, y)
    freepos = zeros(Int, size(y.Y, 1))
    freepos[free] .= 1:length(free)
    nf = length(free)

    rows = Tuple{Int,String}[]
    phases = [String[] for _ in 1:nb]
    rp = Int[]; rn = Int[]; U0 = ComplexF64[]
    for (bi, b) in enumerate(buses)
        ph, neutral = _ok_phase_terminals(net, net["bus"][b])
        nidx = neutral === nothing ? 0 : get(y.index, (b, neutral), 0)
        for t in ph
            pidx = get(y.index, (b, t), 0)
            pidx == 0 && continue
            u0 = V[pidx] - (nidx == 0 ? 0.0im : V[nidx])
            abs(u0) > 1e-6 || continue
            push!(rows, (bi, t)); push!(phases[bi], t)
            push!(rp, pidx); push!(rn, nidx); push!(U0, u0)
        end
    end
    nr = length(rows)
    rowof = Dict(r => k for (k, r) in enumerate(rows))
    bus_rows = [Int[] for _ in 1:nb]
    for (k, (bi, _)) in enumerate(rows)
        push!(bus_rows[bi], k)
    end

    # Δv_r = Re(w_r (ΔV_p − ΔV_n)),  w = conj(U0)/|U0|²   (p.u. of |U0|)
    MI = Int[]; MJ = Int[]; MV = ComplexF64[]
    II = Int[]; IJ = Int[]; IV = ComplexF64[]
    for r in 1:nr
        w = conj(U0[r]) / abs2(U0[r])
        ip = sbase / conj(U0[r])           # current into phase per unit P
        for (node, sgn) in ((rp[r], 1.0), (rn[r], -1.0))
            node == 0 && continue
            fp = freepos[node]
            fp == 0 && continue
            push!(MI, r); push!(MJ, fp); push!(MV, sgn * w)
            push!(II, fp); push!(IJ, r); push!(IV, sgn * ip)
        end
    end
    M = sparse(MI, MJ, MV, nr, nf)
    Iinj = sparse(II, IJ, IV, nf, nr)

    K = zeros(nr, 2nr)
    blk = 256
    for c0 in 1:blk:nr
        cs = c0:min(c0 + blk - 1, nr)
        dV = F \ Matrix{ComplexF64}(Iinj[:, cs])
        MdV = M * dV
        K[:, cs] .= real.(MdV)
        K[:, cs .+ nr] .= imag.(MdV)      # ΔI_Q = −j ΔI_P ⇒ Re(−j z) = Im(z)
    end

    G = real.(Yff); B = imag.(Yff)
    Yr = [G -B; B G]

    # ── candidate pairs (tree hops ≤ H, same zone, phase subset) ───────────
    children = [Int[] for _ in 1:nb]
    for v in 2:nb
        push!(children[parent[v]], v)
    end
    pair_i = Int[]; pair_j = Int[]; pair_path = Vector{Int}[]
    cand = [Int[] for _ in 1:nb]
    pred = zeros(Int, nb); dist = fill(-1, nb)
    for j in 1:nb
        if j == 1
            push!(pair_i, 1); push!(pair_j, 1); push!(pair_path, [1])
            push!(cand[1], length(pair_i))
            continue
        end
        isempty(phases[j]) && continue
        # BFS from j on the tree, within j's zone, up to H hops
        visited = [j]; dist[j] = 0; pred[j] = 0
        q = [j]; h = 1
        while h ≤ length(q)
            u = q[h]; h += 1
            dist[u] == H && continue
            nbrs = parent[u] == 0 ? children[u] : vcat(parent[u], children[u])
            for w in nbrs
                dist[w] ≥ 0 && continue
                zone[w] == zone[j] || continue
                dist[w] = dist[u] + 1; pred[w] = u
                push!(visited, w); push!(q, w)
            end
        end
        for i in visited
            issubset(phases[j], phases[i]) || continue
            path = Int[i]
            u = i
            while u != j
                u = pred[u]; push!(path, u)
            end
            reverse!(path)                 # j … i
            push!(pair_i, i); push!(pair_j, j); push!(pair_path, path)
            push!(cand[j], length(pair_i))
        end
        for u in visited
            dist[u] = -1
        end
        # the slack (fixed voltage) may also represent buses in other zones
        # within H hops: its voltage and aggregated injections do not depend
        # on phase labels across transformers
        if slack_cross_zone && zone[j] != zone[1] && depth[j] ≤ H &&
           issubset(phases[j], phases[1])
            path = Int[j]; u = j
            while u != 1
                u = parent[u]; push!(path, u)
            end
            push!(pair_i, 1); push!(pair_j, j); push!(pair_path, path)
            push!(cand[j], length(pair_i))
        end
    end

    OptiKronModel(buses, busof, parent, depth, zone, phases, rows, rowof, bus_rows,
                  K, Float64(sbase), H, pair_i, pair_j, pair_path, cand,
                  Yr, M, Iinj, n_mesh, n_unreached, abs.(U0))
end

# Column of K for injection row (bus b, phase t), Q block if isq.
@inline _ok_col(m::OptiKronModel, b::Int, t::String, isq::Bool) =
    m.rowof[(b, t)] + (isq ? _ok_nrows(m) : 0)

# ════════════════════════════════════════════════════════════════════════════
# Injection samples
# ════════════════════════════════════════════════════════════════════════════

"""
    opti_kron_load_injections(model, net, mult_p[, mult_q]) -> Matrix{Float64}

Training/test injection samples from the network's loads: column `s` holds
`u = [p; q]` (length `2nrows`, units of `model.sbase`, generation positive)
with each load's `p_nom`/`q_nom` scaled by `mult_p[load_id][s]` /
`mult_q[load_id][s]` (negative multipliers model net export). `mult_*` may be
a `Dict{String,<:AbstractVector}` or a function `(load_id, s) -> Float64`
together with the sample count via the `n` keyword. Delta loads are split
equally between their two phase terminals (approximation).
"""
function opti_kron_load_injections(m::OptiKronModel, net::Dict{String,Any}, mult_p,
                                   mult_q=mult_p; n::Union{Nothing,Int}=nothing)
    getm(mm, id, s) = mm isa AbstractDict ? mm[id][s] : mm(id, s)
    N = n !== nothing ? n : length(first(values(mult_p)))
    nr = _ok_nrows(m)
    U = zeros(2nr, N)
    for (id, ld) in get(net, "load", Dict())
        bi = get(m.busof, string(ld["bus"]), 0)
        bi == 0 && continue
        tm = string.(ld["terminal_map"])
        pn = ld["p_nom"] isa AbstractVector ? Float64.(ld["p_nom"]) : [Float64(ld["p_nom"])]
        qn = ld["q_nom"] isa AbstractVector ? Float64.(ld["q_nom"]) : [Float64(ld["q_nom"])]
        conf = uppercase(string(get(ld, "configuration", "WYE")))
        targets = Vector{Vector{Tuple{String,Float64}}}()
        for k in eachindex(pn)
            if conf == "DELTA"
                a = tm[k]; b = tm[mod1(k + 1, length(tm))]
                push!(targets, [(a, 0.5), (b, 0.5)])
            else
                push!(targets, [(tm[k], 1.0)])
            end
        end
        for s in 1:N
            fp = getm(mult_p, id, s); fq = getm(mult_q, id, s)
            for k in eachindex(pn), (t, w) in targets[k]
                r = get(m.rowof, (bi, t), 0)
                r == 0 && continue
                U[r, s] -= w * fp * pn[k] / m.sbase
                U[r+nr, s] -= w * fq * qn[min(k, length(qn))] / m.sbase
            end
        end
    end
    U
end

# ════════════════════════════════════════════════════════════════════════════
# Uncertainty sets (paper Table I) — over the active coordinates `idx`
# ════════════════════════════════════════════════════════════════════════════

"""
Abstract supertype of robust Opti-KRON uncertainty sets. Every set stores the
active injection coordinates `idx` (those nonzero in at least one training
sample); all other coordinates are fixed at zero.
"""
abstract type OptiKronSet end

"""
    OptiKronBox(U)
Per-coordinate box `[ℓ, h]` of the training samples `U` (`2nrows × N`).
"""
struct OptiKronBox <: OptiKronSet
    idx::Vector{Int}
    ubar::Vector{Float64}
    delta::Vector{Float64}
    samples::Matrix{Float64}
end

"""
    OptiKronHull(U)
Convex hull of the training samples (also the scenario-based model when `U`
holds only the chosen scenarios).
"""
struct OptiKronHull <: OptiKronSet
    idx::Vector{Int}
    samples::Matrix{Float64}
end

"""
    OptiKronEllipsoid(U; quantile=0.95, covariance=:poet, max_factors=5)
`{μ + L y : ‖y‖₂ ≤ Ω}` with `Σ = LLᵀ` estimated by POET (principal
orthogonal complement thresholding, at most `max_factors` factors, as in the
paper) or by linear shrinkage towards the diagonal (`covariance=:shrinkage`),
and `Ω` the `quantile` of the training samples' scaled distances
`‖L⁻¹(u−μ)‖₂`.
"""
struct OptiKronEllipsoid <: OptiKronSet
    idx::Vector{Int}
    mu::Vector{Float64}
    L::Matrix{Float64}
    Omega::Float64
    samples::Matrix{Float64}
end

"""
    OptiKronWasserstein(U; p=1, epsilon=0.01, quantile=0.95)
Type-1 Wasserstein ambiguity set around the empirical distribution with an
`ℓ_p` transport cost (`p ∈ (1, 2, Inf)`); the worst case is the CVaR at level
`1−ε` (paper eq. 7), with radius `ρ/ε` set to the `quantile` of the training
samples' leave-one-out distances to the convex hull of the other samples
(`radius=:hull`, default) or to their nearest other sample (`radius=:nearest`);
a number sets `ρ/ε` directly.
"""
struct OptiKronWasserstein <: OptiKronSet
    idx::Vector{Int}
    samples::Matrix{Float64}
    p::Float64
    epsilon::Float64
    radius::Float64
end

_ok_active(U) = [c for c in 1:size(U, 1) if any(!iszero, @view U[c, :])]

function OptiKronBox(U::AbstractMatrix)
    idx = _ok_active(U)
    lo = vec(minimum(U[idx, :], dims=2)); hi = vec(maximum(U[idx, :], dims=2))
    OptiKronBox(idx, (lo .+ hi) ./ 2, (hi .- lo) ./ 2, Matrix{Float64}(U[idx, :]))
end

OptiKronHull(U::AbstractMatrix) = (idx = _ok_active(U); OptiKronHull(idx, Matrix{Float64}(U[idx, :])))

function OptiKronEllipsoid(U::AbstractMatrix; quantile::Real=0.95, covariance::Symbol=:poet,
                           shrinkage::Real=0.1, max_factors::Int=5, poet_C::Real=0.5)
    idx = _ok_active(U)
    X = Matrix{Float64}(U[idx, :])
    mu = vec(sum(X, dims=2)) ./ size(X, 2)
    D = X .- mu
    S = Symmetric((D * D') ./ max(size(X, 2) - 1, 1))
    d = diag(S)
    floor = 1e-8 * max(maximum(d), 1e-12)
    Σ = if covariance === :poet
        _ok_poet(S, size(X, 2); max_factors=max_factors, C=poet_C)
    elseif covariance === :shrinkage
        (1 - shrinkage) .* S .+ shrinkage .* Diagonal(d)
    else
        throw(ArgumentError("covariance must be :poet or :shrinkage"))
    end
    L = cholesky(Symmetric(Matrix{Float64}(Σ) + floor * I)).L
    dist = [norm(L \ D[:, s]) for s in 1:size(X, 2)]
    OptiKronEllipsoid(idx, mu, Matrix{Float64}(L), Statistics.quantile(dist, quantile), X)
end

# POET (Fan, Liao & Mincheva 2013): K principal factors (eigenvalue-ratio
# choice, K ≤ max_factors) plus the soft-thresholded residual covariance with
# entry-adaptive thresholds C·√(r_ii r_jj)·(√(log p / N) + 1/√p). C is raised
# until the estimate is positive definite.
function _ok_poet(S::Symmetric, N::Int; max_factors::Int=5, C::Real=0.5)
    p = size(S, 1)
    ev = eigen(S)
    λ = reverse(ev.values); V = ev.vectors[:, end:-1:1]
    kmax = min(max_factors, p - 1)
    K = kmax ≥ 1 ? argmax([λ[k] / max(λ[k+1], eps()) for k in 1:kmax]) : 0
    Lr = K == 0 ? zeros(p, p) : V[:, 1:K] * Diagonal(λ[1:K]) * V[:, 1:K]'
    R = Matrix{Float64}(S) .- Lr
    rd = max.(diag(R), 0.0)
    ω = sqrt(log(p) / N) + 1 / sqrt(p)
    for c in (C, 2C, 4C, 8C, Inf)
        T = similar(R)
        for j in 1:p, i in 1:p
            if i == j
                T[i, j] = rd[i]
            else
                θ = isfinite(c) ? c * sqrt(rd[i] * rd[j]) * ω : Inf
                T[i, j] = sign(R[i, j]) * max(abs(R[i, j]) - θ, 0.0)
            end
        end
        Σ = Symmetric(Lr .+ T)
        isposdef(Matrix{Float64}(Σ) + 1e-10 * maximum(diag(Σ)) * I) && return Σ
    end
    Symmetric(Lr .+ Diagonal(rd))
end

function OptiKronWasserstein(U::AbstractMatrix; p::Real=1, epsilon::Real=0.01,
                             quantile::Real=0.95, radius=:hull,
                             hull_neighbors::Int=64)
    p in (1, 2, Inf) || throw(ArgumentError("p must be 1, 2 or Inf"))
    idx = _ok_active(U)
    X = Matrix{Float64}(U[idx, :])
    N = size(X, 2)
    N ≥ 2 || throw(ArgumentError("Wasserstein set needs ≥ 2 samples"))
    r = if radius isa Real
        Float64(radius)
    elseif radius === :nearest
        Statistics.quantile([minimum(norm(X[:, s] .- X[:, t], p) for t in 1:N if t != s)
                             for s in 1:N], quantile)
    elseif radius === :hull
        d = map(1:N) do s
            # hull of the (up to) `hull_neighbors` nearest other samples: a
            # subset hull, so the distance stays an upper bound
            cand = [t for t in 1:N if t != s]
            if length(cand) > hull_neighbors
                dd = [norm(X[:, t] .- X[:, s]) for t in cand]
                cand = cand[partialsortperm(dd, 1:hull_neighbors)]
            end
            others = X[:, cand]
            θ = _ok_simplex_projection_ls(others, X[:, s])
            # both are upper bounds on the ℓ_p distance to the hull
            min(norm(others * θ .- X[:, s], p),
                minimum(norm(c .- X[:, s], p) for c in eachcol(others)))
        end
        Statistics.quantile(d, quantile)
    else
        throw(ArgumentError("radius must be :hull, :nearest or a number"))
    end
    OptiKronWasserstein(idx, X, Float64(p), Float64(epsilon), r)
end

# argmin_{θ ∈ simplex} ‖Yθ − u‖₂ by accelerated projected gradient.
function _ok_simplex_projection_ls(Y::AbstractMatrix, u::AbstractVector; iters::Int=5000,
                                   tol::Real=1e-12)
    n = size(Y, 2)
    G = Y' * Y; b = Y' * u
    L = max(opnorm(G), eps())
    θ = fill(1.0 / n, n); z = copy(θ); t = 1.0
    for _ in 1:iters
        θn = _ok_proj_simplex(z .- (G * z .- b) ./ L)
        tn = (1 + sqrt(1 + 4t^2)) / 2
        z = θn .+ ((t - 1) / tn) .* (θn .- θ)
        done = norm(θn .- θ) ≤ tol
        θ = θn; t = tn
        done && break
    end
    θ
end

function _ok_proj_simplex(v::AbstractVector)
    w = sort(v; rev=true)
    cs = cumsum(w)
    k = findlast(i -> w[i] - (cs[i] - 1) / i > 0, eachindex(w))
    τ = (cs[k] - 1) / k
    max.(v .- τ, 0.0)
end

_ok_samples(S::OptiKronSet) = S.samples

"""
    _ok_wc(S, C) -> Vector{Float64}

Worst case `max_{u∈S} cᵀu` for every row `c` of `C` (columns ↔ `S.idx`).
"""
function _ok_wc(S::OptiKronBox, C::AbstractMatrix)
    C * S.ubar .+ abs.(C) * S.delta
end
function _ok_wc(S::OptiKronHull, C::AbstractMatrix)
    vec(maximum(C * S.samples, dims=2))
end
function _ok_wc(S::OptiKronEllipsoid, C::AbstractMatrix)
    CL = C * S.L
    C * S.mu .+ S.Omega .* [norm(@view CL[r, :]) for r in 1:size(C, 1)]
end
_ok_dualnorm(c, p) = p == 1 ? norm(c, Inf) : p == 2 ? norm(c, 2) : norm(c, 1)
function _ok_wc(S::OptiKronWasserstein, C::AbstractMatrix)
    V = C * S.samples
    N = size(V, 2)
    cap = min(1.0, 1 / (N * S.epsilon))
    out = similar(V, size(V, 1))
    for r in 1:size(V, 1)
        out[r] = _ok_cvar_greedy(view(V, r, :), cap) + S.radius * _ok_dualnorm(view(C, r, :), S.p)
    end
    out
end
function _ok_cvar_greedy(v, cap)
    ord = sortperm(v; rev=true)
    rem = 1.0; val = 0.0
    for k in ord
        θ = min(cap, rem); val += θ * v[k]; rem -= θ
        rem ≤ 0 && break
    end
    val
end

"""
    _ok_argmax(S, c) -> Vector{Float64}

A maximizer `u* ∈ S` of `cᵀu` (active coordinates only).
"""
_ok_argmax(S::OptiKronBox, c) = S.ubar .+ S.delta .* sign.(c)
_ok_argmax(S::OptiKronHull, c) = S.samples[:, argmax(S.samples' * c)]
function _ok_argmax(S::OptiKronEllipsoid, c)
    g = S.L' * c
    ng = norm(g)
    ng == 0 && return copy(S.mu)
    S.mu .+ S.Omega .* (S.L * g) ./ ng
end
function _ok_argmax(S::OptiKronWasserstein, c)
    v = S.samples' * c
    N = length(v)
    cap = min(1.0, 1 / (N * S.epsilon))
    u = zeros(size(S.samples, 1))
    rem = 1.0
    for k in sortperm(v; rev=true)
        θ = min(cap, rem); u .+= θ .* S.samples[:, k]; rem -= θ
        rem ≤ 0 && break
    end
    if S.p == 1
        m = argmax(abs.(c)); u[m] += S.radius * sign(c[m])
    elseif S.p == 2
        nc = norm(c); nc > 0 && (u .+= S.radius .* c ./ nc)
    else
        u .+= S.radius .* sign.(c)
    end
    u
end

# Is a training sample (active coords) inside S?
_ok_contains(S::OptiKronSet, u; tol=1e-9) = true
function _ok_contains(S::OptiKronEllipsoid, u; tol=1e-9)
    norm(S.L \ (u .- S.mu)) ≤ S.Omega * (1 + tol)
end

# ════════════════════════════════════════════════════════════════════════════
# Errors for a fixed assignment, and the adversary of Algorithm 1
# ════════════════════════════════════════════════════════════════════════════

# Error-coefficient matrix C (nrows × |idx|): row r=(j,ψ) holds c_{sup(j) j}(A)
# over the coordinates `idx`.
function _ok_coeffs(m::OptiKronModel, sup::AbstractVector{Int}, idx::AbstractVector{Int})
    nr = _ok_nrows(m)
    aggcol = similar(idx)
    for (a, c) in enumerate(idx)
        r = mod1(c, nr); isq = c > nr
        (k, t) = m.rows[r]
        aggcol[a] = _ok_col(m, sup[k], t, isq)
    end
    suprow = [m.rowof[(sup[j], t)] for (j, t) in m.rows]
    m.K[suprow, aggcol] .- m.K[:, idx]
end

"""
    opti_kron_errors(model, assignment, U) -> Matrix{Float64}

Linear-model voltage-magnitude errors `ṽ_{sup(j)} − v_j` (p.u.) of every row
for every injection sample (columns of `U`, `2nrows × N`) under the reduction
`assignment` (`assignment[j]` = super-node bus index of bus `j`).
"""
function opti_kron_errors(m::OptiKronModel, sup::AbstractVector{Int}, U::AbstractMatrix)
    idx = _ok_active(U)
    isempty(idx) && return zeros(_ok_nrows(m), size(U, 2))
    _ok_coeffs(m, sup, idx) * U[idx, :]
end

"""
    opti_kron_worst_errors(model, assignment, S) -> Vector{Float64}

Worst-case absolute error per row over the uncertainty set `S`.
"""
function opti_kron_worst_errors(m::OptiKronModel, sup::AbstractVector{Int}, S::OptiKronSet)
    C = _ok_coeffs(m, sup, S.idx)
    max.(_ok_wc(S, C), _ok_wc(S, -C))
end

# Adversary (13): largest violation Δ and worst-case injections of the (at
# most) K most-violated buses, as full-length (2nrows) vectors.
function _opti_kron_adversary(m::OptiKronModel, sup::AbstractVector{Int},
                              S::OptiKronSet, Ebar::Real, K::Int)
    C = _ok_coeffs(m, sup, S.idx)
    wp = _ok_wc(S, C); wn = _ok_wc(S, -C)
    nb = length(m.buses)
    busviol = fill(-Inf, nb); busrow = zeros(Int, nb); bussgn = ones(Int, nb)
    for (r, (j, _)) in enumerate(m.rows)
        for (val, sg) in ((wp[r], 1), (wn[r], -1))
            if val - Ebar > busviol[j]
                busviol[j] = val - Ebar; busrow[j] = r; bussgn[j] = sg
            end
        end
    end
    Δ = maximum(busviol)
    worst = Vector{Float64}[]
    for j in sortperm(busviol; rev=true)[1:min(K, nb)]
        busviol[j] > 1e-12 || break
        c = bussgn[j] .* C[busrow[j], :]
        u = zeros(2_ok_nrows(m)); u[S.idx] .= _ok_argmax(S, c)
        push!(worst, u)
    end
    Δ, worst
end

# ════════════════════════════════════════════════════════════════════════════
# Screening (paper §III-A)
# ════════════════════════════════════════════════════════════════════════════

"""
    OptiKronScreen

Result of [`opti_kron_screen`](@ref): `keep[p]` (pair `p` survives),
`redundant[p]` — `Set` of `(row, sign)` error constraints of pair `p` that
hold for every valid assignment with `A_ij = 1` — and counts per test.
"""
struct OptiKronScreen
    keep::BitVector
    redundant::Vector{Set{Tuple{Int,Int}}}
    n_test1::Int
    n_test2::Int
    n_path::Int
    n_redundant::Int
end

# Interval bounds of f(c) = c·a + |c|·d over c ∈ [lo, hi] (d ≥ 0).
@inline function _ok_box_term(lo, hi, a, d)
    flo = lo * a + abs(lo) * d; fhi = hi * a + abs(hi) * d
    mx = max(flo, fhi)
    mn = (lo < 0 < hi) ? min(flo, fhi, 0.0) : min(flo, fhi)
    mn, mx
end

"""
    opti_kron_screen(model, S, Ebar; passes=3, test2=true) -> OptiKronScreen

Presolve screening: test 1 removes pairs whose tree path carries a worst-case
voltage-magnitude difference above `2Ē` (eq. 9); test 2 bounds the error
coefficients by intervals over the remaining candidate super-nodes (eq. 11)
to find infeasible pairs (12a) and redundant error constraints (12b) — box
and convex hull only. The path rule propagates infeasibility along 𝒫_ij.
"""
function opti_kron_screen(m::OptiKronModel, S::OptiKronSet, Ebar::Real;
                          passes::Int=3, test2::Bool=true)
    np = length(m.pair_i)
    keep = trues(np)
    redundant = [Set{Tuple{Int,Int}}() for _ in 1:np]
    idx = S.idx
    Kact = m.K[:, idx]

    # ── test 1: worst |v_a − v_b| for row pairs on candidate paths ─────────
    need = Dict{Tuple{Int,Int},Float64}()
    for p in 1:np
        path = m.pair_path[p]
        length(path) < 2 && continue
        for x in 1:length(path), y in x+1:length(path)
            a, b = minmax(path[x], path[y])
            for t in m.phases[a]
                ra = get(m.rowof, (a, t), 0); rb = get(m.rowof, (b, t), 0)
                (ra == 0 || rb == 0) && continue
                need[(ra, rb)] = 0.0
            end
        end
    end
    keys_ = collect(keys(need))
    for c0 in 1:2048:length(keys_)
        ks = keys_[c0:min(c0 + 2047, length(keys_))]
        D = Kact[first.(ks), :] .- Kact[last.(ks), :]
        w = max.(_ok_wc(S, D), _ok_wc(S, -D))
        for (k, v) in zip(ks, w)
            need[k] = v
        end
    end
    n1 = 0
    for p in 1:np
        path = m.pair_path[p]
        bad = false
        for x in 1:length(path), y in x+1:length(path)
            a, b = minmax(path[x], path[y])
            for t in m.phases[a]
                ra = get(m.rowof, (a, t), 0); rb = get(m.rowof, (b, t), 0)
                (ra == 0 || rb == 0) && continue
                if need[(ra, rb)] > 2Ebar
                    bad = true; break
                end
            end
            bad && break
        end
        if bad && m.pair_i[p] != m.pair_j[p]
            keep[p] = false; n1 += 1
        end
    end

    pairof = Dict((m.pair_i[p], m.pair_j[p]) => p for p in 1:np)
    function path_rule!()
        changed = 0
        for p in 1:np
            keep[p] || continue
            i = m.pair_i[p]
            for k in m.pair_path[p]
                k == i && continue
                q = get(pairof, (i, k), 0)
                if q != 0 && !keep[q]
                    keep[p] = false; changed += 1; break
                end
            end
        end
        changed
    end
    npath = path_rule!()

    n2 = 0
    do2 = test2 && (S isa OptiKronBox || S isa OptiKronHull)
    nr = _ok_nrows(m)
    if do2
        for _ in 1:passes
            # interval of K[(i,ψ), (b(k), φ)] over remaining candidates b of k
            Kmin = fill(Inf, nr, length(idx)); Kmax = fill(-Inf, nr, length(idx))
            for (a, c) in enumerate(idx)
                r = mod1(c, nr); isq = c > nr
                (k, t) = m.rows[r]
                for p in m.cand[k]
                    keep[p] || continue
                    col = _ok_col(m, m.pair_i[p], t, isq)
                    @inbounds for rr in 1:nr
                        v = m.K[rr, col]
                        v < Kmin[rr, a] && (Kmin[rr, a] = v)
                        v > Kmax[rr, a] && (Kmax[rr, a] = v)
                    end
                end
            end
            colbus = [m.rows[mod1(c, nr)][1] for c in idx]
            newbad = 0
            lo = zeros(length(idx)); hi = zeros(length(idx))
            for p in 1:np
                keep[p] || continue
                i = m.pair_i[p]; j = m.pair_j[p]
                i == j == 1 && continue
                onpath = Set(m.pair_path[p])
                infeasible = false
                for t in m.phases[j]
                    ri = m.rowof[(i, t)]; rj = m.rowof[(j, t)]
                    for (a, c) in enumerate(idx)
                        if colbus[a] in onpath
                            r = mod1(c, nr); isq = c > nr
                            v = m.K[ri, _ok_col(m, i, m.rows[r][2], isq)] - Kact[rj, a]
                            lo[a] = v; hi[a] = v
                        else
                            lo[a] = Kmin[ri, a] - Kact[rj, a]
                            hi[a] = Kmax[ri, a] - Kact[rj, a]
                        end
                    end
                    if S isa OptiKronBox
                        lp = 0.0; up = 0.0; ln = 0.0; un = 0.0
                        @inbounds for a in eachindex(lo)
                            mn, mx = _ok_box_term(lo[a], hi[a], S.ubar[a], S.delta[a])
                            lp += mn; up += mx
                            mn, mx = _ok_box_term(lo[a], hi[a], -S.ubar[a], S.delta[a])
                            ln += mn; un += mx
                        end
                    else
                        X = S.samples
                        lp = -Inf; up = -Inf; ln = -Inf; un = -Inf
                        for s in 1:size(X, 2)
                            l_s = 0.0; u_s = 0.0
                            @inbounds for a in eachindex(lo)
                                x = X[a, s]
                                x1 = lo[a] * x; x2 = hi[a] * x
                                l_s += min(x1, x2); u_s += max(x1, x2)
                            end
                            lp = max(lp, l_s); up = max(up, u_s)
                            ln = max(ln, -u_s); un = max(un, -l_s)
                        end
                    end
                    if lp > Ebar || ln > Ebar
                        infeasible = true; break
                    end
                    up ≤ Ebar && push!(redundant[p], (rj, 1))
                    un ≤ Ebar && push!(redundant[p], (rj, -1))
                end
                if infeasible && i != j
                    keep[p] = false; newbad += 1; empty!(redundant[p])
                end
            end
            n2 += newbad
            npath += path_rule!()
            newbad == 0 && break
        end
    end
    nred = sum(length, redundant)
    OptiKronScreen(keep, redundant, n1, n2, npath, nred)
end

# ════════════════════════════════════════════════════════════════════════════
# Result type + entry-point stub (implemented in the JuMP extension)
# ════════════════════════════════════════════════════════════════════════════

# Eliminated buses whose Kron elimination creates mesh fill-in: Steiner-tree
# degree ≥ 3 with respect to the super-nodes (BFS tree of the model).
function _ok_radial_violations(m::OptiKronModel, sup::AbstractVector{Int})
    nb = length(m.buses)
    has = falses(nb)                       # subtree contains a super-node
    for v in nb:-1:1                       # BFS order ⇒ children after parents
        sup[v] == v && (has[v] = true)
        v > 1 && has[v] && (has[m.parent[v]] = true)
    end
    cnt = zeros(Int, nb)
    for v in 2:nb
        has[v] && (cnt[m.parent[v]] += 1)
    end
    [v for v in 2:nb if sup[v] != v && cnt[v] ≥ 2]
end

"""
    opti_kron_required_buses(net) -> Vector{String}

Buses that must stay super-nodes for a reduction to be representable as a
BMOPF case by [`kron_reduce_buses`](@ref): voltage-source buses and the
terminal buses of every transformer (eliminating a transformer terminal would
fold the transformer into a multi-port equivalent that BMOPF lines cannot
express). Pass the result as `keep` to [`opti_kron_reduction`](@ref).
"""
function opti_kron_required_buses(net::Dict{String,Any})
    req = Set{String}()
    for (_, vs) in get(net, "voltage_source", Dict())
        push!(req, string(vs["bus"]))
    end
    for (_, sub) in get(net, "transformer", Dict())
        sub isa AbstractDict || continue
        for (_, t) in sub
            t isa AbstractDict || continue
            refs = _ok_bus_refs(t)
            refs === nothing || union!(req, refs)
        end
    end
    sort!(collect(req))
end

"""
    OptiKronResult

Outcome of [`opti_kron_reduction`](@ref):
- `assignment[j]` — super-node bus index of bus `j` (`model.buses` order)
- `super_nodes` — bus ids kept; `reduction` — fraction of buses removed
- `max_violation` — final adversary value Δ (≤ 0 ⇒ certified for the set)
- `history` — per-iteration `(n_super, lower_bound, Δ, n_samples,
  master_time, master_status)`
- `screen` — the [`OptiKronScreen`](@ref) used
- `status` — `:optimal` (certified for the set and proven minimal),
  `:feasible` (certified, but the last master hit `master_time_limit`),
  `:time_limit`, `:iteration_limit`, `:stalled`, or the master's status
- `lower_bound` — proven lower bound on the number of super-nodes (the best
  master bound; valid whether or not the returned assignment is certified)
"""
struct OptiKronResult
    assignment::Vector{Int}
    super_nodes::Vector{String}
    reduction::Float64
    max_violation::Float64
    history::Vector{NamedTuple}
    screen::OptiKronScreen
    status::Symbol
    time::Float64
    lower_bound::Int
end

Base.show(io::IO, r::OptiKronResult) = print(io,
    "OptiKronResult($(length(r.super_nodes)) super-nodes (≥ $(r.lower_bound)), reduction=",
    round(100r.reduction, digits=1), "%, Δ=", r.max_violation, ", ",
    length(r.history), " iterations, status=", r.status, ")")

"""
    opti_kron_reduction(model, S, Ebar; optimizer, K=3, initial=nothing,
                        screen=true, max_iter=100, time_limit=Inf,
                        master_time_limit=Inf, preserve_radial=true,
                        keep=String[], silent=true) -> OptiKronResult

Robust Opti-KRON (prototype) solved by adversarial constraint generation
(paper Algorithm 1): a scenario-based MILP master over a growing finite set
`𝒰ᵗ ⊂ S` alternates with the closed-form adversary (13), adding the
worst-case injections of at most `K` violated buses per iteration, until the
reduction is certified for every injection in `S` (Δ ≤ 0).

- `optimizer` — a MILP-capable JuMP optimizer (e.g. `HiGHS.Optimizer`).
- `initial` — `2nrows × n` matrix of starting injections; by default the
  training samples of largest and smallest total net injection (if in `S`).
- `screen` — run [`opti_kron_screen`](@ref) first (or pass an
  `OptiKronScreen`).
- `preserve_radial` (default `true`) — require the Kron-reduced network to
  stay radial: no eliminated bus may join ≥ 3 tree directions that contain
  super-nodes (otherwise eliminating it creates mesh fill-in between them).
  This reproduces the paper's structural maximum of 88.6% (103 super-nodes)
  on the IEEE European LV feeder; without it the maximum is 91.1%.
- `keep` — bus ids forced to be super-nodes (e.g.
  [`opti_kron_required_buses`](@ref) for reductions that
  [`kron_reduce_buses`](@ref) must turn into a BMOPF case).
- `master_time_limit` — per-master limit; on expiry the incumbent is passed
  to the adversary, so a certified (but possibly non-minimal) reduction is
  still returned, with the proven `lower_bound`.

Requires the JuMP extension (`using JuMP`).
"""
function opti_kron_reduction end

# ════════════════════════════════════════════════════════════════════════════
# Data helper: standalone sub-network downstream of a bus
# ════════════════════════════════════════════════════════════════════════════

# BFS spanning tree from the single voltage source: (parent, children) by bus id.
function _ok_bfs_tree(net::Dict{String,Any})
    src = string(_ok_source(net)["bus"])
    adj = Dict{String,Vector{String}}()
    for (a, b, _) in _ok_edges(net)
        push!(get!(adj, a, String[]), b); push!(get!(adj, b, String[]), a)
    end
    par = Dict(src => "")
    q = [src]; h = 1
    while h ≤ length(q)
        u = q[h]; h += 1
        for w in sort(get(adj, u, String[]))
            haskey(par, w) && continue
            par[w] = u; push!(q, w)
        end
    end
    kids = Dict{String,Vector{String}}()
    for (w, u) in par
        u == "" && continue
        push!(get!(kids, u, String[]), w)
    end
    par, kids
end

"""
    downstream_bus_counts(net) -> Dict{String,Int}

Number of buses in the subtree below (and including) every bus, with respect
to the BFS spanning tree from the network's single voltage source. Useful to
pick roots for [`extract_downstream_network`](@ref).
"""
function downstream_bus_counts(net::Dict{String,Any})
    par, kids = _ok_bfs_tree(net)
    order = String[]; st = [first(k for (k, v) in par if v == "")]
    while !isempty(st)
        u = pop!(st); push!(order, u)
        append!(st, get(kids, u, String[]))
    end
    cnt = Dict{String,Int}()
    for u in Iterators.reverse(order)
        cnt[u] = 1 + sum((cnt[w] for w in get(kids, u, String[])); init=0)
    end
    cnt
end

"""
    extract_downstream_network(net, root_bus) -> Dict{String,Any}

Return a standalone copy of the part of `net` downstream of `root_bus` (with
respect to the BFS spanning tree from the network's single voltage source),
fed by a new ideal voltage source at `root_bus` whose phase-to-earth voltages
equal the full network's no-load voltages there. Elements are kept only if
every bus they reference lies in the sub-network; linecodes and case-level
metadata are copied. `meta["extracted_from"]` records the root and the number
of dropped boundary elements (nonzero for meshed boundaries).

Intended for trialing reductions on feeders of large models; the upstream
source impedance is not represented.
"""
function extract_downstream_network(net::Dict{String,Any}, root_bus::AbstractString;
                                    config=_DEFAULT_CONFIG, noload=nothing)
    root = string(root_bus)
    par, kids = _ok_bfs_tree(net)
    haskey(par, root) || throw(ArgumentError("bus $root is not connected to the source"))
    region = Set{String}([root]); st = [root]
    while !isempty(st)
        u = pop!(st)
        for w in get(kids, u, String[])
            push!(region, w); push!(st, w)
        end
    end

    y, V = noload === nothing ? opti_kron_noload(net; config=config) : noload
    ph, _ = _ok_phase_terminals(net, net["bus"][root])
    tm = String[]; vm = Float64[]; va = Float64[]
    for t in ph
        idx = get(y.index, (root, t), 0)
        idx == 0 && continue
        push!(tm, t); push!(vm, abs(V[idx])); push!(va, angle(V[idx]))
    end

    dropped = Ref(0)
    function filt(tbl::AbstractDict)
        out = Dict{String,Any}()
        for (id, e) in tbl
            if e isa AbstractDict
                refs = _ok_bus_refs(e)
                if refs === nothing
                    out[id] = deepcopy(e)
                elseif all(in(region), refs)
                    out[id] = deepcopy(e)
                elseif any(in(region), refs)
                    dropped[] += 1
                end
            else
                out[id] = deepcopy(e)
            end
        end
        out
    end
    sub = Dict{String,Any}()
    for (k, v) in net
        if k == "bus"
            sub[k] = Dict{String,Any}(b => deepcopy(d) for (b, d) in v if b in region)
        elseif k == "voltage_source"
            sub[k] = Dict{String,Any}("opti_kron_root" => Dict{String,Any}(
                "bus" => root, "terminal_map" => tm,
                "v_magnitude" => vm, "v_angle" => va))
        elseif k == "transformer" && v isa AbstractDict
            sub[k] = Dict{String,Any}(st => (t isa AbstractDict ? filt(t) : deepcopy(t))
                                      for (st, t) in v)
        elseif v isa AbstractDict && !isempty(v) && all(x -> x isa AbstractDict, values(v)) &&
               any(x -> _ok_bus_refs(x) !== nothing, values(v))
            sub[k] = filt(v)
        else
            sub[k] = deepcopy(v)
        end
    end
    meta = get!(sub, "meta", Dict{String,Any}())
    meta isa AbstractDict && (meta["extracted_from"] = Dict{String,Any}(
        "root_bus" => root, "n_buses" => length(region),
        "dropped_boundary_elements" => dropped[]))
    sub
end
