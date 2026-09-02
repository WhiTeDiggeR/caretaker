# T08 / #49 — проверка миграции

Baseline: `1157dd8` (`team/integration` до T08). Изменены только dressing-слой, его generator и инструменты проверки. SVG, generated architecture, материалы и startup scene не изменены.

## Владение и результат

- 30 authored-сцен, 356 persistent object IDs; все прежние placement IDs сохранены.
- Seed-предложения отделены в `set_dressing/seed/`. Обычный seed-run не записывает authored-сцены, corrections, manifest или bindings вообще. Это сохраняет произвольные редакторские правки, а не только распознанные transform-поля.
- Legacy bootstrap — отдельный `--migrate-authored`; повторный bootstrap поверх v2 отклоняется. Неподдерживаемые формы legacy-данных и дубли ID блокируют запись.
- 145 объектов явно free. 38 wall mounts и 173 portal frames имеют unresolved intents с известными space/side/portal данными. В текущих планах нет подтверждённого соответствия этих данных SVG anchor IDs; никаких anchor IDs не выдумано. Нормативные bindings-файлы пусты и принадлежат автору. Активация требует явного source mapping и валидного frame в последующих пилотах.
- Единственная существенная seed/world поправка: `PX-E-L01-L-OLD-CORE`. Его сохранённый frame находился в `[-73,-6,15]`, новый seed предлагает `[-62,-6,8.666]`. Миграция сохраняет прежнее положение, не исправляя геометрию под видом миграции.

## Проверки

- `validate_set_dressing.py`: PASS, 183 props / 173 portal frames / 38 wall mounts, минимальный service clearance 1.50 м.
- `validate_migration.py`: PASS, 356 уникальных ID, 211 unresolved intents, 145 free.
- Unit tests: **9/9 PASS** — bootstrap на изменённом seed, повторная генерация с пользовательскими bindings/materials/узлами, запрет повторной миграции, unknown transform/NaN/duplicate ID и отсутствие выдуманной portal-привязки.
- Полная и частичная seed-generation: SHA-256 всех 62 authored-файлов (30 сцен + 30 binding documents + manifest + corrections) не изменился.
- `audit_set_dressing_transforms.py`: before/after и repeat audit, max delta = 0, tolerance = 0.00001.
- `set_dressing_scene_check.gd`: реальные экземпляры Godot из committed legacy `.tscn` против новых `Content`-поддеревьев, **2035 Node3D**, 356 объектов, max world-matrix delta = **0**. Проверяет также типы и состав дочерних узлов, а не только текстовые positions.
- Godot 4.7: headless editor load, startup runtime smoke и загрузка всех 30 dressing scenes.
- Графический `--visual` использует Compatibility/OpenGL в скрытом окне; шесть кадров `visuals/{u_medbay,t_utilities,l_old_core}_{before,after}.png` проверены визуально. Каждая пара имеет нулевую попиксельную разницу. Это изображения реальных секторных сцен, не схематические top-down данные.
- `git diff --check`: PASS.

Полный cold import первоначально сообщил о существующих сторонних FBX/EXR texture sources; эти assets вне T08 не менялись. Финальная editor-load проверка после импорта: exit 0, без ошибок. Runtime smoke: exit 0; остаётся ранее известное предупреждение о 2 ObjectDB instances при выходе. Графическая проверка не заявляет покрытие Forward+ shading: она проверяет сохранение визуального содержания до/после в одинаковом renderer.

## Повторение Godot audit

```text
godot --headless --path . --script res://scenes/complex_v3_blockout/set_dressing/set_dressing_scene_check.gd
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://scenes/complex_v3_blockout/set_dressing/set_dressing_scene_check.gd -- --visual
```

Visual mode явно отклоняет `--headless`, поскольку тот отключает отрисовку. Для baseline audit требуется Git и доступный commit `1157dd8`; отсутствие baseline блокирует проверку, а не подменяется текущей сценой.
