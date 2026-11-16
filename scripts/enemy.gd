extends Node2D
class_name EnemyUnit

signal leaked(enemy: EnemyUnit)
signal died(enemy: EnemyUnit)

var enemy_id: int = 0
var enemy_type: String = "runner"
var spawn_wave: int = 1
var max_hp: float = 40.0
var hp: float = 40.0
var base_speed: float = 50.0
var leak_cost: int = 1
var money_on_kill: int = 6
var research_on_kill: int = 1

var path_curve: Curve2D = null
var path_length: float = 0.0
var distance_along_path: float = 0.0
var last_tangent: Vector2 = Vector2.RIGHT
var is_dead_or_leaked: bool = false
var swift_stacks_at_spawn: int = 0
var speed_multiplier_at_spawn: float = 1.0


func setup(p_id: int, p_type: String, p_wave: int, p_curve: Curve2D) -> void:
	enemy_id = p_id
	enemy_type = p_type
	spawn_wave = p_wave
	path_curve = p_curve
	path_length = p_curve.get_baked_length()

	var cfg: Dictionary = Balance.ENEMIES[p_type]
	base_speed = cfg["speed"]
	leak_cost = cfg["leak_cost"]
	money_on_kill = cfg["money_on_kill"]
	research_on_kill = cfg["research_on_kill"]
	swift_stacks_at_spawn = GameState.mission.mutations.get("swift_stacks", 0)
	speed_multiplier_at_spawn = pow(1.0 + Balance.TIME_POWERS["haste"]["speed_bonus_per_stack"], swift_stacks_at_spawn)
	max_hp = float(GameState.get_enemy_wave_hp(p_type, p_wave))
	hp = max_hp
	distance_along_path = 0.0
	is_dead_or_leaked = false
	_sync_transform_to_path()
	queue_redraw()


func advance_along_path(delta: float) -> void:
	if is_dead_or_leaked or path_curve == null or GameState.mission.is_over:
		return
	if GameState.is_enemies_frozen:
		return
	var eff_speed: float = base_speed * speed_multiplier_at_spawn
	if eff_speed <= 0.0:
		return
	distance_along_path += eff_speed * delta
	if distance_along_path >= path_length:
		distance_along_path = path_length
		_sync_transform_to_path()
		is_dead_or_leaked = true
		leaked.emit(self)
		queue_free()
		return
	_sync_transform_to_path()


func _process(delta: float) -> void:
	advance_along_path(delta)


func _sync_transform_to_path() -> void:
	if path_curve == null:
		return
	var clamped_d: float = clampf(distance_along_path, 0.0, path_length)
	position = path_curve.sample_baked(clamped_d, false)
	var ahead_d: float = minf(path_length, clamped_d + 4.0)
	var behind_d: float = maxf(0.0, clamped_d - 4.0)
	var delta_vec: Vector2 = path_curve.sample_baked(ahead_d, false) - path_curve.sample_baked(behind_d, false)
	if delta_vec.length_squared() > 0.001:
		last_tangent = delta_vec.normalized()


func take_damage(amount: float) -> void:
	if is_dead_or_leaked:
		return
	var dmg: float = amount
	if GameState.is_enemies_frozen:
		var thaw_stacks: int = GameState.mission.mutations.get("thaw_stacks", 0)
		var reduction: float = minf(
			Balance.TIME_POWERS["pause"]["frozen_damage_reduction_cap"],
			Balance.TIME_POWERS["pause"]["frozen_damage_reduction_per_stack"] * float(thaw_stacks)
		)
		dmg *= (1.0 - reduction)
	hp -= dmg
	if hp <= 0.0:
		hp = 0.0
		is_dead_or_leaked = true
		died.emit(self)
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var radius: float = 10.0 if enemy_type == "runner" else 15.0
	var fill_color: Color = Color(0.92, 0.25, 0.25) if enemy_type == "runner" else Color(0.75, 0.16, 0.35)
	if GameState.is_enemies_frozen:
		var thaw_stacks: int = GameState.mission.mutations.get("thaw_stacks", 0)
		var frost_strength: float = clampf(0.35 + 0.12 * float(thaw_stacks), 0.35, 0.85)
		fill_color = fill_color.lerp(Color(0.45, 0.85, 1.0), frost_strength)

	# Armoured mutation visual cue: thicker bright shell outline
	var armoured_stacks: int = GameState.mission.mutations.get("armoured_stacks", 0)
	if armoured_stacks > 0:
		var shell_width: float = 2.0 + minf(4.0, float(armoured_stacks) * 1.2)
		draw_arc(Vector2.ZERO, radius + shell_width * 0.5, 0.0, TAU, 24, Color(0.95, 0.82, 0.35), shell_width)

	# Swift mutation visual cue: speed lines trailing opposite tangent
	if swift_stacks_at_spawn > 0:
		var back_dir: Vector2 = -last_tangent
		var perp: Vector2 = Vector2(-back_dir.y, back_dir.x)
		for i in range(min(3, swift_stacks_at_spawn)):
			var offset_perp: float = (float(i) - 1.0) * 5.0
			var start_p: Vector2 = perp * offset_perp + back_dir * (radius + 2.0)
			var end_p: Vector2 = start_p + back_dir * (8.0 + float(swift_stacks_at_spawn) * 2.0)
			draw_line(start_p, end_p, Color(0.4, 0.95, 0.75, 0.85), 2.0)

	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.12, 0.04, 0.04), 1.5)

	# Mini HP bar
	var bar_w: float = radius * 2.4
	var bar_h: float = 4.0
	var bar_pos := Vector2(-bar_w * 0.5, -radius - 9.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.12, 0.9))
	var ratio: float = clampf(hp / max(1.0, max_hp), 0.0, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), Color(0.3, 0.9, 0.4))
