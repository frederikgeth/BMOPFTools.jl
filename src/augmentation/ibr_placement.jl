# IBR placement: deliberate, explainable addition of inverter-interfaced DERs.
#
# Parallel to `add_generators` (see der_placement.jl), but for the richer
# `IBR` element. Where `add_generators` writes a thin generator object,
# `add_ibrs` places an IBR nameplate — `topology`, `prime_mover`,
# `s_max`, `p_avail`, `cost` — and leaves the P/Q dispatch box to be filled by
# `augment_case`'s IBR pass (`_apply_ibr_augmentation!`, augment.jl
# Pass 4), which derives p_max/p_min/q_min/q_max from s_max/p_avail. This keeps
# the same "placement places, augment bounds" division used for generators:
#   fix_case → add_ibrs → augment_case → solve_opf
#
# MVP scope: PV prime movers, box reactive bounds (no control_profile, no
# batteries, no grid-forming). Topology is inferred from the host load's
# terminal_map (a neutral terminal ⇒ FOUR_LEG, otherwise SINGLE_PHASE).
#
# Filtering and topology context reuse the element-agnostic helpers in
# der_placement.jl (`_xfmr_downstream`, `_collect_load_aggregates`,
# `_voltage_family`, `_source_buses`, `_total_load_w`, `_resolve_connectivity`,
# `_resolve_voltage_levels`). The recipe-typed helpers (candidate buses, sizing
# basis, cost) are specialised here because `GeneratorRecipe`/`IBRRecipe`
# are standalone structs — see `_ibr_strategy_buses` / `_ibr_basis_total` /
# `_cost_ibr`.
#
# NOTE: the OPF engine fully supports IBRs (constraints, objective, results,
# per-unit), so placed IBRs ARE dispatched by solve_opf once augment_case
# has filled their P/Q box. Only the I/O converters (from_pmd/to_pmd/from_dss) do
# not yet map IBR elements.

"""
    IBRRecipe

Declarative configuration for [`add_ibrs`](@ref). Mirrors
[`GeneratorRecipe`](@ref) for the shared placement knobs, with IBR-specific
fields for topology, prime mover and apparent-power sizing. Every field is a
deliberate, explainable knob — no randomness.

Placement strategy
------------------
- `strategy` — `:load_following` (one IBR per load bus),
  `:hosting_capacity` (sized to a fraction of the feeding transformer rating),
  or `:topology_targeted` (IBRs at feeder leaves / near the source).
- `topology_mode` — `:leaves` or `:near_source` (only for `:topology_targeted`).

Filters (composable over any strategy)
-------------------------------------
- `voltage_levels` — restrict placement to these voltage-level families
  (`:LV`, `:MV`, `:HV`, `:EHV`); `nothing` = all levels.
- `min_local_load_va` — skip buses whose aggregated local load is below this.
- `skip_source_buses` — never place at a voltage-source bus.

Sizing (targets apparent power `s_max`)
--------------------------------------
- `size_basis` — `:fraction_of_local_load`, `:fraction_of_downstream_load`,
  `:fraction_of_transformer_rating`, or `:fixed_tiers`.
- `s_fraction` — fraction applied for the `:fraction_of_*` bases (sets `s_max`).
- `fixed_tier_va` — voltage-level-family → fixed `s_max` (VA) for `:fixed_tiers`.
- `s_to_p_ratio` — `p_avail = s_to_p_ratio × s_max` per phase (1.0 = unity-rated
  PV; < 1.0 leaves headroom for reactive support at full irradiance).

IBR model
--------------
- `prime_mover` — `:PV` (MVP). Drives `p_min = 0` in the augment pass.
- `inverter_topology` — `:infer` (FOUR_LEG when the host load has a neutral
  terminal, else SINGLE_PHASE), or a forced `:FOUR_LEG` / `:THREE_LEG` /
  `:SINGLE_PHASE`.

Cost (makes the OPF dispatch non-trivial)
----------------------------------------
- `cost_basis` — `:cheaper_than_slack`, `:uniform`, or `:tiered_by_level`.
- `slack_cost`, `der_cost_factor` — `cost = der_cost_factor × slack_cost`.
- `der_cost_uniform` — used when `cost_basis = :uniform`.
- `der_cost_tiers` — voltage-level-family → cost for `:tiered_by_level`.

Identity / safety
-----------------
- `id_prefix` — new IBR ids are `\$(id_prefix)\$(bus)`.
- `overwrite_existing` — if `false`, buses that already host an IBR are
  skipped (no duplicate / replacement).
- `apply_placement` — master enable; `false` makes `add_ibrs` a no-op copy.
"""
Base.@kwdef struct IBRRecipe
    strategy          :: Symbol = :load_following
    topology_mode     :: Symbol = :leaves
    # filters
    voltage_levels    :: Union{Vector{Symbol},Nothing} = [:LV]
    min_local_load_va :: Float64 = 0.0
    skip_source_buses :: Bool    = true
    # sizing (apparent power)
    size_basis        :: Symbol  = :fraction_of_local_load
    s_fraction        :: Float64 = 0.8
    fixed_tier_va     :: Dict{Symbol,Float64} = Dict(:LV => 30_000.0, :MV => 1_000_000.0)
    s_to_p_ratio      :: Float64 = 1.0
    # IBR model
    prime_mover       :: Symbol  = :PV
    inverter_topology :: Symbol  = :infer
    # cost
    cost_basis        :: Symbol  = :cheaper_than_slack
    slack_cost        :: Float64 = 1.0
    der_cost_factor   :: Float64 = 0.5
    der_cost_uniform  :: Float64 = 0.5
    der_cost_tiers    :: Dict{Symbol,Float64} = Dict(:LV => 0.0, :MV => 0.8)
    # identity / safety
    id_prefix         :: String = "pv_"
    overwrite_existing:: Bool   = false
    apply_placement   :: Bool   = true
end

"""
    default_ibr_recipe() -> IBRRecipe

The default IBR placement recipe: load-following PV IBRs at LV buses,
`s_max` sized to 80 % of local load, unity-rated (`p_avail = s_max`), priced at
half the slack cost.
"""
default_ibr_recipe() = IBRRecipe()

# ── Public entry point ───────────────────────────────────────────────────────

"""
    add_ibrs(net; recipe=default_ibr_recipe(), analysis=nothing)
        -> (net′::Dict{String,Any}, manifest::TransformationManifest)

Place inverter-interfaced DERs into `net` using an explainable, semantics-driven
recipe. `net` is never mutated; `net′` is an independent deep copy.

Writes the IBR nameplate — `bus`, `terminal_map`, `topology`,
`prime_mover`, `s_max`, `p_avail`, `cost` — on each new IBR. The active and
reactive dispatch box (`p_max`/`p_min`/`q_min`/`q_max`) is intentionally left to
[`augment_case`](@ref)'s IBR pass, which derives it from `s_max`/`p_avail`.
Every IBR field written is recorded in the returned
[`TransformationManifest`](@ref) with confidence `:synthetic`.

`analysis` may be the output of [`analyze`](@ref) (or a dict carrying
`"voltage_levels"` / `"connectivity"`); if `nothing`, the needed sub-analyses are
run internally.

The placed IBRs are dispatched by [`solve_opf`](@ref) once
[`augment_case`](@ref) has filled their P/Q box. The OPF engine supports IBRs,
and PowerIO v0.6.1 can import IBR/control data where the source carries it.
BMOPFTools still treats `to_pmd` and `to_dss` IBR export as a follow up.

# Example
```julia
net1, _    = fix_case(net)
net2, imf  = add_ibrs(net1; recipe=IBRRecipe(strategy=:load_following))
net3, _    = augment_case(net2)   # fills p_max/p_min/q_min/q_max on the new IBRs
```
"""
function add_ibrs(net::Dict{String,Any};
                       recipe::IBRRecipe = default_ibr_recipe(),
                       analysis = nothing)::Tuple{Dict{String,Any}, TransformationManifest}

    net′    = deepcopy(net)
    entries = TransformEntry[]

    fb = Finding[]; benchmark_readiness_check(net,  fb)
    fa = Finding[]

    inv_findings = Finding[]
    if recipe.apply_placement
        _apply_ibr_placement!(net′, entries, inv_findings, recipe, analysis)
    end

    benchmark_readiness_check(net′, fa)
    append!(fa, inv_findings)   # IBR placement advisories (I.IBR.* / W.IBR.*)

    manifest = TransformationManifest(string(Dates.now()), recipe, entries, fb, fa)
    (net′, manifest)
end

# ── STATCOM convenience constructor ───────────────────────────────────────────

"""
    add_statcom!(net, bus; s_max, id=nothing, terminal_map=nothing,
                 topology=nothing, dc_link_coupled=false, cost=nothing) -> String

Add a STATCOM (a *D-STATCOM* in distribution-system parlance) to `net` at `bus`
and return its id. A STATCOM is a shunt-connected voltage-source converter with
no active-power source: it is modelled as an IBR whose `prime_mover` is
`"STATCOM"`, so [`augment_case`](@ref) exposes the full per-phase converter
rating as symmetric reactive capability (`q_max = s_max`, `q_min = -s_max`).
Converter losses are neglected at this fidelity.

`dc_link_coupled` selects the active-power behaviour:

  * `false` (default) — **reactive-only**: each phase's active power is clamped to
    zero (`p_min = p_max = 0`).
  * `true` — **active power circulation**: the phases share one DC link, so
    per-phase active power is free within the `s_max` circle but the *net* active
    power is zero (`∑ₖ Pₖ = 0`). The converter can then move active power between
    phases to balance an unbalanced feeder, where reactive support has weak
    authority because LV networks are resistive (R≫X). See the
    [D-STATCOM unbalance study](@ref statcom-unbalance) tutorial.

`net` **is mutated** (an entry is written under `net["ibr"]`); use a `deepcopy`
first if you need to preserve the original.

`s_max` is the converter apparent-power rating in VA, given either as a scalar
(replicated across phases) or as a per-phase vector. `terminal_map` and
`topology` are inferred from the bus's `terminal_names` when omitted (last
terminal treated as the neutral/reference, as elsewhere in the IBR model).

Reactive limits are intentionally left for [`augment_case`](@ref) to derive, in
keeping with [`add_ibrs`](@ref). For a controlled STATCOM, attach a
`control_profile` (e.g. a Volt-var droop) by setting the IBR's
`control_profile` field after this call.

# Example
```julia
add_statcom!(net, "bus_650"; s_max = 200_000.0)   # 200 kVA reactive-only D-STATCOM
net2, _ = augment_case(net)                        # fills q_min/q_max = ∓s_max

add_statcom!(net, "bus_675"; s_max = 50_000.0, dc_link_coupled = true)  # phase balancer
```
"""
function add_statcom!(net::Dict{String,Any}, bus::AbstractString;
                      s_max,
                      id::Union{Nothing,AbstractString} = nothing,
                      terminal_map::Union{Nothing,AbstractVector} = nothing,
                      topology::Union{Nothing,AbstractString} = nothing,
                      dc_link_coupled::Bool = false,
                      cost = nothing)::String

    haskey(net, "bus") && haskey(net["bus"], bus) ||
        throw(ArgumentError("add_statcom!: bus '$bus' not found in net"))

    tm = if terminal_map !== nothing
        Vector{String}(terminal_map)
    else
        Vector{String}(get(net["bus"][bus], "terminal_names", String[]))
    end
    length(tm) >= 2 ||
        throw(ArgumentError("add_statcom!: bus '$bus' needs ≥2 terminals " *
                            "(got $(length(tm))); pass terminal_map explicitly"))
    n_phase = length(tm) - 1

    topo = topology !== nothing ? uppercase(String(topology)) :
           (length(tm) <= 2 ? "SINGLE_PHASE" : "FOUR_LEG")

    smax_vec = s_max isa AbstractVector ? Float64.(collect(s_max)) :
                                          fill(Float64(s_max), n_phase)
    length(smax_vec) == n_phase ||
        throw(ArgumentError("add_statcom!: s_max has $(length(smax_vec)) entries " *
                            "but bus '$bus' has $n_phase phase(s)"))

    iid = id !== nothing ? String(id) : string("statcom_", bus)
    invs = get!(net, "ibr", Dict{String,Any}())
    haskey(invs, iid) &&
        throw(ArgumentError("add_statcom!: ibr id '$iid' already exists"))

    obj = Dict{String,Any}(
        "bus"          => String(bus),
        "terminal_map" => tm,
        "topology"     => topo,
        "prime_mover"  => "STATCOM",
        "s_max"        => smax_vec,
        "p_avail"      => 0.0)
    dc_link_coupled && (obj["dc_link_coupled"] = true)
    cost !== nothing && (obj["cost"] = cost isa AbstractVector ?
        Float64.(collect(cost)) : fill(Float64(cost), n_phase))

    invs[iid] = obj
    return iid
end

# ── Core placement ───────────────────────────────────────────────────────────

function _apply_ibr_placement!(net′::Dict{String,Any},
                                    entries::Vector{TransformEntry},
                                    inv_findings::Vector{Finding},
                                    recipe::IBRRecipe,
                                    analysis)
    vl   = _resolve_voltage_levels(net′, analysis)
    conn = _resolve_connectivity(net′, analysis)
    bus_v = get(vl, "bus_voltage_map", Dict{String,Float64}())

    loads = _collect_load_aggregates(net′)
    xfmr  = _xfmr_downstream(net′, loads)

    # 1. strategy-specific candidate bus set (shared with generator placement)
    candidate_buses = _ibr_strategy_buses(recipe, conn, loads)

    # 2. shared filters
    src_buses = _source_buses(net′)
    dangling  = Set(get(conn, "dangling_buses", String[]))
    selected = String[]
    for bus in candidate_buses
        haskey(loads, bus)                           || continue      # only at load buses
        bus in dangling                              && continue
        recipe.skip_source_buses && bus in src_buses && continue
        lvl = _voltage_family(get(bus_v, bus, NaN))
        if recipe.voltage_levels !== nothing
            (lvl === nothing || !(lvl in recipe.voltage_levels)) && continue
        end
        agg = loads[bus]
        sum(agg.p_nom) < recipe.min_local_load_va && continue
        if !recipe.overwrite_existing && _bus_has_ibr(net′, bus)
            continue
        end
        push!(selected, bus)
    end
    sort!(unique!(selected))

    # 3. build, size, cost, and write each IBR
    invs = get!(net′, "ibr", Dict{String,Any}())
    n_placed = 0
    total_s  = 0.0
    for bus in selected
        agg = loads[bus]
        lvl = something(_voltage_family(get(bus_v, bus, NaN)), :LV)
        basis, note_basis = _ibr_basis_total(recipe, bus, agg, xfmr)
        s_max = _size_ibr(recipe, agg.p_nom, basis, lvl)
        all(iszero, s_max) && continue
        p_avail = recipe.s_to_p_ratio * sum(s_max)
        cost  = _cost_ibr(recipe, length(s_max), lvl)
        topo  = _resolve_topology(recipe, agg.terminal_map)

        iid  = string(recipe.id_prefix, bus)
        rule = string("IBR_PLACEMENT/", recipe.strategy)
        invs[iid] = Dict{String,Any}(
            "bus" => bus, "terminal_map" => copy(agg.terminal_map),
            "topology" => topo, "prime_mover" => string(recipe.prime_mover),
            "s_max" => s_max, "p_avail" => p_avail, "cost" => cost)

        note = "IBR at bus '$bus' (level $lvl); $note_basis; topology $topo; " *
               "phasing inherited from load"
        push!(entries, TransformEntry(:ibr, iid, "bus", nothing, bus, rule, :synthetic, note))
        push!(entries, TransformEntry(:ibr, iid, "terminal_map", nothing,
            agg.terminal_map, rule, :synthetic, "inherited from load at '$bus'"))
        push!(entries, TransformEntry(:ibr, iid, "topology", nothing,
            topo, rule, :synthetic,
            recipe.inverter_topology === :infer ?
                "inferred from load terminal_map ($(length(agg.terminal_map)) terminals)" :
                "forced by recipe"))
        push!(entries, TransformEntry(:ibr, iid, "prime_mover", nothing,
            string(recipe.prime_mover), rule, :synthetic, "recipe prime_mover"))
        push!(entries, TransformEntry(:ibr, iid, "s_max", nothing, s_max, rule, :synthetic, note))
        push!(entries, TransformEntry(:ibr, iid, "p_avail", nothing, p_avail, rule, :synthetic,
            "p_avail = $(recipe.s_to_p_ratio) × Σ s_max"))
        push!(entries, TransformEntry(:ibr, iid, "cost", nothing, cost,
            string("IBR_PLACEMENT/cost_", recipe.cost_basis), :synthetic,
            "cost basis $(recipe.cost_basis) → $(cost[1]) \$/kWh per phase (linear dispatch cost)"))

        n_placed += 1
        total_s  += sum(s_max)
    end

    _emit_ibr_findings!(inv_findings, net′, recipe, n_placed, total_s)
    return n_placed
end

# ── Strategy candidate builder ────────────────────────────────────────────────
# Mirrors _strategy_buses (der_placement.jl), specialised to IBRRecipe.
function _ibr_strategy_buses(recipe::IBRRecipe, conn, loads)
    if recipe.strategy == :load_following || recipe.strategy == :hosting_capacity
        return collect(keys(loads))
    elseif recipe.strategy == :topology_targeted
        if recipe.topology_mode == :leaves
            return collect(get(conn, "degree_1_buses", String[]))
        else # :near_source — load buses on the source→leaf longest path (first half)
            path = collect(get(conn, "longest_path_buses", String[]))
            half = max(1, cld(length(path), 2))
            return path[1:min(half, length(path))]
        end
    else
        error("unknown IBRRecipe.strategy = $(recipe.strategy)")
    end
end

# ── Sizing (apparent power) ───────────────────────────────────────────────────

# Resolve the raw basis quantity (VA) for the chosen size_basis, plus a note.
# Mirrors _basis_total (der_placement.jl) but phrases the note in terms of s_max.
# The s_fraction is applied later in _size_ibr, not here.
function _ibr_basis_total(recipe::IBRRecipe, bus::String, agg, xfmr)
    local_total = sum(agg.p_nom)
    if recipe.size_basis == :fraction_of_local_load
        return local_total, "s_max = $(recipe.s_fraction) × local load $(round(local_total)) VA"
    elseif recipe.size_basis == :fixed_tiers
        return local_total, "s_max from fixed voltage-level tier"
    elseif recipe.size_basis == :fraction_of_transformer_rating
        info = get(xfmr.bus_info, bus, nothing)
        info === nothing && return local_total, "s_max = $(recipe.s_fraction) × local load (no feeding transformer found)"
        share = info.down_total > 0 ? local_total / info.down_total : 1.0
        basis = info.s_rating * share
        return basis, "s_max = $(recipe.s_fraction) × transformer '$(info.xfmr_id)' rating $(round(info.s_rating)) VA × load share $(round(share, digits=3))"
    elseif recipe.size_basis == :fraction_of_downstream_load
        info = get(xfmr.bus_info, bus, nothing)
        info === nothing && return local_total, "s_max = $(recipe.s_fraction) × local load (no downstream context)"
        return local_total, "s_max = $(recipe.s_fraction) × downstream-load share at bus"
    else
        error("unknown IBRRecipe.size_basis = $(recipe.size_basis)")
    end
end

# Distribute the sized s_max across phases, mirroring the local load shape.
function _size_ibr(recipe::IBRRecipe, p_nom::Vector{Float64},
                        basis_total::Float64, level::Symbol)::Vector{Float64}
    n = length(p_nom)
    n == 0 && return Float64[]
    total = recipe.size_basis == :fixed_tiers ?
        get(recipe.fixed_tier_va, level, 0.0) :
        recipe.s_fraction * basis_total
    s = sum(p_nom)
    weights = s > 0 ? p_nom ./ s : fill(1.0 / n, n)
    total .* weights
end

# Per-phase linear dispatch cost, mirroring _cost_der (der_placement.jl). Kept
# local because IBRRecipe is a standalone struct; the field meanings are
# identical (cost_basis / der_cost_factor / slack_cost / der_cost_uniform /
# der_cost_tiers).
function _cost_ibr(recipe::IBRRecipe, n_phases::Int, level::Symbol)::Vector{Float64}
    c = if recipe.cost_basis == :cheaper_than_slack
        recipe.der_cost_factor * recipe.slack_cost
    elseif recipe.cost_basis == :uniform
        recipe.der_cost_uniform
    elseif recipe.cost_basis == :tiered_by_level
        get(recipe.der_cost_tiers, level, recipe.der_cost_factor * recipe.slack_cost)
    else
        error("unknown IBRRecipe.cost_basis = $(recipe.cost_basis)")
    end
    fill(Float64(c), n_phases)
end

# ── Topology inference ────────────────────────────────────────────────────────
# A load terminal_map of [phase…, neutral] (≥ 2 terminals with a neutral) maps to
# FOUR_LEG; a two-terminal [phase, ref] map to SINGLE_PHASE. Forced values are
# normalised to the schema's uppercase enum strings.
function _resolve_topology(recipe::IBRRecipe, terminal_map::Vector{String})::String
    if recipe.inverter_topology !== :infer
        return uppercase(string(recipe.inverter_topology))
    end
    n = length(terminal_map)
    n <= 2 ? "SINGLE_PHASE" : "FOUR_LEG"
end

# ── Findings ──────────────────────────────────────────────────────────────────

function _emit_ibr_findings!(inv_findings::Vector{Finding}, net′, recipe, n_placed, total_s)
    if n_placed == 0
        push!(inv_findings, Finding(WARNING, "W.IBR.NO_CANDIDATES", :augmentation,
            :network, nothing,
            "IBR placement strategy '$(recipe.strategy)' produced no placements " *
            "(no candidate load buses passed the filters).",
            Dict{String,Any}("strategy" => string(recipe.strategy))))
        return
    end
    total_load = _total_load_w(net′)
    ratio = total_load > 0 ? total_s / total_load : Inf
    push!(inv_findings, Finding(INFO, "I.IBR.PLACED", :augmentation, :ibr, nothing,
        "Placed $n_placed IBR(s) (strategy=$(recipe.strategy), total s_max=" *
        "$(round(total_s)) VA); IBR-rating/load ≈ $(round(ratio*100, digits=1))%.",
        Dict{String,Any}("n_placed" => n_placed, "total_s_max_va" => total_s,
                         "rating_load_ratio" => ratio,
                         "strategy" => string(recipe.strategy))))
    if ratio > 1.5
        push!(inv_findings, Finding(WARNING, "W.IBR.OVERSUPPLY", :augmentation,
            :ibr, nothing,
            "IBR-rating/load ratio $(round(ratio*100, digits=1))% exceeds 150% — " *
            "the OPF may be trivially over-supplied; consider lowering s_fraction.",
            Dict{String,Any}("rating_load_ratio" => ratio)))
    end
end

# ── Helpers ───────────────────────────────────────────────────────────────────

function _bus_has_ibr(net, bus::String)::Bool
    for (_, inv) in get(net, "ibr", Dict())
        inv isa Dict && string(get(inv, "bus", "")) == bus && return true
    end
    false
end
