"""
    infeasibility_preflight(net, findings) -> Dict{String,Any}

Pre-flight checks that predict infeasibility risk before running the OPF.
Does not run power flow — all checks are static data inspection.

Covers:
- Generation adequacy (local capacity vs load)
- Voltage bound tightness
- Constraint conflict detection (v_min > v_max, p_min > p_max)
- Topological single-point-of-failure risk
"""
function infeasibility_preflight(net::Dict{String,Any},
                                  findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()

    result["generation_adequacy"]     = _check_generation_adequacy(net, findings)
    result["voltage_bound_tightness"] = _check_voltage_bounds(net, findings)
    result["constraint_conflicts"]    = _check_constraint_conflicts(net, findings)
    result["source_setpoints"]        = _check_source_setpoints(net, findings)
    result["source_bus_generators"]   = _check_source_bus_generators(net, findings)
    result["topological_risk"]        = _check_topological_risk(net, findings)
    result["tpia_status"]           = "not_run"   # stub for future TPIA module

    result
end

function _check_generation_adequacy(net::Dict{String,Any},
                                     findings::Vector{Finding})::Dict{String,Any}
    total_p_load = sum(
        sum(Float64.(get(l, "p_nom", Float64[])))
        for (_, l) in get(net, "load", Dict());
        init=0.0
    )
    total_p_cap = sum(
        sum(Float64.(get(g, "p_max", Float64[])))
        for (_, g) in get(net, "generator", Dict());
        init=0.0
    )
    # IBRs contribute local active-power capacity too (STATCOM-type IBRs are
    # reactive-only and excluded — see `_ibr_active_capacity`).
    total_ibr_cap = _ibr_active_capacity(net)
    total_cap = total_p_cap + total_ibr_cap
    ratio = total_p_load > 0 ? total_cap / total_p_load : nothing

    Dict{String,Any}(
        "total_load_w"      => total_p_load,
        "total_gen_cap_w"   => total_p_cap,
        "total_ibr_cap_w"   => total_ibr_cap,
        "adequacy_ratio"    => ratio,
        "import_dependent"  => ratio === nothing || ratio < 0.5
    )
end

function _check_voltage_bounds(net::Dict{String,Any},
                                findings::Vector{Finding})::Dict{String,Any}
    buses = get(net, "bus", Dict())
    no_bounds = String[]

    for (id, b) in buses
        haskey(b, "v_min") || haskey(b, "v_max") || push!(no_bounds, id)
    end

    n_with_lower = count(b -> haskey(b, "v_min"), values(buses))
    n_with_upper = count(b -> haskey(b, "v_max"), values(buses))

    if !isempty(no_bounds)
        push!(findings, Finding(INFO, "I.PRE.NO_VOLT_BOUNDS", :preflight, :bus, nothing,
            "$(length(no_bounds)) bus(es) have no voltage bounds — voltage will be unconstrained at these buses.",
            Dict{String,Any}("buses" => no_bounds)))
    end

    Dict{String,Any}(
        "n_buses"              => length(buses),
        "n_with_lower_bound"   => n_with_lower,
        "n_with_upper_bound"   => n_with_upper,
        "n_without_bounds"     => length(no_bounds),
        "buses_without_bounds" => no_bounds
    )
end

function _check_constraint_conflicts(net::Dict{String,Any},
                                      findings::Vector{Finding})::Dict{String,Any}
    conflicts = Dict{String,Any}[]

    # scalar-or-vector elementwise lower > upper test
    _bounds_conflict(lo, hi) = begin
        lov = lo isa AbstractVector ? Float64.(lo) : [Float64(lo)]
        hiv = hi isa AbstractVector ? Float64.(hi) : [Float64(hi)]
        m = min(length(lov), length(hiv))
        any(lov[i] > hiv[i] for i in 1:m)
    end

    # bus voltage bound pairs: phase-to-ground, phase-to-neutral,
    # phase-to-phase, sequence
    for (id, b) in get(net, "bus", Dict())
        for (lo_k, hi_k) in (("v_min", "v_max"), ("vpn_min", "vpn_max"),
                              ("vpp_min", "vpp_max"), ("vpos_min", "vpos_max"))
            lo = get(b, lo_k, nothing)
            hi = get(b, hi_k, nothing)
            (lo === nothing || hi === nothing) && continue
            if _bounds_conflict(lo, hi)
                push!(conflicts, Dict{String,Any}(
                    "type" => "$lo_k > $hi_k", "component" => "bus", "id" => id,
                    lo_k => lo, hi_k => hi))
                push!(findings, Finding(ERROR, "E.PRE.VBOUND_CONFLICT", :preflight, :bus, id,
                    "Bus '$id': $lo_k > $hi_k — infeasible voltage bounds.",
                    Dict{String,Any}(lo_k => lo, hi_k => hi)))
            end
        end
    end

    # generator power bound pairs
    for (id, g) in get(net, "generator", Dict())
        for (lo_k, hi_k, code, label) in
                (("p_min", "p_max", "E.PRE.PBOUND_CONFLICT", "active"),
                 ("q_min", "q_max", "E.PRE.QBOUND_CONFLICT", "reactive"))
            lo = get(g, lo_k, nothing)
            hi = get(g, hi_k, nothing)
            (lo === nothing || hi === nothing) && continue
            if _bounds_conflict(lo, hi)
                push!(conflicts, Dict{String,Any}(
                    "type" => "$lo_k > $hi_k", "component" => "generator", "id" => id))
                push!(findings, Finding(ERROR, code, :preflight, :generator, id,
                    "Generator '$id': $lo_k > $hi_k — infeasible $label power bounds.",
                    Dict{String,Any}(lo_k => lo, hi_k => hi)))
            end
        end
    end

    Dict{String,Any}(
        "n_conflicts" => length(conflicts),
        "conflicts"   => conflicts
    )
end

function _check_source_setpoints(net::Dict{String,Any},
                                  findings::Vector{Finding})::Dict{String,Any}
    # Voltage source v_magnitude values are pinned as hard equality constraints
    # in the OPF. If they fall outside a bus's declared v_min/v_max the bound
    # is trivially violated before the solver starts — a guaranteed infeasibility.
    # Also flag sources whose setpoints disagree with each other (multi-terminal
    # sources with inconsistent magnitudes per phase are unusual but not forbidden).
    n_oob = 0
    violations = Dict{String,Any}[]

    for (sid, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        bid = get(vs, "bus", nothing)
        bid isa AbstractString || continue
        bus = get(get(net, "bus", Dict()), bid, nothing)
        bus isa Dict || continue

        vm_arr = get(vs, "v_magnitude", nothing)
        vm_arr === nothing && continue
        vms = vm_arr isa AbstractVector ? Float64.(vm_arr) : [Float64(vm_arr)]
        isempty(vms) && continue

        v_min = get(bus, "v_min", nothing)
        v_max = get(bus, "v_max", nothing)
        v_min === nothing && v_max === nothing && continue

        # v_min/v_max are per-phase arrays (phase-to-ground); the source phase
        # index k aligns with the bus phase order. Look up the k-th entry.
        for (k, vm) in enumerate(vms)
            isfinite(vm) || continue
            lb = v_min isa AbstractVector ? get(v_min, k, nothing) : v_min
            ub = v_max isa AbstractVector ? get(v_max, k, nothing) : v_max
            lo_viol = lb !== nothing && vm < Float64(lb)
            hi_viol = ub !== nothing && vm > Float64(ub)
            if lo_viol || hi_viol
                n_oob += 1
                bound = lo_viol ? "below v_min=$(Float64(lb)) V" :
                                  "above v_max=$(Float64(ub)) V"
                push!(violations, Dict{String,Any}(
                    "source" => sid, "bus" => bid, "phase" => k,
                    "vm" => vm, "v_min" => lb, "v_max" => ub))
                push!(findings, Finding(WARNING, "W.PRE.SOURCE_VOLTAGE_OOB",
                    :preflight, :voltage_source, sid,
                    "Voltage source '$sid' phase $k: setpoint vm=$(round(vm; digits=2)) V " *
                    "is $bound on bus '$bid'. The source pins this voltage as a hard " *
                    "equality — the bus voltage bound is trivially violated before " *
                    "the OPF starts.",
                    Dict{String,Any}("source"=>sid,"bus"=>bid,"phase"=>k,
                                     "vm"=>vm,"v_min"=>lb,"v_max"=>ub)))
            end
        end
    end

    Dict{String,Any}("n_source_oob" => n_oob, "violations" => violations)
end

function _check_source_bus_generators(net::Dict{String,Any},
                                       findings::Vector{Finding})::Dict{String,Any}
    # The voltage source is the network's current slack (see ext/BMOPFOpfExt/source.jl):
    # it fixes the bus voltage and injects a free slack current. An independent
    # generator placed at the same bus therefore sits on a fixed-voltage node and
    # competes with the source's slack injection:
    #   • unbounded (no p_max/q_max) → two free current sources at one fixed-voltage
    #     bus → degenerate split (primal non-uniqueness). Its role should instead be
    #     expressed as bounds/cost on the voltage source.
    #   • bounded → well-posed, but the generator's limits/cost may be intended as
    #     the source's import limits/price; advise modelling them on the source.
    source_buses = Set{String}()
    for (_, vs) in get(net, "voltage_source", Dict())
        vs isa Dict || continue
        b = get(vs, "bus", nothing)
        b isa AbstractString && push!(source_buses, b)
    end

    n_unbounded = 0
    n_bounded   = 0
    flagged     = Dict{String,Any}[]

    for (gid, g) in get(net, "generator", Dict())
        g isa Dict || continue
        bus = get(g, "bus", nothing)
        (bus isa AbstractString && bus in source_buses) || continue

        has_p_max = !isempty(Float64.(get(g, "p_max", Float64[])))
        has_q_max = !isempty(Float64.(get(g, "q_max", Float64[])))
        unbounded = !(has_p_max && has_q_max)

        push!(flagged, Dict{String,Any}("generator"=>gid, "bus"=>bus,
                                        "unbounded"=>unbounded))

        if unbounded
            n_unbounded += 1
            push!(findings, Finding(WARNING, "W.PRE.SOURCE_BUS_GENERATOR",
                :preflight, :generator, gid,
                "Generator '$gid' is at voltage-source bus '$bus' and lacks " *
                "p_max/q_max bounds. The voltage source is the network's current " *
                "slack, so two unbounded current injections share one fixed-voltage " *
                "bus — the dispatch split is degenerate (non-unique). Remove this " *
                "generator and express its role as flow bounds/cost on the voltage " *
                "source instead.",
                Dict{String,Any}("generator"=>gid, "bus"=>bus)))
        else
            n_bounded += 1
            push!(findings, Finding(INFO, "I.PRE.SOURCE_BUS_GENERATOR",
                :preflight, :generator, gid,
                "Generator '$gid' is at voltage-source bus '$bus'. This is " *
                "well-posed (the generator is bounded, the source takes the " *
                "remainder), but if its bounds/cost are meant to limit or price " *
                "grid import, set them on the voltage source (p_min/p_max/q_min/" *
                "q_max/cost) instead.",
                Dict{String,Any}("generator"=>gid, "bus"=>bus)))
        end
    end

    Dict{String,Any}(
        "n_source_bus_generators"           => n_unbounded + n_bounded,
        "n_unbounded_source_bus_generators" => n_unbounded,
        "n_bounded_source_bus_generators"   => n_bounded,
        "generators"                        => flagged,
    )
end

function _check_topological_risk(net::Dict{String,Any},
                                   findings::Vector{Finding})::Dict{String,Any}
    n_vsrc  = length(get(net, "voltage_source", Dict()))
    n_sw    = length(get(net, "switch", Dict()))
    n_open  = count(sw -> get(sw, "open_switch", false), values(get(net, "switch", Dict())))

    spof = n_vsrc <= 1
    if spof
        push!(findings, Finding(INFO, "I.PRE.SINGLE_SOURCE", :preflight, :network, nothing,
            "Network has a single voltage source — single point of failure. " *
            "Infeasibility of the source makes the entire network infeasible.",
            nothing))
    end

    Dict{String,Any}(
        "n_voltage_sources"     => n_vsrc,
        "single_point_of_failure" => spof,
        "n_switches"            => n_sw,
        "n_open_switches"       => n_open,
        "n_closed_switches"     => n_sw - n_open
    )
end
