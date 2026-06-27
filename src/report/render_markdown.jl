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
    _md_section_findings(r, io, :connectivity)
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
            flag = u["utilisation_pct"] > 90 ? " ⚠" : ""
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
