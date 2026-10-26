using Documenter
using BMOPFTools

const REPOSITORY_ROOT = normpath(joinpath(@__DIR__, ".."))

makedocs(
    sitename = "BMOPFTools.jl",
    modules  = [BMOPFTools],
    repo     = Documenter.Remotes.GitHub("frederikgeth", "BMOPFTools.jl"),
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",  # pretty URLs on CI, plain files locally
        edit_link  = "main",                             # "Edit on GitHub" links point at main
        # assets/logo.svg and assets/logo-dark.svg are picked up automatically as the
        # sidebar logo; see scripts/logo/README.md for every logo variant.
        assets     = ["assets/favicon.ico"],
        # Both are exhaustive reference pages whose size is the point: findings.md
        # is the full finding catalogue, api.md the full docstring index. api.md
        # was already over the WARN limit before the objective building blocks
        # were added; splitting it would scatter the reference people search.
        size_threshold_ignore = ["findings.md", "api.md"],
    ),
    pages = [
        "Home" => "index.md",
        "Getting started" => [
            "Installation & first steps" => "installation.md",
            "First case: inspect, solve & verify" => "first_case.md",
            "Choose your tutorial" => "choose_tutorial.md",
            "Positioning & ecosystem" => "positioning.md",
            "Why benchmarks matter" => "benchmarking_gap.md",
        ],
        "Network models & data" => [
            "Foundations" => [
                "Buses & terminals primer" => "terminals_primer.md",
                "Ground, neutral & earth return" => "tutorial_grounding.md",
                "Units, bases & economics" => "tutorial_units.md",
                "Object identity" => "semantic_modeling.md",
            ],
            "Modelling choices" => [
                "Line geometry & impedances" => "tutorial_line_geometry.md",
                "Impedance models & OPF decisions" => "tutorial_impedance_models.md",
                "Choosing & identifying a load model" => "tutorial_load_models.md",
                "Transformer models" => "transformer_models.md",
            ],
            "Conventions & conversion" => [
                "Data model conventions" => "conventions.md",
                "Device parameter indexing" => "device_indexing.md",
                "Branch and winding maps" => "connection_maps.md",
                "Transformer phase reporting" => "transformer_phase.md",
                "Conversion guide" => "conversion.md",
            ],
        ],
        "Inspect & prepare cases" => [
            "Inspect the evidence" => [
                "Analysis & reports" => "analysis.md",
                "Findings triage tutorial" => "tutorial_triage.md",
                "How network diagnostics work" => "methodology.md",
                "Spatial diagnostics & cleanup review" => "spatial_diagnostics.md",
                "Visualizing a case with Tellegen" => "visualization.md",
            ],
            "Prepare and recheck" => [
                "From nameplate data to a model" => "tutorial_nameplate.md",
                "From test report to transformer model" => "tutorial_transformer_tests.md",
                "Simplification tutorial" => "tutorial_simplify.md",
                "Case augmentation" => "augmentation.md",
                "DER placement tutorial" => "tutorial_ders.md",
                "Utility-data end-to-end tutorial" => "tutorial_end_to_end.md",
            ],
        ],
        "Power flow & OPF studies" => [
            "OPF guide & model" => "opf.md",
            "Solver guide" => "solvers.md",
            "Choosing an objective" => "objectives.md",
            "Objectives tutorial" => "tutorial_objectives.md",
            "Developing OPF case families" => "tutorial_case_development.md",
            "Time series: a day on an LV feeder" => "tutorial_timeseries.md",
            "PV volt-var / volt-watt study" => "tutorial_vvwo.md",
            "Transformer tap optimisation" => "tutorial_tap.md",
            "D-STATCOM unbalance study" => "tutorial_statcom.md",
            "SWER case study" => "tutorial_swer.md",
            "MVDC/LVDC converter stations" => "tutorial_mvdc.md",
        ],
        "Verify & diagnose results" => [
            "Trust but verify: one solved case" => "tutorial_trust_but_verify.md",
            "Solution projection & power-flow comparison" => "solution_projection.md",
            "OPF result dictionary" => "results.md",
            "Infeasibility diagnosis tutorial" => "tutorial_infeasibility.md",
        ],
        "Advanced formulations & numerics" => [
            "Choose an advanced route" => "advanced.md",
            "Nodal admittance builders" => "spec/nodal-admittance.md",
            "Transformer primitive admittance" => "spec/transformer-admittance.md",
            "Exact substitutions & formulation boundaries" => "formulation_substitutions.md",
            "Smooth droop encoding" => "relu_softplus_encoding.md",
            "Custom formulations: CVR, envelopes & hooks" => "tutorial_custom_formulations.md",
            "Model extensions & sensitivities" => "differentiable_extensions.md",
            "Scaling, initialization & diagnostics" => "numerical_workflows.md",
            "Repeated solves & parameter updates" => "repeated_solves.md",
            "Bounds & feasibility" => [
                "bounds/index.md",
                "bounds/decision_matrix.md",
                "bounds/loss_maximization.md",
                "bounds/diagnostics.md",
                "bounds/known_traps.md",
                "bounds/solver_trust.md",
                "bounds/references.md",
            ],
        ],
        "Automation & integration" => [
            "JSON execution & recipes" => "execution_interface.md",
            "Use with AI coding assistants" => "ai_assistants.md",
        ],
        "Reference & development" => [
            "API reference" => "api.md",
            "Finding-code reference" => "findings.md",
            "Scientific-contract reference" => "scientific_contracts.md",
            "Engine validation evidence" => "validation.md",
            "Developer guide" => [
                "Contributing & workflow" => "dev/contributing.md",
                "Style guide" => "dev/style_guide.md",
                "Versioning & the data model" => "dev/versioning.md",
                "OPF engine: scope & status" => "dev/opf_engine.md",
                "Profiling pipeline" => "dev/profiling.md",
            ],
        ],
        # Existing spec pages still render for inbound links.
        "BMOPF specification" => "spec/index.md",
    ],
    checkdocs = :exports,   # every exported symbol must have a docstring (no suppression)
)

# @example writes reports at the build root. Keep raw download links relative to
# the first-case page in both flat local builds and CI's pretty-URL layout.
if get(ENV, "CI", nothing) == "true"
    for report in ("first-case-report.md", "first-case-solution.md")
        cp(joinpath(@__DIR__, "build", report),
            joinpath(@__DIR__, "build", "first_case", report); force=true)
    end
end

# Keep one canonical machine-discovery file at the repository root and publish
# that exact file with the Documenter site.
cp(
    joinpath(REPOSITORY_ROOT, "llms.txt"),
    joinpath(@__DIR__, "build", "llms.txt");
    force=true,
)

deploydocs(
    repo = "github.com/frederikgeth/BMOPFTools.jl.git",
    devbranch = "main",
    dirname = "docs",   # Pages serves gh-pages:/docs; changing that needs repo admin
    push_preview = false,
)
