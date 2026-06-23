# Simplification log: LV20_26bus

**Generated:** 2026-06-23 21:34:01  
**Buses:** 27 → 13 (−14)  
**Lines:** 19 → 11 (−8)  
**Operations:** 18

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 6 |
| `merge_series_lines` | 8 |
| `remove_dangling_lines` | 4 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_3474_closed` | Collapsed closed switch switch_3474_closed: bus b1477 merged into b2094. |
| 2 | `collapse_closed_switches` | switch `switch_4452_closed` | Collapsed closed switch switch_4452_closed: bus b1898 merged into b2644. |
| 3 | `collapse_closed_switches` | switch `switch_3390_closed` | Collapsed closed switch switch_3390_closed: bus b2747 merged into b1250. |
| 4 | `collapse_closed_switches` | switch `switch_4695_closed` | Collapsed closed switch switch_4695_closed: bus b1699 merged into b1670. |
| 5 | `collapse_closed_switches` | switch `switch_1966_closed` | Collapsed closed switch switch_1966_closed: bus b1921 merged into b2600. |
| 6 | `collapse_closed_switches` | switch `switch_710_closed` | Collapsed closed switch switch_710_closed: bus b850 merged into b3037. |
| 7 | `remove_dangling_lines` | line `l_530` | Removed dangling line l_530 and its leaf bus b389 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_679` | Removed dangling line l_679 and its leaf bus b485 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `l_4538` | Removed dangling line l_4538 and its leaf bus b2644 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_1634` | Removed dangling line l_1634 and its leaf bus b2913 (leaf has no active elements). |
| 11 | `merge_series_lines` | line `l_2790` | Merged line l_907 (0.32847904966700003 m) into l_2790 at pass-through bus b1250; new length 0.39539911615710005 m. |
| 12 | `merge_series_lines` | bus `b2140` | Lines l_2007 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_2685 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b2140 have different linecodes — not merged. |
| 13 | `merge_series_lines` | bus `b3037` | Lines l_2007 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_4326 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b3037 have different linecodes — not merged. |
| 14 | `merge_series_lines` | bus `b2094` | Lines l_4224 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_2790 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b2094 have different linecodes — not merged. |
| 15 | `merge_series_lines` | line `l_170` | Merged line l_1596 (0.255748683198 m) into l_170 at pass-through bus b1670; new length 0.5114973667489999 m. |
| 16 | `merge_series_lines` | line `l_4326` | Merged line l_1974 (0.206301915236 m) into l_4326 at pass-through bus b2600; new length 0.2732219817261 m. |
| 17 | `merge_series_lines` | bus `b3151` | Lines l_3484 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_1096 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b3151 have different linecodes — not merged. |
| 18 | `merge_series_lines` | line `l_3359` | Merged line l_1663 (3.23190271975 m) into l_3359 at pass-through bus b1117; new length 74.20209279795 m. |

