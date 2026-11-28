# Changelog

## 0.1.0 — unreleased

Initial General release candidate. Registration has not yet been requested.

- Infeasibility diagnosis:
  - `solve_feasibility_opf` in per-unit (the default) penalized per-unit slack
    variables weighted by `(I_base/I_ref)²`, which made a milliampere residual
    far smaller than the solver tolerance: feasible cases stopped with ~2 mA of
    slack that an SI solve drives to ~1e-10 A, and `diagnose_infeasibility`
    reported them as infeasible. The slack variables are now amperes in both
    unit modes (entering per-unit KCL as `cs / I_base`), so the objective and
    the converged slack match the SI solve.
  - `diagnose_infeasibility`: `fraction_of_total` is each bus's share of the
    squared total slack, so the shares sum to one (it divided by the L2 norm
    before). Near-bound phases in a bus's `voltage_violations` are labeled
    `at_lower_bound:`/`at_upper_bound:` with the bound, instead of
    `undervoltage:`/`overvoltage:` with a `<`/`>` that held at equality.
- Objectives: the smoothing scale of a `:magnitude` voltage or current term at
  a bus with no `v_max`/`v_min` was 1 V in an SI model (`per_unit=false`) but
  the bus voltage base in per-unit, so one `eps_rel` smoothed differently in
  the two unit modes. SI models now fall back to the bus's classic per-unit
  voltage base, matching per-unit and the documented contract.
- Line constants: `line_geometry` gains `capacitance_model` (`"thin_wire"`
  default, `"charge_simulation"`), also a keyword of `overhead_line_constants`
  and recorded in the compiled linecode's `derivation`. The thin-wire kernel
  (OpenDSS LineConstants parity) is inaccurate for thick, closely spaced
  conductors and gives a positive opposite-core mutual for touching insulated
  cores; `compile_linecode` now warns and `analyze` reports
  `W.DOM.GEOM_THIN_WIRE` when (r_i + r_j)/d > 0.5 for a pair under
  `thin_wire`. The charge-simulation kernel resolves each conductor's surface
  charge and keeps the Maxwell sign pattern (#503).
- Augmentation and DER placement:
  - `augment_case`, `add_generators` and `add_ibrs` accept the `SummaryReport`
    returned by `analyze` (or its Symbol-keyed `results`) as `analysis`. An
    `analysis` holding none of the sub-results a function uses is an
    `ArgumentError` instead of being silently recomputed (#499).
  - The reactive-capability rule for `q_capability_pf = 0.95` was labeled
    `IEEE1547-2018_cos_phi_0.95` and tagged `:standard`, but IEEE 1547-2018
    sets reactive capability from nameplate kVA. Any pf other than 0.90 is now
    recorded as `cos_phi_<pf>_P_based` (IBRs: `…_ibr_default`) with confidence
    `:heuristic`; the EN 50549-1 labels for pf = 0.90 are unchanged. Manifests
    that match the old label must be updated (#500).
  - `add_ibrs` rejects a `prime_mover` outside the data-model values (`PV`,
    `BATTERY`, `GENERIC`, `STATCOM`, `DSTATCOM`), and the augment pass writes
    `p_min = -p_max` for a `BATTERY` without one (rule
    `BATTERY_symmetric_charge`, `:heuristic`) (#501).

- Network models & data documentation review (November 2026): the section is
  checked against the implementation and regrouped into concepts, component
  guides, data model reference, and import & export.
  - The units, grounding and load-model tutorials use bundled fixtures and
    every block runs at documentation build.
  - Corrected statements that contradicted the code, among them the transformer
    no-load shunt placement, terminal-role inference, `_meta` persistence,
    `n_winding` key names, leakage placement on OpenDSS import, the `n_ref`
    return, what `to_pmd` drops, and the `transformer_yprim` behavior for an
    ideal transformer.
  - The device-indexing, connection-map and transformer phase-relation
    references state their rules in the present tense; no rule changed.
  - New "Anatomy of a case" page.
  - `W.LOAD.NL_NO_VMIN` no longer describes a fixed 0.5 V_nom load-voltage
    floor; without a lower voltage bound the load model has no floor.
- Profiler review (November 2026): the electrical and geospatial profiler was
  checked against wiring and earthing practice in North America, Europe, Japan
  and Australia, and against 220 networks for false flags. Each fix is pinned
  by a regression test; where OpenDSS or the power-flow engine can express the
  case, by that oracle too.
  - **Voltage reference.** A transformer's internal neutral impedance
    (`r/x_neutral_*`) and a line's shunt admittance to earth are finite
    references. Impedance- and resonant-earthed islands, and unearthed delta
    islands with modeled capacitance, no longer raise
    `E.INT.NO_VOLTAGE_REFERENCE` or `E.PROV.FLOATING_NEUTRAL`.
  - **Transformer banks.** Single-phase units that join the same two buses on
    different conductors (wye bank, open-wye/open-delta, V-connection) are one
    branch (`results[:connectivity]["transformer_banks"]`) supplying the union
    of their legs: no `W.CONN.MESHED` or `W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY`.
  - **High-leg delta.** Power units beside a center-tapped unit are not a second
    voltage level (`E.VOLT.LEVEL_MISMATCH`, `W.VOLT.XFMR_RATIO`); the bus is
    reported at the leg voltage and listed in `mixed_phase_to_neutral_buses`.
  - **SWER zones** need a branch that witnesses the earth return. A two-wire or
    branchless single-phase section behind a transformer is now `single_phase`;
    `n_swer_zones` on the bundled SWER deck is 1, not 2.
  - **`n_winding` DELTA windings** propagate a per-conductor bus nominal (it was
    √3 too low).
  - **AC sections joined over a DC link** are one network
    (`results[:connectivity]["dc_links"]`).
  - **Declared terminal roles** are honored by the grounding analysis and the
    neutral power-limit check on a hand-built case, not only the name `n`.
  - **Report consolidation.** `analyze` reports an `I.`/`W.` code raised on
    more than `[report] rollup_threshold` components (default 25) as one
    roll-up Finding; `expand_findings` restores the per-component Findings and
    `is_rolled_up` identifies a roll-up. `I.PROV.LINE_SWITCH_LIKE` is dropped
    for a line that raises `W.DOM.LINE_LOW_IMPEDANCE`, and
    `W.OPS.LINE_UNCONSTRAINED` when `W.PROV.I_MAX_ABSENT` names the same lines.
    `E.` Findings are never consolidated. **Behavior change:** code that counts
    per-line Findings in `report.findings` should call `expand_findings`.
  - **Narrower triggers.** `W.OPS.IMPORT_DEPENDENT` is not raised for a passive
    feeder that declares no generator and no IBR (see
    `results[:operational]["passive_feeder"]`); `W.INT.UNUSED_BUS_TERMINAL`
    ignores perfectly grounded terminals and counts capacitors as users;
    `I.OPS.UNLOADED_PHASE` needs a zone that carries load;
    `W.DOM.DROOP_BREAKPOINT_OUTSIDE_BAND` needs every breakpoint on one side of
    the band; `I.PROV.KRON_LIKELY` needs branches at the level and a non-delta
    supply.
  - **Configuration.** `[provenance.dss_defaults]` and
    `[provenance.switch_like]` now follow the `config` passed to `analyze`.
  - **Coordinate frames.** GDA94/GDA2020, JGD2000/JGD2011, NAD83, ETRS89 and
    NZGD2000 are accepted geographic frames. Local Cartesian frames accept US
    survey feet, kilofeet and miles and raise the length Findings.
    `sideload_coordinates!(...; frame=:cartesian, units=...)` loads OpenDSS
    `Buscoords` as a plane.
  - **New Findings.** `W.GEO.LINE_LONGER_THAN_CHORD`,
    `W.GEO.LENGTH_SCALE_SUSPECT` (a network-wide unit factor) and
    `W.GEO.COORDINATE_OUTLIER` (null-island placeholders, positions far outside
    the network). `W.GEO.WGS84_RANGE` records whether the values are valid with
    the axes exchanged.
  - **One graph for the mesh verdict and its evidence.** Banks and DC links are
    part of the shared branch inventory (`branch_scope` states it), bank
    grouping is resolved per bus pair independently of component ids
    (`transformer_bank_groups`), and the power unit of a high-leg bank keeps a
    ratio check against the bank's line-to-line voltage.
  - **Conductor-level reference.** `E.INT.NO_VOLTAGE_REFERENCE` is also raised
    for a group of conductors that no element ties to the earthed ones, even
    when its island has a reference elsewhere (`detail["scope"]`).
  - **One reading of an inverter.** The control rules of an IBR (coil
    terminals, precedence between power factor and droop, droop bases, DC
    coupling) live in `src/validation/ibr_rules.jl` and are used by both the
    OPF/PF builder and the reference check. An inverter coil is left out of
    the reference graph only when those constraints force both its powers to
    zero, which an independent LP test checks by minimizing and maximizing
    each coil's P and Q.
  - **Banks across primary buses.** Units on different primary buses are one
    bank only when closed switches carry every primary conductor of each
    winding between them. Partial ties are listed in
    `undetermined_transformer_banks` and give a high-leg status of
    `undetermined`; the verdicts are tested for invariance under bus renaming,
    switch reversal and terminal relabeling.
  - **Fixtures.** `test/data/profiler_systems`: North American MGN with
    split-phase service, high-leg open delta, European TN four-wire, unearthed
    delta island (referenced and not), Japanese three-wire with V-connection,
    Australian MEN.
  - **Documentation.** A "Profile a case" section ordered tutorial, how-to,
    explanation, reference, with four executed tutorials (first messy case,
    system types, OpenDSS port, spatial cleanup), two how-tos (thresholds,
    accepting findings), a grounding-findings explanation, and the analysis
    page split into an overview and a result-key reference.

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
  - New finding codes, so that what the builders reject is reported by
    validation first, from shared detectors: `E.INT.IDEAL_LOOP` and
    `E.INT.DC_IDEAL_LOOP` (loops of ideal conductors) and
    `E.INT.DC_REFERENCE_CONFLICT` (contradictory exact DC voltages).
    `W.DOM.BUS_LIMIT_NOT_APPLICABLE` reports sequence or phase-to-neutral
    limits on a bus where the OPF cannot define them, and
    `W.CONV.PHASE_NAMED_AS_NEUTRAL` a declared phase whose name reads as a
    neutral. `solution_check` reports `W.SOL.DC_OHM_RESIDUAL` and
    `W.SOL.DC_LOSS_SHARE_MISMATCH` under their own codes.
  - **Breaking: ideal AC conductors must have a determined current.** The
    OPF now rejects an ideal conductor (a closed switch pole, or a line
    conductor with an all-zero impedance row) between two terminals that can
    each supply any current — perfect grounds and source terminals — as it
    already rejected parallel ideal conductors and rings. The usual instance
    is the neutral pole of a four-wire switch between two buses with
    perfectly grounded neutrals: it closes a loop through the earth and its
    current was arbitrary. Validation reports it as `E.INT.IDEAL_LOOP`. The
    conductor is redundant, so leave it out of the terminal maps, or run
    `fix_case`: the new pass `apply_remove_earthed_ideal_conductors` (on by
    default) removes it exactly and records the change in the manifest. It
    runs after the two passes that can create the pattern. A radial feeder
    of ideal neutral conductors between grounded buses, which failed in both
    `solve_pf` and `solve_opf`, is now reported and repaired this way.
  - Ideal transformers are part of the same rule. Two zero-leakage
    transformers in parallel, or one bridged by a closed switch, state one
    voltage relation twice and could share a load in any proportion; the
    builders now reject them, and validation reports ideal `single_phase`
    units as `E.INT.IDEAL_LOOP`. One ideal transformer on its path is
    unaffected, with one exception that is now rejected too: an ideal
    grounded-wye/delta unit connected directly to a voltage source, whose
    zero-sequence current nothing determines. The rule is sufficient, not necessary: an ideal tie between
    two voltage sources is rejected even when power setpoints on the second
    source would pin its current.
  - `fix_case` pads a line shunt matrix that is smaller than the conductor
    count before removing a conductor, so each remaining shunt entry stays on
    its conductor.
  - A terminal declared as protective earth is not a phase in any per-phase
    quantity: `v_min`/`v_max` and `vpn_*` take one entry per phase conductor,
    `vpp_*` and `va_diff_*` one per pair of phase conductors, and the
    sequence objective and reporting functions (`opf_sequence_voltage`,
    `opf_vuf_term`, `opf_report_vuf`) transform the three phases of a bus
    that also carries a neutral and a protective earth. The bound producers
    and `solution_check` index the arrays the same way. **Breaking** for a
    case that declares a protective-earth label and sized these arrays to
    include it.
  - `solution_check` verifies DC voltage-pair bounds (`vdc_ln_*`,
    `vdc_ll_*`, reported as `E.SOL.DC_VOLT_VIOLATION`) and voltage-master
    setpoints (new `W.SOL.DC_VSET_RESIDUAL`), which a result could miss while
    every terminal stayed inside its own band.
  - On the DC side ideal conductors, exact voltage-pair bounds
    (`vdc_ln_min == vdc_ln_max`) and voltage masters share one reference
    graph, so restatements are dropped and contradictions raise; a loop is
    defined by current determinacy, so pinning the poles of an ideal
    triangle no longer hides it and an ideal conductor between two perfect
    grounds is a loop through the earth.
  - Sequence and unbalance limits take their three phases from one
    selection shared by preflight, builder and verifier, excluding a
    declared protective-earth terminal; a three-phase bus with a `pe`
    terminal used to skip the limit silently.
  - `solution_check` tolerates null `dc_bus`/`dc_branch` result blocks, and
    the solution report prints "not assessed" instead of a balance error
    when DC evidence is missing.
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
- Synthetic thermal inference in `augment_case` defaults to off; request
  `AugmentationRecipe(apply_thermal=true)` to reproduce the earlier synthetic
  rating policy and retain its provenance. `apply_vneg_bounds`/`vneg_max_pu`
  control injection of the `vuf_max` ratio on three-phase buses; existing
  absolute `vneg_max` values are preserved, so remove an old synthetic absolute
  cap explicitly if the ratio is the intended policy. Augmentation never
  overwrites previously generated bounds: rebuild split-phase bounds from the
  source case.

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
