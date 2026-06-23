# Simplification log: LV28_25bus

**Generated:** 2026-06-23 21:02:36  
**Buses:** 26 → 14 (−12)  
**Lines:** 21 → 12 (−9)  
**Operations:** 19

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 3 |
| `merge_series_lines` | 9 |
| `remove_dangling_lines` | 7 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `Switch_2514_CLOSED` | Collapsed closed switch Switch_2514_CLOSED: bus B554 merged into B2255. |
| 2 | `collapse_closed_switches` | switch `Switch_2605_CLOSED` | Collapsed closed switch Switch_2605_CLOSED: bus B1343 merged into B3352. |
| 3 | `collapse_closed_switches` | switch `Switch_1562_CLOSED` | Collapsed closed switch Switch_1562_CLOSED: bus B2274 merged into B2551. |
| 4 | `remove_dangling_lines` | line `L_3405` | Removed dangling line L_3405 and its leaf bus B2695 (leaf has no active elements). |
| 5 | `remove_dangling_lines` | line `L_2778` | Removed dangling line L_2778 and its leaf bus B1189 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_1757` | Removed dangling line L_1757 and its leaf bus B2436 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_1048` | Removed dangling line L_1048 and its leaf bus B1215 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_1390` | Removed dangling line L_1390 and its leaf bus B2766 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `L_4231` | Removed dangling line L_4231 and its leaf bus B3352 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_1486` | Removed dangling line L_1486 and its leaf bus B168 (leaf has no active elements). |
| 11 | `merge_series_lines` | line `L_2597` | Merged line L_950 (0.299153552267 m) into L_2597 at pass-through bus B2551; new length 0.49915355226700003 m. |
| 12 | `merge_series_lines` | bus `B363` | Lines L_2018 (linecode ughv_400al_triplex_ug_4w_bundled) and L_563 (linecode abc4x16_lv_oh_4w_bundled) at bus B363 have different linecodes — not merged. |
| 13 | `merge_series_lines` | bus `B706` | Lines L_3238 (linecode abc4x16_lv_oh_4w_bundled) and L_3095 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B706 have different linecodes — not merged. |
| 14 | `merge_series_lines` | line `L_2597` | Merged line L_3799 (0.386643049639 m) into L_2597 at pass-through bus B2255; new length 0.885796601906 m. |
| 15 | `merge_series_lines` | bus `B885` | Lines L_166 (linecode abc4x16_lv_oh_4w_bundled) and L_640 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B885 have different linecodes — not merged. |
| 16 | `merge_series_lines` | bus `B1374` | Lines L_2573 (linecode abc4x16_lv_oh_4w_bundled) and L_640 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B1374 have different linecodes — not merged. |
| 17 | `merge_series_lines` | bus `B301` | Lines L_1211 (linecode ughv_400al_triplex_ug_4w_bundled) and L_538 (linecode moon_lv_oh_4wire) at bus B301 have different linecodes — not merged. |
| 18 | `merge_series_lines` | bus `B107` | Lines L_2702 (linecode ughv_400al_triplex_ug_4w_bundled) and L_2573 (linecode abc4x16_lv_oh_4w_bundled) at bus B107 have different linecodes — not merged. |
| 19 | `merge_series_lines` | bus `B504` | Lines L_1211 (linecode ughv_400al_triplex_ug_4w_bundled) and L_2127 (linecode moon_lv_oh_4wire) at bus B504 have different linecodes — not merged. |

