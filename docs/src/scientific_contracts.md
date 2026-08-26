# Scientific contracts

BMOPFTools scientific contracts turn a scoped knowledge statement into an executable decision with structured evidence. The scientific statement and its evidence remain owned by the sibling `multi-graph-book`; this package owns the code-level applicability checks, result status, Findings, fixtures, and export metadata. See the repository-root `ARCHITECTURE.md` for the stable boundary.

## Parallel member-current limits

[`check_parallel_member_limit_preservation`](@ref) implements the scalar, fixed-linear, series-only portion of `PSK-000001`. It requires an explicit mapping because a reduced aggregate cannot reveal discarded member identity.

```julia
using BMOPFTools

fixture = joinpath(
    pkgdir(BMOPFTools), "test", "fixtures", "negative",
    "parallel-rating-outer-relaxation",
)
source = parse_bmopf(joinpath(fixture, "source.json"))
target = parse_bmopf(joinpath(fixture, "transformed.json"))

result = check_parallel_member_limit_preservation(
    source,
    target;
    member_ids = ["l1", "l2"],
    aggregate_id = "leq",
)

result.status                 # :failed
result.knowledge_ids          # ["PSK-000001"]
result.findings[1].code       # "W.CONTRACT.PARALLEL_MEMBER_LIMIT_LOSS"
result.evidence["witness"]   # 15 V; member currents 150 A and 15 A
```

The check separates two questions. First it tests whether the target aggregate admittance preserves the summed source terminal relation. Then it compares the scalar voltage-drop region implied by every member rating with the target aggregate-rating region. In the negative fixture, a naïve 200 A aggregate is an outer relaxation; the exact scalar target rating is 110 A.

## Neutral, ground, and reference relations

[`check_neutral_ground_reference_preservation`](@ref) implements the initial
representation-level portion of `PSK-000002`. It requires an explicit one-to-one
bus mapping because a transformed model cannot recover discarded neutral identity
or grounding declarations by inspection.

```julia
using BMOPFTools

fixture = joinpath(
    pkgdir(BMOPFTools), "test", "fixtures", "negative",
    "neutral-ground-reference-conflation",
)
source = parse_bmopf(joinpath(fixture, "source.json"))
target = parse_bmopf(joinpath(fixture, "transformed.json"))

result = check_neutral_ground_reference_preservation(
    source,
    target;
    bus_mapping = Dict("source" => "source", "load" => "load"),
)

result.status                    # :failed
[finding.code for finding in result.findings]
# ["E.CONTRACT.NEUTRAL_CONTINUITY_MISMATCH",
#  "E.CONTRACT.GROUND_REFERENCE_RELATION_MISMATCH"]
```

The source fixture has an explicit phase/neutral feeder, a perfectly grounded
source neutral, and a finite 0.1 S grounding shunt at the load neutral. The
unsafe target removes neutral continuity and replaces the finite customer-end
grounding relation with a perfect local ground. Those changes are distinct even
though the simple two-bus graph and the label `n` remain.

The check compares explicit neutral identity, pairwise neutral continuity, and
the incidence of perfect grounds, scalar neutral-only grounding shunts, and
voltage-source references. A pass is not an electrical-equivalence certificate:
terminal equations, explicit-earth behavior, soil and electrode models,
grounding-asset identity and state, fault current, touch voltage, and protection
operation remain explicitly unassessed. Coupled multiconductor grounding models
return `:inapplicable`; missing mapped evidence returns `:indeterminate`.

## Claimed-feasible solution validity

[`check_claimed_solution_validity`](@ref) implements the initial executable
portion of `PSK-000003`. It treats an accepted solver termination status as a
precondition for inspecting a candidate solution, never as proof that the
returned values satisfy the study model.

```julia
using BMOPFTools
using JSON3

fixture = joinpath(
    pkgdir(BMOPFTools), "test", "fixtures", "negative",
    "claimed-feasible-invalid-solution",
)
network = parse_bmopf(joinpath(fixture, "network.json"))
solver_result = JSON3.read(
    read(joinpath(fixture, "claimed-solved-result.json"), String),
    Dict{String,Any},
)

result = check_claimed_solution_validity(network, solver_result)

result.status              # :failed
result.findings[1].code    # "E.CONTRACT.CLAIMED_FEASIBLE_SOLUTION_INVALID"
result.evidence["blocking_solution_findings"][1]["code"]
# "E.SOL.VOLT_VIOLATION"
```

The fixture result is labelled `LOCALLY_SOLVED`, but its reported 180.5 V
terminal magnitude violates the network's declared 200--260 V range. The
contract reuses [`profile_solution`](@ref), retains the underlying `E.SOL`
evidence, and rejects the tempting inference from status alone.

The initial contract requires numeric `vr`, `vi`, and `vm` values for every
declared bus terminal. It checks the complete result tree for non-finite values
and recomputes declared bus magnitude, sequence, and angle-difference limits.
Missing status or terminal data is `:indeterminate`; a status that does not
claim feasibility is `:inapplicable`.

A pass remains deliberately incomplete. Network-equation residuals, branch and
device limits, load-model residuals, power balance, objective optimality,
local/global guarantees, and solver derivative quality are unassessed by this
initial contract even though other BMOPFTools profiling paths already cover
parts of that larger validation problem.

## Load connection voltage bases

[`check_load_voltage_base_consistency`](@ref) implements the initial executable
portion of `PSK-000004`. It checks voltage-dependent WYE and DELTA load anchors
against the nominal phase-to-neutral bus base propagated by BMOPFTools from
declared voltage sources. WYE uses that base directly; DELTA uses the
line-to-line base, `sqrt(3)` times larger.

```julia
using BMOPFTools

fixture = joinpath(
    pkgdir(BMOPFTools), "test", "fixtures", "negative",
    "load-voltage-base-mismatch",
)
network = parse_bmopf(joinpath(fixture, "wrong-base-network.json"))
result = check_load_voltage_base_consistency(network; load_ids=["delta_zip"])

result.status                                      # :failed
result.findings[1].code                            # "E.CONTRACT.LOAD_VOLTAGE_BASE_MISMATCH"
result.evidence["loads"]["delta_zip"]["ratios"] # [1 / sqrt(3)]
```

The fixture source is 230 V phase-to-neutral. Its DELTA ZIP load incorrectly
uses 230 V as `v_nom`, instead of the 398.37 V line-to-line anchor. The contract
uses the same connection-coordinate conversion and default 0.8--1.25 ratio
band as ordinary `W.LOAD.VNOM_MISMATCH` validation.

A pass is deliberately declaration-relative. It does not validate the source
or transformer values used during propagation, the terminal map, load-law
coefficients, units, solved operating voltage, network equations, or equipment
limits. Missing required evidence is `:indeterminate`; constant-power or
unsupported connection cases are `:inapplicable`.

## Adjustable transformer tap domains

[`check_transformer_tap_domain_preservation`](@ref) implements the initial
continuous scalar portion of `PSK-000005`. It compares the complete tap decision
interval on one explicitly mapped two-winding isolating transformer. In the
BMOPFTools data model, omitting `tap_min` and `tap_max` leaves a fixed tap at
`tap` (default `1.0`); it does not retain an implicit adjustable decision.

```julia
using BMOPFTools

fixture = joinpath(
    pkgdir(BMOPFTools), "test", "fixtures", "negative",
    "transformer-tap-domain-loss",
)
source = parse_bmopf(joinpath(fixture, "source.json"))
frozen = parse_bmopf(joinpath(fixture, "transformed.json"))

result = check_transformer_tap_domain_preservation(
    source,
    frozen;
    source_subtype = "single_phase",
    source_id = "tx",
)

result.status                                  # :failed
result.findings[1].code                        # "E.CONTRACT.TRANSFORMER_TAP_DOMAIN_LOSS"
result.evidence["classification"]             # "inner_restriction"
result.evidence["source_domain"]              # [0.95, 1.05] plus start
result.evidence["target_domain"]              # singleton 1.0
```

The exact target fixture retains `[0.95, 1.05]` and passes even though its
admissible start differs from the source. This distinguishes a decision domain
from an initial guess. The check classifies narrower, wider, partially
overlapping, and disjoint target intervals and supplies a tap admitted by only
one side as its mismatch witness.

Applicability is intentionally strict: source and target must have the same
supported subtype and identical non-tap declarations. A pass establishes only
mapped base-factor identity, start admissibility, and equality of the continuous
tap interval. It does not establish pointwise transformer equations,
tap-dependent losses, discrete positions, coupling, automatic-control behavior,
network feasible-set or objective equality, the optimal tap, or solver
guarantees. Those dimensions remain explicit follow-on contracts.

## Transformer winding conventions

[`check_transformer_winding_convention_preservation`](@ref) implements the
initial compact-serialization portion of `PSK-000006`. It checks whether one
fixed-tap `single_phase`, `wye_delta`, or `delta_wye` transformer retains its
mapped winding sides, ordered terminal-to-coil incidence, positive winding
reference voltages, and fixed effective coil ratio.

```julia
using BMOPFTools

fixture = joinpath(
    pkgdir(BMOPFTools), "test", "fixtures", "negative",
    "transformer-winding-role-swap",
)
source = parse_bmopf(joinpath(fixture, "source.json"))
swapped = parse_bmopf(joinpath(fixture, "transformed.json"))

result = check_transformer_winding_convention_preservation(
    source,
    swapped;
    source_subtype = "wye_delta",
    source_id = "tx",
    target_id = "tx_equiv",
    bus_mapping = Dict("primary" => "primary", "secondary" => "secondary"),
)

result.status                      # :failed
result.findings[1].code
# "E.CONTRACT.TRANSFORMER_WINDING_INCIDENCE_MISMATCH"
result.evidence["classification"] # "winding_incidence_mismatch"
```

The negative fixture swaps only `bus_from` and `bus_to`. That operation would
be harmless for the reference arrow of a symmetric ordinary edge, but not for
a transformer record: the subtype assigns WYE and DELTA winding roles, and the
ordered terminal maps define which bus-terminal differences form each coil.
The fixture therefore attaches the same compact winding relations to the wrong
mapped buses. Its exact companion target changes only the transformer ID.

The bus mapping is mandatory because a target cannot recover source identity
after a transformation. Terminal labels are stable by default; pass
`terminal_mapping=Dict("a"=>"1", ...)` for a bijective relabelling. Adjustable
taps return `:inapplicable` and belong to the tap-domain contract. Subtype-
changing or fully reversed transformer encodings are also outside this initial
compact contract: they require a complete typed transformation, not a guessed
field swap.

A pass is narrow. Leakage, excitation-shunt placement and value, grounding,
tap domains, ratings, the complete terminal factor, controls, network feasible
sets, objectives, and solver evidence remain unassessed. In particular, this
check complements the package's `transformer_yprim` and OPF/Yprim consistency
tests; it does not replace them.

## Decision-preservation manifests

[`check_decision_preservation_manifest`](@ref) implements the declaration-
completeness portion of `PSK-000007`. It applies only to version `0.1.0`
manifests that explicitly claim exact `decision_equivalence`; narrower
terminal, inner, outer, or approximate claims return `:inapplicable` instead
of being mislabeled as failures.

```julia
using BMOPFTools
using JSON3

fixture = joinpath(
    pkgdir(BMOPFTools), "test", "fixtures", "negative",
    "decision-manifest-terminal-only",
)
manifest = JSON3.read(
    read(joinpath(fixture, "transformed.json"), String),
    Dict{String,Any},
)

result = check_decision_preservation_manifest(manifest)
result.status                      # :failed
result.findings[1].code
# "E.CONTRACT.DECISION_MANIFEST_EVIDENCE_GAP"
result.evidence["missing_dimensions"]
# admissible domain, observations, constraints, decisions, objective, recovery
```

An exact decision-equivalence manifest must name its source and target and
close seven dimensions: admissible domain, terminal behavior, observations,
constraints, decision variables, objective, and recovery. Each dimension is
either `verified` with one or more `evidence_ids`, `not_required` with a
justification, `not_preserved`, or `unassessed`. The last two dispositions
contradict an exact decision-equivalence claim; omitted dimensions and missing
supporting references create an evidence gap.

The negative fixture deliberately supplies a verified terminal-relation
reference and nothing else. Its evidence-complete companion declares every
required disposition and passes. That pass is administrative, not scientific:
BMOPFTools has checked the manifest's completeness and internal claim boundary,
but has not authenticated the evidence IDs, proved the maps correct, compared
source and target feasible sets or objectives, or established optimization or
solver equivalence. Use narrower case-specific contracts—such as the parallel
member-limit or transformer tap-domain checks—to produce actual evidence for
individual dimensions.

## Result statuses

[`ScientificContractResult`](@ref) uses four statuses:

| Status | Meaning |
|---|---|
| `:passed` | Every declared checked dimension passed within tolerance |
| `:failed` | An in-domain preservation condition was disproved |
| `:inapplicable` | The case lies outside the declared model domain |
| `:indeterminate` | Required mapped components or ratings are unavailable |

A pass is deliberately narrow. Each contract names its checked and unassessed
dimensions in the result and the executable registry. The parallel contract
checks `terminal_behavior` and `scalar_member_current_limits`; the neutral
contract checks representation relations only. Neither result licenses an
inference about a dimension it does not name as checked.

Use [`contract_result_to_dict`](@ref) for deterministic JSON-ready serialization. Finding codes and their meanings are listed in the [Finding-code reference](findings.md).

## Executable discovery export

`knowledge/executable.toml` is the package-owned registry for executable contracts and Findings. The generator validates its source paths, exported API, fixture metadata, Finding definitions, and source hashes, then writes:

- `generated/executable_knowledge.jsonl`, containing contract, API, Finding, and fixture records; and
- `generated/executable-knowledge-manifest.json`, containing package identity, record counts, corpus hash, and source hashes.

Check that committed records are current with:

```bash
python3 scripts/generate_executable_knowledge.py --check
```

The sibling book pins this export in its federated pair manifest. That link lets book retrieval expose an implemented guardrail without copying package semantics into the scientific registry.
