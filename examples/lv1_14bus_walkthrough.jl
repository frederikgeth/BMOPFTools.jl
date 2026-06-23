# =============================================================================
# LV1_14bus step-by-step walkthrough
# =============================================================================
# A real 14-bus LV feeder: 11 kV / 433 V delta-wye transformer, 9 cables,
# 4 normally-closed switches, 2 single-phase loads, 3 neutral reactors.
#
# Run from inside BMOPFTools (PowerIO.jl is a dependency, so no extra setup):
#   julia --project=. examples/lv1_14bus_walkthrough.jl
# =============================================================================

using BMOPFTools

sep(title) = println("\n", "─"^70, "\n  $title\n", "─"^70)

# ---------------------------------------------------------------------------
# 1. Parse OpenDSS → BMOPF dict (via PowerIO.jl)
# ---------------------------------------------------------------------------
sep("1. Parse DSS and convert to BMOPF")

dss_path = joinpath(@__DIR__, "..", "test", "data", "LV", "LV1_14bus", "Master.dss")
println("DSS file: ", relpath(dss_path))

net = from_dss(dss_path)

println("Network name : ", get(net, "name", "(unnamed)"))
println()

for comp_type in ("bus", "line", "linecode", "switch", "load", "shunt",
                  "voltage_source")
    n = length(get(net, comp_type, Dict()))
    n > 0 && println(rpad("  $comp_type", 20), ": $n")
end

xfmr = get(net, "transformer", Dict())
total_tx = sum(length(v) for v in values(xfmr) if v isa Dict; init=0)
println(rpad("  transformer", 20), ": $total_tx  (subtypes: $(join(keys(xfmr), ", ")))")

# ---------------------------------------------------------------------------
# 2. Inventory analysis
# ---------------------------------------------------------------------------
sep("2. Inventory")

findings = Finding[]
inv = inventory_analysis(net, findings)

println("Buses       : ", inv["bus"]["total"],
        "  (phases breakdown: ", inv["bus"]["by_n_phases"], ")")
println("Lines       : ", inv["line"]["total"],
        "  (", inv["line"]["with_linecode"], " with explicit linecode)")
println("Linecodes   : ", inv["linecode"]["total"])
println("Switches    : ", inv["switch"]["total"], "  (from Switches.dss)")
println("Loads       : ", inv["load"]["total"],
        "  total P = ", round(inv["load"]["total_p_w"] / 1000, digits=2), " kW",
        ",  Q = ", round(inv["load"]["total_q_var"] / 1000, digits=2), " kvar")
println("Shunts      : ", inv["shunt"]["total"], "  (neutral reactors → BMOPF shunts)")
tx_inv = inv["transformer"]
println("Transformers: ", tx_inv["total"],
        "  (", join(["$n × $t" for (t, n) in tx_inv["by_type"]], ", "), ")")

# ---------------------------------------------------------------------------
# 3. Connectivity analysis
# ---------------------------------------------------------------------------
sep("3. Connectivity")

conn = connectivity_analysis(net, findings)

println("Connected?     : ", conn["is_connected"])
println("Radial?        : ", conn["is_radial"],
        "  (", conn["n_extra_edges"], " extra edge(s) beyond spanning tree)")
println("Components     : ", conn["n_components"])
println("Source bus(es) : ", join(get(conn, "source_buses", ["?"]), ", "))
println("Tree depth     : ", get(conn, "tree_depth_max", "?"),
        "  (max hops from source)")
println()
println("Degree stats   : min=$(conn["degree_min"]),",
        " mean=$(round(conn["degree_mean"], digits=1)),",
        " max=$(conn["degree_max"])")
println("Leaf nodes     : ", conn["n_degree_1"],
        "  — ", join(sort(conn["degree_1_buses"]), ", "))

if !isempty(get(conn, "dangling_buses", []))
    println("Dangling buses : ", conn["dangling_buses"])
end

# ---------------------------------------------------------------------------
# 4. Voltage level analysis
# ---------------------------------------------------------------------------
sep("4. Voltage levels")

vl = voltage_level_analysis(net, findings)

println("Voltage levels : ", vl["n_levels"])
println()

for (label, info) in sort(collect(vl["levels"]), by=x -> x[2]["nominal_v"], rev=true)
    println("  ", rpad(label, 18),
            rpad("$(round(info["nominal_kv"], sigdigits=3)) kV", 12),
            "$(info["n_buses"]) bus(es),  ",
            "$(info["n_lines"]) line(s),  ",
            "$(info["n_loads"]) load(s)")
end

println()
println("Transformer voltage transitions:")
for t in vl["transformer_transitions"]
    println("  $(t["id"])  :  $(t["level_from"])  →  $(t["level_to"])",
            "  ($(t["bus_from"]) → $(t["bus_to"]))")
end

println()
if isempty(vl["unassigned_buses"])
    println("All buses assigned to a voltage level.")
else
    println("Unassigned buses: ", vl["unassigned_buses"])
end

# ---------------------------------------------------------------------------
# 5. Operational analysis
# ---------------------------------------------------------------------------
sep("5. Operational")

ops = operational_analysis(net, findings)

tl = ops["total_load"]
println("Total load       : ",
        round(tl["p_w"] / 1000, digits=2), " kW  +j",
        round(tl["q_var"] / 1000, digits=2), " kvar  ",
        "(pf = ", round(tl["pf"], digits=3), " ", tl["pf_lag_lead"], ")")

gc = ops["total_generation_capacity"]
println("Generation cap   : ", round(gc["p_max_w"] / 1000, digits=2), " kW  (import-dependent network)")

glr = ops["generation_load_ratio"]
println("Gen / load ratio : ", isnothing(glr) ? "0 %" : "$glr %")

println()
println("Transformer utilisation:")
for util in ops["transformer_utilisation"]
    println("  $(util["id"])  :  ",
            round(util["utilisation_pct"], digits=1), " %  of  ",
            round(util["s_rating_va"] / 1000, digits=1), " kVA",
            "  (apparent load = ",
            round(util["s_load_va"] / 1000, digits=2), " kVA)")
end

ltc = ops["line_thermal_coverage"]
println()
println("Line thermal limits: ",
        ltc["n_with_thermal_limit"], " of ", ltc["n_lines"],
        " lines have i_max set  (", ltc["pct_constrained"], "% constrained)")

# ---------------------------------------------------------------------------
# 6. Diversity / symmetry analysis
# ---------------------------------------------------------------------------
sep("6. Diversity and balance")

div = diversity_analysis(net, findings)

println("Symmetry score : ", div["symmetry_score"],
        "  (flagged categories: ", div["n_flagged_categories"], ")")

ld = div["load"]
if get(ld, "analysed", false)
    println("Load configs   : ", ld["configurations"])
    if haskey(ld, "p_nom")
        pm = ld["p_nom"]
        println("Load P spread  : mean=$(round(get(pm,"mean",0.0)/1000,digits=2)) kW,",
                " cv=$(round(get(pm,"cv",0.0),digits=3))")
    end
end

lc_div = div["linecode"]
if get(lc_div, "analysed", false)
    println("Mutual coupling: ", lc_div["pct_with_mutual_coupling"], "% of linecodes have off-diagonal terms")
end

# ---------------------------------------------------------------------------
# 7. Validation suite
# ---------------------------------------------------------------------------
sep("7. Validation")

comp_res   = completeness_check(net, findings)
schema_res = schema_check(net, findings)
dom_res    = domain_rules_check(net, findings)
red_res    = redundancy_check(net, findings)

n_missing = count(f -> f.code == "E.COMP.MISSING_REQUIRED", findings)
println("Completeness   : ",
        n_missing == 0 ? "all required fields present" : "$n_missing missing-field error(s)")

n_unk_types = schema_res["n_component_types_with_unknown"]
println("Schema         : ",
        n_unk_types == 0 ? "no unknown fields" :
        "$n_unk_types component type(s) with unknown fields")

zl = red_res["zero_loads"]["n"]
ul = red_res["unused_linecodes"]["n"]
println("Redundancy     : ",
        "$zl zero-value load(s),  $ul unused linecode(s)")
if !isempty(red_res["unused_linecodes"]["ids"])
    println("  Unused codes : ", join(red_res["unused_linecodes"]["ids"], ", "))
end

# ---------------------------------------------------------------------------
# 8. Infeasibility preflight
# ---------------------------------------------------------------------------
sep("8. Infeasibility preflight")

pre = infeasibility_preflight(net, findings)

ga = pre["generation_adequacy"]
println("Generation adequacy : ",
        ga["import_dependent"] ? "import-dependent" : "self-sufficient",
        "  (load = ", round(ga["total_load_w"]/1000, digits=2), " kW,",
        "  local cap = ", round(ga["total_gen_cap_w"]/1000, digits=2), " kW)")

vbt = pre["voltage_bound_tightness"]
n_no_bounds = get(vbt, "n_without_bounds", 0)
println("Voltage bounds      : ",
        n_no_bounds == 0 ? "all buses bounded" :
        "$n_no_bounds bus(es) have no voltage bounds set")

cc = pre["constraint_conflicts"]
println("Constraint conflicts: ", cc["n_conflicts"])

tr = pre["topological_risk"]
println("Single point of failure: ", tr["single_point_of_failure"],
        "  (", tr["n_voltage_sources"], " source(s))")

# ---------------------------------------------------------------------------
# 9. Findings summary across all steps above
# ---------------------------------------------------------------------------
sep("9. Accumulated findings")

n_err  = length(errors(findings))
n_warn = length(warnings(findings))
n_info = length(infos(findings))
println("ERRORs   : $n_err")
println("WARNINGs : $n_warn")
println("INFOs    : $n_info")

for f in errors(findings)
    println("  ERROR  [$(f.code)]  $(f.message)")
end
for f in warnings(findings)
    println("  WARN   [$(f.code)]  $(f.message)")
end

# ---------------------------------------------------------------------------
# 10. Full pipeline report
# ---------------------------------------------------------------------------
sep("10. Full analyze() — terminal report")

report = analyze(net)
render(report, stdout; color=true)

# ---------------------------------------------------------------------------
# 11. Export BMOPF JSON
# ---------------------------------------------------------------------------
sep("11. Export BMOPF JSON")

json_out = joinpath(@__DIR__, "lv1_14bus.json")
write_bmopf(net, json_out)
println("Written: ", relpath(json_out), "  (", round(filesize(json_out) / 1024, digits=1), " kB)")

# ---------------------------------------------------------------------------
# 12. Export Markdown summary
# ---------------------------------------------------------------------------
sep("12. Export Markdown summary")

md_out = joinpath(@__DIR__, "lv1_14bus_report.md")
open(md_out, "w") do io
    render_markdown(report, io)
end
println("Written: ", relpath(md_out), "  (", round(filesize(md_out) / 1024, digits=1), " kB)")
