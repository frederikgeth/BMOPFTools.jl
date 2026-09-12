# Independent OpenDSS primitive oracle for #393. Source %R/X and bases are
# declared in package-owned DSS fixtures; no BMOPF stamp builds the oracle.
using OpenDSSDirect, PowerIO, SHA

function _interop_ods_primitive(nodes)
    OpenDSSDirect.Circuit.SetActiveElement("Transformer.tx")
    ce = OpenDSSDirect.CktElement
    buses = first.(split.(lowercase.(ce.BusNames()), '.'))
    order = ce.NodeOrder()
    ncond = ce.NumConductors()
    source_nodes = [(buses[cld(i,ncond)], string(order[i])) for i in eachindex(order)]
    source_y = reshape(ce.YPrim(), length(order), length(order))
    # Explicit terminal identity map, including repeated center-tap terminals.
    A = [a == b ? 1.0 : 0.0 for a in source_nodes, b in nodes]
    @test Set(source_nodes) == Set(nodes) || Set(filter(n->n[2]!="0",source_nodes)) == Set(nodes)
    transpose(A) * source_y * A
end

@testset "OpenDSS one-, two-, and three-coil wye excitation bases" begin
    template = read(joinpath(@__DIR__,"data","transformer_interoperability","wye_bank.dss"),String)
    for ncoil in 1:3
        phases = string.(1:ncoil)
        nodes = join(phases,'.')
        source = replace(template, "phases=3"=>"phases=$ncoil",
            "f.1.2.3.4"=>"f.$nodes.4", "t.1.2.3.4"=>"t.$nodes.4")
        mktempdir() do dir
            path = joinpath(dir,"bank.dss")
            write(path,source)
            OpenDSSDirect.dss("redirect \"$path\"")
            OpenDSSDirect.Circuit.SetActiveElement("transformer.tx")
            Y0 = reshape(OpenDSSDirect.CktElement.YPrim(),2*(ncoil+1),2*(ncoil+1))
            excitation = "\nedit transformer.tx %noloadloss=.2 %imag=.4\nsolve\n"
            OpenDSSDirect.dss(excitation)
            OpenDSSDirect.Circuit.SetActiveElement("transformer.tx")
            Y1 = reshape(OpenDSSDirect.CktElement.YPrim(),size(Y0))
            oracle = (Y1-Y0)[ncoil+2:end,ncoil+2:end]
            write(path,source*excitation)
            module_ = PowerIO.parse(path)
            for neutral in ("n","4")
                terminals = vcat(phases,neutral)
                x = Dict{String,Any}("bus_from"=>"f", "bus_to"=>"t",
                    "terminal_map_from"=>copy(terminals), "terminal_map_to"=>copy(terminals),
                    "v_nom_from"=>400., "v_nom_to"=>200., "s_rating"=>10000.)
                net = Dict{String,Any}("bus"=>Dict{String,Any}(b=>Dict{String,Any}("terminal_names"=>copy(terminals)) for b in ("f","t")),
                    "transformer"=>Dict{String,Any}("single_phase"=>Dict{String,Any}("tx"=>x)),
                    "terminal_conventions"=>Dict("phase"=>phases,"neutral"=>[neutral],"earth"=>String[]))
                BMOPFTools._normalize_transformer_no_load_shunts!(net,(;module_))
                A = hcat(Matrix{Float64}(I,ncoil,ncoil),fill(-1.,ncoil))
                recovered = complex(x["g_no_load"],x["b_no_load"])/ncoil * (transpose(A)*A)
                @test recovered ≈ oracle rtol=1e-9 atol=1e-11
                V = ComplexF64[(70+13*k)*cis(.3*k) for k in 1:ncoil+1]
                @test sum(V.*conj.(recovered*V)) ≈ sum(V.*conj.(oracle*V)) rtol=1e-9 atol=1e-8
                exported = to_pmd(net)["transformer"]["tx"]
                @test exported["noloadloss"] ≈ .002
                @test exported["cmag"] ≈ .004
            end
        end
    end
end

function _interop_manual_ods(kind, tap; excitation=false)
    net = _interop_case(kind)
    x = _interop_tx(net,kind)
    for field in ("r_series","x_series")
        pop!(x,field,nothing)
    end
    vf,vt=x["v_nom_from"],x["v_nom_to"]
    x["tap"]=tap
    # DSS fixture: each winding %R=1; XHL=4 (CT: XHT=XLT=4 too).
    x["r_series_from"]=.01*vf^2/10000
    x["x_series_from"]=.02*vf^2/10000
    x["r_series_to"]=.01*vt^2/10000
    x["x_series_to"]=.02*vt^2/10000
    x["terminal_map_from"]=kind in ("single_phase","center_tap") ? ["1","n"] :
        kind=="wye_delta" ? ["1","2","3","n"] : ["1","2","3"]
    x["terminal_map_to"]=kind=="center_tap" ? ["1","n","2"] :
        kind=="single_phase" ? ["1","n"] :
        kind=="delta_wye" ? ["1","2","3","n"] : ["1","2","3"]
    if excitation
        coil_voltage = kind=="delta_wye" ? vt/sqrt(3) : vt
        # Legacy total across the winding-2 coils; center tap has one such coil.
        x["g_no_load"] = .002*10000/coil_voltage^2
        x["b_no_load"] = -.004*10000/coil_voltage^2
    end
    x
end

function _interop_add_shunts!(Y, nodes, net; aliases=Dict("a"=>"1","b"=>"2","c"=>"3","n"=>"4"))
    for shunt in values(get(net,"shunt",Dict()))
        ts=shunt["terminal_map"];bus=shunt["bus"]
        for i in eachindex(ts),j in eachindex(ts)
            a=findfirst(==((bus,get(aliases,ts[i],ts[i]))),nodes)
            b=findfirst(==((bus,get(aliases,ts[j],ts[j]))),nodes)
            Y[a,b] += complex(shunt["G_$(i)_$(j)"],shunt["B_$(i)_$(j)"])
        end
    end
    Y
end

@testset "OpenDSS nominal transformer bases and excitation (#393, #279)" begin
    @info "Transformer interoperability oracle" julia=string(VERSION) powerio=BMOPFTools.powerio_version() opendss=OpenDSSDirect.Basic.Version()
    aliases=Dict("a"=>"1","b"=>"2","c"=>"3","n"=>"4")
    for kind in ("single_phase","center_tap","wye_delta","delta_wye"),
        tap in (.95,1.0,1.06), excitation in (false,true)
        path=joinpath(@__DIR__,"data","transformer_interoperability","$kind.dss")
        source=read(path,String)*"\nedit transformer.tx wdg=1 tap=$tap"*
            (excitation ? " %noloadloss=.2 %imag=.4" : "")*"\nsolve\n"
        mktempdir() do dir
            p=joinpath(dir,"case.dss");write(p,source)
            OpenDSSDirect.dss("redirect \"$p\"")
            x=_interop_manual_ods(kind,tap;excitation)
            nodes,Y=transformer_yprim(x,kind)
            nodes=[(b,get(aliases,t,t)) for (b,t) in nodes]
            reference=_interop_ods_primitive(nodes)
            @test norm(Y-reference,Inf) <= 1e-11*norm(reference,Inf)
            # Arbitrary, unbalanced prescribed node voltages exercise every
            # column and terminal; no solver termination enters this assertion.
            V=ComplexF64[(50+17*k)*cis(.31*k) for k in eachindex(nodes)]
            @test Y*V ≈ reference*V rtol=1e-11 atol=1e-9
            @test sum(V.*conj.(Y*V)) ≈ sum(V.*conj.(reference*V)) rtol=1e-11 atol=1e-7
            imported=from_dss(p)
            ix=only(values(imported["transformer"][kind]))
            inode,I=transformer_yprim(ix,kind)
            inode=[(b,get(aliases,t,t)) for (b,t) in inode]
            _interop_add_shunts!(I,inode,imported)
            permutation=[findfirst(==(n),inode) for n in nodes]
            @test all(!isnothing,permutation)
            @test I[permutation,permutation] ≈ reference rtol=1e-11 atol=1e-10
            @test haskey(imported["_meta"],"powerio_diagnostics")
            @test haskey(imported["meta"],"\$schema")
            if excitation
                @test length(imported["shunt"])==1
                @test !haskey(ix,"g_no_load") # explicit imported excitation
                # Difference isolates the per-winding core loss independently.
                zero=deepcopy(x);delete!(zero,"g_no_load");delete!(zero,"b_no_load")
                _,Y0=transformer_yprim(zero,kind)
                loss=sum(V.*conj.((Y-Y0)*V))
                @test real(loss)>0 && imag(loss)>0
                if kind != "center_tap"
                    tiny=Dict{String,Any}("bus"=>Dict(b=>Dict("terminal_names"=>tm) for (b,tm) in
                        (("f",x["terminal_map_from"]),("t",x["terminal_map_to"]))),
                        "transformer"=>Dict{String,Any}(kind=>Dict{String,Any}("tx"=>x)))
                    pmd=to_pmd(BMOPFTools._deep_convert(tiny))["transformer"]["tx"]
                    @test pmd["noloadloss"]≈.002
                    @test pmd["cmag"]≈.004
                end
            end
        end
    end
end

@testset "Loaded imported OpenDSS states at fixed taps (#393)" begin
    aliases=Dict("a"=>"1","b"=>"2","c"=>"3","n"=>"4")
    for kind in ("single_phase","center_tap","wye_delta","delta_wye"), tap in (.95,1.06)
        path=joinpath(@__DIR__,"data","transformer_interoperability","$kind.dss")
        # Add references and loads before the first solve: the passive
        # primitive fixture intentionally contains floating winding neutrals.
        source=replace(read(path,String), "\nSolve\n"=>"\n")*
            "\nedit transformer.tx wdg=1 tap=$tap %noloadloss=.2 %imag=.4\n"
        # Solid source/secondary neutrals avoid conflating the Vsource's earth
        # conductor with a separate finite-grounded neutral on the same bus.
        source=replace(source,"f.1.4"=>"f.1.0", "f.1.2.3.4"=>"f.1.2.3.0",
            "t.1.4"=>"t.1.0", "t.4.2"=>"t.0.2", "t.1.2.3.4"=>"t.1.2.3.0")
        kind=="wye_delta" && (source*="new reactor.gt phases=1 bus1=t.3 bus2=t.0 r=.001 x=0\n")
        pairs=kind=="single_phase" ? [("1","0")] : kind=="center_tap" ? [("1","0"),("2","0")] :
            kind=="wye_delta" ? [("1","2"),("2","3"),("3","1")] : [("1","0"),("2","0"),("3","0")]
        kv=kind in ("single_phase","center_tap") ? .12 : kind=="wye_delta" ? .2 : .2/sqrt(3)
        for (k,(p,q)) in enumerate(pairs)
            source*="new load.l$k phases=1 bus1=t.$p.$q kv=$kv kw=$(0.25*k) kvar=$(0.065*k) model=1 vminpu=0 vmaxpu=2\n"
        end
        source*="set voltagebases=[$(kind in ("single_phase","center_tap") ? ".24,.12" : ".4,.2")]\ncalcvoltagebases\nset maxiterations=100\nsolve\n"
        mktempdir() do dir
            p=joinpath(dir,"loaded.dss");write(p,source)
            OpenDSSDirect.dss("redirect \"$p\"")
            @test OpenDSSDirect.Solution.Converged()
            reference=Dict(lowercase.(OpenDSSDirect.Circuit.AllNodeNames()) .=> OpenDSSDirect.Circuit.AllBusVolts())
            net=from_dss(p)
            # BMOPF sources prescribe terminal phasors; DSS Vsource has finite
            # impedance. Supply its observed source phasors so both solves have
            # the same boundary condition, without loosening the comparison.
            for vs in values(net["voltage_source"])
                grounded=get(net["bus"][vs["bus"]],"perfectly_grounded_terminals",String[])
                V=[t in grounded ? 0.0im : reference["$(vs["bus"]).$(get(aliases,t,t))"] for t in vs["terminal_map"]]
                vs["v_magnitude"]=abs.(V)
                vs["v_angle"]=angle.(V)
            end
            # Retain ratings: these deliberately light loads do not bind them.
            result=solve_opf(net;optimizer=Ipopt.Optimizer,per_unit=true,
                solver_options=("print_level"=>0,"tol"=>1e-10,"bound_relax_factor"=>0.))
            @test result["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            compared=0
            for (bus,values) in result["bus"], (terminal,v) in values
                node="$bus.$(get(aliases,terminal,terminal))"
                haskey(reference,node) || continue
                @test complex(v["vr"],v["vi"]) ≈ reference[node] atol=2e-5 rtol=1e-7
                compared+=1
            end
            @test compared>=(kind=="single_phase" ? 2 : kind=="center_tap" ? 3 : 6)
        end
    end
end

@testset "Three-phase wye-bank legacy excitation compatibility (#279)" begin
    path=joinpath(@__DIR__,"data","transformer_interoperability","wye_bank.dss")
    for primary_tap in (.95,1.06), secondary_tap in (1.,1.03)
        source=read(path,String)*"\nedit transformer.tx wdg=1 tap=$primary_tap %noloadloss=.2 %imag=.4\nedit transformer.tx wdg=2 tap=$secondary_tap\nsolve\n"
        mktempdir() do dir
            p=joinpath(dir,"bank.dss");write(p,source)
            module_=PowerIO.parse(p)
            # PowerIO currently splits a Yy bank into separate single-phase
            # records. Exercise the supported multi-pair BMOPF representation
            # explicitly against the original PMD bank's voltage/power bases.
            net=_interop_case("delta_wye")
            x=_interop_tx(net,"delta_wye")
            x["terminal_map_from"]=["a","b","c","n"]
            net["transformer"]=Dict{String,Any}("single_phase"=>Dict{String,Any}("tx"=>x))
            BMOPFTools._normalize_transformer_no_load_shunts!(net,(;module_))
            coil_voltage=200/sqrt(3)*secondary_tap
            @test x["g_no_load"] ≈ .002*10000/coil_voltage^2
            @test x["b_no_load"] ≈ -.004*10000/coil_voltage^2
            # Legacy bank totals and the explicit per-coil representation must
            # have identical winding-2 admittance at arbitrary phase voltages.
            V=ComplexF64[110+3im,-50-95im,-60+92im,2+im]
            power=conj(complex(x["g_no_load"],x["b_no_load"]))/3 * sum(abs2.(V[1:3].-V[4]))
            @test real(power)>0 && imag(power)>0
        end
    end
end
