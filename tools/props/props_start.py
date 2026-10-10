"""Wave 1 props: the start of the game (docs/art/prop-catalog.md, section 1)."""
from __future__ import annotations

import json
import math

from propkit import TEX_DIR, Kit
from registry import prop


def uv(atlas: str, name: str):
    return json.loads((TEX_DIR / "decals" / f"{atlas}.json").read_text(encoding="utf-8"))[name]


# ----------------------------------------------------------------------------- P-001
@prop("emergency_cabinet", "P-001", (0.8, 1.9, 0.45), "floor", 6000,
      views=[((1.6, 1.5, 2.4), (0, 0.95, 0)), ((-1.8, 1.2, 1.6), (0, 1.0, 0)), ((0.2, 1.2, -2.2), (0, 0.9, 0))])
def emergency_cabinet(k: Kit):
    w, h, d, t = 0.8, 1.9, 0.4, 0.02
    # carcass
    k.box((w, 0.08, d), (0, 0.04, 0), "painted_metal", 0.006)                        # plinth
    k.box((t, h - 0.08, d), (-w / 2 + t / 2, 0.08 + (h - 0.08) / 2, 0), "painted_metal", 0.004)
    k.box((t, h - 0.08, d), (w / 2 - t / 2, 0.08 + (h - 0.08) / 2, 0), "painted_metal", 0.004)
    k.box((w, t, d), (0, h - t / 2, 0), "painted_metal", 0.006)                      # top
    k.box((w - 2 * t, 0.012, d - 0.03), (0, 0.09, -0.005), "painted_metal", 0.0)    # floor of the cabinet
    k.box((w - 2 * t, h - 0.1, 0.015), (0, 0.09 + (h - 0.1) / 2, -d / 2 + 0.0075), "painted_metal", 0.0)  # back
    # shelves with first-aid supplies, seen through the glass
    for i, y in enumerate((0.62, 1.05, 1.45)):
        k.box((w - 2 * t, 0.012, d - 0.06), (0, y, -0.02), "steel_bare", 0.0)
    for x, y, bw in ((-0.22, 1.50, 0.26), (0.12, 1.50, 0.3), (-0.2, 1.10, 0.3), (0.2, 1.10, 0.22)):
        k.box((bw, 0.18, 0.16), (x, y + 0.095, -0.03), "white_paint_worn", 0.01)
        k.box((bw * 0.5, 0.03, 0.005), (x, y + 0.12, 0.052), "red_paint_worn", 0.0)
        k.box((0.03, bw * 0.5 * 0.35, 0.005), (x, y + 0.12, 0.053), "red_paint_worn", 0.0)
    k.box((0.22, 0.26, 0.2), (-0.2, 0.745, -0.02), "red_paint_worn", 0.012)         # trauma bag
    k.cyl(0.07, 0.34, (0.22, 0.79, -0.04), "y", "steel_bare", 16)                    # oxygen bottle
    k.cyl(0.03, 0.05, (0.22, 0.985, -0.04), "y", "chrome_dull", 12)
    # door: hinge on the left edge, opens about +Y
    hx, z = -w / 2 + 0.005, d / 2 - 0.004
    k.group("Door", pivot=(hx, 0.0, z))
    dw, dt = w - 0.01, 0.026
    cx = hx + dw / 2
    k.box((dw, 0.9, dt), (cx, 0.54, z), "painted_metal", 0.008)                      # lower solid panel
    k.box((dw, 0.07, dt), (cx, 1.015, z), "painted_metal", 0.006)                    # rail
    k.box((dw, 0.07, dt), (cx, 1.845, z), "painted_metal", 0.006)
    k.box((0.07, 0.8, dt), (hx + 0.035, 1.43, z), "painted_metal", 0.006)            # stiles
    k.box((0.07, 0.8, dt), (hx + dw - 0.035, 1.43, z), "painted_metal", 0.006)
    k.box((dw - 0.12, 0.78, 0.004), (cx, 1.43, z - 0.004), "glass_dirty", 0.0)       # glass
    k.box((0.04, 0.2, 0.03), (hx + dw - 0.09, 0.98, z + 0.025), "steel_bare", 0.006)  # handle
    k.cyl(0.013, 0.2, (hx + dw - 0.09, 0.98, z + 0.045), "y", "steel_bare", 10)
    for y in (0.3, 1.0, 1.7):
        k.cyl(0.014, 0.1, (hx - 0.006, y, z), "y", "steel_bare", 10)
    k.decal((cx, 0.62, z + dt / 2), (0.5, 0.25), "signs_ru", uv("signs_ru", "first_aid"))
    k.decal((cx, 0.26, z + dt / 2), (0.3, 0.12), "panel_labels", uv("panel_labels", "АВАРИЯ"))
    k.body()


def led(k: Kit, x, y, z, m="emit_led_green", r=0.008):
    k.cyl(r + 0.004, 0.006, (x, y, z), "z", "plastic_panel", 10)
    k.cyl(r, 0.01, (x, y, z + 0.004), "z", m, 10)


# ----------------------------------------------------------------------------- P-002
@prop("evac_sign", "P-002", (0.4, 0.2, 0.05), "wall", 800)
def evac_sign(k: Kit):
    k.box((0.4, 0.2, 0.05), (0, 0.1, 0.025), "plastic_panel", 0.006)
    k.group("Emit_Sign", pivot=(0, 0.1, 0.05))
    k.decal((0, 0.1, 0.05), (0.38, 0.19), "signs_lit", uv("signs_ru", "exit"), offset=0.0)
    k.body()


# ----------------------------------------------------------------------------- P-003
@prop("mnemonic_panel", "P-003", (2.0, 1.2, 0.17), "wall", 7000)
def mnemonic_panel(k: Kit):
    w, h, d = 2.0, 1.2, 0.15
    k.box((w, h, 0.08), (0, h / 2, 0.04), "painted_metal", 0.01)                                   # back plate
    k.box((w, 0.06, d), (0, h - 0.03, d / 2), "painted_metal", 0.008)                              # top bezel
    k.box((w, 0.2, d), (0, 0.1, d / 2), "painted_metal", 0.008)                                    # indicator strip
    k.box((0.07, h - 0.26, d), (-w / 2 + 0.035, 0.2 + (h - 0.26) / 2, d / 2), "painted_metal", 0.008)
    k.box((0.07, h - 0.26, d), (w / 2 - 0.035, 0.2 + (h - 0.26) / 2, d / 2), "painted_metal", 0.008)
    k.box((w - 0.14, h - 0.26, 0.012), (0, 0.2 + (h - 0.26) / 2, 0.095), "plastic_panel", 0.0)     # recessed glass plate
    k.group("Screen", pivot=(0, 0.68, 0.101))
    k.decal((0, 0.68, 0.101), (1.8, 0.9), "screens", uv("screens", "mnemonic"), offset=0.0)
    k.body()
    k.box((1.8, 0.01, 0.012), (0, 0.2 + (h - 0.26) + 0.005, 0.105), "steel_bare", 0.0)
    for i, m in enumerate(("emit_led_green", "emit_led_green", "emit_led_amber", "emit_led_red", "emit_led_green", "emit_led_amber")):
        led(k, -0.8 + i * 0.12, 0.11, d + 0.0, m)
    for i, name in enumerate(("ШИНА", "СЕКЦИЯ А", "СЕКЦИЯ Б")):
        k.decal((0.0 + i * 0.36, 0.11, d), (0.3, 0.075), "panel_labels", uv("panel_labels", name), offset=0.0005)
    for x in (0.78, 0.9):
        k.cyl(0.028, 0.02, (x, 0.1, d + 0.008), "z", "steel_bare", 16)
        k.box((0.006, 0.03, 0.006), (x, 0.108, d + 0.019), "white_paint_worn", 0.0)
    for x in (-w / 2 + 0.035, w / 2 - 0.035):
        for y in (0.04, h - 0.03):
            k.hex_bolt((x, y, d + 0.003), 0.012, 0.008)
    k.decal((0.82, h - 0.03, d), (0.24, 0.045), "panel_labels", uv("panel_labels", "ВНИМАНИЕ"), offset=0.0005)


# ----------------------------------------------------------------------------- P-007
@prop("control_desk", "P-007", (1.62, 1.08, 0.82), "floor", 9000, tolerance=0.07)
def control_desk(k: Kit):
    w = 1.6
    # side profile (z, y): lower cabinet, lip, sloped panel, flat rear shelf
    prof = [(0.4, 0.0), (0.4, 0.78), (0.37, 0.82), (-0.02, 0.97), (-0.4, 0.97), (-0.4, 0.0)]
    k.prism_x(prof, w, 0, "painted_metal", bevel=0.006)
    k.box((w + 0.02, 0.06, 0.78), (0, 0.03, 0.0), "painted_metal", 0.006)                          # toe plinth
    k.box((w - 0.1, 0.9, 0.01), (0, 0.45, 0.405), "painted_metal", 0.0)                           # access panel look
    for x in (-0.55, 0.55):
        k.hex_bolt((x, 0.3, 0.41), 0.01, 0.006)
        k.hex_bolt((x, 0.66, 0.41), 0.01, 0.006)
    ang = math.degrees(math.atan2(0.15, 0.39))  # slope of the panel
    # centre of the slope: z = 0.175, y = 0.895
    def on_slope(x, t, lift=0.0):
        """t = 0..1 from the front lip to the rear edge; returns a point on (and lift above) the slope."""
        z, y = 0.37 + (-0.02 - 0.37) * t, 0.82 + (0.97 - 0.82) * t
        n = (0.0, math.cos(math.radians(ang)), math.sin(math.radians(ang)))
        return (x, y + n[1] * lift, z + n[2] * lift)
    # screen strip (top rear of the slope)
    k.group("Screen", pivot=on_slope(-0.45, 0.68))
    k.decal(on_slope(-0.45, 0.62, 0.0015), (0.5, 0.2), "screens", uv("screens", "terminal_off"), tilt=-ang, offset=0.0)
    k.body()
    k.box((0.54, 0.012, 0.28), on_slope(-0.45, 0.62, 0.0), "plastic_panel", 0.002, rot=(ang, 0, 0))
    # button banks
    for row, t in enumerate((0.12, 0.26)):
        for i in range(8):
            x = -0.04 + i * 0.075
            mat = ("emit_led_green", "emit_led_amber", "plastic_panel", "plastic_panel")[(i + row) % 4]
            px, py, pz = on_slope(x + 0.05, t, 0.008)
            k.cyl(0.022, 0.014, (px, py, pz), "y", "steel_bare", 12, rot=(ang, 0, 0))
            px, py, pz = on_slope(x + 0.05, t, 0.0145)
            k.cyl(0.015, 0.005, (px, py, pz), "y", mat, 10, rot=(ang, 0, 0))
    for i, name in enumerate(("ПУСК", "СТОП", "СБРОС", "ТЕСТ")):
        k.decal(on_slope(0.12 + i * 0.14, 0.38, 0.0015), (0.12, 0.03), "panel_labels", uv("panel_labels", name), tilt=-ang, offset=0.0)
    # knife switch (the interactable): base plate and a pivoting handle
    bx = 0.58
    px, py, pz = on_slope(bx, 0.45, 0.012)
    k.box((0.2, 0.012, 0.26), on_slope(bx, 0.45, 0.006), "steel_bare", 0.002, rot=(ang, 0, 0))
    for dz in (-0.1, 0.1):
        k.box((0.05, 0.03, 0.03), on_slope(bx, 0.45 + dz * 1.4, 0.026), "plastic_panel", 0.004, rot=(ang, 0, 0))
    hp = on_slope(bx, 0.55, 0.045)
    k.group("Switch", pivot=hp)
    k.cyl(0.011, 0.13, (hp[0], hp[1] + 0.05, hp[2] - 0.015), "y", "steel_bare", 10, rot=(ang + 30, 0, 0))
    k.sphere(0.026, (hp[0], hp[1] + 0.12, hp[2] - 0.045), "rubber_black", 12)
    k.cyl(0.016, 0.06, hp, "x", "steel_bare", 10)
    k.body()
    # side steps, cable gland and warning label
    k.decal((-0.55, 0.62, 0.411), (0.25, 0.125), "signs_ru", uv("signs_ru", "danger"), offset=0.0)
    k.cyl(0.03, 0.08, (0.65, 0.1, -0.38), "z", "rubber_black", 12)


# ----------------------------------------------------------------------------- P-008
@prop("terminal_console", "P-008", (1.2, 1.5, 0.72), "floor", 9000, tolerance=0.07)
def terminal_console(k: Kit):
    w = 1.2
    prof = [(0.35, 0.0), (0.35, 0.8), (0.33, 0.84), (0.12, 0.9), (-0.2, 0.9), (-0.35, 0.84), (-0.35, 0.0)]
    k.prism_x(prof, w, 0, "painted_metal", bevel=0.006)
    k.box((w + 0.02, 0.06, 0.72), (0, 0.03, 0.0), "painted_metal", 0.006)
    k.box((w - 0.12, 0.74, 0.01), (0, 0.42, 0.355), "painted_metal", 0.0)
    for x in (-0.5, 0.5):
        k.hex_bolt((x, 0.2, 0.36), 0.01, 0.006)
        k.hex_bolt((x, 0.66, 0.36), 0.01, 0.006)
    # keyboard on the shelf
    k.box((0.62, 0.022, 0.2), (0, 0.91, 0.1), "plastic_panel", 0.004)
    for i in range(3):
        k.box((0.58, 0.01, 0.045), (0, 0.926, 0.04 + i * 0.05), "rubber_black", 0.002)
    k.box((0.12, 0.012, 0.09), (0.46, 0.906, 0.1), "plastic_panel", 0.003)                       # trackball plate
    k.sphere(0.022, (0.46, 0.914, 0.1), "steel_bare", 10)
    # monitor on a post
    k.box((0.16, 0.22, 0.12), (0, 1.0, -0.14), "painted_metal", 0.006)
    k.box((1.0, 0.46, 0.14), (0, 1.27, -0.1), "painted_metal", 0.012, rot=(-8, 0, 0))
    k.group("Screen", pivot=(0, 1.27, -0.028))
    k.decal((0, 1.27, -0.027), (0.9, 0.36), "screens", uv("screens", "terminal_boot"), tilt=-8, offset=0.0)
    k.body()
    k.box((1.04, 0.5, 0.01), (0, 1.27, -0.185), "plastic_panel", 0.004, rot=(-8, 0, 0))
    for i in range(3):
        led(k, -0.42 + i * 0.07, 1.075, -0.038, ("emit_led_green", "emit_led_amber", "emit_led_green")[i], 0.007)
    # cooling slots on the back side
    for i in range(6):
        k.box((0.6, 0.008, 0.02), (0, 1.4 - i * 0.03, -0.2), "rubber_black", 0.0)
    k.decal((-0.42, 0.55, 0.361), (0.2, 0.05), "panel_labels", uv("panel_labels", "ДОПУСК"), offset=0.0)
    k.decal((0.35, 0.55, 0.361), (0.2, 0.05), "panel_labels", uv("panel_labels", "СВЯЗЬ"), offset=0.0)
    k.cyl(0.05, 0.08, (-0.5, 0.2, -0.33), "z", "rubber_black", 10)                                # cable trunk


# ----------------------------------------------------------------------------- P-009
@prop("generator_panel", "P-009", (1.2, 1.8, 0.34), "floor", 12000, center_z=False)
def generator_panel(k: Kit):
    w, h, d = 1.2, 1.8, 0.3
    k.box((w, 0.08, d), (0, 0.04, 0), "painted_metal", 0.006)
    k.box((w, h - 0.08, 0.06), (0, 0.08 + (h - 0.08) / 2, -d / 2 + 0.03), "painted_metal", 0.008)  # back wall
    for sx in (-1, 1):
        k.box((0.04, h - 0.08, d), (sx * (w / 2 - 0.02), 0.08 + (h - 0.08) / 2, 0), "painted_metal", 0.006)
    k.box((w, 0.05, d), (0, h - 0.025, 0), "painted_metal", 0.006)
    # left: instruments, centre: label plates, right: breakers
    k.box((0.5, 1.3, 0.04), (-0.3, 1.0, 0.0), "painted_metal", 0.008)                             # left instrument board
    k.box((0.5, 0.04, 0.0), (-0.3, 1.66, 0.021), "plastic_panel", 0.0)
    for i, (face, y) in enumerate((("pressure", 1.5), ("tachometer", 1.5), ("voltage", 1.15), ("temperature", 1.15))):
        x = -0.43 if i % 2 == 0 else -0.17
        k.cyl(0.085, 0.03, (x, y, 0.035), "z", "painted_metal", 24, cap_bevel=0.006)
        k.cyl(0.078, 0.004, (x, y, 0.05), "z", "plastic_panel", 24)
        k.decal((x, y, 0.0525), (0.15, 0.15), "instrument_faces", uv("instrument_faces", face), offset=0.0)
        k.cyl(0.078, 0.003, (x, y, 0.0555), "z", "glass_dirty", 24)
    for i, name in enumerate(("ДАВЛЕНИЕ", "ОБОРОТЫ", "НАПРЯЖЕНИЕ", "ТЕМПЕРАТУРА")):
        pass
    k.decal((-0.3, 1.36, 0.0215), (0.42, 0.06), "panel_labels", uv("panel_labels", "ДАВЛЕНИЕ"), offset=0.0)
    k.decal((-0.3, 1.01, 0.0215), (0.42, 0.06), "panel_labels", uv("panel_labels", "ТЕМПЕРАТУРА"), offset=0.0)
    for i, m in enumerate(("emit_led_green", "emit_led_amber", "emit_led_red", "emit_led_green")):
        led(k, -0.5 + i * 0.1, 0.62, 0.021, m, 0.01)
    k.box((0.5, 0.1, 0.04), (-0.3, 0.5, 0.0), "painted_metal", 0.006)
    # right: breaker rows. Each breaker is its own pivoting node.
    k.box((0.5, 1.1, 0.04), (0.33, 0.95, 0.0), "painted_metal", 0.008)
    n = 0
    for row in range(4):
        for col in range(4):
            n += 1
            bx, by = 0.17 + col * 0.11, 0.55 + row * 0.2
            k.box((0.075, 0.12, 0.03), (bx, by, 0.035), "plastic_panel", 0.004)
            k.group(f"Breaker{n}", pivot=(bx, by, 0.052))
            k.box((0.02, 0.05, 0.015), (bx, by + 0.015, 0.06), "steel_bare", 0.003, rot=(-18, 0, 0))
            k.body()
    k.decal((0.33, 1.52, 0.021), (0.4, 0.05), "panel_labels", uv("panel_labels", "ПИТАНИЕ"), offset=0.0)
    k.decal((0.33, 0.43, 0.021), (0.4, 0.05), "panel_labels", uv("panel_labels", "ЗАЩИТА"), offset=0.0)
    # log book (журнал) hanging on a hook, hazard stripe and warning plate
    k.cyl(0.006, 0.03, (-0.08, 1.7, 0.03), "z", "steel_bare", 8)
    k.box((0.2, 0.28, 0.012), (-0.08, 1.56, 0.04), "vinyl_worn", 0.003)
    k.box((0.18, 0.26, 0.006), (-0.08, 1.56, 0.0475), "paper_aged", 0.0)
    k.decal((0, 0.16, d / 2 - 0.15 + 0.15), (1.1, 0.1), "hazard_stripes", uv("hazard_stripes", "yellow_black"), offset=0.0)
    k.decal((0.33, 1.7, 0.021), (0.2, 0.1), "signs_ru", uv("signs_ru", "high_voltage"), offset=0.0)
    k.cyl(0.07, 0.5, (0.45, 1.55, -0.12), "y", "rubber_black", 12)                                 # cable bundle going up
