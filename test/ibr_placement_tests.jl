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

# Delta (3-wire, no neutral) load — topology must infer THREE_LEG, not FOUR_LEG.
_inv_delta_net() = parse_bmopf("""
{"bus":{
    "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
    "b1": {"terminal_names":["1","2","3"]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
     "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
 "linecode":{"lc":{"R_series_1_1":0.000396,"R_series_2_2":0.000396,"R_series_3_3":0.000396}},
 "line":{"l1":{"bus_from":"src","bus_to":"b1",
     "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
     "linecode":"lc","length":100.0}},
 "load":{"ld":{"bus":"b1","terminal_map":["1","2","3"],"configuration":"DELTA",
     "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]}}}
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

# ── I4b: topology inference — delta (3-wire) load → THREE_LEG (#283) ──────────
@testset "I4b: topology inference (delta, no neutral)" begin
    net = _inv_delta_net()
    net′, _ = add_ibrs(net)
    inv = net′["ibr"]["pv_b1"]
    @test inv["topology"] == "THREE_LEG"           # 3 terminals, no neutral
    @test inv["terminal_map"] == ["1","2","3"]
    @test length(inv["s_max"]) == 3

    # augment_case fills a full 3-entry P/Q box — not truncated to 2 by a
    # length(tm) - 1 phase count that assumed a neutral.
    net3, _ = augment_case(net′)
    inv3 = net3["ibr"]["pv_b1"]
    @test length(inv3["p_max"]) == 3
    @test length(inv3["q_max"]) == 3

    # integrity must not flag the (correct) 3-entry vectors as a dimension
    # mismatch against a bogus 2-phase count.
    f = Finding[]
    integrity_check(net3, f)
    @test !any(x -> x.code == "W.INT.DIM_MISMATCH" && x.component_id == "pv_b1", f)
end

# ── I4c: add_statcom! on a 3-wire (delta) bus → THREE_LEG (#283) ──────────────
@testset "I4c: add_statcom! delta bus" begin
    net = _inv_delta_net()
    add_statcom!(net, "b1"; s_max = 15_000.0)
    inv = net["ibr"]["statcom_b1"]
    @test inv["topology"] == "THREE_LEG"
    @test length(inv["s_max"]) == 3                # one per phase, no neutral
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

# ── I13: add_statcom! writes a STATCOM IBR; augment fills ∓s_max Q box ────────

@testset "I13: add_statcom! nameplate + augment" begin
    net = _inv_lv_net()
    iid = add_statcom!(net, "b1"; s_max = 200_000.0)
    @test iid == "statcom_b1"
    inv = net["ibr"][iid]
    @test inv["bus"] == "b1"
    @test inv["prime_mover"] == "STATCOM"
    @test inv["topology"] == "FOUR_LEG"               # inferred from 4-terminal bus
    @test inv["terminal_map"] == ["1","2","3","n"]
    @test inv["s_max"] ≈ [200_000.0, 200_000.0, 200_000.0]
    @test inv["p_avail"] == 0.0
    @test !haskey(inv, "q_min")                        # deferred to augment_case

    net2, _ = augment_case(net)
    a = net2["ibr"][iid]
    @test a["p_min"] == [0.0, 0.0, 0.0]                # no active source
    @test a["p_max"] == [0.0, 0.0, 0.0]
    @test a["q_max"] ≈ [200_000.0, 200_000.0, 200_000.0]   # = s_max
    @test a["q_min"] ≈ [-200_000.0, -200_000.0, -200_000.0]
end

# ── I14: add_statcom! single-phase bus + per-phase s_max + custom id ──────────

@testset "I14: add_statcom! 1-phase, vector s_max, custom id" begin
    net = _inv_1ph_net()
    iid = add_statcom!(net, "b1"; s_max = [50_000.0], id = "dstat_1")
    @test iid == "dstat_1"
    inv = net["ibr"]["dstat_1"]
    @test inv["topology"] == "SINGLE_PHASE"
    @test inv["s_max"] ≈ [50_000.0]
    @test_throws ArgumentError add_statcom!(net, "b1"; s_max = 1.0, id = "dstat_1")  # dup id
    @test_throws ArgumentError add_statcom!(net, "nope"; s_max = 1.0)               # bad bus
end

# ── I15: add_statcom! dc_link_coupled — active-power circulation augment ──────

@testset "I15: add_statcom! dc_link_coupled" begin
    net = _inv_lv_net()
    iid = add_statcom!(net, "b1"; s_max = 15_000.0, dc_link_coupled = true)
    inv = net["ibr"][iid]
    @test inv["dc_link_coupled"] == true
    @test inv["prime_mover"] == "STATCOM"

    net2, _ = augment_case(net)
    a = net2["ibr"][iid]
    # Per-phase active power is freed to ±s_max (circulation)…
    @test a["p_min"] ≈ [-15_000.0, -15_000.0, -15_000.0]
    @test a["p_max"] ≈ [ 15_000.0,  15_000.0,  15_000.0]
    # …but the net DC-side active power is clamped to zero.
    @test a["p_dc_min"] == 0.0
    @test a["p_dc_max"] == 0.0
    # Reactive capability is still the full converter rating.
    @test a["q_max"] ≈ [15_000.0, 15_000.0, 15_000.0]
    @test a["q_min"] ≈ [-15_000.0, -15_000.0, -15_000.0]

    # Default (reactive-only) path is unchanged: P clamped to zero, no DC fields.
    net3 = _inv_lv_net()
    add_statcom!(net3, "b1"; s_max = 15_000.0)
    @test !haskey(net3["ibr"]["statcom_b1"], "dc_link_coupled")
    net4, _ = augment_case(net3)
    b = net4["ibr"]["statcom_b1"]
    @test b["p_min"] == [0.0, 0.0, 0.0]
    @test b["p_max"] == [0.0, 0.0, 0.0]
    @test !haskey(b, "p_dc_min")
    @test !haskey(b, "p_dc_max")
end

# ── I16: DER/IBR sizing determinism & math (#284, #285) ──────────────────────
# A feeder src → tx(30 kVA) → mv → line → lv, with load on mv (3 kVA) and lv (6 kVA).
_inv_xfmr_net() = Dict{String,Any}(
  "bus"=>Dict{String,Any}(
    "src"=>Dict{String,Any}("terminal_names"=>["1","2","3","n"],"perfectly_grounded_terminals"=>["n"]),
    "mv"=>Dict{String,Any}("terminal_names"=>["1","2","3","n"],"perfectly_grounded_terminals"=>["n"]),
    "lv"=>Dict{String,Any}("terminal_names"=>["1","2","3","n"],"perfectly_grounded_terminals"=>["n"])),
  "voltage_source"=>Dict{String,Any}("vs"=>Dict{String,Any}("bus"=>"src","terminal_map"=>["1","2","3"],
     "v_magnitude"=>[6350.0,6350.0,6350.0],"v_angle"=>[0.0,-2.0944,2.0944])),
  "transformer"=>Dict{String,Any}("single_phase"=>Dict{String,Any}("tx"=>Dict{String,Any}(
     "bus_from"=>"src","bus_to"=>"mv","terminal_map_from"=>["1","2","3"],"terminal_map_to"=>["1","2","3"],
     "s_rating"=>30000.0,"v_nom_from"=>11000.0,"v_nom_to"=>400.0,
     "r_series_from"=>1.0,"r_series_to"=>0.01,"x_series_from"=>5.0,"x_series_to"=>0.05))),
  "linecode"=>Dict{String,Any}("lc"=>Dict{String,Any}("R_series_1_1"=>0.1,"R_series_2_2"=>0.1,"R_series_3_3"=>0.1)),
  "line"=>Dict{String,Any}("l"=>Dict{String,Any}("bus_from"=>"mv","bus_to"=>"lv","linecode"=>"lc","length"=>50.0,
     "terminal_map_from"=>["1","2","3"],"terminal_map_to"=>["1","2","3"])),
  "load"=>Dict{String,Any}(
    "lmv"=>Dict{String,Any}("bus"=>"mv","terminal_map"=>["1","2","3","n"],"configuration"=>"WYE","p_nom"=>[1000.0,1000.0,1000.0],"q_nom"=>[0.0,0.0,0.0]),
    "llv"=>Dict{String,Any}("bus"=>"lv","terminal_map"=>["1","2","3","n"],"configuration"=>"WYE","p_nom"=>[2000.0,2000.0,2000.0],"q_nom"=>[0.0,0.0,0.0])))

@testset "I16a: :fraction_of_downstream_load sizes from downstream, not local (#285)" begin
    net = _inv_xfmr_net()
    nd, _ = add_ibrs(net; recipe = IBRRecipe(size_basis = :fraction_of_downstream_load,
                                             s_fraction = 1.0, strategy = :load_following))
    nl, _ = add_ibrs(net; recipe = IBRRecipe(size_basis = :fraction_of_local_load,
                                             s_fraction = 1.0, strategy = :load_following))
    # mv sees the whole downstream load (mv + lv = 9 kVA), not just its local 3 kVA.
    @test sum(nd["ibr"]["pv_mv"]["s_max"]) > sum(nl["ibr"]["pv_mv"]["s_max"]) + 1.0
    @test sum(nd["ibr"]["pv_mv"]["s_max"]) ≈ 9000.0 rtol = 1e-6
end

@testset "I16b: negative local load never yields a negative rating (#285)" begin
    net = _inv_xfmr_net()
    net["load"]["llv"]["p_nom"] = [-2000.0, -2000.0, -2000.0]   # embedded generation
    nn, _ = add_ibrs(net; recipe = IBRRecipe(size_basis = :fraction_of_local_load,
                                             s_fraction = 1.0, strategy = :load_following))
    @test all(nn["ibr"]["pv_lv"]["s_max"] .>= 0.0)
    @test sum(nn["ibr"]["pv_lv"]["s_max"]) ≈ 6000.0 rtol = 1e-6   # sized by magnitude
end

@testset "I16c: min_local_load_va is an apparent-power threshold (#285)" begin
    net = _inv_xfmr_net()
    # Small active, large reactive: |S| ≈ 6 kVA ≫ 1 kVA, but ΣP = 300 W < 1 kVA.
    net["load"]["llv"]["p_nom"] = [100.0, 100.0, 100.0]
    net["load"]["llv"]["q_nom"] = [2000.0, 2000.0, 2000.0]
    nq, _ = add_ibrs(net; recipe = IBRRecipe(size_basis = :fraction_of_local_load,
                       s_fraction = 1.0, strategy = :load_following, min_local_load_va = 1000.0))
    @test haskey(nq["ibr"], "pv_lv")   # not skipped: |S| clears the VA threshold
end

@testset "I16d: p_avail split ∝ s_max keeps p_max ≤ s_max per phase (#285)" begin
    net = _inv_xfmr_net()
    net["load"]["llv"]["p_nom"] = [3000.0, 1000.0, 500.0]   # unbalanced
    np, _  = add_ibrs(net; recipe = IBRRecipe(size_basis = :fraction_of_local_load,
                                              s_fraction = 1.0, strategy = :load_following))
    npa, _ = augment_case(np)
    inv = npa["ibr"]["pv_lv"]
    @test all(inv["p_max"] .<= inv["s_max"] .+ 1e-6)   # equal split would violate this
end

@testset "I16e: nearest transformer wins deterministically (#284)" begin
    # src → t1(HV/MV) → mv → t2(MV/LV) → lv. Bus lv is downstream of BOTH; the
    # NEARER (smaller downstream set) transformer t2 must own it, every run.
    net = _inv_xfmr_net()
    net["bus"]["lv2"] = Dict{String,Any}("terminal_names"=>["1","2","3","n"],"perfectly_grounded_terminals"=>["n"])
    net["transformer"]["single_phase"]["t2"] = Dict{String,Any}(
        "bus_from"=>"lv","bus_to"=>"lv2","terminal_map_from"=>["1","2","3"],"terminal_map_to"=>["1","2","3"],
        "s_rating"=>10000.0,"v_nom_from"=>400.0,"v_nom_to"=>230.0,
        "r_series_from"=>0.1,"r_series_to"=>0.01,"x_series_from"=>0.5,"x_series_to"=>0.05)
    net["load"]["llv2"] = Dict{String,Any}("bus"=>"lv2","terminal_map"=>["1","2","3","n"],
        "configuration"=>"WYE","p_nom"=>[500.0,500.0,500.0],"q_nom"=>[0.0,0.0,0.0])
    ids = String[]
    sized = Float64[]
    for _ in 1:5
        nd, _ = add_ibrs(net; recipe = IBRRecipe(size_basis = :fraction_of_transformer_rating,
                                                 s_fraction = 0.5, strategy = :load_following))
        push!(sized, sum(nd["ibr"]["pv_lv2"]["s_max"]))
    end
    # lv2's basis must be the NEAREST transformer t2 (10 kVA, load-share 1) →
    # s_max = 0.5 × 10 kVA = 5 kVA, deterministically. The far transformer t1
    # (30 kVA, small share) would give ~2.1 kVA; which one won used to depend on
    # Dict iteration order.
    @test length(unique(round.(sized; digits = 3))) == 1
    @test sized[1] ≈ 5000.0 rtol = 1e-3
end
