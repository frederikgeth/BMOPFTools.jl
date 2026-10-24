# Run: julia --project=. examples/spatial_cleanup_review.jl CASE.json OUTDIR [DECISIONS.json]
using BMOPFTools, JSON3

function write_spatial_cleanup_bundle(net, outdir; decisions=Any[], config=load_config())
    report = analyze(net; config=config)
    spatial = get(report.results[:connectivity], "spatial", nothing)
    spatial === nothing && throw(ArgumentError("case has no spatial report"))
    review = apply_spatial_review(spatial["cleanup_review"], decisions)
    spatial["cleanup_review"] = review
    mkpath(outdir)
    for (filename, data) in (("review.json", review), ("review.geojson", spatial_review_geojson(review)),
            ("decisions-template.json", Dict("schema_version" => "spatial-cleanup-review/v1", "decisions" => Any[])))
        # Never replace a user's existing decision ledger/template.
        filename == "decisions-template.json" && isfile(joinpath(outdir, filename)) && continue
        open(joinpath(outdir, filename), "w") do io
            JSON3.pretty(io, BMOPFTools._jsonable(data))
        end
    end
    open(joinpath(outdir, "review.md"), "w") do io
        BMOPFTools._md_spatial_cleanup_review(review, io)
    end
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
