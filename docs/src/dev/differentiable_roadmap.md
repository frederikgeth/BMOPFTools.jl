# Roadmap: parameterized and differentiable OPF extensions

This roadmap tracks the work needed to make the embedded IVR-EN engine a stable
network-model builder for downstream research packages such as PowerOptLab.jl.
The target is a **DiffOpt-compatible parameterized JuMP model-construction
interface**, not a bilevel solver or a promise that every OPF solution map is
globally differentiable.

## Compatibility contract

Throughout this work:

- `solve_opf`, `solve_pf`, and `solve_feasibility_opf` keep their current result
  dictionaries and default numerical behaviour;
- the staged `build_opf_model` → `enforce_kcl!` → `extract_result` path remains
  the canonical integration seam;
- `model_hook!` and `solution_hook!` remain supported;
- parsing, validation, analysis, conversion, and reporting remain independent
  of JuMP, Ipopt, and DiffOpt;
- BMOPFTools does not take ownership of downstream bilevel semantics, automatic
  differentiation rules, outer solvers, or discrete relaxations.

## Milestones

### M1 — Stable context substrate

- [x] Public model/network/base accessors.
- [x] Stable, extensible `OpfModelKey` identifiers.
- [x] Variable, expression, and constraint registries.
- [x] Namespaced downstream extension state.
- [x] Explicit context lifecycle and one-shot KCL finalization.
- [x] Supported terminal-current injection helper.
- [x] Semantic convenience constructors for every native variable family.
- [x] Public result-extractor and objective-term registries.

### M2 — Composable construction stages

- [x] Separate initialization, variable creation, device physics, operational
      limits, objective assembly, and KCL finalization into coarse public stages.
- [x] Preserve `build_opf_model` as the standard recipe wrapper.
- [x] Add a build manifest recording formulation choices and component ownership.
- [x] Make stage ordering deterministic and reject invalid lifecycle transitions.

### M3 — Replaceable device formulations

- [x] Define a typed device-builder protocol owned by a build specification.
- [x] Allow a downstream package to replace a whole device family without native
      constraints being stamped as well.
- [x] Support mixed ownership, such as one custom IBR with other IBRs native.
- [x] Route custom-device KCL, losses, powers, results, and profiling through
      public registration helpers.
- [x] Provide a miniature external-package fixture that uses no private symbols.

### M4 — Parameter binding and coefficient providers

The core protocol is complete. Native coefficient families will be opted in
incrementally as research cases require them; custom builders can consume every
typed category now without changing the engine internals.

Native load coefficients, generator and IBR P/Q availability/limits, Volt-var
and Volt-watt curve points, and line R/X matrix entries are provider-aware. The
DiffOpt gate covers a native equality coefficient, active inequalities,
controller coefficients, and parameterized network physics.

- [x] Bind caller-created JuMP parameters to existing native decisions such as
      continuous transformer taps.
- [x] Add parameter identity, snapshot/scenario scope, aliases, and one-to-many
      mappings.
- [x] Record SI-to-working-unit transformations and apply their chain rule.
- [x] Add a coefficient-provider protocol for scalar loads, availability,
      setpoints, costs, and limits.
- [x] Extend parameterization to controller coefficients and, on demand, matrix
      physics coefficients such as impedances.
- [x] Reject structural parameters (topology, terminal maps, dimensions) unless
      the model is rebuilt.

### M5 — DiffOpt compatibility gate

- [x] Add an isolated DiffOpt integration-test environment (not a runtime dependency).
- [x] Run that environment as a dedicated CI job on the latest Julia release.
- [x] Build the unmodified physics into `DiffOpt.nonlinear_diff_model`.
- [x] Differentiate a tiny analytic feeder with respect to a linked parameter.
- [x] Check forward sensitivities against a central finite difference on an
      analytic feeder.
- [x] Check the forward/reverse adjoint identity on an analytic feeder.
- [x] Check SI/per-unit derivative scaling and repeated parameter updates.
- [x] Detect and report failed solves, singular KKT systems, and active-set
      transition cases without returning an unqualified gradient.

### M6 — Research diagnostics and provenance

- [x] Expose semantic primal, constraint, dual, and objective references while
      preserving JuMP/MOI result indexing, shapes, units, and dual signs.
- [x] Record active-set signatures, normalized margins, and weakly-active
      constraints with explicit tolerances.
- [x] Record solver/status metadata, residual summaries, smoothing,
      initialization coverage, parameter maps, coefficient ownership, and KKT
      diagnostics in a versioned JSON-compatible provenance snapshot.
- [x] Record explicit downstream regularization and differentiability
      declarations and separate deterministic working-data, model-structure,
      parameter-state, and declaration hashes without inferring undeclared
      research choices.
- [x] Add a baseline differentiability-capability report for lifecycle, failed
      solves, discrete variables, unused providers, and inequality qualifications.
- [x] Add an opt-in checked KKT factorization that refuses singular or
      near-singular derivative systems and records its diagnostic.
- [x] Extend the report to identify remaining nonsmooth operators, dynamic
      branching, and formulation-specific unsupported parameter locations.
- [x] Keep JVP/VJP operations in downstream differentiation packages rather than
      prescribing a dense-Jacobian API here.

## Acceptance gates

The capability is ready for downstream research use when all of the following
hold:

1. The fused and staged default OPF paths remain numerically equivalent.
2. A mock external package replaces an IBR using only documented public APIs.
3. Custom injections participate automatically in KCL and solution profiling.
4. Parameter updates neither rebuild nor grow the JuMP model.
5. DiffOpt derivatives agree with finite differences away from active-set changes.
6. Forward and reverse sensitivities satisfy the adjoint identity in SI and
   per-unit modes.

## Test strategy

The test programme is layered: structural registry/lifecycle tests, tiny analytic
physics tests, default-path equivalence tests, parameter/scaling tests, DiffOpt
forward/reverse tests, a real mock downstream package, fresh-process extension
load-order tests, and seeded randomized small feeders. Active-set transitions,
degenerate KKT systems, shared multi-period parameters, custom terminal labels,
floating neutrals, delta devices, ideal couplings, and AC/DC models are explicit
edge-case families rather than incidental coverage.
