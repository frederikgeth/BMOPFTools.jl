"""
    CaseScenario(; name="scenario", demand_scale=1.0, reactive_scale=nothing,
                   pv_scale=1.0, t_index=nothing, pv_ids=nothing)

An independent operating point. Scale load `p_nom` and `q_nom` after resolving
an optional time-series snapshot; `reactive_scale=nothing` follows demand and
preserves each load's power factor. Scale PV IBR `p_avail` and resolve per-phase
`p_max` using rating-proportional availability, capped by existing `p_max` and
`s_max`. Retain nameplate, lower bounds, reactive bounds and controller settings. Explicit `pv_ids`
restrict the PV selection and must identify PV devices with finite availability.
Factors must be finite and nonnegative. These are study assumptions, not a
probability model. A time-series input requires an explicit `t_index`.
"""
Base.@kwdef struct CaseScenario
    name::String = "scenario"
    demand_scale::Float64 = 1.0
    reactive_scale::Union{Float64,Nothing} = nothing
    pv_scale::Float64 = 1.0
    t_index::Union{Int,Nothing} = nothing
    pv_ids::Union{Vector{String},Nothing} = nothing
end

function _scenario_pv_phase_order(net, inv)
    tm = String.(get(inv, "terminal_map", String[]))
    topology = get(inv, "topology", "FOUR_LEG")
    topology in ("FOUR_LEG", "THREE_LEG", "SINGLE_PHASE") ||
        throw(ArgumentError("unsupported PV topology '$topology'"))
    length(unique(tm)) == length(tm) || throw(ArgumentError("duplicate PV terminals"))
    topology == "SINGLE_PHASE" && length(tm) != 2 &&
        throw(ArgumentError("SINGLE_PHASE PV requires two terminals"))
    bus = get(get(net, "bus", Dict()), get(inv, "bus", ""), Dict())
    !isempty(tm) && all(t -> t in get(bus, "terminal_names", String[]), tm) ||
        throw(ArgumentError("PV terminal map must reference declared bus terminals"))
    phases = topology == "SINGLE_PHASE" ? [1] : topology == "THREE_LEG" ?
        collect(eachindex(tm)) : _phase_positions(tm, _neutral_labels(net))
    tm, phases
end

"""
    materialize_scenario(net, scenario::CaseScenario) -> (network, manifest)

Build a deep, independent copy and record the parameter changes. Load model,
voltage base, hardware ratings and non-PV bounds are retained. Repeated calls always
start from the supplied base, not the preceding scenario. An increased PV
availability is still capped by the base case's explicit operating ceiling.
A retained positive `p_min` may conflict with a low-availability scenario; this
incompatibility is not silently repaired.
"""
function materialize_scenario(net::Dict{String,Any}, scenario::CaseScenario)
    r = scenario
    qscale = something(r.reactive_scale, r.demand_scale)
    all(x -> isfinite(x) && x >= 0, (r.demand_scale, qscale, r.pv_scale)) ||
        throw(ArgumentError("scenario factors must be finite and nonnegative"))
    isempty(strip(r.name)) && throw(ArgumentError("scenario name must not be empty"))
    r.t_index !== nothing && r.t_index < 1 && throw(ArgumentError("t_index must be positive"))
    is_timeseries(net) && r.t_index === nothing && throw(ArgumentError(
        "time-series input requires an explicit scenario t_index"))
    out = r.t_index === nothing ? deepcopy(net) : get_snapshot(net, r.t_index)
    entries = TransformEntry[]
    function scale!(family, id, dev, field, factor)
        haskey(dev, field) || throw(ArgumentError("$family/$id lacks $field"))
        old = dev[field]
        vals = old isa AbstractVector ? old : [old]
        !isempty(vals) && all(x -> x isa Real && !(x isa Bool) && isfinite(x), vals) ||
            throw(ArgumentError("$family/$id.$field must be finite numeric data"))
        new = old isa AbstractVector ? Float64.(old) .* factor : Float64(old) * factor
        all(isfinite, new isa AbstractVector ? new : [new]) ||
            throw(ArgumentError("$family/$id.$field overflowed"))
        dev[field] = new
        push!(entries, TransformEntry(Symbol(family), id, field, deepcopy(old), deepcopy(new),
            "scenario_scale", :synthetic, "$(r.name): multiplier $factor"))
    end
    for id in sort!(collect(keys(get(out, "load", Dict()))))
        dev = out["load"][id]
        scale!("load", id, dev, "p_nom", r.demand_scale)
        scale!("load", id, dev, "q_nom", qscale)
    end
    invs = get(out, "ibr", Dict())
    ids = r.pv_ids === nothing ? sort!([id for (id, dev) in invs
        if uppercase(string(get(dev, "prime_mover", ""))) == "PV"]) : r.pv_ids
    length(unique(ids)) == length(ids) || throw(ArgumentError("duplicate pv_ids"))
    for id in ids
        haskey(invs, id) || throw(ArgumentError("unknown PV IBR '$id'"))
        uppercase(string(get(invs[id], "prime_mover", ""))) == "PV" ||
            throw(ArgumentError("IBR '$id' is not declared PV"))
        availability = get(invs[id], "p_avail", nothing)
        availability isa Real && availability >= 0 ||
            throw(ArgumentError("PV '$id' needs nonnegative scalar p_avail"))
        scale!("ibr", id, invs[id], "p_avail", r.pv_scale)
        # The native solver enforces the operating box, not p_avail metadata.
        # Resolve availability with the same rating-proportional allocation used
        # by IBR augmentation, retaining any tighter explicit operating ceiling.
        dev = invs[id]
        _, phases = _scenario_pv_phase_order(out, dev)
        ratings = get(dev, "s_max", nothing)
        ratings isa AbstractVector && length(ratings) == length(phases) &&
            !isempty(ratings) && all(x -> x isa Real && !(x isa Bool) &&
                isfinite(x) && x >= 0, ratings) ||
            throw(ArgumentError("PV '$id' needs finite nonnegative per-phase s_max"))
        old = get(dev, "p_max", nothing)
        old === nothing || (old isa AbstractVector && length(old) == length(ratings) &&
            all(x -> x isa Real && !(x isa Bool) && !isnan(x), old)) ||
            throw(ArgumentError("PV '$id' needs matching numeric per-phase p_max"))
        total = sum(ratings)
        isfinite(total) || throw(ArgumentError("PV '$id' total rating overflowed"))
        available = total > 0 ? (ratings ./ total) .* dev["p_avail"] : zero.(ratings)
        ceiling = min.(ratings, available)
        old !== nothing && (ceiling = min.(ceiling, old))
        dev["p_max"] = ceiling
        push!(entries, TransformEntry(:ibr, id, "p_max", deepcopy(old), copy(ceiling),
            "scenario_pv_operating_limit", :synthetic,
            "rating-proportional availability, capped by nameplate and existing p_max"))
    end
    before = Finding[]; after = Finding[]
    benchmark_readiness_check(net, before); benchmark_readiness_check(out, after)
    out, TransformationManifest(string(Dates.now()), r, entries, before, after)
end

# Stable in-memory identity: sorted JSON object keys, preserving array order.
# Non-finite values retain explicit JSON3 tokens for hashing (not log output).
function _case_canonical(x)
    x isa AbstractDict && return "{" * join([JSON3.write(string(k)) * ":" *
        _case_canonical(x[k]) for k in sort!(collect(keys(x)); by=string)], ",") * "}"
    x isa Union{AbstractVector,Tuple} && return "[" * join(_case_canonical.(x), ",") * "]"
    JSON3.write(x; allow_inf=true)
end
_case_hash(net) = bytes2hex(SHA.sha256(_case_canonical(net)))

"""
    run_case_sweep(net, scenarios; solve, keep_results=false) -> Vector{Dict}

Materialize and solve each scenario independently using the supplied `solve(net)`
callback. Keep failed attempts as rows; interrupts propagate. Duplicate names are
rejected. Rows contain exact in-memory case hashes, resolved settings, solver
termination, and the standard independent solution profile. `completed` means
execution completed, not that feasibility or optimality was established. Full
results are optional; no files are written. Record solver options separately in
[`write_case_log`](@ref) when releasing results.
"""
function run_case_sweep(net::Dict{String,Any}, scenarios; solve, keep_results::Bool=false)
    specs = collect(scenarios)
    all(r -> r isa CaseScenario, specs) || throw(ArgumentError("expected CaseScenario entries"))
    names = [r.name for r in specs]
    length(unique(names)) == length(names) || throw(ArgumentError("scenario names must be unique"))
    rows = Dict{String,Any}[]
    for scenario in specs
        row = Dict{String,Any}("name"=>scenario.name, "status"=>"error",
            "settings"=>_recipe_to_dict(scenario), "source_sha256"=>_case_hash(net),
            "verification"=>nothing, "termination_status"=>nothing)
        stage = "materialize"
        try
            case, mf = materialize_scenario(net, scenario)
            row["case_sha256"] = _case_hash(case)
            row["manifest"] = manifest_to_dict(mf)
            stage = "solve"
            result = solve(deepcopy(case))
            result isa Dict{String,Any} || throw(ArgumentError("solve callback must return a result Dict{String,Any}"))
            row["termination_status"] = get(result, "termination_status", "UNKNOWN")
            row["objective"] = get(result, "objective", nothing)
            keep_results && (row["result"] = result)
            stage = "profile"
            report = profile_solution(case, result)
            row["verification"] = _solution_report_to_json(report)
            summary = report.results[:solution]
            row["metrics"] = Dict{String,Any}(k=>get(summary, k, nothing) for k in (
                "p_load", "p_loss", "n_volt_violations", "n_volt_active",
                "n_thermal_violations", "n_thermal_active", "n_inv_violations", "n_inv_active"))
            row["metrics"]["voltage_zones"] = _jsonable(report.results[:voltage_zones])
            pv_ids = [id for (id, inv) in get(case, "ibr", Dict())
                      if uppercase(string(get(inv, "prime_mover", ""))) == "PV"]
            availability = sum(get(case["ibr"][id], "p_avail", 0.0) for id in pv_ids; init=0.0)
            dispatch = Float64[]
            for id in pv_ids
                dev = case["ibr"][id]
                tm, phs = _scenario_pv_phase_order(case, dev)
                for ph in phs
                    value = get(get(get(get(result, "ibr", Dict()), id, Dict()), tm[ph], Dict()), "pg", NaN)
                    push!(dispatch, value isa Real ? value : NaN)
                end
            end
            row["metrics"]["pv_available_w"] = availability
            row["metrics"]["pv_dispatch_w"] = all(isfinite, dispatch) ? sum(dispatch) : nothing
            row["metrics"]["pv_curtailment_w"] = all(isfinite, dispatch) ?
                availability - sum(dispatch) : nothing
            row["status"] = "completed"
        catch err
            err isa InterruptException && rethrow()
            row["error_stage"] = stage
            row["error"] = sprint(showerror, err)
        end
        push!(rows, row)
    end
    rows
end

"""
    write_case_log(net, path; manifests=[], assumptions=[], settings=Dict(),
                   source_paths=[], runs=[])

Save an optional author log as JSON (`.json`) or readable Markdown (`.md`). Include
resolved transformation recipes, structured Findings, supplied assumptions and
settings, hashes of explicitly supplied source files, and optional sweep rows.
The case hash describes the in-memory model, not `write_bmopf` output bytes.
This log is not a Task Force submission requirement or a validity certificate.
Return the JSON-compatible log. No network access or solver invocation occurs.
"""
function write_case_log(net::Dict{String,Any}, path::AbstractString;
                        manifests=TransformationManifest[], assumptions=String[],
                        settings=Dict(), source_paths=String[], runs=[])
    ext = lowercase(splitext(path)[2])
    ext in (".json", ".md") || throw(ArgumentError("case log path must end in .json or .md"))
    sources = [Dict("path"=>string(p), "sha256"=>bytes2hex(SHA.sha256(read(p))))
               for p in source_paths]
    log = _jsonable(Dict{String,Any}(
        "format_version"=>"1.0", "created_at"=>string(Dates.now()),
        "package_version"=>string(Base.pkgversion(BMOPFTools)),
        "case_name"=>get(net, "name", nothing), "case_sha256"=>_case_hash(net),
        "hash_basis"=>"sorted-key in-memory JSON; array order retained",
        "sources"=>sources, "assumptions"=>assumptions, "settings"=>settings,
        "transformations"=>manifest_to_dict.(manifests), "runs"=>runs))
    open(path, "w") do io
        if ext == ".json"
            JSON3.pretty(io, log)
        else
            println(io, "# Case development log\n\nOptional author record; not a validity certificate.\n")
            println(io, "Case: ", get(net, "name", "unnamed"), "\n\nIn-memory SHA-256: `", log["case_sha256"], "`\n")
            println(io, "## Assumptions\n")
            for assumption in assumptions; println(io, "- ", assumption); end
            println(io, "\n## Transformations\n")
            for mf in manifests
                println(io, "### ", nameof(typeof(mf.recipe)), "\n")
                for e in mf.entries
                    println(io, "- `", e.component_type, "/", e.component_id, ".", e.field,
                        "`: ", e.note, " (", e.confidence, ")")
                end
            end
            println(io, "\n## Runs\n")
            for row in runs
                println(io, "- ", row["name"], ": ", row["status"], "; solver: ",
                    get(row, "termination_status", nothing), "; error: ", get(row, "error", nothing))
            end
            println(io, "\n## Complete machine-readable record\n\n```json")
            JSON3.pretty(io, log); println(io, "\n```")
        end
    end
    log
end
