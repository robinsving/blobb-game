class_name LevelKit
extends RefCounted
## Building blocks shared by the levels (all static): column areas for story beats and
## checkpoints, solid blocks, ground lookups, a sky gradient, the follow camera, small sounds.


## An Area2D covering tile column `col`, from far above the level to far below it.
static func column_area(parent: Node, col: int, tile: float, height: float) -> Area2D:
	var a := Area2D.new()
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(tile, height * 2.0)
	cs.shape = r
	cs.position = Vector2(col * tile + tile * 0.5, 0)
	a.add_child(cs)
	parent.add_child(a)
	return a


## Story beats by column: the first time `who` walks into a column of `triggers` ({col: "scene"}),
## the scene is marked in `fired` and `beat` is called with its name. While `paused` returns true
## (a retell), nothing fires.
static func story_columns(level: Node, who: Node, triggers: Dictionary, fired: Dictionary, tile: float,
		height: float, beat: Callable, paused := func() -> bool: return false) -> void:
	for col in triggers:
		var scene: String = triggers[col]
		column_area(level, col, tile, height).body_entered.connect(func(b: Node) -> void:
			if b == who and not fired.has(scene) and not paused.call():
				fired[scene] = true
				beat.call(scene))


## Checkpoints by column: when `who` walks into one, `reached` is called with `spot.call(col)`
## (where he comes back after a retell), and the game is saved there (Game.checkpoint: Continue
## starts at that column; not the first one, where he starts anyway, so the intro isn't skipped).
## Not while `paused` returns true.
static func checkpoint_columns(level: Node, who: Node, cols: Array, tile: float, height: float,
		spot: Callable, reached: Callable, paused := func() -> bool: return false) -> void:
	for col in cols:
		var pos: Vector2 = spot.call(col)
		column_area(level, col, tile, height).body_entered.connect(func(b: Node) -> void:
			if b == who and not paused.call():
				reached.call(pos)
				if col != cols[0]:
					Game.checkpoint(col))


## A solid block in pixels (`one_way`: only stood on from above).
static func solid(parent: Node, rect: Rect2, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	cs.one_way_collision = one_way
	body.add_child(cs)
	parent.add_child(body)
	return body


## A solid block of tiles: columns x0..x1 and rows top..bottom, inclusive.
static func solid_tiles(parent: Node, x0: int, x1: int, top: int, bottom: int, tile: float) -> StaticBody2D:
	return solid(parent, Rect2(x0 * tile, top * tile, (x1 - x0 + 1) * tile, (bottom - top + 1) * tile))


## The top row at `col` from tables of [x0, x1, top_row, ...] spans (the first table that has
## the column wins), or `fallback`.
static func top_row(tables: Array, col: int, fallback: int) -> int:
	for t in tables:
		for s in t:
			if col >= s[0] and col <= s[1]:
				return s[2]
	return fallback


## A full-screen vertical gradient (three colours: top, at 65 %, bottom), for skies.
static func gradient_rect(cols: Array) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	g.colors = PackedColorArray(cols)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = Vector2(1920, 1080)
	return r


## The side-view camera: follows `who` with a little horizontal drag, kept inside the level.
static func follow_camera(who: Node, size: Vector2, smoothing := 5.0, top := 0.0, offset := Vector2(0, -120)) -> Camera2D:
	var c := Camera2D.new()
	c.position_smoothing_enabled = true
	c.position_smoothing_speed = smoothing
	c.limit_left = 0
	c.limit_right = int(size.x)
	c.limit_top = int(top)
	c.limit_bottom = int(size.y)
	c.drag_horizontal_enabled = true
	c.drag_left_margin = 0.1
	c.drag_right_margin = 0.1
	c.offset = offset
	who.add_child(c)
	return c


## Drips now and then for as long as `level` is in the tree (the pond and the mill).
static func drip_loop(level: Node) -> void:
	while is_instance_valid(level) and level.is_inside_tree():
		await level.get_tree().create_timer(randf_range(2.5, 5.0)).timeout
		if not is_instance_valid(level) or not level.is_inside_tree():
			return  # the level was left (and freed) while waiting
		Game.sfx("drip", -20.0, randf_range(0.95, 1.05))


## A quick hop (the warden's whistle).
static func hop(n: Node2D, height := 18.0) -> void:
	var y := n.position.y
	var tw := n.create_tween()
	tw.tween_property(n, "position:y", y - height, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", y, 0.15).set_ease(Tween.EASE_IN)
