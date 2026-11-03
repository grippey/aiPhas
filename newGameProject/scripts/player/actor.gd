class_name Actor
extends CharacterBody3D
## Anyone in the game, local or remote: what they carry and where they're looking.
## Player adds the controls. RemotePlayer follows the network and draws a body.

const SLOTS := 3
const FLAG_CROUCH := 1
const FLAG_HIDING := 2
const FLAG_SAFE := 4

var peer_id := 1
var nickname := ""
var camera: Node3D
var hand: Node3D
var slots: Array = [null, null, null]
var active_slot := 0
var crouching := false
var dead := false
var sanity := 100.0


func is_hidden() -> bool:
	return false


func is_hiding() -> bool:
	return false


func active_item() -> Item:
	return slots[active_slot]


func aim_floor_point() -> Variant:
	return null


func change_sanity(amount: float) -> void:
	Net.hurt_sanity(peer_id, amount)


func apply_net_state(_pos: Vector3, _yaw: float, _pitch: float, _flags: int, _sanity: float) -> void:
	pass


func on_emote(_id: String) -> void:
	pass


func on_caught() -> void:
	pass


## The same steps run on every machine, so everyone agrees on who holds what.
func apply_take(item: Item) -> void:
	var target := active_slot
	if slots[target] != null:
		target = slots.find(null)
	# A full hotbar swaps the held item for this one, leaving it in the same spot.
	if target == -1:
		var old: Item = active_item()
		var pos := item.global_position
		apply_release(old)
		old.place_at(pos)
		target = active_slot
	if target != active_slot and active_item() != null:
		active_item().set_stowed(true)
	active_slot = target
	slots[target] = item
	item.set_held(self, true)
	item.set_stowed(false)
	_after_take()


func _after_take() -> void:
	pass


func apply_release(item: Item) -> void:
	var at := slots.find(item)
	if at >= 0:
		slots[at] = null
	item.set_held(null, false)


func apply_select(index: int) -> void:
	if index == active_slot:
		return
	if active_item() != null:
		active_item().set_stowed(true)
	active_slot = index
	if active_item() != null:
		active_item().set_stowed(false)
