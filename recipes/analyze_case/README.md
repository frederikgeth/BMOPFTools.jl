# Analyze and triage one case

Run from the repository root:

```sh
julia --startup-file=no --project=. recipes/analyze_case/recipe.jl
```

The recipe parses `recipes/analyze_case/input.json`, runs BMOPFTools' standard analysis
battery, checks three stable Finding codes, and prints a schema-valid execution
response. The equivalent CLI call is:

```sh
bin/bmopf analyze-case --input recipes/analyze_case/input.json --pretty
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

The bundled `input.json` is a hand-authored synthetic three-bus network,
licensed under this repository's BSD-3-Clause license. It contains no CSIRO
MV/LV dataset data.

The recipe also checks the minimized 100 kVA / 40 kW single-coil witness through
`execute_analysis`. It asserts nominal-demand provenance, negative coil headroom
and the screening Finding without interpreting that estimate as an infeasibility
certificate. Only the fixture's network is used; its supplied solution is not
input to this screen. The emitted example remains the original triage response.

### Suppressing geospatial analysis

Spatial analysis runs by default when bus coordinate fields are present. Use
`execute_analysis(net; spatial_enabled=false)`, CLI `analyze-case --no-spatial`,
or the MCP `bmopf_analyze` argument `"spatial_enabled": false` to skip it.
The Boolean defaults to `true` and is recorded in response request parameters.
Suppression leaves other analyses active and returns an explicit spatial
`inapplicable` / `disabled` record, with `analysis_performed=false`.
The analysis recipe exercises this opt-out on a synthetic case with coordinates.

### Provenance hints and interpretation

The recipe also exercises a minimal three-wire LV case through `execute_analysis`.
Its Kron hint retains the possible native three-wire interpretation, records actual
LV use without a represented neutral, and provides review guidance in JSON Finding
detail. This demonstrates how an automated consumer can receive useful hypotheses
without treating them as a verified cause or a model-changing action. The emitted
example remains the original triage response.
