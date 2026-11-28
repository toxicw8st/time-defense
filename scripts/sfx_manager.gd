extends Node

## Lightweight procedural sci-fi SFX synthesizer (zero external audio files).
## Pre-generates 16-bit PCM AudioStreamWAV clips in memory so Web PWA, Android APK, and Desktop
## play instant, crackle-free sound effects without AudioStreamGenerator thread dropouts.

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 10

var muted: bool = false
var volume_linear: float = 0.85
var master_volume_db: float = -8.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _last_play_msec: Dictionary = {}
var _is_headless: bool = false


func _ready() -> void:
	_is_headless = (DisplayServer.get_name() == "headless")
	if GameState != null:
		volume_linear = clampf(GameState.sfx_volume, 0.0, 1.0)
		muted = GameState.saved_sfx_muted
	if _is_headless:
		return
	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.volume_db = _effective_volume_db(0.0)
		add_child(p)
		_players.append(p)
	_build_all_clips()


func set_volume_linear(slider01: float) -> void:
	volume_linear = clampf(slider01, 0.0, 1.0)
	var db: float = _effective_volume_db(0.0)
	for p in _players:
		p.volume_db = db


func _effective_volume_db(vol_offset_db: float) -> float:
	if volume_linear <= 0.001:
		return -80.0
	# Squared perceptual slider-to-dB mapping (per audio-design skill)
	return master_volume_db + linear_to_db(volume_linear * volume_linear) + vol_offset_db


func set_muted(is_muted: bool) -> void:
	muted = is_muted
	if muted:
		for p in _players:
			if p.playing:
				p.stop()


func play(sfx_name: String, pitch_jitter: float = 0.06, vol_offset_db: float = 0.0) -> void:
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
	player.volume_db = _effective_volume_db(vol_offset_db)
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
	_streams["surge"] = _gen_dual_tone(0.34, 220.0, 311.13, 0.48)
	_streams["hive_beam"] = _gen_explosion(0.50, 480.0, 88.0, 0.68)
	_streams["ui"] = _gen_sweep(0.032, 840.0, 920.0, 0.20, "sine", 0.0)
	_streams["leak"] = _gen_sweep(0.18, 210.0, 105.0, 0.46, "saw", 0.08)


func _pack_pcm(samples: PackedFloat32Array) -> AudioStreamWAV:
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
