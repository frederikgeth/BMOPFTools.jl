# Validating the OPF engine

BMOPFTools ships a reference nonlinear four-wire IVR-EN OPF ([`solve_opf`](opf.md)) used to
validate cases and profile solutions. A reference solver is only as useful as its
own validation, so this page documents **how that engine is tested** — both so you
can judge the results and so you can **reuse the setup for your own tool**. 

The goal of our implementation is to be consistent with generally accepted circuit modeling practice
in the presence of nonlinear elements, including but not limited to constant power loads. We generally
trust OpenDSS's implementation correctness, however, modelers may disagree on
what appropriate models are. In this context, we recommend to study the paper "A perspective on transformer 
modeling for distribution system analysis", with full bibliographic details below. 

Two questions every distribution-OPF engine must answer, and the suite tests each
separately:

1. **Is the solution a valid power flow?** — *feasibility*: do the solved
   voltages and currents actually satisfy Kirchhoff's laws and the component
   models? We check this against **OpenDSS**.
2. **Is it the optimum?** — *optimality*: given the objective and the operating
   bounds, does the optimizer reach the right dispatch? We check this against
   **closed-form solutions** and against **PowerModelsDistribution (PMD)**. 
   Note that we don't claim global optimality, just local. 

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
| `pf_autotransformer`, `pf_open_delta_reg` | step-voltage regulators / autotransformers and open-delta (ABBC) regulation |
| `pf_pv_1ph`, `pf_pv_4leg` | inverter current injection at a pinned dispatch — single-phase and FOUR_LEG |

Single-phase, FOUR_LEG per-phase, and FOUR_LEG AVERAGE-reference **smart-inverter
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

### Reusing the feasibility setup

The `.dss` files are portable and engine-agnostic: point your own solver at a
case, solve the same `.dss` in OpenDSS for the reference voltages, and compare
node-by-node with the mapping and tolerances above. No BMOPFTools dependency is
needed to reuse the baseline.

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
The smart-inverter Volt-var / Volt-watt droop is encoded as constraints *inside*
the OPF (see [Smooth droop encoding](relu_softplus_encoding.md) and the
[VVWO tutorial](tutorial_vvwo.md)). These tests check the optimizer lands on the
droop curve in every regime:

- **Volt-watt** — active power binds to the curtailment cap at the solved voltage
  (`atol = 5 W`) once the droop region is active (`V > 253 V`);
- **Volt-var** — reactive power follows the four-point characteristic, absorbing
  near `V4` (`atol = 5 var`) and ≈ 0 in the deadband (`|Q| < 30 var`);
- **voltage reference** — `PER_PHASE` gives three distinct per-phase `Q`'s on an
  unbalanced bus while `AVERAGE` gives one common `Q` (the contrast the VVWO
  tutorial's appendix shows), plus the exact-vs-smooth encoding agreement as the
  corner-smoothing `ε → 0` (`atol = 2e-3`).

## Reusing this for your own tool

| You want to … | Use | What it proves |
|---|---|---|
| validate your power-flow / component models | the `.dss` cases + a live OpenDSS solve, compared as above | the network physics is correct |
| validate your optimizer | the Tier-1 analytic targets and the Tier-2 PMD objective table as regression checks | the optimizer reaches the true optimum |
| validate smart-inverter control | the Tier-3 droop setpoints | control laws are enforced as modelled |

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