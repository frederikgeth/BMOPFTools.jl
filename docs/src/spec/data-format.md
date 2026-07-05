# Data input formatting

This page defines how physical quantities are represented in the JSON data model:
units, the encoding of complex numbers and matrices, worked unit-conversion examples,
and the meaning of required vs optional fields. It underpins every component page.
Symbols are defined in [Notation](notation.md).

## Units

All physical quantities are in **SI**, with two deliberate exceptions noted below. The
data model carries no unit fields — units are fixed by the field, per this table.

| Quantity | Unit | Symbol |
|----------|------|:------:|
| Voltage | volt | V |
| Current | ampere | A |
| Length | metre | m |
| Active power | watt | W |
| Reactive power | volt-ampere reactive | var |
| Apparent power | volt-ampere | VA |
| Conductance, susceptance | siemens | S |
| Resistance, reactance | ohm | Ω |
| Angle | radian | rad |
| Cost rate | US dollar per kilowatt-hour | \$/kWh |

**Non-SI exceptions.** Two quantities use a customary unit for industry familiarity:
**cost rate** in \$/kWh (there is no SI unit of currency; 1 kWh $= 3.6\times10^6$ J),
and **temperature** in °C (used by `wire_data`/`line_geometry`).

Per-unit normalisation is a solver-internal convenience and is **out of scope** here —
no per-unit quantity appears in the data model.

## Complex numbers, vectors, and matrices

JSON has only ordered lists of real numbers, so:

- A **complex** quantity is stored as a **pair of real fields** (rectangular or polar).
  For example a voltage source is given by `v_magnitude` and `v_angle`; an impedance by
  `R_series_*` and `X_series_*`. The model uses real variables throughout for the same
  reason (see [Notation](notation.md)).
- A **matrix** is stored **row-first** with an underscore-delimited, **1-indexed** key:
  entry $A_{kj}$ is the field `A_k_j`. So `R_series_1_2` is the $(1,2)$ entry of the
  series-resistance matrix, and `G_from_2_2` the $(2,2)$ from-side shunt conductance.
- A **vector** (e.g. `v_min`, `i_max`) is a JSON array, ordered to match the element's
  terminal map or phase order as stated on each component page.

## Conversion examples

Convert conventional power-systems quantities to SI before writing them. To allow exact
cross-checks against tools that use other units (e.g. degrees), give constants to **at
least 10 significant figures**, ideally full floating-point precision.

| Quantity | Conventional | SI | Example → JSON |
|----------|--------------|----|----------------|
| Active power | kilowatts (kW) | watts (W) | 3 kW → `3000.0` (or `3.0e3`) |
| Angle | degrees | radians | 120° → `2.0943951023931953` |
| Reactance | per-unit (on a $Z$-base) | ohms (Ω) | 5 % on a 100 Ω base → `5.0` (Ω) on the winding field |

## Required and optional fields

Each component has required fields (listed with ✔ on its page) and optional ones. The
interpretation of an **absent optional** field depends on its kind:

- **Absent constraint field** ⇒ that constraint is **unbounded**. A missing voltage
  upper bound means no upper bound is enforced; a missing `i_max` means no thermal limit.
- **Absent parameter field** ⇒ a **null / zero** value. A missing transformer
  `r_series_from` means that winding resistance is $0\ \Omega$.

This is why bounds are optional throughout the model: different problem formulations
(cost OPF, maximum load delivery, CVR, state estimation) activate different subsets of
the feasible region, so the data model lets each bound be present or absent
independently.
