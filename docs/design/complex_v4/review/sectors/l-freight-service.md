# L-FREIGHT-SERVICE

Источник: `docs/design/complex_v3/plans/sectors/lower/l_freight_service.svg`. Уровень LV-L. Высота стен 5.0 м (рабочее значение, не из плана).
Масштаб: 19.8 px/м по X, 20.0 px/м по Y; анизотропия 1.0%. Положение сектора (x, z, ширина, глубина), м: [11.11, 69.56, 16.67, 10.0].

- Проверка по общему плану: комната плана 26.77×8.0 м, на общем плане 26.67×10.0 м.

## Помещения

| Помещение | Подпись на плане | Размер, м | м² | Проёмов | Замечания |
|---|---|---|---|---|---|
| `ventilyaciya` | ВЕНТИЛЯЦИЯ | 7.83×8.0 | 62.6 | 1 | L-FREIGHT-SERVICE-01 |
| `raspredelitelnaya` | РАСПРЕДЕЛИТЕЛЬНАЯ | 7.83×8.0 | 62.6 | 1 | L-FREIGHT-SERVICE-01 |
| `gruzovaya-platforma` | ГРУЗОВАЯ ПЛАТФОРМА | 11.11×8.0 | 88.9 | 2 | L-FREIGHT-SERVICE-01 |
| `zaschischennyy-sluzhebnyy-ob` | защищённый служебный обход нижнего г | 26.77×2.0 | 53.5 | 0 | L-FREIGHT-SERVICE-01 |
| `gruzovoy-lift` | ГРУЗОВОЙ ЛИФТ | 13.13×8.0 | 105.0 | 2 | L-FREIGHT-SERVICE-01 |
| `privod` | привод | 3.54×4.0 | 14.1 | 2 | L-FREIGHT-SERVICE-01 |
| `sluzhebnyy` | служебный | 3.54×4.0 | 14.1 | 1 | L-FREIGHT-SERVICE-01 |
| `obhod-shahty-avariynaya-svya` | обход шахты · аварийная связь | 16.67×2.0 | 33.3 | 0 | L-FREIGHT-SERVICE-01 |

## Замечания и варианты исправления

- **L-FREIGHT-SERVICE-01** [общий план] Вентиляция и щитовая на секторном плане лежат внутри блока 27 м, на общем — вне его; высота 8 против 10 м. Блок смещён на 5,6 м относительно U (G-02). Обходы без дверей.
  - **A.** Принять секторный план.
  - **B.** Выровнять с общим.
  - Рекомендация: **A**.
  - Пример: `examples/vertical_alignment.png`

## Автоматические наблюдения

- room_without_drawn_opening: L-FREIGHT-SERVICE/zaschischennyy-sluzhebnyy-ob 
- room_without_drawn_opening: L-FREIGHT-SERVICE/obhod-shahty-avariynaya-svya 

Ничего из перечисленного не применено к каноническому SVG.
