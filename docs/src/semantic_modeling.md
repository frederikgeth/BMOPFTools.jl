# [Object identity & semantic projection](@id object-identity)

## The label test

BMOPFTools models a network as a set of objects that pass one test:

> **Could two engineers, shown the thing in the real world, agree on its label?**

A capacitor bank, a generator, a transformer, an IBR (inverter-based resource), a shunt reactor are
real assets with stable identities. The data model aims to carry *those* objects —
not whichever encoding a particular solver found convenient. This is the same
stance taken at ingest (ingestion is a [semantic projection](conversion.md#ingest-philosophy),
not a transcode); here we state it as a model-wide principle, because it governs
the validation findings and the [fix recipes](augmentation.md#fix) just as much as
`from_dss`.

The goal hierarchy is the same one stated for ingest:

> **Semantic faithfulness + data-quality leverage  >  encoding fidelity.**

You cannot run a meaningful data-quality check — *is this DER inverter-interfaced?
is this a capacitor or a reactor? does this branch actually change voltage
level?* — on a model that has dissolved the asset into a generic admittance, a
negative load, or a per-unit line. Reconstructing the named object is the price of
being able to reason about the network at all, and it is exactly what makes the
benchmark-grade data model more than a re-encoding of the source
([ref. 2](methodology.md#refs), [ref. 14](methodology.md#refs)).

## Why tools abuse representation

Most representational collisions are not modelling errors so much as **encoding
conveniences of a particular solver**, frozen into the data:

- **Admittance solvers forbid exact zero.** A `Ybus`/Newton tool inverts
  impedance, so a zero-impedance branch is singular; practitioners insert a tiny
  placeholder, and *missing* data ends up encoded the same way. The IVR
  formulation here treats impedance as a *coefficient*, so exact zero is well-posed
  and better-conditioned — the placeholder is now the problem, not the cure (the
  worked example below traces this through to the solver numerics).
- **Backward-forward sweep wants negative loads.** Embedding a DER as a negative
  `PQ` load lets an unmodified distribution load-flow handle generation
  ([ref. 5](methodology.md#refs)) — at the cost of erasing that it is a
  generator/IBR with its own bounds and controls
  ([ref. 28](methodology.md#refs)).
- **`Ybus` embeds a constant-impedance load as a shunt.** A constant-`Z` load is
  `Sⱼ/|Vⱼ|²` on the bus admittance diagonal ([ref. 26](methodology.md#refs)); once
  there it is indistinguishable from a real shunt or capacitor.
- **Per-unit "eliminates" the transformer.** Textbooks choose voltage bases on the
  turns ratio so the ideal transformer disappears and only a series impedance
  remains — a line. This is sound for a balanced single-line study and disastrous
  for a four-wire model, where the transformer is a *galvanic boundary* carrying
  the vector group, the grounding, and the voltage-level change
  ([ref. 16](methodology.md#refs), [ref. 17](methodology.md#refs)).
- **Coordinate transforms discard conductor identity.** Symmetrical components and
  Kron reduction are projections that throw away the per-conductor, per-terminal
  data a four-wire model and a non-expert data collector actually need
  ([ref. 10](methodology.md#refs), [ref. 17](methodology.md#refs)); see the
  [buses & terminals primer](terminals_primer.md).

The IEC Common Information Model takes the opposite, asset-first stance — explicit
objects, terminals and connectivity nodes as the unit of exchange
([ref. 23](methodology.md#refs), [ref. 27](methodology.md#refs)) — and is the
closest external precedent for what this data model reconstructs.

## From representation to data artefacts to weak numerics

Representational limits do not stop at mislabelling an asset; they corrupt its
*parameter values*, and the corrupted values then degrade the optimisation
solver. The chain is:

> **encoding limit  →  data artefact  →  ill-conditioned nonlinear program.**

The clearest case is **missingness**. An admittance-based power-flow tool inverts
impedance, so it cannot accept an exactly-zero series impedance. When a
transformer's leakage is unknown — or physically negligible — the value is
therefore not recorded as *absent*; it is written as a small magic number that
keeps the solver's `Y = Z⁻¹` finite. The fact "this parameter is missing" has been
**projected onto "this parameter is small but present"**, and nothing in the file
then distinguishes a genuine tiny leakage from an "I don't know." That is a data
artefact created purely by the source representation, not by the network.

Carried into a nonlinear program the artefact is actively harmful — and, crucially,
the value the source tool was *forced* to write is the one the optimiser handles
*worst*. In the current-voltage (IVR) formulation the series impedance is a
**coefficient** in the winding voltage-drop equation `V_fr − N·V_to = R·I − X·jI`,
not an inverted admittance. A tiny `Z` leaves the series current almost
unconstrained by that equation — a near-flat direction that ill-conditions the
Jacobian and the reduced Hessian, forcing inertia corrections and slowing or
failing convergence — whereas **exact zero** collapses cleanly to the well-posed
ideal-transformer constraint `V_fr = N·V_to`
([ref. 3](methodology.md#refs), [ref. 19](methodology.md#refs),
[ref. 20](methodology.md#refs)). So the admittance-era workaround (small ≠ 0) is
exactly the encoding a modern NLP solver wants least; the representation that is
*honest about the data* (zero, or an explicit "unknown") is also the one with the
best numerics.

The remedy follows directly from the object-identity stance: make the canonical
model able to **say what the source tool could not** — represent
missingness/negligibility as **exactly zero** (well-posed here), and have the
data-quality layer detect the magic-number artefact and offer to snap it
(`W.DOM.XFMR_LOW_IMPEDANCE` + the `apply_snap_transformer_impedance` fix; the
near-zero-impedance line → `switch` fix). Choosing the right *value*, like
choosing the right *object*, is therefore not cosmetic: it is what gives the
downstream optimisation good numerics.

## [The line-impedance fidelity ladder](@id impedance-ladder)

The object-identity principle has a *within-asset* corollary. A line's electrical
behaviour can be recorded at three fidelity levels, and they are not
interchangeable — each higher level expresses and lets you *verify* strictly more
than the ones below:

1. **Geometry** (`wire_data` + `line_geometry`) — the physical construction:
   which conductor, of what material, at which coordinates, over what earth. The
   asset as an engineer would describe it.
2. **Per-length matrices** (`linecode` + `length`) — the series/shunt matrices
   the geometry compiles to *at one frequency*, shared across every line of that
   type and scaled by length.
3. **Total matrices** (inline `R_series_`/`X_series_` on the line) — the
   impedance of one specific section, frozen; nothing is shared, nothing scales.

BMOPFTools accepts all three but **prefers them in that order**, and the
preference is not stylistic — it is the same "data-quality leverage > encoding
fidelity" stance, applied one level down:

- **Realizability is checkable at the top, not the bottom.** Given geometry,
  *"is this physically realisable?"* is a set of **forward** checks on the
  construction data — GMR ≤ radius, conductors do not overlap, cable layers nest
  (`E.DOM.WIRE_GMR_EXCEEDS_RADIUS`, `E.DOM.GEOM_CONDUCTOR_OVERLAP`,
  `E.DOM.WIRE_CABLE_LAYERS`). Given only a matrix, the same question is the
  **inverse Carson problem**: you must try to recover a geometry that *could*
  have produced it — and there may be none, or many. A bare matrix that is
  subtly non-physical is then catchable only by weaker, after-the-fact symptoms
  (`E.PROV.NONRECIPROCAL`, `E.PROV.NONPASSIVE`, or the per-metre plausibility
  guard `W.DOM.LINE_IMPLIED_PER_LENGTH`), never by construction.
- **A matrix is frozen at one frequency; geometry is not.** Compiled matrices
  hold only at the frequency they were computed for — which is why
  `line_geometry.frequency` is required and stamped into every linecode's
  `derivation`. The geometry itself is frequency-free: the same `wire_data`/
  `line_geometry` recompiles at 50 or 60 Hz, and — unlike a frozen matrix — it
  retains the physical description a *frequency-dependent* (harmonic) impedance
  method would need (per-frequency skin effect and earth return). The present
  `compile_linecode` engine is fundamental-frequency (constant-`r_ac` modified
  Carson, and it warns above the critical skin frequency); a harmonic-capable
  model is future work, but only the geometry keeps the door open to it — a
  frozen 50 Hz matrix cannot be re-derived at harmonics at all.
- **Geometry is the better feature for learning problems.** Physical parameters
  (spacings, GMRs, heights, soil resistivity) are low-dimensional, bounded, and
  interpretable; the impedance matrix is their nonlinear, over-parameterised
  image, whose entries must *jointly* satisfy Carson to be meaningful.
  Estimation, sensitivity, and identifiability are naturally posed on the
  geometry, not on the 16 correlated entries of a 4×4.
- **Provenance stays live.** A geometry-compiled linecode keeps a
  `line_geometry` back-reference, so the analysis layer can **re-derive and
  cross-check** it (`W.PROV.GEOMETRY_MISMATCH`); a hand-edited or stale matrix is
  caught. A bare matrix has no such anchor.

The lower levels remain first-class for the cases that genuinely need them — a
finite-element or measured impedance for one specific section (inline totals),
or an imported linecode whose geometry was never recorded (`source="import"`).
But when the construction data exists, capturing it as geometry — and letting
the matrices be a *derived, provenance-linked* artefact — is what keeps the case
verifiable, re-frequency-able, and learnable rather than a frozen numerical
blob. See the [line-geometry workflow](tutorial_line_geometry.md) and the
[impedance conventions](conventions.md#Lines,-linecodes-and-matrices).

## Catalog of representational collisions

Each row is a place where one real asset is commonly encoded as another. The data
model projects back onto the canonical object; where a detector exists it emits a
finding (see the [finding-code reference](findings.md)), and some collisions also
have an opt-in [fix-recipe](augmentation.md#fix) conversion.

| Encoded as | Real asset | Why it happens | Detector / fix |
|---|---|---|---|
| generic `shunt` (G≈0, +B) | **capacitor** bank | `Ybus` shunt embedding; OpenDSS `Capacitor` lowered to admittance | `I.PROV.SHUNT_LIKELY_CAPACITOR` + `apply_shunt_to_capacitor` conversion |
| generic `shunt` (G≈0, −B) | **reactor** | same admittance embedding | `I.PROV.SHUNT_LIKELY_REACTOR` |
| constant-impedance `load` | load **model**, or a shunt | `Sⱼ/|V|²` on the `Ybus` diagonal | kept as a load model (ZIP); not silently a shunt |
| negative `load` | **generator** / IBR | negative-`PQ` sweep convention | `I.DOM.NEGATIVE_LOAD` |
| `generator` that only absorbs | **load** | sign / object-class mix-up | `I.DOM.NEGATIVE_GENERATION` |
| `generator` at LV | **IBR** (DER) | no IBR object in source tool | `I.DOM.GEN_LIKELY_IBR` |
| `line` between voltage levels | **transformer** | per-unit elision of the ideal transformer | `W.PROV.LINE_BRIDGES_VOLTAGE_LEVELS` |
| near-zero-`Z` `line` | **switch** | admittance-solver placeholder | `apply_low_impedance_to_switch` fix |
| tiny placeholder leakage | exact-zero / real `%Z` | admittance solver forbids zero | `W.DOM.XFMR_LOW_IMPEDANCE` + `apply_snap_transformer_impedance` |
| 3 × single-phase `voltage_source` | one polyphase **source** | OpenDSS `Circuit` + per-phase `VSource` | per-phase merge + `W.PROV.SOURCE_*` |
| grounding `shunt` (tiny Z) | a **perfect ground** | impedance placeholder for a bonded neutral | `apply_perfect_grounding` fix |

Two principles keep these projections safe, the same ones that govern ingest:
every inference is **surfaced as a finding** with a confidence tag (never a silent
assumption), and every applied change is **recorded in the transformation
manifest**. A heuristic that guesses wrong is therefore diagnosable, and the
conversion is reproducible.

## References

See the [methodology references](methodology.md#refs). The central citations for
this page are [ref. 14](methodology.md#refs) (data-quality challenges in existing
distribution datasets — the catalogue of real abuses), [ref. 2](methodology.md#refs)
(maintaining semantics in the benchmark data model), [ref. 16](methodology.md#refs)
and [ref. 17](methodology.md#refs) (why the transformer and the conductor-level
model cannot be dissolved), and [ref. 23](methodology.md#refs)/[ref. 27](methodology.md#refs)
(the CIM asset-first precedent), with [ref. 26](methodology.md#refs) (constant-`Z`
load ≡ shunt admittance) and [ref. 28](methodology.md#refs) (IBR-based
resources as a distinct asset class) grounding specific rows.
