class_name Mk
extends RefCounted
## Small helpers for building meshes and materials from code.

static var _surface_cache := {}


static func mat(color: Color, roughness := 0.8, emission := Color.BLACK, emission_energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


## A worn, noisy surface mapped in world space so it needs no UVs.
static func surface(color: Color, grain := Vector3(1, 1, 1), roughness := 0.9) -> StandardMaterial3D:
	var key := "%s|%s" % [color, grain]
	if _surface_cache.has(key):
		return _surface_cache[key]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, color.darkened(0.3))
	ramp.set_color(1, color.lightened(0.1))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = roughness
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = grain * 0.35
	_surface_cache[key] = m
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, material)


static func cyl(parent: Node, top_radius: float, bottom_radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _add(parent, mesh, pos, material)


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _add(parent, mesh, pos, material)


## A box with a matching collider, on the world layer.
static func solid(parent: Node, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	box(body, size, Vector3.ZERO, material)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	return body


static func _add(parent: Node, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.material_override = material
	parent.add_child(inst)
	return inst
