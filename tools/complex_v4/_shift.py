"""Helpers for editing approved_registration.json: shift a sector (offset + every metre-based amendment)."""
import json
P = "tools/complex_v4/approved_registration.json"


def load():
    raw = open(P, encoding="utf-8").read()
    return json.loads(raw), raw.endswith("\n")


def save(r, nl):
    open(P, "w", encoding="utf-8").write(json.dumps(r, ensure_ascii=False, indent=2) + ("\n" if nl else ""))


def shift_amendment(a, dx, dz):
    for key in ("rect_m",):
        if key in a:
            v = a[key]; a[key] = [round(v[0] + dx, 3), round(v[1] + dz, 3), v[2], v[3]]
    for key in ("at_m",):
        if key in a:
            v = a[key]; a[key] = [round(v[0] + dx, 3), round(v[1] + dz, 3), round(v[2] + dx, 3), round(v[3] + dz, 3)]
    for key in ("near_m", "center_m"):
        if key in a:
            v = a[key]; a[key] = [round(v[0] + dx, 3), round(v[1] + dz, 3)]
    if "segments_m" in a:
        a["segments_m"] = [[round(s[0] + dx, 3), round(s[1] + dz, 3), round(s[2] + dx, 3), round(s[3] + dz, 3)] for s in a["segments_m"]]


def shift_sector(r, sid, dx, dz, use_offset=True):
    s = r["sectors"][sid]
    if use_offset:
        ox, oz = s.get("offset_m", [0.0, 0.0])
        s["offset_m"] = [round(ox + dx, 3), round(oz + dz, 3)]
    for a in s.get("amendments", []):
        shift_amendment(a, dx, dz)
