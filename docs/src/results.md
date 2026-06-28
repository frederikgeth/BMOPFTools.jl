# OPF result dictionary

`solve_opf` returns a plain `Dict{String,Any}` in SI units (V, A, W, var).
The structure mirrors the input network dict: top-level keys match the network's
component types, and within each component the result is keyed by the component
id, then by terminal name (or winding label for transformers).

```julia
result = solve_opf(net)

result["termination_status"]   # "LOCALLY_SOLVED", "INFEASIBLE", …
result["objective"]            # total generation cost
result["solve_time"]           # wall-clock time in seconds

result["bus"]["b1"]["1"]["vm"] # phase-1 voltage magnitude at bus b1 (V)
result["line"]["l1"]["1"]["cr_fr"]  # real part of current at from-terminal "1" (A)
result["generator"]["g1"]["1"]["pg"]  # active power on phase "1" (W)
```

Because the result is a plain dict, it serialises straight to JSON.
[`write_result`](@ref) writes it to a file or `IO`, and [`read_result`](@ref)
reads it back to an identical dict:

```julia
write_result(result, "result.json")
result2 = read_result("result.json")   # result2 == result
```

To turn the [`SolutionReport`](@ref) from [`profile_solution`](@ref) into a
Markdown file, pass a path to [`render_solution`](@ref):
`render_solution(report, "report.md")`.

## Infeasible solutions

When the solver terminates without finding a feasible point
(`termination_status` is neither `"LOCALLY_SOLVED"`, `"OPTIMAL"`, nor
`"ALMOST_LOCALLY_SOLVED"`), every numeric field in the result is set to `NaN`.
The `termination_status` and `solve_time` fields are always valid.

## Top-level fields

| Key | Type | Description |
|---|---|---|
| `termination_status` | String | JuMP termination status (e.g. `"LOCALLY_SOLVED"`, `"INFEASIBLE"`, `"TIME_LIMIT"`) |
| `objective` | Float64 | Objective value in cost units (matches the generator cost model) |
| `solve_time` | Float64 | Solver wall-clock time (s) |
| `bus` | Dict | Per-bus, per-terminal voltage results |
| `line` | Dict | Per-line, per-conductor current results |
| `switch` | Dict | Per-switch, per-conductor current results |
| `load` | Dict | Per-load, per-phase current and absorbed power |
| `generator` | Dict | Per-generator, per-phase current and produced power |
| `ibr` | Dict | Per-IBR, per-phase current and produced power |
| `transformer` | Dict | Per-transformer, per-winding-side currents |
| `voltage_source` | Dict | Per-source, per-phase slack current and imported power |
| `initialisation` | Dict | Per-bus, per-terminal Ipopt start values (see below) |
| `losses` | Dict | Network-total active/reactive losses; per-element losses live under each `line`/`transformer` (see below) |

## `bus` — voltages

```
result["bus"][bus_id][terminal] => Dict
```

All voltages are phase-to-ground (i.e. referenced to the global ground at
potential 0 V). The rectangular components `vr`/`vi` are the primary variables
solved by the OPF; `vm` and `va` are derived for convenience.

| Field | Unit | Description |
|---|---|---|
| `vr` | V | Real part of complex voltage |
| `vi` | V | Imaginary part of complex voltage |
| `vm` | V | Voltage magnitude: `√(vr² + vi²)` |
| `va` | rad | Voltage angle: `atan(vi, vr)` |

Grounded terminals (listed in `perfectly_grounded_terminals` or fixed by the
voltage source neutral) are present in the result with `vr = vi = vm = 0`,
`va = 0`.

The neutral terminal voltage is an explicit variable. In a balanced network it
is close to zero; in an unbalanced network it reflects the neutral shift.

## `line` — terminal currents

```
result["line"][line_id][terminal_name] => Dict
```

Conductors are keyed by **terminal name** taken from `terminal_map_from` of the
input line. A line with `terminal_map_from = ["1","2","n"]` produces result
keys `"1"`, `"2"`, `"n"`.

The reported quantities are the **total per-end currents**: the series current
plus that end's π-model shunt half-section, expressed as the current flowing out
of the bus into the branch. This is exactly the quantity the thermal magnitude
limit is enforced on (see [Lines](opf.md#Lines)).

| Field | Unit | Description |
|---|---|---|
| `cr_fr` | A | Real part of total current leaving the from-bus into the line |
| `ci_fr` | A | Imaginary part of total current leaving the from-bus |
| `cr_to` | A | Real part of total current leaving the to-bus into the line |
| `ci_to` | A | Imaginary part of total current leaving the to-bus |
| `cm_fr` | A | Current magnitude at from-end: `√(cr_fr² + ci_fr²)` |
| `cm_to` | A | Current magnitude at to-end: `√(cr_to² + ci_to²)` |

KCL sign convention: current is positive flowing **out of** the bus into the
branch. Internally the OPF solves a single series-current variable per conductor
with `c_to = −c_fr`; the shunt currents are linear functions of the bus voltages
and are added here to form the totals.

`cm_fr ≠ cm_to` when the linecode has a nonzero shunt admittance (π model),
because the two ends draw different shunt currents. For purely series lines (no
shunt) the totals reduce to the series current and `cm_fr = cm_to`.

Besides the per-conductor terminal keys, the line dict carries two reserved
keys: `"ground"` — the device's net current into earth (`cg_r`, `cg_i`, `cgm`
[A]), nonzero only with a phase-to-ground π-shunt — and `"loss"`, the element's
active/reactive losses (see [`losses`](@ref results-losses)).

## `switch` — switch currents

```
result["switch"][switch_id][terminal_name] => Dict
```

Conductors are keyed by terminal name from `terminal_map_from`. Open switches
have all currents fixed to zero; they appear in the result as `cr = ci = cm = 0`.

| Field | Unit | Description |
|---|---|---|
| `cr` | A | Real part of current (positive into bus at from-side) |
| `ci` | A | Imaginary part of current |
| `cm` | A | Current magnitude: `√(cr² + ci²)` |

Switches are ideal (lossless and voltage-coupling): `cr_from = -cr_to` exactly.
Only the from-side current is stored.

## `load` — absorbed power

```
result["load"][load_id][phase_terminal] => Dict
```

Loads are keyed by **phase terminal** name (the neutral terminal, if present,
carries no independent current variable and is absent from the result). For a
WYE load with `terminal_map = ["1","2","3","n"]` the result has keys `"1"`,
`"2"`, `"3"`.

The power fields confirm that the constant-power constraints were satisfied at
the solved operating point.

| Field | Unit | Description |
|---|---|---|
| `crd` | A | Real part of phase current drawn by the load |
| `cid` | A | Imaginary part of phase current drawn by the load |
| `pd`  | W | Active power absorbed: `Δvr·crd + Δvi·cid` |
| `qd`  | var | Reactive power absorbed: `Δvi·crd − Δvr·cid` |

`Δv = v_phase − v_neutral` for WYE/SINGLE_PHASE; `Δv = v_pos − v_neg` across
the DELTA element (terminal `k` to terminal `k mod n + 1`). For a feasible
solve `pd ≈ p_nom[k]` and `qd ≈ q_nom[k]`.

## `generator` — produced power

```
result["generator"][gen_id][phase_terminal] => Dict
```

Same terminal indexing as `load` — phase terminals only, neutral absent.

| Field | Unit | Description |
|---|---|---|
| `crg` | A | Real part of phase current injected by the generator |
| `cig` | A | Imaginary part of phase current injected by the generator |
| `pg`  | W | Active power produced: `Δvr·crg + Δvi·cig` |
| `qg`  | var | Reactive power produced: `Δvi·crg − Δvr·cig` |

When the optional `s_max` / `i_max` ratings are supplied the dispatch also
respects the apparent-power circle `pg² + qg² ≤ s_max²` and the
current-magnitude circle `crg² + cig² ≤ i_max²` (see [Generators](opf.md#generators-section)).

## `ibr` — produced power

```
result["ibr"][ibr_id][phase_terminal] => Dict
```

IBRs are keyed by **phase terminal** name, following the IBR's
`topology`:

- `FOUR_LEG` — keyed by each phase terminal in `terminal_map` (the neutral, the
  last terminal, carries the summed return current and is absent).
- `THREE_LEG` (delta) — keyed by the first terminal of each conductor pair
  `(k, k mod n + 1)`; there is no neutral.
- `SINGLE_PHASE` — a single key, the phase terminal `terminal_map[1]`
  (referenced against `terminal_map[2]`).

| Field | Unit | Description |
|---|---|---|
| `cri` | A | Real part of phase current injected by the IBR |
| `cii` | A | Imaginary part of phase current injected by the IBR |
| `pg`  | W | Active power produced: `Δvr·cri + Δvi·cii` |
| `qg`  | var | Reactive power produced: `Δvi·cri − Δvr·cii` |

`Δv` is the topology-appropriate voltage difference: phase-to-neutral for
`FOUR_LEG`, phase-to-reference for `SINGLE_PHASE`, and across the conductor pair
for `THREE_LEG`. Sign convention matches the generator: positive `pg`/`qg` is
power injected into the network. See [IBRs](opf.md#ibrs) for the
constraint model (box `q_min`/`q_max` bounds, constant-power-factor coupling, the
`s_max` apparent-power circle, and the optional `i_max` current-magnitude limit
`cri² + cii² ≤ i_max²`).

## `transformer` — winding currents

```
result["transformer"][xfmr_id]["fr"|"to"][k] => Dict
```

Transformer results use winding-side keys `"fr"` and `"to"`, each mapping to a
**positional index string** (`"1"`, `"2"`, ...) rather than a terminal name.
The two winding sides may have different terminal maps (e.g. a wye_delta
transformer has a neutral terminal on the wye side but not on the delta side),
so a shared terminal-name key is not well-defined.

To map position back to terminal: position `k` corresponds to
`terminal_map_from[k]` (from-side) or `terminal_map_to[k]` (to-side) in the
input network.

!!! note "Regulator subtypes index by winding, not terminal"
    For `single_phase` and `single_phase_autotransformer` the neutral is the
    return path, so positions index only the **phase** conductors. For
    `open_delta_regulator` the positions index the **two regulators** (`"1"`,
    `"2"`), not the four bus terminals — the shared-phase straight-through wire
    current is internal and not reported. In these cases position `k` does not
    align with `terminal_map[k]`.

| Field | Unit | Description |
|---|---|---|
| `cr` | A | Real part of winding current |
| `ci` | A | Imaginary part of winding current |
| `cm` | A | Current magnitude: `√(cr² + ci²)` |

For ideal transformers the apparent power `S = V·I*` is conserved across
windings (up to the ideal turns ratio). Series winding impedances
(`r_series_from`, `x_series_from`, etc.) cause a small difference.

Alongside the `"fr"`/`"to"` winding keys, the transformer dict carries a
`"ground"` entry (net current into earth: `cg_r`, `cg_i`, `cgm` [A]) and a
`"loss"` entry (see [`losses`](@ref results-losses)).

When the transformer's tap is a **free decision variable** (see
[continuous tap optimisation](opf.md)), the solved tap is also reported:

| Field | Unit | Description |
|---|---|---|
| `tap` | — | Optimised dimensionless tap multiplier (`single_phase`, `delta_wye`, `wye_delta`) |
| `tap_ratio` | — | Optimised regulation ratio — scalar (`single_phase_autotransformer`) or `[a₁, a₂]` (`open_delta_regulator`) |
| `tap_binding` | — | `true` when the optimised tap sits at a `tap_min`/`tap_max` bound (regulation range exhausted); per-regulator vector for `open_delta_regulator` |

These keys are present **only** when the tap was free (`tap_min < tap_max`); a
fixed-tap transformer reports neither.

## [`losses` — active/reactive losses](@id results-losses)

Losses are computed exactly from the **terminal-power identity**
`S_loss = 1ᵀ S_from + 1ᵀ S_to`, summed over every conductor the element drives
(phases and neutral, both winding sides), using the per-device ledger of
terminal-current injections built during model construction. Because the
injected currents sum to zero internally, the result is independent of the
ground voltage reference.

The top-level `losses` dict holds the network totals over all lines and
transformers:

| Field | Unit | Description |
|---|---|---|
| `p_loss` | W | Total active power dissipated (≥ 0 for a passive network) |
| `q_loss` | var | Net reactive absorption; **negative** when the network is net-capacitive (line charging, capacitor shunts) |

The same identity is attached **per element** under each line and transformer as
a `"loss"` sub-dict:

```
result["line"][line_id]["loss"]         => Dict
result["transformer"][xfmr_id]["loss"]  => Dict
```

| Field | Unit | Description |
|---|---|---|
| `p_loss` | W | Active power dissipated by this element (≥ 0; a negative value is non-physical and is flagged by `W.SOL.NEG_LOSS`) |
| `q_loss` | var | Net reactive absorption (negative = element is net-capacitive, e.g. line charging or transformer magnetising) |
| `s_through` | VA | Throughput scale `Σ|V_t||I_t|` over the element's terminals, used to size numerical tolerances (`p_loss` is a difference of large near-equal terminal powers, so its cancellation noise scales with this) |

Switches are ideal (lossless) and carry no `"loss"` entry. The per-element
sub-dicts are present only when the result was produced with the loss ledger
(i.e. by `solve_opf`); they may be absent in results from other solvers.

## `voltage_source` — slack current and grid injection

```
result["voltage_source"][source_id][phase_terminal] => Dict
```

The voltage source is the network's current slack: it fixes terminal voltages
**and** injects the slack current that closes KCL at the source bus (see
[Voltage source as current slack](opf.md#source-slack)). Results are keyed by
phase terminal (neutral excluded — it carries the summed return current).

| Field | Unit | Description |
|---|---|---|
| `cr` | A | Real part of slack current injected at the phase terminal |
| `ci` | A | Imaginary part of slack current |
| `cm` | A | Current magnitude: `√(cr² + ci²)` |
| `ps` | W | Active power imported into the network: `Δvr·cr + Δvi·ci` |
| `qs` | var | Reactive power imported: `Δvi·cr − Δvr·ci` |

Positive `ps`/`qs` is power flowing **into** the network from the source. To
obtain the total active power drawn from the grid, sum `ps` over all phases:

```julia
src    = result["voltage_source"]["source"]   # your source id
p_grid = sum(v["ps"] for v in values(src))
```

## `initialisation` — Ipopt start values

```
result["initialisation"][bus_id][terminal] => Dict
```

The start values set on the `vr`/`vi` JuMP variables before `optimize!` is
called. These are captured immediately after the warm-start setup and before the
solver overwrites them. The section is always present (even for infeasible
results), so it can be read without checking `termination_status` first.

| Field | Unit | Description |
|---|---|---|
| `vr_init` | V | Real part of the start voltage |
| `vi_init` | V | Imaginary part of the start voltage |
| `vm_init` | V | Start voltage magnitude: `√(vr_init² + vi_init²)` |
| `va_init` | rad | Start voltage angle: `atan(vi_init, vr_init)` |

Grounded terminals are recorded as all-zero regardless of the start-value
setting, because they are fixed in the JuMP model and the solver ignores their
start value.

**Convergence diagnostics.** `profile_solution` reads this section and emits
warnings when the start values differ substantially from the solved values:

- `W.SOL.INIT_LEVEL_MISMATCH` — a terminal where `vm_init / vm_solved` is
  outside [0.1, 10]. The most common cause is applying the source voltage
  magnitude to buses on a different voltage level (e.g. a 6.35 kV source
  voltage applied to a 230 V LV bus via flat initialisation). The solver may
  still converge but the path is longer and local-minimum risk is higher.
- `W.SOL.INIT_LARGE_ERROR` — a phase terminal where the init error exceeds
  20 % of the solved voltage magnitude. The start was a poor approximation.
- `I.SOL.INIT_NEUTRAL_NONZERO` — a neutral terminal with `vm_init > 0`.
  Neutral start values should be zero; a non-zero value indicates an
  initialisation inconsistency.

To compare start and solved voltages manually:

```julia
init  = result["initialisation"]
buses = result["bus"]
for (bid, t_dict) in init
    for (t, ivals) in t_dict
        vm_s = buses[bid][t]["vm"]
        vm_i = ivals["vm_init"]
        vm_s > 0 && println("$bid.$t  ratio=$(round(vm_i/vm_s, digits=2))")
    end
end
```

## Coordinate spaces and sign conventions

| Quantity | Space | Sign |
|---|---|---|
| Bus voltage | Rectangular (`vr`/`vi`), phase-to-ground | — |
| Line current | Rectangular, referenced to from-bus direction | Positive leaving the bus into the line |
| Load current | Rectangular, phase current only | Positive flowing from bus into load |
| Generator current | Rectangular, phase current only | Positive flowing from generator into bus |
| Power (all) | `P = Re(V · I*)`, `Q = Im(V · I*)` | Positive = absorbed (load) / produced (generator) |

All phase-to-neutral voltage differences use the **solved** neutral voltage
(explicit JuMP variable), not a forced-zero assumption. This is the correct
reference for 4-wire networks where the neutral is not perfectly grounded.

## Per-unit scaling

When `solve_opf` is called with `per_unit=true` the result is automatically
converted back to SI before being returned. The caller always receives SI units
regardless of the internal solver representation.
