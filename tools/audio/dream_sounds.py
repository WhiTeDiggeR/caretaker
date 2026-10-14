"""Builds the dream transition and dream combat sounds (#218) in loads/audio/cc0.

Usage: python3 tools/audio/dream_sounds.py --kenney DIR [--out DIR] [--only ID,ID...]

DIR holds the unpacked Kenney packs (CC0 1.0, https://kenney.nl): kenney_impact-sounds,
kenney_sci-fi-sounds and kenney_rpg-audio, each with its Audio/ folder. Their takes are cut,
re-pitched, filtered and layered with noise sweeps and low tones synthesised here (own work,
CC0). The result is Ogg Vorbis (mono 44.1 kHz) plus entries in loads/audio/cc0/manifest.json.

Timing: the veil of a dream transition turns white in 0.6 s (DreamSession.FADE_SECONDS), so
the entry and the exit swell up to that moment and then bloom out under the new scene.

Needs numpy and ffmpeg; it is a manual tool, CI only checks the committed result.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100
PEAK = 0.7
DEFAULT_OUT = Path(__file__).resolve().parents[2] / "loads" / "audio" / "cc0"
VEIL = 0.6  # s, the veil is white
SEED = 218

PACKS = {
    "impact": ("kenney_impact-sounds", "Impact Sounds", "https://kenney.nl/assets/impact-sounds"),
    "scifi": ("kenney_sci-fi-sounds", "Sci-fi Sounds", "https://kenney.nl/assets/sci-fi-sounds"),
    "rpg": ("kenney_rpg-audio", "RPG Audio", "https://kenney.nl/assets/rpg-audio"),
}


class Kit:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.used: list[tuple[str, str]] = []

    def take(self, pack: str, name: str) -> np.ndarray:
        path = self.root / PACKS[pack][0] / "Audio" / f"{name}.ogg"
        raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
                              "-f", "f32le", "-"], capture_output=True, check=True).stdout
        self.used.append((pack, name))
        x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
        return x / max(np.max(np.abs(x)), 1e-9)


def one_pole(x: np.ndarray, hz: np.ndarray | float, high: bool = False) -> np.ndarray:
    """One-pole low-pass (or high-pass) with a cutoff that may change per sample."""
    hz = np.broadcast_to(np.asarray(hz, dtype=np.float64), x.shape)
    a = np.exp(-2.0 * np.pi * hz / RATE)
    y = np.empty_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = a[i] * prev + (1.0 - a[i]) * v
        y[i] = prev
    return x - y if high else y


def lowpass(x: np.ndarray, hz: np.ndarray | float, passes: int = 2) -> np.ndarray:
    for _ in range(passes):
        x = one_pole(x, hz)
    return x


def highpass(x: np.ndarray, hz: float, passes: int = 2) -> np.ndarray:
    for _ in range(passes):
        x = one_pole(x, hz, high=True)
    return x


def band(x: np.ndarray, centre: np.ndarray) -> np.ndarray:
    """Band of noise around a moving centre: low-pass above it, high-pass below it."""
    return lowpass(x, centre * 1.6, 2) - lowpass(x, centre * 0.6, 2)


def repitch(x: np.ndarray, factor: float) -> np.ndarray:
    """Plays `x` `factor` times faster (lower and longer below 1)."""
    n = int(len(x) / factor)
    return np.interp(np.arange(n) * factor, np.arange(len(x)), x)


def secs(t: float) -> int:
    return int(round(t * RATE))


def timeline(length: float) -> np.ndarray:
    return np.arange(secs(length)) / RATE


def place(mix: np.ndarray, x: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = secs(at)
    end = min(len(mix), start + len(x))
    if end > start:
        mix[start:end] += x[:end - start] * gain


def fit(x: np.ndarray, length: float) -> np.ndarray:
    n = secs(length)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n]


def ramp(t: np.ndarray, start: float, end: float, power: float = 1.0) -> np.ndarray:
    return np.clip((t - start) / (end - start), 0.0, 1.0) ** power


def fades(x: np.ndarray, fade_in: float, fade_out: float) -> np.ndarray:
    x = x.copy()
    n_in, n_out = secs(fade_in), min(secs(fade_out), len(x))
    if n_in:
        x[:n_in] *= np.linspace(0.0, 1.0, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1.0, 0.0, n_out) ** 2
    return x


def glide(t: np.ndarray, f0: float, f1: float, decay: float) -> np.ndarray:
    """Sine falling from f0 to f1 with an exponential decay: a body thump or a deep fall."""
    freq = f1 + (f0 - f1) * np.exp(-t / max(decay, 1e-3))
    return np.sin(2.0 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / decay)


def dream_enter(kit: Kit, noise: np.ndarray) -> np.ndarray:
    """Sinking into the dream: a dull reversed swell up to the white veil, a deep soft thud,
    then a slow underwater bloom that fades while the dream appears."""
    length = 3.2
    t = timeline(length)
    mix = np.zeros_like(t)
    rise = ramp(t, 0.0, VEIL, 2.2) * (t < VEIL)
    # air sucked in: noise whose low-pass opens 150 -> 1100 Hz on the way to the veil
    mix += lowpass(noise[:len(t)], 150.0 + 950.0 * rise, 2) * rise * 1.6
    boom = repitch(kit.take("scifi", "lowFrequency_explosion_000"), 0.8)
    swell = lowpass(boom[::-1][-secs(VEIL):], 900.0)
    place(mix, swell * np.linspace(0.3, 1.0, len(swell)), 0.0, 0.9)
    thud = lowpass(kit.take("impact", "impactSoft_heavy_000"), 380.0)
    place(mix, thud, VEIL, 0.9)
    place(mix, glide(timeline(2.2), 70.0, 34.0, 0.7), VEIL, 0.75)
    bloom = lowpass(repitch(kit.take("scifi", "forceField_000"), 0.5), 650.0)
    bloom = bloom * np.exp(-np.arange(len(bloom)) / RATE / 0.9)
    place(mix, bloom, VEIL + 0.05, 0.45)
    place(mix, lowpass(boom, 500.0) * 0.6, VEIL, 0.6)
    return fades(highpass(mix, 28.0), 0.02, 1.2)


def dream_exit(kit: Kit, noise: np.ndarray, breath: np.ndarray) -> np.ndarray:
    """Surfacing out of the dream: a rising airy rush up to the white veil, then a bright
    release that thins out, under a sharp waking breath."""
    length = 2.6
    t = timeline(length)
    mix = np.zeros_like(t)
    rise = ramp(t, 0.0, VEIL, 2.0) * (t < VEIL)
    centre = 350.0 + 3200.0 * rise
    mix += band(noise[:len(t)], np.maximum(centre, 1.0)) * rise * 2.4
    shimmer = kit.take("scifi", "forceField_001")
    swell = shimmer[::-1][-secs(VEIL):]
    place(mix, highpass(swell, 300.0) * np.linspace(0.2, 1.0, len(swell)), 0.0, 0.5)
    after = timeline(length - VEIL)
    release = highpass(noise[:len(after)], 900.0) * np.exp(-after / 0.45)
    place(mix, lowpass(release, 7000.0 * np.exp(-after / 0.9) + 1500.0, 1), VEIL, 0.9)
    place(mix, highpass(shimmer, 400.0) * np.exp(-np.arange(len(shimmer)) / RATE / 0.5), VEIL, 0.35)
    place(mix, breath, VEIL + 0.04, 0.55)
    return fades(highpass(mix, 60.0), 0.02, 0.9)


def dream_chain_hit(kit: Kit, noise: np.ndarray) -> np.ndarray:
    """A swing of the chain with its weight: a heavy whoosh past the ear and the links rattling."""
    length = 0.62
    t = timeline(length)
    mix = np.zeros_like(t)
    # the weight passes by: the band rises and falls, the loudness peaks at 0.17 s
    shape = np.exp(-((t - 0.17) / 0.075) ** 2)
    centre = 260.0 + 900.0 * shape
    mix += band(noise[:len(t)], centre) * shape * 2.6
    links = repitch(kit.take("rpg", "handleCoins2"), 0.75)
    place(mix, highpass(links, 500.0), 0.02, 0.32)
    place(mix, highpass(repitch(kit.take("rpg", "beltHandle1"), 0.8), 300.0), 0.12, 0.22)
    return fades(highpass(mix, 70.0), 0.01, 0.25)


def dream_strike(kit: Kit, _noise: np.ndarray) -> np.ndarray:
    """The weight landing on a shade: a heavy body blow with an iron edge and a low thump."""
    length = 0.7
    t = timeline(length)
    mix = np.zeros_like(t)
    place(mix, kit.take("impact", "impactPunch_heavy_000"), 0.0, 1.0)
    place(mix, repitch(kit.take("impact", "impactMetal_heavy_000"), 0.7), 0.0, 0.3)
    mix += glide(t, 110.0, 50.0, 0.12) * 0.55
    return fades(highpass(mix, 40.0), 0.002, 0.25)


def dream_hurt(kit: Kit, noise: np.ndarray) -> np.ndarray:
    """The hero struck: a dull muffled blow felt in the chest, the high end swallowed."""
    length = 0.6
    t = timeline(length)
    mix = np.zeros_like(t)
    place(mix, lowpass(kit.take("impact", "impactPunch_heavy_002"), 1200.0), 0.0, 1.0)
    mix += glide(t, 75.0, 42.0, 0.16) * 0.8
    mix += lowpass(noise[:len(t)], 400.0) * np.exp(-t / 0.08) * 1.2
    return fades(highpass(mix, 30.0), 0.002, 0.2)


def dream_enemy_die(kit: Kit, noise: np.ndarray) -> np.ndarray:
    """A shade dissolving: a low groan sinking in pitch over a hiss that drains away."""
    length = 1.6
    t = timeline(length)
    mix = np.zeros_like(t)
    groan = lowpass(repitch(kit.take("scifi", "forceField_002"), 0.55), 900.0)
    place(mix, groan * np.exp(-np.arange(len(groan)) / RATE / 0.6), 0.0, 0.8)
    place(mix, lowpass(kit.take("scifi", "lowFrequency_explosion_001"), 600.0), 0.0, 0.7)
    hiss = band(noise[:len(t)], 2400.0 * np.exp(-t / 0.5) + 300.0) * np.exp(-t / 0.45)
    mix += hiss * 1.2
    return fades(highpass(mix, 35.0), 0.004, 0.6)


RECIPES = {
    "dream_enter": ("dream_enter", "sinking into the dream: reversed low boom and a noise swell up to the veil "
                                   "(0.6 s), a soft thud with a falling 70-34 Hz tone, a slowed shimmer bloom"),
    "dream_exit": ("dream_exit", "surfacing: an airy band of noise rising to the veil (0.6 s), a reversed shimmer, "
                                 "a bright release thinning out, a waking breath (breath.wav, #209)"),
    "dream_chain_hit": ("dream_chain_hit", "the chain swung: a moving band of noise (whoosh) and slowed rattling "
                                           "links"),
    "dream_strike": ("dream_strike", "the weight landing: a heavy punch, a slowed iron hit, a 110-50 Hz thump"),
    "dream_hurt": ("dream_hurt", "the hero struck: a muffled punch, a 75-42 Hz thump, a low noise burst"),
    "dream_enemy_die": ("dream_enemy_die", "a shade dissolving: a slowed low shimmer, a low explosion, "
                                           "a draining hiss"),
}


def write_ogg(path: Path, x: np.ndarray) -> None:
    x = x - x.mean()
    x = x * (PEAK / max(np.max(np.abs(x)), 1e-9))
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", str(path)], input=pcm, check=True)


def read(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--kenney", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--only", default="", help="comma-separated catalogue ids to rebuild")
    args = parser.parse_args()
    only = set(filter(None, args.only.split(","))) or set(RECIPES)
    manifest_path = args.out / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    breath = read(args.out / "breath.wav")
    for sound_id in RECIPES:
        if sound_id not in only:
            continue
        kit = Kit(args.kenney)
        noise = np.random.default_rng(SEED).standard_normal(secs(4.0)) * 0.25
        builder = globals()[RECIPES[sound_id][0]]
        result = builder(kit, noise, breath) if sound_id == "dream_exit" else builder(kit, noise)
        name = f"{sound_id}.ogg"
        write_ogg(args.out / name, result)
        takes = sorted(set(kit.used))
        manifest["files"][name] = {
            "source": "own work (#218), tools/audio/dream_sounds.py",
            "title": sound_id,
            "author": "caretaker team",
            "license": "CC0 1.0",
            "edits": f"{RECIPES[sound_id][1]}; synthesised noise and tones, layered, normalised to {PEAK} peak, "
                     f"Ogg Vorbis q5",
            "mixed_with": [{"source": PACKS[pack][2], "title": f"{PACKS[pack][1]}: {take}.ogg",
                            "author": "Kenney (kenney.nl)", "license": "CC0 1.0", "edits": "layer"}
                           for pack, take in takes],
        }
        if sound_id == "dream_exit":
            manifest["files"][name]["mixed_with"].append(
                {"source": "https://freesound.org/s/516696/", "title": "breath.wav (Respiración agitada)",
                 "author": "Amekiano", "license": "CC0 1.0", "edits": "layer"})
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"built {', '.join(sorted(only))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
