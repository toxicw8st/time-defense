extends Node2D
class_name ProjectileEffect

## Handles hitscan tracer beams (Blaster Piercing, Laser Spire) and lobbed splash shells (Mortar Normal).
## Mortar shells evaluate enemy positions AT LANDING, not at firing.

var is_tracer: bool = false
var tracer_color: Color = Color(0.45, 0.9, 1.0)
var tracer_width: float = 2.5
var damage_type: String = "Normal"
var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var flight_time: float = 0.55
var elapsed: float = 0.0
var damage: float = 22.0
var splash_radius: float = 70.0
var splash_edge_ratio: float = 0.5
var map_ref: GameMap = null
var _exploded: bool = false
var _explosion_flash_timer: float = 0.0


func setup_tracer(p_start: Vector2, p_end: Vector2, p_color: Color = Color(0.45, 0.9, 1.0), p_width: float = 2.5, p_duration: float = 0.08) -> void:
	is_tracer = true
	tracer_color = p_color
	tracer_width = p_width
	start_pos = p_start
	target_pos = p_end
	elapsed = 0.0
	flight_time = maxf(0.04, p_duration)
	position = Vector2.ZERO
	queue_redraw()


func setup_mortar_shell(
	p_start: Vector2,
	p_target: Vector2,
	p_flight_time: float,
	p_damage: float,
	p_splash_radius: float,
	p_edge_ratio: float,
	p_map: GameMap,
	p_damage_type: String = "Normal"
) -> void:
	is_tracer = false
	damage_type = p_damage_type
	start_pos = p_start
	target_pos = p_target
	flight_time = maxf(0.05, p_flight_time)
	elapsed = 0.0
	damage = p_damage
	splash_radius = p_splash_radius
	splash_edge_ratio = p_edge_ratio
	map_ref = p_map
	position = p_start
	queue_redraw()


func _process(delta: float) -> void:
	advance_projectile(GameState.get_sim_delta(delta))


func advance_projectile(delta: float) -> void:
	if GameState.mission.is_over or delta <= 0.0:
		return
	if is_tracer:
		elapsed += delta
		if elapsed >= flight_time:
			queue_free()
		else:
			queue_redraw()
		return

	if _exploded:
		_explosion_flash_timer -= delta
		if _explosion_flash_timer <= 0.0:
			queue_free()
		else:
			queue_redraw()
		return

	elapsed += delta
	var t: float = clampf(elapsed / flight_time, 0.0, 1.0)
	var linear_pos: Vector2 = start_pos.lerp(target_pos, t)
	var arc_height: float = 42.0 * 4.0 * t * (1.0 - t)
	position = linear_pos + Vector2(0.0, -arc_height)
	queue_redraw()

	if t >= 1.0:
		_detonate()


func _detonate() -> void:
	_exploded = true
	_explosion_flash_timer = 0.16
	position = target_pos
	if map_ref != null:
		for enemy in map_ref.get_active_enemies():
			var d: float = enemy.position.distance_to(target_pos)
			if d <= splash_radius:
				var falloff: float = lerpf(1.0, splash_edge_ratio, d / maxf(1.0, splash_radius))
				enemy.take_damage(damage * falloff, damage_type)
	queue_redraw()


func _draw() -> void:
	if is_tracer:
		var alpha: float = clampf(1.0 - (elapsed / flight_time), 0.0, 1.0)
		var col := tracer_color
		col.a = alpha
		draw_line(start_pos, target_pos, col, tracer_width)
		return

	if _exploded:
		var ratio: float = clampf(_explosion_flash_timer / 0.16, 0.0, 1.0)
		draw_circle(Vector2.ZERO, splash_radius * (1.0 - ratio * 0.25), Color(1.0, 0.58, 0.18, 0.35 * ratio))
		draw_arc(Vector2.ZERO, splash_radius, 0.0, TAU, 32, Color(1.0, 0.72, 0.25, 0.85 * ratio), 2.0)
	else:
		draw_circle(Vector2.ZERO, 5.5, Color(1.0, 0.75, 0.28))
		draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 16, Color(0.2, 0.1, 0.05), 1.2)
