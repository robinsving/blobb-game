class_name Retell
extends RefCounted
## Shared bits of the "that's not what happened" retell used by every level's _fail().


## The side-view and rooftop retell. The level has already put Blobb back (`at` is where he
## reappears); this rewinds, hides him under the scribble while Y objects (fail_1..fail_4, by
## `count`), then pops him back. If a scene is being told, Y's objection would wait behind it
## (Blobb gone, controls locked), so then he just comes back after a moment, unexplained.
## Returns true if Y objected (the level counts those).
## `in_water` (the pond): the scribble is darker, so it shows against the water, and it floats up
## while it waits, the way Blobb himself drifts up; he comes back where it has floated to.
static func tell(level: Node, story: StoryScript, fx: StyleFX, who: BlobbBody, at: Vector2, count: int, in_water := false) -> bool:
	Game.control_locked = true
	Game.sfx("rewind", -4.0)
	fx.rewind_pulse(1.2)
	who.visible = false
	var s := scribble(level, at + Vector2(0, -70))
	var rise: Tween
	if s and in_water:
		s.modulate = Color(0.12, 0.12, 0.16)  # near black: the pond is mid-dark green
		var top := (who as PlayerSwim).surface_y + 70.0 if who is PlayerSwim else s.position.y - 400.0
		rise = s.create_tween()  # up at about 45 px/s, the drift of a floating Blobb, until the surface
		rise.tween_property(s, "position:y", top, maxf(s.position.y - top, 0.0) / 45.0)
		var sway := s.create_tween().set_loops()
		sway.tween_property(s, "rotation", s.rotation + 0.12, 1.1).set_trans(Tween.TRANS_SINE)
		sway.tween_property(s, "rotation", s.rotation - 0.12, 1.1).set_trans(Tween.TRANS_SINE)
	var told := false
	if Narrator.busy:
		await level.get_tree().create_timer(0.6 if Game.fast else 1.6).timeout
		Game.control_locked = Narrator.busy_blocking
	else:
		await story.play("fail_%d" % (count % 4 + 1), level)
		told = true
	if not is_instance_valid(who):
		return told  # the level was left mid-retell (a static func keeps running after it's freed)
	if s and in_water and is_instance_valid(s):
		var top := (who as PlayerSwim).surface_y + 140.0 if who is PlayerSwim else -INF
		who.global_position = Vector2(at.x, maxf(s.position.y + 70.0, top))
		who.velocity = Vector2.ZERO
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
