# DC networks

BMOPFTools models an **MVDC/LVDC network** — DC buses, cables, groundings, loads, and
sources — that AC/DC converters share. This is how converter stations, back-to-back
soft open points (SOPs), and MVDC ties are formed. DC quantities have **no angle**:
each DC terminal holds a single real, *signed* voltage to earth (positive pole $>0$,
negative pole $<0$, metallic return $\approx 0$). This page groups the DC objects and
the converter coupling; each follows the [foundational → implementation
split](index.md#How-each-component-page-is-organised). Symbols are defined in
[Notation](notation.md).

The DC subsystem is a BMOPFTools extension with no counterpart in the Task Force PDF
(see the [reconciliation note](#Reconciliation-note)).

## DC buses

### Data model (`dc_bus`)

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `terminal_names` | string[] | – | ✔ | Ordered DC terminals: length 1 (pole, earth return), 2 (pole + return), or 3 (bipole: +pole, −pole, metallic return) |
| `perfectly_grounded_terminals` | string[] | – | | Terminals held at earth ($v_{\text{dc}}=0$) |
| `pole` | map | – | | Terminal → role (`POSITIVE`, `NEGATIVE`, `METALLIC_RETURN`) |
| `v_dc_nom` | number[] | V | | Per-terminal signed nominal voltage |
| `v_dc_min`, `v_dc_max` | number[] | V | | Per-terminal signed line-to-ground bounds |
| `vdc_ln_min`, `vdc_ln_max` | number | V | | Line-to-neutral (pole − return) magnitude bounds |
| `vdc_ll_min`, `vdc_ll_max` | number | V | | Line-to-line (+pole − −pole) magnitude bounds (bipole) |

### Variables

Each DC terminal $p$ holds a real signed voltage $v^{\text{dc}}_{b,p}\in\mathbb{R}$
(perfectly grounded terminals fixed to $0$). A free earth current $i^{\text{gnd}}_{b,p}$
is added at each perfect ground.

### Constraints

**DC KCL** at every terminal (currents sum to zero; grounded terminals keep the
equation, balanced by the earth current) — the DC analogue of the
[AC bus](bus.md#Kirchhoff's-current-law):

```math
\sum \text{(branch, converter, load, source, ground currents)} = 0.
```

**Signed line-to-ground bounds** are variable bounds on $v^{\text{dc}}_{b,p}$.
**Line-to-neutral / line-to-line magnitude bounds** stay *linear* because the pole
roles fix the sign of each difference: for an oriented difference $\Delta\ge 0$,
$\textcolor{red}{v^{\min}}\le\Delta\le\textcolor{red}{v^{\max}}$ (a `POSITIVE`/`NEGATIVE`
role is required, else a hard error — never a non-convex squared form).

## DC branches

### Data model (`dc_branch`)

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `dc_bus_from`, `dc_bus_to` | string | – | ✔ | Endpoint DC buses |
| `terminal_map_from`, `terminal_map_to` | string[] | – | ✔ | Per-wire terminal maps (1/2/3 wires) |
| `r` | number[] | Ω | ✔ | Per-conductor resistance (no mutual coupling) |
| `i_max` | number[] | A | | Per-conductor current limit |
| `p_max` | number | W | | Branch active-power limit |

### Variables and constraints

Per conductor $k$, a real current $i^{\text{dc}}_{\ell,k}$ from `from` to `to`. **Ohm's
law** (or an ideal conductor when $\textcolor{red}{r_k}=0$):

```math
i^{\text{dc}}_{\ell,k} = \frac{v^{\text{dc}}_{b^{\text{fr}},k} - v^{\text{dc}}_{b^{\text{to}},k}}{\textcolor{red}{r_k}}.
```

It enters DC KCL with opposite sign at each end. **Thermal** and **power** limits:
$(i^{\text{dc}}_{\ell,k})^2 \le (\textcolor{red}{i^{\max}_{\ell,k}})^2$ and, on the
pole conductor, $(v^{\text{dc}}\,i^{\text{dc}})^2 \le (\textcolor{red}{p^{\max}_\ell})^2$.

## DC groundings, loads, and sources

### `dc_grounding`

Sets the signed-voltage reference of a DC island. `r = 0` (or omitted) is **perfect**
grounding ($v^{\text{dc}}=0$ with a free earth current); `r > 0` is grounding through
an impedance, drawing $i^{\text{earth}} = v^{\text{dc}}/\textcolor{red}{r}$ from the
node. At least one grounding per connected DC island is required.

### `dc_load` and `dc_source`

A DC load draws constant power across a terminal pair; a DC source injects a dispatched
power. With port voltage $\Delta v^{\text{dc}}$ (pole − return, or pole − earth) and
port current $I$:

```math
\Delta v^{\text{dc}}\, I = \textcolor{red}{p} \quad(\text{load, drawn}),
\qquad
\Delta v^{\text{dc}}\, I = P \quad(\text{source, injected}),
```

with the source power $P$ either a fixed setpoint (`p`) or dispatchable within
$[\textcolor{red}{p^{\min}},\textcolor{red}{p^{\max}}]$. The port current enters DC KCL
at the two terminals.

## AC/DC converters

An IBR that references a `dc_bus` (via `dc_bus` + `dc_terminal_map`) becomes an **AC/DC
converter**: its AC side is the [IBR](ibr.md) model; its DC port injects into the
shared DC node. Converters are **lossless** here — the DC-port power equals the AC
active power.

### Coupling equality

With DC-port voltage $\Delta v^{\text{dc}}_r$ (pole − return) and port current $I_r$:

```math
\Delta v^{\text{dc}}_r\, I_r = \sum_k P_{r,k},
```

and $I_r$ enters DC KCL at the port terminals. A converter station / back-to-back SOP /
MVDC tie emerges automatically when several converters share one `dc_bus` and balance
through DC KCL.

### DC-side control mode (`dc_control`)

- **`P`** (default): the OPF dispatches the converter power (no extra constraint).
- **`V`** (DC-voltage master): pins $\Delta v^{\text{dc}}_r = \textcolor{red}{v^{\text{set}}_r}$;
  the AC power floats to balance the zone.
- **`droop`** (saturated V–P): $\sum_k P_{r,k} = f(\Delta v^{\text{dc}}_r)$, a
  piecewise-linear characteristic rising with DC voltage, flat within an optional
  dead-band around $\textcolor{red}{v^{\text{set}}_r}$, and clamped at the converter
  power limits.

Each connected DC island needs at least one `V` or `droop` converter, else the DC
voltage is underdetermined.

## Implementation in BMOPFTools

### Realisation

- **DC variables** — signed node voltages `v_dc` (grounded fixed to 0), branch
  currents `idc_br`, converter port currents `idc_conv`, load/source currents and
  source power ([`dcnetwork.jl:_add_dc_variables!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/dcnetwork.jl)).
- **DC KCL** — a per-terminal accumulator mirroring the AC pattern, enforced $=0$
  (`_init_dc_kcl`, `_add_dc_kcl_constraints!`).
- **Branches, groundings, loads, sources** — stamped in
  `_add_dc_network_constraints!`; degenerate voltage bands (e.g. a return pinned to 0)
  are fixed rather than bounded, and ideal-conductor equalities to a fixed node are
  skipped.
- **Converter coupling** — the lossless bilinear balance and the P/V/droop control law
  are added by `_couple_converter_to_dc!` (called from the IBR builder, which supplies
  each converter's AC active power). The droop reuses the same smoothed piecewise-linear
  operator as the AC Volt-Watt curves.
- **Warm start** — DC node voltages are seeded at `v_dc_nom` (or the mid-band) so the
  bilinear converter balance starts away from the degenerate $v=0$ point
  (`_set_dc_start_values!`).

### Source map

| Constraint | Code location |
|------------|---------------|
| DC variables, warm start | `dcnetwork.jl:_add_dc_variables!`, `_set_dc_start_values!` |
| DC KCL | `dcnetwork.jl:_init_dc_kcl`, `_add_dc_kcl_constraints!` |
| Branches, groundings, loads, sources, bounds | `dcnetwork.jl:_add_dc_network_constraints!` |
| Converter coupling + control | `dcnetwork.jl:_couple_converter_to_dc!` |

### Reconciliation note

!!! warning "The DC subsystem is not in the Task Force PDF"
    `dc_bus`, `dc_branch`, `dc_grounding`, `dc_load`, `dc_source`, and the AC/DC
    converter coupling (via IBR `dc_bus`) are BMOPFTools extensions with no counterpart
    in the current PDF. They should be added as a first-class DC subsystem in the
    superseding spec.
