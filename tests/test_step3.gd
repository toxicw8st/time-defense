extends Node

## Headless Step 3 acceptance verification:
## - 2 towers ($180 = 90% of $200 starting $) build during Wave 1 and hold Wave 1 (20 Crawlers, 27 DPS needed)
## - Construction pauses during BUILD phase and NEVER fires while constructing/upgrading
## - 4x3 Damage Matrix verified: Normal, Piercing, Laser, Time vs Standard, Armored, Reflective
## - Range upgrades (+25% / +60% / +100% total, costs $75 / $160 / $320) verified
## - All 6 per-tower targeting modes (first/last/strongest/weakest/fastest/slowest) verified
## - Mortar 60 px min-range blind spot verified (default target = first)
## - Sell refunds floor(50% of total_spent) and frees the pad

var killed_count: int = 0


func _ready() -> void:
	GameState.reset_meta_progression()
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main1: Node = main_scene.instantiate()
	add_child(main1)

	var map1: GameMap = main1.get_node("Map")
	var wm1: WaveManager = main1.get_node("WaveManager")

	# 1) Verify 4x3 Damage Matrix exact multipliers (including Time HIGHEST-only rule)
	assert(is_equal_approx(Balance.get_damage_multiplier("Normal", ["Standard"]), 1.00))
	assert(is_equal_approx(Balance.get_damage_multiplier("Normal", ["Armored"]), 0.50))
	assert(is_equal_approx(Balance.get_damage_multiplier("Normal", ["Reflective"]), 1.10))
	assert(is_equal_approx(Balance.get_damage_multiplier("Normal", ["Armored", "Reflective"]), 0.55))
	assert(is_equal_approx(Balance.get_damage_multiplier("Piercing", ["Standard"]), 0.75))
	assert(is_equal_approx(Balance.get_damage_multiplier("Piercing", ["Armored"]), 1.50))
	assert(is_equal_approx(Balance.get_damage_multiplier("Piercing", ["Reflective"]), 1.20))
	assert(is_equal_approx(Balance.get_damage_multiplier("Piercing", ["Armored", "Reflective"]), 1.80))
	assert(is_equal_approx(Balance.get_damage_multiplier("Laser", ["Standard"]), 1.50))
	assert(is_equal_approx(Balance.get_damage_multiplier("Laser", ["Armored"]), 0.85))
	assert(is_equal_approx(Balance.get_damage_multiplier("Laser", ["Reflective"]), 0.10))
	assert(is_equal_approx(Balance.get_damage_multiplier("Laser", ["Armored", "Reflective"]), 0.085))
	assert(is_equal_approx(Balance.get_damage_multiplier("Time", ["Standard"]), 1.00))
	assert(is_equal_approx(Balance.get_damage_multiplier("Time", ["Armored"]), 1.20))
	assert(is_equal_approx(Balance.get_damage_multiplier("Time", ["Reflective"]), 1.50))
	assert(is_equal_approx(Balance.get_damage_multiplier("Time", ["Armored", "Reflective"]), 1.50), "Time vs Armored+Reflective MUST use HIGHEST only (1.50), NOT 1.80!")

	GameState.enemy_killed.connect(func(_t: String, _m: int, _r: int, _p: Vector2) -> void: killed_count += 1)
	var laser1: TowerUnit = map1.build_tower_on_pad(4, "laser") # P5 ($100)
	var blaster1: TowerUnit = map1.build_tower_on_pad(5, "blaster") # P6 ($90)
	assert(laser1 != null and blaster1 != null)
	assert(laser1.target_mode == "first" and blaster1.target_mode == "first")
	assert(not blaster1.can_fire(), "Tower under construction must NEVER fire")

	# Verify Range upgrade costs ($75 / $160 / $320) and total range progression (+25% / +60% / +100%)
	assert(Balance.get_tower_upgrade_cost("range", 0) == 75)
	assert(Balance.get_tower_upgrade_cost("range", 1) == 160)
	assert(Balance.get_tower_upgrade_cost("range", 2) == 320)
	var base_laser_range: float = Balance.TOWERS["laser"]["range"]
	assert(is_equal_approx(laser1.get_effective_range(), base_laser_range))
	laser1.levels["range"] = 1
	assert(is_equal_approx(laser1.get_effective_range(), base_laser_range * 1.25))
	laser1.levels["range"] = 2
	assert(is_equal_approx(laser1.get_effective_range(), base_laser_range * 1.60))
	laser1.levels["range"] = 3
	assert(is_equal_approx(laser1.get_effective_range(), base_laser_range * 2.00))
	laser1.levels["range"] = 0

	# Advance 5.0 s in BUILD: construction must stay paused!
	_step_sim(map1, wm1, 5.0, 0.05)
	assert(blaster1.is_constructing() and is_equal_approx(blaster1.current_job.remaining_time, 4.0), "Construction must pause between waves")

	# Start Wave 1: towers build during first 4-5 s and hold Wave 1 (20 Crawlers) with 0 leaks
	assert(wm1.start_wave())
	_step_sim(map1, wm1, 3.5, 0.05)
	assert(blaster1.is_constructing() and not blaster1.can_fire(), "Must not fire until 4.0 s build completes")
	var ticks: int = 0
	while wm1.state != WaveManager.State.BUILD and ticks < 5000:
		ticks += 1
		_step_sim(map1, wm1, 0.05, 0.05)
	assert(blaster1.is_built and laser1.is_built)
	assert(GameState.mission.lives == 20, "2 starting towers must hold Wave 1 with 0 leaks, lives=%d" % GameState.mission.lives)
	assert(killed_count == 20, "Expected 20 Crawler kills on Wave 1, got %d" % killed_count)

	# 2) Verify Sell refunds exact floor(50% of total_spent) + upgrade cannot fire while upgrading
	assert(blaster1.get_sell_refund() == 45, "floor($90 * 0.5) must be $45")
	assert(blaster1.start_upgrade("damage")) # +$60 -> $150 total
	assert(not blaster1.can_fire(), "Upgrading tower must NOT fire")
	assert(blaster1.get_sell_refund() == 75, "floor($150 * 0.5) must be $75")
	var money_before_sell: int = GameState.mission.economy["money"]
	var refund: int = map1.sell_tower(blaster1)
	assert(refund == 75 and GameState.mission.economy["money"] == money_before_sell + 75)
	assert(map1.pad_occupancy[5] == null, "Selling must free the pad")

	main1.queue_free()

	# 3) Verify Mortar 60 px min-range blind spot, default target First, and all 6 targeting modes
	GameState.reset_mission()
	var main2: Node = main_scene.instantiate()
	add_child(main2)
	var map2: GameMap = main2.get_node("Map")
	var close_mortar: TowerUnit = map2.build_tower_on_pad(0, "mortar")
	assert(close_mortar.target_mode == "first", "All towers including Mortar must default to First target mode")
	GameState.is_wave_active = true
	_step_sim(map2, main2.get_node("WaveManager"), 7.5, 0.1)
	var close_enemy: EnemyUnit = map2.spawn_enemy("crawler", 1)
	close_enemy.distance_along_path = 110.0
	close_enemy._sync_transform_to_path()
	assert(close_mortar._pick_target() == null, "Mortar must NOT target enemies inside 60 px min range")
	close_enemy.queue_free()

	var e_first: EnemyUnit = map2.spawn_enemy("crawler", 1)
	e_first.position = close_mortar.position + Vector2(100.0, 0.0)
	e_first.distance_along_path = 500.0
	e_first.hp = 50.0
	var e_strong: EnemyUnit = map2.spawn_enemy("brute", 5)
	e_strong.position = close_mortar.position + Vector2(110.0, 0.0)
	e_strong.distance_along_path = 400.0
	e_strong.hp = 600.0
	var e_weak_fast: EnemyUnit = map2.spawn_enemy("rusher", 3)
	e_weak_fast.position = close_mortar.position + Vector2(120.0, 0.0)
	e_weak_fast.distance_along_path = 300.0
	e_weak_fast.hp = 30.0

	close_mortar.set_target_mode("first")
	assert(close_mortar._pick_target() == e_first, "First mode must pick enemy farthest along path")
	close_mortar.set_target_mode("last")
	assert(close_mortar._pick_target() == e_weak_fast, "Last mode must pick enemy least far along path")
	close_mortar.set_target_mode("strongest")
	assert(close_mortar._pick_target() == e_strong, "Strongest mode must pick highest HP enemy")
	close_mortar.set_target_mode("weakest")
	assert(close_mortar._pick_target() == e_weak_fast, "Weakest mode must pick lowest HP enemy")
	close_mortar.set_target_mode("fastest")
	assert(close_mortar._pick_target() == e_weak_fast, "Fastest mode must pick fastest moving enemy")
	close_mortar.set_target_mode("slowest")
	assert(close_mortar._pick_target() == e_strong, "Slowest mode must pick slowest moving enemy")

	var modes_seen: Array[String] = []
	close_mortar.set_target_mode("first")
	for _i in range(6):
		modes_seen.append(close_mortar.cycle_target_mode())
	assert(modes_seen == ["last", "strongest", "weakest", "fastest", "slowest", "first"])

	GameState.is_wave_active = false
	main2.queue_free()

	print("STEP3_TEST_PASS w1_kills=%d damage_matrix_4x3=ok range_x2=ok target_modes=6" % killed_count)
	get_tree().quit(0)


func _step_sim(map: GameMap, wm: WaveManager, duration: float, dt: float) -> void:
	var steps: int = int(round(duration / dt))
	for _i in range(steps):
		wm.step_wave(dt)
		for enemy in map.get_active_enemies():
			enemy.advance_along_path(dt)
		for tower in map.get_all_towers():
			tower.advance_tower(dt)
		for proj in map.projectiles_container.get_children():
			if proj is ProjectileEffect:
				proj.advance_projectile(dt)
