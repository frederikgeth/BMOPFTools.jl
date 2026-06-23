# Simplification log: LV7_29bus

**Generated:** 2026-06-23 21:34:02  
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
| 1 | `collapse_closed_switches` | switch `switch_3985_closed` | Collapsed closed switch switch_3985_closed: bus b1201 merged into b2796. |
| 2 | `collapse_closed_switches` | switch `switch_178_closed` | Collapsed closed switch switch_178_closed: bus b3283 merged into b2342. |
| 3 | `collapse_closed_switches` | switch `switch_3852_closed` | Collapsed closed switch switch_3852_closed: bus b2730 merged into b3. |
| 4 | `collapse_closed_switches` | switch `switch_2915_closed` | Collapsed closed switch switch_2915_closed: bus b1267 merged into b1565. |
| 5 | `collapse_closed_switches` | switch `switch_3986_closed` | Collapsed closed switch switch_3986_closed: bus b2767 merged into b403. |
| 6 | `collapse_closed_switches` | switch `switch_628_closed` | Collapsed closed switch switch_628_closed: bus b3377 merged into b627. |
| 7 | `collapse_closed_switches` | switch `switch_811_closed` | Collapsed closed switch switch_811_closed: bus b401 merged into b1847. |
| 8 | `remove_dangling_lines` | line `l_4204` | Removed dangling line l_4204 and its leaf bus b1537 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `l_161` | Removed dangling line l_161 and its leaf bus b444 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_3640` | Removed dangling line l_3640 and its leaf bus b1861 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `l_2808` | Removed dangling line l_2808 and its leaf bus b403 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_684` | Removed dangling line l_684 and its leaf bus b1565 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `l_4127` | Removed dangling line l_4127 and its leaf bus b1382 (leaf has no active elements). |
| 14 | `merge_series_lines` | line `l_4037` | Merged line l_592 (0.0747735676854 m) into l_4037 at pass-through bus b1847; new length 0.4032578931824 m. |
| 15 | `merge_series_lines` | line `l_1177` | Merged line l_1759 (0.320893041571 m) into l_1177 at pass-through bus b2342; new length 0.3956666092564 m. |
| 16 | `merge_series_lines` | bus `b2796` | Lines l_4037 (linecode ughv_400al_triplex_ug_4w_bundled) and l_1889 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b2796 have different linecodes — not merged. |
| 17 | `merge_series_lines` | bus `b627` | Lines l_1177 (linecode ughv_400al_triplex_ug_4w_bundled) and l_353 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b627 have different linecodes — not merged. |
| 18 | `merge_series_lines` | bus `b1013` | Lines l_353 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_4662 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b1013 have different linecodes — not merged. |
| 19 | `merge_series_lines` | line `l_1854` | Merged line l_3887 (0.255748683551 m) into l_1854 at pass-through bus b3; new length 0.500575341201 m. |

