# Simplification log: LV8_14bus

**Generated:** 2026-06-23 21:02:37  
**Buses:** 15 → 5 (−10)  
**Lines:** 9 → 3 (−6)  
**Operations:** 12

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 4 |
| `merge_series_lines` | 4 |
| `remove_dangling_lines` | 4 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `Switch_1829_CLOSED` | Collapsed closed switch Switch_1829_CLOSED: bus B1470 merged into B3129. |
| 2 | `collapse_closed_switches` | switch `Switch_207_CLOSED` | Collapsed closed switch Switch_207_CLOSED: bus B1349 merged into B1969. |
| 3 | `collapse_closed_switches` | switch `Switch_1541_CLOSED` | Collapsed closed switch Switch_1541_CLOSED: bus B415 merged into B1579. |
| 4 | `collapse_closed_switches` | switch `Switch_678_CLOSED` | Collapsed closed switch Switch_678_CLOSED: bus B3013 merged into B2930. |
| 5 | `remove_dangling_lines` | line `L_3030` | Removed dangling line L_3030 and its leaf bus B2928 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_4119` | Removed dangling line L_4119 and its leaf bus B2963 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_3387` | Removed dangling line L_3387 and its leaf bus B2930 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_3033` | Removed dangling line L_3033 and its leaf bus B3129 (leaf has no active elements). |
| 9 | `merge_series_lines` | bus `B694` | Merge blocked: intermediate bus B694 has non-line elements attached. |
| 10 | `merge_series_lines` | bus `B1579` | Lines L_2919 (linecode ughv_400al_triplex_ug_4w_bundled) and L_2965 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B1579 have different linecodes — not merged. |
| 11 | `merge_series_lines` | line `L_4370` | Merged line L_2919 (0.354695866145 m) into L_4370 at pass-through bus B3368; new length 0.610444549343 m. |
| 12 | `merge_series_lines` | line `L_4370` | Merged line L_665 (0.353799366149 m) into L_4370 at pass-through bus B1969; new length 0.964243915492 m. |

