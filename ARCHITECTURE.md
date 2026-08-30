# Federated scientific knowledge and executable guardrails

The canonical cross-repository architecture is maintained in
[`multi-graph-book/ARCHITECTURE.md`](https://github.com/frederikgeth/multi-graph-book/blob/main/ARCHITECTURE.md).
With the usual sibling checkout, its local path is
`../multi-graph-book/ARCHITECTURE.md`.
That document is the authority for repository ownership, dependency direction,
PSK links, scientific-contract semantics, federation, versioning, and change
control. The implementation handover is subordinate to it.

BMOPFTools' local role is intentionally narrower: it owns executable checks and
case-specific evidence. Its existing foundations include validators, stable
`Finding` codes, solution verification, transformation manifests, invariance
tests, and machine-readable reports. Executable scientific contracts,
minimized negative fixtures, small recipes, and the executable-knowledge export
extend those foundations here. BMOPFTools does not own the scientific claims
ledger, misconception catalogue, literature evidence, retrieval ranking,
audience answer contract, or federated context service.

The following local constraints are architectural:

- BMOPFTools must work without `multi-graph-book` or network access.
- Findings remain understandable offline and may carry optional PSK links in
  machine-readable detail.
- Checks distinguish `passed`, `failed`, `inapplicable`, and `indeterminate`;
  they do not imply preservation outside their declared domain.
- Source-versus-target checks require the source, target, and explicit mapping
  whenever the target cannot represent discarded source information.
- Julia/domain APIs precede JSON CLI or MCP adapters, and transport adapters
  remain thin.
- Generated executable records describe capabilities and provenance; they do
  not duplicate the book's scientific prose.

Changes that alter these constraints must update the canonical architecture in
`multi-graph-book` and be reviewed as a cross-repository architectural change.

The first two scientific transport slices expose `parallel_member_limit_preservation` and
`neutral_ground_reference_preservation` through the package-owned
`execute_contract` API and `bin/bmopf check-contract`. A curated adapter
registry gives each contract an explicit parameter allowlist; it does not
perform dynamic Julia dispatch. Responses are validated against
`schemas/execution-response.schema.json`, distinguish request errors from the
four scientific-contract statuses, and bind source and target input hashes.
The `parallel_member_limits` and `neutral_ground_reference` recipes are
CI-tested operational examples. The separate `execute_analysis` API and
`bin/bmopf analyze-case` route serialize the package's existing `analyze`
report with operation status `completed`; ERROR and WARNING Findings remain
case diagnostics rather than transport failures. Its tutorial-derived
`analyze_case` recipe carries no PSK identity because it does not itself assert
a scientific preservation claim. `execute_case_parse`, `bin/bmopf parse-case`,
and the `parse_case` recipe report decode/migration/normalization evidence and
a compact inventory without turning successful intake into a validation
claim. The deliberately incomplete recipe input parses while a separate schema
assertion emits `E.SCHEMA.REQUIRED`. The same package-only boundary applies to
`execute_solution_verification`, `bin/bmopf verify-solution`, and its
`verify_solution` recipe: they serialize existing `profile_solution` behavior
without rerunning a solver or claiming the book's invalid-inference statement.
The package-owned `explain_finding` lookup and `bin/bmopf explain-finding`
route are generated from the canonical local Finding reference. They explain a
stable code class offline and preserve existing contract/PSK links, but do not
inspect a Finding instance, infer causes or repairs, query the book, or invent
scientific links. External PowerIO diagnostic namespaces remain PowerIO-owned.
Other contracts remain available through
their Julia APIs until each mapping has an explicit reviewed transport shape.
