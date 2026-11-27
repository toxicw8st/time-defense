extends CanvasLayer

const GuidePortraitScript = preload("res://scripts/guide_portrait.gd")

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
@onready var research_list_box: VBoxContainer = $BetweenLevelsOverlay/Margin/VBox/ResearchScroll/ResearchButtons
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
@onready var how_time_works_label: Label = $PauseOverlay/Margin/VBox/HowScroll/HowTimeWorksLabel

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_label: Label = $DebugPanel/MarginContainer/DebugLabel

@onready var end_overlay: PanelContainer = $EndOverlay
@onready var end_title_label: Label = $EndOverlay/Margin/VBox/EndTitleLabel
@onready var end_stats_label: Label = $EndOverlay/Margin/VBox/StatsScroll/EndStatsLabel
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
var start_sandbox_button: Button = null
var start_lab_button: Button = null
var start_download_button: Button = null
var start_analytics_button: Button = null
var start_diff_buttons: Dictionary = {}
var lab_sandbox_button: Button = null
var pause_main_menu_button: Button = null
var pause_recipes_button: Button = null
var pause_analytics_button: Button = null
var pause_auto_wave_check: CheckBox = null
var pause_sfx_mute_check: CheckBox = null
var pause_dmg_popups_check: CheckBox = null
var end_main_menu_button: Button = null
var end_endless_button: Button = null
var end_analytics_button: Button = null

var combine_button: Button = null
var combine_partner_box: VBoxContainer = null
var _last_combine_list_sig: String = ""
var zoom_bar: PanelContainer = null
var zoom_out_button: Button = null
var zoom_reset_button: Button = null
var zoom_in_button: Button = null
var _active_touches: Dictionary = {}
var _pinch_prev_dist: float = 0.0
var _pinch_prev_mid: Vector2 = Vector2.ZERO
var _pan_pointer_active: bool = false
var _pan_is_middle: bool = false
var _pan_start_pos: Vector2 = Vector2.ZERO
var _pan_last_pos: Vector2 = Vector2.ZERO
var _is_panning_map: bool = false
var _pinch_zoom_changed: bool = false
var _last_wheel_log_sec: float = -10.0
var wave_intel_button: Button = null
var wave_intel_card: PanelContainer = null
var wave_intel_title_label: Label = null
var wave_intel_bounty_label: Label = null
var wave_intel_hide_button: Button = null
var wave_intel_roster_box: HFlowContainer = null
var wave_intel_tip_label: Label = null
var wave_intel_mut_label: Label = null
var _wave_intel_hidden_for_wave: int = -1
var _wave_intel_pinned_in_combat: bool = false
var _last_wave_intel_sig: String = ""
var comms_toast_panel: PanelContainer = null
var comms_speaker_label: Label = null
var comms_text_label: Label = null
var _comms_timer: float = 0.0
var _comms_cooldown: float = 0.0
var _comms_last_wave_banter: int = -1
var citadel_overlay: PanelContainer = null
var citadel_ability_cards: Dictionary = {}
var citadel_status_label: Label = null
var citadel_next_label: Label = null
var citadel_sac_box: VBoxContainer = null
var citadel_sac_preview_label: Label = null
var citadel_ascend_button: Button = null
var citadel_close_button: Button = null
var _selected_sacrifice_ids: Dictionary = {}
var _sacrifice_refinery_checked: bool = false
var refinery_tech_button: Button = null
var build_recipes_button: Button = null
var recipes_overlay: PanelContainer = null
var recipes_search_edit: LineEdit = null
var recipes_list_box: VBoxContainer = null
var analytics_overlay: PanelContainer = null
var analytics_include_sandbox_check: CheckBox = null
var analytics_kpi_label: Label = null
var analytics_recs_label: Label = null
var analytics_waves_label: Label = null
var analytics_towers_label: Label = null
var analytics_runs_label: Label = null
var analytics_status_label: Label = null
var analytics_reset_button: Button = null
var _analytics_reset_armed: bool = false
var enemy_inspector_panel: PanelContainer = null
var enemy_inspector_label: Label = null
var _inspected_enemy: EnemyUnit = null
var sandbox_toggle_button: Button = null
var sandbox_panel: PanelContainer = null
var sandbox_body_box: VBoxContainer = null
var sandbox_collapse_button: Button = null
var sandbox_fast_build_button: Button = null
var sandbox_wave_label: Label = null
var sandbox_qty_button: Button = null
var _sandbox_selected_wave: int = 1
var _sandbox_spawn_qty: int = 1
var _sandbox_collapsed: bool = false

# Witty Guide (Chrono-Commander Vex — Full-Screen Interposing Overlay) + Responsive Mobile Touch Grids
var guide_panel: Control = null
var guide_backdrop: ColorRect = null
var guide_speech_box: PanelContainer = null
var guide_tag_label: Label = null
var guide_portrait: Control = null
var guide_title_label: Label = null
var guide_body_label: Label = null
var guide_ack_button: Button = null
var guide_dismiss_button: Button = null
var _current_guide_beat: String = ""
var _guide_paused_game: bool = false

var auto_wave_button: Button = null
var build_buttons_grid: GridContainer = null
var tower_buttons_grid: GridContainer = null
var bottom_actions_grid: GridContainer = null
var top_controls_row: HBoxContainer = null
var start_level_grid: GridContainer = null
var start_action_grid: GridContainer = null
var pause_extra_grid: GridContainer = null
var analytics_btns_grid: GridContainer = null
var _right_scroll: ScrollContainer = null
var _last_scroll_log_sec: float = -10.0
var _current_layout_mode: String = "desktop"
var _drag_started_in_right_panel: bool = false
var _drag_is_touch: bool = false
var _seen_touch_input: bool = false
var force_touch_ui: bool = false
var _early_call_armed_timer: float = 0.0

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
	if guide_panel != null and _current_guide_beat != "startup":
		guide_panel.visible = false
		_current_guide_beat = ""
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
	speed_1x_button.text = "0.5x"
	speed_2x_button.text = "1x"
	speed_3x_button.text = "1.5x"
	speed_1x_button.pressed.connect(func() -> void: GameState.set_game_speed(Balance.SPEED_OPTION_SLOW))
	speed_2x_button.pressed.connect(func() -> void: GameState.set_game_speed(Balance.SPEED_OPTION_NORMAL))
	speed_3x_button.pressed.connect(func() -> void: GameState.set_game_speed(Balance.SPEED_OPTION_FAST))
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
	pause_mute_check.text = "Dismiss Guide (Vex)"
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
	_build_combine_and_sandbox_ui()
	_build_zoom_controls_ui()
	_build_wave_intel_ui()
	_build_comms_toast_ui()
	_build_citadel_overlay_ui()
	var surge_row_node := get_node_or_null("BottomBar/VBox/SurgeRow") as Control
	if surge_row_node != null:
		surge_row_node.visible = false
	_setup_responsive_grids()
	_build_guide_ui()
	_setup_right_panel_buttons()
	_hook_button_analytics(self)

	GameState.mission_ended.connect(_on_mission_ended)
	GameState.mission_reset.connect(_on_mission_reset)
	GameState.event_logged.connect(_on_event_logged)
	GameState.enemy_leaked.connect(_on_lives_lost_comms)
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
	if GameState.enemy_leaked.is_connected(_on_lives_lost_comms):
		GameState.enemy_leaked.disconnect(_on_lives_lost_comms)


func _reapply_overlay_bounds() -> void:
	if get_viewport() != null:
		apply_responsive_layout(_get_effective_viewport_size())


func open_start_menu() -> void:
	pause_overlay.visible = false
	end_overlay.visible = false
	between_levels_overlay.visible = false
	if recipes_overlay != null:
		recipes_overlay.visible = false
	if analytics_overlay != null:
		analytics_overlay.visible = false
	if citadel_overlay != null:
		citadel_overlay.visible = false
	_selected_sacrifice_ids.clear()
	_sacrifice_refinery_checked = false
	if enemy_inspector_panel != null:
		enemy_inspector_panel.visible = false
	_guide_paused_game = false
	get_tree().paused = false
	if start_menu_overlay != null:
		start_menu_overlay.visible = true
	if not GameState.prompts_muted and not GameState.guide_completed:
		show_guide_startup()
	_refresh_all()
	_reapply_overlay_bounds()
	call_deferred("_reapply_overlay_bounds")


func close_start_menu() -> void:
	if start_menu_overlay != null:
		start_menu_overlay.visible = false
	if guide_panel != null and _current_guide_beat == "startup":
		guide_panel.visible = false
		_current_guide_beat = ""
		_release_guide_pause()
	_check_teaching_prompt()
	_refresh_all()
	_reapply_overlay_bounds()


func open_between_levels_screen() -> void:
	end_overlay.visible = false
	if start_menu_overlay != null:
		start_menu_overlay.visible = false
	between_levels_overlay.visible = true
	_refresh_all()
	_reapply_overlay_bounds()
	call_deferred("_reapply_overlay_bounds")


func _toggle_between_levels_screen() -> void:
	between_levels_overlay.visible = not between_levels_overlay.visible
	_refresh_all()
	if between_levels_overlay.visible:
		_reapply_overlay_bounds()
		call_deferred("_reapply_overlay_bounds")


func _select_level(level_n: int) -> void:
	GameState.select_level(level_n)
	if map_ref != null and not GameState.is_wave_active and GameState.mission.wave_number == 1:
		map_ref.load_level(GameState.selected_map_level)
	_refresh_all()


func _launch_selected_level(sandbox_mode: bool = false) -> void:
	GameState.set_sandbox_mode(sandbox_mode)
	_sandbox_selected_wave = 1
	between_levels_overlay.visible = false
	if start_menu_overlay != null:
		start_menu_overlay.visible = false
	if map_ref != null:
		map_ref.load_level(GameState.selected_map_level)
	GameState.reset_mission()
	restart_requested.emit()
	_sandbox_collapsed = false
	if sandbox_panel != null:
		sandbox_panel.visible = sandbox_mode
	_refresh_sandbox_ui()


func _on_launch_level_pressed() -> void:
	_launch_selected_level(false)


func _build_start_menu() -> void:
	start_menu_overlay = PanelContainer.new()
	start_menu_overlay.name = "StartMenuOverlay"
	start_menu_overlay.visible = false
	start_menu_overlay.clip_contents = true
	start_menu_overlay.position = Vector2(180.0, 68.0)
	start_menu_overlay.size = Vector2(920.0, 560.0)
	start_menu_overlay.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.08, 0.14, 0.98), Color(0.38, 0.78, 1.0), 10, 6.0, 6.0))
	add_child(start_menu_overlay)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	start_menu_overlay.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "TIME DEFENSE: CHRONO COMMAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "SELECT MISSION SECTOR (LEVELS 1-5)  •  %s" % Balance.BALANCE_VERSION
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.86, 0.98))
	vbox.add_child(subtitle)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	start_level_grid = GridContainer.new()
	start_level_grid.name = "StartLevelGrid"
	start_level_grid.columns = 5
	start_level_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_level_grid.add_theme_constant_override("h_separation", 8)
	start_level_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(start_level_grid)

	var short_zone_tags: Dictionary = {
		1: "4 Rows | 3 Blasts",
		2: "3 Columns | 3 Blasts",
		3: "4 Islands | 4 Blasts",
		4: "4 Bastions | 4 Blasts",
		5: "5 Pillboxes | 5 Blasts",
	}
	start_level_buttons.clear()
	for lvl_id in range(1, 6):
		var lcfg: Dictionary = Balance.LEVELS[lvl_id]
		var lbtn := Button.new()
		lbtn.name = "StartLevel%dButton" % lvl_id
		lbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbtn.custom_minimum_size = Vector2(0, 48)
		lbtn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbtn.add_theme_font_size_override("font_size", 11)
		lbtn.text = "%s\n(%s)" % [lcfg["short_name"], str(short_zone_tags.get(lvl_id, lcfg["zone_type"]))]
		var captured_id: int = lvl_id
		lbtn.pressed.connect(func() -> void: _select_level(captured_id))
		UIIcons.apply_right_button_theme(lbtn, Color(0.32, 0.68, 0.96))
		start_level_grid.add_child(lbtn)
		start_level_buttons.append(lbtn)

	# Wrap briefing/description in a ScrollContainer so autowrap Labels can NEVER push the Play button below the screen!
	var body_scroll := ScrollContainer.new()
	body_scroll.name = "StartBodyScroll"
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(body_scroll)

	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_panel.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.08, 0.12, 0.20, 0.95), Color(0.28, 0.52, 0.78), 6, 12.0, 10.0))
	body_scroll.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_vbox)

	start_level_title_label = Label.new()
	start_level_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_level_title_label.add_theme_font_size_override("font_size", 14)
	start_level_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	info_vbox.add_child(start_level_title_label)

	start_level_desc_label = Label.new()
	start_level_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_level_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_level_desc_label.add_theme_font_size_override("font_size", 12)
	start_level_desc_label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	info_vbox.add_child(start_level_desc_label)

	var rules_lbl := Label.new()
	rules_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_lbl.add_theme_font_size_override("font_size", 11)
	rules_lbl.add_theme_color_override("font_color", Color(0.68, 0.84, 0.96))
	rules_lbl.text = "\n".join([
		"• DRAG & DROP PLACEMENT: Drag any tower from the right shop directly into the highlighted placement zones on the map.",
		"• BASE VISUAL ALERTS: Watch your Citadel for hull-fire/smoke (Almost Dead) vs growing electrical lightning buildup (Surge).",
		"• TIME POWERS & WIN CONDITION: Use Rewind, Pause, or Haste every 5 waves to discharge Surge. Charge Hive Destroyer ($450) to destroy the Alien Hive.",
	])
	info_vbox.add_child(rules_lbl)

	start_meta_label = Label.new()
	start_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_meta_label.add_theme_font_size_override("font_size", 12)
	start_meta_label.add_theme_color_override("font_color", Color(0.48, 0.92, 1.0))
	vbox.add_child(start_meta_label)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	vbox.add_child(diff_row)
	var diff_lbl := Label.new()
	diff_lbl.text = "DIFFICULTY:"
	diff_lbl.add_theme_font_size_override("font_size", 11)
	diff_lbl.add_theme_color_override("font_color", Color(0.75, 0.86, 0.96))
	diff_row.add_child(diff_lbl)
	start_diff_buttons.clear()
	for dk in Balance.DIFFICULTY_ORDER:
		var dcfg: Dictionary = Balance.DIFFICULTY_PRESETS[dk]
		var dbtn := Button.new()
		dbtn.name = "StartDiff_%s" % dk
		dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbtn.custom_minimum_size = Vector2(0, 30)
		dbtn.add_theme_font_size_override("font_size", 11)
		dbtn.text = str(dcfg["name"])
		var cap_dk: String = dk
		dbtn.pressed.connect(func() -> void:
			GameState.set_difficulty(cap_dk)
			if SfxManager != null:
				SfxManager.play("ui")
			_refresh_all()
		)
		var dcol := Color(0.32, 0.78, 0.62) if dk == "standard" else (Color(0.95, 0.68, 0.25) if dk == "hard" else Color(0.95, 0.35, 0.48))
		UIIcons.apply_right_button_theme(dbtn, dcol)
		diff_row.add_child(dbtn)
		start_diff_buttons[dk] = dbtn

	start_action_grid = GridContainer.new()
	start_action_grid.name = "StartActionGrid"
	start_action_grid.columns = 5
	start_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_action_grid.add_theme_constant_override("h_separation", 10)
	start_action_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(start_action_grid)

	start_play_button = Button.new()
	start_play_button.name = "StartPlayButton"
	start_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_play_button.custom_minimum_size = Vector2(0, 48)
	start_play_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_play_button.add_theme_font_size_override("font_size", 13)
	start_play_button.text = "LAUNCH LEVEL 1"
	start_play_button.pressed.connect(func() -> void:
		GameState.select_level(GameState.selected_map_level)
		_launch_selected_level(false)
	)
	UIIcons.apply_right_button_theme(start_play_button, Color(0.28, 0.88, 0.62))
	start_action_grid.add_child(start_play_button)

	start_sandbox_button = Button.new()
	start_sandbox_button.name = "StartSandboxButton"
	start_sandbox_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_sandbox_button.custom_minimum_size = Vector2(0, 48)
	start_sandbox_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_sandbox_button.add_theme_font_size_override("font_size", 12)
	start_sandbox_button.text = "SANDBOX (LV 1)"
	start_sandbox_button.pressed.connect(func() -> void:
		GameState.select_level(GameState.selected_map_level)
		_launch_selected_level(true)
	)
	UIIcons.apply_right_button_theme(start_sandbox_button, Color(0.95, 0.72, 0.25))
	start_action_grid.add_child(start_sandbox_button)

	start_lab_button = Button.new()
	start_lab_button.name = "StartLabButton"
	start_lab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_lab_button.custom_minimum_size = Vector2(0, 48)
	start_lab_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_lab_button.add_theme_font_size_override("font_size", 12)
	start_lab_button.text = "RESEARCH LAB (META-UPGRADES)"
	start_lab_button.pressed.connect(open_between_levels_screen)
	UIIcons.apply_right_button_theme(start_lab_button, Color(0.42, 0.72, 0.96))
	start_action_grid.add_child(start_lab_button)

	start_download_button = Button.new()
	start_download_button.name = "StartDownloadButton"
	start_download_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_download_button.custom_minimum_size = Vector2(128, 48)
	start_download_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_download_button.add_theme_font_size_override("font_size", 11)
	start_download_button.text = "INSTALL / APP"
	start_download_button.pressed.connect(_on_download_button_pressed)
	UIIcons.apply_right_button_theme(start_download_button, Color(0.68, 0.52, 0.95))
	start_action_grid.add_child(start_download_button)

	start_analytics_button = Button.new()
	start_analytics_button.name = "StartAnalyticsButton"
	start_analytics_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_analytics_button.custom_minimum_size = Vector2(124, 48)
	start_analytics_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_analytics_button.add_theme_font_size_override("font_size", 11)
	start_analytics_button.text = "ANALYTICS"
	start_analytics_button.pressed.connect(open_analytics_overlay)
	UIIcons.apply_right_button_theme(start_analytics_button, Color(0.28, 0.86, 0.96))
	start_action_grid.add_child(start_analytics_button)

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
		end_endless_button = Button.new()
		end_endless_button.name = "EndEndlessButton"
		end_endless_button.text = "Continue into Endless Mode (Wave 46+)"
		end_endless_button.visible = false
		end_endless_button.pressed.connect(func() -> void:
			end_overlay.visible = false
			GameState.continue_into_endless()
			_refresh_all()
		)
		UIIcons.apply_right_button_theme(end_endless_button, Color(0.78, 0.46, 1.0))
		end_vbox.add_child(end_endless_button)

		end_analytics_button = Button.new()
		end_analytics_button.name = "EndAnalyticsButton"
		end_analytics_button.text = "View Run Analytics & Export Data"
		end_analytics_button.pressed.connect(open_analytics_overlay)
		UIIcons.apply_right_button_theme(end_analytics_button, Color(0.28, 0.86, 0.96))
		end_vbox.add_child(end_analytics_button)

		end_main_menu_button = Button.new()
		end_main_menu_button.name = "EndMainMenuButton"
		end_main_menu_button.text = "Return to Main Menu (Select Level 1-5)"
		end_main_menu_button.pressed.connect(open_start_menu)
		UIIcons.apply_right_button_theme(end_main_menu_button, Color(0.42, 0.72, 0.96))
		end_vbox.add_child(end_main_menu_button)

	# Pause Overlay settings (Auto-Wave, Mute SFX, Crit Popups, 21 Recipes)
	var pause_vbox := get_node_or_null("PauseOverlay/Margin/VBox") as VBoxContainer
	if pause_vbox != null:
		pause_extra_grid = GridContainer.new()
		pause_extra_grid.name = "PauseExtraOptions"
		pause_extra_grid.columns = 5
		pause_extra_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pause_extra_grid.add_theme_constant_override("h_separation", 12)
		pause_extra_grid.add_theme_constant_override("v_separation", 8)
		pause_vbox.add_child(pause_extra_grid)
		pause_vbox.move_child(pause_extra_grid, pause_mute_check.get_index() + 1)

		pause_auto_wave_check = CheckBox.new()
		pause_auto_wave_check.name = "PauseAutoWaveCheck"
		pause_auto_wave_check.text = "Auto-Start Waves"
		pause_auto_wave_check.button_pressed = GameState.auto_wave_enabled
		pause_auto_wave_check.toggled.connect(func(on: bool) -> void:
			GameState.auto_wave_enabled = on
			GameState.save_meta_progress()
			_refresh_auto_wave_button()
		)
		pause_extra_grid.add_child(pause_auto_wave_check)

		pause_sfx_mute_check = CheckBox.new()
		pause_sfx_mute_check.name = "PauseSfxMuteCheck"
		pause_sfx_mute_check.text = "Mute SFX"
		pause_sfx_mute_check.button_pressed = SfxManager.muted if SfxManager != null else false
		pause_sfx_mute_check.toggled.connect(func(on: bool) -> void:
			if SfxManager != null:
				SfxManager.set_muted(on)
			GameState.save_meta_progress()
		)
		pause_extra_grid.add_child(pause_sfx_mute_check)

		pause_dmg_popups_check = CheckBox.new()
		pause_dmg_popups_check.name = "PauseDmgPopupsCheck"
		pause_dmg_popups_check.text = "Crit Popups"
		pause_dmg_popups_check.button_pressed = GameState.show_damage_numbers
		pause_dmg_popups_check.toggled.connect(func(on: bool) -> void:
			GameState.show_damage_numbers = on
			GameState.save_meta_progress()
		)
		pause_extra_grid.add_child(pause_dmg_popups_check)

		pause_recipes_button = Button.new()
		pause_recipes_button.name = "PauseRecipesButton"
		pause_recipes_button.text = "21 Recipes"
		pause_recipes_button.pressed.connect(func() -> void:
			if pause_overlay.visible:
				_toggle_pause_menu()
			open_recipes_overlay()
		)
		UIIcons.apply_right_button_theme(pause_recipes_button, Color(0.95, 0.78, 0.30))
		pause_extra_grid.add_child(pause_recipes_button)

		pause_analytics_button = Button.new()
		pause_analytics_button.name = "PauseAnalyticsButton"
		pause_analytics_button.text = "Analytics"
		pause_analytics_button.pressed.connect(func() -> void:
			if pause_overlay.visible:
				_toggle_pause_menu()
			open_analytics_overlay()
		)
		UIIcons.apply_right_button_theme(pause_analytics_button, Color(0.28, 0.86, 0.96))
		pause_extra_grid.add_child(pause_analytics_button)


func _build_combine_and_sandbox_ui() -> void:
	# 1) Add Combine button to TowerPanelBox (just above SellButton)
	if tower_panel_box != null and combine_button == null:
		combine_button = Button.new()
		combine_button.name = "CombineButton"
		combine_button.custom_minimum_size = Vector2(0, 32)
		combine_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		combine_button.add_theme_font_size_override("font_size", 11)
		combine_button.text = "Combine w/ Tower..."
		combine_button.pressed.connect(_on_combine_button_pressed)
		tower_panel_box.add_child(combine_button)
		if sell_button != null:
			tower_panel_box.move_child(combine_button, sell_button.get_index())

	# 1b) Add 21 Combo Recipes button to BuildMenuBox
	if build_menu_box != null and build_recipes_button == null:
		build_recipes_button = Button.new()
		build_recipes_button.name = "BuildRecipesButton"
		build_recipes_button.custom_minimum_size = Vector2(0, 28)
		build_recipes_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		build_recipes_button.add_theme_font_size_override("font_size", 11)
		build_recipes_button.text = "21 Combos & Apex Overdrives..."
		build_recipes_button.pressed.connect(open_recipes_overlay)
		build_menu_box.add_child(build_recipes_button)

	# 1b2) Add Refinery Tech Tier Upgrade button inside ManipulatorBox (BTD5 Banana Farm / Bank ladder!)
	var manip_box := get_node_or_null("RightPanel/Margin/VBox/Scroll/ContentVBox/ManipulatorBox") as VBoxContainer
	if manip_box != null and refinery_tech_button == null:
		refinery_tech_button = Button.new()
		refinery_tech_button.name = "RefineryTechButton"
		refinery_tech_button.custom_minimum_size = Vector2(0, 28)
		refinery_tech_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		refinery_tech_button.add_theme_font_size_override("font_size", 11)
		refinery_tech_button.text = "Refinery T2: Chrono-Plant ($550)"
		refinery_tech_button.pressed.connect(_on_refinery_tech_pressed)
		manip_box.add_child(refinery_tech_button)

	# 1c) Build In-Game 21-Combination Recipe Book Modal
	recipes_overlay = PanelContainer.new()
	recipes_overlay.name = "RecipesOverlay"
	recipes_overlay.visible = false
	recipes_overlay.clip_contents = true
	recipes_overlay.position = Vector2(150.0, 74.0)
	recipes_overlay.size = Vector2(980.0, 560.0)
	recipes_overlay.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.08, 0.14, 0.98), Color(0.95, 0.78, 0.30), 10, 10.0, 8.0))
	add_child(recipes_overlay)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 6)
	recipes_overlay.add_child(r_vbox)

	var r_top := HBoxContainer.new()
	r_top.add_theme_constant_override("separation", 8)
	r_vbox.add_child(r_top)

	var r_title := Label.new()
	r_title.text = "21 COMBINATIONS + TIER-4 PERKS & TIER-5 APEX OVERDRIVE (NEED 3+ UPGRADE RANKS TO FUSE)"
	r_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r_title.add_theme_font_size_override("font_size", 13)
	r_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	r_top.add_child(r_title)

	recipes_search_edit = LineEdit.new()
	recipes_search_edit.name = "RecipesSearchEdit"
	recipes_search_edit.custom_minimum_size = Vector2(210, 28)
	recipes_search_edit.placeholder_text = "Filter tower or role..."
	recipes_search_edit.text_changed.connect(func(_txt: String) -> void: _populate_recipes_list())
	r_top.add_child(recipes_search_edit)

	var r_close := Button.new()
	r_close.name = "RecipesCloseButton"
	r_close.custom_minimum_size = Vector2(78, 28)
	r_close.text = "Close"
	r_close.pressed.connect(func() -> void: recipes_overlay.visible = false)
	UIIcons.apply_right_button_theme(r_close, Color(0.95, 0.45, 0.45))
	r_top.add_child(r_close)

	var r_scroll := ScrollContainer.new()
	r_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	r_vbox.add_child(r_scroll)

	recipes_list_box = VBoxContainer.new()
	recipes_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipes_list_box.add_theme_constant_override("separation", 5)
	r_scroll.add_child(recipes_list_box)

	# 1c2) Build In-Game Playtest Analytics & Balance Telemetry Modal
	analytics_overlay = PanelContainer.new()
	analytics_overlay.name = "AnalyticsOverlay"
	analytics_overlay.visible = false
	analytics_overlay.clip_contents = true
	analytics_overlay.position = Vector2(140.0, 68.0)
	analytics_overlay.size = Vector2(1000.0, 570.0)
	analytics_overlay.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.08, 0.14, 0.98), Color(0.28, 0.88, 0.98), 10, 10.0, 8.0))
	add_child(analytics_overlay)

	var a_vbox := VBoxContainer.new()
	a_vbox.add_theme_constant_override("separation", 6)
	analytics_overlay.add_child(a_vbox)

	var a_top := HBoxContainer.new()
	a_top.add_theme_constant_override("separation", 8)
	a_vbox.add_child(a_top)

	var a_title := Label.new()
	a_title.text = "PLAYTEST ANALYTICS & REAL-DATA BALANCE TELEMETRY"
	a_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a_title.add_theme_font_size_override("font_size", 13)
	a_title.add_theme_color_override("font_color", Color(0.45, 0.94, 1.0))
	a_top.add_child(a_title)

	analytics_include_sandbox_check = CheckBox.new()
	analytics_include_sandbox_check.name = "AnalyticsIncludeSandboxCheck"
	analytics_include_sandbox_check.text = "Include Sandbox"
	analytics_include_sandbox_check.button_pressed = false
	analytics_include_sandbox_check.toggled.connect(func(_on: bool) -> void: _refresh_analytics_overlay())
	a_top.add_child(analytics_include_sandbox_check)

	var a_close := Button.new()
	a_close.name = "AnalyticsCloseButton"
	a_close.custom_minimum_size = Vector2(78, 28)
	a_close.text = "Close"
	a_close.pressed.connect(func() -> void: analytics_overlay.visible = false)
	UIIcons.apply_right_button_theme(a_close, Color(0.95, 0.45, 0.45))
	a_top.add_child(a_close)

	analytics_kpi_label = Label.new()
	analytics_kpi_label.name = "AnalyticsKpiLabel"
	analytics_kpi_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	analytics_kpi_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analytics_kpi_label.add_theme_font_size_override("font_size", 11)
	analytics_kpi_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	a_vbox.add_child(analytics_kpi_label)

	var a_scroll := ScrollContainer.new()
	a_scroll.name = "AnalyticsScroll"
	a_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	a_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	a_vbox.add_child(a_scroll)

	var a_body := VBoxContainer.new()
	a_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_body.add_theme_constant_override("separation", 8)
	a_scroll.add_child(a_body)

	analytics_recs_label = _make_analytics_section(a_body, "AUTOMATED BALANCE DIAGNOSTICS", Color(1.0, 0.76, 0.36))
	analytics_waves_label = _make_analytics_section(a_body, "WAVE LEAK HOTSPOTS & ECONOMY", Color(1.0, 0.56, 0.56))
	analytics_towers_label = _make_analytics_section(a_body, "TOWER & COMBINATION PERFORMANCE (DMG / $)", Color(0.45, 0.94, 0.74))
	analytics_runs_label = _make_analytics_section(a_body, "RECENT PLAYTEST RUNS", Color(0.68, 0.86, 1.0))

	analytics_status_label = Label.new()
	analytics_status_label.name = "AnalyticsStatusLabel"
	analytics_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	analytics_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analytics_status_label.add_theme_font_size_override("font_size", 11)
	analytics_status_label.add_theme_color_override("font_color", Color(0.62, 0.96, 0.72))
	analytics_status_label.text = "Play runs auto-save on every wave clear & mission end. Copy AI Report and paste into chat to rebalance from your data."
	a_vbox.add_child(analytics_status_label)

	analytics_btns_grid = GridContainer.new()
	analytics_btns_grid.name = "AnalyticsButtonsGrid"
	analytics_btns_grid.columns = 5
	analytics_btns_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	analytics_btns_grid.add_theme_constant_override("h_separation", 8)
	analytics_btns_grid.add_theme_constant_override("v_separation", 8)
	a_vbox.add_child(analytics_btns_grid)

	var btn_copy_ai := Button.new()
	btn_copy_ai.name = "AnalyticsCopyReportButton"
	btn_copy_ai.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_copy_ai.custom_minimum_size = Vector2(0, 34)
	btn_copy_ai.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_copy_ai.text = "Copy AI Report"
	btn_copy_ai.pressed.connect(func() -> void:
		if AnalyticsManager != null:
			AnalyticsManager.copy_report_to_clipboard(false)
			analytics_status_label.text = "Copied AI Balance Report to clipboard! Paste it directly in chat to tune towers & waves."
	)
	UIIcons.apply_right_button_theme(btn_copy_ai, Color(0.28, 0.88, 0.62))
	analytics_btns_grid.add_child(btn_copy_ai)

	var btn_copy_json := Button.new()
	btn_copy_json.name = "AnalyticsCopyJsonButton"
	btn_copy_json.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_copy_json.custom_minimum_size = Vector2(0, 34)
	btn_copy_json.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_copy_json.text = "Copy Raw JSON"
	btn_copy_json.pressed.connect(func() -> void:
		if AnalyticsManager != null:
			AnalyticsManager.copy_report_to_clipboard(true)
			analytics_status_label.text = "Copied full JSON telemetry payload to clipboard (importable into analytics.html)."
	)
	UIIcons.apply_right_button_theme(btn_copy_json, Color(0.38, 0.72, 0.98))
	analytics_btns_grid.add_child(btn_copy_json)

	var btn_dl_json := Button.new()
	btn_dl_json.name = "AnalyticsDownloadJsonButton"
	btn_dl_json.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dl_json.custom_minimum_size = Vector2(0, 34)
	btn_dl_json.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_dl_json.text = "Export .JSON"
	btn_dl_json.pressed.connect(func() -> void:
		if AnalyticsManager != null:
			analytics_status_label.text = AnalyticsManager.download_json_export()
	)
	UIIcons.apply_right_button_theme(btn_dl_json, Color(0.68, 0.54, 0.96))
	analytics_btns_grid.add_child(btn_dl_json)

	var btn_web_dash := Button.new()
	btn_web_dash.name = "AnalyticsOpenDashboardButton"
	btn_web_dash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_web_dash.custom_minimum_size = Vector2(0, 34)
	btn_web_dash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_web_dash.text = "Visual Dashboard"
	btn_web_dash.pressed.connect(func() -> void:
		if AnalyticsManager != null:
			if AnalyticsManager.open_web_dashboard():
				analytics_status_label.text = "Opened analytics.html visual dashboard in a new tab (auto-synced with localStorage)."
			else:
				analytics_status_label.text = "Open https://toxicw8st.github.io/time-defense/analytics.html and paste/drop your JSON export."
	)
	UIIcons.apply_right_button_theme(btn_web_dash, Color(0.95, 0.76, 0.28))
	analytics_btns_grid.add_child(btn_web_dash)

	analytics_reset_button = Button.new()
	analytics_reset_button.name = "AnalyticsResetButton"
	analytics_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	analytics_reset_button.custom_minimum_size = Vector2(116, 34)
	analytics_reset_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analytics_reset_button.text = "Reset Data"
	analytics_reset_button.pressed.connect(func() -> void:
		if not _analytics_reset_armed:
			_analytics_reset_armed = true
			analytics_reset_button.text = "Confirm Clear?"
			analytics_status_label.text = "Click Confirm Clear? again to wipe saved playtest analytics history."
			return
		_analytics_reset_armed = false
		analytics_reset_button.text = "Reset Data"
		if AnalyticsManager != null:
			AnalyticsManager.clear_analytics_history()
		analytics_status_label.text = "Cleared playtest analytics history."
		_refresh_analytics_overlay()
	)
	UIIcons.apply_right_button_theme(analytics_reset_button, Color(0.92, 0.42, 0.42))
	analytics_btns_grid.add_child(analytics_reset_button)

	# 1d) Build Floating Enemy Inspector Card (shown when tapping any active enemy on path)
	enemy_inspector_panel = PanelContainer.new()
	enemy_inspector_panel.name = "EnemyInspectorPanel"
	enemy_inspector_panel.visible = false
	enemy_inspector_panel.position = Vector2(12.0, 446.0)
	enemy_inspector_panel.size = Vector2(310.0, 90.0)
	enemy_inspector_panel.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.06, 0.10, 0.17, 0.94), Color(0.38, 0.90, 1.0), 8, 8.0, 6.0))
	add_child(enemy_inspector_panel)

	var ei_vbox := VBoxContainer.new()
	ei_vbox.add_theme_constant_override("separation", 3)
	enemy_inspector_panel.add_child(ei_vbox)

	enemy_inspector_label = Label.new()
	enemy_inspector_label.name = "EnemyInspectorLabel"
	enemy_inspector_label.add_theme_font_size_override("font_size", 11)
	enemy_inspector_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	ei_vbox.add_child(enemy_inspector_label)

	# 2) Add Launch Sandbox button inside BetweenLevelsOverlay BottomButtons
	var lab_bottom := get_node_or_null("BetweenLevelsOverlay/Margin/VBox/BottomButtons") as HBoxContainer
	if lab_bottom != null and lab_sandbox_button == null:
		lab_sandbox_button = Button.new()
		lab_sandbox_button.name = "LabSandboxButton"
		lab_sandbox_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab_sandbox_button.text = "Sandbox (Lv 1)"
		lab_sandbox_button.pressed.connect(func() -> void: _launch_selected_level(true))
		UIIcons.apply_right_button_theme(lab_sandbox_button, Color(0.95, 0.72, 0.25))
		lab_bottom.add_child(lab_sandbox_button)

	# 3) Add Sandbox toggle button in TopBar Row2 (visible when in Sandbox Mode)
	var top_row2 := get_node_or_null("TopBar/VBox/Row2") as HBoxContainer
	if top_row2 != null and sandbox_toggle_button == null:
		sandbox_toggle_button = Button.new()
		sandbox_toggle_button.name = "SandboxToggleButton"
		sandbox_toggle_button.custom_minimum_size = Vector2(90, 26)
		sandbox_toggle_button.add_theme_font_size_override("font_size", 11)
		sandbox_toggle_button.text = "Sandbox"
		sandbox_toggle_button.visible = false
		sandbox_toggle_button.pressed.connect(_toggle_sandbox_panel)
		UIIcons.apply_right_button_theme(sandbox_toggle_button, Color(0.96, 0.74, 0.24))
		top_row2.add_child(sandbox_toggle_button)
		if debug_button != null:
			top_row2.move_child(sandbox_toggle_button, debug_button.get_index())

	# 4) Build Floating Sandbox Tool Panel (hidden unless GameState.is_sandbox_mode)
	sandbox_panel = PanelContainer.new()
	sandbox_panel.name = "SandboxPanel"
	sandbox_panel.visible = false
	sandbox_panel.position = Vector2(12.0, 72.0)
	sandbox_panel.size = Vector2(292.0, 232.0)
	sandbox_panel.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.06, 0.09, 0.16, 0.94), Color(0.96, 0.74, 0.26), 8, 8.0, 6.0))
	add_child(sandbox_panel)

	var sb_vbox := VBoxContainer.new()
	sb_vbox.add_theme_constant_override("separation", 5)
	sandbox_panel.add_child(sb_vbox)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 6)
	sb_vbox.add_child(hdr_row)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "SANDBOX STUDIO ($INF)"
	hdr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_lbl.add_theme_font_size_override("font_size", 11)
	hdr_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	hdr_row.add_child(hdr_lbl)

	sandbox_fast_build_button = Button.new()
	sandbox_fast_build_button.name = "SandboxFastBuildButton"
	sandbox_fast_build_button.custom_minimum_size = Vector2(82, 24)
	sandbox_fast_build_button.add_theme_font_size_override("font_size", 10)
	sandbox_fast_build_button.text = "Instant: ON"
	sandbox_fast_build_button.pressed.connect(func() -> void:
		GameState.sandbox_instant_build = not GameState.sandbox_instant_build
		_refresh_sandbox_ui()
	)
	UIIcons.apply_right_button_theme(sandbox_fast_build_button, Color(0.35, 0.92, 0.68))
	hdr_row.add_child(sandbox_fast_build_button)

	sandbox_collapse_button = Button.new()
	sandbox_collapse_button.name = "SandboxCollapseButton"
	sandbox_collapse_button.custom_minimum_size = Vector2(28, 24)
	sandbox_collapse_button.add_theme_font_size_override("font_size", 11)
	sandbox_collapse_button.text = "-"
	sandbox_collapse_button.pressed.connect(func() -> void:
		_sandbox_collapsed = not _sandbox_collapsed
		_refresh_sandbox_ui()
	)
	UIIcons.apply_right_button_theme(sandbox_collapse_button, Color(0.55, 0.72, 0.92))
	hdr_row.add_child(sandbox_collapse_button)

	sandbox_body_box = VBoxContainer.new()
	sandbox_body_box.name = "SandboxBody"
	sandbox_body_box.add_theme_constant_override("separation", 5)
	sb_vbox.add_child(sandbox_body_box)

	# Wave Picker & Launch row
	var w_row := HBoxContainer.new()
	w_row.add_theme_constant_override("separation", 4)
	sandbox_body_box.add_child(w_row)

	var w_minus := Button.new()
	w_minus.name = "SandboxWavePrev"
	w_minus.custom_minimum_size = Vector2(30, 26)
	w_minus.add_theme_font_size_override("font_size", 11)
	w_minus.text = "-1"
	w_minus.pressed.connect(func() -> void: _adjust_sandbox_wave(-1))
	UIIcons.apply_right_button_theme(w_minus, Color(0.38, 0.68, 0.96))
	w_row.add_child(w_minus)

	sandbox_wave_label = Label.new()
	sandbox_wave_label.name = "SandboxWaveLabel"
	sandbox_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sandbox_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sandbox_wave_label.add_theme_font_size_override("font_size", 11)
	sandbox_wave_label.text = "Wave: 1"
	w_row.add_child(sandbox_wave_label)

	var w_plus := Button.new()
	w_plus.name = "SandboxWaveNext"
	w_plus.custom_minimum_size = Vector2(30, 26)
	w_plus.add_theme_font_size_override("font_size", 11)
	w_plus.text = "+1"
	w_plus.pressed.connect(func() -> void: _adjust_sandbox_wave(1))
	UIIcons.apply_right_button_theme(w_plus, Color(0.38, 0.68, 0.96))
	w_row.add_child(w_plus)

	var w_plus5 := Button.new()
	w_plus5.name = "SandboxWavePlus5"
	w_plus5.custom_minimum_size = Vector2(32, 26)
	w_plus5.add_theme_font_size_override("font_size", 11)
	w_plus5.text = "+5"
	w_plus5.pressed.connect(func() -> void: _adjust_sandbox_wave(5))
	UIIcons.apply_right_button_theme(w_plus5, Color(0.38, 0.68, 0.96))
	w_row.add_child(w_plus5)

	var w_run := Button.new()
	w_run.name = "SandboxRunWaveButton"
	w_run.custom_minimum_size = Vector2(78, 26)
	w_run.add_theme_font_size_override("font_size", 11)
	w_run.text = "RUN WAVE"
	w_run.pressed.connect(_on_sandbox_run_wave_pressed)
	UIIcons.apply_right_button_theme(w_run, Color(0.28, 0.88, 0.62))
	w_row.add_child(w_run)

	# Enemy Spawner buttons (2 compact rows)
	var sp_lbl := Label.new()
	sp_lbl.text = "Spawn Enemy (Wave Scale):"
	sp_lbl.add_theme_font_size_override("font_size", 10)
	sp_lbl.add_theme_color_override("font_color", Color(0.75, 0.86, 0.96))
	sandbox_body_box.add_child(sp_lbl)

	var sp_row1 := HBoxContainer.new()
	sp_row1.add_theme_constant_override("separation", 4)
	sandbox_body_box.add_child(sp_row1)
	for etype in ["crawler", "rusher", "brute"]:
		var eb := _make_sandbox_enemy_btn(etype)
		sp_row1.add_child(eb)

	var sp_row2 := HBoxContainer.new()
	sp_row2.add_theme_constant_override("separation", 4)
	sandbox_body_box.add_child(sp_row2)
	for etype in ["blitzer", "juggernaut", "colossus"]:
		var eb := _make_sandbox_enemy_btn(etype)
		sp_row2.add_child(eb)

	var sp_row2b := HBoxContainer.new()
	sp_row2b.add_theme_constant_override("separation", 4)
	sandbox_body_box.add_child(sp_row2b)
	for etype in ["stalker", "mender", "carrier", "conduit"]:
		var eb := _make_sandbox_enemy_btn(etype)
		sp_row2b.add_child(eb)

	var sp_row3 := HBoxContainer.new()
	sp_row3.add_theme_constant_override("separation", 4)
	sandbox_body_box.add_child(sp_row3)

	sandbox_qty_button = Button.new()
	sandbox_qty_button.name = "SandboxQtyButton"
	sandbox_qty_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sandbox_qty_button.custom_minimum_size = Vector2(0, 24)
	sandbox_qty_button.add_theme_font_size_override("font_size", 10)
	sandbox_qty_button.text = "Spawn Qty: x1"
	sandbox_qty_button.pressed.connect(func() -> void:
		_sandbox_spawn_qty = 5 if _sandbox_spawn_qty == 1 else 1
		_refresh_sandbox_ui()
	)
	UIIcons.apply_right_button_theme(sandbox_qty_button, Color(0.72, 0.56, 0.98))
	sp_row3.add_child(sandbox_qty_button)

	# Utility clear/exit row
	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 4)
	sandbox_body_box.add_child(util_row)

	var clr_e := Button.new()
	clr_e.name = "SandboxClearEnemies"
	clr_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr_e.custom_minimum_size = Vector2(0, 26)
	clr_e.add_theme_font_size_override("font_size", 10)
	clr_e.text = "Clear Foes"
	clr_e.pressed.connect(func() -> void:
		if map_ref != null:
			map_ref.sandbox_clear_enemies()
	)
	UIIcons.apply_right_button_theme(clr_e, Color(0.95, 0.52, 0.36))
	util_row.add_child(clr_e)

	var clr_t := Button.new()
	clr_t.name = "SandboxClearTowers"
	clr_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr_t.custom_minimum_size = Vector2(0, 26)
	clr_t.add_theme_font_size_override("font_size", 10)
	clr_t.text = "Clear Towers"
	clr_t.pressed.connect(func() -> void:
		if map_ref != null:
			map_ref.sandbox_clear_towers()
		_refresh_all()
	)
	UIIcons.apply_right_button_theme(clr_t, Color(0.95, 0.44, 0.44))
	util_row.add_child(clr_t)

	var rst_cd := Button.new()
	rst_cd.name = "SandboxResetCooldowns"
	rst_cd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rst_cd.custom_minimum_size = Vector2(0, 26)
	rst_cd.add_theme_font_size_override("font_size", 10)
	rst_cd.text = "Reset CDs"
	rst_cd.pressed.connect(func() -> void:
		if time_powers_ref != null:
			time_powers_ref.cooldowns = {"rewind": 0.0, "pause": 0.0, "haste": 0.0}
		GameState.mission.lives = Balance.PLAYER_STARTING_LIVES
		GameState.mission.surge_timer_seconds = Balance.SURGE_BASE_WINDOW
		_refresh_all()
	)
	UIIcons.apply_right_button_theme(rst_cd, Color(0.36, 0.84, 0.96))
	util_row.add_child(rst_cd)


func _make_sandbox_enemy_btn(enemy_type: String) -> Button:
	var b := Button.new()
	b.name = "SandboxSpawn_%s" % enemy_type
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_font_size_override("font_size", 10)
	b.text = str(Balance.ENEMIES[enemy_type]["name"]).replace("Phase ", "").replace("Bio-", "").replace("Brood ", "").replace("Aegis ", "")
	var captured: String = enemy_type
	b.pressed.connect(func() -> void:
		if map_ref != null:
			map_ref.sandbox_spawn_enemy(captured, _sandbox_selected_wave, _sandbox_spawn_qty)
			_refresh_all()
	)
	UIIcons.apply_right_button_theme(b, Color(0.95, 0.28, 0.48) if (enemy_type == "juggernaut" or enemy_type == "colossus") else Color(0.38, 0.62, 0.88))
	return b


func open_recipes_overlay() -> void:
	if recipes_overlay == null:
		return
	if analytics_overlay != null:
		analytics_overlay.visible = false
	if citadel_overlay != null:
		citadel_overlay.visible = false
	_selected_sacrifice_ids.clear()
	_sacrifice_refinery_checked = false
	if AnalyticsManager != null:
		AnalyticsManager.record_feature_used("recipes_opened")
	_populate_recipes_list()
	recipes_overlay.visible = true
	_reapply_overlay_bounds()
	call_deferred("_reapply_overlay_bounds")


func _make_analytics_section(parent_box: VBoxContainer, title_text: String, accent: Color) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.08, 0.12, 0.20, 0.96), accent, 6, 8.0, 6.0))
	parent_box.add_child(card)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var hdr := Label.new()
	hdr.text = title_text
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", accent)
	v.add_child(hdr)
	var body := Label.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	v.add_child(body)
	return body


func open_analytics_overlay() -> void:
	if analytics_overlay == null:
		return
	if recipes_overlay != null:
		recipes_overlay.visible = false
	_analytics_reset_armed = false
	if analytics_reset_button != null:
		analytics_reset_button.text = "Reset Data"
	_refresh_analytics_overlay()
	analytics_overlay.visible = true
	_reapply_overlay_bounds()
	call_deferred("_reapply_overlay_bounds")


func _refresh_analytics_overlay() -> void:
	if analytics_overlay == null or AnalyticsManager == null:
		return
	var inc_sb: bool = analytics_include_sandbox_check != null and analytics_include_sandbox_check.button_pressed
	var s: Dictionary = AnalyticsManager.compute_aggregate_summary(inc_sb)
	if analytics_kpi_label != null:
		var pu: Dictionary = s["powers_used"]
		var uc: Dictionary = s["upgrade_counts"]
		analytics_kpi_label.text = "Patch: %s  |  Runs: %d (W:%d L:%d)  |  Win%%: %.1f%%  |  Challenge: %.0f/100  |  KillPath: %.0f%% (Boss %.0f%%)  |  AvgSpd: %.2fx  |  Upg D:%d/R:%d/S:%d  |  Cloud: %s" % [
			str(s["balance_version"]), int(s["total_runs"]), int(s["wins"]), int(s["losses"]),
			float(s["win_rate_pct"]), float(s["avg_challenge_score"]), float(s["avg_kill_progress_pct"]), float(s["avg_boss_progress_pct"]),
			float(s["avg_game_speed"]), int(uc["damage"]), int(uc["range"]), int(uc["fire_rate"]), AnalyticsManager.cloud_sync_status,
		]
	if analytics_recs_label != null:
		var rlines: PackedStringArray = []
		for rec in s["recommendations"]:
			rlines.append("• " + str(rec))
		analytics_recs_label.text = "\n".join(rlines)
	if analytics_waves_label != null:
		var wlines: PackedStringArray = []
		var wh: Array = s["wave_hotspots"]
		var lim_w: int = mini(7, wh.size())
		if lim_w == 0:
			wlines.append("No wave telemetry recorded yet — clear or play a wave to populate path penetration, leak & cash data.")
		for i in range(lim_w):
			var h: Dictionary = wh[i]
			wlines.append("Wave %d  |  Plays: %d  |  Leaks: %d (%.0f%%)  |  Max Path: %.0f%%  |  Avg Cash End: $%.0f  |  Culprit: %s" % [
				int(h["wave"]), int(h["plays"]), int(h["leaks_total"]), float(h["leak_rate_pct"]), float(h["avg_max_pen_pct"]), float(h["avg_money_end"]),
				str(h["top_leaker"]) if str(h["top_leaker"]) != "" else "None",
			])
		analytics_waves_label.text = "\n".join(wlines)
	if analytics_towers_label != null:
		var tlines: PackedStringArray = []
		var tb: Array = s["tower_board"]
		var lim_t: int = mini(12, tb.size())
		if lim_t == 0:
			tlines.append("No tower combat data yet — build & fight waves to see per-tower Dmg/$, pick rate, and win rate.")
		for i in range(lim_t):
			var t: Dictionary = tb[i]
			var tag: String = "[COMBO] " if bool(t["is_combo"]) else ""
			tlines.append("%s%s  |  Built: %d  |  Spent: $%d  |  Dmg: %.0f  |  Kills: %d  |  %.1f Dmg/$  |  Pick: %.0f%%  |  WR: %.0f%%" % [
				tag, str(t["name"]), int(t["built"]), int(t["spent"]), float(t["damage"]), int(t["kills"]),
				float(t["dmg_per_dollar"]), float(t["pick_rate_pct"]), float(t["win_rate_pct"]),
			])
		analytics_towers_label.text = "\n".join(tlines)
	if analytics_runs_label != null:
		var all_r: Array = AnalyticsManager.get_all_runs_including_active()
		var run_lines: PackedStringArray = []
		var shown: int = 0
		for i in range(all_r.size() - 1, -1, -1):
			var r: Dictionary = all_r[i]
			if not inc_sb and bool(r.get("is_sandbox", false)):
				continue
			run_lines.append("[%s] Lv%d (%s%s) -> %s @ W%d  |  Lives: %d  |  HiveHP: %d  |  Shots: %d  |  Surges: %d  |  CashEnd: $%d" % [
				str(r.get("started_at", "")).substr(0, 16), int(r.get("level", 1)), str(r.get("difficulty", "standard")).capitalize(),
				" SANDBOX" if bool(r.get("is_sandbox", false)) else "", str(r.get("outcome", "")).to_upper(),
				int(r.get("max_wave_reached", 1)), int(r.get("lives_remaining", 0)), int(r.get("enemy_base_hp_remaining", 0)),
				int(r.get("charges_fired", 0)), int(r.get("surges_suffered", 0)), int(r.get("money_unspent_end", 0)),
			])
			shown += 1
			if shown >= 8:
				break
		if run_lines.is_empty():
			run_lines.append("No tracked runs yet.")
		analytics_runs_label.text = "\n".join(run_lines)


func _populate_recipes_list() -> void:
	if recipes_list_box == null:
		return
	for ch in recipes_list_box.get_children():
		recipes_list_box.remove_child(ch)
		ch.queue_free()
	var q: String = recipes_search_edit.text.strip_edges().to_lower() if recipes_search_edit != null else ""
	var bkeys: Array[String] = Balance.BASE_TOWER_KEYS
	for i in range(bkeys.size()):
		for j in range(i, bkeys.size()):
			var ck: String = Balance.get_combo_key(bkeys[i], bkeys[j])
			if not Balance.TOWERS.has(ck):
				continue
			var cfg: Dictionary = Balance.TOWERS[ck]
			var na: String = str(Balance.TOWERS[bkeys[i]]["name"])
			var nb: String = str(Balance.TOWERS[bkeys[j]]["name"])
			var cname: String = str(cfg["name"])
			var role: String = str(cfg["role"])
			var t4_cfg: Dictionary = Balance.get_combo_evolution_cfg(ck, 1)
			var t5_cfg: Dictionary = Balance.get_combo_evolution_cfg(ck, 2)
			var t4_txt: String = "T4 %s ($%d): %s" % [str(t4_cfg.get("name", "")), int(t4_cfg.get("cost", 0)), str(t4_cfg.get("desc", ""))]
			var t5_txt: String = "★ APEX T5 %s ($%d): %s" % [str(t5_cfg.get("name", "")), int(t5_cfg.get("cost", 0)), str(t5_cfg.get("desc", ""))]
			var hay: String = ("%s %s %s %s %s %s %s" % [na, nb, cname, role, str(cfg["damage_type_label"]), t4_txt, t5_txt]).to_lower()
			if q != "" and not hay.contains(q):
				continue
			var row := PanelContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var is_same: bool = (i == j)
			row.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.08, 0.12, 0.20, 0.96), Color(0.95, 0.78, 0.30) if is_same else Color(0.35, 0.66, 0.92), 6, 8.0, 5.0))
			var rv := VBoxContainer.new()
			rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rv.add_theme_constant_override("separation", 2)
			row.add_child(rv)
			var top_l := Label.new()
			top_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			top_l.add_theme_font_size_override("font_size", 12)
			top_l.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42) if is_same else Color(0.52, 0.94, 1.0))
			top_l.text = "%s + %s  =>  %s  (+$%d merge + sync | Rng %.0f | %.2f/s)" % [
				na, nb, cname, Balance.get_merge_surcharge(bkeys[i], bkeys[j]), float(cfg["range"]), float(cfg["fire_rate"])
			]
			rv.add_child(top_l)
			var desc_l := Label.new()
			desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_l.add_theme_font_size_override("font_size", 10)
			desc_l.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
			desc_l.text = "%s — %s" % [str(cfg["damage_type_label"]), role]
			rv.add_child(desc_l)
			var flav_l := Label.new()
			flav_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			flav_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			flav_l.add_theme_font_size_override("font_size", 10)
			flav_l.add_theme_color_override("font_color", Color(0.68, 0.92, 0.96))
			flav_l.text = "\"%s\"" % ComedyLines.get_tower_flavor(ck)
			rv.add_child(flav_l)
			if not t4_cfg.is_empty() and not t5_cfg.is_empty():
				var evo_l := Label.new()
				evo_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				evo_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				evo_l.add_theme_font_size_override("font_size", 10)
				evo_l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46))
				evo_l.text = "%s\n%s" % [t4_txt, t5_txt]
				rv.add_child(evo_l)
			recipes_list_box.add_child(row)
	if _current_layout_mode == "portrait":
		_scale_overlay_typography(recipes_list_box, true)


func _build_zoom_controls_ui() -> void:
	if zoom_bar != null:
		return
	zoom_bar = PanelContainer.new()
	zoom_bar.name = "ZoomControlsBar"
	zoom_bar.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.06, 0.10, 0.16, 0.92), Color(0.36, 0.72, 0.96), 8, 4.0, 3.0))
	add_child(zoom_bar)
	# Keep zoom pill tucked cleanly under overlays
	if surge_banner != null and surge_banner.get_parent() == self:
		move_child(zoom_bar, surge_banner.get_index())

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	zoom_bar.add_child(hb)

	zoom_out_button = Button.new()
	zoom_out_button.name = "ZoomOutButton"
	zoom_out_button.text = "−"
	zoom_out_button.tooltip_text = "Zoom Out (-)"
	zoom_out_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_out_button.pressed.connect(func() -> void: _step_map_zoom(-1))
	UIIcons.apply_right_button_theme(zoom_out_button, Color(0.42, 0.78, 1.0))
	hb.add_child(zoom_out_button)

	zoom_reset_button = Button.new()
	zoom_reset_button.name = "ZoomResetButton"
	zoom_reset_button.text = "1.0x"
	zoom_reset_button.tooltip_text = "Reset Battlefield Zoom (0) — Pinch or scroll wheel to zoom anytime!"
	zoom_reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_reset_button.pressed.connect(_reset_map_zoom)
	UIIcons.apply_right_button_theme(zoom_reset_button, Color(0.55, 0.85, 1.0))
	hb.add_child(zoom_reset_button)

	zoom_in_button = Button.new()
	zoom_in_button.name = "ZoomInButton"
	zoom_in_button.text = "+"
	zoom_in_button.tooltip_text = "Zoom In (+) onto battlefield or selected tower"
	zoom_in_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_in_button.pressed.connect(func() -> void: _step_map_zoom(1))
	UIIcons.apply_right_button_theme(zoom_in_button, Color(0.38, 0.95, 0.85))
	hb.add_child(zoom_in_button)


func _step_map_zoom(direction: int) -> void:
	if map_ref == null:
		return
	const STEPS: Array[float] = [1.0, 1.4, 1.85, 2.4]
	var cur: float = map_ref.user_zoom
	var target: float = cur
	if direction > 0:
		target = STEPS[STEPS.size() - 1]
		for s in STEPS:
			if s > cur + 0.06:
				target = s
				break
	else:
		target = STEPS[0]
		for i in range(STEPS.size() - 1, -1, -1):
			if STEPS[i] < cur - 0.06:
				target = STEPS[i]
				break
	if direction > 0 and _selected_tower != null and is_instance_valid(_selected_tower):
		map_ref.zoom_to_local_point(target, _selected_tower.position)
	else:
		map_ref.set_user_zoom(target)
	if AnalyticsManager != null:
		AnalyticsManager.record_zoom_event("button", map_ref.user_zoom)
	_refresh_zoom_controls()


func _reset_map_zoom() -> void:
	if map_ref != null:
		var was_z: bool = map_ref.user_zoom > 1.01
		map_ref.reset_user_zoom()
		if was_z and AnalyticsManager != null:
			AnalyticsManager.record_zoom_event("button", 1.0)
	_refresh_zoom_controls()


func _refresh_zoom_controls() -> void:
	if zoom_reset_button == null or map_ref == null:
		return
	var z: float = map_ref.user_zoom
	zoom_reset_button.text = "%.1fx" % z
	zoom_reset_button.modulate = Color(0.45, 0.98, 1.0) if z > 1.01 else Color.WHITE
	if zoom_out_button != null:
		zoom_out_button.disabled = (z <= 1.01)
	if zoom_in_button != null:
		zoom_in_button.disabled = (z >= GameMap.MAX_USER_ZOOM - 0.02)


func _build_wave_intel_ui() -> void:
	if wave_intel_card != null:
		return
	var row1: HBoxContainer = get_node_or_null("TopBar/VBox/Row1") as HBoxContainer
	if row1 != null and wave_intel_button == null:
		wave_intel_button = Button.new()
		wave_intel_button.name = "WaveIntelButton"
		wave_intel_button.text = "Next Wave ▾"
		wave_intel_button.tooltip_text = "Show / Hide detailed Next Wave Intel & counter tips"
		wave_intel_button.custom_minimum_size = Vector2(104.0, 24.0)
		wave_intel_button.add_theme_font_size_override("font_size", 11)
		wave_intel_button.pressed.connect(_toggle_wave_intel_card)
		UIIcons.apply_right_button_theme(wave_intel_button, Color(0.32, 0.86, 1.0))
		row1.add_child(wave_intel_button)

	wave_intel_card = PanelContainer.new()
	wave_intel_card.name = "NextWaveIntelCard"
	wave_intel_card.visible = false
	wave_intel_card.mouse_filter = Control.MOUSE_FILTER_STOP
	wave_intel_card.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.09, 0.16, 0.94), Color(0.35, 0.82, 1.0), 10, 10.0, 7.0))
	add_child(wave_intel_card)
	if surge_banner != null and surge_banner.get_parent() == self:
		move_child(wave_intel_card, surge_banner.get_index())

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 5)
	wave_intel_card.add_child(vb)

	var hdr_row := HBoxContainer.new()
	hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_theme_constant_override("separation", 8)
	vb.add_child(hdr_row)

	wave_intel_title_label = Label.new()
	wave_intel_title_label.name = "WaveIntelTitleLabel"
	wave_intel_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_intel_title_label.add_theme_font_size_override("font_size", 13)
	wave_intel_title_label.add_theme_color_override("font_color", Color(0.55, 0.96, 1.0))
	wave_intel_title_label.text = "NEXT: WAVE 1"
	hdr_row.add_child(wave_intel_title_label)

	wave_intel_bounty_label = Label.new()
	wave_intel_bounty_label.name = "WaveIntelBountyLabel"
	wave_intel_bounty_label.add_theme_font_size_override("font_size", 12)
	wave_intel_bounty_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
	wave_intel_bounty_label.text = "Reward: $80"
	hdr_row.add_child(wave_intel_bounty_label)

	wave_intel_hide_button = Button.new()
	wave_intel_hide_button.name = "WaveIntelHideButton"
	wave_intel_hide_button.text = "Hide ✕"
	wave_intel_hide_button.tooltip_text = "Hide Next Wave Intel for this wave (tap TopBar Intel button anytime to reopen)"
	wave_intel_hide_button.custom_minimum_size = Vector2(62.0, 24.0)
	wave_intel_hide_button.add_theme_font_size_override("font_size", 11)
	wave_intel_hide_button.pressed.connect(_on_wave_intel_hide_pressed)
	UIIcons.apply_right_button_theme(wave_intel_hide_button, Color(0.52, 0.66, 0.84))
	hdr_row.add_child(wave_intel_hide_button)

	wave_intel_roster_box = HFlowContainer.new()
	wave_intel_roster_box.name = "WaveIntelRosterBox"
	wave_intel_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_intel_roster_box.add_theme_constant_override("h_separation", 6)
	wave_intel_roster_box.add_theme_constant_override("v_separation", 4)
	vb.add_child(wave_intel_roster_box)

	wave_intel_tip_label = Label.new()
	wave_intel_tip_label.name = "WaveIntelTipLabel"
	wave_intel_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_intel_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_intel_tip_label.add_theme_font_size_override("font_size", 12)
	wave_intel_tip_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	wave_intel_tip_label.text = ""
	vb.add_child(wave_intel_tip_label)

	wave_intel_mut_label = Label.new()
	wave_intel_mut_label.name = "WaveIntelMutLabel"
	wave_intel_mut_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_intel_mut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_intel_mut_label.add_theme_font_size_override("font_size", 11)
	wave_intel_mut_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	wave_intel_mut_label.visible = false
	vb.add_child(wave_intel_mut_label)


func _toggle_wave_intel_card() -> void:
	if wave_manager_ref == null:
		return
	if wave_manager_ref.is_wave_active():
		_wave_intel_pinned_in_combat = not _wave_intel_pinned_in_combat
	else:
		var cur_w: int = GameState.mission.wave_number
		if _wave_intel_hidden_for_wave == cur_w:
			_wave_intel_hidden_for_wave = -1
		else:
			_wave_intel_hidden_for_wave = cur_w
	_last_wave_intel_sig = ""
	_refresh_wave_intel_card()


func _on_wave_intel_hide_pressed() -> void:
	if wave_manager_ref == null:
		return
	if wave_manager_ref.is_wave_active():
		_wave_intel_pinned_in_combat = false
	else:
		_wave_intel_hidden_for_wave = GameState.mission.wave_number
	_last_wave_intel_sig = ""
	_refresh_wave_intel_card()


func _get_enemy_trait_badge(utype: String) -> Dictionary:
	match utype:
		"crawler":
			return {"tag": "Standard", "color": Color(0.76, 0.88, 0.98)}
		"rusher":
			return {"tag": "Fast 2x", "color": Color(1.0, 0.92, 0.48)}
		"brute":
			return {"tag": "Armored", "color": Color(1.0, 0.76, 0.34)}
		"blitzer":
			return {"tag": "Refl 3x", "color": Color(0.58, 0.80, 1.0)}
		"juggernaut":
			return {"tag": "BOSS • Arm+Refl", "color": Color(1.0, 0.50, 0.28)}
		"colossus":
			return {"tag": "SIEGE BOSS", "color": Color(1.0, 0.36, 0.28)}
		"stalker":
			return {"tag": "CLOAKED • Refl", "color": Color(0.95, 0.45, 1.0)}
		"mender":
			return {"tag": "REGEN 6%/s", "color": Color(0.45, 1.0, 0.58)}
		"carrier":
			return {"tag": "SPLITS x6", "color": Color(1.0, 0.68, 0.28)}
		"conduit":
			return {"tag": "SHIELD -35%", "color": Color(0.38, 0.94, 1.0)}
		_:
			return {"tag": "Alien", "color": Color(0.85, 0.90, 0.96)}


func _build_wave_intel_tactical_tip(wave_num: int, counts: Dictionary) -> String:
	var tips: PackedStringArray = []
	if counts.has("stalker"):
		tips.append("CLOAKED ALERT: Normal Blasters/Mortars/Annihilators CANNOT SEE Phase Stalkers! Upgrade Range to Lv2 (+CAMO & +25% dmg), OR use Laser / Chrono Slow / Railgun.")
	if counts.has("conduit"):
		tips.append("SHIELD AURA: Aegis Conduits cut damage to nearby aliens by 35% — set a Railgun/Sniper to Strongest or use T4/T5 Shield-Strip!")
	if counts.has("colossus"):
		tips.append("SIEGE BOSS: Colossus costs 8♥ if leaked! Stack Piercing (180%), Railgun Decay, Tier-4/5 evolutions & PAUSE.")
	elif counts.has("juggernaut"):
		tips.append("BOSS WAVE: Each Juggernaut costs 5♥ if leaked! Stack Piercing (Blaster/Annihilator 180%), Chrono Slow bubbles & PAUSE.")
	if counts.has("carrier"):
		tips.append("SPLITTER: Brood Carriers burst into 2 Blitzers + 4 Rushers on death — pair Mortar/Splash AoE with Slow Bubbles!")
	if counts.has("mender"):
		tips.append("HEALER: Bio-Menders regen 6% HP/s — suppress regen with Chrono Decay, Laser+Slow Burn, or Armor Shred.")
	if tips.is_empty():
		if counts.has("blitzer"):
			tips.append("REFLECTIVE (3x speed): Blitzers bounce Lasers (only 10% dmg!) — counter with Piercing (Blaster/Annihilator) or Chrono Slow.")
		elif counts.has("brute"):
			tips.append("ARMORED BRUTES (3♥ each): Normal shells deal 50% — Piercing (Blaster/Railgun) deals 150% damage!")
		elif counts.has("rusher") and wave_num <= 4:
			tips.append("FAST SWARM (2x speed): Rushers sprint down lanes — Laser (150% vs Standard), Chrono Slow, or Mortar splash clear packs cleanly.")
		else:
			tips.append("STANDARD WAVE: Laser deals 150% vs Standard aliens. Upgrade base towers to 3+ combined ranks to Fuse them into stronger Combos!")
	return "HOW TO COUNTER: " + "  ".join(tips.slice(0, 2))


func _refresh_wave_intel_card() -> void:
	if wave_intel_card == null or wave_manager_ref == null:
		return
	var in_combat: bool = wave_manager_ref.is_wave_active()
	var max_w: int = wave_manager_ref.max_waves_limit
	var cur_w: int = GameState.mission.wave_number
	var target_w: int = (cur_w + 1) if in_combat else cur_w
	if not GameState.is_endless_mode:
		target_w = mini(target_w, max_w)
	var preview: Dictionary = wave_manager_ref.get_preview_data(target_w)
	var counts: Dictionary = preview["counts"]
	var exam_title: String = str(preview.get("exam_title", ""))
	var is_cloak_wave: bool = counts.has("stalker")
	var is_boss_wave: bool = counts.has("juggernaut") or counts.has("colossus") or exam_title != ""

	var new_enemies: Array[String] = []
	for utype in ["colossus", "juggernaut", "conduit", "carrier", "mender", "stalker", "blitzer", "brute", "rusher", "crawler"]:
		if counts.has(utype) and int(Balance.ENEMIES[utype].get("first_wave", 999)) == target_w and target_w > 1:
			new_enemies.append(utype)

	var overlay_blocked: bool = false
	for ov in [start_menu_overlay, pause_overlay, between_levels_overlay, end_overlay, recipes_overlay, analytics_overlay]:
		if ov != null and ov.visible:
			overlay_blocked = true
			break
	var should_show: bool = (not overlay_blocked) and (not GameState.mission.is_over) and (
		_wave_intel_pinned_in_combat if in_combat else (_wave_intel_hidden_for_wave != cur_w)
	)

	if wave_intel_button != null:
		var prefix_btn: String = "Next W%d" % target_w if in_combat else "W%d Intel" % target_w
		var alert_sym: String = " ⚠" if (is_cloak_wave or is_boss_wave or not new_enemies.is_empty()) else ""
		var arrow_sym: String = " ▴" if should_show else " ▾"
		wave_intel_button.text = "%s%s%s" % [prefix_btn, alert_sym, arrow_sym]
		if is_cloak_wave:
			wave_intel_button.modulate = Color(0.98, 0.58, 1.0)
		elif is_boss_wave:
			wave_intel_button.modulate = Color(1.0, 0.68, 0.34)
		elif not new_enemies.is_empty():
			wave_intel_button.modulate = Color(1.0, 0.90, 0.42)
		else:
			wave_intel_button.modulate = Color(0.75, 0.96, 1.0) if should_show else Color.WHITE

	wave_intel_card.visible = should_show
	if not should_show:
		return

	var muts: Array = preview["active_mutations"]
	var sig: String = "%d|%s|%s|%.3f|%d|%s" % [
		target_w,
		str(in_combat),
		_current_layout_mode,
		GameState.get_enemy_hp_multiplier(),
		muts.size(),
		GameState.difficulty_key,
	]
	if sig == _last_wave_intel_sig:
		return
	_last_wave_intel_sig = sig

	var is_port: bool = (_current_layout_mode == "portrait")
	var is_wide: bool = (_current_layout_mode == "landscape_wide")
	var border_col := Color(0.34, 0.80, 1.0)
	var title_col := Color(0.55, 0.96, 1.0)
	var heading_prefix: String = "UP NEXT: WAVE %d" % target_w if in_combat else "NEXT: WAVE %d" % target_w
	if is_cloak_wave and new_enemies.has("stalker"):
		heading_prefix += "  —  ⚠ NEW CLOAKED ENEMY!"
		border_col = Color(0.92, 0.42, 1.0)
		title_col = Color(1.0, 0.60, 1.0)
	elif exam_title != "":
		heading_prefix = "★ %s: %s" % [heading_prefix, exam_title]
		border_col = Color(1.0, 0.56, 0.24)
		title_col = Color(1.0, 0.78, 0.36)
	elif is_boss_wave:
		heading_prefix += "  —  ★ BOSS WAVE!"
		border_col = Color(1.0, 0.46, 0.28)
		title_col = Color(1.0, 0.68, 0.36)
	elif is_cloak_wave:
		heading_prefix += "  —  ⚠ CLOAKED THREAT"
		border_col = Color(0.88, 0.45, 1.0)
		title_col = Color(0.98, 0.62, 1.0)
	elif not new_enemies.is_empty():
		var first_new_name: String = str(Balance.ENEMIES[new_enemies[0]]["name"]).to_upper()
		heading_prefix += "  —  NEW ENEMY: %s!" % first_new_name
		border_col = Color(1.0, 0.82, 0.30)
		title_col = Color(1.0, 0.90, 0.45)

	wave_intel_card.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.09, 0.16, 0.94), border_col, 10, 12.0 if is_port else 10.0, 10.0 if is_port else 7.0))
	wave_intel_title_label.text = heading_prefix
	wave_intel_title_label.add_theme_color_override("font_color", title_col)
	wave_intel_title_label.add_theme_font_size_override("font_size", 21 if is_port else (14 if is_wide else 13))

	var est_bounty: int = int(round(float(preview.get("b_dollars", 0)) * GameState.get_enemy_bounty_multiplier()))
	wave_intel_bounty_label.text = "Reward: ~$%d" % est_bounty
	wave_intel_bounty_label.add_theme_font_size_override("font_size", 19 if is_port else (13 if is_wide else 12))
	wave_intel_hide_button.add_theme_font_size_override("font_size", 18 if is_port else (12 if is_wide else 11))
	wave_intel_hide_button.custom_minimum_size = Vector2(96.0, 40.0) if is_port else (Vector2(68.0, 28.0) if is_wide else Vector2(58.0, 24.0))

	for ch in wave_intel_roster_box.get_children():
		ch.queue_free()

	var icon_px: int = 36 if is_port else (26 if is_wide else 22)
	var chip_fs: int = 18 if is_port else (12 if is_wide else 11)
	var sub_fs: int = 15 if is_port else (10 if is_wide else 10)
	for utype in ["colossus", "juggernaut", "conduit", "carrier", "mender", "stalker", "blitzer", "brute", "rusher", "crawler"]:
		if not counts.has(utype):
			continue
		var cnt: int = int(counts[utype])
		var ecfg: Dictionary = Balance.ENEMIES[utype]
		var ename: String = str(ecfg["name"])
		var ehp: int = GameState.get_enemy_wave_hp(utype, target_w)
		var leak_c: int = int(ecfg.get("leak_cost", 1))
		var badge: Dictionary = _get_enemy_trait_badge(utype)
		var tcol: Color = badge["color"]
		var is_new_e: bool = new_enemies.has(utype)

		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UIIcons.make_panel_style(
			Color(0.11, 0.14, 0.24, 0.96) if is_new_e else Color(0.08, 0.12, 0.20, 0.92),
			Color(1.0, 0.86, 0.30) if is_new_e else tcol.darkened(0.25),
			7, 7.0, 4.0
		))
		var chb := HBoxContainer.new()
		chb.add_theme_constant_override("separation", 6)
		chip.add_child(chb)

		var e_icon: ImageTexture = SpriteLibrary.get_ui_badge_icon(utype, icon_px)
		if e_icon != null:
			var tr := TextureRect.new()
			tr.texture = e_icon
			tr.custom_minimum_size = Vector2(icon_px, icon_px)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chb.add_child(tr)

		var tvb := VBoxContainer.new()
		tvb.add_theme_constant_override("separation", 0)
		chb.add_child(tvb)

		var top_l := Label.new()
		top_l.text = ("%s%dx %s" % ["NEW! " if is_new_e else "", cnt, ename])
		top_l.add_theme_font_size_override("font_size", chip_fs)
		top_l.add_theme_color_override("font_color", Color(1.0, 0.94, 0.55) if is_new_e else Color.WHITE)
		tvb.add_child(top_l)

		var sub_l := Label.new()
		var leak_tag: String = (" • %d♥" % leak_c) if leak_c > 1 else ""
		sub_l.text = "%d HP • %s%s" % [ehp, str(badge["tag"]), leak_tag]
		sub_l.add_theme_font_size_override("font_size", sub_fs)
		sub_l.add_theme_color_override("font_color", tcol)
		tvb.add_child(sub_l)

		wave_intel_roster_box.add_child(chip)

	wave_intel_tip_label.text = _build_wave_intel_tactical_tip(target_w, counts)
	var headliner_e: String = ""
	if not new_enemies.is_empty():
		headliner_e = new_enemies[0]
	else:
		for ut in ["colossus", "juggernaut", "conduit", "carrier", "mender", "stalker", "blitzer", "brute", "rusher", "crawler"]:
			if counts.has(ut):
				headliner_e = ut
				break
	if headliner_e != "":
		wave_intel_tip_label.text += "\nFIELD NOTE (%s): \"%s\"" % [str(Balance.ENEMIES[headliner_e]["name"]), ComedyLines.get_enemy_flavor(headliner_e)]
	wave_intel_tip_label.add_theme_font_size_override("font_size", 18 if is_port else (12 if is_wide else 11))
	wave_intel_tip_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.98) if is_cloak_wave else Color(0.92, 0.97, 1.0))

	if muts.is_empty():
		wave_intel_mut_label.visible = false
	else:
		var m_parts: PackedStringArray = []
		for item in muts:
			m_parts.append("%s x%d (%s)" % [str(item["label"]), int(item["stacks"]), str(item["effect"])])
		wave_intel_mut_label.text = "⚠ Active Mutations: " + " | ".join(m_parts)
		wave_intel_mut_label.add_theme_font_size_override("font_size", 16 if is_port else 11)
		wave_intel_mut_label.visible = true
	wave_intel_card.reset_size()


func _build_comms_toast_ui() -> void:
	if comms_toast_panel != null:
		return
	comms_toast_panel = PanelContainer.new()
	comms_toast_panel.name = "ChronoCommsToast"
	comms_toast_panel.visible = false
	comms_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comms_toast_panel.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.08, 0.14, 0.90), Color(0.38, 0.92, 1.0), 8, 10.0, 6.0))
	add_child(comms_toast_panel)
	if surge_banner != null and surge_banner.get_parent() == self:
		move_child(comms_toast_panel, surge_banner.get_index())

	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 8)
	comms_toast_panel.add_child(hb)

	comms_speaker_label = Label.new()
	comms_speaker_label.name = "CommsSpeakerLabel"
	comms_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comms_speaker_label.add_theme_font_size_override("font_size", 12)
	comms_speaker_label.add_theme_color_override("font_color", Color(0.38, 0.96, 1.0))
	comms_speaker_label.text = "[VEX]"
	hb.add_child(comms_speaker_label)

	comms_text_label = Label.new()
	comms_text_label.name = "CommsTextLabel"
	comms_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comms_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comms_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comms_text_label.add_theme_font_size_override("font_size", 12)
	comms_text_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	comms_text_label.text = ""
	hb.add_child(comms_text_label)


func show_chrono_comms(category: String, force_priority: bool = false) -> void:
	if comms_toast_panel == null or comms_speaker_label == null or comms_text_label == null:
		return
	if start_menu_overlay != null and start_menu_overlay.visible:
		return
	if not force_priority and _comms_cooldown > 0.0:
		return
	var line: Dictionary = ComedyLines.pick_banter(category)
	if line.is_empty():
		return
	var scol: Color = line["color"]
	var is_port: bool = (_current_layout_mode == "portrait")
	comms_toast_panel.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.08, 0.14, 0.92), scol, 8, 12.0 if is_port else 10.0, 8.0 if is_port else 6.0))
	comms_speaker_label.text = "[%s]" % str(line["tag"])
	comms_speaker_label.add_theme_color_override("font_color", scol)
	comms_speaker_label.add_theme_font_size_override("font_size", 18 if is_port else 12)
	comms_text_label.text = str(line["text"])
	comms_text_label.add_theme_font_size_override("font_size", 18 if is_port else 12)
	comms_toast_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	comms_toast_panel.visible = true
	comms_toast_panel.reset_size()
	_reposition_comms_toast()
	_comms_timer = 5.4
	_comms_cooldown = 4.2


func _reposition_comms_toast() -> void:
	if comms_toast_panel == null or get_viewport() == null:
		return
	var vp_size: Vector2 = _get_effective_viewport_size()
	var toast_h: float = maxf(38.0, comms_toast_panel.get_combined_minimum_size().y)
	var inspector_lift: float = 104.0 if (enemy_inspector_panel != null and enemy_inspector_panel.visible) else 0.0
	if _current_layout_mode == "portrait":
		var tw_p: float = vp_size.x - 32.0
		comms_toast_panel.custom_minimum_size = Vector2(tw_p, 0.0)
		comms_toast_panel.position = Vector2(16.0, right_panel.position.y - toast_h - 10.0 - inspector_lift)
	elif _current_layout_mode == "landscape_wide":
		var safe_x: float = clampf((vp_size.x - 1280.0) * 0.06, 0.0, 24.0)
		var tw_l: float = minf(680.0, maxf(320.0, right_panel.position.x - safe_x - 24.0))
		comms_toast_panel.custom_minimum_size = Vector2(tw_l, 0.0)
		comms_toast_panel.position = Vector2(safe_x + 12.0, bottom_bar.position.y - toast_h - 8.0 - inspector_lift)
	else:
		var tw_d: float = 640.0
		comms_toast_panel.custom_minimum_size = Vector2(tw_d, 0.0)
		comms_toast_panel.position = Vector2(12.0, bottom_bar.position.y - toast_h - 8.0 - inspector_lift)


func _on_lives_lost_comms(_enemy_type: String, _amount: int, _world_pos: Vector2) -> void:
	if not GameState.mission.is_over:
		show_chrono_comms("leak", false)


func _build_citadel_overlay_ui() -> void:
	if citadel_overlay != null:
		return
	citadel_overlay = PanelContainer.new()
	citadel_overlay.name = "CitadelCommandOverlay"
	citadel_overlay.visible = false
	citadel_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	citadel_overlay.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.04, 0.07, 0.13, 0.97), Color(1.0, 0.86, 0.34), 12, 16.0, 12.0))
	add_child(citadel_overlay)

	var main_vb := VBoxContainer.new()
	main_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vb.add_theme_constant_override("separation", 8)
	citadel_overlay.add_child(main_vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	main_vb.add_child(hdr)

	var title_l := Label.new()
	title_l.text = "★ CHRONO-CITADEL ASCENSION & TIME ABILITY LAB"
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.add_theme_font_size_override("font_size", 17)
	title_l.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
	hdr.add_child(title_l)

	citadel_close_button = Button.new()
	citadel_close_button.name = "CitadelCloseButton"
	citadel_close_button.text = "Close ✕"
	citadel_close_button.custom_minimum_size = Vector2(96.0, 34.0)
	citadel_close_button.pressed.connect(func() -> void:
		citadel_overlay.visible = false
		_refresh_all()
	)
	UIIcons.apply_right_button_theme(citadel_close_button, Color(0.92, 0.45, 0.45))
	hdr.add_child(citadel_close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vb.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	# --- SECTION A: PAID TIME ABILITY UPGRADES (T1 -> T5) ---
	var ab_hdr := Label.new()
	ab_hdr.text = "TIME ABILITY UPGRADES (ZERO SURGE, ZERO MUTATIONS — PAY CASH TO CAST & UPGRADE T1→T5)"
	ab_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ab_hdr.add_theme_font_size_override("font_size", 12)
	ab_hdr.add_theme_color_override("font_color", Color(0.45, 0.96, 1.0))
	body.add_child(ab_hdr)

	var ab_row := HBoxContainer.new()
	ab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab_row.add_theme_constant_override("separation", 8)
	body.add_child(ab_row)

	for ak in ["pause", "haste", "rewind"]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_col := Color(0.36, 0.90, 1.0) if ak == "pause" else (Color(0.38, 1.0, 0.72) if ak == "haste" else Color(0.86, 0.50, 1.0))
		card.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.07, 0.11, 0.19, 0.95), card_col, 8, 9.0, 7.0))
		ab_row.add_child(card)

		var cvb := VBoxContainer.new()
		cvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cvb.add_theme_constant_override("separation", 4)
		card.add_child(cvb)

		var t_lbl := Label.new()
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_lbl.add_theme_font_size_override("font_size", 13)
		t_lbl.add_theme_color_override("font_color", card_col)
		cvb.add_child(t_lbl)

		var d_lbl := Label.new()
		d_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_lbl.add_theme_font_size_override("font_size", 11)
		d_lbl.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
		cvb.add_child(d_lbl)

		var u_btn := Button.new()
		u_btn.name = "UpgradeAbility_%s" % ak
		u_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		u_btn.custom_minimum_size = Vector2(0.0, 38.0)
		var captured_k: String = ak
		u_btn.pressed.connect(func() -> void:
			if time_powers_ref != null and time_powers_ref.upgrade_ability(captured_k):
				_refresh_citadel_overlay()
				_refresh_all()
		)
		UIIcons.apply_right_button_theme(u_btn, card_col)
		cvb.add_child(u_btn)

		citadel_ability_cards[ak] = {"title": t_lbl, "desc": d_lbl, "btn": u_btn}

	var sep := HSeparator.new()
	body.add_child(sep)

	# --- SECTION B: 3-STAGE CHRONO-CITADEL ASCENSION ("SUN GOD") + OPT-IN SACRIFICE PICKER ---
	var cit_hdr := Label.new()
	cit_hdr.text = "CHRONO-CITADEL ASCENSION (AWAKEN YOUR BASE INTO AN ENDGAME SUPER-WEAPON!)"
	cit_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cit_hdr.add_theme_font_size_override("font_size", 13)
	cit_hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
	body.add_child(cit_hdr)

	citadel_status_label = Label.new()
	citadel_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	citadel_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	citadel_status_label.add_theme_font_size_override("font_size", 12)
	citadel_status_label.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
	body.add_child(citadel_status_label)

	citadel_next_label = Label.new()
	citadel_next_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	citadel_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	citadel_next_label.add_theme_font_size_override("font_size", 12)
	citadel_next_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
	body.add_child(citadel_next_label)

	citadel_sac_box = VBoxContainer.new()
	citadel_sac_box.name = "CitadelSacrificeBox"
	citadel_sac_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	citadel_sac_box.add_theme_constant_override("separation", 4)
	body.add_child(citadel_sac_box)

	citadel_sac_preview_label = Label.new()
	citadel_sac_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	citadel_sac_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	citadel_sac_preview_label.add_theme_font_size_override("font_size", 12)
	citadel_sac_preview_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.82))
	body.add_child(citadel_sac_preview_label)

	citadel_ascend_button = Button.new()
	citadel_ascend_button.name = "CitadelAscendButton"
	citadel_ascend_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	citadel_ascend_button.custom_minimum_size = Vector2(0.0, 48.0)
	citadel_ascend_button.add_theme_font_size_override("font_size", 15)
	citadel_ascend_button.pressed.connect(_on_citadel_ascend_pressed)
	UIIcons.apply_right_button_theme(citadel_ascend_button, Color(1.0, 0.84, 0.28), true)
	body.add_child(citadel_ascend_button)


func open_citadel_overlay() -> void:
	if citadel_overlay == null:
		return
	_selected_sacrifice_ids.clear()
	_sacrifice_refinery_checked = false
	citadel_overlay.visible = true
	_refresh_citadel_overlay()
	_reapply_overlay_bounds()
	call_deferred("_reapply_overlay_bounds")


func _get_chosen_sacrifice_towers() -> Array:
	var out: Array = []
	if map_ref == null:
		return out
	for t in map_ref.get_all_towers():
		if t != null and is_instance_valid(t) and bool(_selected_sacrifice_ids.get(t.tower_id, false)):
			out.append(t)
	return out


func _refresh_citadel_overlay() -> void:
	if citadel_overlay == null or not citadel_overlay.visible:
		return
	var money: int = GameState.mission.economy["money"]
	# 1) Refresh Time Ability T1->T5 upgrade cards
	for ak in ["pause", "haste", "rewind"]:
		var card: Dictionary = citadel_ability_cards[ak]
		var ab: Dictionary = Balance.TIME_ABILITIES[ak]
		var cur_t: int = GameState.get_ability_level(ak)
		var cur_cfg: Dictionary = Balance.get_time_ability_tier_cfg(ak, cur_t)
		(card["title"] as Label).text = "%s [T%d/5] (Cast $%d)" % [str(ab["name"]), cur_t, int(ab["cast_cost"])]
		var btn: Button = card["btn"]
		if cur_t >= Balance.TIME_ABILITY_MAX_TIER:
			(card["desc"] as Label).text = "MAX %s: %s" % [str(cur_cfg["title"]), str(cur_cfg["desc"])]
			btn.text = "★ MAX TIER 5"
			btn.disabled = true
			btn.modulate = Color(0.55, 1.0, 0.80)
		else:
			var nxt_cfg: Dictionary = Balance.get_time_ability_tier_cfg(ak, cur_t + 1)
			var ucost: int = int(nxt_cfg["upgrade_cost"])
			(card["desc"] as Label).text = "Now: %s\nNext T%d (%s): %s" % [
				str(cur_cfg["desc"]), cur_t + 1, str(nxt_cfg["title"]), str(nxt_cfg["desc"])
			]
			var can_u: bool = time_powers_ref != null and time_powers_ref.can_upgrade_ability(ak)
			btn.text = "UPGRADE T%d ($%d)" % [cur_t + 1, ucost]
			btn.disabled = not can_u
			btn.modulate = Color(0.65, 1.0, 0.85) if can_u else Color(1.0, 0.65, 0.65)

	# 2) Refresh Chrono-Citadel Ascension status & opt-in sacrifice picker
	var m := GameState.mission
	var stage: int = m.citadel_stage
	var grafted: PackedStringArray = []
	for sk in ["kinetic", "explosive", "energy", "chrono", "economy"]:
		var sl: int = int(m.citadel_sacrifices.get(sk, 0))
		if sl > 0:
			grafted.append("%s%s" % [str(Balance.CITADEL_SACRIFICES[sk]["name"]), " ★HYPER" if sl >= 2 else ""])
	var graft_txt: String = ", ".join(grafted) if not grafted.is_empty() else "None yet (Stage 2+ unlocks Sacrifices)"
	var stage_name: String = "Unawakened Base (Stage 0)" if stage == 0 else ("Stage %d: %s" % [stage, str(Balance.CITADEL_STAGES[stage]["name"])])
	citadel_status_label.text = "Current: %s  |  Citadel Dmg: %d  |  Kills: %d  |  Global Spd Aura: +%d%%\nGrafted Super-Weapons: %s" % [
		stage_name, int(round(m.citadel_total_damage)), m.citadel_total_kills,
		int(round(GameState.get_citadel_global_speed_bonus() * 100.0)), graft_txt
	]

	for ch in citadel_sac_box.get_children():
		ch.queue_free()

	var nxt_stage: int = base_attack_ref.get_next_citadel_stage() if base_attack_ref != null else -1
	if nxt_stage < 0:
		citadel_next_label.text = "★ MAXIMUM ASCENSION REACHED — TRUE CHRONO-SINGULARITY ONLINE!"
		citadel_sac_preview_label.text = ""
		citadel_ascend_button.text = "★ TRUE CHRONO-SINGULARITY MAX"
		citadel_ascend_button.disabled = true
		citadel_ascend_button.modulate = Color(1.0, 0.90, 0.42)
		return

	var scfg: Dictionary = Balance.CITADEL_STAGES[nxt_stage]
	var scost: int = int(scfg["cost"])
	citadel_next_label.text = "NEXT -> Stage %d: %s ($%d) — %s" % [nxt_stage, str(scfg["name"]), scost, str(scfg["desc"])]

	if bool(scfg.get("supports_sacrifice", false)) and map_ref != null and base_attack_ref != null:
		var sac_hdr := Label.new()
		sac_hdr.text = "OPTIONAL SUN-GOD SACRIFICES (Toggle placed towers to absorb; $%d+ in a category grafts its permanent super-weapon!):" % Balance.CITADEL_SACRIFICE_THRESHOLD
		sac_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sac_hdr.add_theme_font_size_override("font_size", 11)
		sac_hdr.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40))
		citadel_sac_box.add_child(sac_hdr)

		var t_flow := HFlowContainer.new()
		t_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_flow.add_theme_constant_override("h_separation", 6)
		t_flow.add_theme_constant_override("v_separation", 4)
		citadel_sac_box.add_child(t_flow)

		var built_towers: Array[TowerUnit] = map_ref.get_all_towers()
		if built_towers.is_empty():
			var empty_l := Label.new()
			empty_l.text = "(No placed towers to sacrifice yet — you can still ascend without sacrifices!)"
			empty_l.add_theme_font_size_override("font_size", 11)
			t_flow.add_child(empty_l)
		else:
			for t in built_towers:
				if not t.is_built:
					continue
				var cb := CheckBox.new()
				var cats: Array[String] = Balance.get_tower_sacrifice_categories(t.tower_type)
				cb.text = "%s ($%d • %s)" % [str(Balance.TOWERS[t.tower_type]["name"]), t.total_spent, "+".join(cats).to_upper()]
				cb.button_pressed = bool(_selected_sacrifice_ids.get(t.tower_id, false))
				cb.add_theme_font_size_override("font_size", 11)
				var tid: int = t.tower_id
				cb.toggled.connect(func(on: bool) -> void:
					_selected_sacrifice_ids[tid] = on
					_update_sacrifice_preview_text()
				)
				t_flow.add_child(cb)

		if int(m.economy.get("refineries_owned", 0)) >= 1:
			var rcb := CheckBox.new()
			rcb.text = "Sacrifice 1 Refinery for Chrono-Mint Core (+$350/w, +$700/w at S3)"
			rcb.button_pressed = _sacrifice_refinery_checked
			rcb.add_theme_font_size_override("font_size", 11)
			rcb.toggled.connect(func(on: bool) -> void:
				_sacrifice_refinery_checked = on
				_update_sacrifice_preview_text()
			)
			citadel_sac_box.add_child(rcb)

		_update_sacrifice_preview_text()
	else:
		citadel_sac_preview_label.text = "Stage 1 deploys directly — no sacrifices required! (Stage 2 & 3 unlock optional Sun-God Sacrifices.)"

	var can_asc: bool = base_attack_ref != null and base_attack_ref.can_ascend_citadel()
	citadel_ascend_button.text = "★ ASCEND TO STAGE %d: %s ($%d)" % [nxt_stage, str(scfg["name"]).to_upper(), scost]
	citadel_ascend_button.disabled = not can_asc
	citadel_ascend_button.modulate = Color(1.0, 0.94, 0.48) if can_asc else Color(1.0, 0.65, 0.65)
	if not can_asc and not GameState.is_sandbox_mode:
		citadel_ascend_button.text += "  [Need $%d more]" % maxi(0, scost - money)


func _update_sacrifice_preview_text() -> void:
	if base_attack_ref == null or citadel_sac_preview_label == null:
		return
	var chosen: Array = _get_chosen_sacrifice_towers()
	var prev: Dictionary = base_attack_ref.preview_sacrifice_unlocks(chosen, _sacrifice_refinery_checked)
	var spent: Dictionary = prev["spent_by_cat"]
	var unl: Dictionary = prev["unlocked"]
	var lines: PackedStringArray = ["LIVE SACRIFICE WEAPON PREVIEW (%d tower(s) selected):" % chosen.size()]
	for c in ["kinetic", "explosive", "energy", "chrono"]:
		var cfg_c: Dictionary = Balance.CITADEL_SACRIFICES[c]
		var ok: bool = bool(unl.get(c, false))
		lines.append("  %s %s ($%d/$%d) -> %s" % [
			"✓ UNLOCKED:" if ok else "•",
			c.to_upper(), int(spent.get(c, 0)), Balance.CITADEL_SACRIFICE_THRESHOLD,
			str(cfg_c["name"]) if ok else str(cfg_c["source_hint"]),
		])
	var eco_ok: bool = bool(unl.get("economy", false))
	lines.append("  %s ECONOMY -> %s" % [
		"✓ UNLOCKED:" if eco_ok else "•",
		str(Balance.CITADEL_SACRIFICES["economy"]["name"]) if eco_ok else str(Balance.CITADEL_SACRIFICES["economy"]["source_hint"]),
	])
	citadel_sac_preview_label.text = "\n".join(lines)


func _on_citadel_ascend_pressed() -> void:
	if base_attack_ref == null:
		return
	var chosen: Array = _get_chosen_sacrifice_towers()
	if base_attack_ref.ascend_citadel(chosen, _sacrifice_refinery_checked):
		_selected_sacrifice_ids.clear()
		_sacrifice_refinery_checked = false
		_refresh_citadel_overlay()
		_refresh_all()


func _is_any_blocking_overlay_visible() -> bool:
	for ov in [start_menu_overlay, pause_overlay, between_levels_overlay, end_overlay, recipes_overlay, analytics_overlay, citadel_overlay, guide_panel]:
		if ov != null and ov.visible:
			return true
	return false


func _is_point_in_battlefield_open(screen_pos: Vector2) -> bool:
	if map_ref == null or _is_any_blocking_overlay_visible():
		return false
	if not map_ref.get_viewport_rect_screen().has_point(screen_pos):
		return false
	for hud_ctrl in [top_bar, bottom_bar, right_panel, zoom_bar, wave_intel_card, sandbox_panel, debug_panel, enemy_inspector_panel]:
		if hud_ctrl != null and hud_ctrl.visible and hud_ctrl.get_global_rect().has_point(screen_pos):
			return false
	return true


func _build_guide_ui() -> void:
	# Full-screen interposing overlay: dims the entire battlefield and brings Chrono-Commander Vex
	# in at ~1/4 of the viewport beside/above a bold tactical speech callout box.
	guide_panel = Control.new()
	guide_panel.name = "GuidePanel"
	guide_panel.visible = false
	guide_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	guide_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	guide_panel.position = Vector2.ZERO
	guide_panel.size = Vector2(Balance.VIEWPORT_WIDTH, Balance.VIEWPORT_HEIGHT)
	add_child(guide_panel)

	guide_backdrop = ColorRect.new()
	guide_backdrop.name = "GuideBackdrop"
	guide_backdrop.color = Color(0.02, 0.05, 0.11, 0.74)
	guide_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	guide_backdrop.position = Vector2.ZERO
	guide_backdrop.size = Vector2(Balance.VIEWPORT_WIDTH, Balance.VIEWPORT_HEIGHT)
	guide_panel.add_child(guide_backdrop)

	guide_portrait = GuidePortraitScript.new()
	guide_portrait.name = "GuidePortrait"
	guide_portrait.process_mode = Node.PROCESS_MODE_ALWAYS
	guide_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_portrait.position = Vector2(28.0, 178.0)
	guide_portrait.size = Vector2(400.0, 520.0)
	guide_panel.add_child(guide_portrait)

	guide_speech_box = PanelContainer.new()
	guide_speech_box.name = "GuideSpeechBox"
	guide_speech_box.clip_contents = true
	guide_speech_box.position = Vector2(440.0, 270.0)
	guide_speech_box.size = Vector2(804.0, 360.0)
	guide_speech_box.add_theme_stylebox_override("panel", UIIcons.make_panel_style(Color(0.05, 0.10, 0.19, 0.97), Color(0.32, 0.94, 1.0), 14, 22.0, 18.0))
	guide_panel.add_child(guide_speech_box)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	guide_speech_box.add_child(vbox)

	guide_tag_label = Label.new()
	guide_tag_label.name = "GuideTagLabel"
	guide_tag_label.add_theme_font_size_override("font_size", 11)
	guide_tag_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	guide_tag_label.text = "◀  INCOMING CHRONO-TRANSMISSION  //  COMBAT PAUSED"
	vbox.add_child(guide_tag_label)

	guide_title_label = Label.new()
	guide_title_label.name = "GuideTitleLabel"
	guide_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_title_label.add_theme_font_size_override("font_size", 19)
	guide_title_label.add_theme_color_override("font_color", Color(0.42, 0.96, 1.0))
	guide_title_label.text = "CHRONO-COMMANDER VEX"
	vbox.add_child(guide_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var gscroll := ScrollContainer.new()
	gscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(gscroll)

	guide_body_label = Label.new()
	guide_body_label.name = "GuideBodyLabel"
	guide_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_body_label.add_theme_font_size_override("font_size", 17)
	guide_body_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	gscroll.add_child(guide_body_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	guide_ack_button = Button.new()
	guide_ack_button.name = "GuideAckButton"
	guide_ack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_ack_button.custom_minimum_size = Vector2(0, 50)
	guide_ack_button.add_theme_font_size_override("font_size", 16)
	guide_ack_button.text = "Got It!"
	guide_ack_button.pressed.connect(_on_guide_ack_pressed)
	UIIcons.apply_right_button_theme(guide_ack_button, Color(0.28, 0.88, 0.65))
	btn_row.add_child(guide_ack_button)

	guide_dismiss_button = Button.new()
	guide_dismiss_button.name = "GuideDismissButton"
	guide_dismiss_button.custom_minimum_size = Vector2(180, 50)
	guide_dismiss_button.add_theme_font_size_override("font_size", 15)
	guide_dismiss_button.text = "Dismiss Vex"
	guide_dismiss_button.pressed.connect(_on_guide_dismiss_all_pressed)
	UIIcons.apply_right_button_theme(guide_dismiss_button, Color(0.92, 0.45, 0.45))
	btn_row.add_child(guide_dismiss_button)


func _setup_responsive_grids() -> void:
	_right_scroll = get_node_or_null("RightPanel/Margin/VBox/Scroll") as ScrollContainer
	if _right_scroll != null:
		var vbar: VScrollBar = _right_scroll.get_v_scroll_bar()
		if vbar != null:
			vbar.value_changed.connect(func(_val: float) -> void:
				var now_sec: float = float(Time.get_ticks_msec()) * 0.001
				if now_sec - _last_scroll_log_sec >= 0.65:
					_last_scroll_log_sec = now_sec
					if AnalyticsManager != null:
						AnalyticsManager.record_ui_scroll()
			)

	# 1) Build shop 1-col (desktop/landscape) <-> 2-col touch grid (portrait)
	if build_menu_box != null and build_buttons_grid == null:
		build_buttons_grid = GridContainer.new()
		build_buttons_grid.name = "BuildButtonsGrid"
		build_buttons_grid.columns = 1
		build_buttons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build_buttons_grid.add_theme_constant_override("h_separation", 6)
		build_buttons_grid.add_theme_constant_override("v_separation", 4)
		build_menu_box.add_child(build_buttons_grid)
		var shop_btns: Array[Button] = [
			build_blaster_button, build_mortar_button, build_laser_button,
			build_slow_button, build_railgun_button, build_annihilator_button,
		]
		if build_recipes_button != null:
			shop_btns.append(build_recipes_button)
		for b in shop_btns:
			if b != null and b.get_parent() != null:
				b.reparent(build_buttons_grid)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 2) Selected tower actions 1-col (desktop/landscape) <-> 2-col touch grid (portrait)
	if tower_panel_box != null and tower_buttons_grid == null:
		tower_buttons_grid = GridContainer.new()
		tower_buttons_grid.name = "TowerButtonsGrid"
		tower_buttons_grid.columns = 1
		tower_buttons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tower_buttons_grid.add_theme_constant_override("h_separation", 6)
		tower_buttons_grid.add_theme_constant_override("v_separation", 4)
		tower_panel_box.add_child(tower_buttons_grid)
		var t_btns: Array[Button] = [
			upg_dmg_button, upg_spd_button, upg_rng_button,
		]
		if combine_button != null:
			t_btns.append(combine_button)
		t_btns.append(target_mode_button)
		t_btns.append(sell_button)
		for b in t_btns:
			if b != null and b.get_parent() != null:
				b.reparent(tower_buttons_grid)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 2b) Inline 1-tap Combine Partner Picker right inside TowerPanelBox (no fat-finger map taps required!)
	if tower_panel_box != null and combine_partner_box == null:
		combine_partner_box = VBoxContainer.new()
		combine_partner_box.name = "CombinePartnerBox"
		combine_partner_box.visible = false
		combine_partner_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		combine_partner_box.add_theme_constant_override("separation", 5)
		tower_panel_box.add_child(combine_partner_box)

	# 3) Bottom bar actions 6-col (1 row desktop/landscape) <-> 3-col (2 chunky rows portrait)
	var bot_vbox := get_node_or_null("BottomBar/VBox") as VBoxContainer
	var old_row2 := get_node_or_null("BottomBar/VBox/Row2") as HBoxContainer
	if bot_vbox != null and old_row2 != null and bottom_actions_grid == null:
		bottom_actions_grid = GridContainer.new()
		bottom_actions_grid.name = "BottomActionsGrid"
		bottom_actions_grid.columns = 6
		bottom_actions_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_actions_grid.add_theme_constant_override("h_separation", 8)
		bottom_actions_grid.add_theme_constant_override("v_separation", 8)
		bot_vbox.add_child(bottom_actions_grid)
		bot_vbox.move_child(bottom_actions_grid, old_row2.get_index())
		for b in [rewind_button, pause_button, haste_button, refinery_button, charge_button, start_wave_button]:
			if b != null and b.get_parent() != null:
				b.reparent(bottom_actions_grid)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		old_row2.visible = false

	# 4) Dedicated Portrait Row 3 inside TopBar so speed + utility buttons get chunky thumb targets without overflowing 1280px
	var top_vbox := get_node_or_null("TopBar/VBox") as VBoxContainer
	if top_vbox != null and top_controls_row == null:
		top_controls_row = HBoxContainer.new()
		top_controls_row.name = "PortraitControlsRow"
		top_controls_row.visible = false
		top_controls_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_controls_row.add_theme_constant_override("separation", 8)
		top_vbox.add_child(top_controls_row)

	# 5) One-tap Auto-Wave toggle right on TopBar (eliminates 45 repetitive Start Wave taps on phone!)
	var top_row2 := get_node_or_null("TopBar/VBox/Row2") as HBoxContainer
	if top_row2 != null and auto_wave_button == null:
		auto_wave_button = Button.new()
		auto_wave_button.name = "AutoWaveButton"
		auto_wave_button.custom_minimum_size = Vector2(56, 26)
		auto_wave_button.add_theme_font_size_override("font_size", 10)
		auto_wave_button.text = "Auto:OFF"
		auto_wave_button.tooltip_text = "Auto-Start Waves between rounds (toggle in 1 tap)."
		auto_wave_button.pressed.connect(_on_auto_wave_button_pressed)
		UIIcons.apply_right_button_theme(auto_wave_button, Color(0.36, 0.68, 0.90))
		top_row2.add_child(auto_wave_button)
		if level_picker_button != null and level_picker_button.get_parent() == top_row2:
			top_row2.move_child(auto_wave_button, level_picker_button.get_index())


func _hook_button_analytics(root: Node) -> void:
	if root is BaseButton:
		var btn: BaseButton = root as BaseButton
		if not btn.has_meta("_td_analytics_hooked"):
			btn.set_meta("_td_analytics_hooked", true)
			var bname: String = btn.name
			btn.pressed.connect(func() -> void:
				if AnalyticsManager != null:
					AnalyticsManager.record_button_press(bname, false)
			)
			btn.gui_input.connect(func(ev: InputEvent) -> void:
				if not btn.disabled:
					return
				var pressed_ev: bool = (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and ev.device != InputEvent.DEVICE_ID_EMULATION)
				if pressed_ev and AnalyticsManager != null:
					AnalyticsManager.record_button_press(bname, true)
			)
	for ch in root.get_children():
		_hook_button_analytics(ch)


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
	if combine_button != null:
		_init_styled_button(combine_button, _icons["target"], Color(1.0, 0.82, 0.30))
	if build_recipes_button != null:
		_init_styled_button(build_recipes_button, _icons["target"], Color(0.95, 0.78, 0.30))
		_set_button_description(build_recipes_button, "Browse all 21 tower recipes, costs, and synergy roles.")
	_init_styled_button(manip_upgrade_button, _icons["manipulator"], Color(0.68, 0.52, 0.95))
	if refinery_tech_button != null:
		_init_styled_button(refinery_tech_button, _icons["sell"], Color(0.35, 0.88, 0.65))

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
	elif _selected_tower != null and is_instance_valid(_selected_tower):
		hover_info_label.text = "\"%s\"" % ComedyLines.get_tower_flavor(_selected_tower.tower_type)
		hover_info_label.modulate = Color(0.70, 0.94, 0.98)
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
		map_ref.enemy_inspected.connect(_on_enemy_inspected)
		map_ref.citadel_clicked.connect(open_citadel_overlay)
	if wave_manager_ref != null:
		wave_manager_ref.wave_summary_updated.connect(_on_wave_summary_updated)
		wave_manager_ref.state_changed.connect(_on_wave_state_changed)
	if surge_ref != null:
		surge_ref.surge_banner_triggered.connect(_on_surge_banner_triggered)
	if time_powers_ref != null:
		time_powers_ref.power_activated.connect(func(pname: String) -> void: show_chrono_comms(pname, true))
		time_powers_ref.ability_upgraded.connect(func(_pk: String, _nt: int) -> void: show_chrono_comms("ability_upgrade", true))
	if base_attack_ref != null:
		base_attack_ref.citadel_ascended.connect(func(st: int, _sacs: Dictionary) -> void:
			show_chrono_comms("citadel_s%d" % clampi(st, 1, 3), true)
		)
	if get_viewport() != null:
		apply_responsive_layout(_get_effective_viewport_size())
	_check_teaching_prompt()
	_refresh_all()


func _connect_tower_drag(btn: Button, tower_type: String) -> void:
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if GameState.mission.is_over:
			return
		var cost: int = int(Balance.TOWERS[tower_type]["cost"])
		if not GameState.is_sandbox_mode and GameState.mission.economy["money"] < cost:
			return
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_drag_candidate_type = tower_type
			_drag_start_screen_pos = ev.global_position
			_drag_started_in_right_panel = right_panel.get_global_rect().has_point(ev.global_position)
			_drag_is_touch = false
			_is_dragging_tower = false
		elif ev is InputEventScreenTouch and ev.pressed:
			var gpos: Vector2 = btn.get_global_transform_with_canvas() * ev.position
			_drag_candidate_type = tower_type
			_drag_start_screen_pos = gpos
			_drag_started_in_right_panel = right_panel.get_global_rect().has_point(gpos)
			_drag_is_touch = true
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
	if event is InputEventScreenTouch and event.pressed and not _seen_touch_input:
		_seen_touch_input = true
		if _current_layout_mode == "desktop":
			call_deferred("_reapply_overlay_bounds")
	if event is InputEventKey and event.pressed and not event.echo:
		if guide_panel != null and guide_panel.visible and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
			_on_guide_ack_pressed()
			get_viewport().set_input_as_handled()
			return
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
		elif not _is_any_blocking_overlay_visible():
			if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
				_step_map_zoom(1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
				_step_map_zoom(-1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_0 or event.keycode == KEY_KP_0:
				_reset_map_zoom()
				get_viewport().set_input_as_handled()
		return

	# Battlefield Zoom & Pan Gestures (Wheel Zoom, 2-Finger Pinch-to-Zoom, 1-Finger / Drag-to-Pan when zoomed)
	if map_ref != null and _drag_candidate_type == "" and not _is_dragging_tower and not _is_any_blocking_overlay_visible():
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and _is_point_in_battlefield_open(event.position):
				map_ref.set_user_zoom(map_ref.user_zoom * 1.18, event.position)
				_refresh_zoom_controls()
				var now_w1: float = float(Time.get_ticks_msec()) * 0.001
				if now_w1 - _last_wheel_log_sec >= 0.6 and AnalyticsManager != null:
					_last_wheel_log_sec = now_w1
					AnalyticsManager.record_zoom_event("wheel", map_ref.user_zoom)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _is_point_in_battlefield_open(event.position):
				map_ref.set_user_zoom(map_ref.user_zoom / 1.18, event.position)
				_refresh_zoom_controls()
				var now_w2: float = float(Time.get_ticks_msec()) * 0.001
				if now_w2 - _last_wheel_log_sec >= 0.6 and AnalyticsManager != null:
					_last_wheel_log_sec = now_w2
					AnalyticsManager.record_zoom_event("wheel", map_ref.user_zoom)
				get_viewport().set_input_as_handled()
				return
			elif (event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and map_ref.user_zoom > 1.01)) and _is_point_in_battlefield_open(event.position):
				_pan_pointer_active = true
				_pan_is_middle = (event.button_index == MOUSE_BUTTON_MIDDLE)
				_pan_start_pos = event.position
				_pan_last_pos = event.position
				_is_panning_map = false
		elif event is InputEventMouseButton and not event.pressed:
			if _pan_pointer_active and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE):
				var was_panning: bool = _is_panning_map
				_pan_pointer_active = false
				_pan_is_middle = false
				_is_panning_map = false
				if was_panning:
					if AnalyticsManager != null:
						AnalyticsManager.record_zoom_event("pan", map_ref.user_zoom)
					get_viewport().set_input_as_handled()
					return
		elif event is InputEventMouseMotion and _pan_pointer_active and map_ref.user_zoom > 1.01:
			var moved: float = event.position.distance_to(_pan_start_pos)
			if not _is_panning_map and (_pan_is_middle or moved >= 12.0):
				_is_panning_map = true
			if _is_panning_map:
				map_ref.pan_by_screen_delta(event.position - _pan_last_pos)
				_pan_last_pos = event.position
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventScreenTouch:
			if event.pressed:
				if _is_point_in_battlefield_open(event.position) or not _active_touches.is_empty():
					_active_touches[event.index] = event.position
					if _active_touches.size() == 2:
						var pts: Array = _active_touches.values()
						_pinch_prev_dist = maxf(10.0, (pts[0] as Vector2).distance_to(pts[1] as Vector2))
						_pinch_prev_mid = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
						_pinch_zoom_changed = false
						_pan_pointer_active = false
						_is_panning_map = false
			else:
				_active_touches.erase(event.index)
				if _active_touches.size() < 2:
					if _pinch_zoom_changed and AnalyticsManager != null:
						AnalyticsManager.record_zoom_event("pinch", map_ref.user_zoom)
					_pinch_zoom_changed = false
					_pinch_prev_dist = 0.0
		elif event is InputEventScreenDrag and _active_touches.has(event.index):
			_active_touches[event.index] = event.position
			if _active_touches.size() == 2:
				var pts2: Array = _active_touches.values()
				var p0: Vector2 = pts2[0]
				var p1: Vector2 = pts2[1]
				var cur_dist: float = maxf(10.0, p0.distance_to(p1))
				var cur_mid: Vector2 = (p0 + p1) * 0.5
				if _pinch_prev_dist > 10.0:
					var ratio: float = cur_dist / _pinch_prev_dist
					var prev_z: float = map_ref.user_zoom
					map_ref.pan_by_screen_delta(cur_mid - _pinch_prev_mid)
					map_ref.set_user_zoom(map_ref.user_zoom * ratio, cur_mid)
					if absf(map_ref.user_zoom - prev_z) >= 0.015:
						_pinch_zoom_changed = true
					_refresh_zoom_controls()
				_pinch_prev_dist = cur_dist
				_pinch_prev_mid = cur_mid
				get_viewport().set_input_as_handled()
				return

	if _drag_candidate_type != "":
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			var gpos: Vector2 = event.position
			var delta_v: Vector2 = gpos - _drag_start_screen_pos
			var threshold: float = 22.0 if (_drag_is_touch or _current_layout_mode == "portrait") else 10.0
			if not _is_dragging_tower and delta_v.length() >= threshold:
				# On touch devices in scrollable single-column landscape, let mostly-vertical swipes scroll smoothly!
				if _drag_is_touch and _drag_started_in_right_panel and _current_layout_mode != "portrait" and absf(delta_v.y) > absf(delta_v.x) * 1.25:
					_drag_candidate_type = ""
					_is_dragging_tower = false
					return
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
		if _comms_cooldown > 0.0:
			_comms_cooldown = maxf(0.0, _comms_cooldown - delta)
		if _comms_timer > 0.0:
			_comms_timer = maxf(0.0, _comms_timer - delta)
			if comms_toast_panel != null:
				if _comms_timer <= 0.0:
					comms_toast_panel.visible = false
				elif _comms_timer < 0.6:
					comms_toast_panel.modulate.a = clampf(_comms_timer / 0.6, 0.0, 1.0)
	if _early_call_armed_timer > 0.0:
		_early_call_armed_timer = maxf(0.0, _early_call_armed_timer - delta)
	_refresh_all()


func _refresh_all() -> void:
	var m := GameState.mission
	top_status_label.text = "Lives: %d / %d" % [m.lives, Balance.PLAYER_STARTING_LIVES]
	var max_w: int = wave_manager_ref.max_waves_limit if wave_manager_ref != null else WavesData.MISSION_TARGET_WAVE
	var best_w: int = maxi(GameState.get_level_best_wave(GameState.selected_map_level), int(m.stats.get("waves_completed", 0)))
	enemy_base_bar.max_value = float(max_w)
	enemy_base_bar.value = float(mini(m.wave_number, max_w))
	var c_stage: int = m.citadel_stage
	var c_tag: String = "★TIME GOD" if c_stage >= 3 else ("Stage %d" % c_stage if c_stage >= 1 else "Base")
	if _current_layout_mode == "portrait":
		enemy_base_label.text = ("ENDLESS W%d | Best W%d | Cit:%s" % [m.wave_number, best_w, c_tag]) if GameState.is_endless_mode else ("Goal W%d/%d | Best W%d | Cit:%s" % [m.wave_number, max_w, best_w, c_tag])
	else:
		enemy_base_label.text = ("★ ENDLESS FREEPLAY: Wave %d  |  Best: W%d  |  Chrono-Citadel: %s" % [m.wave_number, best_w, c_tag]) if GameState.is_endless_mode else ("Sector Milestone: Wave %d / %d  |  Best: W%d  |  Chrono-Citadel: %s" % [m.wave_number, max_w, best_w, c_tag])

	var mode_tag: String = " [SANDBOX]" if GameState.is_sandbox_mode else (" [ENDLESS]" if GameState.is_endless_mode else "")
	_refresh_zoom_controls()
	wave_label.text = "Wave %d / %d (Sector %d)%s" % [m.wave_number, max_w, GameState.selected_map_level, mode_tag]
	money_label.text = "Money: $INF (SANDBOX)" if GameState.is_sandbox_mode else ("Money: $%d" % m.economy["money"])
	research_label.text = "Research: %d R (%d/%d)" % [
		GameState.meta_research,
		int(m.stats["research_earned"]),
		Balance.MAX_RESEARCH_PER_MISSION,
	]
	var r_tier: int = GameState.get_refinery_tier()
	var r_rate: float = GameState.get_refinery_rate_per_sec()
	if r_tier > 1:
		refineries_label.text = "Ref: %d [T%d] (+$%.2f/s)" % [
			m.economy["refineries_owned"],
			r_tier,
			float(m.economy["refineries_owned"]) * r_rate,
		]
	else:
		refineries_label.text = "Ref: %d (+$%.2f/s)" % [
			m.economy["refineries_owned"],
			float(m.economy["refineries_owned"]) * r_rate,
		]

	_refresh_speed_buttons()
	_refresh_auto_wave_button()

	var mins: int = int(GameState.mission_elapsed_seconds) / 60
	var secs: int = int(GameState.mission_elapsed_seconds) % 60
	clock_label.text = "Time: %02d:%02d (%s)" % [mins, secs, GameState.get_relative_speed_label()]

	_refresh_preview_panel()
	_refresh_wave_intel_card()
	_refresh_selection_panel()
	_refresh_manipulator_panel()
	_refresh_refinery_tech_button()
	_refresh_research_panel()
	_refresh_surge_bar()
	_refresh_power_buttons()
	_refresh_refinery_button()
	_refresh_charge_button()
	_refresh_start_wave_button()
	_refresh_sandbox_ui()
	_refresh_enemy_inspector()

	if debug_panel.visible:
		_refresh_debug_overlay()


func _refresh_speed_buttons() -> void:
	var paused: bool = GameState.is_speed_paused
	var spd: float = GameState.game_speed
	speed_pause_button.modulate = Color(1.0, 0.65, 0.35) if paused else Color.WHITE
	speed_1x_button.modulate = Color(0.45, 0.95, 1.0) if (not paused and absf(spd - Balance.SPEED_OPTION_SLOW) < 0.15) else Color.WHITE
	speed_2x_button.modulate = Color(0.45, 0.95, 1.0) if (not paused and absf(spd - Balance.SPEED_OPTION_NORMAL) < 0.15) else Color.WHITE
	speed_3x_button.modulate = Color(0.45, 0.95, 1.0) if (not paused and absf(spd - Balance.SPEED_OPTION_FAST) < 0.15) else Color.WHITE


func _on_auto_wave_button_pressed() -> void:
	GameState.auto_wave_enabled = not GameState.auto_wave_enabled
	if pause_auto_wave_check != null and pause_auto_wave_check.button_pressed != GameState.auto_wave_enabled:
		pause_auto_wave_check.button_pressed = GameState.auto_wave_enabled
	GameState.save_meta_progress()
	_refresh_auto_wave_button()


func _refresh_auto_wave_button() -> void:
	if auto_wave_button == null:
		return
	auto_wave_button.text = "Auto:ON" if GameState.auto_wave_enabled else "Auto:OFF"
	auto_wave_button.modulate = Color(0.42, 0.98, 0.72) if GameState.auto_wave_enabled else Color(0.84, 0.88, 0.94)


func _refresh_surge_bar() -> void:
	var m := GameState.mission
	var win: float = surge_ref.get_surge_window() if surge_ref != null else Balance.SURGE_BASE_WINDOW
	surge_bar.max_value = win
	surge_bar.value = clampf(m.surge_timer_seconds, 0.0, win)

	var paused: bool = surge_ref.is_surge_paused() if surge_ref != null else false
	var pause_tag: String = " [PAUSED]" if paused else ""
	if _current_layout_mode == "portrait":
		surge_label.text = "SURGE: W%d (%.0fs)%s - use Time Power (+5w)" % [
			m.surge_deadline_wave,
			maxf(0.0, m.surge_timer_seconds),
			pause_tag,
		]
	else:
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


func _style_power_button(btn: Button, power_name: String, _offline: bool, _offline_str: String, _hive_charging: bool) -> void:
	var ab: Dictionary = Balance.TIME_ABILITIES[power_name]
	var tier: int = GameState.get_ability_level(power_name)
	var tcfg: Dictionary = GameState.get_ability_tier_cfg(power_name)
	var cast_cost: int = int(ab["cast_cost"])
	var title: String = "%s T%d" % [str(ab["name"]).to_upper(), tier]
	var effect: String = ""
	if power_name == "pause":
		effect = "Freeze %.0fs%s" % [float(tcfg.get("duration", 6.0)), " +%d%% dmg" % int(round(float(tcfg.get("brittle_pct", 0.0)) * 100.0)) if float(tcfg.get("brittle_pct", 0.0)) > 0.0 else ""]
	elif power_name == "haste":
		effect = "+%d%% spd %.0fs" % [int(round(float(tcfg.get("speed_bonus", 0.50)) * 100.0)), float(tcfg.get("duration", 16.0))]
	else:
		effect = "Pull -%d%% back!" % int(round(float(tcfg.get("pushback_pct", 0.18)) * 100.0))

	var money: int = GameState.mission.economy["money"]
	var status_line: String = "$%d READY" % cast_cost
	if power_name == "pause" and time_powers_ref.pause_remaining > 0.0:
		status_line = "ACTIVE %.1fs" % time_powers_ref.pause_remaining
	elif power_name == "haste" and time_powers_ref.haste_remaining > 0.0:
		status_line = "ACTIVE %.1fs" % time_powers_ref.haste_remaining
	elif time_powers_ref.cooldowns.get(power_name, 0.0) > 0.0:
		status_line = "CD %.0fs" % ceilf(time_powers_ref.cooldowns[power_name])
	elif not GameState.is_wave_active:
		status_line = "$%d (IN WAVE)" % cast_cost
	elif not GameState.is_sandbox_mode and money < cast_cost:
		status_line = "NEED $%d" % cast_cost
	elif power_name == "rewind" and not time_powers_ref.can_use_power("rewind"):
		status_line = "NO TARGETS"

	btn.text = "%s\n[%s]\n%s" % [title, status_line, effect]
	var usable: bool = time_powers_ref.can_use_power(power_name)
	btn.disabled = not usable
	if (power_name == "pause" and time_powers_ref.pause_remaining > 0.0) or (power_name == "haste" and time_powers_ref.haste_remaining > 0.0):
		btn.modulate = Color(0.45, 0.95, 1.0)
	elif usable:
		btn.modulate = Color.WHITE
	elif not GameState.is_sandbox_mode and GameState.is_wave_active and money < cast_cost:
		btn.modulate = Color(1.0, 0.58, 0.58)
	else:
		btn.modulate = Color(0.72, 0.76, 0.82)


func _format_mmss(seconds: float) -> String:
	var s: int = int(ceilf(maxf(0.0, seconds)))
	return "%d:%02d" % [s / 60, s % 60]


func _refresh_manipulator_panel() -> void:
	var m := GameState.mission
	var st: int = m.citadel_stage
	var st_lbl: String = "★TIME GOD" if st >= 3 else ("Stage %d/3" % st)
	manip_status_label.text = "Citadel %s | Frz T%d • Ovr T%d • Rew T%d" % [
		st_lbl,
		GameState.get_ability_level("pause"),
		GameState.get_ability_level("haste"),
		GameState.get_ability_level("rewind"),
	]
	manip_status_label.modulate = Color(1.0, 0.90, 0.42) if st >= 2 else Color(0.78, 0.92, 1.0)
	var nxt_c: int = base_attack_ref.get_next_citadel_cost() if base_attack_ref != null else -1
	var can_asc: bool = base_attack_ref != null and base_attack_ref.can_ascend_citadel()
	if nxt_c > 0:
		manip_upgrade_button.text = "Citadel S%d ($%d) & Abilities..." % [st + 1, nxt_c]
	else:
		manip_upgrade_button.text = "★ Citadel MAX & Abilities..."
	manip_upgrade_button.disabled = GameState.mission.is_over
	manip_upgrade_button.modulate = Color(1.0, 0.94, 0.48) if can_asc else Color.WHITE
	_set_button_description(manip_upgrade_button, "Upgrade Time Abilities (T1-T5) or Ascend Chrono-Citadel into a Super-Weapon!")


func _refresh_refinery_tech_button() -> void:
	if refinery_tech_button == null or economy_ref == null:
		return
	var cur_tier: int = GameState.get_refinery_tier()
	if economy_ref.refinery_tech_job != null:
		var phase_tag: String = "" if GameState.is_wave_active else " [in wave]"
		refinery_tech_button.text = "Refinery Tech T%d (%.1fs)%s" % [cur_tier + 1, economy_ref.refinery_tech_job.remaining_time, phase_tag]
		refinery_tech_button.disabled = true
		refinery_tech_button.modulate = Color(1.0, 0.88, 0.40)
		_set_button_description(refinery_tech_button, "Upgrading Refinery Annex tech tier (accelerated by Haste).")
		return
	if cur_tier >= Balance.REFINERY_MAX_TIER:
		refinery_tech_button.text = "Refinery T4: Singularity Mint MAX"
		refinery_tech_button.disabled = true
		refinery_tech_button.modulate = Color(0.55, 0.98, 0.85)
		_set_button_description(refinery_tech_button, "MAX Tier 4: $3.25/s per Refinery + 15% Bank interest (up to $1,800/wave).")
		return
	var next_t: int = cur_tier + 1
	var tcfg: Dictionary = Balance.get_refinery_tier_cfg(next_t)
	var cost: int = int(tcfg["cost"])
	var owned: int = int(GameState.mission.economy.get("refineries_owned", 0))
	var can_upg: bool = economy_ref.can_upgrade_refinery_tier()
	if owned < 1 and not GameState.is_sandbox_mode:
		refinery_tech_button.text = "Ref Tech T%d ($%d) [Need 1 Ref]" % [next_t, cost]
	else:
		refinery_tech_button.text = "Ref T%d: %s ($%d)" % [next_t, str(tcfg["name"]), cost]
	refinery_tech_button.disabled = not can_upg
	refinery_tech_button.modulate = Color.WHITE if can_upg else Color(1.0, 0.65, 0.65)
	_set_button_description(refinery_tech_button, "T%d %s ($%d): %s" % [next_t, str(tcfg["name"]), cost, str(tcfg["desc"])])


func _refresh_preview_panel() -> void:
	if wave_manager_ref == null:
		return
	var preview: Dictionary = wave_manager_ref.get_preview_data()
	var wave_num: int = preview["wave_number"]
	var max_w: int = wave_manager_ref.max_waves_limit
	var exam_title: String = str(preview.get("exam_title", ""))
	if exam_title != "":
		preview_title_label.text = "★ W%d %s  •  Reward $%d" % [
			wave_num,
			exam_title,
			int(round(float(preview.get("b_dollars", 0)) * GameState.get_enemy_bounty_multiplier())),
		]
		preview_title_label.modulate = Color(1.0, 0.72, 0.32)
	else:
		preview_title_label.text = "WAVE %d / %d  •  Reward ~$%d" % [
			wave_num,
			max_w,
			int(round(float(preview.get("b_dollars", 0)) * GameState.get_enemy_bounty_multiplier())),
		]
		preview_title_label.modulate = Color(0.76, 0.94, 1.0)

	var counts: Dictionary = preview["counts"]
	var unit_parts: PackedStringArray = []
	for utype in ["colossus", "juggernaut", "conduit", "carrier", "mender", "stalker", "blitzer", "brute", "rusher", "crawler"]:
		if counts.has(utype):
			var uname: String = Balance.ENEMIES[utype]["name"]
			unit_parts.append("%d %s (HP %d)" % [counts[utype], uname, GameState.get_enemy_wave_hp(utype, wave_num)])
	var counter_tags: PackedStringArray = []
	if counts.has("conduit"):
		counter_tags.append("SHIELD AURA: Snipe Conduit!")
	if counts.has("carrier"):
		counter_tags.append("SPLIT: AoE!")
	if counts.has("stalker"):
		counter_tags.append("CLOAK: Time/Laser/Rng2+")
	if counts.has("mender"):
		counter_tags.append("REGEN: Decay/Shred")
	if counter_tags.is_empty():
		if counts.has("colossus") or counts.has("juggernaut"):
			counter_tags.append("BOSS: Piercing 180%")
		elif counts.has("blitzer"):
			counter_tags.append("REFL: Avoid Laser")
		elif counts.has("brute"):
			counter_tags.append("ARMORED: Piercing 150%")
	var counter_tag: String = (" [" + " | ".join(counter_tags) + "]") if not counter_tags.is_empty() else ""
	preview_body_label.text = "Incoming: " + ", ".join(unit_parts) + counter_tag

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

	wave_summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	wave_summary_label.clip_text = true
	wave_summary_label.text = _last_summary_text
	wave_summary_label.visible = (_last_summary_text != "")


func _refresh_selection_panel() -> void:
	var money: int = GameState.mission.economy["money"]
	if _selected_tower != null and is_instance_valid(_selected_tower):
		build_menu_box.visible = false
		tower_panel_box.visible = true

		var cfg: Dictionary = Balance.TOWERS[_selected_tower.tower_type]
		var loc_tag: String = "Pad P%d" % (_selected_tower.pad_index + 1) if _selected_tower.pad_index >= 0 else "Tower Zone"
		var apex_hdr_tag: String = " [★T5]" if _selected_tower.apex_tier >= 2 else (" [T4]" if _selected_tower.apex_tier == 1 else "")
		tower_header_label.text = "%s%s (%s)" % [cfg["name"], apex_hdr_tag, loc_tag]
		var eff_dps: float = _selected_tower.get_estimated_dps()
		var eff_dmg: float = _selected_tower.get_effective_damage()
		var eff_rate: float = _selected_tower.get_effective_fire_rate()
		var eff_rng: float = _selected_tower.get_effective_range()
		if _selected_tower.spawner_creates_bubble():
			tower_ratings_label.text = "DPS %.1f | Bub %.0fpx (%.1fs) | Rng %.0f" % [
				eff_dps,
				_selected_tower.get_effective_bubble_radius(),
				float(cfg.get("bubble_duration", 3.5)) + _selected_tower.get_apex_mod_float("bubble_duration_add", 0.0),
				eff_rng,
			]
		else:
			tower_ratings_label.text = "DPS %.1f | %.0f @ %.2f/s | Rng %.0f" % [
				eff_dps,
				eff_dmg,
				eff_rate,
				eff_rng,
			]
		if _selected_tower.current_job != null:
			var kind_txt: String = "Building" if not _selected_tower.is_built else ("Combining..." if _selected_tower.current_job.kind == "tower_combine" else ("Evolving T%s..." % _selected_tower.current_job.target_key if _selected_tower.current_job.kind == "tower_apex" else ("Upgrading %s" % _selected_tower.current_job.target_key.capitalize())))
			var wave_tag: String = "" if (GameState.is_wave_active or GameState.is_sandbox_mode) else " [starts in wave]"
			tower_status_label.text = "%s: %.1f s left (cannot fire)%s" % [kind_txt, _selected_tower.current_job.remaining_time, wave_tag]
			tower_status_label.modulate = Color(1.0, 0.85, 0.35)
		else:
			var status_badge: String = " [★APEX]" if _selected_tower.apex_tier >= 2 else (" [T4]" if _selected_tower.apex_tier == 1 else (" [COMBO]" if Balance.is_combo_tower(_selected_tower.tower_type) else ""))
			var camo_badge: String = " [CAMO]" if _selected_tower.can_detect_cloaked() else ""
			tower_status_label.text = "Active | Dmg %d | Kills %d%s%s" % [
				int(round(_selected_tower.total_damage_dealt)),
				_selected_tower.total_kills,
				status_badge,
				camo_badge,
			]
			tower_status_label.modulate = Color(0.45, 0.98, 1.0) if _selected_tower.apex_tier >= 2 else (Color(1.0, 0.90, 0.45) if Balance.is_combo_tower(_selected_tower.tower_type) else Color(0.55, 0.95, 0.65))

		var compact_2col: bool = (_current_layout_mode == "landscape_wide")
		var tlabel: String = str(Balance.TARGETING_LABELS.get(_selected_tower.target_mode, "First"))
		target_mode_button.text = ("Target: %s" % tlabel) if compact_2col else ("Target: %s (tap to cycle)" % tlabel)
		target_mode_button.disabled = GameState.mission.is_over
		_set_button_description(target_mode_button, "Targeting (%s): First/Last/Strongest/Weakest/Fastest/Slowest." % tlabel)

		if _selected_tower.uses_decay_upgrades():
			var decay_desc: String = "Decay DoT + Bubble Radius (%.0fpx)" % _selected_tower.get_effective_bubble_radius() if _selected_tower.spawner_creates_bubble() else "Flat Time Decay DoT/sec (150%% vs Refl/Jugg)"
			var decay_lbl: String = "Decay" if compact_2col else ("Decay+Rad" if _selected_tower.spawner_creates_bubble() else "Decay DoT")
			_style_upgrade_button(upg_dmg_button, decay_lbl, "damage", _selected_tower, money, decay_desc)
		else:
			_style_upgrade_button(upg_dmg_button, "Dmg" if compact_2col else "Damage", "damage", _selected_tower, money, "+30% / +68% / +115% / +170% / +235% total damage")
		_style_upgrade_button(upg_rng_button, "Rng" if compact_2col else "Range", "range", _selected_tower, money, "+25%..+160% range | Lv2+ unlocks CAMO detect & +25%..+40% dmg vs Cloaked!")
		_style_upgrade_button(upg_spd_button, "Spd" if compact_2col else "Fire Rate", "fire_rate", _selected_tower, money, "+18% / +38% / +62% / +90% / +120% fire speed")

		if combine_button != null:
			var is_already_combo: bool = Balance.is_combo_tower(_selected_tower.tower_type)
			combine_button.visible = true
			if not is_already_combo:
				var is_picking: bool = (map_ref != null and map_ref.combine_source_tower == _selected_tower)
				if is_picking:
					map_ref.refresh_combine_partner_badges()
				var best_q: Dictionary = map_ref.get_best_combine_quote_for(_selected_tower) if map_ref != null else {}
				var has_rank_partner: bool = (not best_q.is_empty() and bool(best_q.get("meets_ranks", false)))
				var rks: int = _selected_tower.get_total_upgrade_ranks()
				if is_picking:
					if has_rank_partner:
						var min_c: int = int(best_q["total_cost"])
						combine_button.text = ("Cancel ($%d+)" % min_c) if compact_2col else ("Tap Tagged Tower ($%d+) — Cancel" % min_c)
						_set_button_description(combine_button, "Green = ready now | Red = need more $. Cheapest: %s = $%d ($%d merge + $%d sync)." % [
							str(best_q["combo_name"]), min_c, int(best_q["base_fee"]), int(best_q["xfer_fee"])
						])
					else:
						combine_button.text = "Cancel Merge" if compact_2col else "Click Partner Tower (Tap Cancel)"
						_set_button_description(combine_button, "Need 3+ combined upgrade ranks across 2 base towers, or tap Cancel.")
					combine_button.disabled = false
					combine_button.modulate = Color(1.0, 0.90, 0.35)
				else:
					if has_rank_partner:
						var min_cost: int = int(best_q["total_cost"])
						var can_aff: bool = bool(best_q["can_afford"])
						combine_button.text = (("Fuse ($%d+)" % min_cost) if can_aff else ("Fuse ($%d!)" % min_cost)) if compact_2col else ("Combine (from $%d)..." % min_cost)
						combine_button.modulate = Color(0.55, 1.0, 0.72) if can_aff else Color(1.0, 0.80, 0.52)
						_set_button_description(combine_button, "Cheapest fuse: %s = $%d ($%d merge + $%d upgrade sync). Tap to see exact $ on every partner!" % [
							str(best_q["combo_name"]), min_cost, int(best_q["base_fee"]), int(best_q["xfer_fee"])
						])
					elif not GameState.is_sandbox_mode and rks < Balance.COMBINE_MIN_TOTAL_RANKS:
						var best_sum: int = int(best_q.get("combined_ranks", rks))
						combine_button.text = ("Fuse (%d/3 rk)" % best_sum) if compact_2col else ("Combine (Ranks %d/3)..." % best_sum)
						combine_button.modulate = Color(0.95, 0.82, 0.58)
						_set_button_description(combine_button, "Upgrade base towers to 3+ combined ranks (%d/3) before fusing (or drag from shop at 3+ ranks)." % best_sum)
					else:
						combine_button.text = "Combine..." if compact_2col else "Combine w/ Another Tower..."
						combine_button.modulate = Color.WHITE
						_set_button_description(combine_button, "Build another base tower to fuse on-map, or drag any tower from the shop onto this tower!")
					combine_button.disabled = not _selected_tower.can_combine()
			else:
				# Tier-4 Milestone Perk -> Tier-5 APEX OVERDRIVE slot!
				if _selected_tower.apex_tier >= 2:
					var t5_done: Dictionary = Balance.get_combo_evolution_cfg(_selected_tower.tower_type, 2)
					combine_button.text = "★ APEX T5 MAX"
					combine_button.disabled = true
					combine_button.modulate = Color(0.45, 0.98, 1.0)
					_set_button_description(combine_button, "★ %s: %s" % [str(t5_done.get("name", "APEX")), str(t5_done.get("desc", ""))])
				else:
					var next_tier: int = _selected_tower.apex_tier + 1
					var next_evo: Dictionary = _selected_tower.get_next_apex_cfg()
					var evo_name: String = str(next_evo.get("name", "Evolve"))
					var evo_cost: int = int(next_evo.get("cost", 1500))
					var can_evo: bool = _selected_tower.can_evolve_apex()
					if next_tier == 1:
						combine_button.text = ("T4 %s ($%d)" % [evo_name, evo_cost]) if compact_2col else ("Evolve T4: %s ($%d)" % [evo_name, evo_cost])
						combine_button.modulate = Color(1.0, 0.92, 0.42) if can_evo else Color(1.0, 0.65, 0.65)
					else:
						combine_button.text = ("★T5 %s ($%d)" % [evo_name, evo_cost]) if compact_2col else ("★ APEX T5: %s ($%d)" % [evo_name, evo_cost])
						combine_button.modulate = Color(0.48, 0.98, 1.0) if can_evo else Color(1.0, 0.65, 0.65)
					combine_button.disabled = not can_evo
					_set_button_description(combine_button, "%s ($%d): %s" % [evo_name, evo_cost, str(next_evo.get("desc", ""))])

		var refund: int = _selected_tower.get_sell_refund()
		sell_button.disabled = GameState.mission.is_over
		_set_button_description(sell_button, "Refund $%d (50%% of $%d spent) and free placement slot." % [
			refund,
			_selected_tower.total_spent,
		])
		if _sell_confirm_armed:
			sell_button.text = ("CONFIRM +$%d" % refund) if compact_2col else ("CONFIRM SELL (+$%d)" % refund)
			sell_button.modulate = Color(1.0, 0.55, 0.45)
		else:
			sell_button.text = ("Sell +$%d" % refund) if compact_2col else ("Sell Tower (+$%d)" % refund)
			sell_button.modulate = Color.WHITE
		_refresh_combine_partner_list()
	elif _selected_pad_idx >= 0 or (map_ref != null and map_ref.selected_drop_pos.x >= 0.0):
		if combine_partner_box != null:
			combine_partner_box.visible = false
			_last_combine_list_sig = ""
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
		if combine_partner_box != null:
			combine_partner_box.visible = false
			_last_combine_list_sig = ""
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
	meta_research_status_label.text = "Persistent Meta-Research: %d R | Selected: %s (%s | Goal: Wave %d -> Endless)" % [
		res,
		map_cfg["name"],
		map_cfg["zone_type"],
		WavesData.MISSION_TARGET_WAVE,
	]
	var lvl_btns: Array[Button] = [level_1_button, level_2_button, level_3_button, level_4_button, level_5_button]
	for idx in range(lvl_btns.size()):
		if lvl_btns[idx] != null:
			lvl_btns[idx].modulate = Color(0.45, 0.95, 1.0) if sel_map == (idx + 1) else Color.WHITE

	if start_menu_overlay != null:
		var short_zone_tags: Dictionary = {
			1: "4 Rows",
			2: "3 Columns",
			3: "4 Islands",
			4: "4 Bastions",
			5: "5 Pillboxes",
		}
		for idx in range(start_level_buttons.size()):
			var sbtn: Button = start_level_buttons[idx]
			var lid: int = idx + 1
			var lcfg: Dictionary = Balance.LEVELS[lid]
			var is_active: bool = (sel_map == lid)
			var cleared_tag: String = " [★]" if bool(GameState.level_medals.get(lid, {}).get("cleared", false)) else ""
			var bw: int = GameState.get_level_best_wave(lid)
			var best_tag: String = (" | Best W%d" % bw) if bw > 0 else " | Goal W40"
			sbtn.text = "%s%s\n(%s%s)" % [lcfg["short_name"], cleared_tag, str(short_zone_tags.get(lid, lcfg["zone_type"])), best_tag]
			sbtn.modulate = Color(0.45, 0.98, 1.0) if is_active else Color.WHITE
		for dk in start_diff_buttons.keys():
			var dbtn: Button = start_diff_buttons[dk]
			dbtn.modulate = Color(0.45, 0.98, 1.0) if GameState.difficulty_key == dk else Color(0.76, 0.80, 0.86)
		if start_level_title_label != null:
			start_level_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var sel_bw: int = GameState.get_level_best_wave(sel_map)
			var bw_str: String = (" | Best W%d" % sel_bw) if sel_bw > 0 else ""
			start_level_title_label.text = "%s — Goal: W%d -> Endless%s" % [
				str(map_cfg["name"]).to_upper(),
				WavesData.MISSION_TARGET_WAVE,
				bw_str,
			]
		if start_level_desc_label != null:
			var mod_txt: String = str(map_cfg.get("modifier_label", ""))
			var diff_cfg: Dictionary = GameState.get_difficulty_cfg()
			var extra_line: String = ("\nSector Modifier: %s  |  Difficulty: %s (%s)" % [mod_txt, str(diff_cfg["name"]), str(diff_cfg["desc"])]) if mod_txt != "" else ("\nDifficulty: %s (%s)" % [str(diff_cfg["name"]), str(diff_cfg["desc"])])
			start_level_desc_label.text = str(map_cfg["description"]) + extra_line + "\n" + ComedyLines.get_level_lore(sel_map)
		if start_meta_label != null:
			start_meta_label.text = "Persistent Meta-Research Available: %d R (Max %d R earned per mission)" % [res, Balance.MAX_RESEARCH_PER_MISSION]
		if start_play_button != null:
			start_play_button.text = "START %s" % str(map_cfg["name"]).to_upper()
		if start_sandbox_button != null:
			start_sandbox_button.text = "SANDBOX (LV %d)" % sel_map
	if lab_sandbox_button != null:
		lab_sandbox_button.text = "Sandbox (Lv %d)" % sel_map

	var can_spend_now: bool = not GameState.is_wave_active and (GameState.mission.wave_number == 1 or GameState.mission.is_over)
	for key in RESEARCH_ORDER:
		var btn: Button = _research_buttons[key]
		var cfg: Dictionary = Balance.RESEARCH_NODES[key]
		var rank: int = GameState.get_research_rank(key)
		var max_rank: int = cfg["rank_costs"].size()
		var cost: int = GameState.get_next_research_cost(key)
		if rank >= max_rank or cost < 0:
			_set_button_description(btn, "MAX Rank (%d/%d): %s. %s" % [rank, max_rank, cfg["description"], ComedyLines.get_research_flavor(key)])
			btn.text = "%s [Rank %d/%d MAX]" % [cfg["name"], rank, max_rank]
			btn.disabled = true
			btn.modulate = Color(0.62, 0.95, 0.72)
		else:
			_set_button_description(btn, "Rank %d->%d (%d R): %s. %s" % [
				rank,
				rank + 1,
				cost,
				cfg["description"],
				ComedyLines.get_research_flavor(key),
			])
			btn.text = "%s [Rank %d/%d] (%d R)" % [cfg["name"], rank, max_rank, cost]
			var affordable: bool = res >= cost and can_spend_now
			btn.disabled = not affordable
			btn.modulate = Color.WHITE if affordable else Color(1.0, 0.65, 0.65)


func _refresh_charge_button() -> void:
	if base_attack_ref == null:
		charge_button.disabled = true
		return
	var st: int = GameState.mission.citadel_stage
	var nxt_s: int = base_attack_ref.get_next_citadel_stage()
	var can_asc: bool = base_attack_ref.can_ascend_citadel()
	var can_ab_u: bool = time_powers_ref != null and (
		time_powers_ref.can_upgrade_ability("pause") or
		time_powers_ref.can_upgrade_ability("haste") or
		time_powers_ref.can_upgrade_ability("rewind")
	)
	if nxt_s > 0:
		var ncost: int = int(Balance.CITADEL_STAGES[nxt_s]["cost"])
		var nname: String = "TIME GOD S3" if nxt_s >= 3 else ("CITADEL S%d" % nxt_s)
		charge_button.text = "★ %s ($%d)\nAbilities & Sacrifices" % [nname, ncost]
	else:
		charge_button.text = "★ TIME GOD MAX\nUpgrade Abilities"
	charge_button.disabled = GameState.mission.is_over
	if can_asc:
		charge_button.modulate = Color(1.0, 0.94, 0.44)
	elif can_ab_u:
		charge_button.modulate = Color(0.55, 0.96, 1.0)
	else:
		charge_button.modulate = Color(0.86, 0.90, 0.96)


func _on_charge_button_pressed() -> void:
	open_citadel_overlay()


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
	var r_tier: int = GameState.get_refinery_tier()
	var r_rate: float = GameState.get_refinery_rate_per_sec()
	var t_tag: String = (" [T%d]" % r_tier) if r_tier > 1 else ""
	refinery_button.text = "Build Refinery ($%d, %.0fs)\n+$%.2f/sec%s" % [cost, Balance.REFINERY_BUILD_TIME, r_rate, t_tag]
	refinery_button.disabled = not affordable
	refinery_button.modulate = Color.WHITE if affordable else Color(1.0, 0.45, 0.45)


func _style_build_button(btn: Button, tower_type: String, money: int, is_armed: bool = false) -> void:
	var cfg: Dictionary = Balance.TOWERS[tower_type]
	var cost: int = int(cfg["cost"])
	var affordable: bool = (GameState.is_sandbox_mode or money >= cost) and not GameState.mission.is_over
	var is_2col: bool = (build_buttons_grid != null and build_buttons_grid.columns >= 2)
	var short_names := {
		"blaster": "Blaster",
		"mortar": "Mortar",
		"laser": "Laser",
		"slow": "Chrono Slow",
		"railgun": "Rail Gun",
		"annihilator": "Annihilator",
	}
	var disp_name: String = str(short_names.get(tower_type, cfg["name"])) if is_2col else str(cfg["name"])
	var armed_prefix: String = "[TAP] " if (is_armed and is_2col) else ("[CLICK PAD] " if is_armed else "")
	btn.text = "%s%s ($%d)" % [armed_prefix, disp_name, cost]
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

	var desc: String = ""
	if tower_type == "mortar":
		desc = "$%d (%ds) Splash AoE — \"%s\"" % [cost, int(cfg["build_time"]), ComedyLines.get_tower_flavor(tower_type)]
	elif tower_type == "laser":
		desc = "$%d (%ds) 150%% Std / 10%% Refl — \"%s\"" % [cost, int(cfg["build_time"]), ComedyLines.get_tower_flavor(tower_type)]
	elif tower_type == "slow":
		desc = "$%d (%ds) 30%% Slow+Decay — \"%s\"" % [cost, int(cfg["build_time"]), ComedyLines.get_tower_flavor(tower_type)]
	elif tower_type == "railgun":
		desc = "$%d (%ds) 140+Slow+Decay — \"%s\"" % [cost, int(cfg["build_time"]), ComedyLines.get_tower_flavor(tower_type)]
	elif tower_type == "annihilator":
		desc = "$%d (%ds) Anti-Boss — \"%s\"" % [cost, int(cfg["build_time"]), ComedyLines.get_tower_flavor(tower_type)]
	else:
		desc = "$%d (%ds) Piercing 180%% Boss — \"%s\"" % [cost, int(cfg["build_time"]), ComedyLines.get_tower_flavor(tower_type)]
	_set_button_description(btn, desc)

	if is_armed:
		btn.modulate = Color(0.75, 0.98, 1.0)
	else:
		btn.modulate = Color.WHITE if affordable else Color(1.0, 0.65, 0.65)


func _style_upgrade_button(btn: Button, title: String, key: String, tower: TowerUnit, money: int, desc_detail: String) -> void:
	var lvl: int = int(tower.levels.get(key, 0))
	var compact_lbl: bool = (_current_layout_mode == "landscape_wide")
	var pips: String = ""
	if compact_lbl:
		pips = "L%d/5" % lvl
	else:
		for i in range(Balance.TOWER_UPGRADE_MAX_LEVEL):
			pips += "[*]" if i < lvl else "[ ]"
	if lvl >= Balance.TOWER_UPGRADE_MAX_LEVEL:
		var max_camo: String = " [CAMO]" if (key == "range" and tower.can_detect_cloaked()) else ""
		btn.text = ("%s MAX%s" % [title, max_camo]) if compact_lbl else ("%s %s MAX%s" % [title, pips, max_camo])
		btn.disabled = true
		btn.modulate = Color(0.75, 0.92, 0.78)
		_set_button_description(btn, "%s MAX (%d/%d): %s." % [title, Balance.TOWER_UPGRADE_MAX_LEVEL, Balance.TOWER_UPGRADE_MAX_LEVEL, desc_detail])
		return
	var cost: int = Balance.get_tower_upgrade_cost(key, lvl, tower.tower_type)
	var btime: int = int(Balance.TOWER_UPGRADE_BUILD_TIMES[lvl])
	var can_buy: bool = tower.can_start_upgrade(key)
	var camo_suffix: String = ""
	var is_camo_unlock_step: bool = false
	if key == "range":
		if tower.can_detect_cloaked():
			camo_suffix = " [CAMO]"
		elif lvl == 1:
			camo_suffix = " [+CAMO!]"
			is_camo_unlock_step = true
		elif lvl == 0:
			camo_suffix = " (Camo@L2)"
	btn.text = "%s %s ($%d)%s" % [title, pips, cost, camo_suffix]
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
	elif is_camo_unlock_step:
		btn.modulate = Color(0.62, 1.0, 0.96)
	else:
		btn.modulate = Color.WHITE


func _refresh_start_wave_button() -> void:
	if wave_manager_ref == null:
		start_wave_button.disabled = true
		return
	var can_start: bool = (wave_manager_ref.state == WaveManager.State.BUILD) and not GameState.mission.is_over
	var can_early: bool = wave_manager_ref.can_call_next_wave_early()
	start_wave_button.disabled = not (can_start or can_early)
	if can_start:
		_early_call_armed_timer = 0.0
		start_wave_button.text = "START WAVE %d" % GameState.mission.wave_number
		start_wave_button.modulate = Color.WHITE
	elif can_early:
		if _early_call_armed_timer > 0.0:
			start_wave_button.text = "CONFIRM EARLY W%d?\n(+$%d)" % [GameState.mission.wave_number + 1, wave_manager_ref.get_early_call_bonus()]
			start_wave_button.modulate = Color(1.0, 0.62, 0.25)
		else:
			start_wave_button.text = "EARLY W%d (+$%d)\n(Tap 2x)" % [GameState.mission.wave_number + 1, wave_manager_ref.get_early_call_bonus()]
			start_wave_button.modulate = Color(1.0, 0.90, 0.42)
	elif wave_manager_ref.state == WaveManager.State.SPAWNING:
		start_wave_button.text = "SPAWNING..."
		start_wave_button.modulate = Color.WHITE
	elif wave_manager_ref.state == WaveManager.State.FIGHTING:
		start_wave_button.text = "WAVE IN PROGRESS"
		start_wave_button.modulate = Color.WHITE
	else:
		start_wave_button.text = "WAVE COMPLETE"
		start_wave_button.modulate = Color.WHITE


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
	open_citadel_overlay()


func _on_surge_banner_triggered(banner_text: String) -> void:
	surge_banner_label.text = banner_text
	surge_banner.visible = true
	_banner_timer = 3.5
	show_chrono_comms("surge", true)


func _on_event_logged(message: String) -> void:
	_event_feed.push_front(message)
	if _event_feed.size() > 5:
		_event_feed.resize(5)
	event_feed_label.text = "Events: " + "  |  ".join(_event_feed)
	if message.contains("Combined into") or message.contains("COMBINED:") or message.contains("MERGED:"):
		trigger_guide_beat("first_combine")
		show_chrono_comms("combine", true)
	elif message.begins_with("★ APEX T5"):
		show_chrono_comms("apex_t5", true)
	elif message.begins_with("TIER 4 EVOLVED"):
		show_chrono_comms("apex_t4", true)
	elif message.begins_with("Close call!"):
		show_chrono_comms("close_call", false)
	elif message.begins_with("Sold "):
		show_chrono_comms("sell", false)
	elif message.contains("Refinery") and message.contains("Tier"):
		show_chrono_comms("refinery_tech", false)
	elif message.contains("Refinery") and message.contains("built"):
		show_chrono_comms("refinery", false)


func _on_refinery_button_pressed() -> void:
	if economy_ref != null:
		economy_ref.start_build_refinery()
		_refresh_all()


func _on_refinery_tech_pressed() -> void:
	if economy_ref != null:
		economy_ref.start_upgrade_refinery_tier()
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


func _refresh_combine_partner_list() -> void:
	if combine_partner_box == null:
		return
	var show_picker: bool = (
		_selected_tower != null
		and is_instance_valid(_selected_tower)
		and not Balance.is_combo_tower(_selected_tower.tower_type)
		and map_ref != null
		and map_ref.combine_source_tower == _selected_tower
	)
	if not show_picker:
		combine_partner_box.visible = false
		_last_combine_list_sig = ""
		return

	var money: int = int(GameState.mission.economy.get("money", 0))
	var entries: Array[Dictionary] = []
	for t in map_ref.get_all_towers():
		if t == _selected_tower or not t.can_combine():
			continue
		var q: Dictionary = map_ref.get_two_tower_combine_quote(_selected_tower, t)
		if q.is_empty():
			continue
		entries.append({"tower": t, "quote": q})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var qa: Dictionary = a["quote"]
		var qb: Dictionary = b["quote"]
		var ra: int = (2 if (bool(qa["meets_ranks"]) and bool(qa["can_afford"])) else (1 if bool(qa["meets_ranks"]) else 0))
		var rb: int = (2 if (bool(qb["meets_ranks"]) and bool(qb["can_afford"])) else (1 if bool(qb["meets_ranks"]) else 0))
		if ra != rb:
			return ra > rb
		return int(qa["total_cost"]) < int(qb["total_cost"])
	)

	var sig_parts: PackedStringArray = [str(_selected_tower.tower_id), str(money), _current_layout_mode]
	for e in entries:
		var pt: TowerUnit = e["tower"]
		var q: Dictionary = e["quote"]
		sig_parts.append("%d:%s:%d:%s:%s" % [pt.tower_id, str(q["combo_key"]), int(q["total_cost"]), str(q["meets_ranks"]), str(q["can_afford"])])
	var new_sig: String = "|".join(sig_parts)
	combine_partner_box.visible = true
	if new_sig == _last_combine_list_sig:
		return
	_last_combine_list_sig = new_sig

	for ch in combine_partner_box.get_children():
		ch.queue_free()

	var is_port: bool = (_current_layout_mode == "portrait")
	var is_wide: bool = (_current_layout_mode == "landscape_wide")
	var hdr := Label.new()
	hdr.text = "TAP A PARTNER BELOW (OR ON MAP) TO FUSE:"
	hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hdr.add_theme_font_size_override("font_size", 18 if is_port else (12 if is_wide else 11))
	hdr.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
	combine_partner_box.add_child(hdr)

	if entries.is_empty():
		var empty_l := Label.new()
		empty_l.text = "No other built base tower on map yet. Build a 2nd base tower OR drag any tower from the shop onto this one!"
		empty_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_l.add_theme_font_size_override("font_size", 17 if is_port else 11)
		empty_l.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
		combine_partner_box.add_child(empty_l)
		return

	var btn_h: float = 76.0 if is_port else (46.0 if is_wide else 34.0)
	var btn_fs: int = 19 if is_port else (13 if is_wide else 11)
	for e in entries:
		var partner_t: TowerUnit = e["tower"]
		var q: Dictionary = e["quote"]
		var combo_key: String = str(q["combo_key"])
		var combo_name: String = str(q["combo_name"])
		var total_c: int = int(q["total_cost"])
		var meets: bool = bool(q["meets_ranks"])
		var afford: bool = bool(q["can_afford"])
		var p_btn := Button.new()
		p_btn.name = "CombinePartnerBtn_%d" % partner_t.tower_id
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.custom_minimum_size = Vector2(0.0, btn_h)
		p_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		p_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p_btn.add_theme_font_size_override("font_size", btn_fs)
		var c_icon: ImageTexture = SpriteLibrary.get_ui_badge_icon(combo_key, 34)
		if c_icon != null:
			p_btn.icon = c_icon
		if meets and afford:
			p_btn.text = "FUSE $%d  ->  %s" % [total_c, combo_name]
			UIIcons.apply_right_button_theme(p_btn, Color(0.32, 0.98, 0.62), true)
			p_btn.modulate = Color(0.75, 1.0, 0.84)
		elif meets:
			p_btn.text = "NEED $%d  ->  %s (short $%d)" % [total_c, combo_name, int(q["shortfall"])]
			UIIcons.apply_right_button_theme(p_btn, Color(0.98, 0.42, 0.38), false)
			p_btn.modulate = Color(1.0, 0.78, 0.75)
		else:
			p_btn.text = "%d/3 RANKS  ->  %s ($%d)" % [int(q["combined_ranks"]), combo_name, total_c]
			UIIcons.apply_right_button_theme(p_btn, Color(0.96, 0.76, 0.30), false)
			p_btn.modulate = Color(1.0, 0.90, 0.66)
		p_btn.pressed.connect(func() -> void:
			if _selected_tower != null and is_instance_valid(_selected_tower) and is_instance_valid(partner_t) and map_ref != null:
				map_ref.combine_two_towers(_selected_tower, partner_t)
				_refresh_all()
		)
		combine_partner_box.add_child(p_btn)


func _on_combine_button_pressed() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower) or map_ref == null:
		return
	if Balance.is_combo_tower(_selected_tower.tower_type):
		if _selected_tower.start_apex_evolution():
			_refresh_all()
		return
	if map_ref.combine_source_tower == _selected_tower:
		map_ref.cancel_combine_partner_pick()
		_refresh_selection_panel()
		return
	var partner_count: int = map_ref.start_combine_partner_pick(_selected_tower)
	if partner_count == 0:
		var best_q: Dictionary = map_ref.get_best_combine_quote_for(_selected_tower)
		var best_sum: int = int(best_q.get("combined_ranks", _selected_tower.get_total_upgrade_ranks()))
		if not GameState.is_sandbox_mode and best_sum < Balance.COMBINE_MIN_TOTAL_RANKS:
			map_ref.spawn_floater(_selected_tower.position + Vector2(-62.0, -32.0), "NEED 3+ COMBINED RANKS (%d/3)!" % best_sum, Color(1.0, 0.72, 0.32))
			GameState.event_logged.emit("Upgrade base towers to 3+ combined ranks (%d/3) before fusing!" % best_sum)
		else:
			map_ref.spawn_floater(_selected_tower.position + Vector2(-66.0, -32.0), "BUILD ANOTHER BASE TOWER OR DRAG SHOP!", Color(1.0, 0.84, 0.42))
			GameState.event_logged.emit("Drag any shop tower onto this tower OR build another base tower to combine!")
	else:
		var best_q2: Dictionary = map_ref.get_best_combine_quote_for(_selected_tower)
		var min_c: int = int(best_q2.get("total_cost", 0))
		var aff_str: String = "Tap a GREEN tag to fuse now!" if bool(best_q2.get("can_afford", false)) else ("Need $%d+ to fuse (red tags show cost)!" % min_c)
		GameState.event_logged.emit("Combine costs shown over %d partner(s) — %s" % [partner_count, aff_str])
	_refresh_selection_panel()


func _toggle_sandbox_panel() -> void:
	if not GameState.is_sandbox_mode:
		return
	if sandbox_panel != null:
		sandbox_panel.visible = not sandbox_panel.visible
		_refresh_sandbox_ui()


func _adjust_sandbox_wave(delta_w: int) -> void:
	_sandbox_selected_wave = clampi(_sandbox_selected_wave + delta_w, 1, 45)
	_refresh_sandbox_ui()


func _on_sandbox_run_wave_pressed() -> void:
	if wave_manager_ref != null:
		wave_manager_ref.start_sandbox_wave(_sandbox_selected_wave)
		_refresh_all()


func _refresh_sandbox_ui() -> void:
	var in_sb: bool = GameState.is_sandbox_mode
	if sandbox_toggle_button != null:
		sandbox_toggle_button.visible = in_sb
	if sandbox_panel == null:
		return
	if not in_sb:
		sandbox_panel.visible = false
		return
	if not sandbox_panel.visible and sandbox_toggle_button != null and sandbox_toggle_button.visible:
		# Keep visible by default on first entry to sandbox unless manually hidden
		pass
	if sandbox_body_box != null:
		sandbox_body_box.visible = not _sandbox_collapsed
	if sandbox_collapse_button != null:
		sandbox_collapse_button.text = "+" if _sandbox_collapsed else "-"
	if sandbox_fast_build_button != null:
		sandbox_fast_build_button.text = "Instant: ON" if GameState.sandbox_instant_build else "Instant: OFF"
		sandbox_fast_build_button.modulate = Color(0.45, 1.0, 0.72) if GameState.sandbox_instant_build else Color(0.88, 0.88, 0.92)
	if sandbox_wave_label != null:
		sandbox_wave_label.text = "Wave: %d" % _sandbox_selected_wave
	if sandbox_qty_button != null:
		sandbox_qty_button.text = "Spawn Qty: x%d" % _sandbox_spawn_qty
	sandbox_panel.size = Vector2(304.0, 38.0 if _sandbox_collapsed else 290.0)


func _on_enemy_inspected(enemy: EnemyUnit) -> void:
	_inspected_enemy = enemy
	if enemy != null and AnalyticsManager != null:
		AnalyticsManager.record_feature_used("enemies_inspected")
	_refresh_enemy_inspector()


func _refresh_enemy_inspector() -> void:
	if enemy_inspector_panel == null or enemy_inspector_label == null:
		return
	if _inspected_enemy == null or not is_instance_valid(_inspected_enemy) or not _inspected_enemy.is_alive():
		_inspected_enemy = null
		enemy_inspector_panel.visible = false
		return
	var cfg: Dictionary = Balance.ENEMIES.get(_inspected_enemy.enemy_type, {})
	var ename: String = str(cfg.get("name", _inspected_enemy.enemy_type.capitalize()))
	var armour: String = _inspected_enemy.armour_label
	var best_tip: String = "Laser 150%"
	if _inspected_enemy.enemy_type == "stalker":
		best_tip = "Time/Laser/Rng Lv2+ reveals Cloak!"
	elif _inspected_enemy.enemy_type == "mender":
		best_tip = "Decay/Burn/Shred stops 6%/s Regen!"
	elif _inspected_enemy.enemy_type == "carrier":
		best_tip = "Piercing 150% + AoE for 6-unit Split!"
	elif _inspected_enemy.enemy_type == "conduit":
		best_tip = "SNIPE FIRST! Shields allies -35% dmg"
	elif armour.contains("Armored") and armour.contains("Reflective"):
		best_tip = "Piercing 180% | Time 150%"
	elif armour.contains("Reflective"):
		best_tip = "Time 150% | Avoid Laser"
	elif armour.contains("Armored"):
		best_tip = "Piercing 150%"
	var statuses: PackedStringArray = []
	if _inspected_enemy.is_effectively_cloaked():
		statuses.append("CLOAKED")
	elif _inspected_enemy.is_cloaked_type:
		statuses.append("Revealed")
	if _inspected_enemy.regen_pct_per_sec > 0.0:
		if _inspected_enemy.regen_suppressed_timer > 0.0 or _inspected_enemy.decay_ticks_remaining > 0 or _inspected_enemy.armor_shred_stacks > 0:
			statuses.append("Regen Blocked")
		else:
			statuses.append("Regen +6%/s")
	if _inspected_enemy.is_shielded_by_conduit():
		statuses.append("Aegis -35% Dmg")
	if _inspected_enemy.stun_remaining > 0.0:
		statuses.append("STUNNED")
	if _inspected_enemy.slow_remaining > 0.0 and _inspected_enemy.slow_pct > 0.0:
		statuses.append("Slow %d%%" % int(round(_inspected_enemy.slow_pct * 100.0)))
	if _inspected_enemy.decay_ticks_remaining > 0 and _inspected_enemy.decay_base_pct > 0.0:
		statuses.append("Decay %.0f/s" % _inspected_enemy.decay_base_pct)
	if _inspected_enemy.armor_shred_timer > 0.0 and _inspected_enemy.armor_shred_stacks > 0:
		statuses.append("Shred +%d%%" % (_inspected_enemy.armor_shred_stacks * 10))
	var status_str: String = ", ".join(statuses) if not statuses.is_empty() else "None"
	var cur_spd: float = _inspected_enemy.get_current_move_speed()
	enemy_inspector_label.text = "%s [%s]\nHP: %d / %d  |  Spd: %.0f px/s\nCounter: %s\nStatus: %s\n\"%s\"" % [
		ename,
		armour,
		int(ceil(_inspected_enemy.hp)),
		int(round(_inspected_enemy.max_hp)),
		cur_spd,
		best_tip,
		status_str,
		ComedyLines.get_enemy_flavor(_inspected_enemy.enemy_type),
	]
	enemy_inspector_panel.visible = true
	_reposition_comms_toast()


func _on_pad_selected(pad_idx: int) -> void:
	_selected_pad_idx = pad_idx
	_selected_tower = null
	_sell_confirm_armed = false
	_refresh_selection_panel()


func _on_tower_selected(tower: TowerUnit) -> void:
	_selected_tower = tower
	_selected_pad_idx = tower.pad_index
	_sell_confirm_armed = false
	if _right_scroll != null:
		_right_scroll.scroll_vertical = 0
	_refresh_selection_panel()


func _toggle_debug_panel() -> void:
	debug_panel.visible = not debug_panel.visible
	_refresh_all()


func _on_cycle_target_mode_pressed() -> void:
	if _selected_tower != null and is_instance_valid(_selected_tower):
		var new_mode: String = _selected_tower.cycle_target_mode()
		if AnalyticsManager != null:
			AnalyticsManager.record_feature_used("target_mode_changes")
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
	sb.bg_color = Color(0.10, 0.13, 0.19, 1.0)
	sb.border_color = Color(0.26, 0.34, 0.48)
	sb.set_border_width_all(1)
	sb.content_margin_left = 6.0 + pad_x
	sb.content_margin_right = 6.0 + pad_x
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	bar.add_theme_stylebox_override("panel", sb)


func _set_bottom_button_widths(scale_mult: float, btn_height: float = 56.0, font_sz: int = 10, portrait_grid: bool = false) -> void:
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
			btn.custom_minimum_size = Vector2(0.0 if portrait_grid else roundf(float(base_widths[btn]) * scale_mult), btn_height)
			btn.add_theme_font_size_override("font_size", font_sz)


func _scale_overlay_typography(ctrl: Node, is_portrait: bool) -> void:
	if ctrl == null:
		return
	if ctrl is BaseButton:
		var b: BaseButton = ctrl as BaseButton
		if not b.has_meta("_base_min_h"):
			b.set_meta("_base_min_h", b.custom_minimum_size.y)
			b.set_meta("_base_fs", b.get_theme_font_size("font_size") if b.has_theme_font_size_override("font_size") else 12)
		var bh: float = float(b.get_meta("_base_min_h"))
		var bfs: int = int(b.get_meta("_base_fs"))
		b.custom_minimum_size.y = maxf(68.0, bh * 1.65) if is_portrait else bh
		b.add_theme_font_size_override("font_size", maxi(20, int(round(float(bfs) * 1.75))) if is_portrait else bfs)
	elif ctrl is Label:
		var l: Label = ctrl as Label
		if not l.has_meta("_base_fs"):
			l.set_meta("_base_fs", l.get_theme_font_size("font_size") if l.has_theme_font_size_override("font_size") else 12)
		var lfs: int = int(l.get_meta("_base_fs"))
		l.add_theme_font_size_override("font_size", maxi(20, int(round(float(lfs) * 1.75))) if is_portrait else lfs)
	elif ctrl is LineEdit:
		var le: LineEdit = ctrl as LineEdit
		if not le.has_meta("_base_min_h"):
			le.set_meta("_base_min_h", le.custom_minimum_size.y)
		le.custom_minimum_size.y = 62.0 if is_portrait else float(le.get_meta("_base_min_h"))
		le.add_theme_font_size_override("font_size", 22 if is_portrait else 12)
	for ch in ctrl.get_children():
		_scale_overlay_typography(ch, is_portrait)


func _apply_responsive_ergonomics(mode: String) -> void:
	_current_layout_mode = mode
	var is_port: bool = (mode == "portrait")
	var is_wide: bool = (mode == "landscape_wide")

	# TopBar font, row split (3 rows in Portrait, 2 rows in Landscape/Desktop) & generous touch spacing
	var top_lbl_fs: int = 20 if is_port else (12 if is_wide else 12)
	var base_lbl_fs: int = 18 if is_port else (12 if is_wide else 11)
	var top_btn_h: float = 52.0 if is_port else (36.0 if is_wide else 26.0)
	var top_btn_fs: int = 17 if is_port else (12 if is_wide else 10)
	var speed_box_hbox := speed_pause_button.get_parent() as HBoxContainer if speed_pause_button != null else null
	if speed_box_hbox != null:
		speed_box_hbox.add_theme_constant_override("separation", 8 if is_port else (6 if is_wide else 3))
	for lbl in [top_status_label, wave_label, money_label, research_label, refineries_label, clock_label]:
		if lbl != null:
			lbl.add_theme_font_size_override("font_size", top_lbl_fs)
	if enemy_base_label != null:
		enemy_base_label.add_theme_font_size_override("font_size", base_lbl_fs)
		enemy_base_label.clip_text = is_port
	if enemy_base_bar != null:
		enemy_base_bar.custom_minimum_size = Vector2(180.0, 16.0) if is_port else Vector2(360.0, 10.0)
	var top_row2 := get_node_or_null("TopBar/VBox/Row2") as HBoxContainer
	var speed_box := speed_pause_button.get_parent() as Control if speed_pause_button != null else null
	if top_controls_row != null and top_row2 != null:
		var ctrl_items: Array[Control] = []
		if speed_box != null:
			ctrl_items.append(speed_box)
		for b in [auto_wave_button, level_picker_button, menu_button, sandbox_toggle_button, debug_button, fullscreen_button, download_button]:
			if b != null:
				ctrl_items.append(b)
		if is_port:
			top_controls_row.visible = true
			for ci in ctrl_items:
				if ci.get_parent() != top_controls_row:
					ci.reparent(top_controls_row)
				if ci != speed_box:
					ci.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			top_controls_row.visible = false
			for ci in ctrl_items:
				if ci.get_parent() != top_row2:
					ci.reparent(top_row2)
				if ci != speed_box:
					ci.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			if clock_label != null and clock_label.get_parent() == top_row2:
				top_row2.move_child(clock_label, top_row2.get_child_count() - 1)
	for tb in [speed_pause_button, speed_1x_button, speed_2x_button, speed_3x_button, auto_wave_button, level_picker_button, menu_button, debug_button, fullscreen_button, download_button, sandbox_toggle_button]:
		if tb != null:
			tb.custom_minimum_size.y = top_btn_h
			tb.add_theme_font_size_override("font_size", top_btn_fs)
	if is_port:
		speed_pause_button.custom_minimum_size.x = 56.0
		speed_1x_button.custom_minimum_size.x = 68.0
		speed_2x_button.custom_minimum_size.x = 56.0
		speed_3x_button.custom_minimum_size.x = 68.0
		if auto_wave_button != null:
			auto_wave_button.custom_minimum_size.x = 0.0
		level_picker_button.custom_minimum_size.x = 0.0
		menu_button.custom_minimum_size.x = 0.0
		debug_button.custom_minimum_size.x = 0.0
		fullscreen_button.custom_minimum_size.x = 0.0
		download_button.custom_minimum_size.x = 0.0
		if sandbox_toggle_button != null:
			sandbox_toggle_button.custom_minimum_size.x = 0.0
	else:
		speed_pause_button.custom_minimum_size.x = 44.0 if is_wide else 30.0
		speed_1x_button.custom_minimum_size.x = 54.0 if is_wide else 34.0
		speed_2x_button.custom_minimum_size.x = 44.0 if is_wide else 28.0
		speed_3x_button.custom_minimum_size.x = 54.0 if is_wide else 34.0
		if auto_wave_button != null:
			auto_wave_button.custom_minimum_size.x = 64.0 if is_wide else 56.0
		level_picker_button.custom_minimum_size.x = 86.0 if is_wide else 80.0
		menu_button.custom_minimum_size.x = 52.0 if is_wide else 46.0
		debug_button.custom_minimum_size.x = 42.0 if is_wide else 36.0
		fullscreen_button.custom_minimum_size.x = 42.0 if is_wide else 36.0
		download_button.custom_minimum_size.x = 64.0 if is_wide else 58.0
		if sandbox_toggle_button != null:
			sandbox_toggle_button.custom_minimum_size.x = 84.0

	# Shop, Tower, Bottom & Overlay Responsive Grids (multi-col chunky cards on Portrait so nothing is elongated!)
	if start_level_grid != null:
		start_level_grid.columns = 3 if is_port else 5
	if start_action_grid != null:
		start_action_grid.columns = 2 if is_port else 5
		if start_download_button != null:
			start_download_button.custom_minimum_size.x = 0.0 if is_port else 128.0
		if start_analytics_button != null:
			start_analytics_button.custom_minimum_size.x = 0.0 if is_port else 124.0
	if pause_extra_grid != null:
		pause_extra_grid.columns = 2 if is_port else 5
	if analytics_btns_grid != null:
		analytics_btns_grid.columns = 2 if is_port else 5
		if analytics_reset_button != null:
			analytics_reset_button.custom_minimum_size.x = 0.0 if is_port else 116.0
	var bl_title := get_node_or_null("BetweenLevelsOverlay/Margin/VBox/TitleLabel") as Label
	if bl_title != null:
		bl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bl_meta := get_node_or_null("BetweenLevelsOverlay/Margin/VBox/MetaResearchStatusLabel") as Label
	if bl_meta != null:
		bl_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for lb in [level_1_button, level_2_button, level_3_button, level_4_button, level_5_button]:
		if lb != null:
			lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if build_buttons_grid != null:
		build_buttons_grid.columns = 2 if (is_port or is_wide) else 1
		build_buttons_grid.add_theme_constant_override("h_separation", 12 if is_port else (8 if is_wide else 6))
		build_buttons_grid.add_theme_constant_override("v_separation", 10 if is_port else (6 if is_wide else 4))
	if tower_buttons_grid != null:
		tower_buttons_grid.columns = 2 if (is_port or is_wide) else 1
		tower_buttons_grid.add_theme_constant_override("h_separation", 12 if is_port else (8 if is_wide else 6))
		tower_buttons_grid.add_theme_constant_override("v_separation", 10 if is_port else (6 if is_wide else 4))
	if bottom_actions_grid != null:
		bottom_actions_grid.columns = 3 if is_port else 6
		bottom_actions_grid.add_theme_constant_override("h_separation", 12 if is_port else 8)
		bottom_actions_grid.add_theme_constant_override("v_separation", 10 if is_port else 6)

	var shop_btn_h: float = 88.0 if is_port else (48.0 if is_wide else 28.0)
	var shop_btn_fs: int = 22 if is_port else (14 if is_wide else 11)
	var shop_lbl_fs: int = 21 if is_port else (13 if is_wide else 11)
	for sb in [build_blaster_button, build_mortar_button, build_laser_button, build_slow_button, build_railgun_button, build_annihilator_button, build_recipes_button, target_mode_button, upg_dmg_button, upg_rng_button, upg_spd_button, combine_button, sell_button, manip_upgrade_button, refinery_tech_button]:
		if sb != null:
			sb.custom_minimum_size.y = shop_btn_h
			sb.add_theme_font_size_override("font_size", shop_btn_fs)
	for sl in [preview_title_label, preview_body_label, preview_mutations_label, wave_summary_label, build_pad_label, tower_header_label, tower_ratings_label, tower_status_label, manip_status_label]:
		if sl != null:
			sl.add_theme_font_size_override("font_size", shop_lbl_fs)
	var meta_hint := get_node_or_null("RightPanel/Margin/VBox/Scroll/ContentVBox/MetaHintLabel") as Label
	if meta_hint != null:
		meta_hint.add_theme_font_size_override("font_size", 18 if is_port else 10)
	hover_info_panel.custom_minimum_size.y = 96.0 if is_port else (44.0 if is_wide else 44.0)
	var hclip := hover_info_panel.get_node_or_null("HoverMargin/HoverClip") as Control
	if hclip != null:
		hclip.custom_minimum_size.y = 82.0 if is_port else (34.0 if is_wide else 34.0)
	hover_info_label.add_theme_font_size_override("font_size", 20 if is_port else (12 if is_wide else 11))

	# BottomBar labels & Surge bar
	var bot_lbl_fs: int = 19 if is_port else (13 if is_wide else 12)
	surge_label.add_theme_font_size_override("font_size", bot_lbl_fs)
	surge_label.clip_text = is_port
	surge_penalty_label.add_theme_font_size_override("font_size", bot_lbl_fs)
	event_feed_label.add_theme_font_size_override("font_size", 18 if is_port else 12)
	surge_bar.custom_minimum_size = Vector2(210.0 if is_port else 320.0, 30.0 if is_port else (16.0 if is_wide else 22.0))
	var bot_vbox_erg := get_node_or_null("BottomBar/VBox") as VBoxContainer
	if bot_vbox_erg != null:
		bot_vbox_erg.add_theme_constant_override("separation", 6 if is_port else (3 if is_wide else 6))

	# Overlays typography (GuidePanel full-screen interposing layout is styled directly in _position_guide_panel)
	for ov in [start_menu_overlay, pause_overlay, between_levels_overlay, end_overlay, recipes_overlay, analytics_overlay]:
		_scale_overlay_typography(ov, is_port)


func _position_guide_panel(vp_size: Vector2) -> void:
	if guide_panel == null:
		return
	# Cover the entire game viewport so Vex dramatically interposes over gameplay (~1/4-screen character bust!)
	_place_overlay_exact(guide_panel, Vector2.ZERO, vp_size)
	if guide_backdrop != null:
		_place_overlay_exact(guide_backdrop, Vector2.ZERO, vp_size)

	if vp_size.x <= 1285.0 and vp_size.y <= 725.0:
		# Desktop 1280x720: Vex bust 400x520 (~22.6% of viewport) on left, bold speech box on right
		_place_overlay_exact(guide_portrait, Vector2(28.0, 178.0), Vector2(400.0, 520.0))
		_place_overlay_exact(guide_speech_box, Vector2(440.0, 270.0), Vector2(804.0, 360.0))
		if guide_tag_label != null:
			guide_tag_label.add_theme_font_size_override("font_size", 11)
		guide_title_label.add_theme_font_size_override("font_size", 19)
		guide_body_label.add_theme_font_size_override("font_size", 17)
		guide_ack_button.custom_minimum_size = Vector2(0.0, 50.0)
		guide_ack_button.add_theme_font_size_override("font_size", 16)
		guide_dismiss_button.custom_minimum_size = Vector2(180.0, 50.0)
		guide_dismiss_button.add_theme_font_size_override("font_size", 15)
	elif vp_size.x >= vp_size.y:
		# Phone / Wide Landscape (e.g. 1600x720): Vex bust ~460x548 (~22% of viewport) on left, spacious speech box on right
		var char_w: float = clampf(vp_size.x * 0.29, 380.0, 480.0)
		var char_h: float = clampf(vp_size.y * 0.76, 460.0, 560.0)
		var char_x: float = clampf(vp_size.x * 0.022, 20.0, 48.0)
		var char_y: float = vp_size.y - char_h - 14.0
		_place_overlay_exact(guide_portrait, Vector2(char_x, char_y), Vector2(char_w, char_h))
		var box_x: float = char_x + char_w + 18.0
		var box_w: float = maxf(420.0, vp_size.x - box_x - 36.0)
		var box_h: float = clampf(vp_size.y * 0.54, 340.0, 410.0)
		var box_y: float = clampf(vp_size.y * 0.30, 140.0, vp_size.y - box_h - 32.0)
		_place_overlay_exact(guide_speech_box, Vector2(box_x, box_y), Vector2(box_w, box_h))
		if guide_tag_label != null:
			guide_tag_label.add_theme_font_size_override("font_size", 13)
		guide_title_label.add_theme_font_size_override("font_size", 21)
		guide_body_label.add_theme_font_size_override("font_size", 19)
		guide_ack_button.custom_minimum_size = Vector2(0.0, 58.0)
		guide_ack_button.add_theme_font_size_override("font_size", 18)
		guide_dismiss_button.custom_minimum_size = Vector2(210.0, 58.0)
		guide_dismiss_button.add_theme_font_size_override("font_size", 17)
	else:
		# Phone Portrait (e.g. 1280x2844): Giant ~860x1000 Vex bust (~23.6% of viewport) centered above bold speech card!
		var p_char_w: float = clampf(vp_size.x * 0.68, 520.0, 880.0)
		var p_char_h: float = clampf(vp_size.y * 0.35, 580.0, 1020.0)
		var p_char_x: float = floorf((vp_size.x - p_char_w) * 0.5)
		var p_char_y: float = clampf(vp_size.y * 0.13, 180.0, 420.0)
		_place_overlay_exact(guide_portrait, Vector2(p_char_x, p_char_y), Vector2(p_char_w, p_char_h))
		var p_box_w: float = vp_size.x - 100.0
		var p_box_h: float = clampf(vp_size.y * 0.29, 540.0, 840.0)
		var p_box_y: float = minf(p_char_y + p_char_h + 18.0, vp_size.y - p_box_h - 40.0)
		_place_overlay_exact(guide_speech_box, Vector2(50.0, p_box_y), Vector2(p_box_w, p_box_h))
		if guide_tag_label != null:
			guide_tag_label.add_theme_font_size_override("font_size", 20)
		guide_title_label.add_theme_font_size_override("font_size", 30)
		guide_body_label.add_theme_font_size_override("font_size", 27)
		guide_ack_button.custom_minimum_size = Vector2(0.0, 96.0)
		guide_ack_button.add_theme_font_size_override("font_size", 26)
		guide_dismiss_button.custom_minimum_size = Vector2(310.0, 96.0)
		guide_dismiss_button.add_theme_font_size_override("font_size", 24)


func _center_overlay(ctrl: Control, vp_size: Vector2, default_size: Vector2) -> void:
	if ctrl == null:
		return
	var w: float = minf(default_size.x, maxf(300.0, vp_size.x - 24.0))
	var h: float = minf(default_size.y, maxf(260.0, vp_size.y - 24.0))
	var target_size := Vector2(w, h)
	var target_pos := Vector2(floorf((vp_size.x - w) * 0.5), floorf((vp_size.y - h) * 0.5))
	ctrl.position = target_pos
	ctrl.size = target_size
	ctrl.set_deferred("position", target_pos)
	ctrl.set_deferred("size", target_size)


func _place_overlay_exact(ctrl: Control, pos: Vector2, sz: Vector2) -> void:
	if ctrl == null:
		return
	ctrl.position = pos
	ctrl.size = sz
	ctrl.set_deferred("position", pos)
	ctrl.set_deferred("size", sz)


func apply_responsive_layout(vp_size: Vector2) -> void:
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	if AnalyticsManager != null:
		AnalyticsManager.record_viewport_profile(vp_size, DisplayServer.is_touchscreen_available())
	var bg := get_parent().get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.position = Vector2.ZERO
		bg.size = vp_size

	var use_touch_landscape: bool = (force_touch_ui or _seen_touch_input or DisplayServer.is_touchscreen_available())
	# 1) Non-touch Desktop 16:9 (1280x720) — preserve exact desktop coordinates & RightPanel (340x480)
	if vp_size.x <= 1285.0 and vp_size.y <= 725.0 and not use_touch_landscape:
		_apply_responsive_ergonomics("desktop")
		_apply_bar_safe_margins(top_bar, -2.0)
		_apply_bar_safe_margins(bottom_bar, 2.0)
		_set_bottom_button_widths(1.0, 56.0, 10, false)
		top_bar.position = Vector2.ZERO
		top_bar.size = Vector2(1280.0, 64.0)
		bottom_bar.position = Vector2(0.0, 544.0)
		bottom_bar.size = Vector2(1280.0, 176.0)
		right_panel.custom_minimum_size = Vector2(340.0, 480.0)
		right_panel.position = Vector2(940.0, 64.0)
		right_panel.size = Vector2(340.0, 480.0)
		right_panel.set_deferred("size", Vector2(340.0, 480.0))
		if map_ref != null:
			map_ref.set_viewport_margins(0.0, 0.0)
			map_ref.set_base_layout(Rect2(0.0, 64.0, 940.0, 480.0), Vector2(0.0, 64.0), 1.0)
		if zoom_bar != null:
			_place_overlay_exact(zoom_bar, Vector2(940.0 - 144.0, 68.0), Vector2(138.0, 32.0))
			for zb in [zoom_out_button, zoom_reset_button, zoom_in_button]:
				if zb != null:
					zb.custom_minimum_size = Vector2(34.0, 24.0)
					zb.add_theme_font_size_override("font_size", 11)
		if wave_intel_button != null:
			wave_intel_button.custom_minimum_size = Vector2(104.0, 24.0)
			wave_intel_button.add_theme_font_size_override("font_size", 11)
		if wave_intel_card != null:
			var intel_w_d: float = minf(690.0, 940.0 - 156.0 - 10.0)
			wave_intel_card.position = Vector2(10.0, 68.0)
			wave_intel_card.custom_minimum_size = Vector2(intel_w_d, 0.0)
			wave_intel_card.size = Vector2(intel_w_d, wave_intel_card.get_combined_minimum_size().y)
			_last_wave_intel_sig = ""
			_refresh_wave_intel_card()
		surge_banner.position = Vector2(150.0, 68.0)
		surge_banner.size = Vector2(410.0, 42.0)
		prompt_banner.position = Vector2(572.0, 68.0)
		prompt_banner.size = Vector2(362.0, 54.0)
		_place_overlay_exact(pause_overlay, Vector2(240.0, 120.0), Vector2(800.0, 400.0))
		_place_overlay_exact(between_levels_overlay, Vector2(220.0, 86.0), Vector2(840.0, 444.0))
		_place_overlay_exact(end_overlay, Vector2(340.0, 150.0), Vector2(600.0, 360.0))
		_place_overlay_exact(start_menu_overlay, Vector2(180.0, 22.0), Vector2(920.0, 548.0))
		_place_overlay_exact(recipes_overlay, Vector2(150.0, 74.0), Vector2(980.0, 560.0))
		_place_overlay_exact(analytics_overlay, Vector2(140.0, 68.0), Vector2(1000.0, 570.0))
		_place_overlay_exact(citadel_overlay, Vector2(140.0, 68.0), Vector2(1000.0, 560.0))
		_position_guide_panel(vp_size)
		debug_panel.position = Vector2(16.0, 74.0)
		if sandbox_panel != null:
			sandbox_panel.position = Vector2(12.0, 70.0)
		if enemy_inspector_panel != null:
			enemy_inspector_panel.position = Vector2(12.0, bottom_bar.position.y - 98.0)
		_reposition_comms_toast()
		return

	# 2) Phone / Touch Landscape & Widescreen (1280x720 Touch AND Pixel 11 Pro 20:9 1600x720)
	# Tight vertical bar padding (70px top + 132px bottom) maximizes battlefield zoom (>1.07x on 20:9 phones!)
	# while giving RightPanel a generous 460px 2-column zero-scroll touch grid and bigger 74px bottom buttons!
	if vp_size.x >= vp_size.y:
		_apply_responsive_ergonomics("landscape_wide")
		var top_h: float = 74.0
		var bot_h: float = 108.0
		var rp_w: float = 460.0 if vp_size.x >= 1460.0 else (420.0 if vp_size.x >= 1360.0 else 368.0)
		var safe_x: float = clampf((vp_size.x - 1280.0) * 0.06, 0.0, 24.0)
		_apply_bar_safe_margins(top_bar, safe_x)
		_apply_bar_safe_margins(bottom_bar, safe_x)

		top_bar.position = Vector2.ZERO
		top_bar.size = Vector2(vp_size.x, top_h)

		bottom_bar.position = Vector2(0.0, vp_size.y - bot_h)
		_set_bottom_button_widths(clampf(vp_size.x / 1280.0, 1.0, 1.24), 74.0, 13, false)
		bottom_bar.size = Vector2(vp_size.x, bot_h)

		var middle_h: float = maxf(460.0, vp_size.y - top_h - bot_h)
		right_panel.custom_minimum_size = Vector2(rp_w, middle_h)
		right_panel.position = Vector2(vp_size.x - rp_w, top_h)
		right_panel.size = Vector2(rp_w, middle_h)

		var avail_w: float = maxf(300.0, vp_size.x - rp_w)
		var avail_h: float = middle_h
		var map_scale: float = minf(avail_w / GameMap.MAP_WIDTH, avail_h / GameMap.MAP_HEIGHT)
		var extra_w: float = maxf(0.0, (avail_w / map_scale) - GameMap.MAP_WIDTH)
		var extra_left: float = floorf(extra_w * 0.5)
		var extra_right: float = extra_w - extra_left
		var map_y: float = top_h + floorf((avail_h - GameMap.MAP_HEIGHT * map_scale) * 0.5)
		if map_ref != null:
			map_ref.set_viewport_margins(extra_left, extra_right)
			map_ref.set_base_layout(Rect2(0.0, top_h, avail_w, avail_h), Vector2(extra_left * map_scale, map_y), map_scale)
		if zoom_bar != null:
			_place_overlay_exact(zoom_bar, Vector2(right_panel.position.x - 186.0, top_h + 6.0), Vector2(178.0, 44.0))
			for zb in [zoom_out_button, zoom_reset_button, zoom_in_button]:
				if zb != null:
					zb.custom_minimum_size = Vector2(46.0, 36.0)
					zb.add_theme_font_size_override("font_size", 14)
		if wave_intel_button != null:
			wave_intel_button.custom_minimum_size = Vector2(128.0, 28.0)
			wave_intel_button.add_theme_font_size_override("font_size", 12)
		if wave_intel_card != null:
			var intel_x_l: float = safe_x + 12.0
			var intel_w_l: float = minf(760.0, maxf(340.0, right_panel.position.x - 196.0 - intel_x_l))
			wave_intel_card.position = Vector2(intel_x_l, top_h + 6.0)
			wave_intel_card.custom_minimum_size = Vector2(intel_w_l, 0.0)
			wave_intel_card.size = Vector2(intel_w_l, wave_intel_card.get_combined_minimum_size().y)
			_last_wave_intel_sig = ""
			_refresh_wave_intel_card()

		surge_banner.position = Vector2(safe_x + 12.0, top_h + 6.0)
		surge_banner.size = Vector2(410.0, 42.0)
		prompt_banner.position = Vector2(maxf(safe_x + 12.0, right_panel.position.x - 368.0), top_h + 6.0)
		prompt_banner.size = Vector2(362.0, 54.0)
		_center_overlay(pause_overlay, vp_size, Vector2(820.0, 420.0))
		_center_overlay(between_levels_overlay, vp_size, Vector2(920.0, 480.0))
		_center_overlay(end_overlay, vp_size, Vector2(660.0, 420.0))
		var sm_w: float = minf(1060.0, vp_size.x - 40.0)
		_place_overlay_exact(start_menu_overlay, Vector2(floorf((vp_size.x - sm_w) * 0.5), 22.0), Vector2(sm_w, 546.0))
		_center_overlay(recipes_overlay, vp_size, Vector2(1040.0, 560.0))
		_center_overlay(analytics_overlay, vp_size, Vector2(1060.0, 570.0))
		_center_overlay(citadel_overlay, vp_size, Vector2(1060.0, 570.0))
		_position_guide_panel(vp_size)
		debug_panel.position = Vector2(safe_x + 16.0, top_h + 10.0)
		if sandbox_panel != null:
			sandbox_panel.position = Vector2(safe_x + 12.0, top_h + 8.0)
		if enemy_inspector_panel != null:
			enemy_inspector_panel.position = Vector2(safe_x + 12.0, bottom_bar.position.y - 98.0)
		_reposition_comms_toast()
		return

	# 3) Phone Portrait Ergonomic Layout (e.g. 1280x2844 — 3-row TopBar, 2-col chunky shop cards, 3x2 bottom bar, large readable fonts!)
	_apply_responsive_ergonomics("portrait")
	var safe_top: float = 36.0
	var safe_bot: float = 20.0
	var p_top_h: float = 160.0
	var p_bot_h: float = 376.0
	_apply_bar_safe_margins(top_bar, 10.0)
	_apply_bar_safe_margins(bottom_bar, 10.0)

	top_bar.position = Vector2(0.0, safe_top)
	top_bar.size = Vector2(vp_size.x, p_top_h)

	var bot_y: float = vp_size.y - safe_bot - p_bot_h
	var max_map_h: float = maxf(320.0, bot_y - (safe_top + p_top_h) - 520.0)
	var p_scale: float = minf(vp_size.x / GameMap.MAP_WIDTH, max_map_h / GameMap.MAP_HEIGHT)
	var map_h: float = GameMap.MAP_HEIGHT * p_scale
	if map_ref != null:
		var map_x: float = floorf(maxf(0.0, (vp_size.x - GameMap.MAP_WIDTH * p_scale) * 0.5))
		map_ref.set_viewport_margins(0.0, 0.0)
		map_ref.set_base_layout(Rect2(0.0, safe_top + p_top_h, vp_size.x, map_h), Vector2(map_x, safe_top + p_top_h), p_scale)
	if zoom_bar != null:
		_place_overlay_exact(zoom_bar, Vector2(vp_size.x - 252.0, safe_top + p_top_h + 8.0), Vector2(240.0, 62.0))
		for zb in [zoom_out_button, zoom_reset_button, zoom_in_button]:
			if zb != null:
				zb.custom_minimum_size = Vector2(64.0, 52.0)
				zb.add_theme_font_size_override("font_size", 20)
	if wave_intel_button != null:
		wave_intel_button.custom_minimum_size = Vector2(190.0, 44.0)
		wave_intel_button.add_theme_font_size_override("font_size", 18)
	if wave_intel_card != null:
		var intel_w_p: float = maxf(460.0, vp_size.x - 280.0)
		wave_intel_card.position = Vector2(16.0, safe_top + p_top_h + 8.0)
		wave_intel_card.custom_minimum_size = Vector2(intel_w_p, 0.0)
		wave_intel_card.size = Vector2(intel_w_p, wave_intel_card.get_combined_minimum_size().y)
		_last_wave_intel_sig = ""
		_refresh_wave_intel_card()

	bottom_bar.position = Vector2(0.0, bot_y)
	_set_bottom_button_widths(1.0, 108.0, 20, true)
	bottom_bar.size = Vector2(vp_size.x, p_bot_h)

	var rp_top: float = safe_top + p_top_h + map_h
	var rp_h: float = maxf(400.0, bot_y - rp_top)
	right_panel.custom_minimum_size = Vector2(0.0, 400.0)
	right_panel.position = Vector2(0.0, rp_top)
	right_panel.size = Vector2(vp_size.x, rp_h)

	surge_banner.position = Vector2(20.0, safe_top + p_top_h + 10.0)
	surge_banner.size = Vector2(minf(480.0, vp_size.x * 0.42), 56.0)
	prompt_banner.position = Vector2(maxf(16.0, vp_size.x - 378.0), rp_top + 8.0)
	prompt_banner.size = Vector2(362.0, 54.0)
	_center_overlay(pause_overlay, vp_size, Vector2(1180.0, 960.0))
	_center_overlay(between_levels_overlay, vp_size, Vector2(1180.0, 1180.0))
	_center_overlay(end_overlay, vp_size, Vector2(1140.0, 920.0))
	_place_overlay_exact(start_menu_overlay, Vector2(40.0, 280.0), Vector2(vp_size.x - 80.0, 1480.0))
	_center_overlay(recipes_overlay, vp_size, Vector2(1180.0, 1460.0))
	_center_overlay(analytics_overlay, vp_size, Vector2(1180.0, 1520.0))
	_center_overlay(citadel_overlay, vp_size, Vector2(1180.0, 1520.0))
	_position_guide_panel(vp_size)
	debug_panel.position = Vector2(16.0, safe_top + p_top_h + 10.0)
	if sandbox_panel != null:
		sandbox_panel.position = Vector2(16.0, safe_top + p_top_h + 8.0)
	_reposition_comms_toast()
	if enemy_inspector_panel != null:
		enemy_inspector_panel.position = Vector2(20.0, bottom_bar.position.y - 120.0)


func _on_selection_cleared() -> void:
	_selected_pad_idx = -1
	_selected_tower = null
	_tapped_info_button = null
	_sell_confirm_armed = false
	if _right_scroll != null:
		_right_scroll.scroll_vertical = 0
	_refresh_selection_panel()
	_refresh_hover_info()


func _on_wave_summary_updated(summary_text: String) -> void:
	_last_summary_text = summary_text


func _on_wave_state_changed(new_state: int) -> void:
	if new_state == WaveManager.State.SPAWNING:
		_wave_intel_pinned_in_combat = false
	elif new_state == WaveManager.State.BUILD:
		_wave_intel_hidden_for_wave = -1
		_wave_intel_pinned_in_combat = false
		var w_now: int = GameState.mission.wave_number
		if w_now != _comms_last_wave_banter and wave_manager_ref != null:
			_comms_last_wave_banter = w_now
			var prev_d: Dictionary = wave_manager_ref.get_preview_data(w_now)
			var cnts: Dictionary = prev_d.get("counts", {})
			if cnts.has("stalker") and w_now == 11:
				show_chrono_comms("cloak_wave", true)
			elif str(prev_d.get("exam_title", "")) != "":
				show_chrono_comms("exam_wave", true)
			elif cnts.has("juggernaut") or cnts.has("colossus"):
				show_chrono_comms("boss_wave", true)
	_last_wave_intel_sig = ""
	_check_teaching_prompt()
	_refresh_all()


func _populate_how_time_works() -> void:
	how_time_works_label.text = "\n".join([
		"HOW TIME DEFENSE WORKS (v3.0):",
		"1. TIME FREEZE ($75): Freeze all aliens while towers keep firing! Upgrade T1-T5 for Cloaked reveal, +40% brittle dmg & shatter.",
		"2. OVERCLOCK ($60): Supercharge tower fire & build speed! Upgrade T1-T5 for +125% speed, +30% bonus dmg & instant builds.",
		"3. TEMPORAL REWIND ($100): Yank ALL active aliens 18%-48% BACKWARD along the path! Upgrades strip shields/regen, deal Paradox dmg & stun.",
		"4. ZERO SURGE & ZERO MUTATIONS: Time Abilities are purely tactical — no reactor penalties or permanent alien buffs!",
		"5. CHRONO-CITADEL ASCENSION: Tap your Base or the Citadel button to awaken Stage 1-3 Super-Weapons (with optional Sun-God Tower Sacrifices!).",
		"6. MILESTONE & ENDLESS: Clear Wave 40 to earn your Sector Medal, then push Endless Freeplay for your Best Wave record!",
	])


func show_guide_startup() -> void:
	if guide_panel == null or GameState.prompts_muted or GameState.guide_completed:
		return
	_present_guide_beat(
		"startup",
		"CHRONO-COMMANDER VEX  —  STARTUP BRIEFING",
		"Commander! I'm Vex, your over-caffeinated Chrono-Tactician. Welcome to TimeDefense — where bending time is totally legal and aliens are allergic to lasers. Want me to walk you through your first mission, or are you too cool for a guide?",
		"excited",
		"Guide Me!"
	)


func trigger_guide_beat(beat_id: String) -> void:
	if guide_panel == null or GameState.prompts_muted or GameState.guide_completed or GameState.is_sandbox_mode:
		return
	if GameState.mission.shown_prompts.get(beat_id, false):
		return
	match beat_id:
		"first_combine":
			_present_guide_beat(
				"first_combine",
				"VEX  —  MAD SCIENCE UNLOCKED!",
				"Ooh, a tower fusion! Combined turrets save precious zone slots AND share one upgrade track. Tap '21 Recipes' anytime when you're ready to cook up even deadlier combos.",
				"proud",
				"Sweet!"
			)
		"first_boss":
			_present_guide_beat(
				"first_boss",
				"VEX  —  BOSS INCOMING!",
				"Heads up — big metal nightmare on the lane! Stack Piercing (180% vs Bosses) + Chrono Bubbles + PAUSE before it turns our Citadel into a pancake!",
				"alert",
				"Bring It On!"
			)
		"first_cloak":
			_present_guide_beat(
				"first_cloak",
				"VEX  —  CLOAKED PHASE STALKERS AHEAD!",
				"Warning, Commander! Wave 11 brings CLOAKED Phase Stalkers. Normal Blasters, Mortars & Annihilators CANNOT SEE them unless you upgrade Range to Lv2 (+CAMO & +25% bonus dmg) — or rely on Lasers, Chrono Slow, or Railguns!",
				"alert",
				"Sensors Ready!"
			)


func _release_guide_pause() -> void:
	if _guide_paused_game:
		_guide_paused_game = false
		if pause_overlay == null or not pause_overlay.visible:
			get_tree().paused = false


func _present_guide_beat(beat_id: String, title_txt: String, body_txt: String, mood: String = "smirk", ack_txt: String = "Got It!") -> void:
	if guide_panel == null:
		return
	if beat_id != "startup":
		GameState.mission.shown_prompts[beat_id] = true
	_current_guide_beat = beat_id
	prompt_banner.visible = false
	if guide_tag_label != null:
		guide_tag_label.text = "◀  CHRONO-COMMANDER VEX  //  WELCOME BRIEFING" if beat_id == "startup" else "◀  INCOMING CHRONO-TRANSMISSION  //  COMBAT PAUSED"
	guide_title_label.text = title_txt
	guide_body_label.text = body_txt
	guide_ack_button.text = ack_txt
	# Always bring full-screen Vex overlay to the very top of HUD
	if guide_panel.get_parent() == self:
		move_child(guide_panel, get_child_count() - 1)
	guide_panel.visible = true
	if beat_id != "startup" and not get_tree().paused:
		get_tree().paused = true
		_guide_paused_game = true
	if guide_portrait != null and guide_portrait.has_method("trigger_talk"):
		guide_portrait.trigger_talk(mood, 3.4)
	if AnalyticsManager != null:
		AnalyticsManager.record_guide_event("shown", beat_id)
	_position_guide_panel(_get_effective_viewport_size())


func _check_teaching_prompt() -> void:
	prompt_banner.visible = false
	if GameState.prompts_muted or GameState.guide_completed or GameState.is_sandbox_mode or GameState.mission.is_over or wave_manager_ref == null:
		return
	if start_menu_overlay != null and start_menu_overlay.visible:
		return
	var w: int = GameState.mission.wave_number
	var st: int = wave_manager_ref.state
	var beat_id: String = ""
	var title_txt: String = ""
	var body_txt: String = ""
	var mood: String = "smirk"

	if w == 1 and st == WaveManager.State.BUILD:
		beat_id = "w1_build"
		title_txt = "VEX (1/8)  —  LOCK & LOAD"
		body_txt = "First rule of surviving an alien invasion: spend that $200! Drag a Blaster or Laser Spire from the shop right into the glowing placement zones — then hit START WAVE when you're armed."
		mood = "excited"
	elif w == 1 and st == WaveManager.State.SPAWNING:
		beat_id = "w1_combat"
		title_txt = "VEX (2/8)  —  PACE & INTEL"
		body_txt = "Here they come! Default 1x speed is snappy (the old 3x!) — tap 0.5x up top if things get spicy, 1.5x if you're feeling bold, or || to pause-plan. Tap any alien on the path to inspect its armor!"
		mood = "smirk"
	elif w == 2 and st == WaveManager.State.BUILD:
		beat_id = "w2_build"
		title_txt = "VEX (3/8)  —  UPGRADE, FUSE & APEX!"
		body_txt = "Nice work! Upgrade your base towers first — once 2 towers share 3+ upgrade ranks, FUSE them into 1 of 21 powerhouse Combos, then save up for game-changing Tier-4 Perks & Tier-5 APEX OVERDRIVE!"
		mood = "excited"
	elif w == 2 and st == WaveManager.State.SPAWNING:
		beat_id = "w2_combat"
		title_txt = "VEX (4/8)  —  PAID TIME ABILITIES"
		body_txt = "Meet your Time Abilities below: TIME FREEZE ($75) locks aliens solid, OVERCLOCK ($60) supercharges fire & build speed, and TEMPORAL REWIND ($100) yanks aliens backward down the track! Zero Surges, zero permanent mutations!"
		mood = "smirk"
	elif w == 3 and st == WaveManager.State.BUILD:
		beat_id = "w3_build"
		title_txt = "VEX (5/8)  —  UPGRADE YOUR ABILITIES!"
		body_txt = "Tap your Citadel Base (or the Citadel button below) anytime to upgrade Time Freeze, Overclock & Temporal Rewind from Tier 1 all the way to Tier 5 — adding Brittle Freeze damage, Cloak reveal, and massive Path-Pushback!"
		mood = "excited"
		mood = "alert"
	elif w == 4 and st == WaveManager.State.BUILD:
		beat_id = "w4_build"
		title_txt = "VEX (6/8)  —  ARMOR CHEAT SHEET"
		body_txt = "Quick cheat sheet so you don't look silly: Lasers fry Standard swarms (150%) but bounce off Reflective shields (10%); Piercing Blasters & Annihilators shred Brutes & Bosses (180%); Chrono Bubbles slow packs & melt shields!"
		mood = "smirk"
	elif w == 5 and st == WaveManager.State.BUILD:
		beat_id = "w5_build"
		title_txt = "VEX (7/8)  —  REFINERY TECH & META LAB"
		body_txt = "Want to afford those $4k–$8k Apex Overdrives? Build a Refinery ($200), then upgrade Refinery Tech in the right panel: Chrono-Plant -> Temporal Bank (10% wave interest!) -> Singularity Mint!"
		mood = "proud"
	elif w == 6 and st == WaveManager.State.BUILD:
		beat_id = "w6_build"
		title_txt = "VEX (8/8)  —  AWAKEN THE CHRONO-CITADEL!"
		body_txt = "Final lesson: Clear Wave 40 for your Sector Medal, then keep pushing Endless Freeplay! Save up with Temporal Banks to awaken your Base itself through Stages 1-3 — even sacrificing towers to forge the ★ TRUE CHRONO-SINGULARITY!"
		mood = "proud"
	elif w == 10 and st == WaveManager.State.BUILD:
		trigger_guide_beat("first_boss")
		return
	elif w == 11 and st == WaveManager.State.BUILD:
		trigger_guide_beat("first_cloak")
		return

	if beat_id != "" and not GameState.mission.shown_prompts.get(beat_id, false):
		_present_guide_beat(beat_id, title_txt, body_txt, mood, "Got It!")


func _on_guide_ack_pressed() -> void:
	if guide_panel != null:
		guide_panel.visible = false
	_release_guide_pause()
	if _current_guide_beat == "startup":
		GameState.prompts_muted = false
		GameState.guide_completed = false
		if GameState.mission != null:
			GameState.mission.shown_prompts.clear()
		if pause_mute_check != null:
			pause_mute_check.button_pressed = false
	elif _current_guide_beat == "w6_build":
		GameState.guide_completed = true
		GameState.save_meta_progress()
		if AnalyticsManager != null:
			AnalyticsManager.record_guide_event("completed", _current_guide_beat)
	_current_guide_beat = ""


func _on_guide_dismiss_all_pressed() -> void:
	if AnalyticsManager != null:
		AnalyticsManager.record_guide_event("dismissed", _current_guide_beat)
	_current_guide_beat = ""
	_release_guide_pause()
	set_prompts_muted(true)


func _on_prompt_dismiss_pressed() -> void:
	prompt_banner.visible = false
	_on_guide_ack_pressed()


func _on_prompt_mute_pressed() -> void:
	_on_guide_dismiss_all_pressed()


func _on_pause_mute_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		GameState.guide_completed = false
	set_prompts_muted(toggled_on)


func set_prompts_muted(muted: bool) -> void:
	GameState.prompts_muted = muted
	if pause_mute_check.button_pressed != muted:
		pause_mute_check.button_pressed = muted
	if muted:
		prompt_banner.visible = false
		if guide_panel != null:
			guide_panel.visible = false
		_release_guide_pause()
	GameState.save_meta_progress()


func _toggle_pause_menu() -> void:
	if GameState.mission.is_over:
		return
	var next_paused: bool = not pause_overlay.visible
	pause_overlay.visible = next_paused
	get_tree().paused = next_paused or (_guide_paused_game and guide_panel != null and guide_panel.visible)
	if next_paused:
		_reapply_overlay_bounds()
		call_deferred("_reapply_overlay_bounds")


func _on_pause_restart_pressed() -> void:
	pause_overlay.visible = false
	get_tree().paused = false
	_on_restart_pressed()


func _on_mission_ended(outcome: String, reason: String) -> void:
	end_overlay.visible = true
	if end_endless_button != null:
		end_endless_button.visible = (outcome == "won" and not GameState.is_sandbox_mode)
	_reapply_overlay_bounds()
	call_deferred("_reapply_overlay_bounds")
	if outcome == "won":
		end_title_label.text = "★ SECTOR MILESTONE CLEARED (WAVE 40)!"
	else:
		end_title_label.text = "DEFEAT - CITADEL LOST (WAVE %d)" % GameState.mission.wave_number

	var m := GameState.mission
	var best_w: int = GameState.get_level_best_wave(GameState.selected_map_level)
	var review: Dictionary = ComedyLines.get_end_of_run_review(outcome, m)
	end_stats_label.text = "\n".join([
		"★ PERFORMANCE REVIEW: %s" % str(review.get("badge", "")),
		str(review.get("note", "")),
		"",
		reason,
		"Mission Time: %.1f s | Wave: %d | Waves Cleared: %d | Sector Best: Wave %d" % [
			GameState.mission_elapsed_seconds,
			m.wave_number,
			m.stats["waves_completed"],
			best_w,
		],
		"Time Abilities -> Freeze: %d (T%d) | Overclock: %d (T%d) | Rewind: %d (T%d)" % [
			m.stats["powers_used"]["pause"], GameState.get_ability_level("pause"),
			m.stats["powers_used"]["haste"], GameState.get_ability_level("haste"),
			m.stats["powers_used"]["rewind"], GameState.get_ability_level("rewind"),
		],
		"Chrono-Citadel -> Stage %d / 3 | Citadel Dmg: %d | Kills: %d" % [
			m.citadel_stage, int(round(m.citadel_total_damage)), m.citadel_total_kills
		],
		"Money Earned: $%d | Research Earned: %d R (Persistent Total: %d R)" % [
			m.stats["money_earned"],
			m.stats["research_earned"],
			GameState.meta_research,
		],
	])


func _on_mission_reset() -> void:
	end_overlay.visible = false
	if end_endless_button != null:
		end_endless_button.visible = false
	surge_banner.visible = false
	prompt_banner.visible = false
	pause_overlay.visible = false
	if guide_panel != null and _current_guide_beat != "startup":
		guide_panel.visible = false
		_current_guide_beat = ""
	if recipes_overlay != null:
		recipes_overlay.visible = false
	if analytics_overlay != null:
		analytics_overlay.visible = false
	if citadel_overlay != null:
		citadel_overlay.visible = false
	_selected_sacrifice_ids.clear()
	_sacrifice_refinery_checked = false
	if enemy_inspector_panel != null:
		enemy_inspector_panel.visible = false
	_guide_paused_game = false
	get_tree().paused = false
	_banner_timer = 0.0
	_last_summary_text = ""
	_wave_intel_hidden_for_wave = -1
	_wave_intel_pinned_in_combat = false
	_last_wave_intel_sig = ""
	if comms_toast_panel != null:
		comms_toast_panel.visible = false
	_comms_timer = 0.0
	_comms_cooldown = 0.0
	_comms_last_wave_banter = -1
	_selected_pad_idx = -1
	_selected_tower = null
	_inspected_enemy = null
	_hovered_button = null
	_tapped_info_button = null
	_sell_confirm_armed = false
	if pause_auto_wave_check != null:
		pause_auto_wave_check.button_pressed = GameState.auto_wave_enabled
	if pause_sfx_mute_check != null and SfxManager != null:
		pause_sfx_mute_check.button_pressed = SfxManager.muted
	if pause_dmg_popups_check != null:
		pause_dmg_popups_check.button_pressed = GameState.show_damage_numbers
	_event_feed.clear()
	event_feed_label.text = "Events: (none yet)"
	_check_teaching_prompt()
	_refresh_hover_info()


func _on_start_wave_pressed() -> void:
	if wave_manager_ref != null and wave_manager_ref.can_call_next_wave_early():
		if _early_call_armed_timer <= 0.0:
			_early_call_armed_timer = 3.0
			_refresh_all()
			return
		_early_call_armed_timer = 0.0
		wave_manager_ref.call_next_wave_early()
		_refresh_all()
		return
	_early_call_armed_timer = 0.0
	start_wave_requested.emit()


func _on_restart_pressed() -> void:
	GameState.reset_mission()
	restart_requested.emit()
