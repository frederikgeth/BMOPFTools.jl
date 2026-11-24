# Worked example for docs/src/tutorial_network_reduction.md (outputs quoted there).
#   julia --project=test --startup-file=no examples/opti_kron/reduction_workflow.jl
#
# A synthetic 11 kV / 415 V four-wire LV feeder (generated below, so the
# tutorial needs no external data) taken through the three reductions:
# neutral Kron reduction, topology simplification, and Opti-KRON.
using BMOPFTools, JuMP, HiGHS, Ipopt, Random, Printf, Statistics

# ── 1. A feeder with the features that matter ───────────────────────────────
# mv ──Dyn── lv0 ── p1 ── p2 ── … ── p12        trunk, 40 m spans
#                         │           │
#                         q1 … q4     r1 … r4   laterals at p4 and p8, 30 m spans
# Customers are single-phase on rotating phases; some poles carry no customer
# (pass-through). The neutral is solidly earthed at the transformer and through
# finite MEN electrodes (10 Ω) at every third pole.
function synthetic_lv_feeder()
    tn = ["a", "b", "c", "n"]
    lc = Dict{String,Any}()
    for i in 1:4, j in 1:4                        # Ω/m, four-core cable with mutual coupling
        lc["R_series_$(i)_$(j)"] = i == j ? 3.2e-4 : 0.6e-4
        lc["X_series_$(i)_$(j)"] = i == j ? 0.8e-4 : 0.3e-4
    end
    bus = Dict{String,Any}("mv" => Dict{String,Any}("terminal_names" => ["a", "b", "c"]),
                           "lv0" => Dict{String,Any}("terminal_names" => tn,
                                                    "perfectly_grounded_terminals" => ["n"]))
    line = Dict{String,Any}(); load = Dict{String,Any}(); shunt = Dict{String,Any}()
    addbus(b) = (bus[b] = Dict{String,Any}("terminal_names" => tn))
    addline(a, b, len) = (line["l_$b"] = Dict{String,Any}("bus_from" => a, "bus_to" => b,
        "linecode" => "cable", "length" => len, "terminal_map_from" => tn, "terminal_map_to" => tn))
    trunk = ["p$k" for k in 1:12]
    prev = "lv0"
    for (k, b) in enumerate(trunk)
        addbus(b); addline(prev, b, 40.0); prev = b
        if k % 3 == 0                                       # MEN electrode, 10 Ω
            shunt["men_$b"] = Dict{String,Any}("bus" => b, "terminal_map" => ["n"],
                                               "G_1_1" => 0.1, "B_1_1" => 0.0)
        end
    end
    for (root, tag) in (("p4", "q"), ("p8", "r"))
        prev = root
        for k in 1:4
            b = "$tag$k"; addbus(b); addline(prev, b, 30.0); prev = b
        end
    end
    customers = ["p3", "p4", "p6", "p7", "p8", "p10", "p11", "p12",
                 "q2", "q3", "q4", "r1", "r2", "r3", "r4"]      # p1, p2, p5, p9, q1 pass through
    for (k, b) in enumerate(customers), h in 1:2              # two customers per loaded pole
        ph = ["a", "b", "c"][mod1(2k + h, 3)]
        load["c_$(b)_$h"] = Dict{String,Any}("bus" => b, "terminal_map" => [ph, "n"],
            "configuration" => "SINGLE_PHASE", "model" => "constant_power",
            "p_nom" => [2500.0], "q_nom" => [500.0])
    end
    net = Dict{String,Any}(
        "bus" => bus, "line" => line, "load" => load, "shunt" => shunt,
        "linecode" => Dict{String,Any}("cable" => lc),
        "transformer" => Dict{String,Any}("delta_wye" => Dict{String,Any}("tx" => Dict{String,Any}(
            "bus_from" => "mv", "bus_to" => "lv0", "terminal_map_from" => ["a", "b", "c"],
            "terminal_map_to" => tn, "v_nom_from" => 11000.0, "v_nom_to" => 415.0,
            "tap" => 1.0, "s_rating" => 315000.0, "r_series" => 0.01, "x_series" => 0.04))),
        "voltage_source" => Dict{String,Any}("grid" => Dict{String,Any}("bus" => "mv",
            "terminal_map" => ["a", "b", "c"], "v_magnitude" => fill(11000 / sqrt(3), 3),
            "v_angle" => [0.0, -2π / 3, 2π / 3])),
        "terminal_conventions" => Dict{String,Any}("phase" => ["a", "b", "c"], "neutral" => ["n"]))
    parse_bmopf(BMOPFTools.JSON3.write(net); from_string=true)
end

net = synthetic_lv_feeder()
@printf("feeder: %d buses, %d lines, %d customers, %d MEN electrodes, Ybus %d nodes\n",
        length(net["bus"]), length(net["line"]), length(net["load"]), length(net["shunt"]),
        size(ybus_passive(net).Y, 1))

# ── 2. Loadings: evening peak, midday PV export, night ─────────────────────
rng = MersenneTwister(2026)
ids = sort(collect(keys(net["load"])))
pv = Set(ids[1:3:end])                                   # a third of customers have PV
hours = 48
level = [0.25 + 0.75 * max(0, sin(π * (mod(h, 24) - 6) / 18))^2 for h in 1:hours]   # evening peak
sun = [max(0, sin(π * (mod(h, 24) - 6) / 12)) for h in 1:hours]                    # midday
mult = Dict(id => [level[h] * exp(0.35randn(rng)) - (id in pv ? 1.6sun[h] : 0.0) for h in 1:hours]
            for id in ids)
train = Dict(id => v[1:24] for (id, v) in mult)          # day 1: training
test = Dict(id => v[25:48] for (id, v) in mult)          # day 2: test

ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0, "tol" => 1e-9)
function with_loads(n, base, mult, h)
    c = deepcopy(n)
    for (id, ld) in c["load"]
        haskey(mult, id) || continue
        ld["p_nom"] = Float64.(base["load"][id]["p_nom"]) .* mult[id][h]
        ld["q_nom"] = Float64.(base["load"][id]["q_nom"]) .* abs(mult[id][h])
    end
    c
end
truth = [solve_pf(with_loads(net, net, test, h); optimizer=ipopt) for h in 1:24]
function vpn(n, r, b, t)
    rb = r["bus"][b]
    U = complex(rb[t]["vr"], rb[t]["vi"])
    _, nt = BMOPFTools._ok_phase_terminals(n, n["bus"][b])
    nt !== nothing && haskey(rb, nt) && (U -= complex(rb[nt]["vr"], rb[nt]["vi"]))
    abs(U)
end
vmin_full = minimum(vpn(net, truth[h], b, t) for h in 1:24, b in keys(net["bus"])
                    if b != "mv" for t in ("a", "b", "c") if haskey(truth[h]["bus"][b], t))
@printf("full model, test day: lowest phase-to-neutral voltage %.1f V\n", vmin_full)

# error of a reduced case against the truth, per original bus (via super-node map)
function compare(red, superof, mult_used; lift_model=nothing, base=net)
    worst = 0.0; worst_lift = 0.0; covered = Set{String}()
    for h in 1:24
        r = solve_pf(with_loads(red, net, test, h); optimizer=ipopt)
        ll = lift_model === nothing ? nothing : lift_solution(base, red, r; model=lift_model)
        for b in keys(net["bus"]), t in ("a", "b", "c")
            b == "mv" && continue
            haskey(truth[h]["bus"][b], t) || continue
            est = get(superof, b, b)
            haskey(red["bus"], est) || continue
            push!(covered, b)
            vt = vpn(net, truth[h], b, t)
            worst = max(worst, abs(vpn(red, r, est, t) - vt))
            if ll !== nothing
                d = get(get(ll["bus"], b, Dict()), t, Dict())
                haskey(d, "vpn_lifted") && (worst_lift = max(worst_lift, abs(d["vpn_lifted"] - vt)))
            end
        end
    end
    worst, worst_lift, length(covered)
end
nbus_lv = length(net["bus"]) - 1

# ── 3. Neutral Kron reduction: is the neutral really at earth potential? ────
nk = kron_reduce_neutrals(net)
prov = nk["_meta"]["kron_reduction"]
println("neutral Kron: classification = ", prov["classification"],
        ", forced-ground buses = ", length(prov["forced_ground_buses"]))
e_nk, _, _ = compare(nk, Dict{String,String}(), test)
@printf("neutral Kron: Ybus %d → %d nodes, worst voltage error %.2f V\n",
        size(ybus_passive(net).Y, 1), size(ybus_passive(nk).Y, 1), e_nk)

# ── 4. Simplification: exact, but what does it forget? ──────────────────────
sp = simplify_network(net)
e_sp, _, cov_sp = compare(sp, Dict{String,String}(), test)
@printf("simplify: %d → %d buses, worst error %.2e V, voltages kept for %d of %d LV buses\n",
        length(net["bus"]), length(sp["bus"]), e_sp, cov_sp, nbus_lv)

# ── 5. Opti-KRON: remove loaded buses with a voltage guarantee ──────────────
m = opti_kron_model(net; H=4)
U = opti_kron_load_injections(m, net, train)
for (name, S) in [("scenario", OptiKronHull(U[:, unique([argmax(vec(sum(U, dims=1))), argmin(vec(sum(U, dims=1)))])])),
                  ("hull", OptiKronHull(U)), ("box", OptiKronBox(U))]
    for Ebar in (0.005, 0.01)
        res = opti_kron_reduction(m, S, Ebar; optimizer=HiGHS.Optimizer,
                                  keep=opti_kron_required_buses(net), time_limit=600)
        Utest = opti_kron_load_injections(m, net, test)
        etest = maximum(abs.(opti_kron_errors(m, res.assignment, Utest))) / Ebar
        @printf("Opti-KRON %-8s Ē=%.3f: %2d buses kept (%s), linear-model error on test day %.2f Ē\n",
                name, Ebar, length(res.super_nodes), res.status, etest)
    end
end

# ── 6. Build, solve, lift, verify ───────────────────────────────────────────
Ebar = 0.01
res = opti_kron_reduction(m, OptiKronBox(U), Ebar; optimizer=HiGHS.Optimizer,
                          keep=opti_kron_required_buses(net))
red = kron_reduce_buses(net, m, res; Ebar=Ebar)
lg = red["_kron_reduction"]
@printf("reduced case: %d buses, %d lines (%d equivalents), %d shunts (%d equivalents), Ybus %d nodes\n",
        length(red["bus"]), length(red["line"]), length(lg["equivalent_lines"]),
        length(red["shunt"]), length(lg["equivalent_shunts"]), size(ybus_passive(red).Y, 1))
println("kept buses: ", sort(res.super_nodes))
e_ok, e_ok_lift, _ = compare(red, lg["super_node_of"], test; lift_model=m)
@printf("Opti-KRON box Ē=%.2f (= %.1f V): worst AC error on test day %.2f V, after lift %.2f V\n",
        Ebar, Ebar * 240, e_ok, e_ok_lift)
println("voltage limits tightened: ", lg["n_voltage_limits_tightened"],
        "; dropped line current limits: ", length(lg["dropped_line_current_limits"]))
