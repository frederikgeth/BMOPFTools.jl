# io/migrate.jl
#
# Spec-version detection and forward migration for BMOPF network dicts.
#
# Usage: called automatically by parse_bmopf (via _postprocess) so that all
# downstream code — analysis, OPF, augmentation — only ever sees a current-spec
# dict. Callers can also invoke `migrate` directly on an already-parsed dict.
#
# Adding a new spec version:
#   1. Bundle the new schema under src/validation/schemas/<tag>.json.
#   2. Add a new entry to _SPEC_VERSIONS mapping the canonical $schema URI to a
#      version tag symbol.
#   3. Write a _migrate_<old>_to_<new>(net) -> net function below.
#   4. Add the migration step to the chain in `migrate`.

# Map canonical $schema URIs (as written into meta.$schema by write_bmopf) to
# internal version tag symbols. Entries should be added in chronological order.
const _SPEC_VERSIONS = Dict{String,Symbol}(
    # The published schema's own $id, stamped by `write_bmopf` and by powerio
    # v0.8.0 and later. Same draft data model as the two spellings below; the
    # shapes that moved with it (uppercase load models, transformer fields
    # relocated under extras) are handled by the unconditional migrations
    # below, so every source maps to one tag.
    "https://raw.githubusercontent.com/frederikgeth/bmopf-report/main/draft_schema_and_networks/draft_bmopf_schema.json" => :draft,
    # A path this package stamped until it was found to resolve to nothing
    # upstream; accepted on read so files carrying it still parse.
    "https://raw.githubusercontent.com/frederikgeth/bmopf-report/main/schema/bmopf.json" => :draft,
    # Legacy URI written by earlier exports (e.g. output/LV, output/MV cases).
    "https://github.com/frederikgeth/bmopf-report/draft_schema_and_networks" => :draft,
)

# The tag for the spec version this build of BMOPFTools targets.
const _CURRENT_SPEC = :draft

"""
    _detect_spec_version(net::Dict{String,Any}) -> Symbol

Infer the BMOPF spec version from `meta.\$schema`. Returns the corresponding
version tag if the URI is recognised, or `:unknown` otherwise.
"""
function _detect_spec_version(net::Dict{String,Any})::Symbol
    uri = get(get(net, "meta", Dict()), "\$schema", nothing)
    uri isa String || return :unknown
    get(_SPEC_VERSIONS, uri, :unknown)
end

"""
    migrate(net::Dict{String,Any}) -> Dict{String,Any}

Forward-migrate a BMOPF network dict to the current spec version.

If the dict already targets the current spec — or carries no `meta.\$schema`
at all (hand-written fixtures) — it is returned unchanged apart from the
unconditional field-level migrations. A `meta.\$schema` URI that this build
does **not** recognise raises an `ArgumentError`: the file was most likely
written against a newer BMOPF spec than this BMOPFTools build understands, and
silently proceeding could corrupt results. Once older spec versions exist,
each intermediate migration step is applied in sequence and recorded under
`net["_meta"]["migration_notes"]` so the transformation is auditable.

Called automatically by [`parse_bmopf`](@ref); can also be called directly on
an already-parsed dict.
"""
function migrate(net::Dict{String,Any})::Dict{String,Any}
    # Field-level migrations run unconditionally (independent of spec version).
    _fold_transformer_extras!(net)
    _fold_dropped_top_level_extras!(net)
    _migrate_transformer_series_fields!(net)
    _migrate_field_renames!(net)
    _normalize_load_models!(net)
    _reject_scalar_v_bounds!(net)

    v = _detect_spec_version(net)
    v == _CURRENT_SPEC && return net

    # A declared-but-unrecognised URI means a newer spec (or a typo) — refuse
    # rather than silently interpreting the data under the wrong model.
    uri = get(get(net, "meta", Dict()), "\$schema", nothing)
    if v == :unknown && uri isa String
        supported = join(sort(collect(keys(_SPEC_VERSIONS))), "\n  ")
        throw(ArgumentError(
            "meta.\$schema declares an unrecognised BMOPF spec URI:\n  $uri\n" *
            "This build of BMOPFTools supports:\n  $supported\n" *
            "The file was likely written against a newer spec — upgrade " *
            "BMOPFTools, or correct the URI if it is a typo."))
    end

    # No meta.$schema at all: accept (hand-written dicts and fixtures).
    v == :unknown && return net

    # Migration chain — extend when new spec versions are added.
    # (currently empty: only one spec version exists)

    return net
end

"""
    _migrate_transformer_series_fields!(net::Dict{String,Any}) -> nothing

In-place migration applied at parse time (independent of spec version) to
normalise `wye_delta`/`delta_wye` transformers that carry a lumped
`r_series`/`x_series` field (e.g. as emitted by `from_dss`/PowerIO, or by
hand-written JSON that pre-dates the per-winding field names).  Migrates them to
`r_series_from`/`x_series_from` with `r_series_to = x_series_to = 0.0`, matching
the per-winding T convention that the OPF and Ybus builders consume.

Transformers are stored nested by subtype (`net["transformer"][subtype][id]`),
so the subtype is taken from the parent key.  This runs unconditionally so that
lumped transformers from any source are normalised before downstream code sees
them.
"""
function _migrate_transformer_series_fields!(net::Dict{String,Any})
    xfmrs = get(net, "transformer", nothing)
    xfmrs isa Dict || return
    for (subtype, subdict) in xfmrs
        subtype in ("wye_delta", "delta_wye") || continue
        subdict isa Dict || continue
        for (id, xfmr) in subdict
            xfmr isa Dict || continue
            _migrate_one_transformer_series_fields!(net, xfmr, id, subtype)
        end
    end
end

function _migrate_one_transformer_series_fields!(net::Dict{String,Any},
                                                 xfmr::Dict, id, subtype)
    has_legacy_r = haskey(xfmr, "r_series")
    has_legacy_x = haskey(xfmr, "x_series")
    has_new_r    = haskey(xfmr, "r_series_from")
    has_new_x    = haskey(xfmr, "x_series_from")

    # Only migrate if a lumped field is present and per-winding fields are absent.
    (has_legacy_r || has_legacy_x) && !has_new_r && !has_new_x || return

    # `r_series`/`x_series` is already referred to the wye winding's base
    # (powerio-dist's `referred_resistance`/`referred_ohms` in `three_phase`
    # both take `v_wye2`/`zb` from the wye winding regardless of which side
    # it sits on). `_yprim_yd`/the OPF builder re-refer whichever side is the
    # DELTA winding down to the wye base via (n_ph/n_eff0²); routing the
    # already-wye-referred lump through that path applies the referral twice.
    # `wye_delta` (Yd) has wye = from, so the lump belongs on r/x_series_from
    # (the delta side then reads zero and picks up no extra referral).
    # `delta_wye` (Dy) has wye = to, so the lump belongs on r/x_series_to.
    wye_side = subtype == "wye_delta" ? "from" : "to"
    delta_side = wye_side == "from" ? "to" : "from"
    if has_legacy_r
        xfmr["r_series_$(wye_side)"]   = Float64(xfmr["r_series"])
        xfmr["r_series_$(delta_side)"] = 0.0
        delete!(xfmr, "r_series")
    end
    if has_legacy_x
        xfmr["x_series_$(wye_side)"]   = Float64(xfmr["x_series"])
        xfmr["x_series_$(delta_side)"] = 0.0
        delete!(xfmr, "x_series")
    end
    meta = get!(net, "_meta", Dict{String,Any}())
    notes = get!(meta, "migration_notes", Any[])
    push!(notes, Dict(
        "code"      => "W.MIGRATE.XFMR_SERIES_FIELDS",
        "id"        => id,
        "subtype"   => subtype,
        "message"   => "Migrated lumped r_series/x_series (wye-referred) onto the wye " *
                        "winding's r/x_series_$(wye_side) (r/x_series_$(delta_side)=0).",
    ))
end

"""
    _migrate_field_renames!(net::Dict{String,Any}) -> nothing

In-place, unconditional rename of legacy field names to the current spec so that
JSON written against an earlier schema still parses. Renames (old → new):

  * capacitor `v_rated` → `v_nom`
  * two-winding / three-phase / autotransformer / open-delta transformer
    `v_ref_from`/`v_ref_to` → `v_nom_from`/`v_nom_to`
  * n_winding winding `v_ref` → `v_nom`, `connection` → `configuration`
  * ibr `voltage_ref` → `voltage_aggregation`

The open-delta `connection` (phase-pair wiring, ABBC/BCAC/CABA) is a distinct
concept from a winding's `configuration` and is deliberately left unchanged.
Only renames when the old key is present and the new key is absent, so already
current files are untouched.
"""
function _migrate_field_renames!(net::Dict{String,Any})
    _rename!(d, old, new) = begin
        d isa AbstractDict && haskey(d, old) && !haskey(d, new) || return false
        d[new] = d[old]; delete!(d, old); true
    end

    renamed = false

    # capacitor v_rated -> v_nom
    caps = get(net, "capacitor", nothing)
    if caps isa AbstractDict
        for (_, c) in caps
            renamed |= _rename!(c, "v_rated", "v_nom")
        end
    end

    # ibr voltage_ref -> voltage_aggregation
    ibrs = get(net, "ibr", nothing)
    if ibrs isa AbstractDict
        for (_, inv) in ibrs
            renamed |= _rename!(inv, "voltage_ref", "voltage_aggregation")
        end
    end

    # transformers, nested by subtype
    xfmrs = get(net, "transformer", nothing)
    if xfmrs isa AbstractDict
        for (subtype, subdict) in xfmrs
            subdict isa AbstractDict || continue
            for (_, xfmr) in subdict
                xfmr isa AbstractDict || continue
                renamed |= _rename!(xfmr, "v_ref_from", "v_nom_from")
                renamed |= _rename!(xfmr, "v_ref_to",   "v_nom_to")
                if subtype == "n_winding"
                    ws = get(xfmr, "windings", nothing)
                    if ws isa AbstractVector
                        for w in ws
                            w isa AbstractDict || continue
                            renamed |= _rename!(w, "v_ref", "v_nom")
                            renamed |= _rename!(w, "connection", "configuration")
                        end
                    end
                end
            end
        end
    end

    if renamed
        meta  = get!(net, "_meta", Dict{String,Any}())
        notes = get!(meta, "migration_notes", Any[])
        push!(notes, Dict(
            "code"    => "W.MIGRATE.FIELD_RENAMES",
            "message" => "Renamed legacy fields to current spec (v_rated/v_ref*→v_nom*, " *
                         "winding connection→configuration, ibr voltage_ref→voltage_aggregation).",
        ))
    end
    return nothing
end

"""
    _reject_scalar_v_bounds!(net::Dict{String,Any}) -> nothing

Ingest gate: `v_min`/`v_max` are per-phase arrays (one entry per phase terminal,
phase-to-ground). A scalar value is a pre-migration shape and is rejected with a
clear `ArgumentError` rather than silently coerced — the caller must migrate the
file (e.g. wrap the scalar `s` as `fill(s, n_phase)`). The neutral bound is the
separate, optional, maximum-only `vn_max`.
"""
function _reject_scalar_v_bounds!(net::Dict{String,Any})
    buses = get(net, "bus", nothing)
    buses isa Dict || return
    for (bid, bus) in buses
        bus isa Dict || continue
        for field in ("v_min", "v_max")
            haskey(bus, field) || continue
            bus[field] isa AbstractVector && continue
            throw(ArgumentError(
                "Bus '$bid' field `$field` is a scalar; it must be a per-phase " *
                "array (one entry per phase terminal, phase-to-ground, in " *
                "`terminal_names` phase order). Migrate the file by wrapping the " *
                "scalar in an array of the correct length, e.g. `[$(bus[field]), …]`. " *
                "The neutral bound is the separate optional `vn_max` (max only)."))
        end
    end
end

"""
    _fold_transformer_extras!(net::Dict{String,Any}) -> nothing

In-place, unconditional fold of transformer fields that BMOPF schema 0.1.0
writers park under `extras.transformer.<subtype>.<name>` back onto the
transformer objects downstream code reads.

Schema 0.1.0 sets `additionalProperties: false` on every transformer subtype
and defines no slot for taps, neutral impedance, or no-load admittance, so a
conforming writer (powerio v0.8.0+) moves exactly these fields out of the
subtype objects:

  `tap`, `tap_min`, `tap_max`, `r_neutral_from`, `x_neutral_from`,
  `r_neutral_to`, `x_neutral_to`, `g_no_load`, `b_no_load`

for the subtypes `single_phase`, `center_tap`, `wye_delta`, and `delta_wye`
(`n_winding` is left alone by the writer and so also here). Without this fold
the fields silently cease to exist for the Ybus/OPF builders and `to_pmd`: a
tapped transformer becomes nominal-tap, an impedance-grounded neutral becomes
solidly grounded, and the magnetising branch vanishes — with no error.

A field already present on the transformer wins (never overwrite); emptied
containers are pruned so a fully-folded document carries no residue. Folds are
recorded under `net["_meta"]["migration_notes"]`.
"""
function _fold_transformer_extras!(net::Dict{String,Any})
    extras = get(net, "extras", nothing)
    extras isa Dict || return
    parked = get(extras, "transformer", nothing)
    parked isa Dict || return
    xfmrs = get(net, "transformer", nothing)
    xfmrs isa Dict || return

    folded_fields = (
        "tap", "tap_min", "tap_max",
        "r_neutral_from", "x_neutral_from", "r_neutral_to", "x_neutral_to",
        "g_no_load", "b_no_load",
    )
    for (subtype, bytransformer) in parked
        bytransformer isa Dict || continue
        subdict = get(xfmrs, subtype, nothing)
        subdict isa Dict || continue
        for (id, overflow) in bytransformer
            overflow isa Dict || continue
            xfmr = get(subdict, id, nothing)
            xfmr isa Dict || continue
            moved = String[]
            for field in folded_fields
                haskey(overflow, field) && !haskey(xfmr, field) || continue
                xfmr[field] = overflow[field]
                delete!(overflow, field)
                push!(moved, field)
            end
            isempty(moved) && continue
            meta  = get!(net, "_meta", Dict{String,Any}())
            notes = get!(meta, "migration_notes", Any[])
            push!(notes, Dict(
                "code"    => "W.MIGRATE.XFMR_EXTRAS_FOLD",
                "id"      => id,
                "subtype" => subtype,
                "fields"  => moved,
                "message" => "Folded $(join(moved, ", ")) back from " *
                             "extras.transformer.$subtype (BMOPF schema 0.1.0 " *
                             "relocation) onto the transformer.",
            ))
        end
        # Prune what the fold emptied so a round-trip carries no residue.
        for (id, overflow) in collect(bytransformer)
            overflow isa Dict && isempty(overflow) && delete!(bytransformer, id)
        end
    end
    for (subtype, bytransformer) in collect(parked)
        bytransformer isa Dict && isempty(bytransformer) && delete!(parked, subtype)
    end
    isempty(parked) && delete!(extras, "transformer")
    return nothing
end

"""
    _fold_dropped_top_level_extras!(net::Dict{String,Any}) -> nothing

In-place, unconditional fold of the whole-table BMOPF classes that schema
0.1.0 dropped from the top level (`additionalProperties: false` on the
document root, no slot for `ibr`, `control_profile`, `dc_bus`, `dc_load`,
`dc_source`, or `time_series`). powerio's writer re-emits every one of these
under `extras.<name>` (`RAW_BMOPF_EXTRAS_TABLES` in `powerio-dist`); this
raises them back onto `net[name]`, matching the tables every reader in this
package (`COMPONENT_COLLECTIONS`, `get_snapshot`, `analyze`) still expects at
the top level. Without the fold a network with IBRs or DC-side components
parses to zero of them — no error, just an invisible device.

`dc_line` is powerio's name for what this package calls `dc_branch`; the
fold renames it on the way back. powerio has no `dc_grounding` counterpart at
all (a capability gap, not a relocation), so that table is never populated by
`from_dss` regardless of this fold. A table already present at the top level
wins (never overwrite); an emptied `extras` entry is pruned. Folds are
recorded under `net["_meta"]["migration_notes"]`.
"""
function _fold_dropped_top_level_extras!(net::Dict{String,Any})
    extras = get(net, "extras", nothing)
    extras isa Dict || return

    # extras key => top-level key (identity unless noted).
    dropped_tables = (
        "ibr" => "ibr",
        "control_profile" => "control_profile",
        "dc_bus" => "dc_bus",
        "dc_line" => "dc_branch",   # powerio's name; BMOPFTools calls it dc_branch
        "dc_load" => "dc_load",
        "dc_source" => "dc_source",
        "time_series" => "time_series",
    )
    moved = String[]
    for (extras_key, top_key) in dropped_tables
        table = get(extras, extras_key, nothing)
        (table isa Dict && !isempty(table)) || continue
        if haskey(net, top_key) && net[top_key] isa Dict
            # The top level is the document's authoritative representation.
            # Fold only ids that are missing there; a duplicate parked under
            # `extras` must not replace an explicit top level value.
            for (id, value) in table
                get!(net[top_key], id, value)
            end
        else
            net[top_key] = table
        end
        delete!(extras, extras_key)
        push!(moved, top_key)
    end
    isempty(moved) && return
    meta  = get!(net, "_meta", Dict{String,Any}())
    notes = get!(meta, "migration_notes", Any[])
    push!(notes, Dict(
        "code"    => "W.MIGRATE.TOP_LEVEL_EXTRAS_FOLD",
        "tables"  => moved,
        "message" => "Folded $(join(moved, ", ")) back from extras (BMOPF " *
                     "schema 0.1.0 relocation) onto the top-level network dict.",
    ))
    return nothing
end

"""
    _normalize_load_models!(net::Dict{String,Any}) -> nothing

In-place, unconditional lowercasing of load `model` values. The upstream BMOPF
schema moved the enum to uppercase (`CONSTANT_POWER`, `ZIP`, ...) and powerio
v0.8.0 writes it that way, while every comparison in this package — and the
bundled schema's enum — is lowercase. Without normalization an uppercase value
matches no branch, so a ZIP or constant-impedance load is silently modelled as
constant power AND `schema_check` flags the value: wrong physics with a
misleading finding.

Lowercasing at ingest keeps the rest of the package byte-stable, and the round
trip is safe: powerio's reader uppercases `model` on read, so documents this
package writes with lowercase models are read identically. Normalizations are
recorded once under `net["_meta"]["migration_notes"]`.
"""
function _normalize_load_models!(net::Dict{String,Any})
    loads = get(net, "load", nothing)
    loads isa Dict || return
    changed = String[]
    for (id, load) in loads
        load isa Dict || continue
        model = get(load, "model", nothing)
        model isa AbstractString || continue
        lowered = lowercase(model)
        lowered == model && continue
        load["model"] = lowered
        push!(changed, String(id))
    end
    isempty(changed) && return nothing
    meta  = get!(net, "_meta", Dict{String,Any}())
    notes = get!(meta, "migration_notes", Any[])
    push!(notes, Dict(
        "code"    => "W.MIGRATE.LOAD_MODEL_CASE",
        "ids"     => sort!(changed),
        "message" => "Lowercased load `model` values (the upstream schema " *
                     "moved the enum to uppercase; this package and its " *
                     "bundled schema use lowercase).",
    ))
    return nothing
end
