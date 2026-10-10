from review_views import *

def wd(R, sid, i, w, label=None):
    o = R[sid]["openings"][i]["world_m"]
    cx, cz = (o[0] + o[2]) / 2, (o[1] + o[3]) / 2
    vert = abs(o[0] - o[2]) < 1e-6
    return dict(world_m=[o[0], cz - w / 2, o[0], cz + w / 2] if vert else [cx - w / 2, o[1], cx + w / 2, o[1]], label=label or f"{w:g}")

def build(R):
    sid = "U-EAST-SUPPORT"
    box = (6, -10, 36, 25)
    now = draw_sector(R, sid, Edit().note(7, 22.3, "двери 1,1–1,4; ворота лестницы 9,1 м; проёма в перекрытии нет", (150, 0, 0)), "СЕЙЧАС (верхний этаж)", box=box, ppm=22)
    e = Edit()
    for i in (0, 1, 2): e.door(i, **wd(R, sid, i, 1.0))
    e.door(3, **wd(R, sid, 3, 1.0))
    e.door(4, **wd(R, sid, 4, 3.0, "3.0 проход"))
    e.door(5, **wd(R, sid, 5, 1.8, "1.8 противопожарная"))
    e.door(6, world_m=[25.6, 15.56, 27.4, 15.56], label="1.8 противопожарная")
    e.add([21.4, 10.97, 9.5, 4.3], "ПРОЁМ ЛЕСТНИЦЫ (пол U / потолок L)", (170, 170, 170))
    e.add_door([22.0, 15.56, 23.8, 15.56], "door", "", "выход 1.8")
    e.note(7, 22.3, "двери комнат 1,0; противопожарные 1,8; лестница с проёмом, ворота 9,1 м → дверь 1,8", (0, 100, 0))
    P = draw_sector(R, sid, e, "ПРЕДЛОЖЕНИЕ", box=box, ppm=22)
    save(sheet([now, P], cols=2), "u-east-support-options.png")
