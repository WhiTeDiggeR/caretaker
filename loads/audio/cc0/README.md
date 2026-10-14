# Записанные звуки CC0 (#137, #209)

Записи с Freesound под лицензией CC0 1.0, выбранные автором на прослушивании. Они заменяют
сгенерированные заглушки (`loads/audio/sfx`) для этих id каталога `data/audio/sfx.json`:

| id | Источник |
|---|---|
| `step_concrete` | Freesound 459964, florianreichelt |
| `step_grate` | Freesound 669095, vestibule-door — мостки, звенящая решётка (#209; прежняя запись звучала как сплошной пол) |
| `step_metal` | Freesound 451863, kyles |
| `step_ladder` | Freesound 767343, DeqstersLab — проба: автору запись не подошла из-за гулкого эха, здесь эхо срезано коротким окном и фильтром |
| `breaker` | Freesound 451933, kyles |
| `switch` | смесь Freesound 139970 (jessepash) и 377203 (kiddpark) |
| `lever` | Freesound 386208, ldezem |
| `door_locked` | Freesound 829092, -+Fugu+- |
| `door_motor` | Freesound 322920, jedspear — ход гермодвери, 1,7 с |
| `door_stop` | Freesound 406197, kyles — удар в упор |
| `door_mech` | Freesound 438732, craigsmith — штурвал, 1,5 с |
| `door_swing` | Freesound 214002 (FenrirFangs, ручка) + 679460 (Krokulator, металлическая створка) — служебная дверь: нажатие ручки и открывание, 2,5 с (#209, OGG) |
| `door_wheel` | Freesound 559470, Nox_Sound — штурвал крутится под удержанием, 1,6 с; створка гермодвери звучит отдельно (`door_mech`) (#209) |
| `door_wheel_jammed` | Freesound 453333, kyles — запертый штурвал дёргается в упор (#209) |
| `gen_start` | Freesound 709272, Skybonator — рывок стартера, схватывание, холостые (OGG) |
| `gen_run` | Freesound 606933, Garuda1982 — бесшовная петля 16 с, громкость подогнана к холостым `gen_start` (OGG) |

Добавлены в #209 (замечания автора к синтетическим звукам):

| id | Источник |
|---|---|
| `land` | Freesound 646663, SoundDesignForYou — приземление |
| `breath` | Freesound 516696, Amekiano — один вдох-выдох после бега, 1 с |
| `airlock_cycle` | Freesound 457294, brunoboselli — нарастающий выпуск воздуха, 4,4 с (OGG); звучит только после закрытия двери |
| `breach_hit` | Freesound 827432 (jerry.berumen) + 706979 (JesterWhoo) — кувалда по кладке |
| `breach_break` | Freesound 829103 (Squirrel_404) + 550342 (Nox_Sound) — стена обрушивается, осыпь (OGG) |
| `dream_ambush` | Freesound 539968, Za-Games — низкий удар-гул вместо синтетического подъёма (OGG) |
| `dream_exit` | Freesound 275550, mbezzola — мягкий выдох воздуха (OGG) |
| `dream_stage_calm` | Freesound 478812, IanStarGem — ровный низкий фон, петля 16 с (OGG) |
| `dream_stage_alarm` | Freesound 852822, KolbyRFX — подземный вой ветра, петля 16 с (OGG) |
| `dream_stage_unease` | Freesound 852822 + 860781 (bassimat) — ветер и низкие толчки, петля 16 с (OGG) |
| `dream_stage_preawake` | Freesound 860781 + 852822 — гул с ударами давления и ветер, петля 16 с (OGG) |

Механизмы, двери и предметы больше не дают интерфейсных писков (`Interactable.ui_feedback` выключен
по умолчанию; щелчок, сигнал удержания и отказ звучат только у электронных панелей).

Генератор играет компонент `objects/audio/generator_sound.gd`: запуск при установке флага, затем петля работы в 3D.

Происхождение каждого файла, фрагмент и правки — `manifest.json`. Формат: WAV, 44,1 кГц, моно,
16 бит, пик 0,7. Шаги нарезаны на отдельные удары (`steps/<id>_NN.wav`) и играют через
`AudioStreamRandomizer` (`steps/<id>.tres`) без повторов подряд.

Источник обработки — превью Freesound (MP3 около 180 кбит/с): оригиналы через API требуют
OAuth2. При замене на оригиналы рецепты остаются прежними.

Пересобрать:

```
python3 tools/audio/cc0_sounds.py --src <папка с исходниками <id>.mp3> [--only id,id]
godot --headless --editor --path . --quit
godot --headless --path . --script res://tools/audio/build_randomizers.gd
```
