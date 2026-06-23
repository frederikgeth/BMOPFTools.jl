# Simplification log: LV23_13bus

**Generated:** 2026-06-23 21:02:36  
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
| 1 | `collapse_closed_switches` | switch `Switch_1312_CLOSED` | Collapsed closed switch Switch_1312_CLOSED: bus B432 merged into B105. |
| 2 | `collapse_closed_switches` | switch `Switch_1356_CLOSED` | Collapsed closed switch Switch_1356_CLOSED: bus B1335 merged into B2635. |
| 3 | `collapse_closed_switches` | switch `Switch_2516_CLOSED` | Collapsed closed switch Switch_2516_CLOSED: bus B574 merged into B976. |
| 4 | `collapse_closed_switches` | switch `Switch_3241_CLOSED` | Collapsed closed switch Switch_3241_CLOSED: bus B1438 merged into B2493. |
| 5 | `remove_dangling_lines` | line `L_3620` | Removed dangling line L_3620 and its leaf bus B105 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_1986` | Removed dangling line L_1986 and its leaf bus B2944 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_3165` | Removed dangling line L_3165 and its leaf bus B1400 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_3736` | Removed dangling line L_3736 and its leaf bus B976 (leaf has no active elements). |
| 9 | `merge_series_lines` | line `L_3742` | Merged line L_4627 (0.346761446772 m) into L_3742 at pass-through bus B2911; new length 0.60251012997 m. |
| 10 | `merge_series_lines` | line `L_3742` | Merged line L_357 (0.24462917546299998 m) into L_3742 at pass-through bus B2493; new length 0.847139305433 m. |
| 11 | `merge_series_lines` | bus `B2635` | Lines L_3742 (linecode ughv_400al_triplex_ug_4w_bundled) and L_1203 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B2635 have different linecodes — not merged. |

