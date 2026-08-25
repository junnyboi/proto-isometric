#!/usr/bin/env python3
"""Brand a generated Godot Web shell with responsive Protos Harvest loader art."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

DESKTOP_NAME = "proto-isometric.loader-desktop.webp"
MOBILE_NAME = "proto-isometric.loader-mobile.webp"

LOADER_CSS = r"""

/* Protos Harvest responsive Web loader. */
#status {
	background: #07100f;
	overflow: hidden;
	isolation: isolate;
}

#status-art {
	position: absolute;
	inset: 0;
	z-index: 0;
}

#status-splash {
	position: absolute;
	inset: 0;
	display: block;
	width: 100%;
	height: 100%;
	max-width: none;
	max-height: none;
	object-fit: cover;
	filter: saturate(0.86) brightness(0.72);
}

#status-splash.fullsize--true {
	object-fit: cover;
}

#status::after {
	content: '';
	position: absolute;
	inset: 0;
	z-index: 1;
	pointer-events: none;
	background:
		linear-gradient(180deg, rgba(4, 9, 10, 0.08) 0%, rgba(4, 9, 10, 0.02) 44%, rgba(4, 9, 10, 0.74) 100%),
		radial-gradient(circle at 50% 48%, transparent 28%, rgba(4, 9, 10, 0.36) 100%);
}

#status-brand {
	position: absolute;
	left: 50%;
	bottom: calc(8% + 24px);
	z-index: 2;
	display: flex;
	width: min(72vw, 720px);
	transform: translateX(-50%);
	justify-content: space-between;
	gap: 1rem;
	color: #f3a21e;
	font: 600 12px/1.2 system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	text-shadow: 0 1px 12px rgba(0, 0, 0, 0.72);
}

#status-brand span {
	color: #d8e3df;
	font-weight: 500;
	letter-spacing: 0.1em;
}

#status-progress {
	appearance: none;
	-webkit-appearance: none;
	bottom: 8%;
	z-index: 2;
	width: min(72vw, 720px);
	height: 8px;
	margin: 0 auto;
	border: 1px solid rgba(243, 162, 30, 0.62);
	border-radius: 0;
	background: rgba(7, 16, 15, 0.84);
	box-shadow: 0 8px 28px rgba(0, 0, 0, 0.46);
	overflow: hidden;
}

#status-progress::-webkit-progress-bar {
	background: rgba(7, 16, 15, 0.84);
}

#status-progress::-webkit-progress-value {
	background: linear-gradient(90deg, #3e7f7b 0%, #f3a21e 72%, #ffd06a 100%);
}

#status-progress::-moz-progress-bar {
	background: linear-gradient(90deg, #3e7f7b 0%, #f3a21e 72%, #ffd06a 100%);
}

#status-notice {
	z-index: 3;
}

@media (orientation: portrait) {
	#status-brand,
	#status-progress {
		width: calc(100vw - 48px);
	}

	#status-brand {
		bottom: calc(6% + 24px);
		font-size: 10px;
	}

	#status-progress {
		bottom: 6%;
	}
}
"""

PICTURE_HTML = f"""<picture id="status-art">
				<source media="(orientation: portrait)" srcset="{MOBILE_NAME}">
				<img id="status-splash" class="show-image--true fullsize--true use-filter--true" src="{DESKTOP_NAME}" alt="">
			</picture>
			<div id="status-brand">Protos Harvest <span>Restoring the clearing</span></div>"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--html", required=True, type=Path)
    parser.add_argument("--desktop-source", required=True, type=Path)
    parser.add_argument("--mobile-source", required=True, type=Path)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    return parser.parse_args()


def encode_webp(ffmpeg: str, source: Path, output: Path, width: int, height: int) -> None:
    command = [
        ffmpeg,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(source),
        "-vf",
        f"scale={width}:{height}:flags=lanczos",
        "-frames:v",
        "1",
        "-c:v",
        "libwebp",
        "-quality",
        "80",
        "-compression_level",
        "6",
        "-preset",
        "picture",
        str(output),
    ]
    subprocess.run(command, check=True)


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if source.count(old) != 1:
        raise RuntimeError(f"Expected one {label}; found {source.count(old)}")
    return source.replace(old, new, 1)


def main() -> int:
    args = parse_args()
    ffmpeg = shutil.which(args.ffmpeg)
    if ffmpeg is None:
        raise RuntimeError(f"ffmpeg executable was not found: {args.ffmpeg}")
    for source in (args.html, args.desktop_source, args.mobile_source):
        if not source.is_file():
            raise RuntimeError(f"Required input is missing: {source}")

    output_dir = args.html.parent
    desktop_output = output_dir / DESKTOP_NAME
    mobile_output = output_dir / MOBILE_NAME
    encode_webp(ffmpeg, args.desktop_source, desktop_output, 1280, 720)
    encode_webp(ffmpeg, args.mobile_source, mobile_output, 720, 1280)

    html = args.html.read_text(encoding="utf-8")
    html = replace_once(html, "</style>", LOADER_CSS + "\n</style>", "style terminator")
    original_splash = '<img id="status-splash" class="show-image--true fullsize--true use-filter--true" src="proto-isometric.png" alt="">'
    html = replace_once(html, original_splash, PICTURE_HTML, "generated splash image")
    args.html.write_text(html, encoding="utf-8")
    (output_dir / "proto-isometric.png").unlink(missing_ok=True)

    for output in (desktop_output, mobile_output):
        if output.stat().st_size <= 0:
            raise RuntimeError(f"Generated loader asset is empty: {output}")
    if "Godot Game engine" in html or 'src="proto-isometric.png"' in html:
        raise RuntimeError("Generic Godot loader reference survived postprocessing")
    if DESKTOP_NAME not in html or MOBILE_NAME not in html or "#status-progress" not in html:
        raise RuntimeError("Branded loader contract is incomplete")

    print(f"Branded Web shell: {args.html}")
    print(f"Desktop loader: {desktop_output} ({desktop_output.stat().st_size} bytes)")
    print(f"Mobile loader: {mobile_output} ({mobile_output.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
