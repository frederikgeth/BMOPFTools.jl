# API reference

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
migrate
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
from_pmd
to_pmd
from_dss
```

## Top-level analysis and rendering

```@docs
analyze
render
render_terminal
render_markdown
render_ascii_tree
```

## Solution profiling

```@docs
profile_solution
render_solution
solution_check
voltage_zone_summary
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
