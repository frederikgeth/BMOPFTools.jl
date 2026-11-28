# JSON execution interface and recipes

BMOPFTools provides a small automation surface for running ordinary case analysis
and evaluating package-owned scientific contracts without asking an agent to
construct Julia calls or parse diagnostic prose. The interface is deliberately
narrower than the public Julia API: each operation maps to a reviewed package
function and returns a versioned JSON response.

| Operation | CLI (`bin/bmopf …`) | Julia | MCP tool |
|---|---|---|---|
| Parse and inventory a case | `parse-case` | `execute_case_parse` | `bmopf_parse` |
| Analyze a case | `analyze-case` | `execute_analysis` | `bmopf_analyze` |
| Verify a solution | `verify-solution` | `execute_solution_verification` | `bmopf_verify_solution` |
| Explain a Finding code | `explain-finding` | `execute_finding_explanation` | `bmopf_explain_finding` |
| Check parallel-member limit preservation | `check-contract parallel_member_limit_preservation` | `execute_contract` | `bmopf_check_parallel_member_limits` |
| Check neutral/ground/reference preservation | `check-contract neutral_ground_reference_preservation` | `execute_contract` | `bmopf_check_neutral_ground_reference` |

The `bin/bmopf` wrapper activates the repository environment and runs
`scripts/bmopf_cli.jl`; applications that already control the environment may
invoke that script directly. For every operation, a `completed` status means the
operation ran, not that the case is clean, valid, solver-ready or feasible: the
Findings and contract statuses in the response carry that information (see the
[response contract](#Response-contract)).

## Parse and inventory one case

The parse-only route decodes a BMOPF JSON document, applies the same supported
forward migrations and terminal normalization as [`parse_bmopf`](@ref), and
returns a small intake inventory:

```sh
bin/bmopf parse-case --input recipes/parse_case/input.json --pretty
```

Julia callers use `execute_case_parse(net)` after `parse_bmopf`. The result
reports document identity, known component counts, time-series detection,
migration notes, and terminal-coercion evidence. It runs no validation: use
`analyze-case` for schema, domain and readiness checks.

## Analyze one case

This route parses one BMOPF JSON file and runs the same [`analyze`](@ref) battery
used throughout the tutorials:

```sh
bin/bmopf analyze-case --input recipes/analyze_case/input.json --pretty
```

For a time-series case, add `--time-index N` to select the snapshot. The
equivalent Julia entry point is `execute_analysis(net; t_index=1)`.

An analysis response has operation `analyze_case`, status `completed`, and the
structured `SummaryReport` under `result`: severity counts, stable result
sections, and full Finding records. ERROR and WARNING Findings describe the case;
they do not turn the operation status into `error`.

### Suppressing geospatial analysis

Spatial analysis runs by default when bus coordinate fields are present. Use
`execute_analysis(net; spatial_enabled=false)`, CLI `analyze-case --no-spatial`,
or the MCP `bmopf_analyze` argument `"spatial_enabled": false` to skip it.
The Boolean defaults to `true` and is recorded in response request parameters.
Suppression leaves other analyses active and returns an explicit spatial
`inapplicable` / `disabled` record, with `analysis_performed=false`.
The analysis recipe exercises this opt-out on a synthetic case with coordinates.

## Verify one solution

The solution route reads a BMOPF case and a compatible result JSON, then runs
the [`profile_solution`](@ref) checks without invoking a solver:

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

## Explain one Finding code

The package catalog is also available as a deterministic offline lookup:

```sh
bin/bmopf explain-finding E.SOL.VOLT_VIOLATION --pretty
```

Julia callers use `explain_finding(code)` for the catalog entry alone or
`execute_finding_explanation(code)` for the versioned execution envelope. The
result contains canonical severity, namespace, catalog section, meaning,
documentation hash, and any links to executable contracts and scientific
references. It does not inspect a case, infer a root cause, or recommend a repair.

For a Finding already returned by Julia analysis, `explain_finding(finding)`
also returns its serialized `instance` and recorded `interpretation`, or
`nothing` for interpretation when none was supplied. Provenance interpretations
include hypotheses and suggested checks that an automated consumer can use for
review. This Julia overload does not change the code-only CLI/MCP request or
response; analysis JSON already carries the same context in Finding detail.

The registry is generated from the complete [Finding-code reference](findings.md)
and checked against `schemas/finding-registry.schema.json`. External PowerIO
conversion codes such as `EMIT.*` are refused explicitly because their meanings
belong to PowerIO's catalog.

## Scientific contracts

A scientific contract checks that a model transformation (a source case and a
transformed target) preserves a stated property. Each contract links to a stable
`PSK-*` statement in the companion book *What Power-Network Models Preserve*,
which owns the scientific claim and its evidence; BMOPFTools owns the executable
check. From a repository checkout, evaluate the scalar parallel-member contract
with:

```sh
bin/bmopf check-contract parallel_member_limit_preservation \
  --source test/fixtures/negative/parallel-rating-outer-relaxation/source.json \
  --target test/fixtures/negative/parallel-rating-outer-relaxation/transformed.json \
  --member-id l1 --member-id l2 --aggregate-id leq --pretty
```

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

The CLI exposes only these two contracts, through adapters with explicit
parameter allowlists. The other contracts in the
[scientific-contract reference](scientific_contracts.md) are available from Julia.

## Response contract

Every invocation writes one JSON object to standard output. The schema is
`schemas/execution-response.schema.json`. A completed evaluation has:

```json
{
  "schema_version": "0.6.0",
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

The four scientific-contract statuses are:

- `passed`: every implemented obligation held in the applicable domain;
- `failed`: at least one implemented obligation was violated;
- `inapplicable`: a domain precondition did not hold;
- `indeterminate`: required evidence was absent.

`error` is a separate transport/request status. It indicates that no scientific
contract result or analysis report was produced. A contract that evaluates to `failed`,
`inapplicable`, or `indeterminate` is still a successfully completed CLI
operation and therefore exits with code zero. Invalid requests exit with code
2; input or execution errors exit with code 1. For `parse_case`, `analyze_case`,
`verify_solution`, and `explain_finding`, `completed` is the only non-error
operation status.

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

The six recipes are:

```sh
julia --startup-file=no --project=. recipes/analyze_case/recipe.jl
julia --startup-file=no --project=. recipes/explain_finding/recipe.jl
julia --startup-file=no --project=. recipes/parse_case/recipe.jl
julia --startup-file=no --project=. recipes/parallel_member_limits/recipe.jl
julia --startup-file=no --project=. recipes/neutral_ground_reference/recipe.jl
julia --startup-file=no --project=. recipes/verify_solution/recipe.jl
```

The analysis recipe uses the same small network as several tutorials and makes
their triage lesson executable: a completed report can still contain warnings
and readiness disclosures. This demonstrates ordinary package analysis, not
model preservation. The parallel-member-limit and neutral/ground-reference
recipes run their minimized fixtures, assert
their expected statuses and Finding codes, and print execution-response JSON.
The neutral recipe is the compact operational companion to the pedagogical
[grounding tutorial](tutorial_grounding.md). Recipe records are generated into
`generated/executable_knowledge.jsonl`, including source hashes, expected
status, fixture IDs, and “does not establish” statements.

The solution-verification recipe reuses the minimized claimed-feasible result
used by the claimed-solution-validity check. It runs ordinary
`profile_solution` behavior and demonstrates the tutorial's central lesson:
solver status does not replace independent checks.

The Finding-explanation recipe looks up that same `E.SOL.VOLT_VIOLATION` code
without inspecting the result. It demonstrates the boundary between a
catalog meaning and case-specific evidence; it does not turn the code into
a guessed cause or repair.

The parse recipe uses a deliberately incomplete document with a legacy load
model. Ingest succeeds and records the normalization, while a separate CI
assertion requires `E.SCHEMA.REQUIRED`. That executable contrast preserves the
intake tutorial's core boundary: successful parsing is not successful
validation.

Recipes do not replace the tutorials. Tutorials explain modeling choices and
misconceptions in context; recipes provide a short, repeatable operation that
agents and CI can execute.

## MCP stdio adapter

`bin/bmopf-mcp` exposes the same operations to local MCP clients (tool names in
the table at the top of this page). It is a transport adapter, not another
execution layer: every successful tool call returns the `0.6.0` execution
envelope as `structuredContent`, while tool failures return a schema-valid
execution error with MCP `isError = true`.

The server also exposes `bmopf://execution/manifest` and
`bmopf://execution/response-schema` as read-only resources.

Run the newline-delimited MCP stdio server from any directory with:

```sh
/absolute/path/to/BMOPFTools.jl/bin/bmopf-mcp
```

Input paths are read-only and restricted to the repository checkout by
default. To allow case and result files elsewhere, set
`BMOPFTOOLS_MCP_ALLOWED_ROOTS` to an OS path-separator-delimited list of
directories. Existing files are resolved through symlinks before containment is
checked.

Register it in any MCP client as a stdio server with that command and, if
needed, the `BMOPFTOOLS_MCP_ALLOWED_ROOTS` environment variable. For example,
with Claude Code or Codex:

```sh
claude mcp add --transport stdio \
  --env BMOPFTOOLS_MCP_ALLOWED_ROOTS=/absolute/path/to/BMOPFTools.jl:/absolute/path/to/cases \
  bmopftools -- /absolute/path/to/BMOPFTools.jl/bin/bmopf-mcp
```

```sh
codex mcp add bmopftools \
  --env BMOPFTOOLS_MCP_ALLOWED_ROOTS=/absolute/path/to/BMOPFTools.jl:/absolute/path/to/cases \
  -- /absolute/path/to/BMOPFTools.jl/bin/bmopf-mcp
```

Desktop clients (Claude Desktop, ChatGPT desktop) take the same command and
environment variable in their MCP server settings; see each client's
documentation.

The adapter follows standard MCP tool/resource conventions and can run
alongside the power-system servers collected by
[PowerMCP](https://github.com/Power-Agent/PowerMCP). It is not bundled with, or
a runtime dependency of, the `powermcp` package.

## Interface boundary

Neither the CLI nor the MCP adapter exposes arbitrary Julia evaluation, invokes a
solver, infers source-to-target mappings, or retrieves scientific prose. They
report what BMOPFTools checked on the supplied models; the companion book remains
the authority for the scope and evidence behind its scientific statements.
