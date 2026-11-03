extends Item
## Plants iron stakes. No ghost can cross a stake's ring until the stake rusts
## away, which makes a safe spot in a hunt. Iron also binds a Warden in a trap.


var stakes := 3


func _define() -> void:
	net_props = ["stakes"]
	item_id = "iron_ward"
	display_name = "Iron Ward"
	description = "LMB: plant a stake. Ghosts can't cross its ring."
	hand_offset = Vector3(0, -0.05, 0)
	collider_size = Vector3(0.1, 0.3, 0.1)
	collider_center = Vector3(0, 0.15, 0)


func _build() -> void:
	var iron := Mk.mat(Color(0.25, 0.22, 0.2), 0.55)
	Mk.cyl(self, 0.02, 0.003, 0.28, Vector3(0, 0.14, 0), iron)
	Mk.cyl(self, 0.03, 0.03, 0.025, Vector3(0, 0.285, 0), iron)


func use() -> void:
	if stakes <= 0:
		Game.toast.emit("No stakes left.")
		return
	var spot: Variant = holder.aim_floor_point()
	if spot == null or spot.y > 0.2:
		Game.toast.emit("A stake has to go in the floor.")
		return
	stakes -= 1
	Net.spawn_stake(spot)
	Net.noise(spot, 8.0)


func status_text() -> String:
	return "Stakes left: %d" % stakes
