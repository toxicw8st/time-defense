extends Node

## Central GameState autoload owning the single GameClock and MissionState.
## Missions reset cleanly via reset_mission().

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
signal event_logged(message: String)

class MissionState:
	var wave_number: int = 1
	var lives: int = Balance.PLAYER_STARTING_LIVES
	var enemy_base_hp: int = Balance.ENEMY_BASE_MAX_HP
	var mutations: Dictionary = {
		"armoured_stacks": 0,
		"thaw_stacks": 0,
		"swift_stacks": 0,
	}
	var surge_count: int = 0
	var surge_timer_seconds: float = Balance.SURGE_BASE_WINDOW
	var manipulator_level: int = 1
	var manipulator_upgrading_remaining: float = 0.0
	var economy: Dictionary = {
		"money": Balance.STARTING_MONEY,
		"research": Balance.STARTING_RESEARCH,
		"refineries_owned": Balance.STARTING_REFINERIES,
	}
	var owned_research: Dictionary = {}
	var cleared_waves: Dictionary = {}
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
var is_enemies_frozen: bool = false
var is_haste_active: bool = false


func _ready() -> void:
	reset_mission()


func _process(delta: float) -> void:
	if not is_clock_paused and not mission.is_over:
		mission_elapsed_seconds += delta


func reset_mission() -> void:
	mission = MissionState.new()
	mission_elapsed_seconds = 0.0
	is_clock_paused = false
	is_enemies_frozen = false
	is_haste_active = false
	mission_reset.emit()


func spend_money(amount: int) -> bool:
	if amount < 0 or mission.economy["money"] < amount:
		return false
	mission.economy["money"] -= amount
	economy_changed.emit()
	return true


func add_money(amount: int, count_as_earned: bool = true) -> void:
	if amount <= 0:
		return
	mission.economy["money"] += amount
	if count_as_earned:
		mission.stats["money_earned"] += amount
	economy_changed.emit()


func add_research(amount: int) -> void:
	if amount <= 0:
		return
	mission.economy["research"] += amount
	mission.stats["research_earned"] += amount
	economy_changed.emit()


func spend_research(amount: int) -> bool:
	if amount < 0 or mission.economy["research"] < amount:
		return false
	mission.economy["research"] -= amount
	economy_changed.emit()
	return true


func award_kill_earnings(enemy_type: String, money_gained: int, research_gained: int, world_pos: Vector2) -> void:
	add_money(money_gained, true)
	add_research(research_gained)
	enemy_killed.emit(enemy_type, money_gained, research_gained, world_pos)


func lose_lives(amount: int, enemy_type: String = "runner", world_pos: Vector2 = Vector2.ZERO) -> void:
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


func get_enemy_hp_multiplier() -> float:
	var stacks: int = mission.mutations.get("armoured_stacks", 0)
	return pow(1.0 + Balance.TIME_POWERS["rewind"]["hp_bonus_per_stack"], stacks)


func get_enemy_speed_multiplier() -> float:
	if is_enemies_frozen:
		return 0.0
	var stacks: int = mission.mutations.get("swift_stacks", 0)
	return pow(1.0 + Balance.TIME_POWERS["haste"]["speed_bonus_per_stack"], stacks)


func get_effective_enemy_speed(enemy_type: String) -> float:
	var base_speed: float = Balance.ENEMIES[enemy_type]["speed"]
	return base_speed * get_enemy_speed_multiplier()


func get_enemy_wave_hp(enemy_type: String, wave_num: int) -> int:
	var cfg: Dictionary = Balance.ENEMIES[enemy_type]
	var base_hp: float = cfg["base_hp"]
	var growth: float = cfg["hp_growth_per_wave"]
	var first_wave: int = cfg.get("first_wave", 1)
	var steps: int = max(0, wave_num - first_wave)
	var scaled: float = base_hp * pow(1.0 + growth, steps) * get_enemy_hp_multiplier()
	return int(round(scaled))


func get_tower_damage_research_multiplier() -> float:
	var bonus: float = 0.0
	if mission.owned_research.get("reinforced_shots", false):
		bonus += Balance.RESEARCH_NODES["reinforced_shots"]["damage_bonus"]
	return 1.0 + bonus


func get_tower_range_research_multiplier() -> float:
	var bonus: float = 0.0
	if mission.owned_research.get("extended_optics", false):
		bonus += Balance.RESEARCH_NODES["extended_optics"]["range_bonus"]
	return 1.0 + bonus


func get_tower_attack_speed_multiplier() -> float:
	var research_bonus: float = 1.0
	if mission.owned_research.get("rapid_cycling", false):
		research_bonus += Balance.RESEARCH_NODES["rapid_cycling"]["fire_rate_bonus"]
	var surge_penalty: float = pow(Balance.SURGE_ATTACK_SPEED_FACTOR, mission.surge_count)
	return research_bonus * surge_penalty


func get_construction_speed_multiplier() -> float:
	if is_haste_active:
		return float(Balance.TIME_POWERS["haste"]["construction_speed_multiplier"])
	return 1.0
