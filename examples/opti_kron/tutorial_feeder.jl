# Worked example for docs/src/tutorial_opti_kron.md (outputs quoted there).
#   julia --project=test --startup-file=no examples/opti_kron/tutorial_feeder.jl
using BMOPFTools, JuMP, HiGHS, Ipopt, Printf

# Portable pseudo-random normals (xorshift64* + Box–Muller). Julia's own
# random streams may differ between versions, which would change every number
# quoted in the tutorial; this generator gives the same stream everywhere.
mutable struct PortableRNG
    s::UInt64
end
function unif!(g::PortableRNG)
    x = g.s
    x ⊻= x >> 12; x ⊻= x << 25; x ⊻= x >> 27
    g.s = x
    ((x * 0x2545f4914f6cdd1d) >> 11) / 2.0^53
end
gauss!(g::PortableRNG) = sqrt(-2log(max(unif!(g), eps()))) * cos(2π * unif!(g))


# A small 3-phase, 3-wire radial feeder: s ── b1 ── b2 ── b3
#                                                    └── b4 ── b5
function tutorial_feeder()
    lc = Dict{String,Any}()
    for a in 1:3, b in 1:3
        lc["R_series_$(a)_$(b)"] = a == b ? 4e-4 : 0.0        # Ω/m
        lc["X_series_$(a)_$(b)"] = a == b ? 2.5e-4 : 0.0
    end
    tn = ["1", "2", "3"]
    bus = Dict(b => Dict("terminal_names" => tn) for b in ["s", "b1", "b2", "b3", "b4", "b5"])
    edges = [("s", "b1"), ("b1", "b2"), ("b2", "b3"), ("b2", "b4"), ("b4", "b5")]
    line = Dict("l$k" => Dict("bus_from" => a, "bus_to" => b, "length" => 100.0,
                              "linecode" => "lc", "terminal_map_from" => tn,
                              "terminal_map_to" => tn) for (k, (a, b)) in enumerate(edges))
    load = Dict("d$b" => Dict("bus" => b, "configuration" => "WYE", "model" => "CONSTANT_POWER",
                              "p_nom" => [3000.0, 2000.0, 1000.0], "q_nom" => [500.0, 300.0, 100.0],
                              "terminal_map" => tn, "v_nom" => [230.0, 230.0, 230.0])
                for b in ["b1", "b3", "b4", "b5"])
    net = Dict("bus" => bus, "line" => line, "linecode" => Dict("lc" => lc), "load" => load,
               "voltage_source" => Dict("src" => Dict("bus" => "s", "terminal_map" => tn,
                   "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2π / 3, 2π / 3])),
               "terminal_conventions" => Dict("phase" => tn, "neutral" => String[]))
    parse_bmopf(BMOPFTools.JSON3.write(net); from_string=true)
end

net = tutorial_feeder()
m = opti_kron_model(net; H=4)
println(m)

# 1. The linear voltage model is LinDistFlow here: K = shared path resistance
r_b2 = m.rowof[(m.busof["b2"], "1")]; r_b5 = m.rowof[(m.busof["b5"], "1")]
@printf("K_P[b2,b5] = %.4e p.u./kW;  2 × 0.04 Ω × 1 kW / (230 V)² = %.4e\n",
        m.K[r_b2, r_b5], 2 * 0.04 * 1e3 / 230^2)

# 2. Training samples: 24 hours, a common level times per-load noise
rng = PortableRNG(57)                 # seed chosen so the scenario failure of section 4 shows
ids = sort(collect(keys(net["load"])))
level = [0.4 + 0.6 * (1 - cos(2π * h / 24)) / 2 for h in 0:23]
mult = Dict(id => [level[h] * exp(0.25gauss!(rng)) for h in 1:24] for id in ids)
U = opti_kron_load_injections(m, net, mult)
@printf("%d samples, %d active coordinates, largest |v - 1| = %.4f p.u.\n",
        size(U, 2), length(OptiKronHull(U).idx), maximum(abs.(m.K * U)))

# 3. One cluster by hand: merge b3 into b2
sup = collect(1:length(m.buses)); sup[m.busof["b3"]] = m.busof["b2"]
E = opti_kron_errors(m, sup, U)
@printf("b3 → b2: worst error over the samples %.2e p.u.\n", maximum(abs.(E)))

# 4. Scenario-based vs robust reductions at Ē = 8e-3 (loose, so six buses can cluster)
Ebar = 8e-3
tot = vec(sum(U, dims=1))
scen = U[:, [argmax(tot), argmin(tot)]]
for (name, S) in [("scenario", OptiKronHull(scen)), ("hull", OptiKronHull(U)),
                  ("box", OptiKronBox(U)), ("ellipsoid", OptiKronEllipsoid(U))]
    res = opti_kron_reduction(m, S, Ebar; optimizer=HiGHS.Optimizer)
    worst = maximum(abs.(opti_kron_errors(m, res.assignment, U))) / Ebar
    @printf("%-9s super-nodes %-22s worst sample error %.2f Ē\n", name,
            string(res.super_nodes), worst)
end

# 5. Build the reduced case, solve it, lift the answer back
res = opti_kron_reduction(m, OptiKronHull(U), Ebar; optimizer=HiGHS.Optimizer,
                          keep=opti_kron_required_buses(net))
red = kron_reduce_buses(net, m, res; Ebar=Ebar)
println("reduced buses: ", sort(collect(keys(red["bus"]))))
println("equivalent lines: ", red["_kron_reduction"]["equivalent_lines"])
ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
pf_full = solve_pf(net; optimizer=ipopt)
pf_red = solve_pf(red; optimizer=ipopt)
lifted = lift_solution(net, red, pf_red; model=m)
vm(r, b) = abs(complex(r["bus"][b]["1"]["vr"], r["bus"][b]["1"]["vi"]))
for (j, i) in sort(collect(red["_kron_reduction"]["super_node_of"]))
    @printf("%s (→ %s): full %.3f V, super-node %.3f V, lifted %.3f V\n", j, i,
            vm(pf_full, j), vm(pf_red, i), lifted["bus"][j]["1"]["vpn_lifted"])
end
