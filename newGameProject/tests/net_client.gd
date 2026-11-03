extends Node
## A scripted second player for testing multiplayer. Run it from a second copy of
## Godot (--headless works). It joins the host on this machine under the same default
## nickname, plays along for a while and prints what it sees, then leaves.

const ADDRESS := "127.0.0.1"


func _ready() -> void:
	# The node has to outlive the change from this scene to the level.
	var runner := Node.new()
	runner.name = "NetClientRunner"
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	runner.set_script(_Runner)
	get_tree().root.add_child.call_deferred(runner)


class _Runner:
	extends Node

	func _ready() -> void:
		Settings.nickname = "Hunter"
		_run()

	func _wait(seconds: float) -> void:
		await get_tree().create_timer(seconds, true).timeout

	func _find(item_id: String) -> Item:
		for it in Game.items:
			if it.item_id == item_id:
				return it
		return null

	func _run() -> void:
		var err := Net.join_game(ADDRESS)
		print("CLIENT join err=%d" % err)
		while not Net.in_game:
			await _wait(0.2)
		print("CLIENT in game, roster=%s my_id=%d" % [Net.players, Net.my_id()])
		while Game.waiting_for_players or Game.player == null:
			await _wait(0.2)
		await _wait(0.5)
		var l := Game.house.layout
		print("CLIENT house size=%s rooms=%s doors=%d furniture=%d ghost=%s home=%s" % [l.size, l.rooms.map(func(r): return r.name), Game.house.doors.size(), l.furniture.size(), Game.ghost.data.id, Game.ghost.home_room.name])

		var me := Game.player
		me.global_position = Game.house.yard_anchor + Vector3(1.0, 0.05, 2.0)
		var torch := _find("flashlight")
		me.pick_up(torch)
		await _wait(0.5)
		print("CLIENT holds=%s" % (me.active_item().display_name if me.active_item() != null else "nothing"))
		torch.use()
		torch.net_push()
		me.select_slot(1)
		await _wait(0.2)
		var door := Game.house.front_door
		door.interact(me)
		await _wait(0.5)
		print("CLIENT door open=%s" % door.is_open)
		me.global_position = Game.house.entrance + Vector3(0, 0.05, 0)
		me.play_emote("wave")
		for i in 20:
			await _wait(0.5)
			if i % 5 == 0:
				var host: Actor = Game.actors.get(1)
				var hp: Variant = host.global_position if host != null else null
				print("CLIENT t=%d ghost_pos=%s ghost_state=%d host_pos=%s host_name=%s suspicion=%.1f hunting=%s tuned=%s" % [i, Game.ghost.global_position, Game.ghost.state, hp, host.nickname if host != null else "", Game.suspicion, Game.hunting, Game.tuned_ghost_id])
			if Game.over:
				break
		print("CLIENT phase1 over=%s host_holds=%s dead=%s" % [Game.over, _holder_of(Game.actors.get(1)), me.dead])
		# Stay put in the house while the host hunts us.
		var waited := 0.0
		while not me.dead and not Game.over and waited < 40.0:
			await _wait(0.25)
			waited += 0.25
		await _wait(1.6)
		print("CLIENT caught=%s spectating=%s over=%s scare=%s living=%d" % [me.dead, me.spectating.nickname if me.spectating != null else "none", Game.over, me._scare_target != null, Game.living_actors().size()])
		while not Game.over:
			await _wait(0.25)
		print("CLIENT game1 over")
		while Net.in_game:
			await _wait(0.25)
		await _wait(0.5)
		print("CLIENT back in lobby scene=%s roster=%s" % [get_tree().current_scene.name, Net.players])
		while not Net.in_game:
			await _wait(0.25)
		# Long enough for the new level to replace the old one.
		await _wait(2.0)
		while Game.waiting_for_players:
			await _wait(0.2)
		await _wait(0.5)
		print("CLIENT game2 size=%s ghost=%s" % [Game.house.size, Game.ghost.data.id])
		me = Game.player
		var ghost := Game.ghost
		me.global_position = ghost.global_position + Vector3(1.0, 0.05, 0.0)
		me.camera.rotation.x = -0.7
		var trap := _find("ghost_trap")
		me.pick_up(trap)
		await _wait(0.4)
		Net.place_item(trap, ghost.global_position)
		Net.tune_trap(ghost.data.id)
		var box := _find("spirit_box")
		me.pick_up(box)
		await _wait(0.4)
		box.use()
		box.net_push()
		waited = 0.0
		while not Game.over and waited < 14.0:
			await _wait(0.25)
			waited += 0.25
		print("CLIENT capture over=%s seconds=%.1f progress=%.2f ghost_state=%d" % [Game.over, waited, trap.progress, ghost.state])
		await _wait(1.6)
		print("CLIENT game2 end hud_title=%s" % Game.hud._end_title.text)
		while Net.is_online():
			await _wait(0.25)
		await _wait(0.5)
		print("CLIENT host left: scene=%s online=%s" % [get_tree().current_scene.name, Net.is_online()])
		print("CLIENT done")
		await _wait(0.5)
		get_tree().quit()

	func _holder_of(actor: Actor) -> String:
		if actor == null or actor.active_item() == null:
			return "nothing"
		return actor.active_item().display_name
