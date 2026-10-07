from review_views import *


def build(R):
    im = draw_sector(R, "L-CHAMBER-2", None, "L-CHAMBER-2 · итог", box=(-84, 22, -45, 66), ppm=17)
    save(im, "l-chamber-2-final.png")
