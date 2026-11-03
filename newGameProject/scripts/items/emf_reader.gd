extends Item
## Five LEDs showing the ghost's EM field. Only certain ghosts can peak at 5.

var on := false
var level := 0
var _leds: Array[StandardMaterial3D] = []
var _beep_timer := 0.0


func _define() -> void:
	net_props = ["on"]
	item_id = "emf_reader"
	display_name = "EMF Reader"
	description = "LMB: on/off. Level 5 is evidence."
	hand_rotation = Vector3(0.6, 0, 0)
	collider_size = Vector3(0.1, 0.18, 0.04)
	collider_center = Vector3(0, 0.09, 0)


func _build() -> void:
	Mk.box(self, Vector3(0.08, 0.17, 0.03), Vector3(0, 0.085, 0), Mk.mat(Color(0.12, 0.13, 0.12), 0.5))
	var colors := [Color(0.1, 0.9, 0.2), Color(0.5, 0.9, 0.1), Color(0.95, 0.85, 0.1), Color(1.0, 0.5, 0.1), Color(1.0, 0.1, 0.1)]
	for i in 5:
		var led := Mk.mat(colors[i] * 0.4, 0.4, colors[i], 0.0)
		_leds.append(led)
		Mk.box(self, Vector3(0.011, 0.016, 0.005), Vector3(-0.026 + i * 0.013, 0.14, -0.017), led)


func _process(delta: float) -> void:
	level = 0
	if on and Game.ghost != null:
		level = Game.ghost.emf_level_at(global_position)
	for i in 5:
		_leds[i].emission_energy_multiplier = 4.0 if i < level else 0.0
	if on and level >= 3:
		_beep_timer -= delta
		if _beep_timer <= 0.0:
			_beep_timer = 0.9 - level * 0.14
			Sfx.play_at("beep", global_position, -14.0 + level * 2.0, 0.6 + level * 0.12)
			Game.make_noise(global_position, 6.0)


func use() -> void:
	on = not on
	Sfx.play_ui("click", -6.0, 1.5)


func _on_stowed(stowed: bool) -> void:
	if stowed:
		on = false


func status_text() -> String:
	return "EMF level: %d" % level if on else "Off"


func is_bait_on() -> bool:
	return on
