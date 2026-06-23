# Simplification log: LV5_14bus

**Generated:** 2026-06-23 21:02:37  
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
| 1 | `collapse_closed_switches` | switch `Switch_3243_CLOSED` | Collapsed closed switch Switch_3243_CLOSED: bus B932 merged into B1885. |
| 2 | `collapse_closed_switches` | switch `Switch_3992_CLOSED` | Collapsed closed switch Switch_3992_CLOSED: bus B2942 merged into B2061. |
| 3 | `collapse_closed_switches` | switch `Switch_2012_CLOSED` | Collapsed closed switch Switch_2012_CLOSED: bus B2105 merged into B1248. |
| 4 | `collapse_closed_switches` | switch `Switch_717_CLOSED` | Collapsed closed switch Switch_717_CLOSED: bus B392 merged into B2267. |
| 5 | `remove_dangling_lines` | line `L_382` | Removed dangling line L_382 and its leaf bus B2226 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_1215` | Removed dangling line L_1215 and its leaf bus B2646 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_3168` | Removed dangling line L_3168 and its leaf bus B2061 (leaf has no active elements). |
| 8 | `merge_series_lines` | bus `B2267` | Lines L_3009 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_264 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B2267 have different linecodes — not merged. |
| 9 | `merge_series_lines` | bus `B1885` | Lines L_3186 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_832 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B1885 have different linecodes — not merged. |
| 10 | `merge_series_lines` | line `L_745` | Merged line L_177 (0.24462917546299998 m) into L_745 at pass-through bus B1248; new length 0.606210088628 m. |

