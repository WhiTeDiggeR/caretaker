# T13 / #54 — пилот регенерации U-MEDBAY

Дата завершения: 2026-09-04. Статус: **verified**.

## Завершённый срез

- Safe Regenerate сохраняет `repair_queue.json` и JSON validation report вне
  staging/live до promotion, в отдельной папке конкретной попытки. Current report
  содержит пути и SHA-256. Отказ сохранения блокирует promotion.
- Ошибка deleted anchor сохраняет исходный ID, пустой список кандидатов и live
  hash. Никакой перепривязки или изменения authored composition не происходит.
- Чистая следующая попытка получает новую пустую очередь, а ранний отказ — пустой
  `validation_artifacts`; диагностика прошлой попытки не выдаётся за актуальную.
- Registry поддерживает явный planar placement пола/потолка: четыре политики для
  каждой U/V оси, физическая normal отдельно от базиса ориентации объекта, полный
  footprint после rotation и author correction, polygon и holes.
- Bind/Rebind/Record Correction проверяют конечный corrected transform **до**
  изменения ID, bindings и Undo/Redo. Недопустимый ручной move не удаляется:
  пользовательский transform остаётся на месте, correction не записывается.

## Проверки

| Проверка | Результат |
|---|---|
| `python -m unittest discover -s tools/complex_v3_regeneration/tests -v`, с canonical tool roots | 33/33, без skips |
| `anchor_surface_check.gd` | 39 checks, 0 failures |
| `anchor_runtime_check.gd` | прежние linear policies/move/rotate/resize/missing/duplicate проходят |
| `addons/complex_v3_anchor_editor/editor_operations_check.gd` | прежние операции + отказ invalid surface bind/rebind/correction проходят |
| `addons/complex_v3_regeneration_editor/regeneration_editor_check.gd` | проходит |
| `godot --headless --editor --path . --quit` | финальный импорт exit 0, без script/resource errors |
| `godot --headless --path . --quit-after 5` | exit 0; прежнее предупреждение о 2 ObjectDB instances at exit |
| `git diff --check` | проходит |

Godot: 4.7 stable, официальный build `5b4e0cb0f`. Первый cold import нового
worktree повторил прежние ошибки JPEG/FBX/EXR сторонних source assets; эти файлы
не менялись. Финальный cached import прошёл без ошибок. Проверки намеренных
отказов Python печатают `ERROR`, но unittest подтверждает ожидаемые exit/status.

## Завершение пилота

- Изолированный метрический SVG повторяет семь bounds помещений и семь portal
  segments из `complex-handoff.json`; `verify_pilot.py` фиксирует соответствие.
  У дверей явно задана inside-side, hinge не угадывается.
- Adapter добавляет объявленные limits, точные U/V ranges и holes, finished-face
  origin стен и симметричный диапазон door center. Частично пересекающий границу
  surface opening блокируется как неоднозначный.
- `resolve_bindings.py` пересчитывает transforms/bounds трёх anchored объектов и
  32 infrastructure records внутри candidate. Свободный объект не меняется.
- Сквозной тест выполняет move wall, resize wall, move door, remove anchor и
  forced generation failure. Последние два сценария сохраняют live hash; deleted
  anchor остаётся с точным старым ID и без кандидатов.
- Отдельная `pilot_scene.tscn` загружает generated architecture и четыре authored
  объекта. Строгий runtime smoke проверяет непустые imported meshes/collision
  shapes и поведение привязок после нового editor import.
- Before/after: `reports/visuals/baseline.png` и
  `reports/visuals/anchors-moved.png`. Машинная сводка и чистые composition
  evidence лежат в `reports/verification-summary.json` и `reports/baseline/`.

Финальная проверка: 33 regeneration Python tests и 7 composition-validator tests;
39 surface runtime checks; anchor, editor, regeneration-editor и pilot runtime
suites; clean Safe Regenerate и следующий deterministic no-op без Agent Fix.

Контрольный `docs/design/complex_v3/plans/sectors/upper/u_medbay.svg`, соседние
сектора, Route A и startup scene не изменены.
