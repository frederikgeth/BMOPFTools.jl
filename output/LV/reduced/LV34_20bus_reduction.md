# Simplification log: LV34_20bus

**Generated:** 2026-06-23 21:34:02  
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
| 1 | `collapse_closed_switches` | switch `switch_83_closed` | Collapsed closed switch switch_83_closed: bus b1955 merged into b2850. |
| 2 | `collapse_closed_switches` | switch `switch_2724_closed` | Collapsed closed switch switch_2724_closed: bus b1498 merged into b1659. |
| 3 | `remove_dangling_lines` | line `l_863` | Removed dangling line l_863 and its leaf bus b1385 (leaf has no active elements). |
| 4 | `remove_dangling_lines` | line `l_3476` | Removed dangling line l_3476 and its leaf bus b3004 (leaf has no active elements). |
| 5 | `remove_dangling_lines` | line `l_309` | Removed dangling line l_309 and its leaf bus b2139 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_642` | Removed dangling line l_642 and its leaf bus b1425 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_2966` | Removed dangling line l_2966 and its leaf bus b3170 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_2944` | Removed dangling line l_2944 and its leaf bus b393 (leaf has no active elements). |
| 9 | `remove_dangling_lines` | line `l_4660` | Removed dangling line l_4660 and its leaf bus b42 (leaf has no active elements). |
| 10 | `remove_dangling_lines` | line `l_1246` | Removed dangling line l_1246 and its leaf bus b2034 (leaf has no active elements). |
| 11 | `remove_dangling_lines` | line `l_2414` | Removed dangling line l_2414 and its leaf bus b2173 (leaf has no active elements). |
| 12 | `remove_dangling_lines` | line `l_3696` | Removed dangling line l_3696 and its leaf bus b2914 (leaf has no active elements). |
| 13 | `remove_dangling_lines` | line `l_2763` | Removed dangling line l_2763 and its leaf bus b131 (leaf has no active elements). |
| 14 | `merge_series_lines` | line `l_834` | Merged line l_3324 (0.299135511272 m) into l_834 at pass-through bus b2850; new length 0.685764602397 m. |
| 15 | `merge_series_lines` | bus `b801` | Lines l_3054 (linecode ughv_400al_triplex_ug_4w_bundled) and l_1655 (linecode abc4x16_lv_oh_4w_bundled) at bus b801 have different linecodes — not merged. |
| 16 | `merge_series_lines` | bus `b2629` | Lines l_1655 (linecode abc4x16_lv_oh_4w_bundled) and l_188 (linecode ughv_400al_triplex_ug_4w_bundled) at bus b2629 have different linecodes — not merged. |
| 17 | `merge_series_lines` | bus `b3206` | Lines l_188 (linecode ughv_400al_triplex_ug_4w_bundled) and l_2562 (linecode abc4x16_lv_oh_4w_bundled) at bus b3206 have different linecodes — not merged. |
| 18 | `merge_series_lines` | line `l_3054` | Merged line l_834 (0.685764602397 m) into l_3054 at pass-through bus b1659; new length 0.98743644535 m. |

