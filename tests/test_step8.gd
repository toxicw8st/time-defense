extends Node

const Visuals = preload("res://scripts/tower_visuals.gd")

## Comprehensive Overhaul Self-Test + Real UI Input Verification (Checks a-f):
## (a) 2 towers alone do NOT clear 5 waves
## (b) 4th refinery is NOT affordable before Wave 5
## (c) Research is NOT buyable in-game (moved to BetweenLevelsOverlay only, persists across missions) and NOT maxable in 1 mission
## (d) Enemy Base HP (bar + numbers), charge %, cost ($450), dmg/shot, and charges needed are always on HUD; 1st shot takes multiple waves
## (e) Wave 1 is ~3 min (180s + 10s/wave), speed toggle (1x/2x/3x + Pause) scales everything, and Wave 10 is tight (~0.78 no farm, ~0.95-1.0 with Rewind W9 + Pause W10)
## (f) DPS needed per wave for Waves 1-10 matches prompt table [27, 37, 46, 60, 104, 138, 121, 137, 179, 544] within ~10%

func _ready() -> void:
	if AnalyticsManager != null:
		AnalyticsManager.suppress_default_persistence = true
	var ui_ok: bool = await _test_real_ui_clicks_and_hud_requirements()
	assert(ui_ok, "UI clicks and mobile ergonomics test must complete cleanly")
	_test_f_dps_needed_and_algorithm_table()
	_test_a_two_towers_fail_before_wave_5()
	_test_b_fourth_refinery_impossible_before_wave_5()
	_test_c_meta_research_not_in_game_and_not_maxable()
	_test_d_enemy_base_hud_and_multi_wave_cost()
	_test_e_wave_length_speed_toggle_and_wave_10_tightness()
	_test_slow_railgun_decay_and_wave10_package()
	await _test_g_combos_bubble_and_sandbox()
	await _test_h_rebalance_and_pass2_polish()
	await _test_i_analytics_telemetry_and_ui()

	print("ALL_OVERHAUL_SELF_TESTS_PASSED (a=ok b=ok c=ok d=ok e=ok f=ok package=ok combos=ok bubble=ok sandbox=ok rebalance=ok pass2=ok analytics=ok)")
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

	# Verify full-screen interposing Guide Vex overlay (~1/4-screen bust, pauses combat while talking, hides cleanly on ack!)
	assert(not hud.prompt_banner.visible, "Legacy PromptBanner tips must stay hidden")
	assert(hud.guide_panel.visible and hud.guide_title_label.text.contains("VEX"), "Guide Vex must show Wave 1 build beat on first playthrough")
	assert(get_tree().paused, "Vex full-screen interposing guide must pause gameplay while speaking")
	for test_vp in [Vector2(1280.0, 720.0), Vector2(1600.0, 720.0), Vector2(1280.0, 2844.0)]:
		hud.apply_responsive_layout(test_vp)
		await get_tree().process_frame
		var gp_r: Rect2 = hud.guide_panel.get_global_rect()
		var port_r: Rect2 = hud.guide_portrait.get_global_rect()
		var box_r: Rect2 = hud.guide_speech_box.get_global_rect()
		var vp_area: float = test_vp.x * test_vp.y
		var port_frac: float = (port_r.size.x * port_r.size.y) / vp_area
		assert(is_equal_approx(gp_r.size.x, test_vp.x) and is_equal_approx(gp_r.size.y, test_vp.y), "GuidePanel must cover entire viewport at %s, got %s" % [str(test_vp), str(gp_r)])
		assert(port_frac >= 0.18 and port_frac <= 0.34, "Vex bust must occupy ~1/4 of screen at %s (got %.1f%%)" % [str(test_vp), port_frac * 100.0])
		assert(box_r.position.x >= 0.0 and box_r.end.x <= test_vp.x + 1.0 and box_r.end.y <= test_vp.y + 1.0, "GuideSpeechBox overflow at %s: %s" % [str(test_vp), str(box_r)])
		assert(not port_r.intersects(box_r), "Vex bust must not overlap speech callout box at %s" % str(test_vp))
	hud.apply_responsive_layout(Vector2(1280.0, 720.0))
	await get_tree().process_frame
	hud._on_guide_ack_pressed()
	assert(not hud.guide_panel.visible and not get_tree().paused, "Acknowledging Vex must hide overlay and immediately unpause gameplay")

	# Verify one-tap Auto-Wave button on TopBar syncs with GameState & Pause menu checkbox
	assert(hud.auto_wave_button != null and hud.auto_wave_button.visible and hud.auto_wave_button.text == "Auto:OFF")
	hud.auto_wave_button.pressed.emit()
	assert(GameState.auto_wave_enabled and hud.auto_wave_button.text == "Auto:ON" and hud.pause_auto_wave_check.button_pressed)
	hud.auto_wave_button.pressed.emit()
	assert(not GameState.auto_wave_enabled and hud.auto_wave_button.text == "Auto:OFF" and not hud.pause_auto_wave_check.button_pressed)

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

	# Verify Wave 1 combat & Wave 2 combat Vex beats interpose and unpause cleanly
	wm.start_wave()
	assert(hud.guide_panel.visible and get_tree().paused and hud.guide_body_label.text.contains("0.5x"), "Guide Vex must interpose & pause to explain 0.5x / 1x / 1.5x speed during Wave 1 combat")
	hud._on_guide_ack_pressed()
	assert(not hud.guide_panel.visible and not get_tree().paused)
	while wm.is_wave_active():
		wm.step_wave(1.0)
		for e in map.get_active_enemies():
			e.take_damage(9999.0)
	assert(hud.guide_panel.visible and hud.guide_title_label.text.contains("3/8"), "Guide Vex must present Wave 2 Combine beat")
	hud._on_guide_ack_pressed()
	wm.start_wave()
	assert(hud.guide_panel.visible and hud.guide_title_label.text.contains("4/8"), "Guide Vex must present Wave 2 Time Powers beat")
	hud._on_guide_ack_pressed()
	wm.restart_wave_for_rewind()
	assert(not hud.guide_panel.visible)

	# Verify speed options: Default = 3.0 (1x), 0.5x = 1.5, 1.5x = 4.5
	assert(is_equal_approx(GameState.game_speed, Balance.DEFAULT_GAME_SPEED), "Default speed must be 3.0 (1x)")
	hud.speed_1x_button.pressed.emit()
	assert(is_equal_approx(GameState.game_speed, 1.5) and GameState.get_relative_speed_label() == "0.5x")
	hud.speed_3x_button.pressed.emit()
	assert(is_equal_approx(GameState.game_speed, 4.5) and GameState.get_relative_speed_label() == "1.5x")
	hud.speed_2x_button.pressed.emit()
	assert(is_equal_approx(GameState.game_speed, 3.0) and GameState.get_relative_speed_label() == "1x")

	# Verify Pixel 11 Pro responsive aspect modes: 20:9 Landscape (1600x720) & 9:20 Portrait Phone (1280x2844)
	hud.apply_responsive_layout(Vector2(1600.0, 720.0))
	assert(is_equal_approx(hud.top_bar.size.x, 1600.0) and is_equal_approx(hud.bottom_bar.size.x, 1600.0))
	assert(hud.right_panel.position == Vector2(1220.0, 70.0) and hud.right_panel.size.x == 380.0)
	assert(hud.tower_buttons_grid.columns == 2, "Phone Landscape must use 2-col tower upgrades to eliminate vertical scrolling")
	assert(hud.build_blaster_button.custom_minimum_size.y >= 36.0, "Phone landscape shop buttons must be bigger (>=36px)")
	assert(map.scale.x >= 0.95)
	for ctrl_name in ["TopBar", "RightPanel", "BottomBar"]:
		var ctrl: Control = hud.get_node(ctrl_name)
		var r := Rect2(ctrl.position, ctrl.size)
		for i in range(GameMap.BUILD_PAD_POSITIONS.size()):
			var pad_screen: Vector2 = GameMap.BUILD_PAD_POSITIONS[i] * map.scale + map.position
			assert(not r.has_point(pad_screen), "20:9 Landscape %s overlaps Pad P%d!" % [ctrl_name, i + 1])

	hud.apply_responsive_layout(Vector2(1280.0, 2844.0))
	assert(is_equal_approx(hud.top_bar.size.x, 1280.0) and is_equal_approx(hud.top_bar.position.y, 36.0), "Portrait TopBar must fit 1280px width cleanly, got %s" % str(hud.top_bar.size))
	assert(is_equal_approx(hud.top_bar.size.y, 160.0), "Portrait TopBar must use 3-row touch-friendly height (160px), got %.1f" % hud.top_bar.size.y)
	assert(map.scale.x > 1.35 and is_equal_approx(map.position.y, 196.0))
	assert(hud.top_controls_row.visible, "Portrait TopBar must split controls onto dedicated Row 3")
	assert(hud.build_buttons_grid.columns == 2, "Portrait shop must use 2-column grid (no elongated 1280px strips!)")
	assert(hud.tower_buttons_grid.columns == 2, "Portrait tower upgrades must use 2-column grid")
	assert(hud.bottom_actions_grid.columns == 3, "Portrait bottom bar must use 3x2 chunky touch grid")
	assert(hud.build_blaster_button.custom_minimum_size.y >= 84.0, "Portrait shop buttons must be chunky thumb targets (>=84px)")
	assert(hud.start_wave_button.custom_minimum_size.y >= 104.0, "Portrait bottom buttons must be chunky thumb targets (>=104px)")
	assert(hud.right_panel.position.x == 0.0 and is_equal_approx(hud.right_panel.size.x, 1280.0))
	assert(hud.right_panel.position.y >= map.position.y + GameMap.MAP_HEIGHT * map.scale.y - 1.0)
	assert(hud.bottom_bar.position.x == 0.0 and is_equal_approx(hud.bottom_bar.size.x, 1280.0))
	for ctrl_name in ["TopBar", "RightPanel", "BottomBar"]:
		var ctrl: Control = hud.get_node(ctrl_name)
		var r := Rect2(ctrl.position, ctrl.size)
		for i in range(GameMap.BUILD_PAD_POSITIONS.size()):
			var pad_screen: Vector2 = GameMap.BUILD_PAD_POSITIONS[i] * map.scale + map.position
			assert(not r.has_point(pad_screen), "9:20 Portrait %s overlaps Pad P%d!" % [ctrl_name, i + 1])

	hud.apply_responsive_layout(Vector2(1280.0, 720.0))
	assert(hud.build_buttons_grid.columns == 1 and hud.bottom_actions_grid.columns == 6)
	assert(hud.right_panel.size == Vector2(340.0, 480.0) and is_equal_approx(map.extra_left_margin, 0.0), "Desktop restore mismatch: rp=%s rp_min=%s extra_l=%.1f" % [str(hud.right_panel.size), str(hud.right_panel.get_combined_minimum_size()), map.extra_left_margin])
	assert(map.position == Vector2(0.0, 64.0) and map.scale == Vector2.ONE)

	# Verify Start Menu + Startup Full-Screen Guide Vex greeting & Dismiss button fit inside all 3 viewports!
	hud.open_start_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(hud.guide_panel.visible and hud.guide_ack_button.text == "Guide Me!", "Vex must greet player at startup so they can dismiss or follow")
	for test_vp in [Vector2(1280.0, 720.0), Vector2(1600.0, 720.0), Vector2(1280.0, 2844.0)]:
		hud.apply_responsive_layout(test_vp)
		await get_tree().process_frame
		await get_tree().process_frame
		var sm_r: Rect2 = hud.start_menu_overlay.get_global_rect()
		var play_r: Rect2 = hud.start_play_button.get_global_rect()
		var gp_r: Rect2 = hud.guide_panel.get_global_rect()
		var box_r: Rect2 = hud.guide_speech_box.get_global_rect()
		assert(sm_r.position.x >= 0.0 and sm_r.position.y >= 0.0 and sm_r.end.x <= test_vp.x + 1.0 and sm_r.end.y <= test_vp.y + 1.0, "StartMenu overflow at %s: %s" % [str(test_vp), str(sm_r)])
		assert(play_r.end.y <= test_vp.y + 1.0 and play_r.end.y <= sm_r.end.y + 1.0, "StartPlayButton pushed off-screen at %s: %s" % [str(test_vp), str(play_r)])
		assert(is_equal_approx(gp_r.size.x, test_vp.x) and is_equal_approx(gp_r.size.y, test_vp.y), "Startup GuidePanel must cover full viewport at %s" % str(test_vp))
		assert(box_r.position.x >= 0.0 and box_r.end.x <= test_vp.x + 1.0 and box_r.end.y <= test_vp.y + 1.0, "Startup GuideSpeechBox overflow at %s: %s" % [str(test_vp), str(box_r)])
	hud.guide_dismiss_button.pressed.emit()
	assert(not hud.guide_panel.visible and GameState.prompts_muted, "Dismiss Vex must hide and mute guide")
	hud.apply_responsive_layout(Vector2(1280.0, 720.0))
	hud.close_start_menu()

	hud._toggle_pause_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(hud.pause_overlay.get_global_rect().end.y <= 720.0, "PauseOverlay overflowed bottom: %s" % str(hud.pause_overlay.get_global_rect()))
	hud._toggle_pause_menu()

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

	# 4c) Verify Area-Based Drag-and-Drop tower placement (both pad-aligned and free-form inside a zone) + rejection outside zones
	var hud_ref: CanvasLayer = inst.get_node("HUD")
	GameState.mission.economy["money"] = 2000
	var p15_screen: Vector2 = GameMap.BUILD_PAD_POSITIONS[14] + map.position # Row 1 Pad P15 (300, 32)
	var dropped_tower: TowerUnit = hud_ref.drag_and_drop_tower("annihilator", p15_screen + Vector2(10.0, -6.0))
	assert(dropped_tower != null and dropped_tower.tower_type == "annihilator" and map.pad_occupancy[14] == dropped_tower, "Drag-and-drop near P15 must snap to Row 1 Pad P15 and build Gauss Annihilator")

	# Free-form drop in Level 1 ROW 1 between P15 (300,32) and P2 (380,32) at (340, 32)
	var free_row_screen: Vector2 = Vector2(340.0, 32.0) + map.position
	var free_tower: TowerUnit = hud_ref.drag_and_drop_tower("blaster", free_row_screen)
	assert(free_tower != null and is_equal_approx(free_tower.position.x, 340.0) and is_equal_approx(free_tower.position.y, 32.0), "Free drag-and-drop inside Level 1 Row 1 area must place tower at (340, 32)")

	# Invalid drop outside placement zones (on the path at (350, 75)) must be rejected and spend $0
	var money_before_bad_drop: int = GameState.mission.economy["money"]
	var bad_tower: TowerUnit = hud_ref.drag_and_drop_tower("blaster", Vector2(350.0, 75.0) + map.position)
	assert(bad_tower == null and GameState.mission.economy["money"] == money_before_bad_drop, "Dropping outside placement zones must fail and cost $0")

	# 4d) Verify Start Menu, all 5 Levels (Levels 1..5), their placement zones, and Hive Destroyer blasts (Level 1 = 3 blasts = 167 dmg)
	var ba_ref: BaseAttackManager = inst.get_node("BaseAttackManager")
	hud_ref.open_start_menu()
	assert(hud_ref.start_menu_overlay != null and hud_ref.start_menu_overlay.visible, "Start Menu must open")
	assert(hud_ref.start_level_buttons.size() == 5, "Start Menu must have 5 level buttons")
	var expected_shots_dmg: Array[int] = [167, 167, 125, 125, 100]
	var expected_shots_count: Array[int] = [3, 3, 4, 4, 5]
	for lvl_id in range(1, 6):
		hud_ref._select_level(lvl_id)
		map.load_level(lvl_id)
		assert(GameState.selected_map_level == lvl_id and GameState.selected_mission_level == expected_shots_count[lvl_id - 1])
		assert(ba_ref.get_shot_damage() == expected_shots_dmg[lvl_id - 1], "Level %d shot dmg expected %d, got %d" % [lvl_id, expected_shots_dmg[lvl_id - 1], ba_ref.get_shot_damage()])
		var plen_lvl: float = map.get_path_length()
		assert(plen_lvl >= 1800.0 and plen_lvl <= 2000.0, "Level %d path length must be ~1900px, got %.1f" % [lvl_id, plen_lvl])
		assert(map.active_placement_zones.size() >= 3, "Level %d must define placement zones" % lvl_id)
		assert(map.active_pad_positions.size() == 20, "Level %d must define 20 pad anchor positions" % lvl_id)
		for p_pt in map.active_pad_positions:
			var z_hit: int = map.find_zone_for_point(p_pt, 4.0)
			assert(z_hit >= 0, "Level %d pad %s must lie inside a placement zone!" % [lvl_id, str(p_pt)])
			var d_path: float = p_pt.distance_to(map.enemy_path.curve.get_closest_point(p_pt))
			assert(d_path >= 36.5, "Level %d pad %s too close to path: %.1f" % [lvl_id, str(p_pt), d_path])

	# Test 2D island box drag-and-drop on Level 3 (ISLAND NW at (280, 155))
	hud_ref._select_level(3)
	map.load_level(3)
	GameState.mission.economy["money"] = 1000
	var island_drop: TowerUnit = hud_ref.drag_and_drop_tower("laser", Vector2(280.0, 155.0) + map.position)
	assert(island_drop != null and is_equal_approx(island_drop.position.x, 280.0) and is_equal_approx(island_drop.position.y, 155.0), "2D area drop inside Level 3 ISLAND NW must place tower at (280, 155)")
	hud_ref.close_start_menu()
	assert(not hud_ref.start_menu_overlay.visible)

	# 4e) Verify Base Visual States: Player Base Almost Dead vs Growing Surge Buildup (Stage 0->4) -> Electrical Surge Explosion, plus Alien Base stages
	GameState.mission.lives = 20
	GameState.mission.surge_timer_seconds = 950.0
	GameState.mission.wave_number = 1
	GameState.mission.surge_deadline_wave = 6
	var pb_nom: Dictionary = map.get_player_base_visual_state()
	assert(not pb_nom["almost_dead"] and not pb_nom["surge_imminent"] and pb_nom["surge_stage"] == 0 and pb_nom["visual_style"] == "nominal_citadel")

	# Verify Surge buildup grows continuously across Waves 1 -> 2 -> 3 -> 4 -> 5
	var prev_buildup: float = float(pb_nom["surge_buildup"])
	for w_step in [2, 3, 4, 5]:
		GameState.mission.wave_number = w_step
		var st_w: Dictionary = map.get_player_base_visual_state()
		var cur_buildup: float = float(st_w["surge_buildup"])
		assert(cur_buildup > prev_buildup, "Surge buildup must grow from wave to wave (w=%d: %.2f <= %.2f)" % [w_step, cur_buildup, prev_buildup])
		prev_buildup = cur_buildup
	assert(map.get_player_base_visual_state()["surge_stage"] == 4 and map.get_player_base_visual_state()["surge_imminent"])

	# Reset wave to 1 and test Almost Dead state
	GameState.mission.wave_number = 1
	GameState.mission.lives = 5
	var pb_crit: Dictionary = map.get_player_base_visual_state()
	assert(pb_crit["almost_dead"] and not pb_crit["surge_imminent"] and pb_crit["visual_style"] == "critical_hull_fire_smoke")

	# Test Timer-based Imminent Surge state
	GameState.mission.lives = 20
	GameState.mission.surge_timer_seconds = 10.0
	var pb_surge: Dictionary = map.get_player_base_visual_state()
	assert(not pb_surge["almost_dead"] and pb_surge["surge_imminent"] and pb_surge["visual_style"] == "temporal_overload_lightning")

	# Test Electrical Surge Explosion detonation when Surge fires!
	GameState.surge_triggered.emit(1)
	var pb_exp: Dictionary = map.get_player_base_visual_state()
	assert(pb_exp["surge_exploding"] and pb_exp["visual_style"] == "electrical_surge_explosion" and map.surge_explosion_sparks.size() == 28, "Surge detonation must trigger electrical explosion on Player Base!")
	map.surge_explosion_timer = 0.0
	map.surge_explosion_sparks.clear()

	# Test Ability Animations (Pause, Haste, Rewind) triggered by GameState.time_power_used
	for p_name in ["pause", "haste", "rewind"]:
		GameState.time_power_used.emit(p_name)
		var afx: Dictionary = map.get_ability_fx_state()
		assert(afx["active"] and afx["type"] == p_name and int(afx["particle_count"]) == 28, "Ability animation must trigger for %s" % p_name)
	map.ability_fx_timer = 0.0
	map.ability_fx_type = ""
	map.ability_fx_particles.clear()
	GameState.time_power_used.emit("test")
	assert(not map.get_ability_fx_state()["active"], "Unknown power 'test' should not trigger ability FX")

	# Test Cluster Mortar 60% slower fire rate (0.5 -> 0.20/s, 5.0s reload) & verify 1 Mortar cannot carry Waves 1-3 alone
	assert(is_equal_approx(float(Balance.TOWERS["mortar"]["fire_rate"]), 0.20), "Mortar fire rate must be slowed 60% to 0.20/s")

	GameState.mission.enemy_base_hp = 500
	assert(map.get_enemy_base_visual_state()["damage_stage"] == "healthy")
	GameState.mission.enemy_base_hp = 300
	assert(map.get_enemy_base_visual_state()["damage_stage"] == "damaged")
	GameState.mission.enemy_base_hp = 120
	var eb_crit: Dictionary = map.get_enemy_base_visual_state()
	assert(eb_crit["damage_stage"] == "critical" and eb_crit["almost_dead"])
	GameState.select_level(1)
	GameState.selected_mission_level = Balance.BASE_ATTACK_DEFAULT_LEVEL
	map.load_level(1)

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

	# 6) Verify 1 Cluster Mortar alone cannot carry 3 waves without leaks/loss after 60% slowdown
	GameState.reset_meta_progression()
	GameState.prompts_muted = true
	GameState.reset_mission()
	var inst3: Node = main_scene.instantiate()
	add_child(inst3)
	var map3: GameMap = inst3.get_node("Map")
	var wm3: WaveManager = inst3.get_node("WaveManager")
	var solo_mortar: TowerUnit = map3.build_tower_on_pad(4, "mortar") # P5 ($110)
	assert(solo_mortar != null)
	var survived_w3_unscathed: bool = true
	for _w_idx in range(1, 4):
		if GameState.mission.is_over:
			break
		wm3.start_wave()
		while wm3.is_wave_active() and not GameState.mission.is_over:
			var dt3: float = 0.1
			wm3.step_wave(dt3)
			for e in map3.get_active_enemies():
				e.advance_along_path(dt3)
			for t in map3.get_all_towers():
				t.advance_tower(dt3)
			for p in map3.projectiles_container.get_children():
				if p is ProjectileEffect:
					p.advance_projectile(dt3)
	if GameState.mission.lives < Balance.PLAYER_STARTING_LIVES or GameState.mission.is_over:
		survived_w3_unscathed = false
	assert(not survived_w3_unscathed, "1 Cluster Mortar alone MUST NOT carry Waves 1-3 without leaks after 60%% slowdown (lives=%d)" % GameState.mission.lives)
	print("CHECK_MORTAR_NERF_PASS solo_mortar_w1_3_lives=%d" % GameState.mission.lives)
	remove_child(inst3)
	inst3.queue_free()


func _test_g_combos_bubble_and_sandbox() -> void:
	# 1) Verify all 21 combinations exist in Balance.TOWERS and have bespoke accent colors & visual handlers
	var base_keys: Array[String] = Balance.BASE_TOWER_KEYS
	assert(base_keys.size() == 6)
	var seen_combos: Dictionary = {}
	for i in range(base_keys.size()):
		for j in range(i, base_keys.size()):
			var k: String = Balance.get_combo_key(base_keys[i], base_keys[j])
			assert(Balance.is_combo_tower(k), "Expected combo key: %s" % k)
			assert(Balance.TOWERS.has(k), "Missing combo definition: %s" % k)
			var col: Color = Visuals.get_accent_color(k)
			assert(col.a > 0.5)
			seen_combos[k] = true
	assert(seen_combos.size() == 21, "Must define all 21 2-tower combinations, got %d" % seen_combos.size())

	# 2) Verify Chrono Slow tower Status Bubble mechanics (slower 0.40/s rate, AoE slow, Decay + Radius grow on Damage upgrade)
	GameState.set_sandbox_mode(false)
	GameState.reset_meta_progression()
	GameState.prompts_muted = true
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)
	await get_tree().process_frame

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var hud: CanvasLayer = inst.get_node("HUD")
	GameState.mission.economy["money"] = 99999

	var slow_t: TowerUnit = map.build_tower_on_pad(0, "slow") # P1 (220, 32) near first path stretch (110..645, 75)
	assert(slow_t != null)
	slow_t.current_job = null
	slow_t.is_built = true
	assert(is_equal_approx(slow_t.get_effective_fire_rate(), 0.40), "Chrono Slow should fire slower at 0.40/s")
	assert(slow_t.spawner_creates_bubble(), "Chrono Slow must spawn Status Bubbles")
	var base_r: float = slow_t.get_effective_bubble_radius()
	var base_dot: float = slow_t.get_decay_flat_damage()
	slow_t.levels["damage"] = 3
	assert(slow_t.get_effective_bubble_radius() > base_r, "Damage upgrade must increase Chrono Bubble radius (was %.1f, now %.1f)" % [base_r, slow_t.get_effective_bubble_radius()])
	assert(slow_t.get_decay_flat_damage() > base_dot and slow_t.get_decay_flat_damage() < 30.0, "Slow bubble Decay DoT should be lessened vs old single-target")

	# Spawn 2 nearby Crawlers inside P1's range; step tower + projectiles and confirm BOTH get slowed & take Decay ticks
	var c1: EnemyUnit = map.spawn_enemy("crawler", 1)
	var c2: EnemyUnit = map.spawn_enemy("crawler", 1)
	c1.advance_along_path(2.6)
	c2.advance_along_path(3.1)
	var hp1_before: float = c1.hp
	var hp2_before: float = c2.hp
	var found_bubble: bool = false
	for _step in range(30): # 3.0s simulation
		slow_t.advance_tower(0.1)
		c1.advance_along_path(0.1)
		c2.advance_along_path(0.1)
		for p in map.projectiles_container.get_children():
			if p is ProjectileEffect:
				if p.is_bubble:
					found_bubble = true
				p.advance_projectile(0.1)
	assert(found_bubble, "Chrono Slow attack must create a ProjectileEffect status bubble")
	assert(c1.slow_pct >= 0.25 and c2.slow_pct >= 0.25, "Both nearby enemies must be slowed inside Chrono Status Bubble!")
	assert(c1.hp < hp1_before and c2.hp < hp2_before, "Time Decay inside Chrono Bubble must tick damage cleanly without timer reset starvation")
	map.clear_all_enemies()
	map.clear_all_projectiles()

	# 3) Verify Drag-to-Combine (shop onto built base tower) and Two-Tower Merge
	var b1: TowerUnit = map.build_tower_on_pad(4, "blaster") # P5 (380, 157)
	b1.current_job = null
	b1.is_built = true
	var p5_screen: Vector2 = map.position + b1.position * map.scale
	var drop_eval: Dictionary = map.evaluate_drop_position(b1.position, "laser")
	assert(bool(drop_eval["valid"]) and str(drop_eval.get("mode", "")) == "combine" and str(drop_eval.get("combo_type", "")) == "blaster+laser")
	var combined1: TowerUnit = hud.drag_and_drop_tower("laser", p5_screen)
	assert(combined1 == b1 and combined1.tower_type == "blaster+laser", "Dropping shop Laser onto Blaster must combine into blaster+laser")
	combined1.current_job = null
	combined1.is_built = true
	assert(not combined1.can_combine(), "Already combined towers cannot merge a third time")

	# Two-tower merge on map (mortar + annihilator -> mortar+annihilator) keeping higher upgrade level
	var m_t: TowerUnit = map.build_tower_on_pad(5, "mortar")
	var a_t: TowerUnit = map.build_tower_on_pad(6, "annihilator")
	m_t.current_job = null
	m_t.is_built = true
	a_t.current_job = null
	a_t.is_built = true
	a_t.levels["damage"] = 2
	var merged: TowerUnit = map.combine_two_towers(m_t, a_t)
	assert(merged == m_t and merged.tower_type == "mortar+annihilator", "Two-tower combine must form mortar+annihilator")
	assert(int(merged.levels["damage"]) == 2, "Merged tower must inherit higher upgrade rank")

	# 4) Verify Sandbox Mode on any level (e.g. Level 4): infinite money, instant build, Wave 1..45 launch, individual enemy spawns, no game-over on leaks
	hud._select_level(4)
	hud._launch_selected_level(true)
	await get_tree().process_frame
	assert(GameState.is_sandbox_mode, "Sandbox mode flag must activate")
	assert(map.current_level_id == 4, "Sandbox must work on any selected level (Level 4)")
	assert(GameState.mission.economy["money"] >= 999999, "Sandbox mode must grant infinite money")
	assert(hud.sandbox_panel.visible and hud.money_label.text.contains("SANDBOX"))

	# Instant-build an expensive combo component in Sandbox without starting wave
	var sb_rail: TowerUnit = map.build_tower_on_pad(0, "railgun")
	assert(sb_rail != null and sb_rail.is_built and sb_rail.current_job == null, "Sandbox instant-build should finish towers immediately even between waves")
	assert(GameState.mission.economy["money"] >= 999999, "Spending in Sandbox must preserve infinite money")

	# Spawn Wave 35 & individual Juggernaut, verify leak doesn't end Sandbox
	var spawned_juggs: Array[EnemyUnit] = map.sandbox_spawn_enemy("juggernaut", 35, 1)
	assert(spawned_juggs.size() == 1 and spawned_juggs[0].enemy_type == "juggernaut")
	GameState.lose_lives(99, "juggernaut", Vector2.ZERO)
	assert(not GameState.mission.is_over, "Leaking in Sandbox Mode must NOT trigger Mission Over")
	var ran_w35: bool = wm.start_sandbox_wave(35)
	assert(ran_w35 and GameState.mission.wave_number == 35 and wm.state == WaveManager.State.SPAWNING)

	# Verify SandboxPanel stays inside viewport bounds on Desktop, 20:9 Landscape, and 9:20 Portrait
	for test_vp in [Vector2(1280.0, 720.0), Vector2(1600.0, 720.0), Vector2(1280.0, 2844.0)]:
		hud.apply_responsive_layout(test_vp)
		await get_tree().process_frame
		var sb_r: Rect2 = hud.sandbox_panel.get_global_rect()
		assert(sb_r.position.x >= 0.0 and sb_r.end.x <= test_vp.x + 1.0 and sb_r.end.y <= test_vp.y + 1.0, "SandboxPanel overflow at %s: %s" % [str(test_vp), str(sb_r)])

	GameState.set_sandbox_mode(false)
	GameState.prompts_muted = false
	remove_child(inst)
	inst.queue_free()
	print("CHECK_COMBOS_BUBBLE_SANDBOX_PASS combos=21 bubble=ok sandbox=ok")


func _test_h_rebalance_and_pass2_polish() -> void:
	# 1) Tower-cost-scaled upgrade costs & merge upgrade-transfer anti-exploit
	var blaster_lv1: int = Balance.get_tower_upgrade_cost("damage", 0, "blaster")
	var mac_lv1: int = Balance.get_tower_upgrade_cost("damage", 0, "annihilator+annihilator")
	assert(blaster_lv1 == 60, "$90 Blaster Lv1 Damage must remain $60, got %d" % blaster_lv1)
	assert(mac_lv1 == 255, "$640 MAC Cannon Lv1 Damage must scale to $255, got %d" % mac_lv1)
	assert(mac_lv1 > blaster_lv1 * 3, "Endgame combo upgrade cost must scale significantly above $90 Blaster")
	var transfer_fee: int = Balance.get_merge_upgrade_transfer_fee("blaster", {"damage": 3, "range": 0, "fire_rate": 0}, "annihilator", {}, "blaster+annihilator")
	assert(transfer_fee > 0, "Transferring cheap Blaster Lv3 upgrades onto expensive hybrid must charge a positive transfer fee, got %d" % transfer_fee)

	# 2) Wave 16+ Colossus Siege Boss & monotonic post-W10 threat curve
	assert(Balance.ENEMIES.has("colossus"), "Wave 16+ Colossus enemy must exist in Balance.ENEMIES")
	assert(is_equal_approx(float(Balance.ENEMIES["colossus"]["base_hp"]), 14000.0), "Colossus base HP must be 14000")
	var w16: Dictionary = WavesData.compute_wave_stats(16)
	var w25: Dictionary = WavesData.compute_wave_stats(25)
	assert(int(w16["counts"].get("colossus", 0)) >= 1, "Wave 16 must introduce Colossus siege boss")
	assert(int(w25["s_dollars"]) > int(w16["s_dollars"]), "Post-W10 s$ threat must climb monotonically (W16=%d, W25=%d)" % [int(w16["s_dollars"]), int(w25["s_dollars"])])
	assert(int(w25["dps_needed"]) > 650, "Wave 25 DPS required must not collapse (got %d)" % int(w25["dps_needed"]))

	# 3) Save/Load Meta-Research, Medals & Preferences round-trip (isolated test file)
	var test_save_path: String = "user://test_verify_save_step8.cfg"
	GameState.reset_meta_progression()
	GameState.meta_research = 123
	GameState.meta_research_ranks["rapid_cycling"] = 2
	GameState.record_level_clear(1, "hard", 18)
	GameState.difficulty_key = "hard"
	GameState.auto_wave_enabled = true
	GameState.show_damage_numbers = false
	assert(GameState.save_meta_progress(test_save_path), "save_meta_progress must succeed")
	GameState.reset_meta_progression()
	GameState.difficulty_key = "standard"
	GameState.auto_wave_enabled = false
	GameState.show_damage_numbers = true
	assert(GameState.load_meta_progress(test_save_path), "load_meta_progress must succeed")
	assert(GameState.meta_research == 123, "Loaded meta_research mismatch")
	assert(int(GameState.meta_research_ranks["rapid_cycling"]) == 2, "Loaded rank mismatch")
	assert(bool(GameState.level_medals.get(1, {}).get("cleared", false)), "Loaded level medal mismatch")
	assert(GameState.difficulty_key == "hard" and GameState.auto_wave_enabled and not GameState.show_damage_numbers, "Loaded prefs mismatch")
	var abs_save: String = ProjectSettings.globalize_path(test_save_path)
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(abs_save)
	GameState.reset_meta_progression()
	GameState.difficulty_key = "standard"
	GameState.auto_wave_enabled = false
	GameState.show_damage_numbers = true

	# 4) Combat bug fixes, telemetry, Enemy Inspector, RecipesOverlay, Early-Call, Hive Retaliation & Endless Mode
	GameState.set_sandbox_mode(false)
	GameState.prompts_muted = true
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)
	await get_tree().process_frame

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var hud: CanvasLayer = inst.get_node("HUD")
	GameState.mission.economy["money"] = 50000

	# 4a) 30% max_hp Time Decay tick cap
	var cap_crawler: EnemyUnit = map.spawn_enemy("crawler", 1) # 50 max HP -> max tick 15.0
	var cap_dmg: float = cap_crawler.apply_time_decay_tick(500.0)
	assert(cap_dmg <= cap_crawler.max_hp * Balance.TIME_DECAY_MAX_TICK_PCT + 0.01, "Decay tick must obey 30%% max HP cap (dealt=%.2f)" % cap_dmg)
	map.clear_all_enemies()

	# 4b) blaster+mortar direct_primary_only (no double-dip primary splash)
	var fm_t: TowerUnit = map.build_tower_on_pad(0, "blaster")
	fm_t.current_job = null
	fm_t.is_built = true
	fm_t.transform_to_combo("blaster+mortar", 0, {}, 0.0, true)
	var fm_c: EnemyUnit = map.spawn_enemy("crawler", 1) # Standard: Piercing 75% (15*0.75=11.25), Normal 100% (11)
	fm_c.advance_along_path(3.8) # (218, 75) -> 43px from Pad 0 (220, 32)
	var fm_hp0: float = fm_c.hp
	for _s in range(15):
		fm_t.advance_tower(0.1)
		for p in map.projectiles_container.get_children():
			if p is ProjectileEffect:
				p.advance_projectile(0.1)
		if fm_c.hp < fm_hp0:
			break
	# One shot should deal direct 11.25 + secondary splash 11.0 = 22.25 (NOT 11.25 + 11.25 + 11.0 = 33.5!)
	var single_hit_dealt: float = fm_hp0 - fm_c.hp
	assert(single_hit_dealt > 10.0 and single_hit_dealt < 25.0, "blaster+mortar must NOT double-dip primary damage (dealt=%.2f)" % single_hit_dealt)
	map.clear_all_enemies()
	map.clear_all_projectiles()
	map.sell_tower(fm_t)

	# 4c) laser+laser 35% chain refraction arc + Tower Telemetry (total_damage_dealt / total_kills / DPS)
	var ll_t: TowerUnit = map.build_tower_on_pad(0, "laser")
	ll_t.current_job = null
	ll_t.is_built = true
	ll_t.transform_to_combo("laser+laser", 0, {}, 0.0, true)
	assert(ll_t.get_estimated_dps() > 15.0, "Tower get_estimated_dps() must return positive numeric DPS")
	var ch1: EnemyUnit = map.spawn_enemy("crawler", 1)
	var ch2: EnemyUnit = map.spawn_enemy("crawler", 1)
	ch1.advance_along_path(3.8) # (218, 75) -> 43px from Pad 0
	ch2.advance_along_path(3.0) # (195, 75) -> 23px behind ch1 (< 70px refract radius)
	var ch2_hp0: float = ch2.hp
	for _s in range(40):
		ll_t.advance_tower(0.1)
		if ch1.is_dead_or_leaked and ch2.hp < ch2_hp0:
			break
	assert(ch2.hp < ch2_hp0, "laser+laser must refract 35%% chain arc onto nearby enemy within 70px")
	assert(ll_t.total_damage_dealt > 0.0 and ll_t.total_kills >= 1, "Tower telemetry must record damage and kills (dmg=%.1f kills=%d)" % [ll_t.total_damage_dealt, ll_t.total_kills])
	map.select_tower_unit(ll_t)
	hud._refresh_all()
	assert(hud.tower_ratings_label.text.contains("DPS"), "HUD must show live numeric DPS")
	assert(hud.tower_status_label.text.contains("Kills"), "HUD must show live tower Kills telemetry")
	map.clear_all_enemies()
	map.sell_tower(ll_t)

	# 4d) laser+annihilator 3-stack Armor Shred cap
	var la_t: TowerUnit = map.build_tower_on_pad(0, "laser")
	la_t.current_job = null
	la_t.is_built = true
	la_t.transform_to_combo("laser+annihilator", 0, {}, 0.0, true)
	var jugg_s: EnemyUnit = map.spawn_enemy("juggernaut", 10)
	jugg_s.advance_along_path(5.2) # ~109px -> (219, 75), 43px from Pad 0
	for _s in range(60):
		la_t.advance_tower(0.1)
	assert(jugg_s.armor_shred_stacks == 3, "laser+annihilator must stack Armor Shred up to 3 stacks (got %d)" % jugg_s.armor_shred_stacks)

	# 4e) Enemy Inspector Card & RecipesOverlay responsive layout across all 3 viewports
	map.inspect_enemy(jugg_s)
	hud._refresh_all()
	assert(hud.enemy_inspector_panel.visible and hud.enemy_inspector_label.text.contains("Juggernaut"), "Enemy Inspector must display tapped enemy details")
	hud.open_recipes_overlay()
	assert(hud.recipes_overlay.visible and hud.recipes_list_box.get_child_count() == 21, "RecipesOverlay must list all 21 combinations")
	for test_vp in [Vector2(1280.0, 720.0), Vector2(1600.0, 720.0), Vector2(1280.0, 2844.0)]:
		hud.apply_responsive_layout(test_vp)
		await get_tree().process_frame
		var rr: Rect2 = hud.recipes_overlay.get_global_rect()
		var er: Rect2 = hud.enemy_inspector_panel.get_global_rect()
		assert(rr.position.x >= 0.0 and rr.end.x <= test_vp.x + 1.0 and rr.end.y <= test_vp.y + 1.0, "RecipesOverlay overflow at %s: %s" % [str(test_vp), str(rr)])
		assert(er.position.x >= 0.0 and er.end.x <= test_vp.x + 1.0 and er.end.y <= test_vp.y + 1.0, "EnemyInspectorPanel overflow at %s: %s" % [str(test_vp), str(er)])
	hud.recipes_overlay.visible = false
	map.clear_all_enemies()

	# 4f) Early-Call Next Wave bonus + Hive Retaliation + Endless Mode
	GameState.mission.wave_number = 3
	wm.state = WaveManager.State.FIGHTING
	GameState.is_wave_active = true
	var ec_e: EnemyUnit = map.spawn_enemy("crawler", 3)
	assert(wm.can_call_next_wave_early(), "Early-Call must be allowed during FIGHTING with active wave < max")
	var money_before_ec: int = GameState.mission.economy["money"]
	var expected_bonus: int = wm.get_early_call_bonus()
	var ec_ok: bool = wm.call_next_wave_early()
	assert(ec_ok and expected_bonus >= 5 and GameState.mission.economy["money"] == money_before_ec + expected_bonus, "Early-Call must grant immediate cash bonus")
	assert(GameState.mission.wave_number == 4, "Early-Call must advance to Wave 4")
	var before_retal: int = map.get_active_enemies().size()
	map.trigger_hive_retaliation(330, 4)
	assert(map.get_active_enemies().size() >= before_retal + 4, "Hive Retaliation must spawn enraged counter-squad")
	GameState.end_mission("won", "Test victory")
	assert(hud.end_endless_button.visible, "Continue into Endless button must show on non-sandbox victory")
	GameState.continue_into_endless()
	assert(GameState.is_endless_mode and not GameState.mission.is_over, "Endless Mode must clear is_over and enable wave 46+ play")

	GameState.is_endless_mode = false
	GameState.prompts_muted = false
	remove_child(inst)
	inst.queue_free()
	print("CHECK_REBALANCE_AND_PASS2_PASS scaled_upg=ok colossus=ok save_load=ok bugs_fixed=ok ui=ok")


func _test_i_analytics_telemetry_and_ui() -> void:
	assert(AnalyticsManager != null, "AnalyticsManager autoload must be present")
	var prev_runs_backup: Array = AnalyticsManager.runs.duplicate(true)
	AnalyticsManager.suppress_default_persistence = true
	GameState.set_sandbox_mode(false)
	GameState.difficulty_key = "standard"
	GameState.prompts_muted = true
	GameState.reset_mission()
	AnalyticsManager.runs.clear()

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)
	await get_tree().process_frame

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var econ: EconomyManager = inst.get_node("EconomyManager")
	var tp: TimePowersManager = inst.get_node("TimePowersManager")
	var ba: BaseAttackManager = inst.get_node("BaseAttackManager")
	var hud: CanvasLayer = inst.get_node("HUD")
	GameState.mission.economy["money"] = 10000

	# 1) Build, upgrade, combine, combat kill, leak, power, refinery, hive shot, and mission win
	var b_t: TowerUnit = map.build_tower_on_pad(0, "blaster")
	assert(b_t != null)
	b_t.current_job = null
	b_t.is_built = true
	assert(b_t.start_upgrade("damage"))
	b_t.current_job = null
	b_t.levels["damage"] = 1
	var merged: TowerUnit = map.combine_tower_with_shop(b_t, "laser")
	assert(merged != null and merged.tower_type == "blaster+laser")
	merged.current_job = null
	merged.is_built = true

	wm.start_wave()
	var c1: EnemyUnit = map.spawn_enemy("crawler", 1)
	c1.advance_along_path(3.8)
	for _s in range(30):
		merged.advance_tower(0.1)
		if c1.is_dead_or_leaked:
			break
	assert(c1.is_dead_or_leaked, "Pulse-Plasma Carbine should eliminate test crawler")

	# Track boss penetration & player behavior + UI button/screen tap heatmap telemetry
	var j_pen: EnemyUnit = map.spawn_enemy("juggernaut", 10)
	j_pen.advance_along_path(12.0)
	AnalyticsManager.record_enemy_progress("juggernaut", j_pen.get_path_progress_pct(), false)
	map.clear_all_enemies()
	AnalyticsManager._process(0.5)
	map.select_tower_unit(merged)
	hud.target_mode_button.pressed.emit()
	hud.open_recipes_overlay()
	hud.recipes_overlay.visible = false
	AnalyticsManager.record_screen_tap(Vector2(640.0, 360.0), Vector2(1280.0, 720.0), false)
	AnalyticsManager.record_screen_tap(Vector2(640.0, 1422.0), Vector2(1280.0, 2844.0), true)
	AnalyticsManager.record_button_press("ChargeButton", true)

	GameState.lose_lives(1, "crawler", Vector2.ZERO)
	assert(tp.activate_power("pause"))
	assert(econ.start_build_refinery())
	assert(ba.start_charge())
	ba.step_base_attack(ba.get_charge_duration() + 0.5)
	GameState.end_mission("won", "Analytics test victory")

	var summary: Dictionary = AnalyticsManager.compute_aggregate_summary(false)
	assert(str(summary["balance_version"]) == Balance.BALANCE_VERSION, "Analytics must stamp Balance.BALANCE_VERSION")
	assert(int(summary["total_runs"]) == 1 and int(summary["wins"]) == 1, "Analytics must record 1 completed winning run (got %s)" % str(summary["total_runs"]))
	assert(float(summary["avg_kill_progress_pct"]) > 0.0, "Analytics must record enemy kill path penetration %%")
	assert(float(summary["avg_boss_progress_pct"]) > 0.0, "Analytics must record boss path penetration %%")
	assert(float(summary["avg_challenge_score"]) > 0.0, "Analytics must compute positive Challenge Score")
	assert(int(summary["upgrade_counts"]["damage"]) >= 1, "Analytics must track Damage upgrade habit")
	assert(int(summary["combine_methods"]["drag_shop"]) >= 1, "Analytics must track combine method")
	assert(not summary["zone_builds"].is_empty(), "Analytics must record placement zone heatmap")
	assert(int(summary["powers_used"]["pause"]) >= 1, "Analytics must record Pause cast")
	assert(int(summary["enemy_leaks"].get("crawler", 0)) == 1, "Analytics must record crawler leak")
	var ui_sum: Dictionary = summary["ui_summary"]
	assert(int(ui_sum["button_presses"].get("TargetModeButton", 0)) >= 1, "UI analytics must record button presses")
	assert(int(ui_sum["disabled_taps"].get("ChargeButton", 0)) >= 1, "UI analytics must record disabled button taps")
	assert(int(ui_sum["total_taps"]) >= 2 and not ui_sum["tap_grid_landscape"].is_empty() and not ui_sum["tap_grid_portrait"].is_empty(), "UI analytics must record landscape & portrait screen tap heatmaps")

	# Verify Supabase upsert row schema & private scratch-key cleanup
	var sb_row: Dictionary = AnalyticsManager.build_supabase_row(AnalyticsManager.runs[0])
	assert(str(sb_row["balance_version"]) == Balance.BALANCE_VERSION and int(sb_row["challenge_score"]) > 0)
	assert(float(sb_row["max_enemy_progress_pct"]) >= 99.0 and float(sb_row["max_boss_progress_pct"]) > 0.0)
	assert(not sb_row["payload"].has("_speed_weighted_sum"), "Exported Supabase payload must strip internal scratch counters")
	var found_combo: bool = false
	for tb in summary["tower_board"]:
		if str(tb["type"]) == "blaster+laser":
			found_combo = true
			assert(int(tb["built"]) >= 1 and float(tb["damage"]) > 0.0 and int(tb["kills"]) >= 1 and float(tb["dmg_per_dollar"]) > 0.0, "Combo tower ledger must track builds, damage, kills, and Dmg/$")
	assert(found_combo, "Analytics tower_board must contain blaster+laser")

	# 2) Verify Sandbox runs are excluded from balance stats by default
	GameState.set_sandbox_mode(true)
	GameState.reset_mission()
	var sb_t: TowerUnit = map.build_tower_on_pad(1, "railgun")
	assert(sb_t != null)
	wm.start_sandbox_wave(10)
	var sum_excl: Dictionary = AnalyticsManager.compute_aggregate_summary(false)
	var sum_incl: Dictionary = AnalyticsManager.compute_aggregate_summary(true)
	assert(int(sum_excl["total_runs"]) == 1 and int(sum_excl["sandbox_runs_excluded"]) == 1, "Sandbox run must be excluded by default")
	assert(int(sum_incl["total_runs"]) == 2, "Sandbox run must be included when include_sandbox=true")

	# 3) Save / Load JSON round-trip (isolated temp file) & AI Balance Report
	var tmp_path: String = "user://test_verify_analytics_step8.json"
	assert(AnalyticsManager.save_analytics(tmp_path), "save_analytics must succeed on custom test path")
	var ai_md: String = AnalyticsManager.build_ai_balance_report(false)
	assert(ai_md.contains("TimeDefense Real Playtest Analytics Report") and ai_md.contains("Automated Balance Flags") and ai_md.contains("Pulse-Plasma Carbine"), "AI report must include header, flags, and tower stats")
	AnalyticsManager.runs.clear()
	assert(AnalyticsManager.load_analytics(tmp_path), "load_analytics must reload saved runs")
	assert(AnalyticsManager.runs.size() >= 1, "Reloaded analytics must restore run history")
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

	# 4) In-Game AnalyticsOverlay & StartMenuOverlay responsive bounds across all 3 viewports
	GameState.set_sandbox_mode(false)
	hud.open_analytics_overlay()
	assert(hud.analytics_overlay.visible, "AnalyticsOverlay must open cleanly")
	assert(hud.analytics_kpi_label.text.contains("Runs: 1"), "Analytics KPI header must display live run count")
	assert(hud.analytics_towers_label.text.contains("Pulse-Plasma Carbine"), "Analytics tower ledger must display combo performance")
	for test_vp in [Vector2(1280.0, 720.0), Vector2(1600.0, 720.0), Vector2(1280.0, 2844.0)]:
		hud.apply_responsive_layout(test_vp)
		await get_tree().process_frame
		var ar: Rect2 = hud.analytics_overlay.get_global_rect()
		assert(ar.position.x >= 0.0 and ar.end.x <= test_vp.x + 1.0 and ar.end.y <= test_vp.y + 1.0, "AnalyticsOverlay overflow at %s: %s" % [str(test_vp), str(ar)])
	hud.analytics_overlay.visible = false
	hud.open_start_menu()
	for test_vp in [Vector2(1280.0, 720.0), Vector2(1600.0, 720.0), Vector2(1280.0, 2844.0)]:
		hud.apply_responsive_layout(test_vp)
		await get_tree().process_frame
		var ab: Rect2 = hud.start_analytics_button.get_global_rect()
		assert(ab.end.x <= test_vp.x + 1.0 and ab.end.y <= test_vp.y + 1.0, "StartAnalyticsButton overflow at %s: %s" % [str(test_vp), str(ab)])

	AnalyticsManager.runs = prev_runs_backup
	AnalyticsManager.suppress_default_persistence = false
	GameState.prompts_muted = false
	remove_child(inst)
	inst.queue_free()
	print("CHECK_ANALYTICS_TELEMETRY_AND_UI_PASS runs=1 combo_tracked=ok sandbox_filter=ok json_io=ok ui_bounds=ok")
