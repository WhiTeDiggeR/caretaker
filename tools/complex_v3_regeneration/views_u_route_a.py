from review_views import *

def build(R):
    # ---- upper level
    box = (-66, -4, -38, 22)
    now = draw_sector(R, "U-ROUTE-A", Edit().note(-65, 20, "лестница A: проёма в перекрытии на плане нет", (150, 0, 0)), "U сейчас: проёма нет", box=box)
    h1 = Edit().add([-55.556, 10.667, 6.667, 7.777], "ПРОЁМ H1 = вся комната", (90, 90, 90)).note(-65, 20, "проём 6,7×7,8 (как в принятом пилоте)", (0, 90, 0))
    H1 = draw_sector(R, "U-ROUTE-A", h1, "U вариант H1: проём 6,7×7,8", box=box)
    h2 = Edit().add([-55.0, 10.667, 3.4, 7.0], "ПРОЁМ H2 3,4×7,0", (90, 90, 90)).note(-65, 20, "остальная часть комнаты — пол/площадка с ограждением", (0, 90, 0))
    H2 = draw_sector(R, "U-ROUTE-A", h2, "U вариант H2: проём 3,4×7,0", box=box)
    save(sheet([now, H1, H2], cols=3), "u-route-a-upper.png")
    # ---- lower level
    box = (-66, -12, -36, 24)
    nowL = draw_sector(R, "L-ARCHIVE-A", Edit().add([-55.556, 10.667, 6.667, 7.777], "U-лестница (для сравнения)", (255, 160, 160)), "L сейчас: комната лестницы 7,0×3,7 м сдвинута на 4 м и мелкая", box=box)
    a = Edit().rect("lestnica-a", [-55.556, 10.667, 6.667, 7.777]).add([-58.889, 16.2, 17.778, 2.2], "продление архива +2,2 м", NEW)
    a.rect("staryy-arhiv-edinyy-ishodnyy-3", [-58.889, 12.482, 3.333, 3.74]).rect("sluzhebnyy-prohod", [-58.889, 7.288, 14.47, 3.38]).note(-65, 21.5, "проход архива урезан до z 10,7, лестница = U", (0, 90, 0))
    A = draw_sector(R, "L-ARCHIVE-A", a, "L вариант A: лестница = U, архив продлён на юг", box=box)
    c = Edit().rect("lestnica-a", [-55.556, 9.5, 7.777, 6.667]).add([-58.889, 16.2, 17.778, 1.1], "продление архива +1,1 м", NEW)
    c.rect("staryy-arhiv-edinyy-ishodnyy-3", [-58.889, 12.482, 3.333, 3.74]).rect("sluzhebnyy-prohod", [-58.889, 7.288, 14.47, 2.2]).note(-65, 21.5, "лестница лежит вдоль X (7,8×6,7), U меняется так же", (0, 90, 0))
    C = draw_sector(R, "L-ARCHIVE-A", c, "L вариант C: лестница повёрнута вдоль X", box=box)
    save(sheet([nowL, A, C], cols=3), "u-route-a-lower.png")
