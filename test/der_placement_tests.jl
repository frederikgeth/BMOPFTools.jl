using Test
using BMOPFTools

# ---------------------------------------------------------------------------
# Self-contained fixtures (mirror those in augmentation_tests.jl)
# ---------------------------------------------------------------------------

_der_lv_net() = parse_bmopf("""
{"bus":{
    "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
    "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
     "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
 "linecode":{"lc":{"R_series_1_1":0.000396}},
 "line":{"l1":{"bus_from":"src","bus_to":"b1",
     "terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],
     "linecode":"lc","length":100.0}},
 "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
     "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
""", from_string=true)

_der_mv_lv_net() = parse_bmopf("""
{"bus":{
    "mv_src":{"terminal_names":["a","b","c","n"],"perfectly_grounded_terminals":["n"]},
    "lv_bus":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
 "voltage_source":{"vs":{"bus":"mv_src","terminal_map":["a","b","c"],
     "v_magnitude":[6350.0,6350.0,6350.0],"v_angle":[0.0,-2.0944,2.0944]}},
 "transformer":{"single_phase":{"tx":{"bus_from":"mv_src","bus_to":"lv_bus",
     "terminal_map_from":["a","b","c"],"terminal_map_to":["1","2","3"],
     "s_rating":100000.0,"v_nom_from":11000.0,"v_nom_to":400.0,
     "r_series_from":1.0,"r_series_to":0.01,"x_series_from":5.0,"x_series_to":0.05}}},
 "load":{"ld":{"bus":"lv_bus","terminal_map":["1","2","3","n"],"configuration":"WYE",
     "p_nom":[2000.0,2000.0,2000.0],"q_nom":[0.0,0.0,0.0]}}}
""", from_string=true)

# A small radial LV feeder: src → b1(load) → b2(load, leaf). b3 is a dangling leaf.
_der_radial_net() = parse_bmopf("""
{"bus":{
    "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
    "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
    "b2": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
    "b3": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
     "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
 "linecode":{"lc":{"R_series_1_1":0.000396}},
 "line":{
     "l1":{"bus_from":"src","bus_to":"b1","terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],"linecode":"lc","length":50.0},
     "l2":{"bus_from":"b1","bus_to":"b2","terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],"linecode":"lc","length":50.0},
     "l3":{"bus_from":"b1","bus_to":"b3","terminal_map_from":["1","2","3","n"],"terminal_map_to":["1","2","3","n"],"linecode":"lc","length":50.0}},
 "load":{
     "ld1":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE","p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]},
     "ld2":{"bus":"b2","terminal_map":["1","2","3","n"],"configuration":"WYE","p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
""", from_string=true)

# ── D1: load-following placement ─────────────────────────────────────────────

@testset "D1: load-following — LV" begin
    net = _der_lv_net()
    net′, mf = add_generators(net)
    @test haskey(net′["generator"], "der_b1")
    g = net′["generator"]["der_b1"]
    @test g["bus"] == "b1"
    @test g["p_max"] ≈ [800.0, 800.0, 800.0]  atol=1e-6
    @test g["p_min"] == [0.0, 0.0, 0.0]
    @test g["cost"]  ≈ [0.5, 0.5, 0.5]               # per-phase linear dispatch cost
    @test g["terminal_map"] == ["1","2","3","n"]
    @test g["configuration"] == "WYE"
    @test !haskey(net′["generator"], "der_src")     # source bus skipped
end

# ── D2: input is never mutated ───────────────────────────────────────────────

@testset "D2: non-mutation" begin
    net = _der_lv_net()
    _, _ = add_generators(net)
    @test !haskey(net, "generator")
end

# ── D3: voltage-level filter ─────────────────────────────────────────────────

@testset "D3: voltage filter (LV only)" begin
    net = _der_mv_lv_net()
    net′, _ = add_generators(net; recipe=GeneratorRecipe(voltage_levels=[:LV]))
    @test haskey(net′["generator"], "der_lv_bus")
    @test !haskey(net′["generator"], "der_mv_src")
end

# ── D4: hosting-capacity sizing ──────────────────────────────────────────────

@testset "D4: hosting-capacity sizing" begin
    net = _der_mv_lv_net()
    net′, _ = add_generators(net; recipe=GeneratorRecipe(
        strategy=:hosting_capacity,
        size_basis=:fraction_of_transformer_rating,
        der_p_fraction=0.5,
        voltage_levels=nothing))
    g = net′["generator"]["der_lv_bus"]
    @test sum(g["p_max"]) ≈ 50_000.0  atol=1e-3   # 0.5 × 100 kVA rating
end

# ── D5: topology-targeted (leaves) ───────────────────────────────────────────

@testset "D5: topology leaves" begin
    net = _der_radial_net()
    net′, _ = add_generators(net; recipe=GeneratorRecipe(
        strategy=:topology_targeted, topology_mode=:leaves, voltage_levels=[:LV]))
    gens = get(net′, "generator", Dict())
    @test haskey(gens, "der_b2")          # degree-1 leaf hosting load
    @test !haskey(gens, "der_b3")         # degree-1 but dangling (no load)
    @test !haskey(gens, "der_b1")         # degree-3 pass-through, not a leaf
end

# ── D6: manifest explainability ──────────────────────────────────────────────

@testset "D6: manifest entries" begin
    net = _der_lv_net()
    _, mf = add_generators(net)
    ents = [e for e in mf.entries if e.component_id == "der_b1"]
    @test !isempty(ents)
    @test all(e -> e.component_type == :generator, ents)
    @test all(e -> startswith(e.rule, "DER_PLACEMENT/"), ents)
    @test all(e -> e.confidence == :synthetic, ents)
    @test all(e -> !isempty(e.note), ents)
    @test any(e -> e.field == "p_max", ents)
    @test any(f -> f.code == "I.DER.PLACED", mf.findings_after)
end

# ── D7: overwrite guard ──────────────────────────────────────────────────────

@testset "D7: overwrite guard" begin
    net = _der_lv_net()
    get!(net, "generator", Dict{String,Any}())["g1"] = Dict{String,Any}(
        "bus" => "b1", "terminal_map" => ["1","2","3","n"], "configuration" => "WYE",
        "p_min" => [0.0,0.0,0.0], "p_max" => [500.0,500.0,500.0], "cost" => [10.0,10.0,10.0])
    net′, _ = add_generators(net)
    @test net′["generator"]["g1"]["p_max"] == [500.0,500.0,500.0]   # untouched
    @test !haskey(net′["generator"], "der_b1")                      # no duplicate
end

# ── D8: composition with augment_case (data-level) ───────────────────────────
# add_generators writes p_max/cost only; augment_case's generation pass then
# fills q_min/q_max on the new DER — the intended division of labour.

@testset "D8: composition fills reactive bounds" begin
    net = _der_lv_net()
    net2, _ = add_generators(net; recipe=GeneratorRecipe(strategy=:load_following))
    @test !haskey(net2["generator"]["der_b1"], "q_max")   # not written here
    net3, _ = augment_case(net2)
    @test haskey(net3["generator"]["der_b1"], "q_min")    # filled by augment_case
    @test haskey(net3["generator"]["der_b1"], "q_max")
end

# ── D9: DER makes the OPF dispatch non-trivially ─────────────────────────────
# Guarded: needs the OPF extension (JuMP + Ipopt).

if @isdefined(_HAS_JUMP_IPOPT) && _HAS_JUMP_IPOPT
    _opf_ready_net() = parse_bmopf("""
    {"bus":{
        "sourcebus":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
        "bus1":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],"v_min":[900.0, 900.0, 900.0],"v_max":[1100.0, 1100.0, 1100.0]}},
     "voltage_source":{"vs":{"bus":"sourcebus","terminal_map":["1","2","3"],
         "v_magnitude":[1000.0,1000.0,1000.0],"v_angle":[0.0,-2.0944,2.0944],"cost":[1.0,1.0,1.0]}},
     "linecode":{"lc":{"R_series_1_1":1.0e-4,"R_series_2_2":1.0e-4,"R_series_3_3":1.0e-4}},
     "line":{"l1":{"bus_from":"sourcebus","bus_to":"bus1","terminal_map_from":["1","2","3"],
         "terminal_map_to":["1","2","3"],"linecode":"lc","length":1.0}},
     "load":{"ld1":{"bus":"bus1","terminal_map":["1","2","3","n"],"configuration":"WYE",
         "p_nom":[150000.0,150000.0,150000.0],"q_nom":[0.0,0.0,0.0]}}}
    """, from_string=true)

    @testset "D9: DER dispatch reduces slack import" begin
        base = _opf_ready_net()
        rb = solve_opf(base)
        slack_base = sum(Float64(rb["voltage_source"]["vs"][t]["ps"]) for t in ("1","2","3"))

        net2, _ = add_generators(_opf_ready_net();
                    recipe=GeneratorRecipe(voltage_levels=nothing, der_p_fraction=0.5))
        g = net2["generator"]["der_bus1"]
        g["q_min"] = [-1000.0,-1000.0,-1000.0]; g["q_max"] = [1000.0,1000.0,1000.0]
        r = solve_opf(net2)
        @test r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        p = sum(Float64(r["generator"]["der_bus1"][t]["pg"]) for t in ("1","2","3"))
        pmax = sum(Float64.(g["p_max"]))
        slack = sum(Float64(r["voltage_source"]["vs"][t]["ps"]) for t in ("1","2","3"))

        # DER dispatches (non-trivial) up to p_max. The 1e-3 W absolute floor was
        # unrealistic after the per-unit round-trip on a ~225 kW value; allow a
        # realistic 1e-4 relative slack for the scaled solve.
        @test 0.0 < p <= pmax * (1 + 1e-4)
        @test slack < slack_base - 1.0      # local generation displaces import
    end

    # ── D10: composition emits OPF-consumable per-phase array bounds ─────────
    # add_generators → augment_case produces per-phase vpn / per-pair vpp arrays
    # (the shapes the OPF now consumes). The end-to-end solve of array bounds is
    # covered by opf_tests "T-VBND".
    @testset "D10: augment after add_generators emits array bounds" begin
        net2, _ = add_generators(_der_lv_net();
                    recipe=GeneratorRecipe(strategy=:load_following))
        net3, _ = augment_case(net2)
        @test net3["bus"]["b1"]["vpn_min"] isa AbstractVector
        @test net3["bus"]["b1"]["vpp_min"] isa AbstractVector
        @test haskey(net3["generator"]["der_b1"], "q_max")      # q filled by augment
    end
end
