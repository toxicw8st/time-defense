extends Node

## Headless Step 6 acceptance verification:
## - Between waves (W1 BUILD): Pause/Haste/Rewind all blocked (no Wave 1 pre-farming!)
## - Pause freezes alien movement ONLY for 8s (10s at Lv3) while towers keep firing, stacks Thaw (+5% HP next new wave)
## - Haste boosts ALL tower attack speed +50% AND construction speed +50% (7s Mortar in ~4.67s) for 30s, adds Swift (+5% speed)
## - BUILD-phase Rewind: allowed once after clearing a wave, replayed wave has NO new mutation (50.0 HP), +5% Armoured applies to next new wave (52.5 HP)
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

	# Anti-exploit: Pause/Haste/Rewind blocked in initial W1 BUILD phase
	assert(not tp.can_use_power("pause") and not tp.can_use_power("haste") and not tp.can_use_power("rewind"))

	var blaster: TowerUnit = map.build_tower_on_pad(4, "blaster")
	wm.start_wave()
	_step(map, wm, econ, surge, tp, 4.1) # 4.0 s Blaster build completes in wave
	assert(blaster.is_built)
	# Wait until Crawler #1 walks into P5 Blaster range (~17s at 12.0 px/s)
	_step(map, wm, econ, surge, tp, 13.5)
	var active_e: EnemyUnit = map.get_active_enemies()[0]
	var hp_before: float = active_e.hp

	# 1) Pause freezes enemy movement for 8.0 s while tower keeps firing!
	assert(tp.activate_power("pause"))
	assert(is_equal_approx(tp.pause_remaining, 8.0), "Pause base duration must be 8.0 s (+2s longer)")
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
	GameState.mission.mutations["thaw_stacks"] = 0
	tp.pause_remaining = 0.0
	tp.cooldowns["pause"] = 0.0

	# 2) Haste: +50% tower attack speed + +50% construction speed (7s Mortar -> ~4.67s) for 30s
	GameState.mission.economy["money"] = 500
	var mortar: TowerUnit = map.build_tower_on_pad(10, "mortar")
	assert(mortar != null and not mortar.is_built)
	assert(tp.activate_power("haste"))
	assert(is_equal_approx(tp.haste_remaining, 30.0), "Haste duration must be 30.0 s")
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.50), "Haste must give +50% tower attack speed")
	assert(GameState.mission.mutations["swift_stacks"] == 1)
	_step(map, wm, econ, surge, tp, 2.4)
	assert(not mortar.is_built, "At +50% build speed (1.5x), 7 s Mortar must still be building at 2.4 s")
	_step(map, wm, econ, surge, tp, 2.4)
	assert(mortar.is_built, "At +50% build speed (1.5x), 7 s Mortar must finish by 4.8 s (~4.67 s)")
	tp.haste_remaining = 0.0
	tp.cooldowns["haste"] = 0.0

	# Finish Wave 1 so we enter post-W1 BUILD phase
	while wm.is_wave_active():
		wm.step_wave(1.0)
		for e in map.get_active_enemies():
			e.take_damage(9999.0)
	assert(wm.state == WaveManager.State.BUILD and GameState.mission.wave_number == 2)

	# 3) BUILD-phase Rewind: allowed once after clearing Wave 1; replays Wave 1 with NO new mutation (50.0 HP)
	GameState.mission.surge_count = 1
	GameState.mission.lives = 18
	GameState.mission.economy["money"] = 300
	var mid_wave_blaster: TowerUnit = map.build_tower_on_pad(5, "blaster")
	var money_at_rewind: int = GameState.mission.economy["money"]
	var res_at_rewind: int = GameState.meta_research

	assert(tp.can_use_power("rewind"), "Rewind must be available in BUILD phase after clearing a wave")
	assert(tp.activate_power("rewind"))
	assert(wm.is_wave_active() and GameState.mission.wave_number == 1, "Rewind must replay the cleared previous wave (Wave 1)")
	assert(not tp.can_use_power("rewind"), "Rewind must be locked during replay")
	assert(GameState.mission.mutations["armoured_stacks"] == 1)
	assert(GameState.mission.lives == 18, "Lost lives stay lost on Rewind")
	assert(GameState.mission.surge_count == 1, "Surge debuff survives Rewind")
	assert(map.pad_occupancy[5] == mid_wave_blaster and is_instance_valid(mid_wave_blaster))
	assert(GameState.mission.economy["money"] == money_at_rewind)
	assert(GameState.meta_research == res_at_rewind)

	_step(map, wm, econ, surge, tp, 0.1)
	var replayed_crawler: EnemyUnit = map.get_active_enemies()[0]
	assert(is_equal_approx(replayed_crawler.max_hp, 50.0), "Replayed Wave 1 Crawler must have NO new mutation (50.0 HP), got %.2f" % replayed_crawler.max_hp)
	# Kill remaining enemies quickly to finish replayed Wave 1
	while wm.is_wave_active():
		wm.step_wave(1.0)
		for e in map.get_active_enemies():
			e.take_damage(9999.0)
	assert(wm.state == WaveManager.State.BUILD and GameState.mission.wave_number == 2)
	assert(not tp.can_use_power("rewind"), "Second Rewind in the same build phase MUST be blocked")

	# Verify +5% Armoured mutation now applies to the NEXT NEW wave (Wave 2)!
	assert(is_equal_approx(GameState.get_enemy_hp_multiplier(), 1.05), "Armoured x1 must be +5%% (1.05x) on Wave 2, got %.4f" % GameState.get_enemy_hp_multiplier())
	# Verify Pause +5% + Rewind +5% stack multiplicatively to 1.05 * 1.05 = 1.1025 (~1.10x)!
	wm.start_wave()
	tp.cooldowns["pause"] = 0.0
	assert(tp.activate_power("pause"))
	while wm.is_wave_active():
		wm.step_wave(1.0)
		for e in map.get_active_enemies():
			e.take_damage(9999.0)
	assert(is_equal_approx(GameState.get_enemy_hp_multiplier(), 1.1025), "1 Rewind (+5%%) + 1 Pause (+5%%) must stack to 1.1025x HP, got %.4f" % GameState.get_enemy_hp_multiplier())
	tp.pause_remaining = 0.0
	tp.cooldowns["pause"] = 0.0

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
