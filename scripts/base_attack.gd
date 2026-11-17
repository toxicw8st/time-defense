extends Node
class_name BaseAttackManager

## Owns the Hive Destroyer base-attack charge & firing ($450 per shot, 1/N rule by mission level).
## HARD RULE: Haste can NEVER speed up base-attack charging.

signal charge_started
signal base_attack_fired(damage: int, remaining_enemy_hp: int)

var map_ref: GameMap = null
var is_charging: bool = false
var charge_total_time: float = Balance.BASE_ATTACK_CHARGE_TIME
var charge_remaining: float = 0.0


func setup(p_map: GameMap) -> void:
	map_ref = p_map
	if not GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.connect(_on_mission_reset)
	_reset_state()


func _exit_tree() -> void:
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)


func _on_mission_reset() -> void:
	_reset_state()


func _reset_state() -> void:
	is_charging = false
	charge_total_time = Balance.BASE_ATTACK_CHARGE_TIME
	charge_remaining = 0.0
	GameState.base_attack_charging_active = false


func _process(delta: float) -> void:
	step_base_attack(GameState.get_sim_delta(delta))


func step_base_attack(delta: float) -> void:
	if GameState.mission.is_over or not is_charging or not GameState.is_wave_active or delta <= 0.0:
		return
	# Haste NEVER accelerates charge_remaining! Always 1.0x simulation delta.
	charge_remaining = maxf(0.0, charge_remaining - delta)
	if charge_remaining <= 0.0:
		_fire_hive_destroyer()


func get_charge_duration() -> float:
	var dur: float = Balance.BASE_ATTACK_CHARGE_TIME
	if GameState.mission.manipulator_level >= Balance.MANIPULATOR_MAX_LEVEL:
		dur *= float(Balance.MANIPULATOR_UPGRADES[5]["base_attack_charge_multiplier"])
	return dur


## 1/N rule: Level 1 = 1 shot (500 dmg), Level 2 = 2 shots (250 dmg), Level 3 = 3 shots (167 dmg).
func get_shot_damage() -> int:
	var level_n: int = maxi(1, GameState.selected_mission_level)
	var base_dmg: float = ceilf(float(Balance.ENEMY_BASE_MAX_HP) / float(level_n))
	var ranks: int = GameState.get_research_rank("hive_breaker")
	if ranks <= 0 and GameState.mission.owned_research.get("hive_breaker", false):
		ranks = 1
	if ranks > 0:
		base_dmg *= (1.0 + float(ranks) * float(Balance.RESEARCH_NODES["hive_breaker"]["base_attack_bonus"]))
	return int(round(base_dmg))


func get_shots_to_destroy_remaining() -> int:
	var dmg: int = max(1, get_shot_damage())
	return int(ceil(float(GameState.mission.enemy_base_hp) / float(dmg)))


func can_start_charge() -> bool:
	if GameState.mission.is_over or is_charging:
		return false
	if GameState.is_base_locked():
		return false
	if GameState.mission.enemy_base_hp <= 0:
		return false
	return GameState.mission.economy["money"] >= Balance.BASE_ATTACK_COST


func start_charge() -> bool:
	if not can_start_charge():
		return false
	if not GameState.spend_money(Balance.BASE_ATTACK_COST, false):
		return false
	charge_total_time = get_charge_duration()
	charge_remaining = charge_total_time
	is_charging = true
	GameState.base_attack_charging_active = true
	charge_started.emit()
	GameState.event_logged.emit("Hive Destroyer charging (%.0fs, $%d)" % [charge_total_time, Balance.BASE_ATTACK_COST])
	return true


func is_in_firing_warning() -> bool:
	return is_charging and charge_remaining <= Balance.BASE_ATTACK_FIRE_WARNING_TIME


func get_charge_progress() -> float:
	if not is_charging or charge_total_time <= 0.0:
		return 0.0
	return clampf(1.0 - (charge_remaining / charge_total_time), 0.0, 1.0)


func _fire_hive_destroyer() -> void:
	is_charging = false
	charge_remaining = 0.0
	GameState.base_attack_charging_active = false

	var dmg: int = get_shot_damage()
	var m := GameState.mission
	m.enemy_base_hp = max(0, m.enemy_base_hp - dmg)
	m.stats["charges_fired"] += 1
	GameState.enemy_base_hp_changed.emit(m.enemy_base_hp)

	if map_ref != null:
		map_ref.trigger_hive_beam_effect(dmg)

	var msg: String = "Hive destroyer hit - %d damage (%d / %d HP)" % [dmg, m.enemy_base_hp, Balance.ENEMY_BASE_MAX_HP]
	GameState.event_logged.emit(msg)
	base_attack_fired.emit(dmg, m.enemy_base_hp)

	if m.enemy_base_hp <= 0:
		GameState.end_mission("won", "Enemy Base destroyed by Hive Destroyer!")
