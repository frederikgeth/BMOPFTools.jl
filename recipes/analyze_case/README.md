# Analyze and triage one case

Run from the repository root:

```sh
julia --startup-file=no --project=. recipes/analyze_case/recipe.jl
```

The recipe parses `examples/lv1_14bus.json`, runs BMOPFTools' standard analysis
battery, checks three stable Finding codes, and prints a schema-valid execution
response. The equivalent CLI call is:

```sh
bin/bmopf analyze-case --input examples/lv1_14bus.json --pretty
```

This compact example is inspired by the pedagogical findings-triage and
nameplate tutorials. Its central misconception callout is that operation status
and case quality are different axes: `completed` means the analyzer ran, not
that the case is clean. In particular, `W.CONN.DANGLING` deserves a documented
triage decision, while `I.PRE.NO_VOLT_BOUNDS` discloses that the imported case
still lacks a solver-ready operating envelope. Warnings should not be repaired
automatically merely to make a report quiet.

The recipe does not run a solver, validate feasibility, or establish a
scientific preservation claim. It intentionally carries no PSK identifier;
the book owns scientific claims, while this package-owned example demonstrates
ordinary analysis behavior and structured Findings.
