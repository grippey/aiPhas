extends Control
## The main menu: nickname, play solo, host or join a game, options, how to play.

const HOW_TO_PLAY := """You have been hired to clear a haunted house. Something is in there, and you don't yet know what.

1.  Take up to 3 items from the table by the truck, then go in through the front door. The house is different every time.
2.  Use your tools to gather evidence, and mark it in your notebook.
3.  Work out which of the 14 ghosts it is and tune your Ghost Trap to it. Its notebook page says how to catch it.
4.  Set the trap down, set up the bait the ghost needs, and hold it inside the ring until it is captured.

If the lights flicker and your heart starts to pound, it's hunting. Run, hide in a wardrobe, burn a smudge stick, or get out of the house.

People on the street will come and ask what's going on. Talk to them and find the answer each person wants to hear. Ignore them and someone calls the police.

In a group, a caught player watches the others. The team only loses when everyone has been caught.

WASD move     Shift run     C crouch     E interact     Hold V emote wheel
LMB use item     G set item down     1 2 3 / wheel change slot
Tab notebook     Esc pause"""

var _nick: LineEdit
var _address: LineEdit
var _message: Label
var _main_panel: Control
var _lobby_panel: Control
var _options_panel: Control
var _help_panel: Control
var _roster: Label
var _lobby_hint: Label
var _start_button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.035)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := Control.new()
	center.add_child(stack)

	_main_panel = _build_main()
	center.add_child(_main_panel)
	_lobby_panel = _build_lobby()
	center.add_child(_lobby_panel)
	_help_panel = _build_help()
	center.add_child(_help_panel)
	var options := OptionsPanel.new()
	options.closed.connect(_show.bind("main"))
	_options_panel = options
	center.add_child(options)
	stack.queue_free()

	Net.roster_changed.connect(_refresh_lobby)
	Net.join_failed.connect(_on_join_failed)
	Net.left_session.connect(_on_left_session)

	_message.text = Net.menu_message
	Net.menu_message = ""
	if Net.open_lobby_on_menu and Net.is_online():
		Net.open_lobby_on_menu = false
		_show("lobby")
		_refresh_lobby()
	else:
		_show("main")


func _show(which: String) -> void:
	_main_panel.visible = which == "main"
	_lobby_panel.visible = which == "lobby"
	_options_panel.visible = which == "options"
	_help_panel.visible = which == "help"


func _column(width: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override("separation", 10)
	return col


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(action)
	return b


func _build_main() -> Control:
	var col := _column(460)
	var title := Label.new()
	title.text = "RESIDUAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.65, 0.8, 0.95))
	col.add_child(title)

	var nick_label := Label.new()
	nick_label.text = "Nickname (doesn't have to be unique)"
	col.add_child(nick_label)
	_nick = LineEdit.new()
	_nick.text = Settings.nickname
	_nick.max_length = Settings.NICK_LIMIT
	_nick.placeholder_text = "Hunter"
	_nick.custom_minimum_size = Vector2(0, 40)
	_nick.text_changed.connect(func(_t): _save_nickname())
	col.add_child(_nick)

	col.add_child(HSeparator.new())
	col.add_child(_button("Play Solo", _play_solo))
	col.add_child(_button("Host a Game", _host))

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_address = LineEdit.new()
	_address.text = Settings.last_address
	_address.placeholder_text = "Host's IP address"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address)
	var join := _button("Join Game", _join)
	join.custom_minimum_size = Vector2(150, 42)
	join_row.add_child(join)
	col.add_child(join_row)

	col.add_child(HSeparator.new())
	col.add_child(_button("How to Play", _show.bind("help")))
	col.add_child(_button("Options", _show.bind("options")))
	col.add_child(_button("Quit", func(): get_tree().quit()))

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color(1.0, 0.7, 0.45))
	col.add_child(_message)
	return col


func _build_lobby() -> Control:
	var col := _column(460)
	var title := Label.new()
	title.text = "Lobby"
	title.add_theme_font_size_override("font_size", 40)
	col.add_child(title)
	_lobby_hint = Label.new()
	_lobby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_lobby_hint)
	col.add_child(HSeparator.new())
	_roster = Label.new()
	_roster.custom_minimum_size = Vector2(0, 150)
	_roster.add_theme_font_size_override("font_size", 20)
	col.add_child(_roster)
	_start_button = _button("Start the Job", func(): Net.start_game())
	col.add_child(_start_button)
	col.add_child(_button("Leave", _leave_lobby))
	return col


func _build_help() -> Control:
	var col := _column(760)
	var body := Label.new()
	body.text = HOW_TO_PLAY
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	col.add_child(_button("Back", _show.bind("main")))
	return col


func _save_nickname() -> void:
	Settings.nickname = Settings.clean_nickname(_nick.text)
	Settings.save()


func _play_solo() -> void:
	_save_nickname()
	Net.start_solo()


func _host() -> void:
	_save_nickname()
	var err := Net.host_game()
	if err != OK:
		_message.text = "Couldn't host on port %d. Is another copy of the game hosting?" % Net.DEFAULT_PORT
		return
	_show("lobby")
	_refresh_lobby()


func _join() -> void:
	_save_nickname()
	var address := _address.text.strip_edges()
	if address == "":
		_message.text = "Type in the host's IP address first."
		return
	Settings.last_address = address
	Settings.save()
	var err := Net.join_game(address)
	if err != OK:
		_message.text = "That address doesn't look right."
		return
	_show("lobby")
	_refresh_lobby()


func _leave_lobby() -> void:
	Net.close_connection()
	_show("main")


func _on_join_failed(reason: String) -> void:
	_message.text = reason
	_show("main")


func _on_left_session(reason: String) -> void:
	_message.text = reason
	_show("main")


func _refresh_lobby() -> void:
	var lines: Array[String] = []
	var ids: Array = Net.players.keys()
	ids.sort()
	for id in ids:
		lines.append("%s%s" % [Net.players[id], "  (host)" if id == 1 else ""])
	_roster.text = "\n".join(lines) if not lines.is_empty() else "Connecting..."
	_start_button.visible = Net.is_host()
	if Net.is_host():
		_lobby_hint.text = "Friends join with your IP address.\nOn your network: %s\nOver the internet they need your public IP, and UDP port %d forwarded on your router." % [_local_addresses(), Net.DEFAULT_PORT]
	else:
		_lobby_hint.text = "Waiting for the host to start..."


func _local_addresses() -> String:
	var found: Array[String] = []
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		found.append(address)
	return ", ".join(found) if not found.is_empty() else "unknown"
