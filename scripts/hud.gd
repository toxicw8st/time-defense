extends CanvasLayer

signal restart_requested
signal start_wave_requested

@onready var top_status_label: Label = $TopBar/VBox/Row1/TopStatusLabel
@onready var enemy_base_label: Label = $TopBar/VBox/Row1/EnemyBaseLabel
@onready var wave_label: Label = $TopBar/VBox/Row1/WaveLabel
@onready var money_label: Label = $TopBar/VBox/Row2/MoneyLabel
@onready var research_label: Label = $TopBar/VBox/Row2/ResearchLabel
@onready var refineries_label: Label = $TopBar/VBox/Row2/RefineriesLabel
@onready var clock_label: Label = $TopBar/VBox/Row2/ClockLabel

@onready var preview_title_label: Label = $RightPanel/Margin/VBox/PreviewTitleLabel
@onready var preview_body_label: Label = $RightPanel/Margin/VBox/PreviewBodyLabel
@onready var preview_mutations_label: Label = $RightPanel/Margin/VBox/PreviewMutationsLabel
@onready var wave_summary_label: Label = $RightPanel/Margin/VBox/WaveSummaryLabel

@onready var build_menu_box: VBoxContainer = $RightPanel/Margin/VBox/BuildMenuBox
@onready var build_pad_label: Label = $RightPanel/Margin/VBox/BuildMenuBox/BuildPadLabel
@onready var build_blaster_button: Button = $RightPanel/Margin/VBox/BuildMenuBox/BuildBlasterButton
@onready var build_mortar_button: Button = $RightPanel/Margin/VBox/BuildMenuBox/BuildMortarButton

@onready var tower_panel_box: VBoxContainer = $RightPanel/Margin/VBox/TowerPanelBox
@onready var tower_header_label: Label = $RightPanel/Margin/VBox/TowerPanelBox/TowerHeaderLabel
@onready var tower_ratings_label: Label = $RightPanel/Margin/VBox/TowerPanelBox/TowerRatingsLabel
@onready var tower_status_label: Label = $RightPanel/Margin/VBox/TowerPanelBox/TowerStatusLabel
@onready var upg_dmg_button: Button = $RightPanel/Margin/VBox/TowerPanelBox/UpgradeDmgButton
@onready var upg_rng_button: Button = $RightPanel/Margin/VBox/TowerPanelBox/UpgradeRngButton
@onready var upg_spd_button: Button = $RightPanel/Margin/VBox/TowerPanelBox/UpgradeSpdButton
@onready var sell_button: Button = $RightPanel/Margin/VBox/TowerPanelBox/SellButton

@onready var surge_label: Label = $BottomBar/VBox/SurgeLabel
@onready var power_placeholder_label: Label = $BottomBar/VBox/Row2/PowerPlaceholderLabel
@onready var start_wave_button: Button = $BottomBar/VBox/Row2/StartWaveButton

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_label: Label = $DebugPanel/MarginContainer/DebugLabel

@onready var end_overlay: PanelContainer = $EndOverlay
@onready var end_title_label: Label = $EndOverlay/Margin/VBox/EndTitleLabel
@onready var end_stats_label: Label = $EndOverlay/Margin/VBox/EndStatsLabel
@onready var restart_button: Button = $EndOverlay/Margin/VBox/RestartButton

var map_ref: GameMap = null
var wave_manager_ref: WaveManager = null
var _last_summary_text: String = ""
var _selected_pad_idx: int = -1
var _selected_tower: TowerUnit = null
var _sell_confirm_armed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	debug_panel.visible = false
	end_overlay.visible = false
	build_menu_box.visible = false
	tower_panel_box.visible = false

	restart_button.pressed.connect(_on_restart_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)

	build_blaster_button.pressed.connect(func() -> void: _build_tower("blaster"))
	build_mortar_button.pressed.connect(func() -> void: _build_tower("mortar"))
	build_blaster_button.mouse_entered.connect(func() -> void: _set_preview_type("blaster"))
	build_mortar_button.mouse_entered.connect(func() -> void: _set_preview_type("mortar"))
	build_blaster_button.mouse_exited.connect(func() -> void: _set_preview_type(""))
	build_mortar_button.mouse_exited.connect(func() -> void: _set_preview_type(""))

	upg_dmg_button.pressed.connect(func() -> void: _upgrade_selected("damage"))
	upg_rng_button.pressed.connect(func() -> void: _upgrade_selected("range"))
	upg_spd_button.pressed.connect(func() -> void: _upgrade_selected("fire_rate"))
	sell_button.pressed.connect(_on_sell_pressed)

	GameState.mission_ended.connect(_on_mission_ended)
	GameState.mission_reset.connect(_on_mission_reset)
	_refresh_all()


func set_references(p_map: GameMap, p_wm: WaveManager) -> void:
	map_ref = p_map
	wave_manager_ref = p_wm
	if map_ref != null:
		map_ref.pad_selected.connect(_on_pad_selected)
		map_ref.tower_selected.connect(_on_tower_selected)
		map_ref.selection_cleared.connect(_on_selection_cleared)
	if wave_manager_ref != null:
		wave_manager_ref.wave_summary_updated.connect(_on_wave_summary_updated)
		wave_manager_ref.state_changed.connect(_on_wave_state_changed)
	_refresh_all()


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
	money_label.text = "Money: %d" % m.economy["money"]
	research_label.text = "Research: %d" % m.economy["research"]
	refineries_label.text = "Refineries: %d" % m.economy["refineries_owned"]

	var mins: int = int(GameState.mission_elapsed_seconds) / 60
	var secs: int = int(GameState.mission_elapsed_seconds) % 60
	clock_label.text = "Mission Time: %02d:%02d" % [mins, secs]

	_refresh_preview_panel()
	_refresh_selection_panel()
	_refresh_start_wave_button()

	if debug_panel.visible:
		_refresh_debug_overlay()


func _refresh_preview_panel() -> void:
	if wave_manager_ref == null:
		return
	var preview: Dictionary = wave_manager_ref.get_preview_data()
	var wave_num: int = preview["wave_number"]
	preview_title_label.text = "PRE-WAVE PREVIEW - Wave %d / 15" % wave_num

	var counts: Dictionary = preview["counts"]
	var unit_parts: PackedStringArray = []
	if counts.has("runner"):
		unit_parts.append("%d Runners (HP %d)" % [counts["runner"], GameState.get_enemy_wave_hp("runner", wave_num)])
	if counts.has("brute"):
		unit_parts.append("%d Brutes (HP %d)" % [counts["brute"], GameState.get_enemy_wave_hp("brute", wave_num)])
	preview_body_label.text = "Incoming: " + ", ".join(unit_parts)

	var muts: Array = preview["active_mutations"]
	if muts.is_empty():
		preview_mutations_label.text = "Mutations: No mutations"
		preview_mutations_label.modulate = Color(0.75, 0.85, 0.95)
	else:
		var lines: PackedStringArray = ["Active Mutations (for the rest of this mission):"]
		var has_new: bool = false
		for item in muts:
			var prefix: String = "[NEW] " if item["is_new"] else ""
			if item["is_new"]:
				has_new = true
			lines.append("%s%s x%d - %s" % [prefix, item["label"], item["stacks"], item["effect"]])
		preview_mutations_label.text = "\n".join(lines)
		preview_mutations_label.modulate = Color(1.0, 0.78, 0.32) if has_new else Color(0.95, 0.58, 0.45)

	wave_summary_label.text = _last_summary_text


func _refresh_selection_panel() -> void:
	var money: int = GameState.mission.economy["money"]
	if _selected_tower != null and is_instance_valid(_selected_tower):
		build_menu_box.visible = false
		tower_panel_box.visible = true

		var cfg: Dictionary = Balance.TOWERS[_selected_tower.tower_type]
		tower_header_label.text = "%s (Pad P%d)" % [cfg["name"], _selected_tower.pad_index + 1]
		tower_ratings_label.text = "%s - Damage: %s, Speed: %s" % [
			cfg["damage_type_label"],
			cfg["damage_rating"],
			cfg["speed_rating"],
		]
		if _selected_tower.current_job != null:
			var kind_txt: String = "Building" if not _selected_tower.is_built else "Upgrading %s" % _selected_tower.current_job.target_key.capitalize()
			tower_status_label.text = "%s: %.1f s left (cannot fire)" % [kind_txt, _selected_tower.current_job.remaining_time]
			tower_status_label.modulate = Color(1.0, 0.85, 0.35)
		else:
			tower_status_label.text = "Status: Active"
			tower_status_label.modulate = Color(0.55, 0.95, 0.65)

		_style_upgrade_button(upg_dmg_button, "Damage (+25%)", "damage", _selected_tower, money)
		_style_upgrade_button(upg_rng_button, "Range (+12%)", "range", _selected_tower, money)
		_style_upgrade_button(upg_spd_button, "Fire Rate (+15%)", "fire_rate", _selected_tower, money)

		var refund: int = _selected_tower.get_sell_refund()
		sell_button.disabled = GameState.mission.is_over
		if _sell_confirm_armed:
			sell_button.text = "CONFIRM SELL (+%d money)" % refund
			sell_button.modulate = Color(1.0, 0.55, 0.45)
		else:
			sell_button.text = "Sell Tower (+%d money, 50%%)" % refund
			sell_button.modulate = Color.WHITE
	elif _selected_pad_idx >= 0:
		build_menu_box.visible = true
		tower_panel_box.visible = false
		build_pad_label.text = "BUILD ON PAD P%d" % (_selected_pad_idx + 1)
		_style_build_button(build_blaster_button, "blaster", money)
		_style_build_button(build_mortar_button, "mortar", money)
	else:
		build_menu_box.visible = false
		tower_panel_box.visible = false


func _style_build_button(btn: Button, tower_type: String, money: int) -> void:
	var cfg: Dictionary = Balance.TOWERS[tower_type]
	var cost: int = int(cfg["cost"])
	var affordable: bool = money >= cost and not GameState.mission.is_over
	btn.text = "%s (%d$, %ds)\n%s - Dmg: %s, Spd: %s" % [
		cfg["name"],
		cost,
		int(cfg["build_time"]),
		cfg["damage_type_label"],
		cfg["damage_rating"],
		cfg["speed_rating"],
	]
	btn.disabled = not affordable
	btn.modulate = Color.WHITE if affordable else Color(1.0, 0.45, 0.45)


func _style_upgrade_button(btn: Button, title: String, key: String, tower: TowerUnit, money: int) -> void:
	var lvl: int = int(tower.levels.get(key, 0))
	var pips: String = ""
	for i in range(Balance.TOWER_UPGRADE_MAX_LEVEL):
		pips += "[*]" if i < lvl else "[ ]"
	if lvl >= Balance.TOWER_UPGRADE_MAX_LEVEL:
		btn.text = "%s %s MAX" % [title, pips]
		btn.disabled = true
		btn.modulate = Color(0.75, 0.9, 0.75)
		return
	var cost: int = Balance.TOWER_UPGRADE_COSTS[lvl]
	var btime: int = int(Balance.TOWER_UPGRADE_BUILD_TIMES[lvl])
	var can_buy: bool = tower.can_start_upgrade(key)
	btn.text = "%s %s - %d$ (%ds)" % [title, pips, cost, btime]
	btn.disabled = not can_buy
	if money < cost:
		btn.modulate = Color(1.0, 0.45, 0.45)
	elif not can_buy:
		btn.modulate = Color(0.7, 0.7, 0.7)
	else:
		btn.modulate = Color.WHITE


func _refresh_start_wave_button() -> void:
	if wave_manager_ref == null:
		start_wave_button.disabled = true
		return
	var can_start: bool = (wave_manager_ref.state == WaveManager.State.BUILD) and not GameState.mission.is_over
	start_wave_button.disabled = not can_start
	if can_start:
		start_wave_button.text = "START WAVE %d" % GameState.mission.wave_number
	elif wave_manager_ref.state == WaveManager.State.SPAWNING:
		start_wave_button.text = "SPAWNING..."
	elif wave_manager_ref.state == WaveManager.State.FIGHTING:
		start_wave_button.text = "WAVE IN PROGRESS"
	else:
		start_wave_button.text = "WAVE COMPLETE"


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


func _build_tower(tower_type: String) -> void:
	if map_ref != null and _selected_pad_idx >= 0:
		map_ref.build_tower_on_pad(_selected_pad_idx, tower_type)


func _set_preview_type(tower_type: String) -> void:
	if map_ref != null:
		map_ref.set_preview_tower_type(tower_type)


func _upgrade_selected(stat_key: String) -> void:
	if _selected_tower != null and is_instance_valid(_selected_tower):
		_sell_confirm_armed = false
		_selected_tower.start_upgrade(stat_key)
		_refresh_all()


func _on_sell_pressed() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if not _sell_confirm_armed:
		_sell_confirm_armed = true
		_refresh_selection_panel()
		return
	_sell_confirm_armed = false
	if map_ref != null:
		map_ref.sell_tower(_selected_tower)


func _on_pad_selected(pad_idx: int) -> void:
	_selected_pad_idx = pad_idx
	_selected_tower = null
	_sell_confirm_armed = false
	_refresh_selection_panel()


func _on_tower_selected(tower: TowerUnit) -> void:
	_selected_tower = tower
	_selected_pad_idx = tower.pad_index
	_sell_confirm_armed = false
	_refresh_selection_panel()


func _on_selection_cleared() -> void:
	_selected_pad_idx = -1
	_selected_tower = null
	_sell_confirm_armed = false
	_refresh_selection_panel()


func _on_wave_summary_updated(summary_text: String) -> void:
	_last_summary_text = summary_text


func _on_wave_state_changed(_new_state: int) -> void:
	_refresh_all()


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
	_last_summary_text = ""
	_selected_pad_idx = -1
	_selected_tower = null
	_sell_confirm_armed = false


func _on_start_wave_pressed() -> void:
	start_wave_requested.emit()


func _on_restart_pressed() -> void:
	GameState.reset_mission()
	restart_requested.emit()
