extends CanvasLayer

signal restart_requested

@onready var top_status_label: Label = $TopBar/VBox/Row1/TopStatusLabel
@onready var enemy_base_label: Label = $TopBar/VBox/Row1/EnemyBaseLabel
@onready var wave_label: Label = $TopBar/VBox/Row1/WaveLabel
@onready var economy_label: Label = $TopBar/VBox/Row2/EconomyLabel
@onready var clock_label: Label = $TopBar/VBox/Row2/ClockLabel

@onready var right_panel_label: Label = $RightPanel/Margin/RightPanelLabel
@onready var surge_label: Label = $BottomBar/VBox/SurgeLabel
@onready var power_placeholder_label: Label = $BottomBar/VBox/PowerPlaceholderLabel

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_label: Label = $DebugPanel/MarginContainer/DebugLabel

@onready var end_overlay: PanelContainer = $EndOverlay
@onready var end_title_label: Label = $EndOverlay/Margin/VBox/EndTitleLabel
@onready var end_stats_label: Label = $EndOverlay/Margin/VBox/EndStatsLabel
@onready var restart_button: Button = $EndOverlay/Margin/VBox/RestartButton

var map_ref: GameMap = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	debug_panel.visible = false
	end_overlay.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	GameState.mission_ended.connect(_on_mission_ended)
	GameState.mission_reset.connect(_on_mission_reset)
	_refresh_all()


func set_map_ref(p_map: GameMap) -> void:
	map_ref = p_map


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			debug_panel.visible = not debug_panel.visible
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_refresh_all()


func _refresh_all() -> void:
	var m := GameState.mission
	top_status_label.text = "Lives: %d / %d" % [m.lives, Balance.PLAYER_STARTING_LIVES]
	var shots_left: int = int(ceil(float(m.enemy_base_hp) / float(Balance.BASE_ATTACK_TEST_DAMAGE_OVERRIDE)))
	enemy_base_label.text = "Enemy Base: %d / %d HP  (Shots to kill: %d)" % [m.enemy_base_hp, Balance.ENEMY_BASE_MAX_HP, shots_left]
	wave_label.text = "Wave %d / 15" % m.wave_number
	economy_label.text = "Money: %d   |   Research: %d   |   Refineries: %d" % [
		m.economy["money"],
		m.economy["research"],
		m.economy["refineries_owned"],
	]
	var mins: int = int(GameState.mission_elapsed_seconds) / 60
	var secs: int = int(GameState.mission_elapsed_seconds) % 60
	clock_label.text = "Mission Time: %02d:%02d" % [mins, secs]

	if debug_panel.visible:
		_refresh_debug_overlay()


func _refresh_debug_overlay() -> void:
	var m := GameState.mission
	var active_count: int = map_ref.get_active_enemies().size() if map_ref != null else 0
	var path_len: float = map_ref.get_path_length() if map_ref != null else 0.0
	var eff_runner_speed: float = GameState.get_effective_enemy_speed("runner")
	var lines: PackedStringArray = [
		"[DEBUG F1]",
		"Clock: %.1f s | Path: %.0f px | Active aliens: %d" % [GameState.mission_elapsed_seconds, path_len, active_count],
		"Wave: %d / 15 | Lives: %d | Enemy Base: %d HP" % [m.wave_number, m.lives, m.enemy_base_hp],
		"Money: %d | Research: %d | Refineries: %d" % [m.economy["money"], m.economy["research"], m.economy["refineries_owned"]],
		"Runner Speed: %.1f px/s (balance base: %.1f px/s)" % [eff_runner_speed, Balance.ENEMIES["runner"]["speed"]],
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


func _on_mission_ended(outcome: String, reason: String) -> void:
	end_overlay.visible = true
	if outcome == "won":
		end_title_label.text = "VICTORY - ENEMY BASE DESTROYED"
	elif outcome == "stalled":
		end_title_label.text = "MISSION STALLED - WAVE 15 ENDED"
	else:
		end_title_label.text = "DEFEAT - BASE LOST"

	var m := GameState.mission
	end_stats_label.text = "\n".join([
		reason,
		"Mission Time: %.1f s | Wave: %d / 15" % [GameState.mission_elapsed_seconds, m.wave_number],
		"Powers Used -> Rewind: %d | Pause: %d | Haste: %d" % [
			m.stats["powers_used"]["rewind"],
			m.stats["powers_used"]["pause"],
			m.stats["powers_used"]["haste"],
		],
		"Mutations -> Armoured x%d | Thaw x%d | Swift x%d" % [
			m.mutations["armoured_stacks"],
			m.mutations["thaw_stacks"],
			m.mutations["swift_stacks"],
		],
		"Surges Suffered: %d | Base Charges Fired: %d" % [m.surge_count, m.stats["charges_fired"]],
	])


func _on_mission_reset() -> void:
	end_overlay.visible = false


func _on_restart_pressed() -> void:
	GameState.reset_mission()
	restart_requested.emit()
