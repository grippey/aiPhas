extends Item
## The main light source. Its beam slows a Gloam and holds one inside a trap.

var on := false
var _light: SpotLight3D
var _flicker := 0.0
var _lens: StandardMaterial3D


func _define() -> void:
	net_props = ["on"]
	item_id = "flashlight"
	display_name = "Flashlight"
	description = "LMB: on/off"
	hand_offset = Vector3(0.0, 0.03, 0.0)
	collider_size = Vector3(0.1, 0.1, 0.3)
	collider_center = Vector3(0, 0.05, 0)


func _build() -> void:
	var body := Mk.mat(Color(0.12, 0.12, 0.13), 0.4)
	var tube := Mk.cyl(self, 0.028, 0.028, 0.2, Vector3(0, 0.05, 0.02), body)
	tube.rotation.x = PI / 2
	var head := Mk.cyl(self, 0.045, 0.03, 0.06, Vector3(0, 0.05, -0.1), body)
	head.rotation.x = -PI / 2
	_lens = Mk.mat(Color(0.9, 0.9, 0.8), 0.2, Color(1, 0.95, 0.8), 0.0)
	var lens := Mk.cyl(self, 0.04, 0.04, 0.005, Vector3(0, 0.05, -0.132), _lens)
	lens.rotation.x = PI / 2
	_light = SpotLight3D.new()
	_light.position = Vector3(0, 0.05, -0.14)
	_light.spot_range = 20.0
	_light.spot_angle = 27.0
	_light.spot_attenuation = 0.8
	_light.light_energy = 5.0
	_light.light_color = Color(1.0, 0.95, 0.85)
	_light.shadow_enabled = true
	add_child(_light)
	_set_on(false)


func _process(_delta: float) -> void:
	if on and Game.hunting and Game.ghost != null and Game.ghost.global_position.distance_to(global_position) < 12.0:
		_light.visible = randf() > 0.35
	elif on:
		_light.visible = true


func _set_on(value: bool) -> void:
	on = value
	_light.visible = value
	_lens.emission_energy_multiplier = 2.5 if value else 0.0


func use() -> void:
	_set_on(not on)
	Sfx.play_ui("click", -6.0, 1.3)


func _on_stowed(stowed: bool) -> void:
	if stowed:
		_set_on(false)


func status_text() -> String:
	return "Beam: on" if on else "Beam: off"


func is_on_ghost(ghost: Ghost) -> bool:
	return on and held and ghost.in_view_of(holder, 14.0, 20.0)


func bait_works(ghost: Ghost, _trap: Item) -> bool:
	return is_on_ghost(ghost)


func _on_net_state() -> void:
	_set_on(on)
