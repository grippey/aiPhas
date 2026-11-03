extends Item
## Set it down and it pulls the ghost towards it. It follows whichever ghost is
## chosen in the notebook. Tuned right, and with that ghost's bait active, it
## pins the ghost and slowly captures it. Tuned wrong, it backfires. The host decides
## what happens. Other players' copies just show the result.

const RADIUS := 4.0
const CAPTURE_TIME := 8.0
const BURNOUT_TIME := 30.0
const PUSH_INTERVAL := 0.25

var progress := 0.0
var burnout := 0.0
var _label: Label3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _core: StandardMaterial3D
var _light: OmniLight3D
var _hum_timer := 0.0
var _push_timer := 0.0


func _define() -> void:
	item_id = "ghost_trap"
	display_name = "Ghost Trap"
	description = "G: set it down. Tune it in the notebook (Tab)."
	hand_offset = Vector3(-0.02, -0.06, -0.05)
	collider_size = Vector3(0.42, 0.2, 0.42)
	collider_center = Vector3(0, 0.1, 0)
	net_props = ["progress", "burnout"]


func _build() -> void:
	var metal := Mk.mat(Color(0.2, 0.21, 0.23), 0.35)
	Mk.cyl(self, 0.17, 0.2, 0.06, Vector3(0, 0.03, 0), metal)
	Mk.cyl(self, 0.07, 0.09, 0.09, Vector3(0, 0.1, 0), metal)
	_core = Mk.mat(Color(0.2, 0.2, 0.2), 0.2, Color(0.4, 0.8, 1.0), 2.0)
	Mk.sphere(self, 0.055, Vector3(0, 0.16, 0), _core)
	for i in 3:
		var a := TAU * i / 3.0
		var post := Mk.cyl(self, 0.008, 0.012, 0.16, Vector3(cos(a) * 0.15, 0.13, sin(a) * 0.15), metal)
		post.rotation.z = -cos(a) * 0.3
		post.rotation.x = sin(a) * 0.3

	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.03
	torus.outer_radius = RADIUS
	torus.rings = 64
	torus.ring_segments = 4
	_ring_mat = Mk.mat(Color(0.1, 0.1, 0.1), 0.5, Color(0.4, 0.8, 1.0), 1.2)
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.position = Vector3(0, 0.02, 0)
	_ring.visible = false
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.35, 0)
	_light.omni_range = 2.5
	_light.light_energy = 0.6
	_light.visible = false
	add_child(_light)

	_label = Label3D.new()
	_label.position = Vector3(0, 0.55, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0022
	_label.font_size = 36
	_label.outline_size = 8
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)


func _on_placed() -> void:
	_ring.visible = true
	_light.visible = true
	_label.visible = true
	# The ring has to stay level and centred however the trap landed.
	_ring.global_position.y = global_position.y + 0.02


func _on_picked_up() -> void:
	_ring.visible = false
	_light.visible = false
	_label.visible = false
	progress = 0.0


func _physics_process(delta: float) -> void:
	if held or on_table or Game.over or Game.ghost == null:
		return
	burnout = maxf(burnout - delta, 0.0)
	var ghost := Game.ghost
	var tuned := Game.tuned_ghost_id
	var flat := global_position * Vector3(1, 0, 1)
	var inside := ghost.global_position.distance_to(flat) < RADIUS
	var color := Color(0.4, 0.8, 1.0)
	var text := ""

	if burnout > 0.0:
		color = Color(0.6, 0.1, 0.05)
		text = "BURNED OUT %d" % ceili(burnout)
	elif tuned == "":
		color = Color(0.7, 0.7, 0.7)
		text = "NOT TUNED"
	else:
		text = "TUNED: %s" % GhostDB.by_id(tuned).name
		var capturing := false
		if Net.is_host():
			if inside and tuned != ghost.data.id:
				_backfire(ghost)
			elif inside and ghost.bait_active(self):
				capturing = true
				ghost.pin(self)
				progress += delta / CAPTURE_TIME
				if progress >= 1.0:
					_ring.visible = false
					Game.ghost_captured()
			else:
				progress = maxf(progress - delta * 0.05, 0.0)
			_push_timer -= delta
			if _push_timer <= 0.0:
				_push_timer = PUSH_INTERVAL
				net_push()
		else:
			capturing = inside and ghost.state == Ghost.State.PINNED
		if capturing:
			color = Color(0.3, 1.0, 0.5)
			text = "CAPTURING %d%%" % int(progress * 100.0)
			_hum_timer -= delta
			if _hum_timer <= 0.0:
				_hum_timer = 0.5
				Sfx.play_at("beep", global_position, -6.0, 0.5 + progress)
		elif inside:
			color = Color(1.0, 0.8, 0.2)
			text += "\nSIGNAL! NEEDS BAIT"

	_ring_mat.emission = color
	_core.emission = color
	_light.light_color = color
	_label.modulate = color
	_label.text = text


func _backfire(ghost: Ghost) -> void:
	burnout = BURNOUT_TIME
	progress = 0.0
	net_push()
	Net.sfx_all("slam", global_position, 6.0, 0.6)
	Net.toast_all("The trap backfired! It's tuned to the wrong ghost.")
	Net.log_all("Trap tuned to %s backfired. Not that one." % GhostDB.by_id(Game.tuned_ghost_id).name)
	for actor in Game.living_actors():
		actor.change_sanity(-20.0)
	ghost.force_hunt()


func status_text() -> String:
	if Game.tuned_ghost_id == "":
		return "Not tuned. Choose a ghost in the notebook."
	return "Tuned to %s" % GhostDB.by_id(Game.tuned_ghost_id).name
