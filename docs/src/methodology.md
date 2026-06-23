# Methodology notes

The physics and linear algebra behind the provenance and integrity checks.
Numbered citations refer to the [references](@ref refs) at the bottom.

## Impedance matrix invariants vs fingerprints

The central design principle: enforce **invariants** — properties no
legitimate transformation of the data can break — as hard checks, and treat
**typical** properties as soft provenance fingerprints.

For the series impedance Z = R + jX of a multiconductor line in wire
coordinates [1, 5]:

- **Reciprocity** (Z symmetric) holds for any passive network — hard
  (`E.PROV.NONRECIPROCAL`).
- **Passivity** (R ⪰ 0) holds by the dissipation argument, and survives
  Kron reduction: elimination of grounded conductors is a Schur complement,
  and Schur complements of accretive matrices remain accretive [10, 11] —
  hard (`E.PROV.NONPASSIVE`).
- **Inductive realisability** (X ⪰ 0, positive diagonals): the inductance
  matrix is PSD by the magnetic-energy argument; matrices with both R, X
  PSD are *sectorial*, and sectorial matrices are closed under Schur
  complementation — so X-PSD is also Kron-invariant
  (`W.PROV.X_NOT_PSD`, `W.PROV.X_NONINDUCTIVE`).
- **Mutual resistance sign**: Carson's earth-return correction [4] makes
  off-diagonal resistance positive (≈ π²·f·μ₀/4 ≈ 0.049 Ω/km at 50 Hz),
  and nearly equal across conductor pairs — a useful fingerprint of
  geometry-derived data, but only *typical*: reductions and fitting can
  perturb it (`I.PROV.NEGATIVE_MUTUAL_R`, soft).

## Sequence-derived matrices and Z₁/Z₀ recovery

A line parameterised from sequence values and transformed back to phase
coordinates (TF spec Appendix A.2; [2] Eq. 148) is **perfectly balanced**:

```
Z = Zₛ·I + Zₘ·(J − I),   Zₛ = (Z₀ + 2Z₁)/3,   Zₘ = (Z₀ − Z₁)/3
```

Geometric (Carson) parameterisations of untransposed lines cannot produce
this, because phase-pair spacings differ. The classifier inverts the
construction — `Z₁ = Zₛ − Zₘ`, `Z₀ = Zₛ + 2Zₘ` — and reports the implied
sequence parameters (`I.PROV.SEQ_DERIVED`). The verdict tiers:

| tier | structure | reading |
|---|---|---|
| `decoupled` | diagonal | positive-sequence only; phases independent |
| `exactly_balanced` | rtol ≤ 10⁻⁹ | sequence-derived or transposition assumed |
| `near_balanced` | rtol ≤ 10⁻² | possibly physical (twisted/bundled symmetric construction) |
| `distinct` | otherwise | consistent with first-principles geometry |

The `near_balanced` tier exists precisely because bundled LV cables (e.g.
the adapted ENWL library [6, 7, 8]) are *physically* near-symmetric — they
must not be mistaken for sequence-derived data.

## The Maxwell sign pattern

Shunt capacitance in wire coordinates is the **Maxwell capacitance matrix**
C = P⁻¹ (P the potential-coefficient matrix from geometry): positive
diagonals, non-positive off-diagonals (coefficients of electrostatic
induction), nonnegative row sums (capacitance to ground), symmetric PSD —
in fact a Stieltjes matrix [5]. OpenDSS `Cmatrix` is exactly this form;
`B = ωC` inherits it.

The classic data error is entering the *pairwise* capacitance c_ij = −C_ij
with the wrong sign. Severity calibration:

- **PSD / nonnegative diagonals** are invariant — Stieltjes (symmetric
  M-) matrices are closed under Schur complementation (grounded-screen
  elimination) and under bundling congruences [11] — so violations are
  warnings (`W.PROV.B_SIGN`).
- A **positive mutual with PSD intact** cannot arise from a clean
  geometry → P⁻¹ → reduction pipeline; it marks fitted, averaged or
  otherwise processed provenance (`I.PROV.B_OFFDIAG`, informational). This
  calibration was validated empirically on the bundled-cable library, where
  small positive mutuals (+0.0011 vs −0.0114 siblings) occur in PSD
  matrices.

## Kron reduction, grounding and earthing zones

A 4-wire network whose every neutral is solidly grounded admits *exact*
Kron reduction of the neutral; conversely, sparse neutral grounding makes
the explicit 4-wire model essential [6, 7]. The checks formalise this:

- **wires per voltage level**: 3-wire LV is flagged as likely Kron-reduced
  (LV is physically 4-wire); 3-wire MV is physical and silent.
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
from *universal* ones (a deliberate length-normalised convention, reported
in the convention statement instead) — the adapted ENWL library [8] is the
canonical universal case, and its single 1 m source jumper per feeder is
the canonical scattered true-positive.

Limit of the method: defaults that PMD resolves at parse time (e.g.
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
(same-voltage-level endpoints, x_pu < 0.5 %, or a non-unity tap) and is
restricted to wye-wye-derived subtypes, since regulators are never
delta-coupled — which keeps genuine 1:1 phase-shifting interconnectors
silent.

This heuristic concerns *imported* data where a regulator was hacked into a
transformer + shunt. The data model itself has **dedicated** regulator objects —
`single_phase_autotransformer` (a fixed-tap step voltage regulator with the
autotransformer shared-neutral coupling) and `open_delta_regulator` (monolithic
open-delta with the galvanic straight-through of the shared phase) — so a
regulator authored natively needs no such pattern-matching. See the
[OPF reference](opf.md) for their constraints and the
[conventions](conventions.md) for the field set. The `from_dss` converter does
not yet emit these subtypes (regulators arriving from OpenDSS are still detected
via the pattern above rather than converted).

## Benchmark readiness

Raw utility-derived feeders are power-flow cases, not OPF benchmarks: they
ship without costed generation (degenerate objective), without voltage
bounds, sometimes without thermal limits [2, 3, 14]. The transmission
community closed the analogous gap with curated, well-posed benchmark
libraries such as PGLib-OPF [13]; the readiness check exists to bring the
same discipline to distribution cases. The readiness check
encodes the augmentation recipe of the PSCC study [3] — explicit slack
generation (loss-minimisation objective), dispatchable DERs with diverse
costs (cost symmetry creates dispatch degeneracy, `I.INT.UNIFORM_GEN_COST`),
voltage envelopes including the sequence/phase-to-neutral bounds whose
presence measurably improves NLP robustness [3], and cross-section-derived
current ratings.

Beyond the structural augmentation check (`I.BENCH.AUGMENTATION`), four
per-network degeneracy flags catch subtler problems that survive augmentation:

- **`W.BENCH.GEN_NO_DOF`** — generators with `p_min ≈ p_max` on every phase
  are fixed injections, not decision variables.  They add model size without
  contributing to benchmark difficulty.
- **`W.BENCH.GEN_ZERO_COST`** — dispatchable generators with a zero cost
  vector make the objective flat in their dispatch direction; the optimal
  solution is primal non-unique and solver-dependent.
- **`W.BENCH.GEN_DEGENERATE_COST`** — pairs of dispatchable generators on the
  same bus or one hop apart with identical cost coefficients allow free
  power redistribution between them.  Benchmarks with this property have
  multiple optima and produce inconsistent comparisons across solvers.
- **`I.BENCH.LOAD_ZERO_PNOM`** — loads with zero real-power setpoint are
  electrically inert and likely represent missing or placeholder data.

## [References](@id refs)

1. M. Deakin, A. Pandey, F. Geth, *Mathematical Model and Data Model for
   Up-To-Four-Wire Distribution System OPF*, IEEE Task Force on
   Benchmarking Multiconductor OPF for Distribution Systems, draft V0.2, 2026.
2. F. Geth, A. C. Chapman, R. Heidari, J. Clark, "Considerations and design
   goals for unbalanced optimal power flow benchmarks," *Electric Power
   Systems Research* 235 (2024) 110646.
3. F. Geth, F. Pacaud, R. Heidari, "Solving Three-Phase Distribution OPF
   with Nonlinear Programming," *PSCC 2026*, Limassol.
4. J. R. Carson, "Wave propagation in overhead wires with ground return,"
   *Bell System Technical Journal* 5 (1926) 539–554.
5. W. H. Kersting, *Distribution System Modeling and Analysis*, CRC Press, 2002.
6. S. Claeys, F. Geth, G. Deconinck, "Optimal power flow in four-wire
   distribution networks: Formulation and benchmarking," *Electric Power
   Systems Research* 213 (2022) 108522.
7. F. Geth, R. Heidari, A. Koirala, "Computational analysis of impedance
   transformations for four-wire power networks with sparse neutral
   grounding," *Proc. ACM e-Energy '22*, 2022, 105–113.
8. R. Heidari, F. Geth, S. Claeys, *Four-wire low voltage power network
   dataset*, CSIRO Data Collection, 2024, doi:10.25919/jaae-vc35; original
   data: ENWL *Low Voltage Network Solutions* project (LCNF closedown
   report, 2014); cable impedances: A. J. Urquhart, M. Thomson, *Cable
   Impedance Data*, figshare, 2019.
9. R. C. Dugan, T. E. McDermott, "An open source platform for collaborating
   on smart grid research," *Proc. IEEE PES General Meeting*, 2011; EPRI
   OpenDSS documentation, incl. *Modeling Regulators as Autotransformers*.
10. F. Dörfler, F. Bullo, "Kron reduction of graphs with applications to
    electrical networks," *IEEE Trans. Circuits and Systems I* 60 (2013)
    150–163.
11. F. Zhang (ed.), *The Schur Complement and Its Applications*, Springer,
    2005 (incl. D. Carlson, T. L. Markham, "Schur complements of diagonally
    dominant matrices," *Czech. Math. J.* 29 (1979) for the M-matrix
    closure).
12. M. Bazrafshan, N. Gatsis, "Comprehensive modeling of three-phase
    distribution systems via the bus admittance matrix," *IEEE Trans. Power
    Systems* 33 (2018) 2015–2029.
13. S. Babaeinejadsarookolaee et al., "The power grid library for
    benchmarking AC optimal power flow algorithms," arXiv:1908.02788, 2019.
14. F. Geth, M. Vanin, D. Van Hertem, "Data quality challenges in existing
    distribution network datasets," *CIRED 2023*, Rome.
