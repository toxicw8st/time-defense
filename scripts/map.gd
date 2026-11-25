extends Node2D
class_name GameMap

signal pad_selected(pad_index: int)
signal tower_selected(tower: TowerUnit)
signal enemy_inspected(enemy: EnemyUnit)
signal selection_cleared

const MAP_WIDTH: float = 940.0
const MAP_HEIGHT: float = 480.0

## Level 1 default S-path waypoints (~1891 px). Kept as static const for test suite compatibility.
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

## Level 1 default 20 build slots organized strictly into 4 horizontal placement rows (y = 32, 157, 322, 449).
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
const PAD_TOUCH_RADIUS: float = 34.0
const PAD_DRAG_SNAP_RADIUS: float = 56.0
const ZONE_SNAP_MARGIN: float = 20.0
const MIN_TOWER_SPACING: float = 33.0
const MIN_PATH_CLEARANCE: float = 36.5

@onready var map_click_area: Control = $MapClickArea
@onready var enemy_path: Path2D = $EnemyPath
@onready var towers_container: Node2D = $TowersContainer
@onready var enemies_container: Node2D = $EnemiesContainer
@onready var projectiles_container: Node2D = $ProjectilesContainer
@onready var effects_container: Node2D = $EffectsContainer

var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var tower_scene: PackedScene = preload("res://scenes/tower.tscn")
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

var current_level_id: int = 1
var active_path_waypoints: Array[Vector2] = []
var active_pad_positions: Array[Vector2] = []
var active_placement_zones: Array[Dictionary] = []
var active_enemy_base_pos: Vector2 = ENEMY_BASE_POS
var active_player_base_pos: Vector2 = PLAYER_BASE_POS

var next_enemy_id: int = 1
var next_tower_id: int = 1
var leak_flash_timer: float = 0.0
var hive_beam_timer: float = 0.0
var surge_explosion_timer: float = 0.0
var surge_explosion_max_timer: float = 1.65
var surge_explosion_sparks: Array[Dictionary] = []
var ability_fx_type: String = ""
var ability_fx_timer: float = 0.0
var ability_fx_max_timer: float = 1.65
var ability_fx_particles: Array[Dictionary] = []
var hovered_pad_index: int = -1
var selected_pad_index: int = -1
var selected_zone_index: int = -1
var selected_drop_pos: Vector2 = Vector2(-1.0, -1.0)
var selected_tower: TowerUnit = null
var preview_tower_type: String = ""
var pending_build_type: String = ""
var pad_occupancy: Array[TowerUnit] = []
var placed_towers: Array[TowerUnit] = []
var floating_texts: Array[Dictionary] = []
var economy_ref: Node = null
var extra_left_margin: float = 0.0
var extra_right_margin: float = 0.0
var visual_time: float = 0.0

var drag_tower_type: String = ""
var drag_local_pos: Vector2 = Vector2.ZERO
var drag_snap_pad_index: int = -1
var drag_zone_index: int = -1
var drag_valid_drop: bool = false
var drag_drop_pos: Vector2 = Vector2.ZERO
var drag_status_reason: String = ""
var drag_merge_target: TowerUnit = null
var drag_merge_combo_type: String = ""
var combine_source_tower: TowerUnit = null
var inspected_enemy: EnemyUnit = null
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0


static func get_level_config(level_id: int) -> Dictionary:
	var lid: int = clampi(level_id, 1, 5)
	if lid == 1:
		return {
			"id": 1,
			"name": "SECTOR 1: CHRONO ROWS",
			"zone_rule": "4 Horizontal Row Zones",
			"accent": Color(0.28, 0.62, 0.90),
			"enemy_base_pos": ENEMY_BASE_POS,
			"player_base_pos": PLAYER_BASE_POS,
			"waypoints": PATH_WAYPOINTS.duplicate(),
			"zones": [
				{"id": 1, "label": "ROW 1", "rect": Rect2(200.0, 14.0, 360.0, 36.0)},
				{"id": 2, "label": "ROW 2", "rect": Rect2(230.0, 139.0, 430.0, 36.0)},
				{"id": 2, "label": "ROW 2E", "rect": Rect2(752.0, 139.0, 44.0, 36.0)},
				{"id": 3, "label": "ROW 3", "rect": Rect2(275.0, 304.0, 510.0, 36.0)},
				{"id": 4, "label": "ROW 4", "rect": Rect2(265.0, 431.0, 420.0, 36.0)},
			],
			"pads": BUILD_PAD_POSITIONS.duplicate(),
		}
	elif lid == 2:
		var z2: Array[Dictionary] = [
			{"id": 1, "label": "COL 1", "rect": Rect2(252.0, 68.0, 76.0, 306.0)},
			{"id": 2, "label": "COL 2", "rect": Rect2(482.0, 118.0, 76.0, 306.0)},
			{"id": 3, "label": "COL 3", "rect": Rect2(702.0, 68.0, 76.0, 306.0)},
		]
		var p2: Array[Vector2] = [
			Vector2(290, 95), Vector2(290, 145), Vector2(290, 195), Vector2(290, 245), Vector2(290, 295), Vector2(290, 345),
			Vector2(520, 145), Vector2(520, 195), Vector2(520, 245), Vector2(520, 295), Vector2(520, 345), Vector2(520, 395),
			Vector2(740, 95), Vector2(740, 145), Vector2(740, 195), Vector2(740, 245), Vector2(740, 295), Vector2(740, 345),
			Vector2(272, 170), Vector2(538, 220),
		]
		return {
			"id": 2,
			"name": "SECTOR 2: VERTICAL CORRIDORS",
			"zone_rule": "3 Vertical Column Zones",
			"accent": Color(0.32, 0.82, 0.62),
			"enemy_base_pos": Vector2(175, 42),
			"player_base_pos": Vector2(845, 92),
			"waypoints": [
				Vector2(175, 85),
				Vector2(175, 390),
				Vector2(225, 430),
				Vector2(355, 430),
				Vector2(405, 390),
				Vector2(405, 100),
				Vector2(455, 60),
				Vector2(585, 60),
				Vector2(635, 100),
				Vector2(635, 390),
				Vector2(685, 430),
				Vector2(795, 430),
				Vector2(845, 390),
				Vector2(845, 150),
			],
			"zones": z2,
			"pads": p2,
		}
	elif lid == 3:
		var z3: Array[Dictionary] = [
			{"id": 1, "label": "ISLAND NW", "rect": Rect2(205.0, 118.0, 200.0, 80.0)},
			{"id": 2, "label": "ISLAND NE", "rect": Rect2(445.0, 118.0, 200.0, 80.0)},
			{"id": 3, "label": "ISLAND SW", "rect": Rect2(265.0, 292.0, 210.0, 76.0)},
			{"id": 4, "label": "ISLAND SE", "rect": Rect2(515.0, 292.0, 220.0, 76.0)},
		]
		var p3: Array[Vector2] = [
			Vector2(235, 140), Vector2(305, 140), Vector2(375, 140), Vector2(270, 178), Vector2(340, 178),
			Vector2(475, 140), Vector2(545, 140), Vector2(615, 140), Vector2(510, 178), Vector2(580, 178),
			Vector2(295, 314), Vector2(370, 314), Vector2(445, 314), Vector2(332, 350), Vector2(408, 350),
			Vector2(545, 314), Vector2(625, 314), Vector2(705, 314), Vector2(585, 350), Vector2(665, 350),
		]
		return {
			"id": 3,
			"name": "SECTOR 3: TWIN CITADEL ISLANDS",
			"zone_rule": "4 Central Island Fortresses",
			"accent": Color(0.75, 0.48, 0.96),
			"enemy_base_pos": Vector2(58, 70),
			"player_base_pos": Vector2(842, 415),
			"waypoints": [
				Vector2(110, 70),
				Vector2(665, 70),
				Vector2(710, 115),
				Vector2(710, 205),
				Vector2(665, 245),
				Vector2(240, 245),
				Vector2(195, 285),
				Vector2(195, 375),
				Vector2(240, 415),
				Vector2(775, 415),
			],
			"zones": z3,
			"pads": p3,
		}
	elif lid == 4:
		var z4: Array[Dictionary] = [
			{"id": 1, "label": "NORTH BASTION", "rect": Rect2(245.0, 122.0, 230.0, 78.0)},
			{"id": 2, "label": "EAST SANCTUM", "rect": Rect2(575.0, 122.0, 145.0, 120.0)},
			{"id": 3, "label": "SOUTH BASTION", "rect": Rect2(265.0, 322.0, 240.0, 60.0)},
			{"id": 4, "label": "SE KEEP", "rect": Rect2(545.0, 285.0, 175.0, 95.0)},
		]
		var p4: Array[Vector2] = [
			Vector2(275, 142), Vector2(355, 142), Vector2(435, 142), Vector2(315, 180), Vector2(395, 180),
			Vector2(605, 145), Vector2(685, 145), Vector2(645, 182), Vector2(605, 218), Vector2(685, 218),
			Vector2(295, 352), Vector2(360, 352), Vector2(420, 352), Vector2(480, 352), Vector2(325, 340),
			Vector2(575, 310), Vector2(635, 310), Vector2(695, 310), Vector2(605, 355), Vector2(675, 355),
		]
		return {
			"id": 4,
			"name": "SECTOR 4: SPIRAL LABYRINTH",
			"zone_rule": "4 Spiral Core & Bastion Pockets",
			"accent": Color(0.95, 0.65, 0.28),
			"enemy_base_pos": Vector2(58, 125),
			"player_base_pos": Vector2(495, 265),
			"waypoints": [
				Vector2(110, 125),
				Vector2(175, 125),
				Vector2(215, 70),
				Vector2(745, 70),
				Vector2(790, 115),
				Vector2(790, 385),
				Vector2(745, 430),
				Vector2(240, 430),
				Vector2(195, 385),
				Vector2(195, 305),
				Vector2(240, 265),
				Vector2(425, 265),
			],
			"zones": z4,
			"pads": p4,
		}
	else:
		var z5: Array[Dictionary] = [
			{"id": 1, "label": "PILLBOX 1", "rect": Rect2(130.0, 18.0, 170.0, 34.0)},
			{"id": 2, "label": "PILLBOX 2", "rect": Rect2(248.0, 228.0, 174.0, 114.0)},
			{"id": 3, "label": "PILLBOX 3", "rect": Rect2(525.0, 148.0, 90.0, 260.0)},
			{"id": 4, "label": "PILLBOX 4", "rect": Rect2(718.0, 95.0, 130.0, 240.0)},
			{"id": 5, "label": "PILLBOX 5", "rect": Rect2(220.0, 434.0, 420.0, 34.0)},
		]
		var p5: Array[Vector2] = [
			Vector2(155, 35), Vector2(215, 35), Vector2(275, 35),
			Vector2(275, 255), Vector2(335, 255), Vector2(395, 255), Vector2(305, 315), Vector2(375, 315),
			Vector2(570, 175), Vector2(570, 235), Vector2(570, 295), Vector2(570, 355),
			Vector2(755, 130), Vector2(815, 130), Vector2(785, 210), Vector2(755, 290), Vector2(815, 290),
			Vector2(260, 451), Vector2(430, 451), Vector2(600, 451),
		]
		return {
			"id": 5,
			"name": "SECTOR 5: OMEGA GAUNTLET",
			"zone_rule": "5 Switchback Kill-Box Pillboxes",
			"accent": Color(0.95, 0.36, 0.45),
			"enemy_base_pos": Vector2(58, 80),
			"player_base_pos": Vector2(860, 395),
			"waypoints": [
				Vector2(110, 80),
				Vector2(330, 80),
				Vector2(330, 175),
				Vector2(195, 175),
				Vector2(195, 395),
				Vector2(475, 395),
				Vector2(475, 95),
				Vector2(665, 95),
				Vector2(665, 395),
				Vector2(800, 395),
			],
			"zones": z5,
			"pads": p5,
		}


static func get_pad_row_number(pad_idx: int) -> int:
	if pad_idx < 0 or pad_idx >= BUILD_PAD_POSITIONS.size():
		return 1
	var py: float = BUILD_PAD_POSITIONS[pad_idx].y
	for rdef in ROW_DEFS:
		if absf(py - float(rdef["y"])) <= 6.0:
			return int(rdef["row"])
	return 1


func load_level(level_id: int) -> void:
	current_level_id = clampi(level_id, 1, 5)
	var cfg: Dictionary = get_level_config(current_level_id)
	active_path_waypoints.clear()
	for pt in cfg["waypoints"]:
		active_path_waypoints.append(pt)
	active_pad_positions.clear()
	for pt in cfg["pads"]:
		active_pad_positions.append(pt)
	active_placement_zones.clear()
	for z in cfg["zones"]:
		active_placement_zones.append(z.duplicate(true))
	active_enemy_base_pos = cfg["enemy_base_pos"]
	active_player_base_pos = cfg["player_base_pos"]
	_build_path_curve()
	clear_all_towers()
	queue_redraw()


func get_zone_label_for_pad(pad_idx: int) -> String:
	if pad_idx >= 0 and pad_idx < active_pad_positions.size():
		var z_idx: int = find_zone_for_point(active_pad_positions[pad_idx], 12.0)
		if z_idx >= 0 and z_idx < active_placement_zones.size():
			return str(active_placement_zones[z_idx]["label"])
	return "ROW %d" % get_pad_row_number(pad_idx)


func find_zone_for_point(local_pos: Vector2, snap_margin: float = ZONE_SNAP_MARGIN) -> int:
	for i in range(active_placement_zones.size()):
		var r: Rect2 = active_placement_zones[i]["rect"]
		if r.has_point(local_pos):
			return i
	var best_idx: int = -1
	var best_dist_sq: float = snap_margin * snap_margin
	for i in range(active_placement_zones.size()):
		var r: Rect2 = active_placement_zones[i]["rect"]
		var clamped := Vector2(
			clampf(local_pos.x, r.position.x, r.end.x),
			clampf(local_pos.y, r.position.y, r.end.y)
		)
		var d_sq: float = local_pos.distance_squared_to(clamped)
		if d_sq <= best_dist_sq:
			best_dist_sq = d_sq
			best_idx = i
	return best_idx


func clamp_point_to_zone(local_pos: Vector2, zone_idx: int) -> Vector2:
	if zone_idx < 0 or zone_idx >= active_placement_zones.size():
		return local_pos
	var r: Rect2 = active_placement_zones[zone_idx]["rect"]
	var margin_x: float = minf(16.0, r.size.x * 0.5)
	var margin_y: float = minf(16.0, r.size.y * 0.5)
	var cx: float = r.get_center().x if r.size.x <= 40.0 else clampf(local_pos.x, r.position.x + margin_x, r.end.x - margin_x)
	var cy: float = r.get_center().y if r.size.y <= 40.0 else clampf(local_pos.y, r.position.y + margin_y, r.end.y - margin_y)
	return Vector2(cx, cy)


func evaluate_drop_position(local_pos: Vector2, incoming_tower_type: String = "") -> Dictionary:
	var eff_in_type: String = incoming_tower_type if incoming_tower_type != "" else (drag_tower_type if drag_tower_type != "" else pending_build_type)
	if eff_in_type != "" and Balance.BASE_TOWER_KEYS.has(eff_in_type):
		var target_t: TowerUnit = _find_tower_at(local_pos, 40.0)
		if target_t != null and target_t.can_combine():
			var combo_key: String = Balance.get_combo_key(target_t.tower_type, eff_in_type)
			if Balance.TOWERS.has(combo_key):
				var upg_xfer: int = Balance.get_merge_upgrade_transfer_fee(target_t.tower_type, target_t.levels, eff_in_type, {}, combo_key)
				var total_cost: int = int(Balance.TOWERS[eff_in_type]["cost"]) + Balance.get_merge_surcharge(target_t.tower_type, eff_in_type) + upg_xfer
				var can_pay: bool = GameState.is_sandbox_mode or GameState.mission.economy["money"] >= total_cost
				return {
					"valid": can_pay,
					"mode": "combine",
					"pos": target_t.position,
					"zone_idx": find_zone_for_point(target_t.position, ZONE_SNAP_MARGIN),
					"pad_idx": target_t.pad_index,
					"zone_label": "COMBINE",
					"merge_target": target_t,
					"combo_type": combo_key,
					"merge_cost": total_cost,
					"reason": ("COMBINE -> %s ($%d)" % [str(Balance.TOWERS[combo_key]["name"]), total_cost]) if can_pay else ("NEED $%d TO COMBINE" % total_cost),
				}

	var z_idx: int = find_zone_for_point(local_pos, ZONE_SNAP_MARGIN)
	if z_idx < 0:
		return {
			"valid": false,
			"mode": "build",
			"pos": local_pos,
			"zone_idx": -1,
			"pad_idx": -1,
			"zone_label": "",
			"merge_target": null,
			"combo_type": "",
			"reason": "DROP IN A TOWER ZONE",
		}
	var z_label: String = str(active_placement_zones[z_idx]["label"])
	var candidate_pos: Vector2 = clamp_point_to_zone(local_pos, z_idx)
	var snap_pad: int = -1
	var best_pad_d2: float = 14.0 * 14.0
	for i in range(active_pad_positions.size()):
		if pad_occupancy[i] != null:
			continue
		var d2: float = candidate_pos.distance_squared_to(active_pad_positions[i])
		if d2 <= best_pad_d2:
			best_pad_d2 = d2
			snap_pad = i
	if snap_pad >= 0:
		candidate_pos = active_pad_positions[snap_pad]

	for t in get_all_towers():
		if candidate_pos.distance_to(t.position) < MIN_TOWER_SPACING:
			return {
				"valid": false,
				"mode": "build",
				"pos": candidate_pos,
				"zone_idx": z_idx,
				"pad_idx": -1,
				"zone_label": z_label,
				"merge_target": null,
				"combo_type": "",
				"reason": "TOO CLOSE TO TOWER",
			}

	if enemy_path != null and enemy_path.curve != null and enemy_path.curve.point_count >= 2:
		var on_path: Vector2 = enemy_path.curve.get_closest_point(candidate_pos)
		if candidate_pos.distance_to(on_path) < MIN_PATH_CLEARANCE:
			return {
				"valid": false,
				"mode": "build",
				"pos": candidate_pos,
				"zone_idx": z_idx,
				"pad_idx": -1,
				"zone_label": z_label,
				"merge_target": null,
				"combo_type": "",
				"reason": "TOO CLOSE TO PATH",
			}

	return {
		"valid": true,
		"mode": "build",
		"pos": candidate_pos,
		"zone_idx": z_idx,
		"pad_idx": snap_pad,
		"zone_label": z_label,
		"merge_target": null,
		"combo_type": "",
		"reason": "DROP -> %s" % z_label,
	}


func find_nearest_open_pad(local_pos: Vector2, max_radius: float = PAD_DRAG_SNAP_RADIUS) -> int:
	var best_idx: int = -1
	var best_dist_sq: float = max_radius * max_radius
	for i in range(active_pad_positions.size()):
		if pad_occupancy[i] != null:
			continue
		var d_sq: float = local_pos.distance_squared_to(active_pad_positions[i])
		if d_sq <= best_dist_sq:
			best_dist_sq = d_sq
			best_idx = i
	return best_idx


func update_drag_placement(tower_type: String, global_screen_pos: Vector2) -> int:
	drag_tower_type = tower_type
	var eff_scale: Vector2 = Vector2(maxf(0.01, scale.x), maxf(0.01, scale.y))
	drag_local_pos = (global_screen_pos - position) / eff_scale
	var eval: Dictionary = evaluate_drop_position(drag_local_pos, tower_type)
	drag_valid_drop = bool(eval["valid"])
	drag_drop_pos = eval["pos"]
	drag_zone_index = int(eval["zone_idx"])
	drag_snap_pad_index = int(eval["pad_idx"])
	drag_status_reason = str(eval["reason"])
	drag_merge_target = eval.get("merge_target", null)
	drag_merge_combo_type = str(eval.get("combo_type", ""))
	hovered_pad_index = drag_snap_pad_index
	queue_redraw()
	return (drag_zone_index if drag_zone_index >= 0 else 0) if drag_valid_drop else -1


func finish_drag_placement(tower_type: String, global_screen_pos: Vector2) -> TowerUnit:
	var eff_scale: Vector2 = Vector2(maxf(0.01, scale.x), maxf(0.01, scale.y))
	var local_pos: Vector2 = (global_screen_pos - position) / eff_scale
	var eval: Dictionary = evaluate_drop_position(local_pos, tower_type)
	drag_tower_type = ""
	drag_snap_pad_index = -1
	drag_zone_index = -1
	drag_valid_drop = false
	drag_merge_target = null
	drag_merge_combo_type = ""
	hovered_pad_index = -1
	queue_redraw()
	if bool(eval["valid"]):
		pending_build_type = ""
		if str(eval.get("mode", "build")) == "combine":
			var merge_t: TowerUnit = eval.get("merge_target", null)
			return combine_tower_with_shop(merge_t, tower_type)
		var p_idx: int = int(eval["pad_idx"])
		if p_idx >= 0 and pad_occupancy[p_idx] == null:
			return build_tower_on_pad(p_idx, tower_type)
		return build_tower_in_zone(eval["pos"], tower_type, int(eval["zone_idx"]))
	return null


func cancel_drag_placement() -> void:
	drag_tower_type = ""
	drag_snap_pad_index = -1
	drag_zone_index = -1
	drag_valid_drop = false
	drag_merge_target = null
	drag_merge_combo_type = ""
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


func trigger_screen_shake(duration: float = 0.25, intensity: float = 3.5) -> void:
	_shake_timer = maxf(_shake_timer, duration)
	_shake_intensity = maxf(_shake_intensity, intensity)


func trigger_hive_beam_effect(dmg: int = Balance.BASE_ATTACK_TEST_DAMAGE_OVERRIDE) -> void:
	hive_beam_timer = 0.85
	trigger_screen_shake(0.32, 4.5)
	spawn_floater(active_enemy_base_pos + Vector2(-20, -45), "-%d HP!" % dmg, Color(1.0, 0.72, 0.25))
	queue_redraw()


func trigger_hive_retaliation(remaining_hp: int, wave_num: int) -> void:
	if enemy_path == null or enemy_path.curve == null:
		return
	trigger_screen_shake(0.38, 5.2)
	var squad: Array[String] = ["rusher", "rusher", "rusher", "blitzer"]
	if remaining_hp <= 200 and wave_num >= 8:
		squad.append("juggernaut")
	for i in range(squad.size()):
		var e: EnemyUnit = spawn_enemy(squad[i], wave_num)
		if i > 0:
			e.advance_along_path(float(i) * 0.28)
	spawn_floater(active_enemy_base_pos + Vector2(-26, 36), "HIVE RETALIATION!", Color(1.0, 0.30, 0.36))
	GameState.event_logged.emit("HIVE RETALIATION! Enraged squad erupts from the Alien Base!")
	queue_redraw()


func trigger_surge_explosion(_surge_count: int = 1) -> void:
	surge_explosion_max_timer = 1.65
	surge_explosion_timer = surge_explosion_max_timer
	trigger_screen_shake(0.35, 4.8)
	surge_explosion_sparks.clear()
	for i in range(28):
		var ang: float = float(i) * TAU / 28.0 + sin(float(i) * 2.3) * 0.12
		var spd: float = 95.0 + float((i * 37) % 115)
		surge_explosion_sparks.append({
			"pos": active_player_base_pos,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"color": Color(0.45, 0.96, 1.0) if i % 3 == 0 else (Color(0.88, 0.42, 1.0) if i % 3 == 1 else Color(1.0, 0.88, 0.35)),
		})
	spawn_floater(active_player_base_pos + Vector2(-62, -62), "ELECTRICAL SURGE! (-5% SPD)", Color(0.88, 0.45, 1.0))
	queue_redraw()


func _on_surge_triggered(surge_count: int) -> void:
	trigger_surge_explosion(surge_count)


func trigger_ability_animation(power_name: String) -> void:
	if not (power_name in ["pause", "haste", "rewind"]):
		return
	ability_fx_type = power_name
	ability_fx_max_timer = 1.80 if power_name == "rewind" else 1.65
	ability_fx_timer = ability_fx_max_timer
	ability_fx_particles.clear()

	for i in range(28):
		var ang: float = float(i) * TAU / 28.0 + sin(float(i) * 1.9) * 0.14
		var spd: float = 115.0 + float((i * 41) % 135)
		var col := Color(0.45, 0.96, 1.0)
		var start_pos := active_player_base_pos
		if power_name == "pause":
			col = Color(0.55, 0.98, 1.0) if i % 2 == 0 else Color(0.92, 0.98, 1.0)
			spd = 95.0 + float((i * 33) % 110)
		elif power_name == "haste":
			col = Color(0.32, 1.0, 0.72) if i % 2 == 0 else Color(1.0, 0.88, 0.30)
			spd = 140.0 + float((i * 43) % 145)
		else: # "rewind" — starts wide and spirals/pulls + bursts across the base
			col = Color(0.84, 0.45, 1.0) if i % 2 == 0 else Color(1.0, 0.80, 0.32)
			start_pos = active_player_base_pos + Vector2(cos(ang), sin(ang)) * 14.0
			spd = 120.0 + float((i * 37) % 120)
		ability_fx_particles.append({
			"pos": start_pos,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"color": col,
			"angle": ang,
		})

	if power_name == "pause":
		spawn_floater(active_player_base_pos + Vector2(-58, -62), "TEMPORAL PAUSE! (FROZEN)", Color(0.45, 0.96, 1.0))
	elif power_name == "haste":
		spawn_floater(active_player_base_pos + Vector2(-56, -62), "CHRONO HASTE! (+50% SPD)", Color(0.38, 1.0, 0.78))
	else:
		spawn_floater(active_player_base_pos + Vector2(-56, -62), "TIME REWIND! (RESET)", Color(0.86, 0.52, 1.0))
	queue_redraw()


func _on_time_power_used(power_name: String) -> void:
	trigger_ability_animation(power_name)


func get_ability_fx_state() -> Dictionary:
	return {
		"active": ability_fx_timer > 0.0,
		"type": ability_fx_type,
		"timer": ability_fx_timer,
		"max_timer": ability_fx_max_timer,
		"particle_count": ability_fx_particles.size(),
	}


func _ready() -> void:
	load_level(GameState.selected_map_level)
	if map_click_area != null:
		map_click_area.gui_input.connect(_on_map_gui_input)
	GameState.mission_reset.connect(_on_mission_reset)
	GameState.enemy_leaked.connect(_on_enemy_leaked)
	GameState.enemy_killed.connect(_on_enemy_killed)
	GameState.surge_triggered.connect(_on_surge_triggered)
	GameState.time_power_used.connect(_on_time_power_used)


func _exit_tree() -> void:
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)
	if GameState.enemy_leaked.is_connected(_on_enemy_leaked):
		GameState.enemy_leaked.disconnect(_on_enemy_leaked)
	if GameState.enemy_killed.is_connected(_on_enemy_killed):
		GameState.enemy_killed.disconnect(_on_enemy_killed)
	if GameState.surge_triggered.is_connected(_on_surge_triggered):
		GameState.surge_triggered.disconnect(_on_surge_triggered)
	if GameState.time_power_used.is_connected(_on_time_power_used):
		GameState.time_power_used.disconnect(_on_time_power_used)


func _process(delta: float) -> void:
	visual_time += delta
	if leak_flash_timer > 0.0:
		leak_flash_timer = maxf(0.0, leak_flash_timer - delta)
	if hive_beam_timer > 0.0:
		hive_beam_timer = maxf(0.0, hive_beam_timer - delta)
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		if _shake_timer <= 0.0:
			_shake_intensity = 0.0
	if inspected_enemy != null and (not is_instance_valid(inspected_enemy) or not inspected_enemy.is_alive()):
		inspected_enemy = null
		enemy_inspected.emit(null)
	if surge_explosion_timer > 0.0:
		surge_explosion_timer = maxf(0.0, surge_explosion_timer - delta)
		for sp in surge_explosion_sparks:
			sp["pos"] += sp["vel"] * delta
			sp["vel"] *= pow(0.18, delta)
		if surge_explosion_timer <= 0.0:
			surge_explosion_sparks.clear()
	if ability_fx_timer > 0.0:
		ability_fx_timer = maxf(0.0, ability_fx_timer - delta)
		for p in ability_fx_particles:
			p["pos"] += p["vel"] * delta
			if ability_fx_type == "rewind":
				var tangent := Vector2(-p["vel"].y, p["vel"].x) * 0.45
				p["pos"] += tangent * delta
			p["vel"] *= pow(0.22, delta)
		if ability_fx_timer <= 0.0:
			ability_fx_type = ""
			ability_fx_particles.clear()

	if not floating_texts.is_empty():
		for i in range(floating_texts.size() - 1, -1, -1):
			floating_texts[i]["timer"] -= delta
			floating_texts[i]["pos"] += Vector2(0.0, -24.0 * delta)
			if floating_texts[i]["timer"] <= 0.0:
				floating_texts.remove_at(i)

	queue_redraw()


func _find_tower_at(local_pos: Vector2, search_radius: float = 36.0) -> TowerUnit:
	var best_t: TowerUnit = null
	var best_d2: float = search_radius * search_radius
	for t in get_all_towers():
		var d2: float = local_pos.distance_squared_to(t.position)
		if d2 <= best_d2:
			best_d2 = d2
			best_t = t
	return best_t


func _find_combinable_partner_at(local_pos: Vector2, source_tower: TowerUnit, search_radius: float = 46.0) -> TowerUnit:
	var best_t: TowerUnit = null
	var best_d2: float = search_radius * search_radius
	for t in get_all_towers():
		if t == source_tower or not t.can_combine():
			continue
		var d2: float = local_pos.distance_squared_to(t.position)
		if d2 <= best_d2:
			best_d2 = d2
			best_t = t
	return best_t


func _find_enemy_at(local_pos: Vector2) -> EnemyUnit:
	var best_e: EnemyUnit = null
	var best_d2: float = 32.0 * 32.0
	for e in get_active_enemies():
		var d2: float = local_pos.distance_squared_to(e.position)
		if d2 <= best_d2:
			best_d2 = d2
			best_e = e
	return best_e


func inspect_enemy(enemy: EnemyUnit) -> void:
	if inspected_enemy != null and is_instance_valid(inspected_enemy):
		inspected_enemy.is_inspected = false
		inspected_enemy.queue_redraw()
	inspected_enemy = enemy
	if inspected_enemy != null and is_instance_valid(inspected_enemy):
		inspected_enemy.is_inspected = true
		inspected_enemy.queue_redraw()
	enemy_inspected.emit(inspected_enemy)
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
		if combine_source_tower != null:
			cancel_combine_partner_pick()
			map_click_area.accept_event()
		elif pending_build_type != "":
			pending_build_type = ""
			clear_selection()
			map_click_area.accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not in_map:
			return
		# 0) If combining two placed towers, use a generous 46px partner search so slight thumb misses don't cancel Combine!
		if combine_source_tower != null and is_instance_valid(combine_source_tower):
			var partner: TowerUnit = _find_combinable_partner_at(local_pos, combine_source_tower, 46.0)
			if partner != null:
				combine_two_towers(combine_source_tower, partner)
				map_click_area.accept_event()
				return
			# Tapping directly on the source tower cancels cleanly; tapping a busy/building tower explains why; empty space warns without losing Combine arm
			if local_pos.distance_to(combine_source_tower.position) <= 32.0:
				cancel_combine_partner_pick()
				select_tower_unit(combine_source_tower)
			else:
				var near_t: TowerUnit = _find_tower_at(local_pos, 46.0)
				if near_t != null and near_t != combine_source_tower and not near_t.is_built:
					spawn_floater(local_pos, "Wait for tower to finish building!", Color(1.0, 0.72, 0.35))
				elif near_t != null and near_t != combine_source_tower and Balance.is_combo_tower(near_t.tower_type):
					spawn_floater(local_pos, "Already a combo tower — pick a base tower!", Color(1.0, 0.72, 0.35))
				else:
					spawn_floater(local_pos, "Tap a glowing base tower (or Cancel)", Color(1.0, 0.88, 0.42))
			map_click_area.accept_event()
			return

		# 1) If a tower build type is armed, check combine target or placement zone / open pad
		if pending_build_type != "":
			var eval_armed: Dictionary = evaluate_drop_position(local_pos, pending_build_type)
			if str(eval_armed.get("mode", "")) == "combine":
				if bool(eval_armed["valid"]):
					combine_tower_with_shop(eval_armed.get("merge_target", null), pending_build_type)
					pending_build_type = ""
				map_click_area.accept_event()
				return
			var clicked_pad_armed: int = _find_pad_at(local_pos)
			if clicked_pad_armed != -1 and pad_occupancy[clicked_pad_armed] == null:
				build_tower_on_pad(clicked_pad_armed, pending_build_type)
				pending_build_type = ""
				map_click_area.accept_event()
				return
			if bool(eval_armed["valid"]):
				var p_idx: int = int(eval_armed["pad_idx"])
				if p_idx >= 0 and pad_occupancy[p_idx] == null:
					build_tower_on_pad(p_idx, pending_build_type)
				else:
					build_tower_in_zone(eval_armed["pos"], pending_build_type, int(eval_armed["zone_idx"]))
				pending_build_type = ""
				map_click_area.accept_event()
				return

		# 2) Check if clicking an existing tower (including free-dropped towers)
		var existing_t: TowerUnit = _find_tower_at(local_pos)
		if existing_t != null:
			pending_build_type = ""
			inspect_enemy(null)
			select_tower_unit(existing_t)
			map_click_area.accept_event()
			return

		# 2b) Check if clicking an active enemy on the path for live Enemy Inspector
		var clicked_enemy: EnemyUnit = _find_enemy_at(local_pos)
		if clicked_enemy != null:
			pending_build_type = ""
			inspect_enemy(clicked_enemy)
			map_click_area.accept_event()
			return
		inspect_enemy(null)

		# 3) Check if clicking a pad or a placement zone
		var clicked_pad: int = _find_pad_at(local_pos)
		if clicked_pad != -1:
			pending_build_type = ""
			select_pad(clicked_pad)
			map_click_area.accept_event()
			return

		var eval_sel: Dictionary = evaluate_drop_position(local_pos)
		if bool(eval_sel["valid"]):
			pending_build_type = ""
			selected_zone_index = int(eval_sel["zone_idx"])
			selected_drop_pos = eval_sel["pos"]
			selected_pad_index = int(eval_sel["pad_idx"])
			if selected_tower != null and is_instance_valid(selected_tower):
				selected_tower.is_selected = false
				selected_tower.queue_redraw()
			selected_tower = null
			pad_selected.emit(selected_pad_index if selected_pad_index >= 0 else 0)
			queue_redraw()
			map_click_area.accept_event()
			return

		pending_build_type = ""
		clear_selection()
		map_click_area.accept_event()


func select_tower_unit(tower: TowerUnit) -> void:
	if selected_tower != null and is_instance_valid(selected_tower):
		selected_tower.is_selected = false
		selected_tower.queue_redraw()
	selected_tower = tower
	selected_pad_index = tower.pad_index if tower != null else -1
	selected_zone_index = -1
	selected_drop_pos = Vector2(-1.0, -1.0)
	preview_tower_type = ""
	if selected_tower != null and is_instance_valid(selected_tower):
		selected_tower.is_selected = true
		selected_tower.queue_redraw()
		tower_selected.emit(selected_tower)
	queue_redraw()


func select_pad(pad_idx: int) -> void:
	selected_pad_index = pad_idx
	selected_zone_index = find_zone_for_point(active_pad_positions[pad_idx], 12.0) if (pad_idx >= 0 and pad_idx < active_pad_positions.size()) else -1
	selected_drop_pos = active_pad_positions[pad_idx] if (pad_idx >= 0 and pad_idx < active_pad_positions.size()) else Vector2(-1.0, -1.0)
	preview_tower_type = ""
	if selected_tower != null and is_instance_valid(selected_tower):
		selected_tower.is_selected = false
		selected_tower.queue_redraw()
	selected_tower = pad_occupancy[pad_idx] if (pad_idx >= 0 and pad_idx < pad_occupancy.size()) else null
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
	selected_zone_index = -1
	selected_drop_pos = Vector2(-1.0, -1.0)
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
	if pad_idx < 0 or pad_idx >= active_pad_positions.size():
		return null
	if pad_occupancy[pad_idx] != null:
		return null
	var cost: int = int(Balance.TOWERS[tower_type]["cost"])
	if not GameState.spend_money(cost, true):
		return null

	var tower: TowerUnit = tower_scene.instantiate()
	towers_container.add_child(tower)
	tower.setup(next_tower_id, tower_type, pad_idx, active_pad_positions[pad_idx], self)
	next_tower_id += 1
	pad_occupancy[pad_idx] = tower
	placed_towers.append(tower)
	preview_tower_type = ""
	if AnalyticsManager != null:
		AnalyticsManager.record_tower_build(tower_type, cost, get_zone_label_for_pad(pad_idx))
	select_pad(pad_idx)
	queue_redraw()
	return tower


func build_tower_in_zone(drop_pos: Vector2, tower_type: String, zone_idx: int = -1) -> TowerUnit:
	var eval: Dictionary = evaluate_drop_position(drop_pos)
	if not bool(eval["valid"]):
		return null
	var p_idx: int = int(eval["pad_idx"])
	if p_idx >= 0 and pad_occupancy[p_idx] == null:
		return build_tower_on_pad(p_idx, tower_type)

	var cost: int = int(Balance.TOWERS[tower_type]["cost"])
	if not GameState.spend_money(cost, true):
		return null

	var final_pos: Vector2 = eval["pos"]
	var nearest_pad: int = find_nearest_open_pad(final_pos, 38.0)
	var assigned_pad: int = nearest_pad
	var tower: TowerUnit = tower_scene.instantiate()
	towers_container.add_child(tower)
	tower.setup(next_tower_id, tower_type, assigned_pad, final_pos, self)
	next_tower_id += 1
	if assigned_pad >= 0 and assigned_pad < pad_occupancy.size() and pad_occupancy[assigned_pad] == null:
		pad_occupancy[assigned_pad] = tower
	placed_towers.append(tower)
	preview_tower_type = ""
	selected_zone_index = zone_idx
	if AnalyticsManager != null:
		var zlbl: String = str(active_placement_zones[zone_idx]["label"]) if (zone_idx >= 0 and zone_idx < active_placement_zones.size()) else str(eval.get("zone_label", ""))
		AnalyticsManager.record_tower_build(tower_type, cost, zlbl)
	select_tower_unit(tower)
	queue_redraw()
	return tower


func _clear_combine_highlights() -> void:
	for t in get_all_towers():
		if t.is_combine_highlighted:
			t.is_combine_highlighted = false
			t.queue_redraw()


func start_combine_partner_pick(source_tower: TowerUnit) -> int:
	cancel_combine_partner_pick()
	if source_tower == null or not is_instance_valid(source_tower) or not source_tower.can_combine():
		return 0
	combine_source_tower = source_tower
	pending_build_type = ""
	var count: int = 0
	for t in get_all_towers():
		if t != source_tower and t.can_combine():
			t.is_combine_highlighted = true
			t.queue_redraw()
			count += 1
	queue_redraw()
	return count


func cancel_combine_partner_pick() -> void:
	combine_source_tower = null
	_clear_combine_highlights()
	queue_redraw()


func combine_tower_with_shop(target_tower: TowerUnit, shop_type: String) -> TowerUnit:
	if target_tower == null or not is_instance_valid(target_tower) or not target_tower.can_combine():
		return null
	if not Balance.BASE_TOWER_KEYS.has(shop_type):
		return null
	var combo_key: String = Balance.get_combo_key(target_tower.tower_type, shop_type)
	if not Balance.TOWERS.has(combo_key):
		return null
	var upg_xfer: int = Balance.get_merge_upgrade_transfer_fee(target_tower.tower_type, target_tower.levels, shop_type, {}, combo_key)
	var cost: int = int(Balance.TOWERS[shop_type]["cost"]) + Balance.get_merge_surcharge(target_tower.tower_type, shop_type) + upg_xfer
	if not GameState.spend_money(cost, true):
		return null
	var prev_type_a: String = target_tower.tower_type
	var b_time: float = Balance.get_merge_build_time(prev_type_a, shop_type)
	cancel_combine_partner_pick()
	target_tower.transform_to_combo(combo_key, cost, target_tower.levels.duplicate(), b_time)
	if AnalyticsManager != null:
		AnalyticsManager.record_tower_combine(prev_type_a, shop_type, combo_key, cost, target_tower.total_spent, "drag_shop")
	select_tower_unit(target_tower)
	if SfxManager != null:
		SfxManager.play("combine")
	spawn_floater(target_tower.position + Vector2(-46.0, -32.0), "COMBINED: %s!" % str(Balance.TOWERS[combo_key]["name"]), Color(1.0, 0.88, 0.35))
	queue_redraw()
	return target_tower


func combine_two_towers(tower_a: TowerUnit, tower_b: TowerUnit) -> TowerUnit:
	if tower_a == null or tower_b == null or tower_a == tower_b:
		return null
	if not is_instance_valid(tower_a) or not is_instance_valid(tower_b):
		return null
	if not tower_a.can_combine() or not tower_b.can_combine():
		return null
	var combo_key: String = Balance.get_combo_key(tower_a.tower_type, tower_b.tower_type)
	if not Balance.TOWERS.has(combo_key):
		return null
	var upg_xfer: int = Balance.get_merge_upgrade_transfer_fee(tower_a.tower_type, tower_a.levels, tower_b.tower_type, tower_b.levels, combo_key)
	var surcharge: int = Balance.get_merge_surcharge(tower_a.tower_type, tower_b.tower_type) + upg_xfer
	if not GameState.spend_money(surcharge, true):
		return null
	var merged_levels := {
		"damage": maxi(int(tower_a.levels["damage"]), int(tower_b.levels["damage"])),
		"range": maxi(int(tower_a.levels["range"]), int(tower_b.levels["range"])),
		"fire_rate": maxi(int(tower_a.levels["fire_rate"]), int(tower_b.levels["fire_rate"])),
	}
	tower_a.total_damage_dealt += tower_b.total_damage_dealt
	tower_a.total_kills += tower_b.total_kills
	var added_spent: int = tower_b.total_spent + surcharge
	var b_pad: int = tower_b.pad_index
	if b_pad >= 0 and b_pad < pad_occupancy.size() and pad_occupancy[b_pad] == tower_b:
		pad_occupancy[b_pad] = null
	placed_towers.erase(tower_b)
	tower_b.queue_free()
	var prev_a: String = tower_a.tower_type
	var prev_b: String = tower_b.tower_type
	var b_time: float = Balance.get_merge_build_time(prev_a, prev_b)
	cancel_combine_partner_pick()
	tower_a.transform_to_combo(combo_key, added_spent, merged_levels, b_time)
	if AnalyticsManager != null:
		AnalyticsManager.record_tower_combine(prev_a, prev_b, combo_key, surcharge, tower_a.total_spent, "two_tower")
	select_tower_unit(tower_a)
	if SfxManager != null:
		SfxManager.play("combine")
	spawn_floater(tower_a.position + Vector2(-46.0, -32.0), "MERGED: %s!" % str(Balance.TOWERS[combo_key]["name"]), Color(1.0, 0.88, 0.35))
	queue_redraw()
	return tower_a


func sell_tower(tower: TowerUnit) -> int:
	if tower == null or not is_instance_valid(tower):
		return 0
	var sold_type: String = tower.tower_type
	var sold_dmg: float = tower.total_damage_dealt
	var sold_kills: int = tower.total_kills
	var refund: int = tower.get_sell_refund()
	var pad_idx: int = tower.pad_index
	if pad_idx >= 0 and pad_idx < pad_occupancy.size() and pad_occupancy[pad_idx] == tower:
		pad_occupancy[pad_idx] = null
	placed_towers.erase(tower)
	GameState.add_money(refund, false)
	if AnalyticsManager != null:
		AnalyticsManager.record_tower_sell(sold_type, refund, sold_dmg, sold_kills)
	GameState.event_logged.emit("Sold %s (+%d money)" % [Balance.TOWERS[sold_type]["name"], refund])
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
	for t in placed_towers:
		if t != null and is_instance_valid(t):
			list.append(t)
	for t in pad_occupancy:
		if t != null and is_instance_valid(t) and not list.has(t):
			list.append(t)
	return list


func _build_path_curve() -> void:
	var curve := Curve2D.new()
	var pts_src: Array[Vector2] = active_path_waypoints if not active_path_waypoints.is_empty() else PATH_WAYPOINTS
	for pt in pts_src:
		curve.add_point(pt)
	if enemy_path != null:
		enemy_path.curve = curve


func _reset_pad_occupancy() -> void:
	pad_occupancy.clear()
	var count: int = active_pad_positions.size() if not active_pad_positions.is_empty() else BUILD_PAD_POSITIONS.size()
	for _i in range(count):
		pad_occupancy.append(null)


func _on_mission_reset() -> void:
	if current_level_id != GameState.selected_map_level:
		load_level(GameState.selected_map_level)
	clear_all_enemies()
	clear_all_towers()
	clear_all_projectiles()
	floating_texts.clear()
	leak_flash_timer = 0.0
	hive_beam_timer = 0.0
	surge_explosion_timer = 0.0
	surge_explosion_sparks.clear()
	ability_fx_type = ""
	ability_fx_timer = 0.0
	ability_fx_particles.clear()
	selected_pad_index = -1
	selected_zone_index = -1
	selected_drop_pos = Vector2(-1.0, -1.0)
	selected_tower = null
	preview_tower_type = ""
	pending_build_type = ""
	combine_source_tower = null
	inspected_enemy = null
	_shake_timer = 0.0
	_shake_intensity = 0.0
	next_enemy_id = 1
	next_tower_id = 1
	queue_redraw()


func _on_enemy_leaked(_enemy_type: String, _lives_lost: int, _world_pos: Vector2) -> void:
	leak_flash_timer = 0.35
	trigger_screen_shake(0.22, 3.0)
	if SfxManager != null:
		SfxManager.play("leak")
	queue_redraw()


func _on_enemy_killed(enemy_type: String, money_gained: int, research_gained: int, world_pos: Vector2) -> void:
	if enemy_type == "juggernaut" or enemy_type == "colossus":
		trigger_screen_shake(0.28, 4.2)
	var local_p: Vector2 = to_local(world_pos)
	if floating_texts.size() < 32:
		floating_texts.append({
			"pos": local_p + Vector2(-18.0, -14.0),
			"money_text": "+%d$" % money_gained,
			"research_text": "+%dR" % research_gained,
			"timer": 0.9,
			"max_timer": 0.9,
		})
	queue_redraw()


func spawn_damage_popup(local_pos: Vector2, dmg_val: int, col: Color, is_crit: bool = false) -> void:
	if floating_texts.size() >= 32:
		return
	floating_texts.append({
		"pos": local_pos + Vector2(randf_range(-10.0, 10.0), -18.0),
		"custom_text": ("-%d!" % dmg_val) if is_crit else ("-%d" % dmg_val),
		"custom_color": col,
		"timer": 0.65,
		"max_timer": 0.65,
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


func spawn_projectile() -> ProjectileEffect:
	var proj: ProjectileEffect = projectile_scene.instantiate()
	if projectiles_container != null:
		projectiles_container.add_child(proj)
	return proj


func spawn_enemy(enemy_type: String, wave_num: int) -> EnemyUnit:
	var enemy: EnemyUnit = enemy_scene.instantiate()
	enemies_container.add_child(enemy)
	enemy.setup(next_enemy_id, enemy_type, wave_num, enemy_path.curve)
	next_enemy_id += 1
	enemy.leaked.connect(_on_unit_leaked)
	enemy.died.connect(_on_unit_died)
	return enemy


func sandbox_spawn_enemy(enemy_type: String, wave_num: int, count: int = 1) -> Array[EnemyUnit]:
	var spawned: Array[EnemyUnit] = []
	if enemy_path == null or enemy_path.curve == null:
		return spawned
	var safe_count: int = maxi(1, count)
	for i in range(safe_count):
		var e: EnemyUnit = spawn_enemy(enemy_type, maxi(1, wave_num))
		if i > 0:
			e.advance_along_path(float(i) * 0.22)
		spawned.append(e)
	GameState.event_logged.emit("[SANDBOX] Spawned %dx %s (Wave %d scale)" % [safe_count, Balance.ENEMIES[enemy_type]["name"], maxi(1, wave_num)])
	return spawned


func sandbox_clear_enemies() -> void:
	clear_all_enemies()
	clear_all_projectiles()
	GameState.event_logged.emit("[SANDBOX] Cleared all active enemies & bubbles")
	queue_redraw()


func sandbox_clear_towers() -> void:
	cancel_combine_partner_pick()
	clear_all_towers()
	clear_all_projectiles()
	clear_selection()
	GameState.event_logged.emit("[SANDBOX] Cleared all towers")
	queue_redraw()


func _on_unit_leaked(enemy: EnemyUnit) -> void:
	GameState.lose_lives(enemy.leak_cost, enemy.enemy_type, enemy.global_position)


func _on_unit_died(enemy: EnemyUnit) -> void:
	if AnalyticsManager != null:
		AnalyticsManager.record_enemy_progress(enemy.enemy_type, enemy.get_path_progress_pct(), false)
	var is_replay: bool = GameState.mission.replay_count_this_wave > 0
	GameState.award_kill_earnings(enemy.enemy_type, enemy.money_on_kill, enemy.research_on_kill, enemy.global_position, is_replay)


func get_active_enemies() -> Array[EnemyUnit]:
	var list: Array[EnemyUnit] = []
	for child in enemies_container.get_children():
		if child is EnemyUnit and not child.is_dead_or_leaked:
			list.append(child)
	return list


func clear_all_enemies() -> void:
	if enemies_container == null:
		return
	for child in enemies_container.get_children():
		if child is EnemyUnit:
			child.is_dead_or_leaked = true
		enemies_container.remove_child(child)
		child.queue_free()


func clear_all_towers() -> void:
	placed_towers.clear()
	if towers_container != null:
		for child in towers_container.get_children():
			towers_container.remove_child(child)
			child.queue_free()
	_reset_pad_occupancy()


func clear_all_projectiles() -> void:
	if projectiles_container == null:
		return
	for child in projectiles_container.get_children():
		projectiles_container.remove_child(child)
		child.queue_free()


func _find_pad_at(local_pos: Vector2) -> int:
	var half: float = PAD_SIZE * 0.5
	for i in range(active_pad_positions.size()):
		var p: Vector2 = active_pad_positions[i]
		var rect := Rect2(p.x - half, p.y - half, PAD_SIZE, PAD_SIZE)
		if rect.has_point(local_pos):
			return i
	var best_idx: int = -1
	var best_dist_sq: float = PAD_TOUCH_RADIUS * PAD_TOUCH_RADIUS
	for i in range(active_pad_positions.size()):
		var d_sq: float = local_pos.distance_squared_to(active_pad_positions[i])
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


## Continuous 0.0 -> 1.0 growing electrical buildup on the Player Base as the Surge deadline approaches.
func get_player_base_surge_buildup() -> float:
	var m := GameState.mission
	var span: float = float(Balance.MANIPULATOR_UPGRADES[4]["surge_wave_span"]) if m.manipulator_level >= 4 else float(Balance.SURGE_WAVE_SPAN)
	var waves_left: float = clampf(float(m.surge_deadline_wave - m.wave_number), 0.0, span)
	var wave_prog: float = clampf((span - waves_left) / maxf(1.0, span - 1.0), 0.0, 1.0)

	var win: float = float(Balance.MANIPULATOR_UPGRADES[4]["surge_window"]) if m.manipulator_level >= 4 else Balance.SURGE_BASE_WINDOW
	var rem_surge: float = m.surge_timer_seconds
	var timer_used: float = clampf(1.0 - (rem_surge / maxf(1.0, win)), 0.0, 1.0)
	var timer_prog: float = timer_used
	if rem_surge <= Balance.SURGE_WARNING_RED:
		timer_prog = 1.0
	elif rem_surge <= Balance.SURGE_WARNING_AMBER:
		timer_prog = maxf(timer_used, lerpf(0.82, 0.98, 1.0 - (rem_surge - Balance.SURGE_WARNING_RED) / maxf(0.1, Balance.SURGE_WARNING_AMBER - Balance.SURGE_WARNING_RED)))
	elif rem_surge <= 45.0:
		timer_prog = maxf(timer_used, lerpf(0.45, 0.82, 1.0 - (rem_surge - Balance.SURGE_WARNING_AMBER) / 30.0))

	return clampf(maxf(wave_prog, timer_prog), 0.0, 1.0)


## Visual state query for Player Base: distinctly separates "almost_dead" (low lives) from growing "surge_buildup" (0.0 -> 1.0) and "surge_exploding".
func get_player_base_visual_state() -> Dictionary:
	var m := GameState.mission
	var lives_ratio: float = clampf(float(m.lives) / float(Balance.PLAYER_STARTING_LIVES), 0.0, 1.0)
	var almost_dead: bool = m.lives <= 7
	var damaged: bool = m.lives <= 13

	var buildup: float = get_player_base_surge_buildup()
	var surge_stage: int = 0
	if buildup >= 0.80:
		surge_stage = 4
	elif buildup >= 0.60:
		surge_stage = 3
	elif buildup >= 0.38:
		surge_stage = 2
	elif buildup >= 0.15:
		surge_stage = 1

	var rem_surge: float = m.surge_timer_seconds
	var wave_near_deadline: bool = (m.wave_number + 1 >= m.surge_deadline_wave)
	var surge_imminent: bool = (rem_surge <= Balance.SURGE_WARNING_AMBER) or wave_near_deadline or (surge_stage >= 4)
	var surge_urgency: float = buildup
	var is_exploding: bool = (surge_explosion_timer > 0.0)

	var v_style: String = "nominal_citadel"
	if is_exploding:
		v_style = "electrical_surge_explosion"
	elif almost_dead and surge_imminent:
		v_style = "critical_hull_and_surge"
	elif almost_dead:
		v_style = "critical_hull_fire_smoke"
	elif surge_imminent:
		v_style = "temporal_overload_lightning"
	elif surge_stage >= 1:
		v_style = "surge_buildup_stage_%d" % surge_stage

	return {
		"lives": m.lives,
		"lives_ratio": lives_ratio,
		"damaged": damaged,
		"almost_dead": almost_dead,
		"surge_buildup": buildup,
		"surge_stage": surge_stage,
		"surge_imminent": surge_imminent,
		"surge_urgency": surge_urgency,
		"surge_exploding": is_exploding,
		"visual_style": v_style,
	}


## Visual state query for Alien Base (Enemy Hive): tracks damage stages (healthy/damaged/critical), spawn portal, and Hive Destroyer target lock.
func get_enemy_base_visual_state() -> Dictionary:
	var m := GameState.mission
	var hp_ratio: float = clampf(float(m.enemy_base_hp) / float(Balance.ENEMY_BASE_MAX_HP), 0.0, 1.0)
	var damage_stage: String = "healthy"
	if hp_ratio <= 0.34:
		damage_stage = "critical"
	elif hp_ratio <= 0.67:
		damage_stage = "damaged"
	return {
		"hp": m.enemy_base_hp,
		"hp_ratio": hp_ratio,
		"damage_stage": damage_stage,
		"almost_dead": hp_ratio <= 0.34,
		"target_locked": GameState.is_base_charging(),
		"spawning_active": GameState.is_wave_active,
	}


func _draw() -> void:
	if _shake_timer > 0.0 and _shake_intensity > 0.0:
		var ox: float = sin(visual_time * 58.0) * _shake_intensity * clampf(_shake_timer / 0.3, 0.0, 1.0)
		var oy: float = cos(visual_time * 67.0) * _shake_intensity * clampf(_shake_timer / 0.3, 0.0, 1.0)
		draw_set_transform(Vector2(ox, oy))
	else:
		draw_set_transform(Vector2.ZERO)
	var font: Font = ThemeDB.fallback_font
	var full_w: float = MAP_WIDTH + extra_left_margin + extra_right_margin
	var left_x: float = -extra_left_margin
	var right_x: float = MAP_WIDTH + extra_right_margin
	var arena_rect := Rect2(Vector2(left_x, 0.0), Vector2(full_w, MAP_HEIGHT))
	var lvl_cfg: Dictionary = get_level_config(current_level_id)
	var lvl_accent: Color = lvl_cfg["accent"]

	# 1) Deep sci-fi tactical terrain background + dual-scale sector grid
	draw_rect(arena_rect, Color(0.06, 0.08, 0.13))
	draw_rect(Rect2(Vector2(left_x + 12.0, 12.0), Vector2(full_w - 24.0, MAP_HEIGHT - 24.0)), Color(0.075, 0.10, 0.155))

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

	# Sector watermark in bottom-right corner
	draw_string(font, Vector2(695.0, 472.0), "%s (%s)" % [str(lvl_cfg["name"]), str(lvl_cfg["zone_rule"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(lvl_accent.r, lvl_accent.g, lvl_accent.b, 0.52))

	# 2) Refinery Annex industrial zone (bottom-left)
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

	# 3) Layered Path Transit Trench + Animated Directional Flow Chevrons
	if enemy_path != null and enemy_path.curve != null:
		var pts: PackedVector2Array = enemy_path.curve.get_baked_points()
		var wpts: Array[Vector2] = active_path_waypoints if not active_path_waypoints.is_empty() else PATH_WAYPOINTS
		if extra_left_margin > 0.0 and not wpts.is_empty():
			var lead_pts := PackedVector2Array([Vector2(left_x, wpts[0].y), wpts[0]])
			draw_polyline(lead_pts, Color(0.11, 0.15, 0.22), 34.0)
			draw_polyline(lead_pts, Color(0.18, 0.23, 0.32), 24.0)
		if extra_right_margin > 0.0 and not wpts.is_empty():
			var end_pt: Vector2 = wpts[wpts.size() - 1]
			var tail_pts := PackedVector2Array([end_pt, Vector2(right_x, end_pt.y)])
			draw_polyline(tail_pts, Color(0.11, 0.15, 0.22), 34.0)
			draw_polyline(tail_pts, Color(0.18, 0.23, 0.32), 24.0)
		if pts.size() >= 2:
			draw_polyline(pts, Color(0.04, 0.05, 0.08, 0.75), 40.0)
			draw_polyline(pts, Color(0.22, 0.28, 0.39), 34.0)
			draw_polyline(pts, Color(0.13, 0.17, 0.24), 26.0)
			draw_polyline(pts, Color(0.17, 0.22, 0.31), 18.0)
			var rail_col := Color(0.45, 0.88, 1.0, 0.55) if GameState.is_enemies_frozen else Color(0.36, 0.48, 0.66, 0.50)
			draw_polyline(pts, rail_col, 2.0)

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
			# Pre-Wave-1 bright animated route preview beacons so players immediately read the sector path
			if not GameState.is_wave_active and GameState.mission.wave_number == 1 and plen > 40.0:
				for b_i in range(4):
					var frac: float = fmod(visual_time * 0.18 + float(b_i) * 0.25, 1.0)
					var bp: Vector2 = enemy_path.curve.sample_baked(plen * frac, false)
					draw_circle(bp, 7.0, Color(0.35, 0.92, 1.0, 0.28))
					draw_circle(bp, 3.2, Color(0.75, 0.98, 1.0, 0.85))

	# 4) Designated Tower Placement Areas / Zones (Rows in Level 1; Columns, Islands, Spiral Pockets, Pillboxes in Levels 2-5)
	var active_preview_type: String = drag_tower_type if drag_tower_type != "" else (pending_build_type if pending_build_type != "" else preview_tower_type)
	var is_placing_any: bool = (drag_tower_type != "" or pending_build_type != "")
	var pulse_zone: float = 0.65 + 0.35 * sin(visual_time * 5.5)

	for z_i in range(active_placement_zones.size()):
		var zdef: Dictionary = active_placement_zones[z_i]
		var zrect: Rect2 = zdef["rect"]
		var is_active_drag_zone: bool = (drag_tower_type != "" and z_i == drag_zone_index and drag_valid_drop)
		var is_sel_zone: bool = (z_i == selected_zone_index)

		var fill_col := Color(0.10, 0.18, 0.28, 0.46)
		var border_col := Color(lvl_accent.r, lvl_accent.g, lvl_accent.b, 0.68)
		if is_active_drag_zone:
			fill_col = Color(0.14, 0.42, 0.34, 0.58)
			border_col = Color(0.42, 1.0, 0.76, 0.96)
		elif is_placing_any:
			fill_col = Color(0.12, 0.28, 0.38, 0.52)
			border_col = Color(0.42, 0.92, 1.0, 0.55 + 0.40 * pulse_zone)
		elif is_sel_zone:
			border_col = Color(1.0, 0.86, 0.38, 0.88)

		draw_rect(Rect2(zrect.position + Vector2(2, 2), zrect.size), Color(0.0, 0.0, 0.0, 0.32))
		draw_rect(zrect, fill_col)

		# Subtle internal blueprint grid stripes inside the placement zone
		var stripe_x: float = zrect.position.x + 20.0
		while stripe_x < zrect.end.x - 8.0:
			draw_line(Vector2(stripe_x, zrect.position.y + 3.0), Vector2(stripe_x, zrect.end.y - 3.0), Color(border_col.r, border_col.g, border_col.b, 0.16), 1.0)
			stripe_x += 24.0
		if zrect.size.y > 44.0:
			var stripe_y: float = zrect.position.y + 20.0
			while stripe_y < zrect.end.y - 8.0:
				draw_line(Vector2(zrect.position.x + 3.0, stripe_y), Vector2(zrect.end.x - 3.0, stripe_y), Color(border_col.r, border_col.g, border_col.b, 0.16), 1.0)
				stripe_y += 24.0

		draw_rect(zrect, border_col, false, 2.2 if (is_active_drag_zone or is_placing_any) else 1.5)

		# Zone Tag Badge
		var zlabel: String = str(zdef["label"])
		var tag_w: float = maxf(44.0, float(zlabel.length()) * 6.2 + 10.0)
		var tag_pos := Vector2(zrect.position.x, zrect.position.y - 13.0) if zrect.position.y >= 16.0 else Vector2(zrect.position.x + 4.0, zrect.position.y + 2.0)
		draw_rect(Rect2(tag_pos, Vector2(tag_w, 13.0)), Color(0.06, 0.10, 0.16, 0.90))
		draw_rect(Rect2(tag_pos, Vector2(tag_w, 13.0)), border_col, false, 1.0)
		draw_string(font, tag_pos + Vector2(4.0, 10.0), zlabel, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.75, 0.94, 1.0))

	# Subtle anchor sockets inside zones (also used for tap/click pad placement)
	for i in range(active_pad_positions.size()):
		var p: Vector2 = active_pad_positions[i]
		var is_sel: bool = (i == selected_pad_index)
		var is_hov: bool = (i == hovered_pad_index or i == drag_snap_pad_index)
		var is_open: bool = (i < pad_occupancy.size() and pad_occupancy[i] == null)
		if is_open:
			var sock_col := Color(0.32, 0.54, 0.76, 0.42)
			if is_sel:
				sock_col = Color(1.0, 0.88, 0.36, 0.95)
			elif is_hov:
				sock_col = Color(0.48, 1.0, 0.78, 0.90)
			draw_arc(p, 11.0, 0.0, TAU, 16, sock_col, 1.6 if (is_sel or is_hov) else 1.0)
			draw_circle(p, 2.2, sock_col)

	# 5) Range Ring & Drag-and-Drop Ghost Preview
	if active_preview_type != "":
		var show_preview: bool = false
		var center: Vector2 = Vector2.ZERO
		var valid_drop: bool = true
		var status_txt: String = ""

		if drag_tower_type != "":
			show_preview = true
			center = drag_drop_pos if drag_valid_drop else drag_local_pos
			valid_drop = drag_valid_drop
			status_txt = drag_status_reason
		elif pending_build_type != "" and hovered_pad_index >= 0 and hovered_pad_index < active_pad_positions.size() and pad_occupancy[hovered_pad_index] == null:
			show_preview = true
			center = active_pad_positions[hovered_pad_index]
			status_txt = "CLICK TO BUILD"
		elif selected_drop_pos.x >= 0.0:
			show_preview = true
			center = selected_drop_pos
		elif selected_pad_index >= 0 and selected_pad_index < active_pad_positions.size():
			show_preview = true
			center = active_pad_positions[selected_pad_index]

		if show_preview:
			var preview_key: String = drag_merge_combo_type if (drag_merge_combo_type != "" and Balance.TOWERS.has(drag_merge_combo_type)) else active_preview_type
			var cfg: Dictionary = Balance.TOWERS[preview_key]
			var r: float = float(cfg["range"]) * GameState.get_tower_range_research_multiplier()
			var min_r: float = float(cfg.get("min_range", 0.0))
			var is_combine_hover: bool = (drag_merge_target != null and drag_tower_type != "")
			var ring_fill := Color(1.0, 0.85, 0.28, 0.14) if (is_combine_hover and valid_drop) else (Color(0.35, 0.95, 0.72, 0.11) if valid_drop else Color(1.0, 0.32, 0.32, 0.11))
			var ring_stroke := Color(1.0, 0.88, 0.35, 0.95) if (is_combine_hover and valid_drop) else (Color(0.42, 1.0, 0.75, 0.88) if valid_drop else Color(1.0, 0.42, 0.38, 0.88))
			draw_circle(center, r, ring_fill)
			draw_arc(center, r, 0.0, TAU, 56, ring_stroke, 1.8)
			if min_r > 0.0:
				draw_circle(center, min_r, Color(1.0, 0.35, 0.35, 0.08))
				draw_arc(center, min_r, 0.0, TAU, 32, Color(1.0, 0.45, 0.45, 0.75), 1.5)
			if drag_tower_type != "":
				draw_circle(center, 18.0 if is_combine_hover else 15.0, Color(1.0, 0.86, 0.28, 0.45) if (is_combine_hover and valid_drop) else (Color(0.35, 0.95, 0.82, 0.42) if valid_drop else Color(1.0, 0.38, 0.32, 0.38)))
				draw_arc(center, 19.0 if is_combine_hover else 16.0, 0.0, TAU, 24, ring_stroke, 2.4)
				var box_w: float = maxf(130.0, float(status_txt.length()) * 6.5 + 16.0)
				draw_rect(Rect2(center + Vector2(-box_w * 0.5, -36.0), Vector2(box_w, 16.0)), Color(0.05, 0.08, 0.14, 0.94))
				draw_rect(Rect2(center + Vector2(-box_w * 0.5, -36.0), Vector2(box_w, 16.0)), ring_stroke, false, 1.2)
				draw_string(font, center + Vector2(-box_w * 0.5 + 6.0, -24.0), status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.92, 0.48) if (is_combine_hover and valid_drop) else (Color(0.55, 1.0, 0.82) if valid_drop else Color(1.0, 0.65, 0.55)))

	# 6) Alien Base (Enemy Hive Bio-Spire) with Animated Tendrils, Progressive Damage States, Spawn Vortex & Target Lock
	_draw_enemy_base(font)

	# 7) Hive Destroyer Orbital Beam Effect
	if hive_beam_timer > 0.0:
		var b_alpha: float = clampf(hive_beam_timer / 0.85, 0.0, 1.0)
		draw_line(active_player_base_pos, active_enemy_base_pos, Color(0.25, 0.78, 1.0, b_alpha * 0.35), 24.0)
		draw_line(active_player_base_pos, active_enemy_base_pos, Color(0.38, 0.92, 1.0, b_alpha * 0.85), 11.0)
		draw_line(active_player_base_pos, active_enemy_base_pos, Color(1.0, 0.98, 0.82, b_alpha), 4.2)
		draw_circle(active_enemy_base_pos, 42.0 * (1.25 - b_alpha * 0.4), Color(1.0, 0.75, 0.25, b_alpha * 0.45))
		draw_arc(active_enemy_base_pos, 48.0 * (1.0 - b_alpha * 0.5), 0.0, TAU, 36, Color(0.55, 0.96, 1.0, b_alpha * 0.9), 3.0)

	# 8) Player Base Citadel with Distinct Animations for "Almost Dead" (Critical Hull) and "About to Have a Surge" (Temporal Overload)
	_draw_player_base(font)

	# 8b) Time Ability Explosion / Detonation Animations (Pause Stasis Blast, Haste Overdrive Surge, Rewind Vortex)
	if ability_fx_timer > 0.0:
		_draw_ability_fx()

	# 9) Global Time Power Battlefield Border FX (Pause Stasis Frost / Haste Overclock)
	if GameState.is_enemies_frozen:
		draw_rect(arena_rect.grow(-2.0), Color(0.42, 0.88, 1.0, 0.45), false, 3.5)
	elif GameState.is_haste_active:
		draw_rect(arena_rect.grow(-2.0), Color(0.35, 1.0, 0.78, 0.40), false, 3.0)
	draw_rect(arena_rect, Color(0.24, 0.34, 0.48), false, 2.0)

	# 10) Floating earnings texts
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


func _draw_lightning_bolt(p_start: Vector2, p_end: Vector2, col: Color, width: float, seed_offset: float, branched: bool = false) -> void:
	var dir: Vector2 = p_end - p_start
	var len: float = dir.length()
	if len < 2.0:
		return
	var jitter: float = clampf(len * 0.16, 3.0, 14.0)
	var perp := Vector2(-dir.y, dir.x).normalized()
	var p1: Vector2 = p_start + dir * 0.28 + perp * (sin(visual_time * 26.0 + seed_offset) * jitter)
	var p2: Vector2 = p_start + dir * 0.56 - perp * (cos(visual_time * 31.0 + seed_offset * 1.7) * jitter)
	var p3: Vector2 = p_start + dir * 0.82 + perp * (sin(visual_time * 35.0 + seed_offset * 2.3) * jitter * 0.75)
	draw_line(p_start, p1, col, width)
	draw_line(p1, p2, col, width)
	draw_line(p2, p3, col, width * 0.9)
	draw_line(p3, p_end, col, width * 0.8)
	if branched:
		var fork_dir: Vector2 = (dir.normalized() + perp * (0.55 if int(seed_offset * 10.0) % 2 == 0 else -0.55)).normalized()
		var fork_end: Vector2 = p2 + fork_dir * (len * 0.36)
		var fork_mid: Vector2 = p2 + fork_dir * (len * 0.18) + perp * (cos(visual_time * 28.0 + seed_offset) * jitter * 0.45)
		var f_col := Color(col.r, col.g, col.b, col.a * 0.78)
		draw_line(p2, fork_mid, f_col, width * 0.7)
		draw_line(fork_mid, fork_end, f_col, width * 0.55)


func _draw_enemy_base(font: Font) -> void:
	var eb_pos: Vector2 = active_enemy_base_pos
	var eb_state: Dictionary = get_enemy_base_visual_state()
	var hp_ratio: float = float(eb_state["hp_ratio"])
	var stage: String = str(eb_state["damage_stage"])
	var is_crit: bool = (stage == "critical")
	var is_dmg: bool = (stage == "damaged" or is_crit)

	var pulse_spd: float = 10.5 if is_crit else (6.5 if is_dmg else 3.8)
	var hive_pulse: float = 0.65 + 0.35 * sin(visual_time * pulse_spd)

	# Active wave-spawning bio-portal vortex projecting toward the first waypoint
	if bool(eb_state["spawning_active"]) and not active_path_waypoints.is_empty():
		var spawn_dir: Vector2 = (active_path_waypoints[0] - eb_pos).normalized()
		var portal_pos: Vector2 = eb_pos + spawn_dir * 26.0
		var p_r1: float = 6.0 + fmod(visual_time * 18.0, 14.0)
		var p_r2: float = 6.0 + fmod(visual_time * 18.0 + 7.0, 14.0)
		draw_arc(portal_pos, p_r1, 0.0, TAU, 20, Color(1.0, 0.25, 0.45, 1.0 - (p_r1 / 20.0)), 2.0)
		draw_arc(portal_pos, p_r2, 0.0, TAU, 20, Color(0.85, 0.35, 1.0, 1.0 - (p_r2 / 20.0)), 1.6)

	# Base ground shadow & bio-creep aura
	draw_circle(eb_pos + Vector2(2, 3), 36.0, Color(0.0, 0.0, 0.0, 0.48))
	draw_arc(eb_pos, 38.0 + 2.5 * sin(visual_time * 2.5), 0.0, TAU, 32, Color(0.62, 0.12, 0.28, 0.38), 2.0)

	# 8 animated writhing organic bio-tendrils radiating from the Alien Hive
	for t_i in range(8):
		var base_ang: float = float(t_i) * TAU / 8.0 + visual_time * 0.22
		var wave_a: float = sin(visual_time * 4.2 + float(t_i) * 0.9) * 0.24
		var mid_pt: Vector2 = eb_pos + Vector2(cos(base_ang + wave_a), sin(base_ang + wave_a)) * 27.0
		var tip_len: float = 36.0 if (not is_crit or t_i % 2 == 0) else 29.0 # Severed tendrils when critical!
		var tip_pt: Vector2 = eb_pos + Vector2(cos(base_ang - wave_a * 1.2), sin(base_ang - wave_a * 1.2)) * tip_len
		var tendril_col := Color(0.78, 0.16, 0.30) if not is_crit else Color(0.96, 0.35, 0.22)
		draw_line(eb_pos, mid_pt, Color(0.45, 0.08, 0.18), 4.2)
		draw_line(mid_pt, tip_pt, tendril_col, 2.6)
		draw_circle(tip_pt, 2.8, Color(1.0, 0.48, 0.32, hive_pulse))

	# Outer & inner rotating organic chitin carapace
	var hive_outer := _make_regular_poly(eb_pos, 30.0, 8, visual_time * 0.25)
	var hive_inner := _make_regular_poly(eb_pos, 21.0, 8, -visual_time * 0.38)
	var eb_fill := Color(1.0, 0.82, 0.28) if hive_beam_timer > 0.0 else (Color(0.42, 0.08, 0.12) if is_crit else Color(0.32, 0.09, 0.14))
	draw_colored_polygon(hive_outer, eb_fill)
	for s_i in range(8):
		if is_crit and s_i % 3 == 0:
			continue # Shattered outer carapace gaps when critical
		draw_line(hive_outer[s_i], hive_outer[(s_i + 1) % 8], Color(1.0, 0.32, 0.36), 2.5)
	draw_colored_polygon(hive_inner, Color(0.52, 0.12, 0.22))

	# Progressive Damage Fissures & Bio-Plasma Venting when Damaged or Critical
	if is_dmg:
		var crack_count: int = 6 if is_crit else 3
		for c_i in range(crack_count):
			var c_ang: float = float(c_i) * TAU / float(crack_count) + 0.4
			var c_end: Vector2 = eb_pos + Vector2(cos(c_ang), sin(c_ang)) * 25.0
			_draw_lightning_bolt(eb_pos, c_end, Color(1.0, 0.62, 0.18, 0.92), 2.0, float(c_i) * 2.1)
	if is_crit:
		# Rising bio-smoke & unstable plasma spores on critical Alien Hive
		for sp_i in range(5):
			var phase: float = fmod(visual_time * 0.85 + float(sp_i) * 0.2, 1.0)
			var sx: float = eb_pos.x + sin(visual_time * 3.0 + float(sp_i) * 1.4) * 16.0
			var sy: float = eb_pos.y - 6.0 - phase * 28.0
			draw_circle(Vector2(sx, sy), 3.5 + phase * 4.0, Color(0.25, 0.08, 0.14, (1.0 - phase) * 0.65))
			draw_circle(Vector2(sx + 3.0, sy + 2.0), 2.2, Color(1.0, 0.45, 0.20, (1.0 - phase) * 0.9))

	# Throbbing Alien Hive Core + 4 Bio-Eye Nodes
	var core_r: float = 11.0 + 2.5 * sin(visual_time * pulse_spd)
	draw_circle(eb_pos, core_r, Color(0.95, 0.18, 0.32, hive_pulse))
	draw_circle(eb_pos, core_r * 0.52, Color(1.0, 0.72, 0.42))
	for e_i in range(4):
		var ea: float = float(e_i) * PI * 0.5 - visual_time * 0.8
		var ep: Vector2 = eb_pos + Vector2(cos(ea), sin(ea)) * 15.5
		draw_circle(ep, 2.6, Color(1.0, 0.85, 0.32, hive_pulse))

	# Circular Hive HP Arc around Alien Base
	var hp_col := Color(0.95, 0.26, 0.34) if not is_crit else Color(1.0, 0.52, 0.18, hive_pulse)
	draw_arc(eb_pos, 33.5, -PI * 0.5, -PI * 0.5 + TAU * hp_ratio, 32, hp_col, 2.6)

	# Hive Destroyer Orbital Target-Lock Animation while player is charging a shot
	if bool(eb_state["target_locked"]):
		var lock_rot: float = visual_time * 2.6
		var lock_r: float = 41.0 + 3.0 * sin(visual_time * 8.0)
		var lock_col := Color(0.38, 0.95, 1.0, 0.92)
		for b_i in range(4):
			var a0: float = lock_rot + float(b_i) * PI * 0.5 - 0.32
			var a1: float = lock_rot + float(b_i) * PI * 0.5 + 0.32
			draw_arc(eb_pos, lock_r, a0, a1, 10, lock_col, 2.4)
			var tick_in: Vector2 = eb_pos + Vector2(cos(lock_rot + float(b_i) * PI * 0.5), sin(lock_rot + float(b_i) * PI * 0.5)) * (lock_r - 7.0)
			var tick_out: Vector2 = eb_pos + Vector2(cos(lock_rot + float(b_i) * PI * 0.5), sin(lock_rot + float(b_i) * PI * 0.5)) * (lock_r + 5.0)
			draw_line(tick_in, tick_out, Color(1.0, 0.82, 0.28), 2.0)

	# Hive Tag Banner
	var hive_tag: String = "HIVE CRIT!" if is_crit else ("HIVE %d%%" % int(round(hp_ratio * 100.0)))
	var h_box_w: float = 64.0
	draw_rect(Rect2(eb_pos + Vector2(-h_box_w * 0.5, -49.0), Vector2(h_box_w, 14.0)), Color(0.08, 0.05, 0.08, 0.90))
	draw_rect(Rect2(eb_pos + Vector2(-h_box_w * 0.5, -49.0), Vector2(h_box_w, 14.0)), hp_col, false, 1.0)
	draw_string(font, eb_pos + Vector2(-h_box_w * 0.5 + 5.0, -38.0), hive_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.72, 0.68))


func _draw_player_base(font: Font) -> void:
	var pb_pos: Vector2 = active_player_base_pos
	var pb_state: Dictionary = get_player_base_visual_state()
	var lives_ratio: float = float(pb_state["lives_ratio"])
	var is_damaged: bool = bool(pb_state["damaged"])
	var is_almost_dead: bool = bool(pb_state["almost_dead"])
	var buildup: float = float(pb_state["surge_buildup"])
	var surge_stage: int = int(pb_state["surge_stage"])
	var is_surge_imminent: bool = bool(pb_state["surge_imminent"])
	var is_exploding: bool = bool(pb_state["surge_exploding"])

	# --- A) GROWING SURGE BUILDUP (Stages 1..4: progressively growing electrical field, ripples & orbiting nodes) ---
	if buildup >= 0.15:
		# Growing electrical corona aura around the base (radius grows from 20px at 15% up to 48px at 100%)
		var aura_r: float = lerpf(20.0, 48.0, buildup) + 2.5 * sin(visual_time * lerpf(3.0, 12.0, buildup))
		var aura_alpha: float = lerpf(0.08, 0.30, buildup)
		draw_circle(pb_pos, aura_r, Color(0.68, 0.32, 1.0, aura_alpha))

		# Concentric expanding electrical ripples: 1 ripple at Stage 2, 2 ripples at Stage 3, 3 fast ripples at Stage 4
		var ripple_count: int = 3 if surge_stage >= 4 else (2 if surge_stage == 3 else (1 if surge_stage == 2 else 0))
		var ripple_span: float = lerpf(24.0, 48.0, buildup)
		var ripple_spd: float = lerpf(12.0, 34.0, buildup)
		for r_i in range(ripple_count):
			var r_phase: float = fmod(visual_time * ripple_spd + float(r_i) * (ripple_span / float(maxi(1, ripple_count))), ripple_span)
			var r_rad: float = 20.0 + r_phase
			var r_alpha: float = clampf(1.0 - (r_phase / ripple_span), 0.0, 1.0) * lerpf(0.35, 0.85, buildup)
			var r_col := Color(0.78, 0.38, 1.0, r_alpha) if r_i % 2 == 0 else Color(0.45, 0.94, 1.0, r_alpha)
			if surge_stage >= 4 and r_i == 1:
				r_col = Color(1.0, 0.82, 0.28, r_alpha)
			draw_arc(pb_pos, r_rad, 0.0, TAU, 36, r_col, lerpf(1.5, 2.8, buildup))

	# --- B) "ALMOST DEAD" (Rotating Emergency Red Siren Cones behind the Citadel) ---
	if is_almost_dead:
		var siren_ang: float = visual_time * 4.8
		for s_cone in range(2):
			var a_mid: float = siren_ang + float(s_cone) * PI
			var cone_pts := PackedVector2Array([
				pb_pos,
				pb_pos + Vector2(cos(a_mid - 0.38), sin(a_mid - 0.38)) * 54.0,
				pb_pos + Vector2(cos(a_mid + 0.38), sin(a_mid + 0.38)) * 54.0,
			])
			draw_colored_polygon(cone_pts, Color(1.0, 0.15, 0.18, 0.26))

	# Base shadow & outer octagonal citadel hull
	draw_circle(pb_pos + Vector2(2, 3), 36.0, Color(0.0, 0.0, 0.0, 0.48))
	var pb_outer := _make_regular_poly(pb_pos, 34.0, 8, PI * 0.125)
	var pb_inner := _make_regular_poly(pb_pos, 25.0, 8, PI * 0.125)
	var pb_fill := Color(0.11, 0.24, 0.40)
	var pb_border := Color(0.38, 0.82, 1.0)
	if leak_flash_timer > 0.0:
		pb_fill = Color(0.88, 0.18, 0.20)
		pb_border = Color(1.0, 0.85, 0.85)
	elif is_almost_dead:
		var crit_pulse: float = 0.55 + 0.45 * sin(visual_time * 11.0)
		pb_fill = Color(0.34 + 0.18 * crit_pulse, 0.10, 0.14)
		pb_border = Color(1.0, 0.28, 0.28, 0.70 + 0.30 * crit_pulse)
	elif is_damaged:
		pb_fill = Color(0.20, 0.20, 0.30)
		pb_border = Color(1.0, 0.72, 0.28)

	draw_colored_polygon(pb_outer, Color(0.08, 0.14, 0.24))
	draw_colored_polygon(pb_inner, pb_fill)

	# Outer shield walls: intact when healthy, flickering broken segments when Almost Dead!
	for s_i in range(8):
		if is_almost_dead and int(floor(visual_time * 10.0) + s_i) % 3 == 0:
			continue
		draw_line(pb_outer[s_i], pb_outer[(s_i + 1) % 8], pb_border, 2.8)

	# --- C) Structural Hull Cracks, Smoke Plumes & Flying Sparks when Damaged / Almost Dead ---
	if is_damaged:
		var num_cracks: int = 6 if is_almost_dead else 3
		for c_i in range(num_cracks):
			var ca: float = float(c_i) * TAU / float(num_cracks) + 0.25
			var c_mid: Vector2 = pb_pos + Vector2(cos(ca + 0.18), sin(ca + 0.18)) * 14.0
			var c_tip: Vector2 = pb_pos + Vector2(cos(ca - 0.12), sin(ca - 0.12)) * 27.0
			var crack_col := Color(1.0, 0.24, 0.15, 0.95) if is_almost_dead else Color(1.0, 0.62, 0.22, 0.80)
			draw_line(pb_pos + Vector2(cos(ca), sin(ca)) * 5.0, c_mid, crack_col, 2.2)
			draw_line(c_mid, c_tip, crack_col, 1.8)

	if is_almost_dead:
		for sm_i in range(6):
			var phase: float = fmod(visual_time * 0.95 + float(sm_i) * 0.17, 1.0)
			var smoke_x: float = pb_pos.x + cos(float(sm_i) * 1.1) * 15.0 + sin(visual_time * 3.0 + float(sm_i)) * 5.0
			var smoke_y: float = pb_pos.y - 4.0 - phase * 32.0
			draw_circle(Vector2(smoke_x, smoke_y), 3.8 + phase * 4.5, Color(0.14, 0.12, 0.15, (1.0 - phase) * 0.72))
		for sp_i in range(4):
			var sp_phase: float = fmod(visual_time * 3.4 + float(sp_i) * 0.25, 1.0)
			var sp_ang: float = float(sp_i) * PI * 0.5 + sin(visual_time * 9.0 + float(sp_i))
			var sp_p1: Vector2 = pb_pos + Vector2(cos(sp_ang), sin(sp_ang)) * (14.0 + sp_phase * 18.0)
			var sp_p2: Vector2 = sp_p1 + Vector2(cos(sp_ang), sin(sp_ang)) * 5.5
			draw_line(sp_p1, sp_p2, Color(1.0, 0.85, 0.28, 1.0 - sp_phase), 2.0)

	# --- D) Time Manipulator Chronosphere Dome & Progressively Growing Lightning Arcs ---
	var spin_mult: float = lerpf(1.0, 4.4, buildup)
	var manip_col := Color(0.45, 0.94, 1.0).lerp(Color(0.88, 0.42, 1.0), buildup)
	if GameState.is_base_locked():
		manip_col = Color(1.0, 0.75, 0.28)
	draw_arc(pb_pos, 16.5 + buildup * 2.5, visual_time * 1.8 * spin_mult, visual_time * 1.8 * spin_mult + PI * 1.35, 24, manip_col, 2.2 + buildup * 0.8)
	draw_arc(pb_pos, 11.5 + buildup * 1.5, -visual_time * 2.5 * spin_mult, -visual_time * 2.5 * spin_mult + PI * 1.35, 20, Color(0.75, 0.55, 1.0, 0.9).lerp(Color(1.0, 0.82, 0.28, 0.98), buildup), 2.0)

	if surge_stage >= 1:
		# Lightning bolts grow in count (2 -> 4 -> 6 -> 8), reach (14px -> 24px -> 34px -> 45px), thickness, and branching!
		var bolt_count: int = 2 + surge_stage * 2
		var bolt_reach: float = lerpf(14.0, 44.0, buildup)
		var bolt_width: float = lerpf(1.3, 2.5, buildup)
		for b_i in range(bolt_count):
			var b_ang: float = float(b_i) * TAU / float(bolt_count) + visual_time * (1.2 + buildup * 2.5) + sin(visual_time * 8.0 + float(b_i)) * 0.25
			var b_end: Vector2 = pb_pos + Vector2(cos(b_ang), sin(b_ang)) * bolt_reach
			var b_col := Color(0.45, 0.96, 1.0, 0.88) if b_i % 3 == 0 else (Color(0.88, 0.45, 1.0, 0.95) if b_i % 3 == 1 else Color(1.0, 0.86, 0.32, 0.95))
			_draw_lightning_bolt(pb_pos, b_end, b_col, bolt_width, float(b_i) * 1.9, surge_stage >= 3)

		# Orbiting electrical plasma nodes appear at Stage 2+ and multiply as charge builds
		if surge_stage >= 2:
			var node_count: int = surge_stage + 1
			var orbit_r: float = lerpf(22.0, 32.0, buildup)
			for n_i in range(node_count):
				var na: float = float(n_i) * TAU / float(node_count) + visual_time * (2.5 + buildup * 3.0)
				var np: Vector2 = pb_pos + Vector2(cos(na), sin(na)) * orbit_r
				draw_circle(np, 2.2 + buildup * 1.8, Color(0.85, 0.48, 1.0, 0.9))
				draw_circle(np, 1.2 + buildup * 0.8, Color(1.0, 0.95, 0.75))

	# Swelling Chronosphere Core (grows from 6.2px up to 11.2px as electrical charge builds up)
	var core_rad: float = lerpf(6.2, 10.6, buildup) + (2.0 * sin(visual_time * 16.0) if buildup >= 0.5 else 0.0)
	draw_circle(pb_pos, core_rad, manip_col)
	draw_circle(pb_pos, core_rad * 0.48, Color.WHITE)

	# --- E) ELECTRICAL SURGE EXPLOSION DETONATION (When Surge Triggers!) ---
	if is_exploding:
		var exp_prog: float = clampf(1.0 - (surge_explosion_timer / maxf(0.01, surge_explosion_max_timer)), 0.0, 1.0)
		var exp_alpha: float = clampf(1.0 - exp_prog, 0.0, 1.0)

		# 1) Blinding high-voltage core detonation flash dome
		if exp_prog < 0.45:
			var flash_a: float = clampf(1.0 - (exp_prog / 0.45), 0.0, 1.0)
			draw_circle(pb_pos, 28.0 + exp_prog * 95.0, Color(0.75, 0.42, 1.0, flash_a * 0.52))
			draw_circle(pb_pos, 18.0 + exp_prog * 55.0, Color(0.55, 0.98, 1.0, flash_a * 0.78))
			draw_circle(pb_pos, 14.0 + exp_prog * 25.0, Color(1.0, 1.0, 1.0, flash_a * 0.95))

		# 2) 3 Concentric High-Voltage Expanding EMP Blast Shockwaves across the battlefield
		for w_i in range(3):
			var w_delay: float = float(w_i) * 0.14
			var w_p: float = clampf((exp_prog - w_delay) / (1.0 - w_delay), 0.0, 1.0)
			if w_p > 0.0 and w_p < 1.0:
				var w_rad: float = 24.0 + w_p * 340.0
				var w_a: float = (1.0 - w_p) * 0.92
				var w_col := Color(0.45, 0.96, 1.0, w_a) if w_i == 0 else (Color(0.88, 0.42, 1.0, w_a) if w_i == 1 else Color(1.0, 0.86, 0.32, w_a))
				draw_arc(pb_pos, w_rad, 0.0, TAU, 64, w_col, 4.2 * (1.0 - w_p * 0.5))

		# 3) 12 Giant Radial Branched Lightning Bolts erupting outward from the Player Base
		for eb_i in range(12):
			var eb_ang: float = float(eb_i) * TAU / 12.0 + sin(visual_time * 19.0 + float(eb_i)) * 0.18
			var eb_len: float = (70.0 + float((eb_i * 29) % 85)) * (0.35 + 0.65 * sin(minf(1.0, exp_prog * 2.2) * PI * 0.5))
			var eb_end: Vector2 = pb_pos + Vector2(cos(eb_ang), sin(eb_ang)) * eb_len
			var eb_col := Color(0.52, 0.98, 1.0, exp_alpha) if eb_i % 3 == 0 else (Color(0.92, 0.45, 1.0, exp_alpha) if eb_i % 3 == 1 else Color(1.0, 0.92, 0.45, exp_alpha))
			_draw_lightning_bolt(pb_pos, eb_end, eb_col, 3.0 * exp_alpha + 1.0, float(eb_i) * 3.1, true)

		# 4) Chain-Lightning Surge Arcs striking every built Player Tower on the map (-5% speed shock visual!)
		for t_unit in get_all_towers():
			var t_pos: Vector2 = t_unit.position
			_draw_lightning_bolt(pb_pos, t_pos, Color(0.78, 0.45, 1.0, exp_alpha * 0.85), 2.2 * exp_alpha, float(t_unit.tower_id) * 2.7, true)
			draw_arc(t_pos, 20.0 + 4.0 * sin(visual_time * 25.0), 0.0, TAU, 24, Color(0.48, 0.96, 1.0, exp_alpha * 0.9), 2.2)

		# 5) 28 Flying High-Voltage Electric Spark Particles
		for sp in surge_explosion_sparks:
			var sp_pos: Vector2 = sp["pos"]
			var sp_vel: Vector2 = sp["vel"]
			var sp_col: Color = sp["color"]
			sp_col.a = exp_alpha
			var tail: Vector2 = sp_pos - sp_vel.normalized() * 8.0
			draw_line(tail, sp_pos, sp_col, 2.2)
			draw_circle(sp_pos, 2.4, Color(1.0, 1.0, 1.0, exp_alpha))

	# Circular Lives Integrity Arc around the Player Base
	var life_arc_col := Color(0.35, 0.95, 0.75) if not is_damaged else (Color(1.0, 0.25, 0.25) if is_almost_dead else Color(1.0, 0.78, 0.28))
	draw_arc(pb_pos, 37.5, -PI * 0.5, -PI * 0.5 + TAU * lives_ratio, 32, life_arc_col, 2.4)

	# Status Badges above/below Player Base
	if is_almost_dead:
		var c_box := Rect2(pb_pos + Vector2(-42.0, -52.0), Vector2(84.0, 14.0))
		draw_rect(c_box, Color(0.22, 0.04, 0.06, 0.94))
		draw_rect(c_box, Color(1.0, 0.28, 0.28), false, 1.2)
		draw_string(font, c_box.position + Vector2(5.0, 11.0), "CRITICAL %d HP" % int(pb_state["lives"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.75, 0.75))
	else:
		draw_rect(Rect2(pb_pos + Vector2(-22, -50), Vector2(44, 14)), Color(0.05, 0.09, 0.16, 0.88))
		draw_string(font, pb_pos + Vector2(-16, -39), "BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.94, 1.0))

	if is_exploding:
		var e_box := Rect2(pb_pos + Vector2(-52.0, 40.0), Vector2(104.0, 15.0))
		draw_rect(e_box, Color(0.24, 0.06, 0.34, 0.96))
		draw_rect(e_box, Color(0.55, 0.98, 1.0), false, 1.5)
		draw_string(font, e_box.position + Vector2(5.0, 11.0), "ELECTRICAL SURGE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.92, 0.45))
	elif is_surge_imminent:
		var s_pulse: float = 0.65 + 0.35 * sin(visual_time * 12.0)
		var s_box := Rect2(pb_pos + Vector2(-46.0, 40.0), Vector2(92.0, 14.0))
		draw_rect(s_box, Color(0.16, 0.06, 0.26, 0.94))
		draw_rect(s_box, Color(0.88, 0.45, 1.0, s_pulse), false, 1.2)
		draw_string(font, s_box.position + Vector2(5.0, 11.0), "SURGE IMMINENT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.86, 0.42))
	elif surge_stage >= 2:
		var chg_pct: int = int(round(buildup * 100.0))
		var b_box := Rect2(pb_pos + Vector2(-46.0, 40.0), Vector2(92.0, 14.0))
		draw_rect(b_box, Color(0.10, 0.06, 0.20, 0.90))
		draw_rect(b_box, Color(0.68, 0.42, 0.98, 0.82), false, 1.0)
		draw_string(font, b_box.position + Vector2(5.0, 11.0), "SURGE CHARGE %d%%" % chg_pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.75, 1.0))


func _draw_ability_fx() -> void:
	var pb_pos: Vector2 = active_player_base_pos
	var prog: float = clampf(1.0 - (ability_fx_timer / maxf(0.01, ability_fx_max_timer)), 0.0, 1.0)
	var alpha: float = clampf(1.0 - prog, 0.0, 1.0)

	if ability_fx_type == "pause":
		# 1) Cryo-Temporal Stasis Core Flash
		if prog < 0.42:
			var fa: float = clampf(1.0 - (prog / 0.42), 0.0, 1.0)
			draw_circle(pb_pos, 26.0 + prog * 88.0, Color(0.32, 0.88, 1.0, fa * 0.48))
			draw_circle(pb_pos, 16.0 + prog * 36.0, Color(0.92, 0.99, 1.0, fa * 0.88))

		# 2) 2 Sweeping Frost Shockwave Rings + Expanding Hexagonal Stasis Crystal Polygon
		for w_i in range(2):
			var delay: float = float(w_i) * 0.16
			var wp: float = clampf((prog - delay) / (1.0 - delay), 0.0, 1.0)
			if wp > 0.0 and wp < 1.0:
				var rad: float = 24.0 + wp * 880.0
				var wa: float = (1.0 - wp) * 0.90
				draw_arc(pb_pos, rad, 0.0, TAU, 72, Color(0.45, 0.95, 1.0, wa) if w_i == 0 else Color(0.88, 0.98, 1.0, wa), 4.0 * (1.0 - wp * 0.5))
		var hex_r: float = 30.0 + prog * 480.0
		var hex_poly := _make_regular_poly(pb_pos, hex_r, 6, visual_time * 0.35)
		for hi in range(6):
			draw_line(hex_poly[hi], hex_poly[(hi + 1) % 6], Color(0.55, 0.96, 1.0, alpha * 0.72), 2.5)

		# 3) Radial Time-Crystal Fracture Rays from Player Base
		for ray_i in range(12):
			var r_ang: float = float(ray_i) * TAU / 12.0
			var r_len: float = (55.0 + float((ray_i * 23) % 70)) * sin(minf(1.0, prog * 1.9) * PI * 0.5)
			var r_end: Vector2 = pb_pos + Vector2(cos(r_ang), sin(r_ang)) * r_len
			draw_line(pb_pos, r_end, Color(0.65, 0.98, 1.0, alpha * 0.85), 2.2)
			draw_circle(r_end, 3.2 * alpha, Color.WHITE)

		# 4) Stasis Diamond Lock Rings on every frozen Enemy on the map
		for e_unit in get_active_enemies():
			var e_pos: Vector2 = e_unit.position
			var e_r: float = 14.0 + 18.0 * (1.0 - alpha)
			draw_arc(e_pos, e_r, 0.0, TAU, 16, Color(0.45, 0.96, 1.0, alpha * 0.88), 2.0)
			draw_line(e_pos + Vector2(-8, 0), e_pos + Vector2(8, 0), Color(0.90, 0.98, 1.0, alpha * 0.75), 1.5)
			draw_line(e_pos + Vector2(0, -8), e_pos + Vector2(0, 8), Color(0.90, 0.98, 1.0, alpha * 0.75), 1.5)

		# 5) 28 Flying Ice-Diamond Shards
		for p in ability_fx_particles:
			var p_pos: Vector2 = p["pos"]
			var p_col: Color = p["color"]
			p_col.a = alpha
			var dir: Vector2 = Vector2(cos(float(p["angle"])), sin(float(p["angle"])))
			draw_line(p_pos - dir * 5.0, p_pos + dir * 5.0, p_col, 2.4)
			draw_circle(p_pos, 2.2, Color(1.0, 1.0, 1.0, alpha))

	elif ability_fx_type == "haste":
		# 1) Chrono Overdrive Core Flash
		if prog < 0.40:
			var fa: float = clampf(1.0 - (prog / 0.40), 0.0, 1.0)
			draw_circle(pb_pos, 28.0 + prog * 90.0, Color(0.30, 1.0, 0.72, fa * 0.48))
			draw_circle(pb_pos, 16.0 + prog * 40.0, Color(1.0, 0.92, 0.42, fa * 0.85))

		# 2) 3 Hyper-Velocity Concentric Acceleration Rings
		for w_i in range(3):
			var delay: float = float(w_i) * 0.12
			var wp: float = clampf((prog - delay) / (1.0 - delay), 0.0, 1.0)
			if wp > 0.0 and wp < 1.0:
				var rad: float = 22.0 + wp * 780.0
				var wa: float = (1.0 - wp) * 0.90
				var w_col := Color(0.32, 1.0, 0.74, wa) if w_i % 2 == 0 else Color(1.0, 0.86, 0.28, wa)
				draw_arc(pb_pos, rad, 0.0, TAU, 64, w_col, 3.8 * (1.0 - wp * 0.45))

		# 3) Radial Kinetic Overdrive Bolts & Speed Streaks
		for b_i in range(12):
			var ang: float = float(b_i) * TAU / 12.0 + prog * 1.4
			var blen: float = 65.0 + float((b_i * 31) % 80) * sin(minf(1.0, prog * 2.0) * PI * 0.5)
			var bend: Vector2 = pb_pos + Vector2(cos(ang), sin(ang)) * blen
			var b_col := Color(0.35, 1.0, 0.78, alpha) if b_i % 2 == 0 else Color(1.0, 0.88, 0.34, alpha)
			_draw_lightning_bolt(pb_pos, bend, b_col, 2.5 * alpha + 0.8, float(b_i) * 2.3, true)

		# 4) Golden-Emerald Overclock Conduits linking Player Base directly to every Tower!
		for t_unit in get_all_towers():
			var t_pos: Vector2 = t_unit.position
			_draw_lightning_bolt(pb_pos, t_pos, Color(0.35, 1.0, 0.76, alpha * 0.85), 2.2 * alpha, float(t_unit.tower_id) * 1.9, false)
			draw_arc(t_pos, 22.0 + 5.0 * sin(visual_time * 24.0), 0.0, TAU, 24, Color(1.0, 0.88, 0.35, alpha * 0.92), 2.4)

		# 5) 28 Flying Emerald/Gold Velocity Sparks
		for p in ability_fx_particles:
			var p_pos: Vector2 = p["pos"]
			var p_vel: Vector2 = p["vel"]
			var p_col: Color = p["color"]
			p_col.a = alpha
			var tail: Vector2 = p_pos - p_vel.normalized() * 11.0
			draw_line(tail, p_pos, p_col, 2.4)
			draw_circle(p_pos, 2.2, Color(1.0, 1.0, 0.85, alpha))

	else: # "rewind"
		# 1) Reverse-Temporal Core Vortex Flash
		if prog < 0.48:
			var fa: float = clampf(1.0 - (prog / 0.48), 0.0, 1.0)
			draw_circle(pb_pos, 28.0 + prog * 96.0, Color(0.72, 0.35, 1.0, fa * 0.50))
			draw_circle(pb_pos, 16.0 + prog * 45.0, Color(1.0, 0.78, 0.35, fa * 0.82))

		# 2) Giant Counter-Clockwise Spinning Temporal Clock Dial around Player Base
		var dial_r: float = 44.0 + sin(minf(1.0, prog * 1.6) * PI) * 28.0
		draw_arc(pb_pos, dial_r, 0.0, TAU, 36, Color(0.86, 0.48, 1.0, alpha * 0.92), 2.6)
		var ccw_fast := Vector2.RIGHT.rotated(-prog * TAU * 3.5) * (dial_r * 0.86)
		var ccw_slow := Vector2.RIGHT.rotated(-prog * TAU * 1.25 - 1.1) * (dial_r * 0.60)
		draw_line(pb_pos, pb_pos + ccw_fast, Color(1.0, 0.90, 0.42, alpha), 2.8)
		draw_line(pb_pos, pb_pos + ccw_slow, Color(0.95, 0.85, 1.0, alpha), 2.2)

		# 3) 3 Reverse-Time Ripple Waves sweeping all the way across the Arena toward the Hive
		for w_i in range(3):
			var delay: float = float(w_i) * 0.14
			var wp: float = clampf((prog - delay) / (1.0 - delay), 0.0, 1.0)
			if wp > 0.0 and wp < 1.0:
				var rad: float = lerpf(920.0, 20.0, wp) if w_i == 2 else (24.0 + wp * 900.0)
				var wa: float = (1.0 - wp) * 0.85
				var w_col := Color(0.84, 0.44, 1.0, wa) if w_i % 2 == 0 else Color(1.0, 0.78, 0.32, wa)
				draw_arc(pb_pos, rad, 0.0, TAU, 72, w_col, 3.6 * (1.0 - wp * 0.4))

		# 4) Backward Temporal Echo Pulses racing along Enemy Path back to the Alien Base!
		if enemy_path != null and enemy_path.curve != null:
			var plen: float = enemy_path.curve.get_baked_length()
			if plen > 10.0:
				for e_i in range(6):
					var path_frac: float = clampf(1.0 - fmod(prog * 1.3 + float(e_i) * 0.16, 1.0), 0.0, 1.0)
					var p_pt: Vector2 = enemy_path.curve.sample_baked(plen * path_frac, false)
					draw_arc(p_pt, 12.0 + 10.0 * sin(prog * PI), 0.0, TAU, 18, Color(0.88, 0.50, 1.0, alpha * 0.82), 2.2)

		# 5) 28 Swirling Violet/Gold Chronon Particles
		for p in ability_fx_particles:
			var p_pos: Vector2 = p["pos"]
			var p_col: Color = p["color"]
			p_col.a = alpha
			draw_circle(p_pos, 3.2 * alpha + 1.0, p_col)
			draw_circle(p_pos, 1.4, Color(1.0, 0.96, 0.82, alpha))
