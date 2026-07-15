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

**Zero-impedance aliasing.** A closed switch, a line whose series impedance is
below `z_line_min_ohm`, and a 1:1 zero-leakage transformer are all exact shorts:
their terminal pairs are **fused into a single node** by union-find rather than
stamped with a large ``1/z`` penalty admittance. This mirrors what the OPF and
[`simplify_network`](@ref) already do — they impose ``V_{\text{from}} =
V_{\text{to}}`` / merge the nodes — so the Ybus agrees with the model it
represents and avoids a conditioning artifact.

!!! note "Ideal transformers with a non-unity ratio"
    A zero-leakage transformer with ``N \neq 1`` cannot be node-aliased (the two
    sides are not identical) and has no finite ``Y_{\text{prim}}``. In
    `ybus_passive` it stamps the singular, shunt-only block with a warning;
    [`ybus_augmented`](@ref) models it **exactly** instead, as an ideal-coupling
    constraint row.

## Folding nonlinear loads

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
