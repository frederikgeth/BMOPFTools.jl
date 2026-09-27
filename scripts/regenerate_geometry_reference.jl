# Run with an environment containing OpenDSSDirect, JSON3, and SHA.
# This independent oracle must not import BMOPFTools or call its compiler.
using OpenDSSDirect, JSON3, SHA
root = normpath(joinpath(@__DIR__, "..", "test", "data", "line_geometry"))
cases = Dict{String,Any}()
for (name, n) in (("synthetic_overhead", 4), ("synthetic_cn", 3), ("synthetic_ts", 2))
    path = joinpath(root, name * ".dss")
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Redirect \"$path\"")
    OpenDSSDirect.Lines.Name("l1")
    record = Dict{String,Any}("sha256" => bytes2hex(sha256(read(path))))
    for (key, values) in (("R", OpenDSSDirect.Lines.RMatrix()),
                          ("X", OpenDSSDirect.Lines.XMatrix()),
                          ("C", OpenDSSDirect.Lines.CMatrix()))
        matrix = Matrix{Float64}(values)
        @assert size(matrix) == (n, n) && all(isfinite, matrix)
        record[key] = [collect(row) for row in eachrow(matrix)]
    end
    cases[name] = record
end
output = (generator="OpenDSSDirect (no BMOPFTools calculation)",
          opendssdirect_version=string(pkgversion(OpenDSSDirect)),
          engine_version=OpenDSSDirect.Basic.Version(),
          units=(R="ohm/m", X="ohm/m", C="nF/m"), cases=cases)
open(joinpath(root, "opendss_reference.json"), "w") do io
    JSON3.pretty(io, output)
    println(io)
end
