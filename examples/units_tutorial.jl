# Units, bases, scaling, and economics — one feeder, two voltage levels.
#
#   julia --project=test examples/units_tutorial.jl
#
# Companion to docs/src/tutorial_units.md. Both share the same arc:
#   SI data model vs per-unit solver scaling → derive V/Z/I/Y bases by hand and
#   check them against the engine → demonstrate SI ≡ per-unit on the same OPF →
#   price the dispatch ($/kWh → $/h) and reconstruct the objective from the
#   result dict → integrate the rate over a day ($/h → $).
#
# The point. Three unit systems are routinely conflated: the units data is
# stored in (BMOPF: SI, except cost in $/kWh), the units the solver computes in
# (per_unit keyword — a reversible change of variables), and the units the
# objective is priced in ($/h — a rate, not money). Errors in any of the three
# are silent rescalings of the answer; this script makes each layer explicit.

using BMOPFTools, JuMP, Ipopt

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
sep(t) = println("\n" * "="^72 * "\n  " * t * "\n" * "="^72)

# ── 1–2. Load the feeder: 11 kV source, Dyn transformer, 400 V mains ─────────
sep("1. One feeder, two voltage levels")
path = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "LV1_14bus", "Master.dss")
net  = from_dss(path)

src  = first(values(net["voltage_source"]))
xfmr = first(values(net["transformer"]["delta_wye"]))
println("source v_magnitude    : ", round.(Float64.(src["v_magnitude"]); digits = 2),
        " V   (11 kV / √3 phase-to-neutral)")
println("transformer v_nom     : ", xfmr["v_nom_from"], " V -> ", xfmr["v_nom_to"],
        " V (line-to-line), s_rating ", xfmr["s_rating"], " VA")

# ── 3. Derive the bases by hand, verify against the engine ───────────────────
sep("2. Bases by hand: V_base seeds at the source, changes only at transformers")
s_base    = 1e6                                                  # VA, solver default
v_base_mv = maximum(abs, Float64.(src["v_magnitude"]))
v_base_lv = v_base_mv * xfmr["v_nom_to"] / xfmr["v_nom_from"]

println("           V_base        Z_base=V²/S   I_base=S/V   Y_base=S/V²")
for (lvl, vb) in (("MV", v_base_mv), ("LV", v_base_lv))
    println(lvl, "   ", lpad(round(vb; digits = 3), 10), " V",
            lpad(round(vb^2 / s_base; sigdigits = 4), 12), " Ω",
            lpad(round(s_base / vb; sigdigits = 5), 11), " A",
            lpad(round(s_base / vb^2; sigdigits = 4), 11), " S")
end

ext   = Base.get_extension(BMOPFTools, :BMOPFOpfExt)   # internal — verification only
bases = ext._compute_bases(net, s_base)
@assert all(isapprox(bases.v_base[b], b == src["bus"] ? v_base_mv : v_base_lv;
                     rtol = 1e-12) for b in keys(bases.v_base))
println("hand-derived bases match the engine on all ", length(bases.v_base), " buses ✓")

# ── 4. SI ≡ per-unit on the same OPF ─────────────────────────────────────────
sep("3. Same case, solved in SI and in per-unit")
net_ready, _ = augment_case(net; recipe = AugmentationRecipe())
src_id = first(keys(net_ready["voltage_source"]))
net_ready["voltage_source"][src_id]["cost"] = [0.25, 0.25, 0.25]        # $/kWh import
net_ready["generator"] = Dict{String,Any}("der1" => Dict{String,Any}(
    "bus" => "b3230", "terminal_map" => ["a", "b", "c", "n"],
    "configuration" => "WYE",
    "p_min" => zeros(3),         "p_max" => fill(5000.0, 3),            # W per phase
    "q_min" => fill(-3000.0, 3), "q_max" => fill(3000.0, 3),            # var per phase
    "cost"  => [0.10, 0.10, 0.10]))                                     # $/kWh

res_pu = solve_opf(net_ready; optimizer = OPT)                  # per_unit=true default
res_si = solve_opf(net_ready; optimizer = OPT, per_unit = false)
dv = maximum(abs(res_pu["bus"][b][t]["vm"] - res_si["bus"][b][t]["vm"])
             for b in keys(res_pu["bus"]) for t in keys(res_pu["bus"][b]))
println("objective  pu / si : ", res_pu["objective"], " / ", res_si["objective"], " \$/h")
println("max |ΔV|           : ", round(dv; sigdigits = 3), " V")
for (name, r) in (("per-unit", res_pu), ("SI", res_si))
    println(rpad(name, 9), ": ", lpad(r["opt_profile"]["barrier_iterations"], 3),
            " barrier iterations (scaling changes the path, not the answer)")
end

# ── 6. Reconstruct the objective from the result dict ────────────────────────
sep("4. Economics: rebuild the \$/h objective by hand")
p_src = [ph["ps"] for ph in values(res_pu["voltage_source"][src_id])]
p_der = [ph["pg"] for ph in values(res_pu["generator"]["der1"])]
obj_hand = sum(0.25 .* p_src ./ 1000) + sum(0.10 .* p_der ./ 1000)      # $/kWh · W/1000
println("grid import per phase : ", round.(p_src; digits = 1), " W")
println("DER dispatch per phase: ", round.(p_der; digits = 1), " W")
println("objective hand / solver: ", obj_hand, " / ", res_pu["objective"], " \$/h")
@assert isapprox(obj_hand, res_pu["objective"]; rtol = 1e-10)

# ── 7. Rate → energy: integrate over a day ───────────────────────────────────
sep("5. From \$/h to \$: multiply each snapshot's rate by its duration")
ts_path  = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "lv1_14bus_timeseries.json")
ts_ready, _ = augment_case(parse_bmopf(ts_path); recipe = AugmentationRecipe())
rates = [solve_opf(ts_ready; optimizer = OPT, t_index = t)["objective"] for t in 1:24]
Δt_h  = 1.0                                                     # hourly steps
println("rates \$/h: min ", round(minimum(rates); digits = 2),
        " (midday export credited), max ", round(maximum(rates); digits = 2),
        " (evening peak)")
println("daily energy cost = Σ rate·Δt = ", round(sum(rates .* Δt_h); digits = 2), " \$")
