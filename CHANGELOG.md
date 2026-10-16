# Changelog

## 0.1.0 — unreleased

Initial General release candidate. Registration has not yet been requested.

- Fix `ybus_passive`, `ybus_linearized` and `ybus_augmented` modelling switches
  with `open_switch = true` as closed; read the schema field instead of a
  non-schema `status` key and reject a non-boolean `open_switch`.

- Fix pilot-discovered verification false positives for zero-rated generator/IBR
  phases and native switch current fields; accept integer-valued JSON powers.
- Add independent demand/PV scenarios, callback-based sweeps retaining failures,
  explicit DER bus/phase selections and new-capacity budgets, and optional
  JSON/Markdown author logs with resolved recipes and structured Findings.
- Add self-contained, tested case-development examples and a progressive tutorial.
- Correct diagnostic overclaims about phase balance, costs, active constraints
  and dimension counts; retain legacy profile keys as descriptive aliases.
- Change low-impedance switch replacement to opt-in; retain shunts/additional
  branch limits and inconsistent or unassessed source-voltage bounds.

- Replace the IEEE-inspired inline analysis fixture with an original CC BY 4.0
  synthetic workshop feeder and migrate its diagnostic and serialization tests.
- Parse, validate, analyze, and report BMOPF networks, with PowerIO ingestion.
- Provide optional JuMP-based OPF/power-flow and structured solution validation.
- Expose scientific contracts with explicit applicability and stable Findings.
- Provide curated JSON/CLI/MCP execution and reproducible executable metadata.
- Keep restricted MV/LV and ENWL datasets outside the package; retain optional
  external-data integration tests and self-contained synthetic recipes.
- Define a conservative JuMP floor, explicit Julia-floor CI, mandatory backend
  imports in release tests, and fresh-environment extension/solver smoke tests.
- Accept PowerIO 0.11.3's exact archived BMOPF 0.1.0 schema URI; retain strict
  rejection of unreviewed schema revisions and profiles.
- Normalize transformer tap/excitation exchange fields and preserve DSS CVR
  and winding resistance through PowerIO 0.11.1 and later compatible releases.
- Refresh optimizer state after parameter updates before re-solving.
- Verify line limits at both endpoints and signed branch-angle bounds; document
  and test the power-flow nameplate exception.
- Separate exact and modeled Volt-watt controller compliance evidence.
- Accept single-conductor metallic neutral-to-neutral lines and switches; retain
  rejection of asymmetric neutral maps and neutral-only nodal devices.

- Record the copyright holder's CC BY 4.0 grant for bundled fixtures; replace
  IEEE/Kersting geometry data with original synthetic overhead/CN/TS cases,
  independently captured OpenDSS matrices, and live comparisons.

Known release decisions and validation steps are tracked in `RELEASING.md`.
