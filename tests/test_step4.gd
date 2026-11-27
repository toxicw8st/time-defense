extends Node

## Headless Step 4 acceptance verification (Refinery Exponential Curve + Rogue-Like Meta-Research):
## - Refinery prices match exponential $200 * 1.8^owned curve: $200, $360, $650, $1165, $2100
## - Anti-exploit: waiting in BUILD phase generates ZERO money from Refineries!
## - Research is spent between levels only, persists across missions, and uses rank costs [100, 250, 600, 1400, 3200]
## - Currency separation: research cannot buy towers, money cannot buy research

func _ready() -> void:
	GameState.reset_meta_progression()
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main1: Node = main_scene.instantiate()
	add_child(main1)
	var econ1: EconomyManager = main1.get_node("EconomyManager")
	var hud1: CanvasLayer = main1.get_node("HUD")

	# Anti-exploit: idling 60 s in BUILD must yield 0 passive refinery money!
	GameState.mission.economy["refineries_owned"] = 2
	var start_m: int = GameState.mission.economy["money"]
	econ1.step_economy(60.0)
	assert(GameState.mission.economy["money"] == start_m, "Refineries MUST NOT generate money when not in a wave!")

	# Verify exponential refinery cost ramp: $200 * 1.8^owned -> 200, 360, 650, 1165, 2100
	var expected_costs: Array[int] = [200, 360, 650, 1165, 2100]
	for owned_count in range(0, 5):
		GameState.mission.economy["refineries_owned"] = owned_count
		var c: int = econ1.get_next_refinery_cost()
		assert(c == expected_costs[owned_count], "Refinery #%d (owned=%d) expected $%d, got $%d" % [owned_count + 1, owned_count, expected_costs[owned_count], c])

	GameState.reset_meta_progression()
	GameState.reset_mission()
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.0))
	assert(not econ1.buy_research("rapid_cycling", true), "Cannot buy research with 0 R")
	GameState.mission.economy["money"] = 9999
	assert(not econ1.buy_research("rapid_cycling", true), "Money must NEVER buy research")
	GameState.mission.economy["money"] = 0

	# Verify 1 mission's kills are capped at MAX_RESEARCH_PER_MISSION (60 R < 100 R Rank 1 cost)
	GameState.add_research(500, false)
	assert(GameState.meta_research == Balance.MAX_RESEARCH_PER_MISSION, "Single mission research must cap at %d R, got %d" % [Balance.MAX_RESEARCH_PER_MISSION, GameState.meta_research])
	assert(not econ1.buy_research("rapid_cycling", true), "Single mission's 60 R cap must NOT afford Rank 1 (100 R) on its own!")

	# Across a second mission, earn another 50 R -> 110 R total, persists across reset_mission()!
	GameState.reset_mission()
	assert(GameState.meta_research == 60, "Meta-research must persist across reset_mission()")
	GameState.add_research(50, false)
	assert(GameState.meta_research == 110)

	# Verify research cannot be bought mid-wave (in-game)
	GameState.is_wave_active = true
	assert(not econ1.buy_research("rapid_cycling", false), "Research must NOT be buyable in-game during an active wave!")
	GameState.is_wave_active = false

	# Buy Rank 1 (100 R) on the between-levels screen -> next rank costs 250 R!
	assert(econ1.buy_research("rapid_cycling", true))
	assert(GameState.get_research_rank("rapid_cycling") == 1)
	assert(GameState.get_next_research_cost("rapid_cycling") == 250)
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.05))
	hud1._refresh_debug_overlay()
	assert(hud1.debug_label.text.contains("1.05x"), "Debug overlay must show 1.05x attack-speed multiplier")

	# Verify Rank 1 persists across reset_mission()
	GameState.reset_mission()
	assert(GameState.get_research_rank("rapid_cycling") == 1 and is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.05))

	main1.queue_free()
	GameState.reset_meta_progression()
	print("STEP4_TEST_PASS refinery_ramp=[200,360,650,1165,2100] meta_research=ok")
	get_tree().quit(0)
