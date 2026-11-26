extends RefCounted
class_name UIIcons

## Generates crisp 24x24 procedural icons and reusable button styles for the HUD.


static func make_button_style(bg: Color, border: Color, bottom_border: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = bottom_border
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 2
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func make_panel_style(bg: Color = Color(0.08, 0.11, 0.17, 0.96), border: Color = Color(0.26, 0.38, 0.56), radius: int = 6, pad_x: float = 8.0, pad_y: float = 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 4
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func style_progress_bar(bar: ProgressBar, fill_col: Color, border_col: Color = Color(0.32, 0.46, 0.68)) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.11, 0.95)
	bg.border_color = border_col
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.border_color = fill_col.lightened(0.35)
	fg.set_border_width_all(1)
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


static func apply_right_button_theme(btn: Button, accent: Color = Color(0.36, 0.56, 0.82), armed: bool = false) -> void:
	var normal_bg := Color(0.16, 0.27, 0.40) if armed else Color(0.12, 0.17, 0.25)
	var normal_border := Color(0.40, 0.95, 1.0) if armed else accent
	btn.add_theme_stylebox_override("normal", make_button_style(normal_bg, normal_border, 3))
	btn.add_theme_stylebox_override("hover", make_button_style(Color(0.19, 0.28, 0.42), normal_border.lightened(0.30), 3))
	btn.add_theme_stylebox_override("pressed", make_button_style(Color(0.09, 0.13, 0.19), normal_border, 1))
	btn.add_theme_stylebox_override("focus", make_button_style(normal_bg, normal_border.lightened(0.22), 3))
	btn.add_theme_stylebox_override("disabled", make_button_style(Color(0.09, 0.11, 0.15), Color(0.25, 0.22, 0.27), 2))
	btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.68, 0.56, 0.58))


static func create_icon(kind: String) -> ImageTexture:
	var sprite_badge: ImageTexture = SpriteLibrary.get_ui_badge_icon(kind, 28)
	if sprite_badge != null:
		return sprite_badge
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Dark badge plate behind every icon for high contrast
	_fill_circle(img, 12, 12, 11, Color(0.07, 0.10, 0.15, 0.85))
	_draw_ring(img, 12, 12, 11, Color(0.24, 0.34, 0.48, 0.75))

	match kind:
		"blaster":
			_fill_circle(img, 10, 12, 7, Color(0.18, 0.45, 0.82))
			_draw_ring(img, 10, 12, 7, Color(0.55, 0.85, 1.0))
			_fill_rect(img, 11, 7, 22, 10, Color(0.75, 0.95, 1.0))
			_fill_rect(img, 11, 14, 22, 17, Color(0.75, 0.95, 1.0))
			_fill_circle(img, 10, 12, 3, Color(0.45, 0.92, 1.0))
		"mortar":
			_fill_rect(img, 4, 13, 18, 20, Color(0.20, 0.58, 0.38))
			_stroke_rect(img, 4, 13, 18, 20, Color(0.58, 0.95, 0.72))
			_fill_circle(img, 11, 13, 5, Color(0.14, 0.36, 0.24))
			_fill_rect(img, 10, 5, 16, 13, Color(0.32, 0.78, 0.52))
			_fill_circle(img, 18, 5, 3, Color(1.0, 0.78, 0.28))
			_fill_circle(img, 18, 5, 1, Color(1.0, 0.98, 0.85))
		"laser":
			_fill_rect(img, 5, 15, 17, 20, Color(0.55, 0.18, 0.52))
			_fill_triangle_up(img, 11, 4, 11, Color(0.92, 0.32, 0.85))
			_fill_triangle_up(img, 11, 7, 7, Color(1.0, 0.72, 0.96))
			_fill_rect(img, 13, 6, 22, 8, Color(0.55, 0.96, 1.0))
			_fill_circle(img, 11, 7, 2, Color.WHITE)
		"slow":
			_fill_circle(img, 12, 12, 8, Color(0.12, 0.48, 0.62))
			_draw_ring(img, 12, 12, 8, Color(0.48, 0.95, 1.0))
			_draw_ring(img, 12, 12, 5, Color(0.75, 0.55, 1.0))
			_fill_rect(img, 11, 6, 13, 13, Color(0.95, 0.98, 1.0))
			_fill_rect(img, 12, 11, 17, 13, Color(0.95, 0.98, 1.0))
		"railgun":
			_fill_rect(img, 3, 8, 11, 16, Color(0.45, 0.22, 0.78))
			_stroke_rect(img, 3, 8, 11, 16, Color(0.85, 0.68, 1.0))
			_fill_rect(img, 10, 9, 22, 11, Color(0.88, 0.52, 1.0))
			_fill_rect(img, 10, 13, 22, 15, Color(0.88, 0.52, 1.0))
			_fill_rect(img, 11, 11, 23, 13, Color(1.0, 0.92, 0.55))
		"annihilator":
			_fill_rect(img, 3, 6, 13, 18, Color(0.78, 0.32, 0.16))
			_stroke_rect(img, 3, 6, 13, 18, Color(1.0, 0.82, 0.35))
			_fill_rect(img, 11, 8, 22, 16, Color(0.32, 0.24, 0.18))
			_fill_rect(img, 11, 8, 23, 10, Color(1.0, 0.84, 0.28))
			_fill_rect(img, 11, 14, 23, 16, Color(1.0, 0.84, 0.28))
			_fill_circle(img, 8, 12, 3, Color(1.0, 0.92, 0.45))
		"target":
			_draw_ring(img, 12, 12, 8, Color(0.98, 0.86, 0.38))
			_draw_ring(img, 12, 12, 4, Color(0.98, 0.86, 0.38))
			_fill_rect(img, 11, 2, 13, 7, Color(0.98, 0.86, 0.38))
			_fill_rect(img, 11, 17, 13, 22, Color(0.98, 0.86, 0.38))
			_fill_rect(img, 2, 11, 7, 13, Color(0.98, 0.86, 0.38))
			_fill_rect(img, 17, 11, 22, 13, Color(0.98, 0.86, 0.38))
		"damage", "reinforced_shots":
			_fill_rect(img, 10, 8, 14, 19, Color(0.95, 0.38, 0.28))
			_fill_triangle_up(img, 12, 3, 8, Color(1.0, 0.72, 0.32))
			_fill_circle(img, 12, 11, 2, Color(1.0, 0.95, 0.75))
		"range", "extended_optics":
			_draw_ring(img, 12, 12, 8, Color(0.38, 0.88, 1.0))
			_draw_ring(img, 12, 12, 5, Color(0.55, 0.94, 1.0))
			_fill_circle(img, 12, 12, 2, Color(0.92, 0.99, 1.0))
		"fire_rate", "rapid_cycling":
			_fill_rect(img, 5, 6, 15, 9, Color(1.0, 0.86, 0.28))
			_fill_rect(img, 8, 11, 19, 14, Color(1.0, 0.92, 0.48))
			_fill_rect(img, 5, 16, 15, 19, Color(1.0, 0.86, 0.28))
		"sell":
			_fill_circle(img, 12, 12, 8, Color(0.92, 0.74, 0.20))
			_draw_ring(img, 12, 12, 8, Color(1.0, 0.95, 0.65))
			_fill_rect(img, 11, 6, 13, 18, Color(0.32, 0.20, 0.04))
			_fill_rect(img, 9, 8, 15, 10, Color(0.32, 0.20, 0.04))
			_fill_rect(img, 9, 14, 15, 16, Color(0.32, 0.20, 0.04))
		"manipulator", "efficient_manipulator":
			_draw_ring(img, 12, 12, 8, Color(0.75, 0.55, 1.0))
			_fill_circle(img, 12, 12, 4, Color(0.42, 0.88, 1.0))
			_fill_rect(img, 11, 5, 13, 12, Color(0.95, 0.90, 1.0))
			_fill_rect(img, 12, 11, 18, 13, Color(0.95, 0.90, 1.0))
		"hive_breaker":
			_fill_rect(img, 3, 10, 19, 14, Color(0.38, 0.92, 1.0))
			_fill_circle(img, 17, 12, 5, Color(1.0, 0.72, 0.25))
			_fill_circle(img, 17, 12, 2, Color.WHITE)
		_:
			_fill_rect(img, 6, 6, 18, 18, Color(0.55, 0.75, 0.95))

	return ImageTexture.create_from_image(img)


static func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	for y in range(maxi(0, y0), mini(24, y1)):
		for x in range(maxi(0, x0), mini(24, x1)):
			img.set_pixel(x, y, col)


static func _stroke_rect(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	for x in range(maxi(0, x0), mini(24, x1)):
		if y0 >= 0 and y0 < 24:
			img.set_pixel(x, y0, col)
		if y1 - 1 >= 0 and y1 - 1 < 24:
			img.set_pixel(x, y1 - 1, col)
	for y in range(maxi(0, y0), mini(24, y1)):
		if x0 >= 0 and x0 < 24:
			img.set_pixel(x0, y, col)
		if x1 - 1 >= 0 and x1 - 1 < 24:
			img.set_pixel(x1 - 1, y, col)


static func _fill_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for y in range(maxi(0, cy - r), mini(24, cy + r + 1)):
		for x in range(maxi(0, cx - r), mini(24, cx + r + 1)):
			var dx: int = x - cx
			var dy: int = y - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, col)


static func _draw_ring(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for y in range(maxi(0, cy - r - 1), mini(24, cy + r + 2)):
		for x in range(maxi(0, cx - r - 1), mini(24, cx + r + 2)):
			var d: float = sqrt(float((x - cx) * (x - cx) + (y - cy) * (y - cy)))
			if absf(d - float(r)) <= 1.1:
				img.set_pixel(x, y, col)


static func _fill_triangle_up(img: Image, tip_x: int, tip_y: int, height: int, col: Color) -> void:
	for dy in range(height):
		var y: int = tip_y + dy
		for x in range(tip_x - dy, tip_x + dy + 1):
			if x >= 0 and x < 24 and y >= 0 and y < 24:
				img.set_pixel(x, y, col)
