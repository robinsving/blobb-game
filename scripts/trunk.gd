extends Node2D
## A tall crayon tree trunk drawn upward from its origin (origin = ground level at the trunk's left edge).

const WIDTH := 110.0
const HEIGHT := 760.0
const ART := "res://assets/gen/ch1/tree_trunk.png"

## Crayon trunk art, if generated; without it the trunk is drawn in code.
var _tex: Texture2D


func _ready() -> void:
	if ResourceLoader.exists(ART):
		_tex = load(ART)


func _draw() -> void:
	if _tex:
		# fit the height (plus a little root below ground), centred on the trunk
		var h := HEIGHT + 20.0
		var w := h * _tex.get_width() / _tex.get_height()
		draw_texture_rect(_tex, Rect2(WIDTH * 0.5 - w * 0.5, -HEIGHT, w, h), false)
		return
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
