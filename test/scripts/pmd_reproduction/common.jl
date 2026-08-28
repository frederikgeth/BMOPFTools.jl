# Shared helpers for the PMD reproduction scripts in this directory.
# See README.md for the environment and conventions. Not run in CI.

import PowerModelsDistribution as PMD
import Ipopt
import JuMP
using BMOPFTools

const IPOPT = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer, "print_level" => 0, "tol" => 1e-10, "acceptable_tol" => 1e-10)

const FIXTURE_DIR = joinpath(@__DIR__, "..", "..", "data", "pmd_bounds")

load_fixture(case::AbstractString) =
    parse_bmopf(joinpath(FIXTURE_DIR, case * ".json"))

"""
    gen_costs_from_fixture(net) -> Dict{String,Float64}

Per-generator linear cost coefficients read from the fixture itself, so the
scripts cannot drift from the `cost` fields the testset solves with. Each
generator's per-phase cost vector must be uniform (PMD's gen cost is per
generator, not per phase).
"""
function gen_costs_from_fixture(net::Dict)
    out = Dict{String,Float64}()
    for (id, g) in get(net, "generator", Dict())
        haskey(g, "cost") || continue
        u = unique(Float64.(g["cost"]))
        length(u) == 1 ||
            error("generator '$id': non-uniform per-phase cost cannot map to PMD")
        out[id] = u[1]
    end
    out
end

"""
    inject_pmd_bounds!(net) -> net

Translate the BMOPF bus voltage bounds that `to_pmd` does NOT map — `vn_max`,
`vpn_min`/`vpn_max`, `vpp_min`/`vpp_max` — into the PMD eng fields (`vm_ng_ub`,
`vm_pn_lb/ub`, `vm_pp_lb/ub`) via the `"_pmd"` passthrough, together with the
eng `neutral` index required for the `vm_ng_ub` fold. Values are divided by the
eng `voltage_scale_factor` at export time inside `solve_pmd_en` (PMD eng
voltages are `voltage_scale_factor`-scaled; `to_pmd` defaults to settings with
that factor). Mutates and returns `net`.
"""
function inject_pmd_bounds!(net::Dict; vscale::Real=1.0)
    for (_, bus) in get(net, "bus", Dict())
        extra = Dict{String,Any}()
        tnames = get(bus, "terminal_names", String[])
        n_idx = findfirst(==("n"), tnames)
        if n_idx !== nothing
            extra["neutral"] = n_idx
            # eng `phases` is required by PMD's pairwise-bound compilation
            extra["phases"] = [i for i in eachindex(tnames) if i != n_idx]
        end
        # BMOPF's vpn/vpp bounds are per-phase/per-pair arrays; PMD's scalar
        # vm_pn_*/vm_pp_* fields cannot express that, so emit the explicit
        # per-pair tuple lists (vm_pair_lb/ub) that PMD compiles them into.
        # BMOPF pair order (bus.jl): (1,2), (1,3), (2,3) — i<j over phases.
        haskey(bus, "vn_max") && (extra["vm_ng_ub"] = Float64(bus["vn_max"]) / vscale)
        pair_lb = Tuple{Any,Any,Real}[]
        pair_ub = Tuple{Any,Any,Real}[]
        pn_pairs = [(k, 4) for k in 1:3]
        pp_pairs = [(1, 2), (1, 3), (2, 3)]
        for (bk, pairs, dest) in (("vpn_min", pn_pairs, pair_lb),
                                  ("vpn_max", pn_pairs, pair_ub),
                                  ("vpp_min", pp_pairs, pair_lb),
                                  ("vpp_max", pp_pairs, pair_ub))
            haskey(bus, bk) || continue
            vals = Float64.(bus[bk]) ./ vscale
            append!(dest, [(a, b, vals[i]) for (i, (a, b)) in enumerate(pairs)])
        end
        isempty(pair_lb) || (extra["vm_pair_lb"] = pair_lb)
        isempty(pair_ub) || (extra["vm_pair_ub"] = pair_ub)
        isempty(extra) || (bus["_pmd"] = merge(get(bus, "_pmd", Dict{String,Any}()), extra))
    end
    # Branch angle-difference bounds: BMOPF va_diff_min/max are per-line
    # RADIANS; PMD's eng line vad_lb/ub are per-conductor DEGREES.
    for (_, line) in get(net, "line", Dict())
        extra = Dict{String,Any}()
        nph = count(!=("n"), get(line, "terminal_map_from", String[]))
        haskey(line, "va_diff_min") &&
            (extra["vad_lb"] = fill(rad2deg(Float64(line["va_diff_min"])), nph))
        haskey(line, "va_diff_max") &&
            (extra["vad_ub"] = fill(rad2deg(Float64(line["va_diff_max"])), nph))
        isempty(extra) || (line["_pmd"] = merge(get(line, "_pmd", Dict{String,Any}()), extra))
    end
    net
end

"""
    solve_pmd_en(net; gen_costs, source_costs, eng_mod!, math_mod!, form, build)

Export the BMOPF `net` with `to_pmd`, transform to the four-wire math model
(`kron_reduce=false, phase_project=false`), set per-generator linear costs, and
solve. `gen_costs` maps BMOPF generator/source ids to the linear coefficient
`c₁` (`cost = [c₁, 0]`); every gen not listed — including the PMD slack gen for
the voltage source — gets zero cost. Returns `(result, sol_si, math)`;
`sol_si` is in PMD SI units (kW, V).
"""
function solve_pmd_en(net::Dict;
                      gen_costs::Dict{String,<:Real}=Dict{String,Float64}(),
                      eng_mod!::Function=identity,
                      math_mod!::Function=identity,
                      form=PMD.IVRENPowerModel,
                      build=PMD.build_mc_opf,
                      kron::Bool=false)
    vscale_probe = BMOPFTools.to_pmd(net)["settings"]["voltage_scale_factor"]
    inject_pmd_bounds!(net; vscale=vscale_probe)
    eng = BMOPFTools.to_pmd(net)
    # `to_pmd` emits JSON-flavoured data (string enums); apply PMD's JSON-import
    # correction to get native enums/matrices, exactly as PMD's own reader does.
    PMD.correct_json_import!(eng)
    eng["data_model"] = PMD.ENGINEERING
    # `to_pmd` leaves `vbases_default` empty; PMD's voltage-base discovery needs
    # a seed at each source bus. Phase-to-ground magnitude is the natural base.
    vb = Dict{String,Real}()
    for (_, vs) in get(eng, "voltage_source", Dict())
        vb[vs["bus"]] = maximum(vs["vm"])
    end
    eng["settings"]["vbases_default"] = vb
    # `to_pmd` exports bus vm_lb/vm_ub as scalars (pre-0.16 PMD convention);
    # PMD 0.16 wants per-terminal vectors. Phases get the bound, the neutral
    # (terminal 4) stays unbounded here — `vn_max` travels via `vm_ng_ub`.
    for (_, bus) in get(eng, "bus", Dict())
        terms = bus["terminals"]
        for (key, neutral_val) in (("vm_lb", 0.0), ("vm_ub", Inf))
            if haskey(bus, key) && bus[key] isa Real
                bus[key] = [t == 4 ? neutral_val : Float64(bus[key]) for t in terms]
            end
        end
        # `to_pmd` omits "grounded" on ungrounded buses; PMD requires the key.
        haskey(bus, "grounded") || (bus["grounded"] = Int[];
                                    bus["rg"] = Float64[]; bus["xg"] = Float64[])
    end
    # A 3-wire source on a bus that has a neutral terminal must carry that
    # neutral as an explicit 4th connection at 0 V (PMD's own DSS-parser
    # convention). Without it PMD still enforces KCL on the source-bus neutral
    # but gives it no absorber, silently breaking the network's neutral return
    # (symptom: zero neutral current on the source line, wrong unbalanced
    # voltages, LOCALLY_INFEASIBLE on determined cases).
    for (_, vs) in get(eng, "voltage_source", Dict())
        bus = eng["bus"][vs["bus"]]
        if 4 in bus["terminals"] && !(4 in vs["connections"])
            push!(vs["connections"], 4)
            vs["vm"] = vcat(Float64.(vs["vm"]), 0.0)
            vs["va"] = vcat(Float64.(vs["va"]), 0.0)
        end
    end
    # Transformers: BMOPF's s_rating is ALWAYS enforced; to_pmd exports it
    # only as the nominal sm_nom, so mirror it into PMD's thermal cap sm_ub
    # (enforced by the custom builder that restores the commented-out
    # constraint_mc_transformer_thermal_limit call). BMOPF's single_phase
    # subtype uses 1-terminal ground-referenced winding maps; PMD wye
    # windings want phase+neutral, so append the (grounded) neutral.
    for (_, tr) in get(eng, "transformer", Dict())
        haskey(tr, "sm_nom") && !haskey(tr, "sm_ub") && (tr["sm_ub"] = tr["sm_nom"][1])
        if haskey(tr, "connections")
            tr["connections"] = [length(c) == 1 ? vcat(c, 4) : c for c in tr["connections"]]
        end
        # the JSON-import fixer misses the per-winding configuration vector
        if haskey(tr, "configuration")
            tr["configuration"] = [c isa AbstractString ?
                (c == "DELTA" ? PMD.DELTA : PMD.WYE) : c for c in tr["configuration"]]
        end
        # ideal-core / fixed-tap defaults PMD's decomposition requires but
        # to_pmd omits (per-winding vectors sized by each winding's phases)
        get!(tr, "noloadloss", 0.0)
        get!(tr, "cmag", 0.0)
        nw_ = length(tr["connections"])
        nph = [length(c) - 1 for c in tr["connections"]]
        get!(tr, "tm_nom", ones(nw_))
        get!(tr, "tm_set", [fill(1.0, nph[w]) for w in 1:nw_])
        get!(tr, "tm_fix", [fill(true, nph[w]) for w in 1:nw_])
        get!(tr, "tm_lb", [fill(0.9, nph[w]) for w in 1:nw_])
        get!(tr, "tm_ub", [fill(1.1, nph[w]) for w in 1:nw_])
        get!(tr, "tm_step", [fill(1 / 32, nph[w]) for w in 1:nw_])
        get!(tr, "polarity", fill(1, nw_))
    end
    # PMD's mappers expect parser-style source_id on every component
    for ct in ("bus", "line", "linecode", "load", "generator", "voltage_source",
               "transformer", "shunt", "switch")
        for (id, c) in get(eng, ct, Dict())
            c isa Dict && get!(c, "source_id", "$ct.$id")
        end
    end
    # `to_pmd` does not set the load model or vm_nom; all fixtures here are
    # constant power (vm_nom is structural — it only scales ZIP-type models).
    vnom = isempty(vb) ? 230.0 : maximum(values(vb))
    for (_, ld) in get(eng, "load", Dict())
        haskey(ld, "model") || (ld["model"] = PMD.POWER)
        haskey(ld, "vm_nom") || (ld["vm_nom"] = vnom)
    end
    # `to_pmd` emits shunt matrices only when the BMOPF linecode carries them,
    # but PMD's eng2math requires the keys — fill zeros of the series size.
    # Present values need a UNIT conversion: BMOPF B_from/G_from are siemens,
    # while PMD's eng line shunt fields are capacitance-style nF/length —
    # eng2math applies b = 2πf·val·1e-9·length (`_admittance_conversion`).
    f_hz = eng["settings"]["base_frequency"]
    s_to_nF = 1e9 / (2π * f_hz)
    for comp in ("linecode", "line"), (_, lc) in get(eng, comp, Dict())
        haskey(lc, "rs") || continue
        z = zero(lc["rs"])
        for k in ("g_fr", "g_to", "b_fr", "b_to")
            haskey(lc, k) ? (lc[k] = lc[k] .* s_to_nF) : (lc[k] = copy(z))
        end
    end
    eng_mod!(eng)
    # kron=true targets the three-wire Kron-reduced formulations (e.g. IVRU
    # for the angle-difference case, whose constraint has no EN counterpart)
    # phase_project stays off: it would rebuild partial-phase units as rotated
    # three-phase ones, changing the feasible set for single-phase DERs
    math = PMD.transform_data_model(eng; multinetwork=false,
                                    kron_reduce=kron, phase_project=false)
    kron || PMD.add_start_vrvi!(math)
    for (_, gen) in math["gen"]
        c = Float64(get(gen_costs, get(gen, "name", ""), 0.0))
        gen["cost"] = [c, 0.0]
    end
    math_mod!(math)
    pm  = PMD.instantiate_mc_model(math, form, build)
    res = PMD.optimize_model!(pm; optimizer=IPOPT)
    sol = PMD.transform_solution(res["solution"], math; make_si=true)
    return res, sol, math
end

"""
Per-generator dispatch from a reproduction solution (eng-keyed by
`transform_solution`; power in W because `to_pmd` exports
`power_scale_factor = 1`): id ⇒ (pg = Σ kW, qg = Σ kvar).
"""
function pmd_dispatch(sol)
    Dict{String,NamedTuple}(
        id => (pg = sum(g["pg"]) / 1000.0, qg = sum(g["qg"]) / 1000.0)
        for (id, g) in get(sol, "generator", Dict()))
end

"Voltage magnitudes (V) at an eng bus of a reproduction solution."
pmd_vm(sol, bus::AbstractString) =
    abs.(sol["bus"][bus]["vr"] .+ im .* sol["bus"][bus]["vi"])

"Per-generator dispatch from a BMOPF result: id ⇒ (pg = Σ kW, qg = Σ kvar)."
function bmopf_dispatch(res)
    out = Dict{String,NamedTuple}()
    for (gid, g) in get(res, "generator", Dict())
        out[gid] = (pg = sum(g[ph]["pg"] for ph in keys(g)) / 1000.0,
                    qg = sum(g[ph]["qg"] for ph in keys(g)) / 1000.0)
    end
    out
end

"""
    perturbation_check(solve_fn, costs::Dict, der_ids; ratio=1.5)

Non-degeneracy gate for two-generator cases (plan §4): re-solve with each DER's
cost scaled by `ratio` (one at a time) and print the dispatch splits. The split
must move with the cost ratio; a static split means the arbitration is
degenerate and the case must be redesigned before its numbers are locked.
`solve_fn(costs) -> Dict(name ⇒ (pg, qg))`.
"""
function perturbation_check(solve_fn::Function, costs::Dict, der_ids; ratio=1.5)
    base = solve_fn(costs)
    println("  base split: ", [(id, round(base[id].pg; digits=4)) for id in der_ids])
    for id in der_ids
        c = copy(costs); c[id] *= ratio
        alt = solve_fn(c)
        println("  ", id, " cost ×", ratio, ": ",
                [(i, round(alt[i].pg; digits=4)) for i in der_ids])
    end
    nothing
end

"Print a paste-ready block of locked targets."
function print_targets(case::AbstractString, disp::Dict, extras::Pair...)
    println("── locked targets — ", case, " ──")
    for (id, d) in sort(collect(disp); by=first)
        println("  ", id, ": Σpg = ", round(d.pg; digits=4), " kW, Σqg = ",
                round(d.qg; digits=4), " kvar")
    end
    for (k, v) in extras
        println("  ", k, " = ", v)
    end
end
