# Complex v3 blockout

Автономная Godot 4.7 сцена Issue #35. Она процедурно строит метрический blockout из утверждённых JSON-файлов handoff и не изменяет `scenes/underground_research_complex.tscn`.

## Состав

- `complex_v3_blockout.tscn` — переиспользуемая подсцена без игрока, света и UI.
- `complex_v3_assembly.gd` — собирает 30 секторных сцен и единственную общую infrastructure-сцену.
- `complex_v3_blockout.gd` — контроллер сектора с production-режимом `REGENERATED_PACKAGE` и диагностическим `HANDOFF_PREVIEW`.
- `complex_v3_sector_wrapper.gd` — контракт владельцев: заменяемый `Generated` с внешними слоями `Architecture`/`Stairs`, отдельный persistent `AuthoredContent` и transient `EditorPreview` без physics.
- `complex_v3_zone.tscn` и `zones/{upper,lower,technical}/` — общая база и 30 тонких сцен по stable sector ID.
- `complex_v3_infrastructure.tscn` — магистрали, межзонные соединители и вертикальные переходы без дублирования по зонам.
- `res://objects/complex_v3/main_core_switchback_stair.tscn` — самостоятельная редактируемая лестница главного ядра; зональные сцены содержат только совпадающий с ней монтажный проём.
- `sector_catalog.json` — проверяемый индекс сцен, уровней, количества помещений и непосредственных соседей.
- `complex_v3_blockout_test.tscn` — автономная сцена проверки с игроком, окружением и обзорной камерой.
- `complex_v3_blockout_check.gd` — headless runtime-проверка количества построенных сущностей.
- `complex_v3_portal_check.gd` — физическая проверка капсулой всех открытых внутренних и внешних порталов.
- `complex_v3_sector_check.gd` — runtime-проверка всех 30 сцен, их суммарного состава и трёх режимов просмотра.
- `review/u_emergency_plan_assembly.tscn` — обзорная сцена фрагмента плана аварийного блока: `U-EMERGENCY`, `U-MEDBAY`, `U-ROUTE-A`, локальный участок `U-PAX`, соединители и отдельная лестница маршрута A без потолков.
- `complex_v3_visual_check.gd` — воспроизводимые контрольные рендеры всех 30 зон в `user://complex_v3_sector_captures` при запуске с полноценным renderer.
- `scripts/render_plan_previews.cjs`, `render_scene_topdowns.py` и `compose_scene_plan_comparisons.py` — полностью фоновые SVG/source-data сравнения без управления пользовательским экраном.
- `complex_v3_editor_preview_check.tscn` / `.gd` — editor-only проверка временной геометрии, отсутствия collision и сохранности `AuthoredContent`.
- `main_core_switchback_stair_check.gd` и `main_core_switchback_stair_visual_check.tscn` — отдельная проверка размеров, коллизий и четырёх воспроизводимых ракурсов лестницы.
- `validate_blockout_source.py` — статическая сверка источников и границ задачи.
- `validate_sector_scenes.py` — сверка секторных сцен с паспортами и полной сборкой.
- `fixtures/sector_wrapper_fixture.tscn`, `sector_wrapper_contract_check.gd` и `validate_sector_wrapper_contract.py` — доказательство сохранности ручного ресурса при удалении и перестройке generated-слоя.

В test scene `F1` переключает первое лицо и общий вид, `F2` циклически меняет уровень, `F3` — режим `FULL / SECTOR / NEIGHBORS`, `F4` и `Shift+F4` — следующую и предыдущую зону.

`T-CIRCULATION` — паспорт общей технической циркуляции без собственных room spaces. В полной сборке его геометрией владеет только `complex_v3_infrastructure.tscn`; отдельный запуск сцены `T-CIRCULATION` включает эту инфраструктуру как диагностический preview.

Ручные объекты конкретной зоны следует добавлять только в отдельную authored-сцену `set_dressing/sectors/<slug>_dressing.tscn`, подключённую как `AuthoredContent/SetDressing`. Генератор детерминированно пересобирает тонкие sector wrappers, но не записывает authored-сцены. Узел `Generated` полностью принадлежит регенератору и содержит отдельные слои `Architecture` и `Stairs` из `res://gen/**`.

Regeneration wrapper принимает `PackedScene` для generated-архитектуры, generated-лестниц и ручного слоя. `AuthoredContent` обязан быть корнем отдельной сцены; rebuild собирает `GeneratedStaging`, заменяет только прежний `Generated` и валидирует прямые sibling-корни. Все 30 production-сцен используют `REGENERATED_PACKAGE`; старый handoff-builder доступен только как диагностический preview и тестовый fallback.

В production-сценах `editor_preview_enabled` отключён: редактор показывает подключённый пакет `res://gen/**`, поэтому старая handoff-геометрия не может сосуществовать с ним. В режиме `HANDOFF_PREVIEW` временная геометрия не сохраняется в `.tscn`, не содержит physics collision и остаётся доступной для диагностических сцен и тестов.

## Текущая граница blockout

Главное пассажирское ядро имеет трассированные помещения, открытую шахту, кабину и отдельную физическую двухмаршевую лестницу между LV-U и LV-L. При открытии `u_central_core.tscn` или `l_central_core.tscn` вместо лестницы виден только подготовленный проём; единственный экземпляр лестницы добавляется общей инфраструктурой в полной сборке. Остальные лифты и лестницы пока показаны опорными объёмами, а старый наклонный тоннель имеет физическую рампу. Рабочая анимация кабины и детальные лестницы остальных узлов остаются последующими этапами.
