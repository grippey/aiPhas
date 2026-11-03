extends Ghost
## Attacks your cover instead of you. It makes a racket people can hear from the
## street and throws the front door open, so bystanders turn up sooner and get
## suspicious faster.

const RACKET_SUSPICION := 3.0


func do_activity() -> void:
	var roll := randf()
	if roll < 0.4:
		_racket()
	elif roll < 0.6:
		_open_front_door()
	elif roll < 0.8:
		act_door()
	else:
		act_throw(false)


func _racket() -> void:
	Net.sfx_all("slam", global_position, 8.0, randf_range(0.6, 1.0))
	Net.sfx_all("knock", global_position, 8.0, 0.7)
	mark_event(global_position)
	Game.add_commotion(RACKET_SUSPICION)


func _open_front_door() -> void:
	var door := Game.house.front_door
	door.ghost_open()
	mark_event(door.global_position)
	Game.add_commotion(RACKET_SUSPICION)


func spirit_lines() -> Array:
	return ["I'm telling.", "I saw that.", "Who let you in?", "I'll call them.", "Everyone will know."]
