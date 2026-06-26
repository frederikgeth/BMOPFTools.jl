# phase_relabel_tests.jl
#
# Tests for deliberate or accidental phase relabelings.
#
# Two distinct failure modes are covered:
#
#   (1) An *inconsistent* relabel — a single component wired to the wrong
#       phase/neutral, or with from/to maps that disagree. These are detectable
#       statically by spec_conformance_check (the E/I.TMAP family) without a
#       solver, and the first two testsets pin every branch of that checker.
#
#   (2) A *consistent* relabel — every component on a feeder has its phase
#       labels permuted the same way. This is structurally invisible (each map
#       is still internally ordered and from==to), so it can only be caught
#       electrically: a true relabeling must leave the physical solution
#       invariant up to the same permutation. The final (solver-gated) testset
#       checks that, plus the negative case where relabeling ONE component
#       moves load onto the wrong phase and the solution must change.

# ── Phase-relabel helper ──────────────────────────────────────────────────────
# Substitute phase-terminal names via the bijection `π` in every terminal-label
# field. Per-phase numeric arrays (v_min, p_nom, v_magnitude, …) are positional
# and deliberately left untouched: the data travels with its renamed conductor,
# so a uniform substitution is a pure, physics-preserving relabeling.
function _relabel_phases!(net::Dict{String,Any}, π::Dict{String,String})
    sub(v) = [get(π, string(t), string(t)) for t in v]
    for (_, bus) in get(net, "bus", Dict())
        bus isa Dict || continue
        haskey(bus, "terminal_names") && (bus["terminal_names"] = sub(bus["terminal_names"]))
        haskey(bus, "perfectly_grounded_terminals") &&
            (bus["perfectly_grounded_terminals"] = sub(bus["perfectly_grounded_terminals"]))
    end
    for ct in ("load", "generator", "shunt", "voltage_source", "inverter")
        for (_, c) in get(net, ct, Dict())
            c isa Dict && haskey(c, "terminal_map") && (c["terminal_map"] = sub(c["terminal_map"]))
        end
    end
    for ct in ("line", "switch")
        for (_, c) in get(net, ct, Dict())
            c isa Dict || continue
            haskey(c, "terminal_map_from") && (c["terminal_map_from"] = sub(c["terminal_map_from"]))
            haskey(c, "terminal_map_to")   && (c["terminal_map_to"]   = sub(c["terminal_map_to"]))
        end
    end
    net
end

# Minimal clean 3-phase, 4-wire single-line feeder with an UNBALANCED load so
# the three phase voltages are distinct — a relabel that silently dropped a
# phase would not be masked by symmetry. Diagonal linecode ⇒ phases decouple.
_relabel_feeder() = parse_bmopf("""
{"bus":{
    "src":{"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"]},
    "b1": {"terminal_names":["1","2","3","n"],"perfectly_grounded_terminals":["n"],
           "v_min":[900.0,900.0,900.0],"v_max":[1010.0,1010.0,1010.0]}},
 "voltage_source":{"vs":{"bus":"src","terminal_map":["1","2","3"],
     "v_magnitude":[1000.0,1000.0,1000.0],"v_angle":[0.0,-2.0944,2.0944]}},
 "linecode":{"lc":{"R_series_1_1":0.5,"R_series_2_2":0.5,"R_series_3_3":0.5}},
 "line":{"l1":{"bus_from":"src","bus_to":"b1",
     "terminal_map_from":["1","2","3"],"terminal_map_to":["1","2","3"],
     "linecode":"lc","length":1.0}},
 "load":{"ld1":{"bus":"b1","terminal_map":["1","2","3","n"],"configuration":"WYE",
     "p_nom":[100000.0,50000.0,25000.0],"q_nom":[0.0,0.0,0.0]}}}
"""; from_string=true)

@testset "Phase relabeling" begin

    # ── Static detection — fills the untested branches of the TMAP checker ─────
    @testset "static detection of inconsistent relabelings" begin
        # Base 3-phase fixture with a switch in addition to the line.
        base() = parse_bmopf("""
        {"bus":{
            "src":{"terminal_names":["a","b","c","n"],"perfectly_grounded_terminals":["n"]},
            "b1": {"terminal_names":["a","b","c","n"],"perfectly_grounded_terminals":["n"]}},
         "voltage_source":{"vs":{"bus":"src","terminal_map":["a","b","c"],
             "v_magnitude":[1e4,1e4,1e4],"v_angle":[0.0,-2.094,2.094]}},
         "linecode":{"lc":{"R_series_1_1":0.1,"R_series_2_2":0.1,"R_series_3_3":0.1}},
         "line":{"l1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["a","b","c"],"terminal_map_to":["a","b","c"],
             "linecode":"lc","length":100.0}},
         "switch":{"sw1":{"bus_from":"src","bus_to":"b1",
             "terminal_map_from":["a","b","c"],"terminal_map_to":["a","b","c"]}},
         "load":{"ld1":{"bus":"b1","terminal_map":["a","b","c","n"],"configuration":"WYE",
             "p_nom":[1e4,1e4,1e4],"q_nom":[0.0,0.0,0.0]}}}
        """; from_string=true)

        # Switch with disagreeing from/to maps → cross-phase on a SWITCH.
        net = base()
        net["switch"]["sw1"]["terminal_map_to"] = ["b","a","c"]
        f = Finding[]; res = spec_conformance_check(net, f)
        @test res["n_cross_phase_lines"] >= 1
        @test any(x.code == "I.TMAP.CROSS_PHASE_LINE" &&
                  x.component_type == :switch && x.component_id == "sw1" for x in f)

        # Line end whose map is permuted vs the bus order (from==to so it is NOT
        # cross-phase) → PERMUTED_ORDER on the line end.
        net2 = base()
        net2["line"]["l1"]["terminal_map_from"] = ["b","a","c"]
        net2["line"]["l1"]["terminal_map_to"]   = ["b","a","c"]
        f2 = Finding[]; res2 = spec_conformance_check(net2, f2)
        @test res2["n_cross_phase_lines"] == 0          # from == to
        @test any(x.code == "I.TMAP.PERMUTED_ORDER" && x.component_id == "l1" for x in f2)

        # DELTA component has no neutral slot — a neutral anywhere is a phase error.
        net3 = base()
        net3["load"]["dl"] = Dict{String,Any}(
            "bus" => "b1", "terminal_map" => ["a","n","c"], "configuration" => "DELTA",
            "p_nom" => [1e4,1e4,1e4], "q_nom" => [0.0,0.0,0.0])
        f3 = Finding[]; spec_conformance_check(net3, f3)
        @test any(x.code == "E.TMAP.PHASE_TO_NEUTRAL" && x.component_id == "dl" for x in f3)

        # Transformers are exempt from the order/cross-phase rules: a permuted
        # winding map must NOT raise PERMUTED_ORDER or CROSS_PHASE.
        net4 = base()
        net4["transformer"] = Dict{String,Any}("wye_delta" => Dict{String,Any}(
            "tx" => Dict{String,Any}(
                "bus_from" => "src", "bus_to" => "b1",
                "terminal_map_from" => ["b","a","c","n"],   # permuted on purpose
                "terminal_map_to"   => ["c","b","a"],
                "v_ref_from" => 1e4, "v_ref_to" => 400.0)))
        f4 = Finding[]; spec_conformance_check(net4, f4)
        @test !any(x.component_id == "tx" &&
                   x.code in ("I.TMAP.PERMUTED_ORDER", "I.TMAP.CROSS_PHASE_LINE") for x in f4)
    end

    # ── Relabel helper correctness + consistent/inconsistent distinction ───────
    @testset "relabel helper and consistency invariants" begin
        π = Dict("1" => "2", "2" => "1")   # swap phases 1 and 2 (self-inverse)

        # Helper rewrites every terminal-label field.
        net = _relabel_feeder()
        _relabel_phases!(net, π)
        @test net["bus"]["b1"]["terminal_names"] == ["2","1","3","n"]
        @test net["load"]["ld1"]["terminal_map"] == ["2","1","3","n"]
        @test net["line"]["l1"]["terminal_map_from"] == ["2","1","3"]
        @test net["voltage_source"]["vs"]["terminal_map"] == ["2","1","3"]

        # Applying a self-inverse relabel twice restores the original labels.
        rt = _relabel_feeder(); _relabel_phases!(_relabel_phases!(rt, π), π)
        orig = _relabel_feeder()
        @test rt["bus"]["b1"]["terminal_names"]      == orig["bus"]["b1"]["terminal_names"]
        @test rt["load"]["ld1"]["terminal_map"]      == orig["load"]["ld1"]["terminal_map"]
        @test rt["line"]["l1"]["terminal_map_from"]  == orig["line"]["l1"]["terminal_map_from"]
        @test rt["voltage_source"]["vs"]["terminal_map"] == orig["voltage_source"]["vs"]["terminal_map"]

        # A CONSISTENT relabel is clean: it introduces no new TMAP findings.
        fb = Finding[]; rb = spec_conformance_check(_relabel_feeder(), fb)
        consistent = _relabel_feeder(); _relabel_phases!(consistent, π)
        fc = Finding[]; rc = spec_conformance_check(consistent, fc)
        @test rc["n_permuted_terminal_maps"] == rb["n_permuted_terminal_maps"]
        @test rc["n_cross_phase_lines"]      == rb["n_cross_phase_lines"]
        @test rc["n_phase_to_neutral"]       == rb["n_phase_to_neutral"]

        # An INCONSISTENT relabel — only ld1's map swapped — is flagged permuted.
        inconsistent = _relabel_feeder()
        inconsistent["load"]["ld1"]["terminal_map"] = ["2","1","3","n"]
        fi = Finding[]; ri = spec_conformance_check(inconsistent, fi)
        @test ri["n_permuted_terminal_maps"] > rb["n_permuted_terminal_maps"]
        @test any(x.code == "I.TMAP.PERMUTED_ORDER" && x.component_id == "ld1" for x in fi)
    end

    # ── Electrical invariance under a consistent relabel (needs a solver) ──────
    @testset "OPF solution is invariant under a consistent relabel" begin
        if !_HAS_JUMP_IPOPT
            @test_skip "JuMP/Ipopt not in load path"
        else
            π = Dict("1" => "2", "2" => "1")

            base = solve_opf(_relabel_feeder())
            @test base["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

            relabeled_net = _relabel_feeder(); _relabel_phases!(relabeled_net, π)
            rel = solve_opf(relabeled_net)
            @test rel["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

            # The unbalanced load gives three distinct phase voltages; a correct
            # relabel must permute them by π (vm at "1" ↔ vm at "2", "3" fixed).
            for t in ("1", "2", "3")
                @test isapprox(rel["bus"]["b1"][t]["vm"],
                               base["bus"]["b1"][get(π, t, t)]["vm"]; atol=1e-3, rtol=1e-6)
            end
            # Sanity: the phases really are distinct, so the test has teeth.
            @test !isapprox(base["bus"]["b1"]["1"]["vm"],
                            base["bus"]["b1"]["2"]["vm"]; atol=1e-2)

            # Negative case: relabel ONE component only (move ld1 onto swapped
            # phases). The network is now physically different and the solution
            # at the affected phases must change.
            miswired_net = _relabel_feeder()
            miswired_net["load"]["ld1"]["terminal_map"] = ["2","1","3","n"]
            mis = solve_opf(miswired_net)
            @test mis["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test !isapprox(mis["bus"]["b1"]["1"]["vm"],
                            base["bus"]["b1"]["1"]["vm"]; atol=1e-2)
        end
    end
end
