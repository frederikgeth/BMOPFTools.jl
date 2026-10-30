# Static declaration evidence; never a claim that a model was built or solved.
_profile_finite(x) = x isa Real && !(x isa Bool) && isfinite(x) && isfinite(Float64(x))
_profile_nonnegative(x) = _profile_finite(x) && x >= 0
_profile_square_scale(x) = _profile_finite(x) && x > 0 && isfinite(Float64(x)^2) && Float64(x)^2 > 0 &&
    isfinite(inv(Float64(x))^2) && inv(Float64(x))^2 > 0
_profile_cap(x) = _profile_nonnegative(x) && (iszero(x) || _profile_square_scale(x))
_profile_domain_state(reason) = startswith(reason, "unsupported_") ? "unsupported" : "malformed"
_profile_coverage_status(state) = state == "unsupported" ? "inapplicable" : state == "malformed" ? "indeterminate" : "assessed"
const _PROFILE_NW_TAP_KEYS = ("tap", "tap_min", "tap_max", "tap_ratio", "tap_ratio_min", "tap_ratio_max")

function _profile_port_map(net, w)
    w isa AbstractDict || return false
    bus = get(w, "bus", nothing); tm = get(w, "terminal_map", nothing)
    declared = get(get(get(net, "bus", Dict()), bus, Dict()), "terminal_names", [])
    tm isa AbstractVector && !isempty(tm) && all(t -> t isa AbstractString, tm) &&
        length(unique(tm)) == length(tm) && all(t -> t in declared, tm)
end

# Check the native winding-index/limit domain without importing the extension.
# Other transformer parameters and built-model numerical admission remain builder-owned.
function _profile_nw_domain(net, raw)
    raw isa AbstractVector && length(raw) >= 2 || return "invalid_winding_list"
    nph = Int[]
    for w in raw
        _profile_port_map(net, w) || return "invalid_winding_map"
        tm = lowercase.(w["terminal_map"])
        all(t -> t in ("a", "b", "c", "n"), tm) || return "unsupported_native_terminal_labels"
        n = count(t -> t in ("a", "b", "c"), tm)
        cfg = uppercase(string(get(w, "configuration", "WYE")))
        cfg in ("WYE", "DELTA") || return "unsupported_configuration"
        n > 0 && (cfg != "DELTA" || (n >= 2 && !("n" in tm))) || return "invalid_phase_count"
        any(haskey(w, k) for k in _PROFILE_NW_TAP_KEYS) && return "unsupported_tap_declaration"
        v = get(w, "v_nom", 1.0)
        _profile_square_scale(v) || return "invalid_nominal_voltage"
        push!(nph, n)
    end
    length(unique(nph)) == 1 || return "inconsistent_phase_count"
    nothing
end

function _winding_limit_coverage(net, findings)
    rows = Dict{String,Any}[]; devices = Dict{String,Any}[]
    transformers = get(net, "transformer", Dict())
    for subtype in sort!(collect(keys(transformers)))
        sub = transformers[subtype]
        sub isa AbstractDict || continue
        for id in sort!(collect(keys(sub)))
            xf = sub[id]
            raw = xf isa AbstractDict ? get(xf, "windings", nothing) : nothing
            reason = subtype == "n_winding" ? _profile_nw_domain(net, raw) : "unsupported_subtype"
            if subtype == "n_winding" && xf isa AbstractDict && any(haskey(xf, k) for k in _PROFILE_NW_TAP_KEYS)
                reason = "unsupported_tap_declaration"
            end
            first_row = length(rows) + 1
            if subtype == "n_winding" && raw isa AbstractVector
                for (k, w) in enumerate(raw)
                    caps = Dict{String,Any}()
                    for (field, kind) in (("i_max", "bare_coil_current"), ("s_max", "coil_apparent_power"))
                        present = w isa AbstractDict && haskey(w, field)
                        value = w isa AbstractDict ? get(w, field, nothing) : nothing
                        state = !present || value === nothing ? "absent" : value isa Real && value == Inf ? "unbounded" :
                            !_profile_cap(value) ? "malformed" : "present"
                        caps[field] = Dict{String,Any}("state" => state, "value" => value,
                            "field_path" => ["transformer", subtype, id, "windings", k, field],
                            "quantity" => kind, "supported" => reason === nothing && state == "present")
                    end
                    states = [caps[f]["state"] for f in ("i_max", "s_max")]
                    state = reason !== nothing ? _profile_domain_state(reason) : "malformed" in states ? "malformed" :
                        all(s -> s in ("absent", "unbounded"), states) ? "absent" : "present"
                    push!(rows, Dict{String,Any}("transformer" => id, "subtype" => subtype,
                        "winding" => k, "bus" => w isa AbstractDict ? get(w, "bus", nothing) : nothing,
                        "terminal_map" => w isa AbstractDict ? get(w, "terminal_map", nothing) : nothing,
                        "coverage" => state, "status" => _profile_coverage_status(state),
                        "reason" => reason === nothing && state == "malformed" ? "invalid_cap_declaration" : reason,
                        "limits" => caps, "direct_neutral_current" => reason !== nothing ? "unassessed" :
                            any(_is_convention_neutral, w["terminal_map"]) ? "unsupported" : "inapplicable",
                        "s_max_allocation" => "equal_share_per_phase_leg",
                        "i_max_excludes" => ["neutral_return_sum", "magnetizing_current"],
                        "nameplate_creates_caps" => false))
                end
            end
            own = rows[first_row:end]
            states = [r["coverage"] for r in own]
            coverage = reason !== nothing ? _profile_domain_state(reason) : "malformed" in states ? "malformed" :
                all(==("absent"), states) ? "absent" : all(==("present"), states) ? "present" : "partial"
            push!(devices, Dict{String,Any}("transformer" => id, "subtype" => subtype,
                "coverage" => coverage, "reason" => reason === nothing && coverage == "malformed" ? "invalid_cap_declaration" : reason,
                "status" => _profile_coverage_status(coverage),
                "s_rating" => xf isa AbstractDict ? get(xf, "s_rating", nothing) : nothing,
                "n_windings" => length(own)))
        end
    end
    counts = Dict(s => count(d -> d["coverage"] == s, devices)
        for s in ("absent", "partial", "present", "malformed", "unsupported"))
    absent = filter(r -> r["coverage"] == "absent", rows)
    if !isempty(absent)
        n_unbounded = count(r -> any(r["limits"][f]["state"] == "unbounded" for f in ("i_max", "s_max")), absent)
        unbounded_note = n_unbounded > 0 ? " $n_unbounded are explicitly unbounded (Inf)." : ""
        push!(findings, Finding(WARNING, "W.OPS.XFMR_UNCONSTRAINED", :operational, :transformer, nothing,
            "$(length(absent)) n-winding winding(s) have no finite `i_max` or `s_max`, so the OPF puts no thermal " *
            "limit on them; unlike two-winding subtypes, an n-winding `s_rating` is not a cap.$unbounded_note " *
            "Add per-winding caps unless this is intentional.",
            Dict{String,Any}("n_windings_without_caps" => length(absent), "transformer_counts" => counts,
                "witnesses" => absent[1:min(end, 5)], "witness_limit" => 5,
                "witnesses_truncated" => length(absent) > 5,
                "interpretation" => _finding_interpretation("W.OPS.XFMR_UNCONSTRAINED",
                    Dict{String,Any}("n_windings_without_caps" => length(absent),
                        "n_windings_with_unbounded_declarations" => n_unbounded,
                        "limit_state_counts" => Dict(f => Dict(s => count(r -> r["limits"][f]["state"] == s, absent)
                            for s in ("absent", "unbounded")) for f in ("i_max", "s_max")),
                        "transformers" => sort!(unique([r["transformer"] for r in absent])),
                        "s_rating_declared" => sort!(unique([d["transformer"] for d in devices
                            if d["coverage"] == "absent" && d["s_rating"] !== nothing])))))))
    end
    Dict{String,Any}("evidence" => "supported_declarations_not_built_constraints", "solver_run" => false,
        "transformers" => devices, "windings" => rows, "transformer_counts" => counts,
        "n_transformers" => length(devices), "n_windings" => length(rows),
        "n_windings_without_caps" => length(absent),
        "limit_counts" => Dict(f => Dict(s => count(r -> r["limits"][f]["state"] == s, rows)
            for s in ("absent", "present", "malformed", "unbounded")) for f in ("i_max", "s_max")),
        "direct_neutral_current" => "unsupported")
end
