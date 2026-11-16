extends Node2D

@onready var map: GameMap = $Map
@onready var hud: CanvasLayer = $HUD
@onready var wave_manager: WaveManager = $WaveManager


func _ready() -> void:
	wave_manager.setup(map)
	hud.set_references(map, wave_manager)
	hud.start_wave_requested.connect(_on_start_wave_requested)
	hud.restart_requested.connect(_on_restart_requested)


func _on_start_wave_requested() -> void:
	wave_manager.start_wave()


func _on_restart_requested() -> void:
	pass
