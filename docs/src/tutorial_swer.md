# SWER case study: why optimisation matters

This case study follows one rural feeder — a **Single-Wire Earth-Return (SWER)**
line — to show *where optimisation earns its keep* in distribution planning. Every
code block runs when the docs are built, so the voltages below are real.

## What SWER is, and why it is hard

A SWER line carries single-phase power on **one conductor**, using the **earth
itself as the return path**. There is no second wire. A dedicated *isolating
transformer* taps the three-phase medium-voltage network and feeds the SWER line;
distribution transformers along the line step down to 230/240 V for customers, each
earthed so the load current returns through the ground. By halving the conductor
count and the pole hardware, SWER electrifies vast, sparsely populated areas at a
fraction of the cost of a two- or three-wire line. It is the backbone of rural
electrification in Australia, New Zealand, Brazil and southern Africa — **Ergon
Energy alone operates ~65,000 km of it in Queensland**, at 12.7 kV (off 22 kV
feeders) and 19.1 kV (off 33 kV).

The economy comes at a price: **voltage regulation**. A SWER line is long, lightly
built and high-impedance, so it sits on a knife-edge between two opposite failure
modes that the literature documents well:

- **Peak demand → undervoltage.** Rural load has grown far beyond the original
  design — air-conditioning, variable-speed-drive motors, irrigation pumps — and
  the voltage drop along a high-impedance single conductor with an earth return is
  severe (Sultan & Hawkins, *Rural SWER networks — associated problems and
  cost-effective solutions*, IJEPES 2011).
- **Light load + rooftop PV → overvoltage.** Modern rural customers export solar.
  Reverse power flow on the same high-impedance line, plus the light-load
  line-charging rise, pushes the far end *above* its limit (the North Jericho SWER
  study, *Capacity improvements for rural SWER systems*, IEEE).

Because **voltage regulation is the capacity-limiting factor**, the cheapest way to
carry more load or host more PV is not a bigger conductor — it is *better voltage
control*. The North Jericho study found that replacing **fixed** shunt reactors with
**controllable** ones raised feeder capacity by ~85 %. That is the thread this case
study pulls on: a single fixed setting cannot serve both failure modes, but an
optimiser dispatching a controllable device per operating point can.

!!! note "Modelling SWER faithfully"
    BMOPF models the earth return as a solidly-grounded bus neutral, so a SWER line
    is a single phase conductor whose linecode impedance carries the loop. The
    split-phase (centre-tapped) distribution transformer and the phase-to-phase
    isolating transformer both need care — see the
    [end-to-end tutorial](tutorial_end_to_end.md) for the general pipeline and
    [Validating the OPF](validation.md) for the OpenDSS cross-checks.

## 1. Load and diagnose

The case ships with the package: a Queensland-style isolated-SWER feeder — a 22 kV
three-phase source, a phase-to-phase isolating transformer to a 12.7 kV single-wire
backbone, a single-ended distribution transformer (`dx1` → `lv_1`) and a split-phase
centre-tapped one (`dx2` → `lv_2`).

```@example swer
using BMOPFTools

dss = joinpath(pkgdir(BMOPFTools), "test", "data", "SWER", "Master.dss")
net = from_dss(dss)

report = analyze(net)
println("SWER zones         : ", report.results[:connectivity]["n_swer_zones"])
println("split-phase zones  : ", report.results[:connectivity]["n_split_phase_zones"])
println("lv_1 nominal (V)   : ",
        round(report.results[:voltage_levels]["bus_voltage_map"]["lv_1"], digits=1))
```

[`analyze`](@ref) recognises the topology directly: the single-wire,
transformer-isolated sections are flagged `I.PROV.SWER_ZONE`, and the
centre-tap-fed section as split-phase.

```@example swer
for f in report.findings
    f.code in ("I.PROV.SWER_ZONE", "I.PROV.SPLIT_PHASE_ZONE") &&
        println(f.code, " — ", f.message)
end
```

## 2. Stress it into a realistic feeder

The committed fixture is a deliberately small canonical case (it is also a unit-test
network). Real SWER lines run *tens of kilometres* on a high-resistance conductor and
carry an aggregated peak up to the isolating-transformer rating. We stretch the
backbone to ~96 km and use a realistic 2.5 Ω/km conductor — plain edits to the
network dictionary, which doubles as a tour of the data model.

```@example swer
for (_, l) in net["line"]; l["length"] *= 8.0; end       # 12 km → 96 km
net["linecode"]["swer"]["R_series_1_1"] = 2.5 / 1000      # Ω/m

println("backbone length (km): ", sum(l["length"] for l in values(net["line"]))/1000)
```

The LV taps must stay inside the **AS/NZS 4777.2** connection window (230 V nominal,
−6 %/+10 % → **216.2–253 V**); we hold the 12.7 kV backbone to ±10 %.
([`augment_case`](@ref) now derives equivalent phase-to-earth bounds automatically —
the SWER √3 snap is fixed — but we set the regulatory PV limits explicitly so the
violations are unambiguous.)

```@example swer
function set_limits!(n)
    for b in ("lv_1", "lv_2")
        nph = count(t -> t != "n", n["bus"][b]["terminal_names"])
        n["bus"][b]["vpn_min"] = fill(216.2, nph)
        n["bus"][b]["vpn_max"] = fill(253.0, nph)
    end
    for b in ("swer_0", "swer_1", "swer_2")
        n["bus"][b]["v_min"] = [11430.0]; n["bus"][b]["v_max"] = [13970.0]
    end
    n
end
nothing # hide
```

Helpers for the operating points and the two candidate devices. The **fixed reactor**
is a constant inductive shunt (no decision variable); the **controllable compensator**
is an inverter with `p ≈ 0` and reactive power free in a band, which the OPF
dispatches (STATCOM-like). Both sit at the SWER end, `swer_2` — the classic location
for a SWER line reactor.

```@example swer
using JuMP, Ipopt
const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

vpn(res, bid, ph) = (b = res["bus"][bid];
    abs((b[ph]["vr"] + im*b[ph]["vi"]) -
        (haskey(b, "n") ? b["n"]["vr"] + im*b["n"]["vi"] : 0.0 + 0im)))

scale(K)   = (n = deepcopy(net); for (_, ld) in n["load"]
    ld["p_nom"] = ld["p_nom"].*K; ld["q_nom"] = get(ld,"q_nom",[0.0]).*K; end; n)
add_pv!(n, kw) = (n["inverter"] = get(n, "inverter", Dict{String,Any}());
    n["inverter"]["pv"] = Dict{String,Any}("bus"=>"lv_1", "terminal_map"=>["a","n"],
        "topology"=>"SINGLE_PHASE", "s_max"=>[kw*1100.0], "p_min"=>[kw*1000.0],
        "p_max"=>[kw*1000.0], "q_min"=>[0.0], "q_max"=>[0.0],
        "p_avail"=>[kw*1000.0], "prime_mover"=>"PV"); n)
add_reactor!(n, kvar) = (n["shunt"] = get(n, "shunt", Dict{String,Any}());
    n["shunt"]["reac"] = Dict{String,Any}("bus"=>"swer_2", "terminal_map"=>["a"],
        "B_1_1" => -kvar*1000.0 / 12700.0^2); n)
add_comp!(n, kvar) = (n["inverter"] = get(n, "inverter", Dict{String,Any}());
    n["inverter"]["comp"] = Dict{String,Any}("bus"=>"swer_2", "terminal_map"=>["a","n"],
        "topology"=>"SINGLE_PHASE", "s_max"=>[kvar*1000.0], "p_min"=>[0.0],
        "p_max"=>[0.0], "q_min"=>[-kvar*1000.0], "q_max"=>[kvar*1000.0],
        "p_avail"=>[0.0]); n)

Vpf(n)  = vpn(solve_pf(n; optimizer=OPT, per_unit=true), "lv_1", "a")
function Vopf(n)
    r = solve_opf(set_limits!(n); optimizer=OPT, per_unit=true)
    vpn(r, "lv_1", "a"), r["inverter"]["comp"]["a"]["qg"]/1000
end
nothing # hide
```

## 3. The two failure modes

A determined power flow ([`solve_pf`](@ref)) at each operating point shows the
feeder fall out of the AS/NZS window at *both* ends of its operating range.

```@example swer
println("PEAK demand          lv_1 = ", round(Vpf(scale(12.0)), digits=1),
        " V   (< 216.2  → UNDERVOLTAGE)")
println("LIGHT load + 55 kW PV  lv_1 = ", round(Vpf(add_pv!(scale(2.0), 55.0)), digits=1),
        " V   (> 253    → OVERVOLTAGE)")
```

## 4. A fixed reactor cannot serve both

A fixed shunt reactor sized to cure the light-load PV overvoltage *absorbs reactive
power all the time* — so at peak demand it **deepens** the undervoltage. This is the
exact mechanism the North Jericho study gives for why fixed reactors cap SWER
capacity.

```@example swer
println("PEAK  + fixed 120 kVAr reactor  lv_1 = ",
        round(Vpf(add_reactor!(scale(12.0), 120.0)), digits=1), " V   (WORSE)")
println("PV    + fixed 120 kVAr reactor  lv_1 = ",
        round(Vpf(add_reactor!(add_pv!(scale(2.0), 55.0), 120.0)), digits=1), " V   (better)")
```

## 5. One controllable compensator, optimally dispatched

Replace the fixed reactor with a **controllable** compensator and let
[`solve_opf`](@ref) choose its reactive output subject to the voltage limits. The
*same device* now **injects** vars at peak and **absorbs** vars under PV — the degree
of freedom that a fixed setting lacks.

```@example swer
vp, qp = Vopf(add_comp!(scale(12.0), 180.0))
vl, ql = Vopf(add_comp!(add_pv!(scale(2.0), 55.0), 180.0))

println("PEAK  + compensator  lv_1 = ", round(vp, digits=1),
        " V   (OPF injects ", round(qp, digits=0), " kVAr)")
println("PV    + compensator  lv_1 = ", round(vl, digits=1),
        " V   (OPF absorbs ", round(ql, digits=0), " kVAr)")
```

Both operating points are now inside the AS/NZS window, served by one device, only
because the OPF dispatches it per operating point.

## Why optimisation matters

| Operating point | No control | Fixed 120 kVAr reactor | Controllable compensator (OPF) |
|---|---|---|---|
| Peak demand     | 214 V — under | **195 V — worse** | inject +130 kVAr → **231 V** ✓ |
| Light + 55 kW PV| 255 V — over  | 237 V ✓ | absorb −52 kVAr → **247 V** ✓ |

Voltage regulation is the SWER capacity limit, and no single static setting spans
the operating range — the optimiser's per-operating-point reactive dispatch is what
unlocks capacity (the controllable-reactor capacity gains of the North Jericho
study). On a high R/X SWER feeder reactive support is a *limited* lever, which is
itself worth seeing in the numbers; where it runs out, the same OPF machinery sizes
and dispatches real-power DERs and smart-inverter Volt-var.

!!! tip "Where to go next"
    The [DER placement tutorial](tutorial_ders.md) sites and sizes DERs and shows
    how the binding constraint flips; the [VVWO tutorial](tutorial_vvwo.md) puts
    **distributed** smart-inverter Volt-var/Volt-watt control *inside* the OPF, so
    every rooftop PV does autonomously what the lumped compensator did here. The
    runnable version of this page is
    [`examples/swer_tutorial.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/swer_tutorial.jl).
