extends Node

## Headless Step 1 acceptance verification:
## - Path length ~1900 px; 14 build pads none overlapping the path
## - 20 Runners spawn and walk strictly on the Path2D curve at exact 50.0 px/s
## - All 20 leak in exact spawn order (ID 1..20)
## - Lives go 20 -> 0 and Lose screen becomes visible

var leaked_ids: Array[int] = []
var off_path_errors: int = 0
var speed_errors: int = 0
var main_inst: Node = null
var map_node: GameMap = null
var hud_node: CanvasLayer = null


func _ready() -> void:
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	main_inst = main_scene.instantiate()
	add_child(main_inst)

	map_node = main_inst.get_node("Map")
	hud_node = main_inst.get_node("HUD")

	# Verify path length (~1900 px) and 14 non-overlapping build pads.
	var path_len: float = map_node.get_path_length()
	assert(path_len >= 1800.0 and path_len <= 2000.0, "Path length should be ~1900 px, got %.1f" % path_len)
	assert(GameMap.BUILD_PAD_POSITIONS.size() == 14, "Expected 14 build pads")

	var curve: Curve2D = map_node.enemy_path.curve
	for pad_pos in GameMap.BUILD_PAD_POSITIONS:
		var closest: Vector2 = curve.get_closest_point(pad_pos)
		assert(pad_pos.distance_to(closest) >= 37.0, "Pad too close to path: %.1f" % pad_pos.distance_to(closest))

	# Spawn 20 Runners staggered along the path and step deterministically.
	var runners: Array[EnemyUnit] = []
	for i in range(20):
		var e: EnemyUnit = map_node.spawn_enemy("runner", 1)
		e.set_process(false)
		e.leaked.connect(func(unit: EnemyUnit) -> void: leaked_ids.append(unit.enemy_id))
		runners.append(e)

	var dt: float = 0.5
	var spawned_active: int = 0
	var spawn_accum: float = 0.0
	var steps: int = 0

	while not GameState.mission.is_over and steps < 400:
		steps += 1
		if spawned_active < runners.size():
			spawn_accum += dt
			if spawn_accum >= 1.0 or spawned_active == 0:
				spawn_accum = 0.0
				spawned_active += 1

		for idx in range(spawned_active):
			var u: EnemyUnit = runners[idx]
			if is_instance_valid(u) and not u.is_dead_or_leaked:
				var d_before: float = u.distance_along_path
				u.advance_along_path(dt)
				if not u.is_dead_or_leaked:
					var expected_d: float = d_before + 50.0 * dt
					if absf(u.distance_along_path - expected_d) > 0.01:
						speed_errors += 1
					var on_curve: Vector2 = curve.get_closest_point(u.position)
					if u.position.distance_to(on_curve) > 0.5:
						off_path_errors += 1

	assert(off_path_errors == 0, "Enemy left path %d times" % off_path_errors)
	assert(speed_errors == 0, "Speed mismatch %d times" % speed_errors)
	assert(leaked_ids.size() == 20, "Expected 20 leaks, got %d" % leaked_ids.size())
	for i in range(20):
		assert(leaked_ids[i] == i + 1, "Leaked out of order at %d: %d" % [i, leaked_ids[i]])
	assert(GameState.mission.lives == 0, "Lives must reach 0")
	assert(GameState.mission.is_over and GameState.mission.outcome == "lost")
	assert(hud_node.get_node("EndOverlay").visible, "Lose screen must be visible")

	print("STEP1_TEST_PASS path_len=%.1f leaks=%d" % [path_len, leaked_ids.size()])
	get_tree().quit(0)
