#!/usr/bin/env python3
"""Generates the decal atlases and screen textures of docs/art/texture-catalog.md (section 3).

Usage: python3 tools/props/make_decals.py [--out loads/textures]
Writes PNG atlases plus <atlas>.json with UV rectangles (u0, v0, u1, v1; v measured from the top, as in image space).
Fonts: DejaVu Sans / Mono (free licence), checked in by the OS, never bundled.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import texlib as T  # noqa: E402

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def centered(d, box, text, fnt, fill):
    """Draws (possibly multi-line) text centred in box; the font shrinks until every line fits the box width."""
    x0, y0, x1, y1 = box
    lines = text.split("\n")
    maxw, maxh = (x1 - x0) * 0.92, (y1 - y0) * 0.92
    size = fnt.size
    while True:
        f = ImageFont.truetype(fnt.path, size)
        boxes = [d.textbbox((0, 0), ln, font=f) for ln in lines]
        total_h = sum(b[3] - b[1] for b in boxes) + (len(lines) - 1) * size * 0.25
        if (max(b[2] - b[0] for b in boxes) <= maxw and total_h <= maxh) or size <= 10:
            break
        size -= 2
    y = (y0 + y1 - total_h) / 2
    for ln, b in zip(lines, boxes):
        d.text(((x0 + x1 - (b[2] - b[0])) / 2 - b[0], y - b[1]), ln, font=f, fill=fill)
        y += b[3] - b[1] + size * 0.25


def weather(img: Image.Image, seed: int, strength: float = 1.0, edge: float = 0.0) -> Image.Image:
    """Dirt, scratches and edge wear applied to an RGBA image; keeps the alpha channel."""
    w, h = img.size
    n = max(w, h)
    arr = np.asarray(img.convert("RGBA"), np.float32) / 255.0
    g = np.asarray(Image.fromarray((T.fbm(seed, 2.4, size=n) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS), np.float32) / 255.0
    streak = np.asarray(Image.fromarray((T.fbm(seed + 1, 2.2, size=n, stretch=(1.0, 0.05)) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS), np.float32) / 255.0
    scr = np.asarray(Image.fromarray((T.lines(seed + 2, max(40, n // 6), (20, n // 5), 1.0, 0.5, 0.0, size=n) * 255).astype(np.uint8)).resize((w, h), Image.LANCZOS), np.float32) / 255.0
    dirt = np.clip(0.55 + 0.9 * (g - 0.5) - 0.35 * streak, 0.2, 1.0) ** (1.0 + 0.3 * strength)
    arr[..., :3] = arr[..., :3] * (0.55 + 0.45 * dirt[..., None] / max(float(dirt.max()), 1e-6))
    arr[..., :3] = np.clip(arr[..., :3] * (1.0 - 0.25 * scr[..., None] * strength) + scr[..., None] * 0.05, 0, 1)
    if edge > 0:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        d = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
        arr[..., 3] *= np.clip(0.55 + d / max(edge, 1e-3), 0, 1) * (0.85 + 0.15 * g)
    return Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def arrow(d, cx, cy, size, direction, fill):
    s = size
    if direction == "right":
        pts = [(cx - s, cy - s * 0.25), (cx + s * 0.1, cy - s * 0.25), (cx + s * 0.1, cy - s * 0.65), (cx + s, cy),
               (cx + s * 0.1, cy + s * 0.65), (cx + s * 0.1, cy + s * 0.25), (cx - s, cy + s * 0.25)]
    else:
        pts = [(cx + s, cy - s * 0.25), (cx - s * 0.1, cy - s * 0.25), (cx - s * 0.1, cy - s * 0.65), (cx - s, cy),
               (cx - s * 0.1, cy + s * 0.65), (cx - s * 0.1, cy + s * 0.25), (cx + s, cy + s * 0.25)]
    d.polygon(pts, fill=fill)


def stripes(d, box, period, fill_a, fill_b):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=fill_a)
    h = y1 - y0
    x = x0 - h
    while x < x1 + h:
        d.polygon([(x, y1), (x + period / 2, y1), (x + period / 2 + h, y0), (x + h, y0)], fill=fill_b)
        x += period
    return


# ---------------------------------------------------------------- signs
GREEN, RED, YEL, BLK, WHT = (22, 92, 52), (150, 34, 26), (176, 140, 22), (22, 20, 17), (226, 224, 214)


def sign(kind: str, text: str, w=512, h=256) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 6
    box = (pad, pad, w - pad, h - pad)
    if kind in ("exit_l", "exit_r", "exit", "aid"):
        d.rounded_rectangle(box, 18, fill=GREEN)
        d.rounded_rectangle((pad + 8, pad + 8, w - pad - 8, h - pad - 8), 12, outline=WHT, width=4)
        if kind == "exit":
            centered(d, (box[0], box[1] + 20, box[2], box[3] - 20), text, font(FONT_BOLD, 96), WHT)
        elif kind == "aid":
            cx, cy = w * 0.22, h / 2
            d.rectangle((cx - 14, cy - 50, cx + 14, cy + 50), fill=WHT)
            d.rectangle((cx - 50, cy - 14, cx + 50, cy + 14), fill=WHT)
            centered(d, (w * 0.40, box[1], box[2] - 14, box[3]), text, font(FONT_BOLD, 64), WHT)
        else:
            direction = "left" if kind == "exit_l" else "right"
            ax = w * (0.17 if direction == "left" else 0.83)
            arrow(d, ax, h / 2, 62, direction, WHT)
            tb = (w * 0.34, box[1], w * 0.97, box[3]) if direction == "left" else (box[0] + 14, box[1], w * 0.66, box[3])
            centered(d, tb, text, font(FONT_BOLD, 68), WHT)
    elif kind == "danger":
        d.rectangle(box, fill=YEL)
        stripes(d, (pad, pad, w - pad, 60), 56, YEL, BLK)
        stripes(d, (pad, h - 60, w - pad, h - pad), 56, YEL, BLK)
        centered(d, (pad, 60, w - pad, h - 60), text, font(FONT_BOLD, 76 if len(text) < 8 else 44), BLK)
    elif kind == "voltage":
        d.rectangle(box, fill=YEL)
        d.rectangle((pad + 6, pad + 6, w - pad - 6, h - pad - 6), outline=BLK, width=5)
        bolt = [(120, 40), (80, 140), (115, 140), (92, 216), (170, 108), (130, 108), (160, 40)]
        d.polygon(bolt, fill=BLK)
        centered(d, (190, pad + 10, w - pad - 10, h - pad - 10), text, font(FONT_BOLD, 54), BLK)
    elif kind == "stop":
        d.rectangle(box, fill=RED)
        d.rectangle((pad + 8, pad + 8, w - pad - 8, h - pad - 8), outline=WHT, width=5)
        centered(d, box, text, font(FONT_BOLD, 62 if len(text) < 12 else 46), WHT)
    elif kind == "plate":
        d.rounded_rectangle(box, 10, fill=(48, 50, 54))
        d.rounded_rectangle((pad + 6, pad + 6, w - pad - 6, h - pad - 6), 8, outline=(150, 150, 146), width=3)
        centered(d, box, text, font(FONT_BOLD, 70 if len(text) < 11 else 52), (205, 203, 192))
    elif kind == "module":
        d.rectangle(box, fill=(40, 42, 46))
        d.rectangle((pad, pad, w - pad, pad + 44), fill=YEL)
        centered(d, (pad, pad, w - pad, pad + 44), "МОДУЛЬ", font(FONT_BOLD, 34), BLK)
        centered(d, (pad, pad + 44, w - pad, h - pad), text, font(FONT_BOLD, 130), (214, 212, 200))
    return img


SIGNS = [
    ("exit", "ВЫХОД", "exit"), ("evac_left", "ЭВАКУАЦИЯ", "exit_l"), ("evac_right", "ЭВАКУАЦИЯ", "exit_r"), ("first_aid", "АПТЕЧКА", "aid"),
    ("danger", "ОПАСНО", "danger"), ("high_voltage", "ВЫСОКОЕ\nНАПРЯЖЕНИЕ", "voltage"), ("no_entry", "НЕ ВХОДИТЬ", "stop"), ("sealed", "ГЕРМЕТИЧНО", "stop"),
    ("section_a", "СЕКЦИЯ А", "plate"), ("section_b", "СЕКЦИЯ Б", "plate"), ("generator", "ГЕНЕРАТОР Г-1", "plate"), ("ventilation", "ВЕНТИЛЯЦИЯ", "plate"),
    ("module_1", "1", "module"), ("module_2", "2", "module"), ("module_3", "3", "module"), ("module_4", "4", "module"),
]


def make_signs(out: Path):
    cols, rows, cw, ch = 4, 4, 512, 256
    atlas = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    uv = {}
    for i, (name, text, kind) in enumerate(SIGNS):
        cell = weather(sign(kind, text), 700 + i * 7, 1.0, edge=10)
        x, y = (i % cols) * cw, (i // cols) * ch
        atlas.paste(cell, (x, y))
        uv[name] = [x / atlas.width, y / atlas.height, (x + cw) / atlas.width, (y + ch) / atlas.height]
    save(atlas, out / "decals" / "signs_ru.png", uv)


# ---------------------------------------------------------------- hazard stripes
def make_hazard(out: Path):
    w, h = 1024, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stripes(d, (0, 0, w, h // 2 - 4), 128, (172, 138, 24), (22, 20, 16))
    stripes(d, (0, h // 2 + 4, w, h), 128, (150, 36, 28), (210, 206, 196))
    img = weather(img, 810, 1.4)
    save(img, out / "decals" / "hazard_stripes.png", {"yellow_black": [0, 0, 1, 0.48], "red_white": [0, 0.52, 1, 1]})


# ---------------------------------------------------------------- panel labels
LABELS = ["ПИТАНИЕ", "СЕКЦИЯ А", "СЕКЦИЯ Б", "АВАРИЯ", "ПУСК", "СТОП", "ВКЛ", "ОТКЛ",
          "ДАВЛЕНИЕ", "ТЕМПЕРАТУРА", "ОБОРОТЫ", "ПРИВОД", "ЗАЩИТА", "СБРОС", "ТЕСТ", "СВЯЗЬ",
          "ВЕНТИЛЬ 1", "ВЕНТИЛЬ 2", "ВЕНТИЛЬ 3", "ОХЛАЖДЕНИЕ", "ТОПЛИВО", "ГЕНЕРАТОР", "ШИНА", "ДОПУСК",
          "ВНИМАНИЕ", "РУЧНОЙ", "АВТО", "ПОДАЧА", "ДВЕРЬ", "ШЛЮЗ", "АРХИВ", "КАПСУЛА",
          "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "A1", "A2", "B1", "B2"]


def make_labels(out: Path):
    cols, cw, ch = 8, 256, 64
    rows = math.ceil(len(LABELS) / cols)
    atlas = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(atlas)
    uv = {}
    for i, text in enumerate(LABELS):
        x, y = (i % cols) * cw, (i // cols) * ch
        fs = 40 if len(text) < 8 else (30 if len(text) < 11 else 24)
        centered(d, (x, y, x + cw, y + ch), text, font(FONT_BOLD, fs), (206, 204, 192, 235))
        uv[text] = [x / atlas.width, y / atlas.height, (x + cw) / atlas.width, (y + ch) / atlas.height]
    arr = np.asarray(atlas, np.float32) / 255.0
    n = T.fbm(830, 1.2, size=max(atlas.size))[: atlas.height, : atlas.width]
    arr[..., 3] *= np.clip(0.8 + 0.5 * (n - 0.5), 0.5, 1.0)  # chipped paint
    atlas = Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA")
    save(atlas, out / "decals" / "panel_labels.png", uv)


# ---------------------------------------------------------------- instrument faces
def gauge_face(size, vmax, major, minor, unit, red_from, label, fmt="{}"):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    d.ellipse((4, 4, size - 4, size - 4), fill=(206, 204, 190))
    d.ellipse((18, 18, size - 18, size - 18), fill=(26, 27, 28))
    a0, a1 = math.radians(225), math.radians(-45)  # clockwise sweep from lower-left to lower-right
    r_out, r_in = c - 40, c - 78
    steps = major * minor
    for i in range(steps + 1):
        a = a0 + (a1 - a0) * i / steps
        ismaj = i % minor == 0
        rr = r_in if ismaj else r_in + 16
        col = (230, 228, 214)
        v = vmax * i / steps
        if red_from is not None and v >= red_from:
            col = (214, 60, 40)
        d.line([(c + math.cos(a) * r_out, c - math.sin(a) * r_out), (c + math.cos(a) * rr, c - math.sin(a) * rr)], fill=col, width=7 if ismaj else 3)
        if ismaj:
            tr = r_in - 26
            centered(d, (c + math.cos(a) * tr - 30, c - math.sin(a) * tr - 20, c + math.cos(a) * tr + 30, c - math.sin(a) * tr + 20), fmt.format(int(v)), font(FONT_BOLD, 24), (226, 224, 210))
    centered(d, (c - 90, c + 30, c + 90, c + 84), unit, font(FONT_BOLD, 34), (226, 224, 210))
    centered(d, (c - 70, c + 96, c + 70, c + 128), label, font(FONT_REG, 22), (160, 160, 150))
    return weather(img, 840 + vmax % 97, 0.8)


def make_gauges(out: Path):
    size = 512
    faces = [("pressure", gauge_face(size, 10, 10, 2, "БАР", 8, "ДАВЛЕНИЕ")),
             ("tachometer", gauge_face(size, 3000, 6, 5, "ОБ/МИН", 2700, "ОБОРОТЫ", "{}")),
             ("voltage", gauge_face(size, 400, 8, 5, "В", 360, "НАПРЯЖЕНИЕ")),
             ("temperature", gauge_face(size, 120, 6, 4, "°C", 100, "ТЕМПЕРАТУРА"))]
    atlas = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
    uv = {}
    for i, (name, im) in enumerate(faces):
        x, y = (i % 2) * size, (i // 2) * size
        atlas.paste(im, (x, y))
        uv[name] = [x / atlas.width, y / atlas.height, (x + size) / atlas.width, (y + size) / atlas.height]
    save(atlas, out / "decals" / "instrument_faces.png", uv)


# ---------------------------------------------------------------- screens
CY, CYD, GRN, AMB, REDC = (31, 181, 200), (14, 80, 92), (62, 211, 107), (232, 162, 28), (216, 52, 31)


def screen_base(w, h, seed):
    n = np.asarray(Image.fromarray((T.fbm(seed, 1.0, size=max(w, h)) * 255).astype(np.uint8)).resize((w, h)), np.float32) / 255.0
    arr = np.zeros((h, w, 3), np.float32)
    arr[...] = np.array([3, 14, 17], np.float32) / 255.0
    arr += n[..., None] * 0.02
    arr[::3] *= 0.86  # scanlines
    return Image.fromarray((arr * 255).astype(np.uint8)).convert("RGB")


def node(d, x, y, w, h, text, col, fnt):
    d.rectangle((x, y, x + w, y + h), outline=col, width=3)
    centered(d, (x, y, x + w, y + h), text, fnt, col)


def screen_mnemonic(w=1024, h=512):
    im = screen_base(w, h, 900)
    d = ImageDraw.Draw(im)
    f, fs = font(FONT_BOLD, 26), font(FONT_MONO, 20)
    d.text((24, 16), "ЭНЕРГОСНАБЖЕНИЕ  /  МНЕМОСХЕМА", font=font(FONT_BOLD, 28), fill=CY)
    d.line((24, 56, w - 24, 56), fill=CYD, width=2)
    node(d, 40, 200, 230, 90, "ГЕНЕРАТОР Г-1", AMB, fs)
    d.line((250, 245, 330, 245), fill=CY, width=4)
    node(d, 330, 200, 130, 90, "ШИНА", CY, f)
    for i, (name, y, col) in enumerate([("СЕКЦИЯ А", 100, GRN), ("СЕКЦИЯ Б", 220, GRN), ("СЕКЦИЯ В", 340, REDC)]):
        d.line((460, 245, 540, 245), fill=CY, width=4)
        d.line((540, 245, 540, y + 35), fill=CY if col != REDC else REDC, width=4)
        d.line((540, y + 35, 620, y + 35), fill=CY if col != REDC else REDC, width=4)
        node(d, 620, y, 200, 70, name, col, f)
        d.ellipse((840, y + 24, 864, y + 48), fill=col)
        d.text((876, y + 24), "НОРМА" if col == GRN else "НЕТ ПИТАНИЯ", font=fs, fill=col)
    d.text((24, h - 46), "РЕЖИМ: АВАРИЙНЫЙ    ДАВЛЕНИЕ: 4.2 БАР    ОБ/МИН: 0", font=fs, fill=CYD)
    return im


def screen_terminal_boot(w=1024, h=512):
    im = screen_base(w, h, 910)
    d = ImageDraw.Draw(im)
    f = font(FONT_MONO, 24)
    lines = ["СИСТЕМА СОДЕРЖАНИЯ  v4.1", "ПРОВЕРКА ПАМЯТИ ............ ОК", "ШИНА ДАННЫХ ................ ОК",
             "ПИТАНИЕ СЕКЦИИ ............. АВАРИЙНОЕ", "СВЯЗЬ С МОДУЛЯМИ ........... НЕТ ОТВЕТА", "", "ДОПУСК:  ОЖИДАНИЕ", "> _"]
    for i, t in enumerate(lines):
        d.text((32, 28 + i * 34), t, font=f, fill=GRN if "ОК" in t else (AMB if "АВАР" in t or "НЕТ" in t else CY))
    return im


def screen_off(w=1024, h=512):
    im = screen_base(w, h, 920)
    arr = np.asarray(im, np.float32) / 255.0
    arr = arr * 0.35 + 0.012
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    arr += (1 - yy) * 0.02  # faint window reflection
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))


def screen_alarm(w=1024, h=512):
    im = screen_base(w, h, 930)
    d = ImageDraw.Draw(im)
    d.rectangle((24, 24, w - 24, h - 24), outline=REDC, width=6)
    centered(d, (0, 120, w, 260), "ТРЕВОГА", font(FONT_BOLD, 120), REDC)
    centered(d, (0, 270, w, 340), "НЕСТАБИЛЬНОСТЬ МОДУЛЯ", font(FONT_BOLD, 40), AMB)
    centered(d, (0, 350, w, 400), "ТРЕБУЕТСЯ ВМЕШАТЕЛЬСТВО ОПЕРАТОРА", font(FONT_MONO, 26), CY)
    return im


def make_screens(out: Path):
    cw, ch = 1024, 512
    atlas = Image.new("RGB", (cw * 2, ch * 2))
    uv = {}
    for i, (name, im) in enumerate([("mnemonic", screen_mnemonic()), ("terminal_boot", screen_terminal_boot()),
                                    ("terminal_off", screen_off()), ("alarm", screen_alarm())]):
        x, y = (i % 2) * cw, (i // 2) * ch
        atlas.paste(im, (x, y))
        uv[name] = [x / atlas.width, y / atlas.height, (x + cw) / atlas.width, (y + ch) / atlas.height]
    save(atlas, out / "decals" / "screens.png", uv)


# ---------------------------------------------------------------- grime decals
def make_grime(out: Path):
    n = 1024
    streak = T.fbm(950, 2.2, size=n, stretch=(1.0, 0.04))
    blot = T.fbm(951, 2.8, size=n)
    mask = T.smoothstep(0.52, 0.8, streak * 0.75 + blot * 0.4)
    fade = np.linspace(1, 0.15, n, dtype=np.float32)[:, None]  # dirt runs down and fades out
    a = np.clip(mask * (0.55 + 0.45 * fade), 0, 1)
    rgba = np.zeros((n, n, 4), np.float32)
    rgba[..., :3] = np.array([0.02, 0.018, 0.016], np.float32)
    rgba[..., 3] = a * 0.85
    save(Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA"), out / "decals" / "grime_streaks.png", {})

    rust_m = T.smoothstep(0.55, 0.8, T.fbm(952, 2.2, size=n, stretch=(1.0, 0.05)) * 0.7 + T.fbm(953, 3.0, size=n) * 0.4)
    rcol = T.colorize(T.fbm(954, 1.4, size=n), [(0, (0.20, 0.08, 0.03)), (1, (0.40, 0.18, 0.06))])
    rgba = np.zeros((n, n, 4), np.float32)
    rgba[..., :3] = rcol
    rgba[..., 3] = np.clip(rust_m * (0.5 + 0.5 * fade), 0, 1) * 0.9
    save(Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA"), out / "decals" / "rust_bleed.png", {})

    sc = np.maximum(T.lines(955, 380, (40, 260), 1.2, 0.5, 0.0, size=n), T.lines(956, 90, (120, 480), 2.0, 0.3, 0.2, size=n))
    rgba = np.zeros((n, n, 4), np.float32)
    rgba[..., :3] = np.array([0.55, 0.55, 0.53], np.float32)
    rgba[..., 3] = sc * 0.55
    save(Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA"), out / "decals" / "scuffs.png", {})


def save(img: Image.Image, path: Path, uv: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    if uv:
        path.with_suffix(".json").write_text(json.dumps(uv, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(path.name, f"{path.stat().st_size // 1024}K", img.size)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="loads/textures")
    out = Path(ap.parse_args().out)
    for fn in (make_signs, make_hazard, make_labels, make_gauges, make_screens, make_grime):
        fn(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
