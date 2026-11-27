extends Control
## Title screen: Blobb idling on paper, a crayon-styled title, and a small keyboard/gamepad menu.

const CH1 := "res://chapters/ch1/forest.tscn"
const CH2 := "res://chapters/ch2/pond.tscn"
const CH3 := "res://chapters/ch3/city.tscn"
const CH4 := "res://chapters/ch4/dream.tscn"
const CH5 := "res://chapters/ch5/climb.tscn"

var _continue: Button
var _begin: Button
var _lang: Button
var _quit: Button
var _ch2: Button
var _ch3: Button
var _ch4: Button
var _ch5: Button
var _blobb: BlobbSprite
var _notice: Label  # "the game closed unexpectedly last time", after a crash
var _t := 0.0
var _blobb_y := 600.0


func _ready() -> void:
	set_meta("no_pause", true)
	Game.music("res://assets/audio/music_forest.ogg", -20.0)
	var bg := ColorRect.new()
	bg.color = Color(0.95, 0.92, 0.85)
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	const TITLE_BG := "res://assets/gen/title/title_bg.png"  # crayon paper with doodles, if generated
	if ResourceLoader.exists(TITLE_BG):
		var paper := TextureRect.new()
		paper.texture = load(TITLE_BG)
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		paper.size = Vector2(1920, 1080)
		add_child(paper)

	var holder := Node2D.new()
	add_child(holder)
	_blobb = BlobbSprite.new()
	_blobb.position = Vector2(1300, 600)
	if ResourceLoader.exists("res://assets/gen/title/title_bg.png"):
		_blobb_y = 545.0  # feet on the drawn ground line (y 700)
	_blobb.position.y = _blobb_y
	_blobb.scale = Vector2.ONE * 1.25
	holder.add_child(_blobb)

	const DRAWN_TITLE := "res://assets/sprites/drawn_title.png"  # the "BLOBB" from the original drawing
	if ResourceLoader.exists(DRAWN_TITLE):
		var t := TextureRect.new()
		t.texture = load(DRAWN_TITLE)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		t.size = Vector2(820, 820.0 * t.texture.get_height() / t.texture.get_width())
		t.position = Vector2(150, 150)
		add_child(t)
	else:
		var title := Label.new()
		title.text = "Blobb"
		title.add_theme_font_override("font", Fonts.hand())
		title.add_theme_font_size_override("font_size", 230)
		title.add_theme_color_override("font_color", Color(0.4, 0.55, 0.18))
		title.add_theme_color_override("font_shadow_color", Color(0.2, 0.15, 0.1, 0.35))
		title.add_theme_constant_override("shadow_offset_x", 6)
		title.add_theme_constant_override("shadow_offset_y", 8)
		title.position = Vector2(170, 140)
		add_child(title)

	var box := VBoxContainer.new()
	box.position = Vector2(190, 430)  # room for five chapters
	box.add_theme_constant_override("separation", -10)  # seven rows must fit under the title
	add_child(box)
	if Game.progress_scene != "":
		_continue = _button(box, "continue_game", Game.continue_game)
	_begin = _button(box, "begin", func(): Game.go(CH1))
	if Game.unlocked_chapter >= 2:
		_ch2 = _button(box, "chapter_2_btn", func(): Game.go(CH2))
	if Game.unlocked_chapter >= 3:
		_ch3 = _button(box, "chapter_3_btn", func(): Game.go(CH3))
	if Game.unlocked_chapter >= 4:
		_ch4 = _button(box, "chapter_4_btn", func(): Game.go(CH4, Color.WHITE, 1.0))
		# for now open to anyone who has reached ch4 (finishing ch4 also unlocks it)
		_ch5 = _button(box, "chapter_5_btn", func(): Game.go(CH5))
	_lang = _button(box, "language", func():
		Game.cycle_locale()
		_refresh())
	if not OS.has_feature("web"):  # a browser tab can't quit itself
		_quit = _button(box, "quit", func(): Game.quit())
	for b in _buttons():
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Color(0.3, 0.24, 0.18))
		b.add_theme_color_override("font_focus_color", Color(0.75, 0.3, 0.1))
		b.add_theme_color_override("font_hover_color", Color(0.75, 0.3, 0.1))
	(func():
		if _begin.is_inside_tree():  # --scene= replaces the title within its first frame
			(_continue if _continue else _begin).grab_focus()).call_deferred()
	if Game.crashed_last_time and _continue:
		_notice = Label.new()
		_notice.add_theme_font_override("font", Fonts.hand())
		_notice.add_theme_font_size_override("font_size", 30)
		_notice.add_theme_color_override("font_color", Color(0.55, 0.3, 0.15))
		_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notice.position = Vector2(470, 448)  # beside Continue
		_notice.size = Vector2(560, 80)
		_notice.text = Game.t("crashed")
		add_child(_notice)

	var fx := StyleFX.new()
	fx.set_look("crayon", 0.0)
	add_child(fx)


func _button(parent: Node, key: String, cb: Callable) -> Button:
	var b := Fonts.menu_button(Game.t(key), 56 if Game.progress_scene != "" else 64)  # one row more with Continue
	b.set_meta("key", key)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _buttons() -> Array:
	return [_continue, _begin, _ch2, _ch3, _ch4, _ch5, _lang, _quit].filter(func(b): return b != null)


func _refresh() -> void:
	for b in _buttons():
		b.text = Game.t(b.get_meta("key"))
	if _notice:
		_notice.text = Game.t("crashed")


## F1 opens the test menu (every scene, and spots inside them).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1 and not has_node("TestMenu"):
		var m: CanvasLayer = preload("res://scenes/test_menu.gd").new()
		m.name = "TestMenu"
		add_child(m)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_blobb.position.y = _blobb_y - 6.0 + sin(_t * 1.6) * 6.0  # a small bob that never sinks below his line
	_blobb.rotation = sin(_t * 0.8) * 0.04
