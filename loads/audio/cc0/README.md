# Записанные звуки CC0 (#137)

Записи с Freesound под лицензией CC0 1.0, выбранные автором на прослушивании. Они заменяют
сгенерированные заглушки (`loads/audio/sfx`) для этих id каталога `data/audio/sfx.json`:

| id | Источник |
|---|---|
| `step_concrete` | Freesound 459964, florianreichelt |
| `step_grate` | Freesound 834029, IENBA |
| `step_metal` | Freesound 451863, kyles |
| `step_ladder` | Freesound 767343, DeqstersLab — проба: автору запись не подошла из-за гулкого эха, здесь эхо срезано коротким окном и фильтром |
| `breaker` | Freesound 451933, kyles |
| `switch` | смесь Freesound 139970 (jessepash) и 377203 (kiddpark) |
| `lever` | Freesound 386208, ldezem |
| `door_locked` | Freesound 829092, -+Fugu+- |

Происхождение каждого файла, фрагмент и правки — `manifest.json`. Формат: WAV, 44,1 кГц, моно,
16 бит, пик 0,7. Шаги нарезаны на отдельные удары (`steps/<id>_NN.wav`) и играют через
`AudioStreamRandomizer` (`steps/<id>.tres`) без повторов подряд.

Источник обработки — превью Freesound (MP3 около 180 кбит/с): оригиналы через API требуют
OAuth2. При замене на оригиналы рецепты остаются прежними.

Пересобрать:

```
python3 tools/audio/cc0_sounds.py --src <папка с исходниками <id>.mp3>
godot --headless --editor --path . --quit
godot --headless --path . --script res://tools/audio/build_randomizers.gd
```
