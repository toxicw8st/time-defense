extends Node
class_name WaveManager

enum State { BUILD, SPAWNING, FIGHTING, CLEARED }

signal state_changed(new_state: int)
signal wave_summary_updated(summary_text: String)

var state: int = State.BUILD
var map_ref: GameMap = null
var custom_waves_override: Array[Dictionary] = []
var max_waves_limit: int = WavesData.MISSION_TARGET_WAVE

var _schedule: Array[Dictionary] = []
var _spawn_index: int = 0
var _wave_elapsed: float = 0.0
var _is_replay_attempt: bool = false
var _last_cleared_wave: int = 0
var _post_wave_rewind_timer: float = 0.0
var _last_seen_mutations: Dictionary = {
	"armoured_stacks": 0,
	"thaw_stacks": 0,
	"swift_stacks": 0,
}


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
	state = State.BUILD
	GameState.is_wave_active = false
	_schedule.clear()
	_spawn_index = 0
	_wave_elapsed = 0.0
	_is_replay_attempt = false
	_last_cleared_wave = 0
	_post_wave_rewind_timer = 0.0
	_last_seen_mutations = {
		"armoured_stacks": 0,
		"thaw_stacks": 0,
		"swift_stacks": 0,
	}
	state_changed.emit(state)


func _process(delta: float) -> void:
	if GameState.mission.is_over:
		return
	var sim_dt: float = GameState.get_sim_delta(delta)
	if sim_dt <= 0.0:
		return
	if _post_wave_rewind_timer > 0.0:
		_post_wave_rewind_timer = maxf(0.0, _post_wave_rewind_timer - sim_dt)
	step_wave(sim_dt)


func step_wave(delta: float) -> void:
	if GameState.mission.is_over or delta <= 0.0:
		return

	if state == State.SPAWNING:
		_wave_elapsed += delta
		while _spawn_index < _schedule.size() and _wave_elapsed >= float(_schedule[_spawn_index]["time"]):
			var unit_type: String = _schedule[_spawn_index]["type"]
			if map_ref != null:
				map_ref.spawn_enemy(unit_type, GameState.mission.wave_number)
			_spawn_index += 1
		if _spawn_index >= _schedule.size():
			state = State.FIGHTING
			state_changed.emit(state)

	if state == State.FIGHTING:
		var remaining: int = map_ref.get_active_enemies().size() if map_ref != null else 0
		if remaining == 0:
			_complete_current_wave()


func start_wave(is_replay: bool = false) -> bool:
	if GameState.mission.is_over or state != State.BUILD:
		return false
	_begin_wave_internal(GameState.mission.wave_number, is_replay)
	return true


func restart_wave_for_rewind() -> void:
	if map_ref != null:
		map_ref.clear_all_enemies()
	var target_wave: int = GameState.mission.wave_number
	if state == State.BUILD and _last_cleared_wave > 0 and _post_wave_rewind_timer > 0.0:
		target_wave = _last_cleared_wave
		GameState.mission.wave_number = target_wave
	_begin_wave_internal(target_wave, true)


func _begin_wave_internal(wave_num: int, is_replay: bool) -> void:
	_is_replay_attempt = is_replay
	if is_replay:
		GameState.mission.replay_count_this_wave += 1
	else:
		GameState.mission.replay_count_this_wave = 0
		# Apply any Pause (Thaw-hardened +20% effective HP) stacks accumulated on previous waves
		GameState.mission.mutations["thaw_hp_stacks"] = GameState.mission.mutations.get("thaw_stacks", 0)

	_post_wave_rewind_timer = 0.0
	if custom_waves_override.is_empty():
		_schedule = WavesData.build_spawn_schedule(wave_num)
	else:
		_schedule = WavesData.build_spawn_schedule(wave_num, custom_waves_override)
	_spawn_index = 0
	_wave_elapsed = 0.0
	state = State.SPAWNING
	GameState.is_wave_active = true
	state_changed.emit(state)
	GameState.wave_started.emit(wave_num)


func _complete_current_wave() -> void:
	state = State.CLEARED
	GameState.is_wave_active = false
	# Activate any Pause HP stacks for the next wave immediately upon wave clear
	GameState.mission.mutations["thaw_hp_stacks"] = GameState.mission.mutations.get("thaw_stacks", 0)
	state_changed.emit(state)

	var wave_num: int = GameState.mission.wave_number
	var bonus: int = 0
	if not GameState.mission.cleared_waves.get(wave_num, false):
		GameState.mission.cleared_waves[wave_num] = true
		bonus = Balance.WAVE_CLEAR_BONUS_BASE + Balance.WAVE_CLEAR_BONUS_PER_WAVE * wave_num
		if bonus > 0:
			GameState.mission.economy["money"] += bonus
			GameState.mission.stats["money_earned"] += bonus
		GameState.mission.stats["waves_completed"] += 1
		GameState.economy_changed.emit()

	var stats: Dictionary = WavesData.compute_wave_stats(wave_num, GameState.get_enemy_hp_multiplier())
	var summary: String = "Wave %d cleared! (s$%d, b$%d)" % [wave_num, stats["s_dollars"], stats["b_dollars"]]
	if _is_replay_attempt:
		summary += " [Rewind Replay]"
	wave_summary_updated.emit(summary)
	GameState.event_logged.emit(summary)
	GameState.wave_cleared.emit(wave_num)

	_last_cleared_wave = wave_num
	_post_wave_rewind_timer = Balance.TIME_POWERS["rewind"]["post_wave_window"]
	_last_seen_mutations = GameState.mission.mutations.duplicate()

	if wave_num >= max_waves_limit:
		if not GameState.mission.is_over and GameState.mission.enemy_base_hp > 0:
			GameState.end_mission("stalled", "Survived %d waves, but the Enemy Base still stands." % max_waves_limit)
		return

	GameState.mission.wave_number = wave_num + 1
	state = State.BUILD
	state_changed.emit(state)


func is_wave_active() -> bool:
	return state == State.SPAWNING or state == State.FIGHTING


func is_replaying_wave() -> bool:
	return _is_replay_attempt and is_wave_active()


func can_rewind_now() -> bool:
	if GameState.mission.is_over or is_replaying_wave():
		return false
	if is_wave_active():
		return true
	return state == State.BUILD and _last_cleared_wave > 0 and _post_wave_rewind_timer > 0.0


func get_preview_data() -> Dictionary:
	var wave_num: int = GameState.mission.wave_number
	var counts: Dictionary = WavesData.get_wave_counts_by_type(wave_num)
	var m := GameState.mission.mutations
	var active_mutations: Array[Dictionary] = []

	var arm_pct: int = int(round((pow(1.0 + Balance.TIME_POWERS["rewind"]["hp_bonus_per_stack"], m.get("armoured_stacks", 0)) - 1.0) * 100.0))
	var thaw_stacks: int = int(m.get("thaw_stacks", 0))
	var thaw_hp_pct: int = int(round((pow(1.0 + Balance.TIME_POWERS["pause"]["eff_hp_bonus_per_stack"], thaw_stacks) - 1.0) * 100.0))
	var total_hp_pct: int = int(round((GameState.get_enemy_hp_multiplier() - 1.0) * 100.0))

	var defs := [
		{
			"key": "armoured_stacks",
			"label": "Armoured",
			"effect": "+%d%% alien HP (total x%.2f)" % [arm_pct, GameState.get_enemy_hp_multiplier()],
		},
		{
			"key": "thaw_stacks",
			"label": "Thaw-hardened",
			"effect": "+%d%% eff HP (-%d%% frozen dmg, total +%d%% HP)" % [thaw_hp_pct, int(minf(50.0, float(thaw_stacks) * 10.0)), total_hp_pct],
		},
		{
			"key": "swift_stacks",
			"label": "Swift",
			"effect": "+%d%% alien move speed" % int(round((pow(1.0 + Balance.TIME_POWERS["haste"]["speed_bonus_per_stack"], m.get("swift_stacks", 0)) - 1.0) * 100.0)),
		},
	]

	for d in defs:
		var stacks: int = m.get(d["key"], 0)
		if stacks > 0:
			active_mutations.append({
				"label": d["label"],
				"stacks": stacks,
				"effect": d["effect"],
				"is_new": stacks > _last_seen_mutations.get(d["key"], 0),
			})

	var stats: Dictionary = WavesData.compute_wave_stats(wave_num, GameState.get_enemy_hp_multiplier())
	return {
		"wave_number": wave_num,
		"counts": counts,
		"s_dollars": stats["s_dollars"],
		"b_dollars": stats["b_dollars"],
		"mutated_hp": stats["mutated_hp"],
		"dps_needed": stats["dps_needed"],
		"wave_length": stats["wave_length"],
		"active_mutations": active_mutations,
		"note": WavesData.get_wave_def(wave_num).get("note", ""),
	}
