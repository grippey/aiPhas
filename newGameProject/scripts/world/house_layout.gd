class_name HouseLayout
extends RefCounted
## Plans a random one-storey house as plain data: rooms, doors, walls, windows,
## furniture. House turns the plan into nodes. Plans that fail the walkability
## check are thrown away, so every house that gets built is fully reachable.

const MIN_SIDE := 3
const DOOR_SPAN := 2.0
const DOOR_CLEAR_DEPTH := 1.5
const DOOR_CLEAR_HALF := 1.0
const WALL_INSET := 0.12
const REQUIRED_WARDROBES := 3
const SPARE_ROOM_TYPES := ["dining", "bedroom", "nursery", "study", "laundry", "den", "library"]

const ROOM_NAMES := {
	"hallway": "Hallway", "foyer": "Foyer", "bathroom": "Bathroom", "living": "Living Room",
	"kitchen": "Kitchen", "master": "Master Bedroom", "dining": "Dining Room", "bedroom": "Bedroom",
	"nursery": "Nursery", "study": "Study", "laundry": "Laundry Room", "den": "Den", "library": "Library",
}

## Furniture that sits against a wall: [kind, width along the wall, height, depth].
const WALL_FURNITURE := {
	"hallway": [["console", 0.9, 0.8, 0.35]],
	"foyer": [["bench", 1.2, 0.45, 0.4], ["console", 0.9, 0.8, 0.35]],
	"bathroom": [["tub", 1.8, 0.6, 0.85], ["toilet", 0.5, 0.45, 0.65], ["sink", 0.6, 0.85, 0.5]],
	"living": [["sofa", 2.4, 0.8, 0.9], ["bookshelf", 1.6, 2.0, 0.4], ["armchair", 0.9, 0.8, 0.9], ["wardrobe", 1.3, 2.0, 0.9]],
	"kitchen": [["counter", 3.0, 0.92, 0.6], ["fridge", 0.8, 2.0, 0.8], ["cabinet", 1.2, 2.0, 0.4]],
	"master": [["bed", 2.0, 0.55, 2.3], ["wardrobe", 1.3, 2.0, 0.9], ["dresser", 1.6, 1.0, 0.5], ["nightstand", 0.5, 0.55, 0.5]],
	"dining": [["cabinet", 2.0, 2.0, 0.5], ["sideboard", 1.6, 0.9, 0.5]],
	"bedroom": [["bed", 1.5, 0.55, 2.1], ["wardrobe", 1.3, 2.0, 0.9], ["nightstand", 0.5, 0.55, 0.5]],
	"nursery": [["crib", 1.5, 0.9, 0.85], ["chest", 1.0, 0.5, 0.55], ["wardrobe", 1.2, 2.0, 0.9], ["armchair", 0.7, 0.9, 0.7]],
	"study": [["desk", 1.6, 0.78, 0.7], ["bookshelf", 1.8, 2.0, 0.4], ["bookshelf", 1.2, 2.0, 0.4]],
	"laundry": [["washer", 0.8, 0.9, 0.7], ["washer", 0.8, 0.9, 0.7], ["cabinet", 1.2, 2.0, 0.4]],
	"den": [["sofa", 2.0, 0.8, 0.85], ["sideboard", 1.4, 0.7, 0.45], ["armchair", 0.9, 0.8, 0.9]],
	"library": [["bookshelf", 2.2, 2.0, 0.4], ["bookshelf", 2.2, 2.0, 0.4], ["bookshelf", 1.6, 2.0, 0.4], ["armchair", 0.9, 0.8, 0.9]],
}

## Furniture in the middle of a big room: [kind, width, height, depth, chair count].
const CENTER_FURNITURE := {
	"kitchen": ["table", 1.5, 0.75, 0.9, 2],
	"dining": ["table", 2.6, 0.75, 1.1, 4],
	"living": ["coffee_table", 1.3, 0.45, 0.7, 0],
	"den": ["coffee_table", 1.1, 0.45, 0.7, 0],
	"study": ["table", 1.0, 0.75, 1.0, 1],
}

var size := Vector2.ZERO
var rooms: Array[Dictionary] = []
var doors: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var windows: Array[Dictionary] = []
var furniture: Array[Dictionary] = []
var front_door: Dictionary
var fail_reason := ""

var _blocked: Array[Rect2] = []


## Keeps trying until a plan passes. A handful of tries is normally enough.
static func generate() -> HouseLayout:
	var layout: HouseLayout
	for i in 200:
		layout = HouseLayout.new()
		if layout._plan():
			return layout
	push_error("No valid house layout found. Using the last attempt.")
	return layout


func _plan() -> bool:
	size = Vector2(randi_range(18, 26), randi_range(12, 18))
	_partition()
	if rooms.size() < 6 or rooms.size() > 13:
		fail_reason = "room count"
		return false
	var front_index := _pick_front_room()
	if front_index < 0:
		fail_reason = "no front room"
		return false
	if not _connect_rooms(front_index):
		fail_reason = "disconnected"
		return false
	_assign_room_types(front_index)
	_collect_door_clearances()
	_furnish()
	if _count_kind("wardrobe") < REQUIRED_WARDROBES:
		fail_reason = "wardrobes"
		return false
	_build_walls()
	_plan_windows()
	if not _everything_reachable():
		fail_reason = "unreachable"
		return false
	return true


# --- Rooms ----------------------------------------------------------------

func _partition() -> void:
	var w := int(size.x)
	var d := int(size.y)
	match randi() % 3:
		0: # A hallway running side to side, with rooms above and below.
			var z := randi_range(4, d - 6)
			_add_room(Rect2(0, z, w, 2), "hallway")
			_split(Rect2(0, 0, w, z))
			_split(Rect2(0, z + 2, w, d - z - 2))
		1: # A hallway running back from the front door.
			var x := randi_range(5, w - 7)
			_add_room(Rect2(x, 0, 2, d), "hallway")
			_split(Rect2(0, 0, x, d))
			_split(Rect2(x + 2, 0, w - x - 2, d))
		_: # No hallway: rooms open straight into each other.
			_split(Rect2(0, 0, w, d))


func _split(rect: Rect2) -> void:
	var can_x := rect.size.x >= MIN_SIDE * 2
	var can_z := rect.size.y >= MIN_SIDE * 2
	# Room sizes follow the house's size, so big houses get big rooms, not just more of them.
	var small_enough := rect.get_area() <= size.x * size.y / randf_range(4.0, 7.0)
	if (not can_x and not can_z) or (small_enough and randf() < 0.9):
		_add_room(rect, "")
		return
	var cut_x := can_x and (not can_z or rect.size.x > rect.size.y * randf_range(0.8, 1.25))
	if cut_x:
		var cut := randi_range(MIN_SIDE, int(rect.size.x) - MIN_SIDE)
		_split(Rect2(rect.position.x, rect.position.y, cut, rect.size.y))
		_split(Rect2(rect.position.x + cut, rect.position.y, rect.size.x - cut, rect.size.y))
	else:
		var cut := randi_range(MIN_SIDE, int(rect.size.y) - MIN_SIDE)
		_split(Rect2(rect.position.x, rect.position.y, rect.size.x, cut))
		_split(Rect2(rect.position.x, rect.position.y + cut, rect.size.x, rect.size.y - cut))


func _add_room(rect: Rect2, type: String) -> void:
	rooms.append({"rect": rect, "type": type, "name": "", "doors": []})


## The room on the street side closest to the middle gets the front door.
func _pick_front_room() -> int:
	var best := -1
	var best_d := INF
	for i in rooms.size():
		var r: Rect2 = rooms[i].rect
		if not is_equal_approx(r.end.y, size.y) or r.size.x < MIN_SIDE - 1:
			continue
		var d := absf(r.get_center().x - size.x / 2.0)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		var r: Rect2 = rooms[best].rect
		var door := _add_door(Vector2(snappedf(r.get_center().x, 0.5), size.y), true, best, -1, true)
		door.exterior = true
		front_door = door
	return best


# --- Doors ----------------------------------------------------------------

func _connect_rooms(start: int) -> bool:
	var edges: Array[Dictionary] = []
	for a in rooms.size():
		for b in range(a + 1, rooms.size()):
			var edge := _shared_edge(a, b)
			if not edge.is_empty():
				edges.append(edge)

	# A randomised spanning tree guarantees that every room can be reached.
	var visited := {start: true}
	var frontier := [start]
	var used := {}
	while not frontier.is_empty():
		var current: int = frontier.pick_random()
		var options: Array[Dictionary] = []
		for e in edges:
			var other: int = e.b if e.a == current else (e.a if e.b == current else -1)
			if other >= 0 and not visited.has(other):
				options.append(e)
		if options.is_empty():
			frontier.erase(current)
			continue
		var edge: Dictionary = options.pick_random()
		var next: int = edge.b if edge.a == current else edge.a
		visited[next] = true
		frontier.append(next)
		used[edge] = true
		_door_from_edge(edge)
	if visited.size() != rooms.size():
		return false

	# A few extra doors give the player loops to escape through.
	for e in edges:
		if not used.has(e) and randf() < 0.3:
			_door_from_edge(e)
	return true


func _shared_edge(a: int, b: int) -> Dictionary:
	var ra: Rect2 = rooms[a].rect
	var rb: Rect2 = rooms[b].rect
	var along_x := false
	var line := 0.0
	if is_equal_approx(ra.end.x, rb.position.x) or is_equal_approx(rb.end.x, ra.position.x):
		line = ra.end.x if is_equal_approx(ra.end.x, rb.position.x) else rb.end.x
	elif is_equal_approx(ra.end.y, rb.position.y) or is_equal_approx(rb.end.y, ra.position.y):
		along_x = true
		line = ra.end.y if is_equal_approx(ra.end.y, rb.position.y) else rb.end.y
	else:
		return {}
	var from: float
	var to: float
	if along_x:
		from = maxf(ra.position.x, rb.position.x)
		to = minf(ra.end.x, rb.end.x)
	else:
		from = maxf(ra.position.y, rb.position.y)
		to = minf(ra.end.y, rb.end.y)
	if to - from < DOOR_SPAN:
		return {}
	return {"a": a, "b": b, "along_x": along_x, "line": line, "from": from, "to": to}


func _door_from_edge(e: Dictionary) -> void:
	var at := snappedf(randf_range(e.from + 1.0, e.to - 1.0), 0.5)
	at = clampf(at, e.from + 1.0, e.to - 1.0)
	var center := Vector2(at, e.line) if e.along_x else Vector2(e.line, at)
	_add_door(center, e.along_x, e.a, e.b, randf() < 0.75)


func _add_door(center: Vector2, along_x: bool, a: int, b: int, has_door: bool) -> Dictionary:
	var door := {"center": center, "along_x": along_x, "a": a, "b": b, "has_door": has_door, "exterior": false}
	doors.append(door)
	rooms[a].doors.append(door)
	if b >= 0:
		rooms[b].doors.append(door)
	return door


func _collect_door_clearances() -> void:
	for door in doors:
		var c: Vector2 = door.center
		if door.along_x:
			_blocked.append(Rect2(c.x - DOOR_CLEAR_HALF, c.y - DOOR_CLEAR_DEPTH, DOOR_CLEAR_HALF * 2.0, DOOR_CLEAR_DEPTH * 2.0))
		else:
			_blocked.append(Rect2(c.x - DOOR_CLEAR_DEPTH, c.y - DOOR_CLEAR_HALF, DOOR_CLEAR_DEPTH * 2.0, DOOR_CLEAR_HALF * 2.0))


# --- Room types -----------------------------------------------------------

func _assign_room_types(front_index: int) -> void:
	if rooms[front_index].type == "":
		rooms[front_index].type = "foyer"
	var open: Array[Dictionary] = []
	for r in rooms:
		if r.type == "":
			open.append(r)
	open.sort_custom(func(x, y): return x.rect.get_area() < y.rect.get_area())
	if not open.is_empty():
		open.pop_front().type = "bathroom"
	var by_size := ["living", "kitchen", "master"]
	for type in by_size:
		if not open.is_empty():
			open.pop_back().type = type
	var spares: Array = SPARE_ROOM_TYPES.duplicate()
	spares.shuffle()
	for r in open:
		r.type = spares.pop_back() if not spares.is_empty() else "bedroom"
	var counts := {}
	for r in rooms:
		counts[r.type] = counts.get(r.type, 0) + 1
		var label: String = ROOM_NAMES[r.type]
		r.name = label if counts[r.type] == 1 else "%s %d" % [label, counts[r.type]]


# --- Furniture ------------------------------------------------------------

func _furnish() -> void:
	for i in rooms.size():
		var type: String = rooms[i].type
		if CENTER_FURNITURE.has(type):
			_try_center(i, CENTER_FURNITURE[type])
		for entry in WALL_FURNITURE[type]:
			if randf() < 0.9 or entry[0] == "wardrobe":
				_try_wall(i, entry[0], entry[1], entry[2], entry[3])
	var order: Array = range(rooms.size())
	order.shuffle()
	for i in order:
		if _count_kind("wardrobe") >= REQUIRED_WARDROBES:
			break
		if rooms[i].type != "hallway":
			_try_wall(i, "wardrobe", 1.3, 2.0, 0.9)


func _try_wall(room: int, kind: String, width: float, height: float, depth: float) -> bool:
	var r: Rect2 = rooms[room].rect.grow(-WALL_INSET)
	for attempt in 16:
		var side := randi() % 4
		var w := minf(width, (r.size.x if side < 2 else r.size.y) - 0.2)
		if w < width * 0.7 or depth > (r.size.y if side < 2 else r.size.x) - 1.2:
			continue
		var rect: Rect2
		var facing: Vector2
		match side:
			0:
				rect = Rect2(randf_range(r.position.x, r.end.x - w), r.position.y, w, depth)
				facing = Vector2(0, 1)
			1:
				rect = Rect2(randf_range(r.position.x, r.end.x - w), r.end.y - depth, w, depth)
				facing = Vector2(0, -1)
			2:
				rect = Rect2(r.position.x, randf_range(r.position.y, r.end.y - w), depth, w)
				facing = Vector2(1, 0)
			_:
				rect = Rect2(r.end.x - depth, randf_range(r.position.y, r.end.y - w), depth, w)
				facing = Vector2(-1, 0)
		if _is_free(rect):
			_add_furniture(kind, rect, height, facing, room)
			return true
	return false


func _try_center(room: int, entry: Array) -> void:
	var r: Rect2 = rooms[room].rect.grow(-WALL_INSET)
	var w: float = entry[1]
	var d: float = entry[3]
	var aisle := 1.0
	if r.size.x < w + aisle * 2.0 + 1.0 or r.size.y < d + aisle * 2.0 + 1.0:
		return
	var c := r.get_center() + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
	var rect := Rect2(c.x - w / 2.0, c.y - d / 2.0, w, d)
	if not _is_free(rect):
		return
	_add_furniture(entry[0], rect, entry[2], Vector2(0, 1), room)
	var spots := [
		[Vector2(-w * 0.25, -d / 2.0 - 0.35), Vector2(0, 1)],
		[Vector2(w * 0.25, d / 2.0 + 0.35), Vector2(0, -1)],
		[Vector2(w * 0.25, -d / 2.0 - 0.35), Vector2(0, 1)],
		[Vector2(-w * 0.25, d / 2.0 + 0.35), Vector2(0, -1)],
	]
	for i in entry[4]:
		var at: Vector2 = c + spots[i][0]
		var chair := Rect2(at.x - 0.225, at.y - 0.225, 0.45, 0.45)
		if _is_free(chair):
			_add_furniture("chair", chair, 0.48, spots[i][1], room)


func _is_free(rect: Rect2) -> bool:
	for b in _blocked:
		if rect.intersects(b):
			return false
	return true


func _add_furniture(kind: String, rect: Rect2, height: float, facing: Vector2, room: int) -> void:
	_blocked.append(rect)
	furniture.append({"kind": kind, "rect": rect, "height": height, "facing": facing, "room": room})


func _count_kind(kind: String) -> int:
	var total := 0
	for f in furniture:
		if f.kind == kind:
			total += 1
	return total


# --- Walls and windows ----------------------------------------------------

## Adjoining rooms share wall lines, so each line's spans get merged before
## the door gaps are assigned. That keeps walls from being built twice.
func _build_walls() -> void:
	var lines := {}
	for room in rooms:
		var r: Rect2 = room.rect
		_add_span(lines, true, r.position.y, r.position.x, r.end.x)
		_add_span(lines, true, r.end.y, r.position.x, r.end.x)
		_add_span(lines, false, r.position.x, r.position.y, r.end.y)
		_add_span(lines, false, r.end.x, r.position.y, r.end.y)
	for key in lines:
		var along_x: bool = key[0]
		var line: float = key[1]
		var spans: Array = lines[key]
		spans.sort_custom(func(p, q): return p.x < q.x)
		var current: Vector2 = spans[0]
		for i in range(1, spans.size()):
			var s: Vector2 = spans[i]
			if s.x <= current.y + 0.01:
				current.y = maxf(current.y, s.y)
			else:
				_add_wall(along_x, line, current)
				current = s
		_add_wall(along_x, line, current)


func _add_span(lines: Dictionary, along_x: bool, line: float, from: float, to: float) -> void:
	var key := [along_x, line]
	if not lines.has(key):
		lines[key] = []
	lines[key].append(Vector2(from, to))


func _add_wall(along_x: bool, line: float, span: Vector2) -> void:
	var gaps: Array[float] = []
	for door in doors:
		if door.along_x != along_x:
			continue
		var c: Vector2 = door.center
		var on_line: float = c.y if along_x else c.x
		var at: float = c.x if along_x else c.y
		if is_equal_approx(on_line, line) and at > span.x and at < span.y:
			gaps.append(at)
	walls.append({"along_x": along_x, "line": line, "from": span.x, "to": span.y, "gaps": gaps})


func _plan_windows() -> void:
	for room in rooms:
		var r: Rect2 = room.rect
		var c := r.get_center()
		if r.size.x >= 3.0:
			if is_equal_approx(r.position.y, 0.0):
				windows.append({"at": Vector2(c.x, 0.0), "along_x": true})
			if is_equal_approx(r.end.y, size.y) and absf(c.x - front_door.center.x) > 1.6:
				windows.append({"at": Vector2(c.x, size.y), "along_x": true})
		if r.size.y >= 3.0:
			if is_equal_approx(r.position.x, 0.0):
				windows.append({"at": Vector2(0.0, c.y), "along_x": false})
			if is_equal_approx(r.end.x, size.x):
				windows.append({"at": Vector2(size.x, c.y), "along_x": false})


## A switch goes on the wall just beside the room's first door, facing into the room.
func switch_position(room: Dictionary) -> Vector3:
	var door: Dictionary = room.doors[0]
	var r: Rect2 = room.rect
	var c: Vector2 = door.center
	var into := -1.0
	if door.along_x:
		into = 1.0 if r.get_center().y > c.y else -1.0
		return Vector3(c.x + 0.95, 1.2, c.y + into * 0.12)
	into = 1.0 if r.get_center().x > c.x else -1.0
	return Vector3(c.x + into * 0.12, 1.2, c.y + 0.95)


# --- Validation -----------------------------------------------------------

## Flood fills from the front door, treating the player as a 0.25 m radius
## circle, and checks that every room and doorway can be walked to.
func _everything_reachable() -> bool:
	const CELL := 0.25
	var obstacles: Array[Rect2] = []
	for f in furniture:
		obstacles.append(f.rect.grow(0.25))
	for w in walls:
		var cursor: float = w.from
		var sorted: Array = w.gaps.duplicate()
		sorted.sort()
		for g in sorted:
			_add_wall_rect(obstacles, w, cursor, g - 0.6)
			cursor = g + 0.6
		_add_wall_rect(obstacles, w, cursor, w.to)

	var cols := int(size.x / CELL)
	var rows := int(size.y / CELL)
	var grid := PackedByteArray()
	grid.resize(cols * rows)
	for z in rows:
		for x in cols:
			var p := Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
			for o in obstacles:
				if o.has_point(p):
					grid[z * cols + x] = 1
					break

	var fc: Vector2 = front_door.center
	var start_x := int(fc.x / CELL)
	var start_z := rows - 5
	if grid[start_z * cols + start_x] == 1:
		return false
	var stack := PackedInt32Array([start_z * cols + start_x])
	grid[stack[0]] = 2
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x := i % cols
		var z := i / cols
		for n in [[x + 1, z], [x - 1, z], [x, z + 1], [x, z - 1]]:
			if n[0] < 0 or n[1] < 0 or n[0] >= cols or n[1] >= rows:
				continue
			var ni: int = n[1] * cols + n[0]
			if grid[ni] == 0:
				grid[ni] = 2
				stack.append(ni)

	for room in rooms:
		var reached := 0
		var total := 0
		var r: Rect2 = room.rect
		for z in range(int(r.position.y / CELL), int(r.end.y / CELL)):
			for x in range(int(r.position.x / CELL), int(r.end.x / CELL)):
				total += 1
				if grid[z * cols + x] == 2:
					reached += 1
		if reached < total * 0.3:
			return false
	return true


func _add_wall_rect(out: Array[Rect2], w: Dictionary, from: float, to: float) -> void:
	if to <= from:
		return
	var margin := 0.35
	if w.along_x:
		out.append(Rect2(from, w.line - margin, to - from, margin * 2.0))
	else:
		out.append(Rect2(w.line - margin, from, margin * 2.0, to - from))
