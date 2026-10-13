"""Concept sheets for docs/art/dream-bowser-s.md (#187). Own drawings, no third-party assets."""
from __future__ import annotations

import math
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
FONT = "'PT Sans', Arial, sans-serif"

BG = "#141016"
STONE = "#3b3236"
STONE_D = "#2a2226"
STONE_L = "#4d4247"
IRON = "#1a1718"
BRONZE = "#8a6a2e"
BRONZE_L = "#b8913a"
SPIKE = "#cfc4b4"
GREEN = "#2f6e3a"
LAVA = "#ff5a1a"
EMBER = "#ffb35a"
WHITE = "#eef6ff"
TEXT = "#efe7dc"
MUTED = "#b0a59c"
HERO = "#d9d2c8"


def head(w: int, h: int, title: str, sub: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" font-family="{FONT}">
<defs>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
<radialGradient id="warm"><stop offset="0" stop-color="{EMBER}" stop-opacity="0.55"/><stop offset="1" stop-color="{EMBER}" stop-opacity="0"/></radialGradient>
<radialGradient id="whiteg"><stop offset="0" stop-color="{WHITE}" stop-opacity="0.7"/><stop offset="1" stop-color="{WHITE}" stop-opacity="0"/></radialGradient>
<linearGradient id="lavag" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffc04a"/><stop offset="0.4" stop-color="{LAVA}"/><stop offset="1" stop-color="#8a2f1a"/></linearGradient>
</defs>
<rect width="{w}" height="{h}" rx="14" fill="{BG}"/>
<text x="32" y="44" font-size="24" font-weight="700" fill="{TEXT}">{title}</text>
<text x="32" y="70" font-size="14" fill="{MUTED}">{sub}</text>
'''


def txt(x, y, s, size=13, fill=TEXT, anchor="start", weight="400") -> str:
    return f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" font-weight="{weight}">{s}</text>\n'


def hero(x, g, k) -> str:
    """1.8 m figure standing on ground line g, px per metre k."""
    def p(mx, my):
        return f"{x + mx * k:.1f},{g - my * k:.1f}"
    body = (f'<path d="M{p(-0.2, 1.45)} L{p(0.2, 1.45)} L{p(0.17, 0.85)} L{p(0.12, 0)} L{p(0.03, 0)} L{p(0, 0.8)} '
            f'L{p(-0.03, 0)} L{p(-0.12, 0)} L{p(-0.17, 0.85)} Z" fill="{HERO}"/>')
    headc = f'<circle cx="{x:.1f}" cy="{g - 1.63 * k:.1f}" r="{0.13 * k:.1f}" fill="{HERO}"/>'
    return body + headc + txt(x, g + 16, "1,8 м", 11, MUTED, "middle") + "\n"


def ground(x0, x1, g) -> str:
    return f'<line x1="{x0}" y1="{g}" x2="{x1}" y2="{g}" stroke="#5a4e48" stroke-width="1.5"/>\n'


def blocks(x, y, w, h, k, course=1.0, length=2.0, stroke=STONE_D) -> str:
    """Masonry lines inside rect (x, y top-left in px; w, h in metres)."""
    s = []
    rows = int(h / course)
    for r in range(1, rows + 1):
        yy = y + h * k - r * course * k
        s.append(f'<line x1="{x:.1f}" y1="{yy:.1f}" x2="{x + w * k:.1f}" y2="{yy:.1f}" stroke="{stroke}" stroke-width="1"/>')
    for r in range(rows):
        off = (length / 2) * (r % 2)
        xx = off
        while xx < w:
            if xx > 0:
                y0 = y + h * k - (r + 1) * course * k
                s.append(f'<line x1="{x + xx * k:.1f}" y1="{y0:.1f}" x2="{x + xx * k:.1f}" y2="{y0 + course * k:.1f}" stroke="{stroke}" stroke-width="1"/>')
            xx += length
    return "\n".join(s) + "\n"


def spikes_row(x0, x1, y, k, size=0.5, step=1.0, fill=SPIKE) -> str:
    s = []
    xx = x0 + step * k / 2
    while xx < x1:
        s.append(f'<path d="M{xx - size * k * 0.35:.1f},{y:.1f} L{xx:.1f},{y - size * k:.1f} L{xx + size * k * 0.35:.1f},{y:.1f} Z" fill="{fill}"/>')
        xx += step * k
    return "\n".join(s) + "\n"


def arch_path(cx, g, w, h, k) -> str:
    """Round-top opening, w x h metres, bottom centre (cx, g)."""
    r = w / 2
    x0, x1 = cx - r * k, cx + r * k
    ys = g - (h - r) * k
    return f"M{x0:.1f},{g:.1f} L{x0:.1f},{ys:.1f} A{r * k:.1f},{r * k:.1f} 0 0 1 {x1:.1f},{ys:.1f} L{x1:.1f},{g:.1f} Z"


# ---------------------------------------------------------------- sheet 1: fortress kit + closed branches
def sheet_kit() -> str:
    k = 20
    W, H = 1200, 840
    s = [head(W, H, "Модульный набор крепости и закрытые ветки",
              "Концепт DB-К, DB-З. Сетка 4 м, высоты кратны 2 м, масштаб гиганта ×2,5. Мотивы фан-образа: белые конические шипы, ошейники колонн, чёрный металл.")]
    x0, g = 60, 380
    m = lambda v: x0 + v * k  # noqa: E731
    s.append(ground(40, 760, g))
    # K-01 wall 4 x 12 with crenellation
    s.append(f'<rect x="{m(0) - 4}" y="{g - 0.8 * k}" width="{4 * k + 8}" height="{0.8 * k}" fill="{STONE_D}"/>')
    s.append(f'<rect x="{m(0)}" y="{g - 11 * k}" width="{4 * k}" height="{10.2 * k}" fill="{STONE}"/>')
    s.append(blocks(m(0), g - 11 * k, 4, 10.2, k))
    for i in range(2):
        mx = m(i * 2 + 0.25)
        s.append(f'<rect x="{mx}" y="{g - 12.4 * k}" width="{1.5 * k}" height="{1.4 * k}" fill="{STONE_L}"/>')
        s.append(spikes_row(mx, mx + 1.5 * k, g - 12.4 * k, k, 0.7, 1.5))
    s.append(txt(m(2), g + 34, "К-01 Стена 4 × 12 м", 13, TEXT, "middle", "600"))
    # K-02 wall with guardian niche 3 x 5
    s.append(f'<rect x="{m(6)}" y="{g - 12 * k}" width="{4 * k}" height="{12 * k}" fill="{STONE}"/>')
    s.append(blocks(m(6), g - 12 * k, 4, 12, k))
    s.append(f'<path d="{arch_path(m(8), g, 3, 5, k)}" fill="#0d0a0c" stroke="{BRONZE}" stroke-width="2"/>')
    s.append(f'<ellipse cx="{m(8)}" cy="{g - 2.4 * k}" rx="{0.9 * k}" ry="{1.6 * k}" fill="#3a1c18" opacity="0.7" filter="url(#soft)"/>')
    s.append(f'<circle cx="{m(8) + 6}" cy="{g - 3.3 * k}" r="2.5" fill="#ff7a2a"/>')
    s.append(txt(m(8), g + 54, "К-02 Стена с нишей 3 × 5 м", 13, TEXT, "middle", "600"))
    # K-03 column 2 x 10 with spiked collar
    s.append(f'<rect x="{m(11.7)}" y="{g - 0.8 * k}" width="{2.6 * k}" height="{0.8 * k}" fill="{STONE_L}"/>')
    s.append(f'<rect x="{m(12)}" y="{g - 9.2 * k}" width="{2 * k}" height="{8.4 * k}" fill="{STONE}"/>')
    s.append(blocks(m(12), g - 9.2 * k, 2, 8.4, k, 1.4, 2.0))
    s.append(f'<rect x="{m(11.7)}" y="{g - 10 * k}" width="{2.6 * k}" height="{0.8 * k}" fill="{STONE_L}"/>')
    s.append(f'<rect x="{m(11.85)}" y="{g - 3.4 * k}" width="{2.3 * k}" height="{0.6 * k}" fill="{IRON}" stroke="{BRONZE}" stroke-width="1.5"/>')
    for sx in (11.85, 14.15):
        d = -1 if sx < 13 else 1
        s.append(f'<path d="M{m(sx)},{g - 3.25 * k} L{m(sx) + d * 0.6 * k},{g - 3.1 * k} L{m(sx)},{g - 2.95 * k} Z" fill="{SPIKE}"/>')
    s.append(spikes_row(m(11.85), m(14.15), g - 3.4 * k, k, 0.45, 0.6))
    s.append(txt(m(13), g + 34, "К-03 Колонна 2 × 2 × 10 м", 13, TEXT, "middle", "600"))
    # K-04 gate wall 8 x 10, opening 5 x 7
    s.append(f'<rect x="{m(16.5)}" y="{g - 10 * k}" width="{8 * k}" height="{10 * k}" fill="{STONE}"/>')
    s.append(blocks(m(16.5), g - 10 * k, 8, 10, k))
    s.append(f'<path d="{arch_path(m(20.5), g, 5.6, 7.4, k)}" fill="{STONE_L}"/>')
    s.append(f'<path d="{arch_path(m(20.5), g, 5, 7, k)}" fill="{IRON}"/>')
    s.append(f'<line x1="{m(20.5)}" y1="{g}" x2="{m(20.5)}" y2="{g - 7 * k}" stroke="#0a0809" stroke-width="2"/>')
    for row in (1.5, 3.5, 5.0):
        s.append(spikes_row(m(18.3), m(22.7), g - row * k, k, 0.35, 0.9, "#8f857a"))
    s.append(f'<rect x="{m(17.9)}" y="{g - 4.4 * k}" width="{5.2 * k}" height="{0.25 * k}" fill="{GREEN}"/>')
    s.append(f'<circle cx="{m(19.9)}" cy="{g - 2.6 * k}" r="{0.35 * k}" fill="none" stroke="{BRONZE_L}" stroke-width="2.5"/>')
    s.append(f'<circle cx="{m(21.1)}" cy="{g - 2.6 * k}" r="{0.35 * k}" fill="none" stroke="{BRONZE_L}" stroke-width="2.5"/>')
    s.append(txt(m(20.5), g + 54, "К-04 Проём с вратами 5 × 7 м", 13, TEXT, "middle", "600"))
    # K-05 stairs 0.5 m + ramp
    pts = [f"{m(26.5)},{g}"]
    for i in range(4):
        pts += [f"{m(26.5 + i)},{g - (i + 1) * 0.5 * k}", f"{m(27.5 + i)},{g - (i + 1) * 0.5 * k}"]
    pts += [f"{m(30.5)},{g}"]
    s.append(f'<polygon points="{" ".join(pts)}" fill="{STONE_L}"/>')
    s.append(f'<line x1="{m(26.5)}" y1="{g}" x2="{m(30.5)}" y2="{g - 2 * k}" stroke="{BRONZE_L}" stroke-width="2" stroke-dasharray="6 4"/>')
    s.append(txt(m(28.5), g + 34, "К-05 Ступени 0,5 м", 13, TEXT, "middle", "600"))
    s.append(txt(m(28.5), g + 70, "пунктир — пандус 1:2", 11, MUTED, "middle"))
    s.append(hero(m(32.6), g, k))

    # legend right
    lx, ly = 800, 120
    s.append(txt(lx, ly, "Материалы набора", 15, TEXT, "start", "700"))
    rows = [(STONE, "DT-01 кладка стен (тёмный камень, крупный блок 1 × 2 м)"),
            (STONE_L, "DT-02 плиты пола и карнизы"),
            (IRON, "DT-05 чёрный кованый металл (врата, оковки)"),
            (BRONZE_L, "DT-07 бронза (обода, кольца, кромки)"),
            (SPIKE, "DT-01b шипы — светлый камень/кость, конусы"),
            (GREEN, "акцент #2f6e3a — полосы и знамёна, не больше 5 % кадра")]
    for i, (c, t) in enumerate(rows):
        y = ly + 26 + i * 24
        s.append(f'<rect x="{lx}" y="{y - 12}" width="16" height="16" rx="3" fill="{c}" stroke="#5a4e48"/>')
        s.append(txt(lx + 26, y + 1, t, 12))
    ny = ly + 200
    for i, t in enumerate(["Сетка 4 м совпадает с блокаутом #182: стены 4 и 8 м,",
                           "колонны 2 м, высоты 6/8/10/12 м.",
                           "Мелкая деталь (швы, сколы, клёпка) — в нормалях.",
                           "Ниша стража — вариант стены, а не отдельная модель.",
                           "Бюджет: модуль стены до 2 000 тр., врата до 8 000."]):
        s.append(txt(lx, ny + i * 20, t, 12, MUTED))

    # row 2: closed branches
    g2 = 760
    s.append(txt(40, 470, "Закрытые проходы веток (В-1): точки подключения будущих визитов", 17, TEXT, "start", "700"))
    s.append(ground(40, 760, g2))
    # З-1 rubble
    s.append(f'<rect x="{m(0)}" y="{g2 - 8 * k}" width="{6 * k}" height="{8 * k}" fill="{STONE}"/>')
    s.append(blocks(m(0), g2 - 8 * k, 6, 8, k))
    s.append(f'<path d="{arch_path(m(3), g2, 4, 6, k)}" fill="#0d0a0c"/>')
    rub = [(1.0, 0, 2.2, 1.6, -8), (2.6, 0, 2.4, 1.8, 6), (1.4, 1.5, 1.8, 1.4, 14), (3.0, 1.6, 1.6, 1.3, -10),
           (1.9, 2.8, 2.0, 1.2, 4), (2.4, 3.9, 1.4, 1.1, -14), (3.4, 2.9, 1.2, 1.0, 20)]
    for (bx, by, bw, bh, rot) in rub:
        cx, cy = m(bx + bw / 2), g2 - (by + bh / 2) * k
        s.append(f'<rect x="{m(bx)}" y="{g2 - (by + bh) * k}" width="{bw * k}" height="{bh * k}" fill="{STONE_L}" stroke="{STONE_D}" transform="rotate({rot} {cx:.1f} {cy:.1f})"/>')
    s.append(f'<rect x="{m(0.3)}" y="{g2 - 1.2 * k}" width="{3.2 * k}" height="{1.0 * k}" rx="6" fill="{STONE}" stroke="{STONE_D}" transform="rotate(-6 {m(1.9)} {g2 - 0.7 * k})"/>')
    s.append(txt(m(3), g2 + 34, "З-1 Завал в арке 4 × 6 м", 13, TEXT, "middle", "600"))
    # З-2 portcullis
    s.append(f'<rect x="{m(8)}" y="{g2 - 8 * k}" width="{6 * k}" height="{8 * k}" fill="{STONE}"/>')
    s.append(blocks(m(8), g2 - 8 * k, 6, 8, k))
    s.append(f'<path d="{arch_path(m(11), g2, 4, 6, k)}" fill="#0d0a0c"/>')
    s.append(f'<ellipse cx="{m(11)}" cy="{g2 - 2.5 * k}" rx="{1.4 * k}" ry="{2 * k}" fill="url(#warm)" opacity="0.5"/>')
    bx = 9.2
    while bx < 12.9:
        s.append(f'<line x1="{m(bx)}" y1="{g2 - 5.8 * k}" x2="{m(bx)}" y2="{g2 - 0.15 * k}" stroke="{IRON}" stroke-width="5"/>')
        s.append(f'<path d="M{m(bx) - 4},{g2 - 0.3 * k} L{m(bx)},{g2} L{m(bx) + 4},{g2 - 0.3 * k} Z" fill="#8f857a"/>')
        bx += 0.45
    for hy in (1.6, 3.4, 5.0):
        s.append(f'<line x1="{m(9.0)}" y1="{g2 - hy * k}" x2="{m(13.0)}" y2="{g2 - hy * k}" stroke="{IRON}" stroke-width="6"/>')
    s.append(txt(m(11), g2 + 54, "З-2 Опущенная решётка", 13, TEXT, "middle", "600"))
    # З-3 collapsed stair
    s.append(f'<rect x="{m(16)}" y="{g2 - 10 * k}" width="{10 * k}" height="{10 * k}" fill="{STONE}" opacity="0.65"/>')
    s.append(f'<path d="{arch_path(m(24.5), g2 - 6 * k, 2.2, 3.4, k)}" fill="#0d0a0c"/>')
    s.append(f'<rect x="{m(22.6)}" y="{g2 - 6 * k}" width="{3.4 * k}" height="{0.4 * k}" fill="{STONE_L}"/>')
    lower = [f"{m(16.4)},{g2}"]
    for i in range(5):
        lower += [f"{m(16.4 + i)},{g2 - (i + 1) * 0.5 * k}", f"{m(17.4 + i)},{g2 - (i + 1) * 0.5 * k}"]
    lower += [f"{m(21.0)},{g2 - 1.6 * k}", f"{m(20.6)},{g2}"]
    s.append(f'<polygon points="{" ".join(lower[:8])} {m(19.6)},{g2 - 1.3 * k} {m(19.9)},{g2}" fill="{STONE_L}"/>')
    s.append(f'<polygon points="{m(23.6)},{g2 - 6 * k} {m(23.6)},{g2 - 5.6 * k} {m(22.9)},{g2 - 5.2 * k} {m(22.2)},{g2 - 5.6 * k} {m(22.6)},{g2 - 6 * k}" fill="{STONE_L}"/>')
    for (bx_, bw_, bh_, rot) in [(20.2, 1.2, 0.6, 12), (21.5, 0.9, 0.5, -20), (22.4, 1.4, 0.7, 6), (24.0, 0.8, 0.4, 30)]:
        s.append(f'<rect x="{m(bx_)}" y="{g2 - bh_ * k}" width="{bw_ * k}" height="{bh_ * k}" fill="{STONE_L}" stroke="{STONE_D}" transform="rotate({rot} {m(bx_ + bw_ / 2):.1f} {g2 - bh_ * k / 2:.1f})"/>')
    s.append(f'<path d="M{m(19.6)},{g2 - 1.6 * k} L{m(22.6)},{g2 - 5.6 * k}" stroke="{MUTED}" stroke-width="1.5" stroke-dasharray="4 5"/>')
    s.append(txt(m(21), g2 + 34, "З-3 Обрушенная лестница на галерею +6 м", 13, TEXT, "middle", "600"))
    s.append(hero(m(27.5), g2, k))
    ly2 = 500
    for i, t in enumerate(["Каждый проход виден, читается как «потом»",
                           "и не требует ключа в S.",
                           "З-1 — двор (к Кузнице, V2), З-2 — зал",
                           "(к Темнице, V3), З-3 — двор (к Башне, V3).",
                           "В следующем визите заглушку заменяет",
                           "открытая версия того же модуля.",
                           "",
                           "Коллизия — сплошная, без щелей:",
                           "решётка не пропускает даже взгляд камеры",
                           "дальше 1 м (тёмный объём за ней)."]):
        s.append(txt(800, ly2 + i * 20, t, 12, MUTED))
    s.append("</svg>\n")
    return "".join(s)


# ---------------------------------------------------------------- sheet 2: seal


def sheet_seal() -> str:
    W, H = 1200, 700
    s = [head(W, H, "Печать с тремя кольцами и штурвалы",
              "Концепт DB-П. Диск Ø 8 м, три кольца, три штурвала. Пунктирные гнёзда — место под знаки из #188 (здесь не рисуются). Белое (Б-5) — трещина, ядро, метка.")]
    k = 36
    cx, cy = 320, 380
    rings = [(4.0, 2.9, "#4a4044"), (2.9, 1.9, "#423a3e"), (1.9, 1.0, "#3a3236")]
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{4.4 * k}" fill="#1f1a1d" stroke="{BRONZE}" stroke-width="2"/>')
    offsets = [0, 60, 120]  # crack misaligned: rings rotated
    for i, (ro, ri, col) in enumerate(rings):
        s.append(f'<circle cx="{cx}" cy="{cy}" r="{(ro + ri) / 2 * k}" fill="none" stroke="{col}" stroke-width="{(ro - ri) * k - 3}"/>')
        s.append(f'<circle cx="{cx}" cy="{cy}" r="{ro * k}" fill="none" stroke="{BRONZE_L}" stroke-width="2"/>')
        for j in range(6):
            a = math.radians(-90 + j * 60 + offsets[i] + 30)
            x1, y1 = cx + ri * k * math.cos(a), cy + ri * k * math.sin(a)
            x2, y2 = cx + ro * k * math.cos(a), cy + ro * k * math.sin(a)
            s.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{BRONZE}" stroke-width="1.5"/>')
            am = math.radians(-90 + j * 60 + offsets[i])
            rm = (ro + ri) / 2 * k
            tx, ty = cx + rm * math.cos(am), cy + rm * math.sin(am)
            sz = 0.62 * k if i < 2 else 0.5 * k
            s.append(f'<rect x="{tx - sz / 2:.1f}" y="{ty - sz / 2:.1f}" width="{sz:.1f}" height="{sz:.1f}" rx="4" fill="#1f1a1d" stroke="#d8cfc2" stroke-width="1" stroke-dasharray="3 2"/>')
        # crack segment of this ring, at its own rotation
        a = math.radians(-90 + offsets[i] + 12)
        x1, y1 = cx + ri * k * math.cos(a), cy + ri * k * math.sin(a)
        x2, y2 = cx + ro * k * math.cos(a), cy + ro * k * math.sin(a)
        s.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{WHITE}" stroke-width="4" filter="url(#glow)"/>')
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{1.0 * k}" fill="#2a2428" stroke="{BRONZE_L}" stroke-width="2"/>')
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{0.55 * k}" fill="{WHITE}" opacity="0.9" filter="url(#glow)"/>')
    s.append(f'<path d="M{cx - 9},{cy - 4.55 * k} L{cx + 9},{cy - 4.55 * k} L{cx},{cy - 4.1 * k} Z" fill="{WHITE}" filter="url(#glow)"/>')
    s.append(txt(cx + 16, cy - 4.5 * k, "метка чтения", 12, TEXT))
    for i, ang in enumerate((150, 90, 30)):
        a = math.radians(ang)
        px, py = cx + 5.0 * k * math.cos(a), cy + 5.0 * k * math.sin(a)
        s.append(f'<rect x="{px - 0.5 * k:.1f}" y="{py - 0.3 * k:.1f}" width="{1.0 * k}" height="{0.6 * k}" fill="{STONE_L}" stroke="{BRONZE_L}" transform="rotate({ang - 90} {px:.1f} {py:.1f})"/>')
        s.append(txt(px, py + 0.75 * k + 8, f"Ш-{i + 1}", 12, TEXT, "middle", "600"))
    s.append(txt(cx, cy + 6.9 * k, "План. Сейчас трещина разорвана: кольца сбиты на 60° и 120°.", 12, MUTED, "middle"))

    # section
    k2 = 40
    g = 600
    x0 = 640
    m = lambda v: x0 + v * k2  # noqa: E731
    s.append(f'<rect x="{m(3.2)}" y="100" width="{1.6 * k2}" height="{g - 100 - 0.9 * k2}" fill="url(#whiteg)" opacity="0.55"/>')
    s.append(txt(m(4) + 40, 120, "столб света сверху (объёмный туман + SpotLight)", 12, MUTED))
    s.append(ground(x0 - 20, 1170, g))
    s.append(f'<rect x="{m(0)}" y="{g - 0.3 * k2}" width="{8 * k2}" height="{0.3 * k2}" fill="#1f1a1d" stroke="{BRONZE}"/>')
    for (a, b, h, col) in [(0, 1.1, 0.45, "#4a4044"), (6.9, 8, 0.45, "#4a4044"), (1.1, 2.1, 0.6, "#423a3e"),
                           (5.9, 6.9, 0.6, "#423a3e"), (2.1, 3.0, 0.75, "#3a3236"), (5.0, 5.9, 0.75, "#3a3236")]:
        s.append(f'<rect x="{m(a)}" y="{g - h * k2}" width="{(b - a) * k2}" height="{(h - 0.3) * k2}" fill="{col}" stroke="{BRONZE_L}" stroke-width="1.5"/>')
    s.append(f'<path d="M{m(3.0)},{g - 0.75 * k2} Q{m(4)},{g - 1.5 * k2} {m(5.0)},{g - 0.75 * k2} Z" fill="#2a2428" stroke="{BRONZE_L}"/>')
    s.append(f'<ellipse cx="{m(4)}" cy="{g - 1.0 * k2}" rx="{0.45 * k2}" ry="{0.22 * k2}" fill="{WHITE}" filter="url(#glow)"/>')
    # wheel lever
    wx = m(9.3)
    s.append(f'<rect x="{wx - 0.3 * k2}" y="{g - 1.0 * k2}" width="{0.6 * k2}" height="{1.0 * k2}" fill="{STONE_L}"/>')
    s.append(f'<circle cx="{wx}" cy="{g - 1.6 * k2}" r="{0.6 * k2}" fill="none" stroke="{IRON}" stroke-width="7"/>')
    s.append(f'<circle cx="{wx}" cy="{g - 1.6 * k2}" r="{0.6 * k2}" fill="none" stroke="{BRONZE_L}" stroke-width="2"/>')
    for j in range(6):
        a = math.radians(j * 60)
        s.append(f'<line x1="{wx}" y1="{g - 1.6 * k2}" x2="{wx + 0.6 * k2 * math.cos(a):.1f}" y2="{g - 1.6 * k2 + 0.6 * k2 * math.sin(a):.1f}" stroke="{IRON}" stroke-width="4"/>')
        s.append(f'<path d="M{wx + 0.6 * k2 * math.cos(a):.1f},{g - 1.6 * k2 + 0.6 * k2 * math.sin(a):.1f} l{0.18 * k2 * math.cos(a):.1f},{0.18 * k2 * math.sin(a):.1f}" stroke="{SPIKE}" stroke-width="4" stroke-linecap="round"/>')
    s.append(f'<circle cx="{wx}" cy="{g - 1.6 * k2}" r="7" fill="{BRONZE_L}"/>')
    s.append(hero(m(10.6), g, k2))
    s.append(txt(m(4), g + 30, "Разрез: диск 8 м, кольца ступенями 0,45 / 0,6 / 0,75 м, ядро — купол 1,2 м", 12, MUTED, "middle"))
    s.append(txt(wx - 0.9 * k2, g - 2.6 * k2, "штурвал Ø 1,2 м,", 12, TEXT, "end"))
    s.append(txt(wx - 0.9 * k2, g - 2.6 * k2 + 15, "ось 1,6 м", 12, TEXT, "end"))
    notes = ["Узлы: Ring1..3 (пивот в центре, шаг 360°/N), Wheel1..3,", "Emit_Crack1..3, Emit_Core, Glyph_*.",
             "Гнёзда знаков — вставки под атлас-декаль из #188;", "число положений (6 или 8) — по З-5 #188.",
             "Бюджет «героя»: до 25 000 тр. на диск со штурвалами;", "текстуры 2048² только для DT-08."]
    for i, t in enumerate(notes):
        s.append(txt(640, 160 + i * 19, t, 12, MUTED))
    s.append("</svg>\n")
    return "".join(s)


# ---------------------------------------------------------------- sheet 3: remains of the world's hero + operator death trace
def niche(x0, g, k, lit: bool) -> str:
    m = lambda v: x0 + v * k  # noqa: E731
    s = []
    s.append(f'<rect x="{m(0)}" y="{g - 7 * k}" width="{6 * k}" height="{7 * k}" fill="{STONE}"/>')
    s.append(blocks(m(0), g - 7 * k, 6, 7, k))
    s.append(f'<path d="{arch_path(m(3), g, 4, 5, k)}" fill="#120e10"/>')
    if lit:
        s.append(f'<circle cx="{m(5.6)}" cy="{g - 1.6 * k}" r="{2.6 * k}" fill="url(#warm)"/>')
    # hero of this world: slumped under a torn cloak, faceless, one gloved hand out
    cloak = "#3a2226" if not lit else "#4a2a2e"
    s.append(f'<path d="M{m(1.5)},{g} Q{m(1.45)},{g - 0.9 * k} {m(1.9)},{g - 1.45 * k} Q{m(2.3)},{g - 1.75 * k} {m(2.75)},{g - 1.35 * k} '
             f'Q{m(3.1)},{g - 0.8 * k} {m(3.2)},{g} Z" fill="{cloak}" stroke="#1a1214"/>')
    s.append(f'<path d="M{m(1.7)},{g} l{0.15 * k},{-0.25 * k} l{0.12 * k},{0.25 * k} l{0.15 * k},{-0.2 * k} l{0.1 * k},{0.2 * k}" fill="#120e10"/>')
    bone = "#8a8076" if not lit else "#a39a90"
    s.append(f'<path d="M{m(2.95)},{g - 0.35 * k} L{m(3.6)},{g - 0.12 * k}" stroke="{bone}" stroke-width="5" stroke-linecap="round"/>')
    s.append(f'<ellipse cx="{m(3.72)}" cy="{g - 0.1 * k}" rx="{0.14 * k}" ry="{0.09 * k}" fill="#d8cfc2"/>')
    # head-gear lying apart: generic round cap with brim (own form)
    s.append(f'<path d="M{m(0.75)},{g} Q{m(0.75)},{g - 0.32 * k} {m(1.05)},{g - 0.32 * k} Q{m(1.35)},{g - 0.32 * k} {m(1.35)},{g} Z" fill="#6a2a24"/>')
    s.append(f'<path d="M{m(1.3)},{g} l{0.28 * k},{-0.04 * k} l0,{0.04 * k} Z" fill="#6a2a24"/>')
    # weapon beside him: chain + shackle weight
    chain_col = WHITE if lit else "#3d373a"
    filt = ' filter="url(#glow)"' if lit else ""
    pts = [(3.9, 0.1), (4.15, 0.07), (4.4, 0.06), (4.65, 0.08), (4.9, 0.06)]
    for i, (px, py) in enumerate(pts):
        s.append(f'<ellipse cx="{m(px)}" cy="{g - py * k}" rx="{0.15 * k}" ry="{0.06 * k if i % 2 else 0.035 * k}" fill="none" stroke="{chain_col}" stroke-width="2.5"{filt}/>')
    s.append(f'<circle cx="{m(4.6)}" cy="{g - 0.55 * k}" r="{0.2 * k}" fill="{IRON if not lit else "#2a2a30"}" stroke="{chain_col}" stroke-width="2"{filt}/>')
    s.append(f'<path d="M{m(4.6)},{g - 0.35 * k} Q{m(4.75)},{g - 0.15 * k} {m(4.9)},{g - 0.08 * k}" stroke="{chain_col}" stroke-width="2.5" fill="none"{filt}/>')
    # predecessor's note (text lives in data)
    s.append(f'<rect x="{m(2.1)}" y="{g - 0.06 * k}" width="{0.42 * k}" height="{0.06 * k}" fill="#b8ab96" transform="rotate(-4 {m(2.3)} {g})"/>')
    s.append(f'<path d="M{m(2.1)},{g - 0.06 * k} l{0.42 * k},{-0.22 * k}" stroke="#b8ab96" stroke-width="0" />')
    # brazier outside, right
    bx = m(5.4)
    s.append(f'<path d="M{bx - 0.35 * k},{g} L{bx},{g - 1.0 * k} L{bx + 0.35 * k},{g} M{bx},{g} L{bx},{g - 1.0 * k}" stroke="{IRON}" stroke-width="4" fill="none"/>')
    s.append(f'<path d="M{bx - 0.5 * k},{g - 1.0 * k} L{bx + 0.5 * k},{g - 1.0 * k} L{bx + 0.35 * k},{g - 1.3 * k} L{bx - 0.35 * k},{g - 1.3 * k} Z" fill="{IRON}" stroke="{BRONZE}"/>')
    s.append(spikes_row(bx - 0.5 * k, bx + 0.5 * k, g - 1.3 * k, k, 0.18, 0.25, "#8f857a"))
    if lit:
        s.append(f'<path d="M{bx - 0.3 * k},{g - 1.3 * k} Q{bx - 0.2 * k},{g - 1.9 * k} {bx},{g - 2.1 * k} Q{bx + 0.1 * k},{g - 1.7 * k} {bx + 0.3 * k},{g - 1.3 * k} Z" fill="{EMBER}" filter="url(#glow)"/>')
    # fallen column, diagonal, in front-left
    s.append(f'<rect x="{m(-0.6)}" y="{g - 0.9 * k}" width="{2.0 * k}" height="{0.9 * k}" rx="4" fill="{STONE_L}" stroke="{STONE_D}" transform="rotate(-14 {m(0.4)} {g - 0.45 * k})"/>')
    return "".join(s)


def trace(cx, cy, r, kind: str) -> str:
    """Operator death trace on the floor, plan view (circle radius r px)."""
    s = [f'<circle cx="{cx}" cy="{cy}" r="{r * 1.6:.1f}" fill="#2b2427"/>']
    if kind == "a":  # glassy white crack spot, faint
        s.append(f'<circle cx="{cx}" cy="{cy}" r="{r * 0.55:.1f}" fill="{WHITE}" opacity="0.18"/>')
        for j in range(7):
            a = math.radians(j * 51 + 10)
            l = r * (0.7 + 0.3 * ((j * 37) % 5) / 4)
            s.append(f'<path d="M{cx},{cy} l{l * math.cos(a):.1f},{l * math.sin(a):.1f} l{0.3 * l * math.cos(a + 0.6):.1f},{0.3 * l * math.sin(a + 0.6):.1f}" stroke="{WHITE}" stroke-width="1.2" fill="none" opacity="0.75"/>')
    elif kind == "b":  # body-shaped pale imprint
        s.append(f'<ellipse cx="{cx}" cy="{cy - r * 0.7:.1f}" rx="{r * 0.22:.1f}" ry="{r * 0.22:.1f}" fill="{WHITE}" opacity="0.22"/>')
        s.append(f'<path d="M{cx - r * 0.3:.1f},{cy - r * 0.45:.1f} L{cx + r * 0.3:.1f},{cy - r * 0.45:.1f} L{cx + r * 0.2:.1f},{cy + r * 0.9:.1f} L{cx - r * 0.2:.1f},{cy + r * 0.9:.1f} Z" fill="{WHITE}" opacity="0.22"/>')
    else:  # scattered white shards
        for j in range(9):
            a = math.radians(j * 40 + 7)
            d = r * (0.3 + 0.8 * ((j * 53) % 7) / 6)
            x, y = cx + d * math.cos(a), cy + d * math.sin(a)
            s.append(f'<path d="M{x:.1f},{y - 4:.1f} l3,4 l-3,4 l-3,-4 Z" fill="{WHITE}" opacity="0.8"/>')
    return "".join(s)


def sheet_niche() -> str:
    W, H = 1200, 920
    s = [head(W, H, "Останки героя мира, его оружие, записка, жаровня · след гибели оператора",
              "Концепт DB-Н по решению автора в #186. Ниша 4 × 3 м в СЗ углу двора: слева до засады, справа отклик. Внизу — след гибели оператора сразу за WakeLine.")]
    k, g = 48, 520
    s.append(ground(40, 1170, g))
    s.append(niche(70, g, k, False))
    s.append(niche(420, g, k, True))
    s.append(txt(70 + 3 * k, g + 30, "До засады: всё тёмное, цепь — часть декора", 13, TEXT, "middle", "600"))
    s.append(txt(420 + 3 * k, g + 30, "Отклик: цепь белая, жаровня тёплая", 13, TEXT, "middle", "600"))
    s.append(hero(420 + 6.9 * k, g, k))
    vx, vy = 790, 120
    s.append(txt(vx, vy, "Как показать героя мира — решение Д-3", 15, TEXT, "start", "700"))
    for i, t in enumerate(["а. Узнаваемый герой-соперник целиком (силуэт,",
                           "   одежда). Сильнейший фан-мотив, риск О-10, жёстко.",
                           "б. Останки под истлевшим плащом, лица нет; один",
                           "   узнаваемый мотив — головной убор рядом.  РЕКОМ.",
                           "в. Только вещи: убор, плащ, оружие. Нейтрально,",
                           "   «герой» читается слабо — держится на записке."]):
        s.append(txt(vx, vy + 24 + i * 18, t, 12, TEXT if t.startswith(("а", "б", "в")) else MUTED))
    s.append(txt(vx, vy + 152, "Груз на цепи — решение Д-4", 15, TEXT, "start", "700"))
    kk = 110
    gy = vy + 215
    s.append(f'<circle cx="{vx + 40}" cy="{gy}" r="{0.2 * kk}" fill="{IRON}" stroke="#5a5254" stroke-width="2"/>')
    s.append(f'<ellipse cx="{vx + 40}" cy="{gy - 30}" rx="{0.08 * kk}" ry="{0.1 * kk}" fill="none" stroke="#5a5254" stroke-width="4"/>')
    s.append(txt(vx + 40, gy + 42, "а. Кандальная гиря", 12, TEXT, "middle", "600"))
    s.append(txt(vx + 40, gy + 57, "РЕКОМ.: оковы, не оружие", 11, MUTED, "middle"))
    bx = vx + 175
    s.append(f'<circle cx="{bx}" cy="{gy}" r="{0.18 * kk}" fill="{IRON}" stroke="#5a5254" stroke-width="2"/>')
    for j in range(8):
        a = math.radians(j * 45)
        x1, y1 = bx + 0.18 * kk * math.cos(a), gy + 0.18 * kk * math.sin(a)
        x2, y2 = bx + 0.3 * kk * math.cos(a), gy + 0.3 * kk * math.sin(a)
        s.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{SPIKE}" stroke-width="4" stroke-linecap="round"/>')
    s.append(txt(bx, gy + 42, "б. Шипастое ядро", 12, TEXT, "middle", "600"))
    s.append(txt(bx, gy + 57, "слишком явное", 11, MUTED, "middle"))
    cx = vx + 305
    s.append(f'<path d="M{cx - 30},{gy + 14} Q{cx},{gy - 36} {cx + 30},{gy + 14} Z" fill="{GREEN}" stroke="#5a5254" stroke-width="2"/>')
    s.append(f'<rect x="{cx - 32}" y="{gy + 12}" width="64" height="7" fill="#d8cfc2"/>')
    s.append(spikes_row(cx - 22, cx + 22, gy - 6, 30, 0.45, 0.6))
    s.append(txt(cx, gy + 42, "в. Гиря-панцирь", 12, TEXT, "middle", "600"))
    s.append(txt(cx, gy + 57, "вещь хозяина", 11, MUTED, "middle"))
    notes = ["Записка предшественника — лист DT-10 у руки;",
             "текст только в данных (#186), в модели надписей нет.",
             "Цепь: звенья 0,15 м, длина 1,6 м, груз Ø 0,4 м.",
             "Узлы: Body, WeaponSpot/Chain, Emit_Chain, Note, Brazier/Fire.",
             "Бюджет: останки до 6 000 тр., цепь до 1 500, жаровня до 2 000."]
    for i, t in enumerate(notes):
        s.append(txt(vx, gy + 92 + i * 19, t, 12, MUTED))

    # operator death trace
    ty = 600
    s.append(f'<line x1="40" y1="{ty}" x2="1160" y2="{ty}" stroke="#3a3034"/>')
    s.append(txt(40, ty + 32, "След гибели оператора за WakeLine — решение Д-5", 16, TEXT, "start", "700"))
    s.append(txt(40, ty + 54, "Небольшой (≤ 1,2 м), без подписи. Игрок ещё не умирал и не знает, как это выглядит. Тот же след потом оставит смерть игрока —", 12, MUTED))
    s.append(txt(40, ty + 72, "так намёк «расшифровывается» задним числом. Белый (Б-5) — след связи с системой, а не кровь и не тело.", 12, MUTED))
    for i, (kind, a, b) in enumerate([("a", "а. Стеклянная трещина в камне, Ø 0,8 м", "тусклое белое мерцание; РЕКОМ."),
                                      ("b", "б. Бледный отпечаток силуэта", "читается сразу — подсказка слишком явная"),
                                      ("c", "в. Россыпь белых осколков", "легко спутать с искрами печати")]):
        x = 170 + i * 360
        s.append(trace(x, ty + 170, 45, kind))
        s.append(txt(x, ty + 258, a, 13, TEXT, "middle", "600"))
        s.append(txt(x, ty + 276, b, 12, MUTED, "middle"))
    s.append("</svg>\n")
    return "".join(s)


# ---------------------------------------------------------------- sheet 4: guardians
def guardian_a(cx, g, k) -> str:
    """Shell warrior, faces right, 2.6 m."""
    t = f'transform="translate({cx},{g}) scale({k},{-k})"'
    eye = f'<circle cx="{cx + 0.52 * k:.1f}" cy="{g - 2.12 * k:.1f}" r="3.5" fill="#ff7a2a" filter="url(#glow)"/>'
    return (f'<ellipse cx="{cx}" cy="{g - 1.3 * k}" rx="{1.0 * k}" ry="{1.4 * k}" fill="#3a1c18" opacity="0.45" filter="url(#soft)"/>'
            f'<g {t} fill="#120d10" stroke="#2a1a1c" stroke-width="0.02">'
            '<rect x="-0.45" y="0" width="0.32" height="0.95"/><rect x="0.12" y="0" width="0.32" height="0.95"/>'
            '<ellipse cx="0.05" cy="1.4" rx="0.55" ry="0.62"/>'
            '<ellipse cx="-0.32" cy="1.55" rx="0.62" ry="0.78"/>'
            '<path d="M0.2,1.85 Q0.55,2.05 0.8,1.95 L0.75,2.3 Q0.45,2.45 0.15,2.3 Z"/>'
            '<path d="M0.25,2.3 L0.15,2.62 L0.38,2.36 Z"/><path d="M0.5,2.35 L0.55,2.6 L0.66,2.32 Z"/>'
            '<rect x="0.3" y="0.95" width="0.28" height="0.8" transform="rotate(-12 0.44 1.35)"/>'
            '<circle cx="0.55" cy="0.95" r="0.17"/>'
            '</g>'
            f'<g {t} fill="#3a3234">'
            + "".join(f'<path d="M{-0.32 + 0.62 * math.cos(math.radians(a)):.2f},{1.55 + 0.78 * math.sin(math.radians(a)):.2f} l{0.22 * math.cos(math.radians(a)):.2f},{0.22 * math.sin(math.radians(a)):.2f} l{-0.08 * math.sin(math.radians(a)):.2f},{0.08 * math.cos(math.radians(a)):.2f} Z"/>' for a in (100, 125, 150, 175, 200))
            + '</g>' + eye)


def guardian_b(cx, g, k) -> str:
    """Bone guardian, 2.3 m, strokes."""
    st = 'stroke="#5a4e4a" fill="none" stroke-linecap="round"'
    def p(x, y):
        return f"{cx + x * k:.1f},{g - y * k:.1f}"
    return (f'<ellipse cx="{cx}" cy="{g - 1.2 * k}" rx="{0.9 * k}" ry="{1.2 * k}" fill="#3a1c18" opacity="0.35" filter="url(#soft)"/>'
            f'<path d="M{p(-0.3, 0)} L{p(-0.2, 0.9)} M{p(0.25, 0)} L{p(0.15, 0.9)}" {st} stroke-width="7"/>'
            f'<path d="M{p(-0.2, 0.95)} Q{p(-0.7, 1.5)} {p(-0.35, 1.95)} M{p(-0.1, 0.95)} L{p(0.1, 1.9)}" {st} stroke-width="6"/>'
            + "".join(f'<path d="M{p(0.05, 1.15 + i * 0.18)} q{0.3 * k:.1f},{-0.05 * k:.1f} {0.35 * k:.1f},{0.12 * k:.1f}" {st} stroke-width="4"/>' for i in range(4))
            + f'<path d="M{p(-0.75, 1.1)} Q{p(-0.95, 1.6)} {p(-0.55, 2.05)}" stroke="#4a4040" stroke-width="9" fill="none" stroke-dasharray="14 7"/>'
            f'<path d="M{p(0.0, 1.95)} Q{p(0.35, 2.3)} {p(0.65, 2.1)} L{p(0.6, 1.95)} Q{p(0.3, 1.88)} {p(0.0, 1.95)} Z" fill="#4a4040"/>'
            f'<path d="M{p(0.15, 1.92)} L{p(0.55, 1.82)}" {st} stroke-width="4"/>'
            f'<circle cx="{cx + 0.38 * k:.1f}" cy="{g - 2.08 * k:.1f}" r="3.5" fill="#ff7a2a" filter="url(#glow)"/>'
            f'<path d="M{p(0.15, 1.0)} L{p(0.55, 0.6)} L{p(0.5, 0.35)}" {st} stroke-width="5"/>')


def guardian_c(cx, g, k) -> str:
    """Empty armour, 2.8 m."""
    def p(x, y):
        return f"{cx + x * k:.1f},{g - y * k:.1f}"
    smoke = "".join(f'<ellipse cx="{cx + dx * k:.1f}" cy="{g - dy * k:.1f}" rx="{r * k:.1f}" ry="{r * 0.8 * k:.1f}" fill="#4a3440" opacity="0.5" filter="url(#soft)"/>'
                    for (dx, dy, r) in [(0, 2.25, 0.25), (0.1, 2.55, 0.2), (-0.1, 2.8, 0.15), (-0.5, 1.15, 0.15), (0.5, 1.15, 0.15)])
    return (f'<ellipse cx="{cx}" cy="{g - 1.4 * k}" rx="{1.0 * k}" ry="{1.5 * k}" fill="#3a1c18" opacity="0.4" filter="url(#soft)"/>'
            f'<path d="M{p(-0.35, 0)} L{p(-0.3, 1.1)} L{p(-0.08, 1.1)} L{p(-0.12, 0)} Z M{p(0.12, 0)} L{p(0.08, 1.1)} L{p(0.3, 1.1)} L{p(0.35, 0)} Z" fill="{IRON}" stroke="#3a3234"/>'
            f'<path d="M{p(-0.42, 1.15)} L{p(0.42, 1.15)} L{p(0.55, 2.0)} L{p(-0.55, 2.0)} Z" fill="{IRON}" stroke="#3a3234"/>'
            f'<path d="M{p(-0.55, 2.0)} Q{p(-0.95, 2.05)} {p(-0.9, 1.7)} L{p(-0.5, 1.75)} Z M{p(0.55, 2.0)} Q{p(0.95, 2.05)} {p(0.9, 1.7)} L{p(0.5, 1.75)} Z" fill="{IRON}" stroke="#3a3234"/>'
            f'<path d="M{p(-0.9, 1.75)} l{-0.15 * k:.1f},{-0.25 * k:.1f} M{p(0.9, 1.75)} l{0.15 * k:.1f},{-0.25 * k:.1f}" stroke="{SPIKE}" stroke-width="4" stroke-linecap="round"/>'
            f'<path d="M{p(-0.6, 1.8)} L{p(-0.7, 1.0)} M{p(0.6, 1.8)} L{p(0.7, 1.0)}" stroke="{IRON}" stroke-width="12" stroke-linecap="round"/>'
            f'<path d="M{p(-0.22, 2.05)} L{p(0.22, 2.05)} L{p(0.2, 2.45)} Q{p(0, 2.55)} {p(-0.2, 2.45)} Z" fill="{IRON}" stroke="#3a3234"/>'
            f'<line x1="{cx - 0.14 * k:.1f}" y1="{g - 2.3 * k:.1f}" x2="{cx + 0.14 * k:.1f}" y2="{g - 2.3 * k:.1f}" stroke="#ff7a2a" stroke-width="3" filter="url(#glow)"/>'
            + smoke)


def sheet_guardians() -> str:
    W, H = 1200, 620
    s = [head(W, H, "Стражи-тени: три варианта силуэта (решение Д-2)",
              "Концепт DB-С. Один тип стража на S. Материал «тень»: почти чёрный, дымный край, тлеющие глаза #ff7a2a. Белого на стражах нет — белый принадлежит печати.")]
    k, g = 90, 470
    s.append(ground(40, 1170, g))
    s.append(hero(120, g, k))
    s.append(guardian_a(360, g, k))
    s.append(guardian_b(640, g, k))
    s.append(guardian_c(920, g, k))
    for (x, a, b, c) in [(360, "а. Панцирный воин · 2,6 м", "Шипастый панцирь, рога, тяжёлые руки.", "Самый узнаваемый (Б-2). Реком."),
                         (640, "б. Костяной страж · 2,3 м", "Остов с обломками панциря.", "Мрачнее, хорошо в «тени»; читается хуже."),
                         (920, "в. Пустой доспех · 2,8 м", "Латы, внутри дым.", "Нейтральный, слабее связан с фан-образом.")]:
        s.append(txt(x, g + 34, a, 14, TEXT, "middle", "700"))
        s.append(txt(x, g + 54, b, 12, MUTED, "middle"))
        s.append(txt(x, g + 72, c, 12, MUTED, "middle"))
    s.append(txt(1160, g + 120, "Без скелета в S: цельный меш + шейдер дыма, движение — смещение и наклон (DreamEnemy). До 15 000 тр.", 12, MUTED, "end"))
    s.append("</svg>\n")
    return "".join(s)


# ---------------------------------------------------------------- sheet 5: sky stages
STAGES = [
    ("Спокойный сон", "после ресинхронизации, V2+", "#4a2436", "#c8642a", "#8a4a32", "#ff8a2a", 0.0),
    ("Тревога", "вход, S1–S2, S4 после печати", "#2e1622", "#9a3a22", "#6a2a1e", "#ff6a1a", 0.5),
    ("Беспокойство", "засада в S3", "#1c0c16", "#5a1a2a", "#4a1622", "#ff5a1a", 1.0),
    ("Предпробуждение", "смерть / высокая нестабильность", "#0c060c", "#2a0f1f", "#2a0f1f", "#ff3a12", 1.5),
]


def sheet_sky() -> str:
    W, H = 1200, 760
    s = [head(W, H, "Небо, туман и лава по стадиям нестабильности",
              "Концепт DB-Н1…Н4 — уточнение 04_mood_cards.svg. Цвет горизонта = цвет стадии из карточек. Меняются только свет, небо, туман, уровень лавы и частицы.")]
    pw, ph = 560, 300
    for i, (name, when, top, hor, fog, lava, rise) in enumerate(STAGES):
        x = 32 + (i % 2) * (pw + 24)
        y = 96 + (i // 2) * (ph + 28)
        gid = f"sky{i}"
        s.append(f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="0.75" stop-color="{hor}"/><stop offset="1" stop-color="{fog}"/></linearGradient>'
                 f'<clipPath id="c{i}"><rect x="{x}" y="{y}" width="{pw}" height="{ph}" rx="10"/></clipPath></defs>')
        s.append(f'<g clip-path="url(#c{i})">')
        s.append(f'<rect x="{x}" y="{y}" width="{pw}" height="{ph}" fill="url(#{gid})"/>')
        # volcano far
        s.append(f'<path d="M{x + 330},{y + 210} L{x + 420},{y + 120} L{x + 445},{y + 125} L{x + 540},{y + 210} Z" fill="{fog}" opacity="0.9"/>')
        s.append(f'<ellipse cx="{x + 432}" cy="{y + 112}" rx="40" ry="14" fill="{lava}" opacity="0.35" filter="url(#soft)"/>')
        # fortress silhouette
        fort = "#140c12"
        s.append(f'<path d="M{x + 60},{y + 230} L{x + 60},{y + 150} L{x + 80},{y + 150} L{x + 80},{y + 110} L{x + 100},{y + 110} L{x + 100},{y + 150} '
                 f'L{x + 150},{y + 150} L{x + 150},{y + 90} L{x + 162},{y + 70} L{x + 174},{y + 90} L{x + 174},{y + 150} L{x + 240},{y + 150} L{x + 240},{y + 125} '
                 f'L{x + 290},{y + 125} L{x + 290},{y + 230} Z" fill="{fort}"/>')
        for sx in range(66, 290, 14):
            top_y = 150 if not (80 <= sx <= 100 or 150 <= sx <= 174 or 240 <= sx <= 290) else (110 if 80 <= sx <= 100 else (90 if 150 <= sx <= 174 else 125))
            s.append(f'<path d="M{x + sx - 2},{y + top_y} L{x + sx},{y + top_y - 7} L{x + sx + 2},{y + top_y} Z" fill="{fort}"/>')
        # arch glow on bastion
        s.append(f'<rect x="{x + 255}" y="{y + 102}" width="18" height="23" rx="9" fill="{WHITE}" filter="url(#glow)"/>')
        # plateau + lava
        lava_y = y + 248 - rise * 14
        s.append(f'<rect x="{x}" y="{lava_y}" width="{pw}" height="{ph}" fill="{lava}"/>')
        s.append(f'<rect x="{x}" y="{lava_y - 22}" width="{pw}" height="30" fill="{lava}" opacity="0.35" filter="url(#soft)"/>')
        s.append(f'<path d="M{x},{y + 232} L{x + 300},{y + 228} L{x + 320},{y + 260} L{x},{y + 262} Z" fill="#100a0d"/>')
        s.append("</g>")
        s.append(f'<rect x="{x}" y="{y}" width="{pw}" height="{ph}" rx="10" fill="none" stroke="#5a4e48"/>')
        s.append(txt(x + 16, y + 28, name, 17, "#fffaf4", "start", "700"))
        s.append(txt(x + 16, y + 48, when, 12, "#efe7dc"))
        for j, (lab, c) in enumerate([("небо верх", top), ("горизонт", hor), ("туман", fog), ("лава", lava)]):
            sx = x + 330 + (j % 2) * 112
            sy = y + 18 + (j // 2) * 26
            s.append(f'<rect x="{sx}" y="{sy}" width="16" height="16" rx="3" fill="{c}" stroke="#fffaf4" stroke-opacity="0.5"/>')
            s.append(txt(sx + 22, sy + 13, f"{c}", 11, "#fffaf4"))
        s.append(txt(x + pw - 14, y + ph - 12, f"лава +{rise:.1f} м".replace(".", ","), 12, "#fffaf4", "end", "600"))
    s.append("</svg>\n")
    return "".join(s)


# ---------------------------------------------------------------- sheet 6: ledge, chain bridge, bastion arch
def sheet_bridge() -> str:
    W, H = 1200, 600
    s = [head(W, H, "Карниз, цепной мост, бастион и арка-врата",
              "Концепт DB-М, DB-А. Разрез по пути S2 и S5. Лава ниже моста на 8 м; падение = выталкивание (как сейчас в тестовом сне).")]
    k, g = 22, 380
    x0 = 50
    m = lambda v: x0 + v * k  # noqa: E731
    lava_y = g + 8 * k
    s.append(f'<rect x="20" y="{lava_y}" width="1160" height="{H - lava_y - 10}" fill="url(#lavag)"/>')
    s.append(f'<rect x="20" y="{lava_y - 30}" width="1160" height="40" fill="{LAVA}" opacity="0.3" filter="url(#soft)"/>')
    # ledge 14 m with 1.2 m step
    s.append(f'<path d="M{m(0)},{g + 1.2 * k} L{m(7)},{g + 1.2 * k} L{m(7)},{g} L{m(14)},{g} L{m(14)},{lava_y} L{m(0)},{lava_y} Z" fill="#1f171b"/>')
    s.append(f'<path d="M{m(0)},{g + 1.2 * k} L{m(7)},{g + 1.2 * k} L{m(7)},{g} L{m(14)},{g}" stroke="{STONE_L}" stroke-width="3" fill="none"/>')
    s.append(txt(m(7), g - 12, "уступ 1,2 м (перелезание)", 12, TEXT, "middle"))
    s.append(hero(m(4), g + 1.2 * k, k))
    # bridge 16 m
    bx0, bx1 = 14, 30
    for px in (bx0 + 0.3, bx1 - 0.3):
        s.append(f'<rect x="{m(px) - 0.3 * k}" y="{g - 5 * k}" width="{0.6 * k}" height="{5 * k}" fill="{IRON}" stroke="{BRONZE}"/>')
        s.append(f'<path d="M{m(px) - 0.3 * k},{g - 5 * k} L{m(px)},{g - 6 * k} L{m(px) + 0.3 * k},{g - 5 * k} Z" fill="{SPIKE}"/>')
    sag = 1.0
    deck = f"M{m(bx0)},{g} Q{m((bx0 + bx1) / 2)},{g + 2 * sag * k} {m(bx1)},{g}"
    s.append(f'<path d="{deck}" stroke="#4a4044" stroke-width="9" fill="none"/>')
    s.append(f'<path d="{deck}" stroke="{IRON}" stroke-width="3" fill="none" stroke-dasharray="10 4"/>')
    rail = f"M{m(bx0 + 0.3)},{g - 4.6 * k} Q{m((bx0 + bx1) / 2)},{g - 0.6 * k} {m(bx1 - 0.3)},{g - 4.6 * k}"
    s.append(f'<path d="{rail}" stroke="#6b6064" stroke-width="3" fill="none" stroke-dasharray="7 3"/>')
    for i in range(1, 8):
        t = i / 8
        xx = (1 - t) ** 2 * (bx0 + 0.3) + 2 * (1 - t) * t * (bx0 + bx1) / 2 + t ** 2 * (bx1 - 0.3)
        yr = (1 - t) ** 2 * (-4.6) + 2 * (1 - t) * t * (-0.6) + t ** 2 * (-4.6)
        yd = 2 * (1 - t) * t * 2 * sag
        s.append(f'<line x1="{m(xx):.1f}" y1="{g + yr * k:.1f}" x2="{m(xx):.1f}" y2="{g + yd * k:.1f}" stroke="#5a5054" stroke-width="1.5"/>')
    s.append(txt(m(22), g + 3.2 * k, "цепной мост 16 м, ширина 2 м, провис 1 м", 12, TEXT, "middle"))
    s.append(txt(m(22), g + 3.2 * k + 16, "настил — кованые плиты, перила — цепи", 11, MUTED, "middle"))
    # courtyard edge
    s.append(f'<path d="M{m(30)},{g} L{m(34)},{g} L{m(34)},{lava_y} L{m(30)},{lava_y} Z" fill="#1f171b"/>')
    s.append(txt(m(32), g - 12, "к двору", 12, MUTED, "middle"))
    # bastion with arch, right
    bk = 22
    bxs = 830
    bg = g
    mb = lambda v: bxs + v * bk  # noqa: E731
    s.append(f'<path d="M{mb(0)},{bg} L{mb(14)},{bg} L{mb(14)},{lava_y} L{mb(0)},{lava_y} Z" fill="#1f171b"/>')
    s.append(f'<path d="M{mb(0)},{bg} L{mb(14)},{bg}" stroke="{STONE_L}" stroke-width="3"/>')
    for sx in (0, 13):
        s.append(f'<rect x="{mb(sx)}" y="{bg - 1.2 * bk}" width="{1 * bk}" height="{1.2 * bk}" fill="{STONE_L}"/>')
    ax = mb(7)
    s.append(f'<circle cx="{ax}" cy="{bg - 3.5 * bk}" r="{3.6 * bk}" fill="url(#whiteg)"/>')
    s.append(f'<path d="{arch_path(ax, bg, 7.0, 9.0, bk)}" fill="{IRON}"/>')
    s.append(f'<path d="{arch_path(ax, bg, 4.0, 6.5, bk)}" fill="{WHITE}" filter="url(#glow)"/>')
    for side in (-1, 1):
        for j in range(4):
            yy = bg - (1.5 + j * 1.8) * bk
            s.append(f'<ellipse cx="{ax + side * 3.1 * bk:.1f}" cy="{yy:.1f}" rx="5" ry="9" fill="none" stroke="#6b6064" stroke-width="3"/>')
    s.append(spikes_row(ax - 3.5 * bk * 0.6, ax + 3.5 * bk * 0.6, bg - 9.0 * bk + 6, bk, 0.8, 1.2))
    s.append(hero(mb(11.5), bg, bk))
    s.append(txt(ax - 40, bg + 50, "Бастион 10 × 8 м. Арка — общий силуэт врат снов (DreamGate)", 12, TEXT, "middle"))
    s.append(txt(ax - 40, bg + 66, "+ накладки сна Боузера: чёрный металл, цепи, шипы. Проём 4 × 6,5 м — белый.", 12, MUTED, "middle"))
    s.append("</svg>\n")
    return "".join(s)


SHEETS = {
    "01_fortress_kit.svg": sheet_kit,
    "02_seal_rings.svg": sheet_seal,
    "03_remains_hero_trace.svg": sheet_niche,
    "04_guardians.svg": sheet_guardians,
    "05_sky_stages.svg": sheet_sky,
    "06_bridge_bastion.svg": sheet_bridge,
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in SHEETS.items():
        (OUT / name).write_text(fn(), encoding="utf-8")
        print(name)
