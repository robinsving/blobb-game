extends Node2D
## Chapter 3, part 1: the town at night, side view.
## Flow: poster (title page) -> street at dusk -> "I brought the night" -> Y switches the lamps on ->
## gold Blobb under the lamps ("Wasn't he green?") -> the banana sweeping -> the dash over the
## canal (retells) -> sleeping pigeons -> the drainpipe up to the roofs (chapters/ch3/roofs.tscn).
## Dialogue: chapters/ch3/story.txt. Art: assets/gen/ch3/ (everything has a drawn fallback).

const TILE := 64
const ROWS := 17
const WIDTH := 96
const NEXT_SCENE := "res://chapters/ch3/roofs.tscn"
const ART := "res://assets/gen/ch3/"
const STREET_ROW := 13

## [x0, x1, top_row] solid ground down to the bottom row. The gap 47..53 is the canal: too wide for
## a normal jump (~365 px), so the dash (1.7x speed) is how Blobb gets over.
const GROUND := [[0, 46, 13], [54, 95, 13]]
## [x0, x1, row] doorsteps and a bench to hop on
const STEPS := [[21, 23, 12], [37, 38, 12], [58, 60, 12], [76, 77, 12]]
const LAMPS := [6, 14, 22, 30, 38, 45, 54, 62, 70, 78, 86]
const CHECKPOINTS := [4, 18, 36, 56, 72]
const TRIGGERS := {12: "glow", 28: "sweeper", 41: "dash", 66: "pigeons", 86: "climb"}
const CANAL := [47, 53]
const SWEEP_FROM := 27
const SWEEP_TO := 36
const PIGEON_COL := 66
const PIPE_COL := 90
const NIGHT_TINT := Color(0.55, 0.66, 1.0)
const GOLD := BlobbSprite.GOLD

var player: PlayerSide
var _dashing := false
var fx: StyleFX
var camera: Camera2D
var _sky_dusk: TextureRect
var _sky_night: TextureRect
var _stars: Node2D
var _houses: CanvasItem
var _pave: Texture2D  # painted kerb and cobbles, if generated
var _lamps: Array[Node2D] = []
var _pools: Array[Sprite2D] = []
var _pigeons: Array[Sprite2D] = []
var _sweeper: Node2D
var _sweep_dir := 1.0
var _sweep_hit := 0.0
var _bumps := 0
var _shine := false
var _glow := 0.0
var _checkpoint := Vector2.ZERO
var _fired := {}
var _retelling := false
var _fail_count := 0
var _t := 0.0
var _poster_layer: CanvasLayer
var story := StoryScript.load_file("res://chapters/ch3/story.txt")


func _ready() -> void:
	Game.music("res://assets/audio/music_city.ogg", -15.0)
	_build_world()
	if Game.warp >= 0:
		_debug_warp(Game.warp)
	else:
		_intro()


func _debug_warp(col: int) -> void:
	fx_nightfall(0.0)
	for i in _lamps.size():
		_light_lamp(i, true)
	for c in TRIGGERS:
		if c < col:
			_fired[TRIGGERS[c]] = true
	if col > 12:
		_shine = true
		player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT, 0.0)
	player.jump_velocity = PlayerSide.STRONG_JUMP
	_checkpoint = Vector2(col * TILE + 32, _ground_y(col))
	player.teleport(_checkpoint)
	player.visible = true


# ================================================================ story

func _intro() -> void:
	Game.control_locked = true
	player.visible = true
	await _poster()
	await story.play("intro", self)
	Narrator.hint(Game.t("hint_move"), 6.0)


## The chapter's title page: the poster with the chapter name, a very slow push in (no sway),
## then it dissolves into the street.
func _poster() -> void:
	_poster_layer = CanvasLayer.new()
	_poster_layer.layer = 50  # above StyleFX (40), below the fade (55) and the narrator (60)
	add_child(_poster_layer)
	var pic := TextureRect.new()
	pic.size = Vector2(1920, 1080)
	pic.pivot_offset = Vector2(1100, 640)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(ART + "ch3_poster.png"):
		pic.texture = load(ART + "ch3_poster.png")
	else:
		pic.texture = _poster_fallback()
	_poster_layer.add_child(pic)
	var title := VBoxContainer.new()
	title.position = Vector2(130, 110)
	_poster_layer.add_child(title)
	for spec in [[Game.t("chapter_3"), 44, Fonts.serif()], [Game.t("chapter_3_name"), 120, Fonts.hand()]]:
		var l := Label.new()
		l.text = spec[0]
		l.add_theme_font_override("font", spec[2])
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08, 0.8))
		l.add_theme_constant_override("outline_size", 10)
		l.modulate.a = 0.0
		title.add_child(l)
	pic.modulate.a = 0.0
	var hold := 0.6 if Game.fast else 5.0
	var tw := create_tween()
	tw.tween_property(pic, "modulate:a", 1.0, 1.6)
	tw.parallel().tween_property(pic, "scale", Vector2.ONE * 1.035, hold + 4.5).set_trans(Tween.TRANS_SINE)
	for l in title.get_children():
		tw.tween_property(l, "modulate:a", 1.0, 1.0)
	tw.tween_interval(hold)
	await tw.finished
	var out := create_tween().set_parallel()
	out.tween_property(pic, "modulate:a", 0.0, 2.4)
	out.tween_property(title, "modulate:a", 0.0, 1.2)
	await out.finished
	_poster_layer.queue_free()


## Night street with one lamp and Blobb, used until the generated poster exists.
func _poster_fallback() -> Texture2D:
	var img := Image.create(480, 270, false, Image.FORMAT_RGBA8)
	for y in 270:
		for x in 480:
			var sky := Color(0.04, 0.06, 0.16).lerp(Color(0.12, 0.16, 0.32), y / 270.0)
			var d := Vector2(x - 300, (y - 150) * 1.4).length()
			sky = sky.lerp(Color(1.0, 0.75, 0.35), clampf(1.0 - d / 140.0, 0, 1) * 0.55)
			if y > 215:
				sky = Color(0.08, 0.09, 0.14).lerp(Color(0.5, 0.38, 0.2), clampf(1.0 - absf(x - 300) / 90.0, 0, 1) * 0.6)
			img.set_pixel(x, y, sky)
	return ImageTexture.create_from_image(img)


func _beat(scene: String) -> void:
	await story.play(scene, self)
	match scene:
		"dash":
			Narrator.hint(Game.t("hint_dash"), 5.0)


func _fail() -> void:
	if _retelling:
		return
	_retelling = true
	Game.control_locked = true
	Game.sfx("splash", -6.0)
	Game.sfx("rewind", -4.0)
	fx.rewind_pulse(1.2)
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


# ================================================================ story effects

func fx_nightfall(dur := 4.0) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(_sky_night, "modulate:a", 1.0, dur)
	tw.tween_property(_stars, "modulate:a", 1.0, dur * 1.3)
	tw.tween_property(_houses, "modulate", Color(0.55, 0.6, 0.85), dur)
	fx.tint(NIGHT_TINT, 0.32, dur)


func fx_lamps_on() -> void:
	# nearest lamps first, then on down the street
	var order := range(_lamps.size())
	order.sort_custom(func(a, b): return absf(_lamps[a].position.x - player.position.x) < absf(_lamps[b].position.x - player.position.x))
	var i := 0
	for k in order:
		get_tree().create_timer(0.35 * i).timeout.connect(_light_lamp.bind(k, false))
		i += 1


func _light_lamp(i: int, instant: bool) -> void:
	var pool := _pools[i]
	var lantern: CanvasItem = _lamps[i].get_meta("glass")
	if instant:
		pool.modulate.a = 1.0
		lantern.modulate = Color(1, 1, 1)
		return
	Game.sfx("lamp_on", -10.0, randf_range(0.95, 1.08))
	var tw := create_tween().set_parallel()
	tw.tween_property(pool, "modulate:a", 1.0, 0.5)
	tw.tween_property(lantern, "modulate", Color(1, 1, 1), 0.2)


func fx_blobb_yellow() -> void:
	player.sprite.set_tint(GOLD, 0.75, 1.2)
	player.sprite.set_glow(0.35, GOLD, 1.2)
	Game.sfx("chime", -8.0, 0.9)


func fx_blobb_green() -> void:
	player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT, 0.6)
	player.sprite.set_glow(0.0, GOLD, 0.6)
	player.sprite.flash()
	Game.sfx("pop", -6.0)


func fx_blobb_shine() -> void:
	_shine = true
	Game.sfx("chime", -8.0, 1.2)


## "So fast he went all blurry": the green streak lasts until he's landed over the canal (through
## any retells), so the dash is what gets him across.
func fx_dash() -> void:
	player.jump_velocity = PlayerSide.STRONG_JUMP
	_dashing = true
	_set_dash(true)
	Game.sfx("whoosh", -6.0)


func _set_dash(on: bool) -> void:
	player.speed_mul = 1.7 if on else 1.0
	player.sprite.set_form("dash" if on else "normal")


func fx_climb() -> void:
	Game.control_locked = true
	var pipe_x := PIPE_COL * TILE + 20.0
	var tw := create_tween()
	tw.tween_property(player, "position:x", pipe_x, absf(pipe_x - player.position.x) / 380.0)
	await tw.finished
	# the camera stays on Blobb (moving it to the level here made the picture jump)
	player.set_physics_process(false)
	Game.sfx("whoosh", -10.0, 0.7)
	var up := create_tween()
	up.tween_property(player, "position:y", -300.0, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(2.0).timeout
	Game.go(NEXT_SCENE, Color(0.02, 0.03, 0.08), 0.9)


# ================================================================ per frame

func _process(delta: float) -> void:
	_t += delta
	if _dashing and player.is_on_floor() and player.position.x > (CANAL[1] + 2) * TILE:
		_dashing = false  # over the canal: back to his usual self
		_set_dash(false)
		Game.sfx("pop", -8.0)
	_update_sweeper(delta)
	if _shine:
		# green, with a warm glow that grows under each lamp
		var near := 9999.0
		for l in _lamps:
			near = minf(near, absf(l.position.x - player.position.x))
		var g := clampf(1.0 - near / 220.0, 0.0, 1.0) * 0.35
		if absf(g - _glow) > 0.04:
			_glow = g
			player.sprite.set_glow(g, GOLD, 0.25)
	for i in _pigeons.size():
		_pigeons[i].position.y = _pigeons[i].get_meta("y") + sin(_t * 1.3 + i) * 1.5


func _physics_process(_delta: float) -> void:
	if player and player.global_position.y > ROWS * TILE + 150 and not _retelling:
		_fail()


func _update_sweeper(delta: float) -> void:
	if not _sweeper:
		return
	_sweeper.position.x += _sweep_dir * 60.0 * delta
	if _sweeper.position.x > SWEEP_TO * TILE:
		_sweep_dir = -1.0
	elif _sweeper.position.x < SWEEP_FROM * TILE:
		_sweep_dir = 1.0
	var spr: Sprite2D = _sweeper.get_child(0)
	spr.flip_h = _sweep_dir < 0.0
	spr.rotation = sin(_t * 7.0) * 0.06
	_sweep_hit -= delta
	if _sweep_hit <= 0.0 and not _retelling and player.position.distance_to(_sweeper.position) < 90.0:
		_sweep_hit = 1.0
		player.knockback(_sweeper.position.x)
		_bumps += 1
		if _bumps == 1:
			story.play("banana_bump", self)


# ================================================================ world building

func _build_world() -> void:
	var back := CanvasLayer.new()
	back.layer = -10
	add_child(back)
	_sky_dusk = _gradient_rect([Color(0.36, 0.38, 0.62), Color(0.95, 0.6, 0.42), Color(1.0, 0.78, 0.5)])
	back.add_child(_sky_dusk)
	_sky_night = _gradient_rect([Color(0.02, 0.03, 0.1), Color(0.07, 0.1, 0.24), Color(0.2, 0.2, 0.36)])
	_sky_night.modulate.a = 0.0
	back.add_child(_sky_night)
	_stars = Node2D.new()
	_stars.modulate.a = 0.0
	_stars.draw.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		for i in 160:
			var p := Vector2(rng.randf() * 1920, rng.randf() * 620)
			_stars.draw_circle(p, rng.randf_range(0.8, 2.2), Color(1, 1, 0.92, rng.randf_range(0.3, 0.9))))
	back.add_child(_stars)

	var par := Parallax2D.new()
	par.scroll_scale = Vector2(0.45, 1.0)
	add_child(par)
	if ResourceLoader.exists(ART + "city_street_bg.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "city_street_bg.png")
		s.centered = false
		# tall enough that the sky above it never shows when the camera looks up
		var k := (STREET_ROW * TILE + 420.0) / s.texture.get_height()
		s.scale = Vector2(k, k)
		s.position = Vector2(0, -300)
		par.add_child(s)
		par.repeat_size = Vector2(s.texture.get_width() * k, 0)
		par.repeat_times = 3
		_houses = s
	else:
		var h := Node2D.new()
		h.draw.connect(_draw_houses.bind(h))
		par.add_child(h)
		par.repeat_size = Vector2(2400, 0)
		par.repeat_times = 3
		_houses = h
	_houses.modulate = Color(1.0, 0.82, 0.72)

	if ResourceLoader.exists(ART + "pavement_strip.png"):
		_pave = load(ART + "pavement_strip.png")
	var street := Node2D.new()
	street.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the pavement strip is sampled in world pixels
	street.draw.connect(_draw_street.bind(street))
	add_child(street)
	for g in GROUND:
		_solid(g[0], g[1], g[2], ROWS - 1)
	for s in STEPS:
		_solid(s[0], s[1], s[2], s[2])
	_solid(-1, -1, 0, ROWS - 1)
	_solid(WIDTH, WIDTH, 0, ROWS - 1)

	for i in LAMPS.size():
		_make_lamp(LAMPS[i])
	_make_pipe()
	_make_sweeper()
	_make_pigeons()

	for col in TRIGGERS:
		_column_area(col).body_entered.connect(func(b):
			var beat: String = TRIGGERS[col]
			if b == player and not _fired.has(beat) and not _retelling:
				_fired[beat] = true
				_beat(beat))
	for col in CHECKPOINTS:
		var pos := Vector2(col * TILE + 32, _ground_y(col))
		_column_area(col).body_entered.connect(func(b):
			if b == player and not _retelling:
				_checkpoint = pos)

	player = PlayerSide.new()
	player.name = "Player"  # a stable path for gda: /root/<Level>/Player
	_checkpoint = Vector2(CHECKPOINTS[0] * TILE + 32, _ground_y(CHECKPOINTS[0]))
	player.position = _checkpoint
	player.visible = false
	player.z_index = 2
	add_child(player)
	StoryGate.attach(self, player, TRIGGERS, _fired, TILE)  # waits for the story before the next beat
	player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT, 0.0)
	player.jump_velocity = PlayerSide.STRONG_JUMP  # unlocked back in ch1

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
	camera.offset = Vector2(0, -120)
	player.add_child(camera)

	fx = StyleFX.new()
	fx.set_look("real", 0.0)
	add_child(fx)


func _gradient_rect(cols: Array) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
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


## Fallback town: row houses with lit windows, in flat, soft shapes.
func _draw_houses(n: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var base := STREET_ROW * TILE + 10.0
	var x := 0.0
	while x < 2400.0:
		var w := rng.randf_range(220, 360)
		var h := rng.randf_range(420, 640)
		var col := Color(0.24, 0.22, 0.3).lerp(Color(0.36, 0.28, 0.3), rng.randf())
		n.draw_rect(Rect2(x, base - h, w - 6, h), col)
		# roof
		n.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, base - h), Vector2(x + w * 0.5, base - h - rng.randf_range(60, 120)), Vector2(x + w + 4, base - h)]), col.darkened(0.35))
		if rng.randf() < 0.6:
			n.draw_rect(Rect2(x + w * 0.7, base - h - 90, 30, 70), col.darkened(0.25))
		var wy := base - h + 70.0
		while wy < base - 160.0:
			var wx := x + 30.0
			while wx < x + w - 70.0:
				var lit := rng.randf() < 0.35
				n.draw_rect(Rect2(wx, wy, 40, 58), Color(1.0, 0.8, 0.45) if lit else Color(0.12, 0.12, 0.2))
				wx += 80.0
			wy += 110.0
		n.draw_rect(Rect2(x + w * 0.5 - 30, base - 130, 60, 130), col.darkened(0.45))
		x += w


func _draw_street(n: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# canal water between the two halves of the street
	var cx0 := CANAL[0] * TILE
	var cx1 := (CANAL[1] + 1) * TILE
	n.draw_rect(Rect2(cx0, (STREET_ROW + 1.5) * TILE, cx1 - cx0, ROWS * TILE), Color(0.06, 0.1, 0.2))
	for i in 8:
		var y := (STREET_ROW + 1.8) * TILE + i * 22.0
		n.draw_line(Vector2(cx0 + rng.randf_range(10, 60), y), Vector2(cx1 - rng.randf_range(10, 60), y), Color(1.0, 0.8, 0.45, 0.25), 3.0)
	var pave := _pave
	for g in GROUND + STEPS:
		var r := Rect2(g[0] * TILE, g[2] * TILE, (g[1] - g[0] + 1) * TILE, ((ROWS - 1) - g[2] + 1) * TILE if g in GROUND else TILE)
		n.draw_rect(r, Color(0.2, 0.2, 0.26))
		if pave:
			# the painted kerb and cobbles; steps (one tile tall) show only its top half
			var h := minf(r.size.y, float(pave.get_height()))
			n.draw_texture_rect_region(pave, Rect2(r.position, Vector2(r.size.x, h)), Rect2(r.position.x, 0, r.size.x, h))
			continue
		n.draw_rect(Rect2(r.position, Vector2(r.size.x, 16)), Color(0.52, 0.52, 0.58))
		n.draw_rect(Rect2(r.position + Vector2(0, 16), Vector2(r.size.x, 6)), Color(0.12, 0.12, 0.16))
		if g in GROUND:
			# cobbles
			var y := r.position.y + 40.0
			var row := 0
			while y < r.end.y:
				var x := r.position.x + (18.0 if row % 2 else 0.0)
				while x < r.end.x - 20:
					n.draw_rect(Rect2(x + 3, y, 32, 18), Color(0.26, 0.26, 0.33).lerp(Color(0.32, 0.3, 0.34), rng.randf()))
					x += 36.0
				y += 24.0
				row += 1


func _solid(x0: int, x1: int, top: int, bottom: int) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2((x1 - x0 + 1) * TILE, (bottom - top + 1) * TILE)
	cs.shape = shape
	cs.position = Vector2((x0 + x1 + 1) * 0.5 * TILE, (top + bottom + 1) * 0.5 * TILE)
	body.add_child(cs)
	add_child(body)


func _make_lamp(col: int) -> void:
	var n := Node2D.new()
	n.position = Vector2(col * TILE + 32, _ground_y(col))
	add_child(n)
	var glass: CanvasItem
	if ResourceLoader.exists(ART + "street_lamp.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "street_lamp.png")
		var k := 430.0 / s.texture.get_height()
		s.scale = Vector2(k, k)
		s.offset = Vector2(0, -s.texture.get_height() * 0.5)
		n.add_child(s)
		glass = s
	else:
		var post := Node2D.new()
		post.draw.connect(func():
			post.draw_rect(Rect2(-7, -400, 14, 400), Color(0.1, 0.1, 0.13))
			post.draw_rect(Rect2(-18, -24, 36, 24), Color(0.1, 0.1, 0.13))
			post.draw_rect(Rect2(-24, -470, 48, 70), Color(0.1, 0.1, 0.13)))
		n.add_child(post)
		var lit := Node2D.new()
		lit.draw.connect(func(): lit.draw_rect(Rect2(-17, -462, 34, 54), Color(1.0, 0.85, 0.5)))
		n.add_child(lit)
		glass = lit
	glass.modulate = Color(0.35, 0.35, 0.42)
	n.set_meta("glass", glass)
	_lamps.append(n)
	# the pool of light: a soft cone down to the pavement, added on top
	var pool := Sprite2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.82, 0.45, 0.55), Color(1.0, 0.75, 0.35, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	pool.texture = gt
	pool.scale = Vector2(2.4, 2.6)
	pool.position = n.position + Vector2(0, -230)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pool.material = mat
	pool.modulate.a = 0.0
	pool.z_index = 1
	add_child(pool)
	_pools.append(pool)


func _make_pipe() -> void:
	var p := Node2D.new()
	p.position = Vector2(PIPE_COL * TILE + 20, 0)
	p.draw.connect(func():
		p.draw_rect(Rect2(-12, -200, 24, STREET_ROW * TILE + 200), Color(0.16, 0.17, 0.2))
		p.draw_rect(Rect2(-12, -200, 7, STREET_ROW * TILE + 200), Color(0.3, 0.32, 0.38))
		var y := 60.0
		while y < STREET_ROW * TILE:
			p.draw_rect(Rect2(-18, y, 36, 12), Color(0.12, 0.12, 0.15))
			y += 150.0)
	add_child(p)


func _make_sweeper() -> void:
	_sweeper = Node2D.new()
	_sweeper.position = Vector2(SWEEP_FROM * TILE, _ground_y(SWEEP_FROM))
	_sweeper.z_index = 1
	_sweeper.add_to_group("hazard")  # the test bot hops over it
	add_child(_sweeper)
	var s := Sprite2D.new()
	var path := ART + "banana_sweeper.png"
	if not ResourceLoader.exists(path):
		path = "res://assets/gen/ch2/banana_lifeguard.png"
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/banana.png"
	s.texture = load(path)
	var k := 150.0 / s.texture.get_height()
	s.scale = Vector2(k, k)
	s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	_sweeper.add_child(s)


func _make_pigeons() -> void:
	# asleep on a shop sign over the pavement
	var shop_sign := Node2D.new()
	var y := (STREET_ROW - 5) * TILE
	shop_sign.draw.connect(func():
		shop_sign.draw_rect(Rect2(PIGEON_COL * TILE - 140, y, 360, 26), Color(0.2, 0.14, 0.12))
		shop_sign.draw_rect(Rect2(PIGEON_COL * TILE - 140, y + 26, 360, 90), Color(0.3, 0.2, 0.18))
		shop_sign.draw_rect(Rect2(PIGEON_COL * TILE - 120, y + 40, 320, 60), Color(0.42, 0.3, 0.22)))
	add_child(shop_sign)
	for i in 4:
		var s := Sprite2D.new()
		if ResourceLoader.exists(ART + "pigeon_sit.png"):
			s.texture = load(ART + "pigeon_sit.png")
			var k := 70.0 / s.texture.get_height()
			s.scale = Vector2(k, k)
		else:
			s.texture = _pigeon_fallback()
		s.flip_h = i % 2 == 1
		s.position = Vector2(PIGEON_COL * TILE - 100 + i * 85, y - 30)
		s.set_meta("y", s.position.y)
		add_child(s)
		_pigeons.append(s)


func _pigeon_fallback() -> Texture2D:
	var img := Image.create(64, 56, false, Image.FORMAT_RGBA8)
	for py in 56:
		for px in 64:
			var body := Vector2((px - 30) / 26.0, (py - 34) / 18.0).length() < 1.0
			var head := Vector2(px - 14, py - 16).length() < 10.0
			if body or head:
				img.set_pixel(px, py, Color(0.55, 0.57, 0.65) if body else Color(0.4, 0.45, 0.55))
	return ImageTexture.create_from_image(img)


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
	for s in STEPS:
		if col >= s[0] and col <= s[1]:
			return s[2] * TILE
	for g in GROUND:
		if col >= g[0] and col <= g[1]:
			return g[2] * TILE
	return ROWS * TILE

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state"]


func debug_state() -> Dictionary:
	return DebugState.side(player, TILE, _fired, {"checkpoint": _checkpoint, "dashing": _dashing})
