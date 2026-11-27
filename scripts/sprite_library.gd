extends RefCounted
class_name SpriteLibrary

## Central texture & pivot registry for all 43 custom TimeDefense sprites
## (6 base towers, 21 combined towers, 10 enemies, 5 structures, 1 guide portrait).
## Gracefully falls back to null if an asset is missing so procedural vectors can render instead.

const ROOT: String = "res://assets/sprites/"
const META_PATH: String = "res://assets/sprites/sprite_pivots.json"

static var _textures: Dictionary = {}
static var _icon_cache: Dictionary = {}
static var _meta: Dictionary = {}
static var _meta_loaded: bool = false


static func _ensure_meta() -> void:
	if _meta_loaded:
		return
	_meta_loaded = true
	if not FileAccess.file_exists(META_PATH):
		return
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_meta = parsed


static func _load_tex(res_path: String) -> Texture2D:
	if _textures.has(res_path):
		return _textures[res_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		var loaded = ResourceLoader.load(res_path)
		if loaded is Texture2D:
			tex = loaded
	if tex == null and FileAccess.file_exists(res_path):
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(res_path)) == OK:
			tex = ImageTexture.create_from_image(img)
	_textures[res_path] = tex
	return tex


static func get_tower_texture(tower_type: String) -> Texture2D:
	var file_key: String = tower_type.replace("+", "_")
	return _load_tex(ROOT + "towers/" + file_key + ".png")


static func get_tower_meta(tower_type: String) -> Dictionary:
	_ensure_meta()
	var k: String = "tower:" + tower_type
	if _meta.has(k):
		return _meta[k]
	return {"pivot_x": 0.5, "pivot_y": 0.5, "base_h_ratio": 1.0, "radial": false}


static func get_enemy_texture(enemy_type: String) -> Texture2D:
	return _load_tex(ROOT + "enemies/" + enemy_type + ".png")


static func get_structure_texture(struct_key: String) -> Texture2D:
	return _load_tex(ROOT + "structures/" + struct_key + ".png")


static func get_character_texture(char_key: String) -> Texture2D:
	return _load_tex(ROOT + "characters/" + char_key + ".png")


## Draws a texture centered around `pivot_norm` at `center`, rotated by `angle` radians.
## Preserves any parent `_draw()` translation passed via `restore_offset` (e.g. map screen shake).
static func draw_sprite_oriented(
	canvas: CanvasItem,
	tex: Texture2D,
	center: Vector2,
	angle: float,
	draw_size: Vector2,
	pivot_norm: Vector2 = Vector2(0.5, 0.5),
	modulate: Color = Color.WHITE,
	restore_offset: Vector2 = Vector2.ZERO
) -> void:
	if tex == null or draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return
	canvas.draw_set_transform(center + restore_offset, angle, Vector2.ONE)
	var rect := Rect2(-draw_size * pivot_norm, draw_size)
	canvas.draw_texture_rect(tex, rect, false, modulate)
	canvas.draw_set_transform(restore_offset, 0.0, Vector2.ONE)


## Computes aspect-preserving draw size for a tower so its circular/octagonal pedestal
## consistently fills `pedestal_px` while long barrels extend naturally beyond the pad.
static func compute_tower_draw_size(tex: Texture2D, meta: Dictionary, pedestal_px: float = 36.0, max_width_px: float = 64.0) -> Vector2:
	if tex == null:
		return Vector2(pedestal_px, pedestal_px)
	var tw: float = maxf(1.0, float(tex.get_width()))
	var th: float = maxf(1.0, float(tex.get_height()))
	var base_h_ratio: float = clampf(float(meta.get("base_h_ratio", 1.0)), 0.72, 1.0)
	var target_h: float = pedestal_px / base_h_ratio
	var scale_f: float = target_h / th
	var draw_w: float = tw * scale_f
	var draw_h: float = th * scale_f
	if draw_w > max_width_px:
		var clamp_s: float = max_width_px / draw_w
		draw_w *= clamp_s
		draw_h *= clamp_s
	return Vector2(draw_w, draw_h)


## Builds a crisp cached UI badge thumbnail from any custom sprite texture.
static func get_ui_badge_icon(kind: String, icon_size: int = 28) -> ImageTexture:
	var cache_key: String = "%s:%d" % [kind, icon_size]
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key]

	var tex: Texture2D = null
	if kind in ["blaster", "mortar", "laser", "slow", "railgun", "annihilator"] or kind.contains("+"):
		tex = get_tower_texture(kind)
	elif Balance.ENEMIES.has(kind):
		tex = get_enemy_texture(kind)
	elif kind in ["manipulator", "efficient_manipulator"]:
		tex = get_structure_texture("chrono_manipulator")
	elif kind in ["hive_breaker", "hive_destroyer"]:
		tex = get_structure_texture("hive_destroyer")
	elif kind == "refinery":
		tex = get_structure_texture("refinery")

	if tex == null:
		return null
	var src_img: Image = tex.get_image()
	if src_img == null or src_img.is_empty():
		return null

	var img := Image.create(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half: float = float(icon_size) * 0.5
	var r_outer: float = half - 0.5
	for y in range(icon_size):
		for x in range(icon_size):
			var dx: float = (float(x) + 0.5) - half
			var dy: float = (float(y) + 0.5) - half
			var d: float = sqrt(dx * dx + dy * dy)
			if d <= r_outer:
				if d >= r_outer - 1.3:
					img.set_pixel(x, y, Color(0.28, 0.42, 0.60, 0.85))
				else:
					img.set_pixel(x, y, Color(0.06, 0.09, 0.14, 0.90))

	var copy_img: Image = src_img.duplicate()
	copy_img.convert(Image.FORMAT_RGBA8)
	var sw: int = copy_img.get_width()
	var sh: int = copy_img.get_height()
	var inner_max: float = float(icon_size - 4)
	var sc: float = inner_max / float(maxi(1, maxi(sw, sh)))
	var nw: int = maxi(1, int(round(float(sw) * sc)))
	var nh: int = maxi(1, int(round(float(sh) * sc)))
	copy_img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	var ox: int = (icon_size - nw) / 2
	var oy: int = (icon_size - nh) / 2
	img.blend_rect(copy_img, Rect2i(0, 0, nw, nh), Vector2i(ox, oy))

	var out_tex := ImageTexture.create_from_image(img)
	_icon_cache[cache_key] = out_tex
	return out_tex
