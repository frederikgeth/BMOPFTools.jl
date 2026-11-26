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

Ideal (zero-resistance) `dc_branch` conductors that close a loop, each as
`(branch, conductor, from, to)`. Branches are visited in sorted order, so the
conductor named is the one that closes the loop in that order; removing any
conductor of the loop, or giving it its resistance, opens it.

Every terminal the case fixes at a potential counts as ONE node: an ideal path
between two fixed terminals closes the same kind of loop through their
references. A conductor whose two ends are both fixed states nothing new (its
equality is omitted when consistent) and is not an edge here.
"""
function _dc_ideal_loops(net::Dict{String,Any})
    loops = NamedTuple{(:branch, :conductor, :from, :to),
                       Tuple{String,Int,Tuple{String,String},Tuple{String,String}}}[]
    fixed = _dc_fixed_terminals(net)
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
            (haskey(fixed, a) && haskey(fixed, b)) && continue
            ra = root(haskey(fixed, a) ? _DC_EARTH : a)
            rb = root(haskey(fixed, b) ? _DC_EARTH : b)
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

"""
    _dc_reference_conflicts(net) -> Vector{NamedTuple}

Exact DC voltage statements in the case that contradict each other, each as
`(kind, owner, from, to, stated, implied)`:

- `:fixed_terminals` — two terminals joined by ideal conductors are fixed at
  different voltages (`owner` is the terminal that disagrees);
- `:voltage_master` — a `dc_control = "V"` converter sets a port voltage that
  the fixed terminals and the masters before it (in sorted order) already fix
  at a different value.

The references are the ones the OPF builds: fixed terminals first, then
voltage masters, over nodes merged by ideal conductors.
"""
function _dc_reference_conflicts(net::Dict{String,Any})
    Conflict = NamedTuple{(:kind, :owner, :from, :to, :stated, :implied),
        Tuple{Symbol,String,Tuple{String,String},Tuple{String,String},Float64,Float64}}
    conflicts = Conflict[]
    haskey(net, "dc_bus") || return conflicts
    classes = _dc_node_classes(net)
    graph = _DCReferenceGraph()
    fixed = _dc_fixed_terminals(net)
    for key in sort!(collect(keys(fixed)))
        status, implied = _dc_reference_record!(graph, classes(key...), _DC_EARTH, fixed[key])
        status == :conflict && push!(conflicts, (kind=:fixed_terminals,
            owner="$(key[1]).$(key[2])", from=key, to=_DC_EARTH,
            stated=fixed[key], implied=Float64(implied)))
    end
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
        a = classes(b, tm[1])
        c = length(tm) >= 2 ? classes(b, tm[2]) : _DC_EARTH
        status, implied = _dc_reference_record!(graph, a, c, v_set)
        status == :conflict && push!(conflicts, (kind=:voltage_master, owner=id,
            from=(b, tm[1]), to=length(tm) >= 2 ? (b, tm[2]) : _DC_EARTH,
            stated=Float64(v_set), implied=Float64(implied)))
    end
    conflicts
end

"""
    _ac_ideal_loops(net) -> Vector{NamedTuple}

Ideal AC conductors that close a loop, each as `(element, id, conductor, from,
to)`. An ideal conductor is a closed switch conductor, or a line conductor
whose whole impedance row is exactly zero (no self and no mutual impedance).
Parallel ideal conductors and self-loops are loops. Lines are visited before
switches, each in sorted order.

This is the static counterpart of the check the OPF line and switch builders
make while stamping. The two agree on the case as written; a coefficient
provider that changes a line impedance at build time is seen only by the
builder.
"""
function _ac_ideal_loops(net::Dict{String,Any})
    Node = Tuple{String,String}
    loops = NamedTuple{(:element, :id, :conductor, :from, :to),
                       Tuple{String,String,Int,Node,Node}}[]
    parent = Dict{Node,Node}()
    function root(x)
        get!(parent, x, x)
        while parent[x] != x
            parent[x] = parent[parent[x]]
            x = parent[x]
        end
        return x
    end
    function edge!(element, id, k, a, b)
        ra, rb = root(a), root(b)
        ra == rb ? push!(loops, (element=element, id=id, conductor=k, from=a, to=b)) :
                   (parent[ra] = rb)
        return nothing
    end
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
    loops
end
