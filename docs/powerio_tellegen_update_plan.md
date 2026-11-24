# PowerIO 0.11.7 and Tellegen diagram update

Development plan and checkpoint, 29 October 2026.
Branch: `codex/powerio-update-tellegen-diagrams`.
Base: `5ba6e03ea` (`origin/main`, including the merged OpenDSS semantics work).
Publication status: PR #472; the reviewed export guard and regression audit are
implemented. Merge requires the final local gates and GitHub CI to pass.

## Outcome

Support the current registered PowerIO.jl release and teach a concrete case-study
exploration workflow using Tellegen's geographic and schematic single-line
diagrams at network, neighborhood and equipment scales. Keep numerical model
qualifications, source identity, conductor detail and screenshot attribution
visible throughout the workflow.

## 1. Establish the branch and dependency target

- [x] Fetch `origin/main`; verify the previous branch is contained in it; create
  the new branch without bringing unrelated work forward.
- [x] Verify PowerIO.jl 0.11.7 in the upstream Julia project and General registry.
- [x] Raise the package and test dependency floors to 0.11.7 within the 0.11 series.
- [x] Resolve root, test and docs environments against the registered release.
  Keep their manifests untracked, as required by this repository.
- [x] Update the conversion-guide version references and executable metadata floor.
- [x] Run the existing suite to discover actual migration requirements before
  changing expected outputs.

The initial migration run reported 45,091 passes, 99 failures and 34 errors.
The adapter/source-oracle fixes reduced that to 44 structural-check failures.
The final round-trip audit now distinguishes reviewed representations from the
upstream rating defect; it does not weaken the PF tolerances or hide whole cases
behind expected failures.

Final local validation (Julia 1.12.6, PowerIO 0.11.7, macOS arm64):

| Gate | Result |
| --- | --- |
| Full package suite | 47,224 pass, zero failures/errors, 8 broken/skipped; 3m36.5s |
| Scientific contracts | Pass |
| Executable knowledge | 1,208 checks pass; schema/staleness pass |
| Execution interface | 173 checks pass |
| Finding registry | 382 documented codes pass |
| Full Documenter build | Pass |
| Release metadata, machine entry point, diff whitespace | Pass |

The eight broken/skipped entries include the two focused round-trip defects and
existing optional/oracle skips. GitHub CI on the pushed head remains the final
merge gate. OpenDSSDirect emits upstream precompile warnings locally, then loads
and executes its numerical checks successfully.

## 2. Migrate the PowerIO adapter in order of scientific risk

### 2a. Typed load laws and CVR preservation — first priority

Evidence: PowerIO 0.11.7 exposes DSS model-4 data as
`voltage_model.model = "bounded_exponential"` with `gamma_p`, `gamma_q`,
`v_nom`, `v_low_pu`, `v_min_pu` and `v_max_pu`. CVR exponents are no longer in
the load's source-only `extras`. The current `_restore_dss_intake_fidelity!`
therefore substitutes the legacy default 1/2 for a correctly parsed 1.4/2 law.
The existing CVR import, export and independent OpenDSS tests detect this.

- [x] Read typed exponents without overwriting them with missing-extra defaults.
  Preserve explicit zero and negative exponents and reject invalid/nonfinite
  values or unsupported time-dependent laws.
- [x] Adapt source-behavior evidence to the typed voltage thresholds, retaining
  their source and meaning. Do not promote load-law transition thresholds into
  bus operating limits, and do not silently implement a different load law.
- [x] Cover positive, negative, boundary and JSON round-trip cases. Re-run the
  existing power-versus-voltage OpenDSS oracle for CVR and ZIP models.
- [x] Reassess whether the old CVR repair remains necessary. Remove it only when
  the typed public API and independent numerical evidence support that change.

Implemented: the obsolete CVR rewrite is removed. Intake validates the emitted
exponents against the typed source law and refuses missing, nonfinite, misaligned
or changed exponents. The complete typed law, including `v_low_pu`, is retained
with the threshold record. Nine voltage/exponent combinations agree with the
independent OpenDSS oracle; zero/negative/default exponents, invalid input and
JSON serialization are covered.

Files: `src/io/from_dss.jl`, `test/powerio_regression_tests.jl`,
`test/powerio_numerical_tests.jl`, source-behavior tests, conversion documentation.

### 2b. Explicit source impedance and identity correspondence

Evidence: previously idealized DSS sources now produce an internal EMF bus and
an explicit `_pio_vsource_*_impedance` line. Existing exact branch-count checks,
source provenance assumptions, round-trip semantic comparisons and residual
checks need review. These are not automatically cosmetic differences.

- [ ] Establish the source-to-emitted-bus/branch correspondence from PowerIO's
  public structured evidence. Do not guess it from a naming prefix.
- [x] Preserve the source impedance in imported models. Verify voltages and
  currents against OpenDSS at the original physical buses and declared source
  boundary, using explicit mappings where internal buses are added.
- [x] Update topology-count assertions to distinguish source equivalents from
  authored feeder equipment, while testing that both are represented correctly.
- [ ] Audit fresh DSS export/re-import for repeated source equivalents and
  unexpected changes in terminal identity, impedance, voltage or power.
- [x] Diagnose the loaded-transformer, projected-solution and linearized-Ybus
  failures before changing tolerances or fixture expectations.

Files: `src/io/from_dss.jl`, `src/io/to_dss.jl`, `test/runtests.jl`,
`test/opendss_semantics_tests.jl`, `test/roundtrip_fidelity_tests.jl`,
`test/projection_tests.jl`, `test/ybus_linearized_tests.jl` and oracle helpers.

### 2c. Geometry and effective line snapshots

Evidence: the existing synthetic overhead deck now imports successfully.
Its emitted R/X values match the stored OpenDSS reference values inspected in
the first probe. Each line references an effective linecode such as
`_pio_line_l1`; the original named linecode remains source material. A line
referencing missing geometry or a missing conductor still rejects emission
with `BUILD.DIST.ELECTRICAL_INCOMPLETE` and reader evidence
`READ.DSS.GEOMETRY_UNRESOLVED`.

- [x] Repair the SWER documentation example to select its explicitly named
  backbone spans `l1` and `l2` and follow their effective linecode references.
  Do not stretch an imported source-equivalent branch or assume a surviving
  linecode named `swer`. The complete documentation build passes with this edit.

- [x] Replace the obsolete rejection expectation for valid overhead geometry
  with full R/X/shunt comparisons against the frozen independent OpenDSS oracle.
- [x] Retain meter/kilometer equivalence, conductor maps, and IR/BMOPF
  serialization checks; compare effective electrical values, not obsolete IDs.
- [x] Add a minimized genuinely unresolved-geometry fixture and use it in the
  failure-evidence collector/serialization tests and conversion-guide example.
- [x] Update duplicate-`New` tests to follow the line's explicit linecode
  reference and retain their final-value assertions.
- [x] Document supported snapshot behavior without claiming that BMOPFTools now
  reconstructs all editable OpenDSS geometry definitions.

### 2d. Source provenance and diagnostic changes

- [x] Audit source fields that moved out of `extras` into typed model fields.
  Distinguish effective typed values from authored declarations and source-only
  metadata; do not fabricate provenance for values no longer exposed.
- [x] Preserve structured diagnostic codes/details and conservative treatment of
  unclassified losses, including `EMIT.BMOPF.VALUE_SUBSTITUTED` for bounded loads.
- [x] Update counts only after accounting for each changed diagnostic class.
  Keep mixed-case IDs, truncated attribution and serialization tests meaningful.
- [x] Re-run the real source-field mapping and scope tests, not only mocked ones.

### 2e. Round-trip audit and guarded export — implemented

- [x] Classify all 710 structural observations across 36 feature fixtures. Each
  path/kind has a review category in `roundtrip_expected_losses.json`; explicit
  terminal/source/shunt mappings live in `roundtrip_review.json`.
- [x] Check every original line's full primitive and physical feeder ratings.
  Check named +1/−1 Ω source circuits, complex EMFs, and the four tiny-impedance
  auxiliary circuits independently of their solved voltages.
- [x] Compare complete shunt admittances, including finite grounding, under the
  declared terminal maps. Accept dropped `n_ref` only when no original element
  or winding uses it; retain all used perfect-ground relations.
- [x] Keep the pure-PowerIO two-command missing-rating → 600 A witness for
  [powerio#762](https://github.com/eigenergy/powerio/issues/762) in
  `test/data/powerio_regressions/unrated_source.dss`. Only its rating equality is
  expected to fail. Neutral-role loss has a separate focused witness. No whole
  structural or PF case is expected to fail.
- [x] Default `to_dss` to refusal when static AC re-import cannot establish
  identity correspondence and unchanged declared ratings/bounds. Refusal emits
  `W.EXPORT.DSS_RATING_UNVERIFIED` with indeterminate evidence and leaves files
  untouched. `allow_unverified_ratings=true` permits PF verification with the
  warning retained. JSON remains authoritative for OPF and Tellegen.
- [x] Test opt-in, default refusal, JSON/evidence serialization, unchanged input,
  no file creation/overwrite on refusal, explicit 123 A and legitimate 600 A
  positive controls, zero-A refusal, and out-of-domain dynamic data.

The complete review rationale is in `test/data/roundtrip_expectations.md`.
Source implementations were inspected at PowerIO tag `v0.11.7`; no sibling
repository or generated book manifest was changed. Independent OpenDSS PF
comparison still requires every energized mapped node and keeps its original
2 V / 2% thresholds. The original nonconvergent open-delta deck is an explicit
skip, not agreement.

## 3. Produce the visual case-study walkthrough

- [x] Choose the public Norwood model used in Tellegen PR #185.
- [x] Verify the local file matches public Git blob
  `5186ab1fc90017002b8b8235c447b52e36811676` at dataset revision
  `d5ec79b46512a59b56157836a1ceb8459a586d04`.
- [x] Open the unchanged case in deployed Tellegen through the local file picker.
- [x] Capture the geographic whole-network overview before solving.
- [x] Calculate power flow and request the overview; reproduce 16 violations and
  4 warnings. Select transformer `e4c0af231a489a7bd7be` at 184.3% loading.
- [x] Capture the neighborhood and equipment scales around the same selection.
- [x] Capture the same transformer in schematic layout, colored by loading.
- [x] Capture its linked conductor bars and multi-wire winding view.
- [x] Write `docs/src/visualization.md` as an exploration sequence, with actions,
  concrete questions, alt text, captions and links to source evidence.
- [x] Record the case SHA-256, capture sequence, unsolved/solved distinction,
  limitations and dataset/basemap notices in the asset attribution file.
- [x] Review the rendered documentation at its normal column width; provide
  full-resolution screenshot links for reading the equipment labels.

The screenshot names are `tellegen-norwood-{overview,neighborhood,equipment,
schematic,results}.jpg`. No model JSON is copied into this repository. Geographic
views retain basemap attribution. The deployed UI did not expose a build ID;
the provenance states that limitation instead of inventing a commit.

## 4. Validation and completion criteria

After each runtime migration, run its focused regression and oracle tests.
Once those pass, run the complete gates below once more against the final tree:

```sh
python3 scripts/generate_finding_registry.py --check
python3 scripts/generate_executable_knowledge.py --write
python3 scripts/generate_executable_knowledge.py --check
julia --project=test --startup-file=no -e \
  'using Test, BMOPFTools; include("test/scientific_contract_tests.jl"); include("test/executable_knowledge_tests.jl"); include("test/execution_interface_tests.jl")'
julia --project=test --startup-file=no test/runtests.jl
julia --project=docs --startup-file=no docs/make.jl
```

- [x] Register the minimized missing-geometry fixture in `knowledge/executable.toml`
  and regenerate/check this checkpoint's exports. Existing PSK links and supported
  domains are unchanged; the sibling book's generated manifest is untouched.
- [x] Regenerate/check exports after the round-trip guard and audit (382 Finding codes).
- [x] Confirm the public file workflow and download work in the built docs;
  inspect the page at documentation-column width for readable images and captions.
- [x] Verify asset links, source notices, image dimensions/size and `git diff --check`.
- [x] Attribute the remaining rating defect directly to PowerIO and retain the
  pre-existing neutral-role limitation separately. Julia 1.12 emits upstream
  OpenDSSDirect precompilation warnings; verify the supported CI Julia versions.
- [x] Update the changelog with the export admission change and remaining limitations.
- [x] Organize reviewable commits: dependency/adapter migration, tests and
  generated metadata; visualization documentation, image assets and this plan.

Completion requires passing numerical and serialization checks as well as a
successful documentation build. Push the reviewed change to PR #472, rerun CI,
and merge only after all supported behavior passes. Narrow expected failures
track upstream defects; no new PowerIO release is required for guarded export.
