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
var apex_tier: int = 0 # 0 = Standard/Combo, 1 = Tier-4 Milestone Perk, 2 = Tier-5 APEX OVERDRIVE

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
var total_damage_dealt: float = 0.0
var total_kills: int = 0


func record_damage(amount: float, killed: bool = false) -> void:
	if amount > 0.0:
		total_damage_dealt += amount
	if killed:
		total_kills += 1
	if AnalyticsManager != null and (amount > 0.0 or killed):
		AnalyticsManager.record_tower_combat(tower_type, amount, killed)


func get_total_upgrade_ranks() -> int:
	return int(levels.get("damage", 0)) + int(levels.get("range", 0)) + int(levels.get("fire_rate", 0))


func get_apex_mods() -> Dictionary:
	if apex_tier <= 0 or not Balance.is_combo_tower(tower_type):
		return {}
	return Balance.get_combo_evolution_cfg(tower_type, apex_tier).get("mods", {})


func get_apex_mod_float(key: String, default_val: float = 0.0) -> float:
	var mods: Dictionary = get_apex_mods()
	return float(mods.get(key, default_val))


func get_apex_mod_int(key: String, default_val: int = 0) -> int:
	var mods: Dictionary = get_apex_mods()
	return int(mods.get(key, default_val))


func has_apex_mod(key: String) -> bool:
	var mods: Dictionary = get_apex_mods()
	return bool(mods.get(key, false))


func get_apex_execute_pct() -> float:
	return get_apex_mod_float("execute_hp_pct", 0.0)


func get_next_apex_cfg() -> Dictionary:
	if not Balance.is_combo_tower(tower_type) or apex_tier >= 2:
		return {}
	return Balance.get_combo_evolution_cfg(tower_type, apex_tier + 1)


func can_evolve_apex() -> bool:
	if not is_built or current_job != null or GameState.mission.is_over:
		return false
	if not Balance.is_combo_tower(tower_type) or apex_tier >= 2:
		return false
	var next_cfg: Dictionary = get_next_apex_cfg()
	if next_cfg.is_empty():
		return false
	var cost: int = int(next_cfg["cost"])
	return GameState.is_sandbox_mode or GameState.mission.economy["money"] >= cost


func start_apex_evolution() -> bool:
	if not can_evolve_apex():
		return false
	var next_tier: int = apex_tier + 1
	var next_cfg: Dictionary = get_next_apex_cfg()
	var cost: int = int(next_cfg["cost"])
	var btime: float = float(next_cfg.get("build_time", 6.0))
	if GameState.is_sandbox_mode and GameState.sandbox_instant_build:
		total_spent += cost
		apex_tier = next_tier
		if AnalyticsManager != null:
			AnalyticsManager.record_tower_upgrade(tower_type, "apex", apex_tier, cost)
		_celebrate_apex_unlock(next_cfg)
		construction_completed.emit(self)
		queue_redraw()
		return true
	if not GameState.spend_money(cost, true):
		return false
	total_spent += cost
	if AnalyticsManager != null:
		AnalyticsManager.record_tower_upgrade(tower_type, "apex", next_tier, cost)
	current_job = ConstructionJob.new("tower_apex", btime, str(next_tier))
	queue_redraw()
	return true


func _celebrate_apex_unlock(evo_cfg: Dictionary) -> void:
	var evo_name: String = str(evo_cfg.get("name", "Evolution"))
	var prefix: String = "★ APEX T5" if apex_tier >= 2 else "TIER 4 EVOLVED"
	if SfxManager != null:
		SfxManager.play("combine")
	GameState.event_logged.emit("%s: %s (%s)!" % [prefix, evo_name, Balance.TOWERS[tower_type]["name"]])
	if map_ref != null:
		var sw_col := Color(0.45, 0.96, 1.0) if apex_tier >= 2 else Color(1.0, 0.86, 0.34)
		map_ref.spawn_apex_shockwave(position, sw_col, 130.0 if apex_tier >= 2 else 95.0, 0.72 if apex_tier >= 2 else 0.52)
		if apex_tier >= 2:
			map_ref.trigger_screen_shake(0.28, 3.6)
		map_ref.spawn_floater(position + Vector2(-56.0, -34.0), "%s: %s!" % [prefix, evo_name], sw_col)


func can_detect_cloaked() -> bool:
	if int(levels.get("range", 0)) >= 2:
		return true
	if apex_tier >= 1 or has_apex_mod("reveals_cloaked"):
		return true
	if spawner_creates_bubble():
		return true
	var dt: String = get_damage_type()
	return dt == "Time" or dt == "Laser"


func get_estimated_dps() -> float:
	var cfg: Dictionary = Balance.TOWERS[tower_type]
	var rate: float = get_effective_fire_rate()
	var dmg: float = get_effective_damage()
	var dmg_lvl: int = clampi(int(levels["damage"]), 0, Balance.TOWER_DAMAGE_TOTAL_BONUSES.size() - 1)
	var dmg_scale: float = (1.0 + Balance.TOWER_DAMAGE_TOTAL_BONUSES[dmg_lvl]) * GameState.get_tower_damage_research_multiplier() * get_apex_mod_float("dmg_mult", 1.0)
	var sec: float = float(cfg.get("secondary_damage", 0.0)) * dmg_scale
	var direct: float = (dmg + sec) * rate
	var decay: float = get_decay_flat_damage()
	var burn: float = float(cfg.get("bubble_burn_dps", 0.0)) * dmg_scale * get_apex_mod_float("bubble_burn_mult", 1.0)
	return direct + decay + burn


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
	apex_tier = 0
	is_built = false
	fire_cooldown = 0.0
	_shot_counter = 0
	_ramp_target_id = -1
	_ramp_stacks = 0
	_opened_enemy_ids.clear()
	total_damage_dealt = 0.0
	total_kills = 0
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
	apex_tier = 0
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
	var r_val: float
	if not r_ladder.is_empty():
		var lvl: int = clampi(int(levels["damage"]), 0, r_ladder.size() - 1)
		r_val = float(r_ladder[lvl])
	else:
		var base_r: float = float(cfg.get("bubble_radius", cfg.get("splash_radius", 42.0)))
		r_val = base_r + float(int(levels["damage"])) * 6.0
	return r_val * get_apex_mod_float("bubble_radius_mult", 1.0)


func get_decay_flat_damage() -> float:
	if not uses_decay_upgrades():
		return 0.0
	var ladder: Array = Balance.TOWERS[tower_type].get("decay_flat_by_level", [0.0, 5.0, 11.0, 18.0, 27.0, 38.0])
	var lvl: int = clampi(int(levels["damage"]), 0, ladder.size() - 1)
	return float(ladder[lvl]) * GameState.get_tower_damage_research_multiplier() * get_apex_mod_float("decay_mult", 1.0)


func get_decay_tick_pct() -> float:
	return get_decay_flat_damage()


func get_effective_damage() -> float:
	var base: float = float(Balance.TOWERS[tower_type]["damage"])
	var dmg_lvl: int = clampi(int(levels["damage"]), 0, Balance.TOWER_DAMAGE_TOTAL_BONUSES.size() - 1)
	var upg_mult: float = 1.0 + Balance.TOWER_DAMAGE_TOTAL_BONUSES[dmg_lvl]
	return base * upg_mult * GameState.get_tower_damage_research_multiplier() * get_apex_mod_float("dmg_mult", 1.0)


func get_effective_fire_rate() -> float:
	var base: float = float(Balance.TOWERS[tower_type]["fire_rate"])
	var spd_lvl: int = clampi(int(levels["fire_rate"]), 0, Balance.TOWER_FIRE_RATE_TOTAL_BONUSES.size() - 1)
	var upg_mult: float = 1.0 + Balance.TOWER_FIRE_RATE_TOTAL_BONUSES[spd_lvl]
	return base * upg_mult * GameState.get_tower_attack_speed_multiplier() * get_apex_mod_float("rate_mult", 1.0)


## Total range progression per level: Lv0 = 1.0x, Lv1 = +25% (1.25x), Lv2 = +60% (1.60x), Lv3 = +100% (2.00x).
func get_effective_range() -> float:
	var base: float = float(Balance.TOWERS[tower_type]["range"])
	var rng_lvl: int = clampi(int(levels["range"]), 0, Balance.TOWER_RANGE_TOTAL_BONUSES.size() - 1)
	var upg_mult: float = 1.0 + Balance.TOWER_RANGE_TOTAL_BONUSES[rng_lvl]
	return base * upg_mult * GameState.get_tower_range_research_multiplier() * GameState.get_level_tower_range_multiplier() * get_apex_mod_float("range_mult", 1.0)


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
	var cost: int = Balance.get_tower_upgrade_cost(stat_key, lvl, tower_type)
	return GameState.is_sandbox_mode or GameState.mission.economy["money"] >= cost


func start_upgrade(stat_key: String) -> bool:
	if not can_start_upgrade(stat_key):
		return false
	var lvl: int = int(levels[stat_key])
	var cost: int = Balance.get_tower_upgrade_cost(stat_key, lvl, tower_type)
	var build_time: float = Balance.TOWER_UPGRADE_BUILD_TIMES[lvl]
	if GameState.is_sandbox_mode and GameState.sandbox_instant_build:
		total_spent += cost
		levels[stat_key] = lvl + 1
		if AnalyticsManager != null:
			AnalyticsManager.record_tower_upgrade(tower_type, stat_key, lvl + 1, cost)
		var inst_disp: String = "Decay" if (stat_key == "damage" and uses_decay_upgrades()) else stat_key.capitalize()
		GameState.event_logged.emit("%s %s upgraded to Lvl %d" % [Balance.TOWERS[tower_type]["name"], inst_disp, levels[stat_key]])
		construction_completed.emit(self)
		queue_redraw()
		return true
	if not GameState.spend_money(cost, true):
		return false
	total_spent += cost
	if AnalyticsManager != null:
		AnalyticsManager.record_tower_upgrade(tower_type, stat_key, lvl + 1, cost)
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
				if SfxManager != null:
					SfxManager.play("build")
				GameState.event_logged.emit("%s built on P%d" % [Balance.TOWERS[tower_type]["name"], pad_index + 1])
			elif completed_job.kind == "tower_combine":
				is_built = true
				if SfxManager != null:
					SfxManager.play("combine")
				GameState.event_logged.emit("Combined into %s!" % Balance.TOWERS[tower_type]["name"])
			elif completed_job.kind == "tower_apex":
				apex_tier = clampi(int(completed_job.target_key), 1, 2)
				var evo_cfg: Dictionary = Balance.get_combo_evolution_cfg(tower_type, apex_tier)
				_celebrate_apex_unlock(evo_cfg)
			elif completed_job.kind == "tower_upgrade":
				var key: String = completed_job.target_key
				levels[key] = int(levels.get(key, 0)) + 1
				if SfxManager != null:
					SfxManager.play("build")
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
	var can_see_cloak: bool = can_detect_cloaked()
	var in_range: Array[EnemyUnit] = []
	for enemy in map_ref.get_active_enemies():
		if enemy.is_effectively_cloaked() and not can_see_cloak:
			continue
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
	var dmg_scale: float = (1.0 + Balance.TOWER_DAMAGE_TOTAL_BONUSES[dmg_lvl]) * GameState.get_tower_damage_research_multiplier() * get_apex_mod_float("dmg_mult", 1.0)
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

	# Ramp bonus on locked target (e.g. laser+laser) — Haste doubles ramp speed!
	if bool(cfg.get("ramps_damage", false)):
		var max_r: int = int(cfg.get("ramp_max_stacks", 7)) + get_apex_mod_int("ramp_max_add", 0)
		var per_r: float = float(cfg.get("ramp_per_stack", 0.12))
		var step_r: int = 2 if GameState.is_haste_active else 1
		if _ramp_target_id == target.enemy_id:
			_ramp_stacks = mini(max_r, _ramp_stacks + step_r)
		else:
			_ramp_target_id = target.enemy_id
			_ramp_stacks = 0
		dmg *= (1.0 + float(_ramp_stacks) * per_r)
	else:
		_ramp_stacks = 0

	# First-shot opener bonus (e.g. annihilator+annihilator)
	var opener_bonus: float = float(cfg.get("opener_bonus_pct", 0.0)) + get_apex_mod_float("opener_bonus_add", 0.0)
	var triggered_opener: bool = false
	if opener_bonus > 0.0 and not _opened_enemy_ids.has(target.enemy_id):
		if _opened_enemy_ids.size() > 128:
			_opened_enemy_ids.clear()
		_opened_enemy_ids[target.enemy_id] = true
		dmg *= (1.0 + opener_bonus)
		triggered_opener = true

	# Every-Nth-shot armor crack burst (exact +25% multiplier per spec, boosted by Apex T5)
	var crack_every: int = int(cfg.get("armor_crack_every", 0))
	var is_crack_shot: bool = crack_every > 0 and (_shot_counter % crack_every == 0)
	if is_crack_shot:
		dmg *= (float(cfg.get("armor_crack_mult", 1.25)) + get_apex_mod_float("armor_crack_mult_add", 0.0))

	var sec_dmg: float = float(cfg.get("secondary_damage", 0.0)) * dmg_scale
	var sec_type: String = String(cfg.get("secondary_damage_type", "Laser" if tower_type.contains("laser") else "Time"))
	var slow_pct: float = minf(0.75, float(cfg.get("slow_pct", 0.0)) + get_apex_mod_float("bubble_slow_add", 0.0))
	var slow_dur: float = float(cfg.get("slow_duration", 3.5))
	var decay_flat: float = get_decay_flat_damage()
	var decay_ticks: int = int(cfg.get("decay_ticks", 2))
	var creates_bubble: bool = spawner_creates_bubble()
	var apex_stun: float = get_apex_mod_float("stun_duration", 0.0)
	var apex_slag_nova: float = get_apex_mod_float("slag_nova_dmg", 0.0)
	var apex_anti_regen: bool = has_apex_mod("bubble_anti_regen")
	var apex_reveals: bool = has_apex_mod("reveals_cloaked")
	var apex_vortex_pull: float = get_apex_mod_float("bubble_pull_px_per_sec", 0.0)
	var shred_bonus: int = get_apex_mod_int("bonus_shred_stacks", 0)
	var shred_pct: float = float(cfg.get("armor_shred_pct", 0.0))
	var shred_max: int = int(cfg.get("armor_shred_max_stacks", 3)) + shred_bonus
	if shred_pct <= 0.0 and shred_bonus > 0:
		shred_pct = 0.10
		shred_max = shred_bonus

	var bubble_cfg: Dictionary = {}
	if creates_bubble:
		bubble_cfg = {
			"duration": float(cfg.get("bubble_duration", 3.5)) + get_apex_mod_float("bubble_duration_add", 0.0),
			"radius": get_effective_bubble_radius(),
			"slow_pct": slow_pct if slow_pct > 0.0 else 0.30,
			"decay_flat": decay_flat,
			"decay_ticks": decay_ticks,
			"burn_dps": float(cfg.get("bubble_burn_dps", 0.0)) * dmg_scale * get_apex_mod_float("bubble_burn_mult", 1.0),
			"burn_type": String(cfg.get("bubble_burn_type", "Laser" if tower_type.contains("laser") else "Time")),
			"color": accent_col,
			"slow_linger": float(cfg.get("bubble_slow_linger", 0.45)),
			"pull_px_per_sec": apex_vortex_pull,
			"anti_regen": apex_anti_regen,
		}

	var splash_r: float = float(cfg.get("splash_radius", 0.0)) * get_apex_mod_float("splash_mult", 1.0)
	if splash_r > 0.0:
		# Mortar & mortar-hybrid shell delivery
		if SfxManager != null:
			SfxManager.play("blaster", 0.12, -5.0)
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
				int(cfg.get("mirv_subshells", 0)) + get_apex_mod_int("bonus_mirv_subshells", 0),
				slow_pct if not creates_bubble else 0.0,
				slow_dur,
				decay_flat,
				bubble_cfg,
				bool(cfg.get("direct_primary_only", false)),
				float(cfg.get("mirv_damage_ratio", 0.36)),
				self
			)
			shell.configure_apex_mortar_extras(
				apex_stun,
				apex_slag_nova,
				shred_max if shred_pct > 0.0 else 0,
				apex_reveals,
				apex_anti_regen
			)
		return

	# Direct beam / rail / tracer / bubble-projector fire
	if SfxManager != null:
		if creates_bubble:
			SfxManager.play("bubble")
		elif tower_type.contains("railgun") or tower_type.contains("annihilator"):
			SfxManager.play("railgun")
		elif tower_type.contains("laser"):
			SfxManager.play("laser")
		else:
			SfxManager.play("blaster")

	var pierce_cnt: int = maxi(1, int(cfg.get("pierce_count", 1)) + get_apex_mod_int("bonus_pierce", 0))
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
			if perp_dist <= 26.0:
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
		if apex_tier >= 1:
			beam_width += 0.9 * float(apex_tier)
		if is_crack_shot:
			beam_width += 1.4
		var t_col: Color = Color(0.45, 0.9, 1.0) if tower_type == "blaster" else (
			Color(1.0, 0.35, 0.85) if tower_type == "laser" else (
			Color(0.35, 0.92, 1.0) if tower_type == "slow" else (
			Color(0.88, 0.55, 1.0) if tower_type == "railgun" else (
			Color(1.0, 0.78, 0.26) if tower_type == "annihilator" else accent_col))))
		if is_crack_shot:
			t_col = Color(1.0, 0.92, 0.42)
		elif apex_tier >= 2:
			t_col = t_col.lerp(Color(0.62, 0.98, 1.0), 0.35)
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
				float(bubble_cfg["slow_linger"]),
				self
			)
			bubble.configure_apex_bubble_extras(apex_vortex_pull, apex_anti_regen)

	for i in range(hit_targets.size()):
		var h_target: EnemyUnit = hit_targets[i]
		if not is_instance_valid(h_target) or not h_target.is_alive():
			continue
		var t_pos_snap: Vector2 = h_target.position
		var falloff_mult: float = 1.0 if i == 0 else 0.78
		if apex_slag_nova > 0.0:
			h_target.mark_slag_nova(apex_slag_nova, self)
		var dealt_total: float = 0.0
		if dmg > 0.0:
			dealt_total += h_target.take_damage(dmg * falloff_mult, dtype, self)
		if sec_dmg > 0.0 and is_instance_valid(h_target) and h_target.is_alive():
			dealt_total += h_target.take_damage(sec_dmg * falloff_mult, sec_type, self)
		if map_ref != null and GameState.show_damage_numbers and (is_crack_shot or triggered_opener or dealt_total >= 120.0):
			var pop_col := Color(1.0, 0.90, 0.36) if (is_crack_shot or triggered_opener) else Color(0.96, 0.72, 1.0)
			map_ref.spawn_damage_popup(t_pos_snap, int(round(dealt_total)), pop_col, is_crack_shot or triggered_opener)
		if is_instance_valid(h_target) and h_target.is_alive():
			if shred_pct > 0.0:
				h_target.apply_armor_shred(shred_max, 3.8)
			if slow_pct > 0.0 and not creates_bubble:
				h_target.apply_time_hit(slow_pct, slow_dur, decay_flat, decay_ticks, self)
			if apex_stun > 0.0:
				h_target.apply_stun(apex_stun)
			if apex_reveals:
				h_target.reveal_cloak(4.5)
			if apex_anti_regen:
				h_target.suppress_regen(2.8)

	# Secondary Prism Chain Refraction (laser+laser native 1 target, boosted to 3/5 targets + added on Apex combos!)
	var base_refract_r: float = float(cfg.get("refract_radius", 0.0))
	var base_refract_ratio: float = float(cfg.get("refract_ratio", 0.0))
	var bonus_refract_cnt: int = get_apex_mod_int("bonus_refract_targets", 0)
	var total_refract_cnt: int = (1 if (base_refract_r > 0.0 and base_refract_ratio > 0.0) else 0) + bonus_refract_cnt
	var eff_refract_r: float = base_refract_r + get_apex_mod_float("refract_radius_add", 0.0)
	var eff_refract_ratio: float = base_refract_ratio + get_apex_mod_float("refract_ratio_add", 0.0)
	if total_refract_cnt > 0 and eff_refract_r > 0.0 and eff_refract_ratio > 0.0 and map_ref != null:
		var origin_p: Vector2 = beam_end
		var chain_cands: Array = []
		for cand in map_ref.get_active_enemies():
			if cand == target or hit_targets.has(cand) or not is_instance_valid(cand) or not cand.is_alive():
				continue
			var cd: float = origin_p.distance_to(cand.position)
			if cd <= eff_refract_r:
				chain_cands.append({"enemy": cand, "d": cd})
		chain_cands.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
		var chained_n: int = mini(total_refract_cnt, chain_cands.size())
		for ci in range(chained_n):
			var chain_e: EnemyUnit = chain_cands[ci]["enemy"]
			if not is_instance_valid(chain_e) or not chain_e.is_alive():
				continue
			if apex_slag_nova > 0.0:
				chain_e.mark_slag_nova(apex_slag_nova, self)
			var arc: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(arc)
			arc.setup_tracer(origin_p, chain_e.position, Color(0.55, 0.96, 1.0), 2.1 if apex_tier >= 1 else 1.9, 0.12)
			chain_e.take_damage(dmg * eff_refract_ratio, "Laser", self)

	# Apex Kinetic / Smart-Matrix Ricochet Rounds (Vulcan, Carbine, Shredder, Zero-Vector)
	var rico_cnt: int = get_apex_mod_int("ricochet_count", 0)
	var rico_ratio: float = get_apex_mod_float("ricochet_ratio", 0.0)
	if rico_cnt > 0 and rico_ratio > 0.0 and map_ref != null:
		var r_origin: Vector2 = beam_end
		var r_cands: Array = []
		for cand in map_ref.get_active_enemies():
			if cand == target or hit_targets.has(cand) or not is_instance_valid(cand) or not cand.is_alive():
				continue
			var rd: float = r_origin.distance_to(cand.position)
			if rd <= 105.0:
				r_cands.append({"enemy": cand, "d": rd})
		r_cands.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
		var bounced: int = mini(rico_cnt, r_cands.size())
		for ri in range(bounced):
			var re: EnemyUnit = r_cands[ri]["enemy"]
			if not is_instance_valid(re) or not re.is_alive():
				continue
			var r_dtype: String = dtype
			if bool(cfg.get("smart_matrix", false)):
				var best_m: float = Balance.get_damage_multiplier(r_dtype, re.armour_tags)
				for cand_dt in ["Piercing", "Laser", "Normal"]:
					var cm: float = Balance.get_damage_multiplier(cand_dt, re.armour_tags)
					if cm > best_m:
						best_m = cm
						r_dtype = cand_dt
			var r_tracer: ProjectileEffect = projectile_scene.instantiate()
			map_ref.projectiles_container.add_child(r_tracer)
			r_tracer.setup_tracer(r_origin, re.position, Color(1.0, 0.88, 0.42), 2.0, 0.10)
			re.take_damage(dmg * rico_ratio, r_dtype, self)
			if shred_pct > 0.0 and is_instance_valid(re) and re.is_alive():
				re.apply_armor_shred(shred_max, 3.2)


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
		if apex_tier >= 2:
			# Tier-5 APEX OVERDRIVE: radiant prismatic counter-rotating star halo + 6 orbiting shards!
			var ap_pulse: float = 0.65 + 0.35 * sin(anim_time * 7.0)
			draw_circle(Vector2.ZERO, 22.0, Color(0.42, 0.95, 1.0, 0.12 * ap_pulse))
			draw_arc(Vector2.ZERO, 21.8, anim_time * 2.2, anim_time * 2.2 + PI * 1.4, 28, Color(0.45, 0.98, 1.0, 0.95), 2.4)
			draw_arc(Vector2.ZERO, 19.2, -anim_time * 2.8, -anim_time * 2.8 + PI * 1.4, 28, Color(1.0, 0.88, 0.32, 0.95), 2.2)
			for sh_i in range(6):
				var sha: float = anim_time * 2.4 + float(sh_i) * TAU / 6.0
				var sp: Vector2 = Vector2(cos(sha), sin(sha)) * 22.5
				draw_circle(sp, 2.3, Color(1.0, 0.92, 0.45) if sh_i % 2 == 0 else Color(0.48, 0.98, 1.0))
		elif apex_tier == 1:
			# Tier-4 Evolved: glowing golden orbital ring + 4 energy chevrons
			draw_arc(Vector2.ZERO, 19.6, anim_time * 1.6, anim_time * 1.6 + TAU, 24, Color(1.0, 0.86, 0.32, 0.86), 2.0)
			for sh_i in range(4):
				var sha: float = -anim_time * 2.0 + float(sh_i) * PI * 0.5
				draw_circle(Vector2(cos(sha), sin(sha)) * 20.5, 2.0, Color(1.0, 0.92, 0.45))
		else:
			draw_arc(Vector2.ZERO, 18.2, 0.0, TAU, 8, Color(1.0, 0.86, 0.36, 0.45), 1.2)

	var recoil: float = (muzzle_flash_timer / 0.14) * 3.2
	Visuals.draw_turret(self, tower_type, aim_angle, recoil, anim_time, muzzle_flash_timer, levels)

	# Compact target mode pill at bottom of pedestal
	var tgt_tag: String = str(Balance.TARGETING_SHORT_TAGS.get(target_mode, "1ST"))
	draw_rect(Rect2(Vector2(-13, 8), Vector2(26, 11)), Color(0.05, 0.08, 0.13, 0.88))
	draw_rect(Rect2(Vector2(-13, 8), Vector2(26, 11)), accent_col.darkened(0.2), false, 1.0)
	draw_string(font, Vector2(-10, 17), tgt_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.98, 0.95, 0.68))

	# Individual color-coded upgrade pips (Damage=Red/Violet, Range=Cyan, FireRate=Gold) + total level / Apex badge
	var d_lvl: int = int(levels["damage"])
	var r_lvl: int = int(levels["range"])
	var s_lvl: int = int(levels["fire_rate"])
	var total_lvl: int = d_lvl + r_lvl + s_lvl
	if apex_tier >= 1:
		var badge_txt: String = "★T5" if apex_tier >= 2 else "T4"
		var badge_col := Color(0.45, 0.98, 1.0) if apex_tier >= 2 else Color(1.0, 0.88, 0.34)
		draw_rect(Rect2(Vector2(-18, -26), Vector2(26, 12)), Color(0.05, 0.08, 0.14, 0.94))
		draw_rect(Rect2(Vector2(-18, -26), Vector2(26, 12)), badge_col, false, 1.2)
		draw_string(font, Vector2(-16, -16), badge_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, badge_col)
	elif total_lvl > 0:
		draw_rect(Rect2(Vector2(-15, -24), Vector2(22, 11)), Color(0.06, 0.09, 0.14, 0.9))
		draw_string(font, Vector2(-13, -15), "+%d" % total_lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.90, 0.38))
	if total_lvl > 0:
		for i in range(d_lvl):
			draw_circle(Vector2(10.0, -13.0 + float(i) * 3.8), 1.6, Color(1.0, 0.45, 0.38))
		for i in range(r_lvl):
			draw_circle(Vector2(13.8, -13.0 + float(i) * 3.8), 1.6, Color(0.38, 0.92, 1.0))
		for i in range(s_lvl):
			draw_circle(Vector2(17.6, -13.0 + float(i) * 3.8), 1.6, Color(1.0, 0.88, 0.32))
