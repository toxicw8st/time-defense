extends Node
class_name SurgeManager

## v3.0: Surge penalty system retired! Paid, upgradable Time Abilities replace the Surge chore.
## Lightweight compatibility stub preserved so main.tscn & signal references stay clean.

signal surge_banner_triggered(banner_text: String)
signal warning_state_changed(warning_level: int)

var wave_manager_ref: WaveManager = null
var current_warning_level: int = 0


func setup(p_wm: WaveManager) -> void:
	wave_manager_ref = p_wm
	current_warning_level = 0


func get_surge_wave_span() -> int:
	return Balance.SURGE_WAVE_SPAN


func get_surge_window() -> float:
	return Balance.SURGE_BASE_WINDOW


func is_surge_paused() -> bool:
	return true


func step_surge(_delta: float) -> void:
	pass
