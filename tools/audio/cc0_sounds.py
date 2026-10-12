"""Builds the recorded CC0 sounds (#137) in loads/audio/cc0 from Freesound sources.

Usage: python3 tools/audio/cc0_sounds.py --src DIR [--out DIR]

DIR holds the downloaded sources named <freesound id>.mp3 (or .wav/.flac). Each recipe below
cuts, mixes and normalises them; the result is mono 16-bit WAV at 44.1 kHz and the manifest
loads/audio/cc0/manifest.json (source, author, licence, edits). Footsteps are sliced into single
steps and played through an AudioStreamRandomizer (tools/audio/build_randomizers.gd).

Needs numpy and ffmpeg; it is a manual tool, CI only checks the committed result.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
PEAK = 0.7  # same headroom as the generated placeholders (make_sfx.py)
DEFAULT_OUT = Path(__file__).resolve().parents[2] / "loads" / "audio" / "cc0"
LICENSE = "CC0 1.0"

# Freesound sources: id -> (author, title)
SOURCES: dict[str, tuple[str, str]] = {
    "459964": ("florianreichelt", "Footsteps on concrete"),
    "834029": ("IENBA", "Footsteps On Metal"),
    "451863": ("kyles", "footsteps shoes metal stairs up down resonate slow awkward weird"),
    "767343": ("DeqstersLab", "Climbing Metal Ladder hands and feet"),
    "451933": ("kyles", "switch big breaker metal click on, off.flac"),
    "139970": ("jessepash", "Switch.Big.Power.wav"),
    "377203": ("kiddpark", "FX kill switch single record.wav"),
    "386208": ("ldezem", "Ratchet drill - Unbranded - Tighten"),
    "829092": ("-+Fugu+-", "locked door"),
}

# Single steps: catalogue id -> (source, step length s, steps kept, high-pass Hz)
STEPS: dict[str, tuple[str, float, int, float]] = {
    "step_concrete": ("459964", 0.30, 6, 70.0),
    "step_grate": ("834029", 0.35, 6, 80.0),
    "step_metal": ("451863", 0.45, 6, 70.0),
    # The ladder take is boomy (author's note): short window and a steeper high-pass cut the echo.
    "step_ladder": ("767343", 0.22, 6, 160.0),
}

# One-shots: catalogue id -> list of layers (source, start s, end s, gain, offset s), fade out s
ONE_SHOTS: dict[str, tuple[list[tuple[str, float, float, float, float]], float]] = {
    "breaker": ([("451933", 0.10, 0.90, 1.0, 0.0)], 0.25),
    # Between the two takes the author liked: the heavy thunk of one under the snap of the other.
    "switch": ([("139970", 1.25, 2.45, 1.0, 0.0), ("377203", 0.62, 1.82, 0.6, 0.0)], 0.5),
    "lever": ([("386208", 1.35, 2.05, 1.0, 0.0)], 0.15),
    "door_locked": ([("829092", 1.70, 2.32, 1.0, 0.0)], 0.12),
}


def load(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def source(src: Path, sid: str) -> np.ndarray:
    for ext in (".mp3", ".wav", ".flac", ".ogg"):
        if (src / f"{sid}{ext}").exists():
            return load(src / f"{sid}{ext}")
    raise FileNotFoundError(f"source {sid} not found in {src}")


def highpass(x: np.ndarray, hz: float) -> np.ndarray:
    # two passes of a one-pole high-pass, enough to remove rumble and room boom
    a = np.exp(-2.0 * np.pi * hz / RATE)
    for _ in range(2):
        y = np.empty_like(x)
        prev_x = prev_y = 0.0
        for i, v in enumerate(x):
            prev_y = a * (prev_y + v - prev_x)
            prev_x = v
            y[i] = prev_y
        x = y
    return x


def fade(x: np.ndarray, fade_in: float, fade_out: float) -> np.ndarray:
    x = x.copy()
    n_in, n_out = int(fade_in * RATE), min(int(fade_out * RATE), len(x))
    if n_in:
        x[:n_in] *= np.linspace(0.0, 1.0, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1.0, 0.0, n_out) ** 2
    return x


def normalise(x: np.ndarray) -> np.ndarray:
    x = x - x.mean()
    return x * (PEAK / max(np.max(np.abs(x)), 1e-9))


def envelope(x: np.ndarray, hop: int = 220) -> np.ndarray:
    return np.sqrt(np.convolve(x ** 2, np.ones(hop) / hop, "same"))


def step_peaks(x: np.ndarray, min_gap: float = 0.25) -> list[int]:
    """Sample index of each step's transient: local loudness maxima, strongest first wins."""
    env = envelope(x, 110)
    gap = int(min_gap * RATE)
    floor = np.percentile(env, 95) * 0.3
    peaks: list[int] = []
    for i in np.argsort(env)[::-1]:
        if env[i] < floor:
            break
        if all(abs(int(i) - p) > gap for p in peaks):
            peaks.append(int(i))
    return sorted(peaks)


def step_cut(x: np.ndarray, peak: int, length: int) -> np.ndarray | None:
    """Cut from just before the transient; None when another strong hit falls inside the window."""
    env = envelope(x, 110)
    start = peak
    while start > 0 and peak - start < int(0.03 * RATE) and env[start] > env[peak] * 0.15:
        start -= 1
    start = max(0, start - int(0.004 * RATE))
    cut_env = env[start:start + length]
    if len(cut_env) < length:
        return None
    later = cut_env[int(0.09 * RATE):]
    if len(later) and later.max() > env[peak] * 0.45:
        return None
    return x[start:start + length]


def write(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


def entry(sid: str, edits: str) -> dict:
    author, title = SOURCES[sid]
    return {"source": f"https://freesound.org/s/{sid}/", "title": title, "author": author,
            "license": LICENSE, "edits": edits}


def build_steps(src: Path, out: Path) -> dict:
    files = {}
    for sound_id, (sid, length, keep, hp) in STEPS.items():
        x = highpass(source(src, sid), hp)
        n = int(length * RATE)
        cuts = [c for c in (step_cut(x, p, n) for p in step_peaks(x)) if c is not None]
        if len(cuts) < keep:
            raise RuntimeError(f"{sound_id}: only {len(cuts)} steps found in {sid}")
        peaks = np.array([np.max(np.abs(c)) for c in cuts])
        chosen = sorted(np.argsort(np.abs(peaks - np.median(peaks)))[:keep])  # most even loudness
        for n, idx in enumerate(chosen, 1):
            name = f"{sound_id}_{n:02d}.wav"
            write(out / "steps" / name, normalise(fade(cuts[idx], 0.004, length * 0.45)))
            files[f"steps/{name}"] = entry(sid, f"single step at {idx}, high-pass {hp:.0f} Hz, "
                                                 f"fade-out, normalised to {PEAK} peak, mono 44.1 kHz")
    return files


def build_one_shots(src: Path, out: Path) -> dict:
    files = {}
    for sound_id, (layers, fade_out) in ONE_SHOTS.items():
        parts = []
        for sid, start, end, gain, offset in layers:
            x = source(src, sid)[int(start * RATE):int(end * RATE)] * gain
            parts.append(np.concatenate([np.zeros(int(offset * RATE)), x]))
        mix = np.zeros(max(len(p) for p in parts))
        for p in parts:
            mix[:len(p)] += p
        name = f"{sound_id}.wav"
        write(out / name, normalise(fade(highpass(mix, 40.0), 0.003, fade_out)))
        layer_text = " + ".join(f"{sid} {s:.2f}-{e:.2f} s x{g}" for sid, s, e, g, _ in layers)
        meta = entry(layers[0][0], f"cut {layer_text}, high-pass 40 Hz, fade-out, normalised, mono 44.1 kHz")
        if len(layers) > 1:
            meta["mixed_with"] = [entry(sid, "layer") for sid, *_ in layers[1:]]
        files[name] = meta
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--src", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    files = build_steps(args.src, args.out)
    files.update(build_one_shots(args.src, args.out))
    manifest = {"note": "Recorded CC0 sounds (#137). Built by tools/audio/cc0_sounds.py.", "files": files}
    (args.out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(files)} files in {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
