"""
    resnap_enwl_benchmark_bounds.jl

One-time regeneration of the voltage bounds on the reduced ENWLbenchmark cases
so they are referenced to the standardised 230 V nominal instead of the 240 V
the cases were originally built around.

The enriched ENWLbenchmark JSONs carry `vpn_*` bounds computed as ±10 % of a
~240.2 V supply nominal (the actual source magnitude), with no `v_declared` to
record the intended nominal. This script, for each `reduced/<stem>.json`:

  1. strips the existing voltage-bound fields (augment never overwrites, so they
     must be removed before regeneration);
  2. runs `augment_case` with voltage snapping enabled (IEC_50Hz preset), which
     snaps the 240.2 V nominal to 230 V, writes `v_declared = 230`, and rebuilds
     `v_min/v_max`, `vpn_*`, `vpp_*`, `vneg_max` against 230;
  3. writes the JSON back in place.

Only the voltage-bound passes run — thermal, generation (the 15 DER generators'
q-limits), inverter, and slack-cost passes are disabled so the rest of the
benchmark is untouched. After this, re-run `generate_enwl_solution_reports.jl`
and `solve_benchmark_opf.jl`; both read these same JSONs and will report/solve
against the 230 V base.

Idempotent: a case already carrying `v_declared` is re-stripped and re-snapped,
so re-running is safe.

Usage:
    julia --project=scripts scripts/oneoff/resnap_enwl_benchmark_bounds.jl
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))   # scripts/Project.toml — BMOPFTools + JuMP + Ipopt + JSON3

using BMOPFTools

const REDUCED_DIR = joinpath(@__DIR__, "..", "..", "output", "ENWLbenchmark", "reduced")

# Voltage-bound fields rebuilt against the snapped nominal. Stripped first so the
# (never-overwriting) augment passes regenerate them.
const BOUND_FIELDS = ("v_min", "v_max", "vpn_min", "vpn_max",
                      "vpp_min", "vpp_max", "vneg_max", "v_declared")

# Snapping config: IEC_50Hz preset, enabled.
function _snap_config()
    cfg = load_config()
    cfg["augment"]["voltage_snap"]["enabled"] = true
    cfg["augment"]["voltage_snap"]["preset"]  = "IEC_50Hz"
    cfg
end

# Bounds-only recipe: leave generators, thermal, inverters, and slack cost alone.
const BOUNDS_ONLY_RECIPE = AugmentationRecipe(;
    apply_thermal         = false,
    apply_q_bounds        = false,
    apply_slack_generator = false,
    apply_inverter        = false,
)

source_files = sort([
    f for f in readdir(REDUCED_DIR; join=true)
    if isfile(f) && endswith(f, ".json") &&
       !occursin("_results", basename(f)) &&
       !occursin("_opf", basename(f))
])

println("Re-snapping voltage bounds to 230 V on $(length(source_files)) " *
        "reduced ENWLbenchmark case(s).\n")

cfg = _snap_config()

let ok = 0, snapped = 0, failed = 0
    for src in source_files
        stem = splitext(basename(src))[1]
        print("  $stem … ")
        try
            net = parse_bmopf(src)
            for (_, bus) in get(net, "bus", Dict())
                bus isa Dict || continue
                for f in BOUND_FIELDS
                    delete!(bus, f)
                end
            end

            net′, mf = augment_case(net; recipe=BOUNDS_ONLY_RECIPE, config=cfg)

            n_snap = count(e -> e.rule == "IEC60038_snap", mf.entries)
            write_bmopf(net′, src)

            println("✓  $(n_snap) bus(es) snapped to v_declared=230")
            ok += 1
            n_snap > 0 && (snapped += 1)
        catch e
            println("✗")
            @error "Failed: $stem" exception=(e, catch_backtrace())
            failed += 1
        end
    end

    println("\nDone: $ok rewritten ($snapped with snaps), $failed failed.")
    println("Re-run generate_enwl_solution_reports.jl and solve_benchmark_opf.jl " *
            "to refresh the reports against 230 V.")
end
