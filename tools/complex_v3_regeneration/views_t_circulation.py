from review_views import *
import copy

BOX = (-106, -8, 36, 80)
PPM = 6.5
TCOL = {"corridor": (225, 225, 225), "shaft": (200, 205, 215), "work": (214, 205, 175), "energy": (200, 215, 235),
        "utility": (190, 220, 205), "room": (225, 215, 200), "support": (200, 210, 190)}


def level(R, rooms_override, extra_rooms, extra_doors, title, drop=()):
    w, h = int((BOX[2] - BOX[0]) * PPM), int((BOX[3] - BOX[1]) * PPM) + 30
    im = Image.new("RGB", (w, h), "white")
    d = ImageDraw.Draw(im, "RGBA")
    T = lambda x, z: ((x - BOX[0]) * PPM, (z - BOX[1]) * PPM + 28)
    for gx in range(-105, 36, 10):
        d.line([T(gx, BOX[1]), T(gx, BOX[3])], fill=(238, 238, 238, 255))
    for gz in range(-5, 80, 10):
        d.line([T(BOX[0], gz), T(BOX[2], gz)], fill=(238, 238, 238, 255))

    def box(rect, label, col, w_=1):
        a, b, c, e = rect
        d.rectangle([T(a, b), T(a + c, b + e)], fill=col + (235,), outline=(40, 50, 60, 255), width=w_)
        d.text(T(a + 0.4, b + 0.2), label[:22], fill=(0, 0, 0, 255), font=font(8))

    doors = []
    for sid, rep in R.items():
        if rep["level"] != "LV-T":
            continue
        for rm in rep["rooms"]:
            slug = rm["space_id"].split("/")[1]
            if (sid, slug) in drop:
                continue
            rect = rooms_override.get((sid, slug), rm["world_m"])
            box(rect, (rm["label"].split(" / ")[0] or slug), TCOL.get(rm["class"], (220, 220, 220)))
        if rooms_override and sid in ("T-CIRCULATION", "T-UTILITIES"):
            continue
        if True:
            for o in rep["openings"]:
                doors.append(o)
    for rect, label, col in extra_rooms:
        box(rect, label, col, 2)
    for o in doors:
        a, b, c, e = o["world_m"]
        col = {"door": DOOR, "opening": OPEN, "window": WIN}.get(o["type"], DOOR)
        d.line([T(a, b), T(c, e)], fill=col + (255,), width=3)
    for (a, b, c, e, col) in extra_doors:
        d.line([T(a, b), T(c, e)], fill=col + (255,), width=3)
    d.rectangle([0, 0, w, 26], fill=(255, 255, 255, 255))
    d.text((6, 5), title, fill=(0, 0, 0, 255), font=font(15))
    return im


def build(R):
    R = copy.deepcopy(R)
    now = level(R, {}, [], [], "T-УРОВЕНЬ СЕЙЧАС")
    drop = {("T-CIRCULATION", s) for s in ("dostup-v-galereyu-1", "dostup-v-galereyu-2", "corridor", "corridor-2", "corridor-3", "corridor-4",
            "kontroliruemyy", "kontroliruemyy-2", "staraya-lestnica", "lestnica", "glavnyy-lift", "avar", "t6-priemka", "gruzovoy",
            "kabelno-truboprovodnaya-gale", "tyazhelaya-gruzovaya-magistr", "glavnyy-sluzhebnyy-koridor")}
    drop |= {("T-UTILITIES", s) for s in ("corridor", "corridor-2", "corridor-3", "corridor-4", "room", "room-2", "room-3", "room-4")}
    Z = 24.24
    over = {("T-UTILITIES", "kontroliruemyy-gruzovoy-pere"): [-8.05, 24.19, 4.5, 43.21],
            ("T-UTILITIES", "podstanciya"): [-67.4, Z, 15.0, 13.12],
            ("T-UTILITIES", "ventilyaciya"): [-40.55, Z, 16.3, 13.12],
            ("T-UTILITIES", "gazy"): [-24.25, Z, 16.2, 13.12],
            ("T-UTILITIES", "drenazh"): [-3.55, Z, 16.15, 13.12],
            ("T-UTILITIES", "lestnica"): [-47.78, 53.2, 4.67, 8.58],
            ("T-UTILITIES", "protivo"): [-47.78, 61.78, 4.67, 5.62]}
    C = (225, 225, 225)
    extra = [([-102.4, 18.24, 133.5, 6.0], "ГЛАВНЫЙ СЛУЖЕБНЫЙ КОРИДОР", C),
             ([-71.9, 24.24, 4.5, 43.16], "ЗАПАДНЫЙ ПЕРЕХОД", C),
             ([-71.9, 67.4, 99.7, 7.8], "ТЯЖЁЛАЯ ГРУЗОВАЯ МАГИСТРАЛЬ", C)]
    ed = [(-71.9, 24.24, -67.4, 24.24, OPEN), (-71.9, 67.4, -67.4, 67.4, DOOR), (-8.05, 24.24, -3.55, 24.24, DOOR),
          (-8.05, 67.4, -3.55, 67.4, DOOR), (-45.9, 61.78, -45.0, 61.78, DOOR), (-46.6, 67.4, -44.8, 67.4, DOOR)]
    for c in (-59.9, -32.4, -16.15, 4.5):
        ed.append((c - 0.9, Z, c + 0.9, Z, DOOR))
    new = level(R, over, extra, ed, "T-УРОВЕНЬ · ПРЕДЛОЖЕНИЕ 2", drop=drop)
    save(sheet([now, new], cols=1), "t-circulation-v3.png")
