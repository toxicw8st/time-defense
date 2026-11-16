extends Node

## Headless Step 7 acceptance verification:
## - Test mission (167 damage/shot) is won with exactly 3 fired charges
## - Haste active during a charge does NOT change its 30.0 s completion time (timed strictly!)
## - Charge started in BUILD phase completes and wins mid-wave the moment the 3rd hit lands
## - Base lock: Manipulator upgrade blocked while charging; charging blocked while Manipulator upgrading
## - Restart after loss resets wave 1, 200 money, 0 research, 0 mutations, 0 surges, manipulator Lv1

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

	GameState.mission.economy["money"] = 1000

	# 1) Start Charge #1 during BUILD phase while Haste is active: must STILL take full 30.0 s!
	assert(ba.start_charge())
	assert(not ba.can_start_charge(), "Cannot start 2nd charge while charging")
	assert(not tp.can_upgrade_manipulator(), "Manipulator upgrade must be blocked while Hive Destroyer is charging")
	assert(tp.activate_power("haste"))
	assert(GameState.is_haste_active)

	var elapsed: float = 0.0
	var dt: float = 0.05
	# Step 29.9 s with Haste active for the first 6 s -> must NOT have fired yet!
	while elapsed < 29.9:
		elapsed += dt
		_step(map, wm, econ, surge, tp, ba, dt)
	assert(ba.is_charging and GameState.mission.enemy_base_hp == 500, "Haste must NEVER speed up base attack charge! elapsed=%.2f rem=%.2f" % [elapsed, ba.charge_remaining])

	# Step final 0.15 s -> fires at exact 30.0 s
	_step(map, wm, econ, surge, tp, ba, 0.15)
	assert(not ba.is_charging)
	assert(GameState.mission.enemy_base_hp == 333, "1st hit must deal 167 dmg -> 333 HP")
	assert(GameState.mission.stats["charges_fired"] == 1)

	# 2) Verify Manipulator upgrade blocks starting Base Attack charge
	assert(tp.start_manipulator_upgrade())
	assert(not ba.can_start_charge(), "Hive Destroyer charge must be blocked while Manipulator is upgrading")
	_step(map, wm, econ, surge, tp, ba, 10.1)
	assert(not GameState.is_base_locked())

	# 3) Fire Charge #2
	assert(ba.start_charge())
	_step(map, wm, econ, surge, tp, ba, 30.05)
	assert(GameState.mission.enemy_base_hp == 166)
	assert(GameState.mission.stats["charges_fired"] == 2)

	# 4) Start Charge #3 in BUILD, then start Wave 1 and verify Win triggers MID-WAVE on 3rd hit!
	assert(ba.start_charge())
	_step(map, wm, econ, surge, tp, ba, 25.0)
	wm.start_wave()
	assert(wm.is_wave_active())
	_step(map, wm, econ, surge, tp, ba, 5.1)
	assert(GameState.mission.enemy_base_hp == 0)
	assert(GameState.mission.stats["charges_fired"] == 3)
	assert(GameState.mission.is_over and GameState.mission.outcome == "won")
	assert(wm.is_wave_active(), "Win must trigger mid-wave immediately on 3rd hit")
	assert(hud.end_overlay.visible and hud.end_title_label.text.contains("VICTORY"))

	# 5) Simulate loss with dirty state, press Restart, verify full MissionState reset
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

	print("STEP7_TEST_PASS charges_fired=3 haste_invariant=true restart_clean=true")
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
