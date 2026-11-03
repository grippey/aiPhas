extends Ghost
## Jams doors shut. At the start of a hunt it seals the doors nearest the player,
## so the player has to find another route or hide.

const LOCK_TIME := 10.0
const HUNT_LOCK_TIME := 9.0
const HUNT_LOCK_RANGE := 7.0


func _on_hunt_started() -> void:
	for door in Game.house.doors:
		if door != Game.house.front_door and door.global_position.distance_to(target.global_position) < HUNT_LOCK_RANGE:
			door.lock_for(HUNT_LOCK_TIME)


## Iron binds it, so it looks for planted stakes instead of a held item.
func bait_active(trap: Item) -> bool:
	for stake in get_tree().get_nodes_in_group("iron_wards"):
		if stake.global_position.distance_to(trap.global_position) <= Item.BAIT_RANGE:
			return true
	return false


func do_activity() -> void:
	var door := Game.house.nearest_door(global_position, 8.0)
	if door != null and door != Game.house.front_door and randf() < 0.7:
		door.lock_for(LOCK_TIME)
		door.add_handprint()
		mark_event(door.global_position)
	else:
		act_knock()


func spirit_lines() -> Array:
	return ["No way out.", "Stay.", "Locked.", "You can't leave.", "I keep the keys."]
