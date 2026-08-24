# [What are you actually optimising?](@id tutorial-objectives)

*One feeder, six objectives, six different answers.*

`solve_opf` minimises generation cost. That is a choice, not a law, and on a
distribution feeder it is frequently the wrong one — least-cost dispatch has no
opinion about losses and no opinion at all about unbalance.

This tutorial takes **one unbalanced four-wire LV feeder** and solves it under
six objectives, so you can see what each one buys and what it costs. Every code
block runs when the docs are built, so the numbers below are real.

*Prerequisites: `BMOPFTools`, `JuMP` and `Ipopt`, and familiarity with the JSON
input format — see the [end-to-end tutorial](tutorial_end_to_end.md). For the
reference on each term, see [Choosing an objective](objectives.md).*

## The feeder

A 230 V four-wire feeder, two spans, with a badly unbalanced load at the far end
(7 kW / 1.5 kW / 0.8 kW). Two things can respond: a **four-leg STATCOM** at the
midpoint, and an **expensive local generator** at the load end. The grid supply
is cheap (0.30/kWh) and far away; the local generator is dear (0.45/kWh) and
close.

That price gap is what makes "minimise cost" and "minimise losses" *different
questions*.

```@example objectives
using BMOPFTools, JuMP, Ipopt, Printf

feeder() = parse_bmopf("""
{"bus":{
  "src":{"terminal_names":["a","b","c","n"],"perfectly_grounded_terminals":["n"],
         "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
  "mid":{"terminal_names":["a","b","c","n"],
         "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]},
  "end":{"terminal_names":["a","b","c","n"],
         "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
 "voltage_source":{"grid":{"bus":"src","terminal_map":["a","b","c"],
     "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944],
     "cost":[0.30,0.30,0.30]}},
 "linecode":{"lc":{"R_series_1_1":0.16,"R_series_2_2":0.16,"R_series_3_3":0.16,
                   "R_series_4_4":0.16,
                   "X_series_1_1":0.07,"X_series_2_2":0.07,"X_series_3_3":0.07,
                   "X_series_4_4":0.07}},
 "line":{"l1":{"bus_from":"src","bus_to":"mid",
     "terminal_map_from":["a","b","c","n"],"terminal_map_to":["a","b","c","n"],
     "linecode":"lc","length":1.0},
         "l2":{"bus_from":"mid","bus_to":"end",
     "terminal_map_from":["a","b","c","n"],"terminal_map_to":["a","b","c","n"],
     "linecode":"lc","length":1.0}},
 "load":{"ld":{"bus":"end","terminal_map":["a","b","c","n"],
     "configuration":"WYE","p_nom":[7000.0,1500.0,800.0],
     "q_nom":[1200.0,300.0,150.0]}},
 "ibr":{"statcom":{"bus":"mid","terminal_map":["a","b","c","n"],
     "topology":"FOUR_LEG","prime_mover":"STATCOM",
     "s_max":[8000.0,8000.0,8000.0],
     "p_max":[4000.0,4000.0,4000.0],"p_min":[-4000.0,-4000.0,-4000.0],
     "dc_link_coupled":true,
     "cost":[0.0,0.0,0.0]}},
 "generator":{"dg":{"bus":"end","terminal_map":["a","b","c","n"],
     "configuration":"WYE",
     "p_max":[3000.0,3000.0,3000.0],"p_min":[0.0,0.0,0.0],
     "q_max":[1500.0,1500.0,1500.0],"q_min":[-1500.0,-1500.0,-1500.0],
     "cost":[0.45,0.45,0.45]}}}
""";from_string=true)
nothing # hide
```

## One harness, six objectives

Each study builds the model **without** its default objective, assembles terms,
sets them, enforces KCL, and solves. The reported quantities are all physical, so
they are directly comparable across objectives.

```@example objectives
function study(label, maketerms)
    ctx = build_opf_model(feeder(); add_objective = false)
    set_opf_objective!(ctx, maketerms(ctx))
    enforce_kcl!(ctx)                      # REQUIRED — see the note below
    m = opf_model(ctx); set_attribute(m, "print_level", 0); optimize!(m)
    res = extract_result(ctx)
    v2(b) = hypot(value.(opf_sequence_voltage(ctx, b; component = :negative))...) *
            opf_physical_scale(ctx, :V; bus = b)
    In = hypot(value.(opf_neutral_current(ctx, "line", "l2"; side = :to))...) *
         opf_physical_scale(ctx, :A; bus = "end")
    @printf("%-20s cost=%6.3f  loss=%7.1f W  |V2|mid=%5.3f V  |V2|end=%5.3f V  |In|=%5.2f A\n",
            label, value(generation_cost(ctx)), res["losses"]["p_loss"],
            v2("mid"), v2("end"), In)
end

study("min cost",      ctx -> [opf_generation_cost_term(ctx)])
study("min loss",      ctx -> [opf_loss_term(ctx)])
study("min |V2|^2",    ctx -> [opf_sequence_term(ctx, ["mid","end"]; norm = :squared)])
study("min |V2| (L1)", ctx -> [opf_sequence_term(ctx, ["mid","end"]; norm = :magnitude)])
study("min |In|^2",    ctx -> [opf_current_term(ctx, [("line","l2",:to)])])
study("cost + unbal",  ctx -> [opf_generation_cost_term(ctx; weight = 1.0),
                               opf_sequence_term(ctx, ["mid","end"];
                                                 norm = :squared, weight = 2e-3)])
```

## Reading the table

**Cost and losses are different questions.** Least-cost dispatch leaves the
expensive local generator idle and hauls everything down a resistive feeder;
least-loss dispatch buys the dear local power instead and cuts losses by roughly
three quarters, for about 28% more money. Neither answer is wrong — they answer
different questions. If you have ever assumed minimising losses is a reasonable
proxy for minimising cost, this row is the counterexample.

**Balancing is not free.** Driving `|V₂|` to near zero roughly doubles the
losses relative to least-cost dispatch, because the STATCOM circulates active
power between phases to do it and that circulation has `I²R` attached.

**Voltage unbalance and current unbalance actively conflict.** This is the row
worth staring at. Minimising the neutral current drives `|In|` to essentially
zero — and makes `|V₂|` *dramatically worse* than any other objective, including
doing nothing about unbalance at all. Zero neutral current is not the same
condition as balanced voltage, and optimising for one can wreck the other. If
someone hands you "we minimise unbalance", ask **which** unbalance.

**A small weight buys a cheap improvement.** The combined objective barely moves
the cost while measurably reducing `|V₂|` at the load end — the near-flat part of
the Pareto front. Trading the *whole* way to balanced is the expensive part.

## When does `:magnitude` differ from `:squared`?

Not here — and that is worth understanding rather than glossing over.

`:magnitude` is the group-lasso norm; its selling point is *sparsity*, driving a
few targets to zero rather than shrinking all of them. That behaviour needs the
targets to be **independently controllable**. On this radial feeder `mid` and
`end` sit on the same path with one compensator between them, so their `V₂` move
together: there is effectively one degree of freedom and nothing to choose
between. Both norms find the same point, at every STATCOM rating.

Reach for `:magnitude` when your targets genuinely compete — several laterals
with their own compensators and a shared budget, or a control-effort penalty
where you want *few devices moving* rather than *all devices moving slightly*.
On a single controllable axis, prefer `:squared`: it is exact, cheaper, and has
no ε to size.

!!! danger "`enforce_kcl!` is not optional"
    `build_opf_model` defers KCL so a `model_hook!` can still contribute to the
    nodal accumulators. Until [`enforce_kcl!`](@ref) runs the network is
    **electrically disconnected** — bus voltages are free variables and your
    objective is minimised without physics; an unbalance objective in particular
    reaches exactly zero with every compensator idle, which reads as a triumph.

    Skipping it is now an error rather than a wrong number: `JuMP.optimize!`
    refuses a model holding any unstamped context, and `extract_result` refuses
    an unstamped context.

## What you combined is recorded

A weighted objective whose weights are not written down is not a reproducible
experiment. Every term registers its weight, units and purpose:

```@example objectives
ctx = build_opf_model(feeder(); add_objective = false)
set_opf_objective!(ctx, [opf_generation_cost_term(ctx; weight = 1.0),
                         opf_sequence_term(ctx, ["mid","end"];
                                           norm = :squared, weight = 2e-3)])
for (_, r) in sort(collect(opf_regularizations(ctx)); by = first)
    println(rpad(r.name, 32), " weight=", rpad(r.weight, 8), " units=", r.units)
end
```

Note the `units` field. A weight of `2e-3` means *per V²* here; the same number
against `norm = :magnitude` would mean *per V*, roughly 230× different in effect
on an LV feeder — and the objective value would look perfectly reasonable either
way. Weights are declared per physical unit precisely so this stays visible, and
so the same specification gives the same answer in `per_unit = true` and
`per_unit = false`.

## The traps that bite hardest

Three of these cost real debugging time while this feature was built, and all
three were silent when we hit them — nothing errored, and the numbers looked
plausible.

1. **Forgetting `enforce_kcl!`** gives a disconnected network in which an
   unbalance objective reaches exactly zero with every compensator idle. It
   reads as a triumph. This one is now guarded: it raises rather than returning
   a plausible answer.
2. **Sizing `ε` from a unit-conversion factor** rather than the quantity's
   characteristic magnitude makes one specification give two different answers
   in the two unit modes.
3. **Putting a smoothed norm inside a ratio** — the `ε` that conditions a
   vanishing norm mis-states a ratio built on it by tens of percent. It is why
   [`opf_vuf_term`](@ref) is the *squared* ratio.

The full list, with the numbers, is under
[Pitfalls](@ref objective-pitfalls).

## Where to go next

- [Choosing an objective](objectives.md) — the full catalogue, the ε guidance,
  and which quantities do and do not need a square root.
- [D-STATCOM unbalance study](@ref statcom-unbalance) — why a four-leg converter
  can balance a feeder at all.
