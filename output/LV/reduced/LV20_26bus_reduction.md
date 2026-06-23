# Simplification log: LV20_26bus

**Generated:** 2026-06-23 21:02:36  
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
| 1 | `collapse_closed_switches` | switch `Switch_1966_CLOSED` | Collapsed closed switch Switch_1966_CLOSED: bus B1921 merged into B2600. |
| 2 | `collapse_closed_switches` | switch `Switch_3390_CLOSED` | Collapsed closed switch Switch_3390_CLOSED: bus B2747 merged into B1250. |
| 3 | `collapse_closed_switches` | switch `Switch_3474_CLOSED` | Collapsed closed switch Switch_3474_CLOSED: bus B1477 merged into B2094. |
| 4 | `collapse_closed_switches` | switch `Switch_4452_CLOSED` | Collapsed closed switch Switch_4452_CLOSED: bus B1898 merged into B2644. |
| 5 | `collapse_closed_switches` | switch `Switch_4695_CLOSED` | Collapsed closed switch Switch_4695_CLOSED: bus B1699 merged into B1670. |
| 6 | `collapse_closed_switches` | switch `Switch_710_CLOSED` | Collapsed closed switch Switch_710_CLOSED: bus B850 merged into B3037. |
| 7 | `remove_dangling_lines` | line `L_679` | Removed dangling line L_679 and its leaf bus B485 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_4538` | Removed dangling line L_4538 and its leaf bus B2644 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `L_1634` | Removed dangling line L_1634 and its leaf bus B2913 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_530` | Removed dangling line L_530 and its leaf bus B389 (leaf has no active elements). |
| 11 | `merge_series_lines` | bus `B3037` | Lines L_4326 (linecode ughv_400al_triplex_ug_4w_bundled) and L_2007 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B3037 have different linecodes — not merged. |
| 12 | `merge_series_lines` | line `L_3359` | Merged line L_1663 (3.23190271975 m) into L_3359 at pass-through bus B1117; new length 74.20209279795 m. |
| 13 | `merge_series_lines` | line `L_907` | Merged line L_2790 (0.0669200664901 m) into L_907 at pass-through bus B1250; new length 0.39539911615710005 m. |
| 14 | `merge_series_lines` | line `L_1596` | Merged line L_170 (0.255748683551 m) into L_1596 at pass-through bus B1670; new length 0.5114973667489999 m. |
| 15 | `merge_series_lines` | bus `B3151` | Lines L_1096 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_3484 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B3151 have different linecodes — not merged. |
| 16 | `merge_series_lines` | bus `B2094` | Lines L_4224 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_907 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B2094 have different linecodes — not merged. |
| 17 | `merge_series_lines` | bus `B2140` | Lines L_2685 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_2007 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B2140 have different linecodes — not merged. |
| 18 | `merge_series_lines` | line `L_4326` | Merged line L_1974 (0.206301915236 m) into L_4326 at pass-through bus B2600; new length 0.2732219817261 m. |

