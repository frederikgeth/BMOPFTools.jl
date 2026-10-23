"""
    DSSConversionError(source_path, stage, cause, reader_diagnostics=[])

Context for a `PowerIO.PowerIOError` raised by the parse or emission boundary
of [`from_dss`](@ref). `source_path` is absolute; `stage` is `:parse` or
`:emit`. `cause` is the original upstream exception, preserved unchanged.
`reader_diagnostics` is a defensive snapshot taken before emission, separate
from the failure diagnostics in `cause.diagnostics`. A parse failure has no
successful reader module and therefore an empty reader snapshot.

This wrapper changes the exception type exposed at those boundaries. Catch
`DSSConversionError` and inspect `err.cause.code` for the stable upstream
code. Component targets and source spans remain absent when PowerIO supplies
none. No partial network is returned. Use
[`dss_conversion_error_to_dict`](@ref) for JSON-safe evidence.
"""
struct DSSConversionError <: Exception
    source_path::String
    stage::Symbol
    cause::PowerIO.PowerIOError
    reader_diagnostics::Vector{PowerIO.Diagnostic}

    function DSSConversionError(source_path::AbstractString, stage::Symbol,
                                cause::PowerIO.PowerIOError,
                                reader_diagnostics::AbstractVector{PowerIO.Diagnostic}=PowerIO.Diagnostic[])
        isempty(source_path) && throw(ArgumentError("DSS source path must not be empty"))
        stage in (:parse, :emit) || throw(ArgumentError(
            "DSS conversion failure stage must be :parse or :emit"))
        new(abspath(source_path), stage, cause,
            deepcopy(Vector{PowerIO.Diagnostic}(reader_diagnostics)))
    end
end

function Base.showerror(io::IO, err::DSSConversionError)
    print(io, "DSSConversionError: from_dss ", err.stage, " failed for ",
          repr(err.source_path), "\nCaused by: ")
    showerror(io, err.cause)
end

"""
    dss_conversion_error_to_dict(err::DSSConversionError) -> Dict{String,Any}

Return JSON-safe failure evidence with `source_path`, `stage`, a separate
`reader_diagnostics` array, and `upstream_error` containing the original
`code`, `message`, and failure `diagnostics`. Each diagnostic preserves
its upstream code, severity, message, id, target, details, suggested action,
related ids, and byte spans. Empty arrays and `nothing` remain explicit.

The returned containers are defensive copies. The original upstream exception
is still available as `err.cause`; Julia backtraces and foreign module handles
are not serialized. This evidence describes an intake failure, not a scientific
contract result or a network-validation claim.
"""
function dss_conversion_error_to_dict(err::DSSConversionError)
    return Dict{String,Any}(
        "source_path" => err.source_path,
        "stage" => string(err.stage),
        "reader_diagnostics" => _powerio_diagnostic_to_dict.(err.reader_diagnostics),
        "upstream_error" => Dict{String,Any}(
            "code" => err.cause.code, "message" => err.cause.message,
            "diagnostics" => _powerio_diagnostic_to_dict.(err.cause.diagnostics)),
    )
end

function _dss_failure_findings(err::DSSConversionError)
    diagnostics = vcat(err.reader_diagnostics, err.cause.diagnostics)
    records = _powerio_diagnostic_records(diagnostics; infer_message_elements=false)
    reader_count = length(err.reader_diagnostics)
    for record in records
        record["source_path"] = err.source_path
        record["conversion_stage"] = string(err.stage)
        record["diagnostic_details"] = [
            Dict("origin" => i <= reader_count ? "reader" : "failure",
                 "diagnostic" => _powerio_diagnostic_to_dict(diagnostics[i]))
            for i in record["source_records"]]
    end
    return powerio_findings(records)
end

# Restrict interception to explicit PowerIO boundaries. Reader evidence is
# captured before calling the writer; successful intake keeps its existing
# single append of the combined reader/writer Findings.
function _with_dss_conversion_evidence(f::Function, source_path, stage,
                                       reader_diagnostics=PowerIO.Diagnostic[];
                                       findings=nothing)
    snapshot = deepcopy(reader_diagnostics)
    try
        return f()
    catch cause
        cause isa PowerIO.PowerIOError || rethrow()
        err = DSSConversionError(source_path, stage, cause, snapshot)
        findings === nothing || append!(findings, _dss_failure_findings(err))
        throw(err)
    end
end
