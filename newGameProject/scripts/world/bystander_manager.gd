class_name BystanderManager
extends Node
## Sends bystanders to the yard, raises suspicion while they're ignored, and runs
## the police call when suspicion fills up. Those decisions are made on the host.

const MAX_AT_ONCE := 2
const FIRST_VISIT := Vector2(35.0, 60.0)
const NEXT_VISIT := Vector2(80.0, 130.0)
const WAIT_SUSPICION := 0.4
const CALM_RATE := 0.15
const POLICE_DELAY := 45.0
const SUSPICION_AFTER_CANCEL := 55.0
const EMOTE_RANGE := 12.0

var active: Array[Bystander] = []
var by_id := {}
var _timer := 0.0
var _serial := 0
var _car: Node3D
var _car_lights: Array[OmniLight3D] = []
var _arrived := false


func _ready() -> void:
	_timer = randf_range(FIRST_VISIT.x, FIRST_VISIT.y)


func _physics_process(delta: float) -> void:
	if not Net.is_host() or Game.over or _arrived or Game.waiting_for_players:
		return
	# The street only takes notice once someone has gone inside.
	if Game.time_inside > 0.0:
		_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(NEXT_VISIT.x, NEXT_VISIT.y)
		if active.size() < MAX_AT_ONCE:
			spawn()

	# Check first, so that calming down can't hide suspicion that just hit the limit.
	if Game.police_left < 0.0:
		if Game.suspicion >= 100.0:
			_call_police()
	else:
		Game.police_left -= delta
		if Game.police_left <= 0.0:
			_arrived = true
			Net.police_arrived()
			return

	var waiting := 0
	var present := 0
	for b in active:
		if b.mode != Bystander.Mode.LEAVING:
			present += 1
		if b.is_waiting():
			waiting += 1
	if waiting > 0:
		Game.suspicion = minf(Game.suspicion + delta * WAIT_SUSPICION * waiting, 100.0)
	elif present == 0:
		Game.suspicion = maxf(Game.suspicion - delta * CALM_RATE, 0.0)


## Host only. Picks who comes and tells every player's copy of the game.
func spawn() -> int:
	var yard := Game.house.yard_anchor
	var free: Array = []
	for i in BystanderDB.PEOPLE.size():
		var in_use := false
		for b in active:
			if b.person.name == BystanderDB.PEOPLE[i].name:
				in_use = true
		if not in_use:
			free.append(i)
	var from := yard + Vector3(randf_range(-20.0, -16.0), 0.0, 17.0)
	var to := yard + Vector3(randf_range(-8.0, -2.5), 0.0, randf_range(3.5, 7.5))
	_serial += 1
	Net.bystander_spawn(_serial, free.pick_random(), from, to)
	return _serial


func create(id: int, person: int, from: Vector3, to: Vector3) -> void:
	var b := Bystander.new()
	b.setup(self, id, BystanderDB.PEOPLE[person], from, to)
	Game.main.add_child(b)
	active.append(b)
	by_id[id] = b


func remove(b: Bystander) -> void:
	active.erase(b)
	by_id.erase(b.id)


func add_commotion(amount: float) -> void:
	var anyone_here := false
	for b in active:
		if b.is_waiting():
			anyone_here = true
	if anyone_here:
		Game.suspicion = minf(Game.suspicion + amount, 100.0)
	else:
		_timer -= amount * 2.0


func on_emote(id: String, pos: Vector3) -> void:
	for b in active:
		if b.global_position.distance_to(pos) < EMOTE_RANGE:
			b.on_emote(id)


func _call_police() -> void:
	Game.police_left = POLICE_DELAY
	Net.set_siren(true)
	Net.toast_all("Someone has called the police! Talk them down before a car gets here.")
	Net.log_all("Police called. Talk to the caller or finish the job, fast.")
	var caller: Bystander = null
	for b in active:
		if b.mode != Bystander.Mode.LEAVING:
			caller = b
			break
	if caller == null:
		caller = by_id[spawn()]
	caller.start_calling()


func cancel_police() -> void:
	if not Net.is_host():
		return
	Game.police_left = -1.0
	Game.suspicion = SUSPICION_AFTER_CANCEL
	Net.set_siren(false)
	Net.toast_all("The police call was called off.")


func show_police_car() -> void:
	_arrived = true
	var at := Game.house.yard_anchor + Vector3(-7.0, 0.0, 16.5)
	_car = Node3D.new()
	_car.position = at
	Game.main.add_child(_car)
	Mk.box(_car, Vector3(4.2, 0.7, 1.8), Vector3(0, 0.6, 0), Mk.mat(Color(0.85, 0.85, 0.88), 0.3))
	Mk.box(_car, Vector3(2.2, 0.55, 1.6), Vector3(-0.2, 1.2, 0), Mk.mat(Color(0.06, 0.07, 0.1), 0.2))
	var colors := [Color(1.0, 0.1, 0.1), Color(0.1, 0.3, 1.0)]
	for i in 2:
		Mk.box(_car, Vector3(0.25, 0.12, 1.2), Vector3(-0.2 + (i - 0.5) * 0.5, 1.54, 0), Mk.mat(colors[i], 0.3, colors[i], 5.0))
		var light := OmniLight3D.new()
		light.position = Vector3(-0.2 + (i - 0.5) * 0.5, 1.8, 0)
		light.light_color = colors[i]
		light.light_energy = 5.0
		light.omni_range = 18.0
		_car.add_child(light)
		_car_lights.append(light)


func _process(_delta: float) -> void:
	if _car_lights.is_empty():
		return
	var flip := fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5
	_car_lights[0].visible = flip
	_car_lights[1].visible = not flip
