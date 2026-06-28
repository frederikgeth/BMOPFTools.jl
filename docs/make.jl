using Documenter
using BMOPFTools

makedocs(
    sitename = "BMOPFTools.jl",
    modules  = [BMOPFTools],
    repo     = Documenter.Remotes.GitHub("frederikgeth", "BMOPFTools.jl"),
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",  # pretty URLs on CI, plain files locally
        edit_link  = "main",                             # "Edit on GitHub" links point at main
        size_threshold_ignore = ["findings.md"],
    ),
    pages = [
        "Home"                    => "index.md",
        "Getting started"         => [
            "End-to-end tutorial"      => "tutorial_end_to_end.md",
            "Positioning & ecosystem"  => "positioning.md",
        ],
        "Data model"              => [
            "Buses & terminals primer" => "terminals_primer.md",
            "Data model conventions"   => "conventions.md",
            "Object identity"          => "semantic_modeling.md",
            "Conversion guide"         => "conversion.md",
        ],
        "Analysis & diagnostics"  => [
            "Analysis & reports"       => "analysis.md",
            "Finding-code reference"   => "findings.md",
            "Methodology notes"        => "methodology.md",
        ],
        "Case preparation"        => [
            "Case augmentation"        => "augmentation.md",
            "DER placement tutorial"   => "tutorial_ders.md",
            "VVWO tutorial"            => "tutorial_vvwo.md",
            "Smooth droop encoding"    => "relu_softplus_encoding.md",
        ],
        "Optimal power flow"      => [
            "Optimal power flow"       => "opf.md",
            "OPF result dictionary"    => "results.md",
            "Validating the OPF"       => "validation.md",
            "SWER case study"          => "tutorial_swer.md",
        ],
        "Bounds & feasibility"    => [
            "bounds/index.md",
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
    ],
    checkdocs = :exports,   # every exported symbol must have a docstring (no suppression)
)

deploydocs(
    repo = "github.com/frederikgeth/BMOPFTools.jl.git",
    devbranch = "main",
    dirname = "docs",   # Pages serves gh-pages:/docs; changing that needs repo admin
    push_preview = false,
)
