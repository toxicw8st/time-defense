class_name Balance
extends RefCounted

## All balance numbers using exact notation:
## s$ = spawn cost (threat cost to spawn an enemy unit)
## b$ = bounty (player $ earned for killing an enemy unit)
## $  = player money (starting $, tower $, refinery $, base-attack $)
## s$ and b$ are strictly separate numbers.

# --- Viewport & Map ---
const BALANCE_VERSION: String = "v1.3-guide-mobile-ui-ux"
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
const MERGE_SURCHARGE_RATIO: float = 0.30
const MERGE_BUILD_TIME_RATIO: float = 0.65

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
		"merge_fee": 65,
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
		"merge_fee": 65,
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
		"merge_fee": 65,
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
		"merge_fee": 60,
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
		"merge_fee": 235,
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
		"merge_fee": 160,
		"role": "Boss assassin: 115 Piercing (207 vs Jugg) +20% opener strike vs unseen targets",
		"cost": 640,
		"build_time": 8.5,
		"damage": 115.0,
		"fire_rate": 0.78,
		"range": 190.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"damage_type_label": "Piercing MAC (180% vs Juggernaut)",
		"damage_rating": "Devastating Boss",
		"speed_rating": "Medium",
		"targeting": "strongest",
		"opener_bonus_pct": 0.20,
	},
	# 7. blaster + mortar
	"blaster+mortar": {
		"name": "Flak Barrage Battery",
		"is_combo": true,
		"recipe": ["blaster", "mortar"],
		"merge_fee": 60,
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
		"merge_fee": 65,
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
		"merge_fee": 55,
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
		"merge_fee": 140,
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
		"merge_fee": 100,
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
		"merge_fee": 65,
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
		"merge_fee": 65,
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
		"merge_fee": 145,
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
		"merge_fee": 105,
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
		"merge_fee": 60,
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
		"merge_fee": 145,
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
		"merge_fee": 100,
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
		"merge_fee": 145,
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
		"merge_fee": 100,
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
		"merge_fee": 205,
		"role": "275px apex boss killer: 110 Piercing + 42 Time impact + 50% slow 4s + Decay",
		"cost": 820,
		"build_time": 9.5,
		"damage": 110.0,
		"fire_rate": 0.38,
		"range": 275.0,
		"min_range": 0.0,
		"splash_radius": 0.0,
		"splash_edge_ratio": 1.0,
		"damage_type": "Piercing",
		"secondary_damage": 42.0,
		"secondary_damage_type": "Time",
		"damage_type_label": "Piercing + Time Omega Rail",
		"damage_rating": "Apex Boss Killer",
		"speed_rating": "Slow (0.38/s)",
		"targeting": "strongest",
		"slow_pct": 0.50,
		"slow_duration": 4.0,
		"decay_ticks": 3,
		"decay_flat_by_level": [22.0, 44.0, 72.0, 108.0, 150.0, 200.0],
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
		"hp_mult": 1.25,
		"speed_mult": 1.08,
		"bounty_mult": 0.95,
		"desc": "Aliens +25% HP, +8% speed, -5% kill bounty.",
	},
	"nightmare": {
		"name": "Chrono Nightmare",
		"hp_mult": 1.55,
		"speed_mult": 1.15,
		"bounty_mult": 0.90,
		"desc": "Aliens +55% HP, +15% speed, -10% kill bounty.",
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

# --- Enemy Base & Hive Destroyer ($450 charge cost, 1/N rule across 5 Levels) ---
const ENEMY_BASE_MAX_HP: int = 500
const MAX_MISSION_LEVELS: int = 5
const BASE_ATTACK_DEFAULT_LEVEL: int = 3 # Default 3 shots (167 dmg/shot) for baseline test suite; Levels 1..5 use 1/N rule
const BASE_ATTACK_TEST_DAMAGE_OVERRIDE: int = 167
const BASE_ATTACK_COST: int = 450 # $450 per shot (requires multiple waves of savings / Rewind farming)
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
		"description": "Classic S-trench battlefield. Drag & drop towers anywhere along the 4 horizontal row zones (ROW 1-4). 3 Hive Destroyer shots (167 dmg/shot) destroy the Alien Base.",
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
		"description": "Vertical canyon switchbacks. Drag & drop towers inside the 3 tall vertical corridor columns (COL 1-3). Blitzers surge +12% faster. 3 Hive Destroyer shots required.",
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
		"description": "Wide perimeter loops around 4 elevated central island plazas (all towers +8% range). 4 Hive Destroyer shots (125 dmg/shot) required.",
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
		"description": "Aliens spiral clockwise into the central Citadel (+$40 start, aliens +8% HP). Drop towers inside 4 inner bastion pockets. 4 Hive Destroyer shots required.",
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
		"description": "High-threat 5-turn switchback gauntlet (aliens +15% HP, +10% kill bounty). Drop towers into the 5 hairpin pillboxes. 5 Hive Destroyer shots required.",
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
	return maxi(0, int(round(float(target_val - paid_val) / 5.0)) * 5)


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
