# Reproduce the sequence-voltage bound targets (Cases S1–S3) of
# test/pmd_opf_bounds_tests.jl. See README.md. Not run in CI.
#
# PMD implements the sequence-voltage constraints ONLY for the three-wire ACP
# formulation, and no shipped problem uses them: their template
# (constraint_mc_bus_voltage_balance) is additionally stale in v0.16 (it
# asserts a :conductors ref that no longer exists). The reference is therefore
# ACPUPowerModel on the Kron-reduced model with the constraint FUNCTIONS wired
# in directly by a custom builder. Definitions align with BMOPF: /3-normalised
# Fortescue components, bounds on squared magnitudes, upper-only.
# vm_seq_*_max fields are injected into the MATH buses in per-unit (they are
# not part of PMD's eng2math passthrough). phase_project stays off so
# single-phase DERs keep their phase identity.
#
# Produced with: PowerModelsDistribution v0.16.0 (dev checkout), Ipopt.

include(joinpath(@__DIR__, "common.jl"))

const SEQMAP = Dict("vpos_max" => "vm_seq_pos_max",
                    "vneg_max" => "vm_seq_neg_max",
                    "vzero_max" => "vm_seq_zero_max")

function build_mc_opf_seq(pm)
    PMD.build_mc_opf(pm)
    nw = PMD.nw_id_default
    for (i, bus) in PMD.ref(pm, :bus)
        haskey(bus, "vm_seq_pos_max") &&
            PMD.constraint_mc_bus_voltage_magnitude_positive_sequence(pm, nw, i, bus["vm_seq_pos_max"])
        haskey(bus, "vm_seq_neg_max") &&
            PMD.constraint_mc_bus_voltage_magnitude_negative_sequence(pm, nw, i, bus["vm_seq_neg_max"])
        haskey(bus, "vm_seq_zero_max") &&
            PMD.constraint_mc_bus_voltage_magnitude_zero_sequence(pm, nw, i, bus["vm_seq_zero_max"])
    end
end

"Fortescue components of a 3-phasor vector: (V0, V+, V−), /3-normalised."
function seq_components(vs)
    a = cis(2π / 3)
    ((vs[1] + vs[2] + vs[3]) / 3,
     (vs[1] + a * vs[2] + a^2 * vs[3]) / 3,
     (vs[1] + a^2 * vs[2] + a * vs[3]) / 3)
end

function solve_seq(case::AbstractString, costs; vbase=230.0)
    net = load_fixture(case)
    inject_seq!(math) = for (_, b) in math["bus"]
        name = get(b, "name", "")
        haskey(net["bus"], name) || continue
        for (bk, mk) in SEQMAP
            haskey(net["bus"][name], bk) && (b[mk] = Float64(net["bus"][name][bk]) / vbase)
        end
    end
    _, sol, _ = solve_pmd_en(net; gen_costs=costs, form=PMD.ACPUPowerModel,
                             kron=true, build=build_mc_opf_seq, math_mod! = inject_seq!)
    vs = sol["bus"]["buse"]["vm"] .* cis.(deg2rad.(sol["bus"]["buse"]["va"]))
    v0, vp, vn = seq_components(vs[1:3])
    pmd_dispatch(sol), (v0=abs(v0), vp=abs(vp), vn=abs(vn), vm=abs.(vs[1:3]))
end

for case in ("S1_vpos_max", "S2_vneg_max", "S3_vzero_max")
    costs = gen_costs_from_fixture(load_fixture(case))
    disp, s = solve_seq(case, costs)
    print_targets(case, disp,
                  "|V+| |V−| |V0| (buse)" => round.([s.vp, s.vn, s.v0]; digits=4),
                  "|V_ph|(buse)" => round.(s.vm; digits=4))
    perturbation_check(c -> solve_seq(case, c)[1], costs, ["der_m", "der_e"]; ratio=9.0)
end
