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
