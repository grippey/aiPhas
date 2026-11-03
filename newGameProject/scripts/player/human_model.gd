class_name HumanModel
extends Node3D
## A simple body shared by bystanders and other players, with walking and gestures.

var hand: Node3D
var holding_item := false
var on_phone := false

var _right_arm: Node3D
var _left_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _torso: Node3D
var _gesture := ""
var _gesture_time := 0.0
var _walk_phase := 0.0
var _walking := false


func build(shirt_color: Color) -> void:
	var shirt := Mk.mat(shirt_color, 0.8)
	var skin := Mk.mat(Color(randf_range(0.35, 0.85), randf_range(0.25, 0.6), randf_range(0.2, 0.45)), 0.7)
	var trousers := Mk.mat(Color(0.14, 0.15, 0.2), 0.8)
	_torso = Node3D.new()
	add_child(_torso)
	Mk.cyl(_torso, 0.17, 0.15, 0.62, Vector3(0, 1.12, 0), shirt)
	Mk.sphere(_torso, 0.13, Vector3(0, 1.58, 0), skin)
	var hair := Mk.sphere(_torso, 0.135, Vector3(0, 1.62, 0.02), Mk.mat(Color(randf_range(0.05, 0.5), randf_range(0.04, 0.3), randf_range(0.03, 0.2)), 0.9))
	hair.scale = Vector3(1.0, 0.8, 1.0)
	var eye := Mk.mat(Color(0.03, 0.03, 0.03), 0.3)
	Mk.sphere(_torso, 0.016, Vector3(-0.045, 1.6, -0.12), eye)
	Mk.sphere(_torso, 0.016, Vector3(0.045, 1.6, -0.12), eye)
	_left_leg = _limb(self, Vector3(-0.08, 0.82, 0), 0.82, 0.065, trousers)
	_right_leg = _limb(self, Vector3(0.08, 0.82, 0), 0.82, 0.065, trousers)
	_left_arm = _limb(_torso, Vector3(-0.22, 1.4, 0), 0.6, 0.05, shirt)
	_right_arm = _limb(_torso, Vector3(0.22, 1.4, 0), 0.6, 0.05, shirt)
	Mk.sphere(_left_arm, 0.055, Vector3(0, -0.62, 0), skin)
	Mk.sphere(_right_arm, 0.055, Vector3(0, -0.62, 0), skin)
	# Undoing the arm's lift keeps a held item pointing the way the body faces.
	hand = Node3D.new()
	hand.position = Vector3(0, -0.66, 0)
	hand.rotation.x = -PI / 2
	_right_arm.add_child(hand)


func _limb(parent: Node3D, pos: Vector3, length: float, radius: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	Mk.cyl(pivot, radius, radius * 0.85, length, Vector3(0, -length / 2.0, 0), material)
	return pivot


func gesture(kind: String, seconds := 1.8) -> void:
	_gesture = kind
	_gesture_time = seconds


func set_walking(walking: bool, speed := 1.5) -> void:
	_walking = walking
	if walking:
		_walk_phase += get_physics_process_delta_time() * speed * 4.5


func _process(delta: float) -> void:
	_gesture_time -= delta
	var t := Time.get_ticks_msec() * 0.001
	var right := Vector3(sin(_walk_phase) * 0.4, 0, 0) if _walking else Vector3.ZERO
	var left := Vector3(-sin(_walk_phase) * 0.4, 0, 0) if _walking else Vector3.ZERO
	if holding_item:
		right = Vector3(PI / 2, 0, 0)
	if on_phone:
		right = Vector3(2.5, 0, -0.7)
	var lean := 0.0
	if _gesture_time > 0.0:
		match _gesture:
			"wave":
				right = Vector3(2.7, 0, sin(t * 11.0) * 0.35)
			"cheer":
				right = Vector3(2.9, 0, 0.2)
				left = Vector3(2.9, 0, -0.2)
			"shake":
				right = Vector3(1.1, 0, sin(t * 9.0) * 0.5)
				left = Vector3(1.1, 0, -sin(t * 9.0) * 0.5)
			"thumbs_up":
				right = Vector3(1.4, 0, 0)
			"shrug":
				right = Vector3(0.9, 0, 0.8)
				left = Vector3(0.9, 0, -0.8)
			"point":
				right = Vector3(PI / 2, 0, 0)
			"salute":
				right = Vector3(2.4, 0, -0.9)
			"clap":
				right = Vector3(1.3, 0, -0.5 + sin(t * 18.0) * 0.25)
				left = Vector3(1.3, 0, 0.5 - sin(t * 18.0) * 0.25)
			"taunt":
				right = Vector3(1.4 + sin(t * 12.0) * 0.4, 0, 0)
				left = Vector3(1.4 - sin(t * 12.0) * 0.4, 0, 0)
			"dance":
				right = Vector3(2.4 + sin(t * 7.0) * 0.5, 0, 0.3)
				left = Vector3(2.4 - sin(t * 7.0) * 0.5, 0, -0.3)
				lean = sin(t * 7.0) * 0.14
	var blend := minf(delta * 10.0, 1.0)
	_right_arm.rotation = _right_arm.rotation.lerp(right, blend)
	_left_arm.rotation = _left_arm.rotation.lerp(left, blend)
	_torso.rotation.z = lerpf(_torso.rotation.z, lean, blend)
	var stride := sin(_walk_phase) * 0.45 if _walking else 0.0
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, stride, blend)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -stride, blend)
