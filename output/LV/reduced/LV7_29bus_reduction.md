# Simplification log: LV7_29bus

**Generated:** 2026-06-23 21:02:37  
**Buses:** 30 → 14 (−16)  
**Lines:** 21 → 12 (−9)  
**Operations:** 19

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 7 |
| `merge_series_lines` | 6 |
| `remove_dangling_lines` | 6 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `Switch_178_CLOSED` | Collapsed closed switch Switch_178_CLOSED: bus B3283 merged into B2342. |
| 2 | `collapse_closed_switches` | switch `Switch_3852_CLOSED` | Collapsed closed switch Switch_3852_CLOSED: bus B2730 merged into B3. |
| 3 | `collapse_closed_switches` | switch `Switch_2915_CLOSED` | Collapsed closed switch Switch_2915_CLOSED: bus B1267 merged into B1565. |
| 4 | `collapse_closed_switches` | switch `Switch_811_CLOSED` | Collapsed closed switch Switch_811_CLOSED: bus B401 merged into B1847. |
| 5 | `collapse_closed_switches` | switch `Switch_3986_CLOSED` | Collapsed closed switch Switch_3986_CLOSED: bus B2767 merged into B403. |
| 6 | `collapse_closed_switches` | switch `Switch_628_CLOSED` | Collapsed closed switch Switch_628_CLOSED: bus B3377 merged into B627. |
| 7 | `collapse_closed_switches` | switch `Switch_3985_CLOSED` | Collapsed closed switch Switch_3985_CLOSED: bus B1201 merged into B2796. |
| 8 | `remove_dangling_lines` | line `L_4204` | Removed dangling line L_4204 and its leaf bus B1537 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `L_3640` | Removed dangling line L_3640 and its leaf bus B1861 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_4127` | Removed dangling line L_4127 and its leaf bus B1382 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `L_2808` | Removed dangling line L_2808 and its leaf bus B403 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_684` | Removed dangling line L_684 and its leaf bus B1565 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `L_161` | Removed dangling line L_161 and its leaf bus B444 (leaf has no active elements). |
| 14 | `merge_series_lines` | line `L_3887` | Merged line L_1854 (0.24482665765 m) into L_3887 at pass-through bus B3; new length 0.500575341201 m. |
| 15 | `merge_series_lines` | bus `B627` | Lines L_353 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_1177 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B627 have different linecodes — not merged. |
| 16 | `merge_series_lines` | bus `B1013` | Lines L_4662 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_353 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B1013 have different linecodes — not merged. |
| 17 | `merge_series_lines` | line `L_4037` | Merged line L_592 (0.0747735676854 m) into L_4037 at pass-through bus B1847; new length 0.4032578931824 m. |
| 18 | `merge_series_lines` | bus `B2796` | Lines L_4037 (linecode ughv_400al_triplex_ug_4w_bundled) and L_1889 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B2796 have different linecodes — not merged. |
| 19 | `merge_series_lines` | line `L_1759` | Merged line L_1177 (0.0747735676854 m) into L_1759 at pass-through bus B2342; new length 0.3956666092564 m. |

