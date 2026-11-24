# Replicate the IEEE European LV feeder results of Mokhtari et al.,
# "Robust Optimal Network Reduction for Distribution Systems" (arXiv:2611.21313),
# Fig. 2(a) and §IV-B, with the robust Opti-KRON prototype.
#
#   julia --project=<env with Gurobi> --startup-file=no scripts/opti_kron_eulv.jl \
#         [lvtestcase_dir] [Ebars=0.001,0.002,0.003,0.004,0.005] [sets=all]
#
# lvtestcase_dir defaults to the DistributionTestCases.jl copy (deck template,
# one static snapshot, and the 1,440 one-minute load profiles). Paper setup:
# H = 5, ε = 0.01, 95% quantile radii, K = 3, all 1,440 profiles as training
# samples, scenario baseline = samples of largest/smallest total injection.
#
# Paper reference values (text): 11,227 candidate pairs; structural maximum
# 88.6%; at Ē = 0.001 hull 83.0%, Wasserstein-ℓ1 75.0%, scenario 86.7%;
# screening keeps 54–70% of pairs at Ē = 0.001 and 89–98% at 0.005.

using BMOPFTools, JuMP, Printf, Statistics

const SOLVER = lowercase(get(ENV, "OPTI_KRON_SOLVER", "gurobi"))
if SOLVER == "gurobi"
    @eval using Gurobi
    const GRB_ENV = Gurobi.Env()
    optimizer() = Gurobi.Optimizer(GRB_ENV)
else
    @eval using HiGHS
    optimizer() = HiGHS.Optimizer()
end
time_limit = parse(Float64, get(ENV, "OPTI_KRON_TIME_LIMIT", "7200"))
master_time_limit = parse(Float64, get(ENV, "OPTI_KRON_MASTER_LIMIT", "1800"))

dir = length(ARGS) ≥ 1 ? ARGS[1] :
      joinpath(homedir(), "Documents/GitHub/DistributionTestCases.jl/src/data/lvtestcase")
Ebars = length(ARGS) ≥ 2 ? parse.(Float64, split(ARGS[2], ",")) : [1e-3, 2e-3, 3e-3, 4e-3, 5e-3]
wanted = length(ARGS) ≥ 3 ? split(ARGS[3], ",") :
         ["scenario", "hull", "box", "ellipsoid", "W-l1", "W-l2", "W-linf"]

# ── network: static snapshot, re-rooted at the 11 kV source bus ─────────────
full = from_dss(joinpath(dir, "snapshots/lvtestcase_pmd_t1000.dss"))
full isa Tuple && (full = first(full))
net = extract_downstream_network(full, "sourcebus")
m = opti_kron_model(net; H=5)
npairs = count(p -> m.pair_i[p] != m.pair_j[p], eachindex(m.pair_i))
@printf("European LV: %d nodes, %d rows, %d candidate pairs (paper: 907 nodes, 11,227 pairs)\n",
        length(m.buses), length(m.rows), npairs)
flush(stdout)

# ── 1,440 one-minute samples from the load profiles (fixed PF 0.95) ─────────
shape = Dict{String,Int}()
for ln in eachline(joinpath(dir, "lvtestcase_pmd_template.dss"))
    mm = match(r"^New Load\.(\S+) .*Yearly=Shape_(\d+)", ln)
    mm === nothing || (shape[lowercase(mm[1])] = parse(Int, mm[2]))
end
prof = Dict(k => parse.(Float64, strip.(readlines(joinpath(dir, "profiles/load_profile_$k.txt"))))
            for k in unique(values(shape)))
mult = Dict{String,Vector{Float64}}()
for (id, ld) in net["load"]
    k = shape[lowercase(id)]
    pnom_kw = sum(Float64.(ld["p_nom"])) / 1e3        # snapshot t = 1000 (kW = 1 × profile)
    mult[id] = prof[k] ./ pnom_kw                       # → kW = profile[t]
end
U = opti_kron_load_injections(m, net, mult)
@printf("samples: %d, active coordinates: %d, max |v−1| = %.4f p.u.\n",
        size(U, 2), length(OptiKronHull(U).idx), maximum(abs.(m.K * U)))
flush(stdout)

# ── structural maximum (no error constraint binds) ──────────────────────────
res = opti_kron_reduction(m, OptiKronBox(U), 1.0; optimizer=optimizer, time_limit=time_limit,
                          preserve_radial=true,
                          master_time_limit=master_time_limit)
@printf("structural maximum: %.1f%% (%d super-nodes, %s; paper 88.6%%)\n",
        100res.reduction, length(res.super_nodes), res.status)
flush(stdout)

tot = vec(sum(U, dims=1))
scen = U[:, unique([argmax(tot), argmin(tot)])]
mk = Dict("scenario" => () -> OptiKronHull(scen), "hull" => () -> OptiKronHull(U),
          "box" => () -> OptiKronBox(U), "ellipsoid" => () -> OptiKronEllipsoid(U),
          "W-l1" => () -> OptiKronWasserstein(U; p=1), "W-l2" => () -> OptiKronWasserstein(U; p=2),
          "W-linf" => () -> OptiKronWasserstein(U; p=Inf))
sets = Dict(name => mk[name]() for name in wanted)

@printf("\n%-8s %-10s %6s %6s %7s %6s %6s %5s %8s %10s %8s\n", "Ē", "set", "kept%", "super",
        "≥LB", "red%", "iters", "smp", "time", "status", "max/Ē")
flush(stdout)
for Ebar in Ebars, name in wanted
    S = sets[name]
    scr = opti_kron_screen(m, S, Ebar)
    r = opti_kron_reduction(m, S, Ebar; optimizer=optimizer, screen=scr, time_limit=time_limit,
                            preserve_radial=true,
                            master_time_limit=master_time_limit)
    errmax = maximum(abs.(opti_kron_errors(m, r.assignment, U))) / Ebar
    @printf("%-8g %-10s %6.1f %6d %7d %6.1f %6d %5d %8.1f %10s %8.2f\n", Ebar, name,
            100count(p -> scr.keep[p] && m.pair_i[p] != m.pair_j[p], eachindex(scr.keep)) / npairs,
            length(r.super_nodes), r.lower_bound,
            100r.reduction, length(r.history), isempty(r.history) ? 0 : r.history[end].n_samples,
            r.time, r.status, errmax)
    flush(stdout)
end
