extends CanvasLayer

signal restart_requested
signal start_wave_requested

@onready var top_bar: PanelContainer = $TopBar
@onready var bottom_bar: PanelContainer = $BottomBar
@onready var top_status_label: Label = $TopBar/VBox/Row1/TopStatusLabel
@onready var enemy_base_bar: ProgressBar = $TopBar/VBox/Row1/EnemyBaseBox/EnemyBaseBar
@onready var enemy_base_label: Label = $TopBar/VBox/Row1/EnemyBaseBox/EnemyBaseLabel
@onready var wave_label: Label = $TopBar/VBox/Row1/WaveLabel
@onready var money_label: Label = $TopBar/VBox/Row2/MoneyLabel
@onready var research_label: Label = $TopBar/VBox/Row2/ResearchLabel
@onready var refineries_label: Label = $TopBar/VBox/Row2/RefineriesLabel
@onready var speed_pause_button: Button = $TopBar/VBox/Row2/SpeedBox/SpeedPauseButton
@onready var speed_1x_button: Button = $TopBar/VBox/Row2/SpeedBox/Speed1xButton
@onready var speed_2x_button: Button = $TopBar/VBox/Row2/SpeedBox/Speed2xButton
@onready var speed_3x_button: Button = $TopBar/VBox/Row2/SpeedBox/Speed3xButton
@onready var level_picker_button: Button = $TopBar/VBox/Row2/LevelPickerButton
@onready var menu_button: Button = $TopBar/VBox/Row2/MenuButton
@onready var debug_button: Button = $TopBar/VBox/Row2/DebugButton
@onready var fullscreen_button: Button = $TopBar/VBox/Row2/FullscreenButton
@onready var download_button: Button = $TopBar/VBox/Row2/DownloadButton
@onready var clock_label: Label = $TopBar/VBox/Row2/ClockLabel

@onready var right_panel: PanelContainer = $RightPanel
@onready var preview_title_label: Label = $RightPanel/Margin/VBox/PreviewTitleLabel
@onready var preview_body_label: Label = $RightPanel/Margin/VBox/PreviewBodyLabel
@onready var preview_mutations_label: Label = $RightPanel/Margin/VBox/PreviewMutationsLabel
@onready var wave_summary_label: Label = $RightPanel/Margin/VBox/WaveSummaryLabel
@onready var hover_info_panel: PanelContainer = $RightPanel/Margin/VBox/HoverInfoPanel
@onready var hover_info_label: Label = $RightPanel/Margin/VBox/HoverInfoPanel/HoverMargin/HoverClip/HoverInfoLabel

@onready var build_menu_box: VBoxContainer = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox
@onready var build_pad_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildPadLabel
@onready var build_blaster_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildBlasterButton
@onready var build_mortar_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildMortarButton
@onready var build_laser_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildLaserButton
@onready var build_slow_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildSlowButton
@onready var build_railgun_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildRailgunButton
@onready var build_annihilator_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/BuildMenuBox/BuildAnnihilatorButton

@onready var tower_panel_box: VBoxContainer = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox
@onready var tower_header_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/TowerHeaderLabel
@onready var tower_ratings_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/TowerRatingsLabel
@onready var tower_status_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/TowerStatusLabel
@onready var target_mode_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/TargetModeButton
@onready var upg_dmg_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/UpgradeDmgButton
@onready var upg_rng_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/UpgradeRngButton
@onready var upg_spd_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/UpgradeSpdButton
@onready var sell_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/TowerPanelBox/SellButton

@onready var manip_status_label: Label = $RightPanel/Margin/VBox/Scroll/ContentVBox/ManipulatorBox/ManipStatusLabel
@onready var manip_upgrade_button: Button = $RightPanel/Margin/VBox/Scroll/ContentVBox/ManipulatorBox/ManipUpgradeButton

@onready var between_levels_overlay: PanelContainer = $BetweenLevelsOverlay
@onready var meta_research_status_label: Label = $BetweenLevelsOverlay/Margin/VBox/MetaResearchStatusLabel
@onready var level_1_button: Button = $BetweenLevelsOverlay/Margin/VBox/LevelRow/Level1Button
@onready var level_2_button: Button = $BetweenLevelsOverlay/Margin/VBox/LevelRow/Level2Button
@onready var level_3_button: Button = $BetweenLevelsOverlay/Margin/VBox/LevelRow/Level3Button
@onready var level_4_button: Button = $BetweenLevelsOverlay/Margin/VBox/LevelRow/Level4Button
@onready var level_5_button: Button = $BetweenLevelsOverlay/Margin/VBox/LevelRow/Level5Button
@onready var research_list_box: VBoxContainer = $BetweenLevelsOverlay/Margin/VBox/ResearchButtons
@onready var launch_level_button: Button = $BetweenLevelsOverlay/Margin/VBox/BottomButtons/LaunchLevelButton
@onready var close_lab_button: Button = $BetweenLevelsOverlay/Margin/VBox/BottomButtons/CloseLabButton

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

@onready var prompt_banner: PanelContainer = $PromptBanner
@onready var prompt_label: Label = $PromptBanner/HBox/PromptLabel
@onready var prompt_dismiss_button: Button = $PromptBanner/HBox/PromptDismissButton
@onready var prompt_mute_button: Button = $PromptBanner/HBox/PromptMuteButton

@onready var pause_overlay: PanelContainer = $PauseOverlay
@onready var pause_resume_button: Button = $PauseOverlay/Margin/VBox/PauseButtons/PauseResumeButton
@onready var pause_restart_button: Button = $PauseOverlay/Margin/VBox/PauseButtons/PauseRestartButton
@onready var pause_mute_check: CheckBox = $PauseOverlay/Margin/VBox/PauseMuteCheck
@onready var how_time_works_label: Label = $PauseOverlay/Margin/VBox/HowTimeWorksLabel

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_label: Label = $DebugPanel/MarginContainer/DebugLabel

@onready var end_overlay: PanelContainer = $EndOverlay
@onready var end_title_label: Label = $EndOverlay/Margin/VBox/EndTitleLabel
@onready var end_stats_label: Label = $EndOverlay/Margin/VBox/EndStatsLabel
@onready var end_lab_button: Button = $EndOverlay/Margin/VBox/EndLabButton
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
var _icons: Dictionary = {}
var _hover_descriptions: Dictionary = {}
var _hovered_button: Button = null
var _tapped_info_button: Button = null
var _armed_style_state: Dictionary = {"blaster": false, "mortar": false, "laser": false, "slow": false, "railgun": false, "annihilator": false}
var _drag_candidate_type: String = ""
var _drag_start_screen_pos: Vector2 = Vector2.ZERO
var _is_dragging_tower: bool = false

var start_menu_overlay: PanelContainer = null
var start_level_buttons: Array[Button] = []
var start_level_title_label: Label = null
var start_level_desc_label: Label = null
var start_meta_label: Label = null
var start_play_button: Button = null
var start_lab_button: Button = null
var start_download_button: Button = null
var pause_main_menu_button: Button = null
var end_main_menu_button: Button = null

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
	prompt_banner.visible = false
	pause_overlay.visible = false
	between_levels_overlay.visible = false
	build_menu_box.visible = true
	tower_panel_box.visible = false

	restart_button.pressed.connect(_on_restart_pressed)
	end_lab_button.pressed.connect(open_between_levels_screen)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	refinery_button.pressed.connect(_on_refinery_button_pressed)
	charge_button.pressed.connect(_on_charge_button_pressed)
	manip_upgrade_button.pressed.connect(_on_manip_upgrade_pressed)

	speed_pause_button.pressed.connect(func() -> void: GameState.toggle_speed_pause())
	speed_1x_button.pressed.connect(func() -> void: GameState.set_game_speed(1.0))
	speed_2x_button.pressed.connect(func() -> void: GameState.set_game_speed(2.0))
	speed_3x_button.pressed.connect(func() -> void: GameState.set_game_speed(3.0))
	level_picker_button.pressed.connect(_toggle_between_levels_screen)
	menu_button.pressed.connect(_toggle_pause_menu)
	debug_button.pressed.connect(_toggle_debug_panel)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	download_button.pressed.connect(_on_download_button_pressed)

	level_1_button.pressed.connect(func() -> void: _select_level(1))
	level_2_button.pressed.connect(func() -> void: _select_level(2))
	level_3_button.pressed.connect(func() -> void: _select_level(3))
	level_4_button.pressed.connect(func() -> void: _select_level(4))
	level_5_button.pressed.connect(func() -> void: _select_level(5))
	launch_level_button.pressed.connect(_on_launch_level_pressed)
	close_lab_button.pressed.connect(func() -> void: between_levels_overlay.visible = false)

	prompt_dismiss_button.pressed.connect(_on_prompt_dismiss_pressed)
	prompt_mute_button.pressed.connect(_on_prompt_mute_pressed)
	pause_resume_button.pressed.connect(_toggle_pause_menu)
	pause_restart_button.pressed.connect(_on_pause_restart_pressed)
	pause_mute_check.toggled.connect(_on_pause_mute_toggled)
	pause_mute_check.button_pressed = GameState.prompts_muted
	_populate_how_time_works()

	rewind_button.pressed.connect(func() -> void: _activate_power("rewind"))
	pause_button.pressed.connect(func() -> void: _activate_power("pause"))
	haste_button.pressed.connect(func() -> void: _activate_power("haste"))

	build_blaster_button.pressed.connect(func() -> void: _build_tower("blaster"))
	build_mortar_button.pressed.connect(func() -> void: _build_tower("mortar"))
	build_laser_button.pressed.connect(func() -> void: _build_tower("laser"))
	build_slow_button.pressed.connect(func() -> void: _build_tower("slow"))
	build_railgun_button.pressed.connect(func() -> void: _build_tower("railgun"))
	build_annihilator_button.pressed.connect(func() -> void: _build_tower("annihilator"))
	build_blaster_button.mouse_entered.connect(func() -> void: _set_preview_type("blaster"))
	build_mortar_button.mouse_entered.connect(func() -> void: _set_preview_type("mortar"))
	build_laser_button.mouse_entered.connect(func() -> void: _set_preview_type("laser"))
	build_slow_button.mouse_entered.connect(func() -> void: _set_preview_type("slow"))
	build_railgun_button.mouse_entered.connect(func() -> void: _set_preview_type("railgun"))
	build_annihilator_button.mouse_entered.connect(func() -> void: _set_preview_type("annihilator"))
	build_blaster_button.mouse_exited.connect(func() -> void: _set_preview_type(""))
	build_mortar_button.mouse_exited.connect(func() -> void: _set_preview_type(""))
	build_laser_button.mouse_exited.connect(func() -> void: _set_preview_type(""))
	build_slow_button.mouse_exited.connect(func() -> void: _set_preview_type(""))
	build_railgun_button.mouse_exited.connect(func() -> void: _set_preview_type(""))
	build_annihilator_button.mouse_exited.connect(func() -> void: _set_preview_type(""))

	_connect_tower_drag(build_blaster_button, "blaster")
	_connect_tower_drag(build_mortar_button, "mortar")
	_connect_tower_drag(build_laser_button, "laser")
	_connect_tower_drag(build_slow_button, "slow")
	_connect_tower_drag(build_railgun_button, "railgun")
	_connect_tower_drag(build_annihilator_button, "annihilator")

	target_mode_button.pressed.connect(_on_cycle_target_mode_pressed)
	upg_dmg_button.pressed.connect(func() -> void: _upgrade_selected("damage"))
	upg_rng_button.pressed.connect(func() -> void: _upgrade_selected("range"))
	upg_spd_button.pressed.connect(func() -> void: _upgrade_selected("fire_rate"))
	sell_button.pressed.connect(_on_sell_pressed)

	_build_research_buttons()
	_build_start_menu()
	_setup_right_panel_buttons()

	GameState.mission_ended.connect(_on_mission_ended)
	GameState.mission_reset.connect(_on_mission_reset)
	GameState.event_logged.connect(_on_event_logged)
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_size_changed)
		apply_responsive_layout(_get_effective_viewport_size())
	_refresh_all()


func _exit_tree() -> void:
	if GameState.mission_ended.is_connected(_on_mission_ended):
		GameState.mission_ended.disconnect(_on_mission_ended)
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)
	if GameState.event_logged.is_connected(_on_event_logged):
		GameState.event_logged.disconnect(_on_event_logged)


func open_start_menu() -> void:
	pause_overlay.visible = false
	end_overlay.visible = false
	between_levels_overlay.visible = false
	get_tree().paused = false
	if start_menu_overlay != null:
		start_menu_overlay.visible = true
	_refresh_all()


func close_start_menu() -> void:
	if start_menu_overlay != null:
		start_menu_overlay.visible = false
	_refresh_all()


func open_between_levels_screen() -> void:
	end_overlay.visible = false
	if start_menu_overlay != null:
		start_menu_overlay.visible = false
	between_levels_overlay.visible = true
	_refresh_all()


func _toggle_between_levels_screen() -> void:
	between_levels_overlay.visible = not between_levels_overlay.visible
	_refresh_all()


func _select_level(level_n: int) -> void:
	GameState.select_level(level_n)
	if map_ref != null and not GameState.is_wave_active and GameState.mission.wave_number == 1:
		map_ref.load_level(GameState.selected_map_level)
	_refresh_all()


func _on_launch_level_pressed() -> void:
	between_levels_overlay.visible = false
	if start_menu_overlay != null:
		start_menu_overlay.visible = false
	if map_ref != null:
		map_ref.load_level(GameState.selected_map_level)
	GameState.reset_mission()
	restart_requested.emit()


func _build_start_menu() -> void:
	start_menu_overlay = PanelContainer.new()
	start_menu_overlay.name = "StartMenuOverlay"
	start_menu_overlay.visible = false
	start_menu_overlay.position = Vector2(180.0, 68.0)
	start_menu_overlay.size = Vector2(920.0, 560.0)
	start_menu_overlay.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.08, 0.14, 0.98), Color(0.38, 0.78, 1.0), 10, 6.0, 6.0))
	add_child(start_menu_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	start_menu_overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "TIME DEFENSE: CHRONO COMMAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "TACTICAL TOWER DEFENSE & TEMPORAL WARFARE — SELECT MISSION SECTOR (LEVELS 1-5)"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.86, 0.98))
	vbox.add_child(subtitle)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	var lvl_row := HBoxContainer.new()
	lvl_row.add_theme_constant_override("separation", 8)
	vbox.add_child(lvl_row)

	start_level_buttons.clear()
	for lvl_id in range(1, 6):
		var lcfg: Dictionary = Balance.LEVELS[lvl_id]
		var lbtn := Button.new()
		lbtn.name = "StartLevel%dButton" % lvl_id
		lbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbtn.custom_minimum_size = Vector2(0, 56)
		lbtn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbtn.add_theme_font_size_override("font_size", 11)
		lbtn.text = "%s\n(%s)" % [lcfg["short_name"], lcfg["zone_type"]]
		var captured_id: int = lvl_id
		lbtn.pressed.connect(func() -> void: _select_level(captured_id))
		UIIcons.apply_right_button_theme(lbtn, Color(0.32, 0.68, 0.96))
		lvl_row.add_child(lbtn)
		start_level_buttons.append(lbtn)

	var info_panel := PanelContainer.new()
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_panel.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.08, 0.12, 0.20, 0.95), Color(0.28, 0.52, 0.78), 6, 12.0, 10.0))
	vbox.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(info_vbox)

	start_level_title_label = Label.new()
	start_level_title_label.add_theme_font_size_override("font_size", 15)
	start_level_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	info_vbox.add_child(start_level_title_label)

	start_level_desc_label = Label.new()
	start_level_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_level_desc_label.add_theme_font_size_override("font_size", 12)
	start_level_desc_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	info_vbox.add_child(start_level_desc_label)

	var rules_lbl := Label.new()
	rules_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_lbl.add_theme_font_size_override("font_size", 11)
	rules_lbl.add_theme_color_override("font_color", Color(0.68, 0.84, 0.96))
	rules_lbl.text = "\n".join([
		"• DRAG & DROP PLACEMENT: Drag any tower from the right shop directly into the highlighted placement zones on the map.",
		"• BASE VISUAL ALERTS: Watch your Citadel for hull-fire/smoke (Almost Dead) vs violet lightning ripples (Imminent Time Surge).",
		"• TIME POWERS & WIN CONDITION: Use Rewind, Pause, or Haste every 5 waves to prevent Surge. Charge Hive Destroyer ($450) to destroy the Alien Hive.",
	])
	info_vbox.add_child(rules_lbl)

	start_meta_label = Label.new()
	start_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_meta_label.add_theme_font_size_override("font_size", 12)
	start_meta_label.add_theme_color_override("font_color", Color(0.48, 0.92, 1.0))
	vbox.add_child(start_meta_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	vbox.add_child(action_row)

	start_play_button = Button.new()
	start_play_button.name = "StartPlayButton"
	start_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_play_button.custom_minimum_size = Vector2(0, 46)
	start_play_button.add_theme_font_size_override("font_size", 14)
	start_play_button.text = "LAUNCH LEVEL 1"
	start_play_button.pressed.connect(func() -> void:
		if GameState.selected_mission_level != GameState.selected_map_level:
			GameState.select_level(GameState.selected_map_level)
		_on_launch_level_pressed()
	)
	UIIcons.apply_right_button_theme(start_play_button, Color(0.28, 0.88, 0.62))
	action_row.add_child(start_play_button)

	start_lab_button = Button.new()
	start_lab_button.name = "StartLabButton"
	start_lab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_lab_button.custom_minimum_size = Vector2(0, 46)
	start_lab_button.add_theme_font_size_override("font_size", 13)
	start_lab_button.text = "RESEARCH LAB (META-UPGRADES)"
	start_lab_button.pressed.connect(open_between_levels_screen)
	UIIcons.apply_right_button_theme(start_lab_button, Color(0.42, 0.72, 0.96))
	action_row.add_child(start_lab_button)

	start_download_button = Button.new()
	start_download_button.name = "StartDownloadButton"
	start_download_button.custom_minimum_size = Vector2(170, 46)
	start_download_button.add_theme_font_size_override("font_size", 12)
	start_download_button.text = "INSTALL / APP"
	start_download_button.pressed.connect(_on_download_button_pressed)
	UIIcons.apply_right_button_theme(start_download_button, Color(0.68, 0.52, 0.95))
	action_row.add_child(start_download_button)

	# Also add "Main Menu" buttons to PauseOverlay and EndOverlay
	var pause_btns := get_node_or_null("PauseOverlay/Margin/VBox/PauseButtons") as HBoxContainer
	if pause_btns != null:
		pause_main_menu_button = Button.new()
		pause_main_menu_button.name = "PauseMainMenuButton"
		pause_main_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pause_main_menu_button.text = "Main Menu"
		pause_main_menu_button.pressed.connect(open_start_menu)
		UIIcons.apply_right_button_theme(pause_main_menu_button, Color(0.42, 0.72, 0.96))
		pause_btns.add_child(pause_main_menu_button)

	var end_vbox := get_node_or_null("EndOverlay/Margin/VBox") as VBoxContainer
	if end_vbox != null:
		end_main_menu_button = Button.new()
		end_main_menu_button.name = "EndMainMenuButton"
		end_main_menu_button.text = "Return to Main Menu (Select Level 1-5)"
		end_main_menu_button.pressed.connect(open_start_menu)
		UIIcons.apply_right_button_theme(end_main_menu_button, Color(0.42, 0.72, 0.96))
		end_vbox.add_child(end_main_menu_button)


func _build_research_buttons() -> void:
	for key in RESEARCH_ORDER:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func() -> void:
			if economy_ref != null:
				economy_ref.buy_research(key, true)
				_refresh_all()
		)
		research_list_box.add_child(btn)
		_research_buttons[key] = btn


func _setup_right_panel_buttons() -> void:
	right_panel.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.08, 0.11, 0.17, 0.96), Color(0.28, 0.42, 0.62), 0, 0.0, 0.0))
	pause_overlay.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.07, 0.10, 0.16, 0.98), Color(0.38, 0.62, 0.92), 8, 4.0, 4.0))
	between_levels_overlay.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.07, 0.10, 0.16, 0.98), Color(0.38, 0.72, 0.96), 8, 4.0, 4.0))
	end_overlay.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.07, 0.10, 0.16, 0.98), Color(0.42, 0.68, 0.96), 8, 4.0, 4.0))
	debug_panel.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.06, 0.08, 0.13, 0.94), Color(0.32, 0.52, 0.75), 6, 4.0, 4.0))
	prompt_banner.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.10, 0.15, 0.24, 0.96), Color(0.42, 0.78, 1.0), 6, 8.0, 4.0))
	surge_banner.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.24, 0.09, 0.14, 0.96), Color(1.0, 0.42, 0.42), 6, 8.0, 4.0))
	UIIcons.style_progress_bar(enemy_base_bar, Color(0.88, 0.24, 0.30), Color(0.55, 0.25, 0.32))
	UIIcons.style_progress_bar(surge_bar, Color(0.28, 0.78, 0.98), Color(0.28, 0.45, 0.68))
	hover_info_panel.add_theme_stylebox_override("panel", UIIcons.make_button_style(Color(0.10, 0.13, 0.19), Color(0.32, 0.44, 0.62), 1))

	var icon_keys: Array[String] = [
		"blaster", "mortar", "laser", "slow", "railgun", "annihilator", "target", "damage", "range", "fire_rate", "sell", "manipulator",
		"rapid_cycling", "reinforced_shots", "extended_optics", "efficient_manipulator", "hive_breaker",
	]
	for k in icon_keys:
		_icons[k] = UIIcons.create_icon(k)

	_init_styled_button(build_blaster_button, _icons["blaster"], Color(0.28, 0.62, 0.95))
	_init_styled_button(build_mortar_button, _icons["mortar"], Color(0.32, 0.78, 0.54))
	_init_styled_button(build_laser_button, _icons["laser"], Color(0.85, 0.35, 0.82))
	_init_styled_button(build_slow_button, _icons["slow"], Color(0.25, 0.82, 0.92))
	_init_styled_button(build_railgun_button, _icons["railgun"], Color(0.68, 0.42, 0.95))
	_init_styled_button(build_annihilator_button, _icons["annihilator"], Color(1.0, 0.72, 0.25))
	_init_styled_button(target_mode_button, _icons["target"], Color(0.95, 0.85, 0.40))
	_init_styled_button(upg_dmg_button, _icons["damage"], Color(0.92, 0.48, 0.35))
	_init_styled_button(upg_rng_button, _icons["range"], Color(0.35, 0.82, 0.95))
	_init_styled_button(upg_spd_button, _icons["fire_rate"], Color(0.95, 0.82, 0.32))
	_init_styled_button(sell_button, _icons["sell"], Color(0.88, 0.72, 0.25))
	_init_styled_button(manip_upgrade_button, _icons["manipulator"], Color(0.68, 0.52, 0.95))

	for key in RESEARCH_ORDER:
		var btn: Button = _research_buttons[key]
		_init_styled_button(btn, _icons[key], Color(0.42, 0.72, 0.92))

	UIIcons.apply_right_button_theme(rewind_button, Color(0.75, 0.58, 0.95))
	UIIcons.apply_right_button_theme(pause_button, Color(0.42, 0.78, 0.98))
	UIIcons.apply_right_button_theme(haste_button, Color(0.42, 0.92, 0.72))
	UIIcons.apply_right_button_theme(refinery_button, Color(0.38, 0.82, 0.58))
	UIIcons.apply_right_button_theme(charge_button, Color(0.95, 0.62, 0.28))
	UIIcons.apply_right_button_theme(start_wave_button, Color(0.38, 0.78, 1.0))

	for top_btn in [speed_pause_button, speed_1x_button, speed_2x_button, speed_3x_button, level_picker_button, menu_button, debug_button, fullscreen_button, download_button]:
		UIIcons.apply_right_button_theme(top_btn, Color(0.36, 0.56, 0.82))


func _init_styled_button(btn: Button, icon_tex: Texture2D, accent: Color) -> void:
	btn.icon = icon_tex
	btn.expand_icon = false
	UIIcons.apply_right_button_theme(btn, accent)
	btn.mouse_entered.connect(func() -> void:
		_hovered_button = btn
		_refresh_hover_info()
	)
	btn.mouse_exited.connect(func() -> void:
		if _hovered_button == btn:
			_hovered_button = null
			_refresh_hover_info()
	)
	btn.pressed.connect(func() -> void:
		_tapped_info_button = btn
		_refresh_hover_info()
	)
	# Also respond to touch/click even when disabled so mobile users can tap any button to inspect it
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			_tapped_info_button = btn
			_refresh_hover_info()
	)


func _set_button_description(btn: Button, desc: String) -> void:
	_hover_descriptions[btn] = desc
	btn.tooltip_text = desc
	if _hovered_button == btn or _tapped_info_button == btn:
		_refresh_hover_info()


func _refresh_hover_info() -> void:
	var active_btn: Button = _hovered_button if _hovered_button != null else _tapped_info_button
	if active_btn != null and is_instance_valid(active_btn) and _hover_descriptions.has(active_btn):
		hover_info_label.text = _hover_descriptions[active_btn]
		hover_info_label.modulate = Color(0.95, 0.98, 1.0)
	else:
		hover_info_label.text = "Hover or tap any button below for details."
		hover_info_label.modulate = Color(0.68, 0.76, 0.88)


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
	if get_viewport() != null:
		apply_responsive_layout(_get_effective_viewport_size())
	_check_teaching_prompt()
	_refresh_all()


func _connect_tower_drag(btn: Button, tower_type: String) -> void:
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if GameState.mission.is_over:
			return
		var cost: int = int(Balance.TOWERS[tower_type]["cost"])
		if GameState.mission.economy["money"] < cost:
			return
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_drag_candidate_type = tower_type
			_drag_start_screen_pos = ev.global_position
			_is_dragging_tower = false
		elif ev is InputEventScreenTouch and ev.pressed:
			_drag_candidate_type = tower_type
			_drag_start_screen_pos = btn.get_global_transform_with_canvas() * ev.position
			_is_dragging_tower = false
	)


func drag_and_drop_tower(tower_type: String, target_screen_pos: Vector2) -> TowerUnit:
	if map_ref == null:
		return null
	map_ref.update_drag_placement(tower_type, target_screen_pos)
	var built: TowerUnit = map_ref.finish_drag_placement(tower_type, target_screen_pos)
	_refresh_all()
	return built


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			debug_panel.visible = not debug_panel.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if _is_dragging_tower and map_ref != null:
				map_ref.cancel_drag_placement()
				_drag_candidate_type = ""
				_is_dragging_tower = false
			else:
				_toggle_pause_menu()
			get_viewport().set_input_as_handled()
		return

	if _drag_candidate_type != "":
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			var gpos: Vector2 = event.position
			if not _is_dragging_tower and gpos.distance_to(_drag_start_screen_pos) >= 8.0:
				_is_dragging_tower = true
				if map_ref != null:
					map_ref.set_pending_build_type(_drag_candidate_type)
			if _is_dragging_tower and map_ref != null:
				map_ref.update_drag_placement(_drag_candidate_type, gpos)
				_refresh_selection_panel()
		elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
			if _is_dragging_tower and map_ref != null:
				var built: TowerUnit = map_ref.finish_drag_placement(_drag_candidate_type, event.position)
				if built != null:
					map_ref.set_pending_build_type("")
				_refresh_all()
			_drag_candidate_type = ""
			_is_dragging_tower = false


func _process(delta: float) -> void:
	if not get_tree().paused:
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

	var shot_dmg: int = base_attack_ref.get_shot_damage() if base_attack_ref != null else Balance.BASE_ATTACK_TEST_DAMAGE_OVERRIDE
	var shots_left: int = base_attack_ref.get_shots_to_destroy_remaining() if base_attack_ref != null else int(ceil(float(m.enemy_base_hp) / float(shot_dmg)))
	var charge_pct: int = int(round(base_attack_ref.get_charge_progress() * 100.0)) if base_attack_ref != null else 0
	enemy_base_label.text = "Enemy Base: %d / %d HP | Charge: %d%% | Cost: $%d | Dmg: %d/shot | Charges needed: %d" % [
		m.enemy_base_hp,
		Balance.ENEMY_BASE_MAX_HP,
		charge_pct,
		Balance.BASE_ATTACK_COST,
		shot_dmg,
		shots_left,
	]

	var max_w: int = wave_manager_ref.max_waves_limit if wave_manager_ref != null else WavesData.MISSION_TARGET_WAVE
	wave_label.text = "Wave %d / %d (Lv %d)" % [m.wave_number, max_w, GameState.selected_mission_level]
	money_label.text = "Money: $%d" % m.economy["money"]
	research_label.text = "Research: %d R (%d/%d)" % [
		GameState.meta_research,
		int(m.stats["research_earned"]),
		Balance.MAX_RESEARCH_PER_MISSION,
	]
	refineries_label.text = "Ref: %d (+$%.2f/s)" % [
		m.economy["refineries_owned"],
		float(m.economy["refineries_owned"]) * Balance.REFINERY_RATE_PER_SEC,
	]

	_refresh_speed_buttons()

	var mins: int = int(GameState.mission_elapsed_seconds) / 60
	var secs: int = int(GameState.mission_elapsed_seconds) % 60
	clock_label.text = "Time: %02d:%02d (%.0fx)" % [mins, secs, 0.0 if GameState.is_speed_paused else GameState.game_speed]

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


func _refresh_speed_buttons() -> void:
	var paused: bool = GameState.is_speed_paused
	var spd: float = GameState.game_speed
	speed_pause_button.modulate = Color(1.0, 0.65, 0.35) if paused else Color.WHITE
	speed_1x_button.modulate = Color(0.45, 0.95, 1.0) if (not paused and is_equal_approx(spd, 1.0)) else Color.WHITE
	speed_2x_button.modulate = Color(0.45, 0.95, 1.0) if (not paused and is_equal_approx(spd, 2.0)) else Color.WHITE
	speed_3x_button.modulate = Color(0.45, 0.95, 1.0) if (not paused and is_equal_approx(spd, 3.0)) else Color.WHITE


func _refresh_surge_bar() -> void:
	var m := GameState.mission
	var win: float = surge_ref.get_surge_window() if surge_ref != null else Balance.SURGE_BASE_WINDOW
	surge_bar.max_value = win
	surge_bar.value = clampf(m.surge_timer_seconds, 0.0, win)

	var paused: bool = surge_ref.is_surge_paused() if surge_ref != null else false
	var pause_tag: String = " [PAUSED]" if paused else ""
	surge_label.text = "SURGE DEADLINE: Start of Wave %d (%.0fs)%s - use any time power to reset (+5 waves)" % [
		m.surge_deadline_wave,
		maxf(0.0, m.surge_timer_seconds),
		pause_tag,
	]

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
	if rem <= Balance.SURGE_WARNING_RED or m.wave_number + 1 >= m.surge_deadline_wave:
		var pulse: float = 0.6 + 0.4 * sin(_pulse_accum * 10.0)
		surge_bar.modulate = Color(1.0, 0.25, 0.25, pulse)
		surge_label.modulate = Color(1.0, 0.35, 0.35)
	elif rem <= Balance.SURGE_WARNING_AMBER or m.wave_number + 2 >= m.surge_deadline_wave:
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
	var hive_charging: bool = GameState.is_base_charging()
	_style_power_button(rewind_button, "rewind", offline, offline_str, hive_charging)
	_style_power_button(pause_button, "pause", offline, offline_str, hive_charging)
	_style_power_button(haste_button, "haste", offline, offline_str, hive_charging)


func _style_power_button(btn: Button, power_name: String, offline: bool, offline_str: String, hive_charging: bool) -> void:
	var cfg: Dictionary = Balance.TIME_POWERS[power_name]
	var title: String = cfg["name"].to_upper()
	var effect: String = cfg["short_effect"]
	var cost: String = cfg["cost_label"]
	var status_line: String = "READY"

	if offline:
		status_line = "OFFLINE %s" % offline_str
	elif hive_charging:
		status_line = "PAUSED (HIVE)"
	elif power_name == "pause" and time_powers_ref.pause_remaining > 0.0:
		status_line = "ACTIVE %.1fs" % time_powers_ref.pause_remaining
	elif power_name == "haste" and time_powers_ref.haste_remaining > 0.0:
		status_line = "ACTIVE %.1fs" % time_powers_ref.haste_remaining
	elif power_name == "rewind" and wave_manager_ref != null and wave_manager_ref.is_replaying_wave():
		status_line = "REPLAYING"
	elif power_name == "rewind" and wave_manager_ref != null and wave_manager_ref.state == WaveManager.State.BUILD and GameState.mission.rewound_in_current_build_phase:
		status_line = "USED THIS BUILD"
	elif time_powers_ref.cooldowns.get(power_name, 0.0) > 0.0:
		status_line = "CD %.0fs" % ceilf(time_powers_ref.cooldowns[power_name])
	elif not time_powers_ref.can_use_power(power_name):
		status_line = "WAIT FOR WAVE"

	btn.text = "%s [%s]\n%s\n%s" % [title, status_line, effect, cost]
	var usable: bool = time_powers_ref.can_use_power(power_name)
	btn.disabled = not usable
	if offline or hive_charging:
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
		var phase_note: String = "OFFLINE %.1fs (Surge paused, Base locked)" % m.manipulator_upgrading_remaining
		if not GameState.is_wave_active:
			phase_note = "QUEUED %.1fs (builds in wave; powers OFFLINE)" % m.manipulator_upgrading_remaining
		manip_status_label.text = "Manipulator Lv %d -> %d | %s" % [
			m.manipulator_level,
			m.manipulator_level + 1,
			phase_note,
		]
		manip_status_label.modulate = Color(1.0, 0.78, 0.35)
		manip_upgrade_button.text = "Manipulator (%s)" % _format_mmss(m.manipulator_upgrading_remaining)
		manip_upgrade_button.disabled = true
		manip_upgrade_button.modulate = Color(0.85, 0.85, 0.88)
		_set_button_description(manip_upgrade_button, "Upgrading Manipulator: all time powers OFFLINE, Base locked, Surge paused.")
		return

	if m.manipulator_level >= Balance.MANIPULATOR_MAX_LEVEL:
		manip_status_label.text = "Manipulator Lv %d / %d" % [m.manipulator_level, Balance.MANIPULATOR_MAX_LEVEL]
		manip_status_label.modulate = Color(0.55, 0.95, 0.65)
		manip_upgrade_button.text = "Manipulator MAX"
		manip_upgrade_button.disabled = true
		manip_upgrade_button.modulate = Color(0.75, 0.95, 0.78)
		_set_button_description(manip_upgrade_button, "Manipulator is at maximum prototype level (Lv 5).")
		return

	var next_lvl: int = m.manipulator_level + 1
	var cfg: Dictionary = Balance.MANIPULATOR_UPGRADES[next_lvl]
	var cost: int = int(cfg["cost"])
	var btime: int = int(cfg["build_time"])
	manip_status_label.text = "Manipulator Lv %d" % m.manipulator_level
	manip_status_label.modulate = Color(0.85, 0.9, 1.0)
	_set_button_description(manip_upgrade_button, "Lv%d ($%d, %ds): %s. Powers OFFLINE & Surge paused." % [
		next_lvl,
		cost,
		btime,
		cfg["benefit_text"],
	])
	if GameState.is_base_charging():
		manip_upgrade_button.text = "Manipulator Lv%d ($%d) [BUSY]" % [next_lvl, cost]
		manip_upgrade_button.disabled = true
		manip_upgrade_button.modulate = Color(0.78, 0.78, 0.82)
		return

	var can_buy: bool = time_powers_ref != null and time_powers_ref.can_upgrade_manipulator()
	manip_upgrade_button.text = "Manipulator Lv%d ($%d)" % [next_lvl, cost]
	manip_upgrade_button.disabled = not can_buy
	manip_upgrade_button.modulate = Color.WHITE if can_buy else Color(1.0, 0.65, 0.65)


func _refresh_preview_panel() -> void:
	if wave_manager_ref == null:
		return
	var preview: Dictionary = wave_manager_ref.get_preview_data()
	var wave_num: int = preview["wave_number"]
	var max_w: int = wave_manager_ref.max_waves_limit
	preview_title_label.text = "WAVE %d / %d (s$%d, b$%d, DPS req %d)" % [
		wave_num,
		max_w,
		int(preview.get("s_dollars", 0)),
		int(preview.get("b_dollars", 0)),
		int(preview.get("dps_needed", 0)),
	]

	var counts: Dictionary = preview["counts"]
	var unit_parts: PackedStringArray = []
	for utype in ["juggernaut", "blitzer", "brute", "rusher", "crawler"]:
		if counts.has(utype):
			var uname: String = Balance.ENEMIES[utype]["name"]
			unit_parts.append("%d %s (HP %d)" % [counts[utype], uname, GameState.get_enemy_wave_hp(utype, wave_num)])
	preview_body_label.text = "Incoming: " + ", ".join(unit_parts)

	var muts: Array = preview["active_mutations"]
	if muts.is_empty():
		preview_mutations_label.text = "Mutations: No mutations"
		preview_mutations_label.modulate = Color(0.75, 0.85, 0.95)
	else:
		var lines: PackedStringArray = ["Active Mutations (mission):"]
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
		var loc_tag: String = "Pad P%d" % (_selected_tower.pad_index + 1) if _selected_tower.pad_index >= 0 else "Tower Zone"
		tower_header_label.text = "%s (%s)" % [cfg["name"], loc_tag]
		tower_ratings_label.text = "%s - Damage: %s, Speed: %s" % [
			cfg["damage_type_label"],
			cfg["damage_rating"],
			cfg["speed_rating"],
		]
		if _selected_tower.current_job != null:
			var kind_txt: String = "Building" if not _selected_tower.is_built else "Upgrading %s" % _selected_tower.current_job.target_key.capitalize()
			var wave_tag: String = "" if GameState.is_wave_active else " [starts in wave]"
			tower_status_label.text = "%s: %.1f s left (cannot fire)%s" % [kind_txt, _selected_tower.current_job.remaining_time, wave_tag]
			tower_status_label.modulate = Color(1.0, 0.85, 0.35)
		else:
			tower_status_label.text = "Status: Active"
			tower_status_label.modulate = Color(0.55, 0.95, 0.65)

		var tlabel: String = str(Balance.TARGETING_LABELS.get(_selected_tower.target_mode, "First"))
		target_mode_button.text = "Target: %s (tap to cycle)" % tlabel
		target_mode_button.disabled = GameState.mission.is_over
		_set_button_description(target_mode_button, "Targeting (%s): First/Last/Strongest/Weakest/Fastest/Slowest." % tlabel)

		if _selected_tower.uses_decay_upgrades():
			_style_upgrade_button(upg_dmg_button, "Decay DoT", "damage", _selected_tower, money, "Flat Time Decay DoT/sec (3 ticks, 150% vs Refl/Jugg, execute <1 HP)")
		else:
			_style_upgrade_button(upg_dmg_button, "Damage", "damage", _selected_tower, money, "+35% / +80% / +140% / +220% / +320% total damage")
		_style_upgrade_button(upg_rng_button, "Range", "range", _selected_tower, money, "+25% / +60% / +100% / +130% / +160% total range")
		_style_upgrade_button(upg_spd_button, "Fire Rate", "fire_rate", _selected_tower, money, "+20% / +45% / +75% / +110% / +150% fire speed")

		var refund: int = _selected_tower.get_sell_refund()
		sell_button.disabled = GameState.mission.is_over
		_set_button_description(sell_button, "Refund $%d (50%% of $%d spent) and free placement slot." % [
			refund,
			_selected_tower.total_spent,
		])
		if _sell_confirm_armed:
			sell_button.text = "CONFIRM SELL (+$%d)" % refund
			sell_button.modulate = Color(1.0, 0.55, 0.45)
		else:
			sell_button.text = "Sell Tower (+$%d)" % refund
			sell_button.modulate = Color.WHITE
	elif _selected_pad_idx >= 0 or (map_ref != null and map_ref.selected_drop_pos.x >= 0.0):
		build_menu_box.visible = true
		tower_panel_box.visible = false
		var zlabel: String = map_ref.get_zone_label_for_pad(_selected_pad_idx) if (map_ref != null and _selected_pad_idx >= 0) else "TOWER ZONE"
		if map_ref != null and map_ref.selected_zone_index >= 0 and map_ref.selected_zone_index < map_ref.active_placement_zones.size():
			zlabel = str(map_ref.active_placement_zones[map_ref.selected_zone_index]["label"])
		build_pad_label.text = "BUILD IN %s%s" % [zlabel, (" - PAD P%d" % (_selected_pad_idx + 1)) if _selected_pad_idx >= 0 else ""]
		_style_build_button(build_blaster_button, "blaster", money, false)
		_style_build_button(build_mortar_button, "mortar", money, false)
		_style_build_button(build_laser_button, "laser", money, false)
		_style_build_button(build_slow_button, "slow", money, false)
		_style_build_button(build_railgun_button, "railgun", money, false)
		_style_build_button(build_annihilator_button, "annihilator", money, false)
	else:
		build_menu_box.visible = true
		tower_panel_box.visible = false
		var pending: String = map_ref.pending_build_type if map_ref != null else ""
		var cur_lvl: int = map_ref.current_level_id if map_ref != null else GameState.selected_map_level
		var z_rule: String = str(Balance.LEVELS.get(cur_lvl, Balance.LEVELS[1])["zone_type"]).to_upper()
		if _is_dragging_tower and _drag_candidate_type != "":
			build_pad_label.text = "DROP %s IN ANY %s" % [Balance.TOWERS[_drag_candidate_type]["name"].to_upper(), z_rule]
		elif pending != "":
			build_pad_label.text = "TAP OR DROP IN %s TO PLACE %s" % [z_rule, Balance.TOWERS[pending]["name"].to_upper()]
		else:
			build_pad_label.text = "DRAG TOWER TO %s" % z_rule
		_style_build_button(build_blaster_button, "blaster", money, pending == "blaster")
		_style_build_button(build_mortar_button, "mortar", money, pending == "mortar")
		_style_build_button(build_laser_button, "laser", money, pending == "laser")
		_style_build_button(build_slow_button, "slow", money, pending == "slow")
		_style_build_button(build_railgun_button, "railgun", money, pending == "railgun")
		_style_build_button(build_annihilator_button, "annihilator", money, pending == "annihilator")


func _refresh_research_panel() -> void:
	var res: int = GameState.meta_research
	var sel_lvl: int = GameState.selected_mission_level
	var sel_map: int = GameState.selected_map_level
	var map_cfg: Dictionary = Balance.LEVELS.get(sel_map, Balance.LEVELS[1])
	meta_research_status_label.text = "Persistent Meta-Research: %d R | Selected: %s (%s | %d shot%s to destroy Hive)" % [
		res,
		map_cfg["name"],
		map_cfg["zone_type"],
		sel_lvl,
		"s" if sel_lvl > 1 else "",
	]
	var lvl_btns: Array[Button] = [level_1_button, level_2_button, level_3_button, level_4_button, level_5_button]
	for idx in range(lvl_btns.size()):
		if lvl_btns[idx] != null:
			lvl_btns[idx].modulate = Color(0.45, 0.95, 1.0) if sel_map == (idx + 1) else Color.WHITE

	if start_menu_overlay != null:
		for idx in range(start_level_buttons.size()):
			var sbtn: Button = start_level_buttons[idx]
			var is_active: bool = (sel_map == idx + 1)
			sbtn.modulate = Color(0.45, 0.98, 1.0) if is_active else Color.WHITE
		if start_level_title_label != null:
			start_level_title_label.text = "%s  —  %s (%d Hive Destroyer Shot%s)" % [
				str(map_cfg["name"]).to_upper(),
				str(map_cfg["zone_type"]),
				int(map_cfg["shots_required"]),
				"s" if int(map_cfg["shots_required"]) > 1 else "",
			]
		if start_level_desc_label != null:
			start_level_desc_label.text = str(map_cfg["description"])
		if start_meta_label != null:
			start_meta_label.text = "Persistent Meta-Research Available: %d R (Max %d R earned per mission)" % [res, Balance.MAX_RESEARCH_PER_MISSION]
		if start_play_button != null:
			start_play_button.text = "START %s" % str(map_cfg["name"]).to_upper()

	var can_spend_now: bool = not GameState.is_wave_active and (GameState.mission.wave_number == 1 or GameState.mission.is_over)
	for key in RESEARCH_ORDER:
		var btn: Button = _research_buttons[key]
		var cfg: Dictionary = Balance.RESEARCH_NODES[key]
		var rank: int = GameState.get_research_rank(key)
		var max_rank: int = cfg["rank_costs"].size()
		var cost: int = GameState.get_next_research_cost(key)
		if rank >= max_rank or cost < 0:
			_set_button_description(btn, "MAX Rank (%d/%d): %s." % [rank, max_rank, cfg["description"]])
			btn.text = "%s [Rank %d/%d MAX]" % [cfg["name"], rank, max_rank]
			btn.disabled = true
			btn.modulate = Color(0.62, 0.95, 0.72)
		else:
			_set_button_description(btn, "Rank %d->%d (%d R): %s. (Between levels only)" % [
				rank,
				rank + 1,
				cost,
				cfg["description"],
			])
			btn.text = "%s [Rank %d/%d] (%d R)" % [cfg["name"], rank, max_rank, cost]
			var affordable: bool = res >= cost and can_spend_now
			btn.disabled = not affordable
			btn.modulate = Color.WHITE if affordable else Color(1.0, 0.65, 0.65)


func _refresh_charge_button() -> void:
	if base_attack_ref == null:
		charge_button.disabled = true
		return
	if base_attack_ref.is_charging:
		var pct: int = int(round(base_attack_ref.get_charge_progress() * 100.0))
		if not GameState.is_wave_active:
			charge_button.text = "HIVE DESTROYER\nARMED (%.1fs in wave)" % base_attack_ref.charge_remaining
			charge_button.modulate = Color(0.7, 0.9, 1.0)
		elif base_attack_ref.is_in_firing_warning():
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
		charge_button.text = "Hive Destroyer ($%d, %ds)\n[BASE LOCKED]" % [cost, dur]
		charge_button.disabled = true
		charge_button.modulate = Color(0.7, 0.7, 0.7)
		return
	var affordable: bool = base_attack_ref.can_start_charge()
	charge_button.text = "Hive Destroyer ($%d, %ds)\nDeals %d dmg (no Haste)" % [cost, dur, base_attack_ref.get_shot_damage()]
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
		var suffix: String = "" if GameState.is_wave_active else " [in wave]"
		refinery_button.text = "Refinery (%.1fs)%s" % [economy_ref.refinery_job.remaining_time, suffix]
		refinery_button.disabled = true
		refinery_button.modulate = Color(1.0, 0.88, 0.4)
		return
	var cost: int = economy_ref.get_next_refinery_cost()
	if GameState.is_base_locked():
		refinery_button.text = "Refinery ($%d) [BASE LOCKED]" % cost
		refinery_button.disabled = true
		refinery_button.modulate = Color(0.7, 0.7, 0.7)
		return
	var affordable: bool = GameState.mission.economy["money"] >= cost and not GameState.mission.is_over
	refinery_button.text = "Build Refinery ($%d, %.0fs)\n+$%.2f/sec" % [cost, Balance.REFINERY_BUILD_TIME, Balance.REFINERY_RATE_PER_SEC]
	refinery_button.disabled = not affordable
	refinery_button.modulate = Color.WHITE if affordable else Color(1.0, 0.45, 0.45)


func _style_build_button(btn: Button, tower_type: String, money: int, is_armed: bool = false) -> void:
	var cfg: Dictionary = Balance.TOWERS[tower_type]
	var cost: int = int(cfg["cost"])
	var affordable: bool = money >= cost and not GameState.mission.is_over
	var armed_prefix: String = "[CLICK PAD] " if is_armed else ""
	btn.text = "%s%s ($%d)" % [armed_prefix, cfg["name"], cost]
	btn.disabled = not affordable
	if _armed_style_state.get(tower_type, false) != is_armed:
		_armed_style_state[tower_type] = is_armed
		var accent := Color(0.28, 0.62, 0.95)
		if tower_type == "mortar":
			accent = Color(0.32, 0.78, 0.54)
		elif tower_type == "laser":
			accent = Color(0.85, 0.35, 0.82)
		elif tower_type == "slow":
			accent = Color(0.25, 0.82, 0.92)
		elif tower_type == "railgun":
			accent = Color(0.68, 0.42, 0.95)
		elif tower_type == "annihilator":
			accent = Color(1.0, 0.72, 0.25)
		UIIcons.apply_right_button_theme(btn, accent, is_armed)

	var desc: String = "$%d, %ds | %s" % [
		cost,
		int(cfg["build_time"]),
		cfg["damage_type_label"],
	]
	if tower_type == "mortar":
		desc += " - AoE vs Standard."
	elif tower_type == "laser":
		desc += " - 150% Std, 10% Refl."
	elif tower_type == "slow":
		desc += " - 30% slow 2s + flat Time Decay."
	elif tower_type == "railgun":
		desc += " - 140 hit + 50% slow 4s + Decay."
	elif tower_type == "annihilator":
		desc += " - Heavy anti-boss (117-491/hit vs Jugg)."
	else:
		desc += " - JUGGERNAUT COUNTER (180%)."
	_set_button_description(btn, desc)

	if is_armed:
		btn.modulate = Color(0.75, 0.98, 1.0)
	else:
		btn.modulate = Color.WHITE if affordable else Color(1.0, 0.65, 0.65)


func _style_upgrade_button(btn: Button, title: String, key: String, tower: TowerUnit, money: int, desc_detail: String) -> void:
	var lvl: int = int(tower.levels.get(key, 0))
	var pips: String = ""
	for i in range(Balance.TOWER_UPGRADE_MAX_LEVEL):
		pips += "[*]" if i < lvl else "[ ]"
	if lvl >= Balance.TOWER_UPGRADE_MAX_LEVEL:
		btn.text = "%s %s MAX" % [title, pips]
		btn.disabled = true
		btn.modulate = Color(0.75, 0.92, 0.78)
		_set_button_description(btn, "%s MAX (%d/%d): %s." % [title, Balance.TOWER_UPGRADE_MAX_LEVEL, Balance.TOWER_UPGRADE_MAX_LEVEL, desc_detail])
		return
	var cost: int = Balance.get_tower_upgrade_cost(key, lvl)
	var btime: int = int(Balance.TOWER_UPGRADE_BUILD_TIMES[lvl])
	var can_buy: bool = tower.can_start_upgrade(key)
	btn.text = "%s %s ($%d)" % [title, pips, cost]
	btn.disabled = not can_buy
	_set_button_description(btn, "Lvl %d/%d ($%d, %ds): %s. No fire while building." % [
		lvl + 1,
		Balance.TOWER_UPGRADE_MAX_LEVEL,
		cost,
		btime,
		desc_detail,
	])
	if money < cost:
		btn.modulate = Color(1.0, 0.65, 0.65)
	elif not can_buy:
		btn.modulate = Color(0.8, 0.8, 0.85)
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
	var eff_crawler_speed: float = GameState.get_effective_enemy_speed("crawler")
	var wstats: Dictionary = WavesData.compute_wave_stats(m.wave_number, GameState.get_enemy_hp_multiplier())
	var lines: PackedStringArray = [
		"[DEBUG F1]",
		"Clock: %.1f s (%.0fx) | Path: %.0f px | Active aliens: %d" % [GameState.mission_elapsed_seconds, GameState.game_speed, path_len, active_count],
		"Wave: %d (s$%d, b$%d, DPS req %d) | Lives: %d | Enemy Base: %d HP" % [m.wave_number, wstats["s_dollars"], wstats["b_dollars"], wstats["dps_needed"], m.lives, m.enemy_base_hp],
		"Money: $%d | Meta-Research: %d R | Refineries: %d" % [m.economy["money"], GameState.meta_research, m.economy["refineries_owned"]],
		"Crawler Speed: %.1f px/s (balance base: %.1f px/s)" % [eff_crawler_speed, Balance.ENEMIES["crawler"]["speed"]],
		"Surge Deadline: Wave %d (%.0fs left, %d surges) | Manip Lv%d" % [m.surge_deadline_wave, m.surge_timer_seconds, m.surge_count, m.manipulator_level],
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
	if map_ref == null:
		return
	if _selected_pad_idx >= 0 and _selected_pad_idx < map_ref.pad_occupancy.size() and map_ref.pad_occupancy[_selected_pad_idx] == null:
		map_ref.build_tower_on_pad(_selected_pad_idx, tower_type)
	elif map_ref.selected_drop_pos.x >= 0.0:
		var built: TowerUnit = map_ref.build_tower_in_zone(map_ref.selected_drop_pos, tower_type, map_ref.selected_zone_index)
		if built != null:
			map_ref.selected_drop_pos = Vector2(-1.0, -1.0)
	else:
		if map_ref.pending_build_type == tower_type:
			map_ref.set_pending_build_type("")
		else:
			map_ref.set_pending_build_type(tower_type)
		_refresh_selection_panel()


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


func _toggle_debug_panel() -> void:
	debug_panel.visible = not debug_panel.visible
	_refresh_all()


func _on_cycle_target_mode_pressed() -> void:
	if _selected_tower != null and is_instance_valid(_selected_tower):
		var new_mode: String = _selected_tower.cycle_target_mode()
		var tlabel: String = str(Balance.TARGETING_LABELS.get(new_mode, "First"))
		GameState.event_logged.emit("%s (P%d) target -> %s" % [
			Balance.TOWERS[_selected_tower.tower_type]["name"],
			_selected_tower.pad_index + 1,
			tlabel,
		])
		_refresh_selection_panel()


func _on_download_button_pressed() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.ttdOpenDownloads) window.ttdOpenDownloads();")
	else:
		GameState.event_logged.emit("Downloads & PWA Install: https://toxicw8st.github.io/time-defense/")


func _toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.ttdToggleLandscapeFullscreen) window.ttdToggleLandscapeFullscreen();")
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _get_effective_viewport_size() -> Vector2:
	if get_viewport() == null:
		return Vector2(Balance.VIEWPORT_WIDTH, Balance.VIEWPORT_HEIGHT)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	# Headless DisplayServer uses a square 1280x1280 dummy framebuffer under stretch/aspect="expand"
	if DisplayServer.get_name() == "headless" and is_equal_approx(vp_size.x, 1280.0) and is_equal_approx(vp_size.y, 1280.0):
		return Vector2(1280.0, 720.0)
	return vp_size


func _on_viewport_size_changed() -> void:
	apply_responsive_layout(_get_effective_viewport_size())


func _apply_bar_safe_margins(bar: PanelContainer, pad_x: float) -> void:
	if bar == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.14, 0.20, 0.96)
	sb.border_color = Color(0.26, 0.34, 0.48)
	sb.set_border_width_all(1)
	sb.content_margin_left = 6.0 + pad_x
	sb.content_margin_right = 6.0 + pad_x
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	bar.add_theme_stylebox_override("panel", sb)


func _set_bottom_button_widths(scale_mult: float) -> void:
	var base_widths := {
		rewind_button: 185.0,
		pause_button: 185.0,
		haste_button: 185.0,
		refinery_button: 170.0,
		charge_button: 195.0,
		start_wave_button: 145.0,
	}
	for btn in base_widths.keys():
		if btn != null:
			btn.custom_minimum_size.x = roundf(float(base_widths[btn]) * scale_mult)


func _center_overlay(ctrl: Control, vp_size: Vector2, default_size: Vector2) -> void:
	if ctrl == null:
		return
	var w: float = minf(default_size.x, vp_size.x - 24.0)
	var h: float = minf(default_size.y, vp_size.y - 24.0)
	ctrl.size = Vector2(w, h)
	ctrl.position = Vector2(floorf((vp_size.x - w) * 0.5), floorf((vp_size.y - h) * 0.5))


func apply_responsive_layout(vp_size: Vector2) -> void:
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var bg := get_parent().get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.position = Vector2.ZERO
		bg.size = vp_size

	# 1) Desktop / Standard 16:9 (1280x720) — preserve exact desktop coordinates & RightPanel (340x480)
	if vp_size.x <= 1285.0 and vp_size.y <= 725.0:
		_apply_bar_safe_margins(top_bar, -2.0)
		_apply_bar_safe_margins(bottom_bar, 2.0)
		_set_bottom_button_widths(1.0)
		top_bar.position = Vector2.ZERO
		top_bar.size = Vector2(1280.0, 64.0)
		bottom_bar.position = Vector2(0.0, 544.0)
		bottom_bar.size = Vector2(1280.0, 176.0)
		right_panel.custom_minimum_size = Vector2(340.0, 480.0)
		right_panel.position = Vector2(940.0, 64.0)
		right_panel.size = Vector2(340.0, 480.0)
		right_panel.set_deferred("size", Vector2(340.0, 480.0))
		if map_ref != null:
			map_ref.position = Vector2(0.0, 64.0)
			map_ref.scale = Vector2.ONE
			map_ref.set_viewport_margins(0.0, 0.0)
		surge_banner.position = Vector2(150.0, 68.0)
		surge_banner.size = Vector2(410.0, 42.0)
		prompt_banner.position = Vector2(572.0, 68.0)
		prompt_banner.size = Vector2(362.0, 54.0)
		pause_overlay.position = Vector2(240.0, 120.0)
		pause_overlay.size = Vector2(800.0, 400.0)
		between_levels_overlay.position = Vector2(220.0, 86.0)
		between_levels_overlay.size = Vector2(840.0, 444.0)
		end_overlay.position = Vector2(340.0, 150.0)
		end_overlay.size = Vector2(600.0, 360.0)
		if start_menu_overlay != null:
			start_menu_overlay.position = Vector2(180.0, 68.0)
			start_menu_overlay.size = Vector2(920.0, 560.0)
		debug_panel.position = Vector2(16.0, 74.0)
		return

	# 2) Pixel 11 Pro 20:9 Widescreen Landscape (e.g. 1600x720 / 1603x720)
	if vp_size.x >= vp_size.y:
		var top_h: float = 64.0
		var bot_h: float = 176.0
		var rp_w: float = 340.0
		var safe_x: float = clampf((vp_size.x - 1280.0) * 0.08, 0.0, 28.0)
		_apply_bar_safe_margins(top_bar, safe_x)
		_apply_bar_safe_margins(bottom_bar, safe_x)

		top_bar.position = Vector2.ZERO
		top_bar.size = Vector2(vp_size.x, top_h)

		bottom_bar.position = Vector2(0.0, vp_size.y - bot_h)
		_set_bottom_button_widths(clampf(vp_size.x / 1280.0, 1.0, 1.22))
		bottom_bar.size = Vector2(vp_size.x, bot_h)

		var middle_h: float = maxf(480.0, vp_size.y - top_h - bot_h)
		right_panel.custom_minimum_size = Vector2(rp_w, 480.0)
		right_panel.position = Vector2(vp_size.x - rp_w, top_h)
		right_panel.size = Vector2(rp_w, middle_h)

		var avail_w: float = maxf(GameMap.MAP_WIDTH, vp_size.x - rp_w)
		var avail_h: float = middle_h
		var map_scale: float = minf(avail_w / GameMap.MAP_WIDTH, avail_h / GameMap.MAP_HEIGHT)
		var extra_w: float = maxf(0.0, (avail_w / map_scale) - GameMap.MAP_WIDTH)
		var extra_left: float = floorf(extra_w * 0.5)
		var extra_right: float = extra_w - extra_left
		var map_y: float = top_h + floorf((avail_h - GameMap.MAP_HEIGHT * map_scale) * 0.5)
		if map_ref != null:
			map_ref.position = Vector2(extra_left * map_scale, map_y)
			map_ref.scale = Vector2(map_scale, map_scale)
			map_ref.set_viewport_margins(extra_left, extra_right)

		surge_banner.position = Vector2(safe_x + 12.0, top_h + 6.0)
		surge_banner.size = Vector2(410.0, 42.0)
		prompt_banner.position = Vector2(maxf(safe_x + 12.0, right_panel.position.x - 368.0), top_h + 6.0)
		prompt_banner.size = Vector2(362.0, 54.0)
		_center_overlay(pause_overlay, vp_size, Vector2(800.0, 400.0))
		_center_overlay(between_levels_overlay, vp_size, Vector2(840.0, 444.0))
		_center_overlay(end_overlay, vp_size, Vector2(600.0, 360.0))
		_center_overlay(start_menu_overlay, vp_size, Vector2(920.0, 560.0))
		debug_panel.position = Vector2(safe_x + 16.0, top_h + 10.0)
		return

	# 3) Pixel 11 Pro 9:20 Tall Portrait Fallback (e.g. 1280x2844 when Auto-Rotate is OFF)
	var safe_top: float = 36.0
	var safe_bot: float = 20.0
	var p_top_h: float = 72.0
	var p_bot_h: float = 184.0
	_apply_bar_safe_margins(top_bar, 6.0)
	_apply_bar_safe_margins(bottom_bar, 6.0)

	top_bar.position = Vector2(0.0, safe_top)
	top_bar.size = Vector2(vp_size.x, p_top_h)

	var p_scale: float = vp_size.x / GameMap.MAP_WIDTH
	var map_h: float = GameMap.MAP_HEIGHT * p_scale
	if map_ref != null:
		map_ref.position = Vector2(0.0, safe_top + p_top_h)
		map_ref.scale = Vector2(p_scale, p_scale)
		map_ref.set_viewport_margins(0.0, 0.0)

	var bot_y: float = vp_size.y - safe_bot - p_bot_h
	bottom_bar.position = Vector2(0.0, bot_y)
	_set_bottom_button_widths(clampf(vp_size.x / 1280.0, 0.85, 1.0))
	bottom_bar.size = Vector2(vp_size.x, p_bot_h)

	var rp_top: float = safe_top + p_top_h + map_h
	var rp_h: float = maxf(320.0, bot_y - rp_top)
	right_panel.custom_minimum_size = Vector2(0.0, 320.0)
	right_panel.position = Vector2(0.0, rp_top)
	right_panel.size = Vector2(vp_size.x, rp_h)

	surge_banner.position = Vector2(16.0, safe_top + p_top_h + 6.0)
	surge_banner.size = Vector2(minf(260.0, vp_size.x * 0.22), 42.0)
	prompt_banner.position = Vector2(maxf(16.0, vp_size.x - 378.0), safe_top + p_top_h + 6.0)
	prompt_banner.size = Vector2(362.0, 54.0)
	_center_overlay(pause_overlay, vp_size, Vector2(800.0, 400.0))
	_center_overlay(between_levels_overlay, vp_size, Vector2(840.0, 444.0))
	_center_overlay(end_overlay, vp_size, Vector2(600.0, 360.0))
	_center_overlay(start_menu_overlay, vp_size, Vector2(920.0, 560.0))
	debug_panel.position = Vector2(16.0, safe_top + p_top_h + 10.0)


func _on_selection_cleared() -> void:
	_selected_pad_idx = -1
	_selected_tower = null
	_tapped_info_button = null
	_sell_confirm_armed = false
	_refresh_selection_panel()
	_refresh_hover_info()


func _on_wave_summary_updated(summary_text: String) -> void:
	_last_summary_text = summary_text


func _on_wave_state_changed(_new_state: int) -> void:
	_check_teaching_prompt()
	_refresh_all()


func _populate_how_time_works() -> void:
	how_time_works_label.text = "\n".join([
		"HOW TIME WORKS:",
		"1. REWIND (BUILD phase): Replay previous wave once (no new mut); next NEW wave gets Armoured (+5% alien HP).",
		"2. PAUSE: Freeze aliens 8s while towers keep firing. Cost: Thaw-hardened (+5% HP next wave, -10% frozen dmg).",
		"3. HASTE: Towers +50% attack speed & +50% build speed for 30s. Cost: Swift (+5% alien speed).",
		"4. SURGE: Miss the 5-wave deadline (Wave 6 start) and all towers lose 5% attack speed for the rest of this mission.",
		"5. MANIPULATOR: Upgrading pauses Surge & locks powers/Base while building.",
		"6. WIN: Charge the Hive Destroyer ($450, 30s; Haste cannot speed it up) to destroy the Enemy Base.",
	])


func _check_teaching_prompt() -> void:
	if GameState.prompts_muted or GameState.mission.is_over or wave_manager_ref == null:
		return
	var w: int = GameState.mission.wave_number
	var st: int = wave_manager_ref.state
	var prompt_id: String = ""
	var text: String = ""

	if w == 1 and st == WaveManager.State.BUILD:
		prompt_id = "wave_1"
		text = "TIP (1/6): Spend ~90% of your $200 (2 towers) on pads beside the path, then press Start Wave."
	elif w == 2 and st == WaveManager.State.SPAWNING:
		prompt_id = "wave_2"
		text = "TIP (2/6): PAUSE freezes aliens 8s while towers keep firing. (Cost: Thaw-hardened +5% HP on future waves.)"
	elif w == 3 and st == WaveManager.State.BUILD:
		prompt_id = "wave_3"
		text = "TIP (3/6): SURGE DEADLINE is start of Wave 6. Use at least one time power every 5 waves or towers lose 5% speed."
	elif w == 4 and st == WaveManager.State.BUILD:
		prompt_id = "wave_4"
		text = "TIP (4/6): Match damage types: Laser (150% vs Standard), Piercing Blaster (180% vs Juggernaut), Chrono Slow + Decay."
	elif w == 5 and st == WaveManager.State.BUILD:
		prompt_id = "wave_5"
		text = "TIP (5/6): REWIND in BUILD phase replays previous wave (no new mut; +5% HP next wave). Spend Research in Levels/Lab."
	elif w == 6 and st == WaveManager.State.BUILD:
		prompt_id = "wave_6"
		text = "TIP (6/6): Win by destroying the Enemy Base (500 HP). Each Hive Destroyer shot costs $450 (30s charge, no Haste)."

	if prompt_id != "" and not GameState.mission.shown_prompts.get(prompt_id, false):
		GameState.mission.shown_prompts[prompt_id] = true
		prompt_label.text = text
		prompt_banner.visible = true


func _on_prompt_dismiss_pressed() -> void:
	prompt_banner.visible = false


func _on_prompt_mute_pressed() -> void:
	set_prompts_muted(true)


func _on_pause_mute_toggled(toggled_on: bool) -> void:
	set_prompts_muted(toggled_on)


func set_prompts_muted(muted: bool) -> void:
	GameState.prompts_muted = muted
	if pause_mute_check.button_pressed != muted:
		pause_mute_check.button_pressed = muted
	if muted:
		prompt_banner.visible = false


func _toggle_pause_menu() -> void:
	if GameState.mission.is_over:
		return
	var next_paused: bool = not pause_overlay.visible
	pause_overlay.visible = next_paused
	get_tree().paused = next_paused


func _on_pause_restart_pressed() -> void:
	pause_overlay.visible = false
	get_tree().paused = false
	_on_restart_pressed()


func _on_mission_ended(outcome: String, reason: String) -> void:
	end_overlay.visible = true
	if outcome == "won":
		end_title_label.text = "VICTORY - ENEMY BASE DESTROYED"
	elif outcome == "stalled":
		end_title_label.text = "MISSION STALLED - FINAL WAVE ENDED"
	else:
		end_title_label.text = "DEFEAT - BASE LOST"

	var m := GameState.mission
	var pct: int = int(round(pow(Balance.SURGE_ATTACK_SPEED_FACTOR, m.surge_count) * 100.0))
	end_stats_label.text = "\n".join([
		reason,
		"Mission Time: %.1f s | Wave: %d | Waves Cleared: %d" % [
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
		"Money Earned: $%d | Research Earned: %d R (Persistent Total: %d R) | Charges Fired: %d" % [
			m.stats["money_earned"],
			m.stats["research_earned"],
			GameState.meta_research,
			m.stats["charges_fired"],
		],
	])


func _on_mission_reset() -> void:
	end_overlay.visible = false
	surge_banner.visible = false
	prompt_banner.visible = false
	pause_overlay.visible = false
	get_tree().paused = false
	_banner_timer = 0.0
	_last_summary_text = ""
	_selected_pad_idx = -1
	_selected_tower = null
	_hovered_button = null
	_tapped_info_button = null
	_sell_confirm_armed = false
	_event_feed.clear()
	event_feed_label.text = "Events: (none yet)"
	_check_teaching_prompt()
	_refresh_hover_info()


func _on_start_wave_pressed() -> void:
	start_wave_requested.emit()


func _on_restart_pressed() -> void:
	GameState.reset_mission()
	restart_requested.emit()
