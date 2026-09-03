"""
    enwl_encoding_study.jl

Batch the smooth-vs-CCOpt encoding comparison across the ENWL snapshot
benchmarks, including PV-capacity variants that push a feeder into the
Volt-watt curtailment regime.

Why the variants exist. The snapshots carry no bus voltage bounds at all, so
nothing competes with the droop curves — but at their shipped PV capacity only
the 538-bus feeders actually rise past the 253 V Volt-watt knee. On 30-bus the
peak-PV voltage is 245 V and Volt-watt never engages, so its hinges sit at the
`r = 0` branch and the encoding comparison never exercises curtailment.
Scaling every inverter's `p_avail`, `p_max`, `s_max`, `q_max` and `q_min`
together is a hosting-capacity sweep — larger inverters at the same sites — and
it leaves the network, the source and each curve's per-unit shape untouched,
because the droop bases scale with `s_max` alongside the ratings.

Three encodings per case, so that solver and encoding effects stay separable:

    smooth / ipopt    the status quo
    smooth / madnlp   same encoding, different solver   -> solver effect
    ccopt             different encoding, same solver   -> encoding effect

Usage:

    julia --project=<env-with-ccopt> scripts/enwl_encoding_study.jl \
        /path/to/BMOPFDraftData/benchmarks/ENWLsnapshots --out=study.tsv

Options:

    --feeders=30bus_LG,...     default: every feeder folder found
    --times=t09,...,t17        snapshot prefixes; default t09..t17 (peak PV)
    --pv-scale=1,2,3           PV capacity multipliers; 1 is the shipped case
    --scale-feeders=30bus,99bus  substring match; which feeders get scaled >1
    --eps=2e-3,1e-4            smooth smoothing widths
    --tol=1e-10                convergence tolerance for the smooth rows
    --limit=N                  stop after N cases (pilot runs)
    --out=FILE                 write the TSV report

`--tol` is deliberately not forwarded to the CCOpt row: tightening CCOpt's
inner tolerance disrupts its homotopy, and how exactly that row solved its
pairs is reported directly in the residual columns instead.
"""

using Pkg

const _ROOT = normpath(joinpath(@__DIR__, ".."))
if isnothing(Base.identify_package("BMOPFTools"))
    Pkg.activate(_ROOT)
end

using BMOPFTools

const _NEEDED = ("JuMP", "Ipopt", "CCOpt", "MPCCModels", "NLPModelsJuMP", "MadNLP", "JSON3")
const _MISSING = filter(n -> isnothing(Base.identify_package(n)), _NEEDED)
isempty(_MISSING) || error(
    "missing packages: " * join(_MISSING, ", ") * "; see scripts/README.md")

@eval using JuMP
@eval using Ipopt
@eval using CCOpt
@eval using MPCCModels
@eval using NLPModelsJuMP
@eval import MadNLP
@eval using JSON3
using Printf, Statistics

const VOLT_WATT_KNEE = 253.0     # AS/NZS 4777 lower Volt-watt breakpoint

# ── Options ───────────────────────────────────────────────────────────────────

struct Options
    root::String
    feeders::Union{Vector{String},Nothing}
    times::Vector{String}
    pv_scales::Vector{Float64}
    scale_feeders::Vector{String}
    epsilons::Vector{Float64}
    tol::Float64
    limit::Union{Int,Nothing}
    output::Union{String,Nothing}
end

_csv(arg) = String.(strip.(split(last(split(arg, "=", limit=2)), ",")))

function _parse_args(args)
    isempty(args) && error("the ENWLsnapshots directory is required")
    root = nothing
    feeders = nothing
    times = ["t09", "t10", "t11", "t12", "t13", "t14", "t15", "t16", "t17"]
    pv_scales = [1.0, 2.0, 3.0]
    scale_feeders = ["30bus", "99bus"]
    epsilons = [2e-3, 1e-4]
    tol = 1e-10
    limit = nothing
    output = nothing
    for arg in args
        if startswith(arg, "--feeders=");            feeders = _csv(arg)
        elseif startswith(arg, "--times=");          times = _csv(arg)
        elseif startswith(arg, "--pv-scale=");       pv_scales = parse.(Float64, _csv(arg))
        elseif startswith(arg, "--scale-feeders=");  scale_feeders = _csv(arg)
        elseif startswith(arg, "--eps=");            epsilons = parse.(Float64, _csv(arg))
        elseif startswith(arg, "--tol=");            tol = parse(Float64, last(split(arg, "=", limit=2)))
        elseif startswith(arg, "--limit=");          limit = parse(Int, last(split(arg, "=", limit=2)))
        elseif startswith(arg, "--out=");            output = last(split(arg, "=", limit=2))
        elseif startswith(arg, "-");                 error("unknown option $arg")
        elseif root === nothing;                     root = arg
        else                                         error("unexpected argument $arg")
        end
    end
    root === nothing && error("the ENWLsnapshots directory is required")
    isdir(root) || error("not a directory: $root")
    Options(normpath(root), feeders, times, pv_scales, scale_feeders,
            epsilons, tol, limit, output)
end

# ── Case discovery and the PV-capacity variant ────────────────────────────────

function _cases(options)
    folders = options.feeders === nothing ?
        sort!(filter(d -> isdir(joinpath(options.root, d)) &&
                          !isempty(glob_bmopf(joinpath(options.root, d))),
                     readdir(options.root))) :
        options.feeders
    out = Tuple{String,String,String}[]     # (feeder, time-tag, path)
    for feeder in folders
        for path in glob_bmopf(joinpath(options.root, feeder))
            tag = match(r"_(t\d+)_", basename(path))
            tag === nothing && continue
            tag[1] in options.times || continue
            push!(out, (feeder, tag[1], path))
        end
    end
    sort!(out; by = c -> (c[1], c[2]))
end

glob_bmopf(dir) = sort!(filter(p -> endswith(p, ".bmopf.json"),
                               joinpath.(dir, readdir(dir))))

"""
    _scaled_case(path, factor) -> written temp path

Scale every inverter's ratings together. `p_avail` and `p_max` set what the
plant can produce; `s_max` sets the apparent-power envelope AND the reference
base for both droop curves; `q_max`/`q_min` set the reactive envelope. Moving
them as one keeps the control law's per-unit shape identical, so the variant
changes hosting capacity and nothing else.
"""
function _scaled_case(path, factor)
    factor == 1.0 && return path
    d = JSON3.read(read(path, String), Dict{String,Any})
    for inverter in values(d["ibr"])
        for key in ("p_avail", "p_max", "p_min", "q_max", "q_min", "s_max")
            haskey(inverter, key) || continue
            value = inverter[key]
            inverter[key] = value isa AbstractVector ?
                [x * factor for x in value] : value * factor
        end
    end
    out = joinpath(mktempdir(), basename(path))
    write(out, JSON3.write(d))
    return out
end

# ── Solving ───────────────────────────────────────────────────────────────────

_spec(:: Val{:ipopt}, tol) = (Ipopt.Optimizer,
    ("print_level" => 0, "bound_relax_factor" => 0.0, "tol" => tol,
     "max_iter" => 1000))
_spec(:: Val{:madnlp}, tol) = (MadNLP.Optimizer,
    ("print_level" => MadNLP.ERROR, "bound_relax_factor" => 0.0, "tol" => tol,
     "max_iter" => 1000))

_quiet(f) = redirect_stdout(devnull) do; f() end

function _run_smooth(path, epsilon, solver, tol)
    optimizer, options = _spec(Val(solver), tol)
    t0 = time()
    result = try
        _quiet(() -> solve_opf(parse_bmopf(path); optimizer=optimizer,
                               solver_options=options,
                               volt_var_watt_eps=epsilon, verbose=false))
    catch err
        return (nothing, time() - t0, sprint(showerror, err))
    end
    (result, time() - t0, nothing)
end

function _run_ccopt(path)
    t0 = time()
    handle = try
        build_ccopt_model(parse_bmopf(path))
    catch err
        return (nothing, nothing, time() - t0, sprint(showerror, err))
    end
    stats = try
        _quiet(() -> solve_ccopt!(handle))
    catch err
        return (nothing, handle, time() - t0, sprint(showerror, err))
    end
    result = try
        extract_ccopt_result(handle)
    catch err
        return (nothing, handle, time() - t0, sprint(showerror, err))
    end
    (result, handle, time() - t0, nothing)
end

# ── Measurements ──────────────────────────────────────────────────────────────

"""Bus voltage magnitudes, excluding neutral/ground terminals near zero."""
function _phase_voltages(result)
    vms = Float64[]
    for (_, terminals) in get(result, "bus", Dict())
        for (_, values) in terminals
            values isa Dict && haskey(values, "vm") || continue
            values["vm"] > 1.0 && push!(vms, Float64(values["vm"]))
        end
    end
    vms
end

function _total(result, group, field)
    total = 0.0
    for (_, entries) in get(result, group, Dict())
        for (_, values) in entries
            values isa Dict || continue
            total += Float64(get(values, field, 0.0))
        end
    end
    total
end

function _available_power(path)
    d = JSON3.read(read(path, String), Dict{String,Any})
    total = 0.0
    for inverter in values(get(d, "ibr", Dict()))
        value = get(inverter, "p_avail", 0)
        value === nothing && continue
        total += value isa AbstractVector ? sum(Float64, value) : Float64(value)
    end
    total
end

"""
    _hinge_activity(handle) -> (volt_watt_active, volt_var_active, pairs)

Count complementarity pairs sitting on their ACTIVE branch (`r > 0`, i.e. the
monitored voltage is past that breakpoint) rather than the dormant `r = 0`
branch. This is the direct measure of whether a droop curve is doing anything,
and it is only available on the CCOpt path — the smooth encoding has no hinge
variable to read.
"""
function _hinge_activity(handle; tol=1e-6)
    x = handle.stats.solution
    volt_watt = 0; volt_var = 0
    for (k, (i, _)) in enumerate(handle.pair_indices)
        x[i] > tol || continue
        controller = get(handle.pairs[k].metadata, "controller", "")
        controller == "volt_watt" && (volt_watt += 1)
        controller == "volt_var"  && (volt_var  += 1)
    end
    (volt_watt, volt_var, length(handle.pair_indices))
end

function _max_difference(a, b, group, field)
    (a === nothing || b === nothing) && return missing
    haskey(a, group) && haskey(b, group) || return missing
    worst = 0.0
    for id in intersect(keys(a[group]), keys(b[group]))
        for phase in intersect(keys(a[group][id]), keys(b[group][id]))
            left, right = a[group][id][phase], b[group][id][phase]
            haskey(left, field) && haskey(right, field) || continue
            worst = max(worst, abs(Float64(left[field]) - Float64(right[field])))
        end
    end
    worst
end

const HEADERS = [
    "feeder", "time", "pv_scale", "n_ibr", "n_pairs",
    "vmax_V", "terminals_over_knee", "curtailment_pct",
    "volt_watt_hinges_active", "volt_var_hinges_active",
    "ccopt_status", "ccopt_iters", "ccopt_time_s",
    "ccopt_complementarity_ok", "ccopt_curve_error_rel", "ccopt_bound_violation",
    "ipopt_status", "ipopt_iters", "ipopt_time_s",
    "madnlp_status", "madnlp_iters", "madnlp_time_s",
    "eps_fine", "max_dpg_W", "max_dqg_var", "max_dvm_V",
    "solver_disagreement_V", "note",
]

_fmt(v) = v === nothing || v === missing ? "" :
          v isa AbstractFloat ? (isfinite(v) ? @sprintf("%.6g", v) : "") :
          string(v)

function main(args = ARGS)
    options = _parse_args(args)
    cases = _cases(options)
    fine = minimum(options.epsilons)
    println("ENWL encoding study")
    println("  root      : $(options.root)")
    println("  cases     : $(length(cases)) snapshots x PV scales $(options.pv_scales)")
    println("  epsilons  : $(options.epsilons)   tol $(options.tol)")
    rows = Vector{Any}()
    done = 0

    for (feeder, tag, path) in cases, scale in options.pv_scales
        scale == 1.0 || any(occursin(f, feeder) for f in options.scale_feeders) || continue
        options.limit === nothing || done < options.limit || break
        done += 1
        case_path = _scaled_case(path, scale)
        note = String[]

        ccopt, handle, ccopt_time, ccopt_error = _run_ccopt(case_path)
        ccopt_error === nothing || push!(note, "ccopt: " * first(split(ccopt_error, "\n")))

        smooth = Dict{Symbol,Any}()
        for solver in (:ipopt, :madnlp), epsilon in options.epsilons
            result, elapsed, err = _run_smooth(case_path, epsilon, solver, options.tol)
            smooth[Symbol(solver, :_, epsilon)] = (result, elapsed, err)
            err === nothing || push!(note, "$solver@$epsilon: " * first(split(err, "\n")))
        end
        ip, ip_time, _ = smooth[Symbol(:ipopt, :_, fine)]
        mp, mp_time, _ = smooth[Symbol(:madnlp, :_, fine)]

        reference = ip !== nothing && ip["feasible"] ? ip : nothing
        vms = reference === nothing ? Float64[] : _phase_voltages(reference)
        available = _available_power(case_path)
        generated = reference === nothing ? NaN : _total(reference, "ibr", "pg")
        activity = (handle !== nothing && handle.stats !== nothing) ?
            _hinge_activity(handle) : (missing, missing, missing)

        gap = (reference !== nothing && mp !== nothing && mp["feasible"]) ?
            _max_difference(reference, mp, "bus", "vm") : missing

        push!(rows, [
            feeder, tag, scale,
            handle === nothing ? missing : length(handle.ctx.net["ibr"]),
            handle === nothing ? missing : length(handle.pair_indices),
            isempty(vms) ? missing : maximum(vms),
            isempty(vms) ? missing : count(>(VOLT_WATT_KNEE), vms),
            available > 0 && isfinite(generated) ? 100 * (1 - generated / available) : missing,
            activity[1], activity[2],
            ccopt === nothing ? "ERROR" : ccopt["termination_status"],
            ccopt === nothing ? missing : get(ccopt["opt_profile"], "barrier_iterations", missing),
            ccopt_time,
            ccopt === nothing ? missing : ccopt["ccopt"]["complementarity_satisfied"],
            ccopt === nothing ? missing : ccopt["ccopt"]["max_curve_error_relative"],
            ccopt === nothing ? missing : ccopt["ccopt"]["max_hinge_bound_violation"],
            ip === nothing ? "ERROR" : ip["termination_status"],
            ip === nothing ? missing : get(ip["opt_profile"], "barrier_iterations", missing),
            ip_time,
            mp === nothing ? "ERROR" : mp["termination_status"],
            mp === nothing ? missing : get(mp["opt_profile"], "barrier_iterations", missing),
            mp_time,
            fine,
            (ccopt === nothing || reference === nothing) ? missing :
                _max_difference(ccopt, reference, "ibr", "pg"),
            (ccopt === nothing || reference === nothing) ? missing :
                _max_difference(ccopt, reference, "ibr", "qg"),
            (ccopt === nothing || reference === nothing) ? missing :
                _max_difference(ccopt, reference, "bus", "vm"),
            gap,
            join(note, " | "),
        ])

        @printf("[%3d] %-11s %-4s pv=%.0f  pairs=%5s vw_active=%5s  ccopt=%-34s %6.1fs\n",
                done, feeder, tag, scale, _fmt(rows[end][5]), _fmt(activity[1]),
                rows[end][11], ccopt_time)
        flush(stdout)

        if options.output !== nothing
            open(options.output, "w") do io
                println(io, "# ENWL encoding study — root=$(options.root)")
                println(io, "# epsilons=$(options.epsilons) tol=$(options.tol) (smooth rows only)")
                println(io, "# bound_relax_factor=0.0 everywhere")
                println(io, join(HEADERS, '\t'))
                for row in rows; println(io, join(_fmt.(row), '\t')); end
            end
        end
    end
    println("\nDone: $(length(rows)) rows" *
            (options.output === nothing ? "" : " -> $(options.output)"))
end

main()
