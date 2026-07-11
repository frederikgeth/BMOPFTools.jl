# io/ybus_linearized.jl
#
# Linearized system nodal admittance matrix — the passive Ybus with the
# nonlinear load elements folded in, following the OpenDSS solution model.
#
# A ZIP/exponential load draws, on each sub-load connection (t_pos, t_neg),
# a current `I = conj(S(|Δv|)) / conj(Δv)` with `Δv = V_pos − V_neg` and the
# voltage-dependent power (matching ext/BMOPFOpfExt/load.jl exactly)
#
#   P(|Δv|) = p_nom·(αZ·|Δv|²/Vnom² + αI·|Δv|/Vnom + αP)      [ZIP]
#   P(|Δv|) = p_nom·(|Δv|/Vnom)^γP                            [exponential]
#
# (and Q with the β / γQ coefficients). This splits by contribution:
#
#   • constant-Z part (∝ |Δv|²): current `I_z = (cW_p − j·cW_q)·Δv` is a plain
#     admittance `y_z` — voltage-invariant, folded permanently into Y exactly
#     like a passive shunt across (t_pos, t_neg);
#   • constant-I / constant-P / non-integer-exponential parts: current is
#     nonlinear in V and lives in a compensation-current closure `i_comp(V)`.
#
# The linear system is then `Y_lin · V = i_comp(V)`, the fixed-point / Z-bus
# power-flow map (Wang/Bernstein/Bolognani). `fold = :all` instead folds the
# WHOLE load as its equivalent admittance `conj(S(v0))/|Δv0|²` at an operating
# point `v0` (OpenDSS's converged-solution Y, and the load-as-admittance seed
# for state estimation); then `i_comp ≡ 0`.
#
# Generators and IBRs are NOT folded here (their injections are OPF variables /
# come from measurements, not a fixed model); adding them as `i_comp` injections
# is a documented follow-up.

# ── core ports of the OPF load-model helpers (ext/BMOPFOpfExt/load.jl) ────────
# Kept byte-for-byte equivalent so the folded admittance and the OPF stamp agree.

function _ybl_vnom_k(load, k::Int)
    v = get(load, "v_nom", nothing)
    v === nothing && error("Load model requires v_nom but none is present.")
    vv = v isa AbstractVector ? Float64.(v) : [Float64(v)]
    vnom = length(vv) == 1 ? vv[1] : vv[k]
    vnom > 0.0 || error("Load model requires a strictly positive v_nom (got $vnom).")
    vnom
end

function _ybl_coeff_k(load, key::String, k::Int)
    c = get(load, key, nothing)
    c === nothing && return 0.0
    c isa AbstractVector ? Float64(length(c) == 1 ? c[1] : c[k]) : Float64(c)
end

function _ybl_zip_coeffs(load, zkey, ikey, pkey, k::Int)
    if get(load, zkey, nothing) === nothing && get(load, ikey, nothing) === nothing &&
       get(load, pkey, nothing) === nothing
        return (0.0, 0.0, 1.0)
    end
    (_ybl_coeff_k(load, zkey, k), _ybl_coeff_k(load, ikey, k), _ybl_coeff_k(load, pkey, k))
end

# Component right-hand-side split for one family (P or Q) at sub-load k:
# (cc = constant-power term, cW = |Δv|² coefficient, cs = |Δv| coefficient,
#  nl = (base, γ) for a genuinely non-integer exponential exponent, else nothing).
function _ybl_component(load, zkeys, gkey, base::Float64, Vnom::Float64, k::Int)
    model = get(load, "model", "constant_power")
    if model == "constant_power"
        return (cc = base, cW = 0.0, cs = 0.0, nl = nothing)
    elseif model == "constant_impedance"
        return (cc = 0.0, cW = base / Vnom^2, cs = 0.0, nl = nothing)
    elseif model == "constant_current"
        return (cc = 0.0, cW = 0.0, cs = base / Vnom, nl = nothing)
    elseif model == "zip"
        (cz, ci, cp) = _ybl_zip_coeffs(load, zkeys[1], zkeys[2], zkeys[3], k)
        return (cc = base * cp, cW = base * cz / Vnom^2, cs = base * ci / Vnom, nl = nothing)
    else  # exponential
        γ = _ybl_coeff_k(load, gkey, k)
        γ == 0.0 && return (cc = base, cW = 0.0, cs = 0.0, nl = nothing)
        γ == 2.0 && return (cc = 0.0, cW = base / Vnom^2, cs = 0.0, nl = nothing)
        γ == 1.0 && return (cc = 0.0, cW = 0.0, cs = base / Vnom, nl = nothing)
        return (cc = 0.0, cW = 0.0, cs = 0.0, nl = (base, γ))
    end
end

# ── sub-load geometry (mirrors _add_load_constraints! in load.jl) ─────────────

# One connection of a load: power p0+jq0 drawn across (pos → neg), with neg =
# `nothing` for a phase-to-ground connection. `k` indexes into the coefficient
# arrays; `pt`/`qt` are the P/Q component splits; `Vnom` the sub-load nominal.
struct _SubLoad
    pos::_Node
    neg::Union{_Node,Nothing}
    p0::Float64
    q0::Float64
    pt::NamedTuple
    qt::NamedTuple
    Vnom::Float64
end

# Enumerate a load's sub-load connections. Constant-power loads carry no v_nom;
# use a sentinel Vnom=1.0 (their pt/qt only use cc, so Vnom is never divided by).
function _load_subloads(load::Dict{String,Any}, net::Dict{String,Any})
    bus = get(load, "bus", "")
    tm  = Vector{String}(string.(get(load, "terminal_map", String[])))
    cfg = uppercase(string(get(load, "configuration", "WYE")))
    p_nom = Float64.(get(load, "p_nom", Float64[]))
    q_nom = Float64.(get(load, "q_nom", Float64[]))
    nlabels = _neutral_labels(net)
    model = get(load, "model", "constant_power")
    subs = _SubLoad[]

    mk(pos, neg, k) = begin
        (k <= length(p_nom)) || return nothing
        p0 = p_nom[k]; q0 = k <= length(q_nom) ? q_nom[k] : 0.0
        Vnom = model == "constant_power" ? 1.0 : _ybl_vnom_k(load, k)
        pt = _ybl_component(load, ("alpha_z","alpha_i","alpha_p"), "gamma_p", p0, Vnom, k)
        qt = _ybl_component(load, ("beta_z","beta_i","beta_p"),    "gamma_q", q0, Vnom, k)
        _SubLoad(pos, neg, p0, q0, pt, qt, Vnom)
    end
    push_maybe!(x) = x === nothing ? nothing : push!(subs, x)

    if cfg == "SINGLE_PHASE" && length(tm) == 2
        push_maybe!(mk((bus, tm[1]), (bus, tm[2]), 1))
    elseif cfg in ("WYE", "SINGLE_PHASE")
        ph = _phase_positions(tm, nlabels)
        np = _neutral_pos(tm, nlabels)
        t_n = np !== nothing ? (bus, tm[np]) : nothing
        for (idx, p) in enumerate(ph)
            push_maybe!(mk((bus, tm[p]), t_n, idx))
        end
    elseif cfg == "DELTA"
        n_c = length(tm)
        for k in 1:n_c
            push_maybe!(mk((bus, tm[k]), (bus, tm[(k % n_c) + 1]), k))
        end
    else
        @warn "ybus_linearized: load has unknown configuration '$cfg' — skipping."
    end
    subs
end

# Constant-Z equivalent admittance of a sub-load: y_z = cW_p − j·cW_q, where
# cW_· are the |Δv|² coefficients of P and Q. (I_z = conj(S_z)/conj(Δv) with
# S_z = (cW_p + j·cW_q)|Δv|² gives exactly y_z·Δv.)
_subload_yz(sl::_SubLoad) = sl.pt.cW - im * sl.qt.cW

# Full complex power drawn at |Δv| (all ZIP/exp parts). Used by :all folding.
function _subload_S(sl::_SubLoad, absdv::Float64)
    term(t) = t.nl === nothing ?
        (t.cc + t.cW * absdv^2 + t.cs * absdv) :
        (t.nl[1] * (absdv / sl.Vnom)^t.nl[2])
    term(sl.pt) + im * term(sl.qt)
end

# Non-constant-Z complex power (constant-I + constant-P + non-integer-exp) at
# |Δv|. Used by the compensation-current closure.
function _subload_S_nz(sl::_SubLoad, absdv::Float64)
    term(t) = t.nl === nothing ?
        (t.cc + t.cs * absdv) :
        (t.nl[1] * (absdv / sl.Vnom)^t.nl[2])
    term(sl.pt) + im * term(sl.qt)
end

# ── the linearized-Ybus result ───────────────────────────────────────────────

"""
    LinearizedYbus

The passive Ybus with loads folded in (see the module header for the model).

Fields:
- `Y`      — `SparseMatrixCSC{ComplexF64,Int}`, passive + folded load admittances.
- `nodes`  — `Vector{Tuple{String,String}}`, row/column order of `Y`.
- `index`  — `Dict{Tuple{String,String},Int}` from `(bus, terminal)` to row
             (`0` = earth reference; aliased terminals share a row).
- `i_comp` — `V -> i` : maps a node-ordered voltage vector to the compensation
             current vector (the constant-I / constant-P load injection). For
             `fold = :all` this is the zero function.
- `i0`     — `i_comp(v0)` if an operating point `v0` was supplied, else `nothing`.
- `fold`   — `:constant_z` or `:all`.

Solving `Y·V = i_comp(V)` by fixed-point iteration is the Z-bus power flow; the
first iterate (flat or `v0`) is the standard linear power-flow approximation.
"""
struct LinearizedYbus
    Y::SparseMatrixCSC{ComplexF64,Int}
    nodes::Vector{_Node}
    index::Dict{_Node,Int}
    i_comp::Function
    i0::Union{Vector{ComplexF64},Nothing}
    fold::Symbol
end

Base.show(io::IO, r::LinearizedYbus) =
    print(io, "LinearizedYbus($(length(r.nodes)) nodes, $(nnz(r.Y)) nonzeros, fold=$(r.fold))")

# Add a 2-node admittance stamp y across (posidx, negidx) into the COO arrays,
# dropping any endpoint that is the earth reference (index 0).
function _stamp_pair!(I, J, V, pi::Int, ni::Int, y::ComplexF64)
    iszero(y) && return
    pi != 0 && (push!(I, pi); push!(J, pi); push!(V, y))
    ni != 0 && (push!(I, ni); push!(J, ni); push!(V, y))
    if pi != 0 && ni != 0
        push!(I, pi); push!(J, ni); push!(V, -y)
        push!(I, ni); push!(J, pi); push!(V, -y)
    end
    return
end

"""
    ybus_linearized(net; config=_DEFAULT_CONFIG, fold=:constant_z, v0=nothing)
        -> LinearizedYbus

Assemble the passive Ybus with the load elements folded in.

- `fold = :constant_z` (default) — fold only the voltage-invariant constant-Z
  part of each load into `Y`; the constant-I / constant-P parts are returned as
  the `i_comp(V)` closure (the OpenDSS SolutionMode split).
- `fold = :all` — fold the WHOLE load as its equivalent admittance at the
  operating point `v0` (required); `i_comp ≡ 0`. This is OpenDSS's converged
  system Y and the load-as-admittance seed for state estimation.

`v0`, if given, is a `Dict{Tuple{String,String},<:Number}` of node-to-earth
complex voltages (e.g. from `solve_pf`, a solved OPF, or OpenDSS); it sets the
folding point for `:all` and yields `i0 = i_comp(v0)`.
"""
function ybus_linearized(net::Dict{String,Any}; config=_DEFAULT_CONFIG,
                         fold::Symbol=:constant_z, v0=nothing)::LinearizedYbus
    fold in (:constant_z, :all) ||
        throw(ArgumentError("fold must be :constant_z or :all, got $(repr(fold))"))
    idx = _ybus_nodes(net; config)
    n = length(idx.nodes)

    # v0 as a node-ordered vector (for :all folding and/or i0). Missing nodes → 0.
    v0vec = nothing
    if v0 !== nothing
        v0vec = zeros(ComplexF64, n)
        for (nd, i) in idx.of
            i == 0 && continue
            haskey(v0, nd) && (v0vec[i] = ComplexF64(v0[nd]))
        end
    end
    if fold == :all && v0vec === nothing
        throw(ArgumentError("fold = :all requires an operating point v0"))
    end

    I = Int[]; J = Int[]; V = ComplexF64[]
    _stamp_passive!(I, J, V, net, idx, config)

    # collect sub-loads once (reused by the stamp and the closure)
    allsubs = _SubLoad[]
    for (_, load) in get(net, "load", Dict())
        append!(allsubs, _load_subloads(load, net))
    end

    _dvidx(sl) = (get(idx.of, sl.pos, 0), sl.neg === nothing ? 0 : get(idx.of, sl.neg, 0))
    _dv(sl, Vv) = begin
        pi, ni = _dvidx(sl)
        vp = pi == 0 ? 0.0im : Vv[pi]
        vn = ni == 0 ? 0.0im : Vv[ni]
        vp - vn, pi, ni
    end

    # fold load admittances into Y
    for sl in allsubs
        pi, ni = _dvidx(sl)
        if fold == :all
            dv = (pi == 0 ? 0.0im : v0vec[pi]) - (ni == 0 ? 0.0im : v0vec[ni])
            a = abs(dv)
            y = a > 0 ? conj(_subload_S(sl, a)) / a^2 : _subload_yz(sl)
            _stamp_pair!(I, J, V, pi, ni, y)
        else
            _stamp_pair!(I, J, V, pi, ni, _subload_yz(sl))
        end
    end

    Y = sparse(I, J, V, n, n)

    # compensation-current closure: injection = −(non-constant-Z load current).
    subs = allsubs      # capture
    icomp = if fold == :all
        (_::AbstractVector) -> zeros(ComplexF64, n)
    else
        function (Vv::AbstractVector)
            length(Vv) == n || throw(DimensionMismatch(
                "i_comp expects a length-$n voltage vector (got $(length(Vv)))"))
            ic = zeros(ComplexF64, n)
            for sl in subs
                dv, pi, ni = _dv(sl, Vv)
                a = abs(dv)
                a > 0 || continue
                Iload = conj(_subload_S_nz(sl, a)) / conj(dv)   # drawn into load
                pi != 0 && (ic[pi] -= Iload)                    # injection = −draw
                ni != 0 && (ic[ni] += Iload)
            end
            ic
        end
    end

    i0 = v0vec === nothing ? nothing : icomp(v0vec)
    LinearizedYbus(Y, idx.nodes, idx.of, icomp, i0, fold)
end
