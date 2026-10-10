from review_views import *

def build(R):
    sid = "U-EMERGENCY"
    box = (-110, -10, -60, 22)
    now = draw_sector(R, sid, None, "СЕЙЧАС (C): тамбур 3,3×5,0 м, ворота по 3,6 м", box=box)
    # A: both tambur openings hermetic doors 1.8 m
    a = Edit().door(2, label="гермо 1.8×2.8", world_m=[-86.667, 2.8, -86.667, 4.6]).door(3, label="гермо 1.8×2.8", world_m=[-83.333, 2.8, -83.333, 4.6])
    a.note(-88.5, 6.8, "тамбур = шлюз, 2 гермодвери", (0, 100, 0))
    A = draw_sector(R, sid, a, "ВАРИАНТ A: оба проёма — гермодвери 1,8 м", box=box)
    # B: remove tambur, capsule hall extended to the hall wall, one hermetic door
    b = Edit().remove("germotambur").rect("kapsulnyy-zal-avariynogo-blo", [-107.778, -8.222, 24.445, 18.889])
    b.add_door([-83.333, 2.8, -83.333, 4.6], "door", "", "гермо 1.8×2.8")
    b.note(-100, 12.3, "зал удлинён на 3,3 м, одна гермодверь", (0, 100, 0))
    B = draw_sector(R, sid, b, "ВАРИАНТ B: тамбура нет, одна гермодверь", box=box)
    save(sheet([now, A, B], cols=1), "u-emergency-tambur.png")
    # states and the missing hall -> trunk door
    s = Edit()
    s.add_door([-76.0, 19.556, -73.0, 19.556], "door", "blocked", "к U-PAX: завал ✕ (нет на плане)")
    s.door(4, state="blocked", label="к медотсеку: без питания ✕")
    s.door(0, label="маршрут A: механическая, открыта")
    s.note(-82, 21, "фиолетовый — закрыто на старте, зелёный/красный — открыто", (90, 0, 90))
    S = draw_sector(R, sid, s, "СОСТОЯНИЯ на старте игры (G-05) и недостающая дверь в коридор", box=(-110, -10, -60, 24))
    save(sheet([now, S], cols=2), "u-emergency-states.png")
