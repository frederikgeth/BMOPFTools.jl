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
                    "dc_bus":"dcA","dc_terminal_map":["p","m"]},
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
        # Signed DC pole voltage within its band; return pinned to 0.
        vp = res["dc_bus"]["dcA"]["p"]["v_dc"]
        @test 700.0 - 1e-3 <= vp <= 900.0 + 1e-3
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
                    "dc_bus":"dcA","dc_terminal_map":["p","m"]},
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
                    "dc_bus":"dcA","dc_terminal_map":["p","m"]}},
         "dc_bus":{
            "dcA":{"terminal_names":["p","m"],"pole":{"p":"POSITIVE","m":"METALLIC_RETURN"},
                   "v_dc_min":[700.0,0.0],"v_dc_max":[900.0,0.0]}},
         "dc_grounding":{"g":{"dc_bus":"dcA","terminal":"m"}}}
        """; from_string=true)

        res = solve_opf(net)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        @test res["dc_bus"]["dcA"]["m"]["v_dc"] ≈ 0.0 atol=1e-6
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
    @test "E.SPEC.DC_BUS_ARITY" in codes           # 4-wire dc_bus
    @test "E.DOM.DC_R_NEGATIVE" in codes           # r = −0.1
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
