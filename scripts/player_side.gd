class_name PlayerSide
extends CharacterBody2D
## Side-view platformer Blobb. Movement is ignored while Game.control_locked.
## jump_velocity starts weak; the story upgrades it (see ch1 forest "jump" beat).

signal landed

const SPEED := 430.0
const ACCEL := 3200.0
const FRICTION := 3800.0
const GRAVITY := 2500.0
const MAX_FALL := 1500.0
const WEAK_JUMP := -420.0
const STRONG_JUMP := -1060.0
const SPRITE_SCALE := 0.42

var jump_velocity := WEAK_JUMP
## Extra run speed set by a level (ch3's dash).
var speed_mul := 1.0
## The --autoplay run-right bot. Levels with their own test bot (ch3 roofs) turn it off.
var use_bot := true
var sprite: BlobbSprite
var _pivot: Node2D
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := true
var _knock := 0.0
var _t := 0.0
var _folding := false


func _ready() -> void:
	floor_snap_length = 12.0
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 50.0
	cap.height = 116.0
	shape.shape = cap
	shape.rotation = PI / 2.0
	shape.position = Vector2(0, -54)
	add_child(shape)
	_pivot = Node2D.new()
	add_child(_pivot)
	sprite = BlobbSprite.new()
	sprite.scale = Vector2.ONE * SPRITE_SCALE
	# sprite feet at the body origin
	sprite.position = Vector2(0, -305 * SPRITE_SCALE * 0.5 + 4)
	_pivot.add_child(sprite)


func _physics_process(delta: float) -> void:
	_t += delta
	var dir := 0.0
	if not Game.control_locked and _knock <= 0.0:
		dir = Input.get_axis("left", "right")
		if Game.autoplay and use_bot:
			dir = 1.0
	_knock -= delta

	if _knock <= 0.0:
		var target := dir * SPEED * speed_mul * Game.move_scale()
		var rate := ACCEL if dir != 0.0 else FRICTION
		velocity.x = move_toward(velocity.x, target, rate * delta)

	if is_on_floor():
		_coyote = 0.1
	else:
		_coyote -= delta
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if not Game.control_locked and (Input.is_action_just_pressed("jump") or (Game.autoplay and use_bot and _bot_wants_jump())):
		_buffer = 0.13
	_buffer -= delta
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		Game.sfx("jump", -6.0, randf_range(0.95, 1.08) * (1.25 if jump_velocity == WEAK_JUMP else 1.0))
		_squash(Vector2(0.8, 1.25))
		sprite.play(_jump_anim())
		_folding = false
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.55

	move_and_slide()

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_squash(Vector2(1.25, 0.8))
		Game.sfx("land", -14.0, randf_range(0.9, 1.1))
		landed.emit()
	_was_on_floor = on_floor
	_animate(dir, on_floor)


func _animate(dir: float, on_floor: bool) -> void:
	if dir != 0.0:
		sprite.flip_h = dir < 0.0
	if on_floor:
		if absf(velocity.x) > 30.0:
			if sprite.animation != "run":
				sprite.play("run")
			# waddle: Blobb's run frames are subtle, so add a bounce and tilt
			sprite.rotation = sin(_t * 18.0) * 0.08
			_pivot.position.y = -absf(sin(_t * 18.0)) * 10.0
		else:
			if sprite.animation != "idle":
				sprite.play("idle")
			sprite.rotation = lerpf(sprite.rotation, 0.0, 0.2)
			_pivot.position.y = lerpf(_pivot.position.y, 0.0, 0.2)
	else:
		sprite.rotation = lerpf(sprite.rotation, clampf(velocity.x / SPEED, -1, 1) * 0.15, 0.2)
		_pivot.position.y = 0.0
		# super jump: past the top, fold the stretch back up on the way down
		if sprite.animation == "superjump" and velocity.y > 150.0 and not _folding:
			_folding = true
			sprite.play_backwards("superjump")


## The weak hop uses the little jump; once the story has unlocked the big jump,
## Blobb stretches out like the flying Blobb in the drawing.
func _jump_anim() -> String:
	if jump_velocity != WEAK_JUMP and sprite.sprite_frames.has_animation("superjump"):
		return "superjump"
	return "jump"


func _squash(s: Vector2) -> void:
	var tw := create_tween()
	_pivot.scale = s
	tw.tween_property(_pivot, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Test bot: jump at walls and before gaps.
func _bot_wants_jump() -> bool:
	if not is_on_floor():
		return false
	if is_on_wall():
		return true
	for h in get_tree().get_nodes_in_group("hazard"):
		var dx: float = h.global_position.x - global_position.x
		if h.visible and dx > 60.0 and dx < 170.0:
			return true
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(70, -10)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 200))
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


func knockback(from_x: float) -> void:
	var d := signf(global_position.x - from_x)
	if d == 0.0:
		d = -1.0
	velocity = Vector2(d * 650.0, -520.0)
	_knock = 0.35
	sprite.flash()
	Game.sfx("bonk", -4.0)


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_knock = 0.0
