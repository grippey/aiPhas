extends Ghost
## Hates light. It puts lights out as it goes and heads for dark rooms. Very fast
## in the dark, nearly helpless in the light, and it only hunts you in the dark.

const LIGHT_SPEED := 0.8

var _douse_timer := 2.0


func _on_tick(delta: float) -> void:
	_douse_timer -= delta
	if _douse_timer <= 0.0 and current_room.on and state != State.HUNT:
		_douse_timer = randf_range(2.0, 5.0)
		Net.room_light(current_room, false)
		Net.sfx_all("click", current_room.lamp.global_position, 2.0)
		mark_event(global_position)


func can_hunt() -> bool:
	var room := Game.house.room_at(target.global_position)
	return room != null and not room.on and super.can_hunt()


func default_roam_target() -> Vector3:
	var dark: Array[Room] = []
	for r in Game.house.rooms:
		if not r.on:
			dark.append(r)
	if dark.is_empty() or randf() < 0.25:
		return super.default_roam_target()
	return dark.pick_random().random_point()


func hunt_speed() -> float:
	return LIGHT_SPEED if _in_light() else speed


func roam_speed() -> float:
	return LIGHT_SPEED if _in_light() else speed * 0.5


func _in_light() -> bool:
	if current_room != null and current_room.on:
		return true
	return beam_on_me("flashlight")


func do_activity() -> void:
	# Prefers to kill the lights of the nearest lit room.
	var nearest: Room = null
	var best := 9.0
	for r in Game.house.rooms:
		var d := r.center().distance_to(global_position)
		if r.on and d < best:
			best = d
			nearest = r
	if nearest != null:
		Net.room_flicker(nearest, 1.0)
		Net.room_light(nearest, false)
		Net.sfx_all("click", nearest.lamp.global_position, 2.0)
		mark_event(nearest.center())
	elif randf() < 0.5:
		act_knock()
	else:
		act_door(false)


func spirit_lines() -> Array:
	return ["Too bright.", "Turn it off.", "In the dark.", "Close your eyes.", "No light."]
