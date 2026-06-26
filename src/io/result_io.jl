# io/result_io.jl
#
# Serialise / deserialise OPF result dicts (as returned by solve_opf). The
# result is a plain Dict{String,Any} in SI units whose structure mirrors the
# network and is documented in docs/src/results.md, so these are thin JSON
# wrappers — the analogue of write_bmopf/parse_bmopf for solver output.

"""
    write_result(result::Dict{String,Any}, dest; indent=2)

Serialise an OPF result dict (as returned by [`solve_opf`](@ref)) to JSON.

- `dest::IO`             — writes to the IO stream
- `dest::AbstractString` — writes to a file at that path

Pass `indent=nothing` for compact (single-line) output. The result structure is
documented in [OPF result dictionary](@ref). Read it back with [`read_result`](@ref).

!!! note "Infeasible results contain NaN"
    An infeasible result has every numeric field set to `NaN` (only
    `termination_status` and `solve_time` stay valid). `NaN` is not part of
    strict JSON: it is emitted verbatim and round-trips through `read_result`,
    but may be rejected by external strict JSON parsers.
"""
function write_result(result::Dict{String,Any}, io::IO;
                      indent::Union{Int,Nothing}=2)
    # allow_inf keeps NaN/Inf from infeasible results writable (as literal tokens).
    if isnothing(indent)
        JSON3.write(io, result; allow_inf=true)
    else
        JSON3.pretty(io, result, JSON3.AlignmentContext(; indent=UInt16(indent));
                     allow_inf=true)
    end
end

function write_result(result::Dict{String,Any}, path::AbstractString;
                      indent::Union{Int,Nothing}=2)
    open(path, "w") do io
        write_result(result, io; indent)
    end
end

"""
    read_result(src; from_string=false) -> Dict{String,Any}

Read an OPF result JSON (written by [`write_result`](@ref)) back into a
`Dict{String,Any}`.

- `src::IO`             — reads from the IO stream
- `src::AbstractString` — a file path, or the JSON text itself when
  `from_string=true`
"""
function read_result(io::IO)::Dict{String,Any}
    JSON3.read(io, Dict{String,Any}; allow_inf=true)
end

function read_result(src::AbstractString; from_string::Bool=false)::Dict{String,Any}
    from_string ? JSON3.read(src, Dict{String,Any}; allow_inf=true) :
                  open(read_result, src)
end
