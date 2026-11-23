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

## 20 build slots organized strictly into 4 horizontal placement rows (y = 32, 157, 322, 449).
## Indices 0..13 preserve test pad coordinates while aligning all pads onto the 4 rows.
const BUILD_PAD_POSITIONS: Array[Vector2] = [
	Vector2(220, 32),  # P1  (Row 1)
	Vector2(380, 32),  # P2  (Row 1)
	Vector2(540, 32),  # P3  (Row 1)
	Vector2(250, 157), # P4  (Row 2)
	Vector2(380, 157), # P5  (Row 2)
	Vector2(510, 157), # P6  (Row 2)
	Vector2(640, 157), # P7  (Row 2)
	Vector2(770, 157), # P8  (Row 2)
	Vector2(765, 322), # P9  (Row 3)
	Vector2(295, 322), # P10 (Row 3)
	Vector2(430, 322), # P11 (Row 3)
	Vector2(565, 322), # P12 (Row 3)
	Vector2(380, 449), # P13 (Row 4)
	Vector2(570, 449), # P14 (Row 4)
	Vector2(300, 32),  # P15 (Row 1)
	Vector2(460, 32),  # P16 (Row 1)
	Vector2(665, 322), # P17 (Row 3)
	Vector2(285, 449), # P18 (Row 4)
	Vector2(475, 449), # P19 (Row 4)
	Vector2(665, 449), # P20 (Row 4)
]

const ROW_DEFS: Array[Dictionary] = [
	{"row": 1, "y": 32.0, "x_min": 200.0, "x_max": 560.0, "label": "ROW 1"},
	{"row": 2, "y": 157.0, "x_min": 230.0, "x_max": 790.0, "label": "ROW 2"},
	{"row": 3, "y": 322.0, "x_min": 275.0, "x_max": 785.0, "label": "ROW 3"},
	{"row": 4, "y": 449.0, "x_min": 265.0, "x_max": 685.0, "label": "ROW 4"},
]

const ENEMY_BASE_POS: Vector2 = Vector2(58, 75)
const PLAYER_BASE_POS: Vector2 = Vector2(842, 405)
const REFINERY_ANNEX_RECT: Rect2 = Rect2(16, 195, 134, 268)
const PAD_SIZE: float = 36.0
const PAD_TOUCH_RADIUS: float = 34.0 # Finger-friendly hit zone (68 px diameter)
const PAD_DRAG_SNAP_RADIUS: float = 56.0 # Snap radius when dragging a tower onto a row slot

@onready var map_click_area: Control = $MapClickArea
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
var pending_build_type: String = ""
var pad_occupancy: Array[TowerUnit] = []
var floating_texts: Array[Dictionary] = []
var economy_ref: Node = null
var extra_left_margin: float = 0.0
var extra_right_margin: float = 0.0
var visual_time: float = 0.0
var drag_tower_type: String = ""
var drag_local_pos: Vector2 = Vector2.ZERO
var drag_snap_pad_index: int = -1


static func get_pad_row_number(pad_idx: int) -> int:
	if pad_idx < 0 or pad_idx >= BUILD_PAD_POSITIONS.size():
		return 1
	var py: float = BUILD_PAD_POSITIONS[pad_idx].y
	for rdef in ROW_DEFS:
		if absf(py - float(rdef["y"])) <= 6.0:
			return int(rdef["row"])
	return 1


func find_nearest_open_pad(local_pos: Vector2, max_radius: float = PAD_DRAG_SNAP_RADIUS) -> int:
	var best_idx: int = -1
	var best_dist_sq: float = max_radius * max_radius
	for i in range(BUILD_PAD_POSITIONS.size()):
		if pad_occupancy[i] != null:
			continue
		var d_sq: float = local_pos.distance_squared_to(BUILD_PAD_POSITIONS[i])
		if d_sq <= best_dist_sq:
			best_dist_sq = d_sq
			best_idx = i
	return best_idx


func update_drag_placement(tower_type: String, global_screen_pos: Vector2) -> int:
	drag_tower_type = tower_type
	var eff_scale: Vector2 = Vector2(maxf(0.01, scale.x), maxf(0.01, scale.y))
	drag_local_pos = (global_screen_pos - position) / eff_scale
	drag_snap_pad_index = find_nearest_open_pad(drag_local_pos, PAD_DRAG_SNAP_RADIUS)
	hovered_pad_index = drag_snap_pad_index
	queue_redraw()
	return drag_snap_pad_index


func finish_drag_placement(tower_type: String, global_screen_pos: Vector2) -> TowerUnit:
	var snap_idx: int = update_drag_placement(tower_type, global_screen_pos)
	drag_tower_type = ""
	drag_snap_pad_index = -1
	hovered_pad_index = -1
	queue_redraw()
	if snap_idx >= 0 and pad_occupancy[snap_idx] == null:
		pending_build_type = ""
		return build_tower_on_pad(snap_idx, tower_type)
	return null


func cancel_drag_placement() -> void:
	drag_tower_type = ""
	drag_snap_pad_index = -1
	hovered_pad_index = -1
	queue_redraw()


func set_viewport_margins(left_m: float, right_m: float) -> void:
	extra_left_margin = maxf(0.0, left_m)
	extra_right_margin = maxf(0.0, right_m)
	if map_click_area != null:
		map_click_area.offset_left = -extra_left_margin
		map_click_area.offset_top = 0.0
		map_click_area.offset_right = MAP_WIDTH + extra_right_margin
		map_click_area.offset_bottom = MAP_HEIGHT
	queue_redraw()


func set_economy_ref(p_econ: Node) -> void:
	economy_ref = p_econ


func set_pending_build_type(tower_type: String) -> void:
	pending_build_type = tower_type
	queue_redraw()


func show_refinery_tick_floaters(owned_count: int) -> void:
	for i in range(owned_count):
		var col: int = i % 2
		var row: int = i / 2
		var rx: float = REFINERY_ANNEX_RECT.position.x + 24.0 + float(col) * 56.0
		var ry: float = REFINERY_ANNEX_RECT.position.y + 32.0 + float(row) * 44.0
		if ry <= REFINERY_ANNEX_RECT.end.y:
			spawn_floater(Vector2(rx, ry), "+%d$" % Balance.REFINERY_INCOME_PER_TICK, Color(0.55, 0.95, 0.65))


func trigger_hive_beam_effect(dmg: int = Balance.BASE_ATTACK_TEST_DAMAGE_OVERRIDE) -> void:
	hive_beam_timer = 0.85
	spawn_floater(ENEMY_BASE_POS + Vector2(-20, -45), "-%d HP!" % dmg, Color(1.0, 0.72, 0.25))
	queue_redraw()


func _ready() -> void:
	_build_path_curve()
	_reset_pad_occupancy()
	if map_click_area != null:
		map_click_area.gui_input.connect(_on_map_gui_input)
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
	visual_time += delta
	if leak_flash_timer > 0.0:
		leak_flash_timer = maxf(0.0, leak_flash_timer - delta)
	if hive_beam_timer > 0.0:
		hive_beam_timer = maxf(0.0, hive_beam_timer - delta)

	if not floating_texts.is_empty():
		for i in range(floating_texts.size() - 1, -1, -1):
			floating_texts[i]["timer"] -= delta
			floating_texts[i]["pos"] += Vector2(0.0, -24.0 * delta)
			if floating_texts[i]["timer"] <= 0.0:
				floating_texts.remove_at(i)

	queue_redraw()


func _on_map_gui_input(event: InputEvent) -> void:
	if GameState.mission.is_over:
		return
	if not (event is InputEventMouse):
		return
	var click_offset: Vector2 = map_click_area.position if map_click_area != null else Vector2.ZERO
	var local_pos: Vector2 = event.position + click_offset
	var map_bounds := Rect2(Vector2(-extra_left_margin, 0.0), Vector2(MAP_WIDTH + extra_left_margin + extra_right_margin, MAP_HEIGHT))
	var in_map: bool = map_bounds.has_point(local_pos)

	if event is InputEventMouseMotion:
		var new_hover: int = _find_pad_at(local_pos) if in_map else -1
		if new_hover != hovered_pad_index:
			hovered_pad_index = new_hover
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if pending_build_type != "":
			pending_build_type = ""
			clear_selection()
			map_click_area.accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not in_map:
			return
		var clicked_pad: int = _find_pad_at(local_pos)
		if clicked_pad != -1:
			if pending_build_type != "" and pad_occupancy[clicked_pad] == null:
				build_tower_on_pad(clicked_pad, pending_build_type)
				pending_build_type = ""
			else:
				pending_build_type = ""
				select_pad(clicked_pad)
			map_click_area.accept_event()
		else:
			pending_build_type = ""
			clear_selection()
			map_click_area.accept_event()


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
	if not GameState.spend_money(cost, true):
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
	hive_beam_timer = 0.0
	selected_pad_index = -1
	selected_tower = null
	preview_tower_type = ""
	pending_build_type = ""
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
	var is_replay: bool = GameState.mission.replay_count_this_wave > 0
	GameState.award_kill_earnings(enemy.enemy_type, enemy.money_on_kill, enemy.research_on_kill, enemy.global_position, is_replay)


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
	var best_idx: int = -1
	var best_dist_sq: float = PAD_TOUCH_RADIUS * PAD_TOUCH_RADIUS
	for i in range(BUILD_PAD_POSITIONS.size()):
		var d_sq: float = local_pos.distance_squared_to(BUILD_PAD_POSITIONS[i])
		if d_sq <= best_dist_sq:
			best_dist_sq = d_sq
			best_idx = i
	return best_idx


func _make_regular_poly(center: Vector2, r: float, sides: int, angle_offset: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a: float = angle_offset + float(i) * TAU / float(sides)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var full_w: float = MAP_WIDTH + extra_left_margin + extra_right_margin
	var left_x: float = -extra_left_margin
	var right_x: float = MAP_WIDTH + extra_right_margin
	var arena_rect := Rect2(Vector2(left_x, 0.0), Vector2(full_w, MAP_HEIGHT))

	# 1) Deep sci-fi tactical terrain background + dual-scale sector grid
	draw_rect(arena_rect, Color(0.06, 0.08, 0.13))
	# Subtle environmental sector plates
	draw_rect(Rect2(Vector2(left_x + 12.0, 12.0), Vector2(full_w - 24.0, MAP_HEIGHT - 24.0)), Color(0.075, 0.10, 0.155))

	# Minor 40 px grid & Major 80 px grid with tactical crosshairs
	var gx_minor: float = -floorf(extra_left_margin / 40.0) * 40.0
	while gx_minor <= right_x:
		draw_line(Vector2(gx_minor, 0.0), Vector2(gx_minor, MAP_HEIGHT), Color(0.10, 0.13, 0.19, 0.38), 1.0)
		gx_minor += 40.0
	var gy_minor: float = 40.0
	while gy_minor < MAP_HEIGHT:
		draw_line(Vector2(left_x, gy_minor), Vector2(right_x, gy_minor), Color(0.10, 0.13, 0.19, 0.38), 1.0)
		gy_minor += 40.0

	var gx: float = -floorf(extra_left_margin / 80.0) * 80.0
	while gx <= right_x:
		draw_line(Vector2(gx, 0.0), Vector2(gx, MAP_HEIGHT), Color(0.14, 0.19, 0.28, 0.62), 1.0)
		var cy: float = 80.0
		while cy < MAP_HEIGHT:
			draw_line(Vector2(gx - 3.0, cy), Vector2(gx + 3.0, cy), Color(0.24, 0.35, 0.50, 0.55), 1.0)
			draw_line(Vector2(gx, cy - 3.0), Vector2(gx, cy + 3.0), Color(0.24, 0.35, 0.50, 0.55), 1.0)
			cy += 80.0
		gx += 80.0
	var gy: float = 80.0
	while gy < MAP_HEIGHT:
		draw_line(Vector2(left_x, gy), Vector2(right_x, gy), Color(0.14, 0.19, 0.28, 0.62), 1.0)
		gy += 80.0

	# Decorative atmospheric craters / tactical radar rings in non-pad space
	draw_arc(Vector2(105.0, 145.0), 26.0, 0.0, TAU, 28, Color(0.13, 0.18, 0.26, 0.55), 1.2)
	draw_arc(Vector2(865.0, 140.0), 34.0, 0.0, TAU, 32, Color(0.13, 0.18, 0.26, 0.55), 1.2)
	draw_arc(Vector2(842.0, 405.0), 54.0, 0.0, TAU, 36, Color(0.18, 0.34, 0.52, 0.35), 1.2)
	draw_arc(Vector2(58.0, 75.0), 48.0, 0.0, TAU, 36, Color(0.48, 0.16, 0.22, 0.35), 1.2)

	# 2) Refinery Annex industrial zone (bottom-left, distinct from tower pads)
	draw_rect(Rect2(REFINERY_ANNEX_RECT.position + Vector2(2, 3), REFINERY_ANNEX_RECT.size), Color(0.0, 0.0, 0.0, 0.35))
	draw_rect(REFINERY_ANNEX_RECT, Color(0.09, 0.13, 0.17))
	draw_rect(Rect2(REFINERY_ANNEX_RECT.position, Vector2(REFINERY_ANNEX_RECT.size.x, 24.0)), Color(0.13, 0.22, 0.22))
	draw_rect(REFINERY_ANNEX_RECT, Color(0.32, 0.62, 0.54), false, 1.8)
	draw_string(font, REFINERY_ANNEX_RECT.position + Vector2(9, 16), "REFINERY ANNEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.96, 0.86))

	var ref_count: int = GameState.mission.economy.get("refineries_owned", 0)
	for i in range(ref_count):
		var col: int = i % 2
		var row: int = i / 2
		var rx: float = REFINERY_ANNEX_RECT.position.x + 16.0 + float(col) * 56.0
		var ry: float = REFINERY_ANNEX_RECT.position.y + 32.0 + float(row) * 44.0
		if ry + 32.0 <= REFINERY_ANNEX_RECT.end.y:
			var r_rect := Rect2(Vector2(rx, ry), Vector2(44, 32))
			draw_rect(Rect2(r_rect.position + Vector2(1.5, 2.0), r_rect.size), Color(0.0, 0.0, 0.0, 0.4))
			draw_rect(r_rect, Color(0.14, 0.30, 0.26))
			draw_rect(r_rect, Color(0.45, 0.88, 0.72), false, 1.5)
			# Twin storage silos + pulsing energy core
			draw_circle(Vector2(rx + 12.0, ry + 16.0), 7.5, Color(0.20, 0.46, 0.38))
			draw_arc(Vector2(rx + 12.0, ry + 16.0), 7.5, 0.0, TAU, 16, Color(0.58, 0.96, 0.82), 1.2)
			var r_pulse: float = 0.6 + 0.4 * sin(visual_time * 3.5 + float(i))
			draw_circle(Vector2(rx + 12.0, ry + 16.0), 3.5, Color(0.48, 1.0, 0.78, r_pulse))
			draw_string(font, Vector2(rx + 21, ry + 20), "REF", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 1.0, 0.96))

	if economy_ref != null and economy_ref.refinery_job != null:
		var i: int = ref_count
		var col: int = i % 2
		var row: int = i / 2
		var rx: float = REFINERY_ANNEX_RECT.position.x + 16.0 + float(col) * 56.0
		var ry: float = REFINERY_ANNEX_RECT.position.y + 32.0 + float(row) * 44.0
		if ry + 32.0 <= REFINERY_ANNEX_RECT.end.y:
			var center := Vector2(rx + 22.0, ry + 16.0)
			draw_rect(Rect2(Vector2(rx, ry), Vector2(44, 32)), Color(0.22, 0.25, 0.16))
			draw_rect(Rect2(Vector2(rx, ry), Vector2(44, 32)), Color(0.95, 0.82, 0.32), false, 1.5)
			var prog: float = economy_ref.refinery_job.get_progress()
			draw_arc(center, 14.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 24, Color(0.45, 0.95, 0.65), 2.5)
			draw_string(font, Vector2(rx + 6, ry + 21), "%.1fs" % economy_ref.refinery_job.remaining_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.92, 0.45))

	# 3) Layered S-Path Transit Trench + Animated Directional Flow Chevrons
	if enemy_path != null and enemy_path.curve != null:
		var pts: PackedVector2Array = enemy_path.curve.get_baked_points()
		if extra_left_margin > 0.0:
			var lead_pts := PackedVector2Array([Vector2(left_x, PATH_WAYPOINTS[0].y), PATH_WAYPOINTS[0]])
			draw_polyline(lead_pts, Color(0.11, 0.15, 0.22), 34.0)
			draw_polyline(lead_pts, Color(0.18, 0.23, 0.32), 24.0)
			draw_polyline(lead_pts, Color(0.32, 0.42, 0.56, 0.65), 2.0)
		if extra_right_margin > 0.0:
			var end_pt: Vector2 = PATH_WAYPOINTS[PATH_WAYPOINTS.size() - 1]
			var tail_pts := PackedVector2Array([end_pt, Vector2(right_x, end_pt.y)])
			draw_polyline(tail_pts, Color(0.11, 0.15, 0.22), 34.0)
			draw_polyline(tail_pts, Color(0.18, 0.23, 0.32), 24.0)
			draw_polyline(tail_pts, Color(0.32, 0.42, 0.56, 0.65), 2.0)
		if pts.size() >= 2:
			# Outer trench shadow & armor curbs
			draw_polyline(pts, Color(0.04, 0.05, 0.08, 0.75), 40.0)
			draw_polyline(pts, Color(0.22, 0.28, 0.39), 34.0)
			draw_polyline(pts, Color(0.13, 0.17, 0.24), 26.0)
			draw_polyline(pts, Color(0.17, 0.22, 0.31), 18.0)
			# Subtle center energy guide rail
			var rail_col := Color(0.45, 0.88, 1.0, 0.55) if GameState.is_enemies_frozen else Color(0.36, 0.48, 0.66, 0.50)
			draw_polyline(pts, rail_col, 2.0)

			# Animated directional chevrons along the path curve
			var plen: float = enemy_path.curve.get_baked_length()
			var flow_offset: float = 0.0 if GameState.is_enemies_frozen else fmod(visual_time * 28.0, 68.0)
			var d_cur: float = 40.0 + flow_offset
			while d_cur < plen - 35.0:
				var c_pos: Vector2 = enemy_path.curve.sample_baked(d_cur, false)
				var c_next: Vector2 = enemy_path.curve.sample_baked(minf(plen, d_cur + 4.0), false)
				var dir: Vector2 = (c_next - c_pos).normalized()
				if dir.length_squared() > 0.01:
					var perp := Vector2(-dir.y, dir.x)
					var tip: Vector2 = c_pos + dir * 4.5
					var w_l: Vector2 = c_pos - dir * 3.5 + perp * 5.0
					var w_r: Vector2 = c_pos - dir * 3.5 - perp * 5.0
					var chev_col := Color(0.45, 0.72, 0.96, 0.34)
					draw_line(w_l, tip, chev_col, 1.5)
					draw_line(w_r, tip, chev_col, 1.5)
				d_cur += 68.0

	# 4) 4 Horizontal Placement Rows + 20 Sci-Fi Octagonal Build Pads (P1..P20)
	var half: float = PAD_SIZE * 0.5
	var active_preview_type: String = drag_tower_type if drag_tower_type != "" else (pending_build_type if pending_build_type != "" else preview_tower_type)
	var is_placing_any: bool = (drag_tower_type != "" or pending_build_type != "")

	for rdef in ROW_DEFS:
		var ry: float = float(rdef["y"])
		var rx0: float = float(rdef["x_min"])
		var rx1: float = float(rdef["x_max"])
		var rail_col := Color(0.28, 0.58, 0.78, 0.55) if is_placing_any else Color(0.18, 0.28, 0.42, 0.48)
		draw_rect(Rect2(Vector2(rx0, ry - 5.0), Vector2(rx1 - rx0, 10.0)), Color(0.08, 0.12, 0.19, 0.78))
		draw_line(Vector2(rx0, ry - 4.0), Vector2(rx1, ry - 4.0), rail_col, 1.4)
		draw_line(Vector2(rx0, ry + 4.0), Vector2(rx1, ry + 4.0), rail_col, 1.4)
		draw_rect(Rect2(Vector2(rx0 - 44.0, ry - 8.0), Vector2(40.0, 16.0)), Color(0.07, 0.11, 0.17, 0.90))
		draw_rect(Rect2(Vector2(rx0 - 44.0, ry - 8.0), Vector2(40.0, 16.0)), rail_col, false, 1.2)
		draw_string(font, Vector2(rx0 - 40.0, ry + 4.0), str(rdef["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.62, 0.86, 1.0))

	for i in range(BUILD_PAD_POSITIONS.size()):
		var p: Vector2 = BUILD_PAD_POSITIONS[i]
		var is_sel: bool = (i == selected_pad_index)
		var is_hov: bool = (i == hovered_pad_index or i == drag_snap_pad_index)
		var is_open: bool = (pad_occupancy[i] == null)

		# Pad shadow & octagonal metallic plate
		draw_colored_polygon(_make_regular_poly(p + Vector2(1.5, 2.0), half * 1.06, 8, PI * 0.125), Color(0.0, 0.0, 0.0, 0.42))
		var outer_pad := _make_regular_poly(p, half * 1.04, 8, PI * 0.125)
		var inner_pad := _make_regular_poly(p, half * 0.84, 8, PI * 0.125)
		var pad_col := Color(0.14, 0.20, 0.29)
		var border_col := Color(0.36, 0.52, 0.72)
		if i == drag_snap_pad_index and is_open:
			pad_col = Color(0.18, 0.42, 0.36)
			border_col = Color(0.42, 1.0, 0.72)
		elif is_sel:
			pad_col = Color(0.22, 0.30, 0.42)
			border_col = Color(1.0, 0.88, 0.36)
		elif is_hov:
			pad_col = Color(0.20, 0.30, 0.44)
			border_col = Color(0.55, 0.92, 1.0)
		elif is_placing_any and is_open:
			border_col = Color(0.42, 0.88, 0.96, 0.72 + 0.28 * sin(visual_time * 6.0))

		draw_colored_polygon(outer_pad, Color(0.10, 0.14, 0.21))
		draw_colored_polygon(inner_pad, pad_col)
		for s_i in range(8):
			draw_line(outer_pad[s_i], outer_pad[(s_i + 1) % 8], border_col, 2.4 if (is_sel or i == drag_snap_pad_index) else 1.5)
		if is_open:
			draw_arc(p, 10.5, 0.0, TAU, 20, Color(0.26, 0.38, 0.54, 0.65), 1.1)
			draw_string(font, p + Vector2(-7, 4), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.68, 0.82, 0.96))

	# 5) Range ring & Drag-and-Drop Ghost Preview
	var preview_pad: int = -1
	if drag_tower_type != "" and drag_snap_pad_index >= 0:
		preview_pad = drag_snap_pad_index
	elif pending_build_type != "" and hovered_pad_index >= 0 and pad_occupancy[hovered_pad_index] == null:
		preview_pad = hovered_pad_index
	elif active_preview_type != "" and selected_pad_index >= 0 and selected_pad_index < BUILD_PAD_POSITIONS.size():
		preview_pad = selected_pad_index
	if active_preview_type != "" and (preview_pad >= 0 or drag_tower_type != ""):
		var center: Vector2 = BUILD_PAD_POSITIONS[preview_pad] if preview_pad >= 0 else drag_local_pos
		var cfg: Dictionary = Balance.TOWERS[active_preview_type]
		var r: float = float(cfg["range"]) * GameState.get_tower_range_research_multiplier()
		var min_r: float = float(cfg.get("min_range", 0.0))
		var valid_drop: bool = (preview_pad >= 0)
		var ring_fill := Color(0.35, 0.95, 0.72, 0.10) if (drag_tower_type != "" and valid_drop) else Color(0.38, 0.85, 1.0, 0.08)
		var ring_stroke := Color(0.42, 1.0, 0.75, 0.85) if (drag_tower_type != "" and valid_drop) else Color(0.45, 0.88, 1.0, 0.72)
		draw_circle(center, r, ring_fill)
		draw_arc(center, r, 0.0, TAU, 56, ring_stroke, 1.8)
		if min_r > 0.0:
			draw_circle(center, min_r, Color(1.0, 0.35, 0.35, 0.08))
			draw_arc(center, min_r, 0.0, TAU, 32, Color(1.0, 0.45, 0.45, 0.75), 1.5)
		if drag_tower_type != "":
			draw_circle(center, 15.0, Color(0.35, 0.95, 0.82, 0.38) if valid_drop else Color(1.0, 0.55, 0.35, 0.32))
			draw_arc(center, 16.0, 0.0, TAU, 24, ring_stroke, 2.2)
			var drop_txt: String = "DROP -> ROW %d (P%d)" % [get_pad_row_number(preview_pad), preview_pad + 1] if valid_drop else "DRAG TO A ROW SLOT"
			draw_rect(Rect2(center + Vector2(-58, -34), Vector2(116, 15)), Color(0.05, 0.08, 0.14, 0.92))
			draw_string(font, center + Vector2(-52, -23), drop_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 1.0, 0.82) if valid_drop else Color(1.0, 0.82, 0.45))

	# 6) Enemy Base Marker (Alien Bio-Spire Hive at path start)
	var hive_pulse: float = 0.7 + 0.3 * sin(visual_time * 3.8)
	draw_circle(ENEMY_BASE_POS + Vector2(2, 3), 32.0, Color(0.0, 0.0, 0.0, 0.45))
	var hive_outer := _make_regular_poly(ENEMY_BASE_POS, 30.0, 8, visual_time * 0.25)
	var hive_inner := _make_regular_poly(ENEMY_BASE_POS, 22.0, 8, -visual_time * 0.35)
	var eb_fill := Color(1.0, 0.82, 0.28) if hive_beam_timer > 0.0 else Color(0.32, 0.09, 0.14)
	draw_colored_polygon(hive_outer, eb_fill)
	for s_i in range(8):
		draw_line(hive_outer[s_i], hive_outer[(s_i + 1) % 8], Color(0.95, 0.28, 0.34), 2.4)
	draw_colored_polygon(hive_inner, Color(0.48, 0.12, 0.20))
	draw_circle(ENEMY_BASE_POS, 12.0, Color(0.88, 0.18, 0.28, hive_pulse))
	draw_circle(ENEMY_BASE_POS, 6.0, Color(1.0, 0.65, 0.45))
	draw_rect(Rect2(ENEMY_BASE_POS + Vector2(-22, -46), Vector2(44, 14)), Color(0.08, 0.05, 0.08, 0.88))
	draw_string(font, ENEMY_BASE_POS + Vector2(-15, -35), "HIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.62, 0.62))

	# 7) Hive Destroyer Orbital Beam Effect
	if hive_beam_timer > 0.0:
		var b_alpha: float = clampf(hive_beam_timer / 0.85, 0.0, 1.0)
		draw_line(PLAYER_BASE_POS, ENEMY_BASE_POS, Color(0.25, 0.78, 1.0, b_alpha * 0.35), 24.0)
		draw_line(PLAYER_BASE_POS, ENEMY_BASE_POS, Color(0.38, 0.92, 1.0, b_alpha * 0.85), 11.0)
		draw_line(PLAYER_BASE_POS, ENEMY_BASE_POS, Color(1.0, 0.98, 0.82, b_alpha), 4.2)
		draw_circle(ENEMY_BASE_POS, 42.0 * (1.25 - b_alpha * 0.4), Color(1.0, 0.75, 0.25, b_alpha * 0.45))
		draw_arc(ENEMY_BASE_POS, 48.0 * (1.0 - b_alpha * 0.5), 0.0, TAU, 36, Color(0.55, 0.96, 1.0, b_alpha * 0.9), 3.0)

	# 8) Player Base Citadel & Time Manipulator Chronosphere (at path end)
	draw_circle(PLAYER_BASE_POS + Vector2(2, 3), 36.0, Color(0.0, 0.0, 0.0, 0.48))
	var pb_outer := _make_regular_poly(PLAYER_BASE_POS, 34.0, 8, PI * 0.125)
	var pb_inner := _make_regular_poly(PLAYER_BASE_POS, 25.0, 8, PI * 0.125)
	var pb_fill := Color(0.11, 0.24, 0.40)
	var pb_border := Color(0.38, 0.82, 1.0)
	if leak_flash_timer > 0.0:
		pb_fill = Color(0.88, 0.18, 0.20)
		pb_border = Color(1.0, 0.85, 0.85)
	draw_colored_polygon(pb_outer, Color(0.08, 0.14, 0.24))
	draw_colored_polygon(pb_inner, pb_fill)
	for s_i in range(8):
		draw_line(pb_outer[s_i], pb_outer[(s_i + 1) % 8], pb_border, 2.8)
	# Spinning Time Manipulator Chronosphere Dome inside Base
	var manip_col := Color(1.0, 0.75, 0.28) if GameState.is_base_locked() else Color(0.45, 0.94, 1.0)
	draw_arc(PLAYER_BASE_POS, 16.0, visual_time * 1.8, visual_time * 1.8 + PI * 1.35, 24, manip_col, 2.2)
	draw_arc(PLAYER_BASE_POS, 11.5, -visual_time * 2.5, -visual_time * 2.5 + PI * 1.35, 20, Color(0.75, 0.55, 1.0, 0.9), 2.0)
	draw_circle(PLAYER_BASE_POS, 6.0, manip_col)
	draw_circle(PLAYER_BASE_POS, 2.8, Color.WHITE)
	draw_rect(Rect2(PLAYER_BASE_POS + Vector2(-22, -50), Vector2(44, 14)), Color(0.05, 0.09, 0.16, 0.88))
	draw_string(font, PLAYER_BASE_POS + Vector2(-16, -39), "BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.94, 1.0))

	# 9) Global Time Power Battlefield Border FX (Pause Stasis Frost / Haste Overclock)
	if GameState.is_enemies_frozen:
		draw_rect(arena_rect.grow(-2.0), Color(0.42, 0.88, 1.0, 0.45), false, 3.5)
	elif GameState.is_haste_active:
		draw_rect(arena_rect.grow(-2.0), Color(0.35, 1.0, 0.78, 0.40), false, 3.0)
	draw_rect(arena_rect, Color(0.24, 0.34, 0.48), false, 2.0)

	# 10) Floating earnings texts (with drop shadow for crisp readability)
	for ft in floating_texts:
		var alpha: float = clampf(float(ft["timer"]) / float(ft["max_timer"]), 0.0, 1.0)
		var pos: Vector2 = ft["pos"]
		if ft.has("custom_text"):
			var c: Color = ft["custom_color"]
			c.a = alpha
			draw_string(font, pos + Vector2(1, 1), ft["custom_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, alpha * 0.75))
			draw_string(font, pos, ft["custom_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
		else:
			draw_string(font, pos + Vector2(1, 1), ft["money_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, alpha * 0.75))
			draw_string(font, pos, ft["money_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.86, 0.28, alpha))
			draw_string(font, pos + Vector2(29, 1), ft["research_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, alpha * 0.75))
			draw_string(font, pos + Vector2(28, 0), ft["research_text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.48, 0.92, 1.0, alpha))
