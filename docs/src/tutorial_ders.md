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
**recipe-driven DER placement** (`add_ibrs` / `add_generators`), then runs
three scenarios on the *same* feeder and DER fleet that each make a **different
constraint bind**. The throughline:

> B and C share a feeder, a DER fleet, an operating point, and a limit set. They
> differ by a single knob — the service-cable ampacity — yet the active constraint
> flips from **voltage** to **thermal**, and the optimal dispatch flips with it.

The framing follows the network-aware curtailment / dynamic-hosting-capacity view
of Badmus & Pandey [[1]](@ref refs-ders), on the four-wire IVR-EN model of Deakin,
Pandey & Geth [[2]](@ref refs-ders); see also [Positioning & ecosystem](positioning.md)
for where BMOPFTools sits relative to the wider distribution-OPF ecosystem.

!!! note "Prerequisites"
    Read the [end-to-end tutorial](tutorial_end_to_end.md) first — it introduces
    the `load → analyze → fix → place → augment → solve` pipeline this page
    builds on. You need **JuMP** and **Ipopt** alongside BMOPFTools
    (`using Pkg; Pkg.add(["JuMP", "Ipopt"])`), or use the repository's docs
    environment (`julia --project=docs`). Every code block on this page is
    **executed when the documentation is built**, so the dispatches and binding
    constraints below are computed, not transcribed.

The complete, standalone script is
[`examples/place_and_solve_ders.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/place_and_solve_ders.jl):

```
julia --project=test examples/place_and_solve_ders.jl
```

## The setup

We use the real `LV1_14bus` feeder (11 kV / 433 V, two single-phase customers on
phases 1 and 2), loaded from its BMOPF JSON export with [`parse_bmopf`](@ref).

!!! note "Terminal names differ from the from_dss path"
    This case comes from a BMOPF JSON file whose phase terminals are numbered
    `"1"`, `"2"`, `"3"`; the `from_dss` path used in the end-to-end tutorial
    labels the same feeder's terminals `"a"`, `"b"`, `"c"`. Same physics,
    different label convention — see the
    [terminals primer](terminals_primer.md).

Instead of hand-writing each DER, we **declare** them with a recipe and let the
library choose buses from the network's own semantics and record every field it
writes:

```@example ders
using BMOPFTools

IBR_RECIPE = IBRRecipe(
    strategy = :load_following,   # one PV IBR per load bus
    s_fraction = 5.0,             # s_max = 5.0 × local load  (≈ 50 kVA cluster)
    s_to_p_ratio = 0.90,          # p_avail = 0.9 × s_max — leaves VA headroom
    cost_basis = :uniform, der_cost_uniform = 0.2)   # cheaper than the slack (1.0)

GEN_RECIPE = GeneratorRecipe(
    strategy = :load_following,
    der_p_fraction = 0.5,         # p_max = 0.5 × local load  (≈ 5 kW)
    cost_basis = :uniform, der_cost_uniform = 0.3)   # dearer than PV, cheaper than slack
nothing # hide
```

The scenarios need a little network surgery before placement, so we wrap the
whole preparation in one function: load the JSON, strip the pre-existing DERs
(we place every DER from the recipes), tap the 11 kV source so the LV head sits
at `head_pu` on a 230 V base, stretch the two service drops to a realistic 30 m
(the raw ~6 m drops are too short to develop an LV voltage rise), and — for
scenario C — swap the drops onto a derated 16 mm² linecode:

```@example ders
const LV_LN_V    = 230.0                        # phase-to-neutral base we report in
const HEAD_SCALE = LV_LN_V / (433.0 / sqrt(3))  # 433 V feeder head → 230 V base
const DROP_LINES = ("l_3726", "l_2126")         # the two service drops

function base_net(; head_pu = 1.0, drop_m = 30.0, derate = false, imax = 90.0)
    net = parse_bmopf(joinpath(pkgdir(BMOPFTools), "examples", "lv1_14bus.json"))
    delete!(net, "ibr"); delete!(net, "generator")   # clean slate: recipes place all DERs

    # Strip any source cost so augment_case prices the slack itself, and retap the head.
    for (_, vs) in net["voltage_source"]
        delete!(vs, "cost")
        vs["v_magnitude"] = [HEAD_SCALE * head_pu * v for v in vs["v_magnitude"]]
    end

    for lid in DROP_LINES
        line = net["line"][lid]
        line["length"] = drop_m
        if derate   # scenario C: a private, derated linecode on the drops only
            lc = deepcopy(net["linecode"][line["linecode"]])
            for k in keys(lc)   # zero the charging shunt: thermal limit on conductor current alone
                (startswith(k, "G_") || startswith(k, "B_")) && (lc[k] = 0.0)
            end
            lc["i_max"] = fill(imax, length(lc["i_max"]))
            net["linecode"]["derated_$lid"] = lc
            line["linecode"] = "derated_$lid"
        end
    end

    net, _ = add_ibrs(net; recipe = IBR_RECIPE)
    net, _ = add_generators(net; recipe = GEN_RECIPE)
    return net
end

lv_buses(net) = [b for b in keys(net["bus"])
                 if b != first(values(net["voltage_source"]))["bus"]]

# EN 50160 phase-to-neutral envelope, imposed explicitly on every LV bus on the
# 230 V base (so we control exactly the limit we mean).
function set_vpn_limits!(net)
    for b in lv_buses(net)
        net["bus"][b]["vpn_max"] = fill(1.10 * LV_LN_V, 3)
        net["bus"][b]["vpn_min"] = fill(0.90 * LV_LN_V, 3)
    end
    return net
end
nothing # hide
```

`augment_case` then fills the standards-grounded gaps: the IBR `P²+Q²≤s_max²`
circle and its EN 50549-1 reactive box, the generator reactive limits, the
IEC 60228 thermal limit, and a per-phase slack price. Two
[`AugmentationRecipe`](@ref) presets implement "no network limit" (scenario A)
versus "network limits on" (B and C) — A skips the voltage *and* thermal
passes, while B/C keep the thermal pass and get their voltage ceiling from
`set_vpn_limits!` above:

```@example ders
RECIPE_NOLIMITS = AugmentationRecipe(          # scenario A
    apply_vpn_bounds = false, apply_vpp_bounds = false,
    apply_vneg_bounds = false, apply_thermal = false)
RECIPE_LIMITS   = AugmentationRecipe(          # scenarios B and C
    apply_vpn_bounds = false, apply_vpp_bounds = false,
    apply_vneg_bounds = false, apply_v_bounds = false)
nothing # hide
```

```@setup ders
# Metric and reporting helpers — identical to examples/place_and_solve_ders.jl
# (see that script for the commented versions): vpn_pu reads the phase-to-neutral
# magnitude, max_thermal the worst cm_fr/i_max utilisation, classify names the
# headline active constraint, and run_scenario/show_outcome wrap
# augment_case → solve_opf → report.
using JuMP, Ipopt, Printf

const OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0,
                                      "max_iter" => 2000)
const VPN_MAX_PU = 1.10

function vpn_pu(res, b, t)
    ph = res["bus"][b]
    (haskey(ph, t) && haskey(get(ph, "n", Dict()), "vr")) || return 0.0
    n = ph["n"]
    return abs((ph[t]["vr"] - n["vr"]) + im * (ph[t]["vi"] - n["vi"])) / LV_LN_V
end

function max_thermal(net, res)
    worst = 0.0
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
            worst = max(worst, cm / Float64(imax[k]))
        end
    end
    worst
end

function classify(max_vpn, thermal)
    v_act = max_vpn >= 0.99 * VPN_MAX_PU
    t_act = thermal >= 0.99
    v_act && t_act && return "voltage + thermal"
    t_act && return "thermal (i_max)"
    v_act && return "voltage (vpn_max)"
    return "generation bounds only"
end

function run_scenario(net, recipe)
    aug, _ = augment_case(net; recipe = recipe)
    res = solve_opf(aug; optimizer = OPT, per_unit = true)
    max_vpn = maximum(vpn_pu(res, b, t) for b in lv_buses(aug) for t in ("1", "2", "3"))
    thermal = max_thermal(aug, res)
    P = Dict{String,Float64}(); Q = Dict{String,Float64}()
    for kind in ("ibr", "generator"), (id, ph) in get(res, kind, Dict())
        P[id] = sum(v["pg"] for v in values(ph)) / 1000
        Q[id] = sum(v["qg"] for v in values(ph)) / 1000
    end
    exp_kw = -sum(v["ps"] for v in values(first(values(res["voltage_source"])))) / 1000
    return (; status = res["termination_status"], max_vpn, thermal,
              binding = classify(max_vpn, thermal), P, Q, export_kw = exp_kw)
end

function show_outcome(o)
    @printf("  status          : %s\n", o.status)
    @printf("  max V (φ-n)     : %.4f pu   (ceiling %.2f)\n", o.max_vpn, VPN_MAX_PU)
    @printf("  max thermal use : %.0f %% of i_max\n", 100 * o.thermal)
    for id in sort(collect(keys(o.P)))
        @printf("  %-10s      : P = %6.2f kW   Q = %+6.2f kvar\n", id, o.P[id], o.Q[id])
    end
    @printf("  net grid export : %6.2f kW   (negative slack P)\n", o.export_kw)
    println("  → BINDING       : ", o.binding)
end
```

The metric helpers (worst phase-to-neutral voltage, worst `cm_fr/i_max` thermal
utilisation, a classifier that names the headline active constraint, and a
`run_scenario` wrapper around `augment_case → solve_opf`) are defined in
[`examples/place_and_solve_ders.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/examples/place_and_solve_ders.jl)
(functions `vpn_pu`, `max_thermal`, `classify`, `run_scenario`); the doc build
loads the same definitions behind the scenes. With everything in place, the
recipes drop one PV IBR and one thinner generator on each load bus:

```@example ders
demo = base_net()
for (iid, ibr) in sort(collect(demo["ibr"]); by = first)
    println("  IBR  ", rpad(iid, 11), "bus=", rpad(ibr["bus"], 8),
            "topo=", rpad(ibr["topology"], 13), "s_max=", ibr["s_max"], " VA")
end
for (gid, g) in sort(collect(demo["generator"]); by = first)
    println("  GEN  ", rpad(gid, 11), "bus=", rpad(g["bus"], 8),
            "cfg=", rpad(g["configuration"], 14), "p_max=", g["p_max"], " W")
end
```

Because the loads — and therefore the PV — sit on *different* phases, the export
is itself unbalanced, which is where four-wire modelling (explicit neutral, no
Kron reduction) earns its keep. Both DER tiers are priced below the slack, so
the OPF sees a layered **merit order** — cheap PV → mid-priced generator →
expensive slack import.

## Three scenarios

### A — cheap DERs, no network limit

The economic baseline: head at nominal, no voltage ceiling, no thermal limit
(the `RECIPE_NOLIMITS` preset). The OPF is then a pure cost sort:

```@example ders
A = run_scenario(base_net(), RECIPE_NOLIMITS)
show_outcome(A)
```

Every DER runs to its active-power bound and the surplus (≈ 71 kW) is exported —
the slack simply absorbs negative power. The only active constraints are the
imposed generation limits; the network is not yet in the way. This is the merit
order working exactly as priced.

### B — head run high, healthy cable → voltage binds

Now tap the feeder head to 1.05 pu (utilities run the LV head high to cover
downstream drop — precisely when midday PV export over-voltages the far end) and
impose the EN 50160 ceiling via `set_vpn_limits!`, which writes on every LV bus:

```julia
net["bus"][b]["vpn_max"] = fill(1.10 * 230.0, 3)
net["bus"][b]["vpn_min"] = fill(0.90 * 230.0, 3)
```

```@example ders
B = run_scenario(set_vpn_limits!(base_net(head_pu = 1.05)), RECIPE_LIMITS)
show_outcome(B)
```

The voltage is held at **exactly 1.10 pu** and the dispatch changes completely.
Two things happen, co-optimised in a single solve:

- **The IBRs absorb reactive power for voltage support — and both hit the same
  −21.79 kvar, but against *different* constraints.** `augment_case` sized the
  EN 50549-1 reactive box from the apparent-power circle at rated active power:

  ```math
  q_{\min} = -\sqrt{s_{\max}^2 - p_{\text{avail}}^2} = -\sqrt{50^2 - 45^2}
           \approx -21.79\ \text{kvar}.
  ```

  For the *uncurtailed* unit (`pv_b2656`, ``P = 45`` kW) that box edge lies
  exactly on the `P²+Q²≤s_max²` circle — both are active at once, and reactive
  support genuinely trades against active headroom. For the *curtailed* unit
  (`pv_b3230`, ``P ≈ 37.1`` kW) the circle has opened up
  (``\sqrt{50^2-37.1^2} ≈ 33.5`` kvar of circle headroom) and is **slack**; what
  pins its ``Q`` at −21.79 kvar is the fixed rectangular ``q_{\min}`` box the
  augmentation filled. Same number, two different binding constraints — you can
  only tell them apart by reading the active set, which is this tutorial's whole
  point.
- **The merit order is respected on the way down.** The OPF sheds the dearer
  generator (`der_*` → ~0) before curtailing the cheaper PV, and curtails the PV
  only on the worst phase (`pv_b3230`, 45 → ≈ 37 kW) — the unbalanced curtailment
  a three-wire model could not represent.

A simulation-only tool would report the over-voltage of scenario A and stop; here
the limit *reshapes* the optimal dispatch.

### C — same case, a thin cable → thermal binds instead

Keep everything — head, feeder, DER fleet, the 1.10 pu ceiling — and change only
*one* thing: give the two service drops a realistically derated 16 mm² ampacity
(`i_max = 90 A`) instead of their healthy rating:

```@example ders
C = run_scenario(set_vpn_limits!(base_net(head_pu = 1.05, derate = true)),
                 RECIPE_LIMITS)
show_outcome(C)
```

The voltage is now **slack** (≈ 1.084 pu, below the ceiling) and the **thermal
limit binds** at 100 % of `i_max`. The OPF curtails the PV to hold the conductor
current at its rating — a *different* binding constraint, curtailing a
*different* amount on a *different* basis than the voltage case, even though
nothing else about the problem changed. Note the reactive dispatch flipped too:
with no over-voltage to fight, each PV now *injects* a small ≈ +5 kvar instead
of absorbing 21.79 kvar.

### Summary

```@example ders
using Printf
@printf("%-16s%10s%12s%12s%9s   %s\n",
        "scenario", "max V(pu)", "thermal(%)", "export(kW)", "ΣP(kW)", "binding")
for (name, o) in (("A — no limits", A), ("B — voltage", B), ("C — thermal", C))
    @printf("%-16s%10.4f%12.0f%12.1f%9.1f   %s\n", name, o.max_vpn,
            100 * o.thermal, o.export_kw, sum(values(o.P)), o.binding)
end
```

B and C differ by a single knob — the service-cable ampacity — yet the **active
constraint** flips from voltage to thermal, and with it which DER is curtailed and
how much exports. Adding or tightening a binding constraint cannot lower the
objective — it weakly raises cost (less export revenue); *which* constraint binds
is the signature of an optimisation that respects the network physics and the
operating envelope at once.

## Appendix: the hosting-capacity curve and the constraint crossover

If one knob can flip the binding constraint, what does sweeping it look like? Hold
the scenario-C setup fixed and sweep only the cable ampacity:

```@example ders
@printf("%8s%12s%13s   %s\n", "i_max(A)", "max V(pu)", "export(kW)", "binding")
for imax in (60.0, 90.0, 120.0, 160.0, 220.0, 600.0)
    o = run_scenario(set_vpn_limits!(base_net(head_pu = 1.05, derate = true,
                                              imax = imax)), RECIPE_LIMITS)
    @printf("%8.0f%12.4f%13.1f   %s\n", imax, o.max_vpn, o.export_kw, o.binding)
end
```

While the cable is thin the **thermal** limit binds and every extra amp of rating
buys more export. Around 120–160 A both constraints are active at once — the
crossover. Past it the **voltage** ceiling takes over: the voltage pins at 1.10 pu,
export plateaus at ≈ 68 kW, and uprating the copper no longer buys hosting
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
