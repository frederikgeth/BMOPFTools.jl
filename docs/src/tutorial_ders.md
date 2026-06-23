# Tutorial: Placing DERs and reading the *binding constraint*

Hosting-capacity and DER-coordination studies all turn on one question: *when the
cheap distributed generation wants to run, which network constraint stops it?*

A power-flow tool can only answer it after the fact — inject some power, solve,
and check whether a voltage or a current came out too high. An **optimal power
flow (OPF)** answers it directly: it dispatches the DERs against the network
physics and the operating envelope *at once*, and the **active constraint set** of
the optimum *is* the hosting-capacity answer. Which constraint binds — and which
DER is curtailed to respect it — is the modeling content, not the objective value.

This tutorial builds that OPF from a raw LV feeder using the library's
**recipe-driven DER placement** (`add_inverters` / `add_generators`), then runs
three scenarios on the *same* feeder and DER fleet that each make a **different
constraint bind**. The throughline:

> B and C share a feeder, a DER fleet, an operating point, and a limit set. They
> differ by a single knob — the service-cable ampacity — yet the active constraint
> flips from **voltage** to **thermal**, and the optimal dispatch flips with it.

The framing follows the network-aware curtailment / dynamic-hosting-capacity view
of Badmus & Pandey [[1]](@ref refs-ders), on the four-wire IVR-EN model of Deakin,
Pandey & Geth [[2]](@ref refs-ders); see also [Positioning & ecosystem](positioning.md)
for where BMOPFTools sits relative to the wider distribution-OPF ecosystem.

The complete, runnable script is
[`examples/place_and_solve_ders.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/place_and_solve_ders.jl):

```
julia --project=test examples/place_and_solve_ders.jl
```

## The setup

We use the real `LV1_14bus` feeder (11 kV / 433 V, two single-phase customers on
phases 1 and 2). Instead of hand-writing each DER, we **declare** them with a
recipe and let the library choose buses from the network's own semantics and
record every field it writes:

```julia
INV_RECIPE = InverterRecipe(
    strategy = :load_following,   # one PV inverter per load bus
    s_fraction = 5.0,             # s_max = 5.0 × local load  (≈ 50 kVA cluster)
    s_to_p_ratio = 0.90,          # p_avail = 0.9 × s_max — leaves VA headroom
    cost_basis = :uniform, der_cost_uniform = 0.2)   # cheaper than the slack (1.0)

GEN_RECIPE = GeneratorRecipe(
    strategy = :load_following,
    der_p_fraction = 0.5,         # p_max = 0.5 × local load  (≈ 5 kW)
    cost_basis = :uniform, der_cost_uniform = 0.3)   # dearer than PV, cheaper than slack
```

A load-following recipe drops one PV inverter on each load bus, and a thinner
generator co-locates with it. Both are priced below the slack, so the OPF sees a
layered **merit order** — cheap PV → mid-priced generator → expensive slack
import:

```
  INV  pv_b2656   bus=b2656   topo=SINGLE_PHASE s_max=[50000.0] VA
  INV  pv_b3230   bus=b3230   topo=SINGLE_PHASE s_max=[50000.0] VA
  GEN  der_b2656  bus=b2656   cfg=SINGLE_PHASE  p_max=[5000.0] W
  GEN  der_b3230  bus=b3230   cfg=SINGLE_PHASE  p_max=[5000.0] W
```

Because the loads — and therefore the PV — sit on *different* phases, the export
is itself unbalanced, which is where four-wire modelling (explicit neutral, no
Kron reduction) earns its keep. `augment_case` then fills the standards-grounded
gaps: the inverter `P²+Q²≤s_max²` circle and its EN 50549-1 reactive box, the
generator reactive limits, the IEC 60228 thermal limit, and a per-phase slack
price. We add the EN 50160 phase-to-neutral ceiling (`vpn_max = 1.10 pu`)
explicitly so we control exactly the limit we mean.

## Three scenarios

### A — cheap DERs, no network limit

The economic baseline: head at nominal, no voltage ceiling, no thermal limit. The
OPF is then a pure cost sort.

```
max V (φ-n) : 1.0716 pu     thermal: 90 %     export = 70.8 kW
pv_b2656 = 45.0 kW   pv_b3230 = 45.0 kW   der_b2656 = 5.0 kW   der_b3230 = 5.0 kW
→ BINDING : generation bounds only
```

Every DER runs to its bound and the surplus (70.8 kW) is exported — the slack
simply absorbs negative power. The only active constraints are the imposed
generation limits; the network is not yet in the way. This is the merit order
working exactly as priced.

### B — head run high, healthy cable → voltage binds

Now tap the feeder head to 1.05 pu (utilities run the LV head high to cover
downstream drop — precisely when midday PV export over-voltages the far end) and
impose the EN 50160 ceiling:

```julia
for b in lv_buses(net)
    net["bus"][b]["vpn_max"] = fill(1.10 * 230.0, 3)
    net["bus"][b]["vpn_min"] = fill(0.90 * 230.0, 3)
end
```

```
max V (φ-n) : 1.1000 pu     thermal: 90 %     export = 54.5 kW
pv_b2656 = 45.00 kW  (Q = -21.79 kvar)     pv_b3230 = 37.09 kW  (Q = -21.79 kvar)
der_b2656 =  0.18 kW                        der_b3230 =  0.00 kW
→ BINDING : voltage (vpn_max)
```

The voltage is held at **exactly 1.10 pu** and the dispatch changes completely.
Two things happen, co-optimised in a single solve:

- **The inverters absorb reactive power for voltage support.** Each PV sits on its
  apparent-power circle: at `s_max = 50 kVA` the reactive headroom at full active
  power is

  $$Q_{\text{avail}} = \sqrt{s_{\max}^2 - P^2} = \sqrt{50^2 - 45^2} \approx 21.8\ \text{kvar},$$

  which is exactly the −21.79 kvar both inverters draw. The `P²+Q²≤s_max²` circle
  *trades active headroom for reactive absorption* — reactive support is not free.
- **The merit order is respected on the way down.** The OPF sheds the dearer
  generator (`der_*` → ~0) before curtailing the cheaper PV, and curtails the PV
  only on the worst phase (`pv_b3230`, 45 → 37 kW) — the unbalanced curtailment a
  three-wire model could not represent.

A simulation-only tool would report the over-voltage of scenario A and stop; here
the limit *reshapes* the optimal dispatch.

### C — same case, a thin cable → thermal binds instead

Keep everything — head, feeder, DER fleet, the 1.10 pu ceiling — and change only
*one* thing: give the two service drops a realistically derated 16 mm² ampacity
(`i_max = 90 A`) instead of their healthy rating.

```
max V (φ-n) : 1.0839 pu     thermal: 100 %    export = 43.5 kW
pv_b2656 = 32.43 kW     pv_b3230 = 32.44 kW     der_b2656 = der_b3230 = 0.0 kW
→ BINDING : thermal (i_max)
```

The voltage is now **slack** (1.084 pu, below the ceiling) and the **thermal limit
binds** at 100 % of `i_max`. The OPF curtails the PV to hold the conductor current
at its rating — a *different* binding constraint, curtailing a *different* amount
on a *different* basis than the voltage case, even though nothing else about the
problem changed.

### Summary

| scenario | max V (pu) | thermal (%) | export (kW) | ΣP (kW) | binding |
|---|---:|---:|---:|---:|:--|
| A — no limits | 1.0716 | 90 | 70.8 | 100.0 | generation bounds only |
| B — voltage | 1.1000 | 90 | 54.5 | 82.3 | voltage (`vpn_max`) |
| C — thermal | 1.0839 | 100 | 43.5 | 64.9 | thermal (`i_max`) |

B and C differ by a single knob — the service-cable ampacity — yet the **active
constraint** flips from voltage to thermal, and with it which DER is curtailed and
how much exports. Adding or tightening a binding constraint can only raise the
objective (less export); *which* constraint binds is the signature of an
optimisation that respects the network physics and the operating envelope at once.

## Appendix: the hosting-capacity curve and the constraint crossover

If one knob can flip the binding constraint, what does sweeping it look like? Hold
the scenario-C setup fixed and sweep only the cable ampacity:

```
  i_max(A)    max V(pu)   export(kW)   binding
        60       1.0726         29.0   thermal (i_max)
        90       1.0839         43.5   thermal (i_max)
       120       1.0952         58.0   voltage + thermal
       160       1.1000         66.8   voltage + thermal
       220       1.1000         67.7   voltage (vpn_max)
       600       1.1000         67.7   voltage (vpn_max)
```

While the cable is thin the **thermal** limit binds and every extra amp of rating
buys more export. Around 120–160 A both constraints are active at once — the
crossover. Past it the **voltage** ceiling takes over: the voltage pins at 1.10 pu,
export plateaus at 67.7 kW, and uprating the copper no longer buys hosting
capacity, because the limit is now a voltage problem, not a thermal one.

That crossover is exactly the network-aware hosting-capacity question of
[[1]](@ref refs-ders), read straight off the OPF's active constraint set — the
practical payoff of solving the dispatch and the network together.

## [References](@id refs-ders)

1. E. O. Badmus, A. Pandey, *ANOCA: AC Network-aware Optimal Curtailment Approach
   for Dynamic Hosting Capacity*, IEEE Conference on Decision and Control (CDC),
   Milan, Italy, 2024.
2. M. Deakin, A. Pandey, F. Geth, *Mathematical Model and Data Model for
   Up-To-Four-Wire Distribution System OPF*, IEEE Task Force on Benchmarking
   Multiconductor OPF for Distribution Systems, draft V0.2, 2026.
