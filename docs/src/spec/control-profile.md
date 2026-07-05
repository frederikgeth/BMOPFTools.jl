# Control profiles

A **control profile** is a reusable smart-inverter control law, referenced by
[IBRs](ibr.md) the way lines reference a linecode. Several IBRs can share one profile.
This page documents the `control_profile` **object** (its data model); the *constraints*
each law induces are on the [IBR page](ibr.md#Reactive-power-control-law). This is a
*data-model* page — a profile carries no variables itself. Symbols are defined in
[Notation](notation.md).

A `control_profile` is a named entry of the top-level `control_profile` object. Each of
its sub-objects is optional; the presence of a sub-object activates that law. An IBR
references a profile by id via its `control_profile` field. A profile normally carries
**one** law; when both `power_factor` and a droop are present, `power_factor` wins (with
a warning).

## `power_factor`

Constant power-factor operation.

| Field | Type | Range | Description |
|-------|------|:-----:|-------------|
| `pf` | number | $[-1, 1]$ | Power factor; **positive = lagging** (absorbing VAr), **negative = leading** (injecting VAr) |

Induces the bilinear equality
$\operatorname{sign}(\textcolor{red}{\mathrm{pf}})\,Q + \tan(\arccos|\textcolor{red}{\mathrm{pf}}|)\,P = 0$
per phase.

## `volt_var`

Reactive power as a piecewise-linear function of a monitored voltage magnitude.

| Field | Type | Description |
|-------|------|-------------|
| `voltage_reference` | enum | Monitored voltage quantity + aggregation (see [below](#Voltage-reference)) |
| `breakpoints` | number[] | Four non-decreasing voltage breakpoints $[U_1,U_2,U_3,U_4]$ (V) |
| `q_limits` | number[] | $[q_{\text{absorb}}\le 0,\ q_{\text{inject}}\ge 0]$, in `q_unit` |
| `q_unit` | enum | `VA_FRACTION` (fraction of `s_max`) or `VAR` (absolute) |
| `q_ref` | enum | `VAR_MAX` (fixed limits) or `VAR_AVAILABLE` (scale with remaining apparent power) |
| `p_min_for_q` | number | Active power below which reactive output is zero (OpenDSS `%PminNoVars`) |
| `p_min_for_q_max` | number | Active power below which reactive capability is derated (OpenDSS `%PminkvarMax`) |

The curve injects VAr at low voltage, absorbs at high voltage, and is flat (zero)
between $U_2$ and $U_3$.

## `volt_watt`

Active-power limit as a piecewise-linear function of a monitored voltage magnitude.

| Field | Type | Description |
|-------|------|-------------|
| `voltage_reference` | enum | Monitored voltage quantity + aggregation |
| `breakpoints` | number[] | Two non-decreasing breakpoints $[U_5,U_6]$ (V) |
| `p_limits` | number[] | $[p_{\text{low}},\ p_{\text{high}}]$, in `p_unit` |
| `p_unit` | enum | `VA_FRACTION` (fraction of `s_max`) or `W` (absolute) |
| `p_ref` | enum | Normalisation base: `P_AVAILABLE`, `P_MAX`, or `S_MAX` |

The curve caps active power as voltage rises (curtailment), stacking on top of the IBR's
`p_max` availability bound (the tighter binds).

## Enumerations

### Voltage reference

`voltage_reference` combines a **monitored quantity** with a cross-phase **aggregation**:

| Value | Quantity | Aggregation |
|-------|----------|-------------|
| `PN_PER_PHASE` | phase-to-neutral | each phase sees its own magnitude |
| `PG_PER_PHASE` | phase-to-ground | per phase |
| `PP_PER_PHASE` | phase-to-phase | per phase |
| `PN_AVERAGED` | phase-to-neutral | every phase sees the mean magnitude |
| `PG_AVERAGED` | phase-to-ground | averaged |
| `PP_AVERAGED` | phase-to-phase | averaged |

The IBR-level `voltage_aggregation` field, when present, overrides the aggregation
implied here.

### Applicability

Volt-VAr / Volt-Watt droop applies to `SINGLE_PHASE` and `FOUR_LEG` IBRs; a `THREE_LEG`
(delta) IBR has too few degrees of freedom for a per-phase droop and falls back to box
bounds with a warning. See [IBRs](ibr.md) for the full constraint treatment and the
smoothed piecewise-linear encoding.

!!! warning "Reconciliation note — control profiles are not in the Task Force PDF"
    The `control_profile` object and its smart-inverter laws are a BMOPFTools extension
    with no counterpart in the current PDF. They pair with the [IBR](ibr.md) object and
    should enter the superseding spec together.
