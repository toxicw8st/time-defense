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


func get_decay_tick_pct() -> float:
	if not uses_decay_upgrades():
		return 0.0
	var ladder: Array = Balance.TOWERS[tower_type].get("decay_pct_by_level", [0.0, 0.05, 0.10, 0.20])
	var lvl: int = clampi(int(levels["damage"]), 0, ladder.size() - 1)
	return float(ladder[lvl])


func get_effective_damage() -> float:
	var base: float = float(Balance.TOWERS[tower_type]["damage"])
	var upg_mult: float = 1.0 + Balance.TOWER_DAMAGE_PER_LEVEL * float(levels["damage"])
	return base * upg_mult * GameState.get_tower_damage_research_multiplier()


func get_effective_fire_rate() -> float:
	var base: float = float(Balance.TOWERS[tower_type]["fire_rate"])
	var upg_mult: float = 1.0 + Balance.TOWER_FIRE_RATE_PER_LEVEL * float(levels["fire_rate"])
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
	if fire_cooldown <= 0.0:
		var target: EnemyUnit = _pick_target()
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
		target.apply_time_hit(float(cfg["slow_pct"]), float(cfg["slow_duration"]), get_decay_tick_pct(), int(cfg["decay_ticks"]))
	elif tower_type == "railgun":
		if map_ref != null:
			var rail: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(rail)
			rail.setup_tracer(position, target.position, Color(0.88, 0.55, 1.0), 4.5, 0.22)
		target.apply_time_hit(float(cfg["slow_pct"]), float(cfg["slow_duration"]), get_decay_tick_pct(), int(cfg["decay_ticks"]))
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


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var eff_range: float = get_effective_range()
	var min_r: float = get_min_range()

	# Range ring when selected
	if is_selected:
		draw_circle(Vector2.ZERO, eff_range, Color(0.35, 0.72, 1.0, 0.08))
		draw_arc(Vector2.ZERO, eff_range, 0.0, TAU, 48, Color(0.45, 0.82, 1.0, 0.65), 1.5)
		if min_r > 0.0:
			draw_circle(Vector2.ZERO, min_r, Color(1.0, 0.35, 0.35, 0.08))
			draw_arc(Vector2.ZERO, min_r, 0.0, TAU, 32, Color(1.0, 0.45, 0.45, 0.7), 1.5)

	var half: float = 15.0
	var rect := Rect2(Vector2(-half, -half), Vector2(half * 2.0, half * 2.0))

	if current_job != null:
		var scaffold_col := Color(0.35, 0.35, 0.22) if not is_built else Color(0.28, 0.42, 0.55)
		draw_rect(rect, scaffold_col)
		draw_rect(rect, Color(0.95, 0.82, 0.32), false, 2.0)
		draw_line(Vector2(-half, -half), Vector2(half, half), Color(0.95, 0.82, 0.32, 0.6), 1.5)
		draw_line(Vector2(half, -half), Vector2(-half, half), Color(0.95, 0.82, 0.32, 0.6), 1.5)

		var prog: float = current_job.get_progress()
		var ring_col := Color(0.35, 1.0, 0.9) if GameState.is_haste_active else Color(0.35, 0.95, 0.65)
		if GameState.is_haste_active:
			draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color(0.35, 1.0, 0.9, 0.45), 2.0)
		draw_arc(Vector2.ZERO, 21.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, ring_col, 3.0)
		var sec_text: String = "%.1fs" % current_job.remaining_time
		draw_string(font, Vector2(-13, 28), sec_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.92, 0.45))
	else:
		var fill_col := Color(0.22, 0.58, 0.95)
		var tag: String = "BL"
		match tower_type:
			"mortar":
				fill_col = Color(0.28, 0.78, 0.52)
				tag = "MT"
			"laser":
				fill_col = Color(0.85, 0.28, 0.78)
				tag = "LS"
			"slow":
				fill_col = Color(0.20, 0.78, 0.88)
				tag = "SL"
			"railgun":
				fill_col = Color(0.58, 0.32, 0.92)
				tag = "RG"
		var border_col := Color(0.75, 0.92, 1.0) if is_selected else Color(0.1, 0.16, 0.24)
		draw_rect(rect, fill_col)
		draw_rect(rect, border_col, false, 2.5 if is_selected else 1.5)
		draw_string(font, Vector2(-8, 1), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

		# Always show current target selection tag on the tower
		var tgt_tag: String = str(Balance.TARGETING_SHORT_TAGS.get(target_mode, "1ST"))
		draw_string(font, Vector2(-11, 12), tgt_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.95, 0.65))

		var total_lvl: int = int(levels["damage"]) + int(levels["range"]) + int(levels["fire_rate"])
		if total_lvl > 0:
			draw_string(font, Vector2(-14, -18), "+%d" % total_lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.9, 0.4))
