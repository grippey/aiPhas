extends Ghost
## Copies another ghost's stats, colour and main habit, then moves on to a new one.
## Its evidence never changes. The Drifter is left out of the copies because its
## wall-walking would strand the Changeling off the navigation mesh.

const CHANGE_MIN := 45.0
const CHANGE_MAX := 75.0
const COPYABLE := ["mourner", "rattler", "gloam", "watcher", "cinder", "howler", "fury", "gaunt"]

var copying := ""
var _change_timer := 0.0
var _observed := false
var _douse_timer := 3.0


func _configure() -> void:
	_change_timer = randf_range(CHANGE_MIN, CHANGE_MAX)
	copying = COPYABLE.pick_random()
	_apply_copy()


func _ready() -> void:
	super._ready()
	_set_tint(GhostDB.by_id(copying).color)


func _on_tick(delta: float) -> void:
	_change_timer -= delta
	if _change_timer <= 0.0 and state != State.HUNT:
		_change_timer = randf_range(CHANGE_MIN, CHANGE_MAX)
		var next: Array = COPYABLE.filter(func(id): return id != copying)
		copying = next.pick_random()
		_apply_copy()
		_set_tint(GhostDB.by_id(copying).color)
		act_manifest()
	match copying:
		"watcher":
			_observed = seen_by_anyone(42.0, 30.0)
		"gloam":
			_douse_timer -= delta
			if _douse_timer <= 0.0 and current_room.on and state != State.HUNT:
				_douse_timer = randf_range(2.0, 5.0)
				Net.room_light(current_room, false)
				mark_event(global_position)
		"gaunt":
			if target_in_house() and global_position.distance_to(target.global_position) < 6.0:
				target.change_sanity(-delta * 0.6)


func _apply_copy() -> void:
	var t := GhostDB.by_id(copying)
	speed = t.speed
	aggressiveness = t.aggressiveness
	passiveness = t.passiveness
	activeness = t.activeness
	_observed = false


func _set_tint(c: Color) -> void:
	_material.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))


func can_hunt() -> bool:
	match copying:
		"fury":
			return true
		"mourner":
			return target.sanity < 25.0
		"gloam":
			var room := Game.house.room_at(target.global_position)
			return room != null and not room.on and super.can_hunt()
	return super.can_hunt()


func movement_multiplier() -> float:
	return 0.0 if copying == "watcher" and _observed else 1.0


func default_roam_target() -> Vector3:
	match copying:
		"mourner":
			return home_room.random_point()
		"fury", "gaunt", "watcher":
			if target_in_house() and randf() < 0.6:
				return target.global_position
	return super.default_roam_target()


func spirit_lines() -> Array:
	return GhostDB.by_id(copying).get("lines", ["Who am I?", "I can be anyone.", "Do you know me?", "Just like you.", "Whose voice is this?"])


func net_extra() -> String:
	return copying


func apply_net_extra(value: String) -> void:
	if value != copying and value != "":
		copying = value
		_set_tint(GhostDB.by_id(copying).color)
