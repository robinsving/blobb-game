extends Node2D
## Chapter 5: The Climb. The last chapter. Side view, one screen wide: Blobb climbs the mountain
## from ch4, from night at the foot through blue hour to the last stars, and the sun comes up at
## the summit. O comes back, faint at first; by the top the two narrators are equals again.
## Then a glimpse of the real room in the morning (drawn in code, all silhouettes but the drawing
## of Blobb on the wall), and the end.
## Mechanics (tried out in climb_test.tscn):
##   heartbeat ledges  on every monitor beat they kick and launch whoever stands on them (no
##                     timing needed). The beat is uneven at the foot and even from "steady" up.
##   stretch & swing   after O's rule ("rule" scene, @stretch): hold E / (B) near a glowing hold
##                     (roots, then low stars), swing, let go to fling.
## Ledges are one-way: Blobb jumps up through them and lands on top. Falling a long way is a
## retell. Dialogue: chapters/ch5/story.txt. Art: assets/gen/ch5/ (optional; everything has a
## drawn fallback). --warp=N starts at section N (0 foot, 1 O's rule, 2 the stars, 3 near the
## top, 4 the summit); --autoplay hops ledge to ledge to run the story through.

const ART := "res://assets/gen/ch5/"
const W := 1920.0
const DARK := Color(0.02, 0.03, 0.08)  # the night before the narrators tell it back
const GROUND := 7000.0
const TOP := 700.0             # camera limit
const EVEN := 0.95             # seconds between beats once the beat is even
const PAN := 900.0             # at the summit the camera looks up this far, into the morning sky
const SKY_PAN := 620.0         # the sky moves less than the mountain (it's far away)
const FALL := 700.0            # this far below the last safe ledge is a fall (a retell)

## Plain ledges [x0, x1, top], bottom to top. The first is the ground; the last is the summit.
const LEDGES := [
	[0, 1920, 7000],
	# the foot (night)
	[700, 1000, 6820], [1150, 1450, 6620], [800, 1650, 6080], [450, 700, 5880],
	[100, 600, 5340], [750, 1000, 5160], [1150, 1700, 4620],
	# the middle (blue hour): O's rule, then roots
	[450, 800, 4320], [100, 500, 3770], [1600, 1900, 3700], [1300, 1800, 3150],
	# the high stretch (the last stars)
	[100, 450, 2750], [300, 800, 2200], [1600, 1900, 1950], [1000, 1500, 1400],
	[700, 950, 1220], [200, 700, 1050],
]
## Heartbeat ledges [x0, x1, top]; each launches Blobb up to the ledge above it.
const HEARTS := [
	[1550, 1750, 6620], [150, 400, 5880], [1100, 1300, 5160],
	[150, 400, 4320], [1400, 1580, 3700],
	[500, 680, 2750], [1350, 1550, 1950],
]
## Holds: [x, y, "root" | "star"]. They only work after O's rule.
const HOLDS := [
	[1000, 4380, "root"],
	[750, 3560, "root"], [1100, 3500, "root"], [1450, 3560, "root"],
	[1000, 2900, "star"], [600, 2690, "star"],
	[1100, 2000, "star"], [1450, 1850, "star"],
]
## Story beats by height: the scene plays once Blobb's feet are at or above this y.
const TRIGGERS := {6625: "heartbeat", 6085: "moss", 5345: "colour", 4625: "rule", 3155: "steady",
	2755: "stars", 2205: "pigeons", 1405: "question"}
const MOSS := Vector2(1100, 6080)
const SUMMIT_X := 700.0
const WARPS := [Vector2(200, 7000), Vector2(1400, 4620), Vector2(1550, 3150), Vector2(1250, 1400), Vector2(450, 1050)]
## Where the drawing of Blobb hangs on the wall in the room at the end (landscape: the photo in
## assets/drawing.jpeg is portrait, so it's turned a quarter to the left).
const PAPER := Rect2(50, 300, 330, 186)

var player: PlayerSide
var fx: StyleFX
var camera: Camera2D
var story := StoryScript.load_file("res://chapters/ch5/story.txt")
var _world: Node2D
var _sky: Node2D
var _lit := 1.0  # the stars, as told: 0 until Y puts them in (the intro), 1 after
var _sky_sprites := {}
var _rope: Line2D
var rig: ClimbRig  # the climbing moves: heartbeat ledges, holds, the swing
var _tex := {}
var _t := 0.0
var _beat_left := 2.0
var _swung := false
var _safe := Vector2(200, GROUND)
var _fired := {}
var _retelling := false
var _fail_count := 0
var _done := false
var _dawn := 0.0               # 0 = the sky by height, 1 = sunrise
var _sun := 0.0
var _up := 0.0                 # 0..1: the look up into the sky at the summit (moon and star)
var _sky_top: Node2D
var _pigeons: Array[Sprite2D] = []
var _pigeons_on := false
var _room: CanvasLayer
var _bot_i := 0
var _bot_wait := 0.0


func _ready() -> void:
	process_physics_priority = 10  # after the player, so a launch overrides his own movement
	Game.music("res://assets/audio/music_dream.ogg", -24.0, 3.0)
	# cliff_bg.png is a whole canyon scene (it would cover the skies), so only its right-hand
	# strip of rock is used, as the mountain's walls at both sides
	for n in ["ledge_rock", "ledge_heart", "hold_root", "hold_star", "cliff_bg"]:
		if ResourceLoader.exists(ART + n + ".png"):
			_tex[n] = load(ART + n + ".png")
	_build_world()
	if Game.warp >= 0:
		_warp_to(clampi(Game.warp, 0, WARPS.size() - 1))
	else:
		_intro()


func _build_world() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky = Node2D.new()
	_sky.draw.connect(_draw_sky)
	sky_layer.add_child(_sky)
	for n in ["night", "bluehour", "dawn", "summit"]:
		var path := ART + ("summit.png" if n == "summit" else "sky_%s.png" % n)
		if ResourceLoader.exists(path):
			var s := Sprite2D.new()
			s.texture = load(path)
			s.centered = false
			s.scale = Vector2(1920.0, 1080.0) / s.texture.get_size()
			s.modulate.a = 0.0
			sky_layer.add_child(s)
			_sky_sprites[n] = s
	# above the sky pictures: the sky further up, with the moon and the morning star (O and Y)
	_sky_top = Node2D.new()
	_sky_top.draw.connect(_draw_sky_top)
	sky_layer.add_child(_sky_top)
	_world = Node2D.new()
	_world.draw.connect(_draw_world)
	add_child(_world)
	for i in LEDGES.size():
		_solid(LEDGES[i], i > 0)
	for h in HEARTS:
		_solid(h, true)
	_solid([-64, 0, -400], false)
	_solid([W, W + 64, -400], false)
	_rope = Line2D.new()
	_rope.width = 34.0
	_rope.default_color = Color(0.36, 0.62, 0.22)
	_rope.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rope.end_cap_mode = Line2D.LINE_CAP_ROUND
	_rope.z_index = 1
	_rope.visible = false
	add_child(_rope)
	player = PlayerSide.new()
	player.name = "Player"  # a stable path for gda: /root/<Level>/Player
	player.position = _safe
	player.z_index = 2
	player.jump_velocity = PlayerSide.STRONG_JUMP
	player.use_bot = false
	add_child(player)
	player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT, 0.0)
	var spots: Array[Vector2] = []
	for h in HOLDS:
		spots.append(Vector2(h[0], h[1]))
	rig = ClimbRig.new(player, HEARTS, spots, _rope)
	rig.can_reach = false  # not before O's rule
	rig.flung.connect(func() -> void:
		if not _swung:
			_swung = true
			story.play("swing", self))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = int(W)
	camera.limit_top = int(TOP)
	camera.limit_bottom = int(GROUND + 200)
	camera.offset = Vector2(0, -140)
	player.add_child(camera)
	fx = StyleFX.new()
	add_child(fx)
	fx.set_look("real", 0.0)


## One-way ledges: Blobb jumps up through them and lands on top (the ground and walls are solid).
func _solid(r: Array, one_way: bool) -> void:
	var bottom: float = GROUND + 400.0 if not one_way else r[2] + 40.0
	LevelKit.solid(self, Rect2(r[0], r[2], r[1] - r[0], bottom - r[2]), one_way)


func _warp_to(i: int) -> void:
	var p: Vector2 = WARPS[i]
	for y in TRIGGERS:
		if y > p.y + 5:
			_fired[TRIGGERS[y]] = true
	if i >= 1:
		_fired["intro"] = true
	if i >= 2:
		rig.can_reach = true
	player.teleport(p)
	_safe = p
	Game.control_locked = false


# ================================================================ story

## The chapter's name over the night, then O comes back.
func _intro() -> void:
	Game.control_locked = true
	_lit = 0.0
	fx.tint(DARK, 0.85, 0.0)  # nothing told yet: the narrators put the mountain and the stars back
	await ChapterCard.title(self, 5, Color(0.85, 0.85, 0.95), Color(0.03, 0.04, 0.1))  # on the night, then the climb
	await story.play("intro", self)
	Game.control_locked = false
	Narrator.hint(Game.t("hint_move"), 6.0)


func _check_triggers() -> void:
	if _retelling or _done:
		return
	var y := player.position.y
	for ty in TRIGGERS:
		var scene: String = TRIGGERS[ty]
		if y <= ty and not _fired.has(scene):
			_fired[scene] = true
			_beat(scene)
	if not _done and player.is_on_floor() and y <= LEDGES[-1][2] + 5.0 and player.position.x < SUMMIT_X:
		_summit()


func _beat(scene: String) -> void:
	match scene:
		"pigeons":
			_pigeons_in()
	await story.play(scene, self)


func _fail() -> void:
	if _retelling or _done:
		return
	_retelling = true
	rig.release()
	Game.sfx("rewind", -4.0)
	fx.rewind_pulse(1.2)
	player.visible = false
	player.frozen = true
	player.teleport(_safe)
	var scribble := Retell.scribble(self, _safe + Vector2(0, -70))
	# Y's objection is queued behind whatever is being told, so it can come much later: Blobb
	# comes back after a fixed moment, not when the line ends (he used to stay invisible).
	if not Narrator.busy:  # never queued behind a scene being told: it would come far too late
		story.play("fail_%d" % (_fail_count % 4 + 1), self)
		_fail_count += 1
	await get_tree().create_timer(0.6 if Game.fast else 1.8).timeout
	Retell.clear(scribble)
	player.teleport(_safe)
	player.frozen = false
	player.visible = true
	player.sprite.flash(0.6)
	Game.sfx("pop", -6.0)
	_retelling = false


## A save point per section (the --warp numbers): the highest one he has stood above.
## Section 0 is the start, where Continue plays the intro again.
func _save_section() -> void:
	var i := WARPS.size() - 1
	while i > 0 and player.position.y > WARPS[i].y + 5.0:
		i -= 1
	if i > 0 and i > Game.progress_at:
		Game.checkpoint(i)


## The top: the morning rule works, because both halves say it. Then the room, and the end.
func _summit() -> void:
	_done = true
	Game.unlock_chapter(6)  # the story is finished: nothing left to continue
	rig.release()
	Game.control_locked = true
	player.velocity = Vector2.ZERO
	await story.play("summit", self)
	await get_tree().create_timer(1.0 if Game.fast else 2.0).timeout
	await _look_up()
	await get_tree().create_timer(1.0 if Game.fast else 4.0).timeout
	_show_room()
	await get_tree().create_timer(1.0 if Game.fast else 4.5).timeout
	await story.play("room", self)
	await ChapterCard.closing(self, "the_end", Color(0.45, 0.38, 0.32), Color(0.98, 0.95, 0.88), 2.5, 5.0)
	Game.go("res://scenes/title.tscn", Color(0.98, 0.95, 0.88), 2.0)


## After the sunrise, a slow look up past the summit into the sky: a pale moon and one bright
## star still shining in the morning, the two narrators' signs (the icons by their lines).
func _look_up() -> void:
	var center := camera.get_screen_center_position()
	camera.limit_top = int(TOP - PAN - 1000.0)
	camera.offset.y = center.y - player.global_position.y  # carry on from where the view is
	camera.reset_smoothing()
	var dur := 2.0 if Game.fast else 9.0
	var tw := create_tween().set_parallel()
	tw.tween_property(camera, "offset:y", camera.offset.y - PAN, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_up", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


# ================================================================ story effects

## O's rule: "In my half, Blobb is a good deal longer than he looks." The holds wake up.
## O, faint, tells the mountain back: it shows, dimly.
func fx_mountain() -> void:
	fx.tint(DARK, 0.45, 2.5)


## Y's half: the stars, all of them.
func fx_stars() -> void:
	fx.tint(DARK, 0.0, 2.5)
	Game.sfx("chime", -10.0, 1.2)
	create_tween().tween_property(self, "_lit", 1.0, 2.5)


func fx_stretch() -> void:
	rig.can_reach = true
	Game.sfx("pop", -6.0, 0.8)
	Narrator.hint(Game.t("hint_swing"), 10.0)


## "In mine too." The sun comes up over the summit.
func fx_sunrise() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_dawn", 1.0, 6.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_sun", 1.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fx.tint(Color(1.0, 0.85, 0.65), 0.18, 6.0)
	Game.sfx("lamp_on", -10.0, 0.6)


# ================================================================ the room and the end

## The real room in the morning light: two people, and the drawing of Blobb on the wall.
func _show_room() -> void:
	_room = CanvasLayer.new()
	_room.layer = 45  # above the world and StyleFX, below the narrator
	add_child(_room)
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	root.modulate.a = 0.0
	_room.add_child(root)
	var drawn := Control.new()
	drawn.size = Vector2(1920, 1080)
	drawn.draw.connect(_draw_room.bind(drawn))
	root.add_child(drawn)
	if ResourceLoader.exists("res://assets/drawing.jpeg"):
		var art := TextureRect.new()
		var photo := AtlasTexture.new()  # trimmed a little, so no table shows round the paper
		photo.atlas = load("res://assets/drawing.jpeg")
		photo.region = Rect2(Vector2(photo.atlas.get_size()) * 0.05, Vector2(photo.atlas.get_size()) * 0.9)
		art.texture = photo
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # before the size, or the photo's own size wins
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size = Vector2(PAPER.size.y, PAPER.size.x)
		art.pivot_offset = art.size * 0.5
		art.position = PAPER.get_center() - art.size * 0.5
		art.rotation = -PI * 0.5
		art.modulate = Color(1.0, 0.95, 0.86)  # in the morning light
		root.add_child(art)
	create_tween().tween_property(root, "modulate:a", 1.0, 1.0 if Game.fast else 4.0)


## The real room, all in silhouette against a sunrise window (the same mountains outside): the
## hospital bed with O propped up, the monitor beside it, Y on a chair leaning on the bed, their
## hands meeting on the blanket. The only thing in colour is the drawing of Blobb on the wall.
func _draw_room(c: Control) -> void:
	var wall := Color(0.2, 0.15, 0.18)
	var far := Color(0.13, 0.1, 0.13)    # the machine and the bed (a little behind)
	var near := Color(0.06, 0.05, 0.07)  # Y, nearest
	c.draw_rect(Rect2(0, 0, 1920, 1080), wall)
	# the window: a sunrise sky over the mountains
	var win := Rect2(560, 120, 800, 580)
	var top := Color(0.6, 0.66, 0.88)
	var mid := Color(1.0, 0.84, 0.66)
	var low := Color(1.0, 0.74, 0.56)
	for i in 29:
		var k := i / 28.0
		var col := top.lerp(mid, k / 0.6) if k < 0.6 else mid.lerp(low, (k - 0.6) / 0.4)
		c.draw_rect(Rect2(win.position.x, win.position.y + i * 20.0, win.size.x, 21.0), col)
	var sun := Vector2(1180, 590)
	for k in 5:
		c.draw_circle(sun, 60.0 + k * 34.0, Color(1.0, 0.95, 0.8, 0.12))
	c.draw_circle(sun, 58.0, Color(1.0, 0.97, 0.88))
	c.draw_colored_polygon(PackedVector2Array([Vector2(560, 700), Vector2(560, 640), Vector2(700, 600), Vector2(820, 640),
		Vector2(960, 556), Vector2(1100, 628), Vector2(1250, 592), Vector2(1360, 640), Vector2(1360, 700)]), Color(0.86, 0.6, 0.6))
	# frame, cross bars and curtains
	c.draw_rect(win, wall.darkened(0.2), false, 26.0)
	c.draw_rect(Rect2(951, 120, 18, 580), wall.darkened(0.2))
	c.draw_rect(Rect2(560, 401, 800, 18), wall.darkened(0.2))
	c.draw_colored_polygon(PackedVector2Array([Vector2(500, 90), Vector2(640, 90), Vector2(600, 400), Vector2(630, 760), Vector2(480, 760)]), far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(1280, 90), Vector2(1420, 90), Vector2(1440, 760), Vector2(1300, 760), Vector2(1320, 400)]), far)
	# the light: a soft beam across the wall (onto the drawing) and the floor
	c.draw_colored_polygon(PackedVector2Array([Vector2(560, 200), Vector2(560, 560), Vector2(90, 660), Vector2(90, 170)]), Color(1.0, 0.85, 0.65, 0.1))
	c.draw_rect(Rect2(0, 860, 1920, 220), Color(0.15, 0.11, 0.13))
	c.draw_colored_polygon(PackedVector2Array([Vector2(640, 860), Vector2(1300, 860), Vector2(1560, 1080), Vector2(420, 1080)]), Color(1.0, 0.84, 0.62, 0.14))
	# the monitor on its stand, a cable to the bed
	c.draw_rect(Rect2(470, 330, 12, 540), far)
	c.draw_rect(Rect2(420, 858, 112, 14), far)
	c.draw_rect(Rect2(396, 300, 160, 112), far)
	c.draw_rect(Rect2(410, 412, 30, 14), far)
	c.draw_line(Vector2(500, 412), Vector2(640, 640), far, 4.0)
	# the hospital bed: frame, wheels, the raised back, head- and footboard
	c.draw_rect(Rect2(560, 752, 900, 44), far)
	for x in [600.0, 1410.0]:
		c.draw_rect(Rect2(x, 796, 18, 62), far)
		c.draw_circle(Vector2(x + 9, 864), 14.0, far)
	c.draw_rect(Rect2(556, 620, 26, 180), far)
	c.draw_rect(Rect2(1440, 650, 26, 150), far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(586, 752), Vector2(600, 700), Vector2(800, 690), Vector2(1000, 676),
		Vector2(1100, 650), Vector2(1180, 672), Vector2(1438, 690), Vector2(1438, 752)]), far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(590, 700), Vector2(640, 520), Vector2(706, 512), Vector2(690, 700)]), far)
	# O, propped up, awake, looking out at the morning
	c.draw_colored_polygon(PackedVector2Array([Vector2(640, 702), Vector2(672, 606), Vector2(760, 584), Vector2(840, 630), Vector2(880, 700)]), far)
	c.draw_circle(Vector2(728, 548), 46.0, far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(700, 586), Vector2(748, 586), Vector2(752, 610), Vector2(700, 612)]), far)
	c.draw_colored_polygon(PackedVector2Array([Vector2(770, 620), Vector2(860, 676), Vector2(900, 688), Vector2(896, 700), Vector2(850, 694), Vector2(764, 648)]), far)  # an arm on the blanket
	# Y on a chair beside the bed, leaning on it; their hands meet
	c.draw_rect(Rect2(880, 820, 140, 16), near)
	c.draw_rect(Rect2(1004, 690, 14, 146), near)
	for x in [886.0, 1002.0]:
		c.draw_rect(Rect2(x, 836, 12, 50), near)
	c.draw_colored_polygon(PackedVector2Array([Vector2(926, 822), Vector2(998, 822), Vector2(990, 730), Vector2(944, 704), Vector2(906, 726)]), near)
	c.draw_circle(Vector2(912, 690), 36.0, near)
	c.draw_colored_polygon(PackedVector2Array([Vector2(930, 718), Vector2(900, 700), Vector2(906, 688), Vector2(940, 706)]), near)
	c.draw_colored_polygon(PackedVector2Array([Vector2(946, 726), Vector2(904, 700), Vector2(900, 688), Vector2(912, 686), Vector2(956, 712)]), near)  # an arm across to O's hand
	c.draw_colored_polygon(PackedVector2Array([Vector2(936, 822), Vector2(966, 822), Vector2(950, 900), Vector2(924, 900)]), near)
	c.draw_colored_polygon(PackedVector2Array([Vector2(972, 822), Vector2(996, 822), Vector2(984, 900), Vector2(960, 900)]), near)
	# the paper with the drawing, taped up in the beam of light (the drawing itself is a TextureRect)
	c.draw_rect(PAPER.grow(10.0), Color(0.96, 0.93, 0.86))
	c.draw_rect(Rect2(PAPER.position + Vector2(PAPER.size.x * 0.5 - 30, -18), Vector2(60, 18)), Color(0.9, 0.86, 0.74, 0.8))


# ================================================================ per frame

func _physics_process(delta: float) -> void:
	_t += delta
	_beat_left -= delta
	if _beat_left <= 0.0:
		_beat_left = _next_interval()
		_on_beat()
	if _done or _retelling:
		return
	rig.update(delta)
	if player.is_on_floor() and rig.standing_heart < 0 and rig.hold < 0:
		_safe = player.position
		_save_section()
	if player.position.y > _safe.y + FALL and rig.hold < 0:
		_fail()
		return
	if Input.is_action_just_pressed("restart") and rig.hold < 0 and not Game.control_locked:
		player.teleport(_safe)
	_check_triggers()
	if Game.autoplay:
		_bot(delta)


func _process(delta: float) -> void:
	_update_sky()
	_update_pigeons(delta)
	_world.queue_redraw()


# ================================================================ the beat

## 1 = uneven (the foot), 0 = even (from "steady" up, and at the summit).
func unevenness() -> float:
	if _done:
		return 0.0
	return clampf((player.position.y - 3150.0) / (6600.0 - 3150.0), 0.0, 1.0)


func _next_interval() -> float:
	return lerpf(EVEN, randf_range(0.5, 2.0), unevenness())


func _on_beat() -> void:
	Game.sfx("monitor", -12.0 if not _room else -20.0)
	rig.kick(_t)
	if rig.standing_heart >= 0 and rig.hold < 0 and not _done and not Game.control_locked:
		rig.launch()


# ================================================================ stretch & swing

# ================================================================ pigeons (cameo)

func _pigeons_in() -> void:
	_pigeons_on = true
	var tex: Texture2D = load("res://assets/gen/ch3/pigeon_fly.png") if ResourceLoader.exists("res://assets/gen/ch3/pigeon_fly.png") else null
	for i in 4:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * 0.45
		s.z_index = 3
		s.position = player.position + Vector2(-700 - i * 90, -200 + i * 40)
		s.set_meta("i", i)
		if tex == null:
			s.draw.connect(func(): s.draw_circle(Vector2.ZERO, 26.0, Color(0.6, 0.62, 0.7)))
		add_child(s)
		_pigeons.append(s)


func _update_pigeons(delta: float) -> void:
	if _pigeons.is_empty():
		return
	var leave := player.position.y < 1500.0 or _done
	for s in _pigeons:
		var i: int = s.get_meta("i")
		var target: Vector2
		if leave:
			target = s.position + Vector2(900, -500)
		else:
			# keeping up, a little ahead and above, bobbing (small and slow: no wobble)
			target = player.position + Vector2(-260 + i * 170, -260 - (i % 2) * 70 + sin(_t * 2.0 + i) * 14.0)
		s.position = s.position.lerp(target, clampf(delta * (0.8 if leave else 2.2), 0.0, 1.0))
		s.flip_h = target.x < s.position.x
		s.scale.y = 0.45 * (1.0 + sin(_t * 12.0 + i) * 0.08)
	if leave and _pigeons[0].position.y < player.position.y - 1400.0:
		for s in _pigeons:
			s.queue_free()
		_pigeons.clear()


# ================================================================ drawing

func _sky_mix() -> float:
	# 0 at the foot (night), 1 near the top (blue hour turning to the last stars)
	return clampf((6800.0 - player.position.y) / (6800.0 - 1100.0), 0.0, 1.0)


func _update_sky() -> void:
	var m := _sky_mix()
	if _sky_sprites.has("night"):
		_sky_sprites["night"].modulate.a = lerpf(0.4, 1.0, _lit)
	if _sky_sprites.has("bluehour"):
		_sky_sprites["bluehour"].modulate.a = smoothstep(0.25, 0.9, m) * (1.0 - _dawn)
	var dawn: Sprite2D = _sky_sprites.get("summit", _sky_sprites.get("dawn"))
	if dawn:
		dawn.modulate.a = _dawn
	var shift := _up * SKY_PAN
	for k in _sky_sprites:
		_sky_sprites[k].position.y = shift
	_sky.position.y = shift
	_sky.queue_redraw()
	_sky_top.queue_redraw()


func _draw_sky() -> void:
	var m := _sky_mix()
	var night_top := Color(0.03, 0.04, 0.12)
	var night_low := Color(0.12, 0.12, 0.28)
	var blue_top := Color(0.1, 0.16, 0.34)
	var blue_low := Color(0.42, 0.42, 0.62)
	var dawn_top := Color(0.45, 0.6, 0.85)
	var dawn_low := Color(1.0, 0.78, 0.55)
	var top := night_top.lerp(blue_top, m).lerp(dawn_top, _dawn)
	var low := night_low.lerp(blue_low, m).lerp(dawn_low, _dawn)
	for i in 30:
		_sky.draw_rect(Rect2(0, i * 36, 1920, 37), top.lerp(low, i / 29.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var star_a := (1.0 - m * 0.6) * (1.0 - _dawn) * _lit
	for i in 200:
		_sky.draw_circle(Vector2(rng.randf() * 1920, rng.randf() * 1000), rng.randf_range(0.8, 2.2), Color(1, 1, 0.92, rng.randf_range(0.3, 0.9) * star_a))
	# the sun rises behind the far ranges
	if _sun > 0.0:
		var c := Vector2(1450, lerpf(980, 640, _sun))
		for k in 6:
			_sky.draw_circle(c, 70.0 + k * 40.0, Color(1.0, 0.85, 0.5, 0.08 * _sun))
		_sky.draw_circle(c, 70.0, Color(1.0, 0.93, 0.7, _sun))
	# far ranges below, darker at night
	var range_col := Color(0.12, 0.13, 0.24).lerp(Color(0.5, 0.45, 0.6), _dawn)
	var pts := PackedVector2Array([Vector2(0, 1080)])
	for x in range(0, 1921, 80):
		pts.append(Vector2(x, 820 + sin(x * 0.006) * 50.0 + sin(x * 0.017) * 22.0))
	pts.append(Vector2(1920, 1080))
	_sky.draw_colored_polygon(pts, range_col)


## The sky above the pictures, seen when the camera looks up at the summit (_up > 0): a band from
## the top of the morning sky up to a deeper blue, a pale crescent moon (O's sign) and one bright
## star (Y's), side by side. Only the light breathes a little; nothing moves.
func _draw_sky_top() -> void:
	if _up <= 0.0:
		return
	var shift := _up * SKY_PAN
	var low := _sky_top_color()
	var high := Color(0.16, 0.26, 0.52)
	var mid := high.lerp(low, 0.55)
	_vgrad(0.0, shift * 0.5, high, mid)
	_vgrad(shift * 0.5, shift, mid, low)
	# the top of the picture fades into this sky, so there's no edge where the clouds stop
	var clear := Color(low, 0.0)
	_vgrad(shift - 1.0, shift + 260.0, low, clear)
	# the moon (warm, like O's) and the star (cool, like Y's), coming down into view
	var moon := Vector2(760, shift - 330)
	var star := Vector2(1180, shift - 400)
	var breathe := 0.85 + 0.15 * sin(_t * 1.3)
	_halo(moon, 230.0, Color(1.0, 0.92, 0.78, 0.35))
	_halo(star, 200.0, Color(0.78, 0.92, 1.0, 0.45 * breathe))
	_shape(NarratorIcon.moon_points(64.0), moon, Color(1.0, 0.95, 0.84, 0.95))
	_shape(NarratorIcon.star_points(34.0), star, Color(0.9, 0.97, 1.0))
	_sky_top.draw_circle(star, 12.0, Color(1, 1, 1, 0.9 * breathe))


## A smooth vertical gradient across the screen (vertex colours, so no bands).
func _vgrad(y0: float, y1: float, c0: Color, c1: Color) -> void:
	_sky_top.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(1920, y0), Vector2(1920, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


var _halo_tex: GradientTexture2D


## A soft round glow (a radial gradient), no rings.
func _halo(at: Vector2, r: float, col: Color) -> void:
	if not _halo_tex:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.35))
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 256
		_halo_tex.height = 256
	_sky_top.draw_texture_rect(_halo_tex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


func _shape(pts: PackedVector2Array, at: Vector2, col: Color) -> void:
	for i in pts.size():
		pts[i] += at
	_sky_top.draw_colored_polygon(pts, col)


## The colour at the top edge of the morning sky picture, so the sky above it joins without a seam.
var _top_col := Color(-1, 0, 0)


func _sky_top_color() -> Color:
	if _top_col.r >= 0.0:
		return _top_col
	_top_col = Color(0.45, 0.6, 0.85)  # the drawn dawn sky's top
	var spr: Sprite2D = _sky_sprites.get("summit", _sky_sprites.get("dawn"))
	if spr:
		var img := spr.texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var sum := Color(0, 0, 0)
			var n := 0
			for x in range(0, img.get_width(), 16):
				for y in 3:
					sum += img.get_pixel(x, y)
					n += 1
			_top_col = Color(sum.r / n, sum.g / n, sum.b / n)
	return _top_col


func _draw_world() -> void:
	# the mountain's walls at both sides: the painted rock strip, tinted to the hour
	var mood := Color(0.42, 0.42, 0.62).lerp(Color(0.72, 0.68, 0.8), _sky_mix()).lerp(Color(1.0, 0.86, 0.75), _dawn)
	if _tex.has("cliff_bg"):
		var tex: Texture2D = _tex["cliff_bg"]
		var src := Rect2(1640, 0, 280, tex.get_height())
		var w := 220.0
		var h := tex.get_height() * w / src.size.x
		var y := TOP - 400.0 - PAN
		while y < GROUND + 600.0:
			_world.draw_texture_rect_region(tex, Rect2(W - w, y, w, h), src, mood)
			_world.draw_set_transform(Vector2(w, 0), 0.0, Vector2(-1, 1))  # mirrored for the left wall
			_world.draw_texture_rect_region(tex, Rect2(0, y, w, h), src, mood)
			_world.draw_set_transform(Vector2.ZERO)
			y += h
	else:
		var rock := Color(0.16, 0.15, 0.24).lerp(Color(0.32, 0.3, 0.42), _sky_mix())
		_world.draw_rect(Rect2(-40, TOP - 400 - PAN, 260, GROUND - TOP + 800 + PAN), rock.darkened(0.15))
		_world.draw_rect(Rect2(W - 220, TOP - 400 - PAN, 260, GROUND - TOP + 800 + PAN), rock.darkened(0.15))
	for i in LEDGES.size():
		_draw_ledge(LEDGES[i], i == 0, -1)
	for i in HEARTS.size():
		_draw_ledge(HEARTS[i], false, i)
	# the moss (the same glowing moss as ch4)
	for k in 7:
		var p := MOSS + Vector2(-90 + k * 30, -6 - (k % 3) * 4)
		_world.draw_circle(p, 18.0 + (k % 2) * 6.0, Color(0.45, 0.75, 0.35, 0.9))
	_world.draw_circle(MOSS + Vector2(0, -10), 120.0, Color(0.6, 1.0, 0.5, 0.06 + sin(_t * 1.5) * 0.02))
	for i in HOLDS.size():
		_draw_hold(i)


func _draw_ledge(r: Array, ground: bool, heart: int) -> void:
	var x0: float = r[0]
	var x1: float = r[1]
	var top: float = r[2]
	var k := 0.0
	if heart >= 0:
		k = clampf(1.0 - (_t - rig.kicked.get(heart, -9.0)) / 0.3, 0.0, 1.0)
	var up := sin(k * PI) * 16.0
	if ground:
		_world.draw_rect(Rect2(x0, top, x1 - x0, 600), Color(0.2, 0.18, 0.26))
		_world.draw_rect(Rect2(x0, top, x1 - x0, 10), Color(0.42, 0.4, 0.5))
		return
	var key := "ledge_heart" if heart >= 0 else "ledge_rock"
	if _tex.has(key):
		var tex: Texture2D = _tex[key]
		var sy := 0.8
		var dest := Rect2(x0 - 14.0, top - up - 20.0 * sy, x1 - x0 + 28.0, tex.get_height() * sy)
		if heart >= 0:
			_world.draw_texture_rect(tex, dest.grow(8.0 * k), false, Color(1, 0.7, 0.75, 0.4 * k))
		_world.draw_texture_rect(tex, dest, false)
		return
	var body := Color(0.36, 0.33, 0.45) if heart < 0 else Color(0.74, 0.34, 0.44).lerp(Color(1.0, 0.6, 0.66), k)
	var rect := Rect2(x0, top - up, x1 - x0, 44)
	if heart >= 0:
		_world.draw_rect(rect.grow(6.0 * k), Color(1.0, 0.45, 0.55, 0.35 * k))
	_world.draw_rect(rect, body)
	_world.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8)), body.lightened(0.35))


func _draw_hold(i: int) -> void:
	var c := rig.holds[i]
	var star: bool = HOLDS[i][2] == "star"
	var lit := rig.can_reach and i == rig.aim and rig.hold < 0
	var a := 1.0 if rig.can_reach else 0.45
	if lit:
		_world.draw_arc(c, 40.0 + sin(_t * 8.0) * 4.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, 0.8), 4.0)
	var key := "hold_star" if star else "hold_root"
	if _tex.has(key):
		var tex: Texture2D = _tex[key]
		var s := 110.0
		_world.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
		return
	if star:
		for k in 4:
			var ang := k * PI * 0.25 + _t * 0.2
			_world.draw_line(c - Vector2(cos(ang), sin(ang)) * 34.0, c + Vector2(cos(ang), sin(ang)) * 34.0, Color(1.0, 0.95, 0.75, 0.6 * a), 3.0)
		_world.draw_circle(c, 16.0, Color(1.0, 0.95, 0.8, a))
	else:
		_world.draw_circle(c, 22.0, Color(0.55, 0.38, 0.2, a))
		_world.draw_circle(c, 14.0, Color(0.95, 0.75, 0.3, a))


# ================================================================ test bot (--autoplay)

## Hops ledge to ledge (teleporting) so the whole story runs through, up to the end card.
func _bot(delta: float) -> void:
	if Narrator.busy or Game.control_locked:
		return
	_bot_wait -= delta
	if _bot_wait > 0.0:
		return
	_bot_wait = 0.6
	_bot_i += 1
	if _bot_i >= LEDGES.size():
		return
	var l: Array = LEDGES[_bot_i]
	var p := Vector2((l[0] + l[1]) * 0.5, l[2])
	if _bot_i == LEDGES.size() - 1:
		p.x = l[0] + 120.0
	if p.y < player.position.y - 5.0:
		player.teleport(p)
		print("BOT ledge ", _bot_i, " at ", p)

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state"]


func debug_state() -> Dictionary:
	var d := DebugState.base(player)
	d.merge(DebugState.json({"fired": _fired.keys(), "stretch": rig.can_reach, "hold": rig.hold, "standing_heart": rig.standing_heart, "done": _done, "dawn": _dawn}), true)
	return d
