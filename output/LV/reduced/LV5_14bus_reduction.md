# Simplification log: LV5_14bus

**Generated:** 2026-06-23 21:34:02  
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
| 1 | `collapse_closed_switches` | switch `switch_3243_closed` | Collapsed closed switch switch_3243_closed: bus b932 merged into b1885. |
| 2 | `collapse_closed_switches` | switch `switch_2012_closed` | Collapsed closed switch switch_2012_closed: bus b2105 merged into b1248. |
| 3 | `collapse_closed_switches` | switch `switch_3992_closed` | Collapsed closed switch switch_3992_closed: bus b2942 merged into b2061. |
| 4 | `collapse_closed_switches` | switch `switch_717_closed` | Collapsed closed switch switch_717_closed: bus b392 merged into b2267. |
| 5 | `remove_dangling_lines` | line `l_1215` | Removed dangling line l_1215 and its leaf bus b2646 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_382` | Removed dangling line l_382 and its leaf bus b2226 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_3168` | Removed dangling line l_3168 and its leaf bus b2061 (leaf has no active elements). |
| 8 | `merge_series_lines` | bus `b2267` | Lines l_264 (linecode ughv_400al_triplex_ug_4w_bundled) and l_3009 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b2267 have different linecodes — not merged. |
| 9 | `merge_series_lines` | bus `b1885` | Lines l_832 (linecode ughv_400al_triplex_ug_4w_bundled) and l_3186 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b1885 have different linecodes — not merged. |
| 10 | `merge_series_lines` | line `l_177` | Merged line l_745 (0.361580913165 m) into l_177 at pass-through bus b1248; new length 0.606210088628 m. |

