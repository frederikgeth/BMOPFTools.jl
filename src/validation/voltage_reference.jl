# validation/voltage_reference.jl
#
# Which conductors the model ties to the voltage reference. The integrity
# check's island test and its conductor-group test both read
# `_conductor_reference`, so they cannot disagree about what a reference is.
#
# Each element type has its own `_reference_<kind>!` function. Each one adds
# two kinds of evidence to a `_ReferenceEvidence`: ties, which fix the voltage
# difference between two (bus, terminal) nodes, and earths, which fix a node to
# the reference. Every rule reads the element the way the solver's builder
# does; the comments on each function name that builder.

"""
    _unreferenced_conductor_groups(net) -> Vector{Vector{Tuple{String,String}}}

Conductor groups that no element ties to the voltage reference.

A bus-level island test is not enough: an earth shunt on a separately carried
neutral says nothing about delta-connected phases that no element connects to
that neutral. The phases can then shift together without changing any equation.

A *conductor group* is a set of `(bus, terminal)` nodes joined by elements that
fix voltage differences between them: a line or closed switch conductor, a
mutual line-shunt entry, the two ends of an active load, generator or IBR coil
(nonzero demand; bounds and ratings that do not force zero current), the
terminal pairs a capacitor stamps, two shunt terminals with a nonzero
admittance entry between them,
the terminals of one transformer winding side (both sides for the galvanically
continuous subtypes). A group is referenced when one of its nodes is tied to
earth: a perfectly grounded terminal, a voltage-source terminal or the neutral
of a source bus, a shunt or stamped line-shunt row with a nonzero sum, a
transformer neutral impedance, or a coil written against earth (WYE or
one-terminal SINGLE_PHASE with no neutral in its map) whose power is given: a
load coil with nonzero demand, a generator coil with fixed, nonzero output. Declared terminals that no element
touches are not groups (they are `W.INT.UNUSED_BUS_TERMINAL`).
"""
_unreferenced_conductor_groups(net) = _conductor_reference(net).groups

# ── Evidence accumulator ─────────────────────────────────────────────────────

const _RefNode = Tuple{String,String}

struct _ReferenceEvidence
    conductors::_DisjointSets{_RefNode}
    earthed::Set{_RefNode}
end
_ReferenceEvidence() = _ReferenceEvidence(_DisjointSets{_RefNode}(), Set{_RefNode}())

_ref_node(bus, t) = (String(bus), string(t))
_ref_strings(tm) = tm isa AbstractVector && all(x -> x isa AbstractString, tm)
_ref_tie!(ev::_ReferenceEvidence, a::_RefNode, b::_RefNode) = (_ds_union!(ev.conductors, a, b); nothing)
_ref_tie!(ev::_ReferenceEvidence, bus, x, y) = _ref_tie!(ev, _ref_node(bus, x), _ref_node(bus, y))
function _ref_earth!(ev::_ReferenceEvidence, bus, t)
    n = _ref_node(bus, t)
    _ds_find!(ev.conductors, n)
    push!(ev.earthed, n)
    nothing
end
# Every terminal of one map on one bus, tied together.
function _ref_tie_all!(ev::_ReferenceEvidence, bus, tm)
    bus isa AbstractString && _ref_strings(tm) && !isempty(tm) || return
    first_node = _ref_node(bus, tm[1]); _ds_find!(ev.conductors, first_node)
    for t in tm[2:end]; _ref_tie!(ev, first_node, _ref_node(bus, t)); end
end
_ref_table(net, key) = (v = get(net, key, nothing); v isa AbstractDict ? v : Dict{String,Any}())

# ── Admittance blocks: row sums to earth and couplings between terminals ─────

# Relative tolerance, against the block's largest entry, below which a row sum
# or an off-diagonal entry is read as zero.
const _EARTH_TIE_RTOL = 1e-9

# Scale for the tests below, or `nothing` when the block ties nothing at all
# (a non-finite entry, or every entry zero).
function _admittance_scale(Y)
    all(isfinite, Y) || return nothing
    scale = maximum(abs, Y; init=0.0)
    scale > 0 ? scale : nothing
end
# Row `i` has a path to earth: its entries do not cancel.
_row_earths(Y, i, scale)::Bool = abs(sum(Y[i, :])) > _EARTH_TIE_RTOL * scale
# Entry `(i, j)` couples terminal `i` to terminal `j`.
_entry_couples(Y, i, j, scale)::Bool = abs(Y[i, j]) > _EARTH_TIE_RTOL * scale

# Tie and earth what an `n × n` admittance block on `tm` at `bus` stamps.
# `symmetric = false` reads only the upper triangle (line shunts, which the
# builders stamp symmetrically); `true` couples on either triangle (shunts,
# whose G and B keys may be written on one side only).
function _ref_admittance!(ev::_ReferenceEvidence, bus, tm, Y, n; symmetric::Bool)
    scale = _admittance_scale(Y)
    scale === nothing && return
    for i in 1:n
        _row_earths(Y, i, scale) && _ref_earth!(ev, bus, tm[i])
        for j in i+1:n
            (_entry_couples(Y, i, j, scale) || (symmetric && _entry_couples(Y, j, i, scale))) &&
                _ref_tie!(ev, bus, tm[i], tm[j])
        end
    end
end

# ── Coil activity: does a coil carry current at some voltage? ────────────────

_ref_number(v, k) = v isa AbstractVector && k <= length(v) && v[k] isa Real && isfinite(v[k]) ? Float64(v[k]) : nothing

# A load coil carries current when its demand is nonzero.
_load_coil_active(c) = k -> (p = _ref_number(get(c, "p_nom", nothing), k); q = _ref_number(get(c, "q_nom", nothing), k);
                             (p !== nothing && !iszero(p)) || (q !== nothing && !iszero(q)))

# A dispatchable coil (generator or IBR) is forced to zero current when its
# P and Q bounds are both pinned at zero, or when a rating leaves it no
# room at all: an apparent-power or current limit of zero. `whole` reads a
# rating as one number for the device (a single-coil unit, whose current
# is limited by the tightest of its entries).
function _coil_forced_to_zero(c, k; whole::Bool=false)
    pinned(lo, hi) = (a = _ref_number(get(c, lo, nothing), k); b = _ref_number(get(c, hi, nothing), k);
                      a !== nothing && b !== nothing && iszero(a) && iszero(b))
    pinned("p_min", "p_max") && pinned("q_min", "q_max") && return true
    for key in ("s_max", "i_max")
        v = get(c, key, nothing)
        if v isa Real
            isfinite(v) && iszero(v) && return true
        elseif v isa AbstractVector && !isempty(v) && all(x -> x isa Real && isfinite(x), v)
            all(iszero, v) && return true
            whole && key == "i_max" && iszero(minimum(v)) && return true
            !whole && k <= length(v) && iszero(v[k]) && return true
            length(v) == 1 && iszero(v[1]) && return true
        end
    end
    false
end
_generator_coil_active(c) = k -> !_coil_forced_to_zero(c, k)

# A coil written against EARTH is a reference only when its power is given:
# a load always is; a generator only when both P and Q are fixed (and not
# both zero). With a dispatch range, a common shift of the terminal
# voltages is absorbed by the output instead of being pinned.
function _generator_coil_pins(c)
    fixed(lo, hi, k) = (a = _ref_number(get(c, lo, nothing), k); b = _ref_number(get(c, hi, nothing), k);
                        a !== nothing && b !== nothing && a == b ? a : nothing)
    k -> (p = fixed("p_min", "p_max", k); q = fixed("q_min", "q_max", k);
          p !== nothing && q !== nothing && !(iszero(p) && iszero(q)))
end

# ── One function per element type ────────────────────────────────────────────

function _reference_buses!(ev, net)
    for (id, b) in _ref_table(net, "bus")
        b isa AbstractDict || continue
        pg = get(b, "perfectly_grounded_terminals", nothing)
        _ref_strings(pg) && foreach(t -> _ref_earth!(ev, id, t), pg)
    end
end

function _reference_voltage_sources!(ev, net)
    buses = _ref_table(net, "bus")
    roles = _index_roles(net)
    for (_, vs) in _ref_table(net, "voltage_source")
        vs isa AbstractDict || continue
        b = get(vs, "bus", nothing); tm = get(vs, "terminal_map", nothing)
        b isa AbstractString && _ref_strings(tm) || continue
        foreach(t -> _ref_earth!(ev, b, t), tm)
        # The solver pins the neutral of a source bus to the reference.
        bus = get(buses, b, nothing)
        nt = bus isa Dict{String,Any} && roles !== nothing ? _declared_bus_neutral(roles, bus) : nothing
        nt === nothing || _ref_earth!(ev, b, nt)
    end
end

# Conductor k of `terminal_map_from` is conductor k of `terminal_map_to`.
# The Π-shunt blocks are read as `_line_yprim_block` builds them.
function _reference_lines!(ev, net)
    linecodes = _ref_table(net, "linecode")
    for (_, l) in _ref_table(net, "line")
        l isa Dict{String,Any} || continue
        f = get(l, "bus_from", nothing); t = get(l, "bus_to", nothing)
        tmf = get(l, "terminal_map_from", nothing); tmt = get(l, "terminal_map_to", nothing)
        f isa AbstractString && t isa AbstractString && _ref_strings(tmf) && _ref_strings(tmt) || continue
        n = min(length(tmf), length(tmt))
        blocks = try
            Z, nz = _line_z_complex(l, linecodes)
            Z === nothing || (n = min(n, nz))
            yfr, yto = _line_shunt_complex(l, linecodes)
            (yfr === nothing ? nothing : _zero_padded_block(yfr, n),
             yto === nothing ? nothing : _zero_padded_block(yto, n))
        catch
            (nothing, nothing)                      # malformed data ties nothing to earth
        end
        for k in 1:n
            _ref_tie!(ev, _ref_node(f, tmf[k]), _ref_node(t, tmt[k]))
        end
        for (bus, tm, Y) in ((f, tmf, blocks[1]), (t, tmt, blocks[2]))
            Y === nothing && continue
            _ref_admittance!(ev, bus, tm, Y, n; symmetric=false)
        end
    end
end

function _reference_switches!(ev, net)
    for (_, sw) in _ref_table(net, "switch")
        sw isa AbstractDict || continue
        get(sw, "open_switch", false) === true && continue
        f = get(sw, "bus_from", nothing); t = get(sw, "bus_to", nothing)
        tmf = get(sw, "terminal_map_from", nothing); tmt = get(sw, "terminal_map_to", nothing)
        f isa AbstractString && t isa AbstractString && _ref_strings(tmf) && _ref_strings(tmt) || continue
        for k in 1:min(length(tmf), length(tmt))
            _ref_tie!(ev, _ref_node(f, tmf[k]), _ref_node(t, tmt[k]))
        end
    end
end

# A capacitor ties exactly the terminal pairs its susceptance matrix stamps
# (`_cap_bmatrix`, the builder the solver uses): each phase to the neutral
# for WYE, the phase pairs for DELTA, the two terminals for SINGLE_PHASE.
# A WYE bank without a resolvable neutral stamps nothing and ties nothing.
function _reference_capacitors!(ev, net)
    for (_, c) in _ref_table(net, "capacitor")
        c isa Dict{String,Any} || continue
        b = get(c, "bus", nothing); tm = get(c, "terminal_map", nothing)
        b isa AbstractString && _ref_strings(tm) || continue
        B = try _cap_bmatrix(c)[2] catch; nothing end
        B === nothing && continue
        all(isfinite, B) || continue
        for i in 1:length(tm), j in i+1:length(tm)
            i <= size(B, 1) && j <= size(B, 2) && B[i, j] != 0 && _ref_tie!(ev, b, tm[i], tm[j])
        end
    end
end

# IBR coils are read through the rules the solver builds them from
# (`_ibr_control_rules`): the coil terminal pairs by topology, the active
# control law after precedence, the droop bases, the DC coupling. A coil
# is left out only when those constraints PROVE it carries no current at
# any voltage (`_ibr_coil_states`): both its powers forced to zero. Every
# other coil ties its two terminals. A FOUR_LEG coil against earth (no
# neutral in the map) references its phase only when both its powers are
# fixed at one nonzero point, as for a generator.
#
# A record the rules cannot read is not a reason to report a floating
# conductor: all its terminals are then tied together.
function _reference_ibrs!(ev, net, engine_neutrals)
    profiles = _ref_table(net, "control_profile")
    minimum_pf = try
        first(_power_factor_config_check!(net, Finding[]))
    catch
        Dict{String,Any}()
    end
    for (id, c) in _ref_table(net, "ibr")
        c isa AbstractDict || continue
        b = get(c, "bus", nothing); tm = get(c, "terminal_map", nothing)
        b isa AbstractString && _ref_strings(tm) && !isempty(tm) || continue
        rules = try
            policy = minimum_pf isa AbstractDict ? get(minimum_pf, string(id), nothing) : nothing
            engine_neutrals === nothing ? nothing :
                _ibr_control_rules(c, profiles, engine_neutrals, policy)
        catch
            nothing
        end
        if rules === nothing
            for t in tm[2:end]; _ref_tie!(ev, b, tm[1], t); end
            continue
        end
        states = _ibr_coil_states(rules)
        for (k, (positive, reference)) in enumerate(rules.coils)
            states[k] === :zero && continue
            if reference === nothing
                states[k] === :fixed && _ref_earth!(ev, b, positive)
            else
                _ref_tie!(ev, b, positive, reference)
            end
        end
    end
end

# A load or generator is a set of coils, read as the solver reads them:
#   SINGLE_PHASE, two terminals  one coil between them
#   DELTA                        one coil per phase pair (cyclic for three)
#   WYE / one-terminal           one coil per phase, to the neutral in the
#                                map, or to earth when the map holds none
#                                (the phase-to-reference voltage is used)
# A coil counts only where it contributes a voltage-dependent term. A coil
# that carries no current at any voltage neither ties its two ends together
# nor references anything: a load coil whose demand is zero, a generator
# coil whose bounds force both P and Q to zero.
function _reference_coil_elements!(ev, net, kind, activity, pinning, engine_neutrals)
    for (_, c) in _ref_table(net, kind)
        c isa AbstractDict || continue
        b = get(c, "bus", nothing); tm = get(c, "terminal_map", nothing)
        b isa AbstractString && _ref_strings(tm) && !isempty(tm) || continue
        active = activity(c); pins = pinning(c)
        cfg = uppercase(string(get(c, "configuration", "WYE")))
        if cfg == "DELTA"
            pairs = length(tm) == 2 ? [(tm[1], tm[2])] :
                    length(tm) == 3 ? [(tm[k], tm[mod1(k + 1, 3)]) for k in 1:3] : Tuple{String,String}[]
            for (k, (x, y)) in enumerate(pairs)
                active(k) && _ref_tie!(ev, b, x, y)
            end
        elseif cfg == "SINGLE_PHASE" && length(tm) == 2
            active(1) && _ref_tie!(ev, b, tm[1], tm[2])
        else
            npos = engine_neutrals === nothing ? _neutral_pos(tm) : _neutral_pos(tm, engine_neutrals)
            phases = [k for k in eachindex(tm) if k != npos]
            for (idx, k) in enumerate(phases)
                if npos === nothing
                    pins(idx) && _ref_earth!(ev, b, tm[k])
                else
                    active(idx) && _ref_tie!(ev, b, tm[k], tm[npos])
                end
            end
        end
    end
end

_reference_loads!(ev, net, engine_neutrals) =
    _reference_coil_elements!(ev, net, "load", _load_coil_active, _load_coil_active, engine_neutrals)
_reference_generators!(ev, net, engine_neutrals) =
    _reference_coil_elements!(ev, net, "generator", _generator_coil_active, _generator_coil_pins, engine_neutrals)

# Only what the admittance matrix couples is tied: a nonzero entry
# between two terminals, and a nonzero row sum to earth. Listing a
# terminal in the map does not connect it to anything.
function _reference_shunts!(ev, net)
    for (_, sh) in _ref_table(net, "shunt")
        sh isa AbstractDict || continue
        b = get(sh, "bus", nothing); tm = get(sh, "terminal_map", nothing)
        b isa AbstractString && _ref_strings(tm) || continue
        Y = try
            G = _pattern_keys_to_matrix(sh, "G_"); B = _pattern_keys_to_matrix(sh, "B_")
            n = length(tm)
            complex.(G === nothing ? zeros(n, n) : _zero_padded_block(G, n),
                     B === nothing ? zeros(n, n) : _zero_padded_block(B, n))
        catch
            nothing
        end
        Y === nothing && continue
        _ref_admittance!(ev, b, tm, Y, length(tm); symmetric=true)
    end
end

# The terminals of one winding side are tied; the galvanically continuous
# subtypes also tie their two sides. A neutral impedance earths its terminal.
function _reference_transformers!(ev, net)
    for record in _connection_records(net)
        record.kind == "transformer" || continue
        ends = _connection_endpoints(record)
        for e in ends
            _ref_tie_all!(ev, e.bus, e.map)
        end
        if record.subtype in GALVANIC_CONTINUOUS_SUBTYPES && length(ends) == 2 &&
                all(e -> e.bus isa AbstractString && _ref_strings(e.map) && !isempty(e.map), ends)
            _ref_tie!(ev, _ref_node(ends[1].bus, ends[1].map[1]), _ref_node(ends[2].bus, ends[2].map[1]))
        end
    end
    for ((b, t), _) in _transformer_neutral_earthing(net)
        _ref_earth!(ev, b, t)
    end
end

# ── The one source of voltage-reference evidence ─────────────────────────────

# Returns the unreferenced conductor `groups` and `earthed_buses`, the buses
# that carry at least one terminal tied to earth.
function _conductor_reference(net)
    ev = _ReferenceEvidence()
    engine_neutrals = try _neutral_labels(net) catch; nothing end
    _reference_buses!(ev, net)
    _reference_voltage_sources!(ev, net)
    _reference_lines!(ev, net)
    _reference_switches!(ev, net)
    _reference_capacitors!(ev, net)
    _reference_ibrs!(ev, net, engine_neutrals)
    _reference_loads!(ev, net, engine_neutrals)
    _reference_generators!(ev, net, engine_neutrals)
    _reference_shunts!(ev, net)
    _reference_transformers!(ev, net)

    referenced = Set(_ds_find!(ev.conductors, n) for n in ev.earthed)
    groups = [g for (root, g) in _ds_groups(ev.conductors) if !(root in referenced)]
    (groups=sort!([sort!(g) for g in groups]),
     earthed_buses=Set{String}(n[1] for n in ev.earthed))
end

# Whether the Π-shunt block a line contributes to the nodal admittance has a
# path to earth. Mirrors `_line_yprim_block`: the same impedance-source choice,
# length scaling and conductor truncation. Malformed data is not a reference.
function _line_stamps_earth_shunt(line::Dict{String,Any}, linecodes::AbstractDict)::Bool
    try
        Z, nz = _line_z_complex(line, linecodes)
        Z === nothing && return false
        tmf = get(line, "terminal_map_from", nothing); tmt = get(line, "terminal_map_to", nothing)
        tmf isa AbstractVector && tmt isa AbstractVector || return false
        n = min(nz, length(tmf), length(tmt))
        n == 0 && return false
        for Y in _line_shunt_complex(line, linecodes)
            Y === nothing && continue
            # Sparse declarations are zero-padded to the conductor count, as
            # every builder reads them: one diagonal entry is a path to earth.
            block = _zero_padded_block(Y, n)
            scale = _admittance_scale(block)
            scale === nothing && continue
            any(_row_earths(block, i, scale) for i in 1:n) && return true
        end
        return false
    catch
        return false
    end
end
