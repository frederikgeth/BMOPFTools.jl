# roundtrip_fidelity_tests.jl
#
# Exact structural change inventories plus independent primitive, grounding,
# rating, and OpenDSS PF checks for all 36 feature fixtures. Reviewed equivalent
# circuits are ordinary assertions; no whole-case semantic @test_broken masks
# regressions. See data/roundtrip_expectations.md and roundtrip_review_helpers.jl.

include(joinpath(@__DIR__, "roundtrip_helpers.jl"))
include(joinpath(@__DIR__, "roundtrip_review_helpers.jl"))

const _RT_PF_DIR = joinpath(@__DIR__, "data", "pf_comparison")

# All independently convergent feature cases must retain complete mapped node
# coverage at the existing PF tolerance. The original open-delta case is the
# only recorded non-convergence skip; future failures are ordinary failures.
const RT_PF_SOUND = Set([
    "pf_1ph_freeneutral", "pf_1ph_impedanceneutral", "pf_1ph_line",
    "pf_1ph_perfectneutral", "pf_1ph_xfmr", "pf_3ph_line",
    "pf_3wdg_dyn", "pf_3wdg_dyn_unbalanced", "pf_3wdg_dyn_zgnd",
    "pf_3wdg_nwinding", "pf_3wdg_nwinding_unbalanced", "pf_3wdg_unequal_kva", "pf_4wdg_dyyn",
    "pf_4wdg_nwinding", "pf_autotransformer", "pf_cap_delta", "pf_cap_wye",
    "pf_center_tap_240", "pf_center_tap_balanced_heavy", "pf_center_tap_loaded",
    "pf_center_tap_oneleg_extreme", "pf_center_tap_singleleg_pn",
    "pf_center_tap_xfmr", "pf_combined_3ph_split", "pf_delta_load",
    "pf_dy_xfmr", "pf_dy_xfmr_rneut", "pf_dy_xfmr_tap", "pf_exp_1ph",
    "pf_pv_1ph", "pf_pv_4leg", "pf_yd_xfmr",
    "pf_zip_1ph", "pf_zip_3ph", "pf_zip_delta",
])

const RT_EXPECTED_LOSSES = BMOPFTools.JSON3.read(
    read(joinpath(@__DIR__, "data", "roundtrip_expected_losses.json"), String), Dict{String,Any})

const RT_PF_ATOL = 2.0
const RT_PF_RTOL = 0.02

@testset "to_dss round-trip fidelity" begin
    cases = sort(filter(f -> endswith(f, ".dss"), readdir(_RT_PF_DIR)))
    @test !isempty(cases)
    workdir = mktempdir()

    @testset "semantic diff — $(first(splitext(case)))" for case in cases
        stem = first(splitext(case))
        net1 = from_dss(joinpath(_RT_PF_DIR, case))
        regen = joinpath(workdir, "$stem.dss")
        to_dss(net1, regen; allow_unverified_ratings=true)
        net2 = from_dss(regen)
        diffs = semantic_diff(net1, net2)
        observed = sort!([(d.path, string(d.kind)) for d in diffs])
        expected = sort!([(d["path"], d["kind"]) for d in RT_EXPECTED_LOSSES[stem]])
        @test observed == expected # A fixed loss cannot be replaced by a different regression.
        check_reviewed_roundtrip(net1, net2, stem)
    end

    if _HAS_ODS
        @testset "PF cross-check — $(first(splitext(case)))" for case in cases
            stem = first(splitext(case))
            net1 = from_dss(joinpath(_RT_PF_DIR, case))
            regen = joinpath(workdir, "$stem.dss")
            to_dss(net1, regen; allow_unverified_ratings=true)
            pf = pf_cross_check(joinpath(_RT_PF_DIR, case), regen;
                                atol=RT_PF_ATOL, rtol=RT_PF_RTOL,
                                node_map=roundtrip_fixture_node_map(joinpath(_RT_PF_DIR, case)))
            if pf.skipped
                @test stem == "pf_open_delta_reg" # recorded original non-convergence
                @test_skip pf_ok(pf)
            else
                @test stem in RT_PF_SOUND
                @test isempty(pf.missing_nodes)
                @test pf.n_nodes_compared > 0
                @test pf_ok(pf)
            end
        end
    else
        @test_skip "PF cross-check requires OpenDSSDirect"
    end
end

@testset "Fidelity oracle requires evidence and explicit correspondence" begin
    ref = Dict("a.1" => 230.0+0im, "b.1" => 231.0+0im, "a.0" => 0.0+0im)
    @test pf_ok(compare_volts(ref, ref))
    partial = compare_volts(ref, Dict("a.1" => 230.0+0im))
    @test !pf_ok(partial)
    @test partial.missing_nodes == ["b.1"]
    @test !pf_ok(compare_volts(Dict("a.0"=>0.0+0im), Dict("a.0"=>0.0+0im)))
    @test !pf_ok(PFResult(false, false, true, NaN, 0, [], "original did not solve"))
    renamed = Dict("x.1" => 230.0+0im, "y.1" => 231.0+0im)
    @test !pf_ok(compare_volts(ref, renamed))
    @test pf_ok(compare_volts(ref, renamed; node_map=Dict("a.1"=>"x.1", "b.1"=>"y.1")))
end
