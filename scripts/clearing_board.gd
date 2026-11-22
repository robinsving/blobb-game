extends Node2D
## Draws a top-down SokobanGrid room: forest canopy around it, grass, stumps/hedges, water, bridges,
## stone plates, the gate and the exit path. Uses generated textures from assets/gen/ch1/ when present.

const GROUND_TEX := "res://assets/gen/ch1/clearing_topdown_ground.png"
const STUMP_TEX := "res://assets/gen/ch1/stump_topdown.png"

var grid: SokobanGrid
var origin := Vector2.ZERO
var cell := 96
var _ground: Texture2D
var _stump: Texture2D
## Crayon bush art (bush_topdown_a/b/c.png, or one bush_topdown.png), if generated.
var _bushes: Array[Texture2D] = []
var _t := 0.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if ResourceLoader.exists(GROUND_TEX):
		_ground = load(GROUND_TEX)
	if ResourceLoader.exists(STUMP_TEX):
		_stump = load(STUMP_TEX)
	for n in ["bush_topdown_a", "bush_topdown_b", "bush_topdown_c", "bush_topdown"]:
		var path := "res://assets/gen/ch1/%s.png" % n
		if ResourceLoader.exists(path):
			_bushes.append(load(path))


func _process(delta: float) -> void:
	_t += delta
	if not grid.water.is_empty() or not grid.bridges.is_empty():
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# canopy around the room
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.12, 0.24, 0.1))
	for i in 26 * 15:
		@warning_ignore("integer_division")
		var p := Vector2((i % 26) * 78 - 40, (i / 26) * 78 - 40) + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		var r := rng.randf_range(50, 90)
		var g := rng.randf_range(0.22, 0.42)
		if _bushes:
			_bush(p, r * 1.15, Color(0.5, 0.62, 0.42) * (g / 0.42), rng)  # the canopy sits back, darker
			continue
		draw_circle(p, r, Color(g * 0.45, g, g * 0.3))
		draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.5, Color(g * 0.55, g * 1.2, g * 0.35))
	# exit path off to the right edge
	if grid.exit_cell.x >= 0:
		var ep := _rect(grid.exit_cell)
		draw_rect(Rect2(ep.position, Vector2(1920 - ep.position.x, cell)), Color(0.55, 0.42, 0.25))
	# cells
	for y in grid.height:
		for x in grid.width:
			var p := Vector2i(x, y)
			if _is_void(p):
				continue
			var r := _rect(p)
			_draw_floor(r, rng)
			if grid.walls.has(p):
				if _is_border(p):
					_draw_hedge(r, rng)
				else:
					_draw_stump(r, rng)
			elif grid.water.has(p) or grid.bridges.has(p):
				_draw_water(r, p)
				if grid.bridges.has(p):
					_draw_bridge(r)
			if grid.plates.has(p):
				_draw_plate(r, grid.crates.has(p))
			if p == grid.gate:
				_draw_gate(r, grid.gate_open())


func _rect(p: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(p) * cell, Vector2(cell, cell))


func _is_void(p: Vector2i) -> bool:
	return grid.walls.has(p) and _raw_void(p)


## A wall cell counts as "void" (canopy) when it is outside the room: on the outside of the border.
## We approximate: walls with no floor neighbour (8-dir) are void.
func _raw_void(p: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if q.x < 0 or q.y < 0 or q.x >= grid.width or q.y >= grid.height:
				continue
			if not grid.walls.has(q):
				return false
	return true


func _is_border(p: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var q := p + Vector2i(dx, dy)
			if q.x < 0 or q.y < 0 or q.x >= grid.width or q.y >= grid.height:
				return true
			if grid.walls.has(q) and _raw_void(q):
				return true
	return false


func _draw_floor(r: Rect2, rng: RandomNumberGenerator) -> void:
	if _ground:
		# texture_repeat is enabled, so sampling at absolute coords tiles seamlessly
		draw_texture_rect_region(_ground, r, Rect2(r.position * 0.8, r.size * 0.8))
		return
	var g := rng.randf_range(0.0, 0.05)
	draw_rect(r, Color(0.45 + g, 0.68 + g, 0.28))
	for i in 7:
		var p := r.position + Vector2(rng.randf_range(6, cell - 6), rng.randf_range(10, cell - 4))
		draw_line(p, p + Vector2(rng.randf_range(-5, 5), -rng.randf_range(8, 16)), Color(0.3, 0.52, 0.18), 2.5)
	if rng.randf() < 0.12:
		var fp := r.position + Vector2(rng.randf_range(20, cell - 20), rng.randf_range(20, cell - 20))
		for k in 5:
			var a := TAU * k / 5.0
			draw_circle(fp + Vector2(cos(a), sin(a)) * 5.0, 4.0, Color(1, 0.95, 0.6))
		draw_circle(fp, 3.0, Color(1, 0.7, 0.1))


## One bush texture centred at p with radius r, multiplied by col (the art is bright), flipped at random.
func _bush(p: Vector2, r: float, col: Color, rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = _bushes[rng.randi() % _bushes.size()]
	var flip := -1.0 if rng.randf() < 0.5 else 1.0
	draw_set_transform(p, rng.randf_range(-0.4, 0.4), Vector2(flip, 1))
	draw_texture_rect(tex, Rect2(-r, -r, r * 2, r * 2), false, Color(col, 1.0))
	draw_set_transform(Vector2.ZERO)


func _draw_hedge(r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	if _bushes:
		_bush(c + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)), cell * 0.62, Color(0.72, 0.85, 0.6), rng)
		return
	for i in 4:
		var off := Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24))
		var g := rng.randf_range(0.28, 0.4)
		draw_circle(c + off, rng.randf_range(30, 42), Color(g * 0.45, g, g * 0.3))
	draw_circle(c + Vector2(-10, -12), 18, Color(0.25, 0.5, 0.18))


func _draw_stump(r: Rect2, rng: RandomNumberGenerator) -> void:
	var c := r.get_center()
	if _stump:
		var s := cell * 0.95
		draw_texture_rect(_stump, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	draw_circle(c + Vector2(4, 6), 40, Color(0, 0, 0, 0.25))
	draw_circle(c, 40, Color(0.45, 0.28, 0.15))
	draw_circle(c, 33, Color(0.82, 0.66, 0.42))
	for k in [24, 16, 8]:
		draw_arc(c + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), k, 0, TAU, 24, Color(0.6, 0.42, 0.24), 2.5)


func _draw_water(r: Rect2, p: Vector2i) -> void:
	draw_rect(r, Color(0.25, 0.5, 0.78))
	for k in 3:
		var y := r.position.y + 20 + k * 28 + sin(_t * 2.0 + p.x + k) * 4.0
		var x0 := r.position.x + 10 + fmod(_t * 18.0 + k * 31 + p.y * 13, 30.0)
		draw_line(Vector2(x0, y), Vector2(x0 + 34, y), Color(0.65, 0.82, 1.0, 0.7), 3.0)


func _draw_bridge(r: Rect2) -> void:
	var inner := r.grow(-8)
	inner.position.y += sin(_t * 2.0 + r.position.x) * 2.0
	draw_rect(inner, Color(0.6, 0.42, 0.22))
	for k in 4:
		var y := inner.position.y + inner.size.y * (k + 0.5) / 4.0
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(0.38, 0.24, 0.1), 3.0)
	draw_rect(inner, Color(0.3, 0.18, 0.08), false, 3.0)


func _draw_plate(r: Rect2, covered: bool) -> void:
	var c := r.get_center()
	if covered:
		draw_circle(c, 46, Color(1.0, 0.85, 0.3, 0.45))
	draw_circle(c, 34, Color(0.55, 0.55, 0.52))
	draw_circle(c, 28, Color(0.7, 0.7, 0.66))
	draw_arc(c, 34, 0, TAU, 28, Color(0.3, 0.3, 0.3), 3.0)
	# moss specks
	draw_circle(c + Vector2(-12, 10), 6, Color(0.4, 0.6, 0.25))
	draw_circle(c + Vector2(14, -8), 4, Color(0.4, 0.6, 0.25))


func _draw_gate(r: Rect2, open: bool) -> void:
	var dark := Color(0.32, 0.2, 0.1)
	var wood := Color(0.55, 0.36, 0.18)
	if open:
		for k in 2:
			var y := r.position.y + 6 + k * (cell - 22)
			draw_rect(Rect2(r.position.x + 10, y, cell - 20, 16), wood)
			draw_rect(Rect2(r.position.x + 10, y, cell - 20, 16), dark, false, 2.0)
		return
	for k in 4:
		var x := r.position.x + 8 + k * 21
		draw_rect(Rect2(x, r.position.y + 2, 17, cell - 4), wood)
		draw_rect(Rect2(x, r.position.y + 2, 17, cell - 4), dark, false, 2.0)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 24, cell - 4, 12), dark)
	draw_rect(Rect2(r.position.x + 2, r.position.y + cell - 36, cell - 4, 12), dark)
