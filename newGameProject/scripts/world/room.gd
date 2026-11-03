class_name Room
extends RefCounted
## One room of the house and its ceiling lamp.

var index := -1
var name := ""
var type := ""
var rect := Rect2()
var lamp: OmniLight3D
var bulb: StandardMaterial3D
var on := false
var flicker_time := 0.0


func _init(room_name: String, area: Rect2) -> void:
	name = room_name
	rect = area


func has_point(pos: Vector3) -> bool:
	return rect.has_point(Vector2(pos.x, pos.z))


func center() -> Vector3:
	var c := rect.get_center()
	return Vector3(c.x, 0.0, c.y)


func random_point(margin := 0.7) -> Vector3:
	return Vector3(
		randf_range(rect.position.x + margin, rect.end.x - margin),
		0.0,
		randf_range(rect.position.y + margin, rect.end.y - margin))


func set_on(value: bool) -> void:
	on = value
	lamp.visible = value
	bulb.emission_energy_multiplier = 3.0 if value else 0.0
