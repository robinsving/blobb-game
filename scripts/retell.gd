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
	# with the reform strip, the scribble shown is its first frame, so the animation picks up from it
	var reforms := who.sprite.form == "normal" and who.sprite.sprite_frames.has_animation("reform")
	var s := _reform_start(level, who, 380.0 if in_water else 320.0) if reforms else scribble(level, at + Vector2(0, -70))
	var rise: Tween
	if s and in_water:
		if not reforms:
			_water_look(s)
		var top := (who as PlayerSwim).surface_y + 70.0 if who is PlayerSwim else s.position.y - 400.0
		rise = s.create_tween()  # up at about 45 px/s, the drift of a floating Blobb, until the surface
		rise.tween_property(s, "position:y", top, maxf(s.position.y - top, 0.0) / 45.0)
		if not reforms:  # (the reform frame stays upright: the animation starts upright)
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
	if s and in_water and is_instance_valid(s) and not reforms:
		var top := (who as PlayerSwim).surface_y + 140.0 if who is PlayerSwim else -INF
		who.global_position = Vector2(at.x, maxf(s.position.y + 70.0, top))
		who.velocity = Vector2.ZERO
	if reforms and is_instance_valid(s):
		if in_water:  # he comes back where the scribble has floated to: his sprite exactly on it
			who.global_position += s.global_position - who.sprite.global_position
			who.velocity = Vector2.ZERO
	var k := 0.0
	if reforms and is_instance_valid(s):
		k = s.get_meta("k")
		s.queue_free()  # the animation starts as this same frame, at this size
	else:
		clear(s)
	who.visible = true
	var d := who.sprite.reform(k) if reforms else 0.0  # the scribble pulls back together into him
	if d > 0.0:
		var was := Game.control_locked
		Game.control_locked = true
		Game.sfx("unbristle", -8.0, 1.15)
		await level.get_tree().create_timer(d).timeout
		if not is_instance_valid(who):
			return told
		Game.control_locked = was
	else:
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


## In the pond the grey scribble is lost among the plants: it takes the blue Blobb has under
## water (a flat colour over the scribble's own shape, a little more opaque), with a soft shadow.
const WATER_BLUE := Color(0.59, 0.73, 0.94)
const FLAT := "shader_type canvas_item;\nuniform vec4 tint : source_color;\nuniform float boost = 1.0;\nvoid fragment() { COLOR = vec4(tint.rgb, clamp(texture(TEXTURE, UV).a * boost, 0.0, 1.0) * tint.a); }"

static func _water_look(s: Sprite2D) -> void:
	var sh := Shader.new()
	sh.code = FLAT
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", WATER_BLUE)
	m.set_shader_parameter("boost", 1.8)
	s.material = m
	var shadow := Sprite2D.new()
	shadow.texture = s.texture
	shadow.position = Vector2(3, 4) / (s.scale.x * 5.0)  # about (3, 4) px once it has popped to full size
	shadow.show_behind_parent = true
	var ms := ShaderMaterial.new()
	ms.shader = sh
	ms.set_shader_parameter("tint", Color(0.0, 0.02, 0.06, 0.5))
	ms.set_shader_parameter("boost", 1.8)
	shadow.material = ms
	s.add_child(shadow)


## The reform strip's first frame (the scribble), over Blobb's sprite, `height` px tall, through his
## tint and facing his way. Meta "k": its size against his, for BlobbSprite.reform().
static func _reform_start(level: Node, who: BlobbBody, height: float) -> Sprite2D:
	var bs := who.sprite
	var sp := Sprite2D.new()
	sp.texture = bs.sprite_frames.get_frame_texture("reform", 0)
	sp.material = bs.material
	sp.flip_h = bs.flip_h
	sp.z_index = 5
	level.add_child(sp)
	sp.global_position = bs.global_position
	var gs := absf(bs.global_scale.y)
	var k := maxf(height / (BlobbSprite.FRAME_H * 0.9 * gs), 1.0)
	sp.set_meta("k", k)
	var full := Vector2.ONE * gs * k
	sp.scale = full * 0.2
	sp.create_tween().tween_property(sp, "scale", full, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return sp


static func clear(s: Sprite2D) -> void:
	if not is_instance_valid(s):
		return
	var tw := s.create_tween()
	tw.tween_property(s, "scale", s.scale * 1.15, 0.12)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)
