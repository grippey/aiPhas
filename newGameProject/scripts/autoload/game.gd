extends Node
## Global run state: sanity, the notebook, hunts and the win/lose flow. Every player
## has a copy. Anything that must agree between players arrives through Net.

signal log_added(text: String)
signal toast(text: String)
signal subtitle(text: String)
signal hunt_changed(active: bool)
signal photo_taken(texture: Texture2D)
signal finished(won: bool, message: String)
signal talk_requested(bystander: Bystander)
signal play_started

## No hunts until someone has spent this long inside.
const INSIDE_GRACE := 60.0
const CLAP_NOISE := 13.0
const TAUNT_RANGE := 9.0

const SaltPile := preload("res://scripts/items/salt_pile.gd")
const IronStake := preload("res://scripts/items/iron_stake.gd")

var main: Node3D
var house: House
var player: Player
var ghost: Ghost
var hud: CanvasLayer
var bystanders: BystanderManager

## peer id -> Actor, including this player's own Player.
var actors := {}
var items: Array[Item] = []
var salt_piles := {}

var suspicion := 0.0
## Seconds until the police arrive, or below zero if nobody has called them.
var police_left := -1.0
var end_title := ""
var emote_wheel_open := false

var sanity := 100.0
var hunting := false
var over := false
var time_inside := 0.0
var input_locked := false
var waiting_for_players := true
## Set a ghost id here to always get that ghost while testing. Empty means random.
var force_ghost_id := ""

var tuned_ghost_id := ""
var evidence_marks := {}
var field_log: Array[String] = []
var photos: Array[Texture2D] = []


func reset_run() -> void:
	sanity = 100.0
	hunting = false
	over = false
	time_inside = 0.0
	input_locked = false
	waiting_for_players = true
	tuned_ghost_id = ""
	evidence_marks = {}
	field_log = []
	photos = []
	suspicion = 0.0
	police_left = -1.0
	end_title = ""
	emote_wheel_open = false
	actors = {}
	items = []
	salt_piles = {}


func everyone_ready() -> void:
	waiting_for_players = false
	play_started.emit()


func item(id: int) -> Item:
	return items[id] if id >= 0 and id < items.size() else null


func door(index: int) -> Door:
	if house == null or index < 0 or index >= house.doors.size():
		return null
	return house.doors[index]


func room(index: int) -> Room:
	if house == null or index < 0 or index >= house.rooms.size():
		return null
	return house.rooms[index]


func bystander(id: int) -> Bystander:
	return bystanders.by_id.get(id) if bystanders != null else null


func add_log(text: String) -> void:
	field_log.append(text)
	log_added.emit(text)


func change_sanity(amount: float) -> void:
	sanity = clampf(sanity + amount, 0.0, 100.0)


func change_suspicion(amount: float) -> void:
	Net.add_suspicion(amount)


## A loud event in the house. People outside notice, or come to look.
func add_commotion(amount: float) -> void:
	if bystanders != null and Net.is_host():
		bystanders.add_commotion(amount)


func actor_in_house(actor: Actor) -> bool:
	return actor != null and house != null and house.contains(actor.global_position)


func player_in_house() -> bool:
	return actor_in_house(player)


func living_actors() -> Array[Actor]:
	var out: Array[Actor] = []
	for id in actors:
		var a: Actor = actors[id]
		if is_instance_valid(a) and not a.dead:
			out.append(a)
	return out


func set_hunting(active: bool) -> void:
	if hunting != active:
		Net.set_hunting(active)


func apply_hunting(active: bool) -> void:
	if hunting == active:
		return
	hunting = active
	Sfx.set_hunt_audio(active)
	hunt_changed.emit(active)


## Hands a sound to the ghost, which only the host runs. Items exist on every
## player's machine, so the other copies of a noisy item can safely do nothing.
func make_noise(pos: Vector3, radius: float) -> void:
	if ghost != null and Net.is_host():
		ghost.hear(pos, radius)


func placed_trap() -> Item:
	for it in items:
		if it.item_id == "ghost_trap" and not it.held and not it.on_table:
			return it
	return null


func add_salt_pile(id: int, pos: Vector3) -> void:
	var pile: StaticBody3D = SaltPile.new()
	pile.pile_id = id
	main.add_child(pile)
	pile.global_position = pos
	salt_piles[id] = pile
	Sfx.play_at("flame", pos, -14.0, 2.0)


func remove_salt_pile(id: int) -> void:
	var pile: Node = salt_piles.get(id)
	if pile != null and is_instance_valid(pile):
		pile.queue_free()
	salt_piles.erase(id)


func add_iron_stake(pos: Vector3) -> void:
	var stake: Node3D = IronStake.new()
	main.add_child(stake)
	stake.global_position = pos
	Sfx.play_at("thump", pos, 2.0, 1.3)


## What an emote does to the wider world. Runs on the host, whoever did the emote.
func handle_emote(actor: Actor, id: String) -> void:
	var pos := actor.global_position
	if bystanders != null:
		bystanders.on_emote(id, pos)
	match id:
		"clap":
			make_noise(pos, CLAP_NOISE)
		"taunt":
			make_noise(pos, CLAP_NOISE)
			if ghost != null and actor_in_house(actor) and ghost.global_position.distance_to(pos) < TAUNT_RANGE:
				ghost.provoke()
				actor.change_sanity(-3.0)


# --- Winning and losing ---------------------------------------------------

## Runs on the host when the ghost reaches someone.
func player_caught(actor: Actor) -> void:
	if not actor.dead:
		Net.player_caught(actor.peer_id)


func apply_player_caught(peer: int) -> void:
	var actor: Actor = actors.get(peer)
	if actor == null or actor.dead:
		return
	actor.dead = true
	var everyone_down := living_actors().is_empty()
	if actor == player:
		Sfx.play_ui("scream")
		player.jumpscare(ghost)
	elif not everyone_down:
		toast.emit("%s was caught!" % actor.nickname)
		Sfx.play_at("wail", actor.global_position, 4.0)
	actor.on_caught()
	if Net.is_host():
		for it in actor.slots.duplicate():
			if it != null:
				Net.place_item(it, actor.global_position + Vector3(randf_range(-0.4, 0.4), 0.02, randf_range(-0.4, 0.4)))
		if everyone_down:
			over = true
			set_hunting(false)
			await get_tree().create_timer(1.3, true).timeout
			var who := "you" if Net.is_solo() else "everyone"
			Net.end_game(false, "", "The %s caught %s.\n\n%s" % [ghost.data.name, who, _review()])
		elif hunting and living_actors().is_empty():
			set_hunting(false)


func player_left(peer: int, nick: String) -> void:
	toast.emit("%s left the game." % nick)
	var actor: Actor = actors.get(peer)
	if actor == null:
		return
	if Net.is_host():
		for it in actor.slots.duplicate():
			if it != null:
				Net.place_item(it, actor.global_position + Vector3(0.0, 0.02, 0.0))
	actors.erase(peer)
	actor.queue_free()
	if Net.is_host() and living_actors().is_empty() and not over:
		over = true
		Net.end_game(false, "", "Everyone is gone.\n\n%s" % _review())


## Runs on the host when the trap finishes.
func ghost_captured() -> void:
	if not over:
		Net.ghost_captured()


func apply_captured() -> void:
	over = true
	apply_hunting(false)
	Sfx.play_ui("capture")
	ghost.captured()
	if Net.is_host():
		await get_tree().create_timer(1.0, true).timeout
		Net.end_game(true, "", "You trapped the %s.\n\n%s" % [ghost.data.name, _review()])


func apply_police_arrived() -> void:
	if bystanders != null:
		bystanders.show_police_car()
	if over:
		return
	over = true
	apply_hunting(false)
	if Net.is_host():
		await get_tree().create_timer(2.5, true).timeout
		Net.end_game(false, "SHUT DOWN", "The police have arrived and shut the job down.\nYou never trapped the %s.\n\n%s" % [ghost.data.name, _review()])


func apply_end(won: bool, title: String, message: String) -> void:
	over = true
	end_title = title
	Sfx.stop_all_loops()
	finished.emit(won, message)


func _review() -> String:
	var names: Array[String] = []
	for e in ghost.data.evidence:
		names.append(GhostDB.EVIDENCE[e].name)
	return "It was haunting the %s.\nIts evidence: %s" % [ghost.home_room.name, ", ".join(names)]


## Starts a fresh house. In a solo game this is also the "try again" button.
func restart() -> void:
	get_tree().paused = false
	Sfx.stop_all_loops()
	Net.start_game()
