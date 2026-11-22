class_name ChapterCard
extends RefCounted
## Chapter cards on layer 101: "Chapter N" and its name at the start of a chapter
## (ChapterCard.title), and the closing line at its end (ChapterCard.closing).


## "Chapter N" + the chapter's name, over `bg` (transparent = over the scene), then it all fades away.
static func title(parent: Node, n: int, color: Color, bg := Color(0, 0, 0, 0)) -> void:
	await _show(parent, [[Game.t("chapter_%d" % n), 44, Fonts.serif()], [Game.t("chapter_%d_name" % n), 96, Fonts.hand()]],
		color, bg, 0.0, 0.5 if Game.fast else 3.0, true)


## The closing line ("End of chapter one."), on `bg` faded in over `bg_in` s. It stays up:
## the level goes to the title screen afterwards.
static func closing(parent: Node, key: String, color: Color, bg := Color(0, 0, 0, 0), bg_in := 0.0, hold := 3.5) -> void:
	await _show(parent, [[Game.t(key), 44, Fonts.serif()]], color, bg, bg_in, 0.5 if Game.fast else hold, false)


static func _show(parent: Node, lines: Array, color: Color, bg: Color, bg_in: float, hold: float, fade_out: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 101
	parent.add_child(layer)
	var back := ColorRect.new()
	back.color = bg
	back.size = Vector2(1920, 1080)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(back)
	if bg_in > 0.0:
		back.modulate.a = 0.0
		await parent.create_tween().tween_property(back, "modulate:a", 1.0, bg_in).finished
	var box := VBoxContainer.new()
	box.position = Vector2(0, 430)
	box.size = Vector2(1920, 240)
	box.add_theme_constant_override("separation", 18)
	layer.add_child(box)
	for spec in lines:
		var l := Label.new()
		l.text = spec[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", spec[2])
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", color)
		l.modulate.a = 0.0
		box.add_child(l)
	var tw := parent.create_tween()
	for l in box.get_children():
		tw.tween_property(l, "modulate:a", 1.0, 1.4)
	tw.tween_interval(hold)
	if fade_out:
		tw.tween_property(box, "modulate:a", 0.0, 1.5)
		tw.tween_property(back, "modulate:a", 0.0, 1.5)
	await tw.finished
	if fade_out:
		layer.queue_free()
