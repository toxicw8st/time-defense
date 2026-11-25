class_name WavesData
extends RefCounted

## Exact Waves 1-10 compositions + Algorithmic Wave Generator (Waves 11..200).
## Uses mandatory notation:
## s$ = spawn cost (threat cost to spawn an enemy unit)
## b$ = bounty (player $ earned for killing an enemy unit)
## $  = player money (starting $, tower $, refinery $, base-attack $)
## s$ and b$ are strictly separate numbers.

const MISSION_TARGET_WAVE: int = 45

## Exact Locked Compositions for Waves 1-10 from user specification:
## 1: 20 Crawlers — s$20, b$80, HP 1,000, DPS needed 27, ratio 1.02
## 2: 20 Crawlers, 5 Rushers — s$30, b$110, HP 1,250, DPS needed 37, ratio 1.09
## 3: 20 Rushers — s$40, b$120, HP 1,000, DPS needed 46, ratio 1.28
## 4: 25 Crawlers, 15 Rushers — s$55, b$190, HP 2,000, DPS needed 60, ratio 1.35
## 5: 25 Crawlers, 15 Rushers, 3 Brutes — s$79, b$250, HP 3,800, DPS needed 104, ratio 1.07
## 6: 40 Rushers, 2 Brutes — s$96, b$280, HP 3,680 (w/ x1.15), DPS needed 138, ratio 1.32
## 7: 40 Crawlers, 10 Rushers, 4 Brutes — s$92, b$300, HP 5,635 (w/ x1.15), DPS needed 121, ratio 1.91*
## 8: 30 Crawlers, 20 Rushers, 3 Brutes, 2 Blitzers — s$146, b$360, HP 5,520 (w/ x1.15), DPS needed 137, ratio 2.06*
## 9: 50 Crawlers, 25 Rushers, 4 Brutes, 3 Blitzers — s$210, b$520, HP 7,935 (w/ x1.15), DPS needed 179, ratio 1.88*
## 10: 4 Juggernauts, 10 Crawlers, 10 Rushers — s$190, b$300, HP 24,150 (w/ x1.15), DPS needed 544, ratio 0.78 (no farm) / ~0.95-1.0 (farm+Pause)
const WAVES: Array[Dictionary] = [
	{
		"wave": 1,
		"note": "20 Crawlers (s$20, b$80, DPS needed 27)",
		"target_s_dollars": 20,
		"tracks": [
			{"type": "crawler", "count": 20, "interval": 1.25, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 2,
		"note": "20 Crawlers, 5 Rushers (s$30, b$110, DPS needed 37)",
		"target_s_dollars": 30,
		"tracks": [
			{"type": "crawler", "count": 20, "interval": 1.35, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "rusher", "count": 5, "interval": 4.50, "group_size": 0, "group_delay": 0.0, "start_delay": 2.0},
		],
	},
	{
		"wave": 3,
		"note": "20 Rushers (s$40, b$120, DPS needed 46)",
		"target_s_dollars": 40,
		"tracks": [
			{"type": "rusher", "count": 20, "interval": 0.70, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 4,
		"note": "25 Crawlers, 15 Rushers (s$55, b$190, DPS needed 60)",
		"target_s_dollars": 55,
		"tracks": [
			{"type": "crawler", "count": 25, "interval": 0.85, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "rusher", "count": 15, "interval": 1.20, "group_size": 0, "group_delay": 0.0, "start_delay": 1.0},
		],
	},
	{
		"wave": 5,
		"note": "25 Crawlers, 15 Rushers, 3 Brutes (s$79, b$250, DPS needed 104)",
		"target_s_dollars": 79,
		"tracks": [
			{"type": "crawler", "count": 25, "interval": 0.85, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "rusher", "count": 15, "interval": 1.20, "group_size": 0, "group_delay": 0.0, "start_delay": 1.0},
			{"type": "brute", "count": 3, "interval": 6.00, "group_size": 0, "group_delay": 0.0, "start_delay": 2.0},
		],
	},
	{
		"wave": 6,
		"note": "40 Rushers, 2 Brutes (s$96, b$280, DPS needed 138)",
		"target_s_dollars": 96,
		"tracks": [
			{"type": "rusher", "count": 40, "interval": 0.50, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "brute", "count": 2, "interval": 8.00, "group_size": 0, "group_delay": 0.0, "start_delay": 2.0},
		],
	},
	{
		"wave": 7,
		"note": "40 Crawlers, 10 Rushers, 4 Brutes (s$92, b$300, DPS needed 121)",
		"target_s_dollars": 92,
		"tracks": [
			{"type": "crawler", "count": 40, "interval": 0.65, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "rusher", "count": 10, "interval": 1.80, "group_size": 0, "group_delay": 0.0, "start_delay": 1.2},
			{"type": "brute", "count": 4, "interval": 6.00, "group_size": 0, "group_delay": 0.0, "start_delay": 1.5},
		],
	},
	{
		"wave": 8,
		"note": "30 Crawlers, 20 Rushers, 3 Brutes, 2 Blitzers (s$146, b$360, DPS needed 137)",
		"target_s_dollars": 146,
		"tracks": [
			{"type": "crawler", "count": 30, "interval": 0.80, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "rusher", "count": 20, "interval": 1.00, "group_size": 0, "group_delay": 0.0, "start_delay": 0.8},
			{"type": "brute", "count": 3, "interval": 7.00, "group_size": 0, "group_delay": 0.0, "start_delay": 1.0},
			{"type": "blitzer", "count": 2, "interval": 9.00, "group_size": 0, "group_delay": 0.0, "start_delay": 3.0},
		],
	},
	{
		"wave": 9,
		"note": "50 Crawlers, 25 Rushers, 4 Brutes, 3 Blitzers (s$210, b$520, DPS needed 179)",
		"target_s_dollars": 210,
		"tracks": [
			{"type": "crawler", "count": 50, "interval": 0.55, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "rusher", "count": 25, "interval": 0.90, "group_size": 0, "group_delay": 0.0, "start_delay": 0.8},
			{"type": "brute", "count": 4, "interval": 6.50, "group_size": 0, "group_delay": 0.0, "start_delay": 1.0},
			{"type": "blitzer", "count": 3, "interval": 8.00, "group_size": 0, "group_delay": 0.0, "start_delay": 2.5},
		],
	},
	{
		"wave": 10,
		"note": "BOSS WAVE: 4 Juggernauts, 10 Crawlers, 10 Rushers (s$190, b$300, DPS needed 544)",
		"target_s_dollars": 190,
		"tracks": [
			{"type": "juggernaut", "count": 4, "interval": 12.0, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "crawler", "count": 10, "interval": 2.80, "group_size": 0, "group_delay": 0.0, "start_delay": 1.5},
			{"type": "rusher", "count": 10, "interval": 2.80, "group_size": 0, "group_delay": 0.0, "start_delay": 2.5},
		],
	},
]


static func get_wave_count() -> int:
	return MISSION_TARGET_WAVE


## Threat budget s$ growth: ~7% per wave from s$20 start -> Wave 45 = s$393, Wave 100 = s$16,199, Wave 200 = s$14.1M.
static func get_target_threat_s_dollars(wave_number: int, player_assets_spent: int = -1) -> int:
	if wave_number >= 1 and wave_number <= WAVES.size():
		return int(WAVES[wave_number - 1]["target_s_dollars"])
	var base_s: float = Balance.THREAT_START_S_DOLLARS * pow(Balance.THREAT_GROWTH_RATE, float(maxi(0, wave_number - 1)))
	if player_assets_spent > 0:
		# Track player asset value around the 7%/wave baseline curve
		var expected_assets: float = 220.0 * pow(Balance.THREAT_GROWTH_RATE, float(maxi(0, wave_number - 1)))
		var asset_factor: float = clampf(float(player_assets_spent) / maxf(1.0, expected_assets), 0.85, 1.30)
		base_s *= asset_factor
	return maxi(20, int(round(base_s)))


## Generates deterministic wave definitions for Waves 11..200 using s$ threat budget.
## Juggernaut (s$40) joins the regular wave pool after Wave 10.
static func get_wave_def(wave_number: int, player_assets_spent: int = -1) -> Dictionary:
	if wave_number >= 1 and wave_number <= WAVES.size():
		return WAVES[wave_number - 1]

	var w: int = maxi(1, wave_number)
	var raw_budget_s: int = get_target_threat_s_dollars(w, player_assets_spent)
	# Smooth post-Wave 10 escalation (255 * 1.095^(w-11)) so Waves 11-45 never collapse into an idle curve
	var smooth_post10_s: int = int(round(255.0 * pow(1.095, float(maxi(0, w - 11)))))
	var budget_s: int = maxi(raw_budget_s, smooth_post10_s)
	var remaining_s: int = budget_s
	var is_boss_wave: bool = (w % 10 == 0)

	var colossus_count: int = 0
	var jugg_count: int = 0
	var blitzer_count: int = 0
	var brute_count: int = 0
	var rusher_count: int = 0
	var crawler_count: int = 0

	if w >= 16:
		var col_share: float = 0.45 if is_boss_wave else 0.25
		colossus_count = int(floor(float(remaining_s) * col_share / 95.0))
		remaining_s -= colossus_count * 95

	if is_boss_wave:
		# Boss waves (20, 30, 40...): heavy Juggernaut + Colossus assault
		jugg_count = maxi(4, int(floor(float(remaining_s) * 0.55 / 40.0)))
		remaining_s = maxi(0, remaining_s - jugg_count * 40)
		blitzer_count = int(floor(float(remaining_s) * 0.35 / 26.0))
		remaining_s -= blitzer_count * 26
		brute_count = int(floor(float(remaining_s) * 0.45 / 8.0))
		remaining_s -= brute_count * 8
		rusher_count = int(floor(float(remaining_s) * 0.60 / 2.0))
		remaining_s -= rusher_count * 2
		crawler_count = maxi(0, remaining_s)
	else:
		# Regular waves 11+: at least 2 Juggernauts (grows smoothly with s$), Blitzers, Brutes, Rushers, Crawlers
		jugg_count = maxi(2, int(floor(float(remaining_s) * 0.40 / 40.0)))
		remaining_s = maxi(0, remaining_s - jugg_count * 40)
		blitzer_count = int(floor(float(remaining_s) * 0.35 / 26.0))
		remaining_s -= blitzer_count * 26
		brute_count = int(floor(float(remaining_s) * 0.45 / 8.0))
		remaining_s -= brute_count * 8
		rusher_count = int(floor(float(remaining_s) * 0.60 / 2.0))
		remaining_s -= rusher_count * 2
		crawler_count = maxi(0, remaining_s)

	# Steady, continuous spawn stream across the wave (no huge empty platoon gaps or instant clumped bursts)
	var spawn_span: float = clampf(38.0 + float(w - 10) * 1.4, 40.0, 95.0)
	var tracks: Array[Dictionary] = []

	if crawler_count > 0:
		tracks.append({
			"type": "crawler",
			"count": crawler_count,
			"interval": clampf(spawn_span / float(maxi(1, crawler_count)), 0.35, 1.40),
			"group_size": 0,
			"group_delay": 0.0,
			"start_delay": 0.0,
		})
	if rusher_count > 0:
		tracks.append({
			"type": "rusher",
			"count": rusher_count,
			"interval": clampf(spawn_span / float(maxi(1, rusher_count)), 0.45, 1.80),
			"group_size": 0,
			"group_delay": 0.0,
			"start_delay": 1.2,
		})
	if brute_count > 0:
		tracks.append({
			"type": "brute",
			"count": brute_count,
			"interval": clampf(spawn_span / float(maxi(1, brute_count)), 2.20, 7.50),
			"group_size": 0,
			"group_delay": 0.0,
			"start_delay": 2.5,
		})
	if blitzer_count > 0:
		tracks.append({
			"type": "blitzer",
			"count": blitzer_count,
			"interval": clampf(spawn_span / float(maxi(1, blitzer_count)), 2.80, 9.00),
			"group_size": 0,
			"group_delay": 0.0,
			"start_delay": 4.0,
		})
	if jugg_count > 0:
		tracks.append({
			"type": "juggernaut",
			"count": jugg_count,
			"interval": clampf(spawn_span / float(maxi(1, jugg_count)), 4.00, 14.00),
			"group_size": 0,
			"group_delay": 0.0,
			"start_delay": 6.0,
		})
	if colossus_count > 0:
		tracks.append({
			"type": "colossus",
			"count": colossus_count,
			"interval": clampf(spawn_span / float(maxi(1, colossus_count)), 7.50, 16.00),
			"group_size": 0,
			"group_delay": 0.0,
			"start_delay": 8.0,
		})

	return {
		"wave": w,
		"note": "%sWave %d (s$%d)" % ["BOSS " if is_boss_wave else "", w, budget_s],
		"target_s_dollars": budget_s,
		"tracks": tracks,
	}


static func get_wave_counts_by_type(wave_number: int, player_assets_spent: int = -1) -> Dictionary:
	var def: Dictionary = get_wave_def(wave_number, player_assets_spent)
	var counts: Dictionary = {}
	for track in def.get("tracks", []):
		var t: String = track["type"]
		counts[t] = counts.get(t, 0) + int(track["count"])
	return counts


## Computes s$, b$, base HP, mutated HP, count-weighted avg speed, and DPS needed for any wave.
## Formula: DPS needed = (total HP with mutation * avg speed) / (wave_length * 0.30 * difficulty_k)
static func compute_wave_stats(wave_number: int, hp_mutation_mult: float = -1.0) -> Dictionary:
	var counts: Dictionary = get_wave_counts_by_type(wave_number)
	var mut_mult: float = hp_mutation_mult
	if mut_mult < 0.0:
		# Default modeled mutation curve: 1.0x W1-5, 1.05x W6-10 (Rewind W5), ~1.10x W11+ (Pause W10)
		if wave_number <= 5:
			mut_mult = 1.0
		elif wave_number <= 10:
			mut_mult = 1.05
		else:
			mut_mult = 1.1025 # 1.05 * 1.05 = x1.1025 (~x1.10)

	var total_s: int = 0
	var total_b: int = 0
	var base_hp_sum: float = 0.0
	var total_units: int = 0
	var weighted_speed_sum: float = 0.0

	for unit_type in counts.keys():
		var c: int = int(counts[unit_type])
		var cfg: Dictionary = Balance.ENEMIES[unit_type]
		total_s += c * int(cfg["spawn_cost_s"])
		total_b += c * int(cfg["bounty_b"])
		base_hp_sum += float(c) * float(cfg["base_hp"])
		total_units += c
		weighted_speed_sum += float(c) * float(cfg["speed_mult"])

	var avg_speed: float = weighted_speed_sum / float(maxi(1, total_units))
	var mutated_hp: int = int(round(base_hp_sum * mut_mult))
	var wave_len: float = Balance.get_wave_length(wave_number)
	# Effective engagement window = 37 + 3*(w-1) for W1-10, capped at 68s for W11+ so late-game DPS needed stays honest
	var eff_engagement: float = 37.0 + 3.0 * float(maxi(0, wave_number - 1))
	if wave_number > 10:
		eff_engagement = minf(68.0, eff_engagement)
	var difficulty_k: float = eff_engagement / (wave_len * Balance.ENGAGEMENT_FRACTION)
	var dps_needed: int = int(round(( float(mutated_hp) / (wave_len * Balance.ENGAGEMENT_FRACTION * difficulty_k) ) * avg_speed))

	return {
		"wave": wave_number,
		"counts": counts,
		"s_dollars": total_s,
		"b_dollars": total_b,
		"base_hp": int(round(base_hp_sum)),
		"mutated_hp": mutated_hp,
		"mutation_mult": mut_mult,
		"avg_speed": avg_speed,
		"wave_length": wave_len,
		"dps_needed": dps_needed,
	}


## Simulates the exact Money / Difficulty Algorithm across waves 1..max_wave.
static func simulate_money_algorithm(max_wave: int = 10, rewind_wave_9: bool = false, pause_wave_10: bool = false) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var money: float = float(Balance.STARTING_MONEY) # $200 start
	var cum_tower_spend: float = 0.0
	var refineries: float = 0.0

	for w in range(1, max_wave + 1):
		var spend_pct: float = Balance.get_spend_pct(w)
		var spend: float = money * spend_pct
		var leftover: float = money - spend
		cum_tower_spend += spend

		# Model assumes 0.5 refineries buffer after Wave 1 (paid from post-W5 Rewind buffer)
		if w == 2:
			refineries = 0.5

		var effective_tower_dollars: float = cum_tower_spend
		if w >= 6 and w < 10:
			effective_tower_dollars = maxf(0.0, cum_tower_spend - 52.0)
		elif w >= 10:
			# Accounts for ~$250 refinery / utility Slow tower investment so un-farmed W10 ratio is ~0.78
			effective_tower_dollars = maxf(0.0, cum_tower_spend - 315.0)

		var stats: Dictionary = compute_wave_stats(w)
		var player_dps: float = effective_tower_dollars * Balance.MODEL_DPS_PER_DOLLAR
		if w == 10 and pause_wave_10:
			# Pause on Wave 10 grants 8.0s of free frozen firing time inside the kill zone
			player_dps *= 1.08

		var dps_needed: int = int(stats["dps_needed"])
		var ratio: float = player_dps / maxf(1.0, float(dps_needed))

		var bounty_b: int = int(stats["b_dollars"])
		var ref_income: float = refineries * Balance.REFINERY_RATE_PER_SEC * float(stats["wave_length"])

		results.append({
			"wave": w,
			"start_money": int(round(money)),
			"spend_pct": spend_pct,
			"spend_dollars": int(round(spend)),
			"leftover_dollars": int(round(leftover)),
			"cum_spend_dollars": int(round(cum_tower_spend)),
			"s_dollars": stats["s_dollars"],
			"b_dollars": bounty_b,
			"refinery_income": roundf(ref_income * 10.0) / 10.0,
			"mutated_hp": stats["mutated_hp"],
			"dps_needed": dps_needed,
			"player_dps": roundf(player_dps * 10.0) / 10.0,
			"ratio": roundf(ratio * 100.0) / 100.0,
		})

		money = leftover + float(bounty_b) + ref_income
		# Assumed playthrough: Rewind on Wave 5 replays Wave 5 -> extra Wave 5 bounty + refinery income
		if w == 5:
			money += float(bounty_b) + ref_income
		# Optional Rewind farming on Wave 9 before Boss Wave 10
		if w == 9 and rewind_wave_9:
			money += float(bounty_b) + ref_income

	return results


static func build_spawn_schedule(wave_number: int, custom_waves: Array[Dictionary] = [], player_assets_spent: int = -1) -> Array[Dictionary]:
	var def: Dictionary
	if not custom_waves.is_empty():
		var idx: int = clampi(wave_number - 1, 0, custom_waves.size() - 1)
		def = custom_waves[idx]
	else:
		def = get_wave_def(wave_number, player_assets_spent)

	var schedule: Array[Dictionary] = []
	for track in def.get("tracks", []):
		var unit_type: String = track["type"]
		var count: int = int(track["count"])
		var interval: float = float(track["interval"])
		var group_size: int = int(track.get("group_size", 0))
		var group_delay: float = float(track.get("group_delay", 0.0))
		var t: float = float(track.get("start_delay", 0.0))
		for i in range(count):
			schedule.append({"time": t, "type": unit_type})
			if group_size > 0 and ((i + 1) % group_size == 0) and (i + 1 < count):
				t += group_delay
			else:
				t += interval

	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["time"], b["time"]):
			return a["type"] < b["type"]
		return a["time"] < b["time"]
	)
	return schedule
