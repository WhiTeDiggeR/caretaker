from review_views import *

def wd(R, i, w, label=None):
    o = R["U-CONTROL"]["openings"][i]["world_m"]
    cx, cz = (o[0] + o[2]) / 2, (o[1] + o[3]) / 2
    vert = abs(o[0] - o[2]) < 1e-6
    return dict(world_m=[o[0], cz - w / 2, o[0], cz + w / 2] if vert else [cx - w / 2, o[1], cx + w / 2, o[1]], label=label or f"{w:g}")

def build(R):
    sid = "U-CONTROL"
    box = (-36, -12, -4, 25)
    now = draw_sector(R, sid, Edit().note(-35, 22.5, "двери 0,8 м; вход с востока и тамбур-пожарка без дверей; восточная полоса заходит в коридор", (150, 0, 0)), "СЕЙЧАС", box=box)
    e = Edit()
    for i in (3, 4, 5, 6): e.door(i, **wd(R, i, 1.8))
    e.door(1, **wd(R, 1, 1.8))
    for i in (7, 8, 9): e.door(i, **wd(R, i, 1.0))
    e.door(2, **wd(R, 2, 1.0))
    e.rect("vostochnyy", [-10.0, -0.087, 2.691, 19.65])
    e.add_door([-10.0, 1.36, -10.0, 3.16], "door", "", "1.8")
    e.add_door([-19.0, 10.309, -18.0, 10.309], "door", "", "1.0")
    e.add_door([-18.0, 11.665, -17.0, 11.665], "door", "", "1.0")
    e.note(-35, 22.5, "двери хола одинаковые 1,8; служебные 1,0; вход с востока и пожарный тамбур получили двери; полоса не заходит в коридор", (0, 100, 0))
    P = draw_sector(R, sid, e, "ПРЕДЛОЖЕНИЕ", box=box)
    save(sheet([now, P], cols=2), "u-control-options.png")
