# From buses to terminals: a primer for transmission modelers

If you come from transmission optimization — MATPOWER, PowerModels.jl, PGLib-OPF
[ref. 13](methodology.md#refs) — a **bus** *is* the electrical node: it carries a
single complex voltage, KCL is one complex equation per bus, ground is the
implicit reference, and there is no neutral. Even three-phase studies usually
collapse to a single-phase (positive-sequence) equivalent — which is sound
*because* transmission lines are transposed and loading is roughly balanced.
Neither assumption holds on a distribution feeder, so that collapse is not
available here [ref. 17](methodology.md#refs).

This package models distribution networks at conductor level, where that
identity breaks. A **bus** is a *physical location* — a pole, a pillar, a
cabinet — that hosts several **terminals**, one per conductor (`a`, `b`, `c`,
`n`). Each terminal is its own node with its own voltage variable, KCL holds
*per terminal*, and ground and the neutral are **explicit, distinct**
references rather than an assumed zero [ref. 1, 6](methodology.md#refs). The
mental shift is one sentence: **a bus is a bundle of nodes, not a node.**

## Translation table

| Concept | Transmission OPF | Four-wire distribution (here) |
|---|---|---|
| Bus | the electrical node | a *location*; a bundle of terminals |
| Voltage variable | one phasor per bus | one per **terminal** (`a`/`b`/`c`/`n`) |
| KCL | one equation per bus | one per terminal |
| Ohm's law (series) | scalar: $\Delta V = z\,I$ per branch | **matrix**: $\Delta \mathbf{V} = \mathbf{Z}\,\mathbf{I}$, full mutual coupling across conductors [ref. 4, 5](methodology.md#refs) |
| Ground / neutral | implicit reference | explicit, *separate* references |
| Device connection | "at the bus" | to **named terminals** via terminal maps (e.g. a delta load on `a`–`b`) |
| Unbalance | symmetrical components / per-phase | native; no decomposition |

The Ohm's-law row is the one most likely to surprise: a distribution line is not
a scalar reactance but an $n_c \times n_c$ series-impedance matrix (Carson's
equations [ref. 4](methodology.md#refs), with the neutral as an explicit row and
column), so the voltage drop on one conductor depends on the currents in *all*
of them. The off-diagonal (mutual) terms are generally *unequal* — phase
spacings differ — so the matrix cannot be collapsed to a transposed average
without error: on the IEEE 13-node feeder, modelling one real line as transposed
mis-estimates the downstream voltage unbalance by ~31% (1.50% vs 2.17%)
[ref. 17](methodology.md#refs). See the [Lines](opf.md#Lines) KVL constraints for
the exact form.

## "Why not just eliminate the neutral?"

The instinct from transmission is to fold the neutral into the phases and recover
a clean per-phase model. That operation is **Kron reduction**
[ref. 10](methodology.md#refs), and it is exact *only* when the neutral is
perfectly grounded everywhere. Real LV feeders are multi-grounded through finite
impedances, or grounded only at the source; under those conditions a Kron-reduced
model leaves neutral and ground voltages and currents unknown and
**under-estimates voltage deviations** [ref. 6, 7](methodology.md#refs). Because
neutral voltage rise, neutral/ground currents, and touch-safety are precisely
what distribution studies care about, this model keeps the neutral as an explicit
conductor and declines the reduction. (Where a reduction *is* sound, it is
applied deliberately and provenance-tracked — not assumed.)

## Where you've seen this before

The terminal view is the distribution-standard one, not an invention of this
package:

- **OpenDSS** addresses conductors with `Bus.node` notation — `Bus1.1.2.3.4`
  names phases 1–3 and the neutral conductor 4 at `Bus1` (node 0 is reserved for
  ground) [ref. 9](methodology.md#refs).
- **PowerModelsDistribution.jl** models the same structure as *terminals* and
  *connections*, with buses carrying one node per conductor, and supports proper
  four-wire (explicit-neutral) models, not only Kron-reduced ones
  [ref. 15](methodology.md#refs).

## Beyond terminals: more surprises

The terminal model is the central shift, but a few further conventions will look
unfamiliar to a MATPOWER/PowerModels user:

- **The data model is in SI units (volts, amperes, ohms), not per-unit.** There
  is no system MVA base in the data model; an impedance is a fixed property of a
  piece of equipment, independent of where it sits — which avoids the
  base-bookkeeping per-unit needs across voltage levels (Dommel, via Dugan
  [ref. 16](methodology.md#refs); OpenDSS likewise stores and simulates in actual
  volts/amps/ohms [ref. 9](methodology.md#refs)). This is a choice about
  *representation* and is independent of the units the solver computes in: the
  OPF can solve directly in SI or in an internally-scaled per-unit copy
  (`per_unit`), and which one better conditions the nonlinear program is an open,
  instance-dependent question — see [Units & scaling](opf.md#Units-and-scaling).
- **Sequence coordinates are derived, not the network state.** The
  symmetrical-component transform is an invertible change of coordinates for
  any three-phase phasor vector. What requires a cyclically symmetric network
  (commonly obtained from balanced/transposed parameters) is the stronger step
  of treating the positive-, negative-, and zero-sequence networks as
  **decoupled** [ref. 17](methodology.md#refs). This formulation therefore solves
  in phase/conductor coordinates and uses Fortescue components only as derived
  quantities for sequence-voltage limits. A stray $\sqrt{3}$ or phase-shift
  multiplier is not by itself evidence of a balanced model; the tell is whether
  mutual coupling and unequal conductor states have been discarded.
- **The formulation is rectangular current–voltage (IVR), not power-balance
  polar.** The decision variables are *currents* ($c^r, c^i$) and *rectangular*
  voltages ($v^r, v^i$); KCL is written in currents, and power is a bilinear
  product of the two — not $|V|\angle\theta$ with $P/Q$ bus injections
  [ref. 1, 6](methodology.md#refs). This is why opf.md is written in $c^r_{...}$
  rather than $P_g$. See [Variables](opf.md#Variables).
- **There is no slack/PV/PQ bus typing.** The voltage and angle reference is a
  voltage source's fixed rectangular value, and that source absorbs imbalance as
  a *current* slack; generators are plain current injections, not
  voltage-controlled $P,|V|$ buses. See [Voltage sources](opf.md#Voltage-sources).

## Next steps

- [Data model conventions](conventions.md) — terminal naming, voltage bounds,
  grounding, and how devices reference terminals.
- [Optimal power flow](opf.md) — the variables, per-terminal KCL, and the
  matrix Ohm's-law constraints in full.
