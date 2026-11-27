# The profiler's reading of an inverter's constraints, checked against an
# independent linear program.
#
# `_ibr_power_ranges` claims to return, per coil, the exact range of P and Q
# under the voltage-independent constraints the solver stamps. A single OPF
# solution with zero current only shows that zero is feasible. Here each
# coil's P and Q are minimized and maximized by an LP written from the
# documented constraint forms (not from the package's code), so the extrema
# show what is forced. Needs JuMP + HiGHS.

using Test
using BMOPFTools
using JuMP, HiGHS
using Random

@testset "IBR control rules — LP extrema oracle" begin
    D = Dict{String,Any}
    U = 1000.0
    boxes = ((nothing, nothing), (0.0, 0.0), (0.0, U), (-U, U), (-U, 0.0), (300.0, 300.0),
             (nothing, 0.0), (0.0, nothing), (-500.0, -100.0))

    # One scenario: a raw IBR record, its profile, its minimum-power-factor policy.
    function scenario(rng)
        topo, tm = rand(rng, (("SINGLE_PHASE", ["a", "n"]), ("FOUR_LEG", ["a", "b", "n"]),
                              ("FOUR_LEG", ["a", "b", "c", "n"]), ("THREE_LEG", ["a", "b", "c"])))
        n = topo == "SINGLE_PHASE" ? 1 : topo == "THREE_LEG" ? 3 : length(tm) - 1
        inv = D("bus" => "x", "terminal_map" => tm, "topology" => topo)
        # Boxes: one shape per side for the whole device (a bound vector has one
        # entry per coil or is absent), values varied per coil.
        for (lo_key, hi_key) in (("p_min", "p_max"), ("q_min", "q_max"))
            picks = [rand(rng, boxes) for _ in 1:n]
            rand(rng) < 0.3 && (picks = fill(picks[1], n))
            all(b -> b[1] !== nothing, picks) && (inv[lo_key] = [b[1] for b in picks])
            all(b -> b[2] !== nothing, picks) && (inv[hi_key] = [b[2] for b in picks])
        end
        r = rand(rng)
        r < 0.5 && (inv["s_max"] = [rand(rng) < 0.15 ? 0.0 : 3000.0 for _ in 1:n])
        0.5 <= r < 0.6 && (inv["s_max"] = 3000.0)
        rand(rng) < 0.1 && (inv["i_max"] = [rand(rng) < 0.3 ? 0.0 : 50.0 for _ in 1:n])
        rand(rng) < 0.5 && (inv["p_avail"] = rand(rng, (0.0, 1500.0)))
        cp = D()
        rand(rng) < 0.4 && (cp["power_factor"] = D("pf" => rand(rng, (1.0, 0.95, -0.9, -1.0, 0.5))))
        rand(rng) < 0.3 && (cp["volt_watt"] = D("breakpoints" => [250.0, 260.0],
            "p_limits" => rand(rng, ([0.2, 1.0], [0.0, 0.0])), "p_ref" => rand(rng, ("S_MAX", "P_MAX", "P_AVAILABLE"))))
        rand(rng) < 0.3 && (cp["volt_var"] = D("breakpoints" => [207.0, 220.0, 240.0, 253.0],
            "q_limits" => rand(rng, ([-0.44, 0.44], [0.0, 0.0]))))
        profiles = D()
        isempty(cp) || (profiles["cp"] = cp; inv["control_profile"] = "cp")
        d = rand(rng)
        if d < 0.5
            inv["dc_link_coupled"] = true
            d < 0.15 && (inv["p_dc_min"] = -100.0; inv["p_dc_max"] = 100.0)
            0.15 <= d < 0.25 && (inv["p_dc_min"] = 200.0; inv["p_dc_max"] = 200.0)
            0.25 <= d < 0.3 && (inv["p_dc_min"] = -50.0)
        elseif d < 0.6
            inv["dc_bus"] = "dc1"
        end
        policy = rand(rng) < 0.25 ? (pf_min = rand(rng, (0.9, 1.0)),) : nothing
        (inv=inv, profiles=profiles, policy=policy, n=n, topo=topo)
    end

    # The oracle: the constraints as documented, read from the raw record.
    function extrema_lp(s)
        inv = s.inv; n = s.n
        entry(key, k) = (v = get(inv, key, nothing); v isa Real ? (k == 1 ? Float64(v) : nothing) :
                         v === nothing ? nothing : Float64(v[k]))
        cp = get(s.profiles, get(inv, "control_profile", ""), D())
        pf = haskey(cp, "power_factor") ? cp["power_factor"]["pf"] : nothing
        droop = pf === nothing && s.topo != "THREE_LEG"          # precedence
        vw = droop ? get(cp, "volt_watt", nothing) : nothing
        vv = droop ? get(cp, "volt_var", nothing) : nothing
        model = Model(HiGHS.Optimizer); set_silent(model)
        @variable(model, P[1:n]); @variable(model, Q[1:n])
        for k in 1:n
            for (x, lo, hi) in ((P[k], entry("p_min", k), entry("p_max", k)), (Q[k], entry("q_min", k), entry("q_max", k)))
                lo === nothing || @constraint(model, x >= lo)
                hi === nothing || @constraint(model, x <= hi)
            end
            rated_zero = entry("s_max", k) == 0.0
            current_zero = haskey(inv, "i_max") &&
                (s.topo == "SINGLE_PHASE" ? minimum(inv["i_max"]) == 0.0 : entry("i_max", k) == 0.0)
            (rated_zero || current_zero) && @constraint(model, [x in (P[k], Q[k])], x == 0)
            if pf !== nothing                                     # sign(pf)|pf| Q + sin(phi) P = 0
                @constraint(model, sign(pf) * abs(pf) * Q[k] + sqrt(1 - pf^2) * P[k] == 0)
            end
            if s.policy !== nothing                               # P >= 0, pf_min |Q| <= sin(phi) P
                m = s.policy.pf_min; sine = sqrt(1 - m^2)
                @constraint(model, P[k] >= 0)
                @constraint(model, m * Q[k] <= sine * P[k]); @constraint(model, -m * Q[k] <= sine * P[k])
            end
            if vw !== nothing                                     # P <= base f(U); zero when base or curve is zero
                base = vw["p_ref"] == "S_MAX" ? something(entry("s_max", k), 0.0) :
                       vw["p_ref"] == "P_MAX" ? something(entry("p_max", k), 0.0) :
                       get(inv, "p_avail", 0.0) / n
                (base == 0.0 || all(iszero, vw["p_limits"])) && @constraint(model, P[k] <= 0)
            end
            if vv !== nothing                                     # Q = base f(U)
                base = something(entry("s_max", k), 0.0)
                (base == 0.0 || all(iszero, vv["q_limits"])) && @constraint(model, Q[k] == 0)
            end
        end
        if get(inv, "dc_link_coupled", false) === true && !haskey(inv, "dc_bus")
            @constraint(model, get(inv, "p_dc_min", 0.0) <= sum(P) <= get(inv, "p_dc_max", 0.0))
        end
        out = NamedTuple[]
        for k in 1:n
            bound(x, sense) = begin
                @objective(model, sense, x); optimize!(model)
                st = termination_status(model)
                st == MOI.OPTIMAL ? objective_value(model) :
                st in (MOI.INFEASIBLE,) ? NaN :
                (sense == MOI.MIN_SENSE ? -Inf : Inf)             # unbounded (or infeasible-or-unbounded on a feasible model)
            end
            push!(out, (p=(bound(P[k], MOI.MIN_SENSE), bound(P[k], MOI.MAX_SENSE)),
                        q=(bound(Q[k], MOI.MIN_SENSE), bound(Q[k], MOI.MAX_SENSE))))
        end
        @objective(model, MOI.FEASIBILITY_SENSE, 0); optimize!(model)
        termination_status(model) == MOI.OPTIMAL ? out : nothing
    end

    same(a, b) = (isinf(a) && isinf(b) && sign(a) == sign(b)) || isapprox(a, b; atol=1e-5, rtol=1e-6)
    rng = Random.Xoshiro(20261127)
    n_feasible = 0; n_forced = 0; n_infeasible = 0; seen = Set{Tuple}()
    for _ in 1:4000
        s = scenario(rng)
        rules = BMOPFTools._ibr_control_rules(s.inv, s.profiles, ["n"], s.policy)
        ranges = BMOPFTools._ibr_power_ranges(rules)
        states = BMOPFTools._ibr_coil_states(rules)
        oracle = extrema_lp(s)
        if oracle === nothing
            # Contradictory constraints: nothing may be dropped on their account.
            n_infeasible += 1
            @test all(s -> s !== :zero, states) || ranges !== nothing
            ranges === nothing && @test all(==(:free), states)
            continue
        end
        n_feasible += 1
        ok = ranges !== nothing && all(1:s.n) do k
            same(ranges[k].p[1], oracle[k].p[1]) && same(ranges[k].p[2], oracle[k].p[2]) &&
                same(ranges[k].q[1], oracle[k].q[1]) && same(ranges[k].q[2], oracle[k].q[2])
        end
        ok || @error "range mismatch" inv=repr(s.inv) profiles=repr(s.profiles) policy=s.policy ranges oracle
        @test ok
        for k in 1:s.n
            forced = all(x -> abs(x) <= 1e-6, (oracle[k].p..., oracle[k].q...))
            forced && (n_forced += 1)
            # Sound: a coil is dropped only when zero is forced. Complete: and whenever it is.
            @test (states[k] === :zero) == forced
        end
        push!(seen, (s.topo, haskey(s.inv, "dc_link_coupled"), s.policy !== nothing, !isempty(s.profiles)))
    end
    # The sample exercises what it claims to.
    @test n_feasible > 2000 && n_forced > 500 && n_infeasible > 50 && length(seen) >= 24
end
