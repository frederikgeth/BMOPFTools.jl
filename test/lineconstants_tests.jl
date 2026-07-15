# Geometry-based line-constants engine tests.
#
# Reference values are the published IEEE test-feeder / Kersting matrices
# (Kersting, "Distribution System Modeling and Analysis"; IEEE 13-bus test
# feeder documentation). The published matrices are Kron-reduced, so tests
# compute the full primitive matrix through the public API and apply the
# internal `_kron_reduce` — validating both the primitive matrix and the
# internal reduction without a public elimination pathway.

const _FT   = 0.3048        # ft  → m
const _IN   = 0.0254        # in  → m
const _MILE = 1609.344      # mile → m

# IEEE-13 conductor library (Kersting tables, imperial → SI at construction)
_wire_556_acsr() = Dict{String,Any}(       # 556,500 26/7 ACSR
    "kind" => "overhead", "r_ac" => 0.1859 / _MILE,
    "gmr" => 0.0313 * _FT, "radius" => 0.927 / 2 * _IN, "i_max" => 730.0)
_wire_4_0_acsr() = Dict{String,Any}(       # 4/0 6/1 ACSR
    "kind" => "overhead", "r_ac" => 0.592 / _MILE,
    "gmr" => 0.00814 * _FT, "radius" => 0.563 / 2 * _IN, "i_max" => 340.0)

# IEEE-13 pole-top spacing 500 (B-A-C-N): x-offsets 0 / 2.5 / 7 ft at 29 ft,
# neutral at (4, 25) ft. Conductor list ordered a, b, c, n so the compiled
# matrix rows are in phase order.
_geometry_601() = Dict{String,Any}(
    "frequency" => 60.0, "earth_resistivity" => 100.0,
    "earth_model" => "modified_carson",
    "conductors" => Any[
        Dict{String,Any}("wire_data" => "acsr556", "x" => 2.5 * _FT, "y" => 29.0 * _FT, "terminal" => "a"),
        Dict{String,Any}("wire_data" => "acsr556", "x" => 0.0 * _FT, "y" => 29.0 * _FT, "terminal" => "b"),
        Dict{String,Any}("wire_data" => "acsr556", "x" => 7.0 * _FT, "y" => 29.0 * _FT, "terminal" => "c"),
        Dict{String,Any}("wire_data" => "acsr40",  "x" => 4.0 * _FT, "y" => 25.0 * _FT, "terminal" => "n")])

_lc_z_permile(lc) = (BMOPFTools._pattern_keys_to_matrix(lc, "R_series_") .+
                     im .* BMOPFTools._pattern_keys_to_matrix(lc, "X_series_")) .* _MILE

@testset "Line constants — geometry-based impedance engine" begin

    @testset "pure overhead numerical API matches compiler and preserves scalar type" begin
        phase = _wire_556_acsr()
        neutral = _wire_4_0_acsr()
        geo = _geometry_601()
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
    # IEEE 13 config 601: overhead 4-wire, modified Carson, 60 Hz, ρ=100.
    # Published phase matrix (Ω/mile) is the Kron reduction of our 4×4.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "IEEE 13 config 601 — series Z vs published matrix" begin
        net = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("acsr556" => _wire_556_acsr(),
                                            "acsr40"  => _wire_4_0_acsr()),
            "line_geometry" => Dict{String,Any}("cfg601" => _geometry_601()))
        id = compile_linecode(net, "cfg601")
        @test id == "cfg601"
        lc = net["linecode"]["cfg601"]

        Z = _lc_z_permile(lc)
        @test size(Z) == (4, 4)
        @test lc["source"] == "geometry"
        @test lc["line_geometry"] == "cfg601"
        @test lc["derivation"]["method"] == "modified_carson"
        @test lc["i_max"] == [730.0, 730.0, 730.0, 340.0]

        Zred = BMOPFTools._kron_reduce(Z, [1, 2, 3])
        Z601 = [0.3465+1.0179im 0.1560+0.5017im 0.1580+0.4236im;
                0.1560+0.5017im 0.3375+1.0478im 0.1535+0.3849im;
                0.1580+0.4236im 0.1535+0.3849im 0.3414+1.0348im]
        @test maximum(abs.(Zred .- Z601)) < 5e-4    # published to 4 decimals

        # Shunt: engine keeps the full 4×4 C; reduce in potential form and
        # compare to the published 3×3 B matrix (μS/mile).
        Bfrom = BMOPFTools._pattern_keys_to_matrix(lc, "B_from_")
        Bto   = BMOPFTools._pattern_keys_to_matrix(lc, "B_to_")
        @test Bfrom ≈ Bto
        omega = 2pi * 60.0
        C4 = (Bfrom .+ Bto) ./ omega                # total per-metre C
        P4 = inv(C4)
        C3 = inv(BMOPFTools._kron_reduce_potential(P4, [1, 2, 3]))
        B3 = omega .* C3 .* _MILE .* 1e6            # μS/mile
        B601 = [ 6.2998 -1.9958 -1.2595;
                -1.9958  5.9597 -0.7417;
                -1.2595 -0.7417  5.6386]
        @test maximum(abs.(B3 .- B601)) < 1e-2   # published values are rounded
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Earth models agree at power frequency (sub-percent for distribution
    # geometry) and Deri ≠ Carson strictly (different formulations).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "earth models — modified/full Carson and Deri consistent" begin
        Zs = map(("modified_carson", "full_carson", "deri")) do model
            geo = _geometry_601(); geo["earth_model"] = model
            net = Dict{String,Any}(
                "wire_data" => Dict{String,Any}("acsr556" => _wire_556_acsr(),
                                                "acsr40"  => _wire_4_0_acsr()),
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
    # Concentric-neutral cable — Kersting Example 4.2 / IEEE 13 config 606:
    # three 250 kcmil AA CN cables, 6-in flat spacing. Each cable's CN is a
    # shield subconductor, internally reduced → compiled 3×3 compares
    # directly to the published matrix.
    # ─────────────────────────────────────────────────────────────────────────
    @testset "CN cable — IEEE 13 config 606" begin
        cn = Dict{String,Any}(
            "kind" => "cn_cable",
            "r_ac" => 0.4100 / _MILE, "gmr" => 0.0171 * _FT,
            "radius" => 0.567 / 2 * _IN,
            "d_cable" => 1.29 * _IN,
            "n_strands" => 13,
            "d_strand" => 0.0641 * _IN,
            "gmr_strand" => 0.00208 * _FT,
            "r_strand" => 14.8722 / _MILE)
        net = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("cn250" => cn),
            "line_geometry" => Dict{String,Any}("cfg606" => Dict{String,Any}(
                "frequency" => 60.0, "earth_resistivity" => 100.0,
                "conductors" => Any[
                    Dict{String,Any}("wire_data" => "cn250", "x" => -0.5 * _FT, "y" => -3.0 * _FT, "terminal" => "a"),
                    Dict{String,Any}("wire_data" => "cn250", "x" =>  0.0 * _FT, "y" => -3.0 * _FT, "terminal" => "b"),
                    Dict{String,Any}("wire_data" => "cn250", "x" =>  0.5 * _FT, "y" => -3.0 * _FT, "terminal" => "c")])))
        compile_linecode(net, "cfg606")
        lc = net["linecode"]["cfg606"]
        @test sort(lc["derivation"]["shields_reduced"]) == ["cn:1", "cn:2", "cn:3"]

        Z = _lc_z_permile(lc)
        Z606 = [0.7982+0.4463im 0.3192+0.0328im 0.2849-0.0143im;
                0.3192+0.0328im 0.7891+0.4041im 0.3192+0.0328im;
                0.2849-0.0143im 0.3192+0.0328im 0.7982+0.4463im]
        @test maximum(abs.(Z .- Z606)) < 2e-3
    end

    # ─────────────────────────────────────────────────────────────────────────
    # Tape-shield cable — Kersting Example 4.3 / IEEE 13 config 607:
    # 1/0 AA TS cable + separate 1/0 Cu neutral 1 in away (spacing ID 520).
    # Engine output is
    # the full 2×2 (phase + neutral, shield internally reduced); the
    # published value is the further neutral-reduced 1×1.
    # tape_lap=50 reproduces Kersting's shield-resistance convention
    # r = ρ_cu/(π·d_s·t).
    # ─────────────────────────────────────────────────────────────────────────
    @testset "TS cable — IEEE 13 config 607" begin
        ts = Dict{String,Any}(
            "kind" => "ts_cable",
            "r_ac" => 0.97 / _MILE, "gmr" => 0.0111 * _FT,
            "radius" => 0.368 / 2 * _IN,
            "d_shield" => 0.88 * _IN,
            "t_tape" => 5.0 * 1e-3 * _IN,     # 5 mil
            "tape_lap" => 50.0)
        nw = Dict{String,Any}(                 # 1/0 copper, 7 strand
            "kind" => "overhead",
            "r_ac" => 0.607 / _MILE, "gmr" => 0.01113 * _FT,
            "radius" => 0.368 / 2 * _IN)
        net = Dict{String,Any}(
            "wire_data" => Dict{String,Any}("ts10" => ts, "cu10" => nw),
            "line_geometry" => Dict{String,Any}("cfg607" => Dict{String,Any}(
                "frequency" => 60.0, "earth_resistivity" => 100.0,
                "conductors" => Any[
                    Dict{String,Any}("wire_data" => "ts10", "x" => 0.0,       "y" => -3.0 * _FT, "terminal" => "a"),
                    Dict{String,Any}("wire_data" => "cu10", "x" => 1.0 * _IN, "y" => -3.0 * _FT, "terminal" => "n")])))
        compile_linecode(net, "cfg607")
        lc = net["linecode"]["cfg607"]
        @test lc["derivation"]["shields_reduced"] == ["ts:1"]

        Z = _lc_z_permile(lc)
        @test size(Z) == (2, 2)
        z1 = BMOPFTools._kron_reduce(Z, [1])
        @test abs(z1[1, 1] - (1.3425 + 0.5124im)) < 2e-3
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
            "wire_data" => Dict{String,Any}("acsr556" => _wire_556_acsr(),
                                            "acsr40"  => _wire_4_0_acsr()),
            "line_geometry" => Dict{String,Any}("cfg601" => _geometry_601()),
            "load" => Dict{String,Any}("ld" => Dict{String,Any}(
                "bus" => "b1", "terminal_map" => ["a", "b", "c", "n"],
                "configuration" => "WYE",
                "p_nom" => [50e3, 50e3, 50e3], "q_nom" => [10e3, 10e3, 10e3])))
        compile_linecodes!(net)
        net["line"] = Dict{String,Any}("l1" => Dict{String,Any}(
            "bus_from" => "src", "bus_to" => "b1",
            "terminal_map_from" => ["a", "b", "c", "n"],
            "terminal_map_to"   => ["a", "b", "c", "n"],
            "linecode" => "cfg601", "length" => 610.0))

        # write → parse round trip preserves the new libraries
        path = joinpath(mktempdir(), "geom.json")
        write_bmopf(net, path)
        net2 = parse_bmopf(path)
        @test haskey(net2, "wire_data") && haskey(net2["wire_data"], "acsr556")
        @test haskey(net2, "line_geometry")
        @test net2["linecode"]["cfg601"]["line_geometry"] == "cfg601"
        @test net2["linecode"]["cfg601"]["R_series_1_1"] ≈
              net["linecode"]["cfg601"]["R_series_1_1"]

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
        net2["linecode"]["cfg601"]["R_series_1_1"] *= 1.5
        report2 = analyze(net2)
        @test "W.PROV.GEOMETRY_MISMATCH" in [f.code for f in report2.findings]

        # dangling references are caught
        net3 = deepcopy(net)
        net3["line_geometry"]["cfg601"]["conductors"][1]["wire_data"] = "missing"
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
                    "linecode" => "cfg601", "length" => 610.0)),
                "load" => Dict{String,Any}("ld" => Dict{String,Any}(
                    "bus" => "b1", "terminal_map" => ["a", "b", "c", "n"],
                    "configuration" => "WYE",
                    "p_nom" => [200e3, 150e3, 100e3],
                    "q_nom" => [60e3, 40e3, 20e3])))

            net_geo = build()
            net_geo["wire_data"] = Dict{String,Any}(
                "acsr556" => _wire_556_acsr(), "acsr40" => _wire_4_0_acsr())
            net_geo["line_geometry"] = Dict{String,Any}("cfg601" => _geometry_601())
            compile_linecodes!(net_geo)

            net_direct = build()
            lc = deepcopy(net_geo["linecode"]["cfg601"])
            delete!(lc, "source"); delete!(lc, "line_geometry"); delete!(lc, "derivation")
            net_direct["linecode"] = Dict{String,Any}("cfg601" => lc)

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
        # the 601 geometry at 50 Hz: modified vs full Carson still agree to
        # <1 % of the matrix scale, and X(50)/X(60) of the self term tracks
        # ω up to the slowly-varying ln(De) term (≈ 3 % effect)
        function z11(f, model)
            net = Dict{String,Any}(
                "wire_data" => Dict{String,Any}("acsr556" => _wire_556_acsr(),
                                                "acsr40"  => _wire_4_0_acsr()),
                "line_geometry" => Dict{String,Any}("g" => _geometry_601()))
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
# _HAS_ODS so CI without OpenDSS still runs the published-literal tests above.
#
# Geometry-defined linecodes do NOT round-trip through PowerIO yet, so we can't
# use `from_dss`. Instead OpenDSS computes the matrices from hand-written
# WireData/CNData/TSData + LineGeometry decks (test/data/line_geometry/*.dss),
# and BMOPFTools builds the SAME geometry independently as wire_data/
# line_geometry — a separate transcription of the identical physical data. The
# two engines' matrices are then compared.
#
# Complementary to the published-literal tests: those pin us to Kersting's
# MODIFIED-CARSON numbers; this pins us to OpenDSS's own engine across all four
# earth-model/frequency combinations (Carson, FullCarson, Deri, and 50 Hz) and
# across overhead, concentric-neutral, and tape-shield construction — including
# cases (Deri, cable shunt C) for which no published reference matrix exists.
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

        # Overhead config 601, hand-built, at a given earth model and frequency.
        function _net_601(earth_model, f)
            geo = _geometry_601()
            geo["earth_model"] = earth_model; geo["frequency"] = f
            Dict{String,Any}(
                "wire_data" => Dict{String,Any}("acsr556" => _wire_556_acsr(),
                                                "acsr40"  => _wire_4_0_acsr()),
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

        @testset "overhead 601 — Carson ≡ modified_carson (60 Hz), R/X/C tight" begin
            ods = _ods_matrices(joinpath(_dss_dir, "ieee13_601.dss"))
            us  = _bmopf_matrices(_net_601("modified_carson", 60.0), "g", 60.0)
            @test relerr(us.R, ods.R) < 1e-4
            @test relerr(us.X, ods.X) < 1e-4
            @test relerr(us.C, ods.C) < 1e-3
        end

        @testset "overhead 601 — FullCarson ≡ full_carson (60 Hz)" begin
            ods = _ods_matrices(_variant("ieee13_601.dss",
                                         "earthmodel=Carson" => "earthmodel=FullCarson"))
            us  = _bmopf_matrices(_net_601("full_carson", 60.0), "g", 60.0)
            @test relerr(us.R, ods.R) < 1e-4
            @test relerr(us.X, ods.X) < 1e-4
        end

        @testset "overhead 601 — 50 Hz Carson (frequency handled from ω, no rescale)" begin
            ods = _ods_matrices(_variant("ieee13_601.dss",
                                         "defaultbasefreq=60" => "defaultbasefreq=50"))
            us  = _bmopf_matrices(_net_601("modified_carson", 50.0), "g", 50.0)
            @test relerr(us.R, ods.R) < 1e-4
            @test relerr(us.X, ods.X) < 1e-4
            # sanity: the 50 Hz reactance is genuinely ~5/6 of the 60 Hz one
            us60 = _bmopf_matrices(_net_601("modified_carson", 60.0), "g", 60.0)
            @test 0.80 < us.X[1, 1] / us60.X[1, 1] < 0.87
        end

        @testset "overhead 601 — Deri: X/mutual exact, self-R within convention" begin
            ods = _ods_matrices(_variant("ieee13_601.dss",
                                         "earthmodel=Carson" => "earthmodel=Deri"))
            us  = _bmopf_matrices(_net_601("deri", 60.0), "g", 60.0)
            # Reactance and mutual (off-diagonal) resistance match OpenDSS's
            # Deri to machine precision — the complex-depth external and
            # earth-return terms are identical. Only the self (diagonal)
            # earth-RESISTANCE differs, by up to ~1.6 % (largest on the
            # smaller-GMR neutral): a genuine convention difference in the
            # complex-depth SELF term between the two Deri implementations. Our
            # modified_carson (the default) matches OpenDSS's Carson exactly
            # including self-R (test above). Documented, not papered over: if it
            # widens, this fails and points at the self-term formula.
            offdiag = [(i, j) for i in 1:4 for j in 1:4 if i != j]
            @test relerr(us.X, ods.X) < 1e-4
            @test maximum(abs(us.R[i, j] - ods.R[i, j]) for (i, j) in offdiag) < 1e-9
            @test relerr(us.R, ods.R) < 0.02
        end

        @testset "concentric-neutral cable 606 — R/X and coaxial shunt C" begin
            ods = _ods_matrices(joinpath(_dss_dir, "ieee13_606_cn.dss"))
            cn = Dict{String,Any}(
                "kind" => "cn_cable", "r_ac" => 0.4100 / _MILE,
                "gmr" => 0.0171 * _FT, "radius" => 0.2835 * _IN,
                "d_cable" => 1.29 * _IN, "n_strands" => 13,
                "d_strand" => 0.0641 * _IN, "gmr_strand" => 0.00208 * _FT,
                "r_strand" => 14.8722 / _MILE, "eps_r" => 2.3,
                "d_insulation" => 1.06 * _IN, "t_insulation" => 0.220 * _IN)
            net = Dict{String,Any}(
                "wire_data" => Dict{String,Any}("cn250" => cn),
                "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
                    "frequency" => 60.0, "earth_model" => "modified_carson",
                    "earth_resistivity" => 100.0,
                    "conductors" => Any[
                        Dict{String,Any}("wire_data" => "cn250", "x" => -0.5 * _FT, "y" => -3.0 * _FT, "terminal" => "a"),
                        Dict{String,Any}("wire_data" => "cn250", "x" =>  0.0,       "y" => -3.0 * _FT, "terminal" => "b"),
                        Dict{String,Any}("wire_data" => "cn250", "x" =>  0.5 * _FT, "y" => -3.0 * _FT, "terminal" => "c")])))
            us = _bmopf_matrices(net, "g", 60.0)
            # both engines return the 3×3 phase matrix (CN strands reduced)
            @test size(us.R) == (3, 3)
            @test relerr(us.R, ods.R) < 1e-3
            @test relerr(us.X, ods.X) < 1e-3
            # coaxial phase-to-shield capacitance: diagonal, no interphase term
            @test relerr(us.C, ods.C) < 1e-3
            @test maximum(abs.(us.C[i, j] for i in 1:3 for j in 1:3 if i != j)) < 1e-12
        end

        @testset "tape-shield cable 607 — 2×2 (shield reduced, neutral kept)" begin
            ods = _ods_matrices(joinpath(_dss_dir, "ieee13_607_ts.dss"))
            ts = Dict{String,Any}(
                "kind" => "ts_cable", "r_ac" => 0.97 / _MILE,
                "gmr" => 0.0111 * _FT, "radius" => 0.184 * _IN,
                "d_shield" => 0.88 * _IN, "t_tape" => 0.005 * _IN, "tape_lap" => 50.0)
            nw = Dict{String,Any}(
                "kind" => "overhead", "r_ac" => 0.607 / _MILE,
                "gmr" => 0.01113 * _FT, "radius" => 0.184 * _IN)
            net = Dict{String,Any}(
                "wire_data" => Dict{String,Any}("ts10" => ts, "cu10" => nw),
                "line_geometry" => Dict{String,Any}("g" => Dict{String,Any}(
                    "frequency" => 60.0, "earth_model" => "modified_carson",
                    "earth_resistivity" => 100.0,
                    "conductors" => Any[
                        Dict{String,Any}("wire_data" => "ts10", "x" => 0.0,          "y" => -3.0 * _FT, "terminal" => "a"),
                        Dict{String,Any}("wire_data" => "cu10", "x" => 0.0833 * _FT, "y" => -3.0 * _FT, "terminal" => "n")])))
            us = _bmopf_matrices(net, "g", 60.0)
            @test size(us.R) == (2, 2)
            @test relerr(us.R, ods.R) < 1e-3
            @test relerr(us.X, ods.X) < 1e-3
            # neutral-reduced 1×1 matches Kersting's published 607 value
            Z = (us.R .+ im .* us.X)
            z1 = BMOPFTools._kron_reduce(Z, [1])[1, 1] * _MILE
            @test abs(z1 - (1.3425 + 0.5124im)) < 2e-3
        end
    end
end
