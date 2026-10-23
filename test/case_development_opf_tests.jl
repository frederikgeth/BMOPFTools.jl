using Test
include(joinpath(@__DIR__, "..", "examples", "case_development.jl"))

@testset "Worked case-development experiments" begin
    net, mf, rows = demand_pv_experiment()
    @test length(rows) == 3
    for row in rows
        @test row["status"] == "completed"
        @test row["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL", "ALMOST_LOCALLY_SOLVED")
        @test row["verification"]["summary"]["errors"] == 0
        @test row["metrics"]["pv_dispatch_w"] <= row["metrics"]["pv_available_w"] + 1.0
        @test row["metrics"]["p_loss"] >= -1e-6
        @test length(row["case_sha256"]) == 64
    end
    @test rows[1]["metrics"]["pv_available_w"] == 0.0
    @test rows[2]["metrics"]["pv_available_w"] > rows[3]["metrics"]["pv_available_w"]
    for row in placement_experiment()
        @test row["status"] == "completed"
        @test row["verification"]["summary"]["errors"] == 0
        @test row["placement"]["recipe"]["parameters"]["capacity_budget"] == 18000.0
    end
    controls = control_experiment()
    for row in controls
        @test row["status"] == "completed"
        @test row["verification"]["summary"]["errors"] == 0
    end
    # A feasible unity-PF solution also belongs to the coordinated P/Q box.
    # The observed local objective comparison is a fixture check, not a global claim.
    @test controls[1]["objective"] <= controls[2]["objective"] + 1e-4
    comparison = reduction_experiment()
    @test length(comparison.full["bus"]) > length(comparison.reduced["bus"])
    @test isempty(errors(comparison.verification))
    for bus in ("near", "far"), phase in ("1", "2", "3", "n")
        @test comparison.replay["bus"][bus][phase]["vr"] ≈
            comparison.reduced_result["bus"][bus][phase]["vr"] atol=1e-3
    end
end
