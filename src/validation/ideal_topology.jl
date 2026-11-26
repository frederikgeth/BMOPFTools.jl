# Ideal-coupling topology shared by validation and the OPF builders.
#
# An ideal element (a zero-impedance conductor, a closed switch, a perfect
# ground, a fixed voltage) states an exact relation between node voltages and
# carries a current that no impedance determines. Two things can go wrong when
# such relations are combined, and both are properties of the CASE, visible
# before any model is built:
#
#   * a LOOP of ideal conductors: one voltage relation is implied by the
#     others, and a current can circulate around the loop at no cost;
#   * CONTRADICTORY voltage references: two exact statements about the same
#     voltage difference that disagree.
#
# The functions here find both from case data alone. The OPF builders call the
# same functions and raise on what they return, so a case that validation
# passes cannot be rejected for these reasons at build time, and vice versa.

const _DC_EARTH = ("", "")   # the common node of all perfectly grounded DC terminals

# A terminal map as strings, or an empty list when the field is not a list of
# strings. These detectors run on unvalidated input: a malformed record is some
# other check's finding, and here it simply contributes no edge.
_terminal_list(x) = (x isa AbstractVector && all(t -> t isa AbstractString, x)) ?
    String[String(t) for t in x] : String[]
_bus_id(x) = x isa AbstractString ? String(x) : ""

# Terminal roles, or `nothing` when the case is too malformed to resolve them
# (a bad `terminal_conventions` block, a `terminal_names` that is not a list).
# Those defects are reported by the schema and conventions checks.
function _terminal_roles_or_nothing(net)
    try
        return _terminal_roles(net)
    catch err
        err isa InterruptException && rethrow()
        return nothing
    end
end

# Set of perfectly-grounded (dc_bus, terminal): declared on the dc_bus, or a
# dc_grounding with no/zero resistance.
function _dc_grounded_terminals(net::Dict{String,Any})
    g = Set{Tuple{String,String}}()
    for (b, dcbus) in get(net, "dc_bus", Dict())
        dcbus isa Dict || continue
        for t in _terminal_list(get(dcbus, "perfectly_grounded_terminals", String[]))
            push!(g, (String(b), t))
        end
    end
    for (_, gr) in get(net, "dc_grounding", Dict())
        gr isa Dict || continue
        b = get(gr, "dc_bus", nothing); t = get(gr, "terminal", nothing)
        (b isa AbstractString && t isa AbstractString) || continue
        r = get(gr, "r", nothing)
        (r === nothing || (r isa Real && r <= 0)) && push!(g, (String(b), String(t)))
    end
    g
end

"""
    _dc_fixed_terminals(net) -> Dict{(dc_bus, terminal), Float64}

Every DC terminal whose voltage the case fixes exactly, with that voltage: a
perfectly grounded terminal (0), or a terminal whose `v_dc_min` equals its
`v_dc_max`. These are the terminals the OPF fixes rather than bounds.
"""
function _dc_fixed_terminals(net::Dict{String,Any})
    fixed = Dict{Tuple{String,String},Float64}()
    grounded = _dc_grounded_terminals(net)
    for (b, dcbus) in get(net, "dc_bus", Dict())
        dcbus isa Dict || continue
        terms = _terminal_list(get(dcbus, "terminal_names", String[]))
        vmin = get(dcbus, "v_dc_min", Float64[]); vmax = get(dcbus, "v_dc_max", Float64[])
        (vmin isa AbstractVector && vmax isa AbstractVector) || (vmin = Float64[]; vmax = Float64[])
        for (k, t) in enumerate(terms)
            key = (String(b), t)
            if key in grounded
                fixed[key] = 0.0
            elseif k <= length(vmin) && k <= length(vmax) && vmin[k] isa Real &&
                   vmax[k] isa Real && vmin[k] == vmax[k]
                fixed[key] = Float64(vmin[k])
            end
        end
    end
    fixed
end

# Conductors of a dc_branch as (k, from-node, to-node, ideal::Bool); `ideal`
# means no positive resistance is given for conductor k.
function _dc_branch_conductors(br)
    bf = _bus_id(get(br, "dc_bus_from", "")); bt = _bus_id(get(br, "dc_bus_to", ""))
    tmf = _terminal_list(get(br, "terminal_map_from", String[]))
    tmt = _terminal_list(get(br, "terminal_map_to", String[]))
    rv = get(br, "r", Float64[]); rv isa AbstractVector || (rv = Float64[])
    [(k, (bf, tmf[k]), (bt, tmt[k]),
      !(k <= length(rv) && rv[k] isa Real && rv[k] > 0))
     for k in 1:min(length(tmf), length(tmt))]
end

function _dc_known_terminals(net)
    Set((String(b), t) for (b, dcbus) in get(net, "dc_bus", Dict())
        if dcbus isa Dict for t in _terminal_list(get(dcbus, "terminal_names", String[])))
end

"""
    _dc_node_classes(net) -> (bus, terminal) -> representative

Electrical equivalence of DC terminals under IDEAL connections: terminals
joined by a zero-resistance `dc_branch` conductor are one node, and every
perfectly grounded terminal is the earth node `_DC_EARTH`. Used wherever "the
same DC port" must mean the same pair of nodes rather than the same record.
"""
function _dc_node_classes(net)
    parent = Dict{Tuple{String,String},Tuple{String,String}}()
    function find(x)
        get!(parent, x, x)
        while parent[x] != x
            parent[x] = parent[parent[x]]
            x = parent[x]
        end
        return x
    end
    # Earth, when present in a class, is always its representative.
    function unite!(a, b)
        ra = find(a); rb = find(b)
        ra == rb && return nothing
        rb == _DC_EARTH ? (parent[ra] = rb) : (parent[rb] = ra)
        return nothing
    end
    net isa Dict{String,Any} || return (bus, terminal) -> (String(bus), String(terminal))
    for key in _dc_grounded_terminals(net)
        unite!(_DC_EARTH, (String(key[1]), String(key[2])))
    end
    for (_, br) in get(net, "dc_branch", Dict())
        br isa AbstractDict || continue
        for (_, a, b, ideal) in _dc_branch_conductors(br)
            ideal && unite!(a, b)
        end
    end
    return (bus, terminal) -> find((String(bus), String(terminal)))
end

"""
    _dc_ideal_loops(net) -> Vector{NamedTuple}

Ideal (zero-resistance) `dc_branch` conductors whose CURRENT the network does
not determine, each as `(branch, conductor, from, to)`.

An ideal conductor carries a current that no resistance sets; only Kirchhoff's
current law can fix it. KCL fixes the currents of a set of ideal conductors
exactly when they form a forest over the DC nodes, where every **perfectly
grounded** terminal is one and the same node (earth): a ground supplies
whatever current is asked of it, so KCL says nothing there. A cycle — three
ideal conductors in a triangle, two in parallel, or a single ideal conductor
between two perfect grounds, which closes its loop through the earth — leaves a
circulating current free.

This is a statement about currents only. Whether a conductor's *voltage*
relation is new information, implied, or contradictory is a separate question,
answered by the reference graph (`_dc_reference_conflicts`): a terminal fixed
by equal voltage bounds, for instance, has a known voltage but no free
injection, so it is an ordinary node here.

Branches are visited in sorted order; the conductor named is the one that
closes the loop in that order.
"""
function _dc_ideal_loops(net::Dict{String,Any})
    loops = NamedTuple{(:branch, :conductor, :from, :to),
                       Tuple{String,Int,Tuple{String,String},Tuple{String,String}}}[]
    grounded = _dc_grounded_terminals(net)
    known = _dc_known_terminals(net)
    parent = Dict{Tuple{String,String},Tuple{String,String}}()
    function root(x)
        get!(parent, x, x)
        while parent[x] != x
            parent[x] = parent[parent[x]]
            x = parent[x]
        end
        return x
    end
    branches = get(net, "dc_branch", Dict())
    for id in sort!(collect(String.(keys(branches))))
        br = branches[id]; br isa AbstractDict || continue
        for (k, a, b, ideal) in _dc_branch_conductors(br)
            (ideal && a in known && b in known) || continue
            ra = root(a in grounded ? _DC_EARTH : a)
            rb = root(b in grounded ? _DC_EARTH : b)
            if ra == rb
                push!(loops, (branch=id, conductor=k, from=a, to=b))
            else
                parent[ra] = rb
            end
        end
    end
    loops
end

"""
    _DCReferenceGraph

Voltage references between DC nodes as a union-find with potentials: every
node carries its voltage relative to the representative of its component.
Adding V(a) − V(b) = U either joins two components (an independent reference)
or closes a cycle, in which case it must agree with what the component already
implies.
"""
struct _DCReferenceGraph
    parent::Dict{Tuple{String,String},Tuple{String,String}}
    offset::Dict{Tuple{String,String},Float64}   # V(node) − V(parent)
    _DCReferenceGraph() = new(Dict{Tuple{String,String},Tuple{String,String}}(),
                              Dict{Tuple{String,String},Float64}())
end

# Representative of `x` and V(x) − V(representative), with path compression.
function _dc_reference_find!(g::_DCReferenceGraph, x)
    haskey(g.parent, x) || (g.parent[x] = x; g.offset[x] = 0.0)
    g.parent[x] == x && return (x, 0.0)
    root, above = _dc_reference_find!(g, g.parent[x])
    g.offset[x] += above
    g.parent[x] = root
    return (root, g.offset[x])
end

"""
    _dc_reference_record!(graph, a, b, U) -> (status, implied)

Record the reference V(a) − V(b) = U. `status` is `:independent` when the
reference adds information (its row belongs in the model), `:implied` when the
references already recorded give the same difference, and `:conflict` when
they give a different one. `implied` is that existing difference, or `nothing`.
A conflicting reference is not recorded.
"""
function _dc_reference_record!(g::_DCReferenceGraph, a, b, U::Real)
    ra, va = _dc_reference_find!(g, a)      # V(a) − V(ra)
    rb, vb = _dc_reference_find!(g, b)      # V(b) − V(rb)
    if ra == rb
        implied = va - vb
        consistent = isapprox(implied, U; atol=1e-9 * max(1.0, abs(implied), abs(U)))
        return (consistent ? :implied : :conflict, implied)
    end
    # V(ra) − V(rb) = U − va + vb
    g.parent[ra] = rb
    g.offset[ra] = U - va + vb
    return (:independent, nothing)
end

# Default pole-to-return nominal DC voltage of a port from the dc_bus `v_dc_nom`.
function _dc_v_nom_port(net, b, tm)
    dcb = get(get(net, "dc_bus", Dict()), b, nothing)
    dcb isa Dict || return nothing
    raw = get(dcb, "v_dc_nom", Float64[])
    (raw isa AbstractVector && all(x -> x isa Real, raw)) || return nothing
    nom = Float64.(raw)
    terms = _terminal_list(get(dcb, "terminal_names", String[]))
    idx(t) = findfirst(==(t), terms)
    if length(tm) >= 2
        i, j = idx(tm[1]), idx(tm[2])
        (i !== nothing && j !== nothing && i <= length(nom) && j <= length(nom)) || return nothing
        return nom[i] - nom[j]
    elseif length(tm) == 1
        i = idx(tm[1])
        return (i !== nothing && i <= length(nom)) ? nom[i] : nothing
    end
    nothing
end

# The return terminal of a dc_bus: its METALLIC_RETURN pole, else a terminal
# named "m" or "n".
function _dc_return_terminal(dcbus::AbstractDict)
    pole = get(dcbus, "pole", nothing)
    if pole isa AbstractDict
        for (t, role) in pole
            role == "METALLIC_RETURN" && return String(t)
        end
    end
    for t in _terminal_list(get(dcbus, "terminal_names", String[]))
        lowercase(t) in ("m", "n") && return t
    end
    nothing
end

"""
    _dc_exact_pair_references(net) -> Vector{NamedTuple}

Voltage-pair bounds that are EXACT (`vdc_ln_min == vdc_ln_max`, or
`vdc_ll_min == vdc_ll_max`), as the references they amount to:
`(owner, from, to, value)` with `value = V(from) − V(to)`. An exact band is a
statement of the difference itself, on the same footing as a fixed terminal or
a voltage master. Orientation follows the pole roles, as in the OPF.
"""
function _dc_exact_pair_references(net::Dict{String,Any})
    refs = NamedTuple{(:owner, :from, :to, :value),
        Tuple{String,Tuple{String,String},Tuple{String,String},Float64}}[]
    buses = get(net, "dc_bus", Dict())
    for b in sort!(collect(String.(keys(buses))))
        dcbus = buses[b]; dcbus isa AbstractDict || continue
        pole = get(dcbus, "pole", nothing)
        role(t) = pole isa AbstractDict ? get(pole, t, "") : ""
        terms = _terminal_list(get(dcbus, "terminal_names", String[]))
        ret = _dc_return_terminal(dcbus)
        lo = get(dcbus, "vdc_ln_min", nothing); hi = get(dcbus, "vdc_ln_max", nothing)
        if lo isa Real && hi isa Real && lo == hi && ret !== nothing
            for t in terms
                t == ret && continue
                sign = role(t) == "POSITIVE" ? 1.0 : role(t) == "NEGATIVE" ? -1.0 : 0.0
                sign == 0.0 && continue
                push!(refs, (owner="dc_bus '$b' vdc_ln bound on '$t'",
                             from=(b, t), to=(b, ret), value=sign * Float64(lo)))
            end
        end
        lo = get(dcbus, "vdc_ll_min", nothing); hi = get(dcbus, "vdc_ll_max", nothing)
        if lo isa Real && hi isa Real && lo == hi
            pos = [t for t in terms if role(t) == "POSITIVE"]
            neg = [t for t in terms if role(t) == "NEGATIVE"]
            (isempty(pos) || isempty(neg)) && continue
            push!(refs, (owner="dc_bus '$b' vdc_ll bound",
                         from=(b, pos[1]), to=(b, neg[1]), value=Float64(lo)))
        end
    end
    refs
end

"""
    _dc_seed_references!(graph, net) -> Vector

Record in `graph` every exact DC voltage the case states without a converter:
each fixed terminal against earth, each ideal conductor as "its two ends are at
one voltage", and each exact voltage-pair bound. Returns the conflicts met, as `_dc_reference_conflicts`
describes them. The OPF seeds its own reference graph with the same call.
"""
function _dc_seed_references!(graph::_DCReferenceGraph, net::Dict{String,Any})
    Conflict = NamedTuple{(:kind, :owner, :from, :to, :stated, :implied),
        Tuple{Symbol,String,Tuple{String,String},Tuple{String,String},Float64,Float64}}
    conflicts = Conflict[]
    fixed = _dc_fixed_terminals(net)
    for key in sort!(collect(keys(fixed)))
        status, implied = _dc_reference_record!(graph, key, _DC_EARTH, fixed[key])
        status == :conflict && push!(conflicts, (kind=:fixed_terminals,
            owner="$(key[1]).$(key[2])", from=key, to=_DC_EARTH,
            stated=fixed[key], implied=Float64(implied)))
    end
    known = _dc_known_terminals(net)
    branches = get(net, "dc_branch", Dict())
    for id in sort!(collect(String.(keys(branches))))
        br = branches[id]; br isa AbstractDict || continue
        for (k, a, b, ideal) in _dc_branch_conductors(br)
            (ideal && a in known && b in known) || continue
            status, implied = _dc_reference_record!(graph, a, b, 0.0)
            status == :conflict && push!(conflicts, (kind=:ideal_conductor,
                owner="$id.$k", from=a, to=b, stated=0.0, implied=Float64(implied)))
        end
    end
    for ref in _dc_exact_pair_references(net)
        (ref.from in known && ref.to in known) || continue
        status, implied = _dc_reference_record!(graph, ref.from, ref.to, ref.value)
        status == :conflict && push!(conflicts, (kind=:exact_pair_bound,
            owner=ref.owner, from=ref.from, to=ref.to, stated=ref.value,
            implied=Float64(implied)))
    end
    conflicts
end

"""
    _dc_reference_conflicts(net) -> Vector{NamedTuple}

Exact DC voltage statements in the case that contradict each other, each as
`(kind, owner, from, to, stated, implied)`:

- `:fixed_terminals` — a terminal fixed at a voltage the references before it
  already put elsewhere;
- `:ideal_conductor` — a zero-resistance conductor (which states that its two
  ends are at one voltage) between terminals the other references hold at
  different voltages, for example 800 V and 700 V fixed by voltage bounds;
- `:exact_pair_bound` — a `vdc_ln` or `vdc_ll` bound with equal minimum and
  maximum states a difference the other references put elsewhere;
- `:voltage_master` — a `dc_control = "V"` converter sets a port voltage that
  the fixed terminals, the ideal conductors and the masters before it (in
  sorted order) already fix at a different value.

The references are the ones the OPF builds, in the same order: fixed
terminals, ideal conductors, voltage masters.
"""
function _dc_reference_conflicts(net::Dict{String,Any})
    haskey(net, "dc_bus") || return _dc_seed_references!(_DCReferenceGraph(), Dict{String,Any}())
    graph = _DCReferenceGraph()
    conflicts = _dc_seed_references!(graph, net)
    ibrs = get(net, "ibr", Dict())
    known = _dc_known_terminals(net)
    for id in sort!(collect(String.(keys(ibrs))))
        inv = ibrs[id]
        (inv isa Dict && haskey(inv, "dc_bus") &&
         get(inv, "dc_control", "P") == "V") || continue
        b = _bus_id(inv["dc_bus"]); tm = _terminal_list(get(inv, "dc_terminal_map", String[]))
        (isempty(tm) || !all(t -> (b, t) in known, tm)) && continue
        v_set = let s = get(inv, "dc_v_set", nothing)
            s isa Real ? Float64(s) : _dc_v_nom_port(net, b, tm)
        end
        v_set === nothing && continue
        a = (b, tm[1])
        c = length(tm) >= 2 ? (b, tm[2]) : _DC_EARTH
        status, implied = _dc_reference_record!(graph, a, c, v_set)
        status == :conflict && push!(conflicts, (kind=:voltage_master, owner=id,
            from=a, to=c, stated=Float64(v_set), implied=Float64(implied)))
    end
    conflicts
end

"""
    _ac_reference_terminals(net) -> Set{(bus, terminal)}

AC terminals that can supply any current: perfectly grounded terminals, the
neutral of every voltage-source bus (which the OPF grounds), and the terminals
a voltage source fixes. Each has a free injection in the model (an earth
current, or the source's slack current), so Kirchhoff's current law places no
condition there. For the purpose of deciding whether ideal-conductor currents
are determined they are all one node.
"""
function _ac_reference_terminals(net::Dict{String,Any})
    refs = Set{Tuple{String,String}}()
    buses = get(net, "bus", Dict())
    for (bid, bus) in buses
        bus isa Dict || continue
        for t in _terminal_list(get(bus, "perfectly_grounded_terminals", String[]))
            push!(refs, (String(bid), t))
        end
    end
    roles = _terminal_roles_or_nothing(net)
    for (_, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        bus = _bus_id(get(vs, "bus", ""))
        for t in _terminal_list(get(vs, "terminal_map", String[]))
            push!(refs, (bus, t))
        end
        b = get(buses, bus, nothing)
        nt = roles === nothing ? nothing : _declared_bus_neutral(roles, b)
        nt === nothing || push!(refs, (bus, nt))
    end
    refs
end

"""
    _IdealRowBasis{K}

An incremental basis of ideal voltage rows, for deciding whether a new row is
linearly independent of the rows recorded so far. A row is a homogeneous linear
relation between terminal voltages that no impedance relaxes:

- an ideal conductor states `V_p − V_q = 0`;
- one coil pair of an ideal (zero-leakage) transformer with a fixed ratio
  states `(V_p − V_q) − N·(V_p' − V_q') = 0`.

Each row has one current that only Kirchhoff's current law can determine, and
that current is injected with exactly the row's coefficients (`+I` at `p`,
`−I` at `q`; for a transformer the ampere-turn balance supplies the factor
`N`). The injection pattern is therefore the transpose of the voltage rows, so
the two questions have one answer: the rows are independent **if and only if**
KCL determines every ideal current. Terminals held at a fixed voltage (perfect
grounds, source terminals) are left out of a row before it is tested, because
their voltage is not an unknown and their injection is free.

For ideal conductors alone this is the forest test of graph theory (the rows
are the incidence rows of a graph); the basis extends it to rows with a ratio.
Rows are reduced by sparse Gaussian elimination; `pivots[k]` is a recorded row
scaled to coefficient one at `k`, stored without that entry.
"""
struct _IdealRowBasis{K}
    pivots::Dict{K,Dict{K,Float64}}
end
_IdealRowBasis{K}() where {K} = _IdealRowBasis{K}(Dict{K,Dict{K,Float64}}())

"""
    _ideal_row_add!(basis, terms) -> Bool

Record the row `Σ coefficient·V[key] = 0` given as `(key, coefficient)` pairs.
Returns `true` when the row is independent of those already recorded (it is
then kept), `false` when it is dependent, which includes a row with no unknown
left. Coefficients below `1e-9` of the row's largest are treated as zero.
"""
function _ideal_row_add!(basis::_IdealRowBasis{K}, terms) where {K}
    row = Dict{K,Float64}()
    for (key, a) in terms
        row[key] = get(row, key, 0.0) + Float64(a)
    end
    scale = maximum(abs, values(row); init=0.0)
    tol = 1e-9 * scale
    filter!(kv -> abs(kv.second) > tol, row)
    # A recorded row never contains the pivot of an earlier one, so reduction
    # only ever moves forward through the rows and terminates.
    while true
        hit = nothing
        for key in keys(row)
            haskey(basis.pivots, key) && (hit = key; break)
        end
        hit === nothing && break
        a = pop!(row, hit)
        for (key, b) in basis.pivots[hit]
            v = get(row, key, 0.0) - a * b
            abs(v) > tol ? (row[key] = v) : delete!(row, key)
        end
    end
    isempty(row) && return false
    pivot = first(row).first
    for (key, v) in row
        abs(v) > abs(row[pivot]) && (pivot = key)
    end
    a = pop!(row, pivot)
    for key in keys(row)
        row[key] /= a
    end
    basis.pivots[pivot] = row
    return true
end

"""
    _ac_ideal_transformer_rows(net) -> Vector{NamedTuple}

The voltage rows of the ideal `single_phase` transformers (wye–wye and
single-phase units: zero series impedance on both sides and a fixed tap), each
as `(id, winding, from, to, terms)` where `terms` are `((bus, terminal),
coefficient)` pairs of `(V_p − V_q) − N·(V_p' − V_q') = 0` and `from`/`to` are
the two `p` terminals. Wye–delta units and regulators are judged by the OPF
builder, which holds their winding wiring.
"""
function _ac_ideal_transformer_rows(net::Dict{String,Any})
    Node = Tuple{String,String}
    rows = NamedTuple{(:id, :winding, :from, :to, :terms),
                      Tuple{String,Int,Node,Node,Vector{Pair{Node,Float64}}}}[]
    xfmrs = get(get(net, "transformer", Dict()), "single_phase", Dict())
    xfmrs isa AbstractDict || return rows
    roles = _terminal_roles_or_nothing(net)
    roles === nothing && return rows
    for id in sort!(collect(String.(keys(xfmrs))))
        x = xfmrs[id]; x isa Dict{String,Any} || continue
        zero_field(f) = (v = get(x, f, 0.0); v isa Real && iszero(v))
        all(zero_field, ("r_series_from", "x_series_from", "r_series_to", "x_series_to")) || continue
        _xfmr_ratio_coeff_bounds("single_phase", x) === nothing || continue   # free tap
        bf = _bus_id(get(x, "bus_from", "")); bt = _bus_id(get(x, "bus_to", ""))
        tmf = _terminal_list(get(x, "terminal_map_from", String[]))
        tmt = _terminal_list(get(x, "terminal_map_to", String[]))
        N = try
            _xfmr_turns_ratio(x) * _xfmr_tap_mult(x)
        catch
            continue
        end
        pf = _xfmr_winding_pairs(tmf, roles.neutral); pt = _xfmr_winding_pairs(tmt, roles.neutral)
        for k in 1:min(length(pf), length(pt))
            (p, q) = pf[k]; (p2, q2) = pt[k]
            terms = Pair{Node,Float64}[(bf, tmf[p]) => 1.0, (bt, tmt[p2]) => -N]
            q === nothing || push!(terms, (bf, tmf[q]) => -1.0)
            q2 === nothing || push!(terms, (bt, tmt[q2]) => N)
            push!(rows, (id=id, winding=k, from=(bf, tmf[p]), to=(bt, tmt[p2]), terms=terms))
        end
    end
    rows
end

"""
    _ac_ideal_loops(net) -> Vector{NamedTuple}

Ideal AC elements whose voltage row is dependent, and whose current the
network therefore does not determine, each as
`(element, id, conductor, from, to)`. The ideal elements are closed switch
conductors, line conductors whose whole impedance row is exactly zero (no self
and no mutual impedance), and the coil pairs of ideal `single_phase`
transformers (`_ac_ideal_transformer_rows`; `conductor` is then the winding).

The test is the row-independence test of [`_IdealRowBasis`](@ref), with every
terminal held at a fixed voltage (`_ac_reference_terminals`: perfect grounds
and source terminals) left out of the rows. For conductors alone it reads as a
graph rule: the ideal conductors must form a forest in which all those
terminals are one node. So besides parallel ideal conductors and ideal rings,
an ideal conductor **between two reference terminals** is reported: the
neutral of a four-wire switch between two buses with grounded neutrals closes
through the earth, and how the return current divides between that conductor
and the earth is determined by nothing in the model. Two ideal transformers in
parallel, or one in parallel with a closed switch, are reported for the same
reason: their voltage rows say the same thing twice and the current divides
arbitrarily between them.

The rule is sufficient, not necessary. Between two terminals whose voltages
are both fixed the row is always dependent (both sides are data), and it is
reported even in the special case where exact power setpoints at one of the
sources happen to pin the current.

Such a conductor between two **earthed** terminals is redundant rather than
wrong, and `fix_case` removes it (`_ac_earthed_ideal_conductors`).

Lines are visited first, then switches, then transformers, each in sorted
order. This is the static counterpart of the check the OPF builders make while
stamping. The two agree on the case as written; a coefficient provider that
changes a line impedance at build time, and the ideal wye–delta units and
regulators, are seen only by the builder.
"""
function _ac_ideal_loops(net::Dict{String,Any})
    Node = Tuple{String,String}
    loops = NamedTuple{(:element, :id, :conductor, :from, :to),
                       Tuple{String,String,Int,Node,Node}}[]
    references = _ac_reference_terminals(net)
    basis = _IdealRowBasis{Node}()
    function row!(element, id, k, a, b, terms)
        free = [t for t in terms if !(t.first in references)]
        _ideal_row_add!(basis, free) ||
            push!(loops, (element=element, id=id, conductor=k, from=a, to=b))
        return nothing
    end
    edge!(element, id, k, a, b) = row!(element, id, k, a, b, [a => 1.0, b => -1.0])
    linecodes = get(net, "linecode", Dict())
    lines = get(net, "line", Dict())
    for id in sort!(collect(String.(keys(lines))))
        line = lines[id]; line isa Dict{String,Any} || continue
        Z, n = try
            _line_z_complex(line, linecodes)
        catch
            (nothing, 0)
        end
        (Z === nothing || n == 0) && continue
        bf = _bus_id(get(line, "bus_from", "")); bt = _bus_id(get(line, "bus_to", ""))
        tmf = _terminal_list(get(line, "terminal_map_from", String[]))
        tmt = _terminal_list(get(line, "terminal_map_to", String[]))
        (length(tmf) == n && length(tmt) == n) || continue
        for k in 1:n
            all(iszero, @view Z[k, :]) && edge!("line", id, k, (bf, tmf[k]), (bt, tmt[k]))
        end
    end
    switches = get(net, "switch", Dict())
    for id in sort!(collect(String.(keys(switches))))
        sw = switches[id]; sw isa Dict || continue
        get(sw, "open_switch", false) === true && continue
        bf = _bus_id(get(sw, "bus_from", "")); bt = _bus_id(get(sw, "bus_to", ""))
        tmf = _terminal_list(get(sw, "terminal_map_from", String[]))
        tmt = _terminal_list(get(sw, "terminal_map_to", String[]))
        for k in 1:min(length(tmf), length(tmt))
            edge!("switch", id, k, (bf, tmf[k]), (bt, tmt[k]))
        end
    end
    for r in _ac_ideal_transformer_rows(net)
        row!("transformer", r.id, r.winding, r.from, r.to, r.terms)
    end
    loops
end

"""
    _ac_earthed_terminals(net) -> Set{(bus, terminal)}

AC terminals held at earth potential by a perfect ground: declared
`perfectly_grounded_terminals`, and the neutral of every voltage-source bus
(which the OPF grounds). A subset of `_ac_reference_terminals`; source PHASE
terminals are references but are not at zero volts.
"""
function _ac_earthed_terminals(net::Dict{String,Any})
    earthed = Set{Tuple{String,String}}()
    buses = get(net, "bus", Dict())
    for (bid, bus) in buses
        bus isa Dict || continue
        for t in _terminal_list(get(bus, "perfectly_grounded_terminals", String[]))
            push!(earthed, (String(bid), t))
        end
    end
    roles = _terminal_roles_or_nothing(net)
    roles === nothing && return earthed
    for (_, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        bus = _bus_id(get(vs, "bus", ""))
        nt = _declared_bus_neutral(roles, get(buses, bus, nothing))
        nt === nothing || push!(earthed, (bus, nt))
    end
    earthed
end

"""
    _ac_earthed_ideal_conductors(net) -> Vector{NamedTuple}

Ideal AC conductors that join two **earthed** terminals, each as
`(element, id, conductor)`. Both ends are at zero volts and both can sink any
current, so the conductor does nothing electrically: it carries no determinate
current and removing it changes no other quantity in the network. These are the
loops `_ac_ideal_loops` reports that have an exact, automatic remedy
(`fix_case`, pass "remove earthed ideal conductors").

For a line the conductor must be decoupled both ways: its impedance row AND
column are zero, and so are its shunt rows and columns. A nonzero mutual term
would let the undetermined current act on another conductor, which removal
cannot preserve.
"""
function _ac_earthed_ideal_conductors(net::Dict{String,Any})
    out = NamedTuple{(:element, :id, :conductor), Tuple{String,String,Int}}[]
    earthed = _ac_earthed_terminals(net)
    linecodes = get(net, "linecode", Dict())
    lines = get(net, "line", Dict())
    for id in sort!(collect(String.(keys(lines))))
        line = lines[id]; line isa Dict{String,Any} || continue
        Z, n = try
            _line_z_complex(line, linecodes)
        catch
            (nothing, 0)
        end
        (Z === nothing || n == 0) && continue
        bf = _bus_id(get(line, "bus_from", "")); bt = _bus_id(get(line, "bus_to", ""))
        tmf = _terminal_list(get(line, "terminal_map_from", String[]))
        tmt = _terminal_list(get(line, "terminal_map_to", String[]))
        (length(tmf) == n && length(tmt) == n) || continue
        source = _line_has_inline_z(line) ? line :
                 get(linecodes, get(line, "linecode", nothing), nothing)
        source isa AbstractDict || continue
        shunts = [M for prefix in ("G_from_", "B_from_", "G_to_", "B_to_")
                  for M in (_pattern_keys_to_matrix(source, prefix),) if M !== nothing]
        for k in 1:n
            ((bf, tmf[k]) in earthed && (bt, tmt[k]) in earthed) || continue
            (all(iszero, @view Z[k, :]) && all(iszero, @view Z[:, k])) || continue
            all(M -> size(M, 1) < k || size(M, 2) < k ||
                     (all(iszero, @view M[k, :]) && all(iszero, @view M[:, k])), shunts) || continue
            push!(out, (element="line", id=id, conductor=k))
        end
    end
    switches = get(net, "switch", Dict())
    for id in sort!(collect(String.(keys(switches))))
        sw = switches[id]; sw isa Dict || continue
        get(sw, "open_switch", false) === true && continue
        bf = _bus_id(get(sw, "bus_from", "")); bt = _bus_id(get(sw, "bus_to", ""))
        tmf = _terminal_list(get(sw, "terminal_map_from", String[]))
        tmt = _terminal_list(get(sw, "terminal_map_to", String[]))
        for k in 1:min(length(tmf), length(tmt))
            ((bf, tmf[k]) in earthed && (bt, tmt[k]) in earthed) &&
                push!(out, (element="switch", id=id, conductor=k))
        end
    end
    out
end
