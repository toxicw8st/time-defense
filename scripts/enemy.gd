extends Node2D
class_name EnemyUnit

## Enemy unit on the Path2D curve with fixed base HP (scaled only by mutations) and 3x3 Damage Matrix armour tags.
## Notation:
## s$ = spawn_cost_s (threat cost to spawn)
## b$ = bounty_b / money_on_kill (player $ earned on kill)

signal leaked(enemy: EnemyUnit)
signal died(enemy: EnemyUnit)

var enemy_id: int = 0
var enemy_type: String = "crawler"
var spawn_wave: int = 1
var spawn_cost_s: int = 1 # s$
var bounty_b: int = 4     # b$
var max_hp: float = 50.0
var hp: float = 50.0
var base_speed: float = 28.5
var leak_cost: int = 1
var money_on_kill: int = 4
var research_on_kill: int = 1
var armour_label: String = "Standard"
var armour_tags: Array = ["Standard"]

var path_curve: Curve2D = null
var path_length: float = 0.0
var distance_along_path: float = 0.0
var last_tangent: Vector2 = Vector2.RIGHT
var is_dead_or_leaked: bool = false
var swift_stacks_at_spawn: int = 0
var speed_multiplier_at_spawn: float = 1.0
var slow_pct: float = 0.0
var slow_remaining: float = 0.0
var decay_base_pct: float = 0.0
var decay_ticks_remaining: int = 0
var decay_tick_timer: float = 0.0
var anim_time: float = 0.0
var hit_flash_timer: float = 0.0


func setup(p_id: int, p_type: String, p_wave: int, p_curve: Curve2D) -> void:
	enemy_id = p_id
	enemy_type = GameState.normalize_enemy_type(p_type)
	spawn_wave = p_wave
	path_curve = p_curve
	path_length = p_curve.get_baked_length()

	var cfg: Dictionary = Balance.ENEMIES[enemy_type]
	spawn_cost_s = int(cfg["spawn_cost_s"])
	bounty_b = int(cfg["bounty_b"])
	base_speed = float(cfg["speed"])
	leak_cost = int(cfg["leak_cost"])
	money_on_kill = int(cfg["money_on_kill"])
	research_on_kill = int(cfg["research_on_kill"])
	armour_label = str(cfg.get("armour_label", "Standard"))
	armour_tags = cfg.get("armour_tags", ["Standard"]).duplicate()

	swift_stacks_at_spawn = GameState.mission.mutations.get("swift_stacks", 0)
	speed_multiplier_at_spawn = pow(1.0 + Balance.TIME_POWERS["haste"]["speed_bonus_per_stack"], swift_stacks_at_spawn)
	max_hp = float(cfg["base_hp"]) * GameState.get_enemy_hp_multiplier()
	hp = max_hp
	distance_along_path = 0.0
	is_dead_or_leaked = false
	slow_pct = 0.0
	slow_remaining = 0.0
	decay_base_pct = 0.0
	decay_ticks_remaining = 0
	decay_tick_timer = 0.0
	_sync_transform_to_path()
	queue_redraw()


func get_current_move_speed() -> float:
	if GameState.is_enemies_frozen:
		return 0.0
	var slow_mult: float = (1.0 - slow_pct) if slow_remaining > 0.0 else 1.0
	return base_speed * speed_multiplier_at_spawn * slow_mult


func apply_time_hit(raw_slow_pct: float, slow_dur: float, raw_decay_pct: float, ticks: int = 3) -> void:
	if is_dead_or_leaked:
		return
	# Juggernaut resists slow by half
	var eff_slow: float = raw_slow_pct * (0.5 if enemy_type == "juggernaut" else 1.0)
	if slow_remaining <= 0.0 or eff_slow >= slow_pct:
		slow_pct = eff_slow
	slow_remaining = maxf(slow_remaining, slow_dur)

	# Decay DoT refreshes 3s / 3-tick timer on re-hit; NEVER stacks
	if raw_decay_pct > 0.0:
		if decay_ticks_remaining > 0:
			decay_base_pct = maxf(decay_base_pct, raw_decay_pct)
		else:
			decay_base_pct = raw_decay_pct
		decay_ticks_remaining = ticks
		decay_tick_timer = 1.0
	queue_redraw()


func step_status_effects(delta: float) -> void:
	if is_dead_or_leaked or delta <= 0.0:
		return
	if not GameState.is_enemies_frozen and slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_pct = 0.0
			queue_redraw()

	if decay_ticks_remaining > 0 and decay_base_pct > 0.0:
		decay_tick_timer -= delta
		while decay_ticks_remaining > 0 and decay_tick_timer <= 0.0 and not is_dead_or_leaked:
			decay_ticks_remaining -= 1
			if decay_ticks_remaining > 0:
				decay_tick_timer += 1.0
			else:
				decay_tick_timer = 0.0
			apply_time_decay_tick(decay_base_pct)
		if decay_ticks_remaining <= 0:
			decay_base_pct = 0.0


func apply_time_decay_tick(raw_tick_pct: float) -> float:
	if is_dead_or_leaked or raw_tick_pct <= 0.0:
		return 0.0
	var matrix_mult: float = Balance.get_damage_multiplier("Time", armour_tags)
	var eff_pct: float = minf(Balance.TIME_DECAY_MAX_TICK_PCT, raw_tick_pct * matrix_mult)
	var dmg: float = hp * eff_pct
	hp -= dmg
	# Execute rule: if remaining HP < 1.0 after a tick, kill immediately!
	if hp < 1.0:
		hp = 0.0
		is_dead_or_leaked = true
		died.emit(self)
		queue_free()
	else:
		hit_flash_timer = 0.09
		queue_redraw()
	return dmg


func advance_along_path(delta: float) -> void:
	if is_dead_or_leaked or path_curve == null or GameState.mission.is_over or delta <= 0.0:
		return
	step_status_effects(delta)
	if is_dead_or_leaked or GameState.is_enemies_frozen:
		return
	var eff_speed: float = get_current_move_speed()
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
	if not GameState.is_enemies_frozen:
		anim_time += delta
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	advance_along_path(GameState.get_sim_delta(delta))
	queue_redraw()


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


func take_damage(amount: float, damage_type: String = "") -> void:
	if is_dead_or_leaked:
		return
	var dmg: float = amount
	if damage_type != "":
		dmg *= Balance.get_damage_multiplier(damage_type, armour_tags)
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
		hit_flash_timer = 0.09
		queue_redraw()


func _draw_poly_oriented(local_pts: Array, ang: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for v in local_pts:
		pts.append((v as Vector2).rotated(ang))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var radius: float = 9.5
	var fill_color := Color(0.92, 0.28, 0.24)
	match enemy_type:
		"crawler":
			radius = 9.5
			fill_color = Color(0.90, 0.26, 0.22)
		"rusher":
			radius = 8.5
			fill_color = Color(1.0, 0.62, 0.14)
		"brute":
			radius = 14.5
			fill_color = Color(0.76, 0.16, 0.34)
		"blitzer":
			radius = 10.5
			fill_color = Color(0.20, 0.88, 0.96)
		"juggernaut":
			radius = 18.0
			fill_color = Color(0.56, 0.16, 0.74)

	var ang: float = last_tangent.angle()
	var fwd: Vector2 = last_tangent.normalized()
	var side: Vector2 = Vector2(-fwd.y, fwd.x)

	if GameState.is_enemies_frozen:
		var thaw_stacks: int = GameState.mission.mutations.get("thaw_stacks", 0)
		var frost_strength: float = clampf(0.38 + 0.12 * float(thaw_stacks), 0.38, 0.85)
		fill_color = fill_color.lerp(Color(0.48, 0.88, 1.0), frost_strength)
	if hit_flash_timer > 0.0:
		fill_color = fill_color.lerp(Color.WHITE, 0.65)

	# Ground drop shadow
	draw_circle(Vector2(1.5, 2.5), radius * 0.95, Color(0.0, 0.0, 0.0, 0.38))

	# Armoured mutation visual cue: golden segmented shell aura
	var armoured_stacks: int = GameState.mission.mutations.get("armoured_stacks", 0)
	if armoured_stacks > 0:
		var shell_width: float = 2.0 + minf(3.5, float(armoured_stacks) * 1.1)
		draw_arc(Vector2.ZERO, radius + shell_width * 0.55 + 1.0, 0.0, TAU, 24, Color(0.98, 0.84, 0.32, 0.92), shell_width)

	# Swift mutation visual cue: glowing slipstream chevrons trailing behind
	if swift_stacks_at_spawn > 0:
		var back_dir: Vector2 = -fwd
		for i in range(min(3, swift_stacks_at_spawn)):
			var offset_perp: float = (float(i) - 1.0) * 5.0
			var start_p: Vector2 = side * offset_perp + back_dir * (radius + 2.5)
			var end_p: Vector2 = start_p + back_dir * (8.5 + float(swift_stacks_at_spawn) * 2.2)
			draw_line(start_p, end_p, Color(0.38, 0.98, 0.78, 0.88), 2.0)

	# Distinct alien morphology per enemy type
	match enemy_type:
		"crawler":
			# 6 animated insectoid chitin legs + segmented carapace + pincer mandibles
			for l_i in range(3):
				var swing: float = sin(anim_time * 14.0 + float(l_i) * 2.1) * 2.6
				var lx: float = (float(l_i) - 1.0) * 4.5
				var root_l: Vector2 = fwd * lx + side * 5.0
				var tip_l: Vector2 = fwd * (lx + swing) + side * (radius + 3.8)
				var root_r: Vector2 = fwd * lx - side * 5.0
				var tip_r: Vector2 = fwd * (lx - swing) - side * (radius + 3.8)
				draw_line(root_l, tip_l, Color(0.45, 0.12, 0.12), 1.8)
				draw_line(root_r, tip_r, Color(0.45, 0.12, 0.12), 1.8)
			draw_circle(-fwd * 3.0, radius * 0.78, fill_color.darkened(0.22))
			draw_circle(fwd * 1.5, radius * 0.82, fill_color)
			draw_line(fwd * 7.0 + side * 3.2, fwd * 12.0 + side * 1.2, Color(0.98, 0.85, 0.55), 1.8)
			draw_line(fwd * 7.0 - side * 3.2, fwd * 12.0 - side * 1.2, Color(0.98, 0.85, 0.55), 1.8)
			draw_circle(fwd * 5.5 + side * 2.8, 1.6, Color(0.75, 1.0, 0.35))
			draw_circle(fwd * 5.5 - side * 2.8, 1.6, Color(0.75, 1.0, 0.35))

		"rusher":
			# Swept-wing raptor swarmer with forward scythes & bio-thruster exhaust
			var exhaust_len: float = 5.0 + 2.5 * sin(anim_time * 22.0)
			draw_line(-fwd * 7.0, -fwd * (7.0 + exhaust_len), Color(0.45, 0.96, 1.0, 0.85), 3.2)
			var wing_pts := [Vector2(11.0, 0.0), Vector2(-6.0, -9.5), Vector2(-3.0, 0.0), Vector2(-6.0, 9.5)]
			_draw_poly_oriented(wing_pts, ang, fill_color)
			var core_pts := [Vector2(8.0, 0.0), Vector2(-4.0, -4.5), Vector2(-4.0, 4.5)]
			_draw_poly_oriented(core_pts, ang, fill_color.lightened(0.32))
			draw_line(fwd * 5.0 + side * 4.5, fwd * 12.5 + side * 2.0, Color(1.0, 0.95, 0.68), 1.8)
			draw_line(fwd * 5.0 - side * 4.5, fwd * 12.5 - side * 2.0, Color(1.0, 0.95, 0.68), 1.8)

		"brute":
			# Hulking armored goliath with heavy steel dorsal plates & battering-ram horns
			var body_pts := [
				Vector2(13.0, -6.0), Vector2(13.0, 6.0), Vector2(3.0, 14.5),
				Vector2(-11.0, 12.0), Vector2(-14.5, 0.0), Vector2(-11.0, -12.0), Vector2(3.0, -14.5)
			]
			_draw_poly_oriented(body_pts, ang, fill_color.darkened(0.18))
			var plate_pts := [
				Vector2(9.0, -4.5), Vector2(9.0, 4.5), Vector2(1.0, 10.5),
				Vector2(-9.0, 8.5), Vector2(-9.0, -8.5), Vector2(1.0, -10.5)
			]
			_draw_poly_oriented(plate_pts, ang, Color(0.55, 0.60, 0.68) if hit_flash_timer <= 0.0 else Color.WHITE)
			draw_circle(Vector2.ZERO, 6.5, fill_color)
			# Ram horns
			draw_line(fwd * 9.0 + side * 6.5, fwd * 17.5 + side * 3.5, Color(0.88, 0.90, 0.95), 3.0)
			draw_line(fwd * 9.0 - side * 6.5, fwd * 17.5 - side * 3.5, Color(0.88, 0.90, 0.95), 3.0)
			draw_line(fwd * 8.5 - side * 4.0, fwd * 8.5 + side * 4.0, Color(1.0, 0.25, 0.25), 2.4)

		"blitzer":
			# Prismatic diamond interceptor with rotating reflective energy hex-shield
			var diamond := [Vector2(12.5, 0.0), Vector2(0.0, -9.5), Vector2(-11.0, 0.0), Vector2(0.0, 9.5)]
			_draw_poly_oriented(diamond, ang, fill_color.darkened(0.15))
			var inner_d := [Vector2(8.5, 0.0), Vector2(0.0, -5.5), Vector2(-6.5, 0.0), Vector2(0.0, 5.5)]
			_draw_poly_oriented(inner_d, ang, Color(0.82, 0.98, 1.0))
			for s_i in range(6):
				var sa1: float = anim_time * 3.5 + float(s_i) * TAU / 6.0
				var sa2: float = sa1 + TAU / 6.0
				draw_line(Vector2(cos(sa1), sin(sa1)) * 12.2, Vector2(cos(sa2), sin(sa2)) * 12.2, Color(0.65, 0.98, 1.0, 0.85), 1.6)

		"juggernaut":
			# Boss Dreadnought Leviathan (Armored + Reflective)
			var hull := [
				Vector2(17.0, -7.5), Vector2(17.0, 7.5), Vector2(5.0, 18.0),
				Vector2(-13.0, 16.0), Vector2(-18.5, 0.0), Vector2(-13.0, -16.0), Vector2(5.0, -18.0)
			]
			_draw_poly_oriented(hull, ang, fill_color.darkened(0.25))
			var armor_chevron := [
				Vector2(13.0, -5.5), Vector2(13.0, 5.5), Vector2(3.0, 13.5),
				Vector2(-10.0, 11.5), Vector2(-10.0, -11.5), Vector2(3.0, -13.5)
			]
			_draw_poly_oriented(armor_chevron, ang, Color(0.72, 0.78, 0.88))
			draw_circle(Vector2.ZERO, 9.5, fill_color)
			# Pulsing dark-matter reactor core
			var core_r: float = 4.8 + 1.2 * sin(anim_time * 6.0)
			draw_circle(Vector2.ZERO, core_r, Color(0.95, 0.52, 1.0))
			draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
			# 4 heavy siege tusks
			draw_line(fwd * 12.0 + side * 8.5, fwd * 22.5 + side * 5.0, Color(0.95, 0.88, 0.45), 3.4)
			draw_line(fwd * 12.0 - side * 8.5, fwd * 22.5 - side * 5.0, Color(0.95, 0.88, 0.45), 3.4)
			draw_line(fwd * 14.0 + side * 4.0, fwd * 20.0 + side * 2.0, Color(0.88, 0.94, 1.0), 2.4)
			draw_line(fwd * 14.0 - side * 4.0, fwd * 20.0 - side * 2.0, Color(0.88, 0.94, 1.0), 2.4)
			# Rotating outer Reflective prismatic shield
			for s_i in range(6):
				var sa1: float = -anim_time * 2.2 + float(s_i) * TAU / 6.0
				var sa2: float = sa1 + TAU / 6.0
				draw_line(Vector2(cos(sa1), sin(sa1)) * 20.2, Vector2(cos(sa2), sin(sa2)) * 20.2, Color(0.55, 0.96, 1.0, 0.82), 2.0)

	# Frost crystal overlay when frozen by Pause
	if GameState.is_enemies_frozen:
		for f_i in range(3):
			var fa: float = float(f_i) * PI / 3.0
			var fv := Vector2(cos(fa), sin(fa)) * (radius + 3.0)
			draw_line(-fv, fv, Color(0.75, 0.96, 1.0, 0.78), 1.5)

	# Chrono Slow / Time Decay DoT orbital ring
	if slow_remaining > 0.0 or decay_ticks_remaining > 0:
		var time_col := Color(0.82, 0.45, 1.0, 0.92) if decay_ticks_remaining > 0 else Color(0.35, 0.92, 1.0, 0.88)
		draw_arc(Vector2.ZERO, radius + 4.2, anim_time * 3.0, anim_time * 3.0 + PI * 1.5, 20, time_col, 2.2)
		if decay_ticks_remaining > 0:
			for d_i in range(decay_ticks_remaining):
				var da: float = -anim_time * 4.0 + float(d_i) * TAU / 3.0
				draw_circle(Vector2(cos(da), sin(da)) * (radius + 4.2), 2.2, Color(0.95, 0.65, 1.0))

	# Framed color-graded mini HP bar
	var bar_w: float = maxf(22.0, radius * 2.5)
	var bar_h: float = 5.5 if enemy_type == "juggernaut" else 4.2
	var bar_pos := Vector2(-bar_w * 0.5, -radius - 11.0)
	draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_w + 2.0, bar_h + 2.0)), Color(0.04, 0.06, 0.10, 0.92))
	var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var hp_col := Color(0.28, 0.95, 0.48) if ratio > 0.5 else (Color(0.98, 0.78, 0.24) if ratio > 0.25 else Color(0.98, 0.28, 0.28))
	draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), hp_col)
