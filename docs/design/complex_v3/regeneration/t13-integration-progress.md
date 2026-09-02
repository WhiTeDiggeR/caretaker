# T13 / #54 — промежуточные исправления интеграции

Дата: 2026-09-02. Статус: **in-progress**, не приёмка пилота U-MEDBAY.

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
| `python -m unittest discover -s tools/complex_v3_regeneration/tests -q`, с `GODOT_BIN` | 22/22, без skips |
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

## Что ещё требуется для #54

1. Точный изолированный SVG U-MEDBAY и источник соответствия его стабильных IDs
   метрическому handoff; контрольный сектор и startup не менять.
2. Adapter converter frames: объявленные допустимые rotation/offset ranges и
   U/V bounds; происхождение и применённые floor/ceiling openings не терять.
   Runtime намеренно не угадывает отсутствующие значения converter 1.19.
3. Реальное вычисление transform/bounds объектов и generated infrastructure
   для **нового** candidate. Сейчас Safe Regenerate обновляет anchors в копии
   composition input, но не пересчитывает старые bounds; это ещё не полноценный
   binding-resolution этап и не доказательство безопасности moving-object сцены.
4. Четыре pilot-объекта (wall terminal, door beacon, floor object, free object),
   сценарии move wall/door, resize wall, remove anchor, forced failure;
   полный editor workflow и before/after изображения в Godot.

Ни один существующий сектор, authored dressing или startup `.tscn` этим срезом
не изменён. #54 и зависимые rollout-задачи не помечаются done.
