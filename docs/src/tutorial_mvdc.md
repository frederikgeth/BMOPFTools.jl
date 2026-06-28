# MVDC/LVDC converter stations — feeder balancing as an optimisation

This tutorial shows how BMOPFTools models **MVDC/LVDC converter stations** —
back-to-back soft open points (SOPs), MVDC ties, and DC feeders — by reusing the
[`ibr`](@ref) object. There is no separate "converter" object: an AC/DC converter
is an `ibr` that carries a `dc_bus` reference, and **several converters sharing one
`dc_bus` form a station**. The DC side balances active power, so the station can
route power between AC feeders that the AC topology alone could not.

See the [conventions](conventions.md#DC-network-MVDC/LVDC-—-terminals-poles-grounding)
for the DC terminal/pole/return and grounding rules used below.

## Why this is an optimisation, not a simulation

A normally-open tie leaves two feeders radial: a power-flow **simulator** gives a
single, determined answer. Replace the tie with a **soft open point** and the
power split across it becomes a free decision — there is no longer one "simulate"
answer. To find the *best* split you must solve an optimisation, and the quantity
you want (the optimal transfer, and the loss/hosting-capacity it unlocks) is the
*solution* of that problem, not an output you can read off a simulator.

The literature frames the SOP/MVDC benefit exactly this way — feeder load
balancing, loss reduction, voltage support, and DG hosting-capacity enhancement,
all posed as optimisation problems
([Cao et al., feeder load balancing with soft open points](https://www.researchgate.net/publication/281770025_Feeder_load_balancing_in_MV_distribution_networks_using_soft_normally-open_points);
[Jiang et al., SOP overview](https://orca.cardiff.ac.uk/id/eprint/147097/1/Jiang%20X%20-%20An%20overview%20of%20SOPs_accepted%20version.pdf);
[hosting-capacity maximisation with optimised SOPs, *Energies* 16(3) 1035](https://www.mdpi.com/1996-1073/16/3/1035)),
with reported loss reductions and hosting-capacity gains well into the tens of
percent. Below we reproduce the simplest of these — **loss-minimising feeder
balancing** — as a single OPF.

## The case: one substation, two unevenly loaded feeders

A single substation feeds two feeders of equal impedance (`R = 1 Ω` each). One
feeder carries 50 kW, the other 10 kW. An SOP ties the two feeder ends through a
DC bus — the whole MVDC subsystem is **embedded in one AC system**, the way a real
SOP is deployed.

```julia
using BMOPFTools, JuMP, Ipopt

net = parse_bmopf("""
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
   "vA":{"bus":"a","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[60000.0],"dc_bus":"dc","dc_terminal_map":["p","m"]},
   "vB":{"bus":"b","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[60000.0],"dc_bus":"dc","dc_terminal_map":["p","m"]}},
 "dc_bus":{
   "dc":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
         "v_dc_min":[1400.0,0.0],"v_dc_max":[1800.0,0.0]}},
 "dc_grounding":{"g":{"dc_bus":"dc","terminal":"m"}}}
"""; from_string=true)

res = solve_opf(net)
res["ibr"]["vA"]["1"]["pg"]   #  +20 000 W  (SOP delivers into the heavy feeder)
res["ibr"]["vB"]["1"]["pg"]   #  −20 000 W  (SOP draws from the light feeder)
res["losses"]["p_loss"]       #  ≈ 1917 W
```

The source carries a `cost`, so minimising generation cost minimises the power it
must supply — and with the loads fixed, that is exactly the network loss. The two
converters share `dc_bus = "dc"`, which is what makes them one station; each spans
the pole `p` and the grounded metallic return `m`.

## The answer the optimiser computes

The two feeders start at 50 kW and 10 kW. The OPF chooses to move **20 kW** across
the SOP — `vA.pg = +20 kW`, `vB.pg = −20 kW` — so both feeders end up carrying
30 kW. That is precisely the analytic loss-optimal split `(P_a − P_b)/2`: equalising
the currents minimises `Σ I²R`. The losses fall from **2889 W** (radial, no SOP)
to **1917 W** — a **34 % reduction** — with no change to the loads served.

Crucially, `20 kW` is not something you could read off a load-flow run; it is the
*decision* the optimisation makes. Drop the converters and you get the radial 2889 W;
the SOP's value only appears once you let the OPF choose the transfer.

## Extending the story

- **Loss vs hosting capacity.** Swap a load for DER on one feeder and the same
  formulation finds how much extra generation the feeders can host before a voltage
  or thermal limit binds — the SOP redistributing the surplus
  ([*Energies* 16(3) 1035](https://www.mdpi.com/1996-1073/16/3/1035)).
- **A real DC line.** Put the two converters on separate `dc_bus` nodes joined by a
  `dc_branch` and the tie becomes an **MVDC feeder** with its own `I²R` loss: the
  importing and exporting powers then differ by exactly that loss, and the
  pole-voltage drop equals `I·R`.
- **Bipolar / DC loads.** Use 3-wire `dc_bus`/`dc_branch` for bipolar feeders, and
  add `dc_load`/`dc_source` for DC-connected demand or DC-coupled PV/storage.

## Validating

The static validators catch DC data problems before the solve — dangling `dc_bus`
references, ungrounded DC islands, bad bus arity, and a converter whose AC bus is
**energised only through the DC link** (`W.INT.DC_FED_AC_ISLAND`, the "MVDC not
embedded in a referenced AC system" check). [`solution_check`](validation.md) adds
post-solve DC checks (`E.SOL.DC_VOLT_VIOLATION`, `E.SOL.DC_THERMAL_VIOLATION`). See
the [finding-code reference](findings.md#DC-—-MVDC/LVDC-network).
