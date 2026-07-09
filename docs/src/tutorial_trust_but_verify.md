# Trust but verify: validating one solved OPF

*What a solver's status guarantees — and what it does not.*

A nonlinear OPF solver ends with a verdict like `LOCALLY_SOLVED`. It is tempting
to read that as "the answer is correct." It is not what the status means. A
`LOCALLY_SOLVED` status certifies that the solver found a point satisfying the
first-order optimality (KKT) conditions of **the problem as posed**, to its
internal tolerances. It says nothing about whether that problem is the one you
meant, whether the optimum is global, or whether the numbers are physically
sensible.

The antidote is cheap and worth building once by hand: take a solved case and
**independently recompute** the physics — Kirchhoff's current law, Ohm's law,
voltage bounds, thermal loading, losses, and the objective — from the result
dictionary alone. This tutorial does exactly that on a feeder small enough to
have a closed-form answer, then shows that the toolkit ships the same checks so
you do not have to repeat them by hand every time.

*Prerequisites: a Julia environment with `BMOPFTools`, `JuMP` and `Ipopt` — see
the [end-to-end tutorial](tutorial_end_to_end.md) first.*

## 1. A feeder with a known answer

One single-phase source (1000 V), a resistive line (R = 0.5 Ω), and one
constant-power load (100 kW) referred to a grounded neutral. For a resistive
line feeding a constant-power load, Kirchhoff + Ohm give a quadratic in the load
voltage,

```math
V^2 - V_s\,V + R\,P = 0,\qquad V = \tfrac{1}{2}\left(V_s + \sqrt{V_s^2 - 4RP}\right)
```

so we know the operating point before we solve. We also rate the line at
`i_max = 250 A` so there is a thermal limit to check against.

```@example trustverify
using BMOPFTools, JuMP, Ipopt
const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

feeder() = parse_bmopf("""
{"bus":{
    "src": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
    "load":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
            "v_min":[900.0],"v_max":[999.0]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
     "v_magnitude":[1000.0],"v_angle":[0.0]}},
 "linecode":{"lc":{"R_series_1_1":0.5,"X_series_1_1":0.0}},
 "line":{"l1":{"bus_from":"src","bus_to":"load",
     "terminal_map_from":["1"],"terminal_map_to":["1"],
     "linecode":"lc","length":1.0,"i_max":[250.0]}},
 "load":{"ld":{"bus":"load","terminal_map":["1","n"],"configuration":"SINGLE_PHASE",
     "p_nom":[100000.0],"q_nom":[0.0]}}}
"""; from_string=true)

r = solve_opf(feeder(); optimizer = OPT)
r["termination_status"]
```

The solver is happy. Now we ignore that and check the physics ourselves.

## 2. Five independent checks

Everything below reads only the result dictionary `r` — no solver internals.
(See the [result dictionary](results.md) for the full key layout.)

**Check 1 — the voltage matches the closed form.** The solved load-bus
magnitude should equal the quadratic root to full precision.

```@example trustverify
Vs, R, P = 1000.0, 0.5, 100000.0
V_exact  = (Vs + sqrt(Vs^2 - 4R*P)) / 2
V_solved = r["bus"]["load"]["1"]["vm"]
(exact = V_exact, solved = V_solved, mismatch = abs(V_exact - V_solved))
```

**Check 2 — Ohm's law across the line.** Reconstruct the current from the
terminal voltage drop, `I = |V_from − V_to| / R`, and compare it to the current
the solver reports on the line (`cm_fr`, the magnitude leaving the from-bus).

```@example trustverify
Vfr = r["bus"]["src"]["1"]["vr"]  + im*r["bus"]["src"]["1"]["vi"]
Vto = r["bus"]["load"]["1"]["vr"] + im*r["bus"]["load"]["1"]["vi"]
I_ohm    = abs(Vfr - Vto) / R
I_solved = r["line"]["l1"]["1"]["cm_fr"]
(ohm = I_ohm, solved = I_solved)
```

**Check 3 — Kirchhoff's current law at the load bus.** The current the line
delivers into the bus (`cm_to`) must equal what the load draws (`crd`, real here
because the load is unity-power-factor). KCL is what the OPF enforces per
terminal; here we confirm it closes.

```@example trustverify
I_line_in = r["line"]["l1"]["1"]["cm_to"]
I_load    = r["load"]["ld"]["1"]["crd"]
(line_into_bus = I_line_in, load_draw = I_load, residual = abs(I_line_in - I_load))
```

**Check 4 — thermal loading.** The conductor current against its rating. The
OPF was free to bind this limit; at 42 % it is comfortably slack, which is why
`i_max` does not appear as an active constraint.

```@example trustverify
imax = feeder()["line"]["l1"]["i_max"][1]
loading_percent = I_solved / imax * 100
```

**Check 5 — losses and the objective.** The line dissipates `I²R`; that must
equal the reported network loss. And the objective is **zero** — not a bug:
there is no *costed* generator, so this is a pure feasibility problem (a power
flow written as an OPF), and its objective has nothing to minimise.

```@example trustverify
(loss_hand = I_solved^2 * R,
 loss_reported = r["losses"]["p_loss"],
 objective = r["objective"])
```

All five agree. We have now confirmed, without trusting the solver's verdict,
that the returned point is the physical operating point.

## 3. The toolkit does this for you

Recomputing by hand is the right way to build intuition once; in practice you
call [`profile_solution`](@ref), which runs the same balance, loss, thermal and
bound checks and returns a report of `Finding`s.

```@example trustverify
report = profile_solution(feeder(), r)
(errors = length(errors(report)), warnings = length(warnings(report)))
```

The underlying [`solution_check`](@ref) exposes the raw quantities — the
network-wide power-balance residual and the loss fraction among them:

```@example trustverify
f = BMOPFTools.Finding[]
summary = solution_check(feeder(), r, f)
(codes = [x.code for x in f],
 power_balance_err = summary["power_balance_err"],
 loss_fraction = summary["loss_fraction"])
```

`W.SOL.POWER_BALANCE` fires when generation minus load, shunts and losses fails
to net to zero; `W.SOL.NEG_LOSS` when a passive branch appears to *source* active
power; `I.SOL.BINDING_SUMMARY` counts the active and violated limits. These are
the machine version of the five hand-checks above — see the
[finding-code reference](findings.md#SOL-—-solution-profiling).

## 4. When the status is green but the answer is not what you want

A clean status does not mean a *good* case. Take the same feeder with a line
four times more resistive and a slacker voltage floor. The solver still returns
`LOCALLY_SOLVED` — but the feeder now burns **38 % of the delivered power** in
the line, which `profile_solution` flags:

```@example trustverify
badfeeder() = parse_bmopf("""
{"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
        "load":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
                "v_min":[600.0],"v_max":[1050.0]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],"v_magnitude":[1000.0],"v_angle":[0.0]}},
 "linecode":{"lc":{"R_series_1_1":2.0,"X_series_1_1":0.0}},
 "line":{"l1":{"bus_from":"src","bus_to":"load","terminal_map_from":["1"],"terminal_map_to":["1"],
     "linecode":"lc","length":1.0,"i_max":[250.0]}},
 "load":{"ld":{"bus":"load","terminal_map":["1","n"],"configuration":"SINGLE_PHASE",
     "p_nom":[100000.0],"q_nom":[0.0]}}}
"""; from_string=true)

rbad = solve_opf(badfeeder(); optimizer = OPT)
fbad = BMOPFTools.Finding[]
sbad = solution_check(badfeeder(), rbad, fbad)
(status = rbad["termination_status"],
 load_voltage = round(rbad["bus"]["load"]["1"]["vm"], digits=1),
 loss_fraction = round(sbad["loss_fraction"], digits=3),
 flags = [x.code for x in fbad])
```

The status is identical to the healthy case; only the independent loss check
tells them apart. This is the general lesson. A `LOCALLY_SOLVED` verdict
guarantees, to tolerance, a KKT point of the model you handed the solver. It
does **not** guarantee that:

- the optimum is **global** — nonconvex OPF can have several local optima, and
  which one you land on depends on the start point (see
  [Trusting the solver](bounds/solver_trust.md) for why the physical branch is
  usually reached here, and the traps that remain);
- the point is **operationally sensible** — a 38 %-loss or a collapsed-voltage
  solution can be a perfectly valid KKT point;
- the **model is the one you meant** — the solver validates the equations you
  wrote, not your modelling assumptions. That gap is the subject of
  [From nameplate data to a defensible model](tutorial_nameplate.md).

!!! tip "The habit"
    After every solve, run `profile_solution` and read the findings — treat a
    green status plus a clean solution report as the bar, not the status alone.
    For the engine-level validation (agreement with OpenDSS, projection
    triangulation, optimality tiers) see [Validating the OPF](validation.md).
