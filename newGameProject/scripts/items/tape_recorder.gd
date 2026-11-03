extends Item
## Press once to record (setting it down also starts recording), press to stop,
## press again to play the tape back. Ghosts with the EVP evidence leave a voice
## on the tape if the recorder spends long enough near them.

enum Mode { IDLE, RECORDING, READY, PLAYING }

const MAX_RECORD := 30.0
const HEAR_RANGE := 8.0
const TIME_NEEDED := 3.0
const PLAY_TIME := 3.5

var mode := Mode.IDLE
var _record_left := 0.0
var _caught := 0.0
var _line := ""
var _play_left := 0.0
var _led: StandardMaterial3D
var _in_hand := false


func _define() -> void:
	net_props = ["mode", "_record_left"]
	item_id = "tape_recorder"
	display_name = "Tape Recorder"
	description = "LMB: record, stop, play back. Setting it down starts recording."
	hand_rotation = Vector3(0.4, 0, 0)
	collider_size = Vector3(0.16, 0.08, 0.1)
	collider_center = Vector3(0, 0.04, 0)


func _build() -> void:
	Mk.box(self, Vector3(0.15, 0.05, 0.09), Vector3(0, 0.025, 0), Mk.mat(Color(0.16, 0.16, 0.18), 0.5))
	for x in [-0.035, 0.035]:
		Mk.cyl(self, 0.018, 0.018, 0.006, Vector3(x, 0.052, 0), Mk.mat(Color(0.65, 0.62, 0.55), 0.4))
	_led = Mk.mat(Color(0.2, 0.02, 0.02), 0.3, Color(1.0, 0.1, 0.05), 0.0)
	Mk.sphere(self, 0.006, Vector3(0.06, 0.052, 0.03), _led)


func _process(delta: float) -> void:
	match mode:
		Mode.RECORDING:
			_led.emission_energy_multiplier = 4.0 if fmod(Time.get_ticks_msec() * 0.002, 1.0) < 0.5 else 0.5
			_record_left -= delta
			var ghost := Game.ghost
			if ghost != null and ghost.has_evidence(GhostDB.Ev.EVP) and ghost.global_position.distance_to(global_position) < HEAR_RANGE:
				_caught += delta
				if _line == "" and _caught >= TIME_NEEDED:
					_line = ghost.spirit_reply()
			if _record_left <= 0.0:
				_stop_recording()
		Mode.PLAYING:
			_play_left -= delta
			if _play_left <= 0.0:
				mode = Mode.IDLE


func _start_recording() -> void:
	mode = Mode.RECORDING
	_record_left = MAX_RECORD
	_caught = 0.0
	_line = ""


func _stop_recording() -> void:
	mode = Mode.READY
	_led.emission_energy_multiplier = 0.0


func use() -> void:
	Sfx.play_ui("click", -6.0, 0.7)
	match mode:
		Mode.IDLE:
			_start_recording()
		Mode.RECORDING:
			_stop_recording()
		Mode.READY:
			mode = Mode.PLAYING
			_play_left = PLAY_TIME
			Net.noise(global_position, 7.0)
			if _line != "":
				Sfx.play_ui("whisper", 2.0, 0.6)
				Game.subtitle.emit("On the tape: \"%s\"" % _line)
				Game.change_sanity(-2.0)
			else:
				Sfx.play_ui("flame", -8.0, 0.5)
				Game.subtitle.emit("On the tape: only hiss.")


func _on_picked_up() -> void:
	_in_hand = true


## Only the player setting it down starts a recording, not the table at the start
## of a run or a Magpie moving it.
func _on_placed() -> void:
	if _in_hand and mode == Mode.IDLE:
		_start_recording()
	_in_hand = false


func status_text() -> String:
	match mode:
		Mode.RECORDING:
			return "Recording: %d s left" % ceili(_record_left)
		Mode.READY:
			return "Tape ready. LMB to play."
		Mode.PLAYING:
			return "Playing..."
	return "Blank tape"


func is_bait_on() -> bool:
	return mode == Mode.RECORDING or mode == Mode.PLAYING


func _on_net_state() -> void:
	if mode == Mode.PLAYING:
		_play_left = PLAY_TIME
	elif mode != Mode.RECORDING:
		_led.emission_energy_multiplier = 0.0
