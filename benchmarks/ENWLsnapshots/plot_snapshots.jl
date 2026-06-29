"""
    plot_snapshots.jl

Companion to `run_snapshots.jl`. Reads the saved per-unit results
(`*_result_pu.json`) for each ENWL feeder folder and renders time-series
visualisations of the smart-inverter (AS/NZS 4777.2) volt-var / volt-watt
behaviour over the day. (Results are reported in SI units regardless of the solve
mode, so the figures are in SI; the PU solve is just the source.) No re-solve — it
only consumes artifacts already on disk.

For each feeder folder it writes three PNGs into the folder:

    <folder>_pu_curves.png    operating points on the volt-var & volt-watt curves,
                              coloured by time-of-day (which regimes activate)
    <folder>_pu_daily.png     daily aggregate profiles: ΣP & ΣP_avail, ΣQ, and the
                              IBR voltage band vs time-of-day
    <folder>_pu_heatmap.png   per-IBR Q/S_max and voltage heatmaps over the 25 steps

and a gallery `benchmarks/ENWLsnapshots/figures.md` linking them all.

Usage:
    julia --project=scripts benchmarks/ENWLsnapshots/plot_snapshots.jl
    julia --project=scripts benchmarks/ENWLsnapshots/plot_snapshots.jl 30bus_LG 99bus_LN

With no args every feeder folder is processed; otherwise only the named ones.
"""

using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..", "..", "scripts")))

using BMOPFTools
using Plots
using ColorSchemes
using Printf
using Statistics

gr()
default(; fontfamily="sans-serif", framestyle=:box, grid=true, legend=:best)

const SNAP_DIR    = @__DIR__
const GALLERY_MD  = joinpath(SNAP_DIR, "figures.md")
const HOUR_LIMS   = (8.0, 20.0)   # colorbar range for time-of-day
const MODE        = "pu"          # which solve to plot: "pu" or "si"
const MODE_LABEL  = uppercase(MODE)

# ── Folder / case discovery ───────────────────────────────────────────────────

function discover_folders(filter_names)
    folders = sort([d for d in readdir(SNAP_DIR; join=true) if isdir(d)])
    isempty(filter_names) && return folders
    keep = Set(filter_names)
    [d for d in folders if basename(d) in keep]
end

discover_inputs(dir) = sort([
    f for f in readdir(dir; join=true)
    if isfile(f) && endswith(f, ".bmopf.json")
])

case_stem(path) = replace(basename(path), r"\.bmopf\.json$" => "")

# `…_t12_1330` → 13.5 (hour-of-day as a Float). Falls back to the step index.
function hour_of_day(stem, fallback)
    m = match(r"_t\d+_(\d{2})(\d{2})$", stem)
    m === nothing && return Float64(fallback)
    parse(Int, m.captures[1]) + parse(Int, m.captures[2]) / 60
end

# ── Per-IBR sample extraction ─────────────────────────────────────────────────

# One operating point for an IBR phase at one timestep.
struct Sample
    ibr   ::String
    tstep ::Int
    hour  ::Float64
    U     ::Float64   # monitored voltage [V] (PG or PN per profile)
    pg    ::Float64   # [W]
    qg    ::Float64   # [var]
    pmax  ::Float64   # available active power proxy [W]
    smax  ::Float64   # [VA]
end

# Monitored voltage for a SINGLE_PHASE IBR per its profile voltage_reference.
function _monitor_U(t_res, t_ph, t_n, quantity::Symbol)
    g(t, k) = get(get(t_res, t, Dict()), k, NaN)
    if quantity == :PN && t_n !== nothing
        return sqrt((g(t_ph, "vr") - g(t_n, "vr"))^2 + (g(t_ph, "vi") - g(t_n, "vi"))^2)
    end
    g(t_ph, "vm")   # PG (and PN fallback when no neutral)
end

# Gather all samples for a folder, plus the shared control_profile dict and the
# voltage-reference quantity. Reads each snapshot's input + SI result.
function gather_folder(dir)
    inputs = discover_inputs(dir)
    samples = Sample[]
    profile = nothing
    quantity = :PG
    for (ti, src) in enumerate(inputs)
        stem = case_stem(src)
        rj   = joinpath(dir, stem * "_result_$(MODE).json")
        isfile(rj) || continue
        net  = parse_bmopf(src)
        res  = read_result(rj)
        hr   = hour_of_day(stem, ti)
        profiles = get(net, "control_profile", Dict())
        bus_res  = get(res, "bus", Dict())
        ibr_res  = get(res, "ibr", Dict())
        for (id, inv) in get(net, "ibr", Dict())
            inv isa Dict || continue
            get(inv, "topology", "") == "SINGLE_PHASE" || (@warn "skip non-SINGLE_PHASE IBR $id"; continue)
            tm = Vector{String}(get(inv, "terminal_map", String[]))
            length(tm) >= 1 || continue
            t_ph = tm[1]; t_n = length(tm) >= 2 ? tm[2] : nothing
            bus  = get(inv, "bus", "")
            smax = (s = get(inv, "s_max", Float64[]); !isempty(s) ? Float64(s[1]) : NaN)
            pmax = (p = get(inv, "p_max", Float64[]);
                    p isa AbstractVector ? (isempty(p) ? NaN : Float64(p[1])) : Float64(p))
            ph = get(get(ibr_res, id, Dict()), t_ph, nothing)
            ph isa Dict || continue
            pg = Float64(get(ph, "pg", NaN)); qg = Float64(get(ph, "qg", NaN))

            # Resolve the profile + monitored quantity once (shared by all IBRs).
            if profile === nothing
                cp = get(profiles, get(inv, "control_profile", ""), nothing)
                if cp isa Dict
                    profile = cp
                    vw = get(cp, "volt_watt", get(cp, "volt_var", Dict()))
                    vref = uppercase(String(get(vw, "voltage_reference", "PG_PER_PHASE")))
                    quantity = startswith(vref, "PN") ? :PN : startswith(vref, "PP") ? :PP : :PG
                end
            end
            U = _monitor_U(get(bus_res, bus, Dict()), t_ph, t_n, quantity)
            (isfinite(U) && isfinite(pg) && isfinite(qg) && isfinite(smax) && smax > 0) || continue
            push!(samples, Sample(id, ti, hr, U, pg, qg, pmax, smax))
        end
    end
    return samples, profile, quantity, length(inputs)
end

# ── Curve geometry from the control_profile dict ──────────────────────────────

# Flat-clamp endpoints that lie strictly OUTSIDE the breakpoints, so the curve's
# `xs` stays strictly increasing (no backward "wrap" segment) and the flat tails
# render past the extreme breakpoints regardless of the data range. `xlims` is the
# data span; the curve extends to whichever is wider, plus a margin.
_clamp_ends(xlims, bps; m=3.0) = (min(xlims[1], minimum(bps)) - m,
                                  max(xlims[2], maximum(bps)) + m)

# volt-var PWL: (V1,+q_inj),(V2,0),(V3,0),(V4,−q_abs) with flats outside.
function volt_var_curve(profile, xlims)
    vv = get(profile, "volt_var", nothing)
    vv isa Dict || return nothing
    bps = Float64.(get(vv, "breakpoints", Float64[]))
    ql  = Float64.(get(vv, "q_limits", Float64[]))
    (length(bps) == 4 && length(ql) == 2) || return nothing
    q_absorb, q_inject = ql[1], ql[2]            # [absorb (≤0), inject (≥0)]
    lo, hi = _clamp_ends(xlims, bps)
    xs = [lo, bps[1], bps[2], bps[3], bps[4], hi]
    ys = [q_inject, q_inject, 0.0, 0.0, q_absorb, q_absorb]
    @assert issorted(xs) "volt-var curve x values must be strictly increasing"
    (xs, ys, bps)
end

# volt-watt PWL: (V5,p_high),(V6,p_low) with flats outside.
function volt_watt_curve(profile, xlims)
    vw = get(profile, "volt_watt", nothing)
    vw isa Dict || return nothing
    bps = Float64.(get(vw, "breakpoints", Float64[]))
    pl  = Float64.(get(vw, "p_limits", Float64[]))
    (length(bps) == 2 && length(pl) == 2) || return nothing
    p_low, p_high = pl[1], pl[2]
    lo, hi = _clamp_ends(xlims, bps)
    xs = [lo, bps[1], bps[2], hi]
    ys = [p_high, p_high, p_low, p_low]
    @assert issorted(xs) "volt-watt curve x values must be strictly increasing"
    (xs, ys, bps)
end

# ── Figure 1: operating points on the control curves ──────────────────────────

function fig_curves(samples, profile, quantity, folder, out)
    Us = [s.U for s in samples]
    xlo = floor(minimum(Us) - 2); xhi = ceil(maximum(Us) + 2)
    hrs = [s.hour for s in samples]
    qlabel = quantity == :PN ? "phase-to-neutral" : "phase-to-ground"

    vv = volt_var_curve(profile, (xlo, xhi))
    vw = volt_watt_curve(profile, (xlo, xhi))

    p1 = scatter([s.U for s in samples], [s.qg / s.smax for s in samples];
        marker_z=hrs, clims=HOUR_LIMS, c=:viridis, ms=3, msw=0, alpha=0.6,
        colorbar_title="hour of day", label="",
        xlabel="$qlabel voltage  U [V]", ylabel="Q / S_max  [pu]",
        title="Volt-var: operating points")
    if vv !== nothing
        plot!(p1, vv[1], vv[2]; c=:black, lw=2, label="AS/NZS 4777.2 curve")
        vline!(p1, vv[3]; c=:gray, ls=:dash, label="")
    end
    hline!(p1, [0.0]; c=:gray, ls=:dot, label="")

    p2 = scatter([s.U for s in samples], [s.pg / s.smax for s in samples];
        marker_z=hrs, clims=HOUR_LIMS, c=:viridis, ms=3, msw=0, alpha=0.6,
        colorbar_title="hour of day", label="",
        xlabel="$qlabel voltage  U [V]", ylabel="P / S_max  [pu]",
        title="Volt-watt: operating points")
    if vw !== nothing
        plot!(p2, vw[1], vw[2]; c=:black, lw=2, label="volt-watt cap")
        vline!(p2, vw[3]; c=:gray, ls=:dash, label="")
    end

    plt = plot(p1, p2; layout=(1, 2), size=(1100, 470),
               plot_title="$folder — smart-inverter regime activation ($MODE_LABEL)")
    savefig(plt, out)
end

# ── Figure 2: daily aggregate profiles ────────────────────────────────────────

function fig_daily(samples, profile, quantity, folder, out)
    tsteps = sort(unique(s.tstep for s in samples))
    hour_of(t) = first(s.hour for s in samples if s.tstep == t)
    hrs = [hour_of(t) for t in tsteps]
    agg(f) = [f(filter(s -> s.tstep == t, samples)) for t in tsteps]

    sum_pg   = agg(ss -> sum(s.pg for s in ss) / 1e3)               # kW
    sum_pav  = agg(ss -> sum(s.pmax for s in ss) / 1e3)            # kW
    sum_qg   = agg(ss -> sum(s.qg for s in ss) / 1e3)             # kVAr
    vmin     = agg(ss -> minimum(s.U for s in ss))
    vmean    = agg(ss -> mean(s.U for s in ss))
    vmax     = agg(ss -> maximum(s.U for s in ss))

    p1 = plot(hrs, sum_pg; lw=2, marker=:circle, ms=3, label="Σ P dispatched",
              ylabel="active power [kW]", title="Fleet active power", c=:darkorange)
    plot!(p1, hrs, sum_pav; lw=2, ls=:dash, marker=:utriangle, ms=3,
          label="Σ P available (p_max)", c=:seagreen)

    p2 = plot(hrs, sum_qg; lw=2, marker=:circle, ms=3, label="Σ Q (− = absorbing)",
              ylabel="reactive power [kVAr]", title="Fleet volt-var response", c=:purple)
    hline!(p2, [0.0]; c=:gray, ls=:dot, label="")

    # The voltage band is the *monitored* voltage that drives the droops — the same
    # quantity as the curve plots' x-axis (phase-to-neutral for LN, phase-to-ground
    # for LG). Mark the volt-var breakpoints (deadband edge V2, absorb onset V3,
    # max-absorb V4) and the volt-watt curtailment onset (V5) so the band can be
    # read against the regimes.
    qlabel = quantity == :PN ? "phase-to-neutral" : "phase-to-ground"
    p3 = plot(hrs, vmean; ribbon=(vmean .- vmin, vmax .- vmean), lw=2, marker=:circle,
              ms=3, label="mean (band = min–max)", c=:steelblue, xlabel="hour of day",
              ylabel="$qlabel voltage [V]", title="IBR monitored terminal voltage")
    vv = get(profile, "volt_var", nothing)
    if vv isa Dict && length(get(vv, "breakpoints", [])) == 4
        bps = Float64.(vv["breakpoints"])
        hline!(p3, [bps[2]]; c=:teal,   ls=:dot,  label="volt-var deadband (V2, $(Int(bps[2])) V)")
        hline!(p3, [bps[3]]; c=:green,  ls=:dash, label="volt-var absorb onset (V3, $(Int(bps[3])) V)")
        hline!(p3, [bps[4]]; c=:purple, ls=:dash, label="volt-var max absorb (V4, $(Int(bps[4])) V)")
    end
    vw = get(profile, "volt_watt", nothing)
    if vw isa Dict && length(get(vw, "breakpoints", [])) == 2
        hline!(p3, [Float64(vw["breakpoints"][1])]; c=:darkorange, ls=:dash,
               label="volt-watt onset (V5, $(Int(vw["breakpoints"][1])) V)")
    end

    plt = plot(p1, p2, p3; layout=(3, 1), size=(900, 950), link=:x,
               plot_title="$folder — daily aggregate ($MODE_LABEL)")
    savefig(plt, out)
end

# ── Figure 3: per-IBR heatmaps over time ──────────────────────────────────────

function fig_heatmap(samples, folder, nsteps, out)
    ids   = sort(unique(s.ibr for s in samples))
    # sort rows by mean monitored voltage so structure is visible
    meanU = Dict(id => mean(s.U for s in samples if s.ibr == id) for id in ids)
    ids   = sort(ids; by=id -> meanU[id])
    idx   = Dict(id => i for (i, id) in enumerate(ids))

    Q = fill(NaN, length(ids), nsteps)
    V = fill(NaN, length(ids), nsteps)
    for s in samples
        Q[idx[s.ibr], s.tstep] = s.qg / s.smax
        V[idx[s.ibr], s.tstep] = s.U
    end

    show_yticks = length(ids) <= 60
    yt = show_yticks ? (1:length(ids), ids) : false
    qabs = maximum(abs, filter(isfinite, Q); init=1.0)

    p1 = heatmap(1:nsteps, 1:length(ids), Q; c=:RdBu, clims=(-qabs, qabs),
                 yticks=yt, xlabel="time step", ylabel="IBR (↑ mean voltage)",
                 title="Q / S_max", colorbar_title="pu")
    p2 = heatmap(1:nsteps, 1:length(ids), V; c=:thermal,
                 yticks=yt, xlabel="time step", ylabel="",
                 title="monitored voltage", colorbar_title="V")

    h = clamp(20 * length(ids), 360, 1400)
    plt = plot(p1, p2; layout=(1, 2), size=(1100, h),
               plot_title="$folder — per-IBR over the day ($MODE_LABEL)")
    savefig(plt, out)
end

# ── Driver ────────────────────────────────────────────────────────────────────

function main(args)
    folders = discover_folders(args)
    println("[plots] $(length(folders)) folder(s).\n")
    entries = Tuple{String,Vector{String}}[]   # (folder, [png basenames])

    for dir in folders
        folder = basename(dir)
        print("  $folder … "); flush(stdout)
        samples, profile, quantity, nsteps = gather_folder(dir)
        if isempty(samples) || profile === nothing
            println("no IBR samples — skipped"); continue
        end
        f_curves  = joinpath(dir, "$(folder)_$(MODE)_curves.png")
        f_daily   = joinpath(dir, "$(folder)_$(MODE)_daily.png")
        f_heatmap = joinpath(dir, "$(folder)_$(MODE)_heatmap.png")
        fig_curves(samples, profile, quantity, folder, f_curves)
        fig_daily(samples, profile, quantity, folder, f_daily)
        fig_heatmap(samples, folder, nsteps, f_heatmap)
        n_ibr = length(unique(s.ibr for s in samples))
        println("✓  $(n_ibr) IBRs × $(nsteps) steps  ($(length(samples)) points)")
        push!(entries, (folder, [basename(f_curves), basename(f_daily), basename(f_heatmap)]))
    end

    write_gallery(entries)
    println("\n[plots] $GALLERY_MD")
    println("Done.")
end

function write_gallery(entries)
    open(GALLERY_MD, "w") do io
        println(io, "# ENWL Snapshots — volt-var / volt-watt visualisations ($MODE_LABEL)\n")
        println(io, "Smart-inverter (AS/NZS 4777.2) behaviour across one day of varying solar, ")
        println(io, "per feeder. Generated by `plot_snapshots.jl` from the `*_result_$(MODE).json` results.\n")
        println(io, "> Note: with volt-watt `p_ref = S_MAX`, available solar (`p_max`) is not ")
        println(io, "> enforced as the active-power upper bound, so Σ P stays near rated even at ")
        println(io, "> night — visible as the gap to Σ P available in the daily plot.\n")
        for (folder, pngs) in entries
            println(io, "## $folder\n")
            println(io, "**Regime activation** — operating points on the control curves, coloured by time of day:\n")
            println(io, "![$folder curves]($folder/$(pngs[1]))\n")
            println(io, "**Daily aggregate** — fleet P (dispatched vs available), Q (volt-var), and voltage band:\n")
            println(io, "![$folder daily]($folder/$(pngs[2]))\n")
            println(io, "**Per-IBR heatmaps** — Q/S_max and monitored voltage over the 25 steps:\n")
            println(io, "![$folder heatmap]($folder/$(pngs[3]))\n")
        end
    end
end

main(ARGS)
