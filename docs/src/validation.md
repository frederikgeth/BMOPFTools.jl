# Validating the OPF engine

BMOPFTools ships a reference nonlinear four-wire rectangular current–voltage OPF ([`solve_opf`](opf.md)) used to
validate cases and profile solutions. A reference solver is only as useful as its
own validation, so this page documents **how that engine is tested** — both so you
can judge the results and so you can **reuse the setup for your own tool**. 

The goal of our implementation is to be consistent with generally accepted circuit modeling practice
in the presence of nonlinear elements, including but not limited to constant power loads. We generally
trust OpenDSS's implementation correctness, however, modelers may disagree on
what appropriate models are. In this context, we recommend to study the paper "A perspective on transformer 
modeling for distribution system analysis", with full bibliographic details below. 

Three questions every distribution-OPF engine must answer, and the suite tests
each separately:

1. **Is the solution a valid power flow?** — *feasibility*: do the solved
   voltages and currents actually satisfy Kirchhoff's laws and the component
   models? We check this against **OpenDSS**. The same check is available for
   **your own** solved cases by [projecting the OPF onto a determined power
   flow](@ref opf-projection).
2. **Is it the optimum?** — *optimality*: given the objective and the operating
   bounds, does the optimizer reach the right dispatch? We check this against
   **closed-form solutions** and against **PowerModelsDistribution (PMD)**. 
   Note that we don't claim global optimality, just local. 
3. **Are the network limits encoded correctly?** — *limit correctness*: does
   each modeled limit (voltage magnitude, angle, current, power, sequence) hold
   the engineering meaning it claims, given that the variables are *rectangular*
   and most limits are therefore **not** box bounds on a variable? OpenDSS has no
   OPF limits to compare against, so we check each limit by **driving the network
   onto it and recomputing the limited quantity from the primal solution**.

The philosophy is the one stated in [the OPF formulation](opf.md): the accuracy of
the network physics matters more than any single objective, so feasibility is
validated exhaustively and component-by-component, while optimality is pinned to
independently-derived optima.

If you are building your own engine there are **two ways to reuse this**: adopt
the *harness* (the `.dss` cases and the comparison method), or adopt the
*locked-in numbers* (the objective and voltage baselines tabulated below) as
regression targets. The test files are the source of truth; the tables here
reproduce their headers.

## Feasibility — agreement with OpenDSS

Source: [`test/powerflow_comparison_tests.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/test/powerflow_comparison_tests.jl)
(24 testsets) over the 18 OpenDSS cases in
[`test/data/pf_comparison/`](https://github.com/frederikgeth/BMOPFTools.jl/tree/main/test/data/pf_comparison).

### The method: a power flow expressed as a feasibility OPF

There is no separate power-flow solver to validate — instead each case is solved
with [`solve_feasibility_opf`](opf.md#Feasibility-relaxation), which adds an
**elastic slack current** at every non-source terminal and minimises its squared
norm. When the optimal slack is ≈ 0, every KCL/KVL and component-model constraint
is satisfied exactly, so the solution *is* a valid power flow:

```julia
res     = solve_feasibility_opf(net; optimizer = Ipopt.Optimizer)
slack_A = res["total_slack_magnitude_A"]
@test slack_A < 1e-3          # the network balances with no injected slack
```

The same network is then solved in OpenDSS through OpenDSSDirect.jl, and the
complex node voltages are compared one-to-one. OpenDSS is solved *live* at test
time — there are no stored golden voltages; the `.dss` files themselves are the
immutable baseline (see [Voltage source as current slack](opf.md#source-slack)
for how the source/slack convention is matched).

On the BMOPF side the optimizer is **Ipopt at its defaults** — `tol = 1e-8`,
`max_iter = 3000`, the MUMPS linear solver — with output silenced. The only
deliberate change is in the feasibility variant, which sets
`acceptable_tol = 1e-8` to disable Ipopt's "acceptable level" early stop, so the
bilinear constant-power and thermal constraints converge to the full tolerance
rather than to an acceptable-but-loose point. Both sides of the comparison
therefore solve to near machine precision (OpenDSS at `1e-8`, Ipopt at `1e-8`),
which is what lets the residual be read as a *model* difference rather than the
slop of either solver.

The node-name mapping bridges the two conventions:

| OpenDSS node | BMOPF terminal |
|---|---|
| `bus.1` / `bus.2` / `bus.3` | `1` / `2` / `3` (phases) |
| `bus.4` | `n` (neutral) |
| `bus.0` | earth reference — skipped |

### Aligning the OpenDSS reference with the BMOPF model

The `.dss` cases deliberately depart from a default OpenDSS run. The point of
every deviation is the same: make OpenDSS evaluate the *same mathematical model*
that BMOPF solves, so a voltage mismatch can only mean a genuine modelling
disagreement — never a convergence convenience, a silent fallback, or an
ambient default. None of these settings tune the answer; they remove confounds.

| Setting (in every case `.dss`) | OpenDSS default | Why we override it |
|---|---|---|
| `New Circuit … model=ideal` | source has an internal (Thévenin) impedance from `MVAsc1`/`MVAsc3` | BMOPF fixes the source-bus voltage directly (the [current-slack convention](opf.md)). A non-ideal source would sag under load, so the source bus itself would disagree on every case. `model=ideal` collapses the internal impedance to zero — a true fixed-voltage slack. |
| `Load`/`PVSystem … Vminpu=0 Vmaxpu=2` (and `Vcutoff=0` for ZIP/exponential) | ≈ `Vminpu=0.95`, `Vmaxpu=1.05` | Outside that band OpenDSS silently switches a constant-power load to constant-impedance — a convergence aid BMOPF has no equivalent for. Widening the band keeps `model=1` strictly constant-P/Q (and the ZIP/exponential models on their true curve) across the whole voltage sweep. |
| `Set Tolerance=1e-8` | `1e-4` (per-unit voltage-change convergence) | At the default, OpenDSS's own iteration error is ≈ `1e-4` pu — about `1.1 V` on an 11 kV base, comparable to the voltage-comparison `atol` and far larger than the ≈ 0.1–0.3 V agreement the cases actually achieve. Tightening to `1e-8` drives OpenDSS's solution to near machine precision so its convergence slop cannot masquerade as a model error. |
| `Set MaxIterations=100` | `15` | Headroom so the tighter tolerance is actually reached rather than silently capping out. |
| `Set DefaultBaseFreq=50` | `60` (or whatever a Windows GUI session persisted to the registry/environment) | Line and transformer reactances are interpreted *at the base frequency*, so an ambient default silently rescales every `X`. BMOPF models at 50 Hz ([`to_pmd`](api.md)), so the cases pin 50 Hz explicitly. The absolute value matters less than locking it unambiguously: with the solve frequency tracking the base frequency, the ohmic reactances are used as written either way — but the lock removes the dependency on the host's configuration so the cases are portable and reproducible. |

Two further points on what we deliberately do **not** touch, so the "match the
math, don't tune the answer" claim stays honest:

- **Regulators are fixed-tap transformers**, not `RegControl` objects: the tap
  (`tap=1.05`, …) is baked into the winding, so there is no automatic tap-changing
  control loop to disable and the comparison is at a known, deterministic tap.
  `VoltageBases`/`CalcVoltageBases` (reporting only) and the solution `Algorithm`
  (left at the default `Normal`) are likewise untouched — neither changes the
  physics.
- **The open-delta regulator case (`pf_open_delta_reg`) does not converge in
  OpenDSS** at *any* tolerance or iteration cap — it is a known limitation of
  OpenDSS's fixed-point and Newton solvers on that topology, not a regression from
  the tighter tolerance (it did not converge at the `1e-4` default either). Its
  last iterate still matches BMOPF's exact solution within the comparison
  tolerance, which is itself evidence the comparison is robust to OpenDSS's
  solver behaviour. The remaining 17 cases converge to `1e-8` in ≤ 16 iterations.

### Tolerances and their rationale

The voltage comparison (`_cmp_volts`) uses:

| Case class | `atol` | `rtol` | Rationale |
|---|---:|---:|---|
| Lines, loads, single-phase & autotransformer | 0.3 V | 1e-3 | the worst phase-node error is ≈ 0.088 V (in the 4-wire cases), so 0.3 V keeps ~3.4× margin; on a ~240 V base `atol` is the binding tolerance |
| 3-phase Yd / Dy transformers, ≥ 70 % loading | 0.1 V | 1e-3 | at 75 % on a 500 kVA / 0.415 kV unit the LV-side series drop is ≈ 10 V, so 0.1 V demands < 1 % model agreement — any wrong sign, missing factor, or wrong impedance side shows up as > 1 V |
| n-winding transformers (all-wye and delta `Dyn`/`Dyyn`) | 0.3 V | 1e-3 | the HV/MV nodes are tens of kV, so `rtol` binds: the delta cases agree to ≈ 5e-5 relative (≈ 0.7 V on a 14 kV node), well inside 1e-3 — a wrong `delta_roll`/30° rotation or a missing coil-base factor shows up as a ~30 % or 3× error |

`isapprox` passes a node when `|ΔV| ≤ max(atol, rtol·|V|)`, so `rtol` binds the
high-voltage nodes and `atol` the low-voltage ones.

**Why these are not tighter.** The agreement is already close to the achievable
floor, and that floor is the *network model*, not solver precision — two
measurements pin this down:

- **Per-unit and SI solves give identical voltages** (to ~1e-8 V on the same
  case), so variable scaling is not the limiter.
- **In the 4-wire cases the error concentrates on the neutral terminal.** The
  phase voltages agree to ≈ 0.003–0.01 V, while the neutral sits **7–15× higher**
  (≈ 0.03–0.09 V) — the neutral voltage is a small residual set by load unbalance,
  so modelling differences in the grounding / earth-return path show up there
  rather than on the stiff, near-nominal phases.

Two further checks back up the voltage match: the feasibility slack
(`< 1e-3 A`), and total transformer losses against OpenDSS (`rtol = 0.05`). The
tolerances are deliberately tight enough to catch a single modelling error, not
merely "close".

### What the cases isolate

Each `.dss` file is a minimal 2-bus-style fixture that isolates one modelling
concern, so a failure points straight at the responsible component:

| Case file | Isolates |
|---|---|
| `pf_1ph_line`, `pf_3ph_line` | single- and three-phase line series impedance, unbalanced 4-wire loads |
| `pf_1ph_freeneutral`, `pf_1ph_impedanceneutral`, `pf_1ph_perfectneutral` | neutral grounding: floating, grounding-reactor (Z = 0.2 Ω), and perfectly grounded |
| `pf_zip_1ph`, `pf_zip_3ph`, `pf_zip_delta`, `pf_exp_1ph`, `pf_delta_load` | voltage-dependent load models — ZIP (distinct P/Q fractions), exponential (γ), and delta (line-to-line) connection |
| `pf_1ph_xfmr`, `pf_yd_xfmr`, `pf_dy_xfmr`, `pf_center_tap_xfmr` | transformer windings/vector groups: YY, Yd, Dy, and split-phase center-tap |
| `pf_combined_3ph_split` | **source-bus angle offset**: one MV source feeding a 3-phase Dy *and* a split-phase center-tap transformer, solved both at the baseline angle and at a non-zero (+17°) source angle (see [Source-angle convention](#Source-angle-convention) below) |
| `pf_3wdg_nwinding`, `pf_3wdg_nwinding_unbalanced`, `pf_4wdg_nwinding` | **general n-winding** transformer (all-wye), 3- and 4-winding, against OpenDSS's own multi-winding solve — exact ZB leakage (all pairwise reactances, no star approximation), balanced and unbalanced loading, SI and per-unit |
| `pf_3wdg_dyn`, `pf_3wdg_dyn_unbalanced`, `pf_4wdg_dyyn`, `pf_3wdg_dyn_zgnd` | **n-winding with a DELTA winding** (`Dyn`/`Dyyn`, delta primary): winding count (3/4), neutral grounding (solid vs 0.5 Ω-shunt MV neutral), unbalanced loading, the `solve_pf`/feasibility-OPF paths, and per-unit. The delta coil is line-to-line (`delta_roll = -1` matches OpenDSS's 30° rotation; `r_winding`/`x_sc` on the delta coil base `n_ph·V_LL²/S`) |
| `pf_center_tap_loaded`, `pf_center_tap_balanced_heavy`, `pf_center_tap_240`, `pf_center_tap_singleleg_pn`, `pf_center_tap_oneleg_extreme` | split-phase **coupled-coil** model under load — leg symmetry on a balanced heavy load, a 240 V phase-to-phase load, a single leg-to-neutral load, and an extreme one-leg load (see [Split-phase transformer depth](#Split-phase-transformer-depth)) |
| `pf_autotransformer`, `pf_open_delta_reg` | step-voltage regulators / autotransformers and open-delta (ABBC) regulation |
| `pf_cap_wye`, `pf_cap_delta` | fixed shunt **capacitor banks** (wye / delta) as a constant susceptance `B = q_rated/v_nom²`, validated against OpenDSS's own `Capacitor` solve in both SI and per-unit, and cross-checked against the equivalent `shunt` object |
| `pf_pv_1ph`, `pf_pv_4leg` | IBR current injection at a pinned dispatch — single-phase and FOUR_LEG |

Single-phase, FOUR_LEG per-phase, and FOUR_LEG AVERAGE-reference **smart-IBR
droop** are additionally validated against OpenDSS `InvControl` (deadband, slope,
and saturation regimes) within the same file.

**Each case must produce a meaningful voltage difference between its buses.** If
every terminal sat at ≈ 1 pu there would be nothing for a model error to
perturb and agreement would be trivial, so each fixture is loaded to create a
real drop: the line and load cases sag 5–11 % under load, and the transformers
add 2–3.5 % of series drop on top of the turns ratio (the autotransformer is
loaded to ≈ 82 % of rating for exactly this reason — at light load it would only
exercise the fixed tap, not the series impedance). A dedicated **load-scaling
sweep** solves `pf_3ph_line` at ×0.5 / ×1.0 / ×1.5 and asserts both that
agreement holds as the operating point moves and that the voltage sags
*monotonically* with load, so each step is a strictly stronger test than the
last. The sweep stops at ×1.5 because this stiff feeder reaches its power-flow
nose near ×2, beyond which the solution is no longer unique (the flat start and
OpenDSS can land on different branches) — a property of the network, not a model
disagreement.

### Source-angle convention

Every other fixture pins the slack reference at `New Circuit … angle=0`, so a
mistake in the **source-angle convention** — BMOPF's `voltage_source.v_angle` is
in **radians**, OpenDSS's `angle` in **degrees** — would never surface. The
`pf_combined_3ph_split` case closes that gap. It is one MV source feeding two
branches at once: a three-phase `delta_wye` (the 30° vector-group shift) and a
split-phase `center_tap` (the leg-polarity model). It is solved twice:

- **baseline** (`angle=0`) confirms the *combined* model is correct, isolating any
  model error from a convention error;
- **offset** rotates the slack reference by **+17°** — a non-30°-multiple, so a
  wrong unit or a flipped sign would show as a tens-of-percent mismatch, not a
  small one. The OpenDSS reference is re-angled in place (`Edit Vsource.source
  angle=17; Solve`) and BMOPF's `v_angle` is shifted by the same amount in radians.

Because a single-source, generator-free network has the source as its only angle
anchor, the offset must **rigidly rotate the whole solution** — every transformer
phase shift is relative and survives the rotation. The feasibility solve
converging from the offset also exercises the angle-aware voltage initialisation.
A companion analysis test asserts the corollary: **vector-group tagging**
(terminal-map topology) and **voltage-level tagging** (`v_magnitude` / `v_nom`
ratios) read no angle, so both are byte-identical with and without the offset.

### Split-phase transformer depth

The split-phase (`center_tap`) transformer gets extra scrutiny because its two
LV half-windings are tightly coupled on a shared core — a per-leg *decoupled*
drop omits that coupling and silently spreads the legs apart under load. The OPF
therefore imposes the OpenDSS-consistent 5×5 primitive admittance (see the
[OPF reference](opf.md) and [Transformer primitive admittance](spec/transformer-admittance.md)),
and a family of fixtures pins it down rather than a single light-load case:

- **Leg symmetry under a balanced heavy load** (`pf_center_tap_balanced_heavy`):
  a perfectly balanced load must keep the two legs equal; the fixture asserts
  `|V_leg1 − V_ctr| ≈ |V_ctr − V_leg2|` directly, which is exactly what the old
  decoupled model failed.
- **Phase-to-phase, single-leg, and extreme one-leg loads**
  (`pf_center_tap_240` / `_singleleg_pn` / `_oneleg_extreme`): the 240 V load
  exercises the series-aiding winding polarity with zero centre-tap current;
  the unbalanced loads drive the legs apart and check the split against OpenDSS.
  Node voltages hold the default tight band (**atol 0.3 V / rtol 3e-3**) and
  total losses match within **3 %** — the looser legacy tolerance is retired.
- **OPF ↔ Ybus agreement** (`center_tap OPF and Ybus models agree`): the OPF
  builder and the Ybus exporter implement the device independently, so a test
  asserts the centre-tap KCL closes on the `_yprim_center_tap` admittance — a
  guard against the two paths drifting apart again.
- **Continuous tap optimisation under drop + unbalance** (*optimised tap vs
  OpenDSS (center_tap)*): a free HV tap on `pf_center_tap_loaded` (5 km feeder,
  heavy unequal legs) is optimised, then OpenDSS is solved with that tap set on
  winding 1. Node voltages match to **≈ 0.25 V** and **total losses to ≈ 5 %**
  (`rtol = 0.08` — the core loss now matches OpenDSS exactly on the boosted LV;
  the residual is a documented center_tap leakage deviation at this extreme
  boost point, see [transformer models](transformer_models.md)), and a wide-band
  internal-exactness check confirms the free degree-2 T-model reproduces the
  fixed-`Yprim` re-solve at ``t^\star`` to **0.0 V** — so promoting the ratio to
  a variable adds no modelling error.
- **Exact tap² referral for Yd/Dy** (*optimised tap vs OpenDSS (delta_wye Dy)*,
  and *Yd/Dy fixed tap across the schema band*): the coupled delta-arm leakage
  carries the exact ``tap²`` referral (matching OpenDSS's winding-1
  self-impedance scaling — verified directly against OpenDSS's short-circuit
  `Yprim`), applied identically in the OPF and the `Yprim` export. Validated at
  the ±10 % schema band edges at 4 fixed taps for both Yd and Dy against
  OpenDSS's turns-scaled `Yprim`, plus the Dy optimised free tap — agreement is
  at the ~0.3 V node-voltage floor at *every* tap, not just nominal.

### Parse-path and primitive-admittance gates

Two further testsets validate the transformer modelling beyond the hand-built
fixtures above:

- **`from_dss` transformer fidelity** (`single_phase`/`wye_delta`/`delta_wye`):
  the vector-group cases above are built as hand-authored BMOPF nets; this set
  runs the *parse* path (`from_dss` of the same `.dss`) through `solve_pf` and
  compares to OpenDSS, matching voltages and total losses. It guards the
  no-load shunt normalization — placed on **winding 2** (the OpenDSS
  convention), including the magnetising susceptance (`%imag` → negative
  `b_no_load`) — and the `delta_wye` leakage carried by PowerIO v0.6.2's BMOPF
  export, plus the `phases=1` requirement on grounding reactors without which
  the Dy neutral floats and the solve diverges.
- **Transformer `Yprim` matches OpenDSS** (`single_phase`, `center_tap`,
  `wye_delta`, `delta_wye`): the correctness gate from
  [Transformer primitive admittance](spec/transformer-admittance.md#7.-Validation-and-implementation) — the per-element primitive
  admittance is compared term-by-term against OpenDSS's own
  `CktElement.YPrim()`. This is the check that catches turns-ratio direction, √3
  scaling, shunt placement, and winding-polarity sign errors directly: it would
  have caught the original `center_tap` leg-split bug, and extending it to the
  delta subtypes exposed (and now guards) an inverted Yd/Dy export primitive
  that every symmetry/passivity oracle had passed. The Yd/Dy fixtures carry the
  wye neutral as an explicit bus terminal with external grounding, so the
  OpenDSS node set aligns directly with the BMOPF one.
- **OPF ↔ `Yprim` export at a solved setpoint** (`single_phase`, `wye_delta`,
  `delta_wye`, incl. off-nominal fixed taps; plus the `center_tap` variant
  above): the OPF builders and the `Yprim` export implement each subtype
  independently, so after a `solve_pf` the element current implied by the
  exported admittance (``I = Y_p V``) is compared node-by-node against the
  solved winding-current variables. This is the standing drift guard between
  the OPF engine and the exported primitive matrices.
- **Internal winding neutral grounding (`rneut`/`xneut`)**: OpenDSS grounds an
  impedance-grounded wye star point through a transformer-internal branch; the
  BMOPF `r/x_neutral_from`/`to` fields reproduce it. Validated three ways on an
  unbalanced Dy fixture whose ONLY LV earth path is that branch: full PF node
  voltages vs OpenDSS (the branch anchors the galvanically isolated LV island's
  reference; the grounded-wye star absorbs the zero-sequence load current
  metallically, so both engines agree at ≈0 V on the neutral), the
  `Yprim` neutral-node diagonal entry-wise vs `CktElement.YPrim()` (with a
  counterfactual check that omitting the stamp misses OpenDSS by ≈``|y_n|``),
  and the OPF↔`Yprim` setpoint gate.
- **PowerIO import fidelity** (`from_dss`): fixed off-nominal `taps=`, neutral
  grounding, and validated 3-phase 3-winding transformers arrive through
  PowerIO v0.6.2's BMOPF export and are checked end to end against OpenDSS.
  Unsupported winding sets refuse loudly.

### System nodal admittance gates

The gates above validate *per-element* primitives. Two further testsets validate
the *assembled* [system nodal admittance matrix](spec/nodal-admittance.md) — the
whole-network ``\mathbf{Y}`` built by [`ybus_passive`](@ref) /
[`ybus_linearized`](@ref) — against OpenDSS's own system matrix and power flow.

- **Passive `Ybus` matches OpenDSS `getYsparse`** (`test/ybus_tests.jl`): on
  purpose-built **load-free** decks (`test/data/ybus/`), OpenDSS's system Y is
  exactly the passive-element `Yprim`s plus the `Vsource` primitive. Compared
  over the non-source buses, `ybus_passive` reproduces OpenDSS's
  `YMatrix.getYsparse()` term-by-term — to machine precision for the line-Π and
  capacitor case, and ``\sim 10^{-6}`` for the imported Yd transformer (the
  residual is `%r`/`%noloadloss` import rounding, not a model difference).
  Load-free is deliberate: OpenDSS folds a load's linearized admittance
  (``\approx \overline{S}/|V|^2``) into its `getYsparse` diagonal, so a case with
  loads would not isolate the passive network.
- **Linearized `Ybus` power-flow residual** (`test/ybus_linearized_tests.jl`):
  at OpenDSS's converged voltage ``\mathbf{v}_0``, the fixed-point relation
  ``\mathbf{Y}\,\mathbf{v}_0 = \mathbf{i}_{\text{comp}}(\mathbf{v}_0)`` must hold
  — i.e. the net current is ``\approx 0`` at every non-source node. This is
  asserted for **both** fold modes (`:constant_z` and `:all`) across the
  `pf_comparison` WYE / DELTA / SINGLE\_PHASE ZIP and constant-power decks, and
  is the strongest single check: it exercises the passive assembly *and* the
  load folding together against an independent OpenDSS power flow, with the load
  model's constant-Z / constant-I / constant-P split reconstructed exactly. Two
  decks are excluded because `from_dss` imports them lossily rather than for any
  Ybus reason — a 4-wire line whose neutral is dropped from the terminal map
  ([#332](https://github.com/frederikgeth/BMOPFTools.jl/issues/332)) and an
  exponential/CVR load silently imported as constant-power
  ([#333](https://github.com/frederikgeth/BMOPFTools.jl/issues/333)).

The `Ybus` gates run without JuMP — they need only OpenDSSDirect.jl — so they
execute on any CI job that has the OpenDSS reference available, independently of
the solver stack.

### Reusing the feasibility setup

The `.dss` files are portable and engine-agnostic: point your own solver at a
case, solve the same `.dss` in OpenDSS for the reference voltages, and compare
node-by-node with the mapping and tolerances above. No BMOPFTools dependency is
needed to reuse the baseline.

## [Validating a solution end-to-end — projecting the OPF onto a power flow](@id opf-projection)

The feasibility harness above validates the **engine** on a fixed set of `.dss`
fixtures. But you will also want to validate a **particular solution you just
computed** on your own network: is the dispatch `solve_opf` returned actually a
feasible power flow? [`project_solution`](@ref) generalises the feasibility
cross-check to any solved case, so you can run the same OpenDSS oracle test on
your own OPF results rather than only on the shipped fixtures.

### The idea: pin the solution, re-solve as a determined power flow

An OPF has *degrees of freedom* — generator/IBR dispatch, free transformer taps,
smart-inverter setpoints — that a power flow does not. If you **pin every one of
those to the value it takes in the OPF solution**, the only quantities still free
are the nodal voltages: the network is now a fully *determined* power flow, and
that power flow can be re-solved by an independent solver to check that the OPF's
predicted voltages and currents really do satisfy Kirchhoff's laws and the
component models.

[`project_solution(net, result)`](@ref) does exactly this pinning and returns a
deep copy of `net` (the input is never mutated):

- **Generators and IBRs** — per-phase active/reactive dispatch is frozen to the
  solved values (`p_min == p_max == pg`, `q_min == q_max == qg`). An IBR running a
  Volt-var / power-factor `control_profile` has the profile dropped and explicit
  fixed bounds written, freezing the smart-inverter control at its solved operating
  point (the profile couples `Q` to `P` internally, so pinning both fixes it).
- **Free transformer taps** — a tap that was an OPF decision variable (reported as
  `tap` / `tap_ratio` in the result) is written back onto the winding. Fixed-tap
  transformers are left untouched.

The result is a legal input to [`solve_pf`](@ref) and, via [`to_dss`](@ref), an
OpenDSS deck whose only free quantities are the voltages.
`result["_meta"]["projection"]` on the returned net records exactly what was
pinned (`generators`, `ibrs`, `control_profiles_frozen`, `free_taps`) so a later
oracle mismatch can be attributed.

### The three-way triangulation

With a determined snapshot in hand there are three independent estimates of the
same voltages, and comparing them *localises* any disagreement:

| | Source | What it is |
|---|---|---|
| **A** | `result["bus"]` | the OPF's own predicted voltages |
| **B** | `solve_pf(project_solution(net, result))` | BMOPF re-solving the pinned snapshot as a power flow (self-oracle) |
| **C** | OpenDSS solving `to_dss(...)` of the snapshot | an *independent* engine (external oracle) |

Reading the pattern:

- **A ≈ B** confirms the projection is exact and the OPF's rectangular solution is
  a self-consistent power flow — in practice these agree to ``\sim\!10^{-7}`` V, so
  a divergence here points at the OPF or the projection, not the network.
- **A ≈ B ≉ C** isolates a *conversion* problem — the model BMOPF solved and the
  model OpenDSS solved differ (an export gap), not the OPF itself. This is how the
  [PowerIO export gaps](conversion.md#to-dss-export) were found.

The A ≈ B leg needs no external dependency; the C leg needs an OpenDSS solve, and
is subject to the [`to_dss` fidelity limits](conversion.md#Known-limitations) —
notably that PowerIO cannot yet emit a BMOPF `ibr`/`generator`, and currently
writes `kvs = NaN` for transformers, so the OpenDSS oracle is exercised on
transformer-free cases while that gap is upstream.

### Exporting the dispatch to OpenDSS — `dispatch_as_loads`

Because [`to_dss`](@ref) cannot yet serialise a BMOPF `ibr`/`generator`,
[`dispatch_as_loads`](@ref) bridges the gap: it rewrites every **pinned**
generator/IBR as an equivalent constant-power **negative load**
(`p_nom = -p_min`, `q_nom = -q_min`) — which PowerIO exports faithfully — carrying
the device's terminal map and connection. A fixed PQ injection *is* a negative
constant-power load, so under the determined power flow the two forms are
equivalent (`solve_pf` agrees to ``\sim\!10^{-6}`` V). Generation sitting on a
`voltage_source` bus is **dropped, not converted** — the slack source is the
reference injector in a power flow and its dispatch must not be re-imposed as a
load. This bridge can be retired once PowerIO maps `ibr`/`generator` directly.

### Putting it together

```julia
net    = from_dss("my_feeder.dss")
result = solve_opf(net)                    # your OPF solution

snap   = project_solution(net, result)     # pin every setpoint → determined snapshot
res_B  = solve_pf(snap)                     # B: BMOPF self-oracle  (expect A ≈ B)

deck   = dispatch_as_loads(snap)            # generators/IBRs → negative loads
to_dss(deck, "snap.dss")                    # C: hand to OpenDSS   (expect A ≈ B ≈ C)
```

The comparators used in the test suite (`test/roundtrip_helpers.jl`) apply the
same node-name bridge and skip tolerance (`|V| < 1e-4` earth/neutral nodes) as the
feasibility harness above, so the projection cross-check reuses the OpenDSS
comparison method verbatim — the only new machinery is the pinning.
[`test/projection_tests.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/test/projection_tests.jl)
runs this on DER-augmented feeders and free-tap fixtures (the raw `pf_comparison`
cases have no decision variables, so projection is a no-op there).

## Optimality — agreement with known optima

Feasibility proves the physics; optimality proves the optimizer reaches the right
point. Three complementary tiers, each with a different source of truth.

### Tier 1 — closed-form analytic targets

Source: [`test/opf_tests.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/test/opf_tests.jl).
Tiny networks whose optimum is solvable by hand, so the target is exact rather
than borrowed. For a single-phase resistive feeder the load-bus voltage is the
root of the power-flow quadratic

```math
V = \frac{V_s + \sqrt{V_s^2 - 4RP}}{2},
```

and dispatch/cost tests pin the objective directly:

| Test | Analytic target | Tolerance |
|---|---|---|
| T1 — single-phase resistive | `V = (V_s + √(V_s² − 4RP))/2 ≈ 947.214 V` | 0.01 V |
| T3 — forced generator dispatch | `V ≈ 974.342 V`, `objective = cost·P_gen` | 0.01 V / 0.1 |
| T4 — negative cost ⇒ `p_max` binding | each phase at `p_max = 50 kW`, `objective = −3·P_max` | 1.0 W / 10 |
| T5 — power-balance identity | `P_source = P_load + P_line_loss` | 0.1 W |
| T10 — sequence voltage bounds | tight `vneg_max`/`vzero_max` ⇒ balanced `V_phase = vpos_max` | 5.0 V |

The suite also pins per-unit ⇄ SI agreement, immutability of the input network,
and the result-dictionary contract (see [the result schema](results.md)).

### Tier 2 — golden objectives ported from PowerModelsDistribution

Source: [`test/pmd_opf_port_tests.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/test/pmd_opf_port_tests.jl).
These fixtures rebuild PMD's small OPF test networks directly in BMOPF's native
schema (no PMD dependency) and assert the **published PMD objective** — the slack
injection summed over phases, reported as `voltage_source[...]["ps"|"qs"]`. The
2/3-bus cases target PMD's `IVRUPowerModel` (the formulation closest to BMOPF's
current-voltage engine); the 4/5-bus and delta cases target PMD's AC formulations,
whose objectives are formulation-independent.

**Locked-in baseline** (reuse these as regression targets; `atol = 1e-2 kW/kvar`
unless noted):

| Case | Σ pg (kW) | Σ qg (kvar) | PMD reference |
|---|---:|---:|---|
| 2-bus diagonal | 18.209 | 0.208 | `opf_iv.jl` (IVR) |
| 3-bus balanced | 18.345 | 9.194 | `opf_iv.jl` (IVR) |
| 3-bus unbalanced | 21.4812 | 9.27263 | `opf_iv.jl` (IVR) |
| 4-bus phase drop | 18.2632 | 9.02334 | `opf.jl` (AC) — also pins load-bus voltages |
| 5-bus phase drop | 59.9363 | −33.5395 | `opf.jl` (AC) — also pins mid-bus voltages |
| 3-bus delta + ZIP | 42.0464 | 18.1928 | `opf.jl` (AC) — `atol = 1.0 kW/kvar`, voltage-dependent |

Each fixture rebuilds the network from the underlying OpenDSS source that PMD
ships (`case{2_diag,3_balanced,3_unbalanced,4_phase_drop,5_phase_drop,3_unbalanced_delta_loads}.dss`),
so the chain is OpenDSS case → BMOPF schema → BMOPF OPF → PMD objective.

### Tier 3 — droop optimization correctness

Source: [`test/volt_var_watt_tests.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/test/volt_var_watt_tests.jl).
The smart-IBR Volt-var / Volt-watt droop is encoded as constraints *inside*
the OPF (see [Smooth droop encoding](relu_softplus_encoding.md) and the
[VVWO tutorial](tutorial_vvwo.md)). These tests check the optimizer lands on the
droop curve in every regime:

- **Volt-watt** — active power binds to the curtailment cap at the solved voltage
  (`atol = 5 W`) once the droop region is active (`V > 253 V`);
- **Volt-var** — reactive power follows the four-point characteristic, absorbing
  near `V4` (`atol = 5 var`) and ≈ 0 in the deadband (`|Q| < 30 var`);
- **voltage reference — aggregation** — `PER_PHASE` gives three distinct per-phase
  `Q`'s on an unbalanced bus while `AVERAGE` gives one common `Q` (the contrast the
  VVWO tutorial's appendix shows), plus the exact-vs-smooth encoding agreement as
  the corner-smoothing `ε → 0` (`atol = 2e-3`);
- **voltage reference — quantity** — the six `voltage_reference_type` values split
  correctly into quantity × aggregation, the `_AVERAGED` suffix drives aggregation
  on its own (without the legacy `voltage_aggregation` field), and phase-to-ground
  (`PG_PER_PHASE`) and phase-to-neutral (`PN_PER_PHASE`) dispatch differently once
  the neutral is displaced from ground.

## Limit correctness — each network limit encodes what it claims

Feasibility checks the physics and optimality checks the dispatch — but both take
the **constraint set as given**. Neither asks the prior question: does each
inequality *limit* actually encode the engineering limit it is named for? A limit
can be wrong in a way that passes every test above — a sign error in an angle
constraint still yields "an optimum", just the optimum of the wrong feasible set.

This needs its own axis for two reasons:

- **OpenDSS cannot be the oracle.** OpenDSS is a power-flow engine with no OPF
  inequality limits, so the feasibility harness structurally cannot exercise a
  single limit constraint — they are *invisible* to it.
- **The limits are not box bounds.** The engine's variables are rectangular
  (`vr`, `vi`, `cr`, `ci`), so almost no network limit is a simple bound on a
  variable. They take four mathematically distinct shapes, and each shape hides a
  characteristic error mode:

  | Class | Shape | Encoding (rectangular) | The trap |
  |---|---|---|---|
  | **A — magnitude** | quadratic ball / annulus | `vr²+vi² ∈ [lb², ub²]`; `cr²+ci² ≤ ilim²`; `pg²+qg² ≤ s_max²` | the *lower* bound makes a magnitude limit a **nonconvex annulus** |
  | **B — angle** | bilinear cross/dot | `s = vr_k·vi_j − vi_k·vr_j`, `c = vr_k·vr_j + vi_k·vi_j`, then `tan_min·c ≤ s ≤ tan_max·c` | no angle variable exists; a **flipped cross-product sign or wrong pair ordering** is silent |
  | **C — sequence** | Fortescue then magnitude | `|V₁|², |V₂|², |V₀|²` from the `a`-operator combination of the three phase phasors | a **wrong rotation constant or `1/3` factor** passes feasibility unnoticed |
  | **D — power** | bound on a bilinear expression | `p = vr·ir + vi·ii`; `p_min ≤ p ≤ p_max`; `pf·q + tan_φ·p = 0` | even a "simple" P/Q bound is a **nonconvex constraint**, not a variable bound |

### The method: bind, then recompute from the primal

Source: [`test/network_limit_tests.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/test/network_limit_tests.jl).
Each test (1) builds a minimal case where the target limit is the **single active
constraint** and drives the network onto it; (2) solves; (3) **recomputes the
limited quantity from the primal solution by an independent route** — `sqrt(vr²+vi²)`,
`atan2(vi, vr)` differences, an explicit Fortescue matrix, `sqrt(pg²+qg²)` — *never*
by reading back the constraint's own expression — and asserts it equals the named
threshold. Recomputing by a different route is what catches a factor-of, a flipped
sign, or a wrong constant; a test that echoed the constraint expression would not.
This mirrors the **Tier-3 droop tests** above, which already "land on the curve"
by the same logic.

The sequence-bound test (T10 in [`opf_tests.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/test/opf_tests.jl))
is the worked example: it solves a balanced case against tight `vneg_max`/`vzero_max`,
then rebuilds `V₁`, `V₂`, `V₀` from the solved rectangular phase voltages with an
independent Fortescue expansion and asserts each component sits at its bound.

### The limit inventory — test backlog and discussion

The table below enumerates the engine's nontrivial limits (from `ext/BMOPFOpfExt/`).
It is the **single source of truth shared by this page and the test file**: each
row is one unit test to develop, and the *status* column tracks coverage.

| Limit | Class | Encoding | Source | Status |
|---|---|---|---|---|
| Terminal voltage magnitude (`v_min`/`v_max`) | A | `vr²+vi² ∈ [lb²,ub²]` | `bus.jl` | covered (T1, T10) |
| Neutral voltage magnitude (`vn_max`) | A | `vr_n²+vi_n² ≤ vn_max²` | `bus.jl` | gap |
| Phase-to-neutral magnitude (`vpn_min`/`vpn_max`) | A | `Δ(p,n)² ∈ [·²,·²]` | `bus.jl` | gap |
| Phase-to-phase magnitude (`vpp_min`/`vpp_max`) | A | `Δ(k,j)² ∈ [·²,·²]` | `bus.jl` | gap |
| Bus angle difference (`va_diff_min`/`va_diff_max`, centered on `va_nom`) | B | `tan·c ≤ s ≤ tan·c` on `θ_j−θ_k−Δ`, `Δ=va_nom[j]−va_nom[k]` | `bus.jl` | covered (L-B1, L-B1b) |
| Positive-sequence voltage (`vpos_min`/`vpos_max`) | C | `|V₁|²` via Fortescue | `bus.jl` | covered (T10) |
| Negative-sequence voltage (`vneg_max`) | C | `|V₂|² ≤ vneg_max²` | `bus.jl` | covered (L-C2, T10) |
| Zero-sequence voltage (`vzero_max`) | C | `|V₀|² ≤ vzero_max²` (note `/3`) | `bus.jl` | covered (T10) |
| Branch series current (`i_max`) | A | `cr²+ci² ≤ i_max²` (both ends) | `branch.jl` | scaffold (L-A5) |
| Branch apparent power (`s_max`) | D | `P²+Q² ≤ s_max²`, `S=v∘conj(I_tot)` ground-referenced per conductor (both ends) | `branch.jl` | covered (L-SMAX-LINE) |
| Branch angle difference (`va_diff_*`) | B | `tan·c ≤ s ≤ tan·c` | `branch.jl` | gap |
| Switch current | A | `cr_sw²+ci_sw² ≤ ilim²` | `branch.jl` | gap |
| Switch apparent power (`s_max`) | D | `P²+Q² ≤ s_max²` ground-referenced per conductor | `branch.jl` | covered (L-SMAX-SW) |
| Transformer winding/terminal currents | A | `Is²,It²,In² ≤ i_max²` (native); post-solve per-winding `cm ≤ i_max_from/to` | `transformer.jl`, `solution.jl` | covered (post-solve) |
| Transformer nameplate power (`s_rating`, required → always enforced) | D | per-winding coil `P²+Q² ≤ (s_rating/n_ph)²` (native); post-solve coil `\|S\| ≤ s_max` from result `s`/`s_max` | `transformer.jl`, `solution.jl` | covered (L-SMAX-XFMR) |
| n-winding per-winding power (`s_max`) | D | per-winding coil `P²+Q² ≤ (s_max/n_ph)²` (native + post-solve) | `nwinding.jl`, `solution.jl` | covered (L-SMAX-NW) |
| Generator / source P,Q limits | D | bounds on `p=vr·ir+vi·ii` | `generator.jl`, `source.jl` | covered (T3, T4) |
| Generator / IBR apparent power (`s_max`) | A | `pg²+qg² ≤ s_max²` | `generator.jl`, `ibr.jl` | covered (T-INV3); strict recompute scaffold (L-A8) |
| Generator / IBR current magnitude (`i_max`) | A | `cr²+ci² ≤ i_max²` (optional, opt-in) | `generator.jl`, `ibr.jl` | covered (T-INV5, T-INV6, T-GEN-IMAX, T-GEN-IMAX-PU) |
| IBR power-factor coupling | D | `pf·q + tan_φ·p = 0` | `ibr.jl` | gap (see [VVWO](tutorial_vvwo.md)) |

## Reusing this for your own tool

| You want to … | Use | What it proves |
|---|---|---|
| validate your power-flow / component models | the `.dss` cases + a live OpenDSS solve, compared as above | the network physics is correct |
| validate your optimizer | the Tier-1 analytic targets and the Tier-2 PMD objective table as regression checks | the optimizer reaches the true optimum |
| validate smart-IBR control | the Tier-3 droop setpoints | control laws are enforced as modelled |
| validate your network-limit encodings | the bind-and-recompute method + the limit inventory | each limit means what it claims, in rectangular variables |

The two reuse paths are complementary: the analytic and PMD numbers are
*self-contained* baselines (copy the table, no dependency), while the `.dss`
feasibility cases need an OpenDSS solve to regenerate the reference — which is the
point, since OpenDSS is the de-facto distribution power-flow oracle.

## Running the suite

The OPF and OpenDSS tests are optional dependencies, guarded in
[`test/runtests.jl`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/test/runtests.jl):

- the optimality tests (`opf_tests.jl`, `pmd_opf_port_tests.jl`,
  `volt_var_watt_tests.jl`) run when JuMP + Ipopt are present (`_HAS_JUMP_IPOPT`);
- the feasibility comparison (`powerflow_comparison_tests.jl`) additionally needs
  OpenDSSDirect.jl (`_HAS_ODS`).

When a dependency is absent the relevant testset is `@test_skip`-ped rather than
failed, so the core suite runs anywhere. Run everything from the package root:

```
julia --project=. -e "using Pkg; Pkg.test()"
```

## [References](@id refs-validation)

1. D. M. Fobes, S. Claeys, F. Geth, C. Coffrin, *PowerModelsDistribution.jl: An
   open-source framework for exploring distribution power flow formulations*,
   Electric Power Systems Research, 2020. (Source of the ported optimality
   fixtures.)
2. R. C. Dugan, T. E. McDermott, *An open source platform for collaborating on
   smart grid research* (OpenDSS), IEEE PES General Meeting, 2011; the
   OpenDSSDirect.jl interface is used for the live reference solves.
3. M. Deakin, A. Pandey, F. Geth, *Mathematical Model and Data Model for
   Up-To-Four-Wire Distribution System OPF*, IEEE Task Force on Benchmarking
   Multiconductor OPF for Distribution Systems, draft V0.2, 2026.
4. R. C. Dugan, "A perspective on transformer modeling for distribution system analysis," 
   2003 IEEE Power Engineering Society General Meeting (IEEE Cat. No.03CH37491), Toronto, 
   ON, Canada, 2003, pp. 114-119 Vol. 1, doi: 10.1109/PES.2003.1267146.
