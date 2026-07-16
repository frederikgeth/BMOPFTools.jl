# Background and scope

Why this specification exists, what it does and does not cover, and the design choices
behind it. This page frames the rest of the specification; it introduces no model
content. Where the scope differs from the older Task Force PDF, the difference reflects
what BMOPFTools actually implements.

## Motivation

Distribution networks are unbalanced: single-phase loads, untransposed lines, and
single-phase laterals mean the phases cannot be collapsed to a positive-sequence
equivalent without losing the physics. A faithful optimal power flow (OPF) for
distribution must therefore reason at the level of **individual conductors**.

At the same time, the range of utility problems posed as network-constrained
optimisation has grown — power flow, state estimation, volt-var control, DER scheduling,
dynamic operating envelopes, optimal droop settings. Yet there is little standardisation:
few openly-licensed unbalanced network models exist, so papers rely on ad-hoc modified
cases and results are hard to compare. This specification, with its companion data
library, provides a **common, openly-licensed model** so approaches can be compared
directly — the distribution analogue of transmission-side benchmark libraries.

## Scope: beyond classical OPF

Although "OPF" names this document, the goal is broader than minimising generation cost.
The unifying requirement of the target problems is **an accurate conductor-level
representation of an unbalanced network subject to a selectable set of bounds** — not any
one objective. Bounded cost minimisation is a convenient, solver-comparable
starting point. With fixed demand and one uniform non-negative price on every
real-power injection, minimizing total injection is equivalent to minimizing
real losses. It does not make the nonconvex feasible set or optimum unique. The same physics
underpins maximum load delivery, conservation voltage reduction, dynamic operating
envelopes, and state estimation.

This is why **bounds are optional throughout the data model**: different formulations
activate different subsets of the feasible region. The specification is a reusable
foundation, not infrastructure for a single problem.

## Design choices

- **SI units.** All physical quantities in SI (see [Data input formatting](data-format.md)),
  so the data model commits to no per-unit base. Per-unit is a solver-internal convenience,
  out of scope here.
- **JSON + schema.** Parseable from any language; key–value structure lets extensions add
  nested entries without breaking readers. A JSON Schema provides basic structural checks.
- **Real numbers, not complex.** Every complex quantity is a pair of real fields, and the
  model solves in real variables — for cross-language compatibility (see [Notation](notation.md)).
- **Explicit buses.** Buses are a first-class list with their own terminals and bounds
  — unlike OpenDSS, where buses are implicit in element connectivity.
- **String identifiers.** Buses, lines, loads, etc. carry unique string IDs, not forced
  sequential integers (unlike MATPOWER).
- **Wire coordinates.** Quantities are per-conductor ("wire"), not sequence/symmetrical
  components, keeping the format flexible and extendable to any wire count.

## What is modelled

The specification covers the common branch and nodal elements, with these capabilities:

- **Topology:** meshed networks, electrically parallel branches, radial or looped.
- **Conductors:** 1- to 4-wire lines with full mutual coupling; explicit neutral and earth
  (no Kron reduction); perfect grounding and grounding through impedance.
- **Branch elements:** [lines](line.md), [switches](switch.md), galvanically-isolated
  [transformers](transformer.md) (single-phase, centre-tap, wye–delta, delta–wye,
  n-winding), and non-isolated [regulators](regulator.md) (single-phase autotransformer,
  open-delta).
- **Nodal elements:** [loads](load.md) (constant-power and voltage-dependent ZIP/exponential),
  [generators](generator.md), [shunts](shunt.md), [capacitors](capacitor.md),
  [voltage sources](source.md), and [IBRs](ibr.md) with smart-inverter
  [control profiles](control-profile.md).
- **DC:** an [MVDC/LVDC subsystem](dc.md) with AC/DC converters, enabling converter
  stations, back-to-back SOPs, and MVDC ties.
- **Impedance:** direct linecodes/matrices or [geometry-derived](impedance.md) via Carson/Deri.
- **Time variation:** [time-series](timeseries.md) scaling of parameters (snapshot-based).

## Present limitations

The model deliberately targets features universally required for distribution OPF, not
every possible device. In this version:

- A **single voltage source** (one reference bus).
- **Snapshot** solves — time series scale parameters per instant with no inter-temporal
  coupling (no storage state-of-charge dynamics, no OLTC time-domain control).
- Transformer **saturation** and detailed frequency-dependent effects are not modelled
  (a no-load magnetising shunt *is* supported).
- The default objective is linear generation/dispatch cost; quadratic cost terms are not
  included.

!!! note "Relaxations beyond the original PDF"
    Several restrictions listed in the older Task Force PDF have been lifted in this
    implementation and are documented as first-class features here: voltage-dependent
    (ZIP/exponential) **loads**; **inline per-line impedance/admittance** matrices as an
    alternative to a linecode; the general **n-winding** transformer and a separate
    **regulator** element (autotransformer, open-delta); a magnetising **no-load shunt**
    and internal **neutral grounding**; **continuous tap** optimisation; and the **IBR**
    and **DC** subsystems. Each carries a reconciliation note on its page.

## Out of scope

The format is a practical, lightweight model for OPF research — it does not aim to replace
the Common Information Model (CIM), and it does not prescribe solver software. Its OPF
formulation was inspired by [PowerModelsDistribution](references.md)'s `IVRENPowerModel`,
but has been generalized well beyond it — native JSON data, the full set of element
configurations above, and careful grounding.
