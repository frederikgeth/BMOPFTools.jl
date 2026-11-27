# Voltage-reference evidence (src/validation/voltage_reference.jl): which
# conductor groups an element ties to earth, and the integrity findings built on it.

using Test
using BMOPFTools
isdefined(@__MODULE__, :_PG_PF) || include("profiler_test_helpers.jl")

@testset "Profiler: voltage reference" begin
    @testset "transformer neutral impedance is a voltage reference" begin
        # Dyn transformer whose LV star point is earthed only through its own
        # rneut/xneut. OpenDSS solves this deck; the island is referenced.
        net = _pg_dss("pf_dy_xfmr_rneut.dss")
        xf = net["transformer"]["delta_wye"]["t1"]
        @test xf["r_neutral_to"] > 0
        @test isempty(get(net["bus"]["lv"], "perfectly_grounded_terminals", String[]))
        earth = BMOPFTools._transformer_neutral_earthing(net)
        @test haskey(earth, ("lv", "n"))
        @test earth[("lv", "n")] ≈ hypot(xf["r_neutral_to"], xf["x_neutral_to"])
        report = _pg_analyze(net)
        @test !("E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(report.findings))
        @test !("E.PROV.FLOATING_NEUTRAL" in _pg_codes(report.findings))
        @test report.results[:integrity]["n_without_reference"] == 0

        # Negative: remove the neutral impedance and the same island floats.
        bare = deepcopy(net)
        delete!(bare["transformer"]["delta_wye"]["t1"], "r_neutral_to")
        delete!(bare["transformer"]["delta_wye"]["t1"], "x_neutral_to")
        @test isempty(BMOPFTools._transformer_neutral_earthing(bare))
        @test "E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(_pg_analyze(bare).findings)

        # Boundary: an impedance on a side without a neutral terminal is not a
        # branch (the network builders ignore it there).
        delta_side = deepcopy(bare)
        delta_side["transformer"]["delta_wye"]["t1"]["r_neutral_from"] = 5.0
        @test isempty(BMOPFTools._transformer_neutral_earthing(delta_side))
        @test "E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(_pg_analyze(delta_side).findings)

        # Boundary: zero and non-finite impedances are not finite references.
        for bad in (0.0, Inf, NaN)
            z = deepcopy(bare)
            z["transformer"]["delta_wye"]["t1"]["r_neutral_to"] = bad
            @test isempty(BMOPFTools._transformer_neutral_earthing(z))
        end
    end

    @testset "unearthed delta island: referenced only through modeled capacitance" begin
        bare = _pg_analyze(_pg_sys("it_delta_island_unreferenced"))
        ref = only(f for f in bare.findings if f.code == "E.INT.NO_VOLTAGE_REFERENCE")
        @test sort(ref.detail["buses"]) == ["it0", "it1"]
        @test [f.code for f in errors(bare)] == ["E.INT.NO_VOLTAGE_REFERENCE"]
        cap = _pg_analyze(_pg_sys("it_delta_island_capacitive"))
        @test isempty(errors(cap))
        # A delta-fed level is three-wire by construction: no Kron suspicion.
        @test !("I.PROV.KRON_LIKELY" in _pg_codes(bare.findings))
        @test bare.results[:provenance]["wires_by_level"]["LV_231V"]["delta_fed"]

        # The reference is what the admittance builder stamps, nothing else.
        refd(net) = (f = Finding[]; integrity_check(net, f); !("E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(f)))
        # Earth leakage in the stamped primitive: rows of Y sum to the shunt.
        leak(net) = (Y = line_yprim(net["line"]["run"], net["linecode"])[2];
                     maximum(abs, sum(Y, dims=2)) > 1e-12)
        bare() = _pg_sys("it_delta_island_unreferenced")
        @test !leak(bare()) && !refd(bare())
        cap = _pg_sys("it_delta_island_capacitive")
        @test leak(cap) && refd(cap)

        # Purely phase-to-phase admittance (zero row sums) is not a path to earth.
        net = bare()
        for i in 1:3, j in 1:3
            net["linecode"]["cable"]["B_from_$(i)_$(j)"] = i == j ? 2e-7 : -1e-7
        end
        @test !refd(net)
        # A line that uses a linecode takes its shunt from the linecode: a
        # B entry placed on the line record itself is never stamped.
        net = bare()
        for i in 1:3; net["line"]["run"]["B_to_$(i)_$(i)"] = 1e-6; end
        @test !leak(net) && !refd(net)
        # Inline totals on the line are the single source when present.
        net = bare()
        line = net["line"]["run"]; lc = net["linecode"]["cable"]; delete!(line, "linecode")
        for i in 1:3, j in 1:3
            line["R_series_$(i)_$(j)"] = lc["R_series_$(i)_$(j)"] * 80
            line["X_series_$(i)_$(j)"] = lc["X_series_$(i)_$(j)"] * 80
        end
        @test !refd(net)
        for i in 1:3; line["B_from_$(i)_$(i)"] = 4e-6; end
        @test leak(net) && refd(net)
        # Linecode values scale with length: a zero-length line stamps no shunt.
        net = _pg_sys("it_delta_island_capacitive"); net["line"]["run"]["length"] = 0.0
        @test !refd(net)
        # Only the mapped conductor block is stamped: capacitance on a fourth
        # linecode conductor that this three-wire line does not use is not there.
        net = bare()
        lc = net["linecode"]["cable"]
        for i in 1:4
            lc["R_series_$(i)_4"] = lc["R_series_4_$(i)"] = i == 4 ? 3e-4 : 5e-5
            lc["X_series_$(i)_4"] = lc["X_series_4_$(i)"] = i == 4 ? 3e-4 : 1e-4
        end
        for i in 1:4, j in 1:4; lc["B_from_$(i)_$(j)"] = (i == 4 && j == 4) ? 1e-7 : 0.0; end
        @test !leak(net) && !refd(net)
        # Sparse declarations: an omitted entry is zero. One diagonal entry is
        # a path to earth, and explicit zeros beside it change nothing.
        net = bare(); net["linecode"]["cable"]["B_from_1_1"] = 1e-7
        @test leak(net) && refd(net)
        padded = bare(); lc = padded["linecode"]["cable"]
        lc["B_from_1_1"] = 1e-7; lc["B_from_2_2"] = 0.0; lc["B_from_3_3"] = 0.0
        @test refd(padded)
        @test line_yprim(net["line"]["run"], net["linecode"])[2] ==
              line_yprim(padded["line"]["run"], padded["linecode"])[2]
        # G and B declared with different extents are padded, not rejected.
        net = bare(); lc = net["linecode"]["cable"]
        lc["G_to_2_2"] = 1e-9; lc["B_to_1_1"] = 0.0
        @test leak(net) && refd(net)
        # A sparse entry beyond the mapped conductors is still outside the block.
        net = bare(); net["linecode"]["cable"]["B_from_4_4"] = 1e-7
        @test !refd(net)
        # Malformed shunt data is not a reference and does not abort the helper.
        net = _pg_sys("it_delta_island_capacitive")
        net["linecode"]["cable"]["B_from_1_1"] = "high"
        @test !BMOPFTools._line_stamps_earth_shunt(net["line"]["run"], net["linecode"])
    end

    @testset "neutral impedance counts only where a builder stamps it" begin
        island(subtype) = Dict{String,Any}(
            "bus" => Dict{String,Any}("p" => Dict{String,Any}("terminal_names" => ["a","n"]),
                                      "s" => Dict{String,Any}("terminal_names" => ["a","n"])),
            "transformer" => Dict{String,Any}(subtype => Dict{String,Any}("t" => Dict{String,Any}(
                "bus_from" => "p", "bus_to" => "s", "terminal_map_from" => ["a","n"],
                "terminal_map_to" => ["a","n"], "v_nom_from" => 240.0, "v_nom_to" => 240.0,
                "s_rating" => 1e4, "r_neutral_from" => 5.0))))
        @test haskey(BMOPFTools._transformer_neutral_earthing(island("single_phase")), ("p", "n"))
        for subtype in ("single_phase_autotransformer", "open_delta_regulator")
            net = island(subtype)
            @test isempty(BMOPFTools._transformer_neutral_earthing(net))
            f = Finding[]; integrity_check(net, f)
            @test "E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(f)
        end
    end

    @testset "a reference must reach every conductor group" begin
        # Oracle: the passive Ybus. A group floats when a common shift of its
        # nodes lies in the nullspace of the island's admittance matrix.
        floats(net, nodes) = begin
            r = ybus_passive(net)
            x = zeros(ComplexF64, length(r.nodes))
            for n in nodes; x[r.index[n]] = 1.0; end
            maximum(abs, r.Y * x) <= 1e-9 * maximum(abs, r.Y)
        end
        groups(net) = (f = Finding[]; integrity_check(net, f);
            [x for x in f if x.code == "E.INT.NO_VOLTAGE_REFERENCE" && x.detail["scope"] == "conductor_group"])
        phases = [(b, t) for b in ("it0", "it1") for t in ("a", "b", "c")]

        # A separately carried fourth conductor with the line's only earth shunt:
        # the island has a tie to earth, the delta phases do not.
        net = _pg_sys("it_delta_island_unreferenced")
        for b in ("it0", "it1"); net["bus"][b]["terminal_names"] = ["a","b","c","n"]; end
        net["line"]["run"]["terminal_map_from"] = ["a","b","c","n"]
        net["line"]["run"]["terminal_map_to"] = ["a","b","c","n"]
        lc = net["linecode"]["cable"]
        for i in 1:4
            lc["R_series_$(i)_4"] = lc["R_series_4_$(i)"] = i == 4 ? 3e-4 : 5e-5
            lc["X_series_$(i)_4"] = lc["X_series_4_$(i)"] = i == 4 ? 3e-4 : 1e-4
        end
        lc["i_max"] = fill(200.0, 4); lc["B_from_4_4"] = 1e-7
        @test floats(net, phases)
        g = only(groups(net))
        @test Set((t["bus"], t["terminal"]) for t in g.detail["terminals"]) == Set(phases)
        @test g.severity == ERROR && g.detail["buses"] == ["it0", "it1"]
        @test integrity_check(net, Finding[])["n_without_reference"] == 0     # the island has one
        @test integrity_check(net, Finding[])["n_unreferenced_conductor_groups"] == 1

        # Anything that ties the phases to the earthed conductor removes it, and
        # the Ybus agrees each time.
        cap = deepcopy(net); cap["linecode"]["cable"]["B_from_1_1"] = 1e-7       # capacitance on a phase
        @test !floats(cap, phases) && isempty(groups(cap))
        mutual = deepcopy(net); mutual["linecode"]["cable"]["B_from_1_4"] = -2e-8 # phase-to-neutral capacitance
        mutual["linecode"]["cable"]["B_from_4_1"] = -2e-8
        mutual["linecode"]["cable"]["B_from_1_1"] = 2e-8                          # rows a sums to zero: no earth
        @test !floats(mutual, phases) && isempty(groups(mutual))
        wye = deepcopy(net)                                                       # a phase-to-neutral load
        wye["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","n"],
            "configuration" => "SINGLE_PHASE", "p_nom" => [100.0], "q_nom" => [0.0])
        @test isempty(groups(wye))
        # The same earth admittance as a standalone shunt that merely LISTS the
        # phases in its map: only the matrix couplings tie terminals.
        sh = deepcopy(net); delete!(sh["linecode"]["cable"], "B_from_4_4")
        sh["shunt"] = Dict{String,Any}("earth" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c","n"], "G_1_1" => 0.0, "B_1_1" => 0.0, "G_4_4" => 1e-3))
        @test floats(sh, phases)
        @test Set((t["bus"], t["terminal"]) for t in only(groups(sh)).detail["terminals"]) == Set(phases)
        # A nonzero entry between a phase and the earthed terminal does tie them...
        tied = deepcopy(sh); tied["shunt"]["earth"]["G_1_4"] = -1e-4; tied["shunt"]["earth"]["G_4_1"] = -1e-4
        tied["shunt"]["earth"]["G_1_1"] = 1e-4
        @test !floats(tied, phases) && isempty(groups(tied))
        # ...and so does a row of its own to earth.
        own = deepcopy(sh); own["shunt"]["earth"]["G_2_2"] = 1e-5
        @test !floats(own, phases) && isempty(groups(own))
        # A load written against earth (one terminal, no neutral) references its
        # phase, and through the delta the other two: the solver uses the
        # phase-to-reference voltage for it.
        for cfg in ("SINGLE_PHASE", "WYE")
            ld = deepcopy(net)
            tm = cfg == "WYE" ? ["a","b","c"] : ["a"]
            ld["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => tm,
                "configuration" => cfg, "model" => "constant_impedance",
                "p_nom" => fill(100.0, length(tm)), "q_nom" => fill(0.0, length(tm)),
                "v_nom" => fill(230.0, length(tm)))
            @test isempty(groups(ld))
        end
        # Oracle for loads: the linearized Ybus, with constant-impedance loads
        # folded in. A common shift of the phases is in its nullspace iff they float.
        floats_lin(net, nodes) = begin
            lin = ybus_linearized(net)
            x = zeros(ComplexF64, length(lin.nodes))
            for n in nodes; x[lin.index[n]] = 1.0; end
            maximum(abs, lin.Y * x) <= 1e-9 * maximum(abs, lin.Y)
        end
        zload(net, p, q) = begin
            out = deepcopy(net)
            out["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a"],
                "configuration" => "SINGLE_PHASE", "model" => "constant_impedance",
                "p_nom" => [p], "q_nom" => [q], "v_nom" => [230.0])
            out
        end
        @test !floats_lin(zload(net, 100.0, 0.0), phases) && isempty(groups(zload(net, 100.0, 0.0)))
        # A zero-power load draws no current at any voltage: it pins nothing.
        zero_load = zload(net, 0.0, 0.0)
        @test floats_lin(zero_load, phases)
        @test length(groups(zero_load)) == 1
        @test isempty(groups(zload(net, 0.0, 50.0)))            # reactive demand alone is a term
        # A WYE load against earth references only the phases that draw power.
        partial = deepcopy(net)
        partial["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","b","c"],
            "configuration" => "WYE", "model" => "constant_impedance",
            "p_nom" => [0.0, 0.0, 0.0], "q_nom" => [0.0, 0.0, 0.0], "v_nom" => fill(230.0, 3))
        @test length(groups(partial)) == 1
        partial["load"]["aux"]["p_nom"] = [0.0, 80.0, 0.0]
        @test isempty(groups(partial))
        # The same holds per coil for a load that names the neutral: a
        # zero-power phase-to-neutral load ties nothing to the earthed neutral.
        pn(pv, qv) = begin
            out = deepcopy(net)
            out["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","n"],
                "configuration" => "SINGLE_PHASE", "model" => "constant_impedance",
                "p_nom" => [pv], "q_nom" => [qv], "v_nom" => [230.0])
            out
        end
        @test floats_lin(pn(0.0, 0.0), phases) && length(groups(pn(0.0, 0.0))) == 1
        @test !floats_lin(pn(100.0, 0.0), phases) && isempty(groups(pn(100.0, 0.0)))
        # WYE to the neutral: one active coil is enough, since the delta load
        # and the transformer winding tie the phases to each other.
        wyen(pv) = begin
            out = deepcopy(net)
            out["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","b","c","n"],
                "configuration" => "WYE", "model" => "constant_impedance",
                "p_nom" => pv, "q_nom" => [0.0, 0.0, 0.0], "v_nom" => fill(230.0, 3))
            out
        end
        @test floats_lin(wyen([0.0, 0.0, 0.0]), phases) && length(groups(wyen([0.0, 0.0, 0.0]))) == 1
        @test !floats_lin(wyen([0.0, 0.0, 60.0]), phases) && isempty(groups(wyen([0.0, 0.0, 60.0])))
        # A DELTA coil ties its own pair only where it draws power. With the
        # fixture's delta load switched off and the winding removed from the
        # picture, a coil on a-b leaves c in a group of its own.
        coils = BMOPFTools._conductor_reference(Dict{String,Any}(
            "bus" => Dict{String,Any}("x" => Dict{String,Any}("terminal_names" => ["a","b","c","n"],
                "perfectly_grounded_terminals" => ["n"])),
            "load" => Dict{String,Any}(
                "d" => Dict{String,Any}("bus" => "x", "terminal_map" => ["a","b","c"], "configuration" => "DELTA",
                    "p_nom" => [100.0, 0.0, 0.0], "q_nom" => [0.0, 0.0, 0.0]),
                "y" => Dict{String,Any}("bus" => "x", "terminal_map" => ["c","n"], "configuration" => "SINGLE_PHASE",
                    "p_nom" => [50.0], "q_nom" => [0.0])))).groups
        @test coils == [[("x", "a"), ("x", "b")]]            # c is referenced through its own load; a-b float
        # Generators follow the same per-coil rule. A coil whose bounds force
        # both P and Q to zero carries no current at any voltage: it neither
        # ties its phase to the earthed neutral nor references anything.
        gen(tm; pmin=0.0, pmax=0.0, qmin=0.0, qmax=0.0, bounds=true) = begin
            out = deepcopy(net)
            g = Dict{String,Any}("bus" => "it1", "terminal_map" => tm,
                "configuration" => "SINGLE_PHASE", "cost" => [0.1])
            bounds && merge!(g, Dict{String,Any}("p_min" => [pmin], "p_max" => [pmax],
                                                 "q_min" => [qmin], "q_max" => [qmax]))
            out["generator"] = Dict{String,Any}("g" => g)
            out
        end
        @test length(groups(gen(["a", "n"]))) == 1                    # fixed at zero: floats
        @test length(groups(gen(["a"]))) == 1                         # against earth, fixed at zero
        @test isempty(groups(gen(["a", "n"]; pmax=1000.0)))           # can produce: a tie
        @test isempty(groups(gen(["a", "n"]; qmin=-200.0)))           # reactive range alone is a term
        @test isempty(groups(gen(["a", "n"]; pmin=500.0, pmax=500.0)))# fixed nonzero output
        # Against earth, a generator references its phase only when its output
        # is given: with a dispatch range a voltage shift is absorbed by P and Q.
        @test length(groups(gen(["a"]; pmax=1000.0))) == 1             # a range pins nothing
        @test isempty(groups(gen(["a"]; pmin=500.0, pmax=500.0)))      # P and Q fixed, P nonzero
        @test length(groups(gen(["a"]; pmin=500.0, pmax=500.0, qmin=-10.0, qmax=10.0))) == 1   # Q free
        @test length(groups(gen(["a"]; bounds=false))) == 1            # no bounds: free
        @test isempty(groups(gen(["a", "n"]; bounds=false)))          # no bounds: not forced to zero
        # A zero rating leaves a coil no room even when its P/Q bounds allow dispatch.
        for (key, value) in (("s_max", [0.0]), ("i_max", [0.0, 0.0]), ("i_max", [0.0]), ("s_max", 0.0))
            g = gen(["a", "n"]; pmax=1000.0); g["generator"]["g"][key] = value
            @test length(groups(g)) == 1
        end
        g = gen(["a", "n"]; pmax=1000.0); g["generator"]["g"]["s_max"] = [2000.0]
        @test isempty(groups(g))

        # IBRs follow the same rule, coil by coil and by topology. An offline
        # phase-to-neutral inverter (P and Q pinned at zero) carries no current.
        ibr(tm, topo; extra...) = begin
            out = deepcopy(net)
            out["ibr"] = Dict{String,Any}("pv" => merge(Dict{String,Any}("bus" => "it1", "terminal_map" => tm,
                "topology" => topo, "prime_mover" => "PV", "s_max" => [3000.0]),
                Dict{String,Any}(string(k) => v for (k, v) in extra)))
            out
        end
        @test isempty(groups(ibr(["a", "n"], "SINGLE_PHASE")))                     # online: a tie
        offline = ibr(["a", "n"], "SINGLE_PHASE"; p_min=[0.0], p_max=[0.0], q_min=[0.0], q_max=[0.0])
        @test length(groups(offline)) == 1 && floats_lin(offline, phases)
        @test length(groups(ibr(["a", "n"], "SINGLE_PHASE"; s_max=[0.0]))) == 1    # zero apparent power
        @test length(groups(ibr(["a", "n"], "SINGLE_PHASE"; i_max=[50.0, 0.0]))) == 1   # one current, tightest entry
        @test isempty(groups(ibr(["a", "n"], "SINGLE_PHASE"; p_min=[0.0], p_max=[0.0], q_min=[-500.0], q_max=[500.0])))
        # The reactive range is not always free. Under a constant power factor
        # Q is a fixed multiple of P, so with P pinned at zero the coil carries
        # nothing, whatever its Q bounds say.
        pfc(pf; extra...) = begin
            out = ibr(["a", "n"], "SINGLE_PHASE"; p_min=[0.0], p_max=[0.0], q_min=[-500.0], q_max=[500.0],
                      control_profile="cp", extra...)
            out["control_profile"] = Dict{String,Any}("cp" => Dict{String,Any}(
                "power_factor" => Dict{String,Any}("pf" => pf)))
            out
        end
        @test length(groups(pfc(1.0))) == 1                       # unity: Q is forced to zero
        @test length(groups(pfc(0.9))) == 1                       # any constant pf with P = 0
        @test length(groups(pfc(-0.95))) == 1
        live = pfc(1.0); live["ibr"]["pv"]["p_max"] = [2000.0]
        @test isempty(groups(live))                               # P can flow: a tie again
        # Only the P box counts, as in the solver: `p_avail` is the base of a
        # droop curve, not a bound. Zero availability beside a live P range,
        # or beside coils fixed at a nonzero output, forces nothing.
        dark = pfc(1.0); dark["ibr"]["pv"]["p_max"] = [2000.0]; dark["ibr"]["pv"]["p_avail"] = 0.0
        @test isempty(groups(dark))
        fixed = pfc(1.0); fixed["ibr"]["pv"]["p_min"] = [500.0]; fixed["ibr"]["pv"]["p_max"] = [500.0]
        fixed["ibr"]["pv"]["p_avail"] = 0.0
        @test isempty(groups(fixed))
        # A zero upper bound alone does not pin P under a constant power factor
        # (the unit may absorb)...
        absorbs = pfc(1.0); absorbs["ibr"]["pv"]["p_min"] = [-800.0]
        @test isempty(groups(absorbs))
        # ...but a minimum power factor adds P >= 0, so there it does.
        minpf(pmin, pmax) = begin
            out = ibr(["a", "n"], "SINGLE_PHASE"; p_min=[pmin], p_max=[pmax], q_min=[-500.0], q_max=[500.0])
            out["extras"] = Dict{String,Any}("bmopftools" => Dict{String,Any}("minimum_power_factor" =>
                Dict{String,Any}("schema" => "bmopftools.minimum_power_factor/v1", "ibr" => Dict{String,Any}(
                    "pv" => Dict{String,Any}("pf_min" => 0.9, "direction" => "generation", "scope" => "per_coil")))))
            out
        end
        @test !isempty(first(BMOPFTools._power_factor_config_check!(minpf(0.0, 0.0), Finding[])))   # the policy resolves
        @test length(groups(minpf(0.0, 0.0))) == 1
        @test isempty(groups(minpf(0.0, 2000.0)))
        # A Volt-var law is an equality as well. With both q_limits at zero
        # the curve is zero at every voltage: Q is zero, and with P pinned at
        # zero the coil carries nothing.
        vvar(ql; extra...) = begin
            out = ibr(["a", "n"], "SINGLE_PHASE"; p_min=[0.0], p_max=[0.0], q_min=[-500.0], q_max=[500.0],
                      control_profile="cp", extra...)
            out["control_profile"] = Dict{String,Any}("cp" => Dict{String,Any}("volt_var" => Dict{String,Any}(
                "breakpoints" => [207.0, 220.0, 240.0, 253.0], "q_limits" => ql)))
            out
        end
        @test length(groups(vvar([0.0, 0.0]))) == 1
        @test isempty(groups(vvar([-0.44, 0.44])))                # a real curve: Q responds to voltage
        @test isempty(groups(vvar([0.0, 0.44])))                  # one side is enough
        @test isempty(groups(vvar([0.0, 0.0]; p_max=[2000.0])))   # P can flow
        # Read as the solver resolves it: a malformed or unsupported law falls
        # back to the box, and THREE_LEG carries no droop.
        short = vvar([0.0, 0.0]); short["control_profile"]["cp"]["volt_var"]["breakpoints"] = [207.0, 253.0]
        @test isempty(groups(short))
        other = vvar([0.0, 0.0]); other["control_profile"]["cp"]["volt_var"]["q_ref"] = "VAR_AVAILABLE"
        @test isempty(groups(other))
        odd_vv = vvar([0.0, 0.0]); odd_vv["control_profile"]["cp"]["volt_var"] = "flat"
        @test isempty(groups(odd_vv))
        three = vvar([0.0, 0.0]); three["ibr"]["pv"]["topology"] = "THREE_LEG"
        @test isempty(groups(three))
        # An isolated DC link balances the SUM of the coil powers (zero by
        # default). On a single-coil device that is the coil's own power: with
        # a wide P box and an all-zero Volt-var curve it still carries nothing.
        statcom(; extra...) = begin
            out = vvar([0.0, 0.0]; p_min=[-3000.0], p_max=[3000.0], dc_link_coupled=true, extra...)
            out["ibr"]["pv"]["prime_mover"] = "STATCOM"
            out
        end
        @test length(groups(statcom())) == 1
        @test length(groups(statcom(p_dc_min=0.0, p_dc_max=0.0))) == 1
        @test isempty(groups(statcom(p_dc_min=-100.0, p_dc_max=100.0)))      # a range: P is free
        @test isempty(groups(statcom(p_dc_min=200.0, p_dc_max=200.0)))       # a nonzero balance: P flows
        @test isempty(groups(statcom(dc_link_coupled=false)))                # no balance at all
        @test isempty(groups(statcom(dc_bus="dc1")))                         # a shared DC bus: P follows DC KCL
        live_q = statcom(); live_q["control_profile"]["cp"]["volt_var"]["q_limits"] = [-0.44, 0.44]
        @test isempty(groups(live_q))                                        # reactive current still ties
        # P and Q are each fixed by whichever constraint applies: here P by
        # the DC balance and Q by its own box, with no control profile at all.
        boxed(qmin, qmax; extra...) = begin
            out = ibr(["a", "n"], "SINGLE_PHASE"; p_min=[-3000.0], p_max=[3000.0], q_min=[qmin], q_max=[qmax],
                      dc_link_coupled=true, extra...)
            out["ibr"]["pv"]["prime_mover"] = "STATCOM"
            out
        end
        @test length(groups(boxed(0.0, 0.0))) == 1
        @test isempty(groups(boxed(-500.0, 500.0)))                          # reactive current ties
        @test isempty(groups(boxed(300.0, 300.0)))                           # Q fixed, but not at zero
        @test isempty(groups(boxed(0.0, 0.0; dc_link_coupled=false)))        # P is free again
        # A constant power factor below one works both ways: Q pinned at zero
        # forces P to zero. At unity it says nothing about P.
        lagging = pfc(0.9); lagging["ibr"]["pv"]["p_max"] = [2000.0]
        lagging["ibr"]["pv"]["q_min"] = [0.0]; lagging["ibr"]["pv"]["q_max"] = [0.0]
        @test length(groups(lagging)) == 1
        unity = deepcopy(lagging); unity["control_profile"]["cp"]["power_factor"]["pf"] = 1.0
        @test isempty(groups(unity))
        # The power factor is applied before the DC balance. In a two-coil
        # device at 0.95, Q pinned at zero on one coil pins its P; the zero
        # balance then leaves the other coil no P, and the power factor no Q.
        chained(q1; pf=0.95) = begin
            out = ibr(["a", "b", "n"], "FOUR_LEG"; s_max=[3000.0, 3000.0], p_min=[-3000.0, -3000.0],
                      p_max=[3000.0, 3000.0], q_min=[-q1, -3000.0], q_max=[q1, 3000.0],
                      control_profile="cp", dc_link_coupled=true)
            out["control_profile"] = Dict{String,Any}("cp" => Dict{String,Any}(
                "power_factor" => Dict{String,Any}("pf" => pf)))
            out
        end
        @test length(groups(chained(0.0))) == 1
        @test isempty(groups(chained(500.0)))                                # the first coil has room
        @test isempty(groups(chained(0.0; pf=1.0)))                          # unity: Q says nothing about P
        # The sign survives: at +0.95 a Q box of [-500, 0] makes every coil's P
        # nonnegative, and a zero balance over nonnegative coils is zero.
        sided(qlo, qhi; pf=0.95) = begin
            out = chained(0.0; pf); i = out["ibr"]["pv"]
            i["q_min"] = [qlo, qlo]; i["q_max"] = [qhi, qhi]
            out
        end
        @test length(groups(sided(-500.0, 0.0))) == 1
        @test length(groups(sided(0.0, 500.0))) == 1                         # every P nonpositive
        @test length(groups(sided(-500.0, 0.0; pf=-0.95))) == 1
        @test isempty(groups(sided(-500.0, 500.0)))                          # both signs: circulation
        mixed = sided(-500.0, 0.0); mixed["ibr"]["pv"]["q_min"] = [-500.0, 0.0]; mixed["ibr"]["pv"]["q_max"] = [0.0, 500.0]
        @test isempty(groups(mixed))                                         # opposite sides: one exports, one absorbs
        open_q = sided(-500.0, 0.0); delete!(open_q["ibr"]["pv"], "q_min")
        @test length(groups(open_q)) == 1                                    # Q <= 0 alone is one-sided too
        loose_dc = chained(0.0); loose_dc["ibr"]["pv"]["p_dc_min"] = -100.0; loose_dc["ibr"]["pv"]["p_dc_max"] = 100.0
        @test isempty(groups(loose_dc))                                      # the balance leaves the second coil room
        # Several coils can circulate power between phases: the balance pins a
        # coil only as far as the other coils' boxes leave it no room.
        multi(pmin, pmax) = begin
            out = statcom(); i = out["ibr"]["pv"]
            i["terminal_map"] = ["a", "b", "n"]; i["topology"] = "FOUR_LEG"; i["s_max"] = [3000.0, 3000.0]
            i["p_min"] = pmin; i["p_max"] = pmax; i["q_min"] = [-3000.0, -3000.0]; i["q_max"] = [3000.0, 3000.0]
            out
        end
        @test isempty(groups(multi([-3000.0, -3000.0], [3000.0, 3000.0])))   # circulation
        @test length(groups(multi([0.0, -3000.0], [0.0, 3000.0]))) == 1       # one pinned at 0, the other follows
        @test isempty(groups(multi([500.0, -3000.0], [500.0, 3000.0])))      # the other carries -500 W
        # With every coil at P >= 0 and a zero balance, each coil is at zero
        # whatever its own upper bound. Q decides the rest.
        oneway(qlo, qhi; extra...) = begin
            out = multi([0.0, 0.0], [3000.0, 3000.0]); i = out["ibr"]["pv"]
            delete!(out, "control_profile"); delete!(i, "control_profile")
            i["q_min"] = [qlo, qlo]; i["q_max"] = [qhi, qhi]
            for (k, v) in extra; i[string(k)] = v; end
            out
        end
        @test length(groups(oneway(0.0, 0.0))) == 1
        @test isempty(groups(oneway(-500.0, 500.0)))                         # reactive current ties
        @test isempty(groups(oneway(0.0, 0.0; p_dc_max=100.0)))              # room in the balance
        @test isempty(groups(oneway(0.0, 0.0; p_min=[-100.0, 0.0])))         # one coil may absorb: circulation
        @test length(groups(oneway(0.0, 0.0; p_dc_min=-50.0))) == 1          # sum <= 0 and every P >= 0
        mirrored = oneway(0.0, 0.0; p_min=[-3000.0, -3000.0], p_max=[0.0, 0.0])
        @test length(groups(mirrored)) == 1                                  # the same with every P <= 0
        nobound = oneway(0.0, 0.0); delete!(nobound["ibr"]["pv"], "p_min")
        @test isempty(groups(nobound))                                       # a missing bound is no bound
        # A Volt-watt law caps P at base * f(U). A zero base is a zero cap at
        # every voltage, even beside a positive p_max.
        vwatt(; ref="P_AVAILABLE", limits=[0.2, 1.0], extra...) = begin
            out = ibr(["a", "n"], "SINGLE_PHASE"; p_min=[0.0], p_max=[2000.0], q_min=[0.0], q_max=[0.0],
                      control_profile="cp", extra...)
            out["control_profile"] = Dict{String,Any}("cp" => Dict{String,Any}("volt_watt" => Dict{String,Any}(
                "breakpoints" => [250.0, 260.0], "p_limits" => limits, "p_ref" => ref)))
            out
        end
        @test length(groups(vwatt(p_avail=0.0))) == 1
        @test length(groups(vwatt())) == 1                                   # no p_avail reads as zero there
        @test isempty(groups(vwatt(p_avail=1500.0)))                         # power is available
        @test isempty(groups(vwatt(p_avail=0.0, p_min=[-500.0])))            # may still absorb
        @test isempty(groups(vwatt(p_avail=0.0, q_min=[-500.0], q_max=[500.0])))   # reactive current ties
        @test isempty(groups(vwatt(ref="S_MAX", p_avail=0.0)))               # another base: p_avail plays no part
        @test isempty(groups(vwatt(ref="P_MAX", p_avail=0.0)))
        # The base is read as the solver reads it: a missing entry is zero, so
        # an omitted optional `p_max` under P_MAX caps P at zero.
        nomax = vwatt(ref="P_MAX"); delete!(nomax["ibr"]["pv"], "p_max")
        @test length(groups(nomax)) == 1
        @test length(groups(vwatt(ref="P_MAX", p_max=[0.0]))) == 1
        norating = vwatt(ref="S_MAX"); delete!(norating["ibr"]["pv"], "s_max")
        @test length(groups(norating)) == 1
        @test isempty(groups(vwatt(ref="S_MAX", s_max=3000.0)))              # a scalar is its one entry
        @test isempty(groups(vwatt(ref="P_MAX", p_max=["high"])))            # unreadable: not assumed zero
        @test length(groups(vwatt(limits=[0.0, 0.0], p_avail=1500.0))) == 1  # a curve that is zero throughout
        # Read as the solver resolves it: unsupported or malformed laws, a
        # constant power factor beside it, and THREE_LEG leave the box alone.
        @test isempty(groups(vwatt(ref="P_RATED", p_avail=0.0)))
        @test isempty(groups(vwatt(limits=[1.0], p_avail=0.0)))
        w3 = vwatt(p_avail=0.0); w3["ibr"]["pv"]["topology"] = "THREE_LEG"
        @test isempty(groups(w3))
        wpf = vwatt(p_avail=0.0); wpf["control_profile"]["cp"]["power_factor"] = Dict{String,Any}("pf" => 0.95)
        wpf["ibr"]["pv"]["q_min"] = [-500.0]; wpf["ibr"]["pv"]["q_max"] = [500.0]
        @test isempty(groups(wpf))
        # A profile with no power-factor law leaves the Q range free.
        free = pfc(1.0); free["control_profile"]["cp"] = Dict{String,Any}()
        @test isempty(groups(free))
        # A malformed profile does not abort the check.
        odd = pfc(1.0); odd["control_profile"]["cp"]["power_factor"] = Dict{String,Any}("pf" => "unity")
        @test BMOPFTools._conductor_reference(odd) isa NamedTuple
        # FOUR_LEG: one coil per phase to the neutral; one live phase suffices here.
        four_off = ibr(["a","b","c","n"], "FOUR_LEG"; s_max=fill(1000.0, 3),
            p_min=fill(0.0, 3), p_max=fill(0.0, 3), q_min=fill(0.0, 3), q_max=fill(0.0, 3))
        @test length(groups(four_off)) == 1
        four_one = deepcopy(four_off); four_one["ibr"]["pv"]["q_max"] = [0.0, 0.0, 300.0]
        @test isempty(groups(four_one))
        four_rated = ibr(["a","b","c","n"], "FOUR_LEG"; s_max=[0.0, 0.0, 0.0])
        @test length(groups(four_rated)) == 1
        # THREE_LEG is line-to-line: never a tie to the neutral, online or not.
        @test length(groups(ibr(["a","b","c"], "THREE_LEG"))) == 1
        # A fixed-zero generator stamps nothing into the Ybus either.
        @test floats_lin(gen(["a", "n"]), phases)

        # The ISLAND test reads the same evidence. On the bare delta fixture, with
        # no other tie anywhere, the load is the island's reference...
        only_load = zload(_pg_sys("it_delta_island_unreferenced"), 100.0, 0.0)
        @test !floats_lin(only_load, phases)
        f = Finding[]; r = integrity_check(only_load, f)
        @test !("E.INT.NO_VOLTAGE_REFERENCE" in _pg_codes(f))
        @test r["n_without_reference"] == 0 && r["n_unreferenced_conductor_groups"] == 0
        # ...and a zero-power load leaves it without one, in both tests' terms.
        no_load = zload(_pg_sys("it_delta_island_unreferenced"), 0.0, 0.0)
        @test floats_lin(no_load, phases)
        f = Finding[]; r = integrity_check(no_load, f)
        refs = [x for x in f if x.code == "E.INT.NO_VOLTAGE_REFERENCE"]
        @test length(refs) == 1 && only(refs).detail["scope"] == "island" && r["n_without_reference"] == 1
        # A phase-to-phase load is no reference.
        pp = deepcopy(net)
        pp["load"]["aux"] = Dict{String,Any}("bus" => "it1", "terminal_map" => ["a","b"],
            "configuration" => "SINGLE_PHASE", "p_nom" => [100.0], "q_nom" => [0.0])
        @test length(groups(pp)) == 1
        # A capacitor ties what its susceptance matrix stamps. A WYE bank to the
        # earthed fourth conductor references the phases through it...
        capn = deepcopy(net)
        capn["capacitor"] = Dict{String,Any}("bank" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c","n"], "configuration" => "WYE",
            "q_rated" => fill(1000.0, 3), "v_nom" => 230.0))
        @test !floats(capn, phases) && isempty(groups(capn))
        # ...a DELTA bank ties phases to each other only...
        capd = deepcopy(net)
        capd["capacitor"] = Dict{String,Any}("bank" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c"], "configuration" => "DELTA",
            "q_rated" => fill(1000.0, 3), "v_nom" => 400.0))
        @test floats(capd, phases) && length(groups(capd)) == 1
        # ...and a WYE bank whose map holds no resolvable neutral stamps nothing,
        # so merely listing the terminals connects nothing.
        capx = deepcopy(net)
        for b in ("it0", "it1"); capx["bus"][b]["terminal_names"] = ["a","b","c","m"]; end
        capx["line"]["run"]["terminal_map_from"] = ["a","b","c","m"]
        capx["line"]["run"]["terminal_map_to"] = ["a","b","c","m"]
        capx["capacitor"] = Dict{String,Any}("bank" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c","m"], "configuration" => "WYE",
            "q_rated" => fill(1000.0, 3), "v_nom" => 230.0))
        @test all(iszero, BMOPFTools._cap_bmatrix(capx["capacitor"]["bank"])[2])
        phases_x = [(b, t) for b in ("it0", "it1") for t in ("a", "b", "c")]
        @test floats(capx, phases_x) && length(groups(capx)) == 1
        # An IBR ties its terminals as the solver stamps them: THREE_LEG is
        # line-to-line (no reference), FOUR_LEG reaches the earthed neutral.
        three = deepcopy(net)
        three["ibr"] = Dict{String,Any}("pv" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c"], "topology" => "THREE_LEG", "prime_mover" => "PV", "s_max" => [3000.0]))
        @test length(groups(three)) == 1
        four = deepcopy(net)
        four["ibr"] = Dict{String,Any}("pv" => Dict{String,Any}("bus" => "it1",
            "terminal_map" => ["a","b","c","n"], "topology" => "FOUR_LEG", "prime_mover" => "PV", "s_max" => fill(1000.0, 3)))
        @test isempty(groups(four))
        # The whole-island finding is not repeated per group.
        bare = _pg_sys("it_delta_island_unreferenced")
        f = Finding[]; integrity_check(bare, f)
        refs = [x for x in f if x.code == "E.INT.NO_VOLTAGE_REFERENCE"]
        @test length(refs) == 1 && only(refs).detail["scope"] == "island"
        # Declared but untouched terminals are not a group.
        spare = _pg_sys("it_delta_island_capacitive")
        spare["bus"]["it1"]["terminal_names"] = ["a","b","c","spare"]
        @test isempty(groups(spare))
        # Every well-formed regional fixture has every conductor group referenced.
        for name in ("na_mgn_split_phase", "na_high_leg_open_delta", "eu_tn_four_wire",
                     "it_delta_island_capacitive", "jp_three_wire_v_connection", "au_men_four_wire")
            @test isempty(BMOPFTools._unreferenced_conductor_groups(_pg_sys(name)))
        end
        # Malformed tables and records do not abort it.
        bad = _pg_sys("eu_tn_four_wire")
        bad["shunt"] = nothing; bad["switch"] = Dict{String,Any}("s" => 3)
        bad["line"]["f1"]["terminal_map_to"] = "abcn"; bad["load"]["h1"]["terminal_map"] = [1, 2]
        @test BMOPFTools._unreferenced_conductor_groups(bad) isa Vector
    end
end
