using Test, BMOPFTools, LinearAlgebra, JSON3

# PSK-000013: independent component evidence, not a wider preservation claim.
# Minimized finite-bank witness: no load, source or fabricated bond impedance.
@testset "Open-delta shared copper bond in passive assembly" begin
    for (connection, shared) in (("ABBC", "b"), ("BCAC", "c"), ("CABA", "a")),
        regulator_type in ("A", "B"),
        tap in ([0.99, 1.02], [1.0, 1.0])

        net=parse_bmopf(
            read(joinpath(@__DIR__, "data", "open_delta_shared_bond.json"), String);
            from_string = true,
        )
        x=net["transformer"]["open_delta_regulator"]["t"]
        x["connection"]=connection
        x["regulator_type"]=regulator_type
        x["tap_ratio"]=tap
        original=deepcopy(net)
        y=ybus_passive(net)
        @test net==original
        @test y.index[("h", shared)]==y.index[("l", shared)]
        for t in setdiff(["a", "b", "c"], [shared])
            @test y.index[("h", t)]!=y.index[("l", t)]
        end
        @test y.index[("h", "n")]!=y.index[("l", "n")]
        @test y.Y≈transpose(y.Y)
        # Explicit source-to-target alias recovers arbitrary conductor voltages.
        v=ComplexF64[230cis(0.21k)+k for k in eachindex(y.nodes)]
        nodes, primitive=transformer_yprim(x, "open_delta_regulator")
        expected=zeros(ComplexF64, length(y.nodes))
        current=primitive*[v[y.index[node]] for node in nodes]
        for (node, i) in zip(nodes, current)
            expected[y.index[node]]+=i
        end
        @test y.Y*v≈expected atol=1e-9
        # A perfect earth on one endpoint grounds the entire copper identity.
        net["bus"]["l"]["perfectly_grounded_terminals"]=[shared]
        grounded=ybus_passive(net)
        @test grounded.index[("h", shared)]==grounded.index[("l", shared)]==0
        roundtrip=parse_bmopf(JSON3.write(net); from_string = true)
        @test ybus_passive(roundtrip).index==grounded.index
    end
    invalid=Dict{String,Any}("connection"=>"BAD")
    @test_throws ArgumentError BMOPFTools._open_delta_bond(invalid)
    renamed=Dict{String,Any}("connection"=>"ABBC","bus_from"=>"h","bus_to"=>"l",
        "terminal_map_from"=>["return","x","y","z"],
        "terminal_map_to"=>["return","x","y","z"])
    @test BMOPFTools._open_delta_bond(renamed;neutral_labels=Set(["return"])) ==
          (("h","y"),("l","y"))
end
