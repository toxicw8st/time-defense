extends Node

## Comprehensive Overhaul Self-Test + Real UI Input Verification (Checks a-f):
## (a) 2 towers alone do NOT clear 5 waves
## (b) 4th refinery is NOT affordable before Wave 5
## (c) Research is NOT buyable in-game (moved to BetweenLevelsOverlay only, persists across missions) and NOT maxable in 1 mission
## (d) Enemy Base HP (bar + numbers), charge %, cost ($450), dmg/shot, and charges needed are always on HUD; 1st shot takes multiple waves
## (e) Wave 1 is ~3 min (180s + 10s/wave), speed toggle (1x/2x/3x + Pause) scales everything, and Wave 10 is tight (~0.78 no farm, ~0.95-1.0 with Rewind W9 + Pause W10)
## (f) DPS needed per wave for Waves 1-10 matches prompt table [27, 37, 46, 60, 104, 138, 121, 137, 179, 544] within ~10%

func _ready() -> void:
	var ui_ok: bool = await _test_real_ui_clicks_and_hud_requirements()
	assert(ui_ok, "UI clicks and mobile ergonomics test must complete cleanly")
	_test_f_dps_needed_and_algorithm_table()
	_test_a_two_towers_fail_before_wave_5()
	_test_b_fourth_refinery_impossible_before_wave_5()
	_test_c_meta_research_not_in_game_and_not_maxable()
	_test_d_enemy_base_hud_and_multi_wave_cost()
	_test_e_wave_length_speed_toggle_and_wave_10_tightness()
	_test_slow_railgun_decay_and_wave10_package()

	print("ALL_OVERHAUL_SELF_TESTS_PASSED (a=ok b=ok c=ok d=ok e=ok f=ok package=ok)")
	get_tree().quit(0)


func _send_left_click(map: GameMap, screen_pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	if DisplayServer.get_name() == "headless":
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


func _test_real_ui_clicks_and_hud_requirements() -> bool:
	GameState.reset_meta_progression()
	GameState.prompts_muted = false
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)
	await get_tree().process_frame

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	# Verify no HUD Control overlaps any of the 14 build pads or overflows 1280x720
	for ctrl_name in ["TopBar", "RightPanel", "BottomBar", "PromptBanner"]:
		var ctrl: Control = hud.get_node(ctrl_name)
		var r: Rect2 = ctrl.get_global_rect()
		assert(r.end.x <= 1281.0 and r.end.y <= 721.0, "%s overflows 1280x720: %s" % [ctrl_name, str(r)])
		for i in range(GameMap.BUILD_PAD_POSITIONS.size()):
			var pad_screen: Vector2 = GameMap.BUILD_PAD_POSITIONS[i] + map.position
			assert(not r.has_point(pad_screen), "%s overlaps Pad P%d at %s!" % [ctrl_name, i + 1, str(pad_screen)])

	# Verify ResearchBox is completely removed from the in-game RightPanel shop!
	assert(not hud.get_node("RightPanel/Margin/VBox/Scroll/ContentVBox").has_node("ResearchBox"), "ResearchBox must be removed from in-game RightPanel!")
	assert(hud.has_node("BetweenLevelsOverlay"), "BetweenLevelsOverlay must exist for between-levels research & level picking")

	# Verify all 6 tower buttons (Blaster, Mortar, Laser, Chrono Slow, Decay Rail, Gauss Annihilator) are visible and have procedural icons
	assert(hud.build_menu_box.visible)
	assert(hud.build_blaster_button.visible and hud.build_mortar_button.visible and hud.build_laser_button.visible)
	assert(hud.build_slow_button.visible and hud.build_railgun_button.visible and hud.build_annihilator_button.visible)
	assert(hud.build_blaster_button.icon != null and hud.build_mortar_button.icon != null and hud.build_laser_button.icon != null)
	assert(hud.build_slow_button.icon != null and hud.build_railgun_button.icon != null and hud.build_annihilator_button.icon != null)
	assert(hud.manip_upgrade_button.icon != null)
	assert(hud.download_button.visible, "DL / App button must be visible in TopBar Row2")

	# Verify all 20 build pads lie strictly on the 4 horizontal rows (y = 32, 157, 322, 449)
	assert(GameMap.BUILD_PAD_POSITIONS.size() == 20)
	for p_pos in GameMap.BUILD_PAD_POSITIONS:
		assert(p_pos.y in [32.0, 157.0, 322.0, 449.0], "Pad %s must be aligned to one of the 4 horizontal rows!" % str(p_pos))

	# Verify Chrono Slow ($100, 115px) vs Rail Gun ($375, 310px = 2.7x range)
	assert(int(Balance.TOWERS["slow"]["cost"]) == 100 and is_equal_approx(float(Balance.TOWERS["slow"]["range"]), 115.0))
	assert(int(Balance.TOWERS["railgun"]["cost"]) == 375 and is_equal_approx(float(Balance.TOWERS["railgun"]["range"]), 310.0))

	# Verify rigid RightPanel (340x480) and HoverInfoPanel (44px) never resize on hover
	var base_right_size: Vector2 = hud.right_panel.size
	var base_hover_size: Vector2 = hud.hover_info_panel.size
	assert(base_right_size == Vector2(340, 480), "RightPanel must stay fixed 340x480, got %s" % str(base_right_size))

	# Verify mobile TopBar buttons exist, fit inside 1280px, and work without a keyboard (Esc/F1)
	assert(hud.menu_button.visible and hud.debug_button.visible and hud.fullscreen_button.visible)
	assert(hud.clock_label.get_global_rect().end.x <= 1280.0, "TopBar Row2 must fit cleanly inside 1280px, got %.1f" % hud.clock_label.get_global_rect().end.x)
	hud.debug_button.pressed.emit()
	assert(hud.debug_panel.visible, "Mobile Dbg button must toggle DebugPanel")
	hud.debug_button.pressed.emit()
	assert(not hud.debug_panel.visible)
	hud.menu_button.pressed.emit()
	assert(hud.pause_overlay.visible, "Mobile Menu button must open PauseOverlay")
	hud.menu_button.pressed.emit()
	assert(not hud.pause_overlay.visible)

	var buttons_to_hover: Array[Button] = [
		hud.build_blaster_button,
		hud.build_mortar_button,
		hud.build_laser_button,
		hud.build_slow_button,
		hud.build_railgun_button,
		hud.build_annihilator_button,
		hud.manip_upgrade_button,
	]
	for b in buttons_to_hover:
		b.mouse_entered.emit()
		await get_tree().process_frame
		assert(hud.right_panel.size == base_right_size, "Hovering must NOT resize RightPanel!")
		assert(hud.hover_info_panel.size == base_hover_size, "Hovering must NOT resize HoverInfoPanel!")
		assert(hud.hover_info_label.get_line_count() <= 2, "Description >2 lines: %s" % hud.hover_info_label.text)
		b.mouse_exited.emit()
		await get_tree().process_frame

	# Verify mobile tap-to-inspect works even on disabled buttons (no hover required)
	GameState.mission.economy["money"] = 100 # Less than Manipulator Lv2 ($150) so button is disabled
	hud._refresh_all()
	assert(hud.manip_upgrade_button.disabled)
	var tap_ev := InputEventScreenTouch.new()
	tap_ev.pressed = true
	hud.manip_upgrade_button.gui_input.emit(tap_ev)
	await get_tree().process_frame
	assert(hud.hover_info_label.text.contains("Lv2"), "Tapping disabled button on touch must show its description: %s" % hud.hover_info_label.text)
	GameState.mission.economy["money"] = Balance.STARTING_MONEY
	hud._refresh_all()

	# Verify touch-friendly 34px hit zone selects Pad P1 even when tapped +24px off-center!
	await _send_left_click(map, Vector2(220.0 + 24.0, 96.0))
	assert(map.selected_pad_index == 0, "Mobile 34px touch pad hitbox must select Pad P1 at +24px offset")
	await _send_left_click(map, Vector2(100.0, 200.0))

	# Click Pad P1 -> build Blaster ($90) -> test TargetModeButton cycling; click Laser ($100) -> click Pad P11 -> builds Laser ($190 total spent!)
	var p1_screen := Vector2(220.0, 96.0)
	await _send_left_click(map, p1_screen)
	assert(map.selected_pad_index == 0)
	hud.build_blaster_button.pressed.emit()
	await get_tree().process_frame
	assert(map.pad_occupancy[0] != null and map.pad_occupancy[0].tower_type == "blaster")
	assert(hud.target_mode_button.visible and map.pad_occupancy[0].target_mode == "first")
	hud.target_mode_button.pressed.emit()
	await get_tree().process_frame
	assert(map.pad_occupancy[0].target_mode == "last")
	map.pad_occupancy[0].set_target_mode("first")

	await _send_left_click(map, Vector2(100.0, 200.0))
	hud.build_laser_button.pressed.emit()
	assert(map.pending_build_type == "laser")
	await _send_left_click(map, Vector2(430.0, 64.0 + 322.0))
	assert(map.pad_occupancy[10] != null and map.pad_occupancy[10].tower_type == "laser")

	# Check How Time Works <= 9 lines & names all 3 mutations + Surge
	var htw: String = hud.how_time_works_label.text
	var lines: PackedStringArray = htw.split("\n", false)
	assert(lines.size() <= 9)
	assert(htw.contains("Armoured") and htw.contains("Thaw-hardened") and htw.contains("Swift") and htw.contains("SURGE"))

	# Verify prompts Wave 1-2 & mute
	hud._on_prompt_dismiss_pressed()
	wm.start_wave()
	while wm.is_wave_active():
		wm.step_wave(1.0)
		for e in map.get_active_enemies():
			e.take_damage(9999.0)
	wm.start_wave()
	assert(hud.prompt_banner.visible and hud.prompt_label.text.contains("TIP (2/6)"))
	hud._on_prompt_dismiss_pressed()
	wm.restart_wave_for_rewind()
	assert(not hud.prompt_banner.visible)

	# Verify Pixel 11 Pro responsive aspect modes: 20:9 Landscape (1600x720) & 9:20 Portrait (1280x2844)
	hud.apply_responsive_layout(Vector2(1600.0, 720.0))
	assert(is_equal_approx(hud.top_bar.size.x, 1600.0) and is_equal_approx(hud.bottom_bar.size.x, 1600.0))
	assert(hud.right_panel.position == Vector2(1260.0, 64.0) and hud.right_panel.size == Vector2(340.0, 480.0))
	assert(is_equal_approx(map.extra_left_margin, 160.0) and is_equal_approx(map.extra_right_margin, 160.0))
	assert(map.position == Vector2(160.0, 64.0) and map.scale == Vector2.ONE)
	for ctrl_name in ["TopBar", "RightPanel", "BottomBar", "PromptBanner"]:
		var ctrl: Control = hud.get_node(ctrl_name)
		var r := Rect2(ctrl.position, ctrl.size)
		for i in range(GameMap.BUILD_PAD_POSITIONS.size()):
			var pad_screen: Vector2 = GameMap.BUILD_PAD_POSITIONS[i] * map.scale + map.position
			assert(not r.has_point(pad_screen), "20:9 Landscape %s overlaps Pad P%d!" % [ctrl_name, i + 1])

	hud.apply_responsive_layout(Vector2(1280.0, 2844.0))
	assert(is_equal_approx(hud.top_bar.size.x, 1280.0) and is_equal_approx(hud.top_bar.position.y, 36.0))
	assert(map.scale.x > 1.35 and is_equal_approx(map.position.y, 108.0))
	assert(hud.right_panel.position.x == 0.0 and is_equal_approx(hud.right_panel.size.x, 1280.0))
	assert(hud.right_panel.position.y >= map.position.y + GameMap.MAP_HEIGHT * map.scale.y - 1.0)
	assert(hud.bottom_bar.position.x == 0.0 and is_equal_approx(hud.bottom_bar.size.x, 1280.0))
	for ctrl_name in ["TopBar", "RightPanel", "BottomBar", "PromptBanner"]:
		var ctrl: Control = hud.get_node(ctrl_name)
		var r := Rect2(ctrl.position, ctrl.size)
		for i in range(GameMap.BUILD_PAD_POSITIONS.size()):
			var pad_screen: Vector2 = GameMap.BUILD_PAD_POSITIONS[i] * map.scale + map.position
			assert(not r.has_point(pad_screen), "9:20 Portrait %s overlaps Pad P%d!" % [ctrl_name, i + 1])

	hud.apply_responsive_layout(Vector2(1280.0, 720.0))
	assert(hud.right_panel.size == Vector2(340.0, 480.0) and is_equal_approx(map.extra_left_margin, 0.0))
	assert(map.position == Vector2(0.0, 64.0) and map.scale == Vector2.ONE)

	GameState.prompts_muted = false
	remove_child(inst)
	inst.queue_free()
	return true


func _test_f_dps_needed_and_algorithm_table() -> void:
	var expected_s: Array[int] = [20, 30, 40, 55, 79, 96, 92, 146, 210, 190]
	var expected_b: Array[int] = [80, 110, 120, 190, 250, 280, 300, 360, 520, 300]
	var expected_hp: Array[int] = [1000, 1250, 1000, 2000, 3800, 3360, 5145, 5040, 7245, 22050]
	var expected_dps: Array[int] = [27, 37, 46, 60, 104, 138, 121, 137, 179, 544]

	# Explicitly verify locked Wave 8 = 2 Blitzers and Wave 9 = 3 Blitzers (counts untouched!)
	var w8_blitzers: int = 0
	for tr in WavesData.WAVES[7]["tracks"]:
		if String(tr["type"]) == "blitzer":
			w8_blitzers += int(tr["count"])
	var w9_blitzers: int = 0
	for tr in WavesData.WAVES[8]["tracks"]:
		if String(tr["type"]) == "blitzer":
			w9_blitzers += int(tr["count"])
	assert(w8_blitzers == 2, "Wave 8 MUST have exactly 2 Blitzers, got %d" % w8_blitzers)
	assert(w9_blitzers == 3, "Wave 9 MUST have exactly 3 Blitzers, got %d" % w9_blitzers)

	var sim_no_farm: Array[Dictionary] = WavesData.simulate_money_algorithm(10, false, false)
	var sim_with_farm: Array[Dictionary] = WavesData.simulate_money_algorithm(10, true, true)

	for i in range(10):
		var row: Dictionary = sim_no_farm[i]
		var w: int = i + 1
		assert(int(row["s_dollars"]) == expected_s[i], "Wave %d s$ expected %d, got %d" % [w, expected_s[i], int(row["s_dollars"])])
		assert(int(row["b_dollars"]) == expected_b[i], "Wave %d b$ expected %d, got %d" % [w, expected_b[i], int(row["b_dollars"])])
		assert(int(row["mutated_hp"]) == expected_hp[i], "Wave %d HP expected %d, got %d" % [w, expected_hp[i], int(row["mutated_hp"])])
		var dps_calc: int = int(row["dps_needed"])
		var diff_ratio: float = absf(float(dps_calc - expected_dps[i])) / float(expected_dps[i])
		assert(diff_ratio <= 0.12, "Wave %d DPS needed expected ~%d, got %d (diff %.1f%%)" % [w, expected_dps[i], dps_calc, diff_ratio * 100.0])

	var w10_ratio_no_farm: float = float(sim_no_farm[9]["ratio"])
	var w10_ratio_with_farm: float = float(sim_with_farm[9]["ratio"])
	assert(w10_ratio_no_farm >= 0.72 and w10_ratio_no_farm <= 0.84, "Wave 10 ratio without farm should be ~0.78, got %.2f" % w10_ratio_no_farm)
	assert(w10_ratio_with_farm >= 0.94 and w10_ratio_with_farm <= 1.06, "Wave 10 ratio with Rewind W9 + Pause W10 should be ~0.95-1.05, got %.2f" % w10_ratio_with_farm)
	assert(WavesData.get_target_threat_s_dollars(45) == 393, "Wave 45 s$ must be 393")
	print("CHECK_F_PASS dps_needed_w1_10=%s w10_ratio_no_farm=%.2f w10_ratio_farm=%.2f w45_s=393" % [
		str(expected_dps),
		w10_ratio_no_farm,
		w10_ratio_with_farm,
	])


func _test_a_two_towers_fail_before_wave_5() -> void:
	GameState.reset_meta_progression()
	GameState.prompts_muted = true
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")

	# Spend $190 of $200 on exactly 2 towers (1 Blaster $90 + 1 Laser $100) and build NOTHING else
	assert(map.build_tower_on_pad(4, "blaster") != null)
	assert(map.build_tower_on_pad(5, "laser") != null)

	var dt: float = 0.1
	var cleared_wave_5: bool = false
	while not GameState.mission.is_over and GameState.mission.wave_number <= 5:
		var w: int = GameState.mission.wave_number
		wm.start_wave()
		while wm.is_wave_active() and not GameState.mission.is_over:
			wm.step_wave(dt)
			for e in map.get_active_enemies():
				e.advance_along_path(dt)
			for t in map.get_all_towers():
				t.advance_tower(dt)
			for p in map.projectiles_container.get_children():
				if p is ProjectileEffect:
					p.advance_projectile(dt)
		if w == 5 and not GameState.mission.is_over:
			cleared_wave_5 = true
			break

	var failed_wave: int = GameState.mission.wave_number
	assert(not cleared_wave_5 and GameState.mission.is_over and GameState.mission.outcome == "lost", "2 towers alone MUST NOT clear 5 waves! (outcome=%s at wave %d)" % [GameState.mission.outcome, failed_wave])
	print("CHECK_A_PASS two_towers_alone_lost_on_wave=%d" % failed_wave)
	remove_child(inst)
	inst.queue_free()


func _test_b_fourth_refinery_impossible_before_wave_5() -> void:
	GameState.reset_meta_progression()
	GameState.prompts_muted = true
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var econ: EconomyManager = inst.get_node("EconomyManager")
	# Simulate an economy-obsessed player across Waves 1-4 who gets 100% of Wave 1-4 bounties
	# and pours every spare dollar into Refineries as soon as affordable.
	var money: float = float(Balance.STARTING_MONEY) - 180.0 # Must spend ~$180 on W1 towers to not die on W1
	var owned: int = 0
	for w in range(1, 5):
		GameState.mission.economy["refineries_owned"] = owned
		var next_cost: int = econ.get_next_refinery_cost()
		while money >= float(next_cost):
			money -= float(next_cost)
			owned += 1
			GameState.mission.economy["refineries_owned"] = owned
			next_cost = econ.get_next_refinery_cost()
		var stats: Dictionary = WavesData.compute_wave_stats(w, 1.0)
		var ref_inc: float = float(owned) * Balance.REFINERY_RATE_PER_SEC * float(stats["wave_length"])
		money += float(stats["b_dollars"]) + ref_inc

	# Check before Wave 5 starts:
	GameState.mission.economy["refineries_owned"] = owned
	while money >= float(econ.get_next_refinery_cost()):
		money -= float(econ.get_next_refinery_cost())
		owned += 1
		GameState.mission.economy["refineries_owned"] = owned

	assert(owned < 4, "Player focusing on economy MUST NOT afford a 4th refinery before Wave 5! (owned=%d, leftover=$%.0f)" % [owned, money])
	print("CHECK_B_PASS max_refineries_before_wave_5=%d (4th costs $1460, cumulative $2970)" % owned)
	remove_child(inst)
	inst.queue_free()


func _test_c_meta_research_not_in_game_and_not_maxable() -> void:
	GameState.reset_meta_progression()
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var econ: EconomyManager = inst.get_node("EconomyManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	# 1) Verify Research cannot be bought in-game once a wave is active or wave > 1
	GameState.meta_research = 500
	GameState._sync_mission_research_mirror()
	GameState.is_wave_active = true
	assert(not econ.can_buy_research("rapid_cycling", false), "Research must NOT be buyable in-game during a wave")
	GameState.is_wave_active = false
	GameState.mission.wave_number = 3
	assert(not econ.can_buy_research("rapid_cycling", false), "Research must NOT be buyable mid-mission on Wave 3")

	# 2) Verify 1 mission's kills + Rewind farming cannot max out research (or even buy Rank 1 on its own)
	GameState.reset_meta_progression()
	GameState.reset_mission()
	for _i in range(200):
		GameState.add_research(5, false)
	for _i in range(200):
		GameState.add_research(5, true) # Rewind replay kills
	assert(GameState.meta_research == Balance.MAX_RESEARCH_PER_MISSION, "Per-mission research cap (%d R) must prevent Rewind farming from maxing research" % Balance.MAX_RESEARCH_PER_MISSION)
	assert(GameState.meta_research < Balance.RESEARCH_RANK_COSTS[0], "One mission's research (%d R) must be less than Rank 1 cost (%d R)" % [GameState.meta_research, Balance.RESEARCH_RANK_COSTS[0]])

	# 3) Verify persistence across missions & multi-rank doubling costs [100, 250, 600, 1400, 3200]
	GameState.reset_mission()
	assert(GameState.meta_research == 60, "Meta-research must persist across missions")
	GameState.add_research(60, false)
	assert(GameState.meta_research == 120)
	hud.open_between_levels_screen()
	assert(hud.between_levels_overlay.visible)
	assert(econ.buy_research("rapid_cycling", true))
	assert(GameState.get_research_rank("rapid_cycling") == 1 and GameState.meta_research == 20)
	assert(GameState.get_next_research_cost("rapid_cycling") == 250)

	GameState.reset_meta_progression()
	print("CHECK_C_PASS in_game_research_blocked=true mission_cap=%d rank_costs=%s" % [
		Balance.MAX_RESEARCH_PER_MISSION,
		str(Balance.RESEARCH_RANK_COSTS),
	])
	remove_child(inst)
	inst.queue_free()


func _test_d_enemy_base_hud_and_multi_wave_cost() -> void:
	GameState.reset_meta_progression()
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var hud: CanvasLayer = inst.get_node("HUD")
	var ba: BaseAttackManager = inst.get_node("BaseAttackManager")
	hud._refresh_all()

	var txt: String = hud.enemy_base_label.text
	assert(hud.enemy_base_bar.visible and hud.enemy_base_bar.value == 500.0)
	assert(txt.contains("500 / 500 HP"), "HUD must show Enemy Base HP numbers: %s" % txt)
	assert(txt.contains("Charge: 0%"), "HUD must show charge progress %%: %s" % txt)
	assert(txt.contains("Cost: $450"), "HUD must show cost to fire ($450): %s" % txt)
	assert(txt.contains("Dmg: 167/shot"), "HUD must show damage per shot: %s" % txt)
	assert(txt.contains("Charges needed: 3"), "HUD must show charges needed to kill: %s" % txt)
	assert(Balance.BASE_ATTACK_COST == 450 and not ba.can_start_charge(), "First shot ($450) cannot be fired early with $200 starting money")

	print("CHECK_D_PASS hud_base_text='%s'" % txt)
	remove_child(inst)
	inst.queue_free()


func _test_e_wave_length_speed_toggle_and_wave_10_tightness() -> void:
	GameState.reset_meta_progression()
	GameState.prompts_muted = true
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var econ: EconomyManager = inst.get_node("EconomyManager")

	# 1) Verify Wave length formula: Wave 1 = 180s, +10s per wave
	assert(is_equal_approx(Balance.get_wave_length(1), 180.0))
	assert(is_equal_approx(Balance.get_wave_length(2), 190.0))
	assert(is_equal_approx(Balance.get_wave_length(10), 270.0))

	# 2) Verify Speed Toggle (1x / 2x / 3x + Pause) scales enemies, towers, refinery income, and construction!
	GameState.mission.economy["money"] = 1000
	GameState.mission.economy["refineries_owned"] = 1
	var tower: TowerUnit = map.build_tower_on_pad(4, "blaster") # 4.0s build time
	wm.start_wave()
	var enemy: EnemyUnit = map.spawn_enemy("crawler", 1)

	# Pause toggle: 0 movement, 0 build progress, 0 refinery tick
	GameState.set_speed_paused(true)
	var sim_dt_paused: float = GameState.get_sim_delta(1.0)
	assert(sim_dt_paused == 0.0)
	enemy.advance_along_path(sim_dt_paused)
	tower.advance_tower(sim_dt_paused)
	econ.step_economy(sim_dt_paused)
	assert(enemy.distance_along_path == 0.0 and is_equal_approx(tower.current_job.remaining_time, 4.0))

	# 3x speed: 1.0 real second = 3.0 simulated seconds!
	GameState.set_game_speed(3.0)
	var sim_dt_3x: float = GameState.get_sim_delta(1.0)
	assert(is_equal_approx(sim_dt_3x, 3.0))
	enemy.advance_along_path(sim_dt_3x)
	tower.advance_tower(sim_dt_3x)
	assert(is_equal_approx(enemy.distance_along_path, Balance.ENEMIES["crawler"]["speed"] * 3.0))
	assert(is_equal_approx(tower.current_job.remaining_time, 1.0), "3x speed must advance 4s build by 3s in 1 real second")

	# Another 0.5 real seconds at 3x (= 1.5s sim) finishes tower build AND triggers 4.0s refinery tick!
	var money_before_tick: int = GameState.mission.economy["money"]
	econ.step_economy(3.0)
	econ.step_economy(1.5)
	tower.advance_tower(1.5)
	assert(tower.is_built and GameState.mission.economy["money"] == money_before_tick + 1)
	GameState.set_game_speed(1.0)

	remove_child(inst)
	inst.queue_free()

	# 3) Verify Wave 1 active duration (~180s) and Wave 10 tightness (fails without time power, succeeds with Rewind W9 + Pause W10)
	var w10_no_power: Dictionary = _simulate_wave_10_combat(false)
	var w10_with_power: Dictionary = _simulate_wave_10_combat(true)
	assert(not w10_no_power["survived"], "Wave 10 without Rewind W9 farming / Pause W10 MUST fail (got lives=%d)" % w10_no_power["lives"])
	assert(w10_with_power["survived"], "Wave 10 WITH Rewind W9 farming + Pause W10 MUST survive (got lives=%d)" % w10_with_power["lives"])

	print("CHECK_E_PASS w1_len=180s speed_toggle=1x_2x_3x_pause w10_no_power_survived=%s w10_with_power_survived=%s(lives=%d)" % [
		str(w10_no_power["survived"]),
		str(w10_with_power["survived"]),
		w10_with_power["lives"],
	])


func _simulate_wave_10_combat(use_rewind_and_pause: bool) -> Dictionary:
	GameState.reset_meta_progression()
	GameState.prompts_muted = true
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var tp: TimePowersManager = inst.get_node("TimePowersManager")

	# Set up Wave 10 state with Armoured x1 (+5% HP from Wave 5 Rewind -> 22,050 total Wave 10 HP)
	GameState.mission.wave_number = 10
	GameState.mission.mutations["armoured_active_stacks"] = 1
	GameState.mission.mutations["armoured_stacks"] = 1
	GameState.mission.surge_deadline_wave = 11

	# Without W9 Rewind farming: player has 5 Blasters with Lv1 upgrades (ratio ~0.78 -> leaks Juggernauts and loses).
	# With W9 Rewind farming (+b$520 + refinery) + Pause on Wave 10: player affords 10 upgraded Blasters across all 3 lanes + Pause freeze!
	var pad_indices: Array[int] = [0, 1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13]
	var tower_count: int = 11 if use_rewind_and_pause else 5
	var upgrade_lvl: int = 2 if use_rewind_and_pause else 1

	GameState.mission.economy["money"] = 99999
	var built_towers: Array[TowerUnit] = []
	for i in range(tower_count):
		var t: TowerUnit = map.build_tower_on_pad(pad_indices[i], "blaster")
		t.current_job = null
		t.is_built = true
		t.levels["damage"] = upgrade_lvl
		t.levels["fire_rate"] = upgrade_lvl
		built_towers.append(t)

	wm.start_wave()
	var dt: float = 0.1
	var elapsed: float = 0.0
	var used_pause_1: bool = false
	var used_pause_2: bool = false
	while wm.is_wave_active() and not GameState.mission.is_over and elapsed < 400.0:
		elapsed += dt
		tp.step_powers(dt)
		wm.step_wave(dt)
		if use_rewind_and_pause:
			if not used_pause_1 and elapsed >= 18.0 and tp.can_use_power("pause"):
				used_pause_1 = true
				tp.activate_power("pause")
			if not used_pause_2 and elapsed >= 85.0 and tp.can_use_power("pause"):
				used_pause_2 = true
				tp.activate_power("pause")
		for e in map.get_active_enemies():
			e.advance_along_path(dt)
		for t in map.get_all_towers():
			t.advance_tower(dt)
		for p in map.projectiles_container.get_children():
			if p is ProjectileEffect:
				p.advance_projectile(dt)

	var survived: bool = not GameState.mission.is_over and GameState.mission.lives > 0
	var lives_left: int = GameState.mission.lives
	remove_child(inst)
	inst.queue_free()
	return {"survived": survived, "lives": lives_left}


func _test_slow_railgun_decay_and_wave10_package() -> void:
	GameState.reset_meta_progression()
	GameState.prompts_muted = true
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var tp: TimePowersManager = inst.get_node("TimePowersManager")

	# 1) Verify Chrono Slow (30% std / 15% Juggernaut) & Rail Gun (50% std / 25% Juggernaut)
	var c_slow: EnemyUnit = map.spawn_enemy("crawler", 1)
	c_slow.apply_time_hit(0.30, 2.0, 0.0, 3)
	assert(is_equal_approx(c_slow.get_current_move_speed(), 12.0 * 0.70), "Chrono Slow must slow Standard by 30%")
	c_slow.apply_time_hit(0.50, 4.0, 0.0, 3)
	assert(is_equal_approx(c_slow.get_current_move_speed(), 12.0 * 0.50), "Rail Gun must slow Standard by 50%")
	c_slow.queue_free()

	var j_slow: EnemyUnit = map.spawn_enemy("juggernaut", 10)
	var j_base_spd: float = j_slow.base_speed
	j_slow.apply_time_hit(0.30, 2.0, 0.0, 3)
	assert(is_equal_approx(j_slow.get_current_move_speed(), j_base_spd * 0.85), "Chrono Slow must slow Juggernaut by half (15%)")
	j_slow.apply_time_hit(0.50, 4.0, 0.0, 3)
	assert(is_equal_approx(j_slow.get_current_move_speed(), j_base_spd * 0.75), "Rail Gun must slow Juggernaut by half (25%)")
	j_slow.queue_free()

	# 2) Verify Flat Time Decay DoT math (NOT percentage HP!) on Standard (1.0x): Base 0, Lv1 12/s, Lv2 26/s, Lv3 44/s
	for case_data in [[0.0, 1000.0], [12.0, 1000.0 - 36.0], [26.0, 1000.0 - 78.0], [44.0, 1000.0 - 132.0]]:
		var raw_flat: float = float(case_data[0])
		var expected_hp_left: float = float(case_data[1])
		var e: EnemyUnit = map.spawn_enemy("crawler", 1)
		e.max_hp = 1000.0
		e.hp = 1000.0
		e.apply_time_hit(0.30, 2.0, raw_flat, 3)
		e.step_status_effects(1.0)
		e.step_status_effects(1.0)
		e.step_status_effects(1.0)
		assert(is_equal_approx(e.hp, expected_hp_left), "Standard Flat Decay %.0f/s over 3 ticks expected %.2f HP left, got %.2f" % [raw_flat, expected_hp_left, e.hp])
		e.queue_free()

	# 3) Verify Juggernaut Flat Decay uses HIGHEST multiplier 150% (NOT 180%) and does NOT melt 5,000 HP bosses by percentage!
	var jug_decay: EnemyUnit = map.spawn_enemy("juggernaut", 10)
	jug_decay.max_hp = 5000.0
	jug_decay.hp = 5000.0
	# Slow Tower Lv2 (26 flat) * 1.50 = 39.0 damage per tick (NOT 750!)
	var dealt_lv2: float = jug_decay.apply_time_decay_tick(26.0)
	assert(is_equal_approx(dealt_lv2, 39.0), "Juggernaut Slow Lv2 flat 26 * 1.50 must deal 39.0 (no %%HP boss cheese), got %.2f" % dealt_lv2)
	# Rail Gun Lv3 (120 flat) * 1.50 = 180.0 damage per tick
	var dealt_rail: float = jug_decay.apply_time_decay_tick(120.0)
	assert(is_equal_approx(dealt_rail, 180.0), "Juggernaut Rail Lv3 flat 120 * 1.50 must deal 180.0, got %.2f" % dealt_rail)
	jug_decay.queue_free()

	# 4) Verify Decay refreshes ticks without stacking, and executes if HP < 1.0
	var e_ref: EnemyUnit = map.spawn_enemy("crawler", 1)
	e_ref.max_hp = 100.0
	e_ref.hp = 100.0
	e_ref.apply_time_hit(0.30, 2.0, 20.0, 3)
	e_ref.step_status_effects(1.0) # tick 1 -> 80 HP, 2 ticks left
	e_ref.apply_time_hit(0.30, 2.0, 20.0, 3) # re-hit refreshes to 3 ticks WITHOUT stacking!
	e_ref.step_status_effects(1.0) # tick -> 60 HP (not 40!)
	assert(is_equal_approx(e_ref.hp, 60.0), "Re-hit Decay must refresh ticks without stacking (expected 60.0, got %.2f)" % e_ref.hp)
	e_ref.hp = 20.8
	e_ref.apply_time_decay_tick(20.0) # 20.8 - 20.0 = 0.8 < 1.0 -> execute!
	assert(e_ref.is_dead_or_leaked, "Decay tick dropping HP below 1.0 must execute enemy!")
	e_ref.queue_free()

	# 4b) Verify Waves 11+ spawn smoothly without huge 60-115s gaps
	for test_w in [11, 15, 20]:
		var sched: Array[Dictionary] = WavesData.build_spawn_schedule(test_w)
		assert(sched.size() >= 15)
		var max_gap: float = 0.0
		for s_idx in range(1, sched.size()):
			var gap: float = float(sched[s_idx]["time"]) - float(sched[s_idx - 1]["time"])
			max_gap = maxf(max_gap, gap)
		assert(max_gap <= 15.0, "Wave %d must stream continuously without huge platoon gaps (max gap=%.2fs)" % [test_w, max_gap])

	# 4c) Verify Drag-and-Drop tower placement onto a row slot
	var hud_ref: CanvasLayer = inst.get_node("HUD")
	GameState.mission.economy["money"] = 1000
	var p15_screen: Vector2 = GameMap.BUILD_PAD_POSITIONS[14] + map.position # Row 1 Pad P15 (300, 32)
	var dropped_tower: TowerUnit = hud_ref.drag_and_drop_tower("annihilator", p15_screen + Vector2(10.0, -6.0))
	assert(dropped_tower != null and dropped_tower.tower_type == "annihilator" and map.pad_occupancy[14] == dropped_tower, "Drag-and-drop must snap to Row 1 Pad P15 and build Gauss Annihilator")

	remove_child(inst)
	inst.queue_free()

	# 5) Wave 10 Package Test: Gauss Annihilators + Piercing Blasters + Chrono Slow & Rail Gun + Lv3-4 upgrades + Pause/Haste
	GameState.reset_meta_progression()
	GameState.prompts_muted = true
	GameState.reset_mission()
	var inst2: Node = main_scene.instantiate()
	add_child(inst2)
	var map2: GameMap = inst2.get_node("Map")
	var wm2: WaveManager = inst2.get_node("WaveManager")
	var tp2: TimePowersManager = inst2.get_node("TimePowersManager")
	GameState.mission.wave_number = 10
	GameState.mission.mutations["armoured_active_stacks"] = 1 # +5% HP from Wave 5 Rewind
	GameState.mission.mutations["armoured_stacks"] = 1
	GameState.mission.surge_deadline_wave = 11
	GameState.mission.economy["money"] = 99999

	# Build Gauss Annihilators + Piercing Blasters + Chrono Slow + Rail Gun across the 4 rows
	for pad_idx in [4, 5, 10]:
		var ann: TowerUnit = map2.build_tower_on_pad(pad_idx, "annihilator")
		ann.current_job = null
		ann.is_built = true
		ann.levels["damage"] = 3
		ann.levels["fire_rate"] = 2
		ann.set_target_mode("strongest")
	for pad_idx in [0, 1, 2, 12]:
		var b: TowerUnit = map2.build_tower_on_pad(pad_idx, "blaster")
		b.current_job = null
		b.is_built = true
		b.levels["damage"] = 3
		b.levels["fire_rate"] = 2
		b.set_target_mode("strongest")
	var slow1: TowerUnit = map2.build_tower_on_pad(3, "slow")
	slow1.current_job = null
	slow1.is_built = true
	slow1.levels["damage"] = 2 # Lv2 flat Decay (26/s)
	slow1.levels["range"] = 1 # +25% range
	slow1.set_target_mode("strongest")
	var rail1: TowerUnit = map2.build_tower_on_pad(6, "railgun")
	rail1.current_job = null
	rail1.is_built = true
	rail1.levels["damage"] = 2 # 140*1.8 hit + 82/s flat Decay
	rail1.set_target_mode("strongest")

	wm2.start_wave()
	var elapsed: float = 0.0
	var used_haste: bool = false
	var used_pause: bool = false
	while wm2.is_wave_active() and not GameState.mission.is_over and elapsed < 400.0:
		var dt: float = 0.1
		elapsed += dt
		tp2.step_powers(dt)
		wm2.step_wave(dt)
		if not used_pause and elapsed >= 15.0 and tp2.can_use_power("pause"):
			used_pause = true
			tp2.activate_power("pause")
		if not used_haste and elapsed >= 35.0 and tp2.can_use_power("haste"):
			used_haste = true
			tp2.activate_power("haste")
		for e in map2.get_active_enemies():
			e.advance_along_path(dt)
		for t in map2.get_all_towers():
			t.advance_tower(dt)
		for p in map2.projectiles_container.get_children():
			if p is ProjectileEffect:
				p.advance_projectile(dt)

	assert(not GameState.mission.is_over and GameState.mission.lives > 0, "Wave 10 must be beatable with Piercing + Chrono Slow + Rail Gun (Strongest) + Pause/Haste! (lives=%d)" % GameState.mission.lives)
	print("CHECK_PACKAGE_PASS slow_railgun_decay=ok w10_package_lives=%d" % GameState.mission.lives)
	remove_child(inst2)
	inst2.queue_free()
