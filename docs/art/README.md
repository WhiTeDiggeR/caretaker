# Арт-пайплайн: пропы и текстуры

Задача: #118. Документы описывают, **какие** модели и текстуры нужны проекту, **откуда** они берутся и **как** приводятся к единому стилю.

| Документ | Содержание |
|---|---|
| [style-guide.md](style-guide.md) | Стиль, палитра, бюджеты, форматы, правила материалов |
| [prop-catalog.md](prop-catalog.md) | Список пропов: габарит, источник, бюджет, материалы, статус |
| [texture-catalog.md](texture-catalog.md) | Список текстур, декалей и атласов |
| [sourcing.md](sourcing.md) | Где искать готовое, какие домены нужны, лицензии, порядок отказа к генерации |
| [decisions.md](decisions.md) | Решения пайплайна: принятые исполнителем и ожидающие автора |

Исходные скрипты — `tools/props/`. Результаты — `loads/props/` (модели), `loads/textures/` (текстуры), `materials/props/` (материалы). Происхождение каждого файла — `tools/props/manifest.json`.

## Порядок получения ассета

1. **Найти готовое** (CC0, затем CC-BY с записью авторства). Нужны открытые домены, см. `sourcing.md`.
2. **Нарисовать скриптом** (Blender `bpy` → glTF, `numpy`/`PIL` → текстуры) — для всего прямоугольного, модульного и повторяющегося.
3. **Отредактировать** найденное: обрезать, перекрасить в палитру проекта, упростить, поправить опору и габарит.
4. **Сгенерировать text-to-3d** только там, где 1–3 дали плохой результат. Платформа и доступы выбираются на этом этапе (см. `decisions.md`).

Любая модель проходит `tools/props/validate_props.py` (габарит, опора, треугольники, материалы) до коммита.

## Как посмотреть в Godot

1. Получите ветку с ассетами (`git fetch origin ccr-b87fde9f-5fqcbt && git checkout ccr-b87fde9f-5fqcbt`) и откройте проект в Godot 4.7. Первый запуск импортирует новые модели и текстуры (несколько минут).
2. Откройте сцену `res://scenes/sandbox/art_showroom.tscn` и нажмите **F6** (запустить текущую сцену). Игрок стоит у стенда материалов; ряды — «Скрипт», «Poly Haven», «Poly Haven: модульные наборы». Над каждой моделью подпись: id, номер в каталоге, габарит.
3. Отдельная модель: двойной щелчок по `objects/art/<id>.tscn` (обёртка с коллизией) или по `loads/props/<id>/<id>.gltf` (только модель) в панели «Файловая система».
4. Подвижные части (`Door`, `Lid`, `Switch`, `Breaker*`, `Drawer*`, `Fan`, `Crystal`, `Hoop*`, `Needle`, `Wheel`, `Lever`) — отдельные узлы в дереве сцены модели; их можно повернуть в инспекторе.

Витрина генерируется: `python3 tools/props/make_showroom.py` (не править руками).

## Команды

```bash
pip install bpy numpy pillow                            # Blender как модуль Python 3.13 (только для сборки моделей)
python3 tools/props/make_textures.py [материал ...]    # тайловые PBR → loads/textures/<id>/
python3 tools/props/make_decals.py                      # атласы знаков, подписей, экранов, разметки → loads/textures/decals/
python3 tools/props/build_props.py [проп ...]           # модели → loads/props/<id>/ и tools/props/specs.json
python3 tools/props/build_props.py эскиз --preview DIR  # + рендер превью Cycles (≈ 20 с на кадр)
python3 tools/props/make_wrappers.py                    # сцены-обёртки objects/art/<id>.tscn
python3 tools/props/import_textures.py                  # материалы Poly Haven → те же пути, тонировка в палитру
python3 tools/props/import_models.py [id ...]           # модели Poly Haven → loads/props/ph_<id>/ (опора, бюджет, тонировка)
python3 tools/props/preview_models.py OUT.jpg [glob]    # лист превью любых glTF
python3 tools/props/make_showroom.py                    # витрина scenes/sandbox/art_showroom.tscn
python3 tools/props/validate_props.py                   # габариты, опора, бюджет, происхождение (без Blender)
godot --headless --path . --script res://tools/props/check_props.gd
```

После изменения ассетов запустите `godot --headless --editor --path . --quit`, чтобы Godot создал `.import`, и закоммитьте их вместе с файлами. Новая модель — это функция с декоратором `@prop(...)` в `tools/props/props_*.py`; её габарит, опора и бюджет проверяются автоматически.
