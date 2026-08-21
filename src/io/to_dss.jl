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
    to_dss(net::Dict{String,Any}; name=nothing) -> (dss_text, warnings)

Convert a BMOPF network dict to OpenDSS text using
[PowerIO.jl](https://github.com/eigenergy/PowerIO.jl), returning the generated
DSS string and a vector of fidelity-loss warnings.

The dict is serialised to BMOPF JSON (via [`write_bmopf`](@ref)) and handed to
PowerIO's DSS writer. BMOPF terminal labels (`"a"`, `"b"`, `"c"`, `"n"`) are
accepted by the writer and re-normalised to OpenDSS numeric nodes (`.1`, `.2`,
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
  are the same list as the `CODE: message` lines it renders as.

# Conversion warnings
PowerIO reports every piece of information that its BMOPF→DSS writer cannot
represent or had to assume. These are returned as the second element so callers
can inspect fidelity losses without losing the converted text.

# Errors
- `ErrorException` if PowerIO produces no DSS output (writer failure).

# Example
```julia
net = from_dss("test/data/pf_comparison/pf_3ph_line.dss")
dss_text, warnings = to_dss(net)
isempty(warnings) || @warn "DSS writer fidelity losses" warnings
```
"""
function to_dss(net::Dict{String,Any};
                name::Union{AbstractString,Nothing}=nothing,
                findings::Union{Vector{Finding},Nothing}=nothing
                )::Tuple{String,Vector{String}}

    # Serialise to BMOPF JSON without mutating the caller's dict. write_bmopf
    # drops the tool-private `_meta` block and emits schema-valid JSON.
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
    dss_text, warnings_list =
        PowerIO.convert_str(PowerIO.MulticonductorNetwork, json, "dss"; from="bmopf")

    if isempty(dss_text)
        throw(ErrorException("PowerIO produced no DSS output"))
    end

    # The export direction reads component ids straight out of the caller's
    # dict, so unlike `from_dss` there is no case folding to mirror here.
    findings === nothing ||
        append!(findings, powerio_findings(_powerio_diagnostic_records(warnings_list)))

    dss_text, collect(String, warnings_list)
end

"""
    to_dss(net::Dict{String,Any}, path::AbstractString; name=nothing) -> warnings

Convert a BMOPF network dict to OpenDSS and write the result to `path`,
returning the vector of fidelity-loss warnings (see the two-argument
[`to_dss`](@ref) for details).

# Example
```julia
net = from_dss("test/data/ENWL/network_1/Feeder_1/Master.dss")
warnings = to_dss(net, "roundtrip/Master.dss")
```
"""
function to_dss(net::Dict{String,Any}, path::AbstractString;
                name::Union{AbstractString,Nothing}=nothing,
                findings::Union{Vector{Finding},Nothing}=nothing)::Vector{String}
    dss_text, warnings_list = to_dss(net; name=name, findings=findings)
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        write(io, dss_text)
    end
    warnings_list
end

"""
Rewrite lines carrying inline ABSOLUTE impedance matrices (Ω, S) into an
equivalent linecode-referencing form for exporters that only know the
per-length convention (PowerIO's DSS writer): a synthetic per-metre linecode
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
