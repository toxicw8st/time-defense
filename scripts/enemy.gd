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
var armor_shred_stacks: int = 0
var armor_shred_timer: float = 0.0
var anim_time: float = 0.0
var hit_flash_timer: float = 0.0
var is_inspected: bool = false
var _decay_source_ref: WeakRef = null
var map_ref: Node = null

# v2.0 BTD5-inspired enemy mechanics & Apex status flags
var is_cloaked_type: bool = false
var revealed_timer: float = 0.0
var regen_pct_per_sec: float = 0.0
var regen_suppressed_timer: float = 0.0
var shield_aura_radius: float = 0.0
var shield_aura_reduction: float = 0.0
var stun_remaining: float = 0.0
var is_split_child: bool = false
var _slag_nova_dmg: float = 0.0
var _slag_nova_source_ref: WeakRef = null


func setup(p_id: int, p_type: String, p_wave: int, p_curve: Curve2D, p_map: Node = null) -> void:
	enemy_id = p_id
	enemy_type = GameState.normalize_enemy_type(p_type)
	spawn_wave = p_wave
	path_curve = p_curve
	map_ref = p_map
	path_length = p_curve.get_baked_length()

	var cfg: Dictionary = Balance.ENEMIES[enemy_type]
	spawn_cost_s = int(cfg["spawn_cost_s"])
	bounty_b = int(cfg["bounty_b"])
	base_speed = float(cfg["speed"])
	if enemy_type == "blitzer":
		base_speed *= (1.0 + float(GameState.get_level_cfg().get("blitzer_speed_bonus", 0.0)))
	leak_cost = int(cfg["leak_cost"])
	money_on_kill = maxi(1, int(round(float(cfg["money_on_kill"]) * GameState.get_enemy_bounty_multiplier())))
	research_on_kill = int(cfg["research_on_kill"])
	armour_label = str(cfg.get("armour_label", "Standard"))
	armour_tags = cfg.get("armour_tags", ["Standard"]).duplicate()

	is_cloaked_type = bool(cfg.get("is_cloaked", false))
	revealed_timer = 0.0
	regen_pct_per_sec = float(cfg.get("regen_pct_per_sec", 0.0))
	regen_suppressed_timer = 0.0
	shield_aura_radius = float(cfg.get("shield_aura_radius", 0.0))
	shield_aura_reduction = float(cfg.get("shield_aura_reduction", 0.0))
	stun_remaining = 0.0
	is_split_child = false
	_slag_nova_dmg = 0.0
	_slag_nova_source_ref = null

	swift_stacks_at_spawn = GameState.mission.mutations.get("swift_stacks", 0)
	var diff_spd: float = float(GameState.get_difficulty_cfg().get("speed_mult", 1.0))
	speed_multiplier_at_spawn = pow(1.0 + Balance.TIME_POWERS["haste"]["speed_bonus_per_stack"], swift_stacks_at_spawn) * diff_spd
	max_hp = float(cfg["base_hp"]) * GameState.get_enemy_hp_multiplier()
	hp = max_hp
	distance_along_path = 0.0
	is_dead_or_leaked = false
	is_inspected = false
	_decay_source_ref = null
	slow_pct = 0.0
	slow_remaining = 0.0
	decay_base_pct = 0.0
	decay_ticks_remaining = 0
	decay_tick_timer = 0.0
	armor_shred_stacks = 0
	armor_shred_timer = 0.0
	_sync_transform_to_path()
	queue_redraw()


func is_effectively_cloaked() -> bool:
	return is_cloaked_type and revealed_timer <= 0.0


func reveal_cloak(duration: float = 4.5) -> void:
	if not is_cloaked_type or is_dead_or_leaked:
		return
	revealed_timer = maxf(revealed_timer, duration)
	queue_redraw()


func suppress_regen(duration: float = 2.5) -> void:
	if is_dead_or_leaked:
		return
	regen_suppressed_timer = maxf(regen_suppressed_timer, duration)


func apply_stun(duration: float) -> void:
	if is_dead_or_leaked or duration <= 0.0:
		return
	var is_boss: bool = (enemy_type == "juggernaut" or enemy_type == "colossus")
	var eff_dur: float = duration * (0.45 if is_boss else 1.0)
	stun_remaining = maxf(stun_remaining, eff_dur)
	queue_redraw()


func apply_vortex_pull(px_amount: float) -> void:
	if is_dead_or_leaked or px_amount <= 0.0 or path_curve == null:
		return
	var is_boss: bool = (enemy_type == "juggernaut" or enemy_type == "colossus")
	var eff_px: float = px_amount * (0.35 if is_boss else 1.0)
	distance_along_path = maxf(0.0, distance_along_path - eff_px)
	_sync_transform_to_path()


func mark_slag_nova(nova_dmg: float, source_tower: Node = null) -> void:
	if is_dead_or_leaked or nova_dmg <= 0.0:
		return
	if nova_dmg >= _slag_nova_dmg:
		_slag_nova_dmg = nova_dmg
		_slag_nova_source_ref = weakref(source_tower) if source_tower != null else null


func is_shielded_by_conduit() -> bool:
	if is_dead_or_leaked or enemy_type == "conduit" or map_ref == null or not map_ref.has_method("get_active_enemies"):
		return false
	for other in map_ref.get_active_enemies():
		if other == self or not is_instance_valid(other) or not other.is_alive():
			continue
		if other.enemy_type == "conduit" and other.shield_aura_radius > 0.0:
			if position.distance_to(other.position) <= other.shield_aura_radius:
				return true
	return false


func get_current_move_speed() -> float:
	if GameState.is_enemies_frozen or stun_remaining > 0.0:
		return 0.0
	var slow_mult: float = (1.0 - slow_pct) if slow_remaining > 0.0 else 1.0
	return base_speed * speed_multiplier_at_spawn * slow_mult


func apply_time_hit(raw_slow_pct: float, slow_dur: float, raw_decay_flat: float, ticks: int = 3, source_tower: Node = null) -> void:
	if is_dead_or_leaked:
		return
	reveal_cloak(4.5)
	if raw_decay_flat > 0.0:
		suppress_regen(2.8)
	# Bosses (Juggernaut & Colossus) resist slow by half
	var is_boss: bool = (enemy_type == "juggernaut" or enemy_type == "colossus")
	var eff_slow: float = raw_slow_pct * (0.5 if is_boss else 1.0)
	if slow_remaining <= 0.0 or eff_slow >= slow_pct:
		slow_pct = eff_slow
	slow_remaining = maxf(slow_remaining, slow_dur)

	# Flat Time Decay DoT refreshes 3s / 3-tick timer on re-hit; NEVER stacks
	if raw_decay_flat > 0.0:
		if decay_ticks_remaining > 0:
			if raw_decay_flat >= decay_base_pct and source_tower != null:
				_decay_source_ref = weakref(source_tower)
			decay_base_pct = maxf(decay_base_pct, raw_decay_flat)
		else:
			decay_base_pct = raw_decay_flat
			if source_tower != null:
				_decay_source_ref = weakref(source_tower)
		decay_ticks_remaining = ticks
		decay_tick_timer = 1.0
	queue_redraw()


## Called continuously while inside a Chrono Slow Status Bubble: refreshes slow smoothly
## WITHOUT resetting decay_tick_timer so 1.0s DoT ticks still fire reliably inside the bubble!
func apply_bubble_aura(raw_slow_pct: float, slow_linger: float, raw_decay_flat: float, ticks: int = 3, source_tower: Node = null) -> void:
	if is_dead_or_leaked:
		return
	reveal_cloak(4.5)
	if raw_decay_flat > 0.0:
		suppress_regen(2.2)
	var is_boss: bool = (enemy_type == "juggernaut" or enemy_type == "colossus")
	var eff_slow: float = raw_slow_pct * (0.5 if is_boss else 1.0)
	if slow_remaining <= 0.0 or eff_slow >= slow_pct:
		slow_pct = eff_slow
	slow_remaining = maxf(slow_remaining, slow_linger)

	if raw_decay_flat > 0.0:
		if decay_ticks_remaining <= 0:
			decay_base_pct = raw_decay_flat
			decay_ticks_remaining = ticks
			decay_tick_timer = 1.0
			if source_tower != null:
				_decay_source_ref = weakref(source_tower)
		else:
			if raw_decay_flat >= decay_base_pct and source_tower != null:
				_decay_source_ref = weakref(source_tower)
			decay_base_pct = maxf(decay_base_pct, raw_decay_flat)
			decay_ticks_remaining = maxi(decay_ticks_remaining, ticks)
	queue_redraw()


func apply_armor_shred(max_stacks: int = 3, duration: float = 3.0) -> void:
	if is_dead_or_leaked:
		return
	armor_shred_stacks = mini(max_stacks, armor_shred_stacks + 1)
	armor_shred_timer = duration
	suppress_regen(duration)
	queue_redraw()


func step_status_effects(delta: float) -> void:
	if is_dead_or_leaked or delta <= 0.0:
		return
	if revealed_timer > 0.0:
		revealed_timer = maxf(0.0, revealed_timer - delta)
	if regen_suppressed_timer > 0.0:
		regen_suppressed_timer = maxf(0.0, regen_suppressed_timer - delta)
	if not GameState.is_enemies_frozen and stun_remaining > 0.0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
	if not GameState.is_enemies_frozen and slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_pct = 0.0
			queue_redraw()

	if armor_shred_timer > 0.0:
		armor_shred_timer = maxf(0.0, armor_shred_timer - delta)
		if armor_shred_timer <= 0.0:
			armor_shred_stacks = 0
			queue_redraw()

	# Bio-Mender regeneration (heals 6% max HP/sec unless suppressed by Time Decay, Burn, Shred, or Pause!)
	if regen_pct_per_sec > 0.0 and regen_suppressed_timer <= 0.0 and decay_ticks_remaining <= 0 and armor_shred_stacks <= 0 and not GameState.is_enemies_frozen and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * regen_pct_per_sec * delta)

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


## Applies flat Time Decay damage per tick multiplied by the Time row of DAMAGE_MATRIX (100% Std, 120% Arm, 150% Refl/Jugg),
## capped at 30% of max HP per tick, with execute rule if remaining HP < 1.0.
func apply_time_decay_tick(raw_flat_dmg: float) -> float:
	if is_dead_or_leaked or raw_flat_dmg <= 0.0:
		return 0.0
	var matrix_mult: float = Balance.get_damage_multiplier("Time", armour_tags)
	var dmg: float = minf(raw_flat_dmg * matrix_mult, maxf(1.0, max_hp) * Balance.TIME_DECAY_MAX_TICK_PCT)
	var dealt: float = minf(hp, dmg)
	hp -= dmg
	var killed: bool = false
	# Execute rule: if remaining HP < 1.0 after a tick, kill immediately!
	if hp < 1.0:
		hp = 0.0
		is_dead_or_leaked = true
		killed = true
		if SfxManager != null:
			SfxManager.play("boss_kill" if (enemy_type == "juggernaut" or enemy_type == "colossus") else "kill")
		died.emit(self)
		queue_free()
	else:
		hit_flash_timer = 0.09
		queue_redraw()
	if _decay_source_ref != null:
		var src = _decay_source_ref.get_ref()
		if src != null and is_instance_valid(src) and src.has_method("record_damage"):
			src.record_damage(dealt, killed)
	return dmg


func is_alive() -> bool:
	return not is_dead_or_leaked


func get_path_progress_pct() -> float:
	if path_length <= 0.01:
		return 0.0
	return clampf((distance_along_path / path_length) * 100.0, 0.0, 100.0)


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


func take_damage(amount: float, damage_type: String = "", source_tower: Node = null) -> float:
	if is_dead_or_leaked:
		return 0.0
	var dmg: float = amount
	if damage_type != "":
		dmg *= Balance.get_damage_multiplier(damage_type, armour_tags)
	if armor_shred_stacks > 0 and damage_type != "Time":
		dmg *= (1.0 + 0.10 * float(armor_shred_stacks))
	# Aegis Conduit Shield Aura (-35% dmg taken unless attacker has Apex shield-strip!)
	var ignores_aura: bool = (source_tower != null and source_tower.has_method("has_apex_mod") and source_tower.has_apex_mod("strip_shield_aura"))
	if not ignores_aura and is_shielded_by_conduit():
		dmg *= (1.0 - 0.35)
	if GameState.is_enemies_frozen:
		var thaw_stacks: int = GameState.mission.mutations.get("thaw_stacks", 0)
		var reduction: float = minf(
			Balance.TIME_POWERS["pause"]["frozen_damage_reduction_cap"],
			Balance.TIME_POWERS["pause"]["frozen_damage_reduction_per_stack"] * float(thaw_stacks)
		)
		dmg *= (1.0 - reduction)
	# Time/Laser/Reveal impacts strip Phase Stalker cloak
	if is_cloaked_type and (damage_type == "Time" or damage_type == "Laser" or (source_tower != null and source_tower.has_method("has_apex_mod") and source_tower.has_apex_mod("reveals_cloaked"))):
		reveal_cloak(4.0)
	var dealt: float = minf(hp, dmg)
	hp -= dmg
	var killed: bool = false
	# Tier-5 Apex Execute threshold (e.g., Omega Singularity Sovereign executes <12% HP!)
	if hp > 0.0 and dealt > 0.0 and source_tower != null and source_tower.has_method("get_apex_execute_pct"):
		var exec_pct: float = float(source_tower.get_apex_execute_pct())
		if exec_pct > 0.0 and (hp / maxf(1.0, max_hp)) <= exec_pct:
			dealt += hp
			hp = 0.0
			if map_ref != null and map_ref.has_method("spawn_floater"):
				map_ref.spawn_floater(position + Vector2(-24.0, -26.0), "APEX EXECUTE!", Color(1.0, 0.32, 0.65))
	if hp <= 0.0:
		hp = 0.0
		is_dead_or_leaked = true
		killed = true
		if SfxManager != null:
			SfxManager.play("boss_kill" if (enemy_type == "juggernaut" or enemy_type == "colossus" or enemy_type == "carrier") else "kill")
		died.emit(self)
		queue_free()
	else:
		hit_flash_timer = 0.09
		queue_redraw()
	if source_tower != null and is_instance_valid(source_tower) and source_tower.has_method("record_damage"):
		source_tower.record_damage(dealt, killed)
	return dealt


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
		"colossus":
			radius = 22.0
			fill_color = Color(0.78, 0.12, 0.36)
		"stalker":
			radius = 10.5
			fill_color = Color(0.55, 0.32, 0.98)
		"mender":
			radius = 12.0
			fill_color = Color(0.18, 0.86, 0.48)
		"carrier":
			radius = 16.5
			fill_color = Color(0.84, 0.44, 0.14)
		"conduit":
			radius = 14.0
			fill_color = Color(0.28, 0.88, 0.98)

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

	# Distinct custom sprite rendering (with procedural vector fallback)
	var sprite_tex: Texture2D = SpriteLibrary.get_enemy_texture(enemy_type)
	if sprite_tex != null:
		# Keep Conduit's 95px protective dome aura and Mender's healing pulse underneath sprite
		if enemy_type == "conduit":
			var dome_r: float = shield_aura_radius if shield_aura_radius > 0.0 else 95.0
			draw_circle(Vector2.ZERO, dome_r, Color(0.32, 0.88, 1.0, 0.07))
			draw_arc(Vector2.ZERO, dome_r, 0.0, TAU, 40, Color(0.98, 0.84, 0.34, 0.42), 1.8)
			draw_arc(Vector2.ZERO, dome_r - 3.5, anim_time * 1.4, anim_time * 1.4 + PI * 1.2, 32, Color(0.38, 0.96, 1.0, 0.52), 1.5)
		elif enemy_type == "mender":
			var regen_active: bool = (regen_suppressed_timer <= 0.0 and decay_ticks_remaining <= 0 and armor_shred_stacks <= 0)
			if regen_active and hp < max_hp:
				var hp_wave: float = fmod(anim_time * 1.8, 1.0)
				draw_arc(Vector2.ZERO, lerpf(10.0, 24.0, hp_wave), 0.0, TAU, 22, Color(0.30, 1.0, 0.55, (1.0 - hp_wave) * 0.85), 2.0)

		var target_max: float = 30.0
		match enemy_type:
			"crawler": target_max = 28.0
			"rusher": target_max = 28.0
			"stalker": target_max = 34.0
			"blitzer": target_max = 32.0
			"mender": target_max = 34.0
			"brute": target_max = 42.0
			"conduit": target_max = 40.0
			"carrier": target_max = 48.0
			"juggernaut": target_max = 56.0
			"colossus": target_max = 68.0

		var sw: float = maxf(1.0, float(sprite_tex.get_width()))
		var sh: float = maxf(1.0, float(sprite_tex.get_height()))
		var sc: float = target_max / maxf(sw, sh)
		var draw_size := Vector2(sw * sc, sh * sc)

		var mod_col := Color.WHITE
		if GameState.is_enemies_frozen:
			mod_col = Color(0.58, 0.92, 1.0, 1.0)
		elif enemy_type == "mender" and (regen_suppressed_timer > 0.0 or decay_ticks_remaining > 0 or armor_shred_stacks > 0):
			mod_col = Color(0.78, 0.72, 0.62, 1.0)
		if hit_flash_timer > 0.0:
			mod_col = Color(1.55, 1.55, 1.55, 1.0)
		if enemy_type == "stalker" and is_effectively_cloaked():
			mod_col.a = 0.34 + 0.14 * sin(anim_time * 9.0)

		var wobble_amp: float = 0.0 if (GameState.is_enemies_frozen or stun_remaining > 0.0) else (0.065 if enemy_type in ["crawler", "rusher", "stalker", "mender"] else 0.028)
		var wobble_ang: float = ang + sin(anim_time * 13.0 + float(enemy_id) * 1.7) * wobble_amp
		SpriteLibrary.draw_sprite_oriented(self, sprite_tex, Vector2.ZERO, wobble_ang, draw_size, Vector2(0.5, 0.5), mod_col)

		if enemy_type == "stalker":
			if is_effectively_cloaked():
				draw_arc(Vector2.ZERO, 13.5, anim_time * 5.0, anim_time * 5.0 + PI * 1.1, 16, Color(0.68, 0.45, 1.0, 0.55), 1.4)
			else:
				draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 20, Color(0.35, 0.98, 1.0, 0.92), 1.8)
				draw_line(Vector2(-16, 0), Vector2(-11, 0), Color(0.35, 0.98, 1.0), 1.6)
				draw_line(Vector2(11, 0), Vector2(16, 0), Color(0.35, 0.98, 1.0), 1.6)
	else:
		# Procedural fallback morphology if custom sprite is missing
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

			"colossus":
				# Wave 16+ Tier-2 Siege Boss Titan (Armored + Reflective)
				var c_hull := [
					Vector2(21.0, -9.0), Vector2(21.0, 9.0), Vector2(7.0, 21.5),
					Vector2(-15.0, 19.0), Vector2(-22.0, 0.0), Vector2(-15.0, -19.0), Vector2(7.0, -21.5)
				]
				_draw_poly_oriented(c_hull, ang, fill_color.darkened(0.28))
				var c_plate := [
					Vector2(16.0, -6.5), Vector2(16.0, 6.5), Vector2(4.0, 16.0),
					Vector2(-12.0, 14.0), Vector2(-12.0, -14.0), Vector2(4.0, -16.0)
				]
				_draw_poly_oriented(c_plate, ang, Color(0.88, 0.76, 0.42))
				draw_circle(Vector2.ZERO, 11.5, fill_color)
				var c_core: float = 5.5 + 1.6 * sin(anim_time * 7.5)
				draw_circle(Vector2.ZERO, c_core, Color(1.0, 0.82, 0.30))
				draw_circle(Vector2.ZERO, 2.8, Color.WHITE)
				# 6 heavy siege horns
				for h_side in [-1.0, 1.0]:
					draw_line(fwd * 14.0 + side * (11.0 * h_side), fwd * 27.0 + side * (7.0 * h_side), Color(1.0, 0.86, 0.38), 3.8)
					draw_line(fwd * 16.0 + side * (5.0 * h_side), fwd * 24.0 + side * (2.5 * h_side), Color(0.95, 0.96, 1.0), 2.6)
				# Dual counter-rotating prismatic shields
				for s_i in range(8):
					var sa1: float = anim_time * 2.0 + float(s_i) * TAU / 8.0
					var sa2: float = sa1 + TAU / 8.0
					draw_line(Vector2(cos(sa1), sin(sa1)) * 24.5, Vector2(cos(sa2), sin(sa2)) * 24.5, Color(0.48, 0.96, 1.0, 0.85), 2.2)
					var sb1: float = -anim_time * 1.6 + float(s_i) * TAU / 8.0
					var sb2: float = sb1 + TAU / 12.0
					draw_line(Vector2(cos(sb1), sin(sb1)) * 21.5, Vector2(cos(sb2), sin(sb2)) * 21.5, Color(1.0, 0.78, 0.30, 0.75), 1.8)

			"stalker":
				# Cloaked Stealth Phase-Mantis: translucent violet shimmer when cloaked, crisp lock reticle when revealed!
				var cloak_a: float = 0.34 + 0.14 * sin(anim_time * 9.0) if is_effectively_cloaked() else 0.96
				var s_col := Color(fill_color.r, fill_color.g, fill_color.b, cloak_a)
				var blade_pts := [Vector2(13.5, 0.0), Vector2(-3.0, -9.5), Vector2(-9.5, -4.5), Vector2(-5.5, 0.0), Vector2(-9.5, 4.5), Vector2(-3.0, 9.5)]
				_draw_poly_oriented(blade_pts, ang, s_col)
				var visor_pts := [Vector2(9.0, 0.0), Vector2(1.0, -4.0), Vector2(1.0, 4.0)]
				_draw_poly_oriented(visor_pts, ang, Color(0.72, 0.96, 1.0, cloak_a))
				if is_effectively_cloaked():
					draw_arc(Vector2.ZERO, 12.5, anim_time * 5.0, anim_time * 5.0 + PI * 1.1, 16, Color(0.68, 0.45, 1.0, 0.55), 1.4)
				else:
					# Revealed radar scan lock!
					draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 20, Color(0.35, 0.98, 1.0, 0.92), 1.8)
					draw_line(Vector2(-15, 0), Vector2(-10, 0), Color(0.35, 0.98, 1.0), 1.6)
					draw_line(Vector2(10, 0), Vector2(15, 0), Color(0.35, 0.98, 1.0), 1.6)

			"mender":
				# Organic Bio-Regenerator: glowing emerald bio-core + healing pulse rings
				var regen_active: bool = (regen_suppressed_timer <= 0.0 and decay_ticks_remaining <= 0 and armor_shred_stacks <= 0)
				if regen_active and hp < max_hp:
					var hp_wave: float = fmod(anim_time * 1.8, 1.0)
					draw_arc(Vector2.ZERO, lerpf(9.0, 21.0, hp_wave), 0.0, TAU, 22, Color(0.30, 1.0, 0.55, (1.0 - hp_wave) * 0.85), 2.0)
				var m_body := [Vector2(12.0, -4.0), Vector2(12.0, 4.0), Vector2(2.0, 11.5), Vector2(-10.5, 8.5), Vector2(-12.5, 0.0), Vector2(-10.5, -8.5), Vector2(2.0, -11.5)]
				_draw_poly_oriented(m_body, ang, fill_color.darkened(0.22))
				draw_circle(Vector2.ZERO, 7.5, fill_color if regen_active else fill_color.lerp(Color(0.65, 0.55, 0.35), 0.55))
				# Bio-plus emblem on carapace
				draw_line(Vector2(-4.5, 0.0), Vector2(4.5, 0.0), Color(0.85, 1.0, 0.88), 2.4)
				draw_line(Vector2(0.0, -4.5), Vector2(0.0, 4.5), Color(0.85, 1.0, 0.88), 2.4)

			"carrier":
				# Armored Brood Carrier: bulky bronze-amber hive hull cradling 6 glowing spawn sacs
				var hull_c := [Vector2(16.0, -6.5), Vector2(16.0, 6.5), Vector2(6.0, 16.0), Vector2(-12.0, 14.5), Vector2(-17.0, 0.0), Vector2(-12.0, -14.5), Vector2(6.0, -16.0)]
				_draw_poly_oriented(hull_c, ang, fill_color.darkened(0.28))
				var rib_c := [Vector2(11.5, -4.5), Vector2(11.5, 4.5), Vector2(2.0, 11.5), Vector2(-9.5, 10.0), Vector2(-9.5, -10.0), Vector2(2.0, -11.5)]
				_draw_poly_oriented(rib_c, ang, Color(0.52, 0.48, 0.44))
				for pod_i in range(6):
					var pa: float = float(pod_i) * TAU / 6.0 + ang
					var p_off: Vector2 = Vector2(cos(pa), sin(pa)) * 6.8
					var p_r: float = 2.6 + 0.6 * sin(anim_time * 7.0 + float(pod_i))
					draw_circle(p_off, p_r, Color(1.0, 0.72, 0.22) if pod_i % 2 == 0 else Color(0.28, 0.94, 1.0))
				draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.92, 0.65))

			"conduit":
				# Aegis Conduit: projects visible 95px golden-cyan protective shield dome to nearby allies!
				var dome_r: float = shield_aura_radius if shield_aura_radius > 0.0 else 95.0
				draw_circle(Vector2.ZERO, dome_r, Color(0.32, 0.88, 1.0, 0.07))
				draw_arc(Vector2.ZERO, dome_r, 0.0, TAU, 40, Color(0.98, 0.84, 0.34, 0.42), 1.8)
				draw_arc(Vector2.ZERO, dome_r - 3.5, anim_time * 1.4, anim_time * 1.4 + PI * 1.2, 32, Color(0.38, 0.96, 1.0, 0.52), 1.5)
				var hex_pts := PackedVector2Array()
				for hi in range(6):
					var ha: float = anim_time * 1.2 + float(hi) * TAU / 6.0
					hex_pts.append(Vector2(cos(ha), sin(ha)) * 13.5)
				draw_colored_polygon(hex_pts, Color(0.14, 0.32, 0.46))
				for hi in range(6):
					draw_line(hex_pts[hi], hex_pts[(hi + 1) % 6], Color(1.0, 0.88, 0.42), 2.0)
				draw_circle(Vector2.ZERO, 6.2 + 1.0 * sin(anim_time * 6.5), Color(0.45, 0.98, 1.0))
				draw_circle(Vector2.ZERO, 2.8, Color.WHITE)

	# Visual indicators for Conduit protection & Concussive Stun
	if is_shielded_by_conduit():
		draw_arc(Vector2.ZERO, radius + 3.2, 0.0, TAU, 18, Color(1.0, 0.88, 0.38, 0.78), 1.6)
	if stun_remaining > 0.0:
		for st_i in range(3):
			var sta: float = anim_time * 8.0 + float(st_i) * TAU / 3.0
			draw_circle(Vector2(cos(sta), sin(sta)) * (radius + 5.5), 2.2, Color(1.0, 0.94, 0.32))

	if is_inspected:
		var ip: float = 0.65 + 0.35 * sin(anim_time * 8.0)
		draw_arc(Vector2.ZERO, radius + 7.5, 0.0, TAU, 28, Color(0.45, 0.96, 1.0, ip), 2.2)

	# Armor Shred heat glow ring when debuffed
	if armor_shred_stacks > 0:
		draw_arc(Vector2.ZERO, radius + 2.5, 0.0, TAU, 20, Color(1.0, 0.45, 0.22, 0.75), 1.8)

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
