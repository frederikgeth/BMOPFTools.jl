using Test
using BMOPFTools
using Dates

const _HAS_PMD = !isnothing(Base.identify_package("PowerModelsDistribution"))
if _HAS_PMD
    @eval using PowerModelsDistribution
end

const _HAS_ODS = !isnothing(Base.identify_package("OpenDSSDirect"))
if _HAS_ODS
    @eval using OpenDSSDirect
end

const _HAS_JUMP_IPOPT = !isnothing(Base.identify_package("JuMP")) &&
                        !isnothing(Base.identify_package("Ipopt"))
if _HAS_JUMP_IPOPT
    @eval using JuMP, Ipopt
end

# ---------------------------------------------------------------------------
# Minimal IEEE 13-bus inspired fixture — enough to exercise all analysis paths
# ---------------------------------------------------------------------------

const IEEE13_FIXTURE = """
{
  "name": "ieee13_mini",
  "bus": {
    "sourcebus": {
      "terminal_names": ["1","2","3","n"],
      "perfectly_grounded_terminals": ["n"],
      "v_min": [2020.0, 2020.0, 2020.0],
      "v_max": [2540.0, 2540.0, 2540.0]
    },
    "650": {
      "terminal_names": ["1","2","3","n"],
      "perfectly_grounded_terminals": ["n"],
      "v_min": [2020.0, 2020.0, 2020.0],
      "v_max": [2540.0, 2540.0, 2540.0]
    },
    "632": {
      "terminal_names": ["1","2","3","n"],
      "v_min": [2020.0, 2020.0, 2020.0],
      "v_max": [2540.0, 2540.0, 2540.0]
    },
    "634": {
      "terminal_names": ["1","2","3","n"],
      "perfectly_grounded_terminals": ["n"],
      "v_min": [100.0, 100.0, 100.0],
      "v_max": [130.0, 130.0, 130.0]
    },
    "671": {
      "terminal_names": ["1","2","3","n"],
      "v_min": [2020.0, 2020.0, 2020.0],
      "v_max": [2540.0, 2540.0, 2540.0]
    },
    "611": {
      "terminal_names": ["3","n"],
      "v_min": [2020.0],
      "v_max": [2540.0]
    },
    "652": {
      "terminal_names": ["1","n"]
    }
  },
  "voltage_source": {
    "source": {
      "bus": "sourcebus",
      "terminal_map": ["1","2","3"],
      "v_magnitude": [2401.8, 2401.8, 2401.8],
      "v_angle": [0.0, -2.094, 2.094]
    }
  },
  "line": {
    "l650632": {
      "bus_from": "650",
      "bus_to": "632",
      "terminal_map_from": ["1","2","3"],
      "terminal_map_to": ["1","2","3"],
      "linecode": "lc601",
      "length": 609.6
    },
    "l632671": {
      "bus_from": "632",
      "bus_to": "671",
      "terminal_map_from": ["1","2","3"],
      "terminal_map_to": ["1","2","3"],
      "linecode": "lc601",
      "length": 609.6
    },
    "l671611": {
      "bus_from": "671",
      "bus_to": "611",
      "terminal_map_from": ["3"],
      "terminal_map_to": ["3"],
      "linecode": "lc605",
      "length": 152.4
    },
    "l671652": {
      "bus_from": "671",
      "bus_to": "652",
      "terminal_map_from": ["1"],
      "terminal_map_to": ["1"],
      "linecode": "lc607",
      "length": 152.4
    }
  },
  "linecode": {
    "lc601": {
      "R_series_1_1": 3.3717e-4,
      "R_series_1_2": 1.5283e-4,
      "R_series_1_3": 1.3425e-4,
      "R_series_2_2": 3.0282e-4,
      "R_series_2_3": 1.4699e-4,
      "R_series_3_3": 3.0282e-4,
      "X_series_1_1": 6.6791e-4,
      "X_series_1_2": 3.2539e-4,
      "X_series_1_3": 2.6028e-4,
      "X_series_2_2": 6.3254e-4,
      "X_series_2_3": 2.7967e-4,
      "X_series_3_3": 6.3254e-4,
      "i_max": [600.0, 600.0, 600.0]
    },
    "lc605": {
      "R_series_1_1": 1.0304e-3,
      "X_series_1_1": 7.1716e-4,
      "i_max": [200.0]
    },
    "lc607": {
      "R_series_1_1": 1.5208e-3,
      "X_series_1_1": 5.0065e-4,
      "i_max": [200.0]
    }
  },
  "transformer": {
    "wye_delta": {
      "xfm1": {
        "bus_from": "650",
        "bus_to": "sourcebus",
        "terminal_map_from": ["1","2","3","n"],
        "terminal_map_to": ["1","2","3"],
        "s_rating": 5000000.0,
        "v_ref_from": 4160.0,
        "v_ref_to": 4160.0
      }
    },
    "single_phase": {
      "xfm2": {
        "bus_from": "632",
        "bus_to": "634",
        "terminal_map_from": ["1","2","3"],
        "terminal_map_to": ["1","2","3"],
        "s_rating": 500000.0,
        "v_ref_from": 4160.0,
        "v_ref_to": 480.0
      }
    }
  },
  "load": {
    "load_632": {
      "bus": "632",
      "terminal_map": ["1","2","3","n"],
      "configuration": "WYE",
      "p_nom": [17000.0, 66000.0, 117000.0],
      "q_nom": [10000.0, 38000.0, 68000.0]
    },
    "load_671": {
      "bus": "671",
      "terminal_map": ["1","2","3"],
      "configuration": "DELTA",
      "p_nom": [385000.0, 385000.0, 385000.0],
      "q_nom": [220000.0, 220000.0, 220000.0]
    },
    "load_611": {
      "bus": "611",
      "terminal_map": ["3","n"],
      "configuration": "SINGLE_PHASE",
      "p_nom": [170000.0],
      "q_nom": [80000.0]
    },
    "load_652": {
      "bus": "652",
      "terminal_map": ["1","n"],
      "configuration": "SINGLE_PHASE",
      "p_nom": [128000.0],
      "q_nom": [86000.0]
    },
    "load_zero": {
      "bus": "634",
      "terminal_map": ["1","n"],
      "configuration": "SINGLE_PHASE",
      "p_nom": [0.0],
      "q_nom": [0.0]
    }
  },
  "generator": {
    "gen_634": {
      "bus": "634",
      "terminal_map": ["1","2","3"],
      "configuration": "WYE",
      "p_max": [100000.0, 100000.0, 100000.0],
      "p_min": [0.0, 0.0, 0.0],
      "q_max": [50000.0, 50000.0, 50000.0],
      "q_min": [-50000.0, -50000.0, -50000.0],
      "cost": [0.12, 0.12, 0.12]
    }
  }
}
"""

@testset "BMOPFTools" begin

    @testset "IO — parse_bmopf" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        @test net isa Dict{String,Any}
        @test net["name"] == "ieee13_mini"
        @test haskey(net, "bus")
        @test haskey(net, "line")
        @test haskey(net, "load")
        @test length(net["bus"]) == 7
        @test length(net["line"]) == 4
        @test length(net["load"]) == 5
        @test !is_timeseries(net)
    end

    @testset "IO — time-series detection" begin
        ts_net = deepcopy(parse_bmopf(IEEE13_FIXTURE; from_string=true))
        @test !is_timeseries(ts_net)

        # inject a time series reference
        ts_net["time_series"] = Dict{String,Any}(
            "ls1" => Dict{String,Any}("values" => [0.8, 1.0, 1.2])
        )
        ts_net["load"]["load_632"]["time_series"] = Dict{String,Any}("p_nom" => "ls1")
        @test is_timeseries(ts_net)

        snap = get_snapshot(ts_net, 1)
        @test !is_timeseries(snap)
        # scale factor 0.8 applied to [17000, 66000, 117000]
        @test snap["load"]["load_632"]["p_nom"] ≈ [13600.0, 52800.0, 93600.0]
        @test !haskey(snap["load"]["load_632"], "time_series")
        @test !haskey(snap, "time_series")
    end

    @testset "IO — write_bmopf round-trip" begin
        net  = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        buf  = IOBuffer()
        write_bmopf(net, buf)
        json_str = String(take!(buf))
        net2 = parse_bmopf(json_str; from_string=true)
        @test net2["name"] == net["name"]
        @test length(net2["bus"])  == length(net["bus"])
        @test length(net2["line"]) == length(net["line"])
    end

    @testset "IO — meta block" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)

        # write with no caller meta: auto-fields only
        json_auto = let buf = IOBuffer(); write_bmopf(net, buf); String(take!(buf)); end
        m = parse_bmopf(json_auto; from_string=true)["meta"]
        @test m["\$schema"] == BMOPFTools._BMOPF_SCHEMA_URI
        @test haskey(m, "created")
        @test m["generator"]["tool"] == "BMOPFTools.jl"
        @test !isempty(m["generator"]["version"])

        # _meta (tool-private) is not serialised
        @test !occursin("\"_meta\"", json_auto)

        # caller meta is merged; auto-fields fill in the rest
        json_caller = let buf = IOBuffer()
            write_bmopf(net, buf; meta=Dict(
                "title"   => "IEEE 13-bus mini",
                "license" => "https://creativecommons.org/licenses/by/4.0/",
                "authors" => [Dict("name" => "Test Author",
                                   "email" => "test@example.com",
                                   "orcid" => "0000-0001-2345-6789")],
                "sources" => [Dict("name" => "IEEE 13-bus", "format" => "OpenDSS",
                                   "doi"  => "10.1109/TPWRS.2012.2209630")],
            ))
            String(take!(buf))
        end
        m2 = parse_bmopf(json_caller; from_string=true)["meta"]
        @test m2["title"] == "IEEE 13-bus mini"
        @test m2["authors"][1]["orcid"] == "0000-0001-2345-6789"
        @test m2["sources"][1]["doi"] == "10.1109/TPWRS.2012.2209630"
        @test haskey(m2, "\$schema")      # auto-filled
        @test haskey(m2, "generator")     # auto-filled

        # existing created is preserved across write → parse → write
        net4 = parse_bmopf(json_auto; from_string=true)
        net4["meta"]["created"] = "2020-01-01T00:00:00Z"
        json4 = let buf = IOBuffer(); write_bmopf(net4, buf); String(take!(buf)); end
        @test parse_bmopf(json4; from_string=true)["meta"]["created"] ==
              "2020-01-01T00:00:00Z"

        # schema_check: clean meta → no meta-specific warnings
        net5 = let buf = IOBuffer()
            write_bmopf(net, buf; meta=Dict(
                "title"   => "t",
                "license" => "https://example.com/license",
                "authors" => [Dict("name" => "A", "orcid" => "0000-0001-2345-6789")],
                "sources" => [Dict("name" => "S", "url" => "https://example.com/data")],
            ))
            parse_bmopf(String(take!(buf)); from_string=true)
        end
        f5 = Finding[]
        schema_check(net5, f5)
        @test !any(f -> f.code in ("W.SCHEMA.META_ORCID_FORMAT",
                                   "W.SCHEMA.META_SCHEMA_URI",
                                   "W.SCHEMA.META_DATE_FORMAT"), f5)

        # bad ORCID → warning
        net6 = deepcopy(net5)
        net6["meta"]["authors"][1]["orcid"] = "bad"
        f6 = Finding[]
        schema_check(net6, f6)
        @test any(f -> f.code == "W.SCHEMA.META_ORCID_FORMAT", f6)

        # bad $schema → warning
        net7 = deepcopy(net5)
        net7["meta"]["\$schema"] = "not-a-uri"
        f7 = Finding[]
        schema_check(net7, f7)
        @test any(f -> f.code == "W.SCHEMA.META_SCHEMA_URI", f7)
    end

    @testset "Analysis — inventory" begin
        net      = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        result   = inventory_analysis(net, findings)

        @test result["bus"]["total"]            == 7
        @test result["line"]["total"]           == 4
        @test result["load"]["total"]           == 5
        @test result["generator"]["total"]      == 1
        @test result["transformer"]["total"]    == 2
        @test result["load"]["total_p_w"]       > 0
        # No errors on valid fixture
        @test isempty(errors(findings))
    end

    @testset "Analysis — connectivity" begin
        net      = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        result   = connectivity_analysis(net, findings)

        @test result["n_components"] == 1
        @test result["is_connected"] == true
        @test result["is_radial"]    == true
        @test result["degree_max"]   >= 2
        @test isempty(errors(findings))
    end

    @testset "Analysis — voltage levels" begin
        net      = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        result   = voltage_level_analysis(net, findings)

        @test result["n_levels"] >= 2   # MV and LV present
        @test haskey(result, "levels")
        # bus 634 is LV (480 V)
        vmap = result["bus_voltage_map"]
        @test haskey(vmap, "634")
        @test vmap["634"] < 1000.0   # LV
    end

    @testset "Analysis — diversity" begin
        net      = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        result   = diversity_analysis(net, findings)

        @test haskey(result, "load")
        @test haskey(result, "symmetry_score")
        @test result["symmetry_score"] in ("LOW", "MODERATE", "HIGH")
        # The zero-load should not crash anything
        ld = result["load"]
        @test ld["analysed"] == true
    end

    @testset "Analysis — zone topology (split-phase & SWER)" begin
        codes(fs) = Set(f.code for f in fs)

        # (A) center_tap → split-phase secondary zone
        net_ct = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "mv" => Dict{String,Any}("terminal_names" => ["1","n"]),
                "lv" => Dict{String,Any}("terminal_names" => ["1","2","n"])),
            "voltage_source" => Dict{String,Any}("src" => Dict{String,Any}(
                "bus" => "mv", "terminal_map" => ["1"],
                "v_magnitude" => [2400.0], "v_angle" => [0.0])),
            "transformer" => Dict{String,Any}("center_tap" => Dict{String,Any}(
                "ct" => Dict{String,Any}("bus_from" => "mv", "bus_to" => "lv",
                    "terminal_map_from" => ["1","n"], "terminal_map_to" => ["1","n","2"],
                    "v_ref_from" => 2400.0, "v_ref_to" => 120.0))),
            "load" => Dict{String,Any}("l1" => Dict{String,Any}("bus" => "lv",
                "terminal_map" => ["1","n"], "configuration" => "SINGLE_PHASE",
                "p_nom" => [1000.0], "q_nom" => [0.0])))
        f = Finding[]
        r = connectivity_analysis(net_ct, f)
        @test r["n_split_phase_zones"] == 1
        @test r["n_swer_zones"] == 0
        @test "I.PROV.SPLIT_PHASE_ZONE" in codes(f)

        # (B) single-wire transformer-isolated zone → SWER
        net_swer = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "mv" => Dict{String,Any}("terminal_names" => ["1","2","3","n"]),
                "sw" => Dict{String,Any}("terminal_names" => ["1","n"])),
            "voltage_source" => Dict{String,Any}("src" => Dict{String,Any}(
                "bus" => "mv", "terminal_map" => ["1","2","3"],
                "v_magnitude" => [6350.0,6350.0,6350.0], "v_angle" => [0.0,-2.094,2.094])),
            "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
                "iso" => Dict{String,Any}("bus_from" => "mv", "bus_to" => "sw",
                    "terminal_map_from" => ["1","n"], "terminal_map_to" => ["1","n"],
                    "v_ref_from" => 6350.0, "v_ref_to" => 6350.0))),
            "load" => Dict{String,Any}("l1" => Dict{String,Any}("bus" => "sw",
                "terminal_map" => ["1","n"], "configuration" => "SINGLE_PHASE",
                "p_nom" => [1000.0], "q_nom" => [0.0])))
        f = Finding[]
        r = connectivity_analysis(net_swer, f)
        @test r["n_swer_zones"] == 1
        @test r["n_split_phase_zones"] == 0
        @test "I.PROV.SWER_ZONE" in codes(f)

        # (C) AU pattern: SWER MV section feeding a center_tap split-phase LV section
        net_au = deepcopy(net_swer)
        net_au["bus"]["lv"] = Dict{String,Any}("terminal_names" => ["1","2","n"])
        net_au["transformer"]["center_tap"] = Dict{String,Any}("ct" => Dict{String,Any}(
            "bus_from" => "sw", "bus_to" => "lv",
            "terminal_map_from" => ["1","n"], "terminal_map_to" => ["1","n","2"],
            "v_ref_from" => 6350.0, "v_ref_to" => 230.0))
        f = Finding[]
        r = connectivity_analysis(net_au, f)
        @test r["n_swer_zones"] == 1          # the single-wire MV section
        @test r["n_split_phase_zones"] == 1   # the center-tap LV section
        @test "I.PROV.SWER_ZONE" in codes(f)
        @test "I.PROV.SPLIT_PHASE_ZONE" in codes(f)

        # (D) plain 3-phase → neither tag
        f = Finding[]
        r = connectivity_analysis(parse_bmopf(IEEE13_FIXTURE; from_string=true), f)
        @test r["n_split_phase_zones"] == 0
        @test r["n_swer_zones"] == 0
        @test !("I.PROV.SWER_ZONE" in codes(f))

        # (E) single-phase lateral off a 3-phase feeder is NOT SWER (same zone)
        net_lat = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "src" => Dict{String,Any}("terminal_names" => ["1","2","3","n"]),
                "b3"  => Dict{String,Any}("terminal_names" => ["1","2","3","n"]),
                "b1"  => Dict{String,Any}("terminal_names" => ["1","n"])),
            "voltage_source" => Dict{String,Any}("src" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["1","2","3"],
                "v_magnitude" => [240.0,240.0,240.0], "v_angle" => [0.0,-2.094,2.094])),
            "line" => Dict{String,Any}(
                "l1" => Dict{String,Any}("bus_from" => "src", "bus_to" => "b3",
                    "terminal_map_from" => ["1","2","3","n"], "terminal_map_to" => ["1","2","3","n"]),
                "l2" => Dict{String,Any}("bus_from" => "b3", "bus_to" => "b1",
                    "terminal_map_from" => ["1","n"], "terminal_map_to" => ["1","n"])))
        f = Finding[]
        r = connectivity_analysis(net_lat, f)
        @test r["n_swer_zones"] == 0          # b1 shares the 3-phase feeder's zone
    end

    @testset "Diversity — split-phase zone not flagged phase-balanced" begin
        # Balanced legs in a center-tap (split-phase) zone must NOT trigger the
        # "balanced ⇒ single-phase equivalent" finding (it's false for split-phase).
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "mv" => Dict{String,Any}("terminal_names" => ["1","n"]),
                "lv" => Dict{String,Any}("terminal_names" => ["1","2","n"])),
            "voltage_source" => Dict{String,Any}("src" => Dict{String,Any}(
                "bus" => "mv", "terminal_map" => ["1"],
                "v_magnitude" => [2400.0], "v_angle" => [0.0])),
            "transformer" => Dict{String,Any}("center_tap" => Dict{String,Any}(
                "ct" => Dict{String,Any}("bus_from" => "mv", "bus_to" => "lv",
                    "terminal_map_from" => ["1","n"], "terminal_map_to" => ["1","n","2"],
                    "v_ref_from" => 2400.0, "v_ref_to" => 120.0))),
            "load" => Dict{String,Any}(
                "l1" => Dict{String,Any}("bus" => "lv", "terminal_map" => ["1","n"],
                    "configuration" => "SINGLE_PHASE", "p_nom" => [2000.0], "q_nom" => [0.0]),
                "l2" => Dict{String,Any}("bus" => "lv", "terminal_map" => ["2","n"],
                    "configuration" => "SINGLE_PHASE", "p_nom" => [2000.0], "q_nom" => [0.0])))
        f = Finding[]
        diversity_analysis(net, f)
        @test !any(x -> x.code == "I.DIV.LOAD_PHASE_BALANCED", f)
    end

    @testset "Validation — redundancy" begin
        net      = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        result   = redundancy_check(net, findings)

        # zero load fixture has load_zero with p=q=0
        @test result["zero_loads"]["n"] >= 1
        @test "load_zero" in result["zero_loads"]["ids"]

        # unused linecodes: lc601, lc605, lc607 are all used, none unused
        @test result["unused_linecodes"]["n"] == 0

        # no parallel lines in the fixture
        @test result["parallel_lines"]["n_groups"] == 0
    end

    @testset "Redundancy — parallel lines" begin
        make_net(lines) = Dict{String,Any}("line" => lines)

        # Two lines between the same bus pair → flagged
        net = make_net(Dict(
            "l1" => Dict("bus_from"=>"a","bus_to"=>"b","linecode"=>"lc","length"=>100.0),
            "l2" => Dict("bus_from"=>"a","bus_to"=>"b","linecode"=>"lc","length"=>100.0)))
        r = redundancy_check(net, Finding[])
        @test r["parallel_lines"]["n_groups"] == 1
        @test sort(r["parallel_lines"]["groups"][1]["line_ids"]) == ["l1","l2"]
        findings = Finding[]
        redundancy_check(net, findings)
        @test any(f -> f.code == "I.RED.PARALLEL_LINES", findings)

        # Direction-agnostic: (A,B) and (B,A) are the same pair
        net2 = make_net(Dict(
            "l1" => Dict("bus_from"=>"a","bus_to"=>"b","linecode"=>"lc","length"=>100.0),
            "l2" => Dict("bus_from"=>"b","bus_to"=>"a","linecode"=>"lc","length"=>100.0)))
        r2 = redundancy_check(net2, Finding[])
        @test r2["parallel_lines"]["n_groups"] == 1

        # Different bus pairs → no flag
        net3 = make_net(Dict(
            "l1" => Dict("bus_from"=>"a","bus_to"=>"b","linecode"=>"lc","length"=>100.0),
            "l2" => Dict("bus_from"=>"b","bus_to"=>"c","linecode"=>"lc","length"=>100.0)))
        r3 = redundancy_check(net3, Finding[])
        @test r3["parallel_lines"]["n_groups"] == 0
    end

    @testset "Redundancy — sparse phase loads" begin
        make_net(loads) = Dict{String,Any}("load" => loads)

        # 3-phase WYE: phase 2 and 3 dead → flag phases [2,3]
        net = make_net(Dict("l1" => Dict(
            "bus" => "b1", "configuration" => "WYE",
            "terminal_map" => ["1","2","3","n"],
            "p_nom" => [1000.0, 0.0, 0.0], "q_nom" => [0.0, 0.0, 0.0])))
        r = redundancy_check(net, Finding[])
        @test r["sparse_phase_loads"]["n"] == 1
        @test haskey(r["sparse_phase_loads"]["loads"], "l1")
        @test sort(r["sparse_phase_loads"]["loads"]["l1"]) == [2, 3]

        # Finding code fires
        findings = Finding[]
        redundancy_check(net, findings)
        @test any(f -> f.code == "I.RED.LOAD_SPARSE_PHASES", findings)

        # All phases active → no flag
        net2 = make_net(Dict("l1" => Dict(
            "bus" => "b1", "configuration" => "WYE",
            "terminal_map" => ["1","2","3","n"],
            "p_nom" => [100.0, 200.0, 300.0], "q_nom" => [0.0, 0.0, 0.0])))
        r2 = redundancy_check(net2, Finding[])
        @test r2["sparse_phase_loads"]["n"] == 0

        # All phases dead → covered by ZERO_LOADS, not SPARSE_PHASES
        net3 = make_net(Dict("l1" => Dict(
            "bus" => "b1", "configuration" => "WYE",
            "terminal_map" => ["1","2","3","n"],
            "p_nom" => [0.0, 0.0, 0.0], "q_nom" => [0.0, 0.0, 0.0])))
        r3 = redundancy_check(net3, Finding[])
        @test r3["sparse_phase_loads"]["n"] == 0

        # SINGLE_PHASE and DELTA are excluded
        net4 = make_net(Dict(
            "l1" => Dict("bus" => "b1", "configuration" => "SINGLE_PHASE",
                         "terminal_map" => ["1","n"],
                         "p_nom" => [0.0], "q_nom" => [0.0]),
            "l2" => Dict("bus" => "b1", "configuration" => "DELTA",
                         "terminal_map" => ["1","2","3"],
                         "p_nom" => [100.0, 0.0, 0.0], "q_nom" => [0.0, 0.0, 0.0])))
        r4 = redundancy_check(net4, Finding[])
        @test r4["sparse_phase_loads"]["n"] == 0
    end

    @testset "Redundancy — mergeable loads" begin
        make_net(loads) = Dict{String,Any}("load" => loads)

        # Two WYE loads on the same bus with same terminal_map → mergeable
        net = make_net(Dict(
            "l1" => Dict("bus" => "b1", "configuration" => "WYE",
                         "terminal_map" => ["1","2","3","n"],
                         "p_nom" => [100.0, 200.0, 300.0]),
            "l2" => Dict("bus" => "b1", "configuration" => "WYE",
                         "terminal_map" => ["1","2","3","n"],
                         "p_nom" => [50.0, 60.0, 70.0])))
        r = redundancy_check(net, Finding[])
        @test r["mergeable_loads"]["n_groups"] == 1
        @test sort(r["mergeable_loads"]["groups"][1]["load_ids"]) == ["l1","l2"]
        findings = Finding[]
        redundancy_check(net, findings)
        @test any(f -> f.code == "I.RED.LOAD_MERGEABLE", findings)

        # Different terminal_map → not mergeable
        net2 = make_net(Dict(
            "l1" => Dict("bus" => "b1", "configuration" => "SINGLE_PHASE",
                         "terminal_map" => ["1","n"], "p_nom" => [100.0]),
            "l2" => Dict("bus" => "b1", "configuration" => "SINGLE_PHASE",
                         "terminal_map" => ["2","n"], "p_nom" => [200.0])))
        r2 = redundancy_check(net2, Finding[])
        @test r2["mergeable_loads"]["n_groups"] == 0

        # Different buses → not mergeable
        net3 = make_net(Dict(
            "l1" => Dict("bus" => "b1", "configuration" => "WYE",
                         "terminal_map" => ["1","2","3","n"], "p_nom" => [100.0,0.0,0.0]),
            "l2" => Dict("bus" => "b2", "configuration" => "WYE",
                         "terminal_map" => ["1","2","3","n"], "p_nom" => [100.0,0.0,0.0])))
        r3 = redundancy_check(net3, Finding[])
        @test r3["mergeable_loads"]["n_groups"] == 0

        # WYE terminal_map order-insensitive: ["2","1","n"] same key as ["1","2","n"]
        net4 = make_net(Dict(
            "l1" => Dict("bus" => "b1", "configuration" => "WYE",
                         "terminal_map" => ["1","2","n"], "p_nom" => [100.0, 200.0]),
            "l2" => Dict("bus" => "b1", "configuration" => "WYE",
                         "terminal_map" => ["2","1","n"], "p_nom" => [50.0, 60.0])))
        r4 = redundancy_check(net4, Finding[])
        @test r4["mergeable_loads"]["n_groups"] == 1

        # DELTA: same cyclic rotation → mergeable; reverse → not mergeable
        net5 = make_net(Dict(
            "l1" => Dict("bus" => "b1", "configuration" => "DELTA",
                         "terminal_map" => ["1","2","3"], "p_nom" => [100.0,100.0,100.0]),
            "l2" => Dict("bus" => "b1", "configuration" => "DELTA",
                         "terminal_map" => ["2","3","1"], "p_nom" => [50.0,50.0,50.0]),
            "l3" => Dict("bus" => "b1", "configuration" => "DELTA",
                         "terminal_map" => ["1","3","2"], "p_nom" => [10.0,10.0,10.0])))
        r5 = redundancy_check(net5, Finding[])
        # l1 and l2 are cyclic rotations (same group); l3 is reversed (different)
        @test r5["mergeable_loads"]["n_groups"] == 1
        grp = r5["mergeable_loads"]["groups"][1]
        @test sort(grp["load_ids"]) == ["l1","l2"]

        # Loads with time_series excluded
        net6 = make_net(Dict(
            "l1" => Dict("bus" => "b1", "configuration" => "WYE",
                         "terminal_map" => ["1","2","3","n"], "p_nom" => [100.0,0.0,0.0],
                         "time_series" => Dict("p_nom" => "ts1")),
            "l2" => Dict("bus" => "b1", "configuration" => "WYE",
                         "terminal_map" => ["1","2","3","n"], "p_nom" => [50.0,0.0,0.0])))
        r6 = redundancy_check(net6, Finding[])
        @test r6["mergeable_loads"]["n_groups"] == 0
    end

    @testset "Validation — completeness" begin
        net      = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        result   = completeness_check(net, findings)
        # The fixture is well-formed; no missing required fields
        errs = errors(findings)
        @test isempty(errs)
    end

    @testset "Full analyze pipeline" begin
        net    = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        report = analyze(net)

        @test report isa SummaryReport
        @test report.network_name == "ieee13_mini"
        @test report.generated_at isa DateTime
        @test haskey(report.results, :inventory)
        @test haskey(report.results, :connectivity)
        @test haskey(report.results, :voltage_levels)
        @test haskey(report.results, :diversity)
        @test haskey(report.results, :operational)
        @test haskey(report.results, :preflight)
        @test haskey(report.results, :spec)
        @test haskey(report.results, :benchmark)
        @test haskey(report.results, :integrity)

        # render to terminal — should not error
        buf = IOBuffer()
        render(report, buf; color=false)
        output = String(take!(buf))
        @test !isempty(output)
        @test occursin("ieee13_mini", output)
        @test occursin("INVENTORY", output)

        # render to markdown — should not error
        buf = IOBuffer()
        render_markdown(report, buf)
        md = String(take!(buf))
        @test occursin("# BMOPF", md)
        @test occursin("##", md)
    end

    @testset "Finding accessors" begin
        net    = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        report = analyze(net)

        all_f = report.findings
        @test errors(report)   == filter(f -> f.severity == ERROR,   all_f)
        @test warnings(report) == filter(f -> f.severity == WARNING, all_f)
        @test infos(report)    == filter(f -> f.severity == INFO,    all_f)
    end

    @testset "Negative fixtures — error paths" begin
        # v_min > v_max must produce E.PRE.VBOUND_CONFLICT, including when
        # only one bound is present elsewhere (regression for precedence bug)
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        net["bus"]["632"]["v_min"] = [2600.0, 2600.0, 2600.0]   # > v_max of 2540
        delete!(net["bus"]["671"], "v_max")    # one-bound bus must not crash
        report = analyze(net)
        @test any(f -> f.code == "E.PRE.VBOUND_CONFLICT", report.findings)

        # Missing required field must produce E.COMP.MISSING_REQUIRED
        net2 = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        delete!(net2["line"]["l650632"], "linecode")
        report2 = analyze(net2)
        @test any(f -> f.code == "E.COMP.MISSING_REQUIRED" &&
                       f.component_id == "l650632", report2.findings)

        # Unknown field must be catalogued by schema_check as INFO
        net3 = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        net3["load"]["load_632"]["my_custom_field"] = 42
        report3 = analyze(net3)
        @test any(f -> f.code == "I.SCHEMA.UNKNOWN_FIELDS", report3.findings)
        @test haskey(report3.results[:schema]["unknown_fields_by_type"], "load")

        # Scalar v_min/v_max is rejected at ingest (must be a per-phase array).
        scalar_vbound = """
        {"bus":{"b":{"terminal_names":["1","2","3","n"],"v_min":900.0,"v_max":1100.0}}}
        """
        @test_throws ArgumentError parse_bmopf(scalar_vbound; from_string=true)

        # Line crossing voltage levels must produce E.VOLT.LINE_CROSSING
        net4 = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        net4["line"]["bad_line"] = Dict{String,Any}(
            "bus_from" => "632", "bus_to" => "634",   # MV bus to LV bus
            "terminal_map_from" => ["1"], "terminal_map_to" => ["1"],
            "linecode" => "lc605", "length" => 10.0)
        report4 = analyze(net4)
        @test any(f -> f.code == "E.VOLT.LINE_CROSSING", report4.findings)
    end

    @testset "Time-series — missing static value errors" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        net["time_series"] = Dict{String,Any}(
            "ls1" => Dict{String,Any}("values" => [1.0]))
        # reference a parameter that has no static value on the component
        net["load"]["load_632"]["time_series"] =
            Dict{String,Any}("nonexistent_param" => "ls1")
        @test_throws ArgumentError get_snapshot(net, 1)
    end

    @testset "Terminal name validation" begin
        # Genuinely unknown terminal names must fail loudly in to_pmd,
        # not silently mis-map ("a"/"b"/"c", "L1".., "1".."4" are supported)
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        net["bus"]["650"]["terminal_names"] = ["x", "y", "z"]
        @test_throws ArgumentError to_pmd(net)
    end

    @testset "to_pmd — per-phase v bound reduction" begin
        # Uniform per-phase v_min/v_max reduce to scalar PMD vm_lb/vm_ub.
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        eng = to_pmd(net)
        @test eng["bus"]["sourcebus"]["vm_lb"] ≈ 2020.0 / get(eng, "settings", Dict())["voltage_scale_factor"] rtol=1e-6
        @test eng["bus"]["sourcebus"]["vm_ub"] ≈ 2540.0 / get(eng, "settings", Dict())["voltage_scale_factor"] rtol=1e-6
        # A genuinely per-phase (unequal) bound cannot be represented and errors.
        net["bus"]["632"]["v_max"] = [2500.0, 2540.0, 2540.0]
        @test_throws ErrorException to_pmd(net)
    end

    @testset "from_pmd — slack cost priced on the voltage source" begin
        eng = Dict{String,Any}(
            "settings" => Dict{String,Any}("voltage_scale_factor" => 1000.0),
            "bus" => Dict{String,Any}(
                "src" => Dict{String,Any}("terminals" => [1,2,3,4])),
            "voltage_source" => Dict{String,Any}(
                "source" => Dict{String,Any}(
                    "bus" => "src", "connections" => [1,2,3,4],
                    "vm" => [0.23, 0.23, 0.23, 0.0],
                    "va" => [0.0, -120.0, 120.0, 0.0])))

        net = from_pmd(eng; slack_cost=0.25)
        @test !haskey(net, "generator")
        vs = net["voltage_source"]["source"]
        @test vs["bus"] == "src"
        @test vs["cost"] ≈ [0.25, 0.25, 0.25]   # one per phase (neutral excluded)
        @test !haskey(vs, "p_min") && !haskey(vs, "p_max")

        # opt-out
        net2 = from_pmd(eng; add_slack_generator=false)
        @test !haskey(net2["voltage_source"]["source"], "cost")
    end

    @testset "Spec conformance checks" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        res = spec_conformance_check(net, findings)
        @test res["n_voltage_sources"] == 1
        # fixture loads are arity-consistent after the SINGLE_PHASE update
        @test !any(f -> f.code == "W.SPEC.CONFIG_ARITY" &&
                        f.component_type == :load, findings)
        # known gap: PMD WYE-WYE transformers land in single_phase with
        # 3-phase maps; the spec has no wye-wye type
        @test any(f -> f.code == "W.SPEC.XFMR_TMAP_ARITY" &&
                       f.component_id == "xfm2", findings)
        # fixture linecodes are stored upper-triangular — spec wants full
        @test any(f -> f.code == "I.SPEC.MATRIX_TRIANGULAR", findings)

        # arity violation must be flagged
        net2 = deepcopy(net)
        net2["load"]["bad"] = Dict{String,Any}(
            "bus" => "632", "terminal_map" => ["1","n"],
            "configuration" => "WYE",          # WYE needs 4 terminals
            "p_nom" => [1.0], "q_nom" => [0.0])
        findings2 = Finding[]
        spec_conformance_check(net2, findings2)
        @test any(f -> f.code == "W.SPEC.CONFIG_ARITY" &&
                       f.component_id == "bad", findings2)

        # multiple sources violate Eq. (17)
        net3 = deepcopy(net)
        net3["voltage_source"]["second"] = deepcopy(net3["voltage_source"]["source"])
        findings3 = Finding[]
        spec_conformance_check(net3, findings3)
        @test any(f -> f.code == "W.SPEC.N_SOURCES", findings3)
    end

    @testset "Inverter element" begin
        # Self-contained network with a clean FOUR_LEG PV inverter that
        # references a Volt-VAr control profile.
        INV_FIXTURE = """
        {
          "name": "inv_mini",
          "bus": {
            "src": {"terminal_names":["1","2","3","n"],
                    "perfectly_grounded_terminals":["n"],
                    "v_min":[220.0, 220.0, 220.0],"v_max":[260.0, 260.0, 260.0]},
            "b1":  {"terminal_names":["1","2","3","n"],
                    "v_min":[220.0, 220.0, 220.0],"v_max":[260.0, 260.0, 260.0]}
          },
          "voltage_source": {
            "vs": {"bus":"src","terminal_map":["1","2","3"],
                   "v_magnitude":[230.0,230.0,230.0],
                   "v_angle":[0.0,-2.094,2.094]}
          },
          "linecode": {"lc":{"R_series_1_1":0.1,"X_series_1_1":0.1}},
          "line": {
            "l1": {"bus_from":"src","bus_to":"b1",
                   "terminal_map_from":["1","2","3"],
                   "terminal_map_to":["1","2","3"],
                   "linecode":"lc","length":100.0}
          },
          "inverter": {
            "pv1": {"bus":"b1","terminal_map":["1","2","3","n"],
                    "topology":"FOUR_LEG","prime_mover":"PV",
                    "s_max":[5000.0,5000.0,5000.0],"p_avail":4000.0,
                    "q_min":-3000.0,"q_max":3000.0,
                    "control_profile":"vv1"}
          },
          "control_profile": {
            "vv1": {"volt_var": {"voltage_reference":"PN_PER_PHASE",
                                 "breakpoints":[218.0,225.0,235.0,242.0],
                                 "q_limits":[-3000.0,3000.0],
                                 "q_unit":"VAR","q_ref":"VAR_MAX"}}
          }
        }
        """

        @testset "parse + schema" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            @test haskey(net, "inverter")
            @test haskey(net, "control_profile")
            @test net["inverter"]["pv1"]["topology"] == "FOUR_LEG"

            f = Finding[]
            schema_check(net, f)
            @test !any(startswith(fi.code, "E.SCHEMA") for fi in f)
        end

        @testset "inventory" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            f = Finding[]
            res = inventory_analysis(net, f)
            @test res["inverter"]["total"] == 1
            @test res["inverter"]["by_topology"]["FOUR_LEG"] == 1
            @test res["inverter"]["total_s_max_va"] == 15000.0
            @test res["control_profile"]["total"] == 1
        end

        @testset "clean network: no inverter findings" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            f = Finding[]
            spec_conformance_check(net, f)
            integrity_check(net, f)
            domain_rules_check(net, f)
            completeness_check(net, f)
            @test !any(occursin("INV", fi.code) ||
                       fi.code == "E.INT.UNKNOWN_CONTROL_PROFILE"
                       for fi in f if fi.component_type == :inverter)
        end

        @testset "missing required field" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            delete!(net["inverter"]["pv1"], "s_max")
            f = Finding[]
            completeness_check(net, f)
            @test any(f_ -> f_.code == "E.COMP.MISSING_REQUIRED" &&
                            f_.component_id == "pv1", f)
        end

        @testset "bad topology + arity" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            net["inverter"]["bad"] = Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["1","2","3","n"],
                "topology" => "FIVE_LEG", "prime_mover" => "PV", "s_max" => [1.0, 1.0, 1.0])
            net["inverter"]["pv1"]["topology"] = "THREE_LEG"  # needs 3, has 4
            f = Finding[]
            spec_conformance_check(net, f)
            @test any(f_ -> f_.code == "W.SPEC.INV_TOPOLOGY" &&
                            f_.component_id == "bad", f)
            @test any(f_ -> f_.code == "W.SPEC.INV_TMAP_ARITY" &&
                            f_.component_id == "pv1", f)
        end

        @testset "unknown control_profile reference" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            net["inverter"]["pv1"]["control_profile"] = "nope"
            f = Finding[]
            integrity_check(net, f)
            @test any(f_ -> f_.code == "E.INT.UNKNOWN_CONTROL_PROFILE" &&
                            f_.component_id == "pv1", f)
        end

        @testset "filter dimension mismatch" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            net["inverter"]["pv1"]["r_filter"] = [0.01, 0.01]  # needs 3
            f = Finding[]
            integrity_check(net, f)
            @test any(f_ -> f_.code == "W.INT.DIM_MISMATCH" &&
                            f_.component_id == "pv1", f)
        end

        @testset "capability checks" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            net["inverter"]["pv1"]["p_min"] = 100.0
            net["inverter"]["pv1"]["p_max"] = -100.0   # empty range
            net["inverter"]["pv1"]["q_max"] = 20000.0   # exceeds sum(s_max) = 15000
            f = Finding[]
            domain_rules_check(net, f)
            @test any(f_ -> f_.code == "E.DOM.INV_P_BOUNDS", f)
            @test any(f_ -> f_.code == "W.DOM.INV_BOUND_EXCEEDS_SMAX", f)

            # PV that absorbs active power
            net2 = parse_bmopf(INV_FIXTURE; from_string=true)
            net2["inverter"]["pv1"]["p_min"] = -1000.0
            f2 = Finding[]
            domain_rules_check(net2, f2)
            @test any(f_ -> f_.code == "W.DOM.INV_PV_ABSORBS", f2)
        end

        @testset "full analyze pipeline" begin
            net = parse_bmopf(INV_FIXTURE; from_string=true)
            report = analyze(net)
            @test report isa SummaryReport
            buf = IOBuffer(); render(report, buf; color=false)
            @test occursin("inverter", String(take!(buf)))
        end
    end

    @testset "Terminal map convention checks" begin
        # Minimal 3-phase bus used across sub-tests
        _tmap_net(extra_components="") = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["a","b","c","n"],
                   "perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["a","b","c","n"],
                   "perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["a","b","c"],
             "v_magnitude":[11000.0,11000.0,11000.0],
             "v_angle":[0.0,-2.094,-4.189]}},
         "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["a","b","c"],
             "terminal_map_to":["a","b","c"],
             "linecode":"lc","length":100.0}},
         "load":{"ld1":{"bus":"b1","terminal_map":["a","b","c","n"],
             "configuration":"WYE","p_nom":[1e4,1e4,1e4],"q_nom":[0.0,0.0,0.0]}}
         $extra_components}
        """; from_string=true)

        # ── clean network: no terminal map findings ───────────────────────────
        @testset "clean network has no terminal map findings" begin
            net = _tmap_net()
            findings = Finding[]
            res = spec_conformance_check(net, findings)
            @test res["n_phase_to_neutral"]       == 0
            @test res["n_cross_phase_lines"]      == 0
            @test res["n_permuted_terminal_maps"] == 0
            @test !any(f -> f.code in ("E.TMAP.PHASE_TO_NEUTRAL",
                                       "I.TMAP.CROSS_PHASE_LINE",
                                       "I.TMAP.PERMUTED_ORDER"), findings)
        end

        # ── E.TMAP.PHASE_TO_NEUTRAL: generator wired only to neutral ─────────
        @testset "E.TMAP.PHASE_TO_NEUTRAL — generator terminal_map=[n]" begin
            net = _tmap_net(""","generator":{"g1":{"bus":"b1",
                "terminal_map":["n"],
                "configuration":"WYE","cost":[0.05],
                "p_min":[0.0],"p_max":[1e4],
                "q_min":[0.0],"q_max":[0.0]}}""")
            findings = Finding[]
            res = spec_conformance_check(net, findings)
            @test res["n_phase_to_neutral"] >= 1
            @test any(f -> f.code == "E.TMAP.PHASE_TO_NEUTRAL" &&
                           f.component_id == "g1", findings)
        end

        # ── E.TMAP.PHASE_TO_NEUTRAL: WYE load with neutral in phase slot ─────
        @testset "E.TMAP.PHASE_TO_NEUTRAL — neutral in phase slot of WYE load" begin
            net = _tmap_net(""","load":{"bad":{"bus":"b1",
                "terminal_map":["a","n","c","n"],
                "configuration":"WYE",
                "p_nom":[1e4,1e4,1e4],"q_nom":[0.0,0.0,0.0]}}""")
            findings = Finding[]
            res = spec_conformance_check(net, findings)
            @test res["n_phase_to_neutral"] >= 1
            @test any(f -> f.code == "E.TMAP.PHASE_TO_NEUTRAL" &&
                           f.component_id == "bad", findings)
        end

        # ── WYE load with neutral in trailing slot: no error ──────────────────
        @testset "WYE load neutral in last slot is not an error" begin
            net = _tmap_net()   # ld1 already has ["a","b","c","n"] — correct
            findings = Finding[]
            spec_conformance_check(net, findings)
            @test !any(f -> f.code == "E.TMAP.PHASE_TO_NEUTRAL" &&
                            f.component_id == "ld1", findings)
        end

        # ── I.TMAP.CROSS_PHASE_LINE: from/to maps differ ─────────────────────
        @testset "I.TMAP.CROSS_PHASE_LINE — mismatched from/to" begin
            net = _tmap_net()
            net["line"]["l1"]["terminal_map_to"] = ["b","a","c"]   # permuted
            findings = Finding[]
            res = spec_conformance_check(net, findings)
            @test res["n_cross_phase_lines"] >= 1
            @test any(f -> f.code == "I.TMAP.CROSS_PHASE_LINE" &&
                           f.component_id == "l1", findings)
        end

        # ── identical from/to: no cross-phase finding ─────────────────────────
        @testset "matching from/to terminal maps not flagged as cross-phase" begin
            net = _tmap_net()
            findings = Finding[]
            res = spec_conformance_check(net, findings)
            @test res["n_cross_phase_lines"] == 0
        end

        # ── I.TMAP.PERMUTED_ORDER: load terminal map out of bus order ─────────
        @testset "I.TMAP.PERMUTED_ORDER — permuted nodal terminal map" begin
            net = _tmap_net()
            net["load"]["ld1"]["terminal_map"] = ["b","a","c","n"]   # b before a
            findings = Finding[]
            res = spec_conformance_check(net, findings)
            @test res["n_permuted_terminal_maps"] >= 1
            @test any(f -> f.code == "I.TMAP.PERMUTED_ORDER" &&
                           f.component_id == "ld1", findings)
        end

        # ── phase subset in bus order: no permutation finding ─────────────────
        @testset "phase subset in bus order not flagged as permuted" begin
            net = _tmap_net(""","load":{"sub":{"bus":"b1",
                "terminal_map":["a","n"],
                "configuration":"SINGLE_PHASE",
                "p_nom":[5e3],"q_nom":[0.0]}}""")
            findings = Finding[]
            spec_conformance_check(net, findings)
            @test !any(f -> f.code == "I.TMAP.PERMUTED_ORDER" &&
                            f.component_id == "sub", findings)
        end
    end

    @testset "Benchmark readiness" begin
        # fixture has a non-slack generator with cost and voltage bounds
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        res = benchmark_readiness_check(net, findings)
        @test res["objective_wellposed"] == true
        @test res["only_slack_generation"] == false
        @test res["pct_v_bounds"] > 0

        # no generators → degenerate objective, augmentation suggested
        net2 = deepcopy(net)
        delete!(net2, "generator")
        findings2 = Finding[]
        res2 = benchmark_readiness_check(net2, findings2)
        @test res2["objective_wellposed"] == false
        @test !isempty(res2["suggestions"])
        @test any(f -> f.code == "I.BENCH.AUGMENTATION", findings2)

        # slack-only generation → "add DERs" suggestion
        net3 = deepcopy(net2)
        net3["generator"] = Dict{String,Any}(
            "slack_s" => Dict{String,Any}(
                "bus" => "sourcebus", "terminal_map" => ["1","2","3","n"],
                "configuration" => "WYE", "cost" => [1.0,1.0,1.0],
                "_slack" => true))
        findings3 = Finding[]
        res3 = benchmark_readiness_check(net3, findings3)
        @test res3["objective_wellposed"] == true
        @test res3["only_slack_generation"] == true
        @test any(occursin("slack", s) for s in res3["suggestions"])
    end

    @testset "Sign & definiteness checks" begin
        base = parse_bmopf(IEEE13_FIXTURE; from_string=true)

        # X diagonal non-positive → warning
        net = deepcopy(base)
        net["linecode"]["lc_xneg"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3, "R_series_3_3" => 0.3,
            "X_series_1_1" => 0.9, "X_series_2_2" => -0.9, "X_series_3_3" => 0.9)
        f = Finding[]
        provenance_analysis(net, f)
        @test any(x -> x.code == "W.PROV.X_NONINDUCTIVE" &&
                       x.component_id == "lc_xneg", f)

        # X not PSD (diag 0.1, mutual 0.5 → eig −0.4) → warning
        net2 = deepcopy(base)
        net2["linecode"]["lc_xpsd"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3, "R_series_3_3" => 0.3,
            "X_series_1_1" => 0.1, "X_series_2_2" => 0.1, "X_series_3_3" => 0.1,
            "X_series_1_2" => 0.5, "X_series_1_3" => 0.5, "X_series_2_3" => 0.5)
        f2 = Finding[]
        provenance_analysis(net2, f2)
        @test any(x -> x.code == "W.PROV.X_NOT_PSD" &&
                       x.component_id == "lc_xpsd", f2)

        # negative mutual resistance → soft INFO
        net3 = deepcopy(base)
        net3["linecode"]["lc_negm"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3, "R_series_3_3" => 0.3,
            "R_series_1_2" => -0.05, "R_series_1_3" => 0.05, "R_series_2_3" => 0.05,
            "X_series_1_1" => 0.9, "X_series_2_2" => 0.9, "X_series_3_3" => 0.9)
        f3 = Finding[]
        provenance_analysis(net3, f3)
        @test any(x -> x.code == "I.PROV.NEGATIVE_MUTUAL_R" &&
                       x.component_id == "lc_negm", f3)

        # positive off-diagonal B but PSD: soft INFO (screen-elimination
        # artifacts are legitimate); non-PSD B: WARNING
        net4 = deepcopy(base)
        net4["linecode"]["lc_boff"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3,
            "X_series_1_1" => 0.9, "X_series_2_2" => 0.9,
            "B_from_1_1" => 1e-6, "B_from_2_2" => 1e-6,
            "B_from_1_2" => 1e-7, "B_from_2_1" => 1e-7)   # positive mutual, PSD
        net4["linecode"]["lc_bpsd"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3,
            "X_series_1_1" => 0.9, "X_series_2_2" => 0.9,
            "B_from_1_1" => 1e-7, "B_from_2_2" => 1e-7,
            "B_from_1_2" => -1e-6, "B_from_2_1" => -1e-6)  # eig < 0
        f4 = Finding[]
        provenance_analysis(net4, f4)
        @test any(x -> x.code == "I.PROV.B_OFFDIAG" &&
                       x.component_id == "lc_boff", f4)
        @test any(x -> x.code == "W.PROV.B_SIGN" &&
                       x.component_id == "lc_bpsd", f4)
        @test !any(x -> x.code == "W.PROV.B_SIGN" &&
                        x.component_id == "lc_boff", f4)

        # bus shunt: asymmetric matrix (the printed Eq. 98 form!) → reciprocity ERROR
        net5 = deepcopy(base)
        net5["shunt"] = Dict{String,Any}(
            "delta_cap" => Dict{String,Any}(
                "bus" => "632", "terminal_map" => ["1","2","3"],
                "B_1_1" => 1.0, "B_1_2" => -1.0, "B_1_3" => 0.0,
                "B_2_1" => 0.0, "B_2_2" => 1.0, "B_2_3" => -1.0,
                "B_3_1" => -1.0, "B_3_2" => 0.0, "B_3_3" => 1.0,
                "G_1_1" => 0.0))
        f5 = Finding[]
        provenance_analysis(net5, f5)
        @test any(x -> x.code == "E.PROV.NONRECIPROCAL" &&
                       x.component_type == :shunt, f5)

        # bus shunt: negative conductance → ERROR
        net6 = deepcopy(base)
        net6["shunt"] = Dict{String,Any}(
            "active" => Dict{String,Any}(
                "bus" => "632", "terminal_map" => ["n"],
                "G_1_1" => -0.5, "B_1_1" => 0.0))
        f6 = Finding[]
        provenance_analysis(net6, f6)
        @test any(x -> x.code == "E.PROV.NEGATIVE_G", f6)

        # domain rules: zero limits, zero length, degree angles, negative load
        net7 = deepcopy(base)
        net7["linecode"]["lc601"]["i_max"] = [600.0, 0.0, 600.0]
        net7["line"]["l650632"]["length"] = 0.0
        net7["voltage_source"]["source"]["v_angle"] = [0.0, -120.0, 120.0]
        net7["load"]["load_652"]["p_nom"] = [-128000.0]
        f7 = Finding[]
        domain_rules_check(net7, f7)
        @test any(x -> x.code == "W.DOM.ZERO_LIMIT", f7)
        @test any(x -> x.code == "W.DOM.ZERO_LENGTH", f7)
        @test any(x -> x.code == "W.DOM.ANGLE_UNITS", f7)
        @test any(x -> x.code == "I.DOM.NEGATIVE_LOAD", f7)

        # preflight: vpn and q bound conflicts
        net8 = deepcopy(base)
        net8["bus"]["632"]["vpn_min"] = [240.0, 240.0, 240.0]
        net8["bus"]["632"]["vpn_max"] = [230.0, 230.0, 230.0]
        net8["generator"]["gen_634"]["q_min"] = [60000.0, 60000.0, 60000.0]
        f8 = Finding[]
        infeasibility_preflight(net8, f8)
        @test any(x -> x.code == "E.PRE.VBOUND_CONFLICT" &&
                       x.component_id == "632", f8)
        @test any(x -> x.code == "E.PRE.QBOUND_CONFLICT" &&
                       x.component_id == "gen_634", f8)

        # preflight: generators co-located with the voltage source
        net9 = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
                "b1":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "generator":{
             "g_unb":{"bus":"src","terminal_map":["1","n"],"configuration":"WYE","cost":[1.0]},
             "g_bnd":{"bus":"src","terminal_map":["1","n"],"configuration":"WYE",
                      "p_max":[1.0e4],"q_max":[1.0e3],"cost":[1.0]},
             "g_far":{"bus":"b1","terminal_map":["1","n"],"configuration":"WYE",
                      "p_max":[1.0e4],"q_max":[1.0e3],"cost":[1.0]}}}
        """; from_string=true)
        f9 = Finding[]
        r9 = infeasibility_preflight(net9, f9)
        # unbounded generator at source bus → WARNING (degenerate double slack)
        @test any(x -> x.code == "W.PRE.SOURCE_BUS_GENERATOR" &&
                       x.component_id == "g_unb", f9)
        # bounded generator at source bus → INFO (advisory)
        @test any(x -> x.code == "I.PRE.SOURCE_BUS_GENERATOR" &&
                       x.component_id == "g_bnd", f9)
        # generator at a non-source bus → not flagged
        @test !any(x -> occursin("SOURCE_BUS_GENERATOR", x.code) &&
                        x.component_id == "g_far", f9)
        @test r9["source_bus_generators"]["n_unbounded_source_bus_generators"] == 1
        @test r9["source_bus_generators"]["n_bounded_source_bus_generators"]   == 1
    end

    @testset "Integrity checks" begin
        base = parse_bmopf(IEEE13_FIXTURE; from_string=true)

        # pristine fixture: no integrity errors, 3 galvanic islands all referenced
        f0 = Finding[]
        res0 = integrity_check(base, f0)
        @test res0["n_reference_issues"] == 0
        @test res0["n_galvanic_islands"] == 3      # sourcebus | 650-tree | 634
        @test res0["n_without_reference"] == 0
        @test !any(x -> x.severity == ERROR, f0)

        # dangling references
        net = deepcopy(base)
        net["line"]["bad1"] = Dict{String,Any}(
            "bus_from" => "nowhere", "bus_to" => "632",
            "terminal_map_from" => ["1"], "terminal_map_to" => ["1"],
            "linecode" => "lc605", "length" => 1.0)
        net["line"]["bad2"] = Dict{String,Any}(
            "bus_from" => "650", "bus_to" => "632",
            "terminal_map_from" => ["1"], "terminal_map_to" => ["1"],
            "linecode" => "lc_missing", "length" => 1.0)
        net["load"]["bad3"] = Dict{String,Any}(
            "bus" => "611", "terminal_map" => ["1","n"],   # 611 has no "1"
            "configuration" => "SINGLE_PHASE",
            "p_nom" => [1.0], "q_nom" => [0.0])
        f1 = Finding[]
        integrity_check(net, f1)
        @test any(x -> x.code == "E.INT.UNKNOWN_BUS", f1)
        @test any(x -> x.code == "E.INT.UNKNOWN_LINECODE", f1)
        @test any(x -> x.code == "E.INT.UNKNOWN_TERMINAL" &&
                       x.component_id == "bad3", f1)

        # dimension mismatch: 1-terminal maps on a 3×3 linecode
        net2 = deepcopy(base)
        net2["line"]["dim"] = Dict{String,Any}(
            "bus_from" => "650", "bus_to" => "632",
            "terminal_map_from" => ["1"], "terminal_map_to" => ["1"],
            "linecode" => "lc601", "length" => 1.0)
        f2 = Finding[]
        integrity_check(net2, f2)
        @test any(x -> x.code == "W.INT.DIM_MISMATCH" &&
                       x.component_id == "dim", f2)

        # padded matrix: zero third row+column
        net3 = deepcopy(base)
        net3["linecode"]["lc_pad"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3, "R_series_3_3" => 0.0,
            "R_series_1_2" => 0.1, "R_series_1_3" => 0.0, "R_series_2_3" => 0.0,
            "X_series_1_1" => 0.9, "X_series_2_2" => 0.9, "X_series_3_3" => 0.0,
            "X_series_1_2" => 0.4, "X_series_1_3" => 0.0, "X_series_2_3" => 0.0)
        f3 = Finding[]
        integrity_check(net3, f3)
        @test any(x -> x.code == "W.INT.PADDED_MATRIX", f3)

        # galvanic island without reference: unground the 634 island
        net4 = deepcopy(base)
        delete!(net4["bus"]["634"], "perfectly_grounded_terminals")
        f4 = Finding[]
        res4 = integrity_check(net4, f4)
        @test res4["n_without_reference"] == 1
        @test any(x -> x.code == "E.INT.NO_VOLTAGE_REFERENCE", f4)

        # a delta capacitor bank (zero row sums) must NOT count as a reference
        net5 = deepcopy(net4)
        net5["shunt"] = Dict{String,Any}(
            "cap634" => Dict{String,Any}(
                "bus" => "634", "terminal_map" => ["1","2","3"],
                "G_1_1" => 0.0,
                "B_1_1" => 2.0,  "B_1_2" => -1.0, "B_1_3" => -1.0,
                "B_2_1" => -1.0, "B_2_2" => 2.0,  "B_2_3" => -1.0,
                "B_3_1" => -1.0, "B_3_2" => -1.0, "B_3_3" => 2.0))
        f5 = Finding[]
        res5 = integrity_check(net5, f5)
        @test res5["n_without_reference"] == 1
        # …but a grounding shunt (nonzero row sum) does
        net5["shunt"]["gnd634"] = Dict{String,Any}(
            "bus" => "634", "terminal_map" => ["n"],
            "G_1_1" => 0.1, "B_1_1" => 0.0)
        f5b = Finding[]
        res5b = integrity_check(net5, f5b)
        @test res5b["n_without_reference"] == 0

        # wye load at a bus without identifiable neutral
        net6 = deepcopy(base)
        net6["bus"]["3wire"] = Dict{String,Any}("terminal_names" => ["1","2","3"])
        net6["load"]["wye3w"] = Dict{String,Any}(
            "bus" => "3wire", "terminal_map" => ["1","2","3"],
            "configuration" => "WYE",
            "p_nom" => [1.0, 1.0, 1.0], "q_nom" => [0.0, 0.0, 0.0])
        f6 = Finding[]
        integrity_check(net6, f6)
        @test any(x -> x.code == "W.INT.WYE_WITHOUT_NEUTRAL" &&
                       x.component_id == "wye3w", f6)

        # low-impedance line: near-zero length vs the others
        net7 = deepcopy(base)
        net7["line"]["tiny"] = Dict{String,Any}(
            "bus_from" => "632", "bus_to" => "671",
            "terminal_map_from" => ["1","2","3"], "terminal_map_to" => ["1","2","3"],
            "linecode" => "lc601", "length" => 1e-9)
        f7 = Finding[]
        res7 = integrity_check(net7, f7)
        @test any(x -> x.code == "W.INT.LOW_IMPEDANCE_LINE", f7)
        @test res7["impedance_spread"] > 1e6

        # identical generator costs → degeneracy info
        net8 = deepcopy(base)
        net8["generator"]["gen_b"] = deepcopy(net8["generator"]["gen_634"])
        f8 = Finding[]
        integrity_check(net8, f8)
        @test any(x -> x.code == "I.INT.UNIFORM_GEN_COST", f8)
    end

    @testset "Integrity — floating load terminals" begin
        # Build a minimal 2-bus network where the line only carries 2 phases+neutral,
        # but the load claims all 3 phases.
        make_2bus() = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["1","2","3","n"]),
                "b2" => Dict{String,Any}("terminal_names" => ["1","2","3","n"])),
            "linecode" => Dict{String,Any}(
                "lc2w" => Dict{String,Any}("R_series_1_1" => 0.1, "R_series_2_2" => 0.1,
                                           "X_series_1_1" => 0.1, "X_series_2_2" => 0.1)),
            "line" => Dict{String,Any}(
                "l1" => Dict{String,Any}("bus_from" => "b1", "bus_to" => "b2",
                                          "terminal_map_from" => ["1","2","n"],
                                          "terminal_map_to"   => ["1","2","n"],
                                          "linecode" => "lc2w", "length" => 100.0)),
            "voltage_source" => Dict{String,Any}(
                "vs" => Dict{String,Any}("bus" => "b1",
                                          "terminal_map" => ["1","2","n"],
                                          "v_magnitude" => [230.0, 230.0],
                                          "v_angle"     => [0.0, -2.094])),
            "load" => Dict{String,Any}(
                "ld3ph" => Dict{String,Any}("bus" => "b2", "configuration" => "WYE",
                                             "terminal_map" => ["1","2","3","n"],
                                             "p_nom" => [1000.0, 1000.0, 1000.0],
                                             "q_nom" => [0.0, 0.0, 0.0])))

        # phase "3" on b2 has no branch — should flag
        net9 = make_2bus()
        f9 = Finding[]
        res9 = integrity_check(net9, f9)
        @test res9["n_floating_load_terminals"] == 1
        @test any(f -> f.code == "W.INT.FLOATING_LOAD_TERMINAL" &&
                       f.component_id == "ld3ph" &&
                       "3" in f.detail["terminals"], f9)

        # load only uses wired terminals — no false positive
        net10 = make_2bus()
        net10["load"]["ld3ph"]["terminal_map"] = ["1","2","n"]
        net10["load"]["ld3ph"]["p_nom"] = [1000.0, 1000.0]
        net10["load"]["ld3ph"]["q_nom"] = [0.0, 0.0]
        f10 = Finding[]
        res10 = integrity_check(net10, f10)
        @test res10["n_floating_load_terminals"] == 0
        @test !any(f -> f.code == "W.INT.FLOATING_LOAD_TERMINAL", f10)

        # load at voltage-source bus is exempt (source pins voltages)
        net11 = make_2bus()
        net11["load"]["ld3ph"]["bus"] = "b1"
        f11 = Finding[]
        res11 = integrity_check(net11, f11)
        @test res11["n_floating_load_terminals"] == 0
    end

    @testset "Integrity — unused bus terminals" begin
        # Base: b2 declares ["1","2","3","n"]; line and load only use ["1","2","n"].
        # Terminal "3" is declared but nothing references it — should flag.
        make_sparse_bus() = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "b1" => Dict{String,Any}("terminal_names" => ["1","2","n"]),
                "b2" => Dict{String,Any}("terminal_names" => ["1","2","3","n"])),
            "linecode" => Dict{String,Any}(
                "lc2" => Dict{String,Any}("R_series_1_1" => 0.1, "R_series_2_2" => 0.1,
                                          "X_series_1_1" => 0.1, "X_series_2_2" => 0.1)),
            "line" => Dict{String,Any}(
                "l1" => Dict{String,Any}("bus_from" => "b1", "bus_to" => "b2",
                                          "terminal_map_from" => ["1","2","n"],
                                          "terminal_map_to"   => ["1","2","n"],
                                          "linecode" => "lc2", "length" => 100.0)),
            "voltage_source" => Dict{String,Any}(
                "vs" => Dict{String,Any}("bus" => "b1",
                                          "terminal_map" => ["1","2","n"],
                                          "v_magnitude" => [230.0, 230.0],
                                          "v_angle"     => [0.0, -2.094])),
            "load" => Dict{String,Any}(
                "ld" => Dict{String,Any}("bus" => "b2", "configuration" => "WYE",
                                          "terminal_map" => ["1","2","n"],
                                          "p_nom" => [1000.0, 1000.0],
                                          "q_nom" => [0.0, 0.0])))

        # terminal "3" on b2 is declared but unused — should flag once
        net_u1 = make_sparse_bus()
        fu1 = Finding[]
        res_u1 = integrity_check(net_u1, fu1)
        @test res_u1["n_unused_bus_terminals"] == 1
        @test any(f -> f.code == "W.INT.UNUSED_BUS_TERMINAL" &&
                       f.component_id == "b2" &&
                       "3" in f.detail["terminals"], fu1)

        # load uses all declared terminals — no false positive
        net_u2 = make_sparse_bus()
        net_u2["bus"]["b2"]["terminal_names"] = ["1","2","n"]
        fu2 = Finding[]
        res_u2 = integrity_check(net_u2, fu2)
        @test res_u2["n_unused_bus_terminals"] == 0
        @test !any(f -> f.code == "W.INT.UNUSED_BUS_TERMINAL", fu2)

        # terminal covered by a shunt (not load/branch) — still counts as used
        net_u3 = make_sparse_bus()
        net_u3["shunt"] = Dict{String,Any}(
            "sh1" => Dict{String,Any}("bus" => "b2", "terminal_map" => ["3","n"],
                                       "G_1_1" => 0.01, "B_1_1" => 0.0))
        fu3 = Finding[]
        res_u3 = integrity_check(net_u3, fu3)
        @test res_u3["n_unused_bus_terminals"] == 0
        @test !any(f -> f.code == "W.INT.UNUSED_BUS_TERMINAL", fu3)

        # voltage-source bus with surplus terminal is exempt
        net_u4 = make_sparse_bus()
        net_u4["bus"]["b1"]["terminal_names"] = ["1","2","3","n"]
        fu4 = Finding[]
        res_u4 = integrity_check(net_u4, fu4)
        # only b2's "3" should flag; b1 is a source bus
        @test !any(f -> f.code == "W.INT.UNUSED_BUS_TERMINAL" &&
                        f.component_id == "b1", fu4)
    end

    @testset "OpenDSS default fingerprints" begin
        base = parse_bmopf(IEEE13_FIXTURE; from_string=true)

        # default line constants r1/x1/r0/z0 (Ω/kft → Ω/m, balanced matrix)
        net = deepcopy(base)
        z1 = (0.058 + im * 0.1206) / 304.8
        z0 = (0.1784 + im * 0.4047) / 304.8
        zs = (z0 + 2z1) / 3
        zm = (z0 - z1) / 3
        lc = Dict{String,Any}()
        for i in 1:3, j in 1:3
            z = i == j ? zs : zm
            lc["R_series_$(i)_$(j)"] = real(z)
            lc["X_series_$(i)_$(j)"] = imag(z)
        end
        net["linecode"]["lc_dssdef"] = lc
        f = Finding[]
        res = provenance_analysis(net, f)
        @test any(x -> x.code == "W.PROV.DSS_DEFAULT_Z", f)
        @test "lc_dssdef" in res["opendss_defaults"]["default_z_linecodes"]

        # normamps default (400 A); fixture's genuine 600 A must NOT flag
        net2 = deepcopy(base)
        net2["linecode"]["lc605"]["i_max"] = [400.0]
        f2 = Finding[]
        provenance_analysis(net2, f2)
        @test any(x -> x.code == "I.PROV.DSS_DEFAULT_AMPS", f2)
        f2b = Finding[]
        provenance_analysis(base, f2b)
        @test !any(x -> x.code == "I.PROV.DSS_DEFAULT_AMPS", f2b)

        # xhl = 7 % on xfm2 (4160/480, 500 kVA)
        net3 = deepcopy(base)
        zbf = 4160.0^2 / 500_000.0
        zbt = 480.0^2  / 500_000.0
        net3["transformer"]["single_phase"]["xfm2"]["x_series_from"] = 0.035 * zbf
        net3["transformer"]["single_phase"]["xfm2"]["x_series_to"]   = 0.035 * zbt
        f3 = Finding[]
        provenance_analysis(net3, f3)
        @test any(x -> x.code == "I.PROV.DSS_DEFAULT_XFMR", f3)

        # load pf = 0.88
        net4 = deepcopy(base)
        net4["load"]["load_652"]["p_nom"] = [10000.0]
        net4["load"]["load_652"]["q_nom"] = [10000.0 * tan(acos(0.88))]
        f4 = Finding[]
        provenance_analysis(net4, f4)
        @test any(x -> x.code == "I.PROV.DSS_DEFAULT_PF", f4)

        # default kv = 12.47
        net5 = deepcopy(base)
        net5["transformer"]["single_phase"]["xfm2"]["v_ref_from"] = 12470.0
        f5 = Finding[]
        provenance_analysis(net5, f5)
        @test any(x -> x.code == "I.PROV.DSS_DEFAULT_KV", f5)

        # scattered length 1.0 → leak; universal → convention
        net6 = deepcopy(base)
        net6["line"]["l671652"]["length"] = 1.0
        f6 = Finding[]
        provenance_analysis(net6, f6)
        @test any(x -> x.code == "I.PROV.DSS_DEFAULT_LENGTH", f6)
        net7 = deepcopy(base)
        for (_, l) in net7["line"]
            l["length"] = 1.0
        end
        f7 = Finding[]
        res7 = provenance_analysis(net7, f7)
        @test !any(x -> x.code == "I.PROV.DSS_DEFAULT_LENGTH", f7)
        @test res7["opendss_defaults"]["length_normalized"] == true
        @test occursin("length-normalized", res7["convention"])

        # default source impedance (MVAsc3=2000, X1R1=4) via _pmd rs/xs
        net8 = deepcopy(base)
        kV_LL = 2401.8 * sqrt(3)
        r1d = kV_LL^2 / 2000e6 / sqrt(17)
        z1d = complex(r1d, 4r1d)
        zsd = 1.2 * z1d
        zmd = 0.2 * z1d
        mk(part) = [i == j ? part(zsd) : part(zmd) for i in 1:3, j in 1:3]
        net8["voltage_source"]["source"]["_pmd"] = Dict{String,Any}(
            "rs" => mk(real), "xs" => mk(imag))
        f8 = Finding[]
        provenance_analysis(net8, f8)
        @test any(x -> x.code == "W.PROV.DSS_DEFAULT_SOURCE_Z", f8)
    end

    @testset "Earthing zones" begin
        # LV feeder: star earthed via 0.3 Ω at source bus, one 10 Ω
        # downstream neutral earth → TN-C-S / multi-earthed
        lvnet = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "a" => Dict{String,Any}("terminal_names" => ["1","2","3","n"]),
                "b" => Dict{String,Any}("terminal_names" => ["1","2","3","n"])),
            "voltage_source" => Dict{String,Any}(
                "src" => Dict{String,Any}(
                    "bus" => "a", "terminal_map" => ["1","2","3"],
                    "v_magnitude" => [230.0, 230.0, 230.0],
                    "v_angle" => [0.0, -2.094, 2.094])),
            "line" => Dict{String,Any}(
                "l1" => Dict{String,Any}(
                    "bus_from" => "a", "bus_to" => "b",
                    "terminal_map_from" => ["1","2","3","n"],
                    "terminal_map_to"   => ["1","2","3","n"],
                    "linecode" => "lc", "length" => 10.0)),
            "shunt" => Dict{String,Any}(
                "g_a" => Dict{String,Any}(
                    "bus" => "a", "terminal_map" => ["n"],
                    "G_1_1" => 1/0.3, "B_1_1" => 0.0),
                "g_b" => Dict{String,Any}(
                    "bus" => "b", "terminal_map" => ["n"],
                    "G_1_1" => 0.1, "B_1_1" => 0.0)))
        f = Finding[]
        zones = provenance_analysis(lvnet, f)["earthing_zones"]
        @test length(zones) == 1
        @test occursin("TN-C-S", zones[1]["tag"])
        @test zones[1]["n_downstream_earths"] == 1

        # source-earthed only → explicit TN-S/TT ambiguity
        net2 = deepcopy(lvnet)
        delete!(net2["shunt"], "g_b")
        z2 = provenance_analysis(net2, Finding[])["earthing_zones"]
        @test occursin("TN-S or TT", z2[1]["tag"])

        # no neutral earthing anywhere → IT
        net3 = deepcopy(net2)
        delete!(net3, "shunt")
        z3 = provenance_analysis(net3, Finding[])["earthing_zones"]
        @test startswith(z3[1]["tag"], "IT")

        # MV island uses MV vocabulary: fixture sourcebus (2.4 kV LN,
        # perfectly grounded) → "solidly earthed"
        base = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        zb = provenance_analysis(base, Finding[])["earthing_zones"]
        src_zone = first(z for z in zb if "sourcebus" in z["buses"])
        @test src_zone["tag"] == "solidly earthed"
    end

    @testset "Regulator / autotransformer patterns" begin
        # Pattern A: near-1:1 single_phase (wye-wye) transformer with very
        # low impedance between buses at the same voltage level
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "a" => Dict{String,Any}("terminal_names" => ["1","2","3","n"]),
                "b" => Dict{String,Any}("terminal_names" => ["1","2","3","n"])),
            "voltage_source" => Dict{String,Any}(
                "src" => Dict{String,Any}(
                    "bus" => "a", "terminal_map" => ["1","2","3","n"],
                    "v_magnitude" => [2400.0, 2400.0, 2400.0, 0.0],
                    "v_angle" => [0.0, -2.094, 2.094, 0.0])),
            "transformer" => Dict{String,Any}(
                "single_phase" => Dict{String,Any}(
                    "reg1" => Dict{String,Any}(
                        "bus_from" => "a", "bus_to" => "b",
                        "terminal_map_from" => ["1","n"],
                        "terminal_map_to"   => ["1","n"],
                        "v_ref_from" => 2400.0, "v_ref_to" => 2400.0,
                        "s_rating" => 500_000.0,
                        "x_series_from" => 0.0005 * 2400.0^2 / 500_000.0,
                        "x_series_to"   => 0.0005 * 2400.0^2 / 500_000.0,
                        "r_series_from" => 0.0, "r_series_to" => 0.0))))
        f = Finding[]
        provenance_analysis(net, f)
        @test any(x -> x.code == "W.PROV.REGULATOR_PATTERN" &&
                       x.component_id == "reg1", f)

        # Pattern B: explicit autotransformer — both windings on one bus
        net2 = deepcopy(net)
        net2["transformer"]["single_phase"]["auto1"] = Dict{String,Any}(
            "bus_from" => "a", "bus_to" => "a",
            "terminal_map_from" => ["1","n"], "terminal_map_to" => ["2","n"],
            "v_ref_from" => 7200.0, "v_ref_to" => 720.0,
            "s_rating" => 50_000.0)
        f2 = Finding[]
        provenance_analysis(net2, f2)
        @test any(x -> x.code == "W.PROV.REGULATOR_PATTERN" &&
                       x.component_id == "auto1", f2)

        # fixture must NOT trigger: xfm1 is 1:1 but wye-delta (phase
        # shifter, never a regulator); xfm2 is a real step-down
        base = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        fb = Finding[]
        provenance_analysis(base, fb)
        @test !any(x -> x.code == "W.PROV.REGULATOR_PATTERN", fb)
    end

    @testset "Terminal ingest normalization" begin
        # spec requires string terminal identifiers; numeric ones are
        # normalized at parse via the 1≡a, 2≡b, 3≡c, 4≡n convention
        raw = """
        {"bus": {"a": {"terminal_names": [1,2,3,4],
                       "perfectly_grounded_terminals": [4]}},
         "voltage_source": {"s": {"bus": "a", "terminal_map": [1,2,3,4],
            "v_magnitude": [230.0,230.0,230.0,0.0],
            "v_angle": [0.0,-2.094,2.094,0.0]}},
         "load": {"d": {"bus": "a", "terminal_map": [1,4],
            "configuration": "SINGLE_PHASE",
            "p_nom": [1000.0], "q_nom": [0.0]}}}
        """
        net = parse_bmopf(raw; from_string=true)
        @test net["bus"]["a"]["terminal_names"] == ["1","2","3","n"]
        @test net["bus"]["a"]["perfectly_grounded_terminals"] == ["n"]
        @test net["load"]["d"]["terminal_map"] == ["1","n"]
        @test net["_meta"]["terminal_coercions"]["mode"] == "aliases"

        # the coercion is surfaced as a conformance finding, and the
        # normalized net analyzes without crashing
        report = analyze(net)
        @test any(f -> f.code == "W.SPEC.TERMINAL_TYPES", report.findings)
        @test haskey(report.results, :integrity)

        # profiling guard: an exotic terminal disables the alias convention —
        # everything becomes its verbatim decimal string instead
        raw2 = replace(raw, "[1,2,3,4]," => "[1,2,3,4,5],")
        net2 = parse_bmopf(raw2; from_string=true)
        @test net2["bus"]["a"]["terminal_names"] == ["1","2","3","4","5"]
        @test net2["_meta"]["terminal_coercions"]["mode"] == "verbatim-string"

        # user-supplied custom mapping
        net3 = parse_bmopf(raw; from_string=true,
            terminal_aliases=Dict{Any,String}(1=>"a", 2=>"b", 3=>"c", 4=>"n"))
        @test net3["bus"]["a"]["terminal_names"] == ["a","b","c","n"]

        # hand-built dicts with integer terminals (bypassing parse_bmopf)
        # must degrade to findings, never crash the checks
        net4 = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "a" => Dict{String,Any}("terminal_names" => Any[1,2,3,4])),
            "load" => Dict{String,Any}(
                "d" => Dict{String,Any}(
                    "bus" => "a", "terminal_map" => Any[1,4],
                    "configuration" => "SINGLE_PHASE",
                    "p_nom" => [1.0], "q_nom" => [0.0])))
        f4 = Finding[]
        integrity_check(net4, f4)            # no MethodError
        provenance_analysis(net4, Finding[]) # no MethodError
        @test !any(x -> x.code == "E.INT.UNKNOWN_TERMINAL", f4)
    end

    @testset "Terminal-name conventions" begin
        # letter convention: a/b/c/n; explicit neutral_terminal field; no neutral
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "x" => Dict{String,Any}("terminal_names" => ["a","b","c","n"]),
                "y" => Dict{String,Any}("terminal_names" => ["1","2","3","4"],
                                        "neutral_terminal" => "4"),
                "z" => Dict{String,Any}("terminal_names" => ["1","2","3"])))
        findings = Finding[]
        inv = inventory_analysis(net, findings)
        # a/b/c (+n) → 3-phase via name; 1/2/3/4 → 3-phase via explicit field; 1/2/3 → 3-phase
        @test inv["bus"]["by_n_phases"] == Dict(3 => 3)

        # to_pmd accepts the broadened conventions
        @test BMOPFTools._terminal_name_to_int("a")  == 1
        @test BMOPFTools._terminal_name_to_int("N")  == 4
        @test BMOPFTools._terminal_name_to_int("L2") == 2
        @test_throws ArgumentError BMOPFTools._terminal_name_to_int("xyz")
    end

    @testset "Provenance — linecode impedance classification" begin
        # Real Carson-style data (IEEE13 lc601): distinct entries
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        res = provenance_analysis(net, findings)
        by_lc = res["linecodes"]["by_linecode"]
        @test by_lc["lc601"]["verdict"] == "distinct"
        @test by_lc["lc605"]["verdict"] == "not_applicable"   # single-phase

        # Sequence-derived: exactly balanced matrix, Z1/Z0 recovery
        net2 = deepcopy(net)
        net2["linecode"]["lc_seq"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3, "R_series_3_3" => 0.3,
            "R_series_1_2" => 0.1, "R_series_1_3" => 0.1, "R_series_2_3" => 0.1,
            "X_series_1_1" => 0.9, "X_series_2_2" => 0.9, "X_series_3_3" => 0.9,
            "X_series_1_2" => 0.4, "X_series_1_3" => 0.4, "X_series_2_3" => 0.4)
        findings2 = Finding[]
        res2 = provenance_analysis(net2, findings2)
        e = res2["linecodes"]["by_linecode"]["lc_seq"]
        @test e["verdict"] == "exactly_balanced"
        @test e["z1"]["r"] ≈ 0.2  &&  e["z1"]["x"] ≈ 0.5
        @test e["z0"]["r"] ≈ 0.5  &&  e["z0"]["x"] ≈ 1.7
        @test any(f -> f.code == "I.PROV.SEQ_DERIVED", findings2)

        # Positive-sequence only: diagonal matrix → decoupled phases
        net3 = deepcopy(net)
        net3["linecode"]["lc_diag"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3, "R_series_3_3" => 0.3,
            "X_series_1_1" => 0.9, "X_series_2_2" => 0.9, "X_series_3_3" => 0.9)
        findings3 = Finding[]
        res3 = provenance_analysis(net3, findings3)
        @test res3["linecodes"]["by_linecode"]["lc_diag"]["verdict"] == "decoupled"
        @test any(f -> f.code == "I.PROV.DECOUPLED_PHASES", findings3)

        # Non-passive R block (eigenvalues 1.1, -0.4, -0.4) → ERROR
        net4 = deepcopy(net)
        net4["linecode"]["lc_bad"] = Dict{String,Any}(
            "R_series_1_1" => 0.1, "R_series_2_2" => 0.1, "R_series_3_3" => 0.1,
            "R_series_1_2" => 0.5, "R_series_1_3" => 0.5, "R_series_2_3" => 0.5,
            "X_series_1_1" => 0.9)
        findings4 = Finding[]
        provenance_analysis(net4, findings4)
        @test any(f -> f.code == "E.PROV.NONPASSIVE" &&
                       f.component_id == "lc_bad", findings4)

        # Non-reciprocal matrix → ERROR
        net5 = deepcopy(net)
        net5["linecode"]["lc_asym"] = Dict{String,Any}(
            "R_series_1_1" => 0.3, "R_series_2_2" => 0.3,
            "R_series_1_2" => 0.1, "R_series_2_1" => 0.2,
            "X_series_1_1" => 0.9, "X_series_2_2" => 0.9)
        findings5 = Finding[]
        provenance_analysis(net5, findings5)
        @test any(f -> f.code == "E.PROV.NONRECIPROCAL" &&
                       f.component_id == "lc_asym", findings5)
    end

    @testset "Provenance — Kron reduction and grounding" begin
        # 3-wire LV network with a phase-to-ground load → Kron-likely
        kron_net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "a" => Dict{String,Any}("terminal_names" => ["1","2","3"]),
                "b" => Dict{String,Any}("terminal_names" => ["1","2","3"])),
            "voltage_source" => Dict{String,Any}(
                "src" => Dict{String,Any}(
                    "bus" => "a", "terminal_map" => ["1","2","3"],
                    "v_magnitude" => [230.0, 230.0, 230.0],
                    "v_angle" => [0.0, -2.094, 2.094])),
            "line" => Dict{String,Any}(
                "l1" => Dict{String,Any}(
                    "bus_from" => "a", "bus_to" => "b",
                    "terminal_map_from" => ["1","2","3"],
                    "terminal_map_to"   => ["1","2","3"],
                    "linecode" => "lc", "length" => 10.0)),
            "load" => Dict{String,Any}(
                "ld" => Dict{String,Any}(
                    "bus" => "b", "terminal_map" => ["1"],
                    "configuration" => "WYE",
                    "p_nom" => [1000.0], "q_nom" => [0.0])))
        findings = Finding[]
        res = provenance_analysis(kron_net, findings)
        @test any(f -> f.code == "I.PROV.KRON_LIKELY", findings)
        @test occursin("Kron", res["convention"])

        # 4-wire with neutral conductor but no grounding → floating ERROR
        float_net = deepcopy(kron_net)
        for b in values(float_net["bus"])
            b["terminal_names"] = ["1","2","3","n"]
        end
        float_net["line"]["l1"]["terminal_map_from"] = ["1","2","3","n"]
        float_net["line"]["l1"]["terminal_map_to"]   = ["1","2","3","n"]
        float_net["load"]["ld"]["terminal_map"] = ["1","n"]
        findings2 = Finding[]
        provenance_analysis(float_net, findings2)
        @test any(f -> f.code == "E.PROV.FLOATING_NEUTRAL", findings2)
        @test !any(f -> f.code == "I.PROV.KRON_LIKELY", findings2)

        # adding a grounding shunt resolves it
        grounded_net = deepcopy(float_net)
        grounded_net["shunt"] = Dict{String,Any}(
            "gnd" => Dict{String,Any}(
                "bus" => "a", "terminal_map" => ["n"],
                "G_1_1" => 0.1, "B_1_1" => 0.0))
        findings3 = Finding[]
        res3 = provenance_analysis(grounded_net, findings3)
        @test !any(f -> occursin("FLOATING_NEUTRAL", f.code), findings3)
        @test res3["grounding"]["n_floating"] == 0

        # IEEE13-style fixture: neutral terminals exist but no branch carries
        # them — implicit (Kron-style) grounding convention, made explicit
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings4 = Finding[]
        res4 = provenance_analysis(net, findings4)
        @test res4["grounding"]["convention"] == "implicit"
        @test any(f -> f.code == "W.PROV.IMPLICIT_GROUNDING", findings4)
        @test !any(f -> f.severity == ERROR && f.section == :provenance, findings4)

        # analyze() must carry the provenance section
        report = analyze(net)
        @test haskey(report.results, :provenance)
        @test haskey(report.results[:provenance], "convention")
    end

    @testset "I.PROV.WYE_NEUTRAL_UNGROUNDED — wye star point without local earth" begin
        # delta_wye xf: wye (LV) star point brought out at bus 'b', no ground.
        mk = (; ground=nothing) -> begin
            bus_b = Dict{String,Any}("terminal_names" => ["1","2","3","n"])
            ground === :perfect && (bus_b["perfectly_grounded_terminals"] = ["n"])
            net = Dict{String,Any}(
                "bus" => Dict{String,Any}(
                    "a" => Dict{String,Any}("terminal_names" => ["1","2","3"]),
                    "b" => bus_b),
                "transformer" => Dict{String,Any}(
                    "delta_wye" => Dict{String,Any}(
                        "t1" => Dict{String,Any}(
                            "bus_from" => "a", "bus_to" => "b",
                            "terminal_map_from" => ["1","2","3"],
                            "terminal_map_to"   => ["1","2","3","n"],
                            "v_ref_from" => 11000.0, "v_ref_to" => 433.0))))
            ground === :shunt && (net["shunt"] = Dict{String,Any}(
                "gnd" => Dict{String,Any}("bus" => "b", "terminal_map" => ["n"],
                    "G_1_1" => 0.1, "B_1_1" => 0.0)))
            net
        end

        has(f) = any(x -> x.code == "I.PROV.WYE_NEUTRAL_UNGROUNDED", f)

        # ungrounded star point → info
        f1 = Finding[]; provenance_analysis(mk(), f1)
        @test has(f1)
        info = first(x for x in f1 if x.code == "I.PROV.WYE_NEUTRAL_UNGROUNDED")
        @test info.severity == INFO
        @test info.detail["bus"] == "b"
        @test info.detail["side"] == "secondary"

        # perfect ground on the star-point bus resolves it
        f2 = Finding[]; provenance_analysis(mk(ground=:perfect), f2)
        @test !has(f2)

        # grounding impedance (shunt on neutral) also resolves it
        f3 = Finding[]; provenance_analysis(mk(ground=:shunt), f3)
        @test !has(f3)

        # single-phase phase-to-neutral xf is exempt (only 1 phase conductor)
        sp = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "a" => Dict{String,Any}("terminal_names" => ["1","n"]),
                "b" => Dict{String,Any}("terminal_names" => ["1","n"])),
            "transformer" => Dict{String,Any}(
                "single_phase" => Dict{String,Any}(
                    "t1" => Dict{String,Any}(
                        "bus_from" => "a", "bus_to" => "b",
                        "terminal_map_from" => ["1","n"],
                        "terminal_map_to"   => ["1","n"],
                        "v_ref_from" => 11000.0, "v_ref_to" => 230.0))))
        f4 = Finding[]; provenance_analysis(sp, f4)
        @test !has(f4)
    end

    @testset "I.PROV.LINE_SWITCH_LIKE — near-zero impedance detection" begin
        mk_net(R, X, length) = parse_bmopf("""
        {"bus":{
            "a":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "b":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"a","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "linecode":{"lc":{"R_series_1_1":$R,"X_series_1_1":$X}},
         "line":{"l1":{"bus_from":"a","bus_to":"b",
             "terminal_map_from":["1","n"],"terminal_map_to":["1","n"],
             "linecode":"lc","length":$length}}}
        """; from_string=true)

        # condition 1: linecode impedance per-unit-length is near-zero
        f1 = Finding[]
        res1 = provenance_analysis(mk_net(1e-9, 1e-9, 100.0), f1)
        @test any(f -> f.code == "I.PROV.LINE_SWITCH_LIKE" && f.component_id == "l1", f1)
        @test res1["switch_like_lines"]["n"] == 1

        # condition 2: effective impedance (Z * length) is near-zero due to short length
        f2 = Finding[]
        res2 = provenance_analysis(mk_net(1e-3, 1e-3, 0.05), f2)
        @test any(f -> f.code == "I.PROV.LINE_SWITCH_LIKE" && f.component_id == "l1", f2)
        @test res2["switch_like_lines"]["n"] == 1

        # normal line: neither condition triggered
        f3 = Finding[]
        res3 = provenance_analysis(mk_net(3e-4, 2e-4, 100.0), f3)
        @test !any(f -> f.code == "I.PROV.LINE_SWITCH_LIKE", f3)
        @test res3["switch_like_lines"]["n"] == 0
    end

    @testset "from_pmd — earth-bonded voltage source" begin
        # ENWL-style source: neutral bonded to earth via a grounding reactor,
        # so PMD reports connections [1,2,3,5] with vm/va aligned to them.
        # Terminal 5 (earth) must be dropped with its vm/va entries.
        eng = Dict{String,Any}(
            "settings" => Dict{String,Any}("voltage_scale_factor" => 1000.0),
            "bus" => Dict{String,Any}(
                "sourcebus" => Dict{String,Any}(
                    "terminals" => [1,2,3,4,5], "grounded" => [5])),
            "voltage_source" => Dict{String,Any}(
                "source" => Dict{String,Any}(
                    "bus" => "sourcebus",
                    "connections" => [1,2,3,5],
                    "vm" => [0.24, 0.24, 0.24, 0.0],
                    "va" => [0.0, -120.0, 120.0, 0.0])))

        net = from_pmd(eng)
        vs  = net["voltage_source"]["source"]
        @test vs["terminal_map"] == ["1","2","3"]
        @test vs["v_magnitude"] ≈ [240.0, 240.0, 240.0]
        @test length(vs["v_angle"]) == 3
        # earth terminal must not appear on the bus either
        @test net["bus"]["sourcebus"]["terminal_names"] == ["1","2","3","n"]
        @test !haskey(net["bus"]["sourcebus"], "perfectly_grounded_terminals")
    end

    @testset "to_pmd — impedance matrix reconstruction" begin
        # Pattern keys (R_series_1_2 …) must rebuild PMD rs/xs matrices,
        # mirroring upper-triangular storage onto the symmetric lower half.
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        eng = to_pmd(net)

        rs = eng["linecode"]["lc601"]["rs"]
        @test size(rs) == (3, 3)
        @test rs[1,1] ≈ 3.3717e-4
        @test rs[1,2] ≈ 1.5283e-4
        @test rs[2,1] ≈ 1.5283e-4      # mirrored from upper triangle
        @test rs[3,3] ≈ 3.0282e-4
        xs = eng["linecode"]["lc601"]["xs"]
        @test xs[2,3] ≈ 2.7967e-4
        @test xs[3,2] ≈ 2.7967e-4

        # single-phase linecode → 1×1 matrix
        @test eng["linecode"]["lc605"]["rs"][1,1] ≈ 1.0304e-3

        # shunt G/B pattern keys → gs/bs matrices
        net2 = deepcopy(net)
        net2["shunt"] = Dict{String,Any}(
            "sh1" => Dict{String,Any}(
                "bus" => "632", "terminal_map" => ["1"],
                "G_1_1" => 0.5, "B_1_1" => -0.1))
        eng2 = to_pmd(net2)
        @test eng2["shunt"]["sh1"]["gs"][1,1] ≈ 0.5
        @test eng2["shunt"]["sh1"]["bs"][1,1] ≈ -0.1
    end

    @testset "Completeness — transformer required fields" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        delete!(net["transformer"]["single_phase"]["xfm2"], "s_rating")
        report = analyze(net)
        @test any(f -> f.code == "E.COMP.MISSING_REQUIRED" &&
                       f.component_id == "xfm2", report.findings)
    end

    @testset "Connectivity — parallel lines break radiality" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        # duplicate an existing line: same endpoints, parallel branch = cycle
        net["line"]["l650632_par"] = deepcopy(net["line"]["l650632"])
        findings = Finding[]
        result = connectivity_analysis(net, findings)
        @test result["is_radial"] == false
        @test result["n_extra_edges"] == 1
        @test any(f -> f.code == "W.CONN.MESHED", findings)
    end

    @testset "Redundancy — switch tee blocks line merge" begin
        # 632 is a pass-through candidate only if nothing else attaches there.
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        delete!(net["load"], "load_632")              # remove its load
        delete!(net["transformer"]["single_phase"], "xfm2")  # and its transformer
        findings = Finding[]
        result = redundancy_check(net, findings)
        @test result["mergeable_lines"]["n_groups"] == 1   # l650632 + l632671

        # now tee a switch off 632 — merge must be blocked
        net["switch"] = Dict{String,Any}(
            "sw1" => Dict{String,Any}(
                "bus_from" => "632", "bus_to" => "611",
                "terminal_map_from" => ["3"], "terminal_map_to" => ["3"],
                "open_switch" => false))
        findings2 = Finding[]
        result2 = redundancy_check(net, findings2)
        @test result2["mergeable_lines"]["n_groups"] == 0
    end

    @testset "Domain rules — step-down transformer ratio not flagged" begin
        # 11kV/433V (ratio ≈ 0.039) is a standard distribution transformer
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        net["transformer"]["delta_wye"] = Dict{String,Any}(
            "tx_dist" => Dict{String,Any}(
                "bus_from" => "650", "bus_to" => "634",
                "terminal_map_from" => ["1","2","3"],
                "terminal_map_to"   => ["1","2","3","n"],
                "s_rating" => 100_000.0,
                "v_ref_from" => 11000.0, "v_ref_to" => 433.0))
        findings = Finding[]
        domain_rules_check(net, findings)
        @test !any(f -> f.code == "W.DOM.XFMR_RATIO_OOB" &&
                        f.component_id == "tx_dist", findings)

        # but an implausible 11kV/1V ratio is flagged
        net["transformer"]["delta_wye"]["tx_dist"]["v_ref_to"] = 1.0
        findings2 = Finding[]
        domain_rules_check(net, findings2)
        @test any(f -> f.code == "W.DOM.XFMR_RATIO_OOB" &&
                       f.component_id == "tx_dist", findings2)
    end

    @testset "Domain rules — non-uniform per-phase cost warning" begin
        dcodes(net) = (f = Finding[]; domain_rules_check(net, f);
                       [x.code for x in f])

        # Uniform per-phase generator cost → no warning
        net = parse_bmopf("""
        {"bus":{"b1":{"terminal_names":["1","2","3","n"],
            "perfectly_grounded_terminals":["n"],
            "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
         "generator":{"g1":{"bus":"b1","terminal_map":["1","2","3","n"],
             "cost":[0.1,0.1,0.1]}}}
        """; from_string=true)
        @test !("W.DOM.COST_PHASE_NONUNIFORM" in dcodes(net))

        # Non-uniform generator cost → warning on the generator
        net["generator"]["g1"]["cost"] = [0.1, 0.12, 0.1]
        f = Finding[]; domain_rules_check(net, f)
        @test any(x -> x.code == "W.DOM.COST_PHASE_NONUNIFORM" &&
                       x.component_id == "g1", f)

        # Scalar cost is uniform by definition → no warning
        net["generator"]["g1"]["cost"] = 0.1
        @test !("W.DOM.COST_PHASE_NONUNIFORM" in dcodes(net))

        # voltage_source with non-uniform cost → warning on the source
        vsnet = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","2","3","n"],
            "perfectly_grounded_terminals":["n"],
            "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944],
             "cost":[1.0,1.0,2.0]}}}
        """; from_string=true)
        f2 = Finding[]; domain_rules_check(vsnet, f2)
        @test any(x -> x.code == "W.DOM.COST_PHASE_NONUNIFORM" &&
                       x.component_id == "vs", f2)
    end

    @testset "Domain rules — source voltage near bus bound warning" begin
        # v_magnitude 230 sits mid-band of [200,260] → no warning
        mk(vmag, vmin, vmax) = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","2","3","n"],
                "perfectly_grounded_terminals":["n"],
                "v_min":$vmin,"v_max":$vmax},
            "b1":{"terminal_names":["1","2","3","n"],
                "perfectly_grounded_terminals":["n"],
                "v_min":[200.0,200.0,200.0],"v_max":[260.0,260.0,260.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":$vmag,"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":0.01,"R_series_2_2":0.01,"R_series_3_3":0.01}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
             "linecode":"lc","length":10.0}}}
        """; from_string=true)
        dcodes(net) = (f = Finding[]; domain_rules_check(net, f);
                       [x.code for x in f])

        # comfortably mid-band → no warning
        @test !("W.DOM.SOURCE_V_NEAR_BOUND" in
                dcodes(mk("[230.0,230.0,230.0]",
                          "[200.0,200.0,200.0]", "[260.0,260.0,260.0]")))

        # within 5 % of upper bound on source bus (band 60, margin 3 → ≥257) → warning
        @test "W.DOM.SOURCE_V_NEAR_BOUND" in
              dcodes(mk("[258.0,258.0,258.0]",
                        "[200.0,200.0,200.0]", "[260.0,260.0,260.0]"))

        # within 5 % of lower bound → warning
        @test "W.DOM.SOURCE_V_NEAR_BOUND" in
              dcodes(mk("[201.0,201.0,201.0]",
                        "[200.0,200.0,200.0]", "[260.0,260.0,260.0]"))

        # source bus comfortable, but neighbour bus (b1, [200,260]) tight against
        # 258 → still flagged via same-base line adjacency
        net = mk("[258.0,258.0,258.0]", "[100.0,100.0,100.0]", "[400.0,400.0,400.0]")
        f = Finding[]; domain_rules_check(net, f)
        hit = filter(x -> x.code == "W.DOM.SOURCE_V_NEAR_BOUND", f)
        @test length(hit) == 1
        @test hit[1].detail["bus"] == "b1"

        # Configurable margin: 250 is 10/60 ≈ 16.7 % below the 260 upper bound, so
        # it clears the default 5 % margin but trips a widened 20 % one.
        net2 = mk("[250.0,250.0,250.0]", "[200.0,200.0,200.0]", "[260.0,260.0,260.0]")
        fdef = Finding[]; domain_rules_check(net2, fdef)
        @test !any(x -> x.code == "W.DOM.SOURCE_V_NEAR_BOUND", fdef)
        fwide = Finding[]
        domain_rules_check(net2, fwide;
            thresholds=merge(BMOPFTools._domain_thresholds(),
                             Dict{String,Any}("source_v_margin_frac" => 0.20)))
        @test any(x -> x.code == "W.DOM.SOURCE_V_NEAR_BOUND", fwide)
    end

    @testset "Domain rules — shunt on perfectly grounded terminal warning" begin
        codes(net) = (f = Finding[]; domain_rules_check(net, f);
                      [x.code for x in f])

        # Shunt on a perfectly grounded bus terminal → inert → warning.
        net = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
            "lb":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "shunt":{"g1":{"bus":"lb","terminal_map":["n"],"G_1_1":5.0,"B_1_1":0.0}}}
        """; from_string=true)
        f = Finding[]; domain_rules_check(net, f)
        @test any(x -> x.code == "W.DOM.SHUNT_ON_GROUNDED" && x.component_id == "g1", f)

        # Shunt on a source-bus neutral (source-pinned to 0) → also inert → warning.
        net2 = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"neutral_terminal":"n"},
            "lb":{"terminal_names":["1","n"],"neutral_terminal":"n"}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "shunt":{"srcg":{"bus":"src","terminal_map":["n"],"G_1_1":1000.0,"B_1_1":0.0}}}
        """; from_string=true)
        f2 = Finding[]; domain_rules_check(net2, f2)
        @test any(x -> x.code == "W.DOM.SHUNT_ON_GROUNDED" && x.component_id == "srcg", f2)

        # Shunt on an UNGROUNDED (floating-neutral) terminal → carries current → no warning.
        net3 = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["1","n"],"neutral_terminal":"n"},
            "lb":{"terminal_names":["1","n"],"neutral_terminal":"n"}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1"],
             "v_magnitude":[230.0],"v_angle":[0.0]}},
         "shunt":{"lbg":{"bus":"lb","terminal_map":["n"],"G_1_1":5.0,"B_1_1":0.0}}}
        """; from_string=true)
        @test !("W.DOM.SHUNT_ON_GROUNDED" in codes(net3))
    end

    @testset "Redundancy — linecodes without impedance not duplicates" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        # two linecodes with no R/X data must not fingerprint as identical
        net["linecode"]["empty_a"] = Dict{String,Any}("i_max" => [100.0])
        net["linecode"]["empty_b"] = Dict{String,Any}("i_max" => [200.0])
        findings = Finding[]
        result = redundancy_check(net, findings)
        for ids in result["duplicate_linecodes"]["groups"]
            @test !("empty_a" in ids) && !("empty_b" in ids)
        end
    end

    # --------------------------------------------------------------------------
    # New analysis findings — self-loop, unloaded phase, PF default, spec semantics
    # --------------------------------------------------------------------------

    # Minimal 3-bus helper for semantic spec checks
    _spec_net(extra="") = parse_bmopf("""
    {"bus":{
        "src":{"terminal_names":["a","b","c","n"],"perfectly_grounded_terminals":["n"]},
        "b1": {"terminal_names":["a","b","c","n"],"perfectly_grounded_terminals":["n"]}},
     "voltage_source":{"vs":{"bus":"src","terminal_map":["a","b","c"],
         "v_magnitude":[11000.0,11000.0,11000.0],"v_angle":[0.0,-2.094,-4.189]}},
     "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1}},
     "line":{"l1":{"bus_from":"src","bus_to":"b1",
         "terminal_map_from":["a","b","c"],"terminal_map_to":["a","b","c"],
         "linecode":"lc","length":100.0}},
     "load":{"ld1":{"bus":"b1","terminal_map":["a","n"],
         "configuration":"SINGLE_PHASE","p_nom":[1e4],"q_nom":[0.0]}}
     $extra}
    """; from_string=true)

    @testset "Connectivity — E.CONN.SELF_LOOP on line" begin
        net = _spec_net()
        net["line"]["loop"] = Dict{String,Any}(
            "bus_from" => "b1", "bus_to" => "b1",
            "terminal_map_from" => ["a"], "terminal_map_to" => ["a"],
            "linecode" => "lc", "length" => 0.0)
        findings = Finding[]
        connectivity_analysis(net, findings)
        @test any(f -> f.code == "E.CONN.SELF_LOOP" && f.component_id == "loop", findings)
    end

    @testset "Connectivity — E.CONN.SELF_LOOP on switch" begin
        net = _spec_net()
        net["switch"] = Dict{String,Any}(
            "sw_loop" => Dict{String,Any}(
                "bus_from" => "b1", "bus_to" => "b1",
                "terminal_map_from" => ["a"], "terminal_map_to" => ["a"],
                "open_switch" => false))
        findings = Finding[]
        connectivity_analysis(net, findings)
        @test any(f -> f.code == "E.CONN.SELF_LOOP" && f.component_id == "sw_loop", findings)
    end

    @testset "Connectivity — no self-loop on normal line" begin
        net = _spec_net()
        findings = Finding[]
        connectivity_analysis(net, findings)
        @test !any(f -> f.code == "E.CONN.SELF_LOOP", findings)
    end

    @testset "Operational — I.OPS.UNLOADED_PHASE: phase without load" begin
        # b1 has phases a,b,c,n — only phase a has a load
        net = _spec_net()
        findings = Finding[]
        result = operational_analysis(net, findings)
        # phases b and c are unloaded
        unloaded = [f for f in findings if f.code == "I.OPS.UNLOADED_PHASE"]
        terminals = Set(f.detail["terminal"] for f in unloaded)
        @test "b" in terminals
        @test "c" in terminals
        @test !("a" in terminals)
        @test result["unloaded_phase_findings"] >= 2
    end

    @testset "Operational — no I.OPS.UNLOADED_PHASE when all phases loaded" begin
        # Start from base net and manually add b/c loads so the "load" key merges
        net = _spec_net()
        net["load"]["ld_b"] = Dict{String,Any}(
            "bus" => "b1", "terminal_map" => ["b","n"],
            "configuration" => "SINGLE_PHASE",
            "p_nom" => [1e4], "q_nom" => [0.0])
        net["load"]["ld_c"] = Dict{String,Any}(
            "bus" => "b1", "terminal_map" => ["c","n"],
            "configuration" => "SINGLE_PHASE",
            "p_nom" => [1e4], "q_nom" => [0.0])
        findings = Finding[]
        result = operational_analysis(net, findings)
        @test !any(f -> f.code == "I.OPS.UNLOADED_PHASE", findings)
        @test result["unloaded_phase_findings"] == 0
    end

    @testset "Diversity — I.DIV.LOAD_PF_DSS_DEFAULT near 0.88" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        # Force all loads to PF=0.88 (p=0.88, q=√(1-0.88²)=0.475)
        for (_, l) in net["load"]
            n = length(get(l, "p_nom", [0.0]))
            l["p_nom"] = fill(880.0, n)
            l["q_nom"] = fill(475.0, n)
        end
        findings = Finding[]
        diversity_analysis(net, findings)
        @test any(f -> f.code == "I.DIV.LOAD_PF_DSS_DEFAULT", findings)
    end

    @testset "Diversity — no I.DIV.LOAD_PF_DSS_DEFAULT when PF is varied" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        diversity_analysis(net, findings)
        # IEEE13 loads have diverse PF values — should not trigger
        @test !any(f -> f.code == "I.DIV.LOAD_PF_DSS_DEFAULT", findings)
    end

    @testset "Diversity — I.DIV.LOAD_UNIFORM_MODEL when all constant_power" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        for (_, l) in net["load"]; delete!(l, "model"); end   # all default constant_power
        findings = Finding[]
        diversity_analysis(net, findings)
        @test any(f -> f.code == "I.DIV.LOAD_UNIFORM_MODEL", findings)
    end

    @testset "Diversity — no I.DIV.LOAD_UNIFORM_MODEL when models vary" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        first(values(net["load"]))["model"] = "zip"   # introduce model diversity
        findings = Finding[]
        diversity_analysis(net, findings)
        @test !any(f -> f.code == "I.DIV.LOAD_UNIFORM_MODEL", findings)
    end

    @testset "Diversity — I.DIV.LOAD_UNIFORM_CONFIG when all same configuration" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        for (_, l) in net["load"]; l["configuration"] = "WYE"; end
        findings = Finding[]
        diversity_analysis(net, findings)
        @test any(f -> f.code == "I.DIV.LOAD_UNIFORM_CONFIG", findings)
    end

    @testset "Diversity — no I.DIV.LOAD_UNIFORM_CONFIG when configs vary" begin
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        for (_, l) in net["load"]; l["configuration"] = "WYE"; end
        first(values(net["load"]))["configuration"] = "DELTA"
        findings = Finding[]
        diversity_analysis(net, findings)
        @test !any(f -> f.code == "I.DIV.LOAD_UNIFORM_CONFIG", findings)
    end

    @testset "Spec — E.SPEC.DUPLICATE_TERMINAL in load" begin
        # WYE needs 4 terminals; supply 4 but with a duplicate phase so
        # arity is satisfied and the duplicate check fires
        net = _spec_net(""","load":{"bad":{"bus":"b1",
            "terminal_map":["a","a","c","n"],
            "configuration":"WYE",
            "p_nom":[1e4,1e4,1e4],"q_nom":[0.0,0.0,0.0]}}""")
        findings = Finding[]
        spec_conformance_check(net, findings)
        @test any(f -> f.code == "E.SPEC.DUPLICATE_TERMINAL" &&
                       f.component_id == "bad", findings)
    end

    @testset "Spec — I.SPEC.LOAD_PHASE_TO_PHASE: both terminals are phase" begin
        net = _spec_net(""","load":{"pp":{"bus":"b1",
            "terminal_map":["a","b"],
            "configuration":"SINGLE_PHASE",
            "p_nom":[1e4],"q_nom":[0.0]}}""")
        findings = Finding[]
        spec_conformance_check(net, findings)
        @test any(f -> f.code == "I.SPEC.LOAD_PHASE_TO_PHASE" &&
                       f.component_id == "pp", findings)
    end

    @testset "Spec — I.SPEC.LOAD_PHASE_TO_PHASE not raised for phase-to-neutral" begin
        net = _spec_net()   # ld1 is ["a","n"] — phase-to-neutral
        findings = Finding[]
        spec_conformance_check(net, findings)
        @test !any(f -> f.code == "I.SPEC.LOAD_PHASE_TO_PHASE" &&
                        f.component_id == "ld1", findings)
    end

    @testset "Spec — E.SPEC.WYE_MISSING_NEUTRAL: last terminal not neutral" begin
        net = _spec_net(""","load":{"wye_bad":{"bus":"b1",
            "terminal_map":["a","b","c","a"],
            "configuration":"WYE",
            "p_nom":[1e4,1e4,1e4],"q_nom":[0.0,0.0,0.0]}}""")
        findings = Finding[]
        spec_conformance_check(net, findings)
        @test any(f -> f.code == "E.SPEC.WYE_MISSING_NEUTRAL" &&
                       f.component_id == "wye_bad", findings)
    end

    @testset "Spec — E.SPEC.WYE_DUPLICATE_PHASE: duplicate phase in WYE" begin
        net = _spec_net(""","load":{"wye_dup":{"bus":"b1",
            "terminal_map":["a","a","c","n"],
            "configuration":"WYE",
            "p_nom":[1e4,1e4,1e4],"q_nom":[0.0,0.0,0.0]}}""")
        findings = Finding[]
        spec_conformance_check(net, findings)
        @test any(f -> f.code == "E.SPEC.WYE_DUPLICATE_PHASE" &&
                       f.component_id == "wye_dup", findings)
    end

    @testset "Spec — E.SPEC.DELTA_HAS_NEUTRAL: neutral terminal in DELTA" begin
        net = _spec_net(""","load":{"delta_bad":{"bus":"b1",
            "terminal_map":["a","n","c"],
            "configuration":"DELTA",
            "p_nom":[1e4,1e4,1e4],"q_nom":[0.0,0.0,0.0]}}""")
        findings = Finding[]
        spec_conformance_check(net, findings)
        @test any(f -> f.code == "E.SPEC.DELTA_HAS_NEUTRAL" &&
                       f.component_id == "delta_bad", findings)
    end

    @testset "Spec — E.SPEC.DELTA_DUPLICATE_PHASE: duplicate phase in DELTA" begin
        net = _spec_net(""","load":{"delta_dup":{"bus":"b1",
            "terminal_map":["a","a","c"],
            "configuration":"DELTA",
            "p_nom":[1e4,1e4,1e4],"q_nom":[0.0,0.0,0.0]}}""")
        findings = Finding[]
        spec_conformance_check(net, findings)
        @test any(f -> f.code == "E.SPEC.DELTA_DUPLICATE_PHASE" &&
                       f.component_id == "delta_dup", findings)
    end

    @testset "Spec — E.SPEC.DUPLICATE_TERMINAL in line terminal_map_from" begin
        net = _spec_net()
        net["line"]["bad_l"] = Dict{String,Any}(
            "bus_from" => "src", "bus_to" => "b1",
            "terminal_map_from" => ["a","a","c"],
            "terminal_map_to"   => ["a","b","c"],
            "linecode" => "lc", "length" => 50.0)
        findings = Finding[]
        spec_conformance_check(net, findings)
        @test any(f -> f.code == "E.SPEC.DUPLICATE_TERMINAL" &&
                       f.component_id == "bad_l", findings)
    end

    # --------------------------------------------------------------------------
    # LV1_14bus — real OpenDSS network integration test
    # Requires PowerModelsDistribution; skipped if not in the active load path.
    # To run with PMD: cd .. && julia --project=. -e '
    #   using Pkg; Pkg.develop(path="BMOPFTools"); include("BMOPFTools/test/runtests.jl")'
    # --------------------------------------------------------------------------
    @testset "LV1_14bus — OpenDSS integration" begin
        if !_HAS_PMD
            @test_skip "PowerModelsDistribution not in load path"
        else
            dss_master = joinpath(@__DIR__, "data", "LV", "LV1_14bus", "Master.dss")

            # Parse OpenDSS in 4-wire (un-reduced) mode and convert to BMOPF
            eng = parse_file(dss_master; kron_reduce=false)
            net = from_pmd(eng)
            @test net isa Dict{String,Any}

            @testset "Network structure" begin
                # Single 11 kV voltage source at B2577
                @test length(get(net, "voltage_source", Dict())) == 1

                # Single delta-wye transformer (11 kV → 433 V, Tx3170)
                xfmr = get(net, "transformer", Dict())
                @test haskey(xfmr, "delta_wye")
                @test length(xfmr["delta_wye"]) == 1
                tx = first(values(xfmr["delta_wye"]))
                @test tx["v_ref_from"] > tx["v_ref_to"]               # step-down
                @test tx["v_ref_from"] / tx["v_ref_to"] ≈ 11.0/0.433  rtol=0.02
                # per-winding T: from_pmd writes r/x_series_from/to; no legacy lumped fields
                @test haskey(tx, "r_series_from") && tx["r_series_from"] > 0
                @test haskey(tx, "x_series_from") && tx["x_series_from"] > 0
                @test !haskey(tx, "r_series") && !haskey(tx, "x_series")
                # spec arity: delta side 3 terminals, wye side 4 (incl. neutral)
                @test length(tx["terminal_map_from"]) == 3
                @test length(tx["terminal_map_to"])   == 4
                @test "n" in tx["terminal_map_to"]

                # slack cost priced on the voltage source (no phantom generator)
                @test !any(get(g, "_slack", false) for g in values(get(net, "generator", Dict())))
                vs = first(values(net["voltage_source"]))
                @test haskey(vs, "cost")
                @test length(vs["cost"]) == 3        # one per phase (neutral excluded)
                @test !haskey(vs, "p_max")           # unbounded slack

                # 2-terminal loads are SINGLE_PHASE per spec
                @test all(l["configuration"] == "SINGLE_PHASE"
                          for (_, l) in net["load"]
                          if length(l["terminal_map"]) == 2)

                # 9 cable segments (lines.dss), each with a 4-wire linecode
                @test length(get(net, "line", Dict())) == 9

                # 4 closed switches (Switch_4072_OPEN is commented out)
                switches = get(net, "switch", Dict())
                @test length(switches) == 4
                @test all(!get(sw, "open_switch", true) for sw in values(switches))

                # 2 single-phase loads (Ld3313 at B3230.1.4 and Ld3433 at B2656.2.4)
                @test length(get(net, "load", Dict())) == 2

                # 3 neutral-to-earth reactors from Groundings.dss → BMOPF shunts
                shunts = get(net, "shunt", Dict())
                @test length(shunts) == 3
                # Each grounding shunt must have G (conductance) and B (susceptance)
                @test all(haskey(sh, "G_1_1") && haskey(sh, "B_1_1")
                          for sh in values(shunts))

                # Linecodes derived from 4×4 R/X/C matrices
                lcs = get(net, "linecode", Dict())
                @test !isempty(lcs)
                lc = first(values(lcs))
                @test haskey(lc, "R_series_1_1")
                @test haskey(lc, "X_series_1_1")
            end

            @testset "Analysis" begin
                report = analyze(net)
                @test report isa SummaryReport

                # Two voltage levels: HV (~11 kV or per-phase equivalent) and LV (~433 V)
                @test report.results[:voltage_levels]["n_levels"] == 2

                # Fully connected radial topology (15 buses, 14 edges: 1 xfmr + 9 lines + 4 switches)
                conn = report.results[:connectivity]
                @test conn["is_connected"] == true
                @test conn["is_radial"]    == true

                # Inventory counts
                inv = report.results[:inventory]
                @test inv["load"]["total"]        == 2
                @test inv["transformer"]["total"] == 1
                @test inv["switch"]["total"]      == 4
                @test inv["shunt"]["total"]       == 3

                # Clean network: no ERRORs from completeness, schema, or voltage checks
                @test isempty(errors(report))

                # Regression: switch tee points must not be reported as mergeable
                # line groups (b1133/b2327 carry switches)
                @test !any(f -> f.code == "I.RED.MERGEABLE_LINES", report.findings)

                # Regression: a standard 11kV/433V step-down must not trip the
                # transformer ratio plausibility check
                @test !any(f -> f.code == "W.DOM.XFMR_RATIO_OOB", report.findings)

                # Regression: converter output must conform to the BMOPF schema
                @test !any(f -> f.code == "I.SCHEMA.UNKNOWN_FIELDS" &&
                                startswith(string(f.component_type), "transformer"),
                           report.findings)

                # Integrity: all references resolve; both galvanic islands
                # (MV source side, LV side behind the transformer) referenced
                integ = report.results[:integrity]
                @test integ["n_reference_issues"] == 0
                @test integ["n_galvanic_islands"] == 2
                @test integ["n_without_reference"] == 0

                # Provenance: real 4-wire data with explicit groundings —
                # no Kron flag, no floating neutrals, LV level is 4-wire
                prov = report.results[:provenance]
                @test prov["grounding"]["convention"] == "explicit"
                @test prov["grounding"]["n_floating"] == 0
                @test !any(f -> f.code == "I.PROV.KRON_LIKELY", report.findings)
                lv_levels = [info for (_, info) in prov["wires_by_level"]
                             if info["is_lv"]]
                @test !isempty(lv_levels) && all(l -> l["wires"] == "4-wire", lv_levels)
            end
        end
    end

    # -----------------------------------------------------------------------
    # write_bmopf JSON validity
    # -----------------------------------------------------------------------
    include("write_bmopf_tests.jl")

    # -----------------------------------------------------------------------
    # Network simplification
    # -----------------------------------------------------------------------
    include("simplify_tests.jl")

    # -----------------------------------------------------------------------
    # Solution profiling — no solver required
    # -----------------------------------------------------------------------
    include("solution_profiling_tests.jl")

    # -----------------------------------------------------------------------
    # OPF extension — requires JuMP and Ipopt
    # -----------------------------------------------------------------------
    @testset "OPF extension" begin
        if !_HAS_JUMP_IPOPT
            @test_skip "JuMP/Ipopt not in load path — skipping OPF tests"
        else
            include("opf_tests.jl")
            include("pmd_opf_port_tests.jl")
        end
    end

    # -----------------------------------------------------------------------
    # Power-flow comparison — BMOPF vs OpenDSS reference solver
    # Requires JuMP, Ipopt, PowerModelsDistribution, and OpenDSSDirect.
    # -----------------------------------------------------------------------
    @testset "Augmentation" begin
        include("augmentation_tests.jl")
    end

    @testset "Fix case" begin
        include("fix_tests.jl")
    end

    @testset "DER placement" begin
        include("der_placement_tests.jl")
    end

    @testset "Inverter placement" begin
        include("inverter_placement_tests.jl")
    end

    @testset "Load models — validation and analysis" begin
        mk(extra) = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "b1":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
                      "vpn_min":[207.0,207.0,207.0]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":0.001,"R_series_2_2":0.001,"R_series_3_3":0.001}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1","terminal_map_from":["1","2","3","n"],
             "terminal_map_to":["1","2","3","n"],"linecode":"lc","length":100.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0]$extra}}}
        """; from_string=true)

        codes(net) = (f = Finding[]; domain_rules_check(net, f);
                      [x.code for x in f if startswith(x.code, "E.LOAD") ||
                                            startswith(x.code, "W.LOAD") ||
                                            startswith(x.code, "I.LOAD")])

        # clean ZIP load → no load findings
        @test isempty(codes(mk(""","model":"zip","v_nom":[230.0],
            "alpha_z":[0.4],"alpha_i":[0.3],"alpha_p":[0.3],
            "beta_z":[0.4],"beta_i":[0.3],"beta_p":[0.3]""")))

        # ZIP coefficients not summing to 1 → warning
        @test "W.LOAD.ZIP_SUM" in codes(mk(""","model":"zip","v_nom":[230.0],
            "alpha_z":[0.9],"alpha_i":[0.3],"alpha_p":[0.3]"""))

        # zip/exponential without v_nom → error
        @test "E.LOAD.VNOM_MISSING" in codes(mk(""","model":"zip",
            "alpha_z":[0.4],"alpha_i":[0.3],"alpha_p":[0.3]"""))

        # v_nom wrong arity (2 for a 3-phase WYE) → error
        @test "E.LOAD.VNOM_ARITY" in codes(mk(""","model":"zip","v_nom":[230.0,230.0],
            "alpha_z":[0.4],"alpha_i":[0.3],"alpha_p":[0.3]"""))

        # exponent outside (0,2) → info; negative → warning
        @test "I.LOAD.GAMMA_RANGE" in codes(mk(""","model":"exponential","v_nom":[230.0],
            "gamma_p":[0.5],"gamma_q":[2.5]"""))
        @test "W.LOAD.GAMMA_NEGATIVE" in codes(mk(""","model":"exponential","v_nom":[230.0],
            "gamma_p":[-0.5]"""))

        # discriminator vs stray fields
        @test "W.LOAD.MODEL_MIXED" in codes(mk(""","model":"zip","v_nom":[230.0],
            "alpha_z":[0.4],"alpha_i":[0.3],"alpha_p":[0.3],"gamma_p":[1.0]"""))
        @test "I.LOAD.MODEL_FIELDS_IGNORED" in codes(mk(""","model":"constant_power",
            "alpha_z":[0.4]"""))

        # ── analysis: ZIP-equivalent exponential + nonlinear-without-vmin ────
        afindings(net) = (f = Finding[]; load_model_analysis(net, f); f)

        # integer exponents {0,1,2} → flagged ZIP-equivalent
        net_ze = mk(""","model":"exponential","v_nom":[230.0],"gamma_p":[2.0],"gamma_q":[2.0]""")
        res_ze = (f = Finding[]; r = load_model_analysis(net_ze, f); (r, f))
        @test "I.LOAD.EXP_ZIP_EQUIVALENT" in [x.code for x in res_ze[2]]
        @test res_ze[1]["by_model"]["exponential"] == 1
        @test res_ze[1]["n_voltage_dependent"] == 1

        # non-integer exponent → NOT ZIP-equivalent
        net_ni = mk(""","model":"exponential","v_nom":[230.0],"gamma_p":[1.5]""")
        @test !("I.LOAD.EXP_ZIP_EQUIVALENT" in [x.code for x in afindings(net_ni)])

        # voltage-dependent load on a bus WITHOUT a lower voltage bound → warning
        net_nv = parse_bmopf("""
        {"bus":{"src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
                "b1":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
             "v_magnitude":[230.0,230.0,230.0],"v_angle":[0.0,-2.0944,2.0944]}},
         "linecode":{"lc":{"R_series_1_1":0.001,"R_series_2_2":0.001,"R_series_3_3":0.001}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1","terminal_map_from":["1","2","3","n"],
             "terminal_map_to":["1","2","3","n"],"linecode":"lc","length":100.0}},
         "load":{"ld":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
             "p_nom":[1000.0,1000.0,1000.0],"q_nom":[0.0,0.0,0.0],
             "model":"zip","v_nom":[230.0],
             "alpha_z":[1.0],"alpha_i":[0.0],"alpha_p":[0.0],
             "beta_z":[1.0],"beta_i":[0.0],"beta_p":[0.0]}}}
        """; from_string=true)
        @test "W.LOAD.NL_NO_VMIN" in [x.code for x in afindings(net_nv)]
        # the vpn_min bus above must NOT trigger it
        @test !("W.LOAD.NL_NO_VMIN" in [x.code for x in afindings(net_ze)])

        # schema_check layer-2: new load model fields are not catalogued as unknown
        fz = Finding[]
        rz = schema_check(net_ze, fz)
        @test !haskey(get(rz, "unknown_fields_by_type", Dict()), "load")
    end

    @testset "Power-flow comparison vs OpenDSS" begin
        if !_HAS_JUMP_IPOPT || !_HAS_ODS
            @test_skip "Requires JuMP, Ipopt, and OpenDSSDirect"
        else
            include("powerflow_comparison_tests.jl")
        end
    end

    include("admittance_tests.jl")

    # -----------------------------------------------------------------------
    # Regulator subtypes: galvanic zone/island and neutral-continuity topology
    # -----------------------------------------------------------------------
    include("regulator_topology_tests.jl")

    @testset "Config — TOML thresholds" begin
        # Defaults load and match the historical hardcoded values.
        cfg = load_config()
        @test cfg["domain_rules"]["pf_min"] == 0.70
        @test cfg["domain_rules"]["cost_max_per_kwh"] == 10.0
        @test cfg["thermal"]["tolerance"] == 0.15
        @test cfg["provenance"]["grounding"]["earth_solid_ohm"] == 1.0
        @test cfg["provenance"]["dss_defaults"]["normamps"] == 400.0

        # The module consts are sourced from the config.
        @test BMOPFTools._THERMAL_TOLERANCE == cfg["thermal"]["tolerance"]
        @test BMOPFTools._EARTH_SOLID_OHM == cfg["provenance"]["grounding"]["earth_solid_ohm"]
        @test BMOPFTools._DSS_NORMAMPS == cfg["provenance"]["dss_defaults"]["normamps"]
        @test BMOPFTools._DEFAULT_THRESHOLDS["pf_min"] == cfg["domain_rules"]["pf_min"]

        # A user file deep-merges over the defaults: only the named key changes.
        mktemp() do path, io
            write(io, "[domain_rules]\npf_min = 0.95\n"); close(io)
            user = load_config(path)
            @test user["domain_rules"]["pf_min"] == 0.95
            @test user["domain_rules"]["xfmr_ratio_max"] == cfg["domain_rules"]["xfmr_ratio_max"]
        end

        # A nonexistent path errors rather than silently using defaults.
        @test_throws ArgumentError load_config(joinpath(tempdir(), "no_such_bmopf_cfg.toml"))

        # domain_rules_check honours an overridden threshold: a load whose PF is
        # below the raised pf_min is flagged, but not under the default.
        net = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        net["load"]["load_632"]["p_nom"] = [800.0, 800.0, 800.0]
        net["load"]["load_632"]["q_nom"] = [600.0, 600.0, 600.0]   # PF = 0.8
        f_def = Finding[]
        domain_rules_check(net, f_def)   # default pf_min 0.70 → no flag
        @test !any(f -> f.code == "W.DOM.LOAD_PF_LOW" && f.component_id == "load_632", f_def)
        f_strict = Finding[]
        domain_rules_check(net, f_strict; thresholds=Dict{String,Any}(
            "pf_min" => 0.90, "cost_max_per_kwh" => 10.0, "r_series_min" => 1e-9,
            "xfmr_ratio_max" => 1000.0, "z_line_min_ohm" => 1e-4,
            "z_spread_info" => 1e3, "z_spread_warn" => 1e5))
        @test any(f -> f.code == "W.DOM.LOAD_PF_LOW" && f.component_id == "load_632", f_strict)
    end

end  # @testset "BMOPFTools"
