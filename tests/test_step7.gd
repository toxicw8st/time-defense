extends Node

## Headless Step 7 acceptance verification:
## - Charge armed in BUILD does NOT tick in BUILD (anti-exploit), advances during active waves
## - Charging Hive Destroyer PAUSES all time abilities (Rewind, Pause, Haste locked & cooldowns paused) AND pauses Surge
## - Haste cannot speed up the 30.0 s Hive Destroyer charge
## - 3 charges win mid-wave; Restart resets everything cleanly

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
	var ba: BaseAttackManager = inst.get_node("BaseAttackManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	GameState.mission.economy["money"] = 2000
	# Build strong defense (3 Blasters + 2 Mortars) so Wave 6/7/9/10 stay alive during 30 s charge timing checks
	var b1: TowerUnit = map.build_tower_on_pad(4, "blaster")
	var b2: TowerUnit = map.build_tower_on_pad(5, "blaster")
	map.build_tower_on_pad(3, "blaster")
	map.build_tower_on_pad(10, "mortar")
	map.build_tower_on_pad(9, "mortar")

	# 1) Arm Charge #1 in BUILD: must stay at 30.0 s in BUILD, then advance during wave while pausing time abilities & Surge!
	assert(ba.start_charge())
	assert(not ba.can_start_charge(), "Cannot start 2nd charge while charging")
	assert(not tp.can_upgrade_manipulator(), "Manipulator upgrade blocked while Hive Destroyer is charging")
	_step(map, wm, econ, surge, tp, ba, 20.0)
	assert(is_equal_approx(ba.charge_remaining, 30.0), "Hive charge must NOT advance in BUILD phase")

	# Start Wave 6 (26 Runners, lasts >35s!) + test active Haste/cooldown pause during Hive charging!
	GameState.mission.wave_number = 6
	wm.start_wave()
	tp.cooldowns["pause"] = 20.0
	tp.haste_remaining = 4.0
	assert(not tp.can_use_power("rewind") and not tp.can_use_power("pause") and not tp.can_use_power("haste"), "All time powers MUST be paused while Hive charging")
	assert(surge.is_surge_paused(), "Surge MUST pause while Hive charging")
	hud._refresh_power_buttons()
	assert(hud.rewind_button.text.contains("PAUSED (HIVE)"))

	var surge_before_charge: float = GameState.mission.surge_timer_seconds
	_step(map, wm, econ, surge, tp, ba, 29.9)
	assert(not GameState.is_haste_active, "Haste must stay suspended while Hive charging")
	assert(is_equal_approx(tp.cooldowns["pause"], 20.0), "Power cooldowns must pause while Hive charging")
	assert(is_equal_approx(GameState.mission.surge_timer_seconds, surge_before_charge), "Surge must stay paused while Hive charging")
	assert(ba.is_charging and GameState.mission.enemy_base_hp == 500, "Must take full 30.0 s")

	_step(map, wm, econ, surge, tp, ba, 0.15)
	assert(not ba.is_charging)
	assert(GameState.mission.enemy_base_hp == 333, "1st hit must deal 167 dmg -> 333 HP")
	assert(GameState.mission.stats["charges_fired"] == 1)

	# 2) Verify Manipulator upgrade blocks starting Base Attack charge
	tp.cooldowns["pause"] = 0.0
	tp.haste_remaining = 0.0
	GameState.mission.wave_number = 7
	wm.state = WaveManager.State.BUILD
	GameState.is_wave_active = false
	wm.start_wave()
	assert(tp.start_manipulator_upgrade())
	assert(not ba.can_start_charge(), "Hive charge blocked while Manipulator upgrading")
	_step(map, wm, econ, surge, tp, ba, 10.1)
	assert(not GameState.is_base_locked())

	# Upgrade b1/b2 damage to handle Wave 9-10 easily
	b1.start_upgrade("damage")
	b2.start_upgrade("damage")
	_step(map, wm, econ, surge, tp, ba, 3.5)

	# 3) Fire Charge #2 on Wave 9
	GameState.mission.wave_number = 9
	wm.state = WaveManager.State.BUILD
	GameState.is_wave_active = false
	assert(ba.start_charge())
	wm.start_wave()
	_step(map, wm, econ, surge, tp, ba, 30.05)
	assert(GameState.mission.enemy_base_hp == 166)
	assert(GameState.mission.stats["charges_fired"] == 2)

	# 4) Fire Charge #3 on Wave 10 and verify Win triggers mid-wave!
	GameState.mission.wave_number = 10
	wm.state = WaveManager.State.BUILD
	GameState.is_wave_active = false
	assert(ba.start_charge())
	wm.start_wave()
	_step(map, wm, econ, surge, tp, ba, 30.05)
	assert(GameState.mission.enemy_base_hp == 0)
	assert(GameState.mission.stats["charges_fired"] == 3)
	assert(GameState.mission.is_over and GameState.mission.outcome == "won")
	assert(hud.end_overlay.visible and hud.end_title_label.text.contains("VICTORY"))

	# 5) Restart resets everything cleanly
	GameState.reset_mission()
	GameState.mission.wave_number = 7
	GameState.mission.mutations["armoured_stacks"] = 3
	GameState.mission.surge_count = 4
	GameState.mission.manipulator_level = 3
	GameState.mission.economy["money"] = 999
	GameState.mission.economy["research"] = 85
	GameState.lose_lives(20)
	assert(GameState.mission.is_over and GameState.mission.outcome == "lost")
	hud._on_restart_pressed()
	var m := GameState.mission
	assert(not m.is_over and m.wave_number == 1 and m.lives == 20)
	assert(m.economy["money"] == 200 and m.economy["research"] == 0 and m.economy["refineries_owned"] == 1)
	assert(m.mutations["armoured_stacks"] == 0 and m.mutations["thaw_stacks"] == 0 and m.mutations["swift_stacks"] == 0)
	assert(m.surge_count == 0 and m.manipulator_level == 1 and m.enemy_base_hp == 500)

	print("STEP7_TEST_PASS charges_fired=3 hive_pauses_abilities=true restart_clean=true")
	get_tree().quit(0)


func _step(map: GameMap, wm: WaveManager, econ: EconomyManager, surge: SurgeManager, tp: TimePowersManager, ba: BaseAttackManager, duration: float) -> void:
	var dt: float = 0.05
	var steps: int = int(round(duration / dt))
	for _i in range(steps):
		tp.step_powers(dt)
		surge.step_surge(dt)
		ba.step_base_attack(dt)
		wm.step_wave(dt)
		econ.step_economy(dt)
		for enemy in map.get_active_enemies():
			enemy.advance_along_path(dt)
		for tower in map.get_all_towers():
			tower.advance_tower(dt)
		for proj in map.projectiles_container.get_children():
			if proj is ProjectileEffect:
				proj.advance_projectile(dt)
