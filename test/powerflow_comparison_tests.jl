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
# Comparison tolerances (empirically grounded — agreement is already close to the
# achievable floor, so these are deliberately modest):
#   · atol=0.3 V, rtol=1e-3 (Yd/Dy keep atol=0.1 V).  For the ~240 V line/load
#     cases atol binds: lowering it from 1.0→0.3 V tightens those ~3.3x while still
#     leaving ≈3.4x over the worst observed phase-node error (≈0.088 V, in the
#     4-wire neutral cases).
#   · rtol is *not* tightened: the transformer LV side is the binding case
#     (Yd/Dy ≈7e-4 relative, ≈0.28/0.16 V on the 400/233 V secondary), only ~1.4x
#     under rtol=1e-3; the 4-wire neutral cases sit at ~2.7x.  At 75% rated load on
#     a 500 kVA / 0.415 kV unit the series drop is ≈10 V on the LV side, so 1e-3
#     still resolves <1% model agreement — a wrong sign/factor/impedance-side error
#     would produce >1 V.
#   · Per-unit and SI solves give identical voltages, so the floor is the network
#     model (chiefly the 4-wire / transformer-LV agreement), not solver scaling;
#     per-unit does not buy tighter agreement (and currently fails on ZIP loads).
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
    _ods_volts_loadmult(dss_path, mult) -> Dict{String, ComplexF64}

Like `_ods_volts` but re-solves with OpenDSS's global `LoadMult` scaling all
loads by `mult` (constant-P/Q is preserved by the case's `Vminpu=0 Vmaxpu=2`).
Used by the load-scaling sweep so the OpenDSS reference and the BMOPF net are
loaded identically.
"""
function _ods_volts_loadmult(dss_path::String, mult::Real)::Dict{String,ComplexF64}
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
    OpenDSSDirect.dss("Set LoadMult=$mult")
    OpenDSSDirect.dss("Solve")
    names = Circuit.AllNodeNames()
    volts = Circuit.AllBusVolts()
    return Dict(n => v for (n, v) in zip(names, volts))
end

"""
    _ods_volts_angle(dss_path, deg) -> Dict{String, ComplexF64}

Like `_ods_volts` but re-solves with the slack `Vsource.source` rotated to base
angle `deg` (degrees). `New Circuit` creates `Vsource.source` whose `angle` is the
phase-1 base angle (the 3-phase source stays internally balanced), so this offsets
every source phase by `deg`. Used to validate the BMOPF (radians) ↔ OpenDSS
(degrees) source-angle convention.
"""
function _ods_volts_angle(dss_path::String, deg::Real)::Dict{String,ComplexF64}
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
    OpenDSSDirect.dss("Edit Vsource.source angle=$deg")
    OpenDSSDirect.dss("Solve")
    names = Circuit.AllNodeNames()
    volts = Circuit.AllBusVolts()
    return Dict(n => v for (n, v) in zip(names, volts))
end

"""
    _reangle_source(net, dθ_rad) -> net

Deep-copy a BMOPF network and add `dθ_rad` (radians) to every `voltage_source`
terminal's `v_angle`, i.e. rotate the slack reference by `dθ_rad`. Neutral entries
carry `v_magnitude = 0`, so rotating their angle is harmless.
"""
function _reangle_source(net::Dict{String,Any}, dθ::Real)
    n = deepcopy(net)
    for (_, vs) in get(n, "voltage_source", Dict())
        haskey(vs, "v_angle") && (vs["v_angle"] = Float64.(vs["v_angle"]) .+ dθ)
    end
    return n
end

"""
    _scale_loads(net, mult) -> net

Deep-copy a BMOPF network and scale every load's `p_nom`/`q_nom` by `mult`,
mirroring OpenDSS `LoadMult` for the load-scaling sweep.
"""
function _scale_loads(net::Dict{String,Any}, mult::Real)
    n = deepcopy(net)
    for (_, ld) in get(n, "load", Dict())
        haskey(ld, "p_nom") && (ld["p_nom"] = Float64.(ld["p_nom"]) .* mult)
        haskey(ld, "q_nom") && (ld["q_nom"] = Float64.(ld["q_nom"]) .* mult)
    end
    return n
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
because the IBR constraints are only built by `solve_opf`. Buses carry no
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
    _cmp_volts(V_ods, V_bm; label="", atol=0.3, rtol=1e-3)

Assert that every node present in both dicts agrees within tolerance.
Nodes with |V_ref| < 1e-4 V (effectively the earth reference) are skipped.
At least one node must be compared.

Default tolerances are empirically grounded (see the test header). atol=0.3 binds
the ~240 V line/load nodes and sits ~3.4x above the worst observed phase-node
error (≈0.088 V, 4-wire neutral cases). rtol=1e-3 is NOT tightened: the binding
case is the transformer LV side (Yd/Dy ≈7e-4 relative, only ~1.4x of margin), with
the 4-wire neutral cases at ~2.7x. Per-unit and SI solves give identical voltages,
so the limiting factor is the network model, not solver scaling.
"""
function _cmp_volts(V_ods::Dict, V_bm::Dict;
                    label::String="", atol::Float64=0.3, rtol::Float64=1e-3)
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
    #   v_nom_from = 11 000 V, v_nom_to = 240 V, s_rating = 50 000 VA
    #   z_base_from = 11000² / 50000 = 2420 Ω
    #   z_base_to   =   240² / 50000 = 1.152 Ω
    #   r_series_from = 0.01 × 2420 = 24.2 Ω
    #   r_series_to   = 0.01 × 1.152 = 0.01152 Ω
    #   x_series_from = 0.04 × 2420 = 96.8 Ω  (all xsc on winding 1)
    #   x_series_to   = 0.0
    #
    # No-load branch (on from side):
    #   y_base = s / v_nom_from² = 50000 / 11000² = 4.132e-7 S
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
                    "v_nom_from"       => vf,
                    "v_nom_to"         => vt,
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

function _net_3wdg_nwinding()
    # pf_3wdg_nwinding.dss: hv ──[3-winding YYY xfmr]── mv, lv
    #   wdg1 hv 115 kV, wdg2 mv 24.9 kV, wdg3 lv 4.16 kV; 30 MVA; %r = 0.3/0.4/0.4
    #   XHL=8 XHT=8 XLT=6 (% on winding-1 base)
    #
    # Impedance conversion (all on a per-phase basis; v_nom is phase-to-neutral):
    #   z_base_k     = (kv_k·1000)² / s_rating          [per-phase Ω]
    #   r_winding[k] = %r_k/100 · z_base_k              [own base]
    #   x_sc["i_j"]  = X_ij%/100 · z_base_1             [referred to winding 1]
    s = 30.0e6
    zb(kv) = (kv * 1e3)^2 / s
    vpn(kv) = kv * 1e3 / sqrt(3)
    mkw(bus, kv, pr) = Dict{String,Any}(
        "bus"          => bus,
        "terminal_map" => ["a", "b", "c", "n"],
        "v_nom"        => vpn(kv),
        "configuration"   => "WYE",
        "r_winding"    => pr / 100 * zb(kv))
    grounded(_) = Dict{String,Any}(
        "terminal_names" => ["a", "b", "c", "n"],
        "neutral_terminal" => "n",
        "perfectly_grounded_terminals" => ["n"])
    wyeload(bus, p, q) = Dict{String,Any}(
        "bus" => bus, "terminal_map" => ["a", "b", "c", "n"],
        "configuration" => "WYE", "model" => "constant_power",
        "p_nom" => [p, p, p], "q_nom" => [q, q, q])
    Dict{String,Any}(
        "name" => "pf_3wdg_nwinding",
        "bus"  => Dict{String,Any}(
            "hv" => grounded("hv"), "mv" => grounded("mv"), "lv" => grounded("lv")),
        "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}(
            "bus" => "hv", "terminal_map" => ["a", "b", "c", "n"],
            "v_magnitude" => [vpn(115), vpn(115), vpn(115), 0.0],
            "v_angle"     => [0.0, -2.0943951023931953, 2.0943951023931953, 0.0])),
        "load" => Dict{String,Any}(
            "ldmv" => wyeload("mv", 1.0e6, 2.0e5),
            "ldlv" => wyeload("lv", 5.0e5, 1.0e5)),
        "transformer" => Dict{String,Any}("n_winding" => Dict{String,Any}(
            "t1" => Dict{String,Any}(
                "windings" => [mkw("hv", 115.0, 0.3),
                               mkw("mv", 24.9, 0.4),
                               mkw("lv", 4.16, 0.4)],
                "x_sc" => Dict{String,Any}(
                    "1_2" => 8 / 100 * zb(115.0),
                    "1_3" => 8 / 100 * zb(115.0),
                    "2_3" => 6 / 100 * zb(115.0)),
                "s_rating" => s))))
end

function _net_3wdg_nwinding_unbalanced()
    # pf_3wdg_nwinding_unbalanced.dss: same 3-winding unit, single-phase loads on
    # different phases (a,b on MV; c on LV) to exercise per-phase star independence.
    net = _net_3wdg_nwinding()
    net["name"] = "pf_3wdg_nwinding_unb"
    net["load"] = Dict{String,Any}(
        "m1" => Dict{String,Any}("bus"=>"mv","terminal_map"=>["a","n"],
            "configuration"=>"WYE","model"=>"constant_power","p_nom"=>[2.0e6],"q_nom"=>[4.0e5]),
        "m2" => Dict{String,Any}("bus"=>"mv","terminal_map"=>["b","n"],
            "configuration"=>"WYE","model"=>"constant_power","p_nom"=>[5.0e5],"q_nom"=>[5.0e4]),
        "l3" => Dict{String,Any}("bus"=>"lv","terminal_map"=>["c","n"],
            "configuration"=>"WYE","model"=>"constant_power","p_nom"=>[1.2e6],"q_nom"=>[3.0e5]))
    net
end

function _net_4wdg_nwinding()
    # pf_4wdg_nwinding.dss: 4-winding HV/MV/LV/TV (115/24.9/4.16/2.4 kV).
    # Xscarray=[8 8 8 6 6 4] → x_sc pairs (1_2,1_3,1_4,2_3,2_4,3_4). The ZB model
    # reproduces all six pairwise reactances exactly (no star approximation).
    s = 30.0e6
    zb(kv) = (kv * 1e3)^2 / s
    vpn(kv) = kv * 1e3 / sqrt(3)
    mkw(bus, kv, pr) = Dict{String,Any}(
        "bus" => bus, "terminal_map" => ["a","b","c","n"],
        "v_nom" => vpn(kv), "configuration" => "WYE", "r_winding" => pr / 100 * zb(kv))
    grounded(_) = Dict{String,Any}(
        "terminal_names" => ["a","b","c","n"], "neutral_terminal" => "n",
        "perfectly_grounded_terminals" => ["n"])
    wyeload(bus, p, q) = Dict{String,Any}(
        "bus" => bus, "terminal_map" => ["a","b","c","n"],
        "configuration" => "WYE", "model" => "constant_power",
        "p_nom" => [p/3, p/3, p/3], "q_nom" => [q/3, q/3, q/3])
    Dict{String,Any}(
        "name" => "pf_4wdg_nwinding",
        "bus" => Dict{String,Any}(
            "hv"=>grounded("hv"), "mv"=>grounded("mv"),
            "lv"=>grounded("lv"), "tv"=>grounded("tv")),
        "voltage_source" => Dict{String,Any}("s" => Dict{String,Any}(
            "bus" => "hv", "terminal_map" => ["a","b","c","n"],
            "v_magnitude" => [vpn(115), vpn(115), vpn(115), 0.0],
            "v_angle" => [0.0, -2.0943951023931953, 2.0943951023931953, 0.0])),
        "load" => Dict{String,Any}(
            "lm" => wyeload("mv", 2.0e6, 4.0e5),
            "ll" => wyeload("lv", 1.0e6, 2.0e5),
            "lt" => wyeload("tv", 8.0e5, 1.5e5)),
        "transformer" => Dict{String,Any}("n_winding" => Dict{String,Any}(
            "t1" => Dict{String,Any}(
                "windings" => [mkw("hv",115.0,0.3), mkw("mv",24.9,0.4),
                               mkw("lv",4.16,0.4), mkw("tv",2.4,0.4)],
                "x_sc" => Dict{String,Any}(
                    "1_2" => 8/100*zb(115.0), "1_3" => 8/100*zb(115.0),
                    "1_4" => 8/100*zb(115.0), "2_3" => 6/100*zb(115.0),
                    "2_4" => 6/100*zb(115.0), "3_4" => 4/100*zb(115.0)),
                "s_rating" => s))))
end

# ── n-winding transformers WITH delta windings ──────────────────────────────────
# Shared builders for the delta-winding matrix. Every winding's r_winding and the
# x_sc entries are on the per-winding COIL base z_coil = n_ph·v_nom²/S — which is
# V_LL²/S for a WYE winding but n_ph·V_LL²/S for a DELTA winding (the √3/coil-base
# factor lives in v_nom). OpenDSS's standard delta is delta_roll = -1 (the 30°
# vector-group rotation). See src/io/nwinding.jl for the convention.
const _NWD_S   = 30.0e6
const _NWD_NPH = 3

_nwd_zcoil(kv, conn) = conn == "DELTA" ? _NWD_NPH * (kv*1e3)^2 / _NWD_S :
                                                    (kv*1e3)^2 / _NWD_S

function _nwd_winding(bus, kv, conn, pr; roll=-1)
    if conn == "DELTA"
        Dict{String,Any}("bus"=>bus, "terminal_map"=>["a","b","c"],
            "v_nom"=>kv*1e3, "configuration"=>"DELTA", "delta_roll"=>roll,
            "r_winding"=>pr/100 * _nwd_zcoil(kv, "DELTA"))
    else
        Dict{String,Any}("bus"=>bus, "terminal_map"=>["a","b","c","n"],
            "v_nom"=>kv*1e3/sqrt(3), "configuration"=>"WYE",
            "r_winding"=>pr/100 * _nwd_zcoil(kv, "WYE"))
    end
end

# x_sc (Ω) from %-values, referred to winding-1's coil base.
_nwd_xsc(kv1, conn1, xsc_pct) =
    Dict{String,Any}(k => v/100 * _nwd_zcoil(kv1, conn1) for (k, v) in xsc_pct)

_nwd_grounded() = Dict{String,Any}("terminal_names"=>["a","b","c","n"],
    "neutral_terminal"=>"n", "perfectly_grounded_terminals"=>["n"])
# Bus whose neutral is NOT solidly grounded (grounded through a shunt, or floats).
_nwd_softbus() = Dict{String,Any}("terminal_names"=>["a","b","c","n"],
    "neutral_terminal"=>"n")
function _nwd_src(kv)
    vpn = kv*1e3/sqrt(3)
    Dict{String,Any}("bus"=>"hv", "terminal_map"=>["a","b","c","n"],
        "v_magnitude"=>[vpn, vpn, vpn, 0.0],
        "v_angle"=>[0.0, -2.0943951023931953, 2.0943951023931953, 0.0])
end
_nwd_wyeload(bus, p, q) = Dict{String,Any}("bus"=>bus, "terminal_map"=>["a","b","c","n"],
    "configuration"=>"WYE", "model"=>"constant_power", "p_nom"=>[p,p,p], "q_nom"=>[q,q,q])
_nwd_1phload(bus, ph, p, q) = Dict{String,Any}("bus"=>bus, "terminal_map"=>[ph,"n"],
    "configuration"=>"WYE", "model"=>"constant_power", "p_nom"=>[p], "q_nom"=>[q])

# Node-voltage dict from a solve_pf result, keyed "bus.<1|2|3|4>" like _ods_volts.
function _nwd_bm_volts(res)
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
         for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
end

function _net_3wdg_dyn(; roll=-1)
    # pf_3wdg_dyn.dss: delta HV primary (source-grounded), grounded-wye MV/LV.
    Dict{String,Any}(
        "name" => "pf_3wdg_dyn",
        "bus"  => Dict{String,Any}(
            "hv"=>_nwd_grounded(), "mv"=>_nwd_grounded(), "lv"=>_nwd_grounded()),
        "voltage_source" => Dict{String,Any}("s" => _nwd_src(115.0)),
        "load" => Dict{String,Any}(
            "ldmv" => _nwd_wyeload("mv", 1.0e6, 2.0e5),
            "ldlv" => _nwd_wyeload("lv", 5.0e5, 1.0e5)),
        "transformer" => Dict{String,Any}("n_winding" => Dict{String,Any}(
            "t1" => Dict{String,Any}(
                "windings" => [_nwd_winding("hv", 115.0, "DELTA", 0.3; roll=roll),
                               _nwd_winding("mv", 24.9,  "WYE",   0.4),
                               _nwd_winding("lv", 4.16,  "WYE",   0.4)],
                "x_sc" => _nwd_xsc(115.0, "DELTA",
                    Dict("1_2"=>8.0, "1_3"=>8.0, "2_3"=>6.0)),
                "s_rating" => _NWD_S))))
end

function _net_3wdg_dyn_unbalanced()
    # pf_3wdg_dyn_unbalanced.dss: same Dyn unit, single-phase loads on a/b (MV), c (LV).
    net = _net_3wdg_dyn(); net["name"] = "pf_3wdg_dyn_unb"
    net["load"] = Dict{String,Any}(
        "m1" => _nwd_1phload("mv", "a", 2.0e6, 4.0e5),
        "m2" => _nwd_1phload("mv", "b", 5.0e5, 5.0e4),
        "l3" => _nwd_1phload("lv", "c", 1.2e6, 3.0e5))
    net
end

function _net_4wdg_dyyn()
    # pf_4wdg_dyyn.dss: delta HV primary + three grounded-wye secondaries (n=4).
    Dict{String,Any}(
        "name" => "pf_4wdg_dyyn",
        "bus"  => Dict{String,Any}(
            "hv"=>_nwd_grounded(), "mv"=>_nwd_grounded(),
            "lv"=>_nwd_grounded(), "tv"=>_nwd_grounded()),
        "voltage_source" => Dict{String,Any}("s" => _nwd_src(115.0)),
        "load" => Dict{String,Any}(
            "lm" => _nwd_wyeload("mv", 2.0e6/3, 4.0e5/3),
            "ll" => _nwd_wyeload("lv", 1.0e6/3, 2.0e5/3),
            "lt" => _nwd_wyeload("tv", 8.0e5/3, 1.5e5/3)),
        "transformer" => Dict{String,Any}("n_winding" => Dict{String,Any}(
            "t1" => Dict{String,Any}(
                "windings" => [_nwd_winding("hv", 115.0, "DELTA", 0.3),
                               _nwd_winding("mv", 24.9,  "WYE",   0.4),
                               _nwd_winding("lv", 4.16,  "WYE",   0.4),
                               _nwd_winding("tv", 2.4,   "WYE",   0.4)],
                "x_sc" => _nwd_xsc(115.0, "DELTA",
                    Dict("1_2"=>8.0, "1_3"=>8.0, "1_4"=>8.0,
                         "2_3"=>6.0, "2_4"=>6.0, "3_4"=>4.0)),
                "s_rating" => _NWD_S))))
end

function _net_3wdg_dyn_zgnd()
    # pf_3wdg_dyn_zgnd.dss: Dyn with the MV neutral grounded through 0.5 Ω (shunt
    # G = 2 S on mv.n), unbalanced MV load → neutral current lifts mv.4 off earth.
    net = _net_3wdg_dyn(); net["name"] = "pf_3wdg_dyn_zgnd"
    net["bus"]["mv"] = _nwd_softbus()
    net["shunt"] = Dict{String,Any}("mvgrnd" => Dict{String,Any}(
        "bus"=>"mv", "terminal_map"=>["n"], "G_1_1"=>2.0, "B_1_1"=>0.0))
    net["load"] = Dict{String,Any}(
        "m1"   => _nwd_1phload("mv", "a", 2.5e6, 5.0e5),
        "m2"   => _nwd_1phload("mv", "b", 8.0e5, 1.5e5),
        "ldlv" => _nwd_wyeload("lv", 3.0e5, 6.0e4))
    net
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
    #   v_nom_from = 11 000 V (wye, line voltage)
    #   v_nom_to   =    415 V (delta, line voltage)
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
                    "v_nom_from"       => vf,
                    "v_nom_to"         => vt,
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
    #   v_nom_from = 11 000 V (delta, line voltage)
    #   v_nom_to   =    415 V (wye, line voltage)
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
                    "v_nom_from"       => vf,
                    "v_nom_to"         => vt,
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
                "p_nom"         => [400_000.0],
                "q_nom"         => [100_000.0])))
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
    net["ibr"] = Dict{String,Any}("pv" => inv)
    return net
end

function _net_pv_1ph(p::Float64, q, pf)
    # pf_pv_1ph.dss: single-phase earth-return PVSystem. The SINGLE_PHASE IBR
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
    net["ibr"] = Dict{String,Any}("pv" => inv)
    return net
end

# ── Smart-IBR droop (Volt-var / Volt-watt) validation vs OpenDSS InvControl ─
#
# A single-phase, phase-to-perfectly-grounded-neutral PVSystem with a meaningful
# single-phase load on the same bus. OpenDSS drives the droop with an InvControl
# element (iterated to a fixed point); BMOPF's smooth-ReLU droop must reproduce
# the same converged operating point and node voltages, across all three regimes
# of each characteristic (deadband, slope, saturation).
#
# AS/NZS 4777.2:2020 "Australia A" curves on a 240 V (phase-to-neutral) base.
# Breakpoints below are SI volts (BMOPF) / pu-of-rated (OpenDSS XYcurve x-axis).
const _AUSA_VV_X = [207.0, 220.0, 240.0, 258.0]   # volt-var breakpoints [V]
const _AUSA_VV_Q = [-0.60, 0.44]                  # [absorb≤0, inject≥0] frac of s_max
const _AUSA_VW_X = [253.0, 260.0]                 # volt-watt breakpoints [V]
const _AUSA_VW_P = [0.20, 1.00]                   # [p_low, p_high] frac of Pmpp
const _PV_VRATED = 240.0

# Non-obvious OpenDSS settings (validated empirically — see commit message):
#   · Set DefaultBaseFreq=50 — lock the base frequency (BMOPF models at 50 Hz);
#     the OpenDSS default otherwise rescales every reactance.
#   · Set Tolerance=1e-8 / MaxIterations — drive OpenDSS convergence far below the
#     voltage-comparison tolerance so its iteration error is not a confound.
#   · Circuit source model=ideal (stiff slack)
#   · PVSystem & Load Vminpu=0.1 Vmaxpu=2.0 — keep constant-P/Q across the sweep;
#     the default Vmaxpu≈1.1 silently rescales power above ~1.1 pu.
#   · kvarMax=kvarMaxAbs=kVA with RefReactivePower=VARMAX → VV y-axis is a
#     fraction of kVA (matches BMOPF q_ref=VAR_MAX, q_base=s_max).
#   · voltwattyaxis=PMPPPU → VW y-axis is a fraction of Pmpp (matches p_ref=P_MAX).
#   · XYcurves carry flat guard points outside [x1,xn] so OpenDSS CLAMPS instead
#     of extrapolating the end slope (BMOPF's ReLU-sum clamps).
#   · WattPriority=No → var priority on the kVA circle (Q held, P curtailed).
#   · Earth return (PV/load wye point → ground node .0): this is OpenDSS's
#     phase-to-perfectly-grounded-neutral, matching the BMOPF grounded "n"
#     terminal. (An explicit, separately-grounded neutral node instead shorts the
#     return around the line, zeroing the line drop.)
function _ods_pv_droop(; vsrc, kVA, Pmpp, load_kw, load_kvar, mode::Symbol)
    vvx = join(vcat(0.5, _AUSA_VV_X ./ _PV_VRATED, 2.0), ",")
    vvy = "0.44,0.44,0,0,-0.60,-0.60"
    vwx = join(vcat(0.5, _AUSA_VW_X ./ _PV_VRATED, 2.0), ",")
    vwy = "1.0,1.0,0.2,0.2"
    cmds = String[
        "Clear",
        "Set DefaultBaseFreq=50",   # lock base frequency (BMOPF models at 50 Hz)
        "New Circuit.c basekv=0.240 pu=$(vsrc/_PV_VRATED) angle=0 phases=1 bus1=src.1 model=ideal",
        "New Line.l1 bus1=src.1 bus2=lb.1 phases=1 length=0.5 units=km r1=0.5 x1=0.2",
        "New Load.ld bus1=lb.1 phases=1 kv=0.240 kW=$load_kw kvar=$load_kvar model=1 Vminpu=0.1 Vmaxpu=2.0",
        "New PVSystem.pv phases=1 conn=wye bus1=lb.1 kv=0.240 kVA=$kVA Pmpp=$Pmpp irradiance=1.0 " *
            "pf=1 %cutin=0 %cutout=0 VarFollowInverter=yes WattPriority=No " *
            "kvarMax=$kVA kvarMaxAbs=$kVA Vminpu=0.1 Vmaxpu=2.0",
        "New XYcurve.vv npts=6 Xarray=[$vvx] Yarray=[$vvy]",
        "New XYcurve.vw npts=4 Xarray=[$vwx] Yarray=[$vwy]"]
    ic = mode === :vv ?
        "New InvControl.ic mode=VOLTVAR vvc_curve1=vv voltage_curvex_ref=rated " *
            "RefReactivePower=VARMAX VarChangeTolerance=0.0005 VoltageChangeTolerance=1e-5" :
        mode === :vw ?
        "New InvControl.ic mode=VOLTWATT voltwatt_curve=vw voltage_curvex_ref=rated " *
            "voltwattyaxis=PMPPPU ActivePChangeTolerance=0.0005 VoltageChangeTolerance=1e-5" :
        "New InvControl.ic combimode=VV_VW vvc_curve1=vv voltwatt_curve=vw voltage_curvex_ref=rated " *
            "RefReactivePower=VARMAX voltwattyaxis=PMPPPU VarChangeTolerance=0.0005 " *
            "ActivePChangeTolerance=0.0005 VoltageChangeTolerance=1e-5"
    push!(cmds, ic)
    append!(cmds, ["Set VoltageBases=[0.240]", "CalcVoltageBases",
                   "Set Tolerance=1e-8", "Set MaxIterations=100",
                   "Set ControlMode=Static", "Set MaxControlIter=100", "Solve"])
    OpenDSSDirect.dss("Clear")
    for c in cmds
        OpenDSSDirect.dss(c)
    end
    volts = Dict(n => v for (n, v) in
                 zip(OpenDSSDirect.Circuit.AllNodeNames(), OpenDSSDirect.Circuit.AllBusVolts()))
    OpenDSSDirect.Circuit.SetActiveElement("PVSystem.pv")
    pw = OpenDSSDirect.CktElement.Powers()
    P = -real(pw[1]) * 1e3
    Q = -imag(pw[1]) * 1e3
    return volts, P, Q
end

# Matching BMOPF network: single-phase PV (phase "1" to perfectly-grounded "n")
# plus a single-phase load on bus lb, with the Aus A droop control_profile.
function _net_pv_1ph_droop(; vsrc, kVA, Pmpp, load_kw, load_kvar, mode::Symbol,
                             p_ref::String="P_MAX")
    net = _net_1ph_line()
    delete!(net, "load")
    net["voltage_source"]["source"]["v_magnitude"] = [vsrc]
    net["voltage_source"]["source"]["cost"] = [1.0]
    net["bus"]["lb"]["terminal_names"] = ["1", "n"]
    net["bus"]["lb"]["perfectly_grounded_terminals"] = ["n"]

    net["load"] = Dict{String,Any}(
        "ld" => Dict{String,Any}(
            "bus" => "lb", "terminal_map" => ["1", "n"],
            "configuration" => "SINGLE_PHASE",
            "p_nom" => [load_kw * 1e3], "q_nom" => [load_kvar * 1e3]))

    cp = Dict{String,Any}()
    if mode === :vv || mode === :vvvw
        cp["volt_var"] = Dict{String,Any}(
            "voltage_reference" => "PN_PER_PHASE", "breakpoints" => copy(_AUSA_VV_X),
            "q_limits" => copy(_AUSA_VV_Q), "q_unit" => "VA_FRACTION", "q_ref" => "VAR_MAX")
    end
    if mode === :vw || mode === :vvvw
        cp["volt_watt"] = Dict{String,Any}(
            "voltage_reference" => "PN_PER_PHASE", "breakpoints" => copy(_AUSA_VW_X),
            "p_limits" => copy(_AUSA_VW_P), "p_unit" => "VA_FRACTION", "p_ref" => p_ref)
    end
    net["control_profile"] = Dict{String,Any}("cp" => cp)
    inv = Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["1", "n"],
        "topology" => "SINGLE_PHASE", "prime_mover" => "PV",
        "s_max" => [kVA * 1e3], "p_min" => [0.0], "p_max" => [Pmpp * 1e3],
        "control_profile" => "cp", "cost" => [0.1])
    # Volt-watt-only: no volt_var, so pin Q=0 to mirror OpenDSS pf=1 (otherwise the
    # box-bounded reactive power is unconstrained and the OPF picks an arbitrary Q).
    if mode === :vw
        inv["q_min"] = [0.0]
        inv["q_max"] = [0.0]
    end
    net["ibr"] = Dict{String,Any}("pv" => inv)
    return net
end

# ── Three-phase per-phase droop under unbalance ─────────────────────────────────
# A 4-wire unbalanced feeder with a perfectly-grounded load-bus neutral. BMOPF
# models one FOUR_LEG IBR (per-phase droop on |V_k − V_n|, with V_n = 0).
# OpenDSS models the per-phase control as THREE independent single-phase PVSystems
# (one per phase), each with its own InvControl monitoring its own phase voltage —
# a single 3φ PVSystem would instead average the phases and output balanced power,
# which is a different control law. The grounded neutral makes phase-to-ground
# (what InvControl monitors) equal phase-to-neutral (what FOUR_LEG monitors), so
# under genuine per-phase voltage spread the two models coincide.
const _LC4_DSS = "New Linecode.4w nphases=4 units=km " *
    "Rmatrix=[0.5|0.02 0.5|0.02 0.02 0.5|0.02 0.02 0.02 0.5] " *
    "Xmatrix=[0.2|0.05 0.2|0.05 0.05 0.2|0.05 0.05 0.05 0.2] " *
    "Cmatrix=[0|0 0|0 0 0|0 0 0 0]"

function _ods_pv_3ph_droop(; vsrc, kVA, Pmpp, loads, mode::Symbol)
    vvx = join(vcat(0.5, _AUSA_VV_X ./ _PV_VRATED, 2.0), ",")
    vwx = join(vcat(0.5, _AUSA_VW_X ./ _PV_VRATED, 2.0), ",")
    cmds = String[
        "Clear",
        "Set DefaultBaseFreq=50",   # lock base frequency (BMOPF models at 50 Hz)
        "New Circuit.c basekv=$(vsrc*sqrt(3)/1000) pu=1.0 angle=0 phases=3 bus1=src.1.2.3 model=ideal",
        "New Reactor.gs bus1=src.4 bus2=src.0 R=0.001 X=0",
        _LC4_DSS,
        "New Line.l1 bus1=src.1.2.3.4 bus2=lb.1.2.3.4 linecode=4w length=0.5 units=km",
        "New Reactor.gl bus1=lb.4 bus2=lb.0 R=0.001 X=0",
        "New XYcurve.vv npts=6 Xarray=[$vvx] Yarray=[0.44,0.44,0,0,-0.60,-0.60]",
        "New XYcurve.vw npts=4 Xarray=[$vwx] Yarray=[1.0,1.0,0.2,0.2]"]
    for k in 1:3
        push!(cmds, "New Load.ld$k bus1=lb.$k.4 phases=1 kv=0.240 kW=$(loads[k]) kvar=0 " *
                    "model=1 Vminpu=0.1 Vmaxpu=2.0")
        push!(cmds, "New PVSystem.pv$k phases=1 conn=wye bus1=lb.$k.4 kv=0.240 kVA=$kVA Pmpp=$Pmpp " *
                    "irradiance=1.0 pf=1 %cutin=0 %cutout=0 VarFollowInverter=yes WattPriority=No " *
                    "kvarMax=$kVA kvarMaxAbs=$kVA Vminpu=0.1 Vmaxpu=2.0")
    end
    common = "voltage_curvex_ref=rated VoltageChangeTolerance=1e-5 PVSystemList=[pv1,pv2,pv3]"
    ic = mode === :vv ?
        "New InvControl.ic mode=VOLTVAR vvc_curve1=vv RefReactivePower=VARMAX VarChangeTolerance=0.0005 $common" :
        mode === :vw ?
        "New InvControl.ic mode=VOLTWATT voltwatt_curve=vw voltwattyaxis=PMPPPU ActivePChangeTolerance=0.0005 $common" :
        "New InvControl.ic combimode=VV_VW vvc_curve1=vv voltwatt_curve=vw RefReactivePower=VARMAX " *
            "voltwattyaxis=PMPPPU VarChangeTolerance=0.0005 ActivePChangeTolerance=0.0005 $common"
    push!(cmds, ic)
    append!(cmds, ["Set VoltageBases=[0.415]", "CalcVoltageBases",
                   "Set Tolerance=1e-8", "Set MaxIterations=100",
                   "Set ControlMode=Static", "Set MaxControlIter=200", "Solve"])
    OpenDSSDirect.dss("Clear")
    for c in cmds
        OpenDSSDirect.dss(c)
    end
    d = Dict(n => v for (n, v) in
             zip(OpenDSSDirect.Circuit.AllNodeNames(), OpenDSSDirect.Circuit.AllBusVolts()))
    P = zeros(3); Q = zeros(3)
    for k in 1:3
        OpenDSSDirect.Circuit.SetActiveElement("PVSystem.pv$k")
        pw = OpenDSSDirect.CktElement.Powers()
        P[k] = -real(pw[1]) * 1e3
        Q[k] = -imag(pw[1]) * 1e3
    end
    return d, P, Q
end

function _net_pv_3ph_droop(; vsrc, kVA, Pmpp, loads, mode::Symbol, vref::String="PER_PHASE")
    net = _net_3ph_line()
    delete!(net, "load")
    for k in 1:3
        net["voltage_source"]["source"]["v_magnitude"][k] = vsrc
    end
    net["voltage_source"]["source"]["cost"] = [1.0, 1.0, 1.0]
    net["bus"]["lb"]["perfectly_grounded_terminals"] = ["n"]

    net["load"] = Dict{String,Any}(
        "ld$k" => Dict{String,Any}(
            "bus" => "lb", "terminal_map" => ["$k", "n"], "configuration" => "WYE",
            "p_nom" => [loads[k] * 1e3], "q_nom" => [0.0]) for k in 1:3)

    cp = Dict{String,Any}()
    if mode === :vv || mode === :vvvw
        cp["volt_var"] = Dict{String,Any}(
            "voltage_reference" => "PN_PER_PHASE", "breakpoints" => copy(_AUSA_VV_X),
            "q_limits" => copy(_AUSA_VV_Q), "q_unit" => "VA_FRACTION", "q_ref" => "VAR_MAX")
    end
    if mode === :vw || mode === :vvvw
        cp["volt_watt"] = Dict{String,Any}(
            "voltage_reference" => "PN_PER_PHASE", "breakpoints" => copy(_AUSA_VW_X),
            "p_limits" => copy(_AUSA_VW_P), "p_unit" => "VA_FRACTION", "p_ref" => "P_MAX")
    end
    net["control_profile"] = Dict{String,Any}("cp" => cp)
    inv = Dict{String,Any}(
        "bus" => "lb", "terminal_map" => ["1", "2", "3", "n"],
        "topology" => "FOUR_LEG", "prime_mover" => "PV", "voltage_aggregation" => vref,
        "s_max" => fill(kVA * 1e3, 3), "p_min" => fill(0.0, 3), "p_max" => fill(Pmpp * 1e3, 3),
        "control_profile" => "cp", "cost" => fill(0.1, 3))
    if mode === :vw
        inv["q_min"] = fill(0.0, 3)
        inv["q_max"] = fill(0.0, 3)
    end
    net["ibr"] = Dict{String,Any}("pv" => inv)
    return net
end

# ── Three-phase AVERAGE-reference droop ─────────────────────────────────────────
# The averaging counterpart of the per-phase test above. Here OpenDSS models the
# control as ONE 3φ PVSystem with ONE InvControl whose MonVoltageCalc=AVG averages
# the monitored phase voltages and injects balanced power — exactly BMOPF's
# voltage_aggregation=AVERAGE (every phase sees the mean magnitude, equal s_max ⇒ balanced
# P/Q). The same unbalanced same-bus loads that spread the phases under PER_PHASE
# now leave the two models on a common operating point: identical balanced
# injection ⇒ identical node voltages despite the per-phase voltage spread.
function _ods_pv_3ph_avg_droop(; vsrc, kVA, Pmpp, loads, mode::Symbol)
    vvx = join(vcat(0.5, _AUSA_VV_X ./ _PV_VRATED, 2.0), ",")
    vwx = join(vcat(0.5, _AUSA_VW_X ./ _PV_VRATED, 2.0), ",")
    kVA3, Pmpp3 = 3kVA, 3Pmpp                  # 3φ ratings = 3 × per-phase
    kv_ll = _PV_VRATED * sqrt(3) / 1000        # rated per-phase = _PV_VRATED exactly
    cmds = String[
        "Clear",
        "Set DefaultBaseFreq=50",   # lock base frequency (BMOPF models at 50 Hz)
        "New Circuit.c basekv=$(vsrc*sqrt(3)/1000) pu=1.0 angle=0 phases=3 bus1=src.1.2.3 model=ideal",
        "New Reactor.gs bus1=src.4 bus2=src.0 R=0.001 X=0",
        _LC4_DSS,
        "New Line.l1 bus1=src.1.2.3.4 bus2=lb.1.2.3.4 linecode=4w length=0.5 units=km",
        "New Reactor.gl bus1=lb.4 bus2=lb.0 R=0.001 X=0",
        "New XYcurve.vv npts=6 Xarray=[$vvx] Yarray=[0.44,0.44,0,0,-0.60,-0.60]",
        "New XYcurve.vw npts=4 Xarray=[$vwx] Yarray=[1.0,1.0,0.2,0.2]"]
    for k in 1:3
        push!(cmds, "New Load.ld$k bus1=lb.$k.4 phases=1 kv=0.240 kW=$(loads[k]) kvar=0 " *
                    "model=1 Vminpu=0.1 Vmaxpu=2.0")
    end
    push!(cmds, "New PVSystem.pv phases=3 conn=wye bus1=lb.1.2.3.4 kv=$kv_ll kVA=$kVA3 Pmpp=$Pmpp3 " *
                "irradiance=1.0 pf=1 %cutin=0 %cutout=0 VarFollowInverter=yes WattPriority=No " *
                "kvarMax=$kVA3 kvarMaxAbs=$kVA3 Vminpu=0.1 Vmaxpu=2.0")
    common = "voltage_curvex_ref=rated MonVoltageCalc=AVG VoltageChangeTolerance=1e-5 PVSystemList=[pv]"
    ic = mode === :vv ?
        "New InvControl.ic mode=VOLTVAR vvc_curve1=vv RefReactivePower=VARMAX VarChangeTolerance=0.0005 $common" :
        mode === :vw ?
        "New InvControl.ic mode=VOLTWATT voltwatt_curve=vw voltwattyaxis=PMPPPU ActivePChangeTolerance=0.0005 $common" :
        "New InvControl.ic combimode=VV_VW vvc_curve1=vv voltwatt_curve=vw RefReactivePower=VARMAX " *
            "voltwattyaxis=PMPPPU VarChangeTolerance=0.0005 ActivePChangeTolerance=0.0005 $common"
    push!(cmds, ic)
    append!(cmds, ["Set VoltageBases=[0.415]", "CalcVoltageBases",
                   "Set Tolerance=1e-8", "Set MaxIterations=100",
                   "Set ControlMode=Static", "Set MaxControlIter=200", "Solve"])
    OpenDSSDirect.dss("Clear")
    for c in cmds
        OpenDSSDirect.dss(c)
    end
    d = Dict(n => v for (n, v) in
             zip(OpenDSSDirect.Circuit.AllNodeNames(), OpenDSSDirect.Circuit.AllBusVolts()))
    OpenDSSDirect.Circuit.SetActiveElement("PVSystem.pv")
    pw = OpenDSSDirect.CktElement.Powers()       # per-phase terminal powers, phases 1..3
    P = [-real(pw[k]) * 1e3 for k in 1:3]
    Q = [-imag(pw[k]) * 1e3 for k in 1:3]
    return d, P, Q
end

# Comparison for the 3φ AVERAGE droop: BMOPF injects balanced P/Q (the averaging
# signature) and its node voltages and injections match the single 3φ OpenDSS
# PVSystem + averaging InvControl.
function _check_pv_3ph_avg_droop(params, label; atolV=1.0, atolPQ=60.0)
    Vods, Pods, Qods = _ods_pv_3ph_avg_droop(; params...)
    res = solve_opf(_net_pv_3ph_droop(; params..., vref="AVERAGE"))
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    b = res["bus"]["lb"]
    @test sqrt(b["n"]["vr"]^2 + b["n"]["vi"]^2) < 1e-6
    Pbm = Float64[]; Qbm = Float64[]
    for k in 1:3
        iv = res["ibr"]["pv"]["$k"]
        push!(Pbm, iv["pg"]); push!(Qbm, iv["qg"])
        Vbm_k = abs((b["$k"]["vr"] - b["n"]["vr"]) + im * (b["$k"]["vi"] - b["n"]["vi"]))
        Vods_k = abs(Vods["lb.$k"] - Vods["lb.4"])
        isapprox(Vbm_k, Vods_k; atol=atolV) ||
            @warn "$(label)phase $k: V BMOPF=$(round(Vbm_k,digits=2)) ODS=$(round(Vods_k,digits=2))"
        @test isapprox(Vbm_k, Vods_k; atol=atolV)
        @test iv["pg"] ≈ Pods[k]   atol=atolPQ
        @test iv["qg"] ≈ Qods[k]   atol=atolPQ
    end
    # Averaging signature: equal s_max + shared reference ⇒ balanced injection.
    @test maximum(Pbm) - minimum(Pbm) < 1.0
    @test maximum(Qbm) - minimum(Qbm) < 1.0
    return Pbm, Qbm
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

# A single network solved across a load sweep: agreement must hold from light to
# heavy loading, and the voltage must sag monotonically with load — so each
# heavier step is a strictly stronger test of the series-drop physics than the
# last (a trivially-1pu network would expose no model error).  OpenDSS LoadMult
# and BMOPF p_nom/q_nom scaling are applied identically.  The range stops at
# ×1.5 (≈17% drop): this stiff 0.5 km line reaches its power-flow nose near ×2,
# beyond which the solution is no longer unique (the flat start and OpenDSS can
# land on different branches) — that is a property of the network, not a model
# disagreement, so it would make the comparison meaningless rather than stronger.
@testset "PF comparison — 3-phase line, load-scaling sweep" begin
    path     = joinpath(_PF_CMP_DIR, "pf_3ph_line.dss")
    base_net = _net_3ph_line()
    v_nom    = 415.0 / sqrt(3)
    prev_vmag = Inf
    for mult in (0.5, 1.0, 1.5)
        V_ods         = _ods_volts_loadmult(path, mult)
        V_bm, slack_A = _bmopf_volts(_scale_loads(base_net, mult))
        @test slack_A < 1e-3
        _cmp_volts(V_ods, V_bm; label="3ph-load×$(mult): ")
        # phase 3 carries the largest load (20 kW): its magnitude must drop
        # further below nominal at every heavier step.
        vmag = abs(V_bm["lb.3"])
        @test vmag < prev_vmag
        @test vmag < v_nom
        prev_vmag = vmag
    end
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

# Regression for the per-unit scaling of voltage-dependent loads: the ZIP and
# exponential models reference v_nom, which must move to per-unit with the bus
# voltage base.  Before the fix the SI solve was LOCALLY_SOLVED but the per-unit
# solve went LOCALLY_INFEASIBLE (per-unit V≈1 compared against an SI v_nom≈240).
# Constant-power loads ignore v_nom, so only these cases exercised the bug.
@testset "per-unit ZIP/exponential loads agree with SI (regression)" begin
    for (label, net) in (("zip-1ph",   _net_zip_1ph()),
                         ("zip-3ph",   _net_zip_3ph()),
                         ("zip-delta", _net_zip_delta()),
                         ("exp-1ph",   _net_exp_1ph()))
        r_si = solve_pf(net; optimizer=Ipopt.Optimizer)
        r_pu = solve_pf(net; optimizer=Ipopt.Optimizer, per_unit=true)
        @test r_pu["termination_status"] == r_si["termination_status"]
        for (bid, td) in r_si["bus"], (t, tv) in td
            v_si = tv["vr"] + im * tv["vi"]
            pv   = r_pu["bus"][bid][t]
            v_pu = pv["vr"] + im * pv["vi"]
            isapprox(v_si, v_pu; atol=1e-4, rtol=1e-6) ||
                @warn "$label per-unit≠SI at $bid.$t: $v_pu vs $v_si"
            @test isapprox(v_si, v_pu; atol=1e-4, rtol=1e-6)
        end
    end
end

@testset "PF comparison — PVSystem IBR, FOUR_LEG (pinned & PF profile)" begin
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
    @test rp["ibr"]["pv"]["1"]["pg"] ≈ P  atol=1.0
    @test rp["ibr"]["pv"]["1"]["qg"] ≈ Q  atol=1.0

    # (b) P-pinned, Q from a power_factor profile. OpenDSS pf=+0.95 injects vars,
    # so the equivalent BMOPF profile is pf = -0.95.
    Vf, rf = _bmopf_volts_opf(_net_pv_4leg(P, nothing, -0.95))
    @test rf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, Vf; label="pv-4leg-pf: ")
    @test rf["ibr"]["pv"]["1"]["qg"] ≈ Q  atol=1.0   # PF path reproduces OpenDSS Q
end

@testset "PF comparison — PVSystem IBR, SINGLE_PHASE (pinned & PF profile)" begin
    path = joinpath(_PF_CMP_DIR, "pf_pv_1ph.dss")
    V_ods, pw = _ods_pv(path)
    P = -real(pw[1]) * 1e3
    Q = -imag(pw[1]) * 1e3
    @test P ≈ 8_000.0 atol=50.0
    @test Q > 0

    Vp, rp = _bmopf_volts_opf(_net_pv_1ph(P, Q, nothing))
    @test rp["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, Vp; label="pv-1ph-pin: ")
    @test rp["ibr"]["pv"]["1"]["pg"] ≈ P  atol=1.0
    @test rp["ibr"]["pv"]["1"]["qg"] ≈ Q  atol=1.0

    Vf, rf = _bmopf_volts_opf(_net_pv_1ph(P, nothing, -0.95))
    @test rf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, Vf; label="pv-1ph-pf: ")
    @test rf["ibr"]["pv"]["1"]["qg"] ≈ Q  atol=1.0
end

# ── Smart-IBR droop: BMOPF smooth-ReLU vs OpenDSS InvControl ───────────────
# For each scenario: OpenDSS solves its InvControl to a fixed point; BMOPF
# solve_opf with the matching droop must reproduce the node voltages and the
# injected P/Q, and the operating point must sit in the intended regime.
# A small smoothing ε keeps the BMOPF kinks close to OpenDSS's exact piecewise
# curve; scenarios target regime interiors so the softplus rounding is negligible.

# Shared assertions: node voltages match, and BMOPF reproduces OpenDSS P/Q.
function _check_pv_droop(params, label; atolV=1.0, atolPQ=60.0)
    V_ods, P, Q = _ods_pv_droop(; params...)
    Vbm, res = _bmopf_volts_opf(_net_pv_1ph_droop(; params...))
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, Vbm; label=label, atol=atolV)
    @test res["ibr"]["pv"]["1"]["pg"] ≈ P   atol=atolPQ
    @test res["ibr"]["pv"]["1"]["qg"] ≈ Q   atol=atolPQ
    return res, P, Q
end

@testset "PV droop vs OpenDSS — Volt-var only" begin
    # Deadband (220–240 V): Q ≈ 0.
    res, _, Q = _check_pv_droop((vsrc=235.0, kVA=20.0, Pmpp=5.0, load_kw=3.0,
                                 load_kvar=1.0, mode=:vv), "vv-deadband: ")
    @test abs(Q) < 50.0
    @test abs(res["ibr"]["pv"]["1"]["qg"]) < 50.0

    # Slope (240–258 V): partial absorption, strictly inside (0, Q_sat).
    res, _, Q = _check_pv_droop((vsrc=252.0, kVA=20.0, Pmpp=5.0, load_kw=3.0,
                                 load_kvar=1.0, mode=:vv), "vv-slope: ")
    @test -12_000.0 < Q < -2_000.0   # on the ramp, not saturated

    # Saturation (> 258 V): Q clamped at -0.60·s_max = -12 kvar.
    res, _, Q = _check_pv_droop((vsrc=275.0, kVA=20.0, Pmpp=5.0, load_kw=3.0,
                                 load_kvar=1.0, mode=:vv), "vv-saturation: ")
    @test Q ≈ -12_000.0   atol=150.0
end

@testset "PV droop vs OpenDSS — Volt-watt only" begin
    # Below threshold (converged V < 253 V): uncurtailed, P ≈ Pmpp.
    res, P, _ = _check_pv_droop((vsrc=242.0, kVA=14.0, Pmpp=10.0, load_kw=3.0,
                                 load_kvar=1.0, mode=:vw), "vw-uncurtailed: ")
    @test P ≈ 10_000.0   atol=100.0

    # Slope (253–260 V): partial curtailment, strictly inside (P_floor, Pmpp).
    res, P, _ = _check_pv_droop((vsrc=258.0, kVA=14.0, Pmpp=10.0, load_kw=3.0,
                                 load_kvar=1.0, mode=:vw), "vw-slope: ")
    @test 2_000.0 < P < 10_000.0

    # Saturation (> 260 V): P clamped at 0.20·Pmpp = 2 kW.
    res, P, _ = _check_pv_droop((vsrc=272.0, kVA=14.0, Pmpp=10.0, load_kw=3.0,
                                 load_kvar=1.0, mode=:vw), "vw-saturation: ")
    @test P ≈ 2_000.0   atol=150.0
end

@testset "PV droop vs OpenDSS — S_MAX volt-watt respects available power" begin
    # Regression for the available-power bug: with volt-watt p_ref=S_MAX the
    # curtailment cap is a fraction of *rated* (kVA), NOT of available solar, so it
    # must NOT be the only P upper bound — the p_max (Pmpp) box has to still bind.
    # Operate BELOW the volt-watt threshold (uncurtailed) with rated ≫ available:
    # a correct model dispatches P ≈ Pmpp; the buggy one ran up to ≈ s_max.
    # OpenDSS PVSystem can never exceed Pmpp·irradiance, so it is the truth source.
    params = (vsrc=242.0, kVA=20.0, Pmpp=5.0, load_kw=3.0, load_kvar=1.0, mode=:vw)
    V_ods, P_ods, _ = _ods_pv_droop(; params...)
    Vbm, res = _bmopf_volts_opf(_net_pv_1ph_droop(; params..., p_ref="S_MAX"))
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")

    P_bm = res["ibr"]["pv"]["1"]["pg"]
    @test P_ods ≈ 5_000.0   atol=100.0            # OpenDSS: available-limited
    @test P_bm  ≈ 5_000.0   atol=100.0            # BMOPF must match (was ≈ s_max)
    @test P_bm  ≤ 5_000.0 * (1 + 1e-3)            # never exceeds available power
    @test P_bm  < 0.9 * 20_000.0                  # and is nowhere near rated kVA
    _cmp_volts(V_ods, Vbm; label="vw-Smax-available: ", atol=1.0)
end

@testset "PV droop vs OpenDSS — combined VV+VW (var priority)" begin
    # Both active, kVA circle slack: VV and VW satisfied independently.
    res, P, Q = _check_pv_droop((vsrc=255.0, kVA=14.0, Pmpp=10.0, load_kw=3.0,
                                 load_kvar=1.0, mode=:vvvw), "vvvw-slack: ")
    @test sqrt(P^2 + Q^2) < 14_000.0 - 100.0   # circle not binding
    @test Q < -2_000.0 && P < 10_000.0          # both curves engaged

    # kVA circle binds: var priority holds Q on the curve and curtails P below
    # the volt-watt cap (P² + Q² = s_max²).
    res, P, Q = _check_pv_droop((vsrc=250.0, kVA=6.0, Pmpp=10.0, load_kw=3.0,
                                 load_kvar=1.0, mode=:vvvw), "vvvw-varpriority: ")
    @test sqrt(P^2 + Q^2) ≈ 6_000.0   atol=80.0   # on the apparent-power circle
    @test Q < -1_000.0                            # vars held (priority)
    @test P < 5_900.0                             # watts curtailed below kVA
end

# Per-phase comparison for the 3φ FOUR_LEG droop: every phase's node voltage and
# injected P/Q must match the corresponding single-phase OpenDSS InvControl.
function _check_pv_3ph_droop(params, label; atolV=1.0, atolPQ=60.0)
    Vods, Pods, Qods = _ods_pv_3ph_droop(; params...)
    res = solve_opf(_net_pv_3ph_droop(; params...))
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test abs(Vods["lb.4"]) < 0.1          # grounded neutral ≈ 0
    b = res["bus"]["lb"]
    @test sqrt(b["n"]["vr"]^2 + b["n"]["vi"]^2) < 1e-6
    Pbm = Float64[]; Qbm = Float64[]
    for k in 1:3
        iv = res["ibr"]["pv"]["$k"]
        push!(Pbm, iv["pg"]); push!(Qbm, iv["qg"])
        # phase-to-neutral node voltage matches OpenDSS phase-to-ground
        Vbm_k = abs((b["$k"]["vr"] - b["n"]["vr"]) + im * (b["$k"]["vi"] - b["n"]["vi"]))
        Vods_k = abs(Vods["lb.$k"] - Vods["lb.4"])
        isapprox(Vbm_k, Vods_k; atol=atolV) ||
            @warn "$(label)phase $k: V BMOPF=$(round(Vbm_k,digits=2)) ODS=$(round(Vods_k,digits=2))"
        @test isapprox(Vbm_k, Vods_k; atol=atolV)
        @test iv["pg"] ≈ Pods[k]   atol=atolPQ
        @test iv["qg"] ≈ Qods[k]   atol=atolPQ
    end
    return Pbm, Qbm
end

@testset "PV 3φ FOUR_LEG droop vs OpenDSS — Volt-var under unbalance" begin
    # Unbalanced loads (0 / 5 / 14 kW) spread the phase voltages so each lands at a
    # different point on the curve: phase 1 saturates, phases 2 and 3 sit on the
    # slope. Matches OpenDSS's three per-phase single-phase InvControls.
    Pbm, Qbm = _check_pv_3ph_droop((vsrc=255.0, kVA=10.0, Pmpp=7.0,
                                    loads=[0.0, 5.0, 14.0], mode=:vv), "3ph-vv: ")
    @test Qbm[1] ≈ -6_000.0   atol=120.0       # phase 1 saturated at -0.6·s_max
    @test Qbm[1] < Qbm[2] < Qbm[3] < 0.0       # monotone: higher V → more absorption
    @test all(p -> p ≈ 7_000.0, Pbm)           # volt-var only → P uncurtailed at Pmpp
end

@testset "PV 3φ FOUR_LEG droop vs OpenDSS — combined VV+VW under unbalance" begin
    # Both laws active per phase: the high-voltage phase curtails P (volt-watt) and
    # absorbs vars (volt-var) simultaneously; the low-voltage phase does neither.
    Pbm, Qbm = _check_pv_3ph_droop((vsrc=255.0, kVA=12.0, Pmpp=9.0,
                                    loads=[0.0, 5.0, 14.0], mode=:vvvw), "3ph-vvvw: ")
    @test Qbm[1] < Qbm[3] < 0.0                # phase 1 absorbs more (higher V)
    @test Pbm[1] < Pbm[3]                       # phase 1 curtailed more than phase 3
end

@testset "PV 3φ FOUR_LEG droop vs OpenDSS — AVERAGE reference (Volt-var)" begin
    # Same unbalanced loads as the per-phase case, but voltage_aggregation=AVERAGE: every
    # phase responds to the mean magnitude, so BMOPF injects balanced vars and
    # matches a single 3φ OpenDSS PVSystem with an averaging InvControl.
    Pbm, Qbm = _check_pv_3ph_avg_droop((vsrc=255.0, kVA=10.0, Pmpp=7.0,
                                        loads=[0.0, 5.0, 14.0], mode=:vv), "3ph-avg-vv: ")
    @test all(p -> p ≈ 7_000.0, Pbm)           # volt-var only → P uncurtailed
    @test all(q -> q < 0.0, Qbm)               # mean voltage is high → all absorb
end

@testset "PV 3φ FOUR_LEG droop vs OpenDSS — AVERAGE reference (combined VV+VW)" begin
    Pbm, Qbm = _check_pv_3ph_avg_droop((vsrc=255.0, kVA=12.0, Pmpp=9.0,
                                        loads=[0.0, 5.0, 14.0], mode=:vvvw), "3ph-avg-vvvw: ")
    @test all(q -> q < 0.0, Qbm)               # absorbing on the mean
    @test all(p -> p < 9_000.0, Pbm)           # curtailed below Pmpp on the mean
end

@testset "feasibility OPF honours IBRs (regression)" begin
    # Before the fix, solve_feasibility_opf never called _add_ibr_constraints!,
    # so the IBR was ignored and its ~30 kW was absorbed by the elastic KCL
    # slack. With the fix the IBR balances KCL and the slack is ~0.
    path = joinpath(_PF_CMP_DIR, "pf_pv_4leg.dss")
    V_ods, pw = _ods_pv(path)
    P = -real(pw[1]) * 1e3
    Q = -imag(pw[1]) * 1e3

    res = solve_feasibility_opf(_net_pv_4leg(P, Q, nothing); optimizer=Ipopt.Optimizer)
    @test res["total_slack_magnitude_A"] < 1e-3       # IBR (not slack) closes KCL
    @test res["ibr"]["pv"]["1"]["pg"] ≈ P  atol=1.0
    @test res["ibr"]["pv"]["1"]["qg"] ≈ Q  atol=1.0

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

@testset "PF (solve_pf) comparison — 3-winding transformer (n_winding, all-wye)" begin
    # General n-winding transformer (HV 115 / MV 24.9 / LV 4.16 kV) validated
    # against OpenDSS's own 3-winding solve. The BMOPF net is hand-authored from
    # the same nameplate (PowerIO cannot yet parse n-winding). Phase terminals
    # a/b/c map to OpenDSS node numbers 1/2/3 for the voltage comparison.
    path  = joinpath(_PF_CMP_DIR, "pf_3wdg_nwinding.dss")
    net   = _net_3wdg_nwinding()
    V_ods = _ods_volts(path)

    res = solve_pf(net; optimizer=Ipopt.Optimizer)
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))

    @test haskey(get(net, "transformer", Dict()), "n_winding")
    _cmp_volts(V_ods, V_bm; label="pf-3wdg-nwinding: ")
end

@testset "n_winding tap fields warn (unsupported, not silently fixed)" begin
    # Tap optimisation is not supported for n_winding. A tap field on a winding
    # must raise a warning at OPF build, rather than silently holding the ratio
    # fixed. Without the field, that warning must not fire.
    warned(net) = any(
        l -> occursin("tap optimisation is not supported", string(l.message)),
        first(Test.collect_test_logs(() -> solve_opf(net; optimizer=Ipopt.Optimizer))))

    @test !warned(_net_3wdg_nwinding())                 # clean net: no such warning

    nettap = _net_3wdg_nwinding()
    w = first(values(nettap["transformer"]["n_winding"]))
    w["tap_min"] = 0.9; w["tap_max"] = 1.1
    @test warned(nettap)                                # tap field ⇒ warning fires
end

@testset "PF (solve_pf) comparison — 3-winding transformer, unbalanced loads" begin
    # Per-phase star independence: single-phase loads on different phases must
    # still match OpenDSS's 3-winding solve (the n≤3 star is exact).
    path  = joinpath(_PF_CMP_DIR, "pf_3wdg_nwinding_unbalanced.dss")
    net   = _net_3wdg_nwinding_unbalanced()
    V_ods = _ods_volts(path)

    res = solve_pf(net; optimizer=Ipopt.Optimizer)
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(V_ods, V_bm; label="pf-3wdg-unbalanced: ")
end

@testset "PF (solve_pf) comparison — 4-winding transformer (n_winding, per-unit)" begin
    # Four galvanically isolated levels (115/24.9/4.16/2.4 kV). Solved in per-unit
    # so the wide voltage spread stays well-conditioned. The OpenDSS-style ZB
    # leakage is EXACT for any n (it reconstructs all six pairwise reactances), so
    # the match is exact even though the Xscarray is not star-consistent.
    path  = joinpath(_PF_CMP_DIR, "pf_4wdg_nwinding.dss")
    net   = _net_4wdg_nwinding()
    V_ods = _ods_volts(path)

    res = solve_pf(net; optimizer=Ipopt.Optimizer, per_unit=true)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(V_ods, V_bm; label="pf-4wdg-nwinding: ")
end

# ── n-winding transformers with DELTA windings (matrix vs OpenDSS) ───────────────
# Validates delta-winding support across the chosen dimensions: winding count
# (3- and 4-winding), neutral grounding (solid / impedance / delta-no-neutral),
# and unbalanced loading. The delta coil is line-to-line (delta_roll = -1 matches
# OpenDSS's standard 30° rotation; r_winding/x_sc on the delta coil base).

@testset "PF (solve_pf) comparison — 3-winding Dyn (delta primary)" begin
    path  = joinpath(_PF_CMP_DIR, "pf_3wdg_dyn.dss")
    net   = _net_3wdg_dyn()
    V_ods = _ods_volts(path)
    res   = solve_pf(net; optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test net["transformer"]["n_winding"]["t1"]["windings"][1]["configuration"] == "DELTA"
    _cmp_volts(V_ods, _nwd_bm_volts(res); label="pf-3wdg-dyn: ")
end

@testset "PF (solve_pf) comparison — 3-winding Dyn, unbalanced loads" begin
    # Delta primary blocks zero-sequence; single-phase MV/LV loads still match.
    path  = joinpath(_PF_CMP_DIR, "pf_3wdg_dyn_unbalanced.dss")
    V_ods = _ods_volts(path)
    res   = solve_pf(_net_3wdg_dyn_unbalanced(); optimizer=Ipopt.Optimizer)
    _cmp_volts(V_ods, _nwd_bm_volts(res); label="pf-3wdg-dyn-unb: ")
end

@testset "PF (solve_pf) comparison — 4-winding Dyyn (delta primary)" begin
    # Winding-count dimension: n=4 with a delta winding 1; the ZB leakage still
    # reproduces all six pairwise reactances exactly on the delta coil base.
    path  = joinpath(_PF_CMP_DIR, "pf_4wdg_dyyn.dss")
    V_ods = _ods_volts(path)
    res   = solve_pf(_net_4wdg_dyyn(); optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    _cmp_volts(V_ods, _nwd_bm_volts(res); label="pf-4wdg-dyyn: ")
end

@testset "feasibility OPF comparison — 3-winding Dyn (delta primary)" begin
    # Exercises the OTHER solver path for a delta n-winding: the feasibility OPF
    # (elastic KCL slack) must drive the slack to ≈0 and reproduce the same delta
    # voltages as OpenDSS — mirroring the Yd/Dy 2-winding feasibility tests.
    path  = joinpath(_PF_CMP_DIR, "pf_3wdg_dyn.dss")
    net   = _net_3wdg_dyn()
    V_ods = _ods_volts(path)
    res   = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    @test res["total_slack_magnitude_A"] < 1e-3
    _cmp_volts(V_ods, _nwd_bm_volts(res); label="feas-3wdg-dyn: ")
end

@testset "PF (solve_pf) comparison — 3-winding Dyn, impedance-grounded MV neutral" begin
    # Neutral-grounding dimension: the MV neutral is grounded through a 0.5 Ω shunt
    # (not solidly) under unbalanced load. The bus-neutral shunt and the per-winding
    # neutral KCL must agree with OpenDSS's grounding reactor on every node.
    path  = joinpath(_PF_CMP_DIR, "pf_3wdg_dyn_zgnd.dss")
    net   = _net_3wdg_dyn_zgnd()
    V_ods = _ods_volts(path)
    res   = solve_pf(net; optimizer=Ipopt.Optimizer)
    @test haskey(net, "shunt")             # MV neutral grounded via shunt, not solid
    _cmp_volts(V_ods, _nwd_bm_volts(res); label="pf-3wdg-dyn-zgnd: ")
end

@testset "PF (solve_pf) comparison — 3-winding Dyn in per-unit (√3 cancellation)" begin
    # Same Dyn net solved in per-unit. The delta v_nom is line-to-line while the bus
    # base is line-to-neutral, so the √3 cancels and the per-unit solve must agree
    # with both OpenDSS and the SI solve.
    path  = joinpath(_PF_CMP_DIR, "pf_3wdg_dyn.dss")
    V_ods = _ods_volts(path)
    res_pu = solve_pf(_net_3wdg_dyn(); optimizer=Ipopt.Optimizer, per_unit=true)
    @test res_pu["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    V_pu = _nwd_bm_volts(res_pu)
    _cmp_volts(V_ods, V_pu; label="pf-3wdg-dyn-pu: ")
    # Per-unit ≡ SI (same delta net): voltages agree to solver precision.
    V_si = _nwd_bm_volts(solve_pf(_net_3wdg_dyn(); optimizer=Ipopt.Optimizer))
    for (k, v) in V_pu
        @test isapprox(v, V_si[k]; atol=1e-4, rtol=1e-7)
    end
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

# ── Ideal (zero-impedance) transformers ─────────────────────────────────────
# Because the transformer constraints are IVR voltage/current EQUALITIES (not a
# nodal admittance Y = Z⁻¹), they degrade gracefully to the ideal-transformer
# relation when all winding resistance and leakage reactance are zero — no
# inversion, no singularity. (The `transformer_yprim`/`nwinding_yprim` admittance
# export is the one place that IS singular at Z=0, by construction.)

# Zero every series-impedance field on every transformer in `net` (two-bus
# subtypes and n_winding), leaving the ideal ratio behaviour only.
function _zero_all_xfmr_impedance!(net)
    for (_, sub) in get(net, "transformer", Dict())
        sub isa Dict || continue
        for (_, xf) in sub
            xf isa Dict || continue
            for k in ("r_series_from","x_series_from","r_series_to","x_series_to",
                      "r_series","x_series","g_no_load","b_no_load")
                haskey(xf, k) && (xf[k] = 0.0)
            end
            if haskey(xf, "windings")                 # n_winding
                for w in xf["windings"]; w["r_winding"] = 0.0; end
                if haskey(xf, "x_sc")
                    for kk in keys(xf["x_sc"]); xf["x_sc"][kk] = 0.0; end
                end
                delete!(xf, "_zb_re"); delete!(xf, "_zb_im")
            end
        end
    end
    net
end

_net_center_tap_ideal() = parse_bmopf("""
{"bus":{"mv":{"terminal_names":["1","n"],"perfectly_grounded_terminals":["n"]},
        "lv":{"terminal_names":["1","2","n"],"perfectly_grounded_terminals":["n"]}},
 "voltage_source":{"src":{"bus":"mv","terminal_map":["1"],"v_magnitude":[2400.0],"v_angle":[0.0]}},
 "transformer":{"center_tap":{"ct":{"bus_from":"mv","bus_to":"lv",
     "terminal_map_from":["1","n"],"terminal_map_to":["1","n","2"],
     "v_nom_from":2400.0,"v_nom_to":120.0,"s_rating":25000.0,
     "r_series_from":0.1,"x_series_from":0.4,"r_series_to":0.001,"x_series_to":0.004}}},
 "load":{"l1":{"bus":"lv","terminal_map":["1","n"],"configuration":"SINGLE_PHASE","p_nom":[2000.0],"q_nom":[0.0]},
         "l2":{"bus":"lv","terminal_map":["2","n"],"configuration":"SINGLE_PHASE","p_nom":[2000.0],"q_nom":[0.0]}}}
"""; from_string=true)

@testset "Ideal (zero-impedance) transformers solve — every subtype" begin
    cases = [
        ("single_phase",                 _net_1ph_xfmr()),
        ("center_tap",                   _net_center_tap_ideal()),
        ("wye_delta",                    _net_yd_xfmr()),
        ("delta_wye",                    _net_dy_xfmr()),
        ("single_phase_autotransformer", _net_autotransformer()),
        ("open_delta_regulator",         _net_open_delta_reg()),
        ("n_winding (3-winding)",        _net_3wdg_nwinding()),
        ("n_winding (4-winding)",        _net_4wdg_nwinding()),
        ("n_winding Dyn (delta)",        _net_3wdg_dyn()),
        ("n_winding Dyyn (4w, delta)",   _net_4wdg_dyyn()),
    ]
    for (lbl, net) in cases
        _zero_all_xfmr_impedance!(net)
        res = solve_pf(net; optimizer=Ipopt.Optimizer)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    end

    # Ideal voltage ratios are exact where the ratio is a clean scalar.
    vmag(r, b, t) = sqrt(r["bus"][b][t]["vr"]^2 + r["bus"][b][t]["vi"]^2)

    yy = _zero_all_xfmr_impedance!(_net_1ph_xfmr())
    ryy = solve_pf(yy; optimizer=Ipopt.Optimizer)
    N_yy = yy["transformer"]["single_phase"]["t1"]["v_nom_from"] /
           yy["transformer"]["single_phase"]["t1"]["v_nom_to"]
    @test isapprox(vmag(ryy, "hv", "1") / vmag(ryy, "lv", "1"), N_yy; rtol=1e-6)

    nw = _zero_all_xfmr_impedance!(_net_3wdg_nwinding())
    rnw = solve_pf(nw; optimizer=Ipopt.Optimizer)
    ws  = nw["transformer"]["n_winding"]["t1"]["windings"]
    @test isapprox(vmag(rnw, "hv", "a") / vmag(rnw, "mv", "a"),
                   ws[1]["v_nom"] / ws[2]["v_nom"]; rtol=1e-6)
    @test isapprox(vmag(rnw, "hv", "a") / vmag(rnw, "lv", "a"),
                   ws[1]["v_nom"] / ws[3]["v_nom"]; rtol=1e-6)

    # Lossless DELTA: the delta winding-1 coil voltage is line-to-line, so the
    # ideal ratio is V_hv(L-L) / V_mv(L-N) = v_nom_delta / v_nom_wye (the √3 is in
    # v_nom). A wrong coil-base / v_nom convention would break this exact ratio.
    vll(r, b, p, q) = sqrt((r["bus"][b][p]["vr"] - r["bus"][b][q]["vr"])^2 +
                           (r["bus"][b][p]["vi"] - r["bus"][b][q]["vi"])^2)
    dyn  = _zero_all_xfmr_impedance!(_net_3wdg_dyn())
    rdyn = solve_pf(dyn; optimizer=Ipopt.Optimizer)
    wsd  = dyn["transformer"]["n_winding"]["t1"]["windings"]
    @test isapprox(vll(rdyn, "hv", "a", "b") / vmag(rdyn, "mv", "a"),
                   wsd[1]["v_nom"] / wsd[2]["v_nom"]; rtol=1e-6)
end

# ── Fixed capacitor banks ───────────────────────────────────────────────────
# A capacitor is a constant susceptance B = q_rated/v_nom² delivering Q = B·V².
# Validate (1) it compiles to the same physics as an equivalent shunt and
# (2) WYE and DELTA banks match OpenDSS's own Capacitor solve. Nameplate
# convention: q_rated per phase (WYE) / per pair (DELTA) = kvar_3ph/3;
# v_nom = line-to-neutral (WYE) / line-to-line (DELTA).

function _net_cap_base()
    vpn(kv) = kv * 1e3 / sqrt(3)
    g() = Dict{String,Any}("terminal_names"=>["a","b","c","n"],
        "neutral_terminal"=>"n", "perfectly_grounded_terminals"=>["n"])
    Dict{String,Any}(
        "name" => "pf_cap",
        "bus"  => Dict{String,Any}("src"=>g(), "b1"=>g()),
        "voltage_source" => Dict{String,Any}("s"=>Dict{String,Any}(
            "bus"=>"src", "terminal_map"=>["a","b","c","n"],
            "v_magnitude"=>[vpn(12.47),vpn(12.47),vpn(12.47),0.0],
            "v_angle"=>[0.0,-2.0943951023931953,2.0943951023931953,0.0])),
        "line" => Dict{String,Any}("l"=>Dict{String,Any}(
            "bus_from"=>"src","bus_to"=>"b1","linecode"=>"lc","length"=>1.0,
            "terminal_map_from"=>["a","b","c","n"],"terminal_map_to"=>["a","b","c","n"])),
        "linecode" => Dict{String,Any}("lc"=>Dict{String,Any}(
            "R_series_1_1"=>0.5,"X_series_1_1"=>1.0,"R_series_2_2"=>0.5,"X_series_2_2"=>1.0,
            "R_series_3_3"=>0.5,"X_series_3_3"=>1.0,"R_series_4_4"=>0.5,"X_series_4_4"=>1.0)),
        "load" => Dict{String,Any}("ld"=>Dict{String,Any}(
            "bus"=>"b1","terminal_map"=>["a","b","c","n"],"configuration"=>"WYE",
            "model"=>"constant_power","p_nom"=>[3e5,3e5,3e5],"q_nom"=>[1.5e5,1.5e5,1.5e5])))
end

function _net_cap_wye()
    net = _net_cap_base(); vpn = 12.47e3/sqrt(3)
    net["capacitor"] = Dict{String,Any}("c1"=>Dict{String,Any}(
        "bus"=>"b1","terminal_map"=>["a","b","c","n"],"configuration"=>"WYE",
        "q_rated"=>[3e5,3e5,3e5],"v_nom"=>vpn))
    net
end

function _net_cap_delta()
    net = _net_cap_base()
    net["capacitor"] = Dict{String,Any}("c1"=>Dict{String,Any}(
        "bus"=>"b1","terminal_map"=>["a","b","c"],"configuration"=>"DELTA",
        "q_rated"=>[3e5,3e5,3e5],"v_nom"=>12.47e3))
    net
end

@testset "capacitor ≡ equivalent shunt (identical voltages)" begin
    capnet = _net_cap_wye()
    vpn = 12.47e3/sqrt(3); b = 3e5 / vpn^2
    shnet = _net_cap_base()
    shnet["shunt"] = Dict{String,Any}("s1"=>Dict{String,Any}(
        "bus"=>"b1","terminal_map"=>["a","b","c","n"],
        "G_1_1"=>0.0,"B_1_1"=>b,"G_2_2"=>0.0,"B_2_2"=>b,"G_3_3"=>0.0,"B_3_3"=>b))
    Vc = _bmopf_volts_pf(capnet)
    Vs = _bmopf_volts_pf(shnet)
    _cmp_volts(Vs, Vc; label="cap≡shunt: ", atol=1e-4)
end

# Validate against OpenDSS's own `Capacitor` solve in BOTH solver modes (SI and
# per-unit); the result must match OpenDSS either way.
@testset "PF (solve_pf) comparison — fixed WYE capacitor (SI & p.u.)" begin
    path  = joinpath(_PF_CMP_DIR, "pf_cap_wye.dss")
    V_ods = _ods_volts(path)
    phmap = Dict("a"=>"1","b"=>"2","c"=>"3","n"=>"4")
    for pu in (false, true)
        res  = solve_pf(_net_cap_wye(); optimizer=Ipopt.Optimizer, per_unit=pu)
        V_bm = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                    for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
        _cmp_volts(V_ods, V_bm; label="cap-wye (pu=$pu): ")
    end
end

@testset "PF (solve_pf) comparison — fixed DELTA capacitor (SI & p.u.)" begin
    path  = joinpath(_PF_CMP_DIR, "pf_cap_delta.dss")
    V_ods = _ods_volts(path)
    phmap = Dict("a"=>"1","b"=>"2","c"=>"3","n"=>"4")
    for pu in (false, true)
        res  = solve_pf(_net_cap_delta(); optimizer=Ipopt.Optimizer, per_unit=pu)
        V_bm = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                    for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
        _cmp_volts(V_ods, V_bm; label="cap-delta (pu=$pu): ")
    end
end

@testset "PF comparison — Queensland isolated SWER feeder (from_dss)" begin
    # End-to-end isolated-SWER feeder loaded through PowerIO (from_dss): a 22 kV
    # three-phase source, a phase-to-phase isolating transformer to a 12.7 kV
    # single-wire earth-return backbone, a single-ended N-0 distribution
    # transformer (dx1) and a split-phase centre-tapped N-0-N transformer (dx2).
    # Exercises the full parse→power-flow path and validates the center_tap
    # normalisation in from_dss against OpenDSS's own solve.
    path = joinpath(@__DIR__, "data", "SWER", "Master.dss")
    net  = from_dss(path)

    # Structure: one isolating + one single-ended dist xfmr (single_phase), one
    # split-phase (center_tap); the SWER backbone parsed as single-wire.
    @test Set(keys(net["transformer"]["single_phase"])) == Set(["iso", "dx1"])
    @test haskey(net["transformer"]["center_tap"], "dx2")

    # from_dss center_tap normalisation: centre tap "n" sits in the MIDDLE of
    # terminal_map_to and v_nom_to is the per-leg (half-winding) voltage. Without
    # this the OPF connection matrix wires the wrong nodes and the turns ratio is
    # 2× off (leg voltages 2–4× too high).
    dx2 = net["transformer"]["center_tap"]["dx2"]
    @test dx2["terminal_map_to"][2] == "n"
    @test isapprox(dx2["v_nom_to"], 240.0; rtol=1e-6)   # 0.48 kV split → 240 V/leg

    V_ods = _ods_volts(path)
    res   = solve_pf(net; optimizer=Ipopt.Optimizer)
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))

    # The coupled-coil centre-tap model (primitive admittance reconstructed from
    # the full XHL/XLT/XHT short-circuit set, recovered via from_dss's pmd path)
    # matches OpenDSS across the whole feeder, including the split-phase legs.
    _cmp_volts(V_ods, V_bm; label="swer: ", atol=0.3, rtol=3e-3)
end

@testset "PF comparison — loaded center_tap (power-conservation regression)" begin
    # Regression guard for the center_tap ideal-core current-coupling sign. With the
    # wrong sign (N·Is + Il1 + Il2 = 0) the transformer SOURCES spurious active power
    # ∝ load, inflating the load-sensitive HV-side voltage and driving total losses
    # negative. The correct coupling (N·Is + Il1 − Il2 = 0, reversed winding-3)
    # conserves power and matches OpenDSS. The 5 km line makes the bug observable —
    # on a stiff bus the source pins the voltages and hides it (which is why the
    # other center_tap tests, all on stiff/short networks, missed it).
    path = joinpath(_PF_CMP_DIR, "pf_center_tap_loaded.dss")
    net  = from_dss(path)
    V_ods = _ods_volts(path)
    res   = solve_pf(net; optimizer=Ipopt.Optimizer, per_unit=true)
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))

    # Load-sensitive HV bus must match OpenDSS (spurious power would inflate it; the
    # pre-fix model put it hundreds of volts high on a long feeder).
    @test isapprox(abs(V_bm["hv.1"]), abs(V_ods["hv.1"]); atol=0.5)
    # Power must be conserved: a passive transformer cannot generate active power.
    @test res["losses"]["p_loss"] > 0
    # Coupled-coil model: legs now match OpenDSS at the default tight band.
    _cmp_volts(V_ods, V_bm; label="ct-loaded: ", atol=0.5, rtol=2e-3)
end

# Shared driver for the split-phase center_tap cases below: solve via from_dss +
# OpenDSS, compare all node voltages and the network loss, and return the BMOPF
# leg/centre voltages for case-specific symmetry assertions.
function _run_center_tap_case(fname; atol=0.3, rtol=3e-3, ploss_rtol=0.03, label="")
    path  = joinpath(_PF_CMP_DIR, fname)
    net   = from_dss(path)
    V_ods = _ods_volts(path)
    P_ods = _ods_losses_W(path)
    res   = solve_pf(net; optimizer=Ipopt.Optimizer, per_unit=true)
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(V_ods, V_bm; label=label, atol=atol, rtol=rtol)
    # Losses: passive (positive) and matching OpenDSS.
    @test res["losses"]["p_loss"] > 0
    @test isapprox(res["losses"]["p_loss"], P_ods; rtol=ploss_rtol)
    bt = res["bus"]["lv"]
    leg(t) = (v = bt[t]; v["vr"] + im*v["vi"])
    (leg1 = leg("a"), ctr = leg("n"), leg2 = leg("b"))
end

@testset "PF comparison — center_tap balanced heavy load (leg symmetry)" begin
    # Perfectly balanced heavy 120 V leg loads through a long line. The two
    # half-windings are tightly coupled; the old per-leg decoupled model spread
    # the legs apart under load even for balanced loads. The coupled-coil model
    # keeps them symmetric, matching OpenDSS.
    L = _run_center_tap_case("pf_center_tap_balanced_heavy.dss"; label="ct-bal: ")
    # Leg-symmetry regression guard: |V_leg1 − V_ctr| ≈ |V_ctr − V_leg2|.
    @test isapprox(abs(L.leg1 - L.ctr), abs(L.ctr - L.leg2); rtol=1e-3)
end

@testset "PF comparison — center_tap 240 V phase-to-phase load" begin
    # Pure 240 V load across both legs (no leg-to-neutral load): equal through
    # current in both half-windings, zero centre-tap current → symmetric legs.
    # Exercises the series-aiding winding polarity and the L-L load path.
    L = _run_center_tap_case("pf_center_tap_240.dss"; label="ct-240: ")
    @test isapprox(abs(L.leg1 - L.ctr), abs(L.ctr - L.leg2); rtol=1e-3)
end

@testset "PF comparison — center_tap single-leg phase-to-neutral load" begin
    # One 120 V leg-to-neutral load only → heavy centre-tap (unbalance) current
    # and asymmetric legs. Cross-checks the unbalanced split against OpenDSS.
    _run_center_tap_case("pf_center_tap_singleleg_pn.dss"; label="ct-pn: ")
end

@testset "PF comparison — center_tap extreme single-leg load" begin
    # Large load on one leg with the other open, through a long line → strongly
    # unequal leg voltages (the case the old decoupled model got most wrong).
    _run_center_tap_case("pf_center_tap_oneleg_extreme.dss"; label="ct-ext: ")
end

@testset "center_tap OPF and Ybus models agree (guards against drift)" begin
    # The OPF builder and the Ybus exporter implement the split-phase transformer
    # independently; both must reproduce the same OpenDSS-consistent primitive
    # admittance. Solve a small loaded case via solve_pf, then confirm the
    # node currents implied by `_yprim_center_tap` satisfy the same solution.
    path = joinpath(_PF_CMP_DIR, "pf_center_tap_loaded.dss")
    net  = from_dss(path)
    res  = solve_pf(net; optimizer=Ipopt.Optimizer)
    ct   = first(values(net["transformer"]["center_tap"]))
    nodes, Yp = BMOPFTools._yprim_center_tap(ct)
    V = ComplexF64[(d = res["bus"][b]; tv = d[t]; tv["vr"] + im*tv["vi"])
                   for (b, t) in nodes]
    I = Yp * V                         # element currents into each of the 5 nodes
    # LV side carries no shunt, so its three winding currents close exactly:
    # I_leg1 + I_ctr + I_leg2 ≈ 0 (centre-tap KCL).
    @test isapprox(I[3] + I[4] + I[5], 0.0 + 0.0im; atol=1e-3)
    # HV phase + neutral leave only the no-load shunt current (≈ 0 here).
    @test abs(I[1] + I[2]) < 1e-2
end

# ── Generic OPF ↔ Yprim-export drift gate ────────────────────────────────────
# The OPF builders (ext/BMOPFOpfExt/transformer.jl) and the Yprim export
# (src/io/to_ybus.jl) implement each subtype independently. At a solved PF
# setpoint the element current implied by the exported Yprim (I = Yp·V) must
# equal, node by node, the injection reconstructed from the solved OPF
# winding-current variables (series/winding current + the magnetising-shunt
# share the OPF folds into the from-side terminal current). The center_tap
# variant of this gate is above; these helpers cover the other two-bus
# subtypes, including off-nominal fixed taps (which is where the export
# historically diverged: un-tap-scaled single_phase leakage, inverted Yd/Dy
# primitive).

# single_phase: per winding pair k, terminal current = series + Y0/n_c·(V_p−V_q),
# injected +I at p and −I at q on each side.
function _sp_node_injections(xf, nodes, V, res_t)
    b_fr = xf["bus_from"]; b_to = xf["bus_to"]
    tm_fr = Vector{String}(xf["terminal_map_from"])
    tm_to = Vector{String}(xf["terminal_map_to"])
    pairs_fr = BMOPFTools._xfmr_winding_pairs(tm_fr)
    pairs_to = BMOPFTools._xfmr_winding_pairs(tm_to)
    n_c = min(length(pairs_fr), length(pairs_to))
    Y0per = n_c > 0 ?
        (Float64(get(xf, "g_no_load", 0.0)) + im*Float64(get(xf, "b_no_load", 0.0))) / n_c :
        0.0 + 0.0im
    idx = Dict(n => i for (i, n) in enumerate(nodes))
    inj = zeros(ComplexF64, length(nodes))
    for k in 1:n_c
        (p_fr, q_fr) = pairs_fr[k]; (p_to, q_to) = pairs_to[k]
        Is  = res_t["fr"][string(k)]["cr"] + im*res_t["fr"][string(k)]["ci"]
        Ito = res_t["to"][string(k)]["cr"] + im*res_t["to"][string(k)]["ci"]
        v_fr = V[idx[(b_fr, tm_fr[p_fr])]] -
               (q_fr === nothing ? 0.0im : V[idx[(b_fr, tm_fr[q_fr])]])
        Ifr = Is + Y0per * v_fr
        inj[idx[(b_fr, tm_fr[p_fr])]] += Ifr
        q_fr === nothing || (inj[idx[(b_fr, tm_fr[q_fr])]] -= Ifr)
        inj[idx[(b_to, tm_to[p_to])]] += Ito
        q_to === nothing || (inj[idx[(b_to, tm_to[q_to])]] -= Ito)
    end
    inj
end

# wye_delta / delta_wye: wye node k carries the wye winding current, the delta
# node k the delta LINE current; the from-side phase nodes add the
# phase-to-ground magnetising share Gph·V.
function _yd_node_injections(xf, sub, nodes, V, res_t)
    wye_is_from = sub == "wye_delta"
    b_wye = wye_is_from ? xf["bus_from"] : xf["bus_to"]
    b_del = wye_is_from ? xf["bus_to"]   : xf["bus_from"]
    tm_wye = Vector{String}(wye_is_from ? xf["terminal_map_from"] : xf["terminal_map_to"])
    tm_del = Vector{String}(wye_is_from ? xf["terminal_map_to"]   : xf["terminal_map_from"])
    side_wye = wye_is_from ? "fr" : "to"
    side_del = wye_is_from ? "to" : "fr"
    ph_idx = BMOPFTools._phase_positions(tm_wye)
    n_from_ph = wye_is_from ? length(ph_idx) : length(tm_del)
    Gph = n_from_ph > 0 ?
        (Float64(get(xf, "g_no_load", 0.0)) + im*Float64(get(xf, "b_no_load", 0.0))) / n_from_ph :
        0.0 + 0.0im
    # Internal neutral-grounding branch (rneut/xneut) at the wye neutral node.
    rn = Float64(get(xf, wye_is_from ? "r_neutral_from" : "r_neutral_to", 0.0))
    xn = Float64(get(xf, wye_is_from ? "x_neutral_from" : "x_neutral_to", 0.0))
    yn = (rn == 0.0 && xn == 0.0) ? 0.0im : 1.0 / (rn + im*xn)
    n_pos = BMOPFTools._neutral_pos(tm_wye)
    idx = Dict(n => i for (i, n) in enumerate(nodes))
    inj = zeros(ComplexF64, length(nodes))
    for k in eachindex(tm_wye)
        Iw = res_t[side_wye][string(k)]["cr"] + im*res_t[side_wye][string(k)]["ci"]
        i = idx[(b_wye, tm_wye[k])]
        inj[i] += Iw + (wye_is_from && k in ph_idx ? Gph * V[i] : 0.0im) +
                  (k == n_pos ? yn * V[i] : 0.0im)
    end
    for k in eachindex(tm_del)
        Id = res_t[side_del][string(k)]["cr"] + im*res_t[side_del][string(k)]["ci"]
        i = idx[(b_del, tm_del[k])]
        inj[i] += Id + (wye_is_from ? 0.0im : Gph * V[i])
    end
    inj
end

@testset "OPF and Yprim export agree at a solved setpoint (single_phase/Yd/Dy)" begin
    cases = (
        ("pf_1ph_xfmr.dss", "single_phase", 1.0),
        ("pf_1ph_xfmr.dss", "single_phase", 0.96),   # off-nominal fixed tap
        ("pf_yd_xfmr.dss",  "wye_delta",    1.0),
        ("pf_yd_xfmr.dss",  "wye_delta",    1.04),
        ("pf_dy_xfmr.dss",  "delta_wye",    1.0),
        ("pf_dy_xfmr.dss",  "delta_wye",    0.97),
        # rneut/xneut fixture: unbalanced load + internal neutral grounding
        # (fields set below — PowerIO drops them on parse).
        ("pf_dy_xfmr_rneut.dss", "delta_wye", 1.0),
    )
    for (fname, sub, tapm) in cases
        net = from_dss(joinpath(_PF_CMP_DIR, fname))
        tid, xf = first(net["transformer"][sub])
        tapm != 1.0 && (xf["tap"] = tapm)
        if fname == "pf_dy_xfmr_rneut.dss"
            xf["r_neutral_to"] = 2.0; xf["x_neutral_to"] = 1.0
        end
        res = solve_pf(net; optimizer=Ipopt.Optimizer)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        nodes, Yp = BMOPFTools.transformer_yprim(xf, sub)
        V = ComplexF64[(tv = res["bus"][b][t]; tv["vr"] + im*tv["vi"]) for (b, t) in nodes]
        I = Yp * V
        inj = sub == "single_phase" ?
            _sp_node_injections(xf, nodes, V, res["transformer"][tid]) :
            _yd_node_injections(xf, sub, nodes, V, res["transformer"][tid])
        rel = maximum(abs.(I .- inj)) / max(1.0, maximum(abs.(I)))
        @test rel < 1e-5
    end
end

@testset "center_tap OPF solve with one zero star arm (NaN regression)" begin
    # XHT = XHL + XLT gives an exactly-zero LV star arm — legitimate data. The
    # fixed-Yprim OPF path previously computed y2 = 1/0 = Inf and NaN-poisoned
    # the stamp; any zero arm must route to the (exact) T-model branch.
    net = from_dss(joinpath(_PF_CMP_DIR, "pf_center_tap_loaded.dss"))
    _, ct = first(net["transformer"]["center_tap"])
    ct["r_series_to"] = 0.0
    ct["x_series_to"] = 0.0
    res = solve_pf(net; optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    hv = res["transformer"][first(keys(net["transformer"]["center_tap"]))]["fr"]["1"]
    @test isfinite(hv["cr"]) && isfinite(hv["ci"]) && hv["cm"] > 0
end

@testset "PF comparison — from_dss transformer fidelity (single_phase/Yd/Dy)" begin
    # The single_phase/Yd/Dy models are validated above with hand-built nets;
    # this guards the from_dss PARSE path. PowerIO's `bmopf` export drops the
    # no-load shunt for every transformer and mis-refers the delta_wye leakage;
    # `from_dss` recovers both from the `pmd` export
    # (`_recover_transformer_params_from_pmd!`). The grounding reactors also need
    # an explicit `phases=1` in the .dss to survive PowerIO's parser (without it
    # the LV neutral floats and the delta_wye solve diverges).
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    for (fname, sub) in (("pf_1ph_xfmr.dss", "single_phase"),
                         ("pf_yd_xfmr.dss",  "wye_delta"),
                         ("pf_dy_xfmr.dss",  "delta_wye"))
        path  = joinpath(_PF_CMP_DIR, fname)
        net   = from_dss(path)
        @test haskey(get(net, "transformer", Dict()), sub)
        V_ods = _ods_volts(path)
        P_ods = _ods_losses_W(path)
        res   = solve_pf(net; optimizer=Ipopt.Optimizer)
        V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                     for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
        _cmp_volts(V_ods, V_bm; label="$sub from_dss: ", atol=0.5, rtol=3e-3)
        @test res["losses"]["p_loss"] > 0                       # passive
        @test isapprox(res["losses"]["p_loss"], P_ods; rtol=0.03)
    end
end

@testset "PF comparison — from_dss fixed off-nominal tap recovery (Dy)" begin
    # PowerIO's bmopf export drops OpenDSS `taps=` entirely with only a warning
    # — the network silently solved at the NOMINAL ratio (≈2% voltage error per
    # 2% tap). `from_dss` now recovers the multiplier from the pmd `tm_set`.
    # End-to-end: parse → `tap` present → solve_pf matches the OpenDSS solve of
    # the same tapped unit (which also validates the OPF's fixed off-nominal
    # Dy tap referral against OpenDSS — previously only exercised at nominal).
    path = joinpath(_PF_CMP_DIR, "pf_dy_xfmr_tap.dss")
    net  = from_dss(path)
    xf   = first(values(net["transformer"]["delta_wye"]))
    @test isapprox(Float64(get(xf, "tap", 1.0)), 1.02; atol=1e-9)
    V_ods = _ods_volts(path)
    res   = solve_pf(net; optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(V_ods, V_bm; label="dy-tap from_dss: ", atol=0.5, rtol=3e-3)
    @test isapprox(res["losses"]["p_loss"], _ods_losses_W(path); rtol=0.03)
end

@testset "PF comparison — internal winding neutral grounding (rneut/xneut, Dy)" begin
    # OpenDSS rneut/xneut is a transformer-INTERNAL grounding branch from the
    # wye winding's neutral terminal to earth (verified: the OpenDSS Yprim's
    # neutral-node diagonal gains exactly 1/(rneut+jxneut); the star point
    # stays solid on the neutral node). The fixture has NO external LV
    # grounding — the internal branch is the ONLY absolute reference of the
    # galvanically isolated LV island. In healthy power flow the grounded-wye
    # star absorbs the (unbalanced) neutral current metallically, so both
    # engines put lv.4 at ≈0 V — the PF-level assertions are convergence of
    # the otherwise-floating island and node-for-node agreement with OpenDSS;
    # the branch's numerical sensitivity is carried by the entry-wise Yprim
    # gate below. PowerIO drops rneut/xneut (from_dss emits a targeted
    # warning); the BMOPF fields are set by hand.
    path = joinpath(_PF_CMP_DIR, "pf_dy_xfmr_rneut.dss")
    net  = from_dss(path)
    xf   = first(values(net["transformer"]["delta_wye"]))
    xf["r_neutral_to"] = 2.0
    xf["x_neutral_to"] = 1.0
    V_ods = _ods_volts(path)
    res   = solve_pf(net; optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(V_ods, V_bm; label="dy-rneut: ", atol=0.5, rtol=3e-3)
    # The island reference is anchored by the internal branch: lv.4 agrees with
    # OpenDSS at ≈0 V (the star absorbs the zero-sequence load current
    # metallically, so the grounding branch carries only the residual).
    @test abs(V_bm["lv.4"] - V_ods["lv.4"]) < 0.5
    @test isapprox(res["losses"]["p_loss"], _ods_losses_W(path); rtol=0.03)
end

@testset "PF comparison — from_dss 3-winding recovery (n_winding)" begin
    # PowerIO's bmopf export drops every 3-phase 3+-winding transformer
    # entirely; `from_dss` reconstructs them as `n_winding` from the pmd
    # record. End-to-end against OpenDSS on the same fixtures the hand-built
    # n_winding nets above validate (YYY, Dyn, Dyn-unbalanced), so agreement at
    # the default tolerance means the reconstruction is byte-equivalent in
    # effect to the validated hand mapping.
    for f in ("pf_3wdg_nwinding.dss", "pf_3wdg_dyn.dss", "pf_3wdg_dyn_unbalanced.dss")
        path = joinpath(_PF_CMP_DIR, f)
        net  = from_dss(path)
        @test haskey(get(net, "transformer", Dict()), "n_winding")
        @test get(get(net, "_meta", Dict()), "recovered_n_winding", nothing) == ["t1"]
        V_ods = _ods_volts(path)
        res   = solve_pf(net; optimizer=Ipopt.Optimizer)
        @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
        _cmp_volts(V_ods, _nwd_bm_volts(res); label="recov-$(f): ")
    end
    # 4+ windings: PowerIO's pmd export currently mangles `Xscarray` (it emits
    # the three XHL/XHT/XLT class DEFAULTS, 7/35/30%, instead of the six pairs),
    # so the reconstruction refuses loudly rather than building a wrong unit.
    # Upstream PowerIO gap — when fixed, drop this block and extend the loop.
    net4 = @test_logs (:warn, r"pmd record is incomplete") match_mode=:any from_dss(
        joinpath(_PF_CMP_DIR, "pf_4wdg_dyyn.dss"))
    @test !haskey(get(net4, "transformer", Dict()), "n_winding")
end

@testset "Transformer Yprim matches OpenDSS (single_phase, center_tap, Yd, Dy)" begin
    # Correctness gate from docs/transformer_admittance_derivation.md §7: the
    # per-element primitive admittance must equal OpenDSS's own Transformer
    # `Yprim`. This is the check that directly catches turns-ratio direction,
    # √3 scaling, shunt placement, and winding-polarity sign errors (the
    # original center_tap leg-split bug, and the inverted Yd/Dy primitive that
    # survived while the delta subtypes were excluded from this gate). The
    # Yd/Dy fixtures declare the wye neutral as an explicit bus terminal with
    # EXTERNAL grounding reactors, so the OpenDSS element node set matches the
    # BMOPF one directly; the padded delta ground conductor (node 0) is dropped
    # by the merge below. Residual differences (the dropped %imag magnetising
    # susceptance and the phase-to-ground vs across-coil core-loss stamp) are
    # ≲1e-4 relative — well inside the 1e-2 gate.
    odsnode = Dict(0=>"0", 1=>"a", 2=>"b", 3=>"c", 4=>"n", 5=>"n")
    function ods_yprim(path)
        OpenDSSDirect.dss("Clear")
        OpenDSSDirect.dss("Redirect \"$(normpath(path))\"")
        OpenDSSDirect.Circuit.SetActiveElement("Transformer.t1")
        ce      = OpenDSSDirect.CktElement
        buses   = ce.BusNames(); nodeord = ce.NodeOrder()
        ncond   = ce.NumConductors(); nterm = ce.NumTerminals(); np = ncond * nterm
        Y       = reshape(ce.YPrim(), np, np)
        rowbus  = String[]
        for t in 1:nterm, _ in 1:ncond
            push!(rowbus, lowercase(split(buses[t], '.')[1]))
        end
        ids = [(rowbus[i], odsnode[nodeord[i]]) for i in 1:np]
        Y, ids
    end
    for (fname, sub) in (("pf_1ph_xfmr.dss", "single_phase"),
                         ("pf_center_tap_loaded.dss", "center_tap"),
                         ("pf_yd_xfmr.dss", "wye_delta"),
                         ("pf_dy_xfmr.dss", "delta_wye"))
        path = joinpath(_PF_CMP_DIR, fname)
        net  = from_dss(path)
        xf   = first(values(net["transformer"][sub]))
        nb, Yb = BMOPFTools.transformer_yprim(xf, sub)
        Yo, ido = ods_yprim(path)
        # Merge ODS rows sharing a (bus, terminal) identity (e.g. the centre tap's
        # two `.4` nodes) and drop the ground node, then align to the BMOPF order.
        uids = [u for u in unique(ido) if u[2] != "0"]
        pos  = Dict(u => i for (i, u) in enumerate(uids))
        M    = zeros(ComplexF64, length(uids), length(uids))
        for i in eachindex(ido), j in eachindex(ido)
            (ido[i][2] == "0" || ido[j][2] == "0") && continue
            M[pos[ido[i]], pos[ido[j]]] += Yo[i, j]
        end
        idb  = [(b, t) for (b, t) in nb]
        @test length(uids) == length(idb)
        perm = [findfirst(==(d), uids) for d in idb]
        @test !any(isnothing, perm)
        rel = maximum(abs.(M[perm, perm] .- Yb)) / max(1.0, maximum(abs.(Yb)))
        @test rel < 1e-2
    end

    # Internal winding neutral grounding (rneut/xneut): OpenDSS adds exactly
    # y_n = 1/(rneut+jxneut) to the neutral-node DIAGONAL of the Yprim. The
    # matrix-wide rel gate above is not sensitive to it (y_n ≪ max|Y|), so the
    # neutral diagonal is compared entry-wise, with a counterfactual check that
    # omitting the stamp would miss OpenDSS by ≈|y_n|.
    let path = joinpath(_PF_CMP_DIR, "pf_dy_xfmr_rneut.dss")
        net = from_dss(path)
        xf  = first(values(net["transformer"]["delta_wye"]))
        nb0, Yb0 = BMOPFTools.transformer_yprim(xf, "delta_wye")   # fields absent
        xf["r_neutral_to"] = 2.0; xf["x_neutral_to"] = 1.0
        nb, Yb = BMOPFTools.transformer_yprim(xf, "delta_wye")
        Yo, ido = ods_yprim(path)
        uids = [u for u in unique(ido) if u[2] != "0"]
        pos  = Dict(u => i for (i, u) in enumerate(uids))
        M    = zeros(ComplexF64, length(uids), length(uids))
        for i in eachindex(ido), j in eachindex(ido)
            (ido[i][2] == "0" || ido[j][2] == "0") && continue
            M[pos[ido[i]], pos[ido[j]]] += Yo[i, j]
        end
        perm = [findfirst(==(d), uids) for d in nb]
        @test !any(isnothing, perm)
        Mp  = M[perm, perm]
        i_n = findfirst(==(("lv", "n")), nb)
        yn  = 1.0 / (2.0 + 1.0im)
        # 0.1·|y_n| clears the ≈1.3e-4-relative leakage-recovery floor on the
        # 3y part of the diagonal (~0.026 S here) while staying 5× under the
        # counterfactual miss.
        @test abs(Mp[i_n, i_n] - Yb[i_n, i_n])  < 0.1 * abs(yn)    # with the stamp
        @test abs(Mp[i_n, i_n] - Yb0[i_n, i_n]) > 0.5  * abs(yn)   # counterfactual
        rel = maximum(abs.(Mp .- Yb)) / max(1.0, maximum(abs.(Yb)))
        @test rel < 1e-2
    end
end

# ── Source-bus angle offset: convention + tagging invariance ─────────────────────
# One MV source feeds a 3-phase delta-wye (Dy, 30° shift) AND a split-phase
# center-tap transformer. A non-zero source angle rigidly rotates the whole
# solution, so (B) BMOPF (radians) must match OpenDSS (degrees) under the offset,
# and (C) vector-group / voltage-level tagging — which read topology / magnitude
# only — must be unchanged by it. `from_dss` builds the net from the same fixture
# (self-validating: the angle-0 baseline isolates any parse/model error).

_net_combined_3ph_split() = from_dss(joinpath(_PF_CMP_DIR, "pf_combined_3ph_split.dss"))

@testset "PF (feasibility) — combined 3φ Dy + split-phase, source angle 0 (baseline)" begin
    path  = joinpath(_PF_CMP_DIR, "pf_combined_3ph_split.dss")
    net   = _net_combined_3ph_split()
    @test haskey(net["transformer"], "delta_wye")    # three-phase branch
    @test haskey(net["transformer"], "center_tap")   # split-phase branch
    V_ods = _ods_volts(path)
    res   = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    @test res["total_slack_magnitude_A"] < 1e-3
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(V_ods, V_bm; label="combined-a0: ", atol=0.5, rtol=2e-3)
end

@testset "PF (feasibility) — combined 3φ Dy + split-phase, source angle 17° (convention)" begin
    # The slack reference is offset by a non-30°-multiple so a wrong radians↔degrees
    # unit or a sign flip would show as a tens-of-percent mismatch (not a small one).
    path  = joinpath(_PF_CMP_DIR, "pf_combined_3ph_split.dss")
    deg   = 17.0
    net   = _reangle_source(_net_combined_3ph_split(), deg2rad(deg))
    V_ods = _ods_volts_angle(path, deg)
    res   = solve_feasibility_opf(net; optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    @test res["total_slack_magnitude_A"] < 1e-3   # init + solve converge under the offset
    phmap = Dict("a"=>"1", "b"=>"2", "c"=>"3", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(V_ods, V_bm; label="combined-a17: ", atol=0.5, rtol=2e-3)
end

@testset "Tagging invariance under source angle offset (vector group, voltage levels)" begin
    # Vector-group tagging reads terminal-map topology; voltage-level tagging reads
    # v_magnitude and v_nom ratios. Neither depends on the source angle — so both
    # must be byte-identical whether or not the slack reference is rotated.
    net0 = _net_combined_3ph_split()
    netθ = _reangle_source(net0, 0.7)            # arbitrary non-trivial offset (rad)

    dy0 = first(values(net0["transformer"]["delta_wye"]))
    ct0 = first(values(net0["transformer"]["center_tap"]))
    dyθ = first(values(netθ["transformer"]["delta_wye"]))
    ctθ = first(values(netθ["transformer"]["center_tap"]))

    # Vector group: a non-trivial Dyn clock for the 3φ unit, Ii0 for the split-phase.
    vg_dy0 = BMOPFTools._derive_vector_group("delta_wye", dy0)
    vg_ct0 = BMOPFTools._derive_vector_group("center_tap", ct0)
    @test startswith(vg_dy0, "D")                # delta primary → "Dyn…"
    @test vg_ct0 == "Ii0"
    @test BMOPFTools._derive_vector_group("delta_wye", dyθ) == vg_dy0   # invariant
    @test BMOPFTools._derive_vector_group("center_tap", ctθ) == vg_ct0  # invariant

    # Inventory vector-group tallies unchanged across the offset.
    inv0 = inventory_analysis(net0, Finding[])
    invθ = inventory_analysis(netθ, Finding[])
    @test inv0["transformer"] == invθ["transformer"]

    # Voltage-level tagging unchanged across the offset.
    vl0 = voltage_level_analysis(net0, Finding[])
    vlθ = voltage_level_analysis(netθ, Finding[])
    @test vl0["bus_voltage_map"] == vlθ["bus_voltage_map"]
    @test vl0["n_levels"] == vlθ["n_levels"]
    @test vl0["n_levels"] >= 2                   # MV + LV levels resolved
end

# ── Continuous tap optimisation: OPF-chosen tap validated against OpenDSS ───────
#
# Strategy (mirrors the fixed-tap comparisons): make a transformer's tap a FREE
# continuous OPF variable, give the source a cost and the LV bus a voltage window
# so the optimiser drives the tap to an interior value t*, then set the SAME tap on
# the OpenDSS winding and confirm the OpenDSS power flow reproduces the OPF voltages.
# Because the variable-tap model is exactly the fixed-tap model with the ratio
# promoted to a variable, agreement at t* is the OpenDSS validation of the feature.

"""
    _ods_volts_tap(dss_path, xfname, wdg, tapval) -> Dict{String, ComplexF64}

Like `_ods_volts` but sets transformer `xfname` winding `wdg` tap to `tapval`
before solving — the OpenDSS oracle at the OPF-optimised tap.
"""
function _ods_volts_tap(dss_path::String, xfname::String, wdg::Int, tapval::Real)
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
    OpenDSSDirect.dss("Edit Transformer.$xfname wdg=$wdg tap=$tapval")
    OpenDSSDirect.dss("Solve")
    names = Circuit.AllNodeNames()
    volts = Circuit.AllBusVolts()
    return Dict(n => v for (n, v) in zip(names, volts))
end

"""
    _ods_losses_tap(dss_path, xfname, wdg, tapval) -> Float64

Like `_ods_losses_W` but sets transformer `xfname` winding `wdg` tap to `tapval`
before solving — the OpenDSS loss oracle at the OPF-optimised tap.
"""
function _ods_losses_tap(dss_path::String, xfname::String, wdg::Int, tapval::Real)::Float64
    OpenDSSDirect.dss("Clear")
    OpenDSSDirect.dss("Redirect \"$(normpath(dss_path))\"")
    OpenDSSDirect.dss("Edit Transformer.$xfname wdg=$wdg tap=$tapval")
    OpenDSSDirect.dss("Solve")
    return real(Circuit.Losses())
end

@testset "PF comparison — optimised tap vs OpenDSS (single_phase)" begin
    path = joinpath(_PF_CMP_DIR, "pf_1ph_xfmr.dss")
    net  = _net_1ph_xfmr()
    # Free tap + objective lever (source cost) + an LV voltage window so t* is interior.
    net["voltage_source"]["source"]["cost"] = [1.0]
    net["bus"]["lv"]["v_min"] = [238.0]
    net["bus"]["lv"]["v_max"] = [244.0]
    t1 = net["transformer"]["single_phase"]["t1"]
    t1["tap"] = 1.0; t1["tap_min"] = 0.9; t1["tap_max"] = 1.1

    res = solve_opf(net; optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    tstar = res["transformer"]["t1"]["tap"]
    @test 0.9 < tstar < 0.99                      # interior tap, genuinely moved

    V_bm  = Dict(bid * "." * (t == "n" ? "4" : t) => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td)
    V_ods = _ods_volts_tap(path, "t1", 1, tstar)  # winding 1 = HV (from)
    # The YY tap uses the exact tap²-scaled (to-referred) leakage, so it matches the
    # OpenDSS turns-scaled Yprim at the optimised tap to the usual ~0.3 V floor.
    _cmp_volts(V_ods, V_bm; label="1ph-tap-opt: ")
end

@testset "PF comparison — optimised tap vs OpenDSS (delta_wye Dy)" begin
    path = joinpath(_PF_CMP_DIR, "pf_dy_xfmr.dss")
    net  = _net_dy_xfmr()
    net["voltage_source"]["source"]["cost"] = [1.0, 1.0, 1.0]
    net["bus"]["lv"]["v_min"] = [232.0, 232.0, 232.0]
    net["bus"]["lv"]["v_max"] = [238.0, 238.0, 238.0]
    t1 = net["transformer"]["delta_wye"]["t1"]
    t1["tap"] = 1.0; t1["tap_min"] = 0.95; t1["tap_max"] = 1.05

    res = solve_opf(net; optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    tstar = res["transformer"]["t1"]["tap"]
    @test 0.95 <= tstar < 0.99                    # tap genuinely moved (boost)

    V_bm  = Dict(bid * "." * (t == "n" ? "4" : t) => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td)
    V_ods = _ods_volts_tap(path, "t1", 1, tstar)  # winding 1 = delta HV (from)
    # NOTE: the Dy coupled delta-arm referral keeps the leakage at NOMINAL n_eff
    # (unlike the exact tap²-scaled YY model), a second-order approximation that
    # grows with tap deviation. At this ~2 % tap it agrees with the OpenDSS
    # turns-scaled Yprim to within the rtol floor (~0.24 V on the 233 V secondary);
    # the exact tap² referral for the coupled arm is the general-picture follow-up.
    _cmp_volts(V_ods, V_bm; label="Dy-tap-opt: ", atol=0.1)
end

@testset "PF comparison — optimised tap vs OpenDSS (center_tap: drop + unbalance + losses)" begin
    # Split-phase OLTC on the HV winding. The loaded fixture is a 5 km feeder with
    # heavy, UNEQUAL 120 V leg loads → strong voltage drop and leg unbalance, plus
    # copper (%r), leakage (XHL/XLT/XHT) and core (%noloadloss) losses. The free
    # tap is the coupled-coil Yprim model with the HV ratio promoted to a degree-2
    # variable; agreement with the OpenDSS turns-scaled Yprim at the optimised tap,
    # in BOTH node voltages AND total losses, is the validation. A narrow LV-leg
    # window forces an interior boost so the tap genuinely moves.
    path = joinpath(_PF_CMP_DIR, "pf_center_tap_loaded.dss")
    net  = from_dss(path)
    net["voltage_source"]["source"]["cost"] = [1.0]
    ct = net["transformer"]["center_tap"]["t1"]
    ct["tap"] = 1.0; ct["tap_min"] = 0.9; ct["tap_max"] = 1.1
    # LV legs are phase terminals (a, b); lift them into a narrow window.
    net["bus"]["lv"]["v_min"] = [120.0, 120.0]
    net["bus"]["lv"]["v_max"] = [130.0, 130.0]

    res = solve_opf(net; optimizer=Ipopt.Optimizer)
    @test res["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    tstar = res["transformer"]["t1"]["tap"]
    @test 0.9 < tstar < 0.99                 # interior boost (lower ratio raises LV)
    @test haskey(res["transformer"]["t1"], "tap_binding")

    # Node voltages vs the OpenDSS oracle at the optimised tap (winding 1 = HV).
    phmap = Dict("a"=>"1", "b"=>"2", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in res["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(_ods_volts_tap(path, "t1", 1, tstar), V_bm; label="ct-tap-opt: ", atol=0.5)

    # Losses must be passive and match OpenDSS at the optimised tap — the explicit
    # acceptance bar: correct losses under high drop + unbalance.
    @test res["losses"]["p_loss"] > 0
    @test isapprox(res["losses"]["p_loss"], _ods_losses_tap(path, "t1", 1, tstar); rtol=0.05)
end

@testset "center_tap free tap — internal exactness (T-model ≡ fixed Yprim at t*)" begin
    # The degree-2 free-tap T-model and the fixed coupled-coil Yprim are the same
    # network; re-solving with the tap FIXED to t* must reproduce the free solution
    # to solver tolerance (and drop the tap variable). This links the new free path
    # to the OpenDSS-validated fixed model. A WIDE tap band stresses the referral.
    path = joinpath(_PF_CMP_DIR, "pf_center_tap_loaded.dss")
    nf = from_dss(path); nf["voltage_source"]["source"]["cost"] = [1.0]
    ctf = nf["transformer"]["center_tap"]["t1"]
    ctf["tap"] = 1.0; ctf["tap_min"] = 0.85; ctf["tap_max"] = 1.15
    nf["bus"]["lv"]["v_min"] = [120.0, 120.0]; nf["bus"]["lv"]["v_max"] = [130.0, 130.0]
    rf = solve_opf(nf; optimizer=Ipopt.Optimizer)
    @test rf["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    tstar = rf["transformer"]["t1"]["tap"]
    @test 0.85 - 1e-6 <= tstar <= 1.15 + 1e-6

    nfix = from_dss(path)
    nfix["transformer"]["center_tap"]["t1"]["tap"] = tstar
    rfix = solve_opf(nfix; optimizer=Ipopt.Optimizer)
    @test !haskey(rfix["transformer"]["t1"], "tap")        # fixed ⇒ no variable
    vm(r, b, t) = (v = r["bus"][b][t]; sqrt(v["vr"]^2 + v["vi"]^2))
    for b in keys(rf["bus"]), t in keys(rf["bus"][b])
        @test vm(rf, b, t) ≈ vm(rfix, b, t) atol = 1e-3
    end

    # The OpenDSS oracle at the wide-band optimum still agrees → the N-referral of
    # the leakage holds at this tap excursion (≈8-9 % off nominal).
    phmap = Dict("a"=>"1", "b"=>"2", "n"=>"4")
    V_bm  = Dict(bid * "." * phmap[t] => tv["vr"] + im*tv["vi"]
                 for (bid, td) in rf["bus"] for (t, tv) in td if haskey(phmap, t))
    _cmp_volts(_ods_volts_tap(path, "t1", 1, tstar), V_bm; label="ct-tap-wide: ", atol=0.6)
end

@testset "PF comparison — free regulator taps (internal exactness)" begin
    # Regulators are already OpenDSS-validated at fixed taps; here we confirm the
    # free tap solves and that fixing the tap to the optimiser's value reproduces
    # the free solution exactly (the link to the OpenDSS-validated fixed model).
    vm(r, b, t) = sqrt(r["bus"][b][t]["vr"]^2 + r["bus"][b][t]["vi"]^2)

    # Single-phase autotransformer (Type B regulator).
    na = _net_autotransformer()
    na["voltage_source"]["vs"]["cost"] = [1.0]
    na["transformer"]["single_phase_autotransformer"]["reg"]["tap_ratio_min"] = 0.9
    na["transformer"]["single_phase_autotransformer"]["reg"]["tap_ratio_max"] = 1.1
    ra = solve_opf(na; optimizer=Ipopt.Optimizer)
    @test ra["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    astar = ra["transformer"]["reg"]["tap_ratio"]
    @test 0.9 - 1e-6 <= astar <= 1.1 + 1e-6
    nafix = _net_autotransformer()
    nafix["transformer"]["single_phase_autotransformer"]["reg"]["tap_ratio"] = astar
    rafix = solve_opf(nafix; optimizer=Ipopt.Optimizer)
    @test !haskey(rafix["transformer"]["reg"], "tap_ratio")   # fixed ⇒ no variable
    @test vm(rafix, "reg", "1") ≈ vm(ra, "reg", "1") atol=1e-4

    # Open-delta regulator (two free per-regulator taps).
    no = _net_open_delta_reg()
    haskey(no["voltage_source"], "vs") && (no["voltage_source"]["vs"]["cost"] = [1.0, 1.0, 1.0])
    od = first(values(no["transformer"]["open_delta_regulator"]))
    od["tap_ratio_min"] = [0.9, 0.9]
    od["tap_ratio_max"] = [1.1, 1.1]
    ro = solve_opf(no; optimizer=Ipopt.Optimizer)
    @test ro["termination_status"] in ("LOCALLY_SOLVED", "OPTIMAL")
    oid = first(keys(no["transformer"]["open_delta_regulator"]))
    aopt = ro["transformer"][oid]["tap_ratio"]
    @test all(0.9 - 1e-6 .<= aopt .<= 1.1 + 1e-6)
end
