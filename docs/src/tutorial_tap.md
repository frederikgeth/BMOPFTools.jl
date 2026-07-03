# [Transformer tap optimisation](@id tap-optimisation)

*Choosing on-load tap-changer (OLTC) and regulator settings as a continuous decision
variable — and why it is an optimisation, not a guess.*

Most distribution transformers and every step-voltage regulator carry a **tap**: a
small, switchable change to the turns ratio that trades primary against secondary
voltage. Picking the tap is a control decision — too low and the feeder end
under-voltages, too high and it over-voltages or wastes capacity. Classically a
regulator picks its tap from a local voltage measurement; but the *best* tap for the
whole feeder (lowest losses, all buses in band) depends on the network and the load,
so it is naturally a decision the OPF should make.

This page makes the tap a **free continuous variable** and lets
[`solve_opf`](@ref) choose it. Every code block runs when the docs are built, so the
numbers are real.

**Prerequisites:** a Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`
(`Pkg.add(["JuMP", "Ipopt"])`), and basic familiarity with the JSON input format from
the [end-to-end tutorial](tutorial_end_to_end.md). The result-dictionary layout used
below is documented in [OPF result dictionary](results.md). The
[VVWO tutorial](tutorial_vvwo.md) covers the complementary voltage-control lever —
IBR droop — on a real LV feeder.

## The model

A transformer tap is exposed with the same *implicit* free-variable pattern as
generators and IBRs: **bounds make it optimisable**.

- Ordinary transformers (`single_phase`, `center_tap`, `delta_wye`, `wye_delta`)
  take a dimensionless multiplier `tap` on the nominal from-side ratio
  ``N_0 = v_{\text{nom,from}}/v_{\text{nom,to}}`` (the `v_nom_from`/`v_nom_to`
  fields), with `tap_min`/`tap_max`. For
  `center_tap` this taps the HV winding, so both LV legs scale together.
- Regulator subtypes (`single_phase_autotransformer`, `open_delta_regulator`) make
  their native `tap_ratio` free with `tap_ratio_min`/`tap_ratio_max`.

`n_winding` is the one subtype **without** tap support: its ratio is always held at
the nominal turns ratio. Supplying a tap field on an `n_winding` raises a warning at
OPF-build time (rather than silently fixing the ratio).

If `tap_min < tap_max` the tap becomes a decision variable; otherwise it is fixed
(so existing data is unchanged). Internally the solved tap enters the winding
constraints as the effective ratio ``N = N_0\cdot t``. The from-referred leakage of
an OLTC scales with the winding turns, i.e. with ``t^2``; written on the to side the
leakage is *constant* and — using the ideal-core coupling ``N\,I_{\text{series}} =
-I_{\text{to}}`` — the voltage drop stays **quadratic** in the tap variable, so no
solver change is needed (the OPF is already an Ipopt NLP). At ``t = 1`` the model is
identical to the fixed-tap transformer, so the tap variable adds no error.

```@example tap
using BMOPFTools, JuMP, Ipopt
const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
solved(r) = r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL","ALMOST_LOCALLY_SOLVED")
nothing # hide
```

## 1. A single-phase feeder that needs its tap

An 11 kV / 240 V, 50 kVA single-phase transformer feeds a heavy 40 kW + 13 kVAr load.
The source has a unit cost, so minimising it minimises imported power — i.e. losses.

```@example tap
zbf = 11_000.0^2 / 50_000.0
zbt =    240.0^2 / 50_000.0
feeder(tapfields, vbounds) = parse_bmopf("""
{"bus":{
   "hv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
   "lv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]$vbounds}},
 "voltage_source":{"src":{"bus":"hv","terminal_map":["1"],
     "v_magnitude":[11000.0],"v_angle":[0.0],"cost":[1.0]}},
 "load":{"ld":{"bus":"lv","terminal_map":["1","n"],
     "configuration":"SINGLE_PHASE","p_nom":[40000.0],"q_nom":[13000.0]}},
 "transformer":{"single_phase":{"t1":{
     "bus_from":"hv","bus_to":"lv",
     "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
     "v_nom_from":11000.0,"v_nom_to":240.0,"s_rating":50000.0,
     "r_series_from":$(0.01*zbf),"x_series_from":$(0.04*zbf),
     "r_series_to":$(0.01*zbt),"x_series_to":0.0$tapfields}}}}
"""; from_string=true)

vlv(r) = round(r["bus"]["lv"]["1"]["vm"], digits=2)
ploss(r) = round(r["losses"]["p_loss"], digits=1)
nothing # hide
```

At the **fixed** nominal tap the secondary sags well below a 236 V floor:

```@example tap
r0 = solve_opf(feeder("", ""); optimizer = OPT)
println("fixed tap = 1.0 :  |V_lv| = ", vlv(r0), " V,  losses = ", ploss(r0), " W")
```

A 236 V lower limit is therefore **infeasible at the nominal tap** — there is no
dispatch lever, the load and source are fixed:

```@example tap
r_lim = solve_opf(feeder("", ""","v_min":[236.0],"v_max":[246.0]"""); optimizer = OPT)
println("fixed tap, [236,246] V band  → ", r_lim["termination_status"])
@assert !solved(r_lim)
nothing # hide
```

Now free the tap over ``[0.9, 1.1]`` and re-solve. The optimiser lowers the tap (a
lower from-side ratio raises the secondary), pulling the feeder back into band and
**cutting losses** at the same time:

```@example tap
free = ""","tap":1.0,"tap_min":0.9,"tap_max":1.1"""
rf = solve_opf(feeder(free, ""","v_min":[236.0],"v_max":[246.0]"""); optimizer = OPT)
t★ = rf["transformer"]["t1"]["tap"]
println("free tap  →  status = ", rf["termination_status"])
println("  optimal tap   = ", round(t★, digits=4), "   (binding bound: ",
        rf["transformer"]["t1"]["tap_binding"], ")")
println("  |V_lv|        = ", vlv(rf), " V")
println("  losses        = ", ploss(rf), " W   (was ", ploss(r0), " W at tap 1.0)")
```

The single number `tap` is the whole story: an infeasible feeder becomes feasible,
losses fall, and the result reports whether the tap **bound** is binding — a binding
tap means the regulation range is exhausted and another lever (a second regulator,
DER, reconductoring) is needed.

## 2. The tap is load-dependent: a tap schedule

Because the right tap depends on loading, sweeping the load traces the tap an OLTC
should follow — an *optimised tap schedule*:

```@example tap
for mult in (0.4, 0.7, 1.0, 1.3)
    net = feeder(free, ""","v_min":[232.0],"v_max":[250.0]""")
    net["load"]["ld"]["p_nom"] = [40000.0 * mult]
    net["load"]["ld"]["q_nom"] = [13000.0 * mult]
    r = solve_opf(net; optimizer = OPT)
    println("load ×", mult, "  →  tap = ", round(r["transformer"]["t1"]["tap"], digits=4),
            ",  |V_lv| = ", vlv(r), " V")
end
```

Loss minimisation holds the LV bus at the top of its band; the tap is lowered
further as load grows (a *deeper boost* — recall a lower multiplier raises the
secondary) to keep it there. This tap-vs-load curve is the optimised schedule a
line-drop compensator approximates, here derived directly from the network optimum.

## 3. Continuous vs. a real discrete regulator

A physical regulator moves in discrete steps (a 32-step ±10 % regulator has
0.625 %/step). The continuous optimum is the relaxation; rounding to the nearest
step recovers an implementable setting and shows how little is lost:

```@example tap
step = 0.10 / 16                      # ±10 % over 32 steps
t_disc = 1 + round((t★ - 1) / step) * step
rd = solve_opf(feeder(""","tap":$t_disc""", ""); optimizer = OPT)   # tap fixed at the step
println("continuous tap = ", round(t★, digits=4), " (|V_lv| = ", vlv(rf), " V)")
println("nearest step   = ", round(t_disc, digits=4), " (|V_lv| = ", vlv(rd), " V)")
```

Rounding to the nearest physical step lands a few tenths of a volt off the continuous
optimum — the small, quantifiable cost of discretisation. The continuous relaxation
is both the achievable bound and an excellent guide to the step to dial in.

## 4. Three-phase Dy

The same one-keyword change works for a three-phase delta-wye transformer. Here a
500 kVA, 11 kV(Δ) / 415 V(Y) unit feeds a balanced load; freeing the tap holds the
LV bus in a tight band. (The delta source is set per phase-to-ground, i.e.
``11\,\text{kV}/\sqrt3 = 6350.85`` V; the wye secondary is reported phase-to-neutral.)

```@example tap
zf = 11_000.0^2 / 500_000.0
zt =    415.0^2 / 500_000.0
dy(tapfields, vb) = parse_bmopf("""
{"bus":{
   "hv":{"terminal_names":["1","2","3"]},
   "lv":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]$vb}},
 "voltage_source":{"src":{"bus":"hv","terminal_map":["1","2","3"],
     "v_magnitude":[6350.85,6350.85,6350.85],
     "v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
 "load":{"ld":{"bus":"lv","terminal_map":["1","2","3","n"],"configuration":"WYE",
     "p_nom":[110000.0,110000.0,110000.0],"q_nom":[35000.0,35000.0,35000.0]}},
 "transformer":{"delta_wye":{"t1":{
     "bus_from":"hv","bus_to":"lv",
     "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3","n"],
     "v_nom_from":11000.0,"v_nom_to":415.0,"s_rating":500000.0,
     "r_series_from":$(0.01*zf),"x_series_from":$(0.02*zf),
     "r_series_to":$(0.01*zt),"x_series_to":$(0.02*zt)$tapfields}}}}
"""; from_string=true)

rdy = solve_opf(dy(""","tap":1.0,"tap_min":0.95,"tap_max":1.05""",
                   ""","v_min":[236.0,236.0,236.0],"v_max":[240.0,240.0,240.0]""");
                optimizer = OPT)
println("Dy free tap  →  status = ", rdy["termination_status"],
        ",  tap = ", round(rdy["transformer"]["t1"]["tap"], digits=4))
for t in ("1","2","3")
    println("  |V_lv.", t, "| = ", round(rdy["bus"]["lv"][t]["vm"], digits=2), " V")
end
```

The load is balanced, so the optimiser boosts all three LV phases together into the
tight 236–240 V band with a single tap — the three-phase analogue of Section 2's
rescue, with no per-phase code changes.

!!! note "Dy/Yd leakage referral is exact under tap"
    For `delta_wye`/`wye_delta` the coupled delta-arm leakage carries the exact
    ``t^2`` referral, matching OpenDSS's winding-1 self-impedance scaling: the
    short-circuit impedance referred to the tapped (from) side scales as ``t^2``
    and the non-tapped side is held at nominal (verified directly against
    OpenDSS's short-circuit `Yprim`). The same referral is used in the OPF and
    the exported `Yprim`, so they stay consistent at every tap — as do the YY,
    `center_tap`, and regulator models.

## What single-phase and Dy tell us about the general picture

*(A developer-oriented aside — skip to [Validation](#Validation) if you only want to
use the feature.)*

Working the two cases out side by side surfaces the design choice for extending taps
to *every* transformer:

- **The single-phase (YY) tap admits an exact, degree-2 OLTC model.** Scaling the
  from-winding leakage by ``t^2`` and referring it to the to side gives a *constant*
  leakage and a voltage drop that is linear-in-current and quadratic-in-tap — and it
  matches the OpenDSS turns-scaled `Yprim` at the optimised tap to the usual ~0.3 V
  validation floor.
- **The split-phase (`center_tap`) tap also admits an exact, degree-2 model.** Its
  free tap reuses the same coupled-coil `Yprim` as the fixed model, but with the HV
  ratio promoted to a variable and the voltage drop written in the degree-2 T-model
  form (``N\cdot v`` and ``N\cdot Z_2 I`` products only). It is algebraically
  identical to the fixed `Yprim` — re-solving with the tap fixed to ``t^\star``
  reproduces the free solution to **0.0 V** — so the leakage referral is exact, not
  approximate, even under heavy drop and leg unbalance.
- **The Dy/Yd coupled delta-arm model also carries the exact ``t^2`` referral.**
  OpenDSS scales winding 1's self-impedance by ``t^2``, so the short-circuit
  impedance referred to the tapped (from) side scales as ``t^2`` and the
  non-tapped side is held at nominal (verified directly against OpenDSS's
  short-circuit `Yprim`). The coefficients are degree-1 in the tap variables
  (``n_\text{eff}`` and its reciprocal), so the coupled-arm drop stays degree-2
  for a free tap, and the same referral is used in the exported `Yprim` — so the
  two paths agree at every tap.

The optimiser, the JSON schema and the result reporting are uniform across all the
covered subtypes, and the leakage referral is now exact for every two-bus subtype.
What remains to generalise is free taps for the `n_winding` subtype, to-side taps,
and discrete steps.

## Validation

Each case is checked against OpenDSS: the optimised continuous tap ``t^\star`` is set
on the corresponding OpenDSS transformer winding, the power flow is solved, and the
bus voltages are compared to the OPF solution (see
`test/powerflow_comparison_tests.jl`, *optimised tap vs OpenDSS*). Because the
variable-tap model is the fixed-tap model with the ratio promoted to a variable,
agreement at ``t^\star`` is the validation of the feature.

For `center_tap` the cross-check is deliberately stressed: a 5 km feeder with heavy,
**unequal** 120 V leg loads (high voltage drop + unbalance) — node voltages agree
with the OpenDSS turns-scaled `Yprim` at ``t^\star`` to ≈ 0.25 V and **total losses
to ≈ 2.5 %**, and the free T-model reproduces the fixed-`Yprim` re-solve at
``t^\star`` exactly (0.0 V).
