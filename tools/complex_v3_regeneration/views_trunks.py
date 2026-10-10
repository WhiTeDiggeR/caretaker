from review_views import *
import copy, hashlib

BOX = (-114, -14, 34, 90)
PPM = 4.2
TRUNK = (222, 222, 222)


def col(sid):
    h = int(hashlib.md5(sid.encode()).hexdigest()[:6], 16)
    return (170 + h % 70, 170 + (h >> 8) % 70, 170 + (h >> 16) % 70)


def panel(R, level, variant, title):
    R = copy.deepcopy(R)
    z_ref = 0.0
    trunks = []     # (rect, label)
    lanes = []
    drop = set()
    over = {}
    shift = {}
    crop = {}
    if level == "LV-U":
        if variant == 1:
            trunks = [([-94.4, 19.6, 125.5, 5.5], "коридор"), ([-98.9, 67.3, 126.7, 7.8], "тяжёлая")]
        else:
            trunks = [([-94.4, 19.6, 125.5, 5.5], "коридор"), ([-98.9, 61.8, 126.7, 7.8], "тяжёлая")]
            shift["U-FREIGHT"] = -5.5
            for s in ("U-CHAMBER-4", "U-CHAMBER-6", "U-SECURITY"):
                crop[s] = -5.5
    elif level == "LV-L":
        if variant == 1:
            trunks = [([-61.1, 19.6, 92.2, 5.5], "коридор"), ([-72.2, 67.3, 100.0, 7.8], "тяжёлая")]
            lanes = [[-61.38, 61.8, 4.5, 5.5], [-24.47, 61.8, 4.5, 5.5], [20.47, 61.8, 4.5, 5.5], [-42.86, 61.8, 4.5, 5.5], [-75.02, 69.6, 2.8, 5.5]]
        else:
            trunks = [([-61.1, 19.6, 92.2, 5.5], "коридор"), ([-72.2, 61.8, 100.0, 7.8], "тяжёлая")]
            shift["L-FREIGHT-SERVICE"] = -5.6
        trunks.append(([-4.4, 25.1, 5.5, 36.7], "связка"))
    else:
        zt = 67.4 if variant == 1 else 61.8
        trunks = [([-102.4, 19.6, 133.5, 5.5], "коридор"), ([-71.9, 25.1, 4.5, zt - 25.1], "переход"),
                  ([-8.05, 25.1, 4.5, zt - 25.1], "переход"), ([-71.9, zt, 99.7, 7.8], "тяжёлая")]
        drop = {("T-CIRCULATION", None)}
        if variant == 2:
            shift["T-FREIGHT"] = -5.6
        Z = 25.1
        over = {("T-UTILITIES", "podstanciya"): [-67.4, Z, 15.0, 13.12], ("T-UTILITIES", "ventilyaciya"): [-40.55, Z, 16.3, 13.12],
                ("T-UTILITIES", "gazy"): [-24.25, Z, 16.2, 13.12], ("T-UTILITIES", "drenazh"): [-3.55, Z, 16.15, 13.12],
                ("T-UTILITIES", "lestnica"): [-47.78, 53.2, 4.67, 8.58], ("T-UTILITIES", "protivo"): [-47.78, 61.78 if variant == 1 else 56.2, 4.67, 5.62]}
        if variant == 2:
            over[("T-UTILITIES", "lestnica")] = [-47.78, 53.2, 4.67, 8.58]
            over[("T-UTILITIES", "protivo")] = [-47.78, 61.78, 4.67, 0.0]
        for k in ("corridor", "corridor-2", "corridor-3", "corridor-4", "room", "room-2", "room-3", "room-4", "kontroliruemyy-gruzovoy-pere"):
            drop.add(("T-UTILITIES", k))
    w, h = int((BOX[2] - BOX[0]) * PPM), int((BOX[3] - BOX[1]) * PPM) + 30
    im = Image.new("RGB", (w, h), "white")
    d = ImageDraw.Draw(im, "RGBA")
    T = lambda x, z: ((x - BOX[0]) * PPM, (z - BOX[1]) * PPM + 28)
    for gz in (0, 20, 40, 60, 80):
        d.line([T(BOX[0], gz), T(BOX[2], gz)], fill=(235, 235, 235, 255))
    for rect, lab in trunks:
        a, b, c, e = rect
        d.rectangle([T(a, b), T(a + c, b + e)], fill=TRUNK + (255,), outline=(90, 90, 90, 255))
    for a, b, c, e in lanes:
        d.rectangle([T(a, b), T(a + c, b + e)], fill=(255, 200, 90, 255), outline=(150, 100, 0, 255))
    for sid, rep in R.items():
        if rep["level"] != level or (sid, None) in drop:
            continue
        for rm in rep["rooms"]:
            slug = rm["space_id"].split("/")[1]
            if (sid, slug) in drop:
                continue
            x, z, ww, hh = over.get((sid, slug), rm["world_m"])
            z += shift.get(sid, 0)
            if sid in crop and abs((z + hh) - 67.3) < 0.4:
                hh += crop[sid]
            if hh <= 0:
                continue
            d.rectangle([T(x, z), T(x + ww, z + hh)], fill=col(sid) + (255,), outline=(60, 60, 60, 255))
    for sid, rep in R.items():
        if rep["level"] != level or (sid, None) in drop:
            continue
        xs = [m["world_m"][0] for m in rep["rooms"]]
        zs = [m["world_m"][1] for m in rep["rooms"]]
        d.text(T(min(xs) + 0.5, min(zs) + shift.get(sid, 0) + 0.5), sid.split("-", 1)[1][:12], fill=(0, 0, 0, 255), font=font(8))
    d.rectangle([0, 0, w, 24], fill=(255, 255, 255, 255))
    d.text((6, 4), title, fill=(0, 0, 0, 255), font=font(13))
    return im


def build(R):
    for v, name in ((1, "по U"), (2, "по L")):
        row = [panel(R, lv, v, f"Вариант {v} ({name}) · {ln}") for lv, ln in (("LV-U", "верхний этаж"), ("LV-L", "нижний этаж"), ("LV-T", "технический этаж"))]
        save(sheet(row, cols=3, gap=8), f"trunks-variant-{v}.png")
