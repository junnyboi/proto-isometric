#!/usr/bin/env python3
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "export_presets.cfg"
text = path.read_text(encoding="utf-8")
needle = 'include_filter="'
start = text.index(needle) + len(needle)
end = text.index('"', start)
items = [item for item in text[start:end].split(",") if item]
additions = [
    "assets/settlement/settlers/portraits/*.png",
    "assets/settlement/settlers/sprites/*.png",
    "res://scripts/applicant_lifecycle_service.gd",
    "res://scripts/housing_protection_service.gd",
    "res://scripts/pre_p6_save_compatibility.gd",
    "res://scripts/settlement_interaction_provider.gd",
    "res://scripts/settlement_modal_controller.gd",
    "res://scripts/settlement_presenter.gd",
    "res://scripts/settlement_runtime_coordinator.gd",
    "res://scripts/settler_catalog.gd",
    "res://scripts/settler_presentation_catalog.gd",
    "res://scripts/workforce_service.gd",
]
for item in additions:
    if item not in items:
        items.append(item)
updated = text[:start] + ",".join(items) + text[end:]
path.write_text(updated, encoding="utf-8")
print(f"registered {len(additions)} P6 export entries")
