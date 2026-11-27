# validation/integrity.jl
#
# Structural integrity and degeneracy checks, motivated by the pitfalls in
# Geth et al., "Considerations and design goals for unbalanced optimal power
# flow benchmarks", EPSR 235 (2024) 110646:
#   §5.1.1 small nonzero impedances  → low-impedance line detection
#   §5.1.2 padding is inefficient    → zero row/col + dimension consistency
#   §5.1.4 Kron tracking             → wye loads without a neutral
#   §5.1.5 deficient datasets        → voltage reference per galvanic island
#   §3     symmetry/degeneracy       → identical generator costs
# plus referential integrity (dangling bus/linecode/terminal references).

"""
    _unreferenced_conductor_groups(net) -> Vector{Vector{Tuple{String,String}}}

Conductor groups that no element ties to the voltage reference.

A bus-level island test is not enough: an earth shunt on a separately carried
neutral says nothing about delta-connected phases that no element connects to
that neutral. The phases can then shift together without changing any equation.

A *conductor group* is a set of `(bus, terminal)` nodes joined by elements that
fix voltage differences between them: a line or closed switch conductor, a
mutual line-shunt entry, the two ends of an active load or generator coil
(nonzero demand; bounds that do not force zero output), the terminals of one
IBR or
capacitor, two shunt terminals with a nonzero admittance entry between them,
the terminals of one transformer winding side (both sides for the galvanically
continuous subtypes). A group is referenced when one of its nodes is tied to
earth: a perfectly grounded terminal, a voltage-source terminal or the neutral
of a source bus, a shunt or stamped line-shunt row with a nonzero sum, a
transformer neutral impedance, or a coil written against earth (WYE or
one-terminal SINGLE_PHASE with no neutral in its map) whose power is given: a
load coil with nonzero demand, a generator coil with fixed, nonzero output. Declared terminals that no element
touches are not groups (they are `W.INT.UNUSED_BUS_TERMINAL`).
"""
_unreferenced_conductor_groups(net) = _conductor_reference(net).groups

# The one source of voltage-reference evidence. Returns the unreferenced
# conductor `groups` and `earthed_buses`, the buses that carry at least one
# terminal tied to earth; the island test and the conductor-group test both
# read this, so they cannot disagree about what a reference is.
function _conductor_reference(net)
    Node = Tuple{String,String}
    parent = Dict{Node,Node}()
    earthed = Set{Node}()
    function find(x)
        haskey(parent, x) || (parent[x] = x)
        root = x
        while parent[root] != root; root = parent[root]; end
        while parent[x] != root
            parent[x], x = root, parent[x]
        end
        root
    end
    tie!(a, b) = (ra = find(a); rb = find(b); ra == rb || (parent[ra] = rb); nothing)
    node(bus, t) = (String(bus), string(t))
    strs(tm) = tm isa AbstractVector && all(x -> x isa AbstractString, tm)
    function tie_all!(bus, tm)
        bus isa AbstractString && strs(tm) && !isempty(tm) || return
        first_node = node(bus, tm[1]); find(first_node)
        for t in tm[2:end]; tie!(first_node, node(bus, t)); end
    end
    earth!(bus, t) = (n = node(bus, t); find(n); push!(earthed, n); nothing)
    table(key) = (v = get(net, key, nothing); v isa AbstractDict ? v : Dict{String,Any}())

    buses = table("bus")
    for (id, b) in buses
        b isa AbstractDict || continue
        pg = get(b, "perfectly_grounded_terminals", nothing)
        strs(pg) && foreach(t -> earth!(id, t), pg)
    end
    roles = _index_roles(net)
    for (_, vs) in table("voltage_source")
        vs isa AbstractDict || continue
        b = get(vs, "bus", nothing); tm = get(vs, "terminal_map", nothing)
        b isa AbstractString && strs(tm) || continue
        foreach(t -> earth!(b, t), tm)
        # The solver pins the neutral of a source bus to the reference.
        bus = get(buses, b, nothing)
        nt = bus isa Dict{String,Any} && roles !== nothing ? _declared_bus_neutral(roles, bus) : nothing
        nt === nothing || earth!(b, nt)
    end
    linecodes = table("linecode")
    for (_, l) in table("line")
        l isa Dict{String,Any} || continue
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        tmf = get(l, "terminal_map_from", nothing); tmt = get(l, "terminal_map_to", nothing)
        f isa AbstractString && t isa AbstractString && strs(tmf) && strs(tmt) || continue
        n = min(length(tmf), length(tmt))
        blocks = try
            Z, nz = _line_z_complex(l, linecodes)
            Z === nothing || (n = min(n, nz))
            yfr, yto = _line_shunt_complex(l, linecodes)
            (yfr === nothing ? nothing : _zero_padded_block(yfr, n),
             yto === nothing ? nothing : _zero_padded_block(yto, n))
        catch
            (nothing, nothing)                      # malformed data ties nothing to earth
        end
        for k in 1:n
            tie!(node(f, tmf[k]), node(t, tmt[k]))
        end
        for (bus, tm, Y) in ((f, tmf, blocks[1]), (t, tmt, blocks[2]))
            Y === nothing && continue
            all(isfinite, Y) || continue
            scale = maximum(abs, Y; init=0.0)
            scale > 0 || continue
            for i in 1:n
                abs(sum(Y[i, :])) > 1e-9 * scale && earth!(bus, tm[i])
                for j in i+1:n
                    abs(Y[i, j]) > 1e-9 * scale && tie!(node(bus, tm[i]), node(bus, tm[j]))
                end
            end
        end
    end
    for (_, sw) in table("switch")
        sw isa AbstractDict || continue
        get(sw, "open_switch", false) === true && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        tmf = get(sw, "terminal_map_from", nothing); tmt = get(sw, "terminal_map_to", nothing)
        f isa AbstractString && t isa AbstractString && strs(tmf) && strs(tmt) || continue
        for k in 1:min(length(tmf), length(tmt))
            tie!(node(f, tmf[k]), node(t, tmt[k]))
        end
    end
    engine_neutrals = try _neutral_labels(net) catch; nothing end
    # A capacitor ties exactly the terminal pairs its susceptance matrix stamps
    # (`_cap_bmatrix`, the builder the solver uses): each phase to the neutral
    # for WYE, the phase pairs for DELTA, the two terminals for SINGLE_PHASE.
    # A WYE bank without a resolvable neutral stamps nothing and ties nothing.
    for (_, c) in table("capacitor")
        c isa Dict{String,Any} || continue
        b = get(c, "bus", nothing); tm = get(c, "terminal_map", nothing)
        b isa AbstractString && strs(tm) || continue
        B = try _cap_bmatrix(c)[2] catch; nothing end
        B === nothing && continue
        all(isfinite, B) || continue
        for i in 1:length(tm), j in i+1:length(tm)
            i <= size(B, 1) && j <= size(B, 2) && B[i, j] != 0 && tie!(node(b, tm[i]), node(b, tm[j]))
        end
    end
    # IBRs tie all their terminals (THREE_LEG is line-to-line, SINGLE_PHASE is
    # phase-to-reference terminal, FOUR_LEG is phase-to-neutral).
    for (_, c) in table("ibr")
        c isa AbstractDict && tie_all!(get(c, "bus", nothing), get(c, "terminal_map", nothing))
    end
    # A load or generator is a set of coils, read as the solver reads them:
    #   SINGLE_PHASE, two terminals  one coil between them
    #   DELTA                        one coil per phase pair (cyclic for three)
    #   WYE / one-terminal           one coil per phase, to the neutral in the
    #                                map, or to earth when the map holds none
    #                                (the phase-to-reference voltage is used)
    # A coil counts only where it contributes a voltage-dependent term. A coil
    # that carries no current at any voltage neither ties its two ends together
    # nor references anything: a load coil whose demand is zero, a generator
    # coil whose bounds force both P and Q to zero.
    engine_neutrals = try _neutral_labels(net) catch; nothing end
    number(v, k) = v isa AbstractVector && k <= length(v) && v[k] isa Real && isfinite(v[k]) ? Float64(v[k]) : nothing
    load_active(c) = k -> (p = number(get(c, "p_nom", nothing), k); q = number(get(c, "q_nom", nothing), k);
                           (p !== nothing && !iszero(p)) || (q !== nothing && !iszero(q)))
    function generator_active(c)
        forced_zero(lo, hi, k) = (a = number(get(c, lo, nothing), k); b = number(get(c, hi, nothing), k);
                                  a !== nothing && b !== nothing && iszero(a) && iszero(b))
        k -> !(forced_zero("p_min", "p_max", k) && forced_zero("q_min", "q_max", k))
    end
    # A coil written against EARTH is a reference only when its power is given:
    # a load always is; a generator only when both P and Q are fixed (and not
    # both zero). With a dispatch range, a common shift of the terminal
    # voltages is absorbed by the output instead of being pinned.
    function generator_pins(c)
        fixed(lo, hi, k) = (a = number(get(c, lo, nothing), k); b = number(get(c, hi, nothing), k);
                            a !== nothing && b !== nothing && a == b ? a : nothing)
        k -> (p = fixed("p_min", "p_max", k); q = fixed("q_min", "q_max", k);
              p !== nothing && q !== nothing && !(iszero(p) && iszero(q)))
    end
    for (kind, activity, pinning) in (("load", load_active, load_active),
                                      ("generator", generator_active, generator_pins)), (_, c) in table(kind)
        c isa AbstractDict || continue
        b = get(c, "bus", nothing); tm = get(c, "terminal_map", nothing)
        b isa AbstractString && strs(tm) && !isempty(tm) || continue
        active = activity(c); pins = pinning(c)
        cfg = uppercase(string(get(c, "configuration", "WYE")))
        if cfg == "DELTA"
            pairs = length(tm) == 2 ? [(tm[1], tm[2])] :
                    length(tm) == 3 ? [(tm[k], tm[mod1(k + 1, 3)]) for k in 1:3] : Tuple{String,String}[]
            for (k, (x, y)) in enumerate(pairs)
                active(k) && tie!(node(b, x), node(b, y))
            end
        elseif cfg == "SINGLE_PHASE" && length(tm) == 2
            active(1) && tie!(node(b, tm[1]), node(b, tm[2]))
        else
            npos = engine_neutrals === nothing ? _neutral_pos(tm) : _neutral_pos(tm, engine_neutrals)
            phases = [k for k in eachindex(tm) if k != npos]
            for (idx, k) in enumerate(phases)
                if npos === nothing
                    pins(idx) && earth!(b, tm[k])
                else
                    active(idx) && tie!(node(b, tm[k]), node(b, tm[npos]))
                end
            end
        end
    end
    for (_, sh) in table("shunt")
        sh isa AbstractDict || continue
        b = get(sh, "bus", nothing); tm = get(sh, "terminal_map", nothing)
        b isa AbstractString && strs(tm) || continue
        # Only what the admittance matrix couples is tied: a nonzero entry
        # between two terminals, and a nonzero row sum to earth. Listing a
        # terminal in the map does not connect it to anything.
        Y = try
            G = _pattern_keys_to_matrix(sh, "G_"); B = _pattern_keys_to_matrix(sh, "B_")
            n = length(tm)
            complex.(G === nothing ? zeros(n, n) : _zero_padded_block(G, n),
                     B === nothing ? zeros(n, n) : _zero_padded_block(B, n))
        catch
            nothing
        end
        Y === nothing && continue
        all(isfinite, Y) || continue
        scale = maximum(abs, Y; init=0.0)
        scale > 0 || continue
        for i in 1:length(tm)
            abs(sum(Y[i, :])) > 1e-9 * scale && earth!(b, tm[i])
            for j in i+1:length(tm)
                (abs(Y[i, j]) > 1e-9 * scale || abs(Y[j, i]) > 1e-9 * scale) &&
                    tie!(node(b, tm[i]), node(b, tm[j]))
            end
        end
    end
    for record in _connection_records(net)
        record.kind == "transformer" || continue
        ends = _connection_endpoints(record)
        for e in ends
            tie_all!(e.bus, e.map)
        end
        if record.subtype in GALVANIC_CONTINUOUS_SUBTYPES && length(ends) == 2 &&
                all(e -> e.bus isa AbstractString && strs(e.map) && !isempty(e.map), ends)
            tie!(node(ends[1].bus, ends[1].map[1]), node(ends[2].bus, ends[2].map[1]))
        end
    end
    for ((b, t), _) in _transformer_neutral_earthing(net)
        earth!(b, t)
    end

    referenced = Set(find(n) for n in earthed)
    groups = Dict{Node,Vector{Node}}()
    for n in collect(keys(parent))
        r = find(n)
        r in referenced || push!(get!(groups, r, Node[]), n)
    end
    (groups=sort!([sort!(g) for g in values(groups)]),
     earthed_buses=Set{String}(n[1] for n in earthed))
end

# Whether the Π-shunt block a line contributes to the nodal admittance has a
# path to earth. Mirrors `_line_yprim_block`: the same impedance-source choice,
# length scaling and conductor truncation. Malformed data is not a reference.
function _line_stamps_earth_shunt(line::Dict{String,Any}, linecodes::AbstractDict)::Bool
    try
        Z, nz = _line_z_complex(line, linecodes)
        Z === nothing && return false
        tmf = get(line, "terminal_map_from", nothing); tmt = get(line, "terminal_map_to", nothing)
        tmf isa AbstractVector && tmt isa AbstractVector || return false
        n = min(nz, length(tmf), length(tmt))
        n == 0 && return false
        for Y in _line_shunt_complex(line, linecodes)
            Y === nothing && continue
            # Sparse declarations are zero-padded to the conductor count, as
            # every builder reads them: one diagonal entry is a path to earth.
            block = _zero_padded_block(Y, n)
            all(isfinite, block) || continue
            scale = maximum(abs, block)
            scale > 0 || continue
            any(abs(sum(block[i, :])) > 1e-9 * scale for i in 1:n) && return true
        end
        return false
    catch
        return false
    end
end

"""
    integrity_check(net, findings) -> Dict{String,Any}

Structural integrity checks:

- **Referential integrity**: every `bus`/`bus_from`/`bus_to` exists; every
  line's `linecode` exists; every terminal-map entry is a terminal of the
  referenced bus (this also enforces that nodal elements never connect
  directly to ground).
- **Dimension consistency**: line terminal-map arity vs linecode matrix
  size; `i_max` vector length vs conductor count; load setpoint length vs
  configuration; source `v_magnitude`/`v_angle` lengths vs terminal map.
- **Padded matrices**: all-zero row/column pairs in linecode impedances.
- **Galvanic islands**: transformer windings are galvanic separations; each
  island needs a voltage reference (source, perfect grounding, or a
  grounding shunt) or its voltages are defined only up to a shift.
- **Wye without neutral**: wye-configured loads/generators at buses with no
  identifiable neutral imply an undeclared ground return.
- **Low-impedance lines**: lines far below the network's typical series
  impedance — model them as (lossless) switches instead.
- **Generator cost symmetry**: identical cost vectors create dispatch
  degeneracy (any split between them is optimal).
"""
function integrity_check(net::Dict{String,Any},
                          findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()
    buses = get(net, "bus", Dict())
    busset = Set(keys(buses))
    n_ref_issues = 0

    check_bus_ref(comp_type, id, bus) = begin
        if !(bus in busset)
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.UNKNOWN_BUS", :integrity,
                Symbol(comp_type), id,
                "$comp_type '$id' references unknown bus '$bus'.",
                Dict{String,Any}("bus" => bus)))
            return false
        end
        true
    end

    check_tmap(comp_type, id, bus, tm; field="terminal_map") = begin
        _index_strings(tm) || return
        b = get(buses,bus,nothing)
        b isa AbstractDict || return
        names = get(b,"terminal_names",nothing)
        # Schema/indexing evidence owns malformed terminal declarations. A
        # reference cannot be declared missing when the target set is unknown.
        _index_strings(names) || return
        declared = Set(names)
        bad = [t for t in tm if !(t in declared)]
        if !isempty(bad)
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.UNKNOWN_TERMINAL", :integrity,
                Symbol(comp_type), id,
                "$comp_type '$id' $field references terminal(s) " *
                "$(bad) not defined at bus '$bus'.",
                Dict{String,Any}("bus" => bus, "terminals" => bad, "field" => field)))
        end
    end

    # Shared raw endpoint traversal retains original winding indices and handles
    # malformed maps without invoking numeric transformer conversion helpers.
    n_ref_issues += _check_connection_references!(net, findings)

    # Grounding references are bus-terminal references too. Keep their errors
    # under the integrity owner rather than duplicating them as role warnings.
    for id in sort!(collect(keys(buses)))
        bus = buses[id]
        bus isa AbstractDict || continue
        check_tmap("bus", id, id, get(bus,"perfectly_grounded_terminals",String[]);
            field="perfectly_grounded_terminals")
    end

    # --- referential integrity: nodal elements ---
    for comp_type in ("load", "generator", "shunt", "voltage_source", "ibr")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            b = get(c, "bus", nothing)
            b isa AbstractString && check_bus_ref(comp_type, id, b) &&
                check_tmap(comp_type, id, b, get(c, "terminal_map", String[]))
        end
    end

    # --- ibr → control_profile references ---
    profiles = get(net, "control_profile", Dict())
    for (id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        cp = get(inv, "control_profile", nothing)
        if cp isa AbstractString && !haskey(profiles, cp)
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.UNKNOWN_CONTROL_PROFILE", :integrity,
                :ibr, id,
                "IBR '$id' references unknown control_profile '$cp'.",
                Dict{String,Any}("control_profile" => cp)))
        end

        vref = get(inv, "voltage_aggregation", nothing)
        if vref !== nothing && !(vref isa AbstractString &&
                                 uppercase(String(vref)) in ("PER_PHASE", "AVERAGE"))
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.VOLTAGE_AGGREGATION_INVALID", :integrity,
                :ibr, id,
                "IBR '$id' has voltage_aggregation = $(repr(vref)); expected \"PER_PHASE\" or \"AVERAGE\".",
                Dict{String,Any}("voltage_aggregation" => vref)))
        end
    end

    # --- control_profile droop-law consistency ---
    for (cp_id, cp) in profiles
        cp isa Dict || continue
        _check_droop_profile!(findings, cp_id, cp)
    end

    # --- DC network referential integrity ---
    #   dc_bus refs resolve; DC terminal maps resolve to dc_bus.terminal_names;
    #   each connected DC island (dc_buses joined by dc_branches) is referenced
    #   by at least one dc_grounding (perfect or resistive), else signed DC
    #   voltages float — the DC analog of E.INT.NO_VOLTAGE_REFERENCE.
    dc_buses  = get(net, "dc_bus", Dict())
    dc_busset = Set(keys(dc_buses))
    dc_term_set(b) = Set(string.(get(get(dc_buses, b, Dict()),
                                     "terminal_names", String[])))

    check_dc_bus_ref(comp_type, id, b) = begin
        if !(b in dc_busset)
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.UNKNOWN_DC_BUS", :integrity,
                Symbol(comp_type), id,
                "$comp_type '$id' references unknown dc_bus '$b'.",
                Dict{String,Any}("dc_bus" => b)))
            return false
        end
        true
    end

    check_dc_tmap(comp_type, id, b, tm) = begin
        bad = [t for t in string.(tm) if !(t in dc_term_set(b))]
        if !isempty(bad)
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.UNKNOWN_DC_TERMINAL", :integrity,
                Symbol(comp_type), id,
                "$comp_type '$id' DC terminal map references terminal(s) " *
                "$(bad) not defined at dc_bus '$b'.",
                Dict{String,Any}("dc_bus" => b, "terminals" => bad)))
        end
    end

    # IBR DC ports
    for (id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        b = get(inv, "dc_bus", nothing)
        b isa AbstractString || continue
        check_dc_bus_ref("ibr", id, b) &&
            check_dc_tmap("ibr", id, b, get(inv, "dc_terminal_map", String[]))
    end
    # DC loads / sources
    for comp_type in ("dc_load", "dc_source")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            b = get(c, "dc_bus", nothing)
            b isa AbstractString || continue
            check_dc_bus_ref(comp_type, id, b) &&
                check_dc_tmap(comp_type, id, b, get(c, "terminal_map", String[]))
        end
    end
    # DC grounding
    for (id, g) in get(net, "dc_grounding", Dict())
        g isa Dict || continue
        b = get(g, "dc_bus", nothing)
        b isa AbstractString || continue
        if check_dc_bus_ref("dc_grounding", id, b)
            t = get(g, "terminal", nothing)
            t isa AbstractString && check_dc_tmap("dc_grounding", id, b, [t])
        end
    end
    # DC branches (both ends)
    for (id, br) in get(net, "dc_branch", Dict())
        br isa Dict || continue
        for (busfield, tmfield) in (("dc_bus_from", "terminal_map_from"),
                                    ("dc_bus_to",   "terminal_map_to"))
            b = get(br, busfield, nothing)
            b isa AbstractString || continue
            check_dc_bus_ref("dc_branch", id, b) &&
                check_dc_tmap("dc_branch", id, b, get(br, tmfield, String[]))
        end
    end

    # DC islands: union-find over dc_buses joined by dc_branches; require a
    # grounding in each island.
    if !isempty(dc_busset)
        parent = Dict(b => b for b in dc_busset)
        find(x) = (parent[x] == x ? x : (parent[x] = find(parent[x])))
        for (_, br) in get(net, "dc_branch", Dict())
            br isa Dict || continue
            a = get(br, "dc_bus_from", nothing); c = get(br, "dc_bus_to", nothing)
            (a in dc_busset && c in dc_busset) && (parent[find(a)] = find(c))
        end
        grounded_dc = Set(find(get(g, "dc_bus", "")) for (_, g) in
                          get(net, "dc_grounding", Dict())
                          if g isa Dict && get(g, "dc_bus", "") in dc_busset)
        dc_islands = Dict{String,Vector{String}}()
        for b in dc_busset
            push!(get!(dc_islands, find(b), String[]), b)
        end
        for (root, members) in dc_islands
            root in grounded_dc && continue
            push!(findings, Finding(ERROR, "E.INT.NO_DC_VOLTAGE_REFERENCE", :integrity,
                :network, nothing,
                "DC island of $(length(members)) dc_bus(es) has no grounding " *
                "(perfect or resistive) — signed DC voltages float: " *
                "$(join(sort(members), ", ")).",
                Dict{String,Any}("dc_buses" => sort(members))))
        end

        # DC-voltage control: each island needs ≥1 converter on V or droop control,
        # else the DC operating voltage is underdetermined (the DC analog of needing
        # an AC slack). Master-slave / droop per MTDC practice.
        controlled = Set{String}()
        for (_, inv) in get(net, "ibr", Dict())
            inv isa Dict && haskey(inv, "dc_bus") || continue
            String(get(inv, "dc_control", "P")) in ("V", "droop") || continue
            b = get(inv, "dc_bus", "")
            b in dc_busset && push!(controlled, find(b))
        end
        for (root, members) in dc_islands
            root in controlled && continue
            push!(findings, Finding(ERROR, "E.INT.DC_NO_VOLTAGE_CONTROL", :integrity,
                :network, nothing,
                "DC island of $(length(members)) dc_bus(es) has no converter on " *
                "DC-voltage control (dc_control = \"V\" or \"droop\") — the DC " *
                "operating voltage is underdetermined. Designate a master/droop " *
                "converter: $(join(sort(members), ", ")).",
                Dict{String,Any}("dc_buses" => sort(members))))
        end
    end

    # --- wire_data / line_geometry references ---
    wire_ids = Set(keys(get(net, "wire_data", Dict())))
    for (id, geo) in get(net, "line_geometry", Dict())
        geo isa Dict || continue
        conds = get(geo, "conductors", nothing)
        conds isa AbstractVector || continue
        for (k, c) in enumerate(conds)
            c isa Dict || continue
            w = get(c, "wire_data", nothing)
            if w isa AbstractString && !(w in wire_ids)
                n_ref_issues += 1
                push!(findings, Finding(ERROR, "E.INT.UNKNOWN_WIRE_DATA", :integrity,
                    :line_geometry, id,
                    "line_geometry '$id' conductor $k references unknown " *
                    "wire_data '$w'.",
                    Dict{String,Any}("wire_data" => w, "conductor" => k)))
            end
        end
    end
    geo_ids = Set(keys(get(net, "line_geometry", Dict())))
    for (id, lc) in get(net, "linecode", Dict())
        lc isa Dict || continue
        g = get(lc, "line_geometry", nothing)
        if g isa AbstractString && !(g in geo_ids)
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.UNKNOWN_LINE_GEOMETRY", :integrity,
                :linecode, id,
                "Linecode '$id' references unknown line_geometry '$g'.",
                Dict{String,Any}("line_geometry" => g)))
        end
    end

    # --- linecode references + dimension consistency ---
    linecodes = get(net, "linecode", Dict())
    lc_dims = Dict{String,Int}()
    for (id, lc) in linecodes
        lc isa Dict || continue
        R = _pattern_keys_to_matrix(lc, "R_series_")
        R isa AbstractMatrix && (lc_dims[id] = size(R, 1))
    end

    n_dim_issues = 0

    n_dim_issues += _check_device_dimensions!(net, findings)

    z_tot = Dict{String,Float64}()   # per-line total series impedance proxy
    for (id, l) in get(net, "line", Dict())
        l isa Dict || continue
        lcid = get(l, "linecode", nothing)
        has_inline = _line_has_inline_z(l)

        # exactly one impedance source: linecode XOR inline absolute matrices
        if (lcid isa AbstractString) == has_inline
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.LINE_IMPEDANCE_SOURCE",
                :integrity, :line, id,
                has_inline ?
                    "Line '$id' has BOTH a linecode reference and inline " *
                    "R_series_/X_series_ matrices — ambiguous; a line carries " *
                    "exactly one impedance source." :
                    "Line '$id' has NO impedance source — provide either a " *
                    "`linecode` (+ `length`) or inline absolute " *
                    "R_series_/X_series_ matrices [Ω].",
                Dict{String,Any}("linecode" => lcid, "inline" => has_inline)))
            has_inline && continue
        end

        if has_inline
            # inline ABSOLUTE matrices: dimension check + direct z_tot (no ×length)
            R = _pattern_keys_to_matrix(l, "R_series_")
            X = _pattern_keys_to_matrix(l, "X_series_")
            R isa AbstractMatrix || continue
            n = size(R, 1)
            tmf=get(l,"terminal_map_from",nothing); tmt=get(l,"terminal_map_to",nothing)
            (_index_strings(tmf) && _index_strings(tmt)) || continue
            nf=length(tmf); nt=length(tmt)
            if nf != n || nt != n
                n_ref_issues += 1
                push!(findings, Finding(ERROR, "E.INT.LINE_DIM_MISMATCH", :integrity,
                    :line, id,
                    "Line '$id' has terminal maps of length ($nf, $nt) but its " *
                    "inline impedance matrix is $n×$n. Matrix row k is the " *
                    "impedance seen by terminal-map entry k, so the counts must " *
                    "match exactly; there is no meaningful truncation.",
                    merge(_line_connection_evidence(net,id,l),Dict{String,Any}("n" => n, "from" => nf, "to" => nt))))
            end
            z_tot[id] = maximum(hypot(R[i, i],
                                X isa AbstractMatrix && size(X) == size(R) ?
                                    X[i, i] : 0.0) for i in 1:n)
            continue
        end

        lcid isa AbstractString || continue
        if !haskey(linecodes, lcid)
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.UNKNOWN_LINECODE", :integrity,
                :line, id,
                "Line '$id' references unknown linecode '$lcid'.",
                Dict{String,Any}("linecode" => lcid)))
            continue
        end
        haskey(lc_dims, lcid) || continue
        n = lc_dims[lcid]
        tmf=get(l,"terminal_map_from",nothing); tmt=get(l,"terminal_map_to",nothing)
        (_index_strings(tmf) && _index_strings(tmt)) || continue
        nf=length(tmf); nt=length(tmt)
        if nf != n || nt != n
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.LINE_DIM_MISMATCH", :integrity,
                :line, id,
                "Line '$id' has terminal maps of length ($nf, $nt) but its " *
                "linecode '$lcid' is $n×$n. Matrix row k is the impedance seen " *
                "by terminal-map entry k, so the counts must match exactly — a " *
                "$n-conductor linecode belongs on a $n-terminal line. Silently " *
                "truncating to the shorter length (as some tools do) drops " *
                "conductors and mutual coupling, or misaligns matrix rows with " *
                "terminal roles, producing plausible-but-wrong results.",
                merge(_line_connection_evidence(net,id,l),Dict{String,Any}("linecode" => lcid, "n" => n,
                                 "from" => nf, "to" => nt))))
        end
        # total series impedance proxy: max self-resistance+reactance × length
        lc = linecodes[lcid]
        R = _pattern_keys_to_matrix(lc, "R_series_")
        X = _pattern_keys_to_matrix(lc, "X_series_")
        if R isa AbstractMatrix
            len = Float64(get(l, "length", 1.0))
            zd = maximum(hypot(R[i, i],
                               X isa AbstractMatrix && size(X) == size(R) ?
                                   X[i, i] : 0.0) for i in 1:size(R, 1))
            z_tot[id] = zd * len
        end
    end

    # i_max / s_max length vs conductor count (both are per-conductor)
    for (id, lc) in linecodes
        lc isa Dict || continue
        haskey(lc_dims, id) || continue
        for field in ("i_max", "s_max")
            v = get(lc, field, nothing)
            if v isa AbstractVector && length(v) != lc_dims[id]
                n_dim_issues += 1
                push!(findings, Finding(WARNING, "W.INT.DIM_MISMATCH", :integrity,
                    :linecode, id,
                    "Linecode '$id': $field has $(length(v)) entries but the " *
                    "impedance matrix is $(lc_dims[id])×$(lc_dims[id]).",
                    Dict{String,Any}("field" => field)))
            end
        end
    end

    # padded matrices: all-zero row+column pairs in R and X
    padded = String[]
    for (id, lc) in linecodes
        lc isa Dict || continue
        R = _pattern_keys_to_matrix(lc, "R_series_")
        R isa AbstractMatrix || continue
        n = size(R, 1)
        n > 1 || continue
        X = _pattern_keys_to_matrix(lc, "X_series_")
        Xm = (X isa AbstractMatrix && size(X) == size(R)) ? X : zeros(n, n)
        for i in 1:n
            row_zero = all(R[i, j] == 0 && Xm[i, j] == 0 for j in 1:n)
            col_zero = all(R[j, i] == 0 && Xm[j, i] == 0 for j in 1:n)
            if row_zero && col_zero
                push!(padded, id)
                break
            end
        end
    end
    if !isempty(padded)
        n_dim_issues += length(padded)
        push!(findings, Finding(WARNING, "W.INT.PADDED_MATRIX", :integrity,
            :linecode, nothing,
            "$(length(padded)) linecode(s) contain all-zero row/column pairs " *
            "— padded conductors slow NLP solvers substantially; shrink the " *
            "matrix and use terminal maps: $(join(sort(padded), ", ")).",
            Dict{String,Any}("linecodes" => sort(padded))))
    end

    # --- galvanic islands: voltage reference required per island ---
    src_buses = Set(get(vs, "bus", "") for (_, vs) in get(net, "voltage_source", Dict()))
    # One body of reference evidence for both tests below: a perfectly
    # grounded terminal, a source, a shunt or stamped line-shunt row to earth,
    # a transformer neutral impedance, a load written against earth with
    # nonzero demand. An island is referenced when one of its buses carries
    # such a tie; each conductor group then needs one of its own.
    reference = _conductor_reference(net)
    grounded_buses = reference.earthed_buses

    islands = _galvanic_islands(net)
    unreferenced = Vector{Vector{String}}()
    for comp in islands
        has_ref = any(b -> b in src_buses || b in grounded_buses, comp)
        has_ref || push!(unreferenced, comp)
    end
    result["n_galvanic_islands"]  = length(islands)
    result["n_without_reference"] = length(unreferenced)
    for comp in unreferenced
        push!(findings, Finding(ERROR, "E.INT.NO_VOLTAGE_REFERENCE", :integrity,
            :network, nothing,
            "Galvanic island of $(length(comp)) bus(es) has no voltage " *
            "reference (no source, perfect grounding, grounding shunt, line " *
            "shunt admittance, transformer neutral impedance, or load written " *
            "against earth) — " *
            "voltages are defined only up to a shift (rank-deficient): " *
            "$(join(comp, ", ")).",
            Dict{String,Any}("buses" => comp, "scope" => "island")))
    end

    # An island can hold a reference that does not reach every conductor: an
    # earth shunt on a separately carried neutral leaves delta-connected phases
    # free to shift together. Each conductor group needs its own tie.
    floating_buses = Set{String}(b for comp in unreferenced for b in comp)
    groups = [g for g in reference.groups
              if !all(n -> n[1] in floating_buses, g)]
    result["n_unreferenced_conductor_groups"] = length(groups)
    for g in groups
        group_buses = sort!(unique!([n[1] for n in g]))
        labels = ["$(n[1]).$(n[2])" for n in g]
        push!(findings, Finding(ERROR, "E.INT.NO_VOLTAGE_REFERENCE", :integrity,
            :network, nothing,
            "A group of $(length(g)) conductor terminal(s) on $(length(group_buses)) bus(es) " *
            "has no tie to the voltage reference, although its island has one elsewhere: no " *
            "element connects these conductors to the earthed ones, so they can shift " *
            "together (rank-deficient): $(join(first(labels, 8), ", "))" *
            "$(length(labels) > 8 ? ", …" : "").",
            Dict{String,Any}("buses" => group_buses, "scope" => "conductor_group",
                "terminals" => [Dict{String,Any}("bus" => n[1], "terminal" => n[2]) for n in g])))
    end

    # --- MVDC embedding: converters must land in a referenced AC system ---
    # An MVDC/LVDC subsystem is expected to be embedded within a referenced AC
    # network: every converter's AC bus should sit in an AC galvanic island that
    # carries its own AC voltage reference (source / grounding). A converter whose
    # AC bus is energized ONLY through the DC link — the dangling case
    # "AC system — converter — dc line — converter — bare bus" — is flagged,
    # unless that island hosts a grid-forming converter (which can set the AC
    # reference itself).
    if !isempty(dc_busset)
        island_of = Dict{String,Int}()
        for (i, comp) in enumerate(islands), b in comp
            island_of[b] = i
        end
        referenced = Set(i for (i, comp) in enumerate(islands)
                         if any(b -> b in src_buses || b in grounded_buses, comp))
        # AC islands made referenceable by a grid-forming converter.
        for (_, inv) in get(net, "ibr", Dict())
            inv isa Dict && get(inv, "grid_forming", false) === true || continue
            ab = get(inv, "bus", nothing)
            ab isa AbstractString && haskey(island_of, ab) &&
                push!(referenced, island_of[ab])
        end
        for (id, inv) in get(net, "ibr", Dict())
            inv isa Dict && haskey(inv, "dc_bus") || continue
            ab = get(inv, "bus", nothing)
            ab isa AbstractString && haskey(island_of, ab) || continue
            island_of[ab] in referenced && continue
            push!(findings, Finding(WARNING, "W.INT.DC_FED_AC_ISLAND", :integrity,
                :ibr, id,
                "Converter '$id' feeds AC bus '$ab', whose AC island has no AC " *
                "voltage reference (no source/grounding) and no grid-forming " *
                "converter — it is energized only through the MVDC link " *
                "(dangling / not embedded in a referenced AC system). If this is " *
                "an intentional DC-fed feeder, mark a converter grid_forming.",
                Dict{String,Any}("bus" => ab)))
        end
    end

    # --- wye without neutral ---
    case_roles = _index_roles(net)
    neutral_of = Dict(id => _index_bus_neutral(net,id,case_roles) for id in keys(buses))
    for comp_type in ("load", "generator")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            get(c, "configuration", "") == "WYE" || continue
            b = get(c, "bus", nothing)
            b isa AbstractString && b in busset || continue
            if get(neutral_of, b, nothing) === nothing
                push!(findings, Finding(WARNING, "W.INT.WYE_WITHOUT_NEUTRAL",
                    :integrity, Symbol(comp_type), id,
                    "$comp_type '$id' is wye-configured at bus '$b' which has " *
                    "no identifiable neutral — implies an undeclared ground " *
                    "return (in 3-wire sections only delta connections are " *
                    "expected).", nothing))
            end
        end
    end

    # --- floating load/generator terminals ---
    # A phase terminal that only appears in a load/generator terminal_map but
    # has no branch (line, switch, or transformer) on the same bus is physically
    # floating: KCL reduces to 0=0 there and the voltage variable is decoupled
    # from the rest of the network.  Neutrals are excluded (they are often
    # grounded implicitly).  Terminals at voltage-source buses are also excluded
    # (the source pins the voltage regardless of branch wiring).
    source_buses = Set(get(vs, "bus", "") for (_, vs) in get(net, "voltage_source", Dict())
                       if vs isa Dict)

    # Build bus → Set{terminal} wired by at least one branch end
    branch_terminals = Dict{String, Set{String}}()
    for comp_type in ("line", "switch")
        for (_, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            for (bus_field, tm_field) in (("bus_from","terminal_map_from"),
                                           ("bus_to",  "terminal_map_to"))
                b  = get(c, bus_field, nothing)
                tm = get(c, tm_field,  nothing)
                b isa AbstractString && tm isa AbstractVector || continue
                s = get!(branch_terminals, b, Set{String}())
                for t in tm; push!(s, string(t)); end
            end
        end
    end
    xfmr_sub = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr_sub, subtype, nothing)
        sub isa Dict || continue
        for (_, c) in sub
            c isa Dict || continue
            if subtype in WINDING_LIST_SUBTYPES
                # Winding terminals wire their buses too; omitting them made
                # n-winding-fed buses look like they had floating/unused terminals.
                for w in (get(c, "windings", nothing) isa AbstractVector ? c["windings"] : Any[])
                    w isa AbstractDict || continue
                    b  = get(w, "bus", nothing)
                    tm = get(w, "terminal_map", nothing)
                    b isa AbstractString && tm isa AbstractVector || continue
                    s = get!(branch_terminals, b, Set{String}())
                    for t in tm; push!(s, string(t)); end
                end
                continue
            end
            for (bus_field, tm_field) in (("bus_from","terminal_map_from"),
                                           ("bus_to",  "terminal_map_to"))
                b  = get(c, bus_field, nothing)
                tm = get(c, tm_field,  nothing)
                b isa AbstractString && tm isa AbstractVector || continue
                s = get!(branch_terminals, b, Set{String}())
                for t in tm; push!(s, string(t)); end
            end
        end
    end

    n_floating = 0
    for comp_type in ("load", "generator", "ibr")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            b = get(c, "bus", nothing)
            b isa AbstractString || continue
            b in source_buses && continue
            neutral = get(neutral_of, b, nothing)
            wired   = get(branch_terminals, b, Set{String}())
            raw_tm = get(c, "terminal_map", String[])
            _index_strings(raw_tm) || continue
            tm = string.(raw_tm)
            floating = [t for t in tm
                        if t != neutral &&
                           !(t in wired)]
            isempty(floating) && continue
            n_floating += 1
            push!(findings, Finding(WARNING, "W.INT.FLOATING_LOAD_TERMINAL",
                :integrity, Symbol(comp_type), id,
                "$comp_type '$id' at bus '$b' has phase terminal(s) $floating " *
                "that are not wired by any branch — the voltage at those " *
                "terminals is decoupled from the network (floating), making " *
                "KCL trivially satisfied and the load constraint degenerate.",
                Dict{String,Any}("bus" => b, "terminals" => floating)))
        end
    end
    result["n_floating_load_terminals"] = n_floating

    # --- unused bus terminals ---
    # A terminal declared in terminal_names but not referenced by any component
    # at that bus (branch end or nodal element) adds a free voltage variable
    # with no KCL constraint — pure numeric overhead and almost always a
    # conversion artifact or copy-paste error.
    # Voltage-source buses are excluded: the source pins every declared terminal
    # so unused declarations are harmless there.
    all_used_terminals = Dict{String, Set{String}}()
    for t_dict in (branch_terminals,)
        for (b, ts) in t_dict
            union!(get!(all_used_terminals, b, Set{String}()), ts)
        end
    end
    for comp_type in ("load", "generator", "shunt", "voltage_source", "ibr", "capacitor")
        for (_, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            b  = get(c, "bus", nothing)
            tm = get(c, "terminal_map", nothing)
            b isa AbstractString && tm isa AbstractVector || continue
            s = get!(all_used_terminals, b, Set{String}())
            for t in tm; push!(s, string(t)); end
        end
    end
    # A perfectly grounded terminal is pinned to zero volts: it is a declared
    # reference, not a free voltage variable, whether or not a component uses it.
    for (bus_id, bus) in buses
        bus isa Dict || continue
        pg = get(bus, "perfectly_grounded_terminals", nothing)
        pg isa AbstractVector || continue
        s = get!(all_used_terminals, bus_id, Set{String}())
        for t in pg; push!(s, string(t)); end
    end

    n_unused_bus_terminals = 0
    for (bus_id, bus) in buses
        bus isa Dict || continue
        bus_id in source_buses && continue
        declared = Set(string.(get(bus, "terminal_names", String[])))
        used     = get(all_used_terminals, bus_id, Set{String}())
        unused   = sort(collect(setdiff(declared, used)))
        isempty(unused) && continue
        n_unused_bus_terminals += 1
        push!(findings, Finding(WARNING, "W.INT.UNUSED_BUS_TERMINAL",
            :integrity, :bus, bus_id,
            "Bus '$bus_id' declares terminal(s) $unused in terminal_names " *
            "that are not referenced by any component at that bus — these " *
            "are free voltage variables with no KCL constraint; remove them " *
            "from terminal_names or verify the connection is not missing.",
            Dict{String,Any}("bus" => bus_id, "terminals" => unused)))
    end
    result["n_unused_bus_terminals"] = n_unused_bus_terminals

    # --- low-impedance lines + spread ---
    if length(z_tot) >= 3
        vals = collect(values(z_tot))
        med = median(vals)
        zmin, zmax = extrema(vals)
        result["impedance_spread"] = zmin > 0 ? zmax / zmin : Inf
        low = sort([id for (id, z) in z_tot if z < 1e-3 * med])
        if !isempty(low)
            push!(findings, Finding(WARNING, "W.INT.LOW_IMPEDANCE_LINE",
                :integrity, :line, nothing,
                "$(length(low)) line(s) have total series impedance below " *
                "10⁻³× the network median — they degrade NLP conditioning; " *
                "model them as lossless switches: $(join(low, ", ")).",
                Dict{String,Any}("lines" => low)))
        end
        result["n_low_impedance_lines"] = length(low)
    end

    # --- generator cost symmetry ---
    cost_groups = Dict{String,Vector{String}}()
    for (id, g) in get(net, "generator", Dict())
        g isa Dict || continue
        haskey(g, "cost") || continue
        c = g["cost"]
        _index_numbers(c) || continue # shape finding above owns malformed costs
        key = c isa AbstractVector ? join(Float64.(c), ",") : string(Float64(c))
        push!(get!(cost_groups, key, String[]), id)
    end
    dup_groups = [sort(ids) for (_, ids) in cost_groups if length(ids) > 1]
    if !isempty(dup_groups)
        push!(findings, Finding(INFO, "I.INT.UNIFORM_GEN_COST", :integrity,
            :generator, nothing,
            "$(length(dup_groups)) group(s) of generators share identical " *
            "costs — dispatch between them is degenerate (any split is " *
            "optimal); diversify costs for benchmark use.",
            Dict{String,Any}("groups" => dup_groups)))
    end

    _power_factor_config_check!(net, findings)
    result["n_reference_issues"] = n_ref_issues
    result["n_dimension_issues"] = n_dim_issues
    _check_ideal_topology!(net, findings)

    result
end

# Validate a control_profile's Volt-var / Volt-watt droop sub-objects: shape and
# monotonicity of the breakpoint encoding, sign conventions, mutual exclusivity
# with constant-PF, and the option subset the OPF builder currently supports.
function _check_droop_profile!(findings::Vector{Finding}, cp_id, cp::Dict)
    has_pf = get(cp, "power_factor", nothing) isa Dict
    vv = get(cp, "volt_var",  nothing)
    vw = get(cp, "volt_watt", nothing)

    if has_pf && (vv isa Dict || vw isa Dict)
        push!(findings, Finding(ERROR, "E.INT.CONTROL_PROFILE_CONFLICT", :integrity,
            :control_profile, cp_id,
            "control_profile '$cp_id' declares both power_factor and Volt-var/" *
            "Volt-watt; these are mutually exclusive.",
            Dict{String,Any}()))
    end

    _strictly_increasing(xs) =
        length(xs) >= 2 && all(xs[i+1] > xs[i] for i in 1:length(xs)-1)

    if vv isa Dict
        bps = Float64.(get(vv, "breakpoints", Float64[]))
        ql  = Float64.(get(vv, "q_limits",    Float64[]))
        if length(bps) != 4 || length(ql) != 2
            push!(findings, Finding(ERROR, "E.INT.VOLT_VAR_SHAPE", :integrity,
                :control_profile, cp_id,
                "volt_var in '$cp_id' needs 4 breakpoints and 2 q_limits; got " *
                "$(length(bps)) and $(length(ql)).", Dict{String,Any}()))
        else
            _strictly_increasing(bps) || push!(findings, Finding(ERROR,
                "E.INT.VOLT_VAR_BREAKPOINTS", :integrity, :control_profile, cp_id,
                "volt_var breakpoints in '$cp_id' must be strictly increasing.",
                Dict{String,Any}()))
            (ql[1] <= 0 <= ql[2]) || push!(findings, Finding(WARNING,
                "W.INT.VOLT_VAR_QLIMITS", :integrity, :control_profile, cp_id,
                "volt_var q_limits in '$cp_id' expected [absorb≤0, inject≥0]; " *
                "got $(ql).", Dict{String,Any}()))
        end
        _check_droop_options!(findings, cp_id, "volt_var", vv,
            "q_unit", "VA_FRACTION", "q_ref", "VAR_MAX")
    end

    if vw isa Dict
        bps = Float64.(get(vw, "breakpoints", Float64[]))
        pl  = Float64.(get(vw, "p_limits",    Float64[]))
        if length(bps) != 2 || length(pl) != 2
            push!(findings, Finding(ERROR, "E.INT.VOLT_WATT_SHAPE", :integrity,
                :control_profile, cp_id,
                "volt_watt in '$cp_id' needs 2 breakpoints and 2 p_limits; got " *
                "$(length(bps)) and $(length(pl)).", Dict{String,Any}()))
        else
            _strictly_increasing(bps) || push!(findings, Finding(ERROR,
                "E.INT.VOLT_WATT_BREAKPOINTS", :integrity, :control_profile, cp_id,
                "volt_watt breakpoints in '$cp_id' must be strictly increasing.",
                Dict{String,Any}()))
        end
        _check_droop_options!(findings, cp_id, "volt_watt", vw,
            "p_unit", "VA_FRACTION", "p_ref", nothing)
    end
end

# Reject option values outside the subset the OPF builder currently supports, so
# unsupported configs fail loudly rather than silently mis-solving. `ref_ok`
# being `nothing` means any value of the ref field is accepted (volt_watt p_ref).
function _check_droop_options!(findings, cp_id, law, obj,
                               unit_field, unit_ok, ref_field, ref_ok)
    vref = get(obj, "voltage_reference", "PN_PER_PHASE")
    vref in ("PN_PER_PHASE", "PG_PER_PHASE", "PP_PER_PHASE",
             "PN_AVERAGED", "PG_AVERAGED", "PP_AVERAGED") || push!(findings, Finding(ERROR,
        "E.INT.DROOP_UNSUPPORTED", :integrity, :control_profile, cp_id,
        "$law in '$cp_id': voltage_reference '$vref' is not a valid " *
        "voltage_reference_type value.", Dict{String,Any}()))
    unit = get(obj, unit_field, unit_ok)
    unit == unit_ok || push!(findings, Finding(ERROR,
        "E.INT.DROOP_UNSUPPORTED", :integrity, :control_profile, cp_id,
        "$law in '$cp_id': $unit_field '$unit' not yet supported (only $unit_ok).",
        Dict{String,Any}()))
    if ref_ok !== nothing
        rv = get(obj, ref_field, ref_ok)
        rv == ref_ok || push!(findings, Finding(ERROR,
            "E.INT.DROOP_UNSUPPORTED", :integrity, :control_profile, cp_id,
            "$law in '$cp_id': $ref_field '$rv' not yet supported (only $ref_ok).",
            Dict{String,Any}()))
    end
end

"""
    _check_ideal_topology!(net, findings)

Report ideal-coupling defects that leave a model without a unique solution, or
with no solution at all, before any model is built: loops of ideal conductors
(AC and DC) and contradictory DC voltage references. The OPF builders raise on
exactly what these detectors return (`src/validation/ideal_topology.jl`).
"""
function _check_ideal_topology!(net::Dict{String,Any}, findings::Vector{Finding})
    # Collections that are not objects are a schema defect reported elsewhere.
    all(k -> get(net, k, Dict()) isa AbstractDict,
        ("bus", "line", "switch", "dc_bus", "dc_branch", "dc_grounding", "ibr")) ||
        return nothing
    ac_references = _ac_reference_terminals(net)
    removable = Set((c.element, c.id, c.conductor) for c in _ac_earthed_ideal_conductors(net))
    for loop in _ac_ideal_loops(net)
        between = loop.from in ac_references && loop.to in ac_references
        fixable = (loop.element, loop.id, loop.conductor) in removable
        is_xfmr = loop.element == "transformer"
        text = if is_xfmr
            "transformer '$(loop.id)' winding $(loop.conductor) is ideal (zero leakage " *
            "impedance) and its voltage relation between $(loop.from[1]).$(loop.from[2]) " *
            "and $(loop.to[1]).$(loop.to[2]) is already implied by other ideal elements " *
            "or fixed voltages: another ideal transformer in parallel, a closed switch " *
            "or zero-impedance line across it, or fixed voltages on both sides. The " *
            "current through it is undetermined; supply its leakage impedance or " *
            "remove the parallel ideal path."
        else
            "$(loop.element) '$(loop.id)' conductor $(loop.conductor) closes a loop of " *
            "ideal (zero-impedance) conductors between $(loop.from[1]).$(loop.from[2]) " *
            "and $(loop.to[1]).$(loop.to[2])" *
            (between ?
                ": both terminals are held at a fixed voltage (perfect grounds or source " *
                "terminals), so the conductor's voltage relation only repeats data, and " *
                "the loop closes through the earth or the source, where the injection " *
                "is free." :
                ": its voltage relation is implied by the others and a current can " *
                "circulate around the loop undetermined.") *
            (fixable ? " Both ends are earthed, so the conductor is redundant; " *
                       "`fix_case` removes it." : "")
        end
        push!(findings, Finding(ERROR, "E.INT.IDEAL_LOOP", :integrity,
            Symbol(loop.element), loop.id, text,
            Dict{String,Any}("element"=>loop.element, "conductor"=>loop.conductor,
                "bus_from"=>loop.from[1], "terminal_from"=>loop.from[2],
                "bus_to"=>loop.to[1], "terminal_to"=>loop.to[2],
                "between_references"=>between,
                "closes_through_reference"=>
                    (loop.from in ac_references || loop.to in ac_references),
                "removable_by_fix_case"=>fixable,
                "remedy"=>fixable ? "remove_earthed_ideal_conductor" :
                    is_xfmr ? "supply_transformer_leakage_impedance" :
                    (between && !fixable) ? "keep_one_voltage_reference_or_supply_impedance" :
                    "remove_redundant_ideal_conductor_or_supply_impedance")))
    end
    haskey(net, "dc_bus") || return nothing
    dc_grounded = _dc_grounded_terminals(net)
    for loop in _dc_ideal_loops(net)
        push!(findings, Finding(ERROR, "E.INT.DC_IDEAL_LOOP", :integrity,
            :dc_branch, loop.branch,
            "dc_branch '$(loop.branch)' conductor $(loop.conductor) closes a loop of " *
            "ideal (zero-resistance) DC conductors between $(loop.from[1]).$(loop.from[2]) " *
            "and $(loop.to[1]).$(loop.to[2]): its voltage relation is implied by the " *
            "others and a current can circulate around the loop undetermined.",
            Dict{String,Any}("conductor"=>loop.conductor,
                "dc_bus_from"=>loop.from[1], "terminal_from"=>loop.from[2],
                "dc_bus_to"=>loop.to[1], "terminal_to"=>loop.to[2],
                "closes_through_reference"=>
                    (loop.from in dc_grounded || loop.to in dc_grounded),
                "remedy"=>"remove_redundant_ideal_conductor_or_supply_resistance")))
    end
    for conflict in _dc_reference_conflicts(net)
        master = conflict.kind == :voltage_master
        conductor = conflict.kind == :ideal_conductor
        pair = conflict.kind == :exact_pair_bound
        push!(findings, Finding(ERROR, "E.INT.DC_REFERENCE_CONFLICT", :integrity,
            master ? :ibr : conductor ? :dc_branch : :dc_bus,
            master ? conflict.owner : conductor ? String(first(split(conflict.owner, "."))) :
                conflict.from[1],
            (master ?
                "IBR '$(conflict.owner)' (dc_control=\"V\") sets $(conflict.stated) V " *
                "across its DC port" :
             conductor ?
                "Ideal dc_branch conductor $(conflict.owner) holds its two ends at one voltage" :
             pair ?
                "The exact $(conflict.owner) sets $(conflict.stated) V" :
                "DC terminal $(conflict.owner) is fixed at $(conflict.stated) V") *
            ", but the voltage references already in the case (terminals fixed by " *
            "grounding or equal bounds, ideal conductors, other voltage masters) fix " *
            "that difference at $(conflict.implied) V.",
            Dict{String,Any}("kind"=>String(conflict.kind), "owner"=>conflict.owner,
                "stated_V"=>conflict.stated, "implied_V"=>conflict.implied,
                "dc_bus"=>conflict.from[1], "terminal"=>conflict.from[2])))
    end
    return nothing
end
