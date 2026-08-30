# JSON execution interface and recipes

BMOPFTools provides a small automation surface for evaluating package-owned
scientific contracts and running ordinary case analysis without asking an agent
to construct Julia calls or parse diagnostic prose. The interface is
deliberately narrower than the public Julia API: each supported operation maps
to a reviewed package function and returns a versioned JSON response.

## Supported contracts

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

The second curated route checks explicit neutral, ground, and reference
relations with a declared bus mapping:

```sh
bin/bmopf check-contract neutral_ground_reference_preservation \
  --source test/fixtures/negative/neutral-ground-reference-conflation/source.json \
  --target test/fixtures/negative/neutral-ground-reference-conflation/transformed.json \
  --bus-map source=source --bus-map load=load --pretty
```

`--bus-map` is repeatable and uses `SOURCE_BUS=TARGET_BUS`. BMOPFTools does not
infer this mapping from matching names: explicit mapping is part of the
scientific request whenever the target alone cannot establish source identity.

The CLI intentionally exposes only these two reviewed contracts. They are
registered through package-owned adapters with explicit parameter allowlists;
additional contracts should be promoted one at a time after their required
inputs and mappings have an unambiguous transport representation.

## Analyze one case

The first non-contract route parses one BMOPF JSON file and runs the same
[`analyze`](@ref) battery used throughout the tutorials:

```sh
bin/bmopf analyze-case --input examples/lv1_14bus.json --pretty
```

For a time-series case, add `--time-index N` to select the snapshot. The
equivalent Julia entry point is `execute_analysis(net; t_index=1)`.

An analysis response has operation `analyze_case`, status `completed`, and the
structured `SummaryReport` under `result`: severity counts, stable result
sections, and full Finding records. `completed` means that the requested
analysis ran. It does not mean the case is clean, solver-ready, feasible, or
scientifically validated; ERROR and WARNING Findings describe the case and do
not turn transport status into `error`.

## Verify one solution

The solution route reads a BMOPF case and a compatible result JSON, then runs
the existing [`profile_solution`](@ref) checks without invoking a solver:

```sh
bin/bmopf verify-solution \
  --case test/fixtures/negative/claimed-feasible-invalid-solution/network.json \
  --result test/fixtures/negative/claimed-feasible-invalid-solution/claimed-solved-result.json \
  --pretty
```

Julia callers use `execute_solution_verification(net, result; t_index=1)`. The
structured result preserves solver metadata, severity counts, solution and
optimization summaries, and complete Finding records. Solver termination,
operation status, and Finding severity remain separate: a `LOCALLY_SOLVED`
result can produce `E.SOL.*` Findings while the verification operation itself
correctly reports `completed`.

## Response contract

Every invocation writes one JSON object to standard output. The schema is
`schemas/execution-response.schema.json`. A completed evaluation has:

```json
{
  "schema_version": "0.3.0",
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
contract result or analysis report was produced. A contract that evaluates to `failed`,
`inapplicable`, or `indeterminate` is still a successfully completed CLI
operation and therefore exits with code zero. Invalid requests exit with code
2; input or execution errors exit with code 1. For `analyze_case` and
`verify_solution`, `completed` is the only non-error operation status.

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

For the neutral/ground/reference route, replace the parameters with:

```julia
parameters = Dict(
    "bus_mapping" => Dict("source" => "source", "load" => "load"),
)
```

## Executable recipes

The `recipes/` directory contains small operational companions to the longer
tutorials. Each recipe has machine-readable metadata, a runnable Julia file,
and a short explanation of scope and invalid inferences.

The first four recipes are:

```sh
julia --startup-file=no --project=. recipes/analyze_case/recipe.jl
julia --startup-file=no --project=. recipes/parallel_member_limits/recipe.jl
julia --startup-file=no --project=. recipes/neutral_ground_reference/recipe.jl
julia --startup-file=no --project=. recipes/verify_solution/recipe.jl
```

The analysis recipe uses the same small network as several tutorials and makes
their triage lesson executable: a completed report can still contain warnings
and readiness disclosures. It intentionally carries no PSK identity because it
demonstrates ordinary package analysis rather than a scientific preservation
claim. The two contract recipes run the existing minimized `PSK-000001` and
`PSK-000002` fixtures, assert
their expected statuses and Finding codes, and print execution-response JSON.
The neutral recipe is the compact operational companion to the pedagogical
[grounding tutorial](tutorial_grounding.md). Recipe records are generated into
`generated/executable_knowledge.jsonl`, including source hashes, expected
status, fixture IDs, and “does not establish” statements.

The solution-verification recipe reuses the minimized claimed-feasible result
behind the `PSK-000003` contract, but it runs ordinary `profile_solution`
behavior rather than the scientific contract. It therefore carries no PSK
identity in its executable metadata and demonstrates the tutorial's central
misconception directly: solver status does not replace independent checks.

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
