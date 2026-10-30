# io/to_dss.jl
#
# BMOPF → OpenDSS conversion via the PowerIO.jl package
# (eigenergy/PowerIO.jl, which binds the `powerio` Rust engine in-process).
#
# This is the inverse of `from_dss`: it hands a BMOPF network dict to PowerIO's
# DSS writer and returns the generated OpenDSS text. The goal at this stage is
# *valid* OpenDSS (parseable, solveable), not byte-for-byte or power-flow
# validated fidelity — PowerIO's fidelity-loss warnings are surfaced so callers
# can see what the DSS writer had to assume or could not represent.

"""
    to_dss(net::Dict{String,Any}; name=nothing, allow_unverified_ratings=false) -> (dss_text, warnings)

Convert a BMOPF network dict to OpenDSS text using
[PowerIO.jl](https://github.com/eigenergy/PowerIO.jl), returning the generated
DSS string and a vector of fidelity-loss warnings.

The dict is serialized to BMOPF JSON (via [`write_bmopf`](@ref)) and handed to
PowerIO's DSS writer. BMOPF terminal labels (`"a"`, `"b"`, `"c"`, `"n"`) are
accepted by the writer and re-normalized to OpenDSS numeric nodes (`.1`, `.2`,
`.3`, `.0`); merged polyphase sources are re-expanded as needed by the writer.

This is the inverse of [`from_dss`](@ref). It produces valid OpenDSS but does
not (yet) guarantee that a `from_dss → to_dss` round trip reproduces the
original file byte-for-byte or that the regenerated network solves identically
in OpenDSS — inspect `warnings` for anything the writer could not represent.

# Arguments
- `net`: a BMOPF network dict (as returned by `from_dss` or `parse_bmopf`).
- `name`: optional network name to write instead of `net["name"]`. The input
  dict is not mutated.
- `findings`: optional `Vector{Finding}` to append the writer's findings to,
  carrying powerio's own diagnostic code and severity. The returned warnings
  are the same list as the `CODE: message` lines it renders as. The package
  admission Finding includes an `indeterminate` status and changed declarations.
- `allow_unverified_ratings`: opt in to power-flow verification exports when the
  conservative identity-correspondence check cannot establish rating retention.
  Default `false`. Equivalent circuits, renamed terminals, dynamic controls,
  DC networks, and failed re-imports require opt-in. A successful declaration
  check does not certify electrical equivalence or OPF feasible sets.

# Conversion warnings
PowerIO diagnostics and the package's `W.EXPORT.DSS_RATING_UNVERIFIED` warning
are returned as the second element. Opting in does not establish preservation.
PowerIO 0.11.7 can introduce 600 A limits on unrated equivalent-circuit branches
([powerio#762](https://github.com/eigenergy/powerio/issues/762)). Keep BMOPF JSON
authoritative for OPF and Tellegen; opted-in DSS exports are for independent
power-flow verification, with the returned fidelity warnings inspected.

# Errors
- `ArgumentError` with `W.EXPORT.DSS_RATING_UNVERIFIED` unless the static AC
  re-import retains component/terminal correspondence and declared bounds/ratings,
  or the caller explicitly opts in. File exports refuse before touching `path`.
- `ErrorException` if PowerIO produces no DSS output (writer failure).

# Example
```julia
net = from_dss("test/data/pf_comparison/pf_3ph_line.dss")
dss_text, warnings = to_dss(net; allow_unverified_ratings=true)
isempty(warnings) || @warn "DSS writer fidelity losses" warnings
```
"""
function to_dss(net::Dict{String,Any};
                name::Union{AbstractString,Nothing}=nothing,
                findings::Union{Vector{Finding},Nothing}=nothing,
                allow_unverified_ratings::Bool=false
                )::Tuple{String,Vector{String}}

    # Serialize to BMOPF JSON without mutating the caller's dict. write_bmopf
    # persists tool provenance and retains optional bus coordinate extensions.
    src = net
    if !isnothing(name)
        src = copy(net)          # shallow copy: we only replace the top-level name
        src["name"] = name
    end
    src = _materialize_inline_lines_for_export(src)

    io = IOBuffer()
    write_bmopf(src, io)
    json = String(take!(io))

    # PowerIO reads the BMOPF JSON and writes OpenDSS text, reporting every
    # fidelity loss its writer had to make.
    module_ = PowerIO.parse(IOBuffer(json); format="bmopf", name="network.bmopf.json")
    emission = PowerIO.emit(module_, "dss")
    dss_text = _restore_dss_export_fidelity(emission.text, src)
    diagnostics = vcat(module_.diagnostics, emission.diagnostics)
    warnings_list = _powerio_diagnostic_line.(diagnostics)

    if isempty(dss_text)
        throw(ErrorException("PowerIO produced no DSS output"))
    end

    # The export direction reads component ids straight out of the caller's
    # dict, so unlike `from_dss` there is no case folding to mirror here.
    findings === nothing ||
        append!(findings, powerio_findings(_powerio_diagnostic_records(diagnostics)))

    # Compare declarations only under identity component/terminal correspondence.
    # Equivalent circuits need an explicit recovery map; never infer one from ids
    # or voltages. PSK-000007: terminal behavior does not certify decision limits.
    evidence = _dss_rating_evidence(src, dss_text)
    if evidence["status"] != "passed"
        message = "DSS rating preservation is unverified; use " *
            "allow_unverified_ratings=true only for power-flow verification. " *
            "Keep BMOPF JSON authoritative for OPF and Tellegen (powerio#762)."
        f = Finding(WARNING, "W.EXPORT.DSS_RATING_UNVERIFIED", :provenance,
                    :network, nothing, message, evidence)
        findings === nothing || push!(findings, f)
        allow_unverified_ratings || throw(ArgumentError(f.code * ": " * message))
        push!(warnings_list, f.code * ": " * message)
    end
    dss_text, collect(String, warnings_list)
end

"""
    to_dss(net::Dict{String,Any}, path::AbstractString; name=nothing, allow_unverified_ratings=false) -> warnings

Convert a BMOPF network dict to OpenDSS and write the result to `path`,
returning the vector of fidelity-loss warnings (see the two-argument
[`to_dss`](@ref) for details).

# Example
```julia
net = from_dss(joinpath(pkgdir(BMOPFTools), "test", "data", "pf_comparison", "pf_1ph_line.dss"))
warnings = to_dss(net, "roundtrip/Master.dss"; allow_unverified_ratings=true)
```
"""
function to_dss(net::Dict{String,Any}, path::AbstractString;
                name::Union{AbstractString,Nothing}=nothing,
                findings::Union{Vector{Finding},Nothing}=nothing,
                allow_unverified_ratings::Bool=false)::Vector{String}
    dss_text, warnings_list = to_dss(net; name=name, findings=findings,
                                     allow_unverified_ratings=allow_unverified_ratings)
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        write(io, dss_text)
    end
    warnings_list
end

"""
Rewrite lines carrying inline ABSOLUTE impedance matrices (Ω, S) into an
equivalent linecode-referencing form for exporters that only know the
per-length convention (PowerIO's DSS writer): a synthetic per-meter linecode
holding the section totals with `length = 1.0`. Numerically lossless — the
1 m length carries the totals exactly; the descriptive BMOPF `length` (if
any) is dropped from the export because it would rescale the impedance.
Returns the input unchanged when no inline lines are present.
"""
function _materialize_inline_lines_for_export(net::Dict{String,Any})::Dict{String,Any}
    any(l isa Dict && _line_has_inline_z(l)
        for (_, l) in get(net, "line", Dict())) || return net

    out = deepcopy(net)
    linecodes = get!(out, "linecode", Dict{String,Any}())
    matrix_key = r"^(R_series|X_series|G_from|G_to|B_from|B_to)_\d+_\d+$"
    for (lid, l) in get(out, "line", Dict())
        l isa Dict && _line_has_inline_z(l) || continue
        lcid = "_inline_$(lid)"
        lc = Dict{String,Any}(k => v for (k, v) in l
                              if match(matrix_key, k) !== nothing)
        haskey(l, "i_max") && (lc["i_max"] = l["i_max"])
        linecodes[lcid] = lc
        for k in collect(keys(l))
            match(matrix_key, k) === nothing || delete!(l, k)
        end
        l["linecode"] = lcid
        l["length"]   = 1.0
    end
    out
end

# PowerIO 0.11.1 drops exponential parameters and writes multi-winding %R
# using individual ratings. Explicit DSS edits preserve the source quantities
# restored on intake (#333/#356); caller data and PMD export are untouched.
function _restore_dss_export_fidelity(text, net)
    commands = String[]
    object_name(kind,id) = begin
        any(c -> c in ('"','\n','\r'), string(id)) && throw(ArgumentError(
            "DSS fidelity edit cannot safely quote component identifier $id"))
        "\"$kind.$id\""
    end
    for (id,load) in get(net,"load",Dict())
        get(load,"model","") == "exponential" || continue
        function exponent(field)
            v=get(load,field,[0.0]); v=v isa AbstractVector ? v : [v]
            !isempty(v) && all(x -> x isa Real && isfinite(x) && x==first(v),v) ||
                throw(ArgumentError("DSS load $id requires one finite $field shared by its phases"))
            Float64(first(v))
        end
        push!(commands,"Edit $(object_name("Load",id)) model=4 CVRwatts=$(exponent("gamma_p")) CVRvars=$(exponent("gamma_q"))")
    end
    for (id,t) in get(get(net,"transformer",Dict()),"n_winding",Dict())
        windings=get(t,"windings",[]); isempty(windings) && continue
        base=get(first(windings),"s_rating",get(t,"s_rating",nothing))
        base isa Real && isfinite(base) && base>0 || continue
        # BMOPF n-winding v_nom is already the physical COIL voltage.
        for (k,w) in enumerate(windings)
            own=get(w,"s_rating",base)
            own==base && continue
            voltage=get(w,"v_nom",nothing); resistance=get(w,"r_winding",nothing)
            tm=get(w,"terminal_map",String[])
            phases=length(_phase_positions(tm,_neutral_labels(net)))
            phases in (1,3) && voltage isa Real && voltage>0 && resistance isa Real ||
                throw(ArgumentError("DSS transformer $id winding $k has no supported resistance base"))
            percent=100*resistance*base/(phases*voltage^2)
            isfinite(percent) && percent>=0 || throw(ArgumentError("Invalid DSS winding resistance"))
            push!(commands,"Edit $(object_name("Transformer",id)) wdg=$k %r=$percent")
        end
    end
    isempty(commands) && return text
    # PowerIO's emitted deck ends in Solve. Insert before it so no stale-law
    # power flow is needed to obtain the corrected deck's solution.
    pattern=r"(?im)^solve\s*$"
    occursin(pattern,text) || throw(ArgumentError("DSS writer omitted its final Solve command"))
    replace(text,pattern=>join(commands,"\n")*"\nSolve")
end

# This deliberately narrow declaration check makes no electrical-equivalence or
# OPF-feasibility claim. Added/deleted/relabeled components or terminals are
# indeterminate, even when their power-flow equivalent circuit is understood.
# Compare all declared bounds/ratings recursively, including winding ratings;
# resolve linecode i_max on the source before comparing with emitted line limits.
function _dss_rating_signature(net)
    signature = Dict{String,Any}()
    correspondence = Set(["bus", "bus_from", "bus_to", "terminal_map",
        "terminal_map_from", "terminal_map_to", "terminal_names", "neutral_terminal",
        "perfectly_grounded_terminals", "configuration", "windings", "open_switch"])
    function project(x)
        x isa AbstractVector && return project.(x)
        x isa AbstractDict || return x
        Dict{String,Any}(k => project(v) for (k,v) in x if
            k in correspondence || occursin(r"(^|_)(min|max|rating|limits)($|_)", k))
    end
    for kind in (COMPONENT_COLLECTIONS..., "transformer")
        collection = get(net, kind, Dict())
        if kind == "transformer"
            signature[kind] = Dict(st => Dict(id => project(c) for (id,c) in bank)
                                   for (st,bank) in collection if !isempty(bank))
        else
            signature[kind] = Dict(id => project(c) for (id,c) in collection)
        end
    end
    for (id,line) in get(net, "line", Dict())
        code = get(get(net, "linecode", Dict()), get(line, "linecode", ""), Dict())
        # Line-local limits override the code, matching the solver convention.
        for field in ("i_max", "s_max")
            value = get(line, field, nothing)
            value === nothing && (value = get(code, field, nothing))
            value === nothing || (signature["line"][id][field] = deepcopy(value))
        end
    end
    signature
end

function _dss_rating_evidence(net, text)
    detail = Dict{String,Any}(
        "status" => "indeterminate", "knowledge_ids" => ["PSK-000007"],
        "domain" => "identity component and terminal correspondence; declared bounds and effective line current ratings",
        "upstream_issue" => "https://github.com/eigenergy/powerio/issues/762",
        "powerio_version" => string(pkgversion(PowerIO)),
        "unassessed_dimensions" => ["electrical_equivalence", "opf_feasible_set", "objectives"])
    # Dynamic controls/DC paths are outside this static AC declaration domain.
    unsupported = [k for k in ("control_profile", "time_series", "dc_bus", "dc_branch",
        "dc_grounding", "dc_load", "dc_source") if !isempty(get(net,k,Dict()))]
    if !isempty(unsupported)
        detail["reason"] = "outside_static_ac_domain"
        detail["unsupported_collections"] = unsupported
        return detail
    end
    target = try
        mktempdir() do dir
            path = joinpath(dir, "rating-check.dss")
            write(path, text)
            # Admission evidence is returned below; avoid a second, noisy copy of
            # the re-import's console diagnostics during every export.
            with_logger(NullLogger()) do
                from_dss(path)
            end
        end
    catch err
        err isa InterruptException && rethrow()
        detail["reason"] = "reimport_failed"
        detail["error_type"] = string(typeof(err))
        return detail
    end
    before, after = _dss_rating_signature(net), _dss_rating_signature(target)
    changes = Dict{String,Any}[]
    function compare(a, b, path)
        if a isa AbstractDict && b isa AbstractDict
            for key in sort!(collect(union(keys(a), keys(b))))
                child = isempty(path) ? key : path * "." * key
                if !haskey(a,key) || !haskey(b,key)
                    push!(changes, Dict("path"=>child, "before"=>get(a,key,nothing),
                                        "after"=>get(b,key,nothing)))
                else
                    compare(a[key], b[key], child)
                end
            end
        elseif !isequal(a,b)
            push!(changes, Dict("path"=>path, "before"=>a, "after"=>b))
        end
    end
    compare(before, after, "")
    detail["changes"] = changes
    detail["reason"] = isempty(changes) ? "identical_rating_declarations" : "declarations_or_correspondence_changed"
    detail["status"] = isempty(changes) ? "passed" : "indeterminate"
    detail
end
