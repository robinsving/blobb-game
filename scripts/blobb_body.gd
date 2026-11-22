class_name BlobbBody
extends CharacterBody2D
## What every playable side-view Blobb shares (PlayerSide on land, PlayerSwim in the water): his
## body (a lying capsule, feet at the origin), the sprite on a pivot that squashes, teleporting
## and being knocked back.

const SPRITE_SCALE := 0.42

## Set before adding to the tree: the sprite's size.
var sprite_scale := SPRITE_SCALE
## The --autoplay test bot drives this Blobb. Levels with their own bot turn it off.
var use_bot := true
var sprite: BlobbSprite
## How hard and how long a bump (knockback) throws him.
var knock_push := Vector2(650.0, -520.0)
var knock_time := 0.35
var _pivot: Node2D
var _knock := 0.0


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
	sprite.position = Vector2(0, -305 * sprite_scale * 0.5 + 4)  # feet at the body origin
	_pivot.add_child(sprite)


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_knock = 0.0


## Bumped by something at `from_x`: thrown away from it for a moment.
func knockback(from_x: float) -> void:
	var d := signf(global_position.x - from_x)
	if d == 0.0:
		d = -1.0
	velocity = Vector2(d * knock_push.x, knock_push.y)
	_knock = knock_time
	sprite.flash()
	Game.sfx("bonk", -4.0)


func _squash(s: Vector2) -> void:
	var tw := create_tween()
	_pivot.scale = s
	tw.tween_property(_pivot, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
