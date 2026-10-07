from review_views import *

def wd(R, i, w, label=None, sid="U-FREIGHT"):
    o = R[sid]["openings"][i]["world_m"]
    cx, cz = (o[0] + o[2]) / 2, (o[1] + o[3]) / 2
    vert = abs(o[0] - o[2]) < 1e-6
    return dict(world_m=[o[0], cz - w / 2, o[0], cz + w / 2] if vert else [cx - w / 2, o[1], cx + w / 2, o[1]], label=label or f"{w:g}")

def build(R):
    sid = "U-FREIGHT"
    box = (-20, 62, 32, 90)
    now = draw_sector(R, sid, Edit().note(-19, 88, "ворота 2,8 / 6,6 / 5,4 м; проём лифта не размечен", (150, 0, 0)), "СЕЙЧАС", box=box, ppm=22)
    e = Edit()
    e.door(0, **wd(R, 0, 1.8, "1.8 гермо (изолятор)"))
    e.door(1, **wd(R, 1, 4.5, "4.5 ворота"))
    e.door(2, **wd(R, 2, 4.5, "4.5 ворота"))
    e.door(3, **wd(R, 3, 4.5, "4.5 ворота"))
    e.add([11.11, 75.11, 13.13, 8.0], "ПРОЁМ ШАХТЫ ЛИФТА (пол U)", (170, 170, 170))
    e.note(-19, 88, "ворота грузового тракта 4,5×4,5, изолятор — гермодверь 1,8, двери обходов 1,0; шахта лифта размечена", (0, 100, 0))
    P = draw_sector(R, sid, e, "ПРЕДЛОЖЕНИЕ", box=box, ppm=22)
    save(sheet([now, P], cols=2), "u-freight-options.png")
    # G-02: lift offset between U and L
    u = R["U-FREIGHT"]; l = R["L-FREIGHT-SERVICE"]
    ur = [x for x in u["rooms"] if "gruzovoy-lift" in x["space_id"]][0]["world_m"]
    lr = [x for x in l["rooms"] if "gruzovoy-lift" in x["space_id"]][0]["world_m"]
    a = Edit().add(lr, "L: лифт", (150, 210, 150)).note(-19, 88, "сейчас: на нижнем этаже лифт на 5,6 м севернее", (150, 0, 0))
    A = draw_sector(R, "U-FREIGHT", a, "G-02 СЕЙЧАС: U (серое) и L (зелёное) не совпадают", box=box, ppm=22)
    b = Edit().add([lr[0], ur[1], lr[2], lr[3]], "L: лифт под U (вариант A)", (150, 210, 150)).note(-19, 88, "A: нижний грузовой блок сдвинут на +5,6 м к югу", (0, 100, 0))
    B = draw_sector(R, "U-FREIGHT", b, "G-02 ВАРИАНТ A: L сдвинут под U", box=box, ppm=22)
    save(sheet([A, B], cols=2), "u-freight-lift.png")
