extends Item
## Two brass rods that swing towards the ghost, through walls, and tremble harder
## as you get closer. They give no evidence, but they tell you where to look.

const STRONG_RANGE := 5.0
const FAINT_RANGE := 14.0

var _rods: Array[Node3D] = []


func _define() -> void:
	item_id = "dowsing_rods"
	display_name = "Dowsing Rods"
	description = "Hold them out. They swing towards the ghost."
	hand_offset = Vector3(-0.08, -0.02, 0.02)
	collider_size = Vector3(0.24, 0.1, 0.3)
	collider_center = Vector3(0, 0.05, 0)


func _build() -> void:
	var brass := Mk.mat(Color(0.8, 0.65, 0.3), 0.25)
	for x in [-0.07, 0.07]:
		Mk.cyl(self, 0.008, 0.008, 0.1, Vector3(x, 0.0, 0.0), brass)
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0.05, 0.0)
		add_child(pivot)
		var rod := Mk.cyl(pivot, 0.004, 0.004, 0.28, Vector3(0, 0, -0.14), brass)
		rod.rotation.x = PI / 2
		_rods.append(pivot)


func _process(_delta: float) -> void:
	var ghost := Game.ghost
	if ghost == null or not is_visible_in_tree():
		return
	var d := global_position.distance_to(ghost.global_position)
	var strength := clampf(1.0 - d / FAINT_RANGE, 0.0, 1.0)
	var flat := ghost.global_position - global_position
	var world_yaw := atan2(-flat.x, -flat.z)
	for i in 2:
		var wobble := sin(Time.get_ticks_msec() * 0.03 + i) * 0.12 * strength
		if d > FAINT_RANGE:
			wobble = sin(Time.get_ticks_msec() * 0.0015 + i * 2.0) * 0.5
			_rods[i].rotation.y = wobble
		else:
			_rods[i].global_rotation.y = world_yaw + wobble


func status_text() -> String:
	var ghost := Game.ghost
	if ghost == null:
		return ""
	var d := global_position.distance_to(ghost.global_position)
	if d < STRONG_RANGE:
		return "Pull: very strong"
	if d < FAINT_RANGE:
		return "Pull: steady"
	return "Pull: none"


func is_bait_on() -> bool:
	return held and is_visible_in_tree()
