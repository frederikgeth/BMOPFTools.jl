# Inverter-based resources

An **inverter-based resource (IBR)** is a source interfaced to the AC network through a
power-electronic converter: PV, battery storage, a STATCOM, or a generic converter. It
injects controllable active and reactive power subject to a converter apparent-power
rating, and can follow a smart-inverter control law (constant power factor, Volt-VAr,
Volt-Watt). Parts 1–5 state the foundational model;
[part 6](#6.-Implementation-in-BMOPFTools) records how BMOPFTools realizes it. A
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
| `s_max` | number[] | VA | ✔ | Apparent-power rating, one entry per coil |
| `p_min`, `p_max` | number[] | W | | Active-power bounds, one entry per coil |
| `q_min`, `q_max` | number[] | var | | Reactive-power bounds, one entry per coil |
| `i_max` | number[] | A | | Current-magnitude limit; per-entry meaning depends on `topology` (see [below](#Engineering-bounds)) |
| `p_avail` | number | W | | Scalar available active power; augmentation derives a missing `p_max` from it, and it is the `P_AVAILABLE` Volt-Watt base |
| `cost` | number[] | currency/kWh | | Per-coil linear energy price |
| `control_profile` | string | – | | Reference to a [control profile](control-profile.md) |
| `voltage_aggregation` | string | – | | Legacy `PER_PHASE` / `AVERAGE` override of the droop aggregation |
| `dc_link_coupled` | bool | – | | Couple the phases through a shared DC link |
| `p_dc_min`, `p_dc_max` | number | W | | Net DC-side active-power bounds (when `dc_link_coupled`) |
| `dc_bus`, `dc_terminal_map`, `dc_control`, … | – | – | | Shared DC-node coupling — see [DC networks](dc.md) |
| `r_filter`, `x_filter`, `b_filter_shunt`, `grid_forming`, `v_ref_internal` | – | – | | Accepted by the schema; not used by the OPF (`grid_forming` only informs a DC-island validation check) |

A *coil* is one independently controlled converter current: one per phase
conductor for `FOUR_LEG`, one per cyclic terminal pair for `THREE_LEG`, and one
for `SINGLE_PHASE`. A supplied `p_min`/`p_max`/`q_min`/`q_max` vector must have
exactly one entry per coil; a shorter one is rejected with an `ArgumentError`.

## 2. Input symbols

| Field | Symbol | Notes |
|-------|:------:|-------|
| `s_max` | $\textcolor{red}{\mathbf{S}^{\max}_r}$ | per coil |
| `p_min`, `p_max` | $\textcolor{red}{P^{\min}_r},\ \textcolor{red}{P^{\max}_r}$ | per coil |
| `q_min`, `q_max` | $\textcolor{red}{Q^{\min}_r},\ \textcolor{red}{Q^{\max}_r}$ | per coil |
| `i_max` | $\textcolor{red}{\mathbf{I}^{\max}_r}$ | per coil, plus optional neutral (`FOUR_LEG`) |
| `p_dc_min`, `p_dc_max` | $\textcolor{red}{P^{\text{dc},\min}_r},\ \textcolor{red}{P^{\text{dc},\max}_r}$ | net DC bounds |

## 3. Variables

Each coil $k$ injects a complex converter current $\textcolor{blue}{I_{r,k}}$,
stacked into $\textcolor{blue}{\mathbf{I}_{r}}$. The number of currents follows the
topology: one per phase conductor (`FOUR_LEG`), one per cyclic terminal pair
(`THREE_LEG`), or one (`SINGLE_PHASE`).

## 4. Equality constraints

### Per-phase power

With $\Delta\textcolor{blue}{U_{r,k}}$ the phase voltage difference set by the
topology — phase-to-neutral (`FOUR_LEG`; phase-to-earth when `terminal_map` has no
neutral), terminal $k$ to the next terminal cyclically (`THREE_LEG`), or
`terminal_map[1]` to `terminal_map[2]` (`SINGLE_PHASE`) — the injected complex power is

```math
\textcolor{blue}{S_{r,k}} = \Delta\textcolor{blue}{U_{r,k}}\,(\textcolor{blue}{I_{r,k}})^{*} = P_{r,k} + \textcolor{brown}{j}\,Q_{r,k}.
```

Current conservation over the IBR terminals gives its KCL contribution: each coil
current enters at its positive terminal and returns at its reference terminal (the
neutral for `FOUR_LEG`, or earth when there is none).

### Reactive-power control law

Reactive power can be freely dispatched or set by one of the following control
equalities. Declared reactive capability bounds apply in every mode:

- **Dispatchable Q** (default): no additional control equality.
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
  $\textcolor{red}{Q^{\text{base}}_{r,k}}$ is the coil's `s_max` entry (`q_ref = VAR_MAX`).

If a profile declares both `power_factor` and a droop curve, the power factor is
used and both droop curves are dropped, with a warning.

## 5. Inequality constraints

### Cartesian variable bounds

None. The converter-current components are free variables; `i_max` enters only
through the current circle below.

### Engineering bounds

**Active-power availability**:

```math
\textcolor{red}{P^{\min}_{r,k}} \le P_{r,k} \le \textcolor{red}{P^{\max}_{r,k}}.
```

**Reactive-power capability**, for each declared bound:

```math
\textcolor{red}{Q^{\min}_{r,k}} \le Q_{r,k} \le \textcolor{red}{Q^{\max}_{r,k}}.
```

BMOPFTools enforces these bounds alongside PF or supported Volt-VAr control,
without clipping the equality or dropping the bounds. A conflicting requirement
can leave no feasible point; see [IBRs in the OPF formulation](../opf.md).
For `THREE_LEG`, the P/Q quantities index cyclic terminal pairs;
these bounds do not constrain the external conductor powers.

A **Volt-Watt droop** (from `volt_watt`) adds a voltage-dependent curtailment cap
$P_{r,k}\le\textcolor{red}{P^{\text{base}}_{r,k}}\,f^{\text{VW}}(U_k)$ on top, so the
effective limit is the tighter of the two. $\textcolor{red}{P^{\text{base}}_{r,k}}$
is selected by the profile's `p_ref`: the coil's `s_max` (`S_MAX`, default), its
`p_max` (`P_MAX`), or `p_avail` divided equally over the coils (`P_AVAILABLE`).

**Apparent-power circle** (the converter rating; stamped by OPF and feasibility
OPF, omitted in power flow):

```math
P_{r,k}^2 + Q_{r,k}^2 \le (\textcolor{red}{S^{\max}_{r,k}})^2.
```

**Converter current circle** (optional, per conductor). Because
$|\textcolor{blue}{S_{r,k}}| = |\Delta\textcolor{blue}{U_{r,k}}|\,|\textcolor{blue}{I_{r,k}}|$,
this makes reactive capability roll off roughly linearly with voltage — the faithful
voltage-source-converter behavior — rather than staying flat at $\textcolor{red}{S^{\max}}$:

```math
\textcolor{blue}{I_{r,k}}(\textcolor{blue}{I_{r,k}})^{*} \le (\textcolor{red}{I^{\max}_{r,k}})^2.
```

The meaning of `i_max` depends on the topology:

- `FOUR_LEG`: one entry per phase conductor; a trailing extra entry (length =
  phases + 1) bounds the neutral return current $\lvert\sum_k I_{r,k}\rvert$ when the
  map has a neutral terminal. A phases-only vector warns.
- `SINGLE_PHASE`: length 1 or 2; both entries bound the same current, so one circle
  is stamped at the tighter value.
- `THREE_LEG`: `i_max[k]` caps the cyclic pair current $I_{r,k}$, not the external
  conductor current (which is the difference of two adjacent pair currents and can
  exceed the pair cap). There is no neutral.

**Shared-DC-link net power** (when `dc_link_coupled` without an external `dc_bus`):
the per-phase active powers are coupled by a net balance, letting the converter
circulate active power *between* phases (e.g. a four-wire STATCOM balancing an
unbalanced feeder):

```math
\textcolor{red}{P^{\text{dc},\min}_r} \le \sum_k P_{r,k} \le \textcolor{red}{P^{\text{dc},\max}_r}.
```

This follows the four-wire inverter model of Heidari and Geth (2024) (see
[References](references.md)). For a pure STATCOM both bounds are $0$ (no net active
source). The OPF builder reads a missing bound as $0$; augmentation fills missing
bounds with $0/0$ for a STATCOM and $0/$`p_avail` (else $0/\sum_k$`p_max`) otherwise. When the IBR instead
references an external `dc_bus`, this net power is balanced through DC KCL — see
[DC networks](dc.md).

## 6. Implementation in BMOPFTools

### [Realization](@id Realisation)

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
  a `THREE_LEG` (delta) IBR keeps its box bounds, with a warning. Unsupported
  `volt_var`/`volt_watt` variants (see [Control profiles](control-profile.md))
  likewise fall back to the box bounds with a warning.
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
    — is a BMOPFTools extension with no counterpart in the Task Force PDF. It should be a
    first-class component in the superseding spec, alongside the DC subsystem it pairs
    with.
