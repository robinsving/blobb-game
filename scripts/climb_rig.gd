class_name ClimbRig
extends RefCounted
## Ch5's climbing moves, shared by the chapter (chapters/ch5/climb.gd) and its mechanics test
## level (climb_test.gd). The level owns the beat, the drawing and the story; this owns the moves:
##   heartbeat ledges  on every beat they kick and launch whoever stands on them (launch()).
##   holds             near one, hold `use`: Blobb stretches to it and swings (left/right pump);
##                     let go (or jump) to fling. Auto-aimed at the nearest hold in reach.
## Call update() every physics frame (after the player has moved).

signal flung  # a swing ended with Blobb letting go

const BOUNCE := -1750.0        # a heartbeat ledge's launch (~610 px up); a normal jump is ~225 px
const REACH := 380.0           # how far Blobb can stretch to a hold
const MIN_ROPE := 130.0
const ROPE := 220.0            # after the stretch, Blobb pulls himself in to this length
const PULL := 700.0            # how fast (px/s)
const SWING_G := 2500.0        # same gravity as PlayerSide
const PUMP := 900.0            # left/right while swinging
const BODY := Vector2(0, -54)  # Blobb's middle, from his feet

var player: PlayerSide
var hearts: Array              # heartbeat ledges: [x0, x1, top]
var holds: Array[Vector2]      # hold centres
var rope: Line2D
var can_reach := true          # false: no stretching yet (the chapter waits for O's rule)
var bot_pumps := false         # --autoplay: pump with the swing
var hold := -1                 # the hold Blobb is swinging on, or -1
var aim := -1                  # the nearest hold in reach (highlighted), or the one he holds
var standing_heart := -1       # the heartbeat ledge he stands on, or -1
var kicked := {}               # heart index -> time it last kicked (for drawing)
var _theta := 0.0
var _omega := 0.0
var _len := 200.0


func _init(who: PlayerSide, heart_ledges: Array, hold_spots: Array[Vector2], rope_line: Line2D) -> void:
	player = who
	hearts = heart_ledges
	holds = hold_spots
	rope = rope_line
	_dress_arm()


func update(delta: float) -> void:
	_swing(delta)
	standing_heart = _heart_under()


## A beat: every heartbeat ledge kicks (at time `t`, for drawing).
func kick(t: float) -> void:
	for i in hearts.size():
		kicked[i] = t


## Launches Blobb off the heartbeat ledge he stands on.
func launch() -> void:
	player.velocity.y = BOUNCE
	player.launched = true
	player.sprite.play("superjump")
	Game.sfx("jump", -4.0, 0.8)
	standing_heart = -1


## The swing's angle from straight down (radians, + = to the right) and speed along it (px/s).
func swing_angle() -> float:
	return _theta


func swing_speed() -> float:
	return _omega * _len


## Ends a swing without a fling (a retell, the summit).
## The stretched arm is Blobb himself: a strip of his own crayon fur (cut from the idle drawing,
## mirrored so it tiles without a seam), with his recolour material, so it's the same green and
## glows with him. Thick at his body, thinner toward a round fuzzy hand on the hold.
func _dress_arm() -> void:
	const ARM_W := 40.0
	rope.width = ARM_W
	rope.default_color = Color.WHITE
	rope.material = player.sprite.material
	rope.begin_cap_mode = Line2D.LINE_CAP_ROUND
	rope.end_cap_mode = Line2D.LINE_CAP_ROUND
	rope.joint_mode = Line2D.LINE_JOINT_ROUND
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.62))
	rope.width_curve = curve
	var frames := player.sprite.sprite_frames
	if not frames or not frames.has_animation("idle"):
		return
	var src := frames.get_frame_texture("idle", 0).get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	# a band of fur below the mouth, well inside his outline (frames are 321x305)
	var band := src.get_region(Rect2i(70, 170, 180, 60))
	var flip := band.duplicate()
	flip.flip_x()
	var strip := Image.create(band.get_width() * 2, band.get_height(), false, Image.FORMAT_RGBA8)
	strip.blit_rect(band, Rect2i(Vector2i.ZERO, band.get_size()), Vector2i.ZERO)
	strip.blit_rect(flip, Rect2i(Vector2i.ZERO, flip.get_size()), Vector2i(band.get_width(), 0))
	rope.texture = ImageTexture.create_from_image(strip)
	rope.texture_mode = Line2D.LINE_TEXTURE_TILE
	rope.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# the hand: a round patch of the same fur with a soft, ragged edge
	var size := 72
	var patch := src.get_region(Rect2i(120, 150, size, size))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bumps: Array[float] = []
	for i in 12:
		bumps.append(rng.randf_range(0.86, 1.0))
	for y in size:
		for x in size:
			var d := Vector2(x - size / 2.0 + 0.5, y - size / 2.0 + 0.5)
			var a := fposmod(d.angle(), TAU) / TAU * 12.0
			var r := lerpf(bumps[int(a) % 12], bumps[(int(a) + 1) % 12], a - floorf(a)) * size * 0.5
			var c := patch.get_pixel(x, y)
			c.a *= clampf((r - d.length()) / 3.0, 0.0, 1.0)
			patch.set_pixel(x, y, c)
	var hand := Sprite2D.new()
	hand.name = "Hand"
	hand.texture = ImageTexture.create_from_image(patch)
	hand.scale = Vector2.ONE * (ARM_W * 1.25 / size)
	hand.material = player.sprite.material
	rope.add_child(hand)


func release() -> void:
	player.frozen = false
	player.sprite.rotation = 0.0
	hold = -1
	rope.visible = false


func _heart_under() -> int:
	if not player.is_on_floor():
		return -1
	var p := player.position
	for i in hearts.size():
		var h: Array = hearts[i]
		if p.x >= h[0] - 20 and p.x <= h[1] + 20 and absf(p.y - h[2]) < 6.0:
			return i
	return -1


func nearest_hold() -> int:
	if not can_reach:
		return -1
	var body := player.position + BODY
	var best := -1
	var bd := REACH
	for i in holds.size():
		var d := body.distance_to(holds[i])
		if d < bd:
			bd = d
			best = i
	return best


func _swing(delta: float) -> void:
	aim = nearest_hold() if hold < 0 else hold
	if hold < 0:
		if Input.is_action_just_pressed("use") and aim >= 0 and not Game.control_locked:
			grab(aim)
		return
	if not (Input.is_action_pressed("use") or Game.autoplay) or Input.is_action_just_pressed("jump"):
		let_go()
		return
	_len = move_toward(_len, ROPE, PULL * delta)
	var input := Input.get_axis("left", "right")
	if bot_pumps and Game.autoplay:
		input = signf(_omega)  # the bot pumps with the swing
	_omega += (-(SWING_G / _len) * sin(_theta) + input * PUMP / _len * cos(_theta)) * delta
	_omega *= 0.998
	_theta = clampf(_theta + _omega * delta, -2.6, 2.6)
	var target := holds[hold] + Vector2(sin(_theta), cos(_theta)) * _len - BODY
	var hit := player.move_and_collide(target - player.position)
	if hit:
		if hit.get_normal().y < -0.7:
			let_go()  # swung down onto a ledge: he just lands there
			return
		_omega *= -0.3  # bumped the rock: swing back a little
		var v := player.position + BODY - holds[hold]
		_theta = atan2(v.x, v.y)
	rope.visible = true
	rope.points = PackedVector2Array([player.position + BODY, holds[hold]])
	if rope.has_node("Hand"):
		var hand: Sprite2D = rope.get_node("Hand")
		hand.position = holds[hold]
		hand.rotation = (holds[hold] - player.position - BODY).angle()
	player.sprite.rotation = -_theta * 0.6
	if input != 0.0:
		player.sprite.face(input)


func grab(i: int) -> void:
	hold = i
	var v := player.position + BODY - holds[i]
	_len = clampf(v.length(), MIN_ROPE, REACH)
	_theta = atan2(v.x, v.y)
	_omega = player.velocity.dot(Vector2(cos(_theta), -sin(_theta))) / _len
	player.frozen = true
	player.velocity = Vector2.ZERO
	player.sprite.play("superjump")
	Game.sfx("jump", -8.0, 1.4)


func let_go() -> void:
	player.velocity = Vector2(cos(_theta), -sin(_theta)) * _omega * _len + Vector2(0, -180)
	release()
	player.launched = true
	player.sprite.play("jump")
	flung.emit()
