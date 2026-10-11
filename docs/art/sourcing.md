# Источники готовых ассетов

Состояние на 2026-10-11 (домены открыты автором):

| Источник | Состояние | Что нужно |
|---|---|---|
| Poly Haven (`api.polyhaven.com`, `dl.polyhaven.org`) | **работает**: материалы и модели скачиваются | — |
| Poly Haven превью (`cdn.polyhaven.com`) | закрыт | не обязателен; для быстрого просмотра кандидатов добавить домен |
| ambientCG API (`ambientcg.com`) | работает (поиск) | — |
| ambientCG файлы и превью | **закрыты**: файлы раздаются с `acg-download.struffelproductions.com`, превью — с `acg-media.struffelproductions.com` | добавить оба домена в Allowed domains |
| Sketchfab API (`api.sketchfab.com`) | поиск работает | скачивание требует токен: секрет окружения `SKETCHFAB_TOKEN`; `media.sketchfab.com` отвечает 403 |
| `kenney.nl`, `quaternius.com`, `opengameart.org` | закрыты | запасные, не обязательны |

Скачанное приводится к стандарту скриптами `tools/props/import_textures.py` (материалы) и `tools/props/import_models.py` (модели); источник, авторы и правки записываются в `tools/props/manifest.json`.

## Лицензии

- Скачиваем по умолчанию **CC0**. Принимаются без согласования.
- **CC-BY** — только с записью автора, ссылки и лицензии в `tools/props/manifest.json`; в титры игры автор попадёт позже. Список таких ассетов должен быть коротким.
- Не принимаются: CC-BY-NC, CC-BY-ND, «editorial use», Royalty-free без права на распространение в составе игры, ассеты без явной лицензии.

## Поисковые запросы (кандидаты, проверить после открытия доменов)

| Что | Где искать | Ключевые слова |
|---|---|---|
| Бетон, ржавый металл, оцинковка | Poly Haven textures, ambientCG | `concrete`, `rusty metal`, `corrugated`, `galvanized`, `diamond plate`, `painted metal` |
| Бумага, дерево, ткань | ambientCG | `paper`, `plywood`, `fabric`, `leather` |
| Бочки, баллоны, поддоны | Poly Haven models | `barrel`, `gas cylinder`, `pallet`, `crate` |
| Трубы, вентили | Poly Haven, Sketchfab CC0 | `pipe`, `valve`, `industrial` |
| Стулья, кресла, койки | Poly Haven, Sketchfab CC0 | `office chair`, `stool`, `metal bed` |
| Медицинское | Sketchfab CC0 | `iv stand`, `medical trolley`, `surgical lamp`, `oxygen tank` |
| Мелочь (кружка, бумаги, инструменты) | Poly Haven | `tools`, `mug`, `clipboard` |

## Порядок отказа к генерации

Ассет уходит на text-to-3d, если выполняется хотя бы одно:

1. Готовое не нашлось или не подходит по стилю после перекраски.
2. Скриптовая форма читается плохо на рендере (силуэт «примитивный»).
3. Нужна органическая или сложная форма: капсула, кресло, арка-врата, тело, смятые ворота.

Перед первой генерацией выбираем платформу и бюджет; результаты проходят ретопологию и перекраску (`style-guide.md`), иначе не принимаются.
