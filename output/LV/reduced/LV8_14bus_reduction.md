# Simplification log: LV8_14bus

**Generated:** 2026-06-23 21:34:02  
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
| 1 | `collapse_closed_switches` | switch `switch_678_closed` | Collapsed closed switch switch_678_closed: bus b3013 merged into b2930. |
| 2 | `collapse_closed_switches` | switch `switch_1541_closed` | Collapsed closed switch switch_1541_closed: bus b415 merged into b1579. |
| 3 | `collapse_closed_switches` | switch `switch_1829_closed` | Collapsed closed switch switch_1829_closed: bus b1470 merged into b3129. |
| 4 | `collapse_closed_switches` | switch `switch_207_closed` | Collapsed closed switch switch_207_closed: bus b1349 merged into b1969. |
| 5 | `remove_dangling_lines` | line `l_3033` | Removed dangling line l_3033 and its leaf bus b3129 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_3030` | Removed dangling line l_3030 and its leaf bus b2928 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_3387` | Removed dangling line l_3387 and its leaf bus b2930 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_4119` | Removed dangling line l_4119 and its leaf bus b2963 (leaf has no active elements). |
| 9 | `merge_series_lines` | line `l_4370` | Merged line l_665 (0.353799366149 m) into l_4370 at pass-through bus b1969; new length 0.609548049347 m. |
| 10 | `merge_series_lines` | bus `b694` | Merge blocked: intermediate bus b694 has non-line elements attached. |
| 11 | `merge_series_lines` | line `l_4370` | Merged line l_2919 (0.354695866145 m) into l_4370 at pass-through bus b3368; new length 0.964243915492 m. |
| 12 | `merge_series_lines` | bus `b1579` | Lines l_4370 (linecode ughv_400al_triplex_ug_4w_bundled) and l_2965 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b1579 have different linecodes — not merged. |

