extends Node

## Headless Step 6 acceptance verification:
## - Between waves (BUILD): time powers Pause/Haste cannot be activated and cooldowns/builds pause
## - Pause freezes alien movement ONLY while towers keep firing, stacks Thaw-hardened (+20% eff HP next wave, x1.38 w/ Rewind)
## - Haste speeds 7 s Mortar build in ~2.33 s during wave and adds Swift x1
## - Creator-confirmed Rewind restarts wave, keeps mid-wave towers/money/research/lost lives/surges, adds Armoured x1 (+15% HP)
## - Manipulator upgrade mid-wave disables all 3 powers ("OFFLINE"), locks Refineries, pauses Surge, then restores all

func _ready() -> void:
	GameState.reset_meta_progression()
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

	# Anti-exploit: Pause/Haste cannot be activated in BUILD phase
	assert(not tp.can_use_power("pause") and not tp.can_use_power("haste"))

	var blaster: TowerUnit = map.build_tower_on_pad(4, "blaster")
	wm.start_wave()
	_step(map, wm, econ, surge, tp, 4.1) # 4.0 s Blaster build completes in wave
	assert(blaster.is_built)
	# Wait until Crawler #1 walks into P5 Blaster range (~17s at 12.0 px/s)
	_step(map, wm, econ, surge, tp, 13.5)
	var active_e: EnemyUnit = map.get_active_enemies()[0]
	var hp_before: float = active_e.hp

	# 1) Pause freezes enemy while tower keeps firing!
	assert(tp.activate_power("pause"))
	assert(GameState.mission.mutations["thaw_stacks"] == 1)
	var pos_frozen: Vector2 = active_e.position
	_step(map, wm, econ, surge, tp, 1.0)
	assert(not is_instance_valid(active_e) or active_e.is_dead_or_leaked or (active_e.position.distance_to(pos_frozen) < 0.01 and active_e.hp < hp_before), "Frozen enemy must NOT move and tower MUST fire during Pause")

	# Thaw-hardened x3 frozen damage reduction (30% reduction -> 70% taken)
	GameState.mission.mutations["thaw_stacks"] = 3
	var dummy: EnemyUnit = map.spawn_enemy("brute", 8)
	var brute_start_hp: float = dummy.hp
	GameState.is_enemies_frozen = true
	dummy.take_damage(100.0)
	assert(is_equal_approx(dummy.hp, brute_start_hp - 70.0), "Thaw x3 must reduce frozen damage by 30%")
	dummy.queue_free()
	GameState.is_enemies_frozen = false
	GameState.mission.mutations["thaw_stacks"] = 1
	tp.pause_remaining = 0.0
	tp.cooldowns["pause"] = 0.0

	# 2) Haste finishes a 7 s Mortar in ~2.33 s during active wave and adds Swift x1
	GameState.mission.economy["money"] = 500
	var mortar: TowerUnit = map.build_tower_on_pad(10, "mortar")
	assert(mortar != null and not mortar.is_built)
	assert(tp.activate_power("haste"))
	assert(GameState.mission.mutations["swift_stacks"] == 1)
	_step(map, wm, econ, surge, tp, 2.4)
	assert(mortar.is_built, "Haste 3x must finish 7 s Mortar in ~2.33 s")
	tp.haste_remaining = 0.0
	tp.cooldowns["haste"] = 0.0

	# 3) Creator-confirmed Rewind test
	GameState.mission.surge_count = 1
	GameState.mission.lives = 18
	GameState.mission.economy["money"] = 300
	var mid_wave_blaster: TowerUnit = map.build_tower_on_pad(5, "blaster")
	_step(map, wm, econ, surge, tp, 4.1)
	assert(mid_wave_blaster.is_built)

	var money_at_rewind: int = GameState.mission.economy["money"]
	var res_at_rewind: int = GameState.meta_research
	var wave_before_rewind: int = GameState.mission.wave_number

	assert(tp.activate_power("rewind"))
	assert(not tp.can_use_power("rewind"), "Nested Rewind must be locked during replay")
	assert(GameState.mission.wave_number == wave_before_rewind)
	assert(GameState.mission.mutations["armoured_stacks"] == 1)
	assert(GameState.mission.lives == 18, "Creator rule: lost lives stay lost on Rewind")
	assert(GameState.mission.surge_count == 1, "Surge debuff survives Rewind")
	assert(map.pad_occupancy[5] == mid_wave_blaster and is_instance_valid(mid_wave_blaster), "Creator rule: mid-wave towers stay on Rewind")
	assert(GameState.mission.economy["money"] == money_at_rewind)
	assert(GameState.meta_research == res_at_rewind)

	_step(map, wm, econ, surge, tp, 0.1)
	var first_armoured: EnemyUnit = map.get_active_enemies()[0]
	assert(is_equal_approx(first_armoured.max_hp, 57.5), "Armoured x1 Wave 1 Crawler must be 50 * 1.15 = 57.5, got %.2f" % first_armoured.max_hp)
	# Kill remaining enemies quickly to finish replayed wave
	while wm.is_wave_active():
		wm.step_wave(1.0)
		for e in map.get_active_enemies():
			e.take_damage(9999.0)
	assert(tp.cooldowns["rewind"] > 60.0, "Rewind 65 s cooldown starts after replayed wave ends")

	# Verify stacked Rewind x1 + Pause x1 on next wave gives 1.15 * 1.20 = 1.38x HP!
	assert(is_equal_approx(GameState.get_enemy_hp_multiplier(), 1.38), "1 Rewind + 1 Pause must stack to 1.38x HP on subsequent waves, got %.2f" % GameState.get_enemy_hp_multiplier())

	# Verify cooldowns stay PAUSED during BUILD phase!
	var cd_in_build: float = tp.cooldowns["rewind"]
	_step(map, wm, econ, surge, tp, 30.0)
	assert(is_equal_approx(tp.cooldowns["rewind"], cd_in_build), "Cooldowns must pause between waves!")

	# 4) Manipulator upgrade mid-wave: powers OFFLINE, Refineries locked, Surge paused, then restored
	wm.start_wave()
	GameState.mission.economy["money"] = 500
	assert(tp.start_manipulator_upgrade())
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

	print("STEP6_TEST_PASS manip_lvl=%d arm=%d thaw=%d swift=%d hp_mult=%.2f" % [
		GameState.mission.manipulator_level,
		GameState.mission.mutations["armoured_stacks"],
		GameState.mission.mutations["thaw_stacks"],
		GameState.mission.mutations["swift_stacks"],
		GameState.get_enemy_hp_multiplier(),
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
