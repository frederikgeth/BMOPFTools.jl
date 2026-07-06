# Regenerate the LV1_14bus fixtures from the authoritative OpenDSS source.
#
# WHY: the committed `examples/lv1_14bus.json` and
# `test/data/LV/lv1_14bus_timeseries.json` were derived by a historical path that
# kept OpenDSS-native phase numbering (1/2/3) but mis-mapped the delta-wye
# transformer's wye-side terminal map (`[2,3,1,n]` instead of `[1,2,3,n]`) and
# corrupted its series impedance. That drives the power flow onto a spurious
# branch (unloaded phase 3 carrying ~rated current, ~50 kVAr from nowhere), which
# the always-enforced transformer nameplate cap then correctly flags — making the
# VVWO and time-series tutorials' `@example` OPF solves infeasible.
#
# The current `from_dss` import is correct (it remaps OpenDSS 1/2/3/4 → a/b/c/n
# consistently, transformer included). This script rebuilds the fixtures from
# `test/data/LV/LV1_14bus/Master.dss` via `from_dss`, applies a CONSISTENT,
# transformer-aware a/b/c → 1/2/3 relabel (the piece the old derivation got
# wrong), re-attaches the two rooftop PV IBRs and the 24 h load/solar profiles,
# and writes the corrected fixtures. Run from the repo root:
#     julia --project=test scripts/regenerate_lv1_14bus.jl

using BMOPFTools
using BMOPFTools: from_dss, write_bmopf, parse_bmopf

const ROOT = pkgdir(BMOPFTools)
const DSS  = joinpath(ROOT, "test", "data", "LV", "LV1_14bus", "Master.dss")

# ── Consistent, transformer-aware phase relabel a/b/c → 1/2/3 ──────────────────
# Unlike the test helper `_relabel_phases!`, this also relabels transformer
# terminal maps — the omission that let the corruption through. A uniform
# substitution over conductor labels is physics-preserving (per-phase numeric
# arrays travel with their renamed conductor and are left untouched).
const Π = Dict("a" => "1", "b" => "2", "c" => "3", "n" => "n")
_sub(v) = [get(Π, string(t), string(t)) for t in v]

function relabel_phases!(net::Dict{String,Any})
    for (_, bus) in get(net, "bus", Dict())
        bus isa Dict || continue
        haskey(bus, "terminal_names") && (bus["terminal_names"] = _sub(bus["terminal_names"]))
        haskey(bus, "perfectly_grounded_terminals") &&
            (bus["perfectly_grounded_terminals"] = _sub(bus["perfectly_grounded_terminals"]))
        haskey(bus, "neutral_terminal") && (bus["neutral_terminal"] = get(Π, string(bus["neutral_terminal"]), string(bus["neutral_terminal"])))
    end
    for ct in ("load", "generator", "shunt", "voltage_source", "ibr", "capacitor")
        for (_, c) in get(net, ct, Dict())
            c isa Dict && haskey(c, "terminal_map") && (c["terminal_map"] = _sub(c["terminal_map"]))
        end
    end
    for ct in ("line", "switch")
        for (_, c) in get(net, ct, Dict())
            c isa Dict || continue
            haskey(c, "terminal_map_from") && (c["terminal_map_from"] = _sub(c["terminal_map_from"]))
            haskey(c, "terminal_map_to")   && (c["terminal_map_to"]   = _sub(c["terminal_map_to"]))
        end
    end
    for (_, sub) in get(net, "transformer", Dict())      # ← the fix: transformers too
        sub isa Dict || continue
        for (_, x) in sub
            x isa Dict || continue
            haskey(x, "terminal_map_from") && (x["terminal_map_from"] = _sub(x["terminal_map_from"]))
            haskey(x, "terminal_map_to")   && (x["terminal_map_to"]   = _sub(x["terminal_map_to"]))
        end
    end
    net
end

# ── Base network: import + relabel ────────────────────────────────────────────
function base_network()
    net = from_dss(DSS)
    delete!(net, "_meta")                 # tool-private import notes
    relabel_phases!(net)
    net["name"] = "lv1_14bus"
    net
end

# ── 24 h profiles (PMD convention: multiplicative scale factors) ───────────────
const RESIDENTIAL = [0.35,0.30,0.28,0.27,0.28,0.32,0.45,0.60,0.55,0.50,0.45,0.42,
                     0.40,0.40,0.42,0.48,0.60,0.80,1.00,0.95,0.85,0.70,0.55,0.42]
const SOLAR       = [0.0,0.0,0.0,0.0,0.0,0.05,0.15,0.35,0.55,0.75,0.90,1.00,
                     1.00,0.95,0.85,0.65,0.40,0.15,0.02,0.0,0.0,0.0,0.0,0.0]
_profile(vals) = Dict{String,Any}("time" => collect(0:23), "values" => vals)

# A single-phase rooftop PV IBR, run-to-nameplate (zero-ish cost), with a
# volt-var/volt-watt-ready dispatch box; p_max/p_avail follow the solar profile.
_pv(bus, ph) = Dict{String,Any}(
    "bus" => bus, "terminal_map" => [ph, "n"], "topology" => "SINGLE_PHASE",
    "prime_mover" => "PV", "s_max" => [16000.0], "p_avail" => 15000.0,
    "p_max" => [15000.0], "p_min" => [0.0], "q_min" => [-5000.0], "q_max" => [5000.0],
    "cost" => [0.1],
    "time_series" => Dict{String,Any}("p_max" => "solar_daily", "p_avail" => "solar_daily"))

# ── Build the time-series fixture ─────────────────────────────────────────────
function timeseries_network()
    net = base_network()
    net["name"] = "lv1_14bus_timeseries"
    # Two rooftop PV, co-located with the two customers, on phases 1 and 2.
    net["ibr"] = Dict{String,Any}("pv_b3230" => _pv("b3230", "1"),
                                  "pv_b2656" => _pv("b2656", "2"))
    # Bind the two loads to the residential profile.
    for (_, l) in net["load"]
        l isa Dict || continue
        l["time_series"] = Dict{String,Any}("p_nom" => "residential_daily",
                                             "q_nom" => "residential_daily")
    end
    net["time_series"] = Dict{String,Any}("residential_daily" => _profile(RESIDENTIAL),
                                          "solar_daily"       => _profile(SOLAR))
    net
end

# ── Write both fixtures ───────────────────────────────────────────────────────
base = base_network()
write_bmopf(base, joinpath(ROOT, "examples", "lv1_14bus.json"))
println("wrote examples/lv1_14bus.json")

ts = timeseries_network()
write_bmopf(ts, joinpath(ROOT, "test", "data", "LV", "lv1_14bus_timeseries.json"))
println("wrote test/data/LV/lv1_14bus_timeseries.json")
