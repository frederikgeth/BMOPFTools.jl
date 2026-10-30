# Review guidance attached to INFO/WARNING Findings. Each record says what the
# observation most likely means, why it matters if true, what else could explain
# it and what to check next. These are hypotheses for a human or an AI assistant
# to investigate, never an inferred cause or an automatic repair.
#
# Lists are ordered: the first explanation is the usual reading, the first check
# is the cheapest useful one. Each entry is `{"id", "text"}` so tools can match
# stable ids while people read the text.

_hints(pairs...) = [Dict{String,Any}("id" => id, "text" => text) for (id, text) in pairs]

const _KRON_IMPLICATIONS = (
    "neutral_assumed_grounded" => "The usual neutral-elimination model assumes zero neutral voltage at the line endpoints. " *
        "It cannot predict neutral voltage rise when that assumption is inappropriate.",
    "neutral_loss_attribution" => "Under the exact boundary assumptions, neutral dissipation remains in the reduced " *
        "port impedance. Separate neutral current and loss attribution require the source blocks or a recovery map.",
    "unbalance_understated" => "If an actual neutral develops voltage under unbalanced loading (e.g. single-phase PV or EV), " *
        "a zero-neutral-voltage approximation can give misleading phase voltages and losses.")

const _FINDING_INTERPRETATIONS = Dict{String,NamedTuple}(
    "I.PROV.SEQ_DERIVED" => (
        explanations = _hints(
            "sequence_parameterisation" => "Phase impedances were built from sequence values (r1, x1, r0, x0); " *
                "that construction always gives equal self and equal mutual entries.",
            "transposition_assumption" => "A transposition or phase-symmetry assumption averaged out the geometric coupling."),
        implications = _hints(
            "geometric_unbalance_lost" => "The inspected three-conductor series block contains no phase-pair geometric " *
                "asymmetry. Coupling to additional conductors, grounding, shunts and other equipment can still create unbalance.",
            "neutral_inside_z0" => "If only three phase coordinates remain, return-path effects may be folded into Z0; " *
                "recovering an omitted neutral then needs source information. A larger matrix can still retain a neutral explicitly."),
        alternatives = _hints(
            "symmetric_construction" => "A physically symmetric arrangement (e.g. trefoil or triplex cable) gives nearly this pattern."),
        checks = _hints(
            "parameter_source" => "Compare with the source sequence values, conductor geometry or transposition specification.",
            "study_symmetry" => "For unbalance or neutral studies, inspect retained conductors and their coupling. " *
                "Use geometry-based data (`compile_linecode` from `line_geometry`) when the omitted geometric asymmetry matters.")),
    "I.PROV.DECOUPLED_PHASES" => (
        explanations = _hints(
            "per_phase_impedance_only" => "Phase impedances may have been supplied independently without mutual series " *
                "coupling; a positive-sequence-only diagonal is one common uniform case."),
        implications = _hints(
            "z0_equals_z1" => "For this nearly uniform diagonal three-conductor block, Z0 and Z1 are approximately equal " *
                "within the classifier tolerance. Review whether this simplification represents the intended return path; " *
                "additional conductors and other network factors remain separate."),
        alternatives = _hints(
            "sequence_coordinates" => "The entries may be sequence values (Z0, Z1, Z2) stored as if they were phase values.",
            "negligible_series_coupling" => "Coupling may be genuinely negligible, e.g. widely spaced single-core cables.",
            "prior_reduction" => "A prior Schur reduction can also yield a diagonal block when its correction cancels " *
                "the original mutual entries; this signature alone does not exclude Kron history."),
        checks = _hints(
            "coordinate_basis" => "Check whether the supplied entries are in phase or sequence coordinates; " *
                "`compile_linecode` from `line_geometry` gives coupled phase-frame matrices when geometry is known.",
            "other_coupling" => "Shunts, transformers and connections can still couple phases; inspect them before " *
                "treating the phases as independent networks.")),
    "I.PROV.IMPEDANCE_TRANSFORM_KR" => (
        explanations = _hints(
            "kron_reduction" => "A four-wire (phases + neutral) matrix had its neutral row and column eliminated (Kron reduction)."),
        implications = _hints(_KRON_IMPLICATIONS...),
        alternatives = _hints(
            "native_three_wire" => "The conductor may genuinely be three-wire. This is normal at MV and HV, where " *
                "Carson's earth return is already folded into the matrix.",
            "other_equivalent" => "A phase-to-neutral transformation, another equivalent or incomplete data can also omit the neutral."),
        checks = _hints(
            "original_conductors" => "Inspect the original conductor model: was a neutral conductor specified? If so, " *
                "rebuild a four-wire linecode with `compile_linecode` from `line_geometry`.",
            "grounding_and_recovery" => "If neutral rise matters, review the zero-neutral-voltage assumption and use " *
                "the original four-wire parameters and grounding to re-solve when needed. Current/loss recovery from source " *
                "blocks describes the reduction's assumed boundary conditions.")),
    "I.PROV.KRON_LIKELY" => (
        explanations = _hints(
            "kron_reduction" => "The LV neutral was eliminated by Kron reduction before or during conversion; " *
                "LV distribution is usually physically four-wire."),
        implications = _hints(_KRON_IMPLICATIONS...),
        alternatives = _hints(
            "native_three_wire" => "Some LV systems are genuinely three-wire (e.g. delta-supplied or IT-earthed networks).",
            "other_equivalent" => "A phase-to-neutral transformation, another equivalent or incomplete data can also omit the neutral."),
        checks = _hints(
            "original_conductors" => "Check the source data or GIS for a neutral conductor on these feeders.",
            "grounding_and_recovery" => "If neutral rise matters, obtain the original conductor and grounding data " *
                "and solve an explicit-neutral model when the reduced assumptions are inappropriate.")),
    "I.PROV.IMPEDANCE_TRANSFORM_PN" => (
        explanations = _hints(
            "phase_to_neutral" => "The neutral resistance was folded into each phase: with equal phase and neutral " *
                "resistance this gives R mutual ≈ ½ R self, while reactance keeps its geometric variation."),
        implications = _hints(
            "grounding_sensitive" => "The phase-to-neutral transformation is exact with no conductor-to-earth shunts, no device " *
                "current injection into earth, and one grounding point per continuous neutral section. Multiple earth-return paths " *
                "can break these assumptions; a grounding-impedance value alone does not determine the error.",
            "conductor_size_fingerprint" => "Similar phase and neutral resistances explain the mutual/self ratio near one half. " *
                "That fingerprint is not an accuracy condition; the transformation also applies to unequal conductors.",
            "neutral_recovery" => "Neutral current and voltage can be recovered with the source data under the documented " *
                "single-grounded assumptions; a three-wire matrix alone does not supply all recovery information."),
        alternatives = _hints(
            "other_parameterisation" => "Another parameterization can share the same approximate matrix pattern."),
        checks = _hints(
            "transformation_record" => "Compare with the source four-wire impedances and any declared phase-to-neutral transformation.",
            "return_path" => "Review conductor sizes, grounding and the intended return-current model.")),
    "I.PROV.IMPEDANCE_TRANSFORM_MPN" => (
        explanations = _hints(
            "modified_phase_to_neutral" => "A phase-to-neutral equivalent (R mutual ≈ ½ R self) whose reactance was also symmetrized."),
        implications = _hints(
            "grounding_sensitive" => "Review the phase-to-neutral assumptions about earth shunts, device earth injection " *
                "and single-point neutral grounding. Error is not determined by grounding impedance alone.",
            "geometric_unbalance_lost" => "Reactance symmetrization adds an approximation that removes phase-pair " *
                "reactance asymmetry; compare its effect for the actual geometry and study."),
        alternatives = _hints(
            "other_parameterisation" => "A symmetric physical or authored equivalent can share this pattern."),
        checks = _hints(
            "transformation_record" => "Compare with the source impedances and any resistance folding or reactance symmetrization.",
            "asymmetry" => "Review whether the approximation keeps the asymmetry the study needs.")),
    "I.OPS.FEEDER_LONG" => (
        explanations = _hints(
            "unit_slip" => "Meter values interpreted as kilometers upstream, or a km-to-m conversion applied twice.",
            "long_rural_feeder" => "A genuinely long rural or SWER-style feeder."),
        implications = _hints(
            "impedance_scaled" => "For per-length linecodes, lengths 1000 times too large also scale section impedances " *
                "by 1000, potentially distorting voltages and losses."),
        alternatives = _hints(
            "equivalent_length" => "An electrical or equivalent length rather than the route length."),
        checks = _hints(
            "spot_check_lengths" => "Compare a few line lengths and linecode units with maps or source data. With bus " *
                "coordinates, `W.GEO.LINE_SHORTER_THAN_CHORD` compares lengths with endpoint distances.",
            "impedance_units" => "Check per-km versus per-m impedance units separately: they affect the electrical model " *
                "even when the declared-distance metric is correct.",
            "voltage_regulation" => "If the feeder is genuinely long, check that regulators or tap ranges are modeled.")),
    "I.OPS.FEEDER_SHORT" => (
        explanations = _hints(
            "stub_or_interconnect" => "A service drop, substation bus or short interconnect rather than a feeder.",
            "default_or_unit_slip" => "The OpenDSS default `length=1` left in place, or kilometer values stored as meters " *
                "without multiplying by 1000."),
        implications = _hints(
            "impedance_negligible" => "Too-short lengths make per-length linecode section impedances too small, " *
                "potentially hiding voltage drops and losses."),
        alternatives = _hints(
            "compact_site" => "A compact industrial or campus site can be genuinely short."),
        checks = _hints(
            "spot_check_lengths" => "Compare a few line lengths and linecode units with maps or source data. With bus " *
                "coordinates, `W.GEO.LINE_SHORTER_THAN_CHORD` compares lengths with endpoint distances.")),
    "W.OPS.XFMR_UNCONSTRAINED" => (
        explanations = _hints(
            "nameplate_only" => "A top-level `s_rating`, if present, is only a nameplate here. Two-winding subtypes turn " *
                "it into a per-coil cap, but `n_winding` transformers need finite per-winding `i_max`/`s_max`."),
        implications = _hints(
            "unbounded_loading" => "The OPF can load these windings without a thermal limit, so a solution may rely " *
                "on transformer capacity that does not exist."),
        alternatives = _hints(
            "intentional_omission" => "Caps may be omitted or explicitly set to Inf on purpose, e.g. for an ideal-transformer " *
                "or hosting-capacity bound study."),
        checks = _hints(
            "add_winding_caps" => "Add per-winding `s_max` (e.g. each winding's nameplate rating) or `i_max` from the datasheet.")),
)

# Where to read more. Pages are docs/src files; `section` is the heading text
# (checked by tests) so a reader can find it on the page.
const _DOCS_URL = "https://frederikgeth.github.io/BMOPFTools.jl/dev/"
_doc(page, section, anchor="") = Dict{String,Any}("page" => page, "section" => section,
    "url" => _DOCS_URL * replace(page, ".md" => "/") * (isempty(anchor) ? "" : "#" * anchor))
const _LEARN_MORE = Dict{String,Vector{Dict{String,Any}}}(
    "I.PROV.SEQ_DERIVED" => [_doc("methodology.md", "Sequence-derived matrices and Z₁/Z₀ recovery"),
        _doc("semantic_modeling.md", "The line-impedance fidelity ladder", "impedance-ladder")],
    "I.PROV.DECOUPLED_PHASES" => [_doc("tutorial_grounding.md", "7. The Fortescue transform vs sequence decoupling"),
        _doc("methodology.md", "Impedance matrix invariants vs fingerprints")],
    "I.PROV.IMPEDANCE_TRANSFORM_KR" => [_doc("tutorial_grounding.md", "5. Kron reduction is an assumption, not a simplification"),
        _doc("methodology.md", "Kron reduction, grounding and earthing zones")],
    "I.PROV.KRON_LIKELY" => [_doc("tutorial_grounding.md", "5. Kron reduction is an assumption, not a simplification"),
        _doc("methodology.md", "Kron reduction, grounding and earthing zones")],
    "I.PROV.IMPEDANCE_TRANSFORM_PN" => [_doc("semantic_modeling.md", "The line-impedance fidelity ladder", "impedance-ladder"),
        _doc("tutorial_grounding.md", "5. Kron reduction is an assumption, not a simplification")],
    "I.PROV.IMPEDANCE_TRANSFORM_MPN" => [_doc("semantic_modeling.md", "The line-impedance fidelity ladder", "impedance-ladder"),
        _doc("tutorial_impedance_models.md", "The idealization and its symmetry")],
    "I.OPS.FEEDER_LONG" => [_doc("tutorial_line_geometry.md", "Absolute impedances: matrices on the line itself"),
        _doc("methodology.md", "OpenDSS default fingerprints")],
    "I.OPS.FEEDER_SHORT" => [_doc("tutorial_line_geometry.md", "Absolute impedances: matrices on the line itself"),
        _doc("methodology.md", "OpenDSS default fingerprints")],
    "W.OPS.XFMR_UNCONSTRAINED" => [_doc("transformer_models.md", "Nameplate rating (`s_rating`) as a loading cap"),
        _doc("opf.md", "Current vs. apparent-power limits", "Current-vs-apparent-power-limits")],
)

_by_linecode(observations) = collect(values(get(observations, "by_linecode", Dict())))
_has_extra_conductor(m) = get(m, "phase_block_only", false) === true
_uncoupled_extra(m) = _has_extra_conductor(m) && (r = get(m, "additional_conductor_coupling_ratio", nothing);
    r isa Real && r < 1e-6)

# A missing/invalid nominal voltage or map is distinct from known MV/HV use.
function _kron_context_kind(context)
    n = get(context, "n_lines", 0)
    n == 0 && return "unused"
    get(context, "n_lv_without_neutral_lines", 0) > 0 && return "lv_without_neutral"
    get(context, "n_mv_hv_lines", 0) == n && return "mv_hv_only"
    get(context, "n_lv_with_neutral_lines", 0) == n && return "lv_with_neutral"
    "unassessed"
end

function _finding_interpretation(code, observations; supporting_context=Dict{String,Any}())
    spec = get(_FINDING_INTERPRETATIONS, code, nothing)
    spec === nothing && error("No Finding interpretation registered for $code")
    explanations = deepcopy(spec.explanations)
    implications = deepcopy(spec.implications)
    if code in ("I.PROV.SEQ_DERIVED", "I.PROV.DECOUPLED_PHASES")
        matrices = _by_linecode(observations)
        n_extra = count(_has_extra_conductor, matrices)
        if n_extra > 0
            if code == "I.PROV.SEQ_DERIVED" && n_extra == length(matrices)
                filter!(h -> h["id"] != "neutral_inside_z0", implications)
            end
            if code == "I.PROV.SEQ_DERIVED"
                explanations[1]["text"] = "Sequence values can define the phase block of a larger matrix. " *
                    "A converter can materialize extra conductors from sequence input, or neutral parameters can " *
                    "be supplied separately; conductor count alone does not select the construction method."
            end
            append!(implications, _hints("retained_conductors" => "$n_extra of these matrices retain conductors " *
                "outside the inspected phase block. A neutral can remain explicit; inspect its coupling and grounding " *
                "before drawing conclusions about phase-to-neutral unbalance or recovery."))
        end
        n_uncoupled = count(_uncoupled_extra, matrices)
        n_uncoupled > 0 && append!(implications, _hints("uncoupled_extra_conductor" => "$n_uncoupled of these " *
            "matrices keep an extra conductor with no series coupling to the phases. A real neutral shares flux with " *
            "the phases, so this may be a placeholder or simplified neutral."))
        if code == "I.PROV.DECOUPLED_PHASES"
            n_nonuniform = count(m -> get(m, "diag_spread", 0.0) >= 1e-6, matrices)
            if n_nonuniform > 0
                n_nonuniform == length(matrices) && filter!(h -> h["id"] != "z0_equals_z1", implications)
                append!(implications, _hints("nonuniform_diagonal" => "$n_nonuniform of these phase blocks have " *
                    "unequal self impedances despite negligible mutual coupling. Their Fortescue sequence matrices " *
                    "can still have off-diagonal coupling; independent phase equations do not imply independent sequence networks."))
            end
        end
    end
    if code == "I.PROV.IMPEDANCE_TRANSFORM_KR"
        contexts = collect(values(supporting_context))
        kinds = _kron_context_kind.(contexts)
        if !isempty(kinds) && all(==("unused"), kinds)
            implications = _hints("unused_linecode_context" => "These templates are not used by a line in this case. " *
                "Review their original conductor model before reusing them; no voltage tier is inferred from the matrices.")
        elseif !isempty(kinds) && all(k -> k in ("mv_hv_only", "unused"), kinds)
            implications = _hints("known_mv_hv_context" => "All referenced uses are on known MV/HV lines. " *
                "Three-wire construction is common there; review neutral-related consequences if the original " *
                "conductor data show an eliminated neutral.")
        elseif any(==("unassessed"), kinds) || any(c -> get(c, "n_unassessed_lines", 0) > 0, contexts)
            append!(implications, _hints("unassessed_use_context" => "Some uses have incomplete or mixed voltage/map " *
                "evidence. This does not establish MV/HV use or absence of a physical neutral. Check the nominal " *
                "voltages and original conductor data before dismissing neutral-related consequences."))
        end
    end
    if code in ("I.OPS.FEEDER_LONG", "I.OPS.FEEDER_SHORT")
        counts = get(observations, "impedance_basis_counts", Dict())
        n_abs = get(counts, "absolute_section", 0)
        if n_abs > 0 && get(counts, "length_scaled", 0) == 0 && get(counts, "unresolved", 0) == 0
            implications = _hints("absolute_section_impedance" => "These lines use inline absolute section impedances. " *
                "Changing their declared lengths changes this distance metric, while their impedance matrices stay unchanged. " *
                "Review electrical parameters separately if voltage drops or losses look implausible.")
        elseif n_abs > 0
            append!(implications, _hints("absolute_section_impedance_mixed" => "$n_abs line(s) in this zone use " *
                "inline absolute impedances, which do not change with length; only the linecode lines scale."))
        end
    end
    Dict{String,Any}(
        "observations" => observations,
        "possible_explanations" => explanations,
        "implications" => implications,
        "alternatives" => deepcopy(spec.alternatives),
        "suggested_checks" => deepcopy(spec.checks),
        "supporting_context" => supporting_context,
        "learn_more" => deepcopy(get(_LEARN_MORE, code, Dict{String,Any}[])),
        "automation_guidance" => Dict{String,Any}(
            "disposition" => "review",
            "additional_evidence_required_for_model_changes" => true),
    )
end

_interpretation_ids(list) = [h["id"] for h in list]
