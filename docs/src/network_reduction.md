# [Network reduction: which tool, and what it preserves](@id network-reduction)

BMOPFTools offers three reductions. They remove different things, they are
exact under different conditions, and they lose different information. This
page explains what each one does, when it is exact, and how they combine. The
numbers come from AC power flows on three feeders (the reproduction script is
named at the end).

## Two meanings of "Kron reduction"

Both operations below are called *Kron reduction* in the literature
[Dörfler & Bullo 2013]. They share the algebra, a Schur complement, but
apply it to different matrices under different conditions:

- **Conductor reduction** works on a line's *impedance* matrix and imposes a
  zero voltage drop along the neutral of each line. The neutral may still
  carry current; the reduction is exact when the neutral voltage is zero at
  both ends of every line, that is, when the neutral is held at earth
  potential there. [`kron_reduce_neutrals`](@ref) classifies its result as
  `"exact"` only if no neutral had to be forced to earth and no constraint was
  dropped or converted.
- **Bus reduction** works on the network's *admittance* matrix and imposes
  zero current injection at the eliminated nodes.

| | Eliminates | Imposes | Exact when | Function |
|---|---|---|---|---|
| **Conductor (neutral) Kron reduction** | the neutral *conductor* of each line: Z_abc = Z_pp − Z_pn Z_nn⁻¹ Z_np | zero neutral voltage drop along each line | the neutral is at earth potential at both ends of every line | [`kron_reduce_neutrals`](@ref) |
| **Bus (node) Kron reduction** | whole *buses*: Y_eq = Y_KK − Y_KR Y_RR⁻¹ Y_RK | zero current injection at eliminated nodes | the eliminated buses carry no injection | [`kron_reduce_buses`](@ref), after [`opti_kron_reduction`](@ref) |

The first turns a four-wire model into a three-wire one with the same buses.
The second keeps the conductors but removes buses. Elsewhere in these docs,
for example in the [methodology notes](methodology.md) and the
[line-geometry tutorial](tutorial_line_geometry.md), "Kron reduction" means the
conductor version.

## The three tools

| | [`simplify_network`](@ref) | [`kron_reduce_neutrals`](@ref) | Opti-KRON ([`opti_kron_reduction`](@ref) + [`kron_reduce_buses`](@ref)) |
|---|---|---|---|
| Removes | topology artifacts: closed switches, stubs, unloaded pass-through buses (series merging) | neutral conductors | buses, including loaded ones |
| Exact when | no shunt-bearing line is merged (or `series_merge_policy=:exact`, default `:allow_approximate`), no stub with a shunt is pruned, no rated switch is collapsed (check `_simplification_log`) | neutrals are *perfectly* earthed | never exactly: devices move to a nearby bus |
| Guarantee instead | — | — | voltage error ≤ Ē at **every** original bus, for every injection in an uncertainty set, under a linear model |
| Loses | voltages of merged buses; ratings of collapsed switches | neutral voltages and currents; finite earthing (forced to ideal) | current limits of eliminated lines; per-bus voltages (recoverable with [`lift_solution`](@ref)) |
| Records | `_simplification_log` | `_meta.kron_reduction` | `_kron_reduction` |

All three return a new BMOPF case and leave the original unchanged. The
result is a [solve-time compile target](@ref object-identity), not the case of
record.

## How they compare on real feeders

AC power flow on the reduced case versus the original case on test
loadings, at Ē = 0.001 p.u. "Coverage" is the share of original bus-phases that
still have a voltage estimate. The error is the largest phase-to-neutral
voltage-magnitude error over all covered bus-phases (kept and eliminated) and
test loadings, relative to Ē. Opti-KRON uses the convex hull of the training
samples. On the European LV feeder the 48 test loadings are the half-hour
points of the 1,440 training minutes (minutes 15, 45, …); the
[Opti-KRON validation](@ref opti-kron-validation) measures eliminated buses only on a
different sample set, so its numbers differ.

| Feeder | Strategy | Buses | Ybus nodes | Coverage | AC error / Ē | after lift |
|---|---|---|---|---|---|---|
| IEEE European LV (907 buses, 55 loads, 48 loadings) | original | 907 | 2586 | 100% | 0 | – |
| | simplify | 118 | 354 | 13% | 0 | – |
| | neutral | 907 | 2586 | 100% | 0 | – |
| | Opti-KRON | 148 | 444 | 100% | 1.04 | 0.11 |
| | simplify → Opti-KRON | **70** | **210** | 13% | 0.84 | 0.02 |
| SAPN LV feeder A (80 buses, finite MEN earthing, 12 loadings) | original | 80 | 319 | 100% | 0 | – |
| | simplify | 80 | 319 | 100% | 0 | – |
| | neutral | 80 | 240 | 100% | **1.02** | – |
| | Opti-KRON | **12** | **47** | 100% | 0.73 | 0.02 |
| | neutral → Opti-KRON | 12 | 36 | 100% | 1.44 | 1.02 |
| SAPN LV feeder B (253 buses, 231 loads, 12 loadings) | original | 253 | 994 | 100% | 0 | – |
| | simplify | 245 | 970 | 97% | 0 | – |
| | neutral | 253 | 759 | 100% | 0 | – |
| | Opti-KRON | **32** | **119** | 100% | 0.78 | 0.004 |

What the table adds to the comparison above:

- **Coverage.** Simplification is exact on these feeders, but merged buses no
  longer have a voltage. The European LV feeder is mostly long unloaded
  chains: simplification removes 87% of its buses and keeps a voltage for
  only 13% of bus-phases. On the load-dense feeder B it removes almost
  nothing. Opti-KRON keeps an estimate at every bus.
- **Finite MEN earthing.** Neutral elimination is exact where the model earths
  every neutral perfectly (feeder B: 994 → 759 nodes, zero error). Feeder A
  earths its neutral through finite MEN electrodes; forcing it to ideal earth
  shifts phase-to-neutral voltages by about Ē, and no lift can undo that,
  because the neutral voltages are gone. (The European LV model is already
  three-wire, so the step changes nothing there.)
- **Composition.** Simplifying first and letting Opti-KRON cluster the loaded
  buses gives 907 → 70 buses on the European LV feeder. Errors also compose:
  after neutral elimination on feeder A, Opti-KRON reaches 1.44 Ē in AC and
  the lift recovers only the Opti-KRON part. Opti-KRON alone reaches up to
  1.04 Ē, because its certificate is for the linear model; leave a margin on
  Ē for the linear-versus-AC gap.

## A recommended pipeline

1. Run [`kron_reduce_neutrals`](@ref) only if every neutral is perfectly earthed
   in the model; check its `_meta.kron_reduction` provenance for
   `"classification" => "exact"`. The scientific contract
   [`check_kron_boundary_recovery`](@ref) checks the same grounding
   precondition for a single source/target line pair with a declared
   recovery map; it is not a whole-network precheck.
2. Run [`simplify_network`](@ref) if the voltages of unloaded pass-through
   buses need not be modeled.
3. Run Opti-KRON on what remains, with an uncertainty set built from
   representative loadings, and keep
   [`opti_kron_required_buses`](@ref) so the result can be built. Opti-KRON is
   not yet linked to a `PSK-*` claim or exposed through the JSON execution
   interface.
4. Solve the reduced case, then use [`lift_solution`](@ref) and an AC power flow
   on the original network to check the answer.

[Reducing a feeder with a voltage guarantee](@ref tutorial-opti-kron)
introduces Opti-KRON on a six-bus feeder;
[Reducing a four-wire feeder, step by step](@ref tutorial-network-reduction)
walks through this pipeline on a generated feeder; and
[Error-bounded bus reduction](@ref opti-kron) has the mathematics.

## Reproduction

The comparison table comes from `scripts/reduction_comparison.jl` (Gurobi for
the reduction MILP, Ipopt for the power flows). The European LV data are the
IEEE European Low Voltage Test Feeder (55 one-minute load profiles); the SAPN
feeder rows use a non-public data set and cannot be reproduced from public
data.
