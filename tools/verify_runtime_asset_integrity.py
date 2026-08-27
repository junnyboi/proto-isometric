#!/usr/bin/python3
from __future__ import annotations

import csv
import hashlib
import json
import subprocess
import wave
from pathlib import Path
from typing import Any

from fontTools.ttLib import TTFont
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / 'assets/RUNTIME_ASSET_INTEGRITY.tsv'
FONT = ROOT / 'assets/fonts/NotoSansCJKsc-ProtoIsometric.otf'
LOCALES = (
    ROOT / 'data/locales/en.json',
    ROOT / 'data/locales/zh-CN.json',
)


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            hasher.update(chunk)
    return hasher.hexdigest()


def strings(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [text for child in value for text in strings(child)]
    if isinstance(value, dict):
        return [text for key, child in value.items() for text in (str(key), *strings(child))]
    return []


def verify_audio(path: Path) -> None:
    if path.suffix.lower() == '.wav':
        with wave.open(str(path), 'rb') as audio:
            expected = audio.getnframes() * audio.getnchannels() * audio.getsampwidth()
            if len(audio.readframes(audio.getnframes())) != expected:
                raise RuntimeError(f'incomplete WAV decode: {path}')
        return
    completed = subprocess.run(
        ['ffmpeg', '-v', 'error', '-i', str(path), '-map', '0:a:0', '-f', 'null', '-'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(f'Ogg decode failed: {path}: {completed.stderr.strip()}')


def verify_ledger() -> int:
    count = 0
    listed: set[str] = set()
    with LEDGER.open(encoding='utf-8', newline='') as handle:
        for row in csv.DictReader(handle, delimiter='\t'):
            listed.add(row['path'])
            path = ROOT / row['path']
            source = ROOT / row['provenance']
            if not path.is_file() or not source.is_file():
                raise RuntimeError(f'missing ledger dependency: {path} / {source}')
            if path.stat().st_size != int(row['bytes']) or digest(path) != row['sha256']:
                raise RuntimeError(f'integrity mismatch: {path}')
            if path.suffix.lower() == '.png':
                with Image.open(path) as image:
                    image.verify()
                with Image.open(path) as image:
                    actual_descriptor = f'{image.width}x{image.height}:{image.mode}'
                if actual_descriptor != row['descriptor']:
                    raise RuntimeError(f'image descriptor mismatch: {path}')
            elif path.suffix.lower() in {'.wav', '.ogg'}:
                verify_audio(path)
            count += 1
    actual = {
        path.relative_to(ROOT).as_posix()
        for path in (ROOT / 'assets').rglob('*')
        if path.is_file() and path.suffix.lower() in {'.png', '.wav', '.ogg', '.otf'}
    }
    if listed != actual:
        raise RuntimeError(
            f'ledger inventory drift: missing={sorted(actual - listed)} '
            f'extra={sorted(listed - actual)}'
        )
    return count


def verify_font() -> int:
    font = TTFont(FONT)
    cmap: set[int] = set()
    for table in font['cmap'].tables:
        if table.isUnicode():
            cmap.update(table.cmap)
    required: set[int] = set(range(32, 127))
    for path in LOCALES:
        data = json.loads(path.read_text(encoding='utf-8'))
        required.update(
            ord(character)
            for text in strings(data)
            for character in text
            if ord(character) >= 32
        )
    missing = sorted(codepoint for codepoint in required if codepoint not in cmap)
    if missing:
        sample = ' '.join(f'U+{codepoint:04X}' for codepoint in missing[:32])
        raise RuntimeError(f'runtime font misses {len(missing)} locale codepoints: {sample}')
    return len(required)


def main() -> None:
    rows = verify_ledger()
    codepoints = verify_font()
    print(f'RUNTIME_ASSET_INTEGRITY_PASS rows={rows} font_codepoints={codepoints}')


if __name__ == '__main__':
    main()
