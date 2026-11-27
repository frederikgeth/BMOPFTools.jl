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
const _IBR_RULES_HAS_IPOPT = Base.find_package("Ipopt") !== nothing
if _IBR_RULES_HAS_IPOPT
    using Ipopt
end

@testset "IBR control rules — LP extrema oracle" begin
    D = Dict{String,Any}
    U = 1000.0
    boxes = ((nothing, nothing), (0.0, 0.0), (0.0, U), (-U, U), (-U, 0.0), (300.0, 300.0),
             (nothing, 0.0), (0.0, nothing), (-500.0, -100.0))

    # One scenario: a raw IBR record, its profile, its minimum-power-factor policy.
    function scenario(rng)
        topo, tm = rand(rng, (("SINGLE_PHASE", ["a", "n"]), ("SINGLE_PHASE", ["a", "b"]),
                              ("FOUR_LEG", ["a", "b", "n"]), ("FOUR_LEG", ["a", "b", "c", "n"]),
                              ("FOUR_LEG", ["a", "b"]),                 # no neutral: coils against earth
                              ("THREE_LEG", ["a", "b", "c"]), ("THREE_LEG", ["a", "b"])))
        n = topo == "SINGLE_PHASE" ? 1 : topo == "THREE_LEG" ? length(tm) : count(!=("n"), tm)
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
        0.6 <= r < 0.65 && n > 1 && (inv["s_max"] = [0.0])            # a short vector: coil 1 only
        im = rand(rng)
        im < 0.1 && (inv["i_max"] = [rand(rng) < 0.3 ? 0.0 : 50.0 for _ in 1:n])
        0.1 <= im < 0.13 && (inv["i_max"] = [50.0 for _ in 1:n]; push!(inv["i_max"], 0.0))   # a neutral entry
        0.13 <= im < 0.16 && (inv["i_max"] = 0.0)
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
                         v === nothing || k > length(v) ? nothing : Float64(v[k]))
        cp = get(s.profiles, get(inv, "control_profile", ""), D())
        pf = haskey(cp, "power_factor") ? cp["power_factor"]["pf"] : nothing
        droop = pf === nothing && s.topo != "THREE_LEG"          # precedence
        vw = droop ? get(cp, "volt_watt", nothing) : nothing
        vv = droop ? get(cp, "volt_var", nothing) : nothing
        # A fresh model per solve: a bounded solve that follows an unbounded one
        # on the same HiGHS model can come back with a stale status.
        build() = begin
        model = Model(HiGHS.Optimizer); set_silent(model)
        @variable(model, P[1:n]); @variable(model, Q[1:n])
        for k in 1:n
            for (x, lo, hi) in ((P[k], entry("p_min", k), entry("p_max", k)), (Q[k], entry("q_min", k), entry("q_max", k)))
                lo === nothing || @constraint(model, x >= lo)
                hi === nothing || @constraint(model, x <= hi)
            end
            # A zero rating: enforced by the OPF only. It counts unless the power
            # flow could still carry current beside it (a live Volt-var law, a DC bus).
            rated_zero = entry("s_max", k) == 0.0
            current_zero = haskey(inv, "i_max") &&
                (s.topo == "SINGLE_PHASE" ? minimum(inv["i_max"]) == 0.0 : entry("i_max", k) == 0.0)
            live_vv = vv !== nothing && !all(iszero, vv["q_limits"]) && something(entry("s_max", k), 0.0) != 0.0
            (rated_zero || current_zero) && !live_vv && !haskey(inv, "dc_bus") &&
                @constraint(model, [x in (P[k], Q[k])], x == 0)
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
        (model, P, Q)
        end
        solve(pick, sense) = begin
            model, P, Q = build()
            @objective(model, sense, pick(P, Q)); optimize!(model)
            st = termination_status(model)
            st == MOI.OPTIMAL && return objective_value(model)
            st == MOI.INFEASIBLE && return NaN
            st in (MOI.DUAL_INFEASIBLE, MOI.INFEASIBLE_OR_UNBOUNDED) || error("unexpected LP status $st")
            sense == MOI.MIN_SENSE ? -Inf : Inf
        end
        feasible = let (model, _, _) = build()
            optimize!(model); termination_status(model) == MOI.OPTIMAL
        end
        feasible || return nothing
        [(p=(solve((P, Q) -> P[k], MOI.MIN_SENSE), solve((P, Q) -> P[k], MOI.MAX_SENSE)),
          q=(solve((P, Q) -> Q[k], MOI.MIN_SENSE), solve((P, Q) -> Q[k], MOI.MAX_SENSE))) for k in 1:n]
    end

    same(a, b) = (isinf(a) && isinf(b) && sign(a) == sign(b)) || isapprox(a, b; atol=1e-5, rtol=1e-6)
    rng = Random.Xoshiro(20261127)
    n_feasible = 0; n_forced = 0; n_infeasible = 0
    # Which ingredients a scenario has, so that coverage is checked per ingredient.
    features(s) = begin
        cp = get(s.profiles, "cp", D()); inv = s.inv
        f = String[s.topo * "/" * string(length(inv["terminal_map"]))]
        haskey(cp, "power_factor") && push!(f, "pf"); haskey(cp, "volt_var") && push!(f, "volt_var")
        haskey(cp, "volt_watt") && push!(f, "volt_watt:" * cp["volt_watt"]["p_ref"])
        s.policy !== nothing && push!(f, "min_pf")
        haskey(inv, "dc_bus") && push!(f, "dc_bus")
        get(inv, "dc_link_coupled", false) === true && push!(f, haskey(inv, "p_dc_min") ? "dc_range" : "dc_zero")
        haskey(inv, "s_max") && push!(f, inv["s_max"] isa Real ? "s_max_scalar" : "s_max")
        haskey(inv, "i_max") && push!(f, inv["i_max"] isa Real ? "i_max_scalar" : "i_max")
        f
    end
    with_forced = Dict{String,Int}(); with_free = Dict{String,Int}()
    for _ in 1:4000
        s = scenario(rng)
        rules = BMOPFTools._ibr_control_rules(s.inv, s.profiles, ["n"], s.policy)
        ranges = BMOPFTools._ibr_power_ranges(rules)
        states = BMOPFTools._ibr_coil_states(rules)
        oracle = extrema_lp(s)
        if oracle === nothing
            # Contradictory constraints: nothing may be dropped on their account.
            n_infeasible += 1
            @test all(==(:free), states)
            continue
        end
        n_feasible += 1
        ok = ranges !== nothing && all(1:s.n) do k
            same(ranges[k].p[1], oracle[k].p[1]) && same(ranges[k].p[2], oracle[k].p[2]) &&
                same(ranges[k].q[1], oracle[k].q[1]) && same(ranges[k].q[2], oracle[k].q[2])
        end
        ok || @error "range mismatch" inv=repr(s.inv) profiles=repr(s.profiles) policy=s.policy ranges=repr(ranges) oracle=repr(oracle)
        @test ok
        for k in 1:s.n
            forced = all(x -> abs(x) <= 1e-6, (oracle[k].p..., oracle[k].q...))
            forced && (n_forced += 1)
            # Sound: a coil is dropped only when zero is forced. Complete: and whenever it is.
            @test (states[k] === :zero) == forced
        end
        tally = any(==(:zero), states) ? with_forced : with_free
        for f in features(s); tally[f] = get(tally, f, 0) + 1; end
    end
    # The sample exercises what it claims to.
    @test n_feasible > 2000 && n_forced > 500 && n_infeasible > 50
    expected = ["SINGLE_PHASE/2", "FOUR_LEG/2", "FOUR_LEG/3", "FOUR_LEG/4", "THREE_LEG/2", "THREE_LEG/3",
                "pf", "volt_var", "volt_watt:S_MAX", "volt_watt:P_MAX", "volt_watt:P_AVAILABLE", "min_pf",
                "dc_bus", "dc_range", "dc_zero", "s_max", "s_max_scalar", "i_max", "i_max_scalar"]
    for f in expected
        # Every ingredient appears both where a coil is forced to zero and where none is.
        @test get(with_forced, f, 0) >= 5
        @test get(with_free, f, 0) >= 5
    end

    # The LP above shares one thing with the rules: the list of constraints. It
    # cannot see a constraint both leave out, or one the solver does not really
    # stamp. So the verdict that matters is also held against the solver
    # itself: wherever a coil is reported as carrying no current, the built
    # model must return none. The power flow is used where it accepts the
    # record (fixed setpoints) and the OPF otherwise, so both are covered.
    if _IBR_RULES_HAS_IPOPT
        @testset "a coil reported as zero carries no current in the built model" begin
            base = parse_bmopf(joinpath(@__DIR__, "data", "profiler_systems", "eu_tn_four_wire.json"))
            quiet(f) = redirect_stdout(devnull) do
                redirect_stderr(devnull) do
                    f()
                end
            end
            rng2 = Random.Xoshiro(495)
            solved = Dict(:pf => 0, :opf => 0); checked = 0; tries = 0
            while (solved[:pf] < 12 || solved[:opf] < 12) && tries < 6000
                tries += 1
                s = scenario(rng2)
                # Out of scope here: a policy needs its own extras block, and a DC bus a DC network.
                (s.policy === nothing && !haskey(s.inv, "dc_bus")) || continue
                rules = BMOPFTools._ibr_control_rules(s.inv, s.profiles, ["n"], nothing)
                states = BMOPFTools._ibr_coil_states(rules)
                any(==(:zero), states) || continue
                net = deepcopy(base)
                net["ibr"] = D("x" => merge(s.inv, D("bus" => "lv2", "prime_mover" => "PV")))
                isempty(s.profiles) || (net["control_profile"] = deepcopy(s.profiles))
                kind = :pf
                res = try
                    quiet(() -> solve_pf(net))
                catch
                    kind = :opf
                    solved[:opf] < 12 || continue
                    try quiet(() -> solve_opf(net)) catch; nothing end
                end
                kind == :pf && solved[:pf] >= 12 && continue
                (res !== nothing && get(res, "feasible", false) === true && haskey(res, "ibr")) || continue
                coils = res["ibr"]["x"]
                for (k, (positive, _)) in enumerate(rules.coils)
                    states[k] === :zero && haskey(coils, positive) || continue
                    current = hypot(coils[positive]["cri"], coils[positive]["cii"])
                    current < 1e-3 || @error "zero coil carries current" kind inv=repr(s.inv) profiles=repr(s.profiles) current
                    @test current < 1e-3
                    checked += 1
                end
                solved[kind] += 1
            end
            @test solved[:pf] >= 12 && solved[:opf] >= 12 && checked >= 24
        end
    end
end
