class_name Bystander
extends StaticBody3D
## Someone from the street who wants to know what's going on. Trust is won through
## conversation and emotes. Satisfied bystanders go home; ignored ones raise
## suspicion, and enough suspicion makes one of them call the police. Every player
## walks their own copy, and whoever is talking to them shares the result.

enum Mode { ARRIVING, WAITING, TALKING, LEAVING }

const WALK_SPEED := 1.5
const TRUST_NEEDED := 75.0
const MAX_ROUNDS := 3
const TALK_COOLDOWN := 12.0
const REACTION_COOLDOWN := 8.0
const LIKED_TRUST := 60.0
const NEUTRAL_TRUST := 30.0
const HATED_TRUST := -25.0

var id := 0
var person: Dictionary
var mode := Mode.ARRIVING
var is_caller := false
var trust := 0.0
var rounds := 0
var cooldown := 0.0

var _manager: BystanderManager
var _target := Vector3.ZERO
var _exit := Vector3.ZERO
var _reaction_cooldown := 0.0
var _asked: Array[int] = []

var _model: HumanModel
var _marker: Label3D
var _speech: Label3D
var _speech_time := 0.0


func setup(manager: BystanderManager, bystander_id: int, data: Dictionary, from: Vector3, to: Vector3) -> void:
	_manager = manager
	id = bystander_id
	person = data
	position = from
	_exit = from
	_target = to


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_model = HumanModel.new()
	add_child(_model)
	_model.build(person.shirt)

	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.75
	add_child(CollisionShapes.make(shape, Vector3(0, 0.875, 0)))

	_marker = Label3D.new()
	_marker.text = "?"
	_marker.position = Vector3(0, 2.0, 0)
	_marker.font_size = 90
	_marker.pixel_size = 0.004
	_marker.outline_size = 14
	_marker.modulate = Color(1.0, 0.85, 0.3)
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	add_child(_marker)

	_speech = Label3D.new()
	_speech.position = Vector3(0, 2.35, 0)
	_speech.font_size = 34
	_speech.pixel_size = 0.0035
	_speech.outline_size = 10
	_speech.width = 420.0
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.visible = false
	add_child(_speech)


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	_reaction_cooldown = maxf(_reaction_cooldown - delta, 0.0)
	_speech_time -= delta
	_speech.visible = _speech_time > 0.0
	_marker.visible = mode == Mode.WAITING and cooldown <= 0.0
	_model.on_phone = is_caller

	match mode:
		Mode.ARRIVING:
			if _walk_to(_target, delta):
				mode = Mode.WAITING
				say("Hey! What's going on in there?", 5.0)
				Sfx.play_at("chatter", global_position, 4.0)
				Game.toast.emit("%s is outside asking questions." % person.name)
		Mode.WAITING, Mode.TALKING:
			_model.set_walking(false)
			_face(Game.player.global_position, delta)
		Mode.LEAVING:
			if _walk_to(_exit, delta):
				_manager.remove(self)
				queue_free()


func _walk_to(point: Vector3, delta: float) -> bool:
	var flat := point - global_position
	flat.y = 0.0
	if flat.length() < 0.15:
		return true
	global_position += flat.normalized() * minf(WALK_SPEED * delta, flat.length())
	_face(point, delta)
	_model.set_walking(true, WALK_SPEED)
	return false


func _face(point: Vector3, delta: float) -> void:
	var d := point - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(delta * 5.0, 1.0))


func say(text: String, seconds := 4.0) -> void:
	_speech.text = text
	_speech_time = seconds


func gesture(kind: String, seconds := 1.8) -> void:
	_model.gesture(kind, seconds)


func is_waiting() -> bool:
	return mode == Mode.WAITING


func get_prompt() -> String:
	if mode != Mode.WAITING:
		return ""
	if cooldown > 0.0:
		return "%s needs a moment" % person.name
	return "Talk to %s" % person.name


func interact(_player: Player) -> void:
	if mode == Mode.WAITING and cooldown <= 0.0:
		Game.talk_requested.emit(self)


func begin_talk() -> void:
	mode = Mode.TALKING
	rounds = 0
	trust = maxf(trust, 0.0)
	Net.bystander_sync(self)


func end_talk() -> void:
	if mode == Mode.TALKING:
		mode = Mode.WAITING
		cooldown = TALK_COOLDOWN
		Net.bystander_sync(self)


func apply_sync(new_mode: int, caller: bool, new_trust: float, new_cooldown: float) -> void:
	mode = new_mode as Mode
	is_caller = caller
	trust = new_trust
	cooldown = new_cooldown


func opening_line() -> String:
	return person.greeting


func next_question() -> Dictionary:
	var pool: Array[Dictionary] = BystanderDB.CALLER_QUESTIONS if is_caller else BystanderDB.QUESTIONS
	var options: Array = range(pool.size()).filter(func(i): return not i in _asked)
	if options.is_empty():
		_asked.clear()
		options = range(pool.size())
	var pick: int = options.pick_random()
	_asked.append(pick)
	return pool[pick]


## Applies the player's answer. Returns the reply and whether the talk is over.
func respond(tone: String) -> Dictionary:
	var mood := "neutral"
	if tone == person.likes:
		mood = "liked"
		trust += LIKED_TRUST
		Game.change_suspicion(-10.0)
		Net.bystander_gesture(self, "wave", 1.0)
	elif tone == person.hates:
		mood = "hated"
		trust += HATED_TRUST
		Game.change_suspicion(12.0)
		Net.bystander_gesture(self, "shake", 1.8)
	else:
		trust += NEUTRAL_TRUST
		Game.change_suspicion(-3.0)
	rounds += 1
	var reply: String = BystanderDB.REPLIES[mood].pick_random()
	if trust >= TRUST_NEEDED:
		return {"reply": reply + " " + _satisfied(), "done": true}
	Net.bystander_sync(self)
	if rounds >= MAX_ROUNDS:
		return {"reply": reply + " I'm not done with you. I'll be right here.", "done": true}
	return {"reply": reply, "done": false}


## Showing a permit settles anyone, including someone calling the police.
func accept_permit() -> String:
	trust = TRUST_NEEDED
	Game.change_suspicion(-20.0)
	return "Oh. That looks official. " + _satisfied()


func _satisfied() -> String:
	var line := "All right. Good luck in there."
	if is_caller:
		line = "...Officer? Sorry, false alarm. I'm hanging up now."
		Net.request_cancel_police()
	Game.change_suspicion(-8.0)
	mode = Mode.LEAVING
	is_caller = false
	Net.bystander_sync(self)
	Net.bystander_gesture(self, "wave", 1.5)
	Net.log_all("%s believed you and went home." % person.name)
	return line


## Runs on the host when suspicion fills up.
func start_calling() -> void:
	is_caller = true
	trust = 0.0
	cooldown = 0.0
	Net.bystander_sync(self)
	Net.bystander_say(self, "That's it. I'm calling the police.", 6.0)


## Reacts to a player's emote. Runs on the host, and everyone sees the reaction.
func on_emote(emote_id: String) -> void:
	if mode != Mode.WAITING or _reaction_cooldown > 0.0:
		return
	_reaction_cooldown = REACTION_COOLDOWN
	if emote_id == person.loves_emote:
		trust += 15.0
		Game.change_suspicion(-4.0)
		Net.bystander_sync(self)
		Net.bystander_gesture(self, "cheer", 1.8)
		Net.bystander_say(self, "Ha! I like you.", 2.5)
	elif emote_id == person.hates_emote:
		trust -= 10.0
		Game.change_suspicion(4.0)
		Net.bystander_sync(self)
		Net.bystander_gesture(self, "shake", 1.8)
		Net.bystander_say(self, "Excuse me?!", 2.5)
	elif emote_id == "wave":
		Net.bystander_gesture(self, "wave", 1.8)
		Net.bystander_say(self, "Hey! Come and talk to me!", 2.5)
	else:
		Net.bystander_say(self, "...What's that supposed to mean?", 2.5)
