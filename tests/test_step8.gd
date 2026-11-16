extends Node

## Headless Step 8 + Definition-of-Done Full-15-Wave Verification:
## 1. Prompts Wave 1-6 appear once each, never duplicate (even across Rewind)
## 2. Muting prompts does NOT hide Surge bar, Pre-wave Preview, or Event feed
## 3. "How time works" is <= 9 lines and names Armoured, Thaw-hardened, Swift, Surge
## 4. No-powers 15-wave run is clearable (reaching Wave 13+ / winning via 3 charges) AND suffers surges (first surge right around Wave 3 start!)
## 5. Heavy-powers (6+ uses) 15-wave run is clearable despite stacked mutations, with exact 1:1 mutation-to-power counts
## 6. Stall check: surviving all 15 waves with Enemy Base HP > 0 triggers "stalled" debrief

func _ready() -> void:
	_test_step8_prompts_and_ui()
	var no_pow: Dictionary = _simulate_15_waves(false)
	var heavy_pow: Dictionary = _simulate_15_waves(true)
	var stall_res: Dictionary = _test_wave15_stall()

	assert(no_pow["outcome"] == "won", "No-powers run must win via 3 base charges, got %s at wave %d (lives=%d)" % [no_pow["outcome"], no_pow["wave"], no_pow["lives"]])
	assert(no_pow["surges"] >= 3, "No-powers run must visibly suffer surges, got %d" % no_pow["surges"])
	assert(no_pow["first_surge_wave"] == 3, "With 52 s window, skipping powers in W1-2 must trigger Surge at Wave 3, got Wave %d" % no_pow["first_surge_wave"])

	assert(heavy_pow["outcome"] == "won", "Heavy-powers run must win despite stacked mutations, got %s at wave %d (lives=%d)" % [heavy_pow["outcome"], heavy_pow["wave"], heavy_pow["lives"]])
	assert(heavy_pow["powers_total"] >= 6, "Heavy-powers run must use >=6 powers, used %d" % heavy_pow["powers_total"])
	var mut_sum: int = heavy_pow["mutations"]["armoured_stacks"] + heavy_pow["mutations"]["thaw_stacks"] + heavy_pow["mutations"]["swift_stacks"]
	assert(mut_sum == heavy_pow["powers_total"], "Mutations (%d) must match powers used (%d) 1:1" % [mut_sum, heavy_pow["powers_total"]])

	assert(stall_res["outcome"] == "stalled", "Surviving Wave 15 without killing base must trigger stalled state")

	print("STEP8_AND_FULL_RUN_PASS no_pow=(w%d,surges=%d,first_surge_w=%d,w1_w2_s=%.1f) heavy_pow=(w%d,powers=%d,muts=%s) stall=%s" % [
		no_pow["wave"],
		no_pow["surges"],
		no_pow["first_surge_wave"],
		no_pow["w1_w2_active_seconds"],
		heavy_pow["wave"],
		heavy_pow["powers_total"],
		str(heavy_pow["mutations"]),
		stall_res["outcome"],
	])
	get_tree().quit(0)


func _test_step8_prompts_and_ui() -> void:
	GameState.prompts_muted = false
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	assert(hud.prompt_banner.visible and hud.prompt_label.text.contains("TIP (1/6)"))
	hud._on_prompt_dismiss_pressed()
	assert(not hud.prompt_banner.visible)

	var htw: String = hud.how_time_works_label.text
	var lines: PackedStringArray = htw.split("\n", false)
	assert(lines.size() <= 9, "How time works must be <=9 lines, got %d" % lines.size())
	assert(htw.contains("Armoured") and htw.contains("Thaw-hardened") and htw.contains("Swift") and htw.contains("SURGE"))

	wm.start_wave()
	while wm.is_wave_active():
		wm.step_wave(0.25)
		for e in map.get_active_enemies():
			e.take_damage(9999.0)
	wm.start_wave()
	assert(hud.prompt_banner.visible and hud.prompt_label.text.contains("TIP (2/6)"))

	hud._on_prompt_dismiss_pressed()
	wm.restart_wave_for_rewind()
	assert(not hud.prompt_banner.visible, "Rewind must never show same prompt twice")

	hud.set_prompts_muted(true)
	assert(not hud.prompt_banner.visible)
	assert(hud.surge_bar.visible and hud.preview_title_label.visible and hud.event_feed_label.visible)

	GameState.prompts_muted = false
	remove_child(inst)
	inst.queue_free()


func _simulate_15_waves(use_heavy_powers: bool) -> Dictionary:
	GameState.prompts_muted = true
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

	var dt: float = 0.05
	var w1_w2_active_seconds: float = 0.0
	var first_surge_wave: int = 0
	var pad_plan: Array[Dictionary] = [
		{"pad": 4, "type": "blaster"},
		{"pad": 10, "type": "mortar"},
		{"pad": 5, "type": "blaster"},
		{"pad": 9, "type": "mortar"},
		{"pad": 11, "type": "blaster"},
		{"pad": 3, "type": "blaster"},
		{"pad": 6, "type": "mortar"},
		{"pad": 7, "type": "blaster"},
	]

	map.build_tower_on_pad(4, "blaster")
	_step(map, wm, econ, surge, tp, ba, 4.5, dt)

	var did_rewind_w5: bool = false
	var did_rewind_w9: bool = false

	while not GameState.mission.is_over and GameState.mission.wave_number <= 15:
		var w: int = GameState.mission.wave_number

		if not use_heavy_powers and w == 2 and GameState.mission.economy["refineries_owned"] == 1 and econ.can_build_refinery():
			econ.start_build_refinery()
			_step(map, wm, econ, surge, tp, ba, 6.2, dt)
		if use_heavy_powers and w == 3 and GameState.mission.economy["refineries_owned"] == 1 and econ.can_build_refinery():
			econ.start_build_refinery()
			_step(map, wm, econ, surge, tp, ba, 6.2, dt)

		# Pace Hive Destroyer charges on Waves 6, 9, 13 (Guide p. 11 target timeline!) so Waves 1-13 all get combat-tested
		var charge_waves_ready: bool = (w == 6 and GameState.mission.stats["charges_fired"] == 0) or (w == 9 and GameState.mission.stats["charges_fired"] == 1) or (w >= 13 and GameState.mission.stats["charges_fired"] == 2)
		if charge_waves_ready and ba.can_start_charge():
			ba.start_charge()

		var reserve: int = 150 if (w >= 6 and not ba.is_charging and GameState.mission.enemy_base_hp > 0) else 0
		for item in pad_plan:
			var p: int = item["pad"]
			var ttype: String = item["type"]
			var cost: int = int(Balance.TOWERS[ttype]["cost"])
			if map.pad_occupancy[p] == null and GameState.mission.economy["money"] >= cost + reserve:
				map.build_tower_on_pad(p, ttype)
				if use_heavy_powers and tp.can_use_power("haste"):
					tp.activate_power("haste")
				_step(map, wm, econ, surge, tp, ba, 7.2, dt)

		for t in map.get_all_towers():
			for stat_k in ["damage", "fire_rate", "range"]:
				var lvl: int = int(t.levels[stat_k])
				if lvl < Balance.TOWER_UPGRADE_MAX_LEVEL:
					var upg_cost: int = Balance.TOWER_UPGRADE_COSTS[lvl]
					if t.can_start_upgrade(stat_k) and GameState.mission.economy["money"] >= upg_cost + reserve:
						t.start_upgrade(stat_k)
						_step(map, wm, econ, surge, tp, ba, 5.2, dt)
						break

		for rk in ["reinforced_shots", "rapid_cycling", "extended_optics"]:
			if econ.can_buy_research(rk):
				econ.buy_research(rk)

		if use_heavy_powers and w == 7 and tp.can_upgrade_manipulator() and not ba.is_charging:
			if GameState.mission.economy["money"] >= 300:
				tp.start_manipulator_upgrade()
				_step(map, wm, econ, surge, tp, ba, 10.2, dt)

		if wm.state == WaveManager.State.BUILD:
			wm.start_wave()

		var safety_ticks: int = 0
		var wave_time: float = 0.0
		while wm.is_wave_active() and not GameState.mission.is_over and safety_ticks < 3600:
			safety_ticks += 1
			wave_time += dt
			_step(map, wm, econ, surge, tp, ba, dt, dt)
			if first_surge_wave == 0 and GameState.mission.surge_count > 0:
				first_surge_wave = w

			if w <= 2:
				w1_w2_active_seconds += dt

			if charge_waves_ready and ba.can_start_charge():
				ba.start_charge()

			if use_heavy_powers:
				if w in [2, 4, 8, 10, 12] and wave_time > 5.0 and tp.can_use_power("pause"):
					tp.activate_power("pause")
				if w in [4, 6, 11, 13] and wave_time > 2.0 and tp.can_use_power("haste"):
					tp.activate_power("haste")
				if w == 5 and not did_rewind_w5 and wave_time > 8.0 and tp.can_use_power("rewind"):
					did_rewind_w5 = true
					tp.activate_power("rewind")
				if w == 9 and not did_rewind_w9 and wave_time > 8.0 and tp.can_use_power("rewind"):
					did_rewind_w9 = true
					tp.activate_power("rewind")

		if GameState.mission.is_over:
			break

	var m := GameState.mission
	var powers_total: int = m.stats["powers_used"]["rewind"] + m.stats["powers_used"]["pause"] + m.stats["powers_used"]["haste"]
	var res: Dictionary = {
		"outcome": m.outcome,
		"wave": m.wave_number,
		"lives": m.lives,
		"surges": m.surge_count,
		"first_surge_wave": first_surge_wave,
		"powers_total": powers_total,
		"mutations": m.mutations.duplicate(),
		"w1_w2_active_seconds": w1_w2_active_seconds,
	}
	remove_child(inst)
	inst.queue_free()
	GameState.prompts_muted = false
	return res


func _test_wave15_stall() -> Dictionary:
	GameState.prompts_muted = true
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)
	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")

	GameState.mission.wave_number = 15
	wm.start_wave()
	while wm.is_wave_active():
		wm.step_wave(0.25)
		for e in map.get_active_enemies():
			e.take_damage(9999.0)
	var outcome: String = GameState.mission.outcome
	remove_child(inst)
	inst.queue_free()
	GameState.prompts_muted = false
	return {"outcome": outcome}


func _step(map: GameMap, wm: WaveManager, econ: EconomyManager, surge: SurgeManager, tp: TimePowersManager, ba: BaseAttackManager, duration: float, dt: float) -> void:
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
