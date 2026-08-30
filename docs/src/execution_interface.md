# JSON execution interface and recipes

BMOPFTools provides a small automation surface for evaluating package-owned
scientific contracts without asking an agent to construct Julia calls or parse
diagnostic prose. The interface is deliberately narrower than the public Julia
API: each supported operation maps to a reviewed domain function and returns a
versioned JSON response.

## First supported operation

From a repository checkout, evaluate the scalar parallel-member contract with:

```sh
bin/bmopf check-contract parallel_member_limit_preservation \
  --source test/fixtures/negative/parallel-rating-outer-relaxation/source.json \
  --target test/fixtures/negative/parallel-rating-outer-relaxation/transformed.json \
  --member-id l1 --member-id l2 --aggregate-id leq --pretty
```

The wrapper activates the repository environment and runs
`scripts/bmopf_cli.jl`. Applications may invoke that Julia script directly if
they already control the environment.

The initial CLI intentionally exposes only
`parallel_member_limit_preservation`. Additional contracts should be promoted
one at a time after their required inputs and mappings have an unambiguous
transport representation.

## Response contract

Every invocation writes one JSON object to standard output. The schema is
`schemas/execution-response.schema.json`. A completed evaluation has:

```json
{
  "schema_version": "0.1.0",
  "operation": "check_contract",
  "status": "failed",
  "package": {"name": "BMOPFTools", "version": "0.1.0"},
  "request": {
    "contract_id": "parallel_member_limit_preservation",
    "parameters": {
      "member_ids": ["l1", "l2"],
      "aggregate_id": "leq",
      "atol": 1e-9,
      "rtol": 1e-8
    }
  },
  "inputs": [
    {"role": "source", "path": "...", "sha256": "..."},
    {"role": "target", "path": "...", "sha256": "..."}
  ],
  "result": {
    "contract_id": "parallel_member_limit_preservation",
    "status": "failed",
    "knowledge_ids": ["PSK-000001"],
    "checked_dimensions": [],
    "unassessed_dimensions": [],
    "findings": [],
    "evidence": {}
  }
}
```

The example is structural; actual checked dimensions, Findings, and evidence
come from the supplied cases. Input hashes bind the runtime evidence to the
files that were evaluated.

The four scientific-contract statuses retain their existing meanings:

- `passed`: every implemented obligation held in the applicable domain;
- `failed`: at least one implemented obligation was violated;
- `inapplicable`: a domain precondition did not hold;
- `indeterminate`: required evidence was absent.

`error` is a separate transport/request status. It indicates that no scientific
contract result was produced. A contract that evaluates to `failed`,
`inapplicable`, or `indeterminate` is still a successfully completed CLI
operation and therefore exits with code zero. Invalid requests exit with code
2; input or execution errors exit with code 1.

Julia callers can obtain the same envelope without starting a subprocess:

```julia
response = execute_contract(
    "parallel_member_limit_preservation",
    source,
    target;
    parameters=Dict(
        "member_ids" => ["l1", "l2"],
        "aggregate_id" => "leq",
    ),
)
```

## Executable recipes

The `recipes/` directory contains small operational companions to the longer
tutorials. Each recipe has machine-readable metadata, a runnable Julia file,
and a short explanation of scope and invalid inferences.

The first recipe is:

```sh
julia --startup-file=no --project=. recipes/parallel_member_limits/recipe.jl
```

It runs the existing minimized `PSK-000001` fixture, asserts the expected
status and Finding code, and prints the execution-response JSON. Recipe records
are generated into `generated/executable_knowledge.jsonl`, including source
hashes, expected status, fixture IDs, and “does not establish” statements.

Recipes do not replace the tutorials. Tutorials explain modelling choices and
misconceptions in context; recipes provide a short, repeatable operation that
agents and CI can execute.

## Interface boundary

The CLI does not retrieve scientific prose, infer mappings, expose arbitrary
Julia evaluation, or contact the companion book. The book remains the authority
for what a PSK statement establishes. This interface reports what BMOPFTools
checked on the supplied models. A future MCP or PowerMCP adapter should expose
the same curated operations and response schema rather than introduce another
execution model.
