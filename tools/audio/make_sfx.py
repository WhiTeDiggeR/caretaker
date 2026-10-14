#!/usr/bin/env python3
"""Generate the placeholder sound effects of the opening systems (#126).

Every sound is synthesised here from sine/square waves and filtered noise; nothing comes
from third-party sources. Standard library only. Output: loads/audio/sfx/<id>.wav
(22050 Hz, mono, 16 bit). The playback catalogue (bus, volume, 3D) is data/audio/sfx.json.

Usage: python3 tools/audio/make_sfx.py [--out DIR] [--check]
  --check  render in memory and fail if a committed file differs from its recipe
           (sample tolerance absorbs last-bit differences of math libraries).
"""

from __future__ import annotations

import argparse
import io
import math
import random
import sys
import wave
from array import array
from pathlib import Path

RATE = 22050
PEAK = 0.7  # of full scale, leaves headroom
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "loads" / "audio" / "sfx"
SEED = 126
CHECK_TOLERANCE = 2  # int16 steps
TAU = 2.0 * math.pi

Signal = list


def samples(duration: float) -> int:
    return int(RATE * duration)


def sine(freq, duration: float) -> Signal:
    """`freq` is a number or a per-sample list (phase is integrated)."""
    n = samples(duration)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        f = freq[i] if isinstance(freq, list) else freq
        phase += TAU * f / RATE
        out[i] = math.sin(phase)
    return out


def square(freq: float, duration: float) -> Signal:
    return [0.6 if v >= 0.0 else -0.6 for v in sine(freq, duration)]


def ramp(start: float, end: float, duration: float) -> Signal:
    n = samples(duration)
    return [start + (end - start) * i / max(n - 1, 1) for i in range(n)]


def sweep(start: float, end: float, duration: float) -> Signal:
    return sine(ramp(start, end, duration), duration)


def noise(duration: float, rng: random.Random) -> Signal:
    return [rng.uniform(-1.0, 1.0) for _ in range(samples(duration))]


def lowpass(signal: Signal, cutoff: float) -> Signal:
    alpha = 1.0 - math.exp(-TAU * cutoff / RATE)
    out = [0.0] * len(signal)
    acc = 0.0
    for i, value in enumerate(signal):
        acc += alpha * (value - acc)
        out[i] = acc
    return out


def highpass(signal: Signal, cutoff: float) -> Signal:
    return sub(signal, lowpass(signal, cutoff))


def envelope(n: int, attack: float, release: float) -> Signal:
    env = [1.0] * n
    a = min(samples(attack), n)
    r = min(samples(release), n - a)
    for i in range(a):
        env[i] = i / a
    for i in range(r):
        env[n - r + i] = 1.0 - i / r
    return env


def decay(n: int, seconds: float) -> Signal:
    return [math.exp(-i / (RATE * seconds)) for i in range(n)]


def lfo(freq: float, duration: float, base: float, depth: float) -> Signal:
    return [base + depth * math.sin(TAU * freq * i / RATE) for i in range(samples(duration))]


def mul(*signals) -> Signal:
    n = min(len(s) for s in signals if isinstance(s, list))
    out = [1.0] * n
    for s in signals:
        if isinstance(s, list):
            for i in range(n):
                out[i] *= s[i]
        else:
            out = [v * s for v in out]
    return out


def add(*signals: Signal) -> Signal:
    n = max(len(s) for s in signals)
    out = [0.0] * n
    for s in signals:
        for i, v in enumerate(s):
            out[i] += v
    return out


def sub(a: Signal, b: Signal) -> Signal:
    return [x - y for x, y in zip(a, b)]


def place(total: float, parts) -> Signal:
    out = [0.0] * samples(total)
    for start, part in parts:
        i = samples(start)
        for k, v in enumerate(part[: max(len(out) - i, 0)]):
            out[i + k] += v
    return out


def beep(freq: float, duration: float, wave_fn=sine) -> Signal:
    part = wave_fn(freq, duration)
    return mul(part, envelope(len(part), 0.005, duration * 0.4))


def thud(duration: float, rng: random.Random, freq: float = 70.0) -> Signal:
    n = samples(duration)
    body = mul(sine(freq, duration), decay(n, duration * 0.25))
    hit = mul(lowpass(noise(duration, rng), 900), decay(n, 0.02), 2.0)
    return add(body, hit)


def click(rng: random.Random, duration: float = 0.012, cutoff: float = 4000) -> Signal:
    return mul(highpass(noise(duration, rng), cutoff), decay(samples(duration), 0.003), 1.5)


# --- Recipes ------------------------------------------------------------------

def door_motor(rng):
    d = 1.3
    hum = add(mul(sine(55, d), 0.5), mul(sine(110, d), 0.3), mul(sine(165, d), 0.1))
    grind = mul(lowpass(noise(d, rng), 400), 1.8)
    return mul(add(hum, grind), envelope(samples(d), 0.15, 0.25))


def door_mech(rng):
    d = 1.0
    ratchet = place(d, [(i * 0.085, mul(click(rng, 0.02, 1500), 0.9)) for i in range(11)])
    groan = mul(lowpass(noise(d, rng), 250), 1.2)
    return mul(add(ratchet, groan), envelope(samples(d), 0.05, 0.2))


def door_swing(rng):
    d = 0.7
    pitch = add(ramp(320, 240, d), mul(sine(23, d), 18.0))
    creak = mul(sine(pitch, d), 0.35)
    return mul(add(creak, mul(lowpass(noise(d, rng), 600), 0.4)), envelope(samples(d), 0.05, 0.3))


def door_stop(rng):
    return thud(0.3, rng, 65)


def airlock_cycle(rng):
    d = 2.5
    hiss = mul(highpass(lowpass(noise(d, rng), 3500), 600), 1.2)
    return mul(hiss, envelope(samples(d), 0.3, 0.8))


def interact_click(rng):
    return mul(beep(2100, 0.05), 0.4)


def interact_denied(rng):
    return place(0.25, [(0.0, beep(180, 0.09, square)), (0.13, beep(180, 0.09, square))])


def hold_done(rng):
    return mul(place(0.25, [(0.0, beep(660, 0.1)), (0.1, beep(880, 0.14))]), 0.7)


def lever(rng):
    d = 0.35
    metal = mul(sine(900, d), decay(samples(d), 0.05), 0.4)
    return add(thud(d, rng, 90), metal)


def valve(rng):
    d = 0.6
    squeak = mul(sweep(520, 700, d), 0.3, lfo(9, d, 0.6, 0.4))
    return mul(add(squeak, mul(lowpass(noise(d, rng), 900), 0.6)), envelope(samples(d), 0.05, 0.2))


def switch(rng):
    return place(0.08, [(0.0, click(rng, 0.015, 3000))])


def breaker(rng):
    d = 0.3
    snap = place(d, [(0.0, mul(click(rng, 0.02, 2000), 1.3))])
    buzz = mul(square(100, d), decay(samples(d), 0.06), 0.25)
    return add(snap, buzz)


def terminal_type(rng):
    return place(0.03, [(0.0, mul(click(rng, 0.01, 5000), 0.5))])


def terminal_beep(rng):
    return mul(beep(1000, 0.15), 0.5)


def terminal_error(rng):
    return place(0.42, [(i * 0.14, mul(beep(220, 0.1, square), 0.6)) for i in range(3)])


def alarm_stage(rng):
    return place(1.6, [(i * 0.4, mul(beep(650 if i % 2 == 0 else 900, 0.38, square), 0.5)) for i in range(4)])


def chem_warning(rng):
    return place(1.2, [(i * 0.2, mul(beep(1250, 0.11), 0.8)) for i in range(6)])


def gas_release(rng):
    d = 2.5
    return mul(highpass(noise(d, rng), 1800), 0.9, envelope(samples(d), 0.05, 1.2))


def vent(rng):
    d = 2.0
    return mul(lowpass(noise(d, rng), 300), 2.0, lfo(18, d, 0.65, 0.35), envelope(samples(d), 0.4, 0.5))


def recharge(rng):
    d = 0.8
    rise = mul(sweep(300, 900, d), 0.35, envelope(samples(d), 0.05, 0.1))
    return add(rise, place(d, [(0.7, click(rng, 0.03, 1200))]))


def checkpoint(rng):
    d = 0.6
    return mul(add(sine(880, d), mul(sine(1320, d), 0.6)), decay(samples(d), 0.18), 0.45)


def dream_enter(rng):
    d = 1.5
    shimmer = mul(sine(2400, d), 0.08, lfo(7, d, 0.5, 0.5))
    return mul(add(mul(sweep(200, 1200, d), 0.35), shimmer), envelope(samples(d), 0.2, 0.4))


def dream_exit(rng):
    d = 1.2
    return mul(sweep(1100, 180, d), 0.35, envelope(samples(d), 0.05, 0.5))


def defeat(rng):
    d = 2.5
    drone = add(mul(sine(55, d), 0.6), mul(sine(58.5, d), 0.5), mul(sine(110, d), 0.2))
    return mul(drone, envelope(samples(d), 0.05, 1.5))


def hint(rng):
    return mul(beep(1500, 0.18), 0.25)


# --- First-person feel (#134) ----------------------------------------------------

def ring(rng, partials, duration: float, seconds: float) -> Signal:
    n = samples(duration)
    tones = [mul(sine(freq * (1.0 + rng.uniform(-0.02, 0.02)), duration), level) for freq, level in partials]
    return mul(add(*tones), decay(n, seconds))


def step_concrete(rng):
    d = 0.18
    grit = mul(lowpass(noise(d, rng), 1400), decay(samples(d), 0.025), 1.6)
    return add(grit, mul(thud(d, rng, 85), 0.7))


def step_metal(rng):
    d = 0.35
    return add(mul(thud(d, rng, 110), 0.6), ring(rng, [(420, 0.5), (1130, 0.3), (1870, 0.15)], d, 0.07))


def step_grate(rng):
    d = 0.3
    rattle = place(d, [(i * 0.022 + rng.uniform(0, 0.01), mul(click(rng, 0.015, 2000), 0.6 - i * 0.1)) for i in range(5)])
    return add(mul(thud(d, rng, 95), 0.5), rattle, ring(rng, [(760, 0.25), (1540, 0.12)], d, 0.05))


def step_crawl(rng):
    d = 0.3
    rustle = highpass(lowpass(noise(d, rng), 3000), 700)
    return mul(rustle, envelope(samples(d), 0.06, 0.18), 0.5)


def step_ladder(rng):
    d = 0.3
    return add(mul(thud(d, rng, 120), 0.4), ring(rng, [(650, 0.5), (1600, 0.25), (2900, 0.1)], d, 0.06))


def land(rng):
    d = 0.45
    grit = mul(lowpass(noise(d, rng), 1100), decay(samples(d), 0.05), 1.4)
    return add(thud(d, rng, 60), grit)


def breath(rng):
    d = 0.9
    air = highpass(lowpass(noise(d, rng), 1800), 250)
    return mul(air, envelope(samples(d), 0.18, 0.55), lfo(1.3, d, 0.8, 0.2), 0.6)


# Bowser's dream (#201): stingers. The stage loops are synthesised in the game
# (objects/audio/dream_audio.gd) to keep the placeholders within their budget.


def dream_ambush(rng):
    d = 1.0
    rise = mul(add(sweep(90, 420, d), mul(sweep(95, 445, d), 0.8)), 0.4, envelope(samples(d), 0.6, 0.4))
    return add(mul(thud(0.9, rng, 45.0), 1.4), rise)


def dream_seal(rng):
    d = 1.3
    n = samples(d)
    bell = add(*(mul(sine(f, d), a, decay(n, t)) for f, a, t in ((660, 0.5, 0.6), (990, 0.35, 0.45), (1320, 0.3, 0.35), (1980, 0.15, 0.2))))
    return add(click(rng, 0.03, 2500), mul(bell, envelope(n, 0.005, 0.6)))


def dream_gate(rng):
    d = 1.1
    n = samples(d)
    whoosh = mul(highpass(lowpass(noise(d, rng), 2500), 300), lfo(0.5 / d, d, 0.0, 1.0))
    shimmer = mul(add(sweep(600, 1500, d), mul(sine(2400, d), 0.3)), 0.3, lfo(9, d, 0.6, 0.4))
    return mul(add(whoosh, shimmer), envelope(n, 0.2, 0.6))


def dream_chain_hit(rng):
    d = 0.5
    n = samples(d)
    ring = add(*(mul(sine(f, d), a, decay(n, t)) for f, a, t in ((520, 0.5, 0.25), (1340, 0.35, 0.15), (2210, 0.25, 0.1))))
    return add(thud(d, rng, 80.0), ring, click(rng, 0.02, 3000))


RECIPES = {
    "door_motor": door_motor,
    "door_mech": door_mech,
    "door_swing": door_swing,
    "door_stop": door_stop,
    "airlock_cycle": airlock_cycle,
    "interact_click": interact_click,
    "interact_denied": interact_denied,
    "hold_done": hold_done,
    "lever": lever,
    "valve": valve,
    "switch": switch,
    "breaker": breaker,
    "terminal_type": terminal_type,
    "terminal_beep": terminal_beep,
    "terminal_error": terminal_error,
    "alarm_stage": alarm_stage,
    "chem_warning": chem_warning,
    "gas_release": gas_release,
    "vent": vent,
    "recharge": recharge,
    "checkpoint": checkpoint,
    "dream_enter": dream_enter,
    "dream_exit": dream_exit,
    "defeat": defeat,
    "hint": hint,
    "step_concrete": step_concrete,
    "step_metal": step_metal,
    "step_grate": step_grate,
    "step_crawl": step_crawl,
    "step_ladder": step_ladder,
    "land": land,
    "breath": breath,
    "dream_ambush": dream_ambush,
    "dream_seal": dream_seal,
    "dream_gate": dream_gate,
    "dream_chain_hit": dream_chain_hit,
}

# Each sound's random generator is seeded by its place here: new sounds are appended so
# the sounds generated before them keep their samples.
SEED_ORDER = [
    "airlock_cycle", "alarm_stage", "breaker", "checkpoint", "chem_warning", "defeat",
    "door_mech", "door_motor", "door_stop", "door_swing", "dream_enter", "dream_exit",
    "gas_release", "hint", "hold_done", "interact_click", "interact_denied", "lever",
    "recharge", "switch", "terminal_beep", "terminal_error", "terminal_type", "valve", "vent",
    # #134
    "step_concrete", "step_metal", "step_grate", "step_crawl", "step_ladder", "land", "breath",
    # #201
    "dream_ambush", "dream_seal", "dream_gate", "dream_chain_hit",
]


def render_pcm(name: str) -> array:
    rng = random.Random(SEED * 1000 + SEED_ORDER.index(name))
    signal = RECIPES[name](rng)
    peak = max((abs(v) for v in signal), default=0.0) or 1.0
    return array("h", (int(round(v / peak * PEAK * 32767)) for v in signal))


def to_wav(pcm: array) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        data = array("h", pcm)
        if sys.byteorder == "big":
            data.byteswap()
        out.writeframes(data.tobytes())
    return buffer.getvalue()


def read_pcm(path: Path) -> array | None:
    try:
        with wave.open(str(path), "rb") as source:
            if (source.getnchannels(), source.getsampwidth(), source.getframerate()) != (1, 2, RATE):
                return None
            data = array("h")
            data.frombytes(source.readframes(source.getnframes()))
            if sys.byteorder == "big":
                data.byteswap()
            return data
    except (OSError, wave.Error):
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    problems = [f"{name} has no place in SEED_ORDER" for name in RECIPES if name not in SEED_ORDER]
    total = 0
    for name in sorted(RECIPES):
        pcm = render_pcm(name)
        total += len(pcm) * 2 + 44
        path = args.out / f"{name}.wav"
        if args.check:
            stored = read_pcm(path)
            if stored is None or len(stored) != len(pcm) or any(abs(a - b) > CHECK_TOLERANCE for a, b in zip(stored, pcm)):
                problems.append(f"{path.name} differs from its recipe")
        else:
            args.out.mkdir(parents=True, exist_ok=True)
            path.write_bytes(to_wav(pcm))
    print(f"{len(RECIPES)} sounds, {total / 1024:.0f} KiB")
    for problem in problems:
        print("FAIL", problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
