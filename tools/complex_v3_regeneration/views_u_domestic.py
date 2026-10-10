from review_views import *

def mid(R, i):
    o = R["U-DOMESTIC"]["openings"][i]["world_m"]
    return (o[0] + o[2]) / 2, (o[1] + o[3]) / 2, abs(o[0] - o[2]) < 1e-6

def wd(R, i, w, label=None):
    cx, cz, vert = mid(R, i)
    return dict(world_m=[cx, cz - w / 2, cx, cz + w / 2] if vert else [cx - w / 2, cz, cx + w / 2, cz], label=label or f"{w:g}")

def common_doors(R, e):
    e.door(4, **wd(R, 4, 1.8)).door(5, **wd(R, 5, 1.8)).door(6, **wd(R, 6, 1.8)).door(7, **wd(R, 7, 1.8))
    for i in (8, 9, 10): e.door(i, **wd(R, i, 1.0))
    return e

def build(R):
    sid = "U-DOMESTIC"
    box = (-64, -14, -28, 23)
    now = draw_sector(R, sid, Edit().note(-63, 20.5, "окна 1,0 м в коридор и двери 1,0 м разных назначений", (150, 0, 0)), "СЕЙЧАС: столовая и кухня разделены коридором, окна выдачи смотрят в коридор", box=box)
    # A
    a = common_doors(R, Edit())
    a.door(2, **wd(R, 2, 3.0, "3.0 проход")).door(3, **wd(R, 3, 1.8))
    a.note(-63, 20.5, "A: выдача через коридор (окна остаются), двери по каталогу", (0, 100, 0))
    A = draw_sector(R, sid, a, "ВАРИАНТ A: планировка как есть, двери по каталогу", box=box)
    # B: canteen extended to the kitchen wall, corridor starts below the canteen
    b = common_doors(R, Edit())
    b.rect("stolovaya", [-60.0, -11.556, 16.667, 7.766]).rect("vnutrenniy", [-46.667, -3.79, 3.334, 23.3])
    b.remove("__none__") if False else None
    b.door(2, world_m=[-999, -999, -999, -999], label="")
    b.door(0, world_m=[-999, -999, -999, -999], label="")
    b.door(1, world_m=[-43.333, -9.9, -43.333, -6.6], label="окно выдачи 3.3", type="window")
    b.door(3, **wd(R, 3, 1.8))
    b.add_door([-46.667, -3.8, -43.333, -3.8], "opening", "", "3.3 проход в столовую")
    b.note(-63, 20.5, "B: столовая вплотную к кухне, выдача — окно в общей стене; коридор открывается в столовую", (0, 100, 0))
    B = draw_sector(R, sid, b, "ВАРИАНТ B: столовая примыкает к кухне", box=box)
    # predbannik wider
    pb = Edit()
    common = common_doors(R, pb)
    pb.rect("obschiy-predbannik", [-43.333, 8.458, 10.0, 3.0]).rect("razdevalka", [-43.333, 11.458, 3.333, 5.875]).rect("sanuzel", [-40.0, 11.458, 3.111, 5.875]).rect("komnata", [-36.889, 11.458, 3.556, 5.875])
    pb.note(-63, 20.5, "P2: предбанник 3,0 м за счёт глубины раздевалок (5,9 м)", (0, 100, 0))
    P = draw_sector(R, sid, pb, "ПРЕДБАННИК шире (для A и B)", box=box)
    save(sheet([now, A, B, P], cols=2), "u-domestic-options.png")
