# Optional integration tests for the external CC BY-NC-SA dataset.
# Included by runtests.jl only when BMOPF_RESTRICTED_DATA is explicitly set.
const _RESTRICTED_DATA = abspath(ENV["BMOPF_RESTRICTED_DATA"])
const _TS_FIXTURE_PATH = joinpath(_RESTRICTED_DATA, "LV", "lv1_14bus_timeseries.json")
for path in (joinpath(_RESTRICTED_DATA, "LV", "LV1_14bus", "Master.dss"), _TS_FIXTURE_PATH)
    isfile(path) || error("Missing external dataset fixture: $path")
end

@testset "from_dss — source ledger on a real feeder" begin
        net = from_dss(joinpath(_RESTRICTED_DATA, "LV", "LV1_14bus", "Master.dss"))
        mapping = net["_meta"]["powerio_source_mapping"]
        # OpenDSS carries a length and a linecode on a switch-as-line. BMOPF
        # models a switch as an ideal closure, so dropping them changes no
        # physics — the catch-all "unknown field ⇒ blocking" rule must not fire.
        @test "length" in mapping["unmapped_fields"]
        @test "linecode" in mapping["unmapped_fields"]
        @test "length" ∉ mapping["blocking_unmapped_fields"]
        @test "linecode" ∉ mapping["blocking_unmapped_fields"]
        for field in ("length", "linecode")
            record = mapping["by_field"][field]
            @test record["physical_readiness_blocking"] == false
            @test record["impact"] == "representational"
            @test record["reason"] ==
                  "switch_is_an_ideal_closure_with_no_series_impedance"
            @test all(startswith("switch:"), record["unmapped_scopes"])
        end
        @test mapping["blocking_unmapped_fields"] == String[]

        # PowerIO 0.9 returns owned diagnostic records rather than capping a
        # per-call channel, so even this feeder's long list arrives complete and
        # the ledger's empty blocking list IS a fidelity statement. (Under
        # PowerIO <= 0.7 the list was truncated and the status had to say so.)
        @test !any(contains("warning list truncated"), net["_meta"]["powerio_warnings"])
        @test mapping["warnings_truncated_upstream"] == false
        @test mapping["warning_status"] == "partially_classified"
        @test Set(first(split(message, ":")) for message in mapping["unclassified_warnings"]) ==
            Set(["PARSE.DSS.SOURCE_MALFORMED", "READ.DSS.RETAINED_SOURCE_ONLY"])

        # The same field name is only benign for the kind it was classified on:
        # a `length` dropped from a line would still block.
        @test BMOPFTools._powerio_mapping_policy("length", ["switch:s1"]).blocking == false
        @test BMOPFTools._powerio_mapping_policy("length", ["line:l1"]).blocking == true
        @test BMOPFTools._powerio_mapping_policy(
            "length", ["switch:s1", "line:l1"]).blocking == true
    end

@testset "LV1_14bus — OpenDSS integration" begin
        dss_master = joinpath(_RESTRICTED_DATA, "LV", "LV1_14bus", "Master.dss")

        # Parse OpenDSS directly to BMOPF via PowerIO.jl
        net = from_dss(dss_master)
        @test net isa Dict{String,Any}

        @testset "Network structure" begin
            # Single 11 kV voltage source at B2577
            @test length(get(net, "voltage_source", Dict())) == 1

            # Single delta-wye transformer (11 kV → 433 V, Tx3170)
            xfmr = get(net, "transformer", Dict())
            @test haskey(xfmr, "delta_wye")
            @test length(xfmr["delta_wye"]) == 1
            tx = first(values(xfmr["delta_wye"]))
            @test tx["v_nom_from"] > tx["v_nom_to"]               # step-down
            @test tx["v_nom_from"] / tx["v_nom_to"] ≈ 11.0/0.433  rtol=0.02
            # PowerIO emits a lumped Γ-model, wye-base-referred; the parse-time
            # migration normalises it onto the wye winding's own field (delta_wye
            # has wye = to) so a nonzero leakage impedance reaches the OPF/Ybus
            # builders (not silently zero, and not double-referred).
            @test haskey(tx, "r_series_to") && tx["r_series_to"] > 0
            @test haskey(tx, "x_series_to") && tx["x_series_to"] > 0
            @test !haskey(tx, "r_series") && !haskey(tx, "x_series")
            # spec arity: delta side 3 terminals, wye side 4 (incl. neutral)
            @test length(tx["terminal_map_from"]) == 3
            @test length(tx["terminal_map_to"])   == 4
            # OpenDSS earth terminal "5" is routed to the bus neutral, so the
            # earthed star point lands on "n" rather than a phantom terminal.
            @test "n" in tx["terminal_map_to"]
            @test !("5" in string.(tx["terminal_map_to"]))

            # No phantom slack generator; from_dss does not price slack cost.
            @test !any(get(g, "_slack", false) for g in values(get(net, "generator", Dict())))
            vs = first(values(net["voltage_source"]))
            @test !haskey(vs, "p_max")           # unbounded slack

            # 2-terminal loads are SINGLE_PHASE per spec
            @test all(l["configuration"] == "SINGLE_PHASE"
                      for (_, l) in net["load"]
                      if length(l["terminal_map"]) == 2)

            # 9 cable segments (lines.dss)
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

            # Terminal naming is consistent: every bus uses a/b/c/n and no bus
            # retains the OpenDSS earth terminal "5" (B179 carries the earthed
            # transformer star point). The routing is recorded in _meta.
            @test all(!("5" in string.(get(b, "terminal_names", [])))
                      for b in values(net["bus"]))
            # Identifiers are case-folded on ingest (OpenDSS B179 → b179).
            @test all(k -> k == lowercase(k), keys(net["bus"]))
            @test net["bus"]["b179"]["terminal_names"] == ["a", "b", "c", "n"]
            @test get(net["bus"]["b179"], "neutral_terminal", nothing) == "n"
            @test "b179" in net["_meta"]["earth_terminal_routing"]["buses"]
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

            # Clean network: no ERRORs from completeness, schema, or voltage checks.
            # (Requires the grounding reactors to be mapped — PowerIO ≥ 0.2.2.)
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

            # Provenance: real data with explicit groundings — no Kron flag.
            prov = report.results[:provenance]
            @test prov["grounding"]["convention"] == "explicit"
            @test !any(f -> f.code == "I.PROV.KRON_LIKELY", report.findings)
            lv_levels = [info for (_, info) in prov["wires_by_level"]
                         if info["is_lv"]]
            @test !isempty(lv_levels)
        end
    end

@testset "Earth routing and transformer terminals survive JSON (#163)" begin
    net = from_dss(joinpath(_RESTRICTED_DATA, "LV", "LV1_14bus", "Master.dss"))
    xf = only(values(net["transformer"]["delta_wye"]))
    @test xf["bus_to"] == "b179"
    @test xf["terminal_map_to"] == ["a", "b", "c", "n"]
    @test net["bus"]["b179"]["neutral_terminal"] == "n"
    io = IOBuffer(); write_bmopf(net, io)
    restored = parse_bmopf(String(take!(io)); from_string=true)
    @test restored["bus"]["b179"] == net["bus"]["b179"]
    @test only(values(restored["transformer"]["delta_wye"])) == xf
    @test restored["_meta"]["earth_terminal_routing"] == net["_meta"]["earth_terminal_routing"]
end

    @testset "fixture — lv1_14bus_timeseries loads and analyzes" begin
        net = parse_bmopf(_TS_FIXTURE_PATH)
        @test is_timeseries(net)
        @test length(net["time_series"]["residential_daily"]["values"]) == 24
        @test length(net["time_series"]["solar_daily"]["values"]) == 24
        @test all(haskey(l, "time_series") for (_, l) in net["load"])
        @test all(haskey(i, "time_series") for (_, i) in net["ibr"])

        report = analyze(net)                       # defaults to t_index = 1
        @test isempty(errors(report))
        report24 = analyze(net; t_index = 24)       # kwarg threads through
        @test isempty(errors(report24))
        @test_throws BoundsError analyze(net; t_index = 25)

        # 03:00 (t=4): no sun, light load; 12:00 (t=13): full sun
        snap_night = get_snapshot(net, 4)
        snap_noon  = get_snapshot(net, 13)
        @test snap_night["ibr"]["pv_b3230"]["p_max"] ≈ [0.0]
        @test snap_night["load"]["ld3313_load_a"]["p_nom"] ≈ [2700.0]  # 0.27 × 10 kW
        @test snap_noon["ibr"]["pv_b3230"]["p_max"]  ≈ [15000.0]
        @test snap_noon["ibr"]["pv_b3230"]["p_avail"] ≈ 15000.0        # scalar path
        @test snap_noon["load"]["ld3313_load_a"]["p_nom"] ≈ [4000.0]   # 0.40 × 10 kW
    end

    @testset "fixture — OPF across snapshots (gated)" begin
        if !_HAS_JUMP_IPOPT
            @test_skip "JuMP/Ipopt not in load path"
        else
            net = parse_bmopf(_TS_FIXTURE_PATH)
            net_ready, _ = augment_case(net; recipe = AugmentationRecipe())
            @test is_timeseries(net_ready)   # augmentation preserves ts refs
            opt = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)

            grid_p(res) = sum(v["ps"] for v in values(first(values(res["voltage_source"])))) +
                          sum(sum(ph["pg"] for ph in values(g)) for g in values(get(res, "generator", Dict())); init = 0.0)
            pv_p(res)   = sum(sum(ph["pg"] for ph in values(res["ibr"][id])) for id in keys(res["ibr"]))

            res_noon = solve_opf(net_ready; optimizer = opt, per_unit = true, t_index = 13)
            res_eve  = solve_opf(net_ready; optimizer = opt, per_unit = true, t_index = 20)
            @test res_noon["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test res_eve["termination_status"]  in ("LOCALLY_SOLVED", "OPTIMAL")

            # different snapshots → different dispatch
            @test !isapprox(res_noon["objective"], res_eve["objective"]; rtol = 1e-3)
            @test pv_p(res_noon) ≈ 30_000.0 atol = 10.0      # both PVs at full output
            @test pv_p(res_eve)  ≈ 0.0      atol = 1.0       # no sun at 19:00
            @test grid_p(res_noon) < 0                       # midday reverse flow
            @test grid_p(res_eve)  > 0                       # evening import

            # t_index kwarg ≡ explicit get_snapshot round-trip
            res_manual = solve_opf(get_snapshot(net_ready, 13);
                                   optimizer = opt, per_unit = true)
            @test res_manual["objective"] ≈ res_noon["objective"] rtol = 1e-6

            # profile_solution accepts the ts net + t_index and stays clean
            sol_report = profile_solution(net_ready, res_noon; t_index = 13)
            @test isempty(errors(sol_report))
        end
    end