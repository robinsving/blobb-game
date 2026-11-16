extends Node2D
## A tall crayon tree trunk drawn upward from its origin (origin = ground level at the trunk's left edge).

const WIDTH := 110.0
const HEIGHT := 760.0


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var bark := Color(0.42, 0.27, 0.16)
	var dark := Color(0.28, 0.17, 0.09)
	var pts := PackedVector2Array([
		Vector2(-30, 0), Vector2(0, -60), Vector2(6, -HEIGHT), Vector2(WIDTH - 6, -HEIGHT),
		Vector2(WIDTH, -60), Vector2(WIDTH + 34, 0)])
	draw_colored_polygon(pts, bark)
	for i in 40:
		var x := rng.randf_range(8, WIDTH - 8)
		var y := rng.randf_range(-HEIGHT + 10, -20)
		draw_line(Vector2(x, y), Vector2(x + rng.randf_range(-4, 4), y - rng.randf_range(30, 80)), dark, rng.randf_range(2, 4))
	draw_polyline(pts, dark, 4.0)
	# a knot hole
	draw_circle(Vector2(WIDTH * 0.55, -HEIGHT * 0.35), 14, dark)
