# Complex v3 — контракт секторной регенерации и якорей

Статус: normative draft для Issue #42

Contract ID: `caretaker.complex_v3.sector-regeneration`

Версия контракта: `1.0.0`

## 1. Назначение и нормативные слова

Этот документ задаёт единый контракт между источниками `complex_v3`, SVG-конвертером, генератором лестниц, Godot-композицией и валидатором. Он описывает данные и транзакцию регенерации, но не предписывает реализацию конкретного инструмента.

Слова **MUST / ДОЛЖЕН**, **MUST NOT / НЕ ДОЛЖЕН**, **SHOULD / СЛЕДУЕТ** и **MAY / МОЖЕТ** нормативны. Любой случай, для которого инструмент не может получить точное значение по этому контракту, является блокирующей ошибкой. Геометрическое, семантическое или идентификационное предположение не считается допустимым значением.

Вне области документа: реализация генерации, GDScript, форматы мешей, художественное наполнение и автоматическая миграция существующих сцен.

## 2. Источники истины и владение

| Область | Владелец | Разрешённое поведение регенератора |
|---|---|---|
| `docs/design/complex_v3/plans/` | автор плана | только чтение; семантика не выводится из цвета или подписи |
| `docs/design/complex_v3/handoff/` | handoff pipeline и утверждённый дизайн | только чтение; ID, оси и этажные отметки имеют приоритет над пикселями SVG |
| `Generated` в секторе | регенератор | полная замена только после успешной staging-транзакции |
| `AuthoredContent` в секторе | человек / gameplay и art | никогда не удалять, не переименовывать, не перемещать и не переписывать |
| `.tres`-материалы и назначенные material overrides | человек после первого создания | создать только при отсутствии; затем сохранять байт-в-байт, если отдельная задача явно не меняет материал |
| bindings | автор контента | регенератор читает и валидирует; изменение ссылки разрешено только явной подтверждённой repair-операцией |
| `anchor_frames.json`, generation manifest и отчёты | инструмент, указанный в `producer` | пересоздавать детерминированно из текущих источников |
| `repair_queue.json` | валидатор транзакции | создавать/обновлять детерминированно; закрывать запись только явным решением |

Нормативная структура секторной сцены:

```text
SectorRoot
|- Generated        # replaceable, tool-owned
`- AuthoredContent  # persistent, human-owned
```

Узлы внутри `AuthoredContent` могут ссылаться на якоря только через bindings. Сохранённый `NodePath` к дочернему узлу `Generated` запрещён как долговременная идентичность: порядок и пути generated-узлов не являются API.

Нормативное размещение файлов:

- `<generated-sector-package>/anchor_frames.json` и `<generated-sector-package>/generation_manifest.json` принадлежат producer и заменяются вместе с `Generated`;
- `scenes/complex_v3_blockout/bindings/<sector_slug>.bindings.json` принадлежит автору контента и не входит в generated package;
- `<staging-sector-package>/repair_queue.json` принадлежит валидатору транзакции; при блокировке его копия сохраняется в отчётах, но staging не становится live;
- фактические пути generated/staging package объявляются в generation manifest; consumer не должен угадывать их по имени каталога.

## 3. Системы координат

### 3.1 Мировая система

- единицы: метры; `1 Godot unit = 1 m`;
- горизонтальная плоскость: `XZ`;
- `+X`: восток / вправо на плане;
- `+Z`: юг / вниз на плане;
- `+Y`: вверх;
- world origin: центр шахты главного пассажирского лифта на чистом полу `LV-U`;
- поворот между каноническим планом и миром отсутствует;
- `LV-U Y=0.0`, `LV-L Y=-6.0`, `LV-T Y=-11.5`; provisional-отметки сохраняют статус и допуск handoff.

SVG-конвертер ДОЛЖЕН явно записать использованные `scale`, `origin` и `invert_z`. Результат с `origin != world` допустим только при наличии точного `local_to_world` transform. Лестничный генератор ДОЛЖЕН аналогично записать `origin`, `invert_z`, lower entry side и upper exit side. Нельзя смешивать координаты из разных пространств без применения объявленного transform.

Нормативное описание пространства:

```json
{
  "units": "m",
  "horizontal_plane": "XZ",
  "up_axis": "+Y",
  "positive_x": "east",
  "positive_z": "south",
  "space": "world",
  "local_to_world": {
    "origin": [0.0, 0.0, 0.0],
    "basis_x": [1.0, 0.0, 0.0],
    "basis_y": [0.0, 1.0, 0.0],
    "basis_z": [0.0, 0.0, 1.0]
  }
}
```

Если transform нельзя вычислить точно, staging блокируется. Значение из approximate SVG scale не может тихо заменить точный handoff transform.

## 4. Стабильные ID

1. `sector_id`, `space_id`, wall/portal/transition ID и `anchor_id` — идентичность, а не отображаемое имя.
2. ID ДОЛЖЕН происходить из явного source ID и семантической роли. Запрещено строить ID из координат, индекса массива, порядка обхода SVG, имени Godot-узла или хеша геометрии.
3. Допустимые символы: ASCII `A-Z`, `0-9`, `.`, `_`, `-`, `/`, `:`; сравнение регистрозависимое.
4. Изменение размеров или transform при сохранении той же семантической сущности сохраняет ID и меняет `geometry_hash`.
5. Разделение одной сущности на несколько или объединение нескольких сущностей создаёт новые ID. Старые ID становятся `retired`; автоматический выбор наследника запрещён.
6. Переименование допускается только через отдельную явную таблицу миграции `old_id -> new_id`, строго один-к-одному, с причиной и версией. Миграции one-to-many, many-to-one и циклы блокируются.
7. Повторное использование retired ID для другой сущности запрещено навсегда в пределах `map_id`.
8. `source_id`, `space_id`, `anchor_id`, `object_id` и `binding_id` не взаимозаменяемы.

Рекомендуемый читаемый шаблон anchor ID: `AF-<SECTOR>-<TYPE>-<SOURCE-ID>-<ROLE>`. Шаблон не заменяет реестр уникальности.

## 5. `anchor_frames.json`

### 5.1 Документ

Каждый сектор публикует один нормализованный документ:

```json
{
  "schema_id": "caretaker.anchor_frames",
  "schema_version": "1.0.0",
  "contract_version": "1.0.0",
  "map_id": "caretaker-complex-v3",
  "sector_id": "U-ROUTE-A",
  "generation_id": "sha256:<content-hash>",
  "producer": {
    "name": "svg_to_godot3d",
    "version": "1.18.0"
  },
  "coordinate_space": {
    "units": "m",
    "horizontal_plane": "XZ",
    "up_axis": "+Y",
    "space": "world"
  },
  "anchors": []
}
```

`generation_id` вычисляется из нормализованных входов и настроек, не из времени. Массив `anchors` сортируется по `anchor_id`. Дубликат ID, неизвестный тип или отсутствующее обязательное поле блокирует документ.

### 5.2 Общая запись якоря

```json
{
  "anchor_id": "AF-U-ROUTE-A-WALL-W-U-ROUTE-A-017-NORTH",
  "type": "wall",
  "status": "active",
  "source_ref": {
    "artifact_id": "geometry-handoff",
    "source_id": "W-U-ROUTE-A-017"
  },
  "origin": [-55.0, 0.0, 7.0],
  "forward": [1.0, 0.0, 0.0],
  "normal": [0.0, 0.0, 1.0],
  "up": [0.0, 1.0, 0.0],
  "geometry_hash": "sha256:<canonical-geometry-hash>",
  "bounds": {},
  "placement_limits": {}
}
```

Все векторы находятся в объявленном `coordinate_space`. `origin` — точка в метрах. `forward`, `normal`, `up` — нормализованные направляющие векторы.

Общие проверки:

- длина каждого направляющего вектора отличается от `1` не более чем на `1e-6`;
- `forward · up = 0` с допуском `1e-6`;
- `normal · forward = 0` с допуском `1e-6`;
- для вертикальной поверхности `forward × up = normal`;
- для пола `normal = up`, для потолка `normal = -up`;
- `origin` и `bounds` должны описывать одну и ту же сущность;
- нулевой, NaN/Infinity-вектор или неоднозначная ориентация блокирует якорь.

`forward` задаёт направление отсчёта вдоль линейного якоря или ориентацию объекта на точечном/плоском якоре. `normal` всегда является физической нормалью выбранной поверхности; для объёмного или точечного якоря это объявленное боковое направление. `up` задаёт локальную вертикаль и для `complex_v3` всегда совпадает с world `+Y`.

### 5.3 Типы якорей

| Тип | `origin` | `forward` | `normal` | Обязательные bounds |
|---|---|---|---|---|
| `point` | точная опорная точка | ориентация объекта | `forward × up` | `radius_m` или `0` |
| `wall` | начало выбранной чистовой грани на finished floor | вдоль грани от start к end | наружу из явно указанной стороны стены | `length_m`, `height_m`, `thickness_m`, `surface_side_id` |
| `door` | начало чистого порога | от start jamb к end jamb | из `from_space_id` в `to_space_id` | `width_m`, `height_m`, `bottom_m`, обе стороны прохода |
| `floor` | опорная вершина плоской поверхности | объявленная ось U | вверх | замкнутый `polygon_xz`, elevation и допустимая область |
| `ceiling` | опорная вершина нижней поверхности | объявленная ось U | вниз | замкнутый `polygon_xz`, underside Y и допустимая область |
| `shaft` | центр нижнего чистого сечения | от lower entry в объём шахты | `forward × up` | `clear_bounds_xz`, `bottom_y`, `top_y` |
| `stair_entry` | центр нижней линии перехода на walking surface | с площадки внутрь лестницы | `forward × up` | `clear_width_m`, `level_id`, `transition_id` |
| `stair_exit` | центр верхней линии перехода на walking surface | из лестницы на площадку | `forward × up` | `clear_width_m`, `level_id`, `transition_id` |

Для `door` отсутствие однозначного направления сторон не разрешает угадать `normal`: anchor не публикуется и создаётся blocking diagnostic. Декоративная stair-линия SVG не создаёт `shaft`, `stair_entry` или `stair_exit`. Они публикуются только из точных закрытых openings и/или проверенного отчёта генератора лестниц.

### 5.4 Пример стены

```json
{
  "anchor_id": "AF-U-ROUTE-A-WALL-W-U-ROUTE-A-017-NORTH",
  "type": "wall",
  "status": "active",
  "source_ref": {"artifact_id": "geometry-handoff", "source_id": "W-U-ROUTE-A-017"},
  "origin": [-55.0, 0.0, 7.0],
  "forward": [1.0, 0.0, 0.0],
  "normal": [0.0, 0.0, 1.0],
  "up": [0.0, 1.0, 0.0],
  "geometry_hash": "sha256:wall-example",
  "bounds": {
    "kind": "linear_surface",
    "length_m": 5.0,
    "height_m": 3.4,
    "thickness_m": 0.3,
    "surface_side_id": "U-ROUTE-A/hall_access"
  },
  "placement_limits": {
    "along_normalized": [0.05, 0.95],
    "normal_offset_m": [-0.02, 0.40],
    "height_m": [0.0, 2.4]
  }
}
```

### 5.5 Пример двери

```json
{
  "anchor_id": "AF-U-EMERGENCY-DOOR-P-U-EMERGENCY-01-FROM-VESTIBULE",
  "type": "door",
  "status": "active",
  "source_ref": {"artifact_id": "geometry-handoff", "source_id": "P-U-EMERGENCY-01"},
  "origin": [-85.0, 0.0, -1.6],
  "forward": [0.0, 0.0, 1.0],
  "normal": [-1.0, 0.0, 0.0],
  "up": [0.0, 1.0, 0.0],
  "geometry_hash": "sha256:door-example",
  "bounds": {
    "kind": "portal",
    "width_m": 1.2,
    "height_m": 2.4,
    "bottom_m": 0.0,
    "from_space_id": "U-EMERGENCY/hermetic_vestibule",
    "to_space_id": "U-EMERGENCY/capsule_hall"
  },
  "placement_limits": {
    "along_normalized": [0.0, 1.0],
    "normal_offset_m": [-0.15, 0.15],
    "height_m": [0.0, 2.4]
  }
}
```

### 5.6 Пример лестницы

Три якоря разделяют объём шахты и направления прохода. `entry`/`exit` сверяются с `selected_layout.lower_entry_side` и `upper_exit_side` отчёта генератора.

```json
{
  "transition_id": "VT-ROUTE-A",
  "generator_report": "generation_report.json",
  "anchors": [
    {
      "anchor_id": "AF-U-ROUTE-A-SHAFT-VT-ROUTE-A",
      "type": "shaft",
      "origin": [-52.5, -6.0, 9.5],
      "forward": [0.0, 0.0, -1.0],
      "normal": [1.0, 0.0, 0.0],
      "up": [0.0, 1.0, 0.0],
      "geometry_hash": "sha256:shaft-example",
      "bounds": {"clear_bounds_xz": [-54.3, 7.1, -50.7, 11.9], "bottom_y": -6.0, "top_y": 0.0}
    },
    {
      "anchor_id": "AF-U-ROUTE-A-STAIR-ENTRY-VT-ROUTE-A-LV-L",
      "type": "stair_entry",
      "origin": [-52.5, -6.0, 11.9],
      "forward": [0.0, 0.0, -1.0],
      "normal": [1.0, 0.0, 0.0],
      "up": [0.0, 1.0, 0.0],
      "geometry_hash": "sha256:entry-example",
      "bounds": {"clear_width_m": 1.5, "level_id": "LV-L", "transition_id": "VT-ROUTE-A"}
    },
    {
      "anchor_id": "AF-U-ROUTE-A-STAIR-EXIT-VT-ROUTE-A-LV-U",
      "type": "stair_exit",
      "origin": [-52.5, 0.0, 11.9],
      "forward": [0.0, 0.0, 1.0],
      "normal": [-1.0, 0.0, 0.0],
      "up": [0.0, 1.0, 0.0],
      "geometry_hash": "sha256:exit-example",
      "bounds": {"clear_width_m": 1.5, "level_id": "LV-U", "transition_id": "VT-ROUTE-A"}
    }
  ]
}
```

Числа примера иллюстрируют формат, а не заменяют проверенный stair report. Несовпадение report с handoff `rise`, level datums, clear shaft bounds или entry/exit directions блокирует promotion.

## 6. Объектные привязки

Bindings хранятся вне `Generated` и не встраиваются в generated node paths. Нормативный документ имеет `schema_id = caretaker.object_bindings`, версию, `map_id`, `sector_id` и отсортированный массив `bindings`.

### 6.1 Политики положения вдоль поверхности

Для одного линейного измерения допустима ровно одна политика:

| Policy | Поле | Значение |
|---|---|---|
| `normalized` | `value` | доля `[0,1]` от `origin` по `forward` |
| `from_start_m` | `distance_m` | метры от `origin` по `forward` |
| `from_end_m` | `distance_m` | метры от конца против `forward` |
| `centered` | `offset_m` | знаковое смещение от центра по `forward`, default `0` |

Для `wall`, `door`, `stair_entry`, `stair_exit` используется `placement.linear.along`. Для `floor` и `ceiling` используются две координаты `placement.surface.u` и `v`; каждая использует одну из тех же политик относительно объявленных U/V границ. Итоговая точка ДОЛЖНА лежать внутри точного polygon с учётом footprint. `point` не допускает along-политику. Для `shaft` требуется явно выбранная face/edge/volume policy; отсутствие выбора блокируется.

`normal_offset_m` применяется после along-координат по `normal`. `height_m` применяется после него по `up`. Оба значения обязательны, даже если равны `0.0`.

Поворот задаётся относительно anchor frame после вычисления позиции:

```json
{
  "rotation": {
    "representation": "euler_deg",
    "order": "YXZ",
    "yaw_pitch_roll": [0.0, 0.0, 0.0]
  }
}
```

Альтернатива — нормализованный `quaternion_xyzw`; одновременная запись двух представлений запрещена. `YXZ` является единственным Euler order версии 1. Поворот, выходящий за `placement_limits.rotation_deg`, блокируется.

### 6.2 Пример объектной привязки

```json
{
  "schema_id": "caretaker.object_bindings",
  "schema_version": "1.0.0",
  "map_id": "caretaker-complex-v3",
  "sector_id": "U-ROUTE-A",
  "bindings": [
    {
      "binding_id": "BIND-U-ROUTE-A-EXIT-SIGN-01",
      "object_ref": {
        "object_id": "OBJ-U-ROUTE-A-EXIT-SIGN-01",
        "scene": "res://scenes/complex_v3_blockout/zones/upper/u_route_a.tscn",
        "node_path_hint": "AuthoredContent/ExitSign01"
      },
      "anchor_ref": {
        "anchor_id": "AF-U-ROUTE-A-WALL-W-U-ROUTE-A-017-NORTH",
        "expected_type": "wall"
      },
      "placement": {
        "mode": "linear",
        "linear": {"along": {"policy": "from_end_m", "distance_m": 0.6}},
        "normal_offset_m": 0.03,
        "height_m": 2.1,
        "rotation": {
          "representation": "euler_deg",
          "order": "YXZ",
          "yaw_pitch_roll": [0.0, 0.0, 0.0]
        }
      },
      "footprint_m": [0.8, 0.25, 0.08],
      "constraints": {
        "inside_anchor_bounds": true,
        "collision_free": true
      },
      "on_missing_anchor": "block"
    }
  ]
}
```

`object_id` и `binding_id` — идентичность; `node_path_hint` служит только диагностикой. Если объект по `object_id` отсутствует или найден более одного раза, это blocking error.

## 7. Допустимые границы

Resolved placement принимается только если одновременно выполнено:

1. along/UV значение находится в declared bounds;
2. `normal_offset_m`, `height_m` и rotation находятся в `placement_limits`;
3. весь `footprint_m`, а не только pivot, лежит в допустимой области;
4. объект не пересекает generated collision, если `collision_free=true`;
5. тип anchor совпадает с `expected_type`;
6. ссылка принадлежит тому же `map_id`; межсекторная ссылка явно перечисляет оба сектора;
7. anchor имеет `status=active` и прошёл schema/basis validation.

Отсутствующий `placement_limits`, неизвестный footprint для проверки containment, неплоская поверхность без точной параметризации или несколько одинаково подходящих граней — блокирующие случаи.

## 8. Удалённые и изменённые якоря

- При отсутствии `anchor_id` binding остаётся привязанным к прежнему ID и НЕ перепривязывается.
- Запрещены nearest-anchor, совпадение по типу/имени, fuzzy match и выбор единственного кандидата без явного решения.
- Изменившийся `geometry_hash` при том же ID вызывает повторную проверку bounds и collision. Успешная проверка сохраняет binding; неуспешная создаёт repair item.
- `retired` anchor считается отсутствующим для promotion.
- Явная one-to-one ID migration может быть применена только если тип совместим, migration version поддерживается и после неё проходят все spatial checks. Факт миграции записывается в отчёт.
- Удаление объекта, удаление binding, восстановление anchor или явное перепривязывание — решения человека/владельца bindings, а не регенератора.

Любая открытая blocking-запись в repair queue запрещает замену текущего `Generated`.

## 9. `repair_queue.json`

Файл создаётся в staging даже при пустой очереди. Записи сортируются по `repair_id`. `repair_id` детерминированно вычисляется из `map_id`, `sector_id`, `binding_id`, прежнего `anchor_id`, reason и нового `generation_id`.

```json
{
  "schema_id": "caretaker.repair_queue",
  "schema_version": "1.0.0",
  "contract_version": "1.0.0",
  "map_id": "caretaker-complex-v3",
  "sector_id": "U-ROUTE-A",
  "generation_id": "sha256:<content-hash>",
  "blocking_count": 1,
  "items": [
    {
      "repair_id": "RQ-BIND-U-ROUTE-A-EXIT-SIGN-01-ANCHOR-MISSING",
      "severity": "blocking",
      "status": "open",
      "reason": "anchor_missing",
      "binding_id": "BIND-U-ROUTE-A-EXIT-SIGN-01",
      "object_id": "OBJ-U-ROUTE-A-EXIT-SIGN-01",
      "previous_anchor_ref": {
        "anchor_id": "AF-U-ROUTE-A-WALL-W-U-ROUTE-A-017-NORTH",
        "expected_type": "wall",
        "geometry_hash": "sha256:previous-wall"
      },
      "evidence": {
        "source_generation_id": "sha256:previous-generation",
        "target_generation_id": "sha256:<content-hash>",
        "message": "Referenced stable anchor ID is absent from target anchor_frames"
      },
      "candidate_anchor_ids": [],
      "allowed_actions": ["restore_anchor", "rebind_explicit", "remove_binding"],
      "resolution": null
    }
  ]
}
```

Причины версии 1: `anchor_missing`, `anchor_retired`, `anchor_type_changed`, `basis_invalid`, `out_of_bounds`, `collision_detected`, `object_missing`, `object_id_ambiguous`, `migration_ambiguous`, `schema_incompatible`, `coordinate_transform_unknown`. Кандидаты могут показываться для review, но их порядок и наличие не разрешают автоматическое применение.

Закрытая запись содержит `resolution.action`, `resolved_anchor_id` при необходимости, `approved_by`, `approved_at_utc` и `source_issue`. Валидатор отклоняет `status=resolved` без полного resolution audit trail.

## 10. Атомарная регенерация через staging

### 10.1 Дисковая транзакция

1. Получить эксклюзивную sector lock и зафиксировать входные хеши.
2. Создать новый sibling staging directory на том же filesystem. Генерация в live `Generated` запрещена.
3. Скопировать или сослаться на пользовательские материалы без их перезаписи; записать created/preserved hashes.
4. Сгенерировать геометрию, `anchor_frames.json`, manifest и отчёты только в staging.
5. Проверить schema versions, координаты, stable ID uniqueness, basis, bounds, bindings, repair queue, все заявленные файлы и tool-specific success conditions.
6. Для SVG: `errors=[]`; inspector и converter `spatial_handoff` совпадают при одинаковых semantic/geometry settings; unresolved/invalid отсутствуют.
7. Для лестниц: exit code `0`, `status=ok`, `errors=[]`, `geometry_validation.ok`, `.compiled.ok` и `.shaft.ok` равны `true`; entry/exit и level rise совпадают с handoff.
8. Выполнить доступную Godot load/smoke-проверку staging package отдельно от структурных проверок.
9. При любой ошибке оставить live package неизменным, записать failure report и repair queue.
10. Только при нуле blocking errors атомарно переименовать текущий generated package в rollback backup, а staging — в live. После post-swap validation при ошибке восстановить backup.
11. Удаление rollback backup допускается только после успешной проверки нового live package; arbitrary/unlisted files не являются stale generated files.

Atomic rename гарантируется только внутри одного filesystem. Copy-over-live или частичная замена файлов запрещены.

### 10.2 Runtime/editor-транзакция Godot

Новый subtree сначала строится как отдельный `GeneratedStaging`, не удаляя существующий `Generated`. После полной валидации ссылка меняется одной операцией на границе кадра: старый subtree удаляется только после подключения нового. `AuthoredContent` не участвует в swap. Ошибка построения сохраняет текущий `Generated` без изменений.

## 11. Версионирование и обратная совместимость

Каждый JSON этого контракта содержит `schema_id`, SemVer `schema_version` и `contract_version`.

- изменение major означает несовместимую семантику; consumer ДОЛЖЕН отклонить неизвестный major;
- minor добавляет необязательные поля или типы; consumer может принять новый minor только если неизвестные поля игнорируемы и все встреченные типы/политики известны;
- patch уточняет валидацию без изменения значения существующих полей;
- producer version не заменяет schema version;
- запись, прочитанная старым consumer, никогда не перезаписывается им в урезанном виде.

Legacy handoff `schema_version: "1.0"`, converter `conversion_report.json` и stair `generation_report.json` остаются входными форматами своих владельцев. Adapter MAY нормализовать их в этот контракт без изменения оригинала только при наличии точных данных. Отсутствующие orientation, side, floor-to-floor height или stable semantic ID не выводятся приблизительно: соответствующий anchor не создаётся, а транзакция получает blocking diagnostic.

Обратная совместимость bindings обеспечивается только сохранением stable ID либо явной one-to-one migration. Совпадение координат не является совместимостью.

## 12. Минимальная матрица проверок

| Проверка | Converter | Stairs | Godot | Validator |
|---|---:|---:|---:|---:|
| schema/version | publish | publish | consume | enforce |
| exact coordinate space/transform | publish | publish | apply | cross-check |
| stable anchor IDs | publish | publish transition anchors | resolve | uniqueness/history |
| basis and bounds | publish | publish entry/exit/shaft | apply | validate |
| materials preserved | report | report | retain overrides | hash-check |
| `AuthoredContent` untouched | n/a | n/a | enforce | scene-tree check |
| missing anchor blocks | n/a | n/a | keep current live | repair queue + block |
| atomic staging | generate staged | generate staged | swap subtree/package | gate promotion |

Promotion разрешён только если все применимые строки прошли. Чистая schema-проверка не доказывает playability; успешная генерация лестницы не доказывает совместимость с соседней сценой; Godot load не заменяет проверку stable IDs и bindings.

## 13. Ручная сверка исходных контрактов

Контракт согласован со следующими текущими инвариантами:

- handoff: метры, `XZ` horizontal, `Y` up, origin у главного лифта, fixed anchor IDs и отдельные provisional tolerances;
- SVG-конвертер: exact-data-only `spatial_handoff`, явные anchors только из `data-anchor-*`, отдельные floor/ceiling openings, отсутствие ориентации при неоднозначности, сохранение `.tres` и удаление только ранее перечисленных generated parts;
- генератор лестниц: размеры шахты в метрах, явные lower entry/upper exit sides, независимые structural/compiled/shaft validations, opt-in shaft walls с двумя границами и сохранение `.tres`;
- текущая Godot-композиция: replaceable `Generated`, постоянный `AuthoredContent`, отсутствие права регенератора переписывать ручное наполнение.

Любое расхождение будущей реализации с этим документом требует новой версии контракта до изменения данных или сцен.
