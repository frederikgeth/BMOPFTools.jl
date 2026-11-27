# Regional system-type fixtures

Original synthetic teaching cases, one wiring and earthing practice each. They
are deliberately small: every bus and device can be read in the JSON. They are
not derived from, or calibrated to, any utility network; impedances, ratings
and loads are illustrative.

| File | Practice |
|---|---|
| `na_mgn_split_phase.json` | North America: 12.47 kV four-wire multi-grounded-neutral primary, a single-phase lateral, and a center-tapped 120/240 V service with a 240 V leg-to-leg load |
| `na_high_leg_open_delta.json` | North America: open-wye/open-delta bank, a center-tapped lighting unit plus a power unit, giving a 240/120 V high-leg (four-wire) delta |
| `eu_tn_four_wire.json` | Europe: 10 kV / 400 V Dyn substation, star point earthed once at the transformer, four-wire LV feeder |
| `it_delta_island_unreferenced.json` | An unearthed 400 V delta island with no modeled path to earth: a true `E.INT.NO_VOLTAGE_REFERENCE` |
| `it_delta_island_capacitive.json` | The same island referenced through its cable capacitance to earth |
| `jp_three_wire_v_connection.json` | Japan: 6.6 kV three-wire primary, a 100/200 V single-phase three-wire service, and a V-connected 200 V three-phase service with 100 V lighting legs |
| `au_men_four_wire.json` | Australia: 11 kV / 415 V Dyn substation with a multiple-earthed-neutral LV feeder |

The Australian SWER practice is covered by the OpenDSS deck in `../SWER/`.

`generate.py` writes every file; edit it and rerun rather than editing the JSON
by hand. `test/profiler_generalization_tests.jl` runs each case through
`analyze` and pins the classification and the absence of false errors.

Licensed with the other bundled synthetic fixtures under CC BY 4.0;
see [the fixture license](../license.md). Code remains BSD-3-Clause.
