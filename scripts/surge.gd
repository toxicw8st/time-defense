extends Node
class_name SurgeManager

## Owns the 5-wave Surge deadline (beginning of Wave 6 if no time power used in Waves 1-5;
## resets to +5 waves after any time power use) and the continuous Surge countdown bar.

signal surge_banner_triggered(banner_text: String)
signal warning_state_changed(warning_level: int) # 0 = normal, 1 = amber (<=15s), 2 = red pulse (<=7s)

var wave_manager_ref: WaveManager = null
var current_warning_level: int = 0
var _last_tick_second: int = -1


func setup(p_wm: WaveManager) -> void:
	wave_manager_ref = p_wm
	if not GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.connect(_on_mission_reset)
	if not GameState.time_power_used.is_connected(_on_time_power_used):
		GameState.time_power_used.connect(_on_time_power_used)
	if not GameState.wave_started.is_connected(_on_wave_started):
		GameState.wave_started.connect(_on_wave_started)
	_reset_state()


func _exit_tree() -> void:
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)
	if GameState.time_power_used.is_connected(_on_time_power_used):
		GameState.time_power_used.disconnect(_on_time_power_used)
	if GameState.wave_started.is_connected(_on_wave_started):
		GameState.wave_started.disconnect(_on_wave_started)


func _on_mission_reset() -> void:
	_reset_state()


func get_surge_wave_span() -> int:
	if GameState.mission.manipulator_level >= 4:
		return int(Balance.MANIPULATOR_UPGRADES[4]["surge_wave_span"])
	return Balance.SURGE_WAVE_SPAN


func get_surge_window() -> float:
	if GameState.mission.manipulator_level >= 4:
		return float(Balance.MANIPULATOR_UPGRADES[4]["surge_window"])
	return Balance.SURGE_BASE_WINDOW


func _reset_state() -> void:
	GameState.mission.surge_deadline_wave = 1 + get_surge_wave_span() # Wave 6 start initially
	GameState.mission.surge_timer_seconds = get_surge_window()
	current_warning_level = 0
	_last_tick_second = -1
	warning_state_changed.emit(0)


func _on_wave_started(wave_num: int) -> void:
	if GameState.mission.is_over:
		return
	# Enforce the 5-wave Surge deadline: beginning of Wave 6 if no time ability used in Waves 1-5
	if wave_num >= GameState.mission.surge_deadline_wave:
		_trigger_surge(wave_num)


func is_surge_paused() -> bool:
	if GameState.mission.is_over:
		return true
	if not GameState.is_wave_active:
		return true
	if GameState.is_base_locked() or GameState.is_base_charging():
		return true
	if wave_manager_ref != null and not wave_manager_ref.is_wave_active():
		return true
	return false


func _process(delta: float) -> void:
	step_surge(GameState.get_sim_delta(delta))


func step_surge(delta: float) -> void:
	if is_surge_paused() or delta <= 0.0:
		return

	GameState.mission.surge_timer_seconds -= delta
	if GameState.mission.surge_timer_seconds <= 0.0:
		_trigger_surge(GameState.mission.wave_number)
		return

	_update_warning_state()


func _update_warning_state() -> void:
	var rem: float = GameState.mission.surge_timer_seconds
	var next_level: int = 0
	if rem <= Balance.SURGE_WARNING_RED:
		next_level = 2
	elif rem <= Balance.SURGE_WARNING_AMBER:
		next_level = 1
	if next_level != current_warning_level:
		current_warning_level = next_level
		warning_state_changed.emit(next_level)

	if next_level == 2:
		var whole_sec: int = int(ceil(rem))
		if whole_sec != _last_tick_second:
			_last_tick_second = whole_sec


func _trigger_surge(current_wave: int = -1) -> void:
	var m := GameState.mission
	var w: int = current_wave if current_wave > 0 else m.wave_number
	m.surge_count += 1
	m.stats["surges_suffered"] += 1
	m.surge_deadline_wave = w + get_surge_wave_span()
	m.surge_timer_seconds = get_surge_window()
	current_warning_level = 0
	_last_tick_second = -1
	warning_state_changed.emit(0)

	var pct: int = int(round(pow(Balance.SURGE_ATTACK_SPEED_FACTOR, m.surge_count) * 100.0))
	var msg: String = "SURGE - All towers -5%% attack speed (now at %d%%) for the rest of this mission" % pct
	surge_banner_triggered.emit(msg)
	GameState.event_logged.emit(msg)
	GameState.surge_triggered.emit(m.surge_count)


func _on_time_power_used(_power_name: String) -> void:
	var m := GameState.mission
	# Using any power on Wave W gives 5 full subsequent waves before the next deadline (beginning of Wave W + 6)
	m.surge_deadline_wave = m.wave_number + get_surge_wave_span() + 1
	m.surge_timer_seconds = get_surge_window()
	current_warning_level = 0
	_last_tick_second = -1
	warning_state_changed.emit(0)
