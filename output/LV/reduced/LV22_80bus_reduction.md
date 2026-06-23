# Simplification log: LV22_80bus

**Generated:** 2026-06-23 21:02:36  
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
| 1 | `collapse_closed_switches` | switch `Switch_2339_CLOSED` | Collapsed closed switch Switch_2339_CLOSED: bus B3272 merged into B2660. |
| 2 | `collapse_closed_switches` | switch `Switch_1253_CLOSED` | Collapsed closed switch Switch_1253_CLOSED: bus B118 merged into B722. |
| 3 | `collapse_closed_switches` | switch `Switch_4468_CLOSED` | Collapsed closed switch Switch_4468_CLOSED: bus B307 merged into B2441. |
| 4 | `collapse_closed_switches` | switch `Switch_216_CLOSED` | Collapsed closed switch Switch_216_CLOSED: bus B1992 merged into B1061. |
| 5 | `collapse_closed_switches` | switch `Switch_2467_CLOSED` | Collapsed closed switch Switch_2467_CLOSED: bus B3383 merged into B1915. |
| 6 | `collapse_closed_switches` | switch `Switch_3333_CLOSED` | Collapsed closed switch Switch_3333_CLOSED: bus B1997 merged into B429. |
| 7 | `collapse_closed_switches` | switch `Switch_3062_CLOSED` | Collapsed closed switch Switch_3062_CLOSED: bus B3253 merged into B2923. |
| 8 | `collapse_closed_switches` | switch `Switch_751_CLOSED` | Collapsed closed switch Switch_751_CLOSED: bus B2146 merged into B3351. |
| 9 | `remove_dangling_lines` | line `L_1316` | Removed dangling line L_1316 and its leaf bus B3117 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_4312` | Removed dangling line L_4312 and its leaf bus B2210 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `L_1817` | Removed dangling line L_1817 and its leaf bus B27 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_1006` | Removed dangling line L_1006 and its leaf bus B1879 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `L_3751` | Removed dangling line L_3751 and its leaf bus B3157 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `L_2290` | Removed dangling line L_2290 and its leaf bus B1800 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `L_651` | Removed dangling line L_651 and its leaf bus B3050 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `L_1155` | Removed dangling line L_1155 and its leaf bus B2546 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `L_2154` | Removed dangling line L_2154 and its leaf bus B1220 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `L_1285` | Removed dangling line L_1285 and its leaf bus B2660 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `L_4148` | Removed dangling line L_4148 and its leaf bus B1346 (leaf has no active elements). |
| 20 | `remove_dangling_lines` | line `L_3481` | Removed dangling line L_3481 and its leaf bus B3334 (leaf has no active elements). |
| 21 | `remove_dangling_lines` | line `L_3407` | Removed dangling line L_3407 and its leaf bus B3142 (leaf has no active elements). |
| 22 | `remove_dangling_lines` | line `L_2241` | Removed dangling line L_2241 and its leaf bus B2608 (leaf has no active elements). |
| 23 | `remove_dangling_lines` | line `L_3832` | Removed dangling line L_3832 and its leaf bus B365 (leaf has no active elements). |
| 24 | `remove_dangling_lines` | line `L_4461` | Removed dangling line L_4461 and its leaf bus B2563 (leaf has no active elements). |
| 25 | `remove_dangling_lines` | line `L_4160` | Removed dangling line L_4160 and its leaf bus B741 (leaf has no active elements). |
| 26 | `remove_dangling_lines` | line `L_3951` | Removed dangling line L_3951 and its leaf bus B199 (leaf has no active elements). |
| 27 | `merge_series_lines` | bus `B1894` | Lines L_4112 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_4385 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B1894 have different linecodes — not merged. |
| 28 | `merge_series_lines` | bus `B1014` | Lines L_2336 (linecode abc4x16_lv_oh_4w_bundled) and L_451 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B1014 have different linecodes — not merged. |
| 29 | `merge_series_lines` | bus `B2066` | Lines L_544 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_1256 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B2066 have different linecodes — not merged. |
| 30 | `merge_series_lines` | line `L_4043` | Merged line L_525 (0.07477356794840001 m) into L_4043 at pass-through bus B429; new length 0.6169539638464001 m. |
| 31 | `merge_series_lines` | bus `B2441` | Lines L_3993 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_1042 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B2441 have different linecodes — not merged. |
| 32 | `merge_series_lines` | line `L_4399` | Merged line L_451 (0.30345051448 m) into L_4399 at pass-through bus B459; new length 0.50345051448 m. |
| 33 | `merge_series_lines` | line `L_4673` | Merged line L_4399 (0.50345051448 m) into L_4673 at pass-through bus B180; new length 0.7034505144800001 m. |
| 34 | `merge_series_lines` | bus `B3351` | Lines L_2681 (linecode ughv_400al_triplex_ug_4w_bundled) and L_2872 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B3351 have different linecodes — not merged. |
| 35 | `merge_series_lines` | bus `B3061` | Lines L_2635 (linecode abc4x16_lv_oh_4w_bundled) and L_943 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B3061 have different linecodes — not merged. |
| 36 | `merge_series_lines` | bus `B1061` | Lines L_1118 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_4043 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B1061 have different linecodes — not merged. |
| 37 | `merge_series_lines` | bus `B2714` | Lines L_1716 (linecode abc4x16_lv_oh_4w_bundled) and L_259 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B2714 have different linecodes — not merged. |
| 38 | `merge_series_lines` | line `L_3644` | Merged line L_2681 (0.07477356794840001 m) into L_3644 at pass-through bus B1915; new length 0.2810754831844 m. |
| 39 | `merge_series_lines` | line `L_460` | Merged line L_2872 (68.73582268 m) into L_460 at pass-through bus B3213; new length 72.72719926119 m. |
| 40 | `merge_series_lines` | bus `B1229` | Lines L_2946 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_1481 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B1229 have different linecodes — not merged. |
| 41 | `merge_series_lines` | bus `B60` | Lines L_1956 (linecode uglv_185cu_xlpe/nyl/pvc_ug_4w_bundled) and L_336 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B60 have different linecodes — not merged. |
| 42 | `merge_series_lines` | line `L_1042` | Merged line L_2793 (0.320888958205 m) into L_1042 at pass-through bus B2923; new length 0.39566252615340003 m. |
| 43 | `merge_series_lines` | bus `B3314` | Lines L_3173 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_943 (linecode ughv_400al_triplex_ug_4w_bundled) at bus B3314 have different linecodes — not merged. |
| 44 | `merge_series_lines` | line `L_4286` | Merged line L_41 (0.24462917546299998 m) into L_4286 at pass-through bus B722; new length 0.5003778586609999 m. |

