# T13 — точная параметризация floor/ceiling

Дополнение к разделу 6.1 T01; не меняет смысл существующих linear bindings.
JSON сохраняет `caretaker.anchor_frames` / `caretaker.object_bindings` версии
`1.0.0`: добавляются ранее не конкретизированные поля плоских bounds. Старый
consumer, не поддерживающий surface placement, обязан блокировать такую привязку.

Для пола и потолка U = `forward`, V = `forward × up`. Оба направления единичные,
горизонтальные. `origin` — начало отсчёта; диапазоны не обязаны начинаться с нуля.
`bounds.u_range_m` и `bounds.v_range_m` — пары `[min, max]` в метрах относительно
origin, не world X/Z. Позиция до correction:

`origin + U*u + V*v + normal*normal_offset_m + up*height_m`.

Поворот объекта задаётся в невырожденном базисе `(U, up, V)`. Физическая normal
остаётся `+up` для floor и `-up` для ceiling; она влияет на normal offset,
но не заменяет третью ось ориентации объекта.

```json
{
  "anchor_id": "svg:pilot-floor:floor",
  "type": "floor",
  "status": "active",
  "origin": [20.0, 3.0, 30.0],
  "forward": [0.0, 0.0, 1.0],
  "normal": [0.0, 1.0, 0.0],
  "up": [0.0, 1.0, 0.0],
  "bounds": {
    "kind": "planar_surface",
    "u_range_m": [0.0, 12.0],
    "v_range_m": [0.0, 8.0],
    "polygon_xz": [[20.0, 30.0], [20.0, 42.0], [12.0, 42.0], [12.0, 30.0]],
    "holes_xz": []
  },
  "placement_limits": {
    "normal_offset_m": [0.0, 0.0],
    "height_m": [0.0, 0.0],
    "rotation_deg": {"yaw": [-180.0, 180.0], "pitch": [0.0, 0.0], "roll": [0.0, 0.0]}
  }
}
```

Это фрагмент frame: обязательный `source_ref`, идентичность документа и hash
добавляются производителем. Числа иллюстрируют формат, не геометрию U-MEDBAY.

Фрагмент binding:

```json
{
  "placement": {
    "mode": "surface",
    "surface": {
      "u": {"policy": "normalized", "value": 0.5},
      "v": {"policy": "from_end_m", "distance_m": 2.0}
    },
    "normal_offset_m": 0.0,
    "height_m": 0.0,
    "rotation": {"representation": "euler_deg", "order": "YXZ", "yaw_pitch_roll": [0.0, 0.0, 0.0]}
  },
  "footprint_m": [1.0, 1.0, 1.0],
  "footprint_center_m": [0.0, 0.5, 0.0],
  "constraints": {"inside_anchor_bounds": true, "collision_free": true},
  "on_missing_anchor": "block"
}
```

`footprint_center_m` — необязательный центр локального bounding box относительно
pivot, default `[0,0,0]`. Габарит после полного transform, включая correction,
обязан целиком входить в UV bounds и polygon. `holes_xz` — массив точных world-XZ
полигонов вырезов; отсутствие означает отсутствие вырезов, и adapter обязан это
доказать по геометрии, а не потерять openings из upstream report. Проверка
включает рёбра/площадь footprint, не только pivot или отдельные углы.

Неизвестные bounds, footprint, rotation limits, неоднозначная параметризация,
нечисловые/неfinite значения блокируют resolution. Объект сохраняет прежний
transform и ID. Поддержка runtime сама по себе не доказывает успешную композицию:
нужны актуальные generated collisions, support и проверка candidate до promotion.
