#!/usr/bin/env python3
"""Brand a generated Godot Web shell with responsive Protos Harvest loader art."""

from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRIMARY_HASHES = {'Regular':'b5124032e8e51434e05a51c327a9a614ac96b85ecf9b6cdcfc58834a9ae1347d','Medium':'f28a0f3aee8f427798bf972504d5640d5d28b8692a73102ac39556fa7ffb1ee2','Bold':'099f6d50114f83533f689ddc37028fcff2bd2a2c4871a332488c1a433f440804'}
CJK_SOURCE_HASH = '2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b'
# Compatibility coverage only: the existing Protos Harvest loader copy stays English.
# These five strings are shipped by manus-addon-webdev/runtime-src/game-dev/loading-shell.html.
CJK_COMPATIBILITY_COPY = ['正在加载…', '重试', '下载进度', '游戏加载失败，请重试。', '正在启动游戏…']
FONT_START = '<!-- protos:loader-fonts:start -->'
FONT_END = '<!-- protos:loader-fonts:end -->'


def rebuild_loader_font(source: Path) -> None:
    from fontTools import subset
    from fontTools.ttLib import TTFont
    if hashlib.sha256(source.read_bytes()).hexdigest() != CJK_SOURCE_HASH:
        raise ValueError('CJK source must match the existing published Noto Sans CJK SC Regular pin')
    primary_points = sorted(TTFont(ROOT / 'assets/fonts/ManusCC0-Regular.ttf').getBestCmap())
    corpus = '\n'.join(CJK_COMPATIBILITY_COPY)
    points = sorted({ord(c) for c in corpus} - set(primary_points) - {10})
    font = TTFont(source, recalcTimestamp=False)
    assert set(points) <= set(font.getBestCmap()), 'Pinned font lacks a compatibility glyph'
    options = subset.Options(); options.name_IDs = ['*']; options.recalc_timestamp = False
    worker = subset.Subsetter(options=options); worker.populate(unicodes=points); worker.subset(font)
    for record in font['name'].names:
        if record.nameID in (1, 4, 6, 16):
            record.string = 'ProtosLoaderCJK'.encode(record.getEncoding())
    font.flavor = 'woff2'; output = io.BytesIO(); font.save(output); raw = output.getvalue()
    covered = sorted(TTFont(io.BytesIO(raw)).getBestCmap())
    assert set(points) <= set(covered)
    target = ROOT / 'tools/loader-fonts'; target.mkdir(parents=True, exist_ok=True)
    (target / '.gdignore').write_text('')
    (target / 'loader-cjk.woff2').write_bytes(raw)
    (target / 'manifest.json').write_text(json.dumps({
        'family': 'ProtosLoaderCJK', 'source': 'NotoSansCJKsc-Regular.otf',
        'sourceSha256': CJK_SOURCE_HASH, 'license': 'assets/fonts/OFL.txt',
        'sha256': hashlib.sha256(raw).hexdigest(), 'codepoints': covered,
        'primaryCodepoints': primary_points,
        'compatibilityCorpus': CJK_COMPATIBILITY_COPY,
        'compatibilityCorpusSource': 'manus-addon-webdev/runtime-src/game-dev/loading-shell.html',
        'compatibilityCorpusTextSha256': hashlib.sha256(corpus.encode()).hexdigest(),
        'actualLoaderCopy': 'Protos Harvest / Restoring the clearing; stock Godot status text remains unchanged',
    }, indent=2) + '\n')


def font_styles() -> str:
    target = ROOT / 'tools/loader-fonts'
    manifest = json.loads((target / 'manifest.json').read_text()); raw = (target / 'loader-cjk.woff2').read_bytes()
    assert manifest['sourceSha256'] == CJK_SOURCE_HASH
    assert hashlib.sha256(raw).hexdigest() == manifest['sha256'], 'Loader CJK subset changed'
    corpus = '\n'.join(CJK_COMPATIBILITY_COPY)
    assert hashlib.sha256(corpus.encode()).hexdigest() == manifest['compatibilityCorpusTextSha256'], 'Rebuild loader fonts for the changed compatibility corpus'
    assert {ord(c) for c in corpus} - {10} <= set(manifest['codepoints']) | set(manifest['primaryCodepoints'])
    rules = []
    for style, weight in (('Regular', 400), ('Medium', 500), ('Bold', 700)):
        primary = (ROOT / 'assets/fonts' / f'ManusCC0-{style}.ttf').read_bytes()
        assert hashlib.sha256(primary).hexdigest() == PRIMARY_HASHES[style]
        rules.append("@font-face{font-family:ManusCC0;src:url(data:font/ttf;base64,%s) format('truetype');font-weight:%d;font-style:normal;font-display:swap}" % (base64.b64encode(primary).decode(), weight))
    rules.append('/* ' + (ROOT / manifest['license']).read_text().replace('*/', '* /') + ' */')
    rules.append("@font-face{font-family:ProtosLoaderCJK;src:url(data:font/woff2;base64,%s) format('woff2');font-weight:400 700;font-style:normal;font-display:swap;unicode-range:%s}" % (base64.b64encode(raw).decode(), ','.join('U+%X' % p for p in manifest['codepoints'])))
    rules.append("html,body,#status-notice{font-family:ManusCC0,ProtosLoaderCJK,sans-serif;font-synthesis:none}button,input,select,textarea{font-family:inherit}")
    return '\n'.join(rules)


def install_font_styles(html: str) -> str:
    html = re.sub(r'\s*' + re.escape(FONT_START) + '.*?' + re.escape(FONT_END) + r'\s*', '\n', html, flags=re.S)
    html = html.replace("font-family: 'Noto Sans', 'Droid Sans', Arial, sans-serif", "font-family:ManusCC0,ProtosLoaderCJK,sans-serif")
    if html.count('</head>') != 1:
        raise RuntimeError('Expected a single generated HTML head')
    html = re.sub(r'\s*</head>', '\n</head>', html)
    return html.replace('</head>', FONT_START + '<style>' + font_styles() + '</style>' + FONT_END + '\n</head>', 1)


def update_export_fonts() -> None:
    config = ROOT / 'export_presets.cfg'
    source = config.read_text()
    replacement = 'html/head_include=' + json.dumps(FONT_START + '<style>' + font_styles() + '</style>' + FONT_END)
    updated, count = re.subn(r'^html/head_include=.*$', lambda _: replacement, source, flags=re.M)
    assert count == 1, 'Expected exactly one existing Web font head include'
    config.write_text(updated)

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
	font: 500 12px/1.2 'ManusCC0', ProtosLoaderCJK, sans-serif;
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
    parser.add_argument("--html", type=Path)
    parser.add_argument("--desktop-source", type=Path)
    parser.add_argument("--mobile-source", type=Path)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--rebuild-fonts", action="store_true", help="Rebuild the pinned subset with the existing fontTools/Brotli environment")
    parser.add_argument("--cjk-source", type=Path, help="Existing full Noto Sans CJK SC Regular file for explicit subset rebuilds")
    parser.add_argument("--update-export-fonts", action="store_true", help="Refresh the source Web export font head from the verified cached subset")
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
    if args.rebuild_fonts:
        if args.cjk_source is None:
            raise RuntimeError('--rebuild-fonts requires --cjk-source')
        rebuild_loader_font(args.cjk_source)
    if args.update_export_fonts:
        update_export_fonts()
    if args.html is None:
        if args.rebuild_fonts or args.update_export_fonts:
            return 0
        raise RuntimeError('--html, --desktop-source and --mobile-source are required for loader artwork')
    if args.desktop_source is None or args.mobile_source is None:
        raise RuntimeError('--desktop-source and --mobile-source are required with --html')
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

    html = install_font_styles(args.html.read_text(encoding="utf-8"))
    html, style_count = re.subn(
        r"^[ \t]*</style>",
        LOADER_CSS.strip("\n") + "\n</style>",
        html,
        count=1,
        flags=re.MULTILINE,
    )
    if style_count != 1:
        raise RuntimeError(f"Expected one style terminator; found {style_count}")
    original_splash = '<img id="status-splash" class="show-image--true fullsize--true use-filter--true" src="proto-isometric.png" alt="">'
    html = replace_once(html, original_splash, PICTURE_HTML, "generated splash image")
    html = html.rstrip() + "\n"
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
