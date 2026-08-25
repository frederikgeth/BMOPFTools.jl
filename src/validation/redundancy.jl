# validation/redundancy.jl

"""
    redundancy_check(net, findings) -> Dict{String,Any}

Identify redundant or trivial elements that do not contribute to
the OPF problem and may indicate data quality issues.
"""
function redundancy_check(net::Dict{String,Any},
                           findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()

    result["zero_loads"]         = _check_zero_loads(net, findings)
    result["sparse_phase_loads"] = _check_sparse_phase_loads(net, findings)
    result["mergeable_loads"]    = _check_mergeable_loads(net, findings)
    result["mergeable_lines"]    = _check_mergeable_lines(net, findings)
    result["parallel_lines"]     = _check_parallel_lines(net, findings)
    result["zero_shunts"]        = _check_zero_shunts(net, findings)
    result["unused_linecodes"]   = _check_unused_linecodes(net, findings)
    result["duplicate_linecodes"] = _check_duplicate_linecodes(net, findings)
    result["dc_redundancies"]    = _check_dc_redundancies(net, findings)
    result["dual_thermal_limits"] = _check_dual_thermal_limits(net, findings)

    result
end

# The OPF now enforces BOTH a current limit and an apparent-power limit natively
# on every element that carries them. Declaring both is not MATHEMATICALLY
# redundant: since |S| = |V||I|, S_max/I_max is a voltage, and if it falls inside
# the bus voltage range the binding row changes with voltage. It is usually
# redundant in ENGINEERING terms, which is the useful reading — a device has one
# thermal limit, and two declared rows normally mean one was derived from the
# other — so flag it and name the preferred
# representation for that component type. Preference (see the "current vs.
# apparent-power limits" docs): current for lines/cables/switches and for
# regulators (the tap-changer current is the physical limit); apparent power for
# power transformers (the kVA nameplate is how they are specified).
function _check_dual_thermal_limits(net, findings)
    _has(x) = x !== nothing && !(x isa AbstractVector && isempty(x))
    n = 0
    prefer_current(ct, id, extra="") =
        push!(findings, Finding(WARNING, "W.RED.DUAL_THERMAL_LIMIT", :redundancy, ct, id,
            "$(ct) '$id' declares both a current limit (i_max) and an apparent-power " *
            "limit (s_max)$extra. Both are enforced, and since |S| = |V||I| the binding " *
            "one can change with voltage — so the pair is not mathematically redundant, " *
            "it is a composite envelope no datasheet specifies. It is usually redundant " *
            "in engineering terms: the device has one thermal limit and two rows " *
            "normally mean one was derived from the other. Prefer the current limit " *
            "here (conductor heating is specified in amperes, with no voltage-reference " *
            "ambiguity); drop s_max or convert it in augmentation.", nothing))

    for (id, l) in get(net, "line", Dict())
        l isa Dict || continue
        if _has(get(l, "i_max", nothing)) && _has(get(l, "s_max", nothing))
            n += 1; prefer_current(:line, id)
        end
    end
    for (id, sw) in get(net, "switch", Dict())
        sw isa Dict || continue
        if _has(get(sw, "i_max", nothing)) && _has(get(sw, "s_max", nothing))
            n += 1; prefer_current(:switch, id)
        end
    end
    # Generators / IBRs: both are the converter/machine current circle and power
    # circle; the power circle (s_max) is the natural nameplate, prefer it.
    for (comp, ct) in (("generator", :generator), ("ibr", :ibr))
        for (id, g) in get(net, comp, Dict())
            g isa Dict || continue
            if _has(get(g, "i_max", nothing)) && _has(get(g, "s_max", nothing))
                n += 1
                push!(findings, Finding(WARNING, "W.RED.DUAL_THERMAL_LIMIT", :redundancy,
                    ct, id,
                    "$(ct) '$id' declares both a current limit (i_max) and an " *
                    "apparent-power limit (s_max). Both are enforced, and since " *
                    "|S| = |V||I| the binding one can change with voltage, so the pair " *
                    "is not mathematically redundant; a current cap additionally makes " *
                    "deliverable power roll off with voltage. Declaring both usually " *
                    "reflects duplicated data rather than two real limits — keep " *
                    "whichever is the device's source of truth.", nothing))
            end
        end
    end
    Dict{String,Any}("n" => n)
end

# DC-network redundancies: self-loop branches, duplicate parallel branches, and
# a grounding declared on a terminal already perfectly grounded by its dc_bus.
function _check_dc_redundancies(net, findings)
    n = 0
    for (id, br) in get(net, "dc_branch", Dict())
        br isa Dict || continue
        if get(br, "dc_bus_from", nothing) == get(br, "dc_bus_to", nothing) !== nothing
            n += 1
            push!(findings, Finding(WARNING, "W.RED.DC_BRANCH_SELF_LOOP", :redundancy,
                :dc_branch, id,
                "dc_branch '$id' connects dc_bus '$(get(br,"dc_bus_from",""))' to " *
                "itself — it carries no transfer.", nothing))
        end
    end

    # duplicate parallel branches (same unordered endpoint pair)
    seen = Dict{Tuple{String,String},String}()
    for (id, br) in get(net, "dc_branch", Dict())
        br isa Dict || continue
        f = get(br, "dc_bus_from", nothing); t = get(br, "dc_bus_to", nothing)
        (f isa AbstractString && t isa AbstractString && f != t) || continue
        key = f <= t ? (f, t) : (t, f)
        if haskey(seen, key)
            n += 1
            push!(findings, Finding(INFO, "I.RED.DC_PARALLEL_BRANCHES", :redundancy,
                :dc_branch, id,
                "dc_branch '$id' is parallel to '$(seen[key])' (same dc_bus pair " *
                "$(key)).", Dict{String,Any}("other" => seen[key])))
        else
            seen[key] = id
        end
    end

    # grounding on an already-perfectly-grounded terminal
    dc_buses = get(net, "dc_bus", Dict())
    for (id, g) in get(net, "dc_grounding", Dict())
        g isa Dict || continue
        b = get(g, "dc_bus", nothing); t = get(g, "terminal", nothing)
        (b isa AbstractString && t isa AbstractString) || continue
        bus = get(dc_buses, b, nothing)
        bus isa Dict || continue
        if string(t) in string.(get(bus, "perfectly_grounded_terminals", String[]))
            n += 1
            push!(findings, Finding(WARNING, "W.RED.DC_REDUNDANT_GROUNDING", :redundancy,
                :dc_grounding, id,
                "dc_grounding '$id' earths terminal '$t' of dc_bus '$b', which is " *
                "already in perfectly_grounded_terminals.", nothing))
        end
    end
    n
end

function _check_zero_loads(net, findings)
    zero_loads = String[]
    for (id, l) in get(net, "load", Dict())
        p = Float64.(get(l, "p_nom", Float64[]))
        q = Float64.(get(l, "q_nom", Float64[]))
        p_sum = isempty(p) ? 0.0 : sum(abs, p)
        q_sum = isempty(q) ? 0.0 : sum(abs, q)
        if p_sum == 0.0 && q_sum == 0.0
            push!(zero_loads, id)
        end
    end
    if !isempty(zero_loads)
        push!(findings, Finding(WARNING, "W.RED.ZERO_LOADS", :redundancy, :load, nothing,
            "$(length(zero_loads)) load(s) have p_nom=0 and q_nom=0 — electrically inert.",
            Dict{String,Any}("loads" => zero_loads)))
    end
    Dict{String,Any}("n" => length(zero_loads), "ids" => zero_loads)
end

function _check_sparse_phase_loads(net, findings)
    # Flag WYE loads where at least one phase has p≈0 and q≈0 while another
    # does not.  SINGLE_PHASE and DELTA are excluded: single-phase has no
    # phases to trim; delta "zero phases" have no clean single-phase equivalent.
    sparse = Dict{String, Vector{Int}}()   # load id => dead phase indices (1-based)
    for (id, l) in get(net, "load", Dict())
        l isa Dict || continue
        get(l, "configuration", "WYE") == "WYE" || continue
        p = Float64.(get(l, "p_nom", Float64[]))
        q = Float64.(get(l, "q_nom", Float64[]))
        n = max(length(p), length(q))
        n < 2 && continue   # nothing to trim in a 1-phase WYE
        dead = Int[]
        for k in 1:n
            pk = k <= length(p) ? p[k] : 0.0
            qk = k <= length(q) ? q[k] : 0.0
            pk ≈ 0.0 && qk ≈ 0.0 && push!(dead, k)
        end
        # Only flag if mixed: some phases dead, some alive
        !isempty(dead) && length(dead) < n && (sparse[id] = dead)
    end

    if !isempty(sparse)
        ids = sort(collect(keys(sparse)))
        push!(findings, Finding(INFO, "I.RED.LOAD_SPARSE_PHASES", :redundancy, :load, nothing,
            "$(length(sparse)) WYE load(s) have one or more phases with p≈0 and q≈0 " *
            "while other phases are active — consider splitting into per-phase " *
            "SINGLE_PHASE loads to reduce model size: $(join(ids, ", ")).",
            Dict{String,Any}("loads" => Dict(id => dead for (id, dead) in sparse))))
    end
    Dict{String,Any}("n" => length(sparse),
                     "loads" => Dict(id => dead for (id, dead) in sparse))
end

# Return a canonical key for grouping loads that can be merged.
# WYE/SINGLE_PHASE: sort phase terminals, append neutral last.
# DELTA: normalise to the lexicographically smallest cyclic rotation.
function _load_merge_key(load::Dict)
    bus  = get(load, "bus", "")
    cfg  = get(load, "configuration", "WYE")
    tm   = Vector{String}(get(load, "terminal_map", String[]))

    if cfg in ("WYE", "SINGLE_PHASE")
        neutral = findfirst(t -> lowercase(t) == "n", tm)
        phases  = [tm[i] for i in eachindex(tm) if i != neutral]
        sort!(phases)
        normed  = neutral !== nothing ? vcat(phases, [tm[neutral]]) : phases
    else  # DELTA — find smallest cyclic rotation
        n = length(tm)
        normed = tm
        for rot in 1:n-1
            candidate = vcat(tm[rot+1:end], tm[1:rot])
            candidate < normed && (normed = candidate)
        end
    end
    (bus, cfg, normed)
end

function _check_mergeable_loads(net, findings)
    loads = get(net, "load", Dict())
    groups = Dict{Any, Vector{String}}()

    for (id, l) in loads
        l isa Dict || continue
        # Loads with time_series are excluded: merging requires summing profiles
        haskey(l, "time_series") && continue
        key = _load_merge_key(l)
        push!(get!(groups, key, String[]), id)
    end

    mergeable = [(key, sort(ids)) for (key, ids) in groups if length(ids) >= 2]
    has_ts    = any(haskey(l, "time_series") for (_, l) in loads if l isa Dict)

    if !isempty(mergeable)
        n_loads = sum(length(ids) for (_, ids) in mergeable)
        ts_note = has_ts ? " (loads with time_series profiles were excluded)" : ""
        push!(findings, Finding(INFO, "I.RED.LOAD_MERGEABLE", :redundancy, :load, nothing,
            "$(length(mergeable)) group(s) of loads ($n_loads loads total) share the " *
            "same bus, configuration and terminal_map — each group can be collapsed " *
            "into a single load with summed setpoints$ts_note.",
            Dict{String,Any}(
                "n_groups" => length(mergeable),
                "groups"   => [Dict{String,Any}(
                    "bus"           => key[1],
                    "configuration" => key[2],
                    "terminal_map"  => key[3],
                    "load_ids"      => ids)
                    for (key, ids) in mergeable])))
    end

    Dict{String,Any}("n_groups"  => length(mergeable),
                     "groups"    => [Dict{String,Any}(
                         "bus"           => key[1],
                         "configuration" => key[2],
                         "terminal_map"  => key[3],
                         "load_ids"      => ids)
                         for (key, ids) in mergeable])
end

function _check_mergeable_lines(net, findings)
    # A line is mergeable if its internal buses (both endpoints) have line-degree 2,
    # no other branch elements (switches, transformers), and no shunt elements
    # (loads, generators, shunts, sources) attached.
    buses = get(net, "bus", Dict())
    lines = get(net, "line", Dict())

    # Count line connections per bus; index lines by bus for chain growth
    bus_degree   = Dict{String,Int}(id => 0 for id in keys(buses))
    bus_elements = Dict{String,Int}(id => 0 for id in keys(buses))
    lines_at_bus = Dict{String,Vector{String}}()

    for (id, l) in lines
        for b in (get(l, "bus_from", nothing), get(l, "bus_to", nothing))
            b isa AbstractString && haskey(bus_degree, b) || continue
            bus_degree[b] += 1
            push!(get!(lines_at_bus, b, String[]), id)
        end
    end

    # Other branch elements block merging: a bus where a switch or transformer
    # tees off is a junction, not a pass-through point.
    for (_, sw) in get(net, "switch", Dict())
        for b in (get(sw, "bus_from", nothing), get(sw, "bus_to", nothing))
            b isa AbstractString && haskey(bus_elements, b) && (bus_elements[b] += 1)
        end
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (_, t) in sub
            for b in (get(t, "bus_from", nothing), get(t, "bus_to", nothing))
                b isa AbstractString && haskey(bus_elements, b) && (bus_elements[b] += 1)
            end
        end
    end

    for comp_type in ("load", "generator", "shunt", "voltage_source", "ibr")
        for (_, c) in get(net, comp_type, Dict())
            b = get(c, "bus", nothing)
            b isa AbstractString && haskey(bus_elements, b) && (bus_elements[b] += 1)
        end
    end

    # Identify degree-2 pass-through buses with no element attachments
    passthrough = Set(id for id in keys(buses)
                      if bus_degree[id] == 2 && bus_elements[id] == 0)

    # Find line pairs sharing a pass-through bus
    mergeable_groups = Vector{Vector{String}}()
    visited_lines = Set{String}()

    for (id, l) in lines
        id in visited_lines && continue
        f, t = get(l, "bus_from", ""), get(l, "bus_to", "")

        if f in passthrough || t in passthrough
            # Grow the chain in both directions
            chain = [id]
            push!(visited_lines, id)
            _grow_chain!(chain, t, passthrough, lines, lines_at_bus, visited_lines)
            _grow_chain!(chain, f, passthrough, lines, lines_at_bus, visited_lines)
            length(chain) > 1 && push!(mergeable_groups, chain)
        end
    end

    if !isempty(mergeable_groups)
        total = sum(length, mergeable_groups)
        push!(findings, Finding(INFO, "I.RED.MERGEABLE_LINES", :redundancy, :line, nothing,
            "$(length(mergeable_groups)) group(s) of series lines ($total lines total) " *
            "can be merged — intermediate buses have no other connections.",
            Dict{String,Any}("n_groups" => length(mergeable_groups),
                             "groups"   => mergeable_groups)))
    end

    Dict{String,Any}(
        "n_groups"  => length(mergeable_groups),
        "groups"    => mergeable_groups
    )
end

function _grow_chain!(chain, start_bus, passthrough, lines, lines_at_bus, visited)
    current_bus = start_bus
    while current_bus in passthrough
        next_line = nothing
        for id in get(lines_at_bus, current_bus, String[])
            id in visited && continue
            l = lines[id]
            f, t = get(l, "bus_from", ""), get(l, "bus_to", "")
            next_line = (id, f == current_bus ? t : f)
            break
        end
        next_line === nothing && break
        push!(chain, next_line[1])
        push!(visited, next_line[1])
        current_bus = next_line[2]
    end
end

function _check_parallel_lines(net, findings)
    lines = get(net, "line", Dict())
    # Canonical bus-pair key: always (min, max) so (A,B) and (B,A) are the same
    groups = Dict{Tuple{String,String}, Vector{String}}()
    for (id, l) in lines
        l isa Dict || continue
        bf = get(l, "bus_from", nothing)
        bt = get(l, "bus_to",   nothing)
        (bf isa String && bt isa String) || continue
        key = bf < bt ? (bf, bt) : (bt, bf)
        push!(get!(groups, key, String[]), id)
    end
    parallel = [(pair, sort(ids)) for (pair, ids) in groups if length(ids) > 1]
    if !isempty(parallel)
        total = sum(length(e[2]) for e in parallel)
        push!(findings, Finding(INFO, "I.RED.PARALLEL_LINES", :redundancy, :line, nothing,
            "$(length(parallel)) bus pair(s) have more than one line — parallel lines are " *
            "unusual in distribution networks and may indicate a data conversion artefact " *
            "($total lines across $(length(parallel)) pair(s)).",
            Dict{String,Any}(
                "n_groups" => length(parallel),
                "groups"   => [Dict{String,Any}(
                    "bus_from" => e[1][1],
                    "bus_to"   => e[1][2],
                    "line_ids" => e[2])
                    for e in parallel])))
    end
    Dict{String,Any}(
        "n_groups" => length(parallel),
        "groups"   => [Dict{String,Any}(
            "bus_from" => e[1][1],
            "bus_to"   => e[1][2],
            "line_ids" => e[2])
            for e in parallel])
end

function _check_zero_shunts(net, findings)
    zero_shunts = String[]
    for (id, s) in get(net, "shunt", Dict())
        # Inert if every G_i_j / B_i_j matrix entry is zero
        all_zero = all(
            Float64(v) == 0.0
            for (k, v) in s
            if match(r"^[GB]_\d+_\d+$", k) !== nothing
        )
        all_zero && push!(zero_shunts, id)
    end
    if !isempty(zero_shunts)
        push!(findings, Finding(INFO, "I.RED.ZERO_SHUNTS", :redundancy, :shunt, nothing,
            "$(length(zero_shunts)) shunt(s) have all-zero G and B — electrically inert.",
            Dict{String,Any}("shunts" => zero_shunts)))
    end
    Dict{String,Any}("n" => length(zero_shunts), "ids" => zero_shunts)
end

function _check_unused_linecodes(net, findings)
    defined  = Set(keys(get(net, "linecode", Dict())))
    used     = Set(string(get(l, "linecode", ""))
                   for (_, l) in get(net, "line", Dict())
                   if haskey(l, "linecode"))
    unused   = setdiff(defined, used)
    if !isempty(unused)
        push!(findings, Finding(INFO, "I.RED.UNUSED_LINECODES", :redundancy, :linecode, nothing,
            "$(length(unused)) linecode(s) defined but not referenced by any line.",
            Dict{String,Any}("linecodes" => collect(unused))))
    end
    Dict{String,Any}("n" => length(unused), "ids" => collect(unused))
end

function _check_duplicate_linecodes(net, findings)
    linecodes = get(net, "linecode", Dict())
    # Compare R_series_1_1 and X_series_1_1 as a fingerprint. Linecodes
    # missing both fields are skipped — absent data is not evidence of
    # duplication.
    fingerprints = Dict{Tuple,Vector{String}}()
    for (id, lc) in linecodes
        haskey(lc, "R_series_1_1") || haskey(lc, "X_series_1_1") || continue
        r = round(Float64(get(lc, "R_series_1_1", 0.0)), digits=9)
        x = round(Float64(get(lc, "X_series_1_1", 0.0)), digits=9)
        push!(get!(fingerprints, (r, x), String[]), id)
    end
    dups = [(fp, ids) for (fp, ids) in fingerprints if length(ids) > 1]
    if !isempty(dups)
        push!(findings, Finding(INFO, "I.RED.DUPLICATE_LINECODES", :redundancy,
            :linecode, nothing,
            "$(length(dups)) group(s) of linecodes share identical R_series_1_1/X_series_1_1.",
            Dict{String,Any}("n_groups" => length(dups),
                             "groups"   => [ids for (_, ids) in dups])))
    end
    Dict{String,Any}("n_duplicate_groups" => length(dups),
                     "groups" => [ids for (_, ids) in dups])
end
