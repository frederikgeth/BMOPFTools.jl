# Inline ABSOLUTE line impedances (Ω/S on the line object, replacing a
# linecode reference). Units by location: linecode = per metre × length,
# line = section total, never scaled. Covers consistency rules, validation
# findings, round-trip, simplify merging, PMD export, and (gated) PF parity
# in both per-unit modes.

# 4-wire fixture: the same network expressed with a linecode+length and with
# the equivalent inline totals.
function _inline_fixture(; inline::Bool)
    lc_pm = Dict{String,Any}(   # simple decoupled per-metre code, 4 conductors
        "R_series_1_1" => 4e-4, "R_series_2_2" => 4e-4,
        "R_series_3_3" => 4e-4, "R_series_4_4" => 4e-4,
        "X_series_1_1" => 3e-4, "X_series_2_2" => 3e-4,
        "X_series_3_3" => 3e-4, "X_series_4_4" => 3e-4)
    len = 500.0
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}(
                "terminal_names" => ["a", "b", "c", "n"],
                "perfectly_grounded_terminals" => ["n"]),
            "b1" => Dict{String,Any}(
                "terminal_names" => ["a", "b", "c", "n"],
                "perfectly_grounded_terminals" => ["n"])),
        "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
            "bus" => "src", "terminal_map" => ["a", "b", "c"],
            "v_magnitude" => [2401.8, 2401.8, 2401.8],
            "v_angle" => [0.0, -2.0944, 2.0944])),
        "load" => Dict{String,Any}("ld" => Dict{String,Any}(
            "bus" => "b1", "terminal_map" => ["a", "b", "c", "n"],
            "configuration" => "WYE",
            "p_nom" => [200e3, 150e3, 100e3],
            "q_nom" => [60e3, 40e3, 20e3])))
    line = Dict{String,Any}(
        "bus_from" => "src", "bus_to" => "b1",
        "terminal_map_from" => ["a", "b", "c", "n"],
        "terminal_map_to"   => ["a", "b", "c", "n"])
    if inline
        for (k, v) in lc_pm
            line[k] = v * len            # section totals [Ω]
        end
        line["length"] = len             # descriptive only
    else
        net["linecode"] = Dict{String,Any}("lc" => lc_pm)
        line["linecode"] = "lc"
        line["length"]   = len
    end
    net["line"] = Dict{String,Any}("l1" => line)
    net
end

@testset "Inline absolute line impedances" begin

    @testset "consistency: exactly one impedance source" begin
        # both sources → error finding
        net = _inline_fixture(inline=true)
        net["linecode"] = Dict{String,Any}("lc" => Dict{String,Any}(
            "R_series_1_1" => 1e-4, "X_series_1_1" => 1e-4))
        net["line"]["l1"]["linecode"] = "lc"
        codes = [f.code for f in analyze(net).findings]
        @test "E.INT.LINE_IMPEDANCE_SOURCE" in codes

        # neither source → error finding
        net2 = _inline_fixture(inline=false)
        delete!(net2["line"]["l1"], "linecode")
        codes2 = [f.code for f in analyze(net2).findings]
        @test "E.INT.LINE_IMPEDANCE_SOURCE" in codes2

        # clean fixtures carry no source error
        for inline in (true, false)
            net3 = _inline_fixture(inline=inline)
            @test !("E.INT.LINE_IMPEDANCE_SOURCE" in
                    [f.code for f in analyze(net3).findings])
        end
    end

    @testset "physics and dimension checks reach inline matrices" begin
        # non-reciprocal inline matrix → E.PROV.NONRECIPROCAL on :line
        net = _inline_fixture(inline=true)
        net["line"]["l1"]["R_series_1_2"] = 0.05    # asymmetric (no 2_1)... rebuilt below
        net["line"]["l1"]["R_series_2_1"] = -0.05
        fs = analyze(net).findings
        hit = [f for f in fs if f.code == "E.PROV.NONRECIPROCAL"]
        @test !isempty(hit) && hit[1].component_type == :line

        # dimension mismatch vs terminal maps — a hard error (no silent truncation)
        net2 = _inline_fixture(inline=true)
        net2["line"]["l1"]["terminal_map_from"] = ["a", "b", "c"]
        net2["line"]["l1"]["terminal_map_to"]   = ["a", "b", "c"]
        @test "E.INT.LINE_DIM_MISMATCH" in [f.code for f in analyze(net2).findings]

        # implied per-length plausibility: values far too small for totals
        # over 500 m (e.g. per-metre data pasted in as totals, then some)
        net3 = _inline_fixture(inline=true)
        for k in collect(keys(net3["line"]["l1"]))
            if startswith(k, "R_series_") || startswith(k, "X_series_")
                net3["line"]["l1"][k] /= 2000.0
            end
        end
        @test "W.DOM.LINE_IMPLIED_PER_LENGTH" in
              [f.code for f in analyze(net3).findings]
    end

    @testset "round trip and schema" begin
        net = _inline_fixture(inline=true)
        path = joinpath(mktempdir(), "inline.json")
        write_bmopf(net, path)
        net2 = parse_bmopf(path)
        @test net2["line"]["l1"]["R_series_1_1"] ≈ 0.2
        report = analyze(net2)
        @test !("I.SCHEMA.UNKNOWN_FIELDS" in [f.code for f in report.findings])
        @test report.results[:schema]["jsonschema_valid"] == true
    end

    @testset "simplify: inline+inline merge sums matrices; mixed skips" begin
        net = _inline_fixture(inline=true)
        # split l1 into two 250 m halves through a pass-through bus m
        l = net["line"]["l1"]
        net["bus"]["m"] = Dict{String,Any}(
            "terminal_names" => ["a", "b", "c", "n"])
        half = deepcopy(l)
        for k in keys(half)
            (startswith(k, "R_series_") || startswith(k, "X_series_")) &&
                (half[k] /= 2)
        end
        half["length"] = 250.0
        h2 = deepcopy(half)
        half["bus_to"] = "m"
        h2["bus_from"] = "m"
        net["line"] = Dict{String,Any}("h1" => half, "h2" => h2)

        merged = merge_series_lines(net)
        lines = collect(values(merged["line"]))
        @test length(lines) == 1
        @test lines[1]["R_series_1_1"] ≈ l["R_series_1_1"]
        @test lines[1]["X_series_4_4"] ≈ l["X_series_4_4"]
        @test lines[1]["length"] ≈ 500.0

        # mixed inline/linecode at the junction is not merged
        net2 = _inline_fixture(inline=true)
        net2["bus"]["m"] = Dict{String,Any}(
            "terminal_names" => ["a", "b", "c", "n"])
        i1 = deepcopy(net2["line"]["l1"]); i1["bus_to"] = "m"
        lc_line = Dict{String,Any}(
            "bus_from" => "m", "bus_to" => "b1",
            "terminal_map_from" => ["a", "b", "c", "n"],
            "terminal_map_to"   => ["a", "b", "c", "n"],
            "linecode" => "lc", "length" => 250.0)
        net2["linecode"] = Dict{String,Any}("lc" => Dict{String,Any}(
            "R_series_1_1" => 4e-4, "X_series_1_1" => 3e-4))
        net2["line"] = Dict{String,Any}("i1" => i1, "l2" => lc_line)
        merged2 = merge_series_lines(net2)
        @test length(merged2["line"]) == 2
    end

    @testset "PMD export: inline line becomes a 1 m section of totals" begin
        net = _inline_fixture(inline=true)
        pmd = to_pmd(net)
        pline = first(values(pmd["line"]))
        @test pline["length"] == 1.0
        @test pline["rs"][1, 1] ≈ 0.2
        @test !haskey(pline, "linecode")
    end

    if @isdefined(_HAS_JUMP_IPOPT) && _HAS_JUMP_IPOPT
        @testset "PF parity: inline totals ≡ linecode×length, both pu modes" begin
            net_lc = _inline_fixture(inline=false)
            net_il = _inline_fixture(inline=true)
            for pu in (true, false)
                r1 = solve_pf(net_lc; per_unit=pu)
                r2 = solve_pf(net_il; per_unit=pu)
                @test r1["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
                @test r2["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
                for t in ("a", "b", "c", "n")
                    @test r1["bus"]["b1"][t]["vm"] ≈ r2["bus"]["b1"][t]["vm"] atol = 1e-6
                end
            end
        end
    end
end
