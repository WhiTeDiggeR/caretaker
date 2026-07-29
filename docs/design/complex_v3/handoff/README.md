# Комплекс v3 — 3D-handoff

Производственный пакет Issue #34. Единицы — метры; система координат и текущие статусы описаны в файлах ниже.

## Этап 1 — общая метрическая схема

- `production-brief.md` — цель, источники, ограничения и контрольные этапы.
- `production-ledger.md` — Known / Inferred / Unknown / Fixed, стабильные ID и статусы.
- `plan-style-contract.md` — единый стиль всех планов.
- `coordinate-system.md` — мировые оси, origin, этажные отметки и межэтажные опоры.
- `overview/metric-overview.json` — структурированные уровни, маршруты, опоры и обзорные контуры секторов.
- `overview/metric-overview.svg` — редактируемый обзорный план.
- `overview/metric-overview.png` — review-preview плана.
- `overview/topology.json` — проверяемый граф связей.
- `overview/topology.md` — читаемое представление графа.
- `validation/validate_stage1.py` — автоматическая проверка этапа.
- `validation/stage-1-report.md` — результаты логической, геометрической, визуальной и межартефактной проверки.

Статус этапа 1: `approved` пользователем 29 июля 2026 года.

## Этап 2 — после согласования

Паспорта секторов, точные стены и порталы, вертикальные переходы, полный JSON-handoff, manifest и итоговая проверка.
