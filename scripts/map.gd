extends Node2D
class_name GameMap

signal pad_clicked(pad_index: int)

const MAP_WIDTH: float = 940.0
const MAP_HEIGHT: float = 480.0

const PATH_WAYPOINTS: Array[Vector2] = [
	Vector2(110, 75),
	Vector2(645, 75),
	Vector2(715, 130),
	Vector2(715, 185),
	Vector2(645, 240),
	Vector2(265, 240),
	Vector2(195, 295),
	Vector2(195, 350),
	Vector2(265, 405),
	Vector2(775, 405),
]

const BUILD_PAD_POSITIONS: Array[Vector2] = [
	Vector2(220, 32),
	Vector2(380, 32),
	Vector2(540, 32),
	Vector2(255, 157),
	Vector2(380, 157),
	Vector2(510, 157),
	Vector2(635, 157),
	Vector2(785, 115),
	Vector2(785, 220),
	Vector2(295, 322),
	Vector2(430, 322),
	Vector2(565, 322),
	Vector2(380, 449),
	Vector2(630, 449),
]

const ENEMY_BASE_POS: Vector2 = Vector2(58, 75)
const PLAYER_BASE_POS: Vector2 = Vector2(842, 405)
const REFINERY_ANNEX_RECT: Rect2 = Rect2(16, 195, 134, 268)
const PAD_SIZE: float = 36.0

@onready var enemy_path: Path2D = $EnemyPath
@onready var enemies_container: Node2D = $EnemiesContainer
@onready var towers_container: Node2D = $TowersContainer

var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var next_enemy_id: int = 1
var leak_flash_timer: float = 0.0
var hovered_pad_index: int = -1
var selected_pad_index: int = -1
var pad_occupancy: Array[Node] = []


func _ready() -> void:
	_build_path_curve()
	_reset_pad_occupancy()
	GameState.mission_reset.connect(_on_mission_reset)
	GameState.enemy_leaked.connect(_on_enemy_leaked)


func _process(delta: float) -> void:
	if leak_flash_timer > 0.0:
		leak_flash_timer = maxf(0.0, leak_flash_timer - delta)
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local_pos: Vector2 = get_local_mouse_position()
		var new_hover: int = _find_pad_at(local_pos)
		if new_hover != hovered_pad_index:
			hovered_pad_index = new_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = get_local_mouse_position()
		var clicked: int = _find_pad_at(local_pos)
		if clicked != -1:
			selected_pad_index = clicked
			pad_clicked.emit(clicked)
			queue_redraw()


func _build_path_curve() -> void:
	var curve := Curve2D.new()
	for pt in PATH_WAYPOINTS:
		curve.add_point(pt)
	enemy_path.curve = curve


func _reset_pad_occupancy() -> void:
	pad_occupancy.clear()
	for i in range(BUILD_PAD_POSITIONS.size()):
		pad_occupancy.append(null)


func _on_mission_reset() -> void:
	clear_all_enemies()
	leak_flash_timer = 0.0
	selected_pad_index = -1
	queue_redraw()


func _on_enemy_leaked(_enemy_type: String, _lives_lost: int, _world_pos: Vector2) -> void:
	leak_flash_timer = 0.35
	queue_redraw()


func get_path_length() -> float:
	if enemy_path == null or enemy_path.curve == null:
		return 0.0
	return enemy_path.curve.get_baked_length()


func spawn_enemy(enemy_type: String, wave_num: int) -> EnemyUnit:
	var enemy: EnemyUnit = enemy_scene.instantiate()
	enemies_container.add_child(enemy)
	enemy.setup(next_enemy_id, enemy_type, wave_num, enemy_path.curve)
	next_enemy_id += 1
	enemy.leaked.connect(_on_unit_leaked)
	return enemy


func _on_unit_leaked(enemy: EnemyUnit) -> void:
	GameState.lose_lives(enemy.leak_cost, enemy.enemy_type, enemy.global_position)


func get_active_enemies() -> Array[EnemyUnit]:
	var list: Array[EnemyUnit] = []
	for child in enemies_container.get_children():
		if child is EnemyUnit and not child.is_dead_or_leaked:
			list.append(child)
	return list


func clear_all_enemies() -> void:
	for child in enemies_container.get_children():
		child.queue_free()


func _find_pad_at(local_pos: Vector2) -> int:
	var half: float = PAD_SIZE * 0.5
	for i in range(BUILD_PAD_POSITIONS.size()):
		var p: Vector2 = BUILD_PAD_POSITIONS[i]
		var rect := Rect2(p.x - half, p.y - half, PAD_SIZE, PAD_SIZE)
		if rect.has_point(local_pos):
			return i
	return -1


func _draw() -> void:
	# Map background
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_WIDTH, MAP_HEIGHT)), Color(0.09, 0.11, 0.16))
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_WIDTH, MAP_HEIGHT)), Color(0.22, 0.27, 0.36), false, 2.0)

	# Refinery Annex area (bottom-left, distinct from tower pads)
	draw_rect(REFINERY_ANNEX_RECT, Color(0.12, 0.15, 0.19))
	draw_rect(REFINERY_ANNEX_RECT, Color(0.32, 0.52, 0.46), false, 1.5)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, REFINERY_ANNEX_RECT.position + Vector2(8, 18), "REFINERY ANNEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.85, 0.78))

	# Draw pre-built/owned refineries in the annex
	var ref_count: int = GameState.mission.economy.get("refineries_owned", 0)
	for i in range(ref_count):
		var col: int = i % 2
		var row: int = i / 2
		var rx: float = REFINERY_ANNEX_RECT.position.x + 16.0 + float(col) * 56.0
		var ry: float = REFINERY_ANNEX_RECT.position.y + 32.0 + float(row) * 44.0
		if ry + 32.0 <= REFINERY_ANNEX_RECT.end.y:
			draw_rect(Rect2(Vector2(rx, ry), Vector2(44, 32)), Color(0.24, 0.55, 0.45))
			draw_rect(Rect2(Vector2(rx, ry), Vector2(44, 32)), Color(0.5, 0.9, 0.75), false, 1.5)
			draw_string(font, Vector2(rx + 10, ry + 21), "REF", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 1.0, 0.95))

	# Draw S-path
	if enemy_path != null and enemy_path.curve != null:
		var pts: PackedVector2Array = enemy_path.curve.get_baked_points()
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.18, 0.22, 0.30), 32.0)
			draw_polyline(pts, Color(0.28, 0.33, 0.42), 24.0)
			draw_polyline(pts, Color(0.42, 0.47, 0.58), 2.0)

	# Draw 14 build pads beside path
	var half: float = PAD_SIZE * 0.5
	for i in range(BUILD_PAD_POSITIONS.size()):
		var p: Vector2 = BUILD_PAD_POSITIONS[i]
		var rect := Rect2(p.x - half, p.y - half, PAD_SIZE, PAD_SIZE)
		var pad_col := Color(0.19, 0.26, 0.36)
		var border_col := Color(0.42, 0.56, 0.75)
		if i == selected_pad_index:
			border_col = Color(0.95, 0.85, 0.35)
		elif i == hovered_pad_index:
			pad_col = Color(0.25, 0.35, 0.48)
		draw_rect(rect, pad_col)
		draw_rect(rect, border_col, false, 2.0)
		draw_string(font, p + Vector2(-7, 4), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.78, 0.92))

	# Enemy Base marker (path start)
	var eb_rect := Rect2(ENEMY_BASE_POS - Vector2(28, 28), Vector2(56, 56))
	draw_rect(eb_rect, Color(0.45, 0.14, 0.18))
	draw_rect(eb_rect, Color(0.95, 0.35, 0.35), false, 2.5)
	draw_string(font, ENEMY_BASE_POS + Vector2(-24, -34), "HIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.65, 0.65))

	# Player Base (path end) with leak flash
	var pb_rect := Rect2(PLAYER_BASE_POS - Vector2(32, 32), Vector2(64, 64))
	var pb_fill := Color(0.14, 0.32, 0.52)
	var pb_border := Color(0.35, 0.78, 1.0)
	if leak_flash_timer > 0.0:
		pb_fill = Color(0.92, 0.22, 0.22)
		pb_border = Color(1.0, 0.85, 0.85)
	draw_rect(pb_rect, pb_fill)
	draw_rect(pb_rect, pb_border, false, 3.0)
	draw_string(font, PLAYER_BASE_POS + Vector2(-20, -38), "BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.92, 1.0))
