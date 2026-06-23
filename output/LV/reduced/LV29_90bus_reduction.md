# Simplification log: LV29_90bus

**Generated:** 2026-06-23 21:34:01  
**Buses:** 91 → 67 (−24)  
**Lines:** 82 → 65 (−17)  
**Operations:** 27

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 7 |
| `merge_series_lines` | 8 |
| `remove_dangling_lines` | 12 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_3328_closed` | Collapsed closed switch switch_3328_closed: bus b1533 merged into b1145. |
| 2 | `collapse_closed_switches` | switch `switch_1681_closed` | Collapsed closed switch switch_1681_closed: bus b914 merged into b1967. |
| 3 | `collapse_closed_switches` | switch `switch_1919_closed` | Collapsed closed switch switch_1919_closed: bus b1600 merged into b884. |
| 4 | `collapse_closed_switches` | switch `switch_95_closed` | Collapsed closed switch switch_95_closed: bus b1436 merged into b1896. |
| 5 | `collapse_closed_switches` | switch `switch_3662_closed` | Collapsed closed switch switch_3662_closed: bus b1752 merged into b2961. |
| 6 | `collapse_closed_switches` | switch `switch_713_closed` | Collapsed closed switch switch_713_closed: bus b2340 merged into b274. |
| 7 | `collapse_closed_switches` | switch `switch_1619_closed` | Collapsed closed switch switch_1619_closed: bus b3364 merged into b3219. |
| 8 | `remove_dangling_lines` | line `l_4558` | Removed dangling line l_4558 and its leaf bus b2519 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `l_3303` | Removed dangling line l_3303 and its leaf bus b1967 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_620` | Removed dangling line l_620 and its leaf bus b2448 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `l_3102` | Removed dangling line l_3102 and its leaf bus b772 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_3721` | Removed dangling line l_3721 and its leaf bus b1445 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `l_1790` | Removed dangling line l_1790 and its leaf bus b884 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `l_3447` | Removed dangling line l_3447 and its leaf bus b789 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `l_896` | Removed dangling line l_896 and its leaf bus b3329 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `l_3570` | Removed dangling line l_3570 and its leaf bus b3245 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `l_2873` | Removed dangling line l_2873 and its leaf bus b2488 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `l_654` | Removed dangling line l_654 and its leaf bus b822 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `l_2188` | Removed dangling line l_2188 and its leaf bus b1700 (leaf has no active elements). |
| 20 | `merge_series_lines` | line `l_3057` | Merged line l_1929 (16.1598571545 m) into l_3057 at pass-through bus b406; new length 24.04557272677 m. |
| 21 | `merge_series_lines` | line `l_3026` | Merged line l_249 (0.24462917546299998 m) into l_3026 at pass-through bus b274; new length 0.5003778586609999 m. |
| 22 | `merge_series_lines` | bus `b1747` | Lines l_555 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_1925 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b1747 have different linecodes — not merged. |
| 23 | `merge_series_lines` | bus `b3219` | Lines l_3748 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_3090 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b3219 have different linecodes — not merged. |
| 24 | `merge_series_lines` | line `l_3090` | Merged line l_229 (0.206301915236 m) into l_3090 at pass-through bus b1896; new length 0.27322198196110004 m. |
| 25 | `merge_series_lines` | line `l_4116` | Merged line l_4424 (0.320871851708 m) into l_4116 at pass-through bus b1145; new length 0.3877919184331 m. |
| 26 | `merge_series_lines` | bus `b2961` | Lines l_4116 (linecode ughv_400al_triplex_ug_4w_bundled) and l_2032 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b2961 have different linecodes — not merged. |
| 27 | `merge_series_lines` | line `l_4088` | Merged line l_2289 (15.973101576000001 m) into l_4088 at pass-through bus b1767; new length 20.15622275204 m. |

