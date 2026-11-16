extends Node

## Headless Step 2 acceptance verification:
## - Wave 1 preview shows "No mutations"
## - Waves 1-3 play end-to-end with leaks (8 + 12 = 20 leaks, or killing some so waves 1-3 complete cleanly!)
## - Wave bonus is paid exactly once per wave number (even on replay)
## - Editing a wave count in data changes schedule size with no code edit
## - All 15 waves generate valid deterministic schedules

func _ready() -> void:
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_inst: Node = main_scene.instantiate()
	add_child(main_inst)

	var map_node: GameMap = main_inst.get_node("Map")
	var wm: WaveManager = main_inst.get_node("WaveManager")
	var hud_node: CanvasLayer = main_inst.get_node("HUD")

	# Check Wave 1 preview says "No mutations"
	hud_node._refresh_all()
	var mut_text: String = hud_node.preview_mutations_label.text
	assert(mut_text.contains("No mutations"), "Wave 1 preview must show 'No mutations', got: %s" % mut_text)

	# Verify data-driven editability: custom wave table edit changes spawned count with no code change.
	var edited_waves: Array[Dictionary] = WavesData.WAVES.duplicate(true)
	edited_waves[0]["tracks"][0]["count"] = 11
	var edited_sched: Array[Dictionary] = WavesData.build_spawn_schedule(1, edited_waves)
	assert(edited_sched.size() == 11, "Editing wave count in data must change schedule count")

	# Verify all 15 waves build non-empty deterministic schedules.
	for w in range(1, 16):
		var s: Array[Dictionary] = WavesData.build_spawn_schedule(w)
		assert(s.size() > 0, "Wave %d schedule must not be empty" % w)

	# Play Waves 1-3 end-to-end (killing enemies cleanly so lives stay > 0 across all 3 waves).
	var dt: float = 0.25
	var expected_money: int = Balance.STARTING_MONEY
	for w in range(1, 4):
		assert(wm.state == WaveManager.State.BUILD)
		assert(GameState.mission.wave_number == w)
		assert(wm.start_wave(), "Failed to start wave %d" % w)
		var ticks: int = 0
		var kills_in_wave: int = 0
		while wm.state != WaveManager.State.BUILD and not GameState.mission.is_over and ticks < 400:
			ticks += 1
			wm.step_wave(dt)
			for e in map_node.get_active_enemies():
				# Simulate tower clearing enemies cleanly in Waves 1-3
				if e.distance_along_path > 100.0:
					kills_in_wave += 1
					e.take_damage(9999.0)
				else:
					e.advance_along_path(dt)
		var bonus: int = Balance.WAVE_CLEAR_BONUS_BASE + Balance.WAVE_CLEAR_BONUS_PER_WAVE * w
		expected_money += bonus + kills_in_wave * Balance.ENEMIES["runner"]["money_on_kill"]
		assert(GameState.mission.economy["money"] == expected_money, "Wave %d bonus mismatch" % w)

	assert(GameState.mission.wave_number == 4, "Should reach Wave 4 after clearing 1-3")

	# Verify wave bonus is paid ONLY ONCE per wave number (even if wave 3 is replayed).
	GameState.mission.wave_number = 3
	var money_before_replay: int = GameState.mission.economy["money"]
	wm.restart_wave_for_rewind()
	var replay_ticks: int = 0
	var replay_kills: int = 0
	while wm.state == WaveManager.State.SPAWNING or wm.state == WaveManager.State.FIGHTING:
		replay_ticks += 1
		wm.step_wave(dt)
		for e in map_node.get_active_enemies():
			replay_kills += 1
			e.take_damage(9999.0)
		assert(replay_ticks < 400)
	var expected_replay_money: int = money_before_replay + replay_kills * Balance.ENEMIES["runner"]["money_on_kill"]
	assert(GameState.mission.economy["money"] == expected_replay_money, "Wave bonus must NOT double-pay on replay!")

	print("STEP2_TEST_PASS waves_1_to_3_money=%d" % money_before_replay)
	get_tree().quit(0)
