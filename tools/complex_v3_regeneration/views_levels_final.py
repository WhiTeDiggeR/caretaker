from review_views import *
import hashlib

BOX = (-114, -14, 38, 90)
PPM = 4.0
TR = {"LV-U": [(-98.9, 19.6, 130.0, 5.5), (-98.9, 61.8, 128.8, 7.8)],
      "LV-L": [(-61.1, 19.6, 92.2, 5.5), (-72.2, 61.8, 102.1, 7.8), (-0.3, 25.1, 4.7, 36.7)],
      "LV-T": []}


def col(sid):
    h = int(hashlib.md5(sid.encode()).hexdigest()[:6], 16)
    return (170 + h % 70, 170 + (h >> 8) % 70, 170 + (h >> 16) % 70)


def panel(R, level, title):
    w, h = int((BOX[2] - BOX[0]) * PPM), int((BOX[3] - BOX[1]) * PPM) + 30
    im = Image.new("RGB", (w, h), "white")
    d = ImageDraw.Draw(im, "RGBA")
    T = lambda x, z: ((x - BOX[0]) * PPM, (z - BOX[1]) * PPM + 28)
    for gz in (0, 20, 40, 60, 80):
        d.line([T(BOX[0], gz), T(BOX[2], gz)], fill=(235, 235, 235, 255))
    for a, b, c, e in TR[level]:
        d.rectangle([T(a, b), T(a + c, b + e)], fill=(232, 232, 232, 255), outline=(150, 150, 150, 255), width=1)
    for sid, rep in R.items():
        if rep["level"] != level:
            continue
        for rm in rep["rooms"]:
            x, z, ww, hh = rm["world_m"]
            d.rectangle([T(x, z), T(x + ww, z + hh)], fill=col(sid) + (255,), outline=(60, 60, 60, 255))
        xs = [m["world_m"][0] for m in rep["rooms"]]
        zs = [m["world_m"][1] for m in rep["rooms"]]
        d.text(T(min(xs) + 0.5, min(zs) + 0.5), sid.split("-", 1)[1][:12], fill=(0, 0, 0, 255), font=font(8))
        for o in rep["openings"]:
            a, b, c, e = o["world_m"]
            if o["type"] != "window":
                d.line([T(a, b), T(c, e)], fill=(200, 50, 40, 255), width=2)
    d.rectangle([0, 0, w, 24], fill=(255, 255, 255, 255))
    d.text((6, 4), title, fill=(0, 0, 0, 255), font=font(13))
    return im


def build(R):
    row = [panel(R, lv, ln) for lv, ln in (("LV-U", "Верхний этаж"), ("LV-L", "Нижний этаж"), ("LV-T", "Технический этаж"))]
    save(sheet(row, cols=3, gap=8), "levels-final.png")
