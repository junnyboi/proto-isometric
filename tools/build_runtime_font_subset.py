#!/usr/bin/python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any

DEFAULT_SOURCE = Path('/usr/share/fonts/opentype/noto/NotoSansCJKsc-Medium.otf')
DEFAULT_OUTPUT = Path('assets/fonts/NotoSansCJKsc-ProtoIsometric.otf')
LOCALES = (Path('data/locales/en.json'), Path('data/locales/zh-CN.json'))
REQUIRED_ASCII = ''.join(chr(code) for code in range(32, 127))


def strings(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [text for child in value for text in strings(child)]
    if isinstance(value, dict):
        return [text for key, child in value.items() for text in (str(key), *strings(child))]
    return []


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    if not args.source.is_file():
        raise FileNotFoundError(args.source)
    corpus = REQUIRED_ASCII
    for path in LOCALES:
        corpus += ''.join(strings(json.loads(path.read_text(encoding='utf-8'))))
    corpus += 'Protos Harvest Restoring the clearing'
    corpus_path = args.output.with_suffix('.corpus.txt')
    corpus_path.write_text(''.join(sorted(set(corpus))), encoding='utf-8')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            'pyftsubset',
            str(args.source),
            f'--text-file={corpus_path}',
            f'--output-file={args.output}',
            '--layout-features=*',
            '--glyph-names',
            '--symbol-cmap',
            '--legacy-cmap',
            '--notdef-glyph',
            '--notdef-outline',
            '--recommended-glyphs',
            '--name-IDs=*',
            '--name-legacy',
            '--name-languages=*',
            '--drop-tables+=DSIG',
        ],
        check=True,
    )
    print(f'FONT_CORPUS_CODEPOINTS={len(set(corpus))}')
    print(f'FONT_OUTPUT={args.output}')


if __name__ == '__main__':
    main()
