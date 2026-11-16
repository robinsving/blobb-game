extends Control
## Title screen: Blobb idling on paper, a crayon-styled title, and a small keyboard/gamepad menu.

const CH1 := "res://chapters/ch1/forest.tscn"

var _begin: Button
var _lang: Button
var _quit: Button
var _blobb: BlobbSprite
var _t := 0.0


func _ready() -> void:
	set_meta("no_pause", true)
	Game.music("res://assets/audio/music_forest.ogg", -20.0)
	var bg := ColorRect.new()
	bg.color = Color(0.95, 0.92, 0.85)
	bg.size = Vector2(1920, 1080)
	add_child(bg)

	var holder := Node2D.new()
	add_child(holder)
	_blobb = BlobbSprite.new()
	_blobb.position = Vector2(1300, 600)
	_blobb.scale = Vector2.ONE * 1.25
	holder.add_child(_blobb)

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
	box.position = Vector2(190, 520)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_begin = _button(box, "begin", func(): Game.go(CH1))
	_lang = _button(box, "language", func():
		Game.cycle_locale()
		_refresh())
	_quit = _button(box, "quit", func(): get_tree().quit())
	for b in [_begin, _lang, _quit]:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Color(0.3, 0.24, 0.18))
		b.add_theme_color_override("font_focus_color", Color(0.75, 0.3, 0.1))
		b.add_theme_color_override("font_hover_color", Color(0.75, 0.3, 0.1))
	_begin.grab_focus.call_deferred()

	var fx := StyleFX.new()
	fx.set_look("crayon", 0.0)
	add_child(fx)


func _button(parent: Node, key: String, cb: Callable) -> Button:
	var b := Fonts.menu_button(Game.t(key), 64)
	b.set_meta("key", key)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh() -> void:
	for b in [_begin, _lang, _quit]:
		b.text = Game.t(b.get_meta("key"))


func _process(delta: float) -> void:
	_t += delta
	_blobb.position.y = 600 + sin(_t * 1.6) * 12.0
	_blobb.rotation = sin(_t * 0.8) * 0.04
