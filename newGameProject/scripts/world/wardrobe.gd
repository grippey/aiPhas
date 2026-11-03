class_name Wardrobe
extends StaticBody3D
## A hiding spot. Ghosts can't detect you inside unless they saw you climb in.


func get_prompt() -> String:
	return "Hide in wardrobe"


func interact(player: Player) -> void:
	player.enter_hiding(self)
	Net.sfx_all("door", global_position, -6.0)
	Net.noise(global_position, 5.0)
