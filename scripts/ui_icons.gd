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
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func apply_right_button_theme(btn: Button, accent: Color = Color(0.36, 0.56, 0.82), armed: bool = false) -> void:
	var normal_bg := Color(0.15, 0.25, 0.36) if armed else Color(0.14, 0.19, 0.27)
	var normal_border := Color(0.35, 0.92, 1.0) if armed else accent
	btn.add_theme_stylebox_override("normal", make_button_style(normal_bg, normal_border, 3))
	btn.add_theme_stylebox_override("hover", make_button_style(Color(0.20, 0.29, 0.42), normal_border.lightened(0.28), 3))
	btn.add_theme_stylebox_override("pressed", make_button_style(Color(0.10, 0.14, 0.20), normal_border, 1))
	btn.add_theme_stylebox_override("focus", make_button_style(normal_bg, normal_border.lightened(0.2), 3))
	btn.add_theme_stylebox_override("disabled", make_button_style(Color(0.11, 0.13, 0.17), Color(0.28, 0.24, 0.28), 2))
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.58, 0.60))


static func create_icon(kind: String) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match kind:
		"blaster":
			_fill_rect(img, 3, 5, 13, 19, Color(0.22, 0.58, 0.95))
			_stroke_rect(img, 3, 5, 13, 19, Color(0.72, 0.92, 1.0))
			_fill_rect(img, 12, 8, 22, 11, Color(0.65, 0.92, 1.0))
			_fill_rect(img, 12, 13, 22, 16, Color(0.65, 0.92, 1.0))
		"mortar":
			_fill_rect(img, 3, 7, 18, 21, Color(0.25, 0.72, 0.48))
			_stroke_rect(img, 3, 7, 18, 21, Color(0.68, 0.96, 0.78))
			_fill_circle(img, 12, 12, 5, Color(0.14, 0.32, 0.24))
			_fill_circle(img, 17, 6, 3, Color(1.0, 0.75, 0.28))
			_fill_circle(img, 20, 9, 2, Color(1.0, 0.52, 0.22))
		"damage", "reinforced_shots":
			_fill_rect(img, 10, 6, 14, 20, Color(0.96, 0.42, 0.32))
			_fill_triangle_up(img, 12, 3, 8, Color(1.0, 0.68, 0.35))
		"range", "extended_optics":
			_draw_ring(img, 12, 12, 9, Color(0.38, 0.88, 1.0))
			_draw_ring(img, 12, 12, 5, Color(0.38, 0.88, 1.0))
			_fill_circle(img, 12, 12, 2, Color(0.85, 0.98, 1.0))
		"fire_rate", "rapid_cycling":
			_fill_rect(img, 4, 6, 15, 9, Color(1.0, 0.86, 0.28))
			_fill_rect(img, 7, 11, 19, 14, Color(1.0, 0.86, 0.28))
			_fill_rect(img, 4, 16, 15, 19, Color(1.0, 0.86, 0.28))
		"sell":
			_fill_circle(img, 12, 12, 9, Color(0.95, 0.78, 0.22))
			_draw_ring(img, 12, 12, 9, Color(1.0, 0.95, 0.65))
			_fill_rect(img, 11, 6, 13, 18, Color(0.38, 0.24, 0.05))
		"manipulator", "efficient_manipulator":
			_draw_ring(img, 12, 12, 9, Color(0.72, 0.55, 1.0))
			_fill_circle(img, 12, 12, 4, Color(0.45, 0.88, 1.0))
			_fill_rect(img, 11, 4, 13, 12, Color(0.95, 0.88, 1.0))
			_fill_rect(img, 12, 11, 18, 13, Color(0.95, 0.88, 1.0))
		"hive_breaker":
			_fill_rect(img, 2, 10, 21, 14, Color(0.35, 0.92, 1.0))
			_fill_circle(img, 18, 12, 5, Color(1.0, 0.72, 0.25))
		_:
			_fill_rect(img, 5, 5, 19, 19, Color(0.55, 0.75, 0.95))

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
