# Use BMOPFTools with AI coding assistants

AI coding assistants can help inspect BMOPF cases, explain diagnostics, write Julia workflows, and contribute package changes. They are most reliable when they operate against a pinned BMOPFTools checkout and must show the package outputs and checks supporting their answer.

This page applies equally to ChatGPT, Codex, Claude, and other assistants. It describes safe use of the package; it does not add an LLM retrieval service to BMOPFTools.

!!! important "Package behavior and scientific authority are different"
    BMOPFTools owns executable behavior: APIs, applicability checks, structured results, Finding codes, fixtures, and package tests. The companion *What Power-Network Models Preserve* resource owns the scientific statements, evidence status, misconceptions, and stable `PSK-*` identities.

    Use the book's grounded [ChatGPT guide](https://frederikgeth.github.io/multi-graph-book/dev/start/chatgpt-access/) or [Claude guide](https://frederikgeth.github.io/multi-graph-book/dev/start/claude-access/) when asking what the scientific evidence establishes. Use BMOPFTools when asking what a particular case, result, or executable contract does.

## Choose the working arrangement

| Need | Recommended arrangement | Main limitation |
|---|---|---|
| Change or test the package | A coding assistant with a local repository checkout | It still needs explicit scope and verification requirements |
| Analyse a shareable case | A local coding assistant with the case and pinned environment | Results apply to that case and package revision |
| Discuss a small public example | A chat or Project with the relevant files and documentation | Uploaded files are a snapshot, not a live package installation |
| Analyse confidential network data | A locally controlled environment approved for that data | Do not upload protected models to an unapproved external service |
| Establish a general scientific conclusion | The book's grounded access route, followed by the relevant executable check | A package result alone is not a literature or evidence review |

BMOPFTools does not currently expose a package-specific MCP or HTTP retrieval service. An assistant with repository and terminal access should call the Julia API directly. An application integration should likewise use the package API and serialize its structured outputs, rather than scrape documentation or diagnostic prose.

## Give the assistant an operating contract

State the revision, task, inputs, permitted changes, and evidence expected in the response. A useful starting prompt is:

> Work against BMOPFTools revision `<commit or version>`. The task is `<analysis or change>`. Inputs are `<paths and their meaning>`. Do not invent BMOPF fields or infer semantics from names alone. Use documented APIs and match diagnostics by Finding code, not message text. Do not modify files outside `<scope>`. Run `<checks>`, report their exact outcome, and distinguish verified results from assumptions, unassessed dimensions, and unsupported conclusions.

For a repository contribution, also ask the assistant to read the root `AGENTS.md` and `ARCHITECTURE.md`, preserve unrelated working-tree changes, and show the final diff and test commands.

Record the package identity in reproducible work:

```julia
using BMOPFTools

Base.pkgversion(BMOPFTools)
```

For a development checkout, record the Git commit as well. Version `0.1.0` at two different commits need not have identical behavior while the package is evolving rapidly.

## Prompt templates

### Analyse and triage a case

> Parse `<case.json>` with `parse_bmopf`, run `analyze`, and summarize errors, warnings, and informational Findings by stable code. For each material Finding, name the affected component, explain what the package established, and link to the relevant BMOPFTools documentation. Do not claim the case is OPF-ready merely because parsing succeeds. Do not edit the input. Return the commands used and any limitations of the analysis.

A minimal verifiable workflow is:

```julia
using BMOPFTools

net = parse_bmopf("case.json")
report = analyze(net)

errors(report)
warnings(report)
infos(report)
```

See [Analysis and reports](analysis.md), the [Finding-code reference](findings.md), and [Trust but verify](tutorial_trust_but_verify.md) for the interpretation expected from the assistant.

### Diagnose an OPF result

> Load `<case.json>` and `<result.json>` using the documented BMOPFTools interfaces. Profile the result, report bound violations, residuals, termination information, and any missing evidence by Finding code. Separate solver termination from independent solution validation. Do not treat a solver's “optimal” label as proof that every physical or data-model requirement was checked.

The relevant entry points are documented under [OPF result dictionaries](results.md) and [validating the OPF](validation.md).

### Evaluate a scientific contract

> Evaluate `parallel_member_limit_preservation` for the declared source members `<IDs>` and target aggregate `<ID>`. Report the `ScientificContractResult` status, checked dimensions, unassessed dimensions, Findings, tolerances, and witness. If the result is `inapplicable` or `indeterminate`, do not convert it to a pass or failure. Treat `PSK-000001` as a link to the book's scoped scientific statement, not as a claim that the scalar implementation covers multiconductor or state-dependent branches.

Use [`check_parallel_member_limit_preservation`](@ref) and serialize results with [`contract_result_to_dict`](@ref). The [scientific-contract guide](scientific_contracts.md) defines the current applicability boundary.

For an adjustable transformer, use the same reporting discipline with an
explicit subtype and source/target transformer mapping:

> Evaluate `transformer_tap_domain_preservation` for source transformer `<subtype>/<ID>` and mapped target `<subtype>/<ID>`. Distinguish its tap decision interval from its start value. Report the interval classification and witness, then list every unassessed dimension. Do not describe a matching interval as transformer-equation, control, network-feasible-set, objective, or optimal-tap equivalence.

Use [`check_transformer_tap_domain_preservation`](@ref). The negative fixture
`transformer-tap-domain-loss-001` shows why retaining only the source start tap
is an inner restriction rather than preservation of the adjustable domain.

For a converter that changes transformer endpoint or terminal ordering:

> Evaluate `transformer_winding_convention_preservation` with explicit source/target transformer IDs and a one-to-one bus mapping. If terminal labels changed, provide the terminal-label mapping. Report winding incidence and winding-reference/ratio Findings separately. Do not treat a bare endpoint swap as an ordinary edge reorientation, and do not promote a pass to leakage, grounding, limit, complete-factor, or decision equivalence.

Use [`check_transformer_winding_convention_preservation`](@ref). Adjustable taps
must be checked separately rather than forced into this fixed-convention route.

For a transformation that is being promoted from terminal exactness to a
decision-equivalence claim:

> Evaluate the versioned transformation manifest with `check_decision_preservation_manifest`. Report missing, unsupported, and explicitly unresolved dimensions. Do not fill absent evidence from prose or infer that a passing completeness result authenticates evidence, validates mappings, compares feasible sets or objectives, or proves optimization equivalence. Use the relevant case-specific contracts to support individual manifest dimensions.

Use [`check_decision_preservation_manifest`](@ref). A correctly scoped
terminal-only manifest is `inapplicable` to this gate, not failed; the failure
arises only when a manifest claims exact decision equivalence without closing
the admissible-domain, observation, constraint, decision-variable, objective,
and recovery obligations.

For a proposed Kron reduction, start with the tutorial's grounding premise:

> Evaluate `check_kron_boundary_recovery` for the mapped four-wire source line and three-wire target. Report whether the eliminated neutral is perfectly grounded at every source endpoint, the Schur-complement boundary error and tolerance, and the declared recovery map. Do not call a floating or finite-grounded neutral exact merely because the reduced impedance has the Schur-complement numbers; do not promote a boundary pass to internal-limit, protection, decision, or solver equivalence.

Use [`check_kron_boundary_recovery`](@ref). The [grounding tutorial](tutorial_grounding.md)
shows the same distinction experimentally: perfect endpoint grounding gives an
exact three-wire boundary, while floating or finite grounding changes the
network behaviour that the reduced model cannot represent.

### Contribute a package change

> Implement `<change>` on the current branch. First inspect the relevant public API, tests, documentation, and repository instructions. Preserve unrelated changes. Add focused positive, negative, boundary, and serialization tests in proportion to the change. Update Finding documentation and executable metadata when their stable identities or sources change. Run the focused tests, the stale-output check, and the relevant documentation build. Commit only after the diff and checks are clean.

An assistant should not hand-edit `generated/executable_knowledge.jsonl`. Changes begin in package code, fixtures, documentation, or `knowledge/executable.toml`, followed by the deterministic generator.

## How to judge an assistant's result

Accept a package-level conclusion only when the response makes its evidence inspectable:

- the BMOPFTools version or commit is named;
- input paths and component mappings are explicit;
- public APIs, not invented helper behavior, produced the result;
- diagnostics are identified by stable Finding code;
- `passed`, `failed`, `inapplicable`, and `indeterminate` remain distinct;
- checked and unassessed dimensions are both reported;
- generated manifests or serialized results retain source and package identity where available; and
- the stated tests or reproduction commands actually ran successfully.

Treat these as warning signs:

- matching or suppressing a diagnostic by its prose message;
- inventing a BMOPF schema field because it exists in another tool;
- claiming a transformation is exact without naming the preserved object and domain;
- treating missing data or out-of-domain inputs as success;
- presenting an executable fixture as proof of a broader scientific statement;
- relying on the assistant's memory of package behavior instead of the pinned checkout; or
- modifying generated exports without updating their canonical inputs and hashes.

## Where each question belongs

| Question | Primary authority |
|---|---|
| What does this BMOPF case contain? | BMOPFTools parser, analysis, and Findings |
| Does this result satisfy the package's validation checks? | BMOPFTools solution profiling and validation APIs |
| Does this source-to-target mapping pass an implemented contract? | BMOPFTools scientific-contract API |
| Why is the shortcut scientifically dangerous, and under what scope? | The book's PSK record, claims, misconception registry, and evidence artifacts |
| Does the current scalar witness generalize to another model class? | Unsupported until the book records the broader result and BMOPFTools implements an applicable contract |

This division keeps assistants useful without turning fluent explanations into unverified engineering evidence.
