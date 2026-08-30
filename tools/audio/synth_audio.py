#!/usr/bin/env python3
"""Phase 11 audio synthesis (docs/art/13_AUDIO_VFX_SPEC.md).

Generates the production audio bank into assets/audio/production/ as 22050 Hz
16-bit mono WAVs. Deterministic (seeded RNG, pure stdlib synthesis) so the
committed bank is reproducible; re-running must produce identical files.

Layers covered:
- terrain dig impacts: soil / clay / loose / stone / root
- interaction cues: designate paint, cancel, tool select, zone assign
- discovery stinger (first reveal of a major feature)
- emergency cues: breach burst, collapse rumble, critical creak
- ambience: low underground room-tone loop + three drip one-shots
"""

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
OUTPUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "audio" / "production"
RNG_SEED = 1101


def _write_wav(name: str, samples: list[float]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUTPUT_DIR / name
    clamped = [max(-1.0, min(1.0, s)) for s in samples]
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", int(s * 32767)) for s in clamped)
        handle.writeframes(frames)
    print(f"wrote {path.relative_to(OUTPUT_DIR.parents[2])} ({len(clamped) / SAMPLE_RATE:.2f}s)")


def _seconds(value: float) -> int:
    return int(value * SAMPLE_RATE)


def _env(t: float, attack: float, release: float, duration: float) -> float:
    """Simple attack/decay envelope over [0, duration]."""
    if t < attack:
        return t / max(attack, 1e-6)
    fade = max(duration - attack, 1e-6)
    return max(0.0, 1.0 - (t - attack) / fade) ** release


def _lowpass(samples: list[float], cutoff: float) -> list[float]:
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
    out = []
    state = 0.0
    for s in samples:
        state += alpha * (s - state)
        out.append(state)
    return out


def _highpass(samples: list[float], cutoff: float) -> list[float]:
    alpha = math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
    out = []
    prev_in = 0.0
    prev_out = 0.0
    for s in samples:
        out.append(alpha * (prev_out + s - prev_in))
        prev_in = s
        prev_out = out[-1]
    return out


def _noise(rng: random.Random, duration: float, level: float = 1.0) -> list[float]:
    return [rng.uniform(-level, level) for _ in range(_seconds(duration))]


def _tone(freq: float, duration: float, level: float = 0.6, harmonics: int = 3) -> list[float]:
    out = []
    for i in range(_seconds(duration)):
        t = i / SAMPLE_RATE
        value = 0.0
        for h in range(1, harmonics + 1):
            value += math.sin(2 * math.pi * freq * h * t) / h
        out.append(value * level / harmonics)
    return out


def _mix(*layers: tuple[list[float], float]) -> list[float]:
    length = max(len(s) for s, _ in layers)
    out = [0.0] * length
    for samples, gain in layers:
        for i, s in enumerate(samples):
            out[i] += s * gain
    return out


def _delay(samples: list[float], delay_seconds: float, feedback: float, taps: int) -> list[float]:
    d = _seconds(delay_seconds)
    out = list(samples)
    for tap in range(1, taps + 1):
        gain = feedback ** tap
        for i, s in enumerate(samples):
            j = i + d * tap
            if j < len(out):
                out[j] += s * gain
    return out


def synth_dig_soil(rng: random.Random) -> list[float]:
    """Soft low thud: filtered noise burst."""
    body = _lowpass(_noise(rng, 0.09), 480)
    knock = _tone(95, 0.07, 0.5, 2)
    return _mix((body, 0.9), (knock, 0.7))


def synth_dig_clay(rng: random.Random) -> list[float]:
    """Denser compacted impact."""
    body = _lowpass(_noise(rng, 0.1), 900)
    knock = _tone(150, 0.06, 0.7, 2)
    return _mix((body, 0.85), (knock, 0.9))


def synth_dig_loose(rng: random.Random) -> list[float]:
    """Crumbly double tick."""
    tick_a = _highpass(_noise(rng, 0.045), 1400)
    tick_b = _highpass(_noise(rng, 0.05), 1000)
    gap = [0.0] * _seconds(0.05)
    return _mix((tick_a + gap + tick_b, 0.85))


def synth_dig_stone(rng: random.Random) -> list[float]:
    """Sharp crack with a bright transient."""
    click = _highpass(_noise(rng, 0.02), 3000)
    crack = _lowpass(_noise(rng, 0.09), 1600)
    ring = _tone(310, 0.12, 0.25, 4)
    return _mix((click, 1.0), (crack, 0.8), (ring, 0.4))


def synth_dig_root(rng: random.Random) -> list[float]:
    """Fibrous creak-then-snap."""
    wobble = []
    for i in range(_seconds(0.11)):
        t = i / SAMPLE_RATE
        freq = 180 + 60 * math.sin(2 * math.pi * 14 * t)
        wobble.append(math.sin(2 * math.pi * freq * t) * 0.6)
    snap = _highpass(_noise(rng, 0.03), 1800)
    out = _mix((wobble, 0.7), ([0.0] * _seconds(0.09) + snap, 0.9))
    return out


def synth_ui_tick(rng: random.Random, freq: float) -> list[float]:
    tone = _tone(freq, 0.05, 0.5, 1)
    click = _highpass(_noise(rng, 0.008), 2500)
    return _mix((tone, 0.8), (click, 0.5))


def synth_zone_assign() -> list[float]:
    """Soft down-sweeping pop."""
    out = []
    for i in range(_seconds(0.13)):
        t = i / SAMPLE_RATE
        freq = 340 * (1.0 - 0.55 * t / 0.13)
        env = _env(t, 0.004, 1.6, 0.13)
        out.append(math.sin(2 * math.pi * freq * t) * 0.55 * env)
    return out


def synth_discovery_stinger() -> list[float]:
    """Warm two-note marimba-ish figure, restrained per spec §4."""
    note_a = _delay(_tone(440.0, 0.22, 0.5, 4), 0.05, 0.35, 3)
    gap = [0.0] * _seconds(0.12)
    note_b = _delay(_tone(554.37, 0.4, 0.5, 5), 0.06, 0.3, 3)
    return _mix((note_a + gap + note_b, 0.9))


def synth_breach(rng: random.Random) -> list[float]:
    """Water burst: low whoosh + splash droplets."""
    whoosh = _lowpass(_noise(rng, 0.5), 700)
    splash = _highpass(_noise(rng, 0.35), 900)
    droplets = []
    for _ in range(5):
        start = _seconds(rng.uniform(0.12, 0.4))
        drop = _tone(rng.uniform(600, 1400), 0.05, 0.4, 1)
        droplets = droplets + [0.0] * max(0, start - len(droplets))
        for i, s in enumerate(drop):
            if start + i < len(droplets):
                droplets[start + i] += s
            else:
                droplets.append(s)
    return _mix((whoosh, 0.9), (splash, 0.6), (droplets, 0.7))


def synth_collapse(rng: random.Random) -> list[float]:
    """Low rumble with debris tail."""
    rumble = _lowpass(_noise(rng, 0.85), 220)
    debris = _lowpass(_highpass(_noise(rng, 0.5), 500), 2400)
    tail = [0.0] * _seconds(0.3) + debris
    return _mix((rumble, 1.0), (tail, 0.55))


def synth_critical_creak() -> list[float]:
    """Slow rising creak for critical stability warnings."""
    out = []
    for i in range(_seconds(0.55)):
        t = i / SAMPLE_RATE
        freq = 90 + 55 * t / 0.55 + 18 * math.sin(2 * math.pi * 7 * t)
        rough = math.sin(2 * math.pi * freq * t) + 0.4 * math.sin(2 * math.pi * freq * 2.7 * t)
        env = _env(t, 0.05, 1.2, 0.55)
        out.append(rough * 0.4 * env)
    return _mix((out, 1.0))


def synth_ambience(rng: random.Random) -> list[float]:
    """6 s loopable low room tone: brown noise, seam-crossfaded."""
    duration = 6.0
    brown = []
    state = 0.0
    for _ in range(_seconds(duration)):
        state = max(-1.0, min(1.0, state + rng.uniform(-0.02, 0.02)))
        brown.append(state)
    brown = _lowpass(brown, 240)
    fade = _seconds(0.75)
    for i in range(fade):
        blend = i / fade
        head, tail = brown[i], brown[len(brown) - fade + i]
        brown[i] = head * blend + tail * (1.0 - blend)
    return brown[: len(brown) - fade]


def synth_drip(rng: random.Random) -> list[float]:
    """Single water drip: fast pitch-dropping ping with a short tail."""
    out = []
    for i in range(_seconds(0.28)):
        t = i / SAMPLE_RATE
        freq = rng.uniform(900, 1500) * (1.0 - 0.4 * min(1.0, t / 0.05))
        env = _env(t, 0.002, 4.0, 0.28)
        out.append(math.sin(2 * math.pi * freq * t) * 0.5 * env)
    return _delay(out, 0.06, 0.4, 3)


def main() -> None:
    rng = random.Random(RNG_SEED)
    bank = {
        "dig_soil_01.wav": synth_dig_soil(rng),
        "dig_clay_01.wav": synth_dig_clay(rng),
        "dig_loose_01.wav": synth_dig_loose(rng),
        "dig_stone_01.wav": synth_dig_stone(rng),
        "dig_root_01.wav": synth_dig_root(rng),
        "ui_paint.wav": synth_ui_tick(rng, 620),
        "ui_cancel.wav": synth_ui_tick(rng, 300),
        "ui_tool.wav": synth_ui_tick(rng, 950),
        "zone_assign.wav": synth_zone_assign(),
        "stinger_discovery.wav": synth_discovery_stinger(),
        "cue_breach.wav": synth_breach(rng),
        "cue_collapse.wav": synth_collapse(rng),
        "cue_critical.wav": synth_critical_creak(),
        "amb_underground.wav": synth_ambience(rng),
        "drip_01.wav": synth_drip(rng),
        "drip_02.wav": synth_drip(rng),
        "drip_03.wav": synth_drip(rng),
    }
    for name, samples in bank.items():
        peak = max(abs(s) for s in samples)
        if peak > 0.92:
            scale = 0.92 / peak
            samples = [s * scale for s in samples]
        _write_wav(name, samples)
    print(f"bank complete: {len(bank)} files, seed={RNG_SEED}")


if __name__ == "__main__":
    main()
