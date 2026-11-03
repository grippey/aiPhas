extends Item
## Reads the temperature of the room it is in. Below 0 C is evidence. A burning
## hot room is no evidence on its own, but only one ghost causes that.

var reading := 13.0
var _bar_mat: StandardMaterial3D


func _define() -> void:
	item_id = "thermometer"
	display_name = "Thermometer"
	description = "Reads the room's temperature"
	hand_offset = Vector3(0, -0.03, 0)
	hand_rotation = Vector3(0.5, 0, 0)
	collider_size = Vector3(0.09, 0.2, 0.05)
	collider_center = Vector3(0, 0.1, 0)


func _build() -> void:
	Mk.box(self, Vector3(0.075, 0.18, 0.03), Vector3(0, 0.09, 0), Mk.mat(Color(0.75, 0.73, 0.65), 0.5))
	_bar_mat = Mk.mat(Color(0.1, 0.8, 0.3), 0.5, Color(0.1, 0.8, 0.3), 2.0)
	Mk.box(self, Vector3(0.055, 0.05, 0.005), Vector3(0, 0.14, -0.016), _bar_mat)


func _process(delta: float) -> void:
	if Game.house == null or Game.ghost == null:
		return
	var room := Game.house.room_at(global_position)
	var target := 6.0
	if room != null:
		target = Game.ghost.temperature_for(room)
	reading = lerpf(reading, target + sin(Time.get_ticks_msec() * 0.002) * 0.3, delta * 0.8)
	var c := Color(0.2, 0.6, 1.0) if reading < 0.0 else (Color(1.0, 0.4, 0.1) if reading > 26.0 else Color(0.1, 0.8, 0.3))
	_bar_mat.emission = c


func status_text() -> String:
	return "Temperature: %.1f C" % reading
