extends Ghost
## Acts in bursts of thrown objects and slammed doors. Every burst winds it up,
## and when it boils over it hunts, however calm you are.

const TANTRUM_LIMIT := 14

var _burst_left := 0
var _burst_timer := 0.0
var _tantrum := 0
var _throw_timer := 2.0


func _on_tick(delta: float) -> void:
	if state == State.HUNT:
		_throw_timer -= delta
		if _throw_timer <= 0.0:
			_throw_timer = 2.2
			act_throw(true)
		return
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = randf_range(0.35, 0.8)
			_burst_left -= 1
			_tantrum += 1
			_rattle()
			if _tantrum >= TANTRUM_LIMIT and _hunt_block <= 0.0 and Game.time_inside > Game.INSIDE_GRACE:
				_tantrum = 0
				force_hunt()


func do_activity() -> void:
	_burst_left = randi_range(2, 4)
	_burst_timer = 0.0


func _rattle() -> void:
	var near_player := target_in_house() and global_position.distance_to(target.global_position) < 8.0
	var roll := randf()
	if roll < 0.55:
		act_throw(near_player)
	elif roll < 0.85:
		act_door()
	else:
		act_flicker()


func spirit_lines() -> Array:
	return ["Mine!", "Ha ha ha.", "Catch!", "Play with me.", "Again!"]
