# infeasibility/infeasibility.jl
#
# Post-processing of solve_feasibility_opf results.
#
# The feasibility OPF adds elastic slack current injections (cs_r, cs_i) at
# every non-source bus terminal so those KCL equations can absorb residual.
# At a converged local solution, non-zero slacks reveal where that relaxed point
# needs external current intervention; they do not prove global infeasibility.
# This module turns that raw slack pattern into a ranked, classified diagnosis.

"""
    _phase_vbounds(bus, v_nom) -> (ordered_phase_terminals, lb_of, ub_of)

Resolve per-phase voltage bounds for a bus. `v_min`/`v_max` are per-phase arrays
(phase-to-ground) ordered by `terminal_names` (neutral excluded). When a bus has
neither bound, fall back to per-unit defaults [0.85, 1.10]·v_nom on every phase
(catches networks with no explicit bounds, where voltage collapse still signals
infeasibility). `lb_of(k)`/`ub_of(k)` return the bound for the k-th phase
terminal, or `nothing` if unbounded.
"""
function _phase_vbounds(bus, v_nom)
    nt = _neutral_terminal(bus)
    phase_ts = [t for t in Vector{String}(get(bus, "terminal_names", String[])) if t != nt]
    v_min = get(bus, "v_min", nothing)
    v_max = get(bus, "v_max", nothing)
    if v_min === nothing && v_max === nothing && v_nom !== nothing
        v_min = fill(v_nom * 0.85, length(phase_ts))
        v_max = fill(v_nom * 1.10, length(phase_ts))
    end
    lb_of(k) = v_min === nothing ? nothing :
               (v_min isa AbstractVector ? get(v_min, k, nothing) : v_min)
    ub_of(k) = v_max === nothing ? nothing :
               (v_max isa AbstractVector ? get(v_max, k, nothing) : v_max)
    return phase_ts, lb_of, ub_of
end

"""
    diagnose_infeasibility(fopf_result, net; top_n=10, slack_threshold=1e-3)
        -> Dict{String,Any}

Interpret the result of [`solve_feasibility_opf`](@ref) and identify the root
cause and location of network infeasibility.

# Arguments
- `fopf_result` — output dict from `solve_feasibility_opf`
- `net`          — the same BMOPF network dict passed to `solve_feasibility_opf`
- `top_n`        — maximum number of buses to report in the ranked list
- `slack_threshold` — minimum per-bus slack magnitude (A) to count as infeasible

# Returns a dict with keys:
- `"is_feasible"`            — `true` if total slack < `slack_threshold`
- `"total_infeasibility_A"`  — L2 norm of all slack injections (A)
- `"n_infeasible_buses"`     — number of buses with per-bus slack > threshold
- `"top_buses"`              — list of up to `top_n` dicts, ranked by slack
- `"failure_mode_summary"`   — count of `voltage_bound` vs `power_balance` buses
"""
function diagnose_infeasibility(fopf_result::Dict{String,Any},
                                 net::Dict{String,Any};
                                 top_n::Int            = 10,
                                 slack_threshold::Float64 = 1e-3)

    get(fopf_result, "is_feasibility_opf", false) ||
        error("fopf_result must come from solve_feasibility_opf " *
              "(missing \"is_feasibility_opf\" key).")

    # The feasibility model shares the OPF's hard voltage/angle bounds; KCL is
    # relaxed by the nodal current residual, so power/voltage infeasibility
    # normally surfaces as a non-zero residual (handled below). A non-converged
    # solver status is the rare case where even an arbitrary nodal current cannot
    # satisfy the hard bounds (e.g. a fixed source voltage contradicting a bound
    # on the same terminal); there is no residual pattern to rank, so report it.
    if !get(fopf_result, "feasible", true)
        return Dict{String,Any}(
            "is_feasible"           => false,
            "solver_infeasible"     => true,
            "termination_status"    => get(fopf_result, "termination_status", "UNKNOWN"),
            "total_infeasibility_A" => NaN,
            "n_infeasible_buses"    => 0,
            "top_buses"             => Dict{String,Any}[],
            "failure_mode_summary"  => Dict{String,Any}(
                "voltage_bound" => 0, "power_balance" => 0),
            "voltage_violations"    => String[],
            "n_voltage_violations"  => 0,
            "note" => "Feasibility NLP did not converge: a hard voltage/angle " *
                      "bound cannot be satisfied by any nodal current (e.g. a " *
                      "source voltage contradicting a bound on the same terminal). " *
                      "Inspect the bus bounds directly.",
        )
    end

    total_mag  = Float64(get(fopf_result, "total_slack_magnitude_A", 0.0))
    slack_data = get(fopf_result, "slack_injections", Dict())
    bus_result = get(fopf_result, "bus", Dict())

    # ── Per-bus aggregate slack (L2 over terminals) ───────────────────────────
    bus_slack = Dict{String,Float64}()
    for (bid, t_dict) in slack_data
        mag = sqrt(sum(Float64(v["cs_mag"])^2 for v in values(t_dict); init=0.0))
        mag > slack_threshold && (bus_slack[bid] = mag)
    end

    sorted_buses = sort(collect(bus_slack), by=last, rev=true)

    # ── Analyse each top bus ──────────────────────────────────────────────────
    bus_net  = get(net, "bus",       Dict())
    load_net = get(net, "load",      Dict())
    gen_net  = get(net, "generator", Dict())
    v_nom_by_bus = _assign_nominal_voltages(net)

    top_buses      = Dict{String,Any}[]
    voltage_driven = 0
    power_driven   = 0

    for (bid, mag) in first(sorted_buses, top_n)
        bus     = get(bus_net, bid, Dict())
        bus_res = get(bus_result, bid, Dict())
        v_nom   = get(v_nom_by_bus, bid, nothing)
        phase_ts, lb_of, ub_of = _phase_vbounds(bus, v_nom)

        # Check whether the solved voltage at each phase terminal is near a bound
        viol = String[]
        for (k, t) in enumerate(phase_ts)
            tv = get(bus_res, t, nothing)
            tv isa Dict || continue
            vm = get(tv, "vm", NaN)
            isnan(vm) && continue
            lb = lb_of(k); ub = ub_of(k)
            if lb !== nothing && vm < Float64(lb) * 1.005
                push!(viol, "undervoltage:$t " *
                            "$(round(vm, digits=1))V < $(round(Float64(lb), digits=1))V")
            end
            if ub !== nothing && vm > Float64(ub) * 0.995
                push!(viol, "overvoltage:$t " *
                            "$(round(vm, digits=1))V > $(round(Float64(ub), digits=1))V")
            end
        end

        # Loads and generators at this bus
        bus_loads = [(lid, l) for (lid, l) in load_net if get(l, "bus", "") == bid]
        bus_gens  = [(gid, g) for (gid, g) in gen_net  if get(g, "bus", "") == bid]
        p_load_kw = sum(sum(Float64.(get(l, "p_nom", Float64[])))
                        for (_, l) in bus_loads; init=0.0) / 1000.0
        p_cap_kw  = sum(sum(Float64.(get(g, "p_max", Float64[])))
                        for (_, g) in bus_gens;  init=0.0) / 1000.0

        mode = isempty(viol) ? "power_balance" : "voltage_bound"
        mode == "voltage_bound" ? (voltage_driven += 1) : (power_driven += 1)

        push!(top_buses, Dict{String,Any}(
            "bus"               => bid,
            "slack_A"           => round(mag, sigdigits=4),
            "fraction_of_total" => total_mag > 0.0 ?
                                   round(mag / total_mag, digits=4) : 0.0,
            "failure_mode"      => mode,
            "voltage_violations"=> viol,
            "n_loads"           => length(bus_loads),
            "total_load_kW"     => round(p_load_kw, digits=3),
            "n_generators"      => length(bus_gens),
            "total_gen_cap_kW"  => round(p_cap_kw, digits=3),
        ))
    end

    # ── Voltage bound violations across ALL buses ─────────────────────────────
    # The feasibility OPF enforces the same hard voltage bounds as the OPF, so a
    # converged solution normally respects them — a constrained bus voltage sits
    # at its bound and the mismatch surfaces as residual current. This pass still
    # reports any solved voltage that lands outside:
    #   1. Explicit per-phase v_min/v_max on the bus dict (operational limits), OR
    #   2. Per-unit defaults [0.85, 1.1] of the nominal voltage derived from the
    #      source voltage via BFS propagation (catches networks with no explicit
    #      bounds, where voltage collapse still indicates infeasibility).

    volt_violations = Dict{String,Any}[]
    for (bid, bus) in bus_net
        bus_res = get(bus_result, bid, Dict())
        v_nom   = get(v_nom_by_bus, bid, nothing)
        phase_ts, lb_of, ub_of = _phase_vbounds(bus, v_nom)

        for (k, t) in enumerate(phase_ts)
            tv = get(bus_res, t, nothing)
            tv isa Dict || continue
            vm = get(tv, "vm", NaN)
            isnan(vm) && continue
            lb = lb_of(k); ub = ub_of(k)
            if lb !== nothing && vm < Float64(lb)
                push!(volt_violations, Dict{String,Any}(
                    "bus" => bid, "terminal" => t, "type" => "undervoltage",
                    "vm_V" => round(vm, digits=2),
                    "limit_V" => round(Float64(lb), digits=2),
                    "margin_V" => round(vm - Float64(lb), digits=2)))
            elseif ub !== nothing && vm > Float64(ub)
                push!(volt_violations, Dict{String,Any}(
                    "bus" => bid, "terminal" => t, "type" => "overvoltage",
                    "vm_V" => round(vm, digits=2),
                    "limit_V" => round(Float64(ub), digits=2),
                    "margin_V" => round(vm - Float64(ub), digits=2)))
            end
        end
    end
    sort!(volt_violations, by = v -> abs(Float64(v["margin_V"])), rev=true)

    is_feasible = total_mag < slack_threshold && isempty(volt_violations)

    Dict{String,Any}(
        "is_feasible"            => is_feasible,
        "total_infeasibility_A"  => round(total_mag, sigdigits=4),
        "n_infeasible_buses"     => length(bus_slack),
        "top_buses"              => top_buses,
        "failure_mode_summary"   => Dict{String,Any}(
            "voltage_bound" => voltage_driven,
            "power_balance" => power_driven,
        ),
        "voltage_violations"     => volt_violations,
        "n_voltage_violations"   => length(volt_violations),
    )
end
