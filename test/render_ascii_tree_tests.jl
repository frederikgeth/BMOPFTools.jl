# render_ascii_tree_tests.jl
#
# Coverage for the ASCII tree renderer. No solver required — every path is a
# pure transform of the parsed network dict to text. We render to an IOBuffer
# and assert on the emitted string.

@testset "render_ascii_tree" begin

    # render to string helper
    rstr(net; kw...) = (io = IOBuffer();
                        render_ascii_tree(net, io; kw...); String(take!(io)))

    @testset "single-feeder network renders one tree with legend" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        out = rstr(net)

        @test occursin("# Network graph", out)
        @test occursin("SRC", out)               # source bus tagged
        @test occursin("├──", out) || occursin("└──", out)   # box-drawing edges
        @test occursin("Loads (", out)           # load legend printed
        @test occursin("Generators (", out)      # generator legend printed
        @test occursin("G1", out)                # gen_634 numbered in legend
        # IEEE13 fixture has a single level-crossing transformer (4160/480 V),
        # so split mode must NOT activate — no "MV backbone" header.
        @test !occursin("MV backbone", out)
    end

    @testset "multi-feeder network splits into MV backbone + LV sections" begin
        # Two distribution transformers (11 kV → 400 V) each feed their own LV
        # bus → ≥2 level-crossing edges → split mode.
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "mv1":{"terminal_names":["1","2","3","n"]},
            "mv2":{"terminal_names":["1","2","3","n"]},
            "lvA":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
            "lvB":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[6350.0,6350.0,6350.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1}},
         "line":{
             "l_src_mv1":{"bus_from":"src","bus_to":"mv1","terminal_map_from":["1","2","3"],
                 "terminal_map_to":["1","2","3"],"linecode":"lc","length":100.0},
             "l_mv1_mv2":{"bus_from":"mv1","bus_to":"mv2","terminal_map_from":["1","2","3"],
                 "terminal_map_to":["1","2","3"],"linecode":"lc","length":100.0}},
         "transformer":{"delta_wye":{
             "txA":{"bus_from":"mv1","bus_to":"lvA","terminal_map_from":["1","2","3"],
                 "terminal_map_to":["1","2","3","n"],"s_rating":250000.0,
                 "v_ref_from":11000.0,"v_ref_to":400.0},
             "txB":{"bus_from":"mv2","bus_to":"lvB","terminal_map_from":["1","2","3"],
                 "terminal_map_to":["1","2","3","n"],"s_rating":250000.0,
                 "v_ref_from":11000.0,"v_ref_to":400.0}}},
         "load":{
             "ldA":{"bus":"lvA","terminal_map":["1","2","3","n"],"configuration":"WYE",
                 "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]},
             "ldB":{"bus":"lvB","terminal_map":["1","2","3","n"],"configuration":"WYE",
                 "p_nom":[2000.0,2000.0,2000.0],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        out = rstr(net)
        @test occursin("MV backbone", out)
        @test occursin("# Section 1", out)
        @test occursin("# Section 2", out)
        @test occursin("→ Section", out)        # backbone pointer stubs
        @test occursin("txA", out) && occursin("txB", out)

        # split_by_level=false forces a single tree even with crossing transformers
        out_nosplit = rstr(net; split_by_level=false)
        @test !occursin("MV backbone", out_nosplit)
    end

    @testset "fold_chains collapses unannotated corridors" begin
        # A long single-child chain of un-annotated buses. max_buses small → the
        # render runs in compact mode and folds the corridor into a ⋮ stub.
        buses = join(["\"b$i\":{\"terminal_names\":[\"1\",\"n\"]}" for i in 1:8], ",")
        lines = join(vcat(
            ["\"l0\":{\"bus_from\":\"src\",\"bus_to\":\"b1\",\"terminal_map_from\":[\"1\"],\"terminal_map_to\":[\"1\"],\"linecode\":\"lc\",\"length\":1.0}"],
            ["\"l$i\":{\"bus_from\":\"b$i\",\"bus_to\":\"b$(i+1)\",\"terminal_map_from\":[\"1\"],\"terminal_map_to\":[\"1\"],\"linecode\":\"lc\",\"length\":1.0}" for i in 1:7],
        ), ",")
        net = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},$buses},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.1}},
         "line":{$lines}}
        """; from_string=true)

        out = rstr(net; max_buses=3, fold_chains=true)
        @test occursin("compressed", out)        # header notes compression
        @test occursin("⋮", out)                 # folded-chain stub

        # with folding off the stub disappears (chain printed in full)
        out_nofold = rstr(net; max_buses=3, fold_chains=false, max_depth=100)
        @test !occursin("⋮", out_nofold)
    end

    @testset "max_depth collapses deep subtrees" begin
        buses = join(["\"b$i\":{\"terminal_names\":[\"1\",\"n\"]}" for i in 1:6], ",")
        lines = join(vcat(
            ["\"l0\":{\"bus_from\":\"src\",\"bus_to\":\"b1\",\"terminal_map_from\":[\"1\"],\"terminal_map_to\":[\"1\"],\"linecode\":\"lc\",\"length\":1.0}"],
            ["\"l$i\":{\"bus_from\":\"b$i\",\"bus_to\":\"b$(i+1)\",\"terminal_map_from\":[\"1\"],\"terminal_map_to\":[\"1\"],\"linecode\":\"lc\",\"length\":1.0}" for i in 1:5],
        ), ",")
        net = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},$buses},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.1}},
         "line":{$lines}}
        """; from_string=true)

        # compact mode on (max_buses small), folding off → depth collapse fires
        out = rstr(net; max_buses=2, max_depth=2, fold_chains=false)
        @test occursin("buses", out)
        @test occursin("[+", out)                 # "[+N buses, M loads]" summary
    end

    @testset "disconnected buses are reported separately" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "b1":{"terminal_names":["1","n"]},
            "island":{"terminal_names":["1","n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.1}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1","terminal_map_from":["1"],
             "terminal_map_to":["1"],"linecode":"lc","length":1.0}}}
        """; from_string=true)

        out = rstr(net)
        @test occursin("Disconnected buses", out)
        @test occursin("island", out)
    end

    @testset "switch edges are annotated (open vs closed)" begin
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "b1":{"terminal_names":["1","n"]},
            "b2":{"terminal_names":["1","n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "switch":{
             "sw_closed":{"bus_from":"src","bus_to":"b1"},
             "sw_open":{"bus_from":"src","bus_to":"b2","open_switch":true}}}
        """; from_string=true)

        out = rstr(net)
        @test occursin("[SW]", out)
        @test occursin("[SW:open]", out)
    end

    @testset "legend_limit truncates the load list" begin
        nloads = 12
        loadj = join(["\"ld$i\":{\"bus\":\"b1\",\"terminal_map\":[\"1\",\"n\"],\"configuration\":\"SINGLE_PHASE\",\"p_nom\":[$(100.0*i)],\"q_nom\":[0.0]}" for i in 1:nloads], ",")
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "b1":{"terminal_names":["1","n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":0.1}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1","terminal_map_from":["1"],
             "terminal_map_to":["1"],"linecode":"lc","length":1.0}},
         "load":{$loadj}}
        """; from_string=true)

        out = rstr(net; legend_limit=5)
        @test occursin("Loads ($nloads total)", out)
        @test occursin("and $(nloads - 5) more", out)
    end
end
