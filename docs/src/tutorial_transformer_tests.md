# [From test report to transformer model](@id transformer-tests)

*Short-circuit and open-circuit test data in; winding leakage, magnetising
branch, vector group, and n-winding `x_sc` out — then close the loop by
re-running the tests on the constructed model.*

A transformer arrives as three documents: a **nameplate** (kVA, voltage
ratings, vector group), a **short-circuit test** (impedance voltage %Z and
load loss), and an **open-circuit test** (no-load loss and magnetising
current). Every number is a percentage *on the machine's own base*, and the
BMOPF data model wants **SI ohms and siemens on specific windings**. This
tutorial is that conversion, done twice — a single-phase unit first, then a
Dyn11 — with the validations a defensible model needs: the primitive
admittance derived by hand from the datasheet and compared entry-wise against
the engine; the factory tests *re-simulated on the constructed model* to
recover the datasheet numbers; and an independent cross-check of the whole
mapping through OpenDSS text and [`from_dss`](@ref). A three-winding unit
closes with the `x_sc` matrix that replaces "the" impedance when a single %Z
no longer exists. Every block runs at build time.

!!! note "Prerequisites"
    A Julia environment with `BMOPFTools`, `JuMP` and `Ipopt`. The
    [units tutorial](tutorial_units.md) covers the base arithmetic
    (``Z_B = V^2/S``) used constantly here; the
    [nameplate tutorial](tutorial_nameplate.md) covers the provenance
    discipline for what may *not* be derived; and
    [Transformer models](transformer_models.md) is the normative contract
    behind everything on this page.

## 1. What a test report gives you

| Test | Measures | Yields |
|---|---|---|
| Nameplate | — | `s_rating` (VA), `v_nom_from`/`v_nom_to` (V), vector group → subtype |
| Short-circuit (LV shorted, reduced HV voltage, rated current) | impedance voltage %Z, load loss ``P_{cu}`` | series leakage `r/x_series_*` (Ω) |
| Open-circuit (rated voltage, LV open) | no-load loss ``P_0``, magnetising current ``I_0`` (%) | core branch `g_no_load`/`b_no_load` (S) |

Two facts drive every formula below. First, the percentages are **per-unit on
the machine's own base**: ``Z_B^{\text{wdg}} = V_{\text{wdg}}^2/S`` with the
winding's own voltage and the transformer's `s_rating` — so "4 %" means
different ohms on each side of the same machine, related by the turns ratio
squared. Second, each test isolates one branch of the equivalent circuit: at
rated current with the secondary shorted the core branch is negligible, so
the SC test sees the series leakage alone; at rated voltage with no load the
series drop is negligible, so the OC test sees the core branch alone. That
separation is what lets us *invert* the tests into fields — and, in §4,
re-run them as a check.

## 2. A single-phase unit, by hand

Take a 50 kVA, 11 000/240 V single-phase distribution transformer with a
typical test report:

- short-circuit: ``\%Z = 4.0``, load loss ``P_{cu} = 1100`` W,
- open-circuit: ``P_0 = 150`` W, magnetising current ``I_0 = 0.5\,\%``.

**Series branch.** The load loss fixes the resistive part
(``\%R = 100 P_{cu}/S = 2.2``) and the impedance triangle gives
``\%X = \sqrt{\%Z^2 - \%R^2}``. The SC test measures only the **series sum**
``Z^{fr} + N^2 Z^{to}``; how that sum splits between the windings is *not
measurable from the terminals* and is a convention — here half/half in
percent, each half landing in ohms on its own winding's base (the
[spec](spec/transformer.md) documents the under-determination; §5 shows a
different convention in the wild and why it doesn't matter).

**Core branch.** No-load loss → conductance; magnetising current →
(negative, inductive) susceptance. Placement matters: the engine follows
OpenDSS and puts the branch **across winding 2**, the *to*-side coil, so both
convert on winding 2's voltage
([magnetising-shunt placement](transformer_models.md#Magnetising-shunt-placement)).
The loss current ``100 P_0/S = 0.3\,\%`` is one leg of ``I_0``; the
susceptance current is the quadrature remainder.

```@example xfmr
using BMOPFTools, JuMP, Ipopt

S = 50_000.0;  Vhv = 11_000.0;  Vlv = 240.0
pctZ = 4.0;  Pcu = 1_100.0;  P0 = 150.0;  I0 = 0.5          # the test report

pctR  = 100Pcu / S
pctX  = sqrt(pctZ^2 - pctR^2)
Zb_fr = Vhv^2 / S                        # winding 1's own impedance base (Ω)
Zb_to = Vlv^2 / S                        # winding 2's
pct_b = sqrt(I0^2 - (100P0/S)^2)         # magnetising (susceptance) current, %

xfmr = Dict{String,Any}(
    "bus_from" => "hv", "bus_to" => "lv",
    "terminal_map_from" => ["1", "n"], "terminal_map_to" => ["1", "n"],
    "v_nom_from" => Vhv, "v_nom_to" => Vlv, "s_rating" => S,
    "r_series_from" => (pctR/2)/100 * Zb_fr,    # Ω, HV winding
    "r_series_to"   => (pctR/2)/100 * Zb_to,    # Ω, LV winding
    "x_series_from" => (pctX/2)/100 * Zb_fr,
    "x_series_to"   => (pctX/2)/100 * Zb_to,
    "g_no_load"     =>  (P0/S)      * S / Vlv^2,   # S, on winding 2's coil voltage
    "b_no_load"     => -(pct_b/100) * S / Vlv^2)   # negative: inductive

for k in ("r_series_from", "x_series_from", "r_series_to", "x_series_to",
          "g_no_load", "b_no_load")
    println(rpad(k, 16), " = ", round(xfmr[k]; sigdigits = 5))
end
```

Note the four orders of magnitude between `x_series_from` (≈ 40 Ω) and
`x_series_to` (≈ 0.019 Ω) — the *same* 1.67 % on two different voltage bases.
Typing an HV-base ohm into an LV field is the classic silent transformer bug,
which is why the validations below exist.

## 3. Validation one: the admittance matrix, by hand

[`transformer_yprim`](@ref) builds the primitive admittance the engine (and
its `Yprim` export) uses from those fields. For the single-phase Γ-model the
[spec derivation](spec/transformer-admittance.md) is small enough to
hand-compute. The device is one series admittance ``y = 1/Z`` (with
``Z = Z^{fr} + N^2 Z^{to}`` referred to the HV side) acting between the two
winding voltages, plus the core branch ``Y_0`` across the *to* coil. Over the
node order ``[\,hv.1,\ lv.1,\ hv.n,\ lv.n\,]`` the winding incidence is
``\mathbf{v} = [1, -N, -1, N]^\mathsf{T}`` and the to-coil incidence
``\mathbf{t} = [0, 1, 0, -1]^\mathsf{T}``, so the whole matrix is two rank-one
terms:

```math
\mathbf{Y} = y\,\mathbf{v}\mathbf{v}^\mathsf{T} + Y_0\,\mathbf{t}\mathbf{t}^\mathsf{T}.
```

```@example xfmr
nodes, Y = transformer_yprim(xfmr, "single_phase")
println("engine node order: ", nodes)

N  = Vhv / Vlv
Z  = (xfmr["r_series_from"] + im*xfmr["x_series_from"]) +
     N^2 * (xfmr["r_series_to"] + im*xfmr["x_series_to"])
Y0 = xfmr["g_no_load"] + im * xfmr["b_no_load"]

v = [1.0, -N, -1.0, N]
t = [0.0, 1.0, 0.0, -1.0]
Y_hand = (1/Z) .* (v * transpose(v)) .+ Y0 .* (t * transpose(t))

println("max |Y_engine − Y_hand| = ",
        round(maximum(abs.(Y .- Y_hand)); sigdigits = 3), " S")
@assert isapprox(Y, Y_hand; rtol = 1e-8)
println("entry-wise match ✓   (e.g. Y[1,1] = ", round(Y[1,1]; sigdigits = 5),
        " = y = ", round(1/Z; sigdigits = 5), ")")
```

Every number in the engine's matrix is now accounted for by datasheet
arithmetic. This entry-wise check is the same discipline the test suite
applies against OpenDSS's own `Yprim` dumps for every subtype
([validation](validation.md)) — orientation bugs (stamping ``N`` where
``1/N`` belongs) pass symmetry and passivity checks and are caught *only* by
reference comparisons like this one.

## 4. Validation two: re-run the factory tests on the model

The strongest closure: the model was built *from* the tests, so simulating
the tests on it must return the datasheet numbers. The open-circuit test is a
two-bus power flow with no load; the short-circuit test is the same network
with the LV terminals bolted to ground (`perfectly_grounded_terminals`) and
the source dialled down to exactly %Z of nominal — which, by definition of
the impedance voltage, must circulate exactly rated current.

```@example xfmr
OPT = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

testnet(; short = false, vscale = 1.0) = Dict{String,Any}(
    "bus" => Dict{String,Any}(
        "hv" => Dict{String,Any}("terminal_names" => ["1", "n"],
                                 "perfectly_grounded_terminals" => ["n"]),
        "lv" => Dict{String,Any}("terminal_names" => ["1", "n"],
                 "perfectly_grounded_terminals" => short ? ["1", "n"] : ["n"])),
    "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
        "bus" => "hv", "terminal_map" => ["1", "n"],
        "v_magnitude" => [Vhv * vscale, 0.0], "v_angle" => [0.0, 0.0])),
    "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
        "t1" => deepcopy(xfmr))))

oc = solve_pf(testnet(); optimizer = OPT)
p_oc = sum(ph["ps"] for ph in values(oc["voltage_source"]["source"]))
i_oc = only(ph["cm"] for ph in values(oc["transformer"]["t1"]["fr"]))
println("open-circuit :  P = ", round(p_oc; digits = 2), " W  (datasheet P0 = ", P0, ")")
println("               I0 = ", round(100 * i_oc / (S/Vhv); digits = 3),
        " % of rated  (datasheet ", I0, " %)")

sc = solve_pf(testnet(short = true, vscale = pctZ/100); optimizer = OPT)
p_sc = sum(ph["ps"] for ph in values(sc["voltage_source"]["source"]))
i_sc = only(ph["cm"] for ph in values(sc["voltage_source"]["source"]))
println("short-circuit:  I = ", round(i_sc; digits = 3), " A at ", pctZ,
        " % voltage  (rated = ", round(S/Vhv; digits = 3), " A)")
println("               P = ", round(p_sc; digits = 1), " W  (datasheet Pcu = ", Pcu, ")")

@assert isapprox(p_oc, P0; rtol = 5e-3)          # tiny series loss from I0 flowing
@assert isapprox(i_sc, S/Vhv; rtol = 1e-3)
@assert isapprox(p_sc, Pcu; rtol = 1e-3)
```

The loop closes: report → fields → model → report. The small residual in the
OC power (the magnetising current does traverse half the series resistance)
is exactly the approximation the factory test itself makes — the model
reproduces the *test*, not an idealisation of it.

## 5. Three-phase: the Dyn11 and its vector group

Now the realistic case: a 400 kVA, 11 000/416 V **Dyn11** distribution
transformer — ``\%Z = 4.5``, ``P_{cu} = 4600`` W, ``P_0 = 610`` W,
``I_0 = 0.25\,\%``. The vector group decodes into model structure:

- **D** → winding 1 is delta → subtype `delta_wye`, `terminal_map_from` has
  three phase terminals (no HV neutral);
- **yn** → winding 2 is wye with the neutral brought out (four terminals);
- **11** → the LV leads by 30°; this is the *backward-delta* coil convention,
  which the engine applies for Dy — and `delta_roll = -1` in `n_winding`
  language ([conventions](transformer_models.md#Conventions)).

Two conventions to internalise for the 2-bus three-phase subtypes:
`v_nom_from`/`v_nom_to` are the **line-to-line** ratings straight off the
nameplate (the √3 lives inside the effective per-coil ratio the engine
derives), and the winding-2 shunt converts on winding 2's **coil** voltage —
for the wye secondary that is ``v_{\text{nom,to}}/\sqrt{3}``, i.e. 240 V, not
416 V. The impedance recipe is otherwise §2 verbatim:

```@example xfmr
S3 = 400_000.0;  Vhv3 = 11_000.0;  Vlv3 = 416.0
pctZ3 = 4.5;  Pcu3 = 4_600.0;  P03 = 610.0;  I03 = 0.25

pctR3  = 100Pcu3 / S3
pctX3  = sqrt(pctZ3^2 - pctR3^2)
pct_b3 = sqrt(I03^2 - (100P03/S3)^2)
Vcoil2 = Vlv3 / sqrt(3)                       # wye winding-2 coil voltage

dyn11 = Dict{String,Any}(
    "bus_from" => "hv", "bus_to" => "lv",
    "terminal_map_from" => ["a", "b", "c"],           # delta: no neutral
    "terminal_map_to"   => ["a", "b", "c", "n"],      # wye + neutral
    "v_nom_from" => Vhv3, "v_nom_to" => Vlv3, "s_rating" => S3,
    "r_series_from" => (pctR3/2)/100 * Vhv3^2/S3,
    "r_series_to"   => (pctR3/2)/100 * Vlv3^2/S3,
    "x_series_from" => (pctX3/2)/100 * Vhv3^2/S3,
    "x_series_to"   => (pctX3/2)/100 * Vlv3^2/S3,
    "g_no_load"     =>  (P03/S3)     * S3 / Vcoil2^2,
    "b_no_load"     => -(pct_b3/100) * S3 / Vcoil2^2)

for k in ("r_series_from", "x_series_from", "r_series_to", "x_series_to",
          "g_no_load", "b_no_load")
    println(rpad(k, 16), " = ", round(dyn11[k]; sigdigits = 5))
end
```

**Independent cross-check.** The same datasheet can be written as OpenDSS
text and imported through the entirely separate OpenDSS→PowerIO→BMOPF
pipeline. If the hand conversion and the import pipeline agree, both would
have to be wrong in the same way to be wrong at all:

```@example xfmr
deck = joinpath(mktempdir(), "Master.dss")
write(deck, """
Clear
New Circuit.dyn11 basekv=11 pu=1.0 phases=3 bus1=hvbus
New Transformer.tx1 phases=3 windings=2 buses=(hvbus, lvbus) conns=(delta, wye)
~ kvs=(11, 0.416) kvas=(400, 400) xhl=$(pctX3) %Rs=($(pctR3/2), $(pctR3/2))
~ %noloadloss=$(100P03/S3) %imag=$(pct_b3)
Set VoltageBases=[11, 0.416]
CalcVoltageBases
Solve
""")
imported = first(values(from_dss(deck)["transformer"]["delta_wye"]))

N3 = Vhv3 / Vlv3
series(t) = (t["r_series_from"] + im*t["x_series_from"]) +
            N3^2 * (t["r_series_to"] + im*t["x_series_to"])
println(rpad("field", 16), rpad("hand", 14), "from_dss")
for k in ("r_series_from", "r_series_to", "g_no_load", "b_no_load")
    println(rpad(k, 16), rpad(round(dyn11[k]; sigdigits = 5), 14),
            round(Float64(imported[k]); sigdigits = 5))
end
println(rpad("series sum (Ω)", 16), rpad(round(series(dyn11); sigdigits = 5), 14),
        round(series(imported); sigdigits = 5))
@assert isapprox(series(dyn11), series(imported); rtol = 1e-6)
@assert isapprox(dyn11["g_no_load"], Float64(imported["g_no_load"]); rtol = 1e-6)
@assert isapprox(dyn11["b_no_load"], Float64(imported["b_no_load"]); rtol = 1e-6)
```

The resistances and core branch match term-for-term. The *reactance split*
does not have to: the import happens to distribute X differently between the
windings — and the **HV-referred series sum agrees exactly**, which is the
only thing the short-circuit test ever measured (§2). Two honest conventions,
one physical quantity. (At an off-nominal *optimised* tap the split briefly
matters — the tapped winding's share scales as tap² — which is why the engine
pins the referral convention explicitly;
[transformer models](transformer_models.md).)

**And re-run the tests.** Same drill as §4, three-phase:

```@example xfmr
vph = Vhv3 / sqrt(3)
net3(; short = false, vscale = 1.0) = Dict{String,Any}(
    "bus" => Dict{String,Any}(
        "hv" => Dict{String,Any}("terminal_names" => ["a", "b", "c", "n"],
                                 "perfectly_grounded_terminals" => ["n"]),
        "lv" => Dict{String,Any}("terminal_names" => ["a", "b", "c", "n"],
                 "perfectly_grounded_terminals" => short ? ["a","b","c","n"] : ["n"])),
    "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
        "bus" => "hv", "terminal_map" => ["a", "b", "c", "n"],
        "v_magnitude" => [vph*vscale, vph*vscale, vph*vscale, 0.0],
        "v_angle" => [0.0, -2π/3, 2π/3, 0.0])),
    "transformer" => Dict{String,Any}("delta_wye" => Dict{String,Any}(
        "t1" => deepcopy(dyn11))))

oc3 = solve_pf(net3(); optimizer = OPT)
v_lv = abs(oc3["bus"]["lv"]["a"]["vr"] + im*oc3["bus"]["lv"]["a"]["vi"])
p_oc3 = sum(ph["ps"] for ph in values(oc3["voltage_source"]["source"]))
println("open-circuit :  P = ", round(p_oc3; digits = 1), " W (P0 = ", P03,
        "),  LV no-load = ", round(v_lv; digits = 1), " V (",
        round(Vlv3/sqrt(3); digits = 1), " expected)")

sc3 = solve_pf(net3(short = true, vscale = pctZ3/100); optimizer = OPT)
i_sc3 = [ph["cm"] for ph in values(sc3["voltage_source"]["source"])]
p_sc3 = sum(ph["ps"] for ph in values(sc3["voltage_source"]["source"]))
println("short-circuit:  I = ", round.(i_sc3; digits = 2), " A (rated = ",
        round(S3/(sqrt(3)*Vhv3); digits = 2), "),  P = ", round(p_sc3; digits = 0),
        " W (Pcu = ", Pcu3, ")")
@assert isapprox(p_oc3, P03; rtol = 5e-3)
@assert all(isapprox.(i_sc3, S3/(sqrt(3)*Vhv3); rtol = 1e-3))
@assert isapprox(p_sc3, Pcu3; rtol = 1e-3)
```

Rated line current at 4.5 % voltage, 4600 W of load loss, 610 W of core loss,
and 240.2 V on the open secondary — the Dyn11's datasheet, recovered from the
constructed model.

## 6. Taps and neutral impedances

Two field families complete the 2-bus picture; both are prose here because
their live demonstrations have dedicated tutorials.

**Taps.** `tap` (default 1.0) multiplies the ratio:
``N = (v_{\text{nom,from}}/v_{\text{nom,to}}) \cdot tap``. Setting
`tap_min < tap_max` turns the tap into an **OPF decision variable** — the
[tap-optimisation tutorial](tutorial_tap.md) is the walkthrough. The
interaction with §5's split convention: the engine referral is *exact* — the
short-circuit impedance referred to the tapped winding scales as tap², the
untapped side stays at nominal, matching OpenDSS at every tap position
([transformer models](transformer_models.md)).

**Neutral impedances.** A test report or design sheet may specify a neutral
earthing resistor/reactor on the wye star point (OpenDSS `rneut`/`xneut`).
The fields `r_neutral_from`/`x_neutral_from` and `r_neutral_to`/`x_neutral_to`
model **a grounding branch** ``y_n = 1/(R_n + jX_n)`` **from the winding's
neutral terminal to earth** — *not* a series impedance inside the star. That
distinction is a classic misreading (in a healthy power flow the branch
carries almost nothing; its job is anchoring zero-sequence and isolated
islands), and the engine's semantics are validated entry-wise against
OpenDSS. An *external* grounding transformer or reactor at the bus stays a
separate `shunt` — a transformer's model never absorbs external grounding
([the stand-alone contract](transformer_models.md#Grounding:-the-stand-alone-contract)).

## 7. Three windings and beyond: the `x_sc` matrix

For three or more windings there is **no single %Z** — the factory report
gives *pairwise* short-circuit tests (HL, HT, LT), all expressed on
**winding 1's** base (the OpenDSS convention, kept by the engine so
round-trips stay exact). The `n_winding` subtype stores exactly that: a
`windings` list plus `x_sc["i_j"]` in ohms **on winding 1's coil base**. Note
the per-winding `v_nom` convention differs from the 2-bus subtypes: it is the
**coil** voltage — line-to-neutral for a wye winding, line-to-line for a
delta.

Take a 20 MVA, 33/11/6.6 kV three-winding unit (delta primary, two wye
secondaries), pairwise tests ``\%X_{12} = 10``, ``\%X_{13} = 17``,
``\%X_{23} = 6`` on the 20 MVA base. Winding 1 is a delta, so its coil sees
line-to-line voltage and carries a third of the power:
``Z_{\text{coil},1} = 3 v_1^2 / S``.

```@example xfmr
using LinearAlgebra

Sn = 20e6
v_coil = [33_000.0, 11_000.0/sqrt(3), 6_600.0/sqrt(3)]   # delta L-L, wye L-N
z_coil1 = 3 * v_coil[1]^2 / Sn
x_sc = Dict("1_2" => 0.10 * z_coil1,
            "1_3" => 0.17 * z_coil1,
            "2_3" => 0.06 * z_coil1)
pctRw = [0.4, 0.4, 0.4]                                   # per-winding %R
r_w   = [pctRw[k]/100 * 3 * v_coil[k]^2 / Sn for k in 1:3]

nw = Dict{String,Any}(
    "s_rating" => Sn, "x_sc" => x_sc,
    "windings" => [
        Dict{String,Any}("bus" => "hv", "terminal_map" => ["a","b","c"],
            "configuration" => "DELTA", "delta_roll" => -1,
            "v_nom" => v_coil[1], "r_winding" => r_w[1]),
        Dict{String,Any}("bus" => "mv", "terminal_map" => ["a","b","c","n"],
            "configuration" => "WYE", "v_nom" => v_coil[2], "r_winding" => r_w[2]),
        Dict{String,Any}("bus" => "lv", "terminal_map" => ["a","b","c","n"],
            "configuration" => "WYE", "v_nom" => v_coil[3], "r_winding" => r_w[3])])

println("x_sc (Ω, winding-1 coil base): ",
        Dict(k => round(v; digits = 3) for (k, v) in x_sc))
```

Internally the engine assembles the OpenDSS-style ``(n{-}1){\times}(n{-}1)``
short-circuit matrix ``\mathbf{Z}_B`` referred to winding 1 — diagonal
``Z_{1,i+1}``, off-diagonal ``\tfrac12 (Z_{1,i+1} + Z_{1,j+1} - Z_{i+1,j+1})``
— which is *exact for any n* (the pairwise tests are precisely the
``n(n{-}1)/2`` numbers the matrix needs). Build it by hand and check it
against the engine's builder (internal, shown for verification):

```@example xfmr
Nk  = [vc / v_coil[1] for vc in v_coil]
r1  = r_w ./ Nk .^ 2                       # resistances referred to winding 1
Zp(i, j) = (r1[i] + r1[j]) + im * x_sc["$(min(i,j))_$(max(i,j))"]
ZB_hand = [Zp(1,2)                     (Zp(1,2) + Zp(1,3) - Zp(2,3))/2 ;
           (Zp(1,2) + Zp(1,3) - Zp(2,3))/2                     Zp(1,3)]

ZB_engine = BMOPFTools._nw_zb_matrix(nw)   # internal — verification only
println("ZB (hand)   = ", round.(ZB_hand; sigdigits = 5))
println("ZB (engine) = ", round.(ZB_engine; sigdigits = 5))
@assert isapprox(ZB_hand, ZB_engine; rtol = 1e-12)

ev = eigvals(imag.(ZB_hand))
println("eigvals(imag ZB) = ", round.(ev; sigdigits = 4), "  — realisable: ",
        all(ev .≥ 0))
```

The eigenvalue check is the **realisability test**: the pairwise reactances
of a physical shared-core device must make ``\Im(\mathbf{Z}_B)`` positive
semidefinite. Datasheets fail this more often than you would hope (typos, or
tests taken at different taps), and a negative eigenvalue here is your first
warning *before* a solver produces a confusing answer. A *negative
off-diagonal star arm*, by contrast, is perfectly physical for three-winding
units — do not "fix" it. Two `n_winding` specifics worth pinning:
`delta_roll = -1` is OpenDSS's standard delta orientation (the same 30° the
"11" encoded in §5), and tap *optimisation* is not available on `n_winding`
— regulated windings need a 2-bus subtype
([approximations table](transformer_models.md#Approximations)).

!!! warning "Unequal winding kVAs"
    All impedance percentages here convert on **winding 1's `s_rating`** —
    the engine's (and OpenDSS's `XHL`-family) base convention, and the one
    the validated equal-kVA test fixtures exercise. Factory reports for
    units with *unequal* winding ratings often quote each winding's %R on
    that winding's **own** kVA base — rebase such values onto `s_rating`
    (multiply by ``S_{\text{rating}}/S_{\text{wdg}}``) before the formulas
    above, and cross-check the result against an independent calculation as
    in §5.

## 8. What you may *not* derive

Everything above was *derived* from measurements. The remaining fields are
not derivable, and the provenance discipline of the
[nameplate tutorial](tutorial_nameplate.md) applies in full:

- **No OC test → no core branch.** Omit `g_no_load`/`b_no_load` rather than
  inventing them; a lossless core is an honest, documented approximation.
- **Beware inherited defaults.** OpenDSS fills `xhl = 7 %`, `%r = 0.2` when a
  deck omits them — plausible-looking numbers with zero provenance.
  [`analyze`](@ref) flags them as [`I.PROV.DSS_DEFAULT_XFMR`](findings.md),
  and [`W.DOM.XFMR_X_NONINDUCTIVE`](findings.md) catches sign slips.
- **The winding split is a convention** (§2, §5) — record which one you used
  when publishing a case, because the split becomes observable under
  off-nominal taps.

!!! tip "Where to go next"
    [Transformer models](transformer_models.md) is the normative contract
    (shunt placement, tap referral, grounding);
    [the admittance spec](spec/transformer-admittance.md) has every subtype's
    symbolic `Yprim` and the four validation gates;
    [Validating the OPF](validation.md) shows the OpenDSS reference
    comparisons the test suite runs; the
    [tap-optimisation tutorial](tutorial_tap.md) makes §6's tap fields
    decision variables; and the [SWER tutorial](tutorial_swer.md) features a
    split-phase `center_tap` unit — the three-winding star of §7 in its most
    common street-level form.
