extends Node2D
## Chapter 2, part 1: the millpond, side view, mostly under water.
## The world is built in code from the data tables below; story beats fire from trigger columns.
## Dialogue: chapters/ch2/story.txt (scene names = TRIGGERS values, splash, fail_1..4).
## Flow: bank (murky pond) -> "make it clear" -> jump in, sink, plod along the bottom ->
## "fuzz holds bubbles" (swim) -> big rock -> blue Blobb -> warden banana -> fish -> current ->
## whirlpool (retells) -> far end -> mill channel (chapters/ch2/mill.tscn).
## Art comes from assets/gen/ch2/ when present; everything has a drawn fallback.

const TILE := 64
const ROWS := 17
const WIDTH := 92
const SURFACE_Y := 3 * TILE
const NEXT_SCENE := "res://chapters/ch2/mill.tscn"
const ART := "res://assets/gen/ch2/"

## [x0, x1, top_row, bottom_row] solid banks, riverbed and rocks
const BLOCKS := [
	[0, 7, 3, 16],      # the bank Blobb starts on
	[8, 83, 15, 16],    # riverbed
	[17, 18, 13, 14],   # a stone to hop over while sinking
	[22, 22, 14, 14],   # a smaller one
	[31, 32, 6, 14],    # the big rock: only a swimmer gets over it
	[68, 76, 3, 9],     # a fallen log jam over the whirlpool
	[84, 91, 3, 16],    # far bank, under the mill
]
const CHECKPOINTS := [3, 12, 26, 36, 50, 60, 67]
const TRIGGERS := {27: "bubbles", 35: "cold", 40: "lifeguard", 45: "fish", 57: "current", 66: "whirlpool", 80: "deep_end"}
## [x0_col, x1_col, row, speed, texture]
const FISH := [[42, 52, 7, 140.0, "fish_a"], [44, 55, 11, 180.0, "fish_b"], [47, 54, 5, 110.0, "fish_c"]]
## current: Rect in tiles [x0, y0, x1, y1] and push (px/s). Strong up high, weak near the bottom.
const CURRENTS := [[56, 3, 66, 10, Vector2(-330, 0)], [56, 11, 66, 14, Vector2(-70, 0)]]
## springs whose bubbles lift a swimmer: [col, top_row, bottom_row]
const LIFTS := [[50, 4, 14]]
const SPRINGS := [27, 50]
const REEDS := [10, 14, 24, 29, 38, 53, 63, 78, 82]
const WHIRL_COL := 72
const BUBBLE_COL := 27
const STUMP_COL := 41

var player: PlayerSwim
var fx: StyleFX
var camera: Camera2D
var _bg_murky: Sprite2D
var _bg_clear: Sprite2D
var _banana: Sprite2D
var _whirl_pos := Vector2.ZERO
var _checkpoint := Vector2.ZERO
var _fired := {}
var _retelling := false
var _fail_count := 0
var _streaks: Array[Node2D] = []
var story := StoryScript.load_file("res://chapters/ch2/story.txt")


func _ready() -> void:
	Game.music("res://assets/audio/music_pool.ogg", -16.0)
	_build_world()
	_drip_loop()
	if Game.warp >= 0:
		_debug_warp(Game.warp)
	else:
		_intro()


func _debug_warp(col: int) -> void:
	_fired["splash"] = true
	fx_pond_clear()
	for c in TRIGGERS:
		if c < col:
			_fired[TRIGGERS[c]] = true
	if col > BUBBLE_COL:
		player.set_can_swim(true)
	if col > 35:
		player.sprite.set_tint(BlobbSprite.BLUE, BlobbSprite.BLUE_AMOUNT, 0.0)
	_checkpoint = _checkpoint_pos(col)
	player.teleport(_checkpoint)


# ================================================================ story
# All dialogue lives in chapters/ch2/story.txt. This code decides WHEN a scene plays
# (TRIGGERS columns, the first splash, the whirlpool) and implements the @effects as fx_* methods.

func _intro() -> void:
	await get_tree().create_timer(0.8).timeout
	await story.play("intro", self)
	Narrator.hint(Game.t("hint_walk_in"), 6.0)


func _on_entered_water() -> void:
	if _fired.has("splash"):
		return
	_fired["splash"] = true
	await story.play("splash", self)
	Narrator.hint(Game.t("hint_hop"), 6.0)


func _beat(name: String) -> void:
	await story.play(name, self)
	match name:
		"bubbles":
			Narrator.hint(Game.t("hint_swim"), 6.0)
		"deep_end":
			Game.control_locked = true
			Game.go(NEXT_SCENE, Color(0.05, 0.12, 0.1), 0.9)


func _fail() -> void:
	if _retelling:
		return
	_retelling = true
	Game.control_locked = true
	Game.sfx("rewind", -4.0)
	fx.rewind_pulse(1.2)
	var scene := "fail_%d" % (_fail_count % 4 + 1)
	_fail_count += 1
	player.visible = false
	player.teleport(_checkpoint)
	var scribble := Retell.scribble(self, _checkpoint + Vector2(0, -70))
	await story.play(scene, self)
	Retell.clear(scribble)
	player.visible = true
	player.sprite.flash(0.6)
	Game.sfx("pop", -6.0)
	_retelling = false


# ================================================================ story effects (@name in story.txt)

func fx_pond_clear() -> void:
	fx.set_look("real", 1.5)
	fx.tint(Color(0.95, 1.02, 1.05), 0.2, 1.5)
	var tw := create_tween().set_parallel()
	if _bg_clear:
		tw.tween_property(_bg_clear, "modulate:a", 1.0, 1.5)
	if _bg_murky:
		tw.tween_property(_bg_murky, "modulate:a", 0.0, 1.5)
	Game.sfx("chime", -6.0)


func fx_sink() -> void:
	Game.sfx("bubble", -6.0, 0.6)


func fx_swim_unlock() -> void:
	player.set_can_swim(true)
	player.sprite.flash()
	Game.sfx("chime", -6.0)
	for i in 8:
		player.call("_spawn_bubble")


func fx_blobb_blue() -> void:
	player.sprite.set_tint(BlobbSprite.BLUE, BlobbSprite.BLUE_AMOUNT, 1.5)
	Game.sfx("bubble", -8.0, 0.8)


func fx_whistle() -> void:
	Game.sfx("whistle", -8.0)
	if _banana:
		var y := _banana.position.y
		var tw := create_tween()
		tw.tween_property(_banana, "position:y", y - 18.0, 0.1).set_ease(Tween.EASE_OUT)
		tw.tween_property(_banana, "position:y", y, 0.15).set_ease(Tween.EASE_IN)


func fx_gurgle() -> void:
	Game.sfx("gurgle", -6.0)


# ================================================================ per-frame: currents, whirlpool, triggers

func _physics_process(_delta: float) -> void:
	if not player:
		return
	var p := player.global_position + Vector2(0, -54)
	var push := Vector2.ZERO
	if player.mode == PlayerSwim.Mode.SWIM:
		for c in CURRENTS:
			if Rect2(c[0] * TILE, c[1] * TILE, (c[2] - c[0] + 1) * TILE, (c[3] - c[1] + 1) * TILE).has_point(p):
				push += c[4]
		for l in LIFTS:
			if absf(p.x - (l[0] * TILE + 32)) < 70.0 and p.y > l[1] * TILE and p.y < (l[2] + 1) * TILE:
				push += Vector2(0, -300)
	var to_whirl := _whirl_pos - p
	var d := to_whirl.length()
	if d < 240.0:
		# pulls in and spins round
		push += to_whirl.normalized() * 230.0 * (1.0 - d / 240.0) + to_whirl.normalized().orthogonal() * 120.0 * (1.0 - d / 240.0)
		if d < 75.0 and not _retelling:
			_fail()
	player.flow = push
	_animate_streaks()


func _animate_streaks() -> void:
	for s in _streaks:
		s.position.x -= 6.0
		var r: Rect2 = s.get_meta("zone")
		if s.position.x < r.position.x:
			s.position.x = r.end.x
		s.modulate.a = 0.3 * clampf(minf(s.position.x - r.position.x, r.end.x - s.position.x) / 120.0, 0.0, 1.0)


func _drip_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.5, 5.0)).timeout
		Game.sfx("drip", -20.0, randf_range(0.95, 1.05))


# ================================================================ world building

func _build_world() -> void:
	var back := CanvasLayer.new()
	back.layer = -10
	var deep := ColorRect.new()
	deep.color = Color(0.13, 0.22, 0.17)
	deep.size = Vector2(1920, 1080)
	back.add_child(deep)
	add_child(back)

	var par := Parallax2D.new()
	par.scroll_scale = Vector2(0.3, 0.0)
	add_child(par)
	_bg_murky = _bg_sprite(par, "pond_murky_bg.png", 1.0)
	_bg_clear = _bg_sprite(par, "pond_clear_bg.png", 0.0)
	var any_bg := _bg_clear if _bg_clear else _bg_murky
	if any_bg:
		par.repeat_size = Vector2(any_bg.texture.get_width() * any_bg.scale.x, 0)
		par.repeat_times = 3
	else:
		# no art yet: a plain water gradient that the "clear" beat brightens
		_bg_murky = _gradient_bg(par, Color(0.28, 0.3, 0.18), Color(0.1, 0.12, 0.08), 1.0)
		_bg_clear = _gradient_bg(par, Color(0.35, 0.7, 0.75), Color(0.08, 0.3, 0.4), 0.0)

	# sky above the water line, and the surface seen from below
	var sky := ColorRect.new()
	sky.color = Color(0.82, 0.9, 0.95)
	sky.position = Vector2(0, -400)
	sky.size = Vector2(WIDTH * TILE, SURFACE_Y + 400)
	add_child(sky)
	if ResourceLoader.exists(ART + "water_surface.png"):
		var surf := Sprite2D.new()
		surf.texture = load(ART + "water_surface.png")
		surf.centered = false
		surf.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		surf.region_enabled = true
		surf.region_rect = Rect2(0, 0, WIDTH * TILE, 128)
		surf.position = Vector2(0, SURFACE_Y - 40)
		surf.z_index = 2
		add_child(surf)
	else:
		var line := ColorRect.new()
		line.color = Color(0.85, 0.95, 1.0, 0.6)
		line.position = Vector2(0, SURFACE_Y - 4)
		line.size = Vector2(WIDTH * TILE, 8)
		line.z_index = 2
		add_child(line)

	for col in REEDS:
		_reeds(col)
	for b in BLOCKS:
		_block(b[0], b[1], b[2], b[3])
	_wall(-1)
	_wall(WIDTH)

	for v in SPRINGS:
		_spring(v)
	for c in CURRENTS:
		_current_streaks(c)
	_build_whirlpool()
	_build_stump()
	for f in FISH:
		_fish(f)

	for col in TRIGGERS:
		_trigger(col, TRIGGERS[col])
	for col in CHECKPOINTS:
		_checkpoint_area(col)

	player = PlayerSwim.new()
	player.name = "Player"  # a stable path for gda: /root/<Level>/Player
	player.surface_y = SURFACE_Y
	_checkpoint = _checkpoint_pos(CHECKPOINTS[0])
	player.position = _checkpoint
	player.entered_water.connect(_on_entered_water)
	add_child(player)
	StoryGate.attach(self, player, TRIGGERS, _fired, TILE)  # waits for the story before the next beat

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = WIDTH * TILE
	camera.limit_top = 0
	camera.limit_bottom = ROWS * TILE
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	camera.drag_left_margin = 0.1
	camera.drag_right_margin = 0.1
	player.add_child(camera)

	fx = StyleFX.new()
	fx.set_look("real", 0.0)
	fx.tint(Color(0.85, 0.9, 0.75), 0.3, 0.0)  # murky to begin with
	add_child(fx)


func _bg_sprite(parent: Node, file: String, alpha: float) -> Sprite2D:
	if not ResourceLoader.exists(ART + file):
		return null
	var s := Sprite2D.new()
	s.texture = load(ART + file)
	s.centered = false
	var sc := 1080.0 / s.texture.get_height()
	s.scale = Vector2(sc, sc)
	s.modulate.a = alpha
	parent.add_child(s)
	return s


func _gradient_bg(parent: Node, top: Color, bottom: Color, alpha: float) -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 64
	gt.height = 64
	var s := Sprite2D.new()
	s.texture = gt
	s.centered = false
	s.scale = Vector2(1920.0 / 64.0, 1080.0 / 64.0)
	s.modulate.a = alpha
	parent.add_child(s)
	return s


## Riverbed, banks and rocks: the riverbed texture (one 512px image = 4x4 world tiles).
## Banks get a strip of grass on top where they stick out of the water.
func _block(x0: int, x1: int, top: int, bottom: int) -> void:
	var rect := Rect2(x0 * TILE, top * TILE, (x1 - x0 + 1) * TILE, (bottom - top + 1) * TILE)
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	body.add_child(cs)
	add_child(body)
	if ResourceLoader.exists(ART + "riverbed_tile.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "riverbed_tile.png")
		s.centered = false
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.scale = Vector2(0.5, 0.5)
		s.region_rect = Rect2(rect.position * 2.0, rect.size * 2.0)
		s.position = rect.position
		add_child(s)
	else:
		var r := ColorRect.new()
		r.color = Color(0.36, 0.3, 0.22)
		r.position = rect.position
		r.size = rect.size
		add_child(r)
	if top * TILE <= SURFACE_Y:
		var grass := ColorRect.new()
		grass.color = Color(0.35, 0.55, 0.22)
		grass.position = rect.position - Vector2(0, 10)
		grass.size = Vector2(rect.size.x, 18)
		add_child(grass)


func _wall(col: int) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(TILE, ROWS * TILE * 3)
	cs.shape = r
	cs.position = Vector2(col * TILE + TILE * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func _reeds(col: int) -> void:
	if not ResourceLoader.exists(ART + "reeds.png"):
		return
	var s := Sprite2D.new()
	s.texture = load(ART + "reeds.png")
	var k := randf_range(0.8, 1.15)
	s.scale = Vector2(k, k)
	s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	s.position = Vector2(col * TILE + 32, 15 * TILE + 6)
	s.flip_h = randf() < 0.5
	s.modulate = Color(0.85, 0.9, 0.85)
	add_child(s)
	var tw := s.create_tween().set_loops()
	var base := randf_range(-0.03, 0.03)
	tw.tween_property(s, "skew", base + 0.06, randf_range(1.8, 2.6)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "skew", base - 0.06, randf_range(1.8, 2.6)).set_trans(Tween.TRANS_SINE)


## A spring in the riverbed: bubbles rising.
func _spring(col: int) -> void:
	var p := CPUParticles2D.new()
	if ResourceLoader.exists(ART + "bubble.png"):
		p.texture = load(ART + "bubble.png")
		p.scale_amount_min = 0.12
		p.scale_amount_max = 0.3
	else:
		p.scale_amount_min = 4.0
		p.scale_amount_max = 9.0
	p.position = Vector2(col * TILE + 32, 15 * TILE)
	p.amount = 14
	p.lifetime = 3.2
	p.direction = Vector2.UP
	p.spread = 6.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 220.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(24, 4)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = grad
	p.z_index = 1
	add_child(p)


func _current_streaks(c: Array) -> void:
	if c[4].length() < 100.0:
		return
	var zone := Rect2(c[0] * TILE, c[1] * TILE, (c[2] - c[0] + 1) * TILE, (c[3] - c[1] + 1) * TILE)
	for i in 12:
		var s: Node2D
		if ResourceLoader.exists(ART + "stream_tile.png"):
			var sp := Sprite2D.new()
			sp.texture = load(ART + "stream_tile.png")
			sp.flip_h = true  # the art flows right; this current flows left
			sp.scale = Vector2(1.4, 0.5)
			s = sp
		else:
			var l := Line2D.new()
			l.width = 3.0
			l.default_color = Color(1, 1, 1, 0.7)
			l.points = PackedVector2Array([Vector2(-60, 0), Vector2(60, 0)])
			s = l
		s.position = Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y + 80, zone.end.y - 30))
		s.set_meta("zone", zone)
		s.z_index = 1
		add_child(s)
		_streaks.append(s)


func _build_whirlpool() -> void:
	_whirl_pos = Vector2(WHIRL_COL * TILE + 32, 15 * TILE - 70)
	var s: Node2D
	if ResourceLoader.exists(ART + "whirlpool.png"):
		var sp := Sprite2D.new()
		sp.texture = load(ART + "whirlpool.png")
		sp.scale = Vector2.ONE * (170.0 / sp.texture.get_width())
		s = sp
	else:
		var l := Line2D.new()
		l.width = 4.0
		l.default_color = Color(0.85, 0.95, 1.0, 0.7)
		var pts := PackedVector2Array()
		for i in 60:
			var a := i * 0.45
			pts.append(Vector2(cos(a), sin(a)) * (8.0 + i * 1.3))
		l.points = pts
		s = l
	s.position = _whirl_pos
	s.z_index = 1
	add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "rotation", -TAU, 1.6).from(0.0)


## The warden's mossy stump sticking out of the water, with the banana on top.
func _build_stump() -> void:
	var x := STUMP_COL * TILE + 32.0
	var top := SURFACE_Y - 70.0
	if ResourceLoader.exists(ART + "warden_stump.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "warden_stump.png")
		var k := 300.0 / s.texture.get_height()
		s.scale = Vector2(k, k)
		s.offset = Vector2(0, s.texture.get_height() * 0.5)
		s.position = Vector2(x, top - 10)
		add_child(s)
	else:
		var r := ColorRect.new()
		r.color = Color(0.4, 0.3, 0.2)
		r.position = Vector2(x - 45, top)
		r.size = Vector2(90, 300)
		add_child(r)
	for p in [ART + "banana_lifeguard.png", "res://assets/sprites/banana.png"]:
		if ResourceLoader.exists(p):
			_banana = Sprite2D.new()
			_banana.texture = load(p)
			var k := 130.0 / _banana.texture.get_height()
			_banana.scale = Vector2(k, k)
			_banana.offset = Vector2(0, -_banana.texture.get_height() * 0.5)
			_banana.position = Vector2(x, top + 2)
			add_child(_banana)
			break


func _fish(f: Array) -> void:
	var tex_path: String = ART + f[4] + ".png"
	if not ResourceLoader.exists(tex_path):
		return
	var fish := Node2D.new()
	fish.set_script(preload("res://scripts/fish.gd"))
	fish.set("texture", load(tex_path))
	fish.set("from_x", f[0] * TILE)
	fish.set("to_x", f[1] * TILE)
	fish.set("speed", f[3])
	fish.position = Vector2(f[0] * TILE, f[2] * TILE)
	add_child(fish)
	fish.connect("bumped", func(body):
		if body == player:
			player.knockback(fish.global_position.x))


func _trigger(col: int, beat: String) -> void:
	var a := _column_area(col)
	a.body_entered.connect(func(b):
		if b == player and not _fired.has(beat) and not _retelling:
			_fired[beat] = true
			_beat(beat))


func _checkpoint_area(col: int) -> void:
	var a := _column_area(col)
	var pos := _checkpoint_pos(col)
	a.body_entered.connect(func(b):
		if b == player and not _retelling:
			_checkpoint = pos)


func _checkpoint_pos(col: int) -> Vector2:
	var x := col * TILE + 32.0
	if col < 8:
		return Vector2(x, SURFACE_Y)
	if col >= BUBBLE_COL:  # he can swim by now: come back mid-depth, clear of the whirlpool's pull
		return Vector2(x, 11 * TILE)
	return Vector2(x, 15 * TILE - 4)


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

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state"]


func debug_state() -> Dictionary:
	return DebugState.side(player, TILE, _fired, {"checkpoint": _checkpoint})
