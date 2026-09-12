# Issue #393 implementation plan

Issue: [Transformer interoperability: Yd initialization crash, raw-Dict normalization gaps, and tap/excitation conventions](https://github.com/frederikgeth/BMOPFTools.jl/issues/393).

Planning baseline: `534738408d527da400c9c521f481f7b35b98b585` (2026-09-12).
Branch: `codex/393-transformer-interoperability`.
Status: implemented; the original investigation plan is retained below.

## Implementation outcome

- Repaired cyclic Yd/Dy initialization, orientation, fixed-tap ratios, and
  phase-aligned current starts across grounded anchors and terminal permutations.
- Shared parser normalization with raw-dictionary model preparation, preserving
  caller-owned inputs and rejecting conflicting combined/split leakage fields.
- Established center-tap primary impedance referral with independent OpenDSS
  primitives, then corrected both the admittance stamp and optimization equations.
- Preserved historical subtype-specific legacy excitation semantics, corrected
  import/export voltage bases, and documented the explicit per-coil exchange
  representation in the schema and runtime documentation.
- Added four JSON witnesses and five synthetic OpenDSS fixtures, with primitive,
  loaded-state, serialization, provenance, SI/per-unit, and boundary coverage in
  dedicated interoperability test files.
- Fixed solution projection to remove ordinary transformer tap bounds after
  writing the optimized tap, so power-flow validation holds that tap fixed.
- Updated executable provenance and regenerated the exports. Existing scientific
  contract domains remain unchanged; regulator controls and unequal-kVA
  n-winding intake remain separate work.

See `test/data/transformer_interoperability/README.md` for fixture provenance and
the focused test command, and `docs/src/transformer_models.md` for the resulting
subtype/base conventions.

Validation on 2026-09-12: both generated-output checks passed; the scientific
contracts, executable knowledge (908 assertions), and JSON execution interface
(158 assertions) passed. The full suite passed with 12,369 assertions and 39
expected broken/skipped checks, plus the separate 46-assertion piecewise-linear
API test set. OpenDSS and Ipopt coverage executed in this run.

## Findings from the planning baseline

- `ext/BMOPFOpfExt/variables.jl::_set_yd_dy_start_values!` still computes
  `k_next = mod1(k, n_ph) + 1`. The propagation loop runs even when
  `set_voltage_starts=false`, so staged initialization can encounter the same
  indexing failure as the fallback path.
- `ext/BMOPFOpfExt/core.jl::_prepare_working_net` copies or snapshots the input,
  materializes terminal roles, then converts units. It does not run transformer
  leakage migration or explicit core-shunt materialization.
- `src/io/parse_bmopf.jl::_postprocess` already performs both operations.
  `src/io/migrate.jl::_migrate_one_transformer_series_fields!` routes combined
  Yd/Dy leakage to the wye winding, but its parent docstring still says from-side.
  Its split-field detection checks only from-side fields; mixed and partially
  specified representations need explicit precedence or rejection tests.
- Explicit `no_load_shunt` materialization already checks conflicting legacy
  fields, creates winding-connected shunts, removes the source field, and records
  ownership and provenance. Reuse this behavior at the dictionary boundary.
- Tap and legacy excitation behavior needs subtype-specific investigation.
  The issue's numerical comparisons are reported evidence, not independently
  reproduced results or sufficient grounds to choose one engine's convention.

## 1. Capture minimal independent regressions

Create `test/transformer_interoperability_tests.jl` and small package-owned
fixtures under `test/data/transformer_interoperability/`; register the suite in
`test/runtests.jl` under the appropriate dependency gates. Keep parser-only and
build-only tests runnable without OpenDSS or an optimization run.

Start from the standalone issue reproducer: Yd grounded at its last delta
terminal, Dy combined leakage, center-tap split leakage with unbalanced loads,
and single-phase excitation in absent/legacy/explicit forms. Use explicit
ratings and fixed taps, and retain both hand-authored JSON and imported DSS
cases. Record declared schema versions, parser diagnostics, input hashes,
Julia/package versions, PowerIO binding and binary identity when available,
and OpenDSS runtime version. Record inspected external source revisions
separately from the installed runtime.

Establish raw, parsed, and explicitly split/materialized reference inputs.
Keep source-preserving PowerIO round trips, typed electrical-model checks,
BMOPFTools normalization, and solved-physics checks as separate assertions.
Include missing-rating cases that retain diagnostics even when the emitted
source text still contains nonzero impedances.

## 2. Repair initialization and verify winding equations

Change the wrap to `mod1(k + 1, n_ph)` and test every grounded delta anchor,
all six three-phase terminal permutations, and the ungrounded fallback.
Exercise both Yd and Dy, including their different winding orientation, at
unity and non-unity fixed taps. Audit the helper's nominal-only `n_eff` and
propagation direction against the existing connection equations; fix any
additional mismatch exposed by these tests rather than treating no exception
as sufficient evidence.

Verify grounded voltages, finite starts, loop closure, ideal winding-voltage
residuals, and consistent current orientation. Use nonzero source angle and
SI/per-unit covariance. Test the helper's voltage-writing and current-only
paths plus public staged initialization and fused build/solve entry points.
For floating delta cases, test line-to-line equations without imposing a new
physical ground. Use ideal/no-load fixtures where exact initialization
equations are expected; assess loaded states separately after solving.

Extend the compositional coverage in `test/scaling_policy_tests.jl` and connect
the regression to [#365](https://github.com/frederikgeth/BMOPFTools.jl/issues/365).

## 3. Normalize dictionary inputs at the shared preparation boundary

Preferred design: factor/reuse the parser's normalization operations in a
package-internal helper, and call it for the copied/snapshotted working network
before per-unit conversion, indexing, and variable creation. Avoid serializing
to JSON merely to normalize a Julia dictionary. Preserve parser handling of
schema migration, declared terminal roles, aliases, and provenance without
unexpectedly relabeling already normalized inputs.

Cover `solve_opf`, staged `initialize_opf_model`/`build_opf_model`, and other
solve recipes using `_prepare_working_net`, including power flow. Audit result
extraction, per-unit restoration, and transformer loss ownership: the fused
path currently passes the original input to `_from_per_unit`, whereas staged
extraction uses `ctx.net`. Newly materialized shunts and metadata must survive
both routes consistently.

For combined Yd/Dy leakage, retain the existing wye-side referral and correct
the stale docstring. Define field-level handling for missing r or x and
partially split records. Reject conflicting combined/split declarations with
an actionable component-specific diagnostic instead of overwriting values or
silently discarding impedance. Preserve explicit excitation's existing
conflict and winding validation.

Required regressions:

- Raw, parsed, and canonical split/materialized inputs produce equivalent
  electrical models and independently checked states in SI and per-unit.
- Repeated normalization and parse/write/parse do not duplicate shunts, losses,
  migration notes, or ownership records; caller-owned dictionaries are unchanged.
- Static and time-series snapshot inputs receive the same electrical treatment.
- Zero/absent leakage, r-only/x-only, split-only, and mixed/conflicting fields
  are covered, along with invalid winding IDs, nonfinite shunts, and competing
  legacy/explicit excitation.
- The issue's raw Dy case includes leakage losses, and explicit single-phase
  excitation contributes the same loss as its parsed counterpart. Assert
  electrical residuals and toleranced physical quantities rather than only
  solver status or the issue's printed decimal values.

Document the dictionary contract in `docs/src/opf.md` and the parser/API
docstrings. Any representation that cannot be normalized safely must fail
before model construction with explicit remediation.

## 4. Establish tap/ohm referral using an independent primitive

Create a convention table for each supported transformer subtype and import
path: physical winding, voltage and power base, nominal versus tap-adjusted
ohms, effective turns ratio, and leakage referral. Inspect
`ext/BMOPFOpfExt/transformer.jl`, `ext/BMOPFOpfExt/per_unit.jl`,
`src/io/to_ybus.jl`, `src/io/from_dss.jl`, and relevant PMD export code.

Extend `test/admittance_tests.jl` and `test/powerflow_comparison_tests.jl` with
OpenDSS Yprim witnesses at taps below, equal to, and above unity (including
1.06), with nonzero leakage. Begin with center-tap, then check single-phase,
Yd, and Dy; inventory remaining supported subtypes explicitly. Include
unbalanced center-tap loading and zero-leakage boundary branches. Map terminal
identities and current signs explicitly, and use the declared source bases.

First compare primitive matrices and terminal currents at prescribed voltages;
then compare independently checked feasible loaded states. Use explicit DSS
fixtures as the reference so a common import error cannot make two paths appear
correct. Distinguish terminal quantities from inferred internal currents.

Only after this establishes the intended convention, update inconsistent
stamps, conversions, schema descriptions, and `docs/src/transformer_models.md`,
`docs/src/spec/transformer.md`, and `docs/src/spec/transformer-admittance.md`.
Provide migration/version handling if stored-data interpretation changes.
Do not apply a blanket tap-squared correction based on the issue's diagnostic.

## 5. Resolve legacy excitation with #279

Use [#279](https://github.com/frederikgeth/BMOPFTools.jl/issues/279) as the shared
decision for legacy shunt location and total-versus-per-coil semantics. Inventory
each subtype's actual stamp, including center-tap branches and n-winding,
against schema text and import/export behavior. Retain the explicit
`no_load_shunt` representation and provenance as a distinct exchange contract.

Test all supported explicit winding selections, phase-pair banks, center-tap
half-windings, and legacy subtype behavior with per-winding active/reactive
loss checks at non-unity tap. Compare OpenDSS excitation primitives with known
coil voltage/power bases. Resolve discrepancies in code, schema
(`src/validation/schemas/draft_bmopf_schema.json`), and runtime documentation
together; define backward-compatible migration or a versioned interpretation
where necessary. Do not silently reinterpret existing legacy values.

## Validation and completion

Land in reviewable slices: initialization regression/fix; shared normalization
and diagnostics; independently established tap conventions; excitation decision
and compatibility changes. The first two slices can proceed while convention
evidence is gathered, but they do not close all of #393.

For each slice run its focused tests, then the repository gates:

```bash
python3 scripts/generate_finding_registry.py --check
python3 scripts/generate_executable_knowledge.py --check
julia --project=test --startup-file=no -e \
  'using Test, BMOPFTools; include("test/scientific_contract_tests.jl"); include("test/executable_knowledge_tests.jl"); include("test/execution_interface_tests.jl")'
julia --project=test --startup-file=no test/runtests.jl
```

Ensure the OpenDSS and solver suites actually execute in a dependency-complete
CI job; a skipped oracle test does not establish interoperability. Retain
independent terminal KCL, winding-voltage, and power-balance checks as required
by [#386](https://github.com/frederikgeth/BMOPFTools.jl/issues/386).

Follow `ARCHITECTURE.md` for scientific contracts. The existing
`transformer_winding_convention_preservation` / `PSK-000006` checks winding
incidence and ratios and explicitly excludes leakage and excitation. Do not
widen that claim or use it to certify the new comparisons. Any new scientific
contract requires a book-owned stable PSK identity and an explicit supported
domain. Register stable Finding codes and test codes/structured evidence;
include positive, negative, boundary, serialization, and minimized-witness
coverage. Update `knowledge/executable.toml` and regenerate exports whenever
APIs, Findings, fixtures, or tracked source paths change, including hashes of
tracked implementation files. Repin the book-owned pair manifest from the book
only after both sides are reviewed.

Completion requires every acceptance criterion in #393, with the subtype/base
table and independent checks supporting the convention decisions. No claim of
global optimality follows from Ipopt termination. Free-tap/control-law behavior
and the unequal-kVA n-winding import defect in
[#356](https://github.com/frederikgeth/BMOPFTools.jl/issues/356) remain separate
scope; passing these two-port fixed-tap cases does not resolve them.
