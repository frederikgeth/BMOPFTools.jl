"""
    AugmentationRecipe

Parameters controlling which augmentation passes run and what default values
they inject.  Every field has a standards-grounded default; override only what
you need.

Construct with keyword arguments:

    recipe = AugmentationRecipe(vpn_lv_pu = (0.85, 1.15))

or use [`default_recipe`](@ref) to get the unmodified defaults.

## Declared supply voltage fallbacks

Voltage bounds are expressed as percentages of a *declared supply voltage*,
not the transformer rated voltage.  The authoritative source is the optional
`v_declared` field on the bus (V).  When absent, the recipe fallbacks below
are used; when those are `nothing`, the bus's `v_nom` from voltage-level
analysis is used as a last resort.

The declared voltage is expressed **per conductor** (phase-to-ground ≈
phase-to-neutral), the same basis as `v_nom`.  Phase-to-neutral bounds use it
directly; phase-to-phase (line-to-line) bounds derive their nominal as
`v_declared × √3`.  Set the fallbacks to the per-conductor declared voltage for
the deployment region, e.g. `v_declared_lv = 230.0` for Europe/Australia
(230 V L-N → 400 V L-L); for an 11 kV (L-L) MV system use
`v_declared_mv = 11000 / √3 ≈ 6350.0`.

Full precedence for the declared voltage, highest first:

1. `bus["v_declared"]` — explicit, set at import time
2. the optional **voltage-snap** pass (`[augment.voltage_snap]` in the TOML
   `config`) — snaps `v_nom` to a standard IEC/ANSI level and writes
   `v_declared`; never overrides an explicit `v_declared`
3. these recipe fallbacks (`v_declared_lv/mv/hv`)
4. `v_nom` from voltage-level analysis

Snapping (off by default) is the recommended way to pull imported 240/250 V
transformers onto the standard 230 V without per-bus editing.
"""
Base.@kwdef struct AugmentationRecipe
    # ── Declared supply voltage fallbacks (V) ────────────────────────────────
    # Used when bus["v_declared"] is absent. `nothing` → fall back to v_nom.
    v_declared_lv :: Union{Float64,Nothing} = nothing   # e.g. 230.0 for EU/AU (L-N)
    v_declared_mv :: Union{Float64,Nothing} = nothing   # e.g. 6350.0 (= 11 kV L-L /√3)
    v_declared_hv :: Union{Float64,Nothing} = nothing

    # ── Phase-to-neutral bounds (four-wire buses with neutral) ────────────────
    # Applied as fractions of the declared phase-to-neutral voltage.
    # EN 50160:2010 §3.5/§3.6: 95-%-of-week criterion, ±10 % for LV and MV.
    # MV operational planning practice often uses ±6 % to budget for downstream
    # voltage drop to LV customers.
    vpn_lv_pu :: Tuple{Float64,Float64} = (0.90, 1.10)   # EN 50160 LV
    vpn_mv_pu :: Tuple{Float64,Float64} = (0.94, 1.06)   # DSO planning MV ±6 %

    # ── Phase-to-phase bounds ─────────────────────────────────────────────────
    # vpp_nom = v_declared × √3 (line-to-line) for both four-wire and three-wire
    # buses, since v_declared is the per-conductor phase-to-ground nominal.
    # For three-wire buses this is the only phase-voltage constraint available.
    # HV (three-wire only in practice): ±5 % transmission planning band.
    vpp_lv_pu :: Tuple{Float64,Float64} = (0.90, 1.10)   # EN 50160 LV ±10 %
    vpp_mv_pu :: Tuple{Float64,Float64} = (0.94, 1.06)   # DSO planning MV ±6 %
    vpp_hv_pu :: Tuple{Float64,Float64} = (0.95, 1.05)   # transmission ±5 %

    # ── Negative-sequence upper bound (EN 50160:2010 §3.5) ───────────────────
    # "Under normal operating conditions … the negative-sequence component
    # shall not exceed 2 % of the positive-sequence component."
    vneg_max_pu :: Float64 = 0.02

    # ── Intra-bus angle-difference window ─────────────────────────────────────
    # Symmetric window (radians) injected as va_diff_min = −window, va_diff_max =
    # +window around the nominal phase offset (va_nom). ±30° pins the positive-
    # sequence rotation while staying well inside the tangent-valid (−π/2, π/2)
    # regime. Applied to 3-phase (va_nom = [0,−2π/3,2π/3]) and split-phase
    # (va_nom = [0,π]) buses only. Off by default (stricter, init-sensitive).
    va_diff_window_rad :: Float64 = 0.5236   # ≈ 30°

    # ── Solver regularisation: phase-to-ground envelope ──────────────────────
    # This is a hyperparameter, not a power-quality guarantee.  It widens the
    # feasible set so the solver has room to find a feasible point even at the
    # edge of the power-quality window.  Applied to ALL buses that lack v_min/
    # v_max, regardless of voltage level or wire configuration.  Set to
    # `nothing` to disable (no v_min/v_max injection).
    v_min_pu :: Union{Float64,Nothing} = 0.85
    v_max_pu :: Union{Float64,Nothing} = 1.15

    # ── Thermal limits ───────────────────────────────────────────────────────
    conductor_type :: Symbol = :underground   # :underground | :overhead

    # Minimum provenance confidence required before inferring i_max from R₁₁.
    # :high   — only geometry-derived (distinct) matrices
    # :medium — geometry-derived OR near-balanced (default)
    # :low    — any linecode including sequence-derived
    thermal_min_confidence :: Symbol = :medium

    # ── Reactive capability ──────────────────────────────────────────────────
    # EN 50549-1:2019 requires cos φ ≥ 0.90 for LV-connected DERs.
    # Q_max = P_max × tan(arccos(0.90)) ≈ 0.484 × P_max.
    # Set to 0.95 for IEEE 1547-2018 (ANSI) deployments.
    q_capability_pf :: Float64 = 0.90

    # ── Slack generator ──────────────────────────────────────────────────────
    slack_cost :: Float64 = 1.0

    # ── IBR dispatch defaults ────────────────────────────────────────────
    # Default reactive-capability power factor for IBRs that have no
    # power_factor control profile.  EN 50549-1:2019: cos φ ≥ 0.90 for LV DERs.
    ibr_default_pf :: Float64 = 0.90

    # ── DC network defaults ──────────────────────────────────────────────────
    # Fractional band around the nominal line-to-ground DC voltage used to fill
    # missing dc_bus v_dc_min/v_dc_max (e.g. 0.10 → ±10 %). The nominal magnitude
    # is taken from any present |v_dc_min|/|v_dc_max| midpoint, else left absent.
    dc_v_band_frac :: Float64 = 0.10

    # ── Pass enable flags ────────────────────────────────────────────────────
    apply_v_bounds        :: Bool = true
    apply_vpn_bounds      :: Bool = true
    apply_vpp_bounds      :: Bool = true
    apply_vneg_bounds     :: Bool = true
    apply_va_diff_bounds  :: Bool = false   # opt-in: angle constraints are init-sensitive
    apply_thermal         :: Bool = true
    # Convert per-conductor apparent-power limits (s_max) on lines/switches that
    # lack a current limit into an equivalent i_max = s_max / v_ref. Opt-in: the
    # conversion is only exact at the reference voltage, and current is the
    # preferred thermal representation for lines/switches. Transformers are never
    # converted — they keep the apparent-power nameplate as canonical.
    apply_power_to_current :: Bool = false
    apply_q_bounds        :: Bool = true
    apply_slack_generator :: Bool = true
    apply_ibr        :: Bool = true
    apply_dc         :: Bool = true
end

"""
    default_recipe() -> AugmentationRecipe

Return an [`AugmentationRecipe`](@ref) with all defaults as specified in the
package documentation.
"""
default_recipe() = AugmentationRecipe()
