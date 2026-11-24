extends Node2D
class_name TowerUnit

const Visuals = preload("res://scripts/tower_visuals.gd")

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
var is_combine_highlighted: bool = false
var map_ref: GameMap = null
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
var aim_angle: float = -PI * 0.5
var muzzle_flash_timer: float = 0.0
var anim_time: float = 0.0
var _shot_counter: int = 0
var _ramp_target_id: int = -1
var _ramp_stacks: int = 0
var _opened_enemy_ids: Dictionary = {}


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
	_shot_counter = 0
	_ramp_target_id = -1
	_ramp_stacks = 0
	_opened_enemy_ids.clear()
	if GameState.is_sandbox_mode and GameState.sandbox_instant_build:
		current_job = null
		is_built = true
	else:
		current_job = ConstructionJob.new("tower_build", float(cfg["build_time"]))
	queue_redraw()


func can_combine() -> bool:
	return is_built and current_job == null and not GameState.mission.is_over and not Balance.is_combo_tower(tower_type)


func transform_to_combo(
	combo_type: String,
	added_spent: int,
	merged_levels: Dictionary,
	merge_build_time: float,
	instant_complete: bool = false
) -> void:
	var cfg: Dictionary = Balance.TOWERS[combo_type]
	tower_type = combo_type
	total_spent += maxi(0, added_spent)
	levels = {
		"damage": clampi(int(merged_levels.get("damage", 0)), 0, Balance.TOWER_UPGRADE_MAX_LEVEL),
		"range": clampi(int(merged_levels.get("range", 0)), 0, Balance.TOWER_UPGRADE_MAX_LEVEL),
		"fire_rate": clampi(int(merged_levels.get("fire_rate", 0)), 0, Balance.TOWER_UPGRADE_MAX_LEVEL),
	}
	fire_cooldown = 0.0
	_shot_counter = 0
	_ramp_target_id = -1
	_ramp_stacks = 0
	_opened_enemy_ids.clear()
	is_combine_highlighted = false
	if instant_complete or (GameState.is_sandbox_mode and GameState.sandbox_instant_build):
		current_job = null
		is_built = true
		construction_completed.emit(self)
	else:
		is_built = false
		current_job = ConstructionJob.new("tower_combine", maxf(0.5, merge_build_time))
	queue_redraw()


func is_constructing() -> bool:
	return current_job != null


func can_fire() -> bool:
	return is_built and current_job == null and not GameState.mission.is_over


func get_damage_type() -> String:
	return str(Balance.TOWERS[tower_type].get("damage_type", "Normal"))


func uses_decay_upgrades() -> bool:
	var cfg: Dictionary = Balance.TOWERS[tower_type]
	return not cfg.get("decay_flat_by_level", []).is_empty() or tower_type == "slow" or tower_type == "railgun"


func spawner_creates_bubble() -> bool:
	return bool(Balance.TOWERS[tower_type].get("spawns_bubble", false))


func get_effective_bubble_radius() -> float:
	var cfg: Dictionary = Balance.TOWERS[tower_type]
	var r_ladder: Array = cfg.get("bubble_radius_by_level", [])
	if not r_ladder.is_empty():
		var lvl: int = clampi(int(levels["damage"]), 0, r_ladder.size() - 1)
		return float(r_ladder[lvl])
	var base_r: float = float(cfg.get("bubble_radius", cfg.get("splash_radius", 42.0)))
	return base_r + float(int(levels["damage"])) * 6.0


func get_decay_flat_damage() -> float:
	if not uses_decay_upgrades():
		return 0.0
	var ladder: Array = Balance.TOWERS[tower_type].get("decay_flat_by_level", [0.0, 5.0, 11.0, 18.0, 27.0, 38.0])
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
	if GameState.is_sandbox_mode and GameState.sandbox_instant_build:
		total_spent += cost
		levels[stat_key] = lvl + 1
		var inst_disp: String = "Decay" if (stat_key == "damage" and uses_decay_upgrades()) else stat_key.capitalize()
		GameState.event_logged.emit("%s %s upgraded to Lvl %d" % [Balance.TOWERS[tower_type]["name"], inst_disp, levels[stat_key]])
		construction_completed.emit(self)
		queue_redraw()
		return true
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
	elif is_selected or is_combine_highlighted or current_job != null or GameState.is_haste_active or tower_type in ["slow", "laser", "railgun"] or Balance.is_combo_tower(tower_type):
		queue_redraw()
	advance_tower(GameState.get_sim_delta(delta))


func advance_tower(delta: float) -> void:
	if GameState.mission.is_over or delta <= 0.0:
		return

	if current_job != null:
		if not GameState.is_wave_active and not GameState.is_sandbox_mode:
			return
		var speed_mult: float = GameState.get_construction_speed_multiplier()
		if GameState.is_sandbox_mode and GameState.sandbox_instant_build:
			speed_mult = 999.0
		var finished: bool = current_job.advance(delta, speed_mult)
		queue_redraw()
		if finished:
			var completed_job := current_job
			current_job = null
			if completed_job.kind == "tower_build":
				is_built = true
				GameState.event_logged.emit("%s built on P%d" % [Balance.TOWERS[tower_type]["name"], pad_index + 1])
			elif completed_job.kind == "tower_combine":
				is_built = true
				GameState.event_logged.emit("Combined into %s!" % Balance.TOWERS[tower_type]["name"])
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
	_shot_counter += 1
	queue_redraw()

	var cfg: Dictionary = Balance.TOWERS[tower_type]
	var dmg: float = get_effective_damage()
	var dmg_lvl: int = clampi(int(levels["damage"]), 0, Balance.TOWER_DAMAGE_TOTAL_BONUSES.size() - 1)
	var dmg_scale: float = (1.0 + Balance.TOWER_DAMAGE_TOTAL_BONUSES[dmg_lvl]) * GameState.get_tower_damage_research_multiplier()
	var dtype: String = get_damage_type()
	var accent_col: Color = Visuals.get_accent_color(tower_type)

	# Adaptive prism damage type for smart_matrix combos (e.g. blaster+laser)
	if bool(cfg.get("smart_matrix", false)):
		var best_type: String = dtype
		var best_mult: float = Balance.get_damage_multiplier(dtype, target.armour_tags)
		for cand in ["Piercing", "Laser", "Normal"]:
			var cm: float = Balance.get_damage_multiplier(cand, target.armour_tags)
			if cm > best_mult:
				best_mult = cm
				best_type = cand
		dtype = best_type

	# Ramp bonus on locked target (e.g. laser+laser)
	if bool(cfg.get("ramps_damage", false)):
		if _ramp_target_id == target.enemy_id:
			_ramp_stacks = mini(10, _ramp_stacks + 1)
		else:
			_ramp_target_id = target.enemy_id
			_ramp_stacks = 0
		dmg *= (1.0 + float(_ramp_stacks) * 0.15)
	else:
		_ramp_stacks = 0

	# First-shot opener bonus (e.g. blaster+annihilator / laser+annihilator)
	var opener_bonus: float = float(cfg.get("opener_bonus_pct", 0.0))
	if opener_bonus > 0.0 and not _opened_enemy_ids.has(target.enemy_id):
		if _opened_enemy_ids.size() > 128:
			_opened_enemy_ids.clear()
		_opened_enemy_ids[target.enemy_id] = true
		dmg *= (1.0 + opener_bonus)

	# Every-Nth-shot armor crack burst
	var crack_every: int = int(cfg.get("armor_crack_every", 0))
	var is_crack_shot: bool = crack_every > 0 and (_shot_counter % crack_every == 0)
	if is_crack_shot:
		dmg *= 1.45

	var sec_dmg: float = float(cfg.get("secondary_damage", 0.0)) * dmg_scale
	var sec_type: String = String(cfg.get("secondary_damage_type", "Laser" if tower_type.contains("laser") else "Time"))
	var slow_pct: float = float(cfg.get("slow_pct", 0.0))
	var slow_dur: float = float(cfg.get("slow_duration", 3.5))
	var decay_flat: float = get_decay_flat_damage()
	var decay_ticks: int = int(cfg.get("decay_ticks", 2))
	var creates_bubble: bool = spawner_creates_bubble()

	var bubble_cfg: Dictionary = {}
	if creates_bubble:
		bubble_cfg = {
			"duration": float(cfg.get("bubble_duration", 3.5)),
			"radius": get_effective_bubble_radius(),
			"slow_pct": slow_pct if slow_pct > 0.0 else 0.30,
			"decay_flat": decay_flat,
			"decay_ticks": decay_ticks,
			"burn_dps": float(cfg.get("bubble_burn_dps", 0.0)) * dmg_scale,
			"burn_type": String(cfg.get("bubble_burn_type", "Laser" if tower_type.contains("laser") else "Time")),
			"color": accent_col,
			"slow_linger": float(cfg.get("bubble_slow_linger", 0.45)),
		}

	var splash_r: float = float(cfg.get("splash_radius", 0.0))
	if splash_r > 0.0:
		# Mortar & mortar-hybrid shell delivery
		if map_ref != null:
			var shell: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(shell)
			shell.setup_mortar_shell(
				position,
				target.position,
				float(cfg.get("projectile_flight_time", 0.48)),
				dmg,
				splash_r,
				float(cfg.get("splash_edge_ratio", 0.5)),
				map_ref,
				dtype
			)
			shell.configure_mortar_extras(
				accent_col,
				sec_dmg,
				sec_type,
				int(cfg.get("mirv_subshells", 0)),
				slow_pct if not creates_bubble else 0.0,
				slow_dur,
				decay_flat,
				bubble_cfg
			)
		return

	# Direct beam / rail / tracer / bubble-projector fire
	var pierce_cnt: int = maxi(1, int(cfg.get("pierce_count", 1)))
	var hit_targets: Array[EnemyUnit] = [target]
	var beam_end: Vector2 = target.position

	if pierce_cnt > 1 and map_ref != null:
		var seg: Vector2 = target.position - position
		var seg_len: float = maxf(1.0, seg.length())
		var dir: Vector2 = seg / seg_len
		var max_ray_len: float = get_effective_range()
		var candidates: Array = []
		for cand in map_ref.get_active_enemies():
			if cand == target or not is_instance_valid(cand) or not cand.is_alive():
				continue
			var rel: Vector2 = cand.position - position
			var proj: float = rel.dot(dir)
			if proj <= 0.0 or proj > max_ray_len:
				continue
			var perp_dist: float = absf(rel.x * (-dir.y) + rel.y * dir.x)
			if perp_dist <= 24.0:
				candidates.append({"enemy": cand, "proj": proj})
		candidates.sort_custom(func(a, b): return float(a["proj"]) < float(b["proj"]))
		for c_entry in candidates:
			if hit_targets.size() >= pierce_cnt:
				break
			var extra_e: EnemyUnit = c_entry["enemy"]
			hit_targets.append(extra_e)
			if float(c_entry["proj"]) > (beam_end - position).length():
				beam_end = extra_e.position

	if map_ref != null:
		var tracer: ProjectileEffect = projectile_scene.instantiate()
		map_ref.projectiles_container.add_child(tracer)
		var beam_width: float = 2.5
		var beam_dur: float = 0.09
		if tower_type == "slow" or creates_bubble:
			beam_width = 3.2
			beam_dur = 0.14
		elif tower_type.contains("railgun") or tower_type.contains("annihilator"):
			beam_width = 4.4
			beam_dur = 0.20
		elif bool(cfg.get("ramps_damage", false)):
			beam_width = 2.6 + float(_ramp_stacks) * 0.25
		if is_crack_shot:
			beam_width += 1.4
		var t_col: Color = Color(0.45, 0.9, 1.0) if tower_type == "blaster" else (
			Color(1.0, 0.35, 0.85) if tower_type == "laser" else (
			Color(0.35, 0.92, 1.0) if tower_type == "slow" else (
			Color(0.88, 0.55, 1.0) if tower_type == "railgun" else (
			Color(1.0, 0.78, 0.26) if tower_type == "annihilator" else accent_col))))
		if is_crack_shot:
			t_col = Color(1.0, 0.92, 0.42)
		tracer.setup_tracer(position, beam_end, t_col, beam_width, beam_dur)

		if creates_bubble:
			var bubble: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(bubble)
			bubble.setup_chrono_bubble(
				target.position,
				float(bubble_cfg["duration"]),
				float(bubble_cfg["radius"]),
				float(bubble_cfg["slow_pct"]),
				float(bubble_cfg["decay_flat"]),
				int(bubble_cfg["decay_ticks"]),
				map_ref,
				float(bubble_cfg["burn_dps"]),
				String(bubble_cfg["burn_type"]),
				accent_col,
				float(bubble_cfg["slow_linger"])
			)

	var shred_pct: float = float(cfg.get("armor_shred_pct", 0.0))
	for i in range(hit_targets.size()):
		var h_target: EnemyUnit = hit_targets[i]
		if not is_instance_valid(h_target) or not h_target.is_alive():
			continue
		var falloff_mult: float = 1.0 if i == 0 else 0.78
		if dmg > 0.0:
			h_target.take_damage(dmg * falloff_mult, dtype)
		if sec_dmg > 0.0 and is_instance_valid(h_target) and h_target.is_alive():
			h_target.take_damage(sec_dmg * falloff_mult, sec_type)
		if is_instance_valid(h_target) and h_target.is_alive():
			if (shred_pct > 0.0 or is_crack_shot):
				var stacks: int = maxi(1, int(round(maxf(shred_pct, 0.20) / 0.10)))
				h_target.apply_armor_shred(stacks, 4.0)
			if slow_pct > 0.0 and not creates_bubble:
				h_target.apply_time_hit(slow_pct, slow_dur, decay_flat, decay_ticks)


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
	var accent_col: Color = Visuals.get_accent_color(tower_type)

	if is_combine_highlighted:
		var ch_pulse: float = 0.55 + 0.35 * sin(anim_time * 9.0)
		draw_arc(Vector2.ZERO, 22.5, 0.0, TAU, 28, Color(1.0, 0.88, 0.32, ch_pulse), 2.8)
		draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.86, 0.28, 0.14 * ch_pulse))

	var outer_oct := _make_octagon(16.0)
	var inner_oct := _make_octagon(13.2)
	draw_colored_polygon(outer_oct, Color(0.11, 0.15, 0.22))
	draw_colored_polygon(inner_oct, Color(0.17, 0.22, 0.31))
	var rim_col: Color = Color(0.98, 0.90, 0.42) if (is_selected or is_combine_highlighted) else accent_col.darkened(0.15)
	for i in range(8):
		draw_line(outer_oct[i], outer_oct[(i + 1) % 8], rim_col, 2.2 if (is_selected or is_combine_highlighted) else 1.5)
	draw_circle(Vector2.ZERO, 10.5, Color(0.10, 0.13, 0.19))
	draw_arc(Vector2.ZERO, 10.5, 0.0, TAU, 24, accent_col.darkened(0.25), 1.2)

	if Balance.is_combo_tower(tower_type):
		draw_arc(Vector2.ZERO, 18.2, 0.0, TAU, 8, Color(1.0, 0.86, 0.36, 0.45), 1.2)

	var recoil: float = (muzzle_flash_timer / 0.14) * 3.2
	Visuals.draw_turret(self, tower_type, aim_angle, recoil, anim_time, muzzle_flash_timer, levels)

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
