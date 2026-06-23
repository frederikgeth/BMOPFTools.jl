# Simplification log: LV4_36bus

**Generated:** 2026-06-23 21:02:37  
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
| 1 | `collapse_closed_switches` | switch `Switch_3478_CLOSED` | Collapsed closed switch Switch_3478_CLOSED: bus B1756 merged into B1198. |
| 2 | `collapse_closed_switches` | switch `Switch_1152_CLOSED` | Collapsed closed switch Switch_1152_CLOSED: bus B770 merged into B1151. |
| 3 | `collapse_closed_switches` | switch `Switch_3847_CLOSED` | Collapsed closed switch Switch_3847_CLOSED: bus B239 merged into B3297. |
| 4 | `collapse_closed_switches` | switch `Switch_3886_CLOSED` | Collapsed closed switch Switch_3886_CLOSED: bus B460 merged into B2598. |
| 5 | `collapse_closed_switches` | switch `Switch_4331_CLOSED` | Collapsed closed switch Switch_4331_CLOSED: bus B3242 merged into B97. |
| 6 | `collapse_closed_switches` | switch `Switch_1731_CLOSED` | Collapsed closed switch Switch_1731_CLOSED: bus B130 merged into B418. |
| 7 | `remove_dangling_lines` | line `L_4058` | Removed dangling line L_4058 and its leaf bus B97 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_1820` | Removed dangling line L_1820 and its leaf bus B139 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `L_1612` | Removed dangling line L_1612 and its leaf bus B2993 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_2990` | Removed dangling line L_2990 and its leaf bus B715 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `L_4121` | Removed dangling line L_4121 and its leaf bus B263 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_2045` | Removed dangling line L_2045 and its leaf bus B2598 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `L_2074` | Removed dangling line L_2074 and its leaf bus B418 (leaf has no active elements). |
| 14 | `remove_dangling_lines` | line `L_2469` | Removed dangling line L_2469 and its leaf bus B2517 (leaf has no active elements). |
| 15 | `remove_dangling_lines` | line `L_439` | Removed dangling line L_439 and its leaf bus B1688 (leaf has no active elements). |
| 16 | `remove_dangling_lines` | line `L_4614` | Removed dangling line L_4614 and its leaf bus B3133 (leaf has no active elements). |
| 17 | `remove_dangling_lines` | line `L_3902` | Removed dangling line L_3902 and its leaf bus B708 (leaf has no active elements). |
| 18 | `remove_dangling_lines` | line `L_3475` | Removed dangling line L_3475 and its leaf bus B1252 (leaf has no active elements). |
| 19 | `remove_dangling_lines` | line `L_3550` | Removed dangling line L_3550 and its leaf bus B2922 (leaf has no active elements). |
| 20 | `remove_dangling_lines` | line `L_3365` | Removed dangling line L_3365 and its leaf bus B1500 (leaf has no active elements). |
| 21 | `remove_dangling_lines` | line `L_2999` | Removed dangling line L_2999 and its leaf bus B3044 (leaf has no active elements). |
| 22 | `remove_dangling_lines` | line `L_1886` | Removed dangling line L_1886 and its leaf bus B756 (leaf has no active elements). |
| 23 | `remove_dangling_lines` | line `L_1116` | Removed dangling line L_1116 and its leaf bus B73 (leaf has no active elements). |
| 24 | `remove_dangling_lines` | line `L_411` | Removed dangling line L_411 and its leaf bus B144 (leaf has no active elements). |
| 25 | `remove_dangling_lines` | line `L_4417` | Removed dangling line L_4417 and its leaf bus B1174 (leaf has no active elements). |
| 26 | `remove_dangling_lines` | line `L_4366` | Removed dangling line L_4366 and its leaf bus B2116 (leaf has no active elements). |
| 27 | `remove_dangling_lines` | line `L_1838` | Removed dangling line L_1838 and its leaf bus B721 (leaf has no active elements). |
| 28 | `remove_dangling_lines` | line `L_3689` | Removed dangling line L_3689 and its leaf bus B657 (leaf has no active elements). |
| 29 | `remove_dangling_lines` | line `L_3639` | Removed dangling line L_3639 and its leaf bus B2387 (leaf has no active elements). |
| 30 | `merge_series_lines` | line `L_2869` | Merged line L_4081 (0.255748683198 m) into L_2869 at pass-through bus B1198; new length 0.5114973667489999 m. |
| 31 | `merge_series_lines` | line `L_2869` | Merged line L_2044 (0.206301915236 m) into L_2869 at pass-through bus B439; new length 0.7177992819849999 m. |
| 32 | `merge_series_lines` | line `L_2869` | Merged line L_512 (0.0669200664901 m) into L_2869 at pass-through bus B1151; new length 0.7847193484750998 m. |
| 33 | `merge_series_lines` | bus `B211` | Lines L_1556 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) and L_2977 (linecode ugsc_16cu_xlpe/nyl/pvc_ug_4w_bundled) at bus B211 have different linecodes — not merged. |
| 34 | `merge_series_lines` | bus `B3297` | Lines L_2869 (linecode ughv_400al_triplex_ug_4w_bundled) and L_1556 (linecode uglv_240al_xlpe/nyl/pvc_ug_4w_bundled) at bus B3297 have different linecodes — not merged. |

