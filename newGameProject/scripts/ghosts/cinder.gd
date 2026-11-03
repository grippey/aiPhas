extends Ghost
## A burning ghost. Its room runs hot, it scorches the floor, and it can't leave
## a flame alone: it seeks candles out and swallows them. It speeds up as a hunt
## goes on, but a lit candle in the open will pull it off your trail.

const MAX_SPEED := 4.6
const SWALLOW_RANGE := 0.9



func _on_tick(_delta: float) -> void:
	for candle in get_tree().get_nodes_in_group("candles"):
		if candle.lit and not candle.held and candle.global_position.distance_to(global_position) < SWALLOW_RANGE + candle.global_position.y:
			candle.snuff_by_ghost()
			mark_event(global_position)
			_scorch()
			target.change_sanity(-2.0)


func temperature_for(room: Room) -> float:
	if room == home_room:
		return 36.0
	if room == current_room:
		return 27.0
	return 14.0


func default_roam_target() -> Vector3:
	var flame := _nearest_flame(40.0)
	if flame != null and randf() < 0.8:
		return flame.global_position
	return super.default_roam_target()


func hunt_speed() -> float:
	return minf(speed + _hunt_elapsed * 0.13, MAX_SPEED)


func update_hunt_target() -> bool:
	var flame := _nearest_flame(9.0)
	if flame != null:
		_last_known = flame.global_position
		return true
	return super.update_hunt_target()


func do_activity() -> void:
	var roll := randf()
	if roll < 0.45:
		_scorch()
		Net.sfx_all("flame", global_position, 4.0)
		mark_event(global_position)
	elif roll < 0.7:
		act_flicker()
	else:
		act_door()


func _nearest_flame(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_range
	for candle in get_tree().get_nodes_in_group("candles"):
		var d: float = candle.global_position.distance_to(global_position)
		if candle.lit and not candle.held and d < best_d:
			best_d = d
			best = candle
	return best


func _scorch() -> void:
	Net.scorch(global_position)


func spirit_lines() -> Array:
	return ["Burning.", "Give it to me.", "So hot.", "Feed it.", "Ash."]
