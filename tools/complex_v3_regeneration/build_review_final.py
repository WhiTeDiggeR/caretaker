"""Rewrite the review cards (README, one page per sector, pictures) from the final canonical data and the decision log.

Run after build_canonical_from_approved.py. Reads docs/design/complex_v4/review/data/*.json and review/decisions.md.
"""
import re
import shutil
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import review_views as rv  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "docs/design/complex_v4/review"
LEVEL = {"LV-U": "верхний", "LV-L": "нижний", "LV-T": "технический"}

GLOBAL = [
    ("G-01", "Вертикальные опоры между этажами", "решено", "все шахты совпадают между этажами (±0,03 м), проверка `check_verticals.py`; D-30, D-31, D-33, D-36…D-38, D-41, D-42"),
    ("G-02", "Грузовые зоны U/L смещены на 5,6 м", "решено", "магистрали на всех этажах на одной линии, лифт на z 69,56 везде; D-36"),
    ("G-03", "Магистрали без владельца", "решено", "владельцы: U-/L-/T-CIRCULATION, проёмы повторяют проёмы соседей; D-39 (инвентарь производственных сцен пока на 30 секторов)"),
    ("G-04", "Анизотропия секторных планов", "принято", "рамка сектора — по общему плану, внутри — пропорции секторного плана; камеры 4–6 — один модуль; D-35"),
    ("G-05", "Состояния блокировок и завалов", "отложено", "сюжетные детали, в геометрии пока не нужны; D-05"),
    ("G-06", "Двери уже профиля прохода", "решено", "каталог дверей: wing 1,8×2,8, служебная 1,0×2,1, historic 1,4×2,3, ворота 4,5×4,5, широкий проход 3–6 м; D-09"),
    ("G-07", "Повторяющиеся чертежи и подписи", "решено", "камеры №4, №5, №6 — один модуль по образцу №6, подписи по номеру; D-16, D-35"),
    ("G-08", "Высоты и перекрытия не заданы планами", "решено", "перекрытие не тоньше 1,0 м; стены T-FREIGHT, T-ENERGY, T-EAST-VERTICAL 4,5 м, отметки этажей прежние; D-43"),
    ("G-09", "Химический протокол: физический контур", "решено", "газовый коллектор камеры №3, устройство погружения в камере; D-26 (камера №2 — газовая, D-24)"),
    ("G-10", "Положение лаборатории, камер №2 и №3", "решено", "правка библии: один контур, терминал №2 в посту камеры №2; D-24, D-25"),
    ("G-11", "Камеры №5 и №6 стоят друг над другом", "решено", "принято; скорость ходьбы не менялась; D-17, D-35"),
    ("G-12", "Узлы из библии, которых нет на планах", "открыто", "межмировой узел, поверхность и закрытый транспортный коридор — после сюжетных решений; терминал №2 и резерв кресла — отметки, не геометрия"),
]


def decisions() -> list[list[str]]:
    rows = []
    for line in (REVIEW / "decisions.md").read_text(encoding="utf-8").splitlines():
        if line.startswith("| D-"):
            rows.append([c.strip() for c in line.strip().strip("|").split("|")])
    return rows


def sectors_of(cell: str, known: set[str]) -> set[str]:
    out = set(re.findall(r"[UTL]-[A-Z0-9][A-Z0-9-]*", cell))
    if "U-/L-CENTRAL-CORE" in cell:
        out |= {"U-CENTRAL-CORE", "L-CENTRAL-CORE"}
    if "U-CHAMBER-4/6" in cell:
        out |= {"U-CHAMBER-4", "U-CHAMBER-6"}
    if "U-/L-FREIGHT" in cell:
        out |= {"U-FREIGHT", "L-FREIGHT-SERVICE"}
    return {s for s in out if s in known}


def main() -> int:
    R = rv.load_all()
    known = set(R)
    by_sector: dict[str, list[list[str]]] = {s: [] for s in known}
    for cells in decisions():
        for s in sectors_of(cells[1], known):
            by_sector[s].append(cells)
    img = REVIEW / "sectors" / "img"
    for old in list(img.glob("*.png")) + list(img.glob("*.png.import")):
        if not old.name.startswith("levels.png"):
            old.unlink()
    examples = REVIEW / "examples"
    if examples.exists():
        shutil.rmtree(examples)
    for sid, rep in sorted(R.items()):
        xs = [m["world_m"][0] for m in rep["rooms"]] + [m["world_m"][0] + m["world_m"][2] for m in rep["rooms"]]
        zs = [m["world_m"][1] for m in rep["rooms"]] + [m["world_m"][1] + m["world_m"][3] for m in rep["rooms"]]
        w, h = max(xs) - min(xs), max(zs) - min(zs)
        ppm = max(2.0, min(22.0, 900.0 / max(w + 10, 1), 700.0 / max(h + 10, 1)))
        box = (min(xs) - 5, min(zs) - 5, max(xs) + 5, max(zs) + 5)
        rv.save(rv.draw_sector(R, sid, None, f"{sid} · итог", ppm=ppm, show_neighbours=False, box=box), f"{sid.lower()}.png")
        lines = [f"# {sid}", "",
                 f"Этаж: {LEVEL[rep['level']]} ({rep['level']}). Источник: `{rep['source_plan']}`. Высота стен {rep['wall_height_m']} м. "
                 f"Габарит {w:.1f}×{h:.1f} м, x {min(xs):.1f}…{max(xs):.1f}, z {min(zs):.1f}…{max(zs):.1f}.", "",
                 f"![{sid}](img/{sid.lower()}.png)", "", "## Помещения", "", "| Помещение | Размер, м | м² | Класс |", "|---|---|---|---|"]
        for m in rep["rooms"]:
            label = m["label"].split(" / ")[0] or m["space_id"].split("/")[1]
            lines.append(f"| {label} | {m['world_m'][2]:.2f}×{m['world_m'][3]:.2f} | {m['world_m'][2] * m['world_m'][3]:.1f} | {m['class']} |")
        kinds = Counter((o["type"], o["width_m"]) for o in rep["openings"])
        lines += ["", "## Проёмы и двери", "", ", ".join(f"{t} {wd} м × {n}" for (t, wd), n in sorted(kinds.items())) or "нет", ""]
        if by_sector[sid]:
            lines += ["## Решения", ""] + [f"- **{c[0]}** — {c[2]}" for c in by_sector[sid]] + [""]
        if rep.get("anomalies"):
            lines += ["## Автонаблюдения", ""] + [f"- {a['type']} {a.get('source_id', a.get('space', ''))}" for a in rep["anomalies"]] + [""]
        (REVIEW / "sectors" / f"{sid.lower()}.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    readme = ["# Комплекс v4 — итоги ревизии", "",
              "Канонические SVG построены из утверждённых планов v3 (`tools/complex_v3_regeneration/build_canonical_from_approved.py`, "
              "привязка — `approved_registration.json`). Каждое исправление принято пользователем и записано в [decisions.md](decisions.md) (D-01…D-44).", "",
              "## Статус сквозных вопросов", "", "| № | Вопрос | Статус | Чем закрыт |", "|---|---|---|---|"]
    readme += [f"| {g} | {t} | {s} | {n} |" for g, t, s, n in GLOBAL]
    readme += ["", "## Правила, принятые по ходу", "",
               "- Двери из одного холла в смежные помещения одинаковые по типу и размеру; коридоры открываются в холлы и комнаты широкими проходами (3–6 м), иногда без двери.",
               "- Стены соседних помещений продолжают друг друга, без изломов «в пустоте»; сектора примыкают к магистралям вплотную.",
               "- Камеры №4, №5, №6 — один модуль (образец — №6); коридор z 19,6…25,1 и тяжёлая магистраль z 61,8…69,6 одинаковы на всех этажах.",
               "- Шахты (лифты, лестницы) совпадают между этажами; комната на другом этаже может содержать шахту.", "",
               "## Этажи целиком", "", "![этажи](sectors/img/levels.png)", "", "## Сектора", "",
               "| Сектор | Этаж | Помещений | Анизотропия |", "|---|---|---|---|"]
    for sid, rep in sorted(R.items()):
        readme.append(f"| [{sid}](sectors/{sid.lower()}.md) | {rep['level']} | {len(rep['rooms'])} | {rep['registration']['anisotropy_percent']}% |")
    readme += ["", "## Открыто", "",
               "- VT-OLD-INCLINE: тоннель обрушен, геометрии нет (D-44), в реестре статус `closed`.",
               "- G-05, G-12 — см. таблицу."]
    (REVIEW / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
