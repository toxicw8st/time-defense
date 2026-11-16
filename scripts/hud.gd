extends CanvasLayer

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_label: Label = $DebugPanel/MarginContainer/DebugLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	debug_panel.visible = true
	_refresh_debug_overlay()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			debug_panel.visible = not debug_panel.visible
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if debug_panel.visible:
		_refresh_debug_overlay()


func _refresh_debug_overlay() -> void:
	var m := GameState.mission
	var lines: PackedStringArray = [
		"[DEBUG F1] Step 0 Skeleton",
		"Clock: %.1f s" % GameState.mission_elapsed_seconds,
		"Wave: %d / 15 | Lives: %d | Enemy Base: %d HP" % [m.wave_number, m.lives, m.enemy_base_hp],
		"Money: %d | Research: %d | Refineries: %d" % [m.economy["money"], m.economy["research"], m.economy["refineries_owned"]],
		"Surge: %.1f s left (%d surges)" % [m.surge_timer_seconds, m.surge_count],
		"Mutations: Armoured x%d | Thaw x%d | Swift x%d" % [
			m.mutations["armoured_stacks"],
			m.mutations["thaw_stacks"],
			m.mutations["swift_stacks"],
		],
		"Enemy HP mult: %.2fx | Tower atk-spd mult: %.2fx" % [
			GameState.get_enemy_hp_multiplier(),
			GameState.get_tower_attack_speed_multiplier(),
		],
	]
	debug_label.text = "\n".join(lines)
