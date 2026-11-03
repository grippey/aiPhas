extends Node
## Plays each ghost through the catch loop and a hunt, then tests random houses,
## the backfire, bystanders, the police and emotes. Results go to the game log.

## Set to "police" before adding this node to run only that test.
var only := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _find(item_id: String) -> Item:
	for it in get_tree().get_nodes_in_group("items"):
		if it.item_id == item_id:
			return it
	return null


func _start(id: String) -> void:
	Game.force_ghost_id = id
	Game.restart()
	await _wait(0.8)


func _set_trap(at: Vector3) -> Item:
	var p := Game.player
	var trap := _find("ghost_trap")
	p.pick_up(trap)
	p.slots[p.active_slot] = null
	trap.set_held(null, false)
	trap.place_at(at)
	return trap


func _aim_at(g: Ghost) -> void:
	var p := Game.player
	p.look_at(Vector3(g.global_position.x, p.global_position.y, g.global_position.z))
	p.camera.look_at(g.global_position + Vector3(0, g.data.height * 0.6, 0))


func _run() -> void:
	if only == "police":
		await _test_police()
		print("SMOKE done")
		return
	_test_layouts()
	for t in GhostDB.TYPES:
		await _test_catch(t)
		await _test_hunt(t)
	await _test_backfire()
	await _test_bystander()
	await _test_police()
	Game.force_ghost_id = ""
	print("SMOKE done")


func _test_layouts() -> void:
	var start := Time.get_ticks_msec()
	var room_counts := {}
	var sizes := {}
	for i in 100:
		var l := HouseLayout.generate()
		room_counts[l.rooms.size()] = room_counts.get(l.rooms.size(), 0) + 1
		sizes[l.size] = true
	print("SMOKE layouts: 100 in %d ms, room counts %s, %d distinct sizes" % [Time.get_ticks_msec() - start, room_counts, sizes.size()])


func _test_catch(t: Dictionary) -> void:
	await _start(t.id)
	var p := Game.player
	var g := Game.ghost
	p.global_position = g.global_position + Vector3(1.2, 0.05, 0.0)
	p.camera.rotation.x = -0.7
	await _wait(0.1)
	var trap := _set_trap(g.global_position)
	Game.tuned_ghost_id = t.id
	var bait := _find(t.bait)
	p.pick_up(bait)
	match t.bait:
		"salt", "iron_ward", "spirit_box", "emf_reader", "flashlight", "uv_light", "smudge_stick":
			bait.use()
		"candle":
			bait.use()
			p.place_active()
		"motion_detector", "tape_recorder", "thermos", "permit_folder":
			p.place_active()
	var elapsed := 0.0
	var flash_timer := 0.0
	while elapsed < 12.0 and not Game.over:
		await _wait(0.1)
		elapsed += 0.1
		if t.bait == "flashlight" or t.bait == "camera" or t.bait == "uv_light":
			_aim_at(g)
		if t.bait == "camera":
			flash_timer -= 0.1
			if flash_timer <= 0.0:
				flash_timer = 2.0
				bait.use()
	print("SMOKE catch %s: captured=%s seconds=%.1f progress=%.2f state=%d" % [t.id, Game.over, elapsed, trap.progress, g.state])
	await _wait(1.2)


func _test_hunt(t: Dictionary) -> void:
	await _start(t.id)
	var p := Game.player
	var g := Game.ghost
	p.global_position = Game.house.entrance + Vector3(0, 0.05, 0)
	g.global_position = Game.house.nav_point(Game.house.entrance + Vector3(0, 0, -4))
	g.force_hunt()
	var hunting_started := Game.hunting
	var start_gap := g.global_position.distance_to(p.global_position)
	var elapsed := 0.0
	var moved := 0.0
	var last := g.global_position
	while elapsed < 9.0 and not Game.over:
		await _wait(0.1)
		elapsed += 0.1
		moved += g.global_position.distance_to(last)
		last = g.global_position
		# Stand still and stare the other way, so the Watcher can move.
		p.look_at(p.global_position + (p.global_position - g.global_position) * Vector3(1, 0, 1))
	print("SMOKE hunt %s: started=%s caught=%s seconds=%.1f moved=%.1f start_gap=%.1f temp=%.0f" % [t.id, hunting_started, Game.over, elapsed, moved, start_gap, g.temperature_for(g.home_room)])
	await _wait(1.6)


func _test_backfire() -> void:
	await _start("cinder")
	var p := Game.player
	var g := Game.ghost
	p.global_position = g.global_position + Vector3(1.0, 0.05, 0.0)
	var trap := _set_trap(g.global_position)
	Game.tuned_ghost_id = "mourner"
	await _wait(0.4)
	print("SMOKE backfire: burnout=%.1f hunting=%s sanity=%.0f" % [trap.burnout, Game.hunting, Game.sanity])
	Game.set_hunting(false)


func _test_bystander() -> void:
	await _start("mourner")
	var crowd := Game.bystanders
	var b: Bystander = crowd.by_id[crowd.spawn()]
	b.global_position = b._target + Vector3(0.3, 0, 0)
	await _wait(0.6)
	var waited: bool = b.is_waiting()
	# Rudeness first, then the tone this person likes.
	var hated: String = b.person.hates
	var before := Game.suspicion
	b.begin_talk()
	var r1 := b.respond(hated)
	var after_hated := Game.suspicion
	var r2 := b.respond(b.person.likes)
	var r3 := b.respond(b.person.likes)
	print("SMOKE bystander %s: waited=%s suspicion %.1f->%.1f r1=%s r2_done=%s r3_done=%s leaving=%s" % [b.person.name, waited, before, after_hated, r1.done, r2.done, r3.done, b.mode == Bystander.Mode.LEAVING])
	var other: Bystander = crowd.by_id[crowd.spawn()]
	other.global_position = other._target
	await _wait(0.4)
	var emote: String = other.person.loves_emote
	var trust_before: float = other.trust
	Game.player.global_position = other.global_position + Vector3(2, 0.05, 0)
	Game.player.play_emote(emote)
	await _wait(0.2)
	print("SMOKE emote %s: trust %.0f->%.0f rig_visible=%s current=%s" % [emote, trust_before, other.trust, Game.player.emotes.visible, Game.player.emotes.current])
	for e in EmoteRig.EMOTES:
		Game.player.emotes.current = ""
		Game.player.play_emote(e.id)
		await _wait(0.3)
	print("SMOKE emotes: all played, sanity=%.0f" % Game.sanity)


func _test_police() -> void:
	await _start("mourner")
	var crowd := Game.bystanders
	Game.suspicion = 100.0
	await _wait(0.3)
	if crowd.active.is_empty():
		print("SMOKE police: no caller appeared")
		return
	var called := Game.police_left > 0.0
	var caller: Bystander = crowd.active[0]
	caller.global_position = caller._target
	await _wait(0.2)
	caller.begin_talk()
	caller.respond(caller.person.likes)
	var result := caller.respond(caller.person.likes)
	print("SMOKE police cancel: called=%s caller=%s done=%s police_left=%.1f suspicion=%.0f" % [called, caller.person.name, result.done, Game.police_left, Game.suspicion])

	await _start("mourner")
	Game.suspicion = 100.0
	await _wait(0.2)
	Game.police_left = 0.2
	await _wait(0.4)
	print("SMOKE police arrive: over=%s title=%s" % [Game.over, Game.end_title])
	await _wait(2.6)
