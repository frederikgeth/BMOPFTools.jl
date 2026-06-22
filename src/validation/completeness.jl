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
    "switch"         => ["bus_from", "bus_to", "terminal_map_from", "terminal_map_to",
                         "open_switch"],
    "linecode"       => ["R_series_1_1", "X_series_1_1"],
    "inverter"       => ["bus", "terminal_map", "topology", "prime_mover", "s_max"],
    # control_profile sub-objects are all optional; presence activates a control law
    "control_profile" => String[]
)

# Required fields for all transformer subtypes
const _REQUIRED_TRANSFORMER_FIELDS = ["bus_from", "bus_to",
                                      "terminal_map_from", "terminal_map_to",
                                      "v_ref_from", "v_ref_to", "s_rating"]

const _OPTIONAL_FIELDS = Dict{String,Vector{String}}(
    "bus"  => ["v_min", "v_max", "vpn_min", "vpn_max", "vpp_min", "vpp_max",
               "vpos_min", "vpos_max", "perfectly_grounded_terminals"],
    "line" => ["i_max", "s_max"],
    "load" => [],
    "generator" => ["p_min", "p_max", "q_min", "q_max"],
    "switch"    => ["i_max"],
    "linecode"  => ["i_max", "s_max"],
    "inverter"  => ["p_avail", "p_min", "p_max", "q_min", "q_max",
                    "r_filter", "x_filter", "b_filter_shunt",
                    "grid_forming", "v_ref_internal", "cost", "control_profile",
                    "voltage_ref"],
    "control_profile" => ["volt_var", "volt_watt", "power_factor"]
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
                missing = [f for f in _REQUIRED_TRANSFORMER_FIELDS if !haskey(comp, f)]
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
