extends Item
## Pours salt piles. Some ghosts leave footprints in them, and salt anchors a Drifter.


var charges := 4


func _define() -> void:
	net_props = ["charges"]
	item_id = "salt"
	display_name = "Salt"
	description = "LMB: pour a pile on the floor"
	hand_offset = Vector3(0, -0.02, 0)
	collider_size = Vector3(0.14, 0.2, 0.14)
	collider_center = Vector3(0, 0.1, 0)


func _build() -> void:
	Mk.cyl(self, 0.05, 0.06, 0.18, Vector3(0, 0.09, 0), Mk.mat(Color(0.2, 0.3, 0.55), 0.6))
	Mk.cyl(self, 0.035, 0.05, 0.03, Vector3(0, 0.195, 0), Mk.mat(Color(0.8, 0.8, 0.78), 0.5))


func use() -> void:
	if charges <= 0:
		Game.toast.emit("The salt is empty. Scoop up an old pile with E.")
		return
	var spot: Variant = holder.aim_floor_point()
	if spot == null or spot.y > 0.2:
		Game.toast.emit("Salt has to go on the floor.")
		return
	charges -= 1
	Net.spawn_salt(spot)


func status_text() -> String:
	return "Pours left: %d" % charges


func refill() -> void:
	charges += 1
