extends Node2D

@onready var map: GameMap = $Map
@onready var wave_manager: WaveManager = $WaveManager
@onready var economy_manager: EconomyManager = $EconomyManager
@onready var surge_manager: SurgeManager = $SurgeManager
@onready var mutation_manager: MutationManager = $MutationManager
@onready var time_powers_manager: TimePowersManager = $TimePowersManager
@onready var base_attack_manager: BaseAttackManager = $BaseAttackManager
@onready var hud: CanvasLayer = $HUD
@onready var background: ColorRect = $Background


func _ready() -> void:
	wave_manager.setup(map)
	economy_manager.setup(map)
	surge_manager.setup(wave_manager)
	mutation_manager.setup()
	time_powers_manager.setup(map, wave_manager)
	base_attack_manager.setup(map)
	map.set_economy_ref(economy_manager)
	hud.set_references(map, wave_manager, economy_manager, surge_manager, time_powers_manager, base_attack_manager)
	hud.start_wave_requested.connect(_on_start_wave_requested)
	hud.restart_requested.connect(_on_restart_requested)
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_resized)
		_on_viewport_resized()
	if get_parent() == get_tree().root:
		hud.open_start_menu()


func _on_viewport_resized() -> void:
	if background != null and get_viewport() != null:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		background.position = Vector2.ZERO
		background.size = vp_size


func _on_start_wave_requested() -> void:
	wave_manager.start_wave()


func _on_restart_requested() -> void:
	pass
