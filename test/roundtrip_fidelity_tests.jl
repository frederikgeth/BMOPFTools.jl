# roundtrip_fidelity_tests.jl
#
# Regression guard for the BMOPF → OpenDSS export (`to_dss`). For every
# pf_comparison feature case we round-trip DSS → BMOPF → DSS and check two
# signals:
#
#   1. Semantic diff — the re-parsed BMOPF dict (net2) must match the original
#      (net1) structurally. Cases that round-trip cleanly today are asserted to
#      STAY clean (@test); known-lossy cases are documented with @test_broken so
#      a future fix surfaces as an unexpected pass.
#   2. OpenDSS power-flow cross-check — solve original vs regenerated DSS in
#      OpenDSS and compare node voltages (gated on OpenDSSDirect). A *coarse*
#      tolerance (atol=2 V, rtol=2%) is used deliberately: it ignores the benign
#      systemic drift (`to_dss` currently writes DefaultBaseFrequency=60 and adds
#      line charging) while still catching the severe failures — islanding from a
#      dropped transformer, or a regenerated deck that will not converge.
#
# The allowlists below are a snapshot of today's fidelity. When `to_dss`
# improves, the corresponding @test_broken flips to an unexpected pass and this
# file must be updated to lock in the gain. See scripts/roundtrip_fidelity.jl for
# the full diagnostic sweep (per-case matrix + failure map) this distills.

include(joinpath(@__DIR__, "roundtrip_helpers.jl"))

const _RT_PF_DIR = joinpath(@__DIR__, "data", "pf_comparison")

# Cases whose DSS → BMOPF → DSS round trip is structurally lossless today.
#
# pf_3wdg_dyn moved OUT of this list when `from_dss` started reconstructing
# dropped 3-winding transformers as `n_winding`: the case was only "clean"
# because the transformer was silently LOST at both ends of the round trip.
# The unit now survives import, but `to_dss` lowers `n_winding` to a
# single-phase bank with synthetic per-winding buses, so the reparse differs
# structurally (documented loss; the PF cross-check still agrees).
# pf_4wdg_dyyn moved OUT when PowerIO v0.7 exported the 4-winding unit
# directly (earlier it was dropped, and the reconstruction refused): it now
# imports as `n_winding` and `to_dss` lowers it lossily, so the reparse differs.
# PowerIO v0.7 preserves source neutral grounding on import. The current
# `to_dss` writer does not emit that source side grounding, so those fixtures are
# no longer structurally clean even though their regenerated decks solve.
const RT_SEMANTIC_CLEAN = Set([
    "pf_1ph_line", "pf_exp_1ph", "pf_open_delta_reg", "pf_pv_1ph",
    "pf_zip_1ph",
])

# Cases that survive the OpenDSS power-flow cross-check at the coarse tolerance
# (solve + match, or legitimately skipped). Everything else either islands
# (dropped transformer) or fails to converge — see the failure map.
#
# The transformer cases joined this list as PowerIO's OpenDSS export improved:
# regenerated decks now converge and match at the coarse tolerance.
const RT_PF_SOUND = Set([
    "pf_1ph_freeneutral", "pf_1ph_impedanceneutral", "pf_1ph_line",
    "pf_1ph_perfectneutral", "pf_1ph_xfmr", "pf_3ph_line",
    "pf_3wdg_dyn", "pf_3wdg_dyn_unbalanced", "pf_3wdg_dyn_zgnd",
    "pf_3wdg_nwinding", "pf_3wdg_nwinding_unbalanced", "pf_4wdg_dyyn",
    "pf_4wdg_nwinding", "pf_autotransformer", "pf_cap_delta", "pf_cap_wye",
    "pf_center_tap_240", "pf_center_tap_balanced_heavy", "pf_center_tap_loaded",
    "pf_center_tap_oneleg_extreme", "pf_center_tap_singleleg_pn",
    "pf_center_tap_xfmr", "pf_combined_3ph_split", "pf_delta_load",
    "pf_dy_xfmr", "pf_dy_xfmr_rneut", "pf_dy_xfmr_tap", "pf_exp_1ph",
    "pf_open_delta_reg", "pf_pv_1ph", "pf_pv_4leg", "pf_yd_xfmr",
    "pf_zip_1ph", "pf_zip_3ph", "pf_zip_delta",
])

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
        to_dss(net1, regen)
        net2 = from_dss(regen)
        diffs = semantic_diff(net1, net2)
        if stem in RT_SEMANTIC_CLEAN
            @test isempty(diffs)
        else
            # Documented round-trip loss. If this passes, to_dss improved —
            # move the case into RT_SEMANTIC_CLEAN.
            @test_broken isempty(diffs)
        end
    end

    if _HAS_ODS
        @testset "PF cross-check — $(first(splitext(case)))" for case in cases
            stem = first(splitext(case))
            net1 = from_dss(joinpath(_RT_PF_DIR, case))
            regen = joinpath(workdir, "$stem.dss")
            to_dss(net1, regen)
            pf = pf_cross_check(joinpath(_RT_PF_DIR, case), regen;
                                atol=RT_PF_ATOL, rtol=RT_PF_RTOL)
            if stem in RT_PF_SOUND
                @test pf_ok(pf)
            else
                # Islanding or non-convergence in the regenerated deck. If this
                # passes, to_dss improved — move the case into RT_PF_SOUND.
                @test_broken pf_ok(pf)
            end
        end
    else
        @test_skip "PF cross-check requires OpenDSSDirect"
    end
end
