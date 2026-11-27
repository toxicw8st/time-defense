extends Node

## Playtest Analytics & Cloud Balance Feedback Loop Autoload
## Captures real gameplay runs including:
##   - Patch version tagging (Balance.BALANCE_VERSION) for before/after comparisons
##   - Enemy & Boss path penetration % (measures how close waves actually got) + Challenge Score (0-100)
##   - Player behavior telemetry (zone heatmap, upgrade/merge habits, 1x/2x/3x speed usage, feature usage)
##   - Wave-by-wave leaks/cash, per-tower Dmg/$, build-order timeline, and automated diagnostics
## Persists locally to user://timedefense_analytics.json (+ localStorage on Web) and silently
## auto-syncs runs to the isolated public.timedefense_runs Supabase table across Web, Android, & Desktop.

signal analytics_updated

const SCHEMA_VERSION: int = 2
const ANALYTICS_FILE_PATH: String = "user://timedefense_analytics.json"
const PLAYER_ID_FILE_PATH: String = "user://timedefense_player_id.txt"
const MAX_STORED_RUNS: int = 60
const MAX_EVENTS_PER_RUN: int = 260

# Dedicated TimeDefense telemetry section on user's Supabase project (RLS-isolated public.timedefense_runs)
const SUPABASE_URL: String = "https://ojtcgdsryjylpryevurl.supabase.co"
const SUPABASE_ANON_KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9qdGNnZHNyeWp5bHByeWV2dXJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3NDEzOTUsImV4cCI6MjEwNDMxNzM5NX0.WCTmrNwn3P2j-NemAk4Vu6ZTzVYcMIglqde5UjR3gjI"
const SUPABASE_TABLE: String = "timedefense_runs"

var runs: Array = []
var current_run: Dictionary = {}
var player_id: String = "anon_local"
var cloud_sync_enabled: bool = true
var cloud_sync_status: String = "Idle"
var _synced_run_hashes: Dictionary = {}
var _pending_native_queue: Array = []
var _http_request: HTTPRequest = null
var _http_busy: bool = false

var _active_wave_rec: Dictionary = {}
var _active_wave_open: bool = false
var _session_counter: int = 0
var _map_ref: WeakRef = null
var suppress_default_persistence: bool = false
var _pending_guide_events: Array[Dictionary] = []


func _ready() -> void:
	_init_player_id()
	if DisplayServer.get_name() != "headless":
		load_analytics()
		if not OS.has_feature("web"):
			_http_request = HTTPRequest.new()
			_http_request.timeout = 12.0
			add_child(_http_request)
			_http_request.request_completed.connect(_on_native_http_completed)
	_connect_signals()
	_start_new_run()


func _process(delta: float) -> void:
	if current_run.is_empty() or GameState.mission == null or GameState.mission.is_over:
		return
	if delta <= 0.0 or delta > 1.0:
		return
	if GameState.is_speed_paused:
		return
	if GameState.is_wave_active:
		var spd: float = GameState.game_speed
		var bucket: String = "1x"
		if spd >= 3.75:
			bucket = "1.5x"
		elif spd <= 2.1:
			bucket = "0.5x"
		var st: Dictionary = current_run["speed_time_sec"]
		st[bucket] = float(st.get(bucket, 0.0)) + delta
		current_run["_speed_weighted_sum"] = float(current_run.get("_speed_weighted_sum", 0.0)) + delta * (spd / Balance.DEFAULT_GAME_SPEED)
		current_run["_speed_total_real_sec"] = float(current_run.get("_speed_total_real_sec", 0.0)) + delta
	elif int(current_run.get("waves_started", 0)) > 0:
		current_run["build_phase_sec"] = float(current_run.get("build_phase_sec", 0.0)) + delta


func _input(event: InputEvent) -> void:
	if current_run.is_empty():
		return
	var tap_pos := Vector2(-1.0, -1.0)
	var is_touch_ev: bool = false
	if event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
		is_touch_ev = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return # Avoid double-counting touch-emulated mouse clicks
		tap_pos = event.position
	if tap_pos.x < 0.0 or tap_pos.y < 0.0:
		return
	var vp: Viewport = get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1280.0, 720.0)
	record_screen_tap(tap_pos, vp_size, is_touch_ev)


func _init_player_id() -> void:
	if DisplayServer.get_name() == "headless":
		player_id = "headless_test"
		return
	if OS.has_feature("web"):
		var web_pid = JavaScriptBridge.eval("window.ttdGetOrCreatePlayerId ? window.ttdGetOrCreatePlayerId() : ''")
		if web_pid is String and web_pid != "":
			player_id = web_pid
			return
	if FileAccess.file_exists(PLAYER_ID_FILE_PATH):
		var f := FileAccess.open(PLAYER_ID_FILE_PATH, FileAccess.READ)
		if f != null:
			var existing: String = f.get_as_text().strip_edges()
			f.close()
			if existing != "":
				player_id = existing
				return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	player_id = "p_%d_%06x" % [int(Time.get_unix_time_from_system()), rng.randi_range(0, 0xFFFFFF)]
	var wf := FileAccess.open(PLAYER_ID_FILE_PATH, FileAccess.WRITE)
	if wf != null:
		wf.store_string(player_id)
		wf.close()


func _connect_signals() -> void:
	if not GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.connect(_on_mission_reset)
	if not GameState.wave_started.is_connected(_on_wave_started):
		GameState.wave_started.connect(_on_wave_started)
	if not GameState.wave_cleared.is_connected(_on_wave_cleared):
		GameState.wave_cleared.connect(_on_wave_cleared)
	if not GameState.enemy_killed.is_connected(_on_enemy_killed):
		GameState.enemy_killed.connect(_on_enemy_killed)
	if not GameState.enemy_leaked.is_connected(_on_enemy_leaked):
		GameState.enemy_leaked.connect(_on_enemy_leaked)
	if not GameState.time_power_used.is_connected(_on_time_power_used):
		GameState.time_power_used.connect(_on_time_power_used)
	if not GameState.surge_triggered.is_connected(_on_surge_triggered):
		GameState.surge_triggered.connect(_on_surge_triggered)
	if not GameState.mission_ended.is_connected(_on_mission_ended):
		GameState.mission_ended.connect(_on_mission_ended)


func set_map_ref(p_map: Node) -> void:
	_map_ref = weakref(p_map) if p_map != null else null


func _get_platform_tag() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("ios"):
		return "ios"
	return "desktop"


func _iso_now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


func _start_new_run() -> void:
	_session_counter += 1
	var unix_ts: int = int(Time.get_unix_time_from_system())
	var run_id: String = "%s_%d_%d" % [player_id.substr(0, 12), unix_ts, _session_counter]
	var m := GameState.mission
	current_run = {
		"run_id": run_id,
		"schema_version": SCHEMA_VERSION,
		"balance_version": Balance.BALANCE_VERSION,
		"player_id": player_id,
		"started_at": _iso_now(),
		"ended_at": "",
		"platform": _get_platform_tag(),
		"level": GameState.selected_map_level,
		"level_name": str(GameState.get_level_cfg().get("name", "Level %d" % GameState.selected_map_level)),
		"shots_required": GameState.selected_mission_level,
		"difficulty": GameState.difficulty_key,
		"is_sandbox": GameState.is_sandbox_mode,
		"outcome": "in_progress",
		"end_reason": "",
		"max_wave_reached": 1,
		"waves_started": 0,
		"waves_completed": 0,
		"endless_reached": false,
		"duration_sim_sec": 0.0,
		"build_phase_sec": 0.0,
		"lives_remaining": m.lives if m != null else Balance.PLAYER_STARTING_LIVES,
		"lives_lost_total": 0,
		"enemy_base_hp_remaining": m.enemy_base_hp if m != null else Balance.ENEMY_BASE_MAX_HP,
		"charges_started": 0,
		"charges_fired": 0,
		"surges_suffered": 0,
		"refineries_owned": 0,
		"manipulator_level": 1,
		"early_calls": 0,
		"early_call_bonus_total": 0,
		"money_earned": 0,
		"money_unspent_end": int(m.economy.get("money", 0)) if m != null else 0,
		"avg_unspent_cash": 0.0,
		"total_spent_towers": 0,
		"sell_refunds_total": 0,
		"research_earned": 0,
		# Path penetration & challenge metrics
		"max_enemy_progress_pct": 0.0,
		"avg_kill_progress_pct": 0.0,
		"max_boss_progress_pct": 0.0,
		"boss_kill_progress_sum": 0.0,
		"boss_kill_count": 0,
		"kill_progress_sum": 0.0,
		"kill_progress_count": 0,
		"challenge_score": 0,
		# Player behavior metrics
		"zone_builds": {},
		"upgrade_counts": {"damage": 0, "range": 0, "fire_rate": 0},
		"combine_methods": {"drag_shop": 0, "two_tower": 0},
		"speed_time_sec": {"0.5x": 0.0, "1x": 0.0, "1.5x": 0.0},
		"avg_game_speed": 1.0,
		"_speed_weighted_sum": 0.0,
		"_speed_total_real_sec": 0.0,
		"feature_usage": {
			"target_mode_changes": 0,
			"recipes_opened": 0,
			"enemies_inspected": 0,
		},
		# UI button & screen tap heatmap telemetry
		"ui_telemetry": {
			"button_presses": {},
			"disabled_taps": {},
			"tap_grid_landscape": {},
			"tap_grid_portrait": {},
			"total_taps": 0,
			"touch_taps": 0,
			"scroll_events": 0,
			"viewport_profile": {
				"width": 1280,
				"height": 720,
				"orientation": "landscape",
				"is_touch": false,
			},
			"guide_stats": {
				"beats_shown": 0,
				"dismissed_at": "",
				"completed": false,
			},
			"zoom_stats": {
				"pinch_count": 0,
				"wheel_count": 0,
				"button_count": 0,
				"pan_count": 0,
				"max_zoom": 1.0,
			},
		},
		"meta_ranks_start": GameState.meta_research_ranks.duplicate(true),
		"mutations_end": {"armoured": 0, "thaw": 0, "swift": 0},
		"powers_used": {"rewind": 0, "pause": 0, "haste": 0},
		"kills_by_enemy": {},
		"leaks_by_enemy": {},
		"tower_stats": {},
		"wave_log": [],
		"events": [],
	}
	_active_wave_rec = {}
	_active_wave_open = false
	if not _pending_guide_events.is_empty():
		var carry: Array[Dictionary] = _pending_guide_events.duplicate(true)
		_pending_guide_events.clear()
		for ev in carry:
			_apply_guide_event_to_current(str(ev.get("kind", "")), str(ev.get("beat_id", "")))


func _is_run_meaningful(r: Dictionary) -> bool:
	if r.is_empty():
		return false
	if int(r.get("waves_started", 0)) > 0:
		return true
	if int(r.get("waves_completed", 0)) > 0:
		return true
	var evs: Array = r.get("events", [])
	return evs.size() >= 2


func compute_run_challenge_score(r: Dictionary) -> int:
	# 0-30: Too Easy / Stomp | 31-65: Moderate | 66-88: Sweet Spot / Tense | 89-100: Brutal
	var lives_lost: float = float(r.get("lives_lost_total", 0))
	var lives_score: float = clampf((lives_lost / float(Balance.PLAYER_STARTING_LIVES)) * 42.0, 0.0, 42.0)
	var max_pen: float = float(r.get("max_enemy_progress_pct", 0.0))
	var avg_pen: float = float(r.get("avg_kill_progress_pct", 0.0))
	var boss_pen: float = float(r.get("max_boss_progress_pct", 0.0))
	var pen_score: float = clampf((max_pen * 0.20) + (avg_pen * 0.16) + (boss_pen * 0.12), 0.0, 44.0)
	var surges: float = float(r.get("surges_suffered", 0))
	var surge_score: float = clampf(surges * 5.0, 0.0, 10.0)
	var outcome_bonus: float = 10.0 if str(r.get("outcome", "")) == "lost" else 0.0
	var avg_spd: float = float(r.get("avg_game_speed", 1.0))
	var speed_ease_penalty: float = clampf((avg_spd - 2.0) * 6.0, 0.0, 6.0) if lives_lost == 0.0 else 0.0
	return clampi(int(round(lives_score + pen_score + surge_score + outcome_bonus - speed_ease_penalty)), 0, 100)


func _clean_run_for_export(r: Dictionary) -> Dictionary:
	var snap: Dictionary = r.duplicate(true)
	snap.erase("_speed_weighted_sum")
	snap.erase("_speed_total_real_sec")
	snap.erase("kill_progress_sum")
	snap.erase("kill_progress_count")
	snap.erase("boss_kill_progress_sum")
	snap.erase("boss_kill_count")
	var st: Dictionary = snap.get("speed_time_sec", {})
	for k in st.keys():
		st[k] = snappedf(float(st[k]), 0.1)
	snap["build_phase_sec"] = snappedf(float(snap.get("build_phase_sec", 0.0)), 0.1)
	return snap


func _sync_run_snapshot() -> void:
	if current_run.is_empty() or GameState.mission == null:
		return
	var m := GameState.mission
	if int(current_run.get("waves_started", 0)) == 0 and str(current_run.get("outcome", "")) == "in_progress":
		current_run["level"] = GameState.selected_map_level
		current_run["level_name"] = str(GameState.get_level_cfg().get("name", "Level %d" % GameState.selected_map_level))
		current_run["shots_required"] = GameState.selected_mission_level
		current_run["difficulty"] = GameState.difficulty_key
	# Sticky sandbox taint: once a run has used Sandbox mode, it never pollutes real balance telemetry
	current_run["is_sandbox"] = bool(current_run.get("is_sandbox", false)) or GameState.is_sandbox_mode
	current_run["max_wave_reached"] = maxi(int(current_run.get("max_wave_reached", 1)), int(m.wave_number))
	current_run["waves_completed"] = maxi(int(current_run.get("waves_completed", 0)), int(m.stats.get("waves_completed", 0)))
	current_run["endless_reached"] = bool(current_run.get("endless_reached", false)) or GameState.is_endless_mode
	current_run["duration_sim_sec"] = snappedf(GameState.mission_elapsed_seconds, 0.1)
	current_run["lives_remaining"] = int(m.lives)
	current_run["enemy_base_hp_remaining"] = int(m.enemy_base_hp)
	current_run["charges_fired"] = int(m.stats.get("charges_fired", 0))
	current_run["surges_suffered"] = int(m.surge_count)
	current_run["refineries_owned"] = int(m.economy.get("refineries_owned", 0))
	current_run["manipulator_level"] = int(m.manipulator_level)
	current_run["money_earned"] = int(m.stats.get("money_earned", 0))
	current_run["money_unspent_end"] = int(m.economy.get("money", 0))
	current_run["research_earned"] = int(m.stats.get("research_earned", 0))

	var wl: Array = current_run.get("wave_log", [])
	if not wl.is_empty():
		var sum_cash: float = 0.0
		for rec in wl:
			sum_cash += float(rec.get("money_end", 0))
		current_run["avg_unspent_cash"] = snappedf(sum_cash / float(wl.size()), 1.0)
	else:
		current_run["avg_unspent_cash"] = float(m.economy.get("money", 0))

	var kc: int = int(current_run.get("kill_progress_count", 0))
	if kc > 0:
		current_run["avg_kill_progress_pct"] = snappedf(float(current_run.get("kill_progress_sum", 0.0)) / float(kc), 0.1)
	current_run["max_enemy_progress_pct"] = snappedf(float(current_run.get("max_enemy_progress_pct", 0.0)), 0.1)
	current_run["max_boss_progress_pct"] = snappedf(float(current_run.get("max_boss_progress_pct", 0.0)), 0.1)

	var spd_tot: float = float(current_run.get("_speed_total_real_sec", 0.0))
	if spd_tot > 0.01:
		current_run["avg_game_speed"] = snappedf(float(current_run.get("_speed_weighted_sum", spd_tot)) / spd_tot, 0.01)
	else:
		current_run["avg_game_speed"] = snappedf(GameState.game_speed / Balance.DEFAULT_GAME_SPEED, 0.01)

	current_run["mutations_end"] = {
		"armoured": int(m.mutations.get("armoured_stacks", 0)),
		"thaw": int(m.mutations.get("thaw_stacks", 0)),
		"swift": int(m.mutations.get("swift_stacks", 0)),
	}
	var pu: Dictionary = m.stats.get("powers_used", {})
	current_run["powers_used"] = {
		"rewind": int(pu.get("rewind", 0)),
		"pause": int(pu.get("pause", 0)),
		"haste": int(pu.get("haste", 0)),
	}
	current_run["challenge_score"] = compute_run_challenge_score(current_run)


func _upsert_current_run() -> Dictionary:
	if not _is_run_meaningful(current_run):
		return {}
	_sync_run_snapshot()
	var rid: String = str(current_run.get("run_id", ""))
	var snap: Dictionary = _clean_run_for_export(current_run)
	var replaced: bool = false
	for i in range(runs.size()):
		if str(runs[i].get("run_id", "")) == rid:
			runs[i] = snap
			replaced = true
			break
	if not replaced:
		runs.append(snap)
	while runs.size() > MAX_STORED_RUNS:
		runs.remove_at(0)
	analytics_updated.emit()
	return snap


func _ensure_tower_bucket(tower_type: String) -> Dictionary:
	var ts: Dictionary = current_run["tower_stats"]
	if not ts.has(tower_type):
		var tname: String = str(Balance.TOWERS.get(tower_type, {}).get("name", tower_type))
		ts[tower_type] = {
			"name": tname,
			"is_combo": Balance.is_combo_tower(tower_type),
			"built": 0,
			"sold": 0,
			"spent": 0,
			"damage": 0.0,
			"kills": 0,
			"upgrades": {"damage": 0, "range": 0, "fire_rate": 0},
			"max_lvl": {"damage": 0, "range": 0, "fire_rate": 0},
		}
	return ts[tower_type]


func _log_event(ev_name: String, extra: Dictionary = {}) -> void:
	if current_run.is_empty():
		return
	var evs: Array = current_run["events"]
	if evs.size() >= MAX_EVENTS_PER_RUN:
		return
	var rec := {
		"t": snappedf(GameState.mission_elapsed_seconds, 0.1),
		"w": int(GameState.mission.wave_number) if GameState.mission != null else 1,
		"ev": ev_name,
	}
	for k in extra.keys():
		rec[k] = extra[k]
	evs.append(rec)


func _count_live_towers() -> Dictionary:
	var total: int = 0
	var combos: int = 0
	if _map_ref != null:
		var m = _map_ref.get_ref()
		if m != null and is_instance_valid(m) and m.has_method("get_all_towers"):
			for t in m.get_all_towers():
				total += 1
				if Balance.is_combo_tower(t.tower_type):
					combos += 1
	return {"total": total, "combos": combos}


func _close_active_wave(completed: bool) -> void:
	if not _active_wave_open or _active_wave_rec.is_empty():
		return
	var m := GameState.mission
	var tc: Dictionary = _count_live_towers()
	var end_t: float = GameState.mission_elapsed_seconds
	_active_wave_rec["completed"] = completed
	_active_wave_rec["duration_sec"] = snappedf(maxf(0.0, end_t - float(_active_wave_rec.get("started_at", end_t))), 0.1)
	_active_wave_rec["money_end"] = int(m.economy.get("money", 0)) if m != null else 0
	_active_wave_rec["lives_end"] = int(m.lives) if m != null else 0
	_active_wave_rec["lives_lost"] = maxi(0, int(_active_wave_rec.get("lives_start", 0)) - int(_active_wave_rec["lives_end"]))
	_active_wave_rec["tower_count"] = int(tc["total"])
	_active_wave_rec["combo_count"] = int(tc["combos"])
	var wkc: int = int(_active_wave_rec.get("_kill_prog_cnt", 0))
	_active_wave_rec["avg_kill_progress_pct"] = snappedf(float(_active_wave_rec.get("_kill_prog_sum", 0.0)) / float(wkc), 0.1) if wkc > 0 else 0.0
	_active_wave_rec["max_progress_pct"] = snappedf(float(_active_wave_rec.get("max_progress_pct", 0.0)), 0.1)
	_active_wave_rec["max_boss_progress_pct"] = snappedf(float(_active_wave_rec.get("max_boss_progress_pct", 0.0)), 0.1)
	var clean_w: Dictionary = _active_wave_rec.duplicate(true)
	clean_w.erase("_kill_prog_sum")
	clean_w.erase("_kill_prog_cnt")
	current_run["wave_log"].append(clean_w)
	_active_wave_rec = {}
	_active_wave_open = false


# --- Signal Handlers ---

func _on_mission_reset() -> void:
	if not current_run.is_empty() and str(current_run.get("outcome", "")) == "in_progress" and _is_run_meaningful(current_run):
		_close_active_wave(false)
		current_run["outcome"] = "abandoned"
		current_run["end_reason"] = "Restarted or switched level"
		current_run["ended_at"] = _iso_now()
		var snap: Dictionary = _upsert_current_run()
		save_analytics()
		if not snap.is_empty():
			sync_run_to_supabase(snap)
	_start_new_run()


func _on_wave_started(wave_num: int) -> void:
	if current_run.is_empty():
		_start_new_run()
	if _active_wave_open:
		_close_active_wave(false)
	var m := GameState.mission
	var tc: Dictionary = _count_live_towers()
	current_run["waves_started"] = int(current_run.get("waves_started", 0)) + 1
	current_run["max_wave_reached"] = maxi(int(current_run.get("max_wave_reached", 1)), wave_num)
	_active_wave_rec = {
		"wave": wave_num,
		"started_at": snappedf(GameState.mission_elapsed_seconds, 0.1),
		"duration_sec": 0.0,
		"completed": false,
		"replayed": (m != null and int(m.replay_count_this_wave) > 0),
		"money_start": int(m.economy.get("money", 0)) if m != null else 0,
		"money_end": int(m.economy.get("money", 0)) if m != null else 0,
		"assets_start": int(m.total_assets_spent) if m != null else 0,
		"lives_start": int(m.lives) if m != null else Balance.PLAYER_STARTING_LIVES,
		"lives_end": int(m.lives) if m != null else Balance.PLAYER_STARTING_LIVES,
		"lives_lost": 0,
		"max_progress_pct": 0.0,
		"avg_kill_progress_pct": 0.0,
		"max_boss_progress_pct": 0.0,
		"_kill_prog_sum": 0.0,
		"_kill_prog_cnt": 0,
		"leaks_by_enemy": {},
		"kills_by_enemy": {},
		"powers_used": {"rewind": 0, "pause": 0, "haste": 0},
		"surges": 0,
		"early_called": false,
		"tower_count": int(tc["total"]),
		"combo_count": int(tc["combos"]),
	}
	_active_wave_open = true


func _on_wave_cleared(wave_num: int) -> void:
	if current_run.is_empty():
		return
	_close_active_wave(true)
	var snap: Dictionary = _upsert_current_run()
	save_analytics()
	# If this is the final wave and Enemy Base still stands, mission_ended("stalled") fires immediately after — let it send the final authoritative upsert!
	var will_stall_now: bool = (
		wave_num >= WavesData.MISSION_TARGET_WAVE
		and not GameState.is_endless_mode
		and not GameState.is_sandbox_mode
		and GameState.mission != null
		and GameState.mission.enemy_base_hp > 0
	)
	if not snap.is_empty() and not will_stall_now:
		sync_run_to_supabase(snap)


func _on_enemy_killed(enemy_type: String, _money_gained: int, _research_gained: int, _world_pos: Vector2) -> void:
	if current_run.is_empty():
		return
	var kdict: Dictionary = current_run["kills_by_enemy"]
	kdict[enemy_type] = int(kdict.get(enemy_type, 0)) + 1
	if _active_wave_open:
		var wk: Dictionary = _active_wave_rec["kills_by_enemy"]
		wk[enemy_type] = int(wk.get(enemy_type, 0)) + 1


func _on_enemy_leaked(enemy_type: String, lives_lost: int, _world_pos: Vector2) -> void:
	if current_run.is_empty():
		return
	current_run["lives_lost_total"] = int(current_run.get("lives_lost_total", 0)) + lives_lost
	var ldict: Dictionary = current_run["leaks_by_enemy"]
	ldict[enemy_type] = int(ldict.get(enemy_type, 0)) + lives_lost
	if _active_wave_open:
		var wl: Dictionary = _active_wave_rec["leaks_by_enemy"]
		wl[enemy_type] = int(wl.get(enemy_type, 0)) + lives_lost
	record_enemy_progress(enemy_type, 100.0, true)
	_log_event("leak", {
		"enemy": enemy_type,
		"lives_lost": lives_lost,
		"lives_left": int(GameState.mission.lives) if GameState.mission != null else 0,
	})


func _on_time_power_used(power_name: String) -> void:
	if current_run.is_empty():
		return
	if _active_wave_open:
		var wp: Dictionary = _active_wave_rec["powers_used"]
		wp[power_name] = int(wp.get(power_name, 0)) + 1
	_log_event("power", {
		"name": power_name,
		"lives": int(GameState.mission.lives) if GameState.mission != null else 0,
	})


func _on_surge_triggered(surge_count: int) -> void:
	if current_run.is_empty():
		return
	if _active_wave_open:
		_active_wave_rec["surges"] = int(_active_wave_rec.get("surges", 0)) + 1
	_log_event("surge", {"count": surge_count})


func _on_mission_ended(outcome: String, reason: String) -> void:
	if current_run.is_empty():
		return
	_close_active_wave(outcome == "won")
	current_run["outcome"] = outcome
	current_run["end_reason"] = reason
	current_run["ended_at"] = _iso_now()
	var snap: Dictionary = _upsert_current_run()
	save_analytics()
	if not snap.is_empty():
		sync_run_to_supabase(snap)


# --- Direct Gameplay & Behavior Instrumentation Hooks ---

func record_enemy_progress(enemy_type: String, progress_pct: float, leaked: bool = false) -> void:
	if current_run.is_empty():
		return
	var p: float = clampf(progress_pct, 0.0, 100.0)
	current_run["max_enemy_progress_pct"] = maxf(float(current_run.get("max_enemy_progress_pct", 0.0)), p)
	var is_boss: bool = (enemy_type == "juggernaut" or enemy_type == "colossus")
	if is_boss:
		current_run["max_boss_progress_pct"] = maxf(float(current_run.get("max_boss_progress_pct", 0.0)), p)
		if not leaked:
			current_run["boss_kill_progress_sum"] = float(current_run.get("boss_kill_progress_sum", 0.0)) + p
			current_run["boss_kill_count"] = int(current_run.get("boss_kill_count", 0)) + 1
	if not leaked:
		current_run["kill_progress_sum"] = float(current_run.get("kill_progress_sum", 0.0)) + p
		current_run["kill_progress_count"] = int(current_run.get("kill_progress_count", 0)) + 1
	if _active_wave_open:
		_active_wave_rec["max_progress_pct"] = maxf(float(_active_wave_rec.get("max_progress_pct", 0.0)), p)
		if is_boss:
			_active_wave_rec["max_boss_progress_pct"] = maxf(float(_active_wave_rec.get("max_boss_progress_pct", 0.0)), p)
		if not leaked:
			_active_wave_rec["_kill_prog_sum"] = float(_active_wave_rec.get("_kill_prog_sum", 0.0)) + p
			_active_wave_rec["_kill_prog_cnt"] = int(_active_wave_rec.get("_kill_prog_cnt", 0)) + 1


func record_tower_build(tower_type: String, cost: int, zone_label: String = "") -> void:
	if current_run.is_empty():
		return
	var b: Dictionary = _ensure_tower_bucket(tower_type)
	b["built"] = int(b["built"]) + 1
	b["spent"] = int(b["spent"]) + cost
	current_run["total_spent_towers"] = int(current_run.get("total_spent_towers", 0)) + cost
	var zkey: String = zone_label if zone_label != "" else "UNLABELED"
	var zb: Dictionary = current_run["zone_builds"]
	zb[zkey] = int(zb.get(zkey, 0)) + 1
	_log_event("build", {"type": tower_type, "cost": cost, "zone": zkey})


func record_tower_combine(type_a: String, type_b: String, combo_type: String, added_cost: int, combo_total_spent: int, method: String = "drag_shop") -> void:
	if current_run.is_empty():
		return
	var b: Dictionary = _ensure_tower_bucket(combo_type)
	b["built"] = int(b["built"]) + 1
	b["spent"] = int(b["spent"]) + maxi(added_cost, combo_total_spent)
	current_run["total_spent_towers"] = int(current_run.get("total_spent_towers", 0)) + maxi(0, added_cost)
	var cm: Dictionary = current_run["combine_methods"]
	cm[method] = int(cm.get(method, 0)) + 1
	_log_event("combine", {"a": type_a, "b": type_b, "result": combo_type, "cost": added_cost, "method": method})


func record_tower_upgrade(tower_type: String, stat_key: String, new_level: int, cost: int) -> void:
	if current_run.is_empty():
		return
	var b: Dictionary = _ensure_tower_bucket(tower_type)
	b["spent"] = int(b["spent"]) + cost
	b["upgrades"][stat_key] = int(b["upgrades"].get(stat_key, 0)) + 1
	b["max_lvl"][stat_key] = maxi(int(b["max_lvl"].get(stat_key, 0)), new_level)
	var uc: Dictionary = current_run["upgrade_counts"]
	uc[stat_key] = int(uc.get(stat_key, 0)) + 1
	current_run["total_spent_towers"] = int(current_run.get("total_spent_towers", 0)) + cost
	_log_event("upgrade", {"type": tower_type, "stat": stat_key, "lvl": new_level, "cost": cost})


func record_tower_sell(tower_type: String, refund: int, lifetime_dmg: float, lifetime_kills: int) -> void:
	if current_run.is_empty():
		return
	var b: Dictionary = _ensure_tower_bucket(tower_type)
	b["sold"] = int(b["sold"]) + 1
	current_run["sell_refunds_total"] = int(current_run.get("sell_refunds_total", 0)) + refund
	_log_event("sell", {"type": tower_type, "refund": refund, "dmg": int(round(lifetime_dmg)), "kills": lifetime_kills})


func record_tower_combat(tower_type: String, dealt_dmg: float, killed: bool) -> void:
	if current_run.is_empty() or (dealt_dmg <= 0.0 and not killed):
		return
	var b: Dictionary = _ensure_tower_bucket(tower_type)
	b["damage"] = float(b["damage"]) + maxf(0.0, dealt_dmg)
	if killed:
		b["kills"] = int(b["kills"]) + 1


func record_feature_used(feature_key: String) -> void:
	if current_run.is_empty():
		return
	var fu: Dictionary = current_run["feature_usage"]
	fu[feature_key] = int(fu.get(feature_key, 0)) + 1


func record_viewport_profile(vp_size: Vector2, is_touch: bool = false) -> void:
	if current_run.is_empty() or not current_run.has("ui_telemetry"):
		return
	var ui: Dictionary = current_run["ui_telemetry"]
	var orient: String = "portrait" if vp_size.y > vp_size.x else "landscape"
	ui["viewport_profile"] = {
		"width": int(round(vp_size.x)),
		"height": int(round(vp_size.y)),
		"orientation": orient,
		"is_touch": is_touch or bool(ui["viewport_profile"].get("is_touch", false)),
	}


func record_button_press(button_id: String, was_disabled: bool = false) -> void:
	if current_run.is_empty() or button_id == "" or not current_run.has("ui_telemetry"):
		return
	var ui: Dictionary = current_run["ui_telemetry"]
	var target_dict: Dictionary = ui["disabled_taps"] if was_disabled else ui["button_presses"]
	target_dict[button_id] = int(target_dict.get(button_id, 0)) + 1


func record_screen_tap(screen_pos: Vector2, vp_size: Vector2, is_touch: bool = false) -> void:
	if current_run.is_empty() or vp_size.x <= 1.0 or vp_size.y <= 1.0 or not current_run.has("ui_telemetry"):
		return
	var ui: Dictionary = current_run["ui_telemetry"]
	ui["total_taps"] = int(ui.get("total_taps", 0)) + 1
	if is_touch:
		ui["touch_taps"] = int(ui.get("touch_taps", 0)) + 1
		ui["viewport_profile"]["is_touch"] = true
	var nx: float = clampf(screen_pos.x / vp_size.x, 0.0, 0.9999)
	var ny: float = clampf(screen_pos.y / vp_size.y, 0.0, 0.9999)
	var is_portrait: bool = vp_size.y > vp_size.x
	var cols: int = 9 if is_portrait else 16
	var rows: int = 16 if is_portrait else 9
	var gx: int = clampi(int(floor(nx * float(cols))), 0, cols - 1)
	var gy: int = clampi(int(floor(ny * float(rows))), 0, rows - 1)
	var cell_key: String = "%d,%d" % [gx, gy]
	var grid: Dictionary = ui["tap_grid_portrait"] if is_portrait else ui["tap_grid_landscape"]
	grid[cell_key] = int(grid.get(cell_key, 0)) + 1


func record_ui_scroll() -> void:
	if current_run.is_empty() or not current_run.has("ui_telemetry"):
		return
	var ui: Dictionary = current_run["ui_telemetry"]
	ui["scroll_events"] = int(ui.get("scroll_events", 0)) + 1


func _apply_guide_event_to_current(kind: String, beat_id: String = "") -> void:
	if current_run.is_empty() or not current_run.has("ui_telemetry"):
		return
	var gs: Dictionary = current_run["ui_telemetry"]["guide_stats"]
	if kind == "shown":
		gs["beats_shown"] = int(gs.get("beats_shown", 0)) + 1
	elif kind == "dismissed":
		gs["dismissed_at"] = beat_id
	elif kind == "completed":
		gs["completed"] = true


func record_guide_event(kind: String, beat_id: String = "") -> void:
	# Startup menu Vex interactions happen BEFORE Start Level resets the mission into the real run,
	# so also queue pre-wave startup events to carry over into the launched run!
	if current_run.is_empty() or (beat_id == "startup" and int(current_run.get("waves_started", 0)) == 0):
		_pending_guide_events.append({"kind": kind, "beat_id": beat_id})
	_apply_guide_event_to_current(kind, beat_id)


func record_zoom_event(source: String, zoom_level: float) -> void:
	if current_run.is_empty() or not current_run.has("ui_telemetry"):
		return
	var ui: Dictionary = current_run["ui_telemetry"]
	if not ui.has("zoom_stats"):
		ui["zoom_stats"] = {"pinch_count": 0, "wheel_count": 0, "button_count": 0, "pan_count": 0, "max_zoom": 1.0}
	var zs: Dictionary = ui["zoom_stats"]
	match source:
		"pinch":
			zs["pinch_count"] = int(zs.get("pinch_count", 0)) + 1
		"wheel":
			zs["wheel_count"] = int(zs.get("wheel_count", 0)) + 1
		"button":
			zs["button_count"] = int(zs.get("button_count", 0)) + 1
		"pan":
			zs["pan_count"] = int(zs.get("pan_count", 0)) + 1
	var prev_max: float = float(zs.get("max_zoom", 1.0))
	if zoom_level > prev_max:
		zs["max_zoom"] = snappedf(zoom_level, 0.01)


func record_refinery_started(cost: int, next_count: int) -> void:
	if current_run.is_empty():
		return
	_log_event("refinery", {"count": next_count, "cost": cost})


func record_refinery_tier_upgraded(new_tier: int, cost: int) -> void:
	if current_run.is_empty():
		return
	current_run["refinery_tier"] = new_tier
	_log_event("refinery_tier", {"tier": new_tier, "cost": cost})


func record_research_bought(node_key: String, new_rank: int, cost: int) -> void:
	if current_run.is_empty():
		return
	_log_event("research", {"node": node_key, "rank": new_rank, "cost": cost})


func record_manipulator_upgrade(next_lvl: int, cost: int) -> void:
	if current_run.is_empty():
		return
	_log_event("manipulator", {"lvl": next_lvl, "cost": cost})


func record_hive_charge_started(cost: int) -> void:
	if current_run.is_empty():
		return
	current_run["charges_started"] = int(current_run.get("charges_started", 0)) + 1
	_log_event("hive_charge", {"cost": cost})


func record_hive_shot(dmg: int, remaining_hp: int) -> void:
	if current_run.is_empty():
		return
	_log_event("hive_shot", {"dmg": dmg, "hp_left": remaining_hp})


func record_early_wave_call(next_wave: int, bonus: int) -> void:
	if current_run.is_empty():
		return
	current_run["early_calls"] = int(current_run.get("early_calls", 0)) + 1
	current_run["early_call_bonus_total"] = int(current_run.get("early_call_bonus_total", 0)) + bonus
	if _active_wave_open:
		_active_wave_rec["early_called"] = true
	_log_event("early_call", {"next_w": next_wave, "bonus": bonus})


func record_endless_continue() -> void:
	if current_run.is_empty():
		return
	current_run["endless_reached"] = true
	current_run["outcome"] = "in_progress"
	_log_event("endless_start", {})
	var snap: Dictionary = _upsert_current_run()
	save_analytics()
	if not snap.is_empty():
		sync_run_to_supabase(snap)


# --- Supabase Row Builder & Silent Cloud Sync ---

func build_supabase_row(r: Dictionary) -> Dictionary:
	var clean: Dictionary = _clean_run_for_export(r)
	var ended_str: String = str(clean.get("ended_at", ""))
	return {
		"run_id": str(clean.get("run_id", "")),
		"balance_version": str(clean.get("balance_version", Balance.BALANCE_VERSION)),
		"player_id": str(clean.get("player_id", player_id)),
		"platform": str(clean.get("platform", _get_platform_tag())),
		"started_at": str(clean.get("started_at", _iso_now())),
		"updated_at": _iso_now(),
		"ended_at": ended_str if ended_str != "" else null,
		"level": clampi(int(clean.get("level", 1)), 1, 5),
		"level_name": str(clean.get("level_name", "Level 1")),
		"difficulty": str(clean.get("difficulty", "standard")),
		"is_sandbox": bool(clean.get("is_sandbox", false)),
		"outcome": str(clean.get("outcome", "in_progress")),
		"end_reason": str(clean.get("end_reason", "")),
		"max_wave_reached": int(clean.get("max_wave_reached", 1)),
		"waves_started": int(clean.get("waves_started", 0)),
		"waves_completed": int(clean.get("waves_completed", 0)),
		"endless_reached": bool(clean.get("endless_reached", false)),
		"duration_sim_sec": snappedf(float(clean.get("duration_sim_sec", 0.0)), 0.1),
		"build_phase_sec": snappedf(float(clean.get("build_phase_sec", 0.0)), 0.1),
		"lives_remaining": int(clean.get("lives_remaining", 0)),
		"lives_lost_total": int(clean.get("lives_lost_total", 0)),
		"enemy_base_hp_remaining": int(clean.get("enemy_base_hp_remaining", 0)),
		"charges_fired": int(clean.get("charges_fired", 0)),
		"surges_suffered": int(clean.get("surges_suffered", 0)),
		"refineries_owned": int(clean.get("refineries_owned", 0)),
		"manipulator_level": int(clean.get("manipulator_level", 1)),
		"early_calls": int(clean.get("early_calls", 0)),
		"money_earned": int(clean.get("money_earned", 0)),
		"money_unspent_end": int(clean.get("money_unspent_end", 0)),
		"avg_unspent_cash": snappedf(float(clean.get("avg_unspent_cash", 0.0)), 0.1),
		"max_enemy_progress_pct": snappedf(float(clean.get("max_enemy_progress_pct", 0.0)), 0.1),
		"avg_kill_progress_pct": snappedf(float(clean.get("avg_kill_progress_pct", 0.0)), 0.1),
		"max_boss_progress_pct": snappedf(float(clean.get("max_boss_progress_pct", 0.0)), 0.1),
		"challenge_score": clampi(int(clean.get("challenge_score", 0)), 0, 100),
		"avg_game_speed": snappedf(float(clean.get("avg_game_speed", 1.0)), 0.01),
		"payload": clean,
	}


func sync_run_to_supabase(run_snap: Dictionary) -> bool:
	if not cloud_sync_enabled or SUPABASE_URL == "" or SUPABASE_ANON_KEY == "":
		return false
	if DisplayServer.get_name() == "headless" or suppress_default_persistence:
		return false
	if run_snap.is_empty() or str(run_snap.get("run_id", "")) == "":
		return false

	var row: Dictionary = build_supabase_row(run_snap)
	var body_json: String = JSON.stringify(row)
	var rid: String = str(row["run_id"])
	var sig: String = "%s|%s|%d|%d" % [str(row["outcome"]), str(row["waves_completed"]), int(row["lives_lost_total"]), int(row["charges_fired"])]
	if _synced_run_hashes.get(rid, "") == sig:
		return true

	if OS.has_feature("web"):
		var b64: String = Marshalls.utf8_to_base64(body_json)
		JavaScriptBridge.eval("if (window.ttdSyncRunToSupabaseB64) window.ttdSyncRunToSupabaseB64('%s');" % b64)
		_synced_run_hashes[rid] = sig
		cloud_sync_status = "Cloud Sync Sent (Web)"
		return true

	if _http_request == null:
		return false
	_pending_native_queue.append({"rid": rid, "sig": sig, "body": body_json})
	_pump_native_http_queue()
	return true


func sync_all_runs_now() -> int:
	var all_r: Array = get_all_runs_including_active()
	var count: int = 0
	_synced_run_hashes.clear()
	for r in all_r:
		if sync_run_to_supabase(r):
			count += 1
	return count


func _pump_native_http_queue() -> void:
	if _http_busy or _http_request == null or _pending_native_queue.is_empty():
		return
	var item: Dictionary = _pending_native_queue.pop_front()
	var endpoint: String = "%s/rest/v1/%s?on_conflict=run_id" % [SUPABASE_URL, SUPABASE_TABLE]
	var headers := PackedStringArray([
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % SUPABASE_ANON_KEY,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates,return=minimal",
	])
	_http_busy = true
	_http_request.set_meta("sync_rid", str(item["rid"]))
	_http_request.set_meta("sync_sig", str(item["sig"]))
	var err: Error = _http_request.request(endpoint, headers, HTTPClient.METHOD_POST, str(item["body"]))
	if err != OK:
		_http_busy = false
		cloud_sync_status = "Cloud Sync Offline (err %d)" % int(err)


func _on_native_http_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http_busy = false
	var rid: String = str(_http_request.get_meta("sync_rid", ""))
	var sig: String = str(_http_request.get_meta("sync_sig", ""))
	if response_code >= 200 and response_code < 300:
		if rid != "":
			_synced_run_hashes[rid] = sig
		cloud_sync_status = "Synced to Supabase"
	elif response_code == 404:
		cloud_sync_status = "Run SQL Setup (timedefense_runs table missing)"
	else:
		cloud_sync_status = "Cloud Sync Pending (HTTP %d)" % response_code
	analytics_updated.emit()
	_pump_native_http_queue()


# --- Aggregation & Automated Balance Diagnostics ---

func get_all_runs_including_active() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for r in runs:
		var rid: String = str(r.get("run_id", ""))
		seen[rid] = out.size()
		out.append(r)
	if _is_run_meaningful(current_run):
		_sync_run_snapshot()
		var crid: String = str(current_run.get("run_id", ""))
		var snap: Dictionary = _clean_run_for_export(current_run)
		if seen.has(crid):
			out[int(seen[crid])] = snap
		else:
			out.append(snap)
	return out


func compute_aggregate_summary(include_sandbox: bool = false, version_filter: String = "") -> Dictionary:
	var all_runs: Array = get_all_runs_including_active()
	var filtered: Array = []
	var sandbox_count: int = 0
	for r in all_runs:
		if bool(r.get("is_sandbox", false)):
			sandbox_count += 1
			if not include_sandbox:
				continue
		if version_filter != "" and str(r.get("balance_version", "")) != version_filter:
			continue
		filtered.append(r)

	var total_runs: int = filtered.size()
	var wins: int = 0
	var losses: int = 0
	var stalled: int = 0
	var abandoned: int = 0
	var active: int = 0
	var sum_max_wave: float = 0.0
	var best_wave: int = 0
	var total_surges: int = 0
	var total_early_calls: int = 0
	var sum_challenge: float = 0.0
	var sum_kill_pen: float = 0.0
	var kill_pen_runs: int = 0
	var sum_boss_pen: float = 0.0
	var boss_pen_runs: int = 0
	var sum_game_speed: float = 0.0
	var total_powers := {"rewind": 0, "pause": 0, "haste": 0}
	var total_upgrades := {"damage": 0, "range": 0, "fire_rate": 0}
	var total_combines := {"drag_shop": 0, "two_tower": 0}
	var zone_builds: Dictionary = {}
	var button_presses: Dictionary = {}
	var disabled_taps: Dictionary = {}
	var tap_grid_landscape: Dictionary = {}
	var tap_grid_portrait: Dictionary = {}
	var orientations := {"landscape": 0, "portrait": 0}
	var total_taps: int = 0
	var total_scrolls: int = 0
	var guide_dismissed_count: int = 0
	var guide_completed_count: int = 0
	var by_level: Dictionary = {}
	var by_difficulty: Dictionary = {}
	var by_version: Dictionary = {}
	var wave_agg: Dictionary = {}
	var enemy_leaks: Dictionary = {}
	var enemy_kills: Dictionary = {}
	var tower_agg: Dictionary = {}

	for r in filtered:
		var oc: String = str(r.get("outcome", "in_progress"))
		if oc == "won":
			wins += 1
		elif oc == "lost":
			losses += 1
		elif oc == "stalled":
			stalled += 1
		elif oc == "abandoned":
			abandoned += 1
		else:
			active += 1

		var mw: int = int(r.get("max_wave_reached", 1))
		sum_max_wave += float(mw)
		best_wave = maxi(best_wave, mw)
		total_surges += int(r.get("surges_suffered", 0))
		total_early_calls += int(r.get("early_calls", 0))
		var cs: int = int(r.get("challenge_score", compute_run_challenge_score(r)))
		sum_challenge += float(cs)
		var akp: float = float(r.get("avg_kill_progress_pct", 0.0))
		if akp > 0.0:
			sum_kill_pen += akp
			kill_pen_runs += 1
		var mbp: float = float(r.get("max_boss_progress_pct", 0.0))
		if mbp > 0.0:
			sum_boss_pen += mbp
			boss_pen_runs += 1
		sum_game_speed += float(r.get("avg_game_speed", 1.0))

		var pu: Dictionary = r.get("powers_used", {})
		for pk in ["rewind", "pause", "haste"]:
			total_powers[pk] = int(total_powers[pk]) + int(pu.get(pk, 0))
		var uc: Dictionary = r.get("upgrade_counts", {})
		for uk in ["damage", "range", "fire_rate"]:
			total_upgrades[uk] = int(total_upgrades[uk]) + int(uc.get(uk, 0))
		var cm: Dictionary = r.get("combine_methods", {})
		for ck in ["drag_shop", "two_tower"]:
			total_combines[ck] = int(total_combines[ck]) + int(cm.get(ck, 0))
		var zb: Dictionary = r.get("zone_builds", {})
		for zk in zb.keys():
			zone_builds[zk] = int(zone_builds.get(zk, 0)) + int(zb[zk])

		var ui_t: Dictionary = r.get("ui_telemetry", {})
		if not ui_t.is_empty():
			total_taps += int(ui_t.get("total_taps", 0))
			total_scrolls += int(ui_t.get("scroll_events", 0))
			var vp_prof: Dictionary = ui_t.get("viewport_profile", {})
			var orient: String = str(vp_prof.get("orientation", "landscape"))
			orientations[orient] = int(orientations.get(orient, 0)) + 1
			var bp: Dictionary = ui_t.get("button_presses", {})
			for bk in bp.keys():
				button_presses[bk] = int(button_presses.get(bk, 0)) + int(bp[bk])
			var dt: Dictionary = ui_t.get("disabled_taps", {})
			for dk2 in dt.keys():
				disabled_taps[dk2] = int(disabled_taps.get(dk2, 0)) + int(dt[dk2])
			var gl: Dictionary = ui_t.get("tap_grid_landscape", {})
			for ck in gl.keys():
				tap_grid_landscape[ck] = int(tap_grid_landscape.get(ck, 0)) + int(gl[ck])
			var gp: Dictionary = ui_t.get("tap_grid_portrait", {})
			for ck2 in gp.keys():
				tap_grid_portrait[ck2] = int(tap_grid_portrait.get(ck2, 0)) + int(gp[ck2])
			var gs: Dictionary = ui_t.get("guide_stats", {})
			if str(gs.get("dismissed_at", "")) != "":
				guide_dismissed_count += 1
			if bool(gs.get("completed", false)):
				guide_completed_count += 1

		var bv: String = str(r.get("balance_version", "v1.0"))
		if not by_version.has(bv):
			by_version[bv] = {"runs": 0, "wins": 0, "losses": 0, "sum_wave": 0, "sum_challenge": 0}
		by_version[bv]["runs"] = int(by_version[bv]["runs"]) + 1
		if oc == "won":
			by_version[bv]["wins"] = int(by_version[bv]["wins"]) + 1
		elif oc == "lost":
			by_version[bv]["losses"] = int(by_version[bv]["losses"]) + 1
		by_version[bv]["sum_wave"] = int(by_version[bv]["sum_wave"]) + mw
		by_version[bv]["sum_challenge"] = int(by_version[bv]["sum_challenge"]) + cs

		var lid: int = int(r.get("level", 1))
		if not by_level.has(lid):
			by_level[lid] = {"runs": 0, "wins": 0, "losses": 0, "sum_wave": 0}
		by_level[lid]["runs"] = int(by_level[lid]["runs"]) + 1
		if oc == "won":
			by_level[lid]["wins"] = int(by_level[lid]["wins"]) + 1
		elif oc == "lost":
			by_level[lid]["losses"] = int(by_level[lid]["losses"]) + 1
		by_level[lid]["sum_wave"] = int(by_level[lid]["sum_wave"]) + mw

		var dk: String = str(r.get("difficulty", "standard"))
		if not by_difficulty.has(dk):
			by_difficulty[dk] = {"runs": 0, "wins": 0, "losses": 0}
		by_difficulty[dk]["runs"] = int(by_difficulty[dk]["runs"]) + 1
		if oc == "won":
			by_difficulty[dk]["wins"] = int(by_difficulty[dk]["wins"]) + 1
		elif oc == "lost":
			by_difficulty[dk]["losses"] = int(by_difficulty[dk]["losses"]) + 1

		var lk: Dictionary = r.get("leaks_by_enemy", {})
		for et in lk.keys():
			enemy_leaks[et] = int(enemy_leaks.get(et, 0)) + int(lk[et])
		var kk: Dictionary = r.get("kills_by_enemy", {})
		for et in kk.keys():
			enemy_kills[et] = int(enemy_kills.get(et, 0)) + int(kk[et])

		for wl in r.get("wave_log", []):
			var w: int = int(wl.get("wave", 1))
			if not wave_agg.has(w):
				wave_agg[w] = {
					"wave": w,
					"plays": 0,
					"leaks_total": 0,
					"runs_with_leak": 0,
					"sum_money_end": 0.0,
					"sum_duration": 0.0,
					"sum_max_pen": 0.0,
					"early_calls": 0,
					"leaks_by_enemy": {},
				}
			var wa: Dictionary = wave_agg[w]
			wa["plays"] = int(wa["plays"]) + 1
			var ll: int = int(wl.get("lives_lost", 0))
			wa["leaks_total"] = int(wa["leaks_total"]) + ll
			if ll > 0:
				wa["runs_with_leak"] = int(wa["runs_with_leak"]) + 1
			wa["sum_money_end"] = float(wa["sum_money_end"]) + float(wl.get("money_end", 0))
			wa["sum_duration"] = float(wa["sum_duration"]) + float(wl.get("duration_sec", 0.0))
			wa["sum_max_pen"] = float(wa["sum_max_pen"]) + float(wl.get("max_progress_pct", 0.0))
			if bool(wl.get("early_called", false)):
				wa["early_calls"] = int(wa["early_calls"]) + 1
			var wle: Dictionary = wl.get("leaks_by_enemy", {})
			for et in wle.keys():
				wa["leaks_by_enemy"][et] = int(wa["leaks_by_enemy"].get(et, 0)) + int(wle[et])

		var tstats: Dictionary = r.get("tower_stats", {})
		for tkey in tstats.keys():
			var rec: Dictionary = tstats[tkey]
			if not tower_agg.has(tkey):
				tower_agg[tkey] = {
					"type": tkey,
					"name": str(rec.get("name", Balance.TOWERS.get(tkey, {}).get("name", tkey))),
					"is_combo": bool(rec.get("is_combo", Balance.is_combo_tower(tkey))),
					"runs_used": 0,
					"wins_used": 0,
					"built": 0,
					"sold": 0,
					"spent": 0,
					"damage": 0.0,
					"kills": 0,
				}
			var ta: Dictionary = tower_agg[tkey]
			ta["runs_used"] = int(ta["runs_used"]) + 1
			if oc == "won":
				ta["wins_used"] = int(ta["wins_used"]) + 1
			ta["built"] = int(ta["built"]) + int(rec.get("built", 0))
			ta["sold"] = int(ta["sold"]) + int(rec.get("sold", 0))
			ta["spent"] = int(ta["spent"]) + int(rec.get("spent", 0))
			ta["damage"] = float(ta["damage"]) + float(rec.get("damage", 0.0))
			ta["kills"] = int(ta["kills"]) + int(rec.get("kills", 0))

	var tower_board: Array = []
	var dpd_values: Array[float] = []
	for tkey in tower_agg.keys():
		var ta: Dictionary = tower_agg[tkey]
		var spent: float = maxf(1.0, float(ta["spent"]))
		var dpd: float = float(ta["damage"]) / spent
		var pick_pct: float = (float(ta["runs_used"]) / float(maxi(1, total_runs))) * 100.0
		var wr_pct: float = (float(ta["wins_used"]) / float(maxi(1, int(ta["runs_used"])))) * 100.0
		ta["dmg_per_dollar"] = snappedf(dpd, 0.01)
		ta["pick_rate_pct"] = snappedf(pick_pct, 0.1)
		ta["win_rate_pct"] = snappedf(wr_pct, 0.1)
		ta["damage"] = snappedf(float(ta["damage"]), 0.1)
		if int(ta["built"]) > 0 and float(ta["damage"]) > 0.0:
			dpd_values.append(dpd)
		tower_board.append(ta)
	tower_board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["damage"]) > float(b["damage"])
	)
	dpd_values.sort()
	var median_dpd: float = dpd_values[dpd_values.size() / 2] if not dpd_values.is_empty() else 0.0

	var wave_hotspots: Array = []
	for w in wave_agg.keys():
		var wa: Dictionary = wave_agg[w]
		var plays: int = maxi(1, int(wa["plays"]))
		var top_e: String = ""
		var top_e_cnt: int = 0
		for et in wa["leaks_by_enemy"].keys():
			if int(wa["leaks_by_enemy"][et]) > top_e_cnt:
				top_e_cnt = int(wa["leaks_by_enemy"][et])
				top_e = str(et)
		wave_hotspots.append({
			"wave": int(wa["wave"]),
			"plays": plays,
			"leaks_total": int(wa["leaks_total"]),
			"leak_rate_pct": snappedf((float(wa["runs_with_leak"]) / float(plays)) * 100.0, 0.1),
			"avg_money_end": snappedf(float(wa["sum_money_end"]) / float(plays), 1.0),
			"avg_max_pen_pct": snappedf(float(wa["sum_max_pen"]) / float(plays), 0.1),
			"avg_duration": snappedf(float(wa["sum_duration"]) / float(plays), 1.0),
			"early_calls": int(wa["early_calls"]),
			"top_leaker": top_e,
		})
	wave_hotspots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["leaks_total"]) != int(b["leaks_total"]):
			return int(a["leaks_total"]) > int(b["leaks_total"])
		return float(a["avg_max_pen_pct"]) > float(b["avg_max_pen_pct"])
	)

	var finished_runs: int = wins + losses + stalled
	var win_rate_pct: float = (float(wins) / float(maxi(1, finished_runs))) * 100.0 if finished_runs > 0 else 0.0
	var avg_max_wave: float = sum_max_wave / float(maxi(1, total_runs)) if total_runs > 0 else 0.0
	var avg_challenge: float = sum_challenge / float(maxi(1, total_runs)) if total_runs > 0 else 0.0
	var avg_kill_pen: float = sum_kill_pen / float(maxi(1, kill_pen_runs)) if kill_pen_runs > 0 else 0.0
	var avg_boss_pen: float = sum_boss_pen / float(maxi(1, boss_pen_runs)) if boss_pen_runs > 0 else 0.0
	var avg_speed: float = sum_game_speed / float(maxi(1, total_runs)) if total_runs > 0 else 1.0

	var summary := {
		"balance_version": Balance.BALANCE_VERSION,
		"total_runs": total_runs,
		"sandbox_runs_excluded": 0 if include_sandbox else sandbox_count,
		"wins": wins,
		"losses": losses,
		"stalled": stalled,
		"abandoned": abandoned,
		"active": active,
		"win_rate_pct": snappedf(win_rate_pct, 0.1),
		"avg_max_wave": snappedf(avg_max_wave, 0.1),
		"best_wave": best_wave,
		"avg_challenge_score": snappedf(avg_challenge, 0.1),
		"avg_kill_progress_pct": snappedf(avg_kill_pen, 0.1),
		"avg_boss_progress_pct": snappedf(avg_boss_pen, 0.1),
		"avg_game_speed": snappedf(avg_speed, 0.01),
		"avg_surges_per_run": snappedf(float(total_surges) / float(maxi(1, total_runs)), 0.01),
		"total_early_calls": total_early_calls,
		"powers_used": total_powers,
		"upgrade_counts": total_upgrades,
		"combine_methods": total_combines,
		"zone_builds": zone_builds,
		"ui_summary": {
			"button_presses": button_presses,
			"disabled_taps": disabled_taps,
			"tap_grid_landscape": tap_grid_landscape,
			"tap_grid_portrait": tap_grid_portrait,
			"orientations": orientations,
			"total_taps": total_taps,
			"total_scrolls": total_scrolls,
			"guide_dismissed_count": guide_dismissed_count,
			"guide_completed_count": guide_completed_count,
		},
		"by_version": by_version,
		"by_level": by_level,
		"by_difficulty": by_difficulty,
		"enemy_leaks": enemy_leaks,
		"enemy_kills": enemy_kills,
		"median_dmg_per_dollar": snappedf(median_dpd, 0.01),
		"tower_board": tower_board,
		"wave_hotspots": wave_hotspots,
		"recommendations": [],
	}
	summary["recommendations"] = _compute_balance_recommendations(summary)
	return summary


func _compute_balance_recommendations(s: Dictionary) -> Array[String]:
	var recs: Array[String] = []
	var total_runs: int = int(s["total_runs"])
	if total_runs == 0:
		recs.append("[READY] Play at least 1 non-sandbox run to stream telemetry to Supabase & generate balance diagnostics.")
		return recs

	var avg_cs: float = float(s["avg_challenge_score"])
	var avg_kp: float = float(s["avg_kill_progress_pct"])
	if avg_kp > 0.0 and avg_kp < 42.0 and float(s["avg_challenge_score"]) < 40.0:
		recs.append("[TOO EASY / SPAWN-CAMPED] Avg enemy dies at %.0f%% path & Challenge Score is %.0f/100 — early/mid waves need more pressure." % [avg_kp, avg_cs])
	elif avg_cs >= 85.0 and float(s["win_rate_pct"]) < 30.0:
		recs.append("[OVERWHELMING] Avg Challenge Score is %.0f/100 with %.0f%% win rate — ease top choke wave or buff underperforming counters." % [avg_cs, float(s["win_rate_pct"])])

	var finished: int = int(s["wins"]) + int(s["losses"]) + int(s["stalled"])
	if finished >= 3:
		var wr: float = float(s["win_rate_pct"])
		if wr >= 85.0:
			recs.append("[HIGH WIN RATE] %.0f%% win rate across %d runs — tighten waves or increase boss threat." % [wr, finished])
		elif wr <= 20.0:
			recs.append("[LOW WIN RATE] %.0f%% win rate across %d runs — inspect leak hotspots below." % [wr, finished])

	var hotspots: Array = s["wave_hotspots"]
	if not hotspots.is_empty() and int(hotspots[0]["leaks_total"]) > 0:
		var h0: Dictionary = hotspots[0]
		recs.append("[WAVE SPIKE] Wave %d is top leak wave (%d lives lost, %.0f%% leak rate, avg max path %.0f%%; culprit: %s)." % [
			int(h0["wave"]), int(h0["leaks_total"]), float(h0["leak_rate_pct"]), float(h0["avg_max_pen_pct"]),
			str(h0["top_leaker"]) if str(h0["top_leaker"]) != "" else "mixed"
		])
		if float(h0["avg_money_end"]) >= 320.0:
			recs.append("[ECONOMY SLACK] Avg unspent cash on Wave %d was $%.0f while leaking — upgrades/merges may feel slow." % [
				int(h0["wave"]), float(h0["avg_money_end"])
			])

	# Compare combos against combo median and standalone base towers against base median (ignoring base towers immediately fused into combos)
	var combo_dpds: Array[float] = []
	var base_dpds: Array[float] = []
	var used_combos: int = 0
	for tb in s["tower_board"]:
		if bool(tb["is_combo"]) and int(tb["built"]) > 0:
			used_combos += 1
			if float(tb["damage"]) > 0.0:
				combo_dpds.append(float(tb["dmg_per_dollar"]))
		elif not bool(tb["is_combo"]) and int(tb["built"]) > 0 and float(tb["damage"]) > 0.0 and int(tb["spent"]) >= 350:
			base_dpds.append(float(tb["dmg_per_dollar"]))
	combo_dpds.sort()
	base_dpds.sort()
	var combo_med: float = combo_dpds[combo_dpds.size() / 2] if not combo_dpds.is_empty() else float(s["median_dmg_per_dollar"])
	var base_med: float = base_dpds[base_dpds.size() / 2] if not base_dpds.is_empty() else 0.0

	for tb in s["tower_board"]:
		var is_c: bool = bool(tb["is_combo"])
		var peer_med: float = combo_med if is_c else base_med
		if peer_med > 1.0 and int(tb["built"]) >= 1:
			var dpd: float = float(tb["dmg_per_dollar"])
			if not is_c and int(tb["spent"]) < 350:
				continue
			if dpd >= peer_med * 1.85 and (int(tb["built"]) >= 2 or float(tb["damage"]) >= 500000.0):
				recs.append("[OP CANDIDATE] %s deals %.1f Dmg/$ (%.1fx %s median %.1f) across %d build(s)." % [
					str(tb["name"]), dpd, dpd / peer_med, "combo" if is_c else "base", peer_med, int(tb["built"])
				])
			elif dpd > 0.0 and int(tb["built"]) >= 2 and dpd <= peer_med * 0.45 and str(tb["type"]) != "slow" and str(tb["type"]) != "slow+slow":
				recs.append("[WEAK CANDIDATE] %s averages %.1f Dmg/$ (%.0f%% of %s median) — buff candidate." % [
					str(tb["name"]), dpd, (dpd / peer_med) * 100.0, "combo" if is_c else "base"
				])

	if total_runs >= 2 and used_combos < 5:
		recs.append("[COMBO ADOPTION] Only %d / 21 combinations built so far." % used_combos)

	var pu: Dictionary = s["powers_used"]
	var total_p: int = int(pu["rewind"]) + int(pu["pause"]) + int(pu["haste"])
	if total_p >= 4:
		for pk in ["rewind", "pause", "haste"]:
			var share: float = float(pu[pk]) / float(total_p)
			if share >= 0.72:
				recs.append("[POWER SKEW] %s accounts for %.0f%% of time power casts (%d/%d)." % [
					pk.capitalize(), share * 100.0, int(pu[pk]), total_p
				])
	if float(s["avg_surges_per_run"]) >= 1.2:
		recs.append("[SURGE PRESSURE] Averaging %.2f Surges/run." % float(s["avg_surges_per_run"]))

	if recs.is_empty():
		recs.append("[HEALTHY] Challenge Score (%.0f/100), path penetration (%.0f%%), and tower Dmg/$ are in target bands." % [avg_cs, avg_kp])
	return recs


# --- Export, Persistence & Web Bridge ---

func export_payload_dict(include_sandbox: bool = true) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"balance_version": Balance.BALANCE_VERSION,
		"game": "TimeDefense",
		"player_id": player_id,
		"exported_at": _iso_now(),
		"summary": compute_aggregate_summary(false),
		"runs": get_all_runs_including_active() if include_sandbox else get_all_runs_including_active().filter(func(r: Dictionary) -> bool: return not bool(r.get("is_sandbox", false))),
	}


func export_json_string(include_sandbox: bool = true) -> String:
	return JSON.stringify(export_payload_dict(include_sandbox), "  ")


func build_ai_balance_report(include_sandbox: bool = false) -> String:
	var s: Dictionary = compute_aggregate_summary(include_sandbox)
	var lines: PackedStringArray = [
		"# TimeDefense Real Playtest Analytics Report (%s)" % str(s["balance_version"]),
		"Exported: %s | Runs: %d (W:%d L:%d Stalled:%d Aband:%d Active:%d | Sandbox excluded: %d)" % [
			_iso_now(), int(s["total_runs"]), int(s["wins"]), int(s["losses"]), int(s["stalled"]), int(s["abandoned"]), int(s["active"]), int(s["sandbox_runs_excluded"])
		],
		"Win Rate: %.1f%% | Challenge Score: %.0f/100 | Avg Kill Path: %.0f%% | Avg Boss Peak: %.0f%% | Avg Speed: %.2fx" % [
			float(s["win_rate_pct"]), float(s["avg_challenge_score"]), float(s["avg_kill_progress_pct"]), float(s["avg_boss_progress_pct"]), float(s["avg_game_speed"])
		],
		"Avg Max Wave: %.1f (Best W%d) | Surges/Run: %.2f | Early Calls: %d | Powers R:%d P:%d H:%d | Upgrades D:%d R:%d S:%d" % [
			float(s["avg_max_wave"]), int(s["best_wave"]), float(s["avg_surges_per_run"]), int(s["total_early_calls"]),
			int(s["powers_used"]["rewind"]), int(s["powers_used"]["pause"]), int(s["powers_used"]["haste"]),
			int(s["upgrade_counts"]["damage"]), int(s["upgrade_counts"]["range"]), int(s["upgrade_counts"]["fire_rate"]),
		],
		"",
		"## Automated Balance Flags",
	]
	for rec in s["recommendations"]:
		lines.append("- " + str(rec))

	lines.append("")
	lines.append("## Top Leak / Tension Waves")
	var wh: Array = s["wave_hotspots"]
	var max_wh: int = mini(8, wh.size())
	if max_wh == 0:
		lines.append("- (no waves logged yet)")
	for i in range(max_wh):
		var h: Dictionary = wh[i]
		lines.append("- W%d | plays=%d | leaks=%d (%.0f%%) | max_path=%.0f%% | avg_cash=$%.0f | top=%s" % [
			int(h["wave"]), int(h["plays"]), int(h["leaks_total"]), float(h["leak_rate_pct"]), float(h["avg_max_pen_pct"]), float(h["avg_money_end"]),
			str(h["top_leaker"]) if str(h["top_leaker"]) != "" else "none"
		])

	lines.append("")
	lines.append("## Tower Performance (Top 12 by Damage)")
	var tb: Array = s["tower_board"]
	var max_tb: int = mini(12, tb.size())
	if max_tb == 0:
		lines.append("- (no towers built yet)")
	for i in range(max_tb):
		var t: Dictionary = tb[i]
		lines.append("- %s (%s) | built=%d | spent=$%d | dmg=%.0f | kills=%d | %.1f Dmg/$ | pick=%.0f%% | WR=%.0f%%" % [
			str(t["name"]), str(t["type"]), int(t["built"]), int(t["spent"]), float(t["damage"]), int(t["kills"]),
			float(t["dmg_per_dollar"]), float(t["pick_rate_pct"]), float(t["win_rate_pct"])
		])

	lines.append("")
	lines.append("## Recent Runs (Last 5)")
	var all_r: Array = get_all_runs_including_active()
	var start_idx: int = maxi(0, all_r.size() - 5)
	for i in range(all_r.size() - 1, start_idx - 1, -1):
		var r: Dictionary = all_r[i]
		lines.append("- [%s %s] Lv%d (%s%s) -> %s @ W%d | Score:%d/100 | KillPath:%.0f%% | BossPeak:%.0f%% | Lives:%d | Shots:%d | CashEnd:$%d" % [
			str(r.get("balance_version", "v1.0")),
			str(r.get("started_at", "")).substr(0, 16),
			int(r.get("level", 1)),
			str(r.get("difficulty", "standard")),
			" SANDBOX" if bool(r.get("is_sandbox", false)) else "",
			str(r.get("outcome", "")).to_upper(),
			int(r.get("max_wave_reached", 1)),
			int(r.get("challenge_score", 0)),
			float(r.get("avg_kill_progress_pct", 0.0)),
			float(r.get("max_boss_progress_pct", 0.0)),
			int(r.get("lives_remaining", 0)),
			int(r.get("charges_fired", 0)),
			int(r.get("money_unspent_end", 0)),
		])
	return "\n".join(lines)


func save_analytics(path: String = ANALYTICS_FILE_PATH) -> bool:
	if (DisplayServer.get_name() == "headless" or suppress_default_persistence) and path == ANALYTICS_FILE_PATH:
		return false
	var json_text: String = export_json_string(true)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(json_text)
	f.close()
	if OS.has_feature("web") and path == ANALYTICS_FILE_PATH:
		var b64: String = Marshalls.utf8_to_base64(json_text)
		JavaScriptBridge.eval("if (window.ttdSaveAnalyticsB64) window.ttdSaveAnalyticsB64('%s');" % b64)
	return true


func load_analytics(path: String = ANALYTICS_FILE_PATH) -> bool:
	var raw_text: String = ""
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			raw_text = f.get_as_text()
			f.close()
	elif OS.has_feature("web") and path == ANALYTICS_FILE_PATH:
		var web_txt = JavaScriptBridge.eval("window.ttdLoadAnalyticsJson ? window.ttdLoadAnalyticsJson() : ''")
		if web_txt is String and web_txt != "":
			raw_text = web_txt
	if raw_text == "":
		return false
	var parsed = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		return false
	var loaded_runs = parsed.get("runs", [])
	if loaded_runs is Array:
		runs = loaded_runs.duplicate(true)
		while runs.size() > MAX_STORED_RUNS:
			runs.remove_at(0)
		analytics_updated.emit()
		return true
	return false


func clear_analytics_history(path: String = ANALYTICS_FILE_PATH) -> void:
	runs.clear()
	_synced_run_hashes.clear()
	_start_new_run()
	if not ((DisplayServer.get_name() == "headless" or suppress_default_persistence) and path == ANALYTICS_FILE_PATH):
		save_analytics(path)
	analytics_updated.emit()


func copy_report_to_clipboard(raw_json: bool = false) -> String:
	var txt: String = export_json_string(true) if raw_json else build_ai_balance_report(false)
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(txt)
	if OS.has_feature("web"):
		var b64: String = Marshalls.utf8_to_base64(txt)
		JavaScriptBridge.eval("if (window.ttdCopyTextB64) window.ttdCopyTextB64('%s');" % b64)
	return txt


func download_json_export() -> String:
	var json_text: String = export_json_string(true)
	var fname: String = "timedefense-analytics-%d.json" % int(Time.get_unix_time_from_system())
	if OS.has_feature("web"):
		var b64: String = Marshalls.utf8_to_base64(json_text)
		JavaScriptBridge.eval("if (window.ttdDownloadTextB64) window.ttdDownloadTextB64('%s', '%s', 'application/json');" % [b64, fname])
		return "Downloaded %s" % fname
	var out_path: String = "user://%s" % fname
	if DisplayServer.get_name() != "headless" and not suppress_default_persistence:
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(json_text)
			f.close()
	return "Saved to %s" % ProjectSettings.globalize_path(out_path)


func open_web_dashboard() -> bool:
	save_analytics()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.ttdOpenAnalyticsDashboard) window.ttdOpenAnalyticsDashboard();")
		return true
	return false
