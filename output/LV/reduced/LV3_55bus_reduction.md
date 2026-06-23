# Simplification log: LV3_55bus

**Generated:** 2026-06-23 21:02:37  
**Buses:** 56 → 28 (−28)  
**Lines:** 46 → 26 (−20)  
**Operations:** 34

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 8 |
| `merge_series_lines` | 10 |
| `remove_dangling_lines` | 16 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `Switch_3774_CLOSED` | Collapsed closed switch Switch_3774_CLOSED: bus B1599 merged into B2526. |
| 2 | `collapse_closed_switches` | switch `Switch_1181_CLOSED` | Collapsed closed switch Switch_1181_CLOSED: bus B2925 merged into B2972. |
| 3 | `collapse_closed_switches` | switch `Switch_3760_CLOSED` | Collapsed closed switch Switch_3760_CLOSED: bus B1006 merged into B1384. |
| 4 | `collapse_closed_switches` | switch `Switch_1030_CLOSED` | Collapsed closed switch Switch_1030_CLOSED: bus B1606 merged into B1473. |
| 5 | `collapse_closed_switches` | switch `Switch_2207_CLOSED` | Collapsed closed switch Switch_2207_CLOSED: bus B2740 merged into B718. |
| 6 | `collapse_closed_switches` | switch `Switch_3753_CLOSED` | Collapsed closed switch Switch_3753_CLOSED: bus B2973 merged into B2236. |
| 7 | `collapse_closed_switches` | switch `Switch_3416_CLOSED` | Collapsed closed switch Switch_3416_CLOSED: bus B1141 merged into B1396. |
| 8 | `collapse_closed_switches` | switch `Switch_1450_CLOSED` | Collapsed closed switch Switch_1450_CLOSED: bus B1656 merged into B608. |
| 9 | `remove_dangling_lines` | line `L_1232` | Removed dangling line L_1232 and its leaf bus B1892 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_86` | Removed dangling line L_86 and its leaf bus B2710 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `L_2764` | Removed dangling line L_2764 and its leaf bus B1877 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_1594` | Removed dangling line L_1594 and its leaf bus B121 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `L_1254` | Removed dangling line L_1254 and its leaf bus B2024 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `L_3932` | Removed dangling line L_3932 and its leaf bus B1393 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `L_3877` | Removed dangling line L_3877 and its leaf bus B1320 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `L_3005` | Removed dangling line L_3005 and its leaf bus B1452 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `L_3919` | Removed dangling line L_3919 and its leaf bus B3015 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `L_521` | Removed dangling line L_521 and its leaf bus B1118 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `L_1677` | Removed dangling line L_1677 and its leaf bus B2236 (leaf has no active elements). |
| 20 | `remove_dangling_lines` | line `L_1353` | Removed dangling line L_1353 and its leaf bus B628 (leaf has no active elements). |
| 21 | `remove_dangling_lines` | line `L_474` | Removed dangling line L_474 and its leaf bus B3008 (leaf has no active elements). |
| 22 | `remove_dangling_lines` | line `L_3802` | Removed dangling line L_3802 and its leaf bus B3304 (leaf has no active elements). |
| 23 | `remove_dangling_lines` | line `L_613` | Removed dangling line L_613 and its leaf bus B1069 (leaf has no active elements). |
| 24 | `remove_dangling_lines` | line `L_3577` | Removed dangling line L_3577 and its leaf bus B608 (leaf has no active elements). |
| 25 | `merge_series_lines` | bus `B718` | Lines L_4288 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_1021 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B718 have different linecodes — not merged. |
| 26 | `merge_series_lines` | bus `B2526` | Lines L_1168 (linecode ughv_400al_triplex_ug_4w_bundled) and L_3912 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B2526 have different linecodes — not merged. |
| 27 | `merge_series_lines` | line `L_1250` | Merged line L_4005 (0.255748683198 m) into L_1250 at pass-through bus B2972; new length 0.500377859015 m. |
| 28 | `merge_series_lines` | bus `B1384` | Lines L_1749 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_3253 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B1384 have different linecodes — not merged. |
| 29 | `merge_series_lines` | line `L_1168` | Merged line L_1636 (0.5421723794619999 m) into L_1168 at pass-through bus B1473; new length 0.6090924459520999 m. |
| 30 | `merge_series_lines` | line `L_496` | Merged line L_3253 (0.0669200664901 m) into L_496 at pass-through bus B1396; new length 0.2732219820691 m. |
| 31 | `merge_series_lines` | bus `B690` | Lines L_4294 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_2590 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B690 have different linecodes — not merged. |
| 32 | `merge_series_lines` | bus `B837` | Lines L_4153 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_1021 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B837 have different linecodes — not merged. |
| 33 | `merge_series_lines` | line `L_4288` | Merged line L_989 (0.7473386046070001 m) into L_4288 at pass-through bus B1713; new length 52.928425763207 m. |
| 34 | `merge_series_lines` | bus `B101` | Lines L_4288 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_3432 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B101 have different linecodes — not merged. |

