class_name Item
extends StaticBody3D
## Base class for all the equipment. An item is either held by someone or sitting in
## the world, where E picks it up. Every player has a copy of every item. The player
## using one changes their copy and sends the properties in net_props to the others.

## How close to the trap a bait item has to be, for items that bait by being nearby.
const BAIT_RANGE := 5.0

var net_id := -1
var item_id := ""
var display_name := ""
var description := ""
var held := false
var on_table := true
var holder: Actor = null
var hand_offset := Vector3.ZERO
var hand_rotation := Vector3.ZERO
var collider_size := Vector3(0.3, 0.3, 0.3)
var collider_center := Vector3(0, 0.15, 0)
## The properties that describe this item's state, for other players' copies.
var net_props: Array[String] = []


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group("items")
	_define()
	_build()
	var shape := BoxShape3D.new()
	shape.size = collider_size + Vector3(0.1, 0.1, 0.1)
	add_child(CollisionShapes.make(shape, collider_center))


## Sets the name, id and description. Subclasses must implement this.
func _define() -> void:
	pass


## Builds the item's model. Subclasses must implement this.
func _build() -> void:
	pass


## Runs only on the machine of the player using it. Player sends the result to everyone.
func use() -> void:
	pass


## The readout shown on the HUD while the item is in hand.
func status_text() -> String:
	return ""


## Called when the item stops or starts being the one in hand.
func _on_stowed(_stowed: bool) -> void:
	pass


func _on_placed() -> void:
	pass


func _on_picked_up() -> void:
	pass


## Called after another player's change has been copied onto this item.
func _on_net_state() -> void:
	pass


func net_state() -> Dictionary:
	var state := {}
	for prop in net_props:
		state[prop] = get(prop)
	return state


func apply_net_state(state: Dictionary) -> void:
	for prop in state:
		if prop in net_props:
			set(prop, state[prop])
	_on_net_state()


func net_push() -> void:
	if not net_props.is_empty():
		Net.push_item_state(self)


func get_prompt() -> String:
	return "Pick up %s" % display_name


func interact(player: Player) -> void:
	player.pick_up(self)


func set_stowed(stowed: bool) -> void:
	visible = not stowed
	_on_stowed(stowed)


func set_held(by: Actor, value: bool) -> void:
	held = value
	holder = by
	if value:
		on_table = false
		collision_layer = 0
		reparent(by.hand, false)
		position = hand_offset
		rotation = hand_rotation
		_on_picked_up()


## Puts the item on the equipment table at the start of a run.
func set_on_table(pos: Vector3) -> void:
	global_position = pos
	rotation = Vector3.ZERO
	on_table = true


func place_at(pos: Vector3) -> void:
	held = false
	holder = null
	on_table = false
	collision_layer = 4
	visible = true
	reparent(Game.main, false)
	global_position = pos
	rotation = Vector3(0, randf_range(-PI, PI), 0)
	_on_placed()


## Whether this item is keeping the given ghost inside the trap.
## Items that bait by being nearby only need is_bait_on().
func bait_works(_ghost: Ghost, trap: Item) -> bool:
	return is_bait_on() and global_position.distance_to(trap.global_position) <= BAIT_RANGE


func is_bait_on() -> bool:
	return false
