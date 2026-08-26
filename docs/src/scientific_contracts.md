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
