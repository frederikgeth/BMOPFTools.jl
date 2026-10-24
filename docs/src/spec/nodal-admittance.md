# System nodal admittance

BMOPFTools assembles a whole-system **nodal admittance matrix** ``\mathbf{Y}``
such that ``\mathbf{I} = \mathbf{Y}\,\mathbf{V}``, where ``\mathbf{V}`` is the
vector of node-to-earth voltages and ``\mathbf{I}`` the current injected *into*
the network at each node. Two matrices are exposed:

- [`ybus_passive`](@ref) — the **passive** network: lines, shunts, capacitors,
  and transformers only. Linear and voltage-invariant.
- [`ybus_linearized`](@ref) — the passive matrix with the **nonlinear loads
  folded in**, following the OpenDSS solution model (constant-impedance part
  folded into ``\mathbf{Y}``; constant-current / constant-power part returned as
  a compensation-current closure).
- [`ybus_augmented`](@ref) — the passive matrix **bordered with ideal-coupling
  constraint rows** (closed switches, zero-leakage transformers of any ratio),
  `K = [Y Aᵀ; A 0]`. The exact model for elements with no finite admittance
  form.

Both build on the per-element [transformer primitive admittance](transformer-admittance.md)
and reuse the same convention.

## Convention

Identical to the per-element `transformer_yprim` export and OpenDSS
`DumpYprim` / `getYsparse`:

- **SI siemens.**
- ``\mathbf{I} = \mathbf{Y}\,\mathbf{V}`` with current positive *into* the
  element (out of the bus).
- **Reciprocal, not Hermitian:** ``\mathbf{Y} = \mathbf{Y}^{\mathsf{T}}`` (a
  plain transpose). The network is lossy, so ``\mathbf{Y} \neq \mathbf{Y}^{\mathsf{H}}``
  — symmetry checks and constructions use `transpose`, never the adjoint.
- **Full, un-reduced, multiphase.** Floating neutrals keep their own rows;
  nothing is Kron-reduced to a phase domain.

## Nodes, earth reference, and aliasing

A node is a `(bus_id, terminal_name)` pair. The data model has no integer node
numbers, so the assembler assigns a deterministic integer ordering, exposed as
`YbusResult.nodes` (row/column order) and `YbusResult.index` (`(bus, terminal) →
row`, with `0` for the earth reference).

**Earth reference.** Earth is the reference (not a matrix row). A terminal
collapses onto it only if the bus declares it in `perfectly_grounded_terminals`.
Its admittance contributions become diagonal self-terms. This deliberately
differs from the OPF's internal grounding set, which also pins voltage-source
neutrals: whether such a neutral is earthed depends on the actual grounding
element (a grounding reactor is imported as a *finite* [shunt](shunt.md), not a
perfect ground), and the explicit-neutral convention keeps every
non-perfectly-grounded neutral as its own node. A voltage source is ideal in the
BMOPF model — it contributes no admittance and sets only the boundary.

**Zero-impedance aliasing.** Closed switches and negligible-impedance lines
fuse their terminal pairs. Transformer windings use voltage/current equations:
a unity nameplate ratio does not identify their terminal-to-earth voltages or
bond isolated neutrals (PSK-000002).

A switch is closed unless its [`open_switch`](switch.md) field is `true`; an
absent field means closed, as in the OPF, and a value that is not a boolean
raises an `ArgumentError`. An open switch is neither aliased nor constrained, so
the nodes on its two sides stay separate. A retained terminal with no remaining
stamped admittance has an all-zero row (a singular `Y`). Local shunts can give an
isolated terminal a nonzero row, so isolation alone does not imply a singular
`Y`. [`connectivity_analysis`](@ref) reports open-switch endpoints without a
closed path to a source as `open_switch_isolated_buses`.

Transformer borders replace only the **series** contribution. Finite
magnetising and internal neutral-grounding branches remain in the passive block,
stamped exactly once. This preserves the represented grounding branch; it does
not establish grounding adequacy or equipment safety (PSK-000002).

### Transformer leakage policy

Ordinary two-winding and center-tap Ybus inputs require explicit positive finite
`v_nom_from` and `v_nom_to`, including shunt-only primitive inspection. Missing,
zero, negative, Boolean or nonfinite declarations raise `ArgumentError`; they
never imply a unity turns ratio. Ratios must also remain finite and nonzero in
Float64 arithmetic (PSK-000002).

`xfmr_z_min_ohm` must be finite and nonnegative. An effective impedance at or
below it selects a bordered representation, **not an approximation to zero**.
For ordinary two-winding units, the test uses the primitive's effective series
impedance: tapped from-coil base for single-phase, wye-coil base for Yd/Dy with
the existing delta-base and tap referral. Regulators use each from-referred core
impedance. Center-tap uses each LV-referred star arm (primary tap scaling cancels
against the effective turns ratio). N-winding uses the smallest singular value
of the winding-1 coil-base `ZB`, including partly singular matrices.

`ybus_augmented` currently supports small/zero leakage for `single_phase`,
`wye_delta`, `delta_wye`, `single_phase_autotransformer`, and
`open_delta_regulator`, and `center_tap`. Other subtypes requiring a border raise
`ArgumentError` until their port domains are supported. `ybus_passive`,
`ybus_linearized`, standalone primitives and `ideal_xfmrs=:stamp` reject such
couplings rather than omit them or stamp a large inverse. Set a lower threshold
explicitly to request a finite primitive for a nonzero impedance.
`transformer_yprim(...; shunt_only=true)` is an explicit inspection operation,
not a complete transformer model.

The bordered system is ``K=[Y\; A^T;\ A\; -D]`` in block notation, with
``A=y_0 C``, ``D=y_0^2 Z``, and physical port current ``i=y_0 w``. Its lower
rows express ``CV=Zi``. Only exactly zero leakage yields ideal constraints.
There is no universal bound of `1/xfmr_z_min_ohm` on matrix entries: ratios,
incidence and superposed contributions also enter. Network islands and
redundant ideal cycles may still make the system singular.

## Folding nonlinear loads

DELTA load geometry is shared with the OPF builder: two distinct phase
terminals define one coil; three define the ordered cyclic coils. Both paths
require exactly one `p_nom` and `q_nom` entry per coil and reject neutral/earth
endpoints, unresolved roles, duplicates and nonfinite powers. Invalid inputs
raise `ArgumentError`; terminals are never silently removed from the map.

[`ybus_linearized`](@ref) folds the [load](load.md) elements. On each sub-load
connection ``(t_{\text{pos}}, t_{\text{neg}})`` with drop ``\Delta v = V_{\text{pos}}
- V_{\text{neg}}``, a ZIP load draws (matching the OPF load model exactly)

```math
P(|\Delta v|) = p_{\text{nom}}\!\left(\alpha_Z \tfrac{|\Delta v|^2}{V_{\text{nom}}^2}
  + \alpha_I \tfrac{|\Delta v|}{V_{\text{nom}}} + \alpha_P\right),
\qquad I = \frac{\overline{S(|\Delta v|)}}{\overline{\Delta v}},
```

(and ``Q`` with the ``\beta`` coefficients; exponential loads use
``(|\Delta v|/V_{\text{nom}})^{\gamma}``). This splits by contribution:

| Part | Voltage dependence | Where it goes |
|------|--------------------|---------------|
| constant-Z (``\alpha_Z, \beta_Z``, ``\gamma = 2``) | ``\propto |\Delta v|^2`` — exact admittance | folded into ``\mathbf{Y}`` |
| constant-I (``\alpha_I, \beta_I``, ``\gamma = 1``) | magnitude fixed, angle tracks ``V`` | compensation current |
| constant-P (``\alpha_P, \beta_P``, ``\gamma = 0``) | ``\overline{S}/\overline{V}`` | compensation current |
| non-integer exponential | power law | compensation current |

The constant-Z part is a plain admittance ``y_z = c_{W,p} - \mathrm{j}\,c_{W,q}``
(the same two-node stamp as a passive shunt across the connection), where
``c_{W,\cdot}`` is the ``|\Delta v|^2`` coefficient of ``P`` / ``Q``. The rest is
returned as `i_comp(V)`, a closure mapping a node-ordered voltage vector to the
compensation-current vector (injection ``= -`` current drawn).

The resulting linear system

```math
\mathbf{Y}\,\mathbf{V} = \mathbf{i}_{\text{comp}}(\mathbf{V})
```

is the fixed-point / Z-bus power-flow map: solving it by iteration
``\mathbf{V} \leftarrow \mathbf{Y}^{-1}\mathbf{i}_{\text{comp}}(\mathbf{V})`` is a
power flow, and the first iterate is the standard linear approximation.

**Fold modes.**

- `fold = :constant_z` (default) — fold only the constant-Z part; the rest lives
  in `i_comp`. This is the OpenDSS SolutionMode split.
- `fold = :all` — fold the *whole* load as its equivalent admittance
  ``\overline{S(v_0)}/|\Delta v_0|^2`` at an operating point `v0` (required);
  then ``\mathbf{i}_{\text{comp}} \equiv 0``. This is OpenDSS's converged-solution
  system ``\mathbf{Y}`` and the load-as-admittance seed for state estimation.

!!! note "Generators and IBRs are not folded"
    Generator and IBR injections are OPF variables (or, for state estimation,
    measured), not a fixed model, so they are not folded here. Adding them as
    `i_comp` injections is a planned extension.

## Uses

- **State estimation.** `ybus_passive` is the substrate for the WLS measurement
  Jacobian; `ybus_linearized(fold = :all)` gives the load-as-admittance seed.
- **Screening and initialization.** The linearized matrix gives a cheap flat
  start / warm start and a Ybus-based power flow independent of the OPF.
- **Cross-validation.** Both matrices are checked against OpenDSS — see
  [Validating the OPF engine](@ref) → *System nodal admittance gates*.

## Validation summary

- `ybus_passive` is compared term-by-term against OpenDSS `getYsparse` on
  load-free decks (exact to machine precision for lines and capacitors, ``\sim
  10^{-6}`` for the imported transformer).
- `ybus_linearized` (both fold modes) satisfies the power-flow residual
  ``\lVert \mathbf{Y}\,\mathbf{v}_0 - \mathbf{i}_{\text{comp}}(\mathbf{v}_0)\rVert
  \approx 0`` at OpenDSS's converged voltage across WYE / DELTA / SINGLE\_PHASE +
  ZIP / constant-power cases.

### Regulator ports and shared bushings

The single-phase regulator ties its reference bushing between from/to sides;
it can be a neutral or the second phase of a line-to-line coil. An omitted
reference is allowed only on both sides (implicit earth). Open-delta ties the
common phase of its two cores (ABBC: b, BCAC: c, CABA: a). These galvanic bonds
apply to finite and ideal leakage alike and are distinct from isolated winding
voltage relations (PSK-000013, PSK-000002).

Each regulator core uses its own positive finite fixed tap and Type A/B ratio.
If one core needs a border, both core equations are retained, including all
finite leakage and one no-load shunt per core. Terminal current and absorbed
power tests cover shifted references, unbalanced excitation and mixed cutoffs.

### Center-tap ports

A center-tap transformer's terminal order is `[HV phase, HV neutral]` and
`[LV leg1, LV neutral, LV leg2]`. Its two auxiliary currents use the LV coil
base. Write `uH=(V_Hp-V_Hn)/N`, `u1=V_leg1-V_Ln`, `u2=V_Ln-V_leg2`,
`zH=Z_from*tap²/N²`, and `zL=Z_to`. The port rows are `[uH-u1,uH-u2]` and
the impedance block is `[zH+zL zH; zH zH+zL]`. This preserves the opposite
polarity of leg2 and every finite arm, including when another arm is zero.
No arm is inverted. Fully ideal units have two independent zero-voltage-drop
relations; partly ideal units generally have a nonzero lower-right block.
Magnetising current remains on LV leg1 and both internal neutral grounding
branches remain in the passive block (PSK-000002).

`couplings[j]` describes auxiliary unknown `w[j]` at row/column
`length(nodes)+j`; its physical port current is `couplings[j].scale*w[j]`.
For coupled ports the lower-right block defines mutual impedances, so a single
auxiliary row cannot be interpreted as an independent ideal constraint.
