extends Node

## Central GameState autoload owning the single GameClock and MissionState.
## Missions reset cleanly via reset_mission().

signal mission_reset
signal enemy_killed(enemy_type: String, money_gained: int, research_gained: int, world_pos: Vector2)
signal enemy_leaked(enemy_type: String, lives_lost: int)
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal time_power_used(power_name: String)
signal surge_triggered(surge_count: int)

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
	var snapshot: Dictionary = {}

var mission: MissionState = MissionState.new()
var mission_elapsed_seconds: float = 0.0
var is_clock_paused: bool = false


func _ready() -> void:
	reset_mission()


func _process(delta: float) -> void:
	if not is_clock_paused:
		mission_elapsed_seconds += delta


func reset_mission() -> void:
	mission = MissionState.new()
	mission_elapsed_seconds = 0.0
	is_clock_paused = false
	mission_reset.emit()


func get_enemy_hp_multiplier() -> float:
	var stacks: int = mission.mutations.get("armoured_stacks", 0)
	return pow(1.0 + Balance.TIME_POWERS["rewind"]["hp_bonus_per_stack"], stacks)


func get_enemy_speed_multiplier() -> float:
	var stacks: int = mission.mutations.get("swift_stacks", 0)
	return pow(1.0 + Balance.TIME_POWERS["haste"]["speed_bonus_per_stack"], stacks)


func get_tower_attack_speed_multiplier() -> float:
	var research_bonus: float = 1.0
	if mission.owned_research.get("rapid_cycling", false):
		research_bonus += Balance.RESEARCH_NODES["rapid_cycling"]["fire_rate_bonus"]
	var surge_penalty: float = pow(Balance.SURGE_ATTACK_SPEED_FACTOR, mission.surge_count)
	return research_bonus * surge_penalty
