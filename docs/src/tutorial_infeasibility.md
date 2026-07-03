# [Diagnosing infeasibility](@id infeasibility-tutorial)

*From `LOCALLY_INFEASIBLE` to a located, quantified, and fixed data problem.*

You tighten a voltage bound, re-run [`solve_opf`](@ref), and Ipopt comes back
`LOCALLY_INFEASIBLE`. Now what? The status line names no bus, no constraint, no
magnitude — and, worse, it is not even a proof: Ipopt is a *local* solver, so its
infeasibility verdict is **a claim, not a certificate**
([Trusting the solver](bounds/solver_trust.md), [1](@ref refs-infeas)). This is
the runnable companion to the [Bounds, Branches, and Feasibility](bounds/index.md)
chapter: the three-tool diagnosis workflow on one small feeder, end to end.

The punchline up front: instead of interrogating a failed solve, you run a
**relaxed problem that always solves** — [`solve_feasibility_opf`](@ref) — and read
*where* and *by how much* the network misses feasibility off its elastic slack
variables. [`infeasibility_preflight`](@ref) catches the statically detectable
mistakes before any solver runs, and [`diagnose_infeasibility`](@ref) turns the raw
slack pattern into a ranked, classified diagnosis. Every code block below executes
when the docs are built, so the numbers are real.

*Prerequisites: a Julia environment with `BMOPFTools`, `JuMP` and `Ipopt` installed,
and familiarity with the JSON input format — see the
[end-to-end tutorial](tutorial_end_to_end.md) first.*

## 1. A feeder that solves

A 230 V single-phase source feeds two load buses in series through resistive LV
cable (0.4 Ω per segment, ``R/X = 5``), 2 kW at each bus. The voltage window is a
builder argument so we can tighten it in one place; 207 V is the AS IEC 60038:2022
supply floor of ``0.90 \times 230`` V.

```@example infeas
using BMOPFTools, JuMP, Ipopt
const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

feeder(v_min) = parse_bmopf("""
{"bus":{
    "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
    "b1": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
           "v_min":[$(v_min)],"v_max":[253.0]},
    "b2": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],
           "v_min":[$(v_min)],"v_max":[253.0]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
     "v_magnitude":[230.0],"v_angle":[0.0]}},
 "linecode":{"lc":{"R_series_1_1":0.4,"X_series_1_1":0.08}},
 "line":{"l1":{"bus_from":"src","bus_to":"b1",
     "terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc","length":1.0},
         "l2":{"bus_from":"b1","bus_to":"b2",
     "terminal_map_from":["1"],"terminal_map_to":["1"],"linecode":"lc","length":1.0}},
 "load":{"ld1":{"bus":"b1","terminal_map":["1","n"],"configuration":"SINGLE_PHASE",
     "p_nom":[2000.0],"q_nom":[0.0]},
         "ld2":{"bus":"b2","terminal_map":["1","n"],"configuration":"SINGLE_PHASE",
     "p_nom":[2000.0],"q_nom":[0.0]}}}
"""; from_string=true)

r_ok = solve_opf(feeder(207.0); optimizer = OPT)
println("status : ", r_ok["termination_status"])
for b in ("b1", "b2")
    println("V(", b, ")  : ", round(r_ok["bus"][b]["1"]["vm"], digits=1), " V")
end
```

The feeder is healthy: the end of the line sags to about 219 V, comfortably above
the 207 V floor. Note those solved voltages — they are the *achievable* profile,
and they will explain everything that follows.

## 2. Tighten a bound until the physics gives out

Now suppose a stricter planning rule arrives: no bus may drop below 222 V. Bus `b2`
can only reach ≈ 219 V under this load — there is no dispatch that satisfies the
new bound, so the instance is *genuinely* infeasible, not merely hard to solve.

```@example infeas
tight = feeder(222.0)
r_bad = solve_opf(tight; optimizer = OPT)
println("status : ", r_bad["termination_status"])
```

`LOCALLY_INFEASIBLE` means Ipopt's restoration phase minimised the constraint
violation and could not drive it to zero ([1](@ref refs-infeas)). On a nonconvex
problem that is strong evidence, not proof — a different starting point *could* in
principle have succeeded ([2](@ref refs-infeas)), which is exactly why
[Trusting the solver](bounds/solver_trust.md) asks you to corroborate the verdict
before acting on it. The two tools below are that corroboration, and they answer
the question the status line cannot: *where, and by how much?*

## 3. Pre-flight: catch what static analysis can catch

Before running any solver, [`infeasibility_preflight`](@ref) inspects the data for
infeasibility that is visible *without* power flow: crossed bound pairs
(`v_min > v_max`, `p_min > p_max`), source setpoints outside their own bus's
voltage window, generation adequacy, and topology. It appends structured
[`Finding`](@ref)s to a vector you supply. Here it flags a classic editing slip —
a bus whose `v_min`/`v_max` got swapped:

```@example infeas
swapped = feeder(207.0)
swapped["bus"]["b2"]["v_min"], swapped["bus"]["b2"]["v_max"] = [253.0], [207.0]

findings = Finding[]
pf = infeasibility_preflight(swapped, findings)
println("conflicts found : ", pf["constraint_conflicts"]["n_conflicts"])
for f in errors(findings)
    println(f.code, " @ ", f.component_type, " '", f.component_id, "'")
end
```

An `E.PRE.VBOUND_CONFLICT` on `bus 'b2'` — a guaranteed infeasibility caught in
microseconds, with the offending component named. Run the same check on our
*physically* infeasible case, though, and it finds nothing wrong:

```@example infeas
f2 = Finding[]
pf2 = infeasibility_preflight(tight, f2)
println("conflicts found : ", pf2["constraint_conflicts"]["n_conflicts"])
println("errors raised   : ", length(errors(f2)))
println("adequacy ratio  : ", pf2["generation_adequacy"]["adequacy_ratio"])
```

Zero conflicts, zero errors: `222.0 < 253.0` is a perfectly consistent bound pair
on paper. (The adequacy ratio of 0.0 just says there is no local generation — this
feeder imports everything through the source, which is normal.) Whether 222 V is
*reachable* through 0.8 Ω of cable under 4 kW of load is a power-flow question that
static analysis cannot answer. For that we need the solver back — but on a problem
that cannot fail.

## 4. The elastic problem: `solve_feasibility_opf`

[`solve_feasibility_opf`](@ref) builds the *same* model as `solve_opf` — identical
hard voltage bounds, angle limits, and device current limits — with one surgical
relaxation: an elastic slack current ``(c^s_r, c^s_i)`` is injected into KCL at
every non-source bus terminal, and the objective minimises ``\sum_k |c^s_k|^2``
instead of generation cost. KCL can now always balance, so the problem solves even
when the original could not; any terminal that *needed* its slack to balance is a
terminal where the physics and the bounds disagree. It is the four-wire analogue
of an irreducible-infeasible-subsystem search, run as a single least-squares NLP
(see [Diagnostics & validation](bounds/diagnostics.md)).

```@example infeas
fres = solve_feasibility_opf(tight; optimizer = OPT)
println("status               : ", fres["termination_status"])
println("total slack          : ",
        round(fres["total_slack_magnitude_A"], digits=2), " A")
for (bid, terms) in sort(collect(fres["slack_injections"]), by=first)
    for (t, s) in sort(collect(terms), by=first)
        s["cs_mag"] > 0.01 &&
            println("slack @ ", bid, " terminal ", t, " : ",
                    round(s["cs_mag"], digits=2), " A")
    end
end
```

`LOCALLY_SOLVED` — the relaxed problem converges, and the slack pattern is the
diagnosis. The residual concentrates at `b2` (≈ 2.7 A), with a smaller share at
`b1` (≈ 1.4 A): the least-squares objective spreads the residual over electrically
coupled nodes, so read the *ranking*, not just the presence, of slack. The model is
telling you: to hold every voltage inside its window, roughly three amps of current
would have to appear out of nowhere at the end of this feeder.

Why current and not voltage? Because the voltages are *held* at their hard bounds
— the slack absorbs the resulting KCL imbalance:

```@example infeas
for b in ("b1", "b2")
    println("V(", b, ") : ", round(fres["bus"][b]["1"]["vm"], digits=2),
            " V   (v_min = 222.0 V)")
end
```

`b2` sits exactly on its 222 V floor — a binding bound, with the physical
impossibility showing up as the fictitious current needed to keep it there.

## 5. Reading the result: `diagnose_infeasibility`

[`diagnose_infeasibility`](@ref) post-processes the feasibility-OPF result into a
ranked and *classified* report: per-bus aggregate slack, each bus's failure mode
(`voltage_bound` if the solved voltage sits at a bound, `power_balance` otherwise),
and the local load/generation context.

```@example infeas
d = diagnose_infeasibility(fres, tight)
println("is_feasible            : ", d["is_feasible"])
println("total infeasibility    : ", d["total_infeasibility_A"], " A")
println("failure modes          : ", d["failure_mode_summary"])
top = d["top_buses"][1]
println("worst bus              : ", top["bus"],
        "  (", top["slack_A"], " A, ",
        round(100 * top["fraction_of_total"], digits=1), " % of total)")
println("failure mode           : ", top["failure_mode"])
println("violations             : ", top["voltage_violations"])
println("load served there      : ", top["total_load_kW"], " kW from ",
        top["n_loads"], " load(s)")
```

The report names `b2` as the dominant offender (≈ 89 % of the total residual),
classifies it as `voltage_bound`, and points at the specific violation: terminal 1
pinned at its 222 V lower limit. The upstream bus `b1` is classified
`power_balance` — its voltage is comfortable; its smaller slack is collateral from
propagating `b2`'s deficit. So the fix lives at `b2`'s voltage bound, not at `b1`.

## 6. From amps to volts: fix the right bound by the right amount

The slack is a current, but the offending bound is a voltage. A first-order bridge
is Ohm's law through the upstream path: the missing current, pushed through the
0.8 Ω of series resistance between the source and `b2`, corresponds to roughly

```@example infeas
slack_A    = top["slack_A"]
R_upstream = 0.4 + 0.4          # Ω, src → b1 → b2 series resistance
println("estimated voltage relief needed ≈ ",
        round(slack_A * R_upstream, digits=1), " V")
```

about 2 V of relief — a scale estimate (it ignores the `b1` share of the residual
and the load current's own voltage dependence, so treat it as a lower bound). The
true gap we engineered is 222 − 219.1 ≈ 2.9 V. Either number says the same thing:
the 222 V floor overshoots what this feeder can deliver by *a couple of volts* —
this is a marginal bound to renegotiate, not a feeder to rebuild. Restoring the
207 V statutory floor gives comfortable margin:

```@example infeas
fixed = feeder(207.0)
r_fix = solve_opf(fixed; optimizer = OPT)
println("status : ", r_fix["termination_status"])
println("V(b2)  : ", round(r_fix["bus"]["b2"]["1"]["vm"], digits=1),
        " V  ≥ 207 V floor")

d_fix = diagnose_infeasibility(
    solve_feasibility_opf(fixed; optimizer = OPT), fixed)
println("is_feasible : ", d_fix["is_feasible"],
        "   residual : ", d_fix["total_infeasibility_A"], " A")
```

`LOCALLY_SOLVED`, and the feasibility OPF's residual collapses to numerical zero —
a near-zero `total_slack_magnitude_A` is precisely the certificate that a point
satisfying every KCL, KVL and device equation exists
([Diagnostics & validation](bounds/diagnostics.md)). The loop is closed: claim,
localisation, quantified fix, confirmation.

## When to trust `INFEASIBLE`

- **The verdict is calibrated trust, not proof.** With sane bounds, a
  loss/cost-minimising objective, and the numerical traps excluded,
  `LOCALLY_INFEASIBLE` almost always *is* physical infeasibility — work through the
  [trust checklist](bounds/solver_trust.md) before concluding, and remember that
  restoration is start-dependent ([2](@ref refs-infeas)).
- **Slacks are fictitious nodal currents.** A non-zero `cs_mag` at a terminal is
  the current a hypothetical device would have to inject *at that node* to make the
  bounds hold — its location says *where*, its magnitude (times the upstream
  impedance) says roughly *how far* from feasible you are.
- **Preflight first, always.** It is free, and crossed bounds or out-of-window
  source setpoints produce infeasibilities no amount of solver forensics explains
  faster. What it cannot see is impedance: reachability questions need §4.
- **A converged feasibility OPF with near-zero slack is a feasibility
  certificate**; a converged one with structured slack is a diagnosis. The rare
  case where even the *elastic* problem fails to converge (flagged by
  `solver_infeasible` in the diagnosis) means a hard bound conflicts with a fixed
  source voltage — data to inspect directly, not physics.
- The failure modes behind stubborn cases — collapse proximity, branch
  multiplicity, degenerate duals — are catalogued in the
  [Known traps](bounds/known_traps.md) gallery.

## [References](@id refs-infeas)

1. A. Wächter, L. T. Biegler, *On the implementation of an interior-point filter
   line-search algorithm for large-scale nonlinear programming*, Mathematical
   Programming **106**:25–57, 2006.
2. O. Hinder, Y. Ye, *A one-phase interior point method for nonconvex
   optimization*, arXiv:1801.03072, 2018.
