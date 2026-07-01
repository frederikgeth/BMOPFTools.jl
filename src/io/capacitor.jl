# io/capacitor.jl
#
# Fixed (nameplate-rated) shunt capacitor banks.
#
# A capacitor is a constant susceptance B = q_rated / v_nom² (per phase for
# WYE, per pair for DELTA, single for SINGLE_PHASE) that delivers the
# voltage-dependent reactive power Q = B·V². It is electrically a
# connection-aware shunt, so the OPF compiles it to a terminal-space susceptance
# matrix and reuses the standard shunt current injection. No decision variables
# (fixed); controllable/smooth capacitors are a future extension.
#
# Data shape (subtype-less top-level `capacitor`):
#   bus, terminal_map, configuration ∈ {WYE, SINGLE_PHASE, DELTA},
#   q_rated :: Vector  (var; per phase for WYE, per pair for DELTA, length 1 for
#                       SINGLE_PHASE), v_nom :: Number (V).
#
# `v_nom` is phase-to-neutral for WYE/SINGLE_PHASE and line-to-line for DELTA.

"""
    _cap_susceptances(cap) -> Vector{Float64}

Per-unit-of-configuration susceptances `B = q_rated ./ v_nom²` (S), in whatever
units the dict currently holds (SI, or per-unit after `_pu_scale_capacitors!`).
"""
function _cap_susceptances(cap::Dict{String,Any})::Vector{Float64}
    q = Float64.(get(cap, "q_rated", Float64[]))
    v = Float64(get(cap, "v_nom", 1.0))
    iszero(v) && return zeros(length(q))
    q ./ v^2
end

"""
    _cap_bmatrix(cap) -> (terminals, B)

Assemble the terminal-space susceptance matrix `B` (S, imaginary admittance) for
a capacitor, in the order of its `terminal_map`. Each elementary capacitor across
terminals `(p, q)` adds the reciprocal 2-node stamp `b·[[1,-1],[-1,1]]`:

- **WYE** — one stamp per phase, between that phase and the neutral;
- **SINGLE_PHASE** — one stamp between the two terminals;
- **DELTA** — one stamp per phase pair `(k, k%n+1)`.

The result is symmetric and feeds the existing shunt current injector (with
`G = nothing`).
"""
function _cap_bmatrix(cap::Dict{String,Any})
    tm  = Vector{String}(string.(get(cap, "terminal_map", String[])))
    cfg = uppercase(string(get(cap, "configuration", "")))
    n   = length(tm)
    B   = zeros(Float64, n, n)
    susc = _cap_susceptances(cap)
    isempty(tm) && return (tm, B)

    stamp!(i, j, b) = begin
        B[i, i] += b; B[j, j] += b; B[i, j] -= b; B[j, i] -= b
    end

    if cfg == "DELTA"
        # Across each phase pair (cyclic). q_rated[k] ↔ pair (k, k%n+1).
        for k in 1:n
            b = k <= length(susc) ? susc[k] : 0.0
            stamp!(k, (k % n) + 1, b)
        end
    elseif cfg == "SINGLE_PHASE"
        n >= 2 && stamp!(1, 2, isempty(susc) ? 0.0 : susc[1])
    else  # WYE (default)
        np  = _neutral_pos(tm)
        phs = _phase_positions(tm)
        np === nothing && return (tm, B)   # no neutral → nothing to stamp
        for (k, p) in enumerate(phs)
            b = k <= length(susc) ? susc[k] : 0.0
            stamp!(p, np, b)
        end
    end
    (tm, B)
end
