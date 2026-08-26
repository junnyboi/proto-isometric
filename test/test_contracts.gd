extends RefCounted

const AudioServiceTestsScript: GDScript = preload("res://test/test_audio_service.gd")
const AttackAOETestsScript: GDScript = preload("res://test/test_attack_aoe.gd")
const BalanceTestsScript: GDScript = preload("res://test/test_balance.gd")
const BiomeDestructibleTestsScript: GDScript = preload("res://test/test_biome_destructibles.gd")
const BiomeFaunaTestsScript: GDScript = preload("res://test/test_biome_fauna.gd")
const BiomeIntelPanelTestsScript: GDScript = preload("res://test/test_biome_intel_panel.gd")
const BiomeWeatherAudioTestsScript: GDScript = preload("res://test/test_biome_weather_audio.gd")
const BiomeWeatherParticleTestsScript: GDScript = preload(
	"res://test/test_biome_weather_particles.gd"
)
const CameraZoomTestsScript: GDScript = preload("res://test/test_camera_zoom.gd")
const CharacterHoverTestsScript: GDScript = preload("res://test/test_character_hover.gd")
const DeepBiomeHazardTestsScript: GDScript = preload("res://test/test_deep_biome_hazards.gd")
const EnemySFXTestsScript: GDScript = preload("res://test/test_enemy_sfx.gd")
const ExpeditionTestsScript: GDScript = preload("res://test/test_expedition.gd")
const ExpeditionRadarTestsScript: GDScript = preload("res://test/test_expedition_radar.gd")
const FieldUITestsScript: GDScript = preload("res://test/test_field_ui.gd")
const FrozenTundraTestsScript: GDScript = preload("res://test/test_frozen_tundra.gd")
const InputFeelTestsScript: GDScript = preload("res://test/test_input_feel.gd")
const IronjawBossTestsScript: GDScript = preload("res://test/test_ironjaw_boss.gd")
const KilnheartBossTestsScript: GDScript = preload("res://test/test_kilnheart_boss.gd")
const LavaFieldsTestsScript: GDScript = preload("res://test/test_lava_fields.gd")
const LocalizationTestsScript: GDScript = preload("res://test/test_localization.gd")
const MeleePressureTestsScript: GDScript = preload("res://test/test_melee_pressure.gd")
const OasisWetlandsTestsScript: GDScript = preload("res://test/test_oasis_wetlands.gd")
const OutpostVisualTestsScript: GDScript = preload("res://test/test_outpost_visuals.gd")
const PreferenceTestsScript: GDScript = preload("res://test/test_preferences.gd")
const PerformanceTestsScript: GDScript = preload("res://test/test_performance.gd")
const PeacefulHerdTestsScript: GDScript = preload("res://test/test_peaceful_herds.gd")
const RefitTestsScript: GDScript = preload("res://test/test_refit.gd")
const RewardFeedbackTestsScript: GDScript = preload("res://test/test_reward_feedback.gd")
const ResponsiveViewportTestsScript: GDScript = preload("res://test/test_responsive_viewport.gd")
const RunPickupTestsScript: GDScript = preload("res://test/test_run_pickups.gd")
const SanctuaryBoundaryTestsScript: GDScript = preload("res://test/test_sanctuary_boundary.gd")
const SandwormVisualTestsScript: GDScript = preload("res://test/test_sandworm_visuals.gd")
const SaveMigrationTestsScript: GDScript = preload("res://test/test_save_migrations.gd")
const SaveRepositoryTestsScript: GDScript = preload("res://test/test_save_repository.gd")
const SmashFeedbackTestsScript: GDScript = preload("res://test/test_smash_feedback.gd")
const StateTestsScript: GDScript = preload("res://test/test_state.gd")
const TerminalFlowTestsScript: GDScript = preload("res://test/test_terminal_flow.gd")
const TerrainTransitionTestsScript: GDScript = preload("res://test/test_terrain_transitions.gd")
const TitleBriefingTestsScript: GDScript = preload("res://test/test_title_briefing.gd")
const VisualCatalogTestsScript: GDScript = preload("res://test/test_visual_catalog.gd")
const WormCounterplayTestsScript: GDScript = preload("res://test/test_worm_counterplay.gd")
const WormTelegraphTestsScript: GDScript = preload("res://test/test_worm_telegraph.gd")
const WalkerLocomotionFeedbackTestsScript: GDScript = preload(
	"res://test/test_walker_locomotion_feedback.gd"
)
const HUDFeedbackTestsScript: GDScript = preload("res://test/test_hud_feedback.gd")
const HarvestPhaseZeroTestsScript: GDScript = preload("res://test/test_harvest_phase_zero.gd")
const HarvestSettlementPhaseOneTestsScript: GDScript = preload(
	"res://test/test_harvest_settlement_phase_one.gd"
)
const HarvestSettlementPhaseTwoTestsScript: GDScript = preload(
	"res://test/test_harvest_settlement_phase_two.gd"
)
const HarvestSettlementPhaseThreeTestsScript: GDScript = preload(
	"res://test/test_harvest_settlement_phase_three.gd"
)
const HarvestSettlementPhaseFourTestsScript: GDScript = preload(
	"res://test/test_harvest_settlement_phase_four.gd"
)
const EnvironmentRewardFeedbackTestsScript: GDScript = preload(
	"res://test/test_environment_reward_feedback.gd"
)
const FeedbackAccessibilityTestsScript: GDScript = preload(
	"res://test/test_feedback_accessibility.gd"
)
const JuiceCertificationTestsScript: GDScript = preload("res://test/test_juice_certification.gd")


static func evaluate(
	coordinator: RefCounted, world: RefCounted, runtime: Node = null
) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	cases.append_array(AudioServiceTestsScript.evaluate())
	cases.append_array(AttackAOETestsScript.evaluate())
	cases.append_array(BalanceTestsScript.evaluate(coordinator))
	cases.append_array(BiomeDestructibleTestsScript.evaluate())
	cases.append_array(BiomeFaunaTestsScript.evaluate(runtime))
	cases.append_array(BiomeIntelPanelTestsScript.evaluate(runtime))
	cases.append_array(BiomeWeatherAudioTestsScript.evaluate())
	cases.append_array(BiomeWeatherParticleTestsScript.evaluate())
	cases.append_array(CameraZoomTestsScript.evaluate())
	cases.append_array(StateTestsScript.evaluate(coordinator))
	cases.append_array(TerminalFlowTestsScript.evaluate())
	cases.append_array(TerrainTransitionTestsScript.evaluate())
	cases.append_array(VisualCatalogTestsScript.evaluate())
	cases.append_array(FieldUITestsScript.evaluate())
	cases.append_array(InputFeelTestsScript.evaluate())
	cases.append_array(IronjawBossTestsScript.evaluate())
	cases.append_array(KilnheartBossTestsScript.evaluate())
	cases.append_array(CharacterHoverTestsScript.evaluate())
	cases.append_array(DeepBiomeHazardTestsScript.evaluate())
	cases.append_array(EnemySFXTestsScript.evaluate())
	cases.append_array(LocalizationTestsScript.evaluate())
	cases.append_array(MeleePressureTestsScript.evaluate())
	cases.append_array(PreferenceTestsScript.evaluate())
	cases.append_array(PerformanceTestsScript.evaluate())
	cases.append_array(SmashFeedbackTestsScript.evaluate())
	cases.append_array(PeacefulHerdTestsScript.evaluate())
	cases.append_array(OutpostVisualTestsScript.evaluate())
	if runtime != null:
		cases.append_array(PerformanceTestsScript.evaluate_live(runtime, world))
	cases.append_array(ResponsiveViewportTestsScript.evaluate())
	cases.append_array(TitleBriefingTestsScript.evaluate())
	cases.append_array(OasisWetlandsTestsScript.evaluate())
	cases.append_array(FrozenTundraTestsScript.evaluate())
	cases.append_array(LavaFieldsTestsScript.evaluate())
	cases.append_array(ExpeditionRadarTestsScript.evaluate())
	cases.append_array(ExpeditionTestsScript.evaluate())
	cases.append_array(RefitTestsScript.evaluate())
	cases.append_array(RewardFeedbackTestsScript.evaluate())
	cases.append_array(WormCounterplayTestsScript.evaluate())
	cases.append_array(SandwormVisualTestsScript.evaluate())
	cases.append_array(RunPickupTestsScript.evaluate())
	cases.append_array(WormTelegraphTestsScript.evaluate())
	cases.append_array(WalkerLocomotionFeedbackTestsScript.evaluate())
	cases.append_array(HUDFeedbackTestsScript.evaluate())
	cases.append_array(HarvestPhaseZeroTestsScript.evaluate())
	cases.append_array(EnvironmentRewardFeedbackTestsScript.evaluate())
	cases.append_array(FeedbackAccessibilityTestsScript.evaluate())
	cases.append_array(JuiceCertificationTestsScript.evaluate())
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
	cases.append_array(
		HarvestSettlementPhaseOneTestsScript.evaluate(
			world,
			coordinator.call("get_run_snapshot") as Dictionary,
			coordinator.call("get_profile_snapshot") as Dictionary,
		)
	)
	cases.append_array(HarvestSettlementPhaseTwoTestsScript.evaluate(runtime as Node2D))
	cases.append_array(HarvestSettlementPhaseThreeTestsScript.evaluate())
	cases.append_array(HarvestSettlementPhaseFourTestsScript.evaluate_contracts())
	return cases
