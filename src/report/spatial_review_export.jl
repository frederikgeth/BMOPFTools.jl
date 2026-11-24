"""
    render_spatial_review(review, io=stdout; item_limit=20)

Write a standalone Markdown cleanup review from a spatial `cleanup_review`
dictionary or the result of [`apply_spatial_review`](@ref). `item_limit` is a
nonnegative integer limiting each of the attention, contextual and reviewed
sections separately. It limits presentation only, not captured evidence.
"""
function render_spatial_review(review::AbstractDict, io::IO=stdout; item_limit=20)
    get(review, "schema_version", nothing) == _SPATIAL_REVIEW_VERSION ||
        throw(ArgumentError("unsupported spatial review schema"))
    item_limit isa Integer && !(item_limit isa Bool) && item_limit >= 0 ||
        throw(ArgumentError("item_limit must be a nonnegative integer"))
    _md_spatial_cleanup_review(review, io; item_limit=item_limit)
    nothing
end

"""
    export_spatial_review(review, outdir; item_limit=20)

Write `review.md`, `review.json`, `review.geojson` and a
`decisions-template.json` sidecar to `outdir`. Return a dictionary of output
paths. Accepts the `cleanup_review` dictionary from an analysis or the result of
[`apply_spatial_review`](@ref); it does not rerun analysis or modify the model.

Markdown uses [`render_spatial_review`](@ref). JSON retains all captured items;
GeoJSON contains supported WGS84 evidence points with omission counts.
Existing report files are replaced; an existing decisions template is preserved.
Validate and serialize all reports before creating output files. The bundle is
not a transactional filesystem write.
"""
function export_spatial_review(review::AbstractDict, outdir::AbstractString; item_limit=20)
    markdown = sprint(io -> render_spatial_review(review, io; item_limit=item_limit))
    json = sprint(io -> JSON3.pretty(io, _jsonable(review)))
    geojson = sprint(io -> JSON3.pretty(io, _jsonable(spatial_review_geojson(review))))
    template = sprint(io -> JSON3.pretty(io, Dict("schema_version" => _SPATIAL_REVIEW_VERSION, "decisions" => Any[])))
    mkpath(outdir)
    paths = Dict{String,String}()
    for (filename, content) in (("review.md", markdown), ("review.json", json),
            ("review.geojson", geojson), ("decisions-template.json", template))
        path = abspath(joinpath(outdir, filename)); paths[filename] = path
        filename == "decisions-template.json" && isfile(path) && continue
        write(path, content)
    end
    paths
end
