# Helpers for extracting network data into OPF-ready structures.
# All values remain in SI units: Ω, V, A, W, var.

# Re-export the matrix builder from the parent package internals.
const _pkm = BMOPFTools._pattern_keys_to_matrix

"""
    _bus_terminals(net) -> Dict{String, Vector{String}}

Map each bus id to its ordered list of terminal names.
"""
function _bus_terminals(net::Dict{String,Any})
    bt = Dict{String,Vector{String}}()
    for (bid, bus) in get(net, "bus", Dict())
        bt[bid] = Vector{String}(get(bus, "terminal_names", String[]))
    end
    bt
end

"""
    _grounded_terminals(net) -> Set{Tuple{String,String}}

Set of (bus_id, terminal) pairs that are perfectly grounded (vr=vi=0).

Includes both:
  - terminals declared in a bus's `perfectly_grounded_terminals`, and
  - the **neutral terminal of every voltage-source bus**, which the source
    pins to 0 V as the system ground reference (see `_add_source_constraints!`).

Both kinds are V=0 references AND physical earth connections, so both must get a
free ground-injection current (`cr_gnd`) and a KCL equation. Omitting the source
neutral here is what previously left an earth-return circuit with no return path:
the source neutral could only return `-Σcr_src` (rigidly the phase-slack sum), so
current that had to flow phase→earth→source-ground was forced to zero.
"""
function _grounded_terminals(net::Dict{String,Any})
    grounded = Set{Tuple{String,String}}()
    for (bid, bus) in get(net, "bus", Dict())
        for t in get(bus, "perfectly_grounded_terminals", String[])
            push!(grounded, (bid, string(t)))
        end
    end
    # Source-bus neutrals are pinned to 0 by the source; treat them as grounded
    # so they receive a ground-injection current and KCL like any other ground.
    buses = get(net, "bus", Dict())
    for (_, vs) in get(net, "voltage_source", Dict())
        bus = get(vs, "bus", "")
        nt  = BMOPFTools._neutral_terminal(get(buses, bus, Dict()))
        nt === nothing || push!(grounded, (bus, string(nt)))
    end
    grounded
end

"""
    _line_z_matrix(line, linecodes) -> (R::Matrix, X::Matrix, n::Int)

Return the total series impedance matrices (Ω) for a line and the number
of conductors. R = R_series_per_m × length, same for X.
Returns (nothing, nothing, 0) if the linecode is missing.
"""
function _line_z_matrix(line::Dict{String,Any}, linecodes::Dict{String,Any})
    lcid = get(line, "linecode", nothing)
    lcid === nothing && return (nothing, nothing, 0)
    lc = get(linecodes, lcid, nothing)
    lc === nothing && return (nothing, nothing, 0)

    R_pm = _pkm(lc, "R_series_")   # Ω/m
    X_pm = _pkm(lc, "X_series_")   # Ω/m
    len  = Float64(get(line, "length", 1.0))  # m

    R_pm === nothing && (R_pm = zeros(1,1))
    X_pm === nothing && (X_pm = zeros(size(R_pm)...))

    n = size(R_pm, 1)
    (R_pm .* len, X_pm .* len, n)
end

# These helpers live in BMOPFTools core; alias locally for convenience.
const _neutral_pos      = BMOPFTools._neutral_pos
const _phase_positions  = BMOPFTools._phase_positions
const _xfmr_turns_ratio = BMOPFTools._xfmr_turns_ratio

"""
    _source_fixed_terminals(net) -> Set{Tuple{String,String}}

Collect all (bus_id, terminal) pairs whose voltage is fixed by a voltage source.
These must be excluded from voltage bound constraints.
"""
function _source_fixed_terminals(net::Dict{String,Any})
    fixed = Set{Tuple{String,String}}()
    for (_, vs) in get(net, "voltage_source", Dict())
        bus = get(vs, "bus", "")
        for t in Vector{String}(get(vs, "terminal_map", String[]))
            push!(fixed, (bus, t))
        end
    end
    fixed
end


"""
    _line_pi_shunt(line, linecodes) -> (G_fr, B_fr, G_to, B_to)

Return the total from- and to-side shunt admittance matrices (S) for a line
from its linecode's G_from/B_from/G_to/B_to fields (S/m) scaled by line length.
Returns (nothing, nothing, nothing, nothing) when no shunt fields are present.
"""
function _line_pi_shunt(line::Dict{String,Any}, linecodes::Dict{String,Any})
    lcid = get(line, "linecode", nothing)
    lcid === nothing && return nothing, nothing, nothing, nothing
    lc = get(linecodes, lcid, nothing)
    lc === nothing && return nothing, nothing, nothing, nothing

    G_fr = _pkm(lc, "G_from_")
    B_fr = _pkm(lc, "B_from_")
    G_to = _pkm(lc, "G_to_")
    B_to = _pkm(lc, "B_to_")

    any(!isnothing, (G_fr, B_fr, G_to, B_to)) || return nothing, nothing, nothing, nothing

    len = Float64(get(line, "length", 1.0))
    G_fr !== nothing && (G_fr = G_fr .* len)
    B_fr !== nothing && (B_fr = B_fr .* len)
    G_to !== nothing && (G_to = G_to .* len)
    B_to !== nothing && (B_to = B_to .* len)
    G_fr, B_fr, G_to, B_to
end

"""
    _limit_current_box!(cr, ci, ilim)

Tighten a rectangular current variable pair with a box bound implied by the
magnitude limit `|c| ≤ ilim`. Since `cr² + ci² ≤ ilim²` forces both
`|cr| ≤ ilim` and `|ci| ≤ ilim`, the box `[-ilim, ilim]` on each component is a
valid (looser) bound that is redundant with the second-order cone but helps the
NLP solver by bounding the variables from the start.

Only valid when `ilim` limits the *variable itself*. Do **not** apply it where
the thermal limit is on a series+shunt expression (lines, and the from-side of a
transformer with a no-load shunt): there the variable can exceed `ilim` when the
shunt current opposes it.

`cr`/`ci` must be `VariableRef`s. No-op for a non-finite or negative `ilim`.
"""
function _limit_current_box!(cr::JuMP.VariableRef, ci::JuMP.VariableRef, ilim::Real)
    (isfinite(ilim) && ilim >= 0) || return
    for v in (cr, ci)
        JuMP.has_lower_bound(v) ? JuMP.set_lower_bound(v, max(JuMP.lower_bound(v), -ilim)) :
                                  JuMP.set_lower_bound(v, -ilim)
        JuMP.has_upper_bound(v) ? JuMP.set_upper_bound(v, min(JuMP.upper_bound(v), ilim)) :
                                  JuMP.set_upper_bound(v, ilim)
    end
    return
end

"""
    _neutral_current_limit!(model, cr_terms, ci_terms, ilim)

Cap the magnitude of a WYE/FOUR_LEG device's **neutral-conductor** current at
`ilim` [A]. The neutral return current is the negative sum of the device's phase
currents, so its magnitude limit is the second-order cone

    (Σ_k cr_k)² + (Σ_k ci_k)² ≤ ilim² .

`cr_terms`/`ci_terms` are the per-phase rectangular current variables. This makes
`i_max` per **conductor** (phases + neutral) for star-connected devices, matching
the per-conductor `i_max` already carried by lines and switches. No-op for a
non-finite or negative `ilim`.
"""
function _neutral_current_limit!(model, cr_terms, ci_terms, ilim::Real)
    (isfinite(ilim) && ilim >= 0) || return
    cr_n = @expression(model, sum(cr_terms))
    ci_n = @expression(model, sum(ci_terms))
    @constraint(model, cr_n^2 + ci_n^2 <= ilim^2)
    return
end

"""
    _terminal_vmax_to_ground(bus, terminal, grounded) -> Union{Float64,Nothing}

Sound upper bound on the **to-ground** voltage magnitude `|V_{bus,terminal}|`,
or `nothing` when no hard bound can be derived from the bus data. Used to bound
line shunt-current contributions (which are linear in the to-ground voltage
variables), so it must never over-tighten.

Sources, in order of preference:
- a perfectly grounded terminal → `0`;
- phase-to-ground bound `v_max[k]` for the terminal's phase index `k` → `v_max[k]`;
- phase-to-neutral bound `vpn_max[k]` with a perfectly grounded neutral
  (so `|V_n| = 0`) → `vpn_max[k]`;
- `vpn_max[k]` plus a neutral-to-ground bound `vn_max` (floating neutral) →
  `vpn_max[k] + vn_max`  (triangle inequality `|V_p| ≤ |V_p − V_n| + |V_n|`);
- the neutral terminal itself with only `vn_max` → `vn_max`.

Returns `nothing` if none of these apply (e.g. the ENWL benchmark, which carries
only `vpn_max` on a floating neutral): the caller then leaves the variable free.
"""
function _terminal_vmax_to_ground(bus::Dict{String,Any}, terminal::String,
                                  grounded::Set{Tuple{String,String}}, bid::String)
    (bid, terminal) in grounded && return 0.0

    neutral = BMOPFTools._neutral_terminal(bus)
    vn_max  = get(bus, "vn_max", nothing)

    # Neutral terminal: only vn_max can bound it to ground (phase-to-ground
    # v_max/vpn_max do not apply to the neutral).
    if neutral !== nothing && terminal == neutral
        return vn_max === nothing ? nothing : Float64(vn_max)
    end

    # Phase terminal: find its index among the phase terminals (terminal_names
    # order, neutral excluded). v_min/v_max and vpn_max are per-phase arrays.
    phase_terms = [t for t in get(bus, "terminal_names", String[]) if t != neutral]
    k = findfirst(==(terminal), phase_terms)
    k === nothing && return nothing

    # Phase-to-ground bound is the direct, sound to-ground cap.
    v_max = get(bus, "v_max", nothing)
    if v_max isa AbstractVector && k <= length(v_max)
        return Float64(v_max[k])
    end

    # Otherwise fall back to the phase-to-neutral bound plus a neutral cap.
    vpn_max = get(bus, "vpn_max", nothing)
    (vpn_max === nothing || neutral === nothing) && return nothing
    (k > length(vpn_max)) && return nothing
    vpn = Float64(vpn_max[k])

    if (bid, neutral) in grounded
        return vpn                       # |V_n| = 0
    elseif vn_max !== nothing
        return vpn + Float64(vn_max)     # |V_p| ≤ |V_p − V_n| + |V_n|
    end
    return nothing                       # floating neutral, no vn_max → unbounded
end

"""
    _line_shunt_row_bound(G, B, vmax, k, n) -> Union{Float64,Nothing}

Upper bound on the magnitude of the π-shunt current injected into conductor `k`,
`|I_sh,k| = |Σ_j (G_kj + jB_kj)·V_j| ≤ Σ_j √(G_kj² + B_kj²)·V^max_j`.

`vmax[j]` is the to-ground voltage cap for from-terminal `j` (from
`_terminal_vmax_to_ground`); `nothing` means terminal `j` is unbounded. Returns
`nothing` if any `j` with a nonzero admittance entry has an unknown cap — then
the row's shunt contribution is unbounded and no series-current box is sound.
A row with no shunt (all entries zero) returns `0.0`.
"""
function _line_shunt_row_bound(G::Union{Matrix{Float64},Nothing},
                               B::Union{Matrix{Float64},Nothing},
                               vmax::Vector{Union{Float64,Nothing}},
                               k::Int, n::Int)
    (G === nothing && B === nothing) && return 0.0
    acc = 0.0
    for j in 1:n
        g_kj = (G !== nothing && k <= size(G,1) && j <= size(G,2)) ? G[k,j] : 0.0
        b_kj = (B !== nothing && k <= size(B,1) && j <= size(B,2)) ? B[k,j] : 0.0
        (iszero(g_kj) && iszero(b_kj)) && continue
        vj = vmax[j]
        vj === nothing && return nothing   # admittance feeds from an unbounded node
        acc += hypot(g_kj, b_kj) * vj
    end
    return acc
end
