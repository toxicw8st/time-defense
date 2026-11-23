class_name Balance
extends RefCounted

## All balance numbers using exact notation:
## s$ = spawn cost (threat cost to spawn an enemy unit)
## b$ = bounty (player $ earned for killing an enemy unit)
## $  = player money (starting $, tower $, refinery $, base-attack $)
## s$ and b$ are strictly separate numbers.

# --- Viewport & Map ---
const VIEWPORT_WIDTH: int = 1280
const VIEWPORT_HEIGHT: int = 720
const TARGET_PATH_LENGTH_PX: float = 1891.0
const TARGET_BUILD_PADS: int = 20

# --- Player Base & Starting State ---
const PLAYER_STARTING_LIVES: int = 20
const STARTING_MONEY: int = 200 # $200 starting money
const STARTING_RESEARCH: int = 0
const STARTING_REFINERIES: int = 0 # 0 pre-built; player chooses whether to invest $250

# --- Wave Length & Engagement Model ---
## Wave 1 = 180s (3 min), +10s per wave: 180 + 10 * (wave - 1)
const WAVE_BASE_LENGTH_SECONDS: float = 180.0
const WAVE_LENGTH_ADD_PER_WAVE: float = 10.0
const ENGAGEMENT_FRACTION: float = 0.30 # 0.3 engagement window along path
const BASE_UNIT_SPEED_PX: float = 12.0  # 1.0x speed (~158s path traversal + ~22s stream = ~180s W1 length)

# --- Money / Difficulty Algorithm Constants ---
const THREAT_START_S_DOLLARS: float = 20.0 # Wave 1 = s$20
const THREAT_GROWTH_RATE: float = 1.07     # ~7% s$ growth per wave (Wave 45 ~ s$393)
const MODEL_DPS_PER_DOLLAR: float = 0.153  # Calibrates $180 W1 spend -> ~27.5 DPS (ratio 1.02 vs 27 needed)

# --- 4x3 Damage Matrix (Normal, Piercing, Laser, Time vs Standard, Armored, Reflective) ---
const TIME_DECAY_MAX_TICK_PCT: float = 0.30 # Cap effective per-tick Time damage at 30% of current HP

const DAMAGE_MATRIX: Dictionary = {
	"Normal": {
		"Standard": 1.00,
		"Armored": 0.50,
		"Reflective": 1.10,
	},
	"Piercing": {
		"Standard": 0.75,
		"Armored": 1.50,
		"Reflective": 1.20,
	},
	"Laser": {
		"Standard": 1.50,
		"Armored": 0.85,
		"Reflective": 0.10,
	},
	"Time": {
		"Standard": 1.00,
		"Armored": 1.20,
		"Reflective": 1.50,
	},
}

const TARGETING_MODES: Array[String] = ["first", "last", "strongest", "weakest", "fastest", "slowest"]
const TARGETING_LABELS: Dictionary = {
	"first": "First",
	"last": "Last",
	"strongest": "Strongest",
	"weakest": "Weakest",
	"fastest": "Fastest",
	"slowest": "Slowest",
}
const TARGETING_SHORT_TAGS: Dictionary = {
	"first": "1ST",
	"last": "LST",
	"strongest": "STR",
	"weakest": "WK",
	"fastest": "FST",
	"slowest": "SLW",
}

# --- Towers ($ costs, 4 Damage Types: Piercing, Normal, Laser, Time) ---
const TOWERS: Dictionary = {
	"blaster": {
		"name": "Blaster Turret",
		"role": "Armor-piercing Juggernaut counter",
		"cost": 90, # $90 (2 Blasters = $180 = 90% of $200 W1 spend)
		"build_time": 4.0,
		"damage": 11.5,
		"fire_rate": 1.2, # 13.8 base DPS (~0.153 DPS/$); 150% vs Armored, 120% vs Reflective, 180% vs Juggernaut
		"range": 108.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Piercing (180% vs Juggernaut)",
		"damage_rating": "Medium",
		"speed_rating": "High",
		"targeting": "first",
	},
	"mortar": {
		"name": "Cluster Mortar",
		"role": "Lobbed splash shells vs bunched ground units",
		"cost": 110, # $110
		"build_time": 7.0,
		"damage": 22.0,
		"fire_rate": 0.5, # 11.0 single DPS, high AoE DPS; Normal damage (100% Std, 50% Arm, 110% Refl)
		"range": 135.0,
		"min_range": 60.0,
		"splash_radius": 70.0,
		"splash_edge_ratio": 0.5,
		"damage_type": "Normal",
		"damage_type_label": "Normal (Splash)",
		"damage_rating": "High",
		"speed_rating": "Low",
		"targeting": "first",
		"projectile_flight_time": 0.55,
	},
	"laser": {
		"name": "Laser Spire",
		"role": "Continuous thermal beam; melts Standard, weak vs Reflective",
		"cost": 100, # $100
		"build_time": 5.0,
		"damage": 6.2,
		"fire_rate": 2.5, # 15.5 base DPS (23.25 DPS vs Standard at 150%; 10% vs Reflective)
		"range": 112.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Laser",
		"damage_type_label": "Laser",
		"damage_rating": "High vs Std",
		"speed_rating": "Very High",
		"targeting": "first",
	},
	"slow": {
		"name": "Chrono Slow Tower",
		"role": "Slows 30% for 2s (Jugg 15%) + flat Time Decay DoT upgrades",
		"cost": 100, # $100
		"build_time": 5.0,
		"damage": 0.0, # Base: 0 decay - slow only, no direct damage
		"fire_rate": 1.0, # 1 shot/sec
		"range": 115.0, # Medium range
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Time",
		"damage_type_label": "Time (30% Slow + Flat Decay DoT)",
		"damage_rating": "0..95/s Time DoT",
		"speed_rating": "Medium (1.0/s)",
		"targeting": "first",
		"slow_pct": 0.30,
		"slow_duration": 2.0,
		"decay_ticks": 3,
		"decay_flat_by_level": [0.0, 12.0, 26.0, 44.0, 66.0, 95.0],
	},
	"railgun": {
		"name": "Time Decay Rail Gun",
		"role": "Long-range hitscan rail: 140 Time impact + 50% slow 4s (Jugg 25%) + flat Decay DoT",
		"cost": 375, # $375 (~$350-400)
		"build_time": 8.0,
		"damage": 140.0, # Heavy direct Time rail-slug impact damage + flat Time Decay DoT
		"fire_rate": 0.20, # 1 shot every 5 seconds
		"range": 310.0, # 2.7x Slow tower range (within 2.5-3x)
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Time",
		"damage_type_label": "Time Rail (Impact + 50% Slow + Decay)",
		"damage_rating": "Very High + DoT",
		"speed_rating": "Slow (1/5s)",
		"targeting": "first",
		"slow_pct": 0.50,
		"slow_duration": 4.0,
		"decay_ticks": 3,
		"decay_flat_by_level": [25.0, 50.0, 82.0, 120.0, 170.0, 235.0],
	},
	"annihilator": {
		"name": "Gauss Annihilator",
		"role": "Heavy armor-piercing boss killer (180% vs Juggernaut)",
		"cost": 240, # $240
		"build_time": 6.5,
		"damage": 65.0, # 117 dmg/shot vs Juggernaut at Lv0; 491 dmg/shot vs Juggernaut at Lv5
		"fire_rate": 0.75, # 48.75 base DPS (87.75 DPS vs Juggernaut at Lv0)
		"range": 155.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Piercing Heavy (180% vs Juggernaut)",
		"damage_rating": "Extreme vs Boss",
		"speed_rating": "Medium",
		"targeting": "strongest",
	},
}

const TOWER_UPGRADE_MAX_LEVEL: int = 5
const TOWER_UPGRADE_COSTS: Array[int] = [60, 95, 145, 220, 330] # $ per upgrade level (Damage / Decay & Fire Rate, Lv 1..5)
const TOWER_RANGE_UPGRADE_COSTS: Array[int] = [75, 160, 320, 440, 580] # Range Lv 1..5
const TOWER_UPGRADE_BUILD_TIMES: Array[float] = [3.0, 4.0, 5.0, 6.0, 7.0]
const TOWER_DAMAGE_TOTAL_BONUSES: Array[float] = [0.0, 0.35, 0.80, 1.40, 2.20, 3.20] # Up to 4.20x damage at Lv5
const TOWER_DAMAGE_PER_LEVEL: float = 0.25 # Legacy fallback constant
const TOWER_RANGE_TOTAL_BONUSES: Array[float] = [0.0, 0.25, 0.60, 1.00, 1.30, 1.60] # Lv1 +25%, Lv2 +60%, Lv3 +100% (2x), Lv4 +130%, Lv5 +160%
const TOWER_RANGE_PER_LEVEL: float = 0.25 # Legacy fallback constant
const TOWER_FIRE_RATE_TOTAL_BONUSES: Array[float] = [0.0, 0.20, 0.45, 0.75, 1.10, 1.50] # Up to 2.50x fire rate at Lv5
const TOWER_FIRE_RATE_PER_LEVEL: float = 0.15
const TOWER_SELL_REFUND_RATIO: float = 0.5 # LOCKED 50% refund

# --- Enemies (Fixed HP — NEVER scaled by wave number; separate s$ and b$) ---
const ENEMIES: Dictionary = {
	"crawler": {
		"name": "Crawler",
		"spawn_cost_s": 1, # s$1
		"bounty_b": 4,     # b$4
		"base_hp": 50.0,
		"speed_mult": 1.0,
		"speed": BASE_UNIT_SPEED_PX * 1.0,
		"armour_label": "Standard",
		"armour_tags": ["Standard"],
		"money_on_kill": 4, # b$4
		"research_on_kill": 1,
		"leak_cost": 1,
		"first_wave": 1,
	},
	"rusher": {
		"name": "Rusher",
		"spawn_cost_s": 2, # s$2
		"bounty_b": 6,     # b$6
		"base_hp": 50.0,
		"speed_mult": 2.0,
		"speed": BASE_UNIT_SPEED_PX * 2.0,
		"armour_label": "Standard",
		"armour_tags": ["Standard"],
		"money_on_kill": 6, # b$6
		"research_on_kill": 1,
		"leak_cost": 1,
		"first_wave": 2,
	},
	"brute": {
		"name": "Brute",
		"spawn_cost_s": 8, # s$8
		"bounty_b": 20,    # b$20
		"base_hp": 600.0,
		"speed_mult": 0.9,
		"speed": BASE_UNIT_SPEED_PX * 0.9,
		"armour_label": "Armored",
		"armour_tags": ["Armored"],
		"money_on_kill": 20, # b$20
		"research_on_kill": 2,
		"leak_cost": 3,
		"first_wave": 5,
	},
	"blitzer": {
		"name": "Blitzer",
		"spawn_cost_s": 26, # s$26
		"bounty_b": 30,     # b$30
		"base_hp": 250.0,
		"speed_mult": 3.0,
		"speed": BASE_UNIT_SPEED_PX * 3.0,
		"armour_label": "Reflective",
		"armour_tags": ["Reflective"],
		"money_on_kill": 30, # b$30
		"research_on_kill": 3,
		"leak_cost": 2,
		"first_wave": 8,
	},
	"juggernaut": {
		"name": "Juggernaut",
		"spawn_cost_s": 40, # s$40 (cut from s$120; joins regular wave pool after Wave 10)
		"bounty_b": 50,     # b$50
		"base_hp": 5000.0,
		"speed_mult": 1.15,
		"speed": BASE_UNIT_SPEED_PX * 1.15,
		"armour_label": "Armored + Reflective",
		"armour_tags": ["Armored", "Reflective"],
		"money_on_kill": 50, # b$50
		"research_on_kill": 5,
		"leak_cost": 5,
		"first_wave": 10,
	},
}

# --- Economies: Refineries ($ exponential ramp) & Rogue-like Meta-Research ---
## Cost = $250 * 1.8^(owned) -> $250, $450, $810, $1,460, $2,625
## Income = $0.25/sec per refinery (+$1 every 4.0s tick).
const REFINERY_RATE_PER_SEC: float = 0.25
const REFINERY_TICK_INTERVAL: float = 4.0
const REFINERY_INCOME_PER_TICK: int = 1 # $1 per 4.0s = $0.25/sec
const REFINERY_BASE_COST: float = 250.0
const REFINERY_COST_GROWTH: float = 1.80
const REFINERY_COST_ROUND_TO: int = 5
const REFINERY_BUILD_TIME: float = 8.0

const WAVE_CLEAR_BONUS_BASE: int = 0
const WAVE_CLEAR_BONUS_PER_WAVE: int = 0

## Rogue-like meta-progression: spent ONLY on Between-Levels / Level Picker screen, persists across missions.
## Doubling+ rank costs: 100, 250, 600, 1400, 3200 Research.
const RESEARCH_RANK_COSTS: Array[int] = [100, 250, 600, 1400, 3200]
const MAX_RESEARCH_PER_MISSION: int = 60 # Hard cap per mission so 1 mission (<60 R) cannot buy Rank 1 (100 R)
const REWIND_RESEARCH_MULT: float = 0.25 # Diminishing research on Rewind replays

const RESEARCH_NODES: Dictionary = {
	"rapid_cycling": {
		"name": "Rapid Cycling",
		"cost": 100,
		"rank_costs": RESEARCH_RANK_COSTS,
		"description": "+5% fire speed per rank, all towers",
		"fire_rate_bonus": 0.05,
	},
	"reinforced_shots": {
		"name": "Reinforced Shots",
		"cost": 100,
		"rank_costs": RESEARCH_RANK_COSTS,
		"description": "+5% damage per rank, all towers",
		"damage_bonus": 0.05,
	},
	"extended_optics": {
		"name": "Extended Optics",
		"cost": 100,
		"rank_costs": RESEARCH_RANK_COSTS,
		"description": "+5% range per rank, all towers",
		"range_bonus": 0.05,
	},
	"efficient_manipulator": {
		"name": "Efficient Manipulator",
		"cost": 100,
		"rank_costs": RESEARCH_RANK_COSTS,
		"description": "-10% power cooldowns per rank",
		"cooldown_reduction": 0.10,
	},
	"hive_breaker": {
		"name": "Hive Breaker",
		"cost": 100,
		"rank_costs": RESEARCH_RANK_COSTS,
		"description": "+10% base-attack damage per rank",
		"base_attack_bonus": 0.10,
	},
}

# --- Time Powers & Mutations ---
## Rewind: +5% HP (next wave). Pause: +5% HP (x1.10 total by W11). Haste: +50% tower spd & +50% build for 30s, +5% speed.
const TIME_POWERS: Dictionary = {
	"rewind": {
		"name": "Rewind",
		"short_effect": "Replay prev wave (no mut); keep b$",
		"cost_label": "Cost: next wave +5% HP",
		"cooldown": 65.0,
		"post_wave_window": 9999.0,
		"mutation": "armoured",
		"mutation_label": "Armoured",
		"hp_bonus_per_stack": 0.05,
	},
	"pause": {
		"name": "Pause",
		"short_effect": "Freeze aliens 8s; towers fire",
		"cost_label": "Cost: aliens +5% HP",
		"duration": 8.0,
		"cooldown": 55.0,
		"mutation": "thaw_hardened",
		"mutation_label": "Thaw-hardened",
		"eff_hp_bonus_per_stack": 0.05,
		"frozen_damage_reduction_per_stack": 0.10,
		"frozen_damage_reduction_cap": 0.50,
	},
	"haste": {
		"name": "Haste",
		"short_effect": "Towers +50% spd & build +50% (30s)",
		"cost_label": "Cost: aliens +5% speed",
		"duration": 30.0,
		"cooldown": 50.0,
		"tower_attack_speed_bonus": 0.50,
		"construction_speed_multiplier": 1.50,
		"mutation": "swift",
		"mutation_label": "Swift",
		"speed_bonus_per_stack": 0.05,
	},
}

# --- Surge (5-Wave Deadline + Time Countdown) ---
## Surge deadline: beginning of Wave 6 if no time ability used in Waves 1-5; resets to +5 waves on any use.
const SURGE_WAVE_SPAN: int = 5
const SURGE_BASE_WINDOW: float = 950.0 # ~5 full waves of active combat (fallback timer; wave deadline = Wave 6)
const SURGE_WARNING_AMBER: float = 15.0
const SURGE_WARNING_RED: float = 7.0
const SURGE_ATTACK_SPEED_FACTOR: float = 0.95 # -5% tower attack speed per surge, permanent for mission

# --- Manipulator Upgrades ($ costs, Lv 1..5) ---
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
		"benefit_text": "Pause 8 s -> 10 s; Haste 30 s -> 36 s",
		"pause_duration": 10.0,
		"haste_duration": 36.0,
	},
	4: {
		"cost": 400,
		"build_time": 20.0,
		"benefit_text": "Surge deadline +1 wave (6 waves)",
		"surge_window": 1140.0,
		"surge_wave_span": 6,
	},
	5: {
		"cost": 600,
		"build_time": 25.0,
		"benefit_text": "Base-attack charge time -20%",
		"base_attack_charge_multiplier": 0.80,
	},
}

# --- Enemy Base & Hive Destroyer ($450 charge cost, 1/N rule) ---
const ENEMY_BASE_MAX_HP: int = 500
const BASE_ATTACK_DEFAULT_LEVEL: int = 3 # Level 3 = 3 shots (167 dmg/shot); Level 1 = 1 shot (500); Level 2 = 2 shots (250)
const BASE_ATTACK_TEST_DAMAGE_OVERRIDE: int = 167
const BASE_ATTACK_COST: int = 450 # $450 per shot (requires multiple waves of savings / Rewind farming)
const BASE_ATTACK_CHARGE_TIME: float = 30.0
const BASE_ATTACK_FIRE_WARNING_TIME: float = 1.0


static func get_wave_length(wave_number: int) -> float:
	return WAVE_BASE_LENGTH_SECONDS + WAVE_LENGTH_ADD_PER_WAVE * float(maxi(0, wave_number - 1))


static func get_spend_pct(wave_number: int) -> float:
	if wave_number <= 1:
		return 0.90
	if wave_number % 10 == 0:
		return 0.90 # Boss wave 10, 20, 30... 90% reset
	if wave_number < 10:
		return 0.90 - 0.01 * float(wave_number - 1) # W1=90%..W9=82%
	return 0.90 - 0.01 * float(wave_number % 10)    # W11=89%..W19=81%


static func get_tower_upgrade_cost(stat_key: String, current_level: int) -> int:
	var idx: int = clampi(current_level, 0, TOWER_UPGRADE_MAX_LEVEL - 1)
	if stat_key == "range":
		return TOWER_RANGE_UPGRADE_COSTS[idx]
	return TOWER_UPGRADE_COSTS[idx]


static func get_damage_multiplier(damage_type: String, armour_tags: Array) -> float:
	if not DAMAGE_MATRIX.has(damage_type):
		return 1.0
	var row: Dictionary = DAMAGE_MATRIX[damage_type]
	if damage_type == "Time":
		var max_mult: float = 1.0
		var found: bool = false
		for tag in armour_tags:
			if row.has(tag):
				var val: float = float(row[tag])
				max_mult = val if not found else maxf(max_mult, val)
				found = true
		return max_mult if found else 1.0
	var mult: float = 1.0
	for tag in armour_tags:
		mult *= float(row.get(tag, 1.0))
	return mult
