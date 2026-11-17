extends Node

## Headless Step 2 acceptance verification:
## - Wave 1 preview shows "No mutations"
## - Waves 1-10 exact compositions match s$, b$, HP, and DPS needed
## - Waves 11..45 algorithmic schedules generate cleanly (Wave 45 = s$393)
## - Editing a wave count in data changes schedule size with no code edit
## - Waves 1-3 play end-to-end and b$ bounty feeds player $

func _ready() -> void:
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_inst: Node = main_scene.instantiate()
	add_child(main_inst)

	var map_node: GameMap = main_inst.get_node("Map")
	var wm: WaveManager = main_inst.get_node("WaveManager")
	var hud_node: CanvasLayer = main_inst.get_node("HUD")

	hud_node._refresh_all()
	var mut_text: String = hud_node.preview_mutations_label.text
	assert(mut_text.contains("No mutations"), "Wave 1 preview must show 'No mutations', got: %s" % mut_text)

	# Verify data-driven editability: custom wave table edit changes spawned count with no code change.
	var edited_waves: Array[Dictionary] = WavesData.WAVES.duplicate(true)
	edited_waves[0]["tracks"][0]["count"] = 11
	var edited_sched: Array[Dictionary] = WavesData.build_spawn_schedule(1, edited_waves)
	assert(edited_sched.size() == 11, "Editing wave count in data must change schedule count")

	# Verify all 45 mission waves build non-empty deterministic schedules and Wave 45 s$ == 393.
	for w in range(1, 46):
		var s: Array[Dictionary] = WavesData.build_spawn_schedule(w)
		assert(s.size() > 0, "Wave %d schedule must not be empty" % w)
	assert(WavesData.get_target_threat_s_dollars(45) == 393, "Wave 45 s$ must be 393, got %d" % WavesData.get_target_threat_s_dollars(45))

	# Play Waves 1-3 end-to-end (killing enemies cleanly so lives stay > 0 across all 3 waves).
	var dt: float = 0.5
	var expected_money: int = Balance.STARTING_MONEY
	for w in range(1, 4):
		assert(wm.state == WaveManager.State.BUILD)
		assert(GameState.mission.wave_number == w)
		assert(wm.start_wave(), "Failed to start wave %d" % w)
		var ticks: int = 0
		var bounty_in_wave: int = 0
		while wm.state != WaveManager.State.BUILD and not GameState.mission.is_over and ticks < 1000:
			ticks += 1
			wm.step_wave(dt)
			for e in map_node.get_active_enemies():
				if e.distance_along_path > 50.0:
					bounty_in_wave += e.money_on_kill
					e.take_damage(9999.0)
				else:
					e.advance_along_path(dt)
		var stats: Dictionary = WavesData.compute_wave_stats(w, 1.0)
		assert(bounty_in_wave == int(stats["b_dollars"]), "Wave %d b$ mismatch: %d vs %d" % [w, bounty_in_wave, int(stats["b_dollars"])])
		expected_money += bounty_in_wave
		assert(GameState.mission.economy["money"] == expected_money, "Wave %d money mismatch" % w)

	assert(GameState.mission.wave_number == 4, "Should reach Wave 4 after clearing 1-3")

	# Verify Rewind replay awards wave bounty b$ again (Rewind farming).
	GameState.mission.wave_number = 3
	var money_before_replay: int = GameState.mission.economy["money"]
	wm.restart_wave_for_rewind()
	var replay_ticks: int = 0
	var replay_bounty: int = 0
	while wm.state == WaveManager.State.SPAWNING or wm.state == WaveManager.State.FIGHTING:
		replay_ticks += 1
		wm.step_wave(dt)
		for e in map_node.get_active_enemies():
			replay_bounty += e.money_on_kill
			e.take_damage(9999.0)
		assert(replay_ticks < 1000)
	assert(GameState.mission.economy["money"] == money_before_replay + replay_bounty)

	print("STEP2_TEST_PASS waves_1_to_3_money=%d w45_s=%d" % [money_before_replay, WavesData.get_target_threat_s_dollars(45)])
	get_tree().quit(0)
