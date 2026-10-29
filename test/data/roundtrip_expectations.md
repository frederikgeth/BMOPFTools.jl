# Reviewed PowerIO 0.11.7 round-trip evidence

`roundtrip_expected_losses.json` pins all 710 path/kind differences for the 36
feature fixtures, with an explicit review classification on each entry. These
are structural observations, **not 710 accepted fidelity losses**. Tests never
regenerate this inventory. Any new or repaired path/kind changes an ordinary
assertion. `roundtrip_review.json` declares the per-fixture terminal maps and
named equivalent-circuit replacements used by `roundtrip_review_helpers.jl`.
No correspondence is inferred from voltage agreement.

## Review of the differences

| Classification | Entries | Review and executable evidence |
|---|---:|---|
| Ideal-source equivalent | 236 | Named one-phase source, +1 Ω source impedance and −1 Ω series branch per original phase. Check endpoints, conductor order, zero charging, exact impedance cancellation and complex EMF. The generated branch rating is a separate defect. |
| Effective linecode or equivalent | 234 | Effective snapshot ids change (`_pio_line_l1` → `_pio_line_l1_1`, and analogous `l`/source ids); unused source definitions disappear. Follow every original line's referenced code and compare its full terminal primitive, including mutuals and charging. The new codes for equivalent branches are covered by their circuit checks. |
| Terminal correspondence | 83 | Explicit maps preserve the physical returns: single-phase `n` → `b`; center-tap secondary `n` → `c`. Compare all original line terminals and primitives, all shunts, and OpenDSS voltages with the declared maps. Neutral-role metadata is assessed separately. |
| Shunt equivalent | 39 | Full core-shunt matrices become named pairwise lines plus residual diagonal shunts. Sum their primitives at the mapped terminals and compare every entry, including off-diagonals and finite grounding. The 1e-17 S diagonal residuals are roundoff; tolerance is 1e-12 S. Their generated line ratings are not certified. |
| Zero defaults | 26 | Absent transformer `g_no_load`/`b_no_load` become explicit zero; original nonzero excitation survives in the separately checked shunt circuit. |
| Source-branch rating defect | 22 | Missing `i_max` becomes 600 A per conductor. This is recorded evidence of powerio#762, never called equivalent. Physical feeder ratings still compare normally. The normative missing-rating preservation assertion is isolated in a minimized expected-failure regression. |
| Neutral-role loss | 22 | A mapped return still conducts and keeps its grounding, but its `neutral_terminal` label is absent. This remains a semantic limitation. A focused `pf_1ph_xfmr` witness expects that role to survive; default export refuses changed correspondence. |
| Unused ground reference | 20 | Dropped `n_ref` declarations belong to unused source-port reference terminals. Before accepting removal, the oracle checks no original element or transformer winding uses that node. All used perfect-ground relations must survive. |
| Tiny-impedance equivalent | 20 | Four single-phase fixtures use a declared auxiliary current node, ±1 Ω branches and three constant-impedance loads. Eliminate only that auxiliary node and compare the complete two-port primitive at 1e-12 relative tolerance. |
| Zero-shunt elision | 8 | An all-zero n-winding core shunt disappears. The shunt primitive comparison confirms every contribution is zero; no nonzero grounding path is removed. |

The ordinary primitive and rating assertions are independent of the structural
inventory: replacing a linecode matrix, moving a shunt return, changing a source
EMF, or changing a physical feeder limit cannot be accepted merely by leaving
the same diff paths in the inventory. Primitive agreement is a finite-fixture
observation, not an OPF equivalence claim (PSK-000007). Neutral/ground distinctions
remain qualified by PSK-000002.

## Independent OpenDSS comparison

`roundtrip_node_maps.json` retains the reviewed source-to-exported OpenDSS node
maps for eight fixtures. Single-phase transformer and autotransformer returns
move from node 4 to 2; center-tap secondary returns move from 4 to 3. These maps
come from the original and generated terminal declarations. The BMOPF mapping
also explicitly records `lvsp.n` → `lvsp.c` for `pf_combined_3ph_split`.

Only the named checked-in fixtures select these maps. External inputs use
identity correspondence or a caller-supplied map; every energized source node
must have a target. The pre-existing near-zero reference threshold is 1e-4 V;
the PF tolerances remain 2 V absolute and 2% relative. They do not certify
primitive or limit preservation; the separate assertions above do that narrower
work. The original `pf_open_delta_reg` deck does not converge and remains an
explicit skip, never numerical agreement.

## Narrow remaining defects and release policy

`test/data/powerio_regressions/unrated_source.dss` is the two-command reproducer
for [powerio#762](https://github.com/eigenergy/powerio/issues/762). The test uses
PowerIO directly, independent of BMOPFTools' admission guard. Only the equality
of the original missing rating and re-imported 600 A rating is expected to fail.
A separate neutral-role witness records the unresolved return-role metadata
loss. No whole-case semantic comparison is an expected failure.

`to_dss` defaults to refusal when its conservative static AC re-import check
cannot establish unchanged component/terminal correspondence and declared
bounds/ratings. Explicit `allow_unverified_ratings=true` permits PF verification
and retains `W.EXPORT.DSS_RATING_UNVERIFIED` plus structured evidence. It does not
remove constraints or infer a recovery map. An explicit zero-A line limit also
returns as 600 A in 0.11.7 and is therefore refused. Positive controls retain
123 A and legitimate 600 A limits. BMOPF JSON remains authoritative for OPF and
Tellegen. The guard does not use a version cutoff; it stays useful until actual
source/target declarations pass, and upstream fixes must promote the narrowly
broken assertions to ordinary tests.
