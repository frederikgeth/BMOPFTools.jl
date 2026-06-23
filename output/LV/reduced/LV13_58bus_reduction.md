# Simplification log: LV13_58bus

**Generated:** 2026-06-23 21:02:35  
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
| 1 | `collapse_closed_switches` | switch `Switch_2311_CLOSED` | Collapsed closed switch Switch_2311_CLOSED: bus B963 merged into B1260. |
| 2 | `collapse_closed_switches` | switch `Switch_2037_CLOSED` | Collapsed closed switch Switch_2037_CLOSED: bus B1587 merged into B1323. |
| 3 | `collapse_closed_switches` | switch `Switch_3177_CLOSED` | Collapsed closed switch Switch_3177_CLOSED: bus B207 merged into B520. |
| 4 | `collapse_closed_switches` | switch `Switch_3581_CLOSED` | Collapsed closed switch Switch_3581_CLOSED: bus B2165 merged into B2836. |
| 5 | `collapse_closed_switches` | switch `Switch_2474_CLOSED` | Collapsed closed switch Switch_2474_CLOSED: bus B1564 merged into B136. |
| 6 | `collapse_closed_switches` | switch `Switch_1078_CLOSED` | Collapsed closed switch Switch_1078_CLOSED: bus B2418 merged into B870. |
| 7 | `collapse_closed_switches` | switch `Switch_807_CLOSED` | Collapsed closed switch Switch_807_CLOSED: bus B1057 merged into B2959. |
| 8 | `collapse_closed_switches` | switch `Switch_1235_CLOSED` | Collapsed closed switch Switch_1235_CLOSED: bus B660 merged into B2966. |
| 9 | `collapse_closed_switches` | switch `Switch_4508_CLOSED` | Collapsed closed switch Switch_4508_CLOSED: bus B3398 merged into B1650. |
| 10 | `collapse_closed_switches` | switch `Switch_3499_CLOSED` | Collapsed closed switch Switch_3499_CLOSED: bus B434 merged into B2416. |
| 11 | `remove_dangling_lines` | line `L_4593` | Removed dangling line L_4593 and its leaf bus B3115 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_3315` | Removed dangling line L_3315 and its leaf bus B683 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `L_4484` | Removed dangling line L_4484 and its leaf bus B3098 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `L_44` | Removed dangling line L_44 and its leaf bus B1863 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `L_3252` | Removed dangling line L_3252 and its leaf bus B3395 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `L_1088` | Removed dangling line L_1088 and its leaf bus B2616 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `L_2583` | Removed dangling line L_2583 and its leaf bus B3160 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `L_2992` | Removed dangling line L_2992 and its leaf bus B1159 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `L_1330` | Removed dangling line L_1330 and its leaf bus B2959 (leaf has no active elements). |
| 20 | `remove_dangling_lines` | line `L_3546` | Removed dangling line L_3546 and its leaf bus B1260 (leaf has no active elements). |
| 21 | `remove_dangling_lines` | line `L_1322` | Removed dangling line L_1322 and its leaf bus B2404 (leaf has no active elements). |
| 22 | `remove_dangling_lines` | line `L_2021` | Removed dangling line L_2021 and its leaf bus B2535 (leaf has no active elements). |
| 23 | `remove_dangling_lines` | line `L_595` | Removed dangling line L_595 and its leaf bus B987 (leaf has no active elements). |
| 24 | `remove_dangling_lines` | line `L_1726` | Removed dangling line L_1726 and its leaf bus B719 (leaf has no active elements). |
| 25 | `remove_dangling_lines` | line `L_425` | Removed dangling line L_425 and its leaf bus B1519 (leaf has no active elements). |
| 26 | `remove_dangling_lines` | line `L_2958` | Removed dangling line L_2958 and its leaf bus B2778 (leaf has no active elements). |
| 27 | `remove_dangling_lines` | line `L_2155` | Removed dangling line L_2155 and its leaf bus B132 (leaf has no active elements). |
| 28 | `remove_dangling_lines` | line `L_3128` | Removed dangling line L_3128 and its leaf bus B362 (leaf has no active elements). |
| 29 | `merge_series_lines` | bus `B3109` | Lines L_1835 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_1635 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B3109 have different linecodes — not merged. |
| 30 | `merge_series_lines` | line `L_39` | Merged line L_1499 (63.76658205660001 m) into L_39 at pass-through bus B1585; new length 114.21815344860002 m. |
| 31 | `merge_series_lines` | bus `B1867` | Lines L_2729 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_4674 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B1867 have different linecodes — not merged. |
| 32 | `merge_series_lines` | bus `B520` | Lines L_449 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_3603 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B520 have different linecodes — not merged. |
| 33 | `merge_series_lines` | bus `B870` | Lines L_3977 (linecode ughv_400al_triplex_ug_4w_bundled) and L_1635 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B870 have different linecodes — not merged. |
| 34 | `merge_series_lines` | line `L_2652` | Merged line L_1879 (0.320889194331 m) into L_2652 at pass-through bus B136; new length 0.3878092608211 m. |
| 35 | `merge_series_lines` | bus `B1650` | Lines L_4368 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and L_2165 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B1650 have different linecodes — not merged. |
| 36 | `merge_series_lines` | line `L_3977` | Merged line L_2250 (0.206301915236 m) into L_3977 at pass-through bus B2416; new length 0.2732219817261 m. |
| 37 | `merge_series_lines` | line `L_1911` | Merged line L_2425 (0.255748683551 m) into L_1911 at pass-through bus B2836; new length 0.5114973667489999 m. |
| 38 | `merge_series_lines` | line `L_3603` | Merged line L_2735 (0.32088919241499997 m) into L_3603 at pass-through bus B2966; new length 0.3878092589051 m. |
| 39 | `merge_series_lines` | line `L_449` | Merged line L_39 (114.21815344860002 m) into L_449 at pass-through bus B2049; new length 120.05433142929002 m. |
| 40 | `merge_series_lines` | bus `B1323` | Lines L_2652 (linecode ughv_400al_triplex_ug_4w_bundled) and L_494 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B1323 have different linecodes — not merged. |

