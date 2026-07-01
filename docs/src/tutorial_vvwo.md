# Tutorial: PV smart IBRs as distributed control

A fleet of rooftop PV IBRs is, whether we model it that way or not, a
**distributed control system**. Each IBR is a self-interested local agent:
it wants to export as much of its own active power as possible, and it reacts to
**only one signal it can measure locally** — the voltage at its own terminals —
through an AS/NZS 4777.2 [[6]](@ref refs-vvwo) Volt-var / Volt-watt droop curve.
No IBR sees the others; they are coupled *only* through the grid, because one unit's export lifts
the voltage that its neighbours then sense and respond to. "Everyone maximises
their own output, reacting to their own voltage" is therefore not a heuristic —
it is a genuine distributed optimisation problem.

The remarkable result this tutorial is built around (Farivar–Chen–Low
[[1]](@ref refs-vvwo); Zhou–Farivar–Low [[2]](@ref refs-vvwo)) is that for a
**balanced** network this distributed problem is *equivalent to a centralized
one*: the equilibrium the local controllers settle into is the optimum of a
single, well-defined network-wide optimisation. That equivalence is what makes
local droop trustworthy — and it is also what an OPF lets us exploit and, where
the equivalence breaks, replace.

Most introductions to VV/VW droop instead present it as a **power-flow** feature:
a simulator such as OpenDSS iterates an outer control loop until the IBR
set-points and the network voltages agree. That is *incremental* control — the
distributed algorithm run to convergence. This tutorial shows the other half of
the picture: the very same droop can be written as **constraints inside an
optimal power flow (OPF)** and solved *simultaneously* with the four-wire network
equations — *non-incremental* control that lands directly on the equilibrium. Two
things then become possible that a simulation-only tool cannot do:

1. the IBR set-points and voltages are found in **one consistent solve**, with
   no outer iteration to converge (or oscillate) — in the balanced case this is the
   centralized optimum the distributed controllers are implicitly seeking; and
2. you can add **hard limits** — a voltage ceiling, a neutral-rise cap, thermal
   ratings, an export envelope — that *reshape the optimal dispatch*, in the
   unbalanced four-wire regime where no local-droop equilibrium can guarantee them.

The four-wire VVO framing follows Mhanna, Geth, Quiertant & Mancarella
[[5]](@ref refs-vvwo). BMOPFTools encodes the piecewise-linear droop with that
paper's **softplus** (smooth-ReLU) surrogate so that Ipopt differentiates it
exactly — see [Optimal power flow](opf.md) for the encoding details.

The complete, runnable script is
[`examples/vvwo_tutorial.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/vvwo_tutorial.jl):

```
julia --project=test examples/vvwo_tutorial.jl
```

## PV IBRs as distributed control

Before the scenarios, it is worth being precise about *why* a fleet of locally
controlled IBRs has anything to do with a centralized OPF — because that
equivalence is the conceptual payoff, and it is also exactly what tells us when
the OPF is doing something the local controllers cannot.

### Each IBR is a self-interested local agent

In this study PV is priced at zero while grid import is priced positively (the
objective minimises priced import), so the optimiser pushes **every** IBR's
active power toward its nameplate — each unit maximises its *own* export — and the
only things that hold it back are its **local** droop response and any **hard
limit**. The droop reads a single local quantity, the IBR's own terminal
voltage magnitude $U_{n,k} = |\Delta v_k|$: Volt-var sets reactive power
$q = -f^{VV}(U)$ and Volt-watt caps active power $p \le f^{VW}(U)$ (see
[Optimal power flow](opf.md) for the encoding). There is no peer-to-peer
messaging and no central set-point — each IBR knows only itself.

### They are coupled only through the grid

What turns $N$ selfish local controllers into one *problem* is the network.
Injections move voltages — to first order, around an operating point,
$\mathbf v \approx \mathbf R\,\mathbf p + \mathbf X\,\mathbf q + \text{const}$
with $\mathbf R,\mathbf X$ the network sensitivity matrices — so one IBR's
export raises the voltage that another IBR then measures and reacts to. The
fleet is a closed feedback loop: *control law → injections → voltages → control
law*. A power-flow simulator closes it by **iteration** (update set-points from
the latest voltages, re-solve, repeat); that loop is precisely a distributed
(Jacobi / gradient-type) algorithm running over the IBRs.

### Local selfishness ⇒ a global optimum (the balanced case)

The deep result is that this distributed loop is not arbitrary. Farivar, Chen &
Low [[1]](@ref refs-vvwo) showed that on a **balanced, radial** feeder under the
linearised **LinDistFlow** model [[3]](@ref refs-vvwo), with a monotone droop, the
local-control dynamics has a **unique equilibrium**, and that equilibrium is the
**minimiser of a single convex network-wide objective**. In other words the
selfish local rules behave as one *potential game*: there is a global potential
function that every local controller is implicitly, collectively descending, and
its minimum is the fixed point they converge to. Zhou, Farivar, Liu, Chen & Low
[[2]](@ref refs-vvwo) generalised this into **reverse engineering** (read off the
global problem any given local law is solving) and **forward engineering**
(design the local law so its equilibrium solves a *chosen* global problem). The
practical upshot: under those assumptions, "everyone maximises their own output,
reacting only to their own voltage" provably lands at the optimum of a
centralized optimisation — no coordinator required, and an OPF that encodes the
droop can compute that optimum **in one shot** instead of iterating to it
([[4]](@ref refs-vvwo) surveys the broader distributed-optimisation landscape).

**Where the equivalence breaks — and the OPF takes over.** The guarantee rests on
two assumptions that real LV feeders violate: the **balanced single-phase**
LinDistFlow approximation, and a **monotone, reactive-only** droop. On an
**unbalanced four-wire** network — explicit neutral, per-phase droop, and
*active-power* curtailment that itself moves voltages through $\mathbf R$ — the
clean "distributed equilibrium = centralized optimum" equivalence no longer holds,
and a deadband droop cannot *guarantee* any particular voltage. That is exactly
the regime BMOPFTools targets: it solves the centralized **nonlinear** four-wire
OPF [[5]](@ref refs-vvwo) directly, so it returns the true co-optimum and can
enforce hard limits the distributed law only approximates. The three scenarios
below walk this arc — from no feedback, to the distributed equilibrium, to the
constrained centralized optimum.

## The setup

We use the real `LV1_14bus` feeder (11 kV / 433 V, two single-phase customers on
phases 1 and 2). To create the over-voltage that VV/VW exists to solve, we put a
PV cluster at each customer connection and operate the feeder the way real LV
networks are run at the edge of hosting capacity:

- the **feeder head is tapped to 1.05 pu** (utilities run the LV head high to
  cover downstream voltage drop — which is precisely when midday PV export
  over-voltages the far end);
- the **service drops are modelled at 30 m** (the raw dataset ships ~6 m drops,
  too short to develop a realistic rise); and
- each PV cluster is **45 kVA**, free to run to nameplate (≈ eight of the study's
  5.25 kVA rooftop IBRs behind one pole-top).

Because the loads — and therefore the PV — sit on different phases, the export is
itself unbalanced, which is where four-wire modelling (explicit neutral, no Kron
reduction) earns its keep.

The objective minimises **priced grid import**, so with PV priced at zero the OPF
maximises export until a constraint stops it.

## Three scenarios

The three scenarios are the arc from the previous section made concrete: **A** is
the fleet with the feedback loop *open*, **B** is the distributed equilibrium
*closed and solved in one shot*, and **C** is the *constrained centralized
optimum* that lives beyond the local-droop equivalence.

### A — unity power factor, no limits (no feedback)

PV runs at unity power factor and no network limits are imposed: the droop
feedback loop is open, so each IBR simply exports to nameplate with nothing
reading the voltage it creates. This is the uncoordinated selfish maximum.

```julia
for (_, inv) in net["ibr"]
    inv["q_min"] = [0.0]; inv["q_max"] = [0.0]   # unity PF baseline
end
```

```
max V (φ-n) : 1.1139 pu        P_total = 90.0 kW   Q_total =  -0.0 kvar   export = 30.7 kW
```

The worst phase-to-neutral voltage is **1.114 pu**, well over the 1.10 pu limit.
A power-flow tool would report this over-voltage faithfully — and stop there.

### B — AS/NZS 4777.2 droop in the constraints (the distributed equilibrium)

Now close the loop: attach a (blank) Volt-var / Volt-watt control profile to each
IBR and let `augment_case` fill it from the "Australia A" preset. Encoding
the droop *inside* the OPF lands directly on the fixed point that the local
controllers would otherwise iterate to — and, in the balanced case, that fixed
point is the centralized optimum of [[1]](@ref refs-vvwo), [[2]](@ref refs-vvwo),
reached here with no outer loop:

```julia
net["control_profile"] = Dict("vvw" =>
    Dict("volt_var" => Dict{String,Any}(), "volt_watt" => Dict{String,Any}()))
for (_, inv) in net["ibr"]; inv["control_profile"] = "vvw"; end

cfg = deepcopy(BMOPFTools.load_config())
cfg["augment"]["smart_ibr"]["enabled"] = true     # fill from AS/NZS 4777.2 Aus A
```

```
max V (φ-n) : 1.1042 pu        P_total = 81.0 kW   Q_total = -38.9 kvar   export = 26.8 kW
```

The IBRs now **absorb reactive power** (Volt-var) and **curtail active
power** (Volt-watt), pulling the voltage down — solved in *one shot* with the
network, no outer iteration. Note the voltage still sits at **1.104 pu**: the
4777.2 curve is a deadband droop, not a hard guarantee, and this is an unbalanced
four-wire feeder, so we are already outside the regime where the local-droop
equilibrium would coincide with a constraint-respecting centralized optimum. That
is exactly why the next step matters.

### C — hard limits only an optimiser can enforce (beyond the equivalence)

Keep the droop, and add the constraints that the distributed law provably cannot
guarantee here: a 1.10 pu phase-to-neutral ceiling, a neutral-to-ground cap, and
(via `augment_case`) thermal ratings on the LV buses.

```julia
for b in lv_buses(net)
    net["bus"][b]["vpn_max"] = fill(1.10 * 230.0, 3)
    net["bus"][b]["vpn_min"] = fill(0.90 * 230.0, 3)
    net["bus"][b]["vn_max"]  = 0.10 * 230.0          # four-wire-only limit
end
```

```
max V (φ-n) : 1.1000 pu        P_total = 77.9 kW   Q_total = -37.4 kvar   export = 25.4 kW
```

The OPF **co-optimises the droop and the network limits**: the voltage is held at
*exactly* 1.10 pu by curtailing a little more PV. This binding constraint —
impossible in a simulation-only tool — is the whole point of an OPF.

### Summary

| scenario | max V (pu) | P total (kW) | Q total (kvar) | export (kW) |
|---|---:|---:|---:|---:|
| A — unity PF | 1.1139 | 90.0 | −0.0 | 30.7 |
| B — droop | 1.1042 | 81.0 | −38.9 | 26.8 |
| C — droop + limits | 1.1000 | 77.9 | −37.4 | 25.4 |

The droop (B) trades export for voltage support relative to the naive maximum
(A); the hard limit (C) trades a little more to *guarantee* the ceiling. Adding a
binding constraint can only raise the objective (less export) — the signature of
an optimisation that respects the network physics and the operating envelope at
once. Read through the lens of the previous section: A is the distributed loop
left open, B is its equilibrium computed directly, and C is the constrained
centralized optimum — the dispatch a fleet of purely local controllers cannot
reach on its own, because the balanced-network equivalence that would license it
no longer holds on a four-wire feeder under active curtailment.

## Appendix: the monitored voltage — quantity and aggregation

The voltage a droop law reacts to has two independent degrees of freedom, both
set through the curve's `voltage_reference` (one of the six
`voltage_reference_type` values; see [the OPF model](opf.md#IBRs)).

**Quantity — what the magnitude is taken between.** `PN_*` uses phase-to-neutral
$\lvert v_\varphi - v_n\rvert$ (the default), `PG_*` phase-to-ground
$\lvert v_\varphi\rvert$, and `PP_*` phase-to-phase. The phase-to-ground vs
phase-to-neutral choice is exactly the **`Connection`** switch of the source
study — on a four-wire feeder the neutral is displaced from ground, so the two
references make the inverters see different voltages and dispatch differently. On
this network the phase-to-ground (`PG_PER_PHASE`) variant absorbs noticeably less
reactive power than the phase-to-neutral one, because the worst phase-to-ground
magnitude sits below the phase-to-neutral magnitude once the neutral lifts.

**Aggregation — how phases combine.** A three-phase (`FOUR_LEG`) IBR can respond
to **each phase's own** magnitude (the `_PER_PHASE` suffix, the default) or to the
**mean** of the three (the `_AVERAGED` suffix, like a single three-phase unit that
regulates on its average terminal voltage). On an unbalanced bus the two dispatch
reactive power very differently:

```
PER_PHASE   V(φ-n) = [1.073 1.109 1.104] pu   Q = [-2.28 -4.99 -4.61] kvar
AVERAGE     V(φ-n) = [1.065 1.119 1.106] pu   Q = [-4.10 -4.10 -4.10] kvar
```

With per-phase, each phase reacts to its own voltage, so the lightly-loaded
high-voltage phase absorbs most and the heavily-loaded phase least. With averaged,
every phase reacts to the common mean, giving balanced reactive injection. (The
legacy IBR-level `voltage_aggregation = "PER_PHASE" | "AVERAGE"` field still selects the
aggregation and overrides the enum's suffix when present.)

This appendix is also a concrete face of the caveat from
[PV IBRs as distributed control](#PV-IBRs-as-distributed-control): the
two laws give materially different dispatches *because the bus is unbalanced*. The
balanced-network equivalence of [[1]](@ref refs-vvwo), [[2]](@ref refs-vvwo) is
silent on which one is "optimal" — on a single-phase equivalent there is only one
voltage and the distinction collapses. It is precisely the per-phase, four-wire
detail that the centralized OPF resolves and a single-phase distributed analysis
cannot.

## [References](@id refs-vvwo)

1. M. Farivar, L. Chen, S. H. Low, *Equilibrium and dynamics of local voltage
   control in distribution systems*, 52nd IEEE Conference on Decision and Control
   (CDC), Florence, Italy, 2013, pp. 4329–4334, doi:10.1109/CDC.2013.6760555.
2. X. Zhou, M. Farivar, Z. Liu, L. Chen, S. H. Low, *Reverse and Forward
   Engineering of Local Voltage Control in Distribution Networks*, IEEE
   Transactions on Automatic Control, vol. 66, no. 3, pp. 1116–1128, 2021,
   doi:10.1109/TAC.2020.2994184 (arXiv:1801.02015).
3. M. E. Baran, F. F. Wu, *Optimal Capacitor Placement on Radial Distribution
   Systems*, IEEE Transactions on Power Delivery, vol. 4, no. 1, pp. 725–734,
   1989, doi:10.1109/61.19265. (Introduces the DistFlow / LinDistFlow branch
   model — the balanced, radial approximation the equivalence rests on.)
4. D. K. Molzahn, F. Dörfler, H. Sandberg, S. H. Low, S. Chakrabarti, R. Baldick,
   J. Lavaei, *A Survey of Distributed Optimization and Control Algorithms for
   Electric Power Systems*, IEEE Transactions on Smart Grid, vol. 8, no. 6,
   pp. 2941–2962, 2017, doi:10.1109/TSG.2017.2720471.
5. S. Mhanna, F. Geth, L. Quiertant, P. Mancarella, *Volt-VAr-Watt Optimization in
   Four-Wire Low-Voltage Networks: Exact Nonlinear Models and Smooth
   Approximations*, IEEE Transactions on Power Systems, 2026.
6. AS/NZS 4777.2:2020, *Grid connection of energy systems via IBRs, Part 2:
   IBR requirements*, Standards Australia / Standards New Zealand, 2020.
