extends Node
class_name MutationManager

## Listens to GameState.time_power_used and applies the single visible mutation per power.
## Rewind -> Armoured (+15% alien HP).
## Pause -> Thaw-hardened (+20% effective HP on subsequent waves, stacked x1.38 with Rewind; -10% frozen dmg).
## Haste -> Swift (+8% alien speed).


func setup() -> void:
	if not GameState.time_power_used.is_connected(_on_time_power_used):
		GameState.time_power_used.connect(_on_time_power_used)


func _exit_tree() -> void:
	if GameState.time_power_used.is_connected(_on_time_power_used):
		GameState.time_power_used.disconnect(_on_time_power_used)


func _on_time_power_used(power_name: String) -> void:
	var m := GameState.mission
	match power_name:
		"rewind":
			m.mutations["armoured_stacks"] += 1
			var s: int = m.mutations["armoured_stacks"]
			var pct: int = int(round((GameState.get_enemy_hp_multiplier() - 1.0) * 100.0))
			GameState.event_logged.emit("Mutation: Armoured x%d (+%d%% alien HP for the rest of this mission)" % [s, pct])
		"pause":
			m.mutations["thaw_stacks"] += 1
			var s: int = m.mutations["thaw_stacks"]
			var red_pct: int = int(minf(50.0, float(s) * 10.0))
			var eff_pct: int = int(round((pow(1.20, s) - 1.0) * 100.0))
			GameState.event_logged.emit("Mutation: Thaw-hardened x%d (+%d%% eff HP next wave, -%d%% frozen dmg)" % [s, eff_pct, red_pct])
		"haste":
			m.mutations["swift_stacks"] += 1
			var s: int = m.mutations["swift_stacks"]
			var spd_pct: int = int(round((pow(1.0 + Balance.TIME_POWERS["haste"]["speed_bonus_per_stack"], s) - 1.0) * 100.0))
			GameState.event_logged.emit("Mutation: Swift x%d (+%d%% alien speed for the rest of this mission)" % [s, spd_pct])
