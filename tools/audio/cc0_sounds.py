"""Builds the recorded CC0 sounds (#137, #209) in loads/audio/cc0 from Freesound sources.

Usage: python3 tools/audio/cc0_sounds.py --src DIR [--out DIR] [--only ID,ID...]

DIR holds the downloaded sources named <freesound id>.mp3 (or .wav/.flac). Each recipe below
cuts, mixes and normalises them; the result is mono 16-bit WAV at 44.1 kHz and the manifest
loads/audio/cc0/manifest.json (source, author, licence, edits). Footsteps are sliced into single
steps and played through an AudioStreamRandomizer (tools/audio/build_randomizers.gd).
--only rebuilds just the listed catalogue ids and keeps the other manifest entries (and files).

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
    "451863": ("kyles", "footsteps shoes metal stairs up down resonate slow awkward weird"),
    "767343": ("DeqstersLab", "Climbing Metal Ladder hands and feet"),
    "451933": ("kyles", "switch big breaker metal click on, off.flac"),
    "139970": ("jessepash", "Switch.Big.Power.wav"),
    "377203": ("kiddpark", "FX kill switch single record.wav"),
    "386208": ("ldezem", "Ratchet drill - Unbranded - Tighten"),
    "829092": ("-+Fugu+-", "locked door"),
    "322920": ("jedspear", "Automatic garage door opening"),
    "406197": ("kyles", "door metal big heavy close kinda slam thud echo offmic.wav"),
    "438732": ("craigsmith", "G45-30-Submarine Hatch Opening.wav"),
    "709272": ("Skybonator", "Honda Generator Start-Up."),
    "606933": ("Garuda1982", "large diesel emergency generator is running"),
    # #209
    "214002": ("FenrirFangs", "door handle 7.wav"),
    "679460": ("Krokulator", "metal_door_open.wav"),
    "559470": ("Nox_Sound", "Foley_Mechanism_Wheel_Moderate_Rusty_Loop_Mono.wav"),
    "453333": ("kyles", "metal crank groan.flac"),
    "669095": ("vestibule-door", "metal catwalk footsteps.wav"),
    "646663": ("SoundDesignForYou", "Landing On The Ground [6]"),
    "516696": ("Amekiano", "Respiración agitada (heavy breathing).wav"),
    "457294": ("brunoboselli", "Air (or steam) pressure release"),
    "827432": ("jerry.berumen", "DESTRCrsh_ sledgehammer hitting drywall stonewall variation construction debris hard "
                                "continous_GABR_FCS2"),
    "706979": ("JesterWhoo", "Hitting a brick with a sledgehammer. OWI.wav"),
    "829103": ("Squirrel_404", "Smashed/demolished brick wall crumbling/caving in"),
    "550342": ("Nox_Sound", "Foley_Stones_Falls_Debris_Stereo_DR05.wav"),
    "539968": ("Za-Games", "Deep Boom"),
    "478812": ("IanStarGem", "ambience 4.wav"),
    "852822": ("KolbyRFX", "AMBUndr_Subterranean Howling Wind Loop_KOLBYR_FREE SOUNDS"),
    "860781": ("bassimat", "Low Frequency Vibrating Drone with Heart Pressure Rumbles and Booms"),
}

# Generator (objects/audio/generator_sound.gd): start once, then the running loop.
GEN_START = ("709272", 0.0, 7.0, 1.5)  # source, start s, end s, fade-out s
GEN_IDLE = (4.0, 6.5)  # steady idle inside the start, the loop is matched to its loudness
GEN_RUN = ("606933", 10.0, 26.0, 1.0)  # source, start s, end s, loop crossfade s

# Single steps: catalogue id -> (source, step length s, steps kept, high-pass Hz)
STEPS: dict[str, tuple[str, float, int, float]] = {
    "step_concrete": ("459964", 0.30, 6, 70.0),
    # #209: a catwalk take, the ringing grate; the old take (834029) sounded like a solid floor.
    "step_grate": ("669095", 0.40, 6, 80.0),
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
    # Doors: lengths follow the move (hermetic and mechanical 1.4 s, service 0.8 s); door_stop
    # plays separately when a powered or mechanical door reaches its end.
    "door_motor": ([("322920", 1.90, 3.60, 1.0, 0.0)], 0.3),
    "door_stop": ([("406197", 0.28, 1.30, 1.0, 0.0)], 0.5),
    "door_mech": ([("438732", 4.00, 5.50, 1.0, 0.0)], 0.3),
    # #209: the handle pressed down, then the metal leaf pulled open (was a short handle rattle).
    # #218: cut to the leaf's swing (open_time 0.8 s of service_door.tscn), was 2.5 s.
    "door_swing": ([("214002", 0.30, 0.55, 0.45, 0.0), ("679460", 0.06, 0.86, 1.5, 0.18)], 0.3),
    # #209: the hand wheel turning (one hold, 1.6 s) apart from the hatch leaf (door_mech).
    "door_wheel": ([("559470", 1.00, 2.60, 1.0, 0.0)], 0.2),
    "door_wheel_jammed": ([("453333", 0.45, 1.45, 1.0, 0.0)], 0.3),
    "land": ([("646663", 0.20, 0.84, 1.0, 0.0)], 0.3),
    "breath": ([("516696", 0.95, 1.95, 1.0, 0.0)], 0.25),
    "airlock_cycle": ([("457294", 6.20, 10.60, 1.0, 0.0)], 1.2),
    # The breach wall (#178): a sledgehammer on masonry, then the wall caving in with falling debris.
    "breach_hit": ([("827432", 3.24, 4.10, 1.0, 0.0), ("706979", 0.985, 1.70, 0.5, 0.0)], 0.35),
    "breach_break": ([("829103", 0.25, 3.45, 1.0, 0.0), ("550342", 15.0, 18.2, 0.45, 0.5)], 1.0),
    # Bowser's dream (#201): a deep boom at the ambush. The entry and the exit (#218) are built by
    # tools/audio/dream_sounds.py.
    "dream_ambush": ([("539968", 0.0, 3.0, 1.0, 0.0)], 1.0),
}
# Fade-in of a one-shot (s) when its cut starts inside a sound; others start at a transient.
FADE_IN: dict[str, float] = {"breath": 0.03, "airlock_cycle": 0.4}
# Long one-shots kept as Ogg Vorbis.
OGG: set[str] = {"door_swing", "airlock_cycle", "breach_break", "dream_ambush"}

# Dream stage loops (#201, #209): catalogue id -> layers (source, start s, end s, gain); loudness
# matched to LOOP_RMS, the end cross-faded into the start (LOOP_XFADE s), Ogg Vorbis.
LOOPS: dict[str, list[tuple[str, float, float, float]]] = {
    "dream_stage_calm": [("478812", 10.0, 26.0, 1.0)],
    "dream_stage_alarm": [("852822", 20.0, 36.0, 1.0)],
    "dream_stage_unease": [("852822", 100.0, 116.0, 1.0), ("860781", 50.0, 66.0, 0.5)],
    "dream_stage_preawake": [("860781", 120.0, 136.0, 1.0), ("852822", 140.0, 156.0, 0.6)],
}
LOOP_XFADE = 1.5
LOOP_RMS = 0.12


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


def build_steps(src: Path, out: Path, only: set[str] | None = None) -> dict:
    files = {}
    for sound_id, (sid, length, keep, hp) in STEPS.items():
        if only is not None and sound_id not in only:
            continue
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


def build_one_shots(src: Path, out: Path, only: set[str] | None = None) -> dict:
    files = {}
    for sound_id, (layers, fade_out) in ONE_SHOTS.items():
        if only is not None and sound_id not in only:
            continue
        parts = []
        for sid, start, end, gain, offset in layers:
            x = source(src, sid)[int(start * RATE):int(end * RATE)] * gain
            parts.append(np.concatenate([np.zeros(int(offset * RATE)), x]))
        mix = np.zeros(max(len(p) for p in parts))
        for p in parts:
            mix[:len(p)] += p
        ogg = sound_id in OGG
        name = f"{sound_id}.ogg" if ogg else f"{sound_id}.wav"
        result = normalise(fade(highpass(mix, 40.0), FADE_IN.get(sound_id, 0.003), fade_out))
        if ogg:
            write_ogg(out / name, result)
        else:
            write(out / name, result)
        layer_text = " + ".join(f"{sid} {s:.2f}-{e:.2f} s x{g}" for sid, s, e, g, _ in layers)
        fmt = "Ogg Vorbis q5" if ogg else "mono 44.1 kHz"
        meta = entry(layers[0][0], f"cut {layer_text}, high-pass 40 Hz, fade-out, normalised, {fmt}")
        if len(layers) > 1:
            meta["mixed_with"] = [entry(sid, "layer") for sid, *_ in layers[1:]]
        files[name] = meta
    return files


def write_ogg(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", str(path)], input=pcm, check=True)


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(x ** 2)))


def build_generator(src: Path, out: Path) -> dict:
    sid, start, end, fade_out = GEN_START
    raw = highpass(source(src, sid)[int(start * RATE):int(end * RATE)], 30.0)
    gen_start = normalise(fade(raw, 0.005, fade_out))
    idle = gen_start[int(GEN_IDLE[0] * RATE):int(GEN_IDLE[1] * RATE)]
    write_ogg(out / "gen_start.ogg", gen_start)

    run_sid, run_start, run_end, xfade = GEN_RUN
    full = highpass(source(src, run_sid), 30.0)
    body = full[int(run_start * RATE):int(run_end * RATE)]
    tail = full[int(run_end * RATE):int((run_end + xfade) * RATE)]
    n = len(tail)
    ramp = np.linspace(0.0, 1.0, n)
    body = body.copy()
    # the loop end flows into its start; equal-power weights keep the noisy engine level steady
    body[:n] = body[:n] * np.sqrt(ramp) + tail * np.sqrt(1.0 - ramp)
    body = body - body.mean()
    body *= rms(idle) / max(rms(body), 1e-9)
    if np.max(np.abs(body)) > 0.95:
        body *= 0.95 / np.max(np.abs(body))
    write_ogg(out / "gen_run.ogg", body)
    return {
        "gen_start.ogg": entry(sid, f"cut {start:.1f}-{end:.1f} s (pull start, catch, idle), high-pass 30 Hz, "
                                    f"fade-out {fade_out} s, normalised, mono 44.1 kHz, Ogg Vorbis q5"),
        "gen_run.ogg": entry(run_sid, f"loop {run_start:.1f}-{run_end:.1f} s, {xfade} s crossfade of the end into the "
                                      f"start, high-pass 30 Hz, loudness matched to the idle of gen_start, Ogg Vorbis q5"),
    }


def loop_layer(src: Path, sid: str, start: float, end: float, gain: float) -> np.ndarray:
    full = highpass(source(src, sid), 30.0)
    body = full[int(start * RATE):int(end * RATE)].copy()
    tail = full[int(end * RATE):int((end + LOOP_XFADE) * RATE)]
    ramp = np.linspace(0.0, 1.0, len(tail))
    body[:len(tail)] = body[:len(tail)] * np.sqrt(ramp) + tail * np.sqrt(1.0 - ramp)
    return body * gain


def build_loops(src: Path, out: Path, only: set[str] | None = None) -> dict:
    files = {}
    for sound_id, layers in LOOPS.items():
        if only is not None and sound_id not in only:
            continue
        parts = [loop_layer(src, *layer) for layer in layers]
        mix = np.zeros(max(len(p) for p in parts))
        for p in parts:
            mix[:len(p)] += p
        mix = mix - mix.mean()
        mix *= LOOP_RMS / max(rms(mix), 1e-9)
        if np.max(np.abs(mix)) > 0.95:
            mix *= 0.95 / np.max(np.abs(mix))
        name = f"{sound_id}.ogg"
        write_ogg(out / name, mix)
        layer_text = " + ".join(f"{sid} {s:.1f}-{e:.1f} s x{g}" for sid, s, e, g in layers)
        meta = entry(layers[0][0], f"loop {layer_text}, {LOOP_XFADE} s crossfade of the end into the start, "
                                   f"high-pass 30 Hz, RMS {LOOP_RMS}, Ogg Vorbis q5")
        if len(layers) > 1:
            meta["mixed_with"] = [entry(sid, "layer") for sid, *_ in layers[1:]]
        files[name] = meta
    return files


def sound_of(path: str) -> str:
    """Catalogue id of a manifest file: steps/step_grate_01.wav -> step_grate."""
    stem = Path(path).stem
    return stem.rsplit("_", 1)[0] if path.startswith("steps/") else stem


def merge_manifest(old: dict, rebuilt: dict) -> dict:
    """Rebuilt sounds replace their old entries in place (a format change WAV -> Ogg included)."""
    groups: dict[str, dict] = {}
    for path, meta in rebuilt.items():
        groups.setdefault(sound_of(path), {})[path] = meta
    merged: dict = {}
    for path, meta in old.items():
        group = groups.pop(sound_of(path), None) if sound_of(path) in groups else None
        if group is not None:
            merged.update(group)
        elif not any(sound_of(path) == sound_of(p) for p in rebuilt):
            merged[path] = meta
    for group in groups.values():
        merged.update(group)
    return merged


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--src", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--only", default="", help="comma-separated catalogue ids to rebuild")
    args = parser.parse_args()
    only = set(filter(None, args.only.split(","))) or None
    manifest_path = args.out / "manifest.json"
    files = {}
    if only is None or only & STEPS.keys():
        files.update(build_steps(args.src, args.out, only))
    files.update(build_one_shots(args.src, args.out, only))
    files.update(build_loops(args.src, args.out, only))
    if only is None or only & {"gen_start", "gen_run"}:
        files.update(build_generator(args.src, args.out))
    # Entries of other builders (tools/audio/dream_sounds.py) stay in a full rebuild too.
    if manifest_path.exists():
        files = merge_manifest(json.loads(manifest_path.read_text(encoding="utf-8"))["files"], files)
    manifest = {"note": "Recorded CC0 sounds (#137, #209, #218). Built by tools/audio/cc0_sounds.py and "
                            "tools/audio/dream_sounds.py.", "files": files}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(files)} files in {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
