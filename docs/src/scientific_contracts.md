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

## Result statuses

[`ScientificContractResult`](@ref) uses four statuses:

| Status | Meaning |
|---|---|
| `:passed` | Every declared checked dimension passed within tolerance |
| `:failed` | An in-domain preservation condition was disproved |
| `:inapplicable` | The case lies outside the declared model domain |
| `:indeterminate` | Required mapped components or ratings are unavailable |

A pass is deliberately narrow. This contract checks `terminal_behavior` and `scalar_member_current_limits`. It leaves member identity, independent outage state, switching decisions, asset provenance, individual measurements, and protection quantities explicitly unassessed. Multiconductor, shunted, singular, and state-dependent cases are not inferred from the scalar result.

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
