class_name Ghost
extends Node3D
## Shared ghost brain. The four generic stats drive it:
##   speed          - metres per second while hunting (roaming uses a fraction of it)
##   aggressiveness - when it may hunt, how often, and how soon it hunts again
##   passiveness    - how long it rests, how home-bound it is, how quickly it gives up
##   activeness     - how often it interacts with the house
## Each subclass overrides the virtual methods below to give it distinct behaviour.
## The brain only runs on the host. Other players' copies follow network updates.

enum State { IDLE, ROAM, HUNT, STUNNED, PINNED, CAPTURED }

const CATCH_DISTANCE := 1.05
const SIGHT_RANGE := 16.0
const HUNT_WINDUP := 3.0

var data: Dictionary
var speed := 1.5
var aggressiveness := 0.5
var passiveness := 0.5
var activeness := 0.5

var state := State.IDLE
var home_room: Room
var current_room: Room
var use_navigation := true
var hunt_length_multiplier := 1.0
var smudge_block := 60.0
## The living player the ghost is paying attention to. Set by the host each frame.
var target: Actor

## -1: normal, 0: force hidden, 1: force visible. The camera sets this for one frame.
var film_override := -1
## Whether the host wants the figure drawn. Each player then applies filter_visibility.
var net_wanted := false

var _visual: Node3D
var _material: ShaderMaterial
var _path := PackedVector3Array()
var _path_index := 0
var _state_time := 0.0
var _activity_timer := 10.0
var _hunt_check_timer := 6.0
var _hunt_cooldown := 0.0
var _hunt_block := 0.0
var _hunt_left := 0.0
var _hunt_elapsed := 0.0
var _windup := 0.0
var _lost_time := 0.0
var _repath := 0.0
var _step_timer := 0.0
var _last_known := Vector3.ZERO
var _last_event_pos := Vector3.ZERO
var _last_event_time := -100.0
var _reveal_time := 0.0
var _pin_refresh := 0.0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0


func setup(type_data: Dictionary, room: Room) -> void:
	data = type_data
	speed = data.speed
	aggressiveness = data.aggressiveness
	passiveness = data.passiveness
	activeness = data.activeness
	home_room = room
	current_room = room
	_configure()


func _ready() -> void:
	_build_visual()
	_net_pos = global_position
	_net_yaw = rotation.y
	if not Net.is_host():
		return
	_enter_idle()
	# The nav map only updates on physics frames, so wait for it before snapping.
	var map := get_world_3d().navigation_map
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await get_tree().physics_frame
	if use_navigation:
		_snap_to_walkable_floor()


# --- Virtuals -------------------------------------------------------------

## Set per-type constants here.
func _configure() -> void:
	pass


## Runs every physics frame while the ghost is free to act.
func _on_tick(_delta: float) -> void:
	pass


func _on_hunt_started() -> void:
	pass


## Whether its personal rules allow a hunt right now.
func can_hunt() -> bool:
	return target.sanity < lerpf(15.0, 85.0, aggressiveness)


func default_roam_target() -> Vector3:
	if randf() < passiveness:
		return home_room.random_point()
	return Game.house.rooms.pick_random().random_point()


func idle_duration() -> float:
	return lerpf(2.0, 18.0, passiveness) * randf_range(0.7, 1.3)


func roam_speed() -> float:
	return speed * 0.55


func hunt_speed() -> float:
	return speed


## Multiplies all movement. The Watcher sets it to 0 while it is being looked at.
func movement_multiplier() -> float:
	return 1.0


## During a hunt: returns true and updates _last_known if it knows where someone is.
func update_hunt_target() -> bool:
	for actor in Game.living_actors():
		if can_see(actor):
			_last_known = actor.global_position
			return true
	return false


func can_catch_now() -> bool:
	return true


func lose_interest_time() -> float:
	return lerpf(14.0, 3.0, passiveness)


func wants_visible() -> bool:
	return false


func can_be_lured(_trap: Item) -> bool:
	return true


## Gets the final say on whether the figure is drawn. The Pallid hides here.
func filter_visibility(wanted: bool) -> bool:
	return wanted


func step_volume() -> float:
	return 8.0


## Extra state for the other players' copies. The Changeling sends who it's copying.
func net_extra() -> String:
	return ""


func apply_net_extra(_value: String) -> void:
	pass


func do_activity() -> void:
	var roll := randf()
	if roll < 0.3:
		act_door()
	elif roll < 0.55:
		act_flicker()
	elif roll < 0.75:
		act_throw(false)
	elif roll < 0.9:
		act_knock()
	else:
		act_manifest()


func temperature_for(room: Room) -> float:
	var freezing := has_evidence(GhostDB.Ev.FREEZING)
	if room == home_room:
		return -3.0 if freezing else 6.0
	if room == current_room:
		return 2.0 if freezing else 9.0
	return 13.0


func spirit_lines() -> Array:
	return ["Leave.", "Behind you.", "Here.", "Get out.", "I see you."]


## Called when it hears something. Only the Howler cares.
func hear(_pos: Vector3, _radius: float) -> void:
	pass


# --- Public API -----------------------------------------------------------

func has_evidence(e: int) -> bool:
	return e in data.evidence


func spirit_reply() -> String:
	return spirit_lines().pick_random()


func emf_level_at(pos: Vector3) -> int:
	var d := global_position.distance_to(pos)
	var recent: bool = _now() - _last_event_time < 8.0 and _last_event_pos.distance_to(pos) < 6.0
	if (d < 4.0 or recent) and has_evidence(GhostDB.Ev.EMF):
		return 5
	if recent:
		return 4
	if d < 5.0:
		return 3
	if d < 9.0:
		return 2
	return 1


## Whether the ghost's trap conditions are met. Item subclasses do the checking.
func bait_active(trap: Item) -> bool:
	for item in Game.items:
		if item.item_id == data.bait and item.bait_works(self, trap):
			return true
	return false


func pin(_trap: Item) -> void:
	_pin_refresh = 0.25
	if state == State.PINNED:
		return
	if state == State.HUNT:
		Game.set_hunting(false)
		_hunt_cooldown = 20.0
	state = State.PINNED
	_reveal_time = 0.0


func captured() -> void:
	state = State.CAPTURED
	_visual.visible = true
	var trap := Game.placed_trap()
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if trap != null:
		t.tween_property(self, "global_position", trap.global_position, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func stun(duration: float) -> void:
	if state == State.HUNT:
		_end_hunt()
	state = State.STUNNED
	_state_time = duration
	_path = PackedVector3Array()


## Smudge smoke reached the ghost. Returns true once the smoke has had its effect.
func on_smudged() -> bool:
	if state == State.PINNED or state == State.CAPTURED:
		return false
	_hunt_block = smudge_block
	if state == State.HUNT:
		stun(4.0)
		Net.toast_all("The smoke drives it back!")
	return true


## A taunt from a player. The ghost shows itself and gets closer to hunting.
func provoke() -> void:
	act_manifest()
	act_knock()
	_hunt_check_timer = 0.0
	_hunt_cooldown = maxf(_hunt_cooldown - 20.0, 0.0)


func force_hunt() -> void:
	if state != State.HUNT and state != State.CAPTURED and target_in_house():
		_start_hunt()


func target_in_house() -> bool:
	return Game.actor_in_house(target)


func can_see(actor: Actor) -> bool:
	if not Game.actor_in_house(actor) or actor.is_hidden() or actor.dead:
		return false
	var eye := global_position + Vector3(0, 1.5, 0)
	var head := actor.camera.global_position
	var range_limit := SIGHT_RANGE * (0.55 if actor.crouching else 1.0)
	var d := eye.distance_to(head)
	if d < 2.0:
		return true
	return d < range_limit and _clear_line(eye, head)


## True if this actor has line of sight and is aiming within cone_degrees of the ghost.
func in_view_of(actor: Actor, cone_degrees: float, max_range: float) -> bool:
	if actor == null or actor.is_hidden() or actor.dead:
		return false
	var cam := actor.camera
	var from := cam.global_position
	var aim := global_position + Vector3(0, data.height * 0.6, 0)
	var to_me := aim - from
	if to_me.length() > max_range:
		return false
	if rad_to_deg((-cam.global_transform.basis.z).angle_to(to_me)) > cone_degrees:
		return false
	return _clear_line(from, aim)


func seen_by_anyone(cone_degrees: float, max_range: float) -> bool:
	for actor in Game.living_actors():
		if in_view_of(actor, cone_degrees, max_range):
			return true
	return false


## Whether any player's active item of this kind has its beam on the ghost.
func beam_on_me(item_id: String) -> bool:
	for actor in Game.living_actors():
		var item := actor.active_item()
		if item != null and item.item_id == item_id and item.is_on_ghost(self):
			return true
	return false


# --- Network copies -------------------------------------------------------

func apply_net_state(pos: Vector3, yaw: float, net_state: int, wanted: bool, home: int, extra: String) -> void:
	_net_pos = pos
	_net_yaw = yaw
	if state != State.CAPTURED:
		state = net_state as State
	net_wanted = wanted
	var room := Game.room(home)
	if room != null:
		home_room = room
	apply_net_extra(extra)


func apply_event(pos: Vector3) -> void:
	_last_event_pos = pos
	_last_event_time = _now()


func _tick_copy(delta: float) -> void:
	if state == State.CAPTURED:
		return
	var blend := minf(delta * 12.0, 1.0)
	global_position = global_position.lerp(_net_pos, blend)
	rotation.y = lerp_angle(rotation.y, _net_yaw, blend)
	current_room = Game.house.room_at(global_position)
	if current_room == null:
		current_room = home_room


# --- State machine --------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not Net.is_host():
		_tick_copy(delta)
		_show_visual()
		return
	_pick_target()
	_update_visual()
	if Game.over or state == State.CAPTURED or target == null or Game.waiting_for_players:
		return
	current_room = Game.house.room_at(global_position)
	if current_room == null:
		current_room = home_room
	_hunt_cooldown = maxf(_hunt_cooldown - delta, 0.0)
	_hunt_block = maxf(_hunt_block - delta, 0.0)
	_reveal_time = maxf(_reveal_time - delta, 0.0)

	if state != State.PINNED and state != State.STUNNED:
		_on_tick(delta)
		_activity_timer -= delta
		if _activity_timer <= 0.0:
			_activity_timer = lerpf(30.0, 5.0, activeness) * randf_range(0.7, 1.3)
			do_activity()

	match state:
		State.IDLE:
			_state_time -= delta
			_check_hunt(delta)
			if _state_time <= 0.0:
				_enter_roam()
		State.ROAM:
			_check_hunt(delta)
			if _step_path(delta, roam_speed() * movement_multiplier()):
				_enter_idle()
		State.HUNT:
			_tick_hunt(delta)
		State.STUNNED:
			_state_time -= delta
			if _state_time <= 0.0:
				_enter_roam()
		State.PINNED:
			_pin_refresh -= delta
			if _pin_refresh <= 0.0:
				_enter_roam()


## Prefers the closest living player inside the house, then the closest anywhere.
func _pick_target() -> void:
	var best: Actor = null
	var best_score := INF
	for actor in Game.living_actors():
		var score := actor.global_position.distance_to(global_position)
		if not Game.actor_in_house(actor):
			score += 1000.0
		if score < best_score:
			best_score = score
			best = actor
	target = best


func _enter_idle() -> void:
	state = State.IDLE
	_state_time = idle_duration()


func _enter_roam() -> void:
	state = State.ROAM
	_go_to(_pick_roam_target())


func _pick_roam_target() -> Vector3:
	var trap := Game.placed_trap()
	if trap != null and trap.burnout <= 0.0 and can_be_lured(trap):
		if randf() < (0.85 if bait_active(trap) else 0.35):
			return trap.global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	return default_roam_target()


func _check_hunt(delta: float) -> void:
	_hunt_check_timer -= delta
	if _hunt_check_timer > 0.0:
		return
	_hunt_check_timer = 6.0
	if not target_in_house() or Game.time_inside < Game.INSIDE_GRACE:
		return
	if _hunt_cooldown > 0.0 or _hunt_block > 0.0 or not can_hunt():
		return
	var calm := target.sanity / 100.0
	if randf() < lerpf(0.05, 0.6, aggressiveness) * (1.2 - calm):
		_start_hunt()


func _start_hunt() -> void:
	state = State.HUNT
	_windup = HUNT_WINDUP
	_hunt_left = lerpf(50.0, 16.0, passiveness) * hunt_length_multiplier
	_hunt_elapsed = 0.0
	_lost_time = 0.0
	_repath = 0.0
	_last_known = global_position
	_path = PackedVector3Array()
	Game.set_hunting(true)
	Game.add_commotion(5.0)
	_on_hunt_started()


func _end_hunt() -> void:
	Game.set_hunting(false)
	_hunt_cooldown = lerpf(150.0, 40.0, aggressiveness)


func _tick_hunt(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		return
	_hunt_left -= delta
	_hunt_elapsed += delta
	var knows := update_hunt_target()
	_lost_time = 0.0 if knows else _lost_time + delta
	if _hunt_left <= 0.0 or _lost_time > lose_interest_time():
		_end_hunt()
		_enter_roam()
		return

	_repath -= delta
	if _repath <= 0.0 and knows:
		_repath = 0.35
		_go_to(_last_known)
	var multiplier := movement_multiplier()
	var arrived := _step_path(delta, hunt_speed() * multiplier)
	if arrived and not knows:
		_go_to(current_room.random_point() if randf() < 0.6 else Game.house.rooms.pick_random().random_point())

	if multiplier > 0.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.48
			Net.sfx_all("step", global_position, step_volume(), 0.6)

	if not can_catch_now():
		return
	for actor in Game.living_actors():
		var gap := Vector2(global_position.x, global_position.z).distance_to(Vector2(actor.global_position.x, actor.global_position.z))
		if gap < CATCH_DISTANCE and Game.actor_in_house(actor) and not actor.is_hidden():
			_reveal_time = 5.0
			Game.player_caught(actor)


# --- Movement -------------------------------------------------------------

## Furniture interiors bake as small unreachable islands. Pathing here from the
## front door ends on the connected floor nearest the ghost's spawn point.
func _snap_to_walkable_floor() -> void:
	var map := get_world_3d().navigation_map
	var inside := Game.house.nav_point(Game.house.entrance)
	var path := NavigationServer3D.map_get_path(map, inside, Game.house.nav_point(global_position), true)
	if path.size() > 0:
		global_position = path[path.size() - 1]
		global_position.y = 0.0


func _go_to(destination: Vector3) -> void:
	destination.y = 0.0
	if use_navigation:
		var map := get_world_3d().navigation_map
		var from := Game.house.nav_point(global_position)
		_path = NavigationServer3D.map_get_path(map, from, Game.house.nav_point(destination), true)
	else:
		_path = PackedVector3Array([destination])
	_path_index = 0


## Moves along the path, and returns true on arrival.
func _step_path(delta: float, step_speed: float) -> bool:
	if _path_index >= _path.size():
		return true
	if step_speed <= 0.0:
		return false
	var remaining := step_speed * delta
	while remaining > 0.0 and _path_index < _path.size():
		var next := _path[_path_index]
		next.y = 0.0
		var to_next := next - global_position
		var dist := to_next.length()
		if dist <= remaining:
			global_position = next
			remaining -= dist
			_path_index += 1
		else:
			var dir := to_next / dist
			global_position += dir * remaining
			remaining = 0.0
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(delta * 8.0, 1.0))
	if _pushed_out_of_ward():
		return true
	if use_navigation:
		var door := Game.house.nearest_door(global_position, 1.0)
		if door != null:
			door.ghost_open()
			_touch(door)
	return false


## Iron stakes keep every ghost out of their ring. Returns true if one pushed it.
func _pushed_out_of_ward() -> bool:
	for stake in get_tree().get_nodes_in_group("iron_wards"):
		var away: Vector3 = global_position - stake.global_position
		away.y = 0.0
		var d := away.length()
		if d < stake.RADIUS:
			var dir := away / d if d > 0.01 else Vector3.RIGHT
			global_position = Vector3(stake.global_position.x, 0.0, stake.global_position.z) + dir * stake.RADIUS
			return true
	return false


func _touch(door: Door) -> void:
	if has_evidence(GhostDB.Ev.HANDPRINTS):
		door.add_handprint()


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Actions shared by the subclasses -------------------------------------

func mark_event(pos: Vector3) -> void:
	Net.ghost_event(pos)
	var event_room := Game.house.room_at(pos)
	for actor in Game.living_actors():
		if Game.actor_in_house(actor) and event_room == Game.house.room_at(actor.global_position):
			actor.change_sanity(-1.5)


func act_door(slam := true) -> void:
	var door := Game.house.nearest_door(global_position, 7.0)
	if door == null:
		return
	if slam:
		door.ghost_slam()
		Game.add_commotion(1.5)
	else:
		door.ghost_open()
	_touch(door)
	mark_event(door.global_position)


func act_flicker() -> void:
	Net.room_flicker(current_room, 2.5)
	Net.sfx_all("click", current_room.lamp.global_position, 0.0)
	if current_room.on and randf() < 0.35:
		Net.room_light(current_room, false)
	mark_event(global_position)


func act_throw(at_player: bool) -> void:
	var best := -1
	var best_d := 7.0
	var props := Game.house.props
	for i in props.size():
		var d := props[i].global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	var prop := props[best]
	var dir := Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)).normalized()
	if at_player and target_in_house():
		dir = (target.camera.global_position - prop.global_position).normalized() + Vector3(0, 0.25, 0)
	Net.prop_throw(best, dir * randf_range(2.5, 4.5))
	Net.sfx_all("thump", prop.global_position, 4.0, randf_range(0.8, 1.3))
	Game.add_commotion(0.5)
	mark_event(prop.global_position)


func act_knock() -> void:
	Net.sfx_all("knock", global_position, 4.0, randf_range(0.8, 1.1))
	mark_event(global_position)


func act_manifest() -> void:
	_reveal_time = 2.2
	mark_event(global_position)
	Net.sfx_all("whisper", global_position, -2.0, 0.6)
	for actor in Game.living_actors():
		if in_view_of(actor, 50.0, 15.0):
			actor.change_sanity(-6.0)


# --- Appearance -----------------------------------------------------------

func _build_visual() -> void:
	var h: float = data.height
	var skin := ShaderMaterial.new()
	skin.shader = load("res://shaders/ghost.gdshader")
	var c: Color = data.color
	skin.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
	_material = skin
	_visual = Node3D.new()
	add_child(_visual)
	Mk.cyl(_visual, h * 0.1, h * 0.16, h * 0.66, Vector3(0, h * 0.33, 0), skin)
	Mk.sphere(_visual, h * 0.075, Vector3(0, h * 0.75, 0), skin)
	var eye := Mk.mat(Color.WHITE, 0.5, c.lightened(0.6), 5.0)
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Mk.sphere(_visual, h * 0.012, Vector3(-h * 0.028, h * 0.76, -h * 0.065), eye)
	Mk.sphere(_visual, h * 0.012, Vector3(h * 0.028, h * 0.76, -h * 0.065), eye)
	for side in [-1.0, 1.0]:
		var arm := Mk.cyl(_visual, h * 0.022, h * 0.03, h * 0.42, Vector3(side * h * 0.14, h * 0.45, -h * 0.03), skin)
		arm.rotation.z = side * 0.2
		arm.rotation.x = 0.25
	_visual.visible = false


## Decides whether the figure should show. Only the host runs this.
func _update_visual() -> void:
	var show_it := _reveal_time > 0.0 or (target != null and wants_visible())
	match state:
		State.HUNT:
			show_it = fmod(_now() * 5.3, 1.0) < 0.75 if _windup <= 0.0 else fmod(_now() * 3.0, 1.0) < 0.4
		State.PINNED, State.STUNNED, State.CAPTURED:
			show_it = true
	net_wanted = show_it
	_show_visual()


func _show_visual() -> void:
	if film_override >= 0:
		apply_film_override()
		return
	_visual.visible = filter_visibility(net_wanted)


func apply_film_override() -> void:
	if film_override >= 0:
		_visual.visible = film_override == 1
