# Simplification log: LV34_20bus

**Generated:** 2026-06-23 21:02:37  
**Buses:** 21 → 6 (−15)  
**Lines:** 17 → 4 (−13)  
**Operations:** 18

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 2 |
| `merge_series_lines` | 5 |
| `remove_dangling_lines` | 11 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `Switch_83_CLOSED` | Collapsed closed switch Switch_83_CLOSED: bus B1955 merged into B2850. |
| 2 | `collapse_closed_switches` | switch `Switch_2724_CLOSED` | Collapsed closed switch Switch_2724_CLOSED: bus B1498 merged into B1659. |
| 3 | `remove_dangling_lines` | line `L_2966` | Removed dangling line L_2966 and its leaf bus B3170 (leaf has no active elements). |
| 4 | `remove_dangling_lines` | line `L_3476` | Removed dangling line L_3476 and its leaf bus B3004 (leaf has no active elements). |
| 5 | `remove_dangling_lines` | line `L_309` | Removed dangling line L_309 and its leaf bus B2139 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_642` | Removed dangling line L_642 and its leaf bus B1425 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_863` | Removed dangling line L_863 and its leaf bus B1385 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_2944` | Removed dangling line L_2944 and its leaf bus B393 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `L_4660` | Removed dangling line L_4660 and its leaf bus B42 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `L_1246` | Removed dangling line L_1246 and its leaf bus B2034 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `L_2414` | Removed dangling line L_2414 and its leaf bus B2173 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `L_3696` | Removed dangling line L_3696 and its leaf bus B2914 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `L_2763` | Removed dangling line L_2763 and its leaf bus B131 (leaf has no active elements). |
| 14 | `merge_series_lines` | line `L_3324` | Merged line L_3054 (0.301671842953 m) into L_3324 at pass-through bus B1659; new length 0.600807354225 m. |
| 15 | `merge_series_lines` | bus `B801` | Lines L_3324 (linecode ughv_400al_triplex_ug_4w_bundled) and L_1655 (linecode abc4x16_lv_oh_4w_bundled) at bus B801 have different linecodes — not merged. |
| 16 | `merge_series_lines` | line `L_3324` | Merged line L_834 (0.386629091125 m) into L_3324 at pass-through bus B2850; new length 0.98743644535 m. |
| 17 | `merge_series_lines` | bus `B3206` | Lines L_188 (linecode ughv_400al_triplex_ug_4w_bundled) and L_2562 (linecode abc4x16_lv_oh_4w_bundled) at bus B3206 have different linecodes — not merged. |
| 18 | `merge_series_lines` | bus `B2629` | Lines L_188 (linecode ughv_400al_triplex_ug_4w_bundled) and L_1655 (linecode abc4x16_lv_oh_4w_bundled) at bus B2629 have different linecodes — not merged. |

