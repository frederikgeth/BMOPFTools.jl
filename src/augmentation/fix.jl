"""
    FixRecipe

Parameters controlling which repair passes `fix_case` runs and their
thresholds.  Lossless, semantics-preserving passes default to `true`;
the one pass that changes power-system physics (`apply_perfect_grounding`)
defaults to `false` and must be opted into explicitly.
"""
Base.@kwdef struct FixRecipe
    # ── Pass enable flags (in execution order) ───────────────────────────────
    apply_largest_component       :: Bool    = true
    apply_simplify_network        :: Bool    = true
    apply_remove_zero_loads       :: Bool    = true
    apply_low_impedance_to_switch :: Bool    = true
    apply_source_bus_bounds       :: Bool    = true
    apply_adjacent_current_bounds :: Bool    = false  # opt-in: topology inference
    apply_perfect_grounding       :: Bool    = false  # opt-in: changes OPF physics
    apply_shunt_to_capacitor      :: Bool    = false  # opt-in: re-represent capacitive shunts
    apply_snap_transformer_impedance :: Bool = false  # opt-in: tiny placeholder leakage → 0

    # ── Thresholds ────────────────────────────────────────────────────────────
    # Absolute total series impedance (Ω) below which a line is replaced by a
    # closed switch.  Applied per conductor: norm of diagonal Z × length.
    low_impedance_threshold_ohm     :: Float64 = 1e-4

    # Grounding resistance (Ω) below which a shunt is promoted to a
    # perfectly_grounded_terminal.  Only used when apply_perfect_grounding=true.
    perfect_grounding_threshold_ohm :: Float64 = 0.1

    # Per-unit total series impedance (on the from-side rating base) below which a
    # transformer's non-zero leakage is treated as a placeholder for zero and
    # snapped to exactly 0.  Only used when apply_snap_transformer_impedance=true.
    snap_transformer_z_min_pu       :: Float64 = 1e-3
end

# ── Public entry point ───────────────────────────────────────────────────────

"""
    fix_case(net; recipe=FixRecipe()) -> (net′, TransformationManifest)

Apply structural repairs to a BMOPF network dict, returning an independent
deep copy together with a [`TransformationManifest`](@ref) recording every
change.

`net` is never mutated.  Passes run in order; each is independently
controlled by the corresponding `apply_*` flag in `recipe`.

# Passes (in order)

1. **Largest connected component** — drop buses, lines, loads, generators,
   and shunts that belong to components unreachable from any voltage source.
2. **Simplify network** — merge consecutive same-linecode series lines and
   remove dangling stub lines (wraps [`simplify_network`](@ref)).
3. **Remove zero loads** — delete loads with `p_nom = q_nom = 0` on all phases.
4. **Low-impedance lines → switches** — replace lines whose total per-conductor
   series impedance is below `recipe.low_impedance_threshold_ohm` with closed
   switches.
5. **Source bus bounds** — remove all voltage bounds (`v_min/v_max`,
   `vpn_*`, `vpp_*`, `vneg_max`, etc.) from source buses; they are
   redundant because the voltage source fixes the terminal voltages exactly.
6. **Adjacent current bounds** *(opt-in, default off)* — for each line or
   switch lacking `i_max`, infer an upper bound from directly adjacent
   elements (lines, switches, transformers) at either endpoint bus.
7. **Perfect grounding** *(opt-in, default off)* — promote grounding shunts
   whose equivalent resistance is below `recipe.perfect_grounding_threshold_ohm`
   to `perfectly_grounded_terminals` entries and remove the shunt.

# Example
```julia
net  = parse_bmopf("feeder.json")
net′, fix_mf  = fix_case(net)
net″, aug_mf  = augment_case(net′)
render_manifest(fix_mf)
result = solve_opf(net″)
```
"""
function fix_case(net::Dict{String,Any};
                  recipe::FixRecipe = FixRecipe())::Tuple{Dict{String,Any},
                                                          TransformationManifest}
    net′   = deepcopy(net)
    entries = TransformEntry[]

    fb = Finding[]
    benchmark_readiness_check(net, fb)

    # Pass 1 — largest connected component
    recipe.apply_largest_component &&
        _fix_largest_component!(net′, entries)

    # Pass 2 — simplify network (series merge + dangling removal)
    recipe.apply_simplify_network &&
        _fix_simplify!(net′, entries)

    # Pass 3 — remove zero loads
    recipe.apply_remove_zero_loads &&
        _fix_zero_loads!(net′, entries)

    # Pass 4 — low-impedance lines → switches
    recipe.apply_low_impedance_to_switch &&
        _fix_low_impedance!(net′, entries, recipe.low_impedance_threshold_ohm)

    # Pass 5 — remove redundant bounds on source buses
    recipe.apply_source_bus_bounds &&
        _fix_source_bus_bounds!(net′, entries)

    # Pass 6 — adjacent current bounds (opt-in)
    recipe.apply_adjacent_current_bounds &&
        _fix_adjacent_current_bounds!(net′, entries)

    # Pass 7 — perfect grounding (opt-in)
    recipe.apply_perfect_grounding &&
        _fix_perfect_grounding!(net′, entries,
                                recipe.perfect_grounding_threshold_ohm)

    # Pass 8 — capacitive shunts → capacitor objects (opt-in)
    recipe.apply_shunt_to_capacitor &&
        _fix_shunt_to_capacitor!(net′, entries)

    # Pass 9 — snap placeholder transformer leakage to exactly zero (opt-in)
    recipe.apply_snap_transformer_impedance &&
        _fix_snap_transformer_impedance!(net′, entries,
                                         recipe.snap_transformer_z_min_pu)

    fa = Finding[]
    benchmark_readiness_check(net′, fa)

    manifest = TransformationManifest(
        string(Dates.now()),
        recipe,                 # the actual FixRecipe (manifest.recipe is ::Any)
        entries,
        fb,
        fa,
    )

    (net′, manifest)
end

# ── Pass helpers ─────────────────────────────────────────────────────────────

# Pass 1: drop everything not reachable from a voltage source
# Return `base` if free in `existing`, else `base_2`, `base_3`, … — so a
# generated element id never silently overwrites a pre-existing one.
function _unique_id(existing, base::AbstractString)::String
    haskey(existing, base) || return String(base)
    k = 2
    while haskey(existing, "$(base)_$k"); k += 1; end
    "$(base)_$k"
end

function _fix_largest_component!(net′, entries)
    conn = connectivity_analysis(net′, Finding[])
    conn["is_connected"] && return   # nothing to do

    source_buses = Set{String}(get(conn, "source_buses", String[]))
    comps = get(conn, "components", Vector{Vector{String}}[])
    isempty(comps) && return

    # With no voltage source, EVERY component is unsourced and the pass below
    # would delete the entire network — never the intent. Bail with a finding so
    # a later source/generator augmentation can still act on the intact net.
    if isempty(source_buses)
        push!(entries, TransformEntry(
            :network, "(topology)", "no_source", nothing, nothing,
            "connectivity_analysis", :standard,
            "No voltage source in the network — largest-component pruning skipped " *
            "(dropping every unsourced component would delete the whole network)."))
        return
    end

    # Which components contain at least one source bus?
    keep_buses = Set{String}()
    dropped_comps = Vector{Vector{String}}()
    for comp in comps
        if any(b -> b in source_buses, comp)
            union!(keep_buses, comp)
        else
            push!(dropped_comps, comp)
        end
    end
    isempty(dropped_comps) && return

    drop_buses = Set{String}(b for comp in dropped_comps for b in comp)

    # Count loads/generators in dropped buses for the manifest note
    n_loads = count(((_, l),) -> get(l, "bus", nothing) in drop_buses,
                    get(net′, "load", Dict()))
    n_gens  = count(((_, g),) -> get(g, "bus", nothing) in drop_buses,
                    get(net′, "generator", Dict()))

    let d = get(net′, "bus", Dict())
        for bid in collect(keys(d))
            bid in drop_buses || continue
            delete!(d, bid)
        end
    end
    for ctype in ("line", "switch")
        d = get(net′, ctype, Dict())
        for (id, el) in collect(d)
            (get(el, "bus_from", nothing) in drop_buses ||
             get(el, "bus_to",   nothing) in drop_buses) && delete!(d, id)
        end
    end
    for ctype in ("load", "generator", "shunt", "voltage_source", "ibr", "capacitor")
        d = get(net′, ctype, Dict())
        for (id, el) in collect(d)
            get(el, "bus", nothing) in drop_buses && delete!(d, id)
        end
    end
    for (subtype, xfmr_sub) in get(net′, "transformer", Dict())
        xfmr_sub isa Dict || continue
        for (id, el) in collect(xfmr_sub)
            el isa Dict || continue
            # Use the subtype-aware bus accessor so a winding-list (n_winding)
            # transformer whose winding bus was dropped is pruned too, rather than
            # left dangling by a bus_from/bus_to-only check.
            fb, tb = _xfmr_from_to_buses(subtype, el)
            (any(in(drop_buses), fb) || any(in(drop_buses), tb)) && delete!(xfmr_sub, id)
        end
    end

    push!(entries, TransformEntry(
        :network, "(topology)", "disconnected_components",
        length(dropped_comps), nothing,
        "connectivity_analysis", :standard,
        "dropped $(length(dropped_comps)) component(s) containing " *
        "$(length(drop_buses)) bus(es), $n_loads load(s), $n_gens generator(s) — " *
        "none reachable from a voltage source; " *
        "buses: $(join(sort(collect(drop_buses)), ", "))"))
end

# Pass 2: wrap simplify_network and harvest its log
function _fix_simplify!(net′, entries)
    prev_log = get(net′, "_simplification_log", Any[])
    net_s = simplify_network(net′;
                             open_switches   = false,   # leave open switches alone
                             closed_switches = false,   # leave switch merging alone
                             dangling_lines  = true,
                             series_lines    = true)
    new_log = get(net_s, "_simplification_log", Any[])
    added   = new_log[length(prev_log)+1:end]

    # Copy all mutated keys back into net′ in-place
    for k in keys(net_s)
        k == "_simplification_log" && continue
        net′[k] = net_s[k]
    end
    delete!(net′, "_simplification_log")

    for entry in added
        code = get(entry, "code", "SIMPLIFY")
        msg  = get(entry, "message", "")
        eid  = get(entry, "element_id", "(unknown)")
        etype = Symbol(get(entry, "element_type", "network"))
        push!(entries, TransformEntry(
            etype, string(eid), code,
            nothing, nothing,
            "simplify_network", :standard, msg))
    end
end

# Pass 3: remove loads with all-zero p_nom and q_nom
function _fix_zero_loads!(net′, entries)
    loads = get(net′, "load", Dict())
    for id in collect(keys(loads))
        l = loads[id]
        l isa Dict || continue
        p = Float64.(get(l, "p_nom", Float64[]))
        q = Float64.(get(l, "q_nom", Float64[]))
        (isempty(p) || !all(iszero, p)) && continue
        (isempty(q) || !all(iszero, q)) && continue
        delete!(loads, id)
        push!(entries, TransformEntry(
            :load, id, "(removed)",
            Dict("p_nom" => p, "q_nom" => q), nothing,
            "W.REDUND.ZERO_LOAD", :standard,
            "load has p_nom=0 and q_nom=0 on all phases — electrically inert"))
    end
end

# Pass 4: replace low-impedance lines with closed switches
function _fix_low_impedance!(net′, entries, threshold_ohm)
    lines     = get(net′, "line",     Dict{String,Any}())
    switches  = get!(net′, "switch",  Dict{String,Any}())
    linecodes = get(net′, "linecode", Dict{String,Any}())

    for id in collect(keys(lines))
        line = lines[id]
        line isa Dict || continue
        lcid = get(line, "linecode", nothing)
        lc   = lcid !== nothing ? get(linecodes, string(lcid), nothing) : nothing
        len  = Float64(get(line, "length", 1.0))

        z_max = _line_z_max(lc, len)
        z_max === nothing && continue
        z_max >= threshold_ohm && continue

        # Build a switch from the line's topology, carrying the effective
        # current rating (line override, else linecode) so the thermal
        # constraint is not lost in the conversion.
        sw = Dict{String,Any}(
            "bus_from"         => get(line, "bus_from", ""),
            "bus_to"           => get(line, "bus_to",   ""),
            "terminal_map_from"=> get(line, "terminal_map_from", String[]),
            "terminal_map_to"  => get(line, "terminal_map_to",   String[]),
            "open_switch"      => false,
        )
        i_max = get(line, "i_max", nothing)
        i_max === nothing && lc isa Dict && (i_max = get(lc, "i_max", nothing))
        i_max !== nothing && (sw["i_max"] = deepcopy(i_max))
        sw_id = _unique_id(switches, "_sw_$(id)")
        switches[sw_id] = sw
        delete!(lines, id)

        push!(entries, TransformEntry(
            :line, id, "(converted_to_switch)",
            Dict("z_max_ohm" => z_max, "threshold_ohm" => threshold_ohm),
            sw_id,
            "W.INT.LOW_IMPEDANCE_LINE", :standard,
            "total |Z|=$(round(z_max, sigdigits=3)) Ω < threshold " *
            "$(threshold_ohm) Ω — replaced by closed switch '$(sw_id)'"))
    end
end

# Maximum per-conductor total impedance magnitude for a line (Ω).
# Returns nothing if the linecode is missing or has no R/X data.
function _line_z_max(lc, length_m::Float64)
    lc isa Dict || return nothing
    n = _count_conductors(lc)
    n == 0 && return nothing
    z_max = 0.0
    for k in 1:n
        r = Float64(get(lc, "R_series_$(k)_$(k)", 0.0))
        x = Float64(get(lc, "X_series_$(k)_$(k)", 0.0))
        z_max = max(z_max, sqrt(r^2 + x^2) * length_m)
    end
    z_max
end

# Pass 5: strip all voltage bounds from source buses
const _ALL_VOLTAGE_BOUND_KEYS = [
    "v_min", "v_max",
    "vpn_min", "vpn_max",
    "vpp_min", "vpp_max",
    "vpos_min", "vpos_max",
    "vneg_max", "vzero_max",
    "vn_max",
    "va_diff_min", "va_diff_max", "va_nom",
]

function _fix_source_bus_bounds!(net′, entries)
    buses = get(net′, "bus", Dict())
    source_buses = Set{String}()
    for (_, vs) in get(net′, "voltage_source", Dict())
        b = get(vs, "bus", nothing)
        b isa String && push!(source_buses, b)
    end

    for bid in source_buses
        bus = get(buses, bid, nothing)
        bus isa Dict || continue
        for field in _ALL_VOLTAGE_BOUND_KEYS
            haskey(bus, field) || continue
            old_val = bus[field]
            delete!(bus, field)
            push!(entries, TransformEntry(
                :bus, bid, field,
                old_val, nothing,
                "voltage_source_fixes_terminal_voltages", :standard,
                "source bus — voltage bounds are redundant; " *
                "voltage source pins terminals exactly"))
        end
    end
end

# Pass 6: adjacent current bounds (opt-in)
function _fix_adjacent_current_bounds!(net′, entries)
    lines    = get(net′, "line",     Dict())
    switches = get(net′, "switch",   Dict())

    # Build bus → set of (element_type, element_id, i_max_or_nothing) adjacency
    adj = Dict{String, Vector{Tuple{Symbol,String,Union{Float64,Nothing}}}}()

    function _add_adj!(bus, etype, eid, imax)
        push!(get!(adj, bus, []), (etype, eid, imax))
    end

    # Lines
    linecodes = get(net′, "linecode", Dict())
    for (lid, l) in lines
        l isa Dict || continue
        lc    = get(linecodes, string(get(l, "linecode", "")), Dict())
        imax  = _element_i_max(l, lc)
        bf    = get(l, "bus_from", nothing)
        bt    = get(l, "bus_to",   nothing)
        bf isa String && _add_adj!(bf, :line, lid, imax)
        bt isa String && _add_adj!(bt, :line, lid, imax)
    end

    # Switches
    for (sid, sw) in switches
        sw isa Dict || continue
        imax = _element_i_max(sw, Dict())
        bf   = get(sw, "bus_from", nothing)
        bt   = get(sw, "bus_to",   nothing)
        bf isa String && _add_adj!(bf, :switch, sid, imax)
        bt isa String && _add_adj!(bt, :switch, sid, imax)
    end

    # Transformers — derive i_max from s_rating and v_nom
    for (_, xfmr_sub) in get(net′, "transformer", Dict())
        xfmr_sub isa Dict || continue
        for (tid, xfmr) in xfmr_sub
            xfmr isa Dict || continue
            s_rating = get(xfmr, "s_rating", nothing)
            s_rating isa Number || continue
            for (side, vref_key, bus_key) in (
                    ("from", "v_nom_from", "bus_from"),
                    ("to",   "v_nom_to",   "bus_to"))
                vref = get(xfmr, vref_key, nothing)
                bus  = get(xfmr, bus_key, nothing)
                (vref isa Number && bus isa String) || continue
                # i_max = S / (√3 × V_ref) for 3-phase; S / V_ref for 1-phase
                tm = get(xfmr, "terminal_map_$(side)", String[])
                n_phases = length(tm)  # includes neutral for wye
                denom = n_phases >= 3 ? sqrt(3.0) * Float64(vref) : Float64(vref)
                imax  = Float64(s_rating) / denom
                _add_adj!(bus, :transformer, tid, imax)
            end
        end
    end

    # For each line/switch without i_max, find minimum adjacent bound
    for (lid, l) in lines
        l isa Dict || continue
        haskey(l, "i_max") && continue
        _infer_and_write_i_max!(l, :line, lid, adj, entries)
    end
    for (sid, sw) in switches
        sw isa Dict || continue
        haskey(sw, "i_max") && continue
        _infer_and_write_i_max!(sw, :switch, sid, adj, entries)
    end
end

function _element_i_max(el::Dict, lc::Dict)::Union{Float64,Nothing}
    # Per-element override takes priority
    v = get(el, "i_max", nothing)
    v !== nothing && return Float64(minimum(Float64.(v isa AbstractVector ? v : [v])))
    # Fall back to linecode
    v = get(lc, "i_max", nothing)
    v !== nothing && return Float64(minimum(Float64.(v isa AbstractVector ? v : [v])))
    nothing
end

function _infer_and_write_i_max!(el, etype, eid, adj, entries)
    bf = get(el, "bus_from", nothing)
    bt = get(el, "bus_to",   nothing)
    neighbours = vcat(
        get(adj, bf isa String ? bf : "", []),
        get(adj, bt isa String ? bt : "", []),
    )
    # Collect bounds from adjacent elements, excluding self
    bounds = Float64[]
    sources = String[]
    for (ntype, nid, nimax) in neighbours
        (ntype == etype && nid == eid) && continue   # skip self
        nimax === nothing && continue
        push!(bounds, nimax)
        push!(sources, "$(ntype)/$(nid)")
    end

    # Nothing was written when no neighbour carries a bound — do not record a
    # change entry for a no-op (it would over-count changes in the manifest).
    isempty(bounds) && return

    derived = minimum(bounds)
    # i_max is per-conductor in the data model (and the solution checker only
    # honours vectors) — apply the bound uniformly across the conductors.
    n_cond = length(get(el, "terminal_map_from", String[]))
    el["i_max"] = fill(derived, max(n_cond, 1))
    push!(entries, TransformEntry(
        etype, eid, "i_max", nothing, derived,
        "adjacent_current_bound+IEC60076-7", :medium,
        "min of adjacent bounds $(round.(bounds, sigdigits=4)) A " *
        "from [$(join(sources, ", "))]"))
end

# Pass 7: high-admittance grounding shunts → perfectly_grounded_terminals
function _fix_perfect_grounding!(net′, entries, threshold_ohm)
    shunts = get(net′, "shunt", Dict())
    buses  = get(net′, "bus",   Dict())

    for id in collect(keys(shunts))
        shunt = shunts[id]
        shunt isa Dict || continue
        bus_id = get(shunt, "bus", nothing)
        bus_id isa String || continue
        tm = string.(get(shunt, "terminal_map", String[]))
        isempty(tm) && continue

        # Accept only 1-terminal shunts for safety.
        length(tm) == 1 || continue
        g11 = get(shunt, "G_1_1", nothing)
        g11 isa Number || continue
        b11 = Float64(get(shunt, "B_1_1", 0.0))
        y_mag = sqrt(Float64(g11)^2 + b11^2)
        y_mag <= 0 && continue

        r_eq = 1.0 / y_mag
        r_eq >= threshold_ohm && continue

        # Promote terminal to perfectly_grounded_terminals
        bus = get(buses, bus_id, nothing)
        bus isa Dict || continue
        grounded = string.(get(bus, "perfectly_grounded_terminals", String[]))
        t = tm[1]
        if t ∉ grounded
            bus["perfectly_grounded_terminals"] = vcat(grounded, [t])
        end
        delete!(shunts, id)

        push!(entries, TransformEntry(
            :shunt, id, "(promoted_to_perfect_grounding)",
            Dict("G_1_1" => g11, "B_1_1" => b11, "|Z_eq|_ohm" => r_eq,
                 "terminal" => t, "bus" => bus_id),
            nothing,
            "perfect_grounding_promotion", :low,
            "|Z_eq| = 1/|Y_11| = $(round(r_eq, sigdigits=3)) Ω < " *
            "threshold $(threshold_ohm) Ω — terminal '$t' on bus '$bus_id' " *
            "promoted to perfectly_grounded_terminals; shunt '$id' removed"))
    end
end

# Fingerprint a purely-capacitive shunt's susceptance matrix `B` (over terminals
# `tm`) into one of the model's capacitor configurations and recover the
# nameplate, or return `nothing` to decline. A capacitor `B` is a sum of
# reciprocal 2-node stamps b·[[1,−1],[−1,1]] (weighted Laplacian / M∆ᵀM∆ form):
# symmetric, diagonal ≥ 0, off-diagonal ≤ 0. Row sums tell the return path —
# zero for an in-map pair stamp, positive (a diagonal residual) for a
# phase-to-ground stamp whose other node is the reference. The physical `B` is
# preserved for any `v_nom`, so the config-appropriate nominal (P-N for WYE /
# SINGLE_PHASE, √3·P-N = L-L for DELTA) is chosen only for nameplate readability.
# Returns `(configuration, terminal_map, q_rated, v_nom)`.
function _fingerprint_capacitor_shunt(tm::Vector{String}, B::AbstractMatrix,
                                      bus::Dict, bus_id::String, vmap)
    nb = size(B, 1)
    (nb == length(tm) && nb >= 1) || return nothing
    bscale = max(maximum(abs, B), 1e-30)
    tol = 1e-9  * bscale          # "zero"
    pos = 1e-12 * bscale          # strictly positive
    # capacitor sign pattern: symmetric, diag ≥ 0, off-diag ≤ 0
    maximum(abs.(B .- transpose(B))) <= tol || return nothing
    all(B[i, i] >= -tol for i in 1:nb) || return nothing
    all(B[i, j] <= tol for i in 1:nb, j in 1:nb if i != j) || return nothing

    vpn = get(vmap, bus_id, nothing)
    (vpn isa Number && vpn > 0) || return nothing
    vpn = Float64(vpn); vll = sqrt(3.0) * vpn

    offmax  = nb <= 1 ? 0.0 : maximum(abs(B[i, j]) for i in 1:nb, j in 1:nb if i != j)
    rowsums = [sum(@view B[i, :]) for i in 1:nb]
    diag    = [B[i, i] for i in 1:nb]
    isneutral(t) = lowercase(t) == "n"

    # ── (A) phase-to-ground: diagonal, positive, no internal coupling ──────────
    if offmax <= tol && all(d -> d > pos, diag)
        any(isneutral, tm) && return nothing          # phases only
        nt = _neutral_terminal(bus)
        grounded = Set(string.(get(bus, "perfectly_grounded_terminals", String[])))
        (nt !== nothing && nt in grounded && !(nt in tm)) || return nothing
        nb == 3 && return ("WYE", vcat(tm, nt), [diag[k] * vpn^2 for k in 1:3], vpn)
        nb == 1 && return ("SINGLE_PHASE", [tm[1], nt], [diag[1] * vpn^2], vpn)
        return nothing                                  # 2- or >3-phase ground bank
    end

    # ── internal returns: zero row sums ───────────────────────────────────────
    all(r -> abs(r) <= tol, rowsums) || return nothing

    if nb == 2
        b = -B[1, 2]
        b > pos || return nothing
        vr = (isneutral(tm[1]) || isneutral(tm[2])) ? vpn : vll
        return ("SINGLE_PHASE", copy(tm), [b * vr^2], vr)

    elseif nb == 4
        # star with a single hub coupling to all others (WYE), hub = neutral
        hub = nothing
        for h in 1:4
            others = [i for i in 1:4 if i != h]
            if all(abs(B[i, j]) <= tol for i in others, j in others if i != j) &&
               all(-B[o, h] > pos for o in others)
                hub = h; break
            end
        end
        (hub !== nothing && isneutral(tm[hub])) || return nothing
        phs = [i for i in 1:4 if i != hub]              # _phase_positions order
        return ("WYE", copy(tm), [(-B[p, hub]) * vpn^2 for p in phs], vpn)

    elseif nb == 3
        # 3-cycle with every phase pair coupled (DELTA); phases only
        any(isneutral, tm) && return nothing
        (-B[1, 2] > pos && -B[2, 3] > pos && -B[1, 3] > pos) || return nothing
        # q_rated[k] ↔ pair (k, k%3+1): (1,2),(2,3),(3,1)
        return ("DELTA", copy(tm),
                [(-B[1, 2]) * vll^2, (-B[2, 3]) * vll^2, (-B[1, 3]) * vll^2], vll)
    end
    return nothing
end

# Pass 8: convert purely-capacitive shunts into first-class `capacitor` objects.
# The shunt's susceptance matrix is fingerprinted into a SINGLE_PHASE / WYE /
# DELTA bank (or a phase-to-ground bank on a grounded neutral); the conversion is
# committed only when the emitted capacitor's `_cap_bmatrix` reproduces the
# shunt's `B` exactly (restricted to the shunt's own terminals — an appended
# grounded neutral is pinned to 0 V and inert), guaranteeing faithfulness. Shunts
# with conductance, a non-capacitor sign pattern, an unsupported structure, or an
# undeterminable nominal are left untouched.
function _fix_shunt_to_capacitor!(net′, entries)
    shunts = get(net′, "shunt", nothing)
    (shunts isa Dict && !isempty(shunts)) || return
    buses = get(net′, "bus", Dict())
    vmap  = get(voltage_level_analysis(net′, Finding[]), "bus_voltage_map",
                Dict{String,Float64}())
    caps  = get!(net′, "capacitor", Dict{String,Any}())

    for (id, s) in collect(shunts)
        s isa Dict || continue
        bus_id = string(get(s, "bus", ""))
        bus = get(buses, bus_id, nothing)
        bus isa Dict || continue
        tm = Vector{String}(string.(get(s, "terminal_map", String[])))
        isempty(tm) && continue

        B = _pattern_keys_to_matrix(s, "B_")
        B isa AbstractMatrix || continue
        size(B, 1) == length(tm) || continue
        G = _pattern_keys_to_matrix(s, "G_")
        bscale = max(maximum(abs, B), 1e-30)
        # purely capacitive: negligible conductance
        (G isa AbstractMatrix ? maximum(abs, G) : 0.0) <= 1e-9 * bscale || continue

        fp = _fingerprint_capacitor_shunt(tm, B, bus, bus_id, vmap)
        fp === nothing && continue
        cfg, cap_tm, q, v_nom = fp

        # Round-trip guard: the candidate must reproduce B on the shunt's terminals.
        cand = Dict{String,Any}("bus" => bus_id, "terminal_map" => cap_tm,
                                "configuration" => cfg, "v_nom" => v_nom,
                                "q_rated" => q)
        tm2, B2 = _cap_bmatrix(cand)
        idx = [findfirst(==(t), tm2) for t in tm]
        any(isnothing, idx) && continue
        maximum(abs.(B2[idx, idx] .- B)) <= 1e-7 * bscale || continue

        new_id = _unique_id(caps, "cap_$(id)")
        caps[new_id] = cand
        delete!(shunts, id)
        push!(entries, TransformEntry(
            :shunt, id, "(converted_to_capacitor)",
            Dict("bus" => bus_id, "terminal_map" => tm),
            Dict("capacitor" => new_id, "configuration" => cfg,
                 "q_rated" => q, "v_nom" => v_nom),
            "shunt_to_capacitor", :heuristic,
            "purely-capacitive shunt '$id' → $cfg capacitor '$new_id' " *
            "(q_rated = B·v_nom², v_nom = $(round(v_nom, digits=1)) V); " *
            "B reproduced exactly; shunt removed"))
    end
    isempty(caps) && delete!(net′, "capacitor")
end

# Pass 9: snap a transformer's tiny placeholder leakage to exactly zero. A small
# non-zero series impedance (typically carried over from an admittance-based tool
# that forbids exact zero) ill-conditions the IVR winding voltage-drop equation,
# whereas exact zero collapses to the well-posed ideal constraint V_fr = N·V_to.
# Only acts when the per-unit |Z| on the from-side rating base is non-zero and
# below `z_min_pu` (real units are 1–15 %, so genuine values are never touched),
# and only on the two-winding subtypes where the rating base is well-defined.
const _XFMR_2WINDING_SUBTYPES = ("single_phase", "center_tap", "wye_delta", "delta_wye")

function _fix_snap_transformer_impedance!(net′, entries, z_min_pu)
    xfmr = get(net′, "transformer", Dict())
    zkeys = ("r_series_from", "x_series_from", "r_series_to", "x_series_to",
             "r_series", "x_series")
    for subtype in _XFMR_2WINDING_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            t isa Dict || continue
            xvals = Float64[Float64(t[k]) for k in
                            ("x_series_from", "x_series_to", "x_series") if haskey(t, k)]
            isempty(xvals) && continue
            rvals = Float64[Float64(t[k]) for k in
                            ("r_series_from", "r_series_to", "r_series") if haskey(t, k)]
            X = sum(abs, xvals)
            R = isempty(rvals) ? 0.0 : sum(abs, rvals)
            zpu = _xfmr_z_pu(t, R, X)
            (zpu !== nothing && 0 < zpu < z_min_pu) || continue

            old = Dict{String,Any}(k => t[k] for k in zkeys if haskey(t, k))
            for k in zkeys
                haskey(t, k) && (t[k] = 0.0)
            end
            push!(entries, TransformEntry(
                :transformer, id, "(series_impedance_zeroed)",
                old, Dict(k => 0.0 for k in keys(old)),
                "snap_transformer_impedance", :heuristic,
                "$subtype transformer '$id' had placeholder leakage |Z|≈" *
                "$(round(zpu, sigdigits=2)) pu < $(z_min_pu) pu — snapped to exactly " *
                "zero (well-posed ideal transformer in the IVR formulation)"))
        end
    end
end
