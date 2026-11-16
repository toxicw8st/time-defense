class_name Balance
extends RefCounted

## All prototype numbers from Implementation Guide pp. 4-5.
## STARTER values are tuned only via TUNING.md after a full run.
## LOCKED rules must never be changed without creator sign-off.

# --- Player Base, Map & Starting State (STARTER) ---
const VIEWPORT_WIDTH: int = 1280
const VIEWPORT_HEIGHT: int = 720
const TARGET_PATH_LENGTH_PX: float = 1900.0
const TARGET_BUILD_PADS: int = 14

const PLAYER_STARTING_LIVES: int = 20
const STARTING_MONEY: int = 200
const STARTING_RESEARCH: int = 0
const STARTING_REFINERIES: int = 1

# --- Towers (STARTER stats, LOCKED roles/sell) ---
const TOWERS: Dictionary = {
	"blaster": {
		"name": "Blaster Turret",
		"role": "Fast single-target workhorse",
		"cost": 75,
		"build_time": 4.0,
		"damage": 12.0,
		"fire_rate": 2.0,
		"range": 150.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type_label": "Piercing",
		"damage_rating": "Medium",
		"speed_rating": "High",
		"targeting": "first",
	},
	"mortar": {
		"name": "Cluster Mortar",
		"role": "Slow splash vs bunched ground aliens",
		"cost": 110,
		"build_time": 7.0,
		"damage": 30.0,
		"fire_rate": 0.5,
		"range": 210.0,
		"min_range": 60.0,
		"splash_radius": 70.0,
		"splash_edge_ratio": 0.5,
		"damage_type_label": "Cluster",
		"damage_rating": "High",
		"speed_rating": "Low",
		"targeting": "densest_cluster",
		"projectile_flight_time": 0.55,
	},
}

const TOWER_UPGRADE_MAX_LEVEL: int = 3
const TOWER_UPGRADE_COSTS: Array[int] = [50, 80, 120]
const TOWER_UPGRADE_BUILD_TIMES: Array[float] = [3.0, 4.0, 5.0]
const TOWER_DAMAGE_PER_LEVEL: float = 0.25
const TOWER_RANGE_PER_LEVEL: float = 0.12
const TOWER_FIRE_RATE_PER_LEVEL: float = 0.15
const TOWER_SELL_REFUND_RATIO: float = 0.5 # LOCKED

# --- Enemies (STARTER) ---
const ENEMIES: Dictionary = {
	"runner": {
		"name": "Runner",
		"base_hp": 40.0,
		"hp_growth_per_wave": 0.12,
		"first_wave": 1,
		"speed": 50.0,
		"money_on_kill": 6,
		"research_on_kill": 1,
		"leak_cost": 1,
	},
	"brute": {
		"name": "Brute",
		"base_hp": 220.0,
		"hp_growth_per_wave": 0.12,
		"first_wave": 8,
		"speed": 32.0,
		"money_on_kill": 20,
		"research_on_kill": 3,
		"leak_cost": 3,
	},
}

# --- Economies (STARTER rates, LOCKED separation) ---
const REFINERY_TICK_INTERVAL: float = 5.0
const REFINERY_INCOME_PER_TICK: int = 8
const REFINERY_BASE_COST: float = 100.0
const REFINERY_COST_GROWTH: float = 1.35
const REFINERY_COST_ROUND_TO: int = 5
const REFINERY_BUILD_TIME: float = 6.0

const WAVE_CLEAR_BONUS_BASE: int = 25
const WAVE_CLEAR_BONUS_PER_WAVE: int = 2

const RESEARCH_NODES: Dictionary = {
	"rapid_cycling": {
		"name": "Rapid Cycling",
		"cost": 30,
		"description": "+5% fire speed, all towers",
		"fire_rate_bonus": 0.05,
	},
	"reinforced_shots": {
		"name": "Reinforced Shots",
		"cost": 30,
		"description": "+5% damage, all towers",
		"damage_bonus": 0.05,
	},
	"extended_optics": {
		"name": "Extended Optics",
		"cost": 40,
		"description": "+5% range, all towers",
		"range_bonus": 0.05,
	},
	"efficient_manipulator": {
		"name": "Efficient Manipulator",
		"cost": 40,
		"description": "-10% power cooldowns",
		"cooldown_reduction": 0.10,
	},
	"hive_breaker": {
		"name": "Hive Breaker",
		"cost": 50,
		"description": "+10% base-attack damage",
		"base_attack_bonus": 0.10,
	},
}

# --- Time Powers (STARTER timings, LOCKED effects) ---
const TIME_POWERS: Dictionary = {
	"rewind": {
		"name": "Rewind",
		"short_effect": "Replay wave; keep builds/loot",
		"cost_label": "Cost: aliens +Armour",
		"cooldown": 65.0,
		"post_wave_window": 5.0,
		"mutation": "armoured",
		"mutation_label": "Armoured",
		"hp_bonus_per_stack": 0.15,
	},
	"pause": {
		"name": "Pause",
		"short_effect": "Freeze aliens; towers fire",
		"cost_label": "Cost: aliens +Thaw",
		"duration": 5.0,
		"cooldown": 55.0,
		"mutation": "thaw_hardened",
		"mutation_label": "Thaw-hardened",
		"frozen_damage_reduction_per_stack": 0.10,
		"frozen_damage_reduction_cap": 0.50,
	},
	"haste": {
		"name": "Haste",
		"short_effect": "Speed up construction 3x",
		"cost_label": "Cost: aliens +Swift",
		"duration": 6.0,
		"cooldown": 50.0,
		"construction_speed_multiplier": 3.0,
		"mutation": "swift",
		"mutation_label": "Swift",
		"speed_bonus_per_stack": 0.08,
	},
}

# --- Surge (STARTER timing, LOCKED behaviour) ---
const SURGE_BASE_WINDOW: float = 45.0
const SURGE_WARNING_AMBER: float = 15.0
const SURGE_WARNING_RED: float = 7.0
const SURGE_ATTACK_SPEED_FACTOR: float = 0.95 # -5% per surge, multiplicative

# --- Manipulator Upgrades (STARTER track, level 1..5) ---
const MANIPULATOR_MAX_LEVEL: int = 5
const MANIPULATOR_UPGRADES: Dictionary = {
	2: {
		"cost": 150,
		"build_time": 10.0,
		"benefit_text": "All power cooldowns -15%",
		"cooldown_multiplier": 0.85,
	},
	3: {
		"cost": 250,
		"build_time": 15.0,
		"benefit_text": "Pause 5 s -> 7 s; Haste 6 s -> 8 s",
		"pause_duration": 7.0,
		"haste_duration": 8.0,
	},
	4: {
		"cost": 400,
		"build_time": 20.0,
		"benefit_text": "Surge window 45 s -> 60 s",
		"surge_window": 60.0,
	},
	5: {
		"cost": 600,
		"build_time": 25.0,
		"benefit_text": "Base-attack charge time -20%",
		"base_attack_charge_multiplier": 0.80,
	},
}

# --- Base Attack: Hive Destroyer (STARTER costs, LOCKED 1/N + no Haste) ---
const ENEMY_BASE_MAX_HP: int = 500
const BASE_ATTACK_MISSION_LEVEL: int = 1
const BASE_ATTACK_TEST_DAMAGE_OVERRIDE: int = 167 # 15-wave test override (3 shots); logged in TUNING.md
const BASE_ATTACK_COST: int = 150
const BASE_ATTACK_CHARGE_TIME: float = 30.0
const BASE_ATTACK_FIRE_WARNING_TIME: float = 1.0
