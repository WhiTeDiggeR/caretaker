# Комплекс v4 — канонические источники генерации

Версия 4 самодостаточна: всё, из чего строятся сцены комплекса, лежит в `docs/design/complex_v4/`, код — в `scenes/complex_v4/`,
`tools/complex_v4/` и `addons/complex_v4_*`. Материалы прежней версии (v3) остались в своём каталоге и для v4 не нужны.

## Состав

| Путь | Что это |
|---|---|
| `plans/generation/{upper,lower,technical}/` | 32 канонических метрических SVG — единственный геометрический вход генератора |
| `sources/plans/sectors/` | исходные планы секторов (утверждённые презентационные планы), из которых построены канонические SVG |
| `handoff/` | метаданные комплекса: описание пространств и порталов (`geometry`), вертикальные переходы (`vertical`), паспорта секторов (`passports`) |
| `regeneration/vertical-markup.md` | контракт разметки лестниц и шахт в SVG (`data-vertical-*`) |
| `review/` | итоги ревизии: статус вопросов, решения D-01…D-48, карточка и картинка на сектор |

## Конвейер

1. `tools/complex_v4/build_canonical_from_approved.py` строит `plans/generation/*.svg` из `sources/plans/` по правилам
   `tools/complex_v4/approved_registration.json` (привязка к общим планам этажей, поправки D-01…D-48). Элементы, добавленные в
   исходные планы позже (пилоты), в построении не участвуют.
2. `tools/complex_v4/build_sector_manifest.py` собирает `sector_generation_manifest.json`; лестницы выводятся из разметки SVG
   (`vertical_resolver.py`, определения — `vertical_definitions.json`).
3. `tools/complex_v4/safe_regenerate.py --sector <ID>` атомарно пересобирает пакет сектора в `gen/<этаж>/<сектор>/`.
4. Сцены `scenes/complex_v4/zones/*` подключают пакеты; сборка комплекса — `scenes/complex_v4/complex_v4_blockout.tscn`,
   проходная тестовая сцена — `complex_v4_blockout_test.tscn`.
5. `bash tools/ci/run_checks.sh` — все проверки (Python и headless Godot).

## Планы этажей

`python tools/complex_v4/floor_plans/build_floor_plans.py` собирает `build/floor_plans.html` — интерактивные планы трёх уровней
из `plans/generation/*.svg` (помещения, двери по типам, окна, проёмы, шахты). Маршрут начала и отметки помещений задаются в
`tools/complex_v4/floor_plans/annotations.json`; `--check` проверяет, что все отмеченные помещения существуют (входит в
`run_checks.sh`).

## Правила

- Масштаб и положение берутся только из общих планов этажей (линейки 9 px/м у U/L, 8 px/м у T); оси масштабируются независимо.
- Магистрали, соседние сектора, мебель и оборудование исходных планов записаны как `ignore`.
- Коридоры и магистрали U/L/T принадлежат секторам U-/L-/T-CIRCULATION.
- Перекрытие между этажами не тоньше 1,0 м; высоту стен задаёт политика по этажам (`review/decisions.md`).
- Лестницы занимают шахту целиком, двери входа и выхода стоят по центру своих маршей (`tools/complex_v4/check_stair_fit.py`).
- Проёмы шахт между этажами закрываются при генерации (обшивка и порог у выхода лестницы, `tools/complex_v4/vertical_closures.py`).
- Общую стену, проём в ней и край плиты двух секторов одного этажа рисует один владелец (D-49): CIRCULATION, иначе сектор
  с меньшим ID (`shared_face_rank` в `approved_registration.json` меняет ранг). Сосед подстраивается при построении SVG:
  края помещений ближе 0,3 м сводятся к краю владельца, своих стен на стене владельца не рисует, концы стен упирает в её
  грань, проёмы оставляет владельцу. Проверки: `tools/complex_v4/check_shared_faces.py` (SVG), `check_cross_openings.py`,
  `tools/complex_v4/tests/coplanar_check.gd` (все пары мешей; сектор, чей SVG ещё без `data-shared-faces` или чей пакет
  собран из другого SVG, помечен «ждёт перегенерации»).
- Источник правды по смыслу — `docs/world/`.

## Доработка помещений после генерации

Перегенерация меняет только пакет `gen/<этаж>/<сектор>/` (геометрия, `anchor_frames.json`). Всё, что делается руками, лежит вне
него и переживает правку плана.

**Стабильные ID.** Каждый элемент канонического SVG назван по помещению и стороне, а не по порядку (#206):

| Элемент | Стабильный ID (`data-surface-side-id` / `data-stable-id`) | ID якоря |
|---|---|---|
| стена | `U-SECURITY/dezhurnaya:north` — стена, которой помещение обращено на север | `svg:u-security--dezhurnaya--north:wall` |
| дверь, проём, окно | `U-SECURITY/dezhurnaya:door:vhodnoy-tambur` — первое по алфавиту помещение и сосед (`outer`, если соседа нет в секторе) | `svg:u-security--dezhurnaya--door--vhodnoy-tambur:door:center` |
| пол, потолок | `U-SECURITY/dezhurnaya:floor`, `…:ceiling` | `svg:u-security--dezhurnaya--floor:floor` |
| перегородка плана | `U-SECURITY/line:<ID исходного элемента>` | `svg:u-security--line--…:wall` |

Стена режется там, где меняется пара помещений по её сторонам, и принадлежит помещению на чистовой стороне. Если у помещения
на одной стороне несколько стен или дверей, к ID добавляется сосед (`…:north:koridor`), при совпадении — `-2`, `-3`.

**Предметы** ставятся в `scenes/complex_v4/set_dressing/sectors/<сектор>_dressing.tscn` с привязкой к якорям
(`AnchoredObject3D`, `scenes/complex_v4/bindings/*.bindings.json`); ручная поправка — `author_correction`.

**Отделка.** Класс помещения задаётся в `tools/complex_v4/room_finishes.json`: `sectors.<сектор>.rooms.<помещение>` (часть
`space_id` после `/`) или `sectors.<сектор>.default`. Классы — медицина, содержание, управление, жилой, старый, грузовой,
технический; их материалы стен, пола и потолка — `materials/complex_v4/finish/<класс>_{wall,floor,ceiling}.tres`, менять
внешний вид класса нужно там. Генератор канонических SVG пишет класс в план (`data-finish-class`), этап
`tools/complex_v4/room_finishes.py` после конвертера назначает материалы мешам. Стена между помещениями разных классов
получает класс с меньшим `priority` (у стены один материал). Помещение без класса сохраняет материал пакета. После правки
только материалов класса перегенерация не нужна; после правки классов — пересобрать SVG и пакет сектора (или
`python tools/complex_v4/room_finishes.py --sector <ID>` после пересборки SVG, `--check` — только проверка).

**Не правьте** `gen/**`, включая `*_material.tres` пакета: перегенерация их перезапишет.

**Что безопасно менять в плане** (`approved_registration.json`): двигать и добавлять стены, двери и помещения в других
помещениях — ID и якоря остальных помещений не меняются. Меняют ID:
- переименование помещения (подпись в исходном плане) — меняется `space_id` и все ID его стен, дверей, пола;
- новый сосед на той же стороне помещения или второй проём к тому же соседу — ID этой стороны получает уточнение;
- удаление элемента — привязки к нему блокируются (`resolve_bindings.py`), ближайший якорь не подставляется.

После правки плана: `python tools/complex_v4/build_canonical_from_approved.py`, затем `safe_regenerate.py` для изменённых
секторов и `bash tools/ci/run_checks.sh`.
