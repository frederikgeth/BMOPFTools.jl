# lineconstants/kron.jl
#
# Kron reduction — INTERNAL ONLY, deliberately not exported. BMOPF keeps the
# full primitive matrix for every circuit conductor (grounding is expressed
# on bus `perfectly_grounded_terminals`, not baked into impedance data). The
# two internal uses are:
#   • collapsing cable shield/concentric-neutral subconductors, which are
#     sub-terminal structure held at local earth potential, and
#   • unit tests reproducing published (reduced) reference matrices.

"""
    _kron_reduce(Z, keep) -> Matrix

Eliminate the rows/columns of square matrix `Z` not in `keep`, assuming zero
voltage on the eliminated conductors: Zred = Zkk − Zke·Zee⁻¹·Zek.
"""
function _kron_reduce(Z::AbstractMatrix, keep::AbstractVector{Int})
    n = size(Z, 1)
    elim = setdiff(1:n, keep)
    isempty(elim) && return Z[keep, keep]
    Z[keep, keep] - Z[keep, elim] * (Z[elim, elim] \ Z[elim, keep])
end

"""
    _kron_reduce_potential(P, keep) -> Matrix

Reduce a Maxwell potential-coefficient matrix. Identical Schur complement —
kept as its own name because capacitance must be reduced in potential form
(reduce P̂, then invert to C), never on C or B directly.
"""
_kron_reduce_potential(P::AbstractMatrix, keep::AbstractVector{Int}) =
    _kron_reduce(P, keep)
