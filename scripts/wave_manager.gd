extends Node
class_name WaveManager

enum State { BUILD, SPAWNING, FIGHTING, CLEARED }

signal state_changed(new_state: int)
signal wave_summary_updated(summary_text: String)

var state: int = State.BUILD
var map_ref: GameMap = null
var custom_waves_override: Array[Dictionary] = []

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
	if _post_wave_rewind_timer > 0.0:
		_post_wave_rewind_timer = maxf(0.0, _post_wave_rewind_timer - delta)
	step_wave(delta)


func step_wave(delta: float) -> void:
	if GameState.mission.is_over:
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
	state_changed.emit(state)

	var wave_num: int = GameState.mission.wave_number
	var bonus: int = 0
	if not GameState.mission.cleared_waves.get(wave_num, false):
		GameState.mission.cleared_waves[wave_num] = true
		bonus = Balance.WAVE_CLEAR_BONUS_BASE + Balance.WAVE_CLEAR_BONUS_PER_WAVE * wave_num
		GameState.mission.economy["money"] += bonus
		GameState.mission.stats["money_earned"] += bonus
		GameState.mission.stats["waves_completed"] += 1
		GameState.economy_changed.emit()

	var summary: String = "Wave %d cleared!" % wave_num
	if bonus > 0:
		summary += " +%d money bonus." % bonus
	else:
		summary += " (Replay: wave bonus already claimed)"
	wave_summary_updated.emit(summary)
	GameState.event_logged.emit(summary)
	GameState.wave_cleared.emit(wave_num)

	_last_cleared_wave = wave_num
	_post_wave_rewind_timer = Balance.TIME_POWERS["rewind"]["post_wave_window"]

	# Snapshot mutations seen at the end of the cleared wave so newly gained ones show NEW next preview.
	_last_seen_mutations = GameState.mission.mutations.duplicate()

	if wave_num >= WavesData.get_wave_count():
		if not GameState.mission.is_over and GameState.mission.enemy_base_hp > 0:
			GameState.end_mission("stalled", "Survived 15 waves, but the Enemy Base still stands.")
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

	var defs := [
		{
			"key": "armoured_stacks",
			"label": "Armoured",
			"effect": "+%d%% alien HP" % int(round((GameState.get_enemy_hp_multiplier() - 1.0) * 100.0)),
		},
		{
			"key": "thaw_stacks",
			"label": "Thaw-hardened",
			"effect": "-%d%% damage while frozen" % int(minf(50.0, float(m.get("thaw_stacks", 0)) * 10.0)),
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

	return {
		"wave_number": wave_num,
		"counts": counts,
		"active_mutations": active_mutations,
		"note": WavesData.get_wave_def(wave_num).get("note", ""),
	}
