# Simplification log: LV22_80bus

**Generated:** 2026-06-23 21:34:01  
**Buses:** 81 → 48 (−33)  
**Lines:** 71 → 46 (−25)  
**Operations:** 44

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 8 |
| `merge_series_lines` | 18 |
| `remove_dangling_lines` | 18 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_4468_closed` | Collapsed closed switch switch_4468_closed: bus b307 merged into b2441. |
| 2 | `collapse_closed_switches` | switch `switch_1253_closed` | Collapsed closed switch switch_1253_closed: bus b118 merged into b722. |
| 3 | `collapse_closed_switches` | switch `switch_751_closed` | Collapsed closed switch switch_751_closed: bus b2146 merged into b3351. |
| 4 | `collapse_closed_switches` | switch `switch_2339_closed` | Collapsed closed switch switch_2339_closed: bus b3272 merged into b2660. |
| 5 | `collapse_closed_switches` | switch `switch_2467_closed` | Collapsed closed switch switch_2467_closed: bus b3383 merged into b1915. |
| 6 | `collapse_closed_switches` | switch `switch_3333_closed` | Collapsed closed switch switch_3333_closed: bus b1997 merged into b429. |
| 7 | `collapse_closed_switches` | switch `switch_3062_closed` | Collapsed closed switch switch_3062_closed: bus b3253 merged into b2923. |
| 8 | `collapse_closed_switches` | switch `switch_216_closed` | Collapsed closed switch switch_216_closed: bus b1992 merged into b1061. |
| 9 | `remove_dangling_lines` | line `l_4148` | Removed dangling line l_4148 and its leaf bus b1346 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_3751` | Removed dangling line l_3751 and its leaf bus b3157 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `l_3951` | Removed dangling line l_3951 and its leaf bus b199 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_4312` | Removed dangling line l_4312 and its leaf bus b2210 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `l_2290` | Removed dangling line l_2290 and its leaf bus b1800 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `l_1285` | Removed dangling line l_1285 and its leaf bus b2660 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `l_4461` | Removed dangling line l_4461 and its leaf bus b2563 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `l_3481` | Removed dangling line l_3481 and its leaf bus b3334 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `l_3407` | Removed dangling line l_3407 and its leaf bus b3142 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `l_1006` | Removed dangling line l_1006 and its leaf bus b1879 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `l_651` | Removed dangling line l_651 and its leaf bus b3050 (leaf has no active elements). |
| 20 | `remove_dangling_lines` | line `l_1817` | Removed dangling line l_1817 and its leaf bus b27 (leaf has no active elements). |
| 21 | `remove_dangling_lines` | line `l_3832` | Removed dangling line l_3832 and its leaf bus b365 (leaf has no active elements). |
| 22 | `remove_dangling_lines` | line `l_4160` | Removed dangling line l_4160 and its leaf bus b741 (leaf has no active elements). |
| 23 | `remove_dangling_lines` | line `l_2154` | Removed dangling line l_2154 and its leaf bus b1220 (leaf has no active elements). |
| 24 | `remove_dangling_lines` | line `l_2241` | Removed dangling line l_2241 and its leaf bus b2608 (leaf has no active elements). |
| 25 | `remove_dangling_lines` | line `l_1155` | Removed dangling line l_1155 and its leaf bus b2546 (leaf has no active elements). |
| 26 | `remove_dangling_lines` | line `l_1316` | Removed dangling line l_1316 and its leaf bus b3117 (leaf has no active elements). |
| 27 | `merge_series_lines` | bus `b3314` | Lines l_3173 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_943 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b3314 have different linecodes — not merged. |
| 28 | `merge_series_lines` | bus `b3061` | Lines l_2635 (linecode abc4x16_lv_oh_4w_bundled) and l_943 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b3061 have different linecodes — not merged. |
| 29 | `merge_series_lines` | line `l_4673` | Merged line l_4399 (0.2 m) into l_4673 at pass-through bus b180; new length 0.4 m. |
| 30 | `merge_series_lines` | bus `b1061` | Lines l_1118 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_525 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b1061 have different linecodes — not merged. |
| 31 | `merge_series_lines` | bus `b2066` | Lines l_1256 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and l_544 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b2066 have different linecodes — not merged. |
| 32 | `merge_series_lines` | bus `b2441` | Lines l_3993 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_1042 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b2441 have different linecodes — not merged. |
| 33 | `merge_series_lines` | line `l_4673` | Merged line l_451 (0.30345051448 m) into l_4673 at pass-through bus b459; new length 0.7034505144800001 m. |
| 34 | `merge_series_lines` | line `l_2793` | Merged line l_1042 (0.07477356794840001 m) into l_2793 at pass-through bus b2923; new length 0.39566252615340003 m. |
| 35 | `merge_series_lines` | bus `b1894` | Lines l_4112 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_4385 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b1894 have different linecodes — not merged. |
| 36 | `merge_series_lines` | bus `b1229` | Lines l_1481 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) and l_2946 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b1229 have different linecodes — not merged. |
| 37 | `merge_series_lines` | line `l_3644` | Merged line l_2681 (0.07477356794840001 m) into l_3644 at pass-through bus b1915; new length 0.2810754831844 m. |
| 38 | `merge_series_lines` | bus `b60` | Lines l_336 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_1956 (linecode uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b60 have different linecodes — not merged. |
| 39 | `merge_series_lines` | bus `b3351` | Lines l_3644 (linecode ughv_400al_triplex_ug_4w_bundled) and l_2872 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus b3351 have different linecodes — not merged. |
| 40 | `merge_series_lines` | line `l_41` | Merged line l_4286 (0.255748683198 m) into l_41 at pass-through bus b722; new length 0.5003778586609999 m. |
| 41 | `merge_series_lines` | bus `b1014` | Lines l_4673 (linecode ughv_400al_triplex_ug_4w_bundled) and l_2336 (linecode abc4x16_lv_oh_4w_bundled) at bus b1014 have different linecodes — not merged. |
| 42 | `merge_series_lines` | line `l_4043` | Merged line l_525 (0.07477356794840001 m) into l_4043 at pass-through bus b429; new length 0.6169539638464001 m. |
| 43 | `merge_series_lines` | bus `b2714` | Lines l_259 (linecode ughv_400al_triplex_ug_4w_bundled) and l_1716 (linecode abc4x16_lv_oh_4w_bundled) at bus b2714 have different linecodes — not merged. |
| 44 | `merge_series_lines` | line `l_460` | Merged line l_2872 (68.73582268 m) into l_460 at pass-through bus b3213; new length 72.72719926119 m. |

