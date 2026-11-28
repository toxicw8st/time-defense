extends Node
class_name BaseAttackManager

## v3.0 Chrono-Citadel Ascension ("Sun God" Base Super-Weapon Controller)
## Replaces legacy Hive Destroyer with the 3-Stage Awakened Player Citadel:
##   - Stage 1 ($1,500): Fortified Citadel — Twin Point-Defense Pulse Cannons (240px) + +3 Lives
##   - Stage 2 ($6,500 + Opt-In Tower Sacrifices): Chrono-Dreadnought — Global Orbital Lance + +15% Global Speed + Grafted Weapons
##   - Stage 3 ($18,000 + Opt-In Tower Sacrifices): ★ True Chrono-Singularity ("Time God") — 2.2x Power, +30% Global Speed, Hyper-Apex Grafts & 10s Singularity Pulse!

signal charge_started
signal base_attack_fired(damage: int, remaining_enemy_hp: int)
signal citadel_ascended(new_stage: int, sacrifices: Dictionary)

var map_ref: GameMap = null
var is_charging: bool = false
var charge_total_time: float = Balance.BASE_ATTACK_CHARGE_TIME
var charge_remaining: float = 0.0

# Citadel weapon cooldowns & live visual aim state
var aim_angle: float = PI
var pd_cooldown: float = 0.0
var lance_cooldown: float = 0.0
var kinetic_cooldown: float = 0.0
var explosive_cooldown: float = 0.0
var energy_cooldown: float = 0.0
var chrono_cooldown: float = 0.0
var pulse_cooldown: float = 10.0
var muzzle_flash_timer: float = 0.0


func setup(p_map: GameMap) -> void:
	map_ref = p_map
	if not GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.connect(_on_mission_reset)
	_reset_state()


func _exit_tree() -> void:
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)


func _on_mission_reset() -> void:
	_reset_state()


func _reset_state() -> void:
	is_charging = false
	charge_remaining = 0.0
	GameState.base_attack_charging_active = false
	aim_angle = PI
	pd_cooldown = 0.0
	lance_cooldown = 0.0
	kinetic_cooldown = 0.0
	explosive_cooldown = 0.0
	energy_cooldown = 0.0
	chrono_cooldown = 0.0
	pulse_cooldown = 10.0
	muzzle_flash_timer = 0.0


func _process(delta: float) -> void:
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer = maxf(0.0, muzzle_flash_timer - delta)
	step_base_attack(GameState.get_sim_delta(delta))


func step_base_attack(delta: float) -> void:
	if GameState.mission.is_over or not GameState.is_wave_active or delta <= 0.0 or map_ref == null:
		return
	var stage: int = GameState.mission.citadel_stage
	if stage <= 0:
		return

	var enemies: Array[EnemyUnit] = map_ref.get_active_enemies()
	if enemies.is_empty():
		return

	var pb_pos: Vector2 = map_ref.active_player_base_pos
	var base_stage_mult: float = 1.75 if stage >= 3 else 1.0
	var sac_stage_mult: float = 2.40 if stage >= 3 else 1.0
	var shared_mult: float = GameState.get_citadel_damage_multiplier() * (1.0 + GameState.get_overclock_crit_bonus())
	var core_mult: float = shared_mult * base_stage_mult
	var sac_mult: float = shared_mult * sac_stage_mult
	var spd_mult: float = GameState.get_tower_attack_speed_multiplier()
	var sacs: Dictionary = GameState.mission.citadel_sacrifices

	# 1) Stage 1+: Twin Point-Defense Pulse Cannons (240px local defense covering final approach)
	pd_cooldown = maxf(0.0, pd_cooldown - delta * spd_mult)
	if pd_cooldown <= 0.0:
		var pd_tgt: EnemyUnit = _pick_enemy(enemies, pb_pos, 250.0, "first")
		if pd_tgt != null:
			aim_angle = (pd_tgt.position - pb_pos).angle()
			muzzle_flash_timer = 0.16
			var pd_dtype: String = "Piercing" if (pd_tgt.armour_tags.has("Armored") or pd_tgt.armour_tags.has("Reflective")) else "Laser"
			var pd_dmg: float = (42.0 if stage == 1 else 66.0) * core_mult
			_fire_citadel_beam(pb_pos, pd_tgt, pd_dmg, pd_dtype, Color(0.38, 0.96, 1.0), 3.0)
			pd_cooldown = 0.45

	if stage < 2:
		return

	# 2) Stage 2+: Global Orbital Chrono-Lance (map-wide sniper!)
	lance_cooldown = maxf(0.0, lance_cooldown - delta * spd_mult)
	if lance_cooldown <= 0.0:
		var l_tgt: EnemyUnit = _pick_enemy(enemies, pb_pos, 99999.0, "strongest")
		if l_tgt != null:
			aim_angle = (l_tgt.position - pb_pos).angle()
			muzzle_flash_timer = 0.22
			var l_dmg: float = 165.0 * core_mult
			if l_tgt.is_cloaked_type:
				l_tgt.reveal_cloak(4.0)
			_fire_citadel_beam(pb_pos, l_tgt, l_dmg, "Time", Color(1.0, 0.88, 0.36), 4.8, true)
			lance_cooldown = 0.95

	# 3) Grafted Kinetic Sacrifice: Quad Sabot Boss-Shredder Autocannons
	var kin_lvl: int = int(sacs.get("kinetic", 0))
	if kin_lvl > 0:
		kinetic_cooldown = maxf(0.0, kinetic_cooldown - delta * spd_mult)
		if kinetic_cooldown <= 0.0:
			var k_tgt: EnemyUnit = _pick_enemy(enemies, pb_pos, 99999.0, "strongest")
			if k_tgt != null:
				var k_dmg: float = (115.0 if kin_lvl == 1 else 205.0) * sac_mult
				k_tgt.apply_armor_shred(5, 4.5)
				_fire_citadel_beam(pb_pos, k_tgt, k_dmg, "Piercing", Color(1.0, 0.72, 0.28), 3.4, true)
				kinetic_cooldown = 0.34 if kin_lvl >= 2 else 0.50

	# 4) Grafted Explosive Sacrifice: Map-Wide Orbital Cluster Barrage
	var exp_lvl: int = int(sacs.get("explosive", 0))
	if exp_lvl > 0:
		explosive_cooldown = maxf(0.0, explosive_cooldown - delta * spd_mult)
		if explosive_cooldown <= 0.0:
			var e_tgt: EnemyUnit = _pick_enemy(enemies, pb_pos, 99999.0, "first")
			if e_tgt != null:
				var shells: int = 4 if exp_lvl >= 2 else 3
				var blast_r: float = 96.0 if exp_lvl >= 2 else 78.0
				var blast_dmg: float = (160.0 if exp_lvl == 1 else 260.0) * sac_mult
				var center_p: Vector2 = e_tgt.position
				for si in range(shells):
					var off := Vector2(cos(float(si) * TAU / float(shells)), sin(float(si) * TAU / float(shells))) * (0.0 if si == 0 else 28.0)
					var bp: Vector2 = center_p + off
					map_ref.spawn_apex_shockwave(bp, Color(1.0, 0.58, 0.22), blast_r, 0.42)
					for foe in map_ref.get_active_enemies():
						if is_instance_valid(foe) and foe.is_alive() and foe.position.distance_to(bp) <= blast_r:
							_apply_citadel_damage(foe, blast_dmg, "Normal")
				explosive_cooldown = 2.0 if exp_lvl >= 2 else 2.6

	# 5) Grafted Energy Sacrifice: Triple Prismatic Sunbeams + Global Camo Reveal
	var ene_lvl: int = int(sacs.get("energy", 0))
	if ene_lvl > 0:
		energy_cooldown = maxf(0.0, energy_cooldown - delta * spd_mult)
		if energy_cooldown <= 0.0:
			var hits: int = 0
			var max_chains: int = 5 if ene_lvl >= 2 else 3
			var sun_dmg: float = (105.0 if ene_lvl == 1 else 175.0) * sac_mult
			for foe in enemies:
				if not is_instance_valid(foe) or not foe.is_alive():
					continue
				if foe.is_cloaked_type:
					foe.reveal_cloak(6.0)
				if hits < max_chains:
					_fire_citadel_beam(pb_pos, foe, sun_dmg, "Laser", Color(1.0, 0.45, 0.94), 3.6, true)
					hits += 1
			energy_cooldown = 0.46 if ene_lvl >= 2 else 0.68

	# 6) Grafted Chrono Sacrifice: Global Time-Dilation Field (-20%..30% slow + flat Time Decay)
	var chr_lvl: int = int(sacs.get("chrono", 0))
	if chr_lvl > 0:
		chrono_cooldown = maxf(0.0, chrono_cooldown - delta)
		if chrono_cooldown <= 0.0:
			var slow_v: float = 0.30 if chr_lvl >= 2 else 0.20
			var dec_v: float = (34.0 if chr_lvl == 1 else 68.0) * sac_mult
			for foe in enemies:
				if is_instance_valid(foe) and foe.is_alive():
					foe.apply_slow(slow_v, 2.2)
					foe.apply_time_decay(dec_v, 2, null)
					foe.suppress_regen(2.2)
			chrono_cooldown = 1.6

	# 7) Stage 3 ★ True Chrono-Singularity Pulse every 10s (Pushback 12% + <15% Boss Execute!)
	if stage >= 3:
		pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
		if pulse_cooldown <= 0.0:
			pulse_cooldown = 10.0
			map_ref.spawn_apex_shockwave(pb_pos, Color(1.0, 0.88, 0.34), 320.0, 0.85)
			map_ref.trigger_screen_shake(0.24, 3.2)
			var plen: float = maxf(100.0, map_ref.get_path_length())
			for foe in map_ref.get_active_enemies():
				if not is_instance_valid(foe) or not foe.is_alive():
					continue
				foe.distance_along_path = maxf(4.0, foe.distance_along_path - plen * 0.12)
				foe._sync_transform_to_path()
				if (foe.hp / maxf(1.0, foe.max_hp)) <= 0.15:
					map_ref.spawn_floater(foe.position + Vector2(-28.0, -24.0), "TIME GOD EXECUTE!", Color(1.0, 0.88, 0.32))
					_apply_citadel_damage(foe, foe.hp + 10.0, "Time")
				else:
					_apply_citadel_damage(foe, 190.0 * core_mult, "Time")


func _pick_enemy(enemies: Array[EnemyUnit], origin: Vector2, max_range: float, mode: String) -> EnemyUnit:
	var best: EnemyUnit = null
	var can_see_all: bool = GameState.mission.citadel_stage >= 2 or GameState.has_global_camo_reveal()
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if e.is_effectively_cloaked() and not can_see_all:
			continue
		if max_range < 50000.0 and origin.distance_to(e.position) > max_range:
			continue
		if best == null:
			best = e
			continue
		if mode == "strongest":
			if e.max_hp > best.max_hp or (is_equal_approx(e.max_hp, best.max_hp) and e.distance_along_path > best.distance_along_path):
				best = e
		else:
			if e.distance_along_path > best.distance_along_path:
				best = e
	return best


func _apply_citadel_damage(target: EnemyUnit, raw_dmg: float, dtype: String) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	var dealt: float = target.take_damage(raw_dmg, dtype, null)
	GameState.mission.citadel_total_damage += dealt
	if target.is_dead_or_leaked:
		GameState.mission.citadel_total_kills += 1


func _fire_citadel_beam(from_pos: Vector2, target: EnemyUnit, raw_dmg: float, dtype: String, col: Color, width: float, strip_aura: bool = false) -> void:
	if map_ref == null or target == null or not is_instance_valid(target) or not target.is_alive():
		return
	var end_pos: Vector2 = target.position
	if strip_aura and target.is_shielded_by_conduit():
		raw_dmg /= 0.65 # Bypass Conduit -35% aura
	_apply_citadel_damage(target, raw_dmg, dtype)
	if map_ref.has_method("spawn_citadel_beam"):
		map_ref.spawn_citadel_beam(from_pos, end_pos, col, width)


func get_next_citadel_stage() -> int:
	var cur: int = GameState.mission.citadel_stage
	return (cur + 1) if cur < Balance.CITADEL_MAX_STAGE else -1


func get_next_citadel_cost() -> int:
	var nxt: int = get_next_citadel_stage()
	if nxt < 0:
		return -1
	return int(Balance.CITADEL_STAGES[nxt]["cost"])


func can_ascend_citadel() -> bool:
	if GameState.mission.is_over:
		return false
	var cost: int = get_next_citadel_cost()
	if cost < 0:
		return false
	return GameState.is_sandbox_mode or GameState.mission.economy["money"] >= cost


## Computes which Sacrifice Super-Weapons would unlock/upgrade given a chosen set of towers & refinery option.
func preview_sacrifice_unlocks(selected_towers: Array, sacrifice_refinery: bool = false) -> Dictionary:
	var spent_by_cat: Dictionary = {"kinetic": 0, "explosive": 0, "energy": 0, "chrono": 0}
	for t in selected_towers:
		if t == null or not is_instance_valid(t):
			continue
		var cats: Array[String] = Balance.get_tower_sacrifice_categories(t.tower_type)
		for c in cats:
			spent_by_cat[c] = int(spent_by_cat.get(c, 0)) + int(t.total_spent)
	var unlocked: Dictionary = {}
	for c in ["kinetic", "explosive", "energy", "chrono"]:
		unlocked[c] = int(spent_by_cat[c]) >= Balance.CITADEL_SACRIFICE_THRESHOLD
	unlocked["economy"] = sacrifice_refinery and int(GameState.mission.economy.get("refineries_owned", 0)) >= 1
	return {
		"spent_by_cat": spent_by_cat,
		"unlocked": unlocked,
	}


func ascend_citadel(selected_towers: Array = [], sacrifice_refinery: bool = false) -> bool:
	if not can_ascend_citadel():
		return false
	var next_stage: int = get_next_citadel_stage()
	var scfg: Dictionary = Balance.CITADEL_STAGES[next_stage]
	var cost: int = int(scfg["cost"])
	if not GameState.spend_money(cost, true):
		return false

	# Process opt-in tower sacrifices for Stage 2 & Stage 3!
	var unlocked_cats: Array[String] = []
	if bool(scfg.get("supports_sacrifice", false)):
		var prev: Dictionary = preview_sacrifice_unlocks(selected_towers, sacrifice_refinery)
		var unl: Dictionary = prev["unlocked"]
		for t in selected_towers:
			if t != null and is_instance_valid(t) and map_ref != null:
				if map_ref.has_method("absorb_tower_into_citadel"):
					map_ref.absorb_tower_into_citadel(t)
		if sacrifice_refinery and int(GameState.mission.economy.get("refineries_owned", 0)) > 0:
			GameState.mission.economy["refineries_owned"] = maxi(0, int(GameState.mission.economy["refineries_owned"]) - 1)
		for c in ["kinetic", "explosive", "energy", "chrono", "economy"]:
			if bool(unl.get(c, false)):
				var target_lvl: int = 2 if next_stage >= 3 else 1
				GameState.mission.citadel_sacrifices[c] = maxi(int(GameState.mission.citadel_sacrifices.get(c, 0)), target_lvl)
				unlocked_cats.append(c)
			elif next_stage >= 3 and int(GameState.mission.citadel_sacrifices.get(c, 0)) >= 1:
				# Stage 3 automatically promotes previously grafted Stage-2 weapons to Hyper-Apex!
				GameState.mission.citadel_sacrifices[c] = 2

	GameState.mission.citadel_stage = next_stage
	var heal_amt: int = int(scfg.get("heal_lives", 0))
	if heal_amt > 0:
		GameState.restore_lives(heal_amt)

	if SfxManager != null:
		SfxManager.play("combine")
	if map_ref != null:
		var sw_col := Color(1.0, 0.88, 0.34) if next_stage >= 3 else (Color(0.45, 0.96, 1.0) if next_stage == 2 else Color(0.42, 0.92, 0.72))
		map_ref.spawn_apex_shockwave(map_ref.active_player_base_pos, sw_col, 140.0 + float(next_stage) * 55.0, 0.85)
		map_ref.trigger_screen_shake(0.32, 3.8 + float(next_stage))
		if map_ref.has_method("trigger_hit_stop"):
			map_ref.trigger_hit_stop(0.06, 0.08)
		map_ref.spawn_floater(map_ref.active_player_base_pos + Vector2(-72.0, -48.0), "%s ONLINE!" % str(scfg["name"]).to_upper(), sw_col)
		map_ref.queue_redraw()

	var sac_str: String = (" | Grafted: " + ", ".join(unlocked_cats)) if not unlocked_cats.is_empty() else ""
	GameState.event_logged.emit("CITADEL ASCENDED -> Stage %d %s ($%d)%s!" % [next_stage, str(scfg["name"]), cost, sac_str])
	GameState.citadel_upgraded.emit(next_stage)
	citadel_ascended.emit(next_stage, GameState.mission.citadel_sacrifices.duplicate())
	return true


# Legacy compatibility getters (prevent null/method errors in older scripts)
func get_charge_duration() -> float:
	return Balance.BASE_ATTACK_CHARGE_TIME

func get_shot_damage() -> int:
	return Balance.BASE_ATTACK_TEST_DAMAGE_OVERRIDE

func get_shots_to_destroy_remaining() -> int:
	return 0

func can_start_charge() -> bool:
	return can_ascend_citadel()

func start_charge() -> bool:
	return ascend_citadel()

func is_in_firing_warning() -> bool:
	return false

func get_charge_progress() -> float:
	return float(GameState.mission.citadel_stage) / float(Balance.CITADEL_MAX_STAGE)
