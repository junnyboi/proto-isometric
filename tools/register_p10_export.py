#!/usr/bin/env python3
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "export_presets.cfg"
lines = path.read_text().splitlines()
entries = [
    "res://scripts/farm_occupancy_service.gd",
    "res://scripts/fishing_catalog.gd",
    "res://scripts/fishing_service.gd",
    "res://scripts/orchard_catalog.gd",
    "res://scripts/orchard_service.gd",
    "res://scripts/seasonal_interaction_provider.gd",
    "res://assets/settlement/orchard/tree_cinderapple_stages.png",
    "res://assets/settlement/orchard/tree_ironbark_stages.png",
    "res://assets/fishing/fish_glasslamp_eel.png",
    "res://assets/fishing/fish_mossback_carp.png",
    "res://assets/fishing/fish_relay_minnow.png",
    "res://assets/fishing/fish_rustfin_perch.png",
    "res://assets/ui/items/item_cinderapple_sapling.png",
    "res://assets/ui/items/item_fishing_rod.png",
    "res://assets/ui/items/item_ironbark_sapling.png",
    "res://assets/ui/items/item_luminous_bait.png",
]
marker = "res://scripts/day_advance_service.gd"
for index, line in enumerate(lines):
    if not line.startswith("export_files="):
        continue
    if f'"{marker}"' not in line:
        raise SystemExit(f"export marker missing: {marker}")
    for entry in entries:
        if f'"{entry}"' not in line:
            line = line.replace(f'"{marker}"', f'"{marker}", "{entry}"', 1)
    lines[index] = line
    break
else:
    raise SystemExit("export_files line missing")
path.write_text("\n".join(lines) + "\n")
print(f"registered {len(entries)} P10 export entries")
