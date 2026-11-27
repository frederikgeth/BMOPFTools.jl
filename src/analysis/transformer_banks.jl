# analysis/transformer_banks.jl
#
# Single-phase transformer banks: which units on one secondary bus form one
# bank (`_transformer_bank_groups`), where each unit's primary is supplied
# from (`_supply_point`, on `_conductor_groups`), and which power units of a
# bank are the high leg of a four-wire delta (`_high_leg_banks`).
#
# Consumers: the voltage-level pass (level propagation, ratio checks), the
# connectivity pass (branch counts, supplied phases) and the switch scenarios.

"""
    _transformer_bank_groups(net) -> (merged, groups)

Resolve, per ordered `(bus_from, bus_to)` pair, which single-phase units form
one bank. Primary buses joined by closed switches are one supply point (a
primary disconnect does not split a bank); `bus_from` in a group is that
supply point's canonical bus. The whole pair is resolved before anything is counted, and the result
does not depend on component ids:

- center-tapped units come first (the lighting transformer anchors its bank),
  then units are ordered by their secondary phase-conductor set (smaller first);
- a unit is a **leg** when its set neither contains nor is contained in the set
  of a leg already taken; otherwise it is **parallel** to the bank;
- a unit whose maps cannot be read is **unassessed** and stays its own branch.

Among units with identical sets one is a leg and the rest are parallel, so the
count is the same whichever id sorts first. `groups` reports `units` (the legs),
`parallel_units`, `unassessed_units`, and `ambiguous`, which is true when a unit
partly overlaps the legs (for example `a–b` beside `a–n` and `b–n`): the
grouping is then one reading of the data, recorded rather than hidden.
`merged` holds the `(subtype, id)` of every leg beyond the first of its bank:
the branches a bus graph must not count separately.
"""
function _transformer_bank_groups(net)
    Unit = Tuple{String,String}
    merged = Set{Unit}()
    groups = Dict{String,Any}[]
    undetermined = Dict{String,Any}[]
    membership = Dict{Unit,Tuple{Vector{String},String}}()
    undetermined_pairs = Set{Tuple{Unit,Unit}}()
    result() = (merged=merged, groups=groups, undetermined=undetermined,
                membership=membership, undetermined_pairs=undetermined_pairs)
    xfmr = get(net, "transformer", Dict())
    xfmr isa AbstractDict || return result()
    roles = _index_roles(net)
    neutrals = roles === nothing ? nothing : roles.neutral
    by_secondary = Dict{String,Vector{Any}}()
    supply = _supply_point(net)
    for subtype in _BANKABLE_SUBTYPES
        sub = get(xfmr, subtype, nothing)
        sub isa AbstractDict || continue
        for (id, t) in sub
            t isa AbstractDict || continue
            bf = get(t, "bus_from", nothing); bt = get(t, "bus_to", nothing)
            bf isa AbstractString && bt isa AbstractString && bf != bt || continue
            tf = get(t, "terminal_map_from", nothing)
            reach = supply.reach(String(bf), tf)
            String(bt) in reach && continue
            push!(get!(by_secondary, String(bt), Any[]),
                  (subtype=subtype, id=string(id), sig=_bank_unit_signature(t, neutrals),
                   bus=String(bf), terminals=tf, reach=reach))
        end
    end
    note_undetermined!(bt, a, b, reason) = begin
        x, y = sort!([a, b], by = u -> (u.subtype, u.id))
        push!(undetermined_pairs, ((x.subtype, x.id), (y.subtype, y.id)))
        push!(undetermined, Dict{String,Any}("bus_to" => bt, "units" => sort!([a.id, b.id]),
            "primary_buses" => sort!(unique!([a.bus, b.bus])), "reason" => reason))
    end
    for bt in sort!(collect(keys(by_secondary)))
        all_units = sort!(by_secondary[bt], by = u -> (u.subtype, u.id))
        # Units that share a supply point: some bus at which both windings are
        # wholly present. Components of that relation are candidate banks.
        # Each set's root is its lowest index (the larger root goes under the
        # smaller), so banks come out in the order of their first unit.
        component = _DisjointSets(1:length(all_units))
        root(i) = _ds_find!(component, i)
        for i in 1:length(all_units), j in i+1:length(all_units)
            isempty(intersect(all_units[i].reach, all_units[j].reach)) && continue
            ri, rj = root(i), root(j)
            ri == rj || _ds_union!(component, max(ri, rj), min(ri, rj))
        end
        banks = Vector{Any}[]
        for r in unique(root.(1:length(all_units)))
            members = [all_units[i] for i in 1:length(all_units) if root(i) == r]
            common = sort!(collect(intersect((u.reach for u in members)...)))
            if isempty(common)
                # A chain: each unit shares a bus with the next, but no bus
                # holds them all. Not one supply point; left as separate units.
                for i in 1:length(members), j in i+1:length(members)
                    note_undetermined!(bt, members[i], members[j], "no_common_supply_point")
                end
                for u in members; push!(banks, Any[[u], u.reach]); end
            else
                push!(banks, Any[members, common])
            end
        end
        for (units, common) in banks, u in units
            membership[(u.subtype, u.id)] = (common, bt)
        end
        # Units in different banks whose primaries are joined on some but not
        # all of a winding's conductors: not grouped, and not known to be separate.
        for x in 1:length(banks), y in x+1:length(banks), a in banks[x][1], b in banks[y][1]
            (supply.partial(a.bus, a.terminals, b.bus) || supply.partial(b.bus, b.terminals, a.bus)) || continue
            ((a.subtype, a.id), (b.subtype, b.id)) in undetermined_pairs && continue
            ((b.subtype, b.id), (a.subtype, a.id)) in undetermined_pairs && continue
            note_undetermined!(bt, a, b, "partial_primary_tie")
        end
        for (units, common) in banks
            length(units) > 1 || continue
            # A center-tapped unit is identified as a bank's lighting transformer
            # by its subtype, so it anchors the bank: a unit across one of its legs
            # is the parallel one, not the other way around.
            assessed = sort!([u for u in units if u.sig !== nothing],
                             by = u -> (u.subtype != "center_tap", length(u.sig),
                                        sort!(collect(u.sig)), u.subtype, u.id))
            legs = eltype(assessed)[]; parallel = eltype(assessed)[]; ambiguous = false
            for u in assessed
                clash = [l for l in legs if issubset(u.sig, l.sig) || issubset(l.sig, u.sig)]
                if isempty(clash)
                    push!(legs, u)
                else
                    push!(parallel, u)
                    any(l -> l.sig != u.sig, clash) && (ambiguous = true)
                end
            end
            for l in legs[2:end]
                push!(merged, (l.subtype, l.id))
            end
            push!(groups, Dict{String,Any}("bus_from" => first(common), "supply_buses" => common, "bus_to" => bt,
                "units" => sort!([l.id for l in legs]),
                "parallel_units" => sort!([u.id for u in parallel]),
                "unassessed_units" => sort!([u.id for u in units if u.sig === nothing]),
                "ambiguous" => ambiguous,
                "n_branches" => (isempty(legs) ? 0 : 1) + length(parallel) +
                                count(u -> u.sig === nothing, units)))
        end
    end
    sort!(groups, by = g -> (g["supply_buses"], g["bus_to"]))
    result()
end

# Conductors as a union-find over (bus, terminal) nodes: two nodes are one
# conductor when a branch of one of the given `kinds` maps them onto each
# other (position k of `terminal_map_from` onto position k of
# `terminal_map_to`). Open switches join nothing. This is the one place the
# profiler follows a conductor from bus to bus; labels are never compared.
# Returns `(find, parent)`: `find(node)` is the group's representative, and
# `parent` holds every node a branch touched.
function _conductor_groups(net; kinds=("line", "switch"))
    conductors = _DisjointSets{Tuple{String,String}}()
    find(x) = _ds_find!(conductors, x)
    for kind in kinds
        table = get(net, kind, nothing)
        table isa AbstractDict || continue
        for (_, c) in table
            c isa AbstractDict || continue
            kind == "switch" && get(c, "open_switch", false) === true && continue
            a = get(c, "bus_from", nothing); b = get(c, "bus_to", nothing)
            tf = get(c, "terminal_map_from", nothing); tt = get(c, "terminal_map_to", nothing)
            a isa AbstractString && b isa AbstractString && tf isa AbstractVector && tt isa AbstractVector ||
                continue
            for k in 1:min(length(tf), length(tt))
                tf[k] isa AbstractString && tt[k] isa AbstractString || continue
                _ds_union!(conductors, (String(a), String(tf[k])), (String(b), String(tt[k])))
            end
        end
    end
    (find, conductors.parent)
end

# Conductor-level evidence of where a transformer's primary winding is
# supplied from, for deciding whether units on different primary buses are one
# bank.
#
# Conductors are followed through closed switches only, terminal by terminal,
# by the switch's own terminal maps (a label may change across a switch; the
# conductor does not). A winding's **supply point** is the set of buses at
# which EVERY one of its primary terminals, the neutral included, is present
# on the same conductors. Two units share a supply point when those sets have
# a bus in common: a bus at which both windings are wholly present. Units on
# one bus always do, whatever else their conductors reach, and a full primary
# disconnect between two units leaves the bank what it was.
#
# Anything less is not grouped. A tie that carries some but not all of a
# winding's conductors (one phase of two, the phases without the neutral) is a
# **partial** tie: the units stay separate branches and the pair is reported as
# undetermined. A tie on conductors neither winding uses, or a neutral bond
# alone, is no evidence at all.
#
# The result does not depend on bus names, switch direction or terminal
# labels: it is built from conductor groups, never from a representative bus.
function _supply_point(net)
    Node = Tuple{String,String}
    find, parent = _conductor_groups(net; kinds=("switch",))
    buses_of = Dict{Node,Set{String}}()            # conductor group => buses it is present at
    for n in collect(keys(parent)); push!(get!(buses_of, find(n), Set{String}()), n[1]); end
    roles = _index_roles(net)
    is_return(x) = _is_return_label(roles, x)
    readable(terminals) = terminals isa AbstractVector && !isempty(terminals) &&
        all(x -> x isa AbstractString, terminals)
    present(bus, t) = haskey(parent, (bus, t)) ? buses_of[find((bus, t))] : Set{String}((bus,))
    # Sorted list of the buses every primary terminal of the winding reaches.
    function reach(bus::AbstractString, terminals)
        bus = String(bus)
        (isempty(parent) || !readable(terminals)) && return [bus]
        sort!(collect(intersect((present(bus, String(t)) for t in terminals)...)))
    end
    # True when a PHASE conductor of the winding at `bus` is present at
    # `other`. Asked about two units that share no supply point: one crossing
    # phase conductor then makes the pair a partial tie.
    function partial(bus::AbstractString, terminals, other::AbstractString)
        bus = String(bus); other = String(other)
        (isempty(parent) || !readable(terminals) || bus == other) && return false
        any(t -> !is_return(t) && other in present(bus, String(t)), terminals)
    end
    (reach=reach, partial=partial)
end

# Single-phase unit subtypes that are banked in practice.
const _BANKABLE_SUBTYPES = ("single_phase", "center_tap")

# Secondary PHASE conductors of one unit (its neutral is shared by every leg of
# a bank and says nothing about which leg the unit is). Two units between the
# same bus pair are legs of one bank when neither's phase set contains the
# other's. A unit across conductors another unit already spans — the same
# pair, or the two legs of a center-tapped winding — is paralleled there,
# whatever its primary connection, and closes a loop.
function _bank_unit_signature(t, neutral_labels=nothing)
    f = get(t, "terminal_map_from", nothing); to = get(t, "terminal_map_to", nothing)
    f isa AbstractVector && to isa AbstractVector || return nothing
    all(x -> x isa AbstractString, to) || return nothing
    sig = Set{String}(string(x) for x in to if !_is_neutral_label(neutral_labels, string(x)))
    isempty(sig) ? nothing : sig
end

const _HighLegRecord = NamedTuple{(:id, :bus_from, :bus_to, :lighting, :high, :status, :amplitude_ratio, :amplitude_range),
                                  Tuple{String,String,String,String,Vector{String},String,Union{Float64,Nothing},
                                        Union{Tuple{Float64,Float64},Nothing}}}

# High-leg (four-wire) delta: a center-tapped lighting unit and a phase-to-phase
# power unit land on the same secondary bus and close an open delta. The center
# tap fixes the per-conductor reference (the two legs); the third conductor, the
# high leg, sits at √3 times that to neutral, so no single per-conductor nominal
# describes the bus through the power unit.
#
# Secondary maps and turns ratios do not establish that geometry: it depends on
# the relative phasors of the two PRIMARY windings. With nominal primary
# phasors p₁ (lighting) and p₂ (power), unit directions u = p/|p|, and leg
# level L, the model's winding polarity (secondary first-minus-second terminal
# in phase with primary first-minus-second) gives the legs at ±L·u₁ and the
# new conductor at V_shared ∓ 2L·u₂. That is a high leg only when its
# magnitude is √3·L: primaries on the same conductors give 3L, a line-to-neutral
# beside a line-to-line primary gives about 2.9L. The power unit's own voltage
# rating is deliberately not used here; `_check_high_leg_ratio` checks it.
#
# Returns one record per identified power unit, resolved once per network:
# `(id, bus_from, bus_to, lighting, high, status, amplitude_ratio,
# amplitude_range)`. `amplitude_range` is set when a unit of the bank has a
# free tap (`tap_min < tap_max`): the status then holds for every tap position
# in the bounds, or is "unverified" when the positions disagree. A unit
# whose primaries point the right way but whose secondary amplitude is not the
# bank's line-to-line voltage has status "amplitude_mismatch": it is not a
# high leg, it is kept out of level propagation, and the ratio check reports it. `status` is "verified", or
# "unverified" when the primary phasors are not established: no voltage source
# declares the angle of the conductor each winding terminal is on, as followed
# through the terminal maps of lines and closed switches. Phase labels are
# never taken as evidence of an angle. An
# unverified unit is kept out of level propagation rather than raised as a
# false conflict, is reported with that status, and is not called a high leg.
function _high_leg_banks(net::Dict{String,Any})
    out = _HighLegRecord[]
    xfmr = get(net, "transformer", Dict())
    xfmr isa AbstractDict || return out
    ct = get(xfmr, "center_tap", nothing); sp = get(xfmr, "single_phase", nothing)
    ct isa AbstractDict && sp isa AbstractDict || return out
    # The two units of a bank share a primary supply point, not necessarily a
    # bus id: a primary disconnect (a closed switch) between them leaves the
    # bank what it was. Primary buses are compared up to the closed switches
    # that carry each winding's phase conductors (`_supply_point`).
    banks = _transformer_bank_groups(net)
    bank_of(subtype, id, f, b) = get(banks.membership, (subtype, string(id)), ([String(f)], String(b)))
    lighting = _lighting_units(ct, bank_of)
    isempty(lighting) && return out

    roles = _index_roles(net)
    is_return(x) = _is_return_label(roles, x)
    # Conductor phasors are traced once, and only when a unit needs them.
    phasors = nothing
    function phasor(bus, t)
        phasors === nothing && (phasors = _conductor_phasors(net, is_return))
        phasors((String(bus), String(t)))
    end

    for id in sort!(collect(keys(sp)))
        t = sp[id]
        t isa AbstractDict || continue
        f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
        f isa AbstractString && b isa AbstractString || continue
        tm = get(t, "terminal_map_to", nothing); tf = get(t, "terminal_map_from", nothing)
        _high_leg_strings(tf, 2) || continue
        units = get(lighting, bank_of("single_phase", id, f, b), nothing)
        if units === nothing
            record = _undetermined_high_leg(t, id, f, b, lighting, banks, is_return)
            record === nothing || push!(out, record)
            continue
        end
        _high_leg_strings(tm, 2) && _high_leg_strings(tf, 2) || continue
        to = string.(tm)
        any(is_return, to) && continue                 # the power unit is phase-to-phase
        for u in units
            record = _classify_high_leg(u, id, f, b, t, tf, to, ct, phasor)
            record === nothing && continue
            push!(out, record)
            break
        end
    end
    out
end

_high_leg_strings(tm, n) = tm isa AbstractVector && length(tm) == n && all(x -> x isa AbstractString, tm)

# Center-tapped (lighting) units by bank key `(supply buses, bus_to)`.
function _lighting_units(ct::AbstractDict, bank_of)
    lighting = Dict{Tuple{Vector{String},String},Vector{Any}}()
    for id in sort!(collect(keys(ct)))
        t = ct[id]
        t isa AbstractDict || continue
        f = get(t, "bus_from", nothing); b = get(t, "bus_to", nothing)
        tm = get(t, "terminal_map_to", nothing); tf = get(t, "terminal_map_from", nothing)
        f isa AbstractString && b isa AbstractString && _high_leg_strings(tm, 3) && _high_leg_strings(tf, 2) || continue
        push!(get!(lighting, bank_of("center_tap", id, f, b), Any[]),
              (id=string(id), to=string.(tm), from=string.(tf), bus_from=String(f)))
    end
    lighting
end

# A lighting unit on the same secondary bus whose primary is joined to this
# power unit's on some conductors only: neither one bank nor known to be two.
# Reported, and kept out of level propagation like any unit whose bank cannot
# be established. Returns the record, or `nothing`.
function _undetermined_high_leg(t, id, f, b, lighting, banks, is_return)
    tm2 = get(t, "terminal_map_to", nothing)
    _high_leg_strings(tm2, 2) && !any(is_return, tm2) || return nothing
    candidates = sort!([u for (key, us) in lighting if key[2] == String(b) for u in us], by = u -> u.id)
    for u in candidates
        (("center_tap", u.id), ("single_phase", string(id))) in banks.undetermined_pairs || continue
        legs = (u.to[1], u.to[3])
        count(x -> x in legs, tm2) == 1 || continue
        return (id=string(id), bus_from=String(f), bus_to=String(b), lighting=u.id,
                high=[String(x) for x in tm2 if !(x in legs)], status="undetermined",
                amplitude_ratio=nothing, amplitude_range=nothing)
    end
    nothing
end

# Nominal phasor of a (bus, terminal): the magnitude and angle a voltage
# source declares for the CONDUCTOR that terminal belongs to, followed through the terminal
# maps of lines and closed switches. Labels are not followed: `pole.b` fed
# from `sub.a` through a mapped conductor carries the angle of `sub.a`,
# and two legs behind another transformer carry none. A conductor that two
# sources declare at different angles is not established either.
#
# Returns a function of a `(bus, terminal)` node: its phasor, or `nothing`
# when it is not established.
function _conductor_phasors(net, is_return)
    Node = Tuple{String,String}
    find, parent = _conductor_groups(net)
    # The declared phasor is magnitude AND angle: a winding across two
    # conductors of unequal magnitude does not point where their angles
    # alone would put it.
    declared = Dict{Node,Vector{ComplexF64}}()
    for (_, vs) in get(net, "voltage_source", Dict())
        vs isa AbstractDict || continue
        sb = get(vs, "bus", nothing); tm = get(vs, "terminal_map", nothing)
        va = get(vs, "v_angle", nothing); vm = get(vs, "v_magnitude", nothing)
        sb isa AbstractString && tm isa AbstractVector && va isa AbstractVector &&
            vm isa AbstractVector || continue
        for (label, magnitude, angle) in zip(tm, vm, va)
            label isa AbstractString && angle isa Real && isfinite(angle) &&
                magnitude isa Real && isfinite(magnitude) && magnitude >= 0 || continue
            push!(get!(declared, find((String(sb), String(label))), ComplexF64[]),
                  Float64(magnitude) * cis(Float64(angle)))
        end
    end
    established = Dict{Node,ComplexF64}()
    for (root, values) in declared
        ref = first(values)
        all(v -> abs(v - ref) <= 1e-6 * max(abs(ref), 1.0), values) && (established[root] = ref)
    end
    # A conductor no source declares is at zero only when something
    # holds it there exactly: one of its terminals is a return terminal
    # that is perfectly grounded or on a source bus. The label alone
    # decides nothing: a terminal called `n` that a line maps onto a
    # source phase carries that phase, and an `n` that reaches no such
    # point has no established voltage. A shunt to earth is a path,
    # not a voltage: an electrode carries the primary return current,
    # and a shunt may couple the neutral to a phase as well.
    members = Dict{Node,Vector{Node}}()
    for n in collect(keys(parent)); push!(get!(members, find(n), Node[]), n); end
    source_buses = Set{String}(String(vs["bus"]) for (_, vs) in get(net, "voltage_source", Dict())
                               if vs isa AbstractDict && get(vs, "bus", nothing) isa AbstractString)
    pinned(n) = is_return(n[2]) && (n[1] in source_buses || begin
        b = get(get(net, "bus", Dict()), n[1], nothing)
        g = b isa AbstractDict ? get(b, "perfectly_grounded_terminals", nothing) : nothing
        g isa AbstractVector && n[2] in g
    end)
    n -> begin
        root = find(n)
        haskey(declared, root) && return get(established, root, nothing)
        group = get(members, root, [n])
        any(pinned, group) ? 0.0 + 0.0im : nothing
    end
end

# Phasor across a winding's two terminals, or nothing when it is not
# established. Both terminals at the same phasor (one source conductor on
# both ends) is an established result: exactly zero, with no direction.
function _winding_phasor(phasor, bus, tm)
    a = phasor(bus, tm[1]); b = phasor(bus, tm[2])
    (a === nothing || b === nothing) && return nothing
    p = a - b
    scale = max(abs(a), abs(b))
    scale > 0 && abs(p) > 1e-6 * scale ? p : zero(p)
end

# Secondary volts per primary volt as the solver builds the unit: the
# nameplate ratio N0 = v_nom_from / v_nom_to times the `tap` multiplier is
# the from-to ratio, for single_phase and center_tap alike. With
# `tap_min < tap_max` the solver frees the tap within those bounds and
# `tap` is only its start, clamped into them: the ratio is then a range.
# Returns `(lo, hi, at)`, `at` being the ratio at the (clamped) `tap`.
function _unit_ratio_range(t)
    vf = get(t, "v_nom_from", nothing); vt = get(t, "v_nom_to", nothing)
    tap = get(t, "tap", 1.0)
    ok(x) = x isa Real && isfinite(x) && x > 0
    ok(vf) && ok(vt) && ok(tap) || return nothing
    at(x) = Float64(vt) / (Float64(vf) * Float64(x))
    haskey(t, "tap_min") && haskey(t, "tap_max") || return (at(tap), at(tap), at(tap))
    tlo = t["tap_min"]; thi = t["tap_max"]
    tlo isa Real && thi isa Real && isfinite(tlo) && isfinite(thi) || return nothing
    tlo < thi || return (at(tap), at(tap), at(tap))
    tlo > 0 || return nothing
    (at(thi), at(tlo), at(clamp(tap, tlo, thi)))
end

# The verdict on power unit `id` (secondary conductors `to`) against lighting
# unit `u`. Returns `nothing` when the two are not a candidate pair (the next
# lighting unit is tried), otherwise the record.
function _classify_high_leg(u, id, f, b, t, tf, to, ct, phasor)
    legs = (u.to[1], u.to[3])
    shared = [x for x in to if x in legs]; fresh = [x for x in to if !(x in legs)]
    # One end on a leg, the other on a new conductor: a unit across the
    # two legs is paralleled with the lighting winding instead.
    length(shared) == 1 && length(fresh) == 1 || return nothing
    record(status, amplitude, range=nothing) = (id=string(id), bus_from=String(f), bus_to=String(b),
        lighting=u.id, high=fresh, status=status, amplitude_ratio=amplitude, amplitude_range=range)
    p1 = _winding_phasor(phasor, u.bus_from, u.from); p2 = _winding_phasor(phasor, String(f), string.(tf))
    r1 = _unit_ratio_range(get(ct, u.id, Dict())); r2 = _unit_ratio_range(t)
    if p1 === nothing || p2 === nothing || r1 === nothing || r2 === nothing || iszero(p1)
        return record("unverified", nothing)
    end
    if iszero(p2)
        # The power winding's primary is fed from one conductor on
        # both ends: no voltage across it, so none on its secondary,
        # at any tap. The delta cannot close; the ratio check reports it.
        return record("amplitude_mismatch", 0.0)
    end
    # Secondary voltages as the declared ratios make them from the
    # traced primary phasors: the legs at ±leg, the power winding at
    # `across`. The delta closes only if both the direction and the
    # amplitude of the power winding fit.
    leg = r1[3] * p1; across = r2[3] * p2
    placed(a) = (v_shared = shared[1] == legs[1] ? leg : -leg;
                 to[1] == shared[1] ? v_shared - a : v_shared + a)
    fits(a) = abs(abs(placed(a)) / (sqrt(3.0) * abs(leg)) - 1) <= 0.1
    amplitude = abs(across) / (2 * abs(leg))
    # Two independent conditions. Geometry: with the bank's own
    # line-to-line amplitude the primaries' directions put the third
    # conductor at sqrt(3) times the leg. Amplitude: this winding's
    # secondary is that line-to-line voltage. Testing only the
    # resulting magnitude would accept in-phase primaries whose
    # winding happens to add up to the same number.
    geometry = fits(2 * abs(leg) * across / abs(across))
    geometry || return nothing
    # The amplitude over every tap position the solver may take. With
    # fixed taps the range is the one value.
    free = r1[1] < r1[2] || r2[1] < r2[2]
    base = abs(p2) / (2 * abs(p1))
    lo = base * r2[1] / r1[2]; hi = base * r2[2] / r1[1]
    range = free ? (lo, hi) : nothing
    if abs(lo - 1) <= 0.1 && abs(hi - 1) <= 0.1
        record("verified", amplitude, range)
    elseif hi < 0.9 || lo > 1.1
        # Right direction, wrong amplitude at every tap position: the
        # primaries would close a delta, but this unit's secondary
        # voltage is not the bank's line-to-line voltage (its rating,
        # its tap range, or the magnitude of the phase it is fed
        # from). Not a high leg; the ratio check reports it.
        record("amplitude_mismatch", amplitude, range)
    else
        # A free tap decides: some positions close the delta, others
        # do not. Not certified either way.
        record("unverified", amplitude, range)
    end
end

_high_leg_power_units(net::Dict{String,Any}) = _high_leg_power_units(_high_leg_banks(net))
_high_leg_power_units(banks::AbstractVector)::Set{Tuple{String,String}} =
    Set{Tuple{String,String}}(("single_phase", b.id) for b in banks)
