extends Control
class_name GuidePortrait

## Procedurally drawn animated holographic portrait of Chrono-Commander Vex,
## the witty first-playthrough guide for TimeDefense.

var anim_time: float = 0.0
var talk_timer: float = 0.0
var mood: String = "smirk" # "smirk" | "excited" | "alert" | "proud"


func _ready() -> void:
	custom_minimum_size = Vector2(68, 68)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func trigger_talk(p_mood: String = "smirk", duration: float = 2.6) -> void:
	mood = p_mood
	talk_timer = duration
	queue_redraw()


func _process(delta: float) -> void:
	anim_time += delta
	if talk_timer > 0.0:
		talk_timer = maxf(0.0, talk_timer - delta)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 16.0 or h < 16.0:
		return
	var s: float = minf(w, h) / 68.0
	var cx: float = w * 0.5
	var cy: float = h * 0.5
	var bob: float = sin(anim_time * 3.2) * 1.4 * s

	# Holographic backdrop & subtle scanlines
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.11, 0.19, 0.96), true)
	for sy in range(2, int(h), maxi(4, int(round(5.0 * s)))):
		draw_line(Vector2(2, float(sy)), Vector2(w - 2, float(sy)), Color(0.28, 0.85, 1.0, 0.08), 1.0)
	draw_rect(Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3)), Color(0.35, 0.92, 1.0, 0.92), false, 2.0 * s)

	# Shoulders & Chrono-Tactician collar
	var sh_pts := PackedVector2Array([
		Vector2(cx - 26.0 * s, h - 1.0),
		Vector2(cx - 20.0 * s, cy + 16.0 * s + bob * 0.4),
		Vector2(cx + 20.0 * s, cy + 16.0 * s + bob * 0.4),
		Vector2(cx + 26.0 * s, h - 1.0),
	])
	draw_colored_polygon(sh_pts, Color(0.14, 0.28, 0.46))
	draw_line(Vector2(cx - 11.0 * s, cy + 17.0 * s + bob * 0.4), Vector2(cx, cy + 27.0 * s + bob * 0.4), Color(0.42, 0.96, 1.0), 2.2 * s)
	draw_line(Vector2(cx + 11.0 * s, cy + 17.0 * s + bob * 0.4), Vector2(cx, cy + 27.0 * s + bob * 0.4), Color(0.42, 0.96, 1.0), 2.2 * s)

	# Headset antenna with pulsing beacon
	var ant_base := Vector2(cx + 17.0 * s, cy - 2.0 * s + bob)
	var ant_tip := Vector2(cx + 22.0 * s, cy - 20.0 * s + bob)
	draw_line(ant_base, ant_tip, Color(0.65, 0.82, 0.96), 2.0 * s)
	var pulse: float = 0.55 + 0.45 * sin(anim_time * 7.0)
	var beacon_col := Color(1.0, 0.42, 0.35, pulse) if mood == "alert" else Color(0.35, 0.98, 1.0, pulse)
	draw_circle(ant_tip, 3.2 * s, beacon_col)

	# Neck & stylized face/head
	draw_rect(Rect2(cx - 5.0 * s, cy + 10.0 * s + bob, 10.0 * s, 9.0 * s), Color(0.84, 0.68, 0.56), true)
	draw_circle(Vector2(cx, cy - 2.0 * s + bob), 16.5 * s, Color(0.92, 0.76, 0.62))

	# Spiky retro-futuristic silver-cyan hair
	var hair_pts := PackedVector2Array([
		Vector2(cx - 17.0 * s, cy - 6.0 * s + bob),
		Vector2(cx - 15.0 * s, cy - 21.0 * s + bob),
		Vector2(cx - 6.0 * s, cy - 26.0 * s + bob),
		Vector2(cx + 2.0 * s, cy - 21.0 * s + bob),
		Vector2(cx + 10.0 * s, cy - 26.0 * s + bob),
		Vector2(cx + 17.0 * s, cy - 17.0 * s + bob),
		Vector2(cx + 17.5 * s, cy - 5.0 * s + bob),
		Vector2(cx + 10.0 * s, cy - 12.0 * s + bob),
		Vector2(cx - 10.0 * s, cy - 12.0 * s + bob),
	])
	draw_colored_polygon(hair_pts, Color(0.24, 0.36, 0.56))
	draw_polyline(hair_pts, Color(0.55, 0.92, 1.0, 0.65), 1.2 * s)

	# Glowing Chrono-Visor across eyes
	var visor_col := Color(1.0, 0.56, 0.25, 0.92) if mood == "alert" else (Color(0.35, 1.0, 0.72, 0.92) if mood == "proud" else Color(0.26, 0.92, 1.0, 0.92))
	var visor_rect := Rect2(cx - 14.5 * s, cy - 9.0 * s + bob, 29.0 * s, 8.5 * s)
	draw_rect(visor_rect, Color(0.06, 0.14, 0.24, 0.92), true)
	draw_rect(visor_rect, visor_col, false, 1.8 * s)
	# Animated eye-dots inside visor (blinks occasionally)
	var blink: bool = fmod(anim_time, 4.3) > 4.18
	if blink:
		draw_line(Vector2(cx - 9.0 * s, cy - 4.8 * s + bob), Vector2(cx - 3.5 * s, cy - 4.8 * s + bob), visor_col, 1.8 * s)
		draw_line(Vector2(cx + 3.5 * s, cy - 4.8 * s + bob), Vector2(cx + 9.0 * s, cy - 4.8 * s + bob), visor_col, 1.8 * s)
	else:
		draw_circle(Vector2(cx - 6.2 * s, cy - 4.8 * s + bob), 2.2 * s, visor_col)
		draw_circle(Vector2(cx + 6.2 * s, cy - 4.8 * s + bob), 2.2 * s, visor_col)
	# Visor shine streak
	draw_line(Vector2(cx - 11.0 * s, cy - 7.0 * s + bob), Vector2(cx - 4.0 * s, cy - 2.2 * s + bob), Color(1, 1, 1, 0.38), 1.4 * s)

	# Expressive witty mouth (animates when talking!)
	var mouth_y: float = cy + 6.5 * s + bob
	if talk_timer > 0.0:
		var open_h: float = (1.6 + absf(sin(anim_time * 18.0)) * 3.4) * s
		draw_rect(Rect2(cx - 5.5 * s, mouth_y - open_h * 0.5, 11.0 * s, open_h), Color(0.28, 0.10, 0.14), true)
		draw_line(Vector2(cx - 5.0 * s, mouth_y - open_h * 0.5), Vector2(cx + 5.0 * s, mouth_y - open_h * 0.5), Color(0.96, 0.96, 1.0), 1.2 * s)
	elif mood == "alert":
		draw_arc(Vector2(cx, mouth_y + 2.5 * s), 4.0 * s, PI * 1.15, PI * 1.85, 8, Color(0.32, 0.14, 0.12), 1.8 * s)
	else:
		# Classic witty crooked smirk!
		draw_line(Vector2(cx - 5.0 * s, mouth_y + 0.5 * s), Vector2(cx + 1.5 * s, mouth_y + 0.8 * s), Color(0.32, 0.16, 0.14), 1.8 * s)
		draw_line(Vector2(cx + 1.5 * s, mouth_y + 0.8 * s), Vector2(cx + 6.5 * s, mouth_y - 2.0 * s), Color(0.32, 0.16, 0.14), 1.8 * s)
