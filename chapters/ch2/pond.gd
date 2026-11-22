extends Node2D
## Chapter 2, part 1: the millpond, side view, mostly under water.
## The world is built in code from the data tables below; story beats fire from trigger columns.
## Dialogue: chapters/ch2/story.txt (scene names = TRIGGERS values, splash, fail_1..4).
## Flow: bank (murky pond) -> "make it clear" -> jump in, sink, plod along the bottom ->
## "fuzz holds bubbles" (swim) -> big rock -> blue Blobb -> warden banana -> fish -> current ->
## whirlpool (retells) -> a passage of smaller whirlpools to weave through -> far end -> mill channel (chapters/ch2/mill.tscn).
## Art comes from assets/gen/ch2/ when present; everything has a drawn fallback.

const TILE := 64
const ROWS := 17
const WIDTH := 114
const SURFACE_Y := 3 * TILE
const NEXT_SCENE := "res://chapters/ch2/mill.tscn"
const ART := "res://assets/gen/ch2/"

## [x0, x1, top_row, bottom_row] solid banks, riverbed and rocks
const BLOCKS := [
	[0, 7, 3, 16],      # the bank Blobb starts on
	[8, 105, 15, 16],   # riverbed
	[17, 18, 13, 14],   # a stone to hop over while sinking
	[22, 22, 14, 14],   # a smaller one
	[31, 32, 6, 14],    # the big rock: only a swimmer gets over it
	[68, 76, 3, 9],     # a fallen log jam over the whirlpool
	[106, 113, 3, 16],  # far bank, under the mill
]
const CHECKPOINTS := [3, 12, 26, 36, 50, 60, 67, 78, 90]
const TRIGGERS := {27: "bubbles", 35: "cold", 40: "lifeguard", 45: "fish", 57: "current", 66: "whirlpool", 77: "whirls", 103: "deep_end"}
## [x0_col, x1_col, row, speed, texture]
const FISH := [[42, 52, 7, 140.0, "fish_a"], [44, 55, 11, 180.0, "fish_b"], [47, 54, 5, 110.0, "fish_c"]]
## current: Rect in tiles [x0, y0, x1, y1] and push (px/s). Strong up high, weak near the bottom.
const CURRENTS := [[56, 3, 66, 10, Vector2(-330, 0)], [56, 11, 66, 14, Vector2(-70, 0)]]
## springs whose bubbles lift a swimmer: [col, top_row, bottom_row]
const LIFTS := [[50, 4, 14]]
const SPRINGS := [27, 50]
const REEDS := [10, 14, 24, 29, 38, 53, 63, 102, 104]
const WHIRL_COL := 72
## whirlpools: [col, centre y in px, size (1 = the big one under the log jam)]. After the big one,
## a short passage of smaller ones, high and low in turn: under one, over the next.
const WHIRLS := [[WHIRL_COL, 15 * TILE - 70, 1.0], [81, 6 * TILE, 0.8], [87, 12 * TILE, 0.8],
	[93, 6 * TILE, 0.8], [99, 12 * TILE, 0.8]]
const BUBBLE_COL := 27
const STUMP_COL := 41

var player: PlayerSwim
var fx: StyleFX
var camera: Camera2D
var _bg_murky: Sprite2D
var _bg_clear: Sprite2D
var _banana: Sprite2D
var _whirls: Array[Vector3] = []  # x, y, size
var _checkpoint := Vector2.ZERO
var _fired := {}
var _retelling := false
var _fail_count := 0
var _streaks: Array[Node2D] = []
var story := StoryScript.load_file("res://chapters/ch2/story.txt")


func _ready() -> void:
	Game.music("res://assets/audio/music_pool.ogg", -16.0)
	_build_world()
	LevelKit.drip_loop(self)
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
	Game.control_locked = true
	await ChapterCard.title(self, 2, Color(0.95, 0.9, 0.8), Color.BLACK)
	await story.play("intro", self)
	Narrator.hint(Game.t("hint_walk_in"), 6.0)


func _on_entered_water() -> void:
	if _fired.has("splash"):
		return
	_fired["splash"] = true
	await story.play("splash", self)
	Narrator.hint(Game.t("hint_hop"), 6.0)


func _beat(scene: String) -> void:
	await story.play(scene, self)
	match scene:
		"bubbles":
			Narrator.hint(Game.t("hint_swim"), 6.0)
		"deep_end":
			Game.control_locked = true
			Game.go(NEXT_SCENE, Color(0.05, 0.12, 0.1), 0.9)


func _fail() -> void:
	if _retelling:
		return
	_retelling = true
	player.teleport(_checkpoint)
	if await Retell.tell(self, story, fx, player, _checkpoint, _fail_count):
		_fail_count += 1
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
		LevelKit.hop(_banana)


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
	for w in _whirls:
		var to_whirl := Vector2(w.x, w.y) - p
		var d := to_whirl.length()
		var reach := 240.0 * w.z
		if d < reach:
			# pulls in and spins round
			var k := 1.0 - d / reach
			push += to_whirl.normalized() * 230.0 * k + to_whirl.normalized().orthogonal() * 120.0 * k
			if d < 75.0 * w.z and not _retelling:
				_fail()
	player.flow = push
	if Game.autoplay:
		_steer_bot(p)
	_animate_streaks()


## Test bot: in the whirlpool passage, swim under a high whirlpool and over a low one.
func _steer_bot(p: Vector2) -> void:
	player.bot_y = 820.0
	for w in _whirls:
		if w.z < 1.0 and w.x > p.x - 120.0:
			player.bot_y = 850.0 if w.y < 500.0 else 330.0
			return


func _animate_streaks() -> void:
	for s in _streaks:
		s.position.x -= 6.0
		var r: Rect2 = s.get_meta("zone")
		if s.position.x < r.position.x:
			s.position.x = r.end.x
		s.modulate.a = 0.3 * clampf(minf(s.position.x - r.position.x, r.end.x - s.position.x) / 120.0, 0.0, 1.0)


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
	LevelKit.solid_tiles(self, -1, -1, -ROWS, 2 * ROWS, TILE)  # the pond's ends
	LevelKit.solid_tiles(self, WIDTH, WIDTH, -ROWS, 2 * ROWS, TILE)

	for v in SPRINGS:
		_spring(v)
	for c in CURRENTS:
		_current_streaks(c)
	for i in WHIRLS.size():
		_build_whirlpool(WHIRLS[i], i)
	_build_stump()
	for f in FISH:
		_fish(f)

	player = PlayerSwim.new()
	player.name = "Player"  # a stable path for gda: /root/<Level>/Player
	player.surface_y = SURFACE_Y
	_checkpoint = _checkpoint_pos(CHECKPOINTS[0])
	player.position = _checkpoint
	player.entered_water.connect(_on_entered_water)
	add_child(player)
	StoryGate.attach(self, player, TRIGGERS, _fired, TILE)  # waits for the story before the next beat
	var retelling := func() -> bool: return _retelling
	LevelKit.story_columns(self, player, TRIGGERS, _fired, TILE, ROWS * TILE, _beat, retelling)
	LevelKit.checkpoint_columns(self, player, CHECKPOINTS, TILE, ROWS * TILE, _checkpoint_pos,
		func(pos: Vector2) -> void: _checkpoint = pos, retelling)

	camera = LevelKit.follow_camera(player, Vector2(WIDTH, ROWS) * TILE, 5.0, 0.0, Vector2.ZERO)
	camera.drag_vertical_enabled = true

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


func _build_whirlpool(w: Array, i: int) -> void:
	var pos := Vector2(w[0] * TILE + 32, w[1])
	_whirls.append(Vector3(pos.x, pos.y, w[2]))
	var s: Node2D
	if ResourceLoader.exists(ART + "whirlpool.png"):
		var sp := Sprite2D.new()
		sp.texture = load(ART + "whirlpool.png")
		sp.scale = Vector2.ONE * (170.0 * w[2] / sp.texture.get_width())
		s = sp
	else:
		var l := Line2D.new()
		l.width = 4.0
		l.default_color = Color(0.85, 0.95, 1.0, 0.7)
		var pts := PackedVector2Array()
		for k in 60:
			var a := k * 0.45
			pts.append(Vector2(cos(a), sin(a)) * (8.0 + k * 1.3) * w[2])
		l.points = pts
		s = l
	s.position = pos
	s.z_index = 1
	add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "rotation", -TAU if i % 2 == 0 else TAU, 1.6 * w[2]).from(0.0)  # each its own way


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


func _checkpoint_pos(col: int) -> Vector2:
	var x := col * TILE + 32.0
	if col < 8:
		return Vector2(x, SURFACE_Y)
	if col >= BUBBLE_COL:  # he can swim by now: come back mid-depth, clear of the whirlpool's pull
		return Vector2(x, 11 * TILE)
	return Vector2(x, 15 * TILE - 4)


# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state"]


func debug_state() -> Dictionary:
	return DebugState.side(player, TILE, _fired, {"checkpoint": _checkpoint})
