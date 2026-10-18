using Test, BMOPFTools, JuMP, Ipopt, JSON3

# Independent current/voltage witnesses; linked to PSK-000013 through executable.toml.
_rating_ct() = JSON3.read(read(joinpath(@__DIR__, "data", "transformer_current_ratings",
    "center_tap.json"), String), Dict{String,Any})
_rating_x(net) = net["transformer"]["center_tap"]["tx"]
_rating_v(r,b,t) = complex(r["bus"][b][t]["vr"], r["bus"][b][t]["vi"])
_rating_i(r,side,k) = complex(r["transformer"]["tx"][side][string(k)]["cr"],
                              r["transformer"]["tx"][side][string(k)]["ci"])
_rating_policy(mode) = mode == :si ? OpfScaling(:si) : mode == :classic ?
    OpfScaling(:classic) : OpfScaling(name=:rating_local,
        voltage_bases=Dict("f"=>240.0,"t"=>120.0),
        power_bases=Dict("f"=>10000.0,"t"=>1000.0))

function _rating_solve(net, mode; free=false, tap=1.0)
    n=deepcopy(net); x=_rating_x(n); x["tap"]=tap
    free && (x["tap_min"]=0.9; x["tap_max"]=1.1)
    solve_opf(n; scaling_policy=_rating_policy(mode),
        solver_options=("tol"=>1e-10,"constr_viol_tol"=>1e-10,"bound_relax_factor"=>0.0),
        model_hook! = ctx -> if free
            ratio=BMOPFTools._xfmr_turns_ratio(_rating_x(ctx.net))*tap
            set_lower_bound(ctx.vars[:tap]["tx"],ratio)
            set_upper_bound(ctx.vars[:tap]["tx"],ratio)
        end)
end

@testset "Transformer current-rating contracts (#116)" begin
    @testset "center-tap physical currents, cancellation and coordinate covariance" begin
        for mode in (:si,:classic,:local), tap in (0.95,1.06),
            zero_arm in (nothing,"from","to"), excitation in (false,true)
            net=_rating_ct(); x=_rating_x(net)
            if zero_arm !== nothing
                x["r_series_$zero_arm"]=0.0; x["x_series_$zero_arm"]=0.0
            end
            if !excitation
                x["g_no_load"]=0.0; x["b_no_load"]=0.0
            end
            before=deepcopy(net)
            fixed=_rating_solve(net,mode;tap)
            variable=_rating_solve(net,mode;free=true,tap)
            for r in (fixed,variable)
                @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
                vh=_rating_v(r,"f","p")-_rating_v(r,"f","n")
                v1=_rating_v(r,"t","x1")-_rating_v(r,"t","n")
                v2=_rating_v(r,"t","x2")-_rating_v(r,"t","n")
                # Prescribed load powers independently fix total winding-terminal
                # currents. The legacy excitation is already inside that boundary.
                i1=-conj((250.0+65.0im)/v1)
                i2=-conj((500.0+130.0im)/v2)
                mag=complex(x["g_no_load"],x["b_no_load"])*v1
                series1=i1-mag; n=2*tap; ip=(i2-series1)/n
                for (side,k,expected) in (("fr",1,ip),("fr",2,-ip),
                    ("to",1,i1),("to",2,-i1-i2),("to",3,i2))
                    @test _rating_i(r,side,k) ≈ expected atol=2e-6 rtol=2e-6
                end
                z1=tap^2*complex(x["r_series_from"],x["x_series_from"])
                z2=complex(x["r_series_to"],x["x_series_to"])
                @test vh-n*v1 ≈ z1*ip-n*z2*series1 atol=2e-5
                @test vh+n*v2 ≈ z1*ip+n*z2*i2 atol=2e-5
                if excitation
                    @test abs(series1) > 3.0 # invalid to impose terminal cap here
                    @test abs(i1) < 3.0       # physical point remains admissible
                end
                # Terminal power counts excitation once; compare to load and
                # source powers rather than reusing the package's Yprim helper.
                loss=vh*conj(ip)+v1*conj(i1)+v2*conj(i2)
                @test loss ≈ z1*abs2(ip)+z2*(abs2(series1)+abs2(i2))+
                    conj(complex(x["g_no_load"],x["b_no_load"]))*abs2(v1) atol=2e-5
                @test r["losses"]["p_loss"] ≈ real(loss) atol=2e-5
                @test r["losses"]["q_loss"] ≈ imag(loss) atol=2e-5
                restored=JSON3.read(JSON3.write(r),Dict{String,Any})
                @test _rating_i(restored,"to",1) == _rating_i(r,"to",1)
            end
            for side in ("fr","to"), k in 1:(side=="fr" ? 2 : 3)
                @test _rating_i(fixed,side,k) ≈ _rating_i(variable,side,k) atol=2e-6 rtol=2e-6
            end
            @test net == before
        end
    end

    @testset "center-tap cap boxes and all five thermal rows" begin
        for mode in (:si,:classic,:local), free in (false,true), cap in (7.0,0.0,Inf,nothing)
            n=_rating_ct(); x=_rating_x(n)
            for (field,count) in (("i_max_from",2),("i_max_to",3))
                cap === nothing ? delete!(x,field) : (x[field]=fill(cap,count))
            end
            free && (x["tap_min"]=0.9;x["tap_max"]=1.1)
            c=build_opf_model(n;scaling_policy=_rating_policy(mode))
            for (side,label,count,field) in (("fr","from",2,"i_max_from"),("to","to",3,"i_max_to"))
                for k in 1:count
                    for family in (:cr_xf,:ci_xf)
                        v=c.vars[family][("tx",side,k)]
                        @test has_lower_bound(v) == (cap!==nothing && isfinite(cap) && cap>0)
                        @test has_upper_bound(v) == (cap!==nothing && isfinite(cap) && cap>0)
                        if cap!==nothing && isfinite(cap) && cap>0
                            working=_rating_x(c.net)[field][k]
                            @test lower_bound(v) ≈ -working
                            @test upper_bound(v) ≈ working
                        end
                    end
                    key=OpfModelKey(:constraint,:transformer_current_thermal,("tx",label,k))
                    # Infinite caps are explicit no-ops and not registered.
                    @test (key in opf_object_keys(c)) == (cap!==nothing && isfinite(cap))
                    if cap===0.0
                        row=constraint_object(opf_object(c,key))
                        @test row.set isa MOI.Zeros
                    elseif cap!==nothing && isfinite(cap)
                        row=constraint_object(opf_object(c,key))
                        cr=c.vars[:cr_xf][("tx",side,k)]
                        ci=c.vars[:ci_xf][("tx",side,k)]
                        working=_rating_x(c.net)[field][k]
                        # Exact physical boundary (3-4-5 triangle), then outside;
                        # this checks the row independently of solver termination.
                        for (factor,expected) in ((1.0,1.0),(1.1,1.21))
                            val=value(v -> v==cr ? 0.6*working*factor :
                                v==ci ? 0.8*working*factor : error("unexpected variable"), row.func)
                            @test val ≈ expected
                        end
                    end
                end
            end
        end
        for field in ("i_max_from","i_max_to"), cap in (-1.0,NaN,-Inf)
            n=_rating_ct(); _rating_x(n)[field]=[cap]
            @test_throws ArgumentError build_opf_model(n)
        end
    end

    @testset "external core shunts retain their separate current boundary" begin
        for mode in (:si,:classic,:local), free in (false,true)
            legacy=_rating_ct(); _rating_x(legacy)["i_max_to"]=fill(20.0,3)
            external=deepcopy(legacy); x=_rating_x(external)
            g=pop!(x,"g_no_load"); b=pop!(x,"b_no_load")
            x["no_load_shunt"]=Dict("winding"=>2,"g"=>g,"b"=>b)
            # Exercise the existing normalized representation, without changing
            # parsing: its separate shunt is outside the winding-current cap.
            a=_rating_solve(legacy,mode;free)
            z=_rating_solve(external,mode;free)
            @test a["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            @test z["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            v1=_rating_v(a,"t","x1")-_rating_v(a,"t","n")
            mag=complex(g,b)*v1
            for (bus,terminals) in (("f",("p","n")),("t",("x1","n","x2")))
                for t in terminals
                    @test _rating_v(a,bus,t) ≈ _rating_v(z,bus,t) atol=2e-6
                end
            end
            @test _rating_i(a,"fr",1) ≈ _rating_i(z,"fr",1) atol=2e-6
            @test _rating_i(a,"to",1) ≈ _rating_i(z,"to",1)+mag atol=2e-6
            @test _rating_i(a,"to",2) ≈ _rating_i(z,"to",2)-mag atol=2e-6
            @test _rating_i(a,"to",3) ≈ _rating_i(z,"to",3) atol=2e-6
            @test abs(_rating_i(a,"to",1)) < 3 < abs(_rating_i(z,"to",1))
        end
    end

    @testset "zero-current feasible point and genuinely free tap" begin
        for mode in (:si,:classic,:local), free in (false,true)
            net=_rating_ct(); delete!(net,"load"); x=_rating_x(net)
            x["g_no_load"]=0.0; x["b_no_load"]=0.0
            x["i_max_from"]=zeros(2); x["i_max_to"]=zeros(3)
            free && (x["tap_min"]=0.9; x["tap_max"]=1.1)
            c=build_opf_model(net;scaling_policy=_rating_policy(mode))
            # All five zero caps introduce redundant equalities; Ipopt can reject
            # the equation count before solving. Check the independently known
            # no-load point against every model row and bound instead.
            point=Dict(v=>0.0 for v in all_variables(c.model))
            vh=only(c.net["voltage_source"]["s"]["v_magnitude"])*cis(0.23)
            ratio=BMOPFTools._xfmr_turns_ratio(_rating_x(c.net))
            for (bus,t,v) in (("f","p",vh),("t","x1",vh/ratio),("t","x2",-vh/ratio))
                point[c.vars[:vr][(bus,t)]]=real(v)
                point[c.vars[:vi][(bus,t)]]=imag(v)
            end
            free && (point[c.vars[:tap]["tx"]]=ratio)
            @test isempty(primal_feasibility_report(c.model,point;atol=1e-8))
        end
        for mode in (:si,:classic,:local)
            net=_rating_ct(); x=_rating_x(net); x["tap_min"]=0.9; x["tap_max"]=1.1
            r=solve_opf(net;scaling_policy=_rating_policy(mode),
                solver_options=("tol"=>1e-10,"bound_relax_factor"=>0.0))
            @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            v1=_rating_v(r,"t","x1")-_rating_v(r,"t","n")
            @test _rating_i(r,"to",1) ≈ -conj((250+65im)/v1) atol=2e-6
            @test abs(_rating_i(r,"to",1)) <= 3.0+1e-7
        end
    end

    @testset "HV neutral and LV ratings independently reject over-cap points" begin
        for free in (false,true), mode in (:si,:classic),
            (field,k,cap) in (("i_max_from",2,0.1),("i_max_to",1,1.0),("i_max_to",2,0.1))
            n=_rating_ct(); _rating_x(n)[field][k]=cap
            r=_rating_solve(n,mode;free)
            @test r["termination_status"] ∉ ("LOCALLY_SOLVED","OPTIMAL")
            # Positive solved controls and independent currents are above; a
            # local solver failure by itself is not an infeasibility certificate.
        end
    end

    @testset "bound helper preserves tighter boxes and zero-cap equalities" begin
        e=Base.get_extension(BMOPFTools,:BMOPFOpfExt)
        m=Model(); cr=@variable(m,lower_bound=-2.0,upper_bound=3.0)
        ci=@variable(m,lower_bound=-4.0,upper_bound=5.0)
        e._limit_current_box!(cr,ci,10.0)
        @test (lower_bound(cr),upper_bound(cr),lower_bound(ci),upper_bound(ci)) == (-2.,3.,-4.,5.)
        e._limit_current_box!(cr,ci,2.5)
        @test (lower_bound(cr),upper_bound(cr),lower_bound(ci),upper_bound(ci)) == (-2.,2.5,-2.5,2.5)
    end

    @testset "subtype/side coverage matrix preserves expression-cap exceptions" begin
        for kind in ("single_phase","wye_delta","delta_wye",
                     "single_phase_autotransformer","open_delta_regulator"),
            excitation in (false,true), pu in (false,true)
            if kind in ("single_phase","wye_delta","delta_wye")
                net=JSON3.read(read(joinpath(@__DIR__,"data","transformer_interoperability",
                                           "$kind.json"),String),Dict{String,Any})
                x=net["transformer"][kind]["tx"]
            else
                phases=kind=="open_delta_regulator" ? ["a","b","c","n"] : ["a","n"]
                net=Dict{String,Any}("bus"=>Dict(b=>Dict("terminal_names"=>phases,
                    "perfectly_grounded_terminals"=>["n"]) for b in ("f","t")))
                x=Dict{String,Any}("bus_from"=>"f","bus_to"=>"t",
                    "terminal_map_from"=>phases,"terminal_map_to"=>phases,
                    "regulator_type"=>"B","r_series_from"=>0.1,"x_series_from"=>0.2)
                x["tap_ratio"]=kind=="open_delta_regulator" ? [1.02,1.03] : 1.02
                kind=="open_delta_regulator" && (x["connection"]="ABBC")
                net["transformer"]=Dict(kind=>Dict("tx"=>x))
            end
            x["g_no_load"]=excitation ? 0.001 : 0.0
            x["b_no_load"]=excitation ? -0.002 : 0.0
            for field in ("i_max_from","i_max_to")
                x[field]=fill(17.0,4)
            end
            c=build_opf_model(net;per_unit=pu)
            for (side,label,field) in (("fr","from","i_max_from"),("to","to","i_max_to"))
                count=kind in ("single_phase","single_phase_autotransformer") ? 1 :
                    kind=="open_delta_regulator" ? 2 : length(x[side=="fr" ? "terminal_map_from" : "terminal_map_to"])
                expression_cap=excitation && ((kind=="single_phase" && side=="to") ||
                    (kind=="single_phase_autotransformer" && side=="fr"))
                for k in 1:count
                    @test OpfModelKey(:constraint,:transformer_current_thermal,("tx",label,k)) in opf_object_keys(c)
                    for family in (:cr_xf,:ci_xf)
                        v=c.vars[family][("tx",side,k)]
                        @test has_upper_bound(v) == !expression_cap
                        @test has_lower_bound(v) == !expression_cap
                        if !expression_cap
                            cap=c.net["transformer"][kind]["tx"][field][k]
                            @test upper_bound(v) ≈ cap
                            @test lower_bound(v) ≈ -cap
                        end
                    end
                end
                # Single-phase return conductors and regulator bonds do not
                # acquire an extra independently rated coil from trailing entries.
                if kind in ("single_phase","single_phase_autotransformer")
                    @test OpfModelKey(:constraint,:transformer_current_thermal,("tx",label,2)) ∉ opf_object_keys(c)
                end
                if side=="fr" && kind in ("single_phase_autotransformer","open_delta_regulator")
                    bond=kind=="single_phase_autotransformer" ? 2 : 3
                    @test OpfModelKey(:constraint,:transformer_current_thermal,("tx",label,bond)) ∉ opf_object_keys(c)
                    for family in (:cr_xf,:ci_xf)
                        @test !has_upper_bound(c.vars[family][("tx",side,bond)])
                        @test !has_lower_bound(c.vars[family][("tx",side,bond)])
                    end
                end
            end
        end
        for configuration in ("WYE","DELTA"), pu in (false,true)
            tm=configuration=="WYE" ? ["a","b","c","n"] : ["a","b","c"]
            net=Dict{String,Any}("bus"=>Dict(b=>Dict("terminal_names"=>tm) for b in ("f","t")),
                "transformer"=>Dict("n_winding"=>Dict("tx"=>Dict(
                    "s_rating"=>10000.0, "x_sc"=>Dict("1_2"=>0.1),
                    "windings"=>[Dict("bus"=>b,"terminal_map"=>tm,"v_nom"=>v,
                        "configuration"=>configuration,"r_winding"=>0.01,"i_max"=>17.0)
                        for (b,v) in (("f",240.0),("t",120.0))]))))
            c=build_opf_model(net;per_unit=pu)
            for winding in 1:2, k in 1:3, family in (:cr_nw,:ci_nw)
                v=c.vars[family][("tx",winding,k)]
                cap=c.net["transformer"]["n_winding"]["tx"]["windings"][winding]["i_max"]
                @test upper_bound(v) ≈ cap
                @test lower_bound(v) ≈ -cap
                @test OpfModelKey(:constraint,:nwind_current_thermal,("tx",winding,k)) in opf_object_keys(c)
            end
        end
    end
end
