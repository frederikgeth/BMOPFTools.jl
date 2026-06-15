using Test
using BMOPFTools
using Dates

const _HAS_PMD = !isnothing(Base.identify_package("PowerModelsDistribution"))
if _HAS_PMD
    @eval using PowerModelsDistribution
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
      "v_min": 2020.0,
      "v_max": 2540.0
    },
    "650": {
      "terminal_names": ["1","2","3","n"],
      "perfectly_grounded_terminals": ["n"],
      "v_min": 2020.0,
      "v_max": 2540.0
    },
    "632": {
      "terminal_names": ["1","2","3","n"],
      "v_min": 2020.0,
      "v_max": 2540.0
    },
    "634": {
      "terminal_names": ["1","2","3","n"],
      "perfectly_grounded_terminals": ["n"],
      "v_min": 100.0,
      "v_max": 130.0
    },
    "671": {
      "terminal_names": ["1","2","3","n"],
      "v_min": 2020.0,
      "v_max": 2540.0
    },
    "611": {
      "terminal_names": ["3","n"],
      "v_min": 2020.0,
      "v_max": 2540.0
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
      "cost": 0.12
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

    @testset "Validation — redundancy" begin
        net      = parse_bmopf(IEEE13_FIXTURE; from_string=true)
        findings = Finding[]
        result   = redundancy_check(net, findings)

        # zero load fixture has load_zero with p=q=0
        @test result["zero_loads"]["n"] >= 1
        @test "load_zero" in result["zero_loads"]["ids"]

        # unused linecodes: lc601, lc605, lc607 are all used, none unused
        @test result["unused_linecodes"]["n"] == 0
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
        net["bus"]["632"]["v_min"] = 2600.0   # > v_max of 2540
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

    @testset "Transformer impedance unit conversion" begin
        # PMD rw/xsc (p.u.) → BMOPF r_series/x_series (Ω) → PMD must round-trip
        eng = Dict{String,Any}(
            "settings" => Dict{String,Any}(
                "voltage_scale_factor" => 1000.0,   # PMD kV convention
                "power_scale_factor"   => 1000.0),  # PMD kVA convention
            "bus" => Dict{String,Any}(
                "a" => Dict{String,Any}("terminals" => [1,2,3]),
                "b" => Dict{String,Any}("terminals" => [1,2,3])),
            "voltage_source" => Dict{String,Any}(
                "src" => Dict{String,Any}(
                    "bus" => "a", "connections" => [1,2,3],
                    "vm" => [2.4, 2.4, 2.4], "va" => [0.0, -120.0, 120.0])),
            "transformer" => Dict{String,Any}(
                "tx1" => Dict{String,Any}(
                    "bus" => ["a", "b"],
                    "configuration" => ["WYE", "WYE"],
                    "connections" => [[1,2,3],[1,2,3]],
                    "vm_nom" => [4.16, 0.48],
                    "sm_nom" => [500.0, 500.0],   # 500 kVA in PMD scale
                    "rw" => [0.01, 0.01],
                    "xsc" => [0.06])))

        net = from_pmd(eng)
        tx  = net["transformer"]["single_phase"]["tx1"]
        # s_rating must be in VA
        @test tx["s_rating"] ≈ 500_000.0
        # r_series_from = rw * V² / S = 0.01 * 4160² / 500e3 ≈ 0.346 Ω
        @test tx["r_series_from"] ≈ 0.01 * 4160.0^2 / 500_000.0
        @test tx["r_series_to"]   ≈ 0.01 * 480.0^2  / 500_000.0
        # leakage reactance split evenly across windings
        @test tx["x_series_from"] ≈ 0.03 * 4160.0^2 / 500_000.0
        @test tx["x_series_to"]   ≈ 0.03 * 480.0^2  / 500_000.0

        # reverse direction recovers p.u. values
        eng2 = to_pmd(net)
        @test eng2["transformer"]["tx1"]["rw"]  ≈ [0.01, 0.01]
        @test eng2["transformer"]["tx1"]["xsc"] ≈ [0.06]
    end

    @testset "Delta-wye transformer — spec wye-side lumped impedance" begin
        # Per TF spec, delta_wye carries a single r_series/x_series on the
        # wye windings; both PMD winding impedances refer to the same base
        # Z_base = v_ref_wye²/S, so the lumped value is (rw₁+rw₂)·Z_base.
        eng = Dict{String,Any}(
            "settings" => Dict{String,Any}(
                "voltage_scale_factor" => 1000.0,
                "power_scale_factor"   => 1000.0),
            "bus" => Dict{String,Any}(
                "mv" => Dict{String,Any}("terminals" => [1,2,3]),
                "lv" => Dict{String,Any}("terminals" => [1,2,3,4])),
            "voltage_source" => Dict{String,Any}(
                "src" => Dict{String,Any}(
                    "bus" => "mv", "connections" => [1,2,3],
                    "vm" => [6.35, 6.35, 6.35], "va" => [0.0, -120.0, 120.0])),
            "transformer" => Dict{String,Any}(
                "txdw" => Dict{String,Any}(
                    "bus" => ["mv", "lv"],
                    "configuration" => ["DELTA", "WYE"],
                    "connections" => [[1,2,3],[1,2,3,4]],
                    "vm_nom" => [11.0, 0.433],
                    "sm_nom" => [100.0, 100.0],
                    "rw" => [0.004, 0.006],
                    "xsc" => [0.04])))

        net = from_pmd(eng; add_slack_generator=false)
        tx  = net["transformer"]["delta_wye"]["txdw"]
        z_base = 433.0^2 / 100_000.0
        @test tx["r_series"] ≈ 0.010 * z_base
        @test tx["x_series"] ≈ 0.040 * z_base
        @test !haskey(tx, "r_series_from")

        # reverse: even split of the lumped resistance, total reactance
        eng2 = to_pmd(net)
        @test eng2["transformer"]["txdw"]["rw"]  ≈ [0.005, 0.005]
        @test eng2["transformer"]["txdw"]["xsc"] ≈ [0.04]
    end

    @testset "from_pmd — explicit slack generator" begin
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
        @test haskey(net["generator"], "slack_source")
        g = net["generator"]["slack_source"]
        @test g["bus"] == "src"
        @test g["configuration"] == "WYE"
        @test g["terminal_map"] == ["1","2","3","n"]
        @test g["cost"] ≈ [0.25, 0.25, 0.25]
        @test get(g, "_slack", false) == true
        @test !haskey(g, "p_min") && !haskey(g, "p_max")

        # opt-out
        net2 = from_pmd(eng; add_slack_generator=false)
        @test !haskey(net2, "generator")
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
        # letter convention: a/b/c/n
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}(
                "x" => Dict{String,Any}("terminal_names" => ["a","b","c","n"]),
                "y" => Dict{String,Any}("terminal_names" => ["1","2","3","4"]),
                "z" => Dict{String,Any}("terminal_names" => ["1","2","3"])))
        findings = Finding[]
        inv = inventory_analysis(net, findings)
        # a/b/c (+n) → 3-phase; 1/2/3/4 → 3-phase (4 = neutral); 1/2/3 → 3-phase
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
                # spec: delta_wye carries a single wye-side r_series/x_series;
                # the xhl from Transformers.dss must survive conversion
                @test haskey(tx, "r_series") && tx["r_series"] > 0
                @test haskey(tx, "x_series") && tx["x_series"] > 0
                @test !haskey(tx, "r_series_from") && !haskey(tx, "x_series_from")
                # spec arity: delta side 3 terminals, wye side 4 (incl. neutral)
                @test length(tx["terminal_map_from"]) == 3
                @test length(tx["terminal_map_to"])   == 4
                @test "n" in tx["terminal_map_to"]

                # explicit slack generator at the source bus
                gens = get(net, "generator", Dict())
                slack = [g for (_, g) in gens if get(g, "_slack", false)]
                @test length(slack) == 1
                @test slack[1]["bus"] == first(values(net["voltage_source"]))["bus"]
                @test slack[1]["configuration"] == "WYE"
                @test length(slack[1]["terminal_map"]) == 4
                @test haskey(slack[1], "cost")
                @test !haskey(slack[1], "p_max")     # unbounded slack

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
    # from_dss — requires the powerio CLI (eigenergy/powerio, PR #82)
    # Set BMOPFTOOLS_POWERIO_PATH or put `powerio` on PATH.
    # -----------------------------------------------------------------------
    _POWERIO_BIN = get(ENV, "BMOPFTOOLS_POWERIO_PATH", Sys.which("powerio"))
    @testset "from_dss — powerio integration" begin
        if isnothing(_POWERIO_BIN)
            @test_skip "powerio binary not found — set BMOPFTOOLS_POWERIO_PATH or put powerio on PATH"
        else
            dss_master = joinpath(@__DIR__, "data", "LV", "LV1_14bus", "Master.dss")

            net = from_dss(dss_master; powerio=_POWERIO_BIN)
            @test net isa Dict{String,Any}

            @testset "Network structure" begin
                # Voltage source
                @test length(get(net, "voltage_source", Dict())) == 1

                # Lines — 9 cable segments
                @test length(get(net, "line", Dict())) == 9

                # Loads — 2 single-phase loads
                @test length(get(net, "load", Dict())) == 2

                # Buses exist
                @test !isempty(get(net, "bus", Dict()))

                # Conversion warnings are surfaced (units is a common one)
                @test haskey(net, "_meta")
                @test haskey(net["_meta"], "powerio_warnings")
                @test net["_meta"]["powerio_source"] == abspath(dss_master)

                # Network name set from path when not in JSON
                @test !isempty(net["name"])
            end

            @testset "Analysis runs cleanly" begin
                report = analyze(net)
                @test report isa SummaryReport
                conn = report.results[:connectivity]
                @test conn["is_connected"] == true
                @test conn["is_radial"]    == true
            end

            @testset "from_dss vs from_pmd agreement" begin
                if !_HAS_PMD
                    @test_skip "PowerModelsDistribution not available for cross-parser comparison"
                else
                    eng     = parse_file(dss_master; kron_reduce=false)
                    net_pmd = from_pmd(eng)
                    net_dss = from_dss(dss_master; powerio=_POWERIO_BIN)

                    # Top-level component counts must agree
                    for key in ("bus", "line", "load", "voltage_source", "linecode")
                        n_pmd = length(get(net_pmd, key, Dict()))
                        n_dss = length(get(net_dss, key, Dict()))
                        @test n_pmd == n_dss  broken=(n_pmd != n_dss)
                    end

                    # Both parsers must find the same buses by name
                    pmd_buses = Set(keys(net_pmd["bus"]))
                    dss_buses = Set(keys(net_dss["bus"]))
                    @test pmd_buses == dss_buses  broken=(pmd_buses != dss_buses)
                end
            end

            @testset "powerio_version" begin
                v = powerio_version(; powerio=_POWERIO_BIN)
                @test startswith(v, "powerio ")
            end
        end
    end

    # -----------------------------------------------------------------------
    # OPF extension — requires JuMP and Ipopt
    # -----------------------------------------------------------------------
    @testset "OPF extension" begin
        if !_HAS_JUMP_IPOPT
            @test_skip "JuMP/Ipopt not in load path — skipping OPF tests"
        else
            include("opf_tests.jl")
        end
    end

end  # @testset "BMOPFTools"
