extends Node3D
## Assembles a run: lighting, house, equipment table, the ghost, every player and the
## HUD. All players build the same level, because they all seed it from the same number.

const TABLE_HEIGHT := 0.9
const ITEMS_PER_ROW := 8
const ITEM_SPACING := 0.8
const SPAWN_SPACING := 1.2

var _environment: Environment


func _ready() -> void:
	Game.reset_run()
	Game.main = self
	_build_environment()

	seed(Net.session.get("seed", randi()))
	var house := House.new()
	add_child(house)
	Game.house = house

	_spawn_equipment()
	_spawn_ghost()
	# From here on each player's randomness is their own business.
	randomize()

	_spawn_players(house)

	var crowd := BystanderManager.new()
	add_child(crowd)
	Game.bystanders = crowd

	var hud: CanvasLayer = load("res://scripts/ui/hud.gd").new()
	add_child(hud)
	Net.local_loaded()


func _physics_process(delta: float) -> void:
	if not Net.is_host() or Game.over or Game.waiting_for_players:
		return
	for actor in Game.living_actors():
		if Game.actor_in_house(actor):
			Game.time_inside += delta
			break


func _spawn_players(house: House) -> void:
	var ids: Array = Net.players.keys()
	ids.sort()
	if ids.is_empty():
		ids = [Net.my_id()]
	for i in ids.size():
		var id: int = ids[i]
		var actor: Actor
		if id == Net.my_id():
			actor = Player.new()
			Game.player = actor
		else:
			actor = RemotePlayer.new()
		actor.peer_id = id
		actor.nickname = Net.players.get(id, "Hunter")
		actor.name = "Actor%d" % id
		actor.position = house.yard_anchor + Vector3(3.0 + i * SPAWN_SPACING, 0.05, 7.5)
		add_child(actor)
		Game.actors[id] = actor


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.07)
	sky_mat.sky_horizon_color = Color(0.05, 0.07, 0.12)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.02)
	sky_mat.ground_horizon_color = Color(0.04, 0.05, 0.09)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.5)
	env.ambient_light_energy = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = Settings.brightness
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.07)
	env.fog_density = 0.012
	_environment = env
	Settings.changed.connect(_on_settings_changed)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, -30, 0)
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.3
	moon.shadow_enabled = true
	add_child(moon)


func _on_settings_changed() -> void:
	_environment.tonemap_exposure = Settings.brightness


func _spawn_equipment() -> void:
	var table := Game.house.table_center() + Vector3(0.0, TABLE_HEIGHT, 0.0)
	var left := table + Vector3(-ITEM_SPACING * (ITEMS_PER_ROW - 1) / 2.0, 0.0, 0.0)
	for i in GhostDB.ITEM_SCRIPTS.size():
		var item: Item = load(GhostDB.ITEM_SCRIPTS[i]).new()
		item.net_id = i
		add_child(item)
		Game.items.append(item)
		var col := i % ITEMS_PER_ROW
		var row := i / ITEMS_PER_ROW
		item.set_on_table(left + Vector3(col * ITEM_SPACING, 0.0, -0.28 + row * 0.56))

	var sign_label := Label3D.new()
	sign_label.text = "EQUIPMENT\nTake up to 3 at a time"
	sign_label.position = table + Vector3(0.0, 1.0, 0.0)
	sign_label.pixel_size = 0.005
	sign_label.font_size = 40
	sign_label.outline_size = 10
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign_label)


func _spawn_ghost() -> void:
	var data: Dictionary = GhostDB.by_id(Net.session.get("ghost", ""))
	if data.is_empty():
		data = GhostDB.TYPES.pick_random()
	var homes: Array[Room] = []
	for r in Game.house.rooms:
		if r.type != "hallway" and r.type != "foyer":
			homes.append(r)
	var home: Room = homes.pick_random()
	var ghost: Ghost = load(data.script).new()
	ghost.setup(data, home)
	ghost.position = home.center()
	add_child(ghost)
	Game.ghost = ghost
