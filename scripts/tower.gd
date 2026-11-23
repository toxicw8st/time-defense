extends Node2D
class_name TowerUnit

## Tower unit supporting 4 damage types & 5 tower types:
## - Blaster Turret ($90): Piercing (150% vs Armored, 120% vs Reflective, 180% vs Juggernaut)
## - Cluster Mortar ($110): Normal AoE (100% vs Standard, 50% vs Armored, 110% vs Reflective)
## - Laser Spire ($100): Laser beam (150% vs Standard, 85% vs Armored, 10% vs Reflective)
## - Chrono Slow Tower ($100): Time slow (30% 2s, Jugg 15%) + Decay DoT upgrades (0/5/10/20% current HP/s)
## - Time Decay Rail Gun ($375): Long-range Time hitscan (50% slow 4s, Jugg 25%) + Decay DoT upgrades

signal construction_completed(tower: TowerUnit)

var tower_id: int = 0
var tower_type: String = "blaster"
var pad_index: int = -1
var total_spent: int = 0
var target_mode: String = "first" # Per-tower target priority: first/last/strongest/weakest/fastest/slowest
var levels: Dictionary = {
	"damage": 0,
	"range": 0,
	"fire_rate": 0,
}

var current_job: ConstructionJob = null
var is_built: bool = false
var fire_cooldown: float = 0.0
var is_selected: bool = false
var map_ref: GameMap = null
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
var aim_angle: float = -PI * 0.5
var muzzle_flash_timer: float = 0.0
var anim_time: float = 0.0


func setup(p_id: int, p_type: String, p_pad_index: int, p_pos: Vector2, p_map: GameMap) -> void:
	tower_id = p_id
	tower_type = p_type
	pad_index = p_pad_index
	position = p_pos
	map_ref = p_map
	var cfg: Dictionary = Balance.TOWERS[tower_type]
	total_spent = int(cfg["cost"])
	target_mode = str(cfg.get("targeting", "first"))
	levels = {"damage": 0, "range": 0, "fire_rate": 0}
	is_built = false
	fire_cooldown = 0.0
	current_job = ConstructionJob.new("tower_build", float(cfg["build_time"]))
	queue_redraw()


func is_constructing() -> bool:
	return current_job != null


func can_fire() -> bool:
	return is_built and current_job == null and not GameState.mission.is_over


func get_damage_type() -> String:
	return str(Balance.TOWERS[tower_type].get("damage_type", "Normal"))


func uses_decay_upgrades() -> bool:
	return tower_type == "slow" or tower_type == "railgun"


func get_decay_flat_damage() -> float:
	if not uses_decay_upgrades():
		return 0.0
	var ladder: Array = Balance.TOWERS[tower_type].get("decay_flat_by_level", [0.0, 12.0, 26.0, 44.0, 66.0, 95.0])
	var lvl: int = clampi(int(levels["damage"]), 0, ladder.size() - 1)
	return float(ladder[lvl]) * GameState.get_tower_damage_research_multiplier()


func get_decay_tick_pct() -> float:
	return get_decay_flat_damage()


func get_effective_damage() -> float:
	var base: float = float(Balance.TOWERS[tower_type]["damage"])
	var dmg_lvl: int = clampi(int(levels["damage"]), 0, Balance.TOWER_DAMAGE_TOTAL_BONUSES.size() - 1)
	var upg_mult: float = 1.0 + Balance.TOWER_DAMAGE_TOTAL_BONUSES[dmg_lvl]
	return base * upg_mult * GameState.get_tower_damage_research_multiplier()


func get_effective_fire_rate() -> float:
	var base: float = float(Balance.TOWERS[tower_type]["fire_rate"])
	var spd_lvl: int = clampi(int(levels["fire_rate"]), 0, Balance.TOWER_FIRE_RATE_TOTAL_BONUSES.size() - 1)
	var upg_mult: float = 1.0 + Balance.TOWER_FIRE_RATE_TOTAL_BONUSES[spd_lvl]
	return base * upg_mult * GameState.get_tower_attack_speed_multiplier()


## Total range progression per level: Lv0 = 1.0x, Lv1 = +25% (1.25x), Lv2 = +60% (1.60x), Lv3 = +100% (2.00x).
func get_effective_range() -> float:
	var base: float = float(Balance.TOWERS[tower_type]["range"])
	var rng_lvl: int = clampi(int(levels["range"]), 0, Balance.TOWER_RANGE_TOTAL_BONUSES.size() - 1)
	var upg_mult: float = 1.0 + Balance.TOWER_RANGE_TOTAL_BONUSES[rng_lvl]
	return base * upg_mult * GameState.get_tower_range_research_multiplier()


func get_min_range() -> float:
	return float(Balance.TOWERS[tower_type].get("min_range", 0.0))


func get_sell_refund() -> int:
	return int(floor(float(total_spent) * Balance.TOWER_SELL_REFUND_RATIO))


func set_target_mode(mode: String) -> void:
	if Balance.TARGETING_MODES.has(mode):
		target_mode = mode
		queue_redraw()


func cycle_target_mode() -> String:
	var idx: int = Balance.TARGETING_MODES.find(target_mode)
	var next_idx: int = (idx + 1) % Balance.TARGETING_MODES.size()
	target_mode = Balance.TARGETING_MODES[next_idx]
	queue_redraw()
	return target_mode


func can_start_upgrade(stat_key: String) -> bool:
	if not is_built or current_job != null or GameState.mission.is_over:
		return false
	var lvl: int = int(levels.get(stat_key, 0))
	if lvl >= Balance.TOWER_UPGRADE_MAX_LEVEL:
		return false
	var cost: int = Balance.get_tower_upgrade_cost(stat_key, lvl)
	return GameState.mission.economy["money"] >= cost


func start_upgrade(stat_key: String) -> bool:
	if not can_start_upgrade(stat_key):
		return false
	var lvl: int = int(levels[stat_key])
	var cost: int = Balance.get_tower_upgrade_cost(stat_key, lvl)
	var build_time: float = Balance.TOWER_UPGRADE_BUILD_TIMES[lvl]
	if not GameState.spend_money(cost, true):
		return false
	total_spent += cost
	current_job = ConstructionJob.new("tower_upgrade", build_time, stat_key)
	queue_redraw()
	return true


func _process(delta: float) -> void:
	anim_time += delta
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer = maxf(0.0, muzzle_flash_timer - delta)
		queue_redraw()
	elif is_selected or current_job != null or GameState.is_haste_active or tower_type in ["slow", "laser", "railgun"]:
		queue_redraw()
	advance_tower(GameState.get_sim_delta(delta))


func advance_tower(delta: float) -> void:
	if GameState.mission.is_over or delta <= 0.0:
		return

	if current_job != null:
		if not GameState.is_wave_active:
			return
		var finished: bool = current_job.advance(delta, GameState.get_construction_speed_multiplier())
		queue_redraw()
		if finished:
			var completed_job := current_job
			current_job = null
			if completed_job.kind == "tower_build":
				is_built = true
				GameState.event_logged.emit("%s built on P%d" % [Balance.TOWERS[tower_type]["name"], pad_index + 1])
			elif completed_job.kind == "tower_upgrade":
				var key: String = completed_job.target_key
				levels[key] = int(levels.get(key, 0)) + 1
				var disp_key: String = "Decay" if (key == "damage" and uses_decay_upgrades()) else key.capitalize()
				GameState.event_logged.emit("%s %s upgraded to Lvl %d" % [Balance.TOWERS[tower_type]["name"], disp_key, levels[key]])
			construction_completed.emit(self)
			queue_redraw()
		return

	if not can_fire():
		return

	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var preview_tgt: EnemyUnit = _pick_target()
	if preview_tgt != null:
		var desired_angle: float = (preview_tgt.position - position).angle()
		aim_angle = lerp_angle(aim_angle, desired_angle, clampf(delta * 14.0, 0.0, 1.0))
		queue_redraw()
	if fire_cooldown <= 0.0:
		var target: EnemyUnit = preview_tgt if preview_tgt != null else _pick_target()
		if target != null:
			_fire_at(target)
			var rate: float = maxf(0.05, get_effective_fire_rate())
			fire_cooldown = 1.0 / rate


func _pick_target() -> EnemyUnit:
	if map_ref == null:
		return null
	var eff_range: float = get_effective_range()
	var min_r: float = get_min_range()
	var in_range: Array[EnemyUnit] = []
	for enemy in map_ref.get_active_enemies():
		var d: float = position.distance_to(enemy.position)
		if d <= eff_range and d >= min_r:
			in_range.append(enemy)

	if in_range.is_empty():
		return null

	var best: EnemyUnit = in_range[0]
	match target_mode:
		"last":
			for enemy in in_range:
				if enemy.distance_along_path < best.distance_along_path:
					best = enemy
		"strongest":
			for enemy in in_range:
				if enemy.max_hp > best.max_hp or (is_equal_approx(enemy.max_hp, best.max_hp) and enemy.distance_along_path > best.distance_along_path):
					best = enemy
		"weakest":
			for enemy in in_range:
				if enemy.hp < best.hp or (is_equal_approx(enemy.hp, best.hp) and enemy.distance_along_path > best.distance_along_path):
					best = enemy
		"fastest":
			var best_spd: float = best.get_current_move_speed()
			for enemy in in_range:
				var s: float = enemy.get_current_move_speed()
				if s > best_spd or (is_equal_approx(s, best_spd) and enemy.distance_along_path > best.distance_along_path):
					best = enemy
					best_spd = s
		"slowest":
			var best_spd: float = best.get_current_move_speed()
			for enemy in in_range:
				var s: float = enemy.get_current_move_speed()
				if s < best_spd or (is_equal_approx(s, best_spd) and enemy.distance_along_path > best.distance_along_path):
					best = enemy
					best_spd = s
		_: # "first" (default: furthest along path)
			for enemy in in_range:
				if enemy.distance_along_path > best.distance_along_path:
					best = enemy
	return best


func _fire_at(target: EnemyUnit) -> void:
	aim_angle = (target.position - position).angle()
	muzzle_flash_timer = 0.14
	queue_redraw()
	var dmg: float = get_effective_damage()
	var dtype: String = get_damage_type()
	var cfg: Dictionary = Balance.TOWERS[tower_type]
	if tower_type == "blaster":
		if map_ref != null:
			var tracer: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(tracer)
			tracer.setup_tracer(position, target.position, Color(0.45, 0.9, 1.0))
		target.take_damage(dmg, dtype)
	elif tower_type == "laser":
		if map_ref != null:
			var beam: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(beam)
			beam.setup_tracer(position, target.position, Color(1.0, 0.35, 0.85))
		target.take_damage(dmg, dtype)
	elif tower_type == "slow":
		if map_ref != null:
			var pulse: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(pulse)
			pulse.setup_tracer(position, target.position, Color(0.35, 0.92, 1.0), 3.0, 0.12)
		target.apply_time_hit(float(cfg["slow_pct"]), float(cfg["slow_duration"]), get_decay_flat_damage(), int(cfg["decay_ticks"]))
	elif tower_type == "railgun":
		if map_ref != null:
			var rail: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(rail)
			rail.setup_tracer(position, target.position, Color(0.88, 0.55, 1.0), 4.5, 0.22)
		if dmg > 0.0:
			target.take_damage(dmg, dtype)
		if is_instance_valid(target) and not target.is_dead_or_leaked:
			target.apply_time_hit(float(cfg["slow_pct"]), float(cfg["slow_duration"]), get_decay_flat_damage(), int(cfg["decay_ticks"]))
	elif tower_type == "annihilator":
		if map_ref != null:
			var sabot: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(sabot)
			sabot.setup_tracer(position, target.position, Color(1.0, 0.78, 0.26), 4.2, 0.16)
		target.take_damage(dmg, dtype)
	elif tower_type == "mortar":
		if map_ref != null:
			var shell: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(shell)
			shell.setup_mortar_shell(
				position,
				target.position,
				float(cfg["projectile_flight_time"]),
				dmg,
				float(cfg["splash_radius"]),
				float(cfg["splash_edge_ratio"]),
				map_ref,
				dtype
			)


func _make_octagon(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(8):
		var a: float = float(i) * PI * 0.25 + PI * 0.125
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _rot_pt(pt: Vector2, ang: float) -> Vector2:
	return pt.rotated(ang)


func _draw_rot_poly(pts: Array, ang: float, col: Color) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append((v as Vector2).rotated(ang))
	draw_colored_polygon(p, col)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var eff_range: float = get_effective_range()
	var min_r: float = get_min_range()

	# Range ring + animated radar sweep when selected
	if is_selected:
		draw_circle(Vector2.ZERO, eff_range, Color(0.30, 0.72, 1.0, 0.07))
		draw_arc(Vector2.ZERO, eff_range, 0.0, TAU, 64, Color(0.45, 0.86, 1.0, 0.75), 1.8)
		draw_arc(Vector2.ZERO, maxf(18.0, eff_range - 4.0), 0.0, TAU, 48, Color(0.45, 0.86, 1.0, 0.22), 1.0)
		var sweep_a: float = fmod(anim_time * 1.6, TAU)
		draw_line(Vector2.ZERO, Vector2(cos(sweep_a), sin(sweep_a)) * eff_range, Color(0.55, 0.92, 1.0, 0.22), 1.5)
		if min_r > 0.0:
			draw_circle(Vector2.ZERO, min_r, Color(1.0, 0.30, 0.30, 0.08))
			draw_arc(Vector2.ZERO, min_r, 0.0, TAU, 36, Color(1.0, 0.45, 0.45, 0.75), 1.5)

	var half: float = 16.0
	var rect := Rect2(Vector2(-half, -half), Vector2(half * 2.0, half * 2.0))

	# Drop shadow beneath tower pedestal
	draw_circle(Vector2(1.5, 2.5), 17.5, Color(0.0, 0.0, 0.0, 0.42))

	if current_job != null:
		# Holographic blueprint chassis + hazard construction frame
		var base_oct := _make_octagon(15.5)
		draw_colored_polygon(base_oct, Color(0.14, 0.20, 0.28, 0.92))
		var pulse_a: float = 0.55 + 0.35 * sin(anim_time * 8.0)
		draw_circle(Vector2.ZERO, 9.5, Color(0.28, 0.75, 0.95, 0.25 * pulse_a))
		draw_rect(rect, Color(0.95, 0.82, 0.32, 0.85), false, 2.0)
		draw_line(Vector2(-half, -half), Vector2(half, half), Color(0.95, 0.82, 0.32, 0.55), 1.5)
		draw_line(Vector2(half, -half), Vector2(-half, half), Color(0.95, 0.82, 0.32, 0.55), 1.5)

		var prog: float = current_job.get_progress()
		var ring_col := Color(0.35, 1.0, 0.92) if GameState.is_haste_active else Color(0.38, 0.96, 0.65)
		draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 32, Color(0.12, 0.18, 0.24, 0.85), 4.0)
		if GameState.is_haste_active:
			draw_arc(Vector2.ZERO, 24.5, 0.0, TAU, 28, Color(0.35, 1.0, 0.92, 0.48), 2.0)
		draw_arc(Vector2.ZERO, 21.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 36, ring_col, 3.2)
		var sec_text: String = "%.1fs" % current_job.remaining_time
		draw_rect(Rect2(Vector2(-16, 17), Vector2(32, 13)), Color(0.06, 0.09, 0.14, 0.88))
		draw_string(font, Vector2(-13, 27), sec_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.92, 0.45))
		return

	# Haste active overclock aura
	if GameState.is_haste_active:
		var h_pulse: float = 0.5 + 0.35 * sin(anim_time * 10.0)
		draw_arc(Vector2.ZERO, 19.5, 0.0, TAU, 28, Color(0.35, 1.0, 0.82, h_pulse), 2.0)

	# Armored octagonal pedestal base
	var accent_col := Color(0.28, 0.68, 1.0)
	match tower_type:
		"mortar":
			accent_col = Color(0.32, 0.85, 0.56)
		"laser":
			accent_col = Color(0.95, 0.36, 0.86)
		"slow":
			accent_col = Color(0.32, 0.92, 1.0)
		"railgun":
			accent_col = Color(0.75, 0.46, 1.0)
		"annihilator":
			accent_col = Color(1.0, 0.72, 0.24)

	var outer_oct := _make_octagon(16.0)
	var inner_oct := _make_octagon(13.2)
	draw_colored_polygon(outer_oct, Color(0.11, 0.15, 0.22))
	draw_colored_polygon(inner_oct, Color(0.17, 0.22, 0.31))
	var rim_col := Color(0.98, 0.90, 0.42) if is_selected else accent_col.darkened(0.15)
	for i in range(8):
		draw_line(outer_oct[i], outer_oct[(i + 1) % 8], rim_col, 2.2 if is_selected else 1.5)
	draw_circle(Vector2.ZERO, 10.5, Color(0.10, 0.13, 0.19))
	draw_arc(Vector2.ZERO, 10.5, 0.0, TAU, 24, accent_col.darkened(0.25), 1.2)

	var recoil: float = (muzzle_flash_timer / 0.14) * 3.2
	var fwd: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)

	# Turret superstructure per tower type
	match tower_type:
		"blaster":
			# Twin-barrel armor-piercing autocannon
			var b1_start: Vector2 = fwd * (3.0 - recoil) + side * 4.2
			var b1_end: Vector2 = fwd * (18.5 - recoil) + side * 4.2
			var b2_start: Vector2 = fwd * (3.0 - recoil) - side * 4.2
			var b2_end: Vector2 = fwd * (18.5 - recoil) - side * 4.2
			draw_line(b1_start, b1_end, Color(0.22, 0.30, 0.42), 3.6)
			draw_line(b2_start, b2_end, Color(0.22, 0.30, 0.42), 3.6)
			draw_line(b1_start, b1_end, Color(0.65, 0.88, 1.0), 1.6)
			draw_line(b2_start, b2_end, Color(0.65, 0.88, 1.0), 1.6)
			_draw_rot_poly([Vector2(-7, -6), Vector2(7, -5), Vector2(9, 0), Vector2(7, 5), Vector2(-7, 6)], aim_angle, Color(0.20, 0.52, 0.88))
			draw_circle(Vector2.ZERO, 4.5, Color(0.55, 0.92, 1.0))
			draw_circle(Vector2.ZERO, 2.2, Color.WHITE)
			if muzzle_flash_timer > 0.0:
				draw_circle(b1_end + fwd * 2.0, 3.8, Color(0.65, 0.96, 1.0, 0.9))
				draw_circle(b2_end + fwd * 2.0, 3.8, Color(0.65, 0.96, 1.0, 0.9))

		"mortar":
			# Heavy siege mortar with 4 hydraulic recoil struts & wide-bore tube
			for s_i in range(4):
				var sa: float = float(s_i) * PI * 0.5 + PI * 0.25
				var sv := Vector2(cos(sa), sin(sa))
				draw_line(sv * 7.0, sv * 14.0, Color(0.32, 0.42, 0.36), 3.0)
			draw_circle(Vector2.ZERO, 9.2, Color(0.20, 0.52, 0.36))
			draw_arc(Vector2.ZERO, 9.2, 0.0, TAU, 24, Color(0.45, 0.92, 0.65), 1.6)
			var tube_end: Vector2 = fwd * (13.5 - recoil * 0.8)
			draw_line(-fwd * 3.0, tube_end, Color(0.24, 0.34, 0.28), 9.0)
			draw_line(-fwd * 2.0, tube_end, Color(0.35, 0.76, 0.52), 6.2)
			draw_circle(tube_end, 4.2, Color(0.10, 0.14, 0.12))
			draw_circle(tube_end, 2.4, Color(1.0, 0.68, 0.24))
			if muzzle_flash_timer > 0.0:
				draw_circle(tube_end + fwd * 2.5, 6.5, Color(1.0, 0.78, 0.28, 0.88))
				draw_circle(tube_end + fwd * 2.5, 3.2, Color.WHITE)

		"laser":
			# Crystalline prism spire with orbiting energy nodes
			var crystal_pts := [Vector2(-7, 0), Vector2(-1, -7), Vector2(12, 0), Vector2(-1, 7)]
			_draw_rot_poly(crystal_pts, aim_angle, Color(0.72, 0.20, 0.68))
			var inner_c := [Vector2(-4, 0), Vector2(0, -4), Vector2(9, 0), Vector2(0, 4)]
			_draw_rot_poly(inner_c, aim_angle, Color(0.98, 0.52, 0.92))
			for n_i in range(3):
				var oa: float = anim_time * 3.2 + float(n_i) * TAU / 3.0
				var np := Vector2(cos(oa), sin(oa)) * 11.5
				draw_circle(np, 2.0, Color(0.55, 0.96, 1.0, 0.88))
			var lens_pos: Vector2 = fwd * 11.0
			draw_circle(lens_pos, 3.0, Color(1.0, 0.85, 0.98))
			draw_circle(Vector2.ZERO, 2.8, Color.WHITE)
			if muzzle_flash_timer > 0.0:
				draw_circle(lens_pos, 5.5, Color(1.0, 0.45, 0.92, 0.92))

		"slow":
			# Chrono stasis clockwork pylon with counter-rotating rings & clock hands
			draw_arc(Vector2.ZERO, 12.2, 0.0, TAU, 28, Color(0.28, 0.85, 0.98, 0.85), 1.8)
			for t_i in range(12):
				var ta: float = float(t_i) * TAU / 12.0 + anim_time * 0.5
				var tv := Vector2(cos(ta), sin(ta))
				draw_line(tv * 9.5, tv * 12.5, Color(0.65, 0.96, 1.0, 0.85), 1.3)
			var decay_lvl: int = int(levels["damage"])
			var core_col := Color(0.75, 0.45, 1.0) if decay_lvl > 0 else Color(0.32, 0.92, 1.0)
			draw_arc(Vector2.ZERO, 7.2, -anim_time * 2.4, -anim_time * 2.4 + PI * 1.4, 20, core_col, 2.2)
			# Clock hands
			var h1 := Vector2.RIGHT.rotated(anim_time * 2.2) * 8.5
			var h2 := Vector2.RIGHT.rotated(-anim_time * 0.8) * 6.0
			draw_line(Vector2.ZERO, h1, Color.WHITE, 1.8)
			draw_line(Vector2.ZERO, h2, Color(0.82, 0.96, 1.0), 1.5)
			draw_circle(Vector2.ZERO, 3.2, core_col)
			draw_circle(Vector2.ZERO, 1.6, Color.WHITE)
			if muzzle_flash_timer > 0.0:
				draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 28, Color(0.55, 0.96, 1.0, 0.9), 2.4)

		"railgun":
			# Long-range twin-rail temporal accelerator with glowing capacitor coils
			var r_len: float = 21.0 - recoil
			draw_line(-fwd * 6.0 + side * 3.4, fwd * r_len + side * 3.4, Color(0.75, 0.55, 1.0), 2.4)
			draw_line(-fwd * 6.0 - side * 3.4, fwd * r_len - side * 3.4, Color(0.75, 0.55, 1.0), 2.4)
			draw_line(-fwd * 4.0, fwd * (r_len - 2.0), Color(1.0, 0.90, 0.45, 0.85), 1.8)
			for c_i in range(3):
				var cp: Vector2 = fwd * (4.0 + float(c_i) * 5.0 - recoil * 0.6)
				var c_pulse: float = 0.6 + 0.4 * sin(anim_time * 7.0 - float(c_i) * 1.1)
				draw_line(cp - side * 4.8, cp + side * 4.8, Color(0.95, 0.72, 1.0, c_pulse), 2.0)
			_draw_rot_poly([Vector2(-9, -6), Vector2(4, -5), Vector2(6, 0), Vector2(4, 5), Vector2(-9, 6)], aim_angle, Color(0.45, 0.22, 0.78))
			draw_circle(-fwd * 2.0, 3.6, Color(0.95, 0.78, 1.0))
			if muzzle_flash_timer > 0.0:
				draw_circle(fwd * (r_len + 2.0), 5.5, Color(0.95, 0.72, 1.0, 0.95))
				draw_circle(fwd * (r_len + 2.0), 2.6, Color(1.0, 0.96, 0.72))

		"annihilator":
			# Heavy Gauss Annihilator anti-boss siege turret
			var g_len: float = 20.0 - recoil
			draw_line(-fwd * 4.0 + side * 6.5, fwd * 8.0 + side * 6.5, Color(0.42, 0.24, 0.14), 4.0)
			draw_line(-fwd * 4.0 - side * 6.5, fwd * 8.0 - side * 6.5, Color(0.42, 0.24, 0.14), 4.0)
			draw_line(fwd * 2.0, fwd * g_len, Color(0.28, 0.22, 0.18), 7.5)
			draw_line(fwd * 2.0 + side * 2.2, fwd * g_len + side * 2.2, Color(1.0, 0.78, 0.28), 2.0)
			draw_line(fwd * 2.0 - side * 2.2, fwd * g_len - side * 2.2, Color(1.0, 0.78, 0.28), 2.0)
			_draw_rot_poly([Vector2(-9, -8), Vector2(6, -7), Vector2(9, 0), Vector2(6, 7), Vector2(-9, 8)], aim_angle, Color(0.78, 0.34, 0.18))
			draw_circle(Vector2.ZERO, 4.8, Color(1.0, 0.85, 0.32))
			draw_circle(Vector2.ZERO, 2.2, Color.WHITE)
			if muzzle_flash_timer > 0.0:
				draw_circle(fwd * (g_len + 2.5), 6.2, Color(1.0, 0.82, 0.28, 0.95))
				draw_circle(fwd * (g_len + 2.5), 3.0, Color.WHITE)

	# Compact target mode pill at bottom of pedestal
	var tgt_tag: String = str(Balance.TARGETING_SHORT_TAGS.get(target_mode, "1ST"))
	draw_rect(Rect2(Vector2(-13, 8), Vector2(26, 11)), Color(0.05, 0.08, 0.13, 0.88))
	draw_rect(Rect2(Vector2(-13, 8), Vector2(26, 11)), accent_col.darkened(0.2), false, 1.0)
	draw_string(font, Vector2(-10, 17), tgt_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.98, 0.95, 0.68))

	# Individual color-coded upgrade pips (Damage=Red/Violet, Range=Cyan, FireRate=Gold) + total level badge (up to Lv5 each)
	var d_lvl: int = int(levels["damage"])
	var r_lvl: int = int(levels["range"])
	var s_lvl: int = int(levels["fire_rate"])
	var total_lvl: int = d_lvl + r_lvl + s_lvl
	if total_lvl > 0:
		draw_rect(Rect2(Vector2(-15, -24), Vector2(22, 11)), Color(0.06, 0.09, 0.14, 0.9))
		draw_string(font, Vector2(-13, -15), "+%d" % total_lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.90, 0.38))
		for i in range(d_lvl):
			draw_circle(Vector2(10.0, -13.0 + float(i) * 3.8), 1.6, Color(1.0, 0.45, 0.38))
		for i in range(r_lvl):
			draw_circle(Vector2(13.8, -13.0 + float(i) * 3.8), 1.6, Color(0.38, 0.92, 1.0))
		for i in range(s_lvl):
			draw_circle(Vector2(17.6, -13.0 + float(i) * 3.8), 1.6, Color(1.0, 0.88, 0.32))
