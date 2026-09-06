# Reviewed round-trip evidence

`roundtrip_expected_losses.json` records each semantic difference's path and kind
for the 36 feature fixtures, checked with released PowerIO.jl/native PowerIO
0.11.0 (including core-shunt preservation and complete four-winding reactances). These expectations are reviewed inputs, not generated during tests.
A new loss or a fixed loss changes a normal assertion; the whole-case expected
failure also becomes an unexpected pass when the final loss is repaired. The
numbers or fields must never be relaxed merely to make a dependency bump pass.

`roundtrip_node_maps.json` declares the complete source-to-exported node mapping
for eight named fixtures. The single-phase transformer and autotransformer
export renumbers their winding return from node 4 to node 2. Center-tap exports
renumber the primary/source return to node 2 and the secondary return to node 3;
secondary phase nodes 1 and 2 remain unchanged. These maps come from the coil,
load, and grounding terminal declarations in the source and exported decks,
not from matching voltage magnitudes. They permit the oracle to check return
voltages that the old intersection-only comparison skipped. They do not remove
the corresponding structural/neutral-label differences from the loss ledger.

Only exact paths to the checked-in fixtures select these maps. External inputs
use identity correspondence or a caller-supplied map, and every energized source
node must have a target. The threshold for ignoring effectively zero reference
voltages remains the pre-existing 1e-4 V. The unchanged regression tolerances
are 2 V absolute and 2% relative; tighter standalone sweep results are separate.

The original `pf_open_delta_reg` deck does not converge in the independent
OpenDSS solve and is reported as skipped. That is not numerical agreement.

The coordinated core-shunt update changes the representation under test:
nonzero transformer `g_no_load`/`b_no_load` become explicit ordinary bus shunts
at intake. The current DSS exporter does not preserve all of their coil
incidence: single-phase return entries disappear, polyphase/center-tap matrix
entries change, and zero-valued n-winding shunts disappear entirely. Zero
admittance removal is structurally different but electrically harmless; loss of
a nonzero shunt connection is a remaining export limitation. The reviewed
snapshot contains 264 differences. The core-shunt update changed the original
168-entry ledger to 265 entries (32 old core-field differences replaced by 129
explicit-shunt and zero-default differences). Complete four-winding reactance
preservation removed two entries. The unequal-kVA fixture adds one harmless
zero-shunt omission, bringing the current total to 264.
No whole feature case becomes structurally lossless. These are recorded export
limitations, not evidence that the stronger intake was a regression or that the
coarse voltage gate validates every shunt entry.

The unequal-kVA case also has an independent import-to-OpenDSS primitive
admittance test in `test/powerio_numerical_tests.jl`. Its known #356 failure is
separate from this DSS round-trip ledger: importing the same wrong resistance
at both ends can make a structural round trip pass. Two resistance assertions
(smaller/larger third-winding ratings) and one primitive-admittance assertion
remain `@test_broken`; upstream fixes must promote them to ordinary assertions.
