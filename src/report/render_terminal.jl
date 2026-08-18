# report/render_terminal.jl

"""
    render_terminal(report, io; color, verbose)

Write a human-readable text report to `io`.
"""
function render_terminal(report::SummaryReport, io::IO;
                          color::Bool=false, verbose::Bool=true)
    _render_header(report, io; color)
    _render_inventory(report, io; color)
    _render_voltage_levels(report, io; color)
    _render_connectivity(report, io; color)
    _render_diversity(report, io; color)
    _render_operational(report, io; color)
    _render_preflight(report, io; color)
    _render_provenance(report, io; color)
    _render_spec_benchmark(report, io; color)
    _render_quality(report, io; color, verbose)
end

# ---------------------------------------------------------------------------

function _render_header(r::SummaryReport, io::IO; color::Bool=false)
    _section_header(io, "BMOPF NETWORK SUMMARY REPORT"; color)
    _kv_row(io, "Case name",  something(r.network_name, "(unnamed)"))
    _kv_row(io, "Generated",  Dates.format(r.generated_at, "yyyy-mm-dd HH:MM:SS"))
    findings_summary = "$(length(errors(r))) errors, $(length(warnings(r))) warnings, $(length(infos(r))) info"
    _kv_row(io, "Findings",   findings_summary)
    prov = get(r.results, :provenance, nothing)
    if prov isa Dict && haskey(prov, "convention")
        _kv_row(io, "Convention", prov["convention"])
    end
end

function _render_inventory(r::SummaryReport, io::IO; color::Bool=false)
    d = get(r.results, :inventory, nothing)
    d === nothing && return
    _section_header(io, "1. COMPONENT INVENTORY"; color)

    components = ["bus","line","linecode","voltage_source","load","generator",
                  "shunt","switch","transformer","ibr","control_profile"]
    w = 20
    for comp in components
        info = get(d, comp, nothing)
        info isa Dict || continue
        n = get(info, "total", 0)
        n == 0 && continue
        println(io, "  $(rpad(comp, w)) $n")

        # sub-breakdowns
        if comp == "bus"
            for (np, cnt) in sort(collect(get(info, "by_n_phases", Dict())), by=x->x[1])
                println(io, "    $(rpad("  $np-phase", w-2)) $cnt")
            end
        elseif comp == "load"
            println(io, "    $(rpad("  total P", w-2)) $(_fmt_mw(get(info,"total_p_w",0.0)))")
            println(io, "    $(rpad("  total Q", w-2)) $(_fmt_mvar(get(info,"total_q_var",0.0)))")
            for (cfg, cnt) in sort(collect(get(info, "by_configuration", Dict())), by=x->x[1])
                println(io, "    $(rpad("  $cfg", w-2)) $cnt")
            end
        elseif comp == "generator"
            println(io, "    $(rpad("  total P cap", w-2)) $(_fmt_mw(get(info,"total_p_cap_w",0.0)))")
        elseif comp == "transformer"
            for (type, cnt) in sort(collect(get(info, "by_type", Dict())), by=x->x[1])
                println(io, "    $(rpad("  $type", w-2)) $cnt")
            end
        elseif comp == "line"
            println(io, "    $(rpad("  with linecode", w-2)) $(get(info,"with_linecode",0))")
        elseif comp == "ibr"
            cap = round(get(info, "total_s_max_va", 0.0) / 1e6, digits=3)
            println(io, "    $(rpad("  total S cap", w-2)) $cap MVA")
            for (topo, cnt) in sort(collect(get(info, "by_topology", Dict())), by=x->x[1])
                println(io, "    $(rpad("  $topo", w-2)) $cnt")
            end
        end
    end
end

function _render_voltage_levels(r::SummaryReport, io::IO; color::Bool=false)
    d = get(r.results, :voltage_levels, nothing)
    d === nothing && return
    _section_header(io, "2. VOLTAGE LEVELS"; color)

    levels = get(d, "levels", Dict())
    println(io, "  Voltage levels identified: $(get(d, "n_levels", 0))\n")
    w = 14
    println(io, "  $(rpad("Level", w)) $(rpad("Nominal", 12)) $(rpad("Buses", 7)) $(rpad("Lines", 7)) $(rpad("Loads", 7)) Generators")
    println(io, "  " * "─"^60)
    for (label, linfo) in sort(collect(levels), by=x -> -x[2]["nominal_v"])
        println(io, "  $(rpad(label, w)) $(rpad(_fmt_kv(linfo["nominal_v"]), 12)) " *
                    "$(rpad(linfo["n_buses"], 7)) $(rpad(linfo["n_lines"], 7)) " *
                    "$(rpad(linfo["n_loads"], 7)) $(linfo["n_generators"])")
    end

    transitions = get(d, "transformer_transitions", Any[])
    if !isempty(transitions)
        println(io, "\n  Transformer transitions:")
        for tr in transitions
            vg = get(tr, "vector_group", "")
            tag = isempty(vg) ? tr["subtype"] : "$(tr["subtype"]), $vg"
            println(io, "    $(tr["id"])  $(tr["level_from"]) → $(tr["level_to"])  [$tag]")
        end
    end

    _render_section_findings(r, io, :voltage_levels; color)
end

function _render_connectivity(r::SummaryReport, io::IO; color::Bool=false)
    d = get(r.results, :connectivity, nothing)
    d === nothing && return
    _section_header(io, "3. CONNECTIVITY & TOPOLOGY"; color)

    n_comp = get(d, "n_components", "?")
    connected = get(d, "is_connected", false)
    radial    = get(d, "is_radial", "?")
    println(io, "  Connected components:    $n_comp  $(connected ? "(fully connected)" : "⚠ DISCONNECTED")")
    println(io, "  Network topology:        $(radial == true ? "Radial" : "Meshed ($(get(d,"n_extra_edges",0)) extra edges)")")

    println(io, "\n  Degree statistics:")
    _kv_row(io, "Mean degree",   round(Float64(get(d,"degree_mean",0)), digits=2); indent=4)
    _kv_row(io, "Max degree",    get(d,"degree_max","?"); indent=4)
    _kv_row(io, "Degree-1 buses (end-nodes)", get(d,"n_degree_1","?"); indent=4)
    _kv_row(io, "Degree-2 buses (pass-through)", get(d,"n_degree_2","?"); indent=4)

    depth = get(d, "tree_depth_max", nothing)
    depth !== nothing && _kv_row(io, "Max tree depth (hops)", depth; indent=2)

    dangling = get(d, "dangling_buses", String[])
    !isempty(dangling) && println(io, "\n  Dangling buses: $(join(dangling, ", "))")

    isolated = get(d, "open_switch_isolated_buses", String[])
    !isempty(isolated) && println(io, "  Open-switch isolated buses: $(join(isolated, ", "))")

    _render_section_findings(r, io, :connectivity; color)
end

function _render_diversity(r::SummaryReport, io::IO; color::Bool=false)
    d = get(r.results, :diversity, nothing)
    d === nothing && return
    _section_header(io, "4. DIVERSITY & VARIANCE"; color)

    score = get(d, "symmetry_score", "?")
    n_flagged = get(d, "n_flagged_categories", 0)
    println(io, "  Overall symmetry score:  $score  ($n_flagged category/ies flagged)\n")

    for comp in ("load", "generator", "line", "linecode", "transformer", "bus")
        cd = get(d, comp, nothing)
        cd isa Dict && get(cd, "analysed", false) || continue
        flag = get(cd, "symmetry_flag", false) ? " ⚠" : ""
        println(io, "  $comp$flag")

        for stat_key in ("p_nom", "q_nom", "p_max", "length", "R_series_1_1", "s_rating")
            stats = get(cd, stat_key, nothing)
            stats isa Dict || continue
            n   = get(stats, "n",    "?")
            mn  = round(Float64(get(stats, "min",  0.0)), sigdigits=3)
            mx  = round(Float64(get(stats, "max",  0.0)), sigdigits=3)
            cv  = round(Float64(get(stats, "cv",   0.0)), digits=3)
            println(io, "    $(rpad(stat_key, 14)) min=$(mn)  max=$(mx)  CV=$(cv)  n=$(n)")
        end

        if haskey(cd, "n_distinct_pq_tuples")
            println(io, "    Distinct (p,q) tuples: $(cd["n_distinct_pq_tuples"]) / $(get(cd,"n_total_loads","?"))")
        end
        if haskey(cd, "n_with_voltage_bounds")
            println(io, "    Buses with voltage bounds: $(cd["n_with_voltage_bounds"])  ($(cd["pct_with_voltage_bounds"])%)")
        end
    end

    _render_section_findings(r, io, :diversity; color)
end

function _render_operational(r::SummaryReport, io::IO; color::Bool=false)
    d = get(r.results, :operational, nothing)
    d === nothing && return
    _section_header(io, "5. LOADING & OPERATIONAL SUMMARY"; color)

    tl = get(d, "total_load", Dict())
    if !isempty(tl)
        println(io, "  Total installed load:")
        _kv_row(io, "P", _fmt_mw(get(tl,"p_w",0.0)); indent=4)
        _kv_row(io, "Q", _fmt_mvar(get(tl,"q_var",0.0)); indent=4)
        pf = get(tl, "pf", nothing)
        pf !== nothing && _kv_row(io, "Power factor", "$(round(pf, digits=3)) $(get(tl,"pf_lag_lead",""))"; indent=4)
    end

    tg = get(d, "total_generation_capacity", Dict())
    if !isempty(tg)
        println(io, "  Total generation capacity:")
        _kv_row(io, "P_max", _fmt_mw(get(tg,"p_max_w",0.0)); indent=4)
    end

    glr = get(d, "generation_load_ratio", nothing)
    glr !== nothing && _kv_row(io, "Generation/load ratio", "$glr%")

    cfg = get(d, "load_by_configuration", Dict())
    if !isempty(cfg)
        println(io, "\n  Load by configuration:")
        for (c, p) in sort(collect(cfg), by=x->x[1])
            println(io, "    $(rpad(c, 12)) $(_fmt_mw(p))")
        end
    end

    xutil = get(d, "transformer_utilisation", Any[])
    if !isempty(xutil)
        println(io, "\n  Transformer utilisation (nominal load estimate):")
        for u in xutil
            bar = u["utilisation_pct"] > 90 ? " ⚠" : ""
            println(io, "    $(rpad(u["id"], 16)) $(rpad(_fmt_mva(u["s_rating_va"]) * " rating", 18)) " *
                        "$(_fmt_pct(u["utilisation_pct"]))$bar")
        end
    end

    tc = get(d, "line_thermal_coverage", Dict())
    if !isempty(tc)
        println(io, "\n  Line thermal limits:")
        println(io, "    $(tc["n_with_thermal_limit"]) / $(tc["n_lines"]) lines have thermal limit " *
                    "($(tc["pct_constrained"])% constrained)")
    end

    _render_section_findings(r, io, :operational; color)
    _render_section_findings(r, io, :load_models; color)
end

function _render_preflight(r::SummaryReport, io::IO; color::Bool=false)
    d = get(r.results, :preflight, nothing)
    d === nothing && return
    _section_header(io, "6. INFEASIBILITY PRE-FLIGHT"; color)

    ga = get(d, "generation_adequacy", Dict())
    if !isempty(ga)
        println(io, "  Generation adequacy:")
        _kv_row(io, "Total load",    _fmt_mw(get(ga,"total_load_w",0.0)); indent=4)
        _kv_row(io, "Gen capacity",  _fmt_mw(get(ga,"total_gen_cap_w",0.0)); indent=4)
        _kv_row(io, "Import dependent", get(ga,"import_dependent","?"); indent=4)
    end

    vb = get(d, "voltage_bound_tightness", Dict())
    if !isempty(vb)
        println(io, "  Voltage bounds:")
        _kv_row(io, "With lower bound", "$(get(vb,"n_with_lower_bound","?")) / $(get(vb,"n_buses","?"))"; indent=4)
        _kv_row(io, "With upper bound", "$(get(vb,"n_with_upper_bound","?")) / $(get(vb,"n_buses","?"))"; indent=4)
        _kv_row(io, "Without bounds",   get(vb,"n_without_bounds","?"); indent=4)
    end

    cc = get(d, "constraint_conflicts", Dict())
    nc = get(cc, "n_conflicts", 0)
    println(io, "  Constraint conflicts:    $nc $(nc == 0 ? "✓" : "⚠")")

    tr = get(d, "topological_risk", Dict())
    if !isempty(tr)
        println(io, "  Topological risk:")
        _kv_row(io, "Voltage sources", get(tr,"n_voltage_sources","?"); indent=4)
        _kv_row(io, "Single point of failure", get(tr,"single_point_of_failure","?"); indent=4)
    end

    println(io, "\n  TPIA module: $(get(d,"tpia_status","not_run"))")
    _render_section_findings(r, io, :preflight; color)
end

function _render_provenance(r::SummaryReport, io::IO; color::Bool=false)
    d = get(r.results, :provenance, nothing)
    d === nothing && return
    _section_header(io, "7. PROVENANCE & MODEL CONVENTIONS"; color)

    _kv_row(io, "Inferred convention", get(d, "convention", "undetermined"))

    wl = get(d, "wires_by_level", Dict())
    if !isempty(wl)
        println(io, "\n  Wires per voltage level:")
        for (label, info) in sort(collect(wl), by=x -> -x[2]["nominal_v"])
            println(io, "    $(rpad(label, 14)) $(rpad(info["wires"], 8)) " *
                        "($(info["n_with_neutral"]) of $(info["n_buses"]) buses carry neutral)")
        end
    end

    g = get(d, "grounding", Dict())
    if get(g, "n_buses_with_neutral", 0) > 0
        println(io, "\n  Neutral grounding:")
        _kv_row(io, "Buses with neutral",   g["n_buses_with_neutral"]; indent=4)
        _kv_row(io, "Neutral branches",     get(g, "n_neutral_branches", 0); indent=4)
        _kv_row(io, "Grounding points",     get(g, "n_grounding_points", 0); indent=4)
        _kv_row(io, "Neutral sections",     get(g, "n_neutral_components", "?"); indent=4)
        nfl = get(g, "n_floating", 0)
        _kv_row(io, "Floating sections",    "$nfl $(nfl == 0 ? "✓" : "⚠")"; indent=4)
    end

    lc = get(d, "linecodes", Dict())
    vc = get(lc, "verdict_counts", Dict())
    if !isempty(vc)
        println(io, "\n  Linecode impedance classification:")
        for verdict in ("distinct", "near_balanced", "exactly_balanced",
                        "decoupled", "not_applicable")
            haskey(vc, verdict) || continue
            println(io, "    $(rpad(verdict, 18)) $(vc[verdict])")
        end
    end

    lm = get(get(d, "line_models", Dict()), "counts", Dict())
    if !isempty(lm) && sum(values(lm)) > 0
        println(io, "\n  Line model topology:")
        for (m, lab) in (("series", "pure series"), ("symmetric_pi", "symmetric π"),
                         ("asymmetric_pi", "asymmetric π"), ("gamma", "Γ (one-sided)"))
            c = get(lm, m, 0); c > 0 || continue
            println(io, "    $(rpad(lab, 18)) $c")
        end
    end

    dd = get(d, "opendss_defaults", Dict())
    if !isempty(dd)
        nh = get(dd, "n_default_hits", 0)
        println(io, "\n  OpenDSS default fingerprints: " *
                    "$nh $(nh == 0 ? "✓ (none detected)" : "hit(s) — see findings")")
    end

    zones = get(d, "earthing_zones", Any[])
    if !isempty(zones)
        println(io, "\n  Earthing system per galvanic zone:")
        for z in zones
            vlab = isnan(z["nominal_v"]) ? "?" : _fmt_kv(z["nominal_v"])
            star = z["star_earthing"] == "solid" ? "solid" :
                   z["star_earthing"] == "impedance" ?
                       "R≈$(round(z["star_R_ohm"], sigdigits=2)) Ω" : "none"
            println(io, "    $(rpad(vlab, 10)) $(rpad("$(z["n_buses"]) bus(es)", 12)) " *
                        "$(rpad(z["wires"], 8)) star: $(rpad(star, 12)) " *
                        "+$(z["n_downstream_earths"]) downstream → $(z["tag"])")
        end
    end

    pc = get(d, "powerio_conversion", Dict())
    if get(pc, "n_classes", 0) > 0
        println(io, "\n  PowerIO conversion: $(pc["n_diagnostics"]) fidelity " *
                    "loss(es) in $(pc["n_classes"]) class(es) — see findings")
    end

    _render_section_findings(r, io, :provenance; color)
end

function _render_spec_benchmark(r::SummaryReport, io::IO; color::Bool=false)
    spec  = get(r.results, :spec, nothing)
    bench = get(r.results, :benchmark, nothing)
    (spec === nothing && bench === nothing) && return
    _section_header(io, "8. SPEC CONFORMANCE & BENCHMARK READINESS"; color)

    if spec isa Dict
        n_issues = get(spec, "n_conformance_issues", 0)
        _kv_row(io, "Conformance issues",
                "$n_issues $(n_issues == 0 ? "✓" : "⚠")")
        _kv_row(io, "Voltage sources",
                "$(get(spec, "n_voltage_sources", "?")) (spec requires 1)")
    end

    integ = get(r.results, :integrity, nothing)
    if integ isa Dict
        println(io, "\n  Structural integrity:")
        nri = get(integ, "n_reference_issues", 0)
        ndi = get(integ, "n_dimension_issues", 0)
        _kv_row(io, "Reference issues", "$nri $(nri == 0 ? "✓" : "⚠")"; indent=4)
        _kv_row(io, "Dimension issues", "$ndi $(ndi == 0 ? "✓" : "⚠")"; indent=4)
        nwr = get(integ, "n_without_reference", 0)
        _kv_row(io, "Galvanic islands",
                "$(get(integ, "n_galvanic_islands", "?")) " *
                "($nwr without voltage reference$(nwr == 0 ? " ✓" : " ⚠"))"; indent=4)
        if haskey(integ, "impedance_spread")
            _kv_row(io, "Line impedance spread",
                    "$(round(integ["impedance_spread"], sigdigits=3))×"; indent=4)
        end
    end

    if bench isa Dict
        println(io, "\n  Benchmark readiness:")
        _kv_row(io, "Objective well-posed",
                get(bench, "objective_wellposed", "?"); indent=4)
        _kv_row(io, "Only slack generation",
                get(bench, "only_slack_generation", "?"); indent=4)
        _kv_row(io, "Buses with |V| bounds",
                "$(get(bench, "pct_v_bounds", "?"))%"; indent=4)
        _kv_row(io, "vpn/vpp/vpos bounds",
                "$(get(bench,"n_vpn_bounds",0)) / $(get(bench,"n_vpp_bounds",0)) / $(get(bench,"n_vpos_bounds",0)) buses"; indent=4)
        _kv_row(io, "Lines with thermal limits",
                "$(get(bench, "pct_thermal_limits", "?"))%"; indent=4)

        sugg = get(bench, "suggestions", String[])
        if !isempty(sugg)
            println(io, "\n  Augmentation needed:")
            for s in sugg
                println(io, "    • $s")
            end
        end
    end

    _render_section_findings(r, io, :integrity; color)
    _render_section_findings(r, io, :spec; color)
    _render_section_findings(r, io, :benchmark; color)
end

function _render_quality(r::SummaryReport, io::IO; color::Bool=false, verbose::Bool=true)
    _section_header(io, "9. DATA QUALITY SUMMARY"; color)

    all_f = r.findings
    errs  = errors(all_f)
    warns = warnings(all_f)
    infs  = infos(all_f)
    println(io, "  Total findings: $(length(all_f))  " *
                "($(length(errs)) errors, $(length(warns)) warnings, $(length(infs)) info)\n")

    for (label, subset) in (("ERRORS", errs), ("WARNINGS", warns),
                             (verbose ? "INFO" : nothing, infs))
        label === nothing && continue
        isempty(subset) && continue
        println(io, "  $label:")
        for f in subset
            _fmt_finding(f, io; color, prefix="    ")
        end
    end
    println(io)
end

function _render_section_findings(r::SummaryReport, io::IO, section::Symbol;
                                   color::Bool=false)
    fs = filter(f -> f.section == section, r.findings)
    isempty(fs) && return
    println(io)
    for f in fs
        _fmt_finding(f, io; color, prefix="  ")
    end
end
