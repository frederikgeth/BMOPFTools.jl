# DC-network OPF tests: converter stations modelled as DC-coupled IBRs.
# Included from runtests.jl when JuMP and Ipopt are in the load path.
#
# Each fixture is a minimal converter station whose optimal dispatch is
# analytically checkable: lossless converters make the AC active power equal the
# DC-port power, so a back-to-back SOP conserves power exactly, and an MVDC tie
# loses precisely I²R on its DC line.

@testset "DC network — converter stations" begin

    # ─────────────────────────────────────────────────────────────────────────
    # D1: Back-to-back SOP on one shared DC bus.
    #
    # Two single-phase converters share dc_bus "dcA" (pole p + grounded return m).
    # Feeder 1 source is cheap, feeder 2 source is expensive and carries the load,
    # so the optimum imports on feeder 1 and exports on feeder 2. Lossless ⇒
    # vsc1.pg = −vsc2.pg exactly, and DC KCL balances.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "D1: back-to-back SOP — lossless power conservation" begin
        net = parse_bmopf("""
        {"bus":{
            "f1":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],
                  "v_min":[220.0],"v_max":[245.0]},
            "f2":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],
                  "v_min":[220.0],"v_max":[245.0]}},
         "voltage_source":{
            "s1":{"bus":"f1","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],
                  "v_angle":[0.0,0.0],"cost":[1.0]},
            "s2":{"bus":"f2","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],
                  "v_angle":[0.0,0.0],"cost":[10.0]}},
         "load":{
            "L2":{"bus":"f2","terminal_map":["a","n"],"configuration":"SINGLE_PHASE",
                  "p_nom":[5000.0],"q_nom":[0.0]}},
         "ibr":{
            "vsc1":{"bus":"f1","terminal_map":["a","n"],"topology":"SINGLE_PHASE",
                    "prime_mover":"GENERIC","s_max":[8000.0],
                    "dc_bus":"dcA","dc_terminal_map":["p","m"],
                    "dc_control":"V","dc_v_set":800.0},
            "vsc2":{"bus":"f2","terminal_map":["a","n"],"topology":"SINGLE_PHASE",
                    "prime_mover":"GENERIC","s_max":[8000.0],
                    "dc_bus":"dcA","dc_terminal_map":["p","m"]}},
         "dc_bus":{
            "dcA":{"terminal_names":["p","m"],
                   "pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
                   "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]}},
         "dc_grounding":{"g":{"dc_bus":"dcA","terminal":"m","r":0.0}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        p1 = res["ibr"]["vsc1"]["a"]["pg"]
        p2 = res["ibr"]["vsc2"]["a"]["pg"]
        # No DC line ⇒ perfectly lossless: the two converters' AC powers cancel.
        @test p1 + p2 ≈ 0.0 atol=1e-3
        # Economic direction: import on the cheap feeder (vsc1 absorbs, p1 < 0).
        @test p1 < -1.0
        @test p2 > 1.0
        # The V-master pins the DC pole-to-return voltage to its 800 V setpoint;
        # return pinned to 0.
        vp = res["dc_bus"]["dcA"]["p"]["v_dc"]
        @test vp ≈ 800.0 atol=1e-2
        @test res["dc_bus"]["dcA"]["m"]["v_dc"] ≈ 0.0 atol=1e-6
    end

    # ─────────────────────────────────────────────────────────────────────────
    # D2: MVDC tie — two stations joined by a resistive DC pole conductor.
    #
    # Power flows f1 → dcA → DC line (r = 0.5 Ω) → dcB → f2. The converter power
    # gap equals the DC line loss I²R, and the pole-voltage drop equals I·R.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "D2: MVDC tie — DC line loss = I²R" begin
        net = parse_bmopf("""
        {"bus":{
            "f1":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],
                  "v_min":[220.0],"v_max":[245.0]},
            "f2":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],
                  "v_min":[220.0],"v_max":[245.0]}},
         "voltage_source":{
            "s1":{"bus":"f1","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],
                  "v_angle":[0.0,0.0],"cost":[1.0]},
            "s2":{"bus":"f2","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],
                  "v_angle":[0.0,0.0],"cost":[10.0]}},
         "load":{
            "L2":{"bus":"f2","terminal_map":["a","n"],"configuration":"SINGLE_PHASE",
                  "p_nom":[5000.0],"q_nom":[0.0]}},
         "ibr":{
            "vsc1":{"bus":"f1","terminal_map":["a","n"],"topology":"SINGLE_PHASE",
                    "prime_mover":"GENERIC","s_max":[8000.0],
                    "dc_bus":"dcA","dc_terminal_map":["p","m"],
                    "dc_control":"V","dc_v_set":850.0},
            "vsc2":{"bus":"f2","terminal_map":["a","n"],"topology":"SINGLE_PHASE",
                    "prime_mover":"GENERIC","s_max":[8000.0],
                    "dc_bus":"dcB","dc_terminal_map":["p","m"]}},
         "dc_bus":{
            "dcA":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
                   "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]},
            "dcB":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
                   "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]}},
         "dc_branch":{
            "line":{"dc_bus_from":"dcA","dc_bus_to":"dcB",
                    "terminal_map_from":["p","m"],"terminal_map_to":["p","m"],
                    "r":[0.5,0.0]}},
         "dc_grounding":{"gA":{"dc_bus":"dcA","terminal":"m","r":0.0}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

        p1 = res["ibr"]["vsc1"]["a"]["pg"]   # into AC f1 (negative = importing)
        p2 = res["ibr"]["vsc2"]["a"]["pg"]   # into AC f2 (positive = exporting)
        i  = res["dc_branch"]["line"]["1"]["i_dc"]
        vA = res["dc_bus"]["dcA"]["p"]["v_dc"]
        vB = res["dc_bus"]["dcB"]["p"]["v_dc"]

        # Ohm's law on the pole conductor.
        @test i ≈ (vA - vB) / 0.5 atol=1e-3
        # Converter power gap equals the DC line loss I²R.
        loss = -p1 - p2                       # power in minus power out
        @test loss ≈ i^2 * 0.5 atol=1.0
        @test loss > 0.0                      # genuinely lossy
        # Voltages within band.
        @test 700.0 - 1e-3 <= vB <= 900.0 + 1e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # D3: Monopole with earth return (1-wire DC port) + DC voltage reference.
    #
    # A single converter on a 1-terminal DC bus, returning through earth via a
    # perfect dc_grounding. With only one converter there is no transfer, but the
    # model must solve with the DC voltage referenced (not floating).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "D3: monopole earth-return solves and references v_dc" begin
        net = parse_bmopf("""
        {"bus":{
            "f1":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],
                  "v_min":[220.0],"v_max":[245.0]}},
         "voltage_source":{
            "s1":{"bus":"f1","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],
                  "v_angle":[0.0,0.0]}},
         "ibr":{
            "vsc1":{"bus":"f1","terminal_map":["a","n"],"topology":"SINGLE_PHASE",
                    "prime_mover":"STATCOM","s_max":[5000.0],
                    "dc_bus":"dcA","dc_terminal_map":["p","m"],
                    "dc_control":"V","dc_v_set":800.0}},
         "dc_bus":{
            "dcA":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
                   "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]}},
         "dc_grounding":{"g":{"dc_bus":"dcA","terminal":"m"}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["dc_bus"]["dcA"]["m"]["v_dc"] ≈ 0.0 atol=1e-6
    end

    # ─────────────────────────────────────────────────────────────────────────
    # D4: per-unit scaling of the DC network. The DC quantities (v_dc ~ 850,
    # dc_branch r, dc_load p) must be scaled consistently with the AC side, so a
    # per_unit=true solve (a) succeeds and (b) reproduces the SI answer exactly
    # on a genuine-transfer case whose physics is pinned by Ohm's law + i²R.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "D4: per_unit reproduces SI on a DC transfer case" begin
        mk() = parse_bmopf("""
        {"bus":{"f1":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"]},
                "f2":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{
            "s1":{"bus":"f1","terminal_map":["a","n"],"v_magnitude":[230.0],"v_angle":[0.0],"cost":[1.0]},
            "s2":{"bus":"f2","terminal_map":["a","n"],"v_magnitude":[230.0],"v_angle":[0.0],"cost":[10.0]}},
         "load":{"L2":{"bus":"f2","terminal_map":["a","n"],"configuration":"SINGLE_PHASE",
                       "p_nom":[5000.0],"q_nom":[0.0]}},
         "ibr":{
            "vsc1":{"bus":"f1","terminal_map":["a","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC",
                    "s_max":[8000.0],"dc_bus":"dcA","dc_terminal_map":["p","m"],
                    "dc_control":"V","dc_v_set":850.0},
            "vsc2":{"bus":"f2","terminal_map":["a","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC",
                    "s_max":[8000.0],"dc_bus":"dcB","dc_terminal_map":["p","m"]}},
         "dc_bus":{
            "dcA":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
                   "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0],"v_dc_nom":[850.0,0.0]},
            "dcB":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
                   "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0],"v_dc_nom":[850.0,0.0]}},
         "dc_branch":{"line":{"dc_bus_from":"dcA","dc_bus_to":"dcB",
                    "terminal_map_from":["p","m"],"terminal_map_to":["p","m"],"r":[0.5,0.0]}},
         "dc_grounding":{"gA":{"dc_bus":"dcA","terminal":"m","r":0.0}}}
        """; from_string=true)

        si = solve_opf(mk(); per_unit=false)
        pu = solve_opf(mk(); per_unit=true)
        @test pu["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        vA = pu["dc_bus"]["dcA"]["p"]["v_dc"]; vB = pu["dc_bus"]["dcB"]["p"]["v_dc"]
        i  = pu["dc_branch"]["line"]["1"]["i_dc"]
        # Results are returned in SI regardless of the internal per-unit solve.
        @test vA ≈ si["dc_bus"]["dcA"]["p"]["v_dc"] atol=1e-1
        @test vB ≈ si["dc_bus"]["dcB"]["p"]["v_dc"] atol=1e-1
        @test i  ≈ si["dc_branch"]["line"]["1"]["i_dc"] atol=1e-2
        # Physics holds on the unscaled result: Ohm's law and DC line loss.
        @test i ≈ (vA - vB) / 0.5 atol=1e-2
        loss = -pu["ibr"]["vsc1"]["a"]["pg"] - pu["ibr"]["vsc2"]["a"]["pg"]
        @test loss ≈ i^2 * 0.5 atol=1.0
        @test 700.0 - 1e-3 <= vB <= 900.0 + 1e-3
    end

end

# ── Validation findings (no solver needed) ──────────────────────────────────
@testset "DC network — validation findings" begin
    # Dangling dc_bus reference, missing grounding, negative resistance.
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}("b1" => Dict{String,Any}(
            "terminal_names" => ["a","n"])),
        "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}(
            "bus"=>"b1","terminal_map"=>["a","n"],
            "v_magnitude"=>[230.0,0.0],"v_angle"=>[0.0,0.0])),
        "ibr" => Dict{String,Any}("vsc" => Dict{String,Any}(
            "bus"=>"b1","terminal_map"=>["a","n"],"topology"=>"SINGLE_PHASE",
            "prime_mover"=>"GENERIC","s_max"=>[1.0e4],
            "dc_bus"=>"dcA","dc_terminal_map"=>["p","m"])),
        "dc_bus" => Dict{String,Any}("dcA" => Dict{String,Any}(
            "terminal_names" => ["p","m","x","y"])),         # arity 4 → error
        "dc_branch" => Dict{String,Any}("br" => Dict{String,Any}(
            "dc_bus_from"=>"dcA","dc_bus_to"=>"nope",        # dangling endpoint
            "terminal_map_from"=>["p","m"],"terminal_map_to"=>["p","m"],
            "r"=>[-0.1])),                                    # negative r
    )
    findings = BMOPFTools.Finding[]
    BMOPFTools.integrity_check(net, findings)
    BMOPFTools.spec_conformance_check(net, findings)
    BMOPFTools.domain_rules_check(net, findings)
    codes = Set(f.code for f in findings)

    @test "E.INT.UNKNOWN_DC_BUS" in codes          # dc_branch → "nope"
    @test "E.INT.NO_DC_VOLTAGE_REFERENCE" in codes # no grounding on the island
    @test "E.INT.DC_NO_VOLTAGE_CONTROL" in codes   # both converters default P-control
    @test "E.SPEC.DC_BUS_ARITY" in codes           # 4-wire dc_bus
    @test "E.DOM.DC_R_NEGATIVE" in codes           # r = −0.1

    # Line-to-neutral bound without a pole role to orient it → required-role error.
    net2 = Dict{String,Any}(
        "bus" => Dict{String,Any}("b1" => Dict{String,Any}("terminal_names"=>["a","n"])),
        "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}(
            "bus"=>"b1","terminal_map"=>["a","n"],
            "v_magnitude"=>[230.0,0.0],"v_angle"=>[0.0,0.0])),
        "dc_bus" => Dict{String,Any}("dcA" => Dict{String,Any}(
            "terminal_names"=>["p","m"], "vdc_ln_max"=>800.0)),   # no `pole` map
    )
    f2 = BMOPFTools.Finding[]
    BMOPFTools.domain_rules_check(net2, f2)
    @test "E.DOM.DC_POLE_ROLE_REQUIRED" in [f.code for f in f2]

    # Droop reference power beyond the converter's capability → DC_DROOP_BOUNDS.
    net3 = Dict{String,Any}(
        "ibr" => Dict{String,Any}("vD" => Dict{String,Any}(
            "bus"=>"b1","terminal_map"=>["a","n"],"topology"=>"SINGLE_PHASE",
            "prime_mover"=>"GENERIC","s_max"=>[5000.0],
            "dc_bus"=>"dcA","dc_terminal_map"=>["p","m"],
            "dc_control"=>"droop","dc_v_set"=>800.0,"dc_droop"=>0.001,
            "dc_p_ref"=>20000.0)),                       # 20 kW ≫ 5 kVA capability
        "dc_bus" => Dict{String,Any}("dcA" => Dict{String,Any}(
            "terminal_names"=>["p","m"])),
    )
    f3 = BMOPFTools.Finding[]
    BMOPFTools.domain_rules_check(net3, f3)
    @test "W.DOM.DC_DROOP_BOUNDS" in [f.code for f in f3]
end

@testset "DC network — converter DC-voltage control" begin
    # Two converters share dcA: vM is the V-master (pins v_dc = v_set), vD runs
    # droop. Driven at its reference voltage the droop converter outputs dc_p_ref;
    # driven far past its band it saturates at the converter limit ±Σs_max.
    mk(vset_master, vD_extra) = parse_bmopf("""
    {"bus":{
        "f1":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],"v_min":[210.0],"v_max":[250.0]},
        "f2":{"terminal_names":["a","n"],"perfectly_grounded_terminals":["n"],"v_min":[210.0],"v_max":[250.0]}},
     "voltage_source":{
        "s1":{"bus":"f1","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],"v_angle":[0.0,0.0],"cost":[1.0]},
        "s2":{"bus":"f2","terminal_map":["a","n"],"v_magnitude":[230.0,0.0],"v_angle":[0.0,0.0],"cost":[1.0]}},
     "ibr":{
        "vM":{"bus":"f1","terminal_map":["a","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[20000.0],
              "dc_bus":"dcA","dc_terminal_map":["p","m"],"dc_control":"V","dc_v_set":$(vset_master)},
        "vD":{"bus":"f2","terminal_map":["a","n"],"topology":"SINGLE_PHASE","prime_mover":"GENERIC","s_max":[8000.0],
              "dc_bus":"dcA","dc_terminal_map":["p","m"],"dc_control":"droop",$(vD_extra)}},
     "dc_bus":{"dcA":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
                      "v_dc_min":[600.0,0.0],"v_dc_max":[1000.0,0.0]}},
     "dc_grounding":{"g":{"dc_bus":"dcA","terminal":"m","r":0.0}}}
    """; from_string=true)

    @testset "droop at reference → p_ref" begin
        # master pins v_dc = 800 = vD's dc_v_set ⇒ droop sits at its reference power.
        net = mk(800.0, "\"dc_v_set\":800.0,\"dc_droop\":0.001,\"dc_p_ref\":3000.0")
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["dc_bus"]["dcA"]["p"]["v_dc"] ≈ 800.0 atol=1e-2
        @test res["ibr"]["vD"]["a"]["pg"] ≈ 3000.0 atol=5.0
    end

    @testset "droop driven past band → saturates at Σs_max" begin
        # master pins v_dc = 1000, vD's droop centred at 600 with a stiff slope ⇒
        # the droop line demands huge power; it must clamp at +s_max = 8000 W.
        net = mk(1000.0, "\"dc_v_set\":600.0,\"dc_droop\":1.0e-5,\"dc_p_ref\":0.0")
        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["ibr"]["vD"]["a"]["pg"] ≈ 8000.0 atol=20.0   # saturated, not >>8000
    end
end

@testset "DC network — dangling converter detection" begin
    # AC source on f1 → conv → dcA ── dc line ── dcB → conv → bare bus x.
    # Bus x has no AC source/grounding and no grid-forming converter, so it is
    # energised only through the MVDC link → flagged as not embedded.
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "f1" => Dict{String,Any}("terminal_names"=>["a","n"],
                                     "perfectly_grounded_terminals"=>["n"]),
            "x"  => Dict{String,Any}("terminal_names"=>["a","n"])),
        "voltage_source" => Dict{String,Any}("s1" => Dict{String,Any}(
            "bus"=>"f1","terminal_map"=>["a","n"],
            "v_magnitude"=>[230.0,0.0],"v_angle"=>[0.0,0.0])),
        "ibr" => Dict{String,Any}(
            "c1" => Dict{String,Any}("bus"=>"f1","terminal_map"=>["a","n"],
                "topology"=>"SINGLE_PHASE","prime_mover"=>"GENERIC","s_max"=>[1.0e4],
                "dc_bus"=>"dcA","dc_terminal_map"=>["p","m"]),
            "c2" => Dict{String,Any}("bus"=>"x","terminal_map"=>["a","n"],
                "topology"=>"SINGLE_PHASE","prime_mover"=>"GENERIC","s_max"=>[1.0e4],
                "dc_bus"=>"dcB","dc_terminal_map"=>["p","m"])),
        "dc_bus" => Dict{String,Any}(
            "dcA" => Dict{String,Any}("terminal_names"=>["p","m"]),
            "dcB" => Dict{String,Any}("terminal_names"=>["p","m"])),
        "dc_branch" => Dict{String,Any}("l" => Dict{String,Any}(
            "dc_bus_from"=>"dcA","dc_bus_to"=>"dcB",
            "terminal_map_from"=>["p","m"],"terminal_map_to"=>["p","m"],
            "r"=>[0.5,0.5])),
        "dc_grounding" => Dict{String,Any}("g" => Dict{String,Any}(
            "dc_bus"=>"dcA","terminal"=>"m")),
    )
    findings = BMOPFTools.Finding[]
    BMOPFTools.integrity_check(net, findings)
    codes = [f.code for f in findings]
    @test "W.INT.DC_FED_AC_ISLAND" in codes

    # Marking c2 grid-forming makes bus x referenceable → no flag.
    net["ibr"]["c2"]["grid_forming"] = true
    f2 = BMOPFTools.Finding[]
    BMOPFTools.integrity_check(net, f2)
    @test !("W.INT.DC_FED_AC_ISLAND" in [f.code for f in f2])
end

@testset "DC network — ASCII tree overlay" begin
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "f1" => Dict{String,Any}("terminal_names"=>["a","n"],
                                     "perfectly_grounded_terminals"=>["n"]),
            "f2" => Dict{String,Any}("terminal_names"=>["a","n"],
                                     "perfectly_grounded_terminals"=>["n"])),
        "voltage_source" => Dict{String,Any}("s1" => Dict{String,Any}(
            "bus"=>"f1","terminal_map"=>["a","n"],
            "v_magnitude"=>[230.0,0.0],"v_angle"=>[0.0,0.0])),
        "line" => Dict{String,Any}(),
        "ibr" => Dict{String,Any}(
            "vsc1" => Dict{String,Any}("bus"=>"f1","terminal_map"=>["a","n"],
                "topology"=>"SINGLE_PHASE","prime_mover"=>"GENERIC","s_max"=>[1.0e4],
                "dc_bus"=>"dcA","dc_terminal_map"=>["p","m"]),
            "vsc2" => Dict{String,Any}("bus"=>"f2","terminal_map"=>["a","n"],
                "topology"=>"SINGLE_PHASE","prime_mover"=>"GENERIC","s_max"=>[1.0e4],
                "dc_bus"=>"dcA","dc_terminal_map"=>["p","m"])),
        "dc_bus" => Dict{String,Any}("dcA" => Dict{String,Any}(
            "terminal_names"=>["p","m"],
            "pole"=>Dict{String,Any}("p"=>"POSITIVE","m"=>"METALLIC_RETURN"))),
        "dc_grounding" => Dict{String,Any}("g" => Dict{String,Any}(
            "dc_bus"=>"dcA","terminal"=>"m")),
    )
    io = IOBuffer()
    BMOPFTools.render_ascii_tree(net, io)
    s = String(take!(io))
    @test occursin("DC network", s)
    @test occursin("converter station", s)   # vsc1 + vsc2 share dcA
    @test occursin("vsc1", s) && occursin("vsc2", s)
    @test occursin("⏚", s)                    # grounded return marked
end
