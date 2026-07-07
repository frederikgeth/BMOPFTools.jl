# network/simplify.jl
#
# Topology simplification transforms on BMOPF network dicts.
#
# All public functions return a deep-copied modified network. Outcomes are
# recorded in `net["_simplification_log"]` as plain Dicts so callers can
# inspect, filter, or serialise them without additional types.
#
# Log entry schema:
#   "operation"    — which function produced this entry
#   "code"         — machine-readable event type (see catalogue below)
#   "severity"     — "info" | "warning"
#   "element_type" — "line" | "bus" | "switch"
#   "element_id"   — the specific element id (or nothing)
#   "message"      — human-readable description
#   "detail"       — optional Dict with structured extras
#
# Event code catalogue:
#   LINES_MERGED              info    merge_series_lines     two lines fused
#   LINECODE_MISMATCH         info    merge_series_lines     adjacent linecodes differ — not merged
#   TERMINAL_MISMATCH         warning merge_series_lines     terminal maps at shared bus differ — not merged
#   SWITCH_IN_CHAIN           warning merge_series_lines     switch blocks a same-linecode chain (likely user error)
#   NON_LINE_ON_BUS           info    merge_series_lines     load/shunt/etc. blocks merge at intermediate bus
#   GROUNDED_BUS              warning merge_series_lines /    bus has grounded terminals — merge/prune would drop the ground
#                                     remove_dangling_lines
#   PARALLEL_LINES            info    merge_series_lines     two lines form a parallel pair (A—B—A), not a series chain
#   LINE_REMOVED              info    remove_dangling_lines  stub line and leaf bus removed
#   SHUNT_DROPPED             warning remove_dangling_lines  pruned stub carried shunt-to-earth — feasible set may change
#   SWITCH_REMOVED            info    remove_open_switches   open switch element deleted
#   ISOLATED_BUS              warning remove_open_switches   bus has no connections after switch removal
#   SWITCH_COLLAPSED          info    collapse_closed_switches bus pair merged via closed switch
#   SWITCH_LIMIT_DROPPED      warning collapse_closed_switches collapsed switch carried an i_max/s_max — cut vanishes, limit lost
#   BOUND_DROPPED             warning collapse_closed_switches a merged bound could not be carried across the collapse
#   MERGE_CONFLICT_TERMINALS  warning collapse_closed_switches terminal-map cross-phase/partial mismatch — not collapsed
#   MERGE_CONFLICT_SOURCE     warning collapse_closed_switches both buses have voltage sources — not collapsed

# ── Internal helpers ───────────────────────────────────────────────────────────

function _simlog!(net, operation, code, severity, element_type, element_id, message;
                  detail=nothing)
    entry = Dict{String,Any}(
        "operation"    => operation,
        "code"         => code,
        "severity"     => severity,
        "element_type" => element_type,
        "element_id"   => element_id,
        "message"      => message,
    )
    detail !== nothing && (entry["detail"] = detail)
    push!(get!(net, "_simplification_log", Any[]), entry)
end

# Non-line, non-switch, non-transformer element categories that attach to a
# single bus via a `"bus"` field. `ibr` and `capacitor` are first-class
# categories and must be included alongside loads/generators/shunts/sources.
const _BUS_ATTACHED_COMPONENTS =
    ("load", "generator", "shunt", "voltage_source", "ibr", "capacitor")

# Every bus a transformer references, across both the two-bus subtypes
# (`bus_from`/`bus_to`) and the winding-list subtypes (`windings[].bus`). Read
# only — see `_redirect_bus!` for the mutating winding path.
function _xfmr_bus_refs(subtype, t)
    if subtype in WINDING_LIST_SUBTYPES
        return String[w.bus for w in _nw_windings(t) if !isempty(w.bus)]
    end
    bs = String[]
    for b in (get(t, "bus_from", nothing), get(t, "bus_to", nothing))
        b isa AbstractString && push!(bs, b)
    end
    bs
end

# Returns (line_count, nonline_count, lines_at) for all buses.
# line_count[b]    = number of lines referencing bus b
# nonline_count[b] = number of non-line elements at bus b
#                    (loads, generators, shunts, voltage_sources, ibrs,
#                     capacitors, switches, transformers)
# lines_at[b]      = vector of line ids referencing bus b
function _bus_connectivity(net)
    buses        = get(net, "bus",  Dict())
    line_count   = Dict{String,Int}(id => 0 for id in keys(buses))
    nonline_count = Dict{String,Int}(id => 0 for id in keys(buses))
    lines_at     = Dict{String,Vector{String}}()

    for (lid, l) in get(net, "line", Dict())
        for b in (get(l, "bus_from", nothing), get(l, "bus_to", nothing))
            b isa AbstractString && haskey(line_count, b) || continue
            line_count[b] += 1
            push!(get!(lines_at, b, String[]), lid)
        end
    end

    for comp in _BUS_ATTACHED_COMPONENTS
        for (_, c) in get(net, comp, Dict())
            b = get(c, "bus", nothing)
            b isa AbstractString && haskey(nonline_count, b) && (nonline_count[b] += 1)
        end
    end
    for (_, sw) in get(net, "switch", Dict())
        for b in (get(sw, "bus_from", nothing), get(sw, "bus_to", nothing))
            b isa AbstractString && haskey(nonline_count, b) && (nonline_count[b] += 1)
        end
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (_, t) in sub
            for b in _xfmr_bus_refs(subtype, t)
                haskey(nonline_count, b) && (nonline_count[b] += 1)
            end
        end
    end

    line_count, nonline_count, lines_at
end

# True if any element in the network references bus_id.
function _bus_has_connections(net, bus_id)
    for (_, l) in get(net, "line", Dict())
        (get(l, "bus_from", nothing) == bus_id ||
         get(l, "bus_to",   nothing) == bus_id) && return true
    end
    for comp in _BUS_ATTACHED_COMPONENTS
        for (_, c) in get(net, comp, Dict())
            get(c, "bus", nothing) == bus_id && return true
        end
    end
    for (_, sw) in get(net, "switch", Dict())
        (get(sw, "bus_from", nothing) == bus_id ||
         get(sw, "bus_to",   nothing) == bus_id) && return true
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (_, t) in sub
            bus_id in _xfmr_bus_refs(subtype, t) && return true
        end
    end
    false
end

# Rewrite every reference to old_bus as new_bus across all element types.
function _redirect_bus!(net, old_bus, new_bus)
    for (_, l) in get(net, "line", Dict())
        get(l, "bus_from", nothing) == old_bus && (l["bus_from"] = new_bus)
        get(l, "bus_to",   nothing) == old_bus && (l["bus_to"]   = new_bus)
    end
    for comp in _BUS_ATTACHED_COMPONENTS
        for (_, c) in get(net, comp, Dict())
            get(c, "bus", nothing) == old_bus && (c["bus"] = new_bus)
        end
    end
    for (_, sw) in get(net, "switch", Dict())
        get(sw, "bus_from", nothing) == old_bus && (sw["bus_from"] = new_bus)
        get(sw, "bus_to",   nothing) == old_bus && (sw["bus_to"]   = new_bus)
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (_, t) in sub
            if subtype in WINDING_LIST_SUBTYPES
                # Winding-list subtypes carry buses inside `windings[].bus`;
                # mutate the raw dicts (the `_nw_windings` view is a copy).
                for w in get(t, "windings", Any[])
                    w isa AbstractDict && get(w, "bus", nothing) == old_bus &&
                        (w["bus"] = new_bus)
                end
            else
                get(t, "bus_from", nothing) == old_bus && (t["bus_from"] = new_bus)
                get(t, "bus_to",   nothing) == old_bus && (t["bus_to"]   = new_bus)
            end
        end
    end
end

# True if the line carries any non-zero π-shunt admittance to earth, either
# inline (`G_from_*`/`B_from_*`/`G_to_*`/`B_to_*` on the line, in siemens) or via
# its linecode (per-metre `G_*`/`B_*` that the model scales by `length`). A stub
# with shunt is a shunt capacitor/conductance to earth: dropping it removes an
# injection from the surviving bus's balance and can move the feasible set.
function _line_has_shunt(net, line)::Bool
    _shunt_prefix(k) = startswith(k, "G_from_") || startswith(k, "B_from_") ||
                       startswith(k, "G_to_")   || startswith(k, "B_to_")
    for (k, v) in line
        _shunt_prefix(k) && v isa Number && !iszero(v) && return true
    end
    lcid = get(line, "linecode", nothing)
    lcid isa AbstractString || return false
    lc = get(get(net, "linecode", Dict()), lcid, nothing)
    lc isa Dict || return false
    for (k, v) in lc
        _shunt_prefix(k) && v isa Number && !iszero(v) && return true
    end
    false
end

# ── Mutating implementation functions ─────────────────────────────────────────

function _merge_series_lines!(net)
    warned_buses = Set{String}()  # suppress duplicate warnings across iterations
    changed = true
    while changed
        changed = false
        line_count, nonline_count, lines_at = _bus_connectivity(net)
        lines = get(net, "line", Dict())

        for bus_id in keys(get(net, "bus", Dict()))
            get(line_count, bus_id, 0) == 2 || continue

            lids = get(lines_at, bus_id, String[])
            length(lids) == 2 || continue

            # Strict block: any non-line element on this bus prevents merging.
            if get(nonline_count, bus_id, 0) > 0
                bus_id in warned_buses && continue
                push!(warned_buses, bus_id)
                has_switch = any(
                    get(sw, "bus_from", nothing) == bus_id ||
                    get(sw, "bus_to",   nothing) == bus_id
                    for (_, sw) in get(net, "switch", Dict())
                )
                if has_switch
                    _simlog!(net, "merge_series_lines", "SWITCH_IN_CHAIN", "warning",
                        "bus", bus_id,
                        "Merge of same-linecode lines $(lids[1]) and $(lids[2]) at bus $bus_id " *
                        "blocked by a switch — possible user error (switch in the middle of a cable run).",
                        detail=Dict("lines" => lids))
                else
                    _simlog!(net, "merge_series_lines", "NON_LINE_ON_BUS", "info",
                        "bus", bus_id,
                        "Merge blocked: intermediate bus $bus_id has non-line elements attached.",
                        detail=Dict("lines" => lids))
                end
                continue
            end

            # Grounded pass-through buses are electrically meaningful: a modelled
            # ground (e.g. a multi-grounded neutral point) fixes terminal voltages
            # and would be silently lost if the bus were deleted. Block the merge.
            bus_obj = get(get(net, "bus", Dict()), bus_id, nothing)
            grounded = bus_obj isa Dict ?
                String.(get(bus_obj, "perfectly_grounded_terminals", String[])) : String[]
            if !isempty(grounded)
                bus_id in warned_buses && continue
                push!(warned_buses, bus_id)
                _simlog!(net, "merge_series_lines", "GROUNDED_BUS", "warning",
                    "bus", bus_id,
                    "Merge of lines $(lids[1]) and $(lids[2]) blocked: intermediate bus " *
                    "$bus_id has grounded terminals $(grounded) — a modelled ground is " *
                    "electrically meaningful and would be lost by the merge.",
                    detail=Dict("lines" => lids, "grounded_terminals" => grounded))
                continue
            end

            l1_id, l2_id = lids[1], lids[2]
            # A self-loop line registers twice at its bus and would satisfy the
            # two-line gate with l1 ≡ l2; "merging" it would delete the element
            # and its bus outright. Skip — self-loops are a data error reported
            # by connectivity_analysis.
            (l1_id == l2_id) && continue
            l1 = lines[l1_id]
            l2 = lines[l2_id]
            (get(l1, "bus_from", nothing) == get(l1, "bus_to", nothing) ||
             get(l2, "bus_from", nothing) == get(l2, "bus_to", nothing)) && continue

            lc1 = get(l1, "linecode", nothing)
            lc2 = get(l2, "linecode", nothing)
            inline1 = _line_has_inline_z(l1)
            inline2 = _line_has_inline_z(l2)
            if !inline1 && !inline2 && lc1 != lc2
                bus_id in warned_buses && continue
                push!(warned_buses, bus_id)
                _simlog!(net, "merge_series_lines", "LINECODE_MISMATCH", "info",
                    "bus", bus_id,
                    "Lines $l1_id (linecode $lc1) and $l2_id (linecode $lc2) at bus $bus_id " *
                    "have different linecodes — not merged.",
                    detail=Dict("line_1" => l1_id, "line_2" => l2_id,
                                "linecode_1" => lc1, "linecode_2" => lc2))
                continue
            end

            # Resolve the non-shared endpoint and terminal maps for each line.
            if get(l1, "bus_to", nothing) == bus_id
                A          = get(l1, "bus_from", nothing)
                tmap_A     = get(l1, "terminal_map_from", String[])
                tmap_B_l1  = get(l1, "terminal_map_to",   String[])
            else
                A          = get(l1, "bus_to",   nothing)
                tmap_A     = get(l1, "terminal_map_to",   String[])
                tmap_B_l1  = get(l1, "terminal_map_from", String[])
            end

            if get(l2, "bus_from", nothing) == bus_id
                C          = get(l2, "bus_to",   nothing)
                tmap_C     = get(l2, "terminal_map_to",   String[])
                tmap_B_l2  = get(l2, "terminal_map_from", String[])
            else
                C          = get(l2, "bus_from", nothing)
                tmap_C     = get(l2, "terminal_map_from", String[])
                tmap_B_l2  = get(l2, "terminal_map_to",   String[])
            end

            # Two lines forming a 2-cycle A—B—A (both connect the same pair of
            # buses) share BOTH endpoints, so the non-shared ends resolve to the
            # same bus. Merging them would fabricate a self-loop line
            # (bus_from == bus_to) — exactly the E.CONN.SELF_LOOP data error.
            # Skip; parallel lines are not a series pair.
            if A == C
                bus_id in warned_buses && continue
                push!(warned_buses, bus_id)
                _simlog!(net, "merge_series_lines", "PARALLEL_LINES", "info",
                    "bus", bus_id,
                    "Lines $l1_id and $l2_id both connect buses $A and $bus_id " *
                    "(a parallel pair, not a series chain) — not merged.",
                    detail=Dict("line_1" => l1_id, "line_2" => l2_id, "bus" => A))
                continue
            end

            # The two segments are in series per conductor only when their maps
            # at the shared bus agree in ORDER, not merely as sets: terminal maps
            # are positional (conductor k ↔ entry k), so ["1","n"] vs ["n","1"] is
            # a phase transposition the merged single line cannot represent. Require
            # exact equality (the inline-impedance path below does the same).
            if tmap_B_l1 != tmap_B_l2
                bus_id in warned_buses && continue
                push!(warned_buses, bus_id)
                _simlog!(net, "merge_series_lines", "TERMINAL_MISMATCH", "warning",
                    "bus", bus_id,
                    "Lines $l1_id and $l2_id share bus $bus_id but have incompatible terminal " *
                    "maps there ($(tmap_B_l1) vs $(tmap_B_l2)) — not merged.",
                    detail=Dict("line_1" => l1_id, "tmap_1" => tmap_B_l1,
                                "line_2" => l2_id, "tmap_2" => tmap_B_l2))
                continue
            end

            # Inline ABSOLUTE matrices: series impedances add directly when
            # both lines are inline, series-only (no π-shunt fields), and the
            # conductor order at the shared bus matches exactly. Anything
            # else (mixed inline/linecode, shunts, permuted maps) is skipped —
            # summing would silently mis-model the corridor.
            if inline1 || inline2
                has_shunt(l) = any(k -> startswith(k, "G_from_") ||
                                        startswith(k, "B_from_") ||
                                        startswith(k, "G_to_") ||
                                        startswith(k, "B_to_"), keys(l))
                R1 = _pattern_keys_to_matrix(l1, "R_series_")
                X1 = _pattern_keys_to_matrix(l1, "X_series_")
                R2 = _pattern_keys_to_matrix(l2, "R_series_")
                X2 = _pattern_keys_to_matrix(l2, "X_series_")
                mergeable = inline1 && inline2 &&
                    !has_shunt(l1) && !has_shunt(l2) &&
                    tmap_B_l1 == tmap_B_l2 &&
                    R1 isa AbstractMatrix && R2 isa AbstractMatrix &&
                    size(R1) == size(R2) &&
                    X1 isa AbstractMatrix && X2 isa AbstractMatrix &&
                    size(X1) == size(X2)
                if !mergeable
                    bus_id in warned_buses && continue
                    push!(warned_buses, bus_id)
                    _simlog!(net, "merge_series_lines", "INLINE_IMPEDANCE", "info",
                        "bus", bus_id,
                        "Lines $l1_id and $l2_id at bus $bus_id carry inline " *
                        "absolute impedances that cannot be merged safely " *
                        "(mixed source, π-shunt present, or mismatched " *
                        "conductor order) — not merged.",
                        detail=Dict("line_1" => l1_id, "line_2" => l2_id))
                    continue
                end
                n_m = size(R1, 1)
                for i in 1:n_m, j in 1:n_m
                    l1["R_series_$(i)_$(j)"] = R1[i, j] + R2[i, j]
                    l1["X_series_$(i)_$(j)"] = X1[i, j] + X2[i, j]
                end
            end

            len1 = Float64(get(l1, "length", 0.0))
            len2 = Float64(get(l2, "length", 0.0))

            l1["bus_from"]        = A
            l1["bus_to"]          = C
            l1["terminal_map_from"] = tmap_A
            l1["terminal_map_to"]   = tmap_C
            l1["length"]          = len1 + len2
            l1["_merged_from"]    = vcat(get(l1, "_merged_from", String[]), [l2_id])

            # The corridor carries one current through both segments, so its
            # rating is the tighter of the two segments' *effective* limits —
            # each segment's line-level override if present, else its linecode's
            # rating (the only source the OPF reads). Comparing raw line-level
            # overrides alone would miss the case where one segment relies on the
            # linecode and the other carries a looser override, silently relaxing
            # the constraint. The merged line keeps l1's linecode, so we only pin
            # an explicit override when at least one segment already had one;
            # otherwise the shared linecode still carries the (identical) rating.
            lcs   = get(net, "linecode", Dict())
            lc1_d = lc1 isa AbstractString ? get(lcs, lc1, nothing) : nothing
            lc2_d = lc2 isa AbstractString ? get(lcs, lc2, nothing) : nothing
            for key in ("i_max", "s_max")
                o1 = get(l1, key, nothing); o2 = get(l2, key, nothing)
                had_override = o1 !== nothing || o2 !== nothing
                e1 = o1 !== nothing ? o1 : (lc1_d isa Dict ? get(lc1_d, key, nothing) : nothing)
                e2 = o2 !== nothing ? o2 : (lc2_d isa Dict ? get(lc2_d, key, nothing) : nothing)
                if e1 isa AbstractVector && e2 isa AbstractVector
                    # Per conductor: the tighter limit where both segments rate
                    # it, else the one that does. Truncating to the shorter vector
                    # would silently drop a trailing conductor's rating (e.g. one
                    # segment rates phases+neutral, the other phases only — the
                    # neutral limit must survive).
                    n = max(length(e1), length(e2))
                    merged_lim = [begin
                        v1 = k <= length(e1) ? Float64(e1[k]) : nothing
                        v2 = k <= length(e2) ? Float64(e2[k]) : nothing
                        v1 === nothing ? v2 : (v2 === nothing ? v1 : min(v1, v2))
                    end for k in 1:n]
                    had_override ? (l1[key] = merged_lim) : delete!(l1, key)
                elseif e1 isa AbstractVector
                    l1[key] = deepcopy(e1)
                elseif e2 isa AbstractVector
                    l1[key] = deepcopy(e2)
                end
            end

            delete!(lines, l2_id)
            delete!(get(net, "bus", Dict()), bus_id)

            _simlog!(net, "merge_series_lines", "LINES_MERGED", "info",
                "line", l1_id,
                "Merged line $l2_id ($(len2) m) into $l1_id at pass-through bus $bus_id; " *
                "new length $(len1 + len2) m.",
                detail=Dict("absorbed_line" => l2_id, "removed_bus" => bus_id,
                            "new_length" => len1 + len2))
            changed = true
            break  # restart with fresh connectivity
        end
    end
end

function _remove_dangling_lines!(net)
    warned_grounded = Set{String}()
    changed = true
    while changed
        changed = false
        line_count, nonline_count, lines_at = _bus_connectivity(net)
        lines = get(net, "line", Dict())

        for bus_id in keys(get(net, "bus", Dict()))
            get(line_count, bus_id, 0) == 1 || continue
            get(nonline_count, bus_id, 0) == 0 || continue

            # A grounded leaf bus is tied to earth; pruning it silently drops a
            # ground (a return path / neutral reference), changing the electrics.
            # Keep it, matching merge_series_lines' treatment of grounded buses.
            bus_obj = get(get(net, "bus", Dict()), bus_id, Dict())
            if !isempty(get(bus_obj, "perfectly_grounded_terminals", String[]))
                if bus_id ∉ warned_grounded
                    push!(warned_grounded, bus_id)
                    _simlog!(net, "remove_dangling_lines", "GROUNDED_BUS", "warning",
                        "bus", bus_id,
                        "Dangling leaf bus $bus_id has grounded terminals — not pruned; " *
                        "removing it would drop a ground (return path / neutral reference).",
                        detail=Dict("bus" => bus_id))
                end
                continue
            end

            lid  = only(get(lines_at, bus_id, String[]))
            line = lines[lid]
            near = get(line, "bus_from", nothing) == bus_id ?
                   get(line, "bus_to", nothing) : get(line, "bus_from", nothing)

            # A stub with shunt admittance is a shunt-to-earth, not "nothing":
            # removing it drops an injection from the surviving bus's balance, so
            # the feasible set can shift. Negligible on LV overhead, material for
            # cable charging. Still pruned (this is a topology pass), but flagged.
            if _line_has_shunt(net, line)
                _simlog!(net, "remove_dangling_lines", "SHUNT_DROPPED", "warning",
                    "line", lid,
                    "Removed dangling line $lid carried non-zero shunt admittance to " *
                    "earth; dropping it perturbs the nodal balance at surviving bus " *
                    "$near — the feasible set may change (negligible for LV overhead, " *
                    "material for cable charging).",
                    detail=Dict("removed_bus" => bus_id, "surviving_bus" => near))
            end

            delete!(lines, lid)
            delete!(get(net, "bus", Dict()), bus_id)

            _simlog!(net, "remove_dangling_lines", "LINE_REMOVED", "info",
                "line", lid,
                "Removed dangling line $lid and its leaf bus $bus_id " *
                "(leaf has no active elements).",
                detail=Dict("removed_bus" => bus_id))
            changed = true
            break
        end
    end
end

function _remove_open_switches!(net)
    switches  = get(net, "switch", Dict())
    to_remove = [sid for (sid, sw) in switches if get(sw, "open_switch", false)]

    for sid in to_remove
        sw    = switches[sid]
        b_fr  = get(sw, "bus_from", nothing)
        b_to  = get(sw, "bus_to",   nothing)

        delete!(switches, sid)

        _simlog!(net, "remove_open_switches", "SWITCH_REMOVED", "info",
            "switch", sid,
            "Removed open switch $sid between buses $b_fr and $b_to.",
            detail=Dict("bus_from" => b_fr, "bus_to" => b_to))

        for b in (b_fr, b_to)
            b isa AbstractString || continue
            haskey(get(net, "bus", Dict()), b) || continue
            _bus_has_connections(net, b) && continue
            _simlog!(net, "remove_open_switches", "ISOLATED_BUS", "warning",
                "bus", b,
                "Bus $b has no remaining connections after removing open switch $sid " *
                "— possible user error.",
                detail=Dict("switch_removed" => sid))
        end
    end
end

function _collapse_closed_switches!(net)
    changed = true
    while changed
        changed = false

        for (sid, sw) in collect(get(net, "switch", Dict()))
            get(sw, "open_switch", false) && continue

            b_fr = get(sw, "bus_from", nothing)
            b_to = get(sw, "bus_to",   nothing)
            (b_fr isa AbstractString && b_to isa AbstractString) || continue

            if b_fr == b_to
                _simlog!(net, "collapse_closed_switches", "MERGE_CONFLICT_TERMINALS", "warning",
                    "switch", sid,
                    "Switch $sid is a self-loop (bus_from == bus_to == $b_fr) — skipped.",
                    detail=Dict("bus" => b_fr))
                continue
            end

            buses  = get(net, "bus", Dict())
            bus_f  = get(buses, b_fr, nothing)
            bus_t  = get(buses, b_to, nothing)
            (bus_f isa Dict && bus_t isa Dict) || continue

            # Block if both endpoints already have a voltage source.
            vs_at = b -> any(get(vs, "bus", nothing) == b
                             for (_, vs) in get(net, "voltage_source", Dict()))
            if vs_at(b_fr) && vs_at(b_to)
                _simlog!(net, "collapse_closed_switches", "MERGE_CONFLICT_SOURCE", "warning",
                    "switch", sid,
                    "Switch $sid joins buses $b_fr and $b_to, each with a voltage source " *
                    "— collapse would create conflicting references; skipped.",
                    detail=Dict("bus_from" => b_fr, "bus_to" => b_to))
                continue
            end

            # The collapse fuses b_to into b_fr by terminal-NAME union, so a name
            # present on BOTH buses becomes one node. That is only correct when the
            # switch actually connects those terminals straight-through. Two failure
            # modes pass an arity check but corrupt the topology:
            #   • cross-phase map (tmap_from ≠ tmap_to element-wise): the switch
            #     joins e.g. b_fr's "1" to b_to's "2", yet the name-union would
            #     silently make it an identity ("1"↔"1") connection;
            #   • partial map: a terminal name shared by both buses but absent from
            #     the switch map would be fused by name though the switch never
            #     connected it.
            # Require an identity map (tmap_from == tmap_to) that covers every
            # terminal name the two buses share; skip otherwise. (A terminal on
            # only one bus is harmless — it is carried across, not fused.)
            tmap_fr = String.(get(sw, "terminal_map_from", String[]))
            tmap_to = String.(get(sw, "terminal_map_to",   String[]))
            shared  = intersect(Set(String.(get(bus_f, "terminal_names", String[]))),
                                Set(String.(get(bus_t, "terminal_names", String[]))))
            if tmap_fr != tmap_to || !issubset(shared, Set(tmap_fr))
                _simlog!(net, "collapse_closed_switches", "MERGE_CONFLICT_TERMINALS", "warning",
                    "switch", sid,
                    "Switch $sid is not a straight-through identity connection over the " *
                    "terminals its buses share (cross-phase or partial map) — skipped.",
                    detail=Dict("bus_from" => b_fr, "bus_to" => b_to,
                                "tmap_from" => tmap_fr, "tmap_to" => tmap_to,
                                "shared_terminals" => sort(collect(shared))))
                continue
            end

            # Merge: b_fr survives, b_to absorbed. Capture each bus's own
            # phase-terminal order first — the per-phase bound arrays are
            # indexed by it, and the two buses may order their phases
            # differently.
            _phases(bus) = begin
                tn = String.(get(bus, "terminal_names", String[]))
                nt = get(bus, "neutral_terminal", nothing)
                nt === nothing && (nt = _neutral_terminal(tn))
                [t for t in tn if t != nt]
            end
            ph_f = _phases(bus_f)
            ph_t = _phases(bus_t)

            merged_terminals = copy(get(bus_f, "terminal_names", String[]))
            for t in get(bus_t, "terminal_names", String[])
                t in merged_terminals || push!(merged_terminals, t)
            end
            bus_f["terminal_names"] = merged_terminals

            pg_merged = collect(union(
                Set(String.(get(bus_f, "perfectly_grounded_terminals", String[]))),
                Set(String.(get(bus_t, "perfectly_grounded_terminals", String[])))))
            isempty(pg_merged) || (bus_f["perfectly_grounded_terminals"] = pg_merged)

            # Tighter voltage bounds, aligned by phase-terminal NAME (max of
            # the lower bounds, min of the upper bounds where both buses bound
            # the same phase). A blind element-wise combine would pair
            # different phases whenever the orderings differ. Covers the
            # per-phase and phase-to-neutral arrays; scalar and phase-pair
            # bounds are combined below.
            merged_phases = _phases(bus_f)
            _by_name(phs, vals) = Dict(phs[i] => Float64(vals[i])
                                       for i in 1:min(length(phs), length(vals)))
            for (field, op) in (("v_min", max), ("v_max", min),
                                ("vpn_min", max), ("vpn_max", min))
                vf = get(bus_f, field, nothing)
                vt = get(bus_t, field, nothing)
                (vf === nothing && vt === nothing) && continue
                bf = vf isa AbstractVector ? _by_name(ph_f, vf) : Dict{String,Float64}()
                bt = vt isa AbstractVector ? _by_name(ph_t, vt) : Dict{String,Float64}()
                vals = Float64[]
                complete = true
                for t in merged_phases
                    hf = haskey(bf, t); ht = haskey(bt, t)
                    if hf && ht
                        push!(vals, op(bf[t], bt[t]))
                    elseif hf || ht
                        push!(vals, hf ? bf[t] : bt[t])
                    else
                        complete = false
                        break
                    end
                end
                if complete
                    bus_f[field] = vals
                else
                    # A merged phase has no bound from either side; a per-phase
                    # array cannot carry holes, so drop the field with a log
                    # entry rather than fabricate a value.
                    delete!(bus_f, field)
                    _simlog!(net, "collapse_closed_switches", "BOUND_DROPPED",
                        "warning", "bus", b_fr,
                        "Merged bus $b_fr: `$field` dropped — phase set after " *
                        "collapsing switch $sid has phases with no bound on " *
                        "either side.",
                        detail=Dict("field" => field, "bus_absorbed" => b_to))
                end
            end

            # Scalar feasible-set bounds (sequence magnitudes, neutral voltage,
            # angle-difference limits): the merged node keeps the tighter of the
            # two — max for lower bounds, min for upper. Previously only v_min/
            # v_max survived, so an absorbed bus's tighter scalar bound was lost.
            for (field, op) in (("vpos_min", max), ("vpos_max", min),
                                ("vneg_max", min), ("vzero_max", min),
                                ("vn_max",   min),
                                ("va_diff_min", max), ("va_diff_max", min))
                vf = get(bus_f, field, nothing); vt = get(bus_t, field, nothing)
                if vf isa Number && vt isa Number
                    bus_f[field] = op(Float64(vf), Float64(vt))
                elseif vt isa Number
                    bus_f[field] = Float64(vt)
                end
                # vf-only: already on bus_f, nothing to do.
            end

            # Phase-pair bounds (vpp_*) are indexed by phase PAIR, not phase
            # name, so they can only be combined element-wise when both buses
            # enumerate the same phases in the same order. Otherwise the pairing
            # is ambiguous; keep the survivor's and record the absorbed bus's
            # loss rather than mis-pair.
            same_phase_order = ph_f == ph_t
            for (field, op) in (("vpp_min", max), ("vpp_max", min))
                vf = get(bus_f, field, nothing); vt = get(bus_t, field, nothing)
                (vt isa AbstractVector) || continue          # nothing to fold in
                if vf isa AbstractVector && same_phase_order &&
                   length(vf) == length(vt)
                    bus_f[field] = [op(Float64(vf[k]), Float64(vt[k])) for k in eachindex(vf)]
                elseif vf === nothing && same_phase_order
                    bus_f[field] = deepcopy(vt)
                else
                    _simlog!(net, "collapse_closed_switches", "BOUND_DROPPED",
                        "warning", "bus", b_fr,
                        "Merged bus $b_fr: absorbed bus $b_to's `$field` could not " *
                        "be combined (differing phase order or length) and was dropped.",
                        detail=Dict("field" => field, "bus_absorbed" => b_to))
                end
            end

            # A closed switch with an enforced current OR apparent-power limit is
            # flow-limited in the OPF just like a line. Collapsing fuses its two
            # buses into one node, so the cut the rating constrained no longer
            # exists and the limit cannot be projected onto any surviving branch —
            # it is simply lost. Flag it (the collapse still proceeds); keep
            # `closed_switches = false` to retain a rated switch as an explicit
            # branch.
            for lim_key in ("i_max", "s_max")
                lim = get(sw, lim_key, nothing)
                (lim isa AbstractVector && any(x -> x isa Number && !iszero(x), lim)) || continue
                _simlog!(net, "collapse_closed_switches", "SWITCH_LIMIT_DROPPED", "warning",
                    "switch", sid,
                    "Collapsing switch $sid drops its $lim_key $(lim): merging " *
                    "buses $b_fr and $b_to fuses them into one node, so the cut the rating " *
                    "constrained no longer exists and the limit cannot be projected onto a " *
                    "surviving branch — the feasible set may change. Keep " *
                    "`closed_switches = false` to retain the switch as an explicit branch.",
                    detail=Dict("bus_from" => b_fr, "bus_to" => b_to, lim_key => lim))
            end

            _redirect_bus!(net, b_to, b_fr)
            delete!(get(net, "switch", Dict()), sid)
            delete!(buses, b_to)

            _simlog!(net, "collapse_closed_switches", "SWITCH_COLLAPSED", "info",
                "switch", sid,
                "Collapsed closed switch $sid: bus $b_to merged into $b_fr.",
                detail=Dict("bus_from" => b_fr, "bus_to_absorbed" => b_to))
            changed = true
            break
        end
    end
end

# ── Public API ─────────────────────────────────────────────────────────────────

"""
    merge_series_lines(net) -> net′

Return a deep-copied network with consecutive same-linecode lines fused at
pass-through buses (buses with exactly two line connections and no other
elements). Iterates to convergence so chains of three or more lines are fully
collapsed in one call.

A pass-through bus is blocked — and a log entry emitted — when:
- the intermediate bus carries any non-line element (load, shunt, etc.):
  code `NON_LINE_ON_BUS` (info)
- a switch is the blocking element: code `SWITCH_IN_CHAIN` (warning; likely
  user error — a switch placeholder left in the middle of a cable run)
- the intermediate bus has grounded terminals (`perfectly_grounded_terminals`):
  code `GROUNDED_BUS` (warning) — the ground fixes terminal voltages and would
  be lost if the bus were deleted
- adjacent linecodes differ: code `LINECODE_MISMATCH` (info)
- terminal maps at the shared bus are incompatible: code `TERMINAL_MISMATCH`
  (warning)

Successful merges record `_merged_from` on the surviving line and emit
`LINES_MERGED` (info). The merged corridor's `i_max`/`s_max` is the
element-wise minimum of the two segments' **effective** limits (each segment's
line-level override if present, else its linecode rating), so no thermal
constraint is silently relaxed.

This is a **one-way, lossy** transformation: the intermediate bus and the
absorbed line's per-segment impedance are removed, and the reduction is recorded
only in the package-level `_simplification_log`/`_merged_from`, not in the
versioned data-model schema. Keep the original case as the exchanged artifact
and treat the simplified network as a solve-time compile target — see the
[simplification tutorial](@ref tutorial-simplify) and
[object identity](@ref object-identity).

All outcomes are appended to `net′["_simplification_log"]`.
"""
function merge_series_lines(net::Dict{String,Any})::Dict{String,Any}
    net′ = deepcopy(net)
    get!(net′, "_simplification_log", Any[])
    _merge_series_lines!(net′)
    net′
end

"""
    remove_dangling_lines(net) -> net′

Return a deep-copied network with all stub lines removed. A stub is a line
whose far-end bus has exactly one line connection and no active elements (loads,
generators, shunts, voltage sources, transformers, switches). The far-end bus
is removed along with the line. Iterates to convergence so dangling chains are
fully pruned.

Successful removals emit `LINE_REMOVED` (info). A stub that carries non-zero
shunt admittance to earth (inline `G_*`/`B_*`, or via its linecode) is a
shunt-to-earth, not electrically "nothing": pruning it drops an injection from
the surviving bus's balance and **can move the feasible set** (negligible for LV
overhead, material for cable charging). Such removals additionally emit
`SHUNT_DROPPED` (warning); the line is still pruned. All outcomes appended to
`net′["_simplification_log"]`.
"""
function remove_dangling_lines(net::Dict{String,Any})::Dict{String,Any}
    net′ = deepcopy(net)
    get!(net′, "_simplification_log", Any[])
    _remove_dangling_lines!(net′)
    net′
end

"""
    remove_open_switches(net) -> net′

Return a deep-copied network with all open switch elements (`open_switch=true`)
deleted. The buses they connected are retained. Emits `SWITCH_REMOVED` (info)
for each deleted switch and `ISOLATED_BUS` (warning) for any bus that has no
remaining connections after the removal.

All outcomes appended to `net′["_simplification_log"]`.
"""
function remove_open_switches(net::Dict{String,Any})::Dict{String,Any}
    net′ = deepcopy(net)
    get!(net′, "_simplification_log", Any[])
    _remove_open_switches!(net′)
    net′
end

"""
    collapse_closed_switches(net) -> net′

Return a deep-copied network with closed switches (`open_switch=false`) removed
by merging the two buses they connect. The `bus_from` bus always survives; the
`bus_to` bus is absorbed and every element that referenced it is redirected.
Terminal names and grounding sets are unioned; voltage bounds are tightened to
their intersection. Iterates to convergence.

Collapse is blocked — and a warning logged — when:
- both buses carry a voltage source: code `MERGE_CONFLICT_SOURCE`
- the switch's terminal-map arities differ: code `MERGE_CONFLICT_TERMINALS`
- the switch is a self-loop: code `MERGE_CONFLICT_TERMINALS`

Successful collapses emit `SWITCH_COLLAPSED` (info).

A closed switch carrying an `i_max` is flow-limited in the OPF like a line, but
collapsing fuses its two buses into a single node — the cut its rating
constrained no longer exists, so the limit **cannot be projected onto a surviving
branch** and is dropped. This emits `SWITCH_LIMIT_DROPPED` (warning) and **the
feasible set may change**; the collapse still proceeds. Keep `closed_switches =
false` to retain a rated switch as an explicit zero-impedance branch.

All outcomes appended to `net′["_simplification_log"]`.
"""
function collapse_closed_switches(net::Dict{String,Any})::Dict{String,Any}
    net′ = deepcopy(net)
    get!(net′, "_simplification_log", Any[])
    _collapse_closed_switches!(net′)
    net′
end

"""
    simplify_network(net;
                     open_switches   = true,
                     closed_switches = true,
                     dangling_lines  = true,
                     series_lines    = true) -> net′

Apply selected topology simplifications in order:
1. `collapse_closed_switches` — merge bus pairs joined by zero-impedance closed switches
2. `remove_open_switches`     — delete open switch elements
3. `remove_dangling_lines`    — remove stub lines and their leaf buses
4. `merge_series_lines`       — fuse consecutive same-linecode lines at pass-through buses

Each operation can be disabled individually via keyword arguments. Returns a
deep copy of `net` with all selected operations applied; outcomes accumulate in
`net′["_simplification_log"]`.
"""
function simplify_network(net::Dict{String,Any};
                          open_switches   = true,
                          closed_switches = true,
                          dangling_lines  = true,
                          series_lines    = true)::Dict{String,Any}
    net′ = deepcopy(net)
    get!(net′, "_simplification_log", Any[])
    closed_switches && _collapse_closed_switches!(net′)
    open_switches   && _remove_open_switches!(net′)
    dangling_lines  && _remove_dangling_lines!(net′)
    series_lines    && _merge_series_lines!(net′)
    net′
end
