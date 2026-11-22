extends Node2D
## Ch5 mechanics test level (plain shapes, no story): heartbeat ledges and stretch & swing.
## Run: godot-flatpak --path . -- --scene=res://chapters/ch5/climb_test.tscn
##
## Heartbeat ledges (rose): on every monitor beat they kick like a springboard and launch whoever
## stands on them (BOUNCE). No timing needed: stand on one and wait. The beat is uneven at the
## bottom and steadies as he climbs (keys 1/2/3 force uneven/middle/even, 0 goes back to by-height).
## Holds (gold knots): near one, hold E / (B): Blobb stretches to it and swings (left/right pump);
## let go to fling. Auto-aimed at the nearest hold in reach.
## R, or a long fall, puts him back on the last plain ledge he stood on.

const TILE := 64.0
const W := 1920.0
const GROUND := 3000.0
const EVEN := 0.85             # seconds between beats when the beat is even

## Plain ledges: [x0, x1, top]. The ground is the first.
const LEDGES := [
	[0, 1920, 3000],
	[560, 800, 2650],     # A: up from heart 1 (needs a bounce)
	[1150, 1400, 2100],   # A: up from heart 2
	[1250, 1480, 1760],   # A: up from heart 3 (a bounce rises ~390 px)
	[80, 300, 1600],      # B: across the chasm on the holds
	[750, 1100, 1150],    # C: swing off the high hold
	[1350, 1900, 650],    # the top
]
## Heartbeat ledges: [x0, x1, top]
const HEARTS := [
	[300, 500, 2940],
	[900, 1080, 2650],
	[1500, 1680, 2100],
	[330, 480, 1600],
	[1150, 1300, 1150],
]
## Holds: centres
const HOLDS := [
	Vector2(1050, 1430), Vector2(720, 1380), Vector2(390, 1430),   # B: the chasm
	Vector2(430, 1060),                                            # C: bounce up into this one
]

var player: PlayerSide
var camera: Camera2D
var _world: Node2D
var _rope: Line2D
var rig: ClimbRig  # the climbing moves (scripts/climb_rig.gd)
var _hud: Label
var _t := 0.0
var _beat_left := 1.0
var _last_beat := -9.0
var _force := -1.0             # forced unevenness (keys 1/2/3), or -1 for by-height
var _safe := Vector2(120, GROUND)
var _bot_step := 0
var _bot_t := 0.0


func _ready() -> void:
	process_physics_priority = 10  # after the player, so a launch overrides his own jump
	Game.music("", 0.0, 1.0)
	var sky := CanvasLayer.new()
	sky.layer = -10
	add_child(sky)
	var bg := Node2D.new()
	bg.draw.connect(_draw_sky.bind(bg))
	sky.add_child(bg)
	_world = Node2D.new()
	_world.draw.connect(_draw_world)
	add_child(_world)
	for l in LEDGES:
		_solid(l)
	for h in HEARTS:
		_solid(h)
	_solid([-64, 0, -400])
	_solid([W, W + 64, -400])
	_rope = Line2D.new()
	_rope.width = 34.0
	_rope.default_color = Color(0.36, 0.62, 0.22)
	_rope.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_rope.end_cap_mode = Line2D.LINE_CAP_ROUND
	_rope.z_index = 1
	add_child(_rope)
	player = PlayerSide.new()
	player.position = _safe
	player.z_index = 2
	player.jump_velocity = PlayerSide.STRONG_JUMP
	player.use_bot = false
	add_child(player)
	player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT, 0.0)
	var spots: Array[Vector2] = []
	spots.assign(HOLDS)
	rig = ClimbRig.new(player, HEARTS, spots, _rope)
	rig.bot_pumps = true
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_right = int(W)
	camera.limit_top = 300
	camera.limit_bottom = int(GROUND + 200)
	camera.offset = Vector2(0, -160)
	player.add_child(camera)
	var ui := CanvasLayer.new()
	ui.layer = 50
	add_child(ui)
	_hud = Label.new()
	_hud.position = Vector2(24, 18)
	_hud.add_theme_font_size_override("font_size", 22)
	_hud.add_theme_color_override("font_color", Color(0.92, 0.9, 0.98))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud.add_theme_constant_override("outline_size", 6)
	ui.add_child(_hud)
	Game.control_locked = false


func _solid(r: Array) -> void:
	var bottom: float = GROUND + 400.0 if r[2] >= GROUND - 100 else r[2] + 40.0
	LevelKit.solid(self, Rect2(r[0], r[2], r[1] - r[0], bottom - r[2]))


# ================================================================ the beat

## 1 = uneven (the foot), 0 = even (the top).
func unevenness() -> float:
	if _force >= 0.0:
		return _force
	return clampf((player.position.y - 900.0) / (GROUND - 900.0), 0.0, 1.0)


func _next_interval() -> float:
	var u := unevenness()
	return lerpf(EVEN, randf_range(0.45, 1.8), u)


func _on_beat() -> void:
	_last_beat = _t
	var u := unevenness()
	Game.sfx("monitor", lerpf(-8.0, -14.0, u))  # the monitor beep (tools/gen_monitor.py)
	rig.kick(_t)
	if rig.standing_heart >= 0 and rig.hold < 0:
		rig.launch()


# ================================================================ per frame

func _physics_process(delta: float) -> void:
	_t += delta
	_beat_left -= delta
	if _beat_left <= 0.0:
		_beat_left = _next_interval()
		_on_beat()
	rig.update(delta)
	if player.is_on_floor() and rig.standing_heart < 0 and rig.hold < 0:
		_safe = player.position
	if player.position.y > _safe.y + 900.0 or (Input.is_action_just_pressed("restart") and rig.hold < 0):
		player.teleport(_safe)
	if Game.autoplay:
		_bot()


func _process(_delta: float) -> void:
	for k in {KEY_1: 1.0, KEY_2: 0.5, KEY_3: 0.0, KEY_0: -1.0}.keys():
		if Input.is_physical_key_pressed(k):
			_force = {KEY_1: 1.0, KEY_2: 0.5, KEY_3: 0.0, KEY_0: -1.0}[k]
	var mode: String = "by height" if _force < 0.0 else ["even", "middle", "uneven"][int(_force * 2.0)]
	_hud.text = "Ch5 test.  ←→ move · Space jump · stand on a pink ledge: the beat launches you · hold E near a gold knot: swing, let go to fling · R reset\nBeat: %s (%d%% uneven) · keys 1/2/3 uneven/middle/even, 0 by height" % [mode, int(unevenness() * 100.0)]
	_world.queue_redraw()


# ================================================================ stretch & swing

# ================================================================ drawing

func _draw_sky(n: Node2D) -> void:
	var top := Color(0.05, 0.06, 0.16)
	var low := Color(0.2, 0.18, 0.36)
	for i in 30:
		n.draw_rect(Rect2(0, i * 36, 1920, 37), top.lerp(low, i / 29.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 160:
		n.draw_circle(Vector2(rng.randf() * 1920, rng.randf() * 1080), rng.randf_range(0.8, 2.0), Color(1, 1, 0.92, rng.randf_range(0.3, 0.9)))


func _draw_world() -> void:
	for l in LEDGES:
		var r := Rect2(l[0], l[2], l[1] - l[0], (GROUND + 400.0 if l[2] >= GROUND - 100 else l[2] + 40.0) - l[2])
		_world.draw_rect(r, Color(0.4, 0.36, 0.48))
		_world.draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color(0.66, 0.62, 0.74))
	for i in HEARTS.size():
		var h: Array = HEARTS[i]
		var k := clampf(1.0 - (_t - rig.kicked.get(i, -9.0)) / 0.25, 0.0, 1.0)
		var up := sin(k * PI) * 16.0
		var r := Rect2(h[0], h[2] - up, h[1] - h[0], 40)
		_world.draw_rect(r.grow(6.0 * k), Color(1.0, 0.45, 0.55, 0.35 * k))
		_world.draw_rect(r, Color(0.78, 0.32, 0.42).lerp(Color(1.0, 0.6, 0.66), k))
		_world.draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color(1.0, 0.72, 0.76))
	for i in HOLDS.size():
		var c: Vector2 = HOLDS[i]
		var lit := i == rig.aim
		if lit and rig.hold < 0:
			_world.draw_arc(c, 34.0 + sin(_t * 8.0) * 4.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, 0.8), 4.0)
		_world.draw_circle(c, 20.0, Color(0.95, 0.75, 0.3) if lit else Color(0.75, 0.58, 0.28))
		_world.draw_circle(c + Vector2(-5, -6), 6.0, Color(1.0, 0.92, 0.7))
	_world.draw_string(ThemeDB.fallback_font, Vector2(1500, 600), "TOP", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(1, 0.9, 0.6))


# ================================================================ test bot (--autoplay)

## Checks the two mechanics end to end and prints what happened: a bounce off heart 1, then a
## grab and fling on the first chasm hold.
func _bot() -> void:
	match _bot_step:
		0:
			player.teleport(Vector2(400, HEARTS[0][2]))
			_bot_step = 1
		1:
			if player.velocity.y < -1000.0:
				print("BOT bounce: launched at ", int(player.velocity.y))
				_bot_step = 2
		2:
			if player.is_on_floor():
				print("BOT landed at y ", int(player.position.y), " (heart 1 top is ", HEARTS[0][2], ")")
				player.teleport(Vector2(1300, 1760))
				_bot_step = 3
		3:
			if player.is_on_floor():
				player.velocity = Vector2(-430, -900)
				_bot_step = 4
		4:
			if rig.hold < 0 and rig.nearest_hold() >= 0:
				rig.grab(rig.nearest_hold())
				print("BOT grabbed hold ", rig.hold)
				_bot_t = _t
				_bot_step = 5
		5:
			# hang on a while (for screenshots), then let go on a fast swing to the left
			if _t - _bot_t > 3.0 and rig.swing_angle() < -0.1 and rig.swing_speed() < -500.0:
				rig.let_go()
				print("BOT flung at ", player.velocity.round(), " from ", player.position.round())
				_bot_step = 6
		6:
			if rig.hold < 0 and rig.nearest_hold() == 1:
				rig.grab(1)
				print("BOT caught hold 1 in the air")
				_bot_step = 7
			elif player.is_on_floor():
				print("BOT landed at ", player.position.round(), " without reaching hold 1")
				_bot_step = 7
