# Wires-per-voltage-level classification and neutral grounding analysis.
#
# _wires_by_level   — 3-wire vs 4-wire per voltage level; flags likely Kron-reduced LV.
# _grounding_analysis — neutral continuity graph; identifies floating neutral sections.
# _earthing_zones   — TT/TN/IT/MV earthing classification per galvanic island.

# ---------------------------------------------------------------------------
# 2. Wires per voltage level — Kron-reduction likelihood
# ---------------------------------------------------------------------------

function _wires_by_level(net::Dict{String,Any},
                          findings::Vector{Finding},
                          vl::Dict{String,Any})::Dict{String,Any}
    buses = get(net, "bus", Dict())
    out = Dict{String,Any}()
    isempty(buses) && return out

    levels = get(vl, "levels", Dict())

    neutral_of = _bus_neutral_map(buses)

    for (label, info) in levels
        ids = get(info, "buses", String[])
        isempty(ids) && continue
        n_with_n = count(b -> get(neutral_of, b, nothing) !== nothing, ids)
        nominal_v = Float64(get(info, "nominal_v", 0.0))
        is_lv = nominal_v < 1000.0

        # Single-terminal loads without a neutral: implicit ground return
        level_set = Set(ids)
        implicit_loads = String[]
        for (lid, l) in get(net, "load", Dict())
            b = get(l, "bus", "")
            b in level_set || continue
            tm = get(l, "terminal_map", String[])
            nn = get(neutral_of, b, nothing)
            (nn !== nothing && nn in tm) && continue
            length(tm) == 1 && push!(implicit_loads, lid)
        end

        wires = n_with_n == 0           ? "3-wire" :
                n_with_n == length(ids) ? "4-wire" : "mixed"

        out[label] = Dict{String,Any}(
            "nominal_v"               => nominal_v,
            "n_buses"                 => length(ids),
            "n_with_neutral"          => n_with_n,
            "wires"                   => wires,
            "is_lv"                   => is_lv,
            "n_implicit_ground_loads" => length(implicit_loads)
        )

        if is_lv && n_with_n == 0 && length(ids) > 1
            extra = isempty(implicit_loads) ? "" :
                " $(length(implicit_loads)) load(s) connect phase-to-ground, " *
                "corroborating an implicit neutral."
            push!(findings, Finding(INFO, "I.PROV.KRON_LIKELY", :provenance,
                :network, nothing,
                "Voltage level $label is modeled 3-wire, but LV networks are " *
                "physically 4-wire — this level is likely Kron-reduced " *
                "(neutral eliminated assuming a ground path at every bus).$extra",
                Dict{String,Any}("level" => label,
                                 "implicit_ground_loads" => implicit_loads)))
        end
    end

    out
end

# ---------------------------------------------------------------------------
# 3. Neutral grounding — continuity and floating sections
# ---------------------------------------------------------------------------

function _grounding_analysis(net::Dict{String,Any},
                              findings::Vector{Finding})::Dict{String,Any}
    buses = get(net, "bus", Dict())
    neutral_of = _bus_neutral_map(buses)
    nbuses = sort([id for (id, nn) in neutral_of if nn !== nothing])
    res = Dict{String,Any}("n_buses_with_neutral" => length(nbuses))
    if isempty(nbuses)
        res["n_grounding_points"]  = 0
        res["n_neutral_components"] = 0
        res["n_floating"]          = 0
        return res
    end
    nbus_set = Set(nbuses)

    # Does this terminal list reference the bus's neutral?
    uses_neutral(bus, tm) = begin
        nn = get(neutral_of, bus, nothing)
        nn !== nothing && nn in tm
    end

    # Grounding points: perfect grounding, grounding shunt on the neutral,
    # or a voltage source that references the neutral (pins its potential).
    grounded = Set{String}()
    n_perfect = 0
    for (id, b) in buses
        if uses_neutral(id, get(b, "perfectly_grounded_terminals", String[]))
            push!(grounded, id)
            n_perfect += 1
        end
    end
    for comp_type in ("shunt", "voltage_source")
        for (_, c) in get(net, comp_type, Dict())
            b = get(c, "bus", nothing)
            b isa AbstractString || continue
            uses_neutral(b, get(c, "terminal_map", String[])) && push!(grounded, b)
        end
    end
    intersect!(grounded, nbus_set)

    # Neutral continuity graph: branches that carry a neutral conductor on both
    # ends — lines and closed switches, plus the line-to-neutral
    # single_phase_autotransformer (see below). Most transformer windings are
    # galvanically isolated circuits, so the neutral does not continue through them.
    adj = Dict{String,Vector{String}}()
    n_neutral_branches = 0
    for comp_type in ("line", "switch")
        for (_, c) in get(net, comp_type, Dict())
            comp_type == "switch" && get(c, "open_switch", false) && continue
            f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
            (f isa AbstractString && t isa AbstractString) || continue
            (uses_neutral(f, get(c, "terminal_map_from", String[])) &&
             uses_neutral(t, get(c, "terminal_map_to",   String[]))) || continue
            n_neutral_branches += 1
            push!(get!(adj, f, String[]), t)
            push!(get!(adj, t, String[]), f)
        end
    end
    # The single_phase_autotransformer shares one physical neutral bushing across
    # its two sides — the OPF bonds V_fr_n == V_to_n — so the neutral continues
    # through it, but only for a line-to-neutral SVR (both maps reference "n").
    # The open_delta_regulator is line-to-line: its neutral terminal is unused by
    # the device (no from↔to tie in the model), so it is NOT a neutral branch —
    # even though it IS galvanically continuous (see GALVANIC_CONTINUOUS_SUBTYPES).
    # All other subtypes have galvanically isolated windings.
    for (_, c) in get(get(net, "transformer", Dict()),
                      "single_phase_autotransformer", Dict())
        c isa Dict || continue
        f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
        (f isa AbstractString && t isa AbstractString) || continue
        (uses_neutral(f, get(c, "terminal_map_from", String[])) &&
         uses_neutral(t, get(c, "terminal_map_to",   String[]))) || continue
        n_neutral_branches += 1
        push!(get!(adj, f, String[]), t)
        push!(get!(adj, t, String[]), f)
    end
    res["n_neutral_branches"] = n_neutral_branches
    res["n_grounding_points"] = length(grounded)
    res["all_perfectly_grounded"] = n_perfect >= length(nbuses)

    # Buses whose neutral terminal is actually used by a shunt component
    neutral_users = Set{String}()
    for comp_type in ("load", "generator")
        for (_, c) in get(net, comp_type, Dict())
            b = get(c, "bus", nothing)
            b isa AbstractString || continue
            uses_neutral(b, get(c, "terminal_map", String[])) && push!(neutral_users, b)
        end
    end

    if n_neutral_branches == 0
        # The dataset does not model neutral conductors at all — "n" is a
        # local ground reference (Kron-style convention).
        res["n_neutral_components"] = length(nbuses)
        res["n_floating"] = 0
        res["convention"] = "implicit"
        ungrounded_users = sort(collect(setdiff(neutral_users, grounded)))
        if !isempty(ungrounded_users)
            push!(findings, Finding(WARNING, "W.PROV.IMPLICIT_GROUNDING",
                :provenance, :network, nothing,
                "No branch carries a neutral conductor, but " *
                "$(length(ungrounded_users)) bus(es) have components " *
                "referencing terminal 'n' without an explicit grounding — " *
                "the model implicitly assumes every bus is grounded " *
                "(Kron-style convention). Make this assumption explicit.",
                Dict{String,Any}("buses" => ungrounded_users)))
        end
        return res
    end
    res["convention"] = "explicit"

    # Connected components of the neutral graph; each must reach a grounding
    visited = Set{String}()
    n_components = 0
    floating = Vector{Vector{String}}()
    for start in sort(nbuses)
        start in visited && continue
        n_components += 1
        comp = String[]
        queue = String[start]
        push!(visited, start)
        while !isempty(queue)
            b = popfirst!(queue)
            push!(comp, b)
            for nb in get(adj, b, String[])
                (nb in visited || !(nb in nbus_set)) && continue
                push!(visited, nb)
                push!(queue, nb)
            end
        end
        any(b -> b in grounded, comp) || push!(floating, sort(comp))
    end
    res["n_neutral_components"] = n_components
    res["n_floating"]           = length(floating)
    res["floating_components"]  = floating

    for comp in floating
        used = any(b -> b in neutral_users, comp)
        sev  = used ? ERROR : WARNING
        code = used ? "E.PROV.FLOATING_NEUTRAL" : "W.PROV.FLOATING_NEUTRAL"
        push!(findings, Finding(sev, code, :provenance, :bus, nothing,
            "Neutral section spanning $(length(comp)) bus(es) has no path to " *
            "ground$(used ? " and is used by loads/generators — the " *
            "zero-sequence path is undefined (ill-posed for 4-wire analysis)" :
            "") : $(join(comp, ", ")).",
            Dict{String,Any}("buses" => comp, "used" => used)))
    end

    if res["all_perfectly_grounded"] && n_neutral_branches > 0
        push!(findings, Finding(INFO, "I.PROV.KRON_REDUCIBLE", :provenance,
            :network, nothing,
            "Every bus neutral is perfectly grounded (rg = 0): Kron reduction " *
            "is exact, so the explicit neutral conductors are numerically " *
            "redundant — either reduce the model or revisit the perfect-" *
            "grounding assumption.",
            nothing))
    end

    res
end

"""
    _check_ungrounded_wye_neutrals(net, findings)

Info-level note for three-phase wye windings whose neutral (star point) is
brought out at a bus that has neither a perfect ground nor a grounding impedance
on it. A wye star point is the natural earthing point of the winding; if its bus
carries no local ground, the zero-sequence potential is set only by whatever the
neutral conductor reaches elsewhere (if anything) — easy to overlook and often an
omission. Single-phase transformers (connected phase-to-neutral or phase-to-phase)
are exempt: their neutral is a winding terminal, not a three-phase star point, so
the winding must have ≥3 phase conductors to qualify.
"""
function _check_ungrounded_wye_neutrals(net::Dict{String,Any},
                                         findings::Vector{Finding})
    xfmr = get(net, "transformer", Dict())
    isempty(xfmr) && return
    buses = get(net, "bus", Dict())
    neutral_of = _bus_neutral_map(buses)
    # Buses with any neutral-earthing path — perfect ground (|Z|=0), source
    # neutral bond, or a grounding shunt (finite |Z|). Membership = "grounded".
    earth = _bus_neutral_earthing(net, neutral_of)

    for subtype in TRANSFORMER_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (id, t) in sub
            t isa Dict || continue
            for (bk, mk, side) in (("bus_from", "terminal_map_from", "primary"),
                                    ("bus_to",   "terminal_map_to",   "secondary"))
                b = get(t, bk, nothing)
                b isa AbstractString || continue
                tm = Vector{String}(get(t, mk, String[]))
                # Three-phase wye winding with the star point brought out: the
                # neutral is accessible and there are ≥3 phase conductors.
                (_neutral_terminal(tm) !== nothing &&
                 length(_phase_positions(tm)) >= 3) || continue
                haskey(earth, b) && continue   # perfectly or impedance grounded
                push!(findings, Finding(INFO, "I.PROV.WYE_NEUTRAL_UNGROUNDED",
                    :provenance, :transformer, id,
                    "Transformer '$id' ($subtype) brings out a three-phase wye " *
                    "neutral on its $side side at bus '$b', but that bus has no " *
                    "local grounding (no perfect ground and no grounding " *
                    "impedance). The star point's zero-sequence potential is set " *
                    "only by what the neutral conductor reaches elsewhere — add a " *
                    "grounding shunt or perfect ground at '$b' if a local earth " *
                    "was intended.",
                    Dict{String,Any}("bus" => b, "subtype" => subtype,
                                     "side" => side)))
            end
        end
    end
end

# Per-bus neutral terminal name (or nothing), via the convention helper
function _bus_neutral_map(buses)::Dict{String,Union{String,Nothing}}
    Dict{String,Union{String,Nothing}}(
        id => _neutral_terminal(b)
        for (id, b) in buses)
end

# ---------------------------------------------------------------------------
# Galvanic islands (shared with integrity checks)
# ---------------------------------------------------------------------------

"""
Connected components over lines, closed switches, and the galvanically-continuous
transformer subtypes (`single_phase_autotransformer`, `open_delta_regulator`,
listed in `GALVANIC_CONTINUOUS_SUBTYPES`); isolating transformer windings are
galvanic separations. Returns sorted bus-id vectors.
"""
function _galvanic_islands(net::Dict{String,Any})::Vector{Vector{String}}
    busset = Set(keys(get(net, "bus", Dict())))
    adj = Dict{String,Vector{String}}()
    for comp_type in ("line", "switch")
        for (_, c) in get(net, comp_type, Dict())
            comp_type == "switch" && get(c, "open_switch", false) && continue
            f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
            (f isa AbstractString && t isa AbstractString &&
             f in busset && t in busset) || continue
            push!(get!(adj, f, String[]), t)
            push!(get!(adj, t, String[]), f)
        end
    end
    # Regulators (autotransformer / open-delta) do not isolate: both sides stay
    # in one island.
    xfmr = get(net, "transformer", Dict())
    for subtype in GALVANIC_CONTINUOUS_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa Dict || continue
        for (_, c) in sub
            f = get(c, "bus_from", nothing); t = get(c, "bus_to", nothing)
            (f isa AbstractString && t isa AbstractString &&
             f in busset && t in busset) || continue
            push!(get!(adj, f, String[]), t)
            push!(get!(adj, t, String[]), f)
        end
    end
    visited = Set{String}()
    islands = Vector{Vector{String}}()
    for start in sort(collect(busset))
        start in visited && continue
        comp = String[]
        queue = String[start]
        push!(visited, start)
        while !isempty(queue)
            b = popfirst!(queue)
            push!(comp, b)
            for nb in get(adj, b, String[])
                nb in visited && continue
                push!(visited, nb)
                push!(queue, nb)
            end
        end
        push!(islands, sort(comp))
    end
    islands
end

# ---------------------------------------------------------------------------
# Earthing system classification per galvanic island
# ---------------------------------------------------------------------------

# Defaults from config/default.toml [provenance.grounding].
const _EARTH_SOLID_OHM = Float64(_grounding_cfg()["earth_solid_ohm"])     # |Z| below this: "solid"
const _EARTH_T_I_OHM   = Float64(_grounding_cfg()["earth_isolated_ohm"])  # |Z| above this (or absent): isolated (I)

# bus => smallest |Z| of any neutral-earthing path at that bus
function _bus_neutral_earthing(net::Dict{String,Any},
                                neutral_of)::Dict{String,Float64}
    earth = Dict{String,Float64}()
    upd!(b, z) = (earth[b] = min(get(earth, b, Inf), z))
    for (id, b) in get(net, "bus", Dict())
        nn = get(neutral_of, id, nothing)
        nn !== nothing &&
            nn in string.(get(b, "perfectly_grounded_terminals", String[])) &&
            upd!(id, 0.0)
    end
    for (_, vs) in get(net, "voltage_source", Dict())
        b = get(vs, "bus", nothing)
        b isa AbstractString || continue
        nn = get(neutral_of, b, nothing)
        nn !== nothing && nn in string.(get(vs, "terminal_map", String[])) &&
            upd!(b, 0.0)
    end
    for (_, s) in get(net, "shunt", Dict())
        b = get(s, "bus", nothing)
        b isa AbstractString || continue
        nn = get(neutral_of, b, nothing)
        (nn !== nothing && nn in string.(get(s, "terminal_map", String[]))) || continue
        y = complex(Float64(get(s, "G_1_1", 0.0)), Float64(get(s, "B_1_1", 0.0)))
        abs(y) > 0 && upd!(b, abs(1 / y))
    end
    earth
end

"""
Classify the likely earthing system per galvanic island, from the
network-side evidence the data model carries. The protective-earth side of
installations is **not representable** in a power-flow data model, so TT
cannot be distinguished from TN-S when the neutral is earthed at the source
only — the tag is explicit about that ambiguity. MV islands use MV
vocabulary (solidly/impedance-earthed/isolated) instead of TT/TN/IT.
"""
function _earthing_zones(net::Dict{String,Any},
                          vl::Dict{String,Any})::Vector{Dict{String,Any}}
    buses = get(net, "bus", Dict())
    isempty(buses) && return Dict{String,Any}[]
    neutral_of = _bus_neutral_map(buses)
    earth = _bus_neutral_earthing(net, neutral_of)
    vmap  = get(vl, "bus_voltage_map", Dict())

    zones = Dict{String,Any}[]
    for isl in _galvanic_islands(net)
        islset = Set(isl)
        vs_ = [Float64(get(vmap, b, NaN)) for b in isl]
        known = filter(!isnan, vs_)
        vnom = isempty(known) ? NaN : maximum(known)
        is_lv = !isnan(vnom) && vnom < 1000.0
        wires4 = all(get(neutral_of, b, nothing) !== nothing for b in isl)

        # infeed reference points: source buses and in-island wye-winding
        # buses whose map carries the neutral (the star point bond)
        star_buses = String[]
        for (_, vs) in get(net, "voltage_source", Dict())
            b = get(vs, "bus", nothing)
            b isa AbstractString && b in islset && push!(star_buses, b)
        end
        xfmr = get(net, "transformer", Dict())
        for subtype in TRANSFORMER_SUBTYPES
            sub = get(xfmr, subtype, nothing)
            sub isa Dict || continue
            for (_, t) in sub
                for (bk, mk) in (("bus_from", "terminal_map_from"),
                                  ("bus_to",   "terminal_map_to"))
                    b = get(t, bk, nothing)
                    (b isa AbstractString && b in islset) || continue
                    nn = get(neutral_of, b, nothing)
                    nn !== nothing && nn in string.(get(t, mk, String[])) &&
                        push!(star_buses, b)
                end
            end
        end
        star_set = Set(star_buses)
        star_R = isempty(star_buses) ? Inf :
                 minimum(get(earth, b, Inf) for b in star_buses)
        downstream = [b for b in isl if haskey(earth, b) && !(b in star_set)]
        n_down = length(downstream)

        kind = star_R < _EARTH_SOLID_OHM ? "solid" :
               star_R <= _EARTH_T_I_OHM  ? "impedance" : "none"
        rstr = kind == "impedance" ? " (R≈$(round(star_R, sigdigits=2)) Ω)" : ""

        tag = if !is_lv
            kind == "solid"     ? "solidly earthed" :
            kind == "impedance" ? "impedance-earthed$rstr" :
            n_down > 0          ? "earthed downstream only (nonstandard)" :
                                  "isolated"
        elseif kind == "none" && n_down == 0
            "IT (isolated / high-impedance earthed)"
        elseif kind == "none" && n_down > 0
            "nonstandard: neutral earthed downstream only"
        elseif !wires4
            "indeterminate (3-wire / Kron-style implicit grounding)"
        elseif n_down >= 1
            "TN-C-S / multi-earthed (PME/MEN-style)$rstr"
        else
            "TN-S or TT (source-earthed only$rstr — protective-earth side " *
            "not representable in the data model)"
        end

        push!(zones, Dict{String,Any}(
            "buses"              => isl,
            "n_buses"            => length(isl),
            "nominal_v"          => vnom,
            "wires"              => wires4 ? "4-wire" : "≤3-wire",
            "star_earthing"      => kind,
            "star_R_ohm"         => star_R,
            "n_downstream_earths" => n_down,
            "tag"                => tag))
    end
    sort!(zones, by = z -> -(isnan(z["nominal_v"]) ? -Inf : z["nominal_v"]))
    zones
end
