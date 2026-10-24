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
            vg_str = isempty(vg) ? tr["subtype"] : "$(tr["subtype"]), effective $vg"
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
    if get(spatial, "analysis_performed", true) === false
        println(io, "### Geographic evidence\n")
        println(io, "**Geospatial analysis:** $(spatial["status"]) ($(spatial["reason"])). $(spatial["caution"])\n")
        return
    end
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
    semantics = get(spatial, "coordinate_semantics", nothing)
    if semantics !== nothing
        println(io, "Coordinate semantics: frame `$(semantics["frame"])`, units `$(semantics["units"])`; " *
            "$(semantics["n_metric_eligible_buses"]) metric-eligible buses; " *
            "$(semantics["n_with_reported_accuracy"]) with reported accuracy.\n")
        for issue in semantics["issues"]
            println(io, "- Coordinate declaration: `$issue`")
        end
        for (issue, count) in sort!(collect(semantics["bus_issue_counts"]), by=first)
            println(io, "- `$issue`: $count buses")
        end
        println(io)
    end
    proximity = get(spatial, "proximity", nothing)
    if proximity !== nothing
        println(io, "**Proximity:** $(proximity["status"]) ($(proximity["reason"])); " *
            "radius $(proximity["radius_m"]) m; " *
            "$(something(proximity["n_near_bus_pairs"], "unassessed")) near bus pairs; " *
            "$(something(proximity["n_clusters"], "unassessed")) clusters. $(proximity["caution"])\n")
        if !proximity["counts_complete"]
            println(io, "Partial observations: $(proximity["n_near_bus_pairs_observed"]) near pairs; " *
                "$(proximity["candidate_pairs_checked"]) candidate location pairs checked. Totals are unavailable.\n")
        end
        println(io, "<details>\n<summary>Proximity inventory — no connectivity claim</summary>\n")
        for pair in proximity["pair_witnesses"]
            buses = pair["representative_bus_pair"]
            println(io, "- `$(buses[1]["bus_id"])` ↔ `$(buses[2]["bus_id"])`: " *
                "$(round(pair["distance_m"], digits=4)) m; $(pair["accuracy_context"]) " *
                "for these representatives; $(pair["n_bus_pairs_at_these_locations"]) bus pairs at these locations.")
        end
        println(io, "\n</details>\n")
    end
    _md_spatial_cleanup_review(get(spatial, "cleanup_review", nothing), io)
    discrepancies = get(spatial, "discrepancy_candidates", nothing)
    if discrepancies !== nothing
        println(io, "<details>\n<summary>Underlying geometry and topology observations</summary>\n")
        println(io, "$(discrepancies["caution"])\n")
        for (name, check) in sort!(collect(discrepancies["checks"]), by=first)
            total = something(check["n_candidates"], "unavailable")
            println(io, "- **$name:** $(check["status"]) ($(check["reason"])); $total candidates; " *
                "$(check["n_candidates_observed"]) observed; counts include contextual evidence.")
            if haskey(check, "component_relation_counts_observed")
                counts = join(["$k=$v" for (k,v) in sort!(collect(check["component_relation_counts_observed"]), by=first)], ", ")
                println(io, "  - Observed component relations: $counts; $(check["n_endpoint_like_pairs_observed"]) endpoint-like pairs.")
            end
            for witness in check["witnesses"]
                code = witness["code"]
                detail = if code == "S.NEARBY_WITHOUT_DIRECT_BRANCH"
                    ids = [b["bus_id"] for b in witness["buses"]]
                    "$(join(ids, " ↔ ")): $(round(witness["distance_m"], digits=3)) m; " *
                        "$(witness["component_relation"]); voltage tiers $(witness["voltage_tier_relation"])"
                elseif code == "S.DIRECT_ALONGSIDE_SERIES_PATH"
                    ids = [b["component_id"] for b in witness["series_branches"]]
                    "$(witness["direct_branch"]["component_id"]) alongside $(join(ids, " → ")); " *
                        "endpoint-chord detour $(round(witness["detour_ratio"], digits=3))"
                elseif code == "S.LONG_BRANCH_SPAN"
                    "$(witness["branch"]["kind"]) $(witness["branch"]["component_id"]): $(round(witness["span_m"], digits=2)) m"
                elseif code in ("S.SHARED_ROUTE_SEGMENT", "S.REPEATED_SOURCE_INTERVAL")
                    ids = [l["line_id"] for l in witness["lines"]]
                    "$(join(ids, ", ")); $(witness["n_lines"]) lines; $(witness["declared_arrangement"]); " *
                        witness["terminal_map_relation"]
                elseif code == "S.ROUTE_ENDPOINT_DISAGREEMENT"
                    parts = ["$(e["side"]) bus $(e["connected_bus"]["bus_id"]): $(round(e["gap_m"], digits=2)) m gap; " *
                        "nearby alternatives $(something(e["nearby_alternative_buses"]["n_buses"], "indeterminate"))" for e in witness["endpoints"]]
                    "$(witness["line_id"]) ($(witness["orientation"])) — $(join(parts, "; "))"
                elseif code == "S.ROUTE_SEGMENT_DEFECT"
                    "$(witness["line_id"]): $(witness["n_zero_segments"]) zero segments, " *
                        "$(witness["n_repeated_segments"]) repeated segments, $(witness["n_long_segments"]) long segments"
                else
                    "$(witness["line_id"]): $(witness["reason"])"
                end
                println(io, "  - `$code`: $detail")
            end
        end
        println(io, "\nFull terminal, switch, coordinate and branch evidence is retained in the JSON report. " *
            "Unassessed: $(join(discrepancies["unassessed"], ", ")).\n")
        println(io, "</details>\n")
    end
    println(io, "Line routes: $(routes["n_with_route"])/$(routes["n_lines"]); " *
        "$(reference["n_matching_wgs84_routes"]) WGS84 routes match their bus endpoints.\n")
    coincidence = get(spatial, "coincidence", nothing)
    if coincidence !== nothing
        println(io, "Exact coordinate coincidence: $(coincidence["n_groups"]) groups " *
            "containing $(coincidence["n_buses_in_groups"]) buses. $(coincidence["caution"])\n")
        for witness in coincidence["witnesses"]
            ids = join(["`$(b["bus_id"])`" for b in witness["buses"]], ", ")
            suffix = witness["members_truncated"] ? " (member list truncated)" : ""
            println(io, "- $ids$suffix: $(join(witness["contexts"], ", "))")
        end
        isempty(coincidence["witnesses"]) || println(io)
    end
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
    if get(reference, "metric_distances_applicable", reference["geodesic_distances_applicable"])
        xf = transformers["separation_m"]
        println(io, "Metric comparisons: $(lines["n_with_chord_comparison"]) lines with endpoint distances; " *
            "$(something(lines["n_shorter_than_chord_beyond_tolerance"], "unassessed")) declared lengths below their " *
            "endpoint chord by more than max(5 m, 10% of chord). " *
            "Route endpoint gaps over 5 m: " *
            "$(something(routes["n_endpoint_gaps_over_5m"], "unassessed")) " *
            "of $(routes["n_endpoint_comparisons"]) compared; " *
            "route/declaration length mismatches: " *
            "$(something(routes["n_length_mismatches"], "unassessed")) " *
            "of $(routes["n_length_comparisons"]) compared.\n")
        if xf["n"] > 0
            println(io, "Transformer extent across all winding buses: median $(round(xf["p50"], digits=1)) m, " *
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
            println(io, "**Declared lengths below endpoint distance** (descriptive; see physical/electrical context below):")
            for witness in lines["shorter_than_chord_witnesses"]
                println(io, "- `$(witness["line_id"])`: declared " *
                    "$(round(witness["length_m"], digits=1)) m, " *
                    "endpoint chord $(round(witness["chord_m"], digits=1)) m")
            end
            println(io)
        end
    end
    if haskey(transformers, "n_indeterminate")
        println(io, "Transformer extents: $(transformers["n_assessed"])/$(transformers["n_transformers"]) assessed; " *
            "$(transformers["n_indeterminate"]) indeterminate; " *
            "$(transformers["n_zero_extent"]) with zero extent. $(transformers["caution"])\n")
    end
    context = get(spatial, "length_context", nothing)
    if context !== nothing
        println(io, "**Physical and electrical length context.** $(context["caution"])\n")
        println(io, "| Comparison | Passed | Failed | Indeterminate | Inapplicable |")
        println(io, "|---|---:|---:|---:|---:|")
        for (name, counts) in sort!(collect(context["comparison_status_counts"]), by=first)
            println(io, "| $name | $(counts["passed"]) | $(counts["failed"]) | " *
                "$(counts["indeterminate"]) | $(counts["inapplicable"]) |")
        end
        println(io)
        metres(v) = v === nothing ? "unavailable" : "$(round(v, digits=2)) m"
        for row in context["witnesses"]
            println(io, "- `$(row["line_id"])`: $(join(row["contexts"], ", ")); " *
                "declared $(metres(row["declared_length_m"])), physical $(metres(row["physical_length_m"])), " *
                "endpoint distance $(metres(row["chord_m"])), stored route $(metres(row["stored_route_length_m"])), " *
                "recomputed route $(metres(row["recomputed_route_length_m"])); " *
                "comparison basis `$(row["comparison_basis"])`.")
        end
        isempty(context["witnesses"]) || println(io)
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
    headroom = get(d, "transformer_coil_headroom", Dict())
    estimates = get(headroom, "transformers", Any[])
    if !isempty(estimates)
        println(io, "**Nominal transformer coil headroom (estimate):**\n")
        println(io, "At each load's nominal voltage; losses, mutual coupling and neutral displacement omitted. Signed P/Q are summed per coil. This is not a feasibility or infeasibility certificate.\n")
        println(io, "| Transformer | Coil (from) | Nominal S (VA) | Cap (VA) | Headroom (VA) |")
        println(io, "|---|---|---:|---:|---:|")
        for estimate in estimates
            for coil in estimate["coils"]
                println(io, "| $(estimate["transformer"]) | $(coil["coil"]) | $(round(coil["s_nom_VA"];digits=3)) | $(round(coil["cap_VA"];digits=3)) | $(round(coil["headroom_VA"];digits=3)) |")
            end
            if estimate["status"] != "estimated"
                println(io, "| $(estimate["transformer"]) | unassessed: $(estimate["reason"]) | — | — | — |")
            end
        end
        println(io)
    end
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

function _md_spatial_cleanup_review(review, io::IO; item_limit=20)
    review isa AbstractDict || return
    _md_spatial_coverage_banner(review, io)
    println(io, "**Cleanup review:** $(review["status"]) ($(review["reason"])); " *
        "$(length(review["items"])) captured items in $(length(review["locations"])) exact review locations. " *
        "Queue complete within scope: $(review["queue_complete"]).\n")
    println(io, "$(review["caution"])\n")
    for (name, coverage) in sort!(collect(review["coverage"]), by=first)
        if !coverage["capture_complete"] || !coverage["scan_complete"]
            println(io, "- Coverage `$name`: $(coverage["status"]) ($(coverage["reason"])); " *
                "$(coverage["n_captured"])/$(coverage["n_observed"]) observed candidates captured.")
        end
    end
    isempty(review["coverage"]) || println(io)
    for (state, count) in sort!(collect(get(review, "disposition_counts", Dict())), by=first)
        count > 0 && println(io, "- Disposition `$state`: $count")
    end
    for (state, count) in sort!(collect(get(review, "review_status_counts", Dict())), by=first)
        state in ("unreviewed", "recorded") || println(io, "- Decision status `$state`: $count")
    end
    audit = get(review, "decision_audit", nothing)
    if audit !== nothing
        println(io, "\nDecision ledger: $(audit["n_invalid_records"]) invalid records; $(audit["n_unmatched_records"]) unmatched records. " *
            "Unmatched candidates are not assumed resolved.")
    end
    println(io, "\nPriority is an inspection order, not error probability. Impact counts refer only to identified subjects and directly attached loads.\n")
    if any(i -> !haskey(i, "assessment"), review["items"])
        println(io, "Classification unavailable for legacy observations; regenerate the report for current evidence categories. " *
            "Unclassified observations are retained in the inspection view.\n")
    else
        categories = get(review, "category_counts", Dict())
        println(io, "| Automated evidence category | Captured observations |\n| --- | ---: |")
        for category in _SPATIAL_QUALITY_CATEGORIES
            println(io, "| $(replace(category, "_"=>" ")) | $(get(categories, category, 0)) |")
        end
    end
    println(io, "\nThese are observation counts, not error counts. Confirmed issues are recorded separately as reviewer dispositions. " *
        "Context alone does not imply a required correction.\n")
    _md_spatial_candidate_index(review, io; limit=item_limit)
    println(io, "**Needs inspection or information**\n")
    _md_spatial_review_items(review, io, "attention"; limit=item_limit)
    println(io, "<details>\n<summary>Contextual observations — overlap alone is not an issue</summary>\n")
    _md_spatial_review_items(review, io, "context"; limit=item_limit)
    println(io, "</details>\n")
    if any(i -> _spatial_review_bucket(i) == "reviewed", review["items"])
        println(io, "<details>\n<summary>Accepted or resolved by a reviewer</summary>\n")
        _md_spatial_review_items(review, io, "reviewed"; limit=item_limit)
        println(io, "</details>\n")
    end
end

# Escape model-supplied text before placing it in Markdown or HTML details blocks.
_spatial_md_text(x) = replace(string(x), '&'=>"&amp;", '<'=>"&lt;", '>'=>"&gt;",
    '\n'=>" ", '\r'=>" ", '\\'=>"\\\\", '`'=>"\\`", '*'=>"\\*", '_'=>"\\_",
    '['=>"\\[", ']'=>"\\]", '|'=>"\\|")
_spatial_review_anchor(item) = "spatial-item-" * _spatial_review_hash(item["item_id"])

function _md_spatial_coverage_banner(review, io)
    coordinates = review["coordinate_context"]
    total = coordinates["n_buses"]
    eligible = coordinates["n_metric_eligible_buses"]
    excluded = total - eligible
    percentage = total > 0 ? " ($(round(100 * eligible / total; digits=1))%)" : ""
    println(io, "> **Coordinate coverage:** $eligible of $total buses$percentage eligible for metric checks; " *
        "**$excluded not eligible** for bus-distance checks.")
    accuracy = get(coordinates, "n_with_reported_accuracy", nothing)
    accuracy_text = accuracy === nothing ? "coverage unavailable in this report" : "$accuracy of $total buses"
    println(io, ">\n> Frame: $(_spatial_md_text(coordinates["status"])). Reported coordinate accuracy: $accuracy_text.")
    println(io, ">\n> Queue completeness covers applicable checks within search and capture limits. " *
        "It does not cover excluded bus geometry or establish model correctness.\n")
    issues = get(coordinates, "bus_issue_counts", Dict())
    if !isempty(issues)
        summary = join(["$(replace(k, "_"=>" ")): $v" for (k,v) in sort!(collect(issues), by=first)], "; ")
        println(io, "Coordinate issue counts (may overlap): $(_spatial_md_text(summary)).\n")
    end
end

function _md_spatial_candidate_index(review, io; limit=20)
    attention = filter(i -> _spatial_review_bucket(i) == "attention", review["items"])
    shown = collect(Iterators.take(attention, limit))
    println(io, "**Candidate index — $(length(shown)) of $(length(attention)) attention observations**\n")
    println(io, "Links lead to the detailed entries below. The display limit applies to both the index and details; " *
        "JSON retains all captured items. Row numbers are navigation aids, not stable identities.\n")
    isempty(shown) && return
    println(io, "| # | Priority | Category / code | Primary asset | Details |\n| ---: | --- | --- | --- | --- |")
    for (rank, item) in enumerate(shown)
        evidence = item["evidence"]
        subject = if haskey(evidence, "direct_branch")
            "line:" * evidence["direct_branch"]["component_id"]
        elseif !isempty(item["components"])
            ref = first(item["components"]); "$(ref["kind"]):$(ref["id"])"
        else
            "bus:" * first(item["bus_ids"])
        end
        label = length(subject) > 80 ? first(subject, 77) * "…" : subject
        category = haskey(item, "assessment") ? replace(_spatial_review_category(item), "_"=>" ") : "classification unavailable"
        println(io, "| $rank | P$(item["priority"]) | $(_spatial_md_text(category)) / $(_spatial_md_text(item["code"])) | " *
            "$(_spatial_md_text(label)) | [View](#$(_spatial_review_anchor(item))) |")
    end
    println(io)
end

function _md_spatial_review_items(review, io, bucket; limit=20)
    selected = filter(i -> _spatial_review_bucket(i) == bucket, review["items"])
    shown = collect(Iterators.take(selected, limit))
    groups = Dict{String,Vector{Any}}(); order = String[]
    for item in shown
        id = item["location_id"]
        if !haskey(groups, id)
            groups[id] = Any[]; push!(order, id)
        end
        push!(groups[id], item)
    end
    for id in order
        members = groups[id]; location = first(members)["location"]
        label = location["status"] == "located" ?
            "$(join(location["coordinate"], ", ")) $(location["units"]) in $(location["frame"])" :
            "Location unavailable; asset $(join(location["primary_asset"], ":"))"
        println(io, "\n**Review location: $(_spatial_md_text(label))**\n")
        for item in members
            println(io, "<a id=\"$(_spatial_review_anchor(item))\"></a>\n")
            assessment = get(item, "assessment", nothing)
            title = assessment === nothing ? item["ranking_reason"] : assessment["observation"]
            category = assessment === nothing ? "classification unavailable" : replace(_spatial_review_category(item), "_"=>" ")
            println(io, "- **$(_spatial_md_text(category)) · P$(item["priority"])** — $(_spatial_md_text(title))")
            refs = vcat(["$(c["kind"]):$(c["id"])" for c in item["components"]], ["bus:$b" for b in item["bus_ids"]])
            println(io, "\n  Subjects: $(_spatial_md_text(join(Iterators.take(refs, 8), ", ")))$(length(refs) > 8 ? " (more in JSON)" : "").")
            evidence = item["evidence"]
            details = String[]
            haskey(evidence, "distance_m") && push!(details, "separation $(round(evidence["distance_m"], digits=4)) m")
            haskey(evidence, "segment_length_m") && push!(details, "shared segment $(round(evidence["segment_length_m"], digits=4)) m")
            if item["code"] == "S.ROUTE_ENDPOINT_DISAGREEMENT"
                append!(details, ["$(e["side"]) endpoint gap $(round(e["gap_m"], digits=4)) m" for e in evidence["endpoints"]])
                push!(details, "tolerance $(evidence["tolerance_m"]) m; orientation $(evidence["orientation"])")
            elseif item["code"] == "R.LINE_LENGTH_CONTEXT"
                for key in ("declared_length_m", "physical_length_m", "chord_m", "stored_route_length_m", "recomputed_route_length_m")
                    push!(details, "$(replace(key, "_"=>" ")): $(something(evidence[key], "unavailable"))")
                end
            elseif item["code"] == "S.INVALID_ROUTE_GEOMETRY"
                push!(details, "validation reason: $(evidence["reason"])")
            end
            if assessment !== nothing
                voltage = assessment["voltage_context"]
                if voltage !== nothing
                    push!(details, "voltage relation: $(voltage["relation"])")
                    haskey(voltage, "tiers") && push!(details, "tiers: $(join(voltage["tiers"], ", "))")
                    haskey(voltage, "buses") && push!(details, join(["$(b["bus_id"]): $(b["voltage_tier"])" for b in voltage["buses"]], ", "))
                end
                isempty(details) || println(io, "\n  Evidence: $(_spatial_md_text(join(details, "; "))).")
                println(io, "\n  Interpretation: $(_spatial_md_text(assessment["explanation"]))")
                println(io, "\n  Uncertainty: $(_spatial_md_text(assessment["uncertainty"]))")
                println(io, "\n  Inspect: $(_spatial_md_text(assessment["inspect"]))")
            end
            _md_spatial_interpretation_evidence(get(item, "interpretation_evidence", nothing), io)
            println(io, "\n  Geometry basis: $(_spatial_md_text(item["geometry_basis"])); " *
                "$(item["geometry_coverage"]["n_buses_with_eligible_coordinates"])/$(item["geometry_coverage"]["n_identified_buses"]) identified buses located; " *
                "subject list complete: $(item["geometry_coverage"]["subject_list_complete"]).")
            coordinate_evidence = get(item, "coordinate_evidence", Dict())
            for (bus, record) in Iterators.take(sort!(collect(coordinate_evidence), by=first), 4)
                println(io, "\n  Coordinates for $(_spatial_md_text(bus)): provenance $(_spatial_md_text(record["coordinate_provenance"])); " *
                    "reported accuracy $(_spatial_md_text(something(record["coordinate_accuracy_m"], "unavailable"))) m.")
            end
            length(coordinate_evidence) > 4 && println(io, "  Additional coordinate provenance is retained in JSON.")
            println(io, "\n  Review: $(_spatial_md_text(item["review"]["disposition"])) ($(_spatial_md_text(item["review"]["status"]))). " *
                "Directly attached loads: $(item["impact"]["n_directly_attached_loads"]). " *
                "Code: `$(item["code"])`. ID: `$(item["item_id"])`.\n")
            if item["review"]["status"] == "recorded"
                decision = item["review"]["decision"]
                println(io, "  Reviewer: $(_spatial_md_text(decision["reviewer"])) at $(_spatial_md_text(decision["recorded_at"])). " *
                    "Rationale: $(_spatial_md_text(decision["rationale"])).\n")
            end
        end
    end
    println(io, "\nShowing $(length(shown)) of $(length(selected)) $bucket observations; JSON retains all captured items.\n")
end

# JSON-style lists avoid leaking Julia display types (for example Any[]) into reports.
_spatial_md_list(value) = value === nothing ? "unavailable" : JSON3.write(_jsonable(value))
_spatial_md_distance(value) = value === nothing ? "unavailable" : string(round(value; digits=3))
function _md_spatial_interpretation_evidence(evidence, io)
    evidence isa AbstractDict || return
    println(io, "\n  **Direct / series decision evidence**\n")
    for (role, branch) in [("direct", evidence["direct"]); [("series", b) for b in evidence["series"]]]
        label = "$role line $(branch["line_id"]): $(branch["path_from"]) $(_spatial_md_list(branch["terminal_map_from"])) → $(branch["path_to"]) $(_spatial_md_list(branch["terminal_map_to"]))"
        println(io, "  - $(_spatial_md_text(label))")
        lengths = branch["length_context"]
        if lengths !== nothing
            values = ["$(replace(key, "_"=>" ")): $(_spatial_md_distance(lengths[key]))" for key in
                ("declared_length_m", "physical_length_m", "chord_m", "recomputed_route_length_m")]
            println(io, "\n    Length evidence: $(_spatial_md_text(join(values, "; "))). Comparison basis: $(_spatial_md_text(lengths["comparison_basis"])).")
        end
        declarations = branch["model_declarations"]
        isempty(declarations) && println(io, "\n    Model provenance: unavailable within the supported metadata fields.")
        for record in declarations
            println(io, "\n    Source declaration $(_spatial_md_text(join(record["path"], "."))): $(_spatial_md_text(record["value"]))")
        end
    end
    for comparison in evidence["terminal_comparisons"]
        println(io, "\n  Terminal sets at $(_spatial_md_text(comparison["bus_id"])): $(_spatial_md_text(replace(comparison["relation"], "_"=>" "))).")
    end
    for bus in evidence["intermediate_buses"]
        attachments = bus["attachments"]
        counts = ["$kind=$(count(a -> a["kind"] == kind, attachments))" for kind in sort!(unique([a["kind"] for a in attachments]))]
        println(io, "\n  Intermediate bus $(_spatial_md_text(bus["bus_id"])): $(isempty(counts) ? "no listed attachments" : _spatial_md_text(join(counts, ", "))). " *
            "Explicit perfectly grounded terminals: $(_spatial_md_text(bus["perfectly_grounded_terminals"] === nothing ? "not declared" : _spatial_md_list(bus["perfectly_grounded_terminals"]))).")
        for attachment in Iterators.take(attachments, 8)
            println(io, "  - $(_spatial_md_text(attachment["kind"])):$(_spatial_md_text(attachment["component_id"])); terminal map $(_spatial_md_text(_spatial_md_list(attachment["terminal_map"])))")
        end
        length(attachments) > 8 && println(io, "  Additional attachment identities are retained in JSON.")
    end
    println(io, "\n  $(_spatial_md_text(evidence["scope"]))\n")
end
