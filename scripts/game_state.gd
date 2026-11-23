extends Node

## Central GameState autoload owning the single GameClock, Speed Toggle, Meta-Progression, and MissionState.
## Notation:
## s$ = spawn cost (threat cost to spawn an enemy unit)
## b$ = bounty (player $ earned for killing an enemy unit)
## $  = player money (starting $, tower $, refinery $, base-attack $)

signal mission_reset
signal mission_ended(outcome: String, reason: String)
signal lives_changed(new_lives: int)
signal enemy_base_hp_changed(new_hp: int)
signal economy_changed
signal enemy_killed(enemy_type: String, money_gained: int, research_gained: int, world_pos: Vector2)
signal enemy_leaked(enemy_type: String, lives_lost: int, world_pos: Vector2)
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal time_power_used(power_name: String)
signal surge_triggered(surge_count: int)
signal speed_changed(new_speed: float, is_paused: bool)
signal event_logged(message: String)

class MissionState:
	var wave_number: int = 1
	var lives: int = Balance.PLAYER_STARTING_LIVES
	var enemy_base_hp: int = Balance.ENEMY_BASE_MAX_HP
	var mutations: Dictionary = {
		"armoured_stacks": 0,
		"armoured_active_stacks": 0, # Stays unchanged during a Rewind replay; syncs for the next NEW wave
		"thaw_stacks": 0,
		"thaw_hp_stacks": 0, # Activates on subsequent waves after Pause
		"swift_stacks": 0,
	}
	var rewound_in_current_build_phase: bool = false
	var surge_count: int = 0
	var surge_deadline_wave: int = 1 + Balance.SURGE_WAVE_SPAN # Beginning of Wave 6 initially
	var surge_timer_seconds: float = Balance.SURGE_BASE_WINDOW
	var manipulator_level: int = 1
	var manipulator_upgrading_remaining: float = 0.0
	var total_assets_spent: int = 0 # Cumulative $ spent on towers, upgrades, and refineries
	var replay_count_this_wave: int = 0
	var economy: Dictionary = {
		"money": Balance.STARTING_MONEY,
		"research": Balance.STARTING_RESEARCH,
		"refineries_owned": Balance.STARTING_REFINERIES,
	}
	var owned_research: Dictionary = {}
	var cleared_waves: Dictionary = {}
	var shown_prompts: Dictionary = {}
	var towers: Array[Dictionary] = []
	var is_over: bool = false
	var outcome: String = "" # "won", "lost", "stalled"
	var end_reason: String = ""
	var stats: Dictionary = {
		"waves_completed": 0,
		"powers_used": {"rewind": 0, "pause": 0, "haste": 0},
		"surges_suffered": 0,
		"charges_fired": 0,
		"money_earned": 0,
		"research_earned": 0,
	}

var mission: MissionState = MissionState.new()
var mission_elapsed_seconds: float = 0.0
var is_clock_paused: bool = false
var is_wave_active: bool = false
var is_enemies_frozen: bool = false
var is_haste_active: bool = false
var base_attack_charging_active: bool = false
var prompts_muted: bool = false

# --- Speed Toggle (1x / 2x / 3x + Pause) ---
var game_speed: float = 1.0
var is_speed_paused: bool = false

# --- Persistent Rogue-Like Meta-Progression (Persists across missions & levels!) ---
var meta_research: int = 0
var meta_research_ranks: Dictionary = {
	"rapid_cycling": 0,
	"reinforced_shots": 0,
	"extended_optics": 0,
	"efficient_manipulator": 0,
	"hive_breaker": 0,
}
var selected_mission_level: int = Balance.BASE_ATTACK_DEFAULT_LEVEL # 1/N rule: Level 1..5 shots
var selected_map_level: int = 1 # Map layout 1..5 (Level 1 = Chrono Rows, 2 = Vertical Corridors, 3 = Citadel Islands, 4 = Spiral Labyrinth, 5 = Omega Gauntlet)


func _ready() -> void:
	reset_mission()


func _process(delta: float) -> void:
	var sim_dt: float = get_sim_delta(delta)
	if is_wave_active and sim_dt > 0.0 and not mission.is_over:
		mission_elapsed_seconds += sim_dt


func get_sim_delta(delta: float) -> float:
	if is_clock_paused or is_speed_paused or mission.is_over:
		return 0.0
	return delta * game_speed


func set_game_speed(mult: float) -> void:
	game_speed = clampf(mult, 1.0, 3.0)
	is_speed_paused = false
	speed_changed.emit(game_speed, is_speed_paused)


func set_speed_paused(paused: bool) -> void:
	is_speed_paused = paused
	speed_changed.emit(game_speed, is_speed_paused)


func toggle_speed_pause() -> void:
	set_speed_paused(not is_speed_paused)


func select_level(level_n: int) -> void:
	var clamped: int = clampi(level_n, 1, Balance.MAX_MISSION_LEVELS)
	selected_map_level = clamped
	selected_mission_level = int(Balance.LEVELS[clamped]["shots_required"])
	economy_changed.emit()


func reset_meta_progression() -> void:
	meta_research = 0
	for k in meta_research_ranks.keys():
		meta_research_ranks[k] = 0
	selected_mission_level = Balance.BASE_ATTACK_DEFAULT_LEVEL
	selected_map_level = 1
	_sync_mission_research_mirror()
	economy_changed.emit()


func _sync_mission_research_mirror() -> void:
	if mission == null:
		return
	mission.economy["research"] = meta_research
	for k in meta_research_ranks.keys():
		mission.owned_research[k] = int(meta_research_ranks[k]) > 0


func reset_mission() -> void:
	mission = MissionState.new()
	mission_elapsed_seconds = 0.0
	is_clock_paused = false
	is_speed_paused = false
	game_speed = 1.0
	is_wave_active = false
	is_enemies_frozen = false
	is_haste_active = false
	base_attack_charging_active = false
	_sync_mission_research_mirror()
	mission_reset.emit()


func spend_money(amount: int, count_as_asset: bool = false) -> bool:
	if amount < 0 or mission.economy["money"] < amount:
		return false
	mission.economy["money"] -= amount
	if count_as_asset:
		mission.total_assets_spent += amount
	economy_changed.emit()
	return true


func add_money(amount: int, count_as_earned: bool = true) -> void:
	if amount <= 0:
		return
	mission.economy["money"] += amount
	if count_as_earned:
		mission.stats["money_earned"] += amount
	economy_changed.emit()


func add_research(amount: int, is_replay: bool = false) -> int:
	if amount <= 0:
		return 0
	var remaining_cap: int = maxi(0, Balance.MAX_RESEARCH_PER_MISSION - int(mission.stats["research_earned"]))
	if remaining_cap <= 0:
		return 0
	var eff_amount: int = amount
	if is_replay:
		eff_amount = maxi(0, int(floor(float(amount) * pow(Balance.REWIND_RESEARCH_MULT, float(maxi(1, mission.replay_count_this_wave))))))
	var granted: int = mini(eff_amount, remaining_cap)
	if granted <= 0:
		return 0
	meta_research += granted
	mission.stats["research_earned"] += granted
	_sync_mission_research_mirror()
	economy_changed.emit()
	return granted


func spend_research(amount: int) -> bool:
	if amount < 0 or meta_research < amount:
		return false
	meta_research -= amount
	_sync_mission_research_mirror()
	economy_changed.emit()
	return true


func get_research_rank(node_key: String) -> int:
	return int(meta_research_ranks.get(node_key, 0))


func get_next_research_cost(node_key: String) -> int:
	if not Balance.RESEARCH_NODES.has(node_key):
		return 999999
	var rank: int = get_research_rank(node_key)
	var costs: Array = Balance.RESEARCH_NODES[node_key]["rank_costs"]
	if rank >= costs.size():
		return -1
	return int(costs[rank])


func award_kill_earnings(enemy_type: String, money_gained: int, research_gained: int, world_pos: Vector2, is_replay: bool = false) -> void:
	add_money(money_gained, true)
	var actual_r: int = add_research(research_gained, is_replay)
	enemy_killed.emit(enemy_type, money_gained, actual_r, world_pos)


func lose_lives(amount: int, enemy_type: String = "crawler", world_pos: Vector2 = Vector2.ZERO) -> void:
	if mission.is_over:
		return
	mission.lives = max(0, mission.lives - amount)
	lives_changed.emit(mission.lives)
	enemy_leaked.emit(enemy_type, amount, world_pos)
	if mission.lives <= 0:
		end_mission("lost", "Player base fell (0 lives remaining)")


func end_mission(outcome: String, reason: String) -> void:
	if mission.is_over:
		return
	mission.is_over = true
	mission.outcome = outcome
	mission.end_reason = reason
	is_clock_paused = true
	mission_ended.emit(outcome, reason)


func normalize_enemy_type(enemy_type: String) -> String:
	if enemy_type == "runner":
		return "crawler"
	if enemy_type == "boss":
		return "juggernaut"
	return enemy_type


## Stacked HP multiplier from Rewind (+5% per stack, applied after replay to next new wave)
## and Pause (+5% per stack on subsequent waves). With 1 Rewind + 1 Pause: 1.05 * 1.05 = 1.1025 (~1.10x).
func get_enemy_hp_multiplier() -> float:
	var arm_stacks: int = mission.mutations.get("armoured_active_stacks", 0)
	var thaw_hp_stacks: int = mission.mutations.get("thaw_hp_stacks", 0)
	var arm_mult: float = pow(1.0 + Balance.TIME_POWERS["rewind"]["hp_bonus_per_stack"], arm_stacks)
	var thaw_mult: float = pow(1.0 + Balance.TIME_POWERS["pause"]["eff_hp_bonus_per_stack"], thaw_hp_stacks)
	return arm_mult * thaw_mult


func get_enemy_speed_multiplier() -> float:
	if is_enemies_frozen:
		return 0.0
	var stacks: int = mission.mutations.get("swift_stacks", 0)
	return pow(1.0 + Balance.TIME_POWERS["haste"]["speed_bonus_per_stack"], stacks)


func get_effective_enemy_speed(enemy_type: String) -> float:
	var key: String = normalize_enemy_type(enemy_type)
	var base_speed: float = Balance.ENEMIES[key]["speed"]
	return base_speed * get_enemy_speed_multiplier()


## FIXED base HP per unit type — NEVER increases with wave_num! Only mutations scale HP.
func get_enemy_wave_hp(enemy_type: String, _wave_num: int = 1) -> int:
	var key: String = normalize_enemy_type(enemy_type)
	var cfg: Dictionary = Balance.ENEMIES[key]
	var base_hp: float = float(cfg["base_hp"])
	var scaled: float = base_hp * get_enemy_hp_multiplier()
	return int(round(scaled))


func get_tower_damage_research_multiplier() -> float:
	var ranks: int = get_research_rank("reinforced_shots")
	if ranks <= 0 and mission.owned_research.get("reinforced_shots", false):
		ranks = 1
	return 1.0 + float(ranks) * float(Balance.RESEARCH_NODES["reinforced_shots"]["damage_bonus"])


func get_tower_range_research_multiplier() -> float:
	var ranks: int = get_research_rank("extended_optics")
	if ranks <= 0 and mission.owned_research.get("extended_optics", false):
		ranks = 1
	return 1.0 + float(ranks) * float(Balance.RESEARCH_NODES["extended_optics"]["range_bonus"])


func get_tower_attack_speed_multiplier() -> float:
	var ranks: int = get_research_rank("rapid_cycling")
	if ranks <= 0 and mission.owned_research.get("rapid_cycling", false):
		ranks = 1
	var research_bonus: float = 1.0 + float(ranks) * float(Balance.RESEARCH_NODES["rapid_cycling"]["fire_rate_bonus"])
	var surge_penalty: float = pow(Balance.SURGE_ATTACK_SPEED_FACTOR, mission.surge_count)
	var haste_mult: float = (1.0 + float(Balance.TIME_POWERS["haste"]["tower_attack_speed_bonus"])) if is_haste_active else 1.0
	return research_bonus * surge_penalty * haste_mult


func get_construction_speed_multiplier() -> float:
	if is_haste_active:
		return float(Balance.TIME_POWERS["haste"]["construction_speed_multiplier"])
	return 1.0


func is_base_locked() -> bool:
	return mission.manipulator_upgrading_remaining > 0.0


func is_base_charging() -> bool:
	return base_attack_charging_active
