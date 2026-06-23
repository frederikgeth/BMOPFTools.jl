# Simplification log: DSuite_SPD_Rural

**Generated:** 2026-06-23 21:26:48  
**Buses:** 66 → 55 (−11)  
**Lines:** 65 → 54 (−11)  
**Operations:** 21

## Summary by operation

| Operation | Count |
|-----------|------:|
| `merge_series_lines` | 17 |
| `remove_dangling_lines` | 4 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `remove_dangling_lines` | line `5750581` | Removed dangling line 5750581 and its leaf bus 16081939 (leaf has no active elements). |
| 2 | `remove_dangling_lines` | line `8534180` | Removed dangling line 8534180 and its leaf bus 17444778 (leaf has no active elements). |
| 3 | `remove_dangling_lines` | line `3346698` | Removed dangling line 3346698 and its leaf bus 13320536 (leaf has no active elements). |
| 4 | `remove_dangling_lines` | line `5750580` | Removed dangling line 5750580 and its leaf bus 13353810 (leaf has no active elements). |
| 5 | `merge_series_lines` | line `7032539` | Merged line 2764155 (5.39 m) into 7032539 at pass-through bus 13215639; new length 10.7 m. |
| 6 | `merge_series_lines` | bus `13215643` | Lines 7032539 (linecode cable_230v_35_al_acs) and 2764154 (linecode cable_230v_25_al) at bus 13215643 have different linecodes — not merged. |
| 7 | `merge_series_lines` | line `8579693` | Merged line 8554734 (4.04 m) into 8579693 at pass-through bus 13320538; new length 4.459 m. |
| 8 | `merge_series_lines` | bus `17439336` | Merge blocked: intermediate bus 17439336 has non-line elements attached. |
| 9 | `merge_series_lines` | bus `14499306` | Lines 3446232 (linecode cable_230v_35_al_acs) and 3446212 (linecode cable_230v_95_al) at bus 14499306 have different linecodes — not merged. |
| 10 | `merge_series_lines` | bus `17439334` | Lines 8539453 (linecode cable_230v_25_cu) and 7095821 (linecode connector) at bus 17439334 have different linecodes — not merged. |
| 11 | `merge_series_lines` | line `8546760` | Merged line 8546774 (0.216 m) into 8546760 at pass-through bus 16081970; new length 0.523 m. |
| 12 | `merge_series_lines` | bus `12295316` | Merge blocked: intermediate bus 12295316 has non-line elements attached. |
| 13 | `merge_series_lines` | line `3343309` | Merged line 3343317 (0.534 m) into 3343309 at pass-through bus 13226995; new length 1.8940000000000001 m. |
| 14 | `merge_series_lines` | line `5750578` | Merged line 5744736 (0.182 m) into 5750578 at pass-through bus 16078810; new length 5.572 m. |
| 15 | `merge_series_lines` | bus `9461181` | Lines 7095819 (linecode connector) and 11545351 (linecode busbar) at bus 9461181 have different linecodes — not merged. |
| 16 | `merge_series_lines` | line `3446232` | Merged line 3446145 (0.545 m) into 3446232 at pass-through bus 14499304; new length 1.815 m. |
| 17 | `merge_series_lines` | bus `17439337` | Lines 278484 (linecode unknown_lv_ohline_s) and 8537817 (linecode unknown_lv_ohline_m) at bus 17439337 have different linecodes — not merged. |
| 18 | `merge_series_lines` | bus `13353838` | Lines 3733227 (linecode cable_230v_35_al_ascs) and 3583186 (linecode cable_230v_25_al) at bus 13353838 have different linecodes — not merged. |
| 19 | `merge_series_lines` | line `3446212` | Merged line 8555526 (3.46 m) into 3446212 at pass-through bus 14522891; new length 3.769 m. |
| 20 | `merge_series_lines` | bus `14522889` | Merge blocked: intermediate bus 14522889 has non-line elements attached. |
| 21 | `merge_series_lines` | bus `14522887` | Lines 6701701 (linecode unknown_lv_cable_s) and 8534594 (linecode cable_230v_25_cu) at bus 14522887 have different linecodes — not merged. |

