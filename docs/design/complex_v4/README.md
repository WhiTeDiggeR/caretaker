# Комплекс v4 — канонические источники генерации

Версия 4 самодостаточна: всё, из чего строятся сцены комплекса, лежит в `docs/design/complex_v4/`, код — в `scenes/complex_v4/`,
`tools/complex_v4/` и `addons/complex_v4_*`. Материалы прежней версии (v3) остались в своём каталоге и для v4 не нужны.

## Состав

| Путь | Что это |
|---|---|
| `plans/generation/{upper,lower,technical}/` | 32 канонических метрических SVG — единственный геометрический вход генератора |
| `sources/plans/sectors/` | исходные планы секторов (утверждённые презентационные планы), из которых построены канонические SVG |
| `handoff/` | метаданные комплекса: описание пространств и порталов (`geometry`), вертикальные переходы (`vertical`), паспорта секторов (`passports`) |
| `regeneration/vertical-markup.md` | контракт разметки лестниц и шахт в SVG (`data-vertical-*`) |
| `review/` | итоги ревизии: статус вопросов, решения D-01…D-45, карточка и картинка на сектор |

## Конвейер

1. `tools/complex_v4/build_canonical_from_approved.py` строит `plans/generation/*.svg` из `sources/plans/` по правилам
   `tools/complex_v4/approved_registration.json` (привязка к общим планам этажей, поправки D-01…D-45). Элементы, добавленные в
   исходные планы позже (пилоты), в построении не участвуют.
2. `tools/complex_v4/build_sector_manifest.py` собирает `sector_generation_manifest.json`; лестницы выводятся из разметки SVG
   (`vertical_resolver.py`, определения — `vertical_definitions.json`).
3. `tools/complex_v4/safe_regenerate.py --sector <ID>` атомарно пересобирает пакет сектора в `gen/<этаж>/<сектор>/`.
4. Сцены `scenes/complex_v4/zones/*` подключают пакеты; сборка комплекса — `scenes/complex_v4/complex_v4_blockout.tscn`,
   проходная тестовая сцена — `complex_v4_blockout_test.tscn`.
5. `bash tools/ci/run_checks.sh` — все проверки (Python и headless Godot).

## Правила

- Масштаб и положение берутся только из общих планов этажей (линейки 9 px/м у U/L, 8 px/м у T); оси масштабируются независимо.
- Магистрали, соседние сектора, мебель и оборудование исходных планов записаны как `ignore`.
- Коридоры и магистрали U/L/T принадлежат секторам U-/L-/T-CIRCULATION.
- Перекрытие между этажами не тоньше 1,0 м; высоту стен задаёт политика по этажам (`review/decisions.md`).
- Лестницы занимают шахту целиком, двери входа и выхода стоят по центру своих маршей (`tools/complex_v4/check_stair_fit.py`).
- Источник правды по смыслу — `docs/world/`.
