# validation/spec_conformance.jl
#
# Conformance checks against the IEEE Task Force data model specification
# ("Mathematical Model and Data Model for Up-To-Four-Wire Distribution
# System OPF") that the JSON Schema cannot express, plus benchmark-readiness
# assessment with augmentation suggestions.

# Spec §3.4 / Table 4: required terminal-map arity per load configuration
const _CONFIG_ARITY = Dict{String,Int}(
    "SINGLE_PHASE" => 2,   # between any two nodes
    "WYE"          => 4,   # three phases + midpoint return
    "DELTA"        => 3
)

# Inverter extension §3.6': required terminal-map arity per topology
const _INVERTER_ARITY = Dict{String,Int}(
    "SINGLE_PHASE" => 2,   # two terminals p, q
    "THREE_LEG"    => 3,   # phases a, b, c (no neutral current)
    "FOUR_LEG"     => 4    # phases a, b, c, n
)

const _PRIME_MOVER_VALUES = ("PV", "BATTERY", "GENERIC")

# Spec §4.2: terminal-map arities (from, to) per transformer subtype
const _XFMR_ARITY = Dict{String,Tuple{Int,Int}}(
    "single_phase" => (2, 2),
    "center_tap"   => (2, 3),
    "wye_delta"    => (4, 3),
    "delta_wye"    => (3, 4),
    "single_phase_autotransformer" => (2, 2),  # phase + shared neutral, both sides
    "open_delta_regulator"         => (4, 4)   # 3 phases + neutral, both sides
)

"""
    spec_conformance_check(net, findings) -> Dict{String,Any}

Check conformance with the TF data model beyond what the JSON Schema can
express:

- exactly one voltage source (spec Eq. 17);
- load/generator configuration strings and configuration ↔ terminal-map
  arity consistency (SINGLE_PHASE = 2, WYE = 4, DELTA = 3 terminals);
- transformer terminal-map arities per subtype;
- linecode impedance matrices stored with all n² entries (spec §4.1.1
  row-first format) rather than upper-triangular shorthand.
"""
function spec_conformance_check(net::Dict{String,Any},
                                 findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()
    n_issues = 0

    # --- terminal identifiers were non-string in the source file ---
    tc = get(get(net, "_meta", Dict()), "terminal_coercions", nothing)
    if tc isa Dict
        n_issues += 1
        push!(findings, Finding(WARNING, "W.SPEC.TERMINAL_TYPES", :spec,
            :network, nothing,
            "$(tc["n"]) terminal identifier(s) in the source file were not " *
            "strings (spec requires strings); coerced at parse via " *
            "$(tc["mode"] == "aliases" ? "the 1→\"1\", 2→\"2\", 3→\"3\", 4→\"n\" convention" :
              "verbatim decimal strings (exotic terminals present — supply an explicit terminal_aliases mapping if this is wrong)").",
            Dict{String,Any}("n" => tc["n"], "mode" => tc["mode"])))
    end

    # --- exactly one voltage source ---
    n_src = length(get(net, "voltage_source", Dict()))
    result["n_voltage_sources"] = n_src
    if n_src != 1
        n_issues += 1
        push!(findings, Finding(WARNING, "W.SPEC.N_SOURCES", :spec,
            :voltage_source, nothing,
            "Spec requires exactly one voltage source; found $n_src.",
            Dict{String,Any}("n" => n_src)))
    end

    # --- nodal element configuration / arity / semantic terminal checks ---
    buses = get(net, "bus", Dict())
    bus_neutral(bid) = begin
        b = get(buses, bid, nothing)
        b isa Dict ? _neutral_terminal(b) : nothing
    end

    for comp_type in ("load", "generator")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            cfg = get(c, "configuration", nothing)
            cfg isa AbstractString || continue
            if !(cfg in keys(_CONFIG_ARITY))
                n_issues += 1
                push!(findings, Finding(WARNING, "W.SPEC.BAD_CONFIG", :spec,
                    Symbol(comp_type), id,
                    "$comp_type '$id' has configuration '$cfg' — spec allows " *
                    "SINGLE_PHASE, WYE, DELTA.", nothing))
                continue
            end
            arity = _CONFIG_ARITY[cfg]
            tm = Vector{String}(string.(get(c, "terminal_map", String[])))
            if length(tm) != arity
                n_issues += 1
                push!(findings, Finding(WARNING, "W.SPEC.CONFIG_ARITY", :spec,
                    Symbol(comp_type), id,
                    "$comp_type '$id': configuration $cfg requires $arity " *
                    "terminal(s), terminal_map has $(length(tm)).",
                    Dict{String,Any}("configuration" => cfg,
                                     "arity" => length(tm))))
                continue   # semantic checks below assume correct arity
            end

            # --- duplicate terminals ---
            if length(unique(tm)) < length(tm)
                dups = [t for t in unique(tm) if count(==(t), tm) > 1]
                n_issues += 1
                push!(findings, Finding(ERROR, "E.SPEC.DUPLICATE_TERMINAL", :spec,
                    Symbol(comp_type), id,
                    "$comp_type '$id' has duplicate terminal(s) in terminal_map " *
                    "$(tm): $(join(dups, ", ")).",
                    Dict{String,Any}("terminal_map" => tm, "duplicates" => dups)))
            end

            bid = get(c, "bus", nothing)
            nn  = bid isa AbstractString ? bus_neutral(bid) : nothing

            # --- semantic checks per configuration ---
            if cfg == "SINGLE_PHASE" && nn !== nothing
                t1, t2 = tm[1], tm[2]
                if t1 != nn && t2 != nn
                    # both phase conductors — phase-to-phase (delta) single-phase
                    push!(findings, Finding(INFO, "I.SPEC.LOAD_PHASE_TO_PHASE", :spec,
                        Symbol(comp_type), id,
                        "$comp_type '$id' (SINGLE_PHASE) connects terminals " *
                        "'$t1' and '$t2', neither of which is the neutral '$nn' of " *
                        "bus '$bid' -- this is a phase-to-phase (delta-connected) " *
                        "single-phase element.",
                        Dict{String,Any}("bus" => bid, "terminals" => tm,
                                         "neutral" => nn)))
                end
                # t1==nn && t2!=nn is already caught by E.TMAP.PHASE_TO_NEUTRAL
            end

            if cfg == "WYE" && nn !== nothing
                phase_tms = tm[1:end-1]
                neutral_tm = tm[end]
                if neutral_tm != nn
                    n_issues += 1
                    push!(findings, Finding(ERROR, "E.SPEC.WYE_MISSING_NEUTRAL", :spec,
                        Symbol(comp_type), id,
                        "$comp_type '$id' (WYE) last terminal '$neutral_tm' is not " *
                        "the neutral '$nn' of bus '$bid' -- return path is not the neutral.",
                        Dict{String,Any}("bus" => bid, "terminal_map" => tm,
                                         "neutral" => nn, "last_terminal" => neutral_tm)))
                end
                dups_phase = [t for t in unique(phase_tms) if count(==(t), phase_tms) > 1]
                if !isempty(dups_phase)
                    n_issues += 1
                    push!(findings, Finding(ERROR, "E.SPEC.WYE_DUPLICATE_PHASE", :spec,
                        Symbol(comp_type), id,
                        "$comp_type '$id' (WYE) has duplicate phase terminal(s): " *
                        "$(join(dups_phase, ", ")).",
                        Dict{String,Any}("terminal_map" => tm,
                                         "duplicates" => dups_phase)))
                end
            end

            if cfg == "DELTA" && nn !== nothing
                neutral_in_delta = filter(t -> t == nn, tm)
                if !isempty(neutral_in_delta)
                    n_issues += 1
                    push!(findings, Finding(ERROR, "E.SPEC.DELTA_HAS_NEUTRAL", :spec,
                        Symbol(comp_type), id,
                        "$comp_type '$id' (DELTA) has neutral terminal '$nn' in " *
                        "terminal_map $(tm) -- delta elements must connect phase-to-phase only.",
                        Dict{String,Any}("bus" => bid, "terminal_map" => tm,
                                         "neutral" => nn)))
                end
                phase_tms = filter(t -> t != nn, tm)
                dups_phase = [t for t in unique(phase_tms) if count(==(t), phase_tms) > 1]
                if !isempty(dups_phase)
                    n_issues += 1
                    push!(findings, Finding(ERROR, "E.SPEC.DELTA_DUPLICATE_PHASE", :spec,
                        Symbol(comp_type), id,
                        "$comp_type '$id' (DELTA) has duplicate phase terminal(s): " *
                        join(dups_phase, ", ") * ".",
                        Dict{String,Any}("terminal_map" => tm,
                                         "duplicates" => dups_phase)))
                end
            end
        end
    end

    # --- duplicate terminals in lines and switches ---
    for comp_type in ("line", "switch")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            for side in ("terminal_map_from", "terminal_map_to")
                tm = Vector{String}(string.(get(c, side, String[])))
                if length(unique(tm)) < length(tm)
                    dups = [t for t in unique(tm) if count(==(t), tm) > 1]
                    n_issues += 1
                    push!(findings, Finding(ERROR, "E.SPEC.DUPLICATE_TERMINAL", :spec,
                        Symbol(comp_type), id,
                        "$comp_type '$id' $side has duplicate terminal(s): " *
                        join(dups, ", ") * ".",
                        Dict{String,Any}("side" => side, "terminal_map" => tm,
                                         "duplicates" => dups)))
                end
            end
        end
    end

    # --- transformer terminal-map arities ---
    xfmr = get(net, "transformer", Dict())
    for (subtype, (a_from, a_to)) in _XFMR_ARITY
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            nf = length(get(t, "terminal_map_from", String[]))
            nt = length(get(t, "terminal_map_to",   String[]))
            if nf != a_from || nt != a_to
                n_issues += 1
                push!(findings, Finding(WARNING, "W.SPEC.XFMR_TMAP_ARITY", :spec,
                    :transformer, id,
                    "transformer $subtype '$id': spec requires terminal maps " *
                    "of length $a_from/$a_to; found $nf/$nt.",
                    Dict{String,Any}("subtype" => subtype,
                                     "from" => nf, "to" => nt)))
            end
        end
    end

    # --- inverter topology / prime-mover / arity (inverter extension §3.6') ---
    n_inv_issues = 0
    for (id, c) in get(net, "inverter", Dict())
        c isa Dict || continue
        topo = get(c, "topology", nothing)
        pm   = get(c, "prime_mover", nothing)

        if pm isa AbstractString && !(pm in _PRIME_MOVER_VALUES)
            n_inv_issues += 1
            push!(findings, Finding(WARNING, "W.SPEC.INV_PRIME_MOVER", :spec,
                :inverter, id,
                "inverter '$id' has prime_mover '$pm' — spec allows " *
                "PV, BATTERY, GENERIC.", nothing))
        end

        if !(topo isa AbstractString) || !haskey(_INVERTER_ARITY, topo)
            n_inv_issues += 1
            push!(findings, Finding(WARNING, "W.SPEC.INV_TOPOLOGY", :spec,
                :inverter, id,
                "inverter '$id' has topology '$(topo)' — spec allows " *
                "SINGLE_PHASE, THREE_LEG, FOUR_LEG.", nothing))
            continue   # arity check below needs a known topology
        end

        arity = _INVERTER_ARITY[topo]
        tm = Vector{String}(string.(get(c, "terminal_map", String[])))
        if length(tm) != arity
            n_inv_issues += 1
            push!(findings, Finding(WARNING, "W.SPEC.INV_TMAP_ARITY", :spec,
                :inverter, id,
                "inverter '$id': topology $topo requires $arity terminal(s), " *
                "terminal_map has $(length(tm)).",
                Dict{String,Any}("topology" => topo, "arity" => length(tm))))
        end
        if length(unique(tm)) < length(tm)
            dups = [t for t in unique(tm) if count(==(t), tm) > 1]
            n_inv_issues += 1
            push!(findings, Finding(ERROR, "E.SPEC.DUPLICATE_TERMINAL", :spec,
                :inverter, id,
                "inverter '$id' has duplicate terminal(s) in terminal_map " *
                "$(tm): $(join(dups, ", ")).",
                Dict{String,Any}("terminal_map" => tm, "duplicates" => dups)))
        end
    end
    result["n_inverter_issues"] = n_inv_issues
    n_issues += n_inv_issues

    # --- terminal map conventions ---
    _check_terminal_map_conventions!(net, findings, result)

    # --- linecode matrix storage: full row-first vs upper-triangular ---
    triangular = String[]
    for (id, lc) in get(net, "linecode", Dict())
        lc isa Dict || continue
        for prefix in ("R_series_", "X_series_")
            entries = Set{Tuple{Int,Int}}()
            n = 0
            for k in keys(lc)
                startswith(k, prefix) || continue
                m = match(r"^(\d+)_(\d+)$", k[length(prefix)+1:end])
                m === nothing && continue
                i, j = parse(Int, m[1]), parse(Int, m[2])
                push!(entries, (i, j))
                n = max(n, i, j)
            end
            n == 0 && continue
            # triangular shorthand: some entries missing, but every missing
            # (i,j) has its transpose present
            mirrored = all(((i, j) in entries) || ((j, i) in entries)
                           for i in 1:n, j in 1:n)
            if length(entries) < n^2 && mirrored
                push!(triangular, id)
                break
            end
        end
    end
    unique!(triangular)
    if !isempty(triangular)
        push!(findings, Finding(INFO, "I.SPEC.MATRIX_TRIANGULAR", :spec,
            :linecode, nothing,
            "$(length(triangular)) linecode(s) store impedance matrices " *
            "upper-triangular; spec §4.1.1 defines full row-first storage: " *
            "$(join(sort(triangular), ", ")).",
            Dict{String,Any}("linecodes" => sort(triangular))))
    end
    result["n_triangular_linecodes"] = length(triangular)
    result["n_conformance_issues"]   = n_issues
    result
end

# ---------------------------------------------------------------------------
# Terminal map convention checks
# ---------------------------------------------------------------------------
#
# Three rules:
#  E.TMAP.PHASE_TO_NEUTRAL — any terminal in a component's map that occupies
#    a phase position but resolves to the bus neutral. "Phase position" is any
#    slot that is not the expected neutral slot: for nodal WYE/SINGLE_PHASE
#    components the neutral slot is the last entry; for DELTA components and
#    lines/switches there is no neutral slot at all. Transformer maps are
#    exempt (non-trivial neutral involvement is expected).
#
#  I.TMAP.CROSS_PHASE_LINE — terminal_map_from != terminal_map_to on a line
#    or switch, implying cross-phase / transposed wiring.
#
#  I.TMAP.PERMUTED_ORDER — the terminal map entries appear in a different
#    relative order than they do in the bus's terminal_names (permuted
#    connection). Phase subsetting is fine; only ordering is flagged.
#    Transformers are exempt.

function _check_terminal_map_conventions!(net, findings, result)
    buses = get(net, "bus", Dict())

    # Helper: neutral terminal name for a bus (nothing if not identified)
    bus_neutral(bid) = begin
        b = get(buses, bid, nothing)
        b isa Dict ? _neutral_terminal(b) : nothing
    end

    # Helper: relative order of terminals as they appear in terminal_names
    # Returns true if `tm` entries appear in the same relative order as in
    # `terminal_names` (subsequence check, ignoring elements not in tm).
    function _ordered_subsequence(tm, terminal_names)
        # Filter terminal_names to only those appearing in tm, then check
        # if that filtered list equals tm.
        tm_set = Set(tm)
        filtered = [t for t in terminal_names if t in tm_set]
        filtered == tm
    end

    n_phase_neutral = 0
    n_cross_phase   = 0
    n_permuted      = 0

    # ── Nodal elements ───────────────────────────────────────────────────────
    # Shunts are exempt from the "all entries neutral" check: a shunt whose
    # terminal_map is purely ["n"] is a neutral-to-ground admittance (NER/
    # grounding impedance), which is a standard and legitimate earthing model.
    for comp_type in ("load", "generator", "shunt", "voltage_source")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue
            bid = get(c, "bus", nothing)
            bid isa AbstractString || continue
            nn  = bus_neutral(bid)
            nn === nothing && continue   # bus has no identified neutral

            tm  = Vector{String}(get(c, "terminal_map", String[]))
            isempty(tm) && continue
            cfg = get(c, "configuration", nothing)

            # Determine the expected neutral slot: last position for WYE and
            # SINGLE_PHASE; none for DELTA.
            neutral_slot = if cfg == "DELTA"
                nothing
            else
                length(tm)   # last position is the expected return/neutral
            end

            # Flag when the map contains no phase conductors at all (every
            # entry is the neutral). Shunts are exempt: terminal_map=["n"] is
            # a valid neutral-to-ground earthing admittance.
            if comp_type != "shunt" && all(string(t) == nn for t in tm)
                n_phase_neutral += 1
                push!(findings, Finding(ERROR, "E.TMAP.PHASE_TO_NEUTRAL", :spec,
                    Symbol(comp_type), id,
                    "$comp_type '$id': terminal_map $tm contains no phase " *
                    "conductors — all entries resolve to neutral '$nn' of bus '$bid'.",
                    Dict{String,Any}("bus" => bid, "neutral" => nn,
                                     "terminal_map" => tm)))
            else
                for (pos, t) in enumerate(tm)
                    string(t) == nn || continue
                    # This entry is the neutral terminal — flag only if it
                    # occupies a phase slot (not the expected trailing slot).
                    if neutral_slot === nothing || pos != neutral_slot
                        n_phase_neutral += 1
                        push!(findings, Finding(ERROR, "E.TMAP.PHASE_TO_NEUTRAL", :spec,
                            Symbol(comp_type), id,
                            "$comp_type '$id': terminal at position $pos is wired " *
                            "to neutral '$nn' of bus '$bid', which is a phase " *
                            "position$(neutral_slot === nothing ? " (DELTA has no neutral slot)" :
                                       " (expected neutral at position $neutral_slot)").",
                            Dict{String,Any}("bus" => bid, "neutral" => nn,
                                             "position" => pos, "terminal_map" => tm)))
                    end
                end
            end

            # Ordering check against bus terminal_names
            b = buses[bid]
            tn = Vector{String}(get(b, "terminal_names", String[]))
            isempty(tn) && continue
            if !_ordered_subsequence(tm, tn)
                n_permuted += 1
                push!(findings, Finding(INFO, "I.TMAP.PERMUTED_ORDER", :spec,
                    Symbol(comp_type), id,
                    "$comp_type '$id' terminal_map $tm is a permutation of the " *
                    "expected order from bus '$bid' terminal_names $tn — check " *
                    "whether phases are wired in the intended order.",
                    Dict{String,Any}("bus" => bid, "terminal_map" => tm,
                                     "terminal_names" => tn)))
            end
        end
    end

    # ── Lines and switches ────────────────────────────────────────────────────
    for comp_type in ("line", "switch")
        for (id, c) in get(net, comp_type, Dict())
            c isa Dict || continue

            tmf = Vector{String}(get(c, "terminal_map_from", String[]))
            tmt = Vector{String}(get(c, "terminal_map_to",   String[]))

            # Cross-phase check
            if !isempty(tmf) && !isempty(tmt) && tmf != tmt
                n_cross_phase += 1
                push!(findings, Finding(INFO, "I.TMAP.CROSS_PHASE_LINE", :spec,
                    Symbol(comp_type), id,
                    "$comp_type '$id' has different from/to terminal maps " *
                    "(from=$tmf, to=$tmt) — implies cross-phase or transposed " *
                    "wiring, which is rare in distribution networks.",
                    Dict{String,Any}("terminal_map_from" => tmf,
                                     "terminal_map_to"   => tmt)))
            end

            # Phase-to-neutral check on each end
            for (side, tm, bus_key) in (("from", tmf, "bus_from"),
                                         ("to",   tmt, "bus_to"))
                bid = get(c, bus_key, nothing)
                bid isa AbstractString || continue
                nn  = bus_neutral(bid)
                nn === nothing && continue
                isempty(tm) && continue
                # For lines/switches there is no "expected" neutral slot — any
                # neutral in the map is flagged only when it also appears in
                # the other end's map at the same position (symmetric neutral
                # return is fine). Asymmetric neutral involvement is flagged
                # via the cross-phase rule already. Here we catch the case
                # where ALL entries are the neutral (degenerate map).
                if all(string(t) == nn for t in tm)
                    n_phase_neutral += 1
                    push!(findings, Finding(ERROR, "E.TMAP.PHASE_TO_NEUTRAL", :spec,
                        Symbol(comp_type), id,
                        "$comp_type '$id' $side terminal map $tm consists " *
                        "entirely of neutral '$nn' at bus '$bid'.",
                        Dict{String,Any}("bus" => bid, "neutral" => nn,
                                         "side" => side, "terminal_map" => tm)))
                end
            end

            # Ordering check on each end against bus terminal_names
            for (tm, bus_key) in ((tmf, "bus_from"), (tmt, "bus_to"))
                bid = get(c, bus_key, nothing)
                bid isa AbstractString || continue
                b = get(buses, bid, nothing)
                b isa Dict || continue
                tn = Vector{String}(get(b, "terminal_names", String[]))
                isempty(tn) || isempty(tm) && continue
                if !_ordered_subsequence(tm, tn)
                    n_permuted += 1
                    push!(findings, Finding(INFO, "I.TMAP.PERMUTED_ORDER", :spec,
                        Symbol(comp_type), id,
                        "$comp_type '$id' terminal map $tm is a permutation of " *
                        "the expected order from bus '$bid' terminal_names $tn.",
                        Dict{String,Any}("bus" => bid, "terminal_map" => tm,
                                         "terminal_names" => tn)))
                end
            end
        end
    end

    result["n_phase_to_neutral"] = n_phase_neutral
    result["n_cross_phase_lines"] = n_cross_phase
    result["n_permuted_terminal_maps"] = n_permuted
end

"""
    benchmark_readiness_check(net, findings) -> Dict{String,Any}

Assess whether the case defines a non-trivial, well-posed OPF benchmark per
the TF spec (generation-cost objective, Eq. 135), and list the augmentation
steps needed to make it one. Also flags degeneracy risks that could cause
primal non-uniqueness or flat objective directions.
"""
function benchmark_readiness_check(net::Dict{String,Any},
                                    findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()
    suggestions = String[]

    # --- objective well-posedness ---
    # The voltage source is the network's priced current slack; a generator with
    # a cost is dispatchable generation. The objective is well-posed if either
    # carries a cost. (Legacy `_slack` generators are still recognised.)
    gens = get(net, "generator", Dict())
    with_cost = [id for (id, g) in gens if g isa Dict && haskey(g, "cost")]
    non_slack = [id for id in with_cost if !get(gens[id], "_slack", false)]
    srcs = get(net, "voltage_source", Dict())
    src_with_cost = [id for (id, vs) in srcs if vs isa Dict && haskey(vs, "cost")]
    has_slack_cost = !isempty(src_with_cost) ||
                     any(id -> get(gens[id], "_slack", false), with_cost)
    result["n_generators"]        = length(gens)
    result["n_with_cost"]         = length(with_cost)
    result["objective_wellposed"] = !isempty(with_cost) || !isempty(src_with_cost)
    # "Only slack generation" = the objective is well-posed but the only priced
    # element is the slack source — dispatch is trivial (loss minimisation).
    result["only_slack_generation"] =
        result["objective_wellposed"] && isempty(non_slack) && has_slack_cost

    if !result["objective_wellposed"]
        push!(suggestions,
            "no priced slack or generator — the generation-cost objective is " *
            "degenerate; add a cost to the voltage source at the source bus " *
            "(from_pmd does this by default) or dispatchable DERs")
    elseif isempty(non_slack)
        push!(suggestions,
            "only slack generation — dispatch is trivial (loss minimisation); " *
            "add dispatchable DERs with diverse costs and p/q bounds")
    end

    # --- voltage bound coverage, incl. the spec's richer bound types ---
    buses = get(net, "bus", Dict())
    n_buses = length(buses)
    n_vb   = count(b -> haskey(b, "v_min")    || haskey(b, "v_max"),    values(buses))
    n_vpn  = count(b -> haskey(b, "vpn_min")  || haskey(b, "vpn_max"),  values(buses))
    n_vpp  = count(b -> haskey(b, "vpp_min")  || haskey(b, "vpp_max"),  values(buses))
    n_vpos = count(b -> haskey(b, "vpos_min") || haskey(b, "vpos_max"), values(buses))
    result["pct_v_bounds"]   = n_buses > 0 ? round(100.0 * n_vb / n_buses, digits=1) : 0.0
    result["n_vpn_bounds"]   = n_vpn
    result["n_vpp_bounds"]   = n_vpp
    result["n_vpos_bounds"]  = n_vpos

    if n_buses > 0 && n_vb == 0
        push!(suggestions,
            "no voltage magnitude bounds on any bus — voltage is " *
            "unconstrained; add v_min/v_max (phase-to-ground)")
    end
    if n_buses > 0 && n_vpos == 0 && n_vpn == 0
        push!(suggestions,
            "no phase-to-neutral or sequence voltage bounds (vpn_*/vpos_*) — " *
            "sequence bounds also improve solver robustness for 4-wire OPF")
    end

    # --- thermal limit coverage ---
    lines     = get(net, "line", Dict())
    linecodes = get(net, "linecode", Dict())
    n_lines = length(lines)
    n_thermal = count(lines) do (_, l)
        lc = get(linecodes, string(get(l, "linecode", "")), Dict())
        haskey(l, "i_max") || haskey(l, "s_max") ||
        haskey(lc, "i_max") || haskey(lc, "s_max")
    end
    result["pct_thermal_limits"] = n_lines > 0 ?
        round(100.0 * n_thermal / n_lines, digits=1) : 0.0
    if n_lines > 0 && n_thermal < n_lines
        push!(suggestions,
            "$(n_lines - n_thermal) of $n_lines lines lack thermal limits — " *
            "add i_max/s_max (e.g. correlated with conductor cross-section)")
    end

    result["suggestions"] = suggestions
    if !isempty(suggestions)
        push!(findings, Finding(INFO, "I.BENCH.AUGMENTATION", :benchmark,
            :network, nothing,
            "Case needs augmentation to be a non-trivial OPF benchmark: " *
            join(suggestions, "; ") * ".",
            Dict{String,Any}("suggestions" => suggestions)))
    end

    # ── Degeneracy risk flags ────────────────────────────────────────────────

    # Helper: is a generator dispatchable (p_min strictly below p_max on at
    # least one phase)?
    function _is_dispatchable(g)
        g isa Dict || return false
        pmn = Float64.(get(g, "p_min", Float64[]))
        pmx = Float64.(get(g, "p_max", Float64[]))
        isempty(pmx) && return false
        any(i -> length(pmn) >= i && pmx[i] - pmn[i] > 0.0, eachindex(pmx))
    end

    # (1) Generators with no degrees of freedom (p_min == p_max on every phase)
    no_dof = String[]
    for (id, g) in gens
        g isa Dict || continue
        pmn = Float64.(get(g, "p_min", Float64[]))
        pmx = Float64.(get(g, "p_max", Float64[]))
        isempty(pmx) && continue
        n_ph = length(pmx)
        if all(i -> length(pmn) >= i && pmx[i] ≈ pmn[i], 1:n_ph)
            push!(no_dof, id)
        end
    end
    result["n_gen_no_dof"] = length(no_dof)
    if !isempty(no_dof)
        push!(findings, Finding(WARNING, "W.BENCH.GEN_NO_DOF", :benchmark,
            :generator, nothing,
            "$(length(no_dof)) generator(s) have p_min ≈ p_max on all phases — " *
            "fixed output, not dispatchable: $(join(sort(no_dof), ", ")).",
            Dict{String,Any}("generators" => sort(no_dof))))
    end

    # (2) Generators with cost = 0 (flat objective direction)
    zero_cost = String[]
    for (id, g) in gens
        g isa Dict || continue
        _is_dispatchable(g) || continue   # fixed generators can't move anyway
        cost = Float64.(get(g, "cost", Float64[]))
        if !isempty(cost) && all(c -> c ≈ 0.0, cost)
            push!(zero_cost, id)
        end
    end
    result["n_gen_zero_cost"] = length(zero_cost)
    if !isempty(zero_cost)
        push!(findings, Finding(WARNING, "W.BENCH.GEN_ZERO_COST", :benchmark,
            :generator, nothing,
            "$(length(zero_cost)) dispatchable generator(s) have cost = 0 — " *
            "their dispatch is underdetermined (flat objective direction): " *
            "$(join(sort(zero_cost), ", ")).",
            Dict{String,Any}("generators" => sort(zero_cost))))
    end

    # (3) Same-cost dispatchable generators on the same bus or one hop away
    #     (primal non-uniqueness: solver can exchange power between them freely)
    bus_adj = Dict{String,Set{String}}()
    for (_, l) in lines
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        push!(get!(bus_adj, f, Set{String}()), t)
        push!(get!(bus_adj, t, Set{String}()), f)
    end
    for (_, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        push!(get!(bus_adj, f, Set{String}()), t)
        push!(get!(bus_adj, t, Set{String}()), f)
    end

    disp_gens = [(id, g) for (id, g) in gens if g isa Dict && _is_dispatchable(g)]
    same_cost_pairs = Tuple{String,String,Float64}[]
    for i in eachindex(disp_gens), j in (i+1):length(disp_gens)
        id_a, ga = disp_gens[i]
        id_b, gb = disp_gens[j]
        cost_a = Float64.(get(ga, "cost", Float64[]))
        cost_b = Float64.(get(gb, "cost", Float64[]))
        isempty(cost_a) || isempty(cost_b) && continue
        # Compare first (representative) cost coefficient
        abs(cost_a[1] - cost_b[1]) > 1e-12 * max(abs(cost_a[1]), 1.0) && continue
        bus_a = get(ga, "bus", ""); bus_b = get(gb, "bus", "")
        same_bus  = bus_a == bus_b
        one_hop   = bus_b in get(bus_adj, bus_a, Set{String}())
        (same_bus || one_hop) || continue
        push!(same_cost_pairs, (id_a, id_b, cost_a[1]))
    end
    result["n_same_cost_gen_pairs"] = length(same_cost_pairs)
    if !isempty(same_cost_pairs)
        pair_strs = ["($a, $b)" for (a, b, _) in same_cost_pairs]
        push!(findings, Finding(WARNING, "W.BENCH.GEN_DEGENERATE_COST", :benchmark,
            :generator, nothing,
            "$(length(same_cost_pairs)) pair(s) of dispatchable generators share " *
            "the same cost and are electrically close (same bus or one hop) — " *
            "optimal dispatch is primal non-unique: $(join(pair_strs, ", ")).",
            Dict{String,Any}("pairs" => [[a, b] for (a, b, _) in same_cost_pairs])))
    end

    # (4) Loads with zero p_nom entries
    zero_pnom_loads = String[]
    for (id, l) in get(net, "load", Dict())
        l isa Dict || continue
        pnom = Float64.(get(l, "p_nom", Float64[]))
        if !isempty(pnom) && all(p -> p ≈ 0.0, pnom)
            push!(zero_pnom_loads, id)
        end
    end
    result["n_loads_zero_pnom"] = length(zero_pnom_loads)
    if !isempty(zero_pnom_loads)
        push!(findings, Finding(INFO, "I.BENCH.LOAD_ZERO_PNOM", :benchmark,
            :load, nothing,
            "$(length(zero_pnom_loads)) load(s) have p_nom = 0 on all phases — " *
            "these loads impose no real power demand: " *
            "$(join(sort(zero_pnom_loads), ", ")).",
            Dict{String,Any}("loads" => sort(zero_pnom_loads))))
    end

    result
end
