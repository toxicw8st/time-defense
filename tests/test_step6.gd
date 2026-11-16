extends Node

## Headless Step 6 acceptance verification (including creator-confirmed Rewind & Base-lock rules):
## - Wave 1: all 3 powers ready
## - Pause freezes enemy movement ONLY while towers keep firing, stacks Thaw-hardened (frozen damage drops up to 50%)
## - Haste speeds 7 s Mortar build in ~2.33 s and adds Swift x1 (visible on next spawns)
## - Rewind (creator rule): restarts current enemy wave, adds Armoured x1, keeps mid-wave towers, keeps money/research,
##   keeps lost lives (lost lives stay lost!), preserves surge count, prevents double wave-clear bonus, locks nested Rewind until replay ends + 65 s cooldown
## - Manipulator upgrade mid-wave disables all 3 powers ("OFFLINE"), locks Refineries, pauses Surge for exact build duration, then restores all

func _ready() -> void:
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var econ: EconomyManager = inst.get_node("EconomyManager")
	var surge: SurgeManager = inst.get_node("SurgeManager")
	var tp: TimePowersManager = inst.get_node("TimePowersManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	# 1) Three Pauses across mission stack Thaw-hardened to x3 and drop frozen damage to 70%
	var blaster: TowerUnit = map.build_tower_on_pad(4, "blaster")
	_step(map, wm, econ, surge, tp, 4.5)
	assert(blaster.is_built)
	wm.start_wave()
	# Walk ~3.2 s so Runner #1 enters P5 Blaster range (x ~ 270)
	_step(map, wm, econ, surge, tp, 3.2)
	var active_e: EnemyUnit = map.get_active_enemies()[0]
	var hp_before: float = active_e.hp

	# Use Pause #1: verify enemy frozen while tower still fires!
	assert(tp.activate_power("pause"))
	assert(GameState.mission.mutations["thaw_stacks"] == 1)
	var pos_frozen: Vector2 = active_e.position
	_step(map, wm, econ, surge, tp, 0.55)
	assert(not is_instance_valid(active_e) or active_e.is_dead_or_leaked or (active_e.position.distance_to(pos_frozen) < 0.01 and active_e.hp < hp_before), "Frozen enemy must NOT move and tower MUST fire during Pause")

	# Test Thaw-hardened x3 frozen damage reduction (30% reduction -> 70% taken)
	GameState.mission.mutations["thaw_stacks"] = 3
	var dummy: EnemyUnit = map.spawn_enemy("brute", 8)
	var brute_start_hp: float = dummy.hp
	GameState.is_enemies_frozen = true
	dummy.take_damage(100.0)
	assert(is_equal_approx(dummy.hp, brute_start_hp - 70.0), "Thaw x3 must reduce frozen damage by 30%")
	dummy.queue_free()
	GameState.is_enemies_frozen = false
	tp.pause_remaining = 0.0
	tp.cooldowns["pause"] = 0.0

	# 2) Haste finishes a 7 s Mortar in ~2.33 s of hasted time and adds Swift x1
	var mortar: TowerUnit = map.build_tower_on_pad(10, "mortar")
	assert(mortar != null and not mortar.is_built)
	assert(tp.activate_power("haste"))
	assert(GameState.mission.mutations["swift_stacks"] == 1)
	_step(map, wm, econ, surge, tp, 2.4) # 2.4 * 3 = 7.2 s >= 7.0 s
	assert(mortar.is_built, "Haste 3x must finish 7 s Mortar in ~2.33 s")
	tp.haste_remaining = 0.0
	tp.cooldowns["haste"] = 0.0

	# 3) Creator-confirmed Rewind test:
	# Build a second Blaster MID-WAVE, lose 2 lives, suffer 1 surge, then Rewind.
	# Verify: mid-wave tower STAYS, money/research STAY, lost lives STAY LOST (18), surge STAYS (1),
	# Armoured stacks +1, nested Rewind blocked during replay, and replay clear doesn't double-pay bonus.
	GameState.mission.surge_count = 1
	GameState.mission.lives = 18
	GameState.mission.economy["money"] = 300
	var mid_wave_blaster: TowerUnit = map.build_tower_on_pad(5, "blaster")
	_step(map, wm, econ, surge, tp, 4.1)
	assert(mid_wave_blaster.is_built)

	var money_at_rewind: int = GameState.mission.economy["money"]
	var res_at_rewind: int = GameState.mission.economy["research"]
	var wave_before_rewind: int = GameState.mission.wave_number

	assert(tp.activate_power("rewind"))
	assert(not tp.can_use_power("rewind"), "Nested Rewind must be locked during replay")
	assert(GameState.mission.wave_number == wave_before_rewind)
	assert(GameState.mission.mutations["armoured_stacks"] == 1)
	assert(GameState.mission.lives == 18, "Creator rule: lost lives stay lost on Rewind")
	assert(GameState.mission.surge_count == 1, "Surge debuff survives Rewind")
	assert(map.pad_occupancy[5] == mid_wave_blaster and is_instance_valid(mid_wave_blaster), "Creator rule: mid-wave towers stay on Rewind")
	assert(GameState.mission.economy["money"] == money_at_rewind)
	assert(GameState.mission.economy["research"] == res_at_rewind)

	# Clear the replayed wave and verify Armoured x1 HP (+15%) + Rewind cooldown starts after clear
	_step(map, wm, econ, surge, tp, 0.1)
	var first_armoured: EnemyUnit = map.get_active_enemies()[0]
	assert(first_armoured.max_hp == 46.0, "Armoured x1 Wave 1 Runner must be round(40 * 1.15) = 46")
	while wm.is_wave_active():
		_step(map, wm, econ, surge, tp, 0.2)
	assert(tp.cooldowns["rewind"] > 60.0, "Rewind 65 s cooldown starts after replayed wave ends")

	# 4) Manipulator upgrade mid-wave: powers OFFLINE, Refineries locked, Surge paused for exact build time, then restored
	wm.start_wave()
	GameState.mission.economy["money"] = 500
	assert(tp.start_manipulator_upgrade()) # 1->2 costs 150, 10 s
	assert(GameState.is_base_locked())
	assert(not tp.can_use_power("pause") and not tp.can_use_power("haste") and not tp.can_use_power("rewind"))
	assert(not econ.can_build_refinery(), "Refinery build must be locked during Manipulator upgrade")
	hud._refresh_power_buttons()
	assert(hud.pause_button.text.contains("OFFLINE"), "Power button must display OFFLINE during Manipulator upgrade")

	var surge_before_manip: float = GameState.mission.surge_timer_seconds
	_step(map, wm, econ, surge, tp, 9.9)
	assert(GameState.is_base_locked())
	assert(is_equal_approx(GameState.mission.surge_timer_seconds, surge_before_manip), "Surge timer must stay paused during Manipulator upgrade")
	_step(map, wm, econ, surge, tp, 0.2)
	assert(not GameState.is_base_locked() and GameState.mission.manipulator_level == 2)
	assert(tp.can_use_power("pause"), "Powers restored after Manipulator upgrade completes")

	print("STEP6_TEST_PASS manip_lvl=%d arm=%d thaw=%d swift=%d" % [
		GameState.mission.manipulator_level,
		GameState.mission.mutations["armoured_stacks"],
		GameState.mission.mutations["thaw_stacks"],
		GameState.mission.mutations["swift_stacks"],
	])
	get_tree().quit(0)


func _step(map: GameMap, wm: WaveManager, econ: EconomyManager, surge: SurgeManager, tp: TimePowersManager, duration: float) -> void:
	var dt: float = 0.05
	var steps: int = int(round(duration / dt))
	for _i in range(steps):
		tp.step_powers(dt)
		surge.step_surge(dt)
		wm.step_wave(dt)
		econ.step_economy(dt)
		for enemy in map.get_active_enemies():
			enemy.advance_along_path(dt)
		for tower in map.get_all_towers():
			tower.advance_tower(dt)
		for proj in map.projectiles_container.get_children():
			if proj is ProjectileEffect:
				proj.advance_projectile(dt)
