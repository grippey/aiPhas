extends Node3D
## A planted iron stake. Ghost.gd pushes ghosts out of its ring.

const RADIUS := 2.2
const LIFETIME := 30.0

var _left := LIFETIME
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("iron_wards")
	Mk.cyl(self, 0.022, 0.004, 0.3, Vector3(0, 0.15, 0), Mk.mat(Color(0.25, 0.22, 0.2), 0.55))
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.025
	torus.outer_radius = RADIUS
	torus.rings = 48
	torus.ring_segments = 4
	_ring_mat = Mk.mat(Color(0.1, 0.1, 0.1), 0.5, Color(0.9, 0.5, 0.2), 1.0)
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = _ring_mat
	ring.position = Vector3(0, 0.03, 0)
	add_child(ring)


func _process(delta: float) -> void:
	_left -= delta
	_ring_mat.emission_energy_multiplier = clampf(_left / 8.0, 0.1, 1.0)
	if _left <= 0.0:
		queue_free()
