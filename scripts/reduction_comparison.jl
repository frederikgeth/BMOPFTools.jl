# Compare network-reduction strategies on real feeders.
#
#   julia --project=<env with Gurobi + Ipopt> --startup-file=no \
#         scripts/reduction_comparison.jl [cases=eulv,harrow80,hackham250] [Ebar=1e-3]
#
# Strategies (all compared against AC power flow on the ORIGINAL network):
#   original        — the case as given
#   simplify        — simplify_network (closed switches, stubs, degree-2 series merging)
#   neutral         — kron_reduce_neutrals (explicit neutrals → implicit ideal ground)
#   opti_kron       — robust Opti-KRON (convex hull of the training samples, Ē),
#                     keeping transformer/source buses, then kron_reduce_buses
#   neutral+opti    — kron_reduce_neutrals, then Opti-KRON on the 3-wire case
#   simplify+opti   — simplify_network, then Opti-KRON (certificate covers the
#                     buses simplify keeps; merged pass-through buses are gone)
#
# Error metric: max over test samples of |v_est − v_true| / U0 at every original
# (bus, phase) the strategy can estimate, v = phase-to-neutral magnitude (phase-
# to-earth where the neutral is earthed or reduced away). Eliminated buses are
# read off their super-node (Opti-KRON's certified estimator) and, for the
# bus reductions, also via lift_solution(method=:linear). Buses removed by
# simplify are not estimated (reported as coverage).

using BMOPFTools, JuMP, Ipopt, Gurobi, Random, Statistics, Printf

const GRB = Gurobi.Env()
milp() = Gurobi.Optimizer(GRB)
ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0, "tol" => 1e-9)

cases = length(ARGS) ≥ 1 ? split(ARGS[1], ",") : ["eulv", "harrow80", "hackham250"]
Ebar = length(ARGS) ≥ 2 ? parse(Float64, ARGS[2]) : 1e-3
SAPN = joinpath(homedir(), "Documents/GitHub/BMOPFDraftData/output/SAPN")
EULV = joinpath(homedir(), "Documents/GitHub/DistributionTestCases.jl/src/data/lvtestcase")

# ── cases: (net, training multipliers, test multipliers) ────────────────────
function eulv_case()
    full = from_dss(joinpath(EULV, "snapshots/lvtestcase_pmd_t1000.dss"))
    full isa Tuple && (full = first(full))
    net = extract_downstream_network(full, "sourcebus")
    shape = Dict{String,Int}()
    for ln in eachline(joinpath(EULV, "lvtestcase_pmd_template.dss"))
        mm = match(r"^New Load\.(\S+) .*Yearly=Shape_(\d+)", ln)
        mm === nothing || (shape[lowercase(mm[1])] = parse(Int, mm[2]))
    end
    prof = Dict(k => parse.(Float64, strip.(readlines(joinpath(EULV, "profiles/load_profile_$k.txt"))))
                for k in unique(values(shape)))
    mult = Dict(id => prof[shape[lowercase(id)]] ./ (sum(Float64.(ld["p_nom"])) / 1e3)
                for (id, ld) in net["load"])
    train = mult                                            # all 1,440 minutes
    test = Dict(id => v[15:30:end] for (id, v) in mult)     # 48 half-hour points
    net, train, test
end

function sapn_case(file, target)
    net0 = parse_bmopf(joinpath(SAPN, file))
    cnt = downstream_bus_counts(net0)
    roots = String[]
    for (_, sub) in net0["transformer"], (_, t) in sub
        t isa AbstractDict && haskey(t, "bus_from") && push!(roots, t["bus_from"])
    end
    sort!(unique!(roots); by=r -> (abs(cnt[r] - target), r))
    net = extract_downstream_network(net0, roots[1])
    ids = sort(collect(keys(net["load"])))
    gen(N, seed) = (rng = MersenneTwister(seed); lvl = [0.3 + 0.7rand(rng) for _ in 1:N];
                    Dict(id => [lvl[s] * exp(0.3randn(rng)) for s in 1:N] for id in ids))
    net, gen(29, 1), gen(12, 2)
end

getcase(name) = name == "eulv" ? eulv_case() :
                name == "harrow80" ? sapn_case("harrow.bmopf.json", 80) :
                name == "hackham250" ? sapn_case("hackham.bmopf.json", 250) :
                error("unknown case $name")

# ── helpers ─────────────────────────────────────────────────────────────────
function set_loads!(n, base, mult, s)
    for (id, ld) in n["load"]
        haskey(mult, id) || continue
        ld["p_nom"] = Float64.(base["load"][id]["p_nom"]) .* mult[id][s]
        ld["q_nom"] = Float64.(base["load"][id]["q_nom"]) .* mult[id][s]
    end
end
nsamples(mult) = length(first(values(mult)))

# phase-to-neutral (or -earth) magnitude of (bus, phase) in a PF result
function vmag(net, res, b, t)
    rb = get(res["bus"], b, nothing)
    (rb === nothing || !haskey(rb, t)) && return nothing
    U = complex(rb[t]["vr"], rb[t]["vi"])
    _, nt = BMOPFTools._ok_phase_terminals(net, net["bus"][b])
    if nt !== nothing && haskey(rb, nt)
        U -= complex(rb[nt]["vr"], rb[nt]["vi"])
    end
    abs(U)
end

function opti(net, train)
    m = opti_kron_model(net; H=5)
    U = opti_kron_load_injections(m, net, train)
    res = opti_kron_reduction(m, OptiKronHull(U), Ebar; optimizer=milp,
                              keep=opti_kron_required_buses(net), time_limit=1800,
                              master_time_limit=900)
    m, res, kron_reduce_buses(net, m, res; Ebar=Ebar)
end

ybus_nodes(n) = size(ybus_passive(n).Y, 1)

# ── main ────────────────────────────────────────────────────────────────────
for name in cases
    net, train, test = getcase(name)
    m0 = opti_kron_model(net; H=1)              # rows + no-load bases of the original
    println("\n## ", name, ": ", length(net["bus"]), " buses, ", length(net["load"]), " loads, ",
            nsamples(test), " test samples, Ē = ", Ebar)
    flush(stdout)

    strategies = Pair{String,Any}[]
    t = @elapsed s = simplify_network(net)
    push!(strategies, "simplify" => (net=s, prep=t, superof=Dict{String,String}(), m=nothing))
    t = @elapsed nk = kron_reduce_neutrals(net)
    push!(strategies, "neutral" => (net=nk, prep=t, superof=Dict{String,String}(), m=nothing))
    t = @elapsed (mo, ro, ok) = opti(net, train)
    push!(strategies, "opti_kron" => (net=ok, prep=t, superof=ok["_kron_reduction"]["super_node_of"],
                                      m=mo, res=ro))
    t = @elapsed begin
        nk2 = kron_reduce_neutrals(net)
        (mn, rn, okn) = opti(nk2, train)
    end
    push!(strategies, "neutral+opti" => (net=okn, prep=t, superof=okn["_kron_reduction"]["super_node_of"],
                                         m=mn, res=rn, base=nk2))
    t = @elapsed begin
        sp = simplify_network(net)
        (ms_, rs_, oks) = opti(sp, Dict(id => v for (id, v) in train if haskey(sp["load"], id)))
    end
    push!(strategies, "simplify+opti" => (net=oks, prep=t, superof=oks["_kron_reduction"]["super_node_of"],
                                          m=ms_, res=rs_, base=sp))

    # ground truth: AC PF on the original
    truth = Dict{Int,Any}(); ttrue = Float64[]
    for s in 1:nsamples(test)
        n = deepcopy(net); set_loads!(n, net, test, s)
        push!(ttrue, @elapsed truth[s] = solve_pf(n; optimizer=ipopt))
    end

    @printf("| strategy | buses | lines | Ybus nodes | prep (s) | PF (s, median) | coverage | max err/Ē | max err/Ē (lifted) |\n")
    @printf("|---|---|---|---|---|---|---|---|---|\n")
    @printf("| original | %d | %d | %d | – | %.2f | 100%% | 0 | – |\n", length(net["bus"]),
            length(net["line"]), ybus_nodes(net), median(ttrue))
    for (sname, st) in strategies
        rn = st.net
        errs = 0.0; errl = 0.0; covered = 0; total = 0; tpf = Float64[]
        for s in 1:nsamples(test)
            n = deepcopy(rn); set_loads!(n, net, test, s)
            local pr
            push!(tpf, @elapsed pr = solve_pf(n; optimizer=ipopt))
            lifted = st.m === nothing ? nothing :
                     lift_solution(get(st, :base, net), rn, pr; model=st.m)
            for (r, (j, ph)) in enumerate(m0.rows)
                b = m0.buses[j]
                vt = vmag(net, truth[s], b, ph)
                vt === nothing && continue
                s == 1 && (total += 1)
                est = get(st.superof, b, b)
                ve = vmag(rn, pr, est, ph)
                ve === nothing && continue
                s == 1 && (covered += 1)
                errs = max(errs, abs(ve - vt) / m0.u0[r])
                if lifted !== nothing
                    d = get(get(lifted["bus"], b, Dict()), ph, Dict())
                    haskey(d, "vpn_lifted") && (errl = max(errl, abs(d["vpn_lifted"] - vt) / m0.u0[r]))
                end
            end
        end
        @printf("| %s | %d | %d | %d | %.1f | %.2f | %.0f%% | %.3f | %s |\n", sname, length(rn["bus"]),
                length(rn["line"]), ybus_nodes(rn), st.prep, median(tpf), 100covered / total,
                errs / Ebar, st.m === nothing ? "–" : @sprintf("%.3f", errl / Ebar))
        flush(stdout)
    end
    for (sname, st) in strategies
        st.m === nothing && continue
        @printf("  %s: %s\n", sname, st.res)
    end
end
