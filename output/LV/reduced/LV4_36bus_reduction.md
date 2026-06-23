# Simplification log: LV4_36bus

**Generated:** 2026-06-23 21:34:02  
**Buses:** 37 → 5 (−32)  
**Lines:** 29 → 3 (−26)  
**Operations:** 34

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 6 |
| `merge_series_lines` | 5 |
| `remove_dangling_lines` | 23 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_1152_closed` | Collapsed closed switch switch_1152_closed: bus b770 merged into b1151. |
| 2 | `collapse_closed_switches` | switch `switch_4331_closed` | Collapsed closed switch switch_4331_closed: bus b3242 merged into b97. |
| 3 | `collapse_closed_switches` | switch `switch_1731_closed` | Collapsed closed switch switch_1731_closed: bus b130 merged into b418. |
| 4 | `collapse_closed_switches` | switch `switch_3847_closed` | Collapsed closed switch switch_3847_closed: bus b239 merged into b3297. |
| 5 | `collapse_closed_switches` | switch `switch_3478_closed` | Collapsed closed switch switch_3478_closed: bus b1756 merged into b1198. |
| 6 | `collapse_closed_switches` | switch `switch_3886_closed` | Collapsed closed switch switch_3886_closed: bus b460 merged into b2598. |
| 7 | `remove_dangling_lines` | line `l_2990` | Removed dangling line l_2990 and its leaf bus b715 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_2999` | Removed dangling line l_2999 and its leaf bus b3044 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `l_4058` | Removed dangling line l_4058 and its leaf bus b97 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_2045` | Removed dangling line l_2045 and its leaf bus b2598 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `l_3365` | Removed dangling line l_3365 and its leaf bus b1500 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_4614` | Removed dangling line l_4614 and its leaf bus b3133 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `l_2469` | Removed dangling line l_2469 and its leaf bus b2517 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `l_439` | Removed dangling line l_439 and its leaf bus b1688 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `l_1820` | Removed dangling line l_1820 and its leaf bus b139 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `l_3902` | Removed dangling line l_3902 and its leaf bus b708 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `l_1612` | Removed dangling line l_1612 and its leaf bus b2993 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `l_1886` | Removed dangling line l_1886 and its leaf bus b756 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `l_4121` | Removed dangling line l_4121 and its leaf bus b263 (leaf has no active elements). |
| 20 | `remove_dangling_lines` | line `l_2074` | Removed dangling line l_2074 and its leaf bus b418 (leaf has no active elements). |
| 21 | `remove_dangling_lines` | line `l_1116` | Removed dangling line l_1116 and its leaf bus b73 (leaf has no active elements). |
| 22 | `remove_dangling_lines` | line `l_411` | Removed dangling line l_411 and its leaf bus b144 (leaf has no active elements). |
| 23 | `remove_dangling_lines` | line `l_3475` | Removed dangling line l_3475 and its leaf bus b1252 (leaf has no active elements). |
| 24 | `remove_dangling_lines` | line `l_3550` | Removed dangling line l_3550 and its leaf bus b2922 (leaf has no active elements). |
| 25 | `remove_dangling_lines` | line `l_4417` | Removed dangling line l_4417 and its leaf bus b1174 (leaf has no active elements). |
| 26 | `remove_dangling_lines` | line `l_4366` | Removed dangling line l_4366 and its leaf bus b2116 (leaf has no active elements). |
| 27 | `remove_dangling_lines` | line `l_1838` | Removed dangling line l_1838 and its leaf bus b721 (leaf has no active elements). |
| 28 | `remove_dangling_lines` | line `l_3689` | Removed dangling line l_3689 and its leaf bus b657 (leaf has no active elements). |
| 29 | `remove_dangling_lines` | line `l_3639` | Removed dangling line l_3639 and its leaf bus b2387 (leaf has no active elements). |
| 30 | `merge_series_lines` | line `l_512` | Merged line l_2044 (0.206301915236 m) into l_512 at pass-through bus b1151; new length 0.2732219817261 m. |
| 31 | `merge_series_lines` | bus `b211` | Lines l_1556 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_2977 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus b211 have different linecodes — not merged. |
| 32 | `merge_series_lines` | line `l_4081` | Merged line l_2869 (0.255748683551 m) into l_4081 at pass-through bus b1198; new length 0.5114973667489999 m. |
| 33 | `merge_series_lines` | line `l_4081` | Merged line l_512 (0.2732219817261 m) into l_4081 at pass-through bus b439; new length 0.7847193484750999 m. |
| 34 | `merge_series_lines` | bus `b3297` | Lines l_1556 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and l_4081 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b3297 have different linecodes — not merged. |

