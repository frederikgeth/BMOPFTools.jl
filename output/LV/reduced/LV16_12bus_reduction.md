# Simplification log: LV16_12bus

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
| 1 | `collapse_closed_switches` | switch `switch_647_closed` | Collapsed closed switch switch_647_closed: bus b516 merged into b259. |
| 2 | `collapse_closed_switches` | switch `switch_1087_closed` | Collapsed closed switch switch_1087_closed: bus b366 merged into b2794. |
| 3 | `collapse_closed_switches` | switch `switch_4391_closed` | Collapsed closed switch switch_4391_closed: bus b752 merged into b1255. |
| 4 | `collapse_closed_switches` | switch `switch_3858_closed` | Collapsed closed switch switch_3858_closed: bus b324 merged into b3372. |
| 5 | `remove_dangling_lines` | line `l_110` | Removed dangling line l_110 and its leaf bus b2325 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_3060` | Removed dangling line l_3060 and its leaf bus b2794 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_995` | Removed dangling line l_995 and its leaf bus b3372 (leaf has no active elements). |
| 8 | `merge_series_lines` | bus `b1255` | Lines l_3457 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and l_1536 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b1255 have different linecodes — not merged. |
| 9 | `merge_series_lines` | line `l_1536` | Merged line l_4175 (0.24462917546299998 m) into l_1536 at pass-through bus b1259; new length 0.59933043057 m. |
| 10 | `merge_series_lines` | line `l_4334` | Merged line l_1536 (0.59933043057 m) into l_4334 at pass-through bus b259; new length 0.855079113768 m. |

