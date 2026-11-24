# Linecode-use context for provenance interpretations. Review guidance itself
# lives in `analysis/finding_interpretation.jl`. PSK-000008 / PSK-000009 remain
# links to scientific scope, not prerequisites for exploratory feedback.

# A converter-generated source (Thevenin) equivalent is not authored line data;
# provenance hints about it would only be noise. Identified by explicit metadata.
_is_source_equivalent_linecode(lc) = lc isa AbstractDict &&
    occursin(r"thevenin|source impedance"i, string(get(lc, "source", "")))

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
                "n_mv_hv_lines" => 0, "mv_hv_line_ids" => String[],
                "n_lv_with_neutral_lines" => 0, "lv_with_neutral_line_ids" => String[],
                "n_unassessed_lines" => 0, "unassessed_line_ids" => String[],
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
        mv_hv = all(endpoints) do bus
            v = get(voltages, bus, nothing)
            v isa Real && !(v isa Bool) && isfinite(v) && v >= 1000
        end
        unambiguous = !any(k -> startswith(k, "R_series_") || startswith(k, "X_series_"), keys(line))
        supported = phase_only && lv && unambiguous && all(b -> !(b in carried), endpoints)
        context[supported ? "n_lv_without_neutral_lines" : "n_other_or_unassessed_lines"] += 1
        ids = context[supported ? "lv_without_neutral_line_ids" : "other_or_unassessed_line_ids"]
        length(ids) < context["witness_limit"] && push!(ids, id)
        if !supported
            kind = phase_only && unambiguous && mv_hv ? "mv_hv" :
                phase_only && unambiguous && lv ? "lv_with_neutral" : "unassessed"
            context["n_$(kind)_lines"] += 1
            ids = context["$(kind)_line_ids"]
            length(ids) < context["witness_limit"] && push!(ids, id)
        end
    end
    for context in values(contexts)
        context["witnesses_truncated"] = context["n_lines"] > length(context["line_ids"])
    end
    contexts
end
