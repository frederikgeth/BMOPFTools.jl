# SWER case study: why optimisation matters

This case study follows one rural feeder — a **Single-Wire Earth-Return (SWER)**
line — to show *where optimisation earns its keep* in distribution planning. Every
code block runs when the docs are built, so the voltages below are real.

!!! note "Prerequisites"
    A Julia session with BMOPFTools plus **JuMP** and **Ipopt**
    (`using Pkg; Pkg.add(["JuMP", "Ipopt"])`), or `julia --project=docs` from a
    clone of the repository. Building this page runs six Ipopt solves (four
    power flows, two OPFs) — a few seconds on a laptop.

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
  Reverse power flow on the same high-impedance line pushes the far end *above*
  its limit (the North Jericho SWER study, *Capacity improvements for rural SWER
  systems*, IEEE). On real, very long SWER lines the light-load line-charging
  (Ferranti) rise adds to this; the fixture used below models no shunt
  capacitance, so the overvoltage demonstrated here is purely PV reverse flow.

Because **voltage regulation is the capacity-limiting factor**, the cheapest way to
carry more load or host more PV is not a bigger conductor — it is *better voltage
control*. The North Jericho study found that replacing **fixed** shunt reactors with
**controllable** ones raised feeder capacity by ~85 %. That is the thread this case
study pulls on: a single fixed setting cannot serve both failure modes, but an
optimiser dispatching a controllable device per operating point can.

!!! note "Modelling SWER faithfully"
    BMOPF models the earth return as a solidly-grounded bus neutral, so a SWER line
    is a single phase conductor whose linecode impedance carries the loop. The
    split-phase (centre-tapped) distribution transformer is modelled as a full
    coupled-coil 3-winding unit — the primitive admittance is reconstructed from the
    OpenDSS short-circuit set (`from_dss` recovers it via PowerIO's `pmd` export), so
    its two legs track OpenDSS even under heavy, unbalanced loading. See the
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

The LV taps must stay inside the Australian **AS 60038 / AS 61000.3.100**
supply-voltage range (230 V nominal, −6 %/+10 % → **216.2–253 V**) — the same
window that inverter standards such as AS/NZS 4777.2 key their responses off; we
hold the 12.7 kV backbone to ±10 %.

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

Next, the measurement helper and the operating points. `vpn` reads the
phase-to-neutral magnitude out of a solved result — the quantity the limits bind.
An operating point is just a scaled copy of the loads: the fixture ships **5 kW**
of canonical load, so `scale(12.0)` lifts it to a **60 kW aggregated peak**
approaching the 100 kVA isolating-transformer rating (real SWER peaks are
transformer-limited), and `scale(2.0)` is a **10 kW light-load trough**.

```@example swer
using JuMP, Ipopt, Printf
const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

# Phase-to-neutral voltage magnitude at bus `bid`, terminal `ph`, from a result.
vpn(res, bid, ph) = (b = res["bus"][bid];
    abs((b[ph]["vr"] + im*b[ph]["vi"]) -
        (haskey(b, "n") ? b["n"]["vr"] + im*b["n"]["vi"] : 0.0 + 0im)))

# Operating point = the fixture's loads scaled by K (deepcopy → scenarios stay independent).
scale(K) = (n = deepcopy(net); for (_, ld) in n["load"]
    ld["p_nom"] = ld["p_nom"].*K; ld["q_nom"] = get(ld,"q_nom",[0.0]).*K; end; n)
nothing # hide
```

The overvoltage driver is rooftop PV at the `lv_1` tap. **55 kW** — roughly a
dozen 5 kW rooftop systems behind one tap — pushes ~45 kW *back up* the line
against the 10 kW trough. The IBR dict pins the unit at full, unity-power-factor
output, so the power flow sees a fixed injection rather than a dispatchable
device:

```@example swer
function add_pv!(n, kw)
    n["ibr"] = get(n, "ibr", Dict{String,Any}())
    n["ibr"]["pv"] = Dict{String,Any}(
        "bus" => "lv_1", "terminal_map" => ["a","n"], "topology" => "SINGLE_PHASE",
        "prime_mover" => "PV",
        "s_max"   => [kw*1100.0],   # VA rating: 10 % headroom over P, typical sizing
        "p_min"   => [kw*1000.0],   # p_min = p_max pins P at full output —
        "p_max"   => [kw*1000.0],   #   a fixed injection, not a decision variable
        "q_min"   => [0.0],
        "q_max"   => [0.0],         # q pinned to 0: unity power factor
        "p_avail" => [kw*1000.0])   # irradiance-limited available power (= P here)
    return n
end
nothing # hide
```

Finally the two candidate devices. The **fixed reactor** is a constant inductive
shunt (no decision variable), at **120 kVAr** sized by trial so the light-load PV
overvoltage comes back inside 253 V. The **controllable compensator** is an IBR with
`p = 0` and reactive power free in a band, which the OPF dispatches
(STATCOM-like); its **180 kVAr** band gives headroom in *both* directions so the
voltage limits, not the device rating, are what bind. Both sit at the SWER end,
`swer_2` — the classic location for a SWER line reactor. `Vpf` solves a power
flow; `Vopf` solves an OPF and returns the voltage plus the compensator dispatch,
erroring readably if the solve fails.

```@example swer
add_reactor!(n, kvar) = (n["shunt"] = get(n, "shunt", Dict{String,Any}());
    n["shunt"]["reac"] = Dict{String,Any}("bus"=>"swer_2", "terminal_map"=>["a"],
        "B_1_1" => -kvar*1000.0 / 12700.0^2); n)   # fixed inductive susceptance (S)
add_comp!(n, kvar) = (n["ibr"] = get(n, "ibr", Dict{String,Any}());
    n["ibr"]["comp"] = Dict{String,Any}("bus"=>"swer_2", "terminal_map"=>["a","n"],
        "topology"=>"SINGLE_PHASE", "s_max"=>[kvar*1000.0], "p_min"=>[0.0],
        "p_max"=>[0.0], "q_min"=>[-kvar*1000.0], "q_max"=>[kvar*1000.0],
        "p_avail"=>[0.0]); n)

Vpf(n)  = vpn(solve_pf(n; optimizer=OPT, per_unit=true), "lv_1", "a")
function Vopf(n)
    r = solve_opf(set_limits!(n); optimizer=OPT, per_unit=true)
    st = r["termination_status"]
    st in ("LOCALLY_SOLVED", "OPTIMAL") || error("OPF did not solve: status = ", st)
    vpn(r, "lv_1", "a"), r["ibr"]["comp"]["a"]["qg"]/1000
end
nothing # hide
```

## 3. The two failure modes

A determined power flow ([`solve_pf`](@ref)) at each operating point shows the
feeder fall out of the AS 60038 supply-voltage window at *both* ends of its
operating range.

```@example swer
v_peak_nc = Vpf(scale(12.0))
v_pv_nc   = Vpf(add_pv!(scale(2.0), 55.0))

println("PEAK demand            lv_1 = ", round(v_peak_nc, digits=1),
        " V   (< 216.2  → UNDERVOLTAGE)")
println("LIGHT load + 55 kW PV  lv_1 = ", round(v_pv_nc, digits=1),
        " V   (> 253    → OVERVOLTAGE)")
```

## 4. A fixed reactor cannot serve both

A fixed shunt reactor sized to cure the light-load PV overvoltage *absorbs reactive
power all the time* — so at peak demand it **deepens** the undervoltage. This is the
exact mechanism the North Jericho study gives for why fixed reactors cap SWER
capacity.

```@example swer
v_peak_fr = Vpf(add_reactor!(scale(12.0), 120.0))
v_pv_fr   = Vpf(add_reactor!(add_pv!(scale(2.0), 55.0), 120.0))

println("PEAK  + fixed 120 kVAr reactor  lv_1 = ", round(v_peak_fr, digits=1), " V   (WORSE)")
println("PV    + fixed 120 kVAr reactor  lv_1 = ", round(v_pv_fr, digits=1), " V   (better)")
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

Both operating points are now inside the AS 60038 window, served by one device, only
because the OPF dispatches it per operating point.

## Why optimisation matters

The table is computed from the results above — the same live numbers, side by side:

```@example swer
@printf("%-18s | %-14s | %-20s | %s\n",
        "operating point", "no control", "fixed 120 kVAr", "compensator (OPF)")
println("-"^85)
@printf("%-18s | %6.1f V under | %6.1f V worse      | %6.1f V ok  (%+.0f kVAr)\n",
        "peak demand", v_peak_nc, v_peak_fr, vp, qp)
@printf("%-18s | %6.1f V over  | %6.1f V ok         | %6.1f V ok  (%+.0f kVAr)\n",
        "light + 55 kW PV", v_pv_nc, v_pv_fr, vl, ql)
```

Voltage regulation is the SWER capacity limit, and no single static setting spans
the operating range — the optimiser's per-operating-point reactive dispatch is what
unlocks capacity (the controllable-reactor capacity gains of the North Jericho
study). On a high R/X SWER feeder reactive support is a *limited* lever, which is
itself worth seeing in the numbers; where it runs out, the same OPF machinery sizes
and dispatches real-power DERs and smart-IBR Volt-var.

!!! tip "Where to go next"
    The [DER placement tutorial](tutorial_ders.md) sites and sizes DERs and shows
    how the binding constraint flips; the [VVWO tutorial](tutorial_vvwo.md) puts
    **distributed** smart-IBR Volt-var/Volt-watt control *inside* the OPF, so
    every rooftop PV does autonomously what the lumped compensator did here. The
    runnable version of this page is
    [`examples/swer_tutorial.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/swer_tutorial.jl).
