# Simplification log: LV2_43bus

**Generated:** 2026-06-23 21:02:36  
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
| 1 | `collapse_closed_switches` | switch `Switch_1043_CLOSED` | Collapsed closed switch Switch_1043_CLOSED: bus B1982 merged into B2252. |
| 2 | `collapse_closed_switches` | switch `Switch_965_CLOSED` | Collapsed closed switch Switch_965_CLOSED: bus B2341 merged into B278. |
| 3 | `remove_dangling_lines` | line `L_1015` | Removed dangling line L_1015 and its leaf bus B617 (leaf has no active elements). |
| 4 | `remove_dangling_lines` | line `L_495` | Removed dangling line L_495 and its leaf bus B3291 (leaf has no active elements). |
| 5 | `remove_dangling_lines` | line `L_2176` | Removed dangling line L_2176 and its leaf bus B832 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_3298` | Removed dangling line L_3298 and its leaf bus B928 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_2978` | Removed dangling line L_2978 and its leaf bus B2348 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_4052` | Removed dangling line L_4052 and its leaf bus B2751 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `L_186` | Removed dangling line L_186 and its leaf bus B3348 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_2034` | Removed dangling line L_2034 and its leaf bus B776 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `L_1413` | Removed dangling line L_1413 and its leaf bus B2688 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_2263` | Removed dangling line L_2263 and its leaf bus B1099 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `L_418` | Removed dangling line L_418 and its leaf bus B146 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `L_4353` | Removed dangling line L_4353 and its leaf bus B2359 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `L_2169` | Removed dangling line L_2169 and its leaf bus B350 (leaf has no active elements). |
| 16 | `merge_series_lines` | bus `B2206` | Lines L_1816 (linecode moon_lv_oh_4wire) and L_15 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B2206 have different linecodes — not merged. |
| 17 | `merge_series_lines` | bus `B2870` | Lines L_2227 (linecode ughv_400al_triplex_ug_4w_bundled) and L_119 (linecode abc4x16_lv_oh_4w_bundled) at bus B2870 have different linecodes — not merged. |
| 18 | `merge_series_lines` | bus `B2098` | Lines L_2193 (linecode ughv_400al_triplex_ug_4w_bundled) and L_806 (linecode moon_lv_oh_4wire) at bus B2098 have different linecodes — not merged. |
| 19 | `merge_series_lines` | bus `B2574` | Lines L_2980 (linecode moon_lv_oh_4wire) and L_15 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B2574 have different linecodes — not merged. |
| 20 | `merge_series_lines` | bus `B491` | Lines L_4668 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_1380 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B491 have different linecodes — not merged. |
| 21 | `merge_series_lines` | bus `B2821` | Lines L_1926 (linecode ughv_400al_triplex_ug_4w_bundled) and L_1659 (linecode abc4x16_lv_oh_4w_bundled) at bus B2821 have different linecodes — not merged. |
| 22 | `merge_series_lines` | bus `B359` | Lines L_139 (linecode abc4x16_lv_oh_4w_bundled) and L_2805 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B359 have different linecodes — not merged. |
| 23 | `merge_series_lines` | bus `B242` | Lines L_3786 (linecode abc4x16_lv_oh_4w_bundled) and L_2741 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B242 have different linecodes — not merged. |
| 24 | `merge_series_lines` | line `L_4542` | Merged line L_4450 (0.386636051821 m) into L_4542 at pass-through bus B2252; new length 0.685780559656 m. |
| 25 | `merge_series_lines` | bus `B1535` | Lines L_236 (linecode moon_lv_oh_4wire) and L_2193 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B1535 have different linecodes — not merged. |
| 26 | `merge_series_lines` | line `L_236` | Merged line L_1816 (33.7097211418 m) into L_236 at pass-through bus B2555; new length 65.15067336850001 m. |
| 27 | `merge_series_lines` | bus `B333` | Lines L_3409 (linecode abc4x16_lv_oh_4w_bundled) and L_3526 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B333 have different linecodes — not merged. |
| 28 | `merge_series_lines` | line `L_1386` | Merged line L_2227 (0.29550750121 m) into L_1386 at pass-through bus B3128; new length 0.69550750121 m. |
| 29 | `merge_series_lines` | bus `B1906` | Lines L_3159 (linecode ughv_400al_triplex_ug_4w_bundled) and L_3203 (linecode abc4x16_lv_oh_4w_bundled) at bus B1906 have different linecodes — not merged. |
| 30 | `merge_series_lines` | line `L_2741` | Merged line L_4181 (0.2 m) into L_2741 at pass-through bus B1586; new length 0.505966421029 m. |
| 31 | `merge_series_lines` | bus `B535` | Lines L_1926 (linecode ughv_400al_triplex_ug_4w_bundled) and L_3680 (linecode moon_lv_oh_4wire) at bus B535 have different linecodes — not merged. |

