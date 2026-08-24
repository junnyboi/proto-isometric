#!/usr/bin/env python3
"""Batch-test biome BGM loop seams in decoded audio and in Godot.

The offline gate decodes every Ogg through ffmpeg and measures the actual
last-sample-to-first-sample boundary. The runtime gate launches Godot's
`test/bgm_loop_runtime.gd`, which seeks each imported stream near its end and
asserts that playback remains active and wraps to the beginning.
"""

from __future__ import annotations

import argparse
import array
import dataclasses
import json
import math
import os
import pathlib
import shutil
import subprocess
import sys
from collections.abc import Sequence

SAMPLE_RATE = 48_000
CHANNELS = 2
EXPECTED_TRACK_NAMES = (
    "bgm_desert.ogg",
    "bgm_wetland.ogg",
    "bgm_frozen.ogg",
    "bgm_volcanic.ogg",
)


@dataclasses.dataclass(frozen=True)
class Thresholds:
    minimum_duration_seconds: float
    maximum_edge_jump_dbfs: float
    maximum_edge_vs_local_db: float
    maximum_dc_delta_dbfs: float
    maximum_rms_delta_db: float


@dataclasses.dataclass(frozen=True)
class TrackResult:
    path: str
    duration_seconds: float
    edge_jump_dbfs: float
    edge_vs_local_db: float
    dc_delta_dbfs: float
    rms_delta_db: float
    passed: bool
    failures: tuple[str, ...]


class LoopTestError(RuntimeError):
    """Raised when required tooling or a subprocess fails."""


def _dbfs(value: float) -> float:
    return 20.0 * math.log10(max(abs(value), 1e-12))


def _rms_from_sum(square_sum: float, count: int) -> float:
    return math.sqrt(square_sum / max(count, 1))


def _decode_f32le(path: pathlib.Path, ffmpeg: str) -> array.array[float]:
    command = [
        ffmpeg,
        "-v",
        "error",
        "-i",
        str(path),
        "-f",
        "f32le",
        "-acodec",
        "pcm_f32le",
        "-ar",
        str(SAMPLE_RATE),
        "-ac",
        str(CHANNELS),
        "-",
    ]
    process = subprocess.run(command, check=False, capture_output=True)
    if process.returncode != 0:
        error = process.stderr.decode("utf-8", errors="replace").strip()
        raise LoopTestError(f"ffmpeg failed for {path}: {error}")
    samples: array.array[float] = array.array("f")
    samples.frombytes(process.stdout)
    if sys.byteorder != "little":
        samples.byteswap()
    if len(samples) < SAMPLE_RATE * CHANNELS:
        raise LoopTestError(f"decoded audio is unexpectedly short: {path}")
    if len(samples) % CHANNELS != 0:
        raise LoopTestError(f"decoded sample count is not stereo-aligned: {path}")
    return samples


def _analyze_track(
    path: pathlib.Path,
    ffmpeg: str,
    thresholds: Thresholds,
) -> TrackResult:
    samples = _decode_f32le(path, ffmpeg)
    frame_count = len(samples) // CHANNELS
    duration_seconds = frame_count / SAMPLE_RATE

    edge_jump = max(
        abs(samples[channel] - samples[(frame_count - 1) * CHANNELS + channel])
        for channel in range(CHANNELS)
    )
    edge_jump_dbfs = _dbfs(edge_jump)

    local_frames = min(int(SAMPLE_RATE * 0.05), frame_count // 4)
    derivative_square_sum = 0.0
    derivative_count = 0
    for channel in range(CHANNELS):
        for frame in range(1, local_frames):
            difference = (
                samples[frame * CHANNELS + channel]
                - samples[(frame - 1) * CHANNELS + channel]
            )
            derivative_square_sum += difference * difference
            derivative_count += 1
        tail_start = frame_count - local_frames
        for frame in range(tail_start + 1, frame_count):
            difference = (
                samples[frame * CHANNELS + channel]
                - samples[(frame - 1) * CHANNELS + channel]
            )
            derivative_square_sum += difference * difference
            derivative_count += 1
    local_derivative_rms = _rms_from_sum(
        derivative_square_sum,
        derivative_count,
    )
    edge_vs_local_db = 20.0 * math.log10(
        max(edge_jump, 1e-12) / max(local_derivative_rms, 1e-12)
    )

    dc_frames = min(int(SAMPLE_RATE * 0.05), frame_count // 4)
    dc_delta = 0.0
    for channel in range(CHANNELS):
        head_mean = sum(
            samples[frame * CHANNELS + channel]
            for frame in range(dc_frames)
        ) / dc_frames
        tail_mean = sum(
            samples[frame * CHANNELS + channel]
            for frame in range(frame_count - dc_frames, frame_count)
        ) / dc_frames
        dc_delta = max(dc_delta, abs(head_mean - tail_mean))
    dc_delta_dbfs = _dbfs(dc_delta)

    rms_frames = min(int(SAMPLE_RATE * 0.25), frame_count // 4)
    head_square_sum = 0.0
    tail_square_sum = 0.0
    rms_sample_count = rms_frames * CHANNELS
    for frame in range(rms_frames):
        for channel in range(CHANNELS):
            head_sample = samples[frame * CHANNELS + channel]
            tail_sample = samples[(frame_count - rms_frames + frame) * CHANNELS + channel]
            head_square_sum += head_sample * head_sample
            tail_square_sum += tail_sample * tail_sample
    head_rms_dbfs = _dbfs(_rms_from_sum(head_square_sum, rms_sample_count))
    tail_rms_dbfs = _dbfs(_rms_from_sum(tail_square_sum, rms_sample_count))
    rms_delta_db = abs(head_rms_dbfs - tail_rms_dbfs)

    failures: list[str] = []
    if duration_seconds < thresholds.minimum_duration_seconds:
        failures.append(
            f"duration {duration_seconds:.3f}s is below "
            f"{thresholds.minimum_duration_seconds:.3f}s"
        )
    if edge_jump_dbfs > thresholds.maximum_edge_jump_dbfs:
        failures.append(
            f"edge jump {edge_jump_dbfs:.2f} dBFS exceeds "
            f"{thresholds.maximum_edge_jump_dbfs:.2f} dBFS"
        )
    if edge_vs_local_db > thresholds.maximum_edge_vs_local_db:
        failures.append(
            f"edge/local ratio {edge_vs_local_db:.2f} dB exceeds "
            f"{thresholds.maximum_edge_vs_local_db:.2f} dB"
        )
    if dc_delta_dbfs > thresholds.maximum_dc_delta_dbfs:
        failures.append(
            f"DC delta {dc_delta_dbfs:.2f} dBFS exceeds "
            f"{thresholds.maximum_dc_delta_dbfs:.2f} dBFS"
        )
    if rms_delta_db > thresholds.maximum_rms_delta_db:
        failures.append(
            f"RMS delta {rms_delta_db:.2f} dB exceeds "
            f"{thresholds.maximum_rms_delta_db:.2f} dB"
        )

    return TrackResult(
        path=str(path),
        duration_seconds=duration_seconds,
        edge_jump_dbfs=edge_jump_dbfs,
        edge_vs_local_db=edge_vs_local_db,
        dc_delta_dbfs=dc_delta_dbfs,
        rms_delta_db=rms_delta_db,
        passed=not failures,
        failures=tuple(failures),
    )


def _run_godot_runtime_gate(project_root: pathlib.Path, godot: str) -> str:
    harness = project_root / "test" / "bgm_loop_runtime.gd"
    command = [
        godot,
        "--headless",
        "--audio-driver",
        "Dummy",
        "--path",
        str(project_root),
        "-s",
        str(harness),
    ]
    environment = os.environ.copy()
    environment["GODOT_SILENCE_ROOT_WARNING"] = "1"
    process = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        timeout=30,
        env=environment,
    )
    output = "\n".join(part for part in (process.stdout, process.stderr) if part).strip()
    if process.returncode != 0:
        raise LoopTestError(
            f"Godot runtime loop gate exited with {process.returncode}:\n{output}"
        )
    if "[BGM_LOOP_GODOT_PASS]" not in output:
        raise LoopTestError(f"Godot runtime pass marker is missing:\n{output}")
    if "ERROR:" in output or "SCRIPT ERROR:" in output or "Parse Error" in output:
        raise LoopTestError(f"Godot runtime loop gate reported an error:\n{output}")
    return output


def _print_results(results: Sequence[TrackResult]) -> None:
    print(
        "Track              Duration  Edge jump  Edge/local  DC delta  "
        "RMS delta  Result"
    )
    print("-" * 91)
    for result in results:
        print(
            f"{pathlib.Path(result.path).name:<18} "
            f"{result.duration_seconds:>7.3f}s "
            f"{result.edge_jump_dbfs:>9.2f} "
            f"{result.edge_vs_local_db:>10.2f} "
            f"{result.dc_delta_dbfs:>8.2f} "
            f"{result.rms_delta_db:>9.2f} "
            f"{'PASS' if result.passed else 'FAIL'}"
        )
        for failure in result.failures:
            print(f"  - {failure}")


def _write_json_report(
    path: pathlib.Path,
    results: Sequence[TrackResult],
    godot_passed: bool,
    thresholds: Thresholds,
) -> None:
    payload = {
        "schema_version": 1,
        "sample_rate_hz": SAMPLE_RATE,
        "channels": CHANNELS,
        "thresholds": dataclasses.asdict(thresholds),
        "godot_runtime_passed": godot_passed,
        "tracks": [dataclasses.asdict(result) for result in results],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def _resolve_executable(requested: str, label: str) -> str:
    expanded = os.path.expanduser(requested)
    resolved = shutil.which(expanded)
    if resolved is None and pathlib.Path(expanded).is_file():
        resolved = str(pathlib.Path(expanded).resolve())
    if resolved is None:
        raise LoopTestError(f"{label} executable was not found: {requested}")
    return resolved


def _parse_args(project_root: pathlib.Path) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Batch-test biome Ogg loop seams and Godot loop wrap behavior.",
    )
    parser.add_argument(
        "tracks",
        nargs="*",
        type=pathlib.Path,
        default=[
            project_root / "assets" / "audio" / name
            for name in EXPECTED_TRACK_NAMES
        ],
        help="Ogg files to test; defaults to the four shipped biome tracks.",
    )
    parser.add_argument(
        "--ffmpeg",
        default="ffmpeg",
        help="ffmpeg executable used for deterministic float PCM decoding.",
    )
    parser.add_argument(
        "--godot",
        default=os.environ.get("GODOT", "~/.local/bin/godot"),
        help="Godot executable used for imported-stream loop-wrap validation.",
    )
    parser.add_argument(
        "--skip-godot",
        action="store_true",
        help="Run only decoded waveform seam checks.",
    )
    parser.add_argument(
        "--json-report",
        type=pathlib.Path,
        help="Optional path for a machine-readable JSON report.",
    )
    parser.add_argument("--minimum-duration-seconds", type=float, default=80.0)
    parser.add_argument("--maximum-edge-jump-dbfs", type=float, default=-35.0)
    parser.add_argument("--maximum-edge-vs-local-db", type=float, default=15.0)
    parser.add_argument("--maximum-dc-delta-dbfs", type=float, default=-35.0)
    parser.add_argument("--maximum-rms-delta-db", type=float, default=14.0)
    return parser.parse_args()


def main() -> int:
    project_root = pathlib.Path(__file__).resolve().parents[1]
    args = _parse_args(project_root)
    thresholds = Thresholds(
        minimum_duration_seconds=args.minimum_duration_seconds,
        maximum_edge_jump_dbfs=args.maximum_edge_jump_dbfs,
        maximum_edge_vs_local_db=args.maximum_edge_vs_local_db,
        maximum_dc_delta_dbfs=args.maximum_dc_delta_dbfs,
        maximum_rms_delta_db=args.maximum_rms_delta_db,
    )
    try:
        ffmpeg = _resolve_executable(args.ffmpeg, "ffmpeg")
        tracks = [path.resolve() for path in args.tracks]
        missing = [str(path) for path in tracks if not path.is_file()]
        if missing:
            raise LoopTestError("missing track(s): " + ", ".join(missing))
        results = [
            _analyze_track(path, ffmpeg, thresholds)
            for path in tracks
        ]
        _print_results(results)
        waveform_passed = all(result.passed for result in results)
        godot_passed = args.skip_godot
        if not args.skip_godot:
            godot = _resolve_executable(args.godot, "Godot")
            godot_output = _run_godot_runtime_gate(project_root, godot)
            print(godot_output)
            godot_passed = True
        if args.json_report:
            _write_json_report(
                args.json_report,
                results,
                godot_passed,
                thresholds,
            )
        if not waveform_passed or not godot_passed:
            print(
                f"[BGM_LOOP_BATCH_FAIL] tracks={len(results)}",
                file=sys.stderr,
            )
            return 1
        mode = "skipped" if args.skip_godot else "pass"
        print(f"[BGM_LOOP_BATCH_PASS] tracks={len(results)} godot={mode}")
        return 0
    except (LoopTestError, subprocess.TimeoutExpired) as error:
        print(f"[BGM_LOOP_BATCH_ERROR] {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
