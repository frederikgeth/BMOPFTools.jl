# Independent numerical witness for unequal-kVA intake (#356).
using OpenDSSDirect, Ipopt
include(joinpath(@__DIR__, "roundtrip_helpers.jl"))

@testset "Unequal winding rating discrepancy against OpenDSS (#356)" begin
    path = joinpath(@__DIR__, "data", "pf_comparison", "pf_3wdg_unequal_kva.dss")
    net = from_dss(path)
    xf = net["transformer"]["n_winding"]["t1"]
    converged, reference_volts = ods_solve_volts(path)
    @test converged

    # Source node identities define the correspondence; drop only OpenDSS's
    # padded delta ground conductor, not a physical winding terminal.
    OpenDSSDirect.Circuit.SetActiveElement("Transformer.t1")
    ce = OpenDSSDirect.CktElement
    buses = lowercase.(first.(split.(ce.BusNames(), '.')))
    ncond = ce.NumConductors()
    order = ce.NodeOrder()
    source_nodes = [(buses[cld(i, ncond)], string(order[i])) for i in eachindex(order)]
    source_y = reshape(ce.YPrim(), length(order), length(order))
    labels = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    nodes, imported_y = BMOPFTools.nwinding_yprim(xf)
    target_nodes = [(bus, labels[terminal]) for (bus, terminal) in nodes]
    @test Set(target_nodes) == Set(node for node in source_nodes if node[2] != "0")
    permutation = [findfirst(==(node), source_nodes) for node in target_nodes]
    @test all(!isnothing, permutation)
    reference_y = source_y[permutation, permutation]
    relative_error(y) = maximum(abs.(y .- reference_y)) / maximum(abs.(reference_y))
    # PowerIO 0.11.1 alone gives ~0.342 relative error; intake recovery must
    # agree with the independent primitive, not the stale issue diagnosis.
    @test relative_error(imported_y) < 1e-6

    # An explicitly reconstructed copy using winding 1's kVA base also
    # matches the oracle, independently checking intake recovery. The value
    # comes from the declared source %R, voltage, and first-winding rating.
    reference_base = deepcopy(xf)
    reference_base["windings"][3]["r_winding"] = 0.008 * 400^2 / 20e6
    @test relative_error(BMOPFTools.nwinding_yprim(reference_base)[2]) < 1e-6

    result = solve_pf(net; optimizer=Ipopt.Optimizer)
    @test result["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    comparison = compare_volts(reference_volts, result_volts(result); atol=2.0, rtol=3e-3)
    @test isempty(comparison.missing_nodes)
    @test comparison.n_nodes_compared >= 9
    @test pf_ok(comparison)
end

@testset "DSS CVR powers against OpenDSS across voltage scales (#333)" begin
    source=read(joinpath(@__DIR__,"data","pf_comparison","pf_exp_1ph.dss"),String)
    for pu in (0.8,1.0,1.2), (gp,gq) in ((1.4,2.),(.4,3.1),(0.,0.))
        mktempdir() do dir
            path=joinpath(dir,"cvr.dss")
            write(path,replace(source,"pu=1.0"=>"pu=$pu",
                "CVRwatts=1.4 CVRvars=2.0"=>"CVRwatts=$gp CVRvars=$gq"))
            OpenDSSDirect.dss("redirect \"$path\"")
            @test OpenDSSDirect.Solution.Converged()
            OpenDSSDirect.Circuit.SetActiveElement("Load.ld1")
            volts=OpenDSSDirect.CktElement.Voltages()
            voltage=abs(volts[1]-volts[2])
            expected=sum(OpenDSSDirect.CktElement.Powers())*1000
            load=from_dss(path)["load"]["ld1"]
            actual=complex(BMOPFTools._load_model_power(load,"p",1,Float64(load["p_nom"][1]),voltage^2,240.),
                BMOPFTools._load_model_power(load,"q",1,Float64(load["q_nom"][1]),voltage^2,240.))
            @test actual ≈ expected rtol=1e-7 atol=1e-5
        end
    end
end
