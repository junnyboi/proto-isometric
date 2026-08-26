#!/usr/bin/env python3
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "export_presets.cfg"
lines = path.read_text().splitlines()
entries = [
    "res://scripts/legacy_machine_recipe_adapter.gd",
    "res://scripts/logistics_service.gd",
    "res://scripts/production_policy_service.gd",
]
marker = "res://scripts/machine_service.gd"
for index, line in enumerate(lines):
    if not line.startswith("export_files="):
        continue
    for entry in entries:
        line = line.replace("," + entry, '", "' + entry)
    if '"' + marker + '"' not in line:
        raise SystemExit(f"export marker missing: {marker}")
    for entry in entries:
        if '"' + entry + '"' in line:
            continue
        line = line.replace('"' + marker + '"', '"' + marker + '", "' + entry + '"', 1)
    lines[index] = line
    break
else:
    raise SystemExit("export_files line missing")
path.write_text("\n".join(lines) + "\n")
print(f"registered {len(entries)} P8 export entries")
