# [Custom formulations: CVR, envelopes, and hooks](@id custom-formulations)

*The reference OPF is a floor, not a ceiling: conservation voltage reduction
without writing a hook, a connection-point export cap with one constraint, a
phase-balancing objective with three lines — and a two-period energy budget
through the staged API.*

Research formulations rarely stop at least-cost dispatch: conservation voltage
reduction (CVR), dynamic operating envelopes, unbalance mitigation, and
multi-period coupling all *change the optimisation problem*. The engine's
answer is a ladder of extension points, documented in the
[OPF reference](opf.md) — the `model_hook!` seam and the
[staged API](opf.md#staged-api). This tutorial climbs that ladder with worked
studies, one rung at a time, and starts with the rung people skip: checking
whether the study you want is *already expressible* without touching the
formulation at all. Every block runs at build time.

!!! note "Prerequisites"
    A Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`, and three
    earlier tutorials this one leans on hard:
    [units & economics](tutorial_units.md) (`ctx.bases`, the \$/h objective),
    [load models](tutorial_load_models.md) (why voltage-dependence matters),
    and [tap optimisation](tutorial_tap.md) (the free-tap mechanics).

## 1. The extension ladder

| Rung | Mechanism | Reach |
|---|---|---|
| 0 | data configuration only | anything the schema already says: costs, bounds, free taps, control profiles |
| 1 | `model_hook!` adds constraints | couplings the schema cannot express (aggregate caps, fairness, custom devices via `ctx.kcl_r/i`) |
| 2 | `model_hook!` replaces the objective (+ variables), `solution_hook!` reads back | different *questions*: minimax, unbalance, estimation |
| 3 | staged API (`build_opf_model` → `generation_cost` → `enforce_kcl!` → `extract_result`) | several snapshots in one model: storage, ramps, energy budgets |

Climb no higher than the study requires — every rung up costs reviewability,
and a hook that re-implements something the schema already says is a bug
farm. The running network: the LV1 14-bus feeder, augmented, grid import
priced at 0.25 \$/kWh.

```@example hooks
using BMOPFTools, JuMP, Ipopt

path = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "LV1_14bus", "Master.dss")
base, _ = augment_case(from_dss(path); recipe = AugmentationRecipe())
src_id  = first(keys(base["voltage_source"]))
base["voltage_source"][src_id]["cost"] = [0.25, 0.25, 0.25]
xfmr_id = first(keys(base["transformer"]["delta_wye"]))
OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

println("LV voltage floor from augmentation (vpn_min): ",
        round(base["bus"]["b3230"]["vpn_min"][1]; digits = 1), " V")
```

## 2. Rung 0 — CVR needs no hook at all

Conservation voltage reduction — operating the feeder at the low end of the
voltage band so that voltage-dependent demand shrinks — sounds like a custom
formulation. It is not. Its three ingredients are all data: a **voltage-dependent
load model**, a **controllable voltage** (free the transformer tap with
`tap_min < tap_max`), and the standard cost objective (import is priced, so
minimising cost minimises demand). Run the 2×2 experiment — load model ×
tap freedom:

```@example hooks
zip = Dict{String,Any}(
    "alpha_z" => [0.4], "alpha_i" => [0.3], "alpha_p" => [0.3],
    "beta_z"  => [0.4], "beta_i"  => [0.3], "beta_p"  => [0.3])

println("case                      P_import      tap      LV Vmin")
for (label, model, free_tap) in (
        ("constant-P, fixed tap", "constant_power", false),
        ("constant-P, free tap",  "constant_power", true),
        ("ZIP, fixed tap",        "zip",            false),
        ("ZIP, free tap",         "zip",            true))
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
    vmin  = minimum(v["vm"] for (b, ts) in r["bus"] if b != "b2577"
                            for (t, v) in ts if t != "n")
    println(rpad(label, 24), lpad(round(p_imp; digits = 1), 10), " W",
            lpad(round(tap; digits = 4), 9), lpad(round(vmin; digits = 1), 9), " V")
end
```

Read the tap column: **the load model flips the sign of the optimal
decision.** With constant-power loads the optimiser *raises* the feeder
voltage (tap toward 0.91 — a higher secondary voltage means less current for
the same power, so lower copper losses; worth a few tens of watts). With ZIP
loads it slams the tap the other way (1.10) and rides the feeder down onto
the augmentation's 0.9 pu voltage floor — shedding roughly a tenth of the
demand. That *is* CVR, emerging from data alone; and it is also a warning
shot from the [load-models tutorial](tutorial_load_models.md): run a CVR
study with constant-power loads and the method looks worthless by
construction. No `model_hook!` was harmed — nor needed.

## 3. Rung 1 — a constraint the schema cannot express

Now something genuinely inexpressible in data: two rooftop PV systems at
different buses share **one connection agreement** — their *combined* export
may not exceed a cap (the flat ancestor of a dynamic operating envelope).
Per-device `p_max` cannot say "jointly"; a one-line hook can. The hook builds
each generator's total active power the same way the engine's own objective
does — the bilinear ``\sum_k \Delta v_k \cdot c^g_k`` over phase terms — and
constrains the sum. One unit rule to burn in: **the hook sees the model in
per-unit** (the default), so a physical literal must be divided by
`ctx.bases.s_base` ([units tutorial](tutorial_units.md)).

```@example hooks
function with_ders(net; cost = 0.10)
    n = deepcopy(net)
    n["generator"] = Dict{String,Any}()
    for (gid, bus) in (("pv1", "b3230"), ("pv2", "b2656"))
        n["generator"][gid] = Dict{String,Any}(
            "bus" => bus, "terminal_map" => ["a", "b", "c", "n"],
            "configuration" => "WYE",
            "p_min" => zeros(3),          "p_max" => fill(4000.0, 3),
            "q_min" => fill(-2000.0, 3),  "q_max" => fill(2000.0, 3),
            "cost"  => fill(cost, 3))
    end
    n
end

# a generator's total P as a JuMP expression, from the hook context
function gen_p(ctx, gid)
    vr, vi   = ctx.vars[:vr],  ctx.vars[:vi]
    crg, cig = ctx.vars[:crg], ctx.vars[:cig]
    g = ctx.net["generator"][gid]
    b, tm = g["bus"], g["terminal_map"]
    sum(@expression(ctx.model,
            (vr[(b, tm[k])] - vr[(b, "n")]) * crg[(gid, k)] +
            (vi[(b, tm[k])] - vi[(b, "n")]) * cig[(gid, k)]) for k in 1:3)
end

net = with_ders(base; cost = -0.05)            # export credited: both want full output
r0  = solve_opf(net; optimizer = OPT)
pg0 = sum(ph["pg"] for g in values(r0["generator"]) for ph in values(g))

cap_W = 9_000.0
r1 = solve_opf(net; optimizer = OPT, model_hook! = ctx -> begin
    sb = ctx.bases === nothing ? 1.0 : ctx.bases.s_base   # W → per-unit
    @constraint(ctx.model, gen_p(ctx, "pv1") + gen_p(ctx, "pv2") <= cap_W / sb)
end)
pg1 = sum(ph["pg"] for g in values(r1["generator"]) for ph in values(g))

println("joint DER output, uncapped : ", round(pg0; digits = 1), " W")
println("joint DER output, capped   : ", round(pg1; digits = 1), " W  (cap ", cap_W, ")")
@assert isapprox(pg1, cap_W; rtol = 1e-4)
```

The cap binds exactly, and *how* the 9 kW splits between the two systems —
and across their phases — is decided by the network: the optimiser curtails
where it relieves the feeder most. That co-optimised allocation is precisely
what per-device static limits cannot deliver, and scaling the same pattern
over feeder scenarios is how operating-envelope studies are built.

## 4. Rung 2 — replace the question: balance the feeder head

The standard objective answers "cheapest dispatch". A distribution engineer
often asks a different question: *how balanced can the substation infeed be?*
That is a minimax problem — new variables, new objective. The hook adds
epigraph variables bracketing the three per-phase source powers and minimises
the spread; `solution_hook!` reads the achieved value back into the result in
SI:

```@example hooks
src_p(ctx) = begin
    vr, vi   = ctx.vars[:vr],     ctx.vars[:vi]
    crs, cis = ctx.vars[:cr_src], ctx.vars[:ci_src]
    vs = ctx.net["voltage_source"][src_id]
    b, tm = vs["bus"], vs["terminal_map"]
    [@expression(ctx.model,
        (vr[(b, tm[k])] - vr[(b, "n")]) * crs[(src_id, k)] +
        (vi[(b, tm[k])] - vi[(b, "n")]) * cis[(src_id, k)]) for k in 1:3]
end

net = with_ders(base; cost = 0.10)
r0  = solve_opf(net; optimizer = OPT)
p0  = sort([ph["ps"] for ph in values(r0["voltage_source"][src_id])])
println("least-cost per-phase import : ", round.(p0; digits = 1),
        "   spread ", round(p0[end] - p0[1]; digits = 1), " W")

r2 = solve_opf(net; optimizer = OPT,
    model_hook! = ctx -> begin
        es   = src_p(ctx)
        t_hi = @variable(ctx.model)
        t_lo = @variable(ctx.model)
        for e in es
            @constraint(ctx.model, e <= t_hi)
            @constraint(ctx.model, e >= t_lo)
        end
        @objective(ctx.model, Min, t_hi - t_lo)
        ctx.model[:spread] = t_hi - t_lo
    end,
    solution_hook! = (ctx, result) -> begin
        sb = ctx.bases === nothing ? 1.0 : ctx.bases.s_base
        result["head_spread_W"] = abs(JuMP.value(ctx.model[:spread])) * sb
    end)
p2 = sort([ph["ps"] for ph in values(r2["voltage_source"][src_id])])
println("balanced   per-phase import : ", round.(p2; digits = 1),
        "   spread ", round(r2["head_spread_W"]; digits = 2), " W")
```

From a ``\sim 7`` kW spread (two single-phase customers plus asymmetric PV
relief) to **exactly balanced** — the DERs re-dispatch per phase to make the
MV network upstream see a symmetric load. But notice what we gave up: the
objective now says *nothing* about cost, and any perfectly balanced operating
point is optimal, so the solver returned an arbitrary member of that set. A
replaced objective means you own the economics. The repair is composition —
[`generation_cost`](@ref) hands you the engine's own \$/h expression to blend
back in:

```@example hooks
r3 = solve_opf(net; optimizer = OPT, model_hook! = ctx -> begin
    es   = src_p(ctx)
    t_hi = @variable(ctx.model); t_lo = @variable(ctx.model)
    for e in es
        @constraint(ctx.model, e <= t_hi)
        @constraint(ctx.model, e >= t_lo)
    end
    sb = ctx.bases.s_base
    # spread is per-unit power → ×s_base/1000 puts it in kW, penalised at 1 $/kWh-equivalent,
    # commensurate with generation_cost's $/h.
    @objective(ctx.model, Min, generation_cost(ctx) + 1.0 * (t_hi - t_lo) * sb / 1000)
end)
p3 = sort([ph["ps"] for ph in values(r3["voltage_source"][src_id])])
pg3 = sum(ph["pg"] for g in values(r3["generator"]) for ph in values(g))
println("balanced + cheap: per-phase ", round.(p3; digits = 1),
        "   DER output ", round(pg3; digits = 1), " W")
```

Still balanced to the watt — but now at the *cheap* balanced point: the DERs
carry most of the load (≈ 18.5 kW of their 24 kW capability, versus the
arbitrary dispatch the spread-only objective happened to land on). The
weight is an explicit engineering choice with units; write it down in your
study, because the objective value now mixes \$/h with a penalty term and is
no longer a pure cost rate.

## 5. Rung 3 — two snapshots, one model: an energy budget

`solve_opf` fuses build–solve–extract for a single snapshot, so it cannot
couple time steps. The [staged API](opf.md#staged-api) unbundles it. Here is
the smallest genuinely multi-period study: two hours (normal load, then light
load), one PV plant allowed at most **5 kWh across both** — a battery-like
energy budget that forces the optimiser to *allocate* energy where it is
worth most:

```@example hooks
netA = with_ders(base; cost = 0.10)                 # hour 1: full load
netB = deepcopy(netA)
for (_, d) in netB["load"]
    d["p_nom"] = [0.4 * Float64(d["p_nom"][1])]     # hour 2: light load
end

model = JuMP.Model(Ipopt.Optimizer); JuMP.set_silent(model)
ctxs  = [build_opf_model(n; model = model, add_objective = false) for n in (netA, netB)]

Δt_h  = 1.0
sb    = ctxs[1].bases.s_base
Ppv1  = [gen_p(c, "pv1") for c in ctxs]
@constraint(model, sum(Ppv1[t] * Δt_h for t in 1:2) <= 5_000.0 / sb)   # 5 kWh budget
@objective(model, Min, sum(Δt_h * generation_cost(c) for c in ctxs))
foreach(enforce_kcl!, ctxs)
optimize!(model)

results = [extract_result(c) for c in ctxs]
for (t, r) in enumerate(results)
    p1 = sum(ph["pg"] for ph in values(r["generator"]["pv1"]))
    println("hour ", t, ": pv1 dispatches ", round(p1; digits = 1), " W")
end
used = sum(sum(ph["pg"] for ph in values(r["generator"]["pv1"])) for r in results) * Δt_h
println("energy used: ", round(used; digits = 1), " Wh of the 5000 Wh budget")
@assert used <= 5_000.0 * (1 + 1e-4)
```

The optimiser spends the entire budget in hour 1 — where demand (and thus
displaced import) is high — and idles the plant in the light hour. Note the
contract details that make this correct rather than merely runnable: every
snapshot is built into the **same** `model` with `add_objective = false`; the
objective duration-weights each snapshot's [`generation_cost`](@ref) (a
*rate*, \$/h — see the [units tutorial](tutorial_units.md)); `enforce_kcl!`
runs once per snapshot before the single `optimize!`; and each `ctx` extracts
its own SI result afterwards. Real storage studies replace the one budget
constraint with a state-of-charge recursion — the
[OPF reference](opf.md#staged-api) shows that pattern.

## 6. Hook hygiene

Hard-won rules, in checklist form:

- **Scale every physical literal.** The model is per-unit by default;
  `ctx.bases` (`s_base`, per-bus `v_base`/`i_base`/`z_base`) is the
  dictionary, and it is `nothing` in SI mode — the
  `x / (ctx.bases === nothing ? 1.0 : ctx.bases.s_base)` guard keeps a hook
  correct under both.
- **Prefer rung 0.** If the schema can say it (§2), say it in data — it
  round-trips, validates, and appears in `analyze` reports; hook code does
  none of those.
- **A replaced objective is a replaced question** (§4): re-anchor economics
  explicitly via [`generation_cost`](@ref), and document your weights and
  their units.
- **Reuse the engine's own power expressions** (the ``\Delta v \cdot c``
  bilinears of §3) rather than inventing new power variables — they are
  exactly what the objective and results use, so your constraint means what
  the report says.
- **Read custom values back with `solution_hook!`**, scaling by `ctx.bases`
  (§4). If your hook injects current via `ctx.kcl_r`/`ctx.kcl_i`, also write
  its terminal power to `result["custom_injection"]` so
  [`profile_solution`](@ref)'s power-balance check accounts for it
  ([OPF reference](opf.md)).
- **Verify like you would any solve.** A hooked model is still a nonconvex
  NLP; the [trust-but-verify tutorial](tutorial_trust_but_verify.md)
  discipline applies unchanged — more so, because the formulation is now
  partly yours.

!!! tip "Where to go next"
    The [OPF reference](opf.md) documents the full `ctx` surface, the
    `solution_hook!` contract, and the state-of-charge staged pattern;
    [beyond OPF](opf.md#beyond-opf) sketches estimation-type problems on the
    same seam. The [load-models tutorial](tutorial_load_models.md) explains
    why §2's CVR result hinges on the load model, and the
    [tap tutorial](tutorial_tap.md) covers the free-tap mechanics it used.
    For inverter volt-var/volt-watt behaviour — control, not optimisation —
    see the [VVWO tutorial](tutorial_vvwo.md) before reaching for a hook.
