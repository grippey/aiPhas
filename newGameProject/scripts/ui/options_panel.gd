class_name OptionsPanel
extends PanelContainer
## Video and sound options, used by both the main menu and the pause screen.

signal closed


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.4, 0.5)
	style.set_content_margin_all(22)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(620, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var heading := Label.new()
	heading.text = "Options"
	heading.add_theme_font_size_override("font_size", 30)
	col.add_child(heading)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 390)
	col.add_child(tabs)
	tabs.add_child(_build_video())
	tabs.add_child(_build_sound())

	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(0, 40)
	done.pressed.connect(func():
		Settings.save()
		closed.emit())
	col.add_child(done)


func _build_video() -> Control:
	var grid := _page("Video")
	_choice(grid, "Window mode", Settings.WINDOW_MODES, Settings.window_mode, func(i):
		Settings.window_mode = i
		Settings.window_option_changed())
	var sizes: Array = Settings.RESOLUTIONS.map(func(r): return "%d x %d" % [r.x, r.y])
	_choice(grid, "Resolution (windowed)", sizes, Settings.resolution, func(i):
		Settings.resolution = i
		Settings.window_option_changed())
	_toggle(grid, "VSync", Settings.vsync, func(on):
		Settings.vsync = on
		Settings.apply_video())
	var limits: Array = Settings.FPS_LIMITS.map(func(f): return "Unlimited" if f == 0 else str(f))
	_choice(grid, "Frame rate limit", limits, Settings.fps_limit, func(i):
		Settings.fps_limit = i
		Settings.apply_video())
	_choice(grid, "Anti-aliasing", Settings.MSAA_MODES, Settings.msaa, func(i):
		Settings.msaa = i
		Settings.apply_video())
	_choice(grid, "Shadow quality", Settings.SHADOW_MODES, Settings.shadows, func(i):
		Settings.shadows = i
		Settings.apply_video())
	_slider(grid, "Render scale", 0.5, 1.0, 0.05, Settings.render_scale, "%d%%", 100.0, func(v):
		Settings.render_scale = v
		Settings.apply_video())
	_slider(grid, "Brightness", 0.6, 1.8, 0.05, Settings.brightness, "%d%%", 100.0, func(v):
		Settings.brightness = v
		Settings.apply_video())
	_slider(grid, "Field of view", 60.0, 100.0, 1.0, Settings.fov, "%d", 1.0, func(v):
		Settings.fov = v
		Settings.apply_video())
	return grid.get_parent()


func _build_sound() -> Control:
	var grid := _page("Sound")
	_slider(grid, "Master volume", 0.0, 1.0, 0.01, Settings.master_volume, "%d%%", 100.0, func(v):
		Settings.master_volume = v
		Settings.apply_sound())
	_slider(grid, "Ambience", 0.0, 1.0, 0.01, Settings.ambience_volume, "%d%%", 100.0, func(v):
		Settings.ambience_volume = v
		Settings.apply_sound())
	_slider(grid, "Effects", 0.0, 1.0, 0.01, Settings.effects_volume, "%d%%", 100.0, func(v):
		Settings.effects_volume = v
		Settings.apply_sound()
		Sfx.play_ui("click", -6.0))
	return grid.get_parent()


func _page(title: String) -> GridContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(grid)
	return grid


func _label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(190, 0)
	grid.add_child(l)


func _choice(grid: GridContainer, text: String, options: Array, current: int, action: Callable) -> void:
	_label(grid, text)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for o in options:
		picker.add_item(o)
	picker.select(current)
	picker.item_selected.connect(action)
	grid.add_child(picker)
	grid.add_child(Control.new())


func _toggle(grid: GridContainer, text: String, current: bool, action: Callable) -> void:
	_label(grid, text)
	var box := CheckButton.new()
	box.button_pressed = current
	box.toggled.connect(action)
	grid.add_child(box)
	grid.add_child(Control.new())


func _slider(grid: GridContainer, text: String, low: float, high: float, step: float, current: float, display: String, display_scale: float, action: Callable) -> void:
	_label(grid, text)
	var bar := HSlider.new()
	bar.min_value = low
	bar.max_value = high
	bar.step = step
	bar.value = current
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(bar)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(50, 0)
	readout.text = display % roundi(current * display_scale)
	grid.add_child(readout)
	bar.value_changed.connect(func(v):
		readout.text = display % roundi(v * display_scale)
		action.call(v))
