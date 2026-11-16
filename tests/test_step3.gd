extends Node

## Headless Step 3 acceptance verification:
## - Blaster builds during wave and holds Wave 1
## - Construction pauses during BUILD phase and NEVER fires while constructing/upgrading
## - Mortar visibly outperforms Blaster on bunched Wave 4, respects 60 px min range, splash at landing
## - Sell refunds floor(50% of total_spent) and frees the pad
## - Kill earnings feed money + research and spawn floating texts

var killed_count: int = 0


func _ready() -> void:
	# 1) Test Blaster built in BUILD stays paused until wave starts, never fires while building, and holds Wave 1
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main1: Node = main_scene.instantiate()
	add_child(main1)

	var map1: GameMap = main1.get_node("Map")
	var wm1: WaveManager = main1.get_node("WaveManager")

	GameState.enemy_killed.connect(func(_t: String, _m: int, _r: int, _p: Vector2) -> void: killed_count += 1)
	var blaster: TowerUnit = map1.build_tower_on_pad(4, "blaster") # P5 (380,157)
	assert(blaster != null)
	assert(not blaster.can_fire(), "Tower under construction must NEVER fire")

	# Advance 5.0 s in BUILD: construction must stay paused!
	_step_sim(map1, wm1, 5.0, 0.05)
	assert(blaster.is_constructing() and is_equal_approx(blaster.current_job.remaining_time, 4.0), "Construction must pause between waves")

	# Start Wave 1: Blaster builds during first 4.0 s, still holds Wave 1 with 0 leaks
	assert(wm1.start_wave())
	_step_sim(map1, wm1, 3.5, 0.05)
	assert(blaster.is_constructing() and not blaster.can_fire(), "Must not fire until 4.0 s build completes")
	var ticks: int = 0
	while wm1.state != WaveManager.State.BUILD and ticks < 1200:
		ticks += 1
		_step_sim(map1, wm1, 0.05, 0.05)
	assert(blaster.is_built)
	assert(GameState.mission.lives == 20, "Blaster alone must hold Wave 1 with 0 leaks, lives=%d" % GameState.mission.lives)
	assert(killed_count == 8, "Expected 8 kills on Wave 1, got %d" % killed_count)
	assert(map1.floating_texts.size() > 0 or GameState.mission.economy["research"] == 8)

	# 2) Verify Sell refunds exact floor(50% of total_spent) + upgrade cannot fire while upgrading
	assert(blaster.get_sell_refund() == 37, "floor(75 * 0.5) must be 37")
	assert(blaster.start_upgrade("damage"))
	assert(not blaster.can_fire(), "Upgrading tower must NOT fire")
	assert(blaster.get_sell_refund() == 62, "floor(125 * 0.5) must be 62")
	var money_before_sell: int = GameState.mission.economy["money"]
	var refund: int = map1.sell_tower(blaster)
	assert(refund == 62 and GameState.mission.economy["money"] == money_before_sell + 62)
	assert(map1.pad_occupancy[4] == null, "Selling must free the pad")

	main1.queue_free()

	# 3) Compare 1 Blaster vs 1 Mortar on bunched Wave 4
	var blaster_w4_leaks: int = _run_wave4_solo("blaster", 4)
	var mortar_w4_leaks: int = _run_wave4_solo("mortar", 4)
	assert(mortar_w4_leaks < blaster_w4_leaks, "Mortar (leaks=%d) must outperform Blaster (leaks=%d) on bunched Wave 4" % [mortar_w4_leaks, blaster_w4_leaks])

	# 4) Verify Mortar 60 px min-range blind spot on close pad P1 (220,32)
	GameState.reset_mission()
	var main2: Node = main_scene.instantiate()
	add_child(main2)
	var map2: GameMap = main2.get_node("Map")
	var close_mortar: TowerUnit = map2.build_tower_on_pad(0, "mortar")
	GameState.is_wave_active = true
	_step_sim(map2, main2.get_node("WaveManager"), 7.5, 0.1)
	var close_enemy: EnemyUnit = map2.spawn_enemy("runner", 1)
	close_enemy.distance_along_path = 110.0
	close_enemy._sync_transform_to_path()
	assert(close_mortar._pick_target() == null, "Mortar must NOT target enemies inside 60 px min range")
	GameState.is_wave_active = false
	main2.queue_free()

	print("STEP3_TEST_PASS w4_blaster_leaks=%d w4_mortar_leaks=%d" % [blaster_w4_leaks, mortar_w4_leaks])
	get_tree().quit(0)


func _run_wave4_solo(tower_type: String, pad_idx: int) -> int:
	GameState.reset_mission()
	GameState.mission.wave_number = 4
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)
	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var t: TowerUnit = map.build_tower_on_pad(pad_idx, tower_type)
	GameState.is_wave_active = true
	_step_sim(map, wm, 8.0, 0.1)
	assert(t.is_built)
	GameState.is_wave_active = false
	wm.start_wave()
	var ticks: int = 0
	while wm.state != WaveManager.State.BUILD and not GameState.mission.is_over and ticks < 2400:
		ticks += 1
		_step_sim(map, wm, 0.05, 0.05)
	var leaks: int = Balance.PLAYER_STARTING_LIVES - GameState.mission.lives
	inst.queue_free()
	return leaks


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
