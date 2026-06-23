# Simplification log: LV31_15bus

**Generated:** 2026-06-23 21:02:36  
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
| 1 | `collapse_closed_switches` | switch `Switch_405_CLOSED` | Collapsed closed switch Switch_405_CLOSED: bus B886 merged into B1210. |
| 2 | `collapse_closed_switches` | switch `Switch_4054_CLOSED` | Collapsed closed switch Switch_4054_CLOSED: bus B200 merged into B1985. |
| 3 | `collapse_closed_switches` | switch `Switch_2287_CLOSED` | Collapsed closed switch Switch_2287_CLOSED: bus B1735 merged into B1916. |
| 4 | `collapse_closed_switches` | switch `Switch_3756_CLOSED` | Collapsed closed switch Switch_3756_CLOSED: bus B2388 merged into B3156. |
| 5 | `remove_dangling_lines` | line `L_1503` | Removed dangling line L_1503 and its leaf bus B2690 (leaf has no active elements). |
| 6 | `remove_dangling_lines` | line `L_176` | Removed dangling line L_176 and its leaf bus B955 (leaf has no active elements). |
| 7 | `remove_dangling_lines` | line `L_3841` | Removed dangling line L_3841 and its leaf bus B1916 (leaf has no active elements). |
| 8 | `remove_dangling_lines` | line `L_4537` | Removed dangling line L_4537 and its leaf bus B1985 (leaf has no active elements). |
| 9 | `merge_series_lines` | bus `B1279` | Merge blocked: intermediate bus B1279 has non-line elements attached. |
| 10 | `merge_series_lines` | line `L_830` | Merged line L_2235 (0.346777684226 m) into L_830 at pass-through bus B1835; new length 0.602526368131 m. |
| 11 | `merge_series_lines` | line `L_1124` | Merged line L_830 (0.602526368131 m) into L_1124 at pass-through bus B1210; new length 0.8582750513290001 m. |

