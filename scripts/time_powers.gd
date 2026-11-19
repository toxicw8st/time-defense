extends Node
class_name TimePowersManager

## Owns Rewind, Pause, Haste (active durations, cooldowns, wave-1 readiness, manipulator downtime).
## All time-ability timers pause between waves (BUILD) and while Hive Destroyer is charging.

signal power_activated(power_name: String)
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
var _waiting_rewind_cooldown_after_replay: bool = false


func setup(p_map: GameMap, p_wm: WaveManager) -> void:
	map_ref = p_map
	wave_manager_ref = p_wm
	if not GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.connect(_on_mission_reset)
	if not GameState.wave_started.is_connected(_on_wave_started):
		GameState.wave_started.connect(_on_wave_started)
	if not GameState.wave_cleared.is_connected(_on_wave_cleared):
		GameState.wave_cleared.connect(_on_wave_cleared)
	_reset_state()


func _exit_tree() -> void:
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)
	if GameState.wave_started.is_connected(_on_wave_started):
		GameState.wave_started.disconnect(_on_wave_started)
	if GameState.wave_cleared.is_connected(_on_wave_cleared):
		GameState.wave_cleared.disconnect(_on_wave_cleared)


func _on_mission_reset() -> void:
	_reset_state()


func _reset_state() -> void:
	pause_remaining = 0.0
	haste_remaining = 0.0
	cooldowns = {"rewind": 0.0, "pause": 0.0, "haste": 0.0}
	_waiting_rewind_cooldown_after_replay = false
	GameState.is_enemies_frozen = false
	GameState.is_haste_active = false


func _on_wave_started(wave_num: int) -> void:
	snapshot_helper.capture_wave_start(wave_num)


func _on_wave_cleared(_wave_num: int) -> void:
	if _waiting_rewind_cooldown_after_replay:
		_waiting_rewind_cooldown_after_replay = false
		cooldowns["rewind"] = get_effective_cooldown("rewind")
	elif wave_manager_ref != null and not wave_manager_ref._is_replay_attempt:
		cooldowns["rewind"] = 0.0 # Rewind resets for next build phase after clearing a new wave


func _process(delta: float) -> void:
	step_powers(GameState.get_sim_delta(delta))


func step_powers(delta: float) -> void:
	if GameState.mission.is_over:
		return

	# Keep effect flags off whenever wave is paused (BUILD) or Hive Destroyer is charging
	var hive_charging: bool = GameState.is_base_charging()
	var can_tick_wave_timers: bool = GameState.is_wave_active and not hive_charging
	GameState.is_enemies_frozen = (pause_remaining > 0.0) and can_tick_wave_timers
	GameState.is_haste_active = (haste_remaining > 0.0) and can_tick_wave_timers

	# Between waves (BUILD) or paused: all ability timers, cooldowns, and manipulator upgrades pause
	if not GameState.is_wave_active or delta <= 0.0:
		return

	# Manipulator upgrade construction (pauses between waves, never hasted)
	if GameState.mission.manipulator_upgrading_remaining > 0.0:
		GameState.mission.manipulator_upgrading_remaining = maxf(0.0, GameState.mission.manipulator_upgrading_remaining - delta)
		if GameState.mission.manipulator_upgrading_remaining <= 0.0:
			GameState.mission.manipulator_level += 1
			var new_lvl: int = GameState.mission.manipulator_level
			manipulator_upgraded.emit(new_lvl)
			GameState.event_logged.emit("Manipulator upgraded to Level %d - powers online!" % new_lvl)

	# Hive Destroyer charging pauses all time abilities (active durations + cooldown recovery)
	if hive_charging:
		return

	# Active Pause effect
	if pause_remaining > 0.0:
		pause_remaining = maxf(0.0, pause_remaining - delta)
		if pause_remaining <= 0.0:
			GameState.is_enemies_frozen = false
			cooldowns["pause"] = get_effective_cooldown("pause")
			if map_ref != null:
				for e in map_ref.get_active_enemies():
					e.queue_redraw()

	# Active Haste effect
	if haste_remaining > 0.0:
		haste_remaining = maxf(0.0, haste_remaining - delta)
		if haste_remaining <= 0.0:
			GameState.is_haste_active = false
			cooldowns["haste"] = get_effective_cooldown("haste")

	# Cooldowns tick down only during active waves and when Hive Destroyer is NOT charging
	for key in ["rewind", "pause", "haste"]:
		if cooldowns[key] > 0.0:
			cooldowns[key] = maxf(0.0, cooldowns[key] - delta)


func get_cooldown_multiplier() -> float:
	var mult: float = 1.0
	if GameState.mission.manipulator_level >= 2:
		mult *= float(Balance.MANIPULATOR_UPGRADES[2]["cooldown_multiplier"])
	var ranks: int = GameState.get_research_rank("efficient_manipulator")
	if ranks <= 0 and GameState.mission.owned_research.get("efficient_manipulator", false):
		ranks = 1
	if ranks > 0:
		mult *= maxf(0.35, 1.0 - float(ranks) * float(Balance.RESEARCH_NODES["efficient_manipulator"]["cooldown_reduction"]))
	return mult


func get_effective_cooldown(power_name: String) -> float:
	var base_cd: float = float(Balance.TIME_POWERS[power_name]["cooldown"])
	return base_cd * get_cooldown_multiplier()


func get_pause_duration() -> float:
	if GameState.mission.manipulator_level >= 3:
		return float(Balance.MANIPULATOR_UPGRADES[3]["pause_duration"])
	return float(Balance.TIME_POWERS["pause"]["duration"])


func get_haste_duration() -> float:
	if GameState.mission.manipulator_level >= 3:
		return float(Balance.MANIPULATOR_UPGRADES[3]["haste_duration"])
	return float(Balance.TIME_POWERS["haste"]["duration"])


func can_use_power(power_name: String) -> bool:
	if GameState.mission.is_over or GameState.is_base_locked() or GameState.is_base_charging():
		return false
	if power_name == "rewind":
		if _waiting_rewind_cooldown_after_replay:
			return false
		if wave_manager_ref == null:
			return false
		if wave_manager_ref.state == WaveManager.State.BUILD:
			return wave_manager_ref.can_rewind_now()
		return cooldowns.get("rewind", 0.0) <= 0.0 and wave_manager_ref.can_rewind_now()

	if cooldowns.get(power_name, 0.0) > 0.0:
		return false

	match power_name:
		"pause":
			return GameState.is_wave_active and pause_remaining <= 0.0
		"haste":
			return GameState.is_wave_active and haste_remaining <= 0.0
	return false


func activate_power(power_name: String) -> bool:
	if not can_use_power(power_name):
		return false

	GameState.mission.stats["powers_used"][power_name] += 1

	match power_name:
		"pause":
			pause_remaining = get_pause_duration()
			GameState.is_enemies_frozen = true
			if map_ref != null:
				for e in map_ref.get_active_enemies():
					e.queue_redraw()
			GameState.event_logged.emit("PAUSE activated (%.0fs) - Aliens frozen. Towers keep firing." % pause_remaining)
		"haste":
			haste_remaining = get_haste_duration()
			GameState.is_haste_active = true
			GameState.event_logged.emit("HASTE activated (%.0fs) - Towers +50%% attack speed & +50%% build speed." % haste_remaining)
		"rewind":
			if pause_remaining > 0.0:
				pause_remaining = 0.0
				GameState.is_enemies_frozen = false
				cooldowns["pause"] = get_effective_cooldown("pause")
			_waiting_rewind_cooldown_after_replay = true
			snapshot_helper.execute_rewind(map_ref, wave_manager_ref)
			GameState.event_logged.emit("REWIND activated - Replaying wave %d (no new mutation); +5%% HP applies to next wave." % GameState.mission.wave_number)
			GameState.time_power_used.emit("rewind")
			power_activated.emit("rewind")
			return true

	GameState.time_power_used.emit(power_name)
	power_activated.emit(power_name)
	return true


func can_upgrade_manipulator() -> bool:
	if GameState.mission.is_over or GameState.is_base_locked() or GameState.is_base_charging():
		return false
	var lvl: int = GameState.mission.manipulator_level
	if lvl >= Balance.MANIPULATOR_MAX_LEVEL:
		return false
	var cost: int = int(Balance.MANIPULATOR_UPGRADES[lvl + 1]["cost"])
	return GameState.mission.economy["money"] >= cost


func start_manipulator_upgrade() -> bool:
	if not can_upgrade_manipulator():
		return false
	var next_lvl: int = GameState.mission.manipulator_level + 1
	var cfg: Dictionary = Balance.MANIPULATOR_UPGRADES[next_lvl]
	var cost: int = int(cfg["cost"])
	if not GameState.spend_money(cost, false):
		return false
	GameState.mission.manipulator_upgrading_remaining = float(cfg["build_time"])
	GameState.event_logged.emit("Manipulator queued for Lv%d ($%d, %.0fs in wave) - Powers OFFLINE, Base locked, Surge paused." % [
		next_lvl,
		cost,
		float(cfg["build_time"]),
	])
	return true
