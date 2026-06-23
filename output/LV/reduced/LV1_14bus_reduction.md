# Simplification log: LV1_14bus

**Generated:** 2026-06-23 21:34:01  
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
| 1 | `collapse_closed_switches` | switch `switch_499_closed` | Collapsed closed switch switch_499_closed: bus b3218 merged into b1149. |
| 2 | `collapse_closed_switches` | switch `switch_792_closed` | Collapsed closed switch switch_792_closed: bus b2123 merged into b2984. |
| 3 | `collapse_closed_switches` | switch `switch_4000_closed` | Collapsed closed switch switch_4000_closed: bus b2327 merged into b232. |
| 4 | `collapse_closed_switches` | switch `switch_1972_closed` | Collapsed closed switch switch_1972_closed: bus b1133 merged into b514. |
| 5 | `remove_dangling_lines` | line `l_226` | Removed dangling line l_226 and its leaf bus b1989 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_597` | Removed dangling line l_597 and its leaf bus b1149 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_4124` | Removed dangling line l_4124 and its leaf bus b1977 (leaf has no active elements). |
| 8 | `merge_series_lines` | bus `b232` | Lines l_378 (linecode ughv_400al_triplex_ug_4w_bundled) and l_3726 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b232 have different linecodes — not merged. |
| 9 | `merge_series_lines` | line `l_4431` | Merged line l_793 (0.255748683198 m) into l_4431 at pass-through bus b2984; new length 0.602521795538 m. |
| 10 | `merge_series_lines` | bus `b514` | Lines l_3383 (linecode ughv_400al_triplex_ug_4w_bundled) and l_2126 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b514 have different linecodes — not merged. |

