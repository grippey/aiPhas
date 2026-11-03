class_name Door
extends StaticBody3D
## A hinged door. The body sits on the hinge, and the panel extends along local +X.
## Anything that changes a door goes through Net, so every player sees it.

const WIDTH := 1.4
const HEIGHT := 2.1
const MAX_PRINTS := 4

var index := -1
var swing := 1.0
var base_yaw := 0.0
var is_open := false
var _tween: Tween
var _locked_until := 0.0
var _lock_glow: MeshInstance3D
var _print_material: StandardMaterial3D
var _prints := 0
var _print_cooldown := 0.0


func setup(material: Material) -> void:
	Mk.box(self, Vector3(WIDTH, HEIGHT, 0.06), Vector3(WIDTH / 2.0, HEIGHT / 2.0, 0.0), material)
	var brass := Mk.mat(Color(0.7, 0.6, 0.3), 0.3)
	Mk.sphere(self, 0.04, Vector3(WIDTH - 0.2, 1.0, 0.06), brass)
	Mk.sphere(self, 0.04, Vector3(WIDTH - 0.2, 1.0, -0.06), brass)
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, 0.08)
	add_child(CollisionShapes.make(shape, Vector3(WIDTH / 2.0, HEIGHT / 2.0, 0.0)))
	_lock_glow = Mk.box(self, Vector3(0.1, 0.1, 0.09), Vector3(WIDTH - 0.2, 1.15, 0.0), Mk.mat(Color(0.2, 0.05, 0.05), 0.4, Color(1.0, 0.15, 0.1), 3.0))
	_lock_glow.visible = false


func is_locked() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _locked_until


func get_prompt() -> String:
	if is_locked():
		return "Door is jammed shut"
	return "Close door" if is_open else "Open door"


func interact(_player: Player) -> void:
	if is_locked():
		Game.toast.emit("It won't budge. Something is holding it shut.")
		Sfx.play_at("knock", global_position, -4.0, 1.4)
		return
	Net.door_open(self, not is_open, 0.35, "door")
	Net.noise(global_position, 9.0)


func set_open(value: bool, duration := 0.35) -> void:
	is_open = value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var yaw := base_yaw + (deg_to_rad(100.0) * swing if value else 0.0)
	_tween.tween_property(self, "rotation:y", yaw, duration).set_trans(Tween.TRANS_SINE)


func ghost_open() -> void:
	if not is_open:
		is_open = true
		Net.door_open(self, true, 0.25, "door")


func ghost_slam() -> void:
	is_open = not is_open
	Net.door_open(self, is_open, 0.12, "slam")


## Slams the door and holds it shut for a while. Used by the Warden.
func lock_for(seconds: float) -> void:
	is_open = false
	Net.door_open(self, false, 0.12, "slam")
	Net.door_lock(self, seconds)


func apply_lock(seconds: float) -> void:
	_locked_until = Time.get_ticks_msec() / 1000.0 + seconds
	_lock_glow.visible = true
	var timer := create_tween()
	timer.tween_interval(seconds)
	timer.tween_callback(func(): _lock_glow.visible = false)


## Leaves a handprint that only shows up under a UV Light.
func add_handprint() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _prints >= MAX_PRINTS or now < _print_cooldown:
		return
	_print_cooldown = now + 6.0
	var side := 1.0 if randf() < 0.5 else -1.0
	var pos := Vector3(randf_range(0.5, 1.1), randf_range(0.9, 1.5), side * 0.033)
	Net.door_print(self, pos, randf_range(-0.6, 0.6))


func apply_handprint(pos: Vector3, angle: float) -> void:
	_prints += 1
	if _print_material == null:
		_print_material = Mk.mat(Color(0.5, 1.0, 0.7), 0.9, Color(0.35, 1.0, 0.6), 2.5)
		_print_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hand := Node3D.new()
	hand.position = pos
	hand.rotation.z = angle
	hand.add_to_group("handprints")
	hand.visible = false
	add_child(hand)
	Mk.box(hand, Vector3(0.09, 0.1, 0.002), Vector3.ZERO, _print_material)
	for f in 4:
		Mk.box(hand, Vector3(0.016, 0.075, 0.002), Vector3(-0.033 + f * 0.022, 0.085, 0.0), _print_material)
	var thumb := Mk.box(hand, Vector3(0.016, 0.06, 0.002), Vector3(0.06, 0.01, 0.0), _print_material)
	thumb.rotation.z = -0.7
