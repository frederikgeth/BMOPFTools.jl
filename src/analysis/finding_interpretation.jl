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
            "per_phase_impedance_only" => "Only a per-phase (positive-sequence) impedance was supplied and placed on the diagonal."),
        implications = _hints(
            "z0_equals_z1" => "For this nearly uniform diagonal three-conductor block, Z0 and Z1 are approximately equal " *
                "within the classifier tolerance. Review whether this simplification represents the intended return path; " *
                "additional conductors and other network factors remain separate."),
        alternatives = _hints(
            "sequence_coordinates" => "The entries may be sequence values (Z0, Z1, Z2) stored as if they were phase values.",
            "negligible_series_coupling" => "Coupling may be genuinely negligible, e.g. widely spaced single-core cables."),
        checks = _hints(
            "coordinate_basis" => "Check whether the supplied entries are in phase or sequence coordinates.",
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
            "original_conductors" => "Inspect the original conductor model: was a neutral conductor specified?",
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
            "other_parameterisation" => "Another parameterisation can share the same approximate matrix pattern."),
        checks = _hints(
            "transformation_record" => "Compare with the source four-wire impedances and any declared phase-to-neutral transformation.",
            "return_path" => "Review conductor sizes, grounding and the intended return-current model.")),
    "I.PROV.IMPEDANCE_TRANSFORM_MPN" => (
        explanations = _hints(
            "modified_phase_to_neutral" => "A phase-to-neutral equivalent (R mutual ≈ ½ R self) whose reactance was also symmetrised."),
        implications = _hints(
            "grounding_sensitive" => "Review the phase-to-neutral assumptions about earth shunts, device earth injection " *
                "and single-point neutral grounding. Error is not determined by grounding impedance alone.",
            "geometric_unbalance_lost" => "Reactance symmetrisation adds an approximation that removes phase-pair " *
                "reactance asymmetry; compare its effect for the actual geometry and study."),
        alternatives = _hints(
            "other_parameterisation" => "A symmetric physical or authored equivalent can share this pattern."),
        checks = _hints(
            "transformation_record" => "Compare with the source impedances and any resistance folding or reactance symmetrisation.",
            "asymmetry" => "Review whether the approximation keeps the asymmetry the study needs.")),
    "I.OPS.FEEDER_LONG" => (
        explanations = _hints(
            "unit_slip" => "Metre values interpreted as kilometres upstream, or a km-to-m conversion applied twice.",
            "long_rural_feeder" => "A genuinely long rural or SWER-style feeder."),
        implications = _hints(
            "impedance_scaled" => "For per-length linecodes, lengths 1000 times too large also scale section impedances " *
                "by 1000, potentially distorting voltages and losses. Inline absolute section matrices do not scale with length."),
        alternatives = _hints(
            "equivalent_length" => "An electrical or equivalent length rather than the route length."),
        checks = _hints(
            "spot_check_lengths" => "Compare a few line lengths and linecode units with maps or source data.",
            "impedance_units" => "Check per-km versus per-m impedance units separately: they affect the electrical model " *
                "even when the declared-distance metric is correct.",
            "voltage_regulation" => "If the feeder is genuinely long, check that regulators or tap ranges are modelled.")),
    "I.OPS.FEEDER_SHORT" => (
        explanations = _hints(
            "stub_or_interconnect" => "A service drop, substation bus or short interconnect rather than a feeder.",
            "default_or_unit_slip" => "The OpenDSS default `length=1` left in place, or kilometre values stored as metres " *
                "without multiplying by 1000."),
        implications = _hints(
            "impedance_negligible" => "Too-short lengths make per-length linecode section impedances too small, " *
                "potentially hiding voltage drops and losses. Inline absolute section matrices do not scale with length."),
        alternatives = _hints(
            "compact_site" => "A compact industrial or campus site can be genuinely short."),
        checks = _hints(
            "spot_check_lengths" => "Compare a few line lengths and linecode units with maps or source data.")),
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

function _finding_interpretation(code, observations; supporting_context=Dict{String,Any}())
    spec = get(_FINDING_INTERPRETATIONS, code, nothing)
    spec === nothing && error("No Finding interpretation registered for $code")
    implications = deepcopy(spec.implications)
    if code in ("I.PROV.SEQ_DERIVED", "I.PROV.DECOUPLED_PHASES")
        matrices = collect(values(get(observations, "by_linecode", Dict())))
        n_extra = count(m -> get(m, "phase_block_only", false), matrices)
        if n_extra > 0
            if code == "I.PROV.SEQ_DERIVED" && n_extra == length(matrices)
                filter!(h -> h["id"] != "neutral_inside_z0", implications)
            end
            append!(implications, _hints("retained_conductors" => "$n_extra of these matrices retain conductors " *
                "outside the inspected phase block. A neutral can remain explicit; inspect its coupling and grounding " *
                "before drawing conclusions about phase-to-neutral unbalance or recovery."))
        end
    end
    if code in ("I.OPS.FEEDER_LONG", "I.OPS.FEEDER_SHORT")
        counts = get(observations, "impedance_basis_counts", Dict())
        if get(counts, "absolute_section", 0) > 0 && get(counts, "length_scaled", 0) == 0 && get(counts, "unresolved", 0) == 0
            implications = _hints("absolute_section_impedance" => "These lines use inline absolute section impedances. " *
                "Changing their declared lengths changes this distance metric, while their impedance matrices stay unchanged. " *
                "Review electrical parameters separately if voltage drops or losses look implausible.")
        end
    end
    Dict{String,Any}(
        "observations" => observations,
        "possible_explanations" => deepcopy(spec.explanations),
        "implications" => implications,
        "alternatives" => deepcopy(spec.alternatives),
        "suggested_checks" => deepcopy(spec.checks),
        "supporting_context" => supporting_context,
        "automation_guidance" => Dict{String,Any}(
            "disposition" => "review",
            "additional_evidence_required_for_model_changes" => true),
    )
end

_interpretation_ids(list) = [h["id"] for h in list]
