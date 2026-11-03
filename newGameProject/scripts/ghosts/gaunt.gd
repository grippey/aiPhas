extends Ghost
## Feeds on fear. It drains sanity fast when near you and speeds up as your sanity
## falls, so a calm player can outwalk it and a frightened one can't.

const FEED_RANGE := 7.0
const FEED_RATE := 1.1
const SLOW := 1.3
const FAST := 4.2


func _on_tick(delta: float) -> void:
	if target_in_house() and not target.is_hidden():
		var d := global_position.distance_to(target.global_position)
		if d < FEED_RANGE:
			target.change_sanity(-delta * FEED_RATE * (1.0 - d / FEED_RANGE))


func can_hunt() -> bool:
	return target.sanity < 55.0


func hunt_speed() -> float:
	return lerpf(FAST, SLOW, target.sanity / 100.0)


func default_roam_target() -> Vector3:
	if target_in_house() and randf() < 0.55:
		return target.global_position
	return super.default_roam_target()


func do_activity() -> void:
	if randf() < 0.5:
		act_knock()
	else:
		act_flicker()


func spirit_lines() -> Array:
	return ["Hungry.", "So afraid.", "Feed me.", "More.", "I can taste it."]
