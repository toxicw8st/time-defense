extends Control
class_name GuidePortrait

## Procedurally drawn full-bust animated character renderer for Chrono-Commander Vex.
## Designed to render large (~1/4 of viewport) directly over the full-screen GuideOverlay
## without a boxy frame so Vex dramatically interposes over the battlefield.

var anim_time: float = 0.0
var talk_timer: float = 0.0
var mood: String = "smirk" # "smirk" | "excited" | "alert" | "proud"


func _ready() -> void:
	custom_minimum_size = Vector2(320, 380)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func trigger_talk(p_mood: String = "smirk", duration: float = 3.2) -> void:
	mood = p_mood
	talk_timer = duration
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	anim_time += delta
	if talk_timer > 0.0:
		talk_timer = maxf(0.0, talk_timer - delta)
	queue_redraw()


func _get_accent_color() -> Color:
	match mood:
		"alert":
			return Color(1.0, 0.42, 0.28, 0.96)
		"proud":
			return Color(0.32, 0.98, 0.72, 0.96)
		"excited":
			return Color(0.38, 0.95, 1.0, 0.98)
		_:
			return Color(0.28, 0.88, 1.0, 0.95)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 48.0 or h < 48.0:
		return

	# Normalized unit scale (designed on a 320x380 logical canvas, scales crisply to 1/4 screen on any viewport)
	var s: float = minf(w / 320.0, h / 380.0)
	var cx: float = w * 0.50
	var base_y: float = h - 6.0 * s
	var bob: float = sin(anim_time * 2.8) * 5.0 * s
	var breathe: float = sin(anim_time * 2.8 - 0.6) * 2.4 * s
	var accent: Color = _get_accent_color()
	var gold := Color(1.0, 0.84, 0.34, 0.95)
	var head_c := Vector2(cx - 4.0 * s, base_y - 246.0 * s + bob)
	var torso_top_y: float = base_y - 168.0 * s + breathe

	# 1) Spinning holographic Chrono-Clock Halo floating behind Vex
	var halo_c := Vector2(cx - 2.0 * s, head_c.y + 22.0 * s)
	var halo_r: float = 118.0 * s
	draw_circle(halo_c, halo_r * 1.08, Color(accent.r, accent.g, accent.b, 0.08))
	draw_arc(halo_c, halo_r, 0.0, TAU, 48, Color(accent.r, accent.g, accent.b, 0.38), 3.0 * s)
	draw_arc(halo_c, halo_r * 0.82, anim_time * 0.6, anim_time * 0.6 + PI * 1.45, 36, Color(gold.r, gold.g, gold.b, 0.32), 2.4 * s)
	for i in range(12):
		var ang: float = (TAU * float(i) / 12.0) + anim_time * 0.14
		var p_in: Vector2 = halo_c + Vector2(cos(ang), sin(ang)) * (halo_r * 0.88)
		var p_out: Vector2 = halo_c + Vector2(cos(ang), sin(ang)) * (halo_r * 1.01)
		draw_line(p_in, p_out, Color(accent.r, accent.g, accent.b, 0.55), 2.4 * s if (i % 3 == 0) else 1.4 * s)
	# Sweeping holographic clock hands behind shoulders
	var hand_a: float = anim_time * 0.9
	var hand_b: float = -anim_time * 0.25
	draw_line(halo_c, halo_c + Vector2(cos(hand_a), sin(hand_a)) * (halo_r * 0.72), Color(accent.r, accent.g, accent.b, 0.35), 2.6 * s)
	draw_line(halo_c, halo_c + Vector2(cos(hand_b), sin(hand_b)) * (halo_r * 0.50), Color(gold.r, gold.g, gold.b, 0.38), 3.2 * s)

	# 2) Holographic emitter glow beam at base
	var beam_pts := PackedVector2Array([
		Vector2(cx - 122.0 * s, base_y),
		Vector2(cx - 98.0 * s, base_y - 38.0 * s),
		Vector2(cx + 98.0 * s, base_y - 38.0 * s),
		Vector2(cx + 122.0 * s, base_y),
	])
	draw_colored_polygon(beam_pts, Color(accent.r, accent.g, accent.b, 0.16))
	draw_line(Vector2(cx - 128.0 * s, base_y), Vector2(cx + 128.0 * s, base_y), accent, 3.0 * s)

	# 2b) High-res custom Chrono-Commander Vex portrait sprite (falls back to procedural vector art if absent)
	var vex_tex: Texture2D = SpriteLibrary.get_character_texture("vex")
	if vex_tex != null:
		var tw: float = maxf(1.0, float(vex_tex.get_width()))
		var th: float = maxf(1.0, float(vex_tex.get_height()))
		var fit_s: float = minf((w * 0.98) / tw, (h * 0.95) / th)
		var talk_bounce: float = absf(sin(anim_time * 13.0)) * 3.8 * s if talk_timer > 0.0 else 0.0
		var breath_scale: float = 1.0 + sin(anim_time * 3.2) * 0.012 + (0.016 if talk_timer > 0.0 else 0.0)
		var dw: float = tw * fit_s * breath_scale
		var dh: float = th * fit_s * breath_scale
		var dst_pos := Vector2(cx - dw * 0.5, base_y - dh + bob * 0.65 - talk_bounce)
		var mod_tint := Color.WHITE
		if mood == "alert":
			mod_tint = Color(1.04, 0.95, 0.93, 1.0)
		elif talk_timer > 0.0:
			var glow_p: float = 1.0 + 0.05 * absf(sin(anim_time * 11.0))
			mod_tint = Color(glow_p, glow_p, glow_p, 1.0)
		draw_texture_rect(vex_tex, Rect2(dst_pos, Vector2(dw, dh)), false, mod_tint)
		# Subtle holographic transmission scanlines across Vex
		var scan_step_s: int = maxi(6, int(round(9.0 * s)))
		var scan_off_s: int = int(fmod(anim_time * 24.0, float(scan_step_s)))
		for sy in range(scan_off_s, int(h), scan_step_s):
			draw_line(Vector2(dst_pos.x + dw * 0.08, float(sy)), Vector2(dst_pos.x + dw * 0.92, float(sy)), Color(accent.r, accent.g, accent.b, 0.045), 1.0)
		# Live comms waveform bar under Vex when speaking
		if talk_timer > 0.0:
			for bar_i in range(9):
				var bx: float = cx - 48.0 * s + float(bar_i) * 12.0 * s
				var bh: float = (4.0 + 10.0 * absf(sin(anim_time * 16.0 + float(bar_i) * 0.9))) * s
				draw_rect(Rect2(Vector2(bx, base_y - bh - 4.0 * s), Vector2(6.0 * s, bh)), Color(accent.r, accent.g, accent.b, 0.82))
		return

	# 3) Armored Chrono-Command Jacket / Torso & Broad Pauldrons
	var coat_pts := PackedVector2Array([
		Vector2(cx - 126.0 * s, base_y),
		Vector2(cx - 116.0 * s, torso_top_y + 42.0 * s),
		Vector2(cx - 92.0 * s, torso_top_y + 2.0 * s),
		Vector2(cx - 40.0 * s, torso_top_y - 12.0 * s),
		Vector2(cx + 38.0 * s, torso_top_y - 12.0 * s),
		Vector2(cx + 94.0 * s, torso_top_y + 4.0 * s),
		Vector2(cx + 116.0 * s, torso_top_y + 46.0 * s),
		Vector2(cx + 124.0 * s, base_y),
	])
	draw_colored_polygon(coat_pts, Color(0.10, 0.19, 0.33, 0.98))
	draw_polyline(coat_pts, Color(accent.r, accent.g, accent.b, 0.78), 2.8 * s)

	# Armored left & right shoulder pauldrons with brass commander stripes
	var left_pad := PackedVector2Array([
		Vector2(cx - 122.0 * s, torso_top_y + 46.0 * s),
		Vector2(cx - 102.0 * s, torso_top_y - 4.0 * s),
		Vector2(cx - 46.0 * s, torso_top_y - 14.0 * s),
		Vector2(cx - 56.0 * s, torso_top_y + 38.0 * s),
	])
	var right_pad := PackedVector2Array([
		Vector2(cx + 120.0 * s, torso_top_y + 46.0 * s),
		Vector2(cx + 100.0 * s, torso_top_y - 4.0 * s),
		Vector2(cx + 44.0 * s, torso_top_y - 14.0 * s),
		Vector2(cx + 54.0 * s, torso_top_y + 38.0 * s),
	])
	draw_colored_polygon(left_pad, Color(0.16, 0.30, 0.50))
	draw_colored_polygon(right_pad, Color(0.16, 0.30, 0.50))
	draw_polyline(left_pad, accent, 2.4 * s)
	draw_polyline(right_pad, accent, 2.4 * s)
	# Gold rank chevrons on left shoulder
	for k in range(3):
		var ox: float = float(k) * 8.0 * s
		draw_line(
			Vector2(cx - 98.0 * s + ox, torso_top_y + 16.0 * s),
			Vector2(cx - 88.0 * s + ox, torso_top_y + 6.0 * s),
			gold,
			3.0 * s
		)

	# High raised Chrono-Tactician collar + glowing V-lapels + Chest Core
	var collar_pts := PackedVector2Array([
		Vector2(cx - 50.0 * s, torso_top_y - 22.0 * s),
		Vector2(cx - 34.0 * s, torso_top_y + 44.0 * s),
		Vector2(cx, torso_top_y + 72.0 * s),
		Vector2(cx + 34.0 * s, torso_top_y + 44.0 * s),
		Vector2(cx + 48.0 * s, torso_top_y - 22.0 * s),
		Vector2(cx + 26.0 * s, torso_top_y - 10.0 * s),
		Vector2(cx, torso_top_y + 30.0 * s),
		Vector2(cx - 26.0 * s, torso_top_y - 10.0 * s),
	])
	draw_colored_polygon(collar_pts, Color(0.06, 0.12, 0.22))
	draw_line(Vector2(cx - 46.0 * s, torso_top_y - 16.0 * s), Vector2(cx, torso_top_y + 68.0 * s), accent, 3.6 * s)
	draw_line(Vector2(cx + 44.0 * s, torso_top_y - 16.0 * s), Vector2(cx, torso_top_y + 68.0 * s), accent, 3.6 * s)

	# Glowing chest Chrono-Core medallion
	var core_c := Vector2(cx, torso_top_y + 92.0 * s)
	var core_pulse: float = 0.72 + 0.28 * sin(anim_time * 5.2)
	draw_circle(core_c, 22.0 * s, Color(accent.r, accent.g, accent.b, 0.22 * core_pulse))
	draw_circle(core_c, 13.0 * s, Color(0.07, 0.16, 0.28))
	draw_arc(core_c, 13.0 * s, 0.0, TAU, 24, accent, 2.8 * s)
	draw_circle(core_c, 6.0 * s, Color(accent.r, accent.g, accent.b, core_pulse))

	# Tactical diagonal strap across torso
	draw_line(
		Vector2(cx - 72.0 * s, torso_top_y + 18.0 * s),
		Vector2(cx + 58.0 * s, base_y - 12.0 * s),
		Color(0.24, 0.36, 0.54, 0.90),
		12.0 * s
	)
	draw_line(
		Vector2(cx - 72.0 * s, torso_top_y + 18.0 * s),
		Vector2(cx + 58.0 * s, base_y - 12.0 * s),
		Color(gold.r, gold.g, gold.b, 0.65),
		2.0 * s
	)

	# 4) Animated Gesturing Chrono-Gauntlet on right side (points toward speech box!)
	var gest: float = sin(anim_time * 7.5) * 6.0 * s if talk_timer > 0.0 else sin(anim_time * 2.2) * 2.0 * s
	var wrist_c := Vector2(cx + 96.0 * s, torso_top_y + 98.0 * s + gest)
	var arm_pts := PackedVector2Array([
		Vector2(cx + 76.0 * s, torso_top_y + 52.0 * s),
		Vector2(cx + 114.0 * s, torso_top_y + 56.0 * s),
		Vector2(wrist_c.x + 22.0 * s, wrist_c.y + 16.0 * s),
		Vector2(wrist_c.x - 16.0 * s, wrist_c.y + 12.0 * s),
	])
	draw_colored_polygon(arm_pts, Color(0.14, 0.26, 0.44))
	draw_polyline(arm_pts, accent, 2.0 * s)
	# Glowing wrist chronometer holo-ring
	var holo_r: float = (18.0 + (4.0 if talk_timer > 0.0 else 0.0) * absf(sin(anim_time * 10.0))) * s
	draw_circle(wrist_c, holo_r * 0.72, Color(accent.r, accent.g, accent.b, 0.25))
	draw_arc(wrist_c, holo_r, anim_time * 2.0, anim_time * 2.0 + PI * 1.6, 20, gold, 2.4 * s)

	# 5) Neck & Stylized Head / Jaw
	draw_rect(Rect2(head_c.x - 18.0 * s, head_c.y + 44.0 * s, 36.0 * s, 40.0 * s), Color(0.80, 0.63, 0.50), true)
	# Subtle shadow under chin
	draw_circle(Vector2(head_c.x, head_c.y + 52.0 * s), 19.0 * s, Color(0.68, 0.52, 0.40, 0.65))
	# Head shape (cranium + strong stylized jawline)
	draw_circle(Vector2(head_c.x, head_c.y - 4.0 * s), 54.0 * s, Color(0.93, 0.77, 0.64))
	var jaw_pts := PackedVector2Array([
		Vector2(head_c.x - 50.0 * s, head_c.y + 6.0 * s),
		Vector2(head_c.x - 38.0 * s, head_c.y + 44.0 * s),
		Vector2(head_c.x, head_c.y + 58.0 * s),
		Vector2(head_c.x + 38.0 * s, head_c.y + 44.0 * s),
		Vector2(head_c.x + 50.0 * s, head_c.y + 6.0 * s),
	])
	draw_colored_polygon(jaw_pts, Color(0.93, 0.77, 0.64))

	# 6) Comms Headset + Pulsing Antenna Beacon + Mic Boom
	var ear_r := Vector2(head_c.x + 54.0 * s, head_c.y + 2.0 * s)
	draw_rect(Rect2(ear_r.x - 8.0 * s, ear_r.y - 18.0 * s, 18.0 * s, 36.0 * s), Color(0.18, 0.30, 0.48), true)
	draw_rect(Rect2(ear_r.x - 8.0 * s, ear_r.y - 18.0 * s, 18.0 * s, 36.0 * s), accent, false, 2.2 * s)
	var ant_tip := Vector2(head_c.x + 74.0 * s, head_c.y - 68.0 * s)
	draw_line(Vector2(ear_r.x + 3.0 * s, ear_r.y - 16.0 * s), ant_tip, Color(0.70, 0.86, 1.0), 3.6 * s)
	var beacon_p: float = 0.55 + 0.45 * sin(anim_time * 8.0)
	draw_circle(ant_tip, 11.0 * s, Color(accent.r, accent.g, accent.b, 0.28 * beacon_p))
	draw_circle(ant_tip, 6.2 * s, Color(accent.r, accent.g, accent.b, beacon_p))
	# Boom mic curving to cheek
	draw_line(Vector2(ear_r.x - 2.0 * s, ear_r.y + 14.0 * s), Vector2(head_c.x + 28.0 * s, head_c.y + 30.0 * s), Color(0.24, 0.34, 0.48), 3.2 * s)
	draw_circle(Vector2(head_c.x + 26.0 * s, head_c.y + 30.0 * s), 4.2 * s, accent)

	# 7) Spiky Silver-Cyan Commander Hair with luminous streaks
	var hair_pts := PackedVector2Array([
		Vector2(head_c.x - 56.0 * s, head_c.y - 8.0 * s),
		Vector2(head_c.x - 62.0 * s, head_c.y - 44.0 * s),
		Vector2(head_c.x - 42.0 * s, head_c.y - 74.0 * s),
		Vector2(head_c.x - 18.0 * s, head_c.y - 62.0 * s),
		Vector2(head_c.x - 4.0 * s, head_c.y - 90.0 * s),
		Vector2(head_c.x + 18.0 * s, head_c.y - 66.0 * s),
		Vector2(head_c.x + 42.0 * s, head_c.y - 82.0 * s),
		Vector2(head_c.x + 56.0 * s, head_c.y - 48.0 * s),
		Vector2(head_c.x + 58.0 * s, head_c.y - 10.0 * s),
		Vector2(head_c.x + 36.0 * s, head_c.y - 34.0 * s),
		Vector2(head_c.x + 8.0 * s, head_c.y - 28.0 * s),
		Vector2(head_c.x - 22.0 * s, head_c.y - 36.0 * s),
		Vector2(head_c.x - 44.0 * s, head_c.y - 26.0 * s),
	])
	draw_colored_polygon(hair_pts, Color(0.20, 0.33, 0.52))
	draw_polyline(hair_pts, Color(0.62, 0.94, 1.0, 0.80), 2.4 * s)
	# Hair shine highlights
	draw_line(Vector2(head_c.x - 36.0 * s, head_c.y - 60.0 * s), Vector2(head_c.x - 14.0 * s, head_c.y - 44.0 * s), Color(0.80, 0.97, 1.0, 0.55), 3.0 * s)
	draw_line(Vector2(head_c.x + 4.0 * s, head_c.y - 74.0 * s), Vector2(head_c.x + 24.0 * s, head_c.y - 50.0 * s), Color(0.80, 0.97, 1.0, 0.55), 3.0 * s)

	# 8) Expressive Mood-Reactive Eyebrows + Glowing Chrono-Visor
	var brow_tilt: float = 6.0 * s if mood == "alert" else (-5.0 * s if mood == "excited" else -2.0 * s)
	draw_line(Vector2(head_c.x - 36.0 * s, head_c.y - 26.0 * s - brow_tilt * 0.4), Vector2(head_c.x - 10.0 * s, head_c.y - 26.0 * s + brow_tilt), Color(0.16, 0.26, 0.42), 4.6 * s)
	draw_line(Vector2(head_c.x + 10.0 * s, head_c.y - 26.0 * s + brow_tilt), Vector2(head_c.x + 36.0 * s, head_c.y - 26.0 * s - brow_tilt * 0.4), Color(0.16, 0.26, 0.42), 4.6 * s)

	var visor_pts := PackedVector2Array([
		Vector2(head_c.x - 48.0 * s, head_c.y - 18.0 * s),
		Vector2(head_c.x + 48.0 * s, head_c.y - 18.0 * s),
		Vector2(head_c.x + 44.0 * s, head_c.y + 8.0 * s),
		Vector2(head_c.x + 10.0 * s, head_c.y + 12.0 * s),
		Vector2(head_c.x, head_c.y + 6.0 * s),
		Vector2(head_c.x - 10.0 * s, head_c.y + 12.0 * s),
		Vector2(head_c.x - 44.0 * s, head_c.y + 8.0 * s),
	])
	draw_colored_polygon(visor_pts, Color(0.05, 0.13, 0.24, 0.94))
	draw_polyline(visor_pts, accent, 3.2 * s)

	# Animated glowing eyes inside visor (occasional blink)
	var blink: bool = fmod(anim_time, 4.1) > 3.96
	var eye_y: float = head_c.y - 4.0 * s
	if blink:
		draw_line(Vector2(head_c.x - 30.0 * s, eye_y), Vector2(head_c.x - 12.0 * s, eye_y), accent, 3.2 * s)
		draw_line(Vector2(head_c.x + 12.0 * s, eye_y), Vector2(head_c.x + 30.0 * s, eye_y), accent, 3.2 * s)
	else:
		draw_circle(Vector2(head_c.x - 21.0 * s, eye_y), 7.2 * s, Color(accent.r, accent.g, accent.b, 0.35))
		draw_circle(Vector2(head_c.x - 21.0 * s, eye_y), 4.2 * s, accent)
		draw_circle(Vector2(head_c.x + 21.0 * s, eye_y), 7.2 * s, Color(accent.r, accent.g, accent.b, 0.35))
		draw_circle(Vector2(head_c.x + 21.0 * s, eye_y), 4.2 * s, accent)
	# Diagonal glass sheen across visor
	draw_line(Vector2(head_c.x - 36.0 * s, head_c.y - 14.0 * s), Vector2(head_c.x - 16.0 * s, head_c.y + 6.0 * s), Color(1, 1, 1, 0.34), 4.2 * s)
	draw_line(Vector2(head_c.x - 22.0 * s, head_c.y - 14.0 * s), Vector2(head_c.x - 8.0 * s, head_c.y + 2.0 * s), Color(1, 1, 1, 0.22), 2.2 * s)

	# 9) Subtle Nose & Expressive Talking / Witty Smirking Mouth
	draw_line(Vector2(head_c.x, head_c.y + 12.0 * s), Vector2(head_c.x - 3.0 * s, head_c.y + 21.0 * s), Color(0.72, 0.54, 0.42), 2.2 * s)
	var mouth_y: float = head_c.y + 33.0 * s
	if talk_timer > 0.0:
		var open_h: float = (5.0 + absf(sin(anim_time * 17.5)) * 12.0) * s
		draw_rect(Rect2(head_c.x - 17.0 * s, mouth_y - open_h * 0.5, 34.0 * s, open_h), Color(0.28, 0.09, 0.14), true)
		draw_rect(Rect2(head_c.x - 15.0 * s, mouth_y - open_h * 0.5, 30.0 * s, minf(4.0 * s, open_h * 0.45)), Color(0.98, 0.98, 1.0), true)
		draw_rect(Rect2(head_c.x - 17.0 * s, mouth_y - open_h * 0.5, 34.0 * s, open_h), Color(0.55, 0.25, 0.24), false, 1.8 * s)
	elif mood == "alert":
		draw_arc(Vector2(head_c.x, mouth_y + 8.0 * s), 13.0 * s, PI * 1.15, PI * 1.85, 12, Color(0.32, 0.13, 0.12), 3.6 * s)
	elif mood == "excited" or mood == "proud":
		# Confident wide grin!
		var grin_pts := PackedVector2Array([
			Vector2(head_c.x - 18.0 * s, mouth_y - 1.0 * s),
			Vector2(head_c.x + 20.0 * s, mouth_y - 4.0 * s),
			Vector2(head_c.x + 12.0 * s, mouth_y + 9.0 * s),
			Vector2(head_c.x - 10.0 * s, mouth_y + 8.0 * s),
		])
		draw_colored_polygon(grin_pts, Color(0.98, 0.98, 1.0))
		draw_polyline(grin_pts, Color(0.32, 0.14, 0.14), 2.4 * s)
	else:
		# Classic witty crooked commander smirk!
		draw_line(Vector2(head_c.x - 16.0 * s, mouth_y + 2.0 * s), Vector2(head_c.x + 6.0 * s, mouth_y + 3.0 * s), Color(0.32, 0.15, 0.14), 3.6 * s)
		draw_line(Vector2(head_c.x + 6.0 * s, mouth_y + 3.0 * s), Vector2(head_c.x + 22.0 * s, mouth_y - 7.0 * s), Color(0.32, 0.15, 0.14), 3.6 * s)

	# 10) Faint holographic scanlines across Vex so he reads as a crisp chrono-transmission
	var scan_step: int = maxi(6, int(round(9.0 * s)))
	var scan_off: int = int(fmod(anim_time * 24.0, float(scan_step)))
	for sy in range(scan_off, int(h), scan_step):
		draw_line(Vector2(cx - 122.0 * s, float(sy)), Vector2(cx + 122.0 * s, float(sy)), Color(accent.r, accent.g, accent.b, 0.045), 1.0)
