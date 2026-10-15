"""Concept sheets of the character models to be regenerated (#225, stage 1). Own drawings, no third-party assets.

Usage: python3 docs/art/previews/characters/make_sheets.py docs/art/previews/characters
"""
from __future__ import annotations

import html
import sys
import textwrap
from pathlib import Path

FONT = "'PT Sans', Arial, sans-serif"
W, H = 1400, 900

BG = "#141016"
PANEL = "#221c22"
PANEL_L = "#2c252c"
GRID = "#3a3238"
TEXT = "#efe7dc"
MUTED = "#b0a59c"
ACCENT = "#ffb35a"
HERO = "#d9d2c8"
GROUND = "#5a4e48"
WHITE = "#eef6ff"

# Н-01 remains
CLOAK = "#3d3431"
CLOAK_L = "#564943"
CLOAK_D = "#2a2321"
BONE = "#cfc4b4"
BONE_D = "#9c9184"
CAP = "#a8382c"
CAP_D = "#7a271f"
BADGE = "#e8e2d6"
WOOD = "#6b4a2e"
WOOD_D = "#4a321f"
IRON = "#2b2729"
IRON_L = "#4a4447"
STONE = "#3b3236"
STONE_L = "#4d4247"

# С-01 dream guard (canon colours, dimmed by the dream light)
SMOKE = "#3a2a35"
EYE = "#ff7a2a"
K_SKIN = "#b89a45"
K_SKIN_D = "#8a7232"
K_SHELL = "#3f6b3a"
K_SHELL_D = "#2c4a29"
K_SHELL_B = "#6d6a66"   # the bone guard's grey cracked shell
K_RIM = "#cfc29a"
K_BELLY = "#d2c38e"
K_BELLY_D = "#a8996a"
K_MUZZLE = "#d9c48a"
K_SCLERA = "#e6dcc0"    # cream, not white: white belongs to the system (Б-5)
K_IRON = "#45444c"
K_IRON_L = "#6a6873"
K_SPIKE = "#cfc8b8"
K_BOOT = "#5a3a2a"

# Ст-01 senior officer
SR_JACKET = "#2f3a4a"
SR_JACKET_D = "#253040"
SR_COLLAR = "#4f5862"
SR_PANTS = "#3b424a"
SR_SKIN = "#c8aa98"
SR_SKIN_D = "#8e6f60"
SR_HAIR = "#8d8a86"
SR_CORD = "#a8382c"
SR_PIPE = "#6b5a4a"
SR_PIPE_D = "#4a3e33"
SR_CONSOLE = "#2b3036"
SR_CONSOLE_L = "#3e4650"

# P-106s Herobrine
HB_SKIN = "#b88d6c"
HB_SKIN_D = "#9a7356"
HB_HAIR = "#3b2a1f"
HB_SHIRT = "#1fa3a3"
HB_SHIRT_D = "#168080"
HB_PANTS = "#3c3f9e"
HB_PANTS_D = "#2d2f7a"
HB_SHOE = "#6b6b6b"
CAPS_BLUE = "#8cc8ff"
FLUID_BLUE = "#173248"

# staff sleeper
COVER = "#4f5862"
COVER_D = "#3b424a"
COVER_L = "#66707b"
SKIN_S = "#c19a80"
HAIR_S = "#4a3a30"
STRIPE = "#d8c46a"
FROST = "#bcd3df"


def esc(s: str) -> str:
    return html.escape(s, quote=False)


def head(title: str, sub: str, w: int = W, h: int = H) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" font-family="{FONT}">
<defs>
<filter id="glow" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7"/></filter>
<radialGradient id="eyeg"><stop offset="0" stop-color="{EYE}" stop-opacity="0.8"/><stop offset="1" stop-color="{EYE}" stop-opacity="0"/></radialGradient>
<radialGradient id="whiteg"><stop offset="0" stop-color="{WHITE}" stop-opacity="0.8"/><stop offset="1" stop-color="{WHITE}" stop-opacity="0"/></radialGradient>
<linearGradient id="fluid" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#24506e"/><stop offset="1" stop-color="{FLUID_BLUE}"/></linearGradient>
<linearGradient id="frost" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{FROST}" stop-opacity="0.55"/><stop offset="1" stop-color="{FROST}" stop-opacity="0.25"/></linearGradient>
</defs>
<rect width="{w}" height="{h}" rx="14" fill="{BG}"/>
<text x="32" y="44" font-size="24" font-weight="700" fill="{TEXT}">{esc(title)}</text>
<text x="32" y="70" font-size="14" fill="{MUTED}">{esc(sub)}</text>
'''


def txt(x: float, y: float, s: str, size: int = 13, fill: str = TEXT, anchor: str = "start", weight: str = "400") -> str:
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" '
            f'font-weight="{weight}">{esc(s)}</text>\n')


def panel(x: float, y: float, w: float, h: float, label: str = "") -> str:
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{PANEL}" stroke="{GRID}"/>\n'
    if label:
        s += txt(x + 14, y + 22, label, 13, ACCENT, weight="700")
    return s


class V:
    """A view: metres → px. x is the view's centre line, g the ground line, k px per metre."""

    def __init__(self, x: float, g: float, k: float):
        self.x, self.g, self.k = x, g, k

    def X(self, mx: float) -> float:
        return self.x + mx * self.k

    def Y(self, my: float) -> float:
        return self.g - my * self.k

    def p(self, mx: float, my: float) -> str:
        return f"{self.X(mx):.1f},{self.Y(my):.1f}"

    def poly(self, pts, fill: str, extra: str = "") -> str:
        return f'<polygon points="{" ".join(self.p(*q) for q in pts)}" fill="{fill}" {extra}/>\n'

    def ell(self, cx: float, cy: float, rx: float, ry: float, fill: str, extra: str = "") -> str:
        return (f'<ellipse cx="{self.X(cx):.1f}" cy="{self.Y(cy):.1f}" rx="{rx * self.k:.1f}" ry="{ry * self.k:.1f}" '
                f'fill="{fill}" {extra}/>\n')

    def rect(self, x0: float, y0: float, x1: float, y1: float, fill: str, extra: str = "") -> str:
        return (f'<rect x="{self.X(min(x0, x1)):.1f}" y="{self.Y(max(y0, y1)):.1f}" width="{abs(x1 - x0) * self.k:.1f}" '
                f'height="{abs(y1 - y0) * self.k:.1f}" fill="{fill}" {extra}/>\n')

    def line(self, pts, stroke: str, wm: float, extra: str = "") -> str:
        return (f'<polyline points="{" ".join(self.p(*q) for q in pts)}" fill="none" stroke="{stroke}" '
                f'stroke-width="{max(wm * self.k, 1):.1f}" stroke-linecap="round" stroke-linejoin="round" {extra}/>\n')

    def curve(self, d: list, stroke: str, wm: float, fill: str = "none", extra: str = "") -> str:
        """d: a list of SVG path commands with metre pairs, e.g. ["M", (0, 1), "Q", (1, 2), (2, 1)]."""
        out = []
        for c in d:
            out.append(self.p(*c) if isinstance(c, tuple) else c)
        return (f'<path d="{" ".join(out)}" fill="{fill}" stroke="{stroke}" stroke-width="{max(wm * self.k, 1):.1f}" '
                f'stroke-linecap="round" stroke-linejoin="round" {extra}/>\n')

    def rot(self, deg: float, mx: float, my: float, inner: str) -> str:
        return f'<g transform="rotate({deg:.1f} {self.X(mx):.1f} {self.Y(my):.1f})">\n{inner}</g>\n'


def ground(v: V, x0: float, x1: float) -> str:
    return f'<line x1="{v.X(x0):.1f}" y1="{v.g:.1f}" x2="{v.X(x1):.1f}" y2="{v.g:.1f}" stroke="{GROUND}" stroke-width="1.5"/>\n'


def hero(v: V, mx: float) -> str:
    """The player, 1.8 m, standing on the view's ground at mx."""
    def p(a, b):
        return v.p(mx + a, b)
    body = (f'<path d="M{p(-0.2, 1.45)} L{p(0.2, 1.45)} L{p(0.17, 0.85)} L{p(0.12, 0)} L{p(0.03, 0)} L{p(0, 0.8)} '
            f'L{p(-0.03, 0)} L{p(-0.12, 0)} L{p(-0.17, 0.85)} Z" fill="{HERO}" opacity="0.85"/>')
    return (body + f'<circle cx="{v.X(mx):.1f}" cy="{v.Y(1.63):.1f}" r="{0.13 * v.k:.1f}" fill="{HERO}" opacity="0.85"/>\n'
            + txt(v.X(mx), v.g + 16, "игрок 1,8 м", 11, MUTED, "middle"))


def dim(v: V, mx: float, y0: float, y1: float, label: str, side: int = 1) -> str:
    x = v.X(mx)
    a, b = v.Y(y0), v.Y(y1)
    s = f'<line x1="{x:.1f}" y1="{a:.1f}" x2="{x:.1f}" y2="{b:.1f}" stroke="{MUTED}" stroke-width="1"/>\n'
    for yy in (a, b):
        s += f'<line x1="{x - 5:.1f}" y1="{yy:.1f}" x2="{x + 5:.1f}" y2="{yy:.1f}" stroke="{MUTED}" stroke-width="1"/>\n'
    s += txt(x + side * 8, (a + b) / 2 + 4, label, 12, MUTED, "start" if side > 0 else "end")
    return s


def info(x: float, y: float, sections: list, chars: int = 62) -> str:
    """Right-hand text column: (heading, list of lines) or (heading, [("#hex", "name"), ...]) for a palette."""
    s = []
    for title, body in sections:
        s.append(txt(x, y, title, 14, ACCENT, weight="700"))
        y += 20
        if body and isinstance(body[0], tuple):
            for i, (hexc, name) in enumerate(body):
                cx = x + (i % 2) * 240
                if i % 2 == 0 and i:
                    y += 28
                s.append(f'<rect x="{cx}" y="{y - 14}" width="22" height="22" rx="4" fill="{hexc}" stroke="{GRID}"/>')
                s.append(txt(cx + 30, y + 1, f"{name}", 12, TEXT))
                s.append(txt(cx + 30, y + 13, hexc, 10, MUTED))
            y += 34
        else:
            for line in body:
                for j, part in enumerate(textwrap.wrap(line, chars)):
                    s.append(txt(x + (10 if j else 0), y, ("• " if not j else "") + part, 13, TEXT if not j else TEXT))
                    y += 17
            y += 8
    return "\n".join(s) + "\n"


# ============================================================================= С-01 dream guard: three variants
def koopa_front(v: V, kind: str = "armored", glow: bool = True) -> str:
    """Front view of an upright turtle guard. kind: armored (а) · bones (б) · hammer (в). Feet on y = 0."""
    bones = kind == "bones"
    skin = BONE if bones else K_SKIN
    skin_d = BONE_D if bones else K_SKIN_D
    shell = K_SHELL_B if bones else K_SHELL
    rim = BONE_D if bones else K_RIM
    tall = 1.06 if kind == "hammer" else 1.0          # the hammer guard is taller and has a larger shell
    s = []
    if glow:
        s.append(v.ell(0, 0.06, 0.62, 0.1, SMOKE, 'filter="url(#soft)" opacity="0.8"'))
    for sx in (-1, 1):                                                                       # legs and boots
        if bones:
            s.append(v.line([(sx * 0.2, 0.12), (sx * 0.2, 0.62)], skin, 0.07))
            s.append(v.ell(sx * 0.2, 0.42, 0.06, 0.05, skin))
        else:
            s.append(v.poly([(sx * 0.08, 0.64), (sx * 0.34, 0.64), (sx * 0.32, 0.12), (sx * 0.1, 0.12)], skin))
        s.append(v.ell(sx * 0.24, 0.08, 0.2, 0.09, K_BOOT))
        s.append(v.rect(sx * 0.06, 0.0, sx * 0.42, 0.04, K_BOOT))
    s.append(v.ell(0, 1.22 * tall, 0.66 * tall, 0.66 * tall, rim))                         # shell rim behind
    s.append(v.ell(0, 1.24 * tall, 0.6 * tall, 0.6 * tall, shell))
    if kind == "armored":                                                                    # spikes on the shell edge
        for y0 in (1.62, 1.22, 0.84):
            for sx in (-1, 1):
                s.append(v.poly([(sx * 0.6, y0 + 0.07), (sx * 0.6, y0 - 0.07), (sx * 0.84, y0)], K_SPIKE))
    if bones:                                                                                # cracks in the grey shell
        s.append(v.line([(-0.5, 1.5), (-0.36, 1.36), (-0.44, 1.18)], K_SHELL_D, 0.014))
        s.append(v.line([(0.46, 0.9), (0.34, 1.02), (0.4, 1.16)], K_SHELL_D, 0.014))
        s.append(v.line([(0, 0.62), (0, 1.68)], skin, 0.07))                                  # spine
        for i, y in enumerate((1.5, 1.38, 1.26, 1.14)):                                       # ribs
            w = 0.3 - i * 0.03
            s.append(v.curve(["M", (-w, y - 0.06), "Q", (0, y + 0.06), (w, y - 0.06)], skin, 0.035))
        s.append(v.ell(0, 0.68, 0.24, 0.08, skin))                                            # pelvis
    else:
        s.append(v.ell(0, 1.12 * tall, 0.36, 0.5 * tall, K_BELLY))                           # belly plate
        for y in (0.82, 1.02, 1.22, 1.42):
            s.append(v.line([(-0.3, y * tall), (0.3, y * tall)], K_BELLY_D, 0.012))
    for sx in (-1, 1):                                                                       # arms
        if bones:
            s.append(v.line([(sx * 0.42, 1.62), (sx * 0.62, 1.3), (sx * 0.66, 1.0)], skin, 0.055))
        else:
            s.append(v.poly([(sx * 0.44, 1.7 * tall), (sx * 0.64, 1.66 * tall), (sx * 0.7, 1.02), (sx * 0.54, 1.0)], skin))
        s.append(v.ell(sx * 0.63, 0.94, 0.1, 0.09, skin))
        for c in (-0.05, 0.0, 0.05):
            s.append(v.poly([(sx * 0.63 + c - 0.02, 0.88), (sx * 0.63 + c + 0.02, 0.88), (sx * 0.63 + c, 0.8)], skin_d))
        if kind == "armored":                                                                # spiked cuffs and pauldrons
            s.append(v.rect(sx * 0.53, 1.08, sx * 0.73, 1.2, K_IRON))
            s.append(v.poly([(sx * 0.73, 1.19), (sx * 0.73, 1.09), (sx * 0.84, 1.14)], K_SPIKE))
            s.append(v.ell(sx * 0.52, 1.72, 0.2, 0.13, K_IRON))
            s.append(v.poly([(sx * 0.46, 1.82), (sx * 0.6, 1.82), (sx * 0.55, 2.0)], K_SPIKE))
    if kind == "armored":                                                                    # spiked collar
        s.append(v.rect(-0.26, 1.7, 0.26, 1.8, K_IRON))
        for c in (-0.18, 0.0, 0.18):
            s.append(v.poly([(c - 0.04, 1.8), (c + 0.04, 1.8), (c, 1.88)], K_SPIKE))
    hy = 2.0 * tall if not bones else 1.94                                                  # head
    s.append(v.rect(-0.1, hy - 0.26, 0.1, hy - 0.12, skin))
    s.append(v.ell(0, hy, 0.25, 0.26, skin))
    s.append(v.ell(0, hy - 0.12, 0.17, 0.11, K_MUZZLE if not bones else BONE_D))           # muzzle / beak
    s.append(v.line([(-0.1, hy - 0.16), (0, hy - 0.19), (0.1, hy - 0.16)], skin_d, 0.012))
    for sx in (-1, 1):                                                                       # eyes
        if bones:
            s.append(v.ell(sx * 0.09, hy + 0.06, 0.07, 0.08, "#0b0809"))
        else:
            s.append(v.ell(sx * 0.08, hy + 0.06, 0.065, 0.1, K_SCLERA))
        if glow:
            s.append(v.ell(sx * 0.08, hy + 0.05, 0.08, 0.08, "url(#eyeg)"))
        s.append(v.ell(sx * 0.07, hy + 0.04, 0.025, 0.04, EYE, 'filter="url(#glow)"' if glow else ""))
    if kind == "armored":                                                                    # spiked helmet
        s.append(v.curve(["M", (-0.29, hy + 0.1), "Q", (-0.3, hy + 0.36), (0, hy + 0.36), "Q", (0.3, hy + 0.36),
                          (0.29, hy + 0.1), "Z"], K_IRON_L, 0.006, K_IRON))
        s.append(v.rect(-0.31, hy + 0.08, 0.31, hy + 0.13, K_IRON_L))
        s.append(v.poly([(-0.06, hy + 0.34), (0.06, hy + 0.34), (0, hy + 0.5)], K_SPIKE))
        for sx in (-1, 1):
            s.append(v.poly([(sx * 0.17, hy + 0.3), (sx * 0.25, hy + 0.26), (sx * 0.27, hy + 0.4)], K_SPIKE))
    elif kind == "hammer":                                                                   # round helmet, shell colour
        s.append(v.curve(["M", (-0.27, hy + 0.12), "Q", (-0.27, hy + 0.34), (0, hy + 0.34), "Q", (0.27, hy + 0.34),
                          (0.27, hy + 0.12), "Z"], K_RIM, 0.008, K_SHELL))
        s.append(v.line([(0.64, 0.98), (0.7, 1.4), (0.78, 1.9)], WOOD, 0.04))              # hammer raised
        s.append(v.rot(-8, 0.79, 1.98, v.rect(0.66, 1.9, 0.92, 2.08, K_IRON)))
        s.append(v.line([(0.74, 1.88), (0.82, 1.92)], WOOD_D, 0.02))
        s.append(v.line([(-0.36, 0.72), (-0.36, 0.42)], WOOD, 0.035))                      # spare hammer at the belt
        s.append(v.rect(-0.44, 0.7, -0.28, 0.8, K_IRON))
    return "".join(s)


def koopa_side(v: V) -> str:
    """Variant а, side view, face to +x."""
    s = []
    s.append(v.ell(0, 0.06, 0.55, 0.1, SMOKE, 'filter="url(#soft)" opacity="0.8"'))
    s.append(v.poly([(-0.08, 0.64), (0.2, 0.64), (0.18, 0.12), (-0.04, 0.12)], K_SKIN))
    s.append(v.ell(0.12, 0.08, 0.24, 0.09, K_BOOT) + v.rect(-0.12, 0.0, 0.36, 0.04, K_BOOT))
    s.append(v.ell(-0.18, 1.24, 0.42, 0.62, K_RIM))
    s.append(v.ell(-0.2, 1.24, 0.37, 0.57, K_SHELL))
    for y0 in (1.7, 1.38, 1.04, 0.74):                                                       # back spikes
        s.append(v.poly([(-0.54, y0 + 0.08), (-0.54, y0 - 0.08), (-0.8, y0 - 0.02)], K_SPIKE))
    s.append(v.curve(["M", (-0.5, 1.0), "Q", (-0.3, 1.24), (-0.48, 1.5)], K_SHELL_D, 0.012))
    s.append(v.ell(0.12, 1.12, 0.2, 0.48, K_BELLY))
    s.append(v.ell(0.0, 1.7, 0.16, 0.12, K_IRON))                                            # pauldron
    s.append(v.poly([(-0.04, 1.8), (0.08, 1.8), (0.02, 1.98)], K_SPIKE))
    s.append(v.poly([(0.02, 1.66), (0.18, 1.62), (0.26, 1.02), (0.1, 1.0)], K_SKIN))
    s.append(v.rect(0.08, 1.08, 0.3, 1.2, K_IRON))
    s.append(v.ell(0.2, 0.94, 0.09, 0.09, K_SKIN))
    s.append(v.rect(0.02, 1.74, 0.2, 1.88, K_SKIN))                                          # neck
    s.append(v.ell(0.14, 2.0, 0.22, 0.24, K_SKIN))
    s.append(v.ell(0.34, 1.9, 0.15, 0.1, K_MUZZLE))                                          # snout forward
    s.append(v.ell(0.24, 2.06, 0.05, 0.09, K_SCLERA))
    s.append(v.ell(0.26, 2.05, 0.022, 0.04, EYE, 'filter="url(#glow)"'))
    s.append(v.curve(["M", (-0.12, 2.1), "Q", (-0.1, 2.36), (0.14, 2.36), "Q", (0.36, 2.34), (0.36, 2.12), "Z"],
                     K_IRON_L, 0.006, K_IRON))
    s.append(v.poly([(0.06, 2.34), (0.18, 2.34), (0.12, 2.5)], K_SPIKE))
    return "".join(s)


GUARD_VARIANTS = [
    ("armored", "а. Купа-латник · 2,3 м", "по мотивам Koopatrol",
     "Элитная охрана замка: шлем с шипом, шипастый панцирь, наплечники и браслеты. Ближе всего к роли «страж»."),
    ("bones", "б. Костяной купа · 2,2 м", "по мотивам Dry Bones",
     "Скелет черепахи с треснувшим панцирем. Сам «собирается» и «рассыпается» — как наш телеграф 1,5 с."),
    ("hammer", "в. Молот-страж · 2,4 м", "по мотивам Hammer Bro",
     "Выше, панцирь больше, круглый шлем, тяжёлый молот в руке и запасной на поясе. Удар молотом."),
]


def sheet_guard() -> str:
    s = [head("С-01 · Страж сна Боузера — 3 варианта ближе к образам вселенной",
              "Двор S3, засада bowser_first_fight: 2 стража выходят из ниш. Прошлый «страж-тень» отклонён. "
              "Свои рисунки по описаниям, без чужих картинок")]
    s.append(panel(24, 92, 1352, 500, "Спереди · вариант «а» сбоку · игрок 1,8 м (для генерации — A-поза, В-2 «а»)"))
    k = 165
    xs = (200, 470, 740)
    for x, (kind, title, ref, _) in zip(xs, GUARD_VARIANTS):
        v = V(x, 540, k)
        s.append(koopa_front(v, kind))
        s.append(ground(v, -1.0, 1.0))
        s.append(txt(x, 566, title, 14, ACCENT if kind == "armored" else TEXT, "middle", "700"))
        s.append(txt(x, 583, ref, 12, MUTED, "middle"))
    v4 = V(1000, 540, k)
    s.append(koopa_side(v4))
    s.append(ground(v4, -0.9, 0.7))
    s.append(dim(v4, 0.62, 0, 2.5, "2,3 м + шип", 1))
    s.append(txt(1000, 566, "а. сбоку, лицом вправо", 12, MUTED, "middle"))
    s.append(hero(V(1260, 540, k), 0.0))
    # variants, palette, notes
    y = 618
    for i, (kind, title, ref, line) in enumerate(GUARD_VARIANTS):
        x = 32 + i * 330
        s.append(f'<rect x="{x - 8}" y="{y - 20}" width="318" height="140" rx="8" fill="{PANEL}" '
                 f'stroke="{ACCENT if kind == "armored" else GRID}"/>')
        s.append(txt(x + 4, y, title + (" — рекомендация" if kind == "armored" else ""), 13, ACCENT, weight="700"))
        yy = y + 20
        for part in textwrap.wrap(line, 44):
            s.append(txt(x + 4, yy, part, 12, TEXT))
            yy += 16
    pros = [
        ("а", "+ читается как «стража», ближний бой, шипы держат силуэт в темноте; − шипы осложняют авториг"),
        ("б", "+ сборка/распад «бесплатно», риф с останками Н-01; − тонкие кости хуже читаются на 12 м"),
        ("в", "+ самый узнаваемый; − молот просит бросок (новая механика), длинный замах"),
    ]
    yy = y + 92
    for i, (_, line) in enumerate(pros):
        x = 32 + i * 330
        for j, part in enumerate(textwrap.wrap(line, 50)[:3]):
            s.append(txt(x + 4, yy - 14 + j * 15, part, 11, MUTED))
    s.append(info(1016, 618, [
        ("Палитра (вариант «а»)", [(K_SHELL, "панцирь"), (K_SKIN, "кожа"), (K_BELLY, "брюшной щит"), (K_IRON, "латы"),
                                   (K_SPIKE, "шипы"), (EYE, "зрачки, эмиссия")]),
    ], 40))
    s.append(txt(32, 790, "Цвет (В-11): канонные цвета, приглушённые светом сна; дым dream_shadow — только на «сборке» и гибели. "
                          "Белого на стражах нет (Б-5): белки глаз кремовые.", 12, TEXT))
    s.append(txt(32, 810, "Референсы (описания, ссылки — без копий в репо): mariowiki.com/Koopatrol · mariowiki.com/Dry_Bones · "
                          "mariowiki.com/Hammer_Bro · mariowiki.com/Magikoopa (маг — на будущие сны, не страж).", 12, MUTED))
    s.append(txt(32, 830, "Риск О-10: узнаваемость по Б-2 — силуэт и роль, а не копия. Свои пропорции (рост 2,2–2,4 м, "
                          "«взрослое» тело), без надписей и логотипов; в промптах этапа 2 — описание, не имя персонажа.", 12, MUTED))
    s.append(txt(32, 850, "Для генерации (этап 2): риг по A-позе, 3–5 клипов (стойка, шаг, замах 0,45 с, удар, гибель). "
                          "До 15 тыс. треугольников, 1K. Статуи Д-02 — тот же меш в камне (В-6).", 12, MUTED))
    s.append("</svg>\n")
    return "".join(s)


# ============================================================================= Н-01 remains of the world's hero, lying
def remains_lying_side(v: V) -> str:
    """Side view: lying on the back under the cloak, head to −x (the niche wall), feet to +x; y = 0 the floor."""
    s = []
    s.append(v.rect(-1.15, 0, -1.0, 0.6, STONE))                                                 # niche back wall
    s.append(v.ell(-0.95, 0.07, 0.17, 0.07, CAP))                                                # the cap by the head
    s.append(v.rect(-1.1, 0.0, -0.8, 0.025, CAP_D))
    s.append(v.ell(-0.95, 0.08, 0.045, 0.035, BADGE))
    s.append(v.curve(["M", (-0.86, 0.0), "Q", (-0.88, 0.2), (-0.7, 0.24), "Q", (-0.5, 0.3), (-0.3, 0.3), "Q", (-0.05, 0.3),
                      (0.1, 0.22), "Q", (0.3, 0.18), (0.45, 0.2), "Q", (0.58, 0.18), (0.62, 0.1), "L", (0.66, 0.0), "Z"],
                     CLOAK_D, 0.004, CLOAK))
    s.append(v.ell(-0.7, 0.13, 0.08, 0.07, "#0b0809"))                                           # hood opening, empty dark
    s.append(v.curve(["M", (-0.8, 0.2), "Q", (-0.72, 0.26), (-0.62, 0.22)], CLOAK_L, 0.012))
    for x0 in (-0.35, -0.05, 0.25):                                                               # folds
        s.append(v.line([(x0, 0.27), (x0 + 0.06, 0.02)], CLOAK_D, 0.01))
    s.append(v.poly([(0.5, 0.0), (0.58, 0.06), (0.68, 0.0)], CLOAK_D))                            # torn hem
    s.append(v.line([(0.58, 0.1), (0.86, 0.07)], BONE, 0.055))                                    # shins sticking out
    s.append(v.ell(0.88, 0.09, 0.04, 0.07, BONE_D))                                               # foot bones up
    s.append(v.line([(0.88, 0.14), (0.9, 0.2)], BONE, 0.018))
    s.append(v.line([(-0.26, 0.05), (-0.14, 0.02), (-0.02, 0.01)], BONE, 0.035))                  # hand out at the side
    for f in (-0.03, 0.0, 0.03):
        s.append(v.line([(-0.02, 0.01), (0.04, 0.0 + f * 0.2)], BONE, 0.01))
    return "".join(s)


def remains_lying_top(v: V) -> str:
    """Top view: head to −x, y across the niche (+y — towards the yard)."""
    s = []
    s.append(v.rect(-1.15, -0.55, -1.0, 0.75, STONE))
    s.append(v.curve(["M", (-0.86, 0.0), "Q", (-0.86, 0.2), (-0.66, 0.22), "Q", (-0.4, 0.34), (-0.1, 0.3), "Q", (0.3, 0.26),
                      (0.62, 0.18), "L", (0.66, -0.18), "Q", (0.3, -0.26), (-0.1, -0.3), "Q", (-0.4, -0.34), (-0.66, -0.22),
                      "Q", (-0.86, -0.2), (-0.86, 0.0), "Z"], CLOAK_D, 0.004, CLOAK))
    s.append(v.ell(-0.72, 0.0, 0.12, 0.13, CLOAK_L))                                              # hood
    s.append(v.ell(-0.7, 0.0, 0.07, 0.08, "#0b0809"))
    for y0 in (-0.15, 0.0, 0.15):
        s.append(v.line([(-0.5, y0 * 1.4), (0.55, y0)], CLOAK_D, 0.01))
    for sy in (-1, 1):                                                                            # shins and feet
        s.append(v.line([(0.6, sy * 0.1), (0.86, sy * 0.12)], BONE, 0.05))
        s.append(v.ell(0.9, sy * 0.13, 0.05, 0.04, BONE_D))
    s.append(v.line([(-0.24, 0.3), (-0.16, 0.44), (-0.02, 0.52)], BONE, 0.035))                   # right hand to the note
    for f in (-0.03, 0.0, 0.03):
        s.append(v.line([(-0.02, 0.52), (0.04, 0.54 + f)], BONE, 0.01))
    s.append(v.rect(0.06, 0.48, 0.3, 0.64, "#d8cfbf", 'opacity="0.9"'))                            # predecessor's note
    s.append(v.ell(-0.95, 0.4, 0.15, 0.12, CAP) + v.ell(-0.95, 0.4, 0.05, 0.05, BADGE))           # cap
    s.append(v.line([(0.2, -0.36), (0.6, -0.42)], WOOD, 0.035))                                  # mallet
    s.append(v.rect(0.6, -0.54, 0.74, -0.3, WOOD) + v.rect(0.64, -0.54, 0.68, -0.3, IRON_L))
    # chain with the shackle weight (separate pickup, Д-4а) — context only
    s.append(v.line([(-0.5, -0.4), (-0.2, -0.48), (0.1, -0.44), (0.3, -0.5)], IRON_L, 0.02, 'stroke-dasharray="4 3"'))
    s.append(v.rect(-0.66, -0.48, -0.5, -0.34, IRON))
    return "".join(s)


def sheet_remains() -> str:
    s = [head("Н-01 · Останки героя мира — лежат под плащом, ниша у цепи",
              "Двор S3, Yard/Remains: «ОСМОТРЕТЬ ОСТАНКИ», рядом цепь с грузом. Решение автора: не сидят, а лежат, "
              "накрыты плащом, из-под него торчат кости. Сейчас: dream_hero_remains.gltf (скрипт)")]
    s.append(panel(24, 92, 856, 780, "Сбоку · сверху · масштаб рядом с игроком"))
    v = V(450, 330, 300)
    s.append(remains_lying_side(v))
    s.append(ground(v, -1.15, 1.05))
    s.append(txt(450, 362, "сбоку: на спине, головой к стене ниши, плащ до макушки; торчат голени, стопы и кисть", 12, MUTED, "middle"))
    s.append(dim(v, 1.08, 0, 0.3, "0,3 м", 1))
    v2 = V(450, 560, 240)
    s.append(remains_lying_top(v2))
    s.append(txt(450, 716, "сверху: правая кисть тянется к записке, кепка у головы, молот и цепь сбоку", 12, MUTED, "middle"))
    v3 = V(150, 830, 55)
    s.append(remains_lying_side(v3))
    s.append(ground(v3, -1.2, 2.4))
    s.append(hero(v3, 1.9))
    s.append(txt(330, 800, "Масштаб: длина ≈ 1,75 м, высота холма плаща ≈ 0,3 м", 12, MUTED))
    s.append(info(900, 112, [
        ("Палитра", [(CLOAK, "истлевший плащ"), (CLOAK_L, "кромка, капюшон"), (BONE, "кости"), (CAP, "кепка, вытертая"),
                     (BADGE, "пустой круг-эмблема"), (WOOD, "молот, дерево")]),
        ("Материалы", ["Плащ — грубая шерсть, тяжёлые складки по форме тела, рваный подол, пыль и пепел.",
                       "Кости — матовые, тёплые, без глянца. Кепка — выцветшая красная ткань, эмблема — пустой круг (Д-7).",
                       "Молот — тёмное дерево, железный обод. Без надписей: тексты — в данных (#186)."]),
        ("Ключевые детали", ["Плащ накрывает всё тело с головой; капюшон пустой и тёмный (Д-3 «б», В-7).",
                             "Из-под подола торчат голени и стопы, сбоку — кисть, тянется к записке (В-1 «а»).",
                             "Кепка упала у головы — единственный узнаваемый мотив героя.",
                             "Цепь с кандальной гирей — отдельный подбор (DreamWeaponPickup), не в модели."]),
        ("Поза", ["Лежит на спине вдоль ниши, головой к стене; по складкам читаются плечи, таз, колени.",
                  "Статика, без рига, коллизия — низкий бокс. Сцена: точка осмотра опускается к полу."]),
        ("Масштаб", ["≈ 1,75 × 0,7 × 0,3 м без молота; плащ шире тела на 0,1 м с боков."]),
        ("Канон", ["#186: останки — герой этого мира, побеждённый хозяином (Б-1, Б-12). "
                   "Д-3, Д-4 в docs/art/dream-bowser-s.md; сцена — docs/game_design/06-bowser-dream-world.md §5."]),
        ("Для генерации (этап 2)", ["Статика: до 8 тыс. треугольников, 1K. Кепку, молот, записку — отдельными мешами."]),
    ]))
    s.append("</svg>\n")
    return "".join(s)


# ============================================================================= senior officer killed by the riser pipe
def console_side(v: V) -> str:
    """The operator console seen from the side, its front to +x; x 0…0.8."""
    s = []
    s.append(v.poly([(-0.1, 0.0), (0.6, 0.0), (0.6, 0.72), (0.8, 0.92), (-0.1, 1.08)], SR_CONSOLE))
    s.append(v.poly([(0.6, 0.72), (0.8, 0.92), (0.74, 0.96), (0.54, 0.76)], SR_CONSOLE_L))
    s.append(v.rect(0.05, 0.86, 0.3, 1.08, SR_CONSOLE_L))
    s.append(v.rect(0.12, 1.0, 0.2, 1.06, "#7fd0a0", 'opacity="0.6"'))                            # status lamp, mug next to it
    s.append(v.rect(-0.05, 1.08, 0.06, 1.18, "#6a5c54"))
    return "".join(s)


def senior_side(v: V) -> str:
    """The senior officer on his right side at the console foot, head to −x, knees a little bent, face to the viewer."""
    s = []
    s.append(v.ell(1.0, 0.11, 0.1, 0.11, SR_SKIN))                                                 # head on the floor
    s.append(v.curve(["M", (0.92, 0.18), "Q", (0.98, 0.25), (1.08, 0.2)], SR_HAIR, 0.05))
    s.append(v.line([(0.95, 0.09), (0.99, 0.08)], SR_SKIN_D, 0.008))                               # closed eye
    s.append(v.poly([(1.08, 0.04), (1.08, 0.28), (1.62, 0.26), (1.66, 0.04)], SR_JACKET))         # torso
    s.append(v.rect(1.08, 0.23, 1.2, 0.28, SR_COLLAR))
    s.append(v.rect(1.3, 0.1, 1.42, 0.14, STRIPE))                                                 # sleeve stripe
    s.append(v.line([(1.12, 0.16), (1.34, 0.08), (1.18, 0.02)], SR_JACKET_D, 0.07))                # arm towards the key
    s.append(v.ell(1.17, 0.02, 0.04, 0.03, SR_SKIN))
    s.append(v.line([(1.14, 0.24), (1.08, 0.12), (1.02, 0.03)], SR_CORD, 0.008))                   # lanyard cord
    s.append(v.rect(0.98, 0.0, 1.04, 0.03, "#c9a640"))                                             # the key
    s.append(v.poly([(1.62, 0.04), (1.66, 0.24), (1.96, 0.22), (2.1, 0.12), (2.1, 0.02)], SR_PANTS))  # hips, thighs
    s.append(v.poly([(2.06, 0.02), (2.1, 0.14), (2.5, 0.1), (2.56, 0.0)], SR_PANTS))              # shins
    s.append(v.rect(2.52, 0.0, 2.66, 0.12, "#2a2d31"))                                             # boots
    return "".join(s)


def riser_side(v: V) -> str:
    """The riser pipe that tore off: upper end on the console edge, across the chest, lower end on the floor."""
    s = []
    s.append(v.line([(0.78, 1.0), (1.36, 0.36), (1.94, 0.16)], SR_PIPE_D, 0.17))
    s.append(v.line([(0.78, 1.0), (1.36, 0.36), (1.94, 0.16)], SR_PIPE, 0.13))
    s.append(v.ell(0.78, 1.0, 0.09, 0.09, SR_PIPE_D) + v.ell(0.78, 1.0, 0.05, 0.05, "#1a1614"))    # open end
    s.append(v.rect(1.9, 0.06, 2.0, 0.26, SR_PIPE_D))                                              # flange on the floor end
    return "".join(s)


def senior_top(v: V) -> str:
    """Top view: the console along −x, the body along x, the pipe across the chest; y across the room."""
    s = []
    s.append(v.rect(-0.1, -0.7, 0.6, 0.7, SR_CONSOLE) + v.rect(0.6, -0.7, 0.8, 0.7, SR_CONSOLE_L))
    s.append(v.ell(0.2, 0.36, 0.06, 0.06, "#6a5c54"))                                               # mug
    s.append(v.rect(0.3, -0.46, 0.46, -0.3, "#cfc4b4"))                                             # photo, face down
    s.append(v.ell(1.0, 0.0, 0.1, 0.09, SR_SKIN) + v.ell(0.96, 0.0, 0.06, 0.09, SR_HAIR))
    s.append(v.poly([(1.08, -0.22), (1.08, 0.22), (1.64, 0.2), (1.64, -0.2)], SR_JACKET))
    s.append(v.line([(1.12, -0.24), (1.32, -0.3), (1.2, -0.36)], SR_JACKET_D, 0.07))
    s.append(v.poly([(1.64, -0.2), (1.64, 0.2), (2.08, 0.18), (2.08, -0.18)], SR_PANTS))
    for sy in (-1, 1):
        s.append(v.line([(2.08, sy * 0.1), (2.56, sy * 0.12)], SR_PANTS, 0.12))
        s.append(v.rect(2.54, sy * 0.06, 2.66, sy * 0.18, "#2a2d31"))
    s.append(v.line([(1.12, -0.1), (1.04, -0.3), (1.0, -0.4)], SR_CORD, 0.01))
    s.append(v.rect(0.97, -0.44, 1.03, -0.38, "#c9a640"))                                           # key on the floor
    s.append(v.line([(0.78, 0.5), (1.4, 0.06), (1.94, -0.36)], SR_PIPE_D, 0.17))
    s.append(v.line([(0.78, 0.5), (1.4, 0.06), (1.94, -0.36)], SR_PIPE, 0.13))
    s.append(v.rect(-0.1, -0.8, 3.0, -0.76, STONE_L))                                               # broken wall to the relay
    s.append(txt(v.X(3.06), v.Y(-0.8), "пролом в релейную", 11, MUTED))
    return "".join(s)


def sheet_senior() -> str:
    s = [head("Ст-01 · Останки старшего сотрудника — кабинет, под сорвавшейся трубой",
              "Комплекс, старое ядро: L-OLD-CORE/senior_room (Р-2, #170, #178). Осмотр senior_body, ключ на шнурке. "
              "Сейчас: бокс-примитив и труба в breach_station.gd (_build_body), в комплексе модели нет")]
    s.append(panel(24, 92, 856, 780, "Сбоку (пульт слева) · сверху · масштаб рядом с игроком"))
    v = V(110, 470, 190)
    s.append(console_side(v) + senior_side(v) + riser_side(v))
    s.append(ground(v, -0.2, 3.9))
    s.append(hero(v, 3.5))
    s.append(txt(450, 500, "сбоку: на правом боку у подножия пульта, лицом к пролому; стояк сорвался с потолка и лёг", 12, MUTED, "middle"))
    s.append(txt(450, 516, "верхним концом на край пульта, поперёк груди, нижним — на пол. Крови нет, глаза закрыты", 12, MUTED, "middle"))
    v2 = V(150, 690, 170)
    s.append(senior_top(v2))
    s.append(txt(450, 852, "сверху: кружка и перевёрнутая фотография на пульте, ключ на шнурке у руки", 12, MUTED, "middle"))
    s.append(info(900, 112, [
        ("Палитра", [(SR_JACKET, "китель старшего"), (SR_PANTS, "брюки"), (STRIPE, "нашивка, полоса"), (SR_SKIN, "кожа, бледная"),
                     (SR_HAIR, "седина"), (SR_PIPE, "стояк, ржавая сталь")]),
        ("Материалы", ["Плотный тёмный китель поверх комбинезона персонала, нашивка старшего на рукаве, пропуск на груди без текста.",
                       "Кожа бледная, без ран и крови (сцена «тихая», 01-opening). Пыль от пролома на плечах.",
                       "Стояк — стальная труба Ø 0,15 м, ржавчина, оторванный фланец и скоба."]),
        ("Ключевые детали", ["Лицо видно со стороны пролома: глаза закрыты, «будто задремал» (senior_body).",
                             "Шнурок с ключом выпал из ворота и лежит у руки — ключ остаётся отдельным подбором.",
                             "Стояк придавил грудь: одежда смята под трубой, тело и труба не пересекаются."]),
        ("Поза", ["На правом боку у подножия пульта, колени чуть согнуты, нижняя рука под телом, верхняя к ключу (В-8 «а»).",
                  "Статика, без рига. Генерация в A-позе + поза в Blender по авторигу, затем риг удаляется."]),
        ("Масштаб", ["Рост 1,78 м, лёжа ≈ 1,7 × 0,5 × 0,3 м. Стояк ≈ 2,6 м (как в breach_station), пульт 0,9–1,1 м."]),
        ("Канон", ["01-opening Р-2: удар побега объекта №1 сорвал стояк, он убил старшего и проломил стену к релейной; "
                   "«первое тело в игре»; senior_body: «лежит у пульта, стояк придавил его». 03-complex: ключ старшего."]),
        ("Для генерации (этап 2)", ["До 8 тыс. треугольников, 1K. Трубу — мешем сцены (В-9 «а»), фото и кружка уже есть "
                                     "(personal_items.gd)."]),
    ]))
    s.append("</svg>\n")
    return "".join(s)


# ============================================================================= P-106s Herobrine
def herobrine_stand(v: V, t: float = 0.07) -> str:
    """Front, standing, blocky: 32 texels tall, t metres per texel; x centre, feet on the ground."""
    s = []

    def box(x0, y0, w, h, fill):
        return v.rect(x0 * t, y0 * t, (x0 + w) * t, (y0 + h) * t, fill)
    for sx in (-4, 0):                                                                       # legs 4×12
        s.append(box(sx, 0, 4, 12, HB_PANTS))
        s.append(box(sx, 0, 4, 1.5, HB_SHOE))
        s.append(box(sx + (3 if sx else 0), 1.5, 1, 10.5, HB_PANTS_D))
    s.append(box(-4, 12, 8, 12, HB_SHIRT))                                                   # body 8×12
    s.append(box(-4, 12, 8, 1, HB_PANTS))
    s.append(box(-1, 21, 2, 3, HB_SKIN))                                                     # neck V
    for sx in (-8, 4):                                                                       # arms 4×12
        s.append(box(sx, 12, 4, 12, HB_SKIN))
        s.append(box(sx, 20, 4, 4, HB_SHIRT))
        s.append(box(sx, 12, 4, 1, HB_SKIN_D))
    s.append(box(-4, 24, 8, 8, HB_SKIN))                                                     # head 8×8
    s.append(box(-4, 30, 8, 2, HB_HAIR))
    s.append(box(-4, 29, 1, 1, HB_HAIR) + box(3, 29, 1, 1, HB_HAIR))
    s.append(box(-1, 26, 2, 1, HB_SKIN_D))                                                   # nose
    s.append(box(-2, 25, 4, 1, "#6b4a3a"))                                                   # mouth
    for ex in (-3, 1):
        s.append(v.rect(ex * t, 27 * t, (ex + 2) * t, 28 * t, WHITE, 'filter="url(#glow)"'))
    s.append(v.ell(0, 27.5 * t, 6 * t, 2.5 * t, "url(#whiteg)", 'opacity="0.6"'))
    for i in range(-8, 9):                                                                   # texel grid hint
        s.append(f'<line x1="{v.X(i * t):.1f}" y1="{v.Y(0):.1f}" x2="{v.X(i * t):.1f}" y2="{v.Y(32 * t):.1f}" stroke="#000" stroke-opacity="0.06"/>')
    return "".join(s)


def herobrine_lying(v: V, t: float = 0.07) -> str:
    """Side view in the capsule: on the left side, head to the left, knees drawn up, face to the viewer (window)."""
    s = []

    def part(cx, cy, w, h, ang, fill, extra=""):
        inner = v.rect(cx - w / 2 * t, cy - h / 2 * t, cx + w / 2 * t, cy + h / 2 * t, fill, extra)
        return v.rot(ang, cx, cy, inner)
    s.append(part(-0.45, -0.2, 4, 10, -40, HB_SKIN))                                         # under arm to the chin
    s.append(part(0.84, 0.0, 12, 4, 8, HB_PANTS))                                            # thighs drawn forward
    s.append(part(1.16, -0.38, 4, 11, 20, HB_PANTS_D))                                       # shins folded back
    s.append(part(1.04, -0.74, 4, 1.5, 20, HB_SHOE))
    s.append(part(0.0, 0.1, 12, 8, 0, HB_SHIRT))                                             # torso along x
    s.append(part(0.39, 0.1, 1, 8, 0, HB_PANTS))
    s.append(part(0.05, 0.3, 12, 4, 10, HB_SKIN))                                            # upper arm resting forward
    s.append(part(-0.3, 0.36, 4, 4, 10, HB_SHIRT))
    s.append(part(-0.72, 0.14, 8, 8, -8, HB_SKIN))
    s.append(part(-0.7, 0.39, 8, 1.6, -8, HB_HAIR))
    for ex in (-0.82, -0.64):
        s.append(part(ex, 0.17, 2, 1, -8, WHITE, 'filter="url(#glow)"'))
    s.append(v.ell(-0.73, 0.17, 0.3, 0.14, "url(#whiteg)", 'opacity="0.55"'))
    return "".join(s)


def sheet_herobrine() -> str:
    s = [head("P-106s · Херобрин, объект №3 — спит в капсуле №3",
              "Комплекс, модуль 3: prisoner_capsule_herobrine. Сейчас: sleeper_herobrine.gltf "
              "(скрипт: блоки со скин-текстурой, светящиеся глаза)")]
    s.append(panel(24, 92, 856, 780, "Силуэт: стоя спереди (эталон пропорций) · в капсуле на боку · рядом с игроком"))
    v = V(180, 820, 230)
    s.append(herobrine_stand(v))
    s.append(dim(v, 0.68, 0, 2.24, "2,24 м", 1))
    s.append(txt(180, 852, "32 текселя по 7 см", 12, MUTED, "middle"))
    s.append(hero(V(460, 820, 230), 0.0))
    s.append(ground(v, -0.65, 1.3))
    # capsule interior, side view through the window
    cx, cy = 680, 470
    s.append(f'<rect x="{cx - 195}" y="{cy - 200}" width="390" height="360" rx="40" fill="url(#fluid)" stroke="{CAPS_BLUE}" stroke-width="3"/>')
    for i in range(9):
        s.append(f'<circle cx="{cx - 170 + i * 42}" cy="{cy - 170 + (i * 53) % 300}" r="{3 + i % 3}" fill="{CAPS_BLUE}" opacity="0.35"/>')
    s.append(herobrine_lying(V(cx - 20, cy, 150)))
    s.append(txt(cx, cy + 195, "в капсуле: на левом боку, голова влево (+X сокета), лицо к окну,", 12, MUTED, "middle"))
    s.append(txt(cx, cy + 211, "колени подтянуты; плавает — пол капсулы не касается", 12, MUTED, "middle"))
    s.append(txt(cx, 255, "холодная синяя гамма капсулы, свечение глаз — EyeGlow", 12, CAPS_BLUE, "middle"))
    s.append(info(900, 112, [
        ("Палитра", [(HB_SHIRT, "футболка"), (HB_PANTS, "брюки"), (HB_SKIN, "кожа"), (HB_HAIR, "волосы"),
                     (WHITE, "глаза, эмиссия"), (CAPS_BLUE, "свет капсулы")]),
        ("Материалы", ["Ткань и кожа матовые, «пиксельная» текстура 8 текселей на голову; глаза — эмиссия без зрачков.",
                       "Внутри капсулы — жидкость: модель без собственной подсветки, свет даёт капсула."]),
        ("Ключевые детали", ["Кубическая голова 8 × 8, туловище 8 × 12, руки и ноги 4 × 12 — это и есть образ.",
                             "Белые глаза без зрачков, ровное свечение — единственный «живой» сигнал.",
                             "Короткие рукава, тёмные волосы шапкой, без лишних аксессуаров."]),
        ("Поза", ["Свёрнут на левом боку, нижняя рука под подбородком, верхняя лежит вперёд.",
                  "Статика, без рига; позу задаёт скрипт (_HB_POSE)."]),
        ("Масштаб", ["2,24 м в рост (на 0,44 м выше игрока); в капсуле ≈ 2,2 × 1,3 × 1,0 м, центр — сокет окна."]),
        ("Канон", ["docs/world/05-prisoners-and-characters.md: объект №3, первая опытная капсула; "
                   "капсула в холодной синей гамме, аномалия и искажения. Риск узнаваемости — О-10."]),
        ("Для генерации (этап 2)", ["См. В-3: блочную форму генераторы делают хуже скрипта. "
                                     "Рекомендация — скрипт + новая скин-текстура, без генерации."]),
    ]))
    s.append("</svg>\n")
    return "".join(s)


# ============================================================================= staff sleeper
def staff_side(v: V) -> str:
    """Lying on the back, head to the left (−x), side view; y=0 is the mattress."""
    s = []
    s.append(v.ell(-0.76, 0.11, 0.1, 0.11, SKIN_S))
    s.append(v.curve(["M", (-0.86, 0.12), "Q", (-0.84, 0.24), (-0.72, 0.2)], HAIR_S, 0.05))
    s.append(v.poly([(-0.64, 0.04), (-0.64, 0.24), (-0.05, 0.22), (0.02, 0.12), (0.02, 0.0), (-0.64, 0.0)], COVER))
    s.append(v.poly([(-0.02, 0.0), (-0.02, 0.15), (0.5, 0.12), (0.8, 0.1), (0.8, 0.0)], COVER_D))
    s.append(v.rect(0.78, 0.0, 0.88, 0.16, "#2a2d31"))
    s.append(v.line([(-0.55, 0.16), (-0.25, 0.14), (-0.05, 0.12)], COVER_L, 0.05))           # arm along the body
    s.append(v.ell(-0.02, 0.12, 0.04, 0.035, SKIN_S))
    s.append(v.rect(-0.12, 0.1, -0.06, 0.15, "#7fd0a0"))                                       # wrist sensor
    s.append(v.rect(-0.5, 0.2, -0.4, 0.245, STRIPE))                                          # badge
    return "".join(s)


def staff_top(v: V) -> str:
    """Top view (through the lid), head to the left; y is across the bed."""
    s = []
    s.append(v.ell(-0.76, 0.0, 0.11, 0.09, SKIN_S))
    s.append(v.ell(-0.8, 0.0, 0.07, 0.09, HAIR_S))
    s.append(v.poly([(-0.64, -0.23), (-0.64, 0.23), (-0.02, 0.2), (-0.02, -0.2)], COVER))
    for sy in (-1, 1):
        s.append(v.poly([(-0.02, sy * 0.02), (-0.02, sy * 0.18), (0.8, sy * 0.13), (0.8, sy * 0.04)], COVER_D))
        s.append(v.rect(0.78, sy * 0.03, 0.88, sy * 0.14, "#2a2d31"))
        s.append(v.line([(-0.6, sy * 0.28), (-0.3, sy * 0.29), (-0.06, sy * 0.25)], COVER_L, 0.07))
        s.append(v.ell(-0.02, sy * 0.24, 0.045, 0.04, SKIN_S))
    s.append(v.rect(-0.5, 0.06, -0.38, 0.13, STRIPE))
    s.append(v.rect(-0.64, -0.23, -0.02, -0.2, STRIPE, 'opacity="0.7"'))
    return "".join(s)


def sheet_staff() -> str:
    s = [head("Спящий сотрудник — капсулы персонала (U-EMERGENCY)",
              "Капсульный зал персонала, staff_capsule_occupied: виден силуэтом под матовой крышкой. "
              "Сейчас: примитивы в staff_capsule.gd (_build_sleeper). Подключение — после #224")]
    s.append(panel(24, 92, 856, 780, "Силуэт: сбоку в капсуле · сверху через крышку · стоя рядом с игроком"))
    v = V(360, 300, 240)
    s.append(v.rect(-1.3, -0.4, 1.3, -0.1, "#2d3238"))                                        # tub
    s.append(v.rect(-1.15, -0.06, 1.15, 0.0, "#3e4650"))                                       # mattress
    s.append(staff_side(v))
    s.append(v.rect(-1.3, -0.1, 1.3, 0.45, "url(#frost)", f'stroke="{FROST}" stroke-opacity="0.6" rx="18"'))
    s.append(txt(360, 420, "сбоку: на спине, голова к −Z, руки вдоль тела; крышка матовая — читается силуэт", 12, MUTED, "middle"))
    v2 = V(360, 590, 240)
    s.append(v2.rect(-1.15, -0.5, 1.15, 0.5, "#3e4650", 'rx="12"'))
    s.append(staff_top(v2))
    s.append(txt(360, 740, "сверху: значок на груди, датчик на запястье, светоотражающая полоса", 12, MUTED, "middle"))
    v3 = V(735, 840, 200)
    s.append(v3.rect(-0.2, 0.0, -0.04, 0.85, COVER_D) + v3.rect(0.04, 0.0, 0.2, 0.85, COVER_D))
    s.append(v3.rect(-0.23, 0.82, 0.23, 1.45, COVER))
    s.append(v3.rect(-0.3, 0.86, -0.23, 1.42, COVER_L) + v3.rect(0.23, 0.86, 0.3, 1.42, COVER_L))
    s.append(v3.rect(-0.23, 1.05, 0.23, 1.08, STRIPE))
    s.append(v3.ell(0, 1.6, 0.11, 0.13, SKIN_S) + v3.ell(0, 1.68, 0.11, 0.06, HAIR_S))
    s.append(txt(735, 862, "1,75 м", 11, MUTED, "middle"))
    s.append(hero(V(825, 840, 200), 0.0))
    s.append(info(900, 112, [
        ("Палитра", [(COVER, "комбинезон"), (COVER_D, "брюки, тень"), (STRIPE, "полоса, значок"), (SKIN_S, "кожа"),
                     (HAIR_S, "волосы"), (FROST, "матовая крышка")]),
        ("Материалы", ["Плотный рабочий комбинезон с отражающей полосой, мягкая обувь, медицинский датчик на запястье.",
                       "Под крышкой видна только форма: детали лица не нужны, важны силуэт и цвет."]),
        ("Ключевые детали", ["Значок-пропуск на груди (без текста), полоса на поясе и рукавах.",
                             "2–3 варианта текстуры (волосы, тон кожи, цвет нашивки), один меш."]),
        ("Поза", ["Лежит на спине, руки вдоль тела, голова чуть повёрнута. Статика, без рига."]),
        ("Масштаб", ["1,75 м (SLEEPER_HEIGHT), капсула рассчитана до 2,0 м и 0,6 м в плечах."]),
        ("Канон", ["docs/world/03-complex.md: персонал спит в аварийных капсулах. "
                   "Капсула и зал — #210, #224; модель только заменяет примитив."]),
        ("Для генерации (этап 2)", ["До 6 тыс. треугольников, 1K. Низкий приоритет: виден сквозь матовое стекло."]),
    ]))
    s.append("</svg>\n")
    return "".join(s)


# ============================================================================= inventory and line-up
ROWS = [
    ("С-01", "Страж сна (3 варианта)", "Сон Боузера, двор S3: засада, 2 шт.", "dream_shade_guard.gltf (loads/props)",
     "data/dreams/combat.json → ambushes.bowser_first_fight.art", "заменить, с ригом (В-10)"),
    ("Н-01", "Останки героя мира", "Сон Боузера, ниша у цепи (Yard/Remains)", "dream_hero_remains.gltf (loads/props)",
     "scenes/dreams/bowser_dream.tscn → Yard/Remains/Art", "лёжа под плащом, статика"),
    ("Ст-01", "Останки старшего", "Комплекс, L-OLD-CORE/senior_room", "бокс + труба в breach_station.gd",
     "_build_body(); в комплексе модели нет", "новая, статика"),
    ("P-106s", "Херобрин, объект №3", "Комплекс, капсула №3", "objects/art/sleeper_herobrine.tscn",
     "prisoner_capsule_herobrine.tscn (make_capsule_assemblies.py)", "см. В-3"),
    ("—", "Спящий сотрудник", "Капсульный зал персонала", "objects/props/staff_capsule.gd",
     "_build_sleeper(), примитивы в коде", "заменить, после #224"),
    ("P-106s", "Боузер, объект №4", "Комплекс, капсула №4", "objects/art/sleeper_bowser.tscn",
     "пакет уже есть: docs/art/gen/bowser (#162)", "вне задачи"),
    ("Д-02", "Статуи стражей", "Сон Боузера, двор (план)", "— (ещё не сделаны)",
     "docs/art/dream-bowser-s.md: «поза С-01, камень»", "из меша С-01"),
    ("—", "Враги тестового сна", "scenes/dreams/test_dream.tscn", "CapsuleMesh в dream_enemy.gd",
     "отладочная сцена", "не менять"),
]


def sheet_inventory() -> str:
    s = [head("Инвентаризация персонажных моделей (#225)",
              "Что заменяем генерацией, где оно в игре и какой файл сейчас. Пакеты генерации — этап 2, после одобрения",
              h=700)]
    cols = [(32, "Код"), (110, "Персонаж"), (290, "Где в игре"), (560, "Текущий файл"), (850, "Как подключено"), (1200, "Решение")]
    y = 112
    s.append(f'<rect x="24" y="{y - 22}" width="{W - 48}" height="34" rx="6" fill="{PANEL_L}"/>')
    for x, t in cols:
        s.append(txt(x, y, t, 14, ACCENT, weight="700"))
    y += 40
    for i, row in enumerate(ROWS):
        if i % 2 == 0:
            s.append(f'<rect x="24" y="{y - 24}" width="{W - 48}" height="56" rx="6" fill="{PANEL}"/>')
        dim_row = row[5] in ("вне задачи", "не менять")
        for (x, _), cell in zip(cols, row):
            parts = textwrap.wrap(cell, 34 if x in (560, 850) else 30)
            for j, part in enumerate(parts[:2]):
                s.append(txt(x, y + j * 17, part, 13, MUTED if dim_row else TEXT,
                             weight="700" if x == 1200 and not dim_row else "400"))
        y += 62
    y += 10
    s.append(txt(32, y, "Не персонажи и в задачу не входят: след гибели оператора (декаль Н-05), рамка ниши стража "
                       "(К-02), цепь с гирей (подбор). Объекты №1, №2, №5–6 моделей пока не имеют.", 13, MUTED))
    s.append("</svg>\n")
    return "".join(s)


def sheet_lineup() -> str:
    s = [head("Масштаб: все персонажи рядом с игроком", "Один масштаб для всех: 1 м = 150 px, пунктир — каждый метр")]
    s.append(panel(24, 92, W - 48, 780))
    g, k = 760, 150
    s.append(f'<line x1="40" y1="{g}" x2="{W - 40}" y2="{g}" stroke="{GROUND}" stroke-width="1.5"/>')
    for m in (1, 2, 3):
        s.append(f'<line x1="40" y1="{g - m * k}" x2="{W - 40}" y2="{g - m * k}" stroke="{GRID}" stroke-dasharray="4 6"/>')
        s.append(txt(48, g - m * k - 6, f"{m} м", 11, MUTED))
    s.append(hero(V(100, g, k), 0.0))
    s.append(koopa_front(V(290, g, k), "armored"))
    s.append(txt(290, g + 30, "С-01 «а» купа-латник · 2,3 м", 13, TEXT, "middle"))
    s.append(remains_lying_side(V(600, g, k)))
    s.append(txt(600, g + 30, "Н-01 останки · лёжа 1,75 м", 13, TEXT, "middle"))
    s.append(herobrine_stand(V(850, g, k)))
    s.append(txt(850, g + 30, "Херобрин · 2,24 м", 13, TEXT, "middle"))
    vs = V(1000, g, k)
    s.append(vs.rect(-0.2, 0.0, -0.04, 0.85, COVER_D) + vs.rect(0.04, 0.0, 0.2, 0.85, COVER_D))
    s.append(vs.rect(-0.23, 0.82, 0.23, 1.45, COVER) + vs.rect(-0.23, 1.05, 0.23, 1.08, STRIPE))
    s.append(vs.rect(-0.3, 0.86, -0.23, 1.42, COVER_L) + vs.rect(0.23, 0.86, 0.3, 1.42, COVER_L))
    s.append(vs.ell(0, 1.6, 0.11, 0.13, SKIN_S) + vs.ell(0, 1.68, 0.11, 0.06, HAIR_S))
    s.append(txt(1000, g + 30, "сотрудник · 1,75 м", 13, TEXT, "middle"))
    s.append(senior_side(V(1080 - 0.9 * k, g, k)))
    s.append(txt(1215, g + 30, "Ст-01 старший · 1,78 м лёжа", 13, TEXT, "middle"))
    s.append("</svg>\n")
    return "".join(s)


SHEETS = {
    "00_inventory.svg": sheet_inventory,
    "01_shade_guard.svg": sheet_guard,
    "02_hero_remains.svg": sheet_remains,
    "03_herobrine_sleeper.svg": sheet_herobrine,
    "04_staff_sleeper.svg": sheet_staff,
    "05_scale_lineup.svg": sheet_lineup,
    "06_senior_remains.svg": sheet_senior,
}

if __name__ == "__main__":
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in SHEETS.items():
        (out / name).write_text(fn(), encoding="utf-8", newline="\n")
        print(name)
