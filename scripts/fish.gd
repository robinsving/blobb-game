extends Node2D
## A silly fish that swims back and forth between from_x and to_x and bumps Blobb on contact.
## When he bristles at it, it turns tail and darts off for a moment (startle()).

signal bumped(body: Node2D)

var texture: Texture2D
var from_x := 0.0
var to_x := 0.0
var speed := 140.0
var _dir := 1.0
var _t := 0.0
var _sprite: Sprite2D
var _base_y := 0.0
var _dart := 0.0  # seconds of fleeing left: faster, and a little wiggle


func _ready() -> void:
	_base_y = position.y
	_t = randf() * 10.0
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.scale = Vector2(0.45, 0.45)
	add_child(_sprite)
	var area := Area2D.new()
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	cs.shape = shape
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b): bumped.emit(b))


func _process(delta: float) -> void:
	_t += delta
	_dart = maxf(_dart - delta, 0.0)
	position.x += _dir * speed * (1.0 + 1.8 * minf(_dart, 1.0)) * delta
	if position.x > to_x:
		_dir = -1.0
	elif position.x < from_x:
		_dir = 1.0
	_sprite.flip_h = _dir < 0.0  # the art faces right
	position.y = _base_y + sin(_t * 2.0) * 10.0
	_sprite.rotation = sin(_t * (6.0 + 14.0 * minf(_dart, 1.0))) * 0.06


## Blobb went prickly at it: turn away from him and dart off.
func startle(from_x: float) -> void:
	_dir = signf(position.x - from_x) if position.x != from_x else -_dir
	_dart = 1.2
