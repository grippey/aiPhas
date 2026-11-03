extends Ghost
## Invisible unless a UV Light is on it, even during a hunt, and its steps are faint.


func filter_visibility(_wanted: bool) -> bool:
	if state == State.CAPTURED:
		return true
	return beam_on_me("uv_light")


func step_volume() -> float:
	return -2.0


func do_activity() -> void:
	if randf() < 0.6:
		act_door(false)
	else:
		act_knock()


func spirit_lines() -> Array:
	return ["Can't see me.", "Right here.", "Next to you.", "Look closer.", "I never left."]
