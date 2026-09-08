@testset "Piecewise-linear function API" begin
    xs = [253.0, 260.0]
    ys = [1.0, 0.2]

    @testset "exact numeric evaluation" begin
        @test piecewise_linear_value(250.0, xs, ys) == 1.0
        @test piecewise_linear_value(253.0, xs, ys) == 1.0
        @test piecewise_linear_value(256.5, xs, ys) ≈ 0.6 rtol=1e-12
        @test piecewise_linear_value(260.0, xs, ys) ≈ 0.2 rtol=1e-12
        @test piecewise_linear_value(265.0, xs, ys) ≈ 0.2 rtol=1e-12

        deadband_xs = [207.0, 220.0, 240.0, 258.0]
        deadband_ys = [0.44, 0.0, 0.0, -0.60]
        @test piecewise_linear_value(230.0, deadband_xs, deadband_ys) ≈ 0.0 atol=1e-14
    end

    @testset "smooth numeric evaluation" begin
        for u in (250.0, 256.5, 265.0)
            @test piecewise_linear_value(u, xs, ys; epsilon=1e-6) ≈
                  piecewise_linear_value(u, xs, ys) atol=1e-6
        end

        # Stable StatsFuns evaluation must remain finite even when |z/ε| is
        # far beyond the range at which a literal exp(z/ε) would overflow.
        @test isfinite(piecewise_linear_value(1.0e6, xs, ys; epsilon=1e-9))
        @test isfinite(piecewise_linear_value(-1.0e6, xs, ys; epsilon=1e-9))
    end

    @testset "Swish numeric evaluation" begin
        for u in (250.0, 256.5, 265.0)
            @test piecewise_linear_value(
                u, xs, ys; epsilon=1e-6, encoding=:swish) ≈
                piecewise_linear_value(
                    u, xs, ys; epsilon=1e-6, encoding=:softplus) atol=2e-6
        end

        # Swish remains finite when z/epsilon is far outside the exponential
        # range, and its signed negative tail is intentional.
        @test isfinite(piecewise_linear_value(
            -1.0e6, xs, ys; epsilon=1e-9, encoding=:swish))
        @test isfinite(piecewise_linear_value(
            1.0e6, xs, ys; epsilon=1e-9, encoding=:swish))
        @test piecewise_linear_value(
            251.7215, xs, ys; epsilon=1.0, encoding=:swish) > 1.0
    end

    @testset "validation" begin
        @test_throws ArgumentError piecewise_linear_value(1.0, [0.0], [1.0])
        @test_throws ArgumentError piecewise_linear_value(
            1.0, [0.0, 1.0], [1.0])
        @test_throws ArgumentError piecewise_linear_value(
            1.0, [0.0, 0.0], [1.0, 2.0])
        @test_throws ArgumentError piecewise_linear_value(
            1.0, [0.0, Inf], [1.0, 2.0])
        @test_throws ArgumentError piecewise_linear_value(
            1.0, [0.0, 1.0], [1.0, NaN])
        @test_throws ArgumentError piecewise_linear_value(
            Inf, [0.0, 1.0], [1.0, 2.0])
        @test_throws ArgumentError piecewise_linear_value(
            1.0, [0.0, 1.0], [1.0, 2.0]; epsilon=0.0)
        @test_throws ArgumentError piecewise_linear_value(
            1.0, [0.0, 1.0], [1.0, 2.0]; epsilon=Inf)
        @test_throws ArgumentError piecewise_linear_value(
            1.0, [0.0, 1.0], [1.0, 2.0]; epsilon=0.1, encoding=:unknown)
    end

    @testset "staged OPF expression and operator cache" begin
        if !_HAS_JUMP_IPOPT
            @test_skip "JuMP/Ipopt not in load path — skipping expression tests"
        else
            net = Dict{String,Any}(
                "bus" => Dict{String,Any}(
                    "b" => Dict{String,Any}(
                        "terminal_names" => ["1", "n"],
                        "perfectly_grounded_terminals" => ["n"],
                    ),
                ),
            )

            epsilon = 0.05
            for mode in (:user_defined, :builtin)
                ctx = initialize_opf_model(net; per_unit=false, softplus=mode)
                model = opf_model(ctx)
                input = JuMP.@variable(model)

                expr = opf_piecewise_linear_expression(
                    ctx, input, xs, ys; epsilon=epsilon)
                observed = JuMP.value(_ -> 256.5, expr)
                expected = piecewise_linear_value(
                    256.5, xs, ys; epsilon=epsilon)
                @test observed ≈ expected rtol=1e-12

                # Repeating an epsilon reuses one operator; a new epsilon adds
                # one. This is the scaling-critical behavior of the context API.
                opf_piecewise_linear_expression(
                    ctx, input, [0.0, 1.0], [0.0, 1.0]; epsilon=epsilon)
                @test length(ctx.relu_ops) == 1
                opf_piecewise_linear_expression(
                    ctx, input, [0.0, 1.0], [0.0, 1.0]; epsilon=0.1)
                @test length(ctx.relu_ops) == 2

                @test_throws ArgumentError opf_piecewise_linear_expression(
                    ctx, input, xs, ys; epsilon=0.0)
                @test_throws ArgumentError opf_piecewise_linear_expression(
                    ctx, input, [1.0, 1.0], ys; epsilon=epsilon)
            end

            function contains_head(expr, head::Symbol)
                expr isa JuMP.GenericNonlinearExpr &&
                    (expr.head == head || any(
                        arg -> contains_head(arg, head), expr.args))
            end

            swish_ctx = initialize_opf_model(
                net; per_unit=false, softplus=:swish)
            opfext = Base.get_extension(BMOPFTools, :BMOPFOpfExt)
            swish_input = JuMP.@variable(opf_model(swish_ctx))
            swish_expr = opf_piecewise_linear_expression(
                swish_ctx, swish_input, xs, ys; epsilon=epsilon)
            @test contains_head(swish_expr, :logistic)
            @test swish_ctx.relu_ops[epsilon] isa opfext.BuiltinSwish
            swish_provenance = opf_research_provenance(swish_ctx)
            @test swish_provenance["smoothing"]["softplus_mode"] == "swish"
            @test swish_provenance["smoothing"]["uses_native_logistic"] == true
            @test piecewise_linear_value(
                256.5, xs, ys; epsilon=epsilon, encoding=:swish) ≈
                  opfext.curve_value_smooth(
                      1.0, ((-0.8 / 7, 253.0), (0.8 / 7, 260.0)),
                      256.5, epsilon; encoding=:swish) rtol=1e-12

            @test_throws ArgumentError initialize_opf_model(
                net; per_unit=false, softplus=:unknown)

            flat_ctx = initialize_opf_model(net; per_unit=false)
            flat_input = JuMP.@variable(opf_model(flat_ctx))
            flat = opf_piecewise_linear_expression(
                flat_ctx, flat_input, [0.0, 1.0], [2.0, 2.0]; epsilon=0.1)
            @test flat == 2.0
            @test isempty(flat_ctx.relu_ops)
        end
    end
end
