# [Units, bases, scaling, and economics](@id units-and-economics)

*One feeder, two voltage levels: derive every base by hand, watch SI and
per-unit agree to machine precision, then price the dispatch rigorously.*

Every quantitative claim a power-system study makes rests on three unit systems
that are routinely conflated: the units the **data** is stored in, the units the
**solver** computes in, and the units the **objective** is priced in. Getting
any of the three wrong does not crash anything — it silently rescales your
answer. This tutorial works a single MV/LV feeder through all three layers:
we derive the voltage, current, impedance, and power bases by hand and check
them against the engine, demonstrate that an SI solve and a per-unit solve of
the same case return the same physics, and then build the cost story from
\$/kWh coefficients to a priced 24-hour day, reconstructing the solver's
objective value from first principles along the way. Every code block runs
when the docs are built, so the numbers are real.

!!! note "Prerequisites"
    A Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`, and the
    pipeline vocabulary of the [end-to-end tutorial](tutorial_end_to_end.md).
    The feeder is the same LV1 14-bus network used there.

## 1. Two separate choices, often conflated

The BMOPF **data model is SI**: volts, amperes, ohms, siemens, watts, vars —
equipment properties as the manufacturer states them, with no system MVA base
anywhere in the file (see [Units](conventions.md#Units) and the
[terminals primer](terminals_primer.md)). The single exception is the
economics: `cost` fields are energy prices in **\$/kWh**.

Whether the *solver* computes in SI or in per-unit is a second, independent
choice, made at solve time with the `per_unit` keyword of
[`solve_opf`](@ref) (default `true`). Per-unit here is a **normalized working
copy** — the network is scaled, solved, and the results converted back, so the
caller sees SI either way. Representation and numerical scaling are different
concerns; conflating them is how "per-unit data" ends up with undocumented
bases baked into published case files
([Units and scaling](opf.md#Units-and-scaling) develops this argument).

## 2. One feeder, two voltage levels

The LV1 14-bus feeder has exactly the structure the per-unit method was
invented for: an 11 kV medium-voltage source behind a 100 kVA delta-wye
transformer feeding four-wire 400 V mains.

```@example units
using BMOPFTools

path = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "LV1_14bus", "Master.dss")
net  = from_dss(path)

src = first(values(net["voltage_source"]))
println("source bus          : ", src["bus"])
println("source v_magnitude  : ", round.(Float64.(src["v_magnitude"]); digits = 2), " V")

xfmr = first(values(net["transformer"]["delta_wye"]))
println("transformer         : ", xfmr["bus_from"], " -> ", xfmr["bus_to"])
println("v_nom_from / v_nom_to : ", xfmr["v_nom_from"], " V / ", xfmr["v_nom_to"], " V")
println("s_rating            : ", xfmr["s_rating"], " VA")
println("buses / lines / loads : ", length(net["bus"]), " / ",
        length(net["line"]), " / ", length(net["load"]))
```

Read the numbers: the source magnitude is 6350.85 V **phase-to-neutral**
(11 kV/√3 — BMOPF voltages are always the quantity across the element's own
terminals, never an implied line-to-line figure), while the transformer's
`v_nom_from`/`v_nom_to` are the winding reference voltages from the nameplate,
11000 V and 433 V line-to-line. Two voltage levels, one ratio between them —
everything below follows from these three numbers plus one free choice.

## 3. Deriving the bases by hand

Per-unit needs one **system power base** ``S_B`` (a free choice; the solver
default is ``10^6`` VA) and a **voltage base per bus**. The engine derives the
voltage bases the classical way:

1. seed the source bus with the source's phase-to-neutral magnitude,
2. propagate through every transformer by its `v_nom` ratio,
3. lines and switches preserve the base (a cable does not change the voltage
   level),
4. everything else follows per bus:

```math
Z_B = \frac{V_B^2}{S_B}, \qquad
I_B = \frac{S_B}{V_B}, \qquad
Y_B = \frac{S_B}{V_B^2}.
```

That is four lines of arithmetic for this feeder — do it by hand:

```@example units
s_base = 1e6                                       # VA — the solver default

v_base_mv = maximum(abs, Float64.(src["v_magnitude"]))          # 11 kV / √3
v_base_lv = v_base_mv * xfmr["v_nom_to"] / xfmr["v_nom_from"]   # through the ratio

println("            MV (", src["bus"], ")      LV feeder")
println("V_base  : ", lpad(round(v_base_mv; digits = 3), 10), " V ",
        lpad(round(v_base_lv; digits = 3), 10), " V")
println("Z_base  : ", lpad(round(v_base_mv^2 / s_base; digits = 3), 10), " Ω ",
        lpad(round(v_base_lv^2 / s_base; digits = 4), 10), " Ω")
println("I_base  : ", lpad(round(s_base / v_base_mv; digits = 2), 10), " A ",
        lpad(round(s_base / v_base_lv; digits = 1), 10), " A")
println("Y_base  : ", lpad(round(s_base / v_base_mv^2; digits = 5), 10), " S ",
        lpad(round(s_base / v_base_lv^2; digits = 2), 10), " S")
```

Two things deserve attention. First, the LV base lands on 249.99 V — the
phase-to-neutral value of a 433 V system — even though both `v_nom`s are
line-to-line: for a three-phase transformer the line-to-line ratio *is* the
phase-to-neutral ratio, so propagating a phase-to-neutral seed through it stays
phase-to-neutral. Second, the impedance bases differ by the ratio squared —
40.33 Ω against 0.0625 Ω, a factor of 645 — which is precisely the referral
factor that makes "4.5 % impedance" mean the same thing on either side of the
transformer.

Now check the arithmetic against the engine's own bookkeeping. The base
computation lives in the OPF extension (it is internal — shown here for
verification, not as API):

```@example units
using JuMP, Ipopt              # loading these activates the OPF extension
ext   = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
bases = ext._compute_bases(net, s_base)

@assert isapprox(bases.v_base[src["bus"]], v_base_mv; rtol = 1e-12)
@assert isapprox(bases.v_base[xfmr["bus_to"]], v_base_lv; rtol = 1e-12)
@assert isapprox(bases.z_base[xfmr["bus_to"]], v_base_lv^2 / s_base; rtol = 1e-12)
println("hand-derived bases match the engine on all ",
        length(bases.v_base), " buses: ",
        all(isapprox(bases.v_base[b],
                     b == src["bus"] ? v_base_mv : v_base_lv; rtol = 1e-12)
            for b in keys(bases.v_base)))
```

Every LV bus inherits the transformer's low-side base through the line
adjacency — the base changes at transformers and *only* at transformers. This
is the same NamedTuple a [`solve_opf`](@ref) `model_hook!` receives as
`ctx.bases` when it needs to express a physical-unit constraint inside a
per-unit model.

## 4. SI ≡ per-unit, demonstrated

Per-unit is a *reversible change of variables* — it must not change the
physics. That is a testable claim: solve the same OPF both ways and compare.
First give the case operating bounds and an economic setting (a 15 kW
three-phase DER competing with the grid — §6 prices it):

```@example units
net_ready, _ = augment_case(net; recipe = AugmentationRecipe())

src_id = first(keys(net_ready["voltage_source"]))
net_ready["voltage_source"][src_id]["cost"] = [0.25, 0.25, 0.25]   # \$ / kWh import

net_ready["generator"] = Dict{String,Any}("der1" => Dict{String,Any}(
    "bus" => "b3230", "terminal_map" => ["a", "b", "c", "n"],
    "configuration" => "WYE",
    "p_min" => zeros(3),          "p_max" => fill(5000.0, 3),   # W, per phase
    "q_min" => fill(-3000.0, 3),  "q_max" => fill(3000.0, 3),   # var, per phase
    "cost"  => [0.10, 0.10, 0.10]))                             # \$ / kWh

optimizer = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

res_pu = solve_opf(net_ready; optimizer = optimizer)                    # per_unit = true is the default
res_si = solve_opf(net_ready; optimizer = optimizer, per_unit = false)

dv = maximum(abs(res_pu["bus"][b][t]["vm"] - res_si["bus"][b][t]["vm"])
             for b in keys(res_pu["bus"]) for t in keys(res_pu["bus"][b]))

println("status      : ", res_pu["termination_status"], " / ", res_si["termination_status"])
println("objective   : ", res_pu["objective"], "  (per-unit solve)")
println("              ", res_si["objective"], "  (SI solve)")
println("max |ΔV|    : ", round(dv; sigdigits = 3), " V  across all buses and terminals")
```

Both solves return SI results (they always do — `per_unit` never leaks into
the output, see the [result dictionary](results.md)), and they agree to
sub-microvolt voltages and a relative objective gap around ``10^{-6}`` — the
convergence tolerance of the interior-point method, not a modelling
difference. The two runs solve *different nonlinear programs* (every variable
and coefficient rescaled) and land on the same physical solution: that is the
SI ≡ per-unit equality, demonstrated rather than asserted.

## 5. Why solvers care anyway

If the answer is identical, why does the default bother normalizing?
Because the *path* to the answer is not scale-invariant: interior-point
initialization, barrier updates, and stopping tests all react to the numeric
magnitude of variables and constraints. Compare what the two solves reported:

```@example units
for (name, r) in (("per-unit", res_pu), ("SI", res_si))
    p = r["opt_profile"]
    println(rpad(name, 9), ": ", lpad(p["barrier_iterations"], 3), " barrier iterations",
            ", median active shadow price ", round(p["median_shadow_price"]; sigdigits = 3))
end
```

On this instance the per-unit solve needs several times fewer barrier
iterations — and the shadow prices differ by orders of magnitude *because the
constraint units differ*, a reminder that duals are only interpretable
together with their scaling. But be careful what you conclude:

!!! warning "An observation, not a theorem"
    Whether per-unit scaling helps convergence is **instance- and
    formulation-dependent** — a documented open question for this engine
    ([Units and scaling](opf.md#Units-and-scaling), refs 18–20 in the
    [methodology notes](methodology.md#refs)). The iteration counts above are
    one data point on one feeder, printed live so you can watch them change
    across solver versions. The two modes exist so the question can be
    *benchmarked*; per-unit became the default because DC-network cases are
    numerically fragile in SI, not because SI is wrong.

It is also worth being precise about what per-unit does *not* fix. The SI line
resistances on this feeder span a factor of ~264 (short service drops against
long mains); dividing all of them by the same LV ``Z_B`` leaves that spread
untouched. Per-unit compresses scale differences **across voltage levels and
across quantity types** (volts vs ohms vs amperes); spread *within* one
quantity at one level — flagged as
[`W.DOM.LINE_IMPEDANCE_SPREAD`](findings.md) — survives normalization and is a
property of the network itself.

## 6. Economics: pricing the dispatch

Now the third unit system. Every dispatchable element — generators, IBRs,
*and the voltage source* — takes a `cost` field: a **per-phase vector of
energy prices in \$/kWh** (a scalar is rejected — per-phase pricing is the
general case, and silent broadcasting invites silent errors). For a snapshot,
the objective is the total **cost rate**

```math
\min \; \sum_{e} \sum_{k} \frac{c_{e,k}}{1000}\, P_{e,k}
\qquad \left[\tfrac{\$}{\text{kWh}} \cdot \tfrac{\text{W}}{1000} = \tfrac{\$}{\text{h}}\right]
```

with ``P_{e,k}`` the active power **injected into the network** by element
``e``'s phase term ``k``, in watts ([objective specification](spec/objective.md)).
The sign convention is uniform: the source is *not* a special case. Its
injection is grid import, so a positive source cost is the import tariff — and
a negative injection (reverse flow) is *credited* at the same price. Above we
priced the grid at 0.25 \$/kWh against a 0.10 \$/kWh DER, so the optimum is no
surprise: the DER runs at its 15 kW capacity and the grid supplies the
remainder of the 20 kW load plus losses.

The rigorous test is that we can reconstruct the solver's objective from
nothing but the result dictionary and the input prices:

```@example units
p_src = [ph["ps"] for ph in values(res_pu["voltage_source"][src_id])]   # W, per phase
p_der = [ph["pg"] for ph in values(res_pu["generator"]["der1"])]

println("grid import per phase : ", round.(p_src; digits = 1), " W   Σ = ",
        round(sum(p_src); digits = 1), " W")
println("DER dispatch per phase: ", round.(p_der; digits = 1), " W   Σ = ",
        round(sum(p_der); digits = 1), " W")

obj_hand = sum(0.25 .* p_src ./ 1000) + sum(0.10 .* p_der ./ 1000)      # \$/h

println("objective, by hand    : ", obj_hand, "  \$/h")
println("objective, solver     : ", res_pu["objective"], "  \$/h")
@assert isapprox(obj_hand, res_pu["objective"]; rtol = 1e-10)
```

The two numbers agree to machine precision — the objective is exactly the
stated formula, nothing more. Note the per-phase grid powers in the output:
they are far from balanced, and one phase can even back-feed while the total
imports. Each phase term is priced independently by its own coefficient,
which is why `cost` is a vector — and why a deliberately unbalanced tariff
(useful in unbalance-mitigation studies) is expressible at all. Two findings
police this field:
[`W.DOM.GEN_COST_HIGH`](findings.md) flags prices above 10 \$/kWh (a likely
\$/MWh paste), and [`W.DOM.COST_PHASE_NONUNIFORM`](findings.md) flags per-phase
vectors that differ when you probably meant them equal.

!!! note "Cheap DER + free export = an arbitrage machine"
    With export credited at the import price, a DER priced below the grid and
    sized above the load makes *exporting* optimal — the objective happily
    goes negative. That is correct market behaviour, not a bug; if it is not
    the study you meant to run, the modelling lever is the DER's capacity
    (`p_max`), its price, or an export limit at the source.

## 7. From rate to energy: the timestep

The snapshot objective is a **rate** (\$/h). Money is the integral of that
rate, and the integration step is *yours*: BMOPFTools has no built-in timestep
duration. The [time-series mechanism](tutorial_timeseries.md) gives you the
snapshots; converting to currency is one multiplication per step,
``\text{cost} = \sum_t \; \text{rate}_t \cdot \Delta t_h`` with ``\Delta t_h``
in hours ([spec](spec/timeseries.md)). On the 24-hour LV1 fixture (hourly
steps, so ``\Delta t_h = 1``), with the augmentation default of 1 \$/kWh at
the source:

```@example units
ts_path  = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "lv1_14bus_timeseries.json")
ts_ready, _ = augment_case(parse_bmopf(ts_path); recipe = AugmentationRecipe())

rates = [solve_opf(ts_ready; optimizer = optimizer, t_index = t)["objective"]
         for t in 1:24]                                           # \$/h, one per hour
Δt_h  = 1.0                                                       # hourly profile steps

println("hourly cost rates (\$/h):")
println("  overnight : ", join(round.(rates[1:6]; digits = 2), "  "))
println("  daytime   : ", join(round.(rates[7:18]; digits = 2), "  "))
println("  evening   : ", join(round.(rates[19:24]; digits = 2), "  "))
println("daily energy cost = Σ rate·Δt = ", round(sum(rates .* Δt_h); digits = 2), " \$")
```

The rates tell the feeder's story in currency: modest import cost overnight,
**negative** rates through the middle of the day — the rooftop PV pushes the
feeder into export, credited at the import price — and the peak cost in the
evening. The daily figure is their sum *only because* the steps are one hour;
a 15-minute profile would need `Δt_h = 0.25`, and mixed step lengths need the
general dot product. Forgetting `Δt` is the classic \$-vs-\$/h unit bug — it
rescales every result by the step count and survives peer review depressingly
often.

!!! note "True multi-period studies"
    Summing independently-solved snapshots prices a day, but it cannot
    *couple* the hours (storage, ramps). For a genuinely multi-period model,
    the staged API exposes the pieces: [`build_opf_model`](@ref) with
    `add_objective = false`, [`generation_cost`](@ref) for each period's rate
    expression — multiply each by its duration in hours before summing into
    one objective — then [`enforce_kcl!`](@ref) and [`extract_result`](@ref).

## 8. The checklist

Unit errors are silent, so check them off explicitly:

- **Data is SI** — volts, amperes, ohms, watts; `cost` in \$/kWh is the one
  exception ([conventions](conventions.md#Units)). Nothing in a BMOPF file is
  per-unit.
- **`per_unit` is a solver setting**, default `true`; results come back in SI
  either way. Reach for `per_unit = false` only to benchmark or reproduce a
  raw-SI solve.
- **Voltage bases change at transformers and only at transformers** — seeded
  phase-to-neutral at the source, propagated by `v_nom` ratios; ``Z_B, I_B,
  Y_B`` follow per bus. In a `model_hook!`, scale physical literals with
  `ctx.bases`.
- **`s_rating` on a transformer is also its impedance base** — the nameplate
  powers both the loading cap and the per-unit referral
  ([transformer models](transformer_models.md)).
- **The objective is a rate** (\$/h): per-phase \$/kWh coefficients times
  injected watts over 1000. Positive cost minimises injection; export is
  credited at the same price. Multiply by the step duration in hours before
  calling anything "cost".
- **Duals carry units too** — a shadow price from an SI solve and one from a
  per-unit solve differ by the constraint's base factor (§5).

!!! tip "Where to go next"
    [Units and scaling](opf.md#Units-and-scaling) states the engine's
    per-unit contract and the open benchmarking question; the
    [objective specification](spec/objective.md) has the full formulation and
    sign-convention test; the [time-series tutorial](tutorial_timeseries.md)
    builds the day this tutorial priced; and
    [Trust but verify](tutorial_trust_but_verify.md) extends §6's
    reconstruct-it-yourself discipline to every other quantity in the result.
