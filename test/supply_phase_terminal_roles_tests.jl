# Supply phase counts and source rotation classes use the case's resolved
# terminal roles. A declared neutral such as "4" is a return conductor, not a
# phase. The synthetic 4-wire wye witness is built inline.
using Test, BMOPFTools, JSON3

function _declared_neutral_witness(; phases=["1", "2", "3"], neutral="4", conventions=true)
    all4 = vcat(phases, [neutral])
    net = Dict{String,Any}(
        "name" => "declared neutral label witness",
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names" => copy(all4),
                                      "perfectly_grounded_terminals" => [neutral]),
            "load_bus" => Dict{String,Any}("terminal_names" => copy(all4))),
        "voltage_source" => Dict{String,Any}("grid" => Dict{String,Any}(
            "bus" => "src", "terminal_map" => copy(phases),
            "v_magnitude" => fill(7621.0, length(phases)),
            "v_angle" => [0.0, -2pi / 3, 2pi / 3][1:length(phases)])),
        "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
            ("R_series_$(i)_$(i)" => 2e-4 for i in eachindex(all4))...,
            ("X_series_$(i)_$(i)" => 4e-4 for i in eachindex(all4))...)),
        "line" => Dict{String,Any}("mv" => Dict{String,Any}("bus_from" => "src",
            "bus_to" => "load_bus", "terminal_map_from" => copy(all4),
            "terminal_map_to" => copy(all4), "linecode" => "lc", "length" => 500.0)),
        "load" => Dict{String,Any}("l" => Dict{String,Any}("bus" => "load_bus",
            "terminal_map" => copy(all4), "configuration" => length(phases) == 1 ?
                "SINGLE_PHASE" : "WYE",
            "p_nom" => fill(1e4, length(phases)), "q_nom" => fill(1e3, length(phases)))))
    conventions && (net["terminal_conventions"] = Dict{String,Any}(
        "phase" => ["1", "2", "3"], "neutral" => [neutral]))
    net
end

_codes(net) = [f.code for f in analyze(net).findings]
const _EXCEEDS = "W.PROV.PHASE_COUNT_EXCEEDS_SUPPLY"

@testset "Supply phase counts use resolved terminal roles" begin
    parse(net) = BMOPFTools.parse_bmopf(JSON3.write(net); from_string=true)

    @testset "Declared neutral is not a phase" begin
        net = parse(_declared_neutral_witness())
        report = analyze(net)
        @test !any(f -> f.code == _EXCEEDS, report.findings)
        @test report.results[:connectivity]["supply_phase_consistency"]["n"] == 0
        # A source map that also lists the neutral still supplies three phases.
        net = _declared_neutral_witness()
        vs = net["voltage_source"]["grid"]
        vs["terminal_map"] = ["1", "2", "3", "4"]
        vs["v_magnitude"] = [7621.0, 7621.0, 7621.0, 0.0]
        vs["v_angle"] = [0.0, -2pi / 3, 2pi / 3, 0.0]
        report = analyze(parse(net))
        @test !any(f -> f.code == _EXCEEDS, report.findings)
        @test report.results[:provenance]["voltage_source_sequence"]["arrangements"] ==
              Dict("grid" => "positive")
    end

    @testset "Single-phase source with a declared neutral" begin
        net = _declared_neutral_witness(phases=["1"])
        vs = net["voltage_source"]["grid"]
        vs["terminal_map"] = ["1", "4"]
        vs["v_magnitude"] = [7621.0, 0.0]; vs["v_angle"] = [0.0, 0.0]
        codes = _codes(parse(net))
        @test !(_EXCEEDS in codes)
        # The neutral angle is not a second phase of a zero-sequence profile.
        @test !("W.PROV.SOURCE_ZERO_SEQUENCE" in codes)
    end

    @testset "Genuine phase-count excess is still reported" begin
        net = _declared_neutral_witness(phases=["1"])
        for b in values(net["bus"])
            b["terminal_names"] = ["1", "2", "3", "4"]
        end
        net["line"]["mv"]["terminal_map_from"] = ["1", "2", "3", "4"]
        net["line"]["mv"]["terminal_map_to"] = ["1", "2", "3", "4"]
        report = analyze(parse(net))
        f = only(f for f in report.findings if f.code == _EXCEEDS)
        @test f.detail["supplied_phases"] == 1
        @test f.detail["offending_buses"] == ["load_bus", "src"]
        # A real zero-sequence source profile is still flagged.
        net = _declared_neutral_witness()
        net["voltage_source"]["grid"]["v_angle"] = [0.0, 0.0, 0.0]
        @test "W.PROV.SOURCE_ZERO_SEQUENCE" in _codes(parse(net))
    end

    @testset "Role resolution boundaries" begin
        # Naming-convention fallback is unchanged.
        @test !(_EXCEEDS in _codes(parse(_declared_neutral_witness(
            phases=["a", "b", "c"], neutral="n", conventions=false))))
        # Earth-role labels are returns too.
        net = _declared_neutral_witness()
        net["terminal_conventions"]["neutral"] = String[]
        net["terminal_conventions"]["earth"] = ["4"]
        @test !(_EXCEEDS in _codes(parse(net)))
        # A label declared both phase and neutral, or unclassified, is counted.
        net = _declared_neutral_witness()
        push!(net["terminal_conventions"]["phase"], "4")
        @test _EXCEEDS in _codes(parse(net))
        net = _declared_neutral_witness()
        net["terminal_conventions"]["neutral"] = String[]
        @test _EXCEEDS in _codes(parse(net))
        # A malformed declaration uses the previous naming fallback without throwing.
        net = parse(_declared_neutral_witness())
        net["terminal_conventions"] = Dict{String,Any}("neutral" => "4")
        is_return = BMOPFTools._return_label_predicate(net)
        @test is_return("n", nothing) && !is_return("4", nothing)
        @test connectivity_analysis(net, BMOPFTools.Finding[])["supply_phase_consistency"]["n"] == 1
    end

    @testset "Serialization" begin
        net = parse(_declared_neutral_witness())
        path = joinpath(mktempdir(), "wye4.json")
        write_bmopf(net, path)
        roundtrip = BMOPFTools.parse_bmopf(path)
        @test roundtrip["terminal_conventions"]["neutral"] == ["4"]
        @test !(_EXCEEDS in _codes(roundtrip))
        net = _declared_neutral_witness(phases=["1"])
        for b in values(net["bus"])
            b["terminal_names"] = ["1", "2", "3", "4"]
        end
        net["line"]["mv"]["terminal_map_from"] = ["1", "2", "3", "4"]
        net["line"]["mv"]["terminal_map_to"] = ["1", "2", "3", "4"]
        f = only(f for f in analyze(parse(net)).findings if f.code == _EXCEEDS)
        @test JSON3.read(JSON3.write(f.detail), Dict{String,Any}) == f.detail
    end
end
