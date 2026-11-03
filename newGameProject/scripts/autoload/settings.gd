extends Node
## Saves the nickname, video and sound options to user://settings.cfg and applies them.

signal changed

const PATH := "user://settings.cfg"
const NICK_LIMIT := 16
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const WINDOW_MODES := ["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"]
const MSAA_MODES := ["Off", "2x", "4x"]
const SHADOW_MODES := ["Low", "Medium", "High"]
const FPS_LIMITS := [0, 30, 60, 120, 144, 240]

var nickname := "Hunter"
var last_address := "127.0.0.1"

var window_mode := 0
var resolution := 0
var vsync := true
var fps_limit := 0
var render_scale := 1.0
var msaa := 0
var shadows := 1
var brightness := 1.0
var fov := 72.0

var master_volume := 1.0
var ambience_volume := 1.0
var effects_volume := 1.0

var _has_saved_window := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	apply_sound()
	apply_video()


func clean_nickname(text: String) -> String:
	var cleaned := text.strip_edges().left(NICK_LIMIT)
	return cleaned if cleaned != "" else "Hunter"


func save() -> void:
	var c := ConfigFile.new()
	c.set_value("player", "nickname", nickname)
	c.set_value("player", "last_address", last_address)
	c.set_value("video", "window_mode", window_mode)
	c.set_value("video", "resolution", resolution)
	c.set_value("video", "vsync", vsync)
	c.set_value("video", "fps_limit", fps_limit)
	c.set_value("video", "render_scale", render_scale)
	c.set_value("video", "msaa", msaa)
	c.set_value("video", "shadows", shadows)
	c.set_value("video", "brightness", brightness)
	c.set_value("video", "fov", fov)
	c.set_value("sound", "master", master_volume)
	c.set_value("sound", "ambience", ambience_volume)
	c.set_value("sound", "effects", effects_volume)
	c.save(PATH)


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	_has_saved_window = true
	nickname = clean_nickname(c.get_value("player", "nickname", nickname))
	last_address = c.get_value("player", "last_address", last_address)
	window_mode = c.get_value("video", "window_mode", window_mode)
	resolution = c.get_value("video", "resolution", resolution)
	vsync = c.get_value("video", "vsync", vsync)
	fps_limit = c.get_value("video", "fps_limit", fps_limit)
	render_scale = c.get_value("video", "render_scale", render_scale)
	msaa = c.get_value("video", "msaa", msaa)
	shadows = c.get_value("video", "shadows", shadows)
	brightness = c.get_value("video", "brightness", brightness)
	fov = c.get_value("video", "fov", fov)
	master_volume = c.get_value("sound", "master", master_volume)
	ambience_volume = c.get_value("sound", "ambience", ambience_volume)
	effects_volume = c.get_value("sound", "effects", effects_volume)


func apply_sound() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Ambience", ambience_volume)
	_set_bus("Effects", effects_volume)


func _set_bus(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(volume))
	AudioServer.set_bus_mute(index, volume <= 0.001)


func apply_video() -> void:
	var viewport := get_viewport()
	viewport.scaling_3d_scale = render_scale
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][msaa]
	viewport.positional_shadow_atlas_size = [2048, 4096, 8192][shadows]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 8192][shadows], true)
	Engine.max_fps = FPS_LIMITS[fps_limit]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	# Leave the window alone until the player has chosen something, so the first
	# launch, and running inside the editor, keep their normal window.
	if _has_saved_window:
		_apply_window()
	changed.emit()


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var modes := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if DisplayServer.window_get_mode() != modes[window_mode]:
		DisplayServer.window_set_mode(modes[window_mode])
	if window_mode == 0:
		var wanted: Vector2i = RESOLUTIONS[resolution]
		if DisplayServer.window_get_size() != wanted:
			DisplayServer.window_set_size(wanted)
			var screen := DisplayServer.screen_get_position() + (DisplayServer.screen_get_size() - wanted) / 2
			DisplayServer.window_set_position(screen)


## Called when the player changes a window option in the menu.
func window_option_changed() -> void:
	_has_saved_window = true
	apply_video()
