# Каталог пропов

Основа — каталог начала игры в `docs/game_design/02-prop-standard.md` (§7) и скетчи. Габариты — ш × в × г, м. Обозначения источника:

- **Скр** — рисуем скриптом (Blender `bpy`);
- **Скач** — ищем и скачиваем готовое, затем правим (нужны домены, см. `sourcing.md`);
- **Прав** — берём то, что уже в `loads/`, и правим;
- **Ген** — text-to-3d, только если Скр/Скач дали плохой результат.

Колонка «Ист.» — **первый** способ; запасной — через `/`. Волна: **В1** — начало игры (делаем первым), **В2** — комплекс по секторам, **В3** — по мере необходимости. Статус: `готов`, `в работе`, `план`.

## 1. Начало игры (В1)

| ID | Проп | Габарит | Класс | Ист. | Материалы | Подвижное | Волна | Статус |
|---|---|---|---|---|---|---|---|---|
| P-001 | `emergency_cabinet` Аварийный шкаф | 0,8×1,9×0,4 (с ручкой 0,45) | интерактив | Скр | painted_metal, glass_dirty, декаль «+» | `Door` | В1 | **v1 готов** |
| P-002 | `evac_sign` Указатель эвакуации | 0,6×0,2×0,05 | малый | Скр | plastic_panel, emissive, атлас знаков | — | В1 | **v1 готов** |
| P-003 | `mnemonic_panel` Мнемосхема | 2,0×1,2×0,15 | интерактив | Скр | painted_metal, экран-схема, индикаторы | `Screen` | В1 | **v1 готов** |
| P-004 | `rubble_set` Завал прохода (3 модуля) | ≥4,5×2,5×1,8 | фон | Скр / Скач | concrete_rubble, rusted_steel (арматура) | — | В1 | **v1 готов** |
| P-005 | `fallen_duct` Упавший воздуховод | 3,5×0,6×0,6, низ 1,2–1,4 | фон | Скр | duct_galvanized, rusted_steel | — | В1 | **v1 готов** |
| P-006 | `ventilation_unit` Вентиляторный агрегат | 1,5×1,5×1,0 | фон | Скр | painted_metal, steel_bare | `Fan` | В1 | **v1 готов** |
| P-007 | `control_desk` Пульт с рубильником | 1,6×1,0×0,8 | интерактив | Скр | painted_metal, plastic_panel, экран | `Switch` | В1 | **v1 готов** |
| P-008 | `terminal_console` Терминал | 1,2×1,5×0,7 | интерактив | Скр | painted_metal, plastic_panel, экран | — | В1 | **v1 готов** |
| P-009 | `generator_panel` Щит генератора с автоматами | 1,2×1,8×0,3 | интерактив | Скр | painted_metal, plastic_panel, индикаторы | `Door`, автоматы | В1 | **v1 готов** |
| P-010 | `valve_wheel` Вентиль | Ø0,3, ось 0,15 | малый | Скр | steel_bare, rusted_steel | `Wheel` | В1 | **v1 готов** |
| P-011 | `pressure_gauge` Манометр / тахометр | Ø0,2×0,08 | малый | Скр | steel_bare, циферблат (декаль) | `Needle` | В1 | **v1 готов** |
| P-012 | `start_lever` Рычаг пуска (напольный) | 0,4×1,2×0,3 | малый | Скр | painted_metal, rubber | `Lever` | В1 | **v1 готов** |
| P-013 | `wall_breaker` Рубильник / автомат | 0,25×0,35×0,12 | малый | Скр | plastic_panel, steel_bare | `Handle` | В1 | **v1 готов** |
| P-014 | `chain_hanging` (цепь с потолка), `cable_hang` (обрывки кабелей) | 0,08×1,23 / 0,36×1,54 | малый | Скр | steel_bare, rubber | — | В1 | **v1 готов** |
| P-015 | `staff_pod` Аварийная капсула персонала | 1,0×1,2×2,4 | «герой» | Скр / Ген | painted_metal, glass_dirty, emissive | `Lid` | В1 | **v1 готов** |
| P-016 | `immersion_chair` Кресло погружения с кристаллом и обручами | 1,0×2,2×1,2 | «герой» | Скр / Ген | painted_metal, vinyl, crystal (свечение) | `Crystal`, `Hoop` | В1 | **v1 готов** |
| P-017 | `chamber1_gate` Смятые ворота камеры №1 | 5,6×4,5 | «герой» | Скр / Ген | painted_metal, steel_bare, rusted_steel | — | В1 | **v1 готов** |
| P-018 | `personal_key` Личный ключ | 0,08×0,03 | малый | Скр | steel_bare | — | В1 | **v1 готов** |
| P-019 | `document_sheet` Лист/папка документа | 0,42×0,3 | малый | Скр | paper_aged | — | В1 | **v1 готов** |
| P-020 | `staff_body` Тело сотрудника | рост ≈1,75 | «герой» | **решение автора** | — | — | В1 | ждёт решения |

## 2. Исправление существующих (В1, правка)

| ID | Сцена / источник | Проблема (из §6 стандарта) | Решение | Ист. | Статус |
|---|---|---|---|---|---|
| P-101 | `loaded_locker` / `loads/3D_locker_3.fbx` | 0,30 м шириной, нужно 0,5 | новая модель `locker_tall` 0,5×1,9×0,53, двери `Door1/2` | Скр | **v1 готов** (в сцены не подставлялась) |
| P-102 | `loaded_cabinet` / `loads/3D_cabinet_3.fbx` | 0,4 м, нужен картотечный 0,5×1,3 | новая модель `file_cabinet` 0,5×1,3×0,48, ящики `Drawer1–4` | Скр | **v1 готов** (в сцены не подставлялась) |
| P-103 | `wall_terminal` | опора в центре | пересобрать с креплением к плоскости стены | Скр | план |
| P-104 | `emergency_light`, `caged_light` | опора в центре / принять | опора по стандарту | Скр | план |
| P-105 | `temporary_blast_door` | заменяется семейством дверей | рама и створка строятся `objects/doors/door_art.gd` по размерам двери; пульт `door_panel`, штурвал `door_wheel`, ручка `door_handle`, петля `door_hinge` (P-210a–d, #157) | Скр | **готово** |
| P-106 | `bowser_pod`, `herobrine_pod` (по 84–88 МБ) | непомерный вес | три варианта на выбор автора (#130): облегчённая копия `loads/*_capsule/lod/` (40 тыс., нормали запечены с исходника, 2,3–2,5 МБ; `tools/props/lighten_capsules.py --bake`), скриптовые `capsule_bowser`, `capsule_herobrine` (`tools/props/props_capsules.py`); сравнение — `scenes/sandbox/capsule_compare.tscn`, `docs/art/previews/capsules_compare.jpg`. Исходники не тронуты | Прав | **решено (О-5): облегчённые копии в `scenes/bowser_pod.tscn`, `scenes/herobrine_pod.tscn`** (удалены в #216 — заменены сборками `prisoner_capsule_*` ниже); скриптовые остаются в репозитории для сравнения. **v2 (#162):** скриптовые капсулы переделаны по артам (окно-стадион, торцевые барабаны с эмблемой, консоль «РЕЖИМ СНА», общие с капсулой персонала дуги, табличка «КАПСУЛА», шланги в распределительные коробки); узники — отдельные пропы `sleeper_herobrine`, `sleeper_bowser`; сборки `objects/containment/prisoner_capsule_{herobrine,bowser}.tscn` (узел `Sleeper` меняется отдельно, маркеры `RoomLinkL/R` — точки подключения кабелей комнаты; генерирует `tools/props/make_capsule_assemblies.py`); превью `docs/art/previews/capsules_v2.jpg`. **#210:** задняя стенка из металла корпуса, узник висит в цветной жидкости (голубая / зелёная) с пузырями, свет — от видимой лампы-балки под потолком; Херобрин свернулся на боку и чуть темнее (до/после — `docs/art/previews/capsules_210_before_after.jpg`). Пакет для генерации Боузера сторонним сервисом — `docs/art/gen/bowser/README.md` (`tools/props/normalize_generated.py`, `make_capsule_assemblies.py --sleeper`) |
| P-107 | `debris_pile` | низкий для завала | заменяется P-004 | — | план |

## 3. Общие модульные наборы (В2)

| ID | Набор | Состав | Ист. |
|---|---|---|---|
| P-201 | `pipe_kit` | **готово:** `pipe_straight` 2 м, `pipe_elbow`, `pipe_tee` (фланцы, хомут); вентиль — `valve_wheel` | Скр |
| P-202 | `cable_tray_kit` | **готово:** `cable_tray_straight` 2 м на потолочных шпильках с траверсами (ставится на высоту потолка − 0,55 м), `cable_tray_wall` 2 м на настенных консолях с подкосами (#157); повороты — план | Скр |
| P-203 | `duct_kit` | **готово:** `duct_straight` 2 м с фланцами и подвесами; колено и решётки — план | Скр |
| P-204 | `door_frame_kit` | рамы дверей уже делает генератор комплекса (`objects/complex_v4/open_door_frame.tscn`); створки и пульты — семейство `objects/doors/` | не нужен |
| P-205 | `floor_grates` | **готово:** `floor_grate` 1×1; люки и жёлоба — план | Скр |
| P-206 | `lights_kit` | **готово:** `fluorescent_light`, `emergency_beacon`, `evac_sign`; лампа в клетке — уже есть (`loads/caged_hanging_light`) | Скр |
| P-207 | `rail_barrier_kit` | перила, ограждения, лестничные поручни, ступени-вставки | Скр |

## 4. Сектора комплекса (В2–В3)

Позиции берутся из скетчей; для каждого сектора сначала проверяется, что хватает наборов раздела 3.

| Сектор / скетчи | Нужные пропы | Ист. |
|---|---|---|
| Центр управления (`upper/control`) | операторские кресла (P-301), консоли-пульты (вариант P-007), стойки серверов, настенные экраны | Скр |
| Медблок (`upper/medbay`) | операционный стол (есть `medical_bed`), хирургический светильник, шкаф-витрина с препаратами, стойка с капельницей, тележка, кислородный баллон, табурет | Скр/Скач |
| Жилой / бытовой (`upper/domestic`) | койки, тумбы, столы, стулья | Скач |
| Охрана (`upper/security`) | оружейный шкаф, мониторный пост, решётчатые двери | Скр |
| Склады / грузовой (`upper/freight`, `technical/freight`) | ящики, поддоны, контейнеры, бочки, погрузчик-тележка, грузовые ворота | Скач/Скр |
| Энергоблок (`technical/energy`) | генератор Г-1 (доработка `generator_unit`), щиты, трубы высокого давления, баллоны | Скр |
| Утилиты, цех (`technical/utilities`, `workshop`) | верстаки, станки, шкафы инструмента, тиски, стеллажи | Скач/Скр |
| Нижний уровень (`lower/*`) | кабели, цепи, решётки, ржавые трубы, лужи/жёлоба | Скр |
| Камеры (`lower/chamber_*`) | усиления: балки, распорки, ворота, фиксаторы, оковы | Скр/Ген |
| Врата снов | арка-портал — отдельная задача (мир сна) | Ген |
| Хаб-мелочь | бумаги, кружки, личные вещи, инструменты, фонарь | Скач |

## 4а. Что сделано (v1, скрипты `tools/props/`)

Первая партия: 19 моделей (`loads/props/<id>/`), все проходят `tools/props/validate_props.py` и `tools/props/check_props.gd`. Фактические габариты и бюджет — `tools/props/specs.json`.

Принятые отступления от габаритов каталога (выступающие детали, ручки, решётки):

| Проп | Каталог | Модель | Причина |
|---|---|---|---|
| `emergency_cabinet` | 0,8×1,9×0,4 | 0,81×1,90×0,45 | ручка выступает на 5 см |
| `evac_sign` | 0,6×0,2 | 0,4×0,2×0,05 | пропорция знака 2:1 в атласе (дёшево менять) |
| `mnemonic_panel` | 2,0×1,2×0,15 | …×0,17 | рамка индикаторов |
| `control_desk` | 1,6×1,0×0,8 | 1,62×1,09×0,83 | рубильник над пультом |
| `terminal_console` | 1,2×1,5×0,7 | 1,22×1,52×0,73 | монитор, кабель |
| `generator_panel` | 1,2×1,8×0,3 | 1,2×1,8×0,34 | автоматы выступают |
| `ventilation_unit` | 1,5×1,5×1,0 | 1,5×1,5×1,03 | предохранительная решётка вентилятора |
| `staff_pod` | 1,2×1,35×2,6 (Р-16) | 1,25×1,35×3,0 | пульт на стойке у ног и шланги у головы; размеры совпадают с заготовкой `objects/props/staff_capsule.gd` |
| `fallen_duct` | низ 1,2–1,4 | нижняя точка 1,25 | потолок 2,85 м, левый конец у подвесов |
| `chamber1_gate` | 5,6×4,5 | 5,6×4,5×1,33 | погнутые прутья выходят вперёд |

Оценка по рендерам (Blender, Cycles): аварийный шкаф, мнемосхема, щит генератора, вентагрегат, капсула, кресло — читаются и вписываются в скетчи; завал, ворота камеры №1 и воздуховод — рабочие, но «героев» (ворота, капсула, кресло) стоит показать автору до обработки: это пункт О-4 в `decisions.md`.

## 4б. Скачанные модели (Poly Haven, CC0)

Импорт — `tools/props/import_models.py` по списку `tools/props/sourced_models.json`: опора по стандарту, бюджет треугольников, тонировка альбедо в палитру (насыщенность ×0,7, яркость ×0,85 по умолчанию). Обёртки — `objects/art/ph_*.tscn`, превью — `docs/art/previews/polyhaven_models.jpg`, `polyhaven_kits.jpg`.

### Аналоги наших моделей — что выбрано

| Наше | Poly Haven | Решение |
|---|---|---|
| `duct_straight` (P-203) | `ph_airduct_rect` (24 детали: колена, тройники, переходы, решётки), `ph_airduct_round` (21 деталь, с вентилятором) | **основной — Poly Haven**: богаче и закрывает колена, которых у нас нет; наш прямой участок оставлен для `fallen_duct` |
| `pipe_straight/elbow/tee` (P-201) | `ph_industrial_pipes` (8 деталей, вентиль с маховиком и манометром) | **основной — Poly Haven**; наши — запасные длинные прямые |
| кабели (P-202, P-014b) | `ph_electric_cables` (≈40 деталей: короба, выключатели, розетки) | **Poly Haven** для настенной проводки; наши свисающие обрывки остаются |
| `fluorescent_light` (P-206) | mounted_fluorescent_lights | **наш**: у Poly Haven голые трубки без корпуса |
| `wall_breaker` (P-013), `generator_panel` (P-009) | `ph_power_box`, `ph_utility_box` | оба: наши — сюжетные пульты с подписями, Poly Haven — фоновые щитки |
| `emergency_cabinet` (P-001) | `ph_medical_box` | дополнение (аптечка на полке/стене) |
| `locker_tall`, `file_cabinet` (P-101/102) | — | наши |
| остальные наши пропы начала | аналогов нет | наши |

### Принятые модели

| id | Источник | Габарит, м / состав | Каталог |
|---|---|---|---|
| `ph_airduct_rect` | [modular_airduct_rectangular_01](https://polyhaven.com/a/modular_airduct_rectangular_01) | набор: 18 деталей | P-203 |
| `ph_airduct_round` | [modular_airduct_circular_01](https://polyhaven.com/a/modular_airduct_circular_01) | набор: 16 деталей | P-203 |
| `ph_industrial_pipes` | [modular_industrial_pipes_01](https://polyhaven.com/a/modular_industrial_pipes_01) | набор: 8 деталей | P-201 |
| `ph_electric_cables` | [modular_electric_cables](https://polyhaven.com/a/modular_electric_cables) | набор: 49 деталей | P-202 |
| `ph_power_box` | [power_box_01](https://polyhaven,com/a/power_box_01) | 0,46×0,50×0,40 | P-013 |
| `ph_utility_box` | [utility_box_01](https://polyhaven,com/a/utility_box_01) | 0,52×1,12×0,43 | P-009 |
| `ph_hanging_lamp` | [hanging_industrial_lamp](https://polyhaven,com/a/hanging_industrial_lamp) | 0,55×1,36×0,55 | P-206 |
| `ph_wall_lamp` | [industrial_wall_lamp](https://polyhaven,com/a/industrial_wall_lamp) | 0,27×0,43×0,14 | P-206 |
| `ph_medical_box` | [medical_box](https://polyhaven,com/a/medical_box) | 0,53×0,10×0,35 | P-001 |
| `ph_spacecraft_instrument` | [vintage_spacecraft_instrument](https://polyhaven,com/a/vintage_spacecraft_instrument) | 0,41×0,27×0,20 | P-007 |
| `ph_radio_transceiver` | [vintage_radio_transceiver](https://polyhaven,com/a/vintage_radio_transceiver) | 0,57×0,43×0,41 | P-008 |
| `ph_multimeter` | [retro_multimeter](https://polyhaven,com/a/retro_multimeter) | 0,22×0,28×0,20 | P-011 |
| `ph_office_desk` | [metal_office_desk](https://polyhaven,com/a/metal_office_desk) | 2,00×0,79×0,95 | P-301 |
| `ph_tool_chest` | [metal_tool_chest](https://polyhaven,com/a/metal_tool_chest) | 0,69×0,65×0,41 | P-301 |
| `ph_tool_cart` | [tool_cart](https://polyhaven,com/a/tool_cart) | 1,27×0,97×0,75 | P-301 |
| `ph_metal_rack` | [worn_metal_rack](https://polyhaven,com/a/worn_metal_rack) | 0,92×1,90×0,60 | P-301 |
| `ph_barrel_oil` | [Barrel_01](https://polyhaven,com/a/Barrel_01) | 0,56×0,88×0,56 | P-301 |
| `ph_barrel_fuel` | [barrel_03](https://polyhaven,com/a/barrel_03) | 0,63×0,93×0,64 | P-301 |
| `ph_propane_tank` | [propane_tank](https://polyhaven,com/a/propane_tank) | 0,34×0,55×0,34 | P-301 |
| `ph_lpg_tank` | [small_lpg_tank](https://polyhaven,com/a/small_lpg_tank) | 0,41×0,64×0,41 | P-301 |
| `ph_welding_cart` | [portable_welding_cart](https://polyhaven,com/a/portable_welding_cart) | 0,84×1,56×0,66 | P-301 |
| `ph_cardboard_box` | [cardboard_box_01](https://polyhaven,com/a/cardboard_box_01) | 0,39×0,34×0,52 | P-301 |
| `ph_plastic_crate` | [plastic_crate_03](https://polyhaven,com/a/plastic_crate_03) | 0,48×0,27×0,27 | P-301 |
| `ph_military_crate` | [wooden_military_crate](https://polyhaven,com/a/wooden_military_crate) | 1,24×0,47×0,52 | P-301 |
| `ph_jerrycan` | [metal_jerrycan](https://polyhaven,com/a/metal_jerrycan) | 0,35×0,46×0,17 | P-301 |
| `ph_trash_can` | [metal_trash_can](https://polyhaven,com/a/metal_trash_can) | 1,78×0,91×0,56 | P-301 |
| `ph_hand_truck` | [hand_truck](https://polyhaven,com/a/hand_truck) | 0,59×1,40×0,69 | P-301 |
| `ph_bench_vice` | [bench_vice_01](https://polyhaven,com/a/bench_vice_01) | 0,20×0,28×0,40 | P-301 |
| `ph_drill_press` | [old_drill_press](https://polyhaven,com/a/old_drill_press) | 0,53×1,05×0,61 | P-301 |
| `ph_ladder` | [ladder_sectioned_01](https://polyhaven,com/a/ladder_sectioned_01) | 0,66×2,13×0,18 | P-301 |
| `ph_metal_stool` | [metal_stool_02](https://polyhaven,com/a/metal_stool_02) | 0,45×0,46×0,47 | P-301 |
| `ph_metal_chair` | [metal_stool_03](https://polyhaven,com/a/metal_stool_03) | 0,46×1,02×0,47 | P-301 |
| `ph_bed_frame` | [old_bed_frame](https://polyhaven,com/a/old_bed_frame) | 0,91×1,20×2,00 | P-301 |
| `ph_clipboard` | [clipboard](https://polyhaven,com/a/clipboard) | 0,23×0,04×0,34 | P-019 |
| `ph_gas_mask` | [old_gas_mask](https://polyhaven,com/a/old_gas_mask) | 0,21×1,13×0,31 | P-301 |
| `ph_security_camera` | [security_camera_01](https://polyhaven,com/a/security_camera_01) | 0,17×0,29×0,55 | P-301 |
| `ph_crt_television` | [television_02](https://polyhaven,com/a/television_02) | 0,40×0,41×0,35 | P-008 |
| `ph_manhole_cover` | [water_manhole_cover](https://polyhaven,com/a/water_manhole_cover) | 0,69×0,07×0,69 | P-205 |
| `ph_pipe_wrench` | [pipe_wrench](https://polyhaven,com/a/pipe_wrench) | 0,08×0,41×0,04 | P-301 |
| `ph_crowbar` | [crowbar_01](https://polyhaven,com/a/crowbar_01) | 0,04×0,56×0,13 | P-301 |
| `ph_bolt_cutters` | [bolt_cutters_01](https://polyhaven,com/a/bolt_cutters_01) | 0,15×0,80×0,04 | P-301 |
| `ph_sledgehammer` | [sledgehammer_01](https://polyhaven,com/a/sledgehammer_01) | 0,21×1,01×0,09 | P-301 |
| `ph_toolbox` | [metal_toolbox](https://polyhaven,com/a/metal_toolbox) | 0,40×0,30×0,27 | P-301 |
| `ph_ammo_box` | [ammo_box](https://polyhaven,com/a/ammo_box) | 0,09×0,18×0,26 | P-301 |
| `ph_oil_tin` | [oil_tin](https://polyhaven,com/a/oil_tin) | 0,11×0,20×0,15 | P-301 |
| `ph_flashlight` | [vintage_flashlight](https://polyhaven,com/a/vintage_flashlight) | 0,10×0,14×0,31 | P-018 |

Надписи на английском на крышке `ph_medical_box` («FIRST AID») и наклейке `ph_utility_box` («DANGER») нужно перекрыть нашими декалями (`signs_ru`) — мелкая доработка при расстановке.

### Отклонено

| Ассет | Причина |
|---|---|
| industrial_caged_sconce | набор разрозненных деталей |
| fire_alarm | английский текст FIRE ALARM |
| korean_fire_extinguisher_01 | корейский текст |
| steel_frame_shelves_01 | современная мебель |
| drawer_cabinet | современная деревянная мебель |
| industrial_pastic_container | современный бытовой пластик |
| SchoolChair_01 | современный пластик |
| exterior_aircon_unit | бытовые внешние блоки |
| portable_generator | современный брендированный |
| mounted_fluorescent_lights | голые трубки без корпуса; наш fluorescent_light лучше |

Правило: модели с крупным нерусским текстом, современным брендированным или бытовым видом не принимаются (канон: русский текст, старая техническая эстетика).

### Чего нет на Poly Haven

Медблок (стойка капельницы, хирургический светильник, шкаф-витрина), операторские кресла, серверные стойки, оружейный шкаф. Это кандидаты для ambientCG/Sketchfab (нужны домены и токен, см. `sourcing.md`) или для скрипта.

## 5. Бюджет первой партии

Фактически 19 моделей ≈ 55 000 треугольников и ≈ 2,6 МБ суммарно (самый тяжёлый — щит генератора 326 КБ), текстуры общие (см. `texture-catalog.md`). Допустимый вес: до 1 МБ на малый проп, до 3 МБ на интерактив, до 10 МБ на «героя».
