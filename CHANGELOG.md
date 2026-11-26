# Changelog

## 0.1.0 — unreleased

Initial General release candidate. Registration has not yet been requested.

- OPF engine review (November 2026): correctness fixes found by a
  line-by-line audit of the unbalanced IVR engine, each pinned by a regression
  test and, where OpenDSS can express the case, by an OpenDSS oracle.
  - **Per-unit voltage bases** are now assigned per galvanic zone. Buses joined
    by lines, switches, regulators or autotransformers share one base; only an
    isolating transformer changes it. Previously a regulator's `v_nom_*`
    nameplate rescaled the downstream coordinates on top of its tap (a 5 %
    boost solved as 10 %), and a line closing a loop between transformers of
    unequal ratio joined buses with different bases, removing the circulating
    current. SI solves were unaffected.
  - **Line angle windows** (`va_diff_min`/`va_diff_max`) bound phase
    conductors only. They were also stamped on the neutral, whose phasor
    routinely rotates by tens of degrees along a healthy four-wire line, so
    feasible cases were reported infeasible.
  - **DELTA generators** follow the load geometry: two or three distinct
    phase terminals, a two-terminal map is one coil (it was two anti-parallel
    coils, doubling the unit), and a neutral terminal is rejected. Supplied
    `p_min`/`p_max`/`q_min`/`q_max` vectors must have one entry per coil; a
    short vector used to leave the remaining coils unbounded.
  - **Losses include DC branches.** `result["losses"]["p_loss"]`,
    `opf_total_loss` and `opf_element_loss` (new block `"dc_branch"`) count
    DC-conductor I²R, and each `dc_branch` result carries `loss.p_loss`. A
    loss objective could previously route current through a resistive DC tie
    at no apparent cost.
  - **DC voltage droop** acts on the pole-voltage magnitude, so a negative
    pole sags under load like a positive one instead of rising.
  - **Volt-watt with `p_ref = "P_AVAILABLE"`** divides the available power by
    the number of coils, not phase terminals; a phase-to-phase single-phase
    unit was capped at half its available power.
  - **`solve_pf` requires a determined problem.** Generators and AC-only IBRs
    need fixed active power, and reactive power that is fixed or set by a
    constant power factor or Volt-var law; missing and one-sided bounds are
    rejected instead of returning a start-point-dependent answer.
  - **Feasibility OPF** penalizes slack in amperes in either unit system, so
    the reported slack location no longer depends on `per_unit`.
  - A capacitor without `v_nom` is rejected (the 1.0 fallback meant one volt
    in SI and one per-unit voltage in per-unit). An IBR with an unsupported
    topology is rejected instead of being left out of the network with a
    warning. A shared-DC-link balance with `p_dc_min == p_dc_max` is one
    equality row, `:ibr_dc_power_equality`. Apparent-power auxiliaries start
    on their defining equalities.
  - A **minimum power factor of exactly one** stamps the single equality
    `:ibr_minimum_pf_equality` (`Q = 0`) instead of the opposing pair
    `Q <= 0`, `-Q <= 0`, unless a pinned reactive box or a unity constant
    power factor already states `Q = 0` for that coil. Limits below one keep
    their two wedge rows. Likewise a shared-DC-link balance is not restated
    when every coil's active power is pinned and already sums to it.
  - A **two-terminal DELTA generator** applies the tighter of its
    per-conductor `i_max` entries to its one coil current, whichever terminal
    it is listed against.
  - **IBR `p_min`/`p_max`/`q_min`/`q_max` vectors** must have one entry per
    coil, as for generators; a short vector used to leave coils unbounded.
    `solve_pf` checks determinacy coil by coil and counts a reactive control
    law only where the engine stamps it (not Volt-var on `THREE_LEG`, not a
    malformed curve). A multi-coil DC-coupled unit needs each coil's active
    power fixed, since its DC side determines only their sum.
  - **Open switches** no longer join voltage-base zones, and no longer trip
    the same-base check of a custom scaling policy.
  - **Dependent equality rows** are omitted only when static rows already
    in the model imply them: a constant-power-factor equality over boxes that
    pin it, and repeated DC voltage masters on one port (one reference row;
    masters that disagree raise). Bounds supplied as live parameters never
    count as pins, so a shared-DC-link balance stays in force when `p_max`
    is a parameter. An ideal DC conductor between terminals fixed at
    different voltages is rejected instead of carrying a spurious current.
    `solve_pf` waives the active-power setpoint of a single-coil DC-coupled
    unit only when its DC side supplies the determining equation (zero-width
    private balance, droop, or one voltage master per port).
  - **`solution_check` agrees with the engine again** on the semantics
    changed here: line angle windows are assessed on phase conductors only;
    the AC power balance no longer counts DC-branch loss twice (the result
    reports that share as `losses.p_loss_dc`); a two-terminal DELTA
    generator is checked as one coil against its tighter rating; and the
    Volt-watt `P_AVAILABLE` cap is per coil.
  - A flat Volt-var curve over a pinned reactive box is not restated. DC
    voltage masters are grouped by electrical port, so masters joined by
    zero-resistance conductors share one reference row.
  - `solve_pf` confirms determinacy on the rows actually stamped, so a
    coefficient provider that widens a fixed bound is rejected.
  - `solution_check` derives the DC-branch loss share from the case and the
    solved DC quantities (a reported `losses.p_loss_dc` is only
    cross-checked), expects one power record per coil for line-to-line
    devices, identifies neutrals by the case's declared labels, and skips
    neutral and protective-earth conductors in line angle checks, resolving
    terminal roles once per case. Integrity accepts one-entry bounds on a
    two-terminal DELTA generator.
  - DC voltage references are treated as a graph over electrical nodes: a
    reference the others already imply (including the third side of a
    triangle of ports on a bipolar bus) is not stamped, and one that
    contradicts them raises. `solve_pf` rejects free voltage masters whose
    ports close a loop, reading "free" from the built model, and requires a
    standalone `dc_source` to be a fixed injection. Its resolved-row check
    skips devices owned by a custom builder.
  - Line angle windows honor declared phase labels: with
    `terminal_conventions` present, a phase conductor named `n` is bounded;
    the naming convention applies only to cases that declare no roles.
  - `solution_check` reports missing DC voltages or branch currents as
    `W.SOL.INCOMPLETE_RESULT` instead of passing the DC checks vacuously.
  - A loop of ideal (zero-resistance) `dc_branch` conductors is rejected, as
    ideal AC loops already are: its current could circulate undetermined.
    Fixed DC terminal voltages seed the voltage-reference graph, so a master
    that restates one is not stamped and one that contradicts it raises.
  - Source-bus neutral grounding follows declared terminal roles: a source
    phase named `n` is no longer grounded when `terminal_conventions`
    declares it a phase.
  - `solution_check` computes DC-branch loss as r·i² from the case
    resistance and checks each reported drop against r·i, so a claimed drop
    across a zero-ohm conductor cannot offset an AC imbalance. Malformed DC
    evidence (absent or JSON null) is read as unavailable; the active-power
    balance is then not assessed and the verification is indeterminate.
  - Open-delta regulators are unchanged: the bank does not connect its neutral
    terminals, and neutral continuity past it stays an explicit line or
    switch. Two OpenDSS cases (ideal and 0.5 ohm jumper) now pin this.

- Add network-reduction tools: explicit-neutral Kron reduction
  (`kron_reduce_neutrals`, ported from PowerOptLab with its tests and
  cross-checked against the PSK-000008 boundary contract), and a prototype of
  robust Opti-KRON error-bounded bus reduction (`opti_kron_model`, uncertainty
  sets, screening, `opti_kron_reduction` with adversarial constraint
  generation, `kron_reduce_buses` to build a solvable reduced case, and
  `lift_solution`). Validated against the IEEE European LV results of
  arXiv:2611.21313; new pages compare all reductions on real feeders. The
  reducers refuse rather than approximate: `kron_reduce_neutrals` rejects
  `FOUR_LEG` IBRs whose neutral return would be removed, and
  `kron_reduce_buses` rejects time-varying eliminated elements, mesh fill-in
  on the physical graph, and slack-represented buses whose limits the fixed
  slack voltage cannot certify.
- An IBR whose static `p_min` equals `p_max` (or `q_min` equals `q_max`) now
  stamps one equality row, registered as `:ibr_p_equality` (`:ibr_q_equality`),
  instead of a zero-width `:ibr_p_lower`/`:ibr_p_upper` pair. The pair has no
  strictly feasible interior, so Ipopt's per-unit path became ill-conditioned
  and, depending on platform rounding, about 1–3% of pinned or constant-PF
  solves landed on a low-voltage root (an intermittent Julia 1.10 CI failure
  in the FOUR_LEG PVSystem comparison). Pinned per-unit solves now take 2
  iterations instead of about 16. Bounds supplied as parameters keep both rows.
  Generators follow the same rule (`:generator_p_equality`,
  `:generator_q_equality`); pinned generators take 2–3 iterations instead of
  5–17.
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
