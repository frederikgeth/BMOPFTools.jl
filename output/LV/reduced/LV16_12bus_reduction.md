# Simplification log: LV16_12bus

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
| 1 | `collapse_closed_switches` | switch `Switch_1087_CLOSED` | Collapsed closed switch Switch_1087_CLOSED: bus B366 merged into B2794. |
| 2 | `collapse_closed_switches` | switch `Switch_647_CLOSED` | Collapsed closed switch Switch_647_CLOSED: bus B516 merged into B259. |
| 3 | `collapse_closed_switches` | switch `Switch_3858_CLOSED` | Collapsed closed switch Switch_3858_CLOSED: bus B324 merged into B3372. |
| 4 | `collapse_closed_switches` | switch `Switch_4391_CLOSED` | Collapsed closed switch Switch_4391_CLOSED: bus B752 merged into B1255. |
| 5 | `remove_dangling_lines` | line `L_995` | Removed dangling line L_995 and its leaf bus B3372 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_3060` | Removed dangling line L_3060 and its leaf bus B2794 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_110` | Removed dangling line L_110 and its leaf bus B2325 (leaf has no active elements). |
| 8 | `merge_series_lines` | line `L_4175` | Merged line L_4334 (0.255748683198 m) into L_4175 at pass-through bus B259; new length 0.5003778586609999 m. |
| 9 | `merge_series_lines` | bus `B1255` | Lines L_1536 (linecode ughv_400al_triplex_ug_4w_bundled) and L_3457 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B1255 have different linecodes — not merged. |
| 10 | `merge_series_lines` | line `L_4175` | Merged line L_1536 (0.354701255107 m) into L_4175 at pass-through bus B1259; new length 0.8550791137679999 m. |

