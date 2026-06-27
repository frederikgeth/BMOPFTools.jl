using Test
using BMOPFTools

# ---------------------------------------------------------------------------
# Self-contained fixtures (mirror those in der_placement_tests.jl)
# ---------------------------------------------------------------------------

_inv_lv_net() = parse_bmopf("""
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

# A radial LV feeder: src → b1(load) → b2(load, leaf); b3 dangling leaf.
_inv_radial_net() = parse_bmopf("""
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

# Single-phase load (phase + neutral) to exercise topology inference.
_inv_1ph_net() = parse_bmopf("""
{"bus":{
    "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
    "b1": {"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
     "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
 "linecode":{"lc":{"R_series_1_1":0.000396}},
 "line":{"l1":{"bus_from":"src","bus_to":"b1",
     "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
     "linecode":"lc","length":100.0}},
 "load":{"ld":{"bus":"b1","terminal_map":["1","n"],"configuration":"WYE",
     "p_nom":[1000.0],"q_nom":[0.0]}}}
""", from_string=true)

# ── I1: load-following placement writes the nameplate ────────────────────────

@testset "I1: load-following — nameplate" begin
    net = _inv_lv_net()
    net′, mf = add_ibrs(net)
    @test haskey(net′["ibr"], "pv_b1")
    inv = net′["ibr"]["pv_b1"]
    @test inv["bus"] == "b1"
    @test inv["topology"] == "FOUR_LEG"            # inferred from neutral terminal
    @test inv["prime_mover"] == "PV"
    @test inv["s_max"] ≈ [800.0, 800.0, 800.0]  atol=1e-6   # 0.8 × local load
    @test inv["p_avail"] ≈ 2400.0                atol=1e-6   # 1.0 × Σ s_max
    @test inv["cost"]  ≈ [0.5, 0.5, 0.5]
    @test inv["terminal_map"] == ["1","2","3","n"]
    # P/Q box is deferred to augment_case, not written here
    @test !haskey(inv, "p_max")
    @test !haskey(inv, "q_min")
    @test !haskey(net′["ibr"], "pv_src")      # source bus skipped
end

# ── I2: input is never mutated ───────────────────────────────────────────────

@testset "I2: non-mutation" begin
    net = _inv_lv_net()
    _, _ = add_ibrs(net)
    @test !haskey(net, "ibr")
end

# ── I3: augment_case fills the deferred P/Q box ──────────────────────────────

@testset "I3: placement → augment fills P/Q" begin
    net = _inv_lv_net()
    net2, _ = add_ibrs(net)
    net3, _ = augment_case(net2)
    inv = net3["ibr"]["pv_b1"]
    @test inv["p_max"] ≈ [800.0, 800.0, 800.0]  atol=1e-6   # = s_max
    @test inv["p_min"] == [0.0, 0.0, 0.0]                    # PV unidirectional
    # EN 50549-1 default cos φ = 0.90 ⇒ Q = ±tan(acos(0.9)) × P_max
    qexp = 800.0 * tan(acos(0.90))
    @test inv["q_max"] ≈ [qexp, qexp, qexp]      atol=1e-6
    @test inv["q_min"] ≈ [-qexp, -qexp, -qexp]   atol=1e-6
end

# ── I4: topology inference — single-phase load ───────────────────────────────

@testset "I4: topology inference (1-phase)" begin
    net = _inv_1ph_net()
    net′, _ = add_ibrs(net)
    inv = net′["ibr"]["pv_b1"]
    @test inv["topology"] == "SINGLE_PHASE"        # 2-terminal load
    @test inv["s_max"] ≈ [800.0]                atol=1e-6
end

# ── I5: forced topology overrides inference ──────────────────────────────────

@testset "I5: forced topology" begin
    net = _inv_lv_net()
    net′, _ = add_ibrs(net; recipe = IBRRecipe(inverter_topology = :THREE_LEG))
    @test net′["ibr"]["pv_b1"]["topology"] == "THREE_LEG"
end

# ── I6: overwrite guard — existing IBR is not replaced ───────────────────

@testset "I6: overwrite guard" begin
    net = _inv_lv_net()
    net["ibr"] = Dict("existing" => Dict(
        "bus" => "b1", "terminal_map" => ["1","2","3","n"],
        "topology" => "FOUR_LEG", "prime_mover" => "PV", "s_max" => [1.0,1.0,1.0]))
    net′, mf = add_ibrs(net)
    @test !haskey(net′["ibr"], "pv_b1")        # b1 already hosts one
    @test haskey(net′["ibr"], "existing")
    @test any(f.code == "W.IBR.NO_CANDIDATES" for f in mf.findings_after)
end

# ── I7: sizing — fraction knob ───────────────────────────────────────────────

@testset "I7: s_fraction sizing" begin
    net = _inv_lv_net()
    net′, _ = add_ibrs(net; recipe = IBRRecipe(s_fraction = 0.5))
    @test net′["ibr"]["pv_b1"]["s_max"] ≈ [500.0,500.0,500.0]  atol=1e-6
end

# ── I8: s_to_p_ratio leaves reactive headroom ────────────────────────────────

@testset "I8: s_to_p_ratio" begin
    net = _inv_lv_net()
    net′, _ = add_ibrs(net; recipe = IBRRecipe(s_to_p_ratio = 0.9))
    @test net′["ibr"]["pv_b1"]["p_avail"] ≈ 0.9 * 2400.0  atol=1e-6
end

# ── I9: topology-targeted (leaves) ───────────────────────────────────────────

@testset "I9: topology-targeted leaves" begin
    net = _inv_radial_net()
    net′, mf = add_ibrs(net;
        recipe = IBRRecipe(strategy = :topology_targeted, topology_mode = :leaves))
    # b2 is the only load-bearing degree-1 bus (b3 dangling has no load)
    @test haskey(net′["ibr"], "pv_b2")
    @test !haskey(net′["ibr"], "pv_b1")        # b1 is degree-3, not a leaf
    @test any(f.code == "I.IBR.PLACED" for f in mf.findings_after)
end

# ── I10: findings — placement summary ────────────────────────────────────────

@testset "I10: I.IBR.PLACED finding" begin
    net = _inv_lv_net()
    _, mf = add_ibrs(net)
    placed = filter(f -> f.code == "I.IBR.PLACED", mf.findings_after)
    @test length(placed) == 1
    @test placed[1].detail["n_placed"] == 1
    @test placed[1].detail["total_s_max_va"] ≈ 2400.0  atol=1e-6
end

# ── I11: apply_placement = false is a no-op copy ─────────────────────────────

@testset "I11: apply_placement disabled" begin
    net = _inv_lv_net()
    net′, mf = add_ibrs(net; recipe = IBRRecipe(apply_placement = false))
    @test !haskey(get(net′, "ibr", Dict()), "pv_b1")
    @test isempty(mf.entries)
end

# ── I12: manifest entries are all :synthetic ─────────────────────────────────

@testset "I12: synthetic manifest entries" begin
    net = _inv_lv_net()
    _, mf = add_ibrs(net)
    @test !isempty(mf.entries)
    @test all(e.confidence == :synthetic for e in mf.entries)
    @test all(startswith(e.rule, "IBR_PLACEMENT/") for e in mf.entries)
    @test any(e.field == "s_max"   for e in mf.entries)
    @test any(e.field == "topology" for e in mf.entries)
end
