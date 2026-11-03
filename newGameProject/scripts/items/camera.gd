extends Item
## Takes real photos. Ghosts with the Photo evidence appear in them; the rest
## don't, even if you can see them with your own eyes. The flash pins a Watcher.

const VIEW_CONE := 38.0
const VIEW_RANGE := 14.0
const PIN_TIME := 2.5

var film := 12
var flash_serial := 0
var _seen_serial := 0
var _flash: OmniLight3D
var _last_flash := -100.0
var _busy := false


func _define() -> void:
	net_props = ["film", "flash_serial"]
	item_id = "camera"
	display_name = "Camera"
	description = "LMB: take a photo (saved in the notebook)"
	collider_size = Vector3(0.2, 0.14, 0.1)
	collider_center = Vector3(0, 0.07, 0)


func _build() -> void:
	Mk.box(self, Vector3(0.18, 0.11, 0.06), Vector3(0, 0.06, 0), Mk.mat(Color(0.1, 0.1, 0.1), 0.5))
	var lens := Mk.cyl(self, 0.03, 0.035, 0.05, Vector3(0, 0.06, -0.05), Mk.mat(Color(0.05, 0.05, 0.08), 0.15))
	lens.rotation.x = PI / 2
	Mk.box(self, Vector3(0.04, 0.02, 0.02), Vector3(0.06, 0.125, 0), Mk.mat(Color(0.8, 0.8, 0.8), 0.3))
	_flash = OmniLight3D.new()
	_flash.position = Vector3(0, 0.1, -0.2)
	_flash.omni_range = 14.0
	_flash.light_energy = 7.0
	_flash.visible = false
	add_child(_flash)


func use() -> void:
	if _busy:
		return
	if film <= 0:
		Game.toast.emit("Out of film.")
		return
	film -= 1
	_busy = true
	_last_flash = _now()
	flash_serial += 1
	_seen_serial = flash_serial
	Net.noise(global_position, 6.0)
	Sfx.play_ui("shutter")
	var ghost := Game.ghost
	if ghost.has_evidence(GhostDB.Ev.PHOTO):
		ghost.film_override = 1 if ghost.in_view_of(holder, VIEW_CONE, VIEW_RANGE) else ghost.film_override
	else:
		ghost.film_override = 0
	ghost.apply_film_override()
	_flash.visible = true
	holder.hand.visible = false
	Game.hud.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	Game.hud.visible = true
	if holder != null:
		holder.hand.visible = true
	_flash.visible = false
	ghost.film_override = -1
	image.resize(384, 216, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(image)
	Game.photos.append(tex)
	Game.photo_taken.emit(tex)
	_busy = false


func status_text() -> String:
	return "Film left: %d" % film


func bait_works(ghost: Ghost, _trap: Item) -> bool:
	return held and _now() - _last_flash < PIN_TIME and ghost.in_view_of(holder, VIEW_CONE, VIEW_RANGE)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Someone else's camera fired, so show the flash here too.
func _on_net_state() -> void:
	if flash_serial == _seen_serial:
		return
	_seen_serial = flash_serial
	_last_flash = _now()
	_flash.visible = true
	await get_tree().create_timer(0.1, true).timeout
	_flash.visible = false
