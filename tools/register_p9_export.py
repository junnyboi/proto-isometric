#!/usr/bin/env python3
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "export_presets.cfg"
lines = path.read_text().splitlines()
entry = "res://scripts/wellbeing_service.gd"
marker = "res://scripts/day_advance_service.gd"
for index, line in enumerate(lines):
    if not line.startswith("export_files="):
        continue
    if f'"{entry}"' not in line:
        if f'"{marker}"' not in line:
            raise SystemExit(f"export marker missing: {marker}")
        line = line.replace(f'"{marker}"', f'"{marker}", "{entry}"', 1)
    lines[index] = line
    break
else:
    raise SystemExit("export_files line missing")
path.write_text("\n".join(lines) + "\n")
print("registered P9 export entry")
