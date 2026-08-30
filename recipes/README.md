# BMOPFTools executable recipes

Recipes are short, CI-tested examples for agents and automation. They wrap the
same public Julia APIs documented for human users and produce structured
evidence without copying scientific claims from the companion book.

Each recipe contains:

- `metadata.toml`, which binds the recipe to stable contract, PSK, fixture, and
  Finding identifiers;
- `recipe.jl`, a directly runnable Julia example; and
- `README.md`, which explains inputs, outputs, scope, and invalid inferences.

Run a recipe from the repository root with its documented command. Longer
tutorials under `docs/src/` remain the pedagogical source; recipes are compact
operational companions rather than replacements for those tutorials.
