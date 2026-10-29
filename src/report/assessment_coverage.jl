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

_humanize(x) = x === nothing ? "" : replace(string(x), "_" => " ")
_pre(markdown) = markdown ? "" : "  "

# One line by default; only checks a reader can act on are listed. The full
# ledger (including legacy passes with unknown coverage) stays in JSON.
function _render_assessment_coverage(report, io; markdown=false)
    coverage = get(report.results, :assessment, nothing)
    coverage === nothing && return
    pre = _pre(markdown)
    listed = filter(c -> !endswith(c["check"], "_remaining_coverage"), coverage["checks"])
    st(s) = count(c -> c["status"] == s, listed)
    println(io, (markdown ? "\n**Assessment coverage:** " : "\n  Assessment coverage: ") *
        "$(st("assessed")) assessed, $(st("indeterminate")) indeterminate, $(st("skipped")) skipped, " *
        "$(st("inapplicable")) not applicable (of $(length(listed)) tracked checks; not a validation score).")
    for c in listed
        c["status"] in ("indeterminate", "skipped", "unknown") && c["n_entities"] > 0 || continue
        reasons = join(["$(_humanize(k)) ($v)" for (k, v) in sort!(collect(c["reason_counts"]), by=first)], ", ")
        println(io, "$pre- $(_humanize(c["check"])): $(c["status"]) for " *
            "$(c["n_entities"] - c["status_counts"]["assessed"]) of $(c["n_entities"]) $(_humanize(c["entity_unit"]))(s)" *
            (isempty(reasons) ? "" : " — $reasons"))
    end
    println(io)
end

function _render_repeat_evidence(r, io; markdown=false)
    pre = _pre(markdown)
    d = get(get(r.results, :diversity, Dict()), "load", Dict())
    haskey(d, "n_excess_repetitions") && d["n_excess_repetitions"] > 0 || return
    println(io, "\n$(pre)Load repetitions: $(d["n_total_loads"]) assessed loads, $(d["n_distinct_pq_tuples"]) distinct P/Q tuples, " *
        "$(d["n_excess_repetitions"]) excess repetitions; largest group $(d["largest_group_count"]), " *
        "$(d["n_repeated_groups"]) repeated groups with $(d["n_members_of_repeated_groups"]) members. " *
        "Excluded invalid/incomplete tuples: $(d["n_excluded_loads"]).\n")
    for w in d["witnesses"]
        println(io, "$pre- P=$(w["p_nom"]), Q=$(w["q_nom"]): $(w["n_members"]) loads; examples $(join(w["load_ids"], ", "))" *
            (w["members_truncated"] ? " (member list truncated)" : ""))
    end
    println(io)
end

function _render_parallel_evidence(r, io; markdown=false)
    pre = _pre(markdown)
    p = get(get(get(r.results, :connectivity, Dict()), "structure", Dict()), "parallel_lines", Dict())
    haskey(p, "excess_counts_by_class") && p["n_groups"] > 0 || return
    println(io, "\n$(pre)Parallel declaration evidence: $(p["n_groups"]) line groups; $(p["n_parallel_excess"]) excess line records, " *
        "including $(p["n_identical_group_excess"]) in wholly identical declaration groups. Asset identity unassessed.")
    println(io, "$(pre)Multiplicity (members per group): ", join([
        "$k members: $(p["multiplicity_counts"][k]) groups" for k in
        sort!(collect(keys(p["multiplicity_counts"])); by=k -> parse(Int,k))], "; "))
    for class in sort!(collect(keys(p["classification_counts"])))
        println(io, "$pre- $class: $(p["classification_counts"][class]) groups; " *
            "$(p["member_counts_by_class"][class]) members; $(p["excess_counts_by_class"][class]) excess")
    end
    for w in p["witnesses"]
        println(io, "$pre- $(join(w["bus_pair"], " ↔ ")): $(w["classification"]), $(w["n_members"]) members; " *
            "examples $(join(w["line_ids"], ", "))" * (w["members_truncated"] ? " (truncated)" : ""))
    end
    println(io)
end

function _render_operational_evidence(r, io; markdown=false)
    pre = _pre(markdown)
    d = get(r.results, :operational, Dict()); c = get(d, "winding_limit_coverage", Dict())
    counts = get(c, "transformer_counts", Dict())
    n_assessed_xf = sum(get(counts, k, 0) for k in ("absent", "partial", "present", "malformed"); init=0)
    if n_assessed_xf > 0
        println(io, "\n$(pre)n-winding transformer caps (declared, not a solved result): " *
            join(["$(_humanize(k)) $(counts[k])" for k in ("present", "partial", "absent", "malformed") if counts[k] > 0], ", ") * ".")
        c["n_windings_without_caps"] > 0 &&
            println(io, "$pre$(c["n_windings_without_caps"]) winding(s) have neither `i_max` nor `s_max` (see W.OPS.XFMR_UNCONSTRAINED).")
    end
    reach = get(d, "feeder_length", [])
    distance(v) = v === nothing ? "unassessed" : "$(round(v; digits=1)) m"
    assessed = filter(z -> z["status"] == "assessed", reach)
    if !isempty(assessed)
        println(io, "\n$(pre)Farthest bus from the nearest supply boundary (declared line lengths; up to 10 zones):")
        for z in Iterators.take(assessed, 10)
            println(io, "$pre- $(z["zone_anchor"]): $(distance(z["boundary_reach_m"])) " *
                "(from the zone anchor: $(distance(z["anchor_extent_m"])))")
        end
    end
    unassessed = filter(z -> z["status"] != "assessed" && z["n_buses"] > 1, reach)
    if !isempty(unassessed)
        reasons = Dict{String,Int}()
        for z in unassessed; reasons[_humanize(z["reason"])] = get(reasons, _humanize(z["reason"]), 0) + 1; end
        println(io, "\n$(pre)Supply-boundary distance unassessed for $(length(unassessed)) zone(s): " *
            join(["$k ($v)" for (k, v) in sort!(collect(reasons), by=first)], ", ") * ". " *
            "Supported boundaries: voltage sources and untapped two-port n-winding, single-phase, wye-delta and " *
            "delta-wye transformers with consistent voltage bases.")
    end
    role_text = Dict("source_beyond_port" => "source beyond (possible supply)",
        "no_source_beyond_port" => "no source beyond (load side)", "unresolved" => "role unresolved")
    shared = sort!(filter(z -> z["n_incident_transformers"] > 1, reach), by=z -> (-z["n_incident_transformers"], z["zone_anchor"]))
    if !isempty(shared)
        println(io, "\n$(pre)Zones with several transformers attached: $(length(shared)). Only ports with a source " *
            "beyond them can supply the zone; two or more such ports mean parallel supply worth reviewing.")
        for z in Iterators.take(shared, 10)
            band = something(z["band"], "unknown")
            roles = z["n_ports_by_role"]
            println(io, "$pre- $(z["zone_anchor"]): $(z["n_buses"]) buses, $(z["n_loads"]) loads, " *
                "$(z["n_incident_transformers"]) transformers; voltage band $band; ports with a source beyond: " *
                "$(roles["source_beyond_port"]), load side: $(roles["no_source_beyond_port"]), unresolved: $(roles["unresolved"]).")
            for p in Iterators.take(filter(p -> p["kind"] == "transformer", z["boundaries"]), 5)
                println(io, "$pre    $(p["subtype"])/$(p["id"]) winding $(p["winding"]) at $(p["bus"]): " *
                    role_text[p["port_role"]] * (p["reason"] === nothing ? "" : " — $(_humanize(p["reason"]))"))
            end
        end
    end
    util = get(d, "transformer_utilisation", [])
    n_upper = count(u -> u["estimate_status"] == "upper_bound", util)
    n_upper > 0 && println(io, "\n$pre$n_upper transformer load estimate(s) are upper bounds (parallel paths); " *
        "they do not trigger overload warnings.")
    println(io)
end

function _render_provenance_evidence(r, io; markdown=false)
    d = get(get(r.results, :provenance, Dict()), "impedance_transform", Dict())
    es = get(d, "evidence_by_linecode", Dict()); isempty(es) && return
    types = get(d, "by_type", Dict())
    n_src = count(e -> haskey(e, "finding_suppressed"), values(es))
    flagged(k) = count(id -> !haskey(get(es, id, Dict()), "finding_suppressed"), get(types, k, []))
    named = [(k, label) for (k, label) in (("kron_reduced", "possible Kron reduction"),
        ("phase_to_neutral", "phase-to-neutral"), ("modified_phase_to_neutral", "modified phase-to-neutral"),
        ("unknown", "no pattern")) if flagged(k) > 0]
    isempty(named) && n_src == 0 && return
    println(io, "\n$(_pre(markdown))Three-wire linecode patterns (hints, not history): " *
        (isempty(named) ? "none flagged" : join(["$(flagged(k)) $label" for (k, label) in named], ", ")) *
        (n_src > 0 ? "; $n_src source equivalent(s) not flagged" : "") * ". See the matching INFO findings.\n")
end

# Keep ambiguous attribution separate from radial nominal-demand estimates.
function _render_nameplate_estimates(r, io; markdown=false)
    estimates = get(get(r.results, :operational, Dict()), "transformer_utilisation", [])
    isempty(estimates) && return
    pre = _pre(markdown)
    println(io, "\n$(pre)Transformer nameplate comparison (nominal load estimate):\n")
    for (status, label) in (("radial_component", "Radial component estimates"), ("upper_bound", "Upper-bound estimates"))
        entries = sort!(filter(u -> get(u, "estimate_status", "radial_component") == status, estimates);
            by=u -> (get(u,"subtype",""), u["id"]))
        isempty(entries) && continue
        println(io, "$pre$label ($(length(entries))):\n")
        status == "upper_bound" && println(io, "$(pre)Attribution is ambiguous; these do not trigger overload warnings.\n")
        if markdown
            println(io, "| ID | Nameplate | Nominal demand/nameplate (est.) |")
            println(io, "|---|---|---:|")
        end
        for u in entries
            marker = status == "radial_component" && u["utilisation_pct"] > 90 ? " ⚠" : ""
            if markdown
                println(io, "| $(u["id"]) | $(_fmt_mva(u["s_rating_va"])) | $(_fmt_pct(u["utilisation_pct"]))$marker |")
            else
                println(io, "    $(u["id"]): $(_fmt_mva(u["s_rating_va"])) nameplate; $(_fmt_pct(u["utilisation_pct"]))$marker")
            end
        end
        println(io)
    end
end
