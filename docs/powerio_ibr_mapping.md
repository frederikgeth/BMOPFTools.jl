# PowerIO mapping guide — BMOPF `ibr` ⇄ OpenDSS PVSystem / Generator + InvControl

Companion to [`powerio_projection_feedback.md`](powerio_projection_feedback.md).
That note reports that `to_dss` currently drops the BMOPF `ibr` component and
`from_dss` drops OpenDSS `PVSystem`/`Generator`. This guide is the concrete
mapping so those two directions can be implemented — including the **volt-var /
volt-watt (VVWO)** smart-inverter control BMOPFTools models today.

All BMOPF field names/units below are from
[`src/validation/schemas/draft_bmopf_schema.json`](../src/validation/schemas/draft_bmopf_schema.json)
(`ibr` at line 473, `control_profile` at line 626); the OPF control semantics are
in [`ext/BMOPFOpfExt/ibr.jl`](../ext/BMOPFOpfExt/ibr.jl). OpenDSS property names
follow the OpenDSS PVSystem / Generator / InvControl / XYcurve elements.

> **The one caveat up front.** BMOPF's droop laws monitor, by default, the
> **phase-to-neutral** voltage `|V_φ − V_n|` (`PN_*` references), and can also
> monitor phase-to-phase (`PP_*`). OpenDSS `InvControl` monitors the terminal
> **phase-to-ground** magnitude only. So only the `PG_*` references map exactly;
> `PN_*`/`PP_*` are exact **only** where the neutral is solidly grounded
> (`V_n ≈ 0`) and are otherwise an approximation. See §5.

---

## 1. AC nameplate: `ibr` → PVSystem (or Generator)

A BMOPF `ibr` is an inverter-interfaced source. Map the AC side as an OpenDSS
`PVSystem` (preferred, so the InvControl attaches) or a `Generator`:

| BMOPF `ibr` field | Unit | OpenDSS PVSystem | Notes |
|---|---|---|---|
| `bus` + `terminal_map` | — | `bus1=bus.n1.n2…` | terminal→node via the same a/b/c/n → 1/2/3/0 map used elsewhere; a `"n"` terminal → node `.4` (or `.0` if bonded to ground) |
| `topology` (`SINGLE_PHASE`/`THREE_LEG`/`FOUR_LEG`) | — | `phases=1` / `phases=3 conn=delta` / `phases=3 conn=wye` | `FOUR_LEG` = wye + explicit neutral node; `THREE_LEG` = delta |
| `s_max` (per-phase array) | VA | `kVA = Σ s_max / 1000` | OpenDSS kVA is the inverter rating (whole element) |
| `p_avail` | W | `Pmpp = p_avail/1000`, `irradiance=1`, `%Pmpp=100` | available DC/AC active power (PV) |
| `p_max` (per-phase array) | W | (cap) | if `< p_avail`, an explicit dispatch cap; see §2 |
| `p_min` (per-phase array) | W | — | `< 0` ⇒ battery charging → use `Storage`, not `PVSystem` |
| `q_min` / `q_max` | var | `kvarMaxAbs` / `kvarMax` | reactive capability box (default ±`s_max`) |
| `prime_mover` (`PV`/`BATTERY`/`GENERIC`/`STATCOM`/`DSTATCOM`) | — | element choice | `PV`→PVSystem; `BATTERY`→Storage; `STATCOM/DSTATCOM`→PVSystem with `Pmpp≈0` (or Generator kW=0) |
| `i_max` | A | (see §6) | per-conductor current cap ⇒ Q rolls off with voltage |

**Apparent-power circle.** BMOPF always enforces `P² + Q² ≤ s_max²` per phase
([ibr.jl:260](../ext/BMOPFOpfExt/ibr.jl#L260)). In OpenDSS set the `kVA` rating and
`WattPriority=No` / `VarFollowInverter=Yes` so vars are limited to stay inside the
kVA circle rather than the other way round.

**Out-of-scope fields** with no OpenDSS equivalent — drop on export with a warning:
the DC-side set (`dc_link_coupled`, `dc_bus`, `p_dc_min/max`, `dc_control`,
`dc_v_set`, `dc_droop`, …) for shared-DC converter stations / back-to-back SOPs;
`grid_forming` + `v_ref_internal` (GFM operation); `r_filter`/`x_filter`/
`b_filter_shunt` (converter filter); and `cost` (per-phase `$/kWh` dispatch cost,
an optimizer input, not a physical device property).

## 2. Fixed dispatch (no `control_profile`)

An `ibr` with **no** `control_profile` and a pinned operating point (`p_min ==
p_max`, `q_min == q_max` — e.g. a projected OPF snapshot) is a constant-PQ
injection. Two faithful encodings:

- **Generator, `model=1`**: `New Generator.g_<id> bus1=… phases=… kv=… kw=ΣP/1000
  kvar=ΣQ/1000 model=1 Vminpu=0 Vmaxpu=2`. (`Vminpu=0 Vmaxpu=2` keeps it constant-
  PQ across the solve — see the load note in the feedback doc.)
- **PVSystem** at a fixed point: `Pmpp`, `pf`/`kvar` set to the dispatched values,
  `%cutin=0 %cutout=0 VarFollowInverter=yes`.

(This is exactly what BMOPFTools' `dispatch_as_loads` approximates today with a
*negative load*, as a stopgap until PVSystem/Generator export exists.)

## 3. Constant power factor: `control_profile.power_factor`

```json
"control_profile": { "cpf": { "power_factor": { "pf": 0.95 } } }
```
BMOPF sign convention ([schema:689](../src/validation/schemas/draft_bmopf_schema.json#L689)):
**positive pf = lagging (Q absorption), negative pf = leading (Q injection)** — the
OPF enforces `sign(pf)·Q + tan(acos|pf|)·P = 0` ([ibr.jl:264](../ext/BMOPFOpfExt/ibr.jl#L264)).

OpenDSS: set `PVSystem.pf = ±0.95`. **Watch the sign convention** — OpenDSS's
`pf` sign is the opposite orientation in several releases; validate against a
one-node case. Set `VarFollowInverter=yes` and `WattPriority` to match whether P or
Q yields under the kVA cap.

## 4. Volt-var and volt-watt: `control_profile` → InvControl + XYcurve

BMOPF encodes each droop as a **piecewise-linear curve of a monitored voltage
magnitude**, with breakpoints in **volts** (normalized internally by the bus base
voltage → per-unit, [ibr.jl:120](../ext/BMOPFOpfExt/ibr.jl#L120)). OpenDSS encodes
the same as an `XYcurve` (x = per-unit voltage, y = per-unit of a reference)
referenced by an `InvControl`.

### 4a. Volt-var — `control_profile.volt_var`

```json
"volt_var": {
  "voltage_reference": "PN_PER_PHASE",
  "breakpoints": [207.0, 220.0, 240.0, 258.0],   // [U1,U2,U3,U4] volts, non-decreasing
  "q_limits":   [-0.60, 0.44],                    // [q_absorb (≤0), q_inject (≥0)]
  "q_unit": "VA_FRACTION",                         // fraction of q_ref
  "q_ref":  "VAR_MAX"                              // reference = s_max (fixed)
}
```
Semantics ([_resolve_volt_var, ibr.jl:199](../ext/BMOPFOpfExt/ibr.jl#L199)): the
curve value at the four breakpoints is `[q_inject, 0, 0, q_absorb]`, i.e. **inject
vars below U1, deadband U2–U3, absorb above U4** — the standard IEEE-1547 shape.
The OPF stamps the **equality** `Q_k = q_base · f(|U_k|)` with `q_base = s_max`
(`VAR_MAX`).

OpenDSS mapping:
```
New XYcurve.vv_<id> npts=4
  ~ Xarray=[0.9000 0.9565 1.0435 1.1217]   ! breakpoints_V / base_V  (207/230 … 258/230 for a 230 V base)
  ~ Yarray=[0.44   0.0    0.0    -0.60 ]    ! q_inject … q_absorb, as fraction of RefReactivePower
New InvControl.ivc_<id> DERList=[PVSystem.<id>]
  ~ mode=VOLTVAR  vvc_curve1=vv_<id>
  ~ RefReactivePower=VARMAX            ! ↔ q_ref VAR_MAX  (VARAVAL_WATTS ↔ VAR_AVAILABLE)
  ~ voltage_curvex_ref=rated          ! x-axis is per-unit of the element's rated kV
  ~ monVoltageCalc=AVG                 ! see §5 (aggregation)
```
Notes:
- **x-axis** = breakpoint_V / (element base voltage). Use the same base the OPF
  uses: the bus phase-to-neutral base (`bases.v_base`). With `voltage_curvex_ref=
  rated`, OpenDSS's x per-unit is of the PVSystem `kv` — set `kv` = that base.
- **y sign**: OpenDSS `vvc_curve` y > 0 = inject (capacitive), y < 0 = absorb
  (inductive) — matches BMOPF `[+q_inject … −|q_absorb|]`.
- `p_min_for_q` → PVSystem **`%PminNoVars`**; `p_min_for_q_max` → **`%PminkvarMax`**
  (the schema names these OpenDSS analogues directly,
  [schema:654-661](../src/validation/schemas/draft_bmopf_schema.json#L654)).

### 4b. Volt-watt — `control_profile.volt_watt`

```json
"volt_watt": {
  "voltage_reference": "PN_PER_PHASE",
  "breakpoints": [253.0, 260.0],    // [U5,U6] volts
  "p_limits":   [0.20, 1.00],       // [p_low, p_high] fraction of p_ref
  "p_unit": "VA_FRACTION",
  "p_ref":  "S_MAX"                  // S_MAX | P_MAX | P_AVAILABLE
}
```
Semantics ([_resolve_volt_watt, ibr.jl:220](../ext/BMOPFOpfExt/ibr.jl#L220)): curve
value is `[p_high at U5, p_low at U6]` — **full power up to U5, curtail down to
p_low by U6**. The OPF applies it as a **cap** `P_k ≤ p_base · f(|U_k|)` on top of
the `p_max` box (the tighter binds, [ibr.jl:257](../ext/BMOPFOpfExt/ibr.jl#L257)).

OpenDSS mapping:
```
New XYcurve.vw_<id> npts=2 Xarray=[1.1000 1.1304] Yarray=[1.00 0.20]   ! 253/230, 260/230
New InvControl.ivc_<id> DERList=[PVSystem.<id>]
  ~ mode=VOLTWATT  voltwatt_curve=vw_<id>
  ~ VoltwattYAxis=KVARATINGPU        ! p_ref S_MAX → kVA-rating pu;  P_AVAILABLE → PAVAILABLEPU;  P_MAX → PMPPPU
  ~ voltage_curvex_ref=rated  monVoltageCalc=AVG
```
Combine volt-var **and** volt-watt on one inverter with `CombiMode=VV_VW` (both
`vvc_curve1` and `voltwatt_curve` set).

## 5. The monitored-voltage caveat (PN vs PG, and aggregation)

BMOPF `voltage_reference` is one of six values that split into a **quantity** and an
**aggregation** ([_split_voltage_reference, ibr.jl:131](../ext/BMOPFOpfExt/ibr.jl#L131);
[_monitor_U, ibr.jl:156](../ext/BMOPFOpfExt/ibr.jl#L156)):

| BMOPF `voltage_reference` | Monitored quantity | OpenDSS InvControl support |
|---|---|---|
| `PG_PER_PHASE` / `PG_AVERAGED` | `\|V_φ\|` phase-to-ground | **exact** — this is what InvControl measures |
| `PN_PER_PHASE` (**default**) / `PN_AVERAGED` | `\|V_φ − V_n\|` phase-to-neutral | **approximate** — exact only if the neutral is grounded (`V_n ≈ 0`); a floating 4-wire neutral is not representable |
| `PP_PER_PHASE` / `PP_AVERAGED` | `\|V_φ − V_ψ\|` phase-to-phase | **not representable** by native InvControl (it measures L-G) |

- **PG maps exactly.** For a faithful export of a VVWO IBR, prefer authoring the
  BMOPF profile with a `PG_*` reference, or document the approximation.
- **PN (the default) needs a grounded neutral to be exact.** On the four-wire cases
  BMOPFTools targets, the neutral point shifts, so InvControl (L-G) and the OPF
  (L-N) will disagree by the neutral-shift voltage. This is the fundamental limit
  the user flagged: *OpenDSS does phase-to-ground volt-var/watt, not phase-to-
  neutral.*

**Aggregation.** `*_PER_PHASE` drives each phase's Q/P from **its own** monitored
voltage; `*_AVERAGED` feeds every phase the **mean** magnitude. (An IBR-level
`voltage_aggregation` field, when present, overrides the curve's suffix:
`PER_PHASE` / `AVERAGE`, [ibr.jl:345](../ext/BMOPFOpfExt/ibr.jl#L345).) OpenDSS
`monVoltageCalc = AVG` corresponds to `*_AVERAGED`. Native `*_PER_PHASE` control of
a 3-phase PVSystem generally needs **three single-phase PVSystems, each with its own
single-phase InvControl** (one control signal per element), since a single
InvControl on a 3-phase element applies one aggregated signal. `FOUR_LEG`/
`SINGLE_PHASE` only — BMOPF does not apply droop to `THREE_LEG`
([ibr.jl:268](../ext/BMOPFOpfExt/ibr.jl#L268)).

## 6. Reactive capability reference (`q_ref`) and current limits

- `q_ref = VAR_MAX` → `RefReactivePower = VARMAX` (fraction of the fixed kvar
  rating). `VAR_AVAILABLE` → `VARAVAL_WATTS` (∝ `√(s_max² − P²)`). BMOPF `volt_var`
  currently emits only `VAR_MAX`.
- `i_max` (per-conductor current cap, [schema:499](../src/validation/schemas/draft_bmopf_schema.json#L499)):
  when present the OPF caps `\|I_φ\| ≤ i_max`, so reactive capability rolls off ~
  linearly with voltage instead of staying flat at `s_max`. OpenDSS has no direct
  per-phase current cap on PVSystem; approximate via the kVA rating, or note the
  divergence at low voltage.

## 7. Import direction (OpenDSS → BMOPF, for `from_dss`)

- `PVSystem` → `ibr` with `prime_mover="PV"`, `s_max=[kVA·1000]` (split per phase),
  `p_avail = Pmpp·irradiance·1000`, `topology` from `phases`/`conn`.
- `Generator` (model 1/7) → `ibr` `prime_mover="GENERIC"` (or `generator` if you
  prefer the rotating-machine component), with `p_min=p_max=kw·1000` for a fixed
  dispatch or a `[0, kw]` range.
- `InvControl` + its `XYcurve`s → a `control_profile` with `volt_var`/`volt_watt`
  sub-objects: invert §4 (per-unit x-axis × base voltage → breakpoints in volts;
  y-array → `q_limits`/`p_limits`). Set `voltage_reference` to a `PG_*` value
  (that is what OpenDSS measured) and the aggregation from `monVoltageCalc`.
- Emit a warning when a construct can't be represented (e.g. `DRC` mode, hysteresis,
  time-domain dynamics) rather than dropping it silently.

## 8. Worked example

The breakpoints/limits used here are the reviewed **AS/NZS 4777.2:2020 "Australia
A"** preset shipped in
[`config/default.toml`](../config/default.toml) (`[augment.smart_ibr.regions.Aus_A]`,
lines 169–180); the end-to-end study is
[`docs/src/tutorial_vvwo.md`](src/tutorial_vvwo.md) /
[`examples/vvwo_tutorial.jl`](../examples/vvwo_tutorial.jl), which embeds these
droop curves in an OPF on the `LV1_14bus` 4-wire feeder.

The BMOPF volt-var fixture
([test/volt_var_watt_tests.jl:126](../test/volt_var_watt_tests.jl#L126)) — a 1-φ PV
on a 230 V (nominal) node, injecting up to 0.44·s_max at 207 V and absorbing down to
−0.60·s_max at 258 V:

```json
"ibr": { "pv1": { "bus":"b1", "terminal_map":["1","n"], "topology":"SINGLE_PHASE",
                  "prime_mover":"PV", "s_max":[3000.0], "p_max":[0.0], "p_min":[0.0],
                  "control_profile":"vv" } },
"control_profile": { "vv": { "volt_var": {
  "voltage_reference":"PN_PER_PHASE",
  "breakpoints":[207.0,220.0,240.0,258.0], "q_limits":[-0.60,0.44],
  "q_unit":"VA_FRACTION", "q_ref":"VAR_MAX" } } }
```
→ OpenDSS (base 230 V; note the PN→PG approximation flag from §5):
```
New PVSystem.pv1 phases=1 bus1=b1.1.4 kv=0.230 kVA=3.0 Pmpp=0.0 irradiance=1
New XYcurve.vv_pv1 npts=4 Xarray=[0.900 0.957 1.043 1.122] Yarray=[0.44 0.0 0.0 -0.60]
New InvControl.ivc_pv1 DERList=[PVSystem.pv1] mode=VOLTVAR vvc_curve1=vv_pv1
  ~ RefReactivePower=VARMAX voltage_curvex_ref=rated monVoltageCalc=AVG
```

## 9. Priority for implementation

1. **PVSystem/Generator nameplate** (§1–2) — unblocks the OPF-snapshot oracle for
   DER cases without the negative-load stopgap. Highest value.
2. **Constant power factor** (§3) — trivial, one property.
3. **Volt-var / volt-watt via InvControl + XYcurve** (§4), authored with `PG_*`
   references first (exact), then the `PN_*` approximation with a documented
   caveat (§5).
4. **Per-phase (`*_PER_PHASE`) control** via split single-phase PVSystems — last, and
   only if per-phase droop fidelity is needed.
