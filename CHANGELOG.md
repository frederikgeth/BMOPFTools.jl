# Changelog

## 0.1.0 — unreleased

Initial General release candidate. Registration has not yet been requested.

- Parse, validate, analyze, and report BMOPF networks, with PowerIO ingestion.
- Provide optional JuMP-based OPF/power-flow and structured solution validation.
- Expose scientific contracts with explicit applicability and stable Findings.
- Provide curated JSON/CLI/MCP execution and reproducible executable metadata.
- Keep restricted MV/LV and ENWL datasets outside the package; retain optional
  external-data integration tests and self-contained synthetic recipes.
- Define a conservative JuMP floor, explicit Julia-floor CI, mandatory backend
  imports in release tests, and fresh-environment extension/solver smoke tests.

Known release decisions and validation steps are tracked in `RELEASING.md`.
