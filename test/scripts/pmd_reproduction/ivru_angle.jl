# Reproduce the branch angle-difference target (Case D1) of
# test/pmd_opf_bounds_tests.jl. See README.md. Not run in CI.
#
# PMD's explicit-neutral models implement no angle-difference constraint, so
# the reference is the THREE-WIRE IVRUPowerModel (stock build calls
# constraint_mc_voltage_angle_difference; math branch angmin/angmax), solved on
# the Kron-reduced model — the fully grounded fixture makes the two models
# coincide. BMOPF's per-line va_diff_min/max (radians) travel to PMD as eng
# vad_lb/ub (degrees) via the "_pmd" passthrough.
#
# Produced with: PowerModelsDistribution v0.16.0 (dev checkout), Ipopt.

include(joinpath(@__DIR__, "common.jl"))

let
    costs0 = gen_costs_from_fixture(load_fixture("D1_va_diff"))
    function solve_d1(costs)
        net = load_fixture("D1_va_diff")
        _, sol, _ = solve_pmd_en(net; gen_costs=costs, form=PMD.IVRUPowerModel, kron=true)
        pmd_dispatch(sol), sol
    end
    disp, sol = solve_d1(costs0)
    vth(b) = sol["bus"][b]["vr"] .+ im .* sol["bus"][b]["vi"]
    dth(b1, b2) = [rad2deg(angle(vth(b1)[k] / vth(b2)[k])) for k in 1:3]
    print_targets("D1_va_diff", disp,
                  "Δθ(source→busm) deg" => round.(dth("sourcebus", "busm"); digits=4),
                  "Δθ(busm→buse) deg (unbounded)" => round.(dth("busm", "buse"); digits=4))
    perturbation_check(c -> solve_d1(c)[1], costs0, ["der_m", "der_e"]; ratio=9.0)
end
