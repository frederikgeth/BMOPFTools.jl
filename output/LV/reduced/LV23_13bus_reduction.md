# Simplification log: LV23_13bus

**Generated:** 2026-06-23 21:34:01  
**Buses:** 14 → 4 (−10)  
**Lines:** 8 → 2 (−6)  
**Operations:** 11

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 4 |
| `merge_series_lines` | 3 |
| `remove_dangling_lines` | 4 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_3241_closed` | Collapsed closed switch switch_3241_closed: bus b1438 merged into b2493. |
| 2 | `collapse_closed_switches` | switch `switch_1356_closed` | Collapsed closed switch switch_1356_closed: bus b1335 merged into b2635. |
| 3 | `collapse_closed_switches` | switch `switch_1312_closed` | Collapsed closed switch switch_1312_closed: bus b432 merged into b105. |
| 4 | `collapse_closed_switches` | switch `switch_2516_closed` | Collapsed closed switch switch_2516_closed: bus b574 merged into b976. |
| 5 | `remove_dangling_lines` | line `l_3736` | Removed dangling line l_3736 and its leaf bus b976 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_3165` | Removed dangling line l_3165 and its leaf bus b1400 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_3620` | Removed dangling line l_3620 and its leaf bus b105 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_1986` | Removed dangling line l_1986 and its leaf bus b2944 (leaf has no active elements). |
| 9 | `merge_series_lines` | line `l_3742` | Merged line l_4627 (0.346761446772 m) into l_3742 at pass-through bus b2911; new length 0.60251012997 m. |
| 10 | `merge_series_lines` | line `l_3742` | Merged line l_357 (0.24462917546299998 m) into l_3742 at pass-through bus b2493; new length 0.847139305433 m. |
| 11 | `merge_series_lines` | bus `b2635` | Lines l_3742 (linecode ughv_400al_triplex_ug_4w_bundled) and l_1203 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b2635 have different linecodes — not merged. |

