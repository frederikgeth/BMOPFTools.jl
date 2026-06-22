"""
    vvwo_tutorial.jl  —  Volt-VAr-Watt **optimisation** on a four-wire LV feeder

Most people meet Volt-var / Volt-watt (VV/VW) droop inside a *power-flow* tool
(e.g. OpenDSS), where the inverter control is iterated to a fixed point *after*
each network solve. This example shows the other half of the story: the same
AS/NZS 4777.2 droop can live **inside the constraints of an optimal power flow
(OPF)**, solved *simultaneously* with the network equations — and, unlike a
simulation-only tool, an OPF can then enforce hard limits (a voltage ceiling, a
neutral-rise cap, thermal ratings) that *reshape the optimal dispatch*.

This "non-incremental" framing — embedding VV/VW directly into the unified
network model rather than iterating an outer control loop — follows
Mhanna, Geth, Quiertant & Mancarella, *"Volt-VAr-Watt Optimization in Four-Wire
Low-Voltage Networks: Exact Nonlinear Models and Smooth Approximations"*, IEEE
Trans. Power Systems, 2026. BMOPFTools uses the softplus (smooth-ReLU) encoding
of the droop curves described there.

We tell the story in three scenarios on the real `LV1_14bus` feeder, each pushing
PV export against an over-voltage problem:

  A.  PV at unity power factor, **no limits**        → voltage runs away (> 1.10 pu)
  B.  AS/NZS 4777.2 VV/VW droop in the constraints   → Q absorbed, P curtailed
  C.  B + a hard 1.10 pu voltage ceiling, neutral
      cap, and thermal limits                        → the OPF enforces the limit
                                                        the droop alone cannot

A short appendix contrasts a three-phase (`FOUR_LEG`) inverter's per-phase vs
phase-averaged voltage reference (`voltage_ref`).

Run from the repository root with the test environment (JuMP + Ipopt):
    julia --project=test examples/vvwo_tutorial.jl
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "test"))

using BMOPFTools
using JuMP, Ipopt
using Printf

sep(t) = println("\n", "─"^74, "\n  ", t, "\n", "─"^74)

# ── Modelling constants ───────────────────────────────────────────────────────
# AS/NZS 4777.2:2020 "Australia A" curves are injected by augment_case from the
# [augment.smart_inverter] config preset; we only need the nominal voltage here.
const LV_LN_V   = 230.0          # LV phase-to-neutral nominal (V)
const HEAD_PU   = 1.05           # feeder-head tap (utilities run the LV head high
                                 #   to cover downstream drop — the classic setup
                                 #   in which midday PV export then over-voltages)
const SERVICE_M = 30.0           # service-cable length (m) to the two PV/load
                                 #   buses. The dataset ships ~6 m drops, far too
                                 #   short to develop a realistic LV rise; 30 m is
                                 #   a representative residential service.
const PV_KVA    = 45_000.0       # PV nameplate per connection (VA). Read as an
                                 #   aggregated cluster — ≈ 8 of the study's
                                 #   5.25 kVA rooftop inverters behind one pole-top.
const VPN_MAX_PU = 1.10          # EN 50160 / AS 4777 phase-to-neutral ceiling
const VPN_MIN_PU = 0.90
const VN_MAX_PU  = 0.10          # neutral-to-ground cap (a four-wire-only limit)

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0,
                                      "max_iter" => 500)

const INPUT = joinpath(@__DIR__, "lv1_14bus.json")

# ── Base network: retap the head, lengthen the service drops, place the PV ─────
#
# The two single-phase loads sit on phase 1 (bus b3230) and phase 2 (bus b2656);
# we co-locate one single-phase PV cluster at each — so the PV export is itself
# unbalanced, which is exactly where four-wire modelling earns its keep.
function base_net()
    net = parse_bmopf(INPUT)

    vs = first(values(net["voltage_source"]))
    haskey(vs, "cost") || (vs["cost"] = fill(1.0, length(vs["v_magnitude"]) - 1))
    # The source sits on the 11 kV side; scale it so the LV head is HEAD_PU.
    f = LV_LN_V / (433.0 / sqrt(3))
    vs["v_magnitude"] = [f * HEAD_PU * v for v in vs["v_magnitude"]]

    net["line"]["l_3726"]["length"] = SERVICE_M   # drop to b3230
    net["line"]["l_2126"]["length"] = SERVICE_M   # drop to b2656

    net["inverter"] = Dict{String,Any}(
        "pv_a" => _pv("b3230", "1"),
        "pv_b" => _pv("b2656", "2"))
    return net
end

# A single-phase PV nameplate on `phase` of `bus`. p_avail = s_max so the unit is
# free to run to nameplate (curtailed only by Volt-watt or a hard limit); cost 0
# so the OPF maximises export (every exported W displaces priced grid import).
_pv(bus, phase) = Dict{String,Any}(
    "bus" => bus, "terminal_map" => [phase, "n"], "topology" => "SINGLE_PHASE",
    "prime_mover" => "PV", "s_max" => [PV_KVA], "p_avail" => PV_KVA,
    "p_max" => [PV_KVA], "p_min" => [0.0], "cost" => [0.0])

# LV buses = everything except the HV source bus (the cap/metric must not touch
# the 11 kV side).
function lv_buses(net)
    src = first(values(net["voltage_source"]))["bus"]
    return [b for b in keys(net["bus"]) if b != src]
end

# Phase-to-neutral magnitude (pu of LV_LN_V) at bus `b`, phase `t`.
function vpn_pu(res, b, t)
    ph = res["bus"][b]
    (haskey(ph, t) && haskey(get(ph, "n", Dict()), "vr")) || return 0.0
    n = ph["n"]
    return abs((ph[t]["vr"] - n["vr"]) + im * (ph[t]["vi"] - n["vi"])) / LV_LN_V
end

# Disable every augment_case bound pass; each scenario adds exactly the limits it
# wants. (apply_thermal is toggled on for scenario C.)
manual_recipe(; thermal=false) = AugmentationRecipe(
    apply_v_bounds=false, apply_vpn_bounds=false, apply_vpp_bounds=false,
    apply_vneg_bounds=false, apply_thermal=thermal, apply_q_bounds=false,
    apply_slack_generator=false, apply_inverter=false)

# Config with the AS/NZS 4777.2 "Australia A" smart-inverter preset enabled, so a
# blank volt_var/volt_watt sub-object gets filled with the regional curve.
function ausA_config()
    cfg = deepcopy(BMOPFTools.load_config())
    cfg["augment"]["smart_inverter"]["enabled"] = true
    cfg["augment"]["smart_inverter"]["region"]  = "Aus_A"
    return cfg
end

# Attach a (blank) VV/VW control profile to every inverter.
function attach_droop!(net)
    net["control_profile"] = Dict("vvw" =>
        Dict("volt_var" => Dict{String,Any}(), "volt_watt" => Dict{String,Any}()))
    for (_, inv) in net["inverter"]
        inv["control_profile"] = "vvw"
    end
    return net
end

# ── Scenario runner ───────────────────────────────────────────────────────────
struct Outcome
    label::String
    status::String
    max_vpn::Float64
    max_vn::Float64
    p::Dict{String,Float64}     # inverter id → kW
    q::Dict{String,Float64}     # inverter id → kvar
    export_kw::Float64
end

function run_scenario(label, net; config=BMOPFTools._DEFAULT_CONFIG, thermal=false)
    aug, _ = augment_case(net; config=config, recipe=manual_recipe(thermal=thermal))
    res = solve_opf(aug; optimizer=OPT, per_unit=true)
    st  = res["termination_status"]
    if !(st in ("LOCALLY_SOLVED", "OPTIMAL"))
        return Outcome(label, st, NaN, NaN, Dict(), Dict(), NaN)
    end
    lv = lv_buses(aug)
    max_vpn = maximum(vpn_pu(res, b, t) for b in lv for t in ("1", "2", "3"))
    max_vn  = maximum(abs(res["bus"][b]["n"]["vr"] + im*res["bus"][b]["n"]["vi"])
                      for b in lv if haskey(res["bus"][b], "n")) / LV_LN_V
    P = Dict(id => sum(v["pg"] for v in values(ph))/1000 for (id, ph) in res["inverter"])
    Q = Dict(id => sum(v["qg"] for v in values(ph))/1000 for (id, ph) in res["inverter"])
    exp = -sum(v["ps"] for v in values(first(values(res["voltage_source"]))))/1000
    return Outcome(label, st, max_vpn, max_vn, P, Q, exp)
end

function show_outcome(o::Outcome)
    println("  status            : ", o.status)
    o.status in ("LOCALLY_SOLVED", "OPTIMAL") || return
    @printf("  max V (φ-n)       : %.4f pu   (limit %.2f)\n", o.max_vpn, VPN_MAX_PU)
    @printf("  max V neutral     : %.4f pu\n", o.max_vn)
    for id in sort(collect(keys(o.p)))
        @printf("  %-6s            : P = %5.1f kW   Q = %+6.1f kvar\n", id, o.p[id], o.q[id])
    end
    @printf("  net grid export   : %5.1f kW\n", o.export_kw)
end

# ── Scenario A: unity PF, no limits — the power-flow blind spot ────────────────
sep("A.  PV at unity power factor, no network limits")
netA = base_net()
for (_, inv) in netA["inverter"]               # pin Q = 0 (unity PF baseline)
    inv["q_min"] = [0.0]; inv["q_max"] = [0.0]
end
A = run_scenario("A — unity PF", netA)
show_outcome(A)
println("\n  → PV maxes out; the worst phase-to-neutral voltage exceeds 1.10 pu.")
println("    A power-flow tool would faithfully report this over-voltage — and stop there.")

# ── Scenario B: AS/NZS 4777.2 droop embedded in the OPF ────────────────────────
sep("B.  Volt-var / Volt-watt droop in the OPF constraints (AS/NZS 4777.2 Aus A)")
B = run_scenario("B — droop", attach_droop!(base_net()); config=ausA_config())
show_outcome(B)
println("\n  → Q is absorbed (Volt-var) and P curtailed (Volt-watt), pulling the voltage")
println("    down. Solved in ONE shot with the network — no outer control iteration.")
@printf("    Voltage still sits at %.4f pu: 4777.2 droop is a deadband response, not a\n", B.max_vpn)
println("    hard guarantee — exactly why a binding constraint is needed next.")

# ── Scenario C: hard limits only an optimiser can enforce ──────────────────────
sep("C.  Add a hard 1.10 pu ceiling, a neutral-rise cap, and thermal limits")
netC = attach_droop!(base_net())
for b in lv_buses(netC)
    netC["bus"][b]["vpn_max"] = fill(VPN_MAX_PU * LV_LN_V, 3)
    netC["bus"][b]["vpn_min"] = fill(VPN_MIN_PU * LV_LN_V, 3)
    netC["bus"][b]["vn_max"]  = VN_MAX_PU * LV_LN_V
end
C = run_scenario("C — droop + limits", netC; config=ausA_config(), thermal=true)
show_outcome(C)
println("\n  → The OPF co-optimises the droop AND the network limits: voltage is held at")
println("    exactly 1.10 pu by curtailing a little more PV. This binding constraint —")
println("    impossible in a simulation-only tool — is the whole point of an OPF.")

# ── Side-by-side summary ──────────────────────────────────────────────────────
sep("Summary")
@printf("  %-22s %10s %12s %12s %12s\n", "scenario", "max V(pu)", "P_total(kW)", "Q_total(kvar)", "export(kW)")
for o in (A, B, C)
    if o.status in ("LOCALLY_SOLVED", "OPTIMAL")
        @printf("  %-22s %10.4f %12.1f %12.1f %12.1f\n", o.label, o.max_vpn,
                sum(values(o.p)), sum(values(o.q)), o.export_kw)
    else
        @printf("  %-22s %10s\n", o.label, o.status)
    end
end
println("""

  Reading the table: the droop (B) trades export for voltage support relative to
  the naive maximum (A); the hard limit (C) trades a little more to *guarantee*
  the ceiling. Adding a binding constraint can only raise the objective (less
  export) — the signature of an optimisation that respects the physics and the
  operating envelope at once.""")

# ── Appendix: three-phase voltage reference (per-phase vs averaged) ────────────
# A FOUR_LEG inverter can respond to each phase's own magnitude (PER_PHASE) or to
# the mean of the three (AVERAGE, like a single 3φ unit). On an unbalanced bus the
# two laws dispatch reactive power very differently. We show it on a deliberately
# unbalanced minimal feeder so the contrast is unmistakable.
sep("Appendix.  FOUR_LEG voltage_ref: per-phase vs averaged")

function aside_net(vref)
    net = parse_bmopf("""
    {"bus":{
       "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
       "lb" :{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
         "v_magnitude":[245.0,245.0,245.0],"v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
     "linecode":{"lc":{"R_series_1_1":0.4,"R_series_2_2":0.4,"R_series_3_3":0.4,"R_series_4_4":0.4,
         "X_series_1_1":0.1,"X_series_2_2":0.1,"X_series_3_3":0.1,"X_series_4_4":0.1}},
     "line":{"l1":{"bus_from":"src","bus_to":"lb","linecode":"lc","length":1.0,
         "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"]}},
     "load":{"la":{"bus":"lb","terminal_map":["1","n"],"configuration":"WYE","p_nom":[8000.0],"q_nom":[0.0]},
             "lc":{"bus":"lb","terminal_map":["3","n"],"configuration":"WYE","p_nom":[2000.0],"q_nom":[0.0]}},
     "control_profile":{"vvw":{"volt_var":{},"volt_watt":{}}},
     "inverter":{"pv":{"bus":"lb","terminal_map":["1","2","3","n"],"topology":"FOUR_LEG",
         "prime_mover":"PV","voltage_ref":"$(vref)","s_max":[10000.0,10000.0,10000.0],
         "p_avail":30000.0,"p_max":[10000.0,10000.0,10000.0],"p_min":[0.0,0.0,0.0],
         "control_profile":"vvw","cost":[0.0,0.0,0.0]}}}
    """; from_string=true)
    return net
end

for vref in ("PER_PHASE", "AVERAGE")
    aug, _ = augment_case(aside_net(vref); config=ausA_config(), recipe=manual_recipe())
    res = solve_opf(aug; optimizer=OPT, per_unit=true)
    iv  = res["inverter"]["pv"]
    qs  = [sum(v["qg"] for (t, v) in iv if t == ph)/1000 for ph in ("1", "2", "3")]
    vs  = [vpn_pu(res, "lb", ph) for ph in ("1", "2", "3")]
    @printf("  %-10s  V(φ-n) = [%.3f %.3f %.3f] pu   Q = [%+.2f %+.2f %+.2f] kvar\n",
            vref, vs[1], vs[2], vs[3], qs[1], qs[2], qs[3])
end
println("""
  PER_PHASE: each phase reacts to its own voltage → unequal Q (the heavily loaded
             phase absorbs least, the lightly loaded/high-voltage phase most).
  AVERAGE  : every phase reacts to the mean magnitude → balanced Q, like a single
             three-phase inverter that regulates on its average terminal voltage.""")
