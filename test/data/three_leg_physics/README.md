# Independent THREE_LEG witnesses (#95)

The balanced and unbalanced one-bus, three-wire networks prescribe voltage magnitudes
and angles. `_test_targets` holds pair powers in W/var and is removed before
building the model. The native source supplies the opposite external current;
no line is needed to independently observe each conductor's KCL. `balanced.json`
has equal pair powers; `unbalanced.json` has unequal magnitudes, non-120-degree
angles, unequal powers, both reactive signs, and one consuming pair.

The standalone suite `test/three_leg_physics_tests.jl` computes
`J[k] = conj(S[k]/(V[k]-V[next]))` and `I[k] = J[k]-J[previous]` using only
authored inputs. It checks full phasors against native pair and source variables,
each terminal's KCL and source power, and total complex power balance. Checking
only `sum(I)==0` would not detect incorrect pair stamping or result indexing.
Result `cri`/`cii` are pair currents labeled by the first endpoint; they must not
be interpreted as conductor currents. The balanced witness explicitly permits
conductor current greater than the pair cap while every pair stays within it.

The finite deterministic matrix covers SI and two bases each for classic,
consistent and zone PU policies. Tolerances use physical excitation scales,
not PU bases. Unequal P/Q/S/current ratings are isolated by family and pair;
boundary solves use Ipopt `tol=constr_viol_tol=1e-12`, no acceptable-level early
exit, no automatic NLP scaling, and no bound relaxation. At the 1 MVA base,
`1e-10` termination admitted small physical power residuals above the new
oracle's tolerance; convergence was tightened instead of relaxing assertions.
inside/on-boundary points must solve and satisfy the independent electrical
checks. Beyond-boundary points are evaluated directly in the registered model
row at the prescribed analytic point. A positive signed residual is the
witness; local solver failure is neither required nor called proof of global
infeasibility. Zero and absent ratings are separate cases. JSON recovery and
rotation/cyclic relabeling preserve physical units, orientation and pair identity.
Existing malformed-topology and unsupported-droop regressions remain enabled.

This is case-specific evidence linked to the existing `PSK-000013` contract via
`knowledge/executable.toml`; it does not extend that contract's scientific claim.
The domain is three distinct terminals, nonzero cyclic pair voltage, fixed ideal
source phasors, and the existing lossless fundamental cyclic-pair IBR. It does
not assess zero-voltage inversion, filters, switching, DC ripple or advanced
controllers. The result schema and feasible region are unchanged.

## Minimized zero-current defect

`zero_current.json` reproduces a warm-start transfer failure before solving:
`UnsupportedAttribute{VariablePrimalStart}` from MOI's `ZerosBridge`. The native
IBR warm-starts its pair-current variables, but a vector of those variables in
`Zeros` selects a variable-elimination bridge that cannot accept the starts.
The shared zero-magnitude helper now represents bare variables as affine
expressions in the same vector equality. This preserves exact zero semantics,
the variables and their starts; it neither removes a cap nor adds a squared-zero
inequality. The suite exercises the public `solve_opf` path for this minimized
witness in every coordinate policy/base. Zero-norm tests avoid adding redundant
P=Q=0 target equalities because the zero cap already implies them.

## Provenance and adaptation

Patterns were reviewed in PowerOptLab.jl at revision
`4f417d470c8bff78bd0941658f97030e5ddb7692`:

- `docs/src/ibr/verification.md`: independent physical checks beyond solver status.
- `test/advanced_inverter_tests.jl:196–268`: balanced/unbalanced excitation and
  three-wire zero-neutral invariants; `465–475`: prescribed complex phasors;
  `1262–1295`: comparing SI and PU in physical units.
- `test/inverter_control_tests.jl:416–427,565–573`: reference-angle rotation and
  cyclic relabeling as covariance tests.

The fixtures and analytic pair oracle here are newly authored for BMOPFTools.
No upstream model, controller, fixture or oracle implementation is copied.
PowerOptLab's advanced THREE_LEG model has different mechanisms and rating
semantics; its richer FOUR_LEG/SPLIT_DC SI/PU tests do not establish equivalence
for this model. Only the applicable excitation/verification patterns are reused.
Tests run without PowerOptLab or network access.
