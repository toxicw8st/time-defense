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
var _auto_wave_countdown: float = 0.0
var _lives_at_wave_start: int = Balance.PLAYER_STARTING_LIVES
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
	if state == State.BUILD and GameState.auto_wave_enabled and not GameState.is_sandbox_mode and GameState.mission.wave_number > 1:
		if _auto_wave_countdown <= 0.0:
			_auto_wave_countdown = 2.5
		else:
			_auto_wave_countdown = maxf(0.0, _auto_wave_countdown - delta)
			if _auto_wave_countdown <= 0.0:
				start_wave()
				return
	else:
		_auto_wave_countdown = 0.0
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
	_auto_wave_countdown = 0.0
	_begin_wave_internal(GameState.mission.wave_number, is_replay)
	return true


func can_call_next_wave_early() -> bool:
	if GameState.mission.is_over or state != State.FIGHTING or GameState.is_sandbox_mode:
		return false
	if GameState.mission.wave_number >= max_waves_limit and not GameState.is_endless_mode:
		return false
	return true


func get_early_call_bonus() -> int:
	if not can_call_next_wave_early():
		return 0
	var active_cnt: int = map_ref.get_active_enemies().size() if map_ref != null else 0
	return clampi(5 + active_cnt * 2 + int(GameState.mission.wave_number / 3), 5, 35)


func call_next_wave_early() -> bool:
	if not can_call_next_wave_early():
		return false
	var bonus: int = get_early_call_bonus()
	var prev_w: int = GameState.mission.wave_number
	GameState.mission.cleared_waves[prev_w] = true
	GameState.mission.stats["waves_completed"] += 1
	GameState.add_money(bonus, true)
	if AnalyticsManager != null:
		AnalyticsManager.record_early_wave_call(prev_w + 1, bonus)
	GameState.event_logged.emit("EARLY WAVE CALL (+$%d bonus)! Launching Wave %d!" % [bonus, prev_w + 1])
	GameState.wave_cleared.emit(prev_w)
	GameState.mission.wave_number = prev_w + 1
	_begin_wave_internal(GameState.mission.wave_number, false)
	return true


func start_sandbox_wave(wave_num: int) -> bool:
	if GameState.mission.is_over:
		return false
	if map_ref != null:
		map_ref.clear_all_enemies()
	var w: int = clampi(wave_num, 1, 45)
	GameState.mission.wave_number = w
	_begin_wave_internal(w, false)
	GameState.event_logged.emit("[SANDBOX] Launched Wave %d" % w)
	return true


func restart_wave_for_rewind() -> void:
	if map_ref != null:
		map_ref.clear_all_enemies()
	GameState.mission.rewound_in_current_build_phase = true
	var target_wave: int = GameState.mission.wave_number
	if state == State.BUILD and _last_cleared_wave > 0:
		target_wave = _last_cleared_wave
		GameState.mission.wave_number = target_wave
	_begin_wave_internal(target_wave, true)


func _begin_wave_internal(wave_num: int, is_replay: bool) -> void:
	_is_replay_attempt = is_replay
	if is_replay:
		GameState.mission.replay_count_this_wave += 1
		# Replayed wave is EXACTLY as it was: do NOT apply newly added mutations during the replay
	else:
		GameState.mission.replay_count_this_wave = 0
		GameState.mission.rewound_in_current_build_phase = false
		GameState.mission.mutations["armoured_active_stacks"] = GameState.mission.mutations.get("armoured_stacks", 0)
		GameState.mission.mutations["thaw_hp_stacks"] = GameState.mission.mutations.get("thaw_stacks", 0)

	_post_wave_rewind_timer = 0.0
	if custom_waves_override.is_empty():
		_schedule = WavesData.build_spawn_schedule(wave_num)
	else:
		_schedule = WavesData.build_spawn_schedule(wave_num, custom_waves_override)
	_spawn_index = 0
	_wave_elapsed = 0.0
	_lives_at_wave_start = GameState.mission.lives
	state = State.SPAWNING
	GameState.is_wave_active = true
	state_changed.emit(state)
	GameState.wave_started.emit(wave_num)


func _complete_current_wave() -> void:
	state = State.CLEARED
	GameState.is_wave_active = false
	# Activate accumulated mutations AFTER wave clears so next NEW wave gets them
	GameState.mission.mutations["armoured_active_stacks"] = GameState.mission.mutations.get("armoured_stacks", 0)
	GameState.mission.mutations["thaw_hp_stacks"] = GameState.mission.mutations.get("thaw_stacks", 0)
	if not _is_replay_attempt:
		GameState.mission.rewound_in_current_build_phase = false
	state_changed.emit(state)

	var wave_num: int = GameState.mission.wave_number
	var stats: Dictionary = WavesData.compute_wave_stats(wave_num, GameState.get_enemy_hp_multiplier())
	var bonus: int = 0
	var stipend_part: int = 0
	var clean_part: int = 0
	var interest_part: int = 0
	var mint_part: int = 0
	if not GameState.mission.cleared_waves.get(wave_num, false):
		GameState.mission.cleared_waves[wave_num] = true
		GameState.record_best_wave(GameState.selected_map_level, wave_num)
		bonus = Balance.WAVE_CLEAR_BONUS_BASE + Balance.WAVE_CLEAR_BONUS_PER_WAVE * wave_num
		# Wave 11+ BTD5 wave-clear stipend (W1-10 remain exact $0!)
		if wave_num >= 11:
			stipend_part = Balance.POST_W10_WAVE_STIPEND_BASE + Balance.POST_W10_WAVE_STIPEND_PER_WAVE * wave_num
			bonus += stipend_part
		# Citadel Economy Sacrifice Chrono-Mint Core (+$350/w Stage 2, +$700/w Stage 3!)
		var eco_sac: int = int(GameState.mission.citadel_sacrifices.get("economy", 0))
		if eco_sac > 0:
			mint_part = 700 if eco_sac >= 2 else 350
			bonus += mint_part
		# Refinery Tech Tier 2+ Clean-Wave Bonus & Tier 3+ Compound Bank Interest (only when >=1 Refinery owned!)
		var ref_owned: int = int(GameState.mission.economy.get("refineries_owned", 0))
		var rtier_cfg: Dictionary = GameState.get_refinery_tier_cfg()
		if ref_owned >= 1 and GameState.get_refinery_tier() >= 2:
			var clean_pct: float = float(rtier_cfg.get("clean_wave_bonus_pct", 0.0))
			if clean_pct > 0.0 and GameState.mission.lives >= _lives_at_wave_start:
				clean_part = int(round(float(stats["b_dollars"]) * clean_pct))
				bonus += clean_part
			var int_pct: float = float(rtier_cfg.get("bank_interest_pct", 0.0))
			var int_cap: int = int(rtier_cfg.get("bank_interest_cap", 0))
			if int_pct > 0.0 and int_cap > 0:
				var cur_cash: int = int(GameState.mission.economy.get("money", 0))
				interest_part = mini(int_cap, int(floor(float(cur_cash) * int_pct)))
				bonus += interest_part
		if bonus > 0:
			GameState.add_money(bonus, true)
		GameState.mission.stats["waves_completed"] += 1
		GameState.economy_changed.emit()

	var summary: String = "Wave %d cleared! (b$%d)" % [wave_num, stats["b_dollars"]]
	if interest_part > 0 or stipend_part > 0 or clean_part > 0 or mint_part > 0:
		var bonus_bits: PackedStringArray = []
		if stipend_part > 0:
			bonus_bits.append("+$%d clear" % stipend_part)
		if clean_part > 0:
			bonus_bits.append("+$%d clean" % clean_part)
		if interest_part > 0:
			bonus_bits.append("+$%d bank" % interest_part)
		if mint_part > 0:
			bonus_bits.append("+$%d mint" % mint_part)
		summary += " [" + ", ".join(bonus_bits) + "]"
	wave_summary_updated.emit(summary)
	GameState.event_logged.emit(summary)
	GameState.wave_cleared.emit(wave_num)

	_last_cleared_wave = wave_num
	_post_wave_rewind_timer = Balance.TIME_POWERS["rewind"]["post_wave_window"]
	_last_seen_mutations = GameState.mission.mutations.duplicate()

	if wave_num >= max_waves_limit and not GameState.is_endless_mode:
		if GameState.is_sandbox_mode:
			state = State.BUILD
			state_changed.emit(state)
			return
		if not GameState.mission.is_over:
			GameState.mission.wave_number = wave_num + 1
			GameState.end_mission("won", "SECTOR MILESTONE CLEARED! Survived all %d waves — tap Continue Endless to push your Best Wave!" % max_waves_limit)
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
	if GameState.mission.rewound_in_current_build_phase:
		return false
	if state == State.BUILD:
		return _last_cleared_wave > 0
	return is_wave_active()


func get_preview_data(wave_override: int = -1) -> Dictionary:
	var wave_num: int = wave_override if wave_override >= 1 else GameState.mission.wave_number
	var counts: Dictionary = WavesData.get_wave_counts_by_type(wave_num)
	var m := GameState.mission.mutations
	var active_mutations: Array[Dictionary] = []

	var arm_stacks: int = int(m.get("armoured_stacks", 0))
	var arm_pct: int = int(round((pow(1.0 + Balance.TIME_POWERS["rewind"]["hp_bonus_per_stack"], arm_stacks) - 1.0) * 100.0))
	var thaw_stacks: int = int(m.get("thaw_stacks", 0))
	var thaw_hp_pct: int = int(round((pow(1.0 + Balance.TIME_POWERS["pause"]["eff_hp_bonus_per_stack"], thaw_stacks) - 1.0) * 100.0))
	var preview_hp_mult: float = pow(1.0 + Balance.TIME_POWERS["rewind"]["hp_bonus_per_stack"], arm_stacks) * pow(1.0 + Balance.TIME_POWERS["pause"]["eff_hp_bonus_per_stack"], thaw_stacks)
	var total_hp_pct: int = int(round((preview_hp_mult - 1.0) * 100.0))

	var defs := [
		{
			"key": "armoured_stacks",
			"label": "Armoured",
			"effect": "+%d%% alien HP (total x%.2f)" % [arm_pct, preview_hp_mult],
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
	var wdef: Dictionary = WavesData.get_wave_def(wave_num)
	return {
		"wave_number": wave_num,
		"counts": counts,
		"s_dollars": stats["s_dollars"],
		"b_dollars": stats["b_dollars"],
		"mutated_hp": stats["mutated_hp"],
		"dps_needed": stats["dps_needed"],
		"wave_length": stats["wave_length"],
		"active_mutations": active_mutations,
		"note": str(wdef.get("note", "")),
		"exam_title": str(wdef.get("exam_title", "")),
	}
