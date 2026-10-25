# System nodal admittance

Use this guide when you need a network matrix for inspection, a power-flow
iteration, or a downstream algorithm. Start with the
[buses and terminals primer](../terminals_primer.md) and
[units and bases](../tutorial_units.md). These builders assemble equations;
they do not choose source boundary conditions or certify a solvable network.

## Choose a builder

| Your task | Builder | What you receive and must supply |
|---|---|---|
| Inspect the passive network | [`ybus_passive`](@ref) | `Y`, `nodes`, `index`; loads, generators, IBRs and ideal voltage sources are excluded. Supply injections and source boundaries separately. |
| Keep nonlinear loads in a power-flow iteration | [`ybus_linearized`](@ref), `fold=:constant_z` | A constant-Z load contribution in `Y`, plus a voltage-dependent `i_comp`. The assembled equations still contain nonlinear load behavior. |
| Replace loads by admittances at one operating point | [`ybus_linearized`](@ref), `fold=:all` | An equivalent admittance at the supplied `v0`, with zero `i_comp`. It matches load current at that point; it is not a Jacobian linearization. |
| Retain supported small/zero transformer leakage or explicit switch currents | [`ybus_augmented`](@ref) | A bordered `K`, node mappings and `couplings`. Additional unknowns represent scaled port currents; finite leakage is retained. Loads are excluded. |

The passive relation is ``I=YV`` with node-to-earth voltages. The augmented
relation uses ``K=[Y\ A^T;\ A\ {-D}]``; the lower block vanishes only for
fully ideal ports. This follows the modified nodal analysis principle of
retaining branch currents and constitutive equations when a voltage-only stamp
is unsuitable [1]. Package-specific supported domains are listed below.
All three builders reuse the [transformer primitive conventions](transformer-admittance.md).

## A small network, with an explicit source boundary

This executable example uses a 230 V source, a 1 ohm line, and a 100 W
constant-power load. The grounded neutral has index zero and no matrix row.
No JuMP model or optimizer is needed.

```@example admittance_guide
using BMOPFTools, LinearAlgebra

net = parse_bmopf("""
{"bus":{
    "s":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"]},
    "b":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"]}},
 "voltage_source":{"grid":{"bus":"s","terminal_map":["a"],
     "v_magnitude":[230.0],"v_angle":[0.0]}},
 "linecode":{"lc":{"R_series_1_1":1.0}},
 "line":{"l":{"bus_from":"s","bus_to":"b","terminal_map_from":["a"],
     "terminal_map_to":["a"],"linecode":"lc","length":1.0}},
 "load":{"d":{"bus":"b","terminal_map":["a","n"],
     "configuration":"SINGLE_PHASE","p_nom":[100.0],"q_nom":[0.0]}}}
"""; from_string=true)

passive = ybus_passive(net)
loads = ybus_linearized(net)  # default: fold=:constant_z
augmented = ybus_augmented(net)
@assert size(passive.Y) == size(loads.Y) == size(augmented.K) == (2, 2)
@assert passive.index[("b", "n")] == 0
@assert isempty(augmented.couplings)  # no bordered devices in this case

# Partition known source voltage b from unknown voltages u; never invert full Y.
b = [loads.index[("s", "a")]]
u = [loads.index[("b", "a")]]
v = fill(230.0 + 0im, length(loads.nodes))
for iteration in 1:10
    rhs = loads.i_comp(v)[u] - loads.Y[u, b] * v[b]
    v[u] = loads.Y[u, u] \ rhs
end
expected = (230.0 + sqrt(230.0^2 - 4 * 100.0)) / 2
@assert isapprox(real(v[only(u)]), expected; atol=1e-8)
@assert norm((loads.Y * v - loads.i_comp(v))[u]) < 1e-8

# An operating-point equivalent matches this load current at this v0.
v0 = Dict(node => v[k] for (k, node) in enumerate(loads.nodes))
folded = ybus_linearized(net; fold=:all, v0)
@assert norm((folded.Y * v)[u]) < 1e-8
(nodes=loads.nodes, voltage_V=real(v[only(u)]),
 source_current_A=(loads.Y * v - loads.i_comp(v))[only(b)])
```

The source row gives the required source injection, rather than a zero
residual. Ten fixed-point steps suffice for this case; this is not a convergence
guarantee for other networks. Use each result's `index` when assembling vectors,
since aliasing can change node counts and ordering.

### When an admittance inverse is unavailable

Replace the line by a supported ideal 230:115 V transformer. The passive
builder rejects its zero leakage; the augmented builder retains a port current.
The load is removed here to isolate the transformer relation.

```@example admittance_guide
ideal = deepcopy(net)
delete!(ideal, "line")
delete!(ideal, "load")
ideal["transformer"] = Dict("single_phase" => Dict("t" => Dict{String,Any}(
    "bus_from" => "s", "bus_to" => "b",
    "terminal_map_from" => ["a", "n"], "terminal_map_to" => ["a", "n"],
    "v_nom_from" => 230.0, "v_nom_to" => 115.0,
    "r_series_from" => 0.0, "x_series_from" => 0.0,
    "r_series_to" => 0.0, "x_series_to" => 0.0)))
rejected = try
    ybus_passive(ideal)
    false
catch err
    err isa ArgumentError
end
@assert rejected
border = ybus_augmented(ideal)
@assert size(border.K) == (3, 3)
@assert length(border.nodes) == 2 && length(border.couplings) == 1
b = [border.index[("s", "a")]]
u = setdiff(collect(1:size(border.K, 1)), b)  # LV voltage and port unknown
x = zeros(ComplexF64, size(border.K, 1))
x[b] .= 230.0
x[u] = border.K[u, u] \ (-border.K[u, b] * x[b])
@assert isapprox(x[border.index[("b", "a")]], 115.0; atol=1e-10)
physical_port_current = border.couplings[1].scale * x[length(border.nodes) + 1]
(voltage_V=x[border.index[("b", "a")]], physical_port_current_A=physical_port_current)
```

This unloaded, grounded example has zero port current. Floating references and
redundant ideal constraints can make other bordered systems singular. See
[exact substitutions and formulation boundaries](../formulation_substitutions.md)
for why retaining a constitutive equation matters at such boundaries.

## Convention

The passive admittance blocks follow the per-element `transformer_yprim`
export and OpenDSS `DumpYprim` / `getYsparse` conventions. The augmented
port scaling is described under transformer leakage policy below:

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
`wye_delta`, `delta_wye`, `single_phase_autotransformer`,
`open_delta_regulator`, `center_tap`, and `n_winding` within the domains below.
Unsupported winding configurations raise `ArgumentError`. `ybus_passive`,
`ybus_linearized`, standalone primitives and `ideal_xfmrs=:stamp` reject such
couplings rather than omit them or stamp a large inverse. Set a lower threshold
explicitly to request a finite primitive for a nonzero impedance.
`transformer_yprim(...; shunt_only=true)` is an explicit inspection operation,
not a complete transformer model.

The bordered system is ``K=\begin{bmatrix}Y&A^T\\A&-D\end{bmatrix}``, with
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

With fixed source-node voltages ``V_b`` and unknown-node voltages ``V_u``,
the equations for the unknown nodes are

```math
Y_{uu} V_u = i_{\mathrm{comp},u}(V) + I_{\mathrm{external},u} - Y_{ub}V_b.
```

Here ``I_{\mathrm{external},u}`` contains any additional specified injections.
A fixed-point iteration evaluates the compensation current at the previous
voltage and solves this partitioned system, assuming ``Y_{uu}`` is nonsingular.
The OpenDSS documentation describes the related compensation-current approach
[2]; the example above shows the explicit ideal-source boundary used here.

**Fold modes.**

- `fold = :constant_z` (default) — fold only the constant-Z part; the rest lives
  in `i_comp`. This preserves the declared load law within its supported
  voltage domain; evaluating `i_comp` is still necessary at every iterate.
- `fold = :all` — fold the *whole* load as its equivalent admittance
  ``\overline{S(v_0)}/|\Delta v_0|^2`` at an operating point `v0` (required);
  then ``\mathbf{i}_{\text{comp}} \equiv 0``. This is an operating-point
  load-as-admittance equivalent. Away from `v0`,
  it generally changes the load current and its voltage derivative.

!!! note "Generators and IBRs are not folded"
    Generator and IBR injections are OPF variables (or, for state estimation,
    measured), not a fixed model, so they are not folded here. Adding them as
    `i_comp` injections is a planned extension.

## Uses

- **Downstream state-estimation work.** `ybus_passive` supplies network
  admittances for measurement equations; `fold=:all` supplies an operating-point
  equivalent. These exports are building blocks, not a complete estimator.
- **Screening and initialization.** Combine a matrix, source boundaries and
  compensation currents in an external power-flow or initialization algorithm.
- **Cross-validation.** Both matrices are checked against OpenDSS — see
  [Validating the OPF engine](@ref) → *System nodal admittance gates*.

## Validation summary

- `ybus_passive` is compared term-by-term against OpenDSS `getYsparse` on
  load-free decks (exact to machine precision for lines and capacitors, ``\sim
  10^{-6}`` for the imported transformer).
- `ybus_linearized` (both fold modes) satisfies the power-flow residual
  ``\lVert (\mathbf{Y}\,\mathbf{v}_0 - \mathbf{i}_{\text{comp}}(\mathbf{v}_0))_u\rVert
  \approx 0`` on non-source nodes at OpenDSS's converged voltage across WYE / DELTA / SINGLE\_PHASE +
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

### N-winding ports

N-winding ports retain the existing winding-1 coil-base `ZB` matrix. For each
phase, port `k-1` has voltage `u1-uk/Nk`, where `Nk=v_nom[k]/v_nom[1]` and each
`uk` is the explicitly connected WYE or DELTA coil voltage. The lower block
is `-scale²*ZB`, including all finite and singular modes. Neither inversion,
mode truncation nor an artificial impedance is used for bordered units.
At a zero configured cutoff, a roundoff-rank-deficient `ZB` still selects the
border; this preserves the supplied matrix rather than declaring its small
singular values exactly zero.

The supported domain is two or more windings with positive finite coil
voltages, matching phase counts, explicit finite pairwise `x_sc` values and
finite winding resistances. Terminal labels are `a`, `b`, `c`, and optional
`n` (case insensitive). WYE supports one to three phases with explicit neutral
or implicit earth; DELTA requires three phases, no neutral and `delta_roll`
of +1 or -1. Unknown configurations, malformed maps and missing pairs are
rejected rather than inferred. The no-load branch remains across each coil
of winding 2. Internal neutral-grounding fields are not supported by the
n-winding model; represent grounding as explicit network shunts (PSK-000002).
Network assembly also requires every referenced winding bus and terminal to
exist. A named but undeclared neutral is an error, not implicit earth. Omit the
neutral from a WYE winding map to request the documented implicit-earth domain;
declared perfectly grounded terminals continue to map to earth explicitly.
Floating winding references and ideal delta cycles can leave free voltages or
circulating currents; callers must supply valid references and handle rank
limitations. A border does not assert solvability or physical realizability.

## References and next steps

1. C.-W. Ho, A. E. Ruehli, and P. A. Brennan, “The Modified Nodal Approach to
   Network Analysis,” *IEEE Transactions on Circuits and Systems* 22(6),
   504–509, 1975. [doi:10.1109/TCS.1975.1084079](https://doi.org/10.1109/TCS.1975.1084079).
2. EPRI, OpenDSS documentation, [The Normal method](https://opendss.epri.com/TheNormalSolutionmethod.html).

For changing the JuMP formulation, continue to
[exact substitutions](../formulation_substitutions.md) and
[custom formulations](../tutorial_custom_formulations.md). To differentiate a
solved model with respect to physical parameters, use the
[DiffOpt worked example](../differentiable_extensions.md#diffopt-worked-example).
These are different tasks from constructing `Y` or `K`.
