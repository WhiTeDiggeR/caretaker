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

# С-01 shade guard
SHADOW = "#120d10"
SHADOW_B = "#1f171c"
SHADOW_RIM = "#5b4656"
SMOKE = "#3a2a35"
EYE = "#ff7a2a"
ARMOR = "#4a3f3a"     # neutral base colour for generation (the shader overrides it in game)
ARMOR_L = "#6a5c54"

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


# ============================================================================= С-01 shade guard
def guard_front(v: V, fill: str = SHADOW_B, rim: str = SHADOW_RIM, arm_out: float = 0.0, glow: bool = True) -> str:
    """Front view, 2.6 m. arm_out — degrees the arms are raised out to the sides (A-pose ≈ 35)."""
    s = []
    if glow:
        s.append(v.ell(0, 0.08, 0.7, 0.12, SMOKE, 'filter="url(#soft)" opacity="0.9"'))
    for sx in (-1, 1):
        s.append(v.poly([(sx * 0.1, 1.3), (sx * 0.42, 1.3), (sx * 0.38, 0.8), (sx * 0.13, 0.8)], fill))
        s.append(v.poly([(sx * 0.13, 0.84), (sx * 0.37, 0.84), (sx * 0.33, 0.14), (sx * 0.16, 0.14)], fill))
        s.append(v.poly([(sx * 0.08, 0.15), (sx * 0.42, 0.15), (sx * 0.45, 0.0), (sx * 0.05, 0.0)], fill))
        for c in (-0.09, 0.0, 0.09):
            s.append(v.poly([(sx * 0.25 + c - 0.035, 0.02), (sx * 0.25 + c + 0.035, 0.02), (sx * 0.25 + c, -0.04)], fill))
        s.append(v.poly([(sx * 0.18, 0.86), (sx * 0.32, 0.86), (sx * 0.25, 1.02)], rim))            # knee spike
    s.append(v.ell(0, 1.84, 0.66, 0.62, fill))                                                     # carapace behind
    for sx in (-1, 1):
        for y0, ln in ((2.2, 0.26), (1.85, 0.32), (1.48, 0.24)):
            s.append(v.poly([(sx * 0.6, y0 + 0.08), (sx * 0.6, y0 - 0.08), (sx * (0.6 + ln), y0)], fill))
    s.append(v.ell(0, 1.38, 0.37, 0.25, fill))
    s.append(v.ell(0, 1.8, 0.5, 0.46, fill))
    for sx in (-1, 1):                                                                               # arms
        arm = []
        arm.append(v.poly([(sx * 0.5, 2.06), (sx * 0.78, 2.06), (sx * 0.76, 1.56), (sx * 0.56, 1.56)], fill))
        arm.append(v.poly([(sx * 0.56, 1.58), (sx * 0.8, 1.58), (sx * 0.82, 1.08), (sx * 0.6, 1.08)], fill))
        arm.append(v.rect(sx * 0.58, 1.26, sx * 0.84, 1.36, rim))                                    # spiked bracer
        arm.append(v.poly([(sx * 0.84, 1.36), (sx * 0.84, 1.26), (sx * 0.96, 1.31)], rim))
        arm.append(v.ell(sx * 0.71, 1.0, 0.13, 0.11, fill))
        for c in (-0.07, 0.0, 0.07):
            arm.append(v.poly([(sx * 0.71 + c - 0.03, 0.94), (sx * 0.71 + c + 0.03, 0.94), (sx * 0.71 + c, 0.78)], fill))
        a = "".join(arm)
        s.append(v.rot(-sx * arm_out, sx * 0.62, 2.04, a) if arm_out else a)
        s.append(v.ell(sx * 0.6, 2.1, 0.26, 0.19, fill))                                            # pauldron
        s.append(v.poly([(sx * 0.52, 2.22), (sx * 0.7, 2.22), (sx * 0.64, 2.52)], fill))
        s.append(v.poly([(sx * 0.8, 2.16), (sx * 0.8, 2.04), (sx * 1.02, 2.12)], fill))
    s.append(v.rect(-0.14, 2.22, 0.14, 2.36, fill))
    s.append(v.ell(0, 2.45, 0.23, 0.2, fill))
    s.append(v.rect(-0.16, 2.28, 0.16, 2.4, fill))
    for sx in (-1, 1):                                                                              # curled horns
        s.append(v.curve(["M", (sx * 0.15, 2.52), "Q", (sx * 0.42, 2.58), (sx * 0.46, 2.76), "Q", (sx * 0.5, 2.6),
                          (sx * 0.38, 2.56)], fill, 0.07))
    s.append(v.poly([(-0.05, 2.6), (0.05, 2.6), (0, 2.7)], fill))
    # rim light (fresnel) and plate lines
    s.append(v.curve(["M", (-0.5, 1.8), "Q", (-0.5, 2.26), (0, 2.26), "Q", (0.5, 2.26), (0.5, 1.8)], rim, 0.012))
    for y in (1.62, 1.44):
        s.append(v.line([(-0.24, y), (0.24, y)], rim, 0.01))
    s.append(v.line([(0, 1.36), (0, 1.66)], rim, 0.01))
    if glow:
        for sx in (-1, 1):
            s.append(v.ell(sx * 0.08, 2.43, 0.1, 0.08, "url(#eyeg)"))
            s.append(v.ell(sx * 0.08, 2.43, 0.04, 0.018, EYE, 'filter="url(#glow)"'))
        s.append(v.line([(0.1, 1.95), (0.16, 1.82), (0.12, 1.7), (0.2, 1.58)], EYE, 0.012, 'filter="url(#glow)" opacity="0.9"'))
        s.append(v.line([(-0.22, 1.9), (-0.14, 1.78), (-0.2, 1.66)], EYE, 0.01, 'filter="url(#glow)" opacity="0.8"'))
    return "".join(s)


def guard_side(v: V, fill: str = SHADOW_B, rim: str = SHADOW_RIM, glow: bool = True) -> str:
    """Side view, front to +x."""
    s = []
    if glow:
        s.append(v.ell(0, 0.08, 0.6, 0.12, SMOKE, 'filter="url(#soft)" opacity="0.9"'))
    s.append(v.poly([(-0.18, 1.3), (0.2, 1.3), (0.18, 0.82), (-0.12, 0.8)], fill))
    s.append(v.poly([(-0.12, 0.84), (0.16, 0.84), (0.1, 0.14), (-0.1, 0.14)], fill))
    s.append(v.poly([(-0.16, 0.15), (0.34, 0.15), (0.44, 0.0), (-0.18, 0.0)], fill))
    s.append(v.poly([(0.4, 0.06), (0.4, 0.0), (0.52, 0.0)], fill))
    s.append(v.poly([(0.14, 0.9), (0.14, 0.76), (0.34, 0.8)], rim))
    s.append(v.ell(0, 1.38, 0.3, 0.25, fill))
    s.append(v.ell(0.04, 1.8, 0.38, 0.46, fill))
    s.append(v.ell(-0.3, 1.84, 0.36, 0.64, fill))                                  # carapace dome on the back
    for y0, ln in ((2.28, 0.34), (1.92, 0.42), (1.52, 0.34)):
        s.append(v.poly([(-0.6, y0 + 0.1), (-0.6, y0 - 0.1), (-0.62 - ln, y0 - 0.06)], fill))
    s.append(v.curve(["M", (-0.6, 1.3), "Q", (-0.78, 1.84), (-0.48, 2.4)], rim, 0.014))
    s.append(v.ell(0.0, 2.1, 0.24, 0.2, fill))
    s.append(v.poly([(-0.08, 2.24), (0.1, 2.24), (0.0, 2.54)], fill))
    s.append(v.poly([(0.08, 2.06), (0.1, 1.56), (0.3, 1.56), (0.26, 2.06)], fill))
    s.append(v.poly([(0.14, 1.58), (0.34, 1.58), (0.42, 1.1), (0.22, 1.08)], fill))
    s.append(v.rect(0.16, 1.26, 0.42, 1.36, rim))
    s.append(v.ell(0.34, 1.0, 0.11, 0.12, fill))
    s.append(v.poly([(0.36, 0.94), (0.46, 0.94), (0.5, 0.8)], fill))
    s.append(v.rect(0.0, 2.22, 0.18, 2.36, fill))
    s.append(v.ell(0.1, 2.46, 0.2, 0.19, fill))
    s.append(v.poly([(0.16, 2.4), (0.36, 2.36), (0.32, 2.28), (0.12, 2.3)], fill))                  # jaw guard / visor
    s.append(v.curve(["M", (0.02, 2.56), "Q", (-0.2, 2.74), (-0.26, 2.56), "Q", (-0.28, 2.44), (-0.18, 2.42)], fill, 0.07))
    s.append(v.poly([(0.06, 2.6), (0.14, 2.6), (0.08, 2.7)], fill))
    if glow:
        s.append(v.ell(0.24, 2.44, 0.09, 0.07, "url(#eyeg)"))
        s.append(v.ell(0.25, 2.44, 0.035, 0.016, EYE, 'filter="url(#glow)"'))
    return "".join(s)


def sheet_guard() -> str:
    s = [head("С-01 · Страж-тень — враг сна Боузера",
              "Двор первого боя S3, засада bowser_first_fight: 2 стража выходят из ниш. Сейчас: dream_shade_guard.gltf "
              "(скрипт, примитивы, без скелета) + шейдер dream_shadow")]
    s.append(panel(24, 92, 856, 780, "Силуэт: спереди (A-поза для генерации и рига) · сбоку · в игре под шейдером"))
    v = V(250, 820, 170)
    s.append(guard_front(v, ARMOR, ARMOR_L, arm_out=24, glow=False))
    s.append(txt(250, 852, "спереди, A-поза, нейтральная текстура", 12, MUTED, "middle"))
    v2 = V(620, 820, 170)
    s.append(guard_side(v2, ARMOR, ARMOR_L, glow=False))
    s.append(txt(620, 852, "сбоку, лицом вправо", 12, MUTED, "middle"))
    s.append(dim(v2, -1.05, 0, 2.6, "2,6 м", -1))
    v3 = V(780, 420, 95)
    s.append(f'<rect x="{v3.X(-0.95):.0f}" y="{v3.Y(2.95):.0f}" width="{1.9 * 95:.0f}" height="{3.12 * 95:.0f}" rx="8" fill="#0c090b"/>')
    s.append(guard_front(v3))
    s.append(txt(780, 452, "в игре: dream_shadow", 11, MUTED, "middle"))
    s.append(txt(780, 467, "(#120d10, френель-дым,", 11, MUTED, "middle"))
    s.append(txt(780, 482, "глаза и трещины #ff7a2a)", 11, MUTED, "middle"))
    s.append(hero(V(800, 820, 170), 0.0))
    s.append(ground(v, -1.05, 1.05) + ground(v2, -1.0, 1.4))
    s.append(info(900, 112, [
        ("Палитра", [(SHADOW, "тень (шейдер)"), (SMOKE, "дым по краю"), (EYE, "глаза, трещины"),
                     (ARMOR, "база для генерации"), (ARMOR_L, "кромки пластин"), (SHADOW_RIM, "френель")]),
        ("Материалы", ["Один материал на всю модель: в игре его заменяет шейдер DT-12 dream_shadow. Текстура генерации "
                       "нужна только для чтения формы: тёмный матовый панцирь, без яркой раскраски."]),
        ("Ключевые детали", ["Шипастый панцирь на спине: 7 конических шипов в 3 ряда, торчат назад и в стороны.",
                             "Рогатый шлем, морда скрыта забралом — видны только две щели глаз.",
                             "Наплечники с шипом вверх и вбок, браслеты с шипом, по три когтя на руке и ноге.",
                             "Шипы на коленях, пластины брюха — силуэт «черепаха-воин», без лица хозяина."]),
        ("Поза", ["Генерация: A-поза (руки на 30–35° от тела), ноги на ширине плеч, взгляд вперёд — под авториг.",
                  "Анимации: стойка, шаг, замах 0,45 с, удар, «сборка» из дыма 1,5 с (шейдер), смерть-рассыпание."]),
        ("Масштаб", ["2,6 м — на 0,8 м выше игрока; рога и гребень заканчиваются на 2,6 м. Коллизия — капсула "
                     "DreamEnemy, глаза на 1,39 м над центром тела (art_eye_height)."]),
        ("Канон", ["Д-2 «а» в docs/art/dream-bowser-s.md: панцирный воин, узнаваемый при Б-2 (облик Боузера, "
                   "его стражи), читается тенью. Бой: docs/game_design/05-dream-combat.md, data/dreams/combat.json."]),
        ("Для генерации (этап 2)", ["С ригом: гуманоидный скелет, 3–5 клипов. До 15 тыс. треугольников, текстуры 1K."]),
    ]))
    s.append("</svg>\n")
    return "".join(s)


# ============================================================================= Н-01 remains of the world's hero
def remains_front(v: V) -> str:
    s = []
    s.append(v.rect(-1.0, 0, 1.0, 1.7, STONE))                                                   # niche back wall
    for y in (0.5, 1.0, 1.5):
        s.append(v.line([(-1.0, y), (1.0, y)], STONE_L, 0.006))
    s.append(v.curve(["M", (-0.58, 0.0), "Q", (-0.5, 0.5), (-0.24, 0.78), "Q", (-0.2, 1.1), (0.0, 1.13), "Q", (0.2, 1.1),
                      (0.24, 0.78), "Q", (0.5, 0.5), (0.58, 0.0), "Z"], CLOAK_D, 0.004, CLOAK))
    s.append(v.ell(0, 0.9, 0.12, 0.13, "#0b0809"))                                               # empty hood
    s.append(v.curve(["M", (-0.16, 0.98), "Q", (0, 1.08), (0.16, 0.98)], CLOAK_L, 0.012))
    for x0 in (-0.42, -0.2, 0.18, 0.4):                                                            # rotted folds
        s.append(v.line([(x0 * 0.8, 0.7), (x0, 0.05)], CLOAK_D, 0.01))
    s.append(v.poly([(-0.6, 0.0), (-0.44, 0.08), (-0.3, 0.0)], CLOAK_D))
    s.append(v.poly([(0.3, 0.0), (0.46, 0.06), (0.62, 0.0)], CLOAK_D))
    for sx in (-1, 1):                                                                              # knees and shins
        s.append(v.line([(sx * 0.17, 0.4), (sx * 0.2, 0.05)], BONE, 0.07))
        s.append(v.ell(sx * 0.17, 0.4, 0.06, 0.055, BONE))
        s.append(v.ell(sx * 0.2, 0.03, 0.07, 0.035, BONE_D))
    s.append(v.line([(-0.3, 0.62), (-0.32, 0.45), (-0.2, 0.42)], BONE, 0.05))                       # left hand on the knee
    s.append(v.line([(0.3, 0.62), (0.42, 0.34), (0.4, 0.06)], BONE, 0.05))                          # right hand to the note
    for f in (-0.03, 0.0, 0.03):
        s.append(v.line([(0.4 + f, 0.06), (0.42 + f * 1.4, 0.0)], BONE, 0.012))
    s.append(v.rect(0.42, 0.0, 0.7, 0.01, "#d8cfbf"))                                                # predecessor's note
    s.append(v.ell(-0.58, 0.07, 0.17, 0.08, CAP))                                                   # the cap
    s.append(v.rect(-0.76, 0.0, -0.4, 0.025, CAP_D))
    s.append(v.ell(-0.58, 0.08, 0.05, 0.04, BADGE))
    s.append(v.line([(0.7, 0.03), (0.92, 0.38)], WOOD, 0.035))                                     # the mallet
    s.append(v.rect(0.82, 0.3, 1.0, 0.54, WOOD))
    s.append(v.rect(0.82, 0.4, 1.0, 0.44, IRON_L))
    # chain with the shackle weight (separate pickup, Д-4а) — context only
    s.append(v.line([(-0.2, 0.02), (-0.05, 0.03), (0.1, 0.02), (0.22, 0.04)], IRON_L, 0.02, 'stroke-dasharray="4 3"'))
    s.append(v.poly([(-0.36, 0.0), (-0.22, 0.0), (-0.25, 0.12), (-0.33, 0.12)], IRON))
    return "".join(s)


def remains_side(v: V) -> str:
    """Side view: the niche wall on the left, the body sits facing +x."""
    s = []
    s.append(v.rect(-0.55, 0, -0.4, 1.7, STONE))
    s.append(v.curve(["M", (-0.4, 0.0), "L", (-0.4, 0.7), "Q", (-0.36, 1.06), (-0.12, 1.12), "Q", (0.06, 1.08), (0.08, 0.92),
                      "Q", (0.02, 0.72), (0.1, 0.5), "Q", (0.16, 0.2), (0.3, 0.0), "Z"], CLOAK_D, 0.004, CLOAK))
    s.append(v.ell(0.02, 0.9, 0.06, 0.11, "#0b0809"))
    s.append(v.line([(-0.05, 0.22), (0.38, 0.4), (0.72, 0.05)], BONE, 0.07))                       # thigh, shin
    s.append(v.ell(0.38, 0.4, 0.06, 0.06, BONE))
    s.append(v.rect(0.66, 0.0, 0.9, 0.05, BONE_D))
    s.append(v.line([(-0.14, 0.62), (0.1, 0.5), (0.34, 0.45)], BONE, 0.05))
    s.append(v.poly([(-0.4, 0.0), (0.45, 0.0), (0.3, 0.06), (-0.2, 0.08)], CLOAK_D))
    return "".join(s)


def sheet_remains() -> str:
    s = [head("Н-01 · Останки героя мира — сон Боузера, ниша у цепи",
              "Двор S3, Yard/Remains: точка осмотра «ОСМОТРЕТЬ ОСТАНКИ», рядом цепь с грузом. "
              "Сейчас: dream_hero_remains.gltf (скрипт, примитивы)")]
    s.append(panel(24, 92, 856, 780, "Силуэт: спереди (в нише) · сбоку · масштаб рядом с игроком"))
    v = V(290, 560, 220)
    s.append(remains_front(v))
    s.append(ground(v, -1.0, 1.05))
    s.append(txt(290, 590, "спереди: плащ, пустой капюшон, колени, кепка у колена, молот, записка", 12, MUTED, "middle"))
    s.append(dim(v, -1.12, 0, 1.12, "1,1 м", -1))
    v2 = V(700, 560, 180)
    s.append(remains_side(v2))
    s.append(ground(v2, -0.6, 0.95))
    s.append(txt(700, 590, "сбоку: спиной к стене ниши", 12, MUTED, "middle"))
    v3 = V(180, 830, 110)
    s.append(remains_front(v3))
    s.append(hero(v3, 1.45))
    s.append(ground(v3, -1.0, 1.75))
    s.append(txt(60, 640, "Масштаб (1:2,7): сидя ≈ 1,1 м, в рост был бы ≈ 1,7 м", 12, MUTED))
    # glove / trophy variants for question В-1
    s.append(txt(560, 640, "В-1: что видно из-под плаща", 12, ACCENT, weight="700"))
    for i, (lbl, col) in enumerate((("а. кости", BONE), ("б. перчатка", "#f2eee6"), ("в. скрыто", CLOAK))):
        x = 560 + i * 100
        vv = V(x + 25, 800, 260)
        s.append(vv.ell(0, 0.18, 0.14, 0.18, CLOAK))
        s.append(vv.ell(0, 0.04, 0.07, 0.04, col))
        if col != CLOAK:
            for f in (-0.04, 0.0, 0.04):
                s.append(vv.line([(f, 0.03), (f * 1.3, -0.04)], col, 0.016 if col == BONE else 0.03))
        s.append(txt(x + 25, 830, lbl, 11, MUTED, "middle"))
    s.append(info(900, 112, [
        ("Палитра", [(CLOAK, "истлевший плащ"), (CLOAK_L, "кромка плаща"), (BONE, "кости"), (CAP, "кепка, вытертая"),
                     (BADGE, "пустой круг-эмблема"), (WOOD, "молот, дерево")]),
        ("Материалы", ["Плащ — грубая шерсть, рваные края, пыль и пепел. Кости — матовые, тёплые, без глянца.",
                       "Кепка — выцветшая красная ткань, эмблема — пустой белый круг (Д-7, без букв).",
                       "Молот — тёмное дерево, железный обод. Без надписей: тексты — в данных (#186)."]),
        ("Ключевые детали", ["Пустой капюшон: лица нет (Д-3 «б»).",
                             "Колени торчат из-под плаща, правая рука тянется к записке на полу, левая на колене.",
                             "Кепка упала к колену — единственный узнаваемый мотив героя.",
                             "Цепь с кандальной гирей — отдельный предмет-подбор (DreamWeaponPickup), не в модели."]),
        ("Поза", ["Сидит, спиной к стене ниши, обмяк вперёд. Статичная модель, без рига, коллизия — простая."]),
        ("Масштаб", ["Габарит ≈ 1,4 × 1,1 × 1,0 м без молота (Н-01). Пол — под телом, спина к −Z."]),
        ("Канон", ["#186: останки — герой этого мира, побеждённый хозяином (Б-1, Б-12). "
                   "Д-3 «б», Д-4 «а» в docs/art/dream-bowser-s.md; сцена — docs/game_design/06-bowser-dream-world.md §5."]),
        ("Для генерации (этап 2)", ["Статика: до 8 тыс. треугольников, текстуры 1K. Кепку и молот — отдельными мешами."]),
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
    ("С-01", "Страж-тень", "Сон Боузера, двор S3: засада, 2 шт.", "dream_shade_guard.gltf (loads/props)",
     "data/dreams/combat.json → ambushes.bowser_first_fight.art", "заменить, с ригом"),
    ("Н-01", "Останки героя мира", "Сон Боузера, ниша у цепи (Yard/Remains)", "dream_hero_remains.gltf (loads/props)",
     "scenes/dreams/bowser_dream.tscn → Yard/Remains/Art", "заменить, статика"),
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
    ("—", "Останки в комплексе", "нет ни одной модели", "—", "канон: погибший учёный у капсулы №3", "см. В-5"),
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
    s.append(hero(V(150, g, k), 0.0))
    v = V(380, g, k)
    s.append(guard_front(v))
    s.append(txt(380, g + 30, "С-01 страж-тень · 2,6 м", 13, TEXT, "middle"))
    s.append(remains_front(V(670, g, k)))
    s.append(txt(670, g + 30, "Н-01 останки · сидя 1,1 м", 13, TEXT, "middle"))
    s.append(herobrine_stand(V(900, g, k)))
    s.append(txt(900, g + 30, "P-106s Херобрин · 2,24 м", 13, TEXT, "middle"))
    vs = V(1150, g, k)
    s.append(vs.rect(-0.2, 0.0, -0.04, 0.85, COVER_D) + vs.rect(0.04, 0.0, 0.2, 0.85, COVER_D))
    s.append(vs.rect(-0.23, 0.82, 0.23, 1.45, COVER) + vs.rect(-0.23, 1.05, 0.23, 1.08, STRIPE))
    s.append(vs.rect(-0.3, 0.86, -0.23, 1.42, COVER_L) + vs.rect(0.23, 0.86, 0.3, 1.42, COVER_L))
    s.append(vs.ell(0, 1.6, 0.11, 0.13, SKIN_S) + vs.ell(0, 1.68, 0.11, 0.06, HAIR_S))
    s.append(txt(1150, g + 30, "сотрудник · 1,75 м", 13, TEXT, "middle"))
    s.append("</svg>\n")
    return "".join(s)


SHEETS = {
    "00_inventory.svg": sheet_inventory,
    "01_shade_guard.svg": sheet_guard,
    "02_hero_remains.svg": sheet_remains,
    "03_herobrine_sleeper.svg": sheet_herobrine,
    "04_staff_sleeper.svg": sheet_staff,
    "05_scale_lineup.svg": sheet_lineup,
}

if __name__ == "__main__":
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in SHEETS.items():
        (out / name).write_text(fn(), encoding="utf-8", newline="\n")
        print(name)
