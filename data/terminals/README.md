# Программы терминалов

Каждый файл `*.json` — программа одного терминала (`objects/terminal/terminal.tscn`, поле `program_path`). Модель — `objects/terminal/terminal_program.gd`; все файлы этой папки проверяются тестом `tests/opening/cases/terminal_case.gd`.

> Экспорт: JSON не является ресурсом Godot. В пресете экспорта добавьте `data/*` в «Filters to export non-resource files».

## Структура

```json
{
  "id": "old_cp_console",
  "title": "РЕЗЕРВНЫЙ ПУНКТ УПРАВЛЕНИЯ · ПУЛЬТ 01",
  "start": "main",
  "screens": {
    "main": {
      "redirects": [{"if": {"flag": "caretaker_assigned"}, "goto": "main_caretaker"}],
      "effects": [],
      "lines": [
        "Обычная строка печатается сразу.",
        {"text": "Строка после паузы 1,5 с.", "wait": 1.5},
        {"text": "Строка только при основном питании.", "if": {"power": {"section": "old_core", "min": "main"}}}
      ],
      "options": [
        {"text": "Сводка", "goto": "status"},
        {"text": "Протокол", "goto": "protocol", "requires": {"flag": "generator_started"}, "locked_text": "Нет основного питания"},
        {"text": "Скрытый пункт", "goto": "x", "visible_if": {"access": "caretaker"}},
        {"text": "Выход", "action": "exit"}
      ],
      "next": "screen_after_lines_when_no_options"
    }
  }
}
```

- `lines` печатаются по очереди; `wait` — пауза перед строкой (для «проверок» системы).
- Экран без `options`, но с `next`, после печати сам переходит дальше — так строятся пошаговые процедуры.
- `redirects` проверяются при входе на экран; срабатывает первый подходящий.
- `requires` делает пункт недоступным (виден серым с `locked_text`), `visible_if` — скрывает его.

## Условия

Объект, все ключи которого должны выполняться (пустой объект — всегда истина):
`flag`, `not_flag`, `access`, `not_access`, `power: {section, min, max}` (уровни `off < emergency < main`; по умолчанию `min = off`, `max = main`), `all: [...]`, `any: [...]`.

## Действия (`effects`)

Действия экрана выполняются, когда его строки допечатаны (выход по Esc до этого момента их отменяет); действия пункта — при его выборе:
`set_flag` (строка или `{flag, value}`), `clear_flag`, `grant_access`, `revoke_access`, `set_objective: {id, text}`, `set_power: {section, power}`, `event` (сигнал `event_triggered` терминала для сценария сцены).
