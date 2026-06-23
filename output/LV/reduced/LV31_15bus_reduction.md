# Simplification log: LV31_15bus

**Generated:** 2026-06-23 21:34:02  
**Buses:** 16 → 6 (−10)  
**Lines:** 10 → 4 (−6)  
**Operations:** 11

## Summary by operation

| Operation | Count |
|-----------|------:|
| `collapse_closed_switches` | 4 |
| `merge_series_lines` | 3 |
| `remove_dangling_lines` | 4 |

## Operation log

| # | Operation | Element | Message |
|--:|-----------|---------|---------|
| 1 | `collapse_closed_switches` | switch `switch_405_closed` | Collapsed closed switch switch_405_closed: bus b886 merged into b1210. |
| 2 | `collapse_closed_switches` | switch `switch_4054_closed` | Collapsed closed switch switch_4054_closed: bus b200 merged into b1985. |
| 3 | `collapse_closed_switches` | switch `switch_2287_closed` | Collapsed closed switch switch_2287_closed: bus b1735 merged into b1916. |
| 4 | `collapse_closed_switches` | switch `switch_3756_closed` | Collapsed closed switch switch_3756_closed: bus b2388 merged into b3156. |
| 5 | `remove_dangling_lines` | line `l_1503` | Removed dangling line l_1503 and its leaf bus b2690 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `l_176` | Removed dangling line l_176 and its leaf bus b955 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `l_3841` | Removed dangling line l_3841 and its leaf bus b1916 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `l_4537` | Removed dangling line l_4537 and its leaf bus b1985 (leaf has no active elements). |
| 9 | `merge_series_lines` | bus `b1279` | Merge blocked: intermediate bus b1279 has non-line elements attached. |
| 10 | `merge_series_lines` | line `l_2235` | Merged line l_830 (0.255748683905 m) into l_2235 at pass-through bus b1835; new length 0.602526368131 m. |
| 11 | `merge_series_lines` | line `l_1124` | Merged line l_2235 (0.602526368131 m) into l_1124 at pass-through bus b1210; new length 0.8582750513290001 m. |

