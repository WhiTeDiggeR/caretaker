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

## Этап 2 — полный 3D-handoff

- `passports/sector-passports.md` — читаемые паспорта всех 30 секторов.
- `passports/sector-passports.json` — структурированные паспорта и родительские границы.
- `geometry/complex-handoff.json` — 139 точных прямоугольных пространств, стены, порталы, коридорные соединители и допуски.
- `vertical/vertical-transitions.json` — лестницы, лифты, проходящая шахта и старый наклонный тоннель.
- `vertical/vertical-section.svg` / `.png` — редактируемый разрез и review-preview.
- `map-package.json` — переносимый manifest пакета с зависимостями, покрытием и статусами.
- `validation/validate_stage2.py` — геометрическая, портальная и межартефактная проверка.
- `validation/stage-2-report.md` — сводный отчёт этапа.
- `scripts/generate_passports.py`, `scripts/generate_handoff.py`, `scripts/generate_manifest.py` — детерминированное воспроизведение структурированных материалов.

Статус этапа 2: `verified / awaiting-user-approval`. После утверждения пакет получает статус `ready-for-godot-blockout`; сам блок-аут остаётся отдельной задачей этапа 3.
