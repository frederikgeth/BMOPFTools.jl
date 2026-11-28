# [How network diagnostics work](@id Methodology-notes)

This page explains the physics and linear algebra behind three groups of
profiler checks: **provenance** (what an impedance matrix, a default value or a
transformer pattern reveals about where the data came from), **integrity**
(grounding, earthing zones and voltage references) and **benchmark readiness**
(whether a case poses a well-defined OPF problem). Read it alongside
[Analysis & reports](analysis.md) when a finding needs more than its message.
Solver coordinates and starting values are covered in
[Scaling, initialization and diagnostics](numerical_workflows.md). Numbered
citations refer to the [Bibliography](@ref refs).

## Impedance matrix invariants vs fingerprints

The central design principle: report a violated **invariant** — a property
no legitimate transformation of the data can break — as a data defect (an
error or a warning), and treat **typical** properties as soft provenance
fingerprints.

For the series impedance Z = R + jX of a multiconductor line in wire
coordinates [1, 5]:

- **Reciprocity** (Z symmetric) holds for ordinary passive lines in
  reciprocal media (isotropic conductors and earth — no gyrotropic or
  otherwise non-reciprocal materials) — hard (`E.PROV.NONRECIPROCAL`).
- **Passivity** (R ⪰ 0) holds by the dissipation argument, and survives
  Kron reduction: elimination of grounded conductors is a Schur complement,
  and Schur complements of accretive matrices remain accretive [10, 11] —
  hard (`E.PROV.NONPASSIVE`).
- **Inductive realizability** (X ⪰ 0, positive diagonals): the inductance
  matrix is PSD by the magnetic-energy argument; matrices with both R, X
  PSD are *sectorial*, and sectorial matrices are closed under Schur
  complementation — so X-PSD is also Kron-invariant
  (`W.PROV.X_NOT_PSD`, `W.PROV.X_NONINDUCTIVE`).
- **Mutual resistance sign**: Carson's earth-return correction [4] makes
  off-diagonal resistance positive (≈ ω·μ₀/8 = π·f·μ₀/4 ≈ 0.049 Ω/km at 50 Hz),
  and nearly equal across conductor pairs — a useful fingerprint of
  geometry-derived data, but only *typical*: reductions and fitting can
  perturb it (`I.PROV.NEGATIVE_MUTUAL_R`, soft).

Severity follows the consequence of a violated invariant. Asymmetry and a
resistance matrix that is not PSD are errors: the first breaks reciprocity, the
second lets the line deliver active power. The reactance and susceptance
checks (`W.PROV.X_NOT_PSD`, `W.PROV.X_NONINDUCTIVE`, `W.PROV.B_SIGN` below) are
warnings. For a symmetric Z the absorbed active power is Iᴴ R I whatever X is
(likewise Vᴴ G V for a shunt, whatever B is), so a violation there makes the
data physically unrealizable without creating an active-power source.

## Sequence-derived matrices and Z₁/Z₀ recovery

A line parameterized from sequence values and transformed back to phase
coordinates (TF spec [1], Appendix A.2 / Eq. 148) is **perfectly balanced**:

```
Z = Zₛ·I + Zₘ·(J − I),   Zₛ = (Z₀ + 2Z₁)/3,   Zₘ = (Z₀ − Z₁)/3
```

Geometric (Carson) parameterizations of *generic asymmetric* untransposed
geometries do not produce this, because their phase-pair spacings differ.
(Symmetric untransposed arrangements can also be balanced.) The classifier inverts the
construction — `Z₁ = Zₛ − Zₘ`, `Z₀ = Zₛ + 2Zₘ` — and sorts each linecode
into a tier:

| tier | structure | reading |
|---|---|---|
| `decoupled` | near-diagonal phase series block | coupling/self spread below 10⁻⁶; other factors unassessed |
| `exactly_balanced` | rtol ≤ 10⁻⁹ | suggests sequence parameterization or a symmetry assumption; physical symmetry is an alternative |
| `near_balanced` | rtol ≤ 10⁻² | approximate balance signature; review conductor symmetry and modeling assumptions |
| `distinct` | otherwise | nonuniform structure; consider geometry and any prior neutral elimination |
| `unassessed` | missing/incompatible X block | full complex-matrix signature unassessed |

`I.PROV.SEQ_DERIVED` reports `exactly_balanced` linecodes with their implied
Z₁ and Z₀. If the sequence reading is right, phase-pair asymmetry is absent from
the inspected block, although retained neutral coupling and other equipment can
still create unbalance. Check the source data and whether the intended network
shares the symmetry assumption.

## Impedance provenance hints

Linecode matrices carry clues to construction choices. Their engineering
consequences depend on which conductors and couplings the model retains:

| Pattern | Possible origin | Engineering implications |
|---|---|---|
| negligible phase-block coupling (`I.PROV.DECOUPLED_PHASES`) | per-phase simplification | uniform self terms give approximately Z₀ = Z₁; unequal self terms can still couple sequence networks. Diagonal structure does not exclude prior reduction |
| three-wire, no PN pattern (`I.PROV.IMPEDANCE_TRANSFORM_KR`) | prior neutral elimination (weak hint) | a zero-neutral-voltage model cannot predict neutral rise when inappropriate; total dissipation can remain represented, while separate neutral attribution needs recovery data |
| uniform R, mutual ≈ ½ self (`…_PN`) | phase-to-neutral equivalent | exact under the single-grounded/no-earth-current assumptions; similar conductor resistances explain the pattern, while accuracy depends on earth-current assumptions |
| uniform R and X (`…_MPN`) | modified phase-to-neutral equivalent | review PN earth-current assumptions and the additional reactance-symmetrization approximation |

The equal-self, equal-mutual pattern (`I.PROV.SEQ_DERIVED`) is the
`exactly_balanced` tier above.

**Extra conductors.** A conductor outside the inspected phase block can coexist
with a sequence-built phase block: OpenDSS can materialize a coupled
four-conductor matrix from sequence values, or a modeler can supply neutral
parameters separately. Shape alone does not select transposition over sequence
parameterization, and a balanced phase block can still have an explicit neutral
that introduces phase-to-neutral unbalance. An extra conductor with negligible
coupling to the phases is flagged as a possible placeholder or simplified
neutral.

**Diagonal phase blocks.** The per-phase simplification hint also covers
unequal diagonal terms, which may couple the sequence networks. A Schur
reduction subtracts its correction from the original mutuals and can cancel
them, so diagonal data retain an unresolved origin: possible prior reduction is
listed as an alternative, and the hint does not declare Kron history impossible.

**The PN transformation.** Its exact reference domain has no conductor-to-earth
shunts, no device current injection into earth, and one grounding point per
continuous neutral section. Neutral current and voltage can be recovered from
source information in that domain. Multiple earth-return paths can invalidate
its assumptions; grounding impedance alone does not determine the error. An R
mutual/self ratio near one half is a fingerprint of similar phase and neutral
resistances, while the transformation itself also applies to unequal
conductors.

**The Kron hint** is matrix-only, so its context separates known LV use without
a represented neutral, known MV/HV-only use, unused templates, and unassessed or
mixed use. Missing nominal-voltage or terminal-map evidence does not establish
MV/HV use, and unassessed uses keep their conditional neutral implications.
Exactly balanced candidates cross-reference `I.PROV.SEQ_DERIVED`.
`I.PROV.KRON_LIKELY` is the network-level counterpart, for an LV level without a
neutral carried by any branch.

Converter-generated source equivalents are classified but never flagged.
Scientific checks for [reduction and positive-sequence
applicability](scientific_contracts.md) keep their own documented domains; these
hints do not widen them. Each hint carries review guidance
([reading a hint](analysis.md#Evidence-qualified-profiler-results)); its
evidence keys are listed under
[Impedance hint evidence](analysis_results.md#Impedance-hint-evidence).

## The Maxwell sign pattern

Shunt capacitance in wire coordinates is the **Maxwell capacitance matrix**
C = P⁻¹ (P the potential-coefficient matrix from geometry): positive
diagonals, non-positive off-diagonals (coefficients of electrostatic
induction), nonnegative row sums (capacitance to ground), symmetric PSD —
in fact a Stieltjes matrix [5]. OpenDSS `Cmatrix` is exactly this form;
`B = ωC` inherits it.

The classic data error is entering the *pairwise* capacitance c_ij = −C_ij
with the wrong sign. Severity calibration:

- **PSD / nonnegative diagonals** are invariant, so violations are
  warnings (`W.PROV.B_SIGN`).
- The **sign pattern** is invariant under every exact reduction. Grounding a
  conductor (a screen bonded to earth, V = 0) keeps a principal submatrix of
  C; eliminating a floating conductor (zero net charge) takes a Schur
  complement of C; bundling conductors at equal potential is the congruence
  SᵀCS with a 0/1 aggregation matrix S; transposition averages permuted
  copies. Principal submatrices, congruences by S and convex combinations
  keep off-diagonals ≤ 0 directly, and Schur complements of Stieltjes
  matrices are Stieltjes [11]. A check on 400 randomly placed conductor
  groups, computed with an accurate (charge-simulation) solver and put
  through about a thousand random grounding, floating, bundling and
  transposition steps, found no off-diagonal above zero.
- A **positive mutual with PSD intact** (`I.PROV.B_OFFDIAG`, informational)
  therefore comes from how the matrix was computed or entered, not from a
  reduction. The common cause is the thin-wire potential-coefficient formula
  ``P_{ii} = \ln(2h_i/r_i)/(2\pi\varepsilon)`` applied to thick conductors
  at close spacing, which ignores the redistribution of charge around each
  conductor's surface. For four touching insulated cores (an aerial bundled
  cable or a four-core underground cable) it puts a small *positive* mutual
  between diagonally opposite cores, where an accurate solution gives a
  small negative one (about +2.5 pF/m against −3.4 pF/m for 95 mm² aerial
  bundled cores). LineConstants-style tools, including
  [`overhead_line_constants`](@ref), use this formula, so matrices for
  tightly bundled conductors carry the finding by construction; the
  error is in the opposite-core mutual, and the matrix stays passive.
  Sequence data with C₀ > C₁ (the mutual is (C₀ − C₁)/3) and a sign-convention
  mix-up give the same pattern.

## Kron reduction, grounding and earthing zones

!!! note "Two Kron reductions"
    On this page *Kron reduction* means eliminating a grounded **conductor**
    (usually the neutral) from a line's impedance matrix
    ([`kron_reduce_neutrals`](@ref)). Eliminating whole **buses**, as in
    error-bounded network reduction ([`kron_reduce_buses`](@ref)), is the
    same Schur complement applied to the nodal admittance matrix, under a
    different condition: zero current injection at the eliminated nodes,
    rather than zero voltage drop along the neutral. See
    [Network reduction](@ref network-reduction).

A 4-wire network whose every neutral is solidly grounded admits *exact*
Kron reduction of the neutral; conversely, sparse neutral grounding makes
the explicit 4-wire model essential [6, 7]. The checks formalize this:

- **wires per voltage level**: absent represented LV neutrals are reported
  descriptively. A possible reduction history needs authored source evidence;
  wire count alone does not establish it.
- **neutral continuity graph** (lines + closed switches carrying the
  neutral; transformer windings do not pass it): every section must reach a
  grounding — perfect grounding, a grounding shunt, or a source that pins
  the neutral. Floating sections leave the zero-sequence path undefined.
- **earthing zones**: per *galvanic island* (transformer windings are
  galvanic separations) the star-point earthing and the count of downstream
  neutral electrodes classify the likely earthing system. Downstream
  neutral electrodes can only exist in multi-earthed systems
  (TN-C-S/PME/MEN); a source-earthed-only 4-wire zone is genuinely
  ambiguous between TN-S and TT, because the protective-earth side of
  installations is **not representable** in a power-flow data model — the
  tag states the ambiguity rather than guessing. MV zones use MV vocabulary
  (solidly/impedance-earthed/isolated).

## Voltage reference per galvanic island

Each galvanically isolated island needs at least one voltage reference or
its voltages are defined only up to a shift — the nodal admittance matrix
is rank-deficient. This is the IEEE 123-bus "bus 610" defect that OpenDSS
silently patches with a phantom shunt [2, 12]. A shunt anchors an island
only if its admittance has nonzero row sums (Y·1 ≠ 0): a pure delta
capacitor bank does not.

## OpenDSS default fingerprints

When a `.dss` file omits a property, OpenDSS substitutes a documented
default [9]; after conversion these are indistinguishable from deliberate
data except by value. The fingerprint table:

| field | default | consequence if accidental |
|---|---|---|
| line constants | r1=0.058, x1=0.1206, r0=0.1784, x0=0.4047 Ω/kft | a fictitious 60 Hz overhead line (≈336 ACSR) |
| `normamps` | 400 A | un-engineered thermal limits |
| transformer `xhl` / `%r` | 7 % / 0.2 per winding | placeholder impedance |
| load `pf` | 0.88 | reactive demand never specified |
| `basekv` / `kv` | 115 / 12.47 kV | US default voltages |
| Vsource `MVAsc3`, `X1R1` | 2000 MVA, 4 | fictitious fault level |
| line `length` | 1.0 | un-set lengths |

The length check distinguishes *scattered* exact-1.0 values (default leak)
from *universal* ones (a deliberate length-normalized convention, reported
in the convention statement instead) — the adapted ENWL library [8] is the
canonical universal case, and its single 1 m source jumper per feeder is
the canonical scattered true-positive.

Limit of the method: defaults that the importer resolves at parse time (e.g.
`basefreq` mismatches) leave no trace in the converted data and cannot be
fingerprinted downstream.

## Regulators and autotransformers

OpenDSS has no first-class regulator branch; modelers encode them either as
a near-1:1 wye transformer plus a RegControl (which does not convert), or —
per the EPRI autotransformer guidance [9] — as two windings on the *same
bus* (common + ~10 % series winding), kVA rated at the **series winding**,
with a negligible-impedance jumper. Both freeze a control device into a
fixed branch; the second bundles three benchmark pitfalls of [2] in one
pattern (self-loop topology, deliberate tiny impedance, a rating that reads
as 10× overload). Detection (`W.PROV.REGULATOR_PATTERN`): the self-loop is
near-conclusive on its own; the 1:1 form requires corroboration
(same-voltage-level endpoints, x_pu < 0.5 %, or a non-unity tap), a
winding-voltage ratio `v_nom_to / v_nom_from` between 0.85 and 1.176, and the
`single_phase` subtype. The delta-coupled `wye_delta` and `delta_wye` subtypes
are never matched, since regulators are never delta-coupled, which keeps
genuine 1:1 phase-shifting interconnectors silent.

This heuristic concerns *imported* data where a regulator was hacked into a
transformer + shunt. The data model itself has **dedicated** regulator objects —
`single_phase_autotransformer` (a fixed-tap step voltage regulator with the
autotransformer shared-neutral coupling) and `open_delta_regulator` (monolithic
open-delta with the galvanic straight-through of the shared phase) — so a
regulator authored natively needs no such pattern-matching. See the
[OPF reference](opf.md) for their constraints and the
[conventions](conventions.md) for the field set. The `from_dss` converter does
not emit these subtypes: regulators arriving from OpenDSS are detected via the
pattern above rather than converted.

## Benchmark readiness

Raw utility-derived feeders are power-flow cases, not OPF benchmarks: they
ship without costed generation (degenerate objective), without voltage
bounds, sometimes without thermal limits [2, 3, 14]. The transmission
community closed the analogous gap with curated, well-posed benchmark
libraries such as PGLib-OPF [13]; the readiness check exists to bring the
same discipline to distribution cases. The readiness check
encodes the augmentation recipe of the PSCC study [3] — explicit slack
generation (loss-minimization objective), dispatchable DERs with diverse
costs (`I.INT.UNIFORM_GEN_COST` screens uniform costs without establishing degeneracy),
voltage envelopes including the sequence/phase-to-neutral bounds whose
presence measurably improves NLP robustness [3], and cross-section-derived
current ratings.

Beyond the structural augmentation check (`I.BENCH.AUGMENTATION`), four
per-network screens describe features worth inspecting after augmentation:

- **`W.BENCH.GEN_NO_DOF`** — generators with `p_min ≈ p_max` on every phase
  have fixed active power; reactive dispatch may still be controllable.
- **`W.BENCH.GEN_ZERO_COST`** — dispatchable generators with a zero cost
  vector have no direct active-generation cost. Network losses, upstream
  costs and constraints can still determine their dispatch.
- **`W.BENCH.GEN_DEGENERATE_COST`** — pairs of dispatchable generators on the
  same bus or one hop apart with equal representative costs warrant checking
  for interchangeable controls. The screen does not establish non-uniqueness.
- **`I.BENCH.LOAD_ZERO_PNOM`** — loads with zero real-power setpoint are
  zero in active power; reactive demand may remain. Inspect both P and Q.
