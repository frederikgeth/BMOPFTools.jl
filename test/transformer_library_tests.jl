using Test
using BMOPFTools

# ---------------------------------------------------------------------------
# Transformer parameter library + snapping
# ---------------------------------------------------------------------------

# Minimal single_phase transformer (L-N, has neutral on the from side) with all
# snap-able parameters zeroed/absent. Z_base = v_ref_from²/s_rating.
function _txlib_single(; vf = 11000.0, vt = 240.0, s = 100_000.0,
                         rfrom = 0.0, xfrom = 0.0)
    Dict{String,Any}(
        "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
            "tx" => Dict{String,Any}(
                "bus_from" => "mv", "bus_to" => "lv",
                "terminal_map_from" => ["a", "n"], "terminal_map_to" => ["a", "n"],
                "v_ref_from" => vf, "v_ref_to" => vt, "s_rating" => s,
                "r_series_from" => rfrom, "x_series_from" => xfrom,
                "r_series_to" => 0.0, "x_series_to" => 0.0))))
end

@testset "Transformer parameter library (snapping)" begin

    @testset "single_phase: %Z and X/R from library" begin
        net = _txlib_single(; s = 100_000.0)   # 100 kVA → z_pct 4.0, xr 2.5
        entries = apply_snap_transformer_library!(net)
        t = net["transformer"]["single_phase"]["tx"]

        R = t["r_series_from"]; X = t["x_series_from"]
        @test R > 0 && X > 0
        # Percentage impedance lands on the library z_pct (4.0 %).
        @test BMOPFTools._xfmr_z_pu(t, R, X) ≈ 0.04 atol = 1e-9
        # X/R matches the library ratio (2.5).
        @test X / R ≈ 2.5 rtol = 1e-9
        # No-load shunt and tap range were filled too.
        @test t["g_no_load"] > 0 && t["b_no_load"] > 0
        @test t["tap_min"] == 0.95 && t["tap_max"] == 1.10
        @test any(e -> e.rule == "snap_transformer_library" && e.field == "x_series_from",
                  entries)
    end

    @testset "nearest-rating match (off-ladder)" begin
        net = _txlib_single(; s = 120_000.0)   # nearest entry is 100 kVA (z_pct 4.0)
        apply_snap_transformer_library!(net)
        t = net["transformer"]["single_phase"]["tx"]
        @test BMOPFTools._xfmr_z_pu(t, t["r_series_from"], t["x_series_from"]) ≈ 0.04 atol = 1e-9

        net2 = _txlib_single(; s = 30_000.0)   # nearest is 25 kVA (z_pct 3.3)
        apply_snap_transformer_library!(net2)
        t2 = net2["transformer"]["single_phase"]["tx"]
        @test BMOPFTools._xfmr_z_pu(t2, t2["r_series_from"], t2["x_series_from"]) ≈ 0.033 atol = 1e-9
    end

    @testset "three_phase delta_wye: single series impedance on from base" begin
        net = Dict{String,Any}(
            "transformer" => Dict{String,Any}("delta_wye" => Dict{String,Any}(
                "tx" => Dict{String,Any}(
                    "bus_from" => "mv", "bus_to" => "lv",
                    "terminal_map_from" => ["a", "b", "c"],
                    "terminal_map_to" => ["a", "b", "c", "n"],
                    "v_ref_from" => 11000.0, "v_ref_to" => 433.0, "s_rating" => 200_000.0,
                    "r_series" => 0.0, "x_series" => 0.0))))
        apply_snap_transformer_library!(net)
        t = net["transformer"]["delta_wye"]["tx"]
        @test haskey(t, "r_series") && haskey(t, "x_series")
        @test !haskey(t, "r_series_from")          # schema-correct target field
        @test BMOPFTools._xfmr_z_pu(t, t["r_series"], t["x_series"]) ≈ 0.04 atol = 1e-9
        @test t["x_series"] / t["r_series"] ≈ 3.5 rtol = 1e-9   # 200 kVA xr
        @test t["g_no_load"] > 0
    end

    @testset "line-to-line single_phase: no neutral ⇒ shunt skipped" begin
        net = _txlib_single()
        net["transformer"]["single_phase"]["tx"]["terminal_map_from"] = ["a", "b"]
        apply_snap_transformer_library!(net)
        t = net["transformer"]["single_phase"]["tx"]
        @test t["x_series_from"] > 0          # leakage still filled
        @test !haskey(t, "g_no_load")         # shunt correctly skipped
    end

    @testset "overwrite policy" begin
        # Realistic existing leakage is preserved by default …
        net = _txlib_single(; rfrom = 50.0, xfrom = 121.0)
        apply_snap_transformer_library!(net)
        t = net["transformer"]["single_phase"]["tx"]
        @test t["x_series_from"] == 121.0
        @test t["r_series_from"] == 50.0

        # … but overwrite=true re-snaps every covered field.
        net2 = _txlib_single(; rfrom = 50.0, xfrom = 121.0)
        apply_snap_transformer_library!(net2; overwrite = true)
        t2 = net2["transformer"]["single_phase"]["tx"]
        @test t2["x_series_from"] != 121.0
        @test BMOPFTools._xfmr_z_pu(t2, t2["r_series_from"], t2["x_series_from"]) ≈ 0.04 atol = 1e-9
    end

    @testset "fix_case integration (opt-in) + ideal-flag cleared" begin
        net = _txlib_single(; s = 100_000.0)
        disabled = (apply_largest_component = false, apply_simplify_network = false,
                    apply_remove_zero_loads = false, apply_low_impedance_to_switch = false,
                    apply_source_bus_bounds = false)

        # Off by default: untouched.
        net_def, _ = fix_case(net; recipe = FixRecipe(; disabled...))
        @test net_def["transformer"]["single_phase"]["tx"]["x_series_from"] == 0.0

        net′, mf = fix_case(net;
            recipe = FixRecipe(; disabled..., apply_snap_transformer_library = true))
        t = net′["transformer"]["single_phase"]["tx"]
        @test t["x_series_from"] > 0
        @test any(e -> e.rule == "snap_transformer_library", mf.entries)

        # The snapped unit is no longer flagged ideal, and %Z is in [3%, 8%].
        f = Finding[]
        BMOPFTools._check_transformer_ideal(net′, f, Dict{String,Any}(), Ref(0))
        @test !any(x -> x.code == "I.DOM.XFMR_IDEAL" && x.component_id == "tx", f)
        zpu = BMOPFTools._xfmr_z_pu(t, t["r_series_from"], t["x_series_from"])
        @test 0.03 <= zpu <= 0.08
    end

    @testset "voltage gate: transmission-class unit not snapped" begin
        net = _txlib_single(; vf = 132_000.0, vt = 11000.0, s = 100_000.0)
        entries = apply_snap_transformer_library!(net)
        @test isempty(entries)
        @test net["transformer"]["single_phase"]["tx"]["x_series_from"] == 0.0
    end
end
