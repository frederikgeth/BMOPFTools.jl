# Power-flow comparison tests: BMOPF component models vs OpenDSS reference.
#
# Strategy: for each 2-bus test case the feasibility OPF is run with no
# operational bounds.  When the elastic slack injections are ≈ 0, the solution
# satisfies all KCL/KVL constraints and is therefore a valid power flow.
# The resulting bus-terminal complex voltages are then compared directly with
# those returned by OpenDSS (via OpenDSSDirect.jl) on the same network.
#
# Node-name mapping:
#   OpenDSS "bus.1" / ".2" / ".3" / ".4"  →  BMOPF terminal "1"/"2"/"3"/"n"
#   OpenDSS "bus.0" (earth reference)       →  not a BMOPF terminal (skipped)
#
# Comparison tolerances:
#   · Lines and lossless / lightly-loaded transformers: atol=1.0 V, rtol=1e-3
#   · Three-phase transformers with realistic losses at ≥70% loading:
#       atol=0.1 V, rtol=1e-3
#     At 75% rated load on a 500 kVA / 0.415 kV unit the series drop is ≈10 V
#     on the LV side, so 0.1 V tolerance requires <1% model agreement — any
#     wrong sign, missing factor, or wrong impedance side would produce >1 V error.
#
# Parser note: BMOPF network dicts are constructed directly here (no external
# parser dependency).  When PowerIO.jl is available, replace the hand-crafted
# dicts with `from_dss(path)` calls and delete the inline dicts.

using OpenDSSDirect
using BMOPFTools
using Ipopt

const _PF_CMP_DIR = joinpath(@__DIR__, "data", "pf_comparison")

# ── Helpers ───────────────────────────────────────────────────────────────────

"""
    _ods_volts(dss_path) -> Dict{String, ComplexF64}

Load and solve the DSS file with OpenDSS.  Returns a dict mapping every
non-earth node name (e.g. `"src.1"`, `"lb.4"`) to its complex voltage in V.
"""
function _ods_volts(dss_path::String)::Dict{String,ComplexF64}
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
    names = Circuit.AllNodeNames()
    volts = Circuit.AllBusVolts()
    return Dict(n => v for (n, v) in zip(names, volts))
end

"""
    _ods_losses_W(dss_path) -> Float64

Load and solve the DSS file; return total circuit losses in watts.
"""
function _ods_losses_W(dss_path::String)::Float64
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
    return real(Circuit.Losses())
end

"""
    _bmopf_volts(net) -> (Dict{String, ComplexF64}, Float64)

Run the feasibility OPF on a BMOPF network dict and return `(volts, slack_A)`
where `volts` maps `"bus.node"` → complex voltage in V and `slack_A` is the
total elastic-slack magnitude in amperes.
"""
function _bmopf_volts(net::Dict{String,Any})
    res = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    slack_A = res["total_slack_magnitude_A"]
    volts = Dict{String,ComplexF64}()
    for (bid, t_dict) in res["bus"]
        for (t, tv) in t_dict
            node_str = t == "n" ? "4" : t
            volts[bid * "." * node_str] = tv["vr"] + im * tv["vi"]
        end
    end
    return volts, slack_A
end

"""
    _bmopf_volts_pf(net) -> Dict{String, ComplexF64}

Run the determined power flow (`solve_pf`) on a BMOPF network dict and return a
dict mapping `"bus.node"` → complex voltage in V. Same node-name mapping as
`_bmopf_volts`. `solve_pf` enforces KCL exactly (no elastic slack), so a valid
power-flow solution needs no slack check — the comparison against OpenDSS is the
correctness test.
"""
function _bmopf_volts_pf(net::Dict{String,Any})
    res = solve_pf(net; optimizer=Ipopt.Optimizer)
    volts = Dict{String,ComplexF64}()
    for (bid, t_dict) in res["bus"]
        for (t, tv) in t_dict
            node_str = t == "n" ? "4" : t
            volts[bid * "." * node_str] = tv["vr"] + im * tv["vi"]
        end
    end
    return volts
end

"""
    _bmopf_losses_W(res, net) -> Float64

Compute total transformer losses (W) as the sum of complex power flowing into
every transformer winding terminal on both sides: P_loss = Σ Re(V_t · conj(I_t)).
This is sign-convention-agnostic and avoids the generator current direction ambiguity.
"""
function _bmopf_losses_W(res::Dict, net::Dict)::Float64
    bus_v = res["bus"]
    xfmr_res = get(res, "transformer", Dict())
    p_loss = 0.0
    for (_, subtypedict) in get(net, "transformer", Dict())
        for (tid, xfmr) in subtypedict
            xr = get(xfmr_res, tid, nothing)
            xr === nothing && continue
            b_fr = xfmr["bus_from"]; b_to = xfmr["bus_to"]
            tmfr = Vector{String}(get(xfmr, "terminal_map_from", String[]))
            tmto = Vector{String}(get(xfmr, "terminal_map_to",   String[]))
            for (k, t) in enumerate(tmfr)
                cd = get(get(xr, "fr", Dict()), string(k), nothing)
                cd === nothing && continue
                tv = get(get(bus_v, b_fr, Dict()), t, nothing)
                tv === nothing && continue
                p_loss += tv["vr"] * cd["cr"] + tv["vi"] * cd["ci"]
            end
            for (k, t) in enumerate(tmto)
                cd = get(get(xr, "to", Dict()), string(k), nothing)
                cd === nothing && continue
                tv = get(get(bus_v, b_to, Dict()), t, nothing)
                tv === nothing && continue
                p_loss += tv["vr"] * cd["cr"] + tv["vi"] * cd["ci"]
            end

            # Core-loss (no-load) shunt at the from-side phase terminals. The
            # winding-current sum above is the copper loss only; the magnetising
            # conductance draws G·|V|² per phase that does not appear in cr_xf.
            G_total = Float64(get(xfmr, "g_no_load", 0.0))
            if G_total != 0.0
                ph = BMOPFTools._phase_positions(
                    Vector{String}(get(xfmr, "terminal_map_from", String[])))
                Gph = G_total / max(length(ph), 1)
                for pidx in ph
                    t = tmfr[pidx]
                    tv = get(get(bus_v, b_fr, Dict()), t, nothing)
                    tv === nothing && continue
                    p_loss += Gph * (tv["vr"]^2 + tv["vi"]^2)
                end
            end
        end
    end
    return p_loss
end

"""
    _ods_pv(dss_path) -> (volts::Dict{String,ComplexF64}, powers::Vector{ComplexF64})

Solve the DSS file and return node voltages plus the PVSystem element's complex
power per conductor (kVA, sign convention: power flowing *into* the element from
the bus). The injected power is therefore `-powers[k]`.
"""
function _ods_pv(dss_path::String)
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
    volts = Dict(n => v for (n, v) in
                 zip(OpenDSSDirect.Circuit.AllNodeNames(), OpenDSSDirect.Circuit.AllBusVolts()))
    OpenDSSDirect.Circuit.SetActiveElement("PVSystem.pv")
    powers = OpenDSSDirect.CktElement.Powers()
    return volts, powers
end

"""
    _bmopf_volts_opf(net) -> (volts::Dict{String,ComplexF64}, result::Dict)

Like `_bmopf_volts` but via `solve_opf` rather than `solve_feasibility_opf`,
because the inverter constraints are only built by `solve_opf`. Buses carry no
voltage bounds, so this is a pure power flow with the voltage source as slack.
"""
function _bmopf_volts_opf(net::Dict{String,Any})
    res = solve_opf(net; optimizer=Ipopt.Optimizer)
    volts = Dict{String,ComplexF64}()
    for (bid, t_dict) in res["bus"]
        for (t, tv) in t_dict
            node = t == "n" ? "4" : t
            volts[bid * "." * node] = tv["vr"] + im * tv["vi"]
        end
    end
    return volts, res
end

"""
    _cmp_volts(V_ods, V_bm; label="", atol=1.0, rtol=1e-3)

Assert that every node present in both dicts agrees within tolerance.
Nodes with |V_ref| < 1e-4 V (effectively the earth reference) are skipped.
At least one node must be compared.
"""
function _cmp_volts(V_ods::Dict, V_bm::Dict;
                    label::String="", atol::Float64=1.0, rtol::Float64=1e-3)
    n = 0
    for (node, V_ref) in V_ods
        haskey(V_bm, node)   || continue
        abs(V_ref) < 1e-4    && continue
        V_calc = V_bm[node]
        ok = isapprox(V_calc, V_ref; atol=atol, rtol=rtol)
        if !ok
            err = abs(V_calc - V_ref)
            @warn "$(label)node $node: |BMOPF − ODS| = $(round(err, digits=3)) V " *
                  "(ODS=$(round(abs(V_ref),digits=3)) V, " *
                  "BMOPF=$(round(abs(V_calc),digits=3)) V)"
        end
        @test ok
        n += 1
    end
    @test n > 0
end

# ── Network constructors ──────────────────────────────────────────────────────
# Each function returns a BMOPF network dict that mirrors its .dss fixture.
# TODO: replace these with `from_dss(path)` once PowerIO.jl is available.

function _net_1ph_line()
    # pf_1ph_line.dss: src ──[1-ph line, 0.5 km, r1=0.5 Ω/km, x1=0.2 Ω/km]── lb
    # Single conductor, earth return (no explicit neutral).
    # Total series impedance: R = 0.25 Ω, X = 0.10 Ω
    # Load: 10 kW + 3 kVAr phase-to-earth
    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}(
                "terminal_names" => ["1"]),
            "lb"  => Dict{String,Any}(
                "terminal_names" => ["1"])),
        "voltage_source" => Dict{String,Any}(
            "source" => Dict{String,Any}(
                "bus"          => "src",
                "terminal_map" => ["1"],
                "v_magnitude"  => [240.0],
                "v_angle"      => [0.0])),
        "linecode" => Dict{String,Any}(
            "sp1w" => Dict{String,Any}(
                "R_series_1_1" => 0.500 / 1000.0,
                "X_series_1_1" => 0.200 / 1000.0)),
        "line" => Dict{String,Any}(
            "l1" => Dict{String,Any}(
                "bus_from"         => "src",
                "bus_to"           => "lb",
                "linecode"         => "sp1w",
                "length"           => 500.0,
                "terminal_map_from"=> ["1"],
                "terminal_map_to"  => ["1"])),
        "load" => Dict{String,Any}(
            "ld1" => Dict{String,Any}(
                "bus"           => "lb",
                "terminal_map"  => ["1"],
                "configuration" => "WYE",
                "p_nom"         => [10_000.0],
                "q_nom"         => [3_000.0])))
end

function _net_3ph_line()
    # pf_3ph_line.dss: src ──[4-wire line, 0.5 km]── lb
    # linecode 4w: phase self 0.5/0.2 Ω/km, neutral self 0.5/0.2, mutual 0.02/0.05 Ω/km
    # source: 3-phase balanced 0.415 kV (line), i.e. 239.6 V / phase at 0°/−120°/+120°
    # grounding reactor at src.4: R=0.001 Ω → shunt G=1000 S
    # loads: unbalanced 15/10/20 kW + 5/3/7 kVAr phase-to-neutral
    v_ph = 415.0 / sqrt(3)
    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}(
                "terminal_names"  => ["1", "2", "3", "n"],
                "neutral_terminal"=> "n"),
            "lb"  => Dict{String,Any}(
                "terminal_names"  => ["1", "2", "3", "n"],
                "neutral_terminal"=> "n")),
        "voltage_source" => Dict{String,Any}(
            "source" => Dict{String,Any}(
                "bus"          => "src",
                "terminal_map" => ["1", "2", "3"],
                "v_magnitude"  => [v_ph, v_ph, v_ph],
                "v_angle"      => [0.0, -2π/3, 2π/3])),
        "shunt" => Dict{String,Any}(
            "grnd" => Dict{String,Any}(
                "bus"          => "src",
                "terminal_map" => ["n"],
                "G_1_1"        => 1000.0,
                "B_1_1"        => 0.0)),
        "linecode" => Dict{String,Any}(
            "4w" => Dict{String,Any}(
                "R_series_1_1" => 0.500 / 1000.0,
                "R_series_1_2" => 0.020 / 1000.0,
                "R_series_1_3" => 0.020 / 1000.0,
                "R_series_1_4" => 0.020 / 1000.0,
                "R_series_2_1" => 0.020 / 1000.0,
                "R_series_2_2" => 0.500 / 1000.0,
                "R_series_2_3" => 0.020 / 1000.0,
                "R_series_2_4" => 0.020 / 1000.0,
                "R_series_3_1" => 0.020 / 1000.0,
                "R_series_3_2" => 0.020 / 1000.0,
                "R_series_3_3" => 0.500 / 1000.0,
                "R_series_3_4" => 0.020 / 1000.0,
                "R_series_4_1" => 0.020 / 1000.0,
                "R_series_4_2" => 0.020 / 1000.0,
                "R_series_4_3" => 0.020 / 1000.0,
                "R_series_4_4" => 0.500 / 1000.0,
                "X_series_1_1" => 0.200 / 1000.0,
                "X_series_1_2" => 0.050 / 1000.0,
                "X_series_1_3" => 0.050 / 1000.0,
                "X_series_1_4" => 0.050 / 1000.0,
                "X_series_2_1" => 0.050 / 1000.0,
                "X_series_2_2" => 0.200 / 1000.0,
                "X_series_2_3" => 0.050 / 1000.0,
                "X_series_2_4" => 0.050 / 1000.0,
                "X_series_3_1" => 0.050 / 1000.0,
                "X_series_3_2" => 0.050 / 1000.0,
                "X_series_3_3" => 0.200 / 1000.0,
                "X_series_3_4" => 0.050 / 1000.0,
                "X_series_4_1" => 0.050 / 1000.0,
                "X_series_4_2" => 0.050 / 1000.0,
                "X_series_4_3" => 0.050 / 1000.0,
                "X_series_4_4" => 0.200 / 1000.0)),
        "line" => Dict{String,Any}(
            "l1" => Dict{String,Any}(
                "bus_from"         => "src",
                "bus_to"           => "lb",
                "linecode"         => "4w",
                "length"           => 500.0,
                "terminal_map_from"=> ["1", "2", "3", "n"],
                "terminal_map_to"  => ["1", "2", "3", "n"])),
        "load" => Dict{String,Any}(
            "ld1" => Dict{String,Any}(
                "bus"           => "lb",
                "terminal_map"  => ["1", "n"],
                "configuration" => "WYE",
                "p_nom"         => [15_000.0],
                "q_nom"         => [5_000.0]),
            "ld2" => Dict{String,Any}(
                "bus"           => "lb",
                "terminal_map"  => ["2", "n"],
                "configuration" => "WYE",
                "p_nom"         => [10_000.0],
                "q_nom"         => [3_000.0]),
            "ld3" => Dict{String,Any}(
                "bus"           => "lb",
                "terminal_map"  => ["3", "n"],
                "configuration" => "WYE",
                "p_nom"         => [20_000.0],
                "q_nom"         => [7_000.0])))
end

function _net_1ph_xfmr()
    # pf_1ph_xfmr.dss: hv ──[1-ph YY xfmr, 11 kV / 0.24 kV, 50 kVA]── lv
    # %r=1.0 per winding, xhl=4.0%, %noloadloss=0.3, %imag=1.5
    # load: 30 kW + 10 kVAr on lv
    #
    # Impedance conversion (single_phase subtype, WYE-WYE):
    #   v_ref_from = 11 000 V, v_ref_to = 240 V, s_rating = 50 000 VA
    #   z_base_from = 11000² / 50000 = 2420 Ω
    #   z_base_to   =   240² / 50000 = 1.152 Ω
    #   r_series_from = 0.01 × 2420 = 24.2 Ω
    #   r_series_to   = 0.01 × 1.152 = 0.01152 Ω
    #   x_series_from = 0.04 × 2420 = 96.8 Ω  (all xsc on winding 1)
    #   x_series_to   = 0.0
    #
    # No-load branch (on from side):
    #   y_base = s / v_ref_from² = 50000 / 11000² = 4.132e-7 S
    #   G = noloadloss × y_base = 0.003 × 4.132e-7 = 1.240e-9 S
    #   |Y| = cmag × y_base = 0.015 × 4.132e-7 = 6.198e-9 S
    #   B = sqrt(|Y|² − G²) ≈ 6.073e-9 S
    s   = 50_000.0
    vf  = 11_000.0
    vt  =    240.0
    zbf = vf^2 / s
    zbt = vt^2 / s
    yb  = s / vf^2
    nl  = 0.003
    cm  = 0.015
    G_nl = nl * yb
    Y_nl = cm * yb
    B_nl = sqrt(max(Y_nl^2 - G_nl^2, 0.0))

    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "hv" => Dict{String,Any}(
                "terminal_names"  => ["1", "n"],
                "neutral_terminal"=> "n"),
            "lv" => Dict{String,Any}(
                "terminal_names"  => ["1", "n"],
                "neutral_terminal"=> "n")),
        "voltage_source" => Dict{String,Any}(
            "source" => Dict{String,Any}(
                "bus"          => "hv",
                "terminal_map" => ["1"],
                "v_magnitude"  => [11_000.0],
                "v_angle"      => [0.0])),
        "shunt" => Dict{String,Any}(
            "grnd_hv" => Dict{String,Any}(
                "bus"          => "hv",
                "terminal_map" => ["n"],
                "G_1_1"        => 1000.0,
                "B_1_1"        => 0.0),
            "grnd_lv" => Dict{String,Any}(
                "bus"          => "lv",
                "terminal_map" => ["n"],
                "G_1_1"        => 1000.0,
                "B_1_1"        => 0.0)),
        "transformer" => Dict{String,Any}(
            "single_phase" => Dict{String,Any}(
                "t1" => Dict{String,Any}(
                    "bus_from"         => "hv",
                    "bus_to"           => "lv",
                    "terminal_map_from"=> ["1", "n"],
                    "terminal_map_to"  => ["1", "n"],
                    "v_ref_from"       => vf,
                    "v_ref_to"         => vt,
                    "s_rating"         => s,
                    "r_series_from"    => 0.01 * zbf,
                    "r_series_to"      => 0.01 * zbt,
                    "x_series_from"    => 0.04 * zbf,
                    "x_series_to"      => 0.0,
                    "g_no_load"        => G_nl,
                    "b_no_load"        => B_nl))),
        "load" => Dict{String,Any}(
            "ld1" => Dict{String,Any}(
                "bus"           => "lv",
                "terminal_map"  => ["1", "n"],
                "configuration" => "WYE",
                "p_nom"         => [30_000.0],
                "q_nom"         => [10_000.0])))
end

function _net_yd_xfmr()
    # pf_yd_xfmr.dss: hv ──[Yd xfmr, 11 kV wye / 0.415 kV delta, 500 kVA]── lv
    # %r=1.0 per winding, xhl=4.0%, %noloadloss=0.3, %imag=1.5
    # HV neutral earthed via R=0.001 Ω reactor → shunt G=1000 S at hv.n
    # LV delta: near-solid ground (R=0.001 Ω, G≈1000 S) at lv.1 to anchor
    #   common mode deterministically — mirrors ODS Reactor.grnd_lv.
    # loads: unbalanced (3:1:2) delta loads to expose per-phase errors
    #
    # Impedance conversion (wye_delta subtype):
    #   v_ref_from = 11 000 V (wye, line voltage)
    #   v_ref_to   =    415 V (delta, line voltage)
    #   s_rating   = 500 000 VA
    #   zbf = 11000² / 500000 = 242 Ω
    #   zbt =   415² / 500000 = 0.34445 Ω
    #
    #   _add_yd_transformer! variables: Iw = wye line current, Id = delta arm current.
    #   Current constraint: n_eff·Id = Iw_k - Iw_{k-1}, so at rated load |Id|=|Iw|/√3.
    #   Power loss matching to OpenDSS (%r per winding on winding kVA base):
    #     Rw × |Iw|² = %r × (S/3)  →  Rw = %r × zbf       (no √3)
    #     Rd × |Id|² = %r × (S/3)  →  Rd = %r × zbt × 3   (|Id|=rated_LV_arm_current)
    #   Wait — for the delta winding (to-side here), |Id| at rated = (S/3)/vt (arm current).
    #   So Rd × ((S/3)/vt)² = %r × S/3  →  Rd = %r × vt²/S = %r × zbt.
    #   Result: r_series = %r × z_base, no √3 on either side.
    #   xhl split 50/50 between windings (a valid T-model choice summing to xhl):
    #   r_series_from = 0.01 × 242 = 2.42 Ω    (wye winding)
    #   r_series_to   = 0.01 × 0.34445 = 3.4445e-3 Ω  (delta winding)
    #   x_series_from = 0.04/2 × 242 = 4.84 Ω  (half xhl on wye side)
    #   x_series_to   = 0.04/2 × 0.34445 = 6.889e-3 Ω  (half xhl on delta side)
    s   = 500_000.0
    vf  = 11_000.0
    vt  =    415.0
    zbf = vf^2 / s
    zbt = vt^2 / s
    nl  = 0.003
    cm  = 0.015
    # No-load (core-loss) shunt is stamped phase-to-ground at the from bus, which
    # sits at the line-to-NEUTRAL voltage V_LN = vf/√3 for a 3-phase winding.  Its
    # admittance must therefore be referred to V_LN (not the line-to-line vf), so
    # that the total core loss = g_no_load·V_LN² = %noloadloss·kVA matches OpenDSS.
    yb_nl = s / (vf / sqrt(3))^2   # = 3·s/vf²  (the √3 connection factor)
    G_nl = nl * yb_nl
    Y_nl = cm * yb_nl
    B_nl = sqrt(max(Y_nl^2 - G_nl^2, 0.0))

    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "hv" => Dict{String,Any}(
                "terminal_names"  => ["1", "2", "3", "n"],
                "neutral_terminal"=> "n"),
            "lv" => Dict{String,Any}(
                "terminal_names"  => ["1", "2", "3"])),
        "voltage_source" => Dict{String,Any}(
            "source" => Dict{String,Any}(
                "bus"          => "hv",
                "terminal_map" => ["1", "2", "3"],
                "v_magnitude"  => [vf/sqrt(3), vf/sqrt(3), vf/sqrt(3)],
                "v_angle"      => [0.0, -2π/3, 2π/3])),
        "shunt" => Dict{String,Any}(
            "grnd_hv" => Dict{String,Any}(
                "bus"          => "hv",
                "terminal_map" => ["n"],
                "G_1_1"        => 1000.0,
                "B_1_1"        => 0.0),
            "grnd_lv" => Dict{String,Any}(
                "bus"          => "lv",
                "terminal_map" => ["1"],
                "G_1_1"        => 1000.0,
                "B_1_1"        => 0.0)),
        "transformer" => Dict{String,Any}(
            "wye_delta" => Dict{String,Any}(
                "t1" => Dict{String,Any}(
                    "bus_from"         => "hv",
                    "bus_to"           => "lv",
                    "terminal_map_from"=> ["1", "2", "3", "n"],
                    "terminal_map_to"  => ["1", "2", "3"],
                    "v_ref_from"       => vf,
                    "v_ref_to"         => vt,
                    "s_rating"         => s,
                    "r_series_from"    => 0.01 * zbf,
                    "r_series_to"      => 0.01 * zbt,
                    "x_series_from"    => 0.04 / 2 * zbf,
                    "x_series_to"      => 0.04 / 2 * zbt,
                    "g_no_load"        => G_nl,
                    "b_no_load"        => B_nl))),
        "load" => Dict{String,Any}(
            "ld1" => Dict{String,Any}(
                "bus"           => "lv",
                "terminal_map"  => ["1", "2"],
                "configuration" => "DELTA",
                "p_nom"         => [180_000.0],
                "q_nom"         => [60_000.0]),
            "ld2" => Dict{String,Any}(
                "bus"           => "lv",
                "terminal_map"  => ["2", "3"],
                "configuration" => "DELTA",
                "p_nom"         => [60_000.0],
                "q_nom"         => [20_000.0]),
            "ld3" => Dict{String,Any}(
                "bus"           => "lv",
                "terminal_map"  => ["3", "1"],
                "configuration" => "DELTA",
                "p_nom"         => [120_000.0],
                "q_nom"         => [40_000.0])))
end

function _net_dy_xfmr()
    # pf_dy_xfmr.dss: hv ──[Dy xfmr, 11 kV delta / 0.415 kV wye, 500 kVA]── lv
    # %r=1.0 per winding, xhl=4.0%, %noloadloss=0.3, %imag=1.5
    # LV neutral earthed via R=0.3 Ω reactor → shunt G=1/0.3 S
    # loads: unbalanced wye-to-neutral 120 kW + 40 kVAr each phase (3:3:3 here, balanced)
    #
    # Impedance conversion (delta_wye subtype):
    #   v_ref_from = 11 000 V (delta, line voltage)
    #   v_ref_to   =    415 V (wye, line voltage)
    #   s_rating   = 500 000 VA
    #   zbf = 11000² / 500000 = 242 Ω
    #   zbt =   415² / 500000 = 0.34445 Ω
    #
    #   _add_yd_transformer! variables: Id = delta arm current (from-side), Iw = wye line current.
    #   Current constraint: n_eff·Id = Iw_k - Iw_{k+1}, so |Id| = |Iw|/√3 balanced.
    #   Power loss matching to OpenDSS (%r per winding on winding kVA base):
    #     Rd × |Id|² = %r × (S/3)  →  Rd = %r × zbf       (no √3: |Id|_rated = (S/3)/(vf/√3·√3))
    #     Rw × |Iw|² = %r × (S/3)  →  Rw = %r × zbt       (no √3)
    #   Result: r_series = %r × z_base, no √3 on either side.
    #   xhl split 50/50 between windings:
    #   r_series_from = 0.01 × 242 = 2.42 Ω         (delta winding, from-side)
    #   r_series_to   = 0.01 × 0.34445 = 3.4445e-3 Ω (wye winding, to-side)
    #   x_series_from = 0.04/2 × 242 = 4.84 Ω       (half xhl on delta side)
    #   x_series_to   = 0.04/2 × 0.34445 = 6.889e-3 Ω (half xhl on wye side)
    s   = 500_000.0
    vf  = 11_000.0
    vt  =    415.0
    zbf = vf^2 / s
    zbt = vt^2 / s
    nl  = 0.003
    cm  = 0.015
    # No-load shunt stamped phase-to-ground at the from (HV) bus → referred to the
    # line-to-neutral voltage V_LN = vf/√3 (the bus is 3-phase at line voltage vf,
    # regardless of the delta winding connection).  See _net_yd_xfmr.
    yb_nl = s / (vf / sqrt(3))^2   # = 3·s/vf²
    G_nl = nl * yb_nl
    Y_nl = cm * yb_nl
    B_nl = sqrt(max(Y_nl^2 - G_nl^2, 0.0))

    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "hv" => Dict{String,Any}(
                "terminal_names" => ["1", "2", "3"]),
            "lv" => Dict{String,Any}(
                "terminal_names"  => ["1", "2", "3", "n"],
                "neutral_terminal"=> "n")),
        "voltage_source" => Dict{String,Any}(
            "source" => Dict{String,Any}(
                "bus"          => "hv",
                "terminal_map" => ["1", "2", "3"],
                "v_magnitude"  => [vf/sqrt(3), vf/sqrt(3), vf/sqrt(3)],
                "v_angle"      => [0.0, -2π/3, 2π/3])),
        "shunt" => Dict{String,Any}(
            "grnd_lv" => Dict{String,Any}(
                "bus"          => "lv",
                "terminal_map" => ["n"],
                "G_1_1"        => 1.0 / 0.3,
                "B_1_1"        => 0.0)),
        "transformer" => Dict{String,Any}(
            "delta_wye" => Dict{String,Any}(
                "t1" => Dict{String,Any}(
                    "bus_from"         => "hv",
                    "bus_to"           => "lv",
                    "terminal_map_from"=> ["1", "2", "3"],
                    "terminal_map_to"  => ["1", "2", "3", "n"],
                    "v_ref_from"       => vf,
                    "v_ref_to"         => vt,
                    "s_rating"         => s,
                    "r_series_from"    => 0.01 * zbf,
                    "r_series_to"      => 0.01 * zbt,
                    "x_series_from"    => 0.04 / 2 * zbf,
                    "x_series_to"      => 0.04 / 2 * zbt,
                    "g_no_load"        => G_nl,
                    "b_no_load"        => B_nl))),
        "load" => Dict{String,Any}(
            "ld1" => Dict{String,Any}(
                "bus"           => "lv",
                "terminal_map"  => ["1", "n"],
                "configuration" => "WYE",
                "p_nom"         => [120_000.0],
                "q_nom"         => [40_000.0]),
            "ld2" => Dict{String,Any}(
                "bus"           => "lv",
                "terminal_map"  => ["2", "n"],
                "configuration" => "WYE",
                "p_nom"         => [120_000.0],
                "q_nom"         => [40_000.0]),
            "ld3" => Dict{String,Any}(
                "bus"           => "lv",
                "terminal_map"  => ["3", "n"],
                "configuration" => "WYE",
                "p_nom"         => [120_000.0],
                "q_nom"         => [40_000.0])))
end

function _net_autotransformer()
    # pf_autotransformer.dss: src ──[1-ph regulator, 2.4 kV, 500 kVA, tap 1.05]── reg
    # ANSI Type B at tap a=1.05 → n_eff = 1/a; lossless boost V_reg = a·V_src.
    # %r=0.5 per winding, xhl=1.0 (both kv equal → same z_base both sides).
    #   z_base = 2400² / 500000 = 11.52 Ω
    #   r_series_from = r_series_to = 0.005 × 11.52   (winding %r on own base)
    #   x_series_from = 0.01 × 11.52  (all xhl on winding 1, Γ-model)
    s   = 500_000.0
    v   = 2400.0
    zb  = v^2 / s
    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}(
                "terminal_names"  => ["1", "n"],
                "neutral_terminal"=> "n"),
            "reg" => Dict{String,Any}(
                "terminal_names"  => ["1", "n"],
                "neutral_terminal"=> "n")),
        "voltage_source" => Dict{String,Any}(
            "vs" => Dict{String,Any}(
                "bus"          => "src",
                "terminal_map" => ["1"],
                "v_magnitude"  => [2400.0],
                "v_angle"      => [0.0])),
        "shunt" => Dict{String,Any}(
            "g_src" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["n"],
                "G_1_1" => 1000.0, "B_1_1" => 0.0),
            "g_reg" => Dict{String,Any}(
                "bus" => "reg", "terminal_map" => ["n"],
                "G_1_1" => 1000.0, "B_1_1" => 0.0)),
        "transformer" => Dict{String,Any}(
            "single_phase_autotransformer" => Dict{String,Any}(
                "reg" => Dict{String,Any}(
                    "bus_from"         => "src",
                    "bus_to"           => "reg",
                    "terminal_map_from"=> ["1", "n"],
                    "terminal_map_to"  => ["1", "n"],
                    "tap_ratio"        => 1.05,
                    "regulator_type"   => "B",
                    "s_rating"         => s,
                    "r_series_from"    => 0.005 * zb,
                    "r_series_to"      => 0.005 * zb,
                    "x_series_from"    => 0.01  * zb))),
        "load" => Dict{String,Any}(
            "ld" => Dict{String,Any}(
                "bus"           => "reg",
                "terminal_map"  => ["1", "n"],
                "configuration" => "SINGLE_PHASE",
                "p_nom"         => [50_000.0],
                "q_nom"         => [0.0])))
end

function _net_open_delta_reg()
    # pf_open_delta_reg.dss: src ──[open-delta regulator, ABBC]── reg
    # Two single-phase line-to-line regulators (reg1 across A-B tap 1.05,
    # reg2 across B-C tap 1.025), 500 kVA each, 4.157 kV L-L, %r=0.5, xhl=1.0.
    # The monolithic BMOPF open_delta_regulator reproduces this with two cores.
    #   v_LL = 2400·√3 = 4156.9 V; z_base = v_LL² / S referred to the L-L coil.
    s    = 500_000.0
    vll  = 2400.0 * sqrt(3)
    zb   = vll^2 / s
    Dict{String,Any}(
        "bus" => Dict{String,Any}(
            "src" => Dict{String,Any}(
                "terminal_names"  => ["1", "2", "3", "n"],
                "neutral_terminal"=> "n"),
            "reg" => Dict{String,Any}(
                "terminal_names"  => ["1", "2", "3", "n"],
                "neutral_terminal"=> "n")),
        "voltage_source" => Dict{String,Any}(
            "vs" => Dict{String,Any}(
                "bus"          => "src",
                "terminal_map" => ["1", "2", "3"],
                "v_magnitude"  => [2400.0, 2400.0, 2400.0],
                "v_angle"      => [0.0, -2π/3, 2π/3])),
        "shunt" => Dict{String,Any}(
            "g_src" => Dict{String,Any}(
                "bus" => "src", "terminal_map" => ["n"],
                "G_1_1" => 1000.0, "B_1_1" => 0.0),
            "g_reg" => Dict{String,Any}(
                "bus" => "reg", "terminal_map" => ["n"],
                "G_1_1" => 1000.0, "B_1_1" => 0.0)),
        "transformer" => Dict{String,Any}(
            "open_delta_regulator" => Dict{String,Any}(
                "od" => Dict{String,Any}(
                    "bus_from"         => "src",
                    "bus_to"           => "reg",
                    "terminal_map_from"=> ["1", "2", "3", "n"],
                    "terminal_map_to"  => ["1", "2", "3", "n"],
                    "connection"       => "ABBC",
                    "tap_ratio"        => [1.05, 1.025],
                    "regulator_type"   => "B",
                    "s_rating"         => s,
                    "r_series_from"    => 0.005 * zb,
                    "r_series_to"      => 0.005 * zb,
                    "x_series_from"    => 0.01  * zb))),
        "load" => Dict{String,Any}(
            "lda" => Dict{String,Any}(
                "bus" => "reg", "terminal_map" => ["1", "n"],
                "configuration" => "SINGLE_PHASE", "p_nom" => [20_000.0], "q_nom" => [0.0]),
            "ldb" => Dict{String,Any}(
                "bus" => "reg", "terminal_map" => ["2", "n"],
                "configuration" => "SINGLE_PHASE", "p_nom" => [20_000.0], "q_nom" => [0.0]),
            "ldc" => Dict{String,Any}(
                "bus" => "reg", "terminal_map" => ["3", "n"],
                "configuration" => "SINGLE_PHASE", "p_nom" => [20_000.0], "q_nom" => [0.0])))
end

function _net_delta_load()
    # pf_delta_load.dss: src ──[4-wire line, 0.5 km]── lb
    # Same source, grounding, and 4-wire linecode as _net_3ph_line, but the load
    # is a single UNBALANCED three-phase delta bank (line-to-line, no neutral):
    #   arm 1 (1-2) = 15 kW + 5 kVAr   ↔ ODS Load.d12
    #   arm 2 (2-3) = 10 kW + 3 kVAr   ↔ ODS Load.d23
    #   arm 3 (3-1) = 20 kW + 7 kVAr   ↔ ODS Load.d31
    # The BMOPF DELTA arm convention is tm[k] → tm[(k mod n)+1], i.e. 1-2, 2-3,
    # 3-1, matching the OpenDSS bus-pair ordering above.
    net = _net_3ph_line()
    net["load"] = Dict{String,Any}(
        "dl" => Dict{String,Any}(
            "bus"           => "lb",
            "terminal_map"  => ["1", "2", "3"],
            "configuration" => "DELTA",
            "p_nom"         => [15_000.0, 10_000.0, 20_000.0],
            "q_nom"         => [ 5_000.0,  3_000.0,  7_000.0]))
    return net
end

# ── Four-wire grounding study: single-phase load, three load-bus neutral cases ──
# These exercise the ground-injection current variable at perfectly grounded and
# source-pinned neutral terminals. A single-phase phase-to-neutral load forces the
# full return current through the neutral, so the load-bus neutral condition (free
# / impedance / perfect) directly shapes the neutral-point voltage rise.

function _net_1ph_freeneutral()
    # pf_1ph_freeneutral.dss: 15 kW + 5 kVAr single-phase load lb.1 → lb.4, with
    # the load-bus neutral FREE (grounded only via the line neutral back to src).
    net = _net_3ph_line()
    net["load"] = Dict{String,Any}(
        "ld1" => Dict{String,Any}(
            "bus"           => "lb",
            "terminal_map"  => ["1", "n"],
            "configuration" => "WYE",
            "p_nom"         => [15_000.0],
            "q_nom"         => [ 5_000.0]))
    return net
end

function _net_1ph_perfectneutral()
    # pf_1ph_perfectneutral.dss: same load, but lb.4 is perfectly grounded
    # (perfectly_grounded_terminals=["n"], exact vr=vi=0). ODS hard-ties lb.4→lb.0.
    net = _net_1ph_freeneutral()
    net["bus"]["lb"]["perfectly_grounded_terminals"] = ["n"]
    return net
end

function _net_1ph_impedanceneutral()
    # pf_1ph_impedanceneutral.dss: same load, lb.4 grounded through Z = 0.2 Ω,
    # modelled as a shunt G = 1/0.2 = 5 S on the lb neutral terminal. ODS uses a
    # 0.2 Ω grounding reactor lb.4 → lb.0.
    net = _net_1ph_freeneutral()
    net["shunt"]["lbgrnd"] = Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["n"], "G_1_1" => 5.0, "B_1_1" => 0.0)
    return net
end

function _net_zip_1ph()
    # pf_zip_1ph.dss: single-phase ZIP load, distinct P and Q coefficients.
    net = _net_1ph_line()
    net["load"] = Dict{String,Any}(
        "ld1" => Dict{String,Any}(
            "bus"           => "lb",
            "terminal_map"  => ["1"],
            "configuration" => "SINGLE_PHASE",
            "p_nom"         => [15_000.0],
            "q_nom"         => [ 5_000.0],
            "model"         => "zip",
            "v_nom"         => [240.0],
            "alpha_z" => [0.5], "alpha_i" => [0.2], "alpha_p" => [0.3],
            "beta_z"  => [0.4], "beta_i"  => [0.3], "beta_p"  => [0.3]))
    return net
end

function _net_exp_1ph()
    # pf_exp_1ph.dss: single-phase exponential load, gamma_p=1.4, gamma_q=2.0.
    net = _net_1ph_line()
    net["load"] = Dict{String,Any}(
        "ld1" => Dict{String,Any}(
            "bus"           => "lb",
            "terminal_map"  => ["1"],
            "configuration" => "SINGLE_PHASE",
            "p_nom"         => [15_000.0],
            "q_nom"         => [ 5_000.0],
            "model"         => "exponential",
            "v_nom"         => [240.0],
            "gamma_p"       => [1.4],
            "gamma_q"       => [2.0]))
    return net
end

function _net_zip_3ph()
    # pf_zip_3ph.dss: unbalanced wye ZIP loads on the 4-wire branch.
    net = _net_3ph_line()
    zf() = Dict{String,Any}(
        "model" => "zip", "v_nom" => [240.0],
        "alpha_z" => [0.45], "alpha_i" => [0.25], "alpha_p" => [0.30],
        "beta_z"  => [0.40], "beta_i"  => [0.30], "beta_p"  => [0.30])
    net["load"] = Dict{String,Any}(
        "ld1" => merge(Dict{String,Any}("bus"=>"lb","terminal_map"=>["1","n"],
            "configuration"=>"WYE","p_nom"=>[15_000.0],"q_nom"=>[5_000.0]), zf()),
        "ld2" => merge(Dict{String,Any}("bus"=>"lb","terminal_map"=>["2","n"],
            "configuration"=>"WYE","p_nom"=>[10_000.0],"q_nom"=>[3_000.0]), zf()),
        "ld3" => merge(Dict{String,Any}("bus"=>"lb","terminal_map"=>["3","n"],
            "configuration"=>"WYE","p_nom"=>[20_000.0],"q_nom"=>[7_000.0]), zf()))
    return net
end

function _net_zip_delta()
    # pf_zip_delta.dss: unbalanced delta ZIP bank (line-to-line, Vnom=415).
    net = _net_3ph_line()
    net["load"] = Dict{String,Any}(
        "dl" => Dict{String,Any}(
            "bus"           => "lb",
            "terminal_map"  => ["1", "2", "3"],
            "configuration" => "DELTA",
            "p_nom"         => [15_000.0, 10_000.0, 20_000.0],
            "q_nom"         => [ 5_000.0,  3_000.0,  7_000.0],
            "model"         => "zip",
            "v_nom"         => [415.0, 415.0, 415.0],
            "alpha_z" => [0.45, 0.45, 0.45], "alpha_i" => [0.25, 0.25, 0.25],
            "alpha_p" => [0.30, 0.30, 0.30], "beta_z"  => [0.40, 0.40, 0.40],
            "beta_i"  => [0.30, 0.30, 0.30], "beta_p"  => [0.30, 0.30, 0.30]))
    return net
end

function _net_pv_4leg(p_ph::Float64, q_ph, pf)
    # pf_pv_4leg.dss: 3φ wye PVSystem on the 4-wire branch, pinned to (p_ph,q_ph)
    # per phase, or P-pinned with a power_factor profile when `pf` is given.
    net = _net_3ph_line()
    delete!(net, "load")
    inv = Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["1", "2", "3", "n"],
        "topology" => "FOUR_LEG", "prime_mover" => "PV",
        "s_max" => fill(1.0e6, 3),
        "p_min" => fill(p_ph, 3), "p_max" => fill(p_ph, 3))
    if pf === nothing
        inv["q_min"] = fill(q_ph, 3); inv["q_max"] = fill(q_ph, 3)
    else
        inv["control_profile"] = "cpf"
        net["control_profile"] = Dict{String,Any}(
            "cpf" => Dict{String,Any}("power_factor" => Dict{String,Any}("pf" => pf)))
    end
    net["inverter"] = Dict{String,Any}("pv" => inv)
    return net
end

function _net_pv_1ph(p::Float64, q, pf)
    # pf_pv_1ph.dss: single-phase earth-return PVSystem. The SINGLE_PHASE inverter
    # references a grounded neutral terminal at lb (= V=0 ground reference).
    net = _net_1ph_line()
    delete!(net, "load")
    net["bus"]["lb"]["terminal_names"] = ["1", "n"]
    net["bus"]["lb"]["perfectly_grounded_terminals"] = ["n"]
    inv = Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["1", "n"],
        "topology" => "SINGLE_PHASE", "prime_mover" => "PV",
        "s_max" => [1.0e6], "p_min" => [p], "p_max" => [p])
    if pf === nothing
        inv["q_min"] = [q]; inv["q_max"] = [q]
    else
        inv["control_profile"] = "cpf"
        net["control_profile"] = Dict{String,Any}(
            "cpf" => Dict{String,Any}("power_factor" => Dict{String,Any}("pf" => pf)))
    end
    net["inverter"] = Dict{String,Any}("pv" => inv)
    return net
end

# ── Test cases ────────────────────────────────────────────────────────────────

@testset "PF comparison — single-phase 2-wire line" begin
    path = joinpath(_PF_CMP_DIR, "pf_1ph_line.dss")
    V_ods          = _ods_volts(path)
    V_bm, slack_A  = _bmopf_volts(_net_1ph_line())

    @test slack_A < 1e-3

    _cmp_volts(V_ods, V_bm; label="1ph-line: ")
end

@testset "PF comparison — three-phase 4-wire unbalanced line" begin
    path = joinpath(_PF_CMP_DIR, "pf_3ph_line.dss")
    V_ods          = _ods_volts(path)
    V_bm, slack_A  = _bmopf_volts(_net_3ph_line())

    @test slack_A < 1e-3

    _cmp_volts(V_ods, V_bm; label="3ph-line: ")
end

@testset "PF comparison — three-phase delta load on a 4-wire branch" begin
    path = joinpath(_PF_CMP_DIR, "pf_delta_load.dss")
    net            = _net_delta_load()
    V_ods          = _ods_volts(path)
    res            = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    V_bm, slack_A  = _bmopf_volts(net)

    @test slack_A < 1e-3

    # Node voltages must match OpenDSS (phase terminals + neutral).
    _cmp_volts(V_ods, V_bm; label="delta-load: ")

    # Physics: a pure delta load draws no zero-sequence current, so the line
    # neutral stays at earth potential despite the phase imbalance.
    @test abs(V_bm["lb.4"]) < 1.0

    # Per-arm power must match the requested constant-power setpoints. This is the
    # direct check that the result extractor reports DELTA power line-to-line
    # (arm voltage), not phase-to-ground.
    ld = res["load"]["dl"]
    @test ld["1"]["pd"] ≈ 15_000.0  atol=1.0
    @test ld["1"]["qd"] ≈  5_000.0  atol=1.0
    @test ld["2"]["pd"] ≈ 10_000.0  atol=1.0
    @test ld["2"]["qd"] ≈  3_000.0  atol=1.0
    @test ld["3"]["pd"] ≈ 20_000.0  atol=1.0
    @test ld["3"]["qd"] ≈  7_000.0  atol=1.0
end

# ── Four-wire grounding study (single-phase load) ──────────────────────────────
# Three load-bus neutral conditions, each compared against OpenDSS. Together they
# regression-guard the ground-injection current variable at perfectly grounded and
# source-pinned neutral terminals: without it the determined power flow (solve_pf)
# of the impedance/perfect cases is infeasible (the neutral return current has no
# earth path) and the feasibility OPF needs non-zero slack. The neutral-rise
# ladder free > impedance > perfect = 0 distinguishes the three cases.

@testset "PF comparison — 1φ load, FREE load-bus neutral" begin
    path = joinpath(_PF_CMP_DIR, "pf_1ph_freeneutral.dss")
    net           = _net_1ph_freeneutral()
    V_ods         = _ods_volts(path)
    V_bm, slack_A = _bmopf_volts(net)
    @test slack_A < 1e-3
    _cmp_volts(V_ods, V_bm; label="1ph-free: ")
    # Free neutral: full single-phase return through the line neutral → ~20 V rise.
    @test abs(V_bm["lb.4"]) > 15.0
    # solve_pf (determined) must also solve and agree with the feasibility voltages.
    V_pf = _bmopf_volts_pf(net)
    @test isapprox(V_pf["lb.4"], V_bm["lb.4"]; atol=0.5)
    @test isapprox(V_pf["lb.1"], V_bm["lb.1"]; atol=0.5)
end

@testset "PF comparison — 1φ load, IMPEDANCE-grounded neutral (Z=0.2Ω)" begin
    path = joinpath(_PF_CMP_DIR, "pf_1ph_impedanceneutral.dss")
    net           = _net_1ph_impedanceneutral()
    V_ods         = _ods_volts(path)
    V_bm, slack_A = _bmopf_volts(net)
    @test slack_A < 1e-3
    _cmp_volts(V_ods, V_bm; label="1ph-impedance: ")
    # Impedance ground: neutral rise between the free and perfect cases (~8 V).
    @test 4.0 < abs(V_bm["lb.4"]) < 15.0
    # Determined power flow: previously INFEASIBLE; the ground-injection fix makes
    # it solve and match the feasibility solution.
    V_pf = _bmopf_volts_pf(net)
    @test isapprox(V_pf["lb.4"], V_bm["lb.4"]; atol=0.5)
    @test isapprox(V_pf["lb.1"], V_bm["lb.1"]; atol=0.5)
end

@testset "PF comparison — 1φ load, PERFECTLY grounded neutral" begin
    path = joinpath(_PF_CMP_DIR, "pf_1ph_perfectneutral.dss")
    net           = _net_1ph_perfectneutral()
    V_ods         = _ods_volts(path)
    V_bm, slack_A = _bmopf_volts(net)
    @test slack_A < 1e-3
    _cmp_volts(V_ods, V_bm; label="1ph-perfect: ")
    # Perfect ground pins the load-bus neutral to 0 V exactly.
    @test abs(V_bm["lb.4"]) < 1e-6
    # Determined power flow: previously INFEASIBLE; now solves and agrees.
    V_pf = _bmopf_volts_pf(net)
    @test abs(V_pf["lb.4"]) < 1e-6
    @test isapprox(V_pf["lb.1"], V_bm["lb.1"]; atol=0.5)
end

@testset "PF comparison — single-phase ZIP load (mixed Z/I/P, P and Q)" begin
    path = joinpath(_PF_CMP_DIR, "pf_zip_1ph.dss")
    net           = _net_zip_1ph()
    V_ods         = _ods_volts(path)
    res           = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    V_bm, slack_A = _bmopf_volts(net)

    @test slack_A < 1e-3
    _cmp_volts(V_ods, V_bm; label="zip-1ph: ")

    # Lock the ZIP evaluation (incl. the reactive beta path) against the solved V.
    v   = abs(V_bm["lb.1"]) / 240.0
    pd  = res["load"]["ld1"]["1"]["pd"]
    qd  = res["load"]["ld1"]["1"]["qd"]
    @test pd ≈ 15_000.0 * (0.5v^2 + 0.2v + 0.3)   rtol=1e-4
    @test qd ≈  5_000.0 * (0.4v^2 + 0.3v + 0.3)   rtol=1e-4
    @test !isapprox(qd, 5_000.0; rtol=1e-3)   # Q genuinely voltage-dependent
end

@testset "PF comparison — single-phase exponential load (gamma_p≠gamma_q)" begin
    path          = joinpath(_PF_CMP_DIR, "pf_exp_1ph.dss")
    net           = _net_exp_1ph()
    V_ods         = _ods_volts(path)
    res           = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    V_bm, slack_A = _bmopf_volts(net)

    @test slack_A < 1e-3
    _cmp_volts(V_ods, V_bm; label="exp-1ph: ")

    v  = abs(V_bm["lb.1"]) / 240.0
    pd = res["load"]["ld1"]["1"]["pd"]
    qd = res["load"]["ld1"]["1"]["qd"]
    @test pd ≈ 15_000.0 * v^1.4   rtol=1e-4
    @test qd ≈  5_000.0 * v^2.0   rtol=1e-4
    @test !isapprox(qd, 5_000.0; rtol=1e-3)
end

@testset "PF comparison — three-phase unbalanced ZIP loads (4-wire)" begin
    path          = joinpath(_PF_CMP_DIR, "pf_zip_3ph.dss")
    net           = _net_zip_3ph()
    V_ods         = _ods_volts(path)
    res           = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    V_bm, slack_A = _bmopf_volts(net)

    @test slack_A < 1e-3
    _cmp_volts(V_ods, V_bm; label="zip-3ph: ")

    # Per-phase ZIP evaluation (phase-to-neutral controlling voltage).
    for (lid, t, p0, q0) in (("ld1","1",15_000.0,5_000.0),
                             ("ld2","2",10_000.0,3_000.0),
                             ("ld3","3",20_000.0,7_000.0))
        vpn = abs(V_bm["lb.$t"] - V_bm["lb.4"]) / 240.0
        @test res["load"][lid][t]["pd"] ≈ p0*(0.45vpn^2 + 0.25vpn + 0.30)  rtol=1e-3
        @test res["load"][lid][t]["qd"] ≈ q0*(0.40vpn^2 + 0.30vpn + 0.30)  rtol=1e-3
    end
end

@testset "PF comparison — three-phase delta ZIP load (4-wire)" begin
    path          = joinpath(_PF_CMP_DIR, "pf_zip_delta.dss")
    net           = _net_zip_delta()
    V_ods         = _ods_volts(path)
    res           = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    V_bm, slack_A = _bmopf_volts(net)

    @test slack_A < 1e-3
    _cmp_volts(V_ods, V_bm; label="zip-delta: ")
    @test abs(V_bm["lb.4"]) < 1.0   # pure delta → no neutral current

    # Per-arm ZIP evaluation with line-to-line controlling voltage (arms 1-2/2-3/3-1).
    arms = (("1", "1", "2", 15_000.0, 5_000.0),
            ("2", "2", "3", 10_000.0, 3_000.0),
            ("3", "3", "1", 20_000.0, 7_000.0))
    for (key, a, b, p0, q0) in arms
        vll = abs(V_bm["lb.$a"] - V_bm["lb.$b"]) / 415.0
        @test res["load"]["dl"][key]["pd"] ≈ p0*(0.45vll^2 + 0.25vll + 0.30)  rtol=1e-3
        @test res["load"]["dl"][key]["qd"] ≈ q0*(0.40vll^2 + 0.30vll + 0.30)  rtol=1e-3
    end
end

@testset "PF comparison — PVSystem inverter, FOUR_LEG (pinned & PF profile)" begin
    path = joinpath(_PF_CMP_DIR, "pf_pv_4leg.dss")
    V_ods, pw = _ods_pv(path)
    # Injected per-phase P/Q (balanced); element power is into the element, so negate.
    P = -real(pw[1]) * 1e3
    Q = -imag(pw[1]) * 1e3
    @test P ≈ 10_000.0 atol=50.0    # Pmpp 30 kW / 3 phases — clean operating point
    @test Q > 0                     # pf=0.95 in OpenDSS injects vars

    # (a) pinned to the read-back P and Q
    Vp, rp = _bmopf_volts_opf(_net_pv_4leg(P, Q, nothing))
    @test rp["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, Vp; label="pv-4leg-pin: ")
    @test rp["inverter"]["pv"]["1"]["pg"] ≈ P  atol=1.0
    @test rp["inverter"]["pv"]["1"]["qg"] ≈ Q  atol=1.0

    # (b) P-pinned, Q from a power_factor profile. OpenDSS pf=+0.95 injects vars,
    # so the equivalent BMOPF profile is pf = -0.95.
    Vf, rf = _bmopf_volts_opf(_net_pv_4leg(P, nothing, -0.95))
    @test rf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, Vf; label="pv-4leg-pf: ")
    @test rf["inverter"]["pv"]["1"]["qg"] ≈ Q  atol=1.0   # PF path reproduces OpenDSS Q
end

@testset "PF comparison — PVSystem inverter, SINGLE_PHASE (pinned & PF profile)" begin
    path = joinpath(_PF_CMP_DIR, "pf_pv_1ph.dss")
    V_ods, pw = _ods_pv(path)
    P = -real(pw[1]) * 1e3
    Q = -imag(pw[1]) * 1e3
    @test P ≈ 8_000.0 atol=50.0
    @test Q > 0

    Vp, rp = _bmopf_volts_opf(_net_pv_1ph(P, Q, nothing))
    @test rp["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, Vp; label="pv-1ph-pin: ")
    @test rp["inverter"]["pv"]["1"]["pg"] ≈ P  atol=1.0
    @test rp["inverter"]["pv"]["1"]["qg"] ≈ Q  atol=1.0

    Vf, rf = _bmopf_volts_opf(_net_pv_1ph(P, nothing, -0.95))
    @test rf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, Vf; label="pv-1ph-pf: ")
    @test rf["inverter"]["pv"]["1"]["qg"] ≈ Q  atol=1.0
end

@testset "feasibility OPF honours inverters (regression)" begin
    # Before the fix, solve_feasibility_opf never called _add_inverter_constraints!,
    # so the inverter was ignored and its ~30 kW was absorbed by the elastic KCL
    # slack. With the fix the inverter balances KCL and the slack is ~0.
    path = joinpath(_PF_CMP_DIR, "pf_pv_4leg.dss")
    V_ods, pw = _ods_pv(path)
    P = -real(pw[1]) * 1e3
    Q = -imag(pw[1]) * 1e3

    res = solve_feasibility_opf(_net_pv_4leg(P, Q, nothing); optimizer=Ipopt.Optimizer)
    @test res["total_slack_magnitude_A"] < 1e-3       # inverter (not slack) closes KCL
    @test res["inverter"]["pv"]["1"]["pg"] ≈ P  atol=1.0
    @test res["inverter"]["pv"]["1"]["qg"] ≈ Q  atol=1.0

    V_bm = Dict{String,ComplexF64}()
    for (bid, td) in res["bus"], (t, tv) in td
        V_bm[bid * "." * (t == "n" ? "4" : t)] = tv["vr"] + im * tv["vi"]
    end
    _cmp_volts(V_ods, V_bm; label="pv-4leg-feas: ")
end

@testset "PF comparison — single-phase transformer (single_phase YY)" begin
    path = joinpath(_PF_CMP_DIR, "pf_1ph_xfmr.dss")
    net            = _net_1ph_xfmr()
    V_ods          = _ods_volts(path)
    V_bm, slack_A  = _bmopf_volts(net)

    @test slack_A < 1e-3
    @test haskey(get(net, "transformer", Dict()), "single_phase")

    _cmp_volts(V_ods, V_bm; label="1ph-xfmr: ")
end

# Yd/Dy transformer PF comparison vs OpenDSS. The delta-winding leakage is
# referred to the wye side with the delta-COIL (line-to-line) base, matching
# OpenDSS Transformer.pas: Y_term[i,j] = Y_1volt[i,j]/(VBase_i·VBase_j), with
# VBase_delta = kVLL (not kVLL/√3). In _add_yd_transformer! this is the n_ph
# factor (Zd_scale) on the delta-arm series drop — without it the delta arm
# under-refers by 1:n_ph, giving the historical 3/4 effective-Z deficit.
@testset "PF comparison — wye-delta transformer (wye_delta Yd)" begin
    path = joinpath(_PF_CMP_DIR, "pf_yd_xfmr.dss")
    net   = _net_yd_xfmr()
    V_ods = _ods_volts(path)

    res     = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    V_bm    = Dict(bid * "." * (t == "n" ? "4" : t) => tv["vr"] + im*tv["vi"]
                   for (bid, td) in res["bus"] for (t, tv) in td)
    slack_A = res["total_slack_magnitude_A"]

    @test slack_A < 1e-3
    @test haskey(get(net, "transformer", Dict()), "wye_delta")

    _cmp_volts(V_ods, V_bm; label="Yd-xfmr: ", atol=0.1)

    P_ods = _ods_losses_W(path)
    P_bm  = _bmopf_losses_W(res, net)
    # Total losses (copper ~6.6 kW + core ~1.5 kW) match OpenDSS: the no-load
    # shunt is referred to the line-to-neutral stamping voltage V_LN = vf/√3, so
    # core loss = g_no_load·V_LN² = %noloadloss·kVA exactly (see _net_yd_xfmr).
    @test isapprox(P_bm, P_ods; rtol=0.05)
end

@testset "PF comparison — delta-wye transformer (delta_wye Dy)" begin
    path = joinpath(_PF_CMP_DIR, "pf_dy_xfmr.dss")
    net   = _net_dy_xfmr()
    V_ods = _ods_volts(path)

    res     = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    V_bm    = Dict(bid * "." * (t == "n" ? "4" : t) => tv["vr"] + im*tv["vi"]
                   for (bid, td) in res["bus"] for (t, tv) in td)
    slack_A = res["total_slack_magnitude_A"]

    @test slack_A < 1e-3
    @test haskey(get(net, "transformer", Dict()), "delta_wye")

    _cmp_volts(V_ods, V_bm; label="Dy-xfmr: ", atol=0.1)

    P_ods = _ods_losses_W(path)
    P_bm  = _bmopf_losses_W(res, net)
    # Total losses match OpenDSS — the no-load shunt base fix (V_LN-referred) makes
    # the core loss exact; see the Yd testset above.
    @test isapprox(P_bm, P_ods; rtol=0.05)
end

# Step voltage regulator (single_phase_autotransformer) vs OpenDSS. A fixed-tap
# regulator is a low-impedance two-winding transformer with the secondary turns
# scaled by Tap; the BMOPF autotransformer reproduces V_reg = a·V_src (Type B,
# n_eff = 1/a) plus the series drop. Defined neutral both sides → node voltages
# compare directly.
@testset "PF comparison — single-phase autotransformer (Type B regulator)" begin
    path  = joinpath(_PF_CMP_DIR, "pf_autotransformer.dss")
    net   = _net_autotransformer()
    V_ods = _ods_volts(path)
    V_bm, slack_A = _bmopf_volts(net)

    @test slack_A < 1e-3
    @test haskey(get(net, "transformer", Dict()), "single_phase_autotransformer")

    _cmp_volts(V_ods, V_bm; label="autotrafo: ")
end

# Open-delta regulator (open_delta_regulator) vs OpenDSS. OpenDSS builds the bank
# from two single-phase line-to-line transformers. Only the two regulated
# line-to-line voltages are physically pinned (the third floats — open-delta), so
# the comparison is on line-to-line magnitudes, not raw node voltages.
@testset "PF comparison — open-delta regulator (ABBC)" begin
    path  = joinpath(_PF_CMP_DIR, "pf_open_delta_reg.dss")
    net   = _net_open_delta_reg()
    V_ods = _ods_volts(path)

    res     = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    slack_A = res["total_slack_magnitude_A"]
    @test slack_A < 1e-3
    @test haskey(get(net, "transformer", Dict()), "open_delta_regulator")

    # Line-to-line magnitudes from each solver.
    rv = res["bus"]["reg"]
    Vll_bm(p, q) = abs((rv[p]["vr"] - rv[q]["vr"]) + im*(rv[p]["vi"] - rv[q]["vi"]))
    Vll_ods(p, q) = abs(V_ods["reg.$p"] - V_ods["reg.$q"])

    # reg1 across A-B (tap 1.05), reg2 across B-C (tap 1.025).
    @test Vll_bm("1", "2") ≈ Vll_ods("1", "2")   rtol=2e-3
    @test Vll_bm("2", "3") ≈ Vll_ods("2", "3")   rtol=2e-3
    # Boost ratios match the taps (source LL ≈ 4156.9 V).
    @test Vll_bm("1", "2") / (2400*sqrt(3)) ≈ 1.05   rtol=5e-3
    @test Vll_bm("2", "3") / (2400*sqrt(3)) ≈ 1.025  rtol=5e-3
end

# Galvanic straight-through (common-neutral model, Yan et al. 2018 Eq. 14/15).
# The open-delta SVR is two single-phase autotransformers sharing the middle
# phase (B in the ABBC arrangement), which is a copper wire straight through the
# bank — NOT galvanically isolated. The physically-correct "common neutral" model
# requires V_shared,from = V_shared,to, while the two regulated phases are boosted
# by their taps. (The line-to-line voltages alone cannot detect this — they are
# identical for the unspecified-neutral, neutral-shift, and common-neutral models;
# this test exercises the per-phase reference that the galvanic tie pins.)
@testset "open-delta regulator — galvanic straight-through (common neutral)" begin
    net = _net_open_delta_reg()
    res = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    @test res["total_slack_magnitude_A"] < 1e-3

    sv = res["bus"]["src"]; rv = res["bus"]["reg"]
    vm(d, t) = sqrt(d[t]["vr"]^2 + d[t]["vi"]^2)
    # ABBC → shared phase is "2" (in both regulator pairs (1,2) and (2,3)).
    # Common-neutral: the shared phase passes straight through unchanged.
    @test rv["2"]["vr"] ≈ sv["2"]["vr"]   atol=1e-3
    @test rv["2"]["vi"] ≈ sv["2"]["vi"]   atol=1e-3
    @test vm(rv, "2") ≈ vm(sv, "2")       rtol=1e-4
    # The two regulated phases are boosted above the (preserved) shared phase —
    # the hallmark of the common-neutral model (paper Fig. 6, Table III), not the
    # balanced result of the neutral-shift model.
    @test vm(rv, "1") > vm(rv, "2") + 1.0
    @test vm(rv, "3") > vm(rv, "2") + 1.0
end

# ── solve_pf cross-checks vs OpenDSS ────────────────────────────────────────────
# The determined power flow (solve_pf) must reproduce the same node voltages as
# OpenDSS on the same networks the feasibility OPF validates above. solve_pf
# enforces KCL exactly (no elastic slack) and imposes no bounds, so for these
# generator-free fixtures it is the canonical power flow. Each case mirrors its
# feasibility-OPF counterpart, swapping _bmopf_volts → _bmopf_volts_pf.

@testset "PF (solve_pf) comparison — single-phase 2-wire line" begin
    path  = joinpath(_PF_CMP_DIR, "pf_1ph_line.dss")
    V_ods = _ods_volts(path)
    V_bm  = _bmopf_volts_pf(_net_1ph_line())
    _cmp_volts(V_ods, V_bm; label="pf-1ph-line: ")
end

@testset "PF (solve_pf) comparison — three-phase 4-wire unbalanced line" begin
    path  = joinpath(_PF_CMP_DIR, "pf_3ph_line.dss")
    V_ods = _ods_volts(path)
    V_bm  = _bmopf_volts_pf(_net_3ph_line())
    _cmp_volts(V_ods, V_bm; label="pf-3ph-line: ")
end

@testset "PF (solve_pf) comparison — three-phase delta load on a 4-wire branch" begin
    path  = joinpath(_PF_CMP_DIR, "pf_delta_load.dss")
    net   = _net_delta_load()
    V_ods = _ods_volts(path)
    V_bm  = _bmopf_volts_pf(net)
    _cmp_volts(V_ods, V_bm; label="pf-delta-load: ")
    # Pure delta load draws no zero-sequence current → neutral stays at earth.
    @test abs(V_bm["lb.4"]) < 1.0
end

@testset "PF (solve_pf) comparison — single-phase transformer (single_phase YY)" begin
    path  = joinpath(_PF_CMP_DIR, "pf_1ph_xfmr.dss")
    net   = _net_1ph_xfmr()
    V_ods = _ods_volts(path)
    V_bm  = _bmopf_volts_pf(net)
    @test haskey(get(net, "transformer", Dict()), "single_phase")
    _cmp_volts(V_ods, V_bm; label="pf-1ph-xfmr: ")
end

@testset "PF (solve_pf) vs feasibility OPF — voltages agree on 3-phase line" begin
    # Internal consistency: on a feasible, generator-free network the determined
    # power flow and the (slack≈0) feasibility OPF must return the same voltages.
    net   = _net_3ph_line()
    V_pf  = _bmopf_volts_pf(net)
    V_fe, slack_A = _bmopf_volts(net)
    @test slack_A < 1e-3
    _cmp_volts(V_fe, V_pf; label="pf-vs-feas: ", atol=0.05)
end
