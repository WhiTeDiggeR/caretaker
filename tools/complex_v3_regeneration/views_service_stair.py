from review_views import *

BOX = (-58, 44, -34, 72)
PPM = 16


def build(R):
    sid = "T-UTILITIES"
    now = draw_sector(R, sid, None, "T СЕЙЧАС: вход снизу (юг)", box=BOX, ppm=PPM)
    d = ImageDraw.Draw(now)
    d.text((8, 32), "на L вход сверху (север) → прямая лестница 11 м не влезает в 8,6 м", fill=(150, 0, 0), font=font(10))
    e = Edit()
    e.add([-49.78, 51.21, 2.0, 10.59], "проход", (225, 225, 225))
    e.add([-47.78, 51.21, 4.67, 2.0], "тамбур", (230, 215, 200))
    e.add_door([-49.78, 59.9, -47.78, 59.9], "door", "", "1.8 пож.")
    e.add_door([-47.78, 51.4, -47.78, 53.0], "door", "", "1.8")
    e.add_door([-46.4, 53.21, -44.6, 53.21], "door", "", "вход 1.8")
    P = draw_sector(R, sid, e, "T ПРЕДЛОЖЕНИЕ: вход сверху (север), как на L", box=BOX, ppm=PPM)
    save(sheet([now, P], cols=2), "service-stair-options.png")
