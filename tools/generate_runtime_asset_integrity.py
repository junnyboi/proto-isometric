#!/usr/bin/python3
from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
OUTPUT = ASSETS / 'RUNTIME_ASSET_INTEGRITY.tsv'
EXTENSIONS = {'.png', '.wav', '.ogg', '.otf'}
P10_PREFIXES = (
    'assets/fishing/',
    'assets/settlement/orchard/',
    'assets/ui/items/',
)


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            hasher.update(chunk)
    return hasher.hexdigest()


def provenance(path: Path) -> str:
    relative = path.relative_to(ROOT).as_posix()
    if relative.startswith(P10_PREFIXES):
        return 'assets/settlement/P10_SOURCES.md'
    parent = path.parent
    while parent == ASSETS or ASSETS in parent.parents:
        candidate = parent / 'SOURCES.md'
        if candidate.is_file():
            return candidate.relative_to(ROOT).as_posix()
        if parent == ASSETS:
            break
        parent = parent.parent
    return 'UNMAPPED'


def descriptor(path: Path) -> str:
    if path.suffix.lower() != '.png':
        return '-'
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        return f'{image.width}x{image.height}:{image.mode}'


def main() -> None:
    paths = sorted(
        path for path in ASSETS.rglob('*')
        if path.is_file() and path.suffix.lower() in EXTENSIONS
    )
    rows = ['path\tbytes\tsha256\tdescriptor\tprovenance']
    for path in paths:
        relative = path.relative_to(ROOT).as_posix()
        source = provenance(path)
        if source == 'UNMAPPED':
            raise RuntimeError(f'missing provenance mapping: {relative}')
        rows.append(
            f'{relative}\t{path.stat().st_size}\t{digest(path)}\t'
            f'{descriptor(path)}\t{source}'
        )
    OUTPUT.write_text('\n'.join(rows) + '\n', encoding='utf-8')
    print(f'RUNTIME_ASSET_ROWS={len(paths)}')
    print(f'RUNTIME_ASSET_LEDGER={OUTPUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
