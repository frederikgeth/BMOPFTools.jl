# BMOPFTools executable recipes

Recipes are short, CI-tested examples for agents and automation. They wrap the
same public Julia APIs documented for human users and produce structured
evidence without copying scientific claims from the companion book.

Each recipe contains:

- `metadata.toml`, which binds scientific recipes to stable contract, PSK, and
  fixture identifiers and binds every recipe to expected Finding identifiers;
- `recipe.jl`, a directly runnable Julia example; and
- `README.md`, which explains inputs, outputs, scope, and invalid inferences.

Run a recipe from the repository root with its documented command. Longer
tutorials under `docs/src/` remain the pedagogical source; recipes are compact
operational companions rather than replacements for those tutorials.

Current recipes:

- `analyze_case`: parses and analyzes the tutorial network, demonstrating that
  a completed operation can still contain Findings that need triage;
- `explain_finding`: looks up one stable package Finding code in the generated
  offline registry without diagnosing a case or inventing a repair;
- `parse_case`: inventories a deliberately incomplete document after supported
  ingest migration, demonstrating that parse completion is not schema validity;
- `parallel_member_limits`: checks the `PSK-000001` scalar member-limit
  counterexample;
- `neutral_ground_reference`: checks the `PSK-000002` neutral-continuity and
  grounding-relation counterexample, complementing the pedagogical grounding
  tutorial;
- `verify_solution`: independently profiles a result that says
  `LOCALLY_SOLVED` but violates its case's declared voltage bound, complementing
  the “Trust but verify” tutorial.
