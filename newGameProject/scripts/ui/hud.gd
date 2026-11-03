extends CanvasLayer
## HUD, 3-slot hotbar, and the title, pause and end screens.

var _prompt: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _status: Label
var _toast: Label
var _subtitle: Label
var _sanity: ProgressBar
var _stamina: ProgressBar
var _location: Label
var _hunt_flash: ColorRect
var _hide_overlay: Control
var _photo: TextureRect
var _crosshair: ColorRect

var _toast_time := 0.0
var _subtitle_time := 0.0
var _photo_time := 0.0

var _gameplay: Control
var _notebook: Notebook
var _waiting: Label
var _team: Label
var _options: Control
var _pause: Control
var _end_primary: Button
var _end: Control
var _end_title: Label
var _end_text: Label
var _style_on: StyleBoxFlat
var _style_off: StyleBoxFlat
var _suspicion: ProgressBar
var _police_label: Label
var _dialogue: DialoguePanel
var _wheel: Control
var _wheel_labels: Array[Label] = []
var _wheel_motion := Vector2.ZERO
var _wheel_choice := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.hud = self
	_build_gameplay()
	_notebook = Notebook.new()
	_notebook.visible = false
	add_child(_notebook)
	_dialogue = DialoguePanel.new()
	_dialogue.visible = false
	add_child(_dialogue)
	_wheel = _build_emote_wheel()
	add_child(_wheel)
	_pause = _build_pause()
	add_child(_pause)
	_options = _build_options()
	add_child(_options)
	_end = _build_end()
	add_child(_end)
	Game.toast.connect(_show_toast)
	Game.subtitle.connect(_show_subtitle)
	Game.log_added.connect(_show_toast)
	Game.finished.connect(_on_finished)
	Game.photo_taken.connect(_show_photo)
	Game.talk_requested.connect(_open_dialogue)
	Game.play_started.connect(_begin)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if Game.waiting_for_players or _end.visible or _options.visible:
		return
	if _handle_wheel_input(event):
		return
	if _dialogue.visible:
		if event.is_action_pressed("pause"):
			_dialogue.close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("notebook") and not _pause.visible:
		_set_notebook(not _notebook.visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if _notebook.visible:
			_set_notebook(false)
		else:
			_set_paused(not _pause.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not _notebook.visible and not _pause.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if Game.player == null:
		return
	var player := Game.player
	_prompt.text = player.focus_prompt
	_update_team(player)
	_crosshair.visible = player.hiding_in == null and not player.dead
	_hide_overlay.visible = player.hiding_in != null
	for i in Player.SLOTS:
		var item: Item = player.slots[i]
		_slot_labels[i].text = "%d  %s" % [i + 1, item.display_name if item != null else "empty"]
		_slot_panels[i].add_theme_stylebox_override("panel", _style_on if i == player.active_slot else _style_off)
	var active := player.active_item()
	if active != null:
		var read := active.status_text()
		_status.text = "%s\n%s" % [active.description, read] if read != "" else active.description
	else:
		_status.text = ""
	_sanity.value = Game.sanity
	_stamina.value = player.stamina
	_suspicion.value = Game.suspicion
	_police_label.visible = Game.police_left >= 0.0
	if _police_label.visible:
		_police_label.text = "POLICE ARRIVING IN %d" % ceili(Game.police_left)
	var room := Game.house.room_at(player.global_position)
	_location.text = room.name if room != null else "Outside"

	_toast_time -= delta
	_toast.visible = _toast_time > 0.0
	_subtitle_time -= delta
	_subtitle.visible = _subtitle_time > 0.0
	_photo_time -= delta
	_photo.visible = _photo_time > 0.0
	_hunt_flash.visible = Game.hunting
	if Game.hunting:
		_hunt_flash.color.a = 0.08 + 0.07 * sin(Time.get_ticks_msec() * 0.009)


func _begin() -> void:
	_waiting.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.start_ambience()


## Lists the team, and shows who a caught player is watching.
func _update_team(player: Player) -> void:
	if Net.is_solo():
		_team.visible = false
		return
	_team.visible = true
	var lines: Array[String] = []
	var ids: Array = Game.actors.keys()
	ids.sort()
	for id in ids:
		var a: Actor = Game.actors[id]
		if is_instance_valid(a):
			lines.append("%s%s" % [a.nickname, "  (caught)" if a.dead else ""])
	_team.text = "\n".join(lines)
	if player.dead and player.spectating != null and is_instance_valid(player.spectating):
		_prompt.text = "You were caught. Watching %s. Click to switch." % player.spectating.nickname


func _set_notebook(open: bool) -> void:
	_notebook.visible = open
	Game.input_locked = open
	if open:
		_notebook._refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _open_dialogue(who: Bystander) -> void:
	Game.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dialogue.open(who, _on_dialogue_closed)


func _on_dialogue_closed() -> void:
	Game.input_locked = false
	if not Game.over:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Returns true if the wheel used this event.
func _handle_wheel_input(event: InputEvent) -> bool:
	if _wheel.visible:
		if event is InputEventMouseMotion:
			_wheel_motion = (_wheel_motion + event.relative).limit_length(120.0)
			_update_wheel_choice()
			get_viewport().set_input_as_handled()
			return true
		if event.is_action_released("emote"):
			_close_wheel()
			get_viewport().set_input_as_handled()
			return true
		return false
	if event.is_action_pressed("emote") and not Game.input_locked and not _pause.visible:
		_wheel.visible = true
		_wheel_motion = Vector2.ZERO
		_wheel_choice = -1
		Game.emote_wheel_open = true
		_update_wheel_choice()
		get_viewport().set_input_as_handled()
		return true
	return false


func _update_wheel_choice() -> void:
	_wheel_choice = -1
	if _wheel_motion.length() > 25.0:
		var count := _wheel_labels.size()
		var angle := fposmod(_wheel_motion.angle() + PI / 2.0 + PI / count, TAU)
		_wheel_choice = int(angle / TAU * count) % count
	for i in _wheel_labels.size():
		_wheel_labels[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if i == _wheel_choice else Color(0.85, 0.85, 0.85))
		_wheel_labels[i].add_theme_font_size_override("font_size", 22 if i == _wheel_choice else 17)


func _close_wheel() -> void:
	_wheel.visible = false
	Game.emote_wheel_open = false
	if _wheel_choice >= 0:
		Game.player.play_emote(EmoteRig.EMOTES[_wheel_choice].id)


func _build_emote_wheel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var disc := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.72)
	style.set_corner_radius_all(190)
	disc.add_theme_stylebox_override("panel", style)
	disc.position = Vector2(-190, -190)
	disc.size = Vector2(380, 380)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(disc)
	var count := EmoteRig.EMOTES.size()
	for i in count:
		var angle := -PI / 2.0 + TAU * i / count
		var label := Label.new()
		label.text = EmoteRig.EMOTES[i].name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(130, 40)
		label.position = Vector2(cos(angle), sin(angle)) * 135.0 - label.size / 2.0
		center.add_child(label)
		_wheel_labels.append(label)
	return root


## The world only really stops in a solo game. Other people are still playing otherwise.
func _set_paused(paused: bool) -> void:
	_pause.visible = paused
	Game.input_locked = paused
	if Net.is_solo():
		get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_time = 4.0


func _show_subtitle(text: String) -> void:
	_subtitle.text = text
	_subtitle_time = 3.5


func _show_photo(tex: Texture2D) -> void:
	_photo.texture = tex
	_photo_time = 2.5


func _on_finished(won: bool, message: String) -> void:
	_set_notebook(false)
	_dialogue.close()
	_end_title.text = "GHOST TRAPPED" if won else (Game.end_title if Game.end_title != "" else "YOU DIED")
	_end_title.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6) if won else Color(0.9, 0.15, 0.1))
	_end_text.text = message
	if Net.is_solo():
		_end_primary.text = "Take another job"
	elif Net.is_host():
		_end_primary.text = "Back to the lobby"
	else:
		_end_primary.text = "Waiting for the host..."
		_end_primary.disabled = true
	_pause.visible = false
	_options.visible = false
	_end.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_gameplay() -> void:
	_gameplay = Control.new()
	_gameplay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gameplay)

	var grad := Gradient.new()
	grad.set_offset(0, 0.45)
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(0, 0, 0, 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	var vignette := TextureRect.new()
	vignette.texture = tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay.add_child(vignette)

	_hunt_flash = ColorRect.new()
	_hunt_flash.color = Color(0.7, 0.0, 0.0, 0.1)
	_hunt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hunt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hunt_flash.visible = false
	_gameplay.add_child(_hunt_flash)

	_hide_overlay = _build_hide_overlay()
	_gameplay.add_child(_hide_overlay)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.55)
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-2, -2)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay.add_child(_crosshair)

	_prompt = _center_label(18, 0.57)
	_toast = _center_label(18, 0.2)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_subtitle = _center_label(26, 0.68)
	_subtitle.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))

	# Hotbar
	_style_on = StyleBoxFlat.new()
	_style_on.bg_color = Color(0.3, 0.28, 0.2, 0.85)
	_style_on.set_border_width_all(2)
	_style_on.border_color = Color(1.0, 0.85, 0.5)
	_style_on.set_content_margin_all(8)
	_style_off = StyleBoxFlat.new()
	_style_off.bg_color = Color(0.05, 0.05, 0.06, 0.65)
	_style_off.set_border_width_all(1)
	_style_off.border_color = Color(0.4, 0.4, 0.4, 0.6)
	_style_off.set_content_margin_all(8)
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -14
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay.add_child(bar)
	for i in Player.SLOTS:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(170, 38)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 15)
		panel.add_child(l)
		bar.add_child(panel)
		_slot_panels.append(panel)
		_slot_labels.append(l)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status.offset_bottom = -64
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_constant_override("outline_size", 4)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_gameplay.add_child(_status)

	# Sanity and stamina, top left.
	var stats := VBoxContainer.new()
	stats.position = Vector2(16, 14)
	stats.custom_minimum_size = Vector2(190, 0)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay.add_child(stats)
	_location = Label.new()
	_location.add_theme_font_size_override("font_size", 15)
	stats.add_child(_location)
	_sanity = _bar(100.0, Color(0.45, 0.65, 0.95))
	stats.add_child(_small("Sanity"))
	stats.add_child(_sanity)
	stats.add_child(_small("Stamina"))
	_stamina = _bar(1.0, Color(0.8, 0.75, 0.4))
	stats.add_child(_stamina)
	stats.add_child(_small("Neighbors' suspicion"))
	_suspicion = _bar(100.0, Color(0.9, 0.35, 0.3))
	stats.add_child(_suspicion)

	_police_label = _center_label(24, 0.06)
	_police_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	_police_label.visible = false

	_waiting = _center_label(24, 0.45)
	_waiting.text = "Waiting for everyone to load..."

	_team = Label.new()
	_team.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_team.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_team.offset_left = -220
	_team.offset_right = -16
	_team.offset_top = 14
	_team.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_team.add_theme_font_size_override("font_size", 15)
	_team.add_theme_constant_override("outline_size", 4)
	_team.add_theme_color_override("font_outline_color", Color.BLACK)
	_team.visible = false
	_gameplay.add_child(_team)

	_photo = TextureRect.new()
	_photo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_photo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_photo.offset_left = -300
	_photo.offset_right = -16
	_photo.offset_top = 16
	_photo.offset_bottom = 176
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_photo.visible = false
	_gameplay.add_child(_photo)


func _build_hide_overlay() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	# Two black panels, leaving a slit between the wardrobe doors.
	var left := ColorRect.new()
	left.color = Color(0.01, 0.01, 0.01)
	left.anchor_right = 0.48
	left.anchor_bottom = 1.0
	root.add_child(left)
	var right := ColorRect.new()
	right.color = Color(0.01, 0.01, 0.01)
	right.anchor_left = 0.52
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	root.add_child(right)
	return root


func _center_label(size: int, vertical: float) -> Label:
	var l := Label.new()
	l.anchor_left = 0.1
	l.anchor_right = 0.9
	l.anchor_top = vertical
	l.anchor_bottom = vertical
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay.add_child(l)
	return l


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	return l


func _bar(max_value: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(190, 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.6)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", back)
	return b


func _screen(bg: Color) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	var shade := ColorRect.new()
	shade.color = bg
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(720, 0)
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	return [root, col]


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(action)
	return b


func _heading(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l


func _build_pause() -> Control:
	var parts := _screen(Color(0, 0, 0, 0.7))
	var col: VBoxContainer = parts[1]
	col.add_child(_heading("Paused" if Net.is_solo() else "Menu (the game keeps running)", 36))
	col.add_child(_button("Resume", func(): _set_paused(false)))
	col.add_child(_button("Options", func():
		_pause.visible = false
		_options.visible = true))
	if Net.is_solo():
		col.add_child(_button("Restart", Game.restart))
	col.add_child(_button("Leave to Main Menu", func(): Net.leave_to_menu()))
	return parts[0]


func _build_options() -> Control:
	var root := CenterContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	var panel := OptionsPanel.new()
	panel.closed.connect(func():
		_options.visible = false
		_pause.visible = true)
	root.add_child(panel)
	return root


func _build_end() -> Control:
	var parts := _screen(Color(0.01, 0.01, 0.02, 0.92))
	var col: VBoxContainer = parts[1]
	_end_title = _heading("", 52)
	col.add_child(_end_title)
	_end_text = Label.new()
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_text.add_theme_font_size_override("font_size", 18)
	col.add_child(_end_text)
	_end_primary = _button("Take another job", func():
		if Net.is_solo():
			Game.restart()
		else:
			Net.back_to_lobby())
	col.add_child(_end_primary)
	col.add_child(_button("Leave to Main Menu", func(): Net.leave_to_menu()))
	return parts[0]
