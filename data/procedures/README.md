# Ремонтные процедуры

`*.json` — многошаговые процедуры для `objects/repair/repair_procedure.gd`. Органы управления (`objects/repair/repair_control.gd`: рычаг, вентиль, рубильник, автомат) находятся по `control_id` внутри `controls_root` процедуры. Состояние элемента — флаг `ctl/<control_id>` в `GameState`, итог — флаг `proc/<id>`; прогресс восстанавливается из сохранения.

```json
{
  "id": "generator_start",
  "title": "ГЕНЕРАТОР Г-1",
  "steps": [
    {"id": "diagnose", "hint": "Выяснить причину останова", "done_when": {"flag": "gen_diagnosed"}},
    {"id": "coolant", "hint": "Открыть вентили по схеме", "sequence": ["valve_2", "valve_1"], "order_error": "…", "early_error": "…"},
    {"id": "start", "hint": "Удерживать рычаг пуска", "all_on": ["start_lever"], "early_error": "…"}
  ],
  "completion_effects": [{"set_power": {"section": "old_core", "power": "main"}}]
}
```

- Шаг выполняется по одному из правил: `done_when` (условие, как у терминалов), `sequence` (включить элементы строго по порядку), `all_on` (включить все в любом порядке).
- Элемент более позднего шага, включённый раньше времени, возвращается обратно с сообщением `early_error`; нарушение порядка в `sequence` — с `order_error`.
- Элементы выполненных шагов фиксируются (подсказка `fixed_prompt` элемента или «ГОТОВО»).
- `hint` текущего шага становится целью игрока (если `drive_objective`).
- `completion_effects` — действия из `data/terminals/README.md`, выполняются один раз.
