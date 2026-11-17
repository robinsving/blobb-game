class_name Retell
extends RefCounted
## Shared bits of the "that's not what happened" retell used by every level's _fail().


## The big grey scribble from the original drawing pops up over `pos` (where Blobb will be
## re-told) while the younger narrator takes it back. Call clear() on it when he reappears.
static func scribble(parent: Node, pos: Vector2, height := 320.0) -> Sprite2D:
	const TEX := "res://assets/sprites/drawn_scribble.png"
	if not ResourceLoader.exists(TEX):
		return null
	var s := Sprite2D.new()
	s.texture = load(TEX)
	s.position = pos
	s.rotation = randf_range(-0.4, 0.4)
	s.z_index = 5
	parent.add_child(s)
	var k := height / s.texture.get_height()
	s.scale = Vector2.ONE * k * 0.2
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * k, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return s


static func clear(s: Sprite2D) -> void:
	if not is_instance_valid(s):
		return
	var tw := s.create_tween()
	tw.tween_property(s, "scale", s.scale * 1.15, 0.12)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)
