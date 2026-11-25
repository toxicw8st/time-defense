extends Node

## Playtest Analytics & Balance Telemetry Autoload
## Captures real gameplay runs (wave-by-wave leaks/cash, per-tower Dmg/$, build order,
## time powers, surges, Hive Destroyer shots, and outcomes) to user://timedefense_analytics.json
## and mirrors to browser localStorage on Web for the live analytics.html dashboard.

signal analytics_updated

const SCHEMA_VERSION: int = 1
const ANALYTICS_FILE_PATH: String = "user://timedefense_analytics.json"
const MAX_STORED_RUNS: int = 60
const MAX_EVENTS_PER_RUN: int = 260

var runs: Array = []
var current_run: Dictionary = {}
var _active_wave_rec: Dictionary = {}
var _active_wave_open: bool = false
var _session_counter: int = 0
var _map_ref: WeakRef = null
var suppress_default_persistence: bool = false


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		load_analytics()
	_connect_signals()
	_start_new_run()


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
	var run_id: String = "run_%d_%d" % [unix_ts, _session_counter]
	var m := GameState.mission
	current_run = {
		"run_id": run_id,
		"schema_version": SCHEMA_VERSION,
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
		"total_spent_towers": 0,
		"sell_refunds_total": 0,
		"research_earned": 0,
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


func _is_run_meaningful(r: Dictionary) -> bool:
	if r.is_empty():
		return false
	if int(r.get("waves_started", 0)) > 0:
		return true
	if int(r.get("waves_completed", 0)) > 0:
		return true
	var evs: Array = r.get("events", [])
	return evs.size() >= 2


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


func _upsert_current_run() -> void:
	if not _is_run_meaningful(current_run):
		return
	_sync_run_snapshot()
	var rid: String = str(current_run.get("run_id", ""))
	var snap: Dictionary = current_run.duplicate(true)
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
	current_run["wave_log"].append(_active_wave_rec.duplicate(true))
	_active_wave_rec = {}
	_active_wave_open = false


# --- Signal Handlers ---

func _on_mission_reset() -> void:
	if not current_run.is_empty() and str(current_run.get("outcome", "")) == "in_progress" and _is_run_meaningful(current_run):
		_close_active_wave(false)
		current_run["outcome"] = "abandoned"
		current_run["end_reason"] = "Restarted or switched level"
		current_run["ended_at"] = _iso_now()
		_upsert_current_run()
		save_analytics()
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
		"leaks_by_enemy": {},
		"kills_by_enemy": {},
		"powers_used": {"rewind": 0, "pause": 0, "haste": 0},
		"surges": 0,
		"early_called": false,
		"tower_count": int(tc["total"]),
		"combo_count": int(tc["combos"]),
	}
	_active_wave_open = true


func _on_wave_cleared(_wave_num: int) -> void:
	if current_run.is_empty():
		return
	_close_active_wave(true)
	_upsert_current_run()
	save_analytics()


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
	_upsert_current_run()
	save_analytics()


# --- Direct Gameplay Instrumentation Hooks ---

func record_tower_build(tower_type: String, cost: int, zone_label: String = "") -> void:
	if current_run.is_empty():
		return
	var b: Dictionary = _ensure_tower_bucket(tower_type)
	b["built"] = int(b["built"]) + 1
	b["spent"] = int(b["spent"]) + cost
	current_run["total_spent_towers"] = int(current_run.get("total_spent_towers", 0)) + cost
	_log_event("build", {"type": tower_type, "cost": cost, "zone": zone_label})


func record_tower_combine(type_a: String, type_b: String, combo_type: String, added_cost: int, combo_total_spent: int) -> void:
	if current_run.is_empty():
		return
	var b: Dictionary = _ensure_tower_bucket(combo_type)
	b["built"] = int(b["built"]) + 1
	b["spent"] = int(b["spent"]) + maxi(added_cost, combo_total_spent)
	current_run["total_spent_towers"] = int(current_run.get("total_spent_towers", 0)) + maxi(0, added_cost)
	_log_event("combine", {"a": type_a, "b": type_b, "result": combo_type, "cost": added_cost})


func record_tower_upgrade(tower_type: String, stat_key: String, new_level: int, cost: int) -> void:
	if current_run.is_empty():
		return
	var b: Dictionary = _ensure_tower_bucket(tower_type)
	b["spent"] = int(b["spent"]) + cost
	b["upgrades"][stat_key] = int(b["upgrades"].get(stat_key, 0)) + 1
	b["max_lvl"][stat_key] = maxi(int(b["max_lvl"].get(stat_key, 0)), new_level)
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


func record_refinery_started(cost: int, next_count: int) -> void:
	if current_run.is_empty():
		return
	_log_event("refinery", {"count": next_count, "cost": cost})


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
	_upsert_current_run()
	save_analytics()


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
		var snap: Dictionary = current_run.duplicate(true)
		if seen.has(crid):
			out[int(seen[crid])] = snap
		else:
			out.append(snap)
	return out


func compute_aggregate_summary(include_sandbox: bool = false) -> Dictionary:
	var all_runs: Array = get_all_runs_including_active()
	var filtered: Array = []
	var sandbox_count: int = 0
	for r in all_runs:
		if bool(r.get("is_sandbox", false)):
			sandbox_count += 1
			if not include_sandbox:
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
	var total_powers := {"rewind": 0, "pause": 0, "haste": 0}
	var by_level: Dictionary = {}
	var by_difficulty: Dictionary = {}
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

		var pu: Dictionary = r.get("powers_used", {})
		for pk in ["rewind", "pause", "haste"]:
			total_powers[pk] = int(total_powers[pk]) + int(pu.get(pk, 0))

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

	# Build sorted tower leaderboard & median Dmg/$
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
	var median_dpd: float = 0.0
	if not dpd_values.is_empty():
		median_dpd = dpd_values[dpd_values.size() / 2]

	# Wave hotspots sorted by total leaks desc
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
			"avg_duration": snappedf(float(wa["sum_duration"]) / float(plays), 1.0),
			"early_calls": int(wa["early_calls"]),
			"top_leaker": top_e,
		})
	wave_hotspots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["leaks_total"]) != int(b["leaks_total"]):
			return int(a["leaks_total"]) > int(b["leaks_total"])
		return int(a["wave"]) < int(b["wave"])
	)

	var finished_runs: int = wins + losses + stalled
	var win_rate_pct: float = (float(wins) / float(maxi(1, finished_runs))) * 100.0 if finished_runs > 0 else 0.0
	var avg_max_wave: float = sum_max_wave / float(maxi(1, total_runs)) if total_runs > 0 else 0.0

	var summary := {
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
		"avg_surges_per_run": snappedf(float(total_surges) / float(maxi(1, total_runs)), 0.01),
		"total_early_calls": total_early_calls,
		"powers_used": total_powers,
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
		recs.append("[READY] Play at least 1 non-sandbox run (or clear Wave 1) to start generating data-driven balance flags.")
		return recs

	var finished: int = int(s["wins"]) + int(s["losses"]) + int(s["stalled"])
	if finished >= 3:
		var wr: float = float(s["win_rate_pct"])
		if wr >= 85.0:
			recs.append("[TOO EASY?] Win rate is %.0f%% across %d completed runs — consider tightening mid/late waves or trying Hard/Nightmare." % [wr, finished])
		elif wr <= 20.0:
			recs.append("[TOO HARD?] Win rate is %.0f%% across %d completed runs — check leak hotspots below to ease choke waves." % [wr, finished])

	var hotspots: Array = s["wave_hotspots"]
	if not hotspots.is_empty() and int(hotspots[0]["leaks_total"]) > 0:
		var h0: Dictionary = hotspots[0]
		recs.append("[WAVE SPIKE] Wave %d is top leak wave (%d lives lost across %d plays, %.0f%% leak rate; top culprit: %s)." % [
			int(h0["wave"]), int(h0["leaks_total"]), int(h0["plays"]), float(h0["leak_rate_pct"]),
			str(h0["top_leaker"]) if str(h0["top_leaker"]) != "" else "mixed"
		])
		if float(h0["avg_money_end"]) >= 320.0:
			recs.append("[ECONOMY SLACK] Avg unspent cash on Wave %d was $%.0f while leaking — upgrades/merges may feel too slow to build or unclear." % [
				int(h0["wave"]), float(h0["avg_money_end"])
			])

	var med_dpd: float = float(s["median_dmg_per_dollar"])
	var used_combos: int = 0
	for tb in s["tower_board"]:
		if bool(tb["is_combo"]) and int(tb["built"]) > 0:
			used_combos += 1
		if med_dpd > 1.0 and int(tb["built"]) >= 2:
			var dpd: float = float(tb["dmg_per_dollar"])
			if dpd >= med_dpd * 1.85:
				recs.append("[OP CANDIDATE] %s deals %.1f Dmg/$ (%.1fx median %.1f) across %d builds — watch for overperformance." % [
					str(tb["name"]), dpd, dpd / med_dpd, med_dpd, int(tb["built"])
				])
			elif dpd > 0.0 and dpd <= med_dpd * 0.45 and str(tb["type"]) != "slow" and str(tb["type"]) != "slow+slow":
				recs.append("[WEAK CANDIDATE] %s averages only %.1f Dmg/$ (%.0f%% of median %.1f) — consider buffing damage or lowering cost." % [
					str(tb["name"]), dpd, (dpd / med_dpd) * 100.0, med_dpd
				])

	if total_runs >= 2 and used_combos < 5:
		recs.append("[COMBO ADOPTION] Only %d / 21 tower combinations built so far — players may need stronger incentives or lower merge friction." % used_combos)

	var pu: Dictionary = s["powers_used"]
	var total_p: int = int(pu["rewind"]) + int(pu["pause"]) + int(pu["haste"])
	if total_p >= 4:
		for pk in ["rewind", "pause", "haste"]:
			var share: float = float(pu[pk]) / float(total_p)
			if share >= 0.72:
				recs.append("[POWER SKEW] %s accounts for %.0f%% of all time power casts (%d/%d) — other powers may feel under-tuned." % [
					pk.capitalize(), share * 100.0, int(pu[pk]), total_p
				])
	if float(s["avg_surges_per_run"]) >= 1.2:
		recs.append("[SURGE PRESSURE] Averaging %.2f Surges/run — Surge deadline or visual warning may be catching players off guard." % float(s["avg_surges_per_run"]))

	if recs.is_empty():
		recs.append("[HEALTHY] Win rate, economy, and tower efficiency are within target bands across %d tracked run(s)." % total_runs)
	return recs


# --- Export, Persistence & Web Bridge ---

func export_payload_dict(include_sandbox: bool = true) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"game": "TimeDefense",
		"exported_at": _iso_now(),
		"summary": compute_aggregate_summary(false),
		"runs": get_all_runs_including_active() if include_sandbox else get_all_runs_including_active().filter(func(r: Dictionary) -> bool: return not bool(r.get("is_sandbox", false))),
	}


func export_json_string(include_sandbox: bool = true) -> String:
	return JSON.stringify(export_payload_dict(include_sandbox), "  ")


func build_ai_balance_report(include_sandbox: bool = false) -> String:
	var s: Dictionary = compute_aggregate_summary(include_sandbox)
	var lines: PackedStringArray = [
		"# TimeDefense Real Playtest Analytics Report",
		"Exported: %s | Runs: %d (W:%d L:%d Stalled:%d Aband:%d Active:%d | Sandbox excluded: %d)" % [
			_iso_now(), int(s["total_runs"]), int(s["wins"]), int(s["losses"]), int(s["stalled"]), int(s["abandoned"]), int(s["active"]), int(s["sandbox_runs_excluded"])
		],
		"Win Rate: %.1f%% | Avg Max Wave: %.1f | Best Wave: %d | Avg Surges/Run: %.2f | Early Calls: %d" % [
			float(s["win_rate_pct"]), float(s["avg_max_wave"]), int(s["best_wave"]), float(s["avg_surges_per_run"]), int(s["total_early_calls"])
		],
		"Powers Used -> Rewind: %d | Pause: %d | Haste: %d | Median Tower Efficiency: %.1f Dmg/$" % [
			int(s["powers_used"]["rewind"]), int(s["powers_used"]["pause"]), int(s["powers_used"]["haste"]), float(s["median_dmg_per_dollar"])
		],
		"",
		"## Automated Balance Flags",
	]
	for rec in s["recommendations"]:
		lines.append("- " + str(rec))

	lines.append("")
	lines.append("## Top Leak Waves (Wave | Plays | Total Leaks | Leak% | Avg Cash Left | Top Culprit)")
	var wh: Array = s["wave_hotspots"]
	var max_wh: int = mini(8, wh.size())
	if max_wh == 0:
		lines.append("- (no waves logged yet)")
	for i in range(max_wh):
		var h: Dictionary = wh[i]
		lines.append("- W%d | plays=%d | leaks=%d (%.0f%%) | avg_cash=$%.0f | top=%s" % [
			int(h["wave"]), int(h["plays"]), int(h["leaks_total"]), float(h["leak_rate_pct"]), float(h["avg_money_end"]),
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
		lines.append("- [%s] Lv%d (%s%s) -> %s at W%d | Lives:%d | BaseHP:%d | Shots:%d | Surges:%d | CashEnd:$%d | Leaked:%s" % [
			str(r.get("started_at", "")) .substr(0, 16),
			int(r.get("level", 1)),
			str(r.get("difficulty", "standard")),
			" SANDBOX" if bool(r.get("is_sandbox", false)) else "",
			str(r.get("outcome", "")).to_upper(),
			int(r.get("max_wave_reached", 1)),
			int(r.get("lives_remaining", 0)),
			int(r.get("enemy_base_hp_remaining", 0)),
			int(r.get("charges_fired", 0)),
			int(r.get("surges_suffered", 0)),
			int(r.get("money_unspent_end", 0)),
			JSON.stringify(r.get("leaks_by_enemy", {})),
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
	_start_new_run()
	if not (DisplayServer.get_name() == "headless" and path == ANALYTICS_FILE_PATH):
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
	if DisplayServer.get_name() != "headless":
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
