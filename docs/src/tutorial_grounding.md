# [Ground, neutral, and earth return](@id grounding-tutorial)

*Three different things called "ground", one experiment across floating,
impedance-grounded, and solidly-grounded neutrals — then the mathematics:
null spaces, the Kron-reduction assumption, and what the Fortescue transform
does and does not buy you.*

Distribution modelling uses one word — *ground* — for three different
objects, and most four-wire modelling errors trace back to conflating them.
The [terminals primer](terminals_primer.md) makes the conceptual case for
explicit neutrals; the [grounding spec](spec/grounding.md) defines the data
model. This tutorial supplies the missing chain between them: the same feeder
solved under three grounding assumptions, the null-space view of what
"floating" means, a live demonstration of exactly when eliminating the
neutral (Kron reduction) is legitimate, the single-wire earth-return system
as the limiting case, and the precise distinction between the Fortescue
*transform* (always available) and sequence-network *decoupling* (an
assumption). Every block runs at build time.

!!! note "Prerequisites"
    A Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`, plus the
    [terminals primer](terminals_primer.md). The
    [impedance-models tutorial](tutorial_impedance_models.md) is this page's
    sibling on the symmetry side of the story.

## 1. Three things called "ground"

- **The ground reference** is a modelling convention: the single 0 V "copper
  plate" all node voltages are measured against. It is *not* a matrix row,
  not a conductor, and nothing flows "through" it
  ([grounding spec](spec/grounding.md)).
- **The neutral conductor** is a physical wire with resistance, reactance,
  and mutual coupling to the phases. It has its own voltage variable at every
  bus, and that voltage is generally *not* zero.
- **The grounding electrode** (rod, mat, counterpoise) is the tie between the
  two: a physical, *imperfect* connection from a conductor — usually the
  neutral — to the local earth.

The classic conflation is assuming the neutral *is* the reference: that its
voltage is zero everywhere because it is "grounded". Whether that holds is a
property of the electrodes, not of the word — §3 measures it.

## 2. The engine's vocabulary

Four data-model pieces express everything in this tutorial:

- a case-level `terminal_conventions` block declares which terminal labels
  are phases, neutrals, or (rare, for genuine earth *wires*) earth
  conductors. Absent the block, roles are inferred from naming and flagged
  [`W.CONV.TERMINAL_ROLES_INFERRED`](findings.md);
- `perfectly_grounded_terminals` on a bus pins those terminal voltages to
  exactly 0 V and adds a free earth-injection current — the *ideal* electrode;
- an **impedance grounding** is not a special field at all: it is an ordinary
  `shunt` from the neutral terminal to the reference — the *real* electrode;
- `vn_max` bounds how far a *floating* neutral may drift in an OPF.

Look at both on real cases — the LV feeder used across these tutorials, and
the SWER feeder whose grounding *is* its return circuit:

```@example gnd
using BMOPFTools, JuMP, Ipopt, LinearAlgebra

lv1  = from_dss(joinpath(pkgdir(BMOPFTools), "test", "data", "LV",  "LV1_14bus", "Master.dss"))
swer = from_dss(joinpath(pkgdir(BMOPFTools), "test", "data", "SWER", "Master.dss"))

println("conventions (both cases): ", lv1["terminal_conventions"])
println("SWER perfectly grounded : ",
        [(b, bd["perfectly_grounded_terminals"]) for (b, bd) in swer["bus"]
         if !isempty(get(bd, "perfectly_grounded_terminals", String[]))])
println("SWER electrodes (shunts): ",
        sort([(id, s["bus"], round(Float64(s["G_1_1"]); digits = 0)) for (id, s) in swer["shunt"]]))
```

One perfectly-grounded source neutral, and five 1000 S (1 mΩ — effectively
solid) electrode shunts along the feeder: the SWER system's earth-return path,
written as ordinary data. §6 returns to it.

## 3. Floating, impedance-grounded, solid: one experiment

Build the smallest network where the three assumptions differ: a 500 m
four-wire line (mutually coupled phase and neutral conductors), a single-phase
3 kW + 1 kvar customer between phase *a* and neutral, and the source neutral
solidly grounded. Vary only the *customer-end* neutral: floating, a realistic
10 Ω electrode, or perfect. Watch three quantities — the neutral-to-earth
voltage (NEV), the phase-to-neutral voltage the customer actually receives,
and how the return current splits between the neutral conductor and the earth:

```@example gnd
OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

lc4 = Dict{String,Any}()
for i in 1:4, j in 1:4
    lc4["R_series_$(i)_$(j)"] = (i == j ? 0.5 : 0.02) / 1000   # Ω/m
    lc4["X_series_$(i)_$(j)"] = (i == j ? 0.2 : 0.05) / 1000
end

function feeder(ground)
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                                      "perfectly_grounded_terminals" => ["n"]),
            "lb"  => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                     "perfectly_grounded_terminals" =>
                         ground == :perfect ? ["n"] : String[])),
        "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
            "bus" => "src", "terminal_map" => ["a","b","c","n"],
            "v_magnitude" => [230.0, 230.0, 230.0, 0.0],
            "v_angle" => [0.0, -2π/3, 2π/3, 0.0])),
        "linecode" => Dict{String,Any}("lc4" => deepcopy(lc4)),
        "line" => Dict{String,Any}("l1" => Dict{String,Any}(
            "bus_from" => "src", "bus_to" => "lb", "linecode" => "lc4",
            "length" => 500.0,
            "terminal_map_from" => ["a","b","c","n"],
            "terminal_map_to"   => ["a","b","c","n"])),
        "load" => Dict{String,Any}("ld" => Dict{String,Any}(
            "bus" => "lb", "terminal_map" => ["a","n"],
            "configuration" => "SINGLE_PHASE",
            "p_nom" => [3000.0], "q_nom" => [1000.0])))
    ground == :electrode && (net["shunt"] = Dict{String,Any}(
        "rod" => Dict{String,Any}("bus" => "lb", "terminal_map" => ["n"],
                                  "G_1_1" => 0.1)))        # a 10 Ω rod
    net
end

println("neutral       NEV      V_pn(load)   I_neutral wire")
for g in (:float, :electrode, :perfect)
    r  = solve_pf(feeder(g); optimizer = OPT)
    lb = r["bus"]["lb"]
    vn = abs(lb["n"]["vr"] + im*lb["n"]["vi"])
    va = abs((lb["a"]["vr"] + im*lb["a"]["vi"]) - (lb["n"]["vr"] + im*lb["n"]["vi"]))
    println(rpad(g, 12), lpad(round(vn; digits = 2), 6), " V",
            lpad(round(va; digits = 2), 10), " V",
            lpad(round(r["line"]["l1"]["n"]["cm_fr"]; digits = 2), 10), " A")
end
```

Three lessons, one table:

- **Floating**: the full 14 A of return current flows in the neutral
  conductor, and its impedance drop appears as ≈ 3.6 V of NEV at the customer
  — stray voltage a person can touch, and a direct bite out of the voltage
  the load receives.
- **A real electrode barely moves it.** The 10 Ω rod diverts only ≈ 0.35 A to
  earth — the neutral conductor's fraction of an ohm is a far lower-impedance
  return than any single rod. One electrode is *bonding*, not a return path;
  this is why multi-grounded systems need *many* electrodes before the
  "grounded" idealisation is honest.
- **Perfect grounding is not a small step from a good electrode — it is a
  different circuit.** NEV is zero *by construction*, the customer gains
  3.4 V, and — look at the last column — the neutral conductor now carries
  1.4 A instead of 14 A: the model quietly rerouted 90 % of the return
  current through the zero-impedance earth. If your physical feeder does not
  do that, neither should your model. `perfectly_grounded_terminals` is the
  right model for substation mats and dense multi-grounded neutrals, and a
  silently wrong one for a single rod at the end of a long rural line.

## 4. What "floating" means mathematically

The system nodal admittance matrix makes the reference story precise.
[`ybus_passive`](@ref) assembles every passive element over explicit
`(bus, terminal)` nodes, with **earth as the reference (not a matrix row)**,
grounded terminals collapsed onto it, and — deliberately — no contribution
from ideal voltage sources. Whatever that matrix cannot see, something else
must pin:

```@example gnd
cases = [
    "no grounding anywhere" => (n = feeder(:float);
                                delete!(n["bus"]["src"], "perfectly_grounded_terminals"); n),
    "source neutral grounded" => feeder(:float),
    "both neutrals grounded"  => feeder(:perfect),
]
for (name, net) in cases
    yb = ybus_passive(net)
    sv = svdvals(Matrix(yb.Y))
    println(rpad(name, 26), "nodes: ", size(yb.Y, 1),
            "   near-zero singular values: ", count(s -> s < 1e-9 * sv[1], sv))
end
```

Read the counts as **degrees of freedom the passive network leaves
undetermined** — rigid voltage translations of conductor groups that have no
tie to the reference. With nothing grounded, all four conductor paths float
(shift both ends of any conductor pair equally and no current changes);
grounding the source neutral removes exactly the neutral's mode; the three
phase modes remain in every case *because a passive matrix cannot know about
sources* — it is the voltage source's fixed phasors, a boundary condition,
that pin them in an actual solve. This is the graph-Laplacian story of
reference nodes, made concrete: **sources pin voltages; groundings tie
conductors to earth; every conductor group needs one or the other**, or the
problem is singular — the numerical face of an electrician's "floating".

## 5. Kron reduction is an assumption, not a simplification

Textbooks reduce the 4×4 series-impedance matrix to 3×3 by eliminating the
neutral row — the Schur complement
``Z_{\text{red}} = Z_{pp} - Z_{pn} Z_{nn}^{-1} Z_{np}``. The step is
algebraically exact **iff the eliminated node's voltage is held at zero
wherever current enters it** — that is, the neutral is *perfectly* grounded
at every connection point. §3 just showed when that premise holds. Test the
whole chain: Kron-reduce our line by hand, build the three-wire equivalent
(loads become phase-to-ground — the reduced model has no neutral to connect
to), and compare against the four-wire truth under each grounding:

```@example gnd
Z4  = [(i == j ? 0.5 : 0.02) + im*(i == j ? 0.2 : 0.05) for i in 1:4, j in 1:4] ./ 2 # 500 m, Ω
Zk  = Z4[1:3,1:3] .- Z4[1:3,4:4] * (Z4[4:4,4:4] \ Matrix(transpose(Z4[1:3,4:4])))

lc3 = Dict{String,Any}()
for i in 1:3, j in 1:3
    lc3["R_series_$(i)_$(j)"] = real(Zk[i,j]) / 500.0
    lc3["X_series_$(i)_$(j)"] = imag(Zk[i,j]) / 500.0
end
net3w = Dict{String,Any}(
    "bus" => Dict{String,Any}(
        "src" => Dict{String,Any}("terminal_names" => ["a","b","c"]),
        "lb"  => Dict{String,Any}("terminal_names" => ["a","b","c"])),
    "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
        "bus" => "src", "terminal_map" => ["a","b","c"],
        "v_magnitude" => [230.0, 230.0, 230.0], "v_angle" => [0.0, -2π/3, 2π/3])),
    "linecode" => Dict{String,Any}("lc3" => lc3),
    "line" => Dict{String,Any}("l1" => Dict{String,Any}(
        "bus_from" => "src", "bus_to" => "lb", "linecode" => "lc3",
        "length" => 500.0,
        "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c"])),
    "load" => Dict{String,Any}("ld" => Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["a"], "configuration" => "WYE",
        "p_nom" => [3000.0], "q_nom" => [1000.0])))

va3 = let r = solve_pf(net3w; optimizer = OPT)
    abs(r["bus"]["lb"]["a"]["vr"] + im*r["bus"]["lb"]["a"]["vi"])
end
println("Kron three-wire model:  V_a = ", round(va3; digits = 3), " V, always")
for g in (:perfect, :electrode, :float)
    r  = solve_pf(feeder(g); optimizer = OPT)
    lb = r["bus"]["lb"]
    va = abs((lb["a"]["vr"] + im*lb["a"]["vi"]) - (lb["n"]["vr"] + im*lb["n"]["vi"]))
    println(rpad(g, 12), " four-wire V_pn = ", round(va; digits = 3),
            " V    Kron error = ", round(abs(va - va3); digits = 3), " V")
end
```

Under perfect grounding at both ends the reduction is **exact to the last
digit** — Kron is not an approximation there, it is algebra. Under a floating
or realistically-earthed neutral the "same" model is ≈ 3.3 V optimistic —
1.4 % of nominal, larger than the margins hosting-capacity studies argue
over, and invisible from inside the reduced model, which cannot even
represent the NEV it is mispredicting. European LV feeders ground the neutral
at the transformer and rarely along the way — the *wrong* regime for Kron.
This is precisely why the engine keeps four-wire models un-reduced end to end
([impedance spec](spec/impedance.md)); its single deliberate exception is
collapsing concentric-neutral/tape-shield *subconductors* held at earth
potential inside [`compile_linecode`](@ref), recorded in the linecode's
`derivation.shields_reduced` provenance
([line geometry tutorial](tutorial_line_geometry.md)).

## 6. Earth as the return conductor: SWER

Push §3 to its limit: remove the neutral conductor entirely and let the earth
*be* the return path — Single-Wire Earth-Return, thousands of kilometres of
which electrify rural Australia. In the data model this needs nothing new:
one phase conductor per span, and the grounding machinery of §2 carrying the
full load current at every electrode. The earth-return impedance itself lives
in the line constants — Carson's frequency- and resistivity-dependent
correction, applied when geometry compiles to a linecode
([impedance derivation](spec/impedance.md)):

```@example gnd
report = analyze(swer)
println("SWER zones found: ", report.results[:connectivity]["n_swer_zones"])
for f in report.findings
    startswith(String(f.code), "I.PROV.SWER") && println("  ", f.code, ": ", f.message)
end
```

[`analyze`](@ref) recognises the pattern (single-wire, transformer-isolated
galvanic zones) and labels it as provenance, not as an error — earthing as a
*design choice*. The [SWER case study](tutorial_swer.md) takes this feeder on
to the optimisation question; here the point is conceptual: SWER is not an
exotic special case bolted onto the model, it is §1's three objects — a
reference, (no) neutral conductor, and electrodes — in their most honest
configuration, where getting the earth path wrong is not a 3 V subtlety but
the whole circuit.

## 7. The Fortescue transform vs sequence decoupling

The last conflation in the chain is coordinate change versus physical
assumption. The Fortescue matrix ``\mathbf{F}`` (a conjugate three-point DFT,
[notation](spec/notation.md)) can *always* be applied — it is invertible, no
assumptions required. What is **not** free is the step every sequence-network
diagram takes next: treating zero, positive, and negative sequence as three
*decoupled* single-phase circuits. That requires
``\mathbf{F}^{-1} \mathbf{Z} \mathbf{F}`` to be diagonal, which holds exactly
when ``\mathbf{Z}`` is **circulant** — balanced, transposed construction.
Our §5 matrix is circulant by construction (all mutuals equal); perturb the
mutuals the way untransposed geometry does and watch the decoupling die:

```@example gnd
a = cis(2π/3)
F = (1/sqrt(3)) .* [1 1 1; 1 a a^2; 1 a^2 a]
offdiag_max(M) = maximum(abs(M[i,j]) for i in 1:3, j in 1:3 if i != j)

Zs = inv(F) * Zk * F
println("circulant line:    Z0 = ", round(Zs[1,1]; sigdigits = 3),
        "  Z1 = Z2 = ", round(Zs[2,2]; sigdigits = 3),
        "  max off-diag = ", round(offdiag_max(Zs); sigdigits = 2), " Ω")

Zu = copy(Zk)                          # untransposed: unequal mutual spacings
Zu[1,2] = Zu[2,1] = 0.015 + 0.040im
Zu[2,3] = Zu[3,2] = 0.010 + 0.025im
Zu[1,3] = Zu[3,1] = 0.008 + 0.020im
Zsu = inv(F) * Zu * F
println("untransposed line: Z0 = ", round(Zsu[1,1]; sigdigits = 3),
        "  Z1 = ", round(Zsu[2,2]; sigdigits = 3),
        "  max off-diag = ", round(offdiag_max(Zsu); sigdigits = 2), " Ω")
```

Two readings tie the whole tutorial together. First, ``Z_0 \neq Z_1`` even
for the perfectly balanced line — because **zero-sequence current needs a
return path**, and ``Z_0`` is where the neutral-and-earth story of §§3–6
hides inside sequence analysis: change the grounding and you change ``Z_0``,
while ``Z_1`` never notices. Second, for the untransposed line the sequence
coupling is small but structural — the decoupled diagram is now an
approximation with an error you must budget, not a change of coordinates.
The engine sidesteps the entire question by solving in phase coordinates and
using sequence quantities only as *derived* outputs; the
[impedance-models tutorial](tutorial_impedance_models.md) develops the
circulant ⇔ DFT ⇔ ``Z_1 = Z_2`` story and its consequences for OPF in full —
link, don't duplicate.

## 8. The checklist

- **Say which "ground" you mean.** Reference, neutral conductor, or
  electrode — if a sentence works with all three meanings, it is hiding an
  assumption.
- **`perfectly_grounded_terminals` is a strong claim**: zero NEV *and* a free
  zero-impedance return path (§3). Defensible for substation earthing mats
  and dense multi-grounded systems; not for a rod at the end of a feeder —
  model that as a `shunt` and let the solver tell you what it carries.
- **A floating neutral is not an error** — it is a modelling statement that
  the only return is metallic. Expect NEV, bound it with `vn_max`, and expect
  [`ybus_passive`](@ref) to show the corresponding null mode if nothing ties
  the group to earth (§4).
- **Kron-reduce only what is genuinely pinned to zero volts** (§5). If you
  ingest three-wire data that was reduced upstream, the assumption arrived
  with it — [`I.PROV.SEQ_DERIVED` / `I.PROV.DECOUPLED_PHASES`](findings.md)
  flag the fingerprints.
- **Sequence networks are a symmetry statement, not a coordinate change**
  (§7). Use the transform freely on results; trust decoupled networks only as
  far as the construction is balanced — and remember ``Z_0`` *is* the
  grounding story.

!!! tip "Where to go next"
    The [grounding spec](spec/grounding.md) and
    [terminals primer](terminals_primer.md) formalise §§1–2; the
    [SWER case study](tutorial_swer.md) turns §6 into an optimisation
    problem; the [line-geometry tutorial](tutorial_line_geometry.md) shows
    where Carson's earth-return correction enters the impedance data; and the
    [impedance-models tutorial](tutorial_impedance_models.md) continues §7
    into OPF consequences.
