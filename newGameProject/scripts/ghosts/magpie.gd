extends Ghost
## A thief. It heads for equipment you've set down inside the house and drops it
## in another room. The trap is the one thing it leaves alone.

const SNATCH_RANGE := 2.0

var _snatch_timer := 8.0


func _on_tick(delta: float) -> void:
	_snatch_timer -= delta
	if _snatch_timer > 0.0:
		return
	var item := _nearest_loot(SNATCH_RANGE)
	if item != null:
		_snatch_timer = 10.0
		_steal(item)


func default_roam_target() -> Vector3:
	var item := _nearest_loot(40.0)
	if item != null and randf() < 0.7:
		return item.global_position
	return super.default_roam_target()


func _nearest_loot(max_range: float) -> Item:
	var best: Item = null
	var best_d := max_range
	for it in get_tree().get_nodes_in_group("items"):
		if it.held or it.item_id == "ghost_trap" or not Game.house.contains(it.global_position):
			continue
		var d: float = it.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = it
	return best


func _steal(item: Item) -> void:
	var rooms: Array = Game.house.rooms.filter(func(r): return r != current_room)
	var spot := Game.house.nav_point(rooms.pick_random().random_point())
	Net.sfx_all("thump", item.global_position, 2.0, 1.5)
	mark_event(item.global_position)
	Net.place_item(item, spot)
	if target_in_house():
		Net.toast_all("Something just moved your %s." % item.display_name)
		target.change_sanity(-2.0)


func do_activity() -> void:
	if randf() < 0.5:
		act_throw(false)
	else:
		act_door(false)


func spirit_lines() -> Array:
	return ["Mine now.", "Shiny.", "Where'd it go?", "Finders keepers.", "Give it here."]
