# validation/completeness.jl

# Required fields per component type (mirrors JSON Schema `required` arrays)
const _REQUIRED_FIELDS = Dict{String,Vector{String}}(
    "bus"            => ["terminal_names"],
    "line"           => ["bus_from", "bus_to", "terminal_map_from", "terminal_map_to",
                         "length", "linecode"],
    "voltage_source" => ["bus", "terminal_map", "v_magnitude", "v_angle"],
    "load"           => ["bus", "terminal_map", "configuration", "p_nom", "q_nom"],
    "generator"      => ["bus", "terminal_map", "configuration", "cost"],
    "shunt"          => ["bus", "terminal_map", "G_1_1", "B_1_1"],
    "capacitor"      => ["bus", "terminal_map", "configuration", "q_rated", "v_rated"],
    "switch"         => ["bus_from", "bus_to", "terminal_map_from", "terminal_map_to",
                         "open_switch"],
    "linecode"       => ["R_series_1_1", "X_series_1_1"],
    "ibr"            => ["bus", "terminal_map", "topology", "prime_mover", "s_max"],
    # control_profile sub-objects are all optional; presence activates a control law
    "control_profile" => String[],
    # DC network objects
    "dc_bus"         => ["terminal_names"],
    "dc_branch"      => ["dc_bus_from", "dc_bus_to", "terminal_map_from",
                         "terminal_map_to", "r"],
    "dc_grounding"   => ["dc_bus", "terminal"],
    "dc_load"        => ["dc_bus", "terminal_map", "p"],
    "dc_source"      => ["dc_bus", "terminal_map"]
)

# Optional fields whose presence is worth tracking for coverage reporting.
const _OPTIONAL_DC_BUS_FIELDS = ["v_dc_min", "v_dc_max", "pole",
                                 "vdc_ln_min", "vdc_ln_max",
                                 "vdc_ll_min", "vdc_ll_max"]

# Required fields for the two-bus transformer subtypes
const _REQUIRED_TRANSFORMER_FIELDS = ["bus_from", "bus_to",
                                      "terminal_map_from", "terminal_map_to",
                                      "v_ref_from", "v_ref_to", "s_rating"]

# Required fields for an n_winding transformer per winding
const _REQUIRED_WINDING_FIELDS = ["bus", "terminal_map", "v_ref", "connection"]

"""
    _nwinding_missing_fields(comp) -> Vector{String}

Required-field check for an `n_winding` transformer: the top-level `windings`,
`x_sc`, `s_rating`, plus each winding's `bus`/`terminal_map`/`v_ref`/`connection`
and `x_sc` coverage of every winding pair. Returns human-readable missing-field
descriptions (empty when complete).
"""
function _nwinding_missing_fields(comp::Dict{String,Any})::Vector{String}
    missing = String[]
    for f in ("windings", "x_sc", "s_rating")
        haskey(comp, f) || push!(missing, f)
    end
    ws = get(comp, "windings", nothing)
    if ws isa AbstractVector
        length(ws) >= 2 || push!(missing, "windings (need >= 2)")
        for (k, w) in enumerate(ws)
            w isa AbstractDict || (push!(missing, "windings[$k] (not an object)"); continue)
            for f in _REQUIRED_WINDING_FIELDS
                haskey(w, f) || push!(missing, "windings[$k].$f")
            end
        end
        # x_sc must cover every winding pair i<j
        xsc = get(comp, "x_sc", nothing)
        if xsc isa AbstractDict
            n = length(ws)
            for i in 1:n, j in i+1:n
                haskey(xsc, "$(i)_$(j)") || push!(missing, "x_sc[$(i)_$(j)]")
            end
        end
    elseif haskey(comp, "windings")
        push!(missing, "windings (not a list)")
    end
    missing
end

const _OPTIONAL_FIELDS = Dict{String,Vector{String}}(
    "bus"  => ["v_min", "v_max", "vpn_min", "vpn_max", "vpp_min", "vpp_max",
               "vpos_min", "vpos_max", "perfectly_grounded_terminals"],
    "line" => ["i_max", "s_max"],
    "load" => [],
    "generator" => ["p_min", "p_max", "q_min", "q_max", "s_max", "i_max"],
    "switch"    => ["i_max"],
    "linecode"  => ["i_max", "s_max"],
    "ibr"       => ["i_max", "p_avail", "p_min", "p_max", "q_min", "q_max",
                    "r_filter", "x_filter", "b_filter_shunt",
                    "grid_forming", "v_ref_internal", "cost", "control_profile",
                    "voltage_ref", "dc_bus", "dc_terminal_map"],
    "control_profile" => ["volt_var", "volt_watt", "power_factor"],
    "dc_bus"    => _OPTIONAL_DC_BUS_FIELDS,
    "dc_branch" => ["i_max", "p_max"],
    "dc_grounding" => ["r"],
    "dc_source" => ["p", "p_min", "p_max"]
)

"""
    completeness_check(net, findings) -> Dict{String,Any}

Two-layer completeness check:
1. Hard: are all schema-required fields present?
2. Soft: which optional fields are absent across the dataset?
"""
function completeness_check(net::Dict{String,Any},
                             findings::Vector{Finding})::Dict{String,Any}
    result = Dict{String,Any}()

    for (comp_type, required) in _REQUIRED_FIELDS
        components = get(net, comp_type, nothing)
        components isa Dict || continue
        missing_per_comp = Dict{String,Vector{String}}()

        for (id, comp) in components
            comp isa Dict || continue
            missing = [f for f in required if !haskey(comp, f)]
            if !isempty(missing)
                missing_per_comp[id] = missing
                push!(findings, Finding(ERROR, "E.COMP.MISSING_REQUIRED",
                    :completeness, Symbol(comp_type), id,
                    "$comp_type '$id' is missing required field(s): $(join(missing, ", ")).",
                    Dict{String,Any}("missing" => missing)))
            end
        end

        # Soft: which optional fields are present across the category?
        optional = get(_OPTIONAL_FIELDS, comp_type, String[])
        opt_coverage = Dict{String,Int}()
        for f in optional
            opt_coverage[f] = count(comp -> haskey(comp, f),
                                    values(components))
        end

        result[comp_type] = Dict{String,Any}(
            "n_components"      => length(components),
            "n_with_missing"    => length(missing_per_comp),
            "optional_coverage" => opt_coverage
        )
    end

    # Transformer subtypes
    xfmr = get(net, "transformer", nothing)
    if xfmr isa Dict
        n_xfmr = 0
        n_xfmr_missing = 0
        for subtype in TRANSFORMER_SUBTYPES
            sub = get(xfmr, subtype, nothing)
            sub isa Dict || continue
            for (id, comp) in sub
                comp isa Dict || continue
                n_xfmr += 1
                missing = subtype == "n_winding" ?
                    _nwinding_missing_fields(comp) :
                    [f for f in _REQUIRED_TRANSFORMER_FIELDS if !haskey(comp, f)]
                if !isempty(missing)
                    n_xfmr_missing += 1
                    push!(findings, Finding(ERROR, "E.COMP.MISSING_REQUIRED",
                        :completeness, :transformer, id,
                        "transformer ($subtype) '$id' is missing required field(s): $(join(missing, ", ")).",
                        Dict{String,Any}("missing" => missing, "subtype" => subtype)))
                end
            end
        end
        result["transformer"] = Dict{String,Any}(
            "n_components"   => n_xfmr,
            "n_with_missing" => n_xfmr_missing
        )
    end

    result
end
