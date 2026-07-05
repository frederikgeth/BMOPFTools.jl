# Inverter-based resources

An **inverter-based resource (IBR)** is a source interfaced to the AC network through a
power-electronic converter: PV, battery storage, a STATCOM, or a generic converter. It
injects controllable active and reactive power subject to a converter apparent-power
rating, and can follow a smart-inverter control law (constant power factor, Volt-VAr,
Volt-Watt). Parts 1–5 state the foundational model;
[part 6](#6.-Implementation-in-BMOPFTools) records how BMOPFTools realises it. A
converter that also connects to a DC network is covered in [DC networks](dc.md).
Symbols are defined in [Notation](notation.md).

## 1. Data model

An IBR is an entry of the top-level `ibr` object, keyed by its string ID $r$.

| Field | Type | Unit | Req. | Description |
|-------|------|:----:|:----:|-------------|
| `bus` | string | – | ✔ | Host bus ID $i$ |
| `terminal_map` | string[] | – | ✔ | Conductor→terminal map |
| `topology` | string | – | ✔ | `FOUR_LEG`, `THREE_LEG`, or `SINGLE_PHASE` |
| `prime_mover` | string | – | ✔ | PV / battery / STATCOM / … |
| `s_max` | number[] | VA | ✔ | Per-phase apparent-power rating |
| `p_min`, `p_max` | number[] | W | | Per-phase active-power bounds |
| `q_min`, `q_max` | number[] | var | | Per-phase reactive-power bounds |
| `i_max` | number[] | A | | Per-conductor current-magnitude limit (optional neutral entry) |
| `p_avail` | number | W | | Available active power (PV curtailment ceiling) |
| `control_profile` | string | – | | Reference to a [control profile](control-profile.md) |
| `dc_link_coupled` | bool | – | | Couple the phases through a shared DC link |
| `p_dc_min`, `p_dc_max` | number | W | | Net DC-side active-power bounds (when `dc_link_coupled`) |
| `dc_bus`, `dc_terminal_map`, `dc_control`, … | – | – | | Shared DC-node coupling — see [DC networks](dc.md) |

## 2. Input symbols

| Field | Symbol | Notes |
|-------|:------:|-------|
| `s_max` | $\textcolor{red}{\mathbf{S}^{\max}_r}$ | per phase |
| `p_min`, `p_max` | $\textcolor{red}{P^{\min}_r},\ \textcolor{red}{P^{\max}_r}$ | per phase |
| `q_min`, `q_max` | $\textcolor{red}{Q^{\min}_r},\ \textcolor{red}{Q^{\max}_r}$ | per phase |
| `i_max` | $\textcolor{red}{\mathbf{I}^{\max}_r}$ | per conductor |
| `p_dc_min`, `p_dc_max` | $\textcolor{red}{P^{\text{dc},\min}_r},\ \textcolor{red}{P^{\text{dc},\max}_r}$ | net DC bounds |

## 3. Variables

Each phase conductor $k$ injects a complex converter current $\textcolor{blue}{I_{r,k}}$,
stacked into $\textcolor{blue}{\mathbf{I}_{r}}$. The number of currents follows the
topology: one per phase (`FOUR_LEG`), one per conductor pair (`THREE_LEG`), or one
(`SINGLE_PHASE`).

## 4. Equality constraints

### Per-phase power

With $\Delta\textcolor{blue}{U_{r,k}}$ the phase voltage difference set by the
topology — phase-to-neutral (`FOUR_LEG`), line-to-line (`THREE_LEG`), or the terminal
pair (`SINGLE_PHASE`) — the injected complex power is

```math
\textcolor{blue}{S_{r,k}} = \Delta\textcolor{blue}{U_{r,k}}\,(\textcolor{blue}{I_{r,k}})^{*} = P_{r,k} + \textcolor{brown}{j}\,Q_{r,k}.
```

Current conservation over the IBR terminals gives its KCL contribution (injection
positive at the phase terminal, return at the neutral for `FOUR_LEG`).

### Reactive-power control law

Reactive power is set one of three ways (mutually exclusive):

- **Box** (default): the inequality of part 5.
- **Constant power factor** (from a control profile's `power_factor.pf`), a bilinear
  equality coupling $Q$ to $P$:

```math
\operatorname{sign}(\textcolor{red}{\mathrm{pf}})\,Q_{r,k} + \tan(\arccos|\textcolor{red}{\mathrm{pf}}|)\,P_{r,k} = 0,
```

  with $\textcolor{red}{\mathrm{pf}}>0$ lagging (absorbing VAr), $<0$ leading.

- **Volt-VAr droop** (from `volt_var`): $Q$ follows a piecewise-linear function of a
  monitored voltage magnitude $U_k$,

```math
Q_{r,k} = \textcolor{red}{Q^{\text{base}}_{r,k}}\; f^{\text{VV}}(U_k),
```

  where $U_k$ is phase-to-neutral, phase-to-ground, or phase-to-phase per the
  profile's `voltage_reference`, and may be per-phase or phase-averaged.

## 5. Inequality constraints

### Cartesian variable bounds

Optional per-conductor current box on the converter-current components, from `i_max`
(implied by the current circle below).

### Engineering bounds

**Active-power availability**:

```math
\textcolor{red}{P^{\min}_{r,k}} \le P_{r,k} \le \textcolor{red}{P^{\max}_{r,k}}.
```

A **Volt-Watt droop** (from `volt_watt`) adds a voltage-dependent curtailment cap
$P_{r,k}\le\textcolor{red}{P^{\text{base}}_{r,k}}\,f^{\text{VW}}(U_k)$ on top, so the
effective limit is the tighter of the two.

**Apparent-power circle** (the converter rating):

```math
P_{r,k}^2 + Q_{r,k}^2 \le (\textcolor{red}{S^{\max}_{r,k}})^2.
```

**Converter current circle** (optional, per conductor). Because
$|\textcolor{blue}{S_{r,k}}| = |\Delta\textcolor{blue}{U_{r,k}}|\,|\textcolor{blue}{I_{r,k}}|$,
this makes reactive capability roll off roughly linearly with voltage — the faithful
voltage-source-converter behaviour — rather than staying flat at $\textcolor{red}{S^{\max}}$:

```math
\textcolor{blue}{I_{r,k}}(\textcolor{blue}{I_{r,k}})^{*} \le (\textcolor{red}{I^{\max}_{r,k}})^2.
```

A trailing `i_max` entry additionally bounds the `FOUR_LEG` neutral return current.

**Shared-DC-link net power** (when `dc_link_coupled` without an external `dc_bus`):
the per-phase active powers are coupled by a net balance, letting the converter
circulate active power *between* phases (e.g. a four-wire STATCOM balancing an
unbalanced feeder):

```math
\textcolor{red}{P^{\text{dc},\min}_r} \le \sum_k P_{r,k} \le \textcolor{red}{P^{\text{dc},\max}_r}.
```

For a pure STATCOM both bounds are $0$ (no net active source). When the IBR instead
references an external `dc_bus`, this net power is balanced through DC KCL — see
[DC networks](dc.md).

## 6. Implementation in BMOPFTools

### Realisation

- **Rectangular bilinear power** with `cri`/`cii` the converter currents:
  $P = \Delta v^r\,\text{cri} + \Delta v^i\,\text{cii}$,
  $Q = \Delta v^i\,\text{cri} - \Delta v^r\,\text{cii}$
  ([`ibr.jl:_add_ibr_constraints!`](https://github.com/frederikgeth/BMOPFTools.jl/blob/main/ext/BMOPFOpfExt/ibr.jl), stamped per phase by `_apply_ibr_phase!`).
- **Apparent-power circle via auxiliaries** (`pi`,`qi` pinned to $P,Q$), as for
  generators.
- **Physical-root warm start.** The bilinear power has a spurious low-voltage /
  high-current root; the code seeds each current at $\textcolor{blue}{I}\approx\overline{S}/\overline{U}$
  from the seeded nominal voltage (`_warmstart_ibr_current!`) to steer Ipopt onto the
  physical branch (important in per-unit).
- **Smooth droop encoding.** Volt-VAr and Volt-Watt curves are piecewise-linear;
  BMOPFTools stamps them with a smoothed ReLU/softplus operator
  (`_resolve_volt_var`/`_resolve_volt_watt`, `curve_expr`) so the corners are
  differentiable for Ipopt. Droop is applied for `SINGLE_PHASE`/`FOUR_LEG` only;
  `THREE_LEG` (delta) has too few degrees of freedom and falls back to box bounds with
  a warning.
- **Neutral-conductor limit** via `_neutral_current_limit!` (as for generators).

### Source map

| Constraint | Code location |
|------------|---------------|
| Current variables | `ibr.jl:_add_ibr_variables!` |
| P/Q, ratings, control law | `ibr.jl:_add_ibr_constraints!`, `_apply_ibr_phase!` |
| Volt-VAr / Volt-Watt curves | `ibr.jl:_resolve_volt_var`, `_resolve_volt_watt`, `_monitor_U` |
| Shared-DC coupling | `dcnetwork.jl:_couple_converter_to_dc!` (see [DC networks](dc.md)) |

### Reconciliation note

!!! warning "IBR is not in the Task Force PDF"
    The entire `ibr` object — topologies, smart-inverter control profiles (constant-PF,
    Volt-VAr, Volt-Watt), the shared-DC-link STATCOM coupling, and grid-forming fields
    — is a BMOPFTools extension with no counterpart in the current PDF. It should be a
    first-class component in the superseding spec, alongside the DC subsystem it pairs
    with.
