# Coverage is orthogonal to Finding severity and is never a global validation score.
function _assessment_coverage(results)
    checks = Dict{String,Any}[]
    function add(id, rows, unit; empty_reason="no_entities")
        counts = Dict(s => 0 for s in ("assessed", "skipped", "inapplicable", "indeterminate", "unknown"))
        reasons = Dict{String,Int}()
        for row in rows
            status = get(row, "status", "unknown")
            status == "estimated" && (status = "assessed")
            status == "unassessed" && (status = "indeterminate")
            haskey(counts, status) || (status = "unknown")
            counts[status] += 1
            reason = get(row, "reason", nothing)
            reason === nothing || (reasons[string(reason)] = get(reasons, string(reason), 0)+1)
        end
        push!(checks, Dict{String,Any}("check" => id, "entity_unit" => unit, "n_entities" => length(rows),
            "status_counts" => counts, "reason_counts" => reasons,
            "status" => isempty(rows) ? "inapplicable" : counts["assessed"] == length(rows) ? "assessed" :
                counts["inapplicable"] == length(rows) ? "inapplicable" : counts["skipped"] == length(rows) ? "skipped" :
                counts["unknown"] == length(rows) ? "unknown" : "indeterminate",
            "reason" => isempty(rows) ? empty_reason : nothing))
    end
    schema = get(results, :schema, Dict())
    ran = get(schema, "jsonschema_ran", nothing)
    row = Dict{String,Any}("status" => ran === true ? "assessed" : ran === false ? "skipped" : "unknown",
        "reason" => ran === false ? "unsupported_schema_structural_validation_skipped" : nothing)
    row["outcome"] = ran === true ? (get(schema, "jsonschema_valid", false) ? "passed" : "failed") : nothing
    add("structural_schema", [row], "document"); checks[end]["outcome"] = row["outcome"]
    ops = get(results, :operational, Dict())
    add("winding_limits", get(get(ops, "winding_limit_coverage", Dict()), "transformers", []), "transformer")
    reach = get(ops, "feeder_length", [])
    add("boundary_distance", reach, "galvanic_zone")
    add("feeder_threshold", [Dict("status" => get(r, "threshold_status", "unknown"),
        "reason" => get(r, "threshold_reason", nothing)) for r in reach], "galvanic_zone")
    add("nominal_coil_headroom", get(get(get(results, :preflight, Dict()), "transformer_coil_headroom", Dict()), "transformers", []), "transformer")
    spatial = get(get(results, :connectivity, Dict()), "spatial", nothing)
    spatial_status, reason = spatial === nothing ? ("inapplicable", "no_coordinate_evidence") :
        get(spatial, "analysis_performed", true) === false ?
            (get(spatial, "reason", nothing) == "disabled" ? "skipped" : "indeterminate", get(spatial, "reason", nothing)) :
            ("assessed", "individual_spatial_checks_retain_their_own_applicability")
    add("spatial_analysis", [Dict("status" => spatial_status, "reason" => reason)], "analysis_pass")
    for section in sort!(collect(keys(results)), by=string)
        section == :assessment && continue
        add("$(section)_remaining_coverage", [Dict("status" => "unknown",
            "reason" => "legacy_pass_has_no_complete_assessment_ledger")], "analysis_pass")
    end
    counts = Dict(s => count(c -> c["status"] == s, checks)
        for s in ("assessed", "skipped", "inapplicable", "indeterminate", "unknown"))
    Dict{String,Any}("checks" => checks, "check_status_counts" => counts,
        "scope" => "explicit_producer_status_with_legacy_coverage_unknown",
        "comprehensive_validation" => false)
end

function _render_assessment_coverage(report, io; markdown=false)
    coverage = get(report.results, :assessment, nothing)
    coverage === nothing && return
    println(io, markdown ? "\n**Assessment coverage**\n" : "\n  Assessment coverage:")
    counts = coverage["check_status_counts"]
    println(io, join(["$s=$(counts[s])" for s in ("assessed", "skipped", "inapplicable", "indeterminate", "unknown")], ", "))
    println(io, "Coverage describes the listed checks, not comprehensive validation. Entity units are separate.\n")
    legacy = filter(c -> endswith(c["check"], "_remaining_coverage"), coverage["checks"])
    println(io, "$(length(legacy)) legacy passes have no complete coverage ledger; their remaining coverage is unknown.\n")
    for check in coverage["checks"]
        endswith(check["check"], "_remaining_coverage") && continue
        counts = check["status_counts"]
        reasons = join(["$k=$v" for (k,v) in sort!(collect(check["reason_counts"]), by=first)], ", ")
        println(io, "- $(check["check"]): $(check["status"]); $(check["n_entities"]) $(check["entity_unit"]); " *
            join(["$s=$(counts[s])" for s in ("assessed", "skipped", "inapplicable", "indeterminate", "unknown")], ", ") *
            (isempty(reasons) ? "" : "; $reasons"))
    end
    println(io)
end

function _render_repeat_evidence(r, io)
    d = get(get(r.results, :diversity, Dict()), "load", Dict())
    haskey(d, "n_excess_repetitions") || return
    println(io, "\nLoad repetitions: $(d["n_total_loads"]) assessed loads, $(d["n_distinct_pq_tuples"]) distinct P/Q tuples, " *
        "$(d["n_excess_repetitions"]) excess repetitions; largest group $(d["largest_group_count"]), " *
        "$(d["n_repeated_groups"]) repeated groups with $(d["n_members_of_repeated_groups"]) members. " *
        "Excluded invalid/incomplete tuples: $(d["n_excluded_loads"]).\n")
    for w in d["witnesses"]
        println(io, "- P=$(w["p_nom"]), Q=$(w["q_nom"]): $(w["n_members"]) loads; examples $(join(w["load_ids"], ", "))" *
            (w["members_truncated"] ? " (member list truncated)" : ""))
    end
    println(io)
end

function _render_parallel_evidence(r, io)
    p = get(get(get(r.results, :connectivity, Dict()), "structure", Dict()), "parallel_lines", Dict())
    haskey(p, "excess_counts_by_class") && p["n_groups"] > 0 || return
    println(io, "\nParallel declaration evidence: $(p["n_groups"]) line groups; $(p["n_parallel_excess"]) excess line records, " *
        "including $(p["n_identical_group_excess"]) in wholly identical declaration groups. Asset identity unassessed.")
    println(io, "Multiplicity (members per group): ", join([
        "$k members: $(p["multiplicity_counts"][k]) groups" for k in
        sort!(collect(keys(p["multiplicity_counts"])); by=k -> parse(Int,k))], "; "))
    for class in sort!(collect(keys(p["classification_counts"])))
        println(io, "- $class: $(p["classification_counts"][class]) groups; " *
            "$(p["member_counts_by_class"][class]) members; $(p["excess_counts_by_class"][class]) excess")
    end
    for w in p["witnesses"]
        println(io, "- $(join(w["bus_pair"], " ↔ ")): $(w["classification"]), $(w["n_members"]) members; " *
            "examples $(join(w["line_ids"], ", "))" * (w["members_truncated"] ? " (truncated)" : ""))
    end
    println(io)
end

function _render_operational_evidence(r, io)
    d = get(r.results, :operational, Dict()); c = get(d, "winding_limit_coverage", Dict())
    if haskey(c, "transformer_counts")
        println(io, "\nWinding limit coverage (supported declarations, not built constraints):")
        println(io, join(["$k=$v" for (k,v) in sort!(collect(c["transformer_counts"]), by=first)], ", "))
        println(io, "$(c["n_windings_without_caps"]) winding(s) without either supported coil cap. Direct neutral-current caps: unsupported by the native n-winding builder; ports without a neutral are inapplicable.")
        for f in ("i_max", "s_max")
            println(io, "- $f declarations: ", join(["$k=$v" for (k,v) in sort!(collect(c["limit_counts"][f]), by=first)], ", "))
        end
    end
    reach = get(d, "feeder_length", [])
    println(io, "\nDeclared-length boundary distance ($(length(reach)) zones; up to 10 examples):")
    for z in Iterators.take(reach, 10)
        distance(v) = v === nothing ? "unassessed" : "$(round(v; digits=2)) m"
        reason = z["reason"] === nothing ? "" : " ($(replace(z["reason"], "_"=>" ")))"
        threshold_reason = z["threshold_reason"] === nothing ? "" : " ($(replace(z["threshold_reason"], "_"=>" ")))"
        println(io, "- $(z["zone_anchor"]): anchor extent $(distance(z["anchor_extent_m"])); nearest-boundary maximum " *
            "$(distance(z["boundary_reach_m"])); $(z["status"])$reason; threshold $(z["threshold_status"])$threshold_reason.")
    end
    shared = sort!(filter(z -> z["n_incident_transformers"] > 1, reach), by=z -> (-z["n_incident_transformers"], z["zone_anchor"]))
    println(io, "\nZones with multiple transformer boundary ports: $(length(shared)). Supply allocation and safe paralleling are unassessed.")
    for z in Iterators.take(shared, 10)
        println(io, "- $(z["zone_anchor"]): $(z["n_buses"]) buses, $(z["n_loads"]) loads, " *
            "$(z["n_incident_transformers"]) distinct transformers, $(z["n_incident_windings"]) winding ports; voltage band $(z["band"]).")
        for p in Iterators.take(filter(p -> p["kind"] == "transformer", z["boundaries"]), 5)
            println(io, "  Port $(p["subtype"])/$(p["id"])/$(p["winding"]) at $(p["bus"]): $(p["qualification"])" *
                (p["reason"] === nothing ? "." : " ($(replace(p["reason"], "_"=>" ")))."))
        end
        for path in get(z, "port_path_witnesses", [])
            println(io, "  Connecting path ($(path["n_path_edges"]) edges, truncated=$(path["path_truncated"])): $(join(path["branch_ids_from_farthest"], ", ")).")
        end
    end
    util = get(d, "transformer_utilisation", [])
    println(io, "\nNominal transformer estimate coverage: $(count(u -> u["estimate_status"] == "radial_component", util)) radial components; " *
        "$(count(u -> u["estimate_status"] == "upper_bound", util)) upper bounds. Upper bounds do not trigger overload warnings.\n")
end

function _render_provenance_evidence(r, io)
    d = get(get(r.results, :provenance, Dict()), "impedance_transform", Dict())
    es = get(d, "evidence_by_linecode", Dict()); isempty(es) && return
    types = get(d, "by_type", Dict())
    println(io, "\nThree-wire impedance hypotheses: " *
        "$(length(get(types, "kron_reduced", []))) possible Kron; " *
        "$(length(get(types, "phase_to_neutral", []))) phase-to-neutral; " *
        "$(length(get(types, "modified_phase_to_neutral", []))) modified phase-to-neutral; " *
        "$(length(get(types, "unknown", []))) without a candidate. " *
        "Use the Findings to review source parameters and alternatives.\n")
end

# Keep ambiguous attribution separate from radial nominal-demand estimates.
function _render_nameplate_estimates(r, io; markdown=false)
    estimates = get(get(r.results, :operational, Dict()), "transformer_utilisation", [])
    isempty(estimates) && return
    println(io, "\nTransformer nameplate comparison (nominal load estimate):\n")
    for (status, label) in (("radial_component", "Radial component estimates"), ("upper_bound", "Upper-bound estimates"))
        entries = sort!(filter(u -> get(u, "estimate_status", "radial_component") == status, estimates);
            by=u -> (get(u,"subtype",""), u["id"]))
        isempty(entries) && continue
        println(io, "$label ($(length(entries))):\n")
        status == "upper_bound" && println(io, "Attribution is ambiguous; these do not trigger overload warnings.\n")
        if markdown
            println(io, "| ID | Nameplate | Nominal demand/nameplate (est.) |")
            println(io, "|---|---|---:|")
        end
        for u in entries
            marker = status == "radial_component" && u["utilisation_pct"] > 90 ? " ⚠" : ""
            if markdown
                println(io, "| $(u["id"]) | $(_fmt_mva(u["s_rating_va"])) | $(_fmt_pct(u["utilisation_pct"]))$marker |")
            else
                println(io, "  $(u["id"]): $(_fmt_mva(u["s_rating_va"])) nameplate; $(_fmt_pct(u["utilisation_pct"]))$marker")
            end
        end
        println(io)
    end
end
