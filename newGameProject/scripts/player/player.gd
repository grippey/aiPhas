class_name Player
extends Actor
## The local first-person controller: movement, the hotbar, interaction and hiding.

const WALK_SPEED := 2.6
const SPRINT_SPEED := 4.5
const CROUCH_SPEED := 1.2
const STAND_EYES := 1.6
const CROUCH_EYES := 0.95
const REACH := 2.6
const MOUSE_SENSITIVITY := 0.0022
const RAY_MASK := 1 | 4

var emotes: EmoteRig
var focus: Object = null
var focus_prompt := ""
var stamina := 1.0
var hiding_in: Wardrobe = null
var hidden_safe := false
var spectating: Actor = null

var _eye_camera: Camera3D
var _exit_position := Vector3.ZERO
var _collider: CollisionShape3D
var _step_timer := 0.0
var _bob := 0.0
var _scare_target: Ghost = null


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.75
	_collider = CollisionShapes.make(shape, Vector3(0, 0.875, 0))
	add_child(_collider)

	_eye_camera = Camera3D.new()
	_eye_camera.position = Vector3(0, STAND_EYES, 0)
	_eye_camera.fov = Settings.fov
	_eye_camera.near = 0.03
	camera = _eye_camera
	add_child(_eye_camera)
	_eye_camera.current = true
	Settings.changed.connect(func(): _eye_camera.fov = Settings.fov)

	hand = Node3D.new()
	hand.position = Vector3(0.3, -0.27, -0.6)
	camera.add_child(hand)

	emotes = EmoteRig.new()
	emotes.setup(self)
	camera.add_child(emotes)


func _unhandled_input(event: InputEvent) -> void:
	if Game.input_locked or Game.over or Game.emote_wheel_open or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	sanity = Game.sanity
	if _scare_target != null:
		_face_scare(delta)
		return
	if dead:
		_spectate()
		return
	if Game.over or Game.waiting_for_players:
		return
	_update_sanity(delta)
	_update_focus()
	if hiding_in != null:
		velocity = Vector3.ZERO
		if _pressed("interact"):
			exit_hiding()
		return
	_move(delta)
	if Game.input_locked:
		return
	if _pressed("interact") and focus != null:
		focus.interact(self)
	if _pressed("use_item") and active_item() != null and emotes.current == "":
		active_item().use()
		active_item().net_push()
	if _pressed("drop_item") and active_item() != null:
		place_active()
	for i in SLOTS:
		if _pressed("slot_%d" % (i + 1)):
			select_slot(i)
	if Input.is_action_just_pressed("slot_next"):
		select_slot((active_slot + 1) % SLOTS)
	if Input.is_action_just_pressed("slot_prev"):
		select_slot((active_slot + SLOTS - 1) % SLOTS)


func _pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)


func net_flags() -> int:
	var flags := 0
	if crouching:
		flags |= FLAG_CROUCH
	if hiding_in != null:
		flags |= FLAG_HIDING
	if hidden_safe:
		flags |= FLAG_SAFE
	return flags


func _move(delta: float) -> void:
	var dir := Vector2.ZERO
	if not Game.input_locked:
		dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		crouching = Input.is_action_pressed("crouch")
	var moving := dir.length() > 0.1
	var sprinting := moving and Input.is_action_pressed("sprint") and not crouching and stamina > 0.05 and not Game.input_locked
	stamina = clampf(stamina + (-delta / 6.0 if sprinting else delta / 9.0), 0.0, 1.0)

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	var wish := (transform.basis * Vector3(dir.x, 0.0, dir.y)).normalized()
	velocity.x = move_toward(velocity.x, wish.x * speed, delta * 22.0)
	velocity.z = move_toward(velocity.z, wish.z * speed, delta * 22.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 14.0 * delta
	move_and_slide()

	var eyes := CROUCH_EYES if crouching else STAND_EYES
	if moving and is_on_floor():
		_bob += delta * speed * 3.2
		_step_timer -= delta * speed
		if _step_timer <= 0.0:
			_step_timer = 1.6
			Sfx.play_ui("step", -24.0 if crouching else (-10.0 if sprinting else -17.0), randf_range(0.9, 1.1))
			if sprinting:
				Net.noise(global_position, 14.0)
			elif not crouching:
				Net.noise(global_position, 4.5)
	camera.position.y = lerpf(camera.position.y, eyes + sin(_bob) * 0.022, delta * 10.0)


func _update_sanity(delta: float) -> void:
	if not Game.player_in_house():
		if hiding_in == null:
			Game.change_sanity(delta * 0.5)
		return
	var room := Game.house.room_at(global_position)
	var lit := room != null and room.on
	for item in get_tree().get_nodes_in_group("candles"):
		if item.lit and item.global_position.distance_to(global_position) < 4.0:
			lit = true
	Game.change_sanity(-delta * (0.08 if lit else 0.22))


func _update_focus() -> void:
	focus = null
	focus_prompt = ""
	if Game.input_locked:
		return
	if hiding_in != null:
		focus_prompt = "[E] Leave wardrobe"
		return
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col.has_method("interact"):
		var prompt: String = col.get_prompt()
		if prompt != "":
			focus = col
			focus_prompt = "[E] %s" % prompt


func play_emote(id: String) -> void:
	if hiding_in == null and not Game.over and not dead:
		emotes.play(id)


func select_slot(index: int) -> void:
	if index != active_slot:
		Net.select_slot(index)
		Sfx.play_ui("click", -8.0)


func pick_up(item: Item) -> void:
	Net.request_pickup(item)


func _after_take() -> void:
	Sfx.play_ui("click", -6.0)


func place_active() -> void:
	var item := active_item()
	var spot: Variant = aim_floor_point()
	if spot == null:
		Game.toast.emit("There's no room to set that down here.")
		return
	Net.place_item(item, spot)
	Sfx.play_at("thump", spot, -14.0)


## Finds a surface to set something down on, in front of the player.
func aim_floor_point() -> Variant:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + forward * REACH, 1, [get_rid()])
	var hit := space.intersect_ray(q)
	var start: Vector3 = from + forward * minf(REACH, 1.2)
	if not hit.is_empty():
		if hit.normal.y > 0.6:
			return hit.position
		start = hit.position + hit.normal * 0.25
	var down := PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * 4.0, 1, [get_rid()])
	var floor_hit := space.intersect_ray(down)
	return floor_hit.position if not floor_hit.is_empty() else null


func enter_hiding(wardrobe: Wardrobe) -> void:
	hidden_safe = not (Game.hunting and Game.ghost.can_see(self))
	hiding_in = wardrobe
	_exit_position = global_position
	_collider.disabled = true
	global_position = wardrobe.global_position - Vector3(0, 1.0, 0)
	velocity = Vector3.ZERO
	camera.position.y = STAND_EYES
	if active_item() != null:
		active_item().visible = false


func exit_hiding() -> void:
	global_position = _exit_position
	_collider.disabled = false
	hiding_in = null
	hidden_safe = false
	if active_item() != null:
		active_item().visible = true
	Net.sfx_all("door", global_position, -8.0)
	Net.noise(global_position, 5.0)


func is_hidden() -> bool:
	return hiding_in != null and hidden_safe


func is_hiding() -> bool:
	return hiding_in != null


func jumpscare(by: Ghost) -> void:
	_scare_target = by
	hand.visible = false
	if hiding_in != null:
		hiding_in = null
		hidden_safe = false
	_collider.disabled = true
	var timer := get_tree().create_timer(1.3, true)
	timer.timeout.connect(func(): _scare_target = null)


func _face_scare(delta: float) -> void:
	var look: Vector3 = _scare_target.global_position + Vector3(0, _scare_target.data.height * 0.85, 0)
	var eye_target := camera.global_transform.looking_at(look, Vector3.UP)
	camera.global_transform.basis = camera.global_transform.basis.slerp(eye_target.basis, clampf(delta * 12.0, 0.0, 1.0))


## Caught players watch through a living player's eyes. Click to switch who.
func _spectate() -> void:
	var living := Game.living_actors()
	if living.is_empty():
		return
	if spectating == null or not is_instance_valid(spectating) or spectating.dead:
		spectating = living[0]
	if Input.is_action_just_pressed("use_item") and not Game.input_locked:
		spectating = living[(living.find(spectating) + 1) % living.size()]
	camera.global_transform = spectating.camera.global_transform
