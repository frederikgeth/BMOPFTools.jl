# PowerIO 0.11.7 and Tellegen diagram update

Development plan and checkpoint, 29 October 2026.
Branch: `codex/powerio-update-tellegen-diagrams`.
Base: `5ba6e03ea` (`origin/main`, including the merged OpenDSS semantics work).
Publication status: draft PR requested on 29 October 2026. The migration remains
incomplete until the round-trip release gate below passes.

## Outcome

Support the current registered PowerIO.jl release and teach a concrete case-study
exploration workflow using Tellegen's geographic and schematic single-line
diagrams at network, neighbourhood and equipment scales. Keep numerical model
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

The first full run is **not green**: the main `BMOPFTools` testset reports
45,091 passes, 99 failures, 34 errors and 27 broken tests. This is a development
checkpoint, not a completed compatibility upgrade. The failure groups below are
work items; they must not be removed or reclassified simply to pass the suite.

Current validation checkpoint:

| Gate | Result |
| --- | --- |
| Finding registry | Pass: 381 documented codes |
| Executable export schema/staleness | Pass after regeneration |
| Scientific contracts, executable knowledge and execution interface | Pass |
| Complete package suite | 45,505 pass, 44 fail, 0 errors, 27 broken in the main testset; all failures are round-trip structural checks |
| Full Documenter build | Pass after the SWER example fix described below |
| Screenshot asset and rendered-page review | Pass; full-resolution image links included |

The latest full run reduced the original 99 failures / 34 errors to 44 failures /
0 errors. CVR, geometry, loaded-transformer, projection and nodal-current checks
pass, as do scientific contracts, the 1,201 executable-export checks and the 173
execution-interface checks. The final documentation build succeeds.

Runtime migration is now implemented for CVR and typed load-law evidence. The
geometry, source-boundary and provenance regression tests have been adapted to
the new public IR. The dependency floor remains a work-in-progress change until
the round-trip audit below is resolved. The standalone contract gates do not
establish PowerIO compatibility.

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
- [x] Retain metre/kilometre equivalence, conductor maps, and IR/BMOPF
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

### 2e. Round-trip audit: remaining release gate

The 0.11.7 canonical DSS writer uses exact resistance-cancellation source
circuits, full-admittance shunt circuits, and (where qualified) collapses an
isolated source equivalent back to a native Vsource. Its reader materializes
source impedances and effective line snapshots. Byte/dictionary identity is
therefore a different signal from electrical agreement.

The audit of all 36 feature cases found 710 structural differences, including
81 new unique path/kind pairs relative to the prior snapshot. Do **not** accept a
blanket new golden file or mark former clean cases broken merely to pass tests.
The existing `roundtrip_expected_losses.json` and structural checks remain
unchanged while this is investigated.

- [x] Verify the loaded-transformer oracle uses the imported finite source
  impedance without overwriting its EMF with a physical-bus voltage.
- [x] Fill internal EMF nodes explicitly in the nodal-current test and check KCL
  at the original source port as well as all other non-source nodes.
- [x] Diagnose the tap-projection discrepancy: the six physical nodes agreed
  within 6 microvolts, but three internal EMF nodes were absent in OpenDSS's
  public node list. The test now supplies an explicit source-to-observation map
  and recovers the EMF from OpenDSS's own primitive and solved currents. Both
  comparisons pass at all nine nodes; no tolerance increase or node exclusion.
- [ ] Separate legitimate equivalent-circuit/linecode identity changes from
  new operating-limit or grounding losses, then pin only reviewed changes.
- [ ] Resolve the newly introduced current limit before accepting the snapshot.
  In `pf_1ph_line.dss`, imported
  `line._pio_vsource_source_impedance` has no `i_max`; after `to_dss` and
  `from_dss` it has `[600]` A. This is not just a representation change.
  Setting emitted `normamps=0 emergamps=0` was probed outside the repository:
  it produces `i_max=[0]`, an active zero bound, so that workaround was rejected.
- [ ] Review disappearing grounded-reference declarations together with their
  terminal maps; do not infer correspondence from generated-name prefixes.

The source-equivalent implementations were inspected at PowerIO tag `v0.11.7`:
`powerio-dist/src/dss/read/sources.rs`, `write/sources.rs`, and
`write/thevenin.rs`. No sibling repository was edited. The current-limit defect
also reproduces with PowerIO.jl and JSON3 alone, using a two-line DSS source case.
It is reported upstream as
[PowerIO #762](https://github.com/eigenergy/powerio/issues/762), with the minimal
reproducer, observed output and requested preservation behavior. The BMOPFTools
draft PR retains the failing structural gate while the upstream issue is resolved.

Reproduce the current-limit observation from the repository root:

```julia
using BMOPFTools
net = from_dss("test/data/pf_comparison/pf_1ph_line.dss")
source_bus = net["voltage_source"]["source"]["bus"]
branch = only(id for (id, line) in net["line"] if line["bus_from"] == source_bus)
mktempdir() do dir
    path = joinpath(dir, "roundtrip.dss")
    to_dss(net, path)
    restored = from_dss(path)
    @show get(net["line"][branch], "i_max", nothing)
    @show restored["line"][branch]["i_max"]
end
```

## 3. Produce the visual case-study walkthrough

- [x] Choose the public Norwood model used in Tellegen PR #185.
- [x] Verify the local file matches public Git blob
  `5186ab1fc90017002b8b8235c447b52e36811676` at dataset revision
  `d5ec79b46512a59b56157836a1ceb8459a586d04`.
- [x] Open the unchanged case in deployed Tellegen through the local file picker.
- [x] Capture the geographic whole-network overview before solving.
- [x] Calculate power flow and request the overview; reproduce 16 violations and
  4 warnings. Select transformer `e4c0af231a489a7bd7be` at 184.3% loading.
- [x] Capture the neighbourhood and equipment scales around the same selection.
- [x] Capture the same transformer in schematic layout, coloured by loading.
- [x] Capture its linked conductor bars and multi-wire winding view.
- [x] Write `docs/src/visualization.md` as an exploration sequence, with actions,
  concrete questions, alt text, captions and links to source evidence.
- [x] Record the case SHA-256, capture sequence, unsolved/solved distinction,
  limitations and dataset/basemap notices in the asset attribution file.
- [x] Review the rendered documentation at its normal column width; provide
  full-resolution screenshot links for reading the equipment labels.

The screenshot names are `tellegen-norwood-{overview,neighbourhood,equipment,
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
- [ ] Regenerate/check exports again after the remaining round-trip work.
- [x] Confirm the public file workflow and download work in the built docs;
  inspect the page at documentation-column width for readable images and captions.
- [x] Verify asset links, source notices, image dimensions/size and `git diff --check`.
- [ ] Compare remaining failures with the 0.11.6 base if attribution is ambiguous.
  Julia 1.12 emits upstream OpenDSSDirect precompilation warnings; distinguish
  these from actual test assertions and verify the repository's supported CI Julia.
- [ ] Update the changelog to describe final supported behavior and qualifications.
- [x] Organize reviewable commits: dependency/adapter migration, tests and
  generated metadata; visualization documentation, image assets and this plan.

Completion requires passing numerical and serialization checks as well as a
successful documentation build. Publish this checkpoint as a draft PR; the
remaining round-trip failures prevent treating it as ready to merge.
