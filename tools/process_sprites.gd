extends SceneTree

## Batch chroma-key, green-despill, pedestal-pivot extractor, and PNG optimizer
## Run with: Godot --headless --path . --script res://tools/process_sprites.gd

const SRC_DIR: String = "C:/Users/toxic/Downloads/TimeDefense_Combined_Towers"
const OUT_ROOT: String = "res://assets/sprites"

func _init() -> void:
	var jobs: Array[Dictionary] = [
		# --- 6 Base Towers ---
		{"src": "blaster_turret.jpg", "dst": "towers/blaster.png", "cat": "tower", "key": "blaster", "out_max": 180, "radial": false},
		{"src": "cluster_mortar.jpg", "dst": "towers/mortar.png", "cat": "tower", "key": "mortar", "out_max": 180, "radial": false},
		{"src": "laser_spire.jpg", "dst": "towers/laser.png", "cat": "tower", "key": "laser", "out_max": 180, "radial": false},
		{"src": "01_chrono_slow_tower.jpg", "dst": "towers/slow.png", "cat": "tower", "key": "slow", "out_max": 180, "radial": true},
		{"src": "02_time_decay_rail_gun.jpg", "dst": "towers/railgun.png", "cat": "tower", "key": "railgun", "out_max": 200, "radial": false},
		{"src": "03_gauss_annihilator.jpg", "dst": "towers/annihilator.png", "cat": "tower", "key": "annihilator", "out_max": 192, "radial": false},

		# --- 6 Same-Type Combined Towers ---
		{"src": "04_twin_linked_vulcan_battery.jpg", "dst": "towers/blaster_blaster.png", "cat": "tower", "key": "blaster+blaster", "out_max": 192, "radial": false},
		{"src": "05_mirv_siege_howitzer.jpg", "dst": "towers/mortar_mortar.png", "cat": "tower", "key": "mortar+mortar", "out_max": 192, "radial": false},
		{"src": "09_prismatic_focus_obelisk.jpg", "dst": "towers/laser_laser.png", "cat": "tower", "key": "laser+laser", "out_max": 200, "radial": false, "despill_glow": true},
		{"src": "10_stasis_singularity_pylon.jpg", "dst": "towers/slow_slow.png", "cat": "tower", "key": "slow+slow", "out_max": 184, "radial": true, "despill_glow": true},
		{"src": "11_chrono_breach_supercollider.jpg", "dst": "towers/railgun_railgun.png", "cat": "tower", "key": "railgun+railgun", "out_max": 210, "radial": false, "despill_glow": true},
		{"src": "06_hyper_velocity_mac_cannon.jpg", "dst": "towers/annihilator_annihilator.png", "cat": "tower", "key": "annihilator+annihilator", "out_max": 196, "radial": false},

		# --- 15 Cross-Type Combined Towers ---
		{"src": "12_flak_barrage_battery.jpg", "dst": "towers/blaster_mortar.png", "cat": "tower", "key": "blaster+mortar", "out_max": 192, "radial": false},
		{"src": "13_pulse_plasma_carbine.jpg", "dst": "towers/blaster_laser.png", "cat": "tower", "key": "blaster+laser", "out_max": 192, "radial": false, "despill_glow": true},
		{"src": "14_chrono_kinetic_suppressor.jpg", "dst": "towers/blaster_slow.png", "cat": "tower", "key": "blaster+slow", "out_max": 192, "radial": false, "despill_glow": true},
		{"src": "15_hyper_cycle_rail_rifle.jpg", "dst": "towers/blaster_railgun.png", "cat": "tower", "key": "blaster+railgun", "out_max": 204, "radial": false, "despill_glow": true},
		{"src": "16_autocannon_siege_shredder.jpg", "dst": "towers/blaster_annihilator.png", "cat": "tower", "key": "blaster+annihilator", "out_max": 196, "radial": false},
		{"src": "17_solar_plasma_artillery.jpg", "dst": "towers/mortar_laser.png", "cat": "tower", "key": "mortar+laser", "out_max": 192, "radial": false},
		{"src": "18_cryo_cluster_bombard.jpg", "dst": "towers/mortar_slow.png", "cat": "tower", "key": "mortar+slow", "out_max": 192, "radial": false},
		{"src": "19_orbital_temporal_howitzer.jpg", "dst": "towers/mortar_railgun.png", "cat": "tower", "key": "mortar+railgun", "out_max": 200, "radial": false},
		{"src": "20_armor_cracker_siege_cannon.jpg", "dst": "towers/mortar_annihilator.png", "cat": "tower", "key": "mortar+annihilator", "out_max": 196, "radial": false},
		{"src": "21_stasis_bubble_projector.jpg", "dst": "towers/laser_slow.png", "cat": "tower", "key": "laser+slow", "out_max": 200, "radial": false, "despill_glow": true},
		{"src": "22_chrono_lance_thermal_beam.jpg", "dst": "towers/laser_railgun.png", "cat": "tower", "key": "laser+railgun", "out_max": 210, "radial": false, "despill_glow": true},
		{"src": "23_thermal_melter_rail_spire.jpg", "dst": "towers/laser_annihilator.png", "cat": "tower", "key": "laser+annihilator", "out_max": 200, "radial": false, "despill_glow": true},
		{"src": "24_absolute_zero_chrono_cannon.jpg", "dst": "towers/slow_railgun.png", "cat": "tower", "key": "slow+railgun", "out_max": 204, "radial": false, "despill_glow": true},
		{"src": "25_temporal_lock_rail_breaker.jpg", "dst": "towers/slow_annihilator.png", "cat": "tower", "key": "slow+annihilator", "out_max": 200, "radial": false, "despill_glow": true},
		{"src": "26_omega_singularity_gauss_rail.jpg", "dst": "towers/railgun_annihilator.png", "cat": "tower", "key": "railgun+annihilator", "out_max": 220, "radial": false, "despill_glow": true},

		# --- 10 Enemies ---
		{"src": "crawler.jpg", "dst": "enemies/crawler.png", "cat": "enemy", "key": "crawler", "out_max": 140, "radial": false},
		{"src": "rusher.jpg", "dst": "enemies/rusher.png", "cat": "enemy", "key": "rusher", "out_max": 140, "radial": false},
		{"src": "brute.jpg", "dst": "enemies/brute.png", "cat": "enemy", "key": "brute", "out_max": 168, "radial": false},
		{"src": "blitzer.jpg", "dst": "enemies/blitzer.png", "cat": "enemy", "key": "blitzer", "out_max": 152, "radial": false, "despill_glow": true},
		{"src": "juggernaut.jpg", "dst": "enemies/juggernaut.png", "cat": "enemy", "key": "juggernaut", "out_max": 200, "radial": false, "despill_glow": true},
		{"src": "colossus.jpg", "dst": "enemies/colossus.png", "cat": "enemy", "key": "colossus", "out_max": 220, "radial": false, "despill_glow": true},
		{"src": "stalker.jpg", "dst": "enemies/stalker.png", "cat": "enemy", "key": "stalker", "out_max": 152, "radial": false, "despill_glow": true},
		{"src": "mender.jpg", "dst": "enemies/mender.png", "cat": "enemy", "key": "mender", "out_max": 160, "radial": false},
		{"src": "carrier.jpg", "dst": "enemies/carrier.png", "cat": "enemy", "key": "carrier", "out_max": 192, "radial": false},
		{"src": "conduit.jpg", "dst": "enemies/conduit.png", "cat": "enemy", "key": "conduit", "out_max": 180, "radial": false, "despill_glow": true},

		# --- 5 Structures ---
		{"src": "player_base.jpg", "dst": "structures/player_base.png", "cat": "structure", "key": "player_base", "out_max": 240, "radial": true},
		{"src": "alien_base.jpg", "dst": "structures/alien_base.png", "cat": "structure", "key": "alien_base", "out_max": 240, "radial": true},
		{"src": "refinery.jpg", "dst": "structures/refinery.png", "cat": "structure", "key": "refinery", "out_max": 180, "radial": true},
		{"src": "chrono_manipulator.jpg", "dst": "structures/chrono_manipulator.png", "cat": "structure", "key": "chrono_manipulator", "out_max": 180, "radial": true, "despill_glow": true},
		{"src": "hive_destroyer.jpg", "dst": "structures/hive_destroyer.png", "cat": "structure", "key": "hive_destroyer", "out_max": 210, "radial": false},

		# --- 1 Character Portrait ---
		{"src": "vex.jpg", "dst": "characters/vex.png", "cat": "character", "key": "vex", "out_max": 512, "radial": true, "despill_glow": true},
	]

	for sub in ["towers", "enemies", "structures", "characters"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ROOT + "/" + sub))

	var meta: Dictionary = {}
	var ok_count: int = 0
	var t0: int = Time.get_ticks_msec()

	for job in jobs:
		var src_path: String = SRC_DIR + "/" + str(job["src"])
		var dst_res: String = OUT_ROOT + "/" + str(job["dst"])
		var dst_abs: String = ProjectSettings.globalize_path(dst_res)
		var res_info: Dictionary = _process_one(src_path, dst_abs, job)
		if res_info.is_empty():
			push_error("FAILED to process: " + src_path)
			quit(1)
			return
		var meta_key: String = "%s:%s" % [str(job["cat"]), str(job["key"])]
		meta[meta_key] = res_info
		ok_count += 1
		print("[%d/%d] %s -> %s (%dx%d pivot=%.2f,%.2f)" % [
			ok_count, jobs.size(), str(job["src"]), str(job["dst"]),
			int(res_info["w"]), int(res_info["h"]),
			float(res_info["pivot_x"]), float(res_info["pivot_y"])
		])

	var json_abs: String = ProjectSettings.globalize_path(OUT_ROOT + "/sprite_pivots.json")
	var jf := FileAccess.open(json_abs, FileAccess.WRITE)
	if jf != null:
		jf.store_string(JSON.stringify(meta, "\t"))
		jf.close()
	var elapsed: float = float(Time.get_ticks_msec() - t0) / 1000.0
	print("SPRITE_PROCESS_OK count=%d elapsed=%.2fs" % [ok_count, elapsed])
	quit(0)


func _process_one(src_path: String, dst_abs: String, job: Dictionary) -> Dictionary:
	var img := Image.new()
	if img.load(src_path) != OK:
		return {}

	var is_char: bool = (str(job["cat"]) == "character")
	var pre_max: int = 768 if is_char else 560
	var w0: int = img.get_width()
	var h0: int = img.get_height()
	if maxi(w0, h0) > pre_max:
		var sc: float = float(pre_max) / float(maxi(w0, h0))
		img.resize(maxi(1, int(round(w0 * sc))), maxi(1, int(round(h0 * sc))), Image.INTERPOLATE_BILINEAR)

	img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	var n: int = w * h
	var data: PackedByteArray = img.get_data()

	# bg_mask: 0 = foreground, 1 = knocked-out chroma background, 2 = semi-transparent glow/edge
	var bg_mask := PackedByteArray()
	bg_mask.resize(n)
	bg_mask.fill(0)

	# Pre-allocate BFS ring queue
	var queue := PackedInt32Array()
	queue.resize(n)
	var q_head: int = 0
	var q_tail: int = 0

	# 1) Seed BFS from all 4 image edges wherever pixel is chroma green
	for x in range(w):
		for y in [0, h - 1]:
			var idx: int = y * w + x
			if bg_mask[idx] == 0:
				var o: int = idx * 4
				var r: int = data[o]
				var g: int = data[o + 1]
				var b: int = data[o + 2]
				var mx: int = maxi(r, b)
				if g > 85 and (g - mx) > 25:
					bg_mask[idx] = 1
					queue[q_tail] = idx
					q_tail += 1
	for y in range(h):
		for x in [0, w - 1]:
			var idx: int = y * w + x
			if bg_mask[idx] == 0:
				var o: int = idx * 4
				var r: int = data[o]
				var g: int = data[o + 1]
				var b: int = data[o + 2]
				var mx: int = maxi(r, b)
				if g > 85 and (g - mx) > 25:
					bg_mask[idx] = 1
					queue[q_tail] = idx
					q_tail += 1

	# Exterior BFS flood-fill (4-connected)
	while q_head < q_tail:
		var idx: int = queue[q_head]
		q_head += 1
		var cx: int = idx % w
		var cy: int = idx / w
		if cx > 0:
			var ni: int = idx - 1
			if bg_mask[ni] == 0:
				var o: int = ni * 4
				var g: int = data[o + 1]
				var mx: int = maxi(data[o], data[o + 2])
				if g > 95 and (g - mx) > 36 and data[o] < 160:
					bg_mask[ni] = 1
					queue[q_tail] = ni
					q_tail += 1
		if cx < w - 1:
			var ni: int = idx + 1
			if bg_mask[ni] == 0:
				var o: int = ni * 4
				var g: int = data[o + 1]
				var mx: int = maxi(data[o], data[o + 2])
				if g > 95 and (g - mx) > 36 and data[o] < 160:
					bg_mask[ni] = 1
					queue[q_tail] = ni
					q_tail += 1
		if cy > 0:
			var ni: int = idx - w
			if bg_mask[ni] == 0:
				var o: int = ni * 4
				var g: int = data[o + 1]
				var mx: int = maxi(data[o], data[o + 2])
				if g > 95 and (g - mx) > 36 and data[o] < 160:
					bg_mask[ni] = 1
					queue[q_tail] = ni
					q_tail += 1
		if cy < h - 1:
			var ni: int = idx + w
			if bg_mask[ni] == 0:
				var o: int = ni * 4
				var g: int = data[o + 1]
				var mx: int = maxi(data[o], data[o + 2])
				if g > 95 and (g - mx) > 36 and data[o] < 160:
					bg_mask[ni] = 1
					queue[q_tail] = ni
					q_tail += 1

	# 2) Enclosed pure chroma-screen pockets (e.g., between conduit shield ring & hull, railgun rings, legs)
	# Tight seed (unmistakable neon #00FF00: g >= 185, g - max(r,b) >= 100, r < 95, b < 110) so interior paint is 100% safe!
	q_head = 0
	q_tail = 0
	for idx in range(n):
		if bg_mask[idx] == 0:
			var o: int = idx * 4
			var r: int = data[o]
			var g: int = data[o + 1]
			var b: int = data[o + 2]
			var mx: int = maxi(r, b)
			if g >= 185 and (g - mx) >= 100 and r < 95 and b < 110:
				bg_mask[idx] = 1
				queue[q_tail] = idx
				q_tail += 1

	while q_head < q_tail:
		var idx: int = queue[q_head]
		q_head += 1
		var cx: int = idx % w
		var cy: int = idx / w
		if cx > 0:
			var ni: int = idx - 1
			if bg_mask[ni] == 0:
				var o: int = ni * 4
				var g: int = data[o + 1]
				var mx: int = maxi(data[o], data[o + 2])
				if g > 115 and (g - mx) > 48 and data[o] < 135:
					bg_mask[ni] = 1
					queue[q_tail] = ni
					q_tail += 1
		if cx < w - 1:
			var ni: int = idx + 1
			if bg_mask[ni] == 0:
				var o: int = ni * 4
				var g: int = data[o + 1]
				var mx: int = maxi(data[o], data[o + 2])
				if g > 115 and (g - mx) > 48 and data[o] < 135:
					bg_mask[ni] = 1
					queue[q_tail] = ni
					q_tail += 1
		if cy > 0:
			var ni: int = idx - w
			if bg_mask[ni] == 0:
				var o: int = ni * 4
				var g: int = data[o + 1]
				var mx: int = maxi(data[o], data[o + 2])
				if g > 115 and (g - mx) > 48 and data[o] < 135:
					bg_mask[ni] = 1
					queue[q_tail] = ni
					q_tail += 1
		if cy < h - 1:
			var ni: int = idx + w
			if bg_mask[ni] == 0:
				var o: int = ni * 4
				var g: int = data[o + 1]
				var mx: int = maxi(data[o], data[o + 2])
				if g > 115 and (g - mx) > 48 and data[o] < 135:
					bg_mask[ni] = 1
					queue[q_tail] = ni
					q_tail += 1

	# 3) Compute distance from BG up to 5 pixels for soft alpha unmixing & green despill
	var dist := PackedByteArray()
	dist.resize(n)
	dist.fill(99)
	q_head = 0
	q_tail = 0
	for idx in range(n):
		if bg_mask[idx] == 1:
			dist[idx] = 0
			queue[q_tail] = idx
			q_tail += 1
	while q_head < q_tail:
		var idx: int = queue[q_head]
		q_head += 1
		var nd: int = dist[idx] + 1
		if nd > 5:
			continue
		var cx: int = idx % w
		var cy: int = idx / w
		if cx > 0 and dist[idx - 1] > nd:
			dist[idx - 1] = nd
			queue[q_tail] = idx - 1
			q_tail += 1
		if cx < w - 1 and dist[idx + 1] > nd:
			dist[idx + 1] = nd
			queue[q_tail] = idx + 1
			q_tail += 1
		if cy > 0 and dist[idx - w] > nd:
			dist[idx - w] = nd
			queue[q_tail] = idx - w
			q_tail += 1
		if cy < h - 1 and dist[idx + w] > nd:
			dist[idx + w] = nd
			queue[q_tail] = idx + w
			q_tail += 1

	# 4) Apply transparency + chroma color-unmix & green despill on fringe pixels
	#    For sprites with translucent cyan/gold/violet shields or halos (despill_glow=true),
	#    also cleanly unmix any trapped chroma-green bleed inside translucent energy fields!
	var despill_glow: bool = bool(job.get("despill_glow", false))
	for idx in range(n):
		var o: int = idx * 4
		if bg_mask[idx] == 1:
			data[o] = 0
			data[o + 1] = 0
			data[o + 2] = 0
			data[o + 3] = 0
			continue
		var d: int = dist[idx]
		var r: int = data[o]
		var g: int = data[o + 1]
		var b: int = data[o + 2]
		var mx: int = maxi(r, b)
		var g_ex: int = g - mx
		if d <= 5:
			if g_ex > 6:
				# Semi-transparent anti-aliased edge or translucent glow over #00FF00
				var alpha_f: float = 1.0
				if d <= 2:
					alpha_f = clampf(1.0 - float(g_ex) / 140.0, 0.0, 1.0)
				elif g_ex > 18:
					alpha_f = clampf(1.0 - float(g_ex - 14) / 175.0, 0.0, 1.0)
				var clean_g: int = mx
				if alpha_f > 0.04 and alpha_f < 0.96:
					var inv_a: float = minf(2.2, 1.0 / maxf(0.18, alpha_f))
					data[o] = mini(255, int(round(float(r) * inv_a)))
					data[o + 1] = mini(255, int(round(float(clean_g) * inv_a)))
					data[o + 2] = mini(255, int(round(float(b) * inv_a)))
				else:
					data[o + 1] = clean_g
				data[o + 3] = int(round(alpha_f * 255.0))
			elif d == 1 and g > mx:
				data[o + 1] = mx
		elif despill_glow and g_ex > 10:
			# Inside translucent shield/halo over #00FF00: recover clean cyan/gold alpha!
			var alpha_g: float = clampf(1.0 - float(g_ex - 8) / 135.0, 0.0, 1.0)
			var clean_g2: int = mx
			if alpha_g > 0.05 and alpha_g < 0.96:
				var inv_a2: float = minf(2.1, 1.0 / maxf(0.20, alpha_g))
				data[o] = mini(255, int(round(float(r) * inv_a2)))
				data[o + 1] = mini(255, int(round(float(clean_g2) * inv_a2)))
				data[o + 2] = mini(255, int(round(float(b) * inv_a2)))
			else:
				data[o + 1] = clean_g2
			data[o + 3] = int(round(alpha_g * 255.0))

	# 5) Compute tight non-transparent bounding box (alpha >= 20)
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in range(h):
		var row_off: int = y * w
		for x in range(w):
			if data[(row_off + x) * 4 + 3] >= 20:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y

	if max_x < min_x or max_y < min_y:
		return {}

	var pad: int = 3
	min_x = maxi(0, min_x - pad)
	min_y = maxi(0, min_y - pad)
	max_x = mini(w - 1, max_x + pad)
	max_y = mini(h - 1, max_y + pad)
	var cw: int = max_x - min_x + 1
	var ch: int = max_y - min_y + 1

	# 6) Estimate turret pedestal pivot (for directional towers so barrel swings around circular pedestal!)
	var pivot_x: float = 0.5
	var pivot_y: float = 0.5
	var base_h_ratio: float = 1.0
	if str(job["cat"]) == "tower" and not bool(job["radial"]):
		var col_spans := PackedInt32Array()
		col_spans.resize(cw)
		var max_span: int = 1
		for x in range(cw):
			var top_y: int = ch
			var bot_y: int = -1
			var solid_cnt: int = 0
			for y in range(ch):
				var a: int = data[((min_y + y) * w + (min_x + x)) * 4 + 3]
				if a >= 140:
					solid_cnt += 1
					if y < top_y: top_y = y
					if y > bot_y: bot_y = y
			var sp: int = (bot_y - top_y + 1) if (bot_y >= top_y and solid_cnt >= 10) else 0
			col_spans[x] = sp
			if sp > max_span:
				max_span = sp
		# Tall columns belong to the circular/octagonal turret pedestal
		var tall_min_x: int = cw
		var tall_max_x: int = -1
		var thresh: int = int(round(float(max_span) * 0.72))
		for x in range(cw):
			if col_spans[x] >= thresh:
				if x < tall_min_x: tall_min_x = x
				if x > tall_max_x: tall_max_x = x
		if tall_max_x >= tall_min_x:
			var ped_cx: float = 0.5 * float(tall_min_x + tall_max_x)
			# Clamp reasonably so symmetric turrets stay centered and long railguns center on pedestal
			pivot_x = clampf(ped_cx / float(cw), 0.22, 0.52)
			base_h_ratio = clampf(float(max_span) / float(ch), 0.75, 1.0)

	# Write processed RGBA data back into image, crop, resize smoothly with Lanczos, and save PNG
	var out_img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	var cropped: Image = out_img.get_region(Rect2i(min_x, min_y, cw, ch))

	var out_max: int = int(job["out_max"])
	if maxi(cw, ch) > out_max:
		var out_sc: float = float(out_max) / float(maxi(cw, ch))
		cropped.resize(maxi(1, int(round(cw * out_sc))), maxi(1, int(round(ch * out_sc))), Image.INTERPOLATE_LANCZOS)

	if cropped.save_png(dst_abs) != OK:
		return {}

	return {
		"path": OUT_ROOT + "/" + str(job["dst"]),
		"w": cropped.get_width(),
		"h": cropped.get_height(),
		"pivot_x": snappedf(pivot_x, 0.001),
		"pivot_y": snappedf(pivot_y, 0.001),
		"base_h_ratio": snappedf(base_h_ratio, 0.001),
		"radial": bool(job["radial"]),
	}
