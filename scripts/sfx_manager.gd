extends Node

## Lightweight procedural sci-fi SFX + Adaptive 2-Layer Synth Music (zero external audio files).
## Routes through dedicated Master <- SFX / Music buses with a -1 dBTP Master limiter and
## squared perceptual 0..1 volume sliders. Uses AudioStreamSynchronized so ambient & combat stems
## stay sample-locked across Web PWA, Android APK, and Desktop.

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 10
const SFX_BUS_NAME: StringName = &"SFX"
const MUSIC_BUS_NAME: StringName = &"Music"

var muted: bool = false
var volume_linear: float = 0.85
var music_volume_linear: float = 0.45
var master_volume_db: float = -8.0
var music_intensity: int = 0 # 0 = Build/Menu, 1 = Combat, 2 = Boss/Exam

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _last_play_msec: Dictionary = {}
var _is_headless: bool = false

var _music_player: AudioStreamPlayer = null
var _music_sync: AudioStreamSynchronized = null
var _music_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_headless = (DisplayServer.get_name() == "headless")
	_ensure_audio_buses()
	if GameState != null:
		volume_linear = clampf(GameState.sfx_volume, 0.0, 1.0)
		music_volume_linear = clampf(GameState.music_volume, 0.0, 1.0)
		muted = GameState.saved_sfx_muted
		if not GameState.wave_started.is_connected(_on_wave_started):
			GameState.wave_started.connect(_on_wave_started)
		if not GameState.wave_cleared.is_connected(_on_wave_cleared):
			GameState.wave_cleared.connect(_on_wave_cleared)
		if not GameState.mission_reset.is_connected(_on_mission_calm):
			GameState.mission_reset.connect(_on_mission_calm)
		if not GameState.mission_ended.is_connected(_on_mission_ended):
			GameState.mission_ended.connect(_on_mission_ended)
	_apply_bus_gains()
	if _is_headless:
		return
	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS_NAME
		p.volume_db = master_volume_db
		add_child(p)
		_players.append(p)
	_build_all_clips()
	_build_adaptive_music()


func _exit_tree() -> void:
	if GameState != null:
		if GameState.wave_started.is_connected(_on_wave_started):
			GameState.wave_started.disconnect(_on_wave_started)
		if GameState.wave_cleared.is_connected(_on_wave_cleared):
			GameState.wave_cleared.disconnect(_on_wave_cleared)
		if GameState.mission_reset.is_connected(_on_mission_calm):
			GameState.mission_reset.disconnect(_on_mission_calm)
		if GameState.mission_ended.is_connected(_on_mission_ended):
			GameState.mission_ended.disconnect(_on_mission_ended)


func _ensure_audio_buses() -> void:
	# Ensure Master has a gentle -1 dBTP safety limiter so stacked combat blasts never clip
	var has_limiter: bool = false
	for ei in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, ei) is AudioEffectLimiter:
			has_limiter = true
			break
	if not has_limiter:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -1.0
		lim.threshold_db = -3.0
		AudioServer.add_bus_effect(0, lim)
	for bname in [SFX_BUS_NAME, MUSIC_BUS_NAME]:
		if AudioServer.get_bus_index(bname) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bname)
			AudioServer.set_bus_send(idx, &"Master")


func _apply_bus_gains() -> void:
	var sfx_idx: int = AudioServer.get_bus_index(SFX_BUS_NAME)
	if sfx_idx != -1:
		var sfx_silent: bool = muted or volume_linear <= 0.001
		AudioServer.set_bus_mute(sfx_idx, sfx_silent)
		AudioServer.set_bus_volume_linear(sfx_idx, volume_linear * volume_linear)
	var mus_idx: int = AudioServer.get_bus_index(MUSIC_BUS_NAME)
	if mus_idx != -1:
		var mus_silent: bool = muted or music_volume_linear <= 0.001
		AudioServer.set_bus_mute(mus_idx, mus_silent)
		AudioServer.set_bus_volume_linear(mus_idx, music_volume_linear * music_volume_linear)


func set_volume_linear(slider01: float) -> void:
	volume_linear = clampf(slider01, 0.0, 1.0)
	_apply_bus_gains()


func set_music_volume_linear(slider01: float) -> void:
	music_volume_linear = clampf(slider01, 0.0, 1.0)
	_apply_bus_gains()
	if not _is_headless and _music_player != null and not _music_player.playing and not muted and music_volume_linear > 0.001:
		_music_player.play()


func _effective_volume_db(vol_offset_db: float) -> float:
	if volume_linear <= 0.001:
		return -80.0
	# Squared perceptual slider-to-dB mapping (matches SFX bus gain)
	return master_volume_db + linear_to_db(volume_linear * volume_linear) + vol_offset_db


func set_muted(is_muted: bool) -> void:
	muted = is_muted
	if GameState != null:
		GameState.saved_sfx_muted = is_muted
	_apply_bus_gains()
	if muted:
		for p in _players:
			if p.playing:
				p.stop()


func set_music_intensity(level: int) -> void:
	music_intensity = clampi(level, 0, 2)
	if _is_headless or _music_sync == null:
		return
	var target_pad_db: float = -6.0 if music_intensity < 2 else -5.0
	var target_pulse_db: float = -60.0 if music_intensity == 0 else (-8.0 if music_intensity == 1 else -4.5)
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_ignore_time_scale(true)
	_music_tween.set_parallel(true)
	var cur_pad: float = _music_sync.get_sync_stream_volume(0)
	var cur_pulse: float = _music_sync.get_sync_stream_volume(1)
	_music_tween.tween_method(func(v: float) -> void:
		if _music_sync != null:
			_music_sync.set_sync_stream_volume(0, v)
	, cur_pad, target_pad_db, 0.75)
	_music_tween.tween_method(func(v: float) -> void:
		if _music_sync != null:
			_music_sync.set_sync_stream_volume(1, v)
	, cur_pulse, target_pulse_db, 0.75)


func _on_wave_started(wave_num: int) -> void:
	var is_boss_or_exam: bool = (wave_num % 5 == 0) or WavesData.EXAM_WAVES.has(wave_num) or wave_num >= 40
	set_music_intensity(2 if is_boss_or_exam else 1)
	_ensure_music_playing()


func _on_wave_cleared(_wave_num: int) -> void:
	set_music_intensity(0)


func _on_mission_calm() -> void:
	set_music_intensity(0)


func _on_mission_ended(_outcome: String, _reason: String) -> void:
	set_music_intensity(0)


func _ensure_music_playing() -> void:
	if _is_headless or _music_player == null or muted or music_volume_linear <= 0.001:
		return
	if not _music_player.playing:
		_music_player.play()


func play(sfx_name: String, pitch_jitter: float = 0.06, vol_offset_db: float = 0.0) -> void:
	_ensure_music_playing()
	if _is_headless or muted or volume_linear <= 0.001 or _players.is_empty():
		return
	if not _streams.has(sfx_name):
		return
	var now: int = Time.get_ticks_msec()
	var min_gap: int = 45 if sfx_name in ["blaster", "laser", "kill"] else 75
	if now - int(_last_play_msec.get(sfx_name, 0)) < min_gap:
		return
	_last_play_msec[sfx_name] = now

	var player: AudioStreamPlayer = _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	player.stream = _streams[sfx_name]
	# SFX bus already applies squared slider volume_linear; player only applies headroom + per-cue offset
	player.volume_db = master_volume_db + vol_offset_db
	player.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter) if pitch_jitter > 0.0 else 1.0
	player.play()


func _build_all_clips() -> void:
	_streams["blaster"] = _gen_sweep(0.075, 920.0, 260.0, 0.42, "square", 0.14)
	_streams["laser"] = _gen_dual_tone(0.085, 1180.0, 1770.0, 0.28)
	_streams["mortar"] = _gen_explosion(0.24, 155.0, 42.0, 0.62)
	_streams["bubble"] = _gen_fm_chime(0.19, 520.0, 860.0, 18.0, 0.36)
	_streams["railgun"] = _gen_explosion(0.26, 1280.0, 105.0, 0.56)
	_streams["kill"] = _gen_sweep(0.065, 620.0, 980.0, 0.24, "sine", 0.0)
	_streams["boss_kill"] = _gen_explosion(0.42, 240.0, 38.0, 0.72)
	_streams["build"] = _gen_chord(0.13, [440.0, 660.0], 0.32)
	_streams["combine"] = _gen_arpeggio(0.32, [523.25, 659.25, 783.99, 1046.5], 0.36)
	_streams["power"] = _gen_fm_chime(0.34, 340.0, 740.0, 11.0, 0.48)
	_streams["ui"] = _gen_sweep(0.032, 840.0, 920.0, 0.20, "sine", 0.0)
	_streams["leak"] = _gen_sweep(0.18, 210.0, 105.0, 0.46, "saw", 0.08)


func _build_adaptive_music() -> void:
	# 8.0s seamless loop at 120 BPM (4 bars in D Dorian: Dm7 | Dm7 | Bbmaj7 | C6)
	var dur: float = 8.0
	var n: int = int(dur * float(SAMPLE_RATE))
	var pad_buf := PackedFloat32Array()
	var pulse_buf := PackedFloat32Array()
	pad_buf.resize(n)
	pulse_buf.resize(n)

	# Bar-aligned chord frequencies (D2/A2/F3/C4 -> D2/A2/F3/C4 -> Bb1/F2/D3/A3 -> C2/G2/E3/A3)
	var bar_roots: Array[float] = [73.42, 73.42, 58.27, 65.41]
	var bar_chords: Array = [
		[146.83, 220.00, 261.63, 349.23],
		[146.83, 220.00, 293.66, 329.63],
		[116.54, 174.61, 220.00, 293.66],
		[130.81, 196.00, 261.63, 329.63],
	]
	var arp_mults: Array[float] = [1.0, 1.5, 2.0, 1.5, 1.0, 2.0, 1.5, 1.25]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42071
	var lp_hat: float = 0.0

	for i in range(n):
		var sec: float = float(i) / float(SAMPLE_RATE)
		var bar_f: float = sec * 0.5 # 2.0 seconds per bar at 120 BPM
		var bar_idx: int = clampi(int(floor(bar_f)), 0, 3)
		var bar_pos: float = bar_f - float(bar_idx)
		var chord: Array = bar_chords[bar_idx]
		var root_hz: float = bar_roots[bar_idx]

		# Soft bar crossfade envelope so chord transitions never click
		var chord_env: float = minf(1.0, bar_pos * 10.0) * minf(1.0, (1.0 - bar_pos) * 10.0)
		var breathe: float = 0.72 + 0.28 * sin(TAU * sec * 0.25)
		var pad_sig: float = 0.42 * sin(TAU * root_hz * sec)
		for cf in chord:
			pad_sig += 0.14 * sin(TAU * float(cf) * sec)
		pad_buf[i] = pad_sig * (0.35 + 0.65 * chord_env) * breathe * 0.26

		# Combat layer: 16th-note cyberpunk pulse bass + tight kick on beats 1 & 3 + soft off-beat hat
		var step_pos: float = sec * 8.0 # 8 steps/sec = 16th notes at 120 BPM
		var step_idx: int = int(floor(step_pos))
		var step_t: float = step_pos - float(step_idx)
		var arp_hz: float = root_hz * arp_mults[step_idx % arp_mults.size()] * 2.0
		var arp_env: float = minf(1.0, step_t * 28.0) * pow(1.0 - step_t, 2.2)
		var bass_raw: float = sin(TAU * arp_hz * sec)
		var arp_sig: float = (0.72 * bass_raw + 0.28 * signf(bass_raw)) * arp_env * 0.22

		var beat_pos: float = sec * 2.0 # 2 beats/sec = 120 BPM
		var beat_idx: int = int(floor(beat_pos))
		var beat_t: float = beat_pos - float(beat_idx)
		var kick_sig: float = 0.0
		if (beat_idx % 2) == 0 and beat_t < 0.24:
			var kt: float = beat_t / 0.24
			var kfreq: float = lerpf(118.0, 42.0, pow(kt, 0.55))
			kick_sig = sin(TAU * kfreq * beat_t) * pow(1.0 - kt, 2.4) * 0.34
		var hat_sig: float = 0.0
		if (step_idx % 4) == 2 and step_t < 0.45:
			lp_hat = rng.randf_range(-1.0, 1.0) - lp_hat * 0.65
			hat_sig = lp_hat * pow(1.0 - step_t / 0.45, 2.8) * 0.055

		pulse_buf[i] = clampf(arp_sig + kick_sig + hat_sig, -0.92, 0.92)

	var pad_wav: AudioStreamWAV = _pack_pcm(pad_buf, true)
	var pulse_wav: AudioStreamWAV = _pack_pcm(pulse_buf, true)
	_music_sync = AudioStreamSynchronized.new()
	_music_sync.stream_count = 2
	_music_sync.set_sync_stream(0, pad_wav)
	_music_sync.set_sync_stream(1, pulse_wav)
	_music_sync.set_sync_stream_volume(0, -6.0)
	_music_sync.set_sync_stream_volume(1, -60.0)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "AdaptiveMusicPlayer"
	_music_player.bus = MUSIC_BUS_NAME
	_music_player.stream = _music_sync
	add_child(_music_player)
	if not muted and music_volume_linear > 0.001:
		_music_player.play()


func _pack_pcm(samples: PackedFloat32Array, loop_forward: bool = false) -> AudioStreamWAV:
	var n: int = samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		var s: int = clampi(int(round(samples[i] * 32767.0)), -32768, 32767)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if loop_forward:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


func _gen_sweep(dur: float, f0: float, f1: float, amp: float, wave: String, noise_mix: float) -> AudioStreamWAV:
	var n: int = maxi(16, int(dur * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 17.0)
	for i in range(n):
		var t: float = float(i) / float(n)
		var env: float = minf(1.0, t * 28.0) * pow(1.0 - t, 1.7)
		var freq: float = lerpf(f0, f1, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var sig: float = sin(phase)
		if wave == "square":
			sig = 0.65 * signf(sig) + 0.35 * sig
		elif wave == "saw":
			sig = 2.0 * (fmod(phase / TAU, 1.0)) - 1.0
		if noise_mix > 0.0:
			sig = lerpf(sig, rng.randf_range(-1.0, 1.0), noise_mix)
		buf[i] = sig * env * amp
	return _pack_pcm(buf)


func _gen_dual_tone(dur: float, f1: float, f2: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(16, int(dur * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = minf(1.0, t * 22.0) * pow(1.0 - t, 1.4)
		buf[i] = (0.55 * sin(TAU * f1 * sec) + 0.45 * sin(TAU * f2 * sec)) * env * amp
	return _pack_pcm(buf)


func _gen_fm_chime(dur: float, f0: float, f1: float, mod_hz: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(16, int(dur * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = minf(1.0, t * 18.0) * pow(1.0 - t, 1.5)
		var freq: float = lerpf(f0, f1, t) + sin(TAU * mod_hz * sec) * 45.0
		phase += TAU * freq / float(SAMPLE_RATE)
		buf[i] = (sin(phase) * 0.75 + sin(phase * 2.0) * 0.25) * env * amp
	return _pack_pcm(buf)


func _gen_explosion(dur: float, f0: float, f1: float, amp: float) -> AudioStreamWAV:
	var n: int = maxi(16, int(dur * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 31.0)
	var lp: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var env: float = minf(1.0, t * 40.0) * pow(1.0 - t, 1.8)
		var freq: float = lerpf(f0, f1, pow(t, 0.65))
		phase += TAU * freq / float(SAMPLE_RATE)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.22)
		buf[i] = (0.58 * sin(phase) + 0.42 * lp) * env * amp
	return _pack_pcm(buf)


func _gen_chord(dur: float, freqs: Array, amp: float) -> AudioStreamWAV:
	var n: int = maxi(16, int(dur * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var inv: float = 1.0 / float(maxi(1, freqs.size()))
	for i in range(n):
		var t: float = float(i) / float(n)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = minf(1.0, t * 25.0) * pow(1.0 - t, 1.5)
		var sum: float = 0.0
		for f in freqs:
			sum += sin(TAU * float(f) * sec)
		buf[i] = sum * inv * env * amp
	return _pack_pcm(buf)


func _gen_arpeggio(dur: float, notes: Array, amp: float) -> AudioStreamWAV:
	var n: int = maxi(16, int(dur * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var seg: int = maxi(1, n / maxi(1, notes.size()))
	for i in range(n):
		var idx: int = mini(notes.size() - 1, i / seg)
		var local_t: float = float(i % seg) / float(seg)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = minf(1.0, local_t * 18.0) * pow(1.0 - local_t * 0.65, 1.3)
		var f: float = float(notes[idx])
		buf[i] = (0.75 * sin(TAU * f * sec) + 0.25 * sin(TAU * f * 2.0 * sec)) * env * amp
	return _pack_pcm(buf)
