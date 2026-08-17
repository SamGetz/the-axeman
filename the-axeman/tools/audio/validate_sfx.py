#!/usr/bin/env python3
"""Static waveform checks for every live sound-manifest variation."""

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
    checked_paths: set[Path] = set()
    manifest_references = 0
    for cue_id, cue in data["cues"].items():
        for relative in cue["variations"]:
            manifest_references += 1
            path = ROOT / relative.removeprefix("res://")
            if not path.exists():
                errors.append(f"{cue_id}: missing {path}")
                continue
            if path in checked_paths:
                continue
            checked_paths.add(path)
            with wave.open(str(path), "rb") as handle:
                channels = handle.getnchannels()
                rate = handle.getframerate()
                width = handle.getsampwidth()
                frames = handle.getnframes()
                pcm = np.frombuffer(
                    handle.readframes(frames), dtype="<i2"
                ).astype(np.float64)
            seconds = frames / max(rate, 1)
            peak = np.max(np.abs(pcm)) / 32767.0
            dc = abs(float(np.mean(pcm))) / 32767.0
            hard_clips = int(np.count_nonzero((pcm == 32767) | (pcm == -32768)))
            if not 22_050 <= rate <= 96_000 or width != 2 \
                    or channels not in (1, 2):
                errors.append(
                    f"{cue_id}: expected 22.05–96kHz 16-bit mono/stereo"
                )
            if not 0.08 <= seconds <= 2.0:
                errors.append(f"{cue_id}: unexpected duration {seconds:.3f}s")
            if peak < 0.01:
                errors.append(f"{cue_id}: stream is effectively silent")
            if hard_clips > 0:
                errors.append(f"{cue_id}: contains {hard_clips} clipped samples")
            if dc > 0.005:
                errors.append(f"{cue_id}: DC offset too large ({dc:.5f})")
    if errors:
        raise SystemExit("\n".join(errors))
    print(
        f"PASS: {len(checked_paths)} live WAV assets across "
        f"{manifest_references} cue references are engine-safe, bounded, "
        "DC-safe and hard-clip-free"
    )


if __name__ == "__main__":
    main()
