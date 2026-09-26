# Geometry-based line-constants engine tests.
#
# Original synthetic geometries, frozen OpenDSS matrices, analytic checks,
# and live OpenDSS comparisons. See test/data/line_geometry/README.md.
using JSON3, SHA
const _MILE = 1609.344
_wire_phase() = Dict{String,Any}("kind"=>"overhead", "r_ac"=>0.00021,
    "gmr"=>0.006, "radius"=>0.008, "i_max"=>450.0)
_wire_neutral() = Dict{String,Any}("kind"=>"overhead", "r_ac"=>0.00065,
    "gmr"=>0.003, "radius"=>0.004, "i_max"=>180.0)
_geometry_overhead() = Dict{String,Any}(
    "frequency"=>60.0, "earth_resistivity"=>100.0, "earth_model"=>"modified_carson",
    "conductors"=>Any[
        Dict{String,Any}("wire_data"=>w, "x"=>x, "y"=>y, "terminal"=>t)
        for (w,x,y,t) in (("phase",-0.9,10.5,"a"),("phase",0.2,11.1,"b"),
                          ("phase",1.1,10.0,"c"),("neutral",0.45,8.8,"n"))])
function _geometry_reference(name)
    dir = joinpath(@__DIR__, "data", "line_geometry")
    refs = JSON3.read(read(joinpath(dir, "opendss_reference.json"), String))
    record = refs["cases"][name]
    @test bytes2hex(sha256(read(joinpath(dir, name * ".dss")))) == record["sha256"]
    matrix(key) = reduce(vcat, permutedims.(Vector{Float64}.(record[key])))
    (Z = (matrix("R") + im * matrix("X")) * _MILE, C = matrix("C") * 1e-9)
end

_lc_z_permile(lc) = (BMOPFTools._pattern_keys_to_matrix(lc, "R_series_") .+
                     im .* BMOPFTools._pattern_keys_to_matrix(lc, "X_series_")) .* _MILE

@testset "Line constants — geometry-based impedance engine" begin

    @testset "pure overhead numerical API matches compiler and preserves scalar type" begin
        phase = _wire_phase()
        neutral = _wire_neutral()
        geo = _geometry_overhead()
        entries = geo["conductors"]
        wires = [phase, phase, phase, neutral]
        r_ac = [w["r_ac"] for w in wires]
        gmr = [w["gmr"] for w in wires]
        radius = [w["radius"] for w in wires]
        x = [e["x"] for e in entries]
        y = [e["y"] for e in entries]

        constants = overhead_line_constants(r_ac, gmr, radius, x, y;
            frequency=geo["frequency"], earth_model=geo["earth_model"],
            earth_resistivity=geo["earth_resistivity"])

        net = Dict{String,Any}(
            "wire_data" => Dict("phase" => phase, "neutral" => neutral),
            "line_geometry" => Dict("g" => Dict{String,Any}(
                geo...,
                "conductors" => Any[
                    Dict{String,Any}(e..., "wire_data" => i <= 3 ? "phase" : "neutral")
                    for (i, e) in enumerate(entries)
                ])))
        compile_linecode(net, "g")
        lc = net["linecode"]["g"]
        Zcompiled = BMOPFTools._pattern_keys_to_matrix(lc, "R_series_") .+
                    im .* BMOPFTools._pattern_keys_to_matrix(lc, "X_series_")
        Ccompiled = (BMOPFTools._pattern_keys_to_matrix(lc, "B_from_") .+
                     BMOPFTools._pattern_keys_to_matrix(lc, "B_to_")) ./
                    (2pi * geo["frequency"])
        @test constants.Z ≈ Zcompiled rtol=1e-13
        @test constants.C ≈ Ccompiled rtol=1e-13
        @test constants.Z == transpose(constants.Z)
        @test constants.C == transpose(constants.C)

        big = overhead_line_constants(BigFloat.(r_ac), BigFloat.(gmr),
            BigFloat.(radius), BigFloat.(x), BigFloat.(y);
            frequency=big"60", earth_resistivity=big"100")
        @test eltype(big.Z) == Complex{BigFloat}
        @test eltype(big.C) == BigFloat
        @test Float64.(real.(big.Z)) ≈ real.(constants.Z) rtol=1e-13

        @test_throws DimensionMismatch overhead_line_constants(
            r_ac[1:3], gmr, radius, x, y; frequency=60.0)
        @test_throws ArgumentError overhead_line_constants(
            r_ac, gmr, radius, x, zeros(4); frequency=60.0)
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Synthetic overhead case; frozen independently computed OpenDSS matrices.
    @testset "Synthetic overhead — frozen OpenDSS matrices" begin
        net = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("phase" => _wire_phase(),
                                            "neutral"  => _wire_neutral()),
            "line_geometry" => Dict{String,Any}("overhead" => _geometry_overhead()))
        id = compile_linecode(net, "overhead")
        @test id == "overhead"
        lc = net["linecode"]["overhead"]

        Z = _lc_z_permile(lc)
        @test size(Z) == (4, 4)
        @test lc["source"] == "geometry"
        @test lc["line_geometry"] == "overhead"
        @test lc["derivation"]["method"] == "modified_carson"
        @test lc["i_max"] == [450.0, 450.0, 450.0, 180.0]

        Zred = BMOPFTools._kron_reduce(Z, [1, 2, 3])
        ref = _geometry_reference("synthetic_overhead")
        Zref = ref.Z[1:3, 1:3] - ref.Z[1:3, 4:4] * (ref.Z[4:4, 4:4] \ ref.Z[4:4, 1:3])
        @test maximum(abs.(Zred .- Zref)) / maximum(abs.(Zref)) < 1e-4

        # Shunt: engine keeps the full 4×4 C; reduce in potential form and
        # compare with the frozen OpenDSS capacitance (μS/mile).
        Bfrom = BMOPFTools._pattern_keys_to_matrix(lc, "B_from_")
        Bto   = BMOPFTools._pattern_keys_to_matrix(lc, "B_to_")
        @test Bfrom ≈ Bto
        omega = 2pi * 60.0
        C4 = (Bfrom .+ Bto) ./ omega                # total per-metre C
        P4 = inv(C4)
        C3 = inv(BMOPFTools._kron_reduce_potential(P4, [1, 2, 3]))
        B3 = omega .* C3 .* _MILE .* 1e6            # μS/mile
        B_ref = omega .* ref.C[1:3, 1:3] .* _MILE .* 1e6
        @test maximum(abs.(B3 .- B_ref)) / maximum(abs.(B_ref)) < 1e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Earth models agree at power frequency (sub-percent for distribution
    # geometry) and Deri ≠ Carson strictly (different formulations).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "earth models — modified/full Carson and Deri consistent" begin
        Zs = map(("modified_carson", "full_carson", "deri")) do model
            geo = _geometry_overhead(); geo["earth_model"] = model
            net = Dict{String,Any}(
                "wire_data" => Dict{String,Any}("phase" => _wire_phase(),
                                                "neutral"  => _wire_neutral()),
                "line_geometry" => Dict{String,Any}("g" => geo))
            compile_linecode(net, "g")
            _lc_z_permile(net["linecode"]["g"])
        end
        for Zalt in Zs[2:end]
            # norm-relative: small mutual-R entries differ by a few percent
            # of themselves but the matrices agree to <1% of the Z scale
            @test maximum(abs.(Zalt .- Zs[1])) / maximum(abs.(Zs[1])) < 0.01
            @test maximum(abs.(Zalt .- Zs[1])) > 0.0
        end
    end

    # ─────────────────────────────────────────────────────────────────────────
    @testset "CN cable — synthetic asymmetric spacing" begin
        cn = Dict{String,Any}(
            "kind" => "cn_cable",
            "r_ac" => 0.00038, "gmr" => 0.004,
            "radius" => 0.006,
            "d_cable" => 0.032,
            "n_strands" => 12,
            "d_strand" => 0.0015,
            "gmr_strand" => 0.0006,
            "r_strand" => 0.012)
        net = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("cn" => cn),
            "line_geometry" => Dict{String,Any}("cn" => Dict{String,Any}(
                "frequency" => 60.0, "earth_resistivity" => 100.0,
                "conductors" => Any[
                    Dict{String,Any}("wire_data" => "cn", "x" => -0.22, "y" => -1.1, "terminal" => "a"),
                    Dict{String,Any}("wire_data" => "cn", "x" =>  0.03, "y" => -1.1, "terminal" => "b"),
                    Dict{String,Any}("wire_data" => "cn", "x" =>  0.31, "y" => -1.1, "terminal" => "c")])))
        compile_linecode(net, "cn")
        lc = net["linecode"]["cn"]
        @test sort(lc["derivation"]["shields_reduced"]) == ["cn:1", "cn:2", "cn:3"]

        Z = _lc_z_permile(lc)
        ref = _geometry_reference("synthetic_cn")
        @test maximum(abs.(Z .- ref.Z)) / maximum(abs.(ref.Z)) < 1e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    @testset "TS cable — synthetic phase and return" begin
        ts = Dict{String,Any}(
            "kind" => "ts_cable",
            "r_ac" => 0.00058, "gmr" => 0.0036,
            "radius" => 0.0048,
            "d_shield" => 0.024,
            "t_tape" => 0.00016,     # synthetic tape thickness
            "tape_lap" => 25.0)
        nw = Dict{String,Any}(                 # synthetic return conductor
            "kind" => "overhead",
            "r_ac" => 0.0009, "gmr" => 0.0025,
            "radius" => 0.0034)
        net = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("ts" => ts, "return" => nw),
            "line_geometry" => Dict{String,Any}("ts" => Dict{String,Any}(
                "frequency" => 60.0, "earth_resistivity" => 100.0,
                "conductors" => Any[
                    Dict{String,Any}("wire_data" => "ts", "x" => 0.0,       "y" => -1.25, "terminal" => "a"),
                    Dict{String,Any}("wire_data" => "return", "x" => 0.065, "y" => -1.25, "terminal" => "n")])))
        compile_linecode(net, "ts")
        lc = net["linecode"]["ts"]
        @test lc["derivation"]["shields_reduced"] == ["ts:1"]

        Z = _lc_z_permile(lc)
        @test size(Z) == (2, 2)
        z1 = BMOPFTools._kron_reduce(Z, [1])
        ref = _geometry_reference("synthetic_ts").Z
        expected = ref[1, 1] - ref[1, 2] * ref[2, 1] / ref[2, 2]
        @test abs(z1[1, 1] - expected) / abs(expected) < 1e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Analytic capacitance checks.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "shunt capacitance — analytic single conductor and coax" begin
        eps0 = 8.8541878128e-12
        # single conductor at height h: C = 2πε0 / ln(2h/r)
        h = 10.0; r = 0.01; f = 50.0
        net = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("w" => Dict{String,Any}(
                "kind" => "overhead", "r_ac" => 1e-4, "radius" => r)),
            "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
                "frequency" => f,
                "conductors" => Any[Dict{String,Any}(
                    "wire_data" => "w", "x" => 0.0, "y" => h, "terminal" => "a")])))
        compile_linecode(net, "g")
        lc = net["linecode"]["g"]
        C_exact = 2pi * eps0 / log(2h / r)
        @test lc["B_from_1_1"] + lc["B_to_1_1"] ≈ 2pi * f * C_exact  rtol = 1e-12

        # cable coax: C = 2πε0εr / ln(r_out/r_in)
        cn = Dict{String,Any}(
            "kind" => "cn_cable", "r_ac" => 1e-4, "radius" => 0.005,
            "d_cable" => 0.03, "n_strands" => 6, "d_strand" => 0.002,
            "r_strand" => 1e-3,
            "eps_r" => 2.3, "d_insulation" => 0.02, "t_insulation" => 0.004)
        net2 = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("c" => cn),
            "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
                "frequency" => f,
                "conductors" => Any[Dict{String,Any}(
                    "wire_data" => "c", "x" => 0.0, "y" => -1.0, "terminal" => "a")])))
        compile_linecode(net2, "g")
        lc2 = net2["linecode"]["g"]
        C_coax = 2pi * eps0 * 2.3 / log(0.01 / 0.006)
        @test lc2["B_from_1_1"] + lc2["B_to_1_1"] ≈ 2pi * f * C_coax  rtol = 1e-12
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Cross-defaulting and input validation.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "cross-defaults recorded; invalid inputs rejected" begin
        net = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("w" => Dict{String,Any}(
                "kind" => "overhead", "r_dc" => 1e-4, "radius" => 0.01)),
            "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
                "conductors" => Any[Dict{String,Any}(
                    "wire_data" => "w", "x" => 0.0, "y" => 10.0, "terminal" => "a")])))
        # frequency is REQUIRED — no ambient default, cases are self-contained
        @test_throws ErrorException compile_linecode(net, "g")
        net["line_geometry"]["g"]["frequency"] = 50.0
        compile_linecode(net, "g")
        lc = net["linecode"]["g"]
        @test sort(lc["derivation"]["defaults_applied"]) == ["gmr:w", "r_ac:w"]
        @test lc["derivation"]["frequency"] == 50.0
        @test lc["derivation"]["earth_resistivity"] == 100.0   # default
        # r_ac = 1.02 r_dc; gmr = e^{-1/4} radius
        de = BMOPFTools._carson_return_depth(50.0, 100.0)
        omega = 2pi * 50.0; mu0 = 4e-7 * pi
        @test lc["R_series_1_1"] ≈ 1.02e-4 + omega * mu0 / 8       rtol = 1e-12
        @test lc["X_series_1_1"] ≈ omega * mu0 / 2pi * log(de / (exp(-0.25) * 0.01)) rtol = 1e-12

        # existing linecode is protected
        @test_throws ErrorException compile_linecode(net, "g")
        @test compile_linecode(net, "g"; force=true) == "g"

        # duplicate terminals rejected
        net["line_geometry"]["bad"] = Dict{String,Any}(
            "frequency" => 50.0,
            "conductors" => Any[
                Dict{String,Any}("wire_data" => "w", "x" => 0.0, "y" => 10.0, "terminal" => "a"),
                Dict{String,Any}("wire_data" => "w", "x" => 1.0, "y" => 10.0, "terminal" => "a")])
        @test_throws ErrorException compile_linecode(net, "bad")

        # overlapping conductors rejected
        net["line_geometry"]["bad2"] = Dict{String,Any}(
            "frequency" => 50.0,
            "conductors" => Any[
                Dict{String,Any}("wire_data" => "w", "x" => 0.0, "y" => 10.0, "terminal" => "a"),
                Dict{String,Any}("wire_data" => "w", "x" => 0.0, "y" => 10.0, "terminal" => "b")])
        @test_throws ErrorException compile_linecode(net, "bad2")

        # unknown wire reference rejected
        net["line_geometry"]["bad3"] = Dict{String,Any}(
            "frequency" => 50.0,
            "conductors" => Any[Dict{String,Any}(
                "wire_data" => "nope", "x" => 0.0, "y" => 10.0, "terminal" => "a")])
        @test_throws ErrorException compile_linecode(net, "bad3")

        # compile_linecodes! skips existing, compiles the rest, errors surface
        delete!(net["line_geometry"], "bad"); delete!(net["line_geometry"], "bad2")
        delete!(net["line_geometry"], "bad3")
        net["line_geometry"]["g2"] = net["line_geometry"]["g"]
        ids = compile_linecodes!(net)
        @test ids == ["g2"]
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Schema round-trip + provenance cross-check on a complete network.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "round-trip, schema, and geometry cross-check" begin
        net = Dict{String,Any}(
            "name" => "geom_roundtrip",
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
            "wire_data" => Dict{String,Any}("phase" => _wire_phase(),
                                            "neutral"  => _wire_neutral()),
            "line_geometry" => Dict{String,Any}("overhead" => _geometry_overhead()),
            "load" => Dict{String,Any}("ld" => Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["a", "b", "c", "n"],
                "configuration" => "WYE",
                "p_nom" => [50e3, 50e3, 50e3], "q_nom" => [10e3, 10e3, 10e3])))
        compile_linecodes!(net)
        net["line"] = Dict{String,Any}("l1" => Dict{String,Any}(
            "bus_from" => "src", "bus_to" => "b1",
            "terminal_map_from" => ["a", "b", "c", "n"],
            "terminal_map_to"   => ["a", "b", "c", "n"],
            "linecode" => "overhead", "length" => 610.0))

        # write → parse round trip preserves the new libraries
        path = joinpath(mktempdir(), "geom.json")
        write_bmopf(net, path)
        net2 = parse_bmopf(path)
        @test haskey(net2, "wire_data") && haskey(net2["wire_data"], "phase")
        @test haskey(net2, "line_geometry")
        @test net2["linecode"]["overhead"]["line_geometry"] == "overhead"
        @test net2["linecode"]["overhead"]["R_series_1_1"] ≈
              net["linecode"]["overhead"]["R_series_1_1"]

        # analysis: schema-clean, referentially intact, cross-check passes
        report = analyze(net2)
        codes = [f.code for f in report.findings]
        @test !("I.SCHEMA.UNKNOWN_FIELDS" in codes)
        @test !("E.INT.UNKNOWN_WIRE_DATA" in codes)
        @test !("E.INT.UNKNOWN_LINE_GEOMETRY" in codes)
        @test !("W.PROV.GEOMETRY_MISMATCH" in codes)
        gc = report.results[:provenance]["geometry_crosscheck"]
        @test gc["n_checked"] == 1 && isempty(gc["mismatched"])

        # a hand-edited matrix is caught by the cross-check
        net2["linecode"]["overhead"]["R_series_1_1"] *= 1.5
        report2 = analyze(net2)
        @test "W.PROV.GEOMETRY_MISMATCH" in [f.code for f in report2.findings]

        # dangling references are caught
        net3 = deepcopy(net)
        net3["line_geometry"]["overhead"]["conductors"][1]["wire_data"] = "missing"
        report3 = analyze(net3)
        @test "E.INT.UNKNOWN_WIRE_DATA" in [f.code for f in report3.findings]
    end

    # ─────────────────────────────────────────────────────────────────────────
    # End-to-end: a geometry-compiled network solves and matches the same
    # network with the matrices entered directly.
    # ─────────────────────────────────────────────────────────────────────────
    if @isdefined(_HAS_JUMP_IPOPT) && _HAS_JUMP_IPOPT
        @testset "end-to-end power flow on geometry-compiled linecode" begin
            build() = Dict{String,Any}(
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
                "line" => Dict{String,Any}("l1" => Dict{String,Any}(
                    "bus_from" => "src", "bus_to" => "b1",
                    "terminal_map_from" => ["a", "b", "c", "n"],
                    "terminal_map_to"   => ["a", "b", "c", "n"],
                    "linecode" => "overhead", "length" => 610.0)),
                "load" => Dict{String,Any}("ld" => Dict{String,Any}(
                    "bus" => "b1", "terminal_map" => ["a", "b", "c", "n"],
                    "configuration" => "WYE",
                    "p_nom" => [200e3, 150e3, 100e3],
                    "q_nom" => [60e3, 40e3, 20e3])))

            net_geo = build()
            net_geo["wire_data"] = Dict{String,Any}(
                "phase" => _wire_phase(), "neutral" => _wire_neutral())
            net_geo["line_geometry"] = Dict{String,Any}("overhead" => _geometry_overhead())
            compile_linecodes!(net_geo)

            net_direct = build()
            lc = deepcopy(net_geo["linecode"]["overhead"])
            delete!(lc, "source"); delete!(lc, "line_geometry"); delete!(lc, "derivation")
            net_direct["linecode"] = Dict{String,Any}("overhead" => lc)

            r_geo    = solve_pf(net_geo)
            r_direct = solve_pf(net_direct)
            @test r_geo["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test r_direct["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            for t in ("a", "b", "c", "n")
                @test r_geo["bus"]["b1"][t]["vm"] ≈ r_direct["bus"]["b1"][t]["vm"] atol = 1e-6
            end
            # sanity: the loaded phase sees a plausible voltage drop
            @test 2200.0 < r_geo["bus"]["b1"]["a"]["vm"] < 2401.8
        end
    end
end

@testset "Line constants — realizability & assumption checks" begin
    _codes(net) = [f.code for f in analyze(net).findings]
    _mini(extra...) = begin
        net = Dict{String,Any}(
            "bus" => Dict{String,Any}("src" => Dict{String,Any}(
                "terminal_names" => ["a", "n"],
                "perfectly_grounded_terminals" => ["n"])),
            "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["a"],
                "v_magnitude" => [230.0], "v_angle" => [0.0])))
        for (k, v) in extra
            net[k] = v
        end
        net
    end

    @testset "frequency is required and consistency-checked" begin
        wd = Dict{String,Any}("w" => Dict{String,Any}(
            "kind" => "overhead", "r_ac" => 3e-4, "radius" => 0.005))
        geo(f) = Dict{String,Any}("frequency" => f, "conductors" => Any[
            Dict{String,Any}("wire_data" => "w", "x" => 0.0, "y" => 8.0,
                             "terminal" => "a")])

        # mixed frequencies without meta.frequency
        net = _mini("wire_data" => wd,
                    "line_geometry" => Dict{String,Any}("g50" => geo(50.0),
                                                        "g60" => geo(60.0)))
        @test "W.DOM.MIXED_FREQUENCY" in _codes(net)

        # meta.frequency mismatch (check-only — never rescales)
        net2 = _mini("wire_data" => wd,
                     "line_geometry" => Dict{String,Any}("g60" => geo(60.0)))
        net2["meta"] = Dict{String,Any}("frequency" => 50.0)
        codes2 = _codes(net2)
        @test "W.DOM.FREQUENCY_MISMATCH" in codes2
        @test !("W.DOM.MIXED_FREQUENCY" in codes2)

        # matching → clean
        net3 = _mini("wire_data" => wd,
                     "line_geometry" => Dict{String,Any}("g50" => geo(50.0)))
        net3["meta"] = Dict{String,Any}("frequency" => 50.0)
        @test !("W.DOM.FREQUENCY_MISMATCH" in _codes(net3))
    end

    @testset "50 Hz series regression — X scales with ω across earth models" begin
        # the synthetic overhead geometry at 50 Hz: modified vs full Carson still agree to
        # <1 % of the matrix scale, and X(50)/X(60) of the self term tracks
        # ω up to the slowly-varying ln(De) term (≈ 3 % effect)
        function z11(f, model)
            net = Dict{String,Any}(
                "wire_data" => Dict{String,Any}("phase" => _wire_phase(),
                                                "neutral"  => _wire_neutral()),
                "line_geometry" => Dict{String,Any}("g" => _geometry_overhead()))
            net["line_geometry"]["g"]["frequency"] = f
            net["line_geometry"]["g"]["earth_model"] = model
            compile_linecode(net, "g")
            lc = net["linecode"]["g"]
            lc["R_series_1_1"] + im * lc["X_series_1_1"]
        end
        zm50, zf50 = z11(50.0, "modified_carson"), z11(50.0, "full_carson")
        @test abs(zm50 - zf50) / abs(zm50) < 0.01
        # X scales with ω, nudged slightly above 50/60 because the return
        # depth De ∝ 1/√f enlarges the log term at 50 Hz
        ratio = imag(z11(50.0, "modified_carson")) / imag(z11(60.0, "modified_carson"))
        @test 50 / 60 < ratio < 0.87
    end

    @testset "impossible wire data — compile errors AND E findings" begin
        # gmr > radius
        bad = Dict{String,Any}("w" => Dict{String,Any}(
            "kind" => "overhead", "r_ac" => 3e-4,
            "gmr" => 0.006, "radius" => 0.005))
        geo = Dict{String,Any}("frequency" => 50.0, "conductors" => Any[
            Dict{String,Any}("wire_data" => "w", "x" => 0.0, "y" => 8.0,
                             "terminal" => "a")])
        net = _mini("wire_data" => bad,
                    "line_geometry" => Dict{String,Any}("g" => geo))
        @test_throws ErrorException compile_linecode(net, "g")
        @test "E.DOM.WIRE_GMR_EXCEEDS_RADIUS" in _codes(net)

        # overlapping conductor circles (1 cm apart, 1 cm radii)
        wd = Dict{String,Any}("w" => Dict{String,Any}(
            "kind" => "overhead", "r_ac" => 3e-4, "radius" => 0.01))
        geo2 = Dict{String,Any}("frequency" => 50.0, "conductors" => Any[
            Dict{String,Any}("wire_data" => "w", "x" => 0.0,  "y" => 8.0, "terminal" => "a"),
            Dict{String,Any}("wire_data" => "w", "x" => 0.01, "y" => 8.0, "terminal" => "b")])
        net2 = _mini("wire_data" => wd,
                     "line_geometry" => Dict{String,Any}("g" => geo2))
        @test_throws ErrorException compile_linecode(net2, "g")
        @test "E.DOM.GEOM_CONDUCTOR_OVERLAP" in _codes(net2)

        # non-nesting cable layers: strand circle inside the insulation
        cn = Dict{String,Any}("c" => Dict{String,Any}(
            "kind" => "cn_cable", "r_ac" => 3e-4, "radius" => 0.005,
            "d_cable" => 0.024, "n_strands" => 6, "d_strand" => 0.002,
            "r_strand" => 1e-3, "d_insulation" => 0.030, "t_insulation" => 0.004))
        geo3 = Dict{String,Any}("frequency" => 50.0, "conductors" => Any[
            Dict{String,Any}("wire_data" => "c", "x" => 0.0, "y" => -1.0,
                             "terminal" => "a")])
        net3 = _mini("wire_data" => cn,
                     "line_geometry" => Dict{String,Any}("g" => geo3))
        @test_throws ErrorException compile_linecode(net3, "g")
        @test "E.DOM.WIRE_CABLE_LAYERS" in _codes(net3)
    end

    @testset "implausible inputs — W/I findings, compile still succeeds" begin
        # the Ω/km-as-Ω/m unit error: 0.3 Ω/m on a 5 mm-radius conductor
        wd = Dict{String,Any}(
            "wkm" => Dict{String,Any}("kind" => "overhead",
                "r_dc" => 0.3, "radius" => 0.005),
            "wlo" => Dict{String,Any}("kind" => "overhead",
                "r_dc" => 3e-4, "r_ac" => 2e-4, "radius" => 0.005),  # r_ac < r_dc
            "wj"  => Dict{String,Any}("kind" => "overhead",
                "r_dc" => 3e-4, "radius" => 0.005, "i_max" => 5000.0))
        net = _mini("wire_data" => wd)
        codes = _codes(net)
        @test "W.DOM.WIRE_IMPLIED_RESISTIVITY" in codes
        @test "W.DOM.WIRE_RAC_BELOW_RDC" in codes
        @test "I.DOM.WIRE_CURRENT_DENSITY" in codes

        # Carson-validity: huge spacing at tiny earth resistivity
        wd2 = Dict{String,Any}("w" => Dict{String,Any}(
            "kind" => "overhead", "r_ac" => 3e-4, "radius" => 0.005))
        geo = Dict{String,Any}("frequency" => 60.0, "earth_resistivity" => 0.5,
            "conductors" => Any[
                Dict{String,Any}("wire_data" => "w", "x" => 0.0,   "y" => 10.0, "terminal" => "a"),
                Dict{String,Any}("wire_data" => "w", "x" => 200.0, "y" => 10.0, "terminal" => "b")])
        net2 = _mini("wire_data" => wd2,
                     "line_geometry" => Dict{String,Any}("g" => geo))
        codes2 = _codes(net2)
        @test "W.DOM.GEOM_CARSON_VALIDITY" in codes2
        @test "W.DOM.GEOM_EARTH_RESISTIVITY" in codes2
        @test compile_linecode(net2, "g") == "g"   # warns, but compiles

        # buried + full_carson; skin frequency
        geo2 = Dict{String,Any}("frequency" => 5000.0,
            "earth_model" => "full_carson",
            "conductors" => Any[Dict{String,Any}(
                "wire_data" => "w", "x" => 0.0, "y" => -1.0, "terminal" => "a")])
        net3 = _mini("wire_data" => wd2,
                     "line_geometry" => Dict{String,Any}("g" => geo2))
        codes3 = _codes(net3)
        @test "W.DOM.GEOM_BURIED_EARTH_MODEL" in codes3
        @test "W.DOM.WIRE_SKIN_FREQUENCY" in codes3

        # clearance slip (29 ft entered as 29… no — 2.9 m pole)
        geo3 = Dict{String,Any}("frequency" => 50.0,
            "conductors" => Any[Dict{String,Any}(
                "wire_data" => "w", "x" => 0.0, "y" => 2.9, "terminal" => "a")])
        net4 = _mini("wire_data" => wd2,
                     "line_geometry" => Dict{String,Any}("g" => geo3))
        @test "W.DOM.GEOM_CLEARANCE" in _codes(net4)
    end
end

@testset "Line constants — temperature correction of resistance" begin
    # r_ac(T) = r_ac(t_ref)·(1 + α₂₀(T − 20)) / (1 + α₂₀(t_ref − 20))  [IEC 60287].
    # The earth-return real part (ωμ₀/8) is temperature-independent, so the
    # compiled self-R diagonal minus that constant recovers the corrected r_ac.
    mu0 = 4e-7 * pi
    earth_R(f) = 2pi * f * mu0 / 8      # ohm/m, self earth-return resistance

    function _compiled_rac(; r_ac, alpha_20, t_ref, temperature, f = 50.0)
        w = Dict{String,Any}("kind" => "overhead", "r_ac" => r_ac,
                             "radius" => 0.01, "temperature_ref" => t_ref)
        alpha_20 === nothing || (w["alpha_20"] = alpha_20)
        geo = Dict{String,Any}("frequency" => f,
            "conductors" => Any[Dict{String,Any}(
                "wire_data" => "w", "x" => 0.0, "y" => 8.0, "terminal" => "a")])
        temperature === nothing || (geo["temperature"] = temperature)
        net = Dict{String,Any}("wire_data" => Dict{String,Any}("w" => w),
                               "line_geometry" => Dict{String,Any}("g" => geo))
        compile_linecode(net, "g")
        net["linecode"]["g"]["R_series_1_1"] - earth_R(f)
    end

    r20 = 3.0e-4; a = 0.00393              # copper, α at 20 °C
    # correct up from 20 °C to 75 °C
    @test _compiled_rac(r_ac = r20, alpha_20 = a, t_ref = 20.0, temperature = 75.0) ≈
          r20 * (1 + a * (75.0 - 20.0))            rtol = 1e-10
    # reference at 50 °C, operate at 90 °C — both offsets from 20 °C apply
    @test _compiled_rac(r_ac = r20, alpha_20 = a, t_ref = 50.0, temperature = 90.0) ≈
          r20 * (1 + a * (90.0 - 20.0)) / (1 + a * (50.0 - 20.0))  rtol = 1e-10
    # no temperature and no alpha_20 → resistance is left untouched
    @test _compiled_rac(r_ac = r20, alpha_20 = nothing, t_ref = 20.0, temperature = nothing) ≈
          r20                                       rtol = 1e-10
    # temperature given but no alpha_20 → still untouched (no coefficient to use)
    @test _compiled_rac(r_ac = r20, alpha_20 = nothing, t_ref = 20.0, temperature = 90.0) ≈
          r20                                       rtol = 1e-10
    # higher temperature ⇒ higher resistance (monotone)
    @test _compiled_rac(r_ac = r20, alpha_20 = a, t_ref = 20.0, temperature = 90.0) >
          _compiled_rac(r_ac = r20, alpha_20 = a, t_ref = 20.0, temperature = 25.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Live differential cross-check against OpenDSS (via OpenDSSDirect), gated on
# _HAS_ODS so CI without OpenDSS still runs the frozen-reference and analytic tests above.
#
# Geometry-defined linecodes do NOT round-trip through PowerIO yet, so we can't
# use `from_dss`. Instead OpenDSS computes the matrices from hand-written
# WireData/CNData/TSData + LineGeometry decks (test/data/line_geometry/*.dss),
# and BMOPFTools builds the SAME geometry independently as wire_data/
# line_geometry — a separate transcription of the identical physical data. The
# two engines' matrices are then compared.
#
# Live checks complement frozen OpenDSS reference matrices, across Carson,
# FullCarson, Deri and 50 Hz, and all three original conductor constructions.
# ─────────────────────────────────────────────────────────────────────────────
if @isdefined(_HAS_ODS) && _HAS_ODS
    @testset "geometry cross-check vs OpenDSS (live)" begin
        _dss_dir = joinpath(@__DIR__, "data", "line_geometry")

        # OpenDSS returns the full primitive matrix (units=m, reduce=no; CN/TS
        # shields are always internally reduced) in ohm/m, and CMatrix in nF/m.
        function _ods_matrices(dss_path)
            OpenDSSDirect.dss("Clear")
            OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
            OpenDSSDirect.Lines.Name("l1")
            (R = Matrix{Float64}(OpenDSSDirect.Lines.RMatrix()),
             X = Matrix{Float64}(OpenDSSDirect.Lines.XMatrix()),
             C = Matrix{Float64}(OpenDSSDirect.Lines.CMatrix()))
        end

        # Compile a hand-built geometry and return its per-metre matrices; C in
        # nF/m to match OpenDSS (C_total = 2·B_from/ω, ×1e9).
        function _bmopf_matrices(net, gid, f)
            compile_linecode(net, gid)
            lc = net["linecode"][gid]
            Bf = BMOPFTools._pattern_keys_to_matrix(lc, "B_from_")
            (R = BMOPFTools._pattern_keys_to_matrix(lc, "R_series_"),
             X = BMOPFTools._pattern_keys_to_matrix(lc, "X_series_"),
             C = Bf === nothing ? nothing : (2 .* Bf ./ (2pi * f)) .* 1e9)
        end

        # Synthetic overhead, hand-built, at a given earth model and frequency.
        function _net_overhead(earth_model, f)
            geo = _geometry_overhead()
            geo["earth_model"] = earth_model; geo["frequency"] = f
            Dict{String,Any}(
                "wire_data" => Dict{String,Any}("phase" => _wire_phase(),
                                                "neutral"  => _wire_neutral()),
                "line_geometry" => Dict{String,Any}("g" => geo))
        end

        # Write an in-memory variant of a committed deck (earth model / freq).
        function _variant(base, subs...)
            path = joinpath(mktempdir(), "variant.dss")
            txt = read(joinpath(_dss_dir, base), String)
            for (from, to) in subs
                txt = replace(txt, from => to)
            end
            write(path, txt)
            path
        end

        relerr(a, b) = maximum(abs.(a .- b)) / maximum(abs.(b))

        @testset "synthetic overhead — Carson ≡ modified_carson (60 Hz), R/X/C tight" begin
            ods = _ods_matrices(joinpath(_dss_dir, "synthetic_overhead.dss"))
            us  = _bmopf_matrices(_net_overhead("modified_carson", 60.0), "g", 60.0)
            @test relerr(us.R, ods.R) < 1e-4
            @test relerr(us.X, ods.X) < 1e-4
            @test relerr(us.C, ods.C) < 1e-3
        end

        @testset "synthetic overhead — FullCarson ≡ full_carson (60 Hz)" begin
            ods = _ods_matrices(_variant("synthetic_overhead.dss",
                                         "earthmodel=Carson" => "earthmodel=FullCarson"))
            us  = _bmopf_matrices(_net_overhead("full_carson", 60.0), "g", 60.0)
            @test relerr(us.R, ods.R) < 1e-4
            @test relerr(us.X, ods.X) < 1e-4
        end

        @testset "synthetic overhead — 50 Hz Carson (frequency handled from ω, no rescale)" begin
            ods = _ods_matrices(_variant("synthetic_overhead.dss",
                                         "defaultbasefreq=60" => "defaultbasefreq=50"))
            us  = _bmopf_matrices(_net_overhead("modified_carson", 50.0), "g", 50.0)
            @test relerr(us.R, ods.R) < 1e-4
            @test relerr(us.X, ods.X) < 1e-4
            # sanity: the 50 Hz reactance is genuinely ~5/6 of the 60 Hz one
            us60 = _bmopf_matrices(_net_overhead("modified_carson", 60.0), "g", 60.0)
            @test 0.80 < us.X[1, 1] / us60.X[1, 1] < 0.87
        end

        @testset "synthetic overhead — Deri: X/mutual exact, self-R within convention" begin
            ods = _ods_matrices(_variant("synthetic_overhead.dss",
                                         "earthmodel=Carson" => "earthmodel=Deri"))
            us  = _bmopf_matrices(_net_overhead("deri", 60.0), "g", 60.0)
            # Reactance and mutual (off-diagonal) resistance match OpenDSS's
            # Deri to machine precision — the complex-depth external and
            # earth-return terms are identical. Only the self (diagonal)
            # earth-RESISTANCE can differ: a convention difference in the
            # complex-depth SELF term between the two Deri implementations. Our
            # modified_carson (the default) matches OpenDSS's Carson exactly
            # including self-R (test above). Documented, not papered over: if it
            # exceeds the retained 2% tolerance, this fails and points at the
            # self-term formula.
            offdiag = [(i, j) for i in 1:4 for j in 1:4 if i != j]
            @test relerr(us.X, ods.X) < 1e-4
            @test maximum(abs(us.R[i, j] - ods.R[i, j]) for (i, j) in offdiag) < 1e-9
            @test relerr(us.R, ods.R) < 0.02
        end

        @testset "concentric-neutral synthetic cable — R/X and coaxial shunt C" begin
            ods = _ods_matrices(joinpath(_dss_dir, "synthetic_cn.dss"))
            cn = Dict{String,Any}(
                "kind" => "cn_cable", "r_ac" => 0.00038,
                "gmr" => 0.004, "radius" => 0.006,
                "d_cable" => 0.032, "n_strands" => 12,
                "d_strand" => 0.0015, "gmr_strand" => 0.0006,
                "r_strand" => 0.012, "eps_r" => 2.7,
                "d_insulation" => 0.026, "t_insulation" => 0.007)
            net = Dict{String,Any}(
                "wire_data" => Dict{String,Any}("cn" => cn),
                "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
                    "frequency" => 60.0, "earth_model" => "modified_carson",
                    "earth_resistivity" => 100.0,
                    "conductors" => Any[
                        Dict{String,Any}("wire_data" => "cn", "x" => -0.22, "y" => -1.1, "terminal" => "a"),
                        Dict{String,Any}("wire_data" => "cn", "x" =>  0.03,       "y" => -1.1, "terminal" => "b"),
                        Dict{String,Any}("wire_data" => "cn", "x" =>  0.31, "y" => -1.1, "terminal" => "c")])))
            us = _bmopf_matrices(net, "g", 60.0)
            # both engines return the 3×3 phase matrix (CN strands reduced)
            @test size(us.R) == (3, 3)
            @test relerr(us.R, ods.R) < 1e-3
            @test relerr(us.X, ods.X) < 1e-3
            # coaxial phase-to-shield capacitance: diagonal, no interphase term
            @test relerr(us.C, ods.C) < 1e-3
            @test maximum(abs.(us.C[i, j] for i in 1:3 for j in 1:3 if i != j)) < 1e-12
        end

        @testset "tape-shield synthetic cable — 2×2 (shield reduced, neutral kept)" begin
            ods = _ods_matrices(joinpath(_dss_dir, "synthetic_ts.dss"))
            ts = Dict{String,Any}(
                "kind" => "ts_cable", "r_ac" => 0.00058,
                "gmr" => 0.0036, "radius" => 0.0048,
                "d_shield" => 0.024, "t_tape" => 0.00016, "tape_lap" => 25.0)
            nw = Dict{String,Any}(
                "kind" => "overhead", "r_ac" => 0.0009,
                "gmr" => 0.0025, "radius" => 0.0034)
            net = Dict{String,Any}(
                "wire_data" => Dict{String,Any}("ts" => ts, "return" => nw),
                "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
                    "frequency" => 60.0, "earth_model" => "modified_carson",
                    "earth_resistivity" => 100.0,
                    "conductors" => Any[
                        Dict{String,Any}("wire_data" => "ts", "x" => 0.0,          "y" => -1.25, "terminal" => "a"),
                        Dict{String,Any}("wire_data" => "return", "x" => 0.065, "y" => -1.25, "terminal" => "n")])))
            us = _bmopf_matrices(net, "g", 60.0)
            @test size(us.R) == (2, 2)
            @test relerr(us.R, ods.R) < 1e-3
            @test relerr(us.X, ods.X) < 1e-3
            # Compare neutral reduction against an explicit Schur complement of OpenDSS.
            Z = (us.R .+ im .* us.X)
            z1 = BMOPFTools._kron_reduce(Z, [1])[1, 1] * _MILE
            Zods = (ods.R + im * ods.X) * _MILE
            expected = Zods[1, 1] - Zods[1, 2] * Zods[2, 1] / Zods[2, 2]
            @test abs(z1 - expected) / abs(expected) < 1e-3
        end
    end
end
