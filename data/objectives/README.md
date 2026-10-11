# Цепочки целей

Файлы `*.json` этого каталога читает автозагрузка `Objectives` (`objects/objectives/objectives.gd`).

```json
{
  "chains": {
    "<id цепочки>": {
      "final_text": "Текст цели после последнего шага (пусто — цель скрывается)",
      "steps": [
        {"id": "<id шага>", "text": "Текст на экране", "done_when": {<условие StateRules>}}
      ]
    }
  }
}
```

- Цепочку запускает сценарий: `Objectives.start(&"opening")`. Активный шаг попадает в `GameState.set_objective`.
- `done_when` — условие в формате `data/terminals/README.md` («Условия»): `flag`, `not_flag`, `access`, `power`, `all`, `any`. Если условие уже выполнено, шаг пропускается сразу.
- Прогресс сохраняется вместе с игрой (`GameState` → `objectives`).

## Флаги цепочки `opening`

Часть флагов уже ставят системы: `opening/hero_capsule_open` (капсула героя), `generator_started` (процедура генератора), `senior_key_taken` (ключ старшего), `caretaker_assigned` (протокол преемственности), `module4_ready` (чек-лист поста), `dream/returned/module_4` (выход из сна модуля 4). Флаги переходов между зонами — `opening/left_emergency_block`, `opening/reached_old_core`, `opening/reached_old_control`, `opening/reached_module_4` — ставят зоны-триггеры, когда начало будет собрано в сцене комплекса (пролог). Формулировки целей — тестовые.
