# Run: julia --project=. examples/spatial_cleanup_review.jl CASE.json OUTDIR [DECISIONS.json]
using BMOPFTools, JSON3

function write_spatial_cleanup_bundle(net, outdir; decisions=Any[], config=load_config())
    report = analyze(net; config=config)
    spatial = get(report.results[:connectivity], "spatial", nothing)
    spatial === nothing && throw(ArgumentError("case has no spatial report"))
    haskey(spatial, "cleanup_review") || throw(ArgumentError("spatial cleanup review unavailable: $(spatial["reason"])"))
    review = apply_spatial_review(spatial["cleanup_review"], decisions)
    spatial["cleanup_review"] = review
    export_spatial_review(review, outdir)
    review
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) in (2,3) || error("usage: spatial_cleanup_review.jl CASE.json OUTDIR [DECISIONS.json]")
    decisions = if length(ARGS) == 3
        ledger = JSON3.read(read(ARGS[3], String), Dict{String,Any})
        get(ledger, "schema_version", nothing) == "spatial-cleanup-review/v1" || error("unsupported ledger schema")
        ledger["decisions"]
    else
        Any[]
    end
    write_spatial_cleanup_bundle(parse_bmopf(ARGS[1]), ARGS[2]; decisions=decisions)
end
