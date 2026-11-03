# Neutral-only branches carry no phase conductor, so they do not carry a nominal
# voltage level between buses. The witness is a synthetic 4-wire wye feeder with
# a center-tap service transformer whose primary and secondary neutrals are
# bonded by a neutral-only line, as multi-grounded service drops are commonly
# exported. It is built inline so the test owns every value.
using Test, BMOPFTools, JSON3

function _bond_witness(; neutral="4", conventions=true)
    p(t) = t == "4" ? neutral : t
    tm(ts...) = [p(t) for t in ts]
    net = Dict{String,Any}(
        "name" => "neutral bond witness",
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names" => tm("1", "2", "3", "4"),
                                      "perfectly_grounded_terminals" => tm("4")),
            "pad" => Dict{String,Any}("terminal_names" => tm("1", "2", "3", "4")),
            "sec" => Dict{String,Any}("terminal_names" => tm("1", "2", "4"),
                                      "perfectly_grounded_terminals" => tm("4"))),
        "voltage_source" => Dict{String,Any}("grid" => Dict{String,Any}(
            "bus" => "src", "terminal_map" => tm("1", "2", "3"),
            "v_magnitude" => [7621.0, 7621.0, 7621.0],
            "v_angle" => [0.0, -2pi / 3, 2pi / 3])),
        "linecode" => Dict{String,Any}(
            "mv" => Dict{String,Any}(
                "R_series_1_1" => 2e-4, "R_series_2_2" => 2e-4, "R_series_3_3" => 2e-4,
                "R_series_4_4" => 4e-4, "X_series_1_1" => 4e-4, "X_series_2_2" => 4e-4,
                "X_series_3_3" => 4e-4, "X_series_4_4" => 4e-4),
            "bond" => Dict{String,Any}("R_series_1_1" => 1e-3, "X_series_1_1" => 1e-4)),
        "line" => Dict{String,Any}(
            "mv" => Dict{String,Any}("bus_from" => "src", "bus_to" => "pad",
                "terminal_map_from" => tm("1", "2", "3", "4"),
                "terminal_map_to" => tm("1", "2", "3", "4"),
                "linecode" => "mv", "length" => 500.0),
            "bond" => Dict{String,Any}("bus_from" => "pad", "bus_to" => "sec",
                "terminal_map_from" => tm("4"), "terminal_map_to" => tm("4"),
                "linecode" => "bond", "length" => 1.0)),
        "transformer" => Dict{String,Any}("center_tap" => Dict{String,Any}(
            "ct" => Dict{String,Any}("bus_from" => "pad", "bus_to" => "sec",
                "terminal_map_from" => tm("1", "4"), "terminal_map_to" => tm("1", "4", "2"),
                "v_nom_from" => 7621.0, "v_nom_to" => 120.0, "s_rating" => 25e3,
                "r_series_from" => 20.0, "r_series_to" => 0.01,
                "x_series_from" => 40.0, "x_series_to" => 0.01))),
        "load" => Dict{String,Any}("house" => Dict{String,Any}(
            "bus" => "sec", "terminal_map" => tm("1", "2"),
            "configuration" => "SINGLE_PHASE", "p_nom" => [3000.0], "q_nom" => [500.0])))
    conventions && (net["terminal_conventions"] = Dict{String,Any}(
        "phase" => ["1", "2", "3"], "neutral" => [neutral]))
    net
end

const _LEVEL_CODES = ("E.VOLT.LEVEL_MISMATCH", "E.VOLT.LINE_CROSSING",
                      "W.PROV.LINE_BRIDGES_VOLTAGE_LEVELS")

_level_findings(net) = [f for f in analyze(net).findings if f.code in _LEVEL_CODES]

@testset "Neutral-only branches and voltage levels" begin
    parse(net) = BMOPFTools.parse_bmopf(JSON3.write(net); from_string=true)

    @testset "Neutral bond beside a center-tap transformer" begin
        net = parse(_bond_witness())
        @test BMOPFTools._neutral_only_branch(net["line"]["bond"], BMOPFTools._index_roles(net))
        @test !BMOPFTools._neutral_only_branch(net["line"]["mv"], BMOPFTools._index_roles(net))
        report = analyze(net)
        @test isempty([f for f in report.findings if f.code in _LEVEL_CODES])
        vmap = report.results[:voltage_levels]["bus_voltage_map"]
        @test vmap["pad"] ≈ 7621.0
        @test vmap["sec"] ≈ 120.0
        @test isempty(report.results[:voltage_levels]["unassigned_buses"])
        @test isempty(report.results[:voltage_levels]["neutral_only_buses"])
        @test !any(f -> f.code == "W.VOLT.XFMR_RATIO", report.findings)
        @test BMOPFTools._assign_nominal_voltages(net)["sec"] ≈ 120.0
    end

    @testset "Phase-carrying branches between levels remain findings" begin
        net = _bond_witness()
        for key in ("terminal_map_from", "terminal_map_to")
            net["line"]["bond"][key] = ["1"]
        end
        codes = Set(f.code for f in _level_findings(parse(net)))
        @test codes == Set(_LEVEL_CODES)
        # A mixed phase/neutral map still carries a phase conductor.
        net = _bond_witness()
        for key in ("terminal_map_from", "terminal_map_to")
            net["line"]["bond"][key] = ["1", "4"]
        end
        @test "E.VOLT.LINE_CROSSING" in Set(f.code for f in _level_findings(parse(net)))
    end

    @testset "Role resolution boundaries" begin
        # The fallback naming convention resolves "n" as the neutral.
        @test isempty(_level_findings(parse(_bond_witness(neutral="n", conventions=false))))
        # Earth-role labels are return conductors too.
        net = _bond_witness()
        net["terminal_conventions"]["neutral"] = String[]
        net["terminal_conventions"]["earth"] = ["4"]
        @test isempty(_level_findings(parse(net)))
        # An unclassified label is not assumed to be a return conductor.
        net = _bond_witness()
        net["terminal_conventions"]["neutral"] = String[]
        @test !isempty(_level_findings(parse(net)))
        # A label declared as both phase and neutral stays phase-carrying.
        net = _bond_witness()
        push!(net["terminal_conventions"]["phase"], "4")
        @test !isempty(_level_findings(parse(net)))
        # A malformed declaration is reported by validation; analysis does not throw.
        net = parse(_bond_witness())
        net["terminal_conventions"] = Dict{String,Any}("neutral" => "4")
        @test !BMOPFTools._neutral_only_branch(net["line"]["bond"], BMOPFTools._index_roles(net))
        @test voltage_level_analysis(net, BMOPFTools.Finding[]) isa Dict
    end

    @testset "Neutral-only switch" begin
        net = _bond_witness()
        bond = pop!(net["line"], "bond")
        delete!(bond, "linecode"); delete!(bond, "length")
        bond["open_switch"] = false
        net["switch"] = Dict{String,Any}("bond" => bond)
        @test isempty(_level_findings(parse(net)))
    end

    @testset "Return-only buses reached through neutral-only lines" begin
        net = _bond_witness()
        net["bus"]["electrode"] = Dict{String,Any}("terminal_names" => ["4"],
            "perfectly_grounded_terminals" => ["4"])
        net["line"]["ground"] = Dict{String,Any}("bus_from" => "sec", "bus_to" => "electrode",
            "terminal_map_from" => ["4"], "terminal_map_to" => ["4"],
            "linecode" => "bond", "length" => 3.0)
        result = voltage_level_analysis(parse(net), BMOPFTools.Finding[])
        @test result["neutral_only_buses"] == ["electrode"]
        @test !haskey(result["bus_voltage_map"], "electrode")
        @test isempty(result["unassigned_buses"])
        # A bus with phase terminals fed only through a neutral bond has no phase supply.
        net = _bond_witness()
        net["bus"]["orphan"] = Dict{String,Any}("terminal_names" => ["1", "4"])
        net["line"]["orphan_bond"] = Dict{String,Any}("bus_from" => "sec", "bus_to" => "orphan",
            "terminal_map_from" => ["4"], "terminal_map_to" => ["4"],
            "linecode" => "bond", "length" => 3.0)
        findings = BMOPFTools.Finding[]
        result = voltage_level_analysis(parse(net), findings)
        @test result["unassigned_buses"] == ["orphan"]
        @test isempty(result["neutral_only_buses"])
        @test any(f -> f.code == "W.VOLT.UNASSIGNED", findings)
    end

    @testset "Serialization" begin
        net = parse(_bond_witness())
        path = joinpath(mktempdir(), "bond.json")
        write_bmopf(net, path)
        roundtrip = BMOPFTools.parse_bmopf(path)
        @test roundtrip["line"]["bond"]["terminal_map_from"] == ["4"]
        @test isempty(_level_findings(roundtrip))
        result = voltage_level_analysis(roundtrip, BMOPFTools.Finding[])
        restored = JSON3.read(JSON3.write(result), Dict{String,Any})
        @test restored["neutral_only_buses"] == String[]
        @test restored["bus_voltage_map"]["sec"] ≈ 120.0
    end
end
