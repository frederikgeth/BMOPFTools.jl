# OpenDSS oracles for the November 2026 OPF engine review.
#
# Included from runtests.jl after powerflow_comparison_tests.jl (whose helpers
# `_ods_volts`, `_cmp_volts`, `_net_3ph_line`, `_net_autotransformer`, and
# `_net_1ph_xfmr` it reuses). Requires JuMP, Ipopt, and OpenDSSDirect.
#
# `opf_review_regression_tests.jl` pins the same defects with internal
# oracles (per-unit against SI, power balance). Those cannot catch an error
# that both unit systems share, so every fix that OpenDSS can express is also
# checked here against an independent solver:
#
#   * voltage bases across a regulator            (pf_autotransformer.dss)
#   * voltage bases around an unequal-ratio mesh  (pf_mesh_unequal_ratio.dss)
#   * neutral phasors under a line angle window   (pf_4w_two_section.dss)
#   * a two-terminal line-to-line generator       (pf_delta_gen_1ph.dss)
#
# The DC-network, IBR-control, and feasibility-slack fixes have no OpenDSS
# counterpart at snapshot level and stay on internal oracles.

const _REVIEW_ORACLE_DIR = joinpath(@__DIR__, "data", "opf_review_oracles")

# Node voltages of a determined power flow, keyed like OpenDSS ("bus.node").
function _review_pf_volts(net; per_unit::Bool, solver=solve_pf)
    result = solver(deepcopy(net); optimizer=Ipopt.Optimizer, per_unit,
        solver_options=("tol" => 1e-10, "constr_viol_tol" => 1e-10))
    @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    volts = Dict{String,ComplexF64}()
    for (bus, terminals) in result["bus"], (t, v) in terminals
        volts[bus * "." * (t == "n" ? "4" : t)] = complex(v["vr"], v["vi"])
    end
    return volts, result
end

@testset "OpenDSS oracle — regulator nameplate does not rescale per-unit" begin
    V_ods = _ods_volts(joinpath(_PF_CMP_DIR, "pf_autotransformer.dss"))
    # The same regulator, described with and without a nameplate voltage pair.
    # The model uses `tap_ratio` only, so all three must reproduce OpenDSS in
    # both unit systems.
    for nameplate in (Dict{String,Any}(),
                      Dict{String,Any}("v_nom_from" => 2400.0, "v_nom_to" => 2520.0),
                      Dict{String,Any}("v_nom_from" => 2400.0)),
        per_unit in (true, false)
        net = _net_autotransformer()
        merge!(net["transformer"]["single_phase_autotransformer"]["reg"], nameplate)
        V_bm, _ = _review_pf_volts(net; per_unit)
        _cmp_volts(V_ods, V_bm; label="regulator pu=$per_unit: ")
    end
end

function _net_mesh_unequal_ratio()
    # pf_mesh_unequal_ratio.dss. Both transformers: 100 kVA, %r=1 per winding,
    # xhl=4 % placed on winding 1 (as in `_net_1ph_xfmr`).
    s = 100_000.0; vf = 11_000.0
    transformer(bus_to, vt) = Dict{String,Any}(
        "bus_from" => "hv", "bus_to" => bus_to,
        "terminal_map_from" => ["1", "n"], "terminal_map_to" => ["1", "n"],
        "v_nom_from" => vf, "v_nom_to" => vt, "s_rating" => s,
        "r_series_from" => 0.01 * vf^2 / s, "r_series_to" => 0.01 * vt^2 / s,
        "x_series_from" => 0.04 * vf^2 / s, "x_series_to" => 0.0)
    bus() = Dict{String,Any}("terminal_names" => ["1", "n"], "neutral_terminal" => "n")
    ground(b) = Dict{String,Any}("bus" => b, "terminal_map" => ["n"],
                                 "G_1_1" => 1000.0, "B_1_1" => 0.0)
    Dict{String,Any}(
        "bus" => Dict{String,Any}("hv" => bus(), "lv1" => bus(), "lv2" => bus()),
        "voltage_source" => Dict{String,Any}("source" => Dict{String,Any}(
            "bus" => "hv", "terminal_map" => ["1"],
            "v_magnitude" => [vf], "v_angle" => [0.0])),
        "shunt" => Dict{String,Any}("grnd_lv1" => ground("lv1"), "grnd_lv2" => ground("lv2")),
        "transformer" => Dict{String,Any}("single_phase" => Dict{String,Any}(
            "t1" => transformer("lv1", 240.0), "t2" => transformer("lv2", 252.0))),
        "line" => Dict{String,Any}("tie" => Dict{String,Any}(
            "bus_from" => "lv1", "bus_to" => "lv2",
            "terminal_map_from" => ["1", "n"], "terminal_map_to" => ["1", "n"],
            "R_series_1_1" => 0.02, "R_series_2_2" => 0.02, "R_series_1_2" => 0.0,
            "X_series_1_1" => 0.01, "X_series_2_2" => 0.01, "X_series_1_2" => 0.0)),
        "load" => Dict{String,Any}("ld1" => Dict{String,Any}(
            "bus" => "lv2", "terminal_map" => ["1", "n"], "configuration" => "WYE",
            "p_nom" => [30_000.0], "q_nom" => [10_000.0])))
end

@testset "OpenDSS oracle — circulating current in an unequal-ratio mesh" begin
    path = joinpath(_REVIEW_ORACLE_DIR, "pf_mesh_unequal_ratio.dss")
    V_ods = _ods_volts(path)
    # OpenDSS tie current (phase conductor, sending end), after the solve above.
    OpenDSSDirect.Circuit.SetActiveElement("Line.tie")
    I_ods = abs(OpenDSSDirect.CktElement.Currents()[1])
    @test I_ods > 50.0     # the mismatch drives a large loop current
    for per_unit in (true, false)
        V_bm, result = _review_pf_volts(_net_mesh_unequal_ratio(); per_unit)
        _cmp_volts(V_ods, V_bm; label="mesh pu=$per_unit: ")
        @test result["line"]["tie"]["1"]["cm_fr"] ≈ I_ods rtol=1e-2
    end
end

function _net_4w_two_section(; window=nothing)
    # pf_4w_two_section.dss: reuse the four-wire linecode and source of
    # `_net_3ph_line`, split into two 300 m sections.
    net = _net_3ph_line()
    bus() = Dict{String,Any}("terminal_names" => ["1", "2", "3", "n"],
                             "neutral_terminal" => "n")
    net["bus"] = Dict{String,Any}("src" => bus(), "b1" => bus(), "b2" => bus())
    section(bf, bt) = Dict{String,Any}("bus_from" => bf, "bus_to" => bt,
        "linecode" => "4w", "length" => 300.0,
        "terminal_map_from" => ["1", "2", "3", "n"],
        "terminal_map_to" => ["1", "2", "3", "n"])
    net["line"] = Dict{String,Any}("l1" => section("src", "b1"), "l2" => section("b1", "b2"))
    if window !== nothing
        for line in values(net["line"])
            line["va_diff_min"] = -window; line["va_diff_max"] = window
        end
    end
    single(bus, phase) = Dict{String,Any}("bus" => bus, "terminal_map" => [phase, "n"],
        "configuration" => "WYE", "p_nom" => [6_000.0], "q_nom" => [1_000.0])
    net["load"] = Dict{String,Any}("la" => single("b1", "1"), "lb" => single("b2", "2"))
    return net
end

@testset "OpenDSS oracle — neutral phasors under a line angle window" begin
    V_ods = _ods_volts(joinpath(_REVIEW_ORACLE_DIR, "pf_4w_two_section.dss"))
    # The premise, established by OpenDSS alone: the neutral phasor rotates by
    # far more than the window between the two ends of section l2, while every
    # phase conductor rotates by far less.
    window = 0.1
    rotation(node) = abs(rem2pi(angle(V_ods["b1.$node"]) - angle(V_ods["b2.$node"]), RoundNearest))
    @test rotation("4") > 3 * window
    @test all(rotation(string(k)) < window / 3 for k in 1:3)
    # A window that every phase satisfies must leave the solution untouched —
    # neutral voltages included, held to a tolerance fit for a few volts.
    for per_unit in (true, false)
        V_bm, _ = _review_pf_volts(_net_4w_two_section(; window); per_unit, solver=solve_opf)
        _cmp_volts(V_ods, V_bm; label="4w window pu=$per_unit: ")
        for node in ("b1.4", "b2.4")
            @test V_bm[node] ≈ V_ods[node] atol=0.05
        end
    end
end

@testset "OpenDSS oracle — two-terminal DELTA generator is one coil" begin
    V_ods = _ods_volts(joinpath(_REVIEW_ORACLE_DIR, "pf_delta_gen_1ph.dss"))
    net = _net_3ph_line()
    net["load"] = Dict{String,Any}("ld3" => Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["3", "n"], "configuration" => "WYE",
        "p_nom" => [5_000.0], "q_nom" => [1_000.0]))
    net["generator"] = Dict{String,Any}("g1" => Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["1", "2"], "configuration" => "DELTA",
        "p_min" => [8_000.0], "p_max" => [8_000.0],
        "q_min" => [0.0], "q_max" => [0.0]))
    for per_unit in (true, false)
        V_bm, result = _review_pf_volts(net; per_unit)
        _cmp_volts(V_ods, V_bm; label="delta gen pu=$per_unit: ")
        @test length(result["generator"]["g1"]) == 1
        @test sum(coil["pg"] for coil in values(result["generator"]["g1"])) ≈ 8_000.0 rtol=1e-6
    end
end
