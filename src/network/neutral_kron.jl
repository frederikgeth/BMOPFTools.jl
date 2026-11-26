# network/neutral_kron.jl
#
# Explicit-neutral (conductor) Kron reduction: a four-wire network with
# grounded neutrals becomes a three-wire one. Ported from PowerOptLab.jl
# (src/io/kron_reduction.jl, commit d1f217f0; same author and BSD-3 license).
# Not to be confused with `kron_reduce_buses`, which eliminates *buses*
# (network nodes) after an Opti-KRON assignment.
#
# This is deliberately a data-model transformation.  It does not depend on
# PowerModelsDistribution (or any other PMD package), and it does not inspect
# BMOPFTools' private implementation.  The only numerical operation is the
# Schur complement of the primitive series impedance matrix.

const _NK_AC_COMPONENTS = (
    "line", "load", "generator", "voltage_source", "shunt", "switch",
    "ibr", "capacitor",
)
const _NK_MATRIX_PREFIXES = (
    "R_series_", "X_series_", "G_from_", "G_to_", "B_from_", "B_to_",
    "G_", "B_",
)

"""Return a recursively independent copy of a BMOPF value."""
function _nk_copy(x)
    x isa AbstractDict && return Dict{String,Any}(string(k) => _nk_copy(v) for (k, v) in x)
    x isa AbstractVector && return Any[_nk_copy(v) for v in x]
    x
end

function _nk_input(input)
    if input isa AbstractString
        return parse_bmopf(String(input); from_string=true)
    elseif input isa AbstractDict
        return _nk_copy(input)
    end
    throw(ArgumentError("kron_reduce_neutrals expects a BMOPF JSON string or dictionary"))
end

function _nk_matrix(d::AbstractDict, prefix::String; label="matrix")
    vals = Dict{Tuple{Int,Int},Float64}()
    for k in keys(d)
        m = match(Regex("^" * prefix * "(\\d+)_(\\d+)" * raw"$"), string(k))
        m === nothing && continue
        ij = (parse(Int, m.captures[1]), parse(Int, m.captures[2])); v = d[k]
        v isa Real && !(v isa Bool) && isfinite(Float64(v)) ||
            throw(ArgumentError("$label $prefix matrix contains a non-finite/non-numeric entry at $ij"))
        vals[ij] = Float64(v)
    end
    isempty(vals) && return nothing
    n = maximum(max(i, j) for (i, j) in keys(vals))
    # BMOPF accepts full matrices, upper/lower triangular shorthand, and
    # diagonal-only data. Missing entries are zero and missing reciprocals are
    # filled from the available half. Full storage takes precedence exactly as
    # in BMOPFTools (the first key is retained even if a reciprocal key is also
    # present).
    for i in 1:n, j in i+1:n
        a, b = get(vals, (i,j), nothing), get(vals, (j,i), nothing)
        if a === nothing && b !== nothing; vals[(i,j)] = b
        elseif b === nothing && a !== nothing; vals[(j,i)] = a
        elseif a === nothing && b === nothing; vals[(i,j)] = 0.0; vals[(j,i)] = 0.0
        end
    end
    M = zeros(Float64, n, n)
    for i in 1:n, j in 1:n
        M[i,j] = get(vals, (i,j), 0.0)
    end
    M
end

function _nk_complex_matrix(d::AbstractDict, label)
    R = _nk_matrix(d, "R_series_"; label)
    X = _nk_matrix(d, "X_series_"; label)
    R === nothing && X === nothing && return nothing
    if R === nothing
        R = zeros(size(X))
    elseif X === nothing
        X = zeros(size(R))
    end
    size(R) == size(X) || throw(ArgumentError("$label R_series_ and X_series_ matrices have different dimensions"))
    complex.(R, X)
end

function _nk_schur(Z::AbstractMatrix, neutral::Int, label)
    1 <= neutral <= size(Z, 1) || throw(ArgumentError("$label neutral matrix position $neutral is outside the $(size(Z,1))×$(size(Z,2)) matrix"))
    keep = [i for i in axes(Z, 1) if i != neutral]
    isempty(keep) && throw(ArgumentError("$label has no phase conductors after removing its neutral"))
    zn = Z[neutral,neutral]
    scale = max(norm(Z, Inf), 1.0)
    isfinite(abs(zn)) && abs(zn) > 1e-12 * scale ||
        throw(ArgumentError("$label neutral self impedance is singular or near-singular"))
    try
        k = -(Z[neutral:neutral, neutral:neutral] \ Z[neutral:neutral, keep])
        all(isfinite, real.(k)) && all(isfinite, imag.(k)) && norm(k, Inf) < 1e12 ||
            throw(ArgumentError("$label neutral recovery K is non-finite or near-singular"))
        zred = Z[keep, keep] - Z[keep, neutral:neutral] * (-k)
        all(isfinite, real.(zred)) && all(isfinite, imag.(zred)) || throw(ArgumentError("non-finite reduced impedance"))
        norm(zred, Inf) > 1e-14 * scale || throw(ArgumentError("$label reduced impedance is singular/degenerate"))
        κ = cond(zred)
        isfinite(κ) && κ < 1e12 || throw(ArgumentError("$label reduced impedance is singular or near-singular"))
        zred
    catch err
        throw(ArgumentError("$label neutral Schur complement is singular; refusing Kron reduction ($(sprint(showerror, err)))"))
    end
end

function _nk_recovery(Z::AbstractMatrix, neutral::Int, keep)
    -(Z[neutral:neutral, neutral:neutral] \ Z[neutral:neutral, keep])[:]
end

function _nk_write_matrix!(d::AbstractDict, prefix::String, M::AbstractMatrix)
    for k in collect(keys(d))
        startswith(string(k), prefix) && delete!(d, k)
    end
    for i in axes(M, 1), j in axes(M, 2)
        d[prefix * string(i) * "_" * string(j)] = M[i, j]
    end
    d
end

function _nk_mark_linecode!(lc)
    # A reduced catalog no longer has the conductor order promised by the
    # original geometry, so do not leave a stale line_geometry back-reference.
    haskey(lc, "line_geometry") && delete!(lc, "line_geometry")
    deriv = get!(lc, "derivation", Dict{String,Any}())
    deriv isa AbstractDict || (deriv = Dict{String,Any}(); lc["derivation"] = deriv)
    deriv["kron_reduction"] = "explicit neutral Schur complement"
    # A geometry-derived catalog is no longer geometry-backed after its
    # conductor count changes. Keep the provenance truthful for validators.
    lc["source"] = "kron_reduction"
    lc
end

function _nk_drop_matrix_neutral!(d, neutral::Int, prefixes, label)
    for prefix in prefixes
        M = _nk_matrix(d, prefix; label)
        M === nothing && continue
        1 <= neutral <= size(M, 1) || throw(ArgumentError("$label $prefix matrix dimension does not contain neutral position $neutral"))
        keep = [i for i in axes(M, 1) if i != neutral]
        _nk_write_matrix!(d, prefix, M[keep, keep])
    end
end

function _nk_shunt_recovery(d, neutral::Int, prefixes, label)
    out = Dict{String,Any}()
    for prefix in prefixes
        M = _nk_matrix(d, prefix; label)
        M === nothing && continue
        keep = [i for i in axes(M,1) if i != neutral]
        out[prefix * "neutral_row"] = M[neutral,keep]
    end
    out
end

function _nk_neutral_map(net, override=nothing)
    buses = get(net, "bus", Dict{String,Any}())
    out = Dict{String,String}()
    roles = get(net, "terminal_conventions", nothing)
    declared = roles isa AbstractDict ? Set(string.(get(roles, "neutral", String[]))) : nothing
    override_map = override isa AbstractDict ? Dict(string(k)=>string(v) for (k,v) in override) : Dict{String,String}()
    override_label = override isa AbstractString ? String(override) : nothing
    for (id, b) in buses
        b isa AbstractDict || throw(ArgumentError("bus '$id' must be an object"))
        names = string.(get(b, "terminal_names", String[]))
        length(unique(names)) == length(names) || throw(ArgumentError("bus '$id' has duplicate terminal names; neutral role is ambiguous"))
        nt = haskey(override_map, String(id)) ? override_map[String(id)] :
             (override_label !== nothing ? override_label : nothing)
        if nt === nothing && declared !== nothing
            # A declared case-wide convention is authoritative, including
            # when a bus carries a stale/conflicting derived field.
            candidates = [t for t in names if t in declared]
            length(candidates) <= 1 || throw(ArgumentError("bus '$id' has multiple declared neutral labels $(candidates)"))
            nt = isempty(candidates) ? nothing : candidates[1]
        elseif nt === nothing
            nt0 = get(b, "neutral_terminal", nothing)
            nt = nt0 isa AbstractString ? String(nt0) : nothing
            if nt === nothing
                # BMOPF's documented fallback naming convention. Do not infer
                # a neutral from arbitrary labels or grounded phases.
                candidates = [t for t in names if lowercase(t) == "n"]
                length(candidates) <= 1 || throw(ArgumentError("bus '$id' has multiple conventional neutral labels $(candidates)"))
                nt = isempty(candidates) ? nothing : candidates[1]
            end
        end
        nt === nothing || (nt in names || throw(ArgumentError("bus '$id' declares neutral_terminal '$nt', not present in terminal_names")); out[String(id)] = nt)
    end
    out
end

function _nk_strip_map!(c, field::String, busid, neutrals, label; audit=nothing,
                        vector_fields=_NK_CONDUCTOR_VECTOR_FIELDS)
    haskey(c, field) || return false
    tm = string.(c[field])
    nt = get(neutrals, String(busid), nothing)
    nt === nothing && return false
    pos = findall(==(nt), tm)
    length(pos) <= 1 || throw(ArgumentError("$label has neutral '$nt' more than once in $field"))
    isempty(pos) && return false
    p = only(pos)
    cfg = uppercase(string(get(c, "configuration", "")))
    cfg == "DELTA" && throw(ArgumentError("$label is DELTA-connected but contains bus neutral '$nt'; connection semantics are ambiguous"))
    cfg == "WYE" && p != length(tm) && throw(ArgumentError("$label WYE neutral '$nt' is not the final terminal; refusing ambiguous phase ordering"))
    newtm = [tm[i] for i in eachindex(tm) if i != p]
    isempty(newtm) && throw(ArgumentError("$label has no phase terminals after removing neutral '$nt'"))
    # A reversed two-terminal phase-neutral source/load carries a sign that
    # cannot be represented by the one-terminal implicit-ground form.
    cfg == "SINGLE_PHASE" && p == 1 &&
        any(get(c, k, nothing) isa AbstractVector && any(x -> !iszero(x), get(c, k, Any[])) for k in ("p_nom", "q_nom")) &&
        throw(ArgumentError("$label has neutral first in an energized SINGLE_PHASE connection; orientation is not representable after reduction"))
    c[field] = newtm
    # Trim only explicitly conductor-indexed arrays. Arrays with a phase
    # meaning (p_nom/q_nom/cost and bounds) intentionally remain untouched.
    oldn = length(tm)
    old_imax = get(c, "i_max", nothing)
    keep = [i for i in eachindex(tm) if i != p]
    _nk_slice_conductor_vectors!(c, oldn, p, keep, label, audit; fields=vector_fields)
    if cfg == "SINGLE_PHASE" && old_imax isa AbstractVector && length(old_imax) == 2
        c["i_max"] = [min(Float64(old_imax[1]), Float64(old_imax[2]))]
        audit === nothing || push!(audit, Dict{String,Any}("component"=>label,
            "adapted_constraint"=>"i_max", "value"=>c["i_max"],
            "reason"=>"phase and return share one implicit-ground current"))
    end
    audit === nothing || push!(audit, Dict{String,Any}("component"=>label, "field"=>field, "bus"=>String(busid), "neutral"=>nt, "position"=>p))
    true
end

function _nk_preflight_ts!(c, label)
    ts = get(c, "time_series", nothing)
    ts isa AbstractDict || return
    bad = String[]
    for k in keys(ts)
        s = string(k)
        (s in ("terminal_names", "neutral_terminal", "perfectly_grounded_terminals", "terminal_map", "terminal_map_from", "terminal_map_to", "linecode", "length", "v_min", "v_max", "vpn_min", "vpn_max", "vn_max", "i_max", "i_max_from", "i_max_to") ||
         startswith(s, "R_series_") || startswith(s, "X_series_") || startswith(s, "G_") || startswith(s, "B_")) && push!(bad,s)
    end
    isempty(bad) || throw(ArgumentError("$label has time_series mappings to structural/matrix/bound fields $(bad); reduction is not proven to commute"))
end

# Only these fields are indexed by the terminal/conductor map.  Power and
# cost vectors are phase-semantic arrays even when their length happens to
# equal the number of terminals, so they must never be shortened by accident.
const _NK_CONDUCTOR_VECTOR_FIELDS = Set((
    "i_max", "i_max_from", "i_max_to", "s_max", "s_max_from", "s_max_to",
    "v_magnitude", "v_angle",
))
const _NK_RATING_FIELDS = Set(("i_max", "i_max_from", "i_max_to", "s_max", "s_max_from", "s_max_to"))
const _NK_COMPONENT_VECTOR_FIELDS = Dict{String,Set{String}}(
    "voltage_source" => Set(("v_magnitude", "v_angle")),
    "generator" => Set(("i_max", "s_max")),
    "ibr" => Set(("i_max", "s_max")),
    "switch" => _NK_RATING_FIELDS,
    "load" => Set{String}(),
    "shunt" => Set{String}(),
    "capacitor" => Set{String}(),
)

function _nk_slice_conductor_vectors!(c, oldn::Int, p::Int, keep, label, audit;
                                      fields=_NK_CONDUCTOR_VECTOR_FIELDS)
    for key in fields
        v = get(c, key, nothing)
        v isa AbstractVector || continue
        length(v) == oldn || continue             # phase-only or already sliced
        if key in ("i_max", "i_max_from", "i_max_to", "s_max", "s_max_from", "s_max_to")
            audit === nothing || push!(audit, Dict{String,Any}("component"=>label,
                "dropped_constraint"=>"$key[neutral]", "value"=>v[p],
                "reason"=>"neutral conductor is represented by implicit ground"))
        end
        c[key] = [v[i] for i in keep]
    end
end

function _nk_adapt_bus_bounds!(b, id, oldnames, nt, audit)
    p = nt === nothing ? nothing : findfirst(==(String(nt)), oldnames)
    p === nothing || begin
        # v_min/v_max are phase-to-ground arrays and therefore already exclude
        # the neutral.  Merge vpn bounds into them now that Vn=0 is implicit.
        for side in ("min", "max")
            gkey, nkey = "v_"*side, "vpn_"*side
            nv = get(b, nkey, nothing)
            nv === nothing && continue
            gv = get(b, gkey, nothing)
            if nv isa AbstractVector
                phase_n = length(oldnames) - 1
                length(nv) == phase_n || throw(ArgumentError("bus '$id' $nkey has $(length(nv)) entries; expected $phase_n phase entries"))
                if gv isa AbstractVector
                    length(gv) == length(oldnames) && (gv = [gv[i] for i in eachindex(oldnames) if i != p])
                    length(gv) == phase_n || throw(ArgumentError("bus '$id' $gkey has $(length(gv)) entries; expected $phase_n phase entries"))
                    b[gkey] = [side == "min" ? max(Float64(gv[i]), Float64(nv[i])) : min(Float64(gv[i]), Float64(nv[i])) for i in eachindex(nv)]
                elseif gv === nothing
                    b[gkey] = deepcopy(nv)
                else
                    g = Float64(gv)
                    b[gkey] = [side == "min" ? max(g, Float64(x)) : min(g, Float64(x)) for x in nv]
                end
            elseif gv !== nothing
                if gv isa AbstractVector
                    phase_n = length(oldnames) - 1
                    length(gv) == length(oldnames) &&
                        (gv = [gv[i] for i in eachindex(oldnames) if i != p])
                    length(gv) == phase_n || throw(ArgumentError(
                        "bus '$id' $gkey has $(length(gv)) entries; expected $phase_n phase entries"))
                    n = Float64(nv)
                    b[gkey] = [side == "min" ? max(Float64(x), n) : min(Float64(x), n)
                               for x in gv]
                else
                    g = Float64(gv)
                    b[gkey] = side == "min" ? max(g, Float64(nv)) : min(g, Float64(nv))
                end
            else
                b[gkey] = deepcopy(nv)
            end
            delete!(b, nkey)
            push!(audit, Dict{String,Any}("bus"=>String(id), "merged_bound"=>nkey, "into"=>gkey))
        end
        if haskey(b, "vn_max")
            delete!(b, "vn_max")
            push!(audit, Dict{String,Any}("bus"=>String(id), "dropped_bound"=>"vn_max", "reason"=>"neutral voltage is identically ground"))
        end
        if haskey(b, "v_min") && haskey(b, "v_max") && b["v_min"] isa AbstractVector && b["v_max"] isa AbstractVector
            any(Float64(b["v_min"][i]) > Float64(b["v_max"][i]) for i in eachindex(b["v_min"])) &&
                throw(ArgumentError("bus '$id' has contradictory voltage bounds after phase-to-neutral/ground intersection"))
        end
    end
end

function _nk_reduce_line_dict!(line, id, neutrals, linecodes, audit, reduced_linecodes=Set{String}())
    inline = any(startswith(string(k), "R_series_") || startswith(string(k), "X_series_") for k in keys(line))
    hasref = haskey(line, "linecode")
    inline && hasref && throw(ArgumentError("line '$id' has both inline impedance and a linecode reference"))
    tmf, tmt = string.(get(line, "terminal_map_from", String[])), string.(get(line, "terminal_map_to", String[]))
    pf = get(neutrals, String(get(line, "bus_from", "")), nothing)
    pt = get(neutrals, String(get(line, "bus_to", "")), nothing)
    nf = pf === nothing ? nothing : findfirst(==(pf), tmf)
    nt = pt === nothing ? nothing : findfirst(==(pt), tmt)
    (nf === nothing && nt === nothing) && return nothing
    ts = get(line, "time_series", nothing)
    if ts isa AbstractDict
        bad = [string(k) for k in keys(ts) if string(k) in ("linecode", "terminal_map_from", "terminal_map_to") || startswith(string(k), "R_series_") || startswith(string(k), "X_series_")]
        isempty(bad) || throw(ArgumentError("line '$id' has time-series structural/impedance fields $(bad); reduction is not proven to commute"))
    end
    (nf === nothing || nt === nothing) && throw(ArgumentError("line '$id' has an explicit neutral on only one end; refusing asymmetric reduction"))
    nf == nt || throw(ArgumentError("line '$id' has different neutral positions at its two ends ($nf and $nt)"))
    length(tmf) == length(tmt) || throw(ArgumentError("line '$id' terminal maps have different lengths"))
    Z = if inline
        _nk_complex_matrix(line, "line '$id'")
    else
        lcid = get(line, "linecode", nothing)
        lcid isa AbstractString || throw(ArgumentError("line '$id' references a non-string linecode"))
        lc = get(linecodes, lcid, nothing)
        lc isa AbstractDict || throw(ArgumentError("line '$id' references unknown linecode '$lcid'"))
        # The catalog pass may already have reduced this shared linecode. In
        # that case its 3×3 matrix is intentionally paired with the original
        # four-wire maps until this pass removes the neutral labels.
        if String(lcid) in reduced_linecodes
            keep = [i for i in eachindex(tmf) if i != nf]
            line["terminal_map_from"] = tmf[keep]
            line["terminal_map_to"] = tmt[keep]
            _nk_slice_conductor_vectors!(line, length(tmf), nf, keep, "line '$id'", audit; fields=_NK_RATING_FIELDS)
            d = get(lc, "derivation", Dict{String,Any}())
            push!(audit, Dict{String,Any}("line"=>String(id), "neutral_position"=>nf,
                                          "kept_positions"=>keep, "source"=>"reduced linecode",
                                          "source_linecode"=>String(lcid),
                                          "terminal_order_from"=>tmf, "terminal_order_to"=>tmt,
                                          "length"=>get(line,"length",nothing),
                                          "recovery_K_real"=>get(d,"kron_recovery_K_real",Any[]),
                                          "recovery_K_imag"=>get(d,"kron_recovery_K_imag",Any[]),
                                          "neutral_shunt_rows"=>get(d,"kron_neutral_shunt_rows",Dict{String,Any}())))
            return (String(lcid), nf, nothing, keep)
        end
        _nk_complex_matrix(lc, "linecode '$lcid'")
    end
    Z === nothing && throw(ArgumentError("line '$id' has a neutral terminal but no series impedance matrix"))
    size(Z, 1) == length(tmf) || throw(ArgumentError("line '$id' matrix dimension $(size(Z,1)) does not match terminal-map length $(length(tmf))"))
    Zr = _nk_schur(Z, nf, "line '$id'")
    keep = [i for i in axes(Z, 1) if i != nf]
    if inline
        shunt_recovery = _nk_shunt_recovery(line, nf, ("G_from_","G_to_","B_from_","B_to_"), "line '$id'")
        _nk_write_matrix!(line, "R_series_", real.(Zr)); _nk_write_matrix!(line, "X_series_", imag.(Zr))
        _nk_drop_matrix_neutral!(line, nf, ("G_from_","G_to_","B_from_","B_to_"), "line '$id'")
        _nk_slice_conductor_vectors!(line, length(tmf), nf, keep, "line '$id'", audit; fields=_NK_RATING_FIELDS)
    end
    line["terminal_map_from"] = tmf[keep]; line["terminal_map_to"] = tmt[keep]
    push!(audit, Dict{String,Any}("line"=>String(id), "neutral_position"=>nf, "kept_positions"=>keep,
                                 "terminal_order_from"=>tmf, "terminal_order_to"=>tmt,
                                 "recovery_K_real"=>real.(_nk_recovery(Z,nf,keep)),
                                 "recovery_K_imag"=>imag.(_nk_recovery(Z,nf,keep)),
                                 "neutral_shunt_rows"=>shunt_recovery,
                                 "source"=>(inline ? "inline" : "linecode")))
    (String(get(line, "linecode", "")), nf, Zr, keep)
end

function _nk_reduce_linecodes!(net, neutrals, audit)
    linecodes = get(net, "linecode", Dict{String,Any}())
    lines = get(net, "line", Dict{String,Any}())
    reduced = Set{String}()
    usages = Dict{String,Vector{Tuple{String,Int}}}()
    for (id, line) in lines
        line isa AbstractDict || continue
        haskey(line, "linecode") || continue
        tmf = string.(get(line, "terminal_map_from", String[])); tmt = string.(get(line, "terminal_map_to", String[]))
        pf = get(neutrals, String(get(line,"bus_from","")), nothing); pt = get(neutrals, String(get(line,"bus_to","")), nothing)
        nf = pf === nothing ? nothing : findfirst(==(pf), tmf); nt = pt === nothing ? nothing : findfirst(==(pt), tmt)
        nf === nothing && nt === nothing && continue
        nf == nt || throw(ArgumentError("line '$id' has different neutral positions at its two ends"))
        lcid = line["linecode"]
        lcid isa AbstractString || throw(ArgumentError("line '$id' references a non-string linecode"))
        push!(get!(usages, String(lcid), Tuple{String,Int}[]), (String(id), nf))
    end
    for (lcid, uses) in usages
        lc = get(linecodes, lcid, nothing)
        lc isa AbstractDict || throw(ArgumentError("linecode '$lcid' is missing or not an object"))
        poss = unique(last.(uses))
        if length(poss) == 1 && length(uses) == count(==(lcid), [String(get(l,"linecode","")) for l in values(lines) if l isa AbstractDict])
            p = only(poss); Z = _nk_complex_matrix(lc, "linecode '$lcid'")
            Z === nothing && throw(ArgumentError("linecode '$lcid' has no series impedance matrix"))
            Zr = _nk_schur(Z, p, "linecode '$lcid'"); keep = [i for i in axes(Z,1) if i != p]
            _nk_write_matrix!(lc, "R_series_", real.(Zr)); _nk_write_matrix!(lc, "X_series_", imag.(Zr))
            shunt_recovery = _nk_shunt_recovery(lc, p, ("G_from_","G_to_","B_from_","B_to_"), "linecode '$lcid'")
            _nk_drop_matrix_neutral!(lc, p, ("G_from_","G_to_","B_from_","B_to_"), "linecode '$lcid'")
            _nk_mark_linecode!(lc)
            lc["derivation"]["kron_recovery_K_real"] = real.(_nk_recovery(Z,p,keep))
            lc["derivation"]["kron_recovery_K_imag"] = imag.(_nk_recovery(Z,p,keep))
            lc["derivation"]["kron_neutral_shunt_rows"] = shunt_recovery
            _nk_slice_conductor_vectors!(lc, size(Z,1), p, keep, "linecode '$lcid'", audit; fields=_NK_RATING_FIELDS)
            push!(reduced, lcid)
            push!(audit, Dict{String,Any}("linecode"=>lcid, "neutral_position"=>p, "kept_positions"=>keep,
                                          "recovery_K_real"=>real.(_nk_recovery(Z,p,keep)),
                                          "recovery_K_imag"=>imag.(_nk_recovery(Z,p,keep)),
                                          "neutral_shunt_rows"=>shunt_recovery,
                                          "original_conductor_count"=>size(Z,1)))
        else
            # Shared catalog with mixed conductor conventions: clone per
            # position and redirect only the affected lines.
            for p in poss
                newid = lcid * "__kron" * string(p); j=1
                while haskey(linecodes, newid); j += 1; newid = lcid * "__kron" * string(p) * "_" * string(j); end
                clone = deepcopy(lc); Z = _nk_complex_matrix(clone, "linecode '$lcid'"); Z === nothing && throw(ArgumentError("linecode '$lcid' has no series impedance matrix"))
                Zr = _nk_schur(Z,p,"linecode '$lcid'"); keep=[i for i in axes(Z,1) if i != p]
                shunt_recovery = _nk_shunt_recovery(clone,p,("G_from_","G_to_","B_from_","B_to_"),"linecode '$lcid'")
                _nk_write_matrix!(clone,"R_series_",real.(Zr)); _nk_write_matrix!(clone,"X_series_",imag.(Zr)); _nk_drop_matrix_neutral!(clone,p,("G_from_","G_to_","B_from_","B_to_"),"linecode '$lcid'")
                _nk_mark_linecode!(clone)
                clone["derivation"]["kron_recovery_K_real"] = real.(_nk_recovery(Z,p,keep))
                clone["derivation"]["kron_recovery_K_imag"] = imag.(_nk_recovery(Z,p,keep))
                clone["derivation"]["kron_neutral_shunt_rows"] = shunt_recovery
                _nk_slice_conductor_vectors!(clone, size(Z,1), p, keep, "linecode '$newid'", audit; fields=_NK_RATING_FIELDS)
                push!(reduced, newid); linecodes[newid] = clone
                for (id,q) in uses
                    q == p && (lines[id]["linecode"] = newid)
                end
                push!(audit, Dict{String,Any}("linecode"=>newid,"source_linecode"=>lcid,"neutral_position"=>p,"kept_positions"=>keep,
                                              "recovery_K_real"=>real.(_nk_recovery(Z,p,keep)),
                                              "recovery_K_imag"=>imag.(_nk_recovery(Z,p,keep)),
                                              "neutral_shunt_rows"=>shunt_recovery,
                                              "original_conductor_count"=>size(Z,1)))
            end
        end
    end
    reduced
end

function _nk_transformers!(net, neutrals, audit)
    for (subtype, table) in get(net, "transformer", Dict())
        table isa AbstractDict || continue
        for (id, tx) in table
            tx isa AbstractDict || continue
            subtype_s = String(subtype)
            maps = if subtype_s == "n_winding"
                [(get(w,"terminal_map",String[]), get(w,"bus", "")) for w in get(tx,"windings",Any[]) if w isa AbstractDict]
            else
                [(get(tx,"terminal_map_from",String[]), get(tx,"bus_from", "")),
                 (get(tx,"terminal_map_to",String[]), get(tx,"bus_to", ""))]
            end
            for (map_index, (tm,bus)) in enumerate(maps)
                nt = get(neutrals,String(bus),nothing)
                nt === nothing && continue
                if nt in string.(tm) &&
                   ((subtype_s == "wye_delta" && map_index != 1) ||
                    (subtype_s == "delta_wye" && map_index != 2) ||
                    subtype_s == "delta_delta")
                    throw(ArgumentError("transformer '$id' subtype '$subtype_s' declares a neutral on a delta winding"))
                end
                if nt in string.(tm) && !(subtype_s in ("single_phase", "center_tap",
                        "single_phase_autotransformer", "wye_delta", "delta_wye",
                        "grounded_wye_wye"))
                    throw(ArgumentError("transformer '$id' subtype '$subtype_s' carries an explicit neutral; no supported reduced representation is available"))
                end
            end
            if String(subtype) == "n_winding"
                ws = get(tx, "windings", Any[])
                ws isa AbstractVector || throw(ArgumentError("transformer '$id' windings must be an array"))
            else
                for (side, map_key, bus_key, rn_key, xn_key) in (
                        ("from", "terminal_map_from", "bus_from", "r_neutral_from", "x_neutral_from"),
                        ("to", "terminal_map_to", "bus_to", "r_neutral_to", "x_neutral_to"))
                    tm = string.(get(tx, map_key, String[]))
                    bus = String(get(tx, bus_key, ""))
                    nt = get(neutrals, bus, nothing)
                    removed = nt !== nothing && nt in tm
                    _nk_strip_map!(tx, map_key, bus, neutrals,
                        "transformer '$id' $side"; audit,
                        vector_fields=Set(("i_max_$side", "s_max_$side")))
                    if removed
                        for key in (rn_key, xn_key)
                            haskey(tx, key) || continue
                            value = tx[key]
                            delete!(tx, key)
                            push!(audit, Dict{String,Any}(
                                "component"=>"transformer/$(subtype_s)/$(id)",
                                "dropped_grounding"=>key, "value"=>value,
                                "reason"=>"transformer neutral is merged with implicit ideal ground"))
                        end
                    end
                end
            end
        end
    end
end

function _nk_grounded_capacitor!(net, id, c, busid, nt, audit)
    tm = string.(get(c, "terminal_map", String[]))
    pos = findall(==(nt), tm)
    isempty(pos) && return false
    length(pos) == 1 || throw(ArgumentError("capacitor '$id' has repeated neutral terminal '$nt'"))
    uppercase(string(get(c, "configuration", ""))) == "DELTA" &&
        throw(ArgumentError("capacitor '$id' is DELTA-connected but contains neutral '$nt'"))
    haskey(c, "time_series") && throw(ArgumentError("capacitor '$id' has time-varying parameters; grounded-capacitor conversion is not proven to commute"))
    q = get(c, "q_rated", nothing); v = get(c, "v_nom", nothing)
    q isa AbstractVector && v isa Real && Float64(v) > 0 ||
        throw(ArgumentError("capacitor '$id' grounded conversion requires vector q_rated and positive scalar v_nom"))
    phases = [tm[i] for i in eachindex(tm) if i != only(pos)]
    isempty(phases) && throw(ArgumentError("capacitor '$id' has no phase terminal after neutral removal"))
    length(q) == length(phases) || throw(ArgumentError("capacitor '$id' q_rated length $(length(q)) does not match $(length(phases)) phases"))
    sh = get!(net, "shunt", Dict{String,Any}()); newid = "kron_grounded_cap_" * String(id); k=1
    while haskey(sh, newid); k += 1; newid = "kron_grounded_cap_" * String(id) * "_" * string(k); end
    s = Dict{String,Any}("bus"=>String(busid), "terminal_map"=>phases)
    for i in eachindex(phases), j in eachindex(phases)
        s["G_$(i)_$(j)"] = 0.0
        s["B_$(i)_$(j)"] = i == j ? Float64(q[i]) / Float64(v)^2 : 0.0
    end
    sh[newid] = s
    push!(audit, Dict{String,Any}("component"=>"capacitor/$(id)", "converted_to"=>"shunt/$(newid)",
                                  "reason"=>"grounded WYE/SINGLE_PHASE is represented as phase-to-ground shunt"))
    true
end

"""
    kron_reduce_neutrals(input; neutral_terminals=nothing, as_json=false,
                         include_coordinates=false) -> Dict or String

Explicit-neutral (conductor) Kron reduction: turn a four-wire BMOPF network
into a three-wire one by eliminating each bus's neutral terminal and holding
it at earth potential (V_n = 0). Not to be confused with
[`kron_reduce_buses`](@ref), which eliminates buses; see
[Network reduction](@ref network-reduction).

Line series matrices are reduced by the Schur complement
Z_abc = Z_pp − Z_pn Z_nn⁻¹ Z_np; π-shunt rows and conductor-indexed ratings
are projected by deletion; phase-to-neutral bus bounds are merged into
phase-to-earth bounds; neutral-only shunts and switches are removed and
grounded capacitors become phase-to-earth shunts. Every change, including the
neutral-current recovery map I_n = K I_p, is recorded in
`out["_meta"]["kron_reduction"]`.

**Exactness.** The reduction is exact only where the neutral was already
*perfectly* earthed at both ends; then the provenance reports
`"classification" => "exact"`. Otherwise (floating neutrals, or finite
earthing such as MEN shunts) the neutral is *forced* to ideal earth, the
classification is `"grounded_neutral_projection"` and `"forced_ground_buses"`
lists where. The scientific contract [`check_kron_boundary_recovery`](@ref)
(`PSK-000008`) checks the same precondition line by line.

`input` may be a BMOPF dictionary (a new dictionary is returned; the input is
never mutated) or JSON text (`as_json=true` returns strict-schema JSON;
`include_coordinates` keeps bus coordinates as a non-strict extension).
Neutrals are resolved from `terminal_conventions`, a bus's `neutral_terminal`,
or the `n`/`N` convention, or from `neutral_terminals` (one label or a
bus-to-label map). `FOUR_LEG` IBRs whose neutral return would be removed
(BMOPF has no reduced equivalent), active neutral-leg devices with neutral
limits, ambiguous maps and structural time series are refused with an
`ArgumentError`.

Ported from PowerOptLab.jl (same author and license) with its test suite.
"""
function kron_reduce_neutrals(input; as_json::Bool=false, neutral_terminals=nothing,
                           include_coordinates::Bool=false)
    net = _nk_input(input)
    neutrals = _nk_neutral_map(net, neutral_terminals)
    if isempty(neutrals)
        if as_json
            io = IOBuffer(); write_bmopf(net, io; indent=nothing, include_coordinates); return String(take!(io))
        end
        return net
    end
    originally_grounded = Dict{String,Bool}()
    for (id,b) in get(net, "bus", Dict())
        nt = get(neutrals, String(id), nothing)
        originally_grounded[String(id)] = nt !== nothing && nt in string.(get(b, "perfectly_grounded_terminals", String[]))
    end
    # Only geometries that were referenced before this reduction can become
    # newly orphaned. Preserve pre-existing catalog entries for auditability.
    geometry_refs_before = Set{String}()
    for lc in values(get(net, "linecode", Dict()))
        lc isa AbstractDict || continue
        gid = get(lc, "line_geometry", nothing)
        gid === nothing || push!(geometry_refs_before, String(gid))
    end
    audit = Any[]
    # Bus structures and bounds first, so every subsequent map uses the same
    # role table. Keep neutral_terminal only long enough to adapt the bus.
    for (id,b) in get(net,"bus",Dict())
        b isa AbstractDict || continue
        _nk_preflight_ts!(b, "bus '$id'")
        names = string.(get(b,"terminal_names",String[])); nt = get(neutrals,String(id),nothing)
        _nk_adapt_bus_bounds!(b,id,names,nt,audit)
        if nt !== nothing
            p=findfirst(==(nt),names); keep=[i for i in eachindex(names) if i != p]
            isempty(keep) && throw(ArgumentError("bus '$id' would have no terminals after removing neutral '$nt'"))
            b["terminal_names"] = names[keep]
            # v_min/v_max are the only terminal-indexed bus fields. Other
            # vectors (sequence limits, set-like ground lists, phase bounds)
            # have independent semantics and must not be sliced generically.
            for key in ("v_min", "v_max")
                v = get(b,key,nothing)
                v isa AbstractVector && length(v) == length(names) && (b[key] = v[keep])
            end
            if haskey(b,"perfectly_grounded_terminals")
                g=string.(b["perfectly_grounded_terminals"]); b["perfectly_grounded_terminals"]=[x for x in g if x != nt]
                isempty(b["perfectly_grounded_terminals"]) && delete!(b,"perfectly_grounded_terminals")
            end
            haskey(b,"neutral_terminal") && delete!(b,"neutral_terminal")
            push!(audit,Dict{String,Any}("bus"=>String(id),"removed_neutral"=>nt,"position"=>p,
                                        "grounding_class"=>(get(originally_grounded,String(id),false) ? "exact_perfect_ground" : "forced_ideal_ground")))
        end
    end
    reduced_linecodes = _nk_reduce_linecodes!(net, neutrals, audit)
    # Lines need their inline matrices and maps changed after catalog handling.
    for (id,line) in collect(get(net,"line",Dict()))
        line isa AbstractDict || continue
        _nk_preflight_ts!(line, "line '$id'")
        _nk_reduce_line_dict!(line,id,neutrals,get(net,"linecode",Dict()),audit,reduced_linecodes)
    end
    geoms = get(net, "line_geometry", nothing)
    if geoms isa AbstractDict
        used = Set(string(get(lc,"line_geometry","")) for lc in values(get(net,"linecode",Dict())) if lc isa AbstractDict)
        for gid in collect(keys(geoms))
            String(gid) in geometry_refs_before && !(String(gid) in used) &&
                (delete!(geoms,gid); push!(audit, Dict{String,Any}("removed_catalog"=>"line_geometry/$(gid)", "reason"=>"neutral reduction orphaned the previously referenced geometry")))
        end
    end
    _nk_transformers!(net,neutrals,audit)
    # Every AC component collection, including switches and passive shunts.
    removed = String[]
    for family in _NK_AC_COMPONENTS
        table=get(net,family,Dict()); table isa AbstractDict || continue
        for (id,c) in collect(table)
            c isa AbstractDict || continue
            _nk_preflight_ts!(c, "$family '$id'")
            if family == "ibr" && uppercase(string(get(c,"topology",""))) in ("FOUR_LEG", "SINGLE_PHASE") &&
               any(get(neutrals,String(get(c,"bus","")),nothing) == t for t in string.(get(c,"terminal_map",String[])))
                tm_ibr = string.(get(c, "terminal_map", String[]))
                # A FOUR_LEG IBR requires one identified neutral return
                # (E.TMAP.DEVICE_ROLES); BMOPF has no reduced three-leg
                # equivalent of a grounded fourth leg, so refuse the case.
                uppercase(string(get(c, "topology", ""))) == "FOUR_LEG" &&
                    throw(ArgumentError("IBR '$id' is FOUR_LEG; eliminating its neutral return leaves " *
                                        "no valid BMOPF representation (E.TMAP.DEVICE_ROLES)"))
                imax = get(c, "i_max", nothing)
                (imax isa AbstractVector && length(imax) == length(tm_ibr)) &&
                    throw(ArgumentError("IBR '$id' declares a neutral-conductor current limit that Kron reduction cannot preserve"))
                any(haskey(c, key) for key in ("neutral_i_max", "i_neutral_max",
                                               "neutral_current_control")) &&
                    throw(ArgumentError("IBR '$id' declares explicit neutral-current physics that Kron reduction cannot preserve"))
                # Record what was done in this reducer's own provenance rather
                # than stamping a downstream formulation's private key onto a
                # component dict: `kron_reduce_neutrals` is general-purpose, and
                # every consumer sees whatever it writes.
                push!(audit, Dict{String,Any}(
                    "component"=>"ibr/$(id)",
                    "reduced_neutral_leg"=>uppercase(string(get(c,"topology",""))),
                    "reason"=>"active neutral-leg topology reduced; the IBR " *
                              "declared no neutral-conductor limit to preserve"))
            end
            # Switches have two buses, so resolve both neutral roles before
            # considering a neutral-only closure.  `bus` is not a switch
            # field and must not be used as an implicit empty bus id.
            if family == "switch"
                bf, bt = String(get(c, "bus_from", "")), String(get(c, "bus_to", ""))
                ntf, ntt = get(neutrals, bf, nothing), get(neutrals, bt, nothing)
                tmf, tmt = string.(get(c, "terminal_map_from", String[])), string.(get(c, "terminal_map_to", String[]))
                if ntf !== nothing && ntt !== nothing && tmf == [ntf] && tmt == [ntt]
                    original = deepcopy(c)
                    delete!(table, id)
                    push!(removed, "switch/$(id)")
                    push!(audit, Dict{String,Any}("component"=>"switch/$(id)",
                        "type"=>"switch", "id"=>String(id), "bus_from"=>bf,
                        "bus_to"=>bt, "terminal_map_from"=>tmf,
                        "terminal_map_to"=>tmt, "original_values"=>original,
                        "reason"=>"neutral-only switch is parallel to implicit ground"))
                    continue
                end
            end
            busid=get(c,"bus",""); nt=get(neutrals,String(busid),nothing)
            if family == "capacitor" && nt !== nothing && _nk_grounded_capacitor!(net,id,c,busid,nt,audit)
                delete!(table,id)
                continue
            end
            # Shunts consisting only of a neutral grounding point are exactly
            # parallel to the implicit ground and are removed. Preserve the
            # original object in provenance so finite grounding values remain
            # auditable rather than silently disappearing.
            tm=string.(get(c,"terminal_map",String[]))
            if family == "shunt" && nt !== nothing && tm == [nt]
                original = deepcopy(c)
                delete!(table,id); push!(removed,"shunt/$(id)")
                push!(audit, Dict{String,Any}("component"=>"shunt/$(id)",
                    "type"=>"shunt", "id"=>String(id), "bus"=>String(busid),
                    "terminal_map"=>tm, "original_values"=>original,
                    "reason"=>"neutral-only shunt is parallel to implicit ground"))
                continue
            end
            shunt_original = family == "shunt" ? deepcopy(c) : nothing
            if family == "switch"
                tmf, tmt = string.(get(c,"terminal_map_from",String[])), string.(get(c,"terminal_map_to",String[]))
                length(tmf) == length(tmt) || throw(ArgumentError("switch '$id' terminal maps have different arities"))
                length(tmf) == length(unique(tmf)) || throw(ArgumentError("switch '$id' has duplicate from terminals"))
                length(tmt) == length(unique(tmt)) || throw(ArgumentError("switch '$id' has duplicate to terminals"))
                for k in eachindex(tmf)
                    ((tmf[k] == get(neutrals,String(get(c,"bus_from","")),nothing)) ==
                     (tmt[k] == get(neutrals,String(get(c,"bus_to","")),nothing))) ||
                        throw(ArgumentError("switch '$id' conductor role differs between from/to at position $k"))
                end
                _nk_strip_map!(c,"terminal_map_from",get(c,"bus_from",""),neutrals,"switch '$id' from";
                    audit, vector_fields=_NK_RATING_FIELDS)
                _nk_strip_map!(c,"terminal_map_to",get(c,"bus_to",""),neutrals,"switch '$id' to";
                    audit, vector_fields=_NK_RATING_FIELDS)
            else
                _nk_strip_map!(c,"terminal_map",busid,neutrals,"$family '$id'";
                    audit, vector_fields=get(_NK_COMPONENT_VECTOR_FIELDS, String(family), Set{String}()))
            end
            # Matrix shunts follow the same grounded projection as line π-shunts.
            if family == "shunt" && nt !== nothing && !isempty(tm)
                p=findfirst(==(nt),tm)
                if p !== nothing
                    original = shunt_original === nothing ? deepcopy(c) : shunt_original
                    _nk_drop_matrix_neutral!(c,p,("G_","B_"),"shunt '$id'")
                    push!(audit, Dict{String,Any}("component"=>"shunt/$(id)",
                        "type"=>"shunt", "id"=>String(id), "bus"=>String(busid),
                        "terminal_map"=>tm, "original_values"=>original,
                        "reason"=>"mixed neutral shunt projected onto implicit ground"))
                end
            end
        end
    end
    # Transformer terminal maps were handled above. This pass handles nested
    # DC-port maps only by leaving them untouched: `n` on a dc_bus is not an AC
    # neutral and must not be guessed to ground.
    # Keep the exported role declaration consistent with the reduced topology.
    if get(net, "terminal_conventions", nothing) isa AbstractDict
        tc = net["terminal_conventions"]
        haskey(tc, "neutral") && (tc["neutral"] = String[])
    end
    meta=get!(net,"_meta",Dict{String,Any}())
    prov=Dict{String,Any}(
        "method"=>"explicit-neutral Kron reduction (series Schur complement)",
        "ground_assumption"=>"removed neutral terminals are held at ideal ground (Vn=0)",
        "neutral_buses"=>Dict(k=>v for (k,v) in neutrals),
        "neutral_resolution"=>(neutral_terminals === nothing ?
            (haskey(net, "terminal_conventions") ? "terminal_conventions.neutral" : "n/N naming convention") :
            "explicit neutral_terminals override"),
        "changes"=>audit,
        "removed_explicit_grounding"=>removed,
        "unsupported"=>["active neutral-leg devices", "ambiguous neutral position/order", "singular neutral block"],
    )
    forced_buses = [k for (k,v) in originally_grounded if !v && haskey(neutrals,k)]
    lost = [x for x in audit if haskey(x,"dropped_constraint") || haskey(x,"dropped_bound") || haskey(x,"converted_to")]
    prov["classification"] = isempty(forced_buses) && isempty(lost) ? "exact" : "grounded_neutral_projection"
    prov["forced_ground_buses"] = forced_buses
    prov["model_change_reasons"] = isempty(forced_buses) && isempty(lost) ? String[] :
        vcat(isempty(forced_buses) ? String[] : ["neutral not originally perfectly grounded"],
             [string(get(x,"dropped_constraint",get(x,"dropped_bound",get(x,"converted_to","adapted component")))) for x in lost])
    meta["kron_reduction"] = prov
    get!(net, "extras", Dict{String,Any}())["kron_reduction"] = prov
    if as_json
        io = IOBuffer()
        write_bmopf(net, io; indent=nothing, include_coordinates)
        String(take!(io))
    else
        net
    end
end
