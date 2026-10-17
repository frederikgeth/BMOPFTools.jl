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

Use independent branches from reviewed main for unrelated changes. If a later
slice requires an unmerged predecessor, explicitly stack it on that branch and
target that predecessor in GitHub; list the dependency and incremental diff in
the PR body. Do not merge a predecessor merely to start its dependent work.
Retarget/rebase only when a human has merged the prerequisite. Do not mix unrelated
fixes into these branches. Each PR body must record its exact base, issue scope,
behavior/compatibility changes, test edits and reasons, commands/results,
remaining limitations, and the no-merge instruction.

## Delivery tracker

Unchecked means outstanding, not implicitly covered by another row. Replace
planned branch names with actual branch/PR links as work starts. Issue completion
requires all its acceptance criteria; partial PRs use `Refs`, not `Closes`.

| Slice | Issue | Planned branch | Dependency | Status / PR |
|---|---|---|---|---|
| P0 | All | `codex/correctness-usability-plan` | None | Draft [#437](https://github.com/frederikgeth/BMOPFTools.jl/pull/437) |
| P1 | #89 | `codex/89-reactive-capability-limits` | None | Draft [#438](https://github.com/frederikgeth/BMOPFTools.jl/pull/438); local gates/full suite and CI pass |
| P2 | #89 | `codex/89-minimum-power-factor` | P1 semantics; representation review | Planned |
| P3 | #116 | `codex/116-transformer-current-ratings` | None | Draft [#439](https://github.com/frederikgeth/BMOPFTools.jl/pull/439); local gates/full suite and CI pass |
| P4 | #408 | `codex/408-device-index-validation` | None; coordinate P1/P6 | Draft [#440](https://github.com/frederikgeth/BMOPFTools.jl/pull/440); final local gates/full suite and CI running |
| P5 | #409 | `codex/409-connection-map-validation` | Shared role/index contracts from P4 | Planned |
| P6 | #268 | `codex/268-transformer-phase-evidence` | None; coordinate P4/P5 role helpers | Planned |
| P7 | #95 | `codex/95-three-leg-physics-evidence` | P1 behavior; P4 indexing where changed | Planned |
| P8 | #413 | `codex/413-coil-loading-reports` | None; coordinate P3 rating semantics | Planned |
| P9 | #413 | `codex/413-coil-headroom-preflight` | P8 evidence shape; explicit mapping domain | Planned |

Implementation order: P1, P3, P4, P5, P6, P7, P8; then P2 and P9 complete
the feature portions of their issues. P6 and P8 can be brought forward as focused
usability improvements without waiting for the entire sequence. No subagents or
parallel agent work are assumed by this plan.

## P1 — Declared reactive capability under PF and Volt-var control

- [ ] Audit engine, augmentation, solution verification, coefficient providers,
  and docs for the meaning of `q_min`/`q_max` with each supported control/topology.
- [ ] Explicitly propose that authored reactive bounds remain hard constraints
  alongside a constant-PF or supported Volt-var equality. This changes the
  currently documented alternatives. Keep apparent-power/current/active-power
  limits, control precedence, and unsupported THREE_LEG droop behavior explicit.
- [ ] Do not clip a control curve or relax a capability limit to restore feasibility.
  Incompatible requirements may remove feasible points; do not treat a local
  solver failure as proof of global infeasibility.
- [ ] Add a minimized prescribed-voltage fixture with independently calculated
  P/Q/current. Cover both PF signs, unity PF, zero P, absent/one-sided/two-sided Q
  bounds, inside/on/outside limits, and an objective-driven binding bound.
- [ ] Exercise SINGLE_PHASE, FOUR_LEG, THREE_LEG constant PF and supported droop,
  SI/per-unit coordinates, constraint registration, live coefficients, and JSON
  result evidence. Test conflicts with analytic/model-row witnesses independently
  of solver termination.
- [ ] Document compatibility and migration: remove an unwanted Q bound explicitly;
  do not rely on the control law making it disappear. Audit augmentation-generated
  boxes so authored and derived restrictions are not silently conflated.
- [ ] Record every existing-test change in the PR's test-change ledger. Keep #89
  open for minimum-PF semantics and any acceptance criteria not completed here.

## P2 — Minimum PF and remaining PF semantics

- [ ] Settle a package/API representation compatible with official data-model
  ownership before adding schema fields. Specify injection signs, per-coil versus
  aggregate scope, finite PF range, zero-power behavior and supported directions.
- [ ] Start with a declared nonnegative-generation domain and dispatched-P envelope
  `-k*P <= Q <= k*P`; require explicit handling of consumption/bidirectional cases.
  Never substitute nameplate/available power for dispatched power.
- [ ] Compose or reject combinations with constant PF, droop, curtailment and
  existing limits. Reject unsupported requests instead of ignoring them.
- [ ] Verify curtailed and unbalanced examples, both reactive signs, unity/boundary
  PF, zero-P policy, invalid inputs and supplied-result violations independently.
- [ ] Document and test units, serialization, diagnostics and SI/per-unit behavior;
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

- [ ] Audit existing traversal, including nested n-winding and center-tap layouts.
  Extend existing integrity checks only where coverage is absent.
- [ ] Validate actual position-to-position role correspondence for lines/switches
  and keep map/matrix dimensions strict. Accept legitimate phase permutations.
- [ ] Apply subtype-specific transformer connection contracts; never apply line
  continuity rules across all windings or reject valid neutral-only ground shunts.
- [ ] Test identity/permuted/subset maps, transformer connection changes, center-tap
  polarity and nested windings, unknown references, dimensions and role transitions.
- [ ] Findings identify component, side/winding, positions, roles and rule, with
  deterministic nonduplicated evidence. Verify label covariance, non-mutation,
  malformed input handling and JSON round trips.

## P6 — Truthful transformer phase-relation reporting

- [ ] Separate authored connection/maps, declared nameplate group, derived effective
  relation and display label. Define orientation/reference conventions and known,
  partial, unknown and unsupported states.
- [ ] Eliminate failed-inference-as-clock-zero behavior. Resolve neutrals through
  declared roles; arbitrary phase labels require actual phase correspondence,
  not guesses from role membership. Preserve authored maps.
- [ ] Update inventory, voltage-level and text/Markdown consumers compatibly,
  documenting any output-shape/string changes.
- [ ] Independent prescribed-phasor tests cover numeric/letter/custom labels,
  renamed neutrals, cyclic/reversed order, partial maps, traversal reversal,
  supported Yy/Yd/Dy and n-winding `delta_roll` domains. Keep unsupported clock
  interpretations explicit; verify source-angle and SI/per-unit invariance.
- [ ] Add serialized evidence and non-mutation controls. #176 remains separate;
  do not expand reporting into a general loop-feasibility certificate.

## P7 — Independent THREE_LEG physics and result evidence

- [ ] Create balanced and genuinely unbalanced prescribed-phasor fixtures with
  independent pair currents `J_k = conj(S_k / (V_k - V_next))` and terminal
  injections `I_k = J_k - J_previous`.
- [ ] Check complex signs/phasors, external terminal KCL and power balance against
  independent source/branch evidence. A built-in zero-sum identity alone is weak.
- [ ] Cover unequal pair ratings and active/reactive/current capability below,
  on and beyond boundaries; make pair versus conductor meaning explicit in
  runtime docs/results without silently reinterpreting `i_max`.
- [ ] Check SI/per-unit/base changes, angle rotation, cyclic relabeling and JSON
  result identities. Preserve unsupported-droop and malformed-topology tests.
- [ ] Record provenance for any adapted PowerOptLab oracle; keep tests self-contained.
  Isolate newly discovered runtime defects with minimized witnesses and disclose
  them, rather than changing expected values to match the engine.

## P8 — Supplied-result per-coil transformer reporting

- [ ] Reuse existing thermal Findings; report winding/coil/side, S, applicable cap,
  utilization/headroom and candidate status next to bank totals.
- [ ] Distinguish supplied values from independent reconstruction, absent data from
  zero, and failed-solve output from a valid operating candidate. Declare subtype
  coverage and actual constrained side; avoid universal nameplate division rules.
- [ ] Reuse the 100 kVA / 40 kW single-coil witness. Add below/on/above cap,
  missing-data and failed-candidate cases, plus independent voltage/current
  reconstruction, SI/per-unit consistency and JSON/report rendering checks.
- [ ] Explain measured-versus-supplied evidence and the current nominal-load warning.
  Do not change ratings, relax constraints, retry solves or duplicate solution checks.

## P9 — Qualified per-coil preflight estimates

- [ ] Start with explicitly mapped radial single-supply cases; inventory assumptions
  for voltage dependence, losses, Q, local generation and phase coupling.
- [ ] Return estimate provenance, scope, applicable cap and unassessed reasons;
  unsupported meshes/multiple sources/ambiguous coil mappings receive no guess.
- [ ] Test deterministic mapping, below/on/above nominal headroom and ambiguous
  controls; preserve input and distinguish estimates from solved/supplied loading.
- [ ] Document that positive headroom does not prove feasibility and negative
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
  regressions. Existing
  assertions, tolerances and skips are unchanged, including the established
  DELTA phase-to-neutral Finding-code expectations.
  Focused matrix/native-row checks pass before the final fixture regression;
  final local gates and full suite are running against the completed patch.
  P4 checkboxes mean implemented in a draft, not merged or issue-closed.
