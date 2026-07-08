# Terminal-role conventions (phase / neutral / earth)
#
# Covers the case-wide `terminal_conventions` block: schema acceptance, the
# resolver, ingestion (explicit vs inferred + the numeric-4 alias interaction),
# the validation findings raised on the inference fallback and on inconsistent
# declarations, always-on export, and — gated on JuMP/Ipopt — an end-to-end
# solve proving a non-"n" neutral label is honoured by the OPF.

@testset "Terminal-role conventions" begin

    # A minimal, schema-valid single-phase network. `neutral_label` lets each
    # test pick the neutral terminal-name label used throughout.
    mininet(neutral_label; with_conventions=true) = begin
        n = neutral_label
        d = Dict{String,Any}(
            "name" => "tc_mini",
            "meta" => Dict{String,Any}("\$schema" => BMOPFTools._BMOPF_SCHEMA_URI),
            "bus" => Dict{String,Any}(
                "sourcebus" => Dict{String,Any}(
                    "terminal_names" => ["1", n],
                    "perfectly_grounded_terminals" => [n]),
                "bus1" => Dict{String,Any}(
                    "terminal_names" => ["1", n],
                    "perfectly_grounded_terminals" => [n],
                    "v_min" => [900.0], "v_max" => [999.0])),
            "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                "bus" => "sourcebus", "terminal_map" => ["1"],
                "v_magnitude" => [1000.0], "v_angle" => [0.0])),
            "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
                "R_series_1_1" => 0.5, "X_series_1_1" => 0.0)),
            "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                "bus_from" => "sourcebus", "bus_to" => "bus1",
                "terminal_map_from" => ["1"], "terminal_map_to" => ["1"],
                "linecode" => "lc", "length" => 1.0)),
            "load" => Dict{String,Any}("ld1" => Dict{String,Any}(
                "bus" => "bus1", "terminal_map" => ["1", n],
                "configuration" => "SINGLE_PHASE",
                "p_nom" => [100000.0], "q_nom" => [0.0])))
        with_conventions && (d["terminal_conventions"] =
            Dict{String,Any}("phase" => ["1"], "neutral" => [n], "earth" => String[]))
        d
    end

    @testset "resolver: explicit vs inferred" begin
        # Explicit block is authoritative and not flagged inferred.
        net = mininet("ne")
        r = BMOPFTools._terminal_roles(net)
        @test r.inferred == false
        @test r.neutral == Set(["ne"])
        @test r.phase == Set(["1"])
        @test isempty(r.earth)

        # No block → inference from the naming convention, flagged inferred.
        net2 = mininet("n"; with_conventions=false)
        r2 = BMOPFTools._terminal_roles(net2)
        @test r2.inferred == true
        @test r2.neutral == Set(["n"])
        @test r2.phase == Set(["1"])
    end

    @testset "materialisation stamps per-bus neutral (custom label)" begin
        net = mininet("ne")
        BMOPFTools._materialize_terminal_roles!(net)
        @test net["bus"]["bus1"]["neutral_terminal"] == "ne"
        @test BMOPFTools._neutral_terminal(net["bus"]["bus1"]) == "ne"
        # Inferred "n" case must NOT pollute bus dicts.
        net2 = mininet("n"; with_conventions=false)
        BMOPFTools._materialize_terminal_roles!(net2)
        @test !haskey(net2["bus"]["bus1"], "neutral_terminal")
    end

    @testset "schema acceptance / rejection" begin
        findings = Finding[]
        res = BMOPFTools.schema_check(mininet("n"), findings)
        @test get(res, "spec_version", "") == "draft"   # layer-1 actually ran
        @test !any(f -> startswith(f.code, "E.SCHEMA"), findings)
        # Unknown sub-key flagged (terminal_conventions is additionalProperties:false).
        bad = mininet("n")
        bad["terminal_conventions"]["bogus"] = ["x"]
        f2 = Finding[]
        BMOPFTools.schema_check(bad, f2)
        @test any(f -> f.code == "I.SCHEMA.UNKNOWN_FIELDS", f2)
    end

    @testset "validation findings" begin
        # Inference fallback raises W.CONV.TERMINAL_ROLES_INFERRED.
        f = Finding[]
        BMOPFTools.domain_rules_check(mininet("n"; with_conventions=false), f)
        @test any(x -> x.code == "W.CONV.TERMINAL_ROLES_INFERRED", f)

        # Explicit block → no inference finding.
        f2 = Finding[]
        BMOPFTools.domain_rules_check(mininet("ne"), f2)
        @test !any(x -> x.code == "W.CONV.TERMINAL_ROLES_INFERRED", f2)

        # Overlap between role lists is an error.
        ov = mininet("n")
        ov["terminal_conventions"]["neutral"] = ["1"]   # "1" is also a phase
        f3 = Finding[]
        BMOPFTools.domain_rules_check(ov, f3)
        @test any(x -> x.code == "E.CONV.ROLE_OVERLAP", f3)

        # Unclassified bus terminal → warning + treated as phase.
        un = mininet("n")
        un["bus"]["bus1"]["terminal_names"] = ["1", "n", "s2"]   # s2 in no role list
        f4 = Finding[]
        BMOPFTools.domain_rules_check(un, f4)
        @test any(x -> x.code == "W.CONV.TERMINAL_UNCLASSIFIED", f4)

        # More than one neutral on a bus → warning.
        mn = mininet("n")
        mn["terminal_conventions"]["neutral"] = ["n", "n2"]
        mn["bus"]["bus1"]["terminal_names"] = ["1", "n", "n2"]
        f5 = Finding[]
        BMOPFTools.domain_rules_check(mn, f5)
        @test any(x -> x.code == "W.CONV.MULTIPLE_NEUTRALS", f5)
    end

    @testset "numeric-4 alias interaction" begin
        # Raw numeric neutral "4" with NO conventions → aliased to "n" as before.
        raw = """
        {"bus":{"b":{"terminal_names":[1,4]}},
         "voltage_source":{"s":{"bus":"b","terminal_map":[1]}}}
        """
        net = parse_bmopf(raw; from_string=true)
        @test "n" in net["bus"]["b"]["terminal_names"]
        @test !("4" in net["bus"]["b"]["terminal_names"])

        # With an explicit convention declaring "4" as neutral → "4" is kept.
        raw2 = """
        {"bus":{"b":{"terminal_names":[1,4]}},
         "voltage_source":{"s":{"bus":"b","terminal_map":[1]}},
         "terminal_conventions":{"phase":["1"],"neutral":["4"],"earth":[]}}
        """
        net2 = parse_bmopf(raw2; from_string=true)
        @test "4" in net2["bus"]["b"]["terminal_names"]
        @test !("n" in net2["bus"]["b"]["terminal_names"])
        @test net2["bus"]["b"]["neutral_terminal"] == "4"
    end

    @testset "export always writes terminal_conventions" begin
        # Case without a block gains one on write (promoted from inference).
        net = mininet("n"; with_conventions=false)
        json = let buf = IOBuffer(); write_bmopf(net, buf); String(take!(buf)); end
        reparsed = parse_bmopf(json; from_string=true)
        @test haskey(reparsed, "terminal_conventions")
        @test reparsed["terminal_conventions"]["neutral"] == ["n"]
        # Reload no longer fires the inference finding.
        f = Finding[]
        BMOPFTools.domain_rules_check(reparsed, f)
        @test !any(x -> x.code == "W.CONV.TERMINAL_ROLES_INFERRED", f)

        # A declared block round-trips verbatim.
        net2 = mininet("ne")
        json2 = let buf = IOBuffer(); write_bmopf(net2, buf); String(take!(buf)); end
        rp2 = parse_bmopf(json2; from_string=true)
        @test rp2["terminal_conventions"]["neutral"] == ["ne"]
        @test rp2["terminal_conventions"]["phase"] == ["1"]
    end

    if _HAS_JUMP_IPOPT
        @testset "OPF honours a non-\"n\" neutral label" begin
            V_exp = (1000.0 + sqrt(1000.0^2 - 4 * 0.5 * 100000.0)) / 2
            base = solve_opf(mininet("n"))
            @test base["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test base["bus"]["bus1"]["1"]["vm"] ≈ V_exp atol = 0.01

            custom = solve_opf(mininet("ne"))
            @test custom["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test custom["bus"]["bus1"]["1"]["vm"] ≈ V_exp atol = 0.01
        end
    end
end
