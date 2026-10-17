# Correctness and usability PR plan

Status: active; agreed priorities from the 2026-10-18 issue review. Baseline:
`df6bc42bf` on main. This file tracks delivery, not a new scientific claims ledger.

## Goal

Make supported OPF models enforce declared device limits consistently, reject
invalid terminal/index mappings, and report transformer and inverter behavior
with independently verified evidence. Deliver small, tested draft PRs for human
review. **Never merge these PRs or enable auto-merge.** Passing checks means ready
for review, not permission to merge.

## Scope and review policy

The six priorities are #89, #116, #408/#409, #268, #95, and #413. Parsing,
external-format export and PowerIO work are excluded. JSON evidence round trips
and the repository's generated executable-knowledge checks remain required
validation. #404 and other objective features, #410 declaration hygiene, #176
loop diagnostics, backend/performance experiments and broader physics extensions
are deferred.

The 2026-10-18 cross-branch review found 35 conflicting branch pairs, mostly in
generated metadata, plus test includes and documentation. The feature PRs now
form one integration/review stack: **#438 → #439 → #440 → #441 → #442 → #443 →
#444 → #445 → #446**. Tracker #437 remains based on main. This ordering makes the
combined behavior CI-testable before any human merge; it does not imply every
slice has a runtime dependency on its predecessor. Review each incremental PR
diff. Both sides' test includes and documentation are retained, and generated
records are rebuilt from the combined source. No PR is merged or auto-merged.

The user's cross-branch conflict-fix request authorizes this restacking, replacing
the original independent-branch/retarget-after-merge plan. Preserve exact old-head
leases when publishing rewritten branches. Each PR body records its current
base, compatibility changes, test edits, validation and remaining limitations.

## Delivery tracker

Unchecked means outstanding, not implicitly covered by another row. Replace
planned branch names with actual branch/PR links as work starts. Issue completion
requires all its acceptance criteria; partial PRs use `Refs`, not `Closes`.

| Slice | Issue | Planned branch | Dependency | Status / PR |
|---|---|---|---|---|
| P0 | All | `codex/correctness-usability-plan` | None | Draft [#437](https://github.com/frederikgeth/BMOPFTools.jl/pull/437) |
| P1 | #89 | `codex/89-reactive-capability-limits` | None; base main | Draft [#438](https://github.com/frederikgeth/BMOPFTools.jl/pull/438); combined local gates/full suite pass; exact-head CI in #437 review record |
| P2 | #89 | `codex/89-minimum-power-factor` | Review stack on #445; see review record below | Draft [#446](https://github.com/frederikgeth/BMOPFTools.jl/pull/446); combined local gates/full suite pass; exact-head CI in #437 review record |
| P3 | #116 | `codex/116-transformer-current-ratings` | Review stack on #438; see review record below | Draft [#439](https://github.com/frederikgeth/BMOPFTools.jl/pull/439); combined local gates/full suite pass; exact-head CI in #437 review record |
| P4 | #408 | `codex/408-device-index-validation` | Review stack on #439; see review record below | Draft [#440](https://github.com/frederikgeth/BMOPFTools.jl/pull/440); combined local gates/full suite pass; exact-head CI in #437 review record |
| P5 | #409 | `codex/409-connection-map-validation` | Review stack on #440; see review record below | Draft [#441](https://github.com/frederikgeth/BMOPFTools.jl/pull/441); combined local gates/full suite pass; exact-head CI in #437 review record |
| P6 | #268 | `codex/268-transformer-phase-evidence` | Review stack on #441; see review record below | Draft [#442](https://github.com/frederikgeth/BMOPFTools.jl/pull/442); combined local gates/full suite pass; exact-head CI in #437 review record |
| P7 | #95 | `codex/95-three-leg-physics-evidence` | Review stack on #442; see review record below | Draft [#443](https://github.com/frederikgeth/BMOPFTools.jl/pull/443); combined local gates/full suite pass; exact-head CI in #437 review record |
| P8 | #413 | `codex/413-coil-loading-reports` | Review stack on #443; see review record below | Draft [#444](https://github.com/frederikgeth/BMOPFTools.jl/pull/444); combined local gates/full suite pass; exact-head CI in #437 review record |
| P9 | #413 | `codex/413-coil-headroom-preflight` | Review stack on #444; see review record below | Draft [#445](https://github.com/frederikgeth/BMOPFTools.jl/pull/445); combined local gates/full suite pass; exact-head CI in #437 review record |

Implementation order: P1, P3, P4, P5, P6, P7, P8; then P2 and P9 complete
the feature portions of their issues. P6 and P8 can be brought forward as focused
usability improvements without waiting for the entire sequence. No subagents or
parallel agent work are assumed by this plan.

## P1 — Declared reactive capability under PF and Volt-var control

- [x] Audit engine, augmentation, solution verification, coefficient providers,
  and docs for the meaning of `q_min`/`q_max` with each supported control/topology.
- [x] Explicitly propose that authored reactive bounds remain hard constraints
  alongside a constant-PF or supported Volt-var equality. This changes the
  currently documented alternatives. Keep apparent-power/current/active-power
  limits, control precedence, and unsupported THREE_LEG droop behavior explicit.
- [x] Do not clip a control curve or relax a capability limit to restore feasibility.
  Incompatible requirements may remove feasible points; do not treat a local
  solver failure as proof of global infeasibility.
- [x] Add a minimized prescribed-voltage fixture with independently calculated
  P/Q/current. Cover both PF signs, unity PF, zero P, absent/one-sided/two-sided Q
  bounds, inside/on/outside limits, and an objective-driven binding bound.
- [x] Exercise SINGLE_PHASE, FOUR_LEG, THREE_LEG constant PF and supported droop,
  SI/per-unit coordinates, constraint registration, live coefficients, and JSON
  result evidence. Test conflicts with analytic/model-row witnesses independently
  of solver termination.
- [x] Document compatibility and migration: remove an unwanted Q bound explicitly;
  do not rely on the control law making it disappear. Audit augmentation-generated
  boxes so authored and derived restrictions are not silently conflated.
- [x] Record every existing-test change in the PR's test-change ledger. Keep #89
  open for minimum-PF semantics and any acceptance criteria not completed here.

## P2 — Minimum PF and remaining PF semantics

- [x] Settle a package/API representation compatible with official data-model
  ownership before adding schema fields. Specify injection signs, per-coil versus
  aggregate scope, finite PF range, zero-power behavior and supported directions.
- [x] Start with a declared nonnegative-generation domain and dispatched-P envelope
  `-k*P <= Q <= k*P`; require explicit handling of consumption/bidirectional cases.
  Never substitute nameplate/available power for dispatched power.
- [x] Compose or reject combinations with constant PF, droop, curtailment and
  existing limits. Reject unsupported requests instead of ignoring them.
- [x] Verify curtailed and unbalanced examples, both reactive signs, unity/boundary
  PF, zero-P policy, invalid inputs and supplied-result violations independently.
- [x] Document and test units, serialization, diagnostics and SI/per-unit behavior;
  close #89 only after both slices and the full issue checklist are satisfied.

## P3 — Transformer current-rating semantics and safe bounds

- [x] Publish a subtype/side coverage matrix: actual current variable/expression,
  rating index, phase/neutral meaning and whether a component box is valid.
- [x] Resolve center-tap fixed-admittance versus T-model LV rating semantics with
  legacy excitation. Compare physically identical cases at a fixed tap using
  independent total-terminal and internal-current calculations.
- [x] Add missing fixed-path Cartesian bounds only where the same current already
  has a magnitude cap. Preserve tighter bounds and zero-cap equality semantics.
- [x] Retain an excitation-cancellation witness demonstrating why a terminal cap
  cannot simply be copied onto an internal series current.
- [x] Cover fixed/free taps, zero/nonzero leakage arms, excitation present/absent,
  both sides/neutral handling, finite/zero/missing/infinite/invalid caps, SI and
  supported per-unit policies. Verify feasible physical points remain admissible.
- [x] Report any change in rating interpretation as a compatibility change. Missing
  redundant boxes alone must not be described as missing thermal protection.

## P4 — Device topology and parameter-array alignment

- [x] Inventory each supported load, generator, IBR and source field, including
  powers, ZIP/exponents/reference voltages, capability/cost/current arrays, source
  magnitudes/angles and bus `v_*`, `vpn_*`, `vpp_*` bounds.
- [x] Record conductor/phase/coil/pair indexing, scalar/broadcast allowances and
  supported arity. Audit actual runtime behavior rather than inventing a uniform
  vector rule. Share declared-role resolution across checkers.
- [x] Add precise stable Findings/evidence for invalid shapes and neutral placement;
  avoid duplicate existing integrity/configuration Findings.
- [x] Positive controls: phase-neutral/phase-phase single-phase, wye/delta,
  THREE_LEG/FOUR_LEG, sources, allowed broadcasts and terminal permutations.
- [x] Negative/boundary controls: missing/extra entries, ambiguous roles, malformed
  inputs, absent optional fields and supported boundary arities; no crashes,
  truncation or validation mutation. Rename neutrals to `n`, `4`, `return` and
  retain equivalent semantic outcomes; serialize codes and structured evidence.

## P5 — Branch and winding connection-map validation

- [x] Audit existing traversal, including nested n-winding and center-tap layouts.
  Extend existing integrity checks only where coverage is absent.
- [x] Validate actual position-to-position role correspondence for lines/switches
  and keep map/matrix dimensions strict. Accept legitimate phase permutations.
- [x] Apply subtype-specific transformer connection contracts; never apply line
  continuity rules across all windings or reject valid neutral-only ground shunts.
- [x] Test identity/permuted/subset maps, transformer connection changes, center-tap
  polarity and nested windings, unknown references, dimensions and role transitions.
- [x] Findings identify component, side/winding, positions, roles and rule, with
  deterministic nonduplicated evidence. Verify label covariance, non-mutation,
  malformed input handling and JSON round trips.

## P6 — Truthful transformer phase-relation reporting

- [x] Separate authored connection/maps, declared nameplate group, derived effective
  relation and display label. Define orientation/reference conventions and known,
  partial, unknown and unsupported states.
- [x] Eliminate failed-inference-as-clock-zero behavior. Resolve neutrals through
  declared roles; arbitrary phase labels require actual phase correspondence,
  not guesses from role membership. Preserve authored maps.
- [x] Update inventory, voltage-level and text/Markdown consumers compatibly,
  documenting any output-shape/string changes.
- [x] Independent prescribed-phasor tests cover numeric/letter/custom labels,
  renamed neutrals, cyclic/reversed order, partial maps, traversal reversal,
  supported Yy/Yd/Dy and n-winding `delta_roll` domains. Keep unsupported clock
  interpretations explicit; verify source-angle and SI/per-unit invariance.
- [x] Add serialized evidence and non-mutation controls. #176 remains separate;
  do not expand reporting into a general loop-feasibility certificate.

## P7 — Independent THREE_LEG physics and result evidence

- [x] Create balanced and genuinely unbalanced prescribed-phasor fixtures with
  independent pair currents `J_k = conj(S_k / (V_k - V_next))` and terminal
  injections `I_k = J_k - J_previous`.
- [x] Check complex signs/phasors, external terminal KCL and power balance against
  independent source/branch evidence. A built-in zero-sum identity alone is weak.
- [x] Cover unequal pair ratings and active/reactive/current capability below,
  on and beyond boundaries; make pair versus conductor meaning explicit in
  runtime docs/results without silently reinterpreting `i_max`.
- [x] Check SI/per-unit/base changes, angle rotation, cyclic relabeling and JSON
  result identities. Preserve unsupported-droop and malformed-topology tests.
- [x] Record provenance for any adapted PowerOptLab oracle; keep tests self-contained.
  Isolate newly discovered runtime defects with minimized witnesses and disclose
  them, rather than changing expected values to match the engine.

## P8 — Supplied-result per-coil transformer reporting

- [x] Reuse existing thermal Findings; report winding/coil/side, S, applicable cap,
  utilization/headroom and candidate status next to bank totals.
- [x] Distinguish supplied values from independent reconstruction, absent data from
  zero, and failed-solve output from a valid operating candidate. Declare subtype
  coverage and actual constrained side; avoid universal nameplate division rules.
- [x] Reuse the 100 kVA / 40 kW single-coil witness. Add below/on/above cap,
  missing-data and failed-candidate cases, plus independent voltage/current
  reconstruction, SI/per-unit consistency and JSON/report rendering checks.
- [x] Explain measured-versus-supplied evidence and the current nominal-load warning.
  Do not change ratings, relax constraints, retry solves or duplicate solution checks.

## P9 — Qualified per-coil preflight estimates

- [x] Start with explicitly mapped radial single-supply cases; inventory assumptions
  for voltage dependence, losses, Q, local generation and phase coupling.
- [x] Return estimate provenance, scope, applicable cap and unassessed reasons;
  unsupported meshes/multiple sources/ambiguous coil mappings receive no guess.
- [x] Test deterministic mapping, below/on/above nominal headroom and ambiguous
  controls; preserve input and distinguish estimates from solved/supplied loading.
- [x] Document that positive headroom does not prove feasibility and negative
  headroom does not prove infeasibility. Complete #413 only after both evidence paths.

## Test-change ledger and shared acceptance gates

Every implementation PR must include a ledger with **file/test, old assumption,
why it is invalid or deliberately changed, replacement oracle, and coverage
retained**. If none changed, say so. Adding an include to `runtests.jl` is wiring,
not an altered expectation. Do not loosen tolerances, delete failing cases or
replace independent oracles merely to obtain a passing run. A fixture correction
must retain the original failure as a separate negative/control regression when
it is central to the bug. Preserve numerical tolerances unless physical/error
analysis justifies a documented change.

For each runtime slice:

- [ ] Reproduce the relevant old behavior on the pinned base, using a minimal
  witness; retain the result separately from post-change evidence.
- [ ] Run focused tests, then scientific/execution gates and the full suite.
  Record exact commands, environment, totals, skips/failures and external-data limits.
- [ ] Update runtime docs and applicable stable Findings, `knowledge/executable.toml`
  and generated executable records. Keep PSK identities and scientific claims
  book-owned; reuse only supported domains. Do not edit the book's generated pair
  manifest from here. No new transport adapter without a curated tested recipe.
- [ ] Run these repository gates:

  ```sh
  python3 scripts/generate_finding_registry.py --check
  python3 scripts/generate_executable_knowledge.py --check
  julia --project=test --startup-file=no -e 'using Test, BMOPFTools; include("test/scientific_contract_tests.jl"); include("test/executable_knowledge_tests.jl"); include("test/execution_interface_tests.jl")'
  julia --project=test --startup-file=no test/runtests.jl
  ```

- [ ] Review diffs for unrelated changes, public compatibility, independent
  physical evidence, unknown/unassessed behavior and source/result identity.
- [ ] Open/update a draft PR, attach it to the chat, update this tracker with its
  URL and status, and inspect CI. Keep failures visible and fix in-scope failures.
- [ ] Leave every PR unmerged, with auto-merge disabled. Report readiness and
  outstanding decisions to the user; no issue is complete merely because a draft exists.

## Activity and test-change records

- 2026-10-18: plan created from the six accepted priorities. Latest main fetched;
  unrelated existing checkout retained. No runtime behavior or test expectations
  changed by the planning PR.
- 2026-10-18: P1 draft #438 published. Baseline witness reports success at
  1200 W / -900 var despite Q >= -300 var. New hard-bound behavior gives
  400 W / -300 var; supplied-result verification gains distinct Q-bound codes.
  Focused suites: 319 new assertions plus 201 existing controller assertions pass.
  Existing-test ledger: only the new include in `test/runtests.jl`; no existing
  expectations, fixtures or tolerances changed. Scientific gates pass; executable
  knowledge: 1,006 assertions; execution interface: 158 assertions. Full suite exits
  0 (main testset: 13,967 pass, 37 existing broken/skipped). Julia 1.12.6,
  JuMP 1.31.2, Ipopt.jl 1.15.0, MOI 1.53.0, PowerIO 0.11.3. Full commands and
  limitations are recorded in the implementation PR. CI was still running at
  handoff; neither draft has been merged or enabled for auto-merge.
- 2026-10-18: P1 CI subsequently passed all 11 reported checks; #438 remains draft.
- 2026-10-18: P3 draft #439 published from independent main base `df6bc42bf`.
  Center-tap T-model currents/caps now include legacy excitation like the fixed
  primitive path; internal core equations subtract it. Both paths expose safe
  boxes and enforce a supplied HV-neutral rating. The docs and PR explicitly
  describe the changed native/serialized LV current meaning and rating boundary.
  Baseline fixture: fixed tap 1 solves at 2.163185 A under the 3 A LV leg-1 cap;
  the same-tap old T-model returns LOCALLY_INFEASIBLE. Independent power/drop/loss
  equations and excitation cancellation provide the physical evidence.
  Existing-test ledger: one new suite include in `test/runtests.jl`; no existing
  assertions, fixtures, tolerances, skips or independent oracles changed.
  Zero-current coverage checks a known feasible point against every row/bound
  because Ipopt can reject the redundant all-zero-cap equality count.
  Python gates, scientific contracts, executable knowledge (1,006 assertions)
  and JSON execution interface (158 assertions) pass. Full suite at `d96e5bf4f`
  exits 0: main testset 16,693 pass, 37 existing broken/skipped; this includes the
  final reported-loss and bond-current assertions. The same Julia/dependency
  environment as P1 was used. OpenDSSDirect's Julia 1.12 precompile/deprecation
  diagnostics are nonfatal; optional test skips remain visible. CI is running
  at handoff, with metadata passed. P3 implementation checkboxes mean implemented
  and tested in the draft, not merged or issue-closed. #437/#438/#439 remain
  draft and unmerged, with auto-merge disabled.
- 2026-10-18: P3 CI subsequently passed all 11 reported checks; #439 remains draft.
- 2026-10-18: P4 draft #440 published from independent main base `df6bc42bf`.
  Shared role-aware indexing replaces literal-neutral and generic phase-count
  assumptions. The new coverage table distinguishes pairs, cyclic coils,
  phase arrays, source reference prefixes and bus voltage pairs. Ambiguous
  roles produce explicit unassessed evidence; missing IBR/source/bus field checks
  are added. Valid reversed pairs, neutral permutations and grounded source
  prefixes are retained; native physics and external schema are unchanged.
  Existing-test ledger: `test/runtests.jl` includes two new suites and changes
  the clean FOUR_LEG IBR fixture's scalar `q_min/q_max` to three-entry arrays.
  The old scalars do not broadcast to three phases in the native model;
  both the original scalar form and one-entry vectors are retained as negative
  regressions. Existing assertions, tolerances and skips are unchanged, including the established
  DELTA phase-to-neutral Finding-code expectations.
  At final commit `0efa4ad56`, focused indexing tests pass 4,278 assertions,
  native model-row tests pass 462, and existing neutral-only map tests pass 13.
  Both Python registry/provenance gates and scientific contracts pass;
  executable knowledge passes 1,012 assertions and JSON execution passes 158.
  The full suite exits 0: main testset 18,394 pass, 37 existing broken/skipped,
  zero failures. Commands and environment are recorded in #440; the same
  Julia/dependency environment as P1/P3 was used. OpenDSSDirect's Julia 1.12
  precompile/deprecation diagnostics remain nonfatal. CI metadata, DiffOpt,
  ExaModels and downstream-extension checks pass; remaining jobs are running
  at handoff. P4 checkboxes mean implemented and tested in a draft, not merged
  or issue-closed. #437 and #440 remain open drafts with auto-merge disabled.

- 2026-10-18: P5 (#409) started on `codex/409-connection-map-validation`,
  stacked on #440 at `0efa4ad56`. The draft will target P4's branch; no merge
  is needed. Baseline: equal-length mixed phase/neutral switch maps produced
  no error, while a malformed nested winding raised `MethodError`. The patch
  checks positional role correspondence and subtype-specific winding maps,
  retains original winding indices, and preserves isolated/grounding cases.
  Existing-test plan: add one suite include; no existing expectations changed.
  Native n-winding label support remains a separate runtime boundary.

- 2026-10-18: P4 CI passed all 11 checks; #440 remains an unmerged draft.
- 2026-10-18: P5 draft #441 opened at `eb267ea24`, targeting #440's branch.
  New static tests pass 2,360 assertions; existing neutral-link suite passes 13.
  Registry/provenance checks pass (370 documented Finding codes). Required
  scientific/execution gates and full suite are running against this commit.
  The existing n-winding checks run through the full-suite harness; an earlier
  ad hoc include reached its solver section without the harness availability
  flag, after its static assertions passed. No test source change was needed.
  Existing-test ledger: one include added to `test/runtests.jl`; no existing
  assertions, fixtures, tolerances, skips or independent oracles changed.
  Autotransformer shared-reference roles are checked specifically; no continuity
  rule is imposed across isolated transformer windings. No PR has been merged
  or enabled for auto-merge.

- 2026-10-18: P5 final validation at `eb267ea24` passes all required local
  gates: Finding registry (370 codes), reproducible executable export, scientific
  contracts, executable knowledge (1,018 assertions), and JSON execution
  interface (158 assertions). Full suite exits 0: main testset 20,760 pass,
  37 existing broken/skipped, zero failures. The focused suite passes 2,360 new
  and 13 existing neutral-link assertions. Commands and environment are in #441;
  the same Julia/dependency environment as P4 was used. OpenDSSDirect's Julia
  1.12 precompile/deprecation diagnostics remain nonfatal. GitHub metadata has
  passed; remaining CI runs at handoff. No existing assertions, fixtures,
  tolerances, skips or independent oracles changed relative to #440.
  P5 checkboxes mean implemented and tested in draft #441, not merged or
  issue-closed. #441 targets #440's branch; both remain drafts with auto-merge
  disabled. Next planned slice is P6 (#268).

- 2026-10-18: P6 (#268) started on `codex/268-transformer-phase-evidence`,
  stacked on #441 at `eb267ea24`. The baseline reproduces Dyn1/Dyn0/Dy1 for
  equivalent numeric/letter/renamed-neutral inputs. New structured evidence
  separates connection, declared nameplate, explicit phase correspondence and
  derived ideal displacement; failed inference never becomes clock zero.
  Static regression suite passes 2,147 assertions, including independent
  primitive checks across full permutations/taps/source rotations. Native SI/PU
  checks are running. Existing-test change planned: the source-angle tagging
  test will assert center-tap unsupported/Ii? instead of an unjustified Ii0,
  retaining the invariance assertions and adding a status assertion.

- 2026-10-18: P5 CI passed all 11 checks; #441 remains an unmerged draft.
- 2026-10-18: P6 draft #442 opened at `dded4ce79`, targeting #441's branch.
  Focused suites pass 2,158 static/primitive/report and 384 native-coordinate
  assertions. Both Python gates, scientific contracts, executable knowledge
  (1,030 assertions), and JSON execution (158 assertions) pass. Full suite runs
  against this commit. The native checks prescribe exact source phasors and
  subtract delta common mode; generic warm-start perturbations are not an ideal
  phase oracle. No tolerances were relaxed. Existing-test ledger: two suite
  includes plus the source-angle tagging test's context-aware helper calls and
  documented Ii0→Ii?/unsupported correction. Source-angle, inventory and
  voltage-level invariance checks remain. No fixtures or skips changed.
  Full orientation/status/compatibility conventions and commands are in #442.
  No PR has been merged or enabled for auto-merge.

- 2026-10-18: P6 final validation at `dded4ce79` passes all required local
  gates: Finding registry (370 codes, unchanged), reproducible executable
  export, scientific contracts, executable knowledge (1,030 assertions), and
  JSON execution (158 assertions). Full suite exits 0: main testset 23,315 pass,
  37 existing broken/skipped, zero failures. Focused suites pass 2,158
  static/primitive/report plus 384 native-coordinate assertions. The existing
  source-angle tagging suite passes with the documented Ii0→Ii?/unsupported
  change; no other existing expectations, fixtures, tolerances or skips changed.
  The Julia/dependency environment matches P5; commands and limits are in #442.
  OpenDSSDirect's Julia 1.12 precompile/deprecation diagnostics remain nonfatal.
  GitHub metadata passes; remaining CI runs at handoff. P6 checkboxes mean
  implemented and tested in draft #442, not merged or issue-closed. The draft
  targets #441's branch; all drafts remain unmerged with auto-merge disabled.
  Next planned slice is P7 (#95).

- 2026-10-18: P7 (#95) started on `codex/95-three-leg-physics-evidence`,
  stacked on #438 at `1ecbb6731` to exercise hard reactive capability. No merge
  is needed. The existing model constrains/reports cyclic pair currents, while
  the OPF guide incorrectly describes all IBR current limits as per-conductor.
  Correct that documentation explicitly; retain runtime pair semantics. Add
  self-contained prescribed-phasor tests with independently reconstructed
  terminal currents and source KCL/power evidence, boundary/covariance/scaling
  checks, and JSON round trips. PowerOptLab patterns were inspected at
  `4f417d470c8bff78bd0941658f97030e5ddb7692`; advanced-device physics is excluded.
  Existing-test plan: one suite include, with no existing assertions changed.

- 2026-10-18: P6 CI passed all 11 checks; #442 remains an unmerged draft.
- 2026-10-18: P7 draft #443 opened at `6bb9044cc`, targeting #438's branch.
  Independent physics suite passes 9,604 assertions. Both Python gates,
  scientific contracts, executable knowledge (1,011 assertions) and JSON
  execution (158 assertions) pass. Full suite/CI run against this commit.
  A minimized zero-current witness reproduces `UnsupportedAttribute` from
  MOI's `ZerosBridge` on the unchanged base. The shared zero-magnitude helper
  now uses affine expressions in its exact vector equality, preserving the
  variables and warm starts without changing the feasible region. The OPF guide
  corrects the blanket per-conductor description to explain THREE_LEG pair caps
  and pair-result indexing. New boundary tests tighten solver convergence at the
  1 MVA base instead of relaxing physical tolerances. Existing-test ledger:
  one include only; no existing assertions, fixtures, tolerances, skips or
  oracles changed. Exact commands, domain and provenance are in #443.
  No PR has been merged or enabled for auto-merge.

- 2026-10-18: P7 final validation at `6bb9044cc` passes all required local
  gates: Finding registry (366 codes, unchanged from #438), reproducible
  executable output, scientific contracts, executable knowledge (1,011
  assertions), and JSON execution (158 assertions). Full suite exits 0: main
  testset 23,576 pass, 37 existing broken/skipped, zero failures. Focused
  THREE_LEG suite passes 9,604 assertions. Existing malformed-topology and
  unsupported-droop tests remain enabled and pass. No existing assertions,
  fixtures, tolerances or skips changed; `test/runtests.jl` adds one include.
  The Julia/dependency environment matches P1; exact commands and limitations
  are in #443. OpenDSSDirect's Julia 1.12 precompile/deprecation diagnostics
  remain nonfatal. GitHub metadata passes; remaining CI runs at handoff.
  P7 checkboxes mean implemented and tested in draft #443, not merged or
  issue-closed. #443 targets #438; both are open drafts with auto-merge disabled.
  No PR has been merged. Next planned slice is P8 (#413 coil-loading reports).

- 2026-10-18: P8 (#413) started independently from main at `df6bc42bf`.
  Extend `profile_solution` and its Markdown/JSON evidence with native
  constrained-side coil rows and per-side aggregate sums. Reuse existing
  thermal Findings; supplied values/caps do not authenticate stamping or case
  provenance. Preserve failed-candidate and missing-data evidence. No ratings,
  solver equations or retry behavior change. P9 preflight estimation remains
  outstanding, so this draft will reference rather than close #413.
  Existing-test plan: add suite wiring only; retain the nameplate witness and
  all existing numerical expectations.

- 2026-10-18: P7 CI passed all 11 checks; #443 remains an unmerged draft.
- 2026-10-18: P8 draft #444 opened at `f83c1d661`, targeting main. Focused
  suites pass 153 reporting and 258 independent electrical assertions. Both
  Python gates, scientific contracts, executable knowledge (1,012 assertions)
  and JSON execution (158 assertions) pass. Full suite and CI are running.
  Baseline reporting emits the coil Finding but has no per-coil summary; the
  new block surfaces 40% aggregate / 120% coil loading without duplicating
  Findings. JSON round trips exposed an existing integer squared-voltage
  dispatch error in load verification; a minimized witness reproduces it on
  unchanged source, and conversion before squaring fixes it without changing
  physics/tolerances. Existing-test ledger: two suite includes only; no existing
  assertions, fixtures, tolerances, skips or oracles changed. Existing native
  subtype fixtures are read unchanged by the new SI/PU tests. The report never
  edits ratings or retries solves. P9 remains planned; #444 references #413
  without closing it. No PR has been merged or enabled for auto-merge.

- 2026-10-18: P8 final validation at `f83c1d661` passes all required local
  gates: Finding registry (364 codes, unchanged from main), reproducible
  executable metadata, scientific contracts, executable knowledge (1,012
  assertions), and JSON execution (158 assertions). Full suite exits 0: main
  testset 14,065 pass, 37 existing broken/skipped, zero failures. Focused suites
  pass 153 reporting and 258 native electrical assertions. Existing nameplate
  and solution-profiling suites remain enabled and pass. Only two includes
  changed in existing test source; no existing expectations, fixtures,
  tolerances or skips changed. New subtype tests tighten solver convergence
  rather than relax physical SI/PU comparisons. The same Julia/dependency
  environment as prior drafts was used; exact commands and limits are in #444.
  OpenDSSDirect's Julia 1.12 precompile/deprecation diagnostics remain nonfatal.
  GitHub metadata and DiffOpt pass; remaining CI runs at handoff. P8 checkboxes
  mean implemented and tested in draft #444, not merged or issue-closed.
  #444 targets main and remains a draft with auto-merge disabled. No PR has
  been merged. P9 (#413 qualified preflight estimates) and P2 (#89 minimum PF)
  remain outstanding.

- 2026-10-18: P9 started on `codex/413-coil-headroom-preflight`, stacked on
  #444 at `f83c1d661`; P8 now passes all 11 CI checks. Initial domain is one
  single-phase transformer bank in a connected radial single-source network,
  with explicit phase/neutral terminal maps and phase-neutral nominal loads.
  Meshes, multiple sources/banks, local generation/compensation, coupled loads
  and tap decisions receive unassessed reasons. Estimate signed nominal P/Q
  per coil with explicit voltage/loss/coupling omissions; no feasibility claim,
  rating mutation, solver invocation or change to the existing 90% aggregate
  warning. Existing-test plan: one suite include; preserve all expectations.

- 2026-10-18: P9 draft #445 opened at `081f2e73f`, targeting draft #444.
  The unchanged baseline reports 40% aggregate loading and no coil preflight
  block; the new estimate exposes the 120% coil / −6.667 kVA nominal headroom.
  Focused regression suite passes 203 assertions. Finding registry (366 codes),
  executable export/schema/stale-output, llms and release metadata checks pass;
  scientific contracts, executable knowledge (1,025 assertions), and JSON
  execution (158 assertions) pass. Full suite and CI are running.
  Existing-test ledger: one include in `test/runtests.jl`; no existing assertions,
  fixtures, tolerances or skips changed. The existing analysis recipe gains
  assertions through its same curated operation and retains its old assertions
  and emitted example. The P8 fixture is reused unchanged, network only.
  No solver/constraint/rating behavior changed. #445 and #444 remain open drafts
  with auto-merge disabled; neither #413 nor any PR is closed or merged.

- 2026-10-18: P9 final validation at `081f2e73f` passes all required local
  gates and the full suite: **14,281 pass, 37 existing broken/skipped, zero
  failures**, exit 0 (main testset 2m41.5s). The increase over P8 is 203 new
  preflight assertions plus 13 executable-metadata path/hash checks. Scientific
  contracts pass; executable knowledge has 1,025 passing assertions and JSON
  execution has 158. The updated curated analysis recipe is exercised by those
  gates. Finding registry, reproducible executable export/schema, llms and
  release metadata checks pass. No existing assertions, fixtures, tolerances
  or skips changed; the only existing test-source edit is one suite include.
  Existing recipe assertions remain intact. OpenDSSDirect Julia 1.12 diagnostic
  noise is nonfatal. GitHub metadata passes; remaining CI jobs run at handoff.
  P9 checkboxes mean implemented and locally validated in draft #445, not
  merged or issue-closed. #413 now has both supplied-result (#444) and qualified
  nominal-screen (#445) paths available for review in the declared domains.
  #445 targets #444; both remain open drafts with auto-merge disabled. No PR
  has been merged. P2 (#89 minimum PF) is the remaining planned feature slice.

- 2026-10-18: P2 (#89 minimum PF) started on `codex/89-minimum-power-factor`,
  stacked on #438 at `1ecbb6731`. Use the existing free-form `extras` escape
  hatch for a versioned BMOPFTools policy; do not change the Task Force-owned
  schema/control-profile fields. Require explicit generation/per-coil scope and
  nonnegative P bounds. Enforce dispatched-P envelopes (including P=0 => Q=0),
  intersect Q/P/S/current limits and compatible controls, reject unsupported
  directions/combinations, and independently verify supplied P/Q. Retain
  existing constant-PF signs and reject invalid PF declarations explicitly.
  Existing-test plan: add suite wiring and retain all established expectations;
  any additional change will be explained with its reason and retained oracle.

- 2026-10-18: P2 draft #446 opened at `802490305`, targeting #438. Native
  per-coil generation envelopes use dispatched P and bounded PF coefficients;
  supported controls and all existing capability limits remain active. The
  versioned policy uses the schema's existing `extras` escape hatch; the
  Task Force schema and fingerprint are unchanged. The independent unknown-field
  scanner now recognizes the already-supported top-level extras field.
  Baseline on #438 returns P=400 W / Q≈900 var; the minimum-PF 0.8 witness now
  returns Q=300 var. Existing constant-PF zero/invalid values are explicitly
  rejected; docs explain removing the sub-object to disable constant PF.
  Initial focused run passed 344 assertions plus 319 reactive-capability and
  89 Volt-var/Volt-watt assertions unchanged. Final mapping/zero/candidate
  boundary coverage and full gates are running on the committed revision.
  Existing-test ledger: one include only; no existing assertions, fixtures,
  tolerances or skips changed. The curated verification recipe adds assertions
  while retaining its old assertions/output. A new test initially used an
  unsupported absolute-VAr droop; the positive case now uses VA_FRACTION and
  the unsupported encoding remains as an explicit rejection regression.
  #446 remains an open draft with auto-merge disabled. No PR has been merged.
- 2026-10-18: P9 #445 now passes all 11 GitHub CI checks and remains an open draft.

- 2026-10-18: P2 final validation at `802490305` passes all required local
  gates and the full suite: **14,331 pass, 37 existing broken/skipped, zero
  failures**, exit 0 (main testset 2m42.6s). New minimum-PF coverage passes 353
  assertions; the existing reactive-capability (319), Volt-var/Volt-watt (89)
  and controller-compliance (112) suites pass unchanged. Scientific contracts,
  executable knowledge (1,017 assertions) and JSON execution (158 assertions)
  pass, including the expanded curated verification recipe. Registry (370
  codes), executable schema/stale-output, llms, release metadata and diff checks
  pass. The 364-assertion increase over #438 is 353 new regressions plus 11
  generated-metadata path/hash checks. Existing-test changes remain one suite
  include only; no previous assertions, fixtures, tolerances, skips or oracles
  changed. The new suite retains unsupported-control and ambiguous-map cases
  as explicit rejections, not skipped tests. The final fresh-process run covers
  all source changes; OpenDSSDirect Julia 1.12 diagnostics remain nonfatal.
  GitHub metadata passes; remaining CI jobs are running at handoff.
  P2 checkboxes mean implemented and locally validated in draft #446, not
  merged or issue-closed. #89 has P1 (#438) and P2 (#446) available for review
  within their declared domains. All planned feature slices now have draft
  PRs. #446 targets #438; both remain open drafts with auto-merge disabled.
  No PR has been merged and no issue was closed by this work.

## Cross-branch correctness review — 2026-10-18

Scope: draft #437–#446 only, as confirmed by the user. Older draft #383 is excluded.
Initial CI: all 11 checks passed on every scoped PR. All original worktrees were
clean; original heads are retained in local `refs/codex-review-backup/pr-N` refs.
The feature stack was rebased, never merged. Original incremental source/test
changes are retained, with the explicit corrections below. No book or schema
ownership change is introduced.

| PR | Review coverage / correction | Validation status |
|---|---|---|
| #437 | Goal, dependencies, test-change ledger and review evidence | Updating this tracker |
| #438 | Hard Q boxes with PF/droop; supplied Q checks and live bounds | Original head unchanged; 11 CI checks green |
| #439 | Center-tap terminal versus series currents, excitation, neutral rating and safe bounds | Restacked; regenerated metadata checks pass |
| #440 | Device role/index shapes, load coefficient checks, retained DELTA diagnostics | Restacked; regenerated metadata checks pass |
| #441 | Raw winding indices, endpoint roles, duplicate/reference checks and coupled coil counts | Restacked; regenerated metadata checks pass |
| #442 | Directed phase incidence, correspondence, unsupported clock states and consumers | Restacked; regenerated metadata checks pass |
| #443 | Independent cyclic-pair/conductor current oracle, scaling and zero-current warm starts | Restacked; regenerated metadata checks pass |
| #444 | Supplied candidate/coil/group evidence; fix finite-input sum/ratio overflow so JSON retains null/incomplete derived metrics | Existing 153 + 8 new focused assertions pass |
| #445 | Nominal-demand allocation/domain limits; reject malformed terminal declarations with #440's validated resolver instead of inferring roles | 211 focused assertions pass (203 existing + 8 new) |
| #446 | Minimum-PF composition and dispatch evidence; bounded constant-PF coefficients preserve tiny accepted PF; reject malformed roles consistently | Existing 353 minimum-PF + 319 Q-capability, 20 new tiny-PF and 24 malformed-role and three snapshot assertions pass; combined local gates/full suite pass |

### Test-change disclosure for this review

- No existing assertion, tolerance, fixture, skip or independent physical oracle
  is weakened. Conflict resolution retains every suite include exactly once.
- `test/transformer_loading_tests.jl`: eight additional finite-input overflow
  assertions cover null ratios, incomplete sums and JSON round trips. The old
  reporting assertions are unchanged.
- `test/transformer_headroom_tests.jl`: two additional malformed-declaration
  cases, four assertions each. They require no guessed coil allocation, the
  stable unassessed Finding, and non-mutation.
- `test/ibr_minimum_pf_tests.jl`: 20 additional tiny constant-PF assertions use
  independent P/hypot(P,Q), inspect bounded model coefficients, verify finite
  starts and JSON diagnostic serialization, and reject Float64 underflow.
  This does not promise solver relative accuracy below absolute tolerances.
  Twenty-four malformed-role assertions verify invalid-policy evidence,
  rejection through both public model constructors, JSON round trips and
  non-mutation. Three snapshot-selection assertions ensure the early entry guard
  validates the selected snapshot before normalization, not unsliced inputs.
- Retained earlier edits: #440 changes one nominally clean fixture's scalar Q
  bounds into three-element per-coil arrays because native IBR capability is
  vector-indexed. #442 changes the unsupported center-tap `Ii0` expectation to
  `Ii?` plus explicit unsupported status; source-angle/voltage/inventory invariance
  remains tested. #446 adds recipe assertions without changing its original
  example or assertions. Their earlier detailed ledger entries remain above.

### Combined validation

Final combined head `7bfe32720`:

- Full `test/runtests.jl`: exit 0, **37,357 pass**, **37 existing broken/skipped**,
  no failures (main testset 2m44.9s). The review adds 63 assertions: eight overflow,
  eight preflight role guards, 20 tiny-PF, 24 minimum-PF role/public-entry guards, and three snapshot-selection assertions.
- Required scientific contracts pass; executable knowledge **1,074 pass**;
  JSON execution interface **158 pass**. Finding registry **378 codes**, executable
  schema/stale-output, llms entry point, release metadata and whitespace checks pass.
- All **45 PR pairs are conflict-free** under read-only integration checks;
  every one of the **12 new suite includes occurs exactly once**.
- Incremental authored deltas were compared before/after restacking. #439–#443
  retain their deltas; #444/#446 contain the documented fixes; #445 additionally
  retains both formerly conflicting documentation sections and its role guard.
- Environment: Julia 1.12.6, JuMP 1.31.2, MOI 1.53.0, Ipopt.jl 1.15.0,
  PowerIO 0.11.3. Existing optional skips and nonfatal OpenDSSDirect diagnostics
  remain visible. The original checkout is clean and unchanged.
- Exact-head GitHub CI results are maintained in the [#437 review record](https://github.com/frederikgeth/BMOPFTools.jl/pull/437),
  including this tracker PR. Keeping live CI state in the PR body avoids changing
  a commit merely to report that commit's successful checks. Initial scoped heads
  had all 11 checks green. Duplicate/superseded runs were cancelled, preserving
  current-head validation. Pending checks are never recorded as passes.

No additional correctness gap was found within this review's supported-domain
checks. This is bounded regression evidence, not a general feasibility proof or
an exhaustive verification of optional backends. All PRs remain draft; nothing
is merged and auto-merge is disabled.
