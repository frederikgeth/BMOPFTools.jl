# Linecode impedance classification.
#
# Classifies each linecode's series impedance matrix by balance structure
# (decoupled / exactly_balanced / near_balanced / distinct), checks
# reciprocity and passivity of Z, and flags shunt admittance sign issues.
# Also detects the impedance-transformation type for 3-wire linecodes.

function _classify_linecodes(net::Dict{String,Any},
                              findings::Vector{Finding})::Dict{String,Any}
    linecodes = get(net, "linecode", Dict())
    by_lc = Dict{String,Any}()
    verdict_counts = Dict{String,Int}()
    seq_ids   = String[]
    dec_ids   = String[]

    for (id, lc) in linecodes
        lc isa Dict || continue
        R = _pattern_keys_to_matrix(lc, "R_series_")
        R === nothing && continue
        X = _pattern_keys_to_matrix(lc, "X_series_")
        n = size(R, 1)
        Xm = (X isa AbstractMatrix && size(X) == size(R)) ? X : zeros(n, n)

        entry = Dict{String,Any}("n_conductors" => n)

        # Reciprocity: the impedance matrix of a passive line is symmetric
        scale = max(maximum(abs.(R)), maximum(abs.(Xm)), 1e-300)
        asym  = max(maximum(abs.(R - transpose(R))),
                    maximum(abs.(Xm - transpose(Xm)))) / scale
        entry["reciprocity_error"] = asym
        if asym > 1e-6
            push!(findings, Finding(ERROR, "E.PROV.NONRECIPROCAL", :provenance,
                :linecode, id,
                "Linecode '$id' impedance matrix is not symmetric (relative " *
                "asymmetry $(round(asym, sigdigits=3))) — violates reciprocity; " *
                "likely data corruption.",
                Dict{String,Any}("asymmetry" => asym)))
        end

        # Passivity: R block must be positive semidefinite
        Rsym = Symmetric((R + transpose(R)) / 2)
        ev   = eigvals(Rsym)
        entry["r_eig_min"] = minimum(ev)
        if minimum(ev) < -1e-9 * max(maximum(abs.(ev)), 1e-12)
            push!(findings, Finding(ERROR, "E.PROV.NONPASSIVE", :provenance,
                :linecode, id,
                "Linecode '$id' resistance matrix has a negative eigenvalue " *
                "($(round(minimum(ev), sigdigits=3))) — non-passive; the line " *
                "would generate power.",
                Dict{String,Any}("r_eigenvalues" => collect(ev))))
        end

        # X block: series reactance is inductive at power frequency —
        # positive diagonals, and the inductance matrix is PSD (energy
        # argument). Both properties survive Kron reduction (Schur
        # complements of sectorial matrices stay sectorial).
        if X isa AbstractMatrix && size(X) == size(R)
            xdiag = [Xm[i, i] for i in 1:n]
            bad = [i for i in 1:n if xdiag[i] <= 0]
            if !isempty(bad)
                push!(findings, Finding(WARNING, "W.PROV.X_NONINDUCTIVE",
                    :provenance, :linecode, id,
                    "Linecode '$id' has non-positive series self-reactance on " *
                    "diagonal entr$(length(bad) == 1 ? "y" : "ies") $(bad) — " *
                    "likely a sign flip or X/B confusion.",
                    Dict{String,Any}("entries" => bad)))
            end
            evx = eigvals(Symmetric((Xm + transpose(Xm)) / 2))
            entry["x_eig_min"] = minimum(evx)
            if minimum(evx) < -1e-9 * max(maximum(abs.(evx)), 1e-12)
                push!(findings, Finding(WARNING, "W.PROV.X_NOT_PSD",
                    :provenance, :linecode, id,
                    "Linecode '$id' reactance matrix has a negative eigenvalue " *
                    "($(round(minimum(evx), sigdigits=3))) — the implied " *
                    "inductance matrix is not physically realisable.",
                    Dict{String,Any}("x_eigenvalues" => collect(evx))))
            end
        end

        # Mutual resistance sign (soft): Carson's earth-return term makes
        # off-diagonal R positive for lines parameterised from geometry
        if n >= 2
            negm = [(i, j) for i in 1:n for j in i+1:n if R[i, j] < -1e-12]
            if !isempty(negm)
                entry["negative_mutual_r"] = negm
                push!(findings, Finding(INFO, "I.PROV.NEGATIVE_MUTUAL_R",
                    :provenance, :linecode, id,
                    "Linecode '$id' has negative mutual resistance entr" *
                    "$(length(negm) == 1 ? "y" : "ies") $(negm) — unusual; " *
                    "Carson-derived matrices have positive mutuals.",
                    Dict{String,Any}("entries" => negm)))
            end
            # Carson fingerprint: report mutual-R statistics
            muts = [R[i, j] for i in 1:n for j in i+1:n]
            entry["mutual_r_mean"]   = sum(muts) / length(muts)
            entry["mutual_r_spread"] = maximum(muts) - minimum(muts)
        end

        # Shunt admittance blocks: G must be passive (PSD, nonneg diag);
        # B comes from the Maxwell capacitance matrix — nonneg diagonals,
        # non-positive off-diagonals, PSD. Same gates apply to inline lines.
        for prefix in _PI_SHUNT_PREFIXES
            _check_shunt_block_physics!(findings, id, :linecode, prefix,
                                        _pattern_keys_to_matrix(lc, prefix))
        end

        # Balance classification on the phase block (conductors 1–3)
        if n >= 3
            Z = complex.(R, Xm)[1:3, 1:3]
            verdict, detail = _classify_balance(Z)
            merge!(entry, detail)
            entry["verdict"] = verdict
            verdict == "exactly_balanced" && push!(seq_ids, id)
            verdict == "decoupled"        && push!(dec_ids, id)
        else
            entry["verdict"] = "not_applicable"
        end

        # π-model topology (series / Γ / symmetric-π / asymmetric-π). The
        # case-study-level classification and callouts live in
        # `_classify_line_models`; here we just record the per-linecode verdict.
        entry["pi_model"] = first(_pi_topology(lc))

        verdict_counts[entry["verdict"]] = get(verdict_counts, entry["verdict"], 0) + 1
        by_lc[id] = entry
    end

    if !isempty(seq_ids)
        push!(findings, Finding(INFO, "I.PROV.SEQ_DERIVED", :provenance,
            :linecode, nothing,
            "$(length(seq_ids)) linecode(s) have exactly balanced impedance " *
            "matrices (equal self, equal mutual entries) — likely constructed " *
            "from sequence parameters (r1,x1,r0,x0) or a transposition " *
            "assumption, not from conductor geometry: $(join(sort(seq_ids), ", ")).",
            Dict{String,Any}("linecodes" => sort(seq_ids))))
    end
    if !isempty(dec_ids)
        push!(findings, Finding(INFO, "I.PROV.DECOUPLED_PHASES", :provenance,
            :linecode, nothing,
            "$(length(dec_ids)) linecode(s) have zero mutual coupling " *
            "(diagonal impedance matrix) — positive-sequence-only data; the " *
            "phases decouple into independent single-phase networks: " *
            "$(join(sort(dec_ids), ", ")).",
            Dict{String,Any}("linecodes" => sort(dec_ids))))
    end
    Dict{String,Any}("by_linecode" => by_lc, "verdict_counts" => verdict_counts)
end

# ---------------------------------------------------------------------------
# π-model topology classification
# ---------------------------------------------------------------------------
# A line (or its linecode template) is stored as a two-sided nominal-π: a
# series impedance Z with a shunt admittance half-block Y_from at the from-end
# and Y_to at the to-end (Y = G + jB). Which of those blocks are populated, and
# whether the two ends are equal, determines the *model topology*:
#
#   series         — no shunt on either end. Pure series impedance. The default
#                    and expected model for LV / short-cable distribution, where
#                    line charging is negligible.
#   symmetric_pi   — shunt on both ends and Y_from ≈ Y_to. The canonical
#                    nominal-π: a uniform reciprocal line splits its total
#                    charging equally between the two terminals. Expected once
#                    charging matters (longer MV/HV overhead, underground cable).
#   asymmetric_pi  — shunt on both ends but Y_from ≠ Y_to. Suspicious: a uniform
#                    line has a symmetric split, so unequal halves usually mean
#                    a network-reduction artefact or a data error.
#   gamma          — shunt on exactly one end (a Γ-section). A legitimate
#                    deliberate lumping of the charging at one terminal, but it
#                    breaks the physical from/to symmetry — worth confirming.
#
# The four blocks are the schema keys G_from/G_to/B_from/B_to; presence is
# tested as "any stored entry is non-zero" (all-zero keys count as absent,
# matching how the model consumes them).

const _PI_SHUNT_PREFIXES = ("G_from_", "G_to_", "B_from_", "B_to_")

_block_nonzero(M) = M isa AbstractMatrix && any(!=(0.0), M)

# Fetch a shunt block as an n×n matrix, zero-padded/truncated to n conductors
# (zeros when the block is absent). Used to compare from/to blocks of possibly
# differing declared dimension on the same footing.
function _block_as(elem::Dict, prefix::AbstractString, n::Int)
    M = _pattern_keys_to_matrix(elem, prefix)
    M isa AbstractMatrix || return zeros(n, n)
    size(M, 1) == n && return M
    Z = zeros(n, n)
    k = min(n, size(M, 1))
    Z[1:k, 1:k] .= M[1:k, 1:k]
    Z
end

"""
    _pi_topology(elem) -> (model::String, detail::Dict)

Classify the π-model topology of one impedance-bearing element — a linecode
template or an inline line — into `"series"`, `"gamma"`, `"symmetric_pi"`, or
`"asymmetric_pi"`. `detail` reports the from/to admittance mismatch, whether a
shunt conductance (dielectric loss) is present, and, for a Γ-section, which
end carries the shunt.
"""
function _pi_topology(elem::Dict)
    Gf = _pattern_keys_to_matrix(elem, "G_from_")
    Gt = _pattern_keys_to_matrix(elem, "G_to_")
    Bf = _pattern_keys_to_matrix(elem, "B_from_")
    Bt = _pattern_keys_to_matrix(elem, "B_to_")

    fr_present = _block_nonzero(Gf) || _block_nonzero(Bf)
    to_present = _block_nonzero(Gt) || _block_nonzero(Bt)
    has_conductance = _block_nonzero(Gf) || _block_nonzero(Gt)

    detail = Dict{String,Any}("has_shunt_conductance" => has_conductance)

    if !fr_present && !to_present
        return ("series", detail)
    elseif fr_present ⊻ to_present
        detail["shunt_end"] = fr_present ? "from" : "to"
        return ("gamma", detail)
    end

    # Both ends carry a shunt — compare Y_from against Y_to on a common size.
    n = maximum(size(M, 1) for M in (Gf, Gt, Bf, Bt) if M isa AbstractMatrix)
    Yf = complex.(_block_as(elem, "G_from_", n), _block_as(elem, "B_from_", n))
    Yt = complex.(_block_as(elem, "G_to_", n),   _block_as(elem, "B_to_", n))
    scale = max(maximum(abs.(Yf)), maximum(abs.(Yt)), 1e-300)
    asym  = maximum(abs.(Yf - Yt)) / scale
    detail["fromto_asymmetry"] = asym
    (asym < 1e-6 ? "symmetric_pi" : "asymmetric_pi", detail)
end

# Shared physics gates for one shunt admittance block, reported against either a
# linecode template or an inline line (`ctype`). G blocks must be passive (PSD,
# non-negative diagonals); B blocks come from the Maxwell capacitance matrix
# (PSD, non-negative diagonals, non-positive off-diagonals). Reciprocity (block
# symmetry) is required of both.
function _check_shunt_block_physics!(findings::Vector{Finding}, id,
                                     ctype::Symbol, prefix::AbstractString, M)
    M isa AbstractMatrix || return
    label = uppercasefirst(String(ctype))
    nm = size(M, 1)
    scaleM = max(maximum(abs.(M)), 1e-300)
    if maximum(abs.(M - transpose(M))) / scaleM > 1e-6
        push!(findings, Finding(ERROR, "E.PROV.NONRECIPROCAL", :provenance,
            ctype, id,
            "$label '$id' $(prefix)block is not symmetric — violates reciprocity.",
            nothing))
    end
    if startswith(prefix, "G_")
        evg = eigvals(Symmetric((M + transpose(M)) / 2))
        if any(M[i, i] < -1e-12 for i in 1:nm) ||
           minimum(evg) < -1e-9 * max(maximum(abs.(evg)), 1e-12)
            push!(findings, Finding(ERROR, "E.PROV.NEGATIVE_G", :provenance,
                ctype, id,
                "$label '$id' $(prefix)conductance block is not positive " *
                "semidefinite — an active (power-generating) shunt.", nothing))
        end
    else
        evb = eigvals(Symmetric((M + transpose(M)) / 2))
        bad_diag = any(M[i, i] < -1e-9 * scaleM for i in 1:nm)
        bad_eig  = minimum(evb) < -1e-9 * max(maximum(abs.(evb)), 1e-12)
        pos_off  = any(M[i, j] > 1e-9 * scaleM
                       for i in 1:nm for j in 1:nm if i != j)
        if bad_diag || bad_eig
            # PSD and nonnegative diagonals are invariant (capacitance matrix
            # energy argument, preserved by Schur complements)
            push!(findings, Finding(WARNING, "W.PROV.B_SIGN", :provenance,
                ctype, id,
                "$label '$id' $(prefix)susceptance block is not positive " *
                "semidefinite / has negative diagonals — not a physical " *
                "capacitance matrix.", nothing))
        elseif pos_off
            # the Maxwell sign pattern (off-diag ≤ 0) is typical but NOT
            # invariant: screen elimination / bundling can flip small mutuals
            # positive while preserving PSD
            push!(findings, Finding(INFO, "I.PROV.B_OFFDIAG", :provenance,
                ctype, id,
                "$label '$id' $(prefix)block has positive mutual susceptance " *
                "— deviates from the Maxwell sign pattern; typical of " *
                "screen-eliminated/bundled cable reductions, otherwise a " *
                "sign-convention suspect.", nothing))
        end
    end
end

"""
    _classify_line_models(net, findings) -> Dict

Classify every impedance-bearing element (linecode templates and inline lines)
by π-model topology, and audit the case study for model consistency.

Per element it emits a `W.PROV.ASYMMETRIC_PI` warning for unequal shunt halves,
an `I.PROV.GAMMA_SECTION` note for one-sided shunts, and an
`I.PROV.SHUNT_CONDUCTANCE` note for a modelled dielectric loss (unusual in
distribution). At the case-study level it emits `I.PROV.LINE_MODEL_UNIFORM`
when a single model is used throughout, or `I.PROV.LINE_MODEL_MIXED` when the
network mixes topologies (legitimate for series-short / π-long feeders, but
worth a consistency review).
"""
function _classify_line_models(net::Dict{String,Any},
                               findings::Vector{Finding})::Dict{String,Any}
    # Collect the impedance *definitions*: every linecode, plus every line that
    # carries inline absolute matrices (a line with a `linecode` ref inherits
    # that template's topology and is not double-counted).
    elems = Tuple{Symbol,String,Dict{String,Any}}[]
    for (id, lc) in get(net, "linecode", Dict())
        lc isa Dict || continue
        _pattern_keys_to_matrix(lc, "R_series_") === nothing && continue
        push!(elems, (:linecode, id, lc))
    end
    for (id, l) in get(net, "line", Dict())
        (l isa Dict && _line_has_inline_z(l)) || continue
        push!(elems, (:line, id, l))
    end
    isempty(elems) && return Dict{String,Any}()

    _label = Dict("series" => "pure series impedance",
                  "symmetric_pi" => "symmetric π",
                  "asymmetric_pi" => "asymmetric π",
                  "gamma" => "Γ (one-sided shunt)")

    by_element = Dict{String,Any}()
    counts = Dict{String,Int}("series" => 0, "gamma" => 0,
                              "symmetric_pi" => 0, "asymmetric_pi" => 0)
    asym_ids = String[]; gamma_ids = String[]; cond_ids = String[]

    for (ctype, id, elem) in elems
        model, detail = _pi_topology(elem)
        counts[model] += 1
        key = "$(ctype):$(id)"
        by_element[key] = merge(
            Dict{String,Any}("model" => model, "component_type" => String(ctype)),
            detail)
        label = uppercasefirst(String(ctype))

        if model == "asymmetric_pi"
            push!(asym_ids, key)
            push!(findings, Finding(WARNING, "W.PROV.ASYMMETRIC_PI", :provenance,
                ctype, id,
                "$label '$id' is an asymmetric π-section: its from-side and " *
                "to-side shunt admittances differ (relative mismatch " *
                "$(round(get(detail, "fromto_asymmetry", 0.0), sigdigits=3))). A " *
                "uniform reciprocal line splits its shunt charging equally " *
                "between both ends; unequal halves usually indicate a " *
                "network-reduction artefact or a data error.", detail))
        elseif model == "gamma"
            push!(gamma_ids, key)
            push!(findings, Finding(INFO, "I.PROV.GAMMA_SECTION", :provenance,
                ctype, id,
                "$label '$id' is a Γ-section: shunt admittance is present only " *
                "on the $(get(detail, "shunt_end", "?"))-side, the other end is " *
                "a pure series connection. Valid as a deliberate lumping of " *
                "charging at one terminal, but it breaks the from/to symmetry " *
                "of a physical line — confirm it is intended.", detail))
        end

        if get(detail, "has_shunt_conductance", false) && model != "series"
            push!(cond_ids, key)
            push!(findings, Finding(INFO, "I.PROV.SHUNT_CONDUCTANCE", :provenance,
                ctype, id,
                "$label '$id' carries a non-zero shunt conductance " *
                "(G_from/G_to) — dielectric-loss / leakage current is modelled. " *
                "This is unusual in distribution networks, where the line shunt " *
                "is normally purely capacitive; confirm it is not an X/B or " *
                "units confusion.", detail))
        end
    end

    present = [m for m in ("series", "symmetric_pi", "asymmetric_pi", "gamma")
               if counts[m] > 0]
    total = sum(values(counts))
    breakdown = join(["$(counts[m]) × $(_label[m])" for m in present], ", ")

    if length(present) == 1
        m = present[1]
        note = m == "series" ?
            "Shunt charging is neglected network-wide — expected for LV / " *
            "short-cable networks, but worth confirming for feeders with long " *
            "MV/HV overhead or underground-cable sections." :
               m == "symmetric_pi" ?
            "Every branch carries a symmetric π shunt — line charging is " *
            "represented consistently across the network." :
            "Note this is an unusual choice as a network-wide model (see the " *
            "per-element findings)."
        push!(findings, Finding(INFO, "I.PROV.LINE_MODEL_UNIFORM", :provenance,
            :linecode, nothing,
            "All $total line-model definition(s) use a single, consistent " *
            "model: $(_label[m]). $note",
            Dict{String,Any}("counts" => counts)))
    else
        push!(findings, Finding(INFO, "I.PROV.LINE_MODEL_MIXED", :provenance,
            :linecode, nothing,
            "The case study mixes $(length(present)) line models across " *
            "$total definition(s): $breakdown. A series/π mix is legitimate " *
            "when short spurs are modelled as series impedance and long trunks " *
            "as π-sections, but a mix should be reviewed for consistency — " *
            "especially any asymmetric-π or Γ members.",
            Dict{String,Any}("counts" => counts)))
    end

    Dict{String,Any}("by_element" => by_element, "counts" => counts,
                     "asymmetric_pi" => sort(asym_ids),
                     "gamma" => sort(gamma_ids),
                     "shunt_conductance" => sort(cond_ids))
end

"""
Classify the 3×3 phase block of a complex series impedance matrix.
Spreads are normalized by the largest self-impedance magnitude so that
deviations that are negligible relative to the self term don't block a
balanced verdict.
"""
function _classify_balance(Z::AbstractMatrix)
    d = [Z[1,1], Z[2,2], Z[3,3]]
    o = [Z[1,2], Z[1,3], Z[2,3]]
    dscale = max(maximum(abs.(d)), 1e-300)

    diag_spread = maximum(abs(d[i] - d[j]) for i in 1:3 for j in i+1:3) / dscale
    off_spread  = maximum(abs(o[i] - o[j]) for i in 1:3 for j in i+1:3) / dscale
    mutual_ratio = maximum(abs.(o)) / dscale

    detail = Dict{String,Any}(
        "diag_spread"          => diag_spread,
        "offdiag_spread"       => off_spread,
        "mutual_to_self_ratio" => mutual_ratio
    )

    verdict = if mutual_ratio < 1e-6 && diag_spread < 1e-6
        "decoupled"
    elseif diag_spread < 1e-9 && off_spread < 1e-9
        "exactly_balanced"
    elseif diag_spread < 1e-2 && off_spread < 1e-2
        "near_balanced"
    else
        "distinct"
    end

    if verdict in ("exactly_balanced", "near_balanced")
        zs = sum(d) / 3
        zm = sum(o) / 3
        z1 = zs - zm
        z0 = zs + 2zm
        detail["z1"] = Dict{String,Any}("r" => real(z1), "x" => imag(z1))
        detail["z0"] = Dict{String,Any}("r" => real(z0), "x" => imag(z0))
        detail["z0_z1_ratio"] = abs(z0) / max(abs(z1), 1e-300)
    end

    (verdict, detail)
end

# ---------------------------------------------------------------------------
# Impedance transformation classification for 3-wire linecodes
# ---------------------------------------------------------------------------
# Three-wire LV linecodes are either Kron-reduced from a 4-wire Carson matrix
# or constructed via one of two impedance approximations described in:
#   Geth, Heidari, Koirala (2022) ACM e-Energy. doi:10.1145/3538637.3538844
#
# Detection uses the structure of the R and X blocks independently:
#
#   kron_reduced          — R and/or X off-diagonals are non-uniform ("distinct")
#                           and/or R_mutual/R_self << 0.5. This is the signature
#                           of a Schur-complement elimination of the neutral row/col
#                           from the original Carson-geometry 4-wire matrix.
#
#   phase_to_neutral      — R block is exactly circulant (all diagonals equal,
#                           all off-diagonals equal) with mutual/self ≈ 0.5;
#                           X block is NOT circulant. R_neutral was folded into
#                           phase self-terms; X retains the original geometry.
#
#   modified_phase_to_neutral — BOTH R and X are exactly circulant with
#                           mutual/self ≈ 0.5. X was also symmetrised; this
#                           introduces additional modelling error.

function _classify_impedance_transformation(net::Dict{String,Any},
                                             findings::Vector{Finding},
                                             lc_result::Dict{String,Any})::Dict{String,Any}
    linecodes = get(net, "linecode", Dict())
    by_lc     = get(lc_result, "by_linecode", Dict())

    # Only 3-conductor linecodes are relevant
    three_wire = [(id, lc) for (id, lc) in linecodes
                  if lc isa Dict && get(get(by_lc, id, Dict()), "n_conductors", 0) == 3]
    isempty(three_wire) && return Dict{String,Any}()

    # Check whether a 3×3 matrix is circulant (all diagonal entries equal and all
    # off-diagonal entries equal) relative to the diagonal scale.
    function _is_circulant(M::AbstractMatrix, tol=1e-2)
        diags = [M[i, i] for i in 1:3]
        offs  = [M[i, j] for i in 1:3 for j in 1:3 if i ≠ j]
        scale = max(maximum(abs.(diags)), 1e-300)
        maximum(abs(d - diags[1]) for d in diags) / scale < tol &&
        maximum(abs(o - offs[1])  for o in offs)  / scale < tol
    end

    classified = Dict{String,String}()

    for (id, lc) in three_wire
        R = _pattern_keys_to_matrix(lc, "R_series_")
        X = _pattern_keys_to_matrix(lc, "X_series_")
        (R isa AbstractMatrix && size(R, 1) >= 3) || continue

        diag_R = [R[i, i] for i in 1:3]
        off_R  = [R[i, j] for i in 1:3 for j in 1:3 if i ≠ j]
        mean_diag_R = sum(diag_R) / 3
        mean_off_R  = sum(off_R)  / 6
        r_mutual_ratio = mean_diag_R > 0 ? mean_off_R / mean_diag_R : NaN

        r_circ = _is_circulant(R)
        x_circ = X isa AbstractMatrix && size(X, 1) >= 3 && _is_circulant(X)
        half_r = !isnan(r_mutual_ratio) && abs(r_mutual_ratio - 0.5) < 0.06

        transform = if r_circ && x_circ && half_r
            "modified_phase_to_neutral"
        elseif r_circ && half_r
            "phase_to_neutral"
        else
            "kron_reduced"
        end
        classified[id] = transform
    end

    isempty(classified) && return Dict{String,Any}()

    by_type = Dict{String,Vector{String}}()
    for (id, t) in classified
        push!(get!(by_type, t, String[]), id)
        sort!(by_type[t])
    end

    _desc = Dict{String,String}(
        "kron_reduced" =>
            "Kron reduction — neutral row/column eliminated from the original " *
            "four-wire Carson impedance matrix via Schur complement. Exact when " *
            "every neutral is perfectly grounded; approximate with finite grounding. " *
            "Zero-sequence behaviour is not captured by the three-wire representation.",
        "phase_to_neutral" =>
            "phase-to-neutral approximation — R block is circulant with " *
            "mutual ≈ ½ self (neutral resistance folded into phase self-terms); " *
            "X block retains the original geometric structure. Valid approximation " *
            "for equal phase/neutral conductors; error grows with grounding impedance.",
        "modified_phase_to_neutral" =>
            "modified phase-to-neutral approximation — both R and X blocks are " *
            "circulant with mutual ≈ ½ self. X is further symmetrised relative to " *
            "the standard phase-to-neutral form, introducing additional modelling " *
            "error particularly for asymmetric cable geometries.",
    )
    _code = Dict{String,String}(
        "kron_reduced"              => "I.PROV.IMPEDANCE_TRANSFORM_KR",
        "phase_to_neutral"          => "I.PROV.IMPEDANCE_TRANSFORM_PN",
        "modified_phase_to_neutral" => "I.PROV.IMPEDANCE_TRANSFORM_MPN",
    )

    for (type, ids) in sort(collect(by_type), by = first)
        push!(findings, Finding(INFO, _code[type], :provenance, :linecode, nothing,
            "$(length(ids)) three-wire linecode(s) match the impedance signature " *
            "of $(_desc[type]): $(join(ids, ", ")).",
            Dict{String,Any}("transform_type" => type,
                             "linecodes"       => ids)))
    end

    Dict{String,Any}("by_linecode" => classified, "by_type" => by_type)
end

# ---------------------------------------------------------------------------
# Geometry cross-check: linecodes that carry a `line_geometry` back-reference
# are re-derived from the geometry and compared to their stored matrices.
# Catches stale hand-edits and geometry changes that were not recompiled
# (analogous to the transformer Yprim cross-check gate).
# ---------------------------------------------------------------------------

function _crosscheck_geometry_linecodes(net::Dict{String,Any},
                                        findings::Vector{Finding})::Dict{String,Any}
    checked = String[]
    mismatched = String[]
    for (id, lc) in get(net, "linecode", Dict())
        lc isa Dict || continue
        gid = get(lc, "line_geometry", nothing)
        gid isa AbstractString || continue
        haskey(get(net, "line_geometry", Dict()), gid) || continue  # E.INT covers this

        tmp = Dict{String,Any}(
            "wire_data"     => get(net, "wire_data", Dict{String,Any}()),
            "line_geometry" => get(net, "line_geometry", Dict{String,Any}()),
            "linecode"      => Dict{String,Any}())
        derived = try
            compile_linecode(tmp, String(gid))
            tmp["linecode"][gid]
        catch err
            push!(findings, Finding(WARNING, "W.PROV.GEOMETRY_UNCOMPILABLE",
                :provenance, :linecode, id,
                "Linecode '$id' references line_geometry '$gid' which fails " *
                "to compile: $(sprint(showerror, err))"))
            continue
        end
        push!(checked, id)

        worst = 0.0
        for prefix in ("R_series_", "X_series_", "B_from_", "B_to_")
            A = _pattern_keys_to_matrix(lc,      prefix)
            D = _pattern_keys_to_matrix(derived, prefix)
            A === nothing && D === nothing && continue
            n = D === nothing ? size(A, 1) : size(D, 1)
            Am = A === nothing ? zeros(n, n) : A
            Dm = D === nothing ? zeros(n, n) : D
            if size(Am) != size(Dm)
                worst = Inf
                continue
            end
            scale = max(maximum(abs.(Am)), maximum(abs.(Dm)), 1e-300)
            worst = max(worst, maximum(abs.(Am - Dm)) / scale)
        end
        if worst > 1e-6
            push!(mismatched, id)
            push!(findings, Finding(WARNING, "W.PROV.GEOMETRY_MISMATCH",
                :provenance, :linecode, id,
                "Linecode '$id' does not match a re-derivation from its " *
                "line_geometry '$gid' (worst relative deviation " *
                "$(round(worst, sigdigits=3))) — the stored matrices are " *
                "stale or hand-edited; recompile with " *
                "compile_linecode(net, \"$gid\"; force=true) or drop the " *
                "back-reference.",
                Dict{String,Any}("line_geometry" => gid,
                                 "relative_deviation" => worst)))
        end
    end
    Dict{String,Any}("n_checked" => length(checked),
                     "checked" => sort(checked),
                     "mismatched" => sort(mismatched))
end

# ---------------------------------------------------------------------------
# Inline absolute line matrices — the same physics gates as linecodes
# (reciprocity, passivity, inductive reactance), reported on the line.
# ---------------------------------------------------------------------------

function _check_inline_line_matrices(net::Dict{String,Any},
                                     findings::Vector{Finding})::Dict{String,Any}
    checked = String[]
    for (id, l) in get(net, "line", Dict())
        l isa Dict && _line_has_inline_z(l) || continue
        R = _pattern_keys_to_matrix(l, "R_series_")
        R === nothing && continue
        push!(checked, id)
        X = _pattern_keys_to_matrix(l, "X_series_")
        n = size(R, 1)
        Xm = (X isa AbstractMatrix && size(X) == size(R)) ? X : zeros(n, n)

        scale = max(maximum(abs.(R)), maximum(abs.(Xm)), 1e-300)
        asym  = max(maximum(abs.(R - transpose(R))),
                    maximum(abs.(Xm - transpose(Xm)))) / scale
        if asym > 1e-6
            push!(findings, Finding(ERROR, "E.PROV.NONRECIPROCAL", :provenance,
                :line, id,
                "Line '$id' inline impedance matrix is not symmetric " *
                "(relative asymmetry $(round(asym, sigdigits=3))) — violates " *
                "reciprocity; likely data corruption.",
                Dict{String,Any}("asymmetry" => asym)))
        end

        ev = eigvals(Symmetric((R + transpose(R)) / 2))
        if minimum(ev) < -1e-9 * max(maximum(abs.(ev)), 1e-12)
            push!(findings, Finding(ERROR, "E.PROV.NONPASSIVE", :provenance,
                :line, id,
                "Line '$id' inline resistance matrix has a negative " *
                "eigenvalue ($(round(minimum(ev), sigdigits=3))) — non-passive.",
                Dict{String,Any}("r_eigenvalues" => collect(ev))))
        end

        if X isa AbstractMatrix && size(X) == size(R)
            bad = [i for i in 1:n if Xm[i, i] <= 0]
            if !isempty(bad)
                push!(findings, Finding(WARNING, "W.PROV.X_NONINDUCTIVE",
                    :provenance, :line, id,
                    "Line '$id' inline matrix has non-positive series " *
                    "self-reactance on diagonal entr" *
                    "$(length(bad) == 1 ? "y" : "ies") $(bad).",
                    Dict{String,Any}("entries" => bad)))
            end
            evx = eigvals(Symmetric((Xm + transpose(Xm)) / 2))
            if minimum(evx) < -1e-9 * max(maximum(abs.(evx)), 1e-12)
                push!(findings, Finding(WARNING, "W.PROV.X_NOT_PSD",
                    :provenance, :line, id,
                    "Line '$id' inline reactance matrix has a negative " *
                    "eigenvalue ($(round(minimum(evx), sigdigits=3))) — the " *
                    "implied inductance matrix is not physically realisable.",
                    Dict{String,Any}("x_eigenvalues" => collect(evx))))
            end
        end

        # Inline lines can carry their own π-shunt blocks — same physics gates
        # as a linecode template (reciprocity, G passivity, B Maxwell sign).
        for prefix in _PI_SHUNT_PREFIXES
            _check_shunt_block_physics!(findings, id, :line, prefix,
                                        _pattern_keys_to_matrix(l, prefix))
        end
    end
    Dict{String,Any}("n_checked" => length(checked), "checked" => sort(checked))
end
