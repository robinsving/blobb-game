class_name Terrain
extends Node2D
## Procedurally drawn side-view ground (grass top, dirt fill, crayon hatching) plus matching collision.
## Built from tile rectangles; restyle with set_palette() (narrator-driven look changes).

const TILE := 64

const PALETTES := {
	"crayon": {"dirt": Color(0.55, 0.36, 0.2), "dirt_dark": Color(0.4, 0.24, 0.12), "grass": Color(0.42, 0.72, 0.22),
		"grass_dark": Color(0.25, 0.5, 0.12), "hatch": Color(0.3, 0.17, 0.08, 0.55), "flower": true},
	"dark": {"dirt": Color(0.12, 0.1, 0.09), "dirt_dark": Color(0.06, 0.05, 0.05), "grass": Color(0.15, 0.24, 0.13),
		"grass_dark": Color(0.08, 0.13, 0.07), "hatch": Color(0.0, 0.0, 0.0, 0.3), "flower": false},
	"evening": {"dirt": Color(0.5, 0.28, 0.2), "dirt_dark": Color(0.33, 0.16, 0.12), "grass": Color(0.55, 0.62, 0.2),
		"grass_dark": Color(0.36, 0.42, 0.12), "hatch": Color(0.25, 0.1, 0.06, 0.55), "flower": true},
}

var rects: Array[Rect2i] = []        # in tiles
var palette: Dictionary = PALETTES["crayon"]
var _seed := 1234


## Adds a solid block of tiles. x0..x1 inclusive, rows top..bottom inclusive.
func add_block(x0: int, x1: int, top: int, bottom: int) -> void:
	var r := Rect2i(x0, top, x1 - x0 + 1, bottom - top + 1)
	rects.append(r)
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(r.size) * TILE
	cs.shape = shape
	cs.position = (Vector2(r.position) + Vector2(r.size) * 0.5) * TILE
	body.add_child(cs)
	add_child(body)
	queue_redraw()


func set_palette(name: String) -> void:
	palette = PALETTES[name]
	queue_redraw()


func _draw() -> void:
	for r in rects:
		_draw_block(r)


func _draw_block(r: Rect2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + r.position.x * 131 + r.position.y * 17
	var px := Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)
	# dirt with a wobbly outline
	var pts := PackedVector2Array()
	var steps := maxi(2, r.size.x * 2)
	for i in steps + 1:
		pts.append(Vector2(px.position.x + px.size.x * i / steps, px.position.y + rng.randf_range(-3, 5)))
	pts.append(Vector2(px.end.x + rng.randf_range(-3, 3), px.end.y))
	pts.append(Vector2(px.position.x + rng.randf_range(-3, 3), px.end.y))
	draw_colored_polygon(pts, palette["dirt"])
	# darker lower band
	draw_rect(Rect2(px.position + Vector2(0, 70), Vector2(px.size.x, maxf(0, px.size.y - 70))), palette["dirt_dark"])
	# crayon hatching
	var hatch: Color = palette["hatch"]
	var n := int(px.size.x * px.size.y / 900.0)
	for i in n:
		var p := Vector2(rng.randf_range(px.position.x + 4, px.end.x - 4), rng.randf_range(px.position.y + 26, px.end.y))
		var l := rng.randf_range(10, 26)
		draw_line(p, p + Vector2(l, -l * 0.6), hatch, rng.randf_range(1.5, 3.0))
	# grass cap with blades
	var gy := px.position.y
	draw_rect(Rect2(px.position.x - 4, gy - 4, px.size.x + 8, 22), palette["grass"])
	var x := px.position.x - 4
	while x < px.end.x + 4:
		var h := rng.randf_range(8, 22)
		var w := rng.randf_range(5, 10)
		var col: Color = palette["grass"] if rng.randf() < 0.6 else palette["grass_dark"]
		draw_colored_polygon(PackedVector2Array([Vector2(x, gy + 2), Vector2(x + w * 0.5 + rng.randf_range(-3, 3), gy - h), Vector2(x + w, gy + 2)]), col)
		x += w * rng.randf_range(0.5, 0.9)
	draw_line(Vector2(px.position.x - 4, gy + 18), Vector2(px.end.x + 4, gy + 18), palette["grass_dark"], 3.0)
	# flowers and pebbles
	if palette["flower"] and r.size.x >= 3:
		var flowers := r.size.x / 3
		for i in flowers:
			var fx := rng.randf_range(px.position.x + 10, px.end.x - 10)
			var fc: Color = [Color(1, 0.85, 0.2), Color(0.95, 0.4, 0.5), Color(0.9, 0.95, 1.0), Color(0.6, 0.5, 1.0)][rng.randi() % 4]
			draw_line(Vector2(fx, gy), Vector2(fx, gy - 18), palette["grass_dark"], 2.0)
			for k in 5:
				var a := TAU * k / 5.0
				draw_circle(Vector2(fx, gy - 20) + Vector2(cos(a), sin(a)) * 5.0, 4.0, fc)
			draw_circle(Vector2(fx, gy - 20), 3.0, Color(1, 0.7, 0.1))
