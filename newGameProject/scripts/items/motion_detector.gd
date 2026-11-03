extends Item
## Set it down and it watches a few metres around itself, logging anything it
## catches. Only ghosts with the Motion evidence can set it off.

const RANGE := 2.8
const COOLDOWN := 10.0

var on := true
var _cooldown := 0.0
var _led: StandardMaterial3D
var _alarm := 0.0


func _define() -> void:
	net_props = ["on"]
	item_id = "motion_detector"
	display_name = "Motion Detector"
	description = "G: set it down. LMB: on/off."
	collider_size = Vector3(0.14, 0.2, 0.14)
	collider_center = Vector3(0, 0.08, 0)


func _build() -> void:
	Mk.box(self, Vector3(0.12, 0.13, 0.1), Vector3(0, 0.065, 0), Mk.mat(Color(0.78, 0.78, 0.74), 0.5))
	Mk.sphere(self, 0.04, Vector3(0, 0.11, -0.04), Mk.mat(Color(0.3, 0.3, 0.3), 0.15))
	_led = Mk.mat(Color(0.1, 0.1, 0.1), 0.3, Color(0.1, 1.0, 0.2), 2.0)
	Mk.sphere(self, 0.012, Vector3(0.04, 0.14, -0.04), _led)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_alarm = maxf(_alarm - delta, 0.0)
	if _alarm > 0.0:
		_led.emission = Color(1.0, 0.1, 0.05)
		_led.emission_energy_multiplier = 5.0
	else:
		_led.emission = Color(0.1, 1.0, 0.2)
		_led.emission_energy_multiplier = 2.0 if on and not held else 0.0
	if held or not on or _cooldown > 0.0 or Game.ghost == null:
		return
	var ghost := Game.ghost
	if ghost.has_evidence(GhostDB.Ev.MOTION) and ghost.global_position.distance_to(global_position) < RANGE:
		_cooldown = COOLDOWN
		_alarm = 2.0
		Sfx.play_at("alarm", global_position, 2.0)
		Game.make_noise(global_position, 8.0)
		var room := Game.house.room_at(global_position)
		Game.add_log("Motion detector tripped in the %s." % (room.name if room != null else "yard"))


func use() -> void:
	on = not on
	Sfx.play_ui("click", -6.0)


func status_text() -> String:
	return "Armed, set it down" if on else "Off"


func is_bait_on() -> bool:
	return on and not held
