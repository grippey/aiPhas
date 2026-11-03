class_name DialoguePanel
extends Control
## The conversation with a bystander. Answers are shuffled so the right tone has
## to be worked out from what the person said, not from where the button is.

var bystander: Bystander

var _name_label: Label
var _line_label: Label
var _trust_bar: ProgressBar
var _choices: VBoxContainer
var _closed_callback: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_bottom = -70
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.5, 0.45)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name_label)
	var trust_label := Label.new()
	trust_label.text = "Trust"
	trust_label.add_theme_font_size_override("font_size", 12)
	top.add_child(trust_label)
	_trust_bar = ProgressBar.new()
	_trust_bar.custom_minimum_size = Vector2(150, 10)
	_trust_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trust_bar.max_value = Bystander.TRUST_NEEDED
	_trust_bar.show_percentage = false
	top.add_child(_trust_bar)
	_line_label = Label.new()
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(720, 0)
	_line_label.add_theme_font_size_override("font_size", 16)
	col.add_child(_line_label)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	col.add_child(_choices)


func open(who: Bystander, on_closed: Callable) -> void:
	bystander = who
	_closed_callback = on_closed
	who.begin_talk()
	_name_label.text = who.person.name
	_update_trust()
	visible = true
	if who.is_caller:
		_show_question(who.next_question())
	else:
		_show_line(who.opening_line(), false)


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(bystander):
		bystander.end_talk()
	bystander = null
	if _closed_callback.is_valid():
		_closed_callback.call()


func _show_line(text: String, finished: bool) -> void:
	_line_label.text = text
	_clear_choices()
	if finished:
		_add_choice("Leave", close)
	else:
		_add_choice("Continue", func(): _show_question(bystander.next_question()))
		_add_choice("Walk away", close)


func _show_question(q: Dictionary) -> void:
	_line_label.text = q.line
	_clear_choices()
	var tones: Array = BystanderDB.TONES.duplicate()
	tones.shuffle()
	for tone in tones:
		_add_choice(q[tone], _answer.bind(tone))
	var item := Game.player.active_item()
	if item != null and item.item_id == "permit_folder" and item.can_show():
		_add_choice("[Show them a permit]", _show_permit.bind(item))
	_add_choice("Walk away", close)


func _answer(tone: String) -> void:
	Sfx.play_ui("chatter", -6.0)
	var result := bystander.respond(tone)
	_update_trust()
	_show_line(result.reply, result.done)


func _show_permit(item: Item) -> void:
	item.spend()
	item.net_push()
	Sfx.play_ui("click", -4.0)
	var reply := bystander.accept_permit()
	_update_trust()
	_show_line(reply, true)


func _update_trust() -> void:
	_trust_bar.value = bystander.trust


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _add_choice(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(action)
	_choices.add_child(b)
