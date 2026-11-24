extends Node2D
class_name ProjectileEffect

## Handles hitscan tracer beams (Blaster Piercing, Laser Spire) and lobbed splash shells (Mortar Normal).
## Mortar shells evaluate enemy positions AT LANDING, not at firing.

var is_tracer: bool = false
var is_bubble: bool = false
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

# Mortar combo extras
var blast_color: Color = Color(1.0, 0.52, 0.16)
var secondary_damage: float = 0.0
var secondary_damage_type: String = "Normal"
var mirv_subshells: int = 0
var shell_slow_pct: float = 0.0
var shell_slow_dur: float = 0.0
var shell_decay_flat: float = 0.0
var shell_spawn_bubble: Dictionary = {}

# Chrono status bubble fields
var bubble_radius: float = 42.0
var bubble_slow_pct: float = 0.30
var bubble_slow_linger: float = 0.45
var bubble_decay_flat: float = 0.0
var bubble_decay_ticks: int = 2
var bubble_burn_dps: float = 0.0
var bubble_burn_type: String = "Laser"
var bubble_color: Color = Color(0.64, 0.48, 1.0)
var _bubble_pulse_accum: float = 0.0


func setup_tracer(p_start: Vector2, p_end: Vector2, p_color: Color = Color(0.45, 0.9, 1.0), p_width: float = 2.5, p_duration: float = 0.08) -> void:
	is_tracer = true
	is_bubble = false
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
	is_bubble = false
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


func configure_mortar_extras(
	p_blast_color: Color,
	p_secondary_damage: float = 0.0,
	p_secondary_type: String = "Normal",
	p_mirv_subshells: int = 0,
	p_slow_pct: float = 0.0,
	p_slow_dur: float = 0.0,
	p_decay_flat: float = 0.0,
	p_spawn_bubble: Dictionary = {}
) -> void:
	blast_color = p_blast_color
	secondary_damage = p_secondary_damage
	secondary_damage_type = p_secondary_type
	mirv_subshells = p_mirv_subshells
	shell_slow_pct = p_slow_pct
	shell_slow_dur = p_slow_dur
	shell_decay_flat = p_decay_flat
	shell_spawn_bubble = p_spawn_bubble.duplicate()


func setup_chrono_bubble(
	p_center: Vector2,
	p_duration: float,
	p_radius: float,
	p_slow_pct: float,
	p_decay_flat: float,
	p_decay_ticks: int,
	p_map: GameMap,
	p_burn_dps: float = 0.0,
	p_burn_type: String = "Laser",
	p_color: Color = Color(0.64, 0.48, 1.0),
	p_slow_linger: float = 0.45
) -> void:
	is_tracer = false
	is_bubble = true
	start_pos = p_center
	target_pos = p_center
	flight_time = maxf(0.25, p_duration)
	elapsed = 0.0
	bubble_radius = p_radius
	bubble_slow_pct = p_slow_pct
	bubble_slow_linger = p_slow_linger
	bubble_decay_flat = p_decay_flat
	bubble_decay_ticks = p_decay_ticks
	bubble_burn_dps = p_burn_dps
	bubble_burn_type = p_burn_type
	bubble_color = p_color
	map_ref = p_map
	_bubble_pulse_accum = 0.0
	position = p_center
	_apply_bubble_pulse(0.0)
	queue_redraw()


func _process(delta: float) -> void:
	advance_projectile(GameState.get_sim_delta(delta))


func advance_projectile(delta: float) -> void:
	if GameState.mission.is_over or delta <= 0.0:
		return
	if is_bubble:
		elapsed += delta
		_bubble_pulse_accum += delta
		if _bubble_pulse_accum >= 0.15:
			_apply_bubble_pulse(_bubble_pulse_accum)
			_bubble_pulse_accum = 0.0
		if elapsed >= flight_time:
			queue_free()
		else:
			queue_redraw()
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


func _apply_bubble_pulse(pulse_dt: float) -> void:
	if map_ref == null:
		return
	for enemy in map_ref.get_active_enemies():
		if not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if enemy.position.distance_to(position) <= bubble_radius:
			enemy.apply_bubble_aura(bubble_slow_pct, bubble_slow_linger, bubble_decay_flat, bubble_decay_ticks)
			if bubble_burn_dps > 0.0 and pulse_dt > 0.0:
				enemy.take_damage(bubble_burn_dps * pulse_dt, bubble_burn_type)


func _detonate() -> void:
	_exploded = true
	_explosion_flash_timer = 0.24
	position = target_pos
	if map_ref != null:
		for enemy in map_ref.get_active_enemies():
			var d: float = enemy.position.distance_to(target_pos)
			if d <= splash_radius:
				var falloff: float = lerpf(1.0, splash_edge_ratio, d / maxf(1.0, splash_radius))
				if damage > 0.0:
					enemy.take_damage(damage * falloff, damage_type)
				if secondary_damage > 0.0 and enemy.is_alive():
					enemy.take_damage(secondary_damage * falloff, secondary_damage_type)
				if shell_slow_pct > 0.0 and enemy.is_alive():
					enemy.apply_time_hit(shell_slow_pct, shell_slow_dur, shell_decay_flat, 2)
		if mirv_subshells > 0:
			for i in range(mirv_subshells):
				var angle: float = (TAU / float(mirv_subshells)) * float(i) + 0.35
				var sub_target: Vector2 = target_pos + Vector2.from_angle(angle) * maxf(24.0, splash_radius * 0.55)
				var sub_proj: ProjectileEffect = map_ref.spawn_projectile()
				sub_proj.setup_mortar_shell(
					target_pos,
					sub_target,
					0.24,
					damage * 0.36,
					maxf(32.0, splash_radius * 0.55),
					0.55,
					map_ref,
					damage_type
				)
				sub_proj.configure_mortar_extras(blast_color)
		if not shell_spawn_bubble.is_empty():
			var bubble_proj: ProjectileEffect = map_ref.spawn_projectile()
			bubble_proj.setup_chrono_bubble(
				target_pos,
				float(shell_spawn_bubble.get("duration", 3.5)),
				float(shell_spawn_bubble.get("radius", splash_radius)),
				float(shell_spawn_bubble.get("slow_pct", 0.30)),
				float(shell_spawn_bubble.get("decay_flat", 0.0)),
				int(shell_spawn_bubble.get("decay_ticks", 2)),
				map_ref,
				float(shell_spawn_bubble.get("burn_dps", 0.0)),
				String(shell_spawn_bubble.get("burn_type", "Laser")),
				shell_spawn_bubble.get("color", Color(0.64, 0.48, 1.0)),
				float(shell_spawn_bubble.get("slow_linger", 0.45))
			)
	queue_redraw()


func _draw() -> void:
	if is_bubble:
		var life_ratio: float = clampf(elapsed / maxf(0.2, flight_time), 0.0, 1.0)
		var fade_in: float = clampf(elapsed / 0.14, 0.0, 1.0)
		var fade_out: float = clampf((flight_time - elapsed) / 0.45, 0.0, 1.0)
		var alpha: float = minf(fade_in, fade_out)
		var r: float = bubble_radius * (0.45 + 0.55 * fade_in)
		var fill_col := Color(bubble_color.r, bubble_color.g, bubble_color.b, 0.16 * alpha)
		var mid_col := Color(bubble_color.r, bubble_color.g, bubble_color.b, 0.48 * alpha)
		var rim_col := Color(lerpf(bubble_color.r, 1.0, 0.35), lerpf(bubble_color.g, 1.0, 0.35), lerpf(bubble_color.b, 1.0, 0.35), 0.88 * alpha)
		draw_circle(Vector2.ZERO, r, fill_col)
		draw_circle(Vector2.ZERO, r * 0.58, Color(bubble_color.r, bubble_color.g, bubble_color.b, 0.10 * alpha))
		# Expanding inner chrono wave ring
		var pulse_t: float = fmod(elapsed * 1.15, 1.0)
		draw_arc(Vector2.ZERO, lerpf(r * 0.22, r * 0.94, pulse_t), 0.0, TAU, 32, Color(rim_col.r, rim_col.g, rim_col.b, (1.0 - pulse_t) * 0.52 * alpha), 1.6)
		# Rotating dual containment arcs around bubble boundary
		var rot: float = elapsed * 1.4
		draw_arc(Vector2.ZERO, r, rot, rot + PI * 0.72, 24, rim_col, 2.2)
		draw_arc(Vector2.ZERO, r, rot + PI, rot + PI * 1.72, 24, rim_col, 2.2)
		draw_arc(Vector2.ZERO, r * 0.86, -rot * 0.8, -rot * 0.8 + TAU, 32, mid_col, 1.1)
		# Perimeter temporal tick nodes
		for i in range(6):
			var a: float = rot * 0.6 + (TAU / 6.0) * float(i)
			draw_circle(Vector2.from_angle(a) * r, 2.2, rim_col)
		# Optional thermal/void inner distortion if combo bubble also burns
		if bubble_burn_dps > 0.0:
			var burn_col := Color(1.0, 0.52, 0.20, 0.45 * alpha) if bubble_burn_type == "Laser" else Color(0.95, 0.35, 1.0, 0.45 * alpha)
			draw_arc(Vector2.ZERO, r * 0.48, -rot * 1.5, -rot * 1.5 + PI * 1.4, 22, burn_col, 2.0)
		return

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
		# Multi-layer blast shockwave tinted by payload type
		draw_circle(Vector2.ZERO, splash_radius * (0.45 + expand * 0.55), Color(blast_color.r, blast_color.g, blast_color.b, 0.26 * ratio))
		draw_circle(Vector2.ZERO, splash_radius * (0.25 + expand * 0.35), Color(lerpf(blast_color.r, 1.0, 0.45), lerpf(blast_color.g, 1.0, 0.45), lerpf(blast_color.b, 1.0, 0.25), 0.44 * ratio))
		draw_circle(Vector2.ZERO, splash_radius * 0.22 * ratio, Color(1.0, 0.98, 0.85, 0.85 * ratio))
		draw_arc(Vector2.ZERO, splash_radius * (0.75 + expand * 0.25), 0.0, TAU, 36, Color(lerpf(blast_color.r, 1.0, 0.3), lerpf(blast_color.g, 1.0, 0.3), lerpf(blast_color.b, 1.0, 0.3), 0.92 * ratio), 2.5)
		draw_arc(Vector2.ZERO, splash_radius * expand, 0.0, TAU, 28, Color(blast_color.r, blast_color.g, blast_color.b, 0.65 * ratio), 1.5)
	else:
		var t: float = clampf(elapsed / maxf(0.05, flight_time), 0.0, 1.0)
		var linear_pos: Vector2 = start_pos.lerp(target_pos, t)
		var ground_offset: Vector2 = linear_pos - position
		var target_offset: Vector2 = target_pos - position

		# Target warning reticle on ground + ground shadow
		draw_arc(target_offset, 12.0, 0.0, TAU, 20, Color(blast_color.r, blast_color.g, blast_color.b, 0.35), 1.2)
		draw_circle(ground_offset, lerpf(5.0, 3.0, sin(t * PI)), Color(0.0, 0.0, 0.0, 0.35))

		# Smoke & ember trail along the parabolic arc
		for i in range(1, 5):
			var prev_t: float = maxf(0.0, t - float(i) * 0.055)
			var prev_lin: Vector2 = start_pos.lerp(target_pos, prev_t)
			var prev_arc: float = 42.0 * 4.0 * prev_t * (1.0 - prev_t)
			var trail_pos: Vector2 = (prev_lin + Vector2(0.0, -prev_arc)) - position
			var trail_a: float = (1.0 - float(i) * 0.2) * 0.55
			draw_circle(trail_pos, 3.8 - float(i) * 0.5, Color(blast_color.r, blast_color.g, blast_color.b, trail_a))

		# Armored mortar shell body + glowing warhead core
		draw_circle(Vector2.ZERO, 6.2, Color(0.24, 0.28, 0.34))
		draw_circle(Vector2.ZERO, 4.4, blast_color)
		draw_circle(Vector2(-1.2, -1.2), 2.0, Color(1.0, 0.96, 0.78))
		draw_arc(Vector2.ZERO, 6.2, 0.0, TAU, 18, Color(lerpf(blast_color.r, 1.0, 0.4), lerpf(blast_color.g, 1.0, 0.4), lerpf(blast_color.b, 1.0, 0.4)), 1.4)
