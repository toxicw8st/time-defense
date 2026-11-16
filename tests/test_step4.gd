extends Node

## Headless Step 4 acceptance + First Balance Sanity Check (Waves 1-6, no powers):
## - Refinery prices match curve: 100, 135, 180, 245, 330
## - Buying Rapid Cycling raises fire-rate multiplier on debug overlay & towers
## - Currency separation: research cannot buy towers, money cannot buy research
## - No-refinery vs refinery-first reach Wave 5 with visibly different money totals
## - Sanity check Waves 1-6: Wave 1-2 clean, Wave 6 Runner surge leaks 0-3 lives

func _ready() -> void:
	# 1) Refinery cost curve check
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main1: Node = main_scene.instantiate()
	add_child(main1)
	var econ1: EconomyManager = main1.get_node("EconomyManager")
	var hud1: CanvasLayer = main1.get_node("HUD")

	var expected_costs: Array[int] = [100, 135, 180, 245, 330]
	for owned_count in range(1, 6):
		GameState.mission.economy["refineries_owned"] = owned_count
		var c: int = econ1.get_next_refinery_cost()
		assert(c == expected_costs[owned_count - 1], "Refinery #%d expected %d, got %d" % [owned_count, expected_costs[owned_count - 1], c])

	# 2) Rapid Cycling raises tower attack-speed multiplier on debug overlay
	GameState.reset_mission()
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.0))
	assert(not econ1.buy_research("rapid_cycling"), "Cannot buy research with 0 R")
	GameState.mission.economy["money"] = 9999
	assert(not econ1.buy_research("rapid_cycling"), "Money must NEVER buy research")
	GameState.mission.economy["money"] = 0
	GameState.add_research(50)
	assert(main1.get_node("Map").build_tower_on_pad(0, "blaster") == null, "Research must NEVER buy towers")
	assert(econ1.buy_research("rapid_cycling"))
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.05))
	hud1._refresh_debug_overlay()
	assert(hud1.debug_label.text.contains("1.05x"), "Debug overlay must show 1.05x attack-speed multiplier")
	main1.queue_free()

	# 3) Compare no-refinery vs refinery-first through Wave 5 + Sanity Check Waves 1-6
	var no_ref_result: Dictionary = _simulate_waves_1_to_6(false)
	var ref_first_result: Dictionary = _simulate_waves_1_to_6(true)
	assert(no_ref_result["w5_money"] != ref_first_result["w5_money"], "No-refinery and refinery-first must differ at Wave 5")
	assert(no_ref_result["w1_2_leaks"] == 0, "Waves 1-2 must not leak with good build")
	assert(no_ref_result["w6_leaks"] <= 3, "Wave 6 sanity check leaks should be 0-3, got %d" % no_ref_result["w6_leaks"])

	print("STEP4_TEST_PASS no_ref_w5=%d ref_w5=%d w6_leaks=%d" % [
		no_ref_result["w5_money"],
		ref_first_result["w5_money"],
		no_ref_result["w6_leaks"],
	])
	get_tree().quit(0)


func _simulate_waves_1_to_6(buy_early_refinery: bool) -> Dictionary:
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var econ: EconomyManager = inst.get_node("EconomyManager")

	var dt: float = 0.05
	var w5_money: int = 0
	var w1_2_leaks: int = 0

	# Build opening Blaster on P5 (380, 157) covering upper + middle lanes
	var blaster1: TowerUnit = map.build_tower_on_pad(4, "blaster")
	assert(blaster1 != null)
	if buy_early_refinery:
		econ.start_build_refinery()
	else:
		# No-refinery spends on Mortar on P11 (430, 322)
		map.build_tower_on_pad(10, "mortar")

	_advance_sim(map, wm, econ, 8.0, dt)

	for w in range(1, 7):
		if w == 5:
			w5_money = GameState.mission.economy["money"]

		# Reasonable mid-run build decisions in BUILD phase
		if w == 3 and map.pad_occupancy[10] == null and GameState.mission.economy["money"] >= 110:
			map.build_tower_on_pad(10, "mortar")
			_advance_sim(map, wm, econ, 7.5, dt)
		if w >= 4 and map.pad_occupancy[5] == null and GameState.mission.economy["money"] >= 75:
			map.build_tower_on_pad(5, "blaster")
			_advance_sim(map, wm, econ, 4.5, dt)
		if w >= 5 and blaster1 != null and blaster1.can_start_upgrade("damage"):
			blaster1.start_upgrade("damage")
			_advance_sim(map, wm, econ, 3.5, dt)
		if w == 6 and blaster1 != null and blaster1.can_start_upgrade("fire_rate"):
			blaster1.start_upgrade("fire_rate")
			_advance_sim(map, wm, econ, 3.5, dt)
		if econ.can_buy_research("rapid_cycling"):
			econ.buy_research("rapid_cycling")

		wm.start_wave()
		var ticks: int = 0
		while wm.state != WaveManager.State.BUILD and not GameState.mission.is_over and ticks < 3000:
			ticks += 1
			_advance_sim(map, wm, econ, dt, dt)
		if w <= 2:
			w1_2_leaks = Balance.PLAYER_STARTING_LIVES - GameState.mission.lives

	var w6_leaks: int = Balance.PLAYER_STARTING_LIVES - GameState.mission.lives
	inst.queue_free()
	return {
		"w5_money": w5_money,
		"w1_2_leaks": w1_2_leaks,
		"w6_leaks": w6_leaks,
	}


func _advance_sim(map: GameMap, wm: WaveManager, econ: EconomyManager, duration: float, dt: float) -> void:
	var steps: int = int(round(duration / dt))
	for _i in range(steps):
		wm.step_wave(dt)
		econ.step_economy(dt)
		for enemy in map.get_active_enemies():
			enemy.advance_along_path(dt)
		for tower in map.get_all_towers():
			tower.advance_tower(dt)
		for proj in map.projectiles_container.get_children():
			if proj is ProjectileEffect:
				proj.advance_projectile(dt)
