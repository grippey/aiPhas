extends Item
## Shows handprints left on doors, and is the only way to see a Pallid.

const REVEAL_RANGE := 7.0
const REVEAL_CONE := 26.0

var on := false
var _light: SpotLight3D
var _lens: StandardMaterial3D


func _define() -> void:
	net_props = ["on"]
	item_id = "uv_light"
	display_name = "UV Light"
	description = "LMB: on/off. Shine it on doors."
	hand_offset = Vector3(0.0, 0.03, 0.0)
	collider_size = Vector3(0.1, 0.1, 0.28)
	collider_center = Vector3(0, 0.05, 0)


func _build() -> void:
	var tube := Mk.cyl(self, 0.022, 0.022, 0.2, Vector3(0, 0.05, 0.01), Mk.mat(Color(0.18, 0.1, 0.3), 0.4))
	tube.rotation.x = PI / 2
	_lens = Mk.mat(Color(0.4, 0.2, 0.8), 0.2, Color(0.55, 0.2, 1.0), 0.0)
	var lens := Mk.cyl(self, 0.03, 0.03, 0.01, Vector3(0, 0.05, -0.095), _lens)
	lens.rotation.x = PI / 2
	_light = SpotLight3D.new()
	_light.position = Vector3(0, 0.05, -0.11)
	_light.spot_range = 9.0
	_light.spot_angle = 24.0
	_light.light_energy = 1.3
	_light.light_color = Color(0.55, 0.25, 1.0)
	add_child(_light)
	_set_on(false)


func _process(_delta: float) -> void:
	if not on or not held:
		return
	var cam := holder.camera
	var forward := -cam.global_transform.basis.z
	for hand in get_tree().get_nodes_in_group("handprints"):
		var to_hand: Vector3 = hand.global_position - cam.global_position
		hand.visible = to_hand.length() < REVEAL_RANGE and rad_to_deg(forward.angle_to(to_hand)) < REVEAL_CONE


func _set_on(value: bool) -> void:
	on = value
	_light.visible = value
	_lens.emission_energy_multiplier = 3.0 if value else 0.0
	if not value and is_inside_tree():
		for hand in get_tree().get_nodes_in_group("handprints"):
			hand.visible = false


func use() -> void:
	_set_on(not on)
	Sfx.play_ui("click", -6.0, 1.6)


func _on_stowed(stowed: bool) -> void:
	if stowed:
		_set_on(false)


func _on_placed() -> void:
	_set_on(false)


func status_text() -> String:
	return "UV: on" if on else "UV: off"


func is_on_ghost(ghost: Ghost) -> bool:
	return on and held and ghost.in_view_of(holder, REVEAL_CONE, 12.0)


func bait_works(ghost: Ghost, _trap: Item) -> bool:
	return is_on_ghost(ghost)


func _on_net_state() -> void:
	_set_on(on)
