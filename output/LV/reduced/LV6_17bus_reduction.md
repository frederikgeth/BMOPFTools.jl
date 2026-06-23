# Simplification log: LV6_17bus

**Generated:** 2026-06-23 21:02:37  
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
| 1 | `collapse_closed_switches` | switch `Switch_270_CLOSED` | Collapsed closed switch Switch_270_CLOSED: bus B586 merged into B3199. |
| 2 | `collapse_closed_switches` | switch `Switch_4621_CLOSED` | Collapsed closed switch Switch_4621_CLOSED: bus B422 merged into B1372. |
| 3 | `collapse_closed_switches` | switch `Switch_4212_CLOSED` | Collapsed closed switch Switch_4212_CLOSED: bus B3135 merged into B2337. |
| 4 | `collapse_closed_switches` | switch `Switch_3119_CLOSED` | Collapsed closed switch Switch_3119_CLOSED: bus B2241 merged into B1932. |
| 5 | `collapse_closed_switches` | switch `Switch_2376_CLOSED` | Collapsed closed switch Switch_2376_CLOSED: bus B300 merged into B2030. |
| 6 | `remove_dangling_lines` | line `L_1100` | Removed dangling line L_1100 and its leaf bus B1372 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_3321` | Removed dangling line L_3321 and its leaf bus B665 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_4051` | Removed dangling line L_4051 and its leaf bus B1618 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `L_4581` | Removed dangling line L_4581 and its leaf bus B26 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_4686` | Removed dangling line L_4686 and its leaf bus B2030 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `L_2971` | Removed dangling line L_2971 and its leaf bus B1932 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_4359` | Removed dangling line L_4359 and its leaf bus B1568 (leaf has no active elements). |
| 13 | `merge_series_lines` | line `L_4701` | Merged line L_1578 (0.255748683551 m) into L_4701 at pass-through bus B3199; new length 0.500377858661 m. |
| 14 | `merge_series_lines` | line `L_4701` | Merged line L_3378 (0.255748683551 m) into L_4701 at pass-through bus B2074; new length 0.756126542212 m. |
| 15 | `merge_series_lines` | bus `B2337` | Lines L_4701 (linecode ughv_400al_triplex_ug_4w_bundled) and L_725 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B2337 have different linecodes — not merged. |

