extends Node2D
## Chapter 1, part 1: side-view forest platformer.
## The world is built in code from the data tables below; story beats fire from trigger columns.
## Dialogue: chapters/ch1/story.txt (scene names = TRIGGERS values, fail_1..4, banana_bump).
## Flow: intro (blank paper -> Blobb -> forest) -> jump beat -> pits -> banana -> branches -> evening -> "like a bird" -> clearing.

const TILE := 64
const ROWS := 17
const WIDTH := 143
const NEXT_SCENE := "res://chapters/ch1/clearing.tscn"

## [x0, x1, top_row] solid ground down to the bottom row
const GROUND := [
	[0, 21, 13], [22, 34, 11], [39, 49, 11], [58, 87, 11], [88, 96, 5],
	[97, 108, 11], [113, 118, 10], [119, 122, 11], [126, 142, 11],
]
## [x0, x1, row] floating one-row platforms
const PLATFORMS := [[53, 54, 9]]
## [x0, x1, row] one-way branch platforms, hidden until the narrator "grows" them
const BRANCHES := [[84, 87, 9], [85, 87, 7]]
const CHECKPOINTS := [4, 30, 45, 61, 99, 116, 128]
const TRIGGERS := {19: "jump", 31: "careful", 64: "banana", 79: "branches", 100: "evening", 133: "end"}
const BANANA_X := 72
const TREE_X := 88

var player: PlayerSide
var terrain: Terrain
var fx: StyleFX
var camera: Camera2D
var banana: Banana
var _bg_crayon: Sprite2D
var _bg_dark: Sprite2D
var _branch_nodes: Array[Node2D] = []
var _checkpoint := Vector2.ZERO
var _fired := {}
var _retelling := false
var _fail_count := 0
var _bumps := 0
var story := StoryScript.load_file("res://chapters/ch1/story.txt")


func _ready() -> void:
	Game.music("res://assets/audio/music_forest.ogg", -16.0)
	_build_world()
	if Game.warp >= 0:
		_debug_warp(Game.warp)
	else:
		_intro()


func _debug_warp(col: int) -> void:
	player.visible = true
	player.jump_velocity = PlayerSide.STRONG_JUMP
	pass
	terrain.modulate.a = 1.0
	terrain.set_palette("crayon")
	_bg_crayon.modulate.a = 1.0
	fx.set_look("crayon", 0.0)
	camera.offset = Vector2(0, -120)
	for c in TRIGGERS:
		if c < col:
			_fired[TRIGGERS[c]] = true
	if col > 79:
		fx_grow_branches()
	if col > 64:
		banana.visible = true
		banana.shrink()
	_checkpoint = Vector2(col * TILE + 32, _ground_y(col) - 4)
	player.teleport(_checkpoint)


# ================================================================ story
# All dialogue lives in chapters/ch1/story.txt. This code decides WHEN a scene plays
# (TRIGGERS columns, falls, bumps) and implements the @effects as fx_* methods below.

func _intro() -> void:
	Game.control_locked = true
	player.sprite.set_tint(BlobbSprite.GREEN, 0.0, 0.0)  # uncoloured until the narrators decide
	camera.zoom = Vector2(1.9, 1.9)
	camera.offset = Vector2(0, -90)
	camera.position_smoothing_enabled = false
	await get_tree().create_timer(1.0).timeout
	await story.play("intro", self)
	Narrator.hint(Game.t("hint_move"), 6.0)


## Called when Blobb walks into a TRIGGERS column. The scene name = the trigger name.
func _beat(scene: String) -> void:
	await story.play(scene, self)
	match scene:
		"jump":
			Narrator.hint(Game.t("hint_jump"), 6.0)
		"end":
			_fly_up()


func _fail() -> void:
	if _retelling:
		return
	_retelling = true
	Game.control_locked = true
	Game.sfx("rewind", -4.0)
	fx.rewind_pulse(1.2)
	player.sprite.set_form("normal")
	player.visible = false
	player.teleport(_checkpoint)
	var scribble := Retell.scribble(self, _checkpoint + Vector2(0, -70))
	if Narrator.busy:
		# a scene is being told: Y's objection would wait behind it (Blobb gone, controls locked)
		await get_tree().create_timer(0.6 if Game.fast else 1.6).timeout
		Game.control_locked = Narrator.busy_blocking
	else:
		await story.play("fail_%d" % (_fail_count % 4 + 1), self)
		_fail_count += 1
	Retell.clear(scribble)
	player.visible = true
	player.sprite.flash(0.6)
	Game.sfx("pop", -6.0)
	_retelling = false


func _on_banana_bump() -> void:
	_bumps += 1
	if _bumps == 1:
		story.play("banana_bump", self)


# ================================================================ story effects (@name in story.txt)

func fx_blobb_appears() -> void:
	player.visible = true
	player.sprite.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(player.sprite, "scale", Vector2.ONE * PlayerSide.SPRITE_SCALE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Game.sfx("pop")


func fx_blobb_color(color: String) -> void:
	match color:
		"yellow":
			# the same gold as the lamplight in ch3 (city.gd fx_blobb_yellow)
			player.sprite.set_tint(BlobbSprite.GOLD, 0.75)
			player.sprite.set_glow(0.35, BlobbSprite.GOLD, 0.8)
		"green":
			player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT)
			player.sprite.set_glow(0.0, BlobbSprite.GOLD, 0.8)
		_:
			push_error("fx_blobb_color: unknown colour " + color)


## Swap Blobb to one of the forms from the original drawing (BlobbSprite.FORMS) or "normal".
func fx_blobb_form(form: String) -> void:
	player.sprite.set_form(form)
	Game.sfx("pop", -8.0, 0.8 if form == "grumpy" else 1.1)


func fx_forest_dark() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(camera, "zoom", Vector2.ONE, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "offset", Vector2(0, -120), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func(): camera.position_smoothing_enabled = true)
	terrain.set_palette("dark")
	fx.set_look("dark", 1.5)
	_fade_in(_bg_dark, 1.5)
	_fade_in(terrain, 1.5)
	Game.sfx("rumble", -10.0, 0.6)


func fx_forest_crayon() -> void:
	terrain.set_palette("crayon")
	fx.set_look("crayon", 1.2)
	_fade_in(_bg_crayon, 1.2)
	var tw := create_tween()
	tw.tween_property(_bg_dark, "modulate:a", 0.0, 1.2)
	Game.sfx("chime", -6.0)


func fx_jump_unlock() -> void:
	player.jump_velocity = PlayerSide.STRONG_JUMP
	player.sprite.flash()
	Game.sfx("chime", -6.0)


func fx_banana_appear() -> void:
	banana.appear()


func fx_banana_shrink() -> void:
	banana.shrink()


func fx_evening() -> void:
	fx.tint(Color(1.0, 0.7, 0.42), 0.75, 4.0)
	terrain.set_palette("evening")


func fx_grow_branches() -> void:
	Game.sfx("grow", -2.0)
	var i := 0
	for b in _branch_nodes:
		b.visible = true
		var target := b.scale
		b.scale = Vector2(0.01, 0.01)
		var tw := create_tween()
		tw.tween_interval(i * 0.35)
		tw.tween_property(b, "scale", target, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): (b.get_meta("body") as StaticBody2D).process_mode = Node.PROCESS_MODE_INHERIT)
		i += 1


func _fly_up() -> void:
	Game.control_locked = true
	Game.sfx("whoosh")
	var tw := create_tween().set_parallel()
	tw.tween_property(camera, "zoom", Vector2(0.45, 0.45), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(camera, "offset", Vector2(0, -500), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fx.white(1.0, 2.2)
	Game.go(NEXT_SCENE, Color(1.0, 0.99, 0.97), 0.5)


func _fade_in(n: CanvasItem, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(n, "modulate:a", 1.0, dur)


# ================================================================ world building

func _build_world() -> void:
	var paper_layer := CanvasLayer.new()
	paper_layer.layer = -10
	var paper := ColorRect.new()
	paper.color = Color(0.95, 0.92, 0.85)
	paper.size = Vector2(1920, 1080)
	paper_layer.add_child(paper)
	add_child(paper_layer)

	var par := Parallax2D.new()
	par.scroll_scale = Vector2(0.3, 0.0)
	add_child(par)
	_bg_dark = _bg_sprite(par, ["res://assets/gen/ch1/forest_realistic_bg_tiled.png", "res://assets/backgrounds/forest_dark_tiled.png"])
	_bg_crayon = _bg_sprite(par, ["res://assets/gen/ch1/forest_childdrawing_bg_tiled.png", "res://assets/backgrounds/forest_cartoon_tiled.png"])
	par.repeat_size = Vector2(_bg_crayon.texture.get_width() * _bg_crayon.scale.x, 0)
	if absf(_bg_dark.texture.get_width() * _bg_dark.scale.x - par.repeat_size.x) > 1.0:
		# different widths: give the dark layer its own parallax so both tile seamlessly
		var par2 := Parallax2D.new()
		par2.scroll_scale = par.scroll_scale
		par2.repeat_size = Vector2(_bg_dark.texture.get_width() * _bg_dark.scale.x, 0)
		par2.repeat_times = 3
		_bg_dark.reparent(par2, false)
		add_child(par2)
		move_child(par2, par.get_index())
	par.repeat_times = 3

	terrain = Terrain.new()
	terrain.modulate.a = 0.0
	add_child(terrain)
	_build_tree()
	for g in GROUND:
		terrain.add_block(g[0], g[1], g[2], ROWS - 1)
	for p in PLATFORMS:
		terrain.add_block(p[0], p[1], p[2], p[2])
	_wall(-1)
	_wall(WIDTH)

	for b in BRANCHES:
		_branch_nodes.append(_make_branch(b[0], b[1], b[2]))

	for col in TRIGGERS:
		_trigger(col, TRIGGERS[col])
	for col in CHECKPOINTS:
		_checkpoint_area(col)

	banana = Banana.new()
	banana.position = Vector2(BANANA_X * TILE, _ground_y(BANANA_X))
	banana.patrol_from = (BANANA_X - 6) * TILE
	banana.patrol_to = (BANANA_X + 7) * TILE
	banana.bumped_player.connect(_on_banana_bump)
	add_child(banana)

	player = PlayerSide.new()
	player.name = "Player"  # a stable path for gda: /root/<Level>/Player
	_checkpoint = Vector2(CHECKPOINTS[0] * TILE + 32, _ground_y(CHECKPOINTS[0]))
	player.position = _checkpoint
	player.visible = false
	add_child(player)
	StoryGate.attach(self, player, TRIGGERS, _fired, TILE)  # waits for the story before the next beat

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_right = WIDTH * TILE
	camera.limit_top = 0
	camera.limit_bottom = ROWS * TILE
	camera.drag_horizontal_enabled = true
	camera.drag_left_margin = 0.1
	camera.drag_right_margin = 0.1
	camera.ignore_rotation = false
	player.add_child(camera)

	fx = StyleFX.new()
	fx.set_look("paper", 0.0)
	add_child(fx)


func _bg_sprite(parent: Node, paths: Array) -> Sprite2D:
	var s := Sprite2D.new()
	for p in paths:
		if ResourceLoader.exists(p):
			s.texture = load(p)
			break
	s.centered = false
	var h := float(s.texture.get_height())
	if s.texture.resource_path.contains("childdrawing"):
		# the generated drawing fades to blank paper in its lower third; show only the drawn part
		h *= 0.72
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, s.texture.get_width(), h)
	var sc := 1080.0 / h
	s.scale = Vector2(sc, sc)
	s.modulate.a = 0.0
	parent.add_child(s)
	return s


## Big tree trunk in front of the cliff that the branches grow from (child of terrain so it fades with it).
func _build_tree() -> void:
	var trunk := Node2D.new()
	trunk.set_script(preload("res://scripts/trunk.gd"))
	trunk.position = Vector2(TREE_X * TILE, 11 * TILE)
	terrain.add_child(trunk)


func _make_branch(x0: int, x1: int, row: int) -> Node2D:
	var root := Node2D.new()
	var w := (x1 - x0 + 1) * TILE
	root.position = Vector2((x1 + 1) * TILE + 24, row * TILE + 24)  # pivot where it meets the trunk
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/tree_branch_placeholder.png")
	var sc := (w + 60.0) / spr.texture.get_width()
	spr.scale = Vector2(sc, sc)
	spr.centered = false
	spr.offset = Vector2(-spr.texture.get_width(), -spr.texture.get_height() * 0.93)
	root.add_child(spr)
	root.visible = false
	add_child(root)

	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, 16)
	cs.shape = r
	cs.one_way_collision = true
	cs.position = Vector2((x0 * TILE + w * 0.5), row * TILE + 8)
	body.add_child(cs)
	body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(body)
	root.set_meta("body", body)
	return root


func _wall(col: int) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(TILE, ROWS * TILE * 3)
	cs.shape = r
	cs.position = Vector2(col * TILE + TILE * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func _trigger(col: int, beat: String) -> void:
	var a := _column_area(col)
	a.body_entered.connect(func(b):
		if b == player and not _fired.has(beat) and not _retelling:
			_fired[beat] = true
			_beat(beat))


func _checkpoint_area(col: int) -> void:
	var a := _column_area(col)
	var pos := Vector2(col * TILE + 32, _ground_y(col))
	a.body_entered.connect(func(b):
		if b == player and not _retelling:
			_checkpoint = pos)


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


## Pixel y of the ground surface at a column (top of the highest ground block there).
func _ground_y(col: int) -> float:
	for g in GROUND:
		if col >= g[0] and col <= g[1]:
			return g[2] * TILE
	return ROWS * TILE


func _physics_process(_delta: float) -> void:
	if player and player.global_position.y > ROWS * TILE + 150:
		_fail()

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state"]


func debug_state() -> Dictionary:
	return DebugState.side(player, TILE, _fired, {"checkpoint": _checkpoint})
