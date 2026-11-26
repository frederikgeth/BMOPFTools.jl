# AC validation of a robust Opti-KRON reduction on the IEEE European LV feeder.
#
#   julia --project=<env with Gurobi + Ipopt> --startup-file=no \
#         scripts/opti_kron_ac_validation.jl [lvtestcase_dir] [set=hull] [Ebar=1e-3] [stride=30]
#
# 1. Reduce with the chosen set (all 1,440 one-minute samples as training),
#    keeping voltage-source/transformer buses so the result is buildable.
# 2. Build the reduced BMOPF case with kron_reduce_buses.
# 3. For every `stride`-th sample: AC power flow on the full and reduced case;
#    compare the AC voltage error at every eliminated bus with Ē, with the
#    linear-model error, and with the linear lift (lift_solution).

using BMOPFTools, JuMP, Ipopt, Printf, Statistics
const SOLVER = lowercase(get(ENV, "OPTI_KRON_SOLVER", "gurobi"))
if SOLVER == "gurobi"
    @eval using Gurobi
    const GRB_ENV = Gurobi.Env()
    milp() = Gurobi.Optimizer(GRB_ENV)
else
    @eval using HiGHS
    milp() = HiGHS.Optimizer()
end

dir = length(ARGS) ≥ 1 ? ARGS[1] :
      joinpath(homedir(), "Documents/GitHub/DistributionTestCases.jl/src/data/lvtestcase")
setname = length(ARGS) ≥ 2 ? ARGS[2] : "hull"
Ebar = length(ARGS) ≥ 3 ? parse(Float64, ARGS[3]) : 1e-3
stride = length(ARGS) ≥ 4 ? parse(Int, ARGS[4]) : 30

full = from_dss(joinpath(dir, "snapshots/lvtestcase_pmd_t1000.dss"))
full isa Tuple && (full = first(full))
net = extract_downstream_network(full, "sourcebus")
m = opti_kron_model(net; H=5)
shape = Dict{String,Int}()
for ln in eachline(joinpath(dir, "lvtestcase_pmd_template.dss"))
    mm = match(r"^New Load\.(\S+) .*Yearly=Shape_(\d+)", ln)
    mm === nothing || (shape[lowercase(mm[1])] = parse(Int, mm[2]))
end
prof = Dict(k => parse.(Float64, strip.(readlines(joinpath(dir, "profiles/load_profile_$k.txt"))))
            for k in unique(values(shape)))
mult = Dict(id => prof[shape[lowercase(id)]] ./ (sum(Float64.(ld["p_nom"])) / 1e3)
            for (id, ld) in net["load"])
U = opti_kron_load_injections(m, net, mult)
S = Dict("hull" => () -> OptiKronHull(U), "box" => () -> OptiKronBox(U),
         "ellipsoid" => () -> OptiKronEllipsoid(U))[setname]()

keep = opti_kron_required_buses(net)
res = opti_kron_reduction(m, S, Ebar; optimizer=milp, keep=keep, time_limit=3600)
red = kron_reduce_buses(net, m, res; Ebar=Ebar)
lg = red["_kron_reduction"]
@printf("%s, Ē=%g, keep=%s: %s\n", setname, Ebar, keep, res)
@printf("reduced case: %d → %d buses, %d → %d lines (%d equivalents), %d equivalent shunts, asym %.1e\n",
        length(net["bus"]), length(red["bus"]), length(net["line"]), length(red["line"]),
        length(lg["equivalent_lines"]), length(lg["equivalent_shunts"]), lg["max_symmetrized_asymmetry"])
flush(stdout)

opt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0, "tol" => 1e-9)
function set_loads!(n, s)
    for (id, ld) in n["load"]
        f = mult[id][s]
        ld["p_nom"] = Float64.(net["load"][id]["p_nom"]) .* f
        ld["q_nom"] = Float64.(net["load"][id]["q_nom"]) .* f
    end
end
vm(r, b, t) = abs(complex(r["bus"][b][t]["vr"], r["bus"][b][t]["vi"]))
rows = [(j, t) for (j, t) in m.rows if haskey(lg["super_node_of"], m.buses[j])]
E_lin = opti_kron_errors(m, res.assignment, U)
ac = Float64[]; lin = Float64[]; lifted = Float64[]
for s in 1:stride:size(U, 2)
    nf = deepcopy(net); nr = deepcopy(red)
    set_loads!(nf, s); set_loads!(nr, s)
    pf = solve_pf(nf; optimizer=opt); pr = solve_pf(nr; optimizer=opt)
    ll = lift_solution(net, red, pr; model=m)
    eac = 0.0; elin = 0.0; elift = 0.0
    for (j, t) in rows
        jb = m.buses[j]; ib = m.buses[res.assignment[j]]
        r = m.rowof[(j, t)]; ri = m.rowof[(res.assignment[j], t)]
        vj = vm(pf, jb, t) / m.u0[r]
        eac = max(eac, abs(vm(pr, ib, t) / m.u0[ri] - vj))
        elin = max(elin, abs(E_lin[r, s]))
        elift = max(elift, abs(ll["bus"][jb][t]["vpn_lifted"] / m.u0[r] - vj))
    end
    push!(ac, eac); push!(lin, elin); push!(lifted, elift)
end
@printf("samples checked: %d (every %d min)\n", length(ac), stride)
@printf("max error / Ē — linear model: %.3f   AC: %.3f   AC after linear lift: %.4f\n",
        maximum(lin) / Ebar, maximum(ac) / Ebar, maximum(lifted) / Ebar)
@printf("median   / Ē — linear model: %.3f   AC: %.3f   AC after linear lift: %.4f\n",
        median(lin) / Ebar, median(ac) / Ebar, median(lifted) / Ebar)
@printf("max |AC − linear| / Ē over samples: %.3f\n", maximum(abs.(ac .- lin)) / Ebar)
