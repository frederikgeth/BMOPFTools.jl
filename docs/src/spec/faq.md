# Modelling notes and FAQ

Practical questions that recur when building cases, with answers sourced from the
current implementation (some differ from older guidance where BMOPFTools has since added
support). Symbols are defined in [Notation](notation.md).

## How do I model a constant-impedance or constant-current load?

Use the [load](load.md) `model` field: `constant_impedance` ($P\propto|V|^2$),
`constant_current` ($P\propto|V|$), or a full `zip` mix, with `v_nom` giving the
reference voltage. (Older guidance suggested emulating a constant-impedance load with a
[shunt](shunt.md); that is no longer necessary now that voltage-dependent load models
are supported.)

## How do I define a triplex (split-phase service) load?

As one or more **single-phase** loads across the triplex terminals. For a 1 kW load
across legs `1`–`2` of a triplex bus with `terminal_names` `["1","n","2"]`, define a
`SINGLE_PHASE` load with `terminal_map` `["1","2"]` and `p_nom` `[1000.0]`. A
two-terminal `SINGLE_PHASE` map is modelled across exactly those two terminals (here
line-to-line, 240 V), not phase-to-ground — see [Loads](load.md).

## I converted a wye load to delta with the standard transform and got a different answer. Why?

Because a distribution **wye load is four-wire** — three phase branches to a *neutral
return* conductor — whereas the textbook delta–wye (Y–Δ) transform assumes a *three-wire*
wye with no return (a graph-theoretic star). The transform is **not applicable** to a
wye-with-neutral load. Model the wye and delta connections directly via the load
`configuration` field; do not pre-transform.

## How do I model a three-wire wye load (no neutral return)?

Add a **floating midpoint** terminal at the bus and connect three single-phase loads (or
a wye-with-return whose neutral ties to that floating node) across the phases to it. The
floating node carries no external connection, so it enforces the zero-return-current
condition of a true three-wire star. There is no dedicated "wye-without-neutral" load
subtype.

## How do I get center-tap transformer impedances from OpenDSS or Gridlab-D?

**OpenDSS** specifies the three inter-winding short-circuit reactances
$\texttt{Xhl},\texttt{Xlt},\texttt{Xht}$ (% p.u.). These map to the per-winding
reactances by the star (T) transform
$[\texttt{Xh};\texttt{Xl};\texttt{Xt}] = \tfrac12\,\mathbf{S}\,[\texttt{Xhl};\texttt{Xlt};\texttt{Xht}]$
with $\mathbf{S}=\left[\begin{smallmatrix}1&-1&1\\1&1&-1\\-1&1&1\end{smallmatrix}\right]$,
then to ohms via the winding voltage/power base. The [transformer](transformer.md#6.-Implementation-in-BMOPFTools)
page gives the full partitioning (and warns against the common $\texttt{Xhl}/2$ shortcut,
which is wrong for center-tap under unbalance).

**Gridlab-D** gives per-unit primary `impedance` and secondary `impedance1` with a
`power_rating` for the *whole* transformer. The per-winding SI impedances are

```math
\textcolor{brown}{Z_i} = \texttt{impedance}\cdot\frac{3}{1000}\cdot\frac{\texttt{primary\_voltage}^2}{\texttt{power\_rating}},
\qquad
\textcolor{brown}{Z_j} = \texttt{impedance1}\cdot\frac{3}{1000}\cdot\frac{\texttt{secondary\_voltage}^2}{\texttt{power\_rating}},
```

where the factor 3 accounts for the total rating being three times the primary-winding
power, and 1000 converts the kVA rating to VA.

!!! note "These conversions are performed automatically"
    BMOPFTools' importers (`from_dss`, and the Gridlab-D path) apply these conversions
    when reading source models, and are validated against the source tool's transformer
    admittance. The formulas are given here for authors constructing data by hand or
    auditing an import.
