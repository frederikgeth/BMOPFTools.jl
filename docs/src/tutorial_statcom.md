# [D-STATCOM unbalance study](@id statcom-unbalance)

*Reactive support vs. active power circulation on an unbalanced LV feeder.*

This case study follows one **unbalanced low-voltage (LV) feeder** to show what an
inverter-interfaced shunt compensator — a **STATCOM**, or *D-STATCOM* in
distribution-system parlance — can and cannot do about voltage unbalance, and *why
the answer is an optimisation problem rather than a simulation one*. Every code
block runs when the docs are built, so the numbers below are real.

*Prerequisites: a Julia environment with `BMOPFTools`, `JuMP` and `Ipopt` installed,
and familiarity with the JSON input format — see the
[end-to-end tutorial](tutorial_end_to_end.md) first.*

## Why unbalance is hard to fix with reactive power

LV feeders are unbalanced by construction: single-phase loads (and single-phase
rooftop PV) are spread unevenly across the three phases, so the phase carrying the
most load sags while the lightly-loaded phases stay high
([1](@ref refs-statcom)). The instinct from transmission engineering is to throw
*reactive* power at the problem — a STATCOM is, after all, a shunt var source, and
reactive management with STATCOMs is an active research thread for four-wire LV
feeders ([2](@ref refs-statcom)).

The instinct misfires in LV, and the reason is the network impedance. Voltage
magnitude responds to a power injection roughly as
``\Delta|V| \approx (R\,\Delta P + X\,\Delta Q)/|V|``. On the transmission grid ``X \gg R`` so reactive power is the
lever; on an LV feeder the cables are **resistive**, ``X/R \approx 0.2\!-\!0.5``, so
it is **active** power that moves the voltage ([1](@ref refs-statcom)). A var source
therefore has weak authority over the very phase that needs help.

A four-wire converter has a second lever that a capacitor bank or an SVC does not:
its three phase legs share **one DC link**. With no energy source behind that link,
the converter can still *circulate active power between phases* — sourcing real
power on the heavily-loaded phase and sinking it on the lightly-loaded ones — while
the **net** active power stays at zero. This is exactly the DC-link power-balance
constraint ``\sum_k P_k = 0`` formalised for four-wire OPF in
[3](@ref refs-statcom) and [4](@ref refs-statcom). It is what lets a STATCOM
*balance* a feeder rather than merely support its average voltage.

In BMOPFTools a STATCOM is modelled as an IBR (see the [OPF model](opf.md#IBRs));
the two control philosophies are a single keyword on [`add_statcom!`](@ref):

- **reactive-only** (default) — each phase's active power is clamped to zero;
- **active power circulation** (`dc_link_coupled = true`) — per-phase active power
  is free within the converter's apparent-power circle, coupled by ``\sum_k P_k = 0``.

The rest of this page shows, on one feeder, that the first barely moves the needle
and the second balances the feeder outright — and that finding the per-phase
``(P,Q)`` split is intrinsically an optimisation, not a setpoint a power-flow
*simulation* could have guessed.

## 1. An unbalanced four-wire LV feeder

A 230 V three-phase source feeds a short, resistive (``R/X = 5``) four-wire cable to
a single load bus whose phase 1 carries six times the load of phases 2 and 3 — a
deliberately stark single-phase concentration.

```@example statcom
using BMOPFTools, JuMP, Ipopt
const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

feeder() = parse_bmopf("""
{"bus":{
    "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
    "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
     "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
 "linecode":{"lc":{"R_series_1_1":0.4,"X_series_1_1":0.08,
                   "R_series_2_2":0.4,"X_series_2_2":0.08,
                   "R_series_3_3":0.4,"X_series_3_3":0.08,
                   "R_series_4_4":0.4,"X_series_4_4":0.08}},
 "line":{"l1":{"bus_from":"src","bus_to":"b1",
     "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
     "linecode":"lc","length":1.0}},
 "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
     "p_nom":[18000.0,3000.0,3000.0],"q_nom":[2000.0,500.0,500.0]}}}
"""; from_string=true)
nothing # hide
```

The headline metric is the **voltage unbalance factor** (VUF) — the ratio of the
negative- to positive-sequence voltage, the standard measure of unbalance — together
with the per-phase voltage spread and the feeder's active losses.

```@example statcom
solved(r) = r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL","ALMOST_LOCALLY_SOLVED")

function report(label, r, bus="b1")
    if !solved(r)
        println(rpad(label, 34), r["termination_status"]); return
    end
    b = r["bus"][bus]
    V = [b[t]["vr"] + im*b[t]["vi"] for t in ("1","2","3")]
    a  = exp(im*2pi/3)
    V1 = (V[1] + a*V[2] + a^2*V[3]) / 3
    V2 = (V[1] + a^2*V[2] + a*V[3]) / 3
    println(rpad(label, 34),
            "VUF = ", rpad(round(abs(V2)/abs(V1)*100, digits=2), 5), " %   ",
            "phase V = ", round.(abs.(V), digits=1), " V   ",
            "loss = ", round(r["losses"]["p_loss"], digits=0), " W")
end
nothing # hide
```

With no compensation the feeder is badly unbalanced — phase 1 sags well below the
lightly-loaded phases.

```@example statcom
r0 = solve_opf(feeder(); optimizer = OPT)
report("no STATCOM", r0)
```

## 2. The simulation reflex: a fixed reactive setpoint

What would an engineer running a *power-flow simulation* do? Pick a STATCOM, choose a
sensible reactive setpoint — say a symmetric **+5 kVAr per phase** — and simulate the
result with [`solve_pf`](@ref). We fix the device (`p = 0`, `q` pinned) and let the
power flow report the operating point.

```@example statcom
sim = feeder()
add_statcom!(sim, "b1"; s_max = 15_000.0)              # reactive-only nameplate
si = sim["ibr"]["statcom_b1"]
si["p_min"] = [0.0,0.0,0.0];      si["p_max"] = [0.0,0.0,0.0]
si["q_min"] = [5000.0,5000.0,5000.0]; si["q_max"] = [5000.0,5000.0,5000.0]

report("fixed +5 kVAr/phase (solve_pf)", solve_pf(sim; optimizer = OPT))
```

The unbalance hardly budges. The reactive injection lifts *all three* phase voltages
together — it cannot preferentially raise the sagging phase, because on a resistive
feeder reactive power is the wrong lever ([1](@ref refs-statcom)). Worse, the guess
is actively counterproductive: the extra reactive current *raises* the feeder losses
from 3723 W to 4009 W. A different constant setpoint would land somewhere else
equally arbitrary; a simulation can only *evaluate* a guess, never *find* the right
per-phase split.

## 3. Reactive-only, optimally dispatched — still not enough

Give the device its full reactive freedom and let [`solve_opf`](@ref) choose the
per-phase vars optimally, but keep it **reactive-only**. To make the limit concrete
we now impose a lower voltage bound on the load bus and ask whether reactive support
can hold it. The AS/NZS 4777.2 floor is ``0.94 \times 230 \approx 216\,V``; we
require 218 V — the floor plus a small operating margin.

```@example statcom
bounded() = (n = feeder();
    n["bus"]["b1"]["v_min"] = [218.0, 218.0, 218.0];
    n["bus"]["b1"]["v_max"] = [253.0, 253.0, 253.0]; n)

for s in (15_000.0, 30_000.0, 60_000.0)
    n = bounded(); add_statcom!(n, "b1"; s_max = s); n, _ = augment_case(n)
    report("reactive-only, s_max = $(Int(s/1000)) kVA", solve_opf(n; optimizer = OPT))
end
```

The reactive-only STATCOM cannot hold the heavy phase above its limit even at
60 kVA — twice the nameplate that will balance the feeder outright in §4, and more
than twice the feeder's total load. More vars cannot substitute for the active
power the phase is short of.

## 4. Active power circulation balances the feeder

Now flip the one keyword — `dc_link_coupled = true` — so the converter may circulate
active power between phases under ``\sum_k P_k = 0``. [`augment_case`](@ref) opens the
per-phase active range to ``\pm s_{\max}`` and pins the net to zero; the per-phase
apparent-power circle still bounds each leg.

```@example statcom
n = bounded()
add_statcom!(n, "b1"; s_max = 30_000.0, dc_link_coupled = true)
n, _ = augment_case(n)
inv = n["ibr"]["statcom_b1"]
println("per-phase P range : ", inv["p_min"], " … ", inv["p_max"], " W")
println("net DC-link bound : [", inv["p_dc_min"], ", ", inv["p_dc_max"], "] W")

ract = solve_opf(n; optimizer = OPT)
report("active circulation, 30 kVA", ract)
```

The same nameplate that was *infeasible* with reactive-only control now holds every
phase inside the window. Looking at what the converter does makes the mechanism
explicit: it **sources** real power on the heavy phase and **sinks** it on the light
phases, summing to zero — a pure inter-phase transfer drawing no net energy.

```@example statcom
ph = ract["ibr"]["statcom_b1"]
for t in ("1","2","3")
    println("phase $t :  P = ", rpad(round(ph[t]["pg"], digits=0), 8), " W   ",
                          "Q = ", round(ph[t]["qg"], digits=0), " var")
end
println("Σ P over phases : ", round(sum(ph[t]["pg"] for t in ("1","2","3")), digits=2), " W")
```

Run on the *unconstrained* feeder (no voltage limits), the optimiser drives the
unbalance essentially to zero and, by flattening the phase currents, **cuts the
feeder losses**, since balanced currents minimise the resistive ``\sum R|I|^2``:

```@example statcom
n = feeder(); add_statcom!(n, "b1"; s_max = 30_000.0, dc_link_coupled = true)
n, _ = augment_case(n)
report("no STATCOM (repeat)", r0)
report("active circulation", solve_opf(n; optimizer = OPT))
```

## 5. A physically faithful current limit

The apparent-power circle ``P_k^2 + Q_k^2 \le s_{\max}^2`` is the constant-MVA
idealisation. A real converter is limited by its **current**, and ``|S_k| =
|\Delta V_k|\,|I_k|``, so its capability shrinks as the terminal voltage sags. Supply
an optional per-conductor `i_max` and the model captures that rolloff
([3](@ref refs-statcom)); the balancing authority is then bounded by amps, not VA.
`i_max` is **per conductor** — one entry per phase plus a final entry for the
**neutral**, which on a four-wire converter doing unbalance compensation can carry
*more* current than any phase. On the unconstrained feeder of §4 — where active
circulation alone drove the VUF to zero — adding a 40 A per-phase current cap
(here with a generously-rated neutral, so the phase limit is what binds) leaves a
small residual unbalance, the visible signature of the var/active rolloff under load.
Printing the per-conductor current magnitudes makes "bounded by amps" concrete —
the heavy-phase leg sits at its 40 A cap:

```@example statcom
n = feeder(); add_statcom!(n, "b1"; s_max = 30_000.0, dc_link_coupled = true)
n["ibr"]["statcom_b1"]["i_max"] = [40.0, 40.0, 40.0, 120.0]   # A per conductor: a,b,c,n
n, _ = augment_case(n)
r5 = solve_opf(n; optimizer = OPT)
report("active circulation + i_max = 40 A", r5)
st = r5["ibr"]["statcom_b1"]
I  = [st[t]["cri"] + im*st[t]["cii"] for t in ("1", "2", "3")]
for (t, i) in zip(("1", "2", "3"), I)
    println("phase $t   : |I| = ", round(abs(i), digits=1), " A")
end
println("neutral   : |I| = ", round(abs(-sum(I)), digits=1), " A")
```

## Why optimisation matters

| Control of the same converter | Voltage unbalance | Heavy phase held? |
|---|---|---|
| None | severe (see §1) | — |
| Fixed reactive setpoint (*simulation*) | barely changed (§2) | no |
| Reactive-only, optimally dispatched | infeasible even at 60 kVA (§3) | **no** |
| **Active power circulation (OPF)** | driven to ≈ 0 (§4) | **yes** |

The lesson is not that a STATCOM is powerful — it is that *which* degree of freedom
you give it, and *how you dispatch it*, decides everything, and both questions are
optimisation questions. A power-flow simulation can score a fixed per-phase
``(P, Q)`` setpoint, but the setpoint that balances the feeder lives on a constraint
surface — the coupled DC-link balance ``\sum_k P_k = 0`` intersected with three
per-phase apparent-power circles — that no heuristic rule traces. Finding it is what
the OPF does, and it is the difference between a compensator that does almost nothing
and one that balances the feeder outright.

!!! tip "Where to go next"
    The [OPF model](opf.md#IBRs) gives the full IBR/STATCOM formulation, including the
    DC-link coupling and the `i_max` rolloff; [Case augmentation](augmentation.md)
    documents how [`add_statcom!`](@ref) and `augment_case` fill the dispatch box. The
    [SWER case study](tutorial_swer.md) makes the complementary point on a
    *single-phase* high-R/X feeder, where reactive support is likewise a limited lever.

## [References](@id refs-statcom)

1. D. Pullaguram, S. Mishra, N. Senroy, *Coordinated single-phase control scheme for
   voltage unbalance reduction in low voltage network*, Philosophical Transactions of
   the Royal Society A **375**(2100):20160308, 2017.
2. O. Rahman, D. Robinson, S. Elphick, *Mitigation of Solar PV Impact in Four-Wire LV
   Radial Distribution Feeders Through Reactive Power Management Using STATCOMs*,
   Electronics **14**(15):3063, 2025.
3. R. Heidari, F. Geth, *Improved Algebraic Inverter Modelling for Four-Wire Power
   Flow Optimization*, arXiv:2403.07285, 2024.
4. M. Deakin, R. Heidari, X. Deng, *Power Converter DC Link Ripple and Network
   Unbalance as Active Constraints in Distribution System Optimal Power Flow*,
   arXiv:2512.18293, 2025.
