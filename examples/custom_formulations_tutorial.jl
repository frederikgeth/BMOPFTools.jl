# Custom formulations — CVR without a hook, then up the extension ladder.
#
#   julia --project=test examples/custom_formulations_tutorial.jl
#
# Companion to docs/src/tutorial_custom_formulations.md. Both share the arc:
#   rung 0: CVR is data (free tap + ZIP + priced import; the load model flips
#   the optimal tap direction) → rung 1: model_hook! constraint the schema
#   can't express (joint export cap across two PV systems) → rung 2: replace
#   the objective (balance the feeder head; epigraph spread → 0), then
#   re-anchor economics by composing generation_cost(ctx) → rung 3: staged
#   API, two snapshots in one model under a shared 5 kWh energy budget.
#
# The point. Climb no higher than the study requires; scale every physical
# literal by ctx.bases (the hook sees a per-unit model); a replaced objective
# is a replaced question — you own the economics.

using BMOPFTools, JuMP, Ipopt

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
sep(t) = println("\n" * "="^72 * "\n  " * t * "\n" * "="^72)

path = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "LV1_14bus", "Master.dss")
base, _ = augment_case(from_dss(path); recipe = AugmentationRecipe())
src_id  = first(keys(base["voltage_source"]))
base["voltage_source"][src_id]["cost"] = [0.25, 0.25, 0.25]
xfmr_id = first(keys(base["transformer"]["delta_wye"]))

# ── Rung 0: CVR from data alone ───────────────────────────────────────────────
sep("Rung 0 — CVR: load model × free tap (no hook)")
zip = Dict{String,Any}("alpha_z"=>[0.4],"alpha_i"=>[0.3],"alpha_p"=>[0.3],
                       "beta_z"=>[0.4],"beta_i"=>[0.3],"beta_p"=>[0.3])
for (label, model, free_tap) in (("constant-P, fixed tap","constant_power",false),
                                 ("constant-P, free tap", "constant_power",true),
                                 ("ZIP, fixed tap",       "zip",           false),
                                 ("ZIP, free tap",        "zip",           true))
    net = deepcopy(base)
    for (_, d) in net["load"]
        d["model"] = model
        model == "zip" && merge!(d, zip)
    end
    if free_tap
        net["transformer"]["delta_wye"][xfmr_id]["tap_min"] = 0.90
        net["transformer"]["delta_wye"][xfmr_id]["tap_max"] = 1.10
    end
    r = solve_opf(net; optimizer = OPT)
    p_imp = sum(ph["ps"] for ph in values(r["voltage_source"][src_id]))
    tap   = get(get(r["transformer"], xfmr_id, Dict()), "tap", 1.0)
    println(rpad(label, 24), "P_import=", rpad(round(p_imp; digits=1), 9),
            " W  tap=", round(tap; digits=4))
end

function with_ders(net; cost = 0.10)
    n = deepcopy(net)
    n["generator"] = Dict{String,Any}()
    for (gid, bus) in (("pv1","b3230"), ("pv2","b2656"))
        n["generator"][gid] = Dict{String,Any}(
            "bus" => bus, "terminal_map" => ["a","b","c","n"], "configuration" => "WYE",
            "p_min" => zeros(3), "p_max" => fill(4000.0, 3),
            "q_min" => fill(-2000.0, 3), "q_max" => fill(2000.0, 3),
            "cost" => fill(cost, 3))
    end
    n
end
function gen_p(ctx, gid)
    vr, vi   = ctx.vars[:vr],  ctx.vars[:vi]
    crg, cig = ctx.vars[:crg], ctx.vars[:cig]
    g = ctx.net["generator"][gid]; b, tm = g["bus"], g["terminal_map"]
    sum(@expression(ctx.model,
            (vr[(b,tm[k])] - vr[(b,"n")]) * crg[(gid,k)] +
            (vi[(b,tm[k])] - vi[(b,"n")]) * cig[(gid,k)]) for k in 1:3)
end

# ── Rung 1: joint export cap ──────────────────────────────────────────────────
sep("Rung 1 — model_hook!: joint 9 kW export cap across pv1+pv2")
net = with_ders(base; cost = -0.05)
r0 = solve_opf(net; optimizer = OPT)
pg0 = sum(ph["pg"] for g in values(r0["generator"]) for ph in values(g))
r1 = solve_opf(net; optimizer = OPT, model_hook! = ctx -> begin
    sb = ctx.bases === nothing ? 1.0 : ctx.bases.s_base
    @constraint(ctx.model, gen_p(ctx, "pv1") + gen_p(ctx, "pv2") <= 9_000.0 / sb)
end)
pg1 = sum(ph["pg"] for g in values(r1["generator"]) for ph in values(g))
println("joint DER output uncapped/capped: ", round(pg0; digits=1), " / ",
        round(pg1; digits=1), " W")
@assert isapprox(pg1, 9_000.0; rtol = 1e-4)

# ── Rung 2: balance the feeder head ───────────────────────────────────────────
sep("Rung 2 — replace the objective: balanced substation infeed")
src_p(ctx) = begin
    vr, vi   = ctx.vars[:vr], ctx.vars[:vi]
    crs, cis = ctx.vars[:cr_src], ctx.vars[:ci_src]
    vs = ctx.net["voltage_source"][src_id]; b, tm = vs["bus"], vs["terminal_map"]
    [@expression(ctx.model,
        (vr[(b,tm[k])] - vr[(b,"n")]) * crs[(src_id,k)] +
        (vi[(b,tm[k])] - vi[(b,"n")]) * cis[(src_id,k)]) for k in 1:3]
end
net = with_ders(base; cost = 0.10)
r0 = solve_opf(net; optimizer = OPT)
p0 = sort([ph["ps"] for ph in values(r0["voltage_source"][src_id])])
println("least-cost per-phase import: ", round.(p0; digits=1),
        " spread=", round(p0[end]-p0[1]; digits=1))
r2 = solve_opf(net; optimizer = OPT,
    model_hook! = ctx -> begin
        es = src_p(ctx); t_hi = @variable(ctx.model); t_lo = @variable(ctx.model)
        for e in es
            @constraint(ctx.model, e <= t_hi); @constraint(ctx.model, e >= t_lo)
        end
        @objective(ctx.model, Min, t_hi - t_lo)
        ctx.model[:spread] = t_hi - t_lo
    end,
    solution_hook! = (ctx, result) -> begin
        sb = ctx.bases === nothing ? 1.0 : ctx.bases.s_base
        result["head_spread_W"] = abs(JuMP.value(ctx.model[:spread])) * sb
    end)
p2 = sort([ph["ps"] for ph in values(r2["voltage_source"][src_id])])
println("balanced per-phase import  : ", round.(p2; digits=1),
        " spread=", round(r2["head_spread_W"]; digits=2), " W")
r3 = solve_opf(net; optimizer = OPT, model_hook! = ctx -> begin
    es = src_p(ctx); t_hi = @variable(ctx.model); t_lo = @variable(ctx.model)
    for e in es
        @constraint(ctx.model, e <= t_hi); @constraint(ctx.model, e >= t_lo)
    end
    sb = ctx.bases.s_base
    @objective(ctx.model, Min, generation_cost(ctx) + 1.0*(t_hi - t_lo)*sb/1000)
end)
p3 = sort([ph["ps"] for ph in values(r3["voltage_source"][src_id])])
println("balanced + cheap           : ", round.(p3; digits=1),
        "  DER total ", round(sum(ph["pg"] for g in values(r3["generator"]) for ph in values(g)); digits=1), " W")

# ── Rung 3: staged API, 2 periods, 5 kWh budget ──────────────────────────────
sep("Rung 3 — staged API: two snapshots, one 5 kWh energy budget")
netA = with_ders(base; cost = 0.10)
netB = deepcopy(netA)
for (_, d) in netB["load"]; d["p_nom"] = [0.4 * Float64(d["p_nom"][1])]; end
model = JuMP.Model(Ipopt.Optimizer); JuMP.set_silent(model)
ctxs = [build_opf_model(n; model = model, add_objective = false) for n in (netA, netB)]
sb = ctxs[1].bases.s_base
@constraint(model, sum(gen_p(c, "pv1") * 1.0 for c in ctxs) <= 5_000.0 / sb)
@objective(model, Min, sum(1.0 * generation_cost(c) for c in ctxs))
foreach(enforce_kcl!, ctxs)
optimize!(model)
results = [extract_result(c) for c in ctxs]
for (t, r) in enumerate(results)
    println("hour ", t, ": pv1 = ",
            round(sum(ph["pg"] for ph in values(r["generator"]["pv1"])); digits=1), " W")
end
