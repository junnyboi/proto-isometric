extends RefCounted

const BalanceTestsScript: GDScript = preload("res://test/test_balance.gd")
const ExpeditionTestsScript: GDScript = preload("res://test/test_expedition.gd")
const FieldUITestsScript: GDScript = preload("res://test/test_field_ui.gd")
const RefitTestsScript: GDScript = preload("res://test/test_refit.gd")
const RunPickupTestsScript: GDScript = preload("res://test/test_run_pickups.gd")
const SaveMigrationTestsScript: GDScript = preload("res://test/test_save_migrations.gd")
const SaveRepositoryTestsScript: GDScript = preload("res://test/test_save_repository.gd")
const StateTestsScript: GDScript = preload("res://test/test_state.gd")
const WormCounterplayTestsScript: GDScript = preload("res://test/test_worm_counterplay.gd")
const WormTelegraphTestsScript: GDScript = preload("res://test/test_worm_telegraph.gd")


static func evaluate(coordinator: RefCounted, world: RefCounted) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	cases.append_array(BalanceTestsScript.evaluate(coordinator))
	cases.append_array(StateTestsScript.evaluate(coordinator))
	cases.append_array(FieldUITestsScript.evaluate())
	cases.append_array(ExpeditionTestsScript.evaluate())
	cases.append_array(RefitTestsScript.evaluate())
	cases.append_array(WormCounterplayTestsScript.evaluate())
	cases.append_array(RunPickupTestsScript.evaluate())
	cases.append_array(WormTelegraphTestsScript.evaluate())
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
