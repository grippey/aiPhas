extends Item
## Burns blue near some ghosts, steadies your nerves, and draws in a Cinder.

const BLUE_RANGE := 5.5
const BURN_TIME := 300.0

var lit := false
var burn_left := BURN_TIME
var _light: OmniLight3D
var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _wax: MeshInstance3D


func _define() -> void:
	net_props = ["lit", "burn_left"]
	item_id = "candle"
	display_name = "Candle"
	description = "LMB: light / snuff"
	hand_offset = Vector3(-0.03, -0.1, 0)
	collider_size = Vector3(0.1, 0.22, 0.1)
	collider_center = Vector3(0, 0.1, 0)


func _build() -> void:
	add_to_group("candles")
	Mk.cyl(self, 0.09, 0.075, 0.015, Vector3(0, 0.008, 0), Mk.mat(Color(0.45, 0.35, 0.2), 0.4))
	_wax = Mk.cyl(self, 0.03, 0.03, 0.16, Vector3(0, 0.09, 0), Mk.mat(Color(0.85, 0.82, 0.7), 0.7))
	_flame_mat = Mk.mat(Color(1, 0.7, 0.3), 0.5, Color(1, 0.6, 0.2), 4.0)
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame = Mk.sphere(self, 0.02, Vector3(0, 0.195, 0), _flame_mat)
	_flame.scale = Vector3(1, 1.8, 1)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.25, 0)
	_light.omni_range = 5.0
	_light.light_energy = 1.0
	add_child(_light)
	set_lit(false)


func _process(delta: float) -> void:
	if not lit:
		return
	burn_left -= delta
	if burn_left <= 0.0:
		set_lit(false)
		Game.toast.emit("The candle burned out.")
		return
	var ghost := Game.ghost
	var blue := ghost != null and ghost.has_evidence(GhostDB.Ev.BLUE_FLAME) and ghost.global_position.distance_to(global_position) < BLUE_RANGE
	var color := Color(0.25, 0.5, 1.0) if blue else Color(1.0, 0.6, 0.22)
	_flame_mat.emission = _flame_mat.emission.lerp(color, delta * 4.0)
	_light.light_color = _flame_mat.emission
	_light.light_energy = 0.9 + sin(Time.get_ticks_msec() * 0.013) * 0.12 + randf() * 0.1
	_flame.scale.y = 1.8 + randf() * 0.3


func set_lit(value: bool) -> void:
	lit = value and burn_left > 0.0
	_flame.visible = lit
	_light.visible = lit


func use() -> void:
	if burn_left <= 0.0:
		Game.toast.emit("This candle is spent.")
		return
	set_lit(not lit)
	Sfx.play_ui("flame", -14.0, 1.4)


func _on_stowed(stowed: bool) -> void:
	if stowed:
		set_lit(false)


func status_text() -> String:
	if burn_left <= 0.0:
		return "Burned out"
	if not lit:
		return "Unlit"
	return "Burning: %d s left. Watch the flame's colour." % int(burn_left)


func snuff_by_ghost() -> void:
	if lit:
		set_lit(false)
		net_push()
		Net.sfx_all("flame", global_position, -2.0, 0.7)


func is_bait_on() -> bool:
	return lit


func _on_net_state() -> void:
	set_lit(lit)
