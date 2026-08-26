# API reference

## Which function do I need?

A quick map from intent to entry point — each row links to the guide that
explains it in context. The [end-to-end tutorial](tutorial_end_to_end.md) runs
the whole sequence on one feeder.

| I want to… | Reach for | Guide |
|---|---|---|
| Ingest a case | [`from_dss`](@ref), [`parse_bmopf`](@ref) | [Conversion guide](conversion.md) |
| Analyse & diagnose it | [`analyze`](@ref), [`render`](@ref), [`errors`](@ref)/[`warnings`](@ref)/[`infos`](@ref) | [Analysis & reports](analysis.md), [Findings](findings.md) |
| Check a scientific preservation contract | [`check_parallel_member_limit_preservation`](@ref), [`check_neutral_ground_reference_preservation`](@ref), [`check_claimed_solution_validity`](@ref), [`check_load_voltage_base_consistency`](@ref), [`check_transformer_tap_domain_preservation`](@ref), [`check_transformer_winding_convention_preservation`](@ref), [`check_decision_preservation_manifest`](@ref), [`check_kron_boundary_recovery`](@ref), [`check_positive_sequence_collapse`](@ref), [`check_state_dependent_equivalent`](@ref), [`check_reference_singularity`](@ref), [`check_terminal_permutation_invariance`](@ref), [`check_solved_network_feasibility`](@ref), [`check_unit_base_serialization_invariance`](@ref) | [Scientific contracts](scientific_contracts.md) |
| Repair structure | [`fix_case`](@ref) ([`FixRecipe`](@ref)) | [Case augmentation](augmentation.md) |
| Place DERs | [`add_generators`](@ref), [`add_ibrs`](@ref) | [DER placement](tutorial_ders.md) |
| Fill bounds, limits, costs | [`augment_case`](@ref) ([`AugmentationRecipe`](@ref)) | [Case augmentation](augmentation.md) |
| Audit every change | [`render_manifest`](@ref), [`manifest_to_dict`](@ref) | [Case augmentation](augmentation.md) |
| Solve the OPF | [`solve_opf`](@ref), [`solve_pf`](@ref), [`solve_feasibility_opf`](@ref) | [Optimal power flow](opf.md) |
| Extend a staged OPF model | [`build_opf_model`](@ref), [`OpfModelKey`](@ref), [`add_terminal_injection!`](@ref) | [Parameterized and differentiable extensions](differentiable_extensions.md) |
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
OpfModelKey
OpfParameterScope
OpfParameterBinding
OpfDifferentiabilityReport
OpfKKTDiagnostic
OpfDifferentiationError
OpfBuildManifest
OpfDeviceBuilder
OpfBuildSpec
OpfCoefficientKey
OpfCoefficientProvider
ScientificContractResult
```

## Finding accessors

```@docs
errors
warnings
infos
```

## Scientific contracts

```@docs
BMOPFTools.check_parallel_member_limit_preservation
BMOPFTools.check_neutral_ground_reference_preservation
BMOPFTools.check_claimed_solution_validity
BMOPFTools.check_load_voltage_base_consistency
BMOPFTools.check_transformer_tap_domain_preservation
BMOPFTools.check_transformer_winding_convention_preservation
BMOPFTools.check_decision_preservation_manifest
BMOPFTools.check_kron_boundary_recovery
BMOPFTools.check_positive_sequence_collapse
BMOPFTools.check_state_dependent_equivalent
BMOPFTools.check_reference_singularity

BMOPFTools.check_terminal_permutation_invariance
BMOPFTools.check_solved_network_feasibility
BMOPFTools.check_unit_base_serialization_invariance
BMOPFTools.contract_result_to_dict
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
line_yprim
transformer_yprim
export_yprim
write_yprim
ybus_passive
YbusResult
ybus_linearized
LinearizedYbus
ybus_augmented
AugYbusResult
IdealCoupling
```

## Line constants

```@docs
overhead_line_constants
compile_linecode
compile_linecodes!
```

## Conversion

```@docs
to_pmd
from_dss
powerio_source_behavior_contract
to_dss
powerio_findings
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

## Staged OPF extension interface

```@docs
OpfScaling
OpfDiagnosticSchema
OpfRegularization
OpfDifferentiabilityAnnotation
opf_bus_voltage_key
opf_ground_current_key
opf_line_current_key
opf_switch_current_key
opf_load_current_key
opf_generator_current_key
opf_voltage_source_current_key
opf_transformer_current_key
opf_transformer_tap_key
opf_nwinding_current_key
opf_ibr_current_key
opf_ibr_power_key
opf_ibr_voltage_magnitude_key
opf_dc_voltage_key
opf_dc_ground_current_key
opf_dc_branch_current_key
opf_converter_dc_current_key
opf_dc_load_current_key
opf_dc_source_current_key
opf_dc_source_power_key
opf_model
opf_network
opf_bases
piecewise_linear_value
opf_piecewise_linear_expression
opf_coordinate_bases
opf_diagnostic_schema
opf_neutral_labels
opf_lifecycle
opf_build_manifest
opf_build_spec
opf_stage_completed
initialize_opf_model
set_opf_start_values!
add_opf_operational_limits!
add_opf_device_constraints!
set_opf_objective!
register_opf_result_extractor!
register_opf_object!
opf_object
opf_object_keys
register_opf_objective_term!
opf_primal
opf_constraint_value
opf_constraint_slack
opf_dual
opf_objective_value
register_opf_regularization!
opf_regularizations
register_opf_differentiability_annotation!
opf_differentiability_annotations
opf_research_hashes
bind_opf_parameter!
opf_parameter
opf_parameter_binding
opf_parameter_bindings
opf_coefficient
opf_coefficient_provider
opf_coefficient_providers
opf_coefficient_usage
opf_differentiability_report
opf_checked_kkt_factorization
opf_kkt_diagnostic
opf_research_provenance
extension_state!
add_terminal_injection!
```

## Objective building blocks

Composable, individually weighted objective terms — losses, sequence-component
unbalance, and the magnitude primitive behind them. See
[Choosing an objective](objectives.md) for what each one does to the answer and
when not to use it.

```@docs
OpfObjectiveTerm
opf_loss_term
opf_sequence_term
opf_generation_cost_term
opf_total_loss
opf_element_loss
opf_sequence_voltage
opf_current_term
opf_branch_currents
opf_neutral_current
opf_sequence_current
opf_reduce_norm
opf_control_effort_term
opf_vuf_term
opf_report_sequence_voltage
opf_report_vuf
opf_report_current
smooth_norm
opf_physical_scale
```

## Configuration

```@docs
load_config
```

## Advanced OPF semantic extension seam

The semantic-block registry is intentionally an advanced, qualified API rather
than an exported convenience layer. Downstream builders that need to publish
custom coordinate or residual semantics may call these names explicitly:

```@docs
BMOPFTools.OpfSemanticBlock
BMOPFTools.register_opf_semantic_block!
BMOPFTools.opf_semantic_blocks
```

Native semantic blocks are registered lazily on the first schema/provenance
request after KCL finalisation, or when `register_opf_semantic_block!` is
called after KCL finalisation. Ordinary solves therefore do not pay for
diagnostic metadata they never inspect, while post-KCL custom registration
incurs the same materialisation cost and surfaces overlaps at that call.
Before KCL finalisation the schema reports `semantic_blocks_available=false`; a
complete native registry is only claimed once the KCL rows and late auxiliary
bounds exist.

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
