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
    "neutral_assumed_grounded" => "Kron reduction is exact only if the neutral is held at 0 V at every bus. " *
        "Neutral voltage rise, neutral current and neutral losses are not visible in results from this model.",
    "unbalance_understated" => "Under unbalanced loading (e.g. single-phase PV or EV) the eliminated neutral " *
        "would have carried return current, so phase voltages and losses can be optimistic.")

const _FINDING_INTERPRETATIONS = Dict{String,NamedTuple}(
    "I.PROV.SEQ_DERIVED" => (
        explanations = _hints(
            "sequence_parameterisation" => "Phase impedances were built from sequence values (r1, x1, r0, x0); " *
                "that construction always gives equal self and equal mutual entries.",
            "transposition_assumption" => "A transposition or phase-symmetry assumption averaged out the geometric coupling."),
        implications = _hints(
            "geometric_unbalance_lost" => "The lines cannot create the voltage unbalance that untransposed conductor " *
                "geometry causes; unbalance comes only from loads and connections.",
            "neutral_inside_z0" => "Any neutral or earth return is folded into the zero-sequence value, so neutral " *
                "quantities cannot be recovered from this data."),
        alternatives = _hints(
            "symmetric_construction" => "A physically symmetric arrangement (e.g. trefoil or triplex cable) gives nearly this pattern."),
        checks = _hints(
            "parameter_source" => "Compare with the source sequence values, conductor geometry or transposition specification.",
            "study_symmetry" => "If the study is about unbalance or neutral voltage, prefer geometry-based data " *
                "(`compile_linecode` from `line_geometry`) over sequence values.")),
    "I.PROV.DECOUPLED_PHASES" => (
        explanations = _hints(
            "per_phase_impedance_only" => "Only a per-phase (positive-sequence) impedance was supplied and placed on the diagonal."),
        implications = _hints(
            "z0_equals_z1" => "With no mutual coupling the zero-sequence impedance equals the positive-sequence " *
                "impedance; on real lines Z0 is usually several times larger, so unbalanced loading and earth-return effects are misrepresented."),
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
            "grounding_and_recovery" => "If neutral voltage matters (e.g. LV hosting capacity), rebuild a four-wire " *
                "linecode from geometry or recover the eliminated neutral quantities.")),
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
            "grounding_and_recovery" => "If neutral voltage matters, add the neutral conductor and its grounding explicitly.")),
    "I.PROV.IMPEDANCE_TRANSFORM_PN" => (
        explanations = _hints(
            "phase_to_neutral" => "The neutral resistance was folded into each phase: with equal phase and neutral " *
                "resistance this gives R mutual ≈ ½ R self, while reactance keeps its geometric variation."),
        implications = _hints(
            "grounding_sensitive" => "Accurate when phase and neutral conductors are alike and grounding is good; the " *
                "error grows with grounding impedance and with neutral/phase size mismatch. Neutral voltage is not explicit."),
        alternatives = _hints(
            "other_parameterisation" => "Another parameterisation can share the same approximate matrix pattern."),
        checks = _hints(
            "transformation_record" => "Compare with the source four-wire impedances and any declared phase-to-neutral transformation.",
            "return_path" => "Review conductor sizes, grounding and the intended return-current model.")),
    "I.PROV.IMPEDANCE_TRANSFORM_MPN" => (
        explanations = _hints(
            "modified_phase_to_neutral" => "A phase-to-neutral equivalent (R mutual ≈ ½ R self) whose reactance was also symmetrised."),
        implications = _hints(
            "grounding_sensitive" => "Shares the phase-to-neutral error, which grows with grounding impedance.",
            "geometric_unbalance_lost" => "Symmetrised reactance removes geometric unbalance; the error is largest for flat or asymmetric layouts."),
        alternatives = _hints(
            "other_parameterisation" => "A symmetric physical or authored equivalent can share this pattern."),
        checks = _hints(
            "transformation_record" => "Compare with the source impedances and any resistance folding or reactance symmetrisation.",
            "asymmetry" => "Review whether the approximation keeps the asymmetry the study needs.")),
    "I.OPS.FEEDER_LONG" => (
        explanations = _hints(
            "unit_slip" => "Lengths entered in km where metres were expected, or a linecode impedance per km used as per m.",
            "long_rural_feeder" => "A genuinely long rural or SWER-style feeder."),
        implications = _hints(
            "impedance_scaled" => "If lengths are 1000× too large, so are the line impedances: expect voltage-limit " *
                "infeasibility, very large losses or a voltage profile that collapses toward the feeder end."),
        alternatives = _hints(
            "equivalent_length" => "An electrical or equivalent length rather than the route length."),
        checks = _hints(
            "spot_check_lengths" => "Compare a few line lengths and linecode units with maps or source data.",
            "voltage_regulation" => "If the feeder is genuinely long, check that regulators or tap ranges are modelled.")),
    "I.OPS.FEEDER_SHORT" => (
        explanations = _hints(
            "stub_or_interconnect" => "A service drop, substation bus or short interconnect rather than a feeder.",
            "default_or_unit_slip" => "The OpenDSS default `length=1` left in place, or metres entered where km were expected."),
        implications = _hints(
            "impedance_negligible" => "If lengths are too short, impedances are too: voltages look flat and losses " *
                "vanish, which hides the constraints an OPF study is meant to find."),
        alternatives = _hints(
            "compact_site" => "A compact industrial or campus site can be genuinely short."),
        checks = _hints(
            "spot_check_lengths" => "Compare a few line lengths and linecode units with maps or source data.")),
    "W.OPS.XFMR_UNCONSTRAINED" => (
        explanations = _hints(
            "nameplate_only" => "The rating is only in top-level `s_rating`. Two-winding subtypes turn `s_rating` " *
                "into a per-coil cap, but `n_winding` transformers are limited only by per-winding `i_max`/`s_max`."),
        implications = _hints(
            "unbounded_loading" => "The OPF can load these windings without a thermal limit, so a solution may rely " *
                "on transformer capacity that does not exist."),
        alternatives = _hints(
            "intentional_omission" => "Caps may be omitted on purpose, e.g. for an ideal-transformer or hosting-capacity bound study."),
        checks = _hints(
            "add_winding_caps" => "Add per-winding `s_max` (e.g. each winding's nameplate rating) or `i_max` from the datasheet.")),
)

function _finding_interpretation(code, observations; supporting_context=Dict{String,Any}())
    spec = get(_FINDING_INTERPRETATIONS, code, nothing)
    spec === nothing && error("No Finding interpretation registered for $code")
    Dict{String,Any}(
        "observations" => observations,
        "possible_explanations" => deepcopy(spec.explanations),
        "implications" => deepcopy(spec.implications),
        "alternatives" => deepcopy(spec.alternatives),
        "suggested_checks" => deepcopy(spec.checks),
        "supporting_context" => supporting_context,
        "automation_guidance" => Dict{String,Any}(
            "disposition" => "review",
            "additional_evidence_required_for_model_changes" => true),
    )
end

_interpretation_ids(list) = [h["id"] for h in list]
