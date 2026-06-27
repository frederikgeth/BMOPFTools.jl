# MVLVmeshed — meshed combined feeder case

A derived, **meshed** variant of the combined Australian feeder model. It is a
thin overlay on the radial base case ([`../Master.dss`](../Master.dss)) that
restores switches and lines which were commented out when the model was made
radial. The original per-feeder files under [`../MV/`](../MV/) and
[`../LV/`](../LV/) are **not** changed — they remain the radial source of truth.

## Provenance & license

The base data is the CSIRO dataset *"Realistic Australian Medium Voltage Feeder
with Associated Low Voltage Feeders"* (MV21 backbone + 33 LV feeders). See the
per-folder license files, e.g. [`../LV/License.md`](../LV/License.md) and
[`../MV/MV21_328bus/License.md`](../MV/MV21_328bus/License.md). The original data
is licensed **CC BY-NC-SA 4.0** (https://doi.org/10.25919/ghnz-bk28); that
license carries over to this derived case.

## Why this case exists

The combined model was deliberately reduced to a **radial** tree. Switch
statuses in the source came from GIS and are unreliable, so they were overridden
and the loop-closing switches were commented out to guarantee radiality. Those
commented-out objects — the traces of that editing, scattered through the
per-feeder `../LV/LV*/Switches.dss` and `../LV/LV*/lines.dss` files — are exactly
what this case adds back.

> **Note on status:** the `_OPEN` / `_CLOSED` suffix in each switch name is a
> *reconstruction from the original names*, not authoritative GIS truth. Treat
> the statuses as indicative only.

## What is added

The overlay restores **38 unique switches** (deduplicated — the 34 normally-open
ties were each cross-listed in both feeders they bridge, i.e. 68 raw entries) and
**2 lines**:

| Group | Count | Role |
|-------|-------|------|
| `*_CLOSED` switches | 4 | Intra-feeder loop switches; commented out specifically to force radiality. Re-closing them breaks radiality. |
| `*_OPEN` switches | 34 | Normally-open inter-feeder tie switches. |
| lines (`L_1299`, `L_4689`) | 2 | Previously-removed line segments. |

The 4 closed switches: `Switch_4167_CLOSED` (LV12), `Switch_3192_CLOSED` (LV30),
`Switch_3773_CLOSED` and `Switch_4284_CLOSED` (LV9).

## ⚠️ Open-switch status and PowerIO

[`Master.dss`](Master.dss) issues OpenDSS `open line.<name> term=1` commands for
the 34 `_OPEN` ties, so in a **real OpenDSS** run those ties are open and only the
4 closed switches (+ 2 lines) mesh the network.

**However, PowerIO (the parser behind `from_dss`) does not carry open-switch
status** — neither `open` commands nor `enabled=no` round-trip. Through
`from_dss`, **all 38 re-added switches come back closed** (`open_switch=false`),
so the parsed BMOPF network is *fully* meshed: every tie also closes a loop. If
you need the ties open in BMOPF, set `open_switch=true` on the switches whose id
ends in `_OPEN` after parsing.

## Topology at a glance

See [`ANALYSIS.md`](ANALYSIS.md) for the full BMOPFTools report. Headline from
the connectivity section: topology **Meshed**, `40` extra edges forming cycles
(38 switches + 2 lines, all closing loops across the otherwise-radial base).

## How to load & regenerate the report

```julia
using BMOPFTools
net = from_dss(joinpath("test", "data", "MVLVmeshed", "Master.dss"))
report = analyze(net)                                              # run all analyses
render(report, joinpath("test", "data", "MVLVmeshed", "ANALYSIS.md"))  # regenerate ANALYSIS.md
```

## Files

| File | Contents |
|------|----------|
| [`Master.dss`](Master.dss) | Derived master: base redirects (`../MV`, `../LV`) + overlay redirects + `open` commands for the ties. |
| [`readded_switches.dss`](readded_switches.dss) | The 38 restored switches (34 `_OPEN` + 4 `_CLOSED`), deduplicated. |
| [`readded_lines.dss`](readded_lines.dss) | The 2 restored lines (`L_1299`, `L_4689`). |
| [`ANALYSIS.md`](ANALYSIS.md) | Full BMOPFTools report (`analyze` → `render`) for the parsed network. |
