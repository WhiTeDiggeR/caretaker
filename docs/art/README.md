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

## Команды

```bash
pip install bpy numpy pillow                            # Blender как модуль Python 3.13 (только для сборки моделей)
python3 tools/props/make_textures.py [материал ...]    # тайловые PBR → loads/textures/<id>/
python3 tools/props/make_decals.py                      # атласы знаков, подписей, экранов, разметки → loads/textures/decals/
python3 tools/props/build_props.py [проп ...]           # модели → loads/props/<id>/ и tools/props/specs.json
python3 tools/props/build_props.py эскиз --preview DIR  # + рендер превью Cycles (≈ 20 с на кадр)
python3 tools/props/make_wrappers.py                    # сцены-обёртки objects/art/<id>.tscn
python3 tools/props/validate_props.py                   # габариты, опора, бюджет, происхождение (без Blender)
godot --headless --path . --script res://tools/props/check_props.gd
```

После изменения ассетов запустите `godot --headless --editor --path . --quit`, чтобы Godot создал `.import`, и закоммитьте их вместе с файлами. Новая модель — это функция с декоратором `@prop(...)` в `tools/props/props_*.py`; её габарит, опора и бюджет проверяются автоматически.
