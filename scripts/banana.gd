class_name Banana
extends Node2D
## The "monster" in ch1. Starts huge and blocking (solid wall), the younger narrator shrinks it,
## then it patrols and bumps Blobb back on contact.

signal bumped_player

const TEX := preload("res://assets/sprites/banana.png")

var patrol_from := 0.0
var patrol_to := 0.0
var speed := 70.0
var _dir := 1.0
var _small := false
var _sprite: Sprite2D
var _blocker: StaticBody2D
var _hurt: Area2D
var _t := 0.0


func _ready() -> void:
	add_to_group("hazard")
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.offset = Vector2(0, -TEX.get_height() * 0.5)  # feet at origin
	add_child(_sprite)
	set_size(1.6)

	_blocker = StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(300, 1400)
	cs.shape = r
	cs.position = Vector2(0, -700)
	_blocker.add_child(cs)
	add_child(_blocker)

	_hurt = Area2D.new()
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(50, 100)
	hs.shape = hr
	hs.position = Vector2(0, -55)
	_hurt.add_child(hs)
	_hurt.monitoring = false
	_hurt.body_entered.connect(_on_body)
	add_child(_hurt)
	visible = false


func set_size(s: float) -> void:
	_sprite.scale = Vector2.ONE * s


func appear() -> void:
	visible = true
	modulate.a = 0.0
	_sprite.scale = Vector2(1.6, 0.2)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	tw.tween_property(_sprite, "scale", Vector2.ONE * 1.6, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Game.sfx("rumble", -2.0)


func shrink() -> void:
	Game.sfx("shrink", -2.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2.ONE * 0.2, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	_blocker.queue_free()
	_small = true
	_hurt.set_deferred("monitoring", true)


func _process(delta: float) -> void:
	_t += delta
	if not _small:
		_sprite.rotation = sin(_t * 1.5) * 0.02
		return
	position.x += _dir * speed * delta
	if position.x > patrol_to:
		_dir = -1.0
	elif position.x < patrol_from:
		_dir = 1.0
	_sprite.flip_h = _dir < 0.0
	_sprite.rotation = sin(_t * 12.0) * 0.12
	_sprite.position.y = -absf(sin(_t * 12.0)) * 5.0


func _on_body(body: Node) -> void:
	if body is PlayerSide:
		body.knockback(global_position.x)
		bumped_player.emit()
