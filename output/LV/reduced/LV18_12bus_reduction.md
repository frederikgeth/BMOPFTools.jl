# Simplification log: LV18_12bus

**Generated:** 2026-06-23 21:34:01  
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
| 1 | `collapse_closed_switches` | switch `switch_240_closed` | Collapsed closed switch switch_240_closed: bus b1819 merged into b609. |
| 2 | `collapse_closed_switches` | switch `switch_3724_closed` | Collapsed closed switch switch_3724_closed: bus b83 merged into b3030. |
| 3 | `collapse_closed_switches` | switch `switch_2794_closed` | Collapsed closed switch switch_2794_closed: bus b1760 merged into b526. |
| 4 | `collapse_closed_switches` | switch `switch_2180_closed` | Collapsed closed switch switch_2180_closed: bus b2886 merged into b3046. |
| 5 | `remove_dangling_lines` | line `l_2276` | Removed dangling line l_2276 and its leaf bus b609 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_1134` | Removed dangling line l_1134 and its leaf bus b2729 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_1687` | Removed dangling line l_1687 and its leaf bus b3030 (leaf has no active elements). |
| 8 | `merge_series_lines` | line `l_1849` | Merged line l_2437 (0.554144731608 m) into l_1849 at pass-through bus b2156; new length 0.798773907071 m. |
| 9 | `merge_series_lines` | bus `b526` | Lines l_1849 (linecode ughv_400al_triplex_ug_4w_bundled) and l_124 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b526 have different linecodes — not merged. |
| 10 | `merge_series_lines` | line `l_1849` | Merged line l_3611 (0.255937602767 m) into l_1849 at pass-through bus b3046; new length 1.054711509838 m. |

