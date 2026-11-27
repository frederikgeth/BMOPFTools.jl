# analysis/disjoint_sets.jl
#
# The one union-find the profiler uses to group buses, terminals, conductors
# and DC nodes. A node joins the structure the first time it is looked up.
#
# `_ds_union!(ds, a, b)` links the root of `a` under the root of `b`. Callers
# that report a representative (rather than only comparing roots or listing
# groups) rely on that direction, so it is part of the contract.

struct _DisjointSets{T}
    parent::Dict{T,T}
end
_DisjointSets{T}() where {T} = _DisjointSets{T}(Dict{T,T}())
_DisjointSets(nodes) = (ds = _DisjointSets{eltype(nodes)}(); foreach(n -> _ds_find!(ds, n), nodes); ds)

# Representative of `x`'s set, with path compression. Adds `x` as a singleton
# when it has not been seen.
function _ds_find!(ds::_DisjointSets, x)
    parent = ds.parent
    haskey(parent, x) || (parent[x] = x)
    root = x
    while parent[root] != root
        root = parent[root]
    end
    while parent[x] != root
        parent[x], x = root, parent[x]
    end
    root
end

# Join the sets of `a` and `b`, the root of `a` going under the root of `b`.
# Returns `false` when they were already one set (the edge closes a cycle).
function _ds_union!(ds::_DisjointSets, a, b)::Bool
    ra = _ds_find!(ds, a); rb = _ds_find!(ds, b)
    ra == rb && return false
    ds.parent[ra] = rb
    true
end

_ds_same(ds::_DisjointSets, a, b)::Bool = _ds_find!(ds, a) == _ds_find!(ds, b)

# Every node seen so far, in the order the underlying Dict iterates them.
_ds_nodes(ds::_DisjointSets) = keys(ds.parent)

# Members of each set, keyed by representative.
function _ds_groups(ds::_DisjointSets{T}) where {T}
    groups = Dict{T,Vector{T}}()
    for n in collect(keys(ds.parent))
        push!(get!(groups, _ds_find!(ds, n), T[]), n)
    end
    groups
end
