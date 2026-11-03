class_name House
extends Node3D
## Builds a random house from a HouseLayout, plus its yard and navigation mesh.

const WALL_H := 2.8
const WALL_T := 0.2
const GAP := 1.4

const FLOOR_COLORS := {
	"hallway": Color(0.28, 0.2, 0.14), "foyer": Color(0.3, 0.29, 0.27), "bathroom": Color(0.4, 0.45, 0.45),
	"living": Color(0.3, 0.21, 0.14), "kitchen": Color(0.35, 0.36, 0.32), "master": Color(0.27, 0.2, 0.2),
	"dining": Color(0.3, 0.2, 0.13), "bedroom": Color(0.25, 0.22, 0.26), "nursery": Color(0.28, 0.3, 0.36),
	"study": Color(0.22, 0.17, 0.12), "laundry": Color(0.33, 0.34, 0.36), "den": Color(0.26, 0.2, 0.15), "library": Color(0.2, 0.15, 0.11),
}
## Furniture you could leave a mug on.
const SURFACES := ["counter", "table", "nightstand", "dresser", "sideboard", "desk", "coffee_table", "console", "sink", "chest", "washer"]

var layout: HouseLayout
var size := Vector2.ZERO
var rooms: Array[Room] = []
var doors: Array[Door] = []
var front_door: Door
var props: Array[RigidBody3D] = []
var nav_region: NavigationRegion3D

## The point on the floor just inside the front door.
var entrance := Vector3.ZERO
## The point in the yard straight out from the front door.
var yard_anchor := Vector3.ZERO

var _wall_mat: Material
var _trim_mat: Material
var _door_mat: Material
var _wood: Material
var _dark_wood: Material
var _fabric: Material
var _white: Material
var _steel: Material
var _counter_top: Material
var _prop_spots: Array[Vector3] = []


func _ready() -> void:
	layout = HouseLayout.generate()
	size = layout.size
	var door_center: Vector2 = layout.front_door.center
	entrance = Vector3(door_center.x, 0.0, size.y - 1.25)
	yard_anchor = Vector3(door_center.x, 0.0, size.y)

	_wall_mat = Mk.surface(Color(0.5, 0.47, 0.4), Vector3(2, 2, 2))
	_trim_mat = Mk.mat(Color(0.2, 0.16, 0.13))
	_door_mat = Mk.surface(Color(0.33, 0.22, 0.15), Vector3(0.5, 0.1, 0.5), 0.7)
	_wood = Mk.surface(Color(0.42, 0.28, 0.18), Vector3(0.6, 3, 0.6), 0.7)
	_dark_wood = Mk.surface(Color(0.2, 0.13, 0.09), Vector3(0.6, 3, 0.6), 0.6)
	_fabric = Mk.surface(Color(0.3, 0.26, 0.3), Vector3(5, 5, 5))
	_white = Mk.mat(Color(0.75, 0.75, 0.72), 0.3)
	_steel = Mk.mat(Color(0.5, 0.52, 0.53), 0.35)
	_counter_top = Mk.mat(Color(0.25, 0.25, 0.26), 0.4)

	nav_region = NavigationRegion3D.new()
	add_child(nav_region)

	_build_rooms()
	_build_shell(nav_region)
	for piece in layout.furniture:
		_build_furniture(nav_region, piece)
	_build_yard()
	_bake_navigation()
	_add_doors()
	_add_props()


func _process(delta: float) -> void:
	for r in rooms:
		r.flicker_time = maxf(r.flicker_time - delta, 0.0)
		if not r.on:
			continue
		if Game.hunting or r.flicker_time > 0.0:
			r.lamp.visible = randf() > 0.45
		else:
			r.lamp.visible = true


func contains(pos: Vector3) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(Vector2(pos.x, pos.z))


func room_at(pos: Vector3) -> Room:
	for r in rooms:
		if r.has_point(pos):
			return r
	return null


func nav_point(pos: Vector3) -> Vector3:
	var p := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, pos)
	p.y = 0.0
	return p


func nearest_door(pos: Vector3, max_distance: float) -> Door:
	var best: Door = null
	var best_d := max_distance
	for d in doors:
		var center := d.global_position + (d.global_transform.basis.x * Door.WIDTH / 2.0)
		var dist := center.distance_to(pos)
		if dist < best_d:
			best_d = dist
			best = d
	return best


func _build_rooms() -> void:
	for plan in layout.rooms:
		var room := Room.new(plan.name, plan.rect)
		room.type = plan.type
		room.index = rooms.size()
		rooms.append(room)
		var c := room.center()
		# Floors are cosmetic, and the collision comes from the slab below them.
		Mk.box(self, Vector3(room.rect.size.x, 0.02, room.rect.size.y), Vector3(c.x, 0.0, c.z), Mk.surface(FLOOR_COLORS[plan.type], Vector3(1, 1, 1), 0.6))

		var lamp := OmniLight3D.new()
		lamp.position = Vector3(c.x, WALL_H - 0.35, c.z)
		lamp.light_color = Color(1.0, 0.82, 0.6)
		lamp.light_energy = 1.5
		lamp.omni_range = maxf(room.rect.size.x, room.rect.size.y) * 0.9 + 2.0
		lamp.shadow_enabled = true
		add_child(lamp)
		room.lamp = lamp
		room.bulb = Mk.mat(Color(0.8, 0.8, 0.7), 0.4, Color(1.0, 0.85, 0.6), 0.0)
		Mk.sphere(self, 0.09, Vector3(c.x, WALL_H - 0.28, c.z), room.bulb)
		Mk.cyl(self, 0.01, 0.01, 0.2, Vector3(c.x, WALL_H - 0.1, c.z), _trim_mat)
		room.set_on(false)

		_add_switch(room, layout.switch_position(plan), plan.doors[0].along_x)


func _add_switch(room: Room, pos: Vector3, along_x: bool) -> void:
	var sw := LightSwitch.new()
	sw.room = room
	sw.position = pos
	add_child(sw)
	var sw_size := Vector3(0.1, 0.16, 0.05) if along_x else Vector3(0.05, 0.16, 0.1)
	Mk.box(sw, sw_size, Vector3.ZERO, _white)
	var shape := BoxShape3D.new()
	shape.size = sw_size * 1.6
	sw.add_child(CollisionShapes.make(shape))


func _build_shell(parent: Node3D) -> void:
	# The slab and ceiling. The slab's top sits at y = 0.
	Mk.solid(parent, Vector3(size.x, 0.4, size.y), Vector3(size.x / 2, -0.2, size.y / 2), _trim_mat)
	Mk.solid(parent, Vector3(size.x, 0.1, size.y), Vector3(size.x / 2, WALL_H + 0.05, size.y / 2), Mk.surface(Color(0.42, 0.41, 0.38)))

	for w in layout.walls:
		var a := Vector2(w.from, w.line) if w.along_x else Vector2(w.line, w.from)
		var b := Vector2(w.to, w.line) if w.along_x else Vector2(w.line, w.to)
		_wall(parent, a, b, w.gaps)

	# Moonlit windows on the outer walls.
	var glass := Mk.mat(Color(0.2, 0.28, 0.4), 0.1, Color(0.3, 0.42, 0.6), 0.55)
	for win in layout.windows:
		_window(Vector3(win.at.x, 1.55, win.at.y), win.along_x, glass)

	# The roof, seen from the yard.
	var roof := PrismMesh.new()
	roof.size = Vector3(size.y + 1.2, 2.6, size.x + 1.2)
	var roof_inst := MeshInstance3D.new()
	roof_inst.mesh = roof
	roof_inst.material_override = Mk.surface(Color(0.15, 0.13, 0.14), Vector3(3, 3, 3))
	roof_inst.position = Vector3(size.x / 2, WALL_H + 0.1 + 1.3, size.y / 2)
	roof_inst.rotation.y = PI / 2
	add_child(roof_inst)


func _wall(parent: Node3D, a: Vector2, b: Vector2, gaps: Array) -> void:
	var along_x := is_equal_approx(a.y, b.y)
	var start: float = a.x if along_x else a.y
	var end: float = b.x if along_x else b.y
	var cursor := start
	var sorted := gaps.duplicate()
	sorted.sort()
	for g in sorted:
		_wall_piece(parent, a, along_x, cursor, g - GAP / 2.0, 0.0, WALL_H)
		_wall_piece(parent, a, along_x, g - GAP / 2.0, g + GAP / 2.0, Door.HEIGHT, WALL_H)
		cursor = g + GAP / 2.0
	_wall_piece(parent, a, along_x, cursor, end, 0.0, WALL_H)


func _wall_piece(parent: Node3D, anchor: Vector2, along_x: bool, from: float, to: float, y0: float, y1: float) -> void:
	var length := to - from
	if length <= 0.01:
		return
	var mid := (from + to) / 2.0
	var h := y1 - y0
	var wall_size := Vector3(length + WALL_T, h, WALL_T) if along_x else Vector3(WALL_T, h, length + WALL_T)
	if y0 > 0.0:
		wall_size = Vector3(length, h, WALL_T) if along_x else Vector3(WALL_T, h, length)
	var pos := Vector3(mid, y0 + h / 2.0, anchor.y) if along_x else Vector3(anchor.x, y0 + h / 2.0, mid)
	Mk.solid(parent, wall_size, pos, _wall_mat)
	if y0 <= 0.0:
		var trim := Vector3(wall_size.x + 0.02, 0.14, wall_size.z + 0.02)
		Mk.box(self, trim, Vector3(pos.x, 0.07, pos.z), _trim_mat)


func _window(pos: Vector3, along_x: bool, glass: Material) -> void:
	var w := 1.2
	var h := 1.1
	var thick := WALL_T + 0.03
	var pane := Vector3(w, h, thick) if along_x else Vector3(thick, h, w)
	Mk.box(self, pane, pos, glass)
	# Frame and crossbars.
	var bar := thick + 0.03
	var horizontal := Vector3(w + 0.1, 0.06, bar) if along_x else Vector3(bar, 0.06, w + 0.1)
	var vertical := Vector3(0.06, h + 0.1, bar) if along_x else Vector3(bar, h + 0.1, 0.06)
	Mk.box(self, horizontal, pos + Vector3(0, h / 2, 0), _trim_mat)
	Mk.box(self, horizontal, pos - Vector3(0, h / 2, 0), _trim_mat)
	Mk.box(self, horizontal, pos, _trim_mat)
	Mk.box(self, vertical, pos, _trim_mat)


func _build_furniture(p: Node3D, piece: Dictionary) -> void:
	var rect: Rect2 = piece.rect
	var h: float = piece.height
	var c := rect.get_center()
	var pos := Vector3(c.x, h / 2.0, c.y)
	var box_size := Vector3(rect.size.x, h, rect.size.y)
	var facing := Vector3(piece.facing.x, 0.0, piece.facing.y)
	var depth := absf(facing.x) * rect.size.x + absf(facing.z) * rect.size.y
	var across := Vector3(absf(facing.z), 0.0, absf(facing.x))
	var width := across.x * rect.size.x + across.z * rect.size.y
	var kind: String = piece.kind

	match kind:
		"wardrobe":
			_wardrobe(p, pos, box_size)
		"bed":
			Mk.solid(p, box_size, pos, _fabric)
			var pillow := across * (width * 0.8) + (Vector3(absf(facing.x), 0, absf(facing.z)) * 0.42) + Vector3(0, 0.12, 0)
			Mk.box(self, pillow, Vector3(c.x, h + 0.06, c.y) - facing * (depth / 2.0 - 0.3), _white)
		"sofa", "armchair":
			var seat_h := h * 0.55
			var seat := box_size
			seat.y = seat_h
			Mk.solid(p, seat, Vector3(c.x, seat_h / 2.0, c.y), _fabric)
			var back := across * width + Vector3(absf(facing.x), 0, absf(facing.z)) * 0.22 + Vector3(0, h - seat_h, 0)
			Mk.solid(p, back, Vector3(c.x, seat_h + (h - seat_h) / 2.0, c.y) - facing * (depth / 2.0 - 0.11), _fabric)
		"chair":
			Mk.solid(p, box_size, pos, _dark_wood)
			var back := across * width + Vector3(absf(facing.x), 0, absf(facing.z)) * 0.06 + Vector3(0, 0.5, 0)
			Mk.box(self, back, Vector3(c.x, h + 0.25, c.y) - facing * (depth / 2.0 - 0.03), _dark_wood)
		"counter":
			Mk.solid(p, box_size - Vector3(0, 0.04, 0), pos - Vector3(0, 0.02, 0), _wood)
			Mk.box(self, Vector3(box_size.x + 0.04, 0.04, box_size.z + 0.04), Vector3(c.x, h - 0.02, c.y), _counter_top)
		"bookshelf":
			Mk.solid(p, box_size, pos, _dark_wood)
			for shelf in 4:
				var books := across * (width * 0.92) + Vector3(absf(facing.x), 0, absf(facing.z)) * 0.03 + Vector3(0, 0.26, 0)
				Mk.box(self, books, Vector3(c.x, 0.28 + shelf * 0.42, c.y) + facing * (depth / 2.0), Mk.mat(Color(randf_range(0.2, 0.5), randf_range(0.1, 0.3), randf_range(0.1, 0.3)), 0.8))
		"fridge", "washer":
			Mk.solid(p, box_size, pos, _steel)
		"tub", "toilet", "sink", "crib":
			Mk.solid(p, box_size, pos, _white)
		"table", "desk", "sideboard", "console", "cabinet", "coffee_table":
			Mk.solid(p, box_size, pos, _dark_wood)
		_:
			Mk.solid(p, box_size, pos, _wood)

	if kind in SURFACES:
		for i in randi_range(1, 2):
			_prop_spots.append(Vector3(
				c.x + randf_range(-rect.size.x, rect.size.x) * 0.3,
				h + 0.2,
				c.y + randf_range(-rect.size.y, rect.size.y) * 0.3))


func _wardrobe(p: Node3D, pos: Vector3, box_size: Vector3) -> void:
	var w := Wardrobe.new()
	w.position = pos
	p.add_child(w)
	Mk.box(w, box_size, Vector3.ZERO, _dark_wood)
	var shape := BoxShape3D.new()
	shape.size = box_size
	w.add_child(CollisionShapes.make(shape))
	# A vertical seam makes it read as a pair of doors.
	if box_size.x > box_size.z:
		Mk.box(w, Vector3(0.03, box_size.y - 0.1, box_size.z + 0.02), Vector3.ZERO, _trim_mat)
	else:
		Mk.box(w, Vector3(box_size.x + 0.02, box_size.y - 0.1, 0.03), Vector3.ZERO, _trim_mat)


func _build_yard() -> void:
	var dx := yard_anchor.x
	var front := yard_anchor.z
	var mid := size / 2.0
	Mk.solid(self, Vector3(130, 1.0, 130), Vector3(mid.x, -0.52, mid.y + 8.0), Mk.surface(Color(0.1, 0.15, 0.09), Vector3(3, 3, 3)))
	# A gravel path up to the door, and the road beyond the yard.
	Mk.box(self, Vector3(2.0, 0.02, 9.0), Vector3(dx, 0.0, front + 4.5), Mk.surface(Color(0.3, 0.29, 0.27), Vector3(4, 4, 4)))
	Mk.box(self, Vector3(130, 0.02, 6.0), Vector3(mid.x, -0.005, front + 17.0), Mk.surface(Color(0.1, 0.1, 0.11), Vector3(4, 4, 4)))
	for i in 14:
		Mk.box(self, Vector3(1.6, 0.02, 0.14), Vector3(mid.x - 45.0 + i * 7.0, 0.0, front + 17.0), Mk.mat(Color(0.6, 0.55, 0.3), 0.8))

	# Invisible bounds keep the player near the property.
	var bounds := [
		[Vector3(130, 8, 1), Vector3(mid.x, 4, -14)],
		[Vector3(130, 8, 1), Vector3(mid.x, 4, front + 21)],
		[Vector3(1, 8, 130), Vector3(-16, 4, mid.y)],
		[Vector3(1, 8, 130), Vector3(size.x + 16, 4, mid.y)],
	]
	for b in bounds:
		var body := StaticBody3D.new()
		body.position = b[1]
		var shape := BoxShape3D.new()
		shape.size = b[0]
		body.add_child(CollisionShapes.make(shape))
		add_child(body)

	# Pines around the property, kept clear of the house, yard and road.
	var bark := Mk.mat(Color(0.09, 0.07, 0.06))
	var pine := Mk.mat(Color(0.03, 0.06, 0.04))
	var clear := Rect2(-3.0, -3.0, size.x + 6.0, size.y + 6.0).merge(Rect2(dx - 22.0, front, 34.0, 21.0))
	for i in 34:
		var t := Vector2(randf_range(-15.0, size.x + 15.0), randf_range(-13.0, front + 20.0))
		if clear.has_point(t) or (t.y > front + 13.0 and t.y < front + 21.0):
			continue
		var h := randf_range(5.0, 8.0)
		Mk.solid(self, Vector3(0.5, 2.0, 0.5), Vector3(t.x, 1.0, t.y), bark)
		Mk.cyl(self, 0.0, 2.2, h, Vector3(t.x, 1.5 + h / 2.0, t.y), pine)

	# The equipment truck, with a floodlit table in front of it.
	var paint := Mk.mat(Color(0.14, 0.22, 0.25), 0.5)
	Mk.solid(self, Vector3(5.5, 2.4, 2.4), Vector3(dx, 1.5, front + 11.0), paint)
	Mk.solid(self, Vector3(1.8, 1.7, 2.3), Vector3(dx + 3.6, 1.15, front + 11.0), paint)
	for wheel in [Vector3(-1.8, 0.4, 12.3), Vector3(2.8, 0.4, 12.3), Vector3(-1.8, 0.4, 9.7), Vector3(2.8, 0.4, 9.7)]:
		var w := Mk.cyl(self, 0.42, 0.42, 0.3, Vector3(dx + wheel.x, wheel.y, front + wheel.z), Mk.mat(Color(0.03, 0.03, 0.03)))
		w.rotation.x = PI / 2
	var table := table_center()
	Mk.solid(self, Vector3(6.4, 0.9, 1.2), Vector3(table.x, 0.45, table.z), _dark_wood)
	var yard_lamp := OmniLight3D.new()
	yard_lamp.position = Vector3(table.x, 3.0, table.z)
	yard_lamp.light_color = Color(0.95, 0.95, 0.85)
	yard_lamp.light_energy = 1.6
	yard_lamp.omni_range = 9.0
	yard_lamp.shadow_enabled = true
	add_child(yard_lamp)
	Mk.cyl(self, 0.04, 0.04, 3.0, Vector3(table.x + 3.5, 1.5, table.z), _trim_mat)
	Mk.box(self, Vector3(3.5, 0.05, 0.05), Vector3(table.x + 1.75, 3.0, table.z), _trim_mat)
	Mk.sphere(self, 0.12, Vector3(table.x, 2.95, table.z), Mk.mat(Color.WHITE, 0.4, Color(1, 1, 0.9), 4.0))

	# Porch light.
	var porch := OmniLight3D.new()
	porch.position = Vector3(dx, 2.4, front + 0.7)
	porch.light_color = Color(1.0, 0.75, 0.45)
	porch.light_energy = 0.9
	porch.omni_range = 6.0
	add_child(porch)


func table_center() -> Vector3:
	return yard_anchor + Vector3(5.5, 0.0, 5.0)


func _bake_navigation() -> void:
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.1)
	NavigationServer3D.map_set_cell_height(map, 0.1)
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.1
	mesh.cell_height = 0.1
	mesh.agent_radius = 0.3
	mesh.agent_height = 0.4
	mesh.agent_max_climb = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# Baking only a thin slice at floor level keeps tabletops off the mesh and the yard out.
	mesh.filter_baking_aabb = AABB(Vector3(0.1, -0.3, 0.1), Vector3(size.x - 0.2, 0.7, size.y - 0.2))
	nav_region.navigation_mesh = mesh
	nav_region.bake_navigation_mesh(false)


func _add_doors() -> void:
	for plan in layout.doors:
		if not plan.has_door:
			continue
		var c: Vector2 = plan.center
		var door := Door.new()
		# The panel extends along local +X, so a hinge at one end fills the gap.
		if plan.along_x:
			door.position = Vector3(c.x - GAP / 2.0, 0.0, c.y)
			door.base_yaw = 0.0
		else:
			door.position = Vector3(c.x, 0.0, c.y - GAP / 2.0)
			door.base_yaw = deg_to_rad(-90.0)
		door.rotation.y = door.base_yaw
		door.swing = _swing_for(plan)
		add_child(door)
		door.setup(_door_mat)
		door.index = doors.size()
		doors.append(door)
		if plan.exterior:
			front_door = door
		elif randf() < 0.3:
			door.set_open(true, 0.01)


## Doors swing into the room rather than out into a hallway.
func _swing_for(plan: Dictionary) -> float:
	var target: Dictionary = layout.rooms.filter(func(r): return plan in r.doors)[0]
	if plan.b >= 0 and layout.rooms[plan.a].type == "hallway":
		target = layout.rooms[plan.b]
	var center: Vector2 = target.rect.get_center()
	var door_center: Vector2 = plan.center
	if plan.along_x:
		return 1.0 if center.y < door_center.y else -1.0
	return -1.0 if center.x < door_center.x else 1.0


func _add_props() -> void:
	var colors := [Color(0.5, 0.2, 0.15), Color(0.2, 0.3, 0.45), Color(0.6, 0.55, 0.4), Color(0.25, 0.4, 0.25)]
	for s in _prop_spots:
		var body := RigidBody3D.new()
		body.collision_layer = 8
		body.collision_mask = 1 | 8
		body.mass = 0.5
		body.position = s
		var prop_size := Vector3(randf_range(0.1, 0.22), randf_range(0.06, 0.2), randf_range(0.1, 0.2))
		var shape := BoxShape3D.new()
		shape.size = prop_size
		body.add_child(CollisionShapes.make(shape))
		add_child(body)
		Mk.box(body, prop_size, Vector3.ZERO, Mk.mat(colors.pick_random(), 0.7))
		props.append(body)
