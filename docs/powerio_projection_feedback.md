# PowerIO import/export feedback — OpenDSS ⇄ BMOPF fidelity

Feedback for the [PowerIO.jl](https://github.com/eigenergy/PowerIO.jl) developers,
generated while building **OPF-solution → OpenDSS-snapshot validation** in
BMOPFTools. The idea: take a *solved* OPF case, pin every controllable device to
its optimal setpoint (`project_solution`), export the snapshot to OpenDSS
(`to_dss`, via PowerIO), solve it in OpenDSS, and check that OpenDSS reproduces the
OPF-predicted bus voltages. This exercises the BMOPF→DSS writer on live, dispatched
cases and surfaces exactly which setpoints/components survive export.

Items 1–5 are **export** (`to_dss`) findings from that study; items 6–8 are
**import** (`from_dss`) findings — logic BMOPFTools carries today to compensate for
lossy PowerIO output that would be better fixed upstream. A companion document,
[`powerio_ibr_mapping.md`](powerio_ibr_mapping.md), gives the concrete `ibr` ⇄
PVSystem/Generator + volt-var/volt-watt mapping for items 2–3.

Findings are ordered by impact. Reproduce them with:

```
julia --project=test scripts/projection_fidelity.jl
# → output/projection_fidelity/{projection_matrix.md, projection_failure_map.md, projection_reports.json}
```

The three-way check is `A ≈ B ≈ C` where **A** = the OPF prediction, **B** =
`solve_pf(project_solution(net, result))` (BMOPF's own determined re-solve), **C**
= OpenDSS solving `to_dss(...)`. **A ≈ B holds to ~1e-7 V for every case** — the
projection is exact — so any `A ≈ B ✗ C` isolates a PowerIO export issue.

## Summary

| # | Issue | Direction | Impact |
|---|-------|-----------|--------|
| 1 | Transformer winding `kv` exported as `NaN` | `to_dss` | **Blocker** — no deck with a transformer solves in OpenDSS |
| 2 | BMOPF `ibr` not exported | `to_dss` | High — inverter/DER dispatch is silently dropped |
| 3 | OpenDSS `PVSystem`/`Generator` not imported | `from_dss` | High — generation is dropped on import |
| 4 | Loads exported without `Vminpu`/`Vmaxpu` | `to_dss` | Medium — OpenDSS clamps constant-power loads, ~1–4 V drift |
| 5 | Three-phase / 4-wire line snapshot drift | `to_dss` | Medium — ~60–135 V mismatch on multi-phase load buses |
| 6 | Transformer fidelity gaps in the `bmopf` export | `from_dss` | Resolved by PowerIO v0.6.2 for the validated transformer set |
| 7 | 3+-winding transformers dropped from `bmopf` export | `from_dss` | Resolved by PowerIO v0.6.2 for the validated `n_winding` cases |
| 8 | Transformer `rneut`/`xneut` (internal winding grounding) dropped from **both** exports | both | Resolved by PowerIO v0.6.2 |

Items 2 and 3 are worked around downstream (BMOPFTools converts pinned
generators/IBRs to equivalent **negative constant-power loads** before export, via
`dispatch_as_loads`, since loads *do* export), so validation is possible today —
but a direct mapping is preferable. **Items 6–8 are the subject of the new
"Import direction" section below** — they are the reason `from_dss`
([src/io/from_dss.jl](../src/io/from_dss.jl)) fetches a *second* PowerIO export and
reconciles it.

---

## 1. Transformer winding `kv` exported as `NaN` (blocker)

`to_dss` writes every transformer winding voltage as `NaN`, even though the BMOPF
net carries `v_nom_from`/`v_nom_to`:

```
# from_dss(pf_dy_xfmr_tap.dss) → net has v_nom_from=11000, v_nom_to=415
# to_dss(net) emits:
New Transformer.t1 phases=3 windings=2 buses=(hv.1.2.3, lv.1.2.3.4)
  conns=(delta, wye) kvs=(NaN, NaN) kvas=(500, 500) %Rs=(0, 0) taps=(1, 1)
```

OpenDSS cannot solve a deck with `kvs=(NaN,NaN)`, so **every** case with a
transformer fails the oracle at C (in the sweep: all `[free-tap]` cases and the
real `LV1_14bus` feeder — `powerio_export / opendss_nonconvergence`). This is also
why BMOPFTools' existing DSS→BMOPF→DSS transformer round-trips are marked
`@test_broken`.

**Suggestion:** map `v_nom_from`/`v_nom_to` to the winding `kv=` values (respecting
the DELTA line-to-line vs WYE convention already handled elsewhere in PowerIO).

## 2. BMOPF `ibr` is not exported

`to_dss` drops a top-level `ibr` collection with a warning and writes no
generation element for it:

```
to_dss warning: "top level `ibr` is outside the schema; kept untyped"
# → 0 PVSystem / Generator / Isource lines in the output
```

A pinned IBR is a fixed PQ injection; the natural OpenDSS target is a `Generator`
(`model=1`) or a `PVSystem` at a fixed operating point.

**Suggestion:** export `ibr` as an OpenDSS `Generator`/`PVSystem`. Until then we
convert to a negative `Load` (see below), which round-trips faithfully.

## 3. OpenDSS `PVSystem`/`Generator` not imported

Symmetric to #2: `from_dss` on a deck containing a `PVSystem` (e.g.
`pf_pv_4leg.dss`) produces a BMOPF net with **no** `ibr` or `generator` — the
element is dropped, with no warning. All 33 `pf_comparison` fixtures import with
zero controllable devices.

**Suggestion:** map `PVSystem` → `ibr` (`prime_mover="PV"`) and `Generator` →
`generator`, and warn when a generation element cannot be represented.

## 4. Loads exported without `Vminpu`/`Vmaxpu`

Exported `Load` elements carry no `Vminpu`/`Vmaxpu`, so OpenDSS applies its default
band and reverts constant-power loads to constant-Z under the voltage excursions a
DER snapshot creates. On the clean transformer-free cases this shows as a benign
~1–4 V (< 2 %) A≈C drift (`pf_zip_1ph` 2.3 V, `pf_exp_1ph` 4.0 V); the BMOPF model
holds them as true constant-power. BMOPFTools' own comparison fixtures set
`Vminpu=0 Vmaxpu=2` precisely to defeat this.

**Suggestion:** emit `Vminpu`/`Vmaxpu` (or make them configurable) so a constant-
power load stays constant-power across the solve.

## 5. Three-phase / 4-wire line snapshot drift

On multi-phase, 4-wire earth-return cases the regenerated deck's load-bus voltages
diverge well beyond the load-model floor — `pf_3ph_line` shows **135 V** at the
load bus (4 nodes) and `pf_zip_3ph` **63 V**, while the source bus matches. This
points at the neutral/earth-return handling in the exported deck (the neutral point
shifts differently), consistent with these cases already being non-`RT_PF_SOUND` in
the round-trip study. (Distinct from #1: these cases have no transformer.)

**Suggestion:** review 4-wire neutral / earth-return grounding in the DSS writer.

---

# Import direction (`from_dss`) — resolved upstream in PowerIO v0.6.2

PowerIO v0.6.2 carries the validated transformer fidelity fields through the
BMOPF export directly: fixed taps, center-tap leakage, delta-wye leakage,
internal neutral grounding, and the validated `n_winding` cases. BMOPFTools now
uses the PMD export only to normalize no-load shunt sign and placement to its
OPF convention.

## What legitimately stays in `from_dss` (not PowerIO's concern)

For clarity, these `from_dss` normalizations are **BMOPF-spec conventions**, not
PowerIO deficiencies — please **don't** "fix" them upstream:

- **Numeric→phase terminal relabel** `1/2/3/4 → a/b/c/n`
  ([:234](../src/io/from_dss.jl#L234)) — a task-force labelling choice; PowerIO's
  numeric terminals are correct.
- **Identifier case-folding** ([:154](../src/io/from_dss.jl#L154)) — BMOPF
  case-insensitivity.
- **Per-phase `VSource` bank → one polyphase slack**
  ([:807](../src/io/from_dss.jl#L807)) — BMOPF's "one source per bus" spec; the
  docstring notes PowerIO *faithfully* emits the per-phase sources.

---

## What already works well

- **Loads, lines, single-phase topologies, and the voltage source export
  faithfully.** The three transformer-free single-phase DER cases (`pf_1ph_line`,
  `pf_zip_1ph`, `pf_exp_1ph`) pass the full `A ≈ B ≈ C` check within 2 %, i.e. an
  OPF solution projected through PowerIO and solved in OpenDSS reproduces the
  optimizer's voltages — the end-to-end goal, working today.
- **Transformer taps round-trip through the writer**: a freed OPF tap
  (`tap=1.0116`) appears in the exported deck, and the OpenDSS projection check
  solves.
