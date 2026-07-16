# [Choosing and identifying a load model](@id load-models)

*Five load models on the same feeder: where they agree, where they diverge,
what happens at the edge of collapse, and what it takes to identify one from
measurements.*

The [load specification](spec/load.md) gives the equations for constant-power,
constant-current, constant-impedance, ZIP, and exponential loads. What it does
not say is *when each is scientifically defensible* — and that choice is not a
formality. The same 10 kW nameplate produces different feeder voltages,
different losses, different hosting-capacity numbers, and a different distance
to voltage collapse depending on the `model` string you pick. Conservation
voltage reduction (CVR) studies in particular stand or fall on this choice:
if load power does not depend on voltage, CVR saves nothing by construction.
This tutorial puts all five models on the same feeder, stresses them to the
edge of solvability against an analytic collapse limit, and closes with the
identification problem: recovering ZIP parameters from measurements, and why
a narrow voltage window makes that recovery treacherous. Every block runs at
build time — the numbers are real.

!!! note "Prerequisites"
    A Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`; the
    [end-to-end tutorial](tutorial_end_to_end.md) for the pipeline vocabulary.
    The [units tutorial](tutorial_units.md) explains the SI conventions and
    solver scaling used throughout.

## 1. Five names for "10 kW"

A BMOPF load carries `p_nom`/`q_nom` (W, var per sub-load), an anchor voltage
`v_nom` (V), and a `model` string. The five models and how they consume power
as the sub-load voltage magnitude ``|\Delta U|`` moves:

| `model` | ``P(|\Delta U|)`` | Special case of |
|---|---|---|
| `constant_power` (default) | ``P^{\text{nom}}`` | ZIP, ``\alpha = (0,0,1)`` |
| `constant_current` | ``P^{\text{nom}} \cdot \tfrac{\|\Delta U\|}{V^{\text{nom}}}`` | ZIP, ``\alpha = (0,1,0)`` |
| `constant_impedance` | ``P^{\text{nom}} \cdot \tfrac{\|\Delta U\|^2}{(V^{\text{nom}})^2}`` | ZIP, ``\alpha = (1,0,0)`` |
| `zip` | ``P^{\text{nom}}\bigl(\alpha_z \tfrac{\|\Delta U\|^2}{(V^{\text{nom}})^2} + \alpha_i \tfrac{\|\Delta U\|}{V^{\text{nom}}} + \alpha_p\bigr)`` | — |
| `exponential` | ``P^{\text{nom}} \cdot \bigl(\tfrac{\|\Delta U\|}{V^{\text{nom}}}\bigr)^{\gamma_p}`` | ZIP when ``\gamma \in \{0,1,2\}`` |

Reactive power follows the same shapes with ``\beta``/``\gamma_q``
coefficients. Two structural facts to hold onto: **`constant_power` never
reads `v_nom`** (there is nothing voltage-dependent to anchor), and every
other model requires a strictly positive `v_nom` — it is the voltage at which
the load consumes exactly its nameplate. An `exponential` load with integer
exponents is flagged [`I.LOAD.EXP_ZIP_EQUIVALENT`](findings.md) because it *is*
a ZIP special case, solved through the same quadratic machinery
([spec §6](spec/load.md)).

## 2. `v_nom` is the anchor

All five models agree at ``|\Delta U| = V^{\text{nom}}`` and fan out away from
it. Watch that live: take the LV1 14-bus feeder (two single-phase 10 kW
customers), set every load to each model in turn, and sweep the source
magnitude from 90 % to 110 % of nominal. A power flow —
[`solve_pf`](@ref), which enforces **no operational limits** — reports what
one customer actually draws:

```@example loads
using BMOPFTools, JuMP, Ipopt

path = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "LV1_14bus", "Master.dss")
lv1  = from_dss(path)
OPT  = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

MODELS = [
    "constant_power"     => Dict{String,Any}(),
    "constant_current"   => Dict{String,Any}(),
    "constant_impedance" => Dict{String,Any}(),
    "zip"                => Dict{String,Any}(
        "alpha_z" => [0.4], "alpha_i" => [0.3], "alpha_p" => [0.3],
        "beta_z"  => [0.4], "beta_i"  => [0.3], "beta_p"  => [0.3]),
    "exponential"        => Dict{String,Any}("gamma_p" => [1.5], "gamma_q" => [2.0]),
]

function with_model(net, model, extra; λ = 1.0)
    n = deepcopy(net)
    for (_, d) in n["load"]
        d["model"] = model
        merge!(d, extra)
        d["p_nom"] = [Float64(d["p_nom"][1]) * λ]
        d["q_nom"] = [Float64(d["q_nom"][1]) * λ]
    end
    n
end

src_id = first(keys(lv1["voltage_source"]))
vm0    = Float64.(lv1["voltage_source"][src_id]["v_magnitude"])

println("source   ", join(rpad.(first.(MODELS), 20)))
for scale in (0.90, 0.95, 1.00, 1.05, 1.10)
    row = map(MODELS) do (m, extra)
        n = with_model(lv1, m, extra)
        n["voltage_source"][src_id]["v_magnitude"] = vm0 .* scale
        r = solve_pf(n; optimizer = OPT)
        @assert r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        rpad(round(sum(ph["pd"] for ph in values(r["load"]["ld3313_load_a"])); digits = 0), 20)
    end
    println(scale, "     ", join(row))
end
```

Read down the nominal row: the models agree to within about one percent — not
exactly, because the customer's terminal voltage sits slightly *below*
`v_nom` even at nominal source setting (the feeder has voltage drop; the
crossing point is the load's own voltage, not the substation's). Away from
nominal the fan opens: at 90 % source voltage the constant-impedance customer
draws a fifth less than nameplate while the constant-power one draws every
watt regardless. That fifth *is* the CVR argument — and it exists only if the
load model says so.

## 3. Same feeder, five answers

Now hold the feeder at two operating points — nominal, and a depressed 90 %
day — and compare what each model assumption does to the *system* quantities
a study reports:

```@example loads
mv_bus = "b2577"   # 11 kV source bus — excluded from the LV voltage stats

function feeder_row(net)
    r = solve_pf(net; optimizer = OPT)
    @assert r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    vm   = [v["vm"] for (b, ts) in r["bus"] if b != mv_bus for (t, v) in ts if t != "n"]
    load = sum(ph["pd"] for l in values(r["load"]) for ph in values(l))
    grid = sum(ph["ps"] for ph in values(first(values(r["voltage_source"]))))
    (vmin = minimum(vm), load = load, loss = grid - load)
end

for scale in (1.00, 0.90)
    println("source at ", round(Int, scale * 100), " % of nominal:")
    println("  model                 Vmin      P_load     losses")
    for (m, extra) in MODELS
        n = with_model(lv1, m, extra)
        n["voltage_source"][src_id]["v_magnitude"] = vm0 .* scale
        row = feeder_row(n)
        println("  ", rpad(m, 20), lpad(round(row.vmin; digits = 2), 8), " V",
                lpad(round(row.load; digits = 0), 10), " W",
                lpad(round(row.loss; digits = 1), 9), " W")
    end
end
```

At nominal voltage on a healthy, stiff feeder the five assumptions are nearly
indistinguishable — differences of a percent in load and losses. **That is a
finding, not a disappointment**: if your study never leaves the normal
operating band, the load model barely matters and constant power is a
defensible conservative default. The moment voltage departs from nominal —
depressed operation, CVR, hosting-capacity extremes, contingency studies —
the choice starts writing your results: at 90 % the constant-impedance feeder
sheds a fifth of its demand, the constant-power feeder none of it, and every
derived number (losses, import, headroom) moves with them.

## 4. Behaviour near collapse — stressed until something gives

Voltage stability is where the models diverge *qualitatively*, not by
percentages. The LV1 feeder is far too stiff to collapse in any realistic
sweep, so build the textbook weak system where the limit is analytic: a
single-phase 240 V source behind ``Z = 0.25 + j0.10\;\Omega``, feeding one
load with nameplate 10 kW + 3 kvar anchored at ``V^{\text{nom}} = 240`` V.

For a **constant-power** load this two-bus system has a closed-form maximum
loadability: with ``u = V^2``, the power-flow equation reduces to
``u^2 + \bigl(2\lambda(PR + QX) - V_0^2\bigr)u + \lambda^2 (P^2{+}Q^2)|Z|^2 = 0``,
which loses its real solutions — the nose of the PV curve — where the
discriminant hits zero. Solve for that ``\lambda`` and compare it with where
the engine stops converging:

```@example loads
weak(model, extra; λ = 1.0) = Dict{String,Any}(
    "bus" => Dict{String,Any}(
        "src" => Dict{String,Any}("terminal_names" => ["1"]),
        "lb"  => Dict{String,Any}("terminal_names" => ["1"])),
    "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
        "bus" => "src", "terminal_map" => ["1"],
        "v_magnitude" => [240.0], "v_angle" => [0.0])),
    "linecode" => Dict{String,Any}("weak" => Dict{String,Any}(
        "R_series_1_1" => 0.5e-3, "X_series_1_1" => 0.2e-3)),      # Ω/m
    "line" => Dict{String,Any}("l1" => Dict{String,Any}(
        "bus_from" => "src", "bus_to" => "lb", "linecode" => "weak",
        "length" => 500.0, "terminal_map_from" => ["1"], "terminal_map_to" => ["1"])),
    "load" => Dict{String,Any}("ld1" => merge(Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["1"], "configuration" => "WYE",
        "model" => model, "v_nom" => [240.0],
        "p_nom" => [10_000.0 * λ], "q_nom" => [3_000.0 * λ]), extra)))

V0 = 240.0; R = 0.25; X = 0.10; P = 10_000.0; Q = 3_000.0
disc(λ) = (2λ*(P*R + Q*X) - V0^2)^2 - 4λ^2 * (P^2 + Q^2) * (R^2 + X^2)
λ_nose = let lo = 1.0, hi = 20.0
    for _ in 1:60; m = (lo + hi)/2; disc(m) > 0 ? (lo = m) : (hi = m); end
    lo
end
V_nose = sqrt((V0^2 - 2λ_nose*(P*R + Q*X)) / 2)
println("analytic constant-power nose: λ_max = ", round(λ_nose; digits = 3),
        "   V_nose = ", round(V_nose; digits = 1), " V")
```

Now sweep every model up the same loading ramp and record where each stops
solving and at what voltage:

```@example loads
println("model                 last λ    V there    P there    stopped by")
for (m, extra) in MODELS
    lastλ, lastV, lastP = 0.0, NaN, NaN
    for λ in 0.25:0.25:12.0
        r = solve_pf(weak(m, extra; λ = λ); optimizer = OPT)
        r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL") || break
        lastλ = λ
        lastV = r["bus"]["lb"]["1"]["vm"]
        lastP = sum(ph["pd"] for ph in values(r["load"]["ld1"]))
    end
    cause = lastλ == 12.0         ? "nothing — still solving at λ = 12"        :
            m == "constant_power" ? "the physical nose"                        :
            lastV < 0.55 * 240.0  ? "the W-box validity floor (0.5·v_nom)"     :
                                    "nose / floor interplay"
    println(rpad(m, 20), lpad(lastλ, 7), lpad(round(lastV; digits = 1), 10),
            lpad(round(lastP; digits = 0), 11), "    ", cause)
end
```

Three regimes, one table:

- **`constant_power` stops within one grid step of the analytic nose**
  (λ = 5.0 solved, 5.25 infeasible, analytic ``\lambda_{\max}`` ≈ 5.13). The
  demand does not relent as voltage falls, so the required current grows
  without bound and the solution set genuinely ends. This is the model that
  *creates* voltage collapse — which is exactly why it is the conservative
  choice for stability margins.
- **`constant_impedance` never collapses** — a passive admittance in a linear
  network has a solution at every loading; the voltage just keeps sagging and
  the delivered power self-relieves (at λ = 12 it draws about 40 % of its
  scaled nameplate). If your loads are genuinely impedance-like, a collapse margin
  computed with constant-power loads can be pessimistic by *multiples*, not
  percent.
- **The voltage-dependent models sit in between — and where they stop is not
  physics.** The `exponential` load (``\gamma_p = 1.5``, between I and Z)
  rides out the whole ramp; `constant_current` and `zip` stop at ≈ 120 V.
  120 V is ``0.5 \cdot V^{\text{nom}}`` — the
  documented box on the auxiliary squared-voltage variable ``W``
  ([spec §6](spec/load.md), *conditioning only*). A constant-current load's
  voltage declines linearly and would happily continue below half nominal;
  the *model implementation* declares that region out of scope. The lesson
  generalises: every voltage-dependent load model was fitted (or assumed)
  around nominal voltage, and extrapolating it toward collapse is a modelling
  decision — the engine's floor just makes that decision explicit. The
  [`W.LOAD.NL_NO_VMIN`](findings.md) finding warns when a voltage-dependent
  load has no engineering `v_min` on its bus for exactly this reason.

!!! warning "A failed solve is evidence, not a certificate"
    `LOCALLY_INFEASIBLE` from an interior-point method means *this* solver,
    from *this* start, found no solution — the rectangular power-flow
    equations are nonconvex, and a solver can also converge to a spurious
    low-voltage root ([OPF model, warm-start notes](opf.md)). Treat the
    stopping λ as a bracket on the true limit (here we could verify against
    the analytic nose; on a real feeder you cannot). Certified
    distance-to-collapse requires dedicated continuation or holomorphic
    methods — available in the companion package
    [PowerOptLab.jl](https://github.com/frederikgeth/PowerOptLab.jl), not in
    this engine. On stiff networks the solver can also give up for numerical
    reasons well before any physical limit, which is *another* reason not to
    read termination status as physics.

## 5. When is each model scientifically defensible?

The equations are settled; the science is in matching the model to the
device population, the timescale, and the voltage range of your study.

| Load population | Steady-state behaviour | Defensible default |
|---|---|---|
| Power-electronic (SMPS, EV chargers, LED drivers, inverter HVAC) | regulated DC bus holds P as V moves | `constant_power` |
| Resistive heating, incandescent | admittance-like at the timescale of a snapshot | `constant_impedance` |
| Thermostatic resistive (water heaters, ovens) over minutes-to-hours | instantaneous Z, but the *duty cycle* restores energy — average approaches constant P | depends on the study horizon |
| Directly-connected motors | near-constant current over the normal band, stalls at low V | `constant_current` / measured ZIP |
| Feeder-head aggregate (the usual case) | a mixture nobody knows a priori | measured `zip` / `exponential` |

Three caveats that separate a defensible choice from a convenient one:

- **These are steady-state, fundamental-frequency models.** ZIP coefficients
  fitted from quasi-steady measurements say nothing about dynamics (motor
  stalling, fault-induced delayed voltage recovery) — a dynamic study needs a
  dynamic load model, full stop.
- **Aggregation changes the model.** A feeder head aggregates devices *and*
  the network between them; the effective exponent of the aggregate is not
  the average of device exponents, and it drifts with time of day and weather.
  The measurement-based ZIP literature (Hajagos & Danai 1998; Collin et al.
  2014 for modern LV device mixes; the IEEE Task Force reports of 1993/1995
  that standardised the ZIP form) is the right calibration source.
- **The exponent range you fitted is the range you may use** — §4's floor made
  that concrete. Near-nominal fits extrapolated to collapse studies are the
  classic silent error; the conservative fallback there is `constant_power`.

## 6. Identifying a ZIP model from measurements

Suppose the feeder-head aggregate is what you must model, and you have
measurements: pairs of voltage magnitude and drawn power. ZIP identification
is then a *linear* least-squares problem — with ``x = |\Delta U|/V^{\text{nom}}``
and the constraint ``\alpha_z + \alpha_i + \alpha_p = 1`` eliminated,

```math
\frac{P}{P^{\text{nom}}} - 1 =
\alpha_z\,(x^2 - 1) + \alpha_i\,(x - 1),
```

one row per measurement. Generate the "measurement campaign" honestly — a
true ZIP load (``\alpha = (0.4, 0.3, 0.3)``) on the weak feeder, observed
through power-flow solves at different source settings — and fit it back:

```@example loads
using LinearAlgebra

function campaign(scales)
    V = Float64[]; Pm = Float64[]
    for s in scales
        n = weak("zip", Dict{String,Any}(
            "alpha_z" => [0.4], "alpha_i" => [0.3], "alpha_p" => [0.3],
            "beta_z"  => [0.4], "beta_i"  => [0.3], "beta_p"  => [0.3]))
        n["voltage_source"]["source"]["v_magnitude"] = [240.0 * s]
        r = solve_pf(n; optimizer = OPT)
        @assert r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        push!(V, r["bus"]["lb"]["1"]["vm"])
        push!(Pm, sum(ph["pd"] for ph in values(r["load"]["ld1"])))
    end
    V, Pm
end

function fit_zip(V, Pm; v_nom = 240.0, p_nom = 10_000.0)
    x = V ./ v_nom
    A = [x .^ 2 .- 1  x .- 1]
    αz, αi = A \ (Pm ./ p_nom .- 1)
    (αz = αz, αi = αi, αp = 1 - αz - αi, cond = cond(A))
end

wide   = campaign(0.85:0.05:1.10)     # a real voltage-excitation campaign
narrow = campaign(0.98:0.005:1.02)    # a quiet week on a healthy feeder

for (name, (V, Pm)) in ("wide 0.85–1.10" => wide, "narrow 0.98–1.02" => narrow)
    f = fit_zip(V, Pm)
    println(rpad(name, 18), "α = (", round(f.αz; digits = 3), ", ",
            round(f.αi; digits = 3), ", ", round(f.αp; digits = 3),
            ")   cond(A) = ", round(f.cond; sigdigits = 3))
end
```

Both campaigns recover the true parameters exactly — the data is noiseless,
so even an ill-conditioned system solves. Real meters are not noiseless.
Corrupt **a single reading** by half a percent and refit:

```@example loads
for (name, (V, Pm)) in ("wide 0.85–1.10" => wide, "narrow 0.98–1.02" => narrow)
    P2 = copy(Pm); P2[1] *= 1.005          # one meter reads 0.5 % high, once
    f = fit_zip(V, P2)
    println(rpad(name, 18), "α = (", round(f.αz; digits = 3), ", ",
            round(f.αi; digits = 3), ", ", round(f.αp; digits = 3), ")")
end
```

The wide campaign shrugs — the coefficients move but stay recognisable. The
narrow campaign returns **nonsense**: coefficients far outside ``[0,1]``,
including a large negative ``\alpha_i``, from *one* half-percent error. The
mechanism is the condition number printed above: over a ±2 % voltage window,
``x^2 - 1`` and ``x - 1`` are almost the same regressor (both ≈ linear in the
tiny excursion), so the least-squares problem cannot tell Z from I from P —
**identifiability is bought with voltage excitation, not with more data
points from a quiet feeder**. This is why practical campaigns exploit tap
changes, staged switching, or naturally disturbed periods, and why fitted ZIP
coefficients in the wild sometimes carry those out-of-range values: they are
conditioning artefacts, not physics. For estimation at network scale —
recovering load models *and* line parameters from smart-meter data with
proper regularisation — see Vanin & Geth,
[arXiv:2506.04949](https://arxiv.org/abs/2506.04949), and the companion
package [PowerOptLab.jl](https://github.com/frederikgeth/PowerOptLab.jl).

## 7. The checklist

- **Staying near nominal voltage?** The model choice moves results by about a
  percent (§3) — `constant_power` is a fine conservative default.
- **Studying CVR, depressed operation, or hosting extremes?** The choice *is*
  the result (§2–3). Use measured ZIP/exponential coefficients, and cite
  their provenance.
- **Computing stability or collapse margins?** `constant_power` is the
  conservative assumption; voltage-dependent models relieve themselves and
  can be optimistic by multiples (§4). Respect the fitted voltage range —
  the engine's ``0.5 \cdot V^{\text{nom}}`` floor will remind you.
- **Fitting from measurements?** Check the design-matrix conditioning before
  trusting the coefficients (§6); no voltage excitation, no identifiability.
- **Handing a case to others?** [`analyze`](@ref) flags the load-model
  hygiene issues: [`W.LOAD.NL_NO_VMIN`](findings.md),
  [`I.LOAD.EXP_ZIP_EQUIVALENT`](findings.md).

!!! tip "Where to go next"
    The [load specification](spec/load.md) has the full formulation this
    tutorial exercised, including delta and split-phase sub-loads. The
    [impedance-models tutorial](tutorial_impedance_models.md) is this
    tutorial's sibling for the *network* side of the same question — model
    fidelity as a modelling decision. The [VVWO tutorial](tutorial_vvwo.md)
    puts voltage-dependent *generation* (inverter droop) through the same
    kind of reasoning, and the [units tutorial](tutorial_units.md) covers the
    conventions everything here relied on.

---

**References.** IEEE Task Force on Load Representation for Dynamic
Performance, *Load representation for dynamic performance analysis*, IEEE
Trans. Power Systems 8(2), 1993, and *Standard load models for power flow and
dynamic performance simulation*, 10(3), 1995. L. M. Hajagos and B. Danai,
*Laboratory measurements and models of modern loads*, IEEE Trans. Power
Systems 13(2), 1998. A. J. Collin, G. Tsagarakis, A. E. Kiprakis, S. McLaughlin,
*Development of low-voltage load models for the residential load sector*,
IEEE Trans. Power Systems 29(5), 2014. M. Vanin, F. Geth et al.,
arXiv:2506.04949 (parameter estimation from smart-meter data).
