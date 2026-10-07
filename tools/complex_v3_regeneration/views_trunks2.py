from review_views import *
import copy, hashlib

BOX = (-114, -14, 38, 90)
PPM = 4.0
TRUNK = (222, 222, 222)
ZC, ZT = 25.1, 61.8
STUB_CUT = 0.74


def col(sid):
    h = int(hashlib.md5(sid.encode()).hexdigest()[:6], 16)
    return (170 + h % 70, 170 + (h >> 8) % 70, 170 + (h >> 16) % 70)


def module(R, dx):
    out = []
    for rm in R["U-CHAMBER-6"]["rooms"]:
        x, z, w, h = rm["world_m"]
        slug = rm["space_id"].split("/")[1]
        if slug == "passazhirskiy":
            z2, h2 = ZC, h - STUB_CUT
        else:
            z2, h2 = z - 29.9 + ZC - STUB_CUT, h
        out.append(dict(rm, world_m=[x + dx, z2, w, h2]))
    return out


def panel(R, level, title, after=True):
    R = copy.deepcopy(R)
    shift, over_rooms, drop, extra = {}, {}, set(), []
    if after:
        R["U-CHAMBER-6"]["rooms"], R["U-CHAMBER-4"]["rooms"], R["L-CHAMBER-5"]["rooms"] = module(R, 3.36), module(R, -108.82), module(R, 3.36)
        for rm in R["U-SECURITY"]["rooms"]:
            if rm["space_id"].endswith("k-gruzovoy-zone"):
                rm["world_m"][3] = ZT - rm["world_m"][1]
        shift = {"U-FREIGHT": -5.5, "L-FREIGHT-SERVICE": -5.6, "T-FREIGHT": -5.6}
    if level == "LV-U":
        trunks = [([-98.9, 19.6, 130.0, 5.5]), ([-98.9, ZT, 128.8, 7.8])] if after else [([-94.4, 19.6, 125.5, 5.5]), ([-98.9, 67.3, 126.7, 7.8])]
    elif level == "LV-L":
        trunks = [([-61.1, 19.6, 92.2, 5.5]), ([-72.2, ZT, 102.1, 7.8]), ([-0.3, 25.1, 4.7, 36.7])] if after else [([-61.1, 19.6, 92.2, 5.5]), ([-72.2, 61.8, 100.0, 7.8]), ([-4.4, 25.1, 5.5, 36.7])]
    else:
        Z = 25.1
        trunks = [[-102.4, 19.6, 133.5, 5.5], [-71.9, 25.1, 4.5, ZT - 25.1], [-8.05, 25.1, 4.5, ZT - 25.1], [-71.9, ZT, 99.7, 7.8]]
        over_rooms = {("T-UTILITIES", "podstanciya"): [-67.4, Z, 15.0, 13.12], ("T-UTILITIES", "ventilyaciya"): [-40.55, Z, 16.3, 13.12],
                      ("T-UTILITIES", "gazy"): [-24.25, Z, 16.2, 13.12], ("T-UTILITIES", "drenazh"): [-3.55, Z, 16.15, 13.12],
                      ("T-UTILITIES", "lestnica"): [-47.78, 53.2, 4.67, 8.58]}
        drop = {("T-CIRCULATION", None), ("T-UTILITIES", "protivo")} | {("T-UTILITIES", k) for k in ("corridor", "corridor-2", "corridor-3", "corridor-4", "room", "room-2", "room-3", "room-4", "kontroliruemyy-gruzovoy-pere")}
    w, h = int((BOX[2] - BOX[0]) * PPM), int((BOX[3] - BOX[1]) * PPM) + 30
    im = Image.new("RGB", (w, h), "white")
    d = ImageDraw.Draw(im, "RGBA")
    T = lambda x, z: ((x - BOX[0]) * PPM, (z - BOX[1]) * PPM + 28)
    for gz in (0, 20, 40, 60, 80):
        d.line([T(BOX[0], gz), T(BOX[2], gz)], fill=(235, 235, 235, 255))
    for a, b, c, e in trunks:
        d.rectangle([T(a, b), T(a + c, b + e)], fill=TRUNK + (255,), outline=(90, 90, 90, 255))
    for sid, rep in R.items():
        if rep["level"] != level or (sid, None) in drop:
            continue
        for rm in rep["rooms"]:
            slug = rm["space_id"].split("/")[1]
            if (sid, slug) in drop:
                continue
            x, z, ww, hh = over_rooms.get((sid, slug), rm["world_m"])
            z += shift.get(sid, 0)
            d.rectangle([T(x, z), T(x + ww, z + hh)], fill=col(sid) + (255,), outline=(60, 60, 60, 255))
        xs = [m["world_m"][0] for m in rep["rooms"]]
        zs = [m["world_m"][1] for m in rep["rooms"]]
        d.text(T(min(xs) + 0.5, min(zs) + shift.get(sid, 0) + 0.5), sid.split("-", 1)[1][:12], fill=(0, 0, 0, 255), font=font(8))
    d.rectangle([0, 0, w, 24], fill=(255, 255, 255, 255))
    d.text((6, 4), title, fill=(0, 0, 0, 255), font=font(13))
    return im


def build(R):
    row = [panel(R, lv, f"{ln} · ПРЕДЛОЖЕНИЕ") for lv, ln in (("LV-U", "верхний"), ("LV-L", "нижний"), ("LV-T", "технический"))]
    save(sheet(row, cols=3, gap=8), "trunks-aligned.png")
