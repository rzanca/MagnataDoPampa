extends Node

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 4
const SUBTLE_EVENTS: Array[String] = ["hop", "ui"]

var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _stream_cache: Dictionary[String, AudioStreamWAV] = {}

var _audio_enabled: bool = true
var _audio_volume: float = 0.75
var _step_sfx_enabled: bool = true

func _ready() -> void:
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % i
		add_child(player)
		_players.append(player)
	_apply_volume_to_players()

func apply_preferences(prefs: Dictionary) -> void:
	_audio_enabled = bool(prefs.get("audio_enabled", true))
	_audio_volume = clampf(float(prefs.get("audio_volume", 0.75)), 0.0, 1.0)
	_step_sfx_enabled = bool(prefs.get("audio_step_sfx", true))
	_apply_volume_to_players()

func is_audio_enabled() -> bool:
	return _audio_enabled

func get_audio_volume() -> float:
	return _audio_volume

func is_step_sfx_enabled() -> bool:
	return _step_sfx_enabled

func _apply_volume_to_players() -> void:
	var db: float = -80.0
	if _audio_enabled and _audio_volume > 0.01:
		db = linear_to_db(_audio_volume * 0.55)
	for p: AudioStreamPlayer in _players:
		if p != null and is_instance_valid(p):
			p.volume_db = db

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
				{"f0": 260.0, "f1": 180.0, "dur": 0.045, "wave": "noise", "amp": 0.34},
				{"f0": 320.0, "f1": 210.0, "dur": 0.045, "wave": "noise", "amp": 0.30},
				{"f0": 390.0, "f1": 240.0, "dur": 0.055, "wave": "noise", "amp": 0.28}
			])
		"hop":
			return _concat_tones([
				{"f0": 340.0, "f1": 480.0, "dur": 0.055, "wave": "sine", "amp": 0.26}
			])
		"ui":
			return _concat_tones([
				{"f0": 580.0, "f1": 680.0, "dur": 0.035, "wave": "sine", "amp": 0.20}
			])
		"buy":
			return _concat_tones([
				{"f0": 523.25, "f1": 523.25, "dur": 0.070, "wave": "triangle", "amp": 0.38},
				{"f0": 659.25, "f1": 659.25, "dur": 0.075, "wave": "triangle", "amp": 0.38},
				{"f0": 783.99, "f1": 1046.5, "dur": 0.140, "wave": "sine", "amp": 0.42}
			])
		"pay":
			return _concat_tones([
				{"f0": 330.0, "f1": 277.18, "dur": 0.085, "wave": "triangle", "amp": 0.36},
				{"f0": 246.94, "f1": 196.0, "dur": 0.145, "wave": "sine", "amp": 0.38}
			])
		"build":
			return _concat_tones([
				{"f0": 220.0, "f1": 150.0, "dur": 0.055, "wave": "square", "amp": 0.24},
				{"f0": 440.0, "f1": 554.37, "dur": 0.085, "wave": "triangle", "amp": 0.34},
				{"f0": 659.25, "f1": 659.25, "dur": 0.120, "wave": "sine", "amp": 0.38}
			])
		"mortgage":
			return _concat_tones([
				{"f0": 311.13, "f1": 233.08, "dur": 0.110, "wave": "triangle", "amp": 0.34}
			])
		"chance_good":
			return _concat_tones([
				{"f0": 493.88, "f1": 493.88, "dur": 0.075, "wave": "sine", "amp": 0.35},
				{"f0": 659.25, "f1": 659.25, "dur": 0.085, "wave": "sine", "amp": 0.38},
				{"f0": 987.77, "f1": 987.77, "dur": 0.160, "wave": "sine", "amp": 0.40}
			])
		"chance_bad":
			return _concat_tones([
				{"f0": 293.66, "f1": 261.63, "dur": 0.110, "wave": "saw", "amp": 0.26},
				{"f0": 220.00, "f1": 174.61, "dur": 0.190, "wave": "triangle", "amp": 0.34}
			])
		"auction_bid":
			return _concat_tones([
				{"f0": 587.33, "f1": 739.99, "dur": 0.080, "wave": "triangle", "amp": 0.34}
			])
		"auction_win":
			return _concat_tones([
				{"f0": 260.0, "f1": 190.0, "dur": 0.055, "wave": "square", "amp": 0.26},
				{"f0": 523.25, "f1": 523.25, "dur": 0.070, "wave": "triangle", "amp": 0.38},
				{"f0": 783.99, "f1": 1046.5, "dur": 0.180, "wave": "sine", "amp": 0.42}
			])
		"festival":
			return _concat_tones([
				{"f0": 440.0, "f1": 440.0, "dur": 0.075, "wave": "triangle", "amp": 0.34},
				{"f0": 554.37, "f1": 554.37, "dur": 0.075, "wave": "triangle", "amp": 0.36},
				{"f0": 659.25, "f1": 659.25, "dur": 0.085, "wave": "triangle", "amp": 0.38},
				{"f0": 880.0, "f1": 880.0, "dur": 0.200, "wave": "sine", "amp": 0.42}
			])
		"bankrupt":
			return _concat_tones([
				{"f0": 261.63, "f1": 220.0, "dur": 0.140, "wave": "saw", "amp": 0.26},
				{"f0": 196.00, "f1": 146.83, "dur": 0.220, "wave": "saw", "amp": 0.28},
				{"f0": 130.81, "f1": 98.00, "dur": 0.320, "wave": "triangle", "amp": 0.34}
			])
		"victory":
			return _concat_tones([
				{"f0": 523.25, "f1": 523.25, "dur": 0.095, "wave": "triangle", "amp": 0.38},
				{"f0": 659.25, "f1": 659.25, "dur": 0.095, "wave": "triangle", "amp": 0.38},
				{"f0": 783.99, "f1": 783.99, "dur": 0.110, "wave": "triangle", "amp": 0.40},
				{"f0": 1046.50, "f1": 1046.50, "dur": 0.280, "wave": "sine", "amp": 0.45}
			])
		_:
			return _concat_tones([
				{"f0": 480.0, "f1": 480.0, "dur": 0.050, "wave": "sine", "amp": 0.24}
			])

func _concat_tones(segments: Array[Dictionary]) -> AudioStreamWAV:
	var pcm: PackedByteArray = PackedByteArray()
	var seed_val: int = 1337
	for seg: Dictionary in segments:
		var f0: float = float(seg.get("f0", 440.0))
		var f1: float = float(seg.get("f1", f0))
		var dur: float = maxf(0.015, float(seg.get("dur", 0.08)))
		var wave: String = str(seg.get("wave", "sine"))
		var amp: float = clampf(float(seg.get("amp", 0.35)), 0.05, 0.85)
		var count: int = maxi(64, roundi(dur * float(SAMPLE_RATE)))
		var phase: float = 0.0
		var attack_n: int = maxi(1, mini(roundi(0.008 * float(SAMPLE_RATE)), floori(float(count) * 0.25)))
		var release_n: int = maxi(1, mini(roundi(0.025 * float(SAMPLE_RATE)), floori(float(count) * 0.45)))

		for i: int in range(count):
			var t_norm: float = float(i) / float(maxi(1, count - 1))
			var freq: float = lerpf(f0, f1, t_norm)
			phase += TAU * freq / float(SAMPLE_RATE)
			var sample_val: float = 0.0
			match wave:
				"square":
					sample_val = 1.0 if sin(phase) >= 0.0 else -1.0
				"triangle":
					sample_val = 2.0 * absf(2.0 * fposmod(phase / TAU, 1.0) - 1.0) - 1.0
				"saw":
					sample_val = 2.0 * fposmod(phase / TAU, 1.0) - 1.0
				"noise":
					seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
					var rnd: float = (float(seed_val % 2000) / 1000.0) - 1.0
					sample_val = rnd * 0.65 + sin(phase) * 0.35
				_:
					sample_val = sin(phase)

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
