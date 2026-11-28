# DC networks

BMOPFTools models an **MVDC/LVDC network** — DC buses, cables, groundings, loads, and
sources — that AC/DC converters share. This is how converter stations, back-to-back
soft open points (SOPs), and MVDC ties are formed. DC quantities have **no angle**:
each DC terminal holds a single real, *signed* voltage to earth (positive pole $>0$,
negative pole $<0$, metallic return $\approx 0$). This page groups the DC objects and
the converter coupling; each follows the foundational → implementation split of
the [BMOPF specification](https://distribution-system-opt.github.io/math-and-data-model-specifications/).
Symbols are defined in
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
first conductor (taken as the pole) with its from-end voltage,
$(v^{\text{dc}}_{b^{\text{fr}},1}\,i^{\text{dc}}_{\ell,1})^2 \le (\textcolor{red}{p^{\max}_\ell})^2$.
A loop of zero-resistance conductors (including one closed through two perfect
grounds) leaves a circulating current undetermined and is rejected
(`E.INT.DC_IDEAL_LOOP`).

## DC groundings, loads, and sources

### `dc_grounding`

Sets the signed-voltage reference of a DC island: fields `dc_bus`, `terminal`
(required) and `r` [Ω]. `r = 0` (or omitted) is **perfect**
grounding ($v^{\text{dc}}=0$ with a free earth current); `r > 0` is grounding through
a resistance, drawing $i^{\text{earth}} = v^{\text{dc}}/\textcolor{red}{r}$ from the
node. Each connected DC island needs at least one grounding
(`E.INT.NO_DC_VOLTAGE_REFERENCE`); more than one warns
(`W.DOM.DC_MULTIPOINT_GROUNDING`).

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
- **`V`** (DC-voltage master): pins $\Delta v^{\text{dc}}_r = \textcolor{red}{v^{\text{set}}_r}$
  (`dc_v_set`, defaulting to the pole-to-return `v_dc_nom` of the `dc_bus`);
  the AC power floats to balance the zone.
- **`droop`** (saturated V–P): $\sum_k P_{r,k} = f(|\Delta v^{\text{dc}}_r|)$, a
  piecewise-linear characteristic through `dc_p_ref` at $|v^{\text{set}}_r|$ with
  slope $1/$`dc_droop` (W/V, so `dc_droop` $>0$ is required), rising with DC-voltage
  magnitude, flat within an optional ±`dc_deadband` around $|v^{\text{set}}_r|$, and
  clamped at $\sum_k$`p_min`/$\sum_k$`p_max` (or $\mp\sum_k$`s_max` when those are
  absent).

Each connected DC island needs at least one `V` or `droop` converter, else the DC
voltage is underdetermined (`E.INT.DC_NO_VOLTAGE_CONTROL`). Two exact voltage
statements that disagree (for example two masters on one port with different
setpoints) are a data error (`E.INT.DC_REFERENCE_CONFLICT`); statements that agree
are stamped once.

## Implementation in BMOPFTools

### [Realization](@id Realisation)

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
    in the Task Force PDF. They should be added as a first-class DC subsystem in the
    superseding spec.
