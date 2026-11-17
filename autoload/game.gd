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

const SAVE_PATH := "user://save.cfg"
const LOCALES := ["en", "sv"]

var locale := "en"
## True while blocking narration plays or a cutscene runs; player scripts must ignore input then.
var control_locked := false
var unlocked_chapter := 1
var fast := false
var autoplay := false
var debug_moves := ""
var warp := -1

const UI := {
	"begin": {"en": "Begin", "sv": "Börja"},
	"continue": {"en": "Chapters", "sv": "Kapitel"},
	"language": {"en": "Language: English", "sv": "Språk: Svenska"},
	"quit": {"en": "Quit", "sv": "Avsluta"},
	"resume": {"en": "Resume", "sv": "Fortsätt"},
	"to_title": {"en": "Back to title", "sv": "Till startskärmen"},
	"paused": {"en": "Paused", "sv": "Paus"},
	"hint_move": {"en": "← → to move", "sv": "← → för att gå"},
	"hint_jump": {"en": "Space / Ⓐ to jump", "sv": "Mellanslag / Ⓐ för att hoppa"},
	"hint_advance": {"en": "Space / Enter / Ⓐ for the next line", "sv": "Mellanslag / Enter / Ⓐ för nästa rad"},
	"hint_push": {"en": "Arrows to move · Z undo · R restart", "sv": "Piltangenter för att gå · Z ångra · R börja om"},
	"chapter_1": {"en": "Chapter 1", "sv": "Kapitel 1"},
	"chapter_1_name": {"en": "The Other Side of the Forest", "sv": "Andra sidan skogen"},
	"chapter_end": {"en": "End of chapter one. More tomorrow.", "sv": "Slut på kapitel ett. Mer i morgon."},
	"locked": {"en": "(not yet)", "sv": "(inte än)"},
	"chapter_2_btn": {"en": "Chapter 2", "sv": "Kapitel 2"},
	"chapter_2": {"en": "Chapter 2", "sv": "Kapitel 2"},
	"chapter_2_name": {"en": "Learning to Swim", "sv": "Lära sig simma"},
	"chapter_end_2": {"en": "End of chapter two. More tomorrow.", "sv": "Slut på kapitel två. Mer i morgon."},
	"hint_walk_in": {"en": "→ to walk in", "sv": "→ för att gå i"},
	"hint_hop": {"en": "← → to walk · Space / Ⓐ to hop", "sv": "← → för att gå · Mellanslag / Ⓐ för att hoppa"},
	"hint_swim": {"en": "Arrows to swim", "sv": "Piltangenterna för att simma"},
	"hint_mill": {"en": "Arrows to swim · Space / Ⓐ at a wheel or lever · R starts the room again", "sv": "Piltangenterna för att simma · Mellanslag / Ⓐ vid ett hjul eller en spak · R börjar om rummet"},
	"hint_backwards": {"en": "A wheel now goes: off → on → backwards", "sv": "Ett hjul går nu: av → på → baklänges"},
	"chapter_3_btn": {"en": "Chapter 3", "sv": "Kapitel 3"},
	"chapter_3": {"en": "Chapter 3", "sv": "Kapitel 3"},
	"chapter_3_name": {"en": "Lights", "sv": "Ljus"},
	"chapter_end_3": {"en": "End of chapter three.", "sv": "Slut på kapitel tre."},
	"hint_dash": {"en": "Space / Ⓐ to jump the canal", "sv": "Mellanslag / Ⓐ för att hoppa över kanalen"},
	"hint_roofs": {"en": "E / Ⓑ at a crank turns its lamp · R starts the roof again", "sv": "E / Ⓑ vid en vev vrider dess lampa · R börjar om taket"},
	"hint_chase": {"en": "← → change lanes · Space / Ⓐ jump on the beat", "sv": "← → byt fil · Mellanslag / Ⓐ hoppa i takt"},
}

const SFX_NAMES := ["jump", "blip_old", "blip_young", "pop", "push", "splash", "plate", "gate",
	"rewind", "whoosh", "beep", "shrink", "rumble", "bonk", "land", "grow", "chime",
	"whistle", "drip", "bubble", "turn", "flow", "gurgle",
	"kick", "hat", "crank", "lamp_on", "coo", "flap"]

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load()
	_parse_args()
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
	for a in OS.get_cmdline_user_args():
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
			get_tree().create_timer(secs, true, false, true).timeout.connect(func(): get_tree().quit())


func _goto_on_start(path: String) -> void:
	get_tree().change_scene_to_file(path)


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
	if UI.has(key):
		return UI[key].get(locale, UI[key]["en"])
	return key


## While the narrators talk and the player still has control (ambient lines), Blobb moves at this
## fraction of his speed, so the player can't race far past what's being said. Player scripts
## multiply their move speed by move_scale().
const LISTENING_SPEED := 0.4


func move_scale() -> float:
	return LISTENING_SPEED if Narrator.busy and not control_locked else 1.0


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

func sfx(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = _sfx.get(name)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


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
func go(path: String, color := Color.BLACK, dur := 0.7) -> void:
	if _transitioning:
		return
	_transitioning = true
	await fade_out(color, dur)
	Narrator.clear()
	control_locked = false
	get_tree().paused = false
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
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(960 - 300, 380)
	box.custom_minimum_size = Vector2(600, 0)
	_pause_layer.add_child(box)
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

func unlock_chapter(n: int) -> void:
	unlocked_chapter = maxi(unlocked_chapter, n)
	save()


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "locale", locale)
	cf.set_value("game", "unlocked_chapter", unlocked_chapter)
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		locale = cf.get_value("game", "locale", "en")
		unlocked_chapter = cf.get_value("game", "unlocked_chapter", 1)
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
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])


func _action(name: String, keys: Array, buttons: Array, axis := -1, axis_dir := 0.0) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.4)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(name, e)
	if axis >= 0:
		var e := InputEventJoypadMotion.new()
		e.axis = axis
		e.axis_value = axis_dir
		InputMap.action_add_event(name, e)
