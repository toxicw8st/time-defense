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
	_explosion_flash_timer = 0.24
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
		var outer_col := tracer_color
		outer_col.a = alpha * 0.30
		var mid_col := tracer_color
		mid_col.a = alpha * 0.92
		var core_col := Color(0.96, 0.99, 1.0, alpha * 0.95)

		# 3-layer glowing beam (outer bloom, saturated beam, hot white core)
		draw_line(start_pos, target_pos, outer_col, tracer_width * 3.0)
		draw_line(start_pos, target_pos, mid_col, tracer_width * 1.35)
		draw_line(start_pos, target_pos, core_col, maxf(1.2, tracer_width * 0.5))

		# Muzzle flare & impact burst
		draw_circle(start_pos, tracer_width * 1.9, outer_col)
		draw_circle(start_pos, tracer_width * 0.9, core_col)
		draw_circle(target_pos, tracer_width * 2.4 * (1.15 - alpha * 0.3), outer_col)
		draw_circle(target_pos, tracer_width * 1.1, core_col)

		var dir: Vector2 = (target_pos - start_pos)
		var dist: float = dir.length()
		if dist > 1.0:
			var fwd: Vector2 = dir / dist
			var perp := Vector2(-fwd.y, fwd.x)
			# Railgun / Chrono shockwave rings along the beam
			if tracer_width >= 4.0:
				var ring_count: int = clampi(int(dist / 55.0), 2, 6)
				for i in range(1, ring_count + 1):
					var p: Vector2 = start_pos.lerp(target_pos, float(i) / float(ring_count + 1))
					var r_size: float = (5.0 + float(i % 2) * 2.5) * (1.2 - alpha * 0.4)
					draw_arc(p, r_size, 0.0, TAU, 18, Color(1.0, 0.88, 0.52, alpha * 0.75), 1.6)
				draw_arc(target_pos, 14.0 * (1.3 - alpha * 0.5), 0.0, TAU, 24, mid_col, 2.0)
			elif tracer_width >= 2.8:
				# Chrono Slow temporal ripple ring at impact
				var ripple_r: float = lerpf(4.0, 15.0, 1.0 - alpha)
				draw_arc(target_pos, ripple_r, 0.0, TAU, 20, mid_col, 1.8)
			else:
				# Cross-spark at impact
				var sp: float = 5.5 * alpha
				draw_line(target_pos - perp * sp, target_pos + perp * sp, core_col, 1.3)
		return

	if _exploded:
		var ratio: float = clampf(_explosion_flash_timer / 0.24, 0.0, 1.0)
		var expand: float = 1.0 - ratio
		# Multi-layer blast shockwave
		draw_circle(Vector2.ZERO, splash_radius * (0.45 + expand * 0.55), Color(1.0, 0.42, 0.12, 0.24 * ratio))
		draw_circle(Vector2.ZERO, splash_radius * (0.25 + expand * 0.35), Color(1.0, 0.82, 0.32, 0.42 * ratio))
		draw_circle(Vector2.ZERO, splash_radius * 0.22 * ratio, Color(1.0, 0.98, 0.85, 0.85 * ratio))
		draw_arc(Vector2.ZERO, splash_radius * (0.75 + expand * 0.25), 0.0, TAU, 36, Color(1.0, 0.72, 0.24, 0.92 * ratio), 2.5)
		draw_arc(Vector2.ZERO, splash_radius * expand, 0.0, TAU, 28, Color(1.0, 0.45, 0.18, 0.65 * ratio), 1.5)
	else:
		var t: float = clampf(elapsed / maxf(0.05, flight_time), 0.0, 1.0)
		var linear_pos: Vector2 = start_pos.lerp(target_pos, t)
		var ground_offset: Vector2 = linear_pos - position
		var target_offset: Vector2 = target_pos - position

		# Target warning reticle on ground + ground shadow
		draw_arc(target_offset, 12.0, 0.0, TAU, 20, Color(1.0, 0.48, 0.20, 0.32), 1.2)
		draw_circle(ground_offset, lerpf(5.0, 3.0, sin(t * PI)), Color(0.0, 0.0, 0.0, 0.35))

		# Smoke & ember trail along the parabolic arc
		for i in range(1, 5):
			var prev_t: float = maxf(0.0, t - float(i) * 0.055)
			var prev_lin: Vector2 = start_pos.lerp(target_pos, prev_t)
			var prev_arc: float = 42.0 * 4.0 * prev_t * (1.0 - prev_t)
			var trail_pos: Vector2 = (prev_lin + Vector2(0.0, -prev_arc)) - position
			var trail_a: float = (1.0 - float(i) * 0.2) * 0.55
			draw_circle(trail_pos, 3.8 - float(i) * 0.5, Color(0.95, 0.52, 0.18, trail_a))

		# Armored mortar shell body + glowing warhead core
		draw_circle(Vector2.ZERO, 6.2, Color(0.24, 0.28, 0.34))
		draw_circle(Vector2.ZERO, 4.4, Color(1.0, 0.68, 0.22))
		draw_circle(Vector2(-1.2, -1.2), 2.0, Color(1.0, 0.96, 0.78))
		draw_arc(Vector2.ZERO, 6.2, 0.0, TAU, 18, Color(1.0, 0.82, 0.35), 1.4)
