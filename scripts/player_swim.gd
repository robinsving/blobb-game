class_name PlayerSwim
extends CharacterBody2D
## Chapter 2 Blobb: walks on the pool deck, sinks and plods along the bottom until the story lets
## him swim ("fuzz holds bubbles"), then swims freely in every direction.
## Movement is ignored while Game.control_locked. The level sets `surface_y` (water line), and each
## physics frame may set `flow` (currents, bubble columns, the filter's pull) before this node moves.

signal entered_water

enum Mode { LAND, SINK, SWIM }

const SPRITE_SCALE := 0.42
# on land (the deck)
const WALK := 380.0
const GRAVITY := 2500.0
# sinking: heavy, slow, short hops along the bottom
const SINK_WALK := 200.0
const SINK_GRAVITY := 900.0
const SINK_MAX_FALL := 320.0
const SINK_HOP := -560.0
# swimming
const SWIM := 380.0
const SWIM_ACCEL := 1500.0
const SWIM_DRAG := 900.0
const BUOYANCY := -30.0  # gentle drift up when idle

var mode := Mode.LAND
## Set before adding to the tree: sprite size, and whether --autoplay drives this Blobb.
var sprite_scale := SPRITE_SCALE
var use_bot := true
var can_swim := false
var surface_y := 200.0
var flow := Vector2.ZERO
var sprite: BlobbSprite
var _pivot: Node2D
var _knock := 0.0
var _t := 0.0
var _bubble_t := 0.0
var _bubble_tex: Texture2D


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
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = Vector2(0, -305 * sprite_scale * 0.5 + 4)
	_pivot.add_child(sprite)
	const BUBBLE := "res://assets/gen/ch2/bubble.png"
	if ResourceLoader.exists(BUBBLE):
		_bubble_tex = load(BUBBLE)


func in_water() -> bool:
	return global_position.y - 40.0 > surface_y


func _physics_process(delta: float) -> void:
	_t += delta
	_knock -= delta
	var input := Vector2.ZERO
	if not Game.control_locked and _knock <= 0.0:
		input = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down"))
		if Game.autoplay and use_bot:
			input = _bot_input()

	var was_water := mode != Mode.LAND
	if in_water() and mode == Mode.LAND:
		mode = Mode.SWIM if can_swim else Mode.SINK
		Game.sfx("splash", -6.0)
		entered_water.emit()

	match mode:
		Mode.LAND:
			_move_land(input, delta)
		Mode.SINK:
			_move_sink(input, delta)
		Mode.SWIM:
			_move_swim(input, delta)
	# currents carry him on top of his own movement (so swimming against one is slow, not impossible)
	var carried := flow if (was_water and mode != Mode.LAND) else Vector2.ZERO
	velocity += carried
	move_and_slide()
	velocity -= carried
	if is_on_wall():
		velocity.x = 0.0
	if is_on_floor() or is_on_ceiling():
		velocity.y = minf(velocity.y, 0.0) if is_on_floor() else maxf(velocity.y, 0.0)
	if mode == Mode.SWIM and global_position.y < surface_y + 70.0:
		# the surface is a ceiling: bob back down
		global_position.y = surface_y + 70.0
		velocity.y = maxf(velocity.y, 0.0)
	_animate(input, delta)


## The story lets him swim (or not). Switches mode right away if he's in the water.
func set_can_swim(on: bool) -> void:
	can_swim = on
	if mode != Mode.LAND:
		mode = Mode.SWIM if on else Mode.SINK
		if on:
			velocity.y = -200.0


func _move_land(input: Vector2, delta: float) -> void:
	velocity.x = move_toward(velocity.x, input.x * WALK, 3200.0 * delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 1400.0)


func _move_sink(input: Vector2, delta: float) -> void:
	velocity.x = move_toward(velocity.x, input.x * SINK_WALK, 1200.0 * delta)
	velocity.y = minf(velocity.y + SINK_GRAVITY * delta, SINK_MAX_FALL)
	var hop := Input.is_action_just_pressed("jump") or (Game.autoplay and use_bot and is_on_wall())
	if is_on_floor() and hop and not Game.control_locked:
		velocity.y = SINK_HOP
		Game.sfx("bubble", -10.0, 0.7)
		_squash(Vector2(0.85, 1.15))


func _move_swim(input: Vector2, delta: float) -> void:
	var want := input.limit_length(1.0) * SWIM
	if input == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2(0, BUOYANCY), SWIM_DRAG * delta)
	else:
		velocity = velocity.move_toward(want, SWIM_ACCEL * delta)


func _animate(input: Vector2, delta: float) -> void:
	if absf(input.x) > 0.1:
		sprite.face(input.x)
	match mode:
		Mode.LAND, Mode.SINK:
			var moving := absf(velocity.x) > 30.0 and is_on_floor()
			var anim := "run" if moving else "idle"
			if sprite.animation != anim:
				sprite.play(anim)
			var speed := 18.0 if mode == Mode.LAND else 9.0
			sprite.rotation = sin(_t * speed) * 0.08 if moving else lerpf(sprite.rotation, 0.0, 0.2)
		Mode.SWIM:
			if sprite.animation != "idle":
				sprite.play("idle")
			# paddle: a quick wobble while moving, a slow sway while floating
			var moving := velocity.length() > 60.0
			var tilt := clampf(velocity.x / SWIM, -1, 1) * 0.25
			var wob := sin(_t * (11.0 if moving else 2.5)) * (0.1 if moving else 0.04)
			sprite.rotation = lerpf(sprite.rotation, tilt + wob, 0.25)
			_pivot.position.y = sin(_t * 2.5) * 4.0
			_bubble_t -= delta
			if moving and _bubble_t <= 0.0:
				_bubble_t = randf_range(0.25, 0.5)
				_spawn_bubble()


func _spawn_bubble() -> void:
	if not _bubble_tex or not get_parent():
		return
	var b := Sprite2D.new()
	b.texture = _bubble_tex
	var s := randf_range(0.12, 0.22)
	b.scale = Vector2(s, s)
	b.global_position = global_position + Vector2(randf_range(-30, 30), -90)
	b.z_index = 3
	get_parent().add_child(b)
	var top := maxf(surface_y + 20.0, b.global_position.y - randf_range(150, 320))
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "global_position:y", top, 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "global_position:x", b.global_position.x + randf_range(-25, 25), 1.4)
	tw.tween_property(b, "modulate:a", 0.0, 1.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(b.queue_free)


func _squash(s: Vector2) -> void:
	var tw := create_tween()
	_pivot.scale = s
	tw.tween_property(_pivot, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func knockback(from_x: float) -> void:
	var d := signf(global_position.x - from_x)
	if d == 0.0:
		d = -1.0
	velocity = Vector2(d * 520.0, -260.0)
	_knock = 0.4
	sprite.flash()
	Game.sfx("bonk", -4.0)


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_knock = 0.0


## Test bot: head right; swim over walls, keep low (out of the current), steer away from the filter.
func _bot_input() -> Vector2:
	var v := Vector2(1, 0)
	var space := get_world_2d().direct_space_state
	var wall := false
	for dy in [-100.0, -54.0, 0.0, 40.0]:  # head to just below the feet, so it clears corners
		var from := global_position + Vector2(0, dy)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(130, 0))
		q.exclude = [get_rid()]
		wall = wall or not space.intersect_ray(q).is_empty()
	if mode == Mode.SWIM:
		# cruise at mid-depth (under the strong current, over the filter); climb over walls
		v.y = clampf((820.0 - global_position.y) / 100.0, -1.0, 1.0)  # mid-tunnel depth in the pool
		if wall:
			v.y = -1.0
	return v
