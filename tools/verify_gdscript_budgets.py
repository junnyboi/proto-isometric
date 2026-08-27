#!/usr/bin/python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOTS = (ROOT / 'scripts', ROOT / 'test', ROOT / 'assets')
MAX_FILE_LINES = 1_000
MAX_PUBLIC_METHODS = 30
MAX_RETURNS_PER_METHOD = 20
METHOD = re.compile(r'^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
RETURN = re.compile(r'^\s*return(?:\s|$)')


def inspect(path: Path) -> tuple[int, int, int, list[str]]:
    lines = path.read_text(encoding='utf-8').splitlines()
    methods: list[tuple[int, str]] = []
    for index, line in enumerate(lines):
        match = METHOD.match(line)
        if match:
            methods.append((index, match.group(1)))
    public_count = sum(1 for _, name in methods if not name.startswith('_'))
    max_returns = 0
    failures: list[str] = []
    for method_index, (start, name) in enumerate(methods):
        end = methods[method_index + 1][0] if method_index + 1 < len(methods) else len(lines)
        returns = sum(1 for line in lines[start:end] if RETURN.match(line))
        max_returns = max(max_returns, returns)
        if returns > MAX_RETURNS_PER_METHOD:
            failures.append(f'{path.relative_to(ROOT)}::{name} returns={returns}')
    if len(lines) > MAX_FILE_LINES:
        failures.append(f'{path.relative_to(ROOT)} lines={len(lines)}')
    if public_count > MAX_PUBLIC_METHODS:
        failures.append(f'{path.relative_to(ROOT)} public_methods={public_count}')
    return len(lines), public_count, max_returns, failures


def main() -> None:
    paths = sorted(
        path
        for source_root in SOURCE_ROOTS
        for path in source_root.rglob('*.gd')
        if path.is_file()
    )
    failures: list[str] = []
    maximum_lines = (0, '')
    maximum_public = (0, '')
    maximum_returns = (0, '')
    for path in paths:
        lines, public, returns, problems = inspect(path)
        relative = path.relative_to(ROOT).as_posix()
        maximum_lines = max(maximum_lines, (lines, relative))
        maximum_public = max(maximum_public, (public, relative))
        maximum_returns = max(maximum_returns, (returns, relative))
        failures.extend(problems)
    if failures:
        raise SystemExit('GDSCRIPT_BUDGET_FAIL\n' + '\n'.join(failures))
    print(
        'GDSCRIPT_BUDGET_PASS '
        f'files={len(paths)} '
        f'max_lines={maximum_lines[0]}:{maximum_lines[1]} '
        f'max_public={maximum_public[0]}:{maximum_public[1]} '
        f'max_returns={maximum_returns[0]}:{maximum_returns[1]}'
    )


if __name__ == '__main__':
    main()
