# Источники готовых ассетов

Состояние на 2026-10-10: **скачивание из облачного окружения заблокировано** политикой сети. Открыт PyPI, `api.github.com`, GitHub (релизы), npm. Закрыты все ассет-сайты.

## Домены, которые нужно добавить в Allowed domains окружения

| Домен | Зачем |
|---|---|
| `polyhaven.com`, `api.polyhaven.com`, `dl.polyhaven.org` | CC0 модели и PBR-текстуры (основной источник) |
| `ambientcg.com` | CC0 PBR-материалы, декали |
| `sketchfab.com`, `api.sketchfab.com`, `media.sketchfab.com` | модели CC0/CC-BY через API (нужен API-токен как секрет окружения `SKETCHFAB_TOKEN`) |
| `kenney.nl` | CC0 наборы (только как запасной) |
| `quaternius.com` | CC0 модели (запасной) |
| `opengameart.org` | CC0/CC-BY мелочь (запасной) |
| `fonts.google.com`, `fonts.gstatic.com` | шрифты для знаков (запасной; локальные DejaVu/Liberation уже есть) |

Инструкция для окружения: `https://code.claude.com/docs/en/cloud-environments#network-access`.

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
