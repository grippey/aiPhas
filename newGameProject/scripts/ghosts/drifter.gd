extends Ghost
## Always moving, passing straight through walls, with no real home. Slow, but
## during a hunt walls and doors mean nothing to it.

const SENSE_RANGE := 11.0

var _rehome_timer := 45.0


func _configure() -> void:
	use_navigation = false
	hunt_length_multiplier = 0.9


func _on_tick(delta: float) -> void:
	_rehome_timer -= delta
	if _rehome_timer <= 0.0:
		_rehome_timer = 45.0
		home_room = current_room


func idle_duration() -> float:
	return 0.3


func default_roam_target() -> Vector3:
	return Game.house.rooms.pick_random().random_point()


func roam_speed() -> float:
	return speed * 0.75


## It senses you through walls, by distance alone.
func update_hunt_target() -> bool:
	if not target_in_house() or target.is_hidden():
		return false
	if global_position.distance_to(target.global_position) < SENSE_RANGE * (0.7 if target.crouching else 1.0):
		_last_known = target.global_position
		return true
	return false


## Salt anchors it, so it looks for poured piles instead of a held item.
func bait_active(trap: Item) -> bool:
	for pile in get_tree().get_nodes_in_group("salt_piles"):
		if pile.global_position.distance_to(trap.global_position) <= Item.BAIT_RANGE:
			return true
	return false


func do_activity() -> void:
	if randf() < 0.6:
		act_flicker()
	else:
		act_door(false)


func spirit_lines() -> Array:
	return ["Passing through.", "No walls.", "Everywhere.", "Can't stop.", "Keep moving."]
