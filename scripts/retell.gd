class_name Retell
extends RefCounted
## Shared bits of the "that's not what happened" retell used by every level's _fail().


## The side-view and rooftop retell. The level has already put Blobb back (`at` is where he
## reappears); this rewinds, hides him under the scribble while Y objects (fail_1..fail_4, by
## `count`), then pops him back. If a scene is being told, Y's objection would wait behind it
## (Blobb gone, controls locked), so then he just comes back after a moment, unexplained.
## Returns true if Y objected (the level counts those).
static func tell(level: Node, story: StoryScript, fx: StyleFX, who: BlobbBody, at: Vector2, count: int) -> bool:
	Game.control_locked = true
	Game.sfx("rewind", -4.0)
	fx.rewind_pulse(1.2)
	who.visible = false
	var s := scribble(level, at + Vector2(0, -70))
	var told := false
	if Narrator.busy:
		await level.get_tree().create_timer(0.6 if Game.fast else 1.6).timeout
		Game.control_locked = Narrator.busy_blocking
	else:
		await story.play("fail_%d" % (count % 4 + 1), level)
		told = true
	clear(s)
	who.visible = true
	who.sprite.flash(0.6)
	Game.sfx("pop", -6.0)
	return told


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
