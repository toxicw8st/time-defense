extends Node

## Headless Step 5 acceptance verification (v3.0 Zero-Surge / Zero-Mutation + Paid Ability Upgrade Ladders):
## - Surge penalties & permanent enemy mutations are retired (0 surges, 1.0x HP/speed baseline regardless of casts)
## - Surge row is hidden in BottomBar for cleaner mobile layout
## - All 3 Paid Time Abilities (Time Freeze, Overclock, Temporal Rewind) upgrade cleanly from Tier 1 -> Tier 5

func _ready() -> void:
	GameState.reset_meta_progression()
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var wm: WaveManager = inst.get_node("WaveManager")
	var surge: SurgeManager = inst.get_node("SurgeManager")
	var tp: TimePowersManager = inst.get_node("TimePowersManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	# 1) Surge retired: stepping forever never triggers surges or weakens towers!
	wm.start_wave()
	surge.step_surge(5000.0)
	assert(GameState.mission.surge_count == 0, "v3.0 must NEVER trigger Surge penalties")
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.0))

	# 2) Surge row hidden in HUD BottomBar
	var surge_row: Control = hud.get_node_or_null("BottomBar/VBox/SurgeRow") as Control
	assert(surge_row != null and not surge_row.visible, "SurgeRow must stay hidden in v3.0")

	# 3) Paid Time Ability Upgrade Ladders (T1 -> T5) for Time Freeze, Overclock & Temporal Rewind
	GameState.mission.economy["money"] = 0
	assert(not tp.can_upgrade_ability("pause") and not tp.can_upgrade_ability("haste") and not tp.can_upgrade_ability("rewind"))
	GameState.mission.economy["money"] = 25000
	for ak in ["pause", "haste", "rewind"]:
		for expected_t in range(2, 6):
			assert(tp.can_upgrade_ability(ak), "Should be able to upgrade %s to T%d" % [ak, expected_t])
			assert(tp.upgrade_ability(ak))
			assert(GameState.get_ability_level(ak) == expected_t)
		assert(not tp.can_upgrade_ability(ak), "%s must cap at Tier 5" % ak)

	# 4) Reset mission cleanly restores all ability tiers to T1
	GameState.reset_mission()
	assert(GameState.get_ability_level("pause") == 1 and GameState.get_ability_level("haste") == 1 and GameState.get_ability_level("rewind") == 1)

	print("STEP5_TEST_PASS surge_retired=ok abilities_t1_to_t5=ok")
	get_tree().quit(0)
