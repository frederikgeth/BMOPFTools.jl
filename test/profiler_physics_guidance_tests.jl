using Test, BMOPFTools, JSON3, LinearAlgebra

_guidance_case(name) = JSON3.read(read(joinpath(@__DIR__, "data", "profiler_evidence", name), String), Dict{String,Any})
function _guidance_matrices(net)
    lc = net["linecode"]["four_wire"]
    R = [lc["R_series_$(i)_$(j)"] for i in 1:4, j in 1:4]
    X = [lc["X_series_$(i)_$(j)"] for i in 1:4, j in 1:4]
    R, X, complex.(R, X)
end
_guidance_ids(record, field) = Set(h["id"] for h in record[field])

@testset "phase-block symmetry retains explicit neutral information" begin
    net = _guidance_case("balanced_phase_four_wire.json"); original = deepcopy(net)
    R, X, Z = _guidance_matrices(net)
    @test isposdef(R) && isposdef(X)
    fs = Finding[]
    lc = BMOPFTools._classify_linecodes(net, fs)
    seq = only(filter(f -> f.code == "I.PROV.SEQ_DERIVED", fs))
    obs = seq.detail["interpretation"]["observations"]["by_linecode"]["four_wire"]
    @test lc["by_linecode"]["four_wire"]["verdict"] == "exactly_balanced"
    @test obs["n_conductors"] == 4
    @test obs["phase_block_only"]
    @test obs["additional_conductor_coupling_ratio"] > 0
    @test "retained_conductors" in _guidance_ids(seq.detail["interpretation"], "implications")
    @test !("neutral_inside_z0" in _guidance_ids(seq.detail["interpretation"], "implications"))
    # Sequence values cannot produce an explicit, separately coupled neutral.
    @test first(seq.detail["interpretation"]["possible_explanations"])["id"] == "transposition_assumption"
    @test occursin("sequence values cannot produce an explicit neutral", seq.message)
    # Independent Ohm's-law witness: a symmetric phase block can still produce
    # neutral displacement and phase-to-neutral unbalance through the fourth wire.
    Iph = [1, cis(-2pi/3), cis(2pi/3)]
    I4 = vcat(Iph, -sum(Iph))
    Vto = vcat(230 .* Iph, 0) - Z*I4
    @test abs(Vto[4]) ≈ sqrt(0.28)
    mags = abs.(Vto[1:3] .- Vto[4])
    @test maximum(mags)-minimum(mags) > 0.8
    @test net == original
    serialized = JSON3.read(JSON3.write(explain_finding(seq)))
    @test serialized.interpretation.observations.by_linecode.four_wire.phase_block_only
    @test serialized.interpretation.observations.by_linecode.four_wire.n_conductors == 4
    decoupled_extra = deepcopy(net)
    for i in 1:3, p in ("R", "X")
        decoupled_extra["linecode"]["four_wire"]["$(p)_series_$(i)_4"] = 0.0
        decoupled_extra["linecode"]["four_wire"]["$(p)_series_4_$(i)"] = 0.0
    end
    fs = Finding[]; r = BMOPFTools._classify_linecodes(decoupled_extra, fs)
    @test r["by_linecode"]["four_wire"]["additional_conductor_coupling_ratio"] == 0.0
    uncoupled = only(filter(f -> f.code == seq.code, fs))
    @test "retained_conductors" in _guidance_ids(uncoupled.detail["interpretation"], "implications")
    @test "uncoupled_extra_conductor" in _guidance_ids(uncoupled.detail["interpretation"], "implications")
    @test !("uncoupled_extra_conductor" in _guidance_ids(seq.detail["interpretation"], "implications"))
    # A three-wire counterpart keeps the relevant conditional return-path hint.
    lc3 = Dict{String,Any}("$(p)_series_$(i)_$(j)" => (p == "R" ? R[i,j] : X[i,j])
        for p in ("R", "X") for i in 1:3 for j in 1:3)
    net["linecode"]["three_wire"] = lc3
    fs = Finding[]; BMOPFTools._classify_linecodes(net, fs)
    mixed_finding = only(filter(f -> f.code == seq.code, fs))
    mixed = mixed_finding.detail["interpretation"]
    # The message names both groups, matching the interpretation.
    @test occursin("1 three-wire", mixed_finding.message) && occursin("1 with an explicit extra conductor", mixed_finding.message)
    @test first(mixed["possible_explanations"])["id"] == "sequence_parameterisation"
    @test "retained_conductors" in _guidance_ids(mixed, "implications")
    @test "neutral_inside_z0" in _guidance_ids(mixed, "implications")
    @test !mixed["observations"]["by_linecode"]["three_wire"]["phase_block_only"]
    @test mixed["observations"]["by_linecode"]["three_wire"]["additional_conductor_coupling_ratio"] === nothing
end

@testset "PN reference relation depends on earth current, not conductor equality" begin
    net = _guidance_case("balanced_phase_four_wire.json")
    R, _, Z = _guidance_matrices(net)
    T = hcat(Matrix{Float64}(I, 3, 3), -ones(3))
    Zpn = T*Z*transpose(T)
    Ip = ComplexF64[10, 2im, -3im]
    In = -sum(Ip)
    I4 = vcat(Ip, In)
    @test iszero(sum(I4))
    @test T*(Z*I4) ≈ Zpn*Ip atol=1e-12
    # Unequal phase/neutral resistance changes the half-self fingerprint while
    # the full phase-to-neutral transformation remains exact in this domain.
    @test R[1,1] != R[4,4]
    @test abs(real(Zpn[1,2])/real(Zpn[1,1])-0.5) > 0.06
    Vto = vcat(230 .* [1, cis(-2pi/3), cis(2pi/3)], 0) - Z*I4
    recovered_neutral = -sum(Z[4,:] .* I4)
    @test recovered_neutral ≈ Vto[4]
    @test abs(recovered_neutral) > 0
    # An earth-return current breaks the eliminated-current relation.
    Iearth = vcat(Ip, In+1)
    @test norm(T*(Z*Iearth)-Zpn*Ip) > 1
    guide = BMOPFTools._finding_interpretation("I.PROV.IMPEDANCE_TRANSFORM_PN", Dict())
    @test Set(("grounding_sensitive", "conductor_size_fingerprint", "neutral_recovery")) ⊆ _guidance_ids(guide, "implications")
end

@testset "Kron reduction retains dissipation under its boundary relation" begin
    _, _, Z = _guidance_matrices(_guidance_case("balanced_phase_four_wire.json"))
    Ip = ComplexF64[10, 0, 0]
    In = -sum(Z[4,1:3] .* Ip)/Z[4,4]
    I4 = vcat(Ip, In)
    Zk = Z[1:3,1:3] - Z[1:3,4]*transpose(Z[4,1:3])/Z[4,4]
    @test In ≈ -1.0
    @test abs(sum(Z[4,:] .* I4)) < 1e-12 # eliminated voltage drop is zero
    @test real(dot(I4, Z*I4)) ≈ 199.0
    @test real(dot(Ip, Zk*Ip)) ≈ real(dot(I4, Z*I4))
    @test real(Z[4,4])*abs2(In) > 0
    wrong_current = vcat(Ip, In+1)
    @test abs(sum(Z[4,:] .* wrong_current)) > 1
    @test !isapprox(real(dot(wrong_current, Z*wrong_current)), real(dot(Ip, Zk*Ip)))
    guide = BMOPFTools._finding_interpretation("I.PROV.IMPEDANCE_TRANSFORM_KR", Dict())
    @test "neutral_loss_attribution" in _guidance_ids(guide, "implications")
end

function _guidance_reach(net, code)
    cfg = load_config()
    cfg["operational"]["feeder_length"]["LV"]["multi_boundary"] = Dict("reach_short_m"=>1.0, "reach_long_m"=>1500.0)
    fs = Finding[]
    BMOPFTools._feeder_length_check(net, BMOPFTools._galvanic_zones(net), fs, cfg)
    only(filter(f -> f.code == code, fs))
end

@testset "feeder unit directions and impedance declaration basis" begin
    base = _guidance_case("two_boundary_chain.json")
    original = deepcopy(base)
    # Metres interpreted as kilometres, then converted to metres: too long.
    long = deepcopy(base)
    for line in values(long["line"]); line["length"] *= 1000; end
    f = _guidance_reach(long, "I.OPS.FEEDER_LONG")
    @test f.detail["boundary_reach_m"] == 200000.0
    g = f.detail["interpretation"]
    @test g["observations"]["impedance_basis_counts"] == Dict("absolute_section"=>4, "length_scaled"=>0, "unresolved"=>0, "inline_overrides_linecode"=>0)
    @test _guidance_ids(g, "implications") == Set(["absolute_section_impedance"])
    for id in keys(base["line"])
        @test BMOPFTools._line_z_norm(long["line"][id], Dict()) == BMOPFTools._line_z_norm(base["line"][id], Dict())
    end
    # Kilometre values copied into a metre field: too short.
    short = deepcopy(base)
    for line in values(short["line"]); line["length"] /= 1000; end
    f = _guidance_reach(short, "I.OPS.FEEDER_SHORT")
    @test f.detail["boundary_reach_m"] ≈ 0.2
    @test _guidance_ids(f.detail["interpretation"], "implications") == Set(["absolute_section_impedance"])
    # Equivalent per-length declarations do change electrical impedance when length changes.
    per_length = deepcopy(base); per_length["linecode"] = Dict{String,Any}()
    for (id, line) in per_length["line"]
        lc = Dict{String,Any}()
        for key in collect(keys(line))
            if startswith(key, "R_series_") || startswith(key, "X_series_")
                lc[key] = pop!(line, key)/line["length"]
            end
        end
        line["linecode"] = id; per_length["linecode"][id] = lc
        @test BMOPFTools._line_z_norm(line, per_length["linecode"]) ≈ BMOPFTools._line_z_norm(base["line"][id], Dict())
        line["length"] *= 1000
        @test BMOPFTools._line_z_norm(line, per_length["linecode"]) ≈ 1000*BMOPFTools._line_z_norm(base["line"][id], Dict())
    end
    f = _guidance_reach(per_length, "I.OPS.FEEDER_LONG")
    @test f.detail["interpretation"]["observations"]["impedance_basis_counts"]["length_scaled"] == 4
    @test !occursin("inline", f.message) # no inline lines, so no inline caveat
    @test "impedance_scaled" in _guidance_ids(f.detail["interpretation"], "implications")
    id = first(sort!(collect(keys(per_length["line"]))))
    per_length["line"][id] = deepcopy(long["line"][id])
    mixed = _guidance_reach(per_length, "I.OPS.FEEDER_LONG").detail["interpretation"]
    @test mixed["observations"]["impedance_basis_counts"] == Dict("absolute_section"=>1, "length_scaled"=>3, "unresolved"=>0, "inline_overrides_linecode"=>0)
    @test "impedance_scaled" in _guidance_ids(mixed, "implications")
    @test "absolute_section_impedance_mixed" in _guidance_ids(mixed, "implications")
    # Inline matrices win over a linecode, exactly as in the model.
    both = deepcopy(per_length); both["line"][id]["linecode"] = first(keys(per_length["linecode"]))
    both_g = _guidance_reach(both, "I.OPS.FEEDER_LONG").detail["interpretation"]
    @test both_g["observations"]["impedance_basis_counts"]["absolute_section"] == 1
    @test both_g["observations"]["impedance_basis_counts"]["inline_overrides_linecode"] == 1
    empty_line = Dict{String,Any}(k=>v for (k,v) in per_length["line"][id] if !startswith(k, "R_series_") && !startswith(k, "X_series_"))
    per_length["line"][id] = empty_line
    unresolved = _guidance_reach(per_length, "I.OPS.FEEDER_LONG").detail["interpretation"]
    @test unresolved["observations"]["impedance_basis_counts"]["unresolved"] == 1
    decoded = JSON3.read(JSON3.write(explain_finding(f)))
    @test decoded.interpretation.observations.impedance_basis_counts.length_scaled == 4
    @test base == original
end

@testset "diagonal signatures keep consistent context and unbounded caps stay explicit" begin
    net = _guidance_case("provenance_context.json")
    lc = net["linecode"]["three_wire"]
    for i in 1:3, j in 1:3, p in ("R", "X")
        lc["$(p)_series_$(i)_$(j)"] = i == j ? 2.0 : 0.0
    end
    fs = Finding[]; result = BMOPFTools._classify_linecodes(net, fs)
    transform = BMOPFTools._classify_impedance_transformation(net, fs, result)
    @test any(f -> f.code == "I.PROV.DECOUPLED_PHASES", fs)
    # Kron reduction always adds mutual coupling, so a diagonal block is not a Kron candidate.
    @test !any(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", fs)
    @test transform["by_linecode"]["three_wire"] == "unknown"
    @test transform["evidence_by_linecode"]["three_wire"]["reason"] == "negligible_phase_coupling_contradicts_kron"
    Zc = [complex(0.3, 0.8) complex(0.05, 0.45) complex(0.05, 0.40) complex(0.05, 0.42);
          complex(0.05, 0.45) complex(0.3, 0.8) complex(0.05, 0.45) complex(0.05, 0.43);
          complex(0.05, 0.40) complex(0.05, 0.45) complex(0.3, 0.8) complex(0.05, 0.44);
          complex(0.05, 0.42) complex(0.05, 0.43) complex(0.05, 0.44) complex(0.4, 0.82)]
    Zk = Zc[1:3, 1:3] - Zc[1:3, 4:4] * inv(Zc[4:4, 4:4]) * Zc[4:4, 1:3]
    @test abs(Zk[1, 2]) / abs(Zk[1, 1]) > 0.1 # independent witness: elimination couples the phases
    # A non-uniform diagonal (not DECOUPLED_PHASES) is still no Kron candidate.
    lc["R_series_2_2"] = 3.0
    fs = Finding[]; result = BMOPFTools._classify_linecodes(net, fs)
    BMOPFTools._classify_impedance_transformation(net, fs, result)
    @test !any(f -> f.code == "I.PROV.IMPEDANCE_TRANSFORM_KR", fs)
    @test result["by_linecode"]["three_wire"]["mutual_to_self_ratio"] == 0
    nw = _guidance_case("two_boundary_chain.json")
    for xf in values(nw["transformer"]["n_winding"]), w in xf["windings"]
        w["i_max"] = Inf; w["s_max"] = Inf
    end
    before = deepcopy(nw); fs = Finding[]
    BMOPFTools._winding_limit_coverage(nw, fs)
    f = only(filter(f -> f.code == "W.OPS.XFMR_UNCONSTRAINED", fs))
    obs = f.detail["interpretation"]["observations"]
    @test obs["n_windings_without_caps"] == obs["n_windings_with_unbounded_declarations"] == 4
    @test obs["limit_state_counts"]["i_max"] == obs["limit_state_counts"]["s_max"] == Dict("absent"=>0, "unbounded"=>4)
    @test nw == before
    serialized = JSON3.read(JSON3.write(explain_finding(f)))
    @test serialized.instance.detail.witnesses[1].limits.i_max.state == "unbounded"
    @test serialized.instance.detail.witnesses[1].limits.i_max.value === nothing
    @test serialized.interpretation.observations.n_windings_with_unbounded_declarations == 4
    # A finite zero cap is a real restriction, even if the other field is Inf.
    for xf in values(nw["transformer"]["n_winding"]), w in xf["windings"]; w["i_max"] = 0.0; end
    fs = Finding[]; BMOPFTools._winding_limit_coverage(nw, fs)
    @test isempty(fs)
    @test all(w["i_max"] == Inf for xf in values(before["transformer"]["n_winding"]) for w in xf["windings"])
    fs = Finding[]; BMOPFTools._winding_limit_coverage(_guidance_case("two_boundary_chain.json"), fs)
    absent = only(filter(f -> f.code == "W.OPS.XFMR_UNCONSTRAINED", fs)).detail["interpretation"]["observations"]
    @test absent["n_windings_with_unbounded_declarations"] == 0
    @test absent["limit_state_counts"]["i_max"] == Dict("absent"=>4, "unbounded"=>0)
end

@testset "learn-more links point at real documentation sections" begin
    docs = joinpath(@__DIR__, "..", "docs", "src")
    for (code, links) in BMOPFTools._LEARN_MORE
        @test haskey(BMOPFTools._FINDING_INTERPRETATIONS, code)
        @test !isempty(links)
        for link in links
            path = joinpath(docs, link["page"])
            @test isfile(path)
            @test occursin(link["section"], read(path, String))
            @test startswith(link["url"], "https://frederikgeth.github.io/BMOPFTools.jl/dev/")
        end
    end
    @test Set(keys(BMOPFTools._LEARN_MORE)) == Set(keys(BMOPFTools._FINDING_INTERPRETATIONS))
    report = analyze(_guidance_case("provenance_context.json"))
    markdown = sprint(io -> BMOPFTools.render_markdown(report, io))
    @test occursin("**Learn more:** [5. Kron reduction is an assumption, not a simplification]", markdown)
    @test occursin("Full record: `explain_finding(f)`", markdown)
end

@testset "hint messages stay short; caveats live in the interpretation" begin
    budget = 340 # characters before the trailing ": <ids>." list
    for name in ("provenance_context.json", "balanced_phase_four_wire.json", "two_boundary_chain.json")
        for f in analyze(_guidance_case(name)).findings
            f.detail isa AbstractDict && haskey(f.detail, "interpretation") || continue
            head = f.code == "W.OPS.XFMR_UNCONSTRAINED" || startswith(f.code, "I.OPS.FEEDER") ||
                f.code == "I.PROV.KRON_LIKELY" ? f.message : first(rsplit(f.message, ": "; limit=2))
            @test length(head) <= budget
        end
    end
end
