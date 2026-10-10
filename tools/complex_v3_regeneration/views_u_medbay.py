from review_views import *

def recentre(R, idx, width):
    o = R["U-MEDBAY"]["openings"][idx]["world_m"]
    cx, cz = (o[0] + o[2]) / 2, (o[1] + o[3]) / 2
    if abs(o[0] - o[2]) < 1e-6:
        return [o[0], cz - width / 2, o[0], cz + width / 2]
    return [cx - width / 2, o[1], cx + width / 2, o[1]]

def doors_1m(R, e):
    for i in (1, 2, 3, 4, 5):
        e.door(i, world_m=recentre(R, i, 1.0))
    e.door(6, world_m=recentre(R, 6, 1.0))
    return e

def build(R):
    box = (-104, 8, -78, 24)
    now = draw_sector(R, "U-MEDBAY", None, "СЕЙЧАС (после сдвига на 1,1 м): полоса «вход» наезжает на холл, двери 0,6–0,8 м", box=box)
    now_e = Edit().note(-103, 21.8, "полоса «вход» 2,6×7,8 м (справа) лежит внутри холла; двери 0,6–0,8 м", (150, 0, 0))
    now = draw_sector(R, "U-MEDBAY", now_e, "СЕЙЧАС", box=box)
    # A
    a = Edit().remove("raspredelitelnyy-holl")
    doors_1m(R, a)
    a.add_door([-84.444, 14.8, -84.444, 16.6], "door", "", "1.8 к проходу в холл")
    a.note(-103, 21.8, "A: полоса удалена; вход через проход холла; двери комнат 1,0 м", (0, 100, 0))
    A = draw_sector(R, "U-MEDBAY", a, "ВАРИАНТ A", box=box)
    # B: medbay stretched 1.1 m west (procedure and ward wider)
    b = Edit().remove("raspredelitelnyy-holl")
    doors_1m(R, b)
    b.rect("procedurnaya", [-98.878, 11.767, 8.118, 4.088]).rect("palata", [-98.878, 15.855, 8.118, 3.689])
    b.add_door([-84.444, 14.8, -84.444, 16.6], "door", "", "1.8")
    b.note(-103, 21.8, "B: +1,1 м на запад — выигрыш только процедурной и палате", (0, 100, 0))
    B = draw_sector(R, "U-MEDBAY", b, "ВАРИАНТ B", box=box)
    # C: medpost removed, reception extended
    c = Edit().remove("raspredelitelnyy-holl").remove("medpost")
    doors_1m(R, c)
    c.rect("priemnaya", [-88.538, 14.359, 4.094, 5.185])
    c.add_door([-84.444, 14.8, -84.444, 16.6], "door", "", "1.8")
    c.note(-103, 21.8, "C: медпост убран, приёмная 4,1×5,2 м его заменяет", (0, 100, 0))
    C = draw_sector(R, "U-MEDBAY", c, "ВАРИАНТ C", box=box)
    save(sheet([now, A, B, C], cols=2), "u-medbay-options.png")
