extends Node
## All sound is synthesised at startup, so the project needs no audio files.

const RATE := 16000

var streams := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _siren: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_streams()
	for bus in ["Ambience", "Effects"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 5.0
		p.max_distance = 30.0
		p.bus = "Effects"
		add_child(p)
		_pool.append(p)
	for i in 4:
		var u := AudioStreamPlayer.new()
		u.bus = "Effects"
		add_child(u)
		_ui.append(u)
	_drone = AudioStreamPlayer.new()
	_drone.stream = streams.drone
	_drone.volume_db = -14.0
	_drone.bus = "Ambience"
	add_child(_drone)
	_heart = AudioStreamPlayer.new()
	_heart.stream = streams.heartbeat
	_heart.volume_db = -2.0
	_heart.bus = "Effects"
	add_child(_heart)
	_siren = AudioStreamPlayer.new()
	_siren.stream = streams.siren
	_siren.volume_db = -20.0
	_siren.bus = "Effects"
	add_child(_siren)


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	for p in _pool:
		if not p.playing:
			p.stream = streams[sound]
			p.global_position = pos
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


func play_ui(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	for u in _ui:
		if not u.playing:
			u.stream = streams[sound]
			u.volume_db = volume_db
			u.pitch_scale = pitch
			u.play()
			return


func start_ambience() -> void:
	if not _drone.playing:
		_drone.play()


func set_hunt_audio(active: bool) -> void:
	if active:
		play_ui("stinger")
		_heart.play()
	else:
		_heart.stop()


func set_siren(active: bool) -> void:
	if active:
		_siren.play()
	else:
		_siren.stop()


func stop_all_loops() -> void:
	_drone.stop()
	_heart.stop()
	_siren.stop()


func _build_streams() -> void:
	_rng.seed = 1234
	streams.step = _make(0.14, func(t): return _noise() * exp(-t * 40.0) * 0.5 + sin(t * 500.0) * exp(-t * 30.0) * 0.5)
	streams.door = _make(0.6, func(t): return sin(TAU * (160.0 + 90.0 * sin(t * 18.0)) * t) * 0.25 * exp(-t * 3.0) + _noise() * (0.7 * exp(-(t - 0.5) * 30.0) if t > 0.5 else 0.03))
	streams.slam = _make(0.4, func(t): return (_noise() * 0.8 + sin(TAU * 70.0 * t)) * exp(-t * 14.0))
	streams.knock = _make(0.5, func(t): return sin(TAU * 170.0 * t) * (exp(-t * 40.0) + (exp(-(t - 0.2) * 40.0) if t > 0.2 else 0.0)))
	streams.thump = _make(0.3, func(t): return sin(TAU * 90.0 * t) * exp(-t * 18.0) + _noise() * exp(-t * 50.0) * 0.4)
	streams.click = _make(0.05, func(t): return _noise() * exp(-t * 120.0))
	streams.beep = _make(0.18, func(t): return sign(sin(TAU * 1200.0 * t)) * 0.3)
	streams.alarm = _make(0.5, func(t): return sign(sin(TAU * (900.0 if fmod(t, 0.2) < 0.1 else 1400.0) * t)) * 0.3)
	streams.shutter = _make(0.2, func(t): return _noise() * (exp(-t * 70.0) + (exp(-(t - 0.1) * 70.0) if t > 0.1 else 0.0)))
	streams.whisper = _make(1.1, func(t): return _noise() * 0.5 * (0.5 + 0.5 * sin(t * 26.0)) * sin(PI * t / 1.1) * (0.5 + 0.5 * sin(TAU * 240.0 * t)))
	streams.static_loop = _make(1.0, func(_t): return _noise() * 0.35, true)
	streams.wail = _make(2.2, func(t): return sin(TAU * (420.0 + 70.0 * sin(t * 5.0) - t * 70.0) * t) * sin(PI * t / 2.2) * 0.5)
	streams.howl = _make(2.0, func(t): return (sin(TAU * (220.0 + 260.0 * sin(PI * t / 2.0)) * t) + 0.4 * _noise()) * sin(PI * t / 2.0) * 0.7)
	streams.flame = _make(0.5, func(t): return _noise() * 0.5 * exp(-t * 5.0))
	streams.stinger = _make(1.6, func(t): return (sin(TAU * 110.0 * t) + sin(TAU * 117.0 * t) + sin(TAU * 311.0 * t) * 0.6 + _noise() * 0.3) * exp(-t * 1.8) * 0.45)
	streams.scream = _make(1.2, func(t): return (sign(sin(TAU * (500.0 + 500.0 * t) * t)) * 0.4 + _noise() * 0.6) * exp(-t * 1.2))
	streams.capture = _make(1.4, func(t): return (sin(TAU * (300.0 + 800.0 * t) * t) * 0.5 + _noise() * 0.15) * exp(-t * 1.4))
	streams.siren = _make(2.0, func(t): return sin(TAU * (650.0 + 250.0 * sin(TAU * t / 2.0)) * t) * 0.45, true)
	streams.chatter = _make(0.5, func(t): return sin(TAU * (190.0 + 60.0 * sin(t * 40.0)) * t) * (0.5 + 0.5 * sin(t * 44.0)) * sin(PI * t / 0.5) * 0.6)
	streams.heartbeat = _make(0.8, func(t): return sin(TAU * 55.0 * t) * (exp(-t * 18.0) + (0.8 * exp(-(t - 0.22) * 18.0) if t > 0.22 else 0.0)), true)
	streams.drone = _make(4.0, func(t): return sin(TAU * 45.0 * t) * 0.5 + sin(TAU * 67.5 * t) * 0.25 * (0.6 + 0.4 * sin(TAU * t / 4.0)) + _noise() * 0.02, true)


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _make(duration: float, wave: Callable, loop := false) -> AudioStreamWAV:
	var frames := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var v: float = wave.call(float(i) / RATE)
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = frames
	return s
