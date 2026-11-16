extends Node2D

@onready var map: GameMap = $Map
@onready var hud: CanvasLayer = $HUD

## Temporary Step 1 test spawner (20 Runners leaking in order).
## Replaced by WaveManager in Step 2.
@export var step1_auto_spawn: bool = true
var _step1_spawned: int = 0
var _step1_timer: float = 0.5


func _ready() -> void:
	hud.set_map_ref(map)
	hud.restart_requested.connect(_on_restart_requested)


func _process(delta: float) -> void:
	if not step1_auto_spawn or GameState.mission.is_over:
		return
	if _step1_spawned >= 20:
		return
	_step1_timer -= delta
	if _step1_timer <= 0.0:
		map.spawn_enemy("runner", 1)
		_step1_spawned += 1
		_step1_timer = 1.0


func _on_restart_requested() -> void:
	_step1_spawned = 0
	_step1_timer = 0.5
