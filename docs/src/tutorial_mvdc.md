# MVDC/LVDC converter stations — feeder balancing as an optimisation

This tutorial shows how BMOPFTools models **MVDC/LVDC converter stations** —
back-to-back soft open points (SOPs), MVDC ties, and DC feeders — by reusing the
`ibr` object. There is no separate "converter" object: an AC/DC converter
is an `ibr` that carries a `dc_bus` reference, and **several converters sharing one
`dc_bus` form a station**. The DC side balances active power, so the station can
route power between AC feeders that the AC topology alone could not.

*Prerequisites: a Julia environment with `BMOPFTools`, `JuMP` and `Ipopt` installed,
and familiarity with the JSON input format — see the
[end-to-end tutorial](tutorial_end_to_end.md) first. Every code block on this page runs when
the docs are built, so the numbers below are real.*

See the [conventions](@ref dc-network) for the DC terminal/pole/return and
grounding rules used below.

## Why this is an optimisation, not a simulation

A normally-open tie leaves two feeders radial: a power-flow **simulator** gives a
single, determined answer. Replace the tie with a **soft open point** and the
power split across it becomes a free decision — there is no longer one "simulate"
answer. To find the *best* split you must solve an optimisation, and the quantity
you want (the optimal transfer, and the loss/hosting-capacity it unlocks) is the
*solution* of that problem, not an output you can read off a simulator.

The literature frames the SOP/MVDC benefit exactly this way — feeder load
balancing, loss reduction, voltage support, and DG hosting-capacity enhancement,
all posed as optimisation problems ([1](@ref refs-mvdc), [2](@ref refs-mvdc),
[3](@ref refs-mvdc)), with reported loss reductions and hosting-capacity gains
well into the tens of percent. Below we reproduce the simplest of these —
**loss-minimising feeder balancing** — as a single OPF.

## The case: one substation, two unevenly loaded feeders

A single substation feeds two feeders of equal impedance (`R = 1 Ω` each). One
feeder carries 50 kW, the other 10 kW. An SOP ties the two feeder ends through a
DC bus — the whole MVDC subsystem is **embedded in one AC system**, the way a real
SOP is deployed.

```@example mvdc
using BMOPFTools, JuMP, Ipopt
const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

sop_case() = parse_bmopf("""
{"bus":{
   "sub":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
   "a":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],"v_min":[600.0],"v_max":[1100.0]},
   "b":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],"v_min":[600.0],"v_max":[1100.0]}},
 "linecode":{"lc":{"R_series_1_1":1.0,"X_series_1_1":0.0}},
 "line":{
   "La":{"bus_from":"sub","bus_to":"a","terminal_map_from":["1","n"],"terminal_map_to":["1","n"],"length":1.0,"linecode":"lc"},
   "Lb":{"bus_from":"sub","bus_to":"b","terminal_map_from":["1","n"],"terminal_map_to":["1","n"],"length":1.0,"linecode":"lc"}},
 "voltage_source":{
   "s":{"bus":"sub","terminal_map":["1","n"],"v_magnitude":[1000.0,0.0],"v_angle":[0.0,0.0],"cost":[1.0]}},
 "load":{
   "La_load":{"bus":"a","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[50000.0],"q_nom":[0.0]},
   "Lb_load":{"bus":"b","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[10000.0],"q_nom":[0.0]}},
 "ibr":{
   "vA":{"bus":"a","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[60000.0],"dc_bus":"dc","dc_terminal_map":["p","m"],"dc_control":"V","dc_v_set":1500.0},
   "vB":{"bus":"b","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[60000.0],"dc_bus":"dc","dc_terminal_map":["p","m"]}},
 "dc_bus":{
   "dc":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
         "v_dc_min":[1400.0,0.0],"v_dc_max":[1800.0,0.0]}},
 "dc_grounding":{"g":{"dc_bus":"dc","terminal":"m"}}}
"""; from_string=true)

res = solve_opf(sop_case(); optimizer = OPT)
println("vA pg   : ", round(res["ibr"]["vA"]["1"]["pg"], digits=0), " W  (SOP delivers into the heavy feeder)")
println("vB pg   : ", round(res["ibr"]["vB"]["1"]["pg"], digits=0), " W  (SOP draws from the light feeder)")
println("v_dc    : ", round(res["dc_bus"]["dc"]["p"]["v_dc"], digits=1), " V")
println("p_loss  : ", round(res["losses"]["p_loss"], digits=0), " W")
```

The source carries a `cost`, so minimising generation cost minimises the power it
must supply — and with the loads fixed, that is exactly the network loss. The two
converters share `dc_bus = "dc"`, which is what makes them one station; each spans
the pole `p` and the grounded metallic return `m`. Per-converter results live under
`res["ibr"][id]["1"]["pg"]` (AC-side active power, positive into the AC network)
and the DC node voltage under `res["dc_bus"]["dc"]["p"]["v_dc"]`.

Converter `vA` is the **DC-voltage master** (`dc_control = "V"`, `dc_v_set = 1500`):
like an AC slack bus, an MVDC zone needs one converter to set the DC voltage, or
its `v_dc` is underdetermined (the validator flags `E.INT.DC_NO_VOLTAGE_CONTROL`
otherwise — demonstrated [below](@ref mvdc-validating)). The master holds `v_dc`;
its AC power floats to balance the zone, while `vB` controls power. Real systems
also use **V–P droop** (`dc_control = "droop"`), which shares DC-voltage regulation
across converters and saturates at their power limits — see the
[conventions](@ref dc-network) and the next section.

## The answer the optimiser computes

The two feeders start at 50 kW and 10 kW. The OPF chooses to move **20 kW** across
the SOP — `vA.pg = +20 kW`, `vB.pg = −20 kW` — so both feeders end up carrying
30 kW. That is precisely the analytic loss-optimal split `(P_a − P_b)/2`: equalising
the currents minimises `Σ I²R`. Removing the SOP shows what it was worth:

```@example mvdc
radial = sop_case()
for k in ("ibr", "dc_bus", "dc_grounding")
    delete!(radial, k)
end
res_radial = solve_opf(radial; optimizer = OPT)
println("radial p_loss : ", round(res_radial["losses"]["p_loss"], digits=0), " W")
```

The losses fall from **2888 W** (radial, no SOP) to **1917 W** — a **34 %
reduction** — with no change to the loads served. Crucially, `20 kW` is not
something you could read off a load-flow run; it is the *decision* the optimisation
makes. Drop the converters and you get the radial 2888 W; the SOP's value only
appears once you let the OPF choose the transfer.

## Droop control: shared DC-voltage regulation

The case above uses one **V-master** (`dc_control = "V"`) — fine when a single
converter can hold the DC voltage. Real MVDC zones usually prefer **V–P droop**,
where several converters *share* the DC-voltage regulation, so no single converter
is a single point of failure ([4](@ref refs-mvdc), [5](@ref refs-mvdc)).
Droop is a **control law**, not free dispatch: each converter's AC-side active
power follows its own P–V characteristic,

```math
p_g = \texttt{dc\_p\_ref} + \frac{v_{dc} - \texttt{dc\_v\_set}}{\texttt{dc\_droop}},
```

saturated at the converter's power limits. Sign conventions matter here: `pg` is
the AC-side injection, so the power a converter **delivers into the DC link** is
`−pg` — with `dc_p_ref = 0`, that is `(dc_v_set − v_dc)/dc_droop`, positive
whenever the DC voltage has drooped *below* the set-point.

Put two droop converters (`vA`, `vB`) on one `dc_bus` that jointly feed a DC load,
both with `dc_v_set = 1500`, `dc_p_ref = 0`. The listing is complete — note the DC
voltage window `[1200, 1800] V` is deliberately wide enough for the heaviest load
below:

```@example mvdc
droop_case(kA, kB, P_load; smaxA = 60000.0, smaxB = 60000.0) = parse_bmopf("""
{"bus":{
   "sub":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
   "a":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"],"v_min":[600.0],"v_max":[1100.0]}},
 "linecode":{"lc":{"R_series_1_1":1.0,"X_series_1_1":0.0}},
 "line":{
   "La":{"bus_from":"sub","bus_to":"a","terminal_map_from":["1","n"],"terminal_map_to":["1","n"],"length":1.0,"linecode":"lc"}},
 "voltage_source":{
   "s":{"bus":"sub","terminal_map":["1","n"],"v_magnitude":[1000.0,0.0],"v_angle":[0.0,0.0],"cost":[1.0]}},
 "ibr":{
   "vA":{"bus":"a","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[$smaxA],
         "dc_bus":"dc","dc_terminal_map":["p","m"],
         "dc_control":"droop","dc_v_set":1500.0,"dc_p_ref":0.0,"dc_droop":$kA},
   "vB":{"bus":"a","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[$smaxB],
         "dc_bus":"dc","dc_terminal_map":["p","m"],
         "dc_control":"droop","dc_v_set":1500.0,"dc_p_ref":0.0,"dc_droop":$kB}},
 "dc_bus":{
   "dc":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
         "v_dc_min":[1200.0,0.0],"v_dc_max":[1800.0,0.0]}},
 "dc_load":{"dl":{"dc_bus":"dc","terminal_map":["p","m"],"p":$P_load}},
 "dc_grounding":{"g":{"dc_bus":"dc","terminal":"m"}}}
"""; from_string=true)
nothing # hide
```

Solving gives the textbook droop behaviour — and it is the OPF that finds the
self-consistent `(v_dc, P_A, P_B)`, not a hand-iterated controller model. We
tabulate the power each converter delivers **into the DC link** (`−pg`):

```@example mvdc
println(rpad("kA", 9), rpad("kB", 9), rpad("P_load", 9),
        rpad("P_A→dc", 10), rpad("P_B→dc", 10), "v_dc")
for (kA, kB, P) in ((0.005, 0.005, 10e3), (0.0025, 0.005, 10e3), (0.005, 0.005, 60e3))
    r = solve_opf(droop_case(kA, kB, P); optimizer = OPT)
    PA = -r["ibr"]["vA"]["1"]["pg"]
    PB = -r["ibr"]["vB"]["1"]["pg"]
    println(rpad(kA, 9), rpad(kB, 9), rpad("$(P/1e3) kW", 9),
            rpad("$(round(PA/1e3, digits=2)) kW", 10),
            rpad("$(round(PB/1e3, digits=2)) kW", 10),
            round(r["dc_bus"]["dc"]["p"]["v_dc"], digits=1), " V")
end
```

Three things to read off:

- **The DC voltage droops** below the 1500 V reference as load rises (1475 → 1350 V)
  — that voltage *deviation* is the shared signal that tells every converter how
  much to contribute: with `dc_p_ref = 0`, each delivers
  `(dc_v_set − v_dc)/dc_droop` into the link.
- **Power shares inversely to the droop coefficient.** Halving `kA` (a stiffer
  converter) makes `vA` carry twice `vB` (6.67 vs 3.33 kW) at the same shared
  `v_dc`.
- **Saturation is built in.** Drive a converter past its headroom and its power
  clamps at `s_max` instead of following the line to infinity — the curve is a
  *saturated* piecewise-linear P–V characteristic, encoded with the same smooth
  (softplus) machinery as the Volt-watt/Volt-var droops so it stays well-behaved
  for Ipopt.

The saturation point deserves a demonstration. Shrink `vA` to a 10 kVA nameplate
and load the link with 30 kW — unsaturated droop would split it 15/15 kW at
1425 V, but `vA` can no longer follow its line:

```@example mvdc
r = solve_opf(droop_case(0.005, 0.005, 30e3; smaxA = 10000.0); optimizer = OPT)
println("P_A→dc : ", round(-r["ibr"]["vA"]["1"]["pg"]/1e3, digits=2), " kW  (clamped at s_max)")
println("P_B→dc : ", round(-r["ibr"]["vB"]["1"]["pg"]/1e3, digits=2), " kW")
println("v_dc   : ", round(r["dc_bus"]["dc"]["p"]["v_dc"], digits=1), " V")
```

`vA` clamps at its 10 kW limit; `vB` — still on its droop line — must pick up the
remaining 20 kW, which requires the common DC voltage to droop all the way to
`1500 − 20000 × 0.005 = 1400 V`. The saturated converter no longer participates in
voltage regulation; the burden shifts entirely to the ones with headroom.

Every DC zone needs at least one `"V"` or `"droop"` converter; an all-`"P"` zone
leaves `v_dc` undetermined and is flagged `E.INT.DC_NO_VOLTAGE_CONTROL`.

## Extending the story

- **Loss vs hosting capacity.** Swap a load for DER on one feeder and the same
  formulation finds how much extra generation the feeders can host before a voltage
  or thermal limit binds — the SOP redistributing the surplus ([3](@ref refs-mvdc)).
- **A real DC line.** Put the two converters on separate `dc_bus` nodes joined by a
  `dc_branch` and the tie becomes an **MVDC feeder** with its own `I²R` loss: the
  importing and exporting powers then differ by exactly that loss, and the
  pole-voltage drop equals `I·R`. Remember to widen the far bus's
  metallic-return voltage bounds (`v_dc_min`/`v_dc_max` on the `m` terminal) —
  pinning both returns to 0 V while the return conductor has resistance forces the
  tie current to zero.
- **Bipolar / DC loads.** Use 3-wire `dc_bus`/`dc_branch` for bipolar feeders, and
  add `dc_load`/`dc_source` for DC-connected demand or DC-coupled PV/storage.

## [Validating](@id mvdc-validating)

The static validators catch DC data problems before the solve — dangling `dc_bus`
references, ungrounded DC islands, bad bus arity, and a converter whose AC bus is
**energised only through the DC link** (`W.INT.DC_FED_AC_ISLAND`, the "MVDC not
embedded in a referenced AC system" check). Here is the voltage-control check
firing: demote the V-master to plain power control and no converter regulates the
DC voltage.

```@example mvdc
bad = sop_case()
bad["ibr"]["vA"]["dc_control"] = "P"   # no V-master or droop left in the zone
rep = analyze(bad)
for f in rep.findings
    if f.code == "E.INT.DC_NO_VOLTAGE_CONTROL"
        println(f.severity, " ", f.code, "\n  ", f.message)
    end
end
```

[`solution_check`](validation.md) adds post-solve DC checks
(`E.SOL.DC_VOLT_VIOLATION`, `E.SOL.DC_THERMAL_VIOLATION`). See the
[finding-code reference](findings.md#DC-—-MVDC/LVDC-network).

## [References](@id refs-mvdc)

1. W. Cao, J. Wu, N. Jenkins, *Feeder load balancing in MV distribution networks
   using soft normally-open points*, IEEE PES Innovative Smart Grid Technologies
   Europe (ISGT-Europe), 2014.
2. X. Jiang, Y. Zhou, W. Ming, P. Yang, J. Wu, *An Overview of Soft Open Points in
   Electricity Distribution Networks*, IEEE Transactions on Smart Grid
   **13**(3):1899–1910, 2022.
3. *Hosting-capacity maximisation of distribution networks with optimised soft
   open points*, Energies **16**(3):1035, 2023.
4. *Comparison between voltage droop and voltage margin controllers for MTDC
   systems*, 2019.
5. K. Rouzbehi, A. Miranian, A. Luna, P. Rodriguez, *A Generalized Voltage Droop
   Strategy for Control of Multiterminal DC Grids*, IEEE Transactions on Industry
   Applications **51**(1):607–618, 2015.
