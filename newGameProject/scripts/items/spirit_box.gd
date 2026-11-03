extends Item
## Sweeps radio static. A ghost with the Spirit Box evidence answers if you are
## close. It is loud, though, and a Howler will hear it.

const HEAR_RANGE := 7.5
const QUESTION_INTERVAL := 5.0

var on := false
var _static: AudioStreamPlayer3D
var _timer := 0.0
var _dial: StandardMaterial3D


func _define() -> void:
	net_props = ["on"]
	item_id = "spirit_box"
	display_name = "Spirit Box"
	description = "LMB: on/off. Listen close to the ghost."
	hand_rotation = Vector3(0.3, 0, 0)
	collider_size = Vector3(0.17, 0.12, 0.06)
	collider_center = Vector3(0, 0.06, 0)


func _build() -> void:
	Mk.box(self, Vector3(0.16, 0.1, 0.05), Vector3(0, 0.05, 0), Mk.mat(Color(0.25, 0.14, 0.1), 0.6))
	Mk.box(self, Vector3(0.1, 0.05, 0.005), Vector3(-0.02, 0.05, -0.026), Mk.mat(Color(0.05, 0.05, 0.05), 0.8))
	_dial = Mk.mat(Color(0.2, 0.2, 0.2), 0.5, Color(1.0, 0.65, 0.2), 0.0)
	Mk.box(self, Vector3(0.022, 0.03, 0.006), Vector3(0.055, 0.05, -0.027), _dial)
	var antenna := Mk.cyl(self, 0.003, 0.005, 0.2, Vector3(0.065, 0.19, 0), Mk.mat(Color(0.7, 0.7, 0.7), 0.2))
	antenna.rotation.z = -0.25
	_static = AudioStreamPlayer3D.new()
	_static.stream = Sfx.streams.static_loop
	_static.volume_db = -14.0
	_static.unit_size = 3.0
	_static.bus = "Effects"
	add_child(_static)


func _process(delta: float) -> void:
	if not on:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = QUESTION_INTERVAL * randf_range(0.8, 1.3)
	Game.make_noise(global_position, 9.0)
	var ghost := Game.ghost
	if ghost != null and ghost.has_evidence(GhostDB.Ev.SPIRIT_BOX) and ghost.global_position.distance_to(global_position) < HEAR_RANGE and randf() < 0.65:
		Sfx.play_ui("whisper", 2.0, randf_range(0.7, 1.0))
		Game.subtitle.emit("\"%s\"" % ghost.spirit_reply())
		Game.change_sanity(-2.5)


func _set_on(value: bool) -> void:
	on = value
	_timer = 2.0
	_dial.emission_energy_multiplier = 3.0 if value else 0.0
	if value:
		_static.play()
	else:
		_static.stop()


func use() -> void:
	_set_on(not on)
	Sfx.play_ui("click", -6.0, 0.8)


func _on_stowed(stowed: bool) -> void:
	if stowed:
		_set_on(false)


func status_text() -> String:
	return "Listening..." if on else "Off"


func is_bait_on() -> bool:
	return on


func _on_net_state() -> void:
	_set_on(on)
