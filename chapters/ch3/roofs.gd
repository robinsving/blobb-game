extends Node2D
## Chapter 3, part 2: the rooftops, where light is solid. Three rooms (chapters/ch3/beam_rooms.gd,
## rules in scripts/beam_room.gd): Blobb turns cranks that swing the rooftop lamps, and every
## beam (but one shining straight up) becomes a bridge or a ramp he can stand on. Turning a lamp he is standing on
## drops him. Falling off the roofs is a retell. After room 3 the pigeons wake (chase.tscn).
## Dialogue: chapters/ch3/story.txt. Art: assets/gen/ch3/ (everything has a drawn fallback).

const ROOMS: Array = preload("res://chapters/ch3/beam_rooms.gd").ROOMS
const CELL := 128.0
const ORIGIN := Vector2(0, 56)
const ART := "res://assets/gen/ch3/"
const NEXT_SCENE := "res://chapters/ch3/chase.tscn"
const BEAM_W := 30.0
const LIGHT := Color(1.0, 0.86, 0.5)
## each crank and its lamp share a colour and a number (as in the ch2 mill)
const PAIR_COLORS := [Color(0.95, 0.3, 0.25), Color(0.25, 0.6, 1.0), Color(0.4, 0.85, 0.35),
	Color(0.85, 0.4, 0.95), Color(1.0, 0.55, 0.15), Color(1.0, 0.8, 0.2)]

var room: BeamRoom
var room_i := 0
var player: PlayerSide
var fx: StyleFX
var _room_node: Node2D
var _beam_node: Node2D        # beams are drawn here
var _overlay: Node2D          # the line from the crank in reach to its lamp
var _beam_bodies: Node2D
var _lamp_nodes := {}         # letter -> Node2D (rotated to the beam's direction)
var _crank_nodes := {}        # Vector2i -> Node2D
var _pair_col := {}
var _pair_num := {}
var _lamp_badges := {}
var _pigeons: Array[Sprite2D] = []
var _solid_light := false
var _busy := true
var _done := false
var _retelling := false
var _restart_told := false
var _fail_count := 0
var _linked := Vector2i(-1, -1)
var _t := 0.0
var _room_gen := 0
var story := StoryScript.load_file("res://chapters/ch3/story.txt")


func _ready() -> void:
	Game.music("res://assets/audio/music_city.ogg", -16.0)
	_build_scenery()
	fx = StyleFX.new()
	fx.set_look("real", 0.0)
	fx.tint(Color(0.6, 0.7, 1.0), 0.22, 0.0)
	add_child(fx)
	var first := clampi(Game.warp - 1, 0, ROOMS.size() - 1) if Game.warp > 0 else 0
	_load_room(first)
	if first > 0:
		_solid_light = true
		_refresh_beams()
	_room_intro()


func _room_intro() -> void:
	_busy = true
	await get_tree().create_timer(0.6).timeout
	match room_i:
		0:
			await story.play("roofs", self)
		1:
			await story.play("room2", self)
		2:
			await story.play("room3", self)
	_busy = false
	Narrator.legend("hint_roofs")
	if room_i == 0:  # the big hint too, so the new key isn't only in the faint line at the bottom
		Narrator.hint(Game.t("hint_roofs_use"), 7.0)
	if Game.autoplay:
		_autoplay()


# ================================================================ story effects

func fx_solid_light() -> void:
	_solid_light = true
	Game.sfx("lamp_on", -6.0, 0.8)
	_refresh_beams()


func fx_birds_wake() -> void:
	Game.sfx("flap", -4.0)
	Game.sfx("coo", -8.0, 0.8)
	for p in _pigeons:
		var tw := create_tween()
		var fly := ART + "pigeon_fly.png"
		if ResourceLoader.exists(fly):
			var k: float = p.scale.x * p.texture.get_height()
			p.texture = load(fly)
			p.scale = Vector2.ONE * k / p.texture.get_height()
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-400, 200), -900), randf_range(1.2, 1.8)).set_ease(Tween.EASE_IN)


# ================================================================ per frame

func _process(delta: float) -> void:
	_t += delta
	_pulse()
	if _busy or _done or _retelling or Game.control_locked:
		return
	if room.solved_by(_player_cell()) and player.is_on_floor():
		_solved()
		return
	if Game.autoplay:
		return
	if Input.is_action_just_pressed("use"):  # not Space, so turning a crank never makes Blobb jump
		var c := _crank_in_reach()
		if c != Vector2i(-1, -1):
			_turn(c)
	elif Input.is_action_just_pressed("restart"):
		_restart()


func _physics_process(_delta: float) -> void:
	if player and player.global_position.y > 1080 + 160 and not _retelling and not _done:
		_fail()


func _player_cell() -> Vector2i:
	var v := (player.global_position + Vector2(0, -40) - ORIGIN) / CELL
	return Vector2i(floori(v.x), floori(v.y))


## The crank in the cell Blobb is standing in (the same rule the solver uses: on the floor, in
## that column, body in that cell), or (-1, -1). No turning cranks mid-jump or from next door.
func _crank_in_reach() -> Vector2i:
	if not player.is_on_floor():
		return Vector2i(-1, -1)
	var c := _player_cell()
	return c if room.cranks.has(c) else Vector2i(-1, -1)


func _turn(c: Vector2i) -> void:
	room.press(c)
	var n: Node2D = _crank_nodes[c]
	Game.sfx("crank", -4.0)
	create_tween().tween_property(n, "rotation", n.rotation + PI * 0.5, 0.25).set_trans(Tween.TRANS_BACK)
	_update_lamp(room.cranks[c])
	_refresh_beams()


func _restart() -> void:
	_load_room(room_i)
	Game.sfx("whoosh", -10.0)
	if not _restart_told:
		_restart_told = true
		story.play("restart", self)


func _fail() -> void:
	_retelling = true
	_load_room(room_i)  # the whole roof starts over, lamps too (or it could be solved the wrong way)
	var start := _stand_pos(room.start_pos(room.states()))
	if await Retell.tell(self, story, fx, player, start, _fail_count):
		_fail_count += 1
	_retelling = false


func _solved() -> void:
	_busy = true
	Game.control_locked = true
	Narrator.legend("")
	Game.sfx("chime", -6.0)
	if room_i < ROOMS.size() - 1:
		await get_tree().create_timer(0.8).timeout
		await Game.fade_out(Color(0.02, 0.03, 0.08), 0.8)
		_load_room(room_i + 1)
		Game.fade_in(0.8)
		Game.control_locked = false
		_room_intro()
		return
	_done = true
	await story.play("birds", self)
	await get_tree().create_timer(1.0).timeout
	Game.go(NEXT_SCENE, Color(0.02, 0.03, 0.08), 0.6)


# ================================================================ room building

func _load_room(i: int) -> void:
	Game.checkpoint(i + 1 if i > 0 else -1)  # a save point: Continue starts on this roof
	room_i = i
	_room_gen += 1
	for n in [_room_node, _beam_node, _overlay, _beam_bodies]:
		if n:
			n.queue_free()
	_lamp_nodes.clear()
	_crank_nodes.clear()
	_lamp_badges.clear()
	_pigeons.clear()
	room = BeamRoom.from_room(ROOMS[i])
	_room_node = Node2D.new()
	add_child(_room_node)
	_beam_node = Node2D.new()
	_beam_node.z_index = 1
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam_node.material = add
	_beam_node.draw.connect(_draw_beams.bind(_beam_node))  # bound: an old node being freed on a restart draws on itself
	add_child(_beam_node)
	_beam_bodies = Node2D.new()
	add_child(_beam_bodies)
	_overlay = Node2D.new()
	_overlay.z_index = 5
	_overlay.draw.connect(_draw_link.bind(_overlay))
	add_child(_overlay)

	_pair_col.clear()
	_pair_num.clear()
	var keys := room.cranks.keys()
	keys.sort()
	for k in keys:
		var l: String = room.cranks[k]
		_pair_col[l] = PAIR_COLORS[_pair_col.size() % PAIR_COLORS.size()]
		_pair_num[l] = room.rows[k.y][k.x]

	_draw_roofs()
	for y in room.height:
		for x in room.width:
			var ch: String = room.rows[y][x]
			if ch == "#" or ch == "H" or BeamRoom.LAMP_LETTERS.contains(ch):
				_solid_cell(Vector2i(x, y))
			if ch == "H":
				_chimney(Vector2i(x, y))
	for l in room.lamps:
		_lamp(l)
	for c in room.cranks:
		_crank(c)
	_goal(room.goal)
	_place_pigeons()

	if not player:
		player = PlayerSide.new()
		player.name = "Player"  # a stable path for gda: /root/<Level>/Player
		player.jump_velocity = PlayerSide.STRONG_JUMP
		player.use_bot = false  # roofs have their own bot (_autoplay)
		player.floor_max_angle = deg_to_rad(50.0)  # the diagonal beams are 45-degree ramps
		player.z_index = 3
		add_child(player)
		player.sprite.set_tint(BlobbSprite.GREEN, BlobbSprite.GREEN_AMOUNT, 0.0)
	player.teleport(_stand_pos(room.start_pos(room.states())))
	_refresh_beams()


func _cell_pos(p: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(p) + Vector2(0.5, 0.5)) * CELL


## Pixel position of a model position (column, height in half cells).
func _stand_pos(p: Vector2i) -> Vector2:
	return Vector2((p.x + 0.5) * CELL, ORIGIN.y + p.y * CELL * 0.5 - 12.0)  # just above (beams are 14 px thick)


func _solid_cell(p: Vector2i) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL, CELL)
	cs.shape = shape
	body.position = _cell_pos(p)
	body.add_child(cs)
	_room_node.add_child(body)


## Roof blocks: slate on top, dark brick below, a few lit attic windows.
func _draw_roofs() -> void:
	var n := Node2D.new()
	n.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the wall and cap tiles are sampled in world pixels
	_room_node.add_child(n)
	var r := room
	var wall: Texture2D = load(ART + "roof_wall_tile.png") if ResourceLoader.exists(ART + "roof_wall_tile.png") else null
	var cap: Texture2D = load(ART + "roof_cap.png") if ResourceLoader.exists(ART + "roof_cap.png") else null
	var window: Texture2D = load(ART + "attic_window.png") if ResourceLoader.exists(ART + "attic_window.png") else null
	n.draw.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + room_i
		for x in r.width:
			for y in r.height:
				if r.rows[y][x] != "#":
					continue
				var rect := Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL))
				var top: bool = y == 0 or r.rows[y - 1][x] != "#"
				if wall:
					n.draw_texture_rect_region(wall, rect, rect)
					if top and cap:
						var c := Rect2(rect.position + Vector2(-4, -12), Vector2(CELL + 8, 48))
						n.draw_texture_rect_region(cap, c, Rect2(c.position.x, 0, c.size.x, cap.get_height()))
					elif not top and window and rng.randf() < 0.18:
						n.draw_texture_rect(window, Rect2(rect.position + Vector2(40, 34), Vector2(48, 60)), false)
					continue
				n.draw_rect(rect, Color(0.17, 0.15, 0.2))
				# brick courses
				for k in 6:
					n.draw_line(rect.position + Vector2(0, k * 22 + 10), rect.position + Vector2(CELL, k * 22 + 10), Color(0.12, 0.1, 0.14), 2.0)
				if top:
					n.draw_rect(Rect2(rect.position + Vector2(-4, 0), Vector2(CELL + 8, 26)), Color(0.3, 0.34, 0.44))
					n.draw_rect(Rect2(rect.position + Vector2(-4, 0), Vector2(CELL + 8, 6)), Color(0.55, 0.6, 0.72))
				elif rng.randf() < 0.18:
					n.draw_rect(Rect2(rect.position + Vector2(44, 40), Vector2(40, 52)), Color(1.0, 0.8, 0.45)))


func _chimney(p: Vector2i) -> void:
	var pos := _cell_pos(p)
	if ResourceLoader.exists(ART + "chimney.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "chimney.png")
		var k := CELL * 1.05 / s.texture.get_height()
		s.scale = Vector2(k, k)
		s.position = pos
		_room_node.add_child(s)
		return
	var n := Node2D.new()
	n.position = pos
	n.draw.connect(func():
		n.draw_rect(Rect2(-44, -64, 88, 128), Color(0.45, 0.22, 0.17))
		for k in 5:
			n.draw_line(Vector2(-44, -64 + k * 26), Vector2(44, -64 + k * 26), Color(0.3, 0.15, 0.12), 3.0)
		n.draw_rect(Rect2(-52, -64, 104, 16), Color(0.3, 0.16, 0.13))
		n.draw_rect(Rect2(-18, -84, 36, 22), Color(0.5, 0.3, 0.22)))
	_room_node.add_child(n)


## A lamp on its swivel. It stands on the roof, or on an iron post when it's out over a gap.
func _lamp(l: String) -> void:
	var cell: Vector2i = room.lamps[l]["pos"]
	_post_below(cell)
	var n := Node2D.new()
	n.position = _cell_pos(cell)
	n.z_index = 2
	_room_node.add_child(n)
	n.draw.connect(func():
		n.draw_circle(Vector2.ZERO, 30.0, Color(0.12, 0.12, 0.15))
		n.draw_rect(Rect2(-22, 26, 44, 38), Color(0.12, 0.12, 0.15)))
	var head := Node2D.new()
	n.add_child(head)
	if ResourceLoader.exists(ART + "roof_lamp.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "roof_lamp.png")
		var k := CELL * 0.95 / maxf(s.texture.get_width(), s.texture.get_height())
		s.scale = Vector2(k, k)
		head.add_child(s)
	else:
		head.draw.connect(func():
			head.draw_rect(Rect2(-40, -26, 70, 52), Color(0.22, 0.23, 0.28))
			head.draw_rect(Rect2(-40, -26, 70, 8), Color(0.4, 0.42, 0.5))
			head.draw_rect(Rect2(28, -30, 16, 60), Color(1.0, 0.9, 0.6)))
	n.set_meta("head", head)
	_lamp_nodes[l] = n
	if _pair_col.has(l):
		var b := PuzzleMarks.badge(_pair_num[l], _pair_col[l], 22.0)
		b.position = n.position + Vector2(CELL * 0.36, -CELL * 0.36)
		_room_node.add_child(b)
		_lamp_badges[l] = b
	_update_lamp(l, true)


func _update_lamp(l: String, instant := false) -> void:
	var head: Node2D = _lamp_nodes[l].get_meta("head")
	var target := Vector2(room.dir_of(l)).angle()
	if instant:
		head.rotation = target
	else:
		var from := head.rotation
		var diff := wrapf(target - from, -PI, PI)
		create_tween().tween_property(head, "rotation", from + diff, 0.25).set_trans(Tween.TRANS_BACK)


func _crank(c: Vector2i) -> void:
	_post_below(c)
	var col: Color = _pair_col[room.cranks[c]]
	var n := Node2D.new()
	n.position = _cell_pos(c)
	n.z_index = 2
	_room_node.add_child(n)
	if ResourceLoader.exists(ART + "crank.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "crank.png")
		var k := CELL * 0.55 / maxf(s.texture.get_width(), s.texture.get_height())
		s.scale = Vector2(k, k)
		n.add_child(s)
	else:
		n.draw.connect(func():
			n.draw_circle(Vector2.ZERO, 12.0, Color(0.2, 0.2, 0.24))
			n.draw_line(Vector2.ZERO, Vector2(30, 0), Color(0.3, 0.3, 0.35), 9.0)
			n.draw_line(Vector2(30, 0), Vector2(30, -20), Color(0.55, 0.35, 0.2), 10.0))
	var ring := PuzzleMarks.ring(_cell_pos(c), CELL * 0.36, col, 5.0)
	_room_node.add_child(ring)
	n.set_meta("ring", ring)
	var b := PuzzleMarks.badge(_pair_num[room.cranks[c]], col, 22.0)
	b.position = _cell_pos(c) + Vector2(-CELL * 0.36, -CELL * 0.36)
	_room_node.add_child(b)
	_crank_nodes[c] = n


## An iron post from a lamp or crank out over a gap down to the roof below (or out of view).
func _post_below(cell: Vector2i) -> void:
	var y := cell.y + 1
	if y >= room.height or room.solid(cell.x, y):
		return
	while y < room.height and not room.solid(cell.x, y):
		y += 1
	var top := _cell_pos(cell) + Vector2(0, CELL * 0.3)
	var bottom := Vector2(top.x, ORIGIN.y + y * CELL + (200.0 if y >= room.height else 0.0))
	var post := Line2D.new()
	post.points = PackedVector2Array([top, bottom])
	post.width = 12.0
	post.default_color = Color(0.1, 0.1, 0.13)
	_room_node.add_child(post)


func _goal(p: Vector2i) -> void:
	# a roof hatch, warm light spilling out of it
	var n := Node2D.new()
	n.position = _cell_pos(p) + Vector2(0, CELL * 0.5)
	n.draw.connect(func():
		n.draw_rect(Rect2(-46, -14, 92, 14), Color(0.35, 0.25, 0.16))
		n.draw_rect(Rect2(-38, -12, 76, 8), Color(1.0, 0.82, 0.45))
		n.draw_colored_polygon(PackedVector2Array([Vector2(-38, -12), Vector2(38, -12), Vector2(60, -110), Vector2(-60, -110)]), Color(1.0, 0.85, 0.5, 0.18)))
	_room_node.add_child(n)


func _place_pigeons() -> void:
	# sleeping pigeons on the far roof's edge
	var spots := []
	for x in range(room.width - 1, room.width - 5, -1):
		for y in range(1, room.height):
			if room.rows[y][x] == "#" and room.rows[y - 1][x] in [".", "G"]:
				spots.append(Vector2i(x, y))
				break
	for s in spots.slice(0, 3):
		var p := Sprite2D.new()
		if ResourceLoader.exists(ART + "pigeon_sit.png"):
			p.texture = load(ART + "pigeon_sit.png")
			var k := 54.0 / p.texture.get_height()
			p.scale = Vector2(k, k)
		else:
			var img := Image.create(48, 40, false, Image.FORMAT_RGBA8)
			for py in 40:
				for px in 48:
					if Vector2((px - 24) / 20.0, (py - 26) / 13.0).length() < 1.0 or Vector2(px - 10, py - 12).length() < 8.0:
						img.set_pixel(px, py, Color(0.5, 0.52, 0.6))
			p.texture = ImageTexture.create_from_image(img)
		p.position = ORIGIN + Vector2((s.x + 0.5) * CELL + randf_range(-30, 30), s.y * CELL - 22)
		p.z_index = 2
		_room_node.add_child(p)
		_pigeons.append(p)


# ================================================================ beams

## Rebuild the beams' collision (one-way, so Blobb can jump up through them) and redraw them.
func _refresh_beams() -> void:
	for b in _beam_bodies.get_children():
		b.queue_free()
	if _solid_light:
		for l in room.lamps:
			var cells := room.beam(l)
			if cells.is_empty():
				continue
			var d := room.dir_of(l)
			if d.x == 0:
				continue  # straight up: only light, nothing to stand on
			else:
				var a := _cell_pos(cells[0]) - Vector2(d) * CELL * 0.5
				var b := _cell_pos(cells[-1]) + Vector2(d) * CELL * 0.5
				var dir := (b - a).normalized()
				if dir.x < 0:
					dir = -dir
				_one_way((a + b) * 0.5, a.distance_to(b), dir.angle())
				if d.y == 0:
					_step_ramps(cells, d)
	_beam_node.queue_redraw()


## A level beam runs at mid-height of its row, half a cell below the top of a lamp or roof at
## its ends: a short ramp at each such end lets Blobb walk up onto it instead of jumping.
func _step_ramps(cells: Array, d: Vector2i) -> void:
	for end in [[cells[0], -d], [cells[-1], d]]:
		var c: Vector2i = end[0]
		var side: Vector2i = end[1]
		var n := c + side
		if not room.solid(n.x, n.y) or room.solid(n.x, n.y - 1):
			continue
		var edge_x := _cell_pos(c).x + side.x * CELL * 0.5
		var low := Vector2(edge_x - side.x * CELL * 0.5, _cell_pos(c).y - 7.0)
		var high := Vector2(edge_x, _cell_pos(c).y - CELL * 0.5)
		var dir := (high - low).normalized()
		if dir.x < 0:
			dir = -dir
		_one_way((low + high) * 0.5, low.distance_to(high), dir.angle())


func _one_way(center: Vector2, length: float, angle: float) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, 14.0)
	cs.shape = shape
	cs.one_way_collision = true
	cs.one_way_collision_margin = 8.0
	body.position = center
	body.rotation = angle
	body.add_child(cs)
	_beam_bodies.add_child(body)


func _draw_beams(n: Node2D) -> void:
	for l in room.lamps:
		var cells := room.beam(l)
		var d := Vector2(room.dir_of(l))
		var a := _cell_pos(room.lamps[l]["pos"]) + d.normalized() * 40.0
		var b := a + d * 30.0 if cells.is_empty() else _cell_pos(cells[-1]) + d * CELL * 0.5
		var alpha := 1.0 if _solid_light else 0.5
		n.draw_line(a, b, Color(LIGHT, 0.12 * alpha), BEAM_W * 3.2)
		n.draw_line(a, b, Color(LIGHT, 0.25 * alpha), BEAM_W * 1.6)
		if _solid_light and d.x != 0:
			# solid light: a bright walkable edge along the top (straight-up light is only light)
			n.draw_line(a, b, Color(1.0, 0.95, 0.8, 0.85), 8.0)


func _pulse() -> void:
	if not player or _crank_nodes.is_empty():
		return
	var reach := _crank_in_reach() if not _busy else Vector2i(-1, -1)
	if reach != _linked:
		_linked = reach
	for c in _crank_nodes:
		var ring: Line2D = _crank_nodes[c].get_meta("ring")
		ring.width = 5.0 + (4.0 + 3.0 * sin(_t * 8.0) if c == _linked else 0.0)
	for l in _lamp_badges:
		var on: bool = _linked != Vector2i(-1, -1) and room.cranks[_linked] == l
		_lamp_badges[l].scale = Vector2.ONE * (1.25 + 0.15 * sin(_t * 8.0) if on else 1.0)
	_overlay.queue_redraw()


func _draw_link(n: Node2D) -> void:
	if _linked == Vector2i(-1, -1) or not room.cranks.has(_linked):
		return
	var l: String = room.cranks[_linked]
	var from := _cell_pos(_linked)
	var to := _cell_pos(room.lamps[l]["pos"])
	var col: Color = _pair_col[l]
	var dir := (to - from).normalized()
	var total := from.distance_to(to)
	var at := fmod(_t * 60.0, 36.0)
	while at < total - CELL * 0.3:
		if at > CELL * 0.3:
			n.draw_line(from + dir * at, from + dir * minf(at + 20.0, total - CELL * 0.3), col, 7.0)
		at += 36.0


# ================================================================ scenery

func _build_scenery() -> void:
	var back := CanvasLayer.new()
	back.layer = -10
	add_child(back)
	var sky := ColorRect.new()
	sky.size = Vector2(1920, 1080)
	sky.color = Color(0.03, 0.04, 0.12)
	back.add_child(sky)
	if ResourceLoader.exists(ART + "rooftops_bg.png"):
		var bg := TextureRect.new()
		bg.texture = load(ART + "rooftops_bg.png")
		bg.size = Vector2(1920, 1080)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.modulate = Color(0.7, 0.72, 0.8)  # keep it behind the puzzle
		back.add_child(bg)
		return
	var n := Node2D.new()
	n.draw.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 200:
			n.draw_circle(Vector2(rng.randf() * 1920, rng.randf() * 700), rng.randf_range(0.8, 2.0), Color(1, 1, 0.9, rng.randf_range(0.3, 0.9)))
		# the town far below: rows of warm lights
		for i in 260:
			n.draw_circle(Vector2(rng.randf() * 1920, rng.randf_range(820, 1080)), rng.randf_range(1.5, 3.5), Color(1.0, 0.8, 0.45, rng.randf_range(0.3, 0.8)))
		# far off: one tall building, one lit sign
		n.draw_rect(Rect2(1690, 470, 70, 420), Color(0.07, 0.08, 0.16))
		n.draw_rect(Rect2(1702, 490, 46, 18), Color(0.85, 0.92, 1.0, 0.85)))
	back.add_child(n)


# ================================================================ test bot

## Autoplay: walk the solver's answer by teleporting Blobb to each crank in turn (for screenshots).
func _autoplay() -> void:
	var gen := _room_gen
	var sol := room.solve()
	for c in sol:
		await get_tree().create_timer(0.9).timeout
		if gen != _room_gen:
			return
		for r in room.region(_model_pos(), room.surfaces(room.states())):
			if room.at(c, r):
				player.teleport(_stand_pos(r) + Vector2(0, -56))  # drop onto it: on a 45° ramp his box corner would start inside the beam
				break
		await get_tree().create_timer(0.5).timeout
		_turn(c)
	await get_tree().create_timer(1.0).timeout
	if gen != _room_gen:
		return
	for r in room.region(_model_pos(), room.surfaces(room.states())):
		if room.at(room.goal, r):
			player.teleport(_stand_pos(r) + Vector2(0, -56))  # drop onto it: on a 45° ramp his box corner would start inside the beam
			break


## Blobb's current model position: his column and the surface just under his feet.
func _model_pos() -> Vector2i:
	var x := floori(player.global_position.x / CELL)
	var y2 := roundi((player.global_position.y - ORIGIN.y) / (CELL * 0.5))
	var surf := room.surfaces(room.states())
	var best := Vector2i(x, y2)
	var bd := 999
	for s in surf:
		if s.x == x and absi(s.y - y2) < bd:
			bd = absi(s.y - y2)
			best = s
	return best

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state", "debug_plan"]


func debug_state() -> Dictionary:
	var d := DebugState.base(player)
	d.merge(DebugState.json({"room": room_i, "lamps": room.states(), "cell": _player_cell(), "crank_in_reach": _crank_in_reach(), "solved": room.solved_by(_player_cell()), "busy_room": _busy, "done": _done, "fails": _fail_count, "retelling": _retelling}), true)
	return d


## For tools/playtest.py. Read-only. `solution`: the solver's cranks from the room's start. `path`:
## the shortest way (the strict jump model's moves) from where Blobb stands now to stand in cell
## (tx, ty) (the goal if omitted), as surfaces with the pixel point to stand on; [] if none.
func debug_plan(tx := -1.0, ty := -1.0) -> Dictionary:
	var target := room.goal if tx < 0 else Vector2i(int(tx), int(ty))
	var surf := room.surfaces(room.states())
	var from := _model_pos()
	var prev := {from: from}
	var queue := [from]
	var path := []
	while not queue.is_empty():
		var a: Vector2i = queue.pop_front()
		if room.at(target, a):
			while true:
				path.push_front({"surf": a, "stand": _stand_pos(a)})
				if a == from:
					break
				a = prev[a]
			break
		for b in room.moves(a, surf):
			if not prev.has(b):
				prev[b] = a
				queue.append(b)
	return DebugState.json({"solution": room.solve(), "from": from, "path": path, "goal": room.goal})
