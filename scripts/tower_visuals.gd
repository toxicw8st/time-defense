extends RefCounted
class_name TowerVisuals

## Procedural bespoke top-down turret artwork for all 6 base towers + all 21 combined towers (27 unique designs).

static func get_accent_color(tower_type: String) -> Color:
	match tower_type:
		"blaster":
			return Color(0.28, 0.68, 1.0)
		"mortar":
			return Color(0.32, 0.85, 0.56)
		"laser":
			return Color(0.95, 0.36, 0.86)
		"slow":
			return Color(0.32, 0.92, 1.0)
		"railgun":
			return Color(0.75, 0.46, 1.0)
		"annihilator":
			return Color(1.0, 0.72, 0.24)
		"blaster+blaster":
			return Color(0.45, 0.86, 1.0)
		"mortar+mortar":
			return Color(0.42, 0.95, 0.58)
		"laser+laser":
			return Color(1.0, 0.45, 0.94)
		"slow+slow":
			return Color(0.42, 0.88, 1.0)
		"railgun+railgun":
			return Color(0.86, 0.55, 1.0)
		"annihilator+annihilator":
			return Color(1.0, 0.82, 0.28)
		"blaster+mortar":
			return Color(0.38, 0.85, 0.82)
		"blaster+laser":
			return Color(0.72, 0.62, 1.0)
		"blaster+slow":
			return Color(0.32, 0.84, 1.0)
		"blaster+railgun":
			return Color(0.58, 0.68, 1.0)
		"blaster+annihilator":
			return Color(0.86, 0.76, 0.45)
		"mortar+laser":
			return Color(0.95, 0.56, 0.68)
		"mortar+slow":
			return Color(0.30, 0.96, 0.82)
		"mortar+railgun":
			return Color(0.62, 0.78, 0.85)
		"mortar+annihilator":
			return Color(0.88, 0.68, 0.32)
		"laser+slow":
			return Color(0.68, 0.68, 1.0)
		"laser+railgun":
			return Color(0.92, 0.52, 1.0)
		"laser+annihilator":
			return Color(1.0, 0.55, 0.52)
		"slow+railgun":
			return Color(0.52, 0.82, 1.0)
		"slow+annihilator":
			return Color(0.78, 0.85, 0.65)
		"railgun+annihilator":
			return Color(0.98, 0.78, 0.52)
	return Color(0.48, 0.78, 1.0)


static func _draw_rot_poly(canvas: CanvasItem, pts: Array, ang: float, col: Color) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append((v as Vector2).rotated(ang))
	canvas.draw_colored_polygon(p, col)


static func draw_turret(
	canvas: CanvasItem,
	tower_type: String,
	aim_angle: float,
	recoil: float,
	anim_time: float,
	muzzle_flash_timer: float,
	levels: Dictionary
) -> void:
	var fwd: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)

	var tex: Texture2D = SpriteLibrary.get_tower_texture(tower_type)
	if tex != null:
		var meta: Dictionary = SpriteLibrary.get_tower_meta(tower_type)
		var is_combo: bool = Balance.is_combo_tower(tower_type)
		var ped_px: float = 39.0 if is_combo else 36.0
		var max_w: float = 70.0 if is_combo else 62.0
		var draw_size: Vector2 = SpriteLibrary.compute_tower_draw_size(tex, meta, ped_px, max_w)
		var pivot := Vector2(float(meta.get("pivot_x", 0.5)), float(meta.get("pivot_y", 0.5)))
		var is_radial: bool = bool(meta.get("radial", false))
		var draw_ang: float = (anim_time * 0.35) if is_radial else aim_angle
		var recoil_off: Vector2 = Vector2.ZERO if is_radial else (-fwd * (recoil * 0.85))
		SpriteLibrary.draw_sprite_oriented(canvas, tex, recoil_off, draw_ang, draw_size, pivot, Color.WHITE)
		if muzzle_flash_timer > 0.0:
			var accent: Color = get_accent_color(tower_type)
			var mf_a: float = clampf(muzzle_flash_timer / 0.14, 0.0, 1.0)
			if is_radial:
				canvas.draw_arc(Vector2.ZERO, 18.0 + (1.0 - mf_a) * 6.0, 0.0, TAU, 28, Color(accent.r, accent.g, accent.b, mf_a * 0.92), 2.5)
			else:
				var tip_dist: float = maxf(14.0, (1.0 - pivot.x) * draw_size.x - recoil * 0.5)
				var tip_pos: Vector2 = fwd * tip_dist
				canvas.draw_circle(tip_pos, 6.2 * mf_a + 1.8, Color(accent.r, accent.g, accent.b, mf_a * 0.85))
				canvas.draw_circle(tip_pos, 3.0 * mf_a + 0.8, Color(1.0, 0.98, 0.86, mf_a))
		return

	match tower_type:
		"blaster":
			# Twin-barrel armor-piercing autocannon
			var b1_s: Vector2 = fwd * (3.0 - recoil) + side * 4.2
			var b1_e: Vector2 = fwd * (18.5 - recoil) + side * 4.2
			var b2_s: Vector2 = fwd * (3.0 - recoil) - side * 4.2
			var b2_e: Vector2 = fwd * (18.5 - recoil) - side * 4.2
			canvas.draw_line(b1_s, b1_e, Color(0.22, 0.30, 0.42), 3.6)
			canvas.draw_line(b2_s, b2_e, Color(0.22, 0.30, 0.42), 3.6)
			canvas.draw_line(b1_s, b1_e, Color(0.65, 0.88, 1.0), 1.6)
			canvas.draw_line(b2_s, b2_e, Color(0.65, 0.88, 1.0), 1.6)
			_draw_rot_poly(canvas, [Vector2(-7, -6), Vector2(7, -5), Vector2(9, 0), Vector2(7, 5), Vector2(-7, 6)], aim_angle, Color(0.20, 0.52, 0.88))
			canvas.draw_circle(Vector2.ZERO, 4.5, Color(0.55, 0.92, 1.0))
			canvas.draw_circle(Vector2.ZERO, 2.2, Color.WHITE)
			if muzzle_flash_timer > 0.0:
				canvas.draw_circle(b1_e + fwd * 2.0, 3.8, Color(0.65, 0.96, 1.0, 0.9))
				canvas.draw_circle(b2_e + fwd * 2.0, 3.8, Color(0.65, 0.96, 1.0, 0.9))

		"mortar":
			# Heavy siege mortar with 4 hydraulic recoil struts & wide-bore tube
			for s_i in range(4):
				var sa: float = float(s_i) * PI * 0.5 + PI * 0.25
				var sv := Vector2(cos(sa), sin(sa))
				canvas.draw_line(sv * 7.0, sv * 14.0, Color(0.32, 0.42, 0.36), 3.0)
			canvas.draw_circle(Vector2.ZERO, 9.2, Color(0.20, 0.52, 0.36))
			canvas.draw_arc(Vector2.ZERO, 9.2, 0.0, TAU, 24, Color(0.45, 0.92, 0.65), 1.6)
			var tube_end: Vector2 = fwd * (13.5 - recoil * 0.8)
			canvas.draw_line(-fwd * 3.0, tube_end, Color(0.24, 0.34, 0.28), 9.0)
			canvas.draw_line(-fwd * 2.0, tube_end, Color(0.35, 0.76, 0.52), 6.2)
			canvas.draw_circle(tube_end, 4.2, Color(0.10, 0.14, 0.12))
			canvas.draw_circle(tube_end, 2.4, Color(1.0, 0.68, 0.24))
			if muzzle_flash_timer > 0.0:
				canvas.draw_circle(tube_end + fwd * 2.5, 6.5, Color(1.0, 0.78, 0.28, 0.88))
				canvas.draw_circle(tube_end + fwd * 2.5, 3.2, Color.WHITE)

		"laser":
			# Crystalline prism spire with orbiting energy nodes
			_draw_rot_poly(canvas, [Vector2(-7, 0), Vector2(-1, -7), Vector2(12, 0), Vector2(-1, 7)], aim_angle, Color(0.72, 0.20, 0.68))
			_draw_rot_poly(canvas, [Vector2(-4, 0), Vector2(0, -4), Vector2(9, 0), Vector2(0, 4)], aim_angle, Color(0.98, 0.52, 0.92))
			for n_i in range(3):
				var oa: float = anim_time * 3.2 + float(n_i) * TAU / 3.0
				canvas.draw_circle(Vector2(cos(oa), sin(oa)) * 11.5, 2.0, Color(0.55, 0.96, 1.0, 0.88))
			var lens_pos: Vector2 = fwd * 11.0
			canvas.draw_circle(lens_pos, 3.0, Color(1.0, 0.85, 0.98))
			canvas.draw_circle(Vector2.ZERO, 2.8, Color.WHITE)
			if muzzle_flash_timer > 0.0:
				canvas.draw_circle(lens_pos, 5.5, Color(1.0, 0.45, 0.92, 0.92))

		"slow":
			# Chrono stasis clockwork pylon with counter-rotating rings & clock hands
			canvas.draw_arc(Vector2.ZERO, 12.2, 0.0, TAU, 28, Color(0.28, 0.85, 0.98, 0.85), 1.8)
			for t_i in range(12):
				var ta: float = float(t_i) * TAU / 12.0 + anim_time * 0.5
				var tv := Vector2(cos(ta), sin(ta))
				canvas.draw_line(tv * 9.5, tv * 12.5, Color(0.65, 0.96, 1.0, 0.85), 1.3)
			var decay_lvl: int = int(levels.get("damage", 0))
			var core_col := Color(0.75, 0.45, 1.0) if decay_lvl > 0 else Color(0.32, 0.92, 1.0)
			canvas.draw_arc(Vector2.ZERO, 7.2, -anim_time * 2.4, -anim_time * 2.4 + PI * 1.4, 20, core_col, 2.2)
			canvas.draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(anim_time * 2.2) * 8.5, Color.WHITE, 1.8)
			canvas.draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(-anim_time * 0.8) * 6.0, Color(0.82, 0.96, 1.0), 1.5)
			canvas.draw_circle(Vector2.ZERO, 3.2, core_col)
			canvas.draw_circle(Vector2.ZERO, 1.6, Color.WHITE)
			if muzzle_flash_timer > 0.0:
				canvas.draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 28, Color(0.55, 0.96, 1.0, 0.9), 2.4)

		"railgun":
			# Long-range twin-rail temporal accelerator with glowing capacitor coils
			var r_len: float = 21.0 - recoil
			canvas.draw_line(-fwd * 6.0 + side * 3.4, fwd * r_len + side * 3.4, Color(0.75, 0.55, 1.0), 2.4)
			canvas.draw_line(-fwd * 6.0 - side * 3.4, fwd * r_len - side * 3.4, Color(0.75, 0.55, 1.0), 2.4)
			canvas.draw_line(-fwd * 4.0, fwd * (r_len - 2.0), Color(1.0, 0.90, 0.45, 0.85), 1.8)
			for c_i in range(3):
				var cp: Vector2 = fwd * (4.0 + float(c_i) * 5.0 - recoil * 0.6)
				var c_pulse: float = 0.6 + 0.4 * sin(anim_time * 7.0 - float(c_i) * 1.1)
				canvas.draw_line(cp - side * 4.8, cp + side * 4.8, Color(0.95, 0.72, 1.0, c_pulse), 2.0)
			_draw_rot_poly(canvas, [Vector2(-9, -6), Vector2(4, -5), Vector2(6, 0), Vector2(4, 5), Vector2(-9, 6)], aim_angle, Color(0.45, 0.22, 0.78))
			canvas.draw_circle(-fwd * 2.0, 3.6, Color(0.95, 0.78, 1.0))
			if muzzle_flash_timer > 0.0:
				canvas.draw_circle(fwd * (r_len + 2.0), 5.5, Color(0.95, 0.72, 1.0, 0.95))
				canvas.draw_circle(fwd * (r_len + 2.0), 2.6, Color(1.0, 0.96, 0.72))

		"annihilator":
			# Heavy Gauss Annihilator anti-boss siege turret
			var g_len: float = 20.0 - recoil
			canvas.draw_line(-fwd * 4.0 + side * 6.5, fwd * 8.0 + side * 6.5, Color(0.42, 0.24, 0.14), 4.0)
			canvas.draw_line(-fwd * 4.0 - side * 6.5, fwd * 8.0 - side * 6.5, Color(0.42, 0.24, 0.14), 4.0)
			canvas.draw_line(fwd * 2.0, fwd * g_len, Color(0.28, 0.22, 0.18), 7.5)
			canvas.draw_line(fwd * 2.0 + side * 2.2, fwd * g_len + side * 2.2, Color(1.0, 0.78, 0.28), 2.0)
			canvas.draw_line(fwd * 2.0 - side * 2.2, fwd * g_len - side * 2.2, Color(1.0, 0.78, 0.28), 2.0)
			_draw_rot_poly(canvas, [Vector2(-9, -8), Vector2(6, -7), Vector2(9, 0), Vector2(6, 7), Vector2(-9, 8)], aim_angle, Color(0.78, 0.34, 0.18))
			canvas.draw_circle(Vector2.ZERO, 4.8, Color(1.0, 0.85, 0.32))
			canvas.draw_circle(Vector2.ZERO, 2.2, Color.WHITE)
			if muzzle_flash_timer > 0.0:
				canvas.draw_circle(fwd * (g_len + 2.5), 6.2, Color(1.0, 0.82, 0.28, 0.95))
				canvas.draw_circle(fwd * (g_len + 2.5), 3.0, Color.WHITE)

		# === 21 UNIQUE COMBINED TURRETS (6 Same-Type + 15 Cross-Type Hybrids) ===

		"blaster+blaster":
			# Quad staggered rotary autocannons + dual drum magazines + spinning top radar dish
			for offset_y in [-6.8, -2.6, 2.6, 6.8]:
				var bs: Vector2 = fwd * (1.0 - recoil * 0.7) + side * offset_y
				var be: Vector2 = fwd * ((19.5 if absf(offset_y) < 4.0 else 17.0) - recoil) + side * offset_y
				canvas.draw_line(bs, be, Color(0.20, 0.30, 0.45), 3.0)
				canvas.draw_line(bs, be, Color(0.68, 0.92, 1.0), 1.4)
			canvas.draw_circle(-fwd * 3.0 + side * 7.5, 4.2, Color(0.18, 0.40, 0.72))
			canvas.draw_circle(-fwd * 3.0 - side * 7.5, 4.2, Color(0.18, 0.40, 0.72))
			_draw_rot_poly(canvas, [Vector2(-8, -8), Vector2(7, -7), Vector2(10, 0), Vector2(7, 7), Vector2(-8, 8)], aim_angle, Color(0.18, 0.48, 0.85))
			var rad_v: Vector2 = Vector2.RIGHT.rotated(anim_time * 4.5) * 6.0
			canvas.draw_line(-rad_v, rad_v, Color(0.55, 0.96, 1.0), 1.8)
			canvas.draw_circle(Vector2.ZERO, 3.2, Color.WHITE)

		"mortar+mortar":
			# 6 radial hydraulic anchor struts + fanned triple-bore MIRV siege tubes
			for s_i in range(6):
				var sa: float = float(s_i) * TAU / 6.0
				canvas.draw_line(Vector2(cos(sa), sin(sa)) * 7.0, Vector2(cos(sa), sin(sa)) * 15.0, Color(0.32, 0.44, 0.36), 2.8)
			for sub_a in [-0.30, 0.0, 0.30]:
				var dir_s: Vector2 = fwd.rotated(sub_a)
				var tend: Vector2 = dir_s * (15.5 - recoil * 0.7)
				canvas.draw_line(-dir_s * 2.0, tend, Color(0.20, 0.34, 0.25), 6.2)
				canvas.draw_line(-dir_s * 1.0, tend, Color(0.45, 0.88, 0.58), 3.6)
				canvas.draw_circle(tend, 2.2, Color(1.0, 0.76, 0.28))
			canvas.draw_circle(Vector2.ZERO, 6.2, Color(0.24, 0.56, 0.38))
			canvas.draw_circle(Vector2.ZERO, 2.8, Color(1.0, 0.84, 0.32))

		"laser+laser":
			# Twin nested crystal obelisk + 6 orbiting cyan resonator nodes
			_draw_rot_poly(canvas, [Vector2(-10, 0), Vector2(0, -10), Vector2(14, 0), Vector2(0, 10)], aim_angle, Color(0.65, 0.16, 0.62))
			_draw_rot_poly(canvas, [Vector2(-6, 0), Vector2(0, -6), Vector2(11, 0), Vector2(0, 6)], aim_angle, Color(1.0, 0.45, 0.92))
			for n_i in range(6):
				var oa: float = anim_time * 3.8 + float(n_i) * TAU / 6.0
				var np := Vector2(cos(oa), sin(oa)) * 12.8
				canvas.draw_circle(np, 2.1, Color(0.48, 0.96, 1.0) if n_i % 2 == 0 else Color(1.0, 0.72, 0.98))
			canvas.draw_line(fwd * 4.0, fwd * 15.5, Color(1.0, 0.88, 0.98), 2.6)
			canvas.draw_circle(Vector2.ZERO, 3.6, Color.WHITE)

		"slow+slow":
			# Double counter-rotating Stasis clock gears + floating bubble emitter dome
			canvas.draw_arc(Vector2.ZERO, 13.8, 0.0, TAU, 32, Color(0.35, 0.92, 1.0, 0.92), 2.2)
			canvas.draw_arc(Vector2.ZERO, 9.6, anim_time * 2.2, anim_time * 2.2 + PI * 1.6, 24, Color(0.75, 0.48, 1.0), 2.4)
			for t_i in range(8):
				var ta: float = float(t_i) * TAU / 8.0 - anim_time * 1.1
				var tv := Vector2(cos(ta), sin(ta))
				canvas.draw_line(tv * 8.0, tv * 14.2, Color(0.55, 0.95, 1.0), 2.0)
			canvas.draw_circle(Vector2.ZERO, 5.5 + 1.0 * sin(anim_time * 5.0), Color(0.38, 0.78, 1.0, 0.85))
			canvas.draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(-anim_time * 2.6) * 9.0, Color.WHITE, 1.8)
			canvas.draw_circle(Vector2.ZERO, 2.4, Color.WHITE)

		"railgun+railgun":
			# Stacked twin-tier mega-collider rails + 4 golden capacitor rings + heavy dark breech
			var m_len: float = 23.0 - recoil
			for y_o in [-5.8, -2.6, 2.6, 5.8]:
				canvas.draw_line(-fwd * 7.0 + side * y_o, fwd * m_len + side * y_o, Color(0.78, 0.50, 1.0) if absf(y_o) > 4.0 else Color(0.95, 0.82, 1.0), 2.0)
			canvas.draw_line(-fwd * 5.0, fwd * (m_len - 1.0), Color(1.0, 0.90, 0.42), 2.2)
			for c_i in range(4):
				var cp: Vector2 = fwd * (1.0 + float(c_i) * 4.8 - recoil * 0.5)
				canvas.draw_line(cp - side * 7.2, cp + side * 7.2, Color(1.0, 0.86, 0.35), 2.0)
			_draw_rot_poly(canvas, [Vector2(-10, -8), Vector2(3, -7), Vector2(6, 0), Vector2(3, 7), Vector2(-10, 8)], aim_angle, Color(0.40, 0.18, 0.74))
			canvas.draw_circle(-fwd * 2.0, 4.2, Color(1.0, 0.92, 0.55))

		"annihilator+annihilator":
			# Twin heavy bronze MAC wedge rails + side pistons + golden plasma core
			var k_len: float = 22.0 - recoil
			canvas.draw_line(-fwd * 6.0 + side * 8.2, fwd * 9.0 + side * 8.2, Color(0.45, 0.25, 0.14), 4.2)
			canvas.draw_line(-fwd * 6.0 - side * 8.2, fwd * 9.0 - side * 8.2, Color(0.45, 0.25, 0.14), 4.2)
			canvas.draw_line(fwd * 1.0 + side * 3.8, fwd * k_len + side * 3.8, Color(0.32, 0.22, 0.16), 5.6)
			canvas.draw_line(fwd * 1.0 - side * 3.8, fwd * k_len - side * 3.8, Color(0.32, 0.22, 0.16), 5.6)
			canvas.draw_line(fwd * 2.0 + side * 3.8, fwd * k_len + side * 3.8, Color(1.0, 0.84, 0.28), 2.4)
			canvas.draw_line(fwd * 2.0 - side * 3.8, fwd * k_len - side * 3.8, Color(1.0, 0.84, 0.28), 2.4)
			_draw_rot_poly(canvas, [Vector2(-10, -9), Vector2(7, -8), Vector2(11, 0), Vector2(7, 8), Vector2(-10, 9)], aim_angle, Color(0.80, 0.36, 0.16))
			canvas.draw_circle(Vector2.ZERO, 5.5, Color(1.0, 0.88, 0.35))
			canvas.draw_circle(Vector2.ZERO, 2.5, Color.WHITE)

		"blaster+mortar":
			# Dual flared angled flak barrels flanking a green rotary shell drum
			var f_len: float = 16.5 - recoil
			canvas.draw_line(side * 5.2, fwd * f_len + side * 5.8, Color(0.24, 0.42, 0.44), 5.2)
			canvas.draw_line(-side * 5.2, fwd * f_len - side * 5.8, Color(0.24, 0.42, 0.44), 5.2)
			canvas.draw_line(fwd * 2.0 + side * 5.2, fwd * f_len + side * 5.8, Color(0.55, 0.92, 0.82), 2.2)
			canvas.draw_line(fwd * 2.0 - side * 5.2, fwd * f_len - side * 5.8, Color(0.55, 0.92, 0.82), 2.2)
			canvas.draw_circle(-fwd * 2.0, 7.2, Color(0.18, 0.48, 0.38))
			for s_i in range(4):
				var sa: float = aim_angle + float(s_i) * PI * 0.5
				canvas.draw_circle(Vector2(cos(sa), sin(sa)) * 3.8, 1.8, Color(1.0, 0.82, 0.32))

		"blaster+laser":
			# Dual cyan Blaster rails straddling a central magenta crystal emitter blade
			var p_len: float = 18.0 - recoil
			canvas.draw_line(side * 5.2, fwd * p_len + side * 5.2, Color(0.45, 0.82, 1.0), 2.6)
			canvas.draw_line(-side * 5.2, fwd * p_len - side * 5.2, Color(0.45, 0.82, 1.0), 2.6)
			_draw_rot_poly(canvas, [Vector2(-6, -5), Vector2(4, -5), Vector2(14, 0), Vector2(4, 5), Vector2(-6, 5)], aim_angle, Color(0.75, 0.24, 0.72))
			_draw_rot_poly(canvas, [Vector2(-2, 0), Vector2(3, -3), Vector2(12, 0), Vector2(3, 3)], aim_angle, Color(1.0, 0.65, 0.96))
			canvas.draw_circle(-fwd * 4.0, 3.0, Color(0.55, 0.96, 1.0))

		"blaster+slow":
			# Dual Blaster barrels projecting through a rotating cyan chrono-bubble halo
			var bs1: Vector2 = fwd * (2.0 - recoil) + side * 3.6
			var be1: Vector2 = fwd * (18.0 - recoil) + side * 3.6
			var bs2: Vector2 = fwd * (2.0 - recoil) - side * 3.6
			var be2: Vector2 = fwd * (18.0 - recoil) - side * 3.6
			canvas.draw_line(bs1, be1, Color(0.32, 0.78, 1.0), 3.0)
			canvas.draw_line(bs2, be2, Color(0.32, 0.78, 1.0), 3.0)
			canvas.draw_arc(Vector2.ZERO, 12.0, anim_time * 2.5, anim_time * 2.5 + PI * 1.45, 22, Color(0.42, 0.95, 1.0), 2.2)
			_draw_rot_poly(canvas, [Vector2(-6, -5), Vector2(6, -4), Vector2(8, 0), Vector2(6, 4), Vector2(-6, 5)], aim_angle, Color(0.18, 0.45, 0.78))
			canvas.draw_circle(Vector2.ZERO, 3.8, Color(0.65, 0.98, 1.0))

		"blaster+railgun":
			# Long rapid-cooled accelerator rails with slotted radiator fins + top ammo drum
			var hr_len: float = 21.5 - recoil
			canvas.draw_line(-fwd * 4.0 + side * 3.5, fwd * hr_len + side * 3.5, Color(0.52, 0.85, 1.0), 2.6)
			canvas.draw_line(-fwd * 4.0 - side * 3.5, fwd * hr_len - side * 3.5, Color(0.52, 0.85, 1.0), 2.6)
			for f_i in range(4):
				var fp: Vector2 = fwd * (3.0 + float(f_i) * 4.2 - recoil * 0.5)
				canvas.draw_line(fp - side * 5.6, fp + side * 5.6, Color(0.75, 0.52, 1.0), 1.8)
			_draw_rot_poly(canvas, [Vector2(-9, -6), Vector2(3, -5), Vector2(5, 0), Vector2(3, 5), Vector2(-9, 6)], aim_angle, Color(0.28, 0.34, 0.68))
			canvas.draw_circle(-fwd * 2.5, 4.0, Color(0.55, 0.94, 1.0))

		"blaster+annihilator":
			# Heavy bronze Gauss main cannon flanked by dual cyan rotary sub-barrels
			var s_len: float = 20.5 - recoil
			canvas.draw_line(fwd * 2.0, fwd * s_len, Color(0.78, 0.44, 0.18), 6.0)
			canvas.draw_line(fwd * 2.0, fwd * s_len, Color(1.0, 0.84, 0.32), 2.2)
			canvas.draw_line(fwd * 1.0 + side * 6.0, fwd * (16.0 - recoil) + side * 6.0, Color(0.45, 0.85, 1.0), 2.4)
			canvas.draw_line(fwd * 1.0 - side * 6.0, fwd * (16.0 - recoil) - side * 6.0, Color(0.45, 0.85, 1.0), 2.4)
			_draw_rot_poly(canvas, [Vector2(-9, -8), Vector2(6, -7), Vector2(9, 0), Vector2(6, 7), Vector2(-9, 8)], aim_angle, Color(0.55, 0.36, 0.28))
			canvas.draw_circle(Vector2.ZERO, 4.2, Color(0.55, 0.94, 1.0))

		"mortar+laser":
			# Emerald mortar cauldron cradling a levitating pink plasma crystal orb + 3 prism fins
			for s_i in range(3):
				var sa: float = aim_angle + float(s_i) * TAU / 3.0
				var sv := Vector2(cos(sa), sin(sa))
				canvas.draw_line(sv * 5.0, sv * 14.0, Color(0.85, 0.32, 0.78), 2.8)
			canvas.draw_line(-fwd * 3.0, fwd * (14.0 - recoil * 0.7), Color(0.22, 0.48, 0.34), 8.8)
			canvas.draw_circle(fwd * (11.0 - recoil * 0.7), 4.6, Color(1.0, 0.42, 0.88))
			canvas.draw_circle(Vector2.ZERO, 6.2, Color(0.95, 0.45, 0.90))
			canvas.draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.92, 0.80))

		"mortar+slow":
			# Wide frosted siege mortar wrapped in helical icy chrono rings + side cryo canisters
			canvas.draw_circle(side * 8.2, 4.0, Color(0.25, 0.82, 0.92))
			canvas.draw_circle(-side * 8.2, 4.0, Color(0.25, 0.82, 0.92))
			canvas.draw_line(-fwd * 3.0, fwd * (15.0 - recoil * 0.8), Color(0.18, 0.42, 0.38), 9.2)
			for c_i in range(3):
				var cp: Vector2 = fwd * (3.0 + float(c_i) * 4.2 - recoil * 0.6)
				canvas.draw_line(cp - side * 5.2, cp + side * 5.2, Color(0.45, 0.96, 1.0), 2.0)
			canvas.draw_circle(fwd * (14.0 - recoil * 0.8), 4.2, Color(0.42, 0.95, 1.0))
			canvas.draw_circle(Vector2.ZERO, 4.8, Color(0.28, 0.88, 0.76))

		"mortar+railgun":
			# Elevated violet dual-rail artillery cradle with amber gear arcs
			canvas.draw_arc(Vector2.ZERO, 12.2, aim_angle - 1.1, aim_angle + 1.1, 16, Color(1.0, 0.78, 0.32), 2.4)
			var o_len: float = 19.0 - recoil
			canvas.draw_line(-fwd * 5.0 + side * 4.5, fwd * o_len + side * 4.5, Color(0.65, 0.42, 0.95), 3.2)
			canvas.draw_line(-fwd * 5.0 - side * 4.5, fwd * o_len - side * 4.5, Color(0.65, 0.42, 0.95), 3.2)
			canvas.draw_line(-fwd * 2.0, fwd * (13.0 - recoil), Color(0.28, 0.62, 0.46), 7.0)
			canvas.draw_circle(fwd * 4.0, 4.5, Color(0.92, 0.68, 1.0))

		"mortar+annihilator":
			# Bulldozer front shield + massive thick bronze-green bunker-buster tube + twin side Gauss rails
			var b_len: float = 17.5 - recoil
			_draw_rot_poly(canvas, [Vector2(4, -10), Vector2(9, -8), Vector2(9, 8), Vector2(4, 10)], aim_angle, Color(0.68, 0.38, 0.18))
			canvas.draw_line(-fwd * 4.0, fwd * b_len, Color(0.28, 0.36, 0.24), 9.6)
			canvas.draw_line(fwd * 1.0 + side * 5.6, fwd * (16.5 - recoil) + side * 5.6, Color(1.0, 0.78, 0.28), 2.2)
			canvas.draw_line(fwd * 1.0 - side * 5.6, fwd * (16.5 - recoil) - side * 5.6, Color(1.0, 0.78, 0.28), 2.2)
			canvas.draw_circle(fwd * b_len, 4.0, Color(1.0, 0.72, 0.26))
			canvas.draw_circle(-fwd * 3.0, 5.2, Color(0.86, 0.56, 0.24))

		"laser+slow":
			# Spinning cyan-pink crystal octahedron suspended inside 12-tick cryo-clock ring
			canvas.draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 28, Color(0.40, 0.94, 1.0), 1.8)
			for t_i in range(6):
				var ta: float = float(t_i) * TAU / 6.0 + anim_time * 1.4
				canvas.draw_circle(Vector2(cos(ta), sin(ta)) * 13.0, 1.8, Color(1.0, 0.55, 0.92))
			_draw_rot_poly(canvas, [Vector2(-8, 0), Vector2(0, -8), Vector2(12, 0), Vector2(0, 8)], anim_time * 2.0, Color(0.68, 0.28, 0.88))
			canvas.draw_circle(Vector2.ZERO, 4.2, Color(0.55, 0.96, 1.0))
			canvas.draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

		"laser+railgun":
			# Razor-sharp split violet rails converging on a glowing magenta crystal nozzle + beam rings
			var lr_len: float = 22.0 - recoil
			canvas.draw_line(-fwd * 6.0 + side * 3.8, fwd * lr_len + side * 1.5, Color(0.85, 0.45, 1.0), 2.4)
			canvas.draw_line(-fwd * 6.0 - side * 3.8, fwd * lr_len - side * 1.5, Color(0.85, 0.45, 1.0), 2.4)
			_draw_rot_poly(canvas, [Vector2(-6, -5), Vector2(6, -3), Vector2(15, 0), Vector2(6, 3), Vector2(-6, 5)], aim_angle, Color(0.88, 0.26, 0.75))
			canvas.draw_circle(fwd * lr_len, 3.2, Color(1.0, 0.85, 0.98))

		"laser+annihilator":
			# Copper Gauss pincer claws holding a blazing superheated plasma crystal core
			var la_len: float = 19.5 - recoil
			canvas.draw_line(-fwd * 4.0 + side * 5.2, fwd * la_len + side * 3.2, Color(0.86, 0.42, 0.18), 3.6)
			canvas.draw_line(-fwd * 4.0 - side * 5.2, fwd * la_len - side * 3.2, Color(0.86, 0.42, 0.18), 3.6)
			canvas.draw_line(fwd * 2.0 + side * 3.2, fwd * la_len + side * 2.2, Color(1.0, 0.84, 0.34), 1.6)
			canvas.draw_line(fwd * 2.0 - side * 3.2, fwd * la_len - side * 2.2, Color(1.0, 0.84, 0.34), 1.6)
			_draw_rot_poly(canvas, [Vector2(-4, -5), Vector2(4, -4), Vector2(10, 0), Vector2(4, 4), Vector2(-4, 5)], aim_angle, Color(1.0, 0.35, 0.82))
			canvas.draw_circle(fwd * 2.0, 4.0, Color(1.0, 0.86, 0.96))

		"slow+railgun":
			# Clockwork dial turret topped with extended frost-violet twin magnetic rails + ice capacitors
			var az_len: float = 22.0 - recoil
			canvas.draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 26, Color(0.45, 0.94, 1.0, 0.88), 1.8)
			canvas.draw_line(-fwd * 5.0 + side * 4.0, fwd * az_len + side * 4.0, Color(0.55, 0.88, 1.0), 2.6)
			canvas.draw_line(-fwd * 5.0 - side * 4.0, fwd * az_len - side * 4.0, Color(0.75, 0.52, 1.0), 2.6)
			canvas.draw_line(-fwd * 3.0, fwd * (az_len - 2.0), Color(0.68, 0.96, 1.0), 1.8)
			canvas.draw_circle(side * 6.8, 3.2, Color(0.38, 0.92, 1.0))
			canvas.draw_circle(-side * 6.8, 3.2, Color(0.78, 0.52, 1.0))
			canvas.draw_circle(Vector2.ZERO, 4.5, Color.WHITE)

		"slow+annihilator":
			# Heavy bronze Gauss barrel encircled by a gyroscopic cyan stasis ring
			var sa_len: float = 19.5 - recoil
			canvas.draw_arc(Vector2.ZERO, 13.5, -anim_time * 2.4, -anim_time * 2.4 + PI * 1.5, 24, Color(0.42, 0.95, 1.0), 2.4)
			canvas.draw_line(fwd * 1.0, fwd * sa_len, Color(0.30, 0.24, 0.18), 7.4)
			canvas.draw_line(fwd * 2.0, fwd * sa_len, Color(1.0, 0.82, 0.30), 2.8)
			_draw_rot_poly(canvas, [Vector2(-8, -7), Vector2(6, -6), Vector2(8, 0), Vector2(6, 6), Vector2(-8, 7)], aim_angle, Color(0.72, 0.36, 0.20))
			canvas.draw_circle(Vector2.ZERO, 4.5, Color(0.45, 0.96, 1.0))

		"railgun+annihilator":
			# Colossal quad-ringed gold-and-violet endgame dual-stage magnetic cannon + swept armor wings
			var og_len: float = 23.0 - recoil
			_draw_rot_poly(canvas, [Vector2(-10, -11), Vector2(0, -10), Vector2(4, -5), Vector2(4, 5), Vector2(0, 10), Vector2(-10, 11)], aim_angle, Color(0.46, 0.22, 0.68))
			canvas.draw_line(-fwd * 5.0 + side * 4.5, fwd * og_len + side * 4.5, Color(1.0, 0.84, 0.28), 3.0)
			canvas.draw_line(-fwd * 5.0 - side * 4.5, fwd * og_len - side * 4.5, Color(0.85, 0.52, 1.0), 3.0)
			canvas.draw_line(-fwd * 4.0, fwd * og_len, Color(1.0, 0.95, 0.72), 2.4)
			for c_i in range(3):
				var cp: Vector2 = fwd * (4.0 + float(c_i) * 5.2 - recoil * 0.5)
				canvas.draw_line(cp - side * 6.5, cp + side * 6.5, Color(0.55, 0.96, 1.0), 1.8)
			canvas.draw_circle(Vector2.ZERO, 5.2, Color(1.0, 0.88, 0.38))
			canvas.draw_circle(Vector2.ZERO, 2.4, Color.WHITE)

		_:
			canvas.draw_circle(Vector2.ZERO, 8.0, Color(0.5, 0.8, 1.0))
			canvas.draw_line(Vector2.ZERO, fwd * 16.0, Color.WHITE, 3.0)
