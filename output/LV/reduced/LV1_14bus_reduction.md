# Simplification log: LV1_14bus

**Generated:** 2026-06-23 21:02:36  
**Buses:** 15 → 7 (−8)  
**Lines:** 9 → 5 (−4)  
**Operations:** 10

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 4 |
| `merge_series_lines` | 3 |
| `remove_dangling_lines` | 3 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `Switch_1972_CLOSED` | Collapsed closed switch Switch_1972_CLOSED: bus B1133 merged into B514. |
| 2 | `collapse_closed_switches` | switch `Switch_4000_CLOSED` | Collapsed closed switch Switch_4000_CLOSED: bus B2327 merged into B232. |
| 3 | `collapse_closed_switches` | switch `Switch_792_CLOSED` | Collapsed closed switch Switch_792_CLOSED: bus B2123 merged into B2984. |
| 4 | `collapse_closed_switches` | switch `Switch_499_CLOSED` | Collapsed closed switch Switch_499_CLOSED: bus B3218 merged into B1149. |
| 5 | `remove_dangling_lines` | line `L_226` | Removed dangling line L_226 and its leaf bus B1989 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_597` | Removed dangling line L_597 and its leaf bus B1149 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_4124` | Removed dangling line L_4124 and its leaf bus B1977 (leaf has no active elements). |
| 8 | `merge_series_lines` | line `L_793` | Merged line L_4431 (0.34677311234 m) into L_793 at pass-through bus B2984; new length 0.602521795538 m. |
| 9 | `merge_series_lines` | bus `B232` | Lines L_378 (linecode ughv_400al_triplex_ug_4w_bundled) and L_3726 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B232 have different linecodes — not merged. |
| 10 | `merge_series_lines` | bus `B514` | Lines L_2126 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_3383 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B514 have different linecodes — not merged. |

