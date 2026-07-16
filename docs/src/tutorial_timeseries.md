# [Time series: a day on an LV feeder](@id timeseries-day)

*Snapshot networks, daily profiles, and a 24-hour OPF sweep.*

A single OPF answers a single question: *given this loading, what is the best
dispatch right now?* But a distribution feeder does not have one loading — it
has a day. Residential demand bottoms out before dawn and peaks in the evening;
rooftop PV peaks at noon, exactly when demand is low. The feeder's binding
constraint *moves with the clock*: overnight it is a lightly-loaded import
network, at midday it can run **backwards**, and in the evening it carries its
peak. A case that only encodes one operating point silently picks one of these
regimes and hides the others.

BMOPF networks therefore carry an optional root-level `"time_series"`
collection of named profiles — plain vectors of **multiplicative scale
factors**, following PowerModelsDistribution's convention — and any component
can bind a parameter to a profile via its own `"time_series"` map
(`parameter name → profile id`). Two functions do all the work:

- [`is_timeseries`](@ref) — does this network actually vary over time?
- [`get_snapshot`](@ref) — materialise the concrete network at one step:
  `resolved = static × scale[t]`.

Everything downstream — [`analyze`](@ref), [`solve_opf`](@ref),
[`solve_pf`](@ref), [`profile_solution`](@ref) — accepts a `t_index` keyword
and snapshots internally, so a time-series case drops into the ordinary
single-period pipeline. Every code block below runs when the docs are built,
so the numbers are real.

!!! note "Prerequisites"
    A Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`, and familiarity
    with the load → analyze → augment → solve pipeline from the
    [end-to-end tutorial](tutorial_end_to_end.md). The feeder here is the same
    LV1 14-bus network that tutorial walks through, with profiles and two
    rooftop PV units added.

## 1. A feeder with a day attached

The test fixture `lv1_14bus_timeseries.json` is the LV1 14-bus feeder — an
11 kV source behind a delta-wye transformer, four-wire 230 V mains, two 10 kW
single-phase customers — plus two named 24-step profiles and two 15 kW
single-phase rooftop PV IBRs (one per load bus, on different phases):

```@example ts
using BMOPFTools

path = joinpath(pkgdir(BMOPFTools), "test", "data", "LV", "lv1_14bus_timeseries.json")
net  = parse_bmopf(path)

println("is_timeseries : ", is_timeseries(net))
for (id, ts) in sort(collect(net["time_series"]); by = first)
    println(rpad(id, 18), " : ", length(ts["values"]), " steps, ",
            "min ", minimum(ts["values"]), ", max ", maximum(ts["values"]))
end
```

`is_timeseries` requires **both** halves of the contract: a non-empty root
collection *and* at least one component that references it. A network with
profiles nobody uses — or references into a missing collection — is treated as
an ordinary snapshot network. Here both loads bind `p_nom` and `q_nom` to the
residential shape (constant power factor across the day), and both PV units
bind `p_max` and `p_avail` to the solar shape:

```@example ts
println("load  ld3313_load_a : ", net["load"]["ld3313_load_a"]["time_series"])
println("ibr   pv_b3230      : ", net["ibr"]["pv_b3230"]["time_series"])
```

## 2. Snapshot mechanics

`get_snapshot(net, t)` returns a **deep copy** with every referenced parameter
resolved multiplicatively and all the time-series bookkeeping stripped — the
result is a plain single-period BMOPF network. Compare 03:00 (`t_index = 4`,
1-based) with noon (`t_index = 13`):

```@example ts
night = get_snapshot(net, 4)    # 03:00
noon  = get_snapshot(net, 13)   # 12:00

println("03:00  load p_nom = ", night["load"]["ld3313_load_a"]["p_nom"],
        " W,  PV p_max = ", night["ibr"]["pv_b3230"]["p_max"], " W")
println("12:00  load p_nom = ", noon["load"]["ld3313_load_a"]["p_nom"],
        " W,  PV p_max = ", noon["ibr"]["pv_b3230"]["p_max"], " W")
println("snapshot is static      : ", !is_timeseries(noon))
println("original is untouched   : ", net["load"]["ld3313_load_a"]["p_nom"],
        " W, is_timeseries = ", is_timeseries(net))
```

At 03:00 the customer draws 27 % of its 10 kW nominal and the PV ceiling is
zero; at noon the load sits at 40 % while each PV unit may dispatch its full
15 kW. Scaling `p_max` (the OPF dispatch bound) rather than a fixed injection
is deliberate: the solar shape is a *ceiling*, and the OPF stays free to
curtail below it if the network requires. The original `net` keeps its static
values and its profiles — snapshots never mutate their source.

## 3. Prepare once, solve per hour

The import lacks operating bounds, so we run [`augment_case`](@ref) **once**
on the time-series network — bounds and costs are time-invariant, and
augmentation passes the profiles through untouched. Each `solve_opf` call then
selects its hour with `t_index`:

```@example ts
using JuMP, Ipopt

net_ready, _ = augment_case(net; recipe = AugmentationRecipe())
optimizer = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

result_noon = solve_opf(net_ready; optimizer = optimizer, per_unit = true, t_index = 13)
println("noon status : ", result_noon["termination_status"])
println("noon PV     : ",
        round(sum(ph["pg"] for id in keys(result_noon["ibr"])
                           for ph in values(result_noon["ibr"][id])) / 1e3; digits = 2), " kW")
```

Passing `t_index` is exactly equivalent to `solve_opf(get_snapshot(net_ready, 13))`
— the solver materialises the snapshot internally before building the model.

## 4. The 24-hour sweep — a duck curve in a table

Now sweep the day: 24 independent snapshot OPFs, one per hour. For each we
record total load, dispatched PV, the net grid exchange (slack generator plus
voltage source, positive = import), and the phase-voltage envelope on the
230 V mains (all buses except the 11 kV source bus):

```@example ts
mv_bus = "b2577"   # the 11 kV source bus — excluded from the LV voltage envelope

function hour_row(res, snap)
    load = sum(sum(l["p_nom"]) for l in values(snap["load"]))
    pv   = sum(ph["pg"] for id in keys(res["ibr"]) for ph in values(res["ibr"][id]))
    grid = sum(v["ps"] for v in values(first(values(res["voltage_source"])))) +
           sum(ph["pg"] for g in values(get(res, "generator", Dict())) for ph in values(g); init = 0.0)
    vms  = [v["vm"] for (b, terms) in res["bus"] if b != mv_bus
                    for (t, v) in terms if t != "n"]
    (load = load, pv = pv, grid = grid, vmin = minimum(vms), vmax = maximum(vms))
end

println("hour   load kW   PV kW   grid kW   Vmin    Vmax")
rows = NamedTuple[]
for t in 1:24
    res  = solve_opf(net_ready; optimizer = optimizer, per_unit = true, t_index = t)
    @assert res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    r = hour_row(res, get_snapshot(net_ready, t))
    push!(rows, r)
    println(lpad(t - 1, 4), lpad(round(r.load / 1e3; digits = 1), 10),
            lpad(round(r.pv / 1e3;   digits = 1), 8),
            lpad(round(r.grid / 1e3; digits = 2), 10),
            lpad(round(r.vmin; digits = 1), 8), lpad(round(r.vmax; digits = 1), 8))
end
nothing # hide
```

Read the table as three regimes:

- **Overnight (00–05 h)** — no sun, 2.7–3.5 kW of load: the feeder imports a
  few kW and the LV voltages sit in a narrow band around the transformer's
  no-load value, gently drooping toward the customers.
- **Midday (09–15 h)** — the duck's belly. 30 kW of PV meets 4–5 kW of load;
  the grid exchange goes **negative** (reverse power flow up through the
  distribution transformer) and the voltage *maximum* now occurs at the PV
  buses, not the source: power flows uphill, so the far end of the feeder is
  the high point. This is the regime where volt-var/volt-watt control and
  export limits earn their keep — see the [VVWO tutorial](tutorial_vvwo.md).
- **Evening (18–21 h)** — the duck's head. The sun is gone, load peaks at
  20 kW, imports peak, and the voltage *minimum* is at the customers again.

```@example ts
t_imp = argmax(t -> rows[t].grid, 1:24)
t_exp = argmin(t -> rows[t].grid, 1:24)
println("peak import : ", round(rows[t_imp].grid / 1e3; digits = 2),
        " kW at hour ", t_imp - 1)
println("peak export : ", round(-rows[t_exp].grid / 1e3; digits = 2),
        " kW at hour ", t_exp - 1)
println("day-wide LV voltage envelope: ",
        round(minimum(r.vmin for r in rows); digits = 1), " – ",
        round(maximum(r.vmax for r in rows); digits = 1), " V")
```

The two sizing constraints of the feeder live at *different hours*: the
thermal/import question at the evening peak, the overvoltage/export question
at solar noon. A single-snapshot study would have shown at most one of them.

The per-hour results feed the same tooling as any single-period solve —
`profile_solution(net_ready, result; t_index = t)` checks each hour's result
against that hour's bounds.

!!! warning "Scope: independent snapshots, not multi-period optimisation"
    Each hour above is a **separate, self-contained OPF**. The snapshots share
    nothing: there is no storage arbitraging energy between them, no ramp
    limits linking one hour's dispatch to the next, no inter-temporal
    constraints of any kind. `get_snapshot` + `t_index` give you a *sequence
    of single-period problems* — the right tool for hosting-capacity envelopes
    and worst-hour screening, and the wrong one for battery scheduling or
    unit commitment, which need a genuinely multi-period model that BMOPFTools
    does not currently build.

This sweep-the-parameter pattern is the same one the
[tap-optimisation tutorial](tutorial_tap.md) uses to trace an OLTC tap
schedule against load level — there the sweep variable is a synthetic load
multiplier; here it is the clock, with the shapes shipped inside the case
itself so every consumer of the benchmark sweeps the *same* day.

## Modelling notes & FAQ

A time series is deliberately a *thin* mechanism — a named vector of
multiplicative scale factors and a per-parameter binding (see the
[spec page](spec/timeseries.md)). Most modelling questions reduce to *which
parameter you bind to which profile*.

**How do I change the irradiance / PV shape?** The PV ceiling is `p_max`/`p_avail`
scaled by a solar profile. To study a cloudier day, a different latitude, or a
seasonal shape, edit that profile's `values` (or bind `p_max` to a different
profile id) — nothing else changes, because the profile is just the ceiling the
OPF curtails under. The scale factors are unitless multipliers on the static
nameplate, so a `values` entry of `0.8` means "80 % of `p_max` available this
step."

**How do I model different load or EV-charging patterns?** Author a new profile
and bind the relevant `load`'s `p_nom` to it. An EV charger is demand, so it is a
`load` whose `p_nom` follows a charging shape (e.g. an evening ramp); several
charging behaviours are just several profiles over the same feeder. A load that
should change power factor over the day binds `p_nom` and `q_nom` to *different*
profiles; binding both to the **same** profile (as the feeder here does) holds
the power factor constant while the magnitude varies.

**Can I do a BESS / storage study, or ramp limits?** Not with this mechanism.
Each `t_index` is an **independent snapshot** with no coupling between steps — no
stored energy, no ramp constraints, no inter-temporal terms (see the scope
warning above). Time series answer *hosting-capacity envelopes* and *worst-hour
screening*; battery arbitrage and unit commitment need a genuinely multi-period
model, which BMOPFTools does not currently build. A battery still appears as an
`ibr` with `prime_mover = "BATTERY"` in each snapshot, but its state of charge is
not carried across hours.

**Why scale `p_max` rather than inject a fixed `p`?** Scaling the *bound* keeps
the OPF free to curtail below the ceiling when the network requires it (the whole
point of §4's midday regime). Binding a fixed injection instead would force the
dispatch and defeat the optimisation.

**Does augmentation need to run per step?** No. Bounds and costs are
time-invariant, so `augment_case` runs **once** on the time-series network and
the profiles pass through untouched (§3). Only `solve_opf`/`solve_pf`/
`profile_solution` take the `t_index`.

!!! tip "Where to go next"
    The [end-to-end tutorial](tutorial_end_to_end.md) covers the pipeline each
    snapshot passes through; [DER placement](tutorial_ders.md) grows the PV
    fleet systematically; the [VVWO tutorial](tutorial_vvwo.md) adds the
    inverter voltage-control that the midday regime above motivates.
