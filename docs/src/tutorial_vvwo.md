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

!!! note "Prerequisites"
    A Julia session with BMOPFTools plus **JuMP** and **Ipopt**
    (`using Pkg; Pkg.add(["JuMP", "Ipopt"])`), or `julia --project=docs` from a
    clone of the repository. If the pipeline (parse → augment → solve) is new to
    you, start with the [end-to-end tutorial](tutorial_end_to_end.md). One
    naming note: this feeder ships as native BMOPF JSON with numbered terminals
    `"1"`/`"2"`/`"3"`, whereas networks imported via `from_dss` use `"a"`/`"b"`/`"c"` —
    see the [terminals primer](terminals_primer.md).

Every code block on this page runs when the documentation is built, so the
voltages and dispatches below are live solver output. The complete, runnable
script is
[`examples/vvwo_tutorial.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/vvwo_tutorial.jl):

```
julia --project=test examples/vvwo_tutorial.jl
```

## PV IBRs as distributed control

Why does a fleet of *locally* controlled IBRs have anything to do with a
*centralized* OPF? In this study PV is priced at zero while grid import is priced
positively, so the optimiser pushes **every** IBR's active power toward its
nameplate — each unit maximises its *own* export — and the only things that hold
it back are its **local** droop response and any **hard limit**. The droop reads a
single local quantity, the IBR's own terminal voltage magnitude
$U_{n,k} = |\Delta v_k|$: Volt-var sets reactive power $q = -f^{VV}(U)$ and
Volt-watt caps active power $p \le f^{VW}(U)$ (see
[Optimal power flow](opf.md) for the encoding). There is no peer-to-peer
messaging and no central set-point.

What turns $N$ selfish local controllers into one *problem* is the network:
injections move voltages (to first order
$\mathbf v \approx \mathbf R\,\mathbf p + \mathbf X\,\mathbf q + \text{const}$),
so one IBR's export raises the voltage that another IBR then measures and reacts
to. The fleet is a closed feedback loop — *control law → injections → voltages →
control law* — and a power-flow simulator closes it by **iteration**, which is
precisely a distributed (Jacobi / gradient-type) algorithm running over the IBRs.
The deep result [[1]](@ref refs-vvwo), [[2]](@ref refs-vvwo) is that on a
**balanced, radial** feeder this loop has a unique equilibrium, and that
equilibrium is the **minimiser of a single convex network-wide objective** — the
selfish local rules collectively descend one global potential function, so an OPF
that encodes the droop can compute their fixed point **in one shot** instead of
iterating to it.

!!! details "The potential-game result in more detail"
    Farivar, Chen & Low [[1]](@ref refs-vvwo) showed that on a balanced, radial
    feeder under the linearised **LinDistFlow** model [[3]](@ref refs-vvwo), with
    a monotone droop, the local-control dynamics has a **unique equilibrium**,
    and that equilibrium is the minimiser of a single convex network-wide
    objective. In other words the selfish local rules behave as one *potential
    game*: there is a global potential function that every local controller is
    implicitly, collectively descending, and its minimum is the fixed point they
    converge to. Zhou, Farivar, Liu, Chen & Low [[2]](@ref refs-vvwo) generalised
    this into **reverse engineering** (read off the global problem any given
    local law is solving) and **forward engineering** (design the local law so
    its equilibrium solves a *chosen* global problem). The practical upshot:
    under those assumptions, "everyone maximises their own output, reacting only
    to their own voltage" provably lands at the optimum of a centralized
    optimisation — no coordinator required.
    ([[4]](@ref refs-vvwo) surveys the broader distributed-optimisation
    landscape.)

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
below walk this arc — from no droop at all, to the distributed equilibrium, to
the constrained centralized optimum.

## The setup

We use the real `LV1_14bus` feeder (11 kV / 433 V, two single-phase customers on
phases 1 and 2), shipped with the package as `examples/lv1_14bus.json`. To create
the over-voltage that VV/VW exists to solve, we put a PV cluster at each customer
connection and operate the feeder the way real LV networks are run at the edge of
hosting capacity:

- the **feeder head is tapped to 1.05 pu** (utilities run the LV head high to
  cover downstream voltage drop — which is precisely when midday PV export
  over-voltages the far end);
- the **service drops are modelled at 30 m** (the raw dataset ships ~6 m drops,
  too short to develop a realistic rise); and
- each PV cluster is **45 kVA**, free to run to nameplate (≈ eight of the study's
  5.25 kVA rooftop IBRs behind one pole-top).

Because the loads — and therefore the PV — sit on different phases, the export is
itself unbalanced, which is where four-wire modelling (explicit neutral, no Kron
reduction) earns its keep. The objective minimises **priced grid import**, so with
PV priced at zero the OPF maximises export until a constraint stops it.

`base_net()` builds this network fresh for each scenario — parse the JSON, retap
the head, lengthen the two service drops, and place the two PV clusters:

```@example vvwo
using BMOPFTools
using JuMP, Ipopt

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0,
                                      "max_iter" => 500)
const LV_LN_V = 230.0        # LV phase-to-neutral nominal (V)

# A single-phase PV nameplate on `phase` of `bus`: p_avail = s_max so the unit is
# free to run to nameplate (curtailed only by Volt-watt or a hard limit); cost 0
# so the OPF maximises export (every exported W displaces priced grid import).
pv(bus, phase) = Dict{String,Any}(
    "bus" => bus, "terminal_map" => [phase, "n"], "topology" => "SINGLE_PHASE",
    "prime_mover" => "PV", "s_max" => [45_000.0], "p_avail" => 45_000.0,
    "p_max" => [45_000.0], "p_min" => [0.0], "cost" => [0.0])

function base_net()
    net = parse_bmopf(joinpath(pkgdir(BMOPFTools), "examples", "lv1_14bus.json"))

    vs = first(values(net["voltage_source"]))
    haskey(vs, "cost") || (vs["cost"] = fill(1.0, length(vs["v_magnitude"]) - 1))
    f = LV_LN_V / (433.0 / sqrt(3))               # source sits on the 11 kV side
    vs["v_magnitude"] = [f * 1.05 * v for v in vs["v_magnitude"]]   # head → 1.05 pu

    net["line"]["l_3726"]["length"] = 30.0        # service drop to b3230 (phase 1)
    net["line"]["l_2126"]["length"] = 30.0        # service drop to b2656 (phase 2)

    net["ibr"] = Dict{String,Any}("pv_a" => pv("b3230", "1"),
                                  "pv_b" => pv("b2656", "2"))
    return net
end
nothing # hide
```

A few helpers: the set of LV buses (the limits and the reported maximum must not
touch the 11 kV source bus), the phase-to-neutral magnitude in pu, an
[`AugmentationRecipe`](@ref) that disables every automatic bound pass (each
scenario adds exactly the limits it wants), and a one-line reporter for a solved
OPF:

```@example vvwo
using Printf

lv_buses(net) = [b for b in keys(net["bus"])
                 if b != first(values(net["voltage_source"]))["bus"]]

function vpn_pu(res, b, t)              # phase-to-neutral magnitude (pu of 230 V)
    ph = res["bus"][b]
    (haskey(ph, t) && haskey(get(ph, "n", Dict()), "vr")) || return 0.0
    n = ph["n"]
    return abs((ph[t]["vr"] - n["vr"]) + im * (ph[t]["vi"] - n["vi"])) / LV_LN_V
end

# Disable every automatic augment_case bound pass; scenario C toggles thermal on.
manual_recipe(; thermal=false) = AugmentationRecipe(
    apply_v_bounds=false, apply_vpn_bounds=false, apply_vpp_bounds=false,
    apply_vneg_bounds=false, apply_thermal=thermal, apply_q_bounds=false,
    apply_slack_generator=false, apply_ibr=false)

function solve_and_report(aug)
    res = solve_opf(aug; optimizer=OPT, per_unit=true)
    res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL") ||
        error("OPF did not solve: ", res["termination_status"])
    vmax = maximum(vpn_pu(res, b, t) for b in lv_buses(aug) for t in ("1", "2", "3"))
    P   = sum(v["pg"] for ph in values(res["ibr"]) for v in values(ph)) / 1000
    Q   = sum(v["qg"] for ph in values(res["ibr"]) for v in values(ph)) / 1000
    exp = -sum(v["ps"] for v in values(first(values(res["voltage_source"])))) / 1000
    @printf("max V (φ-n) : %.4f pu   P_total = %.1f kW   Q_total = %+.1f kvar   export = %.1f kW\n",
            vmax, P, Q, exp)
    return (vmax=vmax, P=P, Q=Q, exp=exp)
end
nothing # hide
```

## Three scenarios

The three scenarios are the arc from the previous section made concrete: **A** is
the fleet with *no droop modelled at all*, **B** is the distributed equilibrium
*solved in one shot*, and **C** is the *constrained centralized optimum* that
lives beyond the local-droop equivalence.

### A — unity power factor, no limits (no droop)

PV runs at unity power factor and no network limits are imposed. There is no
droop in this scenario — nothing reads the voltage the export creates — so each
IBR simply runs to nameplate. This is the uncoordinated selfish maximum:

```@example vvwo
netA = base_net()
for (_, inv) in netA["ibr"]
    inv["q_min"] = [0.0]; inv["q_max"] = [0.0]    # pin Q = 0: unity-PF baseline
end
augA, _ = augment_case(netA; recipe=manual_recipe())
A = solve_and_report(augA)
nothing # hide
```

The worst phase-to-neutral voltage is **1.114 pu**, well over the 1.10 pu limit.
A power-flow tool would report this over-voltage faithfully — and stop there.

### B — AS/NZS 4777.2 droop in the constraints (the distributed equilibrium)

Now add the droop: attach a (blank) Volt-var / Volt-watt control profile to each
IBR and let [`augment_case`](@ref) fill the blank curves from the AS/NZS 4777.2
"Australia A" preset in the config. Encoding the droop *inside* the OPF lands
directly on the fixed point that the local controllers would otherwise iterate
to — and, in the balanced case, that fixed point is the centralized optimum of
[[1]](@ref refs-vvwo), [[2]](@ref refs-vvwo), reached here with no outer loop:

```@example vvwo
function attach_droop!(net)
    net["control_profile"] = Dict("vvw" =>
        Dict("volt_var" => Dict{String,Any}(), "volt_watt" => Dict{String,Any}()))
    for (_, inv) in net["ibr"]; inv["control_profile"] = "vvw"; end
    return net
end

cfg = deepcopy(BMOPFTools.load_config())
cfg["augment"]["smart_ibr"]["enabled"] = true     # fill blank curves from the preset
cfg["augment"]["smart_ibr"]["region"]  = "Aus_A"  # AS/NZS 4777.2:2020 "Australia A"

netB = attach_droop!(base_net())
augB, _ = augment_case(netB; config=cfg, recipe=manual_recipe())

println("volt_var  : ", augB["control_profile"]["vvw"]["volt_var"])
println("volt_watt : ", augB["control_profile"]["vvw"]["volt_watt"])
B = solve_and_report(augB)
nothing # hide
```

The IBRs now **absorb reactive power** (Volt-var) and **curtail active
power** (Volt-watt), pulling the voltage down — solved in *one shot* with the
network, no outer iteration. To see *which segment* of the Aus A curves the
equilibrium sits on, look at each IBR's own monitored voltage:

```@example vvwo
resB = solve_opf(augB; optimizer=OPT, per_unit=true)
for id in sort(collect(keys(augB["ibr"])))
    ibr = augB["ibr"][id]
    bus = ibr["bus"]; ph = ibr["terminal_map"][1]
    v = vpn_pu(resB, bus, ph) * LV_LN_V
    p = resB["ibr"][id][ph]["pg"] / 1000
    q = resB["ibr"][id][ph]["qg"] / 1000
    @printf("%s @ %s phase %s : V(φ-n) = %.1f V   P = %.1f kW   Q = %+.1f kvar\n",
            id, bus, ph, v, p, q)
end
```

Both units sit on the **upper Volt-var absorption ramp**, which runs from 0 at
240 V to −0.6 × s\_max at 258 V: at 254.0 V `pv_a` absorbs
(254.0 − 240)/18 × 0.6 ≈ 0.47 of its 45 kVA rating ≈ 21 kvar, and at 252.0 V
`pv_b` absorbs ≈ 0.40 × 45 ≈ 18 kvar — exactly the dispatched values. They also
straddle the **253 V Volt-watt knee** (the cap ramps from 1.0 at 253 V down to
0.2 at 260 V), which trims the fleet from 90 kW to 81 kW — a **10 % curtailment**
(the softplus surrogate rounds the knee, so `pv_b`, sitting just below 253 V, is
already slightly curtailed too).

Note the worst voltage still sits at **1.104 pu**: the 4777.2 curve is a deadband
droop, not a hard guarantee, and this is an unbalanced four-wire feeder, so we are
already outside the regime where the local-droop equilibrium would coincide with a
constraint-respecting centralized optimum. That is exactly why the next step
matters.

### C — hard limits only an optimiser can enforce (beyond the equivalence)

Keep the droop, and add the constraints that the distributed law provably cannot
guarantee here: a 1.10 pu phase-to-neutral ceiling, a neutral-to-ground cap, and
(via the recipe's thermal pass) thermal ratings on the LV buses:

```@example vvwo
netC = attach_droop!(base_net())
for b in lv_buses(netC)
    netC["bus"][b]["vpn_max"] = fill(1.10 * LV_LN_V, 3)
    netC["bus"][b]["vpn_min"] = fill(0.90 * LV_LN_V, 3)
    netC["bus"][b]["vn_max"]  = 0.10 * LV_LN_V    # neutral rise — a four-wire-only limit
end
augC, _ = augment_case(netC; config=cfg, recipe=manual_recipe(thermal=true))
C = solve_and_report(augC)
nothing # hide
```

The OPF **co-optimises the droop and the network limits**: the voltage is held at
*exactly* 1.10 pu by curtailing a little more PV. This binding constraint —
enforced directly as a hard limit here, rather than approached by trial-and-error
setpoints or outer iteration in a fixed-setpoint simulation — is the whole point
of an OPF.

### Summary

```@example vvwo
@printf("%-22s %10s %13s %15s %12s\n",
        "scenario", "max V (pu)", "P_total (kW)", "Q_total (kvar)", "export (kW)")
for (label, o) in (("A — unity PF", A), ("B — droop", B), ("C — droop + limits", C))
    @printf("%-22s %10.4f %13.1f %15.1f %12.1f\n", label, o.vmax, o.P, o.Q, o.exp)
end
```

The droop (B) trades export for voltage support relative to the naive maximum
(A); the hard limit (C) trades a little more to *guarantee* the ceiling. Each
added binding constraint weakly increases the minimised objective (priced grid
import); since this feeder is a net exporter, that shows up as **less export
revenue** — the price of respecting the network physics and the operating
envelope at once. Read through the lens of the previous section: A is the fleet
with no droop, B is the distributed equilibrium computed directly, and C is the
constrained centralized optimum — the dispatch a fleet of purely local
controllers cannot reach on its own, because the balanced-network equivalence
that would license it no longer holds on a four-wire feeder under active
curtailment.

!!! note "What VV/VW control costs in this model"
    There is **no explicit price on reactive support or on curtailment** here.
    The only term in the objective is priced grid import; PV active power is
    priced at zero, and reactive power is not priced at all. So the economic cost
    of the droop is entirely *implicit* — it shows up as **foregone export
    revenue** (Volt-watt curtailment lowers the exported active power, and the
    reactive absorption of Volt-var consumes VA headroom that would otherwise
    carry active export), which is exactly the objective increase from A→B→C in
    the table. Note the native `cost` field prices **active power only**
    (`cost[k]·P_k`); there is no built-in reactive-power price or curtailment
    penalty. To model an *explicit* ancillary-service payment for reactive
    support — or a compensation for curtailed active power — extend the objective
    with a [`model_hook!`](opf.md) that adds the corresponding term (a cost on
    `|Q|`, or a penalty on `p_avail − P`); the objective then prices those
    services directly rather than only through lost export.

## Appendix: the monitored voltage — quantity and aggregation

The voltage a droop law reacts to has two independent degrees of freedom, both
set through the curve's `voltage_reference` (one of the six
`voltage_reference_type` values; see [the OPF model](opf.md#IBRs)).

**Quantity — what the magnitude is taken between.** `PN_*` uses phase-to-neutral
$\lvert v_\varphi - v_n\rvert$ (the default), `PG_*` phase-to-ground
$\lvert v_\varphi\rvert$, and `PP_*` phase-to-phase. The phase-to-ground vs
phase-to-neutral choice is exactly the **`Connection`** switch of the source
study — on a four-wire feeder the neutral is displaced from ground, so the two
references make the IBRs see different voltages and dispatch differently.

**Aggregation — how phases combine.** A three-phase (`FOUR_LEG`) IBR can respond
to **each phase's own** magnitude (the `_PER_PHASE` suffix, the default) or to the
**mean** of the three (the `_AVERAGED` suffix, like a single three-phase unit that
regulates on its average terminal voltage). (The legacy IBR-level
`voltage_aggregation = "PER_PHASE" | "AVERAGE"` field still selects the
aggregation and overrides the enum's suffix when present.)

To see both effects we use a deliberately unbalanced minimal feeder — a stiff
source, one four-wire line, 8 kW on phase 1 and 2 kW on phase 3, and a 3 × 10 kVA
`FOUR_LEG` PV — whose load-bus neutral is *not* grounded, so it lifts under
unbalance and phase-to-neutral genuinely differs from phase-to-ground:

```@example vvwo
function aside_net(vref)
    net = parse_bmopf("""
    {"bus":{
       "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
       "lb" :{"terminal_names":["1","2","3","n"]}},
     "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
         "v_magnitude":[245.0,245.0,245.0],"v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
     "linecode":{"lc":{"R_series_1_1":0.4,"R_series_2_2":0.4,"R_series_3_3":0.4,"R_series_4_4":0.4,
         "X_series_1_1":0.1,"X_series_2_2":0.1,"X_series_3_3":0.1,"X_series_4_4":0.1}},
     "line":{"l1":{"bus_from":"src","bus_to":"lb","linecode":"lc","length":1.0,
         "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"]}},
     "load":{"la":{"bus":"lb","terminal_map":["1","n"],"configuration":"WYE","p_nom":[8000.0],"q_nom":[0.0]},
             "lc":{"bus":"lb","terminal_map":["3","n"],"configuration":"WYE","p_nom":[2000.0],"q_nom":[0.0]}},
     "control_profile":{"vvw":{"volt_var":{},"volt_watt":{}}},
     "ibr":{"pv":{"bus":"lb","terminal_map":["1","2","3","n"],"topology":"FOUR_LEG",
         "prime_mover":"PV","s_max":[10000.0,10000.0,10000.0],
         "p_avail":30000.0,"p_max":[10000.0,10000.0,10000.0],"p_min":[0.0,0.0,0.0],
         "control_profile":"vvw","cost":[0.0,0.0,0.0]}}}
    """; from_string=true)
    for law in ("volt_var", "volt_watt")
        net["control_profile"]["vvw"][law]["voltage_reference"] = vref
    end
    return net
end

for vref in ("PN_PER_PHASE", "PN_AVERAGED", "PG_PER_PHASE")
    aug, _ = augment_case(aside_net(vref); config=cfg, recipe=manual_recipe())
    res = solve_opf(aug; optimizer=OPT, per_unit=true)
    qs  = [res["ibr"]["pv"][ph]["qg"] / 1000 for ph in ("1", "2", "3")]
    vs  = [vpn_pu(res, "lb", ph) for ph in ("1", "2", "3")]
    @printf("%-13s V(φ-n) = [%.3f %.3f %.3f] pu   Q = [%+.2f %+.2f %+.2f] kvar   ΣQ = %+.2f\n",
            vref, vs..., qs..., sum(qs))
end
```

Reading the three rows:

- **`PN_PER_PHASE` vs `PN_AVERAGED` (aggregation).** With per-phase, each phase
  reacts to its own voltage, so the high-voltage phase 2 absorbs most and the
  heavily loaded phase 1 least. With averaged, every phase reacts to the common
  mean, giving identical reactive injection on all three — and letting the
  individual phase voltages spread further apart.
- **`PN_PER_PHASE` vs `PG_PER_PHASE` (quantity).** The lifted neutral *widens*
  the phase-to-neutral spread relative to the phase-to-ground one, so the
  phase-to-neutral law concentrates its absorption on the neutral-shifted high
  phase, while the phase-to-ground law — blind to the neutral — dispatches more
  evenly across the phases (and, here, ends up absorbing slightly *more* in
  total). Which law is "right" is a standards question; that they differ at all
  is a four-wire phenomenon.

This appendix is also a concrete face of the caveat from
[PV IBRs as distributed control](#PV-IBRs-as-distributed-control): the
laws give materially different dispatches *because the bus is unbalanced*. The
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
