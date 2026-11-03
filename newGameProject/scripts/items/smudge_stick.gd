extends Item
## Burns for a while. Its smoke breaks off a hunt, keeps new hunts away and
## steadies your nerves. It is also what holds a Fury inside a trap.

const BURN_TIME := 14.0
const REACH := 6.0

var uses := 3
var burn_left := 0.0
var _smoke: GPUParticles3D
var _tip: StandardMaterial3D
var _applied := false


func _define() -> void:
	net_props = ["uses", "burn_left"]
	item_id = "smudge_stick"
	display_name = "Smudge Stick"
	description = "LMB: light it. Smoke drives off a nearby ghost."
	hand_offset = Vector3(0, -0.04, 0)
	collider_size = Vector3(0.08, 0.24, 0.08)
	collider_center = Vector3(0, 0.1, 0)


func _build() -> void:
	Mk.cyl(self, 0.03, 0.022, 0.2, Vector3(0, 0.1, 0), Mk.mat(Color(0.4, 0.45, 0.3), 1.0))
	_tip = Mk.mat(Color(0.1, 0.08, 0.06), 1.0, Color(1.0, 0.4, 0.1), 0.0)
	Mk.sphere(self, 0.031, Vector3(0, 0.2, 0), _tip)

	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0, 0.12, 0)
	process.scale_min = 0.5
	process.scale_max = 1.8
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_color = Color(0.7, 0.72, 0.75, 0.13)
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = smoke_mat
	_smoke = GPUParticles3D.new()
	_smoke.draw_pass_1 = quad
	_smoke.process_material = process
	_smoke.amount = 40
	_smoke.lifetime = 2.6
	_smoke.position = Vector3(0, 0.22, 0)
	_smoke.emitting = false
	add_child(_smoke)


func _process(delta: float) -> void:
	if burn_left <= 0.0:
		return
	burn_left -= delta
	if not _applied and Net.is_host():
		var ghost := Game.ghost
		if ghost != null and ghost.global_position.distance_to(global_position) < REACH and ghost.on_smudged():
			_applied = true
	if burn_left <= 0.0:
		_smoke.emitting = false
		_tip.emission_energy_multiplier = 0.0


func use() -> void:
	if burn_left > 0.0:
		Game.toast.emit("It's already burning.")
		return
	if uses <= 0:
		Game.toast.emit("Nothing left of this one to burn.")
		return
	uses -= 1
	burn_left = BURN_TIME
	_applied = false
	_smoke.emitting = true
	_tip.emission_energy_multiplier = 3.0
	Game.change_sanity(12.0)
	Sfx.play_ui("flame", -8.0)


func status_text() -> String:
	if burn_left > 0.0:
		return "Smoking: %d s" % ceili(burn_left)
	return "Burns left: %d" % uses


func is_bait_on() -> bool:
	return burn_left > 0.0


func _on_net_state() -> void:
	_applied = false
	_smoke.emitting = burn_left > 0.0
	_tip.emission_energy_multiplier = 3.0 if burn_left > 0.0 else 0.0
