class_name InteractionTargetAnchorCatalog
extends RefCounted

## Presentation-only screen offsets from an isometric cell center. These values never
## participate in target selection or world-state lookup.
const DEFAULT_OFFSET: Vector2 = Vector2.ZERO
const _LOWER_CENTER_OFFSETS: Dictionary = {
	&"construction": Vector2(0.0, -12.0),
	&"deposit_biomass": Vector2(0.0, -8.0),
	&"deposit_mineral": Vector2(0.0, -8.0),
	&"deposit_salvage": Vector2(0.0, -8.0),
	&"expedition_gate": Vector2(0.0, -18.0),
	&"facility": Vector2(0.0, -16.0),
	&"functional_prop": Vector2(0.0, -10.0),
	&"herd": Vector2(0.0, -10.0),
	&"home": Vector2(0.0, -14.0),
	&"hostile": Vector2(0.0, -12.0),
	&"livestock": Vector2(0.0, -10.0),
	&"machine": Vector2(0.0, -14.0),
	&"resident": Vector2(0.0, -14.0),
	&"resource": Vector2(0.0, -8.0),
	&"ruin": Vector2(0.0, -16.0),
	&"safe_exit": Vector2(0.0, -12.0),
	&"storage": Vector2(0.0, -14.0),
	&"tree": Vector2(0.0, -22.0),
	&"water": Vector2(0.0, -4.0),
}


static func lower_center_offset_for(target_subkind: StringName) -> Vector2:
	return _LOWER_CENTER_OFFSETS.get(target_subkind, DEFAULT_OFFSET) as Vector2


static func offset_for(target_subkind: StringName) -> Vector2:
	return lower_center_offset_for(target_subkind)


static func has_explicit_offset(target_subkind: StringName) -> bool:
	return _LOWER_CENTER_OFFSETS.has(target_subkind)


static func offsets() -> Dictionary:
	return _LOWER_CENTER_OFFSETS.duplicate(true)
