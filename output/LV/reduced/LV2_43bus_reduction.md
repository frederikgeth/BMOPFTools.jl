# Simplification log: LV2_43bus

**Generated:** 2026-06-23 21:34:01  
**Buses:** 44 → 25 (−19)  
**Lines:** 40 → 23 (−17)  
**Operations:** 31

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 2 |
| `merge_series_lines` | 16 |
| `remove_dangling_lines` | 13 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_1043_closed` | Collapsed closed switch switch_1043_closed: bus b1982 merged into b2252. |
| 2 | `collapse_closed_switches` | switch `switch_965_closed` | Collapsed closed switch switch_965_closed: bus b2341 merged into b278. |
| 3 | `remove_dangling_lines` | line `l_2978` | Removed dangling line l_2978 and its leaf bus b2348 (leaf has no active elements). |
| 4 | `remove_dangling_lines` | line `l_2034` | Removed dangling line l_2034 and its leaf bus b776 (leaf has no active elements). |
| 5 | `remove_dangling_lines` | line `l_1413` | Removed dangling line l_1413 and its leaf bus b2688 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_3298` | Removed dangling line l_3298 and its leaf bus b928 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_4052` | Removed dangling line l_4052 and its leaf bus b2751 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_186` | Removed dangling line l_186 and its leaf bus b3348 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `l_2263` | Removed dangling line l_2263 and its leaf bus b1099 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_1015` | Removed dangling line l_1015 and its leaf bus b617 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `l_418` | Removed dangling line l_418 and its leaf bus b146 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_4353` | Removed dangling line l_4353 and its leaf bus b2359 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `l_495` | Removed dangling line l_495 and its leaf bus b3291 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `l_2176` | Removed dangling line l_2176 and its leaf bus b832 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `l_2169` | Removed dangling line l_2169 and its leaf bus b350 (leaf has no active elements). |
| 16 | `merge_series_lines` | bus `b242` | Lines l_2741 (linecode ughv_400al_triplex_ug_4w_bundled) and l_3786 (linecode abc4x16_lv_oh_4w_bundled) at bus b242 have different linecodes — not merged. |
| 17 | `merge_series_lines` | bus `b2206` | Lines l_1816 (linecode moon_lv_oh_4wire) and l_15 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b2206 have different linecodes — not merged. |
| 18 | `merge_series_lines` | line `l_4450` | Merged line l_4542 (0.299144507835 m) into l_4450 at pass-through bus b2252; new length 0.685780559656 m. |
| 19 | `merge_series_lines` | bus `b2098` | Lines l_2193 (linecode ughv_400al_triplex_ug_4w_bundled) and l_806 (linecode moon_lv_oh_4wire) at bus b2098 have different linecodes — not merged. |
| 20 | `merge_series_lines` | bus `b535` | Lines l_1926 (linecode ughv_400al_triplex_ug_4w_bundled) and l_3680 (linecode moon_lv_oh_4wire) at bus b535 have different linecodes — not merged. |
| 21 | `merge_series_lines` | line `l_2741` | Merged line l_4181 (0.2 m) into l_2741 at pass-through bus b1586; new length 0.505966421029 m. |
| 22 | `merge_series_lines` | bus `b359` | Lines l_139 (linecode abc4x16_lv_oh_4w_bundled) and l_2805 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b359 have different linecodes — not merged. |
| 23 | `merge_series_lines` | bus `b1906` | Lines l_3203 (linecode abc4x16_lv_oh_4w_bundled) and l_3159 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b1906 have different linecodes — not merged. |
| 24 | `merge_series_lines` | bus `b333` | Lines l_3409 (linecode abc4x16_lv_oh_4w_bundled) and l_3526 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b333 have different linecodes — not merged. |
| 25 | `merge_series_lines` | bus `b2821` | Lines l_1926 (linecode ughv_400al_triplex_ug_4w_bundled) and l_1659 (linecode abc4x16_lv_oh_4w_bundled) at bus b2821 have different linecodes — not merged. |
| 26 | `merge_series_lines` | bus `b2574` | Lines l_2980 (linecode moon_lv_oh_4wire) and l_15 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b2574 have different linecodes — not merged. |
| 27 | `merge_series_lines` | bus `b491` | Lines l_4668 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and l_1380 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b491 have different linecodes — not merged. |
| 28 | `merge_series_lines` | bus `b2870` | Lines l_119 (linecode abc4x16_lv_oh_4w_bundled) and l_2227 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b2870 have different linecodes — not merged. |
| 29 | `merge_series_lines` | line `l_236` | Merged line l_1816 (33.7097211418 m) into l_236 at pass-through bus b2555; new length 65.15067336850001 m. |
| 30 | `merge_series_lines` | bus `b1535` | Lines l_236 (linecode moon_lv_oh_4wire) and l_2193 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b1535 have different linecodes — not merged. |
| 31 | `merge_series_lines` | line `l_1386` | Merged line l_2227 (0.29550750121 m) into l_1386 at pass-through bus b3128; new length 0.69550750121 m. |

