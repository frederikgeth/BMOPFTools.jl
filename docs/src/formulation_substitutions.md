# Exact substitutions and formulation boundaries

An alternative encoding can remove an auxiliary variable or equation without
introducing a modeling approximation **within its supported domain**. That
is the useful meaning of “at no cost” here. It does not promise the same
sparsity, conditioning, solve time, constraint multipliers, or derivative
behavior at a singular boundary.

Read this after [First case](first_case.md) and the
[buses and terminals primer](terminals_primer.md). It explains how to recognize
three implementation choices; the [OPF model](opf.md) remains the detailed
reference for device equations, keys and units.

## Substitute, retain, or approximate?

| Situation | Current package behavior | Boundary to preserve |
|---|---|---|
| A shunt current is determined by its terminal voltages | Insert the current expression directly into KCL. | Keep the full admittance and terminal map; removing an auxiliary variable does not remove the device. |
| Two orientations describe the same series current | Keep one independent series current and expose the reverse orientation as its negative. | Total line-end currents also include their local shunts; they are generally not negatives of each other. Both end limits remain relevant. |
| A supported load is structurally pure impedance | Use its current law directly, without a squared-voltage auxiliary. | The model classification must remain valid over the parameter family; a coefficient whose current value is zero is not necessarily absent. |
| A transformer leakage inverse is unavailable or below the configured threshold | Retain voltage/current port equations in the augmented admittance builder. | Preserve finite leakage; a small value does not become an ideal zero-leakage model. |
| A nonlinear load is replaced by its admittance at `v0` | `ybus_linearized(...; fold=:all, v0)` matches the operating-point current. | This is an operating-point equivalent, generally not an exact substitution over changing voltages. |

The last two rows are explained in [nodal admittance builders](spec/nodal-admittance.md).
Keeping a branch current and its constitutive equation is the classical modified
nodal analysis approach when eliminating that current is unsuitable [1].

## The zero-voltage example

For a pure-impedance load, the native current law is

```math
I=\overline{S_{\mathrm{nom}}}\,\Delta V/V_{\mathrm{nom}}^2,
\qquad V_{\mathrm{nom}}>0.
```

It gives zero current at zero coil voltage. If instead we start from only the
power relation ``\Delta V\,\overline I =
S_{\mathrm{nom}}|\Delta V|^2/V_{\mathrm{nom}}^2``, cancellation is valid only
when ``\Delta V\ne0``. At zero voltage that power equation is ``0=0`` and
leaves the current unconstrained. The current law supplies the impedance
model's physical boundary behavior; it is not equivalent at zero to that
weaker power equation alone.

This matters beyond loads: Claeys, Deconinck and Geth [2, §IV-D, eq. (30)]
show how replacing KCL by power balance can admit nonphysical solutions at
zero nodal voltage in four-wire formulations. A numerical epsilon or an
arbitrary lower bound on every neutral voltage is not a substitute for the
correct current equations.

BMOPFTools uses the direct law for `constant_impedance`, pure-Z ZIP, and
exponential loads with both exponents equal to two. Mixed ZIP terms are not
separately substituted. The [load formulation](opf.md#Loads) documents the
precise routing, retained public current handles, replacement constraint keys,
and positive-voltage treatment for other load laws.

## Preserve the parameter family and the observables

A parameterized coefficient that currently evaluates to zero must remain in
the expression if later updates may make it nonzero. The native load providers
preserve that symbolic dependence. Removing the term based on today's value
can change tomorrow's model and its sensitivity. See
[parameterized extensions](differentiable_extensions.md), including its
[parameter-update workflow](@ref opf-parameter-resolves), for supported paths
and re-solve checks.

When using or extending a substitution, establish the supported domain, the
recovery map for any removed variable, and which physical outputs must agree.
Then compare terminal currents, KCL, device limits and power in those units.
An affine expression can remain a public current handle even though it is no
longer an independent JuMP variable. Likewise, deleting or rescaling a
constraint changes how its multiplier must be interpreted; a matching primal
voltage alone does not establish matching duals or local sensitivities.

The detailed [line](opf.md#Lines), [shunt](opf.md#Standalone-shunts), and
[load](opf.md#Loads) sections own the implementation details. The package's
`test/opf_device_substitution_tests.jl` supplies analytic device witnesses,
including zero voltage and parameter updates through zero. The
[admittance guide](spec/nodal-admittance.md) explains transformer references and
port boundaries. These finite witnesses do
not establish a universal formulation-equivalence claim; use
[independent solution verification](tutorial_trust_but_verify.md) for the
actual study case.

## References

1. C.-W. Ho, A. E. Ruehli, and P. A. Brennan, “The Modified Nodal Approach to
   Network Analysis,” *IEEE Transactions on Circuits and Systems* 22(6),
   504–509, 1975. [doi:10.1109/TCS.1975.1084079](https://doi.org/10.1109/TCS.1975.1084079).
2. S. Claeys, G. Deconinck, and F. Geth, “Optimal Power Flow in Four-Wire
   Distribution Networks: Formulation and Benchmarking,” *PSCC*, 2022.
   [Author manuscript](https://arxiv.org/abs/2204.08126).
