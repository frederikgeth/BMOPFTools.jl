# DER placement: deliberate, explainable addition of dispatchable generators.
#
# Unlike `augment_case` (which only gap-fills standards-grounded bounds and
# deliberately does NOT add generation), `add_generators` is an opt-in pass that
# *creates* dispatchable `generator` elements so the OPF problem becomes
# meaningful. Placement is driven by the semantic/topological knowledge the
# library already computes (voltage levels, connectivity degree/depth,
# transformer ratings, downstream load) — never random — and every generator is
# recorded in a `TransformationManifest` with a rule, confidence, and note.
#
# Reactive bounds are intentionally NOT written here: `add_generators` writes
# only p_min/p_max/cost, and `augment_case`'s generation pass fills q_min/q_max
# from p_max (EN 50549-1), keeping that logic in one place. The intended order is
#   fix_case → add_generators → augment_case → solve_opf

"""
    GeneratorRecipe

Declarative configuration for [`add_generators`](@ref). Every field is a
deliberate, explainable knob — no randomness.

Placement strategy
------------------
- `strategy` — `:load_following` (one DER per load bus), `:hosting_capacity`
  (DERs sized to a fraction of the feeding transformer rating), or
  `:topology_targeted` (DERs at feeder leaves / near the source).
- `topology_mode` — `:leaves` or `:near_source` (only for `:topology_targeted`).

Filters (composable over any strategy)
-------------------------------------
- `voltage_levels` — restrict placement to these voltage-level families
  (`:LV`, `:MV`, `:HV`, `:EHV`); `nothing` = all levels.
- `min_local_load_va` — skip buses whose aggregated local load is below this.
- `skip_source_buses` — never place at a voltage-source bus.

Sizing
------
- `size_basis` — `:fraction_of_local_load`, `:fraction_of_downstream_load`,
  `:fraction_of_transformer_rating`, or `:fixed_tiers`.
- `der_p_fraction` — fraction applied for the `:fraction_of_*` bases.
- `fixed_tier_w` — voltage-level-family → fixed DER size (W) for `:fixed_tiers`.
- `p_min_fraction` — `p_min = p_min_fraction × p_max` (0 = curtailable).

Cost (makes the OPF dispatch non-trivial)
----------------------------------------
- `cost_basis` — `:cheaper_than_slack`, `:uniform`, or `:tiered_by_level`.
- `slack_cost`, `der_cost_factor` — `cost = der_cost_factor × slack_cost`.
- `der_cost_uniform` — used when `cost_basis = :uniform`.
- `der_cost_tiers` — voltage-level-family → cost for `:tiered_by_level`.

Identity / safety
-----------------
- `configuration` — generator configuration; `nothing` inherits from the load.
- `id_prefix` — new generator ids are `\$(id_prefix)\$(bus)`.
- `overwrite_existing` — if `false`, buses that already host a generator are
  skipped (no duplicate / replacement).
- `apply_placement` — master enable; `false` makes `add_generators` a no-op copy.
"""
Base.@kwdef struct GeneratorRecipe
    strategy          :: Symbol = :load_following
    topology_mode     :: Symbol = :leaves
    # filters
    voltage_levels    :: Union{Vector{Symbol},Nothing} = [:LV]
    min_local_load_va :: Float64 = 0.0
    skip_source_buses :: Bool    = true
    # sizing
    size_basis        :: Symbol  = :fraction_of_local_load
    der_p_fraction    :: Float64 = 0.8
    fixed_tier_w      :: Dict{Symbol,Float64} = Dict(:LV => 30_000.0, :MV => 1_000_000.0)
    p_min_fraction    :: Float64 = 0.0
    # cost
    cost_basis        :: Symbol  = :cheaper_than_slack
    slack_cost        :: Float64 = 1.0
    der_cost_factor   :: Float64 = 0.5
    der_cost_uniform  :: Float64 = 0.5
    der_cost_tiers    :: Dict{Symbol,Float64} = Dict(:LV => 0.0, :MV => 0.8)
    # identity / safety
    configuration     :: Union{String,Nothing} = nothing
    id_prefix         :: String = "der_"
    overwrite_existing:: Bool   = false
    apply_placement   :: Bool   = true
end

"""
    default_generator_recipe() -> GeneratorRecipe

The default DER placement recipe: load-following at LV buses, sized to 80 % of
local load, priced at half the slack cost.
"""
default_generator_recipe() = GeneratorRecipe()

# A resolved placement candidate (always tied to a load bus).
struct _Placement
    bus           :: String
    terminal_map  :: Vector{String}
    configuration :: String
    p_nom         :: Vector{Float64}   # per-phase local load shape
    basis_total_w :: Float64           # raw quantity for the chosen size_basis
    level         :: Symbol
    rule_tag      :: String            # strategy name, for the manifest rule
    note_basis    :: String            # human-readable driver of the sizing
end

# ── Public entry point ───────────────────────────────────────────────────────

"""
    add_generators(net; recipe=default_generator_recipe(), analysis=nothing)
        -> (net′::Dict{String,Any}, manifest::TransformationManifest)

Place dispatchable DERs into `net` using an explainable, semantics-driven
recipe. `net` is never mutated; `net′` is an independent deep copy.

Writes only `bus`, `terminal_map`, `configuration`, `p_min`, `p_max`, `cost` on
each new generator — reactive bounds are intentionally left to
[`augment_case`](@ref). Every generator field written is recorded in the returned
[`TransformationManifest`](@ref).

`analysis` may be the output of [`analyze`](@ref) (or a dict carrying
`"voltage_levels"` / `"connectivity"`); if `nothing`, the needed sub-analyses are
run internally.

# Example
```julia
net1, _    = fix_case(net)
net2, dmf  = add_generators(net1; recipe=GeneratorRecipe(strategy=:load_following))
net3, _    = augment_case(net2)   # fills q_min/q_max on the new DERs
result     = solve_opf(net3)
```
"""
function add_generators(net::Dict{String,Any};
                        recipe::GeneratorRecipe = default_generator_recipe(),
                        analysis = nothing)::Tuple{Dict{String,Any}, TransformationManifest}

    net′    = deepcopy(net)
    entries = TransformEntry[]

    fb = Finding[]; benchmark_readiness_check(net,  fb)
    fa = Finding[]

    der_findings = Finding[]
    if recipe.apply_placement
        _apply_der_placement!(net′, entries, der_findings, recipe, analysis)
    end

    benchmark_readiness_check(net′, fa)
    append!(fa, der_findings)   # DER placement advisories (I.DER.* / W.DER.*)

    manifest = TransformationManifest(string(Dates.now()), recipe, entries, fb, fa)
    (net′, manifest)
end

# ── Core placement ───────────────────────────────────────────────────────────

function _apply_der_placement!(net′::Dict{String,Any},
                               entries::Vector{TransformEntry},
                               der_findings::Vector{Finding},
                               recipe::GeneratorRecipe,
                               analysis)
    vl   = _resolve_voltage_levels(net′, analysis)
    conn = _resolve_connectivity(net′, analysis)
    bus_v = get(vl, "bus_voltage_map", Dict{String,Float64}())

    loads = _collect_load_aggregates(net′)
    xfmr  = _xfmr_downstream(net′, loads)

    # 1. strategy-specific candidate bus set
    candidate_buses = _strategy_buses(recipe, conn, loads)

    # 2. shared filters
    src_buses     = _source_buses(net′)
    dangling      = Set(get(conn, "dangling_buses", String[]))
    selected = String[]
    for bus in candidate_buses
        haskey(loads, bus)                       || continue          # only at load buses
        bus in dangling                          && continue
        recipe.skip_source_buses && bus in src_buses && continue
        lvl = _voltage_family(get(bus_v, bus, NaN))
        if recipe.voltage_levels !== nothing
            (lvl === nothing || !(lvl in recipe.voltage_levels)) && continue
        end
        agg = loads[bus]
        # min_local_load_va is a VA threshold — compare against apparent power
        # |S| = √(ΣP² + ΣQ²), not active power alone.
        hypot(sum(agg.p_nom), sum(agg.q_nom)) < recipe.min_local_load_va && continue
        # overwrite guard
        if !recipe.overwrite_existing && _bus_has_generator(net′, bus)
            continue
        end
        push!(selected, bus)
    end
    sort!(unique!(selected))

    # 3. build, size, cost, and write each generator
    gens = get!(net′, "generator", Dict{String,Any}())
    n_placed = 0
    total_p  = 0.0
    for bus in selected
        agg = loads[bus]
        lvl = something(_voltage_family(get(bus_v, bus, NaN)), :LV)
        basis, note_basis = _basis_total(recipe, bus, agg, xfmr)
        p_max = _size_der(recipe, agg.p_nom, basis, lvl)
        all(iszero, p_max) && continue
        p_min = recipe.p_min_fraction .* p_max
        cost  = _cost_der(recipe, length(p_max), lvl)
        config = recipe.configuration === nothing ? agg.configuration : recipe.configuration

        gid = string(recipe.id_prefix, bus)
        rule = string("DER_PLACEMENT/", recipe.strategy)
        gens[gid] = Dict{String,Any}(
            "bus" => bus, "terminal_map" => copy(agg.terminal_map),
            "configuration" => config,
            "p_min" => p_min, "p_max" => p_max, "cost" => cost)

        note = "DER at bus '$bus' (level $lvl); $note_basis; phasing inherited from load"
        push!(entries, TransformEntry(:generator, gid, "bus", nothing, bus, rule, :synthetic, note))
        push!(entries, TransformEntry(:generator, gid, "terminal_map", nothing,
            agg.terminal_map, rule, :synthetic, "inherited from load at '$bus'"))
        push!(entries, TransformEntry(:generator, gid, "configuration", nothing,
            config, rule, :synthetic, "inherited from load at '$bus'"))
        push!(entries, TransformEntry(:generator, gid, "p_min", nothing, p_min, rule, :synthetic,
            "p_min = $(recipe.p_min_fraction) × p_max (curtailable)"))
        push!(entries, TransformEntry(:generator, gid, "p_max", nothing, p_max, rule, :synthetic, note))
        push!(entries, TransformEntry(:generator, gid, "cost", nothing, cost,
            string("DER_PLACEMENT/cost_", recipe.cost_basis), :synthetic,
            "cost basis $(recipe.cost_basis) → $(cost[1]) \$/kWh per phase (linear dispatch cost)"))

        n_placed += 1
        total_p  += sum(p_max)
    end

    _emit_der_findings!(der_findings, net′, recipe, n_placed, total_p)
    return n_placed
end

# ── Strategy candidate builders ──────────────────────────────────────────────

function _strategy_buses(recipe::GeneratorRecipe, conn, loads)
    if recipe.strategy == :load_following
        return collect(keys(loads))
    elseif recipe.strategy == :hosting_capacity
        # all load buses downstream of a transformer
        return collect(keys(loads))
    elseif recipe.strategy == :topology_targeted
        if recipe.topology_mode == :leaves
            return collect(get(conn, "degree_1_buses", String[]))
        else # :near_source — load buses on the source→leaf longest path
            path = collect(get(conn, "longest_path_buses", String[]))
            half = max(1, cld(length(path), 2))
            return path[1:min(half, length(path))]
        end
    else
        error("unknown GeneratorRecipe.strategy = $(recipe.strategy)")
    end
end

# ── Sizing ───────────────────────────────────────────────────────────────────

# Resolve the raw quantity for the chosen size_basis at a bus, plus a note.
function _basis_total(recipe::GeneratorRecipe, bus::String, agg, xfmr)
    local_total = sum(agg.p_nom)
    if recipe.size_basis == :fraction_of_local_load
        return local_total, "p_max = $(recipe.der_p_fraction) × local load $(round(local_total)) VA"
    elseif recipe.size_basis == :fixed_tiers
        return local_total, "p_max from fixed voltage-level tier"
    elseif recipe.size_basis == :fraction_of_transformer_rating
        info = get(xfmr.bus_info, bus, nothing)
        info === nothing && return local_total, "p_max = $(recipe.der_p_fraction) × local load (no feeding transformer found)"
        share = info.down_total > 0 ? local_total / info.down_total : 1.0
        basis = info.s_rating * share
        return basis, "p_max = $(recipe.der_p_fraction) × transformer '$(info.xfmr_id)' rating $(round(info.s_rating)) VA × load share $(round(share, digits=3))"
    elseif recipe.size_basis == :fraction_of_downstream_load
        info = get(xfmr.bus_info, bus, nothing)
        info === nothing && return local_total, "p_max = $(recipe.der_p_fraction) × local load (no downstream context)"
        # Size from the load DOWNSTREAM of the feeding transformer, not the local
        # bus load (which was returned before, making this identical to
        # :fraction_of_local_load).
        return info.down_total, "p_max = $(recipe.der_p_fraction) × downstream load $(round(info.down_total)) VA"
    else
        error("unknown GeneratorRecipe.size_basis = $(recipe.size_basis)")
    end
end

# Distribute the sized active power across phases, mirroring the local load shape.
function _size_der(recipe::GeneratorRecipe, p_nom::Vector{Float64},
                   basis_total::Float64, level::Symbol)::Vector{Float64}
    n = length(p_nom)
    n == 0 && return Float64[]
    total = recipe.size_basis == :fixed_tiers ?
        get(recipe.fixed_tier_w, level, 0.0) :
        recipe.der_p_fraction * basis_total
    # Distribute by per-phase load MAGNITUDE and keep the result non-negative:
    # a phase with negative p_nom (embedded generation) or a negative basis must
    # not produce a negative p_max (an inverted/unphysical bound).
    w  = abs.(p_nom)
    sw = sum(w)
    weights = sw > 0 ? w ./ sw : fill(1.0 / n, n)
    abs(total) .* weights
end

# ── Cost ─────────────────────────────────────────────────────────────────────

# The OPF objective reads `cost` as a per-phase vector of linear coefficients
# ($/W per phase). We emit one identical coefficient per phase so dispatch is
# priced linearly across all phases.
function _cost_der(recipe::GeneratorRecipe, n_phases::Int, level::Symbol)::Vector{Float64}
    c = if recipe.cost_basis == :cheaper_than_slack
        recipe.der_cost_factor * recipe.slack_cost
    elseif recipe.cost_basis == :uniform
        recipe.der_cost_uniform
    elseif recipe.cost_basis == :tiered_by_level
        get(recipe.der_cost_tiers, level, recipe.der_cost_factor * recipe.slack_cost)
    else
        error("unknown GeneratorRecipe.cost_basis = $(recipe.cost_basis)")
    end
    fill(Float64(c), n_phases)
end

# ── Findings ─────────────────────────────────────────────────────────────────

function _emit_der_findings!(der_findings::Vector{Finding}, net′, recipe, n_placed, total_p)
    if n_placed == 0
        push!(der_findings, Finding(WARNING, "W.DER.NO_CANDIDATES", :augmentation,
            :network, nothing,
            "DER placement strategy '$(recipe.strategy)' produced no placements " *
            "(no candidate load buses passed the filters).",
            Dict{String,Any}("strategy" => string(recipe.strategy))))
        return
    end
    total_load = _total_load_w(net′)
    ratio = total_load > 0 ? total_p / total_load : Inf
    push!(der_findings, Finding(INFO, "I.DER.PLACED", :augmentation, :generator, nothing,
        "Placed $n_placed DER(s) (strategy=$(recipe.strategy), total p_max=" *
        "$(round(total_p)) W); generation/load ≈ $(round(ratio*100, digits=1))%.",
        Dict{String,Any}("n_placed" => n_placed, "total_p_max_w" => total_p,
                         "generation_load_ratio" => ratio,
                         "strategy" => string(recipe.strategy))))
    if ratio > 1.5
        push!(der_findings, Finding(WARNING, "W.DER.OVERSUPPLY", :augmentation,
            :generator, nothing,
            "Generation/load ratio $(round(ratio*100, digits=1))% exceeds 150% — " *
            "the OPF may be trivially over-supplied; consider lowering der_p_fraction.",
            Dict{String,Any}("generation_load_ratio" => ratio)))
    end
end

# ── Helpers ──────────────────────────────────────────────────────────────────

# Voltage-level family from a nominal voltage (V), matching _voltage_level_label.
function _voltage_family(v_volts)::Union{Symbol,Nothing}
    (v_volts isa Real && isfinite(v_volts)) || return nothing
    kv = v_volts / 1000.0
    kv >= 100 ? :EHV : kv >= 35 ? :HV : kv >= 1 ? :MV : :LV
end

function _resolve_connectivity(net, analysis)
    if analysis isa Dict
        for k in ("connectivity", "connectivity_analysis")
            haskey(analysis, k) && return analysis[k]
        end
    end
    connectivity_analysis(net, Finding[])
end

function _source_buses(net)::Set{String}
    Set(string(get(vs, "bus", ""))
        for (_, vs) in get(net, "voltage_source", Dict()) if vs isa Dict)
end

function _bus_has_generator(net, bus::String)::Bool
    for (_, g) in get(net, "generator", Dict())
        g isa Dict && string(get(g, "bus", "")) == bus && return true
    end
    false
end

function _total_load_w(net)::Float64
    s = 0.0
    for (_, l) in get(net, "load", Dict())
        l isa Dict || continue
        s += sum(Float64.(get(l, "p_nom", Float64[])))
    end
    s
end

# Aggregate loads per bus: terminal_map/configuration from the first load,
# p_nom summed elementwise over loads with matching phase count.
function _collect_load_aggregates(net)::Dict{String,NamedTuple}
    out = Dict{String,NamedTuple}()
    # Iterate loads in a deterministic (sorted-id) order so the phasing and
    # configuration a multi-load bus inherits from its "first" load is stable
    # rather than dependent on Dict iteration order.
    loaddict = get(net, "load", Dict())
    for lid in sort!(collect(keys(loaddict)))
        l = loaddict[lid]
        l isa Dict || continue
        bus = string(get(l, "bus", ""))
        isempty(bus) && continue
        tm  = string.(get(l, "terminal_map", String[]))
        cfg = string(get(l, "configuration", "WYE"))
        pn  = Float64.(get(l, "p_nom", Float64[]))
        isempty(pn) && continue
        qn  = Float64.(get(l, "q_nom", Float64[]))
        length(qn) == length(pn) || (qn = zeros(length(pn)))
        if haskey(out, bus)
            prev = out[bus]
            if length(prev.p_nom) == length(pn)
                out[bus] = (terminal_map = prev.terminal_map,
                            configuration = prev.configuration,
                            p_nom = prev.p_nom .+ pn,
                            q_nom = prev.q_nom .+ qn)
            end
        else
            out[bus] = (terminal_map = tm, configuration = cfg, p_nom = pn, q_nom = qn)
        end
    end
    out
end

# Map each downstream load bus to its feeding transformer's rating and the
# transformer's total downstream load, for transformer-rating-based sizing.
function _xfmr_downstream(net, loads)
    # Collect each rated transformer's downstream set once.
    xfmr = get(net, "transformer", Dict())
    entries = Tuple{String,Float64,Set{String},Float64}[]
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            t isa Dict || continue
            s_rating = Float64(get(t, "s_rating", 0.0))
            s_rating > 0 || continue
            _, to_buses = _xfmr_from_to_buses(subtype, t)   # covers n_winding
            isempty(to_buses) && continue
            down = _downstream_buses(net, string(id), to_buses)
            down_total = sum(Float64[sum(loads[b].p_nom) for b in down if haskey(loads, b)]; init = 0.0)
            push!(entries, (string(id), s_rating, down, down_total))
        end
    end
    # "Nearest transformer wins": the one whose downstream set is SMALLEST among
    # those containing the bus (a more-downstream unit's set is a subset). Sort by
    # (set size, id) so the assignment is deterministic — the previous first-claim
    # over Dict iteration order was not.
    sort!(entries, by = e -> (length(e[3]), e[1]))
    bus_info = Dict{String,NamedTuple}()
    for (id, s_rating, down, down_total) in entries
        for b in down
            haskey(loads, b) || continue
            haskey(bus_info, b) && continue
            bus_info[b] = (xfmr_id = id, s_rating = s_rating, down_total = down_total)
        end
    end
    (bus_info = bus_info,)
end

# Buses electrically downstream of a transformer (mirrors _downstream_load's BFS).
function _downstream_buses(net, xfmr_id::String, to_buses::Vector{String})::Set{String}
    adj = Dict{String,Vector{String}}()
    add!(a, b) = (push!(get!(adj, a, String[]), b); push!(get!(adj, b, String[]), a))
    for (_, l) in get(net, "line", Dict())
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) && add!(string(f), string(t))
    end
    for (_, sw) in get(net, "switch", Dict())
        get(sw, "open_switch", false) && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) && add!(string(f), string(t))
    end
    xfmr = get(net, "transformer", Dict())
    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (oid, ot) in sub
            string(oid) == xfmr_id && continue
            # Include n_winding windings so BFS can traverse OTHER transformers.
            fb, tb = _xfmr_from_to_buses(subtype, ot)
            for f in fb, t in tb
                add!(f, t)
            end
        end
    end
    seen = Set{String}(to_buses); q = copy(to_buses)
    while !isempty(q)
        b = popfirst!(q)
        for nb in get(adj, b, String[])
            nb in seen && continue
            push!(seen, nb); push!(q, nb)
        end
    end
    seen
end
