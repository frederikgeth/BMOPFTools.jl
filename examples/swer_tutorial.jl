# SWER case study — why optimisation matters on a single-wire earth-return feeder.
#
#   julia --project=test examples/swer_tutorial.jl
#
# Companion to docs/src/tutorial_swer.md. Both share the same arc:
#   load → diagnose → give an operating envelope → stress into two failure modes
#   → show a FIXED reactor cannot serve both → let the OPF dispatch a CONTROLLABLE
#   compensator that does.
#
# Background. Single-Wire Earth-Return (SWER) feeders carry single-phase power on
# one conductor, with the earth as the return. They electrify vast, sparse rural
# areas cheaply — Ergon Energy alone runs ~65,000 km in Queensland at 12.7/19.1 kV.
# The catch is voltage regulation: long, high-impedance lines sit on a knife-edge
# between PEAK-demand undervoltage (load growth — air-con, motors; Sultan & Hawkins,
# IJEPES 2011) and LIGHT-load / rooftop-PV OVERvoltage (reverse flow + line-charging
# rise; the North Jericho study, IEEE). Voltage regulation is the CAPACITY-limiting
# factor, which is exactly why making the compensation controllable unlocks capacity
# (controllable reactors gave ~85% more capacity at North Jericho). This script
# makes that concrete on the test/data/SWER feeder.

using BMOPFTools, JuMP, Ipopt

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
sep(t) = println("\n" * "="^72 * "\n  " * t * "\n" * "="^72)

# Phase-to-neutral magnitude at a bus terminal (the quantity AS/NZS limits bind).
vpn(res, bid, ph) = (b = res["bus"][bid];
    abs((b[ph]["vr"] + im*b[ph]["vi"]) -
        (haskey(b, "n") ? b["n"]["vr"] + im*b["n"]["vi"] : 0.0 + 0im)))

# ── 1. Load & diagnose ────────────────────────────────────────────────────────
sep("1. Load the isolated-SWER feeder and diagnose it")
dss = joinpath(pkgdir(BMOPFTools), "test", "data", "SWER", "Master.dss")
net = from_dss(dss)
report = analyze(net)
println("SWER zones        : ", report.results[:connectivity]["n_swer_zones"])
println("split-phase zones : ", report.results[:connectivity]["n_split_phase_zones"])
println("LV tap nominal    : ",
        round(report.results[:voltage_levels]["bus_voltage_map"]["lv_1"], digits=1), " V")
for f in report.findings
    f.code == "I.PROV.SWER_ZONE" && println("  ", f.code, " — ", f.message)
end

# ── 2. Stress it into a realistic long feeder ─────────────────────────────────
# The committed fixture is a deliberately tiny canonical case. Real SWER lines run
# tens of km on a high-resistance conductor and carry an aggregated peak. We stretch
# the backbone to ~96 km and use a realistic 2.5 Ω/km conductor — simple dict edits.
sep("2. Stress into a realistic 96 km / 2.5 Ω·km feeder")
for (_, l) in net["line"]; l["length"] *= 8.0; end          # 12 km → 96 km
net["linecode"]["swer"]["R_series_1_1"] = 2.5 / 1000        # Ω/m (realistic SWER)
println("backbone length   : ", sum(l["length"] for l in values(net["line"]))/1000, " km")

# AS/NZS 4777.2 connection limits at the LV taps (230 V nominal, −6 %/+10 %), and a
# ±10 % envelope on the 12.7 kV backbone. (augment_case now derives equivalent
# phase-to-earth bounds automatically — the √3 SWER snap is fixed — but we set the
# regulatory PV limits explicitly so the violations are unambiguous.)
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

# Operating-point and device builders (deep-copy so each scenario is independent).
peak(K=12.0)  = (n = deepcopy(net); for (_, ld) in n["load"]
    ld["p_nom"] = ld["p_nom"].*K; ld["q_nom"] = get(ld,"q_nom",[0.0]).*K; end; n)
light(K=2.0)  = (n = deepcopy(net); for (_, ld) in n["load"]
    ld["p_nom"] = ld["p_nom"].*K; ld["q_nom"] = get(ld,"q_nom",[0.0]).*K; end; n)
add_pv!(n, kw) = (n["ibr"] = get(n, "ibr", Dict{String,Any}());
    n["ibr"]["pv"] = Dict{String,Any}("bus"=>"lv_1", "terminal_map"=>["a","n"],
        "topology"=>"SINGLE_PHASE", "s_max"=>[kw*1100.0], "p_min"=>[kw*1000.0],
        "p_max"=>[kw*1000.0], "q_min"=>[0.0], "q_max"=>[0.0],
        "p_avail"=>[kw*1000.0], "prime_mover"=>"PV"); n)
# A FIXED shunt reactor (constant inductive susceptance — no decision variable).
add_reactor!(n, kvar) = (n["shunt"] = get(n, "shunt", Dict{String,Any}());
    n["shunt"]["reac"] = Dict{String,Any}("bus"=>"swer_2", "terminal_map"=>["a"],
        "B_1_1" => -kvar*1000.0 / 12700.0^2); n)
# A CONTROLLABLE reactive compensator: an IBR with p≈0 and Q free in ±kvar,
# which the OPF dispatches per operating point (STATCOM-like).
add_comp!(n, kvar) = (n["ibr"] = get(n, "ibr", Dict{String,Any}());
    n["ibr"]["comp"] = Dict{String,Any}("bus"=>"swer_2", "terminal_map"=>["a","n"],
        "topology"=>"SINGLE_PHASE", "s_max"=>[kvar*1000.0], "p_min"=>[0.0],
        "p_max"=>[0.0], "q_min"=>[-kvar*1000.0], "q_max"=>[kvar*1000.0],
        "p_avail"=>[0.0]); n)

V(n) = vpn(solve_pf(n; optimizer=OPT, per_unit=true), "lv_1", "a")          # power flow
function Vopf(n)                                                            # OPF dispatch
    r = solve_opf(set_limits!(n); optimizer=OPT, per_unit=true)
    vpn(r, "lv_1", "a"), r["ibr"]["comp"]["a"]["qg"]/1000
end

# ── 3. Two failure modes ──────────────────────────────────────────────────────
sep("3. The two failure modes (vs AS/NZS 216.2–253 V at the LV tap)")
println("PEAK demand        lv_1 = ", round(V(peak()),  digits=1), " V   (< 216.2 → UNDERVOLTAGE)")
println("LIGHT load + 55 kW lv_1 = ", round(V(add_pv!(light(), 55.0)), digits=1),
        " V   (> 253 → OVERVOLTAGE)")

# ── 4. A fixed reactor cannot serve both ──────────────────────────────────────
sep("4. A FIXED 120 kVAr reactor — fixes one mode, worsens the other")
println("PEAK   + fixed reactor   lv_1 = ", round(V(add_reactor!(peak(), 120.0)), digits=1),
        " V   (worse — reactor adds reactive burden at peak)")
println("PV     + fixed reactor   lv_1 = ", round(V(add_reactor!(add_pv!(light(), 55.0), 120.0)), digits=1),
        " V   (better — absorbs the PV rise)")

# ── 5. One controllable compensator, optimally dispatched, serves both ────────
sep("5. A CONTROLLABLE compensator — the OPF dispatches Q per operating point")
vp, qp = Vopf(add_comp!(peak(), 180.0))
vl, ql = Vopf(add_comp!(add_pv!(light(), 55.0), 180.0))
println("PEAK   + compensator     lv_1 = ", round(vp, digits=1), " V   (OPF injects ",
        round(qp, digits=0), " kVAr → within limits)")
println("PV     + compensator     lv_1 = ", round(vl, digits=1), " V   (OPF absorbs ",
        round(ql, digits=0), " kVAr → within limits)")

sep("Takeaway")
println("""
A single FIXED reactive setting cannot span the operating range: sized for the
light-load PV overvoltage it deepens the peak-demand undervoltage. The OPF dispatches
ONE controllable compensator to inject at peak and absorb under PV — voltage
regulation is the SWER capacity limit, and per-operating-point optimal reactive
dispatch is what unlocks it. For distributed smart-IBR Volt-var that does this
autonomously at every PV, see the VVWO tutorial.""")
