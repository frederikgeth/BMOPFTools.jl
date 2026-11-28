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
**one** law; when both `power_factor` and a droop are present, `power_factor` wins and
both droop curves are dropped (with a warning). `volt_var` and `volt_watt` may be
combined.

The schema accepts every enumerated value below, but the OPF builder applies a droop
law only in the supported forms marked in the tables; any other form is skipped with a
warning and the IBR keeps its P/Q box bounds.

## `power_factor`

Constant power-factor operation.

| Field | Type | Range | Description |
|-------|------|:-----:|-------------|
| `pf` | number | $0 < \lvert\mathrm{pf}\rvert \le 1$ | Power factor; **positive = lagging** (absorbing VAr), **negative = leading** (injecting VAr) |

Induces the bilinear equality
$\operatorname{sign}(\textcolor{red}{\mathrm{pf}})\,Q + \tan(\arccos|\textcolor{red}{\mathrm{pf}}|)\,P = 0$
per coil (stamped in the equivalent bounded form
$\mathrm{pf}\,Q + \sqrt{1-\mathrm{pf}^2}\,P = 0$). Values must be finite real numbers
(not Booleans); zero is rejected (`E.INT.CONSTANT_PF_INVALID`),
not interpreted as disabling the law. For positive generation, positive PF
means Q absorption and negative PF means Q injection. At P=0 the equality
forces Q=0, although the numerical PF ratio itself is undefined at zero S.
The same signed equality is retained for existing consumption cases; minimum-PF
support below is restricted to generation.

Minimum PF is a separate operating envelope, not another constant-PF value.
See [Minimum power factor for generation](@ref) for the versioned package policy
in `extras`; it does not add a Task Force-owned profile field.

## `volt_var`

Reactive power as a piecewise-linear function of a monitored voltage magnitude.

| Field | Type | Description |
|-------|------|-------------|
| `voltage_reference` | enum | Monitored voltage quantity + aggregation (see [below](#Voltage-reference)) |
| `breakpoints` | number[] | Exactly four strictly increasing voltage breakpoints $[U_1,U_2,U_3,U_4]$ (V) |
| `q_limits` | number[] | Exactly two: $[q_{\text{absorb}}\le 0,\ q_{\text{inject}}\ge 0]$, in `q_unit` |
| `q_unit` | enum | `VA_FRACTION` (fraction of `s_max`; default, the only supported value) or `VAR` (absolute) |
| `q_ref` | enum | `VAR_MAX` (fixed limits; default, the only supported value) or `VAR_AVAILABLE` (scale with remaining apparent power) |
| `p_min_for_q` | number | Active power below which reactive output is zero (OpenDSS `%PminNoVars`); accepted but not used by the OPF |
| `p_min_for_q_max` | number | Active power below which reactive capability is derated (OpenDSS `%PminkvarMax`); accepted but not used by the OPF |

The curve passes through $q_{\text{inject}}$ at $U_1$, zero at $U_2$ and $U_3$, and
$q_{\text{absorb}}$ at $U_4$, clamped flat outside $[U_1,U_4]$: it injects VAr at low
voltage, absorbs at high voltage, and is zero between $U_2$ and $U_3$. The result is
multiplied by the coil's `s_max`. Breakpoints that are not strictly increasing are
rejected with an error.

## `volt_watt`

Active-power limit as a piecewise-linear function of a monitored voltage magnitude.

| Field | Type | Description |
|-------|------|-------------|
| `voltage_reference` | enum | Monitored voltage quantity + aggregation |
| `breakpoints` | number[] | Exactly two strictly increasing breakpoints $[U_5,U_6]$ (V) |
| `p_limits` | number[] | Exactly two: $[p_{\text{low}},\ p_{\text{high}}]$, in `p_unit` |
| `p_unit` | enum | `VA_FRACTION` (fraction of the `p_ref` base; default, the only supported value) or `W` (absolute) |
| `p_ref` | enum | Normalization base: `S_MAX` (coil `s_max`, default), `P_MAX` (coil `p_max`), or `P_AVAILABLE` (`p_avail` divided equally over the coils) |

The cap is $p_{\text{high}}$ at $U_5$ falling to $p_{\text{low}}$ at $U_6$, clamped flat
outside, times the `p_ref` base. It curtails active power as voltage rises, stacking on
top of the IBR's `p_max` availability bound (the tighter binds).

## Enumerations

### Voltage reference

`voltage_reference` combines a **monitored quantity** with a cross-phase **aggregation**:

| Value | Quantity | Aggregation |
|-------|----------|-------------|
| `PN_PER_PHASE` (default) | phase-to-neutral | each phase sees its own magnitude |
| `PG_PER_PHASE` | phase-to-ground | per phase |
| `PP_PER_PHASE` | phase-to-phase | per phase |
| `PN_AVERAGED` | phase-to-neutral | every phase sees the mean magnitude |
| `PG_AVERAGED` | phase-to-ground | averaged |
| `PP_AVERAGED` | phase-to-phase | averaged |

Phase-to-phase uses the next phase cyclically. A `PN` reference on an IBR without a
neutral terminal, or a `PP` reference with fewer than two phases, falls back to
phase-to-ground with a warning; an unknown value is read as `PN_PER_PHASE`. For a
`SINGLE_PHASE` IBR, `PN` and `PP` both monitor the voltage across its two terminals and
aggregation has no effect.

The legacy IBR-level `voltage_aggregation` field (`PER_PHASE` or `AVERAGE`; renamed
from `voltage_ref` by `migrate`), when present, overrides the aggregation implied here.

### Applicability

Volt-VAr / Volt-Watt droop applies to `SINGLE_PHASE` and `FOUR_LEG` IBRs; a `THREE_LEG`
(delta) IBR has too few degrees of freedom for a per-phase droop and falls back to box
bounds with a warning. See [IBRs](ibr.md) for the full constraint treatment and the
smoothed piecewise-linear encoding.

!!! warning "Reconciliation note — control profiles are not in the Task Force PDF"
    The `control_profile` object and its smart-inverter laws are a BMOPFTools extension
    with no counterpart in the Task Force PDF. They pair with the [IBR](ibr.md) object and
    should enter the superseding spec together.
