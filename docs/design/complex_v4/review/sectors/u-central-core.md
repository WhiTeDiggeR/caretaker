# U-CENTRAL-CORE

Источник: `docs/design/complex_v3/plans/sectors/upper/u_central_core.svg`. Уровень LV-U. Высота стен 3.4 м (рабочее значение, не из плана).
Масштаб: 23.914 px/м по X, 23.874 px/м по Y; анизотропия 0.2%. Положение сектора (x, z, ширина, глубина), м: [-7.78, -6.0, 15.56, 21.11].


## Помещения

| Помещение | Подпись на плане | Размер, м | м² | Проёмов | Замечания |
|---|---|---|---|---|---|
| `elektroschitovaya` | Электрощитовая | 4.52×4.52 | 20.4 | 1 | U-CENTRAL-CORE-03 |
| `sluzhebnyy-dostup-1-5-m` | СЛУЖЕБНЫЙ ДОСТУП · 1,5 М | 1.5×10.05 | 15.1 | 1 | U-CENTRAL-CORE-03 |
| `lift` | ЛИФТ | 4.52×5.03 | 22.7 | 1 | U-CENTRAL-CORE-01, U-CENTRAL-CORE-03 |
| `liftovoy-holl` | Лифтовой холл | 6.52×4.52 | 29.5 | 3 | U-CENTRAL-CORE-01, U-CENTRAL-CORE-03 |
| `promezhutochnaya-ploschadka` | промежуточная площадка | 5.52×2.26 | 12.5 | 0 | U-CENTRAL-CORE-03 |
| `verhnyaya-ploschadka` | верхняя площадка | 5.52×2.01 | 11.1 | 0 | U-CENTRAL-CORE-03 |
| `obschiy-vestibyul-vertikalno` | ОБЩИЙ ВЕСТИБЮЛЬ ВЕРТИКАЛЬНОГО УЗЛА | 14.55×5.03 | 73.1 | 2 | U-CENTRAL-CORE-03 |
| `passenger` | (без подписи) | 4.52×2.51 | 11.4 | 0 | U-CENTRAL-CORE-03 |
| `glavnaya-lestnica` | ГЛАВНАЯ ЛЕСТНИЦА | 6.52×1.51 | 9.8 | 0 | U-CENTRAL-CORE-02, U-CENTRAL-CORE-03 |
| `glavnaya-lestnica-2` | ГЛАВНАЯ ЛЕСТНИЦА | 6.52×8.29 | 54.1 | 0 | U-CENTRAL-CORE-02, U-CENTRAL-CORE-03 |

## Замечания и варианты исправления

- **U-CENTRAL-CORE-01** [геометрия] Шахта лифта 4,5×5,0 м при кабине ≈2,6×2,8 м по подписи (в handoff 2,4×2,4). Начало координат не лежит в шахте.
  - **A.** Принять 4,5×5,0 как шахту с машинным/сервисным карманом.
  - **B.** Сузить до 3,2×3,4 м.
  - Рекомендация: **A**.

- **U-CENTRAL-CORE-02** [секторный план] Лестница нарисована без проёма; площадки вынуты из комнаты. Проём в перекрытии между U и L не задан.
  - **A.** Проём = область между площадками 6,5×8,3 м.
  - **B.** Проём по двум маршам (2×1,8 м + зазор).
  - Рекомендация: **A**.

- **U-CENTRAL-CORE-03** [общий план] На техническом уровне шахта лифта «без остановки» лежит в другом месте (G-01).
  - **A.** См. G-01.
  - Рекомендация: **A**.
  - Пример: `examples/vertical_alignment.png`

## Автоматические наблюдения

- room_without_drawn_opening: U-CENTRAL-CORE/promezhutochnaya-ploschadka 
- room_without_drawn_opening: U-CENTRAL-CORE/verhnyaya-ploschadka 
- room_without_drawn_opening: U-CENTRAL-CORE/passenger 
- room_without_drawn_opening: U-CENTRAL-CORE/glavnaya-lestnica 
- room_without_drawn_opening: U-CENTRAL-CORE/glavnaya-lestnica-2 

Ничего из перечисленного не применено к каноническому SVG.
