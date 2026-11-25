# network/kron_reduce.jl
#
# PROTOTYPE — turn an Opti-KRON assignment into a solvable BMOPF case.
#
# Given the assignment (every bus → its super-node), the reduced case is built
# in two exact steps plus one certified one:
#
#   1. Relocate devices. Every load, generator and IBR at an eliminated bus is
#      re-attached, phase by phase (same terminal labels), to its super-node.
#      Devices stay separate objects, so their own limits and costs survive.
#      This is the only approximation; robust Opti-KRON bounds its voltage
#      effect by Ē (under the linear model, for injections in the set).
#   2. Eliminate. The eliminated buses now carry no injection, so the passive
#      network can be Kron-reduced exactly (Schur complement of the
#      multiconductor admittance matrix, neutrals and groundings included):
#
#          Y_eq = Y_KK − Y_KR · Y_RR⁻¹ · Y_RK
#
#      over the elements that touch an eliminated bus. Elements between two
#      kept buses (and every transformer) are copied unchanged. Y_eq is then
#      written back as BMOPF elements: each pairwise block becomes a line with
#      inline series impedance (−Y_ab)⁻¹, the remainder Y_aa + Σ_b Y_ab a
#      shunt. For the AC model this step is exact.
#   3. Certify voltage limits (optional, `Ebar`). Bus j within ±Ē of its
#      super-node i stays inside its own limits if i's band is tightened by
#      Ē: |Ũ_i| ≥ (U_j^min + Ē·U0_j)·U0_i/U0_j and similarly for the maximum.
#
# Current limits of eliminated lines have no exact equivalent and are dropped
# (recorded in the log, not guessed). Like `simplify_network`, the result is a
# one-way solve-time compile target; keep the source case.

const _KR_PASSIVE = ("line", "switch", "shunt", "capacitor")

"""
    kron_reduce_buses(net, model, assignment; Ebar=nothing, sym_tol=1e-4,
                        allow_mesh=false, config=_DEFAULT_CONFIG) -> Dict

Build the reduced BMOPF case for an Opti-KRON reduction (prototype).
`assignment[j]` is the super-node bus index of bus `j` in `model.buses` order
(e.g. `result.assignment` of [`opti_kron_reduction`](@ref)); an
[`OptiKronResult`](@ref) may be passed directly.

- Devices at eliminated buses are re-attached to their super-node.
- The passive network is Kron-reduced exactly and written back as equivalent
  lines (inline impedance, ids `kron_eq:<a>:<b>`) and shunts
  (`kron_sh:<a>`). A pairwise block must be symmetric to be a BMOPF line; it
  is symmetrized when its relative asymmetry is ≤ `sym_tol`, refused above.
- `Ebar` (p.u., as in the reduction) tightens super-node voltage limits so
  every eliminated bus stays inside its own limits within the certificate.
- A kept terminal tied to earth by a zero-impedance path through eliminated
  buses (e.g. a closed switch to a perfectly grounded neutral) stays perfectly
  grounded in the reduced case.
- Refuses (`ArgumentError`) instead of guessing when: a voltage source or
  transformer terminal is eliminated (keep [`opti_kron_required_buses`](@ref)),
  an unsupported component sits on an eliminated bus, eliminating a bus would
  create mesh fill-in on the physical graph (unless `allow_mesh`), a block
  cannot be expressed, an eliminated element or bus is time-varying (reduce a
  [`get_snapshot`](@ref) instead), or, with `Ebar`, the fixed slack voltage
  cannot certify the limits of a bus the slack represents.

The log `reduced["_kron_reduction"]` records the assignment, equivalents,
asymmetry, dropped current limits and voltage tightening.
"""
function kron_reduce_buses(net::Dict{String,Any}, m::OptiKronModel,
                             sup::AbstractVector{Int}; Ebar::Union{Nothing,Real}=nothing,
                             sym_tol::Real=1e-4, allow_mesh::Bool=false,
                             config=_DEFAULT_CONFIG)
    length(sup) == length(m.buses) ||
        throw(ArgumentError("assignment length $(length(sup)) ≠ $(length(m.buses)) model buses"))
    for (j, i) in enumerate(sup)
        sup[i] == i || throw(ArgumentError("bus $(m.buses[j]) is assigned to $(m.buses[i]), " *
                                           "which is not a super-node"))
    end
    superof = Dict{String,String}(m.buses[j] => m.buses[sup[j]] for j in eachindex(sup)
                                  if sup[j] != j)
    elim = Set(keys(superof))
    for b in opti_kron_required_buses(net)
        b in elim && throw(ArgumentError(
            "bus $b (voltage source or transformer terminal) is eliminated; pass " *
            "keep = opti_kron_required_buses(net) to opti_kron_reduction"))
    end
    _kr_preflight_time_series(net, elim, Ebar !== nothing)
    fillin = _kr_fill_in(net, m, elim)
    if !isempty(fillin) && !allow_mesh
        throw(ArgumentError("eliminating $(length(fillin)) bus(es) creates mesh fill-in " *
                            "(e.g. $(fillin[1])); reduce with preserve_radial=true " *
                            "or pass allow_mesh=true"))
    end

    # ── classify components ────────────────────────────────────────────────
    red = Dict{String,Any}()
    sub = Dict{String,Any}("bus" => Dict{String,Any}(),
                           "linecode" => deepcopy(get(net, "linecode", Dict{String,Any}())))
    haskey(net, "terminal_conventions") &&
        (sub["terminal_conventions"] = deepcopy(net["terminal_conventions"]))
    dropped_limits = String[]
    moved = 0
    added_ground = Set{Tuple{String,String}}()
    touches(e) = (r = _ok_bus_refs(e); r !== nothing && any(in(elim), r))
    for (k, v) in net
        if k == "bus"
            red[k] = Dict{String,Any}(b => deepcopy(d) for (b, d) in v if !(b in elim))
        elseif k in _KR_PASSIVE && v isa AbstractDict
            keep_tbl = Dict{String,Any}(); el_tbl = Dict{String,Any}()
            for (id, e) in v
                if e isa AbstractDict && touches(e)
                    el_tbl[id] = deepcopy(e)
                    if k == "line" && (haskey(e, "i_max") || haskey(e, "s_max") ||
                                       _kr_linecode_has_limit(net, e))
                        push!(dropped_limits, id)
                    end
                else
                    keep_tbl[id] = deepcopy(e)
                end
            end
            red[k] = keep_tbl
            isempty(el_tbl) || (sub[k] = el_tbl)
        elseif k == "transformer" && v isa AbstractDict
            for (_, tbl) in v, (id, e) in (tbl isa AbstractDict ? tbl : Dict())
                e isa AbstractDict && touches(e) && throw(ArgumentError(
                    "transformer $id touches an eliminated bus"))
            end
            red[k] = deepcopy(v)
        elseif k == "voltage_source" && v isa AbstractDict
            any(e -> e isa AbstractDict && touches(e), values(v)) &&
                throw(ArgumentError("a voltage source sits on an eliminated bus"))
            red[k] = deepcopy(v)
        elseif v isa AbstractDict && !isempty(v) && all(x -> x isa AbstractDict, values(v)) &&
               any(x -> _ok_bus_refs(x) !== nothing, values(v))
            tbl = Dict{String,Any}()
            for (id, e) in v
                e2 = deepcopy(e)
                if e isa AbstractDict && touches(e)
                    (haskey(e, "bus") && !haskey(e, "bus_from") && !haskey(e, "buses")) ||
                        throw(ArgumentError("unsupported multi-bus component $k/$id on an " *
                                            "eliminated bus"))
                    src = string(e["bus"]); tgt = superof[src]
                    srcgnd = string.(get(net["bus"][src], "perfectly_grounded_terminals", String[]))
                    tn = string.(get(net["bus"][tgt], "terminal_names", String[]))
                    for t in string.(get(e, "terminal_map", String[]))
                        t in tn && continue
                        # a terminal earthed at the original bus is earthed at
                        # the super-node too: add it there as perfectly grounded
                        t in srcgnd || throw(ArgumentError(
                            "$k/$id uses terminal $t, absent at super-node $tgt"))
                        push!(added_ground, (tgt, t))
                    end
                    e2["bus"] = tgt; moved += 1
                end
                tbl[id] = e2
            end
            red[k] = tbl
        else
            red[k] = deepcopy(v)
        end
    end

    # ── exact Kron elimination of the passive elements that touch R ────────
    eq_lines = Dict{String,Any}(); eq_shunts = Dict{String,Any}()
    max_asym = 0.0
    touched = Set{String}()
    for k in _KR_PASSIVE, (_, e) in get(sub, k, Dict())
        union!(touched, _ok_bus_refs(e))
    end
    if !isempty(touched)
        for b in touched
            sub["bus"][b] = deepcopy(net["bus"][b])
        end
        y = ybus_passive(sub; config=config)
        n = size(y.Y, 1)
        kept_alias = [Tuple{String,String}[] for _ in 1:n]
        for (bt, r) in y.index
            bt[1] in elim && continue
            if r == 0
                # a kept terminal tied to earth by a zero-impedance path through
                # eliminated buses keeps that ideal ground in the reduced case
                own = string.(get(net["bus"][bt[1]], "perfectly_grounded_terminals", String[]))
                bt[2] in own || push!(added_ground, bt)
                continue
            end
            push!(kept_alias[r], bt)
        end
        for r in 1:n
            length(unique(first.(kept_alias[r]))) ≤ 1 || throw(ArgumentError(
                "eliminated zero-impedance path shorts kept buses " *
                "$(unique(first.(kept_alias[r]))); not supported"))
        end
        K = [r for r in 1:n if !isempty(kept_alias[r])]
        R = [r for r in 1:n if isempty(kept_alias[r]) && nnz(y.Y[:, r]) > 0]
        Y = y.Y
        Yeq = Matrix{ComplexF64}(Y[K, K])
        if !isempty(R)
            F = lu(Y[R, R])
            Yeq .-= Matrix{ComplexF64}(Y[K, R]) * (F \ Matrix{ComplexF64}(Y[R, K]))
        end
        # rows of each kept bus, in the bus's terminal order
        pos = Dict{Tuple{String,String},Int}()
        for (a, r) in enumerate(K), bt in kept_alias[r]
            pos[bt] = a
        end
        kb = sort!(unique(first.(collect(keys(pos)))))
        terms(b) = [t for t in string.(net["bus"][b]["terminal_names"]) if haskey(pos, (b, t))]
        scale = maximum(abs, Yeq; init=0.0)
        ztol = 1e-12 * max(scale, 1.0)
        Ysh = Dict(b => Matrix{ComplexF64}(Yeq[[pos[(b, t)] for t in terms(b)], [pos[(b, t)] for t in terms(b)]])
                   for b in kb)
        for x in 1:length(kb), z in x+1:length(kb)
            a = kb[x]; b = kb[z]
            ta = terms(a); tb = terms(b)
            Bab = Yeq[[pos[(a, t)] for t in ta], [pos[(b, t)] for t in tb]]
            maximum(abs, Bab; init=0.0) ≤ ztol && continue
            T = [t for t in ta if t in tb]
            ia = [findfirst(==(t), ta) for t in T]; ib = [findfirst(==(t), tb) for t in T]
            rest = copy(Bab); rest[ia, ib] .= 0
            maximum(abs, rest; init=0.0) ≤ ztol || throw(ArgumentError(
                "equivalent between $a and $b couples different terminal labels"))
            Ys = -Bab[ia, ib]
            keepc = [k for k in eachindex(T) if maximum(abs, view(Ys, k, :)) > ztol]
            T = T[keepc]; Ys = Ys[keepc, keepc]; ia = ia[keepc]; ib = ib[keepc]
            asym = norm(Ys - transpose(Ys)) / max(norm(Ys), eps())
            max_asym = max(max_asym, asym)
            asym ≤ sym_tol || throw(ArgumentError(
                "equivalent between $a and $b is asymmetric ($(asym)); not a BMOPF line"))
            Ys = (Ys + transpose(Ys)) / 2
            Z = inv(Ys)
            ln = Dict{String,Any}("bus_from" => a, "bus_to" => b,
                                  "terminal_map_from" => T, "terminal_map_to" => T)
            for p in eachindex(T), q in eachindex(T)
                ln["R_series_$(p)_$(q)"] = real(Z[p, q]); ln["X_series_$(p)_$(q)"] = imag(Z[p, q])
            end
            eq_lines["kron_eq:$a:$b"] = ln
            Ysh[a][ia, ia] .-= Ys
            Ysh[b][ib, ib] .-= Ys
        end
        for b in kb
            Ys = Ysh[b]
            maximum(abs, Ys; init=0.0) ≤ ztol && continue
            Ys = (Ys + transpose(Ys)) / 2
            sh = Dict{String,Any}("bus" => b, "terminal_map" => terms(b))
            for p in axes(Ys, 1), q in axes(Ys, 2)
                sh["G_$(p)_$(q)"] = real(Ys[p, q]); sh["B_$(p)_$(q)"] = imag(Ys[p, q])
            end
            eq_shunts["kron_sh:$b"] = sh
        end
    end
    for (b, t) in added_ground
        bd = red["bus"][b]
        tn = get!(bd, "terminal_names", String[])
        t in string.(tn) || push!(tn, t)
        pg = get!(bd, "perfectly_grounded_terminals", String[])
        t in string.(pg) || push!(pg, t)
    end
    merge!(get!(red, "line", Dict{String,Any}()), eq_lines)
    merge!(get!(red, "shunt", Dict{String,Any}()), eq_shunts)

    # ── certified voltage-limit tightening ─────────────────────────────────
    # The certificate bounds the model's row magnitudes (phase-to-neutral where
    # the bus has an ungrounded neutral, else phase-to-earth), and it bounds
    # e_ij for every pair the reduction uses, including e_ii of each kept bus.
    tightened = 0; empty_bands = String[]
    if Ebar !== nothing
        # The slack's voltage is fixed, so its band cannot be tightened. A bus
        # it represents is certified only if that fixed magnitude lies inside
        # the bus's tightened band; otherwise the assignment is refused.
        slack_bad = String[]
        for j in 2:length(sup)
            sup[j] == 1 || continue
            bj = net["bus"][m.buses[j]]
            for (fmin, fmax) in _kr_row_limit_fields(net, bj)
                (haskey(bj, fmin) || haskey(bj, fmax)) || continue
                for (kj, t) in enumerate(_kr_limit_phases(net, bj))
                    rj = get(m.rowof, (j, t), 0); ri = get(m.rowof, (1, t), 0)
                    (rj == 0 || ri == 0) && continue
                    ratio = m.u0[ri] / m.u0[rj]; vs = m.u0[ri]
                    lo0 = _kr_limit(bj, fmin, kj); hi0 = _kr_limit(bj, fmax, kj)
                    lo = lo0 === nothing ? -Inf : (lo0 + Ebar * m.u0[rj]) * ratio
                    hi = hi0 === nothing ? Inf : (hi0 - Ebar * m.u0[rj]) * ratio
                    tolv = 1e-9 * vs
                    (lo - tolv ≤ vs ≤ hi + tolv) || push!(slack_bad, "$(m.buses[j]):$t")
                end
            end
        end
        isempty(slack_bad) || throw(ArgumentError(
            "the fixed slack voltage cannot certify the voltage limits of " *
            "$(join(unique(slack_bad), ", ")) within Ebar; keep those buses " *
            "(opti_kron_reduction keep=...) or reduce without Ebar"))
        pairs_ = [(m.buses[j], m.buses[sup[j]]) for j in eachindex(sup) if sup[j] != 1]
        for (jb, ib) in pairs_
            j = m.busof[jb]; i = m.busof[ib]
            bj = net["bus"][jb]; bi = red["bus"][ib]
            fields = _kr_row_limit_fields(net, bj)
            fields == _kr_row_limit_fields(net, net["bus"][ib]) || continue
            phj = _kr_limit_phases(net, bj); phi = _kr_limit_phases(net, net["bus"][ib])
            for (fmin, fmax) in fields
                (haskey(bj, fmin) || haskey(bj, fmax)) || continue
                for (kj, t) in enumerate(phj)
                    ki = findfirst(==(t), phi); ki === nothing && continue
                    rj = get(m.rowof, (j, t), 0); ri = get(m.rowof, (i, t), 0)
                    (rj == 0 || ri == 0) && continue
                    ratio = m.u0[ri] / m.u0[rj]
                    lo0 = _kr_limit(bj, fmin, kj)
                    if lo0 !== nothing
                        lo = (lo0 + Ebar * m.u0[rj]) * ratio
                        arr = _kr_limit_vector!(bi, fmin, length(phi), 0.0)
                        if lo > arr[ki]
                            arr[ki] = lo; tightened += 1
                        end
                    end
                    hi0 = _kr_limit(bj, fmax, kj)
                    if hi0 !== nothing
                        hi = (hi0 - Ebar * m.u0[rj]) * ratio
                        arr = _kr_limit_vector!(bi, fmax, length(phi), 10 * m.u0[ri])
                        if hi < arr[ki]
                            arr[ki] = hi; tightened += 1
                        end
                    end
                    lo_i = _kr_limit(bi, fmin, ki); hi_i = _kr_limit(bi, fmax, ki)
                    lo_i !== nothing && hi_i !== nothing && lo_i > hi_i && push!(empty_bands, ib)
                end
            end
        end
    end

    red["_kron_reduction"] = Dict{String,Any}(
        "method" => "opti_kron (prototype)",
        "super_node_of" => superof,
        "n_eliminated" => length(elim),
        "n_devices_moved" => moved,
        "equivalent_lines" => sort!(collect(keys(eq_lines))),
        "equivalent_shunts" => sort!(collect(keys(eq_shunts))),
        "max_symmetrized_asymmetry" => max_asym,
        "dropped_line_current_limits" => sort!(dropped_limits),
        "Ebar_pu" => Ebar === nothing ? nothing : Float64(Ebar),
        "n_voltage_limits_tightened" => tightened,
        "empty_voltage_bands" => sort!(unique(empty_bands)),
        "mesh_fill_in_buses" => fillin,
        "grounded_terminals_added" => sort!(["$b:$t" for (b, t) in added_ground]))
    red
end

# Eliminated buses whose elimination creates mesh fill-in, on the physical
# graph (every closed branch, including edges outside the model's BFS tree).
# Kron elimination of a connected group of eliminated buses couples every kept
# bus adjacent to the group; with three or more such buses the equivalent forms
# a new loop. On radial inputs this is the Steiner-degree rule of
# `_ok_radial_violations`.
function _kr_fill_in(net, m::OptiKronModel, elim)
    adj = Dict{String,Set{String}}()
    for (a, b, _) in _ok_edges(net)
        a == b && continue
        push!(get!(adj, a, Set{String}()), b); push!(get!(adj, b, Set{String}()), a)
    end
    seen = Set{String}(); bad = String[]
    for s0 in sort!(collect(elim))
        s0 in seen && continue
        comp = String[]; border = Set{String}(); stack = [s0]; push!(seen, s0)
        while !isempty(stack)
            v = pop!(stack); push!(comp, v)
            for w in get(adj, v, Set{String}())
                if w in elim
                    w in seen || (push!(seen, w); push!(stack, w))
                else
                    push!(border, w)
                end
            end
        end
        length(border) ≥ 3 && append!(bad, comp)
    end
    sort!(bad)
end

# The equivalents are computed from one static snapshot. Refuse instead of
# freezing a time-varying impedance or limit; devices keep their own profiles.
function _kr_preflight_time_series(net, elim, tighten::Bool)
    has_ts(e) = e isa AbstractDict && get(e, "time_series", nothing) isa AbstractDict &&
                !isempty(e["time_series"])
    bad = String[]
    for b in elim
        has_ts(net["bus"][b]) && push!(bad, "bus/$b")
    end
    lcs = get(net, "linecode", Dict())
    for k in _KR_PASSIVE, (id, e) in get(net, k, Dict())
        e isa AbstractDict || continue
        r = _ok_bus_refs(e)
        (r !== nothing && any(in(elim), r)) || continue
        has_ts(e) && push!(bad, "$k/$id")
        lc = get(e, "linecode", nothing)
        lc !== nothing && has_ts(get(lcs, string(lc), nothing)) && push!(bad, "linecode/$lc")
    end
    if tighten
        for (b, d) in get(net, "bus", Dict())
            b in elim && continue
            ts = get(d, "time_series", nothing)
            ts isa AbstractDict && any(f -> string(f) in ("v_min", "v_max", "vpn_min", "vpn_max"),
                                       keys(ts)) && push!(bad, "bus/$b (voltage limits)")
        end
    end
    isempty(bad) || throw(ArgumentError(
        "time-varying data would be frozen by the reduction: $(join(sort!(unique(bad)), ", ")); " *
        "reduce a materialized snapshot (get_snapshot(net, t)) instead"))
    nothing
end

kron_reduce_buses(net::Dict{String,Any}, m::OptiKronModel, r::OptiKronResult; kw...) =
    kron_reduce_buses(net, m, r.assignment; kw...)

# Terminals indexing v_min/v_max/vpn_* arrays: every non-neutral terminal, as
# the OPF indexes them (perfectly grounded phases are not skipped).
function _kr_limit_phases(net, bus)
    _, neutral = _ok_phase_terminals(net, bus)
    [string(t) for t in get(bus, "terminal_names", String[]) if string(t) != neutral]
end

# Which limit fields the model's row magnitudes bound at this bus.
function _kr_row_limit_fields(net, bus)
    _, neutral = _ok_phase_terminals(net, bus)
    grounded = Set(string.(get(bus, "perfectly_grounded_terminals", String[])))
    if neutral !== nothing && !(neutral in grounded)
        (("vpn_min", "vpn_max"),)                       # rows are phase-to-neutral
    else
        (("vpn_min", "vpn_max"), ("v_min", "v_max"))   # neutral at earth: both coincide
    end
end

# Limit entry k of a scalar, vector or absent limit field (nothing if absent).
function _kr_limit(bus, field, k)
    v = get(bus, field, nothing)
    v === nothing && return nothing
    v isa AbstractVector || return Float64(v)
    k ≤ length(v) && v[k] !== nothing ? Float64(v[k]) : nothing
end

# Ensure `bus[field]` is a mutable Float64 vector of length n (scalars expand).
function _kr_limit_vector!(bus, field, n, default)
    v = get(bus, field, nothing)
    vec = v === nothing ? fill(Float64(default), n) :
          v isa AbstractVector ? [x === nothing ? Float64(default) : Float64(x) for x in v] :
          fill(Float64(v), n)
    length(vec) < n && append!(vec, fill(Float64(default), n - length(vec)))
    bus[field] = vec
    vec
end

function _kr_linecode_has_limit(net, line)
    lc = get(get(net, "linecode", Dict()), string(get(line, "linecode", "")), nothing)
    lc isa AbstractDict && (haskey(lc, "i_max") || haskey(lc, "s_max"))
end

# ════════════════════════════════════════════════════════════════════════════
# Mapping a reduced solution back onto the eliminated buses
# ════════════════════════════════════════════════════════════════════════════

"""
    lift_solution(net, reduced, result; model=nothing, method=:linear|:region,
                  tol=1e-10, max_iter=100) -> Dict

Map a solution `result` of the reduced case (from [`kron_reduce_buses`](@ref),
solved with `solve_pf`/`solve_opf`) back onto the full network `net`. Device
powers are read from `result` (loads `pd`/`qd`, generators and IBRs
`pg`/`qg`) and placed back at their original buses.

- `method=:linear` (default when the [`OptiKronModel`](@ref) is passed as
  `model`) — first-order correction with the reduction's own error
  coefficients: under the linear model `v_j = ṽ_i − c_ij(A)ᵀu` exactly, so the
  lifted magnitude is `|Ũ_i| − U0_j·c_ij(A)ᵀu` with `|Ũ_i|` the AC magnitude of
  the super-node in `result`. Only the second-order (AC) part of the
  relocation error remains. Applied to every bus, super-nodes included; it
  writes `"vpn_lifted"` (the model row magnitude: phase-to-neutral when the
  bus has an ungrounded neutral, else phase-to-earth) per phase terminal.
- `method=:region` — AC solve of the eliminated region alone with the kept
  voltages of `result` fixed (Z-bus fixed point
  `V_R = Y_RR⁻¹(I_R(V_R) − Y_RK V_K)`); writes `vr`, `vi`, `vm`. Exact when
  the boundary voltages are exact, but it inherits the relocation error of the
  kept buses, so it is not uniformly better than reading the super-node.

`"_lift"` records the method and (for `:region`) convergence.
"""
function lift_solution(net::Dict{String,Any}, reduced::Dict{String,Any},
                       result::Dict{String,Any}; model::Union{Nothing,OptiKronModel}=nothing,
                       method::Symbol=model === nothing ? :region : :linear,
                       tol::Real=1e-10, max_iter::Int=100, config=_DEFAULT_CONFIG)
    log = get(reduced, "_kron_reduction", nothing)
    log === nothing && throw(ArgumentError("`reduced` has no _kron_reduction log"))
    superof = Dict{String,String}(string(k) => string(v) for (k, v) in log["super_node_of"])
    if method === :linear
        model === nothing && throw(ArgumentError("method=:linear needs the OptiKronModel (model=)"))
        return _lift_linear(net, model, superof, result)
    end
    method === :region || throw(ArgumentError("method must be :linear or :region"))
    elim = Set(keys(superof))
    out = deepcopy(result)
    isempty(elim) && (out["_lift"] = Dict("method" => "region", "converged" => true,
                                          "iterations" => 0); return out)

    # passive elements touching the eliminated buses (same split as the reduction)
    sub = Dict{String,Any}("bus" => Dict{String,Any}(),
                           "linecode" => deepcopy(get(net, "linecode", Dict{String,Any}())))
    haskey(net, "terminal_conventions") &&
        (sub["terminal_conventions"] = deepcopy(net["terminal_conventions"]))
    touched = Set{String}()
    for k in _KR_PASSIVE, (id, e) in get(net, k, Dict())
        r = _ok_bus_refs(e)
        (r === nothing || !any(in(elim), r)) && continue
        get!(sub, k, Dict{String,Any}())[id] = deepcopy(e)
        union!(touched, r)
    end
    for b in touched
        sub["bus"][b] = deepcopy(net["bus"][b])
    end
    y = ybus_passive(sub; config=config)
    n = size(y.Y, 1)
    iskept = falses(n)
    for (bt, r) in y.index
        r == 0 && continue
        bt[1] in elim || (iskept[r] = true)
    end
    K = findall(iskept)
    R = [r for r in 1:n if !iskept[r] && nnz(y.Y[:, r]) > 0]
    pos = Dict(r => k for (k, r) in enumerate(R))
    V = zeros(ComplexF64, n)
    rbus = result["bus"]
    for (bt, r) in y.index
        r == 0 && continue
        b, t = bt
        if iskept[r]
            d = get(get(rbus, b, Dict()), t, nothing)
            d === nothing && throw(ArgumentError("result lacks voltage of kept terminal ($b, $t)"))
            V[r] = complex(d["vr"], d["vi"])
        else                                   # start from the super-node voltage
            d = get(get(rbus, superof[b], Dict()), t, nothing)
            d !== nothing && (V[r] = complex(d["vr"], d["vi"]))
        end
    end
    node(b, t) = get(y.index, (b, t), 0)

    # device injections at eliminated buses: (pos node, neg node, S_injected)
    nlabels = _neutral_labels(net)
    inj = Tuple{Int,Int,ComplexF64}[]
    for (tbl, pk, qk, sgn) in (("load", "pd", "qd", -1.0), ("generator", "pg", "qg", 1.0),
                               ("ibr", "pg", "qg", 1.0))
        for (id, e) in get(net, tbl, Dict())
            b = string(get(e, "bus", ""))
            b in elim || continue
            res = get(get(result, tbl, Dict()), id, nothing)
            res === nothing && throw(ArgumentError("result lacks $tbl/$id"))
            tm = string.(e["terminal_map"])
            conf = uppercase(string(get(e, "configuration", get(e, "connection", "WYE"))))
            keyed = [t for t in tm if haskey(res, t)]
            # return terminal by role, as the OPF engine indexes devices: the
            # next terminal for delta coils, the other terminal of a
            # two-terminal single-phase coil, else the resolved neutral (or
            # earth when the device has none)
            npos = _neutral_pos(tm, nlabels)
            for t in keyed
                S = sgn * complex(Float64(res[t][pk]), Float64(res[t][qk]))
                k = findfirst(==(t), tm)
                neg = if conf in ("DELTA", "THREE_LEG")
                    tm[mod1(k + 1, length(tm))]
                elseif conf == "SINGLE_PHASE" && length(tm) == 2
                    tm[3 - k]
                elseif npos !== nothing && npos != k
                    tm[npos]
                else
                    ""
                end
                push!(inj, (node(b, t), neg == "" ? 0 : node(b, neg), S))
            end
        end
    end

    F = lu(y.Y[R, R])
    YRK = y.Y[R, K]
    converged = false; it = 0
    for outer it in 1:max_iter
        I = zeros(ComplexF64, length(R))
        for (p, q, S) in inj
            U = V[p] - (q == 0 ? 0.0im : V[q])
            abs(U) > 0 || continue
            c = conj(S / U)                    # current into the network at p
            haskey(pos, p) && (I[pos[p]] += c)
            q != 0 && haskey(pos, q) && (I[pos[q]] -= c)
        end
        Vn = F \ (I .- YRK * V[K])
        δ = maximum(abs.(Vn .- V[R]); init=0.0) / max(maximum(abs.(V[K]); init=1.0), 1.0)
        V[R] .= Vn
        if δ ≤ tol
            converged = true; break
        end
    end
    for (bt, r) in y.index
        b, t = bt
        b in elim || continue
        bd = get!(out["bus"], b, Dict{String,Any}())
        v = r == 0 ? 0.0im : V[r]
        bd[t] = Dict{String,Any}("vr" => real(v), "vi" => imag(v), "vm" => abs(v))
    end
    out["_lift"] = Dict{String,Any}("method" => "region", "converged" => converged,
                                    "iterations" => it, "n_buses_lifted" => length(elim))
    out
end

# Device powers of `result` at their ORIGINAL buses as an injection vector u
# in the model's coordinates (units of model.sbase, generation positive).
function _lift_injections(net, m::OptiKronModel, result)
    nr = length(m.rows)
    u = zeros(2nr)
    for (tbl, pk, qk, sgn) in (("load", "pd", "qd", -1.0), ("generator", "pg", "qg", 1.0),
                               ("ibr", "pg", "qg", 1.0))
        for (id, e) in get(net, tbl, Dict())
            bi = get(m.busof, string(get(e, "bus", "")), 0)
            bi == 0 && continue
            res = get(get(result, tbl, Dict()), id, nothing)
            res === nothing && throw(ArgumentError("result lacks $tbl/$id"))
            tm = string.(e["terminal_map"])
            keyed = [t for t in tm if haskey(res, t)]
            # the same placement as the training samples (`_ok_power_targets`):
            # the k-th reported entry lands where the k-th power entry does
            tg = _ok_power_targets(net, e)
            for (k, t) in enumerate(keyed)
                P = sgn * Float64(res[t][pk]) / m.sbase; Q = sgn * Float64(res[t][qk]) / m.sbase
                targets = length(keyed) == length(tg) ? tg[k] : [(t, 1.0)]
                for (tt, w) in targets
                    r = get(m.rowof, (bi, tt), 0)
                    r == 0 && continue
                    u[r] += w * P; u[r+nr] += w * Q
                end
            end
        end
    end
    u
end

function _lift_linear(net, m::OptiKronModel, superof, result)
    sup = collect(1:length(m.buses))
    for (jb, ib) in superof
        sup[m.busof[jb]] = m.busof[ib]
    end
    u = _lift_injections(net, m, result)
    idx = [c for c in eachindex(u) if u[c] != 0]
    e = isempty(idx) ? zeros(length(m.rows)) : _ok_coeffs(m, sup, idx) * u[idx]
    out = deepcopy(result)
    rbus = result["bus"]
    for (r, (j, t)) in enumerate(m.rows)
        jb = m.buses[j]; ib = m.buses[sup[j]]
        rb = get(rbus, ib, nothing)
        (rb === nothing || !haskey(rb, t)) && continue
        _, neutral = _ok_phase_terminals(net, net["bus"][ib])
        Ui = complex(rb[t]["vr"], rb[t]["vi"])
        if neutral !== nothing && haskey(rb, neutral)
            Ui -= complex(rb[neutral]["vr"], rb[neutral]["vi"])
        end
        ri = m.rowof[(sup[j], t)]
        vpu = abs(Ui) / m.u0[ri] - e[r]
        bd = get!(out["bus"], jb, Dict{String,Any}())
        get!(bd, t, Dict{String,Any}())["vpn_lifted"] = vpu * m.u0[r]
    end
    out["_lift"] = Dict{String,Any}("method" => "linear", "n_buses_lifted" => length(superof))
    out
end
