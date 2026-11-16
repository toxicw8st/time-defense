extends RefCounted
class_name SnapshotHelper

## Creator-confirmed Rewind implementation:
## Rewind restarts only the current enemy wave (clearing active enemies and enemy-bound projectiles)
## while preserving ALL player-side state: towers (including mid-wave builds/upgrades), refineries,
## constructions in progress, money, research, manipulator level, surges, and lost lives.

var last_wave_snapshot: Dictionary = {}


func capture_wave_start(wave_number: int) -> Dictionary:
	var m := GameState.mission
	last_wave_snapshot = {
		"wave_number": wave_number,
		"lives_at_start": m.lives,
		"money_at_start": m.economy["money"],
		"research_at_start": m.economy["research"],
	}
	return last_wave_snapshot


func execute_rewind(map_ref: GameMap, wave_manager_ref: WaveManager) -> void:
	if map_ref != null:
		map_ref.clear_all_enemies()
		map_ref.clear_all_projectiles()
	if wave_manager_ref != null:
		wave_manager_ref.restart_wave_for_rewind()
