# Reproduce the explicit-neutral (IVREN) bound-binding targets of
# test/pmd_opf_bounds_tests.jl. See README.md. Not run in CI.
#
# Produced with: PowerModelsDistribution v0.16.0 (dev checkout), Ipopt via JuMP.

include(joinpath(@__DIR__, "common.jl"))

# ─────────────────────────────────────────────────────────────────────────────
# Pipeline check — Case A (locked in the testset): the helpers must reproduce
# Σpg = 11.7642 kW with the load bus pinned at v_max = 235 V before any new
# case is trusted.
# ─────────────────────────────────────────────────────────────────────────────
let
    net = load_fixture("A_vmax")
    res, sol, _ = solve_pmd_en(net; gen_costs=gen_costs_from_fixture(net))
    disp = pmd_dispatch(sol)
    vm = pmd_vm(sol, "loadbus")
    ok = isapprox(disp["der"].pg, 11.7642; atol=1e-3) &&
         all(isapprox.(vm[1:3], 235.0; atol=1e-2))
    println("pipeline check (Case A): ", ok ? "OK" : "FAILED",
            "  Σpg = ", round(disp["der"].pg; digits=4), " kW, |V| = ",
            round.(vm[1:3]; digits=3))
    ok || error("pipeline check failed — do not derive new targets with these helpers")
end

# ─────────────────────────────────────────────────────────────────────────────
# Case G1 — vpn_max binds (four-wire, two DERs). See the testset provenance
# comment. PMD converges to the BMOPF optimum from a FLAT start; the two
# cost-ratio perturbations must move the dispatch split (non-degeneracy gate).
# ─────────────────────────────────────────────────────────────────────────────
let
    costs0 = gen_costs_from_fixture(load_fixture("G1_vpn_max"))
    function solve_g1(costs)
        net = load_fixture("G1_vpn_max")
        _, sol, _ = solve_pmd_en(net; gen_costs=costs)
        pmd_dispatch(sol), sol
    end
    disp, sol = solve_g1(costs0)
    vpn = [abs((sol["bus"]["buse"]["vr"][k] + im * sol["bus"]["buse"]["vi"][k]) -
               (sol["bus"]["buse"]["vr"][4] + im * sol["bus"]["buse"]["vi"][4])) for k in 1:3]
    print_targets("G1_vpn_max", disp,
                  "|V_pn|(buse)" => round.(vpn; digits=4),
                  "|V_n|(buse)" => round(abs(sol["bus"]["buse"]["vr"][4] +
                                             im * sol["bus"]["buse"]["vi"][4]); digits=4))
    perturbation_check(c -> solve_g1(c)[1], costs0, ["der_m", "der_e"]; ratio=9.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Case G2 — vpn_min binds (four-wire, two DERs, cost-minimised support).
# Flat start; the der_e ×9 perturbation must flip the dispatch order.
# ─────────────────────────────────────────────────────────────────────────────
let
    costs0 = gen_costs_from_fixture(load_fixture("G2_vpn_min"))
    function solve_g2(costs)
        net = load_fixture("G2_vpn_min")
        _, sol, _ = solve_pmd_en(net; gen_costs=costs)
        pmd_dispatch(sol), sol
    end
    disp, sol = solve_g2(costs0)
    v = sol["bus"]["buse"]["vr"] .+ im .* sol["bus"]["buse"]["vi"]
    print_targets("G2_vpn_min", disp,
                  "|V_pn|(buse)" => round.([abs(v[k] - v[4]) for k in 1:3]; digits=4),
                  "|V_n|(buse)" => round(abs(v[4]); digits=4),
                  "der_m per-ph pg (kW)" => round.(sol["generator"]["der_m"]["pg"] ./ 1000; digits=4))
    perturbation_check(c -> solve_g2(c)[1], costs0, ["der_m", "der_e"]; ratio=9.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Case F — vn_max binds (four-wire, two single-phase DERs on different phases
# sharing the |Vₙ| ≤ 6 V disc budget). Flat start; both ×9 cost perturbations
# must slide the split along the disc boundary.
# ─────────────────────────────────────────────────────────────────────────────
let
    costs0 = gen_costs_from_fixture(load_fixture("F_vn_max"))
    function solve_f(costs)
        net = load_fixture("F_vn_max")
        _, sol, _ = solve_pmd_en(net; gen_costs=costs)
        pmd_dispatch(sol), sol
    end
    disp, sol = solve_f(costs0)
    v = sol["bus"]["buse"]["vr"] .+ im .* sol["bus"]["buse"]["vi"]
    vm_busm_n = abs(sol["bus"]["busm"]["vr"][4] + im * sol["bus"]["busm"]["vi"][4])
    print_targets("F_vn_max", disp,
                  "|V_n|(buse)" => round(abs(v[4]); digits=4),
                  "|V_n|(busm)" => round(vm_busm_n; digits=4),
                  "|V_pg|(buse)" => round.(abs.(v[1:3]); digits=4))
    perturbation_check(c -> solve_f(c)[1], costs0, ["der_m", "der_e"]; ratio=9.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Case H1 — vpp_max binds (three-wire grounded, pair (1,2) at the cap).
# Flat start; the der_e ×9 perturbation must pull der_m off its box.
# ─────────────────────────────────────────────────────────────────────────────
let
    costs0 = gen_costs_from_fixture(load_fixture("H1_vpp_max"))
    function solve_h1(costs)
        net = load_fixture("H1_vpp_max")
        _, sol, _ = solve_pmd_en(net; gen_costs=costs)
        pmd_dispatch(sol), sol
    end
    disp, sol = solve_h1(costs0)
    v = sol["bus"]["buse"]["vr"] .+ im .* sol["bus"]["buse"]["vi"]
    vm = sol["bus"]["busm"]["vr"] .+ im .* sol["bus"]["busm"]["vi"]
    print_targets("H1_vpp_max", disp,
                  "|V_pp|(buse)" => round.([abs(v[1]-v[2]), abs(v[1]-v[3]), abs(v[2]-v[3])]; digits=4),
                  "|V_pg|(buse)" => round.(abs.(v[1:3]); digits=4),
                  "|V_pp|(busm) (unbounded)" => round.([abs(vm[1]-vm[2]), abs(vm[1]-vm[3]), abs(vm[2]-vm[3])]; digits=4))
    perturbation_check(c -> solve_h1(c)[1], costs0, ["der_m", "der_e"]; ratio=9.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Case H2 — vpp_min binds (three-wire grounded, non-uniform per-pair floors
# [395, 375, 375] V travelling to PMD as explicit vm_pair_lb tuples).
# Flat start; the der_e ×9 perturbation must flip the dispatch order.
# ─────────────────────────────────────────────────────────────────────────────
let
    costs0 = gen_costs_from_fixture(load_fixture("H2_vpp_min"))
    function solve_h2(costs)
        net = load_fixture("H2_vpp_min")
        _, sol, _ = solve_pmd_en(net; gen_costs=costs)
        pmd_dispatch(sol), sol
    end
    disp, sol = solve_h2(costs0)
    v = sol["bus"]["buse"]["vr"] .+ im .* sol["bus"]["buse"]["vi"]
    print_targets("H2_vpp_min", disp,
                  "|V_pp|(buse)" => round.([abs(v[1]-v[2]), abs(v[1]-v[3]), abs(v[2]-v[3])]; digits=4),
                  "|V_pg|(buse)" => round.(abs.(v[1:3]); digits=4),
                  "der_e per-ph pg (kW)" => round.(sol["generator"]["der_e"]["pg"] ./ 1000; digits=4),
                  "der_m per-ph pg (kW)" => round.(sol["generator"]["der_m"]["pg"] ./ 1000; digits=4))
    perturbation_check(c -> solve_h2(c)[1], costs0, ["der_m", "der_e"]; ratio=9.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Case W1 — line i_max with a from-side-only shunt binds. The rating and the
# shunt live on the linecode (to_pmd exports linecode i_max → cm_ub; the
# helper converts BMOPF's siemens shunts to PMD's nF-style eng fields).
# Flat start; the der_e ×9 perturbation must flip the order completely.
# ─────────────────────────────────────────────────────────────────────────────
let
    costs0 = gen_costs_from_fixture(load_fixture("W1_imax_shunt"))
    function solve_w1(costs)
        net = load_fixture("W1_imax_shunt")
        _, sol, _ = solve_pmd_en(net; gen_costs=costs)
        pmd_dispatch(sol), sol
    end
    disp, sol = solve_w1(costs0)
    l1 = sol["line"]["l1"]
    print_targets("W1_imax_shunt", disp,
                  "|I_fr|(l1)" => round.(abs.(l1["cr_fr"] .+ im .* l1["ci_fr"]); digits=4),
                  "|I_to|(l1)" => round.(abs.(l1["cr_to"] .+ im .* l1["ci_to"]); digits=4),
                  "|V_pg|(buse)" => round.(abs.(sol["bus"]["buse"]["vr"] .+
                                                im .* sol["bus"]["buse"]["vi"])[1:3]; digits=4))
    perturbation_check(c -> solve_w1(c)[1], costs0, ["der_m", "der_e"]; ratio=9.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Case X1 — transformer s_rating binds. PMD ships the transformer thermal
# limit commented out of its EN build, so a custom builder restores it; the
# helper mirrors BMOPF's always-enforced s_rating into eng sm_ub. Flat start.
# The der_m ×9 perturbation must win phase 1's headroom back from der_e.
# ─────────────────────────────────────────────────────────────────────────────
function build_mc_opf_xfmr_thermal(pm)
    PMD.build_mc_opf(pm)
    for i in PMD.ids(pm, :transformer)
        PMD.constraint_mc_transformer_thermal_limit(pm, i)
    end
end
let
    costs0 = gen_costs_from_fixture(load_fixture("X1_srating"))
    function solve_x1(costs)
        net = load_fixture("X1_srating")
        _, sol, _ = solve_pmd_en(net; gen_costs=costs, build=build_mc_opf_xfmr_thermal)
        pmd_dispatch(sol), sol
    end
    disp, sol = solve_x1(costs0)
    v = sol["bus"]["buse"]["vr"] .+ im .* sol["bus"]["buse"]["vi"]
    print_targets("X1_srating", disp,
                  "der_m per-ph pg (kW)" => round.(sol["generator"]["der_m"]["pg"] ./ 1000; digits=4),
                  "|V_pg|(buse)" => round.(abs.(v[1:3]); digits=4))
    perturbation_check(c -> solve_x1(c)[1], costs0, ["der_m", "der_e"]; ratio=9.0)
end
