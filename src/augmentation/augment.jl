"""
    augment_case(net; recipe=default_recipe(), analysis=nothing, config=_DEFAULT_CONFIG)
        -> (net′::Dict{String,Any}, manifest::TransformationManifest)

Derive a benchmark-ready version of `net` by injecting standards-grounded
default bounds and constraints for any fields that are absent.

`net` is never mutated.  The returned `net′` is an independent deep copy.

# Arguments
- `net`      — a BMOPF network dict (from [`parse_bmopf`](@ref) or
               [`from_dss`](@ref))
- `recipe`   — an [`AugmentationRecipe`](@ref) controlling which passes run
               and what defaults to use; see [`default_recipe`](@ref)
- `analysis` — output of [`analyze`](@ref) or a dict containing at least
               `"voltage_levels"` and `"provenance"` sub-results; if `nothing`
               the relevant sub-analyses are run internally
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
   `vpp_min`/`vpp_max`, `vneg_max` on buses (EN 50160, DSO planning practice)
2. **Thermal limits** — `i_max` on linecodes inferred from R₁₁ via IEC 60228
3. **Generation** — slack generator at source buses; `q_min`/`q_max` on
   existing generators with `p_max` (EN 50549 / IEEE 1547)

Each pass is independently skippable via the recipe's `apply_*` flags.
Existing values are never overwritten.

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

    net′   = deepcopy(net)
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
    # v_declared, so the bounds pass references the standardised voltage.
    _apply_voltage_snap!(net′, entries, _voltage_snap_cfg(config), bus_voltage_map)

    # ── Pass 1: voltage bounds ────────────────────────────────────────────────
    _apply_voltage_bounds!(net′, entries, recipe, bus_voltage_map)

    # ── Pass 2: thermal limits ────────────────────────────────────────────────
    _apply_thermal!(net′, entries, recipe, lc_classifications)

    # ── Pass 3: generation ────────────────────────────────────────────────────
    _apply_generation!(net′, entries, recipe)

    # ── Pass 4: inverter dispatch bounds ─────────────────────────────────────
    recipe.apply_inverter && _apply_inverter_augmentation!(net′, entries, recipe)

    # ── Pass 5: smart-inverter Volt-var/Volt-watt defaults (config-driven) ───
    _apply_smart_inverter_augmentation!(net′, entries, _smart_inverter_cfg(config))

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
