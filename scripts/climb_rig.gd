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
## The stretched arms are drawn like his legs in the drawing: two thin black lines, one from each
## side of him, bowing apart a little and meeting at the hold.
const ARM_W := 5.0
const ARM_COLOR := Color(0.07, 0.06, 0.06)
const ARM_SPREAD := 22.0  # how far apart the two arms leave his body
const ARM_BOW := 14.0     # how far each bows out at the elbow


func _dress_arm() -> void:
	for line in [rope, Line2D.new()]:
		line.width = ARM_W
		line.default_color = ARM_COLOR
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.antialiased = true
		if line != rope:
			line.name = "Arm2"
			rope.add_child(line)


## The two arms from Blobb's middle (`from`) to the hold (`to`).
func _place_arms(from: Vector2, to: Vector2) -> void:
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	var mid := (from + to) * 0.5
	rope.points = PackedVector2Array([from + side * ARM_SPREAD, mid + side * ARM_BOW, to])
	var other: Line2D = rope.get_node("Arm2")
	other.points = PackedVector2Array([from - side * ARM_SPREAD, mid - side * ARM_BOW, to])


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
	_place_arms(player.position + BODY, holds[hold])
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
