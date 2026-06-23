# Simplification log: LV29_90bus

**Generated:** 2026-06-23 21:02:36  
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
| 1 | `collapse_closed_switches` | switch `Switch_95_CLOSED` | Collapsed closed switch Switch_95_CLOSED: bus B1436 merged into B1896. |
| 2 | `collapse_closed_switches` | switch `Switch_3328_CLOSED` | Collapsed closed switch Switch_3328_CLOSED: bus B1533 merged into B1145. |
| 3 | `collapse_closed_switches` | switch `Switch_3662_CLOSED` | Collapsed closed switch Switch_3662_CLOSED: bus B1752 merged into B2961. |
| 4 | `collapse_closed_switches` | switch `Switch_713_CLOSED` | Collapsed closed switch Switch_713_CLOSED: bus B2340 merged into B274. |
| 5 | `collapse_closed_switches` | switch `Switch_1681_CLOSED` | Collapsed closed switch Switch_1681_CLOSED: bus B914 merged into B1967. |
| 6 | `collapse_closed_switches` | switch `Switch_1619_CLOSED` | Collapsed closed switch Switch_1619_CLOSED: bus B3364 merged into B3219. |
| 7 | `collapse_closed_switches` | switch `Switch_1919_CLOSED` | Collapsed closed switch Switch_1919_CLOSED: bus B1600 merged into B884. |
| 8 | `remove_dangling_lines` | line `L_3303` | Removed dangling line L_3303 and its leaf bus B1967 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `L_3447` | Removed dangling line L_3447 and its leaf bus B789 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_3102` | Removed dangling line L_3102 and its leaf bus B772 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `L_654` | Removed dangling line L_654 and its leaf bus B822 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_2188` | Removed dangling line L_2188 and its leaf bus B1700 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `L_2873` | Removed dangling line L_2873 and its leaf bus B2488 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `L_620` | Removed dangling line L_620 and its leaf bus B2448 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `L_4558` | Removed dangling line L_4558 and its leaf bus B2519 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `L_1790` | Removed dangling line L_1790 and its leaf bus B884 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `L_3721` | Removed dangling line L_3721 and its leaf bus B1445 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `L_896` | Removed dangling line L_896 and its leaf bus B3329 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `L_3570` | Removed dangling line L_3570 and its leaf bus B3245 (leaf has no active elements). |
| 20 | `merge_series_lines` | bus `B2961` | Lines L_4116 (linecode ughv_400al_triplex_ug_4w_bundled) and L_2032 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B2961 have different linecodes — not merged. |
| 21 | `merge_series_lines` | line `L_3026` | Merged line L_249 (0.24462917546299998 m) into L_3026 at pass-through bus B274; new length 0.5003778586609999 m. |
| 22 | `merge_series_lines` | line `L_4424` | Merged line L_4116 (0.06692006672510001 m) into L_4424 at pass-through bus B1145; new length 0.3877919184331 m. |
| 23 | `merge_series_lines` | line `L_1929` | Merged line L_3057 (7.8857155722700005 m) into L_1929 at pass-through bus B406; new length 24.04557272677 m. |
| 24 | `merge_series_lines` | bus `B3219` | Lines L_3090 (linecode ughv_400al_triplex_ug_4w_bundled) and L_3748 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B3219 have different linecodes — not merged. |
| 25 | `merge_series_lines` | bus `B1747` | Lines L_1925 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_555 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B1747 have different linecodes — not merged. |
| 26 | `merge_series_lines` | line `L_4088` | Merged line L_2289 (15.973101576000001 m) into L_4088 at pass-through bus B1767; new length 20.15622275204 m. |
| 27 | `merge_series_lines` | line `L_3090` | Merged line L_229 (0.206301915236 m) into L_3090 at pass-through bus B1896; new length 0.27322198196110004 m. |

