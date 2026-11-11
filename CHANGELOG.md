# Changelog

## 0.1.0 — unreleased

Initial General release candidate. Registration has not yet been requested.

- Add `sideload_geolayer!`, which explicitly applies the geographic WGS84
  GeoLayer that PowerIO stores in `extras.geojson` to bus `longitude`/`latitude`,
  line `meta.route_geometry` and `meta.crs`, and returns match counts.
  Projected, diagram and unknown spaces, other CRSs and conflicting
  declarations are reported and left unapplied. A coordinate-free case that
  carries such a layer reports spatial status `indeterminate` /
  `unapplied_geolayer` instead of omitting the spatial result.
  A layer from which nothing could be applied reports `indeterminate` /
  `no_features_applied`.
- Voltage-bound coverage counts phase-to-neutral, phase-to-phase and
  positive-sequence magnitude bounds as well as `v_min`/`v_max`.
  `I.PRE.NO_VOLT_BOUNDS`, the preflight lower/upper counts (now with
  `n_with_bounds_by_kind`), diversity `pct_with_voltage_bounds` and the
  benchmark-readiness suggestion no longer report `vpn_*`-bounded buses as
  unconstrained. Benchmark readiness adds `pct_voltage_magnitude_bounds`;
  `pct_v_bounds` remains the phase-to-ground share.
- Supply phase counts (`W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY`) and voltage-source
  rotation classes use the case's resolved terminal roles, so a declared
  neutral such as `"4"` is no longer counted as a phase and a single-phase
  source no longer reads as a zero-sequence profile.
- Galvanic zones, radiality and downstream-load traversal exclude lines and
  closed switches that map only neutral- or earth-role terminals at both ends.
  A neutral bond beside a service transformer no longer merges the secondary
  zone into the primary zone (split-phase classification and solution
  voltage-zone bases), raises `W.CONN.MESHED`, or turns the transformer loading
  estimate into an upper bound. Connectivity results add
  `n_neutral_only_branches` and `neutral_only_cycle_rank`; the physical
  `structure` counts and the earthing islands are unchanged.
  `ZonePerUnitScaling` still requires one power base across a neutral-only
  bond, which carries return current, and the solution voltage-zone summary
  leaves out zones that have only neutral/earth terminals.
- Voltage-level analysis no longer propagates a nominal voltage through lines
  and closed switches that map only neutral- or earth-role terminals at both
  ends, such as primary-to-secondary neutral bonds beside service transformers.
  These bonds no longer raise `E.VOLT.LEVEL_MISMATCH`, `E.VOLT.LINE_CROSSING` or
  `W.PROV.LINE_BRIDGES_VOLTAGE_LEVELS`; return-only buses reached only through
  them are listed in `neutral_only_buses` instead of `unassigned_buses`.
- Speed up OPF solves. Constant-power load currents start at I = conj(S/V) from the voltage
  start, and generator currents from their power-box midpoints, instead of
  zero. On the 498-bus French feeder 84_MVFeeder2628 this cut Ipopt
  iterations from 38 to 22. `resolve_opf!` now warm-starts from the previous
  feasible solution by default (`warm_start=false` restores a cold re-solve).
  Result extraction and the optimization profile read solver values in batches.
  Per-unit scaling no longer deep-copies the private working network, and
  time-series snapshots no longer copy every series step.

- Adopt American English for repository-authored text and new identifiers,
  with contributor and agent guidance. Preserve existing interfaces, accepted
  input aliases, published anchors, citations, and upstream license text (#464).
- Raise the PowerIO.jl dependency floor to 0.11.7.
  Validate typed CVR exponents without replacing them with legacy defaults;
  retain the typed bounded load law and its threshold provenance. Geometry
  regression tests now check resolved overhead matrices and genuinely missing
  geometry separately.
- **Breaking:** `to_dss` refuses exports whose static AC re-import cannot
  establish unchanged component/terminal correspondence and declared ratings
  and bounds. Use `allow_unverified_ratings=true` for independent power-flow
  verification; the warning and structured evidence remain. Keep BMOPF JSON
  authoritative for OPF and Tellegen. This contained powerio#762 (unrated
  equivalent branches acquire 600 A) without removing legitimate constraints.
- Raise the PowerIO.jl dependency floor to 0.11.11. PowerIO 0.11.10 repaired
  powerio#762: absent OpenDSS line ampacity stays absent on import and
  round trip instead of becoming 600 A. The round-trip evidence drops its 22
  source-branch rating entries (601 differences remain), and the regression
  test now asserts that the missing rating survives. `to_dss` still refuses
  equivalent-circuit exports by default because component correspondence
  changes.
- Review the 36 round-trip fixtures individually. Check effective line
  primitives, source and shunt equivalent circuits, grounding, and physical
  feeder ratings; isolate rating and neutral-role defects in focused expected
  failures instead of whole-case structural expected failures.
- Expand the Tellegen guide with five new Norwood screenshots following one
  transformer from geographic overview to schematic and conductor results,
  including capture provenance and case-study qualifications.
- Make the SWER tutorial follow each backbone span's effective linecode and
  exclude source-equivalent branches from feeder-length edits.

- `from_dss` keeps OpenDSS node 0 (an implicit wye star or source return) as a
  distinct, perfectly grounded terminal `n_ref`, separate from the conductor
  neutral `n` (node 4). It was previously merged into `n` and earthed through
  `n`'s grounding impedance. **Breaking:** imported terminal maps can now
  contain `n_ref`; `_meta.earth_terminal_routing` is replaced by
  `_meta.opendss_ground_references`. Re-import the original DSS source to fix
  previously saved imports.
- `from_dss` checks authored transformer `leadlag` against the converted
  phase relation: `lag`/`ansi` are verified and no longer blocking;
  `lead`/`euro` are recorded as a known 60° mismatch and stay blocking.
- Earthing reports describe represented connections and no longer classify
  TN-C-S/TN-S/TT/IT. **Breaking:** `star_earthing` takes `perfect`, `impedance`,
  `none` or `indeterminate` (was `solid`/`impedance`/`none`); `tag` text changed;
  zones gain `star_points`, `neutral_earths` and `protective_system_status`.
  Parallel earth paths combine as admittances. A phase-only voltage source
  counts as a ground-referenced (perfect) infeed. Wire descriptions count
  represented branch conductors, e.g. `mixed (2/4 conductors)`.
- `[provenance.grounding] earth_solid_ohm`/`earth_isolated_ohm` are kept for
  compatibility but ignored; `load_config` warns when a user file sets them.
  The internal `_EARTH_SOLID_OHM` constant is removed.
- Add the BMOPFTools.jl logo: hero banner in the README and docs home, sidebar
  logo, favicon, GitHub social preview, and light, dark, one-color and icon
  variants as SVG/PNG/PDF, generated by `scripts/logo/generate_logo_assets.py`.
  Update the tagline to "Inspect, prepare, and optimize unbalanced distribution
  networks."

- Preserve bus `longitude`/`latitude` in `write_bmopf` by default for Tellegen
  visualization; use `include_coordinates=false` to retain the previous
  omission behavior for strict BMOPF schema consumers. Add a drag-and-drop guide.

- Fix `ybus_passive`, `ybus_linearized` and `ybus_augmented` modeling switches
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
