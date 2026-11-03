class_name Notebook
extends Control
## The evidence notebook: mark what you've found, narrow down the ghost, read
## its page, and tune the trap to it.

const PAPER := Color(0.82, 0.76, 0.6)
const INK := Color(0.12, 0.09, 0.07)
const FADED := Color(0.4, 0.35, 0.28)
const MARKS := ["[   ]", "[ X ]", "[ - ]"]

var _evidence_buttons := {}
var _ghost_buttons := {}
var _selected := ""

var _page_title: Label
var _page_about: Label
var _page_evidence: Label
var _page_bait: Label
var _stat_bars := {}
var _tune_button: Button
var _tuned_label: Label
var _log_label: Label
var _photo_row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var book := PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.set_corner_radius_all(6)
	paper.set_content_margin_all(18)
	book.add_theme_stylebox_override("panel", paper)
	center.add_child(book)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	book.add_child(columns)
	columns.add_child(_build_left())
	columns.add_child(VSeparator.new())
	columns.add_child(_build_right())
	_refresh()
	Game.log_added.connect(func(_t): _refresh())
	Game.photo_taken.connect(func(_t): _refresh())


func _build_left() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(450, 0)
	col.add_theme_constant_override("separation", 3)
	col.add_child(_label("Evidence", 22))
	col.add_child(_label("Click to cycle: found [ X ], ruled out [ - ], unknown [   ]", 12, FADED))
	var evidence_grid := GridContainer.new()
	evidence_grid.columns = 2
	evidence_grid.add_theme_constant_override("h_separation", 10)
	evidence_grid.add_theme_constant_override("v_separation", 3)
	for e in GhostDB.EVIDENCE:
		var entry: Dictionary = GhostDB.EVIDENCE[e]
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(220, 0)
		cell.add_theme_constant_override("separation", 0)
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 24)
		button.add_theme_font_size_override("font_size", 13)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_cycle_evidence.bind(e))
		_evidence_buttons[e] = button
		cell.add_child(button)
		var hint := _label(entry.hint, 10, FADED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(220, 0)
		cell.add_child(hint)
		evidence_grid.add_child(cell)
	col.add_child(evidence_grid)
	col.add_child(HSeparator.new())
	col.add_child(_label("Ghosts", 22))
	col.add_child(_label("Faded ghosts don't fit your evidence.", 12, FADED))
	var grid := GridContainer.new()
	grid.columns = 4
	for t in GhostDB.TYPES:
		var b := Button.new()
		b.text = t.name
		b.custom_minimum_size = Vector2(108, 26)
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select_ghost.bind(t.id))
		_ghost_buttons[t.id] = b
		grid.add_child(b)
	col.add_child(grid)
	return col


func _build_right() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(450, 0)
	col.add_theme_constant_override("separation", 4)
	_page_title = _label("Choose a ghost", 22)
	col.add_child(_page_title)
	_page_about = _wrapped("Pick a name on the left to read its page.", 13)
	col.add_child(_page_about)
	var stats := GridContainer.new()
	stats.columns = 2
	for s in [["speed", "Speed"], ["aggressiveness", "Aggressiveness"], ["passiveness", "Passiveness"], ["activeness", "Activeness"]]:
		var name_label := _label(s[1], 12)
		name_label.custom_minimum_size = Vector2(115, 0)
		stats.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(300, 12)
		bar.show_percentage = false
		bar.max_value = 1.0
		_stat_bars[s[0]] = bar
		stats.add_child(bar)
	col.add_child(stats)
	_page_evidence = _wrapped("", 13)
	col.add_child(_page_evidence)
	_page_bait = _wrapped("", 13)
	col.add_child(_page_bait)
	_tune_button = Button.new()
	_tune_button.focus_mode = Control.FOCUS_NONE
	_tune_button.disabled = true
	_tune_button.text = "Tune trap to this ghost"
	_tune_button.pressed.connect(_tune_trap)
	col.add_child(_tune_button)
	_tuned_label = _label("", 13)
	col.add_child(_tuned_label)
	col.add_child(HSeparator.new())
	col.add_child(_label("Field log", 15))
	_log_label = _wrapped("", 12)
	_log_label.custom_minimum_size = Vector2(0, 64)
	col.add_child(_log_label)
	col.add_child(_label("Photos (newest first)", 15))
	_photo_row = HBoxContainer.new()
	_photo_row.custom_minimum_size = Vector2(0, 84)
	col.add_child(_photo_row)
	return col


func _label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrapped(text: String, size: int) -> Label:
	var l := _label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	return l


func _cycle_evidence(e: int) -> void:
	Game.evidence_marks[e] = (Game.evidence_marks.get(e, 0) + 1) % 3
	Sfx.play_ui("click", -10.0)
	_refresh()


func _select_ghost(id: String) -> void:
	_selected = id
	Sfx.play_ui("click", -10.0)
	_refresh()


func _tune_trap() -> void:
	Net.tune_trap(_selected)
	Sfx.play_ui("beep", -8.0)
	_refresh()


func _fits(t: Dictionary) -> bool:
	for e in Game.evidence_marks:
		var mark: int = Game.evidence_marks[e]
		if mark == 1 and not (e in t.evidence):
			return false
		if mark == 2 and e in t.evidence:
			return false
	return true


func _refresh() -> void:
	for e in _evidence_buttons:
		var mark: int = Game.evidence_marks.get(e, 0)
		_evidence_buttons[e].text = "%s  %s" % [MARKS[mark], GhostDB.EVIDENCE[e].name]
	for t in GhostDB.TYPES:
		var b: Button = _ghost_buttons[t.id]
		b.modulate.a = 1.0 if _fits(t) else 0.35
		b.text = t.name + (" *" if t.id == Game.tuned_ghost_id else "")

	if _selected != "":
		var t := GhostDB.by_id(_selected)
		_page_title.text = t.name
		_page_about.text = t.about
		_stat_bars.speed.value = t.speed / 4.6
		_stat_bars.aggressiveness.value = t.aggressiveness
		_stat_bars.passiveness.value = t.passiveness
		_stat_bars.activeness.value = t.activeness
		var names: Array[String] = []
		for e in t.evidence:
			names.append(GhostDB.EVIDENCE[e].name)
		_page_evidence.text = "Evidence: " + ", ".join(names)
		_page_bait.text = "To trap it: " + t.bait_text
		_tune_button.disabled = false
		_tune_button.text = "Tune trap to %s" % t.name

	if Game.tuned_ghost_id == "":
		_tuned_label.text = "The trap is not tuned yet."
	else:
		_tuned_label.text = "The trap is tuned to: %s" % GhostDB.by_id(Game.tuned_ghost_id).name

	var recent := Game.field_log.slice(-4)
	_log_label.text = "Nothing logged yet." if recent.is_empty() else "\n".join(recent)

	for child in _photo_row.get_children():
		child.queue_free()
	var shots := Game.photos.slice(-3)
	shots.reverse()
	for tex in shots:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(146, 82)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_photo_row.add_child(rect)
	if shots.is_empty():
		_photo_row.add_child(_label("No photos yet.", 12, FADED))
