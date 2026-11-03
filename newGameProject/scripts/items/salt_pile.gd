extends StaticBody3D
## A poured pile of salt. It takes footprints from ghosts with the Salt evidence.

const TRIGGER_RANGE := 1.1

var pile_id := 0
var disturbed := false
var _pile: MeshInstance3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("salt_piles")
	_pile = Mk.cyl(self, 0.12, 0.34, 0.05, Vector3(0, 0.025, 0), Mk.mat(Color(0.92, 0.92, 0.9), 0.9))
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.2, 0.8)
	add_child(CollisionShapes.make(shape, Vector3(0, 0.1, 0)))


func _physics_process(_delta: float) -> void:
	if disturbed or Game.ghost == null:
		return
	var ghost := Game.ghost
	if ghost.has_evidence(GhostDB.Ev.SALT) and ghost.global_position.distance_to(global_position) < TRIGGER_RANGE:
		_leave_prints(ghost)


func _leave_prints(ghost: Ghost) -> void:
	disturbed = true
	_pile.scale = Vector3(1.5, 0.35, 1.5)
	var dark := Mk.mat(Color(0.05, 0.15, 0.12), 0.8, Color(0.1, 0.6, 0.45), 1.2)
	var dir := (global_position - ghost.global_position)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.05 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP)
	for i in 6:
		var offset := dir * (i - 2.5) * 0.32 + side * (0.09 if i % 2 == 0 else -0.09)
		var print_mark := Mk.box(self, Vector3(0.09, 0.012, 0.2), offset + Vector3(0, 0.06, 0), dark)
		print_mark.rotation.y = atan2(dir.x, dir.z)


func get_prompt() -> String:
	return "Scoop up salt (footprints in it!)" if disturbed else "Scoop up salt (undisturbed)"


func interact(player: Player) -> void:
	var item := player.active_item()
	if item != null and item.item_id == "salt":
		item.refill()
		item.net_push()
		Net.remove_salt(pile_id)
	else:
		Game.toast.emit("You need the salt in hand to scoop this up.")
