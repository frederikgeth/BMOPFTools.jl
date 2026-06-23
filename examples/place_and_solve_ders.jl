"""
    place_and_solve_ders.jl  —  Siting DERs and reading the *binding constraint*

Hosting-capacity and DER-coordination studies live or die on one question: *when
the cheap distributed generation wants to run, which network constraint stops
it?* A power-flow tool can only report a violation after the fact; an optimal
power flow (OPF) answers the question directly — it dispatches the DERs against
the network physics and the operating envelope at once, and the **active
constraint set** of the solution *is* the hosting-capacity answer.

This tutorial builds that OPF from a raw LV feeder with the library's
**recipe-driven DER placement** (`add_inverters` / `add_generators`) feeding the
`augment_case` → `solve_opf` pipeline, then runs three scenarios on the *same*
feeder and DER fleet that each make a **different constraint bind**:

  A.  Cheap DERs, no network limit   → pure merit order; only the imposed
                                       generation bounds bind and the surplus is
                                       exported (the economic baseline).
  B.  Healthy cable, head run high    → the EN 50160 voltage ceiling binds; the
                                       inverter `P²+Q²≤s_max²` circle does real
                                       work, absorbing Q for voltage support at
                                       the cost of active export.
  C.  Same case, a thin/derated cable → the IEC 60228 thermal limit binds
                                       *instead*; the dearer generator is shed
                                       first and a different dispatch results.

The thesis for an optimisation-modeling audience: the objective value is not the
story — the *binding constraint* is. B and C share a feeder, a DER fleet, an
operating point, and a limit set; they differ by a single knob (the service-cable
ampacity), yet the active constraint — and with it the optimal dispatch — flips
from voltage to thermal. The appendix sweeps that knob to trace the
hosting-capacity curve and the crossover where one constraint hands off to the
other.

The framing follows the network-aware curtailment / dynamic-hosting-capacity view
of Badmus & Pandey, *"ANOCA: AC Network-aware Optimal Curtailment Approach for
Dynamic Hosting Capacity"* (IEEE CDC 2024), built on the four-wire IVR-EN model
of Deakin, Pandey & Geth (IEEE Task Force, draft V0.2, 2026). See
[Positioning & ecosystem](../docs/src/positioning.md) for where this sits.

The pipeline order is the one the library is designed around:
    fix_case → add_inverters / add_generators → augment_case → solve_opf
(`fix_case` is omitted — the feeder is already clean.)

Run from the repository root using the test environment (JuMP + Ipopt):
    julia --project=test examples/place_and_solve_ders.jl
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "test"))

using BMOPFTools
using JuMP, Ipopt
using Printf

sep(t) = println("\n", "─"^74, "\n  ", t, "\n", "─"^74)

# ── Modelling constants ───────────────────────────────────────────────────────
const INPUT_JSON = joinpath(@__DIR__, "lv1_14bus.json")

const LV_LN_V    = 230.0                 # LV phase-to-neutral nominal we report in
const HEAD_SCALE = LV_LN_V / (433.0 / sqrt(3))  # rescale the 433 V feeder head to a
                                                #   230 V base (so 1.0 pu = 230 V)
const VPN_MAX_PU = 1.10                  # EN 50160 phase-to-neutral ceiling
const VPN_MIN_PU = 0.90

const HEAD_BASE  = 1.00      # nominal head (scenario A)
const HEAD_HIGH  = 1.05      # head tapped high — the classic over-voltage driver
const DROP_M     = 30.0      # service-cable length (m); the raw ~6 m drops are too
                             #   short to develop a realistic LV rise
const IMAX_THIN  = 90.0      # A — ampacity of a thin/derated 16 mm² service cable
                             #   (scenario C); the healthy cable (B) keeps its rating

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0,
                                      "max_iter" => 2000)

# ── Recipes (the showcase): where, how big, how priced — declared, not hand-fed ─
# A load-following InverterRecipe drops one PV inverter on each load bus; a thinner
# GeneratorRecipe co-locates a dispatchable generator there too. Both are priced
# below the slack, giving the OPF a layered merit order:
#   cheap PV inverter → mid-priced generator → expensive slack import.
const INV_RECIPE = InverterRecipe(
    strategy         = :load_following,   # one inverter per load bus
    s_fraction       = 5.0,               # s_max = 5.0 × local load (≈ 50 kVA cluster)
    s_to_p_ratio     = 0.90,              # p_avail = 0.9 × s_max — leaves VA headroom
                                          #   so the s_max circle and the EN 50549-1
                                          #   Q box stay consistent
    cost_basis       = :uniform,
    der_cost_uniform = 0.2,               # cheaper than the slack (priced 1.0)
)
const GEN_RECIPE = GeneratorRecipe(
    strategy         = :load_following,
    der_p_fraction   = 0.5,               # p_max = 0.5 × local load (≈ 5 kW)
    cost_basis       = :uniform,
    der_cost_uniform = 0.3,               # dearer than PV, cheaper than slack
)

# ── Base network: load, retap the head, set the drops, place the DERs ──────────
# The two single-phase loads sit on phase 1 (bus b3230) and phase 2 (bus b2656);
# `add_inverters`/`add_generators` co-locate a PV cluster and a generator at each,
# so the export is itself unbalanced — exactly where four-wire modelling (explicit
# neutral, no Kron reduction) earns its keep.
const DROP_LINES = ("l_3726", "l_2126")

function base_net(; head_pu::Float64 = HEAD_BASE, drop_m::Float64 = DROP_M,
                    derate::Bool = false, imax::Float64 = IMAX_THIN,
                    place_inverters::Bool = true, place_generators::Bool = true)
    net = parse_bmopf(INPUT_JSON)
    # Start from a clean slate — place every DER from a recipe below.
    delete!(net, "inverter"); delete!(net, "generator")

    # Strip any source cost so augment_case prices the slack itself, and tap the
    # 11 kV source so the LV head sits at head_pu on a 230 V base.
    for (_, vs) in get(net, "voltage_source", Dict())
        delete!(vs, "cost")
        haskey(vs, "v_magnitude") &&
            (vs["v_magnitude"] = [HEAD_SCALE * head_pu * v for v in vs["v_magnitude"]])
    end

    for lid in DROP_LINES
        haskey(get(net, "line", Dict()), lid) || continue
        line = net["line"][lid]
        line["length"] = drop_m
        if derate
            # Give the drop a private, derated linecode: a realistic 16 mm² ampacity
            # and a negligible (zeroed) charging shunt, so the thermal limit is on
            # the conductor current alone — and only on the drops.
            lc = deepcopy(net["linecode"][line["linecode"]])
            for k in keys(lc)
                (startswith(k, "G_") || startswith(k, "B_")) && (lc[k] = 0.0)
            end
            lc["i_max"] = fill(imax, length(get(lc, "i_max", fill(imax, 4))))
            drop_lc = "service_drop_derated_$lid"
            net["linecode"][drop_lc] = lc
            line["linecode"] = drop_lc
        end
    end

    place_inverters  && ((net, _) = add_inverters(net;  recipe = INV_RECIPE))
    place_generators && ((net, _) = add_generators(net; recipe = GEN_RECIPE))
    return net
end

# Impose the EN 50160 phase-to-neutral envelope explicitly on every LV bus, on the
# 230 V base we report in (the feeder's own declared nominal differs, so we set the
# ceiling we mean rather than relying on augment's snapped value).
function set_vpn_limits!(net)
    src = first(values(net["voltage_source"]))["bus"]
    for b in keys(net["bus"])
        b == src && continue
        net["bus"][b]["vpn_max"] = fill(VPN_MAX_PU * LV_LN_V, 3)
        net["bus"][b]["vpn_min"] = fill(VPN_MIN_PU * LV_LN_V, 3)
    end
    return net
end

# ── Metrics ───────────────────────────────────────────────────────────────────
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

# Worst per-conductor thermal utilisation cm_fr / i_max over all lines, with the
# location. cm_fr is the total per-end current; i_max lives on the linecode,
# indexed by conductor position (the line's terminal_map_from order).
function max_thermal(net, res)
    worst = 0.0; loc = ("", "")
    for (lid, line) in get(net, "line", Dict())
        lc   = get(get(net, "linecode", Dict()), get(line, "linecode", ""), Dict())
        imax = get(lc, "i_max", nothing)
        imax isa AbstractVector || continue
        tmf   = string.(get(line, "terminal_map_from", String[]))
        cvals = get(get(res, "line", Dict()), lid, Dict())
        for (k, t) in enumerate(tmf)
            (haskey(cvals, t) && k <= length(imax)) || continue
            cm = get(cvals[t], "cm_fr", NaN)
            (isfinite(cm) && imax[k] > 0) || continue
            r = cm / Float64(imax[k])
            r > worst && (worst = r; loc = (lid, t))
        end
    end
    (worst, loc)
end

# ── Scenario runner ───────────────────────────────────────────────────────────
struct Outcome
    label    :: String
    status   :: String
    max_vpn  :: Float64
    thermal  :: Float64               # worst cm_fr / i_max
    binding  :: String                # headline active constraint
    p        :: Dict{String,Float64}  # DER id → kW
    q        :: Dict{String,Float64}  # DER id → kvar
    export_kw:: Float64
end

# Classify the headline binding constraint (active ≈ within 1 % of the bound).
function classify(max_vpn, thermal)
    v_act = max_vpn  >= 0.99 * VPN_MAX_PU
    t_act = thermal  >= 0.99
    v_act && t_act && return "voltage + thermal"
    t_act && return "thermal (i_max)"
    v_act && return "voltage (vpn_max)"
    return "generation bounds only"
end

function run_scenario(label, net, recipe)
    aug, _ = augment_case(net; recipe = recipe)
    res = solve_opf(aug; optimizer = OPT, per_unit = true)
    st  = res["termination_status"]
    if !(st in ("LOCALLY_SOLVED", "OPTIMAL"))
        return aug, res, Outcome(label, st, NaN, NaN, "—", Dict(), Dict(), NaN)
    end
    lv = lv_buses(aug)
    max_vpn = maximum(vpn_pu(res, b, t) for b in lv for t in ("1", "2", "3"))
    thermal, _ = max_thermal(aug, res)
    P = Dict{String,Float64}(); Q = Dict{String,Float64}()
    for kind in ("inverter", "generator")
        for (id, ph) in get(res, kind, Dict())
            P[id] = sum(v["pg"] for v in values(ph)) / 1000
            Q[id] = sum(v["qg"] for v in values(ph)) / 1000
        end
    end
    exp = -sum(v["ps"] for v in values(first(values(res["voltage_source"])))) / 1000
    return aug, res, Outcome(label, st, max_vpn, thermal,
                             classify(max_vpn, thermal), P, Q, exp)
end

function show_outcome(o::Outcome)
    println("  status            : ", o.status)
    o.status in ("LOCALLY_SOLVED", "OPTIMAL") || return
    @printf("  max V (φ-n)       : %.4f pu   (ceiling %.2f)\n", o.max_vpn, VPN_MAX_PU)
    @printf("  max thermal use   : %.0f %% of i_max\n", 100 * o.thermal)
    for id in sort(collect(keys(o.p)))
        @printf("  %-10s        : P = %6.2f kW   Q = %+6.2f kvar\n", id, o.p[id], o.q[id])
    end
    @printf("  net grid export   : %6.2f kW   (negative slack P)\n", o.export_kw)
    println("  → BINDING         : ", o.binding)
end

# Recipe presets. A leaves the network limits off (we never call set_vpn_limits!
# and the thermal pass is off). B and C impose the IEC 60228 thermal limit and we
# add the EN 50160 ceiling by hand (set_vpn_limits!); the tighter phase-to-phase
# and negative-sequence passes stay off so the single binding constraint in each
# scenario is unambiguous. Both still fill the inverter / generator P/Q boxes and
# price the slack — placement places, augment bounds.
const RECIPE_NOLIMITS = AugmentationRecipe(
    apply_vpn_bounds = false, apply_vpp_bounds = false,
    apply_vneg_bounds = false, apply_thermal = false)
const RECIPE_LIMITS = AugmentationRecipe(
    apply_vpn_bounds = false, apply_vpp_bounds = false,
    apply_vneg_bounds = false, apply_v_bounds = false)

# ── 1. Show the recipe-driven placement once (the unique library capability) ───
sep("1. Recipe-driven DER placement (add_inverters / add_generators)")
demo = base_net()
println("Placed DERs on the LV1_14bus feeder:")
for (iid, inv) in sort(collect(get(demo, "inverter", Dict())); by = first)
    @printf("  INV  %-10s bus=%-7s topo=%-12s s_max=%s VA\n",
            iid, inv["bus"], inv["topology"], string(inv["s_max"]))
end
for (gid, g) in sort(collect(get(demo, "generator", Dict())); by = first)
    @printf("  GEN  %-10s bus=%-7s cfg=%-12s p_max=%s W\n",
            gid, g["bus"], g["configuration"], string(g["p_max"]))
end

# ── 2. Scenario A — cheap DERs, no network limit binds ─────────────────────────
sep("A.  Cheap DERs, no network limit — the economic baseline")
_, _, A = run_scenario("A — no limits",
                       base_net(head_pu = HEAD_BASE), RECIPE_NOLIMITS)
show_outcome(A)
println("\n  → Every DER runs to its bound and the surplus is exported. The only")
println("    active constraints are the imposed generation limits — a pure merit")
println("    order (PV → generator → slack). The network is not yet in the way.")

# ── 3. Scenario B — head run high, healthy cable → voltage binds ───────────────
sep("B.  Head tapped to 1.05 pu, healthy cable → voltage ceiling binds")
_, _, B = run_scenario("B — voltage",
                       set_vpn_limits!(base_net(head_pu = HEAD_HIGH)), RECIPE_LIMITS)
show_outcome(B)
println("\n  → The EN 50160 ceiling binds. The inverters absorb reactive power")
println("    (negative Q, out to the s_max circle) for voltage support and curtail")
println("    active power; the dearer generator is shed first. One shot, no outer")
println("    control loop. P²+Q²≤s_max² trades active headroom for Q.")

# ── 4. Scenario C — same case, a thin cable → thermal binds instead ────────────
sep("C.  Same head and feeder, a thin/derated service cable → thermal binds")
_, _, C = run_scenario("C — thermal",
                       set_vpn_limits!(base_net(head_pu = HEAD_HIGH, derate = true)),
                       RECIPE_LIMITS)
show_outcome(C)
println("\n  → Same head, same DERs, same EN 50160 ceiling as B — only the cable")
println("    rating changed. The thin conductor now hits i_max while the voltage")
println("    is still slack: a DIFFERENT binding constraint, a DIFFERENT dispatch.")

# ── 5. Summary ─────────────────────────────────────────────────────────────────
sep("Summary — same feeder, one knob moves the binding constraint")
@printf("  %-14s %10s %12s %12s %12s   %s\n",
        "scenario", "max V(pu)", "thermal(%)", "export(kW)", "ΣP(kW)", "binding")
for o in (A, B, C)
    if o.status in ("LOCALLY_SOLVED", "OPTIMAL")
        @printf("  %-14s %10.4f %12.0f %12.1f %12.1f   %s\n", o.label, o.max_vpn,
                100 * o.thermal, o.export_kw, sum(values(o.p)), o.binding)
    else
        @printf("  %-14s %10s\n", o.label, o.status)
    end
end
println("""

  B and C differ by ONE knob — the service-cable ampacity — yet the ACTIVE
  CONSTRAINT flips from voltage to thermal, and with it which DER is curtailed and
  how. The binding constraint, not the objective value, is the modeling content.""")

# ── 6. Appendix — the hosting-capacity curve and the constraint crossover ──────
# Sweep the service-cable ampacity in the scenario-C setup. At a thin rating the
# thermal limit binds and export grows as the cable is uprated; past a crossover
# the EN 50160 voltage ceiling takes over and export plateaus — uprating copper
# no longer buys hosting capacity. This is exactly the network-aware
# hosting-capacity question ANOCA poses, read straight off the OPF's active set.
sep("Appendix.  Hosting-capacity curve: sweep the cable rating, watch the crossover")
@printf("  %8s %12s %12s   %s\n", "i_max(A)", "max V(pu)", "export(kW)", "binding")
for imax in (60.0, 90.0, 120.0, 160.0, 220.0, 600.0)
    _, _, o = run_scenario("imax=$imax",
        set_vpn_limits!(base_net(head_pu = HEAD_HIGH, derate = true, imax = imax)),
        RECIPE_LIMITS)
    @printf("  %8.0f %12.4f %12.1f   %s\n",
            imax, o.max_vpn, o.export_kw, o.binding)
end
println("""
  Read top-to-bottom: while the cable is thin the thermal limit binds and every
  extra amp of rating buys more export; once the voltage ceiling takes over,
  uprating the cable stops helping — the hosting capacity is now a voltage
  problem. The crossover is the moment the OPF's binding constraint changes.""")
