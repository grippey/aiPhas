extends Node
## All multiplayer traffic goes through here. One player hosts from inside the game
## and friends connect straight to them. The host runs the ghost, the bystanders and
## the suspicion meter; each player runs their own character. A solo game uses
## Godot's offline peer, so it goes through exactly the same code.

signal roster_changed
signal join_failed(reason: String)
signal left_session(reason: String)

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 6
const SEND_INTERVAL := 0.05
const WORLD_EVERY := 5

## peer id -> nickname. Nicknames can repeat, since peer ids are the real identity.
var players := {}
var session := {}
var in_game := false
var menu_message := ""
var open_lobby_on_menu := false

var _loaded := {}
var _send_timer := 0.0
var _send_count := 0
var _pile_serial := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_solo() -> bool:
	return players.size() <= 1


# --- Sessions -------------------------------------------------------------

func start_solo() -> void:
	close_connection()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {1: Settings.nickname}
	start_game()


func host_game(port := DEFAULT_PORT) -> Error:
	close_connection()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players = {1: Settings.nickname}
	roster_changed.emit()
	return OK


func join_game(address: String, port := DEFAULT_PORT) -> Error:
	close_connection()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func close_connection() -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	in_game = false
	_loaded = {}


func leave_to_menu(reason := "") -> void:
	close_connection()
	menu_message = reason
	open_lobby_on_menu = false
	get_tree().paused = false
	Sfx.stop_all_loops()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func start_game() -> void:
	if not is_host():
		return
	var ghost_id: String = Game.force_ghost_id if Game.force_ghost_id != "" else GhostDB.TYPES.pick_random().id
	if is_online():
		multiplayer.multiplayer_peer.refuse_new_connections = true
	rpc("_start_game", {"seed": randi(), "ghost": ghost_id})


func back_to_lobby() -> void:
	if is_host():
		rpc("_to_lobby")


func _on_connected() -> void:
	rpc_id(1, "_register", Settings.nickname)


func _on_connection_failed() -> void:
	close_connection()
	join_failed.emit("Couldn't reach that address. Check the IP and that the host's port is open.")


func _on_server_gone() -> void:
	var was_in_game := in_game
	close_connection()
	if was_in_game:
		leave_to_menu("The host left the game.")
	else:
		left_session.emit("The host closed the lobby.")


func _on_peer_disconnected(id: int) -> void:
	var nick: String = players.get(id, "Someone")
	players.erase(id)
	roster_changed.emit()
	if is_host() and not in_game:
		rpc("_roster", players)
	if in_game:
		Game.player_left(id, nick)
		_loaded.erase(id)
		if is_host():
			_check_all_loaded()


@rpc("any_peer", "reliable")
func _register(nick: String) -> void:
	if not is_host():
		return
	var from := multiplayer.get_remote_sender_id()
	if in_game:
		multiplayer.multiplayer_peer.disconnect_peer(from)
		return
	players[from] = Settings.clean_nickname(nick)
	rpc("_roster", players)
	roster_changed.emit()


@rpc("authority", "reliable")
func _roster(list: Dictionary) -> void:
	players = list
	roster_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start_game(info: Dictionary) -> void:
	session = info
	_loaded = {}
	in_game = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


@rpc("authority", "call_local", "reliable")
func _to_lobby() -> void:
	in_game = false
	open_lobby_on_menu = true
	if is_host() and is_online():
		multiplayer.multiplayer_peer.refuse_new_connections = false
	get_tree().paused = false
	Sfx.stop_all_loops()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


## Main calls this when the level is built. Play begins when everyone has done so.
func local_loaded() -> void:
	rpc_id(1, "_client_loaded")


@rpc("any_peer", "call_local", "reliable")
func _client_loaded() -> void:
	_loaded[_sender()] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	for id in players:
		if not _loaded.has(id):
			return
	rpc("_all_loaded")


@rpc("authority", "call_local", "reliable")
func _all_loaded() -> void:
	Game.everyone_ready()


func _sender() -> int:
	var from := multiplayer.get_remote_sender_id()
	return from if from != 0 else my_id()


# --- Regular state updates ------------------------------------------------

func _physics_process(delta: float) -> void:
	if not in_game or Game.player == null or not is_instance_valid(Game.player):
		return
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = SEND_INTERVAL
	_send_count += 1
	var me := Game.player
	if is_online():
		rpc("_actor_state", me.global_position, me.rotation.y, me.camera.rotation.x, me.net_flags(), Game.sanity)
		if is_host():
			var g := Game.ghost
			if g != null and is_instance_valid(g):
				rpc("_ghost_state", g.global_position, g.rotation.y, g.state, g.net_wanted, g.home_room.index, g.net_extra())
			if _send_count % WORLD_EVERY == 0:
				rpc("_world_state", Game.suspicion, Game.police_left)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _actor_state(pos: Vector3, yaw: float, pitch: float, flags: int, sanity: float) -> void:
	var actor: Actor = Game.actors.get(multiplayer.get_remote_sender_id())
	if actor != null and is_instance_valid(actor):
		actor.apply_net_state(pos, yaw, pitch, flags, sanity)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _ghost_state(pos: Vector3, yaw: float, state: int, wanted: bool, home: int, extra: String) -> void:
	if Game.ghost != null and is_instance_valid(Game.ghost):
		Game.ghost.apply_net_state(pos, yaw, state, wanted, home, extra)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _world_state(suspicion: float, police_left: float) -> void:
	Game.suspicion = suspicion
	Game.police_left = police_left


# --- Players and items ----------------------------------------------------

func request_pickup(item: Item) -> void:
	rpc_id(1, "_pickup_request", item.net_id)


@rpc("any_peer", "call_local", "reliable")
func _pickup_request(id: int) -> void:
	var item := Game.item(id)
	if item != null and item.holder == null:
		rpc("_do_pickup", _sender(), id)


@rpc("authority", "call_local", "reliable")
func _do_pickup(peer: int, id: int) -> void:
	var actor: Actor = Game.actors.get(peer)
	var item := Game.item(id)
	if actor != null and item != null:
		actor.apply_take(item)


func place_item(item: Item, pos: Vector3) -> void:
	rpc("_do_place", item.net_id, pos)


@rpc("any_peer", "call_local", "reliable")
func _do_place(id: int, pos: Vector3) -> void:
	var item := Game.item(id)
	if item == null:
		return
	if item.holder != null:
		item.holder.apply_release(item)
	item.place_at(pos)


func select_slot(index: int) -> void:
	rpc("_select_slot", index)


@rpc("any_peer", "call_local", "reliable")
func _select_slot(index: int) -> void:
	var actor: Actor = Game.actors.get(_sender())
	if actor != null and index >= 0 and index < Actor.SLOTS:
		actor.apply_select(index)


func push_item_state(item: Item) -> void:
	if is_online():
		rpc("_item_state", item.net_id, item.net_state())


@rpc("any_peer", "call_remote", "reliable")
func _item_state(id: int, state: Dictionary) -> void:
	var item := Game.item(id)
	if item != null:
		item.apply_net_state(state)


func spawn_salt(pos: Vector3) -> void:
	_pile_serial += 1
	rpc("_spawn_salt", my_id() * 1000 + _pile_serial, pos)


@rpc("any_peer", "call_local", "reliable")
func _spawn_salt(id: int, pos: Vector3) -> void:
	Game.add_salt_pile(id, pos)


func remove_salt(id: int) -> void:
	rpc("_remove_salt", id)


@rpc("any_peer", "call_local", "reliable")
func _remove_salt(id: int) -> void:
	Game.remove_salt_pile(id)


func spawn_stake(pos: Vector3) -> void:
	rpc("_spawn_stake", pos)


@rpc("any_peer", "call_local", "reliable")
func _spawn_stake(pos: Vector3) -> void:
	Game.add_iron_stake(pos)


func tune_trap(ghost_id: String) -> void:
	rpc("_tune_trap", ghost_id)


@rpc("any_peer", "call_local", "reliable")
func _tune_trap(ghost_id: String) -> void:
	Game.tuned_ghost_id = ghost_id
	if ghost_id != "" and _sender() != my_id():
		Game.toast.emit("%s tuned the trap to %s." % [players.get(_sender(), "Someone"), GhostDB.by_id(ghost_id).name])


# --- The house ------------------------------------------------------------

func door_open(door: Door, open: bool, duration: float, sound: String) -> void:
	rpc("_door_open", door.index, open, duration, sound)


@rpc("any_peer", "call_local", "reliable")
func _door_open(index: int, open: bool, duration: float, sound: String) -> void:
	var door := Game.door(index)
	if door != null:
		door.set_open(open, duration)
		if sound != "":
			Sfx.play_at(sound, door.global_position, 2.0 if sound == "slam" else -2.0)


func door_lock(door: Door, seconds: float) -> void:
	rpc("_door_lock", door.index, seconds)


@rpc("authority", "call_local", "reliable")
func _door_lock(index: int, seconds: float) -> void:
	var door := Game.door(index)
	if door != null:
		door.apply_lock(seconds)


func door_print(door: Door, pos: Vector3, angle: float) -> void:
	rpc("_door_print", door.index, pos, angle)


@rpc("authority", "call_local", "reliable")
func _door_print(index: int, pos: Vector3, angle: float) -> void:
	var door := Game.door(index)
	if door != null:
		door.apply_handprint(pos, angle)


func room_light(room: Room, on: bool) -> void:
	rpc("_room_light", room.index, on)


@rpc("any_peer", "call_local", "reliable")
func _room_light(index: int, on: bool) -> void:
	var room := Game.room(index)
	if room != null:
		room.set_on(on)


func room_flicker(room: Room, seconds: float) -> void:
	rpc("_room_flicker", room.index, seconds)


@rpc("authority", "call_local", "reliable")
func _room_flicker(index: int, seconds: float) -> void:
	var room := Game.room(index)
	if room != null:
		room.flicker_time = seconds


func prop_throw(prop_index: int, impulse: Vector3) -> void:
	rpc("_prop_throw", prop_index, impulse)


@rpc("authority", "call_local", "reliable")
func _prop_throw(index: int, impulse: Vector3) -> void:
	var props := Game.house.props
	if index >= 0 and index < props.size():
		props[index].sleeping = false
		props[index].apply_central_impulse(impulse)


# --- Sounds, messages and noise -------------------------------------------

func sfx_all(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	rpc("_sfx", sound, pos, volume_db, pitch)


@rpc("any_peer", "call_local", "unreliable_ordered", 4)
func _sfx(sound: String, pos: Vector3, volume_db: float, pitch: float) -> void:
	if Sfx.streams.has(sound):
		Sfx.play_at(sound, pos, volume_db, pitch)


func toast_all(text: String) -> void:
	rpc("_toast", text)


@rpc("any_peer", "call_local", "reliable")
func _toast(text: String) -> void:
	Game.toast.emit(text)


func log_all(text: String) -> void:
	rpc("_log", text)


@rpc("any_peer", "call_local", "reliable")
func _log(text: String) -> void:
	Game.add_log(text)


## A sound made by this player's own actions. Only the host's ghost listens.
func noise(pos: Vector3, radius: float) -> void:
	rpc_id(1, "_noise", pos, radius)


@rpc("any_peer", "call_local", "unreliable_ordered", 4)
func _noise(pos: Vector3, radius: float) -> void:
	Game.make_noise(pos, radius)


func hurt_sanity(peer: int, amount: float) -> void:
	rpc_id(peer, "_sanity", amount)


@rpc("any_peer", "call_local", "reliable")
func _sanity(amount: float) -> void:
	Game.change_sanity(amount)


func add_suspicion(amount: float) -> void:
	rpc_id(1, "_suspicion", amount)


@rpc("any_peer", "call_local", "reliable")
func _suspicion(amount: float) -> void:
	Game.suspicion = clampf(Game.suspicion + amount, 0.0, 100.0)


# --- The ghost and the end of the game ------------------------------------

func set_hunting(active: bool) -> void:
	rpc("_hunting", active)


@rpc("authority", "call_local", "reliable")
func _hunting(active: bool) -> void:
	Game.apply_hunting(active)


func ghost_event(pos: Vector3) -> void:
	rpc("_ghost_event", pos)


@rpc("authority", "call_local", "reliable")
func _ghost_event(pos: Vector3) -> void:
	if Game.ghost != null:
		Game.ghost.apply_event(pos)


func player_caught(peer: int) -> void:
	rpc("_player_caught", peer)


@rpc("authority", "call_local", "reliable")
func _player_caught(peer: int) -> void:
	Game.apply_player_caught(peer)


func ghost_captured() -> void:
	rpc("_ghost_captured")


@rpc("authority", "call_local", "reliable")
func _ghost_captured() -> void:
	Game.apply_captured()


func police_arrived() -> void:
	rpc("_police_arrived")


@rpc("authority", "call_local", "reliable")
func _police_arrived() -> void:
	Game.apply_police_arrived()


func end_game(won: bool, title: String, message: String) -> void:
	rpc("_end_game", won, title, message)


@rpc("authority", "call_local", "reliable")
func _end_game(won: bool, title: String, message: String) -> void:
	Game.apply_end(won, title, message)


# --- Bystanders and emotes ------------------------------------------------

func bystander_spawn(id: int, person: int, from: Vector3, to: Vector3) -> void:
	rpc("_bystander_spawn", id, person, from, to)


@rpc("authority", "call_local", "reliable")
func _bystander_spawn(id: int, person: int, from: Vector3, to: Vector3) -> void:
	if Game.bystanders != null:
		Game.bystanders.create(id, person, from, to)


func bystander_sync(b: Bystander) -> void:
	rpc("_bystander_sync", b.id, b.mode, b.is_caller, b.trust, b.cooldown)


@rpc("any_peer", "call_remote", "reliable")
func _bystander_sync(id: int, mode: int, is_caller: bool, trust: float, cooldown: float) -> void:
	var b := Game.bystander(id)
	if b != null:
		b.apply_sync(mode, is_caller, trust, cooldown)


func bystander_say(b: Bystander, text: String, seconds: float) -> void:
	rpc("_bystander_say", b.id, text, seconds)


@rpc("any_peer", "call_local", "reliable")
func _bystander_say(id: int, text: String, seconds: float) -> void:
	var b := Game.bystander(id)
	if b != null:
		b.say(text, seconds)


func bystander_gesture(b: Bystander, kind: String, seconds: float) -> void:
	rpc("_bystander_gesture", b.id, kind, seconds)


@rpc("any_peer", "call_local", "reliable")
func _bystander_gesture(id: int, kind: String, seconds: float) -> void:
	var b := Game.bystander(id)
	if b != null:
		b.gesture(kind, seconds)


func set_siren(active: bool) -> void:
	rpc("_siren", active)


@rpc("authority", "call_local", "reliable")
func _siren(active: bool) -> void:
	Sfx.set_siren(active)


func request_cancel_police() -> void:
	rpc_id(1, "_cancel_police")


@rpc("any_peer", "call_local", "reliable")
func _cancel_police() -> void:
	if Game.bystanders != null:
		Game.bystanders.cancel_police()


func emote(id: String) -> void:
	rpc("_emote", id)


@rpc("any_peer", "call_local", "reliable")
func _emote(id: String) -> void:
	var actor: Actor = Game.actors.get(_sender())
	if actor != null:
		actor.on_emote(id)
		if is_host():
			Game.handle_emote(actor, id)


func scorch(pos: Vector3) -> void:
	rpc("_scorch", pos)


@rpc("authority", "call_local", "reliable")
func _scorch(pos: Vector3) -> void:
	var mark := Mk.cyl(Game.main, 0.3, 0.45, 0.01, pos + Vector3(0, 0.02, 0), Mk.mat(Color(0.02, 0.015, 0.01), 1.0))
	mark.scale = Vector3(randf_range(0.8, 1.5), 1.0, randf_range(0.8, 1.5))
