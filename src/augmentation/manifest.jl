"""
    TransformEntry

A single field change made by an augmentation pass.

Fields
------
- `component_type` — `:bus`, `:linecode`, `:generator`, `:ibr`, or `:transformer`
- `component_id`   — the dict key of the modified component
- `field`          — the field name written (e.g. `"vpn_min"`, `"i_max"`)
- `old_value`      — previous value (`nothing` if the field was absent)
- `new_value`      — value written
- `rule`           — standards citation (e.g. `"EN50160:2010§3.5"`)
- `confidence`     — `:standard`, `:high`, `:medium`, or `:low`
- `note`           — human-readable explanation
"""
struct TransformEntry
    component_type :: Symbol
    component_id   :: String
    field          :: String
    old_value      :: Any
    new_value      :: Any
    rule           :: String
    confidence     :: Symbol
    note           :: String
end

"""
    TransformationManifest

Complete audit trail for one call to [`augment_case`](@ref).

Fields
------
- `created_at`      — ISO-8601 timestamp of the augmentation run
- `recipe`          — the recipe used (`AugmentationRecipe`, `FixRecipe`, or
                      `GeneratorRecipe`); the change detail is also captured in `entries`
- `entries`         — ordered list of [`TransformEntry`](@ref) records
- `findings_before` — [`benchmark_readiness_check`](@ref) findings on the
                      input case (snapshot)
- `findings_after`  — findings on the augmented output case
"""
struct TransformationManifest
    created_at      :: String
    recipe          :: Any
    entries         :: Vector{TransformEntry}
    findings_before :: Vector{Finding}
    findings_after  :: Vector{Finding}
end

# ── Serialisation helpers ────────────────────────────────────────────────────

function _entry_to_dict(e::TransformEntry)::Dict{String,Any}
    Dict{String,Any}(
        "component_type" => string(e.component_type),
        "component_id"   => e.component_id,
        "field"          => e.field,
        "old_value"      => e.old_value,
        "new_value"      => e.new_value,
        "rule"           => e.rule,
        "confidence"     => string(e.confidence),
        "note"           => e.note,
    )
end

function _finding_to_dict(f::Finding)::Dict{String,Any}
    Dict{String,Any}(
        "severity" => string(f.severity),
        "code"     => f.code,
        "message"  => f.message,
    )
end

"""
    manifest_to_dict(m::TransformationManifest) -> Dict{String,Any}

Convert a manifest to a plain dict suitable for JSON serialisation via
`write_bmopf` or `JSON3.write`.
"""
function manifest_to_dict(m::TransformationManifest)::Dict{String,Any}
    Dict{String,Any}(
        "created_at"      => m.created_at,
        "entries"         => _entry_to_dict.(m.entries),
        "findings_before" => _finding_to_dict.(m.findings_before),
        "findings_after"  => _finding_to_dict.(m.findings_after),
    )
end

# ── Terminal renderer ────────────────────────────────────────────────────────

"""
    render_manifest(m::TransformationManifest; io=stdout)

Print a human-readable diff of all changes recorded in the manifest, grouped
by component type.
"""
function render_manifest(m::TransformationManifest; io::IO = stdout)
    println(io, "Augmentation manifest — $(m.created_at)")
    println(io, "  $(length(m.entries)) change(s)  |  " *
                "findings before: $(length(m.findings_before))  " *
                "after: $(length(m.findings_after))")
    println(io)

    # Group by component_type
    groups = Dict{Symbol,Vector{TransformEntry}}()
    for e in m.entries
        push!(get!(groups, e.component_type, TransformEntry[]), e)
    end

    # Render the known types in a stable, preferred order, then any remaining
    # types present in the manifest — so a new component_type is never silently
    # dropped from the rendered diff (as :ibr once was).
    preferred = (:bus, :linecode, :generator, :ibr, :transformer)
    extra     = sort!([k for k in keys(groups) if !(k in preferred)])
    for ctype in (preferred..., extra...)
        entries = get(groups, ctype, TransformEntry[])
        isempty(entries) && continue
        println(io, "── $(uppercase(string(ctype))) ($(length(entries)) change(s)) ──")
        current_id = ""
        for e in sort(entries, by = x -> (x.component_id, x.field))
            if e.component_id != current_id
                println(io, "  $(e.component_id)")
                current_id = e.component_id
            end
            old_s = e.old_value === nothing ? "—" : string(e.old_value)
            new_s = string(e.new_value)
            println(io, "    $(rpad(e.field, 16)) $(rpad(old_s, 20)) → $(new_s)")
            println(io, "    $(repeat(" ", 16)) [$(e.rule), $(e.confidence)] $(e.note)")
        end
        println(io)
    end
end
