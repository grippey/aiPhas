class_name LightSwitch
extends StaticBody3D
## Wall switch for a room's lamp.

var room: Room


func get_prompt() -> String:
	return "Turn %s %s light" % ["off" if room.on else "on", room.name]


func interact(_player: Player) -> void:
	Net.room_light(room, not room.on)
	Net.sfx_all("click", global_position)
