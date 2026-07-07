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

# Validate a per-CONDUCTOR `i_max` vector for a star/single-phase/delta device
# (generator or IBR). Returns the number of hard dimension issues (0/1) and may
# also append a soft `W.INT.IMAX_NO_NEUTRAL` recommendation. Rules:
#   • no neutral (delta / phase-to-phase)  → exactly `n_phase` (one per conductor);
#   • single-phase (`n_phase == 1`)        → 1 or 2 (phase ≡ return, one current);
#   • ≥2-phase star                        → `n_phase+1` (standard, phases+neutral),
#                                            or `n_phase` (warns: neutral unrated).
function _check_conductor_imax!(findings::Vector{Finding}, ctype::Symbol,
                                label::AbstractString, id, v,
                                n_phase::Int, has_neutral::Bool)::Int
    v isa AbstractVector || return 0
    L = length(v)
    if !has_neutral
        L == n_phase && return 0
        push!(findings, Finding(WARNING, "W.INT.DIM_MISMATCH", :integrity, ctype, id,
            "$label '$id': i_max has $L entries; expected $n_phase (one per conductor).",
            Dict{String,Any}("field" => "i_max", "n_phase" => n_phase)))
        return 1
    elseif n_phase == 1
        L in (1, 2) && return 0
        push!(findings, Finding(WARNING, "W.INT.DIM_MISMATCH", :integrity, ctype, id,
            "$label '$id': single-phase i_max has $L entries; expected 1 or 2.",
            Dict{String,Any}("field" => "i_max", "n_phase" => n_phase)))
        return 1
    else
        L == n_phase + 1 && return 0
        if L == n_phase
            push!(findings, Finding(WARNING, "W.INT.IMAX_NO_NEUTRAL", :integrity, ctype, id,
                "$label '$id': i_max has $n_phase entries (phases only); add a " *
                "$(n_phase + 1)-th entry to rate the neutral conductor, which can carry " *
                "more current than the phases under unbalance compensation.",
                Dict{String,Any}("field" => "i_max", "n_phase" => n_phase)))
            return 0
        end
        push!(findings, Finding(WARNING, "W.INT.DIM_MISMATCH", :integrity, ctype, id,
            "$label '$id': i_max has $L entries; expected $n_phase (phases) or " *
            "$(n_phase + 1) (phases + neutral).",
            Dict{String,Any}("field" => "i_max", "n_phase" => n_phase)))
        return 1
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

    terminal_set(b) = Set(string.(get(get(buses, b, Dict()),
                                      "terminal_names", String[])))

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

    check_tmap(comp_type, id, bus, tm) = begin
        bad = [t for t in string.(tm) if !(t in terminal_set(bus))]
        if !isempty(bad)
            n_ref_issues += 1
            push!(findings, Finding(ERROR, "E.INT.UNKNOWN_TERMINAL", :integrity,
                Symbol(comp_type), id,
                "$comp_type '$id' terminal map references terminal(s) " *
                "$(bad) not defined at bus '$bus'.",
                Dict{String,Any}("bus" => bus, "terminals" => bad)))
        end
    end

    # --- referential integrity: branch elements ---
    for comp_type in ("line", "switch")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
            f isa AbstractString && check_bus_ref(comp_type, id, f) &&
                check_tmap(comp_type, id, f, get(c, "terminal_map_from", String[]))
            t isa AbstractString && check_bus_ref(comp_type, id, t) &&
                check_tmap(comp_type, id, t, get(c, "terminal_map_to", String[]))
        end
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, c) in sub
            c isa Dict || continue
            if subtype in WINDING_LIST_SUBTYPES
                # Winding-list buses/terminal_maps live in windings[]; a fixed
                # bus_from/bus_to check skips them, so dangling references were
                # never caught for n_winding.
                for w in get(c, "windings", Any[])
                    w isa AbstractDict || continue
                    b = get(w, "bus", nothing)
                    b isa AbstractString && check_bus_ref("transformer", id, b) &&
                        check_tmap("transformer", id, b, get(w, "terminal_map", String[]))
                end
                continue
            end
            f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
            f isa AbstractString && check_bus_ref("transformer", id, f) &&
                check_tmap("transformer", id, f, get(c, "terminal_map_from", String[]))
            t isa AbstractString && check_bus_ref("transformer", id, t) &&
                check_tmap("transformer", id, t, get(c, "terminal_map_to", String[]))
        end
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

    # ibr per-phase filter/cost vectors must match phase count = |terminal_map| - 1
    for (id, inv) in get(net, "ibr", Dict())
        inv isa Dict || continue
        tm_i = Vector{String}(get(inv, "terminal_map", String[]))
        # Phase count is set by the topology, not length(tm) - 1 (which assumes a
        # neutral): a THREE_LEG (delta) IBR carries |tm| phase currents, so
        # correct 3-entry per-phase vectors must NOT be flagged as mismatched.
        n_phase, has_n = _ibr_phase_count(get(inv, "topology", "FOUR_LEG"), tm_i)
        n_phase < 1 && continue
        for field in ("r_filter", "x_filter", "cost", "s_max")
            v = get(inv, field, nothing)
            if v isa AbstractVector && length(v) != n_phase
                n_dim_issues += 1
                push!(findings, Finding(WARNING, "W.INT.DIM_MISMATCH", :integrity,
                    :ibr, id,
                    "IBR '$id': $field has $(length(v)) entries but the " *
                    "topology implies $n_phase phase(s).",
                    Dict{String,Any}("field" => field, "n_phase" => n_phase)))
            end
        end
        # i_max is per CONDUCTOR; topology sets phase count and neutral presence.
        n_dim_issues += _check_conductor_imax!(findings, :ibr, "IBR", id,
            get(inv, "i_max", nothing), n_phase, has_n)
    end

    # generator per-phase vectors must match the phase-conductor count, which is
    # configuration-dependent: DELTA carries one current per conductor (|tm|),
    # WYE/SINGLE_PHASE one per non-neutral phase (|tm| minus the neutral).
    for (id, gen) in get(net, "generator", Dict())
        gen isa Dict || continue
        tm = get(gen, "terminal_map", String[])
        is_delta = get(gen, "configuration", "WYE") == "DELTA"
        n_phase = is_delta ? length(tm) : length(_phase_positions(tm))
        n_phase < 1 && continue
        for field in ("p_min", "p_max", "q_min", "q_max", "cost", "s_max")
            v = get(gen, field, nothing)
            if v isa AbstractVector && length(v) != n_phase
                n_dim_issues += 1
                push!(findings, Finding(WARNING, "W.INT.DIM_MISMATCH", :integrity,
                    :generator, id,
                    "Generator '$id': $field has $(length(v)) entries but the " *
                    "terminal map implies $n_phase phase(s).",
                    Dict{String,Any}("field" => field, "n_phase" => n_phase)))
            end
        end
        # i_max is per CONDUCTOR; a star generator may rate its neutral too.
        let has_neutral = !is_delta && _neutral_pos(tm) !== nothing
            n_dim_issues += _check_conductor_imax!(findings, :generator, "Generator",
                id, get(gen, "i_max", nothing), n_phase, has_neutral)
        end
    end

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
            nf = length(get(l, "terminal_map_from", String[]))
            nt = length(get(l, "terminal_map_to",   String[]))
            if nf != n || nt != n
                n_ref_issues += 1
                push!(findings, Finding(ERROR, "E.INT.LINE_DIM_MISMATCH", :integrity,
                    :line, id,
                    "Line '$id' has terminal maps of length ($nf, $nt) but its " *
                    "inline impedance matrix is $n×$n. Matrix row k is the " *
                    "impedance seen by terminal-map entry k, so the counts must " *
                    "match exactly; there is no meaningful truncation.",
                    Dict{String,Any}("n" => n, "from" => nf, "to" => nt)))
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
        nf = length(get(l, "terminal_map_from", String[]))
        nt = length(get(l, "terminal_map_to",   String[]))
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
                Dict{String,Any}("linecode" => lcid, "n" => n,
                                 "from" => nf, "to" => nt)))
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

    # load setpoint length vs configuration; source vm/va lengths
    for (id, l) in get(net, "load", Dict())
        l isa Dict || continue
        cfg = get(l, "configuration", nothing)
        expected = cfg == "SINGLE_PHASE" ? 1 :
                   cfg in ("WYE", "DELTA") ? 3 : nothing
        expected === nothing && continue
        for field in ("p_nom", "q_nom")
            v = get(l, field, nothing)
            if v isa AbstractVector && length(v) != expected
                n_dim_issues += 1
                push!(findings, Finding(WARNING, "W.INT.DIM_MISMATCH", :integrity,
                    :load, id,
                    "Load '$id' ($cfg): $field has $(length(v)) entries, " *
                    "expected $expected.", nothing))
            end
        end
    end
    for (id, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        ntm = length(get(vs, "terminal_map", String[]))
        ntm == 0 && continue
        for field in ("v_magnitude", "v_angle")
            v = get(vs, field, nothing)
            if v isa AbstractVector && length(v) != ntm
                n_dim_issues += 1
                push!(findings, Finding(WARNING, "W.INT.DIM_MISMATCH", :integrity,
                    :voltage_source, id,
                    "Voltage source '$id': $field has $(length(v)) entries " *
                    "but the terminal map has $ntm.", nothing))
            end
        end
    end

    # --- galvanic islands: voltage reference required per island ---
    src_buses = Set(get(vs, "bus", "") for (_, vs) in get(net, "voltage_source", Dict()))
    grounded_buses = Set{String}()
    for (id, b) in buses
        isempty(get(b, "perfectly_grounded_terminals", String[])) ||
            push!(grounded_buses, id)
    end
    # a shunt grounds its bus iff its admittance has nonzero row sums
    # (a pure delta capacitor bank has zero row sums — no ground current)
    for (_, s) in get(net, "shunt", Dict())
        b = get(s, "bus", nothing)
        b isa AbstractString || continue
        G = _pattern_keys_to_matrix(s, "G_")
        B = _pattern_keys_to_matrix(s, "B_")
        Y = G isa AbstractMatrix ? complex.(G,
                (B isa AbstractMatrix && size(B) == size(G)) ? B : zero(G)) :
            B isa AbstractMatrix ? complex.(zero(B), B) : nothing
        Y === nothing && continue
        scaleY = max(maximum(abs.(Y)), 1e-300)
        any(abs(sum(Y[i, :])) > 1e-9 * scaleY for i in 1:size(Y, 1)) &&
            push!(grounded_buses, b)
    end

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
            "reference (no source, perfect grounding, or grounding shunt) — " *
            "voltages are defined only up to a shift (rank-deficient): " *
            "$(join(comp, ", ")).",
            Dict{String,Any}("buses" => comp)))
    end

    # --- MVDC embedding: converters must land in a referenced AC system ---
    # An MVDC/LVDC subsystem is expected to be embedded within a referenced AC
    # network: every converter's AC bus should sit in an AC galvanic island that
    # carries its own AC voltage reference (source / grounding). A converter whose
    # AC bus is energised ONLY through the DC link — the dangling case
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
                "converter — it is energised only through the MVDC link " *
                "(dangling / not embedded in a referenced AC system). If this is " *
                "an intentional DC-fed feeder, mark a converter grid_forming.",
                Dict{String,Any}("bus" => ab)))
        end
    end

    # --- wye without neutral ---
    neutral_of = _bus_neutral_map(buses)
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
                for w in get(c, "windings", Any[])
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
            tm = string.(get(c, "terminal_map", String[]))
            floating = [t for t in tm
                        if t != neutral &&
                           lowercase(t) != "n" &&
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
    for comp_type in ("load", "generator", "shunt", "voltage_source", "ibr")
        for (_, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            b  = get(c, "bus", nothing)
            tm = get(c, "terminal_map", nothing)
            b isa AbstractString && tm isa AbstractVector || continue
            s = get!(all_used_terminals, b, Set{String}())
            for t in tm; push!(s, string(t)); end
        end
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

    result["n_reference_issues"] = n_ref_issues
    result["n_dimension_issues"] = n_dim_issues
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
