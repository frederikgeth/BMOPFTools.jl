# [Inspect and prepare cases](@id inspect-prepare)

An imported distribution model is rarely ready to optimize. It can be
electrically inconsistent (a floating neutral, a terminal typo), silent about
what a study needs (no ratings, no voltage bounds, no costs), or larger than the
study requires. This section covers the three steps between a raw import and a
case you can solve and defend:

1. **Profile**: run [`analyze`](@ref), read the findings, and decide for each one
   whether to fix the data, record a judgment, or disclose a limitation.
2. **Prepare**: repair the structure, place DERs, and add the study assumptions
   (bounds, ratings, costs) with a manifest that records where every value came
   from.
3. **Reduce** (optional): remove buses or conductors the study does not need, and
   know what each reduction preserves.

Profiling comes first and again last: every transformation in steps 2 and 3
changes the case, so the profiler runs again on the result.

## Where to start

| If you want to | Start with | Then |
|---|---|---|
| Learn the profiling loop on a small feeder | [Profile your first messy case](tutorial_profile_messy_case.md) | [Accept and track findings](howto_accept_findings.md) |
| Know what the profiler says about your wiring and earthing practice | [System types & regional practice](tutorial_system_types.md) | [Grounding & neutral findings explained](grounding_findings.md) |
| Import an OpenDSS deck and read the import's own records | [Porting an OpenDSS feeder](tutorial_opendss_port.md) | [Case study: findings triage at scale](tutorial_triage.md) |
| Check line lengths against bus coordinates | [Spatial cleanup](tutorial_spatial_cleanup.md) | [Spatial diagnostics & cleanup review](spatial_diagnostics.md) |
| Follow the whole pipeline from OpenDSS to a solved benchmark | [From OpenDSS to a solved OPF benchmark](tutorial_end_to_end.md) | [Case augmentation guide](augmentation.md) |
| Turn transformer test reports into model fields | [From test report to transformer model](tutorial_transformer_tests.md) | [Transformer models](transformer_models.md) |
| Place DERs and see which constraint binds | [Placing DERs and reading the binding constraint](tutorial_ders.md) | [Augmentation reference](augmentation_reference.md) |
| Make a network smaller | [Network reduction: which tool?](network_reduction.md) | [Reducing a feeder with a voltage guarantee](tutorial_opti_kron.md) |

The pages are grouped by role. **Tutorials** walk through one case from start to
finish. **How-to** pages answer one task. **Explanation** pages give the physics
and the reasoning behind the checks. **Reference** pages list every key, setting
and pass. Finding codes are listed in the
[finding-code reference](findings.md).

## Which pages run when the documentation is built

The profiling tutorials, the grounding explanation, the two how-to pages and the
transformer test-report tutorial execute every block at build time, on fixtures
that ship with the package: the output shown is what the current code produces.

Five pages use a CC BY-NC-SA utility dataset that is not bundled
(set `ENV["BMOPF_RESTRICTED_DATA"]` to run them): the triage case study, the
end-to-end tutorial, the provenance tutorial, the DER tutorial and the
simplification tutorial. Their code is shown but not executed by the build, so
read their printed values as illustrative. The reduction pages quote numbers
from example scripts under `examples/opti_kron/` and `scripts/`, which name
their own requirements.
