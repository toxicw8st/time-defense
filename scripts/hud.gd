extends CanvasLayer

signal restart_requested
signal start_wave_requested

@onready var top_status_label: Label = $TopBar/VBox/Row1/TopStatusLabel
@onready var enemy_base_bar: ProgressBar = $TopBar/VBox/Row1/EnemyBaseBox/EnemyBaseBar
@onready var enemy_base_label: Label = $TopBar/VBox/Row1/EnemyBaseBox/EnemyBaseLabel
@onready var wave_label: Label = $TopBar/VBox/Row1/WaveLabel
@onready var money_label: Label = $TopBar/VBox/Row2/MoneyLabel
@onready var research_label: Label = $TopBar/VBox/Row2/ResearchLabel
@onready var refineries_label: Label = $TopBar/VBox/Row2/RefineriesLabel
@onready var clock_label: Label = $TopBar/VBox/Row2/ClockLabel

@onready var preview_title_label: Label = $RightPanel/Margin/VBox/PreviewTitleLabel
@onready var preview_body_label: Label = $RightPanel/Margin/VBox/PreviewBodyLabel
@onready var preview_mutations_label: Label = $RightPanel/Margin/VBox/PreviewMutationsLabel
@onready var wave_summary_label: Label = $RightPanel/Margin/VBox/WaveSummaryLabel

@onready var build_menu_box: VBoxContainer = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox
@onready var build_pad_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildPadLabel
@onready var build_blaster_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildBlasterButton
@onready var build_mortar_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildMortarButton

@onready var tower_panel_box: VBoxContainer = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox
@onready var tower_header_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/TowerHeaderLabel
@onready var tower_ratings_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/TowerRatingsLabel
@onready var tower_status_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/TowerStatusLabel
@onready var upg_dmg_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/UpgradeDmgButton
@onready var upg_rng_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/UpgradeRngButton
@onready var upg_spd_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/UpgradeSpdButton
@onready var sell_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/SellButton

@onready var manip_status_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/ManipulatorBox/ManipStatusLabel
@onready var manip_upgrade_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/ManipulatorBox/ManipUpgradeButton

@onready var research_list_box: VBoxContainer = $RightPanel/Margin/VBox/Scroll/ContentVBox/ResearchBox/ResearchButtons

@onready var surge_bar: ProgressBar = $BottomBar/VBox/SurgeRow/SurgeBar
@onready var surge_label: Label = $BottomBar/VBox/SurgeRow/SurgeLabel
@onready var surge_penalty_label: Label = $BottomBar/VBox/SurgeRow/SurgePenaltyLabel
@onready var rewind_button: Button = $BottomBar/VBox/Row2/RewindButton
@onready var pause_button: Button = $BottomBar/VBox/Row2/PauseButton
@onready var haste_button: Button = $BottomBar/VBox/Row2/HasteButton
@onready var refinery_button: Button = $BottomBar/VBox/Row2/RefineryButton
@onready var charge_button: Button = $BottomBar/VBox/Row2/ChargeButton
@onready var start_wave_button: Button = $BottomBar/VBox/Row2/StartWaveButton
@onready var event_feed_label: Label = $BottomBar/VBox/EventFeedLabel

@onready var surge_banner: PanelContainer = $SurgeBanner
@onready var surge_banner_label: Label = $SurgeBanner/BannerLabel

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_label: Label = $DebugPanel/MarginContainer/DebugLabel

@onready var end_overlay: PanelContainer = $EndOverlay
@onready var end_title_label: Label = $EndOverlay/Margin/VBox/EndTitleLabel
@onready var end_stats_label: Label = $EndOverlay/Margin/VBox/EndStatsLabel
@onready var restart_button: Button = $EndOverlay/Margin/VBox/RestartButton

var map_ref: GameMap = null
var wave_manager_ref: WaveManager = null
var economy_ref: EconomyManager = null
var surge_ref: SurgeManager = null
var time_powers_ref: TimePowersManager = null
var base_attack_ref: BaseAttackManager = null

var _last_summary_text: String = ""
var _selected_pad_idx: int = -1
var _selected_tower: TowerUnit = null
var _sell_confirm_armed: bool = false
var _research_buttons: Dictionary = {}
var _event_feed: Array[String] = []
var _banner_timer: float = 0.0
var _pulse_accum: float = 0.0

const RESEARCH_ORDER: Array[String] = [
	"rapid_cycling",
	"reinforced_shots",
	"extended_optics",
	"efficient_manipulator",
	"hive_breaker",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	debug_panel.visible = false
	end_overlay.visible = false
	surge_banner.visible = false
	build_menu_box.visible = false
	tower_panel_box.visible = false

	restart_button.pressed.connect(_on_restart_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	refinery_button.pressed.connect(_on_refinery_button_pressed)
	charge_button.pressed.connect(_on_charge_button_pressed)
	manip_upgrade_button.pressed.connect(_on_manip_upgrade_pressed)

	rewind_button.pressed.connect(func() -> void: _activate_power("rewind"))
	pause_button.pressed.connect(func() -> void: _activate_power("pause"))
	haste_button.pressed.connect(func() -> void: _activate_power("haste"))

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

	_build_research_buttons()

	GameState.mission_ended.connect(_on_mission_ended)
	GameState.mission_reset.connect(_on_mission_reset)
	GameState.event_logged.connect(_on_event_logged)
	_refresh_all()


func _build_research_buttons() -> void:
	for key in RESEARCH_ORDER:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func() -> void:
			if economy_ref != null:
				economy_ref.buy_research(key)
				_refresh_all()
		)
		research_list_box.add_child(btn)
		_research_buttons[key] = btn


func set_references(
	p_map: GameMap,
	p_wm: WaveManager,
	p_econ: EconomyManager = null,
	p_surge: SurgeManager = null,
	p_tp: TimePowersManager = null,
	p_ba: BaseAttackManager = null
) -> void:
	map_ref = p_map
	wave_manager_ref = p_wm
	economy_ref = p_econ
	surge_ref = p_surge
	time_powers_ref = p_tp
	base_attack_ref = p_ba
	if map_ref != null:
		map_ref.pad_selected.connect(_on_pad_selected)
		map_ref.tower_selected.connect(_on_tower_selected)
		map_ref.selection_cleared.connect(_on_selection_cleared)
	if wave_manager_ref != null:
		wave_manager_ref.wave_summary_updated.connect(_on_wave_summary_updated)
		wave_manager_ref.state_changed.connect(_on_wave_state_changed)
	if surge_ref != null:
		surge_ref.surge_banner_triggered.connect(_on_surge_banner_triggered)
	_refresh_all()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			debug_panel.visible = not debug_panel.visible
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_pulse_accum += delta
	if _banner_timer > 0.0:
		_banner_timer = maxf(0.0, _banner_timer - delta)
		if _banner_timer <= 0.0:
			surge_banner.visible = false
	_refresh_all()


func _refresh_all() -> void:
	var m := GameState.mission
	top_status_label.text = "Lives: %d / %d" % [m.lives, Balance.PLAYER_STARTING_LIVES]
	enemy_base_bar.max_value = Balance.ENEMY_BASE_MAX_HP
	enemy_base_bar.value = m.enemy_base_hp
	var shots_left: int = base_attack_ref.get_shots_to_destroy_remaining() if base_attack_ref != null else int(ceil(float(m.enemy_base_hp) / float(Balance.BASE_ATTACK_TEST_DAMAGE_OVERRIDE)))
	enemy_base_label.text = "Enemy Base: %d / %d HP  |  Shots to destroy: %d" % [m.enemy_base_hp, Balance.ENEMY_BASE_MAX_HP, shots_left]
	wave_label.text = "Wave %d / 15" % m.wave_number
	money_label.text = "Money: %d" % m.economy["money"]
	research_label.text = "Research: %d" % m.economy["research"]
	refineries_label.text = "Refineries: %d (+%d$/5s)" % [
		m.economy["refineries_owned"],
		m.economy["refineries_owned"] * Balance.REFINERY_INCOME_PER_TICK,
	]

	var mins: int = int(GameState.mission_elapsed_seconds) / 60
	var secs: int = int(GameState.mission_elapsed_seconds) % 60
	clock_label.text = "Mission Time: %02d:%02d" % [mins, secs]

	_refresh_preview_panel()
	_refresh_selection_panel()
	_refresh_manipulator_panel()
	_refresh_research_panel()
	_refresh_surge_bar()
	_refresh_power_buttons()
	_refresh_refinery_button()
	_refresh_charge_button()
	_refresh_start_wave_button()

	if debug_panel.visible:
		_refresh_debug_overlay()


func _refresh_surge_bar() -> void:
	var m := GameState.mission
	var win: float = surge_ref.get_surge_window() if surge_ref != null else Balance.SURGE_BASE_WINDOW
	surge_bar.max_value = win
	surge_bar.value = clampf(m.surge_timer_seconds, 0.0, win)

	var paused: bool = surge_ref.is_surge_paused() if surge_ref != null else false
	var pause_tag: String = " [PAUSED]" if paused else ""
	surge_label.text = "SURGE - use a time power or all towers slow down: %.1f s%s" % [maxf(0.0, m.surge_timer_seconds), pause_tag]

	if m.surge_count > 0:
		var pct: int = int(round(pow(Balance.SURGE_ATTACK_SPEED_FACTOR, m.surge_count) * 100.0))
		surge_penalty_label.text = "Towers at %d%% speed - %d surge%s (for the rest of this mission)" % [
			pct,
			m.surge_count,
			"s" if m.surge_count > 1 else "",
		]
	else:
		surge_penalty_label.text = "0 surges"

	var rem: float = m.surge_timer_seconds
	if rem <= Balance.SURGE_WARNING_RED:
		var pulse: float = 0.6 + 0.4 * sin(_pulse_accum * 10.0)
		surge_bar.modulate = Color(1.0, 0.25, 0.25, pulse)
		surge_label.modulate = Color(1.0, 0.35, 0.35)
	elif rem <= Balance.SURGE_WARNING_AMBER:
		surge_bar.modulate = Color(1.0, 0.72, 0.22)
		surge_label.modulate = Color(1.0, 0.8, 0.32)
	else:
		surge_bar.modulate = Color(0.35, 0.78, 0.95)
		surge_label.modulate = Color(0.85, 0.92, 1.0)


func _refresh_power_buttons() -> void:
	if time_powers_ref == null:
		return
	var offline: bool = GameState.is_base_locked()
	var offline_str: String = _format_mmss(GameState.mission.manipulator_upgrading_remaining)
	_style_power_button(rewind_button, "rewind", offline, offline_str)
	_style_power_button(pause_button, "pause", offline, offline_str)
	_style_power_button(haste_button, "haste", offline, offline_str)


func _style_power_button(btn: Button, power_name: String, offline: bool, offline_str: String) -> void:
	var cfg: Dictionary = Balance.TIME_POWERS[power_name]
	var title: String = cfg["name"].to_upper()
	var effect: String = cfg["short_effect"]
	var cost: String = cfg["cost_label"]
	var status_line: String = "READY"

	if offline:
		status_line = "OFFLINE - %s" % offline_str
	elif power_name == "pause" and time_powers_ref.pause_remaining > 0.0:
		status_line = "ACTIVE: %.1fs" % time_powers_ref.pause_remaining
	elif power_name == "haste" and time_powers_ref.haste_remaining > 0.0:
		status_line = "ACTIVE: %.1fs" % time_powers_ref.haste_remaining
	elif power_name == "rewind" and wave_manager_ref != null and wave_manager_ref.is_replaying_wave():
		status_line = "REPLAYING WAVE"
	elif time_powers_ref.cooldowns.get(power_name, 0.0) > 0.0:
		status_line = "CD: %.0fs" % ceilf(time_powers_ref.cooldowns[power_name])
	elif power_name == "rewind" and not time_powers_ref.can_use_power("rewind"):
		status_line = "WAIT FOR WAVE"

	btn.text = "%s [%s]\n%s | %s" % [title, status_line, effect, cost]
	var usable: bool = time_powers_ref.can_use_power(power_name)
	btn.disabled = not usable
	if offline:
		btn.modulate = Color(0.55, 0.55, 0.6)
	elif (power_name == "pause" and time_powers_ref.pause_remaining > 0.0) or (power_name == "haste" and time_powers_ref.haste_remaining > 0.0):
		btn.modulate = Color(0.45, 0.95, 1.0)
	elif usable:
		btn.modulate = Color.WHITE
	else:
		btn.modulate = Color(0.72, 0.72, 0.75)


func _format_mmss(seconds: float) -> String:
	var s: int = int(ceilf(maxf(0.0, seconds)))
	return "%d:%02d" % [s / 60, s % 60]


func _refresh_manipulator_panel() -> void:
	var m := GameState.mission
	if m.manipulator_upgrading_remaining > 0.0:
		manip_status_label.text = "Manipulator Lv %d -> %d | OFFLINE %.1fs (Surge paused, Base locked)" % [
			m.manipulator_level,
			m.manipulator_level + 1,
			m.manipulator_upgrading_remaining,
		]
		manip_status_label.modulate = Color(1.0, 0.78, 0.35)
		manip_upgrade_button.text = "Upgrading (%s)" % _format_mmss(m.manipulator_upgrading_remaining)
		manip_upgrade_button.disabled = true
		manip_upgrade_button.modulate = Color(0.75, 0.75, 0.75)
		return

	if m.manipulator_level >= Balance.MANIPULATOR_MAX_LEVEL:
		manip_status_label.text = "Manipulator Lv %d / %d (MAX)" % [m.manipulator_level, Balance.MANIPULATOR_MAX_LEVEL]
		manip_status_label.modulate = Color(0.55, 0.95, 0.65)
		manip_upgrade_button.text = "Manipulator MAX"
		manip_upgrade_button.disabled = true
		manip_upgrade_button.modulate = Color(0.75, 0.9, 0.75)
		return

	var next_lvl: int = m.manipulator_level + 1
	var cfg: Dictionary = Balance.MANIPULATOR_UPGRADES[next_lvl]
	var cost: int = int(cfg["cost"])
	var btime: int = int(cfg["build_time"])
	manip_status_label.text = "Manipulator Lv %d -> %d: %s" % [m.manipulator_level, next_lvl, cfg["benefit_text"]]
	manip_status_label.modulate = Color(0.85, 0.9, 1.0)
	if GameState.is_base_charging():
		manip_upgrade_button.text = "Upgrade (%d$, %ds) [BASE BUSY]" % [cost, btime]
		manip_upgrade_button.disabled = true
		manip_upgrade_button.modulate = Color(0.72, 0.72, 0.72)
		return

	var can_buy: bool = time_powers_ref != null and time_powers_ref.can_upgrade_manipulator()
	manip_upgrade_button.text = "Upgrade Manipulator (%d$, %ds downtime)" % [cost, btime]
	manip_upgrade_button.disabled = not can_buy
	manip_upgrade_button.modulate = Color.WHITE if can_buy else Color(1.0, 0.45, 0.45)


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


func _refresh_research_panel() -> void:
	var res: int = GameState.mission.economy["research"]
	for key in RESEARCH_ORDER:
		var btn: Button = _research_buttons[key]
		var cfg: Dictionary = Balance.RESEARCH_NODES[key]
		var cost: int = int(cfg["cost"])
		var owned: bool = GameState.mission.owned_research.get(key, false)
		if owned:
			btn.text = "[OWNED] %s (%s)" % [cfg["name"], cfg["description"]]
			btn.disabled = true
			btn.modulate = Color(0.55, 0.95, 0.65)
		else:
			btn.text = "%s (%d R) - %s" % [cfg["name"], cost, cfg["description"]]
			var affordable: bool = res >= cost and not GameState.mission.is_over
			btn.disabled = not affordable
			btn.modulate = Color.WHITE if affordable else Color(1.0, 0.45, 0.45)


func _refresh_charge_button() -> void:
	if base_attack_ref == null:
		charge_button.disabled = true
		return
	if base_attack_ref.is_charging:
		var pct: int = int(round(base_attack_ref.get_charge_progress() * 100.0))
		if base_attack_ref.is_in_firing_warning():
			var flash: float = 0.65 + 0.35 * sin(_pulse_accum * 16.0)
			charge_button.text = "HIVE DESTROYER\nREADY - firing (%.1fs)" % base_attack_ref.charge_remaining
			charge_button.modulate = Color(1.0, 0.85, 0.25, flash)
		else:
			charge_button.text = "HIVE DESTROYER\nCHARGING %d%% (%.1fs)" % [pct, base_attack_ref.charge_remaining]
			charge_button.modulate = Color(0.45, 0.9, 1.0)
		charge_button.disabled = true
		return

	var cost: int = Balance.BASE_ATTACK_COST
	var dur: int = int(round(base_attack_ref.get_charge_duration()))
	if GameState.is_base_locked():
		charge_button.text = "Hive Destroyer (%d$, %ds)\n[BASE LOCKED]" % [cost, dur]
		charge_button.disabled = true
		charge_button.modulate = Color(0.7, 0.7, 0.7)
		return
	var affordable: bool = base_attack_ref.can_start_charge()
	charge_button.text = "Hive Destroyer (%d$, %ds)\nDeals %d dmg (no Haste)" % [cost, dur, base_attack_ref.get_shot_damage()]
	charge_button.disabled = not affordable
	charge_button.modulate = Color.WHITE if affordable else Color(1.0, 0.45, 0.45)


func _on_charge_button_pressed() -> void:
	if base_attack_ref != null:
		base_attack_ref.start_charge()
		_refresh_all()


func _refresh_refinery_button() -> void:
	if economy_ref == null:
		refinery_button.disabled = true
		return
	if economy_ref.refinery_job != null:
		refinery_button.text = "Refinery Building (%.1fs)" % economy_ref.refinery_job.remaining_time
		refinery_button.disabled = true
		refinery_button.modulate = Color(1.0, 0.88, 0.4)
		return
	var cost: int = economy_ref.get_next_refinery_cost()
	if GameState.is_base_locked():
		refinery_button.text = "Refinery (%d$) [BASE LOCKED]" % cost
		refinery_button.disabled = true
		refinery_button.modulate = Color(0.7, 0.7, 0.7)
		return
	var affordable: bool = GameState.mission.economy["money"] >= cost and not GameState.mission.is_over
	refinery_button.text = "Build Refinery (%d$, 6s)" % cost
	refinery_button.disabled = not affordable
	refinery_button.modulate = Color.WHITE if affordable else Color(1.0, 0.45, 0.45)


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
		"Surge: %.1f s left (%d surges) | Manip Lv%d" % [m.surge_timer_seconds, m.surge_count, m.manipulator_level],
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


func _activate_power(power_name: String) -> void:
	if time_powers_ref != null:
		time_powers_ref.activate_power(power_name)
		_refresh_all()


func _on_manip_upgrade_pressed() -> void:
	if time_powers_ref != null:
		time_powers_ref.start_manipulator_upgrade()
		_refresh_all()


func _on_surge_banner_triggered(banner_text: String) -> void:
	surge_banner_label.text = banner_text
	surge_banner.visible = true
	_banner_timer = 3.5


func _on_event_logged(message: String) -> void:
	_event_feed.push_front(message)
	if _event_feed.size() > 5:
		_event_feed.resize(5)
	event_feed_label.text = "Events: " + "  |  ".join(_event_feed)


func _on_refinery_button_pressed() -> void:
	if economy_ref != null:
		economy_ref.start_build_refinery()
		_refresh_all()


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
	var pct: int = int(round(pow(Balance.SURGE_ATTACK_SPEED_FACTOR, m.surge_count) * 100.0))
	end_stats_label.text = "\n".join([
		reason,
		"Mission Time: %.1f s | Wave: %d / 15 | Waves Cleared: %d" % [
			GameState.mission_elapsed_seconds,
			m.wave_number,
			m.stats["waves_completed"],
		],
		"Powers Used -> Rewind: %d | Pause: %d | Haste: %d" % [
			m.stats["powers_used"]["rewind"],
			m.stats["powers_used"]["pause"],
			m.stats["powers_used"]["haste"],
		],
		"Mutations -> Armoured x%d | Thaw-hardened x%d | Swift x%d" % [
			m.mutations["armoured_stacks"],
			m.mutations["thaw_stacks"],
			m.mutations["swift_stacks"],
		],
		"Surges Suffered: %d (Towers at %d%% speed)" % [m.surge_count, pct],
		"Money Earned: %d | Research Earned: %d | Base Charges Fired: %d" % [
			m.stats["money_earned"],
			m.stats["research_earned"],
			m.stats["charges_fired"],
		],
	])


func _on_mission_reset() -> void:
	end_overlay.visible = false
	surge_banner.visible = false
	_banner_timer = 0.0
	_last_summary_text = ""
	_selected_pad_idx = -1
	_selected_tower = null
	_sell_confirm_armed = false
	_event_feed.clear()
	event_feed_label.text = "Events: (none yet)"


func _on_start_wave_pressed() -> void:
	start_wave_requested.emit()


func _on_restart_pressed() -> void:
	GameState.reset_mission()
	restart_requested.emit()
