# Transformer interoperability witnesses (#393)

These small synthetic fixtures are package-owned and covered by the repository
license. They require no FormulationLab code or external datasets.

The four JSON files isolate raw dictionary leakage/excitation normalization and
loaded transformer equations. They declare the BMOPF schema, a 10 kVA nameplate,
fixed tap 1.06, and deliberately light unbalanced constant-power loads. The Yd
secondary grounds its last delta terminal, reproducing the initialization index
failure before #393. Tests enumerate all three grounded anchors, no anchor,
all six phase permutations, Yd/Dy orientation, and SI/per-unit coordinates.

The four matching DSS files specify independent nominal voltage/power bases,
1% winding resistances, and 4% pairwise short-circuit reactances. The fifth DSS
file, `wye_bank.dss`, supplies the PMD bank witness for legacy three-phase wye
excitation recovery. No impedance is derived from a BMOPFTools primitive.
`transformer_opendss_tests.jl` varies primary tap through 0.95, 1.0 and 1.06 and
excitation through absent and present values. It explicitly maps source terminal
identities and sums repeated center-tap terminal rows/columns.

Primitive tests compare matrices, currents at arbitrary unbalanced voltages,
and terminal complex power. Loaded tests install solid winding neutrals (and a
finite ground on the Yd delta terminal) before solving. They use OpenDSS's
observed source phasors as the BMOPFTools boundary, avoiding an unrelated
comparison between finite-impedance and ideal voltage sources. Nameplate limits
remain present. Independent load-side KCL and winding/energy checks accompany
solver-status assertions. Reconstructed internal currents are inferred, not
independently measured.

Review regressions also vary the wye bank through one, two, and three coils and
numeric/letter neutral labels, checking recovered excitation against OpenDSS's
primitive difference. Empty/unequal coil-tap arrays are tested at the PMD
recovery boundary with zero and nonzero excitation. Solver preparation tests
retain concrete numeric arrays and private matrix ownership while resolving
time series once. Regulator projection tests cover both free arms and mixed
fixed/free arms, followed by a power-flow solve of the pinned snapshot.

Excitation tests distinguish the explicit per-coil exchange representation from
legacy bank totals and legacy n-winding per-coil values. PowerIO tests separately
inspect preserved source text, typed electrical parameters, parser migration,
and missing-rating diagnostics. Unversioned emission must report
`exact_same_format`; that is not evidence of typed electrical completeness.
Test logs record input SHA-256, Julia/PowerIO/OpenDSS versions, and the installed
PowerIO binary SHA-256. They do not infer a Rust revision from a release number.

Run all of this coverage with:

```sh
julia --project=test --startup-file=no -e 'using Test, BMOPFTools, JuMP, Ipopt; const _HAS_JUMP_IPOPT=true; include("test/transformer_interoperability_tests.jl"); include("test/transformer_opendss_tests.jl")'
```

For parser-only checks set `_HAS_JUMP_IPOPT=false` and omit the second include.
The ordinary repository suite includes both files, and CI requires OpenDSS and
Ipopt rather than allowing those oracle checks to be silently skipped.

These are finite package regressions. `PSK-000006` still checks only its declared
winding-incidence/ratio domain; it does not assess leakage or excitation.
`PSK-000013` links the existing solved-state evidence interface without turning
these fixtures into a proof of feasible-set preservation or global optimality.
Unequal-kVA n-winding intake (#356) and automatic regulator controls remain
separate work.
