# AC sections coupled through DC links: one network for topology and path metrics.

using Test
using BMOPFTools
isdefined(@__MODULE__, :_PG_PF) || include("profiler_test_helpers.jl")

@testset "Profiler: DC links" begin
    @testset "AC sections joined over a DC link are one network" begin
        net = _pg_sys("eu_tn_four_wire")
        net["bus"]["isl"] = Dict{String,Any}("terminal_names" => ["a","b","c","n"],
            "perfectly_grounded_terminals" => ["n"])
        net["load"]["isl_load"] = Dict{String,Any}("bus" => "isl", "terminal_map" => ["a","n"],
            "configuration" => "SINGLE_PHASE", "p_nom" => [1000.0], "q_nom" => [0.0])
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test "E.CONN.DISCONNECTED" in _pg_codes(f) && isempty(r["dc_links"])
        net["dc_bus"] = Dict{String,Any}("d1" => Dict{String,Any}("terminal_names" => ["p","n"]),
                                         "d2" => Dict{String,Any}("terminal_names" => ["p","n"]))
        net["dc_branch"] = Dict{String,Any}("cable" => Dict{String,Any}("dc_bus_from" => "d1",
            "dc_bus_to" => "d2", "terminal_map_from" => ["p","n"], "terminal_map_to" => ["p","n"], "r" => 0.1))
        conv(bus, dc) = Dict{String,Any}("bus" => bus, "dc_bus" => dc, "terminal_map" => ["a","b","c"],
            "topology" => "THREE_LEG", "prime_mover" => "CONVERTER", "s_max" => [1e4])
        net["ibr"] = Dict{String,Any}("c1" => conv("lv2", "d1"), "c2" => conv("isl", "d2"))
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test !("E.CONN.DISCONNECTED" in _pg_codes(f))
        @test r["dc_links"] == [["isl", "lv2"]] && r["is_radial"]
        # Boundary: converters on separate DC islands do not join anything.
        delete!(net, "dc_branch")
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test "E.CONN.DISCONNECTED" in _pg_codes(f) && isempty(r["dc_links"])
        # A DC link between two buses of one AC network closes a loop.
        net["dc_branch"] = Dict{String,Any}("cable" => Dict{String,Any}("dc_bus_from" => "d1",
            "dc_bus_to" => "d2", "terminal_map_from" => ["p","n"], "terminal_map_to" => ["p","n"], "r" => 0.1))
        net["ibr"]["c2"]["bus"] = "lv1"; delete!(net["bus"], "isl"); delete!(net["load"], "isl_load")
        f = Finding[]
        r = connectivity_analysis(net, f)
        @test !r["is_radial"] && "W.CONN.MESHED" in _pg_codes(f)
    end

    @testset "a long DC chain is one link" begin
        net = _pg_sys("eu_tn_four_wire")
        n = 20_000
        net["dc_bus"] = Dict{String,Any}("d$k" => Dict{String,Any}("terminal_names" => ["p","n"]) for k in 1:n)
        net["dc_branch"] = Dict{String,Any}("c$k" => Dict{String,Any}("dc_bus_from" => "d$k",
            "dc_bus_to" => "d$(k+1)") for k in 1:n-1)
        net["ibr"] = Dict{String,Any}(
            "c1" => Dict{String,Any}("bus" => "lv1", "dc_bus" => "d1"),
            "c2" => Dict{String,Any}("bus" => "lv2", "dc_bus" => "d$n"))
        @test BMOPFTools._dc_link_ac_groups(net) == [["lv1", "lv2"]]
    end

    @testset "DC-linked path metrics do not depend on bus names" begin
        build(names) = begin
            net = _pg_sys("eu_tn_four_wire")
            # three AC end buses hanging off lv2, each with a converter on ONE DC bus
            net["dc_bus"] = Dict{String,Any}("d" => Dict{String,Any}("terminal_names" => ["p","n"]))
            net["ibr"] = Dict{String,Any}()
            for (k, name) in enumerate(names)
                net["bus"][name] = Dict{String,Any}("terminal_names" => ["a","b","c","n"])
                net["ibr"]["c$k"] = Dict{String,Any}("bus" => name, "dc_bus" => "d")
            end
            net["line"]["tie"] = Dict{String,Any}("bus_from" => "lv2", "bus_to" => names[1],
                "linecode" => "cable", "length" => 20.0,
                "terminal_map_from" => ["a","b","c","n"], "terminal_map_to" => ["a","b","c","n"])
            connectivity_analysis(net, Finding[])
        end
        ra = build(("x1", "x2", "x3")); rb = build(("x3", "x1", "x2")); rc = build(("x2", "x3", "x1"))
        @test ra["tree_depth_max"] == rb["tree_depth_max"] == rc["tree_depth_max"]
        @test ra["degree_max"] == rb["degree_max"] == rc["degree_max"]
        @test ra["n_degree_1"] == rb["n_degree_1"] == rc["n_degree_1"] == 3   # mv and the two far converter buses
        @test ra["is_radial"] && rb["is_radial"] && rc["is_radial"] && ra["is_connected"]
        @test ra["n_extra_edges"] + ra["neutral_only_cycle_rank"] ==
              ra["structure"]["whole_network"]["cycle_rank"] == 0
        # mv - lv0 - lv1 - lv2 - first - island - other: the island hop counts two.
        @test ra["tree_depth_max"] == 6
        # The bus path lists AC buses only (placement strategies slice it);
        # the walk with the island vertex is separate.
        @test !any(startswith("dc_island:"), ra["longest_path_buses"])
        @test any(startswith("dc_island:"), ra["longest_path_vertices"])
        @test length(ra["longest_path_vertices"]) == length(ra["longest_path_buses"]) + 1
        @test !any(startswith("dc_island:"), ra["degree_1_buses"])
        # A real AC bus whose id looks like a DC-island label is still a bus:
        # vertices are told apart by identity, not by name.
        named = _pg_sys("eu_tn_four_wire")
        named["bus"]["dc_island:lv1"] = pop!(named["bus"], "lv1")
        for l in values(named["line"]), k in ("bus_from", "bus_to")
            l[k] == "lv1" && (l[k] = "dc_island:lv1")
        end
        for l in values(named["load"]); l["bus"] == "lv1" && (l["bus"] = "dc_island:lv1"); end
        plain = connectivity_analysis(_pg_sys("eu_tn_four_wire"), Finding[])
        odd = connectivity_analysis(named, Finding[])
        @test odd["longest_path_buses"] == replace(plain["longest_path_buses"], "lv1" => "dc_island:lv1")
        @test odd["longest_path_buses"] == odd["longest_path_vertices"]
        @test "dc_island:lv1" in odd["longest_path_buses"]
        # src -> DC island -> recv -> leaf: the near-source half of the bus path
        # still reaches recv, as it does over a direct AC branch.
        chain = Dict{String,Any}(
            "bus" => Dict{String,Any}(b => Dict{String,Any}("terminal_names" => ["a","n"]) for b in ("src", "recv", "leaf")),
            "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}("bus" => "src", "terminal_map" => ["a"],
                "v_magnitude" => [230.0], "v_angle" => [0.0])),
            "line" => Dict{String,Any}("l" => Dict{String,Any}("bus_from" => "recv", "bus_to" => "leaf",
                "terminal_map_from" => ["a","n"], "terminal_map_to" => ["a","n"])),
            "dc_bus" => Dict{String,Any}("link" => Dict{String,Any}("terminal_names" => ["p","n"])),
            "ibr" => Dict{String,Any}("c1" => Dict{String,Any}("bus" => "src", "dc_bus" => "link"),
                                      "c2" => Dict{String,Any}("bus" => "recv", "dc_bus" => "link")))
        conn = connectivity_analysis(chain, Finding[])
        @test conn["longest_path_buses"] == ["src", "recv", "leaf"]
        @test conn["longest_path_vertices"] == ["src", "dc_island:link", "recv", "leaf"]
        path = conn["longest_path_buses"]
        @test "recv" in path[1:max(1, cld(length(path), 2))]

        # End to end: near-source placement puts the same units behind a DC link
        # as behind a direct AC branch. src - (link) - hub - mid - leaf - tail:
        # the near-source half of the bus path is src, hub, mid, and mid is the
        # first load bus without a converter of its own.
        placed(link) = begin
            bus(grounded=true) = Dict{String,Any}("terminal_names" => ["1","2","3","n"],
                "perfectly_grounded_terminals" => ["n"])
            ln(f, t) = Dict{String,Any}("bus_from" => f, "bus_to" => t, "linecode" => "lc", "length" => 50.0,
                "terminal_map_from" => ["1","2","3","n"], "terminal_map_to" => ["1","2","3","n"])
            ld(b) = Dict{String,Any}("bus" => b, "terminal_map" => ["1","2","3","n"], "configuration" => "WYE",
                "p_nom" => fill(1000.0, 3), "q_nom" => fill(0.0, 3))
            net = Dict{String,Any}(
                "bus" => Dict{String,Any}(b => bus() for b in ("src", "hub", "mid", "leaf", "tail")),
                "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}("bus" => "src",
                    "terminal_map" => ["1","2","3"], "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2.0944, 2.0944])),
                "linecode" => Dict{String,Any}("lc" => Dict{String,Any}("R_series_1_1" => 0.000396)),
                "line" => Dict{String,Any}("l2" => ln("hub", "mid"), "l3" => ln("mid", "leaf"), "l4" => ln("leaf", "tail")),
                "load" => Dict{String,Any}("ld_mid" => ld("mid"), "ld_tail" => ld("tail")))
            if link == :dc
                net["dc_bus"] = Dict{String,Any}("link" => Dict{String,Any}("terminal_names" => ["p","n"]))
                net["ibr"] = Dict{String,Any}(k => Dict{String,Any}("bus" => b, "dc_bus" => "link",
                    "terminal_map" => ["1","2","3"], "topology" => "THREE_LEG", "prime_mover" => "CONVERTER",
                    "s_max" => [1e4]) for (k, b) in (("c1", "src"), ("c2", "hub")))
            else
                net["line"]["l1"] = ln("src", "hub")
            end
            @test connectivity_analysis(net, Finding[])["longest_path_buses"] == ["src", "hub", "mid", "leaf", "tail"]
            gens, _ = redirect_stderr(devnull) do
                add_generators(net; recipe=GeneratorRecipe(strategy=:topology_targeted,
                    topology_mode=:near_source, voltage_levels=nothing))
            end
            ibrs, _ = redirect_stderr(devnull) do
                add_ibrs(net; recipe=IBRRecipe(strategy=:topology_targeted,
                    topology_mode=:near_source, voltage_levels=nothing))
            end
            (sort!(collect(keys(get(gens, "generator", Dict())))),
             sort!([k for k in keys(get(ibrs, "ibr", Dict())) if !(k in ("c1", "c2"))]))
        end
        ac_gens, ac_ibrs = placed(:ac); dc_gens, dc_ibrs = placed(:dc)
        @test ac_gens == ["der_mid"] && dc_gens == ac_gens
        @test ac_ibrs == ["pv_mid"] && dc_ibrs == ac_ibrs
    end
end
