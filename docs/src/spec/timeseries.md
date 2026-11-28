# Time series

A **time series** is a named profile of multiplicative scale factors that makes a
static parameter time-varying. Components reference profiles to model a load shape, a
PV generation curve, and so on; a *snapshot* at a time index multiplies the static
parameter by the profile value. This is a *data-model* page — time series carry no OPF
variables or constraints; they transform the input data that the component models then
consume. Symbols are defined in [Notation](notation.md).

## Data model

### `time_series`

A `time_series` entry is a named profile.

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `values` | number[] | – | ✔ | Multiplicative scale factors, one per step |
| `time` | number[] | – | | Optional time stamps for the steps (informational; not read by `get_snapshot`) |

### Referencing a profile

Any component that supports time variation carries a `time_series` map from a
**parameter name** to a **profile id**:

```json
"load": {
  "d1": {
    "p_nom": [4000.0], "q_nom": [1000.0], "bus": "b1",
    "configuration": "WYE", "terminal_map": ["a", "n"],
    "time_series": { "p_nom": "residential_shape" }
  }
}
```

Here the load's `p_nom` is scaled by the `residential_shape` profile; unreferenced
parameters stay static. The referenced parameter must carry a static number or
vector on the component; a reference to a missing parameter, or to an unknown profile
id, is an error. References are resolved on every component collection and on every
transformer subtype except `control_profile`, whose scalable values are nested inside
the control-law sub-objects; a `time_series` map on a control profile is left
unresolved.

## Snapshot semantics

A snapshot at integer time index $\textcolor{red}{\tau}$ (1-based) replaces each referenced
parameter $\textcolor{red}{x}$ by

```math
\textcolor{red}{x}[\textcolor{red}{\tau}] = \textcolor{red}{x}\cdot \textcolor{red}{v_{\textcolor{red}{\tau}}},
```

where $\textcolor{red}{v_{\textcolor{red}{\tau}}}$ is the profile's `values[τ]`. The
snapshot is an ordinary static network at that instant — the OPF is then built and
solved exactly as documented on the component pages. A time series is therefore a
*pre-processing* transform, never a decision variable, and does not couple time steps
(each snapshot is an independent solve).

## Implementation in BMOPFTools

- `get_snapshot(net, t_index)` returns a deep copy in which every component's
  `time_series` map has been applied (the named static parameter multiplied by
  `values[t_index]`) and removed, along with the root-level `time_series` object. An
  out-of-range `t_index` raises a `BoundsError`. A network without time series is
  returned as an unchanged copy.
- `solve_opf`, `solve_feasibility_opf`, `solve_pf`, and `build_opf_model` accept a
  `t_index` keyword (default `1`) and snapshot the network at that step before
  building the model, so a time-series case solved without `t_index` uses its first
  step.
- Because a snapshot is a static network, all component models, the
  [objective](objective.md), and the [feasibility relaxation](objective.md#Feasibility-relaxation)
  apply unchanged.

!!! note "Control profiles vs time series"
    A `time_series` scales a static *parameter* over time. A `control_profile` (see
    [IBRs](ibr.md#Reactive-power-control-law)) instead encodes a *control law* (constant
    power factor, Volt-VAr, Volt-Watt) that reacts to the solved voltage within a single
    snapshot. The two are independent mechanisms and can be combined.

!!! tip "Worked example and modeling FAQ"
    The [time-series tutorial](../tutorial_timeseries.md) walks a 24-hour sweep on
    a real LV feeder and answers the common modeling questions — changing the
    irradiance/PV shape, EV-charging and other load patterns, constant vs varying
    power factor, and why storage/multi-period studies need a different mechanism.
