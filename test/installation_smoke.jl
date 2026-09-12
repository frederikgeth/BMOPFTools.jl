using Test

smoke_mode = only(ARGS)
smoke_mode in ("core", "jump_first", "package_first", "solver") || error("Unknown smoke_mode: $smoke_mode")
if smoke_mode == "jump_first"
    @eval using JuMP
end
using BMOPFTools
extension_before = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
if smoke_mode in ("package_first", "solver")
    @eval using JuMP
end
if smoke_mode == "solver"
    @eval using Ipopt
end

@testset "Installed package: $smoke_mode" begin
    root = pkgdir(BMOPFTools)
    net = parse_bmopf(joinpath(root, "recipes", "analyze_case", "input.json"))
    @test isempty(errors(analyze(net)))
    @test !isempty(load_config())
    @test execute_analysis(net)["status"] == "completed"
    findings = Finding[]
    net["meta"] = Dict{String,Any}("\$schema" =>
        "https://raw.githubusercontent.com/frederikgeth/bmopf-report/main/draft_schema_and_networks/draft_bmopf_schema.json")
    @test schema_check(net, findings)["jsonschema_ran"]

    if smoke_mode == "core"
        @test isnothing(Base.find_package("JuMP"))
        @test isnothing(Base.find_package("Ipopt"))
        @test isnothing(Base.get_extension(BMOPFTools, :BMOPFOpfExt))
    else
        if smoke_mode != "jump_first"
            @test isnothing(extension_before)
        end
        @test !isnothing(Base.get_extension(BMOPFTools, :BMOPFOpfExt))
        if smoke_mode == "solver"
            pf = from_dss(joinpath(root, "test", "data", "pf_comparison", "pf_1ph_line.dss"))
            result = solve_pf(pf; optimizer=Ipopt.Optimizer)
            @test result["termination_status"] in ("OPTIMAL", "LOCALLY_SOLVED")
        else
            @test isnothing(Base.find_package("Ipopt"))
            @test opf_model(initialize_opf_model(net; optimizer=nothing)) isa JuMP.Model
        end
    end
end
