#!/usr/bin/env python3
"""Static waveform checks for every generated Phase-1 cue."""

from __future__ import annotations

import json
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data" / "sound_manifest.json"


def main() -> None:
    data = json.loads(MANIFEST.read_text())
    errors: list[str] = []
    checked = 0
    for cue_id, cue in data["cues"].items():
        for relative in cue["variations"]:
            path = ROOT / relative.removeprefix("res://")
            if not path.exists():
                errors.append(f"{cue_id}: missing {path}")
                continue
            with wave.open(str(path), "rb") as handle:
                channels = handle.getnchannels()
                rate = handle.getframerate()
                width = handle.getsampwidth()
                frames = handle.getnframes()
                pcm = np.frombuffer(handle.readframes(frames), dtype="<i2").astype(np.float64)
            checked += 1
            seconds = frames / max(rate, 1)
            peak = np.max(np.abs(pcm)) / 32767.0
            dc = abs(float(np.mean(pcm))) / 32767.0
            if rate != 48_000 or width != 2 or channels not in (1, 2):
                errors.append(f"{cue_id}: expected 48kHz 16-bit mono/stereo")
            if not 0.08 <= seconds <= 2.0:
                errors.append(f"{cue_id}: unexpected duration {seconds:.3f}s")
            if peak > 0.90:
                errors.append(f"{cue_id}: clipping headroom is too small ({peak:.3f})")
            if dc > 0.005:
                errors.append(f"{cue_id}: DC offset too large ({dc:.5f})")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: {checked} Phase-1 WAVs are 48kHz/16-bit, bounded, DC-safe and unclipped")


if __name__ == "__main__":
    main()
