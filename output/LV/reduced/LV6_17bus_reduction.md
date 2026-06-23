# Simplification log: LV6_17bus

**Generated:** 2026-06-23 21:34:02  
**Buses:** 18 → 4 (−14)  
**Lines:** 11 → 2 (−9)  
**Operations:** 15

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 5 |
| `merge_series_lines` | 3 |
| `remove_dangling_lines` | 7 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_2376_closed` | Collapsed closed switch switch_2376_closed: bus b300 merged into b2030. |
| 2 | `collapse_closed_switches` | switch `switch_4621_closed` | Collapsed closed switch switch_4621_closed: bus b422 merged into b1372. |
| 3 | `collapse_closed_switches` | switch `switch_4212_closed` | Collapsed closed switch switch_4212_closed: bus b3135 merged into b2337. |
| 4 | `collapse_closed_switches` | switch `switch_3119_closed` | Collapsed closed switch switch_3119_closed: bus b2241 merged into b1932. |
| 5 | `collapse_closed_switches` | switch `switch_270_closed` | Collapsed closed switch switch_270_closed: bus b586 merged into b3199. |
| 6 | `remove_dangling_lines` | line `l_3321` | Removed dangling line l_3321 and its leaf bus b665 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_1100` | Removed dangling line l_1100 and its leaf bus b1372 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_4051` | Removed dangling line l_4051 and its leaf bus b1618 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `l_4581` | Removed dangling line l_4581 and its leaf bus b26 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_4686` | Removed dangling line l_4686 and its leaf bus b2030 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `l_4359` | Removed dangling line l_4359 and its leaf bus b1568 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_2971` | Removed dangling line l_2971 and its leaf bus b1932 (leaf has no active elements). |
| 13 | `merge_series_lines` | line `l_1578` | Merged line l_4701 (0.24462917511 m) into l_1578 at pass-through bus b3199; new length 0.500377858661 m. |
| 14 | `merge_series_lines` | bus `b2337` | Lines l_725 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and l_3378 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b2337 have different linecodes — not merged. |
| 15 | `merge_series_lines` | line `l_1578` | Merged line l_3378 (0.255748683551 m) into l_1578 at pass-through bus b2074; new length 0.756126542212 m. |

