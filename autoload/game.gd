extends Node
## Global state: language, input map, scene transitions, sound, music, pause menu, save data.
##
## Command-line user args (after `--`):
##   --scene=res://chapters/ch1/forest.tscn   start directly in a scene (skips title)
##   --fast                                   narrator auto-advances quickly (for testing)
##   --lang=sv                                force language
##   --shots=DIR                              save a screenshot every 2s into DIR (for visual checks)
##   --quit-after-secs=N                      quit after N seconds
##   --warp=N                                 (forest, pond, city) skip the intro and start at tile column N;
##                                            (chase) start at beat N
##   --moves=RRUL|DDR..                       (clearing) auto-play box-pusher moves, one string per room
##   --autoplay                               crude bot: platformer runs right & jumps gaps; pond swims right;
##                                            mill and roof rooms solve themselves; the chase bot jumps
##                                            and dodges (for screenshots)

signal locale_changed
## Keyboard or controller: the last one the player touched. Prompts show that one's keys.
signal input_device_changed

const SAVE_PATH := "user://save.cfg"
## Exists while the game runs; a clean quit() removes it. Still there at start = the last run
## ended without quit() (a crash), and the title screen says so next to "Continue".
const SESSION_PATH := "user://session.cfg"
const TITLE := "res://scenes/title.tscn"
## Where each chapter starts (Continue goes here once the chapter before it is finished).
const CHAPTER_STARTS := ["", "res://chapters/ch1/forest.tscn", "res://chapters/ch2/pond.tscn",
	"res://chapters/ch3/city.tscn", "res://chapters/ch4/dream.tscn", "res://chapters/ch5/climb.tscn"]
const LOCALES := ["en", "sv"]

var locale := "en"
var using_pad := false
## What each {token} in a UI string shows, on keyboard and on a controller (Xbox-style letters).
const KEYS := {
	"jump": {"kb": {"en": "Space", "sv": "Mellanslag"}, "pad": "Ⓐ"},
	"advance": {"kb": {"en": "Space", "sv": "Mellanslag"}, "pad": "Ⓐ"},
	"use": {"kb": "E", "pad": "Ⓑ"},
	"skip": {"kb": "Tab", "pad": "RB"},
	"undo": {"kb": "Z", "pad": "Ⓧ"},
	"restart": {"kb": "R", "pad": "Ⓨ"},
	"arrows": {"kb": {"en": "Arrows", "sv": "Piltangenterna"}, "pad": {"en": "Stick", "sv": "Spaken"}},
}
## True while blocking narration plays or a cutscene runs; player scripts must ignore input then.
var control_locked := false
var unlocked_chapter := 1
var fast := false
var autoplay := false
var debug_moves := ""
var warp := -1
var _next_warp := -1  # the warp for the next go() (start_at), then back to none

const UI := {
	"begin": {"en": "Begin", "sv": "Börja"},
	"continue": {"en": "Chapters", "sv": "Kapitel"},
	"language": {"en": "Language: English", "sv": "Språk: Svenska"},
	"quit": {"en": "Quit", "sv": "Avsluta"},
	"resume": {"en": "Resume", "sv": "Fortsätt"},
	"to_title": {"en": "Back to title", "sv": "Till startskärmen"},
	"continue_game": {"en": "Continue", "sv": "Fortsätt"},
	"crashed": {"en": "The game closed unexpectedly last time. Continue takes you back to where you were.", "sv": "Spelet stängdes oväntat förra gången. Fortsätt tar dig tillbaka dit du var."},
	"paused": {"en": "Paused", "sv": "Paus"},
	"hint_move": {"en": "← → to move", "sv": "← → för att gå"},
	"hint_jump": {"en": "{jump} to jump", "sv": "{jump} för att hoppa"},
	"hint_advance": {"en": "{advance} for the next line", "sv": "{advance} för nästa rad"},
	"hint_push": {"en": "{arrows} to move · {undo} undo · {restart} start again", "sv": "{arrows} för att gå · {undo} ångra · {restart} börja om"},
	"chapter_1": {"en": "Chapter 1", "sv": "Kapitel 1"},
	"chapter_1_name": {"en": "The Other Side of the Forest", "sv": "Andra sidan skogen"},
	"locked": {"en": "(not yet)", "sv": "(inte än)"},
	"chapter_2_btn": {"en": "Chapter 2", "sv": "Kapitel 2"},
	"chapter_2": {"en": "Chapter 2", "sv": "Kapitel 2"},
	"chapter_2_name": {"en": "Learning to Swim", "sv": "Lära sig simma"},
	"hint_walk_in": {"en": "→ to walk in", "sv": "→ för att hoppa i"},
	"hint_hop": {"en": "← → to walk · {jump} to hop", "sv": "← → för att gå · {jump} för att hoppa"},
	"hint_swim": {"en": "{arrows} to swim", "sv": "{arrows} för att simma"},
	"hint_mill": {"en": "{arrows} to swim · {jump} at a wheel or lever · {restart} start again", "sv": "{arrows} för att simma · {jump} vid ett hjul eller en spak · {restart} börja om"},
	"hint_skip": {"en": "{skip} hurries the text along", "sv": "{skip} skyndar på texten"},
	"hint_duck_stuck": {"en": "The duck is stuck. From the top!", "sv": "Ankan har fastnat. Från början!"},
	"hint_backwards": {"en": "A wheel now goes: off → on → backwards", "sv": "Ett hjul går nu: av → på → baklänges"},
	"chapter_3_btn": {"en": "Chapter 3", "sv": "Kapitel 3"},
	"chapter_3": {"en": "Chapter 3", "sv": "Kapitel 3"},
	"chapter_3_name": {"en": "Lights", "sv": "Ljus"},
	"hint_dash": {"en": "{jump} to jump the canal", "sv": "{jump} för att hoppa över kanalen"},
	"hint_roofs": {"en": "{use} at a crank turns its lamp · {restart} start again", "sv": "{use} vid en vev vrider lampan · {restart} börja om"},
	"hint_chase": {"en": "← → change lanes · {jump} jump on the beat", "sv": "← → byt fil · {jump} hoppa i takt"},
	"chapter_4_btn": {"en": "Chapter 4", "sv": "Kapitel 4"},
	"chapter_5_btn": {"en": "Chapter 5", "sv": "Kapitel 5"},
	"chapter_5": {"en": "Chapter 5", "sv": "Kapitel 5"},
	"chapter_5_name": {"en": "The Climb", "sv": "Klättringen"},
	"the_end": {"en": "The end.", "sv": "Slut."},
	"hint_swing": {"en": "Hold {use} near a glowing hold to stretch and swing. Let go to fly.", "sv": "Håll {use} nära något som lyser för att sträcka dig dit och svinga. Släpp för att flyga."},
	"chapter_4": {"en": "Chapter 4", "sv": "Kapitel 4"},
	"chapter_4_name": {"en": "The Other Half", "sv": "Den andra halvan"},
}

const SFX_NAMES := ["jump", "blip_old", "blip_young", "pop", "push", "splash", "plate", "gate",
	"rewind", "whoosh", "beep", "shrink", "rumble", "bonk", "land", "grow", "chime",
	"whistle", "drip", "bubble", "turn", "flow", "gurgle",
	"kick", "hat", "crank", "lamp_on", "coo", "flap", "monitor"]

var _sfx := {}
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _music: AudioStreamPlayer
var _music_path := ""
var _pause_layer: CanvasLayer
var _shot_dir := ""
var _shot_timer := 0.0
var _shot_n := 0
var _transitioning := false
## The save point: the scene being played and where in it (the same numbers as --warp: a checkpoint
## column, a room, a beat or a section; -1 = its start). Empty scene = nothing to continue.
var progress_scene := ""
var progress_at := -1
## The last run ended without quit() (set at start, from SESSION_PATH).
var crashed_last_time := false
## A test run (--scene, --warp, --autoplay, --shots, --moves, --quit-after-secs, a --script test,
## a gda session, or the F1 test menu): it never touches the player's save point or the crash marker.
var testing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false  # closing the window goes through quit()
	_setup_input()
	_load()
	_parse_args()
	_start_session()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 55  # below Narrator (60) so lines can play over black
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	for n in SFX_NAMES:
		for ext in ["wav", "ogg"]:
			var p := "res://assets/audio/%s.%s" % [n, ext]
			if ResourceLoader.exists(p):
				_sfx[n] = load(p)
				break
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.finished.connect(func(): _music.play())
	add_child(_music)


func _parse_args() -> void:
	if "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args() or ProjectSettings.has_setting("autoload/GdaHarness"):
		testing = true  # a headless test script, or a gda session
	for a in OS.get_cmdline_user_args():
		for t_flag in ["--scene=", "--warp=", "--autoplay", "--shots=", "--moves=", "--quit-after-secs="]:
			if a.begins_with(t_flag):
				testing = true
		if a == "--fast":
			fast = true
		elif a == "--autoplay":
			autoplay = true
		elif a.begins_with("--moves="):
			debug_moves = a.get_slice("=", 1)
		elif a.begins_with("--warp="):
			warp = int(a.get_slice("=", 1))
		elif a.begins_with("--lang="):
			locale = a.get_slice("=", 1)
		elif a.begins_with("--scene="):
			var path := a.get_slice("=", 1)
			_goto_on_start.call_deferred(path)
		elif a.begins_with("--shots="):
			_shot_dir = a.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(_shot_dir)
		elif a.begins_with("--quit-after-secs="):
			var secs := float(a.get_slice("=", 1))
			get_tree().create_timer(secs, true, false, true).timeout.connect(quit)


func _goto_on_start(path: String) -> void:
	get_tree().change_scene_to_file(path)


## Notes whether the last run crashed, then marks this one as running (until quit()).
func _start_session() -> void:
	crashed_last_time = FileAccess.file_exists(SESSION_PATH)
	if testing:
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(Time.get_datetime_string_from_system())


func _process(delta: float) -> void:
	if _shot_dir != "":
		_shot_timer += delta
		if _shot_timer >= 2.0:
			_shot_timer = 0.0
			_shot_n += 1
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/shot_%03d.png" % [_shot_dir, _shot_n])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _transitioning:
		var scene := get_tree().current_scene
		if scene and scene.has_meta("no_pause"):
			return
		toggle_pause()


# ---------------------------------------------------------------- text

func t(key: String) -> String:
	if not UI.has(key):
		return key
	var s: String = UI[key].get(locale, UI[key]["en"])
	if s.contains("{"):
		for k in KEYS:
			s = s.replace("{%s}" % k, key_label(k))
	return s


## The key or button for an action, for the device in use (and in the current language).
func key_label(action: String) -> String:
	var v: Variant = KEYS[action]["pad" if using_pad else "kb"]
	if v is Dictionary:
		return v.get(locale, v["en"])
	return v


func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif event is InputEventKey and event.pressed:
		pad = false
	if pad != using_pad:
		using_pad = pad
		input_device_changed.emit()




## Pick the current-locale string from a {"en": ..., "sv": ...} dictionary.
## Falls back to English when the translation is missing or empty.
func pick(d: Dictionary) -> String:
	var s: String = d.get(locale, "")
	return s if s != "" else d.get("en", "")


func cycle_locale() -> void:
	var i := LOCALES.find(locale)
	locale = LOCALES[(i + 1) % LOCALES.size()]
	TranslationServer.set_locale(locale)
	save()
	locale_changed.emit()


# ---------------------------------------------------------------- sound

func sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = _sfx.get(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Quits cleanly: frees the level (and the coroutines waiting in it) and lets go of the music
## a couple of frames before the engine shuts down, so nothing is reported leaked at exit.
func quit() -> void:
	if not testing:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))  # a clean exit
	Narrator.clear()
	for p: Node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(p as AudioStreamPlayer).stop()
	var scene := get_tree().current_scene
	if scene:
		scene.queue_free()
	# the audio thread drops stopped playbacks on its next mix; give it a moment
	await get_tree().create_timer(0.3, true, false, true).timeout
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


func music(path: String, volume_db := -14.0, fade := 1.5) -> void:
	if path == _music_path:
		return
	_music_path = path
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -60.0, fade * 0.5)
	tw.tween_callback(func():
		if path == "" or not ResourceLoader.exists(path):
			_music.stop()
			return
		_music.stream = load(path)
		_music.volume_db = -60.0
		_music.play())
	tw.tween_property(_music, "volume_db", volume_db, fade)


# ---------------------------------------------------------------- transitions

func fade_out(color := Color.BLACK, dur := 0.6) -> void:
	_fade.color = Color(color.r, color.g, color.b, _fade.color.a)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, dur)
	await tw.finished


func fade_in(dur := 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, dur)
	await tw.finished


## Fade, swap scene, fade back. Clears the narrator and unlocks controls.
## Starts a scene at a given spot (the same numbers as --warp: a column, a room, a beat or a
## section, depending on the scene). Used by the test menu on the title screen.
func start_at(path: String, at: int) -> void:
	_next_warp = at
	go(path)


func go(path: String, color := Color.BLACK, dur := 0.7) -> void:
	if _transitioning:
		return
	_transitioning = true
	await fade_out(color, dur)
	Narrator.clear()
	control_locked = false
	get_tree().paused = false
	warp = _next_warp  # a warp only ever applies to the scene it was asked for
	if path != TITLE:
		_set_progress(path, warp)  # a new scene (or a chapter begun again) is the new save point
	_next_warp = -1
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_transitioning = false
	await fade_in(dur)


# ---------------------------------------------------------------- pause menu

func toggle_pause() -> void:
	if _pause_layer:
		_pause_layer.queue_free()
		_pause_layer = null
		get_tree().paused = false
		return
	get_tree().paused = true
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 90
	add_child(_pause_layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(600, 0)
	center.add_child(box)
	var title := Label.new()
	title.text = t("paused")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Fonts.hand())
	title.add_theme_font_size_override("font_size", 72)
	box.add_child(title)
	var resume := Fonts.menu_button(t("resume"))
	resume.pressed.connect(toggle_pause)
	box.add_child(resume)
	var lang := Fonts.menu_button(t("language"))
	lang.pressed.connect(func():
		cycle_locale()
		lang.text = t("language")
		resume.text = t("resume")
		title.text = t("paused"))
	box.add_child(lang)
	var back := Fonts.menu_button(t("to_title"))
	back.pressed.connect(func():
		toggle_pause()
		go("res://scenes/title.tscn"))
	box.add_child(back)
	resume.grab_focus.call_deferred()


# ---------------------------------------------------------------- save

## A chapter is finished: chapter n opens, and Continue now starts it (after the last one,
## n = 6, there is nothing left to continue).
func unlock_chapter(n: int) -> void:
	unlocked_chapter = maxi(unlocked_chapter, mini(n, CHAPTER_STARTS.size() - 1))
	progress_scene = CHAPTER_STARTS[n] if n < CHAPTER_STARTS.size() else ""
	progress_at = -1
	save()


## The player reached a save point in the current scene (a checkpoint column, a room, ...:
## the number its --warp takes). Saved at once, so a crash loses only what came after it.
func checkpoint(at: int) -> void:
	var path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if path != "" and path != TITLE and (path != progress_scene or at != progress_at):
		_set_progress(path, at)


## Continue: back to the save point.
func continue_game() -> void:
	if progress_scene != "" and ResourceLoader.exists(progress_scene):
		start_at(progress_scene, progress_at)


func _set_progress(path: String, at: int) -> void:
	progress_scene = path
	progress_at = at
	save()


## Writes the save file safely: to a temporary file first, then renamed over the old one, so a
## crash in the middle of saving never leaves a broken save. A test run only saves the language.
func save() -> void:
	var cf := ConfigFile.new()
	var old := ConfigFile.new()
	old.load(SAVE_PATH)
	cf.set_value("game", "locale", locale)
	cf.set_value("game", "unlocked_chapter", unlocked_chapter if not testing else old.get_value("game", "unlocked_chapter", 1))
	if testing:
		for k in ["scene", "at"]:
			if old.has_section_key("progress", k):
				cf.set_value("progress", k, old.get_value("progress", k))
	elif progress_scene != "":
		cf.set_value("progress", "scene", progress_scene)
		cf.set_value("progress", "at", progress_at)
	var tmp := SAVE_PATH + ".tmp"
	if cf.save(tmp) == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK and cf.load(SAVE_PATH + ".tmp") != OK:  # .tmp: a save cut off just before its rename
		TranslationServer.set_locale(locale)
		return
	locale = cf.get_value("game", "locale", "en")
	unlocked_chapter = cf.get_value("game", "unlocked_chapter", 1)
	progress_scene = cf.get_value("progress", "scene", "")
	progress_at = cf.get_value("progress", "at", -1)
	if progress_scene != "" and not ResourceLoader.exists(progress_scene):
		progress_scene = ""
	TranslationServer.set_locale(locale)


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	_action("left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action("down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("jump", [KEY_SPACE, KEY_UP, KEY_W], [JOY_BUTTON_A])
	_action("advance", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E], [JOY_BUTTON_A, JOY_BUTTON_B])
	_action("use", [KEY_E, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_B])
	_action("undo", [KEY_Z, KEY_BACKSPACE], [JOY_BUTTON_X])
	_action("restart", [KEY_R], [JOY_BUTTON_Y])
	_action("skip", [KEY_TAB], [JOY_BUTTON_RIGHT_SHOULDER])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])


func _action(action: String, keys: Array, buttons: Array, axis := -1, axis_dir := 0.0) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	if axis >= 0:
		var e := InputEventJoypadMotion.new()
		e.axis = axis as JoyAxis
		e.axis_value = axis_dir
		InputMap.action_add_event(action, e)
