#!/usr/bin/env python3
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "export_presets.cfg"
text = path.read_text(encoding="utf-8")
needle = 'include_filter="'
start = text.index(needle) + len(needle)
end = text.index('"', start)
items = [item for item in text[start:end].split(",") if item]
additions = [
    "res://scripts/building_local_storage_service.gd",
    "res://scripts/gathering_extraction_service.gd",
    "res://scripts/settler_day_service.gd",
]
for item in additions:
    if item not in items:
        items.append(item)
updated = text[:start] + ",".join(items) + text[end:]
path.write_text(updated, encoding="utf-8")
print(f"registered {len(additions)} P7 export entries")
