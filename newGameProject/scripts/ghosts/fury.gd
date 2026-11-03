extends Ghost
## Hunts at any sanity, goes looking for you between hunts, smashes doors on the
## way, and accelerates for as long as it has you in sight.

const TOP_SPEED := 4.7

var _chase_speed := 0.0
var _door_timer := 0.0


func _configure() -> void:
	hunt_length_multiplier = 0.6
	smudge_block = 30.0


func can_hunt() -> bool:
	return true


func _on_hunt_started() -> void:
	_chase_speed = speed


func _on_tick(delta: float) -> void:
	if state != State.HUNT:
		return
	if _windup > 0.0:
		return
	_chase_speed = move_toward(_chase_speed, TOP_SPEED if can_see(target) else speed, delta * 0.4)
	_door_timer -= delta
	if _door_timer <= 0.0:
		_door_timer = 1.5
		var door := Game.house.nearest_door(global_position, 2.5)
		if door != null:
			door.ghost_slam()
			mark_event(door.global_position)


func hunt_speed() -> float:
	return _chase_speed


func default_roam_target() -> Vector3:
	if target_in_house() and randf() < 0.6:
		return target.global_position
	return super.default_roam_target()


func do_activity() -> void:
	var roll := randf()
	if roll < 0.5:
		act_door()
	elif roll < 0.8:
		act_throw(true)
	else:
		act_manifest()


func spirit_lines() -> Array:
	return ["Die.", "I will find you.", "Get out now.", "Mine.", "You're next."]
