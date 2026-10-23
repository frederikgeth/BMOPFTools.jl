using Test, BMOPFTools, JuMP, Ipopt, JSON3

# PSK-000013: independent physical evidence for the existing cyclic-pair model.
# No stamping/result helper or PowerOptLab dependency supplies the oracle.
function tl95_fixture(name="unbalanced")
    net = JSON3.read(read(joinpath(@__DIR__, "data", "three_leg_physics",
                                  name * ".json"), String), Dict{String,Any})
    target = pop!(net, "_test_targets")
    return net, complex.(target["pair_p_W"], target["pair_q_var"])
end

function tl95_oracle(net, S)
    src = net["voltage_source"]["source"]
    by_terminal = Dict(zip(src["terminal_map"],
        src["v_magnitude"] .* cis.(src["v_angle"])))
    tm = net["ibr"]["inv"]["terminal_map"]
    V = [by_terminal[t] for t in tm]
    U = V - V[[2,3,1]]
    J = conj.(S ./ U)                 # cyclic pair injections
    I = J - J[[3,1,2]]                # external conductor injections
    return (; V, U, J, I)
end

function tl95_policies()
    [OpfScaling(:si), OpfScaling(:classic; power_base=1e4),
     OpfScaling(:classic; power_base=1e6),
     OpfScaling(power_base=2e4, voltage_bases=Dict("b"=>115.0)),
     OpfScaling(power_base=8e4, voltage_bases=Dict("b"=>460.0)),
     OpfScaling(power_bases=Dict("b"=>3e4), voltage_bases=Dict("b"=>200.0)),
     OpfScaling(power_bases=Dict("b"=>9e4), voltage_bases=Dict("b"=>500.0))]
end

function tl95_model(net, S, policy)
    ctx = build_opf_model(net; scaling_policy=policy, add_objective=false)
    bases = opf_coordinate_bases(ctx, "b")
    # Prescribe independent pair powers through public registered auxiliaries.
    for k in 1:3
        inv = net["ibr"]["inv"]
        zero_cap = any(f -> haskey(inv,f) && iszero(inv[f][k]), ("s_max","i_max"))
        if zero_cap && iszero(S[k])
            # A zero norm cap already implies P=Q=0. Adding six more exact
            # equalities can exceed Ipopt's count of available degrees of freedom.
            continue
        end
        p = opf_object(ctx, opf_ibr_power_key("inv", k))
        q = opf_object(ctx, opf_ibr_power_key("inv", k; component=:reactive))
        @constraint(ctx.model, p == real(S[k])/bases.power)
        @constraint(ctx.model, q == imag(S[k])/bases.power)
    end
    enforce_kcl!(ctx)
    set_silent(ctx.model)
    set_optimizer_attribute(ctx.model, "tol", 1e-12)
    set_optimizer_attribute(ctx.model, "constr_viol_tol", 1e-12)
    set_optimizer_attribute(ctx.model, "bound_relax_factor", 0.0)
    set_optimizer_attribute(ctx.model, "acceptable_iter", 0)
    set_optimizer_attribute(ctx.model, "nlp_scaling_method", "none")
    return ctx
end

function tl95_transform(net, S, angle, order)
    n = deepcopy(net)
    inv = n["ibr"]["inv"]; src = n["voltage_source"]["source"]
    for field in ("terminal_map", "p_min", "p_max", "q_min", "q_max", "s_max", "i_max")
        haskey(inv,field) && (inv[field] = inv[field][order])
    end
    n["bus"]["b"]["terminal_names"] = inv["terminal_map"]
    for field in ("terminal_map", "v_magnitude", "v_angle")
        src[field] = src[field][order]
    end
    src["v_angle"] .+= angle
    return n, S[order]
end

function tl95_candidate(net,S)
    o = tl95_oracle(net,S)
    rows = Dict(t => Dict("pg"=>real(S[k]), "qg"=>imag(S[k]),
                         "cri"=>real(o.J[k]), "cii"=>imag(o.J[k]))
                for (k,t) in enumerate(net["ibr"]["inv"]["terminal_map"]))
    # Deliberately supplied candidate: its claimed status is not evidence.
    Dict{String,Any}("termination_status"=>"LOCALLY_SOLVED", "ibr"=>Dict("inv"=>rows))
end

function tl95_solve(ctx)
    resolve_opf!(ctx)
    r = extract_result(ctx)
    @test r["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    return r
end

function tl95_check(net, S, r)
    o = tl95_oracle(net, S)
    tm = net["ibr"]["inv"]["terminal_map"]
    rows = r["ibr"]["inv"]
    @test Set(keys(rows)) == Set(tm)
    J = ComplexF64[]; Is = ComplexF64[]; Vs = ComplexF64[]; Ss = ComplexF64[]
    for (k,t) in enumerate(tm)
        row = rows[t]; src = r["voltage_source"]["source"][t]
        v = r["bus"]["b"][t]
        push!(J, complex(row["cri"], row["cii"]))
        push!(Is, complex(src["cr"], src["ci"]))
        push!(Vs, complex(v["vr"], v["vi"]))
        push!(Ss, complex(src["ps"], src["qs"]))
        @test complex(row["pg"], row["qg"]) ≈ S[k] atol=2e-5 rtol=2e-8
    end
    # Physical tolerances scale with the excitation, never the numerical PU base.
    itol = 2e-7 * max(1.0, maximum(abs, o.I))
    stol = 2e-7 * max(1.0, sum(abs, S))
    @test Vs ≈ o.V atol=2e-7 rtol=2e-9
    @test J ≈ o.J atol=itol rtol=2e-8
    @test Is ≈ -o.I atol=itol rtol=2e-8 # independent native source variables
    @test maximum(abs, Is + J - J[[3,1,2]]) <= itol
    @test abs(sum(Is)) <= 3itol
    @test (Vs - Vs[[2,3,1]]) .* conj.(J) ≈ S atol=stol rtol=2e-8
    @test Ss ≈ -o.V .* conj.(o.I) atol=stol rtol=2e-8
    @test abs(sum(Ss) + sum(S)) <= stol
    @test abs(sum(Vs .* conj.(-Is)) - sum(S)) <= stol
    findings = Finding[]
    @test solution_check(net, r, findings)["n_inv_violations"] == 0
    return (; J, Is, S)
end

# Evaluate the actual model row at the independently prescribed physical point.
# This detects a wrong pair index, sign, omitted cap or unit conversion without
# using local solver failure as an infeasibility certificate.
function tl95_row_residual(ctx, net, S, family, k)
    b = opf_coordinate_bases(ctx, "b")
    o = tl95_oracle(net, S)
    vals = Dict{JuMP.VariableRef,Float64}()
    for (j,t) in enumerate(net["ibr"]["inv"]["terminal_map"])
        vals[ctx.vars[:vr][("b",t)]] = real(o.V[j])/b.voltage
        vals[ctx.vars[:vi][("b",t)]] = imag(o.V[j])/b.voltage
        vals[ctx.vars[:cri][("inv",j)]] = real(o.J[j])/b.current
        vals[ctx.vars[:cii][("inv",j)]] = imag(o.J[j])/b.current
        vals[opf_object(ctx, opf_ibr_power_key("inv",j))] = real(S[j])/b.power
        vals[opf_object(ctx, opf_ibr_power_key("inv",j; component=:reactive))] = imag(S[j])/b.power
    end
    c = constraint_object(opf_object(ctx, OpfModelKey(:constraint, family, ("inv",k))))
    x = value(v -> vals[v], c.func)
    if c.set isa JuMP.MOI.LessThan
        return x - c.set.upper
    elseif c.set isa JuMP.MOI.GreaterThan
        return c.set.lower - x
    elseif c.set isa JuMP.MOI.Zeros
        return maximum(abs, x)
    else
        error("Unexpected THREE_LEG constraint set $(typeof(c.set))")
    end
end

@testset "Independent THREE_LEG physics (#95)" begin
    @testset "zero-current warm-start regression through solve_opf" begin
        for policy in tl95_policies()
            net,S = tl95_fixture("zero_current")
            r = solve_opf(net; scaling_policy=policy)
            @test r["termination_status"] in ("LOCALLY_SOLVED","OPTIMAL")
            tl95_check(net,S,r)
        end
    end
    @testset "balanced/unbalanced SI, PU, bases, source KCL and JSON" begin
        for name in ("balanced", "unbalanced"), policy in tl95_policies()
            net, S = tl95_fixture(name)
            original = deepcopy(net)
            o = tl95_oracle(net, S)
            if name == "unbalanced"
                @test maximum(abs.(o.V)) - minimum(abs.(o.V)) > 40
                @test maximum(abs.(o.I)) - minimum(abs.(o.I)) > 1
                @test any(real.(S) .< 0) && any(imag.(S) .< 0)
            else
                # Conductor current is sqrt(3) times pair current here. This
                # point must stay feasible: i_max constrains J, not I.
                net["ibr"]["inv"]["i_max"] = 1.2 .* abs.(o.J)
                @test all(abs.(o.I) .> net["ibr"]["inv"]["i_max"])
                original = deepcopy(net)
            end
            r = tl95_solve(tl95_model(net, S, policy))
            tl95_check(net, S, r)
            roundtrip = JSON3.read(JSON3.write(r), Dict{String,Any})
            tl95_check(net, S, roundtrip)
            @test net == original
        end
    end

    @testset "rotation and cyclic pair relabeling" begin
        for policy in tl95_policies()
            net, S = tl95_fixture()
            original = tl95_check(net, S, tl95_solve(tl95_model(net, S, policy)))
            for (angle, order) in ((0.37, [1,2,3]), (0.0, [2,3,1]), (-0.41, [3,1,2]))
                n, _ = tl95_transform(net,S,angle,order)
                changed = tl95_check(n, S[order], tl95_solve(tl95_model(n, S[order], policy)))
                @test changed.J ≈ original.J[order] .* cis(angle) atol=2e-6 rtol=2e-8
                @test changed.Is ≈ original.Is[order] .* cis(angle) atol=2e-6 rtol=2e-8
                @test sum(changed.S) ≈ sum(original.S) atol=1e-10
            end
        end
    end

    @testset "unequal per-pair capability: inside, on and beyond" begin
        families = (("p_min", :ibr_p_lower), ("p_max", :ibr_p_upper),
                    ("q_min", :ibr_q_lower), ("q_max", :ibr_q_upper),
                    ("s_max", :ibr_power_circle), ("i_max", :ibr_current_thermal))
        for policy in tl95_policies(), (field,family) in families, k in 1:3
            net, _ = tl95_fixture()
            inv = net["ibr"]["inv"]
            # Isolate one unequal rating family; all other limits are absent.
            ratings = (occursin("min",field) ? -1 : 1) .* [400.0, 700.0, 1000.0]
            field == "i_max" && (ratings = [1.5, 2.5, 4.0])
            for (f,_) in families
                delete!(inv, f)
            end
            inv[field] = ratings
            for factor in (0.8, 1.0, 1.2)
                S = zeros(ComplexF64,3)
                target = factor * ratings[k]
                S[k] = startswith(field,"q") ? im*target :
                       field == "s_max" ? target*(0.8+0.6im) :
                       field == "i_max" ? target*abs(tl95_oracle(net,S).U[k])*(0.6-0.8im) : target
                ctx = tl95_model(net, S, policy)
                residual = tl95_row_residual(ctx, net, S, family, k)
                # Scale-free signed excess must equal the analytic boundary.
                scale = field in ("s_max","i_max") ? 1.0 : abs(ratings[k])/opf_coordinate_bases(ctx,"b").power
                expected = field in ("s_max","i_max") ? factor^2-1 : factor-1
                @test residual/scale ≈ expected atol=1e-10
                supplied = tl95_candidate(net,S)
                findings = Finding[]
                @test solution_check(net,supplied,findings)["n_inv_violations"] == (factor>1 ? 1 : 0)
                violations = filter(f -> f.code in ("E.SOL.IBR_VIOLATION","E.SOL.IBR_Q_VIOLATION"), findings)
                if factor > 1
                    v = only(violations)
                    @test v.detail["terminal"] == inv["terminal_map"][k]
                    @test v.code == (startswith(field,"q") ? "E.SOL.IBR_Q_VIOLATION" : "E.SOL.IBR_VIOLATION")
                end
                restored = JSON3.read(JSON3.write(supplied),Dict{String,Any})
                restored_findings = Finding[]
                solution_check(net,restored,restored_findings)
                @test [(f.code,f.detail) for f in restored_findings] == [(f.code,f.detail) for f in findings]
                # Other pairs carry zero, and hence cannot inherit this rating.
                for j in setdiff(1:3,[k])
                    @test tl95_row_residual(ctx,net,S,family,j) < 0
                end
                if factor <= 1
                    tl95_check(net,S,tl95_solve(ctx))
                else
                    @test residual > 0 # explicit model contradiction at the prescribed point
                end
                if k == 1
                    # Limits and decisions transform with their oriented pairs.
                    order = [2,3,1]
                    rotated, Sr = tl95_transform(net,S,0.37,order)
                    cr = tl95_model(rotated,Sr,policy)
                    @test tl95_row_residual(cr,rotated,Sr,family,3)/scale ≈ expected atol=1e-10
                    fr = Finding[]
                    @test solution_check(rotated,tl95_candidate(rotated,Sr),fr)["n_inv_violations"] == (factor>1 ? 1 : 0)
                end
            end
        end
    end

    @testset "zero and missing limits retain their distinct meanings" begin
        for policy in tl95_policies(), field in ("p_min", "p_max", "q_min", "q_max", "s_max", "i_max")
            net, S = tl95_fixture()
            inv = net["ibr"]["inv"]
            for f in ("p_min","p_max","q_min","q_max","s_max","i_max")
                delete!(inv,f)
            end
            # No declared capability rows: a finite nonzero operating point.
            ctx = tl95_model(net,S,policy)
            for family in (:ibr_p_lower,:ibr_p_upper,:ibr_q_lower,:ibr_q_upper,
                           :ibr_power_circle,:ibr_current_thermal)
                @test !(OpfModelKey(:constraint,family,("inv",1)) in opf_object_keys(ctx))
            end
            tl95_check(net,S,tl95_solve(ctx))
            inv[field] = zeros(3)
            Z = zeros(ComplexF64,3)
            ctx = tl95_model(net,Z,policy)
            tl95_check(net,Z,tl95_solve(ctx))
            family = Dict("p_min"=>:ibr_p_lower,"p_max"=>:ibr_p_upper,
                "q_min"=>:ibr_q_lower,"q_max"=>:ibr_q_upper,
                "s_max"=>:ibr_power_circle,"i_max"=>:ibr_current_thermal)[field]
            @test tl95_row_residual(ctx,net,Z,family,1) == 0
            sign = endswith(field,"min") ? -1 : 1
            @test tl95_row_residual(ctx,net,fill(sign*(1.0+1im),3),family,1) > 0
        end
        for policy in tl95_policies(), field in ("s_max","i_max"), k in 1:3
            net,S = tl95_fixture()
            net["ibr"]["inv"][field][k] = 0.0
            S[k] = 0.0
            @test abs(tl95_oracle(net,S).I[k]) > 0.1
            tl95_check(net,S,tl95_solve(tl95_model(net,S,policy)))
        end
    end
end
