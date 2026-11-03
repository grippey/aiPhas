extends Item
## Official-looking paperwork. With it in hand, a bystander conversation gains an
## option that settles them right away. Set down, it distracts a Busybody.

var copies := 2


func _define() -> void:
	net_props = ["copies"]
	item_id = "permit_folder"
	display_name = "Permit Folder"
	description = "Hold it while talking to someone to show them a permit"
	hand_offset = Vector3(0, -0.03, 0)
	hand_rotation = Vector3(0.9, 0, 0)
	collider_size = Vector3(0.24, 0.06, 0.32)
	collider_center = Vector3(0, 0.02, 0)


func _build() -> void:
	Mk.box(self, Vector3(0.22, 0.015, 0.3), Vector3(0, 0.01, 0), Mk.mat(Color(0.65, 0.5, 0.25), 0.8))
	Mk.box(self, Vector3(0.19, 0.004, 0.27), Vector3(0, 0.02, 0), Mk.mat(Color(0.85, 0.85, 0.8), 0.9))
	Mk.box(self, Vector3(0.06, 0.003, 0.06), Vector3(0.05, 0.023, 0.08), Mk.mat(Color(0.6, 0.1, 0.1), 0.5))


func use() -> void:
	Game.toast.emit("Talk to someone with this in hand to show them a permit.")


func status_text() -> String:
	return "Permits left: %d" % copies


func can_show() -> bool:
	return copies > 0


func spend() -> void:
	copies -= 1


func is_bait_on() -> bool:
	return not held
