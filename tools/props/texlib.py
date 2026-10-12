"""Seamless procedural texture primitives (numpy only). Every function returns float32 arrays
that tile in both directions, so results can be used as repeating PBR materials."""
from __future__ import annotations

import numpy as np

SIZE = 1024


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def fbm(seed: int, beta: float = 2.0, size: int = SIZE, stretch: tuple[float, float] = (1.0, 1.0),
        cutoff_low: float = 0.0) -> np.ndarray:
    """Periodic 1/f^beta noise normalised to 0..1. `stretch` scales the frequency axes (x, y);
    stretch (0.05, 1) gives long horizontal streaks (brushed metal), (1, 0.05) vertical streaks."""
    g = rng(seed)
    white = g.standard_normal((size, size)).astype(np.float32)
    f = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None] * size / stretch[1]
    fx = np.fft.fftfreq(size)[None, :] * size / stretch[0]
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    amp = 1.0 / np.power(r, beta / 2.0)
    amp[0, 0] = 0.0
    if cutoff_low > 0:
        amp[r < cutoff_low] = 0.0
    out = np.real(np.fft.ifft2(f * amp)).astype(np.float32)
    out -= out.min()
    out /= max(float(out.max()), 1e-6)
    return out


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / max(b - a, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def voronoi(seed: int, cells: int, size: int = SIZE) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Tileable voronoi. Returns (F1 distance in cell units, F2-F1 edge distance, random id per pixel)."""
    g = rng(seed)
    pts = g.random((cells, cells, 2)).astype(np.float32)
    ids = g.random((cells, cells)).astype(np.float32)
    cs = size / cells
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cy = (yy // cs).astype(np.int32)
    cx = (xx // cs).astype(np.int32)
    f1 = np.full((size, size), 9.0, np.float32)
    f2 = np.full((size, size), 9.0, np.float32)
    ident = np.zeros((size, size), np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ny = (cy + dy) % cells
            nx = (cx + dx) % cells
            px = (cx + dx + pts[ny, nx, 0]) * cs
            py = (cy + dy + pts[ny, nx, 1]) * cs
            d = np.sqrt((xx - px) ** 2 + (yy - py) ** 2) / cs
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            ident = np.where(closer, ids[ny, nx], ident)
            f1 = np.where(closer, d, f1)
    return f1, f2 - f1, ident


def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """Periodic gaussian blur via FFT."""
    n = a.shape[0]
    f = np.fft.fftfreq(n)
    kx, ky = np.meshgrid(f, f)
    k = np.exp(-2.0 * (np.pi ** 2) * (sigma ** 2) * (kx * kx + ky * ky))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * k)).astype(np.float32)


def lines(seed: int, count: int, length: tuple[float, float], width: float = 1.0,
          angle_jitter: float = 0.25, base_angle: float = 0.0, size: int = SIZE) -> np.ndarray:
    """Random thin wrapped line segments (scratches). Returns 0..1 coverage."""
    from PIL import Image, ImageDraw
    g = rng(seed)
    out = np.zeros((size, size), np.float32)
    img = Image.new("L", (size * 3, size * 3), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = g.random() * size + size, g.random() * size + size
        ln = g.uniform(*length)
        a = base_angle + g.normal(0, angle_jitter)
        x2, y2 = x + np.cos(a) * ln, y + np.sin(a) * ln
        d.line([(x, y), (x2, y2)], fill=int(g.uniform(110, 255)), width=max(1, int(round(width * g.uniform(0.6, 1.4)))))
    arr = np.asarray(img, np.float32) / 255.0
    # fold the 3x3 canvas back onto one tile (wrap-around)
    for ty in range(3):
        for tx in range(3):
            out = np.maximum(out, arr[ty * size:(ty + 1) * size, tx * size:(tx + 1) * size])
    return out


def normal_from_height(h: np.ndarray, strength: float = 2.0) -> np.ndarray:
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx = -dx * strength * 8.0
    ny = dy * strength * 8.0  # image y runs down; OpenGL normal maps expect +Y up
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], axis=-1)
    return (n * 0.5 + 0.5).astype(np.float32)


def cavity(h: np.ndarray, radius: float = 6.0) -> np.ndarray:
    """Cheap ambient occlusion: how far a pixel sits below its blurred surroundings (1 = open)."""
    return np.clip(1.0 + (h - blur(h, radius)) * 4.0, 0.0, 1.0)


def lerp(a, b, t):
    return a + (b - a) * t


def colorize(t: np.ndarray, stops: list[tuple[float, tuple[float, float, float]]]) -> np.ndarray:
    xs = [s[0] for s in stops]
    out = np.zeros(t.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(t, xs, [s[1][c] for s in stops])
    return out


def grid_seams(size: int, cells: int, width: float) -> np.ndarray:
    """Distance-based panel seam grooves, periodic. 1 on the seam, 0 away from it."""
    p = (np.arange(size, dtype=np.float32) / size * cells) % 1.0
    d = np.minimum(p, 1.0 - p) * size / cells
    line = np.clip(1.0 - d / width, 0.0, 1.0)
    return np.maximum(line[None, :], line[:, None])


def rivets(size: int, cells: int, inset: float, radius: float, per_edge: int = 4) -> np.ndarray:
    """Rivet heads along the edges of every panel cell (periodic). 0..1 soft dots."""
    from PIL import Image, ImageDraw
    big = Image.new("L", (size * 3, size * 3), 0)
    d = ImageDraw.Draw(big)
    cs = size / cells
    r = radius
    for cy in range(cells):
        for cx in range(cells):
            for i in range(per_edge):
                t = (i + 0.5) / per_edge * cs
                for (px, py) in ((cx * cs + inset, cy * cs + t), (cx * cs + cs - inset, cy * cs + t),
                                 (cx * cs + t, cy * cs + inset), (cx * cs + t, cy * cs + cs - inset)):
                    for oy in (0, size, 2 * size):
                        for ox in (0, size, 2 * size):
                            d.ellipse([px + ox - r, py + oy - r, px + ox + r, py + oy + r], fill=255)
    arr = np.asarray(big, np.float32) / 255.0
    out = np.zeros((size, size), np.float32)
    for ty in range(3):
        for tx in range(3):
            out = np.maximum(out, arr[ty * size:(ty + 1) * size, tx * size:(tx + 1) * size])
    return blur(out, 1.2)
