using Test, BMOPFTools, LinearAlgebra, JSON3

# Small native witnesses shared by the sequential subtype support tests.
function _leakage_net(kind; z=0.0, ratio=2.0, tap=1.0)
    x=Dict{String,Any}("bus_from"=>"f", "bus_to"=>"t",
        "terminal_map_from"=>["a","n"], "terminal_map_to"=>["a","n"],
        "v_nom_from"=>230ratio, "v_nom_to"=>230., "tap"=>tap,
        "r_series_from"=>z, "r_series_to"=>z,
        "tap_ratio"=>tap, "regulator_type"=>"A")
    if kind=="center_tap"
        x["terminal_map_to"]=["a","n","b"]
    elseif kind in ("wye_delta","delta_wye","open_delta_regulator")
        x["terminal_map_from"]=kind=="wye_delta" ? ["a","b","c","n"] : ["a","b","c"]
        x["terminal_map_to"]=kind=="delta_wye" ? ["a","b","c","n"] : ["a","b","c"]
        if kind=="open_delta_regulator"
            x["connection"]="ABBC"; x["tap_ratio"]=[tap,tap]
        end
    end
    buses=Dict{String,Any}(b=>Dict{String,Any}("terminal_names"=>copy(x["terminal_map_"*s]),
        "perfectly_grounded_terminals"=>String[]) for (b,s) in (("f","from"),("t","to")))
    if kind=="n_winding"
        x=Dict{String,Any}("windings"=>[
            Dict{String,Any}("bus"=>b,"terminal_map"=>["a","n"],"v_nom"=>v,
                "configuration"=>"WYE","r_winding"=>z) for (b,v) in (("f",230ratio),("t",230.))],
                "x_sc"=>Dict{String,Any}("1_2"=>0.))
    end
    Dict{String,Any}("bus"=>buses,"transformer"=>Dict(kind=>Dict("x"=>x))),x
end
_leakage_config(z) = Dict("domain_rules"=>Dict("xfmr_z_min_ohm"=>z))

@testset "Ybus nominal-voltage domain (PSK-000002)" begin
    for kind in ("single_phase", "center_tap", "wye_delta", "delta_wye"),
        z in (0., 1e-9, .01), key in ("v_nom_from", "v_nom_to"),
        value in (nothing, 0., -230., true, "230", Inf, NaN)
        net, x = _leakage_net(kind; z)
        value === nothing ? delete!(x, key) : (x[key] = value)
        before = deepcopy(net)
        for builder in (ybus_passive, ybus_linearized, ybus_augmented)
            @test_throws ArgumentError builder(net)
        end
        @test_throws ArgumentError ybus_augmented(net; ideal_xfmrs=:stamp)
        @test_throws ArgumentError transformer_yprim(x, kind)
        @test_throws ArgumentError transformer_yprim(x, kind; shunt_only=true)
        @test isequal(net, before)
        if value !== Inf && !isequal(value, NaN)
            rt = JSON3.read(JSON3.write(net), Dict{String,Any})
            @test_throws ArgumentError ybus_augmented(rt)
        end
    end
    # Positive boundaries may be tiny, but an unrepresentable ratio is refused.
    net, x = _leakage_net("single_phase")
    for v in (nextfloat(0.), 230., floatmax(Float64))
        x["v_nom_from"] = x["v_nom_to"] = v
        @test length(ybus_augmented(net).couplings) == 1
    end
    for (a, b) in ((nextfloat(0.), floatmax(Float64)), (floatmax(Float64), nextfloat(0.)))
        x["v_nom_from"] = a; x["v_nom_to"] = b
        @test_throws ArgumentError ybus_augmented(net)
    end
    # The minimized shunt witness formerly acquired a fictitious unity ratio.
    witness = JSON3.read(read(joinpath(@__DIR__, "data", "ideal_transformer_shunts.json"), String), Dict{String,Any})
    witness["transformer"]["single_phase"]["t"]["v_nom_to"] = 0.
    @test_throws ArgumentError ybus_augmented(witness)
end

@testset "Transformer leakage representation policy (#453)" begin
    for kind in ("single_phase","wye_delta","delta_wye","center_tap",
                 "single_phase_autotransformer","open_delta_regulator","n_winding")
        for tap in (0.95,1.,1.05), factor in (0.,.5,1.,2.,1e4)
            net,x=_leakage_net(kind;z=1.,tap)
            # Normalize on the declared reference basis, not raw input ohms.
            v=minimum(abs.(BMOPFTools._xfmr_leakage_values(x,kind)))
            net,x=_leakage_net(kind;z=factor*1e-6/v,tap)
            p=BMOPFTools._xfmr_leakage_policy(x,kind,1e-6)
            # Boundary uses exactly the computed floating-point impedance.
            bound=minimum(abs.(p.impedances))
            @test BMOPFTools._xfmr_leakage_policy(x,kind,bound).needs_border
            bound>0 && @test !BMOPFTools._xfmr_leakage_policy(x,kind,prevfloat(bound)).needs_border
            @test p.exact_zero == (factor==0)
            before=deepcopy(net)
            if p.needs_border
                @test_throws ArgumentError ybus_passive(net)
                @test_throws ArgumentError ybus_linearized(net)
                @test_throws ArgumentError ybus_augmented(net;ideal_xfmrs=:stamp)
                if kind in ("single_phase","wye_delta","delta_wye")
                    r=ybus_augmented(net); n=length(r.nodes)
                    @test length(r.couplings)==(kind=="single_phase" ? 1 : 3)
                    @test Matrix(r.K[n+1:end,n+1:end]) ≈ -only(p.impedances)*I
                    @test r.index[("f","a")] != r.index[("t","a")]
                else
                    @test_throws ArgumentError ybus_augmented(net)
                end
            else
                r=ybus_passive(net)
                @test all(isfinite,r.Y)
                @test ybus_augmented(net).K ≈ r.Y
            end
            rt=JSON3.read(JSON3.write(net),Dict{String,Any})
            @test BMOPFTools._xfmr_leakage_policy(rt["transformer"][kind]["x"],kind,1e-6)==p
            @test net==before
        end
        net,x=_leakage_net(kind;z=.01)
        for invalid in (-1.,Inf,NaN,true,"small")
            @test_throws ArgumentError ybus_passive(net;config=_leakage_config(invalid))
            @test_throws ArgumentError ybus_augmented(net;config=_leakage_config(invalid))
        end
        @test_throws ArgumentError ybus_passive(net;config=_leakage_config(10.))
        if kind!="n_winding"
            x["r_series_from"]=NaN
            @test_throws ArgumentError ybus_augmented(net)
        end
    end
    # Tiny finite leakage is retained exactly: Schur elimination reproduces
    # the ordinary finite primitive, even below the default threshold.
    for kind in ("single_phase","wye_delta","delta_wye"), ratio in (1.,2.),tap in (.95,1.05)
        net,x=_leakage_net(kind;z=1e-9,ratio,tap)
        r=ybus_augmented(net); n=length(r.nodes); K=Matrix(r.K)
        Y=K[1:n,1:n]-K[1:n,n+1:end]*(K[n+1:end,n+1:end]\K[n+1:end,1:n])
        @test Y ≈ Matrix(ybus_passive(net;config=_leakage_config(0.)).Y)
        @test K ≈ transpose(K)
    end
end
