from review_views import *


def build(R):
    box = (-22, 56, 32, 90)
    save(sheet([draw_sector(R, "T-FREIGHT", None, "T-FREIGHT · итог", box=box, ppm=9),
                draw_sector(R, "L-FREIGHT-SERVICE", None, "L-FREIGHT-SERVICE · итог", box=box, ppm=9)], cols=2), "t-freight-final.png")
