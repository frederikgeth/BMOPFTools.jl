# io/ybus.jl
#
# System nodal admittance matrix (Ybus) assembly.
#
# Assembles the per-element primitive admittance blocks (lines, shunts,
# capacitors, transformers) into a single system matrix `Y` such that
# `I = Y · V`, where `V` is the vector of node-to-EARTH voltages and `I` the
# vector of currents injected INTO the network at each node. SI units (siemens),
# full multiphase, **un-reduced**: floating neutrals keep their own rows; nothing
# is Kron-reduced to the phase domain.
#
# Convention matches the per-transformer `transformer_yprim` export and OpenDSS
# `DumpYprim` / `getYsparse`: earth is the reference (not a matrix row), current
# positive into the element, `Y = Yᵀ` for a reciprocal network (NOT Hermitian —
# the network is lossy, so `Y ≠ Yᴴ`; symmetry checks and constructions use
# `transpose`, never the adjoint `'`).
#
# Nodes.  A node is a `(bus_id, terminal_name)` pair. There are no integer node
# numbers in the data model, so `_ybus_nodes` assigns a deterministic integer
# ordering. Two classes of terminal do NOT get their own row:
#   • grounded terminals (bus `perfectly_grounded_terminals` and source-bus
#     neutrals) collapse onto the earth reference — their admittance
#     contributions become diagonal self-terms;
#   • terminals joined by a zero-impedance UNITY coupling (a closed switch, a
#     line whose series impedance is below `z_line_min_ohm`, or a 1:1
#     zero-leakage transformer) are fused into a single node by union-find.
# This mirrors what the OPF and `simplify_network` already do — neither invents a
# small penalty impedance for a short; they impose `V_from == V_to` / merge the
# nodes. Assembling a large finite `1/z` admittance instead would disagree with
# that model and inject a conditioning error, so we alias instead.
#
# This module is intentionally free of any JuMP dependency (it lives in the core
# package, not the OPF extension): it reads the same network Dict and reuses the
# core impedance/susceptance helpers (`_pattern_keys_to_matrix`, `_cap_bmatrix`,
# `transformer_yprim`).

using SparseArrays

# ── negligible-impedance thresholds (sourced from config, never hard-coded) ──

# ‖Z_series‖_F (Ω) below which a line is treated as a unity zero-impedance
# coupling (aliased) rather than stamped — the same `z_line_min_ohm` the
# `W.DOM.LINE_LOW_IMPEDANCE` check uses.
_ybus_line_z_min(thresh) = Float64(get(thresh, "z_line_min_ohm", 1e-4))
# Leakage |X| (Ω, referred) at/below which a transformer is treated as exactly
# ideal — the same `xfmr_z_min_ohm` as `I.DOM.XFMR_IDEAL`.
_ybus_xfmr_z_min(thresh) = Float64(get(thresh, "xfmr_z_min_ohm", 1e-6))

# ── union-find over terminals (node aliasing) ────────────────────────────────

const _Node = Tuple{String,String}

mutable struct _UF
    parent::Dict{_Node,_Node}
end
_UF() = _UF(Dict{_Node,_Node}())

function _uf_find(uf::_UF, x::_Node)
    haskey(uf.parent, x) || (uf.parent[x] = x)
    root = x
    while uf.parent[root] != root
        root = uf.parent[root]
    end
    # path compression
    while uf.parent[x] != root
        uf.parent[x], x = root, uf.parent[x]
    end
    root
end

function _uf_union!(uf::_UF, a::_Node, b::_Node)
    ra, rb = _uf_find(uf, a), _uf_find(uf, b)
    ra == rb && return
    # Deterministic representative: smaller (bus, terminal) wins, so the choice
    # of node label is independent of insertion order.
    ra < rb ? (uf.parent[rb] = ra) : (uf.parent[ra] = rb)
end

# Earth-reference terminals for the passive Ybus: ONLY the terminals a bus
# declares `perfectly_grounded_terminals`. These are exact `V = 0` ties to earth
# and collapse onto the reference (they get no matrix row).
#
# Unlike the OPF extension's `_grounded_terminals`, this deliberately does NOT
# auto-ground voltage-source-bus neutrals: whether such a neutral is earthed
# depends on the actual grounding element (a grounding reactor is imported as a
# finite shunt, not a perfect ground), and the "explicit neutral" convention
# keeps every non-perfectly-grounded neutral as its own node. A voltage source
# is a boundary injection, not part of the passive admittance, so it neither
# grounds a node nor stamps into `Y`.
function _ybus_grounded_terminals(net::Dict{String,Any})
    grounded = Set{_Node}()
    for (bid, bus) in get(net, "bus", Dict())
        for t in get(bus, "perfectly_grounded_terminals", String[])
            push!(grounded, (bid, string(t)))
        end
    end
    grounded
end

# ── node index ───────────────────────────────────────────────────────────────

"""
    _YbusIndex

Deterministic integer ordering over the network's electrical nodes.

Fields:
- `nodes`  — `Vector{_Node}`, one canonical `(bus, terminal)` per system node,
             in row/column order of `Y`.
- `of`     — `Dict{_Node,Int}` mapping EVERY `(bus, terminal)` (including aliased
             and grounded ones) to its system node index, or `0` for the earth
             reference. Aliased terminals share one index.
"""
struct _YbusIndex
    nodes::Vector{_Node}
    of::Dict{_Node,Int}
end

# Series impedance (Ω) matrix of a line as complex, in core (no OPF-ext dep).
# Returns (Z::Matrix{ComplexF64}, n) or (nothing, 0).
function _line_z_complex(line::Dict{String,Any}, linecodes::AbstractDict)
    if _line_has_inline_z(line)
        R = _pattern_keys_to_matrix(line, "R_series_")
        X = _pattern_keys_to_matrix(line, "X_series_")
        R === nothing && X === nothing && return (nothing, 0)
        R === nothing && (R = zeros(size(X)...))
        X === nothing && (X = zeros(size(R)...))
        return (complex.(R, X), size(R, 1))
    end
    lcid = get(line, "linecode", nothing)
    lcid === nothing && return (nothing, 0)
    lc = get(linecodes, lcid, nothing)
    lc === nothing && return (nothing, 0)
    R = _pattern_keys_to_matrix(lc, "R_series_")
    X = _pattern_keys_to_matrix(lc, "X_series_")
    R === nothing && X === nothing && return (nothing, 0)
    R === nothing && (R = zeros(size(X)...))
    X === nothing && (X = zeros(size(R)...))
    len = Float64(get(line, "length", 1.0))
    (complex.(R .* len, X .* len), size(R, 1))
end

# π-shunt admittance (S) of a line, from- and to-side, as complex or nothing.
function _line_shunt_complex(line::Dict{String,Any}, linecodes::AbstractDict)
    _cx(G, B) = (G === nothing && B === nothing) ? nothing :
        complex.(G === nothing ? zeros(size(B)...) : G,
                 B === nothing ? zeros(size(G)...) : B)
    if _line_has_inline_z(line)
        Yfr = _cx(_pattern_keys_to_matrix(line, "G_from_"), _pattern_keys_to_matrix(line, "B_from_"))
        Yto = _cx(_pattern_keys_to_matrix(line, "G_to_"),   _pattern_keys_to_matrix(line, "B_to_"))
        return (Yfr, Yto)
    end
    lcid = get(line, "linecode", nothing)
    lcid === nothing && return (nothing, nothing)
    lc = get(linecodes, lcid, nothing)
    lc === nothing && return (nothing, nothing)
    len = Float64(get(line, "length", 1.0))
    scale(M) = M === nothing ? nothing : M .* len
    Yfr = _cx(scale(_pattern_keys_to_matrix(lc, "G_from_")), scale(_pattern_keys_to_matrix(lc, "B_from_")))
    Yto = _cx(scale(_pattern_keys_to_matrix(lc, "G_to_")),   scale(_pattern_keys_to_matrix(lc, "B_to_")))
    (Yfr, Yto)
end

# Is this line a unity zero-impedance coupling (should be aliased, not stamped)?
function _line_is_negligible(Z, thresh)
    Z === nothing && return false
    norm(Z) < _ybus_line_z_min(thresh)
end

"""
    _ybus_nodes(net; config=_DEFAULT_CONFIG) -> _YbusIndex

Assign the deterministic integer node ordering for `net`'s Ybus. Grounded
terminals map to the earth reference (index `0`); closed switches, negligible-Z
lines, and unity-ratio zero-leakage transformers alias their terminal pairs onto
a shared node.
"""
function _ybus_nodes(net::Dict{String,Any}; config=_DEFAULT_CONFIG)
    thresh = _domain_thresholds(config)
    linecodes = get(net, "linecode", Dict())

    # 1. every declared (bus, terminal)
    all_nodes = _Node[]
    for (bid, bus) in get(net, "bus", Dict())
        for t in get(bus, "terminal_names", String[])
            push!(all_nodes, (bid, string(t)))
        end
    end

    uf = _UF()
    for n in all_nodes
        _uf_find(uf, n)   # register
    end

    # 2. alias closed switches
    for (_, sw) in get(net, "switch", Dict())
        get(sw, "status", "closed") == "open" && continue
        bfr = get(sw, "bus_from", ""); bto = get(sw, "bus_to", "")
        tmf = string.(get(sw, "terminal_map_from", String[]))
        tmt = string.(get(sw, "terminal_map_to", String[]))
        for k in 1:min(length(tmf), length(tmt))
            _uf_union!(uf, (bfr, tmf[k]), (bto, tmt[k]))
        end
    end

    # 3. alias negligible-impedance lines (unity coupling)
    for (_, ln) in get(net, "line", Dict())
        Z, _ = _line_z_complex(ln, linecodes)
        _line_is_negligible(Z, thresh) || continue
        bfr = get(ln, "bus_from", ""); bto = get(ln, "bus_to", "")
        tmf = string.(get(ln, "terminal_map_from", String[]))
        tmt = string.(get(ln, "terminal_map_to", String[]))
        for k in 1:min(length(tmf), length(tmt))
            _uf_union!(uf, (bfr, tmf[k]), (bto, tmt[k]))
        end
    end

    # 4. alias 1:1 zero-leakage transformers (see _xfmr_alias_pairs)
    for (bfr, tmf, bto, tmt) in _xfmr_alias_pairs(net, config)
        for k in 1:min(length(tmf), length(tmt))
            _uf_union!(uf, (bfr, tmf[k]), (bto, tmt[k]))
        end
    end

    # 5. collapse grounded terminals onto the earth reference
    grounded = _ybus_grounded_terminals(net)

    # 6. assign integer indices to the surviving representative nodes
    reps = Dict{_Node,Int}()   # representative -> index
    ordered = _Node[]
    of = Dict{_Node,Int}()
    # Deterministic node order: sort terminals, index by representative.
    for n in sort(all_nodes)
        r = _uf_find(uf, n)
        if r in grounded || n in grounded
            of[n] = 0
            continue
        end
        idx = get(reps, r, 0)
        if idx == 0
            push!(ordered, r)
            idx = length(ordered)
            reps[r] = idx
        end
        of[n] = idx
    end
    _YbusIndex(ordered, of)
end

# ── transformer aliasing (1:1 zero-leakage → node fusion) ────────────────────

# Yield (bus_from, terminal_map_from, bus_to, terminal_map_to) for every
# two-winding transformer that is BOTH unity-ratio and zero-leakage — an exact
# node identity that must be aliased rather than stamped (a 1:1 ideal coupling
# has Yprim = [[y,-y],[-y,y]] with y→∞, i.e. no finite admittance form).
function _xfmr_alias_pairs(net::Dict{String,Any}, config)
    thresh = _domain_thresholds(config)
    zmin = _ybus_xfmr_z_min(thresh)
    out = Tuple{String,Vector{String},String,Vector{String}}[]
    xfmrs = get(net, "transformer", Dict())
    for subtype in ("single_phase", "wye_delta", "delta_wye")
        sub = get(xfmrs, subtype, Dict())
        sub isa Dict || continue
        for (_, x) in sub
            _xfmr_is_ideal(x, zmin) || continue
            # unity ratio only: a ratio ≠ 1 is a genuine voltage transform and
            # cannot be node-aliased (handled by the regularizing stamp instead).
            isapprox(_xfmr_turns_ratio(x), 1.0; atol=1e-9) || continue
            bfr = get(x, "bus_from", ""); bto = get(x, "bus_to", "")
            tmf = string.(get(x, "terminal_map_from", String[]))
            tmt = string.(get(x, "terminal_map_to", String[]))
            push!(out, (bfr, tmf, bto, tmt))
        end
    end
    out
end

# Zero-leakage test: all series leakage terms at/below the ideal threshold.
function _xfmr_is_ideal(x::Dict{String,Any}, zmin::Float64)
    r_fr = abs(Float64(get(x, "r_series_from", 0.0)))
    x_fr = abs(Float64(get(x, "x_series_from", 0.0)))
    r_to = abs(Float64(get(x, "r_series_to", 0.0)))
    x_to = abs(Float64(get(x, "x_series_to", 0.0)))
    max(r_fr, x_fr, r_to, x_to) <= zmin
end

# ── primitive blocks ─────────────────────────────────────────────────────────

# Each primitive returns (nodes::Vector{_Node}, Y::Matrix{ComplexF64}) in the
# shared convention: I_into = Y · V_to_ground.

# Line: nominal Π model over [from terminals; to terminals].
function _line_yprim(line::Dict{String,Any}, linecodes::AbstractDict)
    Z, nz = _line_z_complex(line, linecodes)
    (Z === nothing || nz == 0) && return (_Node[], zeros(ComplexF64, 0, 0))
    bfr = get(line, "bus_from", ""); bto = get(line, "bus_to", "")
    tmf = string.(get(line, "terminal_map_from", String[]))
    tmt = string.(get(line, "terminal_map_to", String[]))
    # Conductor count = min(matrix dim, terminal-map lengths), matching the OPF
    # branch stamping (ext/BMOPFOpfExt/branch.jl): when a wider linecode meets a
    # shorter terminal map (a from_dss quirk for some 4-wire decks), only the
    # top-left n×n block is used.
    n = min(nz, length(tmf), length(tmt))
    n == 0 && return (_Node[], zeros(ComplexF64, 0, 0))
    ys = inv(Z[1:n, 1:n])                          # series admittance (S)
    Yfr, Yto = _line_shunt_complex(line, linecodes)
    trunc(M) = M === nothing ? zeros(ComplexF64, n, n) : ComplexF64.(M[1:n, 1:n])
    y_fr = trunc(Yfr); y_to = trunc(Yto)
    Y = zeros(ComplexF64, 2n, 2n)
    Y[1:n, 1:n]         .= ys .+ y_fr
    Y[n+1:2n, n+1:2n]   .= ys .+ y_to
    Y[1:n, n+1:2n]      .= .-ys
    Y[n+1:2n, 1:n]      .= .-ys
    nodes = vcat([(bfr, tmf[k]) for k in 1:n], [(bto, tmt[k]) for k in 1:n])
    (nodes, Y)
end

# Shunt: admittance matrix Y = G + jB over the single bus's terminals.
function _shunt_yprim(shunt::Dict{String,Any})
    G = _pattern_keys_to_matrix(shunt, "G_")
    B = _pattern_keys_to_matrix(shunt, "B_")
    G === nothing && B === nothing && return (_Node[], zeros(ComplexF64, 0, 0))
    G === nothing && (G = zeros(size(B)...))
    B === nothing && (B = zeros(size(G)...))
    Y = ComplexF64.(G, B)
    bus = get(shunt, "bus", "")
    tm  = string.(get(shunt, "terminal_map", String[]))
    ([(bus, t) for t in tm], Y)
end

# Capacitor: pure susceptance block jB from _cap_bmatrix.
function _capacitor_yprim(cap::Dict{String,Any})
    tm, B = _cap_bmatrix(cap)
    isempty(tm) && return (_Node[], zeros(ComplexF64, 0, 0))
    bus = get(cap, "bus", "")
    ([(bus, string(t)) for t in tm], ComplexF64.(0.0, B))
end

# ── assembly ─────────────────────────────────────────────────────────────────

"""
    YbusResult

System nodal admittance matrix and its node ordering.

Fields:
- `Y`     — `SparseMatrixCSC{ComplexF64,Int}`, SI siemens, `I = Y·V` with `V`
            node-to-earth. Symmetric for a reciprocal network (`Y ≈ transpose(Y)`).
- `nodes` — `Vector{Tuple{String,String}}` of `(bus_id, terminal_name)`, in
            row/column order of `Y`.
- `index` — `Dict{Tuple{String,String},Int}` from any `(bus, terminal)` to its
            row (`0` = earth reference; aliased terminals share a row).
"""
struct YbusResult
    Y::SparseMatrixCSC{ComplexF64,Int}
    nodes::Vector{_Node}
    index::Dict{_Node,Int}
end

Base.show(io::IO, r::YbusResult) =
    print(io, "YbusResult($(length(r.nodes)) nodes, $(nnz(r.Y)) nonzeros)")

# Scatter a primitive block into the COO accumulators, dropping any row/column
# that resolves to the earth reference (index 0).
function _scatter!(I, J, V, blk_nodes, blk_Y, idx::_YbusIndex)
    m = length(blk_nodes)
    gi = [get(idx.of, blk_nodes[k], 0) for k in 1:m]
    for a in 1:m
        ga = gi[a]
        ga == 0 && continue                    # reference row — not kept
        for b in 1:m
            gb = gi[b]
            gb == 0 && continue                # V=0 column — contributes nothing
            y = blk_Y[a, b]
            iszero(y) && continue
            push!(I, ga); push!(J, gb); push!(V, y)
        end
    end
end

"""
    ybus_passive(net; config=_DEFAULT_CONFIG) -> YbusResult

Assemble the **passive** system nodal admittance matrix from the network's
lines, shunts, capacitors, and transformers. Loads, generators, and IBRs (the
nonlinear current-injecting elements) are NOT included — this is the linear,
voltage-invariant network. Voltage sources contribute no admittance (they are
ideal in the BMOPF model) and set the boundary, not the matrix.

SI siemens, full multiphase, referenced to earth. Closed switches, negligible-Z
lines, and 1:1 zero-leakage transformers are node-aliased (not stamped). See the
module header for the sign/symmetry convention.

A zero-leakage transformer with a non-unity ratio has no finite admittance form;
it is stamped via `transformer_yprim` as the existing (singular, shunt-only)
block with that function's warning — regularizing it to the `xfmr_z_min_pu`
floor is a documented follow-up.
"""
function ybus_passive(net::Dict{String,Any}; config=_DEFAULT_CONFIG)::YbusResult
    idx = _ybus_nodes(net; config)
    I = Int[]; J = Int[]; V = ComplexF64[]
    _stamp_passive!(I, J, V, net, idx, config)
    n = length(idx.nodes)
    YbusResult(sparse(I, J, V, n, n), idx.nodes, idx.of)
end

# Stamp every passive element (lines, shunts, capacitors, transformers) into the
# COO accumulators for node index `idx`. Shared by ybus_passive and
# ybus_linearized (which appends the load-admittance stamps on top).
function _stamp_passive!(I, J, V, net::Dict{String,Any}, idx::_YbusIndex, config)
    linecodes = get(net, "linecode", Dict())
    thresh = _domain_thresholds(config)

    # lines (skip the negligible ones — they are aliased in the index)
    for (_, ln) in get(net, "line", Dict())
        Z, _ = _line_z_complex(ln, linecodes)
        _line_is_negligible(Z, thresh) && continue
        nodes, Y = _line_yprim(ln, linecodes)
        isempty(nodes) || _scatter!(I, J, V, nodes, Y, idx)
    end

    # shunts
    for (_, sh) in get(net, "shunt", Dict())
        nodes, Y = _shunt_yprim(sh)
        isempty(nodes) || _scatter!(I, J, V, nodes, Y, idx)
    end

    # capacitors
    for (_, cp) in get(net, "capacitor", Dict())
        nodes, Y = _capacitor_yprim(cp)
        isempty(nodes) || _scatter!(I, J, V, nodes, Y, idx)
    end

    # transformers (reuse the per-element Yprim; 1:1 ideal ones already aliased)
    _scatter_transformers!(I, J, V, net, idx, config)
    return
end

# Stamp every transformer's Yprim, except the 1:1 zero-leakage ones handled by
# node aliasing in the index (those would produce a spurious singular block).
function _scatter_transformers!(I, J, V, net, idx::_YbusIndex, config)
    thresh = _domain_thresholds(config)
    zmin = _ybus_xfmr_z_min(thresh)
    xfmrs = get(net, "transformer", Dict())
    xfmrs isa Dict || return
    for (subtype, sub) in xfmrs
        sub isa Dict && !isempty(sub) || continue
        for (_, x) in sub
            # 1:1 zero-leakage two-winding transformers are aliased, not stamped.
            if subtype in ("single_phase", "wye_delta", "delta_wye") &&
               _xfmr_is_ideal(x, zmin) &&
               isapprox(_xfmr_turns_ratio(x), 1.0; atol=1e-9)
                continue
            end
            nodes, Y = if subtype == "n_winding"
                nwinding_yprim(x)
            else
                transformer_yprim(x, subtype)
            end
            isempty(nodes) || _scatter!(I, J, V, nodes, Y, idx)
        end
    end
end
