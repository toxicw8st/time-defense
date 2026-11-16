extends Node2D

@onready var map: GameMap = $Map
@onready var wave_manager: WaveManager = $WaveManager
@onready var economy_manager: EconomyManager = $EconomyManager
@onready var surge_manager: SurgeManager = $SurgeManager
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	wave_manager.setup(map)
	economy_manager.setup(map)
	surge_manager.setup(wave_manager)
	map.set_economy_ref(economy_manager)
	hud.set_references(map, wave_manager, economy_manager, surge_manager)
	hud.start_wave_requested.connect(_on_start_wave_requested)
	hud.restart_requested.connect(_on_restart_requested)


func _on_start_wave_requested() -> void:
	wave_manager.start_wave()


func _on_restart_requested() -> void:
	pass
