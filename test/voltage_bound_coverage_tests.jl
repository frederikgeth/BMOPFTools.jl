# Voltage-bound coverage counts every bus voltage-magnitude bound kind of the
# data model (v_*, vpn_*, vpp_*, vpos_*). Unbalance and neutral-shift limits do
# not bound the phase voltage magnitude. The synthetic two-bus witness is built
# inline.
using Test, BMOPFTools, JSON3

function _bound_witness(; bounds=Dict("vpn_min" => 0.95, "vpn_max" => 1.05))
    net = Dict{String,Any}(
        "name" => "voltage bound coverage witness",
        "terminal_conventions" => Dict{String,Any}("phase" => ["1", "2", "3"],
                                                   "neutral" => ["4"]),
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names" => ["1", "2", "3", "4"],
                                      "perfectly_grounded_terminals" => ["4"]),
            "load_bus" => Dict{String,Any}("terminal_names" => ["1", "2", "3", "4"])),
        "voltage_source" => Dict{String,Any}("grid" => Dict{String,Any}(
            "bus" => "src", "terminal_map" => ["1", "2", "3"],
            "v_magnitude" => [7621.0, 7621.0, 7621.0],
            "v_angle" => [0.0, -2pi / 3, 2pi / 3])),
        "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
            ("R_series_$(i)_$(i)" => 2e-4 for i in 1:4)...,
            ("X_series_$(i)_$(i)" => 4e-4 for i in 1:4)...)),
        "line" => Dict{String,Any}("mv" => Dict{String,Any}("bus_from" => "src",
            "bus_to" => "load_bus", "terminal_map_from" => ["1", "2", "3", "4"],
            "terminal_map_to" => ["1", "2", "3", "4"], "linecode" => "lc", "length" => 500.0)),
        "load" => Dict{String,Any}("l" => Dict{String,Any}("bus" => "load_bus",
            "terminal_map" => ["1", "2", "3", "4"], "configuration" => "WYE",
            "p_nom" => [1e4, 1e4, 1e4], "q_nom" => [1e3, 1e3, 1e3])))
    for b in values(net["bus"]), (field, scale) in bounds
        b[field] = field == "vuf_max" ? scale :
                   startswith(field, "vpos") || startswith(field, "vneg") ||
                   startswith(field, "vzero") || field == "vn_max" ? scale * 7621.0 :
                   fill(scale * (startswith(field, "vpp") ? sqrt(3) : 1.0) * 7621.0, 3)
    end
    net
end

const _NO_BOUNDS_SUGGESTION = "no voltage magnitude bounds on any bus"

@testset "Voltage-bound coverage counts every magnitude bound kind" begin
    parse(net) = BMOPFTools.parse_bmopf(JSON3.write(net); from_string=true)
    suggests_no_bounds(report) = any(s -> startswith(s, _NO_BOUNDS_SUGGESTION),
        report.results[:benchmark]["suggestions"])

    @testset "Phase-to-neutral bounds only" begin
        report = analyze(parse(_bound_witness()))
        @test !any(f -> f.code == "I.PRE.NO_VOLT_BOUNDS", report.findings)
        vb = report.results[:preflight]["voltage_bound_tightness"]
        @test vb["n_without_bounds"] == 0
        @test vb["n_with_lower_bound"] == 2 && vb["n_with_upper_bound"] == 2
        @test vb["n_with_bounds_by_kind"] == Dict("v" => 0, "vpn" => 2, "vpp" => 0, "vpos" => 0)
        @test report.results[:diversity]["bus"]["pct_with_voltage_bounds"] == 100.0
        bench = report.results[:benchmark]
        @test bench["pct_voltage_magnitude_bounds"] == 100.0
        @test bench["pct_v_bounds"] == 0.0
        @test !suggests_no_bounds(report)
        # The richer-bound suggestion is satisfied by vpn bounds.
        @test !any(s -> startswith(s, "no phase-to-neutral or sequence"), bench["suggestions"])
    end

    @testset "Each magnitude bound kind counts on its own" begin
        for bounds in (Dict("v_min" => 0.95), Dict("vpp_max" => 1.05),
                       Dict("vpos_min" => 0.95, "vpos_max" => 1.05))
            report = analyze(parse(_bound_witness(bounds=bounds)))
            @test !any(f -> f.code == "I.PRE.NO_VOLT_BOUNDS", report.findings)
            @test !suggests_no_bounds(report)
            @test report.results[:diversity]["bus"]["pct_with_voltage_bounds"] == 100.0
        end
        vb = analyze(parse(_bound_witness(bounds=Dict("vpp_max" => 1.05)))).results[:preflight]["voltage_bound_tightness"]
        @test vb["n_with_lower_bound"] == 0 && vb["n_with_upper_bound"] == 2
    end

    @testset "Unbounded buses are still reported" begin
        report = analyze(parse(_bound_witness(bounds=Dict{String,Float64}())))
        f = only(f for f in report.findings if f.code == "I.PRE.NO_VOLT_BOUNDS")
        @test sort(f.detail["buses"]) == ["load_bus", "src"]
        @test suggests_no_bounds(report)
        @test report.results[:diversity]["bus"]["pct_with_voltage_bounds"] == 0.0
        # Unbalance and neutral-shift limits do not bound the phase magnitude.
        report = analyze(parse(_bound_witness(bounds=Dict("vneg_max" => 0.02,
            "vzero_max" => 0.02, "vn_max" => 0.01, "vuf_max" => 0.02))))
        @test any(f -> f.code == "I.PRE.NO_VOLT_BOUNDS", report.findings)
        @test suggests_no_bounds(report)
        # A partially bounded case lists only the unbounded bus.
        net = _bound_witness()
        delete!(net["bus"]["load_bus"], "vpn_min"); delete!(net["bus"]["load_bus"], "vpn_max")
        f = only(f for f in analyze(parse(net)).findings if f.code == "I.PRE.NO_VOLT_BOUNDS")
        @test f.detail["buses"] == ["load_bus"]
    end

    @testset "Phase-to-ground uniformity flags stay phase-to-ground" begin
        report = analyze(parse(_bound_witness()))
        @test !any(f -> f.code in ("I.DIV.BUS_UNIFORM_VMIN", "I.DIV.BUS_UNIFORM_VMAX"),
                   report.findings)
        report = analyze(parse(_bound_witness(bounds=Dict("v_min" => 0.95, "v_max" => 1.05))))
        @test any(f -> f.code == "I.DIV.BUS_UNIFORM_VMIN", report.findings)
    end

    @testset "Serialization and rendering" begin
        path = joinpath(mktempdir(), "vpn.json")
        write_bmopf(parse(_bound_witness()), path)
        report = analyze(BMOPFTools.parse_bmopf(path))
        @test !any(f -> f.code == "I.PRE.NO_VOLT_BOUNDS", report.findings)
        vb = JSON3.read(JSON3.write(report.results[:preflight]["voltage_bound_tightness"]),
                        Dict{String,Any})
        @test vb["n_with_bounds_by_kind"]["vpn"] == 2
        md = joinpath(mktempdir(), "report.md")
        render(report, md)
        text = read(md, String)
        @test occursin("| Buses with any \\|V\\| bound | 100.0% |", text)
        @test occursin("| Buses with v\\_min/v\\_max (phase-to-ground) | 0.0% |", text)
    end
end
