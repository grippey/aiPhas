extends Ghost
## Stalks the player and only moves while unobserved. It is visible when near,
## frozen in place, so turning around is how you find out how close it got.

const SHOW_RANGE := 7.0
const VIEW_CONE := 42.0

var _observed := false
var _dread_timer := 1.0


func _configure() -> void:
	hunt_length_multiplier = 1.1


func _on_tick(delta: float) -> void:
	_observed = seen_by_anyone(VIEW_CONE, 30.0)
	_dread_timer -= delta
	if _dread_timer <= 0.0:
		_dread_timer = 1.0
		if target_in_house() and global_position.distance_to(target.global_position) < SHOW_RANGE:
			target.change_sanity(-0.5)


func movement_multiplier() -> float:
	return 0.0 if _observed else 1.0


func roam_speed() -> float:
	return speed * 0.4


func idle_duration() -> float:
	return randf_range(2.0, 5.0)


## Always tries to get behind the player.
func default_roam_target() -> Vector3:
	if not target_in_house():
		return home_room.random_point()
	var cam := target.camera
	var behind := cam.global_transform.basis.z
	behind.y = 0.0
	var spot := target.global_position + behind.normalized() * randf_range(4.0, 7.0)
	var house_size := Game.house.size
	return Vector3(clampf(spot.x, 0.5, house_size.x - 0.5), 0.0, clampf(spot.z, 0.5, house_size.y - 0.5))


func wants_visible() -> bool:
	if state == State.ROAM or state == State.IDLE:
		return target_in_house() and global_position.distance_to(target.global_position) < SHOW_RANGE
	return false


func do_activity() -> void:
	if randf() < 0.5:
		act_knock()
	else:
		act_flicker()


func spirit_lines() -> Array:
	return ["Don't blink.", "I'm closer.", "Look at me.", "Turn around.", "I saw you."]
