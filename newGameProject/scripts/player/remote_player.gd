class_name RemotePlayer
extends Actor
## Another player, drawn as a body with their nickname and moved by network updates.

const SMOOTHING := 14.0

var _model: HumanModel
var _label: Label3D
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0
var _hiding := false
var _safe := false
var _step_timer := 0.0


func _ready() -> void:
	# Players pass through each other, so nobody can be body-blocked into a ghost.
	collision_layer = 0
	collision_mask = 0
	_target_pos = global_position

	var hue := fposmod(float(peer_id) * 0.618, 1.0)
	_model = HumanModel.new()
	add_child(_model)
	_model.build(Color.from_hsv(hue, 0.55, 0.6))
	hand = _model.hand

	camera = Node3D.new()
	camera.position = Vector3(0, 1.6, 0)
	add_child(camera)

	_label = Label3D.new()
	_label.text = nickname
	_label.position = Vector3(0, 2.0, 0)
	_label.font_size = 32
	_label.pixel_size = 0.004
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)


func apply_net_state(pos: Vector3, yaw: float, pitch: float, flags: int, net_sanity: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_target_pitch = pitch
	crouching = flags & FLAG_CROUCH != 0
	_hiding = flags & FLAG_HIDING != 0
	_safe = flags & FLAG_SAFE != 0
	sanity = net_sanity


func _physics_process(delta: float) -> void:
	var before := global_position
	var blend := minf(delta * SMOOTHING, 1.0)
	global_position = global_position.lerp(_target_pos, blend)
	rotation.y = lerp_angle(rotation.y, _target_yaw, blend)
	camera.rotation.x = lerp_angle(camera.rotation.x, _target_pitch, blend)
	camera.position.y = 0.95 if crouching else 1.6

	var speed := (global_position - before).length() / maxf(delta, 0.001)
	_model.set_walking(speed > 0.3, speed)
	_model.scale.y = 0.7 if crouching else 1.0
	_model.holding_item = active_item() != null
	_model.visible = not _hiding and not dead
	_label.visible = not _hiding and not dead
	if speed > 0.3 and not _hiding:
		_step_timer -= delta * speed
		if _step_timer <= 0.0:
			_step_timer = 1.6
			Sfx.play_at("step", global_position, -6.0 if not crouching else -16.0)


func is_hidden() -> bool:
	return _hiding and _safe


func is_hiding() -> bool:
	return _hiding


func on_emote(id: String) -> void:
	var time := 1.5
	for e in EmoteRig.EMOTES:
		if e.id == id:
			time = e.time
	_model.gesture(id, time)
