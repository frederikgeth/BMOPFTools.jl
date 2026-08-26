using Documenter
using BMOPFTools

makedocs(
    sitename = "BMOPFTools.jl",
    modules  = [BMOPFTools],
    repo     = Documenter.Remotes.GitHub("frederikgeth", "BMOPFTools.jl"),
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",  # pretty URLs on CI, plain files locally
        edit_link  = "main",                             # "Edit on GitHub" links point at main
        # Both are exhaustive reference pages whose size is the point: findings.md
        # is the full finding catalogue, api.md the full docstring index. api.md
        # was already over the WARN limit before the objective building blocks
        # were added; splitting it would scatter the reference people search.
        size_threshold_ignore = ["findings.md", "api.md"],
    ),
    pages = [
        "Home"                    => "index.md",
        "Getting started"         => [
            "Installation & first steps" => "installation.md",
            "Use with AI coding assistants" => "ai_assistants.md",
            "End-to-end tutorial"      => "tutorial_end_to_end.md",
            "Choose your tutorial"     => "choose_tutorial.md",
            "Positioning & ecosystem"  => "positioning.md",
            "Why benchmarks matter"    => "benchmarking_gap.md",
        ],
        "Data model"              => [
            "Buses & terminals primer" => "terminals_primer.md",
            "Ground, neutral & earth return" => "tutorial_grounding.md",
            "Data model conventions"   => "conventions.md",
            "Units, bases & economics" => "tutorial_units.md",
            "Object identity"          => "semantic_modeling.md",
            "Line geometry & impedances" => "tutorial_line_geometry.md",
            "Conversion guide"         => "conversion.md",
        ],
        "Analysis & diagnostics"  => [
            "Analysis & reports"       => "analysis.md",
            "Scientific contracts"     => "scientific_contracts.md",
            "Finding-code reference"   => "findings.md",
            "Findings triage tutorial" => "tutorial_triage.md",
            "Trust but verify: validating a solve" => "tutorial_trust_but_verify.md",
            "Methodology notes"        => "methodology.md",
        ],
        "Case preparation"        => [
            "Case augmentation"        => "augmentation.md",
            "From nameplate data to a model" => "tutorial_nameplate.md",
            "From test report to transformer model" => "tutorial_transformer_tests.md",
            "Simplification tutorial"  => "tutorial_simplify.md",
            "DER placement tutorial"   => "tutorial_ders.md",
            "VVWO tutorial"            => "tutorial_vvwo.md",
            "Smooth droop encoding"    => "relu_softplus_encoding.md",
        ],
        "Optimal power flow"      => [
            "Optimal power flow"       => "opf.md",
            "Choosing an objective"    => "objectives.md",
            "Objectives tutorial"      => "tutorial_objectives.md",
            "Parameterized & differentiable extensions" => "differentiable_extensions.md",
            "Transformer models"       => "transformer_models.md",
            "Impedance models & OPF decisions" => "tutorial_impedance_models.md",
            "Choosing & identifying a load model" => "tutorial_load_models.md",
            "OPF result dictionary"    => "results.md",
            "Validating the OPF"       => "validation.md",
            "SWER case study"          => "tutorial_swer.md",
            "D-STATCOM unbalance study" => "tutorial_statcom.md",
            "MVDC/LVDC converter stations" => "tutorial_mvdc.md",
            "Transformer tap optimisation" => "tutorial_tap.md",
            "Time series: a day on an LV feeder" => "tutorial_timeseries.md",
            "Custom formulations: CVR, envelopes & hooks" => "tutorial_custom_formulations.md",
        ],
        "Bounds & feasibility"    => [
            "bounds/index.md",
            "Infeasibility diagnosis tutorial" => "tutorial_infeasibility.md",
            "bounds/decision_matrix.md",
            "bounds/loss_maximization.md",
            "bounds/diagnostics.md",
            "bounds/known_traps.md",
            "bounds/solver_trust.md",
            "bounds/references.md",
        ],
        "Reference"               => [
            "API reference"            => "api.md",
            "Developer guide"          => [
                "Contributing & workflow"      => "dev/contributing.md",
                "Style guide"                  => "dev/style_guide.md",
                "Versioning & the data model"  => "dev/versioning.md",
                "OPF engine: scope & status"   => "dev/opf_engine.md",
                "Profiling pipeline"           => "dev/profiling.md",
            ],
        ],
        "Model specification"     => [
            "Overview"          => "spec/index.md",
            "Background & scope" => "spec/scope.md",
            "Notation"          => "spec/notation.md",
            "Data input formatting" => "spec/data-format.md",
            "Grounding"         => "spec/grounding.md",
            "Worked example"    => "spec/example.md",
            "Document metadata" => "spec/metadata.md",
            "Buses"             => "spec/bus.md",
            "Lines"             => "spec/line.md",
            "Switches"          => "spec/switch.md",
            "Loads"             => "spec/load.md",
            "Generators"        => "spec/generator.md",
            "Shunts"            => "spec/shunt.md",
            "Capacitors"        => "spec/capacitor.md",
            "Voltage sources"   => "spec/source.md",
            "Transformers"      => "spec/transformer.md",
            "Regulators"        => "spec/regulator.md",
            "Transformer primitive admittance" => "spec/transformer-admittance.md",
            "System nodal admittance" => "spec/nodal-admittance.md",
            "IBRs"              => "spec/ibr.md",
            "DC networks"       => "spec/dc.md",
            "Objective & feasibility" => "spec/objective.md",
            "Impedance derivation"    => "spec/impedance.md",
            "Control profiles"        => "spec/control-profile.md",
            "Time series"             => "spec/timeseries.md",
            "Modelling notes & FAQ"   => "spec/faq.md",
            "References & further reading" => "spec/references.md",
        ],
    ],
    checkdocs = :exports,   # every exported symbol must have a docstring (no suppression)
)

deploydocs(
    repo = "github.com/frederikgeth/BMOPFTools.jl.git",
    devbranch = "main",
    dirname = "docs",   # Pages serves gh-pages:/docs; changing that needs repo admin
    push_preview = false,
)
