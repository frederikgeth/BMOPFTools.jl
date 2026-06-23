# Simplification log: LV28_25bus

**Generated:** 2026-06-23 21:34:01  
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
| 1 | `collapse_closed_switches` | switch `switch_2605_closed` | Collapsed closed switch switch_2605_closed: bus b1343 merged into b3352. |
| 2 | `collapse_closed_switches` | switch `switch_2514_closed` | Collapsed closed switch switch_2514_closed: bus b554 merged into b2255. |
| 3 | `collapse_closed_switches` | switch `switch_1562_closed` | Collapsed closed switch switch_1562_closed: bus b2274 merged into b2551. |
| 4 | `remove_dangling_lines` | line `l_2778` | Removed dangling line l_2778 and its leaf bus b1189 (leaf has no active elements). |
| 5 | `remove_dangling_lines` | line `l_1757` | Removed dangling line l_1757 and its leaf bus b2436 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_1486` | Removed dangling line l_1486 and its leaf bus b168 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_3405` | Removed dangling line l_3405 and its leaf bus b2695 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_1048` | Removed dangling line l_1048 and its leaf bus b1215 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `l_1390` | Removed dangling line l_1390 and its leaf bus b2766 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_4231` | Removed dangling line l_4231 and its leaf bus b3352 (leaf has no active elements). |
| 11 | `merge_series_lines` | bus `b885` | Lines l_640 (linecode ughv_400al_triplex_ug_4w_bundled) and l_166 (linecode abc4x16_lv_oh_4w_bundled) at bus b885 have different linecodes — not merged. |
| 12 | `merge_series_lines` | bus `b301` | Lines l_538 (linecode moon_lv_oh_4wire) and l_1211 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b301 have different linecodes — not merged. |
| 13 | `merge_series_lines` | bus `b107` | Lines l_2573 (linecode abc4x16_lv_oh_4w_bundled) and l_2702 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b107 have different linecodes — not merged. |
| 14 | `merge_series_lines` | bus `b504` | Lines l_2127 (linecode moon_lv_oh_4wire) and l_1211 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b504 have different linecodes — not merged. |
| 15 | `merge_series_lines` | bus `b706` | Lines l_3238 (linecode abc4x16_lv_oh_4w_bundled) and l_3095 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b706 have different linecodes — not merged. |
| 16 | `merge_series_lines` | bus `b363` | Lines l_2018 (linecode ughv_400al_triplex_ug_4w_bundled) and l_563 (linecode abc4x16_lv_oh_4w_bundled) at bus b363 have different linecodes — not merged. |
| 17 | `merge_series_lines` | line `l_2597` | Merged line l_950 (0.299153552267 m) into l_2597 at pass-through bus b2551; new length 0.49915355226700003 m. |
| 18 | `merge_series_lines` | bus `b1374` | Lines l_640 (linecode ughv_400al_triplex_ug_4w_bundled) and l_2573 (linecode abc4x16_lv_oh_4w_bundled) at bus b1374 have different linecodes — not merged. |
| 19 | `merge_series_lines` | line `l_2597` | Merged line l_3799 (0.386643049639 m) into l_2597 at pass-through bus b2255; new length 0.885796601906 m. |

