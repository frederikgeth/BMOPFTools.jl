# BMOPFTools.jl logo

The mark shows a radial feeder, starting at a transformer, that descends
through the contour lines of an objective along a solver path to the optimum.
The node colors are Julia's four colors, standing for phases a, b and c
(red, green, purple) and the neutral (blue). The style (warm cream ground,
dark-brown outlines, flat fills, Poppins) follows the
[PowerIO](https://github.com/eigenergy/powerio) artwork.

All files live in [`docs/src/assets/logo/`](../../docs/src/assets/logo/), each
as SVG, PNG and PDF. Text in the SVGs is converted to outlines, so they render
the same without the font installed.

| File stem | Use |
|---|---|
| `bmopftools-hero` | README and docs home banner (1600×720; also `@2x` PNG) |
| `bmopftools-social` | GitHub social preview (1280×640) |
| `bmopftools-lockup`, `-dark` | Mark + wordmark + tagline, transparent background (also `@2x` PNG) |
| `bmopftools-lockup-stacked`, `-dark` | Mark above wordmark, for square spaces (also `@2x` PNG) |
| `bmopftools-mark`, `-dark` | Mark only, full color, transparent background |
| `bmopftools-mark-mono`, `-mono-reversed` | One-color mark for print and single-color use |
| `bmopftools-icon`, `-dark` | App-icon tile: avatars, slides, package registries |
| `bmopftools-mark-small`, `-small-dark`, `bmopftools-icon-small` | Simplified geometry for 16–48 px; the favicon source |

Wired up elsewhere:

- `docs/src/assets/logo.svg` and `logo-dark.svg`: Documenter's sidebar logo
  (copies of `bmopftools-mark` and `bmopftools-mark-dark`).
- `docs/src/assets/favicon.ico`: 16, 32 and 48 px from `bmopftools-icon-small`,
  registered in `docs/make.jl`.
- GitHub social preview: upload `bmopftools-social.png` under the repository's
  Settings › General › Social preview. GitHub has no API for this.

## Palette

| Role | Light | Dark |
|---|---|---|
| Ink (outlines, wordmark) | `#26221F` | `#F2EBDD` |
| Paper | `#FBF7EF` | `#26221F` |
| Ground | `#F3EDE2` | `#1A1714` |
| Contours | `#D3BC8C` | `#7A6A4C` |
| Phase a / b / c | `#CB3C33` / `#389826` / `#9558B2` | `#D66661` / `#6BAB5B` / `#AA79C1` |
| Neutral, optimum | `#4063D8` | `#6682DF` |

## Regenerating

Every file is generated from the geometry in
[`generate_logo_assets.py`](generate_logo_assets.py); edit that, not the
outputs. It needs Python with `fonttools` and `pillow`, the `rsvg-convert`
binary (librsvg), and the Poppins and IBM Plex Mono TTF files from
[Google Fonts](https://github.com/google/fonts) (SIL Open Font License):

```bash
python3 -m venv /tmp/logo-venv && /tmp/logo-venv/bin/pip install fonttools pillow
/tmp/logo-venv/bin/python scripts/logo/generate_logo_assets.py --fonts /path/to/fonts
```

The fonts directory must contain `Poppins-Regular.ttf`, `Poppins-Medium.ttf`,
`Poppins-SemiBold.ttf`, `Poppins-Bold.ttf` and `IBMPlexMono-Medium.ttf`.
