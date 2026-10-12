# Генерация узника «Боузер» сторонними средствами (#162)

Скриптовый `sleeper_bowser` из примитивов узнаётся, но выглядит игрушечно. Этот пакет описывает, как получить модель
генератором (text/image-to-3D) и поставить её в капсулу, не трогая саму капсулу.

Здесь сгенерировать не удалось: сетевая политика облачного окружения блокирует `*.hf.space`, а ключей платных сервисов нет.
Генерацию нужно запустить в браузере (бесплатно или по подписке) и прислать готовый GLB. Остальное делают скрипты.

## Что нужно получить

- Один персонаж без капсулы, стекла, пола и фона.
- Поза как на `pose_reference.jpg` (вырезка из исходного арта):
  - лежит на животе / на боку и спит, глаза закрыты;
  - голова слева, морда к зрителю в три четверти;
  - панцирь сверху, хвост справа.
- Обязательные детали:
  - зелёный панцирь с белыми коническими шипами и кремовым ободом;
  - жёлто-оранжевая чешуйчатая кожа, кремовое брюхо с пластинами;
  - рыжая грива и брови, два белых рога;
  - чёрный ошейник и браслеты с шипами, когти.
- Формат GLB с PBR-текстурами (base color, желательно normal).
- Бюджет: до 30 тыс. треугольников (больше можно, скрипт проредит) и текстуры до 2K (скрипт уменьшит до 1K).

## Шаг 1. Чистый референс (если сервис принимает картинку)

Image-to-3D работает лучше text-to-3D, если на картинке персонаж целиком на однотонном фоне. Сам арт с капсулой (зелёная
жидкость, стекло, пузыри) для этого не годится. Используйте его только как образец позы и сгенерируйте чистую картинку
любым text-to-image (FLUX, Midjourney, DALL·E, встроенный генератор Meshy/Tripo):

```
Bowser, giant turtle dragon king, sleeping peacefully lying on his belly, eyes closed, big green shell with white
cone spikes and cream rim, yellow-orange scaly skin, cream belly plates, wild red-orange mane and eyebrows, two white
horns, black spiked collar and black spiked bracelets, claws, full body visible, three-quarter front view, head on the
left, plain white background, 3D render, Nintendo game character style, soft studio lighting
```

Negative prompt: `glass, capsule, water, liquid, bubbles, background objects, cropped, text, watermark, multiple characters`.

Для text-to-3D сервиса этот же текст годится как промпт без изменений.

## Шаг 2. Image/Text-to-3D

Подойдёт любой из сервисов. Настройки: PBR включён, топология triangle, целевой полигонаж около 30 тыс., экспорт GLB.

| Сервис | Где | Права на результат (проверить на момент генерации) |
|---|---|---|
| Hunyuan3D-2 (Tencent) | бесплатно: huggingface.co/spaces/tencent/Hunyuan3D-2 | Tencent Hunyuan Community License: не действует в ЕС, Великобритании и Южной Корее |
| TRELLIS (Microsoft) | бесплатно: huggingface.co/spaces/trellis-community/TRELLIS | MIT |
| Meshy | meshy.ai | бесплатный план — CC BY 4.0 (нужна атрибуция), платный — модель ваша |
| Tripo | tripo3d.ai | бесплатный план — CC BY 4.0, платный — модель ваша |
| Rodin (Hyper3D) | hyper3d.ai | по подписке |

Выбор платформы и бюджета — открытое решение О-1 (`docs/art/decisions.md`). Запишите выбранный сервис в issue.

Удачный результат обычно получается за 2–4 попытки. Отбраковывайте варианты:

- со слипшимися конечностями;
- с «запечённой» в текстуру подсветкой;
- с кусками фона.

## Шаг 3. Нормализация и установка в капсулу

Исходный GLB в репозиторий не кладём: он большой. Храните его у себя или пришлите в чат.

```
python3 tools/props/normalize_generated.py путь/к/bowser.glb --name sleeper_bowser_gen --preview /tmp/bowser.png
python3 tools/props/make_capsule_assemblies.py --sleeper bowser=sleeper_bowser_gen
godot --headless --editor --path . --quit
```

`normalize_generated.py` (работает в Blender-Python, как `build_props.py`):

- склеивает меши, поворачивает (`--rot-y`, `--rot-x -90` для Z-up исходников);
- вписывает модель в габарит узника: x ±1,55, y от −0,86 (пол капсулы) до 0,75, z ±1,05 относительно сокета; модель смотрит на +Z, к окну;
- прореживает до `--max-tris` (30 000) и уменьшает текстуры до `--tex-size` (1024);
- пишет `loads/characters/sleeper_bowser_gen/` и сцену-обёртку `objects/characters/sleeper_bowser_gen.tscn` без коллизии.

Если морда смотрит не к окну, повторите с `--rot-y 90`, `180` или `270`.

Чтобы замена сохранялась при перегенерации сборок, поменяйте строку `"bowser"` в `SLEEPERS` в
`tools/props/make_capsule_assemblies.py`. Скриптовый `sleeper_bowser` остаётся в репозитории как запасной вариант.

## Проверка

- `bash tools/ci/run_checks.sh`.
- Рендер капсулы в `scenes/sandbox/capsule_compare.tscn`: морда читается через стекло, ничего не торчит сквозь стекло и пол.
- Новые бинарные файлы (`.bin`, текстуры) идут через Git LFS (`docs/LFS.md`).
- Источник, промпт и лицензию записать в issue и в `docs/art/prop-catalog.md`.
