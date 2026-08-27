extends "res://scripts/interaction_dossier_presenter.gd"

const LegacyPresenterScript: GDScript = preload(
	"res://scripts/harvest_interaction_legacy_presenter.gd"
)

static func layout_for(
	viewport_size: Vector2,
	left_handed: bool = false,
	ui_scale: float = 1.0,
	mobile: bool = false,
	row_count: int = 32,
) -> Dictionary:
	return LegacyPresenterScript.layout_for(
		viewport_size, left_handed, ui_scale, mobile, row_count
	)

static func dossier_layout_for(
	viewport_size: Vector2,
	safe_insets: Dictionary = {},
	left_handed: bool = false,
	ui_scale: float = 1.0,
	mobile: bool = false,
	profile: StringName = &"terrain",
	row_count: int = 32,
) -> Dictionary:
	return DossierLayoutScript.layout_for(
		viewport_size, safe_insets, left_handed, ui_scale, mobile, profile, row_count
	)

static func validate_layout(layout: Dictionary) -> bool:
	return LegacyPresenterScript.validate_layout(layout)
