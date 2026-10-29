# Package-local interpretation of profiler observations. PSK-000008 / PSK-000009
# remain links to scientific scope, not prerequisites for exploratory feedback.
# These records offer hypotheses and review steps, never an inferred repair.
function _provenance_interpretation(code, observations; supporting_context=Dict{String,Any}())
    explanations, alternatives, checks = if code == "I.PROV.SEQ_DERIVED"
        (Dict("sequence_parameterisation" => "Phase impedances constructed from sequence parameters.",
              "transposition_assumption" => "A transposition or phase-symmetry assumption."),
         Dict("symmetric_construction" => "A physically symmetric conductor arrangement can also give this pattern."),
         Dict("parameter_source" => "Compare with the source sequence values, conductor geometry or transposition specification.",
              "study_symmetry" => "Review network connections, loading and controls before using a positive-sequence-only model."))
    elseif code == "I.PROV.DECOUPLED_PHASES"
        (Dict("simplified_parameterisation" => "Mutual series coupling may have been omitted in a simplified phase model."),
         Dict("negligible_series_coupling" => "Coupling may simply be negligible at the classifier tolerance."),
         Dict("coordinate_basis" => "Check whether the supplied entries are in phase or sequence coordinates.",
              "other_coupling" => "Inspect shunts, devices and connections before treating whole-network phases as independent."))
    elseif code in ("I.PROV.IMPEDANCE_TRANSFORM_KR", "I.PROV.KRON_LIKELY")
        (Dict("kron_reduction" => "An explicit neutral may have been eliminated by Kron reduction."),
         Dict("native_three_wire" => "The original network may genuinely have no neutral conductor.",
              "other_equivalent" => "A phase-to-neutral transformation, another equivalent or incomplete data can also omit the neutral."),
         Dict("original_conductors" => "Inspect the original conductor model and transformation records.",
              "grounding_and_recovery" => "If neutral displacement or current matters, review grounding assumptions and recovery of eliminated quantities."))
    elseif code == "I.PROV.IMPEDANCE_TRANSFORM_PN"
        (Dict("phase_to_neutral" => "Neutral resistance may have been folded into phase-to-neutral impedances while reactance retains geometric variation."),
         Dict("other_parameterisation" => "Another parameterisation can share the same approximate matrix pattern."),
         Dict("transformation_record" => "Compare with the source four-wire impedances and the declared phase-to-neutral transformation.",
              "return_path" => "Review conductor sizes, grounding and the intended return-current model."))
    elseif code == "I.PROV.IMPEDANCE_TRANSFORM_MPN"
        (Dict("modified_phase_to_neutral" => "A phase-to-neutral equivalent may also have had its reactance symmetrised."),
         Dict("other_parameterisation" => "A symmetric physical or authored equivalent can share this pattern."),
         Dict("transformation_record" => "Compare with the source impedances and any resistance folding or reactance symmetrisation.",
              "asymmetry" => "Review whether the approximation retains the asymmetry needed for the study."))
    else
        error("No profiler interpretation registered for $code")
    end
    Dict{String,Any}(
        "observations" => observations,
        "possible_explanations" => explanations,
        "supporting_context" => supporting_context,
        "alternatives" => alternatives,
        "suggested_checks" => checks,
        "automation_guidance" => Dict{String,Any}(
            "disposition" => "review",
            "additional_evidence_required_for_model_changes" => true),
    )
end

# Context is tied to actual uses of a linecode, not to unused templates or a
# nominal voltage guessed from impedance. Preserve unknown/mixed uses explicitly.
function _linecode_use_context(net, voltage_levels)
    contexts = Dict{String,Any}()
    voltages = get(voltage_levels, "bus_voltage_map", Dict())
    buses = get(net, "bus", Dict())
    carried = _neutral_branch_buses(net)
    roles = _index_roles(net)
    for (id, line) in sort!(collect(get(net, "line", Dict())); by=first)
        line isa AbstractDict || continue
        lc = get(line, "linecode", nothing)
        lc isa String || continue
        context = get!(contexts, lc) do
            Dict{String,Any}("line_ids" => String[], "lv_without_neutral_line_ids" => String[],
                "other_or_unassessed_line_ids" => String[], "n_lines" => 0,
                "n_lv_without_neutral_lines" => 0, "n_other_or_unassessed_lines" => 0,
                "witness_limit" => 5)
        end
        context["n_lines"] += 1
        length(context["line_ids"]) < context["witness_limit"] && push!(context["line_ids"], id)
        endpoints = (get(line, "bus_from", nothing), get(line, "bus_to", nothing))
        maps = (get(line, "terminal_map_from", nothing), get(line, "terminal_map_to", nothing))
        phase_only = roles !== nothing && all(zip(endpoints, maps)) do (bus, tm)
            haskey(buses, bus) && _index_strings(tm) && length(tm) == 3 &&
                length(unique(tm)) == 3 && all(t -> t in roles.phase && t in get(buses[bus], "terminal_names", []), tm)
        end
        lv = all(endpoints) do bus
            v = get(voltages, bus, nothing)
            v isa Real && !(v isa Bool) && isfinite(v) && 0 < v < 1000
        end
        unambiguous = !any(k -> startswith(k, "R_series_") || startswith(k, "X_series_"), keys(line))
        supported = phase_only && lv && unambiguous && all(b -> !(b in carried), endpoints)
        context[supported ? "n_lv_without_neutral_lines" : "n_other_or_unassessed_lines"] += 1
        ids = context[supported ? "lv_without_neutral_line_ids" : "other_or_unassessed_line_ids"]
        length(ids) < context["witness_limit"] && push!(ids, id)
    end
    for context in values(contexts)
        context["witnesses_truncated"] = context["n_lines"] > length(context["line_ids"])
    end
    contexts
end
