class_name Balance
extends RefCounted

## All balance numbers using exact notation:
## s$ = spawn cost (threat cost to spawn an enemy unit)
## b$ = bounty (player $ earned for killing an enemy unit)
## $  = player money (starting $, tower $, refinery $, base-attack $)
## s$ and b$ are strictly separate numbers.

# --- Viewport & Map ---
const BALANCE_VERSION: String = "v3.0-chrono-ascension"
const DEFAULT_GAME_SPEED: float = 3.0 # Old 3x is now the crisp 1x default; options: 0.5x (1.5), 1x (3.0), 1.5x (4.5)
const SPEED_OPTION_SLOW: float = 1.5  # 0.5x of default
const SPEED_OPTION_NORMAL: float = 3.0 # 1.0x default
const SPEED_OPTION_FAST: float = 4.5  # 1.5x of default
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
const BASE_TOWER_KEYS: Array[String] = ["blaster", "mortar", "laser", "slow", "railgun", "annihilator"]
const MERGE_SURCHARGE_RATIO: float = 0.35
const MERGE_BUILD_TIME_RATIO: float = 0.65
const COMBINE_MIN_TOTAL_RANKS: int = 3 # BTD5-style earned merge: requires 3+ total upgrade ranks across base towers (Sandbox exempt)

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
		"role": "Heavy 5s-reload splash shells vs bunched ground units",
		"cost": 110, # $110
		"build_time": 7.0,
		"damage": 25.0,
		"fire_rate": 0.20, # Slowed 60% (from 0.50 -> 0.20/s, 1 shell per 5.0s) so 1 Mortar cannot solo Waves 1-3
		"range": 135.0,
		"min_range": 60.0,
		"splash_radius": 70.0,
		"splash_edge_ratio": 0.55,
		"damage_type": "Normal",
		"damage_type_label": "Normal (Splash)",
		"damage_rating": "High",
		"speed_rating": "Very Low (1/5s)",
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
		"role": "Launches AoE Status Bubbles (30% slow, Jugg 15%; Damage upg grows DoT + bubble radius)",
		"cost": 100, # $100
		"build_time": 5.0,
		"damage": 0.0, # Base: 0 decay - AoE slow bubble only
		"fire_rate": 0.40, # Slower (1 bubble every 2.5s) since bubble affects all units entering it
		"range": 115.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Time",
		"damage_type_label": "Time Bubble (30% Slow + Flat Decay DoT)",
		"damage_rating": "0..38/s AoE DoT",
		"speed_rating": "Slow (0.40/s)",
		"targeting": "first",
		"slow_pct": 0.30,
		"slow_duration": 0.50,
		"decay_ticks": 3,
		"decay_flat_by_level": [0.0, 5.0, 11.0, 18.0, 27.0, 38.0],
		"spawns_bubble": true,
		"bubble_duration": 3.5,
		"bubble_radius_by_level": [42.0, 48.0, 54.0, 60.0, 66.0, 74.0],
		"bubble_color": Color(0.28, 0.90, 1.0),
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
		"damage": 56.0, # 100.8 dmg/shot vs Juggernaut at Lv0; scales cleanly with tower-cost upgrades
		"fire_rate": 0.72, # 40.3 base DPS (72.6 DPS vs Juggernaut at Lv0)
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

	# =========================================================================
	# === 21 COMBINED TOWERS (6 Same-Type Merges + 15 Cross-Type Hybrids) ===
	# =========================================================================

	# 1. blaster + blaster
	"blaster+blaster": {
		"name": "Twin-Linked Vulcan Battery",
		"is_combo": true,
		"recipe": ["blaster", "blaster"],
		"merge_fee": 150,
		"role": "Quad-barrel Piercing rotary cannon; every 4th hit triggers +25% Armor-Crack",
		"cost": 245,
		"build_time": 5.0,
		"damage": 11.5,
		"fire_rate": 2.25,
		"range": 125.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Piercing Vulcan (180% vs Juggernaut)",
		"damage_rating": "High DPS",
		"speed_rating": "Very High (2.25/s)",
		"targeting": "first",
		"armor_crack_every": 4,
		"armor_crack_mult": 1.25,
	},
	# 2. mortar + mortar
	"mortar+mortar": {
		"name": "MIRV Siege Howitzer",
		"is_combo": true,
		"recipe": ["mortar", "mortar"],
		"merge_fee": 160,
		"role": "Triple-shell MIRV canister splitting into 3 overlapping 80px Normal explosions",
		"cost": 285,
		"build_time": 9.0,
		"damage": 23.0,
		"fire_rate": 0.25,
		"range": 155.0,
		"min_range": 60.0,
		"splash_radius": 82.0,
		"splash_edge_ratio": 0.60,
		"damage_type": "Normal",
		"damage_type_label": "Normal MIRV (3x Sub-Shells)",
		"damage_rating": "High Triple-AoE",
		"speed_rating": "Slow (0.25/s)",
		"targeting": "first",
		"projectile_flight_time": 0.56,
		"mirv_subshells": 3,
		"mirv_damage_ratio": 0.44,
	},
	# 3. laser + laser
	"laser+laser": {
		"name": "Prismatic Focus Obelisk",
		"is_combo": true,
		"recipe": ["laser", "laser"],
		"merge_fee": 160,
		"role": "Thermal beam ramps up to +84% locked-on heat + refracts 35% arc to 1 nearby target",
		"cost": 265,
		"build_time": 6.5,
		"damage": 7.4,
		"fire_rate": 2.8,
		"range": 130.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Laser",
		"damage_type_label": "Laser Prismatic (150% Std + Chain)",
		"damage_rating": "Very High vs Std",
		"speed_rating": "Ultra (2.8/s)",
		"targeting": "first",
		"ramps_damage": true,
		"ramp_max_stacks": 7,
		"ramp_per_stack": 0.12,
		"refract_radius": 70.0,
		"refract_ratio": 0.35,
	},
	# 4. slow + slow
	"slow+slow": {
		"name": "Stasis Singularity Pylon",
		"is_combo": true,
		"recipe": ["slow", "slow"],
		"merge_fee": 150,
		"role": "Massive 40% AoE Slow Status Bubble (Jugg 20%) + boosted flat Time Decay; upg grows radius",
		"cost": 260,
		"build_time": 6.5,
		"damage": 0.0,
		"fire_rate": 0.36,
		"range": 135.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Time",
		"damage_type_label": "Time Singularity Bubble (40% Slow)",
		"damage_rating": "0..52/s Wide DoT",
		"speed_rating": "Slow (0.36/s)",
		"targeting": "first",
		"slow_pct": 0.40,
		"slow_duration": 0.65,
		"decay_ticks": 3,
		"decay_flat_by_level": [0.0, 6.0, 14.0, 24.0, 36.0, 52.0],
		"spawns_bubble": true,
		"bubble_duration": 4.2,
		"bubble_radius_by_level": [54.0, 60.0, 68.0, 76.0, 84.0, 92.0],
		"bubble_color": Color(0.45, 0.72, 1.0),
	},
	# 5. railgun + railgun
	"railgun+railgun": {
		"name": "Chrono-Breach Supercollider",
		"is_combo": true,
		"recipe": ["railgun", "railgun"],
		"merge_fee": 480,
		"role": "380px line-piercing rail punching up to 3 enemies; 55% slow + heavy Time Decay",
		"cost": 985,
		"build_time": 10.5,
		"damage": 210.0,
		"fire_rate": 0.20,
		"range": 380.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Time",
		"damage_type_label": "Time Collider (Line Pierce + Slow)",
		"damage_rating": "Extreme + DoT",
		"speed_rating": "Slow (0.20/s)",
		"targeting": "strongest",
		"slow_pct": 0.55,
		"slow_duration": 4.5,
		"decay_ticks": 3,
		"decay_flat_by_level": [30.0, 60.0, 96.0, 140.0, 190.0, 250.0],
		"pierce_count": 3,
	},
	# 6. annihilator + annihilator
	"annihilator+annihilator": {
		"name": "Hyper-Velocity MAC Cannon",
		"is_combo": true,
		"recipe": ["annihilator", "annihilator"],
		"merge_fee": 360,
		"role": "Boss assassin: 88 Piercing (158 vs Jugg) +15% opener strike vs healthy targets",
		"cost": 640,
		"build_time": 8.5,
		"damage": 88.0,
		"fire_rate": 0.68,
		"range": 190.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Piercing MAC (180% vs Juggernaut)",
		"damage_rating": "Apex Boss",
		"speed_rating": "Medium-Low (0.68/s)",
		"targeting": "strongest",
		"opener_bonus_pct": 0.15,
	},
	# 7. blaster + mortar
	"blaster+mortar": {
		"name": "Flak Barrage Battery",
		"is_combo": true,
		"recipe": ["blaster", "mortar"],
		"merge_fee": 150,
		"role": "Airburst flak shells (no blind spot): 15 Piercing center hit + 11 Normal 55px shrapnel splash",
		"cost": 260,
		"build_time": 7.0,
		"damage": 15.0,
		"fire_rate": 0.90,
		"range": 135.0,
		"min_range": 0.0,
		"splash_radius": 55.0,
		"splash_edge_ratio": 0.65,
		"damage_type": "Piercing",
		"secondary_damage": 11.0,
		"secondary_damage_type": "Normal",
		"direct_primary_only": true,
		"damage_type_label": "Piercing Direct + Normal Flak",
		"damage_rating": "Medium + AoE",
		"speed_rating": "Medium (0.90/s)",
		"targeting": "first",
	},
	# 8. blaster + laser
	"blaster+laser": {
		"name": "Pulse-Plasma Carbine",
		"is_combo": true,
		"recipe": ["blaster", "laser"],
		"merge_fee": 160,
		"role": "Smart Matrix weapon: hits Standard at 150% Laser & Armored/Refl at 150%/120% Piercing",
		"cost": 255,
		"build_time": 6.0,
		"damage": 8.6,
		"fire_rate": 2.05,
		"range": 122.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Smart Hybrid (Piercing/Laser)",
		"damage_rating": "Versatile High",
		"speed_rating": "Very High (2.05/s)",
		"targeting": "first",
		"smart_matrix": true,
	},
	# 9. blaster + slow
	"blaster+slow": {
		"name": "Chrono-Kinetic Suppressor",
		"is_combo": true,
		"recipe": ["blaster", "slow"],
		"merge_fee": 145,
		"role": "Piercing bursts spawn a Stasis Bubble (30% slow + flat Time Decay; grows w/ Dmg)",
		"cost": 245,
		"build_time": 6.0,
		"damage": 12.0,
		"fire_rate": 1.05,
		"range": 124.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Piercing + Chrono Stasis Bubble",
		"damage_rating": "Med + Bubble DoT",
		"speed_rating": "Medium (1.05/s)",
		"targeting": "fastest",
		"slow_pct": 0.30,
		"slow_duration": 0.50,
		"decay_ticks": 3,
		"decay_flat_by_level": [0.0, 5.0, 11.0, 18.0, 26.0, 36.0],
		"spawns_bubble": true,
		"bubble_duration": 3.0,
		"bubble_radius_by_level": [40.0, 45.0, 50.0, 56.0, 62.0, 68.0],
		"bubble_color": Color(0.35, 0.78, 1.0),
	},
	# 10. blaster + railgun
	"blaster+railgun": {
		"name": "Hyper-Cycle Rail Rifle",
		"is_combo": true,
		"recipe": ["blaster", "railgun"],
		"merge_fee": 310,
		"role": "2.1x faster Time Rail Rifle (260px): 78 Time + 18 Piercing + 45% slow + Decay",
		"cost": 605,
		"build_time": 8.0,
		"damage": 78.0,
		"fire_rate": 0.42,
		"range": 260.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Time",
		"secondary_damage": 18.0,
		"secondary_damage_type": "Piercing",
		"damage_type_label": "Time + Piercing Fast Rail",
		"damage_rating": "High + Slow/DoT",
		"speed_rating": "Medium-Low (0.42/s)",
		"targeting": "strongest",
		"slow_pct": 0.45,
		"slow_duration": 3.2,
		"decay_ticks": 3,
		"decay_flat_by_level": [16.0, 34.0, 56.0, 82.0, 114.0, 150.0],
	},
	# 11. blaster + annihilator
	"blaster+annihilator": {
		"name": "Autocannon Siege Shredder",
		"is_combo": true,
		"recipe": ["blaster", "annihilator"],
		"merge_fee": 240,
		"role": "Rapid heavy Piercing boss shredder (42 dmg @ 1.05/s, 180% vs Juggernaut)",
		"cost": 430,
		"build_time": 7.0,
		"damage": 42.0,
		"fire_rate": 1.05,
		"range": 148.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Piercing Heavy (180% vs Juggernaut)",
		"damage_rating": "Very High Boss",
		"speed_rating": "High (1.05/s)",
		"targeting": "strongest",
	},
	# 12. mortar + laser
	"mortar+laser": {
		"name": "Solar Plasma Artillery",
		"is_combo": true,
		"recipe": ["mortar", "laser"],
		"merge_fee": 160,
		"role": "Searing plasma shells: 20 Normal + 16 Laser blast (68px AoE) melts Standard hordes",
		"cost": 275,
		"build_time": 8.0,
		"damage": 20.0,
		"fire_rate": 0.40,
		"range": 145.0,
		"min_range": 50.0,
		"splash_radius": 68.0,
		"splash_edge_ratio": 0.62,
		"damage_type": "Normal",
		"secondary_damage": 16.0,
		"secondary_damage_type": "Laser",
		"damage_type_label": "Normal + Laser Plasma AoE",
		"damage_rating": "High Crowd AoE",
		"speed_rating": "Low (0.40/s)",
		"targeting": "first",
		"projectile_flight_time": 0.45,
	},
	# 13. mortar + slow
	"mortar+slow": {
		"name": "Cryo-Cluster Bombard",
		"is_combo": true,
		"recipe": ["mortar", "slow"],
		"merge_fee": 155,
		"role": "Lobs shells exploding for 20 Normal splash + leaving a large 34% Slow Status Bubble",
		"cost": 275,
		"build_time": 8.0,
		"damage": 20.0,
		"fire_rate": 0.26,
		"range": 145.0,
		"min_range": 50.0,
		"splash_radius": 70.0,
		"splash_edge_ratio": 0.58,
		"damage_type": "Normal",
		"damage_type_label": "Normal Splash + Time Slow Bubble",
		"damage_rating": "Med AoE + DoT",
		"speed_rating": "Slow (0.26/s)",
		"targeting": "first",
		"projectile_flight_time": 0.52,
		"slow_pct": 0.34,
		"slow_duration": 0.60,
		"decay_ticks": 3,
		"decay_flat_by_level": [0.0, 5.0, 12.0, 20.0, 29.0, 40.0],
		"spawns_bubble": true,
		"bubble_duration": 4.0,
		"bubble_radius_by_level": [54.0, 60.0, 66.0, 73.0, 80.0, 88.0],
		"bubble_color": Color(0.28, 0.94, 0.78),
	},
	# 14. mortar + railgun
	"mortar+railgun": {
		"name": "Orbital Temporal Howitzer",
		"is_combo": true,
		"recipe": ["mortar", "railgun"],
		"merge_fee": 330,
		"role": "285px cross-map howitzer: 110 Time center + 38 Normal splash (75px) + 50% slow + Decay",
		"cost": 630,
		"build_time": 10.0,
		"damage": 110.0,
		"fire_rate": 0.23,
		"range": 285.0,
		"min_range": 40.0,
		"splash_radius": 75.0,
		"splash_edge_ratio": 0.55,
		"damage_type": "Time",
		"secondary_damage": 38.0,
		"secondary_damage_type": "Normal",
		"direct_primary_only": true,
		"damage_type_label": "Time Center + Normal Splash",
		"damage_rating": "High + AoE Slow",
		"speed_rating": "Slow (0.23/s)",
		"targeting": "strongest",
		"projectile_flight_time": 0.62,
		"slow_pct": 0.50,
		"slow_duration": 4.0,
		"decay_ticks": 3,
		"decay_flat_by_level": [20.0, 40.0, 66.0, 96.0, 134.0, 180.0],
	},
	# 15. mortar + annihilator
	"mortar+annihilator": {
		"name": "Armor-Cracker Siege Cannon",
		"is_combo": true,
		"recipe": ["mortar", "annihilator"],
		"merge_fee": 250,
		"role": "Bunker-buster shell: 62 Piercing center (112 vs Jugg) + 24 Normal 65px splash",
		"cost": 455,
		"build_time": 9.0,
		"damage": 62.0,
		"fire_rate": 0.42,
		"range": 160.0,
		"min_range": 45.0,
		"splash_radius": 65.0,
		"splash_edge_ratio": 0.55,
		"damage_type": "Piercing",
		"secondary_damage": 24.0,
		"secondary_damage_type": "Normal",
		"direct_primary_only": true,
		"damage_type_label": "Piercing Direct + Normal Splash",
		"damage_rating": "Very High + AoE",
		"speed_rating": "Low (0.42/s)",
		"targeting": "strongest",
		"projectile_flight_time": 0.48,
	},
	# 16. laser + slow
	"laser+slow": {
		"name": "Stasis Bubble Projector",
		"is_combo": true,
		"recipe": ["laser", "slow"],
		"merge_fee": 155,
		"role": "Fires ionized Laser pulse spawning an AoE Slow Status Bubble w/ burning thermal ticks",
		"cost": 260,
		"build_time": 6.5,
		"damage": 14.0,
		"fire_rate": 0.85,
		"range": 125.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Laser",
		"damage_type_label": "Laser + Ionized Slow Bubble",
		"damage_rating": "Med + Burn Bubble",
		"speed_rating": "Medium (0.85/s)",
		"targeting": "first",
		"slow_pct": 0.30,
		"slow_duration": 0.50,
		"decay_ticks": 3,
		"decay_flat_by_level": [0.0, 5.0, 10.0, 17.0, 25.0, 35.0],
		"spawns_bubble": true,
		"bubble_duration": 3.2,
		"bubble_radius_by_level": [45.0, 50.0, 55.0, 61.0, 67.0, 73.0],
		"bubble_burn_dps": 5.0,
		"bubble_color": Color(0.75, 0.55, 1.0),
	},
	# 17. laser + railgun
	"laser+railgun": {
		"name": "Chrono-Lance Thermal Beam",
		"is_combo": true,
		"recipe": ["laser", "railgun"],
		"merge_fee": 320,
		"role": "290px lance every 2.2s: 50 Time + 28 Laser dmg + 45% slow + flat Time Decay",
		"cost": 620,
		"build_time": 8.5,
		"damage": 50.0,
		"fire_rate": 0.46,
		"range": 290.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Time",
		"secondary_damage": 28.0,
		"secondary_damage_type": "Laser",
		"damage_type_label": "Time + Laser Long Lance",
		"damage_rating": "High Long-Range",
		"speed_rating": "Medium-Low (0.46/s)",
		"targeting": "first",
		"slow_pct": 0.45,
		"slow_duration": 3.5,
		"decay_ticks": 3,
		"decay_flat_by_level": [18.0, 38.0, 62.0, 92.0, 128.0, 170.0],
	},
	# 18. laser + annihilator
	"laser+annihilator": {
		"name": "Thermal Melter Rail-Spire",
		"is_combo": true,
		"recipe": ["laser", "annihilator"],
		"merge_fee": 250,
		"role": "Gauss slugs superheat armor: +10% dmg taken per stack (max +30% vs Boss)",
		"cost": 440,
		"build_time": 7.5,
		"damage": 32.0,
		"fire_rate": 1.00,
		"range": 152.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"secondary_damage": 10.0,
		"secondary_damage_type": "Laser",
		"damage_type_label": "Piercing/Laser + Armor Melt",
		"damage_rating": "High Boss Debuff",
		"speed_rating": "High (1.00/s)",
		"targeting": "strongest",
		"armor_shred_pct": 0.10,
		"armor_shred_max_stacks": 3,
	},
	# 19. slow + railgun
	"slow+railgun": {
		"name": "Absolute Zero Chrono-Cannon",
		"is_combo": true,
		"recipe": ["slow", "railgun"],
		"merge_fee": 330,
		"role": "330px Temporal Rail creates a massive 55% Slow Status Bubble (Jugg 27.5%) + Decay",
		"cost": 620,
		"build_time": 8.5,
		"damage": 105.0,
		"fire_rate": 0.22,
		"range": 330.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Time",
		"damage_type_label": "Time Sniper + Absolute Bubble",
		"damage_rating": "High + Wide Bubble",
		"speed_rating": "Slow (0.22/s)",
		"targeting": "strongest",
		"slow_pct": 0.55,
		"slow_duration": 0.80,
		"decay_ticks": 3,
		"decay_flat_by_level": [18.0, 34.0, 56.0, 82.0, 114.0, 155.0],
		"spawns_bubble": true,
		"bubble_duration": 4.5,
		"bubble_radius_by_level": [60.0, 66.0, 73.0, 80.0, 88.0, 96.0],
		"bubble_color": Color(0.55, 0.72, 1.0),
	},
	# 20. slow + annihilator
	"slow+annihilator": {
		"name": "Temporal Lock Rail-Breaker",
		"is_combo": true,
		"recipe": ["slow", "annihilator"],
		"merge_fee": 240,
		"role": "Heavy 48 Piercing shots drop a Stasis Lock Bubble (30% slow, Jugg 15%) pinning bosses",
		"cost": 440,
		"build_time": 7.5,
		"damage": 48.0,
		"fire_rate": 0.58,
		"range": 155.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Piercing Boss + Lock Bubble",
		"damage_rating": "Very High vs Boss",
		"speed_rating": "Medium-Low (0.58/s)",
		"targeting": "strongest",
		"slow_pct": 0.30,
		"slow_duration": 0.55,
		"decay_ticks": 3,
		"decay_flat_by_level": [0.0, 6.0, 13.0, 21.0, 30.0, 42.0],
		"spawns_bubble": true,
		"bubble_duration": 3.2,
		"bubble_radius_by_level": [44.0, 49.0, 54.0, 59.0, 64.0, 70.0],
		"bubble_color": Color(0.45, 0.85, 1.0),
	},
	# 21. railgun + annihilator
	"railgun+annihilator": {
		"name": "Omega Singularity Gauss-Rail",
		"is_combo": true,
		"recipe": ["railgun", "annihilator"],
		"merge_fee": 450,
		"role": "275px apex boss killer: 85 Piercing + 34 Time impact + 50% slow 4s + Decay",
		"cost": 820,
		"build_time": 9.5,
		"damage": 85.0,
		"fire_rate": 0.34,
		"range": 275.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"secondary_damage": 34.0,
		"secondary_damage_type": "Time",
		"damage_type_label": "Piercing + Time Omega Rail",
		"damage_rating": "Apex Boss Killer",
		"speed_rating": "Slow (0.34/s)",
		"targeting": "strongest",
		"slow_pct": 0.50,
		"slow_duration": 4.0,
		"decay_ticks": 3,
		"decay_flat_by_level": [18.0, 36.0, 58.0, 86.0, 120.0, 160.0],
	},
}

const TOWER_UPGRADE_MAX_LEVEL: int = 5
const TOWER_UPGRADE_COSTS: Array[int] = [60, 95, 145, 220, 330] # Baseline fallback ($90 Blaster)
const TOWER_UPGRADE_BASE_COSTS: Array[int] = [30, 50, 80, 120, 175]
const TOWER_UPGRADE_COST_RATIOS: Array[float] = [0.35, 0.55, 0.85, 1.25, 1.80]
const TOWER_RANGE_UPGRADE_COSTS: Array[int] = [75, 160, 320, 440, 580] # Range Lv 1..5 baseline
const TOWER_RANGE_EXTRA_RATIOS: Array[float] = [0.15, 0.25, 0.40, 0.55, 0.70]
const TOWER_UPGRADE_BUILD_TIMES: Array[float] = [3.0, 4.0, 5.0, 6.0, 7.0]
const TOWER_DAMAGE_TOTAL_BONUSES: Array[float] = [0.0, 0.30, 0.68, 1.15, 1.70, 2.35] # Up to 3.35x damage at Lv5
const TOWER_DAMAGE_PER_LEVEL: float = 0.25 # Legacy fallback constant
const TOWER_RANGE_TOTAL_BONUSES: Array[float] = [0.0, 0.25, 0.60, 1.00, 1.30, 1.60] # Lv1 +25%, Lv2 +60%, Lv3 +100% (2x), Lv4 +130%, Lv5 +160%
const TOWER_RANGE_PER_LEVEL: float = 0.25 # Legacy fallback constant
const TOWER_FIRE_RATE_TOTAL_BONUSES: Array[float] = [0.0, 0.18, 0.38, 0.62, 0.90, 1.20] # Up to 2.20x fire rate at Lv5
const TOWER_FIRE_RATE_PER_LEVEL: float = 0.15
const TOWER_SELL_REFUND_RATIO: float = 0.5 # LOCKED 50% refund

# =========================================================================
# === BTD5-STYLE TIER-4 MILESTONE PERKS & TIER-5 APEX OVERDRIVE (ALL 21) ==
# =========================================================================
# Unlocked directly on any Combined Tower (apex_tier 0 -> 1 -> 2).
# Massive aspirational save-up targets that transform combat mechanics & visuals!
const COMBO_EVOLUTIONS: Dictionary = {
	"blaster+blaster": {
		"t4": {
			"name": "Hyper-Rotary Shred",
			"cost": 1250,
			"build_time": 5.0,
			"desc": "+30% fire rate, +25% dmg & rounds ricochet to 1 nearby target (55% dmg).",
			"mods": {"rate_mult": 1.30, "dmg_mult": 1.25, "ricochet_count": 1, "ricochet_ratio": 0.55},
		},
		"t5": {
			"name": "Storm-Wall Gatling",
			"cost": 3800,
			"build_time": 7.5,
			"desc": "APEX: +65% fire rate, +70% dmg, 2 ricochets (70% dmg), Armor-Crack +55% & pierces Shield Auras.",
			"mods": {"rate_mult": 1.65, "dmg_mult": 1.70, "ricochet_count": 2, "ricochet_ratio": 0.70, "armor_crack_mult_add": 0.30, "strip_shield_aura": true},
		},
	},
	"mortar+mortar": {
		"t4": {
			"name": "Cluster Saturation",
			"cost": 1400,
			"build_time": 5.5,
			"desc": "5 MIRV sub-shells, +20% blast radius, +35% dmg & 0.45s concussive stun.",
			"mods": {"dmg_mult": 1.35, "bonus_mirv_subshells": 2, "splash_mult": 1.20, "stun_duration": 0.45},
		},
		"t5": {
			"name": "Carpet-Bomb Citadel",
			"cost": 4200,
			"build_time": 8.0,
			"desc": "APEX: 7 MIRV sub-shells, +35% splash, +95% dmg, +30% fire rate & 0.85s shockwave stun.",
			"mods": {"dmg_mult": 1.95, "rate_mult": 1.30, "bonus_mirv_subshells": 4, "splash_mult": 1.35, "stun_duration": 0.85},
		},
	},
	"laser+laser": {
		"t4": {
			"name": "Tri-Prism Refraction",
			"cost": 1350,
			"build_time": 5.0,
			"desc": "Beam chains to 3 nearby targets (50% arc), +30% dmg, ramps to 10 stacks & reveals Cloaked.",
			"mods": {"dmg_mult": 1.30, "bonus_refract_targets": 2, "refract_radius_add": 28.0, "refract_ratio_add": 0.15, "ramp_max_add": 3, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Solaris Hyper-Prism",
			"cost": 4100,
			"build_time": 7.5,
			"desc": "APEX: Chains to 5 targets (70% arc), +95% dmg, +30% speed, 12 ramp stacks & Slag Nova burst on kill.",
			"mods": {"dmg_mult": 1.95, "rate_mult": 1.30, "bonus_refract_targets": 4, "refract_radius_add": 48.0, "refract_ratio_add": 0.35, "ramp_max_add": 5, "reveals_cloaked": true, "slag_nova_dmg": 120.0},
		},
	},
	"slow+slow": {
		"t4": {
			"name": "Event-Horizon Field",
			"cost": 1300,
			"build_time": 5.0,
			"desc": "Bubbles +25% wider, +1.5s longer, +10% slow, +50% Decay & completely strip Bio-Mender regen.",
			"mods": {"bubble_radius_mult": 1.25, "bubble_duration_add": 1.5, "bubble_slow_add": 0.10, "decay_mult": 1.50, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Temporal Vortex Engine",
			"cost": 4000,
			"build_time": 7.5,
			"desc": "APEX: Massive +40% Vortex Bubbles pull enemies BACKWARD along the path, +18% slow & 2.4x Decay!",
			"mods": {"bubble_radius_mult": 1.40, "bubble_duration_add": 2.6, "bubble_slow_add": 0.18, "decay_mult": 2.40, "bubble_pull_px_per_sec": 13.0, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
	},
	"railgun+railgun": {
		"t4": {
			"name": "Sub-Atomic Accelerator",
			"cost": 2400,
			"build_time": 6.0,
			"desc": "Pierces 5 lined-up enemies, +40% dmg, +45% Decay, +12% range & ignores Conduit Shield Auras.",
			"mods": {"dmg_mult": 1.40, "decay_mult": 1.45, "range_mult": 1.12, "bonus_pierce": 2, "strip_shield_aura": true},
		},
		"t5": {
			"name": "Rift-Tear Supercollider",
			"cost": 7400,
			"build_time": 8.5,
			"desc": "APEX: Pierces 8 enemies across map, +120% dmg, +45% fire rate, 2.2x Decay & 0.6s temporal stun.",
			"mods": {"dmg_mult": 2.20, "rate_mult": 1.45, "decay_mult": 2.20, "range_mult": 1.22, "bonus_pierce": 5, "stun_duration": 0.60, "strip_shield_aura": true},
		},
	},
	"annihilator+annihilator": {
		"t4": {
			"name": "Tungsten Hyper-Sabot",
			"cost": 2100,
			"build_time": 5.5,
			"desc": "+40% dmg, +35% opener crit (+50% total), +15% fire rate & bypasses Conduit Shield Auras.",
			"mods": {"dmg_mult": 1.40, "rate_mult": 1.15, "opener_bonus_add": 0.35, "strip_shield_aura": true},
		},
		"t5": {
			"name": "Dreadnought Obliterator",
			"cost": 6600,
			"build_time": 8.0,
			"desc": "APEX: +125% dmg, +35% fire rate, +60% opener, pierces 2 bosses & executes targets <8% HP.",
			"mods": {"dmg_mult": 2.25, "rate_mult": 1.35, "opener_bonus_add": 0.60, "bonus_pierce": 1, "execute_hp_pct": 0.08, "strip_shield_aura": true},
		},
	},
	"blaster+mortar": {
		"t4": {
			"name": "Proximity Shrapnel Storm",
			"cost": 1300,
			"build_time": 5.0,
			"desc": "+35% dmg, +25% splash radius, +20% fire rate & shrapnel reveals Cloaked Stalkers.",
			"mods": {"dmg_mult": 1.35, "rate_mult": 1.20, "splash_mult": 1.25, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Sky-Shredder Flak Fortress",
			"cost": 3900,
			"build_time": 7.5,
			"desc": "APEX: +100% dmg, +50% speed, +40% splash, 3 bonus flak sub-bursts & 0.55s stun.",
			"mods": {"dmg_mult": 2.00, "rate_mult": 1.50, "splash_mult": 1.40, "bonus_mirv_subshells": 3, "stun_duration": 0.55, "reveals_cloaked": true},
		},
	},
	"blaster+laser": {
		"t4": {
			"name": "Phase-Adaptive Repeater",
			"cost": 1350,
			"build_time": 5.0,
			"desc": "+35% dmg, +22% speed, smart plasma bounces to 1 extra foe (60%) & detects Cloaked.",
			"mods": {"dmg_mult": 1.35, "rate_mult": 1.22, "ricochet_count": 1, "ricochet_ratio": 0.60, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Omni-Matrix Annihilator",
			"cost": 4300,
			"build_time": 7.5,
			"desc": "APEX: +105% dmg, +55% speed, 3 smart-matrix ricochets (75%) & ignores Conduit Shield Auras.",
			"mods": {"dmg_mult": 2.05, "rate_mult": 1.55, "ricochet_count": 3, "ricochet_ratio": 0.75, "reveals_cloaked": true, "strip_shield_aura": true},
		},
	},
	"blaster+slow": {
		"t4": {
			"name": "Cryo-Lock Interceptor",
			"cost": 1250,
			"build_time": 5.0,
			"desc": "+35% dmg, +20% wider Stasis Bubbles, +8% slow, strips Bio-Mender regen & reveals Cloaked.",
			"mods": {"dmg_mult": 1.35, "bubble_radius_mult": 1.20, "bubble_slow_add": 0.08, "decay_mult": 1.40, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Zero-Vector Lockdown",
			"cost": 3800,
			"build_time": 7.5,
			"desc": "APEX: +100% dmg, +45% fire rate, 2 kinetic ricochets + Vortex pull bubbles suppressing regen!",
			"mods": {"dmg_mult": 2.00, "rate_mult": 1.45, "ricochet_count": 2, "ricochet_ratio": 0.65, "bubble_radius_mult": 1.35, "bubble_slow_add": 0.14, "bubble_pull_px_per_sec": 7.5, "decay_mult": 2.10, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
	},
	"blaster+railgun": {
		"t4": {
			"name": "Overclocked Rail Carbine",
			"cost": 1850,
			"build_time": 5.5,
			"desc": "+35% fire rate, +30% dmg, pierces 2 targets & strips Shield Auras.",
			"mods": {"dmg_mult": 1.30, "rate_mult": 1.35, "bonus_pierce": 1, "decay_mult": 1.35, "strip_shield_aura": true},
		},
		"t5": {
			"name": "Chrono-Valkyrie Autocannon",
			"cost": 5800,
			"build_time": 8.0,
			"desc": "APEX: +85% fire rate, +95% dmg, pierces 4 targets, 2.0x Decay & +20% range!",
			"mods": {"dmg_mult": 1.95, "rate_mult": 1.85, "range_mult": 1.20, "bonus_pierce": 3, "decay_mult": 2.00, "strip_shield_aura": true},
		},
	},
	"blaster+annihilator": {
		"t4": {
			"name": "Depleted-Core Vulcan",
			"cost": 1700,
			"build_time": 5.5,
			"desc": "+40% dmg, +25% fire rate & every shot ricochets heavy sabot shrapnel to 1 foe (55%).",
			"mods": {"dmg_mult": 1.40, "rate_mult": 1.25, "ricochet_count": 1, "ricochet_ratio": 0.55},
		},
		"t5": {
			"name": "Titan-Reaper Autocannon",
			"cost": 5400,
			"build_time": 8.0,
			"desc": "APEX: +115% dmg, +55% fire rate, 2 heavy ricochets (70%), pierces Shield Auras & shreds armor!",
			"mods": {"dmg_mult": 2.15, "rate_mult": 1.55, "ricochet_count": 2, "ricochet_ratio": 0.70, "bonus_shred_stacks": 2, "strip_shield_aura": true},
		},
	},
	"mortar+laser": {
		"t4": {
			"name": "Supernova Shelling",
			"cost": 1400,
			"build_time": 5.0,
			"desc": "+40% plasma blast dmg, +22% radius, suppresses Bio-Mender regen & reveals Cloaked.",
			"mods": {"dmg_mult": 1.40, "splash_mult": 1.22, "reveals_cloaked": true, "bubble_anti_regen": true},
		},
		"t5": {
			"name": "Helios Orbital Barrage",
			"cost": 4300,
			"build_time": 7.5,
			"desc": "APEX: +110% dmg, +45% fire rate, +35% splash, 3 solar sub-shells & 160-dmg Slag Nova on kill!",
			"mods": {"dmg_mult": 2.10, "rate_mult": 1.45, "splash_mult": 1.35, "bonus_mirv_subshells": 3, "slag_nova_dmg": 160.0, "reveals_cloaked": true},
		},
	},
	"mortar+slow": {
		"t4": {
			"name": "Glacial Quake Shells",
			"cost": 1350,
			"build_time": 5.0,
			"desc": "+35% dmg, +25% larger Cryo Bubbles, 0.5s freeze-stun & strips Bio-Mender regen.",
			"mods": {"dmg_mult": 1.35, "bubble_radius_mult": 1.25, "bubble_duration_add": 1.2, "bubble_slow_add": 0.08, "stun_duration": 0.50, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Permafrost Cataclysm",
			"cost": 4200,
			"build_time": 7.5,
			"desc": "APEX: +105% dmg, +40% Bubble radius, 1.0s quake stun, backward Vortex pull & 2.2x Decay!",
			"mods": {"dmg_mult": 2.05, "rate_mult": 1.30, "bubble_radius_mult": 1.40, "bubble_duration_add": 2.5, "bubble_slow_add": 0.16, "bubble_pull_px_per_sec": 9.5, "decay_mult": 2.20, "stun_duration": 1.00, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
	},
	"mortar+railgun": {
		"t4": {
			"name": "Stratospheric Gravity Bomb",
			"cost": 1950,
			"build_time": 6.0,
			"desc": "+40% dmg, +25% splash, +40% Decay & 0.65s gravity shockwave stun.",
			"mods": {"dmg_mult": 1.40, "splash_mult": 1.25, "decay_mult": 1.40, "stun_duration": 0.65, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Orbital Singularity Strike",
			"cost": 6200,
			"build_time": 8.0,
			"desc": "APEX: +120% dmg, +40% speed, +40% splash, 4 MIRV grav-bombs, 1.1s stun & ignores Shield Auras!",
			"mods": {"dmg_mult": 2.20, "rate_mult": 1.40, "splash_mult": 1.40, "bonus_mirv_subshells": 4, "decay_mult": 2.10, "stun_duration": 1.10, "strip_shield_aura": true, "reveals_cloaked": true},
		},
	},
	"mortar+annihilator": {
		"t4": {
			"name": "Bunker-Buster Tandem Warhead",
			"cost": 1750,
			"build_time": 5.5,
			"desc": "+45% direct & splash dmg, +25% splash radius, 0.5s concussive stun & shreds armor.",
			"mods": {"dmg_mult": 1.45, "splash_mult": 1.25, "stun_duration": 0.50, "bonus_shred_stacks": 2, "strip_shield_aura": true},
		},
		"t5": {
			"name": "Siegebreaker Doomsday Cannon",
			"cost": 5600,
			"build_time": 8.0,
			"desc": "APEX: +125% dmg, +40% speed, +40% splash, 3 AP sub-shells, 0.9s stun & 220-dmg Slag Nova!",
			"mods": {"dmg_mult": 2.25, "rate_mult": 1.40, "splash_mult": 1.40, "bonus_mirv_subshells": 3, "stun_duration": 0.90, "bonus_shred_stacks": 3, "slag_nova_dmg": 220.0, "strip_shield_aura": true},
		},
	},
	"laser+slow": {
		"t4": {
			"name": "Ionized Inferno Dome",
			"cost": 1350,
			"build_time": 5.0,
			"desc": "2.2x Bubble thermal burn, +25% radius, strips Bio-Mender regen & reveals Cloaked.",
			"mods": {"dmg_mult": 1.35, "bubble_burn_mult": 2.20, "bubble_radius_mult": 1.25, "bubble_duration_add": 1.4, "decay_mult": 1.40, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Chromatic Nova Projector",
			"cost": 4100,
			"build_time": 7.5,
			"desc": "APEX: 4.0x Bubble burn, +40% radius, Vortex pull, 2x beam chain & 160-dmg Slag Nova on kill!",
			"mods": {"dmg_mult": 1.95, "rate_mult": 1.35, "bubble_burn_mult": 4.00, "bubble_radius_mult": 1.40, "bubble_duration_add": 2.4, "bubble_pull_px_per_sec": 7.0, "decay_mult": 2.20, "bonus_refract_targets": 2, "refract_radius_add": 80.0, "refract_ratio_add": 0.55, "slag_nova_dmg": 160.0, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
	},
	"laser+railgun": {
		"t4": {
			"name": "Focused Ion Rail-Lance",
			"cost": 1900,
			"build_time": 5.5,
			"desc": "Pierces 3 enemies along 325px lance, +40% dmg, +45% Decay & reveals Cloaked.",
			"mods": {"dmg_mult": 1.40, "range_mult": 1.12, "bonus_pierce": 2, "decay_mult": 1.45, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Starfire Chrono-Lance",
			"cost": 6000,
			"build_time": 8.0,
			"desc": "APEX: Pierces 5 enemies, +115% dmg, +50% speed, chains 2 prism arcs & ignores Shield Auras!",
			"mods": {"dmg_mult": 2.15, "rate_mult": 1.50, "range_mult": 1.22, "bonus_pierce": 4, "decay_mult": 2.15, "bonus_refract_targets": 2, "refract_radius_add": 85.0, "refract_ratio_add": 0.60, "strip_shield_aura": true, "reveals_cloaked": true},
		},
	},
	"laser+annihilator": {
		"t4": {
			"name": "Core-Meltdown Shredder",
			"cost": 1750,
			"build_time": 5.5,
			"desc": "Armor Shred caps at 5 stacks (+50% team dmg taken!), +35% dmg & suppresses Bio-Mender regen.",
			"mods": {"dmg_mult": 1.35, "rate_mult": 1.18, "bonus_shred_stacks": 2, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Slag-Nova Crucible",
			"cost": 5600,
			"build_time": 8.0,
			"desc": "APEX: 7 Shred stacks (+70% team dmg!), +105% dmg, +40% speed & shredded kills detonate 340-dmg Slag Nova!",
			"mods": {"dmg_mult": 2.05, "rate_mult": 1.40, "bonus_shred_stacks": 4, "slag_nova_dmg": 340.0, "strip_shield_aura": true, "reveals_cloaked": true},
		},
	},
	"slow+railgun": {
		"t4": {
			"name": "Deep-Freeze Chrono Sniper",
			"cost": 1950,
			"build_time": 6.0,
			"desc": "+40% dmg, +25% Absolute Bubble radius, +10% slow, pierces 2 foes & strips regen.",
			"mods": {"dmg_mult": 1.40, "bubble_radius_mult": 1.25, "bubble_duration_add": 1.6, "bubble_slow_add": 0.10, "decay_mult": 1.45, "bonus_pierce": 1, "bubble_anti_regen": true, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Zero-Kelvin Singularity Rail",
			"cost": 6300,
			"build_time": 8.0,
			"desc": "APEX: +115% dmg, +45% speed, pierces 3 foes, giant Vortex Pull Bubbles & 0.8s freeze-stun!",
			"mods": {"dmg_mult": 2.15, "rate_mult": 1.45, "bubble_radius_mult": 1.42, "bubble_duration_add": 2.8, "bubble_slow_add": 0.18, "bubble_pull_px_per_sec": 12.0, "decay_mult": 2.25, "bonus_pierce": 2, "stun_duration": 0.80, "bubble_anti_regen": true, "strip_shield_aura": true, "reveals_cloaked": true},
		},
	},
	"slow+annihilator": {
		"t4": {
			"name": "Graviton Anchor Breaker",
			"cost": 1700,
			"build_time": 5.5,
			"desc": "+40% boss dmg, +25% Lock Bubble radius, +10% slow, strips regen & bypasses Shield Auras.",
			"mods": {"dmg_mult": 1.40, "rate_mult": 1.18, "bubble_radius_mult": 1.25, "bubble_slow_add": 0.10, "decay_mult": 1.45, "bubble_anti_regen": true, "strip_shield_aura": true, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Chrono-Guillotine Rail",
			"cost": 5500,
			"build_time": 8.0,
			"desc": "APEX: +115% dmg, +45% speed, Vortex Pull Bubbles, 0.7s boss stun & executes foes <10% HP!",
			"mods": {"dmg_mult": 2.15, "rate_mult": 1.45, "bubble_radius_mult": 1.38, "bubble_duration_add": 2.0, "bubble_slow_add": 0.16, "bubble_pull_px_per_sec": 8.5, "decay_mult": 2.10, "stun_duration": 0.70, "execute_hp_pct": 0.10, "bubble_anti_regen": true, "strip_shield_aura": true, "reveals_cloaked": true},
		},
	},
	"railgun+annihilator": {
		"t4": {
			"name": "Event-Horizon Boss Lance",
			"cost": 2500,
			"build_time": 6.0,
			"desc": "Pierces 2 bosses, +45% dmg, +45% Decay & ignores Conduit Shield Auras.",
			"mods": {"dmg_mult": 1.45, "rate_mult": 1.20, "bonus_pierce": 1, "decay_mult": 1.45, "strip_shield_aura": true, "reveals_cloaked": true},
		},
		"t5": {
			"name": "Omega Singularity Sovereign",
			"cost": 8200,
			"build_time": 8.5,
			"desc": "APEX: Pierces 3 bosses, +135% dmg, +50% speed, 2.3x Decay & EXECUTES any target <12% HP!",
			"mods": {"dmg_mult": 2.35, "rate_mult": 1.50, "range_mult": 1.18, "bonus_pierce": 2, "decay_mult": 2.30, "execute_hp_pct": 0.12, "strip_shield_aura": true, "reveals_cloaked": true},
		},
	},
}

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
	"colossus": {
		"name": "Colossus",
		"spawn_cost_s": 95, # s$95 Wave 16+ Tier-2 Siege Boss (preserves Fixed Unit HP!)
		"bounty_b": 75,     # b$75
		"base_hp": 14000.0,
		"speed_mult": 1.05,
		"speed": BASE_UNIT_SPEED_PX * 1.05,
		"armour_label": "Armored + Reflective",
		"armour_tags": ["Armored", "Reflective"],
		"money_on_kill": 75,
		"research_on_kill": 8,
		"leak_cost": 8,
		"first_wave": 16,
	},
	# --- v2.0 BTD5-Inspired Mechanic Enemies (Waves 11+ ONLY; Waves 1-10 remain 100% locked!) ---
	"stalker": {
		"name": "Phase Stalker",
		"spawn_cost_s": 14, # s$14
		"bounty_b": 22,     # b$22
		"base_hp": 420.0,
		"speed_mult": 1.75,
		"speed": BASE_UNIT_SPEED_PX * 1.75,
		"armour_label": "Reflective + Cloaked",
		"armour_tags": ["Reflective"],
		"is_cloaked": true,
		"money_on_kill": 22,
		"research_on_kill": 2,
		"leak_cost": 2,
		"first_wave": 11,
	},
	"mender": {
		"name": "Bio-Mender",
		"spawn_cost_s": 16, # s$16
		"bounty_b": 26,     # b$26
		"base_hp": 1100.0,
		"speed_mult": 1.05,
		"speed": BASE_UNIT_SPEED_PX * 1.05,
		"armour_label": "Standard + Regen",
		"armour_tags": ["Standard"],
		"regen_pct_per_sec": 0.06, # Heals 6% max HP/sec unless suppressed by Decay/Burn/Shred
		"money_on_kill": 26,
		"research_on_kill": 2,
		"leak_cost": 2,
		"first_wave": 13,
	},
	"carrier": {
		"name": "Brood Carrier",
		"spawn_cost_s": 55, # s$55
		"bounty_b": 58,     # b$58
		"base_hp": 3400.0,
		"speed_mult": 0.88,
		"speed": BASE_UNIT_SPEED_PX * 0.88,
		"armour_label": "Armored + Splitter",
		"armour_tags": ["Armored"],
		"split_children": ["blitzer", "blitzer", "rusher", "rusher", "rusher", "rusher"],
		"money_on_kill": 58,
		"research_on_kill": 4,
		"leak_cost": 4,
		"first_wave": 15,
	},
	"conduit": {
		"name": "Aegis Conduit",
		"spawn_cost_s": 48, # s$48
		"bounty_b": 52,     # b$52
		"base_hp": 2600.0,
		"speed_mult": 1.00,
		"speed": BASE_UNIT_SPEED_PX * 1.00,
		"armour_label": "Reflective + Shield Aura",
		"armour_tags": ["Reflective"],
		"shield_aura_radius": 95.0,
		"shield_aura_reduction": 0.35, # Nearby allies take -35% dmg until Conduit is sniped!
		"money_on_kill": 52,
		"research_on_kill": 4,
		"leak_cost": 3,
		"first_wave": 22,
	},
}

const DIFFICULTY_ORDER: Array[String] = ["standard", "hard", "nightmare"]
const DIFFICULTY_PRESETS: Dictionary = {
	"standard": {
		"name": "Standard",
		"hp_mult": 1.0,
		"speed_mult": 1.0,
		"bounty_mult": 1.0,
		"desc": "Baseline Chrono Command tuning.",
	},
	"hard": {
		"name": "Hard",
		"hp_mult": 1.22,
		"speed_mult": 1.08,
		"bounty_mult": 0.92,
		"desc": "Aliens +22% HP, +8% speed, -8% kill bounty.",
	},
	"nightmare": {
		"name": "Chrono Nightmare",
		"hp_mult": 1.55,
		"speed_mult": 1.16,
		"bounty_mult": 0.84,
		"desc": "Aliens +55% HP, +16% speed, -16% kill bounty.",
	},
}

# --- Economies: Refineries ($ exponential ramp) & Rogue-like Meta-Research ---
## Cost = $200 * 1.8^(owned) -> $200, $360, $650, $1,165, $2,100
## Income = $0.25/sec per refinery (+$1 every 4.0s tick).
const REFINERY_RATE_PER_SEC: float = 0.25
const REFINERY_TICK_INTERVAL: float = 4.0
const REFINERY_INCOME_PER_TICK: int = 1 # $1 per 4.0s = $0.25/sec
const REFINERY_BASE_COST: float = 200.0
const REFINERY_COST_GROWTH: float = 1.80
const REFINERY_COST_ROUND_TO: int = 5
const REFINERY_BUILD_TIME: float = 8.0

## BTD5 Banana Farm / Bank Tech Ladder (Tier 1 default preserves exact W1-10 tests!)
const REFINERY_MAX_TIER: int = 4
const REFINERY_TIERS: Dictionary = {
	1: {
		"name": "Rift Extractor",
		"cost": 0,
		"build_time": 0.0,
		"income_per_tick": 1,   # $0.25/s per refinery (exact baseline)
		"rate_per_sec": 0.25,
		"clean_wave_bonus_pct": 0.0,
		"bank_interest_pct": 0.0,
		"bank_interest_cap": 0,
		"desc": "Base extraction: +$0.25/s per Refinery.",
	},
	2: {
		"name": "Chrono-Plant",
		"cost": 400,
		"build_time": 7.5,
		"income_per_tick": 3,   # $0.75/s per refinery (3x!)
		"rate_per_sec": 0.75,
		"clean_wave_bonus_pct": 0.10,
		"bank_interest_pct": 0.0,
		"bank_interest_cap": 0,
		"desc": "3x Refinery income ($0.75/s each) + 10% clean-wave bonus.",
	},
	3: {
		"name": "Temporal Bank",
		"cost": 1150,
		"build_time": 10.0,
		"income_per_tick": 6,   # $1.50/s per refinery (6x!)
		"rate_per_sec": 1.50,
		"clean_wave_bonus_pct": 0.12,
		"bank_interest_pct": 0.10,
		"bank_interest_cap": 650,
		"desc": "6x Refinery income ($1.50/s) + 10% wave-end Bank interest (max +$650/w).",
	},
	4: {
		"name": "Singularity Mint",
		"cost": 2900,
		"build_time": 13.0,
		"income_per_tick": 13,  # $3.25/s per refinery (13x!)
		"rate_per_sec": 3.25,
		"clean_wave_bonus_pct": 0.15,
		"bank_interest_pct": 0.15,
		"bank_interest_cap": 1800,
		"desc": "13x Refinery income ($3.25/s) + 15% Bank interest (max +$1,800/w) to fund Apex T5!",
	},
}

const WAVE_CLEAR_BONUS_BASE: int = 0 # W1-10 remain $0 to preserve locked W1-10 algorithm
const WAVE_CLEAR_BONUS_PER_WAVE: int = 0
const POST_W10_WAVE_STIPEND_BASE: int = 40 # First-clear stipend for Waves 11+: $40 + wave * $6
const POST_W10_WAVE_STIPEND_PER_WAVE: int = 6

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
		"name": "Citadel Core",
		"cost": 100,
		"rank_costs": RESEARCH_RANK_COSTS,
		"description": "+10% Chrono-Citadel weapon damage & Time Ability power per rank",
		"base_attack_bonus": 0.10,
	},
}

# --- v3.0 Paid, Upgradable Time Abilities (T1..T5 — Zero Surge, Zero Permanent Mutations!) ---
const TIME_ABILITY_MAX_TIER: int = 5
const TIME_ABILITIES: Dictionary = {
	"pause": {
		"name": "Time Freeze",
		"cast_cost": 75,
		"cooldown": 45.0,
		"short_effect": "Freeze all aliens; turrets keep firing",
		"tiers": {
			1: {"upgrade_cost": 0, "title": "Stasis Lock", "duration": 6.0, "brittle_pct": 0.0, "cd_mult": 1.0, "reveals_cloaked": false, "shatter_pct": 0.0, "desc": "Freeze all aliens 6s while turrets fire."},
			2: {"upgrade_cost": 220, "title": "Cryo Optics", "duration": 7.5, "brittle_pct": 0.0, "cd_mult": 1.0, "reveals_cloaked": true, "shatter_pct": 0.0, "desc": "7.5s freeze + exposes ALL Cloaked aliens!"},
			3: {"upgrade_cost": 480, "title": "Brittle Lattice", "duration": 8.0, "brittle_pct": 0.20, "cd_mult": 1.0, "reveals_cloaked": true, "shatter_pct": 0.0, "desc": "8s freeze + frozen aliens take +20% damage!"},
			4: {"upgrade_cost": 950, "title": "Zero-Kelvin Field", "duration": 9.5, "brittle_pct": 0.30, "cd_mult": 0.85, "reveals_cloaked": true, "shatter_pct": 0.0, "desc": "9.5s freeze, +30% brittle dmg, -15% cooldown."},
			5: {"upgrade_cost": 2200, "title": "Absolute Zero", "duration": 12.0, "brittle_pct": 0.40, "cd_mult": 0.80, "reveals_cloaked": true, "shatter_pct": 0.15, "desc": "12s freeze, +40% dmg, shatters non-bosses <15% HP!"},
		},
	},
	"haste": {
		"name": "Overclock",
		"cast_cost": 60,
		"cooldown": 40.0,
		"short_effect": "Supercharge all tower fire & build speed",
		"tiers": {
			1: {"upgrade_cost": 0, "title": "Turbo Feed", "duration": 16.0, "speed_bonus": 0.50, "build_mult": 1.50, "crit_bonus": 0.0, "cd_mult": 1.0, "instant_builds": false, "desc": "+50% tower fire & build speed for 16s."},
			2: {"upgrade_cost": 200, "title": "Twin Capacitors", "duration": 18.0, "speed_bonus": 0.65, "build_mult": 1.75, "crit_bonus": 0.0, "cd_mult": 1.0, "instant_builds": false, "desc": "+65% fire speed & +75% build speed for 18s."},
			3: {"upgrade_cost": 450, "title": "Overcharged Slugs", "duration": 20.0, "speed_bonus": 0.80, "build_mult": 2.00, "crit_bonus": 0.15, "cd_mult": 1.0, "instant_builds": false, "desc": "+80% fire speed & +15% bonus damage for 20s."},
			4: {"upgrade_cost": 900, "title": "Chrono-Dynamo", "duration": 22.0, "speed_bonus": 1.00, "build_mult": 2.25, "crit_bonus": 0.20, "cd_mult": 0.85, "instant_builds": false, "desc": "+100% fire speed, +20% dmg, -15% cooldown."},
			5: {"upgrade_cost": 2000, "title": "Hyper-Dilation", "duration": 26.0, "speed_bonus": 1.25, "build_mult": 3.00, "crit_bonus": 0.30, "cd_mult": 0.80, "instant_builds": true, "desc": "+125% speed, +30% dmg & instantly finishes active builds!"},
		},
	},
	"rewind": {
		"name": "Temporal Rewind",
		"cast_cost": 100,
		"cooldown": 55.0,
		"short_effect": "Yank ALL aliens backward along path!",
		"tiers": {
			1: {"upgrade_cost": 0, "title": "Slipstream Yank", "pushback_pct": 0.18, "paradox_dmg_pct": 0.0, "strip_buffs": false, "stun_sec": 0.0, "cd_mult": 1.0, "desc": "Yanks all active aliens 18% backward along the track!"},
			2: {"upgrade_cost": 260, "title": "Disruption Pull", "pushback_pct": 0.24, "paradox_dmg_pct": 0.0, "strip_buffs": true, "stun_sec": 0.0, "cd_mult": 1.0, "desc": "24% path pushback + strips Bio-Mender regen & shields!"},
			3: {"upgrade_cost": 550, "title": "Paradox Whiplash", "pushback_pct": 0.30, "paradox_dmg_pct": 0.12, "strip_buffs": true, "stun_sec": 0.0, "cd_mult": 1.0, "desc": "30% pushback + deals 12% current HP Paradox damage!"},
			4: {"upgrade_cost": 1100, "title": "Temporal Snap", "pushback_pct": 0.38, "paradox_dmg_pct": 0.15, "strip_buffs": true, "stun_sec": 2.0, "cd_mult": 0.88, "desc": "38% pushback, 15% HP dmg + 2s landing stun!"},
			5: {"upgrade_cost": 2600, "title": "Chrono-Snapback", "pushback_pct": 0.48, "paradox_dmg_pct": 0.22, "strip_buffs": true, "stun_sec": 3.0, "cd_mult": 0.80, "desc": "48% pushback, 22% HP dmg + 3s stun & buff strip!"},
		},
	},
}

# Legacy alias retained for backward-safe reads in older tooling/tests
const TIME_POWERS: Dictionary = {
	"rewind": {
		"name": "Temporal Rewind",
		"short_effect": "Yank aliens backward",
		"cost_label": "Cast: $100",
		"cooldown": 55.0,
		"post_wave_window": 9999.0,
		"mutation": "armoured",
		"mutation_label": "Armoured",
		"hp_bonus_per_stack": 0.0,
	},
	"pause": {
		"name": "Time Freeze",
		"short_effect": "Freeze aliens; towers fire",
		"cost_label": "Cast: $75",
		"duration": 6.0,
		"cooldown": 45.0,
		"mutation": "thaw_hardened",
		"mutation_label": "Thaw-hardened",
		"eff_hp_bonus_per_stack": 0.0,
		"frozen_damage_reduction_per_stack": 0.0,
		"frozen_damage_reduction_cap": 0.0,
	},
	"haste": {
		"name": "Overclock",
		"short_effect": "Towers +50% fire & build",
		"cost_label": "Cast: $60",
		"duration": 16.0,
		"cooldown": 40.0,
		"tower_attack_speed_bonus": 0.50,
		"construction_speed_multiplier": 1.50,
		"mutation": "swift",
		"mutation_label": "Swift",
		"speed_bonus_per_stack": 0.0,
	},
}

# --- v3.0 3-Stage Chrono-Citadel Ascension ("Sun God" Base Super-Weapon) ---
const CITADEL_MAX_STAGE: int = 3
const CITADEL_SACRIFICE_THRESHOLD: int = 1200 # $1,200+ tower value sacrificed in a category unlocks its super-weapon!
const CITADEL_STAGES: Dictionary = {
	1: {
		"name": "Fortified Citadel",
		"cost": 1500,
		"heal_lives": 3,
		"global_speed_bonus": 0.0,
		"supports_sacrifice": false,
		"desc": "Deploys twin Point-Defense Pulse Cannons (240px) + restores +3 Lives!",
	},
	2: {
		"name": "Chrono-Dreadnought",
		"cost": 6500,
		"heal_lives": 5,
		"global_speed_bonus": 0.15,
		"supports_sacrifice": true,
		"desc": "Global Orbital Chrono-Lance, +15% global tower speed, +5 Lives + absorbs optional Tower Sacrifices!",
	},
	3: {
		"name": "★ True Chrono-Singularity",
		"cost": 18000,
		"heal_lives": 20,
		"global_speed_bonus": 0.30,
		"supports_sacrifice": true,
		"desc": "2.2x Citadel power, +30% global tower speed, full heal, Hyper-Apex sacrifice weapons & 10s Singularity Pulse (<15% Boss Execute)!",
	},
}

const CITADEL_SACRIFICES: Dictionary = {
	"kinetic": {
		"name": "Quad Sabot Autocannons",
		"source_hint": "Blaster / Annihilator ($1,200+)",
		"desc": "Global anti-boss sabot barrage (180% vs Boss, shreds armor, ignores Shield Auras).",
	},
	"explosive": {
		"name": "Orbital Cluster Barrage",
		"source_hint": "Mortar ($1,200+)",
		"desc": "Map-wide 3-shell heavy AoE bombardment every 2.8s.",
	},
	"energy": {
		"name": "Triple Prismatic Sunbeams",
		"source_hint": "Laser ($1,200+)",
		"desc": "Chaining sunbeams hitting 3 foes + GLOBAL Camo Reveal across entire map!",
	},
	"chrono": {
		"name": "Global Time-Dilation Field",
		"source_hint": "Chrono Slow / Railgun ($1,200+)",
		"desc": "All enemies on map slowed -20% + constant flat Time Decay!",
	},
	"economy": {
		"name": "Chrono-Mint Core",
		"source_hint": "Sacrifice 1 Refinery (or own T3+ Bank)",
		"desc": "Generates +$350/wave (+$700 at Stage 3) bonus cash on every wave clear!",
	},
}

# Surge disabled in v3.0 (constants retained cleanly for zero-break compatibility)
const SURGE_ENABLED: bool = false
const SURGE_WAVE_SPAN: int = 5
const SURGE_BASE_WINDOW: float = 950.0
const SURGE_WARNING_AMBER: float = 15.0
const SURGE_WARNING_RED: float = 7.0
const SURGE_ATTACK_SPEED_FACTOR: float = 1.0

# --- Manipulator Upgrades (legacy constants retained for compatibility) ---
const MANIPULATOR_MAX_LEVEL: int = 5
const MANIPULATOR_UPGRADES: Dictionary = {
	2: {"cost": 150, "build_time": 10.0, "benefit_text": "All power cooldowns -15%", "cooldown_multiplier": 0.85},
	3: {"cost": 250, "build_time": 15.0, "benefit_text": "Extended ability durations", "pause_duration": 10.0, "haste_duration": 36.0},
	4: {"cost": 400, "build_time": 20.0, "benefit_text": "Enhanced Chrono Core", "surge_window": 1140.0, "surge_wave_span": 6},
	5: {"cost": 600, "build_time": 25.0, "benefit_text": "Citadel Overdrive", "base_attack_charge_multiplier": 0.80},
}

# --- Enemy Rift & Mission Levels (Wave 40 Milestone -> Endless Freeplay!) ---
const ENEMY_BASE_MAX_HP: int = 500
const MAX_MISSION_LEVELS: int = 5
const BASE_ATTACK_DEFAULT_LEVEL: int = 3
const BASE_ATTACK_TEST_DAMAGE_OVERRIDE: int = 167
const BASE_ATTACK_COST: int = 450
const BASE_ATTACK_CHARGE_TIME: float = 30.0
const BASE_ATTACK_FIRE_WARNING_TIME: float = 1.0

const LEVELS: Dictionary = {
	1: {
		"name": "Level 1: Chrono Rows",
		"short_name": "Lv1: Chrono Rows",
		"zone_type": "4 Horizontal Row Zones",
		"shots_required": 3,
		"modifier_label": "Standard Sector Rules",
		"enemy_hp_bonus": 0.0,
		"tower_range_bonus": 0.0,
		"blitzer_speed_bonus": 0.0,
		"bounty_bonus": 0.0,
		"starting_money_bonus": 0,
		"description": "Classic S-trench battlefield across 4 horizontal row zones. Clear Wave 40 for the Sector Medal, then awaken your Chrono-Citadel and push Endless Freeplay!",
	},
	2: {
		"name": "Level 2: Vertical Corridors",
		"short_name": "Lv2: Vertical Corridors",
		"zone_type": "3 Vertical Column Zones",
		"shots_required": 3,
		"modifier_label": "Sector Mod: Blitzers +12% faster",
		"enemy_hp_bonus": 0.0,
		"tower_range_bonus": 0.0,
		"blitzer_speed_bonus": 0.12,
		"bounty_bonus": 0.0,
		"starting_money_bonus": 0,
		"description": "Vertical canyon switchbacks with 3 tall corridor columns. Blitzers surge +12% faster. Clear Wave 40 for your Medal, then test your build in Endless!",
	},
	3: {
		"name": "Level 3: Twin Citadel Islands",
		"short_name": "Lv3: Citadel Islands",
		"zone_type": "4 Central Island Zones",
		"shots_required": 4,
		"modifier_label": "Sector Mod: All towers +8% range",
		"enemy_hp_bonus": 0.0,
		"tower_range_bonus": 0.08,
		"blitzer_speed_bonus": 0.0,
		"bounty_bonus": 0.0,
		"starting_money_bonus": 0,
		"description": "Wide perimeter loops around 4 elevated central island plazas (all towers +8% range). Clear Wave 40, then push Endless Freeplay!",
	},
	4: {
		"name": "Level 4: Spiral Labyrinth",
		"short_name": "Lv4: Spiral Labyrinth",
		"zone_type": "4 Spiral Core & Bastion Pockets",
		"shots_required": 4,
		"modifier_label": "Sector Mod: +$40 start | Aliens +8% HP",
		"enemy_hp_bonus": 0.08,
		"tower_range_bonus": 0.0,
		"blitzer_speed_bonus": 0.0,
		"bounty_bonus": 0.0,
		"starting_money_bonus": 40,
		"description": "Aliens spiral clockwise into your central Citadel (+$40 start, aliens +8% HP). Clear Wave 40 and ascend your Citadel to hold Endless!",
	},
	5: {
		"name": "Level 5: Omega Gauntlet",
		"short_name": "Lv5: Omega Gauntlet",
		"zone_type": "5 Switchback Kill-Box Pillboxes",
		"shots_required": 5,
		"modifier_label": "Sector Mod: Aliens +15% HP | +10% Bounty",
		"enemy_hp_bonus": 0.15,
		"tower_range_bonus": 0.0,
		"blitzer_speed_bonus": 0.0,
		"bounty_bonus": 0.10,
		"starting_money_bonus": 0,
		"description": "High-threat 5-turn switchback gauntlet (aliens +15% HP, +10% kill bounty). Clear Wave 40 and unleash True Chrono-Singularity in Endless!",
	},
}


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


static func get_tower_upgrade_cost(stat_key: String, current_level: int, tower_type: String = "") -> int:
	var idx: int = clampi(current_level, 0, TOWER_UPGRADE_MAX_LEVEL - 1)
	if tower_type == "" or not TOWERS.has(tower_type):
		if stat_key == "range":
			return TOWER_RANGE_UPGRADE_COSTS[idx]
		return TOWER_UPGRADE_COSTS[idx]
	var base_cost: float = float(TOWERS[tower_type]["cost"])
	if stat_key == "range":
		var extra: float = maxf(0.0, base_cost - 110.0) * TOWER_RANGE_EXTRA_RATIOS[idx]
		return int(round((float(TOWER_RANGE_UPGRADE_COSTS[idx]) + extra) / 5.0)) * 5
	var scaled: float = float(TOWER_UPGRADE_BASE_COSTS[idx]) + base_cost * TOWER_UPGRADE_COST_RATIOS[idx]
	return int(round(scaled / 5.0)) * 5


static func get_upgrade_investment_value(tower_type: String, lvls: Dictionary) -> int:
	var total: int = 0
	for k in ["damage", "range", "fire_rate"]:
		var lv: int = clampi(int(lvls.get(k, 0)), 0, TOWER_UPGRADE_MAX_LEVEL)
		for i in range(lv):
			total += get_tower_upgrade_cost(k, i, tower_type)
	return total


const MERGE_UPGRADE_SYNC_RATIO: float = 0.35

static func get_merge_upgrade_transfer_fee(
	type_a: String,
	levels_a: Dictionary,
	type_b: String,
	levels_b: Dictionary,
	combo_type: String
) -> int:
	var merged := {
		"damage": maxi(int(levels_a.get("damage", 0)), int(levels_b.get("damage", 0))),
		"range": maxi(int(levels_a.get("range", 0)), int(levels_b.get("range", 0))),
		"fire_rate": maxi(int(levels_a.get("fire_rate", 0)), int(levels_b.get("fire_rate", 0))),
	}
	var target_val: int = get_upgrade_investment_value(combo_type, merged)
	var paid_val: int = get_upgrade_investment_value(type_a, levels_a) + get_upgrade_investment_value(type_b, levels_b)
	var diff: float = maxf(0.0, float(target_val - paid_val)) * MERGE_UPGRADE_SYNC_RATIO
	return maxi(0, int(round(diff / 5.0)) * 5)


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


static func is_combo_tower(tower_type: String) -> bool:
	return TOWERS.has(tower_type) and bool(TOWERS[tower_type].get("is_combo", false))


static func get_combo_key(type_a: String, type_b: String) -> String:
	var ia: int = BASE_TOWER_KEYS.find(type_a)
	var ib: int = BASE_TOWER_KEYS.find(type_b)
	if ia < 0 or ib < 0:
		return ""
	var k: String = "%s+%s" % [type_a, type_b] if ia <= ib else "%s+%s" % [type_b, type_a]
	return k if TOWERS.has(k) else ""


static func get_merge_surcharge(type_a: String, type_b: String) -> int:
	var ck: String = get_combo_key(type_a, type_b)
	if ck != "" and TOWERS[ck].has("merge_fee"):
		return int(TOWERS[ck]["merge_fee"])
	var raw: float = float(int(TOWERS[type_a]["cost"]) + int(TOWERS[type_b]["cost"])) * MERGE_SURCHARGE_RATIO
	return int(round(raw / 5.0)) * 5


static func get_merge_build_time(type_a: String, type_b: String) -> float:
	var ck: String = get_combo_key(type_a, type_b)
	if ck != "":
		return float(TOWERS[ck]["build_time"])
	return roundf((float(TOWERS[type_a]["build_time"]) + float(TOWERS[type_b]["build_time"])) * MERGE_BUILD_TIME_RATIO * 2.0) * 0.5


static func get_combo_evolution_cfg(combo_type: String, target_apex_tier: int) -> Dictionary:
	if not COMBO_EVOLUTIONS.has(combo_type):
		return {}
	var key: String = "t4" if target_apex_tier == 1 else ("t5" if target_apex_tier == 2 else "")
	if key == "":
		return {}
	return COMBO_EVOLUTIONS[combo_type].get(key, {})


static func get_refinery_tier_cfg(tier: int) -> Dictionary:
	return REFINERY_TIERS.get(clampi(tier, 1, REFINERY_MAX_TIER), REFINERY_TIERS[1])


static func get_time_ability_tier_cfg(ability_key: String, tier: int) -> Dictionary:
	var ab: Dictionary = TIME_ABILITIES.get(ability_key, {})
	if ab.is_empty():
		return {}
	var tiers: Dictionary = ab.get("tiers", {})
	var t: int = clampi(tier, 1, TIME_ABILITY_MAX_TIER)
	return tiers.get(t, {})


static func get_tower_sacrifice_categories(tower_type: String) -> Array[String]:
	var cats: Array[String] = []
	var parts: PackedStringArray = tower_type.split("+")
	for p in parts:
		var c: String = ""
		if p == "blaster" or p == "annihilator":
			c = "kinetic"
		elif p == "mortar":
			c = "explosive"
		elif p == "laser":
			c = "energy"
		elif p == "slow" or p == "railgun":
			c = "chrono"
		if c != "" and not cats.has(c):
			cats.append(c)
	return cats
