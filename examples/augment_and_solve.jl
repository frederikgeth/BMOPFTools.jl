"""
    augment_and_solve.jl

Demonstrate the full augmentation → OPF → solution-report pipeline on a
pre-reduced LV feeder (LV1_14bus).

Steps:
  1. Load a reduced BMOPF network from output/LV/reduced/
  2. Add dispatchable DER generators to make the OPF non-trivial:
       • two single-phase rooftop PV units co-located with the existing loads
       • one three-phase commercial DER at a mid-feeder bus
  3. Run augment_case to inject voltage bounds, thermal limits, slack cost,
     and reactive capability bounds (EN 50549-1); save the augmented JSON
     and augmentation report
  4. Solve the OPF with Ipopt — the solver trades off cheap DER output
     against expensive slack import to minimize total cost
  5. Profile the solution and render the solution report

Run from the repository root using the test environment (which includes JuMP
and Ipopt):
    julia --project=test examples/augment_and_solve.jl
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", "test"))

using BMOPFTools
using JuMP, Ipopt
using Printf

# ── Paths ─────────────────────────────────────────────────────────────────────

const INPUT_JSON = joinpath(@__DIR__, "..", "output", "LV", "reduced", "LV1_14bus.json")
const OUT_DIR    = joinpath(@__DIR__, "..", "output", "LV", "augmented")

mkpath(OUT_DIR)

stem = splitext(basename(INPUT_JSON))[1]   # "LV1_14bus"

sep(title) = println("\n", "─"^70, "\n  $title\n", "─"^70)

# ── 1. Load ───────────────────────────────────────────────────────────────────

sep("1. Load reduced network")

net = parse_bmopf(INPUT_JSON)
println("Loaded: ", get(net, "name", stem))
println("  buses      : ", length(get(net, "bus",      Dict())))
println("  lines      : ", length(get(net, "line",     Dict())))
println("  loads      : ", length(get(net, "load",     Dict())))
println("  generators : ", length(get(net, "generator", Dict())))

# ── 2. Add DER generators ─────────────────────────────────────────────────────
#
# The base network has two single-phase loads:
#   ld3313_load_a  —  bus b3230, phase 1, 10 kW
#   ld3433_load_b  —  bus b2656, phase 2, 10 kW
#
# We add DERs with NEGATIVE costs to model a dispatch-incentive scheme
# (e.g. feed-in tariff, carbon credit, or ancillary-service payment):
#   der_pv_a  — single-phase rooftop PV at b3230 (phase 1), 6 kW peak
#               Cost: -1.0 $/W·s — highest priority; optimizer maxes this out first
#   der_pv_b  — single-phase rooftop PV at b2656 (phase 2), 6 kW peak
#               Cost: -1.0 $/W·s
#   der_bat   — three-phase dispatchable battery at b514 (mid-feeder), 15 kW
#               Cost: -0.50 $/W·s — lower priority than solar
#
# The OPF minimizes total cost = Σ(cost_k * pg_k). Negative costs make the
# solver maximize DER output subject to voltage and thermal constraints. Any
# shortfall is covered by the grid slack (zero cost); surplus can be exported.
#
# augment_case will:
#   • inject voltage bounds (vpn, vpp, vneg) on all LV buses per EN 50160
#   • infer thermal limits on linecodes from IEC 60228 conductor tables
#   • add q_min/q_max on the DERs from EN 50549-1 (cos φ = 0.90)
#   • NOT price the slack source (apply_slack_generator=false in recipe)

sep("2. Add DER generators")

# Strip any pre-existing source cost so augment_case doesn't see it as already set.
for (_, vs) in get(net, "voltage_source", Dict())
    delete!(vs, "cost")
end

gens = get!(net, "generator", Dict{String,Any}())

gens["der_pv_a"] = Dict{String,Any}(
    "bus"           => "b3230",
    "terminal_map"  => ["1", "n"],
    "configuration" => "SINGLE_PHASE",
    "p_min"         => [0.0],
    "p_max"         => [6_000.0],    # 6 kW single-phase PV
    "cost"          => [-1.0],       # $/W·s reward — highest dispatch priority
)

gens["der_pv_b"] = Dict{String,Any}(
    "bus"           => "b2656",
    "terminal_map"  => ["2", "n"],
    "configuration" => "SINGLE_PHASE",
    "p_min"         => [0.0],
    "p_max"         => [6_000.0],
    "cost"          => [-1.0],
)

gens["der_bat"] = Dict{String,Any}(
    "bus"           => "b514",
    "terminal_map"  => ["1", "2", "3", "n"],
    "configuration" => "WYE",
    "p_min"         => [0.0, 0.0, 0.0],
    "p_max"         => [5_000.0, 5_000.0, 5_000.0],   # 5 kW/phase, 15 kW total
    "cost"          => [-0.50, -0.50, -0.50],           # $/W·s reward — second priority
)

println("  Added 3 DER generator(s) (negative cost = dispatch reward):")
for (gid, g) in sort(collect(gens); by=first)
    p_total = sum(get(g, "p_max", [0.0]))
    println("    $gid  bus=$(g["bus"])  cfg=$(g["configuration"])" *
            "  p_max=$(p_total/1000) kW  cost=$(g["cost"]) \$/W·s")
end

# ── 3. Augment ────────────────────────────────────────────────────────────────
#
# Use a custom recipe that skips the slack-source pricing (we don't need it
# here since the DER incentive structure drives the dispatch directly).

sep("3. Augment case")

recipe  = AugmentationRecipe(; apply_slack_generator=false)
net′, manifest = augment_case(net; recipe=recipe)

println("\nAugmentation manifest:")
render_manifest(manifest)

aug_json = joinpath(OUT_DIR, stem * "_augmented.json")
write_bmopf(net′, aug_json)
println("\nAugmented JSON → ", relpath(aug_json))

aug_report_path = joinpath(OUT_DIR, stem * "_augmented_report.md")
render(analyze(net′), aug_report_path)
println("Augmented report → ", relpath(aug_report_path))

# ── 4. Solve OPF ──────────────────────────────────────────────────────────────
#
# Expected behavior:
#   Both PV units are driven to full output (6 kW each; highest reward -1.0).
#   The battery dispatches up to its per-phase limit (5 kW/phase), but may be
#   curtailed by the EN 50160 voltage-rise constraint on the LV feeder — this
#   is the interesting non-trivial case the OPF resolves. Surplus generation
#   beyond load is exported to the grid via the MV slack source.

sep("4. Solve OPF")

optimizer = optimizer_with_attributes(
    Ipopt.Optimizer,
    "print_level" => 0,
    "max_iter"    => 500,
)

result = solve_opf(net′; optimizer=optimizer, per_unit=true)

status = result["termination_status"]
println("Status    : ", status)
if status in ("LOCALLY_SOLVED", "OPTIMAL")
    @printf("Objective : %.6g (cost units)\n", result["objective"])
    @printf("Solve time: %.2f s\n", result["solve_time"])

    println("\nDER dispatch:")
    for (gid, g_res) in sort(collect(result["generator"]); by=first)
        pg_total = sum(v["pg"] for v in values(g_res))
        qg_total = sum(v["qg"] for v in values(g_res))
        @printf("  %-12s  P = %+7.2f kW   Q = %+7.2f kvar\n",
                gid, pg_total/1000, qg_total/1000)
    end

    println("\nGrid slack (voltage source):")
    for (vid, v_res) in result["voltage_source"]
        ps_total = sum(v["ps"] for v in values(v_res))
        qs_total = sum(v["qs"] for v in values(v_res))
        @printf("  %-12s  P = %+7.2f kW   Q = %+7.2f kvar\n",
                vid, ps_total/1000, qs_total/1000)
    end
else
    println("Solver did not find a feasible point — check augmentation bounds.")
end

# ── 5. Solution report ────────────────────────────────────────────────────────

sep("5. Solution report")

sol_report = profile_solution(net′, result)
sol_path   = joinpath(OUT_DIR, stem * "_solution.md")
render_solution(sol_report, sol_path)
println("Solution report → ", relpath(sol_path))

render_solution(sol_report, stdout)
