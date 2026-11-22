extends CanvasLayer
## The test menu: press F1 on the title screen. Every scene, and spots inside them, one click
## away (the same numbers as --warp). For trying things out quickly, not part of the story.

const ENTRIES := [
	["Kapitel 1", [
		["Skogen", "res://chapters/ch1/forest.tscn", -1],
		["Skogen: hoppet", "res://chapters/ch1/forest.tscn", 17],
		["Skogen: bananen", "res://chapters/ch1/forest.tscn", 62],
		["Skogen: kvällen", "res://chapters/ch1/forest.tscn", 98],
		["Gläntan: rum 1", "res://chapters/ch1/clearing.tscn", 1],
		["Gläntan: rum 2", "res://chapters/ch1/clearing.tscn", 2],
	]],
	["Kapitel 2", [
		["Dammen", "res://chapters/ch2/pond.tscn", -1],
		["Dammen: fiskarna", "res://chapters/ch2/pond.tscn", 43],
		["Dammen: virveln", "res://chapters/ch2/pond.tscn", 64],
		["Dammen: virvlarna", "res://chapters/ch2/pond.tscn", 76],
		["Kvarnen: rum 1", "res://chapters/ch2/mill.tscn", 1],
		["Kvarnen: rum 2", "res://chapters/ch2/mill.tscn", 2],
		["Kvarnen: rum 3", "res://chapters/ch2/mill.tscn", 3],
	]],
	["Kapitel 3", [
		["Stan", "res://chapters/ch3/city.tscn", -1],
		["Stan: kanalen", "res://chapters/ch3/city.tscn", 39],
		["Stan: stupröret", "res://chapters/ch3/city.tscn", 84],
		["Taken: rum 1", "res://chapters/ch3/roofs.tscn", 1],
		["Taken: rum 2", "res://chapters/ch3/roofs.tscn", 2],
		["Taken: rum 3", "res://chapters/ch3/roofs.tscn", 3],
		["Jakten", "res://chapters/ch3/chase.tscn", -1],
		["Jakten: mitten", "res://chapters/ch3/chase.tscn", 60],
		["Jakten: slutet", "res://chapters/ch3/chase.tscn", 104],
	]],
	["Kapitel 4", [
		["Drömmen", "res://chapters/ch4/dream.tscn", -1],
		["Drömmen: ankan", "res://chapters/ch4/dream.tscn", 60],
		["Drömmen: slutet", "res://chapters/ch4/dream.tscn", 106],
		["Drömmen: berget", "res://chapters/ch4/dream.tscn", 114],
	]],
	["Kapitel 5", [
		["Klättringen", "res://chapters/ch5/climb.tscn", -1],
		["Klättringen: O:s regel", "res://chapters/ch5/climb.tscn", 1],
		["Klättringen: stjärnorna", "res://chapters/ch5/climb.tscn", 2],
		["Klättringen: nära toppen", "res://chapters/ch5/climb.tscn", 3],
		["Klättringen: toppen", "res://chapters/ch5/climb.tscn", 4],
		["Testbanan (studs, sving)", "res://chapters/ch5/climb_test.tscn", -1],
	]],
]

var _first: Button


func _ready() -> void:
	layer = 95
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.93)
	bg.size = Vector2(1920, 1080)
	add_child(bg)
	var title := Label.new()
	title.text = "Testmeny   (F1 eller Esc stänger)"
	title.position = Vector2(60, 36)
	title.add_theme_font_override("font", Fonts.hand())
	title.add_theme_font_size_override("font_size", 44)
	add_child(title)
	var fast := CheckButton.new()
	fast.text = "Snabb text"
	fast.button_pressed = Game.fast
	fast.position = Vector2(1500, 44)
	fast.add_theme_font_size_override("font_size", 28)
	fast.toggled.connect(func(on): Game.fast = on)
	add_child(fast)
	var cols := HBoxContainer.new()
	cols.position = Vector2(60, 130)
	cols.add_theme_constant_override("separation", 30)
	add_child(cols)
	for ch in ENTRIES:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(340, 0)
		col.add_theme_constant_override("separation", 6)
		cols.add_child(col)
		var head := Label.new()
		head.text = ch[0]
		head.add_theme_font_override("font", Fonts.hand())
		head.add_theme_font_size_override("font_size", 36)
		head.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		col.add_child(head)
		for e in ch[1]:
			var b := Button.new()
			b.text = e[0]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 26)
			b.pressed.connect(_start.bind(e[1], e[2]))
			col.add_child(b)
			if _first == null:
				_first = b
	_first.grab_focus.call_deferred()


func _start(path: String, at: int) -> void:
	queue_free()
	Game.start_at(path, at)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_F1 or event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		queue_free()
