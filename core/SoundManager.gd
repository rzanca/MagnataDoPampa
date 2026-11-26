extends Node

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 4
const SUBTLE_EVENTS: Array[String] = ["hop", "ui"]

var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _stream_cache: Dictionary[String, AudioStreamWAV] = {}
var _ambient_player: AudioStreamPlayer = null
var _ambient_cache: Dictionary[String, AudioStreamWAV] = {}
var _current_ambient_season: String = ""

var _audio_enabled: bool = true
var _audio_volume: float = 0.75
var _step_sfx_enabled: bool = true
var _ambient_enabled: bool = true
var _ambient_volume: float = 0.35
var _app_paused: bool = false

func _ready() -> void:
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % i
		add_child(player)
		_players.append(player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientBedPlayer"
	add_child(_ambient_player)
	_apply_volume_to_players()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_app_paused = true
		if _ambient_player != null and is_instance_valid(_ambient_player) and _ambient_player.playing:
			_ambient_player.stop()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_app_paused = false
		_sync_ambient_playback()

func apply_preferences(prefs: Dictionary) -> void:
	_audio_enabled = bool(prefs.get("audio_enabled", true))
	_audio_volume = clampf(float(prefs.get("audio_volume", 0.75)), 0.0, 1.0)
	_step_sfx_enabled = bool(prefs.get("audio_step_sfx", true))
	_ambient_enabled = bool(prefs.get("ambient_enabled", true))
	_ambient_volume = clampf(float(prefs.get("ambient_volume", 0.35)), 0.0, 1.0)
	_apply_volume_to_players()
	_sync_ambient_playback()

func is_audio_enabled() -> bool:
	return _audio_enabled

func get_audio_volume() -> float:
	return _audio_volume

func is_step_sfx_enabled() -> bool:
	return _step_sfx_enabled

func is_ambient_enabled() -> bool:
	return _ambient_enabled

func get_ambient_volume() -> float:
	return _ambient_volume

func get_current_ambient_season() -> String:
	return _current_ambient_season

func _apply_volume_to_players() -> void:
	var db: float = -80.0
	if _audio_enabled and _audio_volume > 0.01:
		db = linear_to_db(_audio_volume * 0.55)
	for p: AudioStreamPlayer in _players:
		if p != null and is_instance_valid(p):
			p.volume_db = db
	if _ambient_player != null and is_instance_valid(_ambient_player):
		var amb_db: float = -80.0
		if _audio_enabled and _ambient_enabled and _audio_volume > 0.01 and _ambient_volume > 0.01:
			amb_db = linear_to_db(_audio_volume * _ambient_volume * 0.24)
		_ambient_player.volume_db = amb_db

func set_ambient_season(season_id: String) -> void:
	var norm_season: String = season_id.strip_edges().to_upper()
	if norm_season == "":
		norm_season = "PRIMAVERA"
	if _current_ambient_season == norm_season and _ambient_player != null and _ambient_player.playing:
		return
	_current_ambient_season = norm_season
	_sync_ambient_playback()

func stop_ambient() -> void:
	_current_ambient_season = ""
	if _ambient_player != null and is_instance_valid(_ambient_player):
		_ambient_player.stop()

func _sync_ambient_playback() -> void:
	if _ambient_player == null or not is_instance_valid(_ambient_player):
		return
	if _app_paused or not _audio_enabled or not _ambient_enabled or _audio_volume <= 0.01 or _ambient_volume <= 0.01 or _current_ambient_season == "":
		if _ambient_player.playing:
			_ambient_player.stop()
		return
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		return
	var stream: AudioStreamWAV = get_or_create_ambient_stream(_current_ambient_season)
	if stream == null:
		return
	if _ambient_player.stream != stream or not _ambient_player.playing:
		_ambient_player.stream = stream
		_ambient_player.play()

func get_or_create_ambient_stream(season_id: String) -> AudioStreamWAV:
	var key: String = season_id.strip_edges().to_upper()
	if key == "":
		key = "PRIMAVERA"
	if _ambient_cache.has(key):
		return _ambient_cache[key]
	var wav: AudioStreamWAV = _build_ambient_wav(key)
	if wav != null:
		_ambient_cache[key] = wav
	return wav

func play_sfx(event_name: String) -> void:
	if not _audio_enabled or _audio_volume <= 0.01:
		return
	if not _step_sfx_enabled and (event_name in SUBTLE_EVENTS):
		return
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		return
	if _players.is_empty():
		return

	var stream: AudioStreamWAV = get_or_create_stream(event_name)
	if stream == null:
		return

	var voice: AudioStreamPlayer = _players[_next_player_idx % _players.size()]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	if voice == null or not is_instance_valid(voice):
		return
	voice.stream = stream
	voice.play()

func get_or_create_stream(event_name: String) -> AudioStreamWAV:
	if _stream_cache.has(event_name):
		return _stream_cache[event_name]
	var wav: AudioStreamWAV = _build_preset_wav(event_name)
	if wav != null:
		_stream_cache[event_name] = wav
	return wav

func _build_preset_wav(event_name: String) -> AudioStreamWAV:
	match event_name:
		"roll":
			return _concat_tones([
				{"f0": 185.0, "f1": 135.0, "dur": 0.048, "wave": "dice", "amp": 0.42},
				{"f0": 245.0, "f1": 165.0, "dur": 0.045, "wave": "dice", "amp": 0.36},
				{"f0": 310.0, "f1": 195.0, "dur": 0.052, "wave": "dice", "amp": 0.38},
				{"f0": 420.0, "f1": 230.0, "dur": 0.068, "wave": "dice", "amp": 0.32}
			])
		"hop":
			return _concat_tones([
				{"f0": 175.0, "f1": 92.0, "dur": 0.052, "wave": "hoof", "amp": 0.34}
			])
		"ui":
			return _concat_tones([
				{"f0": 520.0, "f1": 660.0, "dur": 0.032, "wave": "guitar", "amp": 0.24}
			])
		"buy":
			return _concat_tones([
				{"f0": 329.63, "f1": 329.63, "dur": 0.068, "wave": "guitar", "amp": 0.38},
				{"f0": 440.00, "f1": 440.00, "dur": 0.068, "wave": "guitar", "amp": 0.40},
				{"f0": 554.37, "f1": 554.37, "dur": 0.078, "wave": "guitar", "amp": 0.42},
				{"f0": 880.00, "f1": 880.00, "dur": 0.165, "wave": "coin", "chord": [1.0, 1.5], "amp": 0.44}
			])
		"pay":
			return _concat_tones([
				{"f0": 987.77, "f1": 920.0, "dur": 0.060, "wave": "coin", "amp": 0.32},
				{"f0": 329.63, "f1": 246.94, "dur": 0.110, "wave": "guitar", "amp": 0.36},
				{"f0": 220.00, "f1": 196.00, "dur": 0.145, "wave": "accordion", "chord": [1.0, 1.1892], "amp": 0.34}
			])
		"build":
			return _concat_tones([
				{"f0": 155.0, "f1": 98.0, "dur": 0.058, "wave": "gavel", "amp": 0.44},
				{"f0": 392.00, "f1": 392.00, "dur": 0.075, "wave": "guitar", "amp": 0.36},
				{"f0": 523.25, "f1": 523.25, "dur": 0.155, "wave": "accordion", "chord": [1.0, 1.25, 1.5], "amp": 0.42}
			])
		"mortgage":
			return _concat_tones([
				{"f0": 293.66, "f1": 220.00, "dur": 0.140, "wave": "accordion", "chord": [1.0, 1.1892], "amp": 0.38},
				{"f0": 740.00, "f1": 698.46, "dur": 0.070, "wave": "coin", "amp": 0.28}
			])
		"chance_good":
			return _concat_tones([
				{"f0": 440.00, "f1": 440.00, "dur": 0.068, "wave": "accordion", "amp": 0.38},
				{"f0": 554.37, "f1": 554.37, "dur": 0.068, "wave": "accordion", "amp": 0.40},
				{"f0": 659.25, "f1": 659.25, "dur": 0.080, "wave": "accordion", "amp": 0.42},
				{"f0": 880.00, "f1": 880.00, "dur": 0.210, "wave": "accordion", "chord": [1.0, 1.25, 1.5], "amp": 0.44}
			])
		"chance_bad":
			return _concat_tones([
				{"f0": 165.00, "f1": 115.00, "dur": 0.120, "wave": "wind", "amp": 0.36},
				{"f0": 261.63, "f1": 233.08, "dur": 0.125, "wave": "accordion", "chord": [1.0, 1.1892], "amp": 0.34},
				{"f0": 196.00, "f1": 155.56, "dur": 0.220, "wave": "accordion", "chord": [1.0, 1.1892], "amp": 0.38}
			])
		"auction_bid":
			return _concat_tones([
				{"f0": 698.46, "f1": 740.00, "dur": 0.090, "wave": "bell", "chord": [1.0, 1.5], "amp": 0.38}
			])
		"auction_win":
			return _concat_tones([
				{"f0": 150.0, "f1": 90.0, "dur": 0.062, "wave": "gavel", "amp": 0.46},
				{"f0": 523.25, "f1": 523.25, "dur": 0.075, "wave": "coin", "amp": 0.38},
				{"f0": 659.25, "f1": 659.25, "dur": 0.080, "wave": "accordion", "amp": 0.40},
				{"f0": 783.99, "f1": 783.99, "dur": 0.220, "wave": "accordion", "chord": [1.0, 1.25, 1.5], "amp": 0.45}
			])
		"festival":
			return _concat_tones([
				{"f0": 392.00, "f1": 392.00, "dur": 0.075, "wave": "accordion", "amp": 0.38},
				{"f0": 493.88, "f1": 493.88, "dur": 0.075, "wave": "accordion", "amp": 0.40},
				{"f0": 587.33, "f1": 587.33, "dur": 0.085, "wave": "accordion", "amp": 0.42},
				{"f0": 783.99, "f1": 783.99, "dur": 0.220, "wave": "accordion", "chord": [1.0, 1.25, 1.5], "amp": 0.44},
				{"f0": 1174.66, "f1": 1174.66, "dur": 0.140, "wave": "coin", "amp": 0.30}
			])
		"season_change":
			return _concat_tones([
				{"f0": 260.0, "f1": 340.0, "dur": 0.120, "wave": "wind", "amp": 0.28},
				{"f0": 440.0, "f1": 440.0, "dur": 0.210, "wave": "accordion", "chord": [1.0, 1.5], "amp": 0.38}
			])
		"bankrupt":
			return _concat_tones([
				{"f0": 293.66, "f1": 261.63, "dur": 0.150, "wave": "accordion", "chord": [1.0, 1.1892], "amp": 0.34},
				{"f0": 220.00, "f1": 185.00, "dur": 0.210, "wave": "accordion", "chord": [1.0, 1.1892], "amp": 0.34},
				{"f0": 146.83, "f1": 110.00, "dur": 0.340, "wave": "guitar", "chord": [1.0, 1.1892, 1.4983], "amp": 0.38}
			])
		"victory":
			return _concat_tones([
				{"f0": 392.00, "f1": 392.00, "dur": 0.090, "wave": "guitar", "amp": 0.40},
				{"f0": 493.88, "f1": 493.88, "dur": 0.090, "wave": "accordion", "amp": 0.42},
				{"f0": 587.33, "f1": 587.33, "dur": 0.105, "wave": "accordion", "chord": [1.0, 1.25], "amp": 0.44},
				{"f0": 783.99, "f1": 783.99, "dur": 0.280, "wave": "accordion", "chord": [1.0, 1.25, 1.5], "amp": 0.48},
				{"f0": 1567.98, "f1": 1567.98, "dur": 0.220, "wave": "coin", "chord": [1.0, 1.5], "amp": 0.36}
			])
		_:
			return _concat_tones([
				{"f0": 480.0, "f1": 480.0, "dur": 0.050, "wave": "guitar", "amp": 0.24}
			])

func _sample_waveform(wave: String, phase: float, t_norm: float, rnd: float) -> float:
	match wave:
		"accordion":
			var tremolo: float = 0.90 + 0.10 * sin(t_norm * TAU * 4.5)
			var reeds: float = (
				sin(phase) * 0.52 +
				sin(phase * 1.006) * 0.28 +
				sin(phase * 0.994) * 0.26 +
				sin(phase * 2.0) * 0.22 +
				sin(phase * 3.0) * 0.12
			)
			return reeds * 0.72 * tremolo
		"guitar":
			var decay2: float = exp(-5.5 * t_norm)
			var decay3: float = exp(-9.5 * t_norm)
			var decay4: float = exp(-14.0 * t_norm)
			var body: float = (
				sin(phase) * 0.62 +
				sin(phase * 2.0) * 0.36 * decay2 +
				sin(phase * 3.0) * 0.22 * decay3 +
				sin(phase * 4.0) * 0.12 * decay4
			)
			return body * exp(-2.8 * t_norm)
		"coin":
			var metal: float = (
				sin(phase) * 0.58 +
				sin(phase * 2.756) * 0.32 * exp(-4.0 * t_norm) +
				sin(phase * 5.404) * 0.18 * exp(-7.5 * t_norm)
			)
			return metal * exp(-4.5 * t_norm)
		"hoof":
			var thud: float = sin(phase) * 0.65 * exp(-16.0 * t_norm) + rnd * 0.35 * exp(-26.0 * t_norm)
			return thud
		"dice":
			var tap: float = (rnd * 0.58 + sin(phase) * 0.28 + sin(phase * 1.7) * 0.18) * exp(-12.0 * t_norm)
			return tap
		"gavel":
			var knock: float = (sin(phase) * 0.70 + sin(phase * 2.3) * 0.30 + rnd * 0.25) * exp(-18.0 * t_norm)
			return knock
		"bell":
			var chime: float = (
				sin(phase) * 0.55 +
				sin(phase * 2.0) * 0.28 +
				sin(phase * 2.42) * 0.22 * exp(-3.5 * t_norm)
			)
			return chime * exp(-3.8 * t_norm)
		"wind":
			var gust: float = rnd * 0.45 + sin(phase) * 0.38 + sin(phase * 0.5) * 0.22
			return gust * sin(PI * clampf(t_norm, 0.0, 1.0))
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"triangle":
			return 2.0 * absf(2.0 * fposmod(phase / TAU, 1.0) - 1.0) - 1.0
		"saw":
			return 2.0 * fposmod(phase / TAU, 1.0) - 1.0
		"noise":
			return rnd * 0.65 + sin(phase) * 0.35
		_:
			return sin(phase)

func _concat_tones(segments: Array[Dictionary]) -> AudioStreamWAV:
	var pcm: PackedByteArray = PackedByteArray()
	var seed_val: int = 1337
	for seg: Dictionary in segments:
		var f0: float = float(seg.get("f0", 440.0))
		var f1: float = float(seg.get("f1", f0))
		var dur: float = maxf(0.015, float(seg.get("dur", 0.08)))
		var wave: String = str(seg.get("wave", "sine"))
		var amp: float = clampf(float(seg.get("amp", 0.35)), 0.05, 0.85)
		var chord_ratios: Array = seg.get("chord", [1.0])
		if chord_ratios.is_empty():
			chord_ratios = [1.0]
		var phases: Array[float] = []
		for _c: int in range(chord_ratios.size()):
			phases.append(0.0)
		var voice_norm: float = 1.0 / sqrt(float(chord_ratios.size()))

		var count: int = maxi(64, roundi(dur * float(SAMPLE_RATE)))
		var attack_n: int = maxi(1, mini(roundi(0.007 * float(SAMPLE_RATE)), floori(float(count) * 0.22)))
		var release_n: int = maxi(1, mini(roundi(0.028 * float(SAMPLE_RATE)), floori(float(count) * 0.45)))

		for i: int in range(count):
			var t_norm: float = float(i) / float(maxi(1, count - 1))
			var freq: float = lerpf(f0, f1, t_norm)
			seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
			var rnd: float = (float(seed_val % 2000) / 1000.0) - 1.0

			var mix_val: float = 0.0
			for v_idx: int in range(chord_ratios.size()):
				var ratio: float = float(chord_ratios[v_idx])
				phases[v_idx] += TAU * (freq * ratio) / float(SAMPLE_RATE)
				mix_val += _sample_waveform(wave, phases[v_idx], t_norm, rnd)
			var sample_val: float = clampf(mix_val * voice_norm, -1.0, 1.0)

			var env: float = 1.0
			if i < attack_n:
				env = float(i) / float(attack_n)
			elif i > count - release_n:
				env = float(count - i) / float(release_n)

			var int16: int = clampi(roundi(sample_val * amp * env * 32767.0), -32767, 32767)
			pcm.append(int16 & 0xFF)
			pcm.append((int16 >> 8) & 0xFF)

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	return wav

func _build_ambient_wav(season_id: String) -> AudioStreamWAV:
	# Loop musical suave de 8 segundos (arpejo acústico de violão pampeano sem ruído branco ou zumbido contínuo)
	var dur: float = 8.0
	var count: int = roundi(dur * float(SAMPLE_RATE))
	var notes: Array[float] = [196.00, 246.94, 293.66, 392.00, 293.66, 246.94]
	var pad_root: float = 196.00
	var pad_fifth: float = 293.66
	match season_id:
		"VERAO":
			notes = [293.66, 369.99, 440.00, 587.33, 440.00, 369.99]
			pad_root = 146.83
			pad_fifth = 220.00
		"OUTONO":
			notes = [220.00, 261.63, 329.63, 440.00, 329.63, 261.63]
			pad_root = 110.00
			pad_fifth = 164.81
		"INVERNO":
			notes = [164.81, 196.00, 246.94, 329.63, 246.94, 196.00]
			pad_root = 164.81
			pad_fifth = 246.94
		_:
			notes = [196.00, 246.94, 293.66, 392.00, 293.66, 246.94]
			pad_root = 196.00
			pad_fifth = 293.66

	var q_pad_root: float = maxf(1.0, roundf(pad_root * dur)) / dur
	var q_pad_fifth: float = maxf(1.0, roundf(pad_fifth * dur)) / dur

	var float_buf: PackedFloat32Array = PackedFloat32Array()
	float_buf.resize(count)

	# Pad harmônico muito sutil que respira suavemente ao longo do ciclo completo
	for i: int in range(count):
		var t_sec: float = float(i) / float(SAMPLE_RATE)
		var breath: float = 0.35 + 0.65 * (0.5 - 0.5 * cos(TAU * t_sec / dur))
		var pad_val: float = (
			sin(TAU * q_pad_root * t_sec) * 0.55 +
			sin(TAU * q_pad_fifth * t_sec) * 0.35
		) * (0.045 * breath)
		float_buf[i] = pad_val

	# Dedilhado suave de violão acústico espaçado com folga natural (zero fadiga auditiva)
	var note_times: Array[float] = [0.00, 1.30, 2.55, 3.85, 5.15, 6.40]
	var note_dur: float = 1.45
	var note_samples: int = roundi(note_dur * float(SAMPLE_RATE))
	for idx_n: int in range(mini(notes.size(), note_times.size())):
		var start_s: int = roundi(note_times[idx_n] * float(SAMPLE_RATE))
		var freq: float = notes[idx_n]
		for k: int in range(note_samples):
			var dst_i: int = (start_s + k) % count
			var t_k: float = float(k) / float(SAMPLE_RATE)
			var t_norm: float = float(k) / float(maxi(1, note_samples - 1))
			var env_att: float = clampf(t_k / 0.015, 0.0, 1.0)
			var env_dec: float = exp(-3.4 * t_k)
			var env_tail: float = clampf((1.0 - t_norm) / 0.12, 0.0, 1.0)
			var phase: float = TAU * freq * t_k
			var guitar: float = (
				sin(phase) * 0.65 +
				sin(phase * 2.0) * 0.25 * exp(-5.0 * t_k) +
				sin(phase * 3.0) * 0.10 * exp(-9.0 * t_k)
			) * 0.24 * env_att * env_dec * env_tail
			float_buf[dst_i] += guitar

	# Crossfade suave nas bordas para loop matematicamente sem clique
	var fade_n: int = 551
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(count * 2)
	for i: int in range(count):
		var edge_env: float = 1.0
		if i < fade_n:
			edge_env = float(i) / float(fade_n)
		elif i >= count - fade_n:
			edge_env = float(count - 1 - i) / float(fade_n)
		var sample_val: float = clampf(float_buf[i] * edge_env, -1.0, 1.0)
		var int16: int = clampi(roundi(sample_val * 32767.0), -32767, 32767)
		var byte_off: int = i * 2
		pcm[byte_off] = int16 & 0xFF
		pcm[byte_off + 1] = (int16 >> 8) & 0xFF

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	wav.data = pcm
	return wav
