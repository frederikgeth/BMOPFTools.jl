# Simplification log: LV18_12bus

**Generated:** 2026-06-23 21:02:35  
**Buses:** 13 → 4 (−9)  
**Lines:** 7 → 2 (−5)  
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
| 1 | `collapse_closed_switches` | switch `Switch_2794_CLOSED` | Collapsed closed switch Switch_2794_CLOSED: bus B1760 merged into B526. |
| 2 | `collapse_closed_switches` | switch `Switch_240_CLOSED` | Collapsed closed switch Switch_240_CLOSED: bus B1819 merged into B609. |
| 3 | `collapse_closed_switches` | switch `Switch_2180_CLOSED` | Collapsed closed switch Switch_2180_CLOSED: bus B2886 merged into B3046. |
| 4 | `collapse_closed_switches` | switch `Switch_3724_CLOSED` | Collapsed closed switch Switch_3724_CLOSED: bus B83 merged into B3030. |
| 5 | `remove_dangling_lines` | line `L_1134` | Removed dangling line L_1134 and its leaf bus B2729 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_2276` | Removed dangling line L_2276 and its leaf bus B609 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_1687` | Removed dangling line L_1687 and its leaf bus B3030 (leaf has no active elements). |
| 8 | `merge_series_lines` | bus `B526` | Lines L_124 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_2437 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B526 have different linecodes — not merged. |
| 9 | `merge_series_lines` | line `L_1849` | Merged line L_2437 (0.554144731608 m) into L_1849 at pass-through bus B2156; new length 0.798773907071 m. |
| 10 | `merge_series_lines` | line `L_1849` | Merged line L_3611 (0.255937602767 m) into L_1849 at pass-through bus B3046; new length 1.054711509838 m. |

