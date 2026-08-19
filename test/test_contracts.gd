extends RefCounted

const AttackAOETestsScript: GDScript = preload("res://test/test_attack_aoe.gd")
const BalanceTestsScript: GDScript = preload("res://test/test_balance.gd")
const ExpeditionTestsScript: GDScript = preload("res://test/test_expedition.gd")
const FieldUITestsScript: GDScript = preload("res://test/test_field_ui.gd")
const OasisWetlandsTestsScript: GDScript = preload("res://test/test_oasis_wetlands.gd")
const PreferenceTestsScript: GDScript = preload("res://test/test_preferences.gd")
const PerformanceTestsScript: GDScript = preload("res://test/test_performance.gd")
const RefitTestsScript: GDScript = preload("res://test/test_refit.gd")
const ResponsiveViewportTestsScript: GDScript = preload("res://test/test_responsive_viewport.gd")
const RunPickupTestsScript: GDScript = preload("res://test/test_run_pickups.gd")
const SanctuaryBoundaryTestsScript: GDScript = preload("res://test/test_sanctuary_boundary.gd")
const SaveMigrationTestsScript: GDScript = preload("res://test/test_save_migrations.gd")
const SaveRepositoryTestsScript: GDScript = preload("res://test/test_save_repository.gd")
const StateTestsScript: GDScript = preload("res://test/test_state.gd")
const TerminalFlowTestsScript: GDScript = preload("res://test/test_terminal_flow.gd")
const TitleBriefingTestsScript: GDScript = preload("res://test/test_title_briefing.gd")
const VisualCatalogTestsScript: GDScript = preload("res://test/test_visual_catalog.gd")
const WormCounterplayTestsScript: GDScript = preload("res://test/test_worm_counterplay.gd")
const WormTelegraphTestsScript: GDScript = preload("res://test/test_worm_telegraph.gd")


static func evaluate(coordinator: RefCounted, world: RefCounted) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	cases.append_array(AttackAOETestsScript.evaluate())
	cases.append_array(BalanceTestsScript.evaluate(coordinator))
	cases.append_array(StateTestsScript.evaluate(coordinator))
	cases.append_array(TerminalFlowTestsScript.evaluate())
	cases.append_array(VisualCatalogTestsScript.evaluate())
	cases.append_array(FieldUITestsScript.evaluate())
	cases.append_array(PreferenceTestsScript.evaluate())
	cases.append_array(PerformanceTestsScript.evaluate())
	cases.append_array(ResponsiveViewportTestsScript.evaluate())
	cases.append_array(TitleBriefingTestsScript.evaluate())
	cases.append_array(OasisWetlandsTestsScript.evaluate())
	cases.append_array(ExpeditionTestsScript.evaluate())
	cases.append_array(RefitTestsScript.evaluate())
	cases.append_array(WormCounterplayTestsScript.evaluate())
	cases.append_array(RunPickupTestsScript.evaluate())
	cases.append_array(WormTelegraphTestsScript.evaluate())
	cases.append_array(SanctuaryBoundaryTestsScript.evaluate(world))
	cases.append_array(SaveMigrationTestsScript.evaluate(world))
	(
		cases
		. append_array(
			(
				SaveRepositoryTestsScript
				. evaluate(
					world,
					coordinator.call("get_run_snapshot") as Dictionary,
					coordinator.call("get_profile_snapshot") as Dictionary,
				)
			)
		)
	)
	return cases
