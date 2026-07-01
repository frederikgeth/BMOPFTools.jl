using Test
using BMOPFTools

# ---------------------------------------------------------------------------
# Shared minimal fixtures
# ---------------------------------------------------------------------------

# Simple 3-phase 4-wire LV feeder used across most tests
function _fix_lv_net()
    parse_bmopf("""
    {"bus":{
        "src":{"terminal_names":["1","2","3","n"],
               "perfectly_grounded_terminals":["n"]},
        "b1": {"terminal_names":["1","2","3","n"],
               "perfectly_grounded_terminals":["n"]},
        "b2": {"terminal_names":["1","2","3","n"],
               "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src",
         "terminal_map":["1","2","3"],
         "v_magnitude":[230.0,230.0,230.0],
         "v_angle":[0.0,-2.0944,2.0944]}},
     "linecode":{"lc":{"R_series_1_1":0.000396,"R_series_2_2":0.000396,
                       "R_series_3_3":0.000396,"R_series_4_4":0.000396}},
     "line":{
         "l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3","n"],
             "terminal_map_to":["1","2","3","n"],
             "linecode":"lc","length":100.0},
         "l2":{"bus_from":"b1","bus_to":"b2",
             "terminal_map_from":["1","2","3","n"],
             "terminal_map_to":["1","2","3","n"],
             "linecode":"lc","length":100.0}},
     "load":{"ld":{"bus":"b2","terminal_map":["1","2","3","n"],
         "configuration":"WYE",
         "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
    """; from_string=true)
end

# Network with a disconnected island (bus "island" has no path to source)
function _disconnected_net()
    parse_bmopf("""
    {"bus":{
        "src":   {"terminal_names":["1","2","3","n"],
                  "perfectly_grounded_terminals":["n"]},
        "b1":    {"terminal_names":["1","2","3","n"],
                  "perfectly_grounded_terminals":["n"]},
        "island":{"terminal_names":["1","2","3","n"],
                  "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src",
         "terminal_map":["1","2","3"],
         "v_magnitude":[230.0,230.0,230.0],
         "v_angle":[0.0,-2.0944,2.0944]}},
     "linecode":{"lc":{"R_series_1_1":0.001,"R_series_2_2":0.001,
                       "R_series_3_3":0.001}},
     "line":{"l1":{"bus_from":"src","bus_to":"b1",
         "terminal_map_from":["1","2","3"],
         "terminal_map_to":["1","2","3"],
         "linecode":"lc","length":100.0}},
     "load":{
         "ld_main":   {"bus":"b1",     "terminal_map":["1","2","3","n"],
                       "configuration":"WYE",
                       "p_nom":[500.0,500.0,500.0],"q_nom":[0.0,0.0,0.0]},
         "ld_island": {"bus":"island", "terminal_map":["1","2","3","n"],
                       "configuration":"WYE",
                       "p_nom":[200.0,200.0,200.0],"q_nom":[0.0,0.0,0.0]}}}
    """; from_string=true)
end

# Network with source bus voltage bounds (should be stripped)
function _source_bounds_net()
    net = _fix_lv_net()
    net["bus"]["src"]["v_min"]   = [100.0, 100.0, 100.0]
    net["bus"]["src"]["v_max"]   = [300.0, 300.0, 300.0]
    net["bus"]["src"]["vpn_min"] = 200.0
    net["bus"]["src"]["vpn_max"] = 260.0
    net["bus"]["src"]["vpp_min"] = 350.0
    net["bus"]["src"]["vpp_max"] = 450.0
    net
end

# Network with a near-zero impedance line
function _low_z_net()
    net = _fix_lv_net()
    # Replace l1 with one that has essentially zero impedance
    net["linecode"]["lc_zero"] = Dict{String,Any}(
        "R_series_1_1" => 1e-10,
        "R_series_2_2" => 1e-10,
        "R_series_3_3" => 1e-10,
    )
    net["line"]["l1"]["linecode"] = "lc_zero"
    net
end

# Network with a zero load
function _zero_load_net()
    net = _fix_lv_net()
    net["load"]["zero_ld"] = Dict{String,Any}(
        "bus"           => "b1",
        "terminal_map"  => ["1","2","3","n"],
        "configuration" => "WYE",
        "p_nom"         => [0.0, 0.0, 0.0],
        "q_nom"         => [0.0, 0.0, 0.0],
    )
    net
end

# Network with a transformer for adjacent current bound inference
function _transformer_net()
    parse_bmopf("""
    {"bus":{
        "mv_src": {"terminal_names":["a","b","c","n"],
                   "perfectly_grounded_terminals":["n"]},
        "lv_bus": {"terminal_names":["1","2","3","n"],
                   "perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"mv_src",
         "terminal_map":["a","b","c"],
         "v_magnitude":[6350.0,6350.0,6350.0],
         "v_angle":[0.0,-2.0944,2.0944]}},
     "transformer":{"single_phase":{"tx":{"bus_from":"mv_src","bus_to":"lv_bus",
         "terminal_map_from":["a","b","c"],
         "terminal_map_to":  ["1","2","3"],
         "s_rating":100000.0,
         "v_nom_from":11000.0,"v_nom_to":400.0,
         "r_series_from":1.0,"r_series_to":0.01,
         "x_series_from":5.0,"x_series_to":0.05}}},
     "linecode":{"lc":{"R_series_1_1":0.000396,"R_series_2_2":0.000396,
                       "R_series_3_3":0.000396}},
     "line":{"l1":{"bus_from":"lv_bus","bus_to":"lv_bus",
         "terminal_map_from":["1","2","3"],
         "terminal_map_to":  ["1","2","3"],
         "linecode":"lc","length":50.0}},
     "load":{"ld":{"bus":"lv_bus","terminal_map":["1","2","3","n"],
         "configuration":"WYE",
         "p_nom":[2000.0,2000.0,2000.0],"q_nom":[0.0,0.0,0.0]}}}
    """; from_string=true)
end

# Network with a grounding shunt (for perfect grounding opt-in test)
function _grounding_shunt_net()
    net = _fix_lv_net()
    net["shunt"] = Dict{String,Any}(
        "gnd_b1" => Dict{String,Any}(
            "bus"          => "b1",
            "terminal_map" => ["n"],
            "G_1_1"        => 1.0 / 0.05,   # |Z_eq| = 1/|Y_11| ≈ 0.05 Ω < 0.1 Ω threshold
            "B_1_1"        => 1.0 / 0.05,   # reactive component included in |Y_11|
        ),
    )
    net
end

# ---------------------------------------------------------------------------

@testset "Fix case" begin

    # ── T1: Largest connected component ────────────────────────────────────

    @testset "T1: Largest component — island dropped" begin
        net = _disconnected_net()
        recipe = FixRecipe(apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false)
        net′, mf = fix_case(net; recipe=recipe)

        # Island bus and its load must be gone
        @test !haskey(net′["bus"],  "island")
        @test !haskey(net′["load"], "ld_island")

        # Main load and source bus must survive
        @test haskey(net′["bus"],  "src")
        @test haskey(net′["bus"],  "b1")
        @test haskey(net′["load"], "ld_main")

        # Manifest records the drop
        @test any(e -> e.component_type == :network &&
                       occursin("island", lowercase(e.note)), mf.entries)
    end

    @testset "T1c: Largest component — island shunt/ibr/capacitor pruned" begin
        # Regression: shunts were deleted by dict KEY compared against bus
        # names (never matching), and ibr/capacitor/voltage_source entries on
        # dropped buses were not pruned at all — leaving dangling bus refs.
        net = _disconnected_net()
        net["shunt"] = Dict{String,Any}("sh_island" => Dict{String,Any}(
            "bus" => "island", "terminal_map" => ["n"], "G_1_1" => 1.0))
        net["ibr"] = Dict{String,Any}("pv_island" => Dict{String,Any}(
            "bus" => "island", "terminal_map" => ["1","2","3","n"],
            "topology" => "FOUR_LEG", "prime_mover" => "PV",
            "s_max" => [5000.0, 5000.0, 5000.0]))
        net["capacitor"] = Dict{String,Any}("cap_island" => Dict{String,Any}(
            "bus" => "island", "terminal_map" => ["1","2","3"],
            "q_rated" => [1000.0, 1000.0, 1000.0]))
        recipe = FixRecipe(apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false)
        net′, _ = fix_case(net; recipe=recipe)

        @test !haskey(net′["bus"],       "island")
        @test !haskey(net′["shunt"],     "sh_island")
        @test !haskey(net′["ibr"],       "pv_island")
        @test !haskey(net′["capacitor"], "cap_island")

        # No surviving component may reference a dropped bus
        buses = Set(keys(net′["bus"]))
        for ctype in ("load", "shunt", "ibr", "capacitor")
            for (_, el) in get(net′, ctype, Dict())
                @test el["bus"] in buses
            end
        end
    end

    @testset "T1b: Already-connected network — no change" begin
        net = _fix_lv_net()
        recipe = FixRecipe(apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false)
        net′, mf = fix_case(net; recipe=recipe)
        @test length(net′["bus"]) == length(net["bus"])
        @test isempty([e for e in mf.entries
                       if e.component_type == :network])
    end

    # ── T2: Simplify network ────────────────────────────────────────────────

    @testset "T2: Simplify — dangling line removed" begin
        net = _fix_lv_net()
        # Add a stub line with no load at its far end
        net["bus"]["stub"] = Dict{String,Any}(
            "terminal_names" => ["1","2","3","n"],
            "perfectly_grounded_terminals" => ["n"],
        )
        net["line"]["lstub"] = Dict{String,Any}(
            "bus_from" => "b2", "bus_to" => "stub",
            "terminal_map_from" => ["1","2","3","n"],
            "terminal_map_to"   => ["1","2","3","n"],
            "linecode" => "lc", "length" => 50.0,
        )
        recipe = FixRecipe(apply_largest_component=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false)
        net′, mf = fix_case(net; recipe=recipe)
        @test !haskey(get(net′, "line", Dict()), "lstub")
    end

    # ── T3: Remove zero loads ───────────────────────────────────────────────

    @testset "T3: Zero loads removed; non-zero untouched" begin
        net = _zero_load_net()
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false)
        net′, mf = fix_case(net; recipe=recipe)

        @test !haskey(net′["load"], "zero_ld")
        @test  haskey(net′["load"], "ld")          # non-zero load untouched

        # Manifest records the removal
        @test any(e -> e.component_type == :load &&
                       e.component_id   == "zero_ld", mf.entries)
    end

    @testset "T3b: Partial zero (only p=0) — not removed" begin
        net = _fix_lv_net()
        net["load"]["partial"] = Dict{String,Any}(
            "bus"           => "b1",
            "terminal_map"  => ["1","2","3","n"],
            "configuration" => "WYE",
            "p_nom"         => [0.0, 0.0, 0.0],
            "q_nom"         => [100.0, 0.0, 0.0],   # q non-zero on phase 1
        )
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false)
        net′, _ = fix_case(net; recipe=recipe)
        @test haskey(net′["load"], "partial")
    end

    # ── T4: Low-impedance lines → switches ─────────────────────────────────

    @testset "T4: Low-impedance line converted to switch" begin
        net = _low_z_net()
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_source_bus_bounds=false,
                           low_impedance_threshold_ohm=1e-4)
        net′, mf = fix_case(net; recipe=recipe)

        # l1 used the near-zero linecode — should be converted
        @test !haskey(net′["line"],   "l1")
        sw_id = "_sw_l1"
        @test  haskey(net′["switch"], sw_id)
        @test net′["switch"][sw_id]["open_switch"] == false

        # Manifest records |Z| and threshold
        e = findfirst(e -> e.component_type == :line &&
                           e.component_id   == "l1", mf.entries)
        @test e !== nothing
        @test mf.entries[e].new_value == sw_id
    end

    @testset "T4c: Converted switch keeps the line's current rating" begin
        # Regression: the replacement switch used to carry no i_max, silently
        # dropping the thermal constraint of a rated jumper.
        net = _low_z_net()
        net["linecode"]["lc_zero"]["i_max"] = [120.0, 120.0, 120.0]
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_source_bus_bounds=false,
                           low_impedance_threshold_ohm=1e-4)
        net′, _ = fix_case(net; recipe=recipe)
        @test net′["switch"]["_sw_l1"]["i_max"] == [120.0, 120.0, 120.0]

        # A line-level override beats the linecode rating.
        net2 = _low_z_net()
        net2["linecode"]["lc_zero"]["i_max"] = [120.0, 120.0, 120.0]
        net2["line"]["l1"]["i_max"] = [80.0, 80.0, 80.0]
        net2′, _ = fix_case(net2; recipe=recipe)
        @test net2′["switch"]["_sw_l1"]["i_max"] == [80.0, 80.0, 80.0]
    end

    @testset "T4b: Normal-impedance line NOT converted" begin
        net = _fix_lv_net()   # lc has R~0.04 Ω over 100 m — well above 1e-4 Ω threshold
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_source_bus_bounds=false,
                           low_impedance_threshold_ohm=1e-4)
        net′, _ = fix_case(net; recipe=recipe)
        @test haskey(net′["line"], "l1")
        @test haskey(net′["line"], "l2")
        @test isempty(get(net′, "switch", Dict()))
    end

    # ── T5: Source bus bounds stripped ────────────────────────────────────

    @testset "T5: Source bus bounds removed" begin
        net = _source_bounds_net()
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false)
        net′, mf = fix_case(net; recipe=recipe)

        src = net′["bus"]["src"]
        for field in ("v_min", "v_max", "vpn_min", "vpn_max", "vpp_min", "vpp_max")
            @test !haskey(src, field)
        end

        # Non-source bus bounds must be untouched
        # (b1/b2 have none in this fixture — just check they're still plain dicts)
        @test haskey(net′["bus"], "b1")

        # Manifest records each removed field
        removed_fields = [e.field for e in mf.entries
                          if e.component_type == :bus &&
                             e.component_id   == "src"]
        @test "v_min"   in removed_fields
        @test "v_max"   in removed_fields
        @test "vpn_min" in removed_fields
    end

    @testset "T5b: Non-source bus bounds untouched" begin
        net = _fix_lv_net()
        net["bus"]["b1"]["v_min"] = [195.5, 195.5, 195.5]
        net["bus"]["b1"]["v_max"] = [264.5, 264.5, 264.5]
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false)
        net′, _ = fix_case(net; recipe=recipe)
        @test net′["bus"]["b1"]["v_min"] ≈ [195.5, 195.5, 195.5]
        @test net′["bus"]["b1"]["v_max"] ≈ [264.5, 264.5, 264.5]
    end

    # ── T6: Adjacent current bounds (opt-in) ───────────────────────────────

    @testset "T6: Adjacent current bounds — transformer inference" begin
        net = _transformer_net()
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false,
                           apply_adjacent_current_bounds=true)
        net′, mf = fix_case(net; recipe=recipe)

        # l1 had no i_max; transformer s_rating=100kVA, v_nom_to=400V, 3-phase
        # expected i_max = 100e3 / (√3 × 400) ≈ 144.3 A, written per conductor
        l1 = net′["line"]["l1"]
        @test haskey(l1, "i_max")
        @test l1["i_max"] isa Vector
        @test length(l1["i_max"]) == length(l1["terminal_map_from"])
        @test all(v -> isapprox(v, 100e3 / (sqrt(3) * 400.0); atol=0.5), l1["i_max"])

        # Manifest entry recorded with :medium confidence
        e = findfirst(e -> e.component_type == :line &&
                           e.component_id   == "l1" &&
                           e.field          == "i_max", mf.entries)
        @test e !== nothing
        @test mf.entries[e].confidence == :medium
    end

    @testset "T6b: Adjacent current bounds default OFF" begin
        net = _transformer_net()
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false)
        # apply_adjacent_current_bounds defaults to false
        net′, _ = fix_case(net; recipe=recipe)
        @test !haskey(net′["line"]["l1"], "i_max")
    end

    @testset "T6c: Already-bounded line not overwritten" begin
        net = _transformer_net()
        net["line"]["l1"]["i_max"] = 999.0   # pre-existing bound
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false,
                           apply_adjacent_current_bounds=true)
        net′, _ = fix_case(net; recipe=recipe)
        @test net′["line"]["l1"]["i_max"] ≈ 999.0
    end

    # ── T7: Perfect grounding (opt-in) ─────────────────────────────────────

    @testset "T7: Perfect grounding promoted" begin
        net = _grounding_shunt_net()
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false,
                           apply_perfect_grounding=true,
                           perfect_grounding_threshold_ohm=0.1)
        net′, mf = fix_case(net; recipe=recipe)

        # Shunt removed
        @test !haskey(net′["shunt"], "gnd_b1")

        # Terminal promoted
        grounded = net′["bus"]["b1"]["perfectly_grounded_terminals"]
        @test "n" in string.(grounded)

        # Manifest records the promotion
        e = findfirst(e -> e.component_type == :shunt &&
                           e.component_id   == "gnd_b1", mf.entries)
        @test e !== nothing
    end

    @testset "T7b: Perfect grounding default OFF" begin
        net = _grounding_shunt_net()
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false)
        # apply_perfect_grounding defaults to false
        net′, _ = fix_case(net; recipe=recipe)
        @test haskey(net′["shunt"], "gnd_b1")   # shunt untouched
    end

    @testset "T7c: High-resistance shunt not promoted" begin
        net = _fix_lv_net()
        net["shunt"] = Dict{String,Any}(
            "gnd_hi" => Dict{String,Any}(
                "bus"          => "b1",
                "terminal_map" => ["n"],
                "G_1_1"        => 1.0 / 10.0,   # 10 Ω — above 0.1 Ω threshold
                "B_1_1"        => 0.0,
            ),
        )
        recipe = FixRecipe(apply_largest_component=false,
                           apply_simplify_network=false,
                           apply_remove_zero_loads=false,
                           apply_low_impedance_to_switch=false,
                           apply_source_bus_bounds=false,
                           apply_perfect_grounding=true,
                           perfect_grounding_threshold_ohm=0.1)
        net′, _ = fix_case(net; recipe=recipe)
        @test haskey(net′["shunt"], "gnd_hi")   # left alone
    end

    # ── T8: Manifest and deep-copy guarantees ──────────────────────────────

    @testset "T8: net is not mutated" begin
        net = _zero_load_net()
        net_orig = deepcopy(net)
        fix_case(net)
        @test net["load"] == net_orig["load"]   # original unchanged
    end

    @testset "T8b: Manifest JSON round-trip" begin
        net = _zero_load_net()
        _, mf = fix_case(net)
        d = manifest_to_dict(mf)
        @test d isa Dict
        @test haskey(d, "entries")
        @test haskey(d, "created_at")
    end

    @testset "T8c: render_manifest does not error" begin
        net = _zero_load_net()
        _, mf = fix_case(net)
        buf = IOBuffer()
        render_manifest(mf; io=buf)
        @test !isempty(String(take!(buf)))
    end

    @testset "T8d: All passes disabled — identity transform" begin
        net = _fix_lv_net()
        recipe = FixRecipe(
            apply_largest_component=false,
            apply_simplify_network=false,
            apply_remove_zero_loads=false,
            apply_low_impedance_to_switch=false,
            apply_source_bus_bounds=false,
            apply_adjacent_current_bounds=false,
            apply_perfect_grounding=false,
        )
        net′, mf = fix_case(net; recipe=recipe)
        @test length(net′["bus"])  == length(net["bus"])
        @test length(net′["line"]) == length(net["line"])
        @test length(net′["load"]) == length(net["load"])
        @test isempty(mf.entries)
    end

    @testset "T9: Capacitive shunt → capacitor (opt-in)" begin
        # Phase-to-ground capacitive shunt on a bus with a grounded neutral.
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"]),
                "b1"  => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"])),
            "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["a","b","c"],
                "v_magnitude" => [230.0,230.0,230.0], "v_angle" => [0.0,-2.0944,2.0944])),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
                "R_series_1_1" => 0.1, "R_series_2_2" => 0.1, "R_series_3_3" => 0.1)),
            "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                "bus_from" => "src", "bus_to" => "b1",
                "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c"],
                "linecode" => "lc", "length" => 1.0)),
            "shunt" => Dict{String,Any}("cap1" => Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["a","b","c"],
                "B_1_1" => 1e-4, "B_2_2" => 1e-4, "B_3_3" => 1e-4)))

        disabled = (apply_largest_component=false, apply_simplify_network=false,
                    apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
                    apply_source_bus_bounds=false)

        # Off by default: untouched.
        net_def, _ = fix_case(net; recipe = FixRecipe(; disabled...))
        @test haskey(net_def["shunt"], "cap1")
        @test !haskey(get(net_def, "capacitor", Dict()), "cap_cap1")

        # Opt-in: converted to a WYE capacitor, shunt removed.
        net′, mf = fix_case(net;
            recipe = FixRecipe(; disabled..., apply_shunt_to_capacitor=true))
        @test !haskey(get(net′, "shunt", Dict()), "cap1")
        cap = net′["capacitor"]["cap_cap1"]
        @test cap["configuration"] == "WYE"
        @test cap["terminal_map"] == ["a","b","c","n"]
        @test cap["v_nom"] ≈ 230.0  atol=1.0
        @test all(cap["q_rated"] .≈ 1e-4 * cap["v_nom"]^2)   # q = B·v_nom²
        @test any(e -> e.rule == "shunt_to_capacitor", mf.entries)
    end

    @testset "T9b: Capacitive shunt without grounded neutral — not converted" begin
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"]),
                "b1"  => Dict{String,Any}("terminal_names" => ["a","b","c","n"])),  # n floats
            "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["a","b","c"],
                "v_magnitude" => [230.0,230.0,230.0], "v_angle" => [0.0,-2.0944,2.0944])),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
                "R_series_1_1" => 0.1, "R_series_2_2" => 0.1, "R_series_3_3" => 0.1)),
            "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                "bus_from" => "src", "bus_to" => "b1",
                "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c"],
                "linecode" => "lc", "length" => 1.0)),
            "shunt" => Dict{String,Any}("cap1" => Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["a","b","c"],
                "B_1_1" => 1e-4, "B_2_2" => 1e-4, "B_3_3" => 1e-4)))
        net′, _ = fix_case(net; recipe = FixRecipe(
            apply_largest_component=false, apply_simplify_network=false,
            apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
            apply_source_bus_bounds=false, apply_shunt_to_capacitor=true))
        @test haskey(net′["shunt"], "cap1")          # left untouched (no grounded return)
        @test !haskey(get(net′, "capacitor", Dict()), "cap_cap1")
    end

    @testset "T9c: Non-capacitor / unsupported shunts are declined" begin
        # A connected base feeder so the bus has a resolvable nominal (vmap),
        # ensuring declines are structural, not nominal-missing.
        function base(bus_terms, shunt)
            Dict{String,Any}(
                "bus" => Dict{String,Any}(
                    "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                        "perfectly_grounded_terminals" => ["n"]),
                    "b1"  => Dict{String,Any}("terminal_names" => bus_terms,
                        "perfectly_grounded_terminals" => ["n"])),
                "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                    "bus" => "src", "terminal_map" => ["a","b","c"],
                    "v_magnitude" => [230.0,230.0,230.0], "v_angle" => [0.0,-2.0944,2.0944])),
                "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
                    "R_series_1_1" => 0.1, "R_series_2_2" => 0.1, "R_series_3_3" => 0.1)),
                "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                    "bus_from" => "src", "bus_to" => "b1",
                    "terminal_map_from" => ["a","b","c"], "terminal_map_to" => ["a","b","c"],
                    "linecode" => "lc", "length" => 1.0)),
                "shunt" => Dict{String,Any}("sh" => shunt))
        end
        recipe = FixRecipe(apply_largest_component=false, apply_simplify_network=false,
            apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
            apply_source_bus_bounds=false, apply_shunt_to_capacitor=true)
        declined(net) = (n′ = first(fix_case(net; recipe=recipe));
                         haskey(get(n′, "shunt", Dict()), "sh") &&
                         !haskey(get(n′, "capacitor", Dict()), "cap_sh"))

        # Conductance present → not a pure capacitor.
        @test declined(base(["a","b","c","n"], Dict{String,Any}(
            "bus"=>"b1", "terminal_map"=>["a"], "G_1_1"=>1e-4, "B_1_1"=>1e-4)))
        # Negative diagonal susceptance → a reactor, not a capacitor.
        @test declined(base(["a","b","c","n"], Dict{String,Any}(
            "bus"=>"b1", "terminal_map"=>["a"], "B_1_1"=>-1e-4)))
        # 4-terminal star whose hub is not a name-resolvable neutral → declined.
        @test declined(base(["a","b","c","g"], Dict{String,Any}(
            "bus"=>"b1", "terminal_map"=>["a","b","c","g"],
            "B_1_1"=>5e-4, "B_2_2"=>5e-4, "B_3_3"=>5e-4, "B_4_4"=>1.5e-3,
            "B_1_4"=>-5e-4, "B_2_4"=>-5e-4, "B_3_4"=>-5e-4)))
        # 3-terminal incomplete star (a–b, a–c but no b–c) → not a delta → declined.
        @test declined(base(["a","b","c","n"], Dict{String,Any}(
            "bus"=>"b1", "terminal_map"=>["a","b","c"],
            "B_1_1"=>1e-3, "B_2_2"=>5e-4, "B_3_3"=>5e-4,
            "B_1_2"=>-5e-4, "B_1_3"=>-5e-4)))
    end

    @testset "T9d: Single phase-to-ground bank → SINGLE_PHASE (arity-correct)" begin
        # Was a latent bug: the old pass emitted a non-conformant WYE (arity 2).
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "src" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                    "perfectly_grounded_terminals" => ["n"]),
                "b1"  => Dict{String,Any}("terminal_names" => ["a","n"],
                    "perfectly_grounded_terminals" => ["n"])),
            "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["a","b","c"],
                "v_magnitude" => [230.0,230.0,230.0], "v_angle" => [0.0,-2.0944,2.0944])),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}("R_series_1_1" => 0.1)),
            "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                "bus_from" => "src", "bus_to" => "b1",
                "terminal_map_from" => ["a"], "terminal_map_to" => ["a"],
                "linecode" => "lc", "length" => 1.0)),
            "shunt" => Dict{String,Any}("sh" => Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["a"], "B_1_1" => 1e-4)))
        net′, _ = fix_case(net; recipe = FixRecipe(
            apply_largest_component=false, apply_simplify_network=false,
            apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
            apply_source_bus_bounds=false, apply_shunt_to_capacitor=true))
        cap = net′["capacitor"]["cap_sh"]
        @test cap["configuration"] == "SINGLE_PHASE"
        @test cap["terminal_map"] == ["a","n"]
        f = Finding[]; spec_conformance_check(net′, f)   # conformant arity
        @test !any(x -> x.code == "W.SPEC.CONFIG_ARITY" && x.component_id == "cap_sh", f)
    end

    @testset "T10: Snap placeholder transformer leakage (opt-in)" begin
        # Z_base = 11000²/50000 = 2420 Ω.
        mknet(xf) = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "mv" => Dict{String,Any}("terminal_names" => ["a","n"]),
                "lv" => Dict{String,Any}("terminal_names" => ["a","n"])),
            "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
                "tx" => Dict{String,Any}(
                    "bus_from" => "mv", "bus_to" => "lv",
                    "terminal_map_from" => ["a","n"], "terminal_map_to" => ["a","n"],
                    "v_nom_from" => 11000.0, "v_nom_to" => 240.0, "s_rating" => 50000.0,
                    "r_series_from" => 0.0, "x_series_from" => xf,
                    "r_series_to" => 0.0, "x_series_to" => 0.0))))
        disabled = (apply_largest_component=false, apply_simplify_network=false,
                    apply_remove_zero_loads=false, apply_low_impedance_to_switch=false,
                    apply_source_bus_bounds=false)

        # Placeholder leakage (zpu ≈ 4e-8) → snapped to exactly zero.
        net′, mf = fix_case(mknet(1e-4);
            recipe = FixRecipe(; disabled..., apply_snap_transformer_impedance=true))
        @test net′["transformer"]["single_phase"]["tx"]["x_series_from"] == 0.0
        @test any(e -> e.rule == "snap_transformer_impedance", mf.entries)

        # Off by default: untouched.
        net_def, _ = fix_case(mknet(1e-4); recipe = FixRecipe(; disabled...))
        @test net_def["transformer"]["single_phase"]["tx"]["x_series_from"] == 1e-4

        # Realistic leakage (x = 121 Ω ⇒ zpu ≈ 5 %) → NOT snapped.
        net_r, _ = fix_case(mknet(121.0);
            recipe = FixRecipe(; disabled..., apply_snap_transformer_impedance=true))
        @test net_r["transformer"]["single_phase"]["tx"]["x_series_from"] == 121.0
    end

end  # @testset "Fix case"
