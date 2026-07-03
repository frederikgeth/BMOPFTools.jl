# io/project_solution.jl
#
# Project a solved OPF result back onto its network, pinning every controllable
# device to the setpoint it takes in the solution. The projected net is a fully
# *determined* snapshot: a valid input to `solve_pf`, and — via `to_dss` — an
# OpenDSS power-flow deck whose only free quantities are the nodal voltages. This
# is what lets an OPF solution be re-solved on an independent oracle (OpenDSS) to
# validate its feasibility end-to-end.
#
# The pinning is the exact inverse of how the OPF result was extracted
# (ext/BMOPFOpfExt/results.jl): generator/IBR per-phase dispatch is keyed by
# phase-terminal name, and the net's p_min/p_max/q_min/q_max vectors are indexed
# by the enumeration order of the phase subset — so we reconstruct that same
# order here (`_projection_phase_order`) to map each solved pg/qg onto the right
# vector slot.

"""
    _projection_phase_order(comp_type, dev) -> (terminal_map, phase_positions)

Reproduce the phase ordering the OPF builder/extractor uses so that the k-th
entry of `p_min`/`p_max`/`q_min`/`q_max` corresponds to phase terminal
`terminal_map[phase_positions[k]]`.

- generators: `WYE` → non-neutral positions; `DELTA` → every position.
- IBRs: `FOUR_LEG` → non-neutral positions; `THREE_LEG` → every position;
  `SINGLE_PHASE` → the first (phase) position only.

Mirrors `generator.jl` / `ibr.jl` and `results.jl`.
"""
function _projection_phase_order(comp_type::Symbol, dev::Dict{String,Any})
    tm = String.(get(dev, "terminal_map", String[]))
    if comp_type === :generator
        phs = get(dev, "configuration", "WYE") == "DELTA" ?
              collect(eachindex(tm)) : _phase_positions(tm)
    else # :ibr
        topo = get(dev, "topology", "FOUR_LEG")
        phs = topo == "THREE_LEG"   ? collect(eachindex(tm)) :
              topo == "SINGLE_PHASE" ? (isempty(tm) ? Int[] : [1]) :
              _phase_positions(tm)   # FOUR_LEG
    end
    return tm, phs
end

# Pin one generator/IBR's p_min/p_max/q_min/q_max to the solved pg/qg. Returns
# `true` if the device was pinned (every reported phase found), `false` if it was
# left untouched (missing/NaN setpoint). `res` is `result[comp][id]`.
function _pin_dispatch!(comp_type::Symbol, dev::Dict{String,Any}, res)
    res isa Dict || return false
    tm, phs = _projection_phase_order(comp_type, dev)
    isempty(phs) && return false
    n = length(phs)
    pg = Vector{Float64}(undef, n)
    qg = Vector{Float64}(undef, n)
    for (idx, ph) in enumerate(phs)
        ph <= length(tm) || return false
        r = get(res, tm[ph], nothing)
        r isa Dict || return false
        p = get(r, "pg", NaN); q = get(r, "qg", NaN)
        (p isa Number && q isa Number && isfinite(p) && isfinite(q)) || return false
        pg[idx] = p; qg[idx] = q
    end
    # An IBR under a control_profile carries no q box (the profile couples Q to P
    # internally); freezing at the solved point means dropping the profile and
    # writing explicit fixed bounds, turning it into a determined PQ injection.
    if comp_type === :ibr
        delete!(dev, "control_profile")
    end
    dev["p_min"] = copy(pg); dev["p_max"] = copy(pg)
    dev["q_min"] = copy(qg); dev["q_max"] = copy(qg)
    return true
end

"""
    project_solution(net, result; t_index=1) -> Dict{String,Any}

Return a deep copy of `net` with every controllable device pinned to the setpoint
it takes in `result` (as returned by [`solve_opf`](@ref) or [`solve_pf`](@ref)),
so the projected net is a fully *determined* snapshot.

Pinned devices:
- **Generators** and **IBRs** — per-phase active/reactive dispatch fixed to the
  solved `pg`/`qg` (`p_min == p_max == pg`, `q_min == q_max == qg`). An IBR under a
  `control_profile` (Volt-var / power-factor) has the profile reference removed and
  explicit fixed bounds written, freezing the smart-inverter control at its solved
  operating point.
- **Free transformer taps** — a tap that was an OPF decision variable (reported as
  `tap` / `tap_ratio` in `result`) is written back onto the transformer.
  Fixed-tap transformers are left untouched. For `open_delta_regulator` the tap is
  a two-element vector; only regulators that were free (non-`missing`) are updated.

Loads, capacitors and voltage sources are not decision variables and are copied
unchanged. The input `net` is never mutated.

The projected net is a legal input to `solve_pf` (every generator satisfies
`p_min == p_max`, `q_min == q_max`) and, via `to_dss`, to OpenDSS.

`result["_meta"]["projection"]` on the returned net records what was pinned
(`generators`, `ibrs`, `free_taps`) and which IBR control profiles were frozen, so
downstream diagnostics can attribute any oracle mismatch.

# Errors
- `ArgumentError` if `result` is infeasible (`result["feasible"] == false`), since
  an infeasible result carries `NaN` setpoints and cannot be projected.

# Example
```julia
net    = from_dss("test/data/pf_comparison/pf_pv_4leg.dss")
result = solve_opf(net)
snap   = project_solution(net, result)
solve_pf(snap)          # re-solve as a determined power flow
to_dss(snap, "snap.dss")  # export the pinned snapshot to OpenDSS
```
"""
function project_solution(net::Dict{String,Any}, result::Dict{String,Any};
                          t_index::Int=1)::Dict{String,Any}
    if get(result, "feasible", true) === false
        throw(ArgumentError("project_solution: result is infeasible " *
            "(termination_status=$(get(result, "termination_status", "?"))); " *
            "its NaN setpoints cannot be projected"))
    end
    working   = is_timeseries(net) ? get_snapshot(net, t_index) : net
    projected = deepcopy(working)

    pinned_gens  = String[]
    pinned_ibrs  = String[]
    frozen_cps   = String[]
    free_taps    = String[]

    # ── Generators ──────────────────────────────────────────────────────────
    gen_res = get(result, "generator", Dict())
    for (gid, gen) in get(projected, "generator", Dict())
        gen isa Dict || continue
        if _pin_dispatch!(:generator, gen, get(gen_res, gid, nothing))
            push!(pinned_gens, gid)
        end
    end

    # ── IBRs ────────────────────────────────────────────────────────────────
    ibr_res = get(result, "ibr", Dict())
    for (iid, inv) in get(projected, "ibr", Dict())
        inv isa Dict || continue
        had_cp = get(inv, "control_profile", nothing) isa String
        if _pin_dispatch!(:ibr, inv, get(ibr_res, iid, nothing))
            push!(pinned_ibrs, iid)
            had_cp && push!(frozen_cps, iid)
        end
    end

    # ── Free transformer taps ────────────────────────────────────────────────
    # Transformer results are keyed flat by id (mixing subtypes); the net nests
    # them by subtype. A tap/tap_ratio key is present ONLY when the tap was free.
    xfmr_res = get(result, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(get(projected, "transformer", Dict()), subtype, nothing)
        sub isa Dict || continue
        for (tid, xfmr) in sub
            xfmr isa Dict || continue
            rec = get(xfmr_res, tid, nothing)
            rec isa Dict || continue
            if subtype == "open_delta_regulator" && haskey(rec, "tap_ratio")
                # Element-wise: only overwrite regulators that were free
                # (the extractor stores `missing` for a fixed arm).
                ratios = rec["tap_ratio"]
                base = collect(Any, get(xfmr, "tap_ratio", Any[missing, missing]))
                applied = false
                for k in eachindex(ratios)
                    r = ratios[k]
                    if r !== missing && r isa Number
                        k <= length(base) ? (base[k] = Float64(r)) : push!(base, Float64(r))
                        applied = true
                    end
                end
                applied && (xfmr["tap_ratio"] = base; push!(free_taps, tid))
            elseif haskey(rec, "tap_ratio")           # single_phase_autotransformer
                xfmr["tap_ratio"] = rec["tap_ratio"]; push!(free_taps, tid)
            elseif haskey(rec, "tap")                 # ordinary transformers
                xfmr["tap"] = rec["tap"]; push!(free_taps, tid)
            end
        end
    end

    meta = get!(projected, "_meta", Dict{String,Any}())
    meta["projection"] = Dict{String,Any}(
        "generators"           => pinned_gens,
        "ibrs"                 => pinned_ibrs,
        "control_profiles_frozen" => frozen_cps,
        "free_taps"            => free_taps,
    )
    return projected
end

# Nominal voltage for the equivalent injection load: prefer the device's own
# `v_nom`, else borrow from a load already at the same bus with a compatible
# configuration (IBRs placed by `add_ibrs` always sit on a load bus). Returns
# `nothing` if none is found — a constant-power load does not require `v_nom`.
function _injection_v_nom(net::Dict{String,Any}, bus::AbstractString,
                          cfg::AbstractString, dev::Dict{String,Any})
    haskey(dev, "v_nom") && return dev["v_nom"]
    for (_, ld) in get(net, "load", Dict())
        ld isa Dict || continue
        get(ld, "bus", "") == bus && get(ld, "configuration", "") == cfg &&
            haskey(ld, "v_nom") && return ld["v_nom"]
    end
    return nothing
end

"""
    dispatch_as_loads(net) -> Dict{String,Any}

Return a deep copy of `net` with every **pinned** generator and IBR replaced by an
equivalent constant-power **negative load** (`p_nom = -p_min`, `q_nom = -q_min`),
carrying the device's terminal map and the load configuration implied by its
connection (`WYE` for generator-WYE / IBR-`FOUR_LEG`, `DELTA` for generator-DELTA /
IBR-`THREE_LEG`, `SINGLE_PHASE` for IBR-`SINGLE_PHASE`). Generators/IBRs sitting on
a `voltage_source` bus are **dropped, not converted** — the slack source is the
reference and unbounded injector in a power flow, so its dispatch must not be
re-imposed as a load.

This is the bridge that makes an OPF snapshot exportable to OpenDSS **today**:
[`to_dss`](@ref) (via PowerIO) cannot yet emit a BMOPF `ibr`/`generator`, but it
exports loads faithfully, and a fixed PQ injection is exactly a negative constant-
power load. Intended to be applied to the output of [`project_solution`](@ref) (so
every generator/IBR already has `p_min == p_max`); a device without fixed bounds is
skipped and recorded under `_meta`.

The negative-load form is equivalent to the pinned generator/IBR form under a
determined power flow, so `solve_pf(dispatch_as_loads(project_solution(net, r)))`
matches the original OPF voltages — the load form is what gets exported and solved
in OpenDSS.

`_meta["dispatch_as_loads"]` records the ids converted, the ids dropped as slack,
and any skipped (unpinned) devices.

Direct `generator`/`ibr` OpenDSS mappings can replace this bridge once PowerIO
supports them.
"""
function dispatch_as_loads(net::Dict{String,Any})::Dict{String,Any}
    projected = deepcopy(net)
    vs_buses = Set(String(get(vs, "bus", "")) for vs in values(get(projected, "voltage_source", Dict())) if vs isa Dict)
    loads = get!(projected, "load", Dict{String,Any}())

    converted = String[]; dropped_slack = String[]; skipped = String[]
    for (comp, cfg_of) in (("generator", d -> get(d, "configuration", "WYE") == "DELTA" ? "DELTA" : "WYE"),
                           ("ibr",       d -> (t = get(d, "topology", "FOUR_LEG"); t == "THREE_LEG" ? "DELTA" : t == "SINGLE_PHASE" ? "SINGLE_PHASE" : "WYE")))
        for (id, dev) in get(projected, comp, Dict())
            dev isa Dict || continue
            bus = String(get(dev, "bus", ""))
            if bus in vs_buses
                push!(dropped_slack, id); continue          # slack: the Vsource handles it
            end
            pmin = get(dev, "p_min", nothing); pmax = get(dev, "p_max", nothing)
            qmin = get(dev, "q_min", nothing); qmax = get(dev, "q_max", nothing)
            if !(pmin isa AbstractVector && pmax isa AbstractVector &&
                 qmin isa AbstractVector && qmax isa AbstractVector &&
                 pmin == pmax && qmin == qmax && !isempty(pmin))
                push!(skipped, id); continue                # not a fixed setpoint
            end
            cfg = cfg_of(dev)
            ld = Dict{String,Any}(
                "bus"          => bus,
                "terminal_map" => copy(get(dev, "terminal_map", String[])),
                "configuration" => cfg,
                "model"        => "constant_power",
                "p_nom"        => [-Float64(x) for x in pmin],
                "q_nom"        => [-Float64(x) for x in qmin],
            )
            vn = _injection_v_nom(projected, bus, cfg, dev)
            vn !== nothing && (ld["v_nom"] = vn)
            loads["inj_$(id)"] = ld
            push!(converted, id)
        end
        delete!(projected, comp)
    end

    meta = get!(projected, "_meta", Dict{String,Any}())
    meta["dispatch_as_loads"] = Dict{String,Any}(
        "converted" => converted, "dropped_slack" => dropped_slack, "skipped" => skipped)
    return projected
end
