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
        "Positioning & ecosystem" => "positioning.md",
        "Data model conventions"  => "conventions.md",
        "Conversion guide"        => "conversion.md",
        "Analysis & reports"      => "analysis.md",
        "Finding-code reference"  => "findings.md",
        "Methodology notes"       => "methodology.md",
        "Optimal power flow"      => "opf.md",
        "VVWO tutorial"           => "tutorial_vvwo.md",
        "Smooth droop encoding"   => "relu_softplus_encoding.md",
        "OPF result dictionary"   => "results.md",
        "Case augmentation"       => "augmentation.md",
        "API reference"           => "api.md",
    ],
    checkdocs = :exports,   # every exported symbol must have a docstring (no suppression)
)

deploydocs(
    repo = "github.com/frederikgeth/BMOPFTools.jl.git",
    devbranch = "main",
    dirname = "docs",   # Pages serves gh-pages:/docs; changing that needs repo admin
    push_preview = false,
)
