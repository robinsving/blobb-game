class_name PuzzleMarks
extends RefCounted
## Marks shared by the puzzle rooms (mill, roofs): numbered badges that pair a control with
## what it moves, and rings around a cell.


## A round badge of radius `r` with a number on it.
static func badge(num: String, col: Color, r := 24.0) -> Node2D:
	var b := Node2D.new()
	b.z_index = 6
	b.draw.connect(func() -> void:
		b.draw_circle(Vector2.ZERO, r, Color(0.08, 0.08, 0.08))
		b.draw_circle(Vector2.ZERO, r - 4.0, col))
	var lab := Label.new()
	lab.text = num
	lab.add_theme_font_size_override("font_size", int(r) + 4)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lab.add_theme_constant_override("outline_size", 7)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size = Vector2(r, r) * 2.0
	lab.position = Vector2(-r, -r - 1.0)
	b.add_child(lab)
	return b


## A ring of `radius` round `pos`.
static func ring(pos: Vector2, radius: float, col: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.default_color = col
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(pos + Vector2(cos(a), sin(a)) * radius)
	l.points = pts
	l.z_index = 2
	return l
