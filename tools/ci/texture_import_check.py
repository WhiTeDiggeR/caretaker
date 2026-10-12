#!/usr/bin/env python3
"""3D texture import settings for `loads/` (issue #156, decision O-6; 2048 px cap: issue #160).

Godot's "detect 3D" switch (VRAM compression + mipmaps once a texture is used in a material) only fires in the
editor with a window; headless imports (cloud sessions, CI) keep textures uncompressed and without mipmaps.
`project.godot` sets `[importer_defaults]` for new textures; this script keeps the existing ones in line.
Every texture is also capped at SIZE_LIMIT px on import: 4K sources stay in the repository, Godot downsizes them,
and lifting the cap brings 4K back. The cap does nothing to textures that are already that small.

Usage:
  python tools/ci/texture_import_check.py           check: every texture under loads/ is VRAM + mipmaps, <= 2048 px
  python tools/ci/texture_import_check.py --apply   switch the params the editor's detection would switch,
                                                    then run `godot --headless --editor --path . --quit`
                                                    so Godot reimports and rewrites the .import files itself
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOTS = ("loads/",)
NORMAL = re.compile(r"(nor_gl|nor_baked|normal|_nrm)", re.IGNORECASE)
SIZE_LIMIT = 2048
# Exactly what the editor writes after detecting a texture used in 3D, plus the size cap.
WANTED = {"compress/mode": "2", "mipmaps/generate": "true", "detect_3d/compress_to": "0",
          "process/size_limit": str(SIZE_LIMIT)}


def texture_imports() -> list[Path]:
    files = subprocess.run(["git", "ls-files", "-z", "--", *[f"{r}*.import" for r in ROOTS]], cwd=REPO,
                           capture_output=True, check=True).stdout.decode("utf-8").split("\0")
    out = []
    for f in files:
        if not f:
            continue
        p = REPO / f
        if p.exists() and 'importer="texture"' in p.read_text(encoding="utf-8"):
            out.append(p)
    return out


def wanted_for(path: Path) -> dict[str, str]:
    want = dict(WANTED)
    if NORMAL.search(path.name):
        want["compress/normal_map"] = "1"
    return want


def params(text: str) -> dict[str, str]:
    body = text.split("[params]", 1)[1] if "[params]" in text else ""
    return dict(line.split("=", 1) for line in body.splitlines() if "=" in line)


def main(argv: list[str]) -> int:
    apply = argv[:1] == ["--apply"]
    bad = []
    for p in texture_imports():
        text = p.read_text(encoding="utf-8")
        have = params(text)
        diff = {k: v for k, v in wanted_for(p).items() if have.get(k) != v}
        if not diff:
            continue
        if apply:
            for k, v in diff.items():
                text = re.sub(rf"^{re.escape(k)}=.*$", f"{k}={v}", text, count=1, flags=re.MULTILINE)
            p.write_text(text, encoding="utf-8")
        bad.append((p.relative_to(REPO).as_posix(), diff))
    if apply:
        print(f"switched {len(bad)} texture imports; now run Godot headless --editor to reimport")
        return 0
    if bad:
        print(f"{len(bad)} texture(s) under loads/ are not imported as 3D textures (VRAM + mipmaps, <= {SIZE_LIMIT} px):")
        for path, diff in bad[:30]:
            print(f"  {path}: {diff}")
        print("Fix: python tools/ci/texture_import_check.py --apply, then godot --headless --editor --path . --quit")
        return 1
    print(f"TEXTURE_IMPORT_CHECK textures={len(texture_imports())} bad=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
