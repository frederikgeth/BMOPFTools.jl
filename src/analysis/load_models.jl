# analysis/load_models.jl
#
# Characterization of voltage-dependent load models (ZIP / exponential) and
# flags relevant to OPF formulation quality:
#   - exponential loads whose exponents are all integer {0,1,2} can be
#     represented losslessly as ZIP, keeping the OPF quadratic;
#   - voltage-dependent loads on buses without a lower voltage magnitude bound
#     leave the squared-voltage variable without an engineering floor.
#
# Shared load-model helpers (_n_subloads, _as_vec, model predicates) live here
# because both the validation layer and the OPF extension consume them.

# Number of sub-loads (independent single-phase primitives) for a load:
# DELTA → one per terminal; WYE/SINGLE_PHASE → one per phase conductor.
function _n_subloads(load)
    tm  = Vector{String}(get(load, "terminal_map", String[]))
    cfg = get(load, "configuration", "WYE")
    cfg == "DELTA" ? length(tm) : length(_phase_positions(tm))
end

# Broadcast a scalar/length-1/length-n coefficient to a length-n vector; `nothing`
# if absent, or if the length is neither 1 nor n.
function _as_vec(c, n)
    c === nothing && return nothing
    v = c isa AbstractVector ? Float64.(c) : [Float64(c)]
    length(v) == 1 ? fill(v[1], n) : (length(v) == n ? v : nothing)
end

# Is this load voltage-dependent (i.e. not equivalent to constant power)?
function _load_is_voltage_dependent(load)
    model = get(load, "model", "constant_power")
    model in ("constant_current", "constant_impedance") && return true
    n = _n_subloads(load)
    if model == "zip"
        for k in ("alpha_z", "alpha_i", "beta_z", "beta_i")
            v = _as_vec(get(load, k, nothing), n)
            v !== nothing && any(!iszero, v) && return true
        end
        return false
    elseif model == "exponential"
        for g in ("gamma_p", "gamma_q")
            v = _as_vec(get(load, g, nothing), n)
            v !== nothing && any(!iszero, v) && return true
        end
        return false
    end
    return false
end

# Does an exponential load reduce losslessly to ZIP (all exponents ∈ {0,1,2})?
function _exp_is_zip_equivalent(load)
    get(load, "model", "constant_power") == "exponential" || return false
    n = _n_subloads(load)
    for g in ("gamma_p", "gamma_q")
        v = _as_vec(get(load, g, nothing), n)
        v === nothing && continue
        all(x -> x in (0.0, 1.0, 2.0), v) || return false
    end
    return true
end

# Any lower voltage magnitude bound on the bus the load can lean on?
_bus_has_lower_voltage_bound(bus) =
    haskey(bus, "v_min") || haskey(bus, "vpn_min") || haskey(bus, "vpp_min")

"""
    load_model_analysis(net, findings) -> Dict{String,Any}

Summarize load voltage-dependence and emit OPF-formulation flags:

- `I.LOAD.EXP_ZIP_EQUIVALENT` — exponential loads with only integer exponents
  {0,1,2}; these can be represented as ZIP, keeping the OPF quadratic.
- `W.LOAD.NL_NO_VMIN` — voltage-dependent loads on buses without any lower
  voltage magnitude bound; the OPF squared-voltage variable then relies on a
  default floor rather than an engineering bound.
"""
function load_model_analysis(net::Dict{String,Any},
                             findings::Vector{Finding})::Dict{String,Any}
    by_model = Dict("constant_power" => 0, "constant_current" => 0,
                    "constant_impedance" => 0, "zip" => 0, "exponential" => 0)
    n_vd          = 0
    zip_equiv     = String[]
    nl_no_vmin    = String[]
    buses = get(net, "bus", Dict())

    for (id, l) in get(net, "load", Dict())
        l isa Dict || continue
        m = get(l, "model", "constant_power")
        haskey(by_model, m) && (by_model[m] += 1)

        _load_is_voltage_dependent(l) || continue
        n_vd += 1

        m == "exponential" && _exp_is_zip_equivalent(l) && push!(zip_equiv, id)

        bus = get(buses, get(l, "bus", ""), nothing)
        bus isa Dict && !_bus_has_lower_voltage_bound(bus) && push!(nl_no_vmin, id)
    end

    if !isempty(zip_equiv)
        push!(findings, Finding(INFO, "I.LOAD.EXP_ZIP_EQUIVALENT", :load_models,
            :load, nothing,
            "$(length(zip_equiv)) exponential load(s) use only integer exponents " *
            "{0,1,2} and can be represented losslessly as ZIP (keeping the OPF " *
            "quadratic): $(join(sort(zip_equiv), ", ")).",
            Dict{String,Any}("loads" => sort(zip_equiv))))
    end

    if !isempty(nl_no_vmin)
        push!(findings, Finding(WARNING, "W.LOAD.NL_NO_VMIN", :load_models,
            :load, nothing,
            "$(length(nl_no_vmin)) voltage-dependent load(s) sit on buses without " *
            "a lower voltage magnitude bound (v_min/vpn_min/vpp_min); the OPF " *
            "squared-voltage variable will use a default floor rather than an " *
            "engineering bound: $(join(sort(nl_no_vmin), ", ")).",
            Dict{String,Any}("loads" => sort(nl_no_vmin))))
    end

    Dict{String,Any}(
        "by_model"            => by_model,
        "n_voltage_dependent" => n_vd,
        "zip_equivalent"      => sort(zip_equiv),
        "nonlinear_no_vmin"   => sort(nl_no_vmin),
    )
end
