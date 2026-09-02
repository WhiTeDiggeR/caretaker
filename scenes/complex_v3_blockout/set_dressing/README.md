# Complex v3 set dressing

Первый тематический проход по 30 редактируемым зонам комплекса. Геометрия и порталы берутся только из `HANDOFF-GEOMETRY-01`.

## Как редактировать зону

1. Откройте нужную сцену в `scenes/complex_v3_blockout/zones/`.
2. Отключите потолок через `include_ceilings = false` у корня зоны, если он ещё включён.
3. Раскройте `AuthoredContent/SetDressing` или откройте соответствующую сцену в `set_dressing/sectors/`.
4. Перемещайте authored-wrapper с `metadata/placement_id`, а не его дочерний `Content`. Не меняйте узлы `Generated` и геометрию порталов.

Обычный запуск `scripts/generate_set_dressing.py` записывает **только** предложения `seed/<sector>.seed.json`. Он не перезаписывает authored-сцены, manifest-инвентарь, `authored_corrections.json` или bindings — включая новые ручные узлы, материалы, изменённые ID и свободные объекты. Применение нового seed к авторскому содержимому не является seed-generation: движение выполняется только через подтверждённые anchor bindings и проверенный regeneration pipeline.

`seed_transform` и `authored_correction` в manifest, а также `authored_corrections.json` фиксируют одноразовую миграцию: итоговое положение = seed + сохранённая world-space translation/yaw/scale-поправка. Это не anchor-local `AnchoredObject3D.author_correction`. После миграции `.tscn` является источником текущих authored transforms; снимки в `migration/` — историческое свидетельство, не способ восстановить свежие правки. Старые `position`, `rotation_y`, `scale`, `id`, `space_id` и поля размещения сохранены для прежних читателей manifest.

## Stable IDs и bindings

- прежний `id` сохранён как `metadata/placement_id` для обратной совместимости;
- отдельный детерминированный `object_id` хранится на `AnchoredObject3D` и не зависит от порядка узлов;
- для 173 portal frames сохранены точные handoff portal ID, space и намерение `door:center`, но они **не** заменяют отсутствующее сопоставление с SVG source ID;
- wall mounts без исходного SVG wall ID не привязываются по ближайшей геометрии: они сохраняют world transform и перечислены в `migration/migration_report.json`;
- 145 остальных объектов явно классифицированы как `free`;
- 30 документов `scenes/complex_v3_blockout/bindings/*.bindings.json` имеют нормативную schema T01 и пока пусты. 211 unresolved intents перечислены в migration report: их активация блокируется до явного сопоставления с проверенными anchor frames. Нет угаданных ID и нет silent rebind.

Bootstrap существующей версии выполняется с зафиксированным снимком:

```powershell
python scenes/complex_v3_blockout/scripts/generate_set_dressing.py `
  --migrate-authored `
  --migration-baseline scenes/complex_v3_blockout/set_dressing/migration/before_transforms.json
```

Команда допускает только legacy manifest `1.0`, проверяет совпадение baseline с текущей сценой и отказывается перезаписывать уже мигрированное authored-содержимое. Дубли ID, неизвестные author properties/asset replacements, изменённый набор объектов, pitch/roll или полная матрица вместо поддержанного legacy yaw требуют явной миграции и блокируют запись. Для обычных seed-предложений параметры миграции не нужны; `--sector-id` ограничивает лишь seed-файлы.

## Визуальные семейства

- `medical` — медблок и аварийный сектор;
- `command` — управление и безопасность;
- `domestic` — бытовое и восточное обеспечение;
- `containment` — камеры и лаборатория сна;
- `freight` — грузовые зоны;
- `utility` — технические и центральные узлы;
- `historic` — старое ядро, архив и маршрут A.

Материалы находятся в `materials/complex_v3/`, исходные albedo-текстуры — в `loads/generated/complex_v3/textures/`.

## Объекты

Повторно используются существующие кровати, шкафы, стеллажи, терминалы, столы, серверные стойки, камеры, ящики, барьеры, верстаки, генераторы и обломки.

Новые модульные сцены в `objects/complex_v3/`: открытая дверная рама, открытый грузовой портал, операторская консоль, трубный блок, технический бак, капсула содержания и настенный транзитный маяк. Дверные рамы и маяк не имеют коллизии. Оба порога грузовых шлюзов камер имеют профиль 4,5 × 4,5 м; закрытый внешний порог тоже получает визуальную грузовую раму.

## Происхождение текстур

Все семь PNG созданы встроенным ImageGen по одному шаблону: бесшовная игровая albedo-текстура, ортографическая плоская подача, равномерное освещение, без текста, логотипов, объектов и запечённых теней. Для каждого семейства менялись палитра и характер поверхности по соответствующим mood-наброскам: медицинские композитные панели, тёмные панели управления, изношенная бытовая окраска, бронепанели содержания, маслянистый грузовой металл с оранжевой маркировкой, сине-зелёная техническая сталь и потрескавшаяся старая поверхность.

Детерминированный результат расстановки записан в `set_dressing_manifest.json`. Проверки:

```powershell
python scenes/complex_v3_blockout/validate_set_dressing.py
python scenes/complex_v3_blockout/set_dressing/validate_migration.py
python -m unittest discover -s scenes/complex_v3_blockout/set_dressing/tests -v
```
