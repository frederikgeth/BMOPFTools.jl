# Robust Opti-KRON prototype trial on real feeders.
#
#   julia --project=test --startup-file=no scripts/opti_kron_trial.jl \
#         <case.bmopf.json> [target_buses=150] [n_feeders=1] [Ebar=1e-3] [H=5]
#
# Environment: OPTI_KRON_SOLVER=highs|gurobi (default highs; gurobi needs
# Gurobi.jl in the active environment and a licence), OPTI_KRON_TIME_LIMIT
# (s per set, default 3600), OPTI_KRON_MASTER_LIMIT (s per master, default 900),
# OPTI_KRON_SETS (comma list, default all).
#
# Picks the LV networks (subtree below a delta-wye transformer's primary bus)
# whose size is closest to `target_buses`, extracts each as a standalone
# network, synthesizes injection samples (the SAPN models carry a single
# scenario), and runs Algorithm 1 for every uncertainty set plus the
# scenario-based baseline. Test-day samples are drawn from the same generator
# with a wider spread to probe out-of-sample errors.
#
# Synthetic samples: N_train "days" of a common demand level times a
# per-load lognormal factor; a third of the loads also export PV at midday.

using BMOPFTools, JuMP, Random, Statistics, Printf

const SOLVER = lowercase(get(ENV, "OPTI_KRON_SOLVER", "highs"))
if SOLVER == "gurobi"
    @eval using Gurobi
    const GRB_ENV = Gurobi.Env()
    optimizer() = Gurobi.Optimizer(GRB_ENV)
else
    @eval using HiGHS
    optimizer() = HiGHS.Optimizer()
end

path = ARGS[1]
target = length(ARGS) ≥ 2 ? parse(Int, ARGS[2]) : 150
nfeed = length(ARGS) ≥ 3 ? parse(Int, ARGS[3]) : 1
Ebar = length(ARGS) ≥ 4 ? parse(Float64, ARGS[4]) : 1e-3
H = length(ARGS) ≥ 5 ? parse(Int, ARGS[5]) : 5
time_limit = parse(Float64, get(ENV, "OPTI_KRON_TIME_LIMIT", "3600"))
master_time_limit = parse(Float64, get(ENV, "OPTI_KRON_MASTER_LIMIT", "900"))
wanted = split(get(ENV, "OPTI_KRON_SETS", "scenario,hull,box,ellipsoid,W-l1,W-l2,W-linf"), ",")

net = parse_bmopf(path)
cnt = downstream_bus_counts(net)
roots = String[]
for (_, sub) in net["transformer"], (_, t) in sub
    t isa AbstractDict && haskey(t, "bus_from") && haskey(cnt, t["bus_from"]) &&
        push!(roots, t["bus_from"])
end
sort!(unique!(roots); by=r -> (abs(cnt[r] - target), r))
noload = opti_kron_noload(net)

function samples(m, sub, N, spread, seed)
    rng = MersenneTwister(seed)
    ids = sort(collect(keys(sub["load"])))
    pv = Set(ids[1:3:end])
    level = [0.3 + 0.7rand(rng) for _ in 1:N]
    sun = [rand(rng) < 0.5 ? rand(rng) : 0.0 for _ in 1:N]
    mp = Dict(id => [level[s] * exp(spread * randn(rng)) - (id in pv ? 1.5sun[s] : 0.0)
                     for s in 1:N] for id in ids)
    mq = Dict(id => [level[s] * exp(spread * randn(rng)) for s in 1:N] for id in ids)
    opti_kron_load_injections(m, sub, mp, mq)
end

for root in roots[1:min(nfeed, length(roots))]
    sub = extract_downstream_network(net, root; noload=noload)
    m = opti_kron_model(sub; H=H)
    Utr = samples(m, sub, 29, 0.3, 1)
    Ute = samples(m, sub, 24, 0.45, 2)
    @printf("\n== solver %s, Ē=%g, H=%d\n", SOLVER, Ebar, H)
    @printf("== %s root %s: %d buses, %d loads, %d rows, %d pairs, mesh=%d, dropped=%d\n",
            basename(path), root, length(m.buses), length(sub["load"]), length(m.rows),
            length(m.pair_i), m.n_mesh_edges, sub["meta"]["extracted_from"]["dropped_boundary_elements"])
    @printf("   max |v−1| over training samples: %.4f p.u.\n", maximum(abs.(m.K * Utr)))
    flush(stdout)
    tot = vec(sum(Utr, dims=1))
    scen = Utr[:, unique([argmax(tot), argmin(tot)])]
    sets = [("scenario", OptiKronHull(scen)), ("hull", OptiKronHull(Utr)), ("box", OptiKronBox(Utr)),
            ("ellipsoid", OptiKronEllipsoid(Utr)), ("W-l1", OptiKronWasserstein(Utr; p=1)),
            ("W-l2", OptiKronWasserstein(Utr; p=2)), ("W-linf", OptiKronWasserstein(Utr; p=Inf))]
    @printf("   %-10s %7s %7s %6s %6s %5s %6s %8s %10s %8s %8s\n", "set", "kept", "of", "super",
            "≥LB", "red%", "iters", "time", "status", "train/Ē", "test/Ē")
    flush(stdout)
    for (name, S) in sets
        name in wanted || continue
        ts = @elapsed scr = opti_kron_screen(m, S, Ebar)
        res = opti_kron_reduction(m, S, Ebar; optimizer=optimizer, screen=scr,
                                  time_limit=time_limit, master_time_limit=master_time_limit)
        etr = maximum(abs.(opti_kron_errors(m, res.assignment, Utr))) / Ebar
        ete = maximum(abs.(opti_kron_errors(m, res.assignment, Ute))) / Ebar
        @printf("   %-10s %7d %7d %6d %6d %5.1f %6d %8.1f %10s %8.2f %8.2f\n", name, count(scr.keep),
                length(scr.keep), length(res.super_nodes), res.lower_bound, 100res.reduction,
                length(res.history), res.time, res.status, etr, ete)
        flush(stdout)
    end
end
