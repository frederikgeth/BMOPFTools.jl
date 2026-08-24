# Transformer models

This page is the normative reference for how BMOPFTools models transformers: the
supported subtypes, the conventions every subtype follows, the exported
primitive admittance (`Yprim`), and the explicit list of approximations. The
overriding design goal is **consistency with OpenDSS**: at a given setpoint the
OPF constraints and the exported `Yprim` describe the same device, and both are
built to match OpenDSS's own `Yprim` term-by-term wherever OpenDSS is unambiguous.

The companion [Transformer primitive admittance](spec/transformer-admittance.md)
spec page carries the full symbolic matrix derivations; this page is the
model-level contract. For the workflow that *produces* these fields — turning
short-circuit/open-circuit test data into a validated model — see the
[transformer test-data tutorial](tutorial_transformer_tests.md).

## Supported subtypes

| Subtype | Shape | Windings | Notes |
|---|---|---|---|
| `single_phase` | two-bus | 2 (per-phase YY) | 1/2/3-phase; line-to-neutral, line-to-line, or phase-to-ground winding pairs |
| `center_tap` | two-bus | 3 (split-phase) | North-American 120/240; strict arity (2 HV, 3 LV) |
| `wye_delta` (Yd) | two-bus | 2, 3-phase | wye is winding 1 (from) |
| `delta_wye` (Dy) | two-bus | 2, 3-phase | delta is winding 1 (from); backward-delta convention |
| `single_phase_autotransformer` | two-bus | 2, galvanically tied | step voltage regulator; ANSI type A/B |
| `open_delta_regulator` | two-bus | two L-L cores | 3-phase only; ABBC/BCAC/CABA |
| `n_winding` | winding-list | any n, WYE and/or DELTA | exact ZB leakage for any n; no tap optimisation |

A subtype string outside this set is **not silently dropped** — the OPF builder
and the `Yprim` export both emit a warning that the device contributes no
constraints / is omitted from the export.

## Conventions

These hold across every subtype unless a row below says otherwise.

| Aspect | Convention |
|---|---|
| Units | SI (volts, amperes, ohms, siemens); per-unit is an internal transform |
| Turns ratio | `N = (v_nom_from / v_nom_to) · tap`, `tap` default 1.0 |
| Current sign (`Yprim`) | into the element (out of the bus); `Y = Yᵀ`, matches OpenDSS `Yprim` |
| Series leakage | to-referred at nominal; the from-winding share scales with `tap²` (turns-scaled, exact for YY / regulators) |
| **Magnetising shunt** | across **winding 2** (the to-side coil), on winding 2's coil voltage base — the OpenDSS placement, verified against its `Yprim`. Inductive, so `b_no_load < 0`. See below. |
| **Neutral grounding** | `r/x_neutral_from`/`to` (OpenDSS `rneut`/`xneut`) is an internal branch `yₙ = 1/(Rₙ+jXₙ)` from the winding neutral terminal to earth. A stand-alone transformer property — external groundings stay on buses/shunts and are **never** merged in. |
| Polarity / vector group | Dy uses the backward-delta (`k_prev`) coil convention; `n_winding` DELTA windings use `delta_roll = -1` for OpenDSS's standard delta |
| Lossless limit | `r = x = g = b = 0` is the well-posed ideal-transformer constraint, not a singularity (the `Yprim` export is the only path where `Z=0` is singular — an ideal transformer has no admittance form) |

### Magnetising-shunt placement

OpenDSS places the no-load (core-loss + magnetising) branch across **winding 2**,
referred to winding 2's coil voltage — not winding 1, and not phase-to-ground.
This was verified empirically by differencing OpenDSS's `Yprim` with and without
`%noloadloss`/`%imag` (the shunt follows winding 2 when the winding order is
flipped). BMOPFTools matches this in both the OPF and the `Yprim` export:

| Subtype | Winding-2 coil the shunt spans |
|---|---|
| `single_phase` | the to coil (`p_to − q_to`) |
| `wye_delta` (Yd) | a delta of `Y₀/nφ` branches across the LV **delta** coils |
| `delta_wye` (Dy) | `Y₀/nφ` phase-to-neutral on the LV **wye** |
| `center_tap` | the **entire** `Y₀` across LV leg 1 (`t1 − tn`), not split |
| `n_winding` | winding 2's coil (connection-aware) |

`from_dss` derives `g_no_load` / `b_no_load` on winding 2's coil base, and now
**recovers `%imag`** into `b_no_load` (negative, inductive) — the across-coil
placement carries the susceptance cleanly, which the earlier phase-to-ground
stamp could not.

## Primitive admittance export

`transformer_yprim(xfmr, subtype)` / `export_yprim(net)` return the SI `Yprim`
block over the device's `(bus, terminal)` nodes. It includes the series leakage,
the winding-2 magnetising shunt, and the `rneut`/`xneut` grounding branch. Two
caveats for consumers:

- **Regulators** (`single_phase_autotransformer`, `open_delta_regulator`): the
  shared-bushing / shared-phase galvanic tie is an OPF **topological** constraint,
  not part of the device primitive (the exported block is the Yan et al. (2018)
  "unspecified neutral" matrix). The exported `Yprim` alone leaves the regulated
  side's return floating.
- **Ideal transformers** (`Z = 0`): no admittance form exists; the export returns
  a singular (shunt-only) block with a warning. The OPF still enforces the exact
  ratio.

### OPF ↔ Yprim consistency

The OPF builders and the `Yprim` export are independent implementations. Their
agreement at a given setpoint is a guarded invariant: the test suite reconstructs
the element current `I = Yₚ·V` from a solved power flow and checks it node-by-node
against the solved OPF winding-current variables, for `single_phase`,
`center_tap`, `wye_delta`, and `delta_wye`, including off-nominal fixed taps. See
[Validating the OPF](validation.md).

## Approximations

Everything below is a deliberate, bounded approximation — listed here so nothing
is hidden.

| Area | Status |
|---|---|
| **`n_winding` tap** | No tap optimisation — the ratio is held at nominal. Tap fields on an `n_winding` transformer are warned and ignored. Model a regulated winding with a two-bus subtype instead. |
| **4+ winding import** | `from_dss` imports the validated `n_winding` cases emitted by PowerIO v0.9. Unsupported winding sets refuse loudly, not built wrong. |
| **Discrete taps** | Optimised taps are continuous; there is no discrete-step (`numtaps`) model. |
| **Per-winding ratings** | A two-bus transformer carries one `s_rating` (winding-1 base). Distinct per-winding kVA is retained only on `n_winding` (per-winding `s_max`). |

## Nameplate rating (`s_rating`) as a loading cap

`s_rating` plays two roles, and they must not be conflated:

1. **Per-unit impedance base (always).** The short-circuit reactances are
   expressed on **winding 1's** kVA base — the OpenDSS convention (`%XHL`/`%XHT`/
   `%XLT` are all on the winding-1 base, *not* the highest-powered winding). The
   OPF matches this: the leakage is per-unitised by `z_base(winding-1 bus)` and
   `s_rating`. **This base never changes**, so OpenDSS round-trips stay exact.
2. **Apparent-power loading cap (always enforced).** The nameplate is enforced as
   a per-winding coil apparent-power limit `P² + Q² ≤ (s_rating / n_\text{ph})²`
   (the coil voltage is phase-to-neutral for a wye winding, line-to-line for a
   delta winding, so it is never ≈ 0 — no neutral degeneracy), alongside the
   per-winding `i_max_from`/`i_max_to` current cones when present. Because
   `s_rating` is a required field, **every transformer is power-limited**; to solve
   without the limit (e.g. a determined power flow compared against limit-free
   OpenDSS), remove `s_rating` from the network dict before calling the OPF. Keep
   in mind the primary coil carries load *plus* copper losses, so at exactly-rated
   delivery the from-side cap binds slightly below the secondary nameplate
   throughput (by the loss margin). See
   [current vs. apparent-power limits](opf.md#Current-vs-apparent-power-limits).

For `n_winding` transformers, add an optional per-winding `s_max` (the winding's
own kVA) inside each winding entry; it is enforced when present. The per-unit
impedance base still keys off winding 1's `s_rating`, so introducing per-winding
ratings never re-bases the leakage.

Not approximations (common misconceptions): the **Dy/Yd leakage under tap** is
exact (it matches OpenDSS's `tap²` winding-1 self-impedance scaling — the
short-circuit impedance referred to the tapped side goes as `tap²`, the
non-tapped side is held at nominal; verified against OpenDSS's short-circuit
`Yprim`, applied identically in the OPF and the `Yprim` export); the magnetising
**susceptance** (`%imag`) is retained; zero-loss transformers are exact; the
`n_winding` ZB leakage is exact for any winding count.

## Grounding: the stand-alone contract

A transformer's model never absorbs an external grounding. Concretely:

- A grounded-wye star point earthed through OpenDSS `rneut`/`xneut` is modeled by
  the transformer's own `r/x_neutral_*` fields (an internal branch to earth).
- An OpenDSS earth node (`.0`) on a winding is routed to the **bus** neutral, and
  the bus's grounding (perfect, or an impedance shunt) does the earthing.
- External grounding reactors import as first-class `shunt` elements.

So the exported `Yprim` for a transformer is a function of the transformer's own
data only — no bus grounding data leaks into it, and there is no Kron reduction
of external nodes inside the builder.
