# Simplification log: LV13_58bus

**Generated:** 2026-06-23 21:34:00  
**Buses:** 59 → 25 (−34)  
**Lines:** 47 → 23 (−24)  
**Operations:** 40

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 10 |
| `merge_series_lines` | 12 |
| `remove_dangling_lines` | 18 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_2037_closed` | Collapsed closed switch switch_2037_closed: bus b1587 merged into b1323. |
| 2 | `collapse_closed_switches` | switch `switch_2474_closed` | Collapsed closed switch switch_2474_closed: bus b1564 merged into b136. |
| 3 | `collapse_closed_switches` | switch `switch_3581_closed` | Collapsed closed switch switch_3581_closed: bus b2165 merged into b2836. |
| 4 | `collapse_closed_switches` | switch `switch_4508_closed` | Collapsed closed switch switch_4508_closed: bus b3398 merged into b1650. |
| 5 | `collapse_closed_switches` | switch `switch_807_closed` | Collapsed closed switch switch_807_closed: bus b1057 merged into b2959. |
| 6 | `collapse_closed_switches` | switch `switch_1235_closed` | Collapsed closed switch switch_1235_closed: bus b660 merged into b2966. |
| 7 | `collapse_closed_switches` | switch `switch_3177_closed` | Collapsed closed switch switch_3177_closed: bus b207 merged into b520. |
| 8 | `collapse_closed_switches` | switch `switch_3499_closed` | Collapsed closed switch switch_3499_closed: bus b434 merged into b2416. |
| 9 | `collapse_closed_switches` | switch `switch_1078_closed` | Collapsed closed switch switch_1078_closed: bus b2418 merged into b870. |
| 10 | `collapse_closed_switches` | switch `switch_2311_closed` | Collapsed closed switch switch_2311_closed: bus b963 merged into b1260. |
| 11 | `remove_dangling_lines` | line `l_1322` | Removed dangling line l_1322 and its leaf bus b2404 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_2155` | Removed dangling line l_2155 and its leaf bus b132 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `l_4484` | Removed dangling line l_4484 and its leaf bus b3098 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `l_4593` | Removed dangling line l_4593 and its leaf bus b3115 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `l_3252` | Removed dangling line l_3252 and its leaf bus b3395 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `l_3315` | Removed dangling line l_3315 and its leaf bus b683 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `l_2021` | Removed dangling line l_2021 and its leaf bus b2535 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `l_1088` | Removed dangling line l_1088 and its leaf bus b2616 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `l_2992` | Removed dangling line l_2992 and its leaf bus b1159 (leaf has no active elements). |
| 20 | `remove_dangling_lines` | line `l_595` | Removed dangling line l_595 and its leaf bus b987 (leaf has no active elements). |
| 21 | `remove_dangling_lines` | line `l_1726` | Removed dangling line l_1726 and its leaf bus b719 (leaf has no active elements). |
| 22 | `remove_dangling_lines` | line `l_425` | Removed dangling line l_425 and its leaf bus b1519 (leaf has no active elements). |
| 23 | `remove_dangling_lines` | line `l_3128` | Removed dangling line l_3128 and its leaf bus b362 (leaf has no active elements). |
| 24 | `remove_dangling_lines` | line `l_2958` | Removed dangling line l_2958 and its leaf bus b2778 (leaf has no active elements). |
| 25 | `remove_dangling_lines` | line `l_44` | Removed dangling line l_44 and its leaf bus b1863 (leaf has no active elements). |
| 26 | `remove_dangling_lines` | line `l_2583` | Removed dangling line l_2583 and its leaf bus b3160 (leaf has no active elements). |
| 27 | `remove_dangling_lines` | line `l_1330` | Removed dangling line l_1330 and its leaf bus b2959 (leaf has no active elements). |
| 28 | `remove_dangling_lines` | line `l_3546` | Removed dangling line l_3546 and its leaf bus b1260 (leaf has no active elements). |
| 29 | `merge_series_lines` | bus `b3109` | Lines l_1635 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_1835 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b3109 have different linecodes — not merged. |
| 30 | `merge_series_lines` | line `l_3977` | Merged line l_2250 (0.206301915236 m) into l_3977 at pass-through bus b2416; new length 0.2732219817261 m. |
| 31 | `merge_series_lines` | line `l_1879` | Merged line l_2652 (0.0669200664901 m) into l_1879 at pass-through bus b136; new length 0.3878092608211 m. |
| 32 | `merge_series_lines` | line `l_39` | Merged line l_449 (5.8361779806900005 m) into l_39 at pass-through bus b2049; new length 56.28774937269001 m. |
| 33 | `merge_series_lines` | bus `b1867` | Lines l_4674 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and l_2729 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b1867 have different linecodes — not merged. |
| 34 | `merge_series_lines` | line `l_2735` | Merged line l_3603 (0.0669200664901 m) into l_2735 at pass-through bus b2966; new length 0.3878092589051 m. |
| 35 | `merge_series_lines` | bus `b1650` | Lines l_4368 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and l_2165 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b1650 have different linecodes — not merged. |
| 36 | `merge_series_lines` | line `l_39` | Merged line l_1499 (63.76658205660001 m) into l_39 at pass-through bus b1585; new length 120.05433142929002 m. |
| 37 | `merge_series_lines` | bus `b520` | Lines l_2735 (linecode ughv_400al_triplex_ug_4w_bundled) and l_39 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b520 have different linecodes — not merged. |
| 38 | `merge_series_lines` | bus `b870` | Lines l_3977 (linecode ughv_400al_triplex_ug_4w_bundled) and l_1635 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b870 have different linecodes — not merged. |
| 39 | `merge_series_lines` | bus `b1323` | Lines l_494 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_1879 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b1323 have different linecodes — not merged. |
| 40 | `merge_series_lines` | line `l_2425` | Merged line l_1911 (0.255748683198 m) into l_2425 at pass-through bus b2836; new length 0.5114973667489999 m. |

