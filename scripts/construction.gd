extends RefCounted
class_name ConstructionJob

## Shared construction timer model for towers, tower upgrades, refineries, and manipulator.

var kind: String = "" # "tower_build", "tower_upgrade", "refinery", "manipulator"
var target_key: String = "" # e.g., upgrade track "damage" / "range" / "fire_rate"
var total_time: float = 1.0
var remaining_time: float = 1.0
var affected_by_haste: bool = true


func _init(p_kind: String, p_duration: float, p_target_key: String = "", p_affected_by_haste: bool = true) -> void:
	kind = p_kind
	target_key = p_target_key
	total_time = maxf(0.01, p_duration)
	remaining_time = p_duration
	affected_by_haste = p_affected_by_haste


func advance(delta: float, speed_mult: float = 1.0) -> bool:
	var eff_mult: float = speed_mult if affected_by_haste else 1.0
	remaining_time = maxf(0.0, remaining_time - delta * eff_mult)
	return remaining_time <= 0.0


func get_progress() -> float:
	if total_time <= 0.0:
		return 1.0
	return clampf(1.0 - (remaining_time / total_time), 0.0, 1.0)
