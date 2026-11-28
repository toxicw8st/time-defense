extends Node
class_name TimePowersManager

## v3.0 Paid, Upgradable Time Abilities (Zero Surge, Zero Permanent Mutations!)
## - Time Freeze ("pause"): Cash-cast stasis freeze; upgrades add Cloaked reveal, +20..40% Brittle dmg, & T5 <15% shatter!
## - Overclock ("haste"): Cash-cast fire/build speed overdrive; upgrades add +65..125% speed, +15..30% bonus dmg, & T5 instant build!
## - Temporal Rewind ("rewind"): Cash-cast tactical path-pushback yanking ALL active aliens 18..48% backward along the track!

signal power_activated(power_name: String)
signal ability_upgraded(power_name: String, new_tier: int)
signal manipulator_upgraded(new_level: int)

var map_ref: GameMap = null
var wave_manager_ref: WaveManager = null
var snapshot_helper: SnapshotHelper = SnapshotHelper.new()

var pause_remaining: float = 0.0
var haste_remaining: float = 0.0
var cooldowns: Dictionary = {
	"rewind": 0.0,
	"pause": 0.0,
	"haste": 0.0,
}


func setup(p_map: GameMap, p_wm: WaveManager) -> void:
	map_ref = p_map
	wave_manager_ref = p_wm
	if not GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.connect(_on_mission_reset)
	_reset_state()


func _exit_tree() -> void:
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)


func _on_mission_reset() -> void:
	_reset_state()


func _reset_state() -> void:
	pause_remaining = 0.0
	haste_remaining = 0.0
	cooldowns = {"rewind": 0.0, "pause": 0.0, "haste": 0.0}
	GameState.is_enemies_frozen = false
	GameState.is_haste_active = false


func _process(delta: float) -> void:
	step_powers(GameState.get_sim_delta(delta))


func step_powers(delta: float) -> void:
	if GameState.mission.is_over:
		return

	var can_tick: bool = GameState.is_wave_active
	GameState.is_enemies_frozen = (pause_remaining > 0.0) and can_tick
	GameState.is_haste_active = (haste_remaining > 0.0) and can_tick

	if not can_tick or delta <= 0.0:
		return

	if pause_remaining > 0.0:
		pause_remaining = maxf(0.0, pause_remaining - delta)
		if pause_remaining <= 0.0:
			GameState.is_enemies_frozen = false
			cooldowns["pause"] = get_effective_cooldown("pause")
			if map_ref != null:
				for e in map_ref.get_active_enemies():
					e.queue_redraw()

	if haste_remaining > 0.0:
		haste_remaining = maxf(0.0, haste_remaining - delta)
		if haste_remaining <= 0.0:
			GameState.is_haste_active = false
			cooldowns["haste"] = get_effective_cooldown("haste")

	for key in ["rewind", "pause", "haste"]:
		if cooldowns[key] > 0.0:
			cooldowns[key] = maxf(0.0, cooldowns[key] - delta)


func get_cooldown_multiplier(power_name: String = "") -> float:
	var mult: float = 1.0
	var ranks: int = GameState.get_research_rank("efficient_manipulator")
	if ranks <= 0 and GameState.mission.owned_research.get("efficient_manipulator", false):
		ranks = 1
	if ranks > 0:
		mult *= maxf(0.35, 1.0 - float(ranks) * float(Balance.RESEARCH_NODES["efficient_manipulator"]["cooldown_reduction"]))
	if power_name != "":
		var tcfg: Dictionary = GameState.get_ability_tier_cfg(power_name)
		mult *= float(tcfg.get("cd_mult", 1.0))
	return mult


func get_effective_cooldown(power_name: String) -> float:
	var ab: Dictionary = Balance.TIME_ABILITIES.get(power_name, {})
	var base_cd: float = float(ab.get("cooldown", 45.0))
	return base_cd * get_cooldown_multiplier(power_name)


func get_cast_cost(power_name: String) -> int:
	return int(Balance.TIME_ABILITIES.get(power_name, {}).get("cast_cost", 75))


func get_pause_duration() -> float:
	return float(GameState.get_ability_tier_cfg("pause").get("duration", 6.0))


func get_haste_duration() -> float:
	return float(GameState.get_ability_tier_cfg("haste").get("duration", 16.0))


func can_use_power(power_name: String) -> bool:
	if GameState.mission.is_over or not GameState.is_wave_active:
		return false
	if cooldowns.get(power_name, 0.0) > 0.0:
		return false
	var cast_cost: int = get_cast_cost(power_name)
	if not GameState.is_sandbox_mode and GameState.mission.economy["money"] < cast_cost:
		return false
	match power_name:
		"pause":
			return pause_remaining <= 0.0
		"haste":
			return haste_remaining <= 0.0
		"rewind":
			return map_ref != null and not map_ref.get_active_enemies().is_empty()
	return false


func activate_power(power_name: String) -> bool:
	if not can_use_power(power_name):
		return false
	var cast_cost: int = get_cast_cost(power_name)
	if not GameState.spend_money(cast_cost, false):
		return false

	GameState.mission.stats["powers_used"][power_name] += 1
	if SfxManager != null:
		SfxManager.play("power")

	var tier: int = GameState.get_ability_level(power_name)
	var tcfg: Dictionary = GameState.get_ability_tier_cfg(power_name)
	var core_mult: float = GameState.get_citadel_damage_multiplier()

	match power_name:
		"pause":
			pause_remaining = get_pause_duration()
			GameState.is_enemies_frozen = true
			var rev_cloak: bool = bool(tcfg.get("reveals_cloaked", false))
			var shatter_pct: float = float(tcfg.get("shatter_pct", 0.0))
			var shattered: int = 0
			if map_ref != null:
				for e in map_ref.get_active_enemies():
					if not is_instance_valid(e) or not e.is_alive():
						continue
					if rev_cloak and e.is_cloaked_type:
						e.reveal_cloak(pause_remaining + 2.0)
					if shatter_pct > 0.0 and e.enemy_type != "juggernaut" and e.enemy_type != "colossus":
						if (e.hp / maxf(1.0, e.max_hp)) <= shatter_pct:
							e.take_damage(e.hp + 10.0, "Time", null)
							shattered += 1
							continue
					e.queue_redraw()
			var extra_f: String = (" | %d shattered!" % shattered) if shattered > 0 else ""
			GameState.event_logged.emit("TIME FREEZE T%d ($%d, %.1fs)%s" % [tier, cast_cost, pause_remaining, extra_f])

		"haste":
			haste_remaining = get_haste_duration()
			GameState.is_haste_active = true
			var spd_pct: int = int(round(float(tcfg.get("speed_bonus", 0.50)) * 100.0))
			var finished_cnt: int = 0
			if bool(tcfg.get("instant_builds", false)) and map_ref != null:
				for t in map_ref.get_all_towers():
					if t != null and is_instance_valid(t) and t.current_job != null:
						t.advance_tower(999.0)
						finished_cnt += 1
			var extra_h: String = (" | %d builds finished!" % finished_cnt) if finished_cnt > 0 else ""
			GameState.event_logged.emit("OVERCLOCK T%d ($%d, +%d%% spd %.0fs)%s" % [tier, cast_cost, spd_pct, haste_remaining, extra_h])

		"rewind":
			var push_pct: float = float(tcfg.get("pushback_pct", 0.18))
			var paradox_pct: float = float(tcfg.get("paradox_dmg_pct", 0.0)) * core_mult
			var strip_buffs: bool = bool(tcfg.get("strip_buffs", false))
			var stun_sec: float = float(tcfg.get("stun_sec", 0.0))
			var pulled: int = 0
			if map_ref != null:
				var plen: float = maxf(100.0, map_ref.get_path_length())
				var push_px: float = plen * push_pct
				for e in map_ref.get_active_enemies():
					if not is_instance_valid(e) or not e.is_alive():
						continue
					var old_pos: Vector2 = e.position
					e.distance_along_path = maxf(4.0, e.distance_along_path - push_px)
					e._sync_transform_to_path()
					if map_ref.has_method("spawn_rewind_trail"):
						map_ref.spawn_rewind_trail(old_pos, e.position)
					if strip_buffs:
						e.suppress_regen(6.0)
						if e.is_cloaked_type:
							e.reveal_cloak(5.0)
					if stun_sec > 0.0:
						e.apply_stun(stun_sec)
					if paradox_pct > 0.0:
						var p_dmg: float = maxf(10.0, e.hp * minf(0.45, paradox_pct))
						e.take_damage(p_dmg, "Time", null)
					pulled += 1
			cooldowns["rewind"] = get_effective_cooldown("rewind")
			GameState.event_logged.emit("TEMPORAL REWIND T%d ($%d) — Yanked %d aliens -%d%% backward!" % [tier, cast_cost, pulled, int(round(push_pct * 100.0))])

	GameState.time_power_used.emit(power_name)
	power_activated.emit(power_name)
	return true


func get_next_upgrade_cost(power_name: String) -> int:
	var cur: int = GameState.get_ability_level(power_name)
	if cur >= Balance.TIME_ABILITY_MAX_TIER:
		return -1
	return int(Balance.get_time_ability_tier_cfg(power_name, cur + 1).get("upgrade_cost", 9999))


func can_upgrade_ability(power_name: String) -> bool:
	if GameState.mission.is_over:
		return false
	var cost: int = get_next_upgrade_cost(power_name)
	if cost < 0:
		return false
	return GameState.is_sandbox_mode or GameState.mission.economy["money"] >= cost


func upgrade_ability(power_name: String) -> bool:
	if not can_upgrade_ability(power_name):
		return false
	var next_tier: int = GameState.get_ability_level(power_name) + 1
	var cost: int = get_next_upgrade_cost(power_name)
	if not GameState.spend_money(cost, true):
		return false
	GameState.mission.ability_levels[power_name] = next_tier
	if SfxManager != null:
		SfxManager.play("combine")
	var ab_name: String = str(Balance.TIME_ABILITIES[power_name]["name"])
	var tcfg: Dictionary = Balance.get_time_ability_tier_cfg(power_name, next_tier)
	GameState.event_logged.emit("ABILITY UPGRADED: %s -> T%d %s ($%d)!" % [ab_name, next_tier, str(tcfg.get("title", "")), cost])
	GameState.ability_upgraded.emit(power_name, next_tier)
	ability_upgraded.emit(power_name, next_tier)
	if AnalyticsManager != null:
		AnalyticsManager.record_ability_upgrade(power_name, next_tier, cost)
	return true


func can_upgrade_manipulator() -> bool:
	return false


func start_manipulator_upgrade() -> bool:
	return false
