# Simplification log: LV3_55bus

**Generated:** 2026-06-23 21:34:02  
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
| 1 | `collapse_closed_switches` | switch `switch_3774_closed` | Collapsed closed switch switch_3774_closed: bus b1599 merged into b2526. |
| 2 | `collapse_closed_switches` | switch `switch_3760_closed` | Collapsed closed switch switch_3760_closed: bus b1006 merged into b1384. |
| 3 | `collapse_closed_switches` | switch `switch_3753_closed` | Collapsed closed switch switch_3753_closed: bus b2973 merged into b2236. |
| 4 | `collapse_closed_switches` | switch `switch_1450_closed` | Collapsed closed switch switch_1450_closed: bus b1656 merged into b608. |
| 5 | `collapse_closed_switches` | switch `switch_1030_closed` | Collapsed closed switch switch_1030_closed: bus b1606 merged into b1473. |
| 6 | `collapse_closed_switches` | switch `switch_3416_closed` | Collapsed closed switch switch_3416_closed: bus b1141 merged into b1396. |
| 7 | `collapse_closed_switches` | switch `switch_2207_closed` | Collapsed closed switch switch_2207_closed: bus b2740 merged into b718. |
| 8 | `collapse_closed_switches` | switch `switch_1181_closed` | Collapsed closed switch switch_1181_closed: bus b2925 merged into b2972. |
| 9 | `remove_dangling_lines` | line `l_3877` | Removed dangling line l_3877 and its leaf bus b1320 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_474` | Removed dangling line l_474 and its leaf bus b3008 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `l_2764` | Removed dangling line l_2764 and its leaf bus b1877 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_1254` | Removed dangling line l_1254 and its leaf bus b2024 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `l_3919` | Removed dangling line l_3919 and its leaf bus b3015 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `l_3802` | Removed dangling line l_3802 and its leaf bus b3304 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `l_1677` | Removed dangling line l_1677 and its leaf bus b2236 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `l_3005` | Removed dangling line l_3005 and its leaf bus b1452 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `l_3932` | Removed dangling line l_3932 and its leaf bus b1393 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `l_521` | Removed dangling line l_521 and its leaf bus b1118 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `l_86` | Removed dangling line l_86 and its leaf bus b2710 (leaf has no active elements). |
| 20 | `remove_dangling_lines` | line `l_1232` | Removed dangling line l_1232 and its leaf bus b1892 (leaf has no active elements). |
| 21 | `remove_dangling_lines` | line `l_1353` | Removed dangling line l_1353 and its leaf bus b628 (leaf has no active elements). |
| 22 | `remove_dangling_lines` | line `l_613` | Removed dangling line l_613 and its leaf bus b1069 (leaf has no active elements). |
| 23 | `remove_dangling_lines` | line `l_3577` | Removed dangling line l_3577 and its leaf bus b608 (leaf has no active elements). |
| 24 | `remove_dangling_lines` | line `l_1594` | Removed dangling line l_1594 and its leaf bus b121 (leaf has no active elements). |
| 25 | `merge_series_lines` | bus `b718` | Lines l_4288 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_1021 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b718 have different linecodes — not merged. |
| 26 | `merge_series_lines` | line `l_3253` | Merged line l_496 (0.206301915579 m) into l_3253 at pass-through bus b1396; new length 0.2732219820691 m. |
| 27 | `merge_series_lines` | bus `b1384` | Lines l_3253 (linecode ughv_400al_triplex_ug_4w_bundled) and l_1749 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b1384 have different linecodes — not merged. |
| 28 | `merge_series_lines` | line `l_4288` | Merged line l_989 (0.7473386046070001 m) into l_4288 at pass-through bus b1713; new length 52.928425763207 m. |
| 29 | `merge_series_lines` | bus `b2526` | Lines l_1168 (linecode ughv_400al_triplex_ug_4w_bundled) and l_3912 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b2526 have different linecodes — not merged. |
| 30 | `merge_series_lines` | line `l_1168` | Merged line l_1636 (0.5421723794619999 m) into l_1168 at pass-through bus b1473; new length 0.6090924459520999 m. |
| 31 | `merge_series_lines` | line `l_1250` | Merged line l_4005 (0.255748683198 m) into l_1250 at pass-through bus b2972; new length 0.500377859015 m. |
| 32 | `merge_series_lines` | bus `b101` | Lines l_4288 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_3432 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b101 have different linecodes — not merged. |
| 33 | `merge_series_lines` | bus `b837` | Lines l_4153 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_1021 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b837 have different linecodes — not merged. |
| 34 | `merge_series_lines` | bus `b690` | Lines l_4294 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and l_2590 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b690 have different linecodes — not merged. |

