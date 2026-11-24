# opti_kron.jl — robust Opti-KRON master MILP and Algorithm 1 (PROTOTYPE)
#
# See src/network/opti_kron.jl for the model, uncertainty sets, screening and
# adversary. The master is problem (6) with 𝒰 replaced by a finite set 𝒰ᵗ:
# for every sample the aggregated injections are linear in A, the reduced
# voltages follow from the sparse linearized network equations
# (Yr·ΔV = ΔI(A u), ṽ = 1 + Re(M ΔV)), and each candidate pair's error is
# enforced with a big-M switch on A_ij.

using BMOPFTools: OptiKronModel, OptiKronSet, OptiKronScreen, OptiKronResult,
                  OptiKronHull, opti_kron_screen, _ok_nrows, _ok_col, _ok_contains,
                  _ok_radial_violations,
                  _opti_kron_adversary

mutable struct _OKMaster
    model::JuMP.Model
    A::Dict{Int,JuMP.VariableRef}
    selfpair::Vector{Int}
    kept::Vector{Int}
    Kmin::Matrix{Float64}   # min/max of K[(i,ψ),(b,φ)] over surviving candidates b
    Kmax::Matrix{Float64}   # of each active coordinate (big-M interval bounds)
    idx::Vector{Int}
    nsamples::Int
    samples::Vector{Vector{Float64}}
    Yscaled::SparseArrays.SparseMatrixCSC{Float64,Int}
    yrow_scale::Vector{Float64}
    Mt::SparseArrays.SparseMatrixCSC{ComplexF64,Int}
end

function _ok_build_master(m::OptiKronModel, scr::OptiKronScreen, idx, optimizer, silent;
                          preserve_radial::Bool=false, keepbus::Vector{Int}=Int[])
    jm = JuMP.Model(optimizer)
    silent && JuMP.set_silent(jm)
    np = length(m.pair_i)
    pairof = Dict((m.pair_i[p], m.pair_j[p]) => p for p in 1:np)
    keep = copy(scr.keep)
    # a pair whose path needs a non-candidate (i,k) cannot be connected
    changed = true
    while changed
        changed = false
        for p in 1:np
            keep[p] || continue
            i = m.pair_i[p]
            for k in m.pair_path[p]
                k == i && continue
                q = get(pairof, (i, k), 0)
                if q == 0 || !keep[q]
                    keep[p] = false; changed = true; break
                end
            end
        end
    end
    kept = findall(keep)
    A = Dict{Int,JuMP.VariableRef}()
    for p in kept
        A[p] = JuMP.@variable(jm, binary = true, base_name = "A_$(m.pair_i[p])_$(m.pair_j[p])")
    end
    nb = length(m.buses)
    selfpair = zeros(Int, nb)
    for p in kept
        m.pair_i[p] == m.pair_j[p] && (selfpair[m.pair_i[p]] = p)
    end
    for j in 1:nb
        ps = [p for p in m.cand[j] if haskey(A, p)]
        if isempty(ps)
            isempty(m.cand[j]) && continue
            error("bus $(m.buses[j]) has no surviving candidate super-node")
        end
        JuMP.@constraint(jm, sum(A[p] for p in ps) == 1)
    end
    JuMP.fix(A[selfpair[1]], 1.0; force=true)
    for v in keepbus
        selfpair[v] == 0 && continue
        JuMP.fix(A[selfpair[v]], 1.0; force=true)
    end
    for p in kept
        i = m.pair_i[p]; j = m.pair_j[p]
        i == j && continue
        JuMP.@constraint(jm, A[p] ≤ A[selfpair[i]])                       # (1a)
        for k in m.pair_path[p]
            (k == i || k == j) && continue
            JuMP.@constraint(jm, A[p] ≤ A[pairof[(i, k)]])                # (1b)
        end
    end
    JuMP.@objective(jm, Min, sum(A[selfpair[i]] for i in 1:nb if selfpair[i] != 0))
    preserve_radial && _ok_add_radial!(jm, m, A, selfpair)

    # K[(i,ψ),(b,φ)] interval over the surviving candidates b of each coordinate
    nr = _ok_nrows(m)
    Kmin = fill(Inf, nr, length(idx)); Kmax = fill(-Inf, nr, length(idx))
    for (a, c) in enumerate(idx)
        r = mod1(c, nr); isq = c > nr
        (k, t) = m.rows[r]
        for p in m.cand[k]
            haskey(A, p) || continue
            col = _ok_col(m, m.pair_i[p], t, isq)
            @inbounds for rr in 1:nr
                v = m.K[rr, col]
                v < Kmin[rr, a] && (Kmin[rr, a] = v)
                v > Kmax[rr, a] && (Kmax[rr, a] = v)
            end
        end
    end
    Kmin[isinf.(Kmin)] .= 0.0; Kmax[isinf.(Kmax)] .= 0.0
    rmax = vec(maximum(abs, m.Yr, dims=2))
    dsc = [r > 0 ? 1 / r : 1.0 for r in rmax]
    _OKMaster(jm, A, selfpair, kept, Kmin, Kmax, collect(idx), 0, Vector{Float64}[],
              SparseArrays.spdiagm(dsc) * m.Yr, dsc, SparseArrays.sparse(transpose(m.M)))
end

# Radial-preserving reduction: Kron elimination of a bus set R makes the
# super-nodes adjacent to each connected component of R a clique, so the
# reduced network stays radial iff no eliminated bus has ≥ 3 tree directions
# containing a super-node (Steiner-tree degree ≤ 2). The parent direction
# always contains the slack, so for an eliminated bus v at most one child
# subtree may contain a super-node: Σ_c y_c ≤ 1 + deg(v)·s_v, with
# y_c ≥ s_c and y_c ≥ y_g for the children g of c.
function _ok_add_radial!(jm, m::OptiKronModel, A, selfpair)
    nb = length(m.buses)
    sv(v) = selfpair[v] == 0 ? 1.0 : A[selfpair[v]]   # rowless buses are always kept
    children = [Int[] for _ in 1:nb]
    for v in 2:nb
        push!(children[m.parent[v]], v)
    end
    y = JuMP.@variable(jm, [1:nb], lower_bound = 0, upper_bound = 1, base_name = "radial_y")
    for c in 2:nb
        JuMP.@constraint(jm, y[c] ≥ sv(c))
        for g in children[c]
            JuMP.@constraint(jm, y[c] ≥ y[g])
        end
    end
    for v in 2:nb
        length(children[v]) ≥ 2 || continue
        JuMP.@constraint(jm, sum(y[c] for c in children[v]) ≤ 1 + length(children[v]) * sv(v))
    end
    y
end

# Add the error constraints of one injection sample u (full 2nrows vector).
function _ok_add_sample!(ms::_OKMaster, m::OptiKronModel, scr::OptiKronScreen,
                         u::AbstractVector, Ebar::Real)
    jm = ms.model; A = ms.A
    nr = _ok_nrows(m)
    ms.nsamples += 1
    push!(ms.samples, collect(u))
    s = ms.nsamples
    # aggregated injections per injection row (b, φ)
    Pagg = Dict{Int,JuMP.AffExpr}(); Qagg = Dict{Int,JuMP.AffExpr}()
    for p in ms.kept
        i = m.pair_i[p]; j = m.pair_j[p]
        for t in m.phases[j]
            rj = m.rowof[(j, t)]; ri = m.rowof[(i, t)]
            up = u[rj]; uq = u[rj+nr]
            up != 0 && JuMP.add_to_expression!(get!(Pagg, ri, JuMP.AffExpr(0.0)), up, A[p])
            uq != 0 && JuMP.add_to_expression!(get!(Qagg, ri, JuMP.AffExpr(0.0)), uq, A[p])
        end
    end
    nf = size(m.Iinj, 1)
    Ire = [JuMP.AffExpr(0.0) for _ in 1:nf]; Iim = [JuMP.AffExpr(0.0) for _ in 1:nf]
    rowsI = SparseArrays.rowvals(m.Iinj); valsI = SparseArrays.nonzeros(m.Iinj)
    for r in union(keys(Pagg), keys(Qagg))
        P = get(Pagg, r, JuMP.AffExpr(0.0)); Q = get(Qagg, r, JuMP.AffExpr(0.0))
        for k in SparseArrays.nzrange(m.Iinj, r)
            f = rowsI[k]; z = valsI[k]
            # z (P − jQ) = (aP + bQ) + j(bP − aQ)
            JuMP.add_to_expression!(Ire[f], real(z), P); JuMP.add_to_expression!(Ire[f], imag(z), Q)
            JuMP.add_to_expression!(Iim[f], imag(z), P); JuMP.add_to_expression!(Iim[f], -real(z), Q)
        end
    end
    x = JuMP.@variable(jm, [1:2nf], base_name = "dV_s$(s)")
    rhs = vcat(Ire, Iim)
    # row-equilibrated network equations (very short cables give conductances
    # of ~1e4–1e5 S; unscaled rows make MILP presolve numerically fragile)
    Yr = ms.Yscaled; dsc = ms.yrow_scale
    JuMP.@constraint(jm, Yr * x .== dsc .* rhs)
    # reduced voltages (only rows that appear in error constraints)
    Mt = ms.Mt
    vtil = Dict{Int,JuMP.AffExpr}()
    function vt(r)
        get!(vtil, r) do
            e = JuMP.AffExpr(1.0)
            rv = SparseArrays.rowvals(Mt); nz = SparseArrays.nonzeros(Mt)
            for k in SparseArrays.nzrange(Mt, r)
                f = rv[k]; w = nz[k]
                JuMP.add_to_expression!(e, real(w), x[f])
                JuMP.add_to_expression!(e, -imag(w), x[f+nf])
            end
            e
        end
    end
    v = 1.0 .+ m.K * u
    # interval of the reduced voltage ṽ_i over every assignment satisfying (1)
    ua = u[ms.idx]; up_ = max.(ua, 0.0); un_ = min.(ua, 0.0)
    vmax = 1.0 .+ ms.Kmax * up_ .+ ms.Kmin * un_
    vmin = 1.0 .+ ms.Kmin * up_ .+ ms.Kmax * un_
    for p in ms.kept
        i = m.pair_i[p]; j = m.pair_j[p]
        i == 1 && j == 1 && continue
        red = scr.redundant[p]
        for t in m.phases[j]
            ri = m.rowof[(i, t)]; rj = m.rowof[(j, t)]
            # big-M from the interval; skip constraints that cannot bind
            Mhi = vmax[ri] - v[rj] - Ebar
            Mlo = v[rj] - vmin[ri] - Ebar
            hi = !((rj, 1) in red) && Mhi > 0
            lo = !((rj, -1) in red) && Mlo > 0
            (hi || lo) || continue
            e = vt(ri)
            # The reduced voltage e comes from network equations the MILP solver
            # satisfies only to its feasibility tolerance (~1e-6), so a big-M
            # with no slack can cut off valid assignments (or make the master
            # infeasible). Keep a margin of Ē: far above solver noise, still far
            # tighter than a global bound.
            hi && JuMP.@constraint(jm, e - v[rj] ≤ Ebar + (Mhi + Ebar) * (1 - A[p]))
            lo && JuMP.@constraint(jm, e - v[rj] ≥ -Ebar - (Mlo + Ebar) * (1 - A[p]))
        end
    end
    ms
end

# MIP-start repair: split every cluster holding a bus that violates the bound
# on a master sample into singletons (all-singleton is always feasible).
function _ok_repair(m::OptiKronModel, sup::Vector{Int}, Ut::Matrix{Float64}, Ebar::Real;
                    preserve_radial::Bool=false, keep::Vector{Int}=Int[])
    sup = copy(sup)
    for v in keep
        sup[v] == v && continue
        i = sup[v]
        for k in eachindex(sup)
            sup[k] == i && (sup[k] = k)
        end
    end
    for _ in 1:length(sup)
        E = BMOPFTools.opti_kron_errors(m, sup, Ut)
        bad = Set{Int}()
        for (r, (j, _)) in enumerate(m.rows)
            maximum(abs, @view E[r, :]) > Ebar * (1 - 1e-6) && push!(bad, sup[j])
        end
        if preserve_radial
            for v in _ok_radial_violations(m, sup)
                push!(bad, sup[v])
            end
        end
        isempty(bad) && return sup
        before = copy(sup)
        for k in eachindex(sup)
            sup[k] in bad && (sup[k] = k)
        end
        sup == before && break                 # no progress: use all-singletons
    end
    collect(eachindex(sup))                    # always feasible (zero error)
end

function _ok_assignment(ms::_OKMaster, m::OptiKronModel)
    sup = collect(1:length(m.buses))
    for p in ms.kept
        JuMP.value(ms.A[p]) > 0.5 && (sup[m.pair_j[p]] = m.pair_i[p])
    end
    sup
end

function BMOPFTools.opti_kron_reduction(m::OptiKronModel, S::OptiKronSet, Ebar::Real;
                                        optimizer, K::Int=3, initial=nothing,
                                        screen=true, max_iter::Int=100,
                                        time_limit::Real=Inf, master_time_limit::Real=Inf,
                                        silent::Bool=true, preserve_radial::Bool=true,
                                        keep=String[],
                                        tol::Real=1e-3 * Ebar, verbose::Bool=false)
    t0 = time()
    scr = screen isa OptiKronScreen ? screen :
          screen === true ? opti_kron_screen(m, S, Ebar) :
          OptiKronScreen(trues(length(m.pair_i)),
                         [Set{Tuple{Int,Int}}() for _ in m.pair_i], 0, 0, 0, 0)
    verbose && @info "opti_kron screening" kept = count(scr.keep) of = length(scr.keep) redundant = scr.n_redundant time = time() - t0
    nr = _ok_nrows(m)
    keepidx = Int[]
    for b in keep
        haskey(m.busof, string(b)) || throw(ArgumentError("keep: bus $b is not in the model"))
        push!(keepidx, m.busof[string(b)])
    end
    ms = _ok_build_master(m, scr, S.idx, optimizer, silent; preserve_radial=preserve_radial,
                          keepbus=keepidx)

    # 𝒰⁰: training samples of largest and smallest total net injection
    U0 = Vector{Float64}[]
    if initial === nothing
        X = S.samples
        tot = vec(sum(X, dims=1))
        for s in unique([argmax(tot), argmin(tot)])
            _ok_contains(S, X[:, s]) || continue
            u = zeros(2nr); u[S.idx] .= X[:, s]; push!(U0, u)
        end
    else
        size(initial, 1) == 2nr || throw(ArgumentError("initial must have 2·nrows = $(2nr) rows"))
        inactive = setdiff(1:2nr, S.idx)
        for (s, c) in enumerate(eachcol(initial))
            all(iszero, view(c, inactive)) || throw(ArgumentError(
                "initial column $s injects at coordinates outside the set's active ones"))
            _ok_contains(S, c[S.idx]) || throw(ArgumentError(
                "initial column $s is not in the uncertainty set; the master would no " *
                "longer be a relaxation"))
            push!(U0, Vector{Float64}(c))
        end
    end
    for u in U0
        _ok_add_sample!(ms, m, scr, u, Ebar)
    end
    # always-feasible MIP start (repaired from all-singletons ⇒ never empty)
    if !isempty(ms.samples)
        start = _ok_repair(m, collect(1:length(m.buses)), reduce(hcat, ms.samples), Ebar;
                           preserve_radial=preserve_radial, keep=keepidx)
        for p in ms.kept
            JuMP.set_start_value(ms.A[p], start[m.pair_j[p]] == m.pair_i[p] ? 1.0 : 0.0)
        end
    end

    history = NamedTuple[]
    status = :iteration_limit
    sup = collect(1:length(m.buses)); Δ = Inf
    prev = nothing
    lower = 0.0
    last_optimal = false
    for it in 1:max_iter
        rem = time_limit - (time() - t0)
        rem ≤ 0 && (status = :time_limit; break)
        lim = min(rem, master_time_limit)
        isfinite(lim) && JuMP.set_time_limit_sec(ms.model, lim)
        tm = @elapsed JuMP.optimize!(ms.model)
        ts = JuMP.termination_status(ms.model)
        if !JuMP.has_values(ms.model) || !(ts in (JuMP.MOI.OPTIMAL, JuMP.MOI.TIME_LIMIT))
            status = Symbol(ts); break
        end
        last_optimal = ts == JuMP.MOI.OPTIMAL
        # master bound is a valid lower bound for (6) since 𝒰ᵗ ⊂ 𝒰
        bnd = last_optimal ? JuMP.objective_value(ms.model) : JuMP.objective_bound(ms.model)
        lower = max(lower, ceil(bnd - 1e-6))
        sup = _ok_assignment(ms, m)
        Δ, worst = _opti_kron_adversary(m, sup, S, Ebar, K)
        nsup = count(i -> ms.selfpair[i] != 0 && sup[i] == i, 1:length(m.buses))
        push!(history, (iteration=it, n_super=nsup, lower_bound=lower, violation=Δ,
                        n_samples=ms.nsamples, master_time=tm, master_status=Symbol(ts)))
        verbose && @info "opti_kron iteration" it nsup lower Δ samples = ms.nsamples master_time = tm ts
        if Δ ≤ tol
            status = last_optimal ? :optimal : :feasible; break
        end
        if prev == sup && isempty(worst)
            status = :stalled; break
        end
        # every proposed worst case is already enforced: the remaining
        # violation is solver feasibility tolerance, not a missing sample
        if !isempty(worst) && all(u -> any(v -> maximum(abs.(u .- v)) ≤ 1e-12 * max(1.0, maximum(abs, u)),
                                           ms.samples), worst)
            status = Δ ≤ 10tol ? (last_optimal ? :optimal : :feasible) : :stalled
            break
        end
        prev = copy(sup)
        # 𝒰ᵗ only grows, so the master optimum never decreases: a valid cut
        JuMP.@constraint(ms.model, JuMP.objective_function(ms.model) ≥ lower)
        for u in worst
            _ok_add_sample!(ms, m, scr, u, Ebar)
        end
        start = _ok_repair(m, sup, reduce(hcat, ms.samples), Ebar; preserve_radial=preserve_radial,
                           keep=keepidx)
        for p in ms.kept
            JuMP.set_start_value(ms.A[p], start[m.pair_j[p]] == m.pair_i[p] ? 1.0 : 0.0)
        end
    end
    counted = [i for i in 1:length(m.buses) if !isempty(m.cand[i])]
    supers = [m.buses[i] for i in counted if sup[i] == i]

    OptiKronResult(sup, supers, 1 - length(supers) / length(counted), Δ, history,
                   scr, status, time() - t0, Int(lower))
end
