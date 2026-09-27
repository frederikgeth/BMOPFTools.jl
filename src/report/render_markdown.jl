# report/render_markdown.jl

"""
    render_markdown(report, io; verbose)

Write a Markdown-formatted report to `io`.
"""
function render_markdown(report::SummaryReport, io::IO; verbose::Bool=true)
    name = something(report.network_name, "Unnamed Network")
    println(io, "# BMOPF Network Summary: $name\n")
    println(io, "**Generated:** $(Dates.format(report.generated_at, "yyyy-mm-dd HH:MM:SS"))  ")
    errs  = errors(report)
    warns = warnings(report)
    infs  = infos(report)
    println(io, "**Findings:** $(length(errs)) errors · $(length(warns)) warnings · $(length(infs)) info  ")
    prov = get(report.results, :provenance, nothing)
    if prov isa Dict && haskey(prov, "convention")
        println(io, "**Convention:** $(prov["convention"])")
    end
    println(io)
    println(io, "---\n")

    _md_inventory(report, io)
    _md_voltage_levels(report, io)
    _md_connectivity(report, io)
    _md_diversity(report, io)
    _md_operational(report, io)
    _md_preflight(report, io)
    _md_provenance(report, io)
    _md_spec_benchmark(report, io)
    _md_quality(report, io; verbose)
end

function _md_inventory(r::SummaryReport, io::IO)
    d = get(r.results, :inventory, nothing)
    d === nothing && return
    println(io, "## 1. Component Inventory\n")
    println(io, "| Component | Count | Notes |")
    println(io, "|-----------|------:|-------|")

    components = ["bus","line","linecode","voltage_source","load",
                  "generator","shunt","switch","transformer",
                  "ibr","control_profile"]
    for comp in components
        info = get(d, comp, nothing)
        info isa Dict || continue
        n = get(info, "total", 0)
        notes = ""
        if comp == "load"
            notes = "$(_fmt_mw(get(info,"total_p_w",0.0))), $(_fmt_mvar(get(info,"total_q_var",0.0)))"
        elseif comp == "generator"
            notes = "capacity: $(_fmt_mw(get(info,"total_p_cap_w",0.0)))"
        elseif comp == "transformer"
            byvg = get(info, "by_vector_group", Dict())
            if !isempty(byvg)
                notes = join(["$vg×$c" for (vg,c) in sort(collect(byvg))], ", ")
            else
                bytype = get(info, "by_type", Dict())
                isempty(bytype) || (notes = join(["$t×$c" for (t,c) in bytype], ", "))
            end
        elseif comp == "ibr"
            cap = round(get(info, "total_s_max_va", 0.0) / 1e6, digits=3)
            bypm = get(info, "by_prime_mover", Dict())
            pm_str = isempty(bypm) ? "" :
                " (" * join(["$pm×$c" for (pm,c) in sort(collect(bypm))], ", ") * ")"
            notes = "capacity: $cap MVA$pm_str"
        end
        println(io, "| $comp | $n | $notes |")
    end
    println(io)
    _md_section_findings(r, io, :inventory)
end

function _md_voltage_levels(r::SummaryReport, io::IO)
    d = get(r.results, :voltage_levels, nothing)
    d === nothing && return
    println(io, "## 2. Voltage Levels\n")
    levels = get(d, "levels", Dict())
    println(io, "**Voltage levels identified:** $(get(d,"n_levels",0))\n")

    println(io, "| Level | Nominal | Buses | Lines | Loads | Generators |")
    println(io, "|-------|---------|------:|------:|------:|-----------:|")
    for (label, linfo) in sort(collect(levels), by=x -> -x[2]["nominal_v"])
        println(io, "| $label | $(_fmt_kv(linfo["nominal_v"])) | $(linfo["n_buses"]) | " *
                    "$(linfo["n_lines"]) | $(linfo["n_loads"]) | $(linfo["n_generators"]) |")
    end
    println(io)

    transitions = get(d, "transformer_transitions", Any[])
    if !isempty(transitions)
        println(io, "**Transformer transitions:**\n")
        for tr in transitions
            vg = get(tr, "vector_group", "")
            vg_str = isempty(vg) ? tr["subtype"] : "$(tr["subtype"]), $vg"
            println(io, "- `$(tr["id"])`: $(tr["level_from"]) → $(tr["level_to"]) ($vg_str)")
        end
        println(io)
    end
    _md_section_findings(r, io, :voltage_levels)
end

function _md_connectivity(r::SummaryReport, io::IO)
    d = get(r.results, :connectivity, nothing)
    d === nothing && return
    println(io, "## 3. Connectivity & Topology\n")

    n_comp = get(d, "n_components", "?")
    radial = get(d, "is_radial", "?")
    println(io, "| Property | Value |")
    println(io, "|----------|-------|")
    println(io, "| Connected components | $n_comp |")
    println(io, "| Fully connected | $(get(d,"is_connected","?")) |")
    println(io, "| Topology | $(radial == true ? "Radial" : "Meshed") |")
    println(io, "| Mean degree | $(round(Float64(get(d,"degree_mean",0)), digits=2)) |")
    println(io, "| Max degree | $(get(d,"degree_max","?")) |")
    println(io, "| Degree-1 buses | $(get(d,"n_degree_1","?")) |")
    println(io, "| Tree depth (max hops) | $(get(d,"tree_depth_max","?")) |")
    println(io)
    structure = get(d, "structure", nothing)
    if structure isa Dict
        whole = structure["whole_network"]
        println(io, "### Physical branch structure\n")
        println(io, "| Scope | Buses | Components | Branches | Simple cycles | Parallel excess | Total cycle rank |")
        println(io, "|---|---:|---:|---:|---:|---:|---:|")
        function row(label, counts)
            println(io, "| $label | $(counts["n_buses"]) | $(counts["n_components"]) | " *
                "$(counts["n_physical_edges"]) | $(counts["simple_cycle_rank"]) | " *
                "$(counts["parallel_excess"]) | $(counts["cycle_rank"]) |")
        end
        row("Whole network", whole)
        for tier in structure["voltage_tiers"]
            row("Tier $(tier["level"])", tier)
        end
        println(io, "\nTransformer-mediated cycle rank: $(whole["transformer_mediated_cycle_rank"]); " *
            "cross-tier branches: $(structure["n_cross_tier_edges"]); " *
            "skipped invalid branches: $(structure["n_skipped_branches"]).\n")
        zones = structure["galvanic_zones"]
        println(io, "Galvanic zones: $(length(zones)); zones with simple cycles: " *
            "$(count(z -> z["simple_cycle_rank"] > 0, zones)); " *
            "zones incident to multiple isolating transformers: " *
            "$(count(z -> z["n_incident_isolating_transformers"] > 1, zones)).\n")
        interesting = sort!(filter(z -> z["cycle_rank"] > 0 ||
                            z["n_incident_isolating_transformers"] > 1, zones),
                            by=z -> (-z["cycle_rank"], -z["n_incident_isolating_transformers"], z["anchor"]))
        if !isempty(interesting)
            println(io, "| Galvanic zone anchor | Levels | Buses | Cycle rank | Parallel excess | Incident transformers |")
            println(io, "|---|---|---:|---:|---:|---:|")
            for zone in Iterators.take(interesting, 10)
                println(io, "| $(zone["anchor"]) | $(join(zone["voltage_levels"], ", ")) | " *
                    "$(zone["n_buses"]) | $(zone["cycle_rank"]) | " *
                    "$(zone["parallel_excess"]) | $(zone["n_incident_isolating_transformers"]) |")
            end
            println(io)
        end
        parallel = structure["parallel_lines"]
        println(io, "Parallel line groups: $(parallel["n_groups"]). " *
            "Classification counts: " *
            join(["$k=$(parallel["classification_counts"][k])" for k in
                  sort!(collect(keys(parallel["classification_counts"])))], ", ") * ".\n")
        if !isempty(parallel["witnesses"])
            println(io, "| Bus pair | Line IDs | Declared-field class |")
            println(io, "|---|---|---|")
            for witness in parallel["witnesses"]
                println(io, "| $(join(witness["bus_pair"], " ↔ ")) | " *
                    "$(join(witness["line_ids"], ", ")) | $(witness["classification"]) |")
            end
            println(io)
        end
        closing = structure["cycle_closing_branches"]
        if !isempty(closing)
            println(io, "First $(length(closing)) spanning-forest closing branches " *
                "(graph witnesses, not defect assignments):")
            for witness in closing
                println(io, "- `$(witness["kind"]):$(witness["component_id"])`: " *
                    "$(witness["bus_from"]) ↔ $(witness["bus_to"])")
            end
            println(io)
        end
        paths = structure["conductor_paths"]
        println(io, "### Mapped conductor paths\n")
        if paths["status"] == "inapplicable"
            println(io, "$(paths["reason"])\n")
        else
            println(io, "$(paths["n_bus_terminals"]) declared bus terminals; " *
                "$(paths["n_mapped_conductor_edges"]) mapped line/closed-switch conductor edges; " *
                "$(paths["n_path_components"]) terminal-path components; " *
                "$(paths["n_skipped_branches"]) incomplete branch maps. " *
                "Transformer winding ports bound these paths; winding conversion is unassessed.\n")
            if paths["n_load_terminals_without_boundary"] !== nothing
                println(io, "Load terminals in paths without a source or transformer port: " *
                    "$(paths["n_load_terminals_without_boundary"]).\n")
                for witness in paths["load_terminal_witnesses"]
                    println(io, "- `$(witness["load_id"])` at " *
                        "$(witness["bus"]):$(witness["terminal"]) " *
                        "(path $(witness["path_component"]))")
                end
                isempty(paths["load_terminal_witnesses"]) || println(io)
            end
        end

    end
    scenarios = get(d, "switch_scenarios", nothing)
    if scenarios isa Dict
        println(io, "### Switch-state bus graph\n")
        status = scenarios["status"]
        switches = scenarios["switch_counts"]
        if status != "assessed"
            println(io, "$(status): $(scenarios["assessment"]["reason"])\n")
            if status == "indeterminate"
                println(io, "Invalid switch IDs: $(join(scenarios["assessment"]["invalid_switch_ids"], ", ")).\n")
            end
        else
            println(io, "$(switches["n_declared_open"]) open and $(switches["n_declared_closed"]) closed switches. " *
                "These views describe bus-graph paths, not energization or feasible operations.\n")
            println(io, "| View | Components | Physical edges | Cycle rank | Parallel excess | Components with source | Buses without source path | Loads without source path |")
            println(io, "|---|---:|---:|---:|---:|---:|---:|---:|")
            for (label, key) in (("Declared", "declared"), ("Fixed backbone", "fixed_backbone"),
                                 ("All closed", "all_closed_envelope"))
                view = scenarios[key]
                println(io, "| $label | $(view["n_components"]) | $(view["n_physical_edges"]) | " *
                    "$(view["cycle_rank"]) | $(view["parallel_excess"]) | " *
                    "$(view["n_components_with_source"]) | $(view["n_buses_without_source_path"]) | " *
                    "$(view["n_loads_without_source_path"]) |")
            end
            println(io)
            transitions = scenarios["transition_counts"]
            println(io, "One-switch transitions: " *
                join(["$k=$(transitions["classifications"][k])" for k in
                      sort!(collect(keys(transitions["classifications"])))], ", ") * ". " *
                "$(transitions["n_switches_gaining_source_path"]) may add source paths; " *
                "$(transitions["n_switches_losing_source_path"]) may remove them; " *
                "$(transitions["n_source_component_joins"]) join source-containing components.\n")
            if !isempty(scenarios["witnesses"])
                println(io, "| Switch | State | Endpoints | Transition | Δ components | Δ cycle rank | Source-path buses gained/lost |")
                println(io, "|---|---|---|---|---:|---:|---:|")
                for witness in scenarios["witnesses"]
                    println(io, "| $(witness["switch_id"]) | $(witness["declared_state"]) | " *
                        "$(witness["bus_from"]) ↔ $(witness["bus_to"]) | " *
                        "$(witness["classification"]) | $(witness["delta_components"]) | " *
                        "$(witness["delta_cycle_rank"]) | " *
                        "$(witness["n_buses_gaining_source_path"])/$(witness["n_buses_losing_source_path"]) |")
                end
                println(io)
            end
        end
        conductor = get(scenarios, "conductor", nothing)
        if conductor isa Dict
            println(io, "### Switch-state mapped conductor paths\n")
            if conductor["status"] != "assessed"
                reason = get(get(conductor, "assessment", Dict{String,Any}()),
                             "reason", get(conductor, "reason", ""))
                println(io, "$(conductor["status"]): $reason\n")
                if haskey(conductor, "assessment")
                    invalid = conductor["assessment"]
                    for (label, key) in (("Incomplete bus terminals", "invalid_bus_ids"),
                                         ("Incomplete branch maps", "invalid_branch_map_ids"),
                                         ("Incomplete load maps", "invalid_load_ids"),
                                         ("Incomplete boundary ports", "invalid_boundary_port_ids"))
                        isempty(invalid[key]) || println(io, "$label: $(join(invalid[key], ", ")).")
                    end
                    any(!isempty(invalid[key]) for key in
                        ("invalid_bus_ids", "invalid_branch_map_ids",
                         "invalid_load_ids", "invalid_boundary_port_ids")) &&
                        println(io)
                end
            else
                println(io, "Source and transformer ports are path boundaries; winding conversion and " *
                    "energization are unassessed.\n")
                println(io, "| View | Terminal paths | Boundary paths | Load terminals without boundary |")
                println(io, "|---|---:|---:|---:|")
                for (label, key) in (("Declared", "declared"),
                                     ("Fixed backbone", "fixed_backbone"),
                                     ("All closed", "all_closed_envelope"))
                    view = conductor[key]
                    println(io, "| $label | $(view["n_path_components"]) | " *
                        "$(view["n_boundary_components"]) | " *
                        "$(view["n_load_terminals_without_boundary"]) |")
                end
                println(io)
                transitions = conductor["transition_counts"]
                println(io, "One-switch path changes: " *
                    join(["$k=$(transitions["classifications"][k])" for k in
                          sort!(collect(keys(transitions["classifications"])))], ", ") * ". " *
                    "$(transitions["n_switches_gaining_load_boundary_path"]) may add load-terminal boundary paths; " *
                    "$(transitions["n_switches_losing_load_boundary_path"]) may remove them.\n")
                println(io, "Bus/conductor transition pairs: " *
                    join(["$k=$(conductor["cross_layer_counts"][k])" for k in
                          sort!(collect(keys(conductor["cross_layer_counts"])))], ", ") * ".\n")
                impact = filter(w -> w["delta_path_components"] != 0 ||
                                   w["n_load_terminals_gaining_boundary_path"] != 0 ||
                                   w["n_load_terminals_losing_boundary_path"] != 0,
                                conductor["witnesses"])
                if !isempty(impact)
                    println(io, "| Switch | State | Bus graph | Conductor | Mapped pairs | Δ paths | Load terminals gaining/losing boundary path |")
                    println(io, "|---|---|---|---|---:|---:|---:|")
                    for witness in Iterators.take(impact, 10)
                        println(io, "| $(witness["switch_id"]) | $(witness["declared_state"]) | " *
                            "$(witness["bus_graph_classification"]) | " *
                            "$(witness["classification"]) | " *
                            "$(witness["n_mapped_terminal_pairs"]) | " *
                            "$(witness["delta_path_components"]) | " *
                            "$(witness["n_load_terminals_gaining_boundary_path"])/$(witness["n_load_terminals_losing_boundary_path"]) |")
                    end
                    println(io)
                end
            end
        end
    end
    _md_spatial(get(d, "spatial", nothing), io)
    _md_section_findings(r, io, :connectivity)
end

function _md_spatial(spatial, io::IO)
    spatial isa Dict || return
    coverage = spatial["coordinate_coverage"]
    reference = spatial["coordinate_reference"]
    routes = spatial["routes"]
    lines = spatial["lines"]
    transformers = spatial["transformers"]
    println(io, "### Geographic evidence\n")
    println(io, "Bus coordinates: $(coverage["n_complete_lonlat"])/$(coverage["n_buses"]) " *
        "complete longitude/latitude pairs; $(coverage["n_with_xy_fields"]) buses with x/y fields; " *
        "$(coverage["n_partial"]) partial, $(coverage["n_invalid"]) invalid, " *
        "$(coverage["n_outside_wgs84_range"]) outside WGS84 numeric ranges.\n")
    println(io, "**Coordinate reference:** $(reference["status"]). " *
        "$(reference["caution"])\n")
    println(io, "Line routes: $(routes["n_with_route"])/$(routes["n_lines"]); " *
        "$(reference["n_matching_wgs84_routes"]) WGS84 routes match their bus endpoints.\n")
    println(io, "| Voltage tier | Lines with length | Median length (m) | 99th percentile (m) | Maximum (m) |")
    println(io, "|---|---:|---:|---:|---:|")
    for (tier, stats) in sort!(collect(lines["length_by_tier_m"]), by=first)
        println(io, "| $tier | $(stats["n"]) | $(round(stats["p50"], digits=1)) | " *
            "$(round(stats["p99"], digits=1)) | $(round(stats["max"], digits=1)) |")
    end
    println(io)
    if !isempty(lines["relative_length_witnesses"])
        println(io, "Longest lines relative to their voltage-tier 99th percentile:")
        for witness in Iterators.take(lines["relative_length_witnesses"], 5)
            println(io, "- `$(witness["line_id"])` ($(witness["tier"])): " *
                "$(round(witness["length_m"], digits=1)) m " *
                "($(round(witness["relative_to_tier_p99"], digits=1))× tier p99)")
        end
        println(io)
    end
    if reference["geodesic_distances_applicable"]
        xf = transformers["separation_m"]
        println(io, "Geodesic comparisons: $(lines["n_with_chord_comparison"]) lines with endpoint distances; " *
            "$(something(lines["n_shorter_than_chord_beyond_tolerance"], "unassessed")) declared lengths below their " *
            "endpoint chord by more than max(5 m, 10% of chord). " *
            "Route endpoint gaps over 5 m: " *
            "$(something(routes["n_endpoint_gaps_over_5m"], "unassessed")) " *
            "of $(routes["n_endpoint_comparisons"]) compared; " *
            "route/declaration length mismatches: " *
            "$(something(routes["n_length_mismatches"], "unassessed")) " *
            "of $(routes["n_length_comparisons"]) compared.\n")
        if xf["n"] > 0
            println(io, "Transformer bus separation: median $(round(xf["p50"], digits=1)) m, " *
                "99th percentile $(round(xf["p99"], digits=1)) m, " *
                "maximum $(round(xf["max"], digits=1)) m.\n")
            println(io, "Farthest transformer bus pairs:")
            for witness in Iterators.take(transformers["farthest_witnesses"], 5)
                println(io, "- `$(witness["transformer_id"])`: " *
                    "$(round(witness["distance_m"], digits=1)) m")
            end
            println(io)
        end
        if !isempty(lines["shorter_than_chord_witnesses"])
            println(io, "**Line length/chord candidates:**")
            for witness in lines["shorter_than_chord_witnesses"]
                println(io, "- `$(witness["line_id"])`: declared " *
                    "$(round(witness["length_m"], digits=1)) m, " *
                    "endpoint chord $(round(witness["chord_m"], digits=1)) m")
            end
            println(io)
        end
    end
end

function _md_diversity(r::SummaryReport, io::IO)
    d = get(r.results, :diversity, nothing)
    d === nothing && return
    println(io, "## 4. Diversity & Variance\n")
    score = get(d, "symmetry_score", "?")
    println(io, "**Overall symmetry score:** $score\n")

    for comp in ("load", "generator", "line", "linecode", "transformer")
        cd = get(d, comp, nothing)
        cd isa Dict && get(cd, "analysed", false) || continue
        flag = get(cd, "symmetry_flag", false) ? " ⚠" : ""
        println(io, "### $comp$flag\n")
        println(io, "| Parameter | Min | Max | CV | n |")
        println(io, "|-----------|-----|-----|----|---|")
        for stat_key in ("p_nom", "q_nom", "p_max", "length", "R_series_1_1", "s_rating")
            stats = get(cd, stat_key, nothing)
            stats isa Dict || continue
            println(io, "| $stat_key | $(round(Float64(get(stats,"min",0)),sigdigits=3)) | " *
                        "$(round(Float64(get(stats,"max",0)),sigdigits=3)) | " *
                        "$(round(Float64(get(stats,"cv",0)),digits=3)) | $(get(stats,"n","?")) |")
        end
        println(io)
    end
    _md_section_findings(r, io, :diversity)
end

function _md_operational(r::SummaryReport, io::IO)
    d = get(r.results, :operational, nothing)
    d === nothing && return
    println(io, "## 5. Loading & Operational Summary\n")

    tl = get(d, "total_load", Dict())
    tg = get(d, "total_generation_capacity", Dict())
    glr = get(d, "generation_load_ratio", nothing)

    println(io, "| | Value |")
    println(io, "|--|-------|")
    !isempty(tl) && println(io, "| Total load P | $(_fmt_mw(get(tl,"p_w",0.0))) |")
    !isempty(tl) && println(io, "| Total load Q | $(_fmt_mvar(get(tl,"q_var",0.0))) |")
    !isempty(tg) && println(io, "| Total gen capacity | $(_fmt_mw(get(tg,"p_max_w",0.0))) |")
    glr !== nothing && println(io, "| Generation/load ratio | $(glr)% |")
    println(io)

    xutil = get(d, "transformer_utilisation", Any[])
    if !isempty(xutil)
        println(io, "**Transformer utilisation:**\n")
        println(io, "| ID | Rating | Loading (est.) |")
        println(io, "|----|--------|---------------:|")
        for u in xutil
            flag = get(u, "estimate_status", "radial_component") == "upper_bound" ?
                " (upper bound)" : u["utilisation_pct"] > 90 ? " ⚠" : ""
            println(io, "| $(u["id"]) | $(_fmt_mva(u["s_rating_va"])) | $(_fmt_pct(u["utilisation_pct"]))$flag |")
        end
        println(io)
    end
    _md_section_findings(r, io, :operational)
    _md_section_findings(r, io, :load_models)
end

function _md_preflight(r::SummaryReport, io::IO)
    d = get(r.results, :preflight, nothing)
    d === nothing && return
    println(io, "## 6. Infeasibility Pre-flight\n")

    ga = get(d, "generation_adequacy", Dict())
    cc = get(d, "constraint_conflicts", Dict())
    vb = get(d, "voltage_bound_tightness", Dict())
    tr = get(d, "topological_risk", Dict())

    println(io, "| Check | Result |")
    println(io, "|-------|--------|")
    !isempty(ga) && println(io, "| Import dependent | $(get(ga,"import_dependent","?")) |")
    !isempty(cc) && println(io, "| Constraint conflicts | $(get(cc,"n_conflicts",0)) |")
    !isempty(vb) && println(io, "| Buses without voltage bounds | $(get(vb,"n_without_bounds","?")) |")
    !isempty(tr) && println(io, "| Single point of failure | $(get(tr,"single_point_of_failure","?")) |")
    println(io, "| TPIA status | $(get(d,"tpia_status","not_run")) |")
    println(io)
    _md_section_findings(r, io, :preflight)
end

function _md_provenance(r::SummaryReport, io::IO)
    d = get(r.results, :provenance, nothing)
    d === nothing && return
    println(io, "## 7. Provenance & Model Conventions\n")
    println(io, "**Inferred convention:** $(get(d, "convention", "undetermined"))\n")

    wl = get(d, "wires_by_level", Dict())
    if !isempty(wl)
        println(io, "| Voltage level | Wires | Buses with neutral |")
        println(io, "|---------------|-------|-------------------:|")
        for (label, info) in sort(collect(wl), by=x -> -x[2]["nominal_v"])
            println(io, "| $label | $(info["wires"]) | $(info["n_with_neutral"]) / $(info["n_buses"]) |")
        end
        println(io)
    end

    g = get(d, "grounding", Dict())
    if get(g, "n_buses_with_neutral", 0) > 0
        println(io, "| Neutral grounding | Value |")
        println(io, "|-------------------|------:|")
        println(io, "| Buses with neutral | $(g["n_buses_with_neutral"]) |")
        println(io, "| Neutral branches | $(get(g,"n_neutral_branches",0)) |")
        println(io, "| Grounding points | $(get(g,"n_grounding_points",0)) |")
        println(io, "| Neutral sections | $(get(g,"n_neutral_components","?")) |")
        println(io, "| Floating sections | $(get(g,"n_floating",0)) |")
        println(io)
    end

    vc = get(get(d, "linecodes", Dict()), "verdict_counts", Dict())
    if !isempty(vc)
        println(io, "**Linecode impedance classification:**\n")
        println(io, "| Verdict | Count |")
        println(io, "|---------|------:|")
        for verdict in ("distinct", "near_balanced", "exactly_balanced",
                        "decoupled", "not_applicable")
            haskey(vc, verdict) || continue
            println(io, "| $verdict | $(vc[verdict]) |")
        end
        println(io)
    end

    lm = get(get(d, "line_models", Dict()), "counts", Dict())
    if !isempty(lm) && sum(values(lm)) > 0
        println(io, "**Line model topology:**\n")
        println(io, "| Topology | Count |")
        println(io, "|----------|------:|")
        for (m, lab) in (("series", "pure series"), ("symmetric_pi", "symmetric π"),
                         ("asymmetric_pi", "asymmetric π"), ("gamma", "Γ (one-sided)"))
            c = get(lm, m, 0); c > 0 || continue
            println(io, "| $lab | $c |")
        end
        println(io)
    end

    dd = get(d, "opendss_defaults", Dict())
    if !isempty(dd)
        nh = get(dd, "n_default_hits", 0)
        println(io, "**OpenDSS default fingerprints:** " *
                    "$(nh == 0 ? "none detected ✓" : "$nh hit(s) — see findings")\n")
    end

    zones = get(d, "earthing_zones", Any[])
    if !isempty(zones)
        println(io, "**Earthing system per galvanic zone:**\n")
        println(io, "| Zone | Buses | Wires | Star point | Downstream earths | Likely system |")
        println(io, "|------|------:|-------|------------|------------------:|---------------|")
        for z in zones
            vlab = isnan(z["nominal_v"]) ? "?" : _fmt_kv(z["nominal_v"])
            star = z["star_earthing"] == "solid" ? "solid" :
                   z["star_earthing"] == "impedance" ?
                       "R≈$(round(z["star_R_ohm"], sigdigits=2)) Ω" : "none"
            println(io, "| $vlab | $(z["n_buses"]) | $(z["wires"]) | $star | " *
                        "$(z["n_downstream_earths"]) | $(z["tag"]) |")
        end
        println(io)
    end

    pc = get(d, "powerio_conversion", Dict())
    if get(pc, "n_classes", 0) > 0
        println(io, "**PowerIO conversion:** $(pc["n_diagnostics"]) fidelity " *
                    "loss(es) in $(pc["n_classes"]) class(es) — see findings\n")
    end

    _md_section_findings(r, io, :provenance)
end

function _md_spec_benchmark(r::SummaryReport, io::IO)
    spec  = get(r.results, :spec, nothing)
    bench = get(r.results, :benchmark, nothing)
    (spec === nothing && bench === nothing) && return
    println(io, "## 8. Spec Conformance & Benchmark Readiness\n")

    if spec isa Dict
        println(io, "| Spec conformance | Value |")
        println(io, "|------------------|------:|")
        println(io, "| Conformance issues | $(get(spec,"n_conformance_issues",0)) |")
        println(io, "| Voltage sources (spec requires 1) | $(get(spec,"n_voltage_sources","?")) |")
        println(io)
    end

    integ = get(r.results, :integrity, nothing)
    if integ isa Dict
        println(io, "| Structural integrity | Value |")
        println(io, "|----------------------|------:|")
        println(io, "| Reference issues | $(get(integ,"n_reference_issues",0)) |")
        println(io, "| Dimension issues | $(get(integ,"n_dimension_issues",0)) |")
        println(io, "| Galvanic islands | $(get(integ,"n_galvanic_islands","?")) |")
        println(io, "| Islands without voltage reference | $(get(integ,"n_without_reference",0)) |")
        haskey(integ, "impedance_spread") &&
            println(io, "| Line impedance spread | $(round(integ["impedance_spread"], sigdigits=3))× |")
        println(io)
    end

    if bench isa Dict
        println(io, "| Benchmark readiness | Value |")
        println(io, "|---------------------|------:|")
        println(io, "| Objective well-posed | $(get(bench,"objective_wellposed","?")) |")
        println(io, "| Only slack generation | $(get(bench,"only_slack_generation","?")) |")
        println(io, "| Buses with \\|V\\| bounds | $(get(bench,"pct_v_bounds","?"))% |")
        println(io, "| Buses with vpn / vpp / vpos bounds | $(get(bench,"n_vpn_bounds",0)) / $(get(bench,"n_vpp_bounds",0)) / $(get(bench,"n_vpos_bounds",0)) |")
        println(io, "| Lines with thermal limits | $(get(bench,"pct_thermal_limits","?"))% |")
        println(io, "| Generators with no DOF (p\\_min≈p\\_max) | $(get(bench,"n_gen_no_dof",0)) |")
        println(io, "| Generators with zero cost (dispatchable) | $(get(bench,"n_gen_zero_cost",0)) |")
        println(io, "| Same-cost generator pairs (≤1 hop) | $(get(bench,"n_same_cost_gen_pairs",0)) |")
        println(io, "| Loads with zero p\\_nom | $(get(bench,"n_loads_zero_pnom",0)) |")
        println(io)

        sugg = get(bench, "suggestions", String[])
        if !isempty(sugg)
            println(io, "**Augmentation needed:**\n")
            for s in sugg
                println(io, "- $s")
            end
            println(io)
        end
    end

    _md_section_findings(r, io, :integrity)
    _md_section_findings(r, io, :spec)
    _md_section_findings(r, io, :benchmark)
end

function _md_quality(r::SummaryReport, io::IO; verbose::Bool=true)
    println(io, "## 9. Data Quality Summary\n")
    errs  = errors(r)
    warns = warnings(r)
    infs  = infos(r)
    println(io, "**Total findings:** $(length(r.findings)) " *
                "($(length(errs)) errors, $(length(warns)) warnings, $(length(infs)) info)\n")

    for (label, subset, icon) in (("Errors", errs, "🔴"),
                                   ("Warnings", warns, "🟡"),
                                   (verbose ? "Info" : nothing, infs, "🔵"))
        label === nothing && continue
        isempty(subset) && continue
        println(io, "### $icon $label\n")
        for f in subset
            println(io, "- **[$(f.code)]** `$(something(f.component_id, string(f.component_type)))`  ")
            println(io, "  $(f.message)")
        end
        println(io)
    end
end

function _md_section_findings(r::SummaryReport, io::IO, section::Symbol)
    fs = filter(f -> f.section == section, r.findings)
    isempty(fs) && return
    for f in fs
        icon = f.severity == ERROR ? "🔴" : f.severity == WARNING ? "🟡" : "🔵"
        println(io, "> $icon **[$(f.code)]** $(f.message)")
    end
    println(io)
end
