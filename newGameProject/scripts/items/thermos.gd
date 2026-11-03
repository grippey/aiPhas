extends Item
## Hot tea. Sip it to steady your nerves. Set down open, it's an offering that
## holds a Gaunt in a trap.

const SIP_SANITY := 18.0

var sips := 3


func _define() -> void:
	net_props = ["sips"]
	item_id = "thermos"
	display_name = "Thermos"
	description = "LMB: take a sip and recover sanity"
	hand_offset = Vector3(0, -0.06, 0)
	collider_size = Vector3(0.1, 0.24, 0.1)
	collider_center = Vector3(0, 0.12, 0)


func _build() -> void:
	Mk.cyl(self, 0.04, 0.042, 0.2, Vector3(0, 0.1, 0), Mk.mat(Color(0.2, 0.32, 0.25), 0.45))
	Mk.cyl(self, 0.03, 0.04, 0.04, Vector3(0, 0.22, 0), Mk.mat(Color(0.65, 0.65, 0.65), 0.3))


func use() -> void:
	if sips <= 0:
		Game.toast.emit("It's empty.")
		return
	sips -= 1
	Game.change_sanity(SIP_SANITY)
	Sfx.play_ui("flame", -12.0, 0.6)


func status_text() -> String:
	return "Sips left: %d" % sips if sips > 0 else "Empty"


func is_bait_on() -> bool:
	return not held and sips > 0
