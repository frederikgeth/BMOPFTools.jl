using Test, BMOPFTools, JuMP

if Base.get_extension(BMOPFTools, :BMOPFOpfExt) !== nothing
    @testset "Scientific review — candidate extraction independent of termination" begin
        ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
        J = ext.JuMP; MOI = J.MOI
        for (termination, primal) in ((MOI.TIME_LIMIT, MOI.FEASIBLE_POINT),
                                     (MOI.ALMOST_OPTIMAL, MOI.NEARLY_FEASIBLE_POINT),
                                     (MOI.ITERATION_LIMIT, MOI.INFEASIBLE_POINT),
                                     (MOI.TIME_LIMIT, MOI.NO_SOLUTION))
            mock = MOI.Utilities.MockOptimizer(MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()))
            model = J.direct_model(mock)
            vr = JuMP.@variable(model)
            vi = JuMP.@variable(model)
            JuMP.@objective(model, Min, vr)
            MOI.set(mock, MOI.SolveTimeSec(), 0.0)
            if primal == MOI.NO_SOLUTION
                MOI.Utilities.mock_optimize!(mock, termination)
            else
                MOI.Utilities.mock_optimize!(mock, termination, (primal, [230.0, 0.0]))
            end
            vars = Dict{Symbol,Any}(key=>Dict() for key in (:vr,:vi,:crg,:cig,:cr_gnd,:ci_gnd,
                :crd,:cid,:cr_fr,:ci_fr,:cr_to,:ci_to,:cr_sw,:ci_sw,:cr_xf,:ci_xf,
                :cri,:cii,:cr_nw,:ci_nw,:cr_src,:ci_src))
            vars[:vr] = Dict(("b","a")=>vr); vars[:vi] = Dict(("b","a")=>vi)
            net = Dict{String,Any}("bus"=>Dict("b"=>Dict("terminal_names"=>["a"])))
            r = ext._extract_results(model, net, Dict("b"=>["a"]), Set{Tuple{String,String}}(), vars)
            @test r["primal_status"] == string(primal)
            @test r["termination_status"] == string(termination)
            @test r["feasible"] == (primal in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT))
            if primal == MOI.NO_SOLUTION
                @test isnan(r["bus"]["b"]["a"]["vr"])
            else
                @test r["bus"]["b"]["a"]["vr"] == 230.0
                @test r["objective"] == 230.0
            end
        end
    end
end
