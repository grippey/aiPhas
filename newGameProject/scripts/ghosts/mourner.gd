extends Ghost
## Stays in one room and weeps. It almost never attacks, and when it does it
## gives up as soon as it can't see you.

var _weep_timer := 8.0


func _configure() -> void:
	hunt_length_multiplier = 1.2


func _on_tick(delta: float) -> void:
	_weep_timer -= delta
	if _weep_timer <= 0.0:
		_weep_timer = randf_range(14.0, 26.0)
		Net.sfx_all("wail", global_position, 4.0, randf_range(0.85, 1.1))
		if target_in_house() and Game.house.room_at(target.global_position) == home_room:
			target.change_sanity(-1.5)


func can_hunt() -> bool:
	return target.sanity < 25.0


func default_roam_target() -> Vector3:
	return home_room.random_point()


## It will only come to a trap set in its own room.
func can_be_lured(trap: Item) -> bool:
	return home_room.has_point(trap.global_position)


func lose_interest_time() -> float:
	return 2.0


func do_activity() -> void:
	if randf() < 0.45:
		act_flicker()
	elif randf() < 0.5:
		act_door(false)
	else:
		act_manifest()


func spirit_lines() -> Array:
	return ["So cold.", "Where did they go?", "Stay with me.", "Don't leave.", "It hurts."]
