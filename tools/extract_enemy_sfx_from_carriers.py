#!/usr/bin/env python3
"""Extract normalized mono enemy SFX WAV files from generated carrier videos."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CARRIER_DIR = ROOT / ".generated" / "enemy_sfx" / "carriers"
OUTPUT_DIR = ROOT / "assets" / "audio" / "enemies"
CUES: dict[str, tuple[str, float]] = {
    "mob_glassback_move": ("mob_glassback_move.mp4", 0.75),
    "mob_glassback_attack": ("mob_glassback_attack.mp4", 0.60),
    "mob_mire_tick_move": ("mob_mire_tick_move.mp4", 0.80),
    "mob_mire_tick_attack": ("mob_mire_tick_attack.mp4", 0.65),
    "mob_rime_shardling_move": ("mob_rime_shardling_move.mp4", 0.80),
    "mob_rime_shardling_attack": ("mob_rime_shardling_attack.mp4", 0.70),
    "mob_ember_skitter_move": ("mob_ember_skitter_move.mp4", 0.80),
    "mob_ember_skitter_attack": ("mob_ember_skitter_attack.mp4", 0.70),
    "boss_kilnheart_move": ("boss_kilnheart_move.mp4", 1.25),
    "boss_kilnheart_forge_sweep": ("boss_kilnheart_forge_sweep.mp4", 1.30),
    "boss_kilnheart_magma_ram": ("boss_kilnheart_magma_ram.mp4", 1.35),
    "boss_kilnheart_caldera_barrage": ("boss_kilnheart_caldera_barrage.mp4", 1.50),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def extract(carrier: Path, output: Path, duration: float) -> None:
    fade_out = max(duration - 0.07, 0.02)
    filters = ",".join(
        [
            "highpass=f=45",
            "lowpass=f=16000",
            "silenceremove=start_periods=1:start_duration=0.01:start_threshold=-48dB",
            f"atrim=duration={duration:.3f}",
            f"apad=pad_dur={duration:.3f}",
            f"atrim=duration={duration:.3f}",
            "asetpts=N/SR/TB",
            "loudnorm=I=-19:TP=-2:LRA=7",
            "afade=t=in:st=0:d=0.015",
            f"afade=t=out:st={fade_out:.3f}:d=0.070",
        ]
    )
    run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(carrier),
            "-vn",
            "-map",
            "0:a:0",
            "-af",
            filters,
            "-ac",
            "1",
            "-ar",
            "48000",
            "-c:a",
            "pcm_s16le",
            str(output),
        ]
    )


def metrics(path: Path) -> tuple[float, float, float]:
    with wave.open(str(path), "rb") as stream:
        if stream.getnchannels() != 1 or stream.getframerate() != 48000 or stream.getsampwidth() != 2:
            raise RuntimeError(f"{path.name}: invalid PCM contract")
        frames = stream.getnframes()
        samples = np.frombuffer(stream.readframes(frames), dtype="<i2").astype(np.float64)
    if samples.size == 0:
        raise RuntimeError(f"{path.name}: empty audio")
    normalized = samples / 32768.0
    duration = samples.size / 48000.0
    peak = float(np.max(np.abs(normalized)))
    rms = float(np.sqrt(np.mean(normalized**2)))
    if peak < 0.015 or rms < 0.001:
        raise RuntimeError(f"{path.name}: output is effectively silent peak={peak} rms={rms}")
    if peak >= 0.999:
        raise RuntimeError(f"{path.name}: output clips peak={peak}")
    return duration, peak, rms


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--carrier-dir", type=Path, default=DEFAULT_CARRIER_DIR)
    args = parser.parse_args()
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg is required")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for cue, (carrier_name, target_duration) in CUES.items():
        carrier = args.carrier_dir / carrier_name
        if not carrier.is_file():
            raise FileNotFoundError(carrier)
        output = OUTPUT_DIR / f"{cue}.wav"
        extract(carrier, output, target_duration)
        duration, peak, rms = metrics(output)
        if abs(duration - target_duration) > (1.0 / 48000.0):
            raise RuntimeError(f"{cue}: duration {duration:.6f} != {target_duration:.6f}")
        print(
            f"{cue}: duration={duration:.3f}s peak={peak:.4f} rms={rms:.4f} "
            f"sha256={sha256(output)}"
        )
    print(f"ENEMY_SFX_EXTRACTION_PASS count={len(CUES)}")


if __name__ == "__main__":
    main()
