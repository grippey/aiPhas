extends Ghost
## Blind. Sound is all it knows. It charges anything it hears and crawls otherwise,
## and it can only find a silent player by walking right into them.

const CRAWL_SPEED := 1.1
const FRESH_SOUND := 5.0
const TOUCH_DISTANCE := 0.55

var _heard_at := -100.0
var _howl_timer := 12.0


func _configure() -> void:
	smudge_block = 70.0


func hear(pos: Vector3, radius: float) -> void:
	if state == State.PINNED or state == State.CAPTURED:
		return
	if global_position.distance_to(pos) > radius:
		return
	_heard_at = _now()
	_last_known = pos
	if state == State.IDLE:
		state = State.ROAM
		_go_to(pos)


func _on_tick(delta: float) -> void:
	_howl_timer -= delta
	if _howl_timer <= 0.0:
		_howl_timer = randf_range(18.0, 34.0)
		Net.sfx_all("howl", global_position, 6.0, randf_range(0.85, 1.1))
		mark_event(global_position)


func _on_hunt_started() -> void:
	Net.sfx_all("howl", global_position, 8.0, 1.15)


func _heard_recently() -> bool:
	return _now() - _heard_at < FRESH_SOUND


func update_hunt_target() -> bool:
	return _heard_recently()


func hunt_speed() -> float:
	return speed if _heard_recently() else CRAWL_SPEED


func lose_interest_time() -> float:
	return 9.0


func can_catch_now() -> bool:
	if _heard_recently():
		return true
	var player := target
	return global_position.distance_to(player.global_position) < TOUCH_DISTANCE


func do_activity() -> void:
	if randf() < 0.5:
		act_knock()
	else:
		act_door()


func spirit_lines() -> Array:
	return ["I hear you.", "Quiet now.", "Shhh.", "Louder.", "Your heart."]
