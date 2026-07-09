using Test
using BMOPFTools

# ---------------------------------------------------------------------------
# Shared minimal fixtures
# ---------------------------------------------------------------------------

# Three-phase 4-wire LV feeder (230/400 V) with one load — no bounds, no limits.
function _lv_net()
    parse_bmopf("""
    {"bus":{
        "src":{"terminal_names":["1","2","3","n"],
               "perfectly_grounded_terminals":["n"]},
        "b1": {"terminal_names":["1","2","3","n"],
               "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src",
         "terminal_map":["1","2","3"],
         "v_magnitude":[230.0,230.0,230.0],
         "v_angle":[0.0,-2.0944,2.0944]}},
     "linecode":{"lc":{"R_series_1_1":0.000396,"R_series_2_2":0.000396,
                       "R_series_3_3":0.000396,"R_series_4_4":0.000396}},
     "line":{"l1":{"bus_from":"src","bus_to":"b1",
         "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
         "linecode":"lc","length":100.0}},
     "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
         "configuration":"WYE",
         "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
    """; from_string=true)
end

# Two-level MV→LV feeder (no bounds anywhere)
function _mv_lv_net()
    parse_bmopf("""
    {"bus":{
        "mv_src":{"terminal_names":["a","b","c","n"],
                  "perfectly_grounded_terminals":["n"]},
        "lv_bus":{"terminal_names":["1","2","3","n"],
                  "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"mv_src",
         "terminal_map":["a","b","c"],
         "v_magnitude":[6350.0,6350.0,6350.0],
         "v_angle":[0.0,-2.0944,2.0944]}},
     "transformer":{"single_phase":{"tx":{"bus_from":"mv_src","bus_to":"lv_bus",
         "terminal_map_from":["a","b","c"],
         "terminal_map_to":["1","2","3"],
         "s_rating":100000.0,
         "v_nom_from":11000.0,"v_nom_to":400.0,
         "r_series_from":1.0,"r_series_to":0.01,
         "x_series_from":5.0,"x_series_to":0.05}}},
     "load":{"ld":{"bus":"lv_bus","terminal_map":["1","2","3","n"],
         "configuration":"WYE",
         "p_nom":[2000.0,2000.0,2000.0],"q_nom":[0.0,0.0,0.0]}}}
    """; from_string=true)
end

# LV net with a dispatchable generator (has p_max, no q bounds)
function _lv_net_with_gen()
    net = _lv_net()
    get!(net, "generator", Dict{String,Any}())["g1"] = Dict{String,Any}(
        "bus"           => "b1",
        "terminal_map"  => ["1","2","3","n"],
        "configuration" => "WYE",
        "p_min"         => [0.0, 0.0, 0.0],
        "p_max"         => [500.0, 500.0, 500.0],
        "cost"          => [10.0, 10.0, 10.0],
    )
    net
end

# ── T1: Voltage bounds ───────────────────────────────────────────────────────

@testset "T1: Voltage bounds — LV" begin
    net  = _lv_net()
    net′, mf = augment_case(net)

    b1 = net′["bus"]["b1"]

    # v_min / v_max: per-phase arrays, 230 V nominal × 0.85 / 1.15
    @test all(≈(230.0 * 0.85; atol=1e-6), b1["v_min"])
    @test all(≈(230.0 * 1.15; atol=1e-6), b1["v_max"])
    @test length(b1["v_min"]) == 3 && length(b1["v_max"]) == 3

    # vpn: per-phase array (length = n_phase = 3); v_declared is per-conductor
    # (phase-to-neutral), so vpn_nom = 230 × pu — no √3 division.
    v_pn = 230.0
    @test b1["vpn_min"] isa Vector && length(b1["vpn_min"]) == 3
    @test b1["vpn_max"] isa Vector && length(b1["vpn_max"]) == 3
    @test all(b1["vpn_min"] .≈ v_pn * 0.90)
    @test all(b1["vpn_max"] .≈ v_pn * 1.10)

    # vpp: per-pair array (length = n_pairs = 3 for 3 phases); line-to-line
    # nominal = 230 × √3 ≈ 398 V, so vpp_nom = 230√3 × pu.
    v_pp = 230.0 * sqrt(3.0)
    @test b1["vpp_min"] isa Vector && length(b1["vpp_min"]) == 3
    @test b1["vpp_max"] isa Vector && length(b1["vpp_max"]) == 3
    @test all(b1["vpp_min"] .≈ v_pp * 0.90)
    @test all(b1["vpp_max"] .≈ v_pp * 1.10)

    # vneg_max: 2% of v_pn
    @test b1["vneg_max"] ≈ v_pn * 0.02  atol=1e-6

    # Source bus gets v_min/v_max but NOT vpn/vpp/vneg
    src = net′["bus"]["src"]
    @test haskey(src, "v_min")
    @test !haskey(src, "vpn_min")
    @test !haskey(src, "vpp_min")
    @test !haskey(src, "vneg_max")

    # Manifest records the entries
    @test length(mf.entries) > 0
    fields_written = [e.field for e in mf.entries if e.component_id == "b1"]
    @test "v_min"    in fields_written
    @test "vpn_min"  in fields_written
    @test "vpp_min"  in fields_written
    @test "vneg_max" in fields_written
end

@testset "T1: Voltage bounds — physically bracket actual voltages" begin
    # Regression for the 4-wire bounds bug: the injected vpn/vpp bounds must
    # bracket the real operating voltages. For a 230 V (L-N) source with a
    # grounded neutral the actual voltages at b1 are ≈230 V phase-to-neutral
    # and ≈230√3 ≈ 398 V phase-to-phase. The previous (buggy) bounds required
    # vpn ≈ 120-146 V and vpp ≈ 207-253 V — physically impossible.
    net  = _lv_net()
    net′, _ = augment_case(net)
    b1 = net′["bus"]["b1"]

    v_pn_actual = 230.0              # phase-to-neutral (neutral grounded)
    v_pp_actual = 230.0 * sqrt(3.0)  # line-to-line ≈ 398 V

    @test all(b1["vpn_min"] .< v_pn_actual .< b1["vpn_max"])
    @test all(b1["vpp_min"] .< v_pp_actual .< b1["vpp_max"])
end

@testset "T1: Voltage bounds — MV tighter than LV" begin
    net  = _mv_lv_net()
    net′, _ = augment_case(net)

    mv = net′["bus"]["mv_src"]
    lv = net′["bus"]["lv_bus"]

    # v_min/v_max are solver regularisation — same pu band at all levels (per-phase arrays)
    @test all(≈(6350.0 * 0.85; atol=1.0), mv["v_min"])
    @test all(≈(6350.0 * 1.15; atol=1.0), mv["v_max"])

    # MV source bus gets v_min/v_max but NOT vpn/vpp/vneg (source bus)
    @test !haskey(mv, "vpn_min")
    @test !haskey(mv, "vpp_min")

    # LV bus: v_min/v_max use same 0.85/1.15 band
    lv_vnom = get(voltage_level_analysis(net, Finding[])["bus_voltage_map"], "lv_bus", NaN)
    @test all(≈(lv_vnom * 0.85; atol=1.0), lv["v_min"])
    @test all(≈(lv_vnom * 1.15; atol=1.0), lv["v_max"])

    # MV vpn band (±6%) is tighter than LV vpn band (±10%) in per-unit terms
    # lv_bus is a four-wire LV bus so it gets vpn bounds (per-phase array, length 3)
    lv_vpn_nom = lv_vnom
    @test lv["vpn_min"] isa Vector && length(lv["vpn_min"]) == 3
    lv_vpn_range = first(lv["vpn_max"]) - first(lv["vpn_min"])
    @test lv_vpn_range / lv_vpn_nom ≈ 0.20  atol=0.01   # ±10 % → 20 % window
end

@testset "T1: Voltage bounds — never overwrite existing" begin
    net = _lv_net()
    net["bus"]["b1"]["vpn_min"] = 199.0   # deliberately set

    net′, mf = augment_case(net)

    # Pre-existing value unchanged
    @test net′["bus"]["b1"]["vpn_min"] == 199.0

    # vpn_min not in manifest entries for b1
    @test !any(e -> e.component_id == "b1" && e.field == "vpn_min", mf.entries)
end

@testset "T1: Voltage bounds — single-phase bus (no vpp)" begin
    net = parse_bmopf("""
    {"bus":{
        "src":{"terminal_names":["1","n"],
               "perfectly_grounded_terminals":["n"]},
        "b1": {"terminal_names":["1","n"],
               "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
         "v_magnitude":[230.0],"v_angle":[0.0]}},
     "linecode":{"lc":{"R_series_1_1":0.001}},
     "line":{"l1":{"bus_from":"src","bus_to":"b1",
         "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
         "linecode":"lc","length":50.0}},
     "load":{"ld":{"bus":"b1","terminal_map":["1","n"],
         "configuration":"SINGLE_PHASE",
         "p_nom":[500.0],"q_nom":[0.0]}}}
    """; from_string=true)

    net′, _ = augment_case(net)
    b1 = net′["bus"]["b1"]

    @test haskey(b1, "v_min")
    @test haskey(b1, "vpn_min")   # single-phase: vpn still applies
    @test !haskey(b1, "vpp_min")  # only 1 phase terminal → no vpp
    @test !haskey(b1, "vneg_max") # only 1 phase terminal → no vneg
end

# ── T2: Thermal limits ───────────────────────────────────────────────────────

@testset "T2: Thermal — 50 mm² distinct linecode (R₁₁ = 0.396 mΩ/m)" begin
    # Use a "distinct" linecode (non-uniform off-diagonals from a geometry-derived
    # matrix) so provenance_analysis gives verdict = "distinct" → confidence :high.
    # R₁₁ = 0.000396 Ω/m = 0.396 mΩ/m matches 50 mm² underground → 170 A.
    net = parse_bmopf("""
    {"bus":{
        "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
        "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
         "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
     "linecode":{"lc_dist":{
         "R_series_1_1":0.000396,"R_series_2_2":0.000396,"R_series_3_3":0.000396,
         "R_series_1_2":0.000049,"R_series_1_3":0.000052,"R_series_2_3":0.000047,
         "R_series_2_1":0.000049,"R_series_3_1":0.000052,"R_series_3_2":0.000047,
         "X_series_1_1":0.00008,"X_series_2_2":0.00008,"X_series_3_3":0.00008,
         "X_series_1_2":0.00003,"X_series_1_3":0.00002,"X_series_2_3":0.000025,
         "X_series_2_1":0.00003,"X_series_3_1":0.00002,"X_series_3_2":0.000025}},
     "line":{"l1":{"bus_from":"src","bus_to":"b1",
         "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
         "linecode":"lc_dist","length":100.0}},
     "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
         "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
    """; from_string=true)

    net′, mf = augment_case(net)

    lc = net′["linecode"]["lc_dist"]
    @test haskey(lc, "i_max")
    @test length(lc["i_max"]) == 3          # 3 conductors (no neutral in this linecode)
    @test all(x -> x ≈ 170.0, lc["i_max"]) # underground XLPE, 50 mm²

    e = only(filter(x -> x.component_id == "lc_dist" && x.field == "i_max" &&
                         x.new_value !== nothing, mf.entries))
    @test e.new_value == [170.0, 170.0, 170.0]
    @test contains(e.rule, "heuristic_ampacity")
    @test e.confidence == :high   # distinct verdict → :high
end

@testset "T2: Thermal — existing i_max not overwritten" begin
    net = _lv_net()
    net["linecode"]["lc"]["i_max"] = [99.0, 99.0, 99.0, 99.0]

    net′, mf = augment_case(net)

    @test net′["linecode"]["lc"]["i_max"] == [99.0, 99.0, 99.0, 99.0]
    @test !any(e -> e.component_id == "lc" && e.field == "i_max" &&
                    e.new_value !== nothing, mf.entries)
end

@testset "T2: Thermal — R₁₁ outside lookup range → skipped" begin
    net = _lv_net()
    net["linecode"]["lc"]["R_series_1_1"] = 0.00001  # 0.01 mΩ/m — below table minimum

    net′, mf = augment_case(net)

    @test !haskey(net′["linecode"]["lc"], "i_max")
    e = only(filter(x -> x.component_id == "lc" && x.field == "i_max", mf.entries))
    @test contains(e.note, "outside lookup range")
end

@testset "i_max: single-phase length-1 standardised to per-conductor [phase, neutral]" begin
    net = parse_bmopf("""
    {"bus":{"b":{"terminal_names":["1","n"]}},
     "voltage_source":{"vs":{"bus":"b","terminal_map":["1"],"v_magnitude":[230.0],"v_angle":[0.0]}},
     "ibr":{"v":{"bus":"b","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"PV",
         "s_max":[5000.0],"i_max":[20.0]}},
     "generator":{"g":{"bus":"b","terminal_map":["1","n"],"configuration":"SINGLE_PHASE",
         "p_max":[1000.0],"i_max":[15.0]}}}
    """; from_string=true)
    net′, mf = augment_case(net)
    @test net′["ibr"]["v"]["i_max"] == [20.0, 20.0]
    @test net′["generator"]["g"]["i_max"] == [15.0, 15.0]
    @test any(e -> e.component_id == "v" && e.field == "i_max" &&
                   e.new_value == [20.0, 20.0], mf.entries)

    # A length-2 single-phase i_max is already canonical — left untouched.
    net2 = parse_bmopf("""
    {"bus":{"b":{"terminal_names":["1","n"]}},
     "voltage_source":{"vs":{"bus":"b","terminal_map":["1"],"v_magnitude":[230.0],"v_angle":[0.0]}},
     "ibr":{"v":{"bus":"b","terminal_map":["1","n"],"topology":"SINGLE_PHASE","prime_mover":"PV",
         "s_max":[5000.0],"i_max":[20.0,8.0]}}}
    """; from_string=true)
    net2′, _ = augment_case(net2)
    @test net2′["ibr"]["v"]["i_max"] == [20.0, 8.0]
end

@testset "T2: Thermal — low-confidence linecode skipped at default threshold" begin
    # Make linecode look sequence-derived by making R matrix exactly balanced
    # so verdict = "exactly_balanced" → confidence = :low < threshold :medium
    r = 0.000396; r_off = (r - r/3)/2  # balanced off-diagonal
    net = parse_bmopf("""
    {"bus":{
        "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
        "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
         "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
     "linecode":{"lc_seq":{
         "R_series_1_1":$(r),"R_series_2_2":$(r),"R_series_3_3":$(r),
         "R_series_1_2":$(r_off),"R_series_1_3":$(r_off),"R_series_2_3":$(r_off),
         "R_series_2_1":$(r_off),"R_series_3_1":$(r_off),"R_series_3_2":$(r_off),
         "X_series_1_1":0.0001,"X_series_2_2":0.0001,"X_series_3_3":0.0001}},
     "line":{"l1":{"bus_from":"src","bus_to":"b1",
         "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
         "linecode":"lc_seq","length":100.0}},
     "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
         "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
    """; from_string=true)

    net′, mf = augment_case(net)

    # i_max should NOT be written (confidence :low < threshold :medium)
    @test !haskey(net′["linecode"]["lc_seq"], "i_max")
    e = only(filter(x -> x.component_id == "lc_seq" && x.field == "i_max", mf.entries))
    @test contains(e.note, "confidence")

    # But with thermal_min_confidence = :low it should be written
    net2′, _ = augment_case(net; recipe=AugmentationRecipe(thermal_min_confidence=:low))
    @test haskey(net2′["linecode"]["lc_seq"], "i_max")

    # Regression: a per-call config override of [thermal].tolerance must be
    # honoured (the tolerance used to be baked into a module-load constant).
    # R₁₁ = 0.45 mΩ/m sits ~14 % from the nearest table row (0.396): it
    # matches under the default 15 % tolerance but not under a 1 % override.
    net_off = deepcopy(net)
    for k in ("R_series_1_1", "R_series_2_2", "R_series_3_3")
        net_off["linecode"]["lc_seq"][k] = 0.00045
    end
    recipe_low = AugmentationRecipe(thermal_min_confidence=:low)
    netd′, _ = augment_case(net_off; recipe=recipe_low)
    @test haskey(netd′["linecode"]["lc_seq"], "i_max")   # default 15 % matches

    tight = deepcopy(load_config())
    tight["thermal"]["tolerance"] = 0.01
    net3′, mf3 = augment_case(net_off; recipe=recipe_low, config=tight)
    @test !haskey(net3′["linecode"]["lc_seq"], "i_max")
    e3 = only(filter(x -> x.component_id == "lc_seq" && x.field == "i_max", mf3.entries))
    @test contains(e3.note, "outside lookup range")
end

# ── T3: Generation ───────────────────────────────────────────────────────────

@testset "T3: Generation — slack cost priced on the voltage source when absent" begin
    net  = _lv_net()
    net′, mf = augment_case(net)

    # No phantom slack generator is created; the cost is priced on the source.
    @test !any(get(g, "_slack", false) for g in values(get(net′, "generator", Dict())))
    vs = net′["voltage_source"]["vs"]
    @test vs["cost"] == [1.0, 1.0, 1.0]
    @test !haskey(vs, "p_min")
    @test !haskey(vs, "p_max")

    e = only(filter(x -> x.component_type == :voltage_source && x.field == "cost", mf.entries))
    @test contains(e.rule, "TFspec")
end

@testset "T3: Generation — existing source cost not overwritten" begin
    net = _lv_net()
    net["voltage_source"]["vs"]["cost"] = [2.0, 2.0, 2.0]

    net′, mf = augment_case(net)

    @test net′["voltage_source"]["vs"]["cost"] == [2.0, 2.0, 2.0]   # unchanged
    @test !any(e -> e.component_type == :voltage_source && e.field == "cost", mf.entries)
end

@testset "T3: Generation — q bounds added from p_max" begin
    net  = _lv_net_with_gen()
    net′, mf = augment_case(net)

    g = net′["generator"]["g1"]
    @test haskey(g, "q_min")
    @test haskey(g, "q_max")

    tan_phi = tan(acos(0.90))
    @test g["q_max"] ≈ [500.0 * tan_phi, 500.0 * tan_phi, 500.0 * tan_phi]  rtol=1e-6
    @test g["q_min"] ≈ -g["q_max"]

    e_min = only(filter(x -> x.component_id == "g1" && x.field == "q_min", mf.entries))
    @test contains(e_min.rule, "EN50549")
end

@testset "T3: Generation — q bounds not overwritten" begin
    net = _lv_net_with_gen()
    net["generator"]["g1"]["q_min"] = [-100.0, -100.0, -100.0]
    net["generator"]["g1"]["q_max"] = [ 100.0,  100.0,  100.0]

    net′, _ = augment_case(net)

    @test net′["generator"]["g1"]["q_min"] == [-100.0, -100.0, -100.0]
    @test net′["generator"]["g1"]["q_max"] == [ 100.0,  100.0,  100.0]
end

# ── T4: Manifest ─────────────────────────────────────────────────────────────

@testset "T4: Manifest — structure and deep-copy guarantee" begin
    net  = _lv_net()
    net′, mf = augment_case(net)

    @test mf isa TransformationManifest
    @test length(mf.entries) > 0
    @test all(e isa TransformEntry for e in mf.entries)

    # findings_after should have fewer or equal I.BENCH.AUGMENTATION items
    n_before = count(f -> f.code == "I.BENCH.AUGMENTATION", mf.findings_before)
    n_after  = count(f -> f.code == "I.BENCH.AUGMENTATION", mf.findings_after)
    @test n_after <= n_before

    # Deep copy: mutating net′ must not affect net
    net′["bus"]["b1"]["v_min"] = [-999.0, -999.0, -999.0]
    @test !haskey(get(net["bus"], "b1", Dict()), "v_min")
end

@testset "T4: Manifest — JSON round-trip" begin
    net  = _lv_net()
    _, mf = augment_case(net)

    d = manifest_to_dict(mf)
    @test d isa Dict{String,Any}
    @test haskey(d, "created_at")
    @test haskey(d, "entries")
    @test d["entries"] isa Vector
    @test all(e -> haskey(e, "component_type") && haskey(e, "field") &&
                   haskey(e, "rule") && haskey(e, "confidence"), d["entries"])
end

@testset "T4: Manifest — render_manifest produces non-empty output" begin
    net  = _lv_net()
    _, mf = augment_case(net)

    buf = IOBuffer()
    render_manifest(mf; io=buf)
    out = String(take!(buf))
    @test length(out) > 50
    @test contains(out, "Augmentation manifest")
end

@testset "T4: Manifest — render covers IBR and unknown component types" begin
    # Guards against the render loop silently dropping entries whose
    # component_type is not in the hardcoded preferred list (e.g. :ibr,
    # which once rendered only the summary header with no detail).
    entries = [
        TransformEntry(:ibr, "pv_b1", "s_max", nothing, [8000.0],
                       "IBR_PLACEMENT/load_following", :synthetic, "placed"),
        TransformEntry(:shunt, "sh1", "gs", nothing, 0.1,
                       "SOME_RULE", :synthetic, "future type"),
    ]
    mf = TransformationManifest("ts", nothing, entries, Finding[], Finding[])

    buf = IOBuffer(); render_manifest(mf; io=buf)
    out = String(take!(buf))
    @test contains(out, "IBR")
    @test contains(out, "pv_b1")
    @test contains(out, "s_max")
    @test contains(out, "SHUNT")        # unknown type still rendered, not dropped
    @test contains(out, "sh1")
end

@testset "T4: Manifest — pass flags respected" begin
    net = _lv_net()

    # Disable all passes — net′ should be identical to net (modulo deep copy)
    recipe = AugmentationRecipe(
        apply_v_bounds        = false,
        apply_vpn_bounds      = false,
        apply_vpp_bounds      = false,
        apply_vneg_bounds     = false,
        apply_thermal         = false,
        apply_q_bounds        = false,
        apply_slack_generator = false,
    )
    net′, mf = augment_case(net; recipe)

    @test !haskey(net′["bus"]["b1"], "v_min")
    @test !haskey(net′["voltage_source"]["vs"], "cost")
    @test isempty([e for e in mf.entries if e.new_value !== nothing])
end

@testset "T4: Manifest — pre-supplied analysis reused" begin
    net  = _lv_net()
    # Run analysis once and pass it in — should not error
    a    = analyze(net)
    analysis_dict = Dict{String,Any}(
        "voltage_levels" => voltage_level_analysis(net, Finding[]),
        "provenance"     => provenance_analysis(net, Finding[]),
    )
    net′, mf = augment_case(net; analysis=analysis_dict)
    @test haskey(net′["bus"]["b1"], "v_min")   # bounds still applied
end

# ── T0: Voltage-level snapping ───────────────────────────────────────────────

# LV feeder declared at a non-standard 240 V (e.g. an imported 240/415 V model).
function _lv240_net()
    parse_bmopf("""
    {"bus":{
        "src":{"terminal_names":["1","2","3","n"],
               "perfectly_grounded_terminals":["n"]},
        "b1": {"terminal_names":["1","2","3","n"],
               "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src",
         "terminal_map":["1","2","3"],
         "v_magnitude":[240.0,240.0,240.0],
         "v_angle":[0.0,-2.0944,2.0944]}},
     "linecode":{"lc":{"R_series_1_1":0.000396,"R_series_2_2":0.000396,
                       "R_series_3_3":0.000396,"R_series_4_4":0.000396}},
     "line":{"l1":{"bus_from":"src","bus_to":"b1",
         "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
         "linecode":"lc","length":100.0}},
     "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],
         "configuration":"WYE",
         "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
    """; from_string=true)
end

@testset "T0: Voltage snap — _snap_voltage rule" begin
    lv = BMOPFTools._resolve_snap_levels(
            Dict("preset" => "IEC_50Hz", "levels" => Float64[]))
    snap(v) = BMOPFTools._snap_voltage(v, lv, 0.10)
    @test snap(240.0) ≈ 230.0          # within 10 % of 230 → snaps
    @test snap(250.0) ≈ 230.0          # 250/230 − 1 ≈ 8.7 % → snaps
    @test snap(230.0) ≈ 230.0          # already standard
    @test snap(277.0) ≈ 277.0          # >10 % from 230; not a 50 Hz level → kept
    @test snap(207.0) ≈ 230.0          # lower edge of the band
    # 11 kV L-L ↔ 6351 V L-N is in the preset; 6600 (≈11.4 kV) snaps to it.
    @test snap(6600.0) ≈ 11000.0 / sqrt(3)
    # Empty level list / "none" preset is a no-op.
    @test BMOPFTools._snap_voltage(240.0, Float64[], 0.10) == 240.0
end

@testset "T0: Voltage snap — writes v_declared and shifts bounds to 230" begin
    cfg = BMOPFTools.load_config()
    cfg["augment"]["voltage_snap"]["enabled"] = true
    net′, mf = augment_case(_lv240_net(); config=cfg)

    b1 = net′["bus"]["b1"]
    @test b1["v_declared"] ≈ 230.0
    # Bounds now reference 230, not 240.
    @test all(b1["vpn_max"] .≈ 230.0 * 1.10)
    @test all(b1["v_max"]   .≈ 230.0 * 1.15)
    # Manifest records the snap.
    snaps = [e for e in mf.entries
             if e.field == "v_declared" && e.rule == "IEC60038_snap"]
    @test !isempty(snaps)
    @test snaps[1].new_value ≈ 230.0
end

@testset "T0: Voltage snap — off by default (no change)" begin
    net′, mf = augment_case(_lv240_net())   # default config: snapping disabled
    b1 = net′["bus"]["b1"]
    @test !haskey(b1, "v_declared")
    @test all(b1["vpn_max"] .≈ 240.0 * 1.10)   # bounds still against 240
    @test isempty([e for e in mf.entries if e.rule == "IEC60038_snap"])
end

@testset "T0: Voltage snap — explicit v_declared is respected" begin
    net = _lv240_net()
    net["bus"]["b1"]["v_declared"] = 240.0     # user pinned it deliberately
    cfg = BMOPFTools.load_config()
    cfg["augment"]["voltage_snap"]["enabled"] = true
    net′, _ = augment_case(net; config=cfg)
    @test net′["bus"]["b1"]["v_declared"] ≈ 240.0   # not re-snapped
    @test all(net′["bus"]["b1"]["vpn_max"] .≈ 240.0 * 1.10)
end

@testset "T0: Voltage snap — custom levels only" begin
    cfg = BMOPFTools.load_config()
    cfg["augment"]["voltage_snap"]["enabled"] = true
    cfg["augment"]["voltage_snap"]["preset"]  = "none"
    cfg["augment"]["voltage_snap"]["levels"]  = [230.0]   # only 230 in the table
    net′, _ = augment_case(_lv240_net(); config=cfg)
    @test net′["bus"]["b1"]["v_declared"] ≈ 230.0
end

# ── T-VADIFF: angle-difference bounds augmentation (opt-in) ───────────────────

# Split-phase: MV→center_tap→split-phase LV (legs "1","2", neutral "n").
function _split_phase_net()
    parse_bmopf("""
    {"bus":{
        "mv":{"terminal_names":["1","n"]},
        "lv":{"terminal_names":["1","2","n"]}},
     "voltage_source":{"src":{"bus":"mv","terminal_map":["1"],
         "v_magnitude":[2400.0],"v_angle":[0.0]}},
     "transformer":{"center_tap":{"ct":{"bus_from":"mv","bus_to":"lv",
         "terminal_map_from":["1","n"],"terminal_map_to":["1","n","2"],
         "v_nom_from":2400.0,"v_nom_to":120.0}}},
     "load":{"l1":{"bus":"lv","terminal_map":["1","n"],
         "configuration":"SINGLE_PHASE","p_nom":[1000.0],"q_nom":[0.0]}}}
    """; from_string=true)
end

@testset "T-VADIFF: angle-diff bounds — off by default" begin
    net′, _ = augment_case(_lv_net())          # default recipe: flag off
    @test !haskey(net′["bus"]["b1"], "va_nom")
    @test !haskey(net′["bus"]["b1"], "va_diff_min")
    @test !haskey(net′["bus"]["b1"], "va_diff_max")
end

@testset "T-VADIFF: 3φ bus gets ±120° nominal + ±30° window" begin
    r = AugmentationRecipe(apply_va_diff_bounds = true)
    net′, mf = augment_case(_lv_net(); recipe = r)
    b1 = net′["bus"]["b1"]
    @test b1["va_nom"] ≈ [0.0, -2π/3, 2π/3]
    @test b1["va_diff_min"] ≈ -0.5236  atol=1e-4
    @test b1["va_diff_max"] ≈  0.5236  atol=1e-4
    # Source bus is skipped (its phasor is pinned).
    @test !haskey(net′["bus"]["src"], "va_nom")
    fields = [e.field for e in mf.entries if e.component_id == "b1"]
    @test "va_nom" in fields && "va_diff_min" in fields
end

@testset "T-VADIFF: split-phase legs get 180° nominal; 1φ skipped" begin
    r = AugmentationRecipe(apply_va_diff_bounds = true)
    net′, _ = augment_case(_split_phase_net(); recipe = r)
    lv = net′["bus"]["lv"]
    @test lv["va_nom"] ≈ [0.0, π]               # legs anti-phase
    @test lv["va_diff_min"] ≈ -0.5236  atol=1e-4
    # Single-phase MV bus: no angle-diff data (offset is never guessed).
    @test !haskey(net′["bus"]["mv"], "va_nom")
    @test !haskey(net′["bus"]["mv"], "va_diff_min")
end
