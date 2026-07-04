# API reference

## Which function do I need?

A quick map from intent to entry point — each row links to the guide that
explains it in context. The [end-to-end tutorial](tutorial_end_to_end.md) runs
the whole sequence on one feeder.

| I want to… | Reach for | Guide |
|---|---|---|
| Ingest a case | [`from_dss`](@ref), [`parse_bmopf`](@ref) | [Conversion guide](conversion.md) |
| Analyse & diagnose it | [`analyze`](@ref), [`render`](@ref), [`errors`](@ref)/[`warnings`](@ref)/[`infos`](@ref) | [Analysis & reports](analysis.md), [Findings](findings.md) |
| Repair structure | [`fix_case`](@ref) ([`FixRecipe`](@ref)) | [Case augmentation](augmentation.md) |
| Place DERs | [`add_generators`](@ref), [`add_ibrs`](@ref) | [DER placement](tutorial_ders.md) |
| Fill bounds, limits, costs | [`augment_case`](@ref) ([`AugmentationRecipe`](@ref)) | [Case augmentation](augmentation.md) |
| Audit every change | [`render_manifest`](@ref), [`manifest_to_dict`](@ref) | [Case augmentation](augmentation.md) |
| Solve the OPF | [`solve_opf`](@ref), [`solve_pf`](@ref), [`solve_feasibility_opf`](@ref) | [Optimal power flow](opf.md) |
| Inspect / profile a result | [`profile_solution`](@ref), [`render_solution`](@ref), [`diagnose_infeasibility`](@ref) | [OPF result dictionary](results.md) |
| Export | [`write_bmopf`](@ref), [`write_result`](@ref), [`to_pmd`](@ref), [`to_dss`](@ref) | [Conversion guide](conversion.md) |

## Module

```@docs
BMOPFTools
```

## Types

```@docs
Finding
SummaryReport
SolutionReport
Severity
ERROR
WARNING
INFO
```

## Finding accessors

```@docs
errors
warnings
infos
```

## IO

```@docs
parse_bmopf
write_bmopf
write_result
read_result
BMOPFTools.migrate
is_timeseries
get_snapshot
sideload_coordinates!
```

## Admittance export

```@docs
transformer_yprim
export_yprim
write_yprim
```

## Conversion

```@docs
to_pmd
from_dss
to_dss
project_solution
dispatch_as_loads
```

## Top-level analysis and rendering

```@docs
analyze
render
BMOPFTools.render_terminal
BMOPFTools.render_markdown
BMOPFTools.render_json
render_ascii_tree
```

## Solution profiling

```@docs
profile_solution
render_solution
solution_check
BMOPFTools.voltage_zone_summary
```

## Configuration

```@docs
load_config
```

## Network simplification

```@docs
simplify_network
merge_series_lines
remove_dangling_lines
remove_open_switches
collapse_closed_switches
```

## Analysis passes

```@docs
inventory_analysis
voltage_level_analysis
connectivity_analysis
diversity_analysis
operational_analysis
load_model_analysis
provenance_analysis
infeasibility_preflight
```

## Validation passes

```@docs
schema_check
completeness_check
domain_rules_check
redundancy_check
integrity_check
spec_conformance_check
benchmark_readiness_check
```

## Case preparation

See [Case augmentation](augmentation.md) for the full reference and worked
examples.  The main entry points are `fix_case` / `FixRecipe` (structural
repairs) and `augment_case` / `AugmentationRecipe` / `default_recipe`
(standards-grounded gap-filling), together with the shared
`TransformationManifest` / `TransformEntry` / `manifest_to_dict` /
`render_manifest` audit trail.
