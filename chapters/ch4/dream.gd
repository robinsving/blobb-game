extends Node2D
## Chapter 4: The Other Half. A short dreamscape, side view. Only Y speaks; O never answers.
## Flow: out of white (title over white) -> Blobb just walks, past drifting bits of earlier
## chapters (moss, a crate, the rubber duck, a ch3 street lamp, which comes round twice: the
## path loops) -> Y tries a rule and nothing happens -> "...Dad?" / "Wake up." -> the mist
## thins onto the mountain -> a short, simple climb (O climbing back to consciousness): the
## monitor beep comes back, faint and uneven at the foot, slow and even at the top -> card.
## No pits, no hazards, no retells. The world drifts between looks and never settles, until
## the mountain, which is clear. Dialogue: chapters/ch4/story.txt. Art: assets/gen/ch4/
## (optional; everything has a drawn fallback).

const TILE := 64
const ROWS := 17
const WIDTH := 140
const GROUND_ROW := 13
const ART := "res://assets/gen/ch4/"

## [x0, x1, top_row] the mountain's first ledges, solid down to the ground. Each is 2 rows up.
const LEDGES := [[117, 119, 11], [120, 122, 9], [123, 125, 7], [126, 128, 5], [129, WIDTH - 1, 3]]
const MOUNTAIN_COL := 112                       # where the mist hides the mountain until @mountain
const TOP_COL := 132
const TRIGGERS := {12: "roofs", 30: "moss", 46: "morning", 62: "duck", 78: "lamp", 94: "again", 108: "ending"}
const MOSS_COL := 30
const CRATE_COL := 40
const DUCK_COL := 62
const LAMP_COLS := [78, 94]                     # the same lamp and stump twice: the path has looped
const LOOKS := ["plain", "paper", "mono", "crayon"]
const PASTELS := [Color(0.8, 0.75, 1.0), Color(1.0, 0.85, 0.75), Color(0.75, 0.95, 0.88), Color(0.95, 0.8, 0.92)]

var player: PlayerSide
var fx: StyleFX
var camera: Camera2D
var _world: Node2D
var _mist: Node2D
var _mountain: Node2D
var _props: Array[Node2D] = []
var _fired := {}
var _t := 0.0
var _look_i := 0
var _look_clock := 0.0
var _drifting := true
var _climbing := false
var _done := false
var _beep_clock := 1.5
var _foot_y := 0.0
var story := StoryScript.load_file("res://chapters/ch4/story.txt")


func _ready() -> void:
	Game.music("res://assets/audio/music_dream.ogg", -16.0, 3.0)
	_build_world()
	if Game.warp >= 0:
		_debug_warp(Game.warp)
	else:
		_intro()


func _debug_warp(col: int) -> void:
	fx.white(0.0, 0.0)
	for c in TRIGGERS:
		if c < col:
			_fired[TRIGGERS[c]] = true
	player.teleport(Vector2(col * TILE + 32, _ground_y(col)))
	if col >= MOUNTAIN_COL:
		fx_mountain()


# ================================================================ story

## Out of ch3's white: the chapter's name on white, then the white thins into the dream.
func _intro() -> void:
	Game.control_locked = true
	fx.white(1.0, 0.0)
	var layer := CanvasLayer.new()
	layer.layer = 101
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 430)
	box.size = Vector2(1920, 240)
	box.add_theme_constant_override("separation", 18)
	layer.add_child(box)
	for spec in [[Game.t("chapter_4"), 44, Fonts.serif()], [Game.t("chapter_4_name"), 96, Fonts.hand()]]:
		var l := Label.new()
		l.text = spec[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", spec[2])
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		l.modulate.a = 0.0
		box.add_child(l)
	var tw := create_tween()
	for l in box.get_children():
		tw.tween_property(l, "modulate:a", 1.0, 1.4)
	tw.tween_interval(0.5 if Game.fast else 3.5)
	tw.tween_property(box, "modulate:a", 0.0, 1.5)
	await tw.finished
	layer.queue_free()
	fx.white(0.0, 1.0 if Game.fast else 5.0)
	await get_tree().create_timer(0.5 if Game.fast else 3.0).timeout
	Game.control_locked = false
	Narrator.hint(Game.t("hint_move"), 6.0)
	story.play("intro", self)


func _beat(name: String) -> void:
	if name == "ending":
		_drifting = false
		fx.set_look("plain", 4.0)
	await story.play(name, self)


# ================================================================ story effects

## The mist thins onto the mountain; the climb begins, and the beep with it.
func fx_mountain() -> void:
	_drifting = false
	fx.set_look("real", 3.0)
	fx.tint(Color(1, 1, 1), 0.0, 3.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(_mist, "modulate:a", 0.0, 3.5)
	tw.tween_property(_mountain, "modulate:a", 1.0, 3.0)
	_foot_y = GROUND_ROW * TILE
	_climbing = true
	_beep_clock = 2.0


func _reach_top() -> void:
	if _done:
		return
	_done = true
	_climbing = false
	Game.control_locked = true
	Game.unlock_chapter(5)
	# a few seconds of the slow, even beep: that's the answer. Nobody speaks.
	await get_tree().create_timer(1.5 if Game.fast else 7.0).timeout
	await _chapter_card()
	Game.go("res://scenes/title.tscn", Color(0.93, 0.92, 0.97), 1.5)


func _chapter_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 101
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.93, 0.92, 0.97)
	bg.size = Vector2(1920, 1080)
	bg.modulate.a = 0.0
	layer.add_child(bg)
	await create_tween().tween_property(bg, "modulate:a", 1.0, 2.0).finished
	var box := VBoxContainer.new()
	box.position = Vector2(0, 400)
	box.size = Vector2(1920, 300)
	box.add_theme_constant_override("separation", 20)
	layer.add_child(box)
	for spec in [[Game.t("chapter_4"), 44, Fonts.serif()], [Game.t("chapter_4_name"), 84, Fonts.hand()], [Game.t("chapter_end_4"), 36, Fonts.serif()]]:
		var l := Label.new()
		l.text = spec[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", spec[2])
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		l.modulate.a = 0.0
		box.add_child(l)
		create_tween().tween_property(l, "modulate:a", 1.0, 1.4)
		await get_tree().create_timer(1.6 if not Game.fast else 0.2).timeout
	await get_tree().create_timer(4.0 if not Game.fast else 0.5).timeout


# ================================================================ per frame

func _process(delta: float) -> void:
	_t += delta
	# the dream can't settle on one look: it drifts from one to the next, slowly
	if _drifting:
		_look_clock -= delta
		if _look_clock <= 0.0:
			_look_clock = 16.0
			_look_i = (_look_i + 1) % LOOKS.size()
			fx.set_look(LOOKS[_look_i], 6.0)
			fx.tint(PASTELS[_look_i], 0.2, 6.0)
	# drifting things bob gently in place (small, slow; the camera never moves with them)
	for p in _props:
		p.position.y = p.get_meta("y") + sin(_t * 0.7 + p.get_meta("ph")) * 6.0
	if _climbing or _done:
		_beep(delta)
	if _climbing and player.position.x > TOP_COL * TILE and player.is_on_floor():
		_reach_top()


## The monitor beep on the climb: faint and uneven at the foot, slow and even at the top.
func _beep(delta: float) -> void:
	var p := 1.0 if _done else clampf((_foot_y - player.position.y) / ((GROUND_ROW - LEDGES[-1][2]) * TILE), 0.0, 1.0)
	_beep_clock -= delta
	if _beep_clock > 0.0:
		return
	var even := 1.1
	var uneven := randf_range(1.2, 3.2)
	_beep_clock = lerpf(uneven, even, p)
	Game.sfx("monitor", lerpf(-34.0, -13.0, p))  # the monitor beep (tools/gen_monitor.py)


# ================================================================ world building

func _build_world() -> void:
	var back := CanvasLayer.new()
	back.layer = -10
	add_child(back)
	var sky := _gradient_rect([Color(0.82, 0.8, 0.95), Color(0.97, 0.88, 0.86), Color(0.86, 0.95, 0.92)])
	back.add_child(sky)
	var par := Parallax2D.new()
	par.scroll_scale = Vector2(0.35, 1.0)
	add_child(par)
	if ResourceLoader.exists(ART + "dream_bg.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "dream_bg.png")
		s.centered = false
		var k := (GROUND_ROW * TILE + 380.0) / s.texture.get_height()
		s.scale = Vector2(k, k)
		s.position = Vector2(0, -260)
		s.modulate = Color(1, 1, 1, 0.9)
		par.add_child(s)
		par.repeat_size = Vector2(s.texture.get_width() * k, 0)
		par.repeat_times = 3
	else:
		var hills := Node2D.new()
		hills.draw.connect(_draw_hills.bind(hills))
		par.add_child(hills)
		par.repeat_size = Vector2(2600, 0)
		par.repeat_times = 3
	_mountain = Node2D.new()
	_mountain.draw.connect(_draw_mountain)
	_mountain.modulate.a = 0.0
	add_child(_mountain)
	if ResourceLoader.exists(ART + "mountain.png"):
		var peak := Sprite2D.new()
		peak.texture = load(ART + "mountain.png")
		peak.centered = false
		peak.show_behind_parent = true  # behind the ledges, which _mountain draws itself
		var k := 1500.0 / peak.texture.get_height()
		peak.scale = Vector2(k, k)
		peak.position = Vector2(LEDGES[0][0] * TILE - 80.0, GROUND_ROW * TILE - 1500.0 + 30.0)
		_mountain.add_child(peak)
	_world = Node2D.new()
	_world.draw.connect(_draw_ground)
	add_child(_world)
	_solid(0, WIDTH - 1, GROUND_ROW, ROWS - 1)
	for l in LEDGES:
		_solid(l[0], l[1], l[2], GROUND_ROW)
	_solid(-1, -1, -10, ROWS - 1)
	_solid(WIDTH, WIDTH, -10, ROWS - 1)
	_make_props()
	_mist = Node2D.new()
	_mist.draw.connect(_draw_mist)
	_mist.z_index = 5
	add_child(_mist)
	for col in TRIGGERS:
		_column_area(col).body_entered.connect(func(b):
			var beat: String = TRIGGERS[col]
			if b == player and not _fired.has(beat):
				_fired[beat] = true
				_beat(beat))
	player = PlayerSide.new()
	player.name = "Player"  # a stable path for gda: /root/<Level>/Player
	player.position = Vector2(4 * TILE + 32, GROUND_ROW * TILE)
	player.z_index = 2
	add_child(player)
	StoryGate.attach(self, player, TRIGGERS, _fired, TILE)  # Y is never outrun
	player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT, 0.0)
	player.jump_velocity = PlayerSide.STRONG_JUMP
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = WIDTH * TILE
	camera.limit_top = -130  # no higher: the painted background ends just above (about y = -140 on screen)
	camera.limit_bottom = ROWS * TILE
	camera.drag_horizontal_enabled = true
	camera.drag_left_margin = 0.1
	camera.drag_right_margin = 0.1
	camera.offset = Vector2(0, -120)
	player.add_child(camera)
	fx = StyleFX.new()
	fx.set_look("plain", 0.0)
	fx.tint(PASTELS[0], 0.2, 0.0)
	add_child(fx)
	_look_clock = 10.0


## Bits of earlier chapters, drifting a little above the path.
func _make_props() -> void:
	var gy := GROUND_ROW * TILE
	# moss: a soft glowing patch, with a few motes over it
	var moss := Node2D.new()
	moss.draw.connect(func():
		for i in 9:
			var a := i * 0.7
			moss.draw_circle(Vector2(cos(a) * 46.0 * (0.5 + 0.5 * sin(i * 1.7)), sin(a) * 10.0), 26.0, Color(0.45, 0.75, 0.4, 0.55))
		for i in 7:
			moss.draw_circle(Vector2(-60 + i * 20, -40 - (i % 3) * 22), 3.0, Color(0.8, 1.0, 0.7, 0.7)))
	_prop(moss, Vector2(MOSS_COL * TILE, gy - 40))
	# a crate from the clearing, floating, slightly tilted
	var crate := Node2D.new()
	crate.rotation = 0.15
	crate.draw.connect(func():
		crate.draw_rect(Rect2(-48, -48, 96, 96), Color(0.72, 0.56, 0.38))
		crate.draw_rect(Rect2(-48, -48, 96, 96), Color(0.45, 0.33, 0.22), false, 6.0)
		crate.draw_line(Vector2(-44, -44), Vector2(44, 44), Color(0.45, 0.33, 0.22), 6.0)
		crate.draw_line(Vector2(-44, 0), Vector2(44, 0), Color(0.55, 0.42, 0.28), 4.0))
	crate.modulate = Color(1, 1, 1, 0.85)
	_prop(crate, Vector2(CRATE_COL * TILE, gy - 220))
	# the rubber duck, in mid-air, still cross
	var duck := Node2D.new()
	if ResourceLoader.exists("res://assets/gen/ch2/rubber_duck.png"):
		var s := Sprite2D.new()
		s.texture = load("res://assets/gen/ch2/rubber_duck.png")
		s.scale = Vector2.ONE * (120.0 / s.texture.get_height())
		s.flip_h = true
		duck.add_child(s)
	else:
		duck.draw.connect(func():
			duck.draw_circle(Vector2.ZERO, 40.0, Color(1.0, 0.85, 0.2))
			duck.draw_circle(Vector2(-28, -34), 24.0, Color(1.0, 0.85, 0.2))
			duck.draw_circle(Vector2(-50, -32), 10.0, Color(1.0, 0.55, 0.15)))
	_prop(duck, Vector2(DUCK_COL * TILE, gy - 190))
	# the same street lamp and stump, twice
	for col in LAMP_COLS:
		_make_lamp(col)


func _make_lamp(col: int) -> void:
	var gy := GROUND_ROW * TILE
	var n := Node2D.new()
	n.position = Vector2(col * TILE + 32, gy)
	add_child(n)
	var glow := Node2D.new()
	glow.draw.connect(func():
		for i in 6:
			glow.draw_circle(Vector2(0, -300), 160.0 - i * 24.0, Color(1.0, 0.85, 0.5, 0.05)))
	n.add_child(glow)
	if ResourceLoader.exists("res://assets/gen/ch3/street_lamp.png"):
		var s := Sprite2D.new()
		s.texture = load("res://assets/gen/ch3/street_lamp.png")
		s.centered = false
		var k := 360.0 / s.texture.get_height()
		s.scale = Vector2(k, k)
		s.position = Vector2(-s.texture.get_width() * k * 0.5, -360)
		n.add_child(s)
	else:
		n.draw.connect(func():
			n.draw_rect(Rect2(-6, -320, 12, 320), Color(0.2, 0.22, 0.3))
			n.draw_circle(Vector2(0, -320), 26.0, Color(1.0, 0.9, 0.6)))
	var stump := Node2D.new()
	stump.position = Vector2(150, 0)
	if ResourceLoader.exists("res://assets/gen/ch2/warden_stump.png"):
		var s := Sprite2D.new()
		s.texture = load("res://assets/gen/ch2/warden_stump.png")
		s.centered = false
		var k := 150.0 / 158.0  # the stump fills rows 121..279 of the 400 px image
		s.scale = Vector2(k, k)
		s.position = Vector2(-s.texture.get_width() * k * 0.5, -279.0 * k + 6.0)
		stump.add_child(s)
	else:
		stump.draw.connect(func():
			stump.draw_rect(Rect2(-50, -80, 100, 80), Color(0.5, 0.38, 0.28))
			stump.draw_circle(Vector2(0, -80), 50.0, Color(0.7, 0.58, 0.42)))
	n.add_child(stump)


func _prop(n: Node2D, at: Vector2) -> void:
	n.position = at
	n.set_meta("y", at.y)
	n.set_meta("ph", randf() * TAU)
	n.z_index = 1
	add_child(n)
	_props.append(n)


func _gradient_rect(cols: Array) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray(cols)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = Vector2(1920, 1080)
	return r


## Fallback background: soft rolling hills fading into mist, and a few vague floating shapes.
func _draw_hills(n: Node2D) -> void:
	var base := GROUND_ROW * TILE
	for layer in 3:
		var pts := PackedVector2Array()
		var amp := 90.0 - layer * 20.0
		var y0 := base - 260.0 + layer * 90.0
		for i in 53:
			var x := i * 50.0
			pts.append(Vector2(x, y0 - amp * (0.5 + 0.5 * sin(x * TAU / 2600.0 * (2 + layer) + layer))))
		pts.append(Vector2(2600, base + 200))
		pts.append(Vector2(0, base + 200))
		var c: Color = [Color(0.78, 0.76, 0.92), Color(0.8, 0.88, 0.86), Color(0.9, 0.84, 0.86)][layer]
		n.draw_colored_polygon(pts, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	for i in 7:
		var p := Vector2(rng.randf() * 2600, rng.randf_range(80, 420))
		var r := rng.randf_range(30, 90)
		n.draw_circle(p, r, Color(1, 1, 1, 0.22))
		n.draw_circle(p + Vector2(r * 0.6, 4), r * 0.7, Color(1, 1, 1, 0.18))


## The path: a soft pale ground, flat all the way (he only walks).
func _draw_ground() -> void:
	var top := Color(0.86, 0.9, 0.84)
	var body := Color(0.74, 0.76, 0.86)
	_world.draw_rect(Rect2(0, GROUND_ROW * TILE, WIDTH * TILE, (ROWS - GROUND_ROW) * TILE), body)
	_world.draw_rect(Rect2(0, GROUND_ROW * TILE, WIDTH * TILE, 14), top)


## The mountain: a big pale peak behind, and the first ledges, which Blobb climbs.
func _draw_mountain() -> void:
	var x0 := LEDGES[0][0] * TILE - 200.0
	var gy := GROUND_ROW * TILE
	if ResourceLoader.exists(ART + "mountain.png"):
		# the painting has the ledges in it, lined up with LEDGES (see build/mountain_guide.png in
		# git history: tops at image rows 1610/1457/1303/1150/996). Only the top ledge runs on past
		# the painting's right edge, so draw that bit.
		var edge := LEDGES[0][0] * TILE - 80.0 + 1400.0 * 1500.0 / 1800.0
		var l: Array = LEDGES[-1]
		_ledge(Rect2(edge - 2.0, l[2] * TILE, (l[1] + 1) * TILE - edge + 2.0, (GROUND_ROW - l[2]) * TILE))
		return
	else:
		_mountain.draw_colored_polygon(PackedVector2Array([Vector2(x0, gy), Vector2(x0 + 700, gy - 1250), Vector2(x0 + 900, gy - 1150),
			Vector2(x0 + 1500, gy)]), Color(0.66, 0.68, 0.8))
		_mountain.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 640, gy - 1140), Vector2(x0 + 700, gy - 1250),
			Vector2(x0 + 780, gy - 1180), Vector2(x0 + 720, gy - 1150)]), Color(0.96, 0.96, 1.0))
	for l in LEDGES:
		_ledge(Rect2(l[0] * TILE, l[2] * TILE, (l[1] - l[0] + 1) * TILE, (GROUND_ROW - l[2]) * TILE))


## One drawn ledge, in the painted mountain's colours: lavender rock, a warm lit top, a cool side.
func _ledge(r: Rect2) -> void:
	_mountain.draw_rect(r, Color(0.79, 0.67, 0.76))
	for i in range(1, int(r.size.y / 34.0)):
		_mountain.draw_rect(Rect2(r.position + Vector2(0, 18 + i * 34.0), Vector2(r.size.x, 3)), Color(0.72, 0.6, 0.72, 0.6))
	_mountain.draw_rect(Rect2(r.position, Vector2(r.size.x, 22)), Color(0.98, 0.9, 0.82))
	_mountain.draw_rect(Rect2(r.position + Vector2(0, 22), Vector2(r.size.x, 4)), Color(0.93, 0.74, 0.7))
	_mountain.draw_rect(Rect2(r.position + Vector2(r.size.x - 14, 26), Vector2(14, r.size.y - 26)), Color(0.66, 0.55, 0.68))


## Mist: a low band along the path, and a thick wall hiding the mountain until @mountain.
func _draw_mist() -> void:
	var gy := GROUND_ROW * TILE
	# a smooth ramp from clear to opaque over ~8 tiles (many thin steps, so no visible bands)
	var x0 := (MOUNTAIN_COL - 4) * TILE
	for i in 64:
		var x := x0 + i * 8.0
		_mist.draw_rect(Rect2(x, -400, 8.0, gy + 400), Color(0.95, 0.94, 0.98, smoothstep(0.0, 1.0, i / 63.0) * 0.97))
	_mist.draw_rect(Rect2(x0 + 512.0, -400, WIDTH * TILE - x0, gy + 400), Color(0.95, 0.94, 0.98, 0.97))


func _solid(x0: int, x1: int, top: int, bottom: int) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2((x1 - x0 + 1) * TILE, (bottom - top + 1) * TILE)
	cs.shape = shape
	cs.position = Vector2((x0 + x1 + 1) * 0.5 * TILE, (top + bottom + 1) * 0.5 * TILE)
	body.add_child(cs)
	add_child(body)


func _column_area(col: int) -> Area2D:
	var a := Area2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(TILE, ROWS * TILE * 2)
	cs.shape = r
	cs.position = Vector2(col * TILE + 32, 0)
	a.add_child(cs)
	add_child(a)
	return a


func _ground_y(col: int) -> float:
	for l in LEDGES:
		if col >= l[0] and col <= l[1]:
			return l[2] * TILE
	return GROUND_ROW * TILE

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state"]


func debug_state() -> Dictionary:
	return DebugState.side(player, TILE, _fired, {"done": _done})
