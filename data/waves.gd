class_name WavesData
extends RefCounted

## Wave table 1-15 from Implementation Guide p. 11.
## Pure data: editing counts/intervals/delays here changes waves with zero code edits.

const WAVES: Array[Dictionary] = [
	{
		"wave": 1,
		"note": "Teach placement + Start Wave",
		"tracks": [
			{"type": "runner", "count": 8, "interval": 1.2, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 2,
		"note": "Teach Pause",
		"tracks": [
			{"type": "runner", "count": 12, "interval": 1.0, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 3,
		"note": "Teach surge bar; first upgrade decision",
		"tracks": [
			{"type": "runner", "count": 16, "interval": 0.9, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 4,
		"note": "Mortar showcase; teach Haste",
		"tracks": [
			{"type": "runner", "count": 20, "interval": 0.5, "group_size": 5, "group_delay": 3.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 5,
		"note": "Teach Rewind + research tree opens",
		"tracks": [
			{"type": "runner", "count": 22, "interval": 0.8, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 6,
		"note": "Teach base attack; first charge should start here",
		"tracks": [
			{"type": "runner", "count": 26, "interval": 0.75, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 7,
		"note": "Manipulator upgrade window - downtime decision",
		"tracks": [
			{"type": "runner", "count": 30, "interval": 0.7, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 8,
		"note": "First Brutes; single-target (Blaster) check",
		"tracks": [
			{"type": "runner", "count": 24, "interval": 0.7, "group_size": 0, "group_delay": 0.0, "start_delay": 0.4},
			{"type": "brute", "count": 2, "interval": 8.4, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 9,
		"note": "Second charge should fire around here",
		"tracks": [
			{"type": "runner", "count": 34, "interval": 0.65, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "brute", "count": 2, "interval": 10.0, "group_size": 0, "group_delay": 0.0, "start_delay": 4.0},
		],
	},
	{
		"wave": 10,
		"note": "Hard wave. Rewind-to-farm showcase",
		"tracks": [
			{"type": "runner", "count": 20, "interval": 0.6, "group_size": 0, "group_delay": 0.0, "start_delay": 0.5},
			{"type": "brute", "count": 5, "interval": 6.0, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
		],
	},
	{
		"wave": 11,
		"note": "Sustained pressure; surge discipline test",
		"tracks": [
			{"type": "runner", "count": 40, "interval": 0.6, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "brute", "count": 3, "interval": 7.5, "group_size": 0, "group_delay": 0.0, "start_delay": 3.0},
		],
	},
	{
		"wave": 12,
		"note": "Splash + single-target together",
		"tracks": [
			{"type": "runner", "count": 44, "interval": 0.45, "group_size": 6, "group_delay": 3.0, "start_delay": 0.0},
			{"type": "brute", "count": 3, "interval": 9.0, "group_size": 0, "group_delay": 0.0, "start_delay": 2.5},
		],
	},
	{
		"wave": 13,
		"note": "Third charge window opens",
		"tracks": [
			{"type": "runner", "count": 48, "interval": 0.55, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "brute", "count": 4, "interval": 6.5, "group_size": 0, "group_delay": 0.0, "start_delay": 2.0},
		],
	},
	{
		"wave": 14,
		"note": "Near-limit defence; mutations/surges felt",
		"tracks": [
			{"type": "runner", "count": 52, "interval": 0.5, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "brute", "count": 5, "interval": 5.0, "group_size": 0, "group_delay": 0.0, "start_delay": 2.0},
		],
	},
	{
		"wave": 15,
		"note": "Final wave",
		"tracks": [
			{"type": "runner", "count": 60, "interval": 0.5, "group_size": 0, "group_delay": 0.0, "start_delay": 0.0},
			{"type": "brute", "count": 6, "interval": 4.8, "group_size": 0, "group_delay": 0.0, "start_delay": 1.5},
		],
	},
]


static func get_wave_count() -> int:
	return WAVES.size()


static func get_wave_def(wave_number: int) -> Dictionary:
	var idx: int = clampi(wave_number - 1, 0, WAVES.size() - 1)
	return WAVES[idx]


static func get_wave_counts_by_type(wave_number: int) -> Dictionary:
	var def: Dictionary = get_wave_def(wave_number)
	var counts: Dictionary = {}
	for track in def.get("tracks", []):
		var t: String = track["type"]
		counts[t] = counts.get(t, 0) + int(track["count"])
	return counts


static func build_spawn_schedule(wave_number: int, custom_waves: Array[Dictionary] = WAVES) -> Array[Dictionary]:
	var idx: int = clampi(wave_number - 1, 0, custom_waves.size() - 1)
	var def: Dictionary = custom_waves[idx]
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
