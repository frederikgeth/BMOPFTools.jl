# Shared helpers for the profiler_*_tests.jl files. Each file includes this
# when the helpers are not yet defined, so it also runs on its own.

using Test
using BMOPFTools

const _PG_PF = joinpath(@__DIR__, "data", "pf_comparison")
_pg_codes(findings) = [f.code for f in findings]
_pg_dss(name) = redirect_stderr(devnull) do
    from_dss(joinpath(_PG_PF, name))
end
_pg_analyze(net) = redirect_stderr(devnull) do
    analyze(net)
end
_pg_sys(name) = parse_bmopf(joinpath(@__DIR__, "data", "profiler_systems", name * ".json"))
_pg_zone(report, bus) = only(z for z in report.results[:connectivity]["zones"] if z["label"] == bus)

# A radial four-wire feeder with one unbalanced single-phase load per phase at the end.
_pg_feeder(; n_lines::Int=3, len::Float64=50.0) = begin
    net = Dict{String,Any}(
        "bus" => Dict{String,Any}("b0" => Dict{String,Any}(
            "terminal_names" => ["a","b","c","n"], "perfectly_grounded_terminals" => ["n"])),
        "voltage_source" => Dict{String,Any}("vs" => Dict{String,Any}(
            "bus" => "b0", "terminal_map" => ["a","b","c"],
            "v_magnitude" => fill(230.0, 3), "v_angle" => [0.0, -2π/3, 2π/3])),
        "linecode" => Dict{String,Any}("lc" => Dict{String,Any}(
            ("$(q)_series_$(k)_$(k)" => (q == "R" ? 3e-4 : 1e-4) for q in ("R","X"), k in 1:4)...,
            "i_max" => fill(200.0, 4))),
        "line" => Dict{String,Any}(), "load" => Dict{String,Any}())
    for k in 1:n_lines
        net["bus"]["b$k"] = Dict{String,Any}("terminal_names" => ["a","b","c","n"])
        net["line"]["l$(lpad(k, 4, '0'))"] = Dict{String,Any}(
            "bus_from" => "b$(k-1)", "bus_to" => "b$k", "linecode" => "lc", "length" => len,
            "terminal_map_from" => ["a","b","c","n"], "terminal_map_to" => ["a","b","c","n"])
    end
    for (k, ph) in enumerate(("a","b","c"))
        net["load"]["ld$ph"] = Dict{String,Any}("bus" => "b$n_lines",
            "terminal_map" => [ph, "n"], "configuration" => "SINGLE_PHASE",
            "p_nom" => [1000.0 * k], "q_nom" => [100.0 * k], "v_nom" => [230.0])
    end
    net
end
