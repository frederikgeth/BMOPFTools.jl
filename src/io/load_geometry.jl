# Runtime DELTA geometry shares the terminal-role domain of the validator
# (PSK-000002). Reject invalid maps; never silently discard a neutral terminal.
function _delta_load_coils(load, net; id="<anonymous>")
    tm = get(load, "terminal_map", nothing)
    fail(message) = throw(ArgumentError("Load '$id': $message"))
    _index_strings(tm) && length(tm) in (2, 3) ||
        fail("DELTA requires two or three phase terminals.")
    length(unique(tm)) == length(tm) || fail("DELTA terminals must be distinct.")
    ctx = _device_index_context(net, "load", id, load)
    ctx.evidence["reason"] === nothing ||
        fail("DELTA terminal roles are unresolved: $(ctx.evidence["reason"]).")
    all(==("phase"), ctx.evidence["resolved_roles"]) ||
        fail("DELTA requires phase terminals only; neutral and earth are not coil endpoints.")
    pairs = length(tm) == 2 ? [(tm[1], tm[2])] :
        [(tm[k], tm[mod1(k+1, 3)]) for k in 1:3]
    n = length(pairs)
    p = get(load, "p_nom", nothing); q = get(load, "q_nom", nothing)
    p isa AbstractVector && q isa AbstractVector && length(p) == length(q) == n ||
        fail("p_nom and q_nom must cover all $n coils.")
    all(v -> v isa Real && !(v isa Bool) && isfinite(v), p) &&
        all(v -> v isa Real && !(v isa Bool) && isfinite(v), q) ||
        fail("nominal powers must be finite real numbers.")
    pairs
end

function _validate_delta_loads(net)
    for (id, load) in get(net, "load", Dict())
        uppercase(string(get(load, "configuration", "WYE"))) == "DELTA" || continue
        _delta_load_coils(load, net; id)
    end
    nothing
end
