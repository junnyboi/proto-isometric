#!/usr/bin/env python3
"""Extract seamless biome weather loops from generated audio-bearing carriers."""

from __future__ import annotations

import hashlib
import json
import math
import re
import shutil
import struct
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CARRIER_DIR = ROOT / ".generated" / "weather_audio" / "carriers"
INTERMEDIATE_DIR = ROOT / ".generated" / "weather_audio" / "intermediate"
OUTPUT_DIR = ROOT / "assets" / "audio" / "weather"
METRICS_PATH = ROOT / ".generated" / "weather_audio" / "weather_audio_metrics.json"

CUES = {
    "weather_desert_glasswind.wav": "weather_desert_glasswind.mp4",
    "weather_wetland_reedrain.wav": "weather_wetland_reedrain.mp4",
    "weather_frozen_whiteout.wav": "weather_frozen_whiteout.mp4",
    "weather_volcanic_ashfall.wav": "weather_volcanic_ashfall.mp4",
}

SAMPLE_RATE = 48_000
DURATION_SECONDS = 8.0
EXPECTED_FRAMES = int(SAMPLE_RATE * DURATION_SECONDS)
SEAM_SECONDS = 1.5
SEAM_FRAMES = int(SAMPLE_RATE * SEAM_SECONDS)
SOURCE_START = 0.25
SOURCE_DURATION = 9.5
SOURCE_FRAMES = int(SAMPLE_RATE * SOURCE_DURATION)
TARGET_LUFS = -34.0
PEAK_CEILING = 0.5


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(f"Required tool is unavailable: {name}")


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def extract_normalized_source(carrier: Path, intermediate: Path) -> None:
    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            "-ss",
            str(SOURCE_START),
            "-t",
            str(SOURCE_DURATION),
            "-i",
            str(carrier),
            "-af",
            "aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=mono,"
            "loudnorm=I=-34:TP=-6:LRA=5,aresample=48000,"
            f"asetnsamples=n={SOURCE_FRAMES}:p=1",
            "-ac",
            "1",
            "-ar",
            str(SAMPLE_RATE),
            "-c:a",
            "pcm_s16le",
            str(intermediate),
        ]
    )


def read_pcm16(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as wav_file:
        if wav_file.getnchannels() != 1 or wav_file.getframerate() != SAMPLE_RATE:
            raise RuntimeError(f"{path.name}: unexpected intermediate format")
        frames = wav_file.readframes(wav_file.getnframes())
    return np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0


def write_pcm16(path: Path, samples: np.ndarray) -> None:
    clipped = np.clip(samples, -1.0, 1.0)
    pcm = np.rint(clipped * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(pcm.tobytes())


def measure_lufs(path: Path) -> float:
    result = subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-nostats",
            "-i",
            str(path),
            "-filter_complex",
            "ebur128=peak=true",
            "-f",
            "null",
            "-",
        ],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    matches = re.findall(r"I:\s+(-?\d+(?:\.\d+)?) LUFS", result.stderr)
    if not matches:
        raise RuntimeError(f"{path.name}: unable to measure integrated loudness")
    return float(matches[-1])


def normalize_loop_loudness(path: Path) -> float:
    current_lufs = measure_lufs(path)
    samples = read_pcm16(path)
    requested_gain = 10.0 ** ((TARGET_LUFS - current_lufs) / 20.0)
    peak = float(np.max(np.abs(samples)))
    peak_gain = PEAK_CEILING / max(peak, 1e-8)
    samples *= min(requested_gain, peak_gain)
    write_pcm16(path, samples)
    return measure_lufs(path)


def build_loop(intermediate: Path, output: Path) -> None:
    source = read_pcm16(intermediate)
    if source.size < SOURCE_FRAMES:
        source = np.pad(source, (0, SOURCE_FRAMES - source.size))
    source = source[:SOURCE_FRAMES]
    head = source[:SEAM_FRAMES]
    tail = source[-SEAM_FRAMES:]
    middle = source[SEAM_FRAMES:-SEAM_FRAMES]
    phase = np.linspace(0.0, math.pi * 0.5, SEAM_FRAMES, endpoint=True)
    seam = tail * np.cos(phase) + head * np.sin(phase)
    loop = np.concatenate((middle, seam))
    if loop.size != EXPECTED_FRAMES:
        raise RuntimeError(f"{output.name}: loop construction produced {loop.size} frames")
    write_pcm16(output, loop)


def read_samples(path: Path) -> tuple[wave._wave_params, list[float]]:
    with wave.open(str(path), "rb") as wav_file:
        params = wav_file.getparams()
        frames = wav_file.readframes(params.nframes)
    values = struct.unpack(f"<{params.nframes}h", frames)
    return params, [value / 32768.0 for value in values]


def rms(samples: list[float]) -> float:
    if not samples:
        return 0.0
    return math.sqrt(sum(value * value for value in samples) / len(samples))


def analyze(path: Path) -> dict[str, float | int | str]:
    params, samples = read_samples(path)
    edge_frames = int(SAMPLE_RATE * 0.2)
    head_rms = rms(samples[:edge_frames])
    tail_rms = rms(samples[-edge_frames:])
    peak = max(abs(value) for value in samples)
    seam_jump = abs(samples[-1] - samples[0])
    overall_rms = rms(samples)
    if params.nchannels != 1:
        raise RuntimeError(f"{path.name}: expected mono, got {params.nchannels} channels")
    if params.framerate != SAMPLE_RATE:
        raise RuntimeError(f"{path.name}: expected {SAMPLE_RATE} Hz, got {params.framerate}")
    if params.sampwidth != 2:
        raise RuntimeError(f"{path.name}: expected 16-bit PCM")
    if params.nframes != EXPECTED_FRAMES:
        raise RuntimeError(f"{path.name}: expected {EXPECTED_FRAMES} frames, got {params.nframes}")
    if overall_rms <= 0.002:
        raise RuntimeError(f"{path.name}: output is effectively silent")
    if peak > 0.55:
        raise RuntimeError(f"{path.name}: peak exceeds conservative weather ceiling")
    if seam_jump > max(0.035, peak * 0.18):
        raise RuntimeError(f"{path.name}: seam jump is too large ({seam_jump:.6f})")
    edge_ratio = max(head_rms, tail_rms) / max(min(head_rms, tail_rms), 1e-8)
    if edge_ratio > 2.5:
        raise RuntimeError(f"{path.name}: edge energy mismatch is too large ({edge_ratio:.3f})")
    return {
        "sample_rate": params.framerate,
        "channels": params.nchannels,
        "sample_width_bytes": params.sampwidth,
        "frames": params.nframes,
        "duration_seconds": params.nframes / params.framerate,
        "peak_linear": round(peak, 6),
        "rms_linear": round(overall_rms, 6),
        "head_rms": round(head_rms, 6),
        "tail_rms": round(tail_rms, 6),
        "edge_ratio": round(edge_ratio, 4),
        "seam_jump": round(seam_jump, 6),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size_bytes": path.stat().st_size,
    }


def main() -> None:
    require_tool("ffmpeg")
    require_tool("ffprobe")
    INTERMEDIATE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    metrics: dict[str, dict[str, float | int | str]] = {}
    for output_name, carrier_name in CUES.items():
        carrier = CARRIER_DIR / carrier_name
        intermediate = INTERMEDIATE_DIR / output_name
        output = OUTPUT_DIR / output_name
        if not carrier.is_file():
            raise FileNotFoundError(carrier)
        probe = run(
            [
                "ffprobe",
                "-v",
                "error",
                "-select_streams",
                "a:0",
                "-show_entries",
                "stream=codec_name,sample_rate,channels",
                "-of",
                "json",
                str(carrier),
            ]
        )
        streams = json.loads(probe.stdout).get("streams", [])
        if not streams:
            raise RuntimeError(f"{carrier.name}: carrier has no audio stream")
        extract_normalized_source(carrier, intermediate)
        build_loop(intermediate, output)
        integrated_lufs = normalize_loop_loudness(output)
        metrics[output_name] = analyze(output)
        metrics[output_name]["integrated_lufs"] = integrated_lufs
        print(json.dumps({"file": output_name, **metrics[output_name]}, sort_keys=True))
    hashes = {entry["sha256"] for entry in metrics.values()}
    if len(hashes) != len(CUES):
        raise RuntimeError("Weather outputs are not all distinct")
    METRICS_PATH.parent.mkdir(parents=True, exist_ok=True)
    METRICS_PATH.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"WEATHER_AUDIO_EXTRACTION_OK count={len(metrics)} metrics={METRICS_PATH}")


if __name__ == "__main__":
    main()
