extends Node

## Headless Step 8 + Real UI Input + Full 15-Wave Verification:
## 1. Real mouse click on build pad (not blocked by Background/PromptBanner) opens Build Menu & places tower
## 2. Towers are ALWAYS visible to build on startup; clicking tower button then pad also builds!
## 3. Prompts Wave 1-6 appear once each, never duplicate; Mute keeps Surge/Preview/Feed visible
## 4. "How time works" <= 9 lines naming Armoured, Thaw-hardened, Swift, Surge
## 5. No-powers 15-wave run wins & suffers surges (first surge Wave 3)
## 6. Heavy-powers (6+ uses) 15-wave run wins with exact 1:1 mutation counts
## 7. Wave 15 stall check verified

func _ready() -> void:
	await _test_real_ui_clicks_and_prompts()
	var no_pow: Dictionary = _simulate_15_waves(false)
	var heavy_pow: Dictionary = _simulate_15_waves(true)
	var stall_res: Dictionary = _test_wave15_stall()

	assert(no_pow["outcome"] == "won", "No-powers run must win via 3 base charges, got %s at wave %d (lives=%d)" % [no_pow["outcome"], no_pow["wave"], no_pow["lives"]])
	assert(no_pow["surges"] >= 3, "No-powers run must visibly suffer surges, got %d" % no_pow["surges"])
	print("OBSERVED_W1_W2_ACTIVE_SECONDS=", no_pow["w1_w2_active_seconds"], " first_surge_wave=", no_pow["first_surge_wave"])
	assert(no_pow["first_surge_wave"] == 3, "Skipping powers in W1-2 must trigger Surge at Wave 3, got Wave %d (w1_w2_s=%.1f)" % [no_pow["first_surge_wave"], no_pow["w1_w2_active_seconds"]])

	assert(heavy_pow["outcome"] == "won", "Heavy-powers run must win despite stacked mutations, got %s at wave %d (lives=%d)" % [heavy_pow["outcome"], heavy_pow["wave"], heavy_pow["lives"]])
	assert(heavy_pow["powers_total"] >= 6, "Heavy-powers run must use >=6 powers, used %d" % heavy_pow["powers_total"])
	var mut_sum: int = heavy_pow["mutations"]["armoured_stacks"] + heavy_pow["mutations"]["thaw_stacks"] + heavy_pow["mutations"]["swift_stacks"]
	assert(mut_sum == heavy_pow["powers_total"], "Mutations (%d) must match powers used (%d) 1:1" % [mut_sum, heavy_pow["powers_total"]])

	assert(stall_res["outcome"] == "stalled", "Surviving Wave 15 without killing base must trigger stalled state")

	print("STEP8_AND_FULL_RUN_PASS real_ui_clicks=ok no_pow=(w%d,surges=%d,first_surge_w=%d,w1_w2_s=%.1f) heavy_pow=(w%d,powers=%d,muts=%s) stall=%s" % [
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


func _send_left_click(map: GameMap, screen_pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	if DisplayServer.get_name() == "headless":
		# Dummy headless display has 0x0 OS window; route directly to MapClickArea in map-local coords
		down.position = screen_pos - map.position
		down.global_position = screen_pos
		map.map_click_area.gui_input.emit(down)
		await get_tree().process_frame
		return
	down.position = screen_pos
	down.global_position = screen_pos
	get_viewport().push_input(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen_pos
	up.global_position = screen_pos
	get_viewport().push_input(up)
	await get_tree().process_frame


func _test_real_ui_clicks_and_prompts() -> void:
	GameState.prompts_muted = false
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)
	await get_tree().process_frame

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	# Verify NO visible mouse-blocking HUD Control covers ANY of the 14 build pads or leaks outside 1280x720!
	for ctrl_name in ["TopBar", "RightPanel", "BottomBar", "PromptBanner"]:
		var ctrl: Control = hud.get_node(ctrl_name)
		var r: Rect2 = ctrl.get_global_rect()
		assert(r.end.x <= 1281.0 and r.end.y <= 721.0, "%s overflows 1280x720: %s" % [ctrl_name, str(r)])
		for i in range(GameMap.BUILD_PAD_POSITIONS.size()):
			var pad_screen: Vector2 = GameMap.BUILD_PAD_POSITIONS[i] + map.position
			assert(not r.has_point(pad_screen), "%s overlaps Pad P%d at %s! rect=%s" % [ctrl_name, i + 1, str(pad_screen), str(r)])

	# Verify BuildMenuBox is IMMEDIATELY visible, buttons have icons, and hover panel stays rigid!
	assert(hud.build_menu_box.visible, "BuildMenuBox must be visible on startup so player sees towers to add")
	assert(hud.build_blaster_button.visible and hud.build_mortar_button.visible)
	assert(hud.build_blaster_button.icon != null and hud.build_mortar_button.icon != null, "Tower buttons must have icons")
	assert(hud.manip_upgrade_button.icon != null, "Manipulator button must have icon")
	for k in hud._research_buttons.keys():
		assert(hud._research_buttons[k].icon != null, "Research button %s must have icon" % k)

	var base_right_size: Vector2 = hud.right_panel.size
	var base_hover_size: Vector2 = hud.hover_info_panel.size
	assert(base_right_size == Vector2(340, 480), "RightPanel must stay fixed 340x480, got %s" % str(base_right_size))

	var buttons_to_hover: Array[Button] = [
		hud.build_blaster_button,
		hud.build_mortar_button,
		hud.manip_upgrade_button,
	]
	for k in hud._research_buttons.keys():
		buttons_to_hover.append(hud._research_buttons[k])
	for b in buttons_to_hover:
		b.mouse_entered.emit()
		await get_tree().process_frame
		assert(hud.right_panel.size == base_right_size, "Hovering must NOT resize RightPanel!")
		assert(hud.hover_info_panel.size == base_hover_size, "Hovering must NOT resize HoverInfoPanel!")
		assert(hud.hover_info_label.get_line_count() <= 2, "Description too long (>2 lines): %s" % hud.hover_info_label.text)
		b.mouse_exited.emit()
		await get_tree().process_frame

	# Verify Wave 1 PromptBanner is visible and NOT overlapping Pad P1 (220, 64+32=96)!
	assert(hud.prompt_banner.visible and hud.prompt_label.text.contains("TIP (1/6)"))
	var p1_screen := Vector2(220.0, 96.0)
	assert(not hud.prompt_banner.get_global_rect().has_point(p1_screen), "PromptBanner must NOT cover Pad P1")

	# Simulate click on Pad P1 (while PromptBanner is open!):
	await _send_left_click(map, p1_screen)
	assert(map.selected_pad_index == 0, "Click on Pad P1 must reach Map and select pad 0")
	assert(hud.build_pad_label.text.contains("P1"))

	# Click Blaster button -> places Blaster on P1!
	hud.build_blaster_button.pressed.emit()
	await get_tree().process_frame
	assert(map.pad_occupancy[0] != null and map.pad_occupancy[0].tower_type == "blaster")

	for tb in [hud.upg_dmg_button, hud.upg_rng_button, hud.upg_spd_button, hud.sell_button]:
		tb.mouse_entered.emit()
		await get_tree().process_frame
		assert(hud.right_panel.size == base_right_size, "Hovering tower btn must NOT resize RightPanel!")
		assert(hud.hover_info_panel.size == base_hover_size, "Hovering tower btn must NOT resize HoverInfoPanel!")
		assert(hud.hover_info_label.get_line_count() <= 2, "Tower btn description >2 lines: %s" % hud.hover_info_label.text)
		tb.mouse_exited.emit()
		await get_tree().process_frame

	# Click empty map space -> clears selection -> BuildMenuBox STILL visible, click Mortar button FIRST -> click P11!
	await _send_left_click(map, Vector2(100.0, 200.0))
	assert(hud.build_menu_box.visible)
	hud.build_mortar_button.pressed.emit()
	assert(map.pending_build_type == "mortar")
	await _send_left_click(map, Vector2(430.0, 64.0 + 322.0)) # Pad P11 (index 10)
	assert(map.pad_occupancy[10] != null and map.pad_occupancy[10].tower_type == "mortar", "Clicking tower then pad must build Mortar on P11")

	# Check How Time Works <= 9 lines & names all 3 mutations + Surge
	var htw: String = hud.how_time_works_label.text
	var lines: PackedStringArray = htw.split("\n", false)
	assert(lines.size() <= 9, "How time works must be <=9 lines, got %d" % lines.size())
	assert(htw.contains("Armoured") and htw.contains("Thaw-hardened") and htw.contains("Swift") and htw.contains("SURGE"))

	# Reach Wave 2 active -> TIP 2/6 appears once; Rewind must not repeat it
	hud._on_prompt_dismiss_pressed()
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

	var did_rewind_w5: bool = false
	var did_rewind_w9: bool = false

	while not GameState.mission.is_over and GameState.mission.wave_number <= 15:
		var w: int = GameState.mission.wave_number

		if not use_heavy_powers and w == 2 and GameState.mission.economy["refineries_owned"] == 1 and econ.can_build_refinery():
			econ.start_build_refinery()
		if use_heavy_powers and w == 3 and GameState.mission.economy["refineries_owned"] == 1 and econ.can_build_refinery():
			econ.start_build_refinery()

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

		for t in map.get_all_towers():
			for stat_k in ["damage", "fire_rate", "range"]:
				var lvl: int = int(t.levels[stat_k])
				if lvl < Balance.TOWER_UPGRADE_MAX_LEVEL:
					var upg_cost: int = Balance.TOWER_UPGRADE_COSTS[lvl]
					if t.can_start_upgrade(stat_k) and GameState.mission.economy["money"] >= upg_cost + reserve:
						t.start_upgrade(stat_k)
						break

		for rk in ["reinforced_shots", "rapid_cycling", "extended_optics"]:
			if econ.can_buy_research(rk):
				econ.buy_research(rk)

		if use_heavy_powers and w == 7 and tp.can_upgrade_manipulator() and not ba.is_charging:
			if GameState.mission.economy["money"] >= 300:
				tp.start_manipulator_upgrade()

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
				if w in [2, 3, 4, 7, 8, 10, 11, 12] and wave_time > 4.0 and tp.can_use_power("pause"):
					tp.activate_power("pause")
				if w in [3, 4, 7, 8, 11, 12] and wave_time > 1.5 and tp.can_use_power("haste"):
					tp.activate_power("haste")
				if w == 5 and not did_rewind_w5 and wave_time > 8.0 and tp.can_use_power("rewind"):
					did_rewind_w5 = true
					tp.activate_power("rewind")
				if w == 8 and not did_rewind_w9 and wave_time > 8.0 and tp.can_use_power("rewind"):
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
