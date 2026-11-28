"""
    augment_case(net; recipe=default_recipe(), analysis=nothing, config=_DEFAULT_CONFIG)
        -> (net′::Dict{String,Any}, manifest::TransformationManifest)

Derive a candidate benchmark by injecting selected study bounds and assumptions
for absent fields. The manifest records these choices; successful augmentation
does not establish physical feasibility or standards compliance.

`net` is never mutated.  The returned `net′` is an independent deep copy.

# Arguments
- `net`      — a BMOPF network dict (from [`parse_bmopf`](@ref) or
               [`from_dss`](@ref))
- `recipe`   — an [`AugmentationRecipe`](@ref) controlling which passes run
               and what defaults to use; see [`default_recipe`](@ref)
- `analysis` — the [`SummaryReport`](@ref) returned by [`analyze`](@ref) on
               this `net`, its `results`, or a dict with `"voltage_levels"`
               and/or `"provenance"` entries; a missing entry is computed
               internally, and an `analysis` holding neither is an
               `ArgumentError`. If `nothing`, both are computed internally
- `config`   — tunable thresholds (see `load_config`); currently drives
               optional voltage-level snapping (`[augment.voltage_snap]`), which
               snaps each bus's derived nominal to a standard IEC/ANSI level and
               writes `v_declared` before the bounds pass. Off by default.

# Returns
A 2-tuple `(net′, manifest)` where:
- `net′` is the augmented network dict
- `manifest` is a [`TransformationManifest`](@ref) recording every field
  written, the standards rule that motivated it, and benchmark-readiness
  findings before and after augmentation

# Passes (in order)
0. **Voltage snapping** *(optional)* — snap each bus's derived nominal to a
   standard IEC 60038 / ANSI C84.1 level and write `v_declared`
   (`[augment.voltage_snap]` in `config`; off by default)
1. **Voltage bounds** — `v_min`/`v_max`, `vpn_min`/`vpn_max`,
   `vpp_min`/`vpp_max`, `vuf_max` on supported buses (instantaneous study policies)
2. **Thermal limits** — opt-in synthetic `i_max` estimates from R₁₁; no verified ampacity claim
3. **Generation** — slack generator at source buses; `q_min`/`q_max` on
   existing generators with `p_max` (cos φ capability, EN 50549-1 default)
4. **IBR bounds** — missing P and Q bounds on IBRs (`apply_ibr`)
5. **Smart-IBR controls** — Volt-var / Volt-watt defaults (AS/NZS 4777.2;
   `[augment.smart_ibr]` in `config`)
6. **DC network** — `dc_bus` bounds and `dc_source` dispatch (`apply_dc`)

Passes 1b (intra-bus angle-difference bounds, `apply_va_diff_bounds`) and the
power-to-current conversion after pass 2 also run. Each pass is controlled by
the recipe's `apply_*` flags or its `config` section.
Existing values are not overwritten; a scalar single-phase `i_max` is
reshaped to its per-conductor vector form.

# Example
```julia
net    = parse_bmopf("my_feeder.json")
net′, manifest = augment_case(net)
render_manifest(manifest)
result = solve_opf(net′)
```
"""
function augment_case(net::Dict{String,Any};
                       recipe::AugmentationRecipe = default_recipe(),
                       analysis = nothing,
                       config::Dict = _DEFAULT_CONFIG)::Tuple{Dict{String,Any}, TransformationManifest}

    analysis = _normalize_analysis(analysis, ("voltage_levels", "provenance"),
                                   "augment_case")
    net′   = deepcopy(net)
    _materialize_roles_if_valid!(net′)
    entries = TransformEntry[]

    # ── Snapshot findings_before ─────────────────────────────────────────────
    fb = Finding[]
    benchmark_readiness_check(net, fb)

    # ── Resolve sub-analyses ──────────────────────────────────────────────────
    vl_result   = _resolve_voltage_levels(net, analysis)
    prov_result = _resolve_provenance(net, analysis)

    bus_voltage_map = get(vl_result, "bus_voltage_map", Dict{String,Float64}())

    # linecode id => classification string ("distinct", "near_balanced", ...)
    lc_classifications = _extract_lc_classifications(prov_result)

    # ── Pass 0: voltage-level snapping (optional, config-driven) ──────────────
    # Snap each bus's derived nominal to a standard IEC/ANSI level and write
    # v_declared, so the bounds pass references the standardized voltage.
    _apply_voltage_snap!(net′, entries, _voltage_snap_cfg(config), bus_voltage_map)

    # ── Pass 1: voltage bounds ────────────────────────────────────────────────
    _apply_voltage_bounds!(net′, entries, recipe, bus_voltage_map)

    # ── Pass 1b: intra-bus angle-difference bounds (opt-in) ──────────────────
    recipe.apply_va_diff_bounds && _apply_angle_diff_bounds!(net′, entries, recipe)

    # ── Pass 2: thermal limits ────────────────────────────────────────────────
    _apply_thermal!(net′, entries, recipe, lc_classifications; config)
    # Opt-in: convert per-conductor s_max on lines/switches into i_max (I = S/v_ref).
    _apply_power_to_current!(net′, entries, recipe, bus_voltage_map)

    # ── Pass 3: generation ────────────────────────────────────────────────────
    _apply_generation!(net′, entries, recipe)
    _normalize_single_phase_imax!(net′, entries)

    # ── Pass 4: IBR dispatch bounds ─────────────────────────────────────
    recipe.apply_ibr && _apply_ibr_augmentation!(net′, entries, recipe)

    # ── Pass 5: smart-IBR Volt-var/Volt-watt defaults (config-driven) ───
    _apply_smart_ibr_augmentation!(net′, entries, _smart_ibr_cfg(config))

    # ── Pass 6: DC network defaults (dc_bus bounds, dc_source dispatch) ──
    recipe.apply_dc && _apply_dc_network_augmentation!(net′, entries, recipe)

    # ── Snapshot findings_after ───────────────────────────────────────────────
    fa = Finding[]
    benchmark_readiness_check(net′, fa)

    manifest = TransformationManifest(
        string(Dates.now()),
        recipe,
        entries,
        fb,
        fa,
    )

    (net′, manifest)
end

# ── Internal helpers ─────────────────────────────────────────────────────────

# Accepted `analysis` keys per sub-result; the first present one is used.
const _ANALYSIS_KEYS = Dict(
    "voltage_levels" => ("voltage_levels", "voltage_level_analysis", "levels"),
    "provenance"     => ("provenance", "provenance_analysis"),
    "connectivity"   => ("connectivity", "connectivity_analysis"),
)

# Normalize the `analysis` keyword of augment_case / add_generators / add_ibrs:
# `nothing`, a `SummaryReport` from `analyze`, its Symbol-keyed `results`, or a
# String-keyed dict. Returns `nothing` or a String-keyed dict. A given analysis
# that holds none of the sub-results `caller` uses is an error rather than
# being silently recomputed; missing individual entries are recomputed.
function _normalize_analysis(analysis, needed::Tuple, caller::AbstractString)
    analysis === nothing && return nothing
    d = if analysis isa SummaryReport
        Dict{String,Any}(String(k) => v for (k, v) in analysis.results)
    elseif analysis isa AbstractDict
        Dict{String,Any}(string(k) => v for (k, v) in analysis)
    else
        throw(ArgumentError("$caller: `analysis` must be `nothing`, a " *
            "SummaryReport from `analyze`, or a dict of analysis results; " *
            "got $(typeof(analysis))."))
    end
    accepted = [k for n in needed for k in _ANALYSIS_KEYS[n]]
    any(k -> haskey(d, k), accepted) || throw(ArgumentError(
        "$caller: `analysis` holds none of the expected sub-results " *
        "($(join(accepted, ", "))); pass the SummaryReport returned by " *
        "`analyze`, or omit `analysis` to compute them internally."))
    d
end

function _resolve_voltage_levels(net, analysis)
    if analysis isa Dict
        for k in ("voltage_levels", "voltage_level_analysis", "levels")
            haskey(analysis, k) && return analysis[k]
        end
    end
    voltage_level_analysis(net, Finding[])
end

function _resolve_provenance(net, analysis)
    if analysis isa Dict
        for k in ("provenance", "provenance_analysis")
            haskey(analysis, k) && return analysis[k]
        end
    end
    provenance_analysis(net, Finding[])
end

function _extract_lc_classifications(prov_result::Dict{String,Any})::Dict{String,String}
    out = Dict{String,String}()
    lc_data = get(prov_result, "linecodes", nothing)
    lc_data isa Dict || return out
    # provenance_analysis nests per-linecode data under "by_linecode"
    by_lc = get(lc_data, "by_linecode", lc_data)
    by_lc isa Dict || return out
    for (lcid, info) in by_lc
        info isa Dict || continue
        cls = get(info, "verdict", nothing)
        cls isa String && (out[lcid] = cls)
    end
    out
end
