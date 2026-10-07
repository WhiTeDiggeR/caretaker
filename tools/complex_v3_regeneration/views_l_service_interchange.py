from review_views import *

BOX = (-52, 38, -30, 68)
PPM = 26


def build(R):
    sid = "L-SERVICE-INTERCHANGE"
    now = draw_sector(R, sid, None, "СЕЙЧАС", box=BOX, ppm=PPM)
    d = ImageDraw.Draw(now)
    x0, z0 = BOX[0], BOX[1]
    T = lambda x, z: ((x - x0) * PPM, (z - z0) * PPM + 28)
    d.rectangle([T(-44.44, 38), T(-38.89, 48.44)], outline=(200, 0, 0), width=2)
    d.text(T(-44.3, 40), "подход общего плана", fill=(200, 0, 0), font=font(10))
    d.text((8, 32), "шлюз 1 и 2 слиты; двери в комнаты 1,7 / 2,7 / 2,0 разные", fill=(150, 0, 0), font=font(11))
    e = Edit()
    e.rect("shlyuz", [-43.11, 53.21, 5.0, 4.29])
    e.add([-43.11, 57.5, 5.0, 4.28], "ШЛЮЗ 2 / тяжёлая сторона", (205, 200, 225))
    e.add([-44.44, 38, 5.55, 10.44], "подход (общий план)", (235, 235, 235))
    e.door(0, type="opening", world_m=[-44.44, 48.44, -38.89, 48.44], label="5.6 проход")
    e.door(1, type="door", world_m=[-46.34, 53.21, -44.54, 53.21], label="1.8 пож.")
    e.door(2, type="door", world_m=[-41.51, 53.21, -39.71, 53.21], label="1.8 пож.")
    e.door(3, world_m=[-42.86, 61.78, -38.36, 61.78], label="4.5 ворота")
    e.door(4, world_m=[-37.18, 53.21, -35.38, 53.21], label="1.8 пож.")
    e.add_door([-41.51, 57.5, -39.71, 57.5], "door", "", "1.8 гермо")
    P = draw_sector(R, sid, e, "ПРЕДЛОЖЕНИЕ", box=BOX, ppm=PPM)
    save(sheet([now, P], cols=2), "l-service-interchange-options.png")
