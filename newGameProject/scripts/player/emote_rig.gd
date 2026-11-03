class_name EmoteRig
extends Node3D
## First-person emotes: animated arms in front of the camera. Other players see the
## matching gesture on your body, and the host works out what it does to the world.

const EMOTES := [
	{"id": "wave", "name": "Wave", "time": 1.6},
	{"id": "thumbs_up", "name": "Thumbs Up", "time": 1.3},
	{"id": "shrug", "name": "Shrug", "time": 1.4},
	{"id": "point", "name": "Point", "time": 1.3},
	{"id": "salute", "name": "Salute", "time": 1.4},
	{"id": "clap", "name": "Clap", "time": 1.7},
	{"id": "taunt", "name": "Taunt", "time": 1.8},
	{"id": "dance", "name": "Dance", "time": 3.0},
]

const SHOULDER_R := Vector3(0.3, -0.55, -0.1)
const SHOULDER_L := Vector3(-0.3, -0.55, -0.1)
const REST_R := Vector3(0.4, -0.8, -0.35)
const REST_L := Vector3(-0.4, -0.8, -0.35)
const DANCE_SANITY := 3.0
const DANCE_COOLDOWN := 25.0

var current := ""
var _time := 0.0
var _duration := 0.0
var _last_clap := -1
var _last_dance := -100.0
var _player: Player
var _right_arm: Node3D
var _left_arm: Node3D
var _right_hand: Node3D
var _left_hand: Node3D
var _finger: Node3D
var _thumb: Node3D


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	var sleeve := Mk.mat(Color(0.16, 0.2, 0.22), 0.8)
	var skin := Mk.mat(Color(0.65, 0.48, 0.36), 0.7)
	_right_arm = _make_arm(sleeve)
	_left_arm = _make_arm(sleeve)
	_right_hand = _make_hand(skin)
	_left_hand = _make_hand(skin)
	_finger = Mk.cyl(_right_hand, 0.011, 0.014, 0.1, Vector3(0, 0, -0.08), skin)
	_finger.rotation.x = PI / 2
	_thumb = Mk.cyl(_right_hand, 0.013, 0.017, 0.09, Vector3(0, 0.07, 0), skin)
	visible = false
	set_process(false)


func _make_arm(material: Material) -> Node3D:
	var arm := Node3D.new()
	add_child(arm)
	Mk.cyl(arm, 0.024, 0.036, 1.0, Vector3.ZERO, material)
	return arm


func _make_hand(material: Material) -> Node3D:
	var hand := Node3D.new()
	add_child(hand)
	var palm := Mk.sphere(hand, 0.038, Vector3.ZERO, material)
	palm.scale = Vector3(0.9, 1.1, 0.6)
	return hand


func play(id: String) -> void:
	if current != "":
		return
	var duration := 1.5
	for e in EMOTES:
		if e.id == id:
			duration = e.time
	current = id
	_time = 0.0
	_duration = duration
	_last_clap = -1
	_finger.visible = id == "point" or id == "taunt"
	_thumb.visible = id == "thumbs_up"
	visible = true
	set_process(true)
	_player.hand.visible = false
	Net.emote(id)
	if id == "taunt":
		Sfx.play_ui("whisper", -6.0, 1.4)
	if id == "dance":
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_dance > DANCE_COOLDOWN:
			_last_dance = now
			Game.change_sanity(DANCE_SANITY)


func _process(delta: float) -> void:
	_time += delta
	if _time >= _duration:
		_finish()
		return
	var blend := minf(minf(_time, _duration - _time) / 0.18, 1.0)
	var pose := _pose(current, _time)
	_set_arm(_right_arm, _right_hand, SHOULDER_R, REST_R.lerp(pose[0], blend))
	_set_arm(_left_arm, _left_hand, SHOULDER_L, REST_L.lerp(pose[1], blend))
	if current == "dance":
		_player.camera.rotation.z = sin(_time * 7.0) * 0.05 * blend
	if current == "clap":
		var beat := int(_time * 5.0)
		if beat != _last_clap and fmod(_time * 5.0, 1.0) > 0.5:
			_last_clap = beat
			Sfx.play_ui("click", 2.0, 0.7)


func _finish() -> void:
	current = ""
	visible = false
	set_process(false)
	_player.camera.rotation.z = 0.0
	if _player.hiding_in == null:
		_player.hand.visible = true


## Hand positions for each emote, in camera space: [right, left].
func _pose(id: String, t: float) -> Array:
	match id:
		"wave":
			return [Vector3(0.24 + sin(t * 11.0) * 0.08, 0.04, -0.5), REST_L]
		"thumbs_up":
			return [Vector3(0.1, -0.12 + sin(t * 4.0) * 0.012, -0.4), REST_L]
		"shrug":
			var lift := 0.06 * sin(t * 5.0)
			return [Vector3(0.34, -0.2 + lift, -0.45), Vector3(-0.34, -0.2 + lift, -0.45)]
		"point":
			return [Vector3(0.1, -0.08, -0.52), REST_L]
		"salute":
			return [Vector3(0.16, 0.12, -0.24), REST_L]
		"clap":
			var gap := 0.025 + absf(sin(t * PI * 5.0)) * 0.11
			return [Vector3(gap, -0.1, -0.42), Vector3(-gap, -0.1, -0.42)]
		"taunt":
			var beckon := sin(t * 12.0) * 0.05
			return [Vector3(0.14, -0.08 + beckon, -0.48), Vector3(-0.14, -0.08 - beckon, -0.48)]
		"dance":
			var swing := sin(t * 7.0)
			return [Vector3(0.22 + swing * 0.12, 0.02 + cos(t * 14.0) * 0.06, -0.45), Vector3(-0.22 + swing * 0.12, -0.02 - cos(t * 14.0) * 0.06, -0.45)]
	return [REST_R, REST_L]


func _set_arm(arm: Node3D, hand: Node3D, shoulder: Vector3, target: Vector3) -> void:
	var span := target - shoulder
	arm.position = (shoulder + target) / 2.0
	arm.basis = Basis(Quaternion(Vector3.UP, span.normalized()))
	arm.scale = Vector3(1.0, span.length(), 1.0)
	hand.position = target
