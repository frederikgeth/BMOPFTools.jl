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
#   LINE_REMOVED              info    remove_dangling_lines  stub line and leaf bus removed
#   SWITCH_REMOVED            info    remove_open_switches   open switch element deleted
#   ISOLATED_BUS              warning remove_open_switches   bus has no connections after switch removal
#   SWITCH_COLLAPSED          info    collapse_closed_switches bus pair merged via closed switch
#   MERGE_CONFLICT_TERMINALS  warning collapse_closed_switches terminal-map arity mismatch — not collapsed
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

# Returns (line_count, nonline_count, lines_at) for all buses.
# line_count[b]    = number of lines referencing bus b
# nonline_count[b] = number of non-line elements at bus b
#                    (loads, generators, shunts, voltage_sources, switches, transformers)
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

    for comp in ("load", "generator", "shunt", "voltage_source")
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
            for b in (get(t, "bus_from", nothing), get(t, "bus_to", nothing))
                b isa AbstractString && haskey(nonline_count, b) && (nonline_count[b] += 1)
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
    for comp in ("load", "generator", "shunt", "voltage_source")
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
            (get(t, "bus_from", nothing) == bus_id ||
             get(t, "bus_to",   nothing) == bus_id) && return true
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
    for comp in ("load", "generator", "shunt", "voltage_source")
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
            get(t, "bus_from", nothing) == old_bus && (t["bus_from"] = new_bus)
            get(t, "bus_to",   nothing) == old_bus && (t["bus_to"]   = new_bus)
        end
    end
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
            if lc1 != lc2
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

            if Set(tmap_B_l1) != Set(tmap_B_l2)
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

            len1 = Float64(get(l1, "length", 0.0))
            len2 = Float64(get(l2, "length", 0.0))

            l1["bus_from"]        = A
            l1["bus_to"]          = C
            l1["terminal_map_from"] = tmap_A
            l1["terminal_map_to"]   = tmap_C
            l1["length"]          = len1 + len2
            l1["_merged_from"]    = vcat(get(l1, "_merged_from", String[]), [l2_id])

            # The corridor's rating is the tighter of the two segments'
            # line-level overrides; dropping the absorbed line's i_max/s_max
            # would silently relax a thermal constraint.
            for key in ("i_max", "s_max")
                v1 = get(l1, key, nothing); v2 = get(l2, key, nothing)
                if v1 isa AbstractVector && v2 isa AbstractVector
                    n = min(length(v1), length(v2))
                    l1[key] = [min(Float64(v1[k]), Float64(v2[k])) for k in 1:n]
                elseif v1 === nothing && v2 !== nothing
                    l1[key] = deepcopy(v2)
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
    changed = true
    while changed
        changed = false
        line_count, nonline_count, lines_at = _bus_connectivity(net)
        lines = get(net, "line", Dict())

        for bus_id in keys(get(net, "bus", Dict()))
            get(line_count, bus_id, 0) == 1 || continue
            get(nonline_count, bus_id, 0) == 0 || continue

            lid = only(get(lines_at, bus_id, String[]))

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

            # Block on terminal-map arity mismatch.
            tmap_fr = get(sw, "terminal_map_from", String[])
            tmap_to = get(sw, "terminal_map_to",   String[])
            if length(tmap_fr) != length(tmap_to)
                _simlog!(net, "collapse_closed_switches", "MERGE_CONFLICT_TERMINALS", "warning",
                    "switch", sid,
                    "Switch $sid has mismatched terminal-map arities " *
                    "(from=$(length(tmap_fr)), to=$(length(tmap_to))) — skipped.",
                    detail=Dict("bus_from" => b_fr, "bus_to" => b_to,
                                "tmap_from" => tmap_fr, "tmap_to" => tmap_to))
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
            # different phases whenever the orderings differ.
            merged_phases = _phases(bus_f)
            _by_name(phs, vals) = Dict(phs[i] => Float64(vals[i])
                                       for i in 1:min(length(phs), length(vals)))
            for (field, op) in (("v_min", max), ("v_max", min))
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
- adjacent linecodes differ: code `LINECODE_MISMATCH` (info)
- terminal maps at the shared bus are incompatible: code `TERMINAL_MISMATCH`
  (warning)

Successful merges record `_merged_from` on the surviving line and emit
`LINES_MERGED` (info).

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

Successful removals emit `LINE_REMOVED` (info). All outcomes appended to
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

Successful collapses emit `SWITCH_COLLAPSED` (info). All outcomes appended to
`net′["_simplification_log"]`.
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
