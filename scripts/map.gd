extends Node2D
class_name GameMap

signal pad_selected(pad_index: int)
signal tower_selected(tower: TowerUnit)
signal selection_cleared

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
@onready var towers_container: Node2D = $TowersContainer
@onready var enemies_container: Node2D = $EnemiesContainer
@onready var projectiles_container: Node2D = $ProjectilesContainer
@onready var effects_container: Node2D = $EffectsContainer

var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var tower_scene: PackedScene = preload("res://scenes/tower.tscn")

var next_enemy_id: int = 1
var next_tower_id: int = 1
var leak_flash_timer: float = 0.0
var hive_beam_timer: float = 0.0
var hovered_pad_index: int = -1
var selected_pad_index: int = -1
var selected_tower: TowerUnit = null
var preview_tower_type: String = ""
var pad_occupancy: Array[TowerUnit] = []
var floating_texts: Array[Dictionary] = []
var economy_ref: Node = null


func set_economy_ref(p_econ: Node) -> void:
	economy_ref = p_econ


func show_refinery_tick_floaters(owned_count: int) -> void:
	for i in range(owned_count):
		var col: int = i % 2
		var row: int = i / 2
		var rx: float = REFINERY_ANNEX_RECT.position.x + 24.0 + float(col) * 56.0
		var ry: float = REFINERY_ANNEX_RECT.position.y + 32.0 + float(row) * 44.0
		if ry <= REFINERY_ANNEX_RECT.end.y:
			spawn_floater(Vector2(rx, ry), "+%d$" % Balance.REFINERY_INCOME_PER_TICK, Color(0.55, 0.95, 0.65))


func trigger_hive_beam_effect() -> void:
	hive_beam_timer = 0.85
	spawn_floater(ENEMY_BASE_POS + Vector2(-20, -45), "-%d HP!" % Balance.BASE_ATTACK_TEST_DAMAGE_OVERRIDE, Color(1.0, 0.72, 0.25))
	queue_redraw()


func _ready() -> void:
	_build_path_curve()
	_reset_pad_occupancy()
	GameState.mission_reset.connect(_on_mission_reset)
	GameState.enemy_leaked.connect(_on_enemy_leaked)
	GameState.enemy_killed.connect(_on_enemy_killed)


func _exit_tree() -> void:
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)
	if GameState.enemy_leaked.is_connected(_on_enemy_leaked):
		GameState.enemy_leaked.disconnect(_on_enemy_leaked)
	if GameState.enemy_killed.is_connected(_on_enemy_killed):
		GameState.enemy_killed.disconnect(_on_enemy_killed)


func _process(delta: float) -> void:
	var needs_redraw: bool = false
	if leak_flash_timer > 0.0:
		leak_flash_timer = maxf(0.0, leak_flash_timer - delta)
		needs_redraw = true
	if hive_beam_timer > 0.0:
		hive_beam_timer = maxf(0.0, hive_beam_timer - delta)
		needs_redraw = true

	if not floating_texts.is_empty():
		for i in range(floating_texts.size() - 1, -1, -1):
			floating_texts[i]["timer"] -= delta
			floating_texts[i]["pos"] += Vector2(0.0, -24.0 * delta)
			if floating_texts[i]["timer"] <= 0.0:
				floating_texts.remove_at(i)
		needs_redraw = true

	if needs_redraw:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.mission.is_over:
		return
	var local_pos: Vector2 = get_local_mouse_position()
	var in_map: bool = Rect2(Vector2.ZERO, Vector2(MAP_WIDTH, MAP_HEIGHT)).has_point(local_pos)

	if event is InputEventMouseMotion:
		var new_hover: int = _find_pad_at(local_pos) if in_map else -1
		if new_hover != hovered_pad_index:
			hovered_pad_index = new_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not in_map:
			return
		var clicked_pad: int = _find_pad_at(local_pos)
		if clicked_pad != -1:
			select_pad(clicked_pad)
			get_viewport().set_input_as_handled()
		else:
			clear_selection()


func select_pad(pad_idx: int) -> void:
	selected_pad_index = pad_idx
	preview_tower_type = ""
	if selected_tower != null and is_instance_valid(selected_tower):
		selected_tower.is_selected = false
		selected_tower.queue_redraw()
	selected_tower = pad_occupancy[pad_idx]
	if selected_tower != null and is_instance_valid(selected_tower):
		selected_tower.is_selected = true
		selected_tower.queue_redraw()
		tower_selected.emit(selected_tower)
	else:
		selected_tower = null
		pad_selected.emit(pad_idx)
	queue_redraw()


func clear_selection() -> void:
	selected_pad_index = -1
	preview_tower_type = ""
	if selected_tower != null and is_instance_valid(selected_tower):
		selected_tower.is_selected = false
		selected_tower.queue_redraw()
	selected_tower = null
	selection_cleared.emit()
	queue_redraw()


func set_preview_tower_type(tower_type: String) -> void:
	preview_tower_type = tower_type
	queue_redraw()


func build_tower_on_pad(pad_idx: int, tower_type: String) -> TowerUnit:
	if pad_idx < 0 or pad_idx >= BUILD_PAD_POSITIONS.size():
		return null
	if pad_occupancy[pad_idx] != null:
		return null
	var cost: int = int(Balance.TOWERS[tower_type]["cost"])
	if not GameState.spend_money(cost):
		return null

	var tower: TowerUnit = tower_scene.instantiate()
	towers_container.add_child(tower)
	tower.setup(next_tower_id, tower_type, pad_idx, BUILD_PAD_POSITIONS[pad_idx], self)
	next_tower_id += 1
	pad_occupancy[pad_idx] = tower
	preview_tower_type = ""
	select_pad(pad_idx)
	queue_redraw()
	return tower


func sell_tower(tower: TowerUnit) -> int:
	if tower == null or not is_instance_valid(tower):
		return 0
	var refund: int = tower.get_sell_refund()
	var pad_idx: int = tower.pad_index
	if pad_idx >= 0 and pad_idx < pad_occupancy.size():
		pad_occupancy[pad_idx] = null
	GameState.add_money(refund, false)
	GameState.event_logged.emit("Sold %s on P%d (+%d money)" % [Balance.TOWERS[tower.tower_type]["name"], pad_idx + 1, refund])
	if selected_tower == tower:
		selected_tower = null
	tower.queue_free()
	if pad_idx >= 0:
		select_pad(pad_idx)
	else:
		clear_selection()
	queue_redraw()
	return refund


func get_all_towers() -> Array[TowerUnit]:
	var list: Array[TowerUnit] = []
	for t in pad_occupancy:
		if t != null and is_instance_valid(t):
			list.append(t)
	return list


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
	clear_all_towers()
	clear_all_projectiles()
	floating_texts.clear()
	leak_flash_timer = 0.0
	selected_pad_index = -1
	selected_tower = null
	preview_tower_type = ""
	next_enemy_id = 1
	next_tower_id = 1
	queue_redraw()


func _on_enemy_leaked(_enemy_type: String, _lives_lost: int, _world_pos: Vector2) -> void:
	leak_flash_timer = 0.35
	queue_redraw()


func _on_enemy_killed(_enemy_type: String, money_gained: int, research_gained: int, world_pos: Vector2) -> void:
	var local_p: Vector2 = to_local(world_pos)
	floating_texts.append({
		"pos": local_p + Vector2(-18.0, -14.0),
		"money_text": "+%d$" % money_gained,
		"research_text": "+%dR" % research_gained,
		"timer": 0.9,
		"max_timer": 0.9,
	})
	queue_redraw()


func spawn_floater(local_pos: Vector2, text: String, col: Color) -> void:
	floating_texts.append({
		"pos": local_pos,
		"custom_text": text,
		"custom_color": col,
		"timer": 0.9,
		"max_timer": 0.9,
	})
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
	enemy.died.connect(_on_unit_died)
	return enemy


func _on_unit_leaked(enemy: EnemyUnit) -> void:
	GameState.lose_lives(enemy.leak_cost, enemy.enemy_type, enemy.global_position)


func _on_unit_died(enemy: EnemyUnit) -> void:
	GameState.award_kill_earnings(enemy.enemy_type, enemy.money_on_kill, enemy.research_on_kill, enemy.global_position)


func get_active_enemies() -> Array[EnemyUnit]:
	var list: Array[EnemyUnit] = []
	for child in enemies_container.get_children():
		if child is EnemyUnit and not child.is_dead_or_leaked:
			list.append(child)
	return list


func clear_all_enemies() -> void:
	for child in enemies_container.get_children():
		if child is EnemyUnit:
			child.is_dead_or_leaked = true
		enemies_container.remove_child(child)
		child.queue_free()


func clear_all_towers() -> void:
	for child in towers_container.get_children():
		towers_container.remove_child(child)
		child.queue_free()
	_reset_pad_occupancy()


func clear_all_projectiles() -> void:
	for child in projectiles_container.get_children():
		projectiles_container.remove_child(child)
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

	if economy_ref != null and economy_ref.refinery_job != null:
		var i: int = ref_count
		var col: int = i % 2
		var row: int = i / 2
		var rx: float = REFINERY_ANNEX_RECT.position.x + 16.0 + float(col) * 56.0
		var ry: float = REFINERY_ANNEX_RECT.position.y + 32.0 + float(row) * 44.0
		if ry + 32.0 <= REFINERY_ANNEX_RECT.end.y:
			var center := Vector2(rx + 22.0, ry + 16.0)
			draw_rect(Rect2(Vector2(rx, ry), Vector2(44, 32)), Color(0.32, 0.35, 0.22))
			draw_rect(Rect2(Vector2(rx, ry), Vector2(44, 32)), Color(0.95, 0.82, 0.32), false, 1.5)
			var prog: float = economy_ref.refinery_job.get_progress()
			draw_arc(center, 14.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 24, Color(0.45, 0.95, 0.65), 2.5)
			draw_string(font, Vector2(rx + 6, ry + 21), "%.1fs" % economy_ref.refinery_job.remaining_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.92, 0.45))

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

	# Range ring preview during placement hover
	if preview_tower_type != "" and selected_pad_index >= 0 and selected_pad_index < BUILD_PAD_POSITIONS.size():
		var center: Vector2 = BUILD_PAD_POSITIONS[selected_pad_index]
		var cfg: Dictionary = Balance.TOWERS[preview_tower_type]
		var r: float = float(cfg["range"]) * GameState.get_tower_range_research_multiplier()
		var min_r: float = float(cfg.get("min_range", 0.0))
		draw_circle(center, r, Color(0.4, 0.85, 1.0, 0.08))
		draw_arc(center, r, 0.0, TAU, 48, Color(0.45, 0.85, 1.0, 0.65), 1.5)
		if min_r > 0.0:
			draw_circle(center, min_r, Color(1.0, 0.35, 0.35, 0.08))
			draw_arc(center, min_r, 0.0, TAU, 32, Color(1.0, 0.45, 0.45, 0.7), 1.5)

	# Enemy Base marker (path start)
	var eb_rect := Rect2(ENEMY_BASE_POS - Vector2(28, 28), Vector2(56, 56))
	var eb_fill := Color(0.98, 0.78, 0.25) if hive_beam_timer > 0.0 else Color(0.45, 0.14, 0.18)
	draw_rect(eb_rect, eb_fill)
	draw_rect(eb_rect, Color(0.95, 0.35, 0.35), false, 2.5)
	draw_string(font, ENEMY_BASE_POS + Vector2(-24, -34), "HIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.65, 0.65))

	# Hive Destroyer beam effect when firing
	if hive_beam_timer > 0.0:
		var b_alpha: float = clampf(hive_beam_timer / 0.85, 0.0, 1.0)
		draw_line(PLAYER_BASE_POS, ENEMY_BASE_POS, Color(0.35, 0.9, 1.0, b_alpha), 10.0)
		draw_line(PLAYER_BASE_POS, ENEMY_BASE_POS, Color(1.0, 0.98, 0.75, b_alpha), 4.0)
		draw_circle(ENEMY_BASE_POS, 38.0 * (1.2 - b_alpha * 0.4), Color(1.0, 0.75, 0.25, b_alpha * 0.5))

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

	# Floating earnings texts (matching separate Money gold + Research cyan colors)
	for ft in floating_texts:
		var alpha: float = clampf(float(ft["timer"]) / float(ft["max_timer"]), 0.0, 1.0)
		var pos: Vector2 = ft["pos"]
		if ft.has("custom_text"):
			var c: Color = ft["custom_color"]
			c.a = alpha
			draw_string(font, pos, ft["custom_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
		else:
			draw_string(font, pos, ft["money_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.25, alpha))
			draw_string(font, pos + Vector2(28, 0), ft["research_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.88, 1.0, alpha))
