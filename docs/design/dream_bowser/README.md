# Сон Боузера S — планы для генератора (#191)

Метрические SVG-планы первого погружения S в формате `svg-plan-to-godot` (svg_to_godot3d ≥ 1.19.0) — того же, что у комплекса v4
(`docs/design/complex_v4/plans/generation/`). Геометрия снята с блокаута `scenes/dreams/bowser_dream.tscn` (#182) и сверена с ТЗ
`docs/game_design/06-bowser-dream-world.md` и набросками `docs/game_design/bowser_dream/05_first_dive_s.svg`, `06_first_fight_zone.svg`.
Сцена сна не менялась: подключение пакета вместо блокаута — отдельная задача после генерации.

## Состав

| Файл | Что это |
|---|---|
| `plans/s_low.svg` | нижний уровень, отметка пола **0,0**: терраса S1, карниз S2, стенки уступа 1,2 м |
| `plans/s_high.svg` | верхний уровень, отметка пола **1,2**: верх уступа, цепной мост, двор S3, зал печати S4, мост и бастион S5 |
| `tools/dream/bowser_s_plans.py` | спецификация планов (`--write`), проверка без генератора (`--check`), запуск генератора (`--generate`) |
| `tools/dream/tests/` | тесты формата; входят в `tools/ci/run_checks.sh` |

Два плана, потому что конвертер принимает одну отметку `--elevation` на SVG, а сон стоит на двух уровнях (уступ 1,2 м).
Правила формата те же, что у комплекса: метры (`data-scale="1"`), +X — восток, +Z (ось y плана) — юг; у каждого элемента стабильный
`id` и `data-godot-type`; у пола — `data-space-id`; высота стены — `data-wall-height` от отметки плана, толщина — `data-wall-thickness`;
двери — линии на стене с `data-door-height` (над проёмом остаётся перемычка); потолок — `data-ceiling-elevation` в абсолютной отметке;
`data-source-id="blockout:<узел>"` указывает узел блокаута, из которого взят элемент.

Стены идут по осевым линиям стен блокаута с их толщиной (1,0 м у двора и зала), поэтому внутренние грани совпадают с блокаутом.
Планы правятся в спецификации `tools/dream/bowser_s_plans.py` и перезаписываются `--write`. Если планы потом правят руками
(Inkscape), `--check` покажет расхождение со спецификацией предупреждением, а ошибки формата — ошибками.

## Якоря вместо узлов-крючков

Узлы блокаута, к которым привязан геймплей (`BowserDream`, #183, засада, останки), стали явными маркерами
`data-godot-type="marker"` с `data-anchor-id` и `data-anchor-role="gameplay_hook"`. Генератор публикует их в `spatial_handoff`
как точечные якоря, так что после замены геометрии объекты можно поставить по якорям, а не по координатам.

| Якорь | Узел блокаута (`data-hook-node`) | План | x, z (м) |
|---|---|---|---|
| `DREAM-S/spawn` | `Spawn` | s_low | 4, 0 |
| `DREAM-S/silhouette-spot` | `Terrace/SilhouetteSpot` | s_low | 12, −4 |
| `DREAM-S/wake-line` | `Yard/Ambush/WakeLine` | s_high | 56, 0 |
| `DREAM-S/guard-spawn-north` | `Yard/Ambush/GuardSpawnNorth` | s_high | 68,5, −5,75 |
| `DREAM-S/guard-spawn-south` | `Yard/Ambush/GuardSpawnSouth` | s_high | 68,5, 6,25 |
| `DREAM-S/hall-threshold` | `Yard/Ambush/HallThreshold` | s_high | 70, 0 (в проёме) |
| `DREAM-S/remains` | `Yard/Remains` (тело) | s_high | 49,6, −7,7 |
| `DREAM-S/weapon-spot` | `Yard/Remains/WeaponSpot` | s_high | 50,9, −7,0 |
| `DREAM-S/seal` | `SealHall/Seal` | s_high | 80, 0 |
| `DREAM-S/seal-slot` | `SealHall/SealSlot` | s_high | 80, 0 |
| `DREAM-S/side-door` | `SealHall/SideDoor` | s_high | 80, −8,5 (в проёме) |
| `DREAM-S/gate` | `Bastion/Gate` | s_high | 80, −25 |

Маркер — точка на полу плана; ориентацию (например, взгляд `Spawn` на восток) точечный якорь не несёт — она остаётся в сцене.

## Размеры: ТЗ, блокаут, план

| Участок | ТЗ | Блокаут #182 | План | Разница |
|---|---|---|---|---|
| S1 терраса | 16 × 12 м | 16 × 12, пол 0,0 | пол 16 × 12, отметка 0,0, без стен и потолка | — |
| S2 карниз и уступ | 14 м, уступ 1,2 м | карниз 10 × 3 + уступ 4 × 3, верх 1,2 | карниз 10 × 3 (s_low) + стенки уступа h 1,2 по контуру 4 × 3 (s_low) + пол уступа 4 × 3 (s_high) | стенки уступа толщиной 0,3 по контуру: по 0,15 м внутрь и наружу |
| Цепной мост | 16 м | 16 × 2, цепи h 1,0 / 0,1 | пол 16 × 2 + стены-цепи h 1,0, толщина 0,1 | — |
| S3 двор | 24 × 18 м | пол 24 × 18 (до оси стены зала), стены h 8 / 1,0; вход 4 × 5; южный проход 3 × 4,5; колонны 2 × 2 | пол 23,5 × 18 (чистый, до грани стены зала) + стены h 8 / 1,0; дверь-арка 4 × 5; дверь `branch-closed` 3 × 4,5; колонны — по 4 стены 1 × 1 / 1,0 = 2 × 2 × 8 | пол под стеной зала добавляет конвертер (`floor_extent: wall-outer`) |
| S4 зал печати | 20 × 16 м, h 12, двери 7 м | чистые 19,5 × 16, стены h 12 / 1,0, потолок 13,2 с просветом 4 × 4 над печатью; вход 4 × 7, северная 3 × 5, восточная 3 × 5 (решётка) | пол 19,5 × 16; стены h 12 / 1,0; потолок 13,2 + `ceiling-opening` 4 × 4; двери 4 × 7 (`giant-arch`), 3 × 5 (`side-door`), 3 × 5 (`branch-closed`) | — |
| Мост к бастиону | 12 м | 3 × 12 от оси стены зала, перила h 0,9 / 0,2 | пол 3 × 11 от внешней грани стены + перила h 0,9 / 0,2 | проходимая длина одинакова — 11 м |
| S5 бастион | 10 × 8 м | 10 × 8, парапеты h 1,0 / 0,4 | пол 10 × 8 + парапеты h 1,0 / 0,4 | — |
| Толщина пола | — | плиты 1,5 м (терраса, двор, зал), мост 0,4 | все полы 0,2 м (`--floor-thickness 0.2`, как в комплексе) | над лавой видны тонкие кромки — при необходимости юбки вручную |

Весь маршрут `BowserDream.route()` (10 точек от террасы до врат) лежит на полах или в дверях планов своей отметки — это проверяет
`--check`.

## Что остаётся ручным в сцене

Формат описывает полы, стены, двери, потолки, вырезы и точки. Всё остальное остаётся в сцене сна:

- **лава**: плоскость `LavaSurface` и зона `Lava` (Area3D, выталкивание), граница падения `FALL_LIMIT_Y`;
- **небо и свет**: `Mood` (WorldEnvironment), `Sun`; открытые участки (терраса, карниз, мосты, двор, бастион) в планах без потолка;
- **объекты геймплея**: печать с кольцами (`SealHall/Seal`, #183), врата (`Bastion/Gate`), створка боковой двери, игрок;
- **закрытые ветки В-1**: завал `Branches/RubbleSouth` (закрывает южную дверь двора), решётка `Branches/GrateEast` (восточная дверь
  зала), обрушенная лестница `Branches/CollapsedStair`; проёмы под них в планах есть и помечены `data-door-type="branch-closed"`;
- **декор двора**: упавшая колонна, ниша с останками (две стенки h 4 и крыша — мелкая постройка, её удобнее держать префабом),
  тело, цепь-образ, жаровня, метка оператора, ниши стражей, линия порога;
- **кромки плит** над лавой, если тонкий пол 0,2 м будет выглядеть хуже массивного блокаута.

## Команды для автора

Генератора в облаке нет. Из корня репозитория, на ветке `task/191-dream-svg-plans` (или на `team/integration` после слияния):

```powershell
python tools/dream/bowser_s_plans.py --check
python tools/dream/bowser_s_plans.py --generate --svg-tool-root <путь к svg-plan-to-godot (svg_to_godot3d >= 1.19.0)>
godot --headless --editor --path . --quit
```

`--generate` для каждого плана запускает тот же предварительный осмотр и конвертер, что `regenerate_sector.py` комплекса
(`--dry-run` только печатает команды). Без обёртки то же самое вручную:

```powershell
$svg = "<путь к svg-plan-to-godot>"
$common = "--profile","generic","--scale","1","--origin","none","--wall-thickness","0.3","--floor-thickness","0.2","--ceiling-thickness","0.2","--strict-wall-overlaps"
python "$svg\scripts\inspect_svg_plan.py" docs/design/dream_bowser/plans/s_low.svg @common --elevation 0 --json --output-json gen/dreams/bowser_s/s_low/preflight_report.json --strict
python "$svg\scripts\svg_to_godot3d.py" docs/design/dream_bowser/plans/s_low.svg gen/dreams/bowser_s/s_low/Generated/Architecture @common --elevation 0 --resource-dir res://gen/dreams/bowser_s/s_low/Generated/Architecture --scene-name bowser_s_low_generated --strict
python "$svg\scripts\inspect_svg_plan.py" docs/design/dream_bowser/plans/s_high.svg @common --elevation 1.2 --json --output-json gen/dreams/bowser_s/s_high/preflight_report.json --strict
python "$svg\scripts\svg_to_godot3d.py" docs/design/dream_bowser/plans/s_high.svg gen/dreams/bowser_s/s_high/Generated/Architecture @common --elevation 1.2 --resource-dir res://gen/dreams/bowser_s/s_high/Generated/Architecture --scene-name bowser_s_high_generated --strict
```

(Каталоги `gen/dreams/bowser_s/<план>/Generated/Architecture` создайте заранее; обёртка делает это сама.)

**Ожидается.**

- В `gen/dreams/bowser_s/s_low/Generated/Architecture/` и `.../s_high/...` появятся `bowser_s_low_generated.tscn` и
  `bowser_s_high_generated.tscn`, а также `.obj`, материалы и `conversion_report.json`. После импорта в Godot добавятся `.import`.
- В `conversion_report.json`:
  - `errors: []`, `generator_version` ≥ 1.19.0;
  - `counts` для s_low: `input_floor 3`, `input_wall 4`;
  - `counts` для s_high: `input_floor 6`, `input_wall 22`, `input_door 5`, `input_ceiling 1`, `ceiling_openings_requested 1`.
- В `spatial_handoff.anchor_frames` есть 12 якорей `DREAM-S/*` из таблицы выше, а также якоря стен, полов и дверей вида `svg:<id>:…`.
- В осмотре (`preflight_report.json`) `unrecognized` и `invalid` равны 0.

**Если осмотр в `--strict` откажет.** Возможные причины: открытые полы без потолка, стены без помещения по обе стороны (цепи,
перила, парапеты) или потолок только над залом. Пришлите в #191 `preflight_report.json`. Это правится в спецификации без
генератора: например, перила и парапеты можно перевести в ручные объекты.

После генерации закоммитьте `gen/dreams/bowser_s/**` (с `.import`, созданными Godot) в эту ветку. Подключение вместо блокаута —
отдельная задача, предложение ниже.

## Подключение (следующая задача, не входит в #191)

1. В `bowser_dream.tscn` добавить узел `Generated` с экземплярами двух сгенерированных сцен.
2. Удалить из сцены статические тела блокаута, которые теперь генерируются: `Terrace/Floor`, `Path/*`, `Yard/Floor`, стены,
   перемычки и колонны двора, `SealHall/*` (кроме `Seal`, `SealSlot`, `SideDoor`), `Bastion/Bridge|Rail*|Floor|Parapet*`.
3. Узлы-крючки оставить на прежних путях (их читают `BowserDream` и тесты `tests/dreams/bowser_dream_check.gd`). Сверить их
   позиции с якорями `DREAM-S/*`.
4. Прогнать `tests/dreams/bowser_dream_check.gd` и пройти маршрут вручную (F-режимы тестового сна).
