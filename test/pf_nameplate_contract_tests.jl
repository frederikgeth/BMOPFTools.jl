using Test, BMOPFTools, JuMP, Ipopt, JSON3

@testset "PF nameplate exception: one overloaded coil in a lightly loaded bank (#355)" begin
    net=BMOPFTools._deep_convert(Dict{String,Any}(
        "bus"=>Dict(b=>Dict("terminal_names"=>["a","b","c","n"],"perfectly_grounded_terminals"=>["n"]) for b in ("f","t")),
        "voltage_source"=>Dict("s"=>Dict("bus"=>"f","terminal_map"=>["a","b","c"],"v_magnitude"=>fill(230.,3),"v_angle"=>[0.,-2pi/3,2pi/3])),
        "transformer"=>Dict("single_phase"=>Dict("tx"=>Dict("bus_from"=>"f","bus_to"=>"t",
            "terminal_map_from"=>["a","b","c","n"],"terminal_map_to"=>["a","b","c","n"],
            "v_nom_from"=>230.,"v_nom_to"=>230.,"s_rating"=>100000.))),
        "load"=>Dict("d"=>Dict("bus"=>"t","terminal_map"=>["a","n"],"configuration"=>"SINGLE_PHASE",
            "model"=>"constant_impedance","v_nom"=>[230.],"p_nom"=>[40000.],"q_nom"=>[0.]))))
    for per_unit in (false,true)
        rated=solve_pf(net;optimizer=Ipopt.Optimizer,per_unit)
        @test rated["termination_status"]=="LOCALLY_INFEASIBLE"
        free=deepcopy(net);delete!(free["transformer"]["single_phase"]["tx"],"s_rating")
        free=JSON3.read(JSON3.write(free),Dict{String,Any})
        result=solve_pf(free;optimizer=Ipopt.Optimizer,per_unit)
        @test result["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
        @test result["load"]["d"]["a"]["pd"] ≈ 40000. atol=1e-3
        @test result["bus"]["t"]["a"]["vm"] ≈ 230. atol=1e-5
        @test net["transformer"]["single_phase"]["tx"]["s_rating"]==100000.
        # Below the per-coil cap the same rated network solves.
        for power in (30000.,100000/3)
            light=deepcopy(net);light["load"]["d"]["p_nom"]=[power]
            @test solve_pf(light;optimizer=Ipopt.Optimizer,per_unit)["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
        end
    end
end
