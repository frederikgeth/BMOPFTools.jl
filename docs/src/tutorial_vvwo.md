# Tutorial: Volt-VAr-Watt *optimisation*

Most introductions to Volt-var / Volt-watt (VV/VW) droop present it as a
**power-flow** feature: a smart inverter follows an AS/NZS 4777.2 droop curve,
and a simulator such as OpenDSS iterates an outer control loop until the inverter
set-points and the network voltages agree. That is *incremental* control — the
control law and the network are solved in alternation.

This tutorial shows the other half of the picture. The very same droop can be
written as **constraints inside an optimal power flow (OPF)** and solved
*simultaneously* with the four-wire network equations — *non-incremental*
control. Two things then become possible that a simulation-only tool cannot do:

1. the inverter set-points and voltages are found in **one consistent solve**, with
   no outer iteration to converge (or oscillate); and
2. you can add **hard limits** — a voltage ceiling, a neutral-rise cap, thermal
   ratings, an export envelope — that *reshape the optimal dispatch*.

The framing follows Mhanna, Geth, Quiertant & Mancarella, *"Volt-VAr-Watt
Optimization in Four-Wire Low-Voltage Networks: Exact Nonlinear Models and Smooth
Approximations"* (IEEE Trans. Power Systems, 2026). BMOPFTools encodes the
piecewise-linear droop with the paper's **softplus** (smooth-ReLU) surrogate so
that Ipopt differentiates it exactly — see [Optimal power flow](opf.md) for the
encoding details.

The complete, runnable script is
[`examples/vvwo_tutorial.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/vvwo_tutorial.jl):

```
julia --project=test examples/vvwo_tutorial.jl
```

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
  5.25 kVA rooftop inverters behind one pole-top).

Because the loads — and therefore the PV — sit on different phases, the export is
itself unbalanced, which is where four-wire modelling (explicit neutral, no Kron
reduction) earns its keep.

The objective minimises **priced grid import**, so with PV priced at zero the OPF
maximises export until a constraint stops it.

## Three scenarios

### A — unity power factor, no limits

PV runs at unity power factor and no network limits are imposed. The OPF simply
maximises export.

```julia
for (_, inv) in net["inverter"]
    inv["q_min"] = [0.0]; inv["q_max"] = [0.0]   # unity PF baseline
end
```

```
max V (φ-n) : 1.1139 pu        P_total = 90.0 kW   Q_total =  -0.0 kvar   export = 30.7 kW
```

The worst phase-to-neutral voltage is **1.114 pu**, well over the 1.10 pu limit.
A power-flow tool would report this over-voltage faithfully — and stop there.

### B — AS/NZS 4777.2 droop in the constraints

Now attach a (blank) Volt-var / Volt-watt control profile to each inverter and
let `augment_case` fill it from the "Australia A" preset:

```julia
net["control_profile"] = Dict("vvw" =>
    Dict("volt_var" => Dict{String,Any}(), "volt_watt" => Dict{String,Any}()))
for (_, inv) in net["inverter"]; inv["control_profile"] = "vvw"; end

cfg = deepcopy(BMOPFTools.load_config())
cfg["augment"]["smart_inverter"]["enabled"] = true     # fill from AS/NZS 4777.2 Aus A
```

```
max V (φ-n) : 1.1042 pu        P_total = 81.0 kW   Q_total = -38.9 kvar   export = 26.8 kW
```

The inverters now **absorb reactive power** (Volt-var) and **curtail active
power** (Volt-watt), pulling the voltage down — solved in *one shot* with the
network, no outer iteration. Note the voltage still sits at **1.104 pu**: the
4777.2 curve is a deadband droop, not a hard guarantee. That is exactly why the
next step matters.

### C — hard limits only an optimiser can enforce

Keep the droop, and add limits to the LV buses: a 1.10 pu phase-to-neutral
ceiling, a neutral-to-ground cap, and (via `augment_case`) thermal ratings.

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
once.

## Appendix: per-phase vs averaged voltage reference

A three-phase (`FOUR_LEG`) inverter can respond to **each phase's own** voltage
magnitude (`voltage_ref = "PER_PHASE"`, the default) or to the **mean** of the
three (`voltage_ref = "AVERAGE"`, like a single three-phase unit that regulates
on its average terminal voltage). On an unbalanced bus the two laws dispatch
reactive power very differently:

```
PER_PHASE   V(φ-n) = [1.073 1.109 1.104] pu   Q = [-2.28 -4.99 -4.61] kvar
AVERAGE     V(φ-n) = [1.065 1.119 1.106] pu   Q = [-4.10 -4.10 -4.10] kvar
```

With `PER_PHASE`, each phase reacts to its own voltage, so the lightly-loaded
high-voltage phase absorbs most and the heavily-loaded phase least. With
`AVERAGE`, every phase reacts to the common mean, giving balanced reactive
injection. The choice is set per inverter with the `voltage_ref` field.
