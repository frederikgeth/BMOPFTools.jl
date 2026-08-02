module MockOpfExtension

using BMOPFTools
using JuMP

const OWNER = :MockOpfExtension

"A deliberately small downstream IBR formulation using only public APIs."
function build_fixed_power_ibrs!(ctx, ids)
    model = opf_model(ctx)
    net = opf_network(ctx)
    state = extension_state!(ctx, OWNER)
    powers = get!(state, :powers,
                  Dict{String,Tuple{OpfModelKey,OpfModelKey}}())

    for id in ids
        inv = net["ibr"][id]
        bus = String(inv["bus"])
        terminals = String.(inv["terminal_map"])
        get(inv, "topology", "") == "SINGLE_PHASE" ||
            throw(ArgumentError("mock builder supports SINGLE_PHASE IBRs only"))
        length(terminals) == 2 ||
            throw(ArgumentError("mock SINGLE_PHASE IBR '$id' needs two terminals"))
        phase, reference = terminals

        vr_phase = opf_object(ctx, opf_bus_voltage_key(bus, phase))
        vi_phase = opf_object(ctx,
            opf_bus_voltage_key(bus, phase; component=:imag))
        vr_ref = opf_object(ctx, opf_bus_voltage_key(bus, reference))
        vi_ref = opf_object(ctx,
            opf_bus_voltage_key(bus, reference; component=:imag))
        cr = opf_object(ctx, opf_ibr_current_key(id, 1))
        ci = opf_object(ctx, opf_ibr_current_key(id, 1; component=:imag))

        dvr = JuMP.@expression(model, vr_phase - vr_ref)
        dvi = JuMP.@expression(model, vi_phase - vi_ref)
        p = JuMP.@expression(model, dvr * cr + dvi * ci)
        q = JuMP.@expression(model, dvi * cr - dvr * ci)
        p_target = opf_coefficient(ctx,
            OpfCoefficientKey(:setpoint, :ibr, id, :active_power, 1),
            Float64(inv["p_max"][1]))
        p_constraint = JuMP.@constraint(model, p == p_target)
        q_constraint = JuMP.@constraint(model, q == 0.0)

        p_key = OpfModelKey(:expression, :mock_ibr_active_power, id)
        q_key = OpfModelKey(:expression, :mock_ibr_reactive_power, id)
        register_opf_object!(ctx, p_key, p)
        register_opf_object!(ctx, q_key, q)
        register_opf_object!(ctx,
            OpfModelKey(:constraint, :mock_ibr_active_power, id), p_constraint)
        register_opf_object!(ctx,
            OpfModelKey(:constraint, :mock_ibr_reactive_power, id), q_constraint)

        add_terminal_injection!(ctx, bus, phase, cr, ci)
        add_terminal_injection!(ctx, bus, reference, -cr, -ci)
        powers[id] = (p_key, q_key)
    end

    if !get(state, :extractor_registered, false)
        register_opf_result_extractor!(ctx, OWNER, extract_mock_results!)
        state[:extractor_registered] = true
    end
    return ctx
end

function extract_mock_results!(ctx, result)
    state = extension_state!(ctx, OWNER)
    s_base = opf_bases(ctx) === nothing ? 1.0 : opf_bases(ctx).s_base
    mock = Dict{String,Any}()
    for id in sort!(collect(keys(state[:powers])))
        p_key, q_key = state[:powers][id]
        p_si = opf_primal(ctx, p_key) * s_base
        q_si = opf_primal(ctx, q_key) * s_base
        mock[id] = Dict{String,Any}("p" => p_si, "q" => q_si)
    end
    result["mock_ibr"] = mock
    return result
end

builder() = OpfDeviceBuilder(OWNER, build_fixed_power_ibrs!)

end # module MockOpfExtension
