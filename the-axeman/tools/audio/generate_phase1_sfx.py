#!/usr/bin/env python3
"""Deterministically synthesize The Axeman Phase 1 SFX and review reel."""

from __future__ import annotations

import json
import math
import wave
from pathlib import Path

import numpy as np

RATE = 48_000
ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data" / "sound_manifest.json"
OUT = ROOT / "assets" / "audio" / "sfx"
REVIEW = ROOT / "assets" / "audio" / "review" / "phase1_preview.wav"


def env(length: int, attack: float = 0.01, release: float = 0.25) -> np.ndarray:
    attack_n = max(1, int(length * attack))
    release_n = max(1, int(length * release))
    sustain_n = max(0, length - attack_n - release_n)
    return np.concatenate((
        np.linspace(0.0, 1.0, attack_n, endpoint=False),
        np.ones(sustain_n),
        np.linspace(1.0, 0.0, release_n),
    ))[:length]


def tone(freq: float, seconds: float, rng: np.random.Generator,
         fall: float = 5.0, wobble: float = 0.0) -> np.ndarray:
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    phase = 2.0 * np.pi * (freq * t + wobble * np.sin(t * 7.0))
    return np.sin(phase + rng.uniform(-0.2, 0.2)) * np.exp(-fall * t)


def filtered_noise(seconds: float, rng: np.random.Generator, width: int) -> np.ndarray:
    n = int(RATE * seconds)
    raw = rng.normal(0.0, 1.0, n + width)
    kernel = np.hanning(width)
    kernel /= max(kernel.sum(), 1e-9)
    return np.convolve(raw, kernel, mode="valid")[:n]


def normalize(samples: np.ndarray, peak: float = 0.82) -> np.ndarray:
    samples = samples.astype(np.float64)
    samples -= np.mean(samples, axis=0)
    maximum = float(np.max(np.abs(samples)))
    if maximum > 1e-9:
        samples *= peak / maximum
    fade = min(240, len(samples) // 8)
    if fade > 0:
        ramp = np.linspace(0.0, 1.0, fade)
        samples[:fade] *= ramp[:, None] if samples.ndim == 2 else ramp
        samples[-fade:] *= (1.0 - ramp)[:, None] if samples.ndim == 2 else (1.0 - ramp)
    return samples


def synth(kind: str, seed: int, tier: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    if kind == "whoosh":
        seconds = 0.28
        noise = filtered_noise(seconds, rng, 18)
        sweep = np.sin(2 * np.pi * (90 + 520 * np.linspace(0, 1, len(noise)) ** 2)
                       * np.arange(len(noise)) / RATE)
        return normalize((noise * 0.65 + sweep * 0.25) * env(len(noise), 0.18, 0.38))
    if kind in {"thud", "drop", "land", "stack"}:
        seconds = {"thud": 0.34, "drop": 0.48, "land": 0.22, "stack": 0.27}[kind]
        base = {"thud": 105, "drop": 72, "land": 145, "stack": 190}[kind]
        body = sum(tone(base * ratio, seconds, rng, 7.0 + ratio)
                   * gain for ratio, gain in [(1.0, 0.8), (1.73, 0.35), (2.42, 0.2)])
        crack = filtered_noise(seconds, rng, 6) * np.exp(-np.arange(len(body)) / (RATE * 0.035))
        return normalize(body + crack * (0.55 if kind == "thud" else 0.3))
    if kind == "split":
        seconds = 0.42
        n = int(RATE * seconds)
        t = np.arange(n) / RATE
        crack = rng.normal(0, 1, n) * np.exp(-70 * t)
        crack += np.roll(crack, int(RATE * rng.uniform(0.018, 0.04))) * 0.55
        wood = tone(92 + rng.uniform(-8, 8), seconds, rng, 5.0)
        wood += tone(225, seconds, rng, 9.0) * 0.35
        return normalize(crack * 0.7 + wood)
    if kind == "haul":
        seconds = 0.62
        noise = filtered_noise(seconds, rng, 36)
        n = len(noise)
        curve = np.sin(np.linspace(0, np.pi, n)) ** 1.5
        clack = np.roll(tone(120, seconds, rng, 12.0), int(RATE * 0.18))
        return normalize(noise * curve * 0.7 + clack * 0.4)
    if kind in {"chime", "reward", "level"}:
        seconds = 0.32 + tier * 0.07 if kind != "level" else 1.15
        root = [520, 660, 780, 990][tier]
        notes = [root, root * 1.25, root * 1.5]
        if kind == "level":
            notes = [392, 523.25, 659.25, 783.99]
        n = int(RATE * seconds)
        out = np.zeros(n)
        for i, frequency in enumerate(notes):
            start = int(i * RATE * (0.045 if kind != "level" else 0.16))
            part = tone(frequency, seconds - start / RATE, rng, 4.5)
            out[start:start + len(part)] += part * (0.65 / (1 + i * 0.15))
        shimmer = filtered_noise(seconds, rng, 5) * np.exp(-12 * np.arange(n) / RATE)
        return normalize(out + shimmer * (0.06 + tier * 0.025))
    if kind == "paper":
        seconds = 0.30 + tier * 0.04
        noise = filtered_noise(seconds, rng, 7 + tier * 3)
        flutter = 0.55 + 0.45 * np.sin(np.arange(len(noise)) / RATE * (50 - tier * 6) * 2 * np.pi)
        ping = tone(720 + tier * 180, seconds, rng, 7.0) * (0.18 + tier * 0.04)
        return normalize(noise * flutter * env(len(noise), 0.06, 0.65) * 0.45 + ping)
    raise ValueError(kind)


def write_wav(path: Path, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(samples, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    channels = 1 if pcm.ndim == 1 else pcm.shape[1]
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(channels)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())


def main() -> None:
    data = json.loads(MANIFEST.read_text())
    preview = []
    silence = np.zeros(int(RATE * 0.28))
    for cue_index, (cue_id, cue) in enumerate(data["cues"].items()):
        tier = int(cue.get("tier", 0))
        kind = cue["synthesis"]
        for variation, relative in enumerate(cue["variations"]):
            samples = synth(kind, 104729 + cue_index * 97 + variation * 17, tier)
            write_wav(ROOT / relative.removeprefix("res://"), samples)
            if variation == 0:
                preview.extend([samples, silence])
    write_wav(REVIEW, np.concatenate(preview))
    print(f"Generated {sum(len(c['variations']) for c in data['cues'].values())} WAVs")
    print(f"Review reel: {REVIEW}")


if __name__ == "__main__":
    main()
