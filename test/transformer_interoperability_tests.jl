# Issue #393: parser, build, and solved-physics assertions are separate layers.
using JSON3, LinearAlgebra, PowerIO, SHA

_interop_case(kind) = JSON3.read(read(joinpath(@__DIR__, "data",
    "transformer_interoperability", "$kind.json"), String), Dict{String,Any})
_interop_tx(net, kind) = net["transformer"][kind]["tx"]
_interop_parse(net) = parse_bmopf(JSON3.write(net); from_string=true)

@testset "Transformer exchange normalization (#393)" begin
    for kind in ("wye_delta", "delta_wye"), component in ("r", "x")
        raw = _interop_case(kind)
        x = _interop_tx(raw, kind)
        other = component == "r" ? "x" : "r"
        delete!(x, "$(other)_series")
        # Orthogonal split component is unambiguous and must be retained.
        x["$(other)_series_to"] = 0.03
        parsed = _interop_parse(raw)
        y = _interop_tx(parsed, kind)
        wye, delta = kind == "wye_delta" ? ("from", "to") : ("to", "from")
        @test y["$(component)_series_$wye"] == x["$(component)_series"]
        @test y["$(component)_series_$delta"] == 0.0
        @test y["$(other)_series_to"] == .03
        @test !haskey(y, "$(component)_series")
        @test haskey(x, "$(component)_series")
        @test BMOPFTools._normalize_bmopf!(deepcopy(parsed)) == parsed
        @test only(parsed["_meta"]["migration_notes"])["code"] == "W.MIGRATE.XFMR_SERIES_FIELDS"
        for side in ("from", "to"), value in (0.0, 0.4)
            conflict = deepcopy(raw)
            _interop_tx(conflict, kind)["$(component)_series_$side"] = value
            @test_throws ArgumentError _interop_parse(conflict)
        end
    end
    for kind in ("single_phase", "center_tap", "wye_delta", "delta_wye")
        for winding in 1:(kind == "center_tap" ? 3 : 2)
            raw = _interop_case(kind)
            _interop_tx(raw, kind)["no_load_shunt"] = Dict("winding"=>winding, "g"=>.002, "b"=>-.001)
            findings=Finding[]
            schema_result=schema_check(raw,findings)
            @test schema_result["jsonschema_valid"]
            @test !haskey(get(schema_result["unknown_fields_by_type"],"transformer/$kind",Dict()),"no_load_shunt")
            parsed = _interop_parse(raw)
            @test length(parsed["shunt"]) == 1
            @test !haskey(_interop_tx(parsed, kind), "no_load_shunt")
            @test BMOPFTools._normalize_bmopf!(deepcopy(parsed)) == parsed
            shunt=only(values(parsed["shunt"]))
            terminals=shunt["terminal_map"]
            volts=Dict(t => (t=="n" ? 2+.5im : (70+11*k)*cis(.3*k)) for (k,t) in enumerate(terminals))
            V=[volts[t] for t in terminals]
            Y=ComplexF64[complex(shunt["G_$(i)_$(j)"],shunt["B_$(i)_$(j)"])
                for i in eachindex(terminals),j in eachindex(terminals)]
            source_tm=_interop_tx(raw,kind)[winding==1 ? "terminal_map_from" : "terminal_map_to"]
            delta=kind=="wye_delta" && winding==2 || kind=="delta_wye" && winding==1
            pairs=kind=="center_tap" && winding>1 ? [(source_tm[winding-1],source_tm[winding])] :
                delta ? [(source_tm[k],source_tm[mod1(k+1,3)]) for k in 1:3] :
                [(t,"n") for t in source_tm if t!="n"]
            expected=(.002+.001im)*sum(abs2(volts[p]-volts[q]) for (p,q) in pairs)
            @test sum(V.*conj.(Y*V)) ≈ expected
            mktemp() do path, io
                close(io)
                write_bmopf(parsed, path)
                restored = parse_bmopf(path)
                @test restored["shunt"] == parsed["shunt"]
                @test restored["_meta"]["explicit_transformer_core_shunts"] ==
                    parsed["_meta"]["explicit_transformer_core_shunts"]
            end
            for bad in (Dict("winding"=>0,"g"=>.002,"b"=>0.),
                        Dict("winding"=>5,"g"=>.002,"b"=>0.),
                        Dict("winding"=>true,"g"=>.002,"b"=>0.),
                        Dict("winding"=>1,"g"=>-1.,"b"=>0.),
                        Dict("winding"=>1,"g"=>Inf,"b"=>0.))
                invalid = deepcopy(raw)
                _interop_tx(invalid, kind)["no_load_shunt"] = bad
                @test_throws ArgumentError BMOPFTools._normalize_bmopf!(invalid)
            end
            _interop_tx(raw, kind)["g_no_load"] = .002
            @test_throws ArgumentError _interop_parse(raw)
        end
    end
end

@testset "Legacy excitation exchange respects coil count and neutral labels" begin
    for ncoil in 1:3, numeric in (false, true), declared in (false, true)
        phases = numeric ? string.(1:ncoil) : ["a", "b", "c"][1:ncoil]
        neutral = numeric ? "4" : "n"
        terminals = vcat(phases, neutral)
        x = Dict{String,Any}("bus_from"=>"f", "bus_to"=>"t",
            "terminal_map_from"=>copy(terminals), "terminal_map_to"=>copy(terminals),
            "v_nom_from"=>400., "v_nom_to"=>200., "s_rating"=>10000.,
            "g_no_load"=>.002, "b_no_load"=>-.004)
        net = Dict{String,Any}("bus"=>Dict{String,Any}(b=>Dict{String,Any}("terminal_names"=>copy(terminals)) for b in ("f","t")),
            "transformer"=>Dict{String,Any}("single_phase"=>Dict{String,Any}("tx"=>x)))
        declared && (net["terminal_conventions"] = Dict("phase"=>phases, "neutral"=>[neutral], "earth"=>String[]))
        before = deepcopy(net)
        coil_voltage = ncoil == 1 ? 200. : 200/sqrt(3)
        pmd = to_pmd(net)["transformer"]["tx"]
        @test pmd["noloadloss"] ≈ .002*coil_voltage^2/10000
        @test pmd["cmag"] ≈ .004*coil_voltage^2/10000
        @test net == before

        for taps in ([1.,1.], [1.,1.03])
            source = Dict("transformer"=>Dict("tx"=>Dict("vm_nom"=>[.4,.2], "sm_nom"=>[10.,10.],
                "tm_set"=>[fill(taps[1],ncoil),fill(taps[2],ncoil)], "noloadloss"=>.002, "cmag"=>.004)))
            restored = deepcopy(net)
            BMOPFTools._normalize_transformer_no_load_shunts_from_pmd!(restored, JSON3.read(JSON3.write(source)))
            rx = restored["transformer"]["single_phase"]["tx"]
            @test rx["g_no_load"] ≈ .002*10000/(coil_voltage*taps[2])^2
            @test rx["b_no_load"] ≈ -.004*10000/(coil_voltage*taps[2])^2
        end
    end

    # A scalar legacy shunt cannot describe unequal coil taps, but a zero shunt
    # needs no base at all. Exercise the actual PMD recovery boundary separately
    # from PowerIO, whose DSS writer normally repeats one tap across a winding.
    for to_taps in (Float64[], [1.,1.03,1.]), losses in ((0.,0.), (.002,0.), (0.,.004))
        net = _interop_case("delta_wye")
        source = JSON3.read(JSON3.write(Dict("transformer"=>Dict("tx"=>Dict(
            "vm_nom"=>[.4,.2], "sm_nom"=>[10.,10.], "tm_set"=>[[1.,1.,1.],to_taps],
            "noloadloss"=>losses[1], "cmag"=>losses[2])))))
        if all(iszero, losses)
            BMOPFTools._normalize_transformer_no_load_shunts_from_pmd!(net, source)
            @test iszero(_interop_tx(net,"delta_wye")["g_no_load"])
            @test iszero(_interop_tx(net,"delta_wye")["b_no_load"])
        else
            @test_throws ArgumentError BMOPFTools._normalize_transformer_no_load_shunts_from_pmd!(net, source)
        end
    end
end

if _HAS_JUMP_IPOPT
    @testset "Working snapshots preserve typed arrays and private ownership" begin
        ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
        for timeseries in (false, true)
            raw = _interop_case("single_phase")
            raw["load"]["l1"]["p_nom"] = [250.0]
            raw["load"]["l1"]["q_nom"] = [65.0]
            raw["custom"] = Dict("matrix"=>[1. 2.; 3. 4.], "weights"=>[1.,2.])
            raw["typed_dict"] = Dict("gain"=>2.0)
            if timeseries
                raw["time_series"] = Dict("shape"=>Dict("values"=>[.5,1.5]))
                raw["load"]["l1"]["time_series"] = Dict("p_nom"=>"shape")
            end
            before = deepcopy(raw)
            working, _ = ext._prepare_working_net(raw, 2, false, 1e6)
            @test working["load"]["l1"]["p_nom"] isa Vector{Float64}
            @test working["load"]["l1"]["q_nom"] isa Vector{Float64}
            @test working["custom"]["weights"] isa Vector{Float64}
            @test working["custom"]["matrix"] isa Matrix{Float64}
            @test working["typed_dict"] isa Dict{String,Any}
            @test working["load"]["l1"]["p_nom"] == [timeseries ? 375. : 250.]
            @test !haskey(working,"time_series")
            working["custom"]["matrix"][1,1] = -1.
            working["custom"]["weights"][1] = -1.
            working["load"]["l1"]["p_nom"][1] = -1.
            @test raw == before
        end
        raw = Dict{String,Any}("bus"=>Dict("b"=>Dict("terminal_names"=>[1,4])))
        working, _ = ext._prepare_working_net(raw, 1, false, 1e6)
        @test working["bus"]["b"]["terminal_names"] == ["1","n"]
        @test raw["bus"]["b"]["terminal_names"] == [1,4]
    end

    @testset "Yd/Dy initialization anchors and permutations (#393, #365)" begin
        ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
        perms = (["a","b","c"], ["a","c","b"], ["b","a","c"],
                 ["b","c","a"], ["c","a","b"], ["c","b","a"])
        for kind in ("wye_delta", "delta_wye"), perm in perms,
            anchor in 0:3, tap in (1.0, 1.06), per_unit in (false, true)
            net = _interop_case(kind)
            x = _interop_tx(net, kind)
            x["tap"] = tap
            delete!(net, "load")
            delete!(x, "r_series"); delete!(x, "x_series")
            wye_from = kind == "wye_delta"
            wd, dd = wye_from ? ("f", "t") : ("t", "f")
            x[wye_from ? "terminal_map_to" : "terminal_map_from"] = perm
            net["bus"][dd]["perfectly_grounded_terminals"] = anchor == 0 ? String[] : [perm[anchor]]
            # Build-only fixture: prescribe a balanced wye source, allowing both
            # directions to exercise a floating/grounded delta without conflicting sources.
            net["voltage_source"]["s"] = Dict("bus"=>wd,"terminal_map"=>["a","b","c"],
                "v_magnitude"=>fill(200.,3), "v_angle"=>[.23,.23-2pi/3,.23+2pi/3])
            ctx = build_opf_model(net; per_unit, add_objective=false)
            startv(b,t) = complex(something(JuMP.start_value(ctx.vars[:vr][(b,t)]),0.),
                                    something(JuMP.start_value(ctx.vars[:vi][(b,t)]),0.))
            wx = _interop_tx(ctx.net, kind)
            ratio = BMOPFTools._xfmr_turns_ratio(wx)*tap
            neff = wye_from ? sqrt(3)/ratio : sqrt(3)*ratio
            # Exercise the standalone fallback too, after the compositional builder.
            ext._set_yd_dy_start_values!(ctx.vars, ctx.net, ctx.grounded)
            for k in 1:3
                ko = mod1(k + (wye_from ? 1 : -1), 3)
                @test startv(dd,perm[k])-startv(dd,perm[ko]) ≈
                    neff*(startv(wd,["a","b","c"][k])-startv(wd,"n")) atol=1e-7
            end
            before = [startv(dd,t) for t in perm]
            ext._set_yd_dy_start_values!(ctx.vars, ctx.net, ctx.grounded; set_voltage_starts=false)
            @test before == [startv(dd,t) for t in perm]
            @test all(isfinite, before)
            anchor == 0 || @test iszero(startv(dd,perm[anchor]))
            # Resistive current estimate must be in phase with winding voltage.
            sw = wye_from ? "fr" : "to"
            for (k,t) in enumerate(["a","b","c"])
                i = complex(JuMP.start_value(ctx.vars[:cr_xf][("tx",sw,k)]),
                            JuMP.start_value(ctx.vars[:ci_xf][("tx",sw,k)]))
                @test abs(imag(i*conj(startv(wd,t)))) < 1e-7
                @test real(i*conj(startv(wd,t))) >= 0
            end
        end
    end

    @testset "Dictionary and parser solved physics (#393)" begin
        options = ("print_level"=>0, "tol"=>1e-10, "bound_relax_factor"=>0.)
        ext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
        for kind in ("single_phase", "center_tap", "wye_delta", "delta_wye"),
            explicit in (false, true), per_unit in (false, true)
            raw = _interop_case(kind)
            explicit && (_interop_tx(raw,kind)["no_load_shunt"] = Dict("winding"=>2,"g"=>.002,"b"=>-.001))
            original = deepcopy(raw)
            parsed = _interop_parse(raw)
            a = solve_opf(raw; optimizer=Ipopt.Optimizer, per_unit, solver_options=options)
            b = solve_opf(parsed; optimizer=Ipopt.Optimizer, per_unit, solver_options=options)
            @test raw == original
            @test a["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            @test b["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
            volts(r,b,t) = complex(r["bus"][b][t]["vr"],r["bus"][b][t]["vi"])
            for (bus, record) in raw["bus"], terminal in record["terminal_names"]
                @test volts(a,bus,terminal) ≈ volts(b,bus,terminal) atol=1e-6
            end
            imported(r) = sum(v["ps"] for s in values(r["voltage_source"]) for v in values(s))
            @test imported(a) ≈ imported(b) atol=1e-6
            load_watts = sum(sum(l["p_nom"]) for l in values(raw["load"]))
            @test imported(a) > load_watts + .01
            # Independent KCL at the load-side nodes using I=YV plus explicit
            # coil admittance and specified constant-power load currents.
            nodes,Y = transformer_yprim(_interop_tx(parsed,kind),kind)
            V = [volts(a,b,t) for (b,t) in nodes]
            currents = Dict(nodes .=> (Y*V))
            for shunt in values(get(parsed,"shunt",Dict()))
                ts=shunt["terminal_map"]; bus=shunt["bus"]
                for i in eachindex(ts), j in eachindex(ts)
                    currents[(bus,ts[i])] += complex(shunt["G_$(i)_$(j)"],shunt["B_$(i)_$(j)"])*volts(a,bus,ts[j])
                end
            end
            for load in values(raw["load"])
                p,q=load["terminal_map"]; bus=load["bus"]
                i=conj(complex(only(load["p_nom"]),only(load["q_nom"]))/
                       (volts(a,bus,p)-volts(a,bus,q)))
                currents[(bus,p)]+=i;currents[(bus,q)]-=i
            end
            for t in setdiff(raw["bus"]["t"]["terminal_names"],raw["bus"]["t"]["perfectly_grounded_terminals"])
                @test abs(currents[("t",t)]) < 2e-6
            end
            # Staged preparation must see the same canonical electrical data.
            ctx=build_opf_model(raw; per_unit=false, add_objective=false)
            @test ctx.net["transformer"] == parsed["transformer"]
            @test get(ctx.net,"shunt",Dict()) == get(parsed,"shunt",Dict())
            explicit && @test ctx.net["_meta"]["explicit_transformer_core_shunts"] == parsed["_meta"]["explicit_transformer_core_shunts"]
        end
        raw=_interop_case("delta_wye")
        raw["time_series"]=Dict("shape"=>Dict("values"=>[.5,1.]))
        raw["load"]["l1"]["time_series"]=Dict("p_nom"=>"shape")
        ctx=build_opf_model(raw; t_index=2, per_unit=false,add_objective=false)
        @test ctx.net["transformer"] == _interop_parse(raw)["transformer"]
        conflict=_interop_case("delta_wye")
        _interop_tx(conflict,"delta_wye")["r_series_to"]=0.1
        @test_throws ArgumentError build_opf_model(conflict)
        @test_throws ArgumentError solve_opf(conflict;optimizer=Ipopt.Optimizer)
    end
end

@testset "PowerIO source preservation is distinct from normalization (#393)" begin
    for rated in (false,true)
        raw=_interop_case("delta_wye")
        rated || delete!(_interop_tx(raw,"delta_wye"),"s_rating")
        mktempdir() do dir
            path=joinpath(dir,"case.json");write(path,JSON3.write(raw))
            module_=PowerIO.parse(path)
            audit=BMOPFTools._powerio_audit_input(module_)
            emission=PowerIO.emit(module_,"bmopf-json")
            @test emission.fidelity == "exact_same_format"
            diagnostics=vcat(module_.diagnostics,emission.diagnostics)
            codes=[d.code for d in diagnostics]
            @test ("READ.BMOPF.VALUE_DEFAULTED" in codes) == !rated
            preserved=JSON3.read(emission.text,Dict{String,Any})
            px=_interop_tx(preserved,"delta_wye")
            @test px["r_series"]==.1 && px["x_series"]==.08
            @test !haskey(px,"r_series_to")
            typed=only(audit.data.transformers)
            if rated
                # Wye-side Zbase=200²/10000=4 Ω; total r%=2.5, x%=2.
                @test sum(w.r_pct for w in typed.windings)≈2.5
                @test only(typed.xsc_pct)≈2.0
            else
                @test all(iszero(w.r_pct) for w in typed.windings)
                @test all(iszero,typed.xsc_pct)
            end
            normalized=_interop_parse(preserved)
            @test _interop_tx(normalized,"delta_wye")["r_series_to"]==.1
            @test _interop_tx(normalized,"delta_wye")["x_series_to"]==.08
            @info "PowerIO transformer witness" rated codes input_sha256=bytes2hex(SHA.sha256(read(path))) binding=BMOPFTools.powerio_version() binary_version=PowerIO.library_version() binary_sha256=bytes2hex(SHA.sha256(read(module_.handle.lib)))
        end
    end
end

@testset "N-winding legacy excitation remains per coil (#279)" begin
    x=Dict{String,Any}("windings"=>[
        Dict("bus"=>"f","terminal_map"=>["a","b","c","n"],"configuration"=>"WYE","v_nom"=>240.,"r_winding"=>.1),
        Dict("bus"=>"t","terminal_map"=>["a","b","c","n"],"configuration"=>"WYE","v_nom"=>120.,"r_winding"=>.025)],
        "x_sc"=>Dict("1_2"=>.1),"s_rating"=>10000.,"g_no_load"=>.002,"b_no_load"=>-.001)
    nodes,Y=BMOPFTools.nwinding_yprim(x)
    no_shunt=deepcopy(x);delete!(no_shunt,"g_no_load");delete!(no_shunt,"b_no_load")
    _,Y0=BMOPFTools.nwinding_yprim(no_shunt)
    V=ComplexF64[(t=="n" ? 2+.5im : 100*cis(.3*k)) for (k,(b,t)) in enumerate(nodes)]
    n=findfirst(==(("t","n")),nodes)
    expected=(.002+.001im)*sum(abs2(V[findfirst(==(("t",t)),nodes)]-V[n]) for t in ["a","b","c"])
    @test sum(V.*conj.((Y-Y0)*V)) ≈ expected
end

if _HAS_JUMP_IPOPT
    @testset "Center-tap fixed and variable-ratio branches (#393)" begin
        for per_unit in (false,true), tap in (.95,1.06), zero_arm in ("none","from","to")
            net=_interop_case("center_tap");x=_interop_tx(net,"center_tap");x["tap"]=tap
            if zero_arm!="none"
                x["r_series_$zero_arm"]=0.;x["x_series_$zero_arm"]=0.
            end
            options=("print_level"=>0,"tol"=>1e-10,"bound_relax_factor"=>0.)
            fixed=solve_opf(net;optimizer=Ipopt.Optimizer,per_unit,solver_options=options)
            free=deepcopy(net);fx=_interop_tx(free,"center_tap");fx["tap_min"]=.9;fx["tap_max"]=1.1
            variable=solve_opf(free;optimizer=Ipopt.Optimizer,per_unit,solver_options=options,
                model_hook! = ctx -> begin
                    ratio=BMOPFTools._xfmr_turns_ratio(_interop_tx(ctx.net,"center_tap"))*tap
                    JuMP.set_lower_bound(ctx.vars[:tap]["tx"],ratio)
                    JuMP.set_upper_bound(ctx.vars[:tap]["tx"],ratio)
                end)
            for r in (fixed,variable)
                @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
                v(b,t)=complex(r["bus"][b][t]["vr"],r["bus"][b][t]["vi"])
                vh=v("f","p")-v("f","n");v1=v("t","x1")-v("t","n");v2=v("t","n")-v("t","x2")
                # Inferred winding currents from prescribed loads; explicitly
                # not counted as independent observed internal currents.
                i1=-conj((250+65im)/v1);i2=conj((500+130im)/v2)
                N=2*tap;ip=(i2-i1)/N
                z1=tap^2*complex(x["r_series_from"],x["x_series_from"])
                z2=complex(x["r_series_to"],x["x_series_to"])
                @test vh-N*v1 ≈ z1*ip-N*z2*i1 atol=1e-6
                @test vh-N*v2 ≈ z1*ip+N*z2*i2 atol=1e-6
                imported=sum(v["ps"] for s in values(r["voltage_source"]) for v in values(s))
                @test imported-750 ≈ real(z1)*abs2(ip)+real(z2)*(abs2(i1)+abs2(i2)) atol=1e-6
            end
            for t in ("x1","n","x2")
                @test fixed["bus"]["t"][t]["vr"] ≈ variable["bus"]["t"][t]["vr"] atol=1e-6
                @test fixed["bus"]["t"][t]["vi"] ≈ variable["bus"]["t"][t]["vi"] atol=1e-6
            end
        end
    end
end
