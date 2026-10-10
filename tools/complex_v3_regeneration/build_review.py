#!/usr/bin/env python3
"""Render the owner review of the complex version 4 canonical plans.

Reads the extraction reports written by build_canonical_from_approved.py and the
authored findings in review_content.py, and writes Markdown plus example images to
docs/design/complex_v4/review/. Nothing here modifies a plan.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).parent))
import review_content as content  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "docs/design/complex_v4/review"
DATA = REVIEW / "data"
FONT = "C:/Windows/Fonts/arial.ttf"
SRC_NAME = {"BIBLE": "библия", "OVERVIEW": "общий план", "PLAN": "секторный план", "GEOM": "геометрия",
            "OVERVIEW + PLAN": "общий и секторный планы", "GEOM + BIBLE": "геометрия и библия"}


def load() -> dict[str, dict]:
    return {p.stem.upper(): json.loads(p.read_text(encoding="utf-8")) for p in sorted(DATA.glob("*.json"))}


def room(reports: dict, sector: str, prefix: str) -> list[float]:
    for rm in reports[sector]["rooms"]:
        if rm["space_id"].split("/")[1].startswith(prefix):
            return rm["world_m"]
    raise KeyError(f"{sector}:{prefix}")


# ----------------------------------------------------------------- drawing
class Canvas:
    def __init__(self, x0: float, z0: float, x1: float, z1: float, ppm: float = 10.0, title: str = ""):
        self.x0, self.z0, self.ppm = x0, z0, ppm
        self.w, self.h = int((x1 - x0) * ppm), int((z1 - z0) * ppm) + 26
        self.im = Image.new("RGB", (self.w, self.h), "white")
        self.d = ImageDraw.Draw(self.im, "RGBA")
        self.d.text((6, 4), title, fill=(0, 0, 0, 255), font=ImageFont.truetype(FONT, 14))

    def t(self, x: float, z: float) -> tuple[float, float]:
        return ((x - self.x0) * self.ppm, (z - self.z0) * self.ppm + 24)

    def rect(self, r, fill=(185, 201, 210), outline=(40, 50, 60), label="", dashed=False, width=2):
        x, z, w, h = r
        a, b = self.t(x, z), self.t(x + w, z + h)
        if dashed:
            self._dash(a, b, outline)
            if fill:
                self.d.rectangle([a, b], fill=tuple(fill) + (60,))
        else:
            self.d.rectangle([a, b], fill=tuple(fill) + (150,) if fill else None, outline=tuple(outline) + (255,), width=width)
        if label:
            self.d.text((a[0] + 3, a[1] + 2), label, fill=(0, 0, 0, 255), font=ImageFont.truetype(FONT, 10))

    def _dash(self, a, b, col):
        for (x1, y1, x2, y2) in ((a[0], a[1], b[0], a[1]), (b[0], a[1], b[0], b[1]), (b[0], b[1], a[0], b[1]), (a[0], b[1], a[0], a[1])):
            n = max(int(abs(x2 - x1) + abs(y2 - y1)) // 8, 1)
            for i in range(0, n, 2):
                p, q = i / n, min((i + 1) / n, 1)
                self.d.line([(x1 + (x2 - x1) * p, y1 + (y2 - y1) * p), (x1 + (x2 - x1) * q, y1 + (y2 - y1) * q)], fill=tuple(col) + (255,), width=2)

    def line(self, x1, z1, x2, z2, col=(200, 40, 40), width=3, dashed=False):
        a, b = self.t(x1, z1), self.t(x2, z2)
        if dashed:
            n = max(int(abs(b[0] - a[0]) + abs(b[1] - a[1])) // 8, 1)
            for i in range(0, n, 2):
                p, q = i / n, min((i + 1) / n, 1)
                self.d.line([(a[0] + (b[0] - a[0]) * p, a[1] + (b[1] - a[1]) * p), (a[0] + (b[0] - a[0]) * q, a[1] + (b[1] - a[1]) * q)], fill=tuple(col) + (255,), width=width)
        else:
            self.d.line([a, b], fill=tuple(col) + (255,), width=width)

    def text(self, x, z, s, col=(150, 0, 0), size=11):
        self.d.text(self.t(x, z), s, fill=tuple(col) + (255,), font=ImageFont.truetype(FONT, size))

    def save(self, name: str) -> None:
        out = REVIEW / "examples"
        out.mkdir(parents=True, exist_ok=True)
        self.im.save(out / name)


def side_by_side(name: str, left: Canvas, right: Canvas) -> None:
    im = Image.new("RGB", (left.w + right.w + 12, max(left.h, right.h)), "white")
    im.paste(left.im, (0, 0))
    im.paste(right.im, (left.w + 12, 0))
    out = REVIEW / "examples"
    out.mkdir(parents=True, exist_ok=True)
    im.save(out / name)


C_U, C_L, C_T = (210, 60, 50), (40, 140, 70), (50, 90, 200)


def ex_vertical(R: dict) -> None:
    items = [
        ("Главный лифт", [("U", "U-CENTRAL-CORE", "lift"), ("L", "L-CENTRAL-CORE", "lift"), ("T", "T-EAST-VERTICAL", "shahta")]),
        ("Лестница маршрута A", [("U", "U-ROUTE-A", "lestnica-a"), ("L", "L-ARCHIVE-A", "lestnica-a")]),
        ("Служебная лестница", [("L", "L-SERVICE-INTERCHANGE", "lestnica"), ("T", "T-UTILITIES", "lestnica")]),
        ("Восточная лестница", [("U", "U-EAST-SUPPORT", "avariynaya-lestnica"), ("L", "L-EAST-STAIR", "avariynaya-lestnica"), ("T", "T-EAST-VERTICAL", "vostochnaya")]),
        ("Грузовой лифт", [("U", "U-FREIGHT", "gruzovoy-lift"), ("L", "L-FREIGHT-SERVICE", "gruzovoy-lift"), ("T", "T-FREIGHT", "gruzovoy-lift")]),
        ("Старая лестница", [("T", "T-OLD-ACCESS", "staraya-lestnica")]),
    ]
    cv = Canvas(-112, -12, 36, 90, 9, "Одни и те же вертикали на трёх этажах (красный — верхний, зелёный — нижний, синий — технический)")
    col = {"U": C_U, "L": C_L, "T": C_T}
    for title, rs in items:
        for lv, sec, pref in rs:
            r = room(R, sec, pref)
            cv.rect(r, fill=None, outline=col[lv], width=3)
            cv.text(r[0] + 0.3, r[1] + 0.2 + {"U": 0, "L": 1.3, "T": 2.6}[lv], f"{lv} {title}", col[lv], 10)
    cv.text(-110, 84, "Старая лестница на нижнем этаже не имеет помещения (см. L-OLD-CORE).", (0, 0, 0), 11)
    cv.save("vertical_alignment.png")


def ex_route_a(R: dict) -> None:
    u, l = room(R, "U-ROUTE-A", "lestnica-a"), room(R, "L-ARCHIVE-A", "lestnica-a")
    arch = room(R, "L-ARCHIVE-A", "sluzhebnyy-prohod")
    a = Canvas(-62, 2, -38, 22, 14, "До: U (красный) и L (зелёный) не совпадают")
    a.rect(arch, fill=(220, 220, 200), outline=(120, 120, 120), label="проход архива")
    a.rect(u, fill=None, outline=C_U); a.rect(l, fill=None, outline=C_L)
    a.text(u[0] + .2, u[1] + .2, "U лестница A 6,7×7,8", C_U); a.text(l[0] + .2, l[1] + l[3] - 1.4, "L лестница A 7,0×3,7", C_L)
    b = Canvas(-62, 2, -38, 22, 14, "После: L по U, проём 3,4×7,0")
    n = [u[0], u[1], u[2], u[3]]
    b.rect(arch, fill=(220, 220, 200), outline=(120, 120, 120), label="проход архива")
    b.rect(n, fill=(200, 230, 210), outline=C_L, label="L: лестничная комната")
    b.rect([u[0] + 0.6, u[1] + 0.4, 3.4, 7.0], fill=(60, 60, 60), outline=(0, 0, 0), label="проём 3,4×7,0")
    b.rect(u, fill=None, outline=C_U, dashed=True)
    side_by_side("route_a_stair.png", a, b)


def ex_old_stair(R: dict) -> None:
    hall = room(R, "L-OLD-CORE", "raspredelitelnyy")
    ta = room(R, "T-OLD-ACCESS", "staraya-lestnica")
    a = Canvas(-110, 0, -60, 50, 10, "До: на нижнем этаже лестница не нарисована")
    a.rect(hall, fill=(214, 196, 160), label="холл старого ядра"); a.rect(ta, fill=None, outline=C_T, dashed=True)
    a.text(ta[0] + 1, ta[1] + 1, "T: старая лестница 18×15,6", C_T)
    b = Canvas(-110, 0, -60, 50, 10, "После (A): вестибюль + лестница по общему плану")
    b.rect(hall, fill=(214, 196, 160), label="холл старого ядра")
    b.rect([-93.3, 28.4, 10.0, 13.4], fill=(205, 215, 225), outline=C_L, label="старая лестница 10×13,4")
    b.rect([-83.3, 30.7, 3.3, 8.9], fill=(220, 220, 200), outline=(120, 120, 120), label="вестибюль")
    b.line(-81.5, 25.1, -81.5, 30.7, (30, 140, 60), 4)
    b.rect(ta, fill=None, outline=C_T, dashed=True)
    side_by_side("old_stair_L.png", a, b)


def ex_lab(R: dict) -> None:
    lab = [room(R, "L-SLEEP-LAB", p) for p in ("neyromonitoring", "nablyudenie", "apparatnaya", "podgotovka", "vnutrenniy")]
    c2, c3 = room(R, "L-CHAMBER-2", "kamera-2"), room(R, "L-CHAMBER-3", "kamera-3")
    p2, p3 = room(R, "L-CHAMBER-2", "post"), room(R, "L-CHAMBER-3", "post")
    a = Canvas(-82, 0, 2, 66, 8, "Сейчас: лаборатория далеко от №2, только кабель к №3")
    b = Canvas(-82, 0, 2, 66, 8, "Вариант B: узел наблюдения №2 + кабельная трасса")
    for cv in (a, b):
        for r in lab: cv.rect(r, fill=(250, 220, 200))
        cv.text(lab[0][0], lab[0][1] - 1.5, "лаборатория сна", (120, 60, 0))
        cv.rect(c2, fill=(214, 196, 160), label="камера №2"); cv.rect(c3, fill=(200, 200, 230), label="камера №3")
        cv.rect(p2, fill=(214, 196, 160)); cv.rect(p3, fill=(200, 200, 230))
    a.line(-23, 6, -23, 28, (90, 90, 90), 3, True); a.text(-22, 16, "кабель", (90, 90, 90))
    node = [p2[0] - 9.5, p2[1] - 7, 8.0, 6.0]
    b.rect(node, fill=(255, 235, 150), outline=(180, 120, 0), label="наблюд. узел №2: терминал")
    b.line(node[0] + 4, node[1], -58, 8, (90, 90, 90), 3, True); b.line(-58, 8, lab[3][0], 8, (90, 90, 90), 3, True)
    b.line(-23, 6, -23, 28, (90, 90, 90), 3, True)
    side_by_side("lab_options.png", a, b)


def ex_chamber3(R: dict) -> None:
    rs = {k: room(R, "L-CHAMBER-3", k) for k in ("kamera-3", "post", "zaschischennaya", "operatorskaya", "diagnostika", "gruzovoy")}
    a = Canvas(-40, 24, -6, 62, 12, "Сейчас: кресло в галерее вне камеры, газа нет")
    b = Canvas(-40, 24, -6, 62, 12, "Вариант C: газоввод в галерею, герметичный контур")
    for cv in (a, b):
        for k, r in rs.items(): cv.rect(r, fill=(200, 200, 230), label=k[:14])
    gal = rs["operatorskaya"]
    b.rect([gal[0] - 2.8, gal[1] + 8, 2.6, 4.0], fill=(255, 235, 150), outline=(180, 120, 0), label="газоввод")
    b.line(gal[0] - 0.2, gal[1] + 10, gal[0] + 0.5, gal[1] + 10, (180, 120, 0), 4)
    b.line(rs["kamera-3"][0] + 2, rs["kamera-3"][1] + 2, gal[0] - 2.4, gal[1] + 8, (180, 120, 0), 3, True)
    b.rect([gal[0], gal[1], gal[2], gal[3]], fill=None, outline=(200, 40, 40), dashed=True)
    b.text(gal[0] - 14, gal[1] - 2, "красный пунктир — герметичная зона", (200, 40, 40))
    side_by_side("chamber3_gas.png", a, b)


def ex_chamber5(R: dict) -> None:
    c5, c6 = room(R, "L-CHAMBER-5", "kamera-6"), room(R, "U-CHAMBER-6", "kamera-6")
    core = room(R, "L-CENTRAL-CORE", "lift")
    a = Canvas(-12, 0, 50, 70, 10, "Сейчас: камеры 5 и 6 друг над другом, ≈15 м от ядра")
    a.rect(core, fill=(220, 220, 200), label="ядро"); a.rect(c5, fill=(190, 230, 190), label="L камера №5"); a.rect(c6, fill=None, outline=C_U, label="U камера №6", dashed=True)
    b = Canvas(-12, 0, 50, 70, 10, "Вариант B: №5 сдвинута на +12 м и вход с T-уровня")
    b.rect(core, fill=(220, 220, 200), label="ядро"); b.rect([c5[0] + 12, c5[1], c5[2], c5[3]], fill=(190, 230, 190), label="L камера №5 (+12 м)")
    b.rect(c6, fill=None, outline=C_U, label="U камера №6", dashed=True)
    b.line(c5[0] + 12 + c5[2] / 2, c5[1] + c5[3], c5[0] + 12 + c5[2] / 2, c5[1] + c5[3] + 4, C_T, 4, True)
    b.text(c5[0] + 12, c5[1] + c5[3] + 4.5, "служебный ввод с T-уровня", C_T)
    side_by_side("chamber5_options.png", a, b)


def ex_tunnel(R: dict) -> None:
    hall = room(R, "L-OLD-RECEIVING", "staryy-priemnyy-zal-2")
    a = Canvas(-125, 36, -60, 76, 11, "Варианты устья тоннеля")
    a.rect(hall, fill=(214, 196, 160), label="старый приёмный зал")
    a.rect([-110, 60, 142, 7.5], fill=(200, 215, 235), label="верхняя магистраль (z 60..67,5)")
    a.rect([-125, 53, 14, 8], fill=(240, 200, 160), outline=(180, 100, 0), label="A: устье на запад")
    a.line(-72, 56, -110, 64, (180, 100, 0), 4, True); a.text(-100, 57, "трасса handoff: пересекает зал, магистраль и шлюз №4", (180, 100, 0), 10)
    a.rect([hall[0], hall[1] + hall[3] - 5, 10, 5], fill=(180, 180, 180), outline=(60, 60, 60), label="C: завал у устья")
    a.save("tunnel.png")


def ex_t_order(R: dict) -> None:
    gal = room(R, "T-CIRCULATION", "kabelno")
    rooms = [room(R, "T-UTILITIES", p) for p in ("podstanciya", "ventilyaciya", "gazy", "drenazh")]
    cor = room(R, "T-CIRCULATION", "glavnyy-sluzhebnyy")
    a = Canvas(-100, 8, 36, 56, 8, "Сейчас: галерея (T7) лежит над комнатами и пересекает их")
    a.rect(cor, fill=(215, 215, 215), label="главный коридор")
    for r in rooms: a.rect(r, fill=(190, 200, 210))
    a.rect(gal, fill=(120, 190, 200), label="кабельная галерея")
    b = Canvas(-100, 8, 36, 56, 8, "Вариант A: галерея ниже комнат (как на общем плане)")
    b.rect(cor, fill=(215, 215, 215), label="главный коридор")
    for r in rooms: b.rect(r, fill=(190, 200, 210))
    low = max(r[1] + r[3] for r in rooms)
    b.rect([gal[0], low + 0.5, gal[2], gal[3]], fill=(120, 190, 200), label="кабельная галерея")
    side_by_side("t_circulation_order.png", a, b)


def ex_medbay(R: dict) -> None:
    med = [rm["world_m"] for rm in R["U-MEDBAY"]["rooms"]]
    hall = room(R, "U-EMERGENCY", "raspredelitelnyy")
    strip = room(R, "U-MEDBAY", "raspredelitelnyy")
    a = Canvas(-100, 6, -60, 28, 14, "До: полоса «вход» перекрывает холл")
    b = Canvas(-100, 6, -60, 28, 14, "После (A): полоса удалена")
    for cv, skip in ((a, False), (b, True)):
        cv.rect(hall, fill=(214, 196, 160), label="холл")
        for r in med:
            if skip and r == strip: continue
            cv.rect(r, fill=(250, 210, 210), outline=(150, 60, 60) if r == strip else (40, 50, 60))
    a.text(strip[0], strip[1] - 1.5, "полоса 2,6×7,8", (150, 0, 0))
    side_by_side("medbay_strip.png", a, b)


# ----------------------------------------------------------------- text
def md_table(rows: list[list[str]], head: list[str]) -> str:
    out = ["| " + " | ".join(head) + " |", "|" + "|".join("---" for _ in head) + "|"]
    out += ["| " + " | ".join(r) + " |" for r in rows]
    return "\n".join(out)


def finding_md(f: dict, ident: str) -> str:
    opts = "\n".join(f"  - **{k}.** {v}" for k, v in f["options"])
    ex = f"\n  - Пример: `examples/{f['example']}`" if f.get("example") else ""
    return f"- **{ident}** [{SRC_NAME.get(f['src'], f['src'])}] {f['text']}\n{opts}\n  - Рекомендация: **{f['rec']}**.{ex}"


def sector_md(sid: str, rep: dict, findings: list[dict]) -> str:
    reg = rep["registration"]
    lines = [f"# {sid}", "",
             f"Источник: `{rep['source_plan']}`. Уровень {rep['level']}. Высота стен {rep['wall_height_m']} м (рабочее значение, не из плана).",
             f"Масштаб: {reg['plan_px_per_m_x']} px/м по X, {reg['plan_px_per_m_y']} px/м по Y; анизотропия {reg['anisotropy_percent']}%. "
             f"Положение сектора (x, z, ширина, глубина), м: {reg['world_envelope_m']}.", ""]
    for c in reg["check_pairs"]:
        lines.append(f"- Проверка по общему плану: комната плана {c['plan_size_m'][0]}×{c['plan_size_m'][1]} м, на общем плане {c['overview_size_m'][0]}×{c['overview_size_m'][1]} м.")
    lines += ["", "## Помещения", ""]
    open_count: dict[str, int] = {}
    for o in rep["openings"]:
        for sp in o["rooms"]:
            open_count[sp] = open_count.get(sp, 0) + 1
    rows = []
    for rm in rep["rooms"]:
        slug = rm["space_id"].split("/")[1]
        mine = [i for i, f in enumerate(findings, 1) if f["room"] == "*" or slug.startswith(f["room"])]
        label = (rm["label"].split(" / ")[0] or "(без подписи)")[:36]
        rows.append([f"`{slug}`", label, f"{rm['size_m'][0]}×{rm['size_m'][1]}", f"{rm['area_m2']}", str(open_count.get(rm["space_id"], 0)),
                     ", ".join(f"{sid}-{i:02d}" for i in mine) or "—"])
    lines.append(md_table(rows, ["Помещение", "Подпись на плане", "Размер, м", "м²", "Проёмов", "Замечания"]))
    lines += ["", "## Замечания и варианты исправления", ""]
    if not findings:
        lines.append("Замечаний нет.")
    for i, f in enumerate(findings, 1):
        lines.append(finding_md(f, f"{sid}-{i:02d}"))
        lines.append("")
    auto = [a for a in rep["anomalies"] if a["type"] != "opening_not_on_sector_wall"]
    if auto:
        lines += ["## Автоматические наблюдения", ""]
        for a in auto:
            lines.append(f"- {a['type']}: {a.get('space') or (a.get('a', '') + ' × ' + a.get('b', ''))} {a.get('overlap_m', '')}")
    lines += ["", "Ничего из перечисленного не применено к каноническому SVG."]
    return "\n".join(lines) + "\n"


def main() -> int:
    R = load()
    for fn in (ex_vertical, ex_route_a, ex_old_stair, ex_lab, ex_chamber3, ex_chamber5, ex_tunnel, ex_t_order, ex_medbay):
        fn(R)
    sdir = REVIEW / "sectors"
    sdir.mkdir(parents=True, exist_ok=True)
    for sid, rep in R.items():
        (sdir / f"{sid.lower()}.md").write_text(sector_md(sid, rep, content.SECTORS.get(sid, [])), encoding="utf-8", newline="\n")
    idx = ["# Комплекс v4 — ревизия канонических планов", "",
           "Канонические SVG построены из утверждённых планов v3 без изменения геометрии "
           "(`tools/complex_v3_regeneration/build_canonical_from_approved.py`). Масштаб и положение взяты из общих планов этажей. "
           "Все ниже перечисленные правки — **предложения**, ни одна не применена.", "",
           "## Сквозные вопросы", ""]
    for g in content.GLOBAL:
        idx.append(f"### {g['id']}. {g['title']}  ({SRC_NAME.get(g['source'], g['source'])})")
        idx.append(g["problem"])
        idx += [f"- **{k}.** {v}" for k, v in g["options"]]
        idx.append(f"- Рекомендация: {g['recommend']}\n")
    idx += ["## Сектора", ""]
    rows = []
    for sid, rep in R.items():
        n = len(content.SECTORS.get(sid, []))
        rows.append([f"[{sid}](sectors/{sid.lower()}.md)", rep["level"], str(len(rep["rooms"])), f"{rep['registration']['anisotropy_percent']}%", str(n)])
    idx.append(md_table(rows, ["Сектор", "Этаж", "Помещений", "Анизотропия", "Замечаний"]))
    idx += ["", "## Примеры", ""] + [f"- `examples/{p.name}`" for p in sorted((REVIEW / "examples").glob("*.png"))]
    (REVIEW / "README.md").write_text("\n".join(idx) + "\n", encoding="utf-8", newline="\n")
    print("review written:", len(R), "sectors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
