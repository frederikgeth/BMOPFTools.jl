#!/usr/bin/env python3
"""Generate the BMOPFTools.jl logo assets (concept "B4").

Writes SVG, PNG and PDF versions of every logo variant to
docs/src/assets/logo/, the Documenter sidebar logo and favicon to
docs/src/assets/, from one set of geometry defined below.

Text is converted to Poppins glyph outlines, so the SVGs render identically
without the font installed (GitHub, browsers, PDF viewers).

Requirements: Python packages ``fonttools`` and ``pillow``, the
``rsvg-convert`` binary (librsvg), and the Poppins and IBM Plex Mono TTF files
(SIL Open Font License; https://github.com/google/fonts):

    python3 scripts/logo/generate_logo_assets.py --fonts /path/to/fonts

The fonts directory must contain Poppins-Regular.ttf, Poppins-Medium.ttf,
Poppins-SemiBold.ttf, Poppins-Bold.ttf and IBMPlexMono-Medium.ttf.
"""

from __future__ import annotations

import argparse
import io
import shutil
import subprocess
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "docs" / "src" / "assets" / "logo"
DOC_ASSETS = REPO / "docs" / "src" / "assets"

TAGLINE = "Inspect, prepare, and optimize unbalanced distribution networks"

# Palette: PowerIO-style warm neutrals plus Julia's four colors, which stand
# for phases a, b, c (red, green, purple) and the neutral (blue).
LIGHT = dict(
    ink="#26221F", cream="#FBF7EF", tan="#D3BC8C", wash="#EFE9DD",
    red="#CB3C33", green="#389826", purple="#9558B2", blue="#4063D8",
    muted="#8A7E6C", sub="#6B6257", ground="#F3EDE2",
)
DARK = dict(
    ink="#F2EBDD", cream="#26221F", tan="#7A6A4C", wash="#3A332B",
    red="#D66661", green="#6BAB5B", purple="#AA79C1", blue="#6682DF",
    muted="#B3A68F", sub="#C9BEAB", ground="#1A1714",
)


# --------------------------------------------------------------------------
# Text to outlines
# --------------------------------------------------------------------------

class Font:
    def __init__(self, path: Path):
        self.tt = TTFont(str(path))
        self.glyphs = self.tt.getGlyphSet()
        self.cmap = self.tt.getBestCmap()
        self.upm = self.tt["head"].unitsPerEm
        self.hmtx = self.tt["hmtx"]

    def width(self, text: str, size: float, tracking: float = 0.0) -> float:
        adv = sum(self.hmtx[self.cmap[ord(c)]][0] for c in text)
        return adv * size / self.upm + tracking * max(len(text) - 1, 0)

    def path(self, text: str, size: float, x: float, y: float,
             tracking: float = 0.0) -> str:
        """SVG path data for ``text`` with its baseline starting at (x, y)."""
        scale = size / self.upm
        pen = SVGPathPen(self.glyphs)
        cursor = x
        for c in text:
            name = self.cmap[ord(c)]
            tpen = TransformPen(pen, (scale, 0, 0, -scale, cursor, y))
            self.glyphs[name].draw(tpen)
            cursor += self.hmtx[name][0] * scale + tracking
        return pen.getCommands()


FONTS: dict[str, Font] = {}


def text(s: str, font: str, size: float, x: float, y: float, fill: str,
         anchor: str = "start", tracking: float = 0.0) -> str:
    f = FONTS[font]
    w = f.width(s, size, tracking)
    if anchor == "middle":
        x -= w / 2
    elif anchor == "end":
        x -= w
    return f'<path fill="{fill}" d="{f.path(s, size, x, y, tracking)}"/>'


def wordmark(size: float, x: float, y: float, c: dict, anchor: str = "start") -> tuple[str, float]:
    """'BMOPFTools' in Poppins Bold plus '.jl' in Poppins Medium."""
    tracking = -size * 0.026
    main, ext = "BMOPFTools", ".jl"
    w_main = FONTS["bold"].width(main, size, tracking)
    w_ext = FONTS["medium"].width(ext, size, tracking)
    total = w_main + tracking + w_ext
    if anchor == "middle":
        x -= total / 2
    svg = (text(main, "bold", size, x, y, c["ink"], tracking=tracking)
           + text(ext, "medium", size, x + w_main + tracking, y, c["muted"], tracking=tracking))
    return svg, total


# --------------------------------------------------------------------------
# The mark (B4: feeder descending contours along a solver path), 120x120 units
# --------------------------------------------------------------------------

def mark(c: dict, small: bool = False, mono: bool = False) -> str:
    ink, cream = c["ink"], c["cream"]
    tan = ink if mono else c["tan"]
    wash = cream if mono else c["wash"]

    def node(col):
        return (ink if small else cream) if mono else col

    blue = ink if mono else c["blue"]
    ew, nr, orr, nw = (9, 11, 15, 0) if small else (4.5, 7, 10, 3)
    parts = []
    if small:
        # Favicon sizes: one bold contour, no transformer or iterates, cropped tighter.
        parts.append('<g transform="translate(60 60) scale(1.2) translate(-62 -57)">')
        parts.append(f'<ellipse cx="68" cy="70" rx="30" ry="22" fill="none" stroke="{tan}" stroke-width="7"/>')
    else:
        parts.append(
            f'<ellipse cx="68" cy="70" rx="47" ry="36" fill="none" stroke="{tan}" stroke-width="2.5"/>'
            f'<ellipse cx="68" cy="70" rx="33" ry="25" fill="none" stroke="{tan}" stroke-width="2.5"/>'
            f'<ellipse cx="68" cy="70" rx="19" ry="14" fill="{wash}" stroke="{tan}" stroke-width="2.5"/>')
    parts.append(
        f'<g fill="none" stroke="{ink}" stroke-width="{ew}" stroke-linecap="round" stroke-linejoin="round">'
        '<path d="M24 24 L52 34 L44 52 L62 58 L60 66 L68 70"/><path d="M52 34 L80 26"/><path d="M44 52 L28 80"/></g>')
    if not small:
        parts.append(
            f'<circle cx="15" cy="15" r="9" fill="{cream}" stroke="{ink}" stroke-width="3"/>'
            f'<circle cx="24" cy="24" r="9" fill="{cream}" stroke="{ink}" stroke-width="3"/>'
            f'<g fill="{cream}" stroke="{ink}" stroke-width="2.5">'
            '<circle cx="44" cy="52" r="4.5"/><circle cx="62" cy="58" r="3.5"/><circle cx="60" cy="66" r="2.5"/></g>')
    parts.append(
        f'<circle cx="52" cy="34" r="{nr}" fill="{node(c["red"])}" stroke="{ink}" stroke-width="{nw}"/>'
        f'<circle cx="80" cy="26" r="{nr}" fill="{node(c["green"])}" stroke="{ink}" stroke-width="{nw}"/>'
        f'<circle cx="28" cy="80" r="{nr}" fill="{node(c["purple"])}" stroke="{ink}" stroke-width="{nw}"/>'
        f'<circle cx="68" cy="70" r="{orr}" fill="{blue}" stroke="{ink}" stroke-width="{nw}"/>')
    if small:
        parts.append("</g>")
    return "".join(parts)


def tile(c: dict, small: bool = False) -> str:
    tw = 6 if small else 4
    return (f'<rect x="4" y="4" width="112" height="112" rx="28" fill="{c["cream"]}" '
            f'stroke="{c["ink"]}" stroke-width="{tw}"/>'
            f'<g transform="translate(10 9) scale(0.82)">{mark(c, small=small)}</g>')


def svg_doc(w: float, h: float, body: str, title: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:g}" height="{h:g}" '
            f'viewBox="0 0 {w:g} {h:g}" role="img" aria-label="{title}">'
            f'<title>{title}</title>{body}</svg>\n')


def place(inner: str, x: float, y: float, size: float) -> str:
    """Place a 120-unit drawing at (x, y) with the given pixel size."""
    return f'<g transform="translate({x:g} {y:g}) scale({size / 120:g})">{inner}</g>'


# --------------------------------------------------------------------------
# Compositions
# --------------------------------------------------------------------------

def lockup(c: dict) -> str:
    m = 120
    wm, w_wm = wordmark(50, m + 16, 62, c)
    tag_w = FONTS["regular"].width(TAGLINE, 15)
    w = m + 16 + max(w_wm, tag_w) + 4
    body = place(mark(c), 0, 0, m) + wm + text(TAGLINE, "regular", 15, m + 16, 90, c["sub"])
    return svg_doc(round(w), m, body, "BMOPFTools.jl: " + TAGLINE)


def lockup_stacked(c: dict) -> str:
    m = 150
    _, w_wm = wordmark(46, 0, 0, c)
    w = max(m, w_wm) + 8
    wm, _ = wordmark(46, w / 2, m + 46, c, anchor="middle")
    body = place(mark(c), (w - m) / 2, 0, m) + wm
    return svg_doc(round(w), m + 62, body, "BMOPFTools.jl")


WIRES = [("red", 0), ("green", 14), ("purple", 28), ("blue", 42)]


def wire_band(c: dict, y0: float, x0: float, x1: float) -> str:
    out = ['<g stroke-linecap="round">']
    for col, dy in WIRES:
        y = y0 + dy
        out.append(f'<path d="M{x0:g} {y:g} H{x1:g}" stroke="{c["ink"]}" stroke-width="8"/>'
                   f'<path d="M{x0:g} {y:g} H{x1:g}" stroke="{c[col]}" stroke-width="4.5"/>')
    out.append("</g>")
    return "".join(out)


def card(x: float, w: float, c: dict) -> str:
    return (f'<rect x="{x}" y="106" width="{w}" height="220" rx="18" fill="{c["ink"]}" opacity="0.1"/>'
            f'<rect x="{x}" y="100" width="{w}" height="220" rx="18" fill="#FFFDF8" stroke="{c["ink"]}" stroke-width="3"/>')


def hero_band(c: dict) -> str:
    """The illustrated pipeline (1600x440 units): import, inspect, prepare, optimize, verify."""
    ink, red, green, purple, blue = c["ink"], c["red"], c["green"], c["purple"], c["blue"]
    paper, tan, rule = "#FFFDF8", c["tan"], "#E4D7BE"
    p = [f'<ellipse cx="800" cy="404" rx="740" ry="20" fill="{ink}" opacity="0.07"/>',
         wire_band(c, 204, 24, 1576)]

    # Import: two file sheets
    def sheet(x, y, tab, extra, label, rot, cx, cy):
        return (f'<g transform="rotate({rot} {cx} {cy})">'
                f'<rect x="{x}" y="{y + 7}" width="150" height="190" rx="10" fill="{ink}" opacity="0.1"/>'
                f'<path d="M{x + 10} {y} H{x + 122} L{x + 150} {y + 28} V{y + 180} A10 10 0 0 1 {x + 140} {y + 190} '
                f'H{x + 10} A10 10 0 0 1 {x} {y + 180} V{y + 10} A10 10 0 0 1 {x + 10} {y} Z" '
                f'fill="{paper}" stroke="{ink}" stroke-width="3"/>'
                f'<path d="M{x + 122} {y} V{y + 28} H{x + 150}" fill="#EFE9DD" stroke="{ink}" stroke-width="3" stroke-linejoin="round"/>'
                f'<rect x="{x + 18}" y="{y + 20}" width="56" height="12" rx="6" fill="{tab}"/>'
                + extra + text(label, "mono", 20, x + 12, y + 172, ink) + '</g>')

    lines = (f'<g stroke="{rule}" stroke-width="5" stroke-linecap="round">'
             '<path d="M98 166 H206"/><path d="M98 184 H196"/><path d="M98 202 H206"/>'
             '<path d="M98 220 H180"/><path d="M98 238 H200"/></g>')
    graph = (f'<g fill="none" stroke="{ink}" stroke-width="3" stroke-linecap="round">'
             '<path d="M180 186 L208 202 L236 222 L262 244"/><path d="M208 202 L246 188"/><path d="M236 222 L210 258"/></g>'
             f'<g fill="{paper}" stroke="{ink}" stroke-width="2.5"><circle cx="180" cy="186" r="6"/>'
             '<circle cx="208" cy="202" r="6"/><circle cx="236" cy="222" r="6"/><circle cx="246" cy="188" r="6"/>'
             '<circle cx="210" cy="258" r="6"/></g>'
             f'<circle cx="262" cy="244" r="6" fill="{purple}" stroke="{ink}" stroke-width="2.5"/>')
    p.append(sheet(78, 112, red, lines, ".dss", -6, 150, 210))
    p.append(sheet(150, 128, blue, graph, ".json", 5, 220, 220))

    # Inspect: network under a magnifier, with a flagged node
    p.append(card(370, 250, c))
    p.append(f'<g fill="none" stroke="{ink}" stroke-width="3" stroke-linecap="round">'
             '<path d="M404 146 L452 170 L502 200 L556 236"/><path d="M452 170 L462 246"/><path d="M502 200 L566 158"/></g>'
             f'<g fill="{paper}" stroke="{ink}" stroke-width="2.5"><circle cx="404" cy="146" r="7"/>'
             '<circle cx="452" cy="170" r="7"/><circle cx="556" cy="236" r="7"/><circle cx="462" cy="246" r="7"/>'
             '<circle cx="566" cy="158" r="7"/></g>'
             f'<circle cx="502" cy="200" r="8" fill="{red}" stroke="{ink}" stroke-width="2.5"/>'
             f'<circle cx="508" cy="206" r="36" fill="#FFFFFF" fill-opacity="0.35" stroke="{ink}" stroke-width="5"/>'
             f'<path d="M534 232 L572 270" stroke="{ink}" stroke-width="13" stroke-linecap="round"/>'
             f'<path d="M536 234 L570 268" stroke="{tan}" stroke-width="6" stroke-linecap="round"/>'
             f'<circle cx="588" cy="128" r="15" fill="{red}" stroke="{ink}" stroke-width="3"/>'
             f'<path d="M588 119 V130" stroke="{paper}" stroke-width="3.5" stroke-linecap="round"/>'
             f'<circle cx="588" cy="137" r="2.2" fill="{paper}"/>')

    # Prepare: cluttered network transformed into a clean one, plus checklist
    p.append(card(670, 250, c))
    tick = f'fill="none" stroke="{green}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"'
    p.append(f'<g fill="none" stroke="{ink}" stroke-width="2.5" stroke-linecap="round">'
             '<path d="M694 138 L712 152 L728 150 L742 168 L760 172 L752 196 L770 214"/>'
             '<path d="M742 168 L724 192 L710 208"/></g>'
             f'<g fill="{paper}" stroke="{ink}" stroke-width="2">'
             + "".join(f'<circle cx="{x}" cy="{y}" r="5"/>' for x, y in
                       [(694, 138), (712, 152), (728, 150), (742, 168), (760, 172), (752, 196),
                        (770, 214), (724, 192), (710, 208)]) + '</g>'
             f'<path d="M786 176 H812 M802 166 L814 176 L802 186" fill="none" stroke="{ink}" stroke-width="3.5" '
             'stroke-linecap="round" stroke-linejoin="round"/>'
             f'<g fill="none" stroke="{ink}" stroke-width="3" stroke-linecap="round">'
             '<path d="M832 140 L862 170 L892 206"/><path d="M862 170 L840 206"/></g>'
             f'<g fill="{paper}" stroke="{ink}" stroke-width="2.5"><circle cx="832" cy="140" r="7"/>'
             '<circle cx="862" cy="170" r="7"/><circle cx="892" cy="206" r="7"/><circle cx="840" cy="206" r="7"/></g>'
             f'<rect x="694" y="250" width="18" height="18" rx="4" fill="{paper}" stroke="{ink}" stroke-width="2.5"/>'
             f'<path d="M698 259 L702 264 L709 254" {tick}/>'
             f'<path d="M724 259 H860" stroke="{rule}" stroke-width="5" stroke-linecap="round"/>'
             f'<rect x="694" y="280" width="18" height="18" rx="4" fill="{paper}" stroke="{ink}" stroke-width="2.5"/>'
             f'<path d="M698 289 L702 294 L709 284" {tick}/>'
             f'<path d="M724 289 H836" stroke="{rule}" stroke-width="5" stroke-linecap="round"/>')

    # Optimize: the mark itself, large
    p.append(card(970, 250, c))
    p.append(f'<g transform="translate(993 108) scale(1.7)">{mark(c)}</g>')

    # Verify: phase voltages within limits, neutral near zero
    p.append(card(1270, 260, c))
    p.append(f'<path d="M1296 128 V290 H1508" fill="none" stroke="{ink}" stroke-width="3" '
             'stroke-linecap="round" stroke-linejoin="round"/>'
             f'<g stroke="{tan}" stroke-width="2.5" stroke-dasharray="7 6"><path d="M1300 146 H1504"/>'
             '<path d="M1300 236 H1504"/></g>'
             '<g fill="none" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">'
             f'<path d="M1302 158 L1352 168 L1402 180 L1452 192 L1500 202" stroke="{red}"/>'
             f'<path d="M1302 164 L1352 178 L1402 196 L1452 210 L1500 222" stroke="{green}"/>'
             f'<path d="M1302 160 L1352 172 L1402 186 L1452 200 L1500 214" stroke="{purple}"/>'
             f'<path d="M1302 282 L1352 278 L1402 272 L1452 268 L1500 264" stroke="{blue}"/></g>'
             f'<circle cx="1500" cy="126" r="17" fill="{green}" stroke="{ink}" stroke-width="3"/>'
             f'<path d="M1491 126 L1498 133 L1510 120" fill="none" stroke="{paper}" stroke-width="3.5" '
             'stroke-linecap="round" stroke-linejoin="round"/>')

    # Flow chevrons between stages
    for x in (335, 645, 945, 1245):
        p.append(f'<circle cx="{x}" cy="225" r="15" fill="{c["cream"]}" stroke="{ink}" stroke-width="3"/>'
                 f'<path d="M{x - 4} 218 L{x + 3} 225 L{x - 4} 232" fill="none" stroke="{ink}" '
                 'stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>')

    stages = [(190, "Import", "OpenDSS · BMOPF cases"),
              (495, "Inspect", "diagnostics & findings"),
              (795, "Prepare", "transformations & augmentations"),
              (1095, "Optimize", "multiconductor PF & OPF"),
              (1400, "Verify", "checked solutions")]
    for x, title, caption in stages:
        p.append(text(title, "semibold", 26, x, 362, ink, anchor="middle"))
        p.append(text(caption, "regular", 17, x, 390, c["sub"], anchor="middle"))
    return "".join(p)


def hero() -> str:
    c = LIGHT
    m, gap, size = 140, 18, 104
    _, w_wm = wordmark(size, 0, 0, c)
    x0 = (1600 - (m + gap + w_wm)) / 2
    wm, _ = wordmark(size, x0 + m + gap, 180, c)
    body = (f'<rect width="1600" height="720" rx="28" fill="{c["ground"]}"/>'
            + place(mark(c), x0, 72, m) + wm
            + text(TAGLINE, "medium", 30, 800, 264, c["sub"], anchor="middle")
            + f'<g transform="translate(0 256)">{hero_band(c)}</g>')
    return svg_doc(1600, 720, body, "BMOPFTools.jl: " + TAGLINE)


def social() -> str:
    c = LIGHT
    m = 260
    tx = 88 + m + 36
    dy = 34  # vertically center the block in the space above the wire band
    wm, _ = wordmark(88, tx, 214 + dy, c)
    body = [f'<rect width="1280" height="640" fill="{c["ground"]}"/>',
            place(mark(c), 88, 148 + dy - 8, m), wm,
            text("Inspect, prepare, and optimize", "medium", 30, tx, 268 + dy, c["sub"]),
            text("unbalanced distribution networks", "medium", 30, tx, 307 + dy, c["sub"])]
    x = tx
    for label in ["four-wire PF & OPF", "OpenDSS import", "diagnostics", "Julia"]:
        w = FONTS["medium"].width(label, 18) + 32
        body.append(f'<rect x="{x:g}" y="{336 + dy}" width="{w:g}" height="38" rx="19" fill="{c["cream"]}" '
                    f'stroke="{c["ink"]}" stroke-width="2"/>')
        body.append(text(label, "medium", 18, x + 16, 361 + dy, c["ink"]))
        x += w + 10
    body.append(wire_band(c, 570, -10, 1290))
    return svg_doc(1280, 640, "".join(body), "BMOPFTools.jl: " + TAGLINE)


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

def rsvg(src: Path, dst: Path, fmt: str, width: int | None = None) -> None:
    cmd = ["rsvg-convert", "-f", fmt, "-o", str(dst)]
    if width:
        cmd += ["-w", str(width), "--keep-aspect-ratio"]
    subprocess.run(cmd + [str(src)], check=True)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--fonts", type=Path, required=True, help="directory with the TTF files")
    args = ap.parse_args()
    if shutil.which("rsvg-convert") is None:
        raise SystemExit("rsvg-convert (librsvg) is required")
    for key, name in [("regular", "Poppins-Regular"), ("medium", "Poppins-Medium"),
                      ("semibold", "Poppins-SemiBold"), ("bold", "Poppins-Bold"),
                      ("mono", "IBMPlexMono-Medium")]:
        FONTS[key] = Font(args.fonts / f"{name}.ttf")

    OUT.mkdir(parents=True, exist_ok=True)
    name = "BMOPFTools.jl logo"
    # (file stem, svg text, PNG width in px)
    variants = [
        ("bmopftools-mark", svg_doc(120, 120, mark(LIGHT), name), 512),
        ("bmopftools-mark-dark", svg_doc(120, 120, mark(DARK), name), 512),
        ("bmopftools-mark-mono", svg_doc(120, 120, mark(LIGHT, mono=True), name), 512),
        ("bmopftools-mark-mono-reversed", svg_doc(120, 120, mark(DARK, mono=True), name), 512),
        ("bmopftools-mark-small", svg_doc(120, 120, mark(LIGHT, small=True), name), 64),
        ("bmopftools-mark-small-dark", svg_doc(120, 120, mark(DARK, small=True), name), 64),
        ("bmopftools-icon", svg_doc(120, 120, tile(LIGHT), name), 512),
        ("bmopftools-icon-dark", svg_doc(120, 120, tile(DARK), name), 512),
        ("bmopftools-icon-small", svg_doc(120, 120, tile(LIGHT, small=True), name), 64),
        ("bmopftools-lockup", lockup(LIGHT), None),
        ("bmopftools-lockup-dark", lockup(DARK), None),
        ("bmopftools-lockup-stacked", lockup_stacked(LIGHT), None),
        ("bmopftools-lockup-stacked-dark", lockup_stacked(DARK), None),
        ("bmopftools-hero", hero(), 1600),
        ("bmopftools-social", social(), 1280),
    ]
    for stem, svg, width in variants:
        src = OUT / f"{stem}.svg"
        src.write_text(svg, encoding="utf-8")
        rsvg(src, OUT / f"{stem}.png", "png", width)  # width None: natural size
        if width is None:  # lockups also get a 2x raster for high-DPI use
            natural = int(float(svg.split('width="')[1].split('"')[0]))
            rsvg(src, OUT / f"{stem}@2x.png", "png", 2 * natural)
        rsvg(src, OUT / f"{stem}.pdf", "pdf")
    rsvg(OUT / "bmopftools-hero.svg", OUT / "bmopftools-hero@2x.png", "png", 3200)

    # Documenter picks up assets/logo.svg and assets/logo-dark.svg automatically.
    shutil.copyfile(OUT / "bmopftools-mark.svg", DOC_ASSETS / "logo.svg")
    shutil.copyfile(OUT / "bmopftools-mark-dark.svg", DOC_ASSETS / "logo-dark.svg")

    # Favicon: the simplified tile, rendered natively at each size.
    small = OUT / "bmopftools-icon-small.svg"
    frames = []
    for px in (16, 32, 48):
        png = subprocess.run(["rsvg-convert", "-f", "png", "-w", str(px), "-h", str(px), str(small)],
                             check=True, capture_output=True).stdout
        frames.append(Image.open(io.BytesIO(png)).convert("RGBA"))
    frames[-1].save(DOC_ASSETS / "favicon.ico", format="ICO",
                    sizes=[(16, 16), (32, 32), (48, 48)], append_images=frames[:-1])
    print(f"wrote {len(variants)} variants to {OUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
