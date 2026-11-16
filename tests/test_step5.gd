extends Node

## Headless Step 5 acceptance verification:
## - Ignoring surge timer fires surges at 45 s intervals with stacking penalties (95%, 90%, 86%)
## - Warning states fire at 15 s (amber) and 7 s (red) before every surge
## - Test power button resets timer and prevents surge
## - Surge pauses in BUILD phase and when manipulator_upgrading_remaining > 0
## - Reset mission zeroes surges

var warning_events: Array[int] = []
var surge_events: Array[int] = []


func _ready() -> void:
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var wm: WaveManager = inst.get_node("WaveManager")
	var surge: SurgeManager = inst.get_node("SurgeManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	surge.warning_state_changed.connect(func(lvl: int) -> void:
		if lvl > 0:
			warning_events.append(lvl)
	)
	GameState.surge_triggered.connect(func(c: int) -> void: surge_events.append(c))

	# Must be paused during BUILD phase
	assert(surge.is_surge_paused(), "Surge must pause during BUILD phase")
	surge.step_surge(100.0)
	assert(GameState.mission.surge_count == 0, "Paused surge must not fire")

	# Start wave so surge runs
	wm.start_wave()
	assert(not surge.is_surge_paused())

	# Step 135 s (3 full 45 s windows) in 0.5 s increments
	for _i in range(270):
		surge.step_surge(0.5)

	assert(surge_events == [1, 2, 3], "Expected 3 surges at 45 s intervals, got %s" % str(surge_events))
	assert(warning_events == [1, 2, 1, 2, 1, 2], "Expected amber(1) & red(2) warnings before every surge, got %s" % str(warning_events))

	hud._refresh_surge_bar()
	assert(hud.surge_penalty_label.text.contains("86%"), "3 surges must display 86%% speed, got: %s" % hud.surge_penalty_label.text)

	# Verify time_power_used signal resets timer and prevents surge
	surge.step_surge(40.0) # 5 s left
	GameState.time_power_used.emit("test")
	assert(is_equal_approx(GameState.mission.surge_timer_seconds, 45.0), "Using power must reset surge timer")
	surge.step_surge(40.0)
	assert(GameState.mission.surge_count == 3, "Prevented surge via test button")

	# Verify manipulator upgrade pauses surge timer
	GameState.mission.manipulator_upgrading_remaining = 10.0
	assert(surge.is_surge_paused())
	var before_pause: float = GameState.mission.surge_timer_seconds
	surge.step_surge(20.0)
	assert(is_equal_approx(GameState.mission.surge_timer_seconds, before_pause))

	# Verify reset clears surges
	GameState.reset_mission()
	assert(GameState.mission.surge_count == 0 and is_equal_approx(GameState.mission.surge_timer_seconds, 45.0))

	print("STEP5_TEST_PASS surges=%s warnings=%s" % [str(surge_events), str(warning_events)])
	get_tree().quit(0)
