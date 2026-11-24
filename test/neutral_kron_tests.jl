# Explicit-neutral Kron reduction (src/network/neutral_kron.jl), ported from
# PowerOptLab.jl test/kron_reduction_tests.jl (commit d1f217f0).
using Test
using JSON3
using LinearAlgebra
using BMOPFTools

const _NK_HAS_ODS = try
    @eval using OpenDSSDirect, JuMP, Ipopt
    true
catch
    false
end

function _nk_fixture()
    z = Dict{String,Any}()
    R = [1.0 0.1 0.2; 0.1 1.1 0.15; 0.2 0.15 0.9]
    X = [2.0 0.2 0.1; 0.2 2.1 0.12; 0.1 0.12 1.8]
    for i in 1:3, j in 1:3
        z["R_series_$(i)_$(j)"] = R[i,j]
        z["X_series_$(i)_$(j)"] = X[i,j]
    end
    Dict{String,Any}(
        "terminal_conventions"=>Dict{String,Any}("phase"=>["a","b"],"neutral"=>["r"],"earth"=>String[]),
        "bus"=>Dict("f"=>Dict{String,Any}("terminal_names"=>["a","b","r"],"perfectly_grounded_terminals"=>["r"]),
                     "t"=>Dict{String,Any}("terminal_names"=>["a","b","r"],"perfectly_grounded_terminals"=>["r"],
                                           "v_min"=>[90.0,90.0,0.0],"v_max"=>[130.0,130.0,0.0],"vpn_min"=>[100.0,100.0],"vpn_max"=>[120.0,120.0],"vn_max"=>5.0)),
        "linecode"=>Dict("lc"=>merge(z,Dict{String,Any}("i_max"=>[10.0,11.0,12.0],"s_max"=>[20.0,21.0,22.0]))),
        "line"=>Dict("l"=>Dict{String,Any}("bus_from"=>"f","bus_to"=>"t","terminal_map_from"=>["a","b","r"],"terminal_map_to"=>["a","b","r"],"linecode"=>"lc","length"=>2.0,"i_max"=>[1.0,2.0,3.0],"s_max"=>[10.0,11.0,12.0])),
        "voltage_source"=>Dict("s"=>Dict{String,Any}("bus"=>"f","terminal_map"=>["a","b","r"],"v_magnitude"=>[120.0,120.0,0.0],"v_angle"=>[0.0,-2.0,0.0])),
        "load"=>Dict("d"=>Dict{String,Any}("bus"=>"t","terminal_map"=>["a","b","r"],"configuration"=>"WYE","p_nom"=>[1.0,2.0],"q_nom"=>[0.1,0.2])),
        "switch"=>Dict("sw"=>Dict{String,Any}("bus_from"=>"f","bus_to"=>"t","terminal_map_from"=>["a","r"],"terminal_map_to"=>["a","r"],"open_switch"=>false)),
        "shunt"=>Dict("g"=>Dict{String,Any}("bus"=>"t","terminal_map"=>["r"],"G_1_1"=>1.0,"B_1_1"=>0.0)),
    )
end

@testset "grounded capacitor is materialized as a phase-ground shunt" begin
    n = Dict{String,Any}("bus"=>Dict("b"=>Dict{String,Any}("terminal_names"=>["a","r"],"neutral_terminal"=>"r")),
        "capacitor"=>Dict("c"=>Dict{String,Any}("bus"=>"b","terminal_map"=>["a","r"],"configuration"=>"SINGLE_PHASE","q_rated"=>[10.0],"v_nom"=>100.0)))
    o = kron_reduce_neutrals(n)
    @test isempty(o["capacitor"])
    @test o["shunt"]["kron_grounded_cap_c"]["terminal_map"] == ["a"]
    @test o["shunt"]["kron_grounded_cap_c"]["B_1_1"] ≈ 1e-3
end

@testset "Kron reduction produces retained center-tap winding maps" begin
    net = Dict{String,Any}(
        "terminal_conventions" => Dict{String,Any}(
            "phase" => ["h", "x1", "x2"], "neutral" => ["n"]),
        "bus" => Dict(
            "hv" => Dict{String,Any}(
                "terminal_names" => ["h", "n"],
                "perfectly_grounded_terminals" => ["n"]),
            "lv" => Dict{String,Any}(
                "terminal_names" => ["x1", "n", "x2"],
                "perfectly_grounded_terminals" => ["n"])),
        "transformer" => Dict("center_tap" => Dict("ct" => Dict{String,Any}(
            "bus_from" => "hv", "bus_to" => "lv",
            "terminal_map_from" => ["h", "n"],
            "terminal_map_to" => ["x1", "n", "x2"],
            "v_nom_from" => 2400.0, "v_nom_to" => 120.0,
            "s_rating" => 25_000.0,
            "i_max_from" => [12.0, 12.0],
            "i_max_to" => [100.0, 30.0, 90.0],
            "r_neutral_from" => 0.1, "x_neutral_from" => 0.2,
            "r_neutral_to" => 0.3, "x_neutral_to" => 0.4))),
        "voltage_source" => Dict("source" => Dict{String,Any}(
            "bus" => "hv", "terminal_map" => ["h", "n"],
            "configuration" => "SINGLE_PHASE",
            "v_magnitude" => [2400.0, 0.0], "v_angle" => [0.0, 0.0])),
        "load" => Dict(
            "leg1" => Dict{String,Any}(
                "bus" => "lv", "terminal_map" => ["x1", "n"],
                "configuration" => "SINGLE_PHASE",
                "p_nom" => [4_000.0], "q_nom" => [500.0]),
            "leg2" => Dict{String,Any}(
                "bus" => "lv", "terminal_map" => ["x2", "n"],
                "configuration" => "SINGLE_PHASE",
                "p_nom" => [1_500.0], "q_nom" => [100.0])))

    out = kron_reduce_neutrals(net)
    ct = out["transformer"]["center_tap"]["ct"]
    @test ct["terminal_map_from"] == ["h"]
    @test ct["terminal_map_to"] == ["x1", "x2"]
    @test ct["i_max_from"] == [12.0]
    @test ct["i_max_to"] == [100.0, 90.0]
    for key in ("r_neutral_from", "x_neutral_from",
                "r_neutral_to", "x_neutral_to")
        @test !haskey(ct, key)
    end
    @test out["voltage_source"]["source"]["terminal_map"] == ["h"]
    @test out["load"]["leg1"]["terminal_map"] == ["x1"]
    @test out["load"]["leg2"]["terminal_map"] == ["x2"]
    changes = out["extras"]["kron_reduction"]["changes"]
    @test count(x -> haskey(x, "dropped_grounding"), changes) == 4
    @test kron_reduce_neutrals(out) == out
end

@testset "BMOPF explicit-neutral Kron reduction" begin
    net = _nk_fixture()
    for i in 1:3, j in 1:3
        net["linecode"]["lc"]["G_from_$(i)_$(j)"] = i == j ? 1e-6 : 2e-7
        net["linecode"]["lc"]["G_to_$(i)_$(j)"] = i == j ? 2e-6 : 3e-7
        net["linecode"]["lc"]["B_from_$(i)_$(j)"] = i == j ? 4e-6 : 1e-7
        net["linecode"]["lc"]["B_to_$(i)_$(j)"] = i == j ? 5e-6 : 2e-7
    end
    net["meta"] = Dict{String,Any}("\$schema" =>
        "https://raw.githubusercontent.com/frederikgeth/bmopf-report/main/draft_schema_and_networks/draft_bmopf_schema.json")
    original = deepcopy(net)
    out = kron_reduce_neutrals(net)
    @test net == original
    @test out["bus"]["t"]["terminal_names"] == ["a","b"]
    @test out["bus"]["t"]["v_min"] == [100.0,100.0]
    @test out["bus"]["t"]["v_max"] == [120.0,120.0]
    @test !haskey(out["bus"]["t"], "vn_max")
    @test out["line"]["l"]["terminal_map_to"] == ["a","b"]
    @test out["line"]["l"]["i_max"] == [1.0, 2.0]
    @test out["line"]["l"]["s_max"] == [10.0, 11.0]
    @test out["linecode"]["lc"]["i_max"] == [10.0, 11.0]
    @test out["linecode"]["lc"]["s_max"] == [20.0, 21.0]
    @test count(k -> startswith(k, "R_series_"), keys(out["linecode"]["lc"])) == 4
    @test out["linecode"]["lc"]["R_series_1_1"] ≈ real((1.0 + 2.0im) - (0.2 + 0.1im)^2 / (0.9 + 1.8im))
    @test isempty(out["shunt"])
    ground_change = only(filter(x -> get(x, "component", "") == "shunt/g",
                                out["extras"]["kron_reduction"]["changes"]))
    @test ground_change["original_values"]["G_1_1"] == 1.0
    @test ground_change["terminal_map"] == ["r"]
    @test out["switch"]["sw"]["terminal_map_from"] == ["a"]
    @test out["load"]["d"]["terminal_map"] == ["a","b"]
    @test !haskey(out["terminal_conventions"], "neutral") || isempty(out["terminal_conventions"]["neutral"])
    @test haskey(out["extras"]["kron_reduction"], "changes")
    @test any(get(x,"recovery_K_real",nothing) !== nothing for x in out["extras"]["kron_reduction"]["changes"])
    line_change = only(filter(x -> haskey(x, "linecode") && x["linecode"] == "lc",
                              out["extras"]["kron_reduction"]["changes"]))
    @test haskey(line_change, "neutral_shunt_rows")
    @test haskey(line_change["neutral_shunt_rows"], "G_from_neutral_row")
    @test kron_reduce_neutrals(out) == out
    findings = BMOPFTools.Finding[]
    schema_result = BMOPFTools.schema_check(out, findings)
    @test get(schema_result, "jsonschema_ran", false)
    @test get(schema_result, "jsonschema_valid", false)
    @test !any(f -> f.severity == BMOPFTools.ERROR, findings)

    text = kron_reduce_neutrals(net; as_json=true)
    reparsed = parse_bmopf(text; from_string=true)
    @test reparsed["bus"]["t"]["terminal_names"] == ["a","b"]
    @test !haskey(reparsed, "_meta") || haskey(reparsed["_meta"], "kron_reduction")
    reparsed_findings = BMOPFTools.Finding[]
    reparsed_schema = BMOPFTools.schema_check(reparsed, reparsed_findings)
    @test get(reparsed_schema, "jsonschema_ran", false)
    @test get(reparsed_schema, "jsonschema_valid", false)
    @test !any(f -> f.severity == BMOPFTools.ERROR, reparsed_findings)
end

@testset "Kron audits mixed neutral shunt projection" begin
    n = Dict{String,Any}(
        "bus" => Dict("b" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                               "neutral_terminal" => "n")),
        "shunt" => Dict("m" => Dict{String,Any}(
            "bus" => "b", "terminal_map" => ["a", "n"],
            "G_1_1" => 1.0, "G_1_2" => 0.1, "G_2_1" => 0.1, "G_2_2" => 2.0,
            "B_1_1" => 0.0, "B_1_2" => 0.2, "B_2_1" => 0.2, "B_2_2" => 0.0)))
    out = kron_reduce_neutrals(n)
    @test out["shunt"]["m"]["terminal_map"] == ["a"]
    change = only(filter(x -> get(x, "component", "") == "shunt/m",
                         out["extras"]["kron_reduction"]["changes"]))
    @test change["original_values"]["G_2_2"] == 2.0
    @test change["reason"] == "mixed neutral shunt projected onto implicit ground"
end

@testset "BMOPF Kron reduction audits restricted IBR neutral elimination" begin
    n = Dict{String,Any}("bus"=>Dict("b"=>Dict{String,Any}("terminal_names"=>["a","r"],"neutral_terminal"=>"r")),
        "ibr"=>Dict("i"=>Dict{String,Any}("bus"=>"b","terminal_map"=>["a","r"],"topology"=>"FOUR_LEG")))
    out = kron_reduce_neutrals(n)
    @test out["ibr"]["i"]["terminal_map"] == ["a"]
    # The reduction is recorded in this reducer's own provenance, not by
    # stamping a downstream formulation's private key onto the component.
    @test !any(startswith(String(k), "_l3f_") for k in keys(out["ibr"]["i"]))
    changes = out["_meta"]["kron_reduction"]["changes"]
    entry = only(c for c in changes
                 if c isa AbstractDict && get(c, "component", "") == "ibr/i")
    @test entry["reduced_neutral_leg"] == "FOUR_LEG"
    @test occursin("neutral-conductor limit", entry["reason"])

    limited = deepcopy(n)
    limited["ibr"]["i"]["i_max"] = [10.0, 5.0]
    @test_throws ArgumentError kron_reduce_neutrals(limited)
    controlled = deepcopy(n)
    controlled["ibr"]["i"]["neutral_current_control"] = "fixed"
    @test_throws ArgumentError kron_reduce_neutrals(controlled)
end

@testset "Kron removes a neutral-only switch using both bus roles" begin
    n = Dict{String,Any}(
        "bus" => Dict("f" => Dict{String,Any}("terminal_names" => ["a", "r"],
                                               "neutral_terminal" => "r"),
                       "t" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                               "neutral_terminal" => "n")),
        "switch" => Dict("g" => Dict{String,Any}(
            "bus_from" => "f", "bus_to" => "t",
            "terminal_map_from" => ["r"], "terminal_map_to" => ["n"],
            "open_switch" => false)))
    out = kron_reduce_neutrals(n)
    @test isempty(out["switch"])
    change = only(filter(x -> get(x, "component", "") == "switch/g",
                         out["_meta"]["kron_reduction"]["changes"]))
    @test change["original_values"]["terminal_map_from"] == ["r"]
    @test change["reason"] == "neutral-only switch is parallel to implicit ground"
end

@testset "Kron does not slice phase-semantic generator cost vectors" begin
    n = Dict{String,Any}(
        "bus" => Dict("b" => Dict{String,Any}("terminal_names" => ["a", "n"],
                                               "neutral_terminal" => "n")),
        "generator" => Dict("g" => Dict{String,Any}(
            "bus" => "b", "terminal_map" => ["a", "n"],
            "configuration" => "WYE", "cost" => [3.0, 4.0],
            "i_max" => [10.0, 11.0])))
    out = kron_reduce_neutrals(n)
    @test out["generator"]["g"]["terminal_map"] == ["a"]
    @test out["generator"]["g"]["cost"] == [3.0, 4.0]
    @test out["generator"]["g"]["i_max"] == [10.0]
end

@testset "Kron matrix shorthand and singular rejection" begin
    sparse = BMOPFTools._nk_matrix(Dict{String,Any}(
        "R_series_1_1" => 1.0, "R_series_1_3" => 0.2, "R_series_3_3" => 2.0),
        "R_series_")
    @test size(sparse) == (3, 3)
    @test sparse[2, 2] == 0.0
    @test sparse[3, 1] == 0.2
    n = Dict{String,Any}("bus"=>Dict("f"=>Dict{String,Any}("terminal_names"=>["a","n"],"perfectly_grounded_terminals"=>["n"]),
                                  "t"=>Dict{String,Any}("terminal_names"=>["a","n"],"perfectly_grounded_terminals"=>["n"])),
        "linecode"=>Dict("lc"=>Dict{String,Any}("R_series_1_1"=>1.0,"R_series_1_2"=>0.2,"R_series_2_2"=>2.0,"X_series_1_1"=>1.0,"X_series_2_2"=>2.0)),
        "line"=>Dict("l"=>Dict{String,Any}("bus_from"=>"f","bus_to"=>"t","terminal_map_from"=>["a","n"],"terminal_map_to"=>["a","n"],"linecode"=>"lc")))
    o = kron_reduce_neutrals(n)
    @test o["linecode"]["lc"]["R_series_1_1"] ≈ 0.99
    @test haskey(o["linecode"]["lc"], "R_series_1_1")
    # BMOPFTools gives a stored full entry precedence over its reciprocal;
    # absent off-diagonals are zero rather than an error.
    n["linecode"]["lc"]["R_series_1_2"] = 0.2
    n["linecode"]["lc"]["R_series_2_1"] = 0.7
    full = kron_reduce_neutrals(n)
    @test full["linecode"]["lc"]["R_series_1_1"] ≈ real(1 - (.2 * .7) / (2 + 2im))
    n["linecode"]["lc"]["R_series_2_2"] = 0.0
    n["linecode"]["lc"]["X_series_2_2"] = 0.0
    @test_throws ArgumentError kron_reduce_neutrals(n)
end

@testset "Kron rejects unsafe structural time-series targets" begin
    n = Dict{String,Any}("bus"=>Dict("f"=>Dict{String,Any}("terminal_names"=>["a","n"]),
                                      "t"=>Dict{String,Any}("terminal_names"=>["a","n"])),
        "linecode"=>Dict("lc"=>Dict{String,Any}("R_series_1_1"=>1.0,"R_series_2_2"=>1.0)),
        "line"=>Dict("l"=>Dict{String,Any}("bus_from"=>"f","bus_to"=>"t","terminal_map_from"=>["a","n"],"terminal_map_to"=>["a","n"],"linecode"=>"lc",
                                        "time_series"=>Dict("terminal_map_from"=>"ts"))))
    @test_throws ArgumentError kron_reduce_neutrals(n)
end

@testset "Kron rejects bus voltage and neutral profiles" begin
    n = Dict{String,Any}(
        "bus" => Dict("f" => Dict{String,Any}(
            "terminal_names" => ["a", "n"], "neutral_terminal" => "n",
            "time_series" => Dict("vpn_min" => "profile")),
            "t" => Dict{String,Any}("terminal_names" => ["a", "n"])),
        "linecode" => Dict("lc" => Dict{String,Any}(
            "R_series_1_1" => 1.0, "R_series_2_2" => 1.0)),
        "line" => Dict("l" => Dict{String,Any}(
            "bus_from" => "f", "bus_to" => "t", "terminal_map_from" => ["a", "n"],
            "terminal_map_to" => ["a", "n"], "linecode" => "lc")))
    @test_throws ArgumentError kron_reduce_neutrals(n)
    n["bus"]["f"]["time_series"] = Dict("v_min" => "profile")
    @test_throws ArgumentError kron_reduce_neutrals(n)
    n["bus"]["f"]["time_series"] = Dict("neutral_terminal" => "profile")
    @test_throws ArgumentError kron_reduce_neutrals(n)
end

"""BMOPF counterpart of the OpenDSS four-wire perfect-ground fixture.

The linecode entries are per metre and the line length is 500 m, matching the
values in `test/data/pf_comparison/pf_1ph_perfectneutral.dss`.  Keeping this
constructor here (rather than importing the BMOPFTools test helpers) makes the
oracle test independent of private upstream test code while still comparing
the exact same physical case.
"""
function _nk_oracle_net(; nonlast_neutral::Bool=false)
    order = nonlast_neutral ? ["a", "b", "n", "c"] : ["a", "b", "c", "n"]
    z = Dict{String,Any}()
    for i in 1:4, j in 1:4
        r = i == j ? 0.500 : 0.020
        x = i == j ? 0.200 : 0.050
        z["R_series_$(i)_$(j)"] = r / 1000.0
        z["X_series_$(i)_$(j)"] = x / 1000.0
    end
    vph = 415.0 / sqrt(3)
    Dict{String,Any}(
        "terminal_conventions" => Dict{String,Any}(
            "phase" => ["a", "b", "c"], "neutral" => ["n"], "earth" => String[]),
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}("terminal_names" => order,
                "perfectly_grounded_terminals" => ["n"]),
            "lb" => Dict{String,Any}("terminal_names" => order,
                "perfectly_grounded_terminals" => ["n"])),
        "voltage_source" => Dict("source" => Dict{String,Any}(
            "bus" => "src", "terminal_map" => ["a", "b", "c"],
            "v_magnitude" => [vph, vph, vph],
            "v_angle" => [0.0, -2pi / 3, 2pi / 3])),
        "linecode" => Dict("4w" => z),
        "line" => Dict("l1" => Dict{String,Any}(
            "bus_from" => "src", "bus_to" => "lb", "linecode" => "4w",
            "length" => 500.0, "terminal_map_from" => order,
            "terminal_map_to" => order)),
        "load" => Dict("ld1" => Dict{String,Any}(
            "bus" => "lb", "terminal_map" => ["a", "n"],
            "configuration" => "WYE", "p_nom" => [15_000.0],
            "q_nom" => [5_000.0])))
end

const _NK_4W_ORACLE_DSS = raw"""Clear
Set DefaultBaseFreq=50
New Circuit.kron4 basekv=0.415 pu=1 angle=0 phases=3 bus1=src.1.2.3 model=ideal
New Linecode.lc nphases=4
~ Rmatrix=[0.500|0.020 0.500|0.020 0.020 0.500|0.020 0.020 0.020 0.500]
~ Xmatrix=[0.200|0.050 0.200|0.050 0.050 0.200|0.050 0.050 0.050 0.200]
~ Cmatrix=[0|0 0|0 0 0|0 0 0 0]
~ units=km
New Line.l1 bus1=src.1.2.3.0 bus2=lb.1.2.3.0 linecode=lc length=0.5 units=km
New Load.ld1 bus1=lb.1.0 phases=1 conn=wye kv=0.2396 kw=15 kvar=5 model=1 Vminpu=0 Vmaxpu=2
Set VoltageBases=[0.415]
CalcVoltageBases
Set Tolerance=1e-10
Set MaxIterations=100
Solve
"""

const _NK_3W_ORACLE_DSS = raw"""Clear
Set DefaultBaseFreq=50
New Circuit.kron3 basekv=0.415 pu=1 angle=0 phases=3 bus1=src.1.2.3 model=ideal
New Linecode.lc nphases=3
~ Rmatrix=[0.5022413793|0.0222413793 0.5022413793|0.0222413793 0.0222413793 0.5022413793|0.0222413793 0.0222413793 0.5022413793]
~ Xmatrix=[0.1951034483|0.0451034483 0.1951034483|0.0451034483 0.0451034483 0.1951034483|0.0451034483 0.0451034483 0.1951034483]
~ Cmatrix=[0|0 0|0 0 0|0 0 0 0]
~ units=km
New Line.l1 bus1=src.1.2.3 bus2=lb.1.2.3 linecode=lc length=0.5 units=km
New Load.ld1 bus1=lb.1 phases=1 conn=wye kv=0.2396 kw=15 kvar=5 model=1 Vminpu=0 Vmaxpu=2
Set VoltageBases=[0.415]
CalcVoltageBases
Set Tolerance=1e-10
Set MaxIterations=100
Solve
"""

function _nk_write_dss(deck::AbstractString)
    path, io = mktemp()
    write(io, deck)
    close(io)
    path
end

function _nk_ods_snapshot(path::AbstractString)
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Set DataPath=\"$(tempdir())\"")
    OpenDSSDirect.dss("Redirect \"$(normpath(path))\"")
    OpenDSSDirect.dss("Solve")
    converged = OpenDSSDirect.Solution.Converged()
    volts = Dict(String(n) => ComplexF64(v) for
                 (n, v) in zip(OpenDSSDirect.Circuit.AllNodeNames(),
                              OpenDSSDirect.Circuit.AllBusVolts()))
    OpenDSSDirect.Circuit.SetActiveElement("Line.l1")
    currents = ComplexF64.(OpenDSSDirect.CktElement.Currents())
    OpenDSSDirect.Circuit.SetActiveElement("Vsource.source")
    powers = ComplexF64.(OpenDSSDirect.CktElement.Powers())
    losses = real(OpenDSSDirect.Circuit.Losses())
    (converged=converged, volts=volts, currents=currents,
     powers=powers, losses=losses)
end

@testset "Kron reduction OpenDSSDirect four-wire oracle" begin
    # `runtests.jl` imports OpenDSSDirect unconditionally. The guard only
    # permits direct inclusion in a minimal environment without test extras;
    # the package test target itself is deliberately non-skippable.
    if _NK_HAS_ODS
        reduced = kron_reduce_neutrals(_nk_oracle_net())
        prov = reduced["_meta"]["kron_reduction"]
        @test prov["classification"] == "exact"

        # Paired OpenDSS oracle: an explicit four-wire node-0-ground deck and
        # its manually projected three-wire counterpart must agree exactly at
        # both line ends, in source power, losses, and current recovery.
        p4 = _nk_write_dss(_NK_4W_ORACLE_DSS)
        p3 = _nk_write_dss(_NK_3W_ORACLE_DSS)
        try
            s4, s3 = _nk_ods_snapshot(p4), _nk_ods_snapshot(p3)
            @test s4.converged
            @test s3.converged
            result = BMOPFTools.solve_pf(reduced; optimizer=Ipopt.Optimizer)
            @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            phase_map = Dict("a" => "1", "b" => "2", "c" => "3")
            v_bm = Dict("$(bid).$(phase_map[t])" => tv["vr"] + im * tv["vi"]
                        for (bid, terminals) in result["bus"]
                        for (t, tv) in terminals if haskey(phase_map, t))
            for node in ("src.1", "src.2", "src.3", "lb.1", "lb.2", "lb.3")
                @test haskey(s4.volts, node)
                @test haskey(s3.volts, node)
                @test isapprox(s4.volts[node], s3.volts[node]; atol=1e-6, rtol=1e-9)
                @test haskey(v_bm, node)
                @test isapprox(v_bm[node], s3.volts[node]; atol=1e-3, rtol=1e-6)
            end
            # Currents() is ordered by terminal: first four are the from end,
            # next four the to end. Compare only retained phase conductors.
            for (i4, i3) in zip((1, 2, 3, 5, 6, 7), (1, 2, 3, 4, 5, 6))
                @test isapprox(s4.currents[i4], s3.currents[i3]; atol=1e-8, rtol=1e-9)
            end
            @test isapprox(sum(s4.powers[1:3]), sum(s3.powers[1:3]); atol=1e-7, rtol=1e-9)
            @test isapprox(s4.losses, s3.losses; atol=1e-6, rtol=1e-8)

            lc_change = only(filter(x -> get(x, "linecode", "") == "4w",
                                    reduced["extras"]["kron_reduction"]["changes"]))
            k_record = complex.(lc_change["recovery_K_real"], lc_change["recovery_K_imag"])
            i4_from, i4_to = s4.currents[4], s4.currents[8]
            @test isapprox(i4_from, dot(conj.(k_record), s4.currents[1:3]); atol=1e-8, rtol=1e-9)
            @test isapprox(i4_to, dot(conj.(k_record), s4.currents[5:7]); atol=1e-8, rtol=1e-9)
            @test isapprox(s4.currents[5:8], -s4.currents[1:4]; atol=1e-8, rtol=1e-9)
        finally
            rm(p4; force=true)
            rm(p3; force=true)
        end

        # The executable recovery record is the neutral row relation
        # In = K*Ip and carries the original conductor ordering and both
        # neutral shunt rows (empty for this no-pi oracle deck).
    end
end

@testset "Kron reduction handles a non-last neutral conductor" begin
    # OpenDSS accepts arbitrary conductor order on a line.  Exercise the same
    # indexing path independently of the optional oracle; the matrix result
    # must still be complete and the neutral map must disappear.
    nonlast = kron_reduce_neutrals(_nk_oracle_net(nonlast_neutral=true))
    @test nonlast["line"]["l1"]["terminal_map_from"] == ["a", "b", "c"]
    @test count(k -> startswith(k, "R_series_"), keys(nonlast["linecode"]["4w"])) == 9
end

@testset "Kron prunes only newly orphaned line geometries" begin
    n = _nk_oracle_net()
    n["linecode"]["4w"]["line_geometry"] = "geo"
    wire = Dict{String,Any}("kind" => "overhead", "r_dc" => 1e-4,
                            "gmr" => 0.005, "radius" => 0.006, "i_max" => 200.0)
    conductors = [Dict{String,Any}("wire_data" => "w", "x" => Float64(i),
                                   "y" => 10.0, "terminal" => t)
                  for (i, t) in enumerate(["a", "b", "c", "n"])]
    valid_geometry = Dict{String,Any}("conductors" => conductors, "frequency" => 50.0)
    n["line_geometry"] = Dict{String,Any}(
        "geo" => valid_geometry, "preexisting_orphan" => deepcopy(valid_geometry))
    n["wire_data"] = Dict{String,Any}("w" => wire)
    out = kron_reduce_neutrals(n)
    @test !haskey(out["line_geometry"], "geo")
    @test haskey(out["line_geometry"], "preexisting_orphan")
end

@testset "Kron clones shared linecodes for mixed neutral positions" begin
    n = _nk_oracle_net()
    order = ["a", "b", "n", "c"]
    n["bus"]["x"] = Dict{String,Any}("terminal_names" => order)
    n["bus"]["y"] = Dict{String,Any}("terminal_names" => order)
    n["line"]["l2"] = Dict{String,Any}(
        "bus_from" => "x", "bus_to" => "y", "linecode" => "4w",
        "length" => 250.0, "terminal_map_from" => order,
        "terminal_map_to" => order, "i_max" => [1.0, 2.0, 3.0, 4.0])
    out = kron_reduce_neutrals(n)
    @test out["line"]["l1"]["linecode"] != out["line"]["l2"]["linecode"]
    @test out["line"]["l2"]["i_max"] == [1.0, 2.0, 4.0]
    @test count(k -> startswith(k, "4w__kron"), keys(out["linecode"])) == 2
end

@testset "Kron reduces inline matrices and preserves line length" begin
    r = [1.0 0.2 0.3; 0.2 2.0 0.4; 0.3 0.4 3.0]
    x = [2.0 0.1 0.2; 0.1 3.0 0.3; 0.2 0.3 4.0]
    line = Dict{String,Any}("bus_from" => "f", "bus_to" => "t",
        "terminal_map_from" => ["a", "n", "b"],
        "terminal_map_to" => ["a", "n", "b"], "length" => 7.0,
        "i_max" => [1.0, 2.0, 3.0], "s_max" => [10.0, 20.0, 30.0])
    for i in 1:3, j in 1:3
        line["R_series_$(i)_$(j)"] = r[i, j]
        line["X_series_$(i)_$(j)"] = x[i, j]
        line["G_from_$(i)_$(j)"] = i == j ? 0.1i : 0.01
        line["B_from_$(i)_$(j)"] = i == j ? 0.2i : 0.02
        line["G_to_$(i)_$(j)"] = i == j ? 0.3i : 0.03
        line["B_to_$(i)_$(j)"] = i == j ? 0.4i : 0.04
    end
    n = Dict{String,Any}(
        "terminal_conventions" => Dict{String,Any}("phase" => ["a", "b"], "neutral" => ["n"]),
        "bus" => Dict("f" => Dict{String,Any}("terminal_names" => ["a", "n", "b"]),
                       "t" => Dict{String,Any}("terminal_names" => ["a", "n", "b"])),
        "line" => Dict("in" => line),
        "load" => Dict("ld" => Dict{String,Any}("bus" => "t",
            "terminal_map" => ["a", "n"], "configuration" => "WYE",
            "p_nom" => [10.0], "q_nom" => [1.0])))
    out = kron_reduce_neutrals(n)
    zred = complex.(r, x)[[1, 3], [1, 3]] -
           complex.(r, x)[[1, 3], 2:2] *
           (complex.(r, x)[2:2, 2:2] \ complex.(r, x)[2:2, [1, 3]])
    @test out["line"]["in"]["terminal_map_from"] == ["a", "b"]
    @test out["line"]["in"]["length"] == 7.0
    @test out["line"]["in"]["i_max"] == [1.0, 3.0]
    @test out["line"]["in"]["s_max"] == [10.0, 30.0]
    @test out["line"]["in"]["R_series_1_1"] ≈ real(zred[1, 1])
    @test out["line"]["in"]["X_series_2_2"] ≈ imag(zred[2, 2])
    @test out["line"]["in"]["G_from_1_1"] == 0.1
    @test out["line"]["in"]["G_to_2_2"] ≈ 0.9
    line_change = only(filter(x -> get(x, "line", "") == "in",
                              out["extras"]["kron_reduction"]["changes"]))
    @test haskey(line_change, "neutral_shunt_rows")
    @test haskey(line_change["neutral_shunt_rows"], "G_from_neutral_row")
    @test kron_reduce_neutrals(out) == out
end

# ── Cross-validation against BMOPFTools' own machinery (added on porting) ──

@testset "neutral Kron output satisfies the PSK-000008 boundary contract" begin
    fixture = joinpath(@__DIR__, "fixtures", "negative", "kron-boundary-grounding")
    source = parse_bmopf(joinpath(fixture, "source.json"))
    recovery = Dict("eliminated_terminal" => "n",
                    "voltage_constraint" => "V_n = 0 at both endpoints",
                    "current_recovery" => "recover I_n from retained phase voltages and source Z")
    check(src, dst) = check_kron_boundary_recovery(src, dst; source_line_id="l4",
        target_line_id="l4", bus_mapping=Dict("src" => "src", "load" => "load"),
        recovery_map=recovery)
    # grounded at both ends: the reducer is exact and the contract passes
    grounded = deepcopy(source)
    grounded["bus"]["load"]["perfectly_grounded_terminals"] = ["n"]
    red = kron_reduce_neutrals(grounded)
    @test red["_meta"]["kron_reduction"]["classification"] == "exact"
    res = check(grounded, red)
    @test res.status == :passed
    @test res.evidence["boundary_relation_error_ohm"] < 1e-12
    # floating neutral: the reducer forces ideal ground and says so, and the
    # contract refuses the same transformation for the same reason
    red_f = kron_reduce_neutrals(source)
    prov = red_f["_meta"]["kron_reduction"]
    @test prov["classification"] == "grounded_neutral_projection"
    @test prov["forced_ground_buses"] == ["load"]
    res_f = check(source, red_f)
    @test res_f.status == :failed
    @test [f.code for f in res_f.findings] == ["E.CONTRACT.KRON_GROUNDING_PRECONDITION"]
end

@testset "neutral Kron leaves the phase Ybus unchanged when neutrals are grounded" begin
    net = _nk_oracle_net()
    red = kron_reduce_neutrals(net)
    y0 = ybus_passive(net); y1 = ybus_passive(red)
    idx(y) = [y.index[(b, t)] for b in ("src", "lb") for t in ("a", "b", "c")]
    @test Matrix{ComplexF64}(y1.Y[idx(y1), idx(y1)]) ≈ Matrix{ComplexF64}(y0.Y[idx(y0), idx(y0)]) rtol = 1e-12
    @test size(y1.Y) == size(y0.Y)       # grounded neutrals were earth nodes already
    # serialization round trip of the reduced case
    io = IOBuffer(); write_bmopf(red, io)
    back = parse_bmopf(String(take!(io)); from_string=true)
    yb = ybus_passive(back)
    @test Matrix{ComplexF64}(yb.Y[idx(yb), idx(yb)]) ≈ Matrix{ComplexF64}(y1.Y[idx(y1), idx(y1)]) rtol = 1e-12
end
