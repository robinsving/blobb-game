extends Node2D
## Chapter 2, part 2: the mill channel. Three rooms (chapters/ch2/flow_rooms.gd, rules in
## scripts/flow_room.gd): Blobb swims to wheels and levers on his side of the fence; the spouts
## and boards they move send streams that carry the rubber duck, one cell per tick, in real time.
## Room 1: the duck pops out onto the warden banana, who throws it back in. Room 3 can't be solved
## until the younger narrator decides water can run backwards ("backwards" scene).
## Dialogue: chapters/ch2/story.txt. Art: assets/gen/ch2/ (with drawn fallbacks).

const ROOMS: Array = preload("res://chapters/ch2/flow_rooms.gd").ROOMS
const CELL := 128.0
const ORIGIN := Vector2(0, 184)
const SURFACE_Y := 150.0
const ART := "res://assets/gen/ch2/"
const TICK := 0.22
const REACH := 95.0           # how close Blobb must be to a wheel or lever to use it
const STREAM_PUSH := 260.0    # streams on Blobb's side push him (slower than he swims)
const BACKWARDS_AFTER_SECS := 25.0
const BACKWARDS_AFTER_PRESSES := 8
## each control and its spout/board share a colour
const PAIR_COLORS := [Color(0.95, 0.3, 0.25), Color(0.25, 0.6, 1.0), Color(1.0, 0.8, 0.2),
	Color(0.4, 0.85, 0.35), Color(0.85, 0.4, 0.95), Color(1.0, 0.55, 0.15)]

var room: FlowRoom
var room_i := 0
var player: PlayerSwim
var fx: StyleFX
var _room_node: Node2D
var _stream_node: Node2D
var _duck: Sprite2D
var _banana: Sprite2D
var _board_nodes := {}      # board letter -> Node2D
var _spout_nodes := {}      # spout letter -> Node2D
var _control_nodes := {}    # Vector2i -> Node2D
var _pair_num := {}         # target letter -> the number its control and badge show
var _pair_col := {}         # target letter -> colour
var _target_badges := {}    # target letter -> badge Node2D
var _paths := []            # [{"pts": PackedVector2Array, "owner": letter}] one per running stream
var _owner := {}            # wet cell -> the spout whose water is there (first letter wins)
var _linked := Vector2i(-1, -1)  # control currently shown with a line to its target
var _flow := {}
var _tick := 0.0
var _busy := true
var _done := false
var _reverse_told := false
var _restart_told := false
var _room_time := 0.0
var _presses := 0
var _duck_still := 0.0
var _stuck_checked := ""  # the room state last checked for a dead end (FlowRoom._key)
var _t := 0.0
var _room_gen := 0  # bumped on every room load, so a bot loop from an earlier room stops
var story := StoryScript.load_file("res://chapters/ch2/story.txt")


func _ready() -> void:
	Game.music("res://assets/audio/music_pool.ogg", -16.0)
	_build_scenery()
	fx = StyleFX.new()
	fx.set_look("real", 0.0)
	fx.tint(Color(0.95, 1.02, 1.05), 0.2, 0.0)
	add_child(fx)
	LevelKit.drip_loop(self)
	_load_room(clampi(Game.warp - 1, 0, ROOMS.size() - 1) if Game.warp > 0 else 0)  # --warp=N: room N
	_room_intro()


func _room_intro() -> void:
	_busy = true
	await get_tree().create_timer(0.6).timeout
	match room_i:
		0: await story.play("room1", self)
		1: await story.play("room2", self)
		2: await story.play("room3", self)
	Narrator.legend("hint_mill")
	_busy = false
	if Game.autoplay:
		_autoplay()


# ================================================================ story effects (@name in story.txt)

func fx_whistle() -> void:
	Game.sfx("whistle", -8.0)
	if _banana:
		LevelKit.hop(_banana)


func fx_duck_bonk() -> void:
	if not _duck or not _banana:
		return
	var head := _banana.position + Vector2(0, -130)
	var tw := create_tween()
	tw.tween_property(_duck, "position", head, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_duck, "rotation", 0.0, 0.35)
	tw.tween_callback(func():
		Game.sfx("bonk", -2.0)
		fx_whistle())


func fx_duck_back() -> void:
	if not _duck:
		return
	Game.sfx("whoosh", -6.0)
	var tw := create_tween()
	tw.tween_property(_duck, "position", Vector2(900, -80), 0.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_duck, "rotation", -TAU * 1.5, 0.9)
	tw.tween_property(_duck, "position", Vector2(700, 1200), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Game.sfx("splash", -6.0))


func fx_reverse() -> void:
	room.reverse_allowed = true
	Game.sfx("chime", -6.0)


func fx_float_back() -> void:
	player.set_physics_process(false)
	var tw := create_tween().set_parallel()
	tw.tween_property(_room_node, "modulate:a", 0.0, 2.0)
	tw.tween_property(_stream_node, "modulate:a", 0.0, 2.0)
	player.global_position = Vector2(-150, 600)
	tw.tween_property(player, "global_position", Vector2(900, SURFACE_Y + 230), 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player.sprite, "rotation", -PI * 0.42, 3.0).set_trans(Tween.TRANS_SINE)
	if _duck:
		_duck.position = Vector2(-300, 600)
		_duck.rotation = 0.0
		tw.tween_property(_duck, "position", Vector2(1080, SURFACE_Y + 160), 3.4).set_trans(Tween.TRANS_SINE)
	fx.tint(Color(1.0, 0.86, 0.62), 0.45, 4.0)


func fx_fade_to_black() -> void:
	Game.fade_out(Color.BLACK, 3.0)


# ================================================================ play

func _process(delta: float) -> void:
	_t += delta
	_scroll_streams(delta)
	_pulse_controls()
	if _busy or _done:
		return
	_room_time += delta
	# the duck moves one cell per tick along the streams (or floats up)
	_tick += delta
	if _tick >= TICK:
		_tick = 0.0
		var from := room.duck
		if room.step(_flow):
			_duck_still = 0.0
			var tw := create_tween()
			tw.tween_property(_duck, "position", _cell_pos(room.duck), TICK).set_trans(Tween.TRANS_LINEAR)
			if _flow.has(from):
				_duck.flip_h = _flow[from].x < 0
		else:
			_duck_still += TICK
			if _duck_still >= TICK * 3.0 and _check_stuck():
				return
		if room.solved():
			_solved()
			return
	if room_i == 2 and not _reverse_told and (_room_time > BACKWARDS_AFTER_SECS or _presses >= BACKWARDS_AFTER_PRESSES):
		_reverse_told = true
		_tell_backwards()
		return
	if Game.control_locked or Game.autoplay:
		return
	if Input.is_action_just_pressed("advance"):
		var c := _control_in_reach()
		if c != Vector2i(-1, -1):
			_press(c)
	elif Input.is_action_just_pressed("restart"):
		_restart()


func _physics_process(_delta: float) -> void:
	if not player or _done:
		return
	var cell := _to_cell(player.global_position + Vector2(0, -54))
	player.flow = Vector2(_flow[cell]) * STREAM_PUSH if _flow.has(cell) else Vector2.ZERO


func _tell_backwards() -> void:
	_busy = true
	await story.play("backwards", self)
	Narrator.hint(Game.t("hint_backwards"), 7.0)
	_busy = false


func _press(c: Vector2i) -> void:
	if not room.press(c):
		return
	_presses += 1
	var t: String = room.controls[c]
	var n: Node2D = _control_nodes[c]
	if room.spouts.has(t):
		Game.sfx("turn", -6.0, [0.8, 1.0, 1.25][room.spouts[t]["state"]])
		create_tween().tween_property(n, "rotation", n.rotation + PI * 0.5, 0.25).set_trans(Tween.TRANS_BACK)
	else:
		Game.sfx("push", -6.0, 1.2)
		n.scale.x *= -1.0  # the lever flips over
		_update_board(t)
	_refresh_streams()


## The wheel or lever Blobb would use: the nearest in reach. The one already marked stays marked
## until another is clearly nearer, so two neighbours (3 and 4) don't flicker as he bobs.
func _control_in_reach() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := REACH
	var p := player.global_position + Vector2(0, -54)
	for c in room.controls:
		var d := p.distance_to(_cell_pos(c))
		if d < best_d:
			best_d = d
			best = c
	if _linked != best and room.controls.has(_linked):
		var keep := p.distance_to(_cell_pos(_linked))
		if keep < REACH and keep < best_d + 28.0:
			return _linked
	return best


## Pressing while the duck is still moving can leave it where no presses can get it to the goal.
## Once it has settled, check that (once per state); if it's a dead end, start the room over.
func _check_stuck() -> bool:
	var key := room._key()
	if key == _stuck_checked or room.solved():
		return false
	_stuck_checked = key
	var allowed := room.reverse_allowed
	room.reverse_allowed = allowed or room_i == 2  # room 3: the backwards rule is coming anyway
	var dead := room.solve().is_empty()
	room.reverse_allowed = allowed
	if not dead:
		return false
	_stuck_restart()
	return true


func _stuck_restart() -> void:
	_busy = true
	Narrator.hint(Game.t("hint_duck_stuck"), 4.0)
	await get_tree().create_timer(1.6).timeout
	_busy = false
	_restart()


func _restart() -> void:
	var allowed := room.reverse_allowed
	_load_room(room_i)
	room.reverse_allowed = allowed
	Game.sfx("whoosh", -10.0)
	if not _restart_told:
		_restart_told = true
		story.play("restart", self)


func _solved() -> void:
	_busy = true
	Game.control_locked = true
	Narrator.legend("")
	Game.sfx("flow", -6.0)
	# the duck shoots up out through the goal to the surface
	var top := Vector2(_cell_pos(room.goal).x, SURFACE_Y - 60)
	var tw := create_tween()
	tw.tween_property(_duck, "position", top, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_duck, "rotation", TAU, 0.5)
	await tw.finished
	match room_i:
		0:
			await story.play("duck_out", self)
			await get_tree().create_timer(0.6).timeout
			await _next_room(1)
		1:
			Game.sfx("chime", -6.0)
			await get_tree().create_timer(1.0).timeout
			await _next_room(2)
		2:
			await story.play("hatch", self)
			_ending()


func _next_room(i: int) -> void:
	await Game.fade_out(Color(0.03, 0.08, 0.07), 0.8)
	_load_room(i)
	Game.fade_in(0.8)
	Game.control_locked = false
	_room_intro()


func _ending() -> void:
	_done = true
	Game.music("", 0.0, 3.0)
	await story.play("ending", self)
	await get_tree().create_timer(1.2).timeout
	Game.sfx("beep", -20.0)
	await get_tree().create_timer(0.7).timeout
	Game.sfx("beep", -20.0)
	await get_tree().create_timer(2.4).timeout
	Game.unlock_chapter(3)  # before the card: quitting during it still counts
	await ChapterCard.closing(self, "chapter_end_2", Color(0.95, 0.9, 0.8))
	Game.go("res://scenes/title.tscn", Color.BLACK, 1.5)


# ================================================================ building

func _build_scenery() -> void:
	var back := CanvasLayer.new()
	back.layer = -10
	var deep := ColorRect.new()
	deep.color = Color(0.07, 0.14, 0.13)
	deep.size = Vector2(1920, 1080)
	back.add_child(deep)
	if ResourceLoader.exists(ART + "millrace_bg.png"):
		var bg := TextureRect.new()
		bg.texture = load(ART + "millrace_bg.png")
		bg.size = Vector2(1920, 1080)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.modulate = Color(0.75, 0.8, 0.8)  # keep it behind the puzzle
		back.add_child(bg)
	add_child(back)
	var sky := ColorRect.new()
	sky.color = Color(0.82, 0.9, 0.95)
	sky.size = Vector2(1920, SURFACE_Y)
	add_child(sky)
	var bank := ColorRect.new()
	bank.color = Color(0.35, 0.55, 0.22)
	bank.position = Vector2(1250, SURFACE_Y - 24)
	bank.size = Vector2(670, 24)
	add_child(bank)
	if ResourceLoader.exists(ART + "water_surface.png"):
		var surf := Sprite2D.new()
		surf.texture = load(ART + "water_surface.png")
		surf.centered = false
		surf.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		surf.region_enabled = true
		surf.region_rect = Rect2(0, 0, 1920, 128)
		surf.position = Vector2(0, SURFACE_Y - 40)
		add_child(surf)
	for p in [ART + "banana_lifeguard.png", "res://assets/sprites/banana.png"]:
		if ResourceLoader.exists(p):
			_banana = Sprite2D.new()
			_banana.texture = load(p)
			var k := 140.0 / _banana.texture.get_height()
			_banana.scale = Vector2(k, k)
			_banana.offset = Vector2(0, -_banana.texture.get_height() * 0.5)
			_banana.position = Vector2(1500, SURFACE_Y - 22)
			_banana.z_index = 1
			add_child(_banana)
			break


func _load_room(i: int) -> void:
	Game.checkpoint(i + 1 if i > 0 else -1)  # a save point: Continue starts in this room
	room_i = i
	_room_gen += 1
	_room_time = 0.0
	_presses = 0
	_tick = 0.0
	_stuck_checked = ""
	if _room_node:
		_room_node.queue_free()
		_stream_node.queue_free()
	if _duck:
		_duck.queue_free()
	_board_nodes.clear()
	_spout_nodes.clear()
	_control_nodes.clear()
	room = FlowRoom.from_room(ROOMS[i])
	_room_node = Node2D.new()
	add_child(_room_node)
	_stream_node = Node2D.new()
	_stream_node.z_index = 1
	add_child(_stream_node)
	_stream_node.draw.connect(_draw_streams.bind(_stream_node))  # bound: an old node being freed on a restart draws on itself

	var pair := {}  # target letter -> colour
	_pair_num.clear()
	_target_badges.clear()
	var keys := room.controls.keys()
	keys.sort()
	for k in keys:
		var t: String = room.controls[k]
		pair[t] = PAIR_COLORS[pair.size() % PAIR_COLORS.size()]
		_pair_num[t] = str(_pair_num.size() + 1)
	_pair_col = pair

	for y in room.height:
		for x in room.width:
			var p := Vector2i(x, y)
			var ch := room.rows[y][x]
			if ch == "#":
				_rock(p)
			elif ch == "H":
				_fence(p)
			elif ch == "G":
				_goal(p)
	for l in room.spouts:
		_spout(l, pair.get(l, Color.WHITE))
	for b in room.boards:
		_board(b, pair.get(b, Color(0.6, 0.6, 0.6)))
	for c in room.controls:
		_control(c, pair[room.controls[c]])

	_duck = _make_duck()
	_duck.position = _cell_pos(room.duck)

	if not player:
		player = PlayerSwim.new()
		player.name = "Player"  # a stable path for gda: /root/<Level>/Player
		player.surface_y = -100000.0
		player.can_swim = true
		player.mode = PlayerSwim.Mode.SWIM
		player.buoyancy = 0.0
		player.use_bot = false
		player.sprite_scale = 0.34
		add_child(player)
		player.sprite.set_tint(BlobbSprite.BLUE, BlobbSprite.BLUE_AMOUNT, 0.0)
		player.z_index = 3
	player.teleport(_cell_pos(room.blobb_start) + Vector2(0, 50))
	_refresh_streams()


func _cell_pos(p: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(p) + Vector2(0.5, 0.5)) * CELL


func _to_cell(v: Vector2) -> Vector2i:
	var g := (v - ORIGIN) / CELL
	return Vector2i(floori(g.x), floori(g.y))


func _solid_body(p: Vector2i) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL, CELL)
	cs.shape = shape
	body.position = _cell_pos(p)
	body.add_child(cs)
	_room_node.add_child(body)


func _rock(p: Vector2i) -> void:
	_solid_body(p)
	var rect := Rect2(ORIGIN + Vector2(p) * CELL, Vector2(CELL, CELL))
	if ResourceLoader.exists(ART + "riverbed_tile.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "riverbed_tile.png")
		s.centered = false
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.scale = Vector2(0.5, 0.5)
		s.region_rect = Rect2(rect.position * 2.0, rect.size * 2.0)
		s.position = rect.position
		_room_node.add_child(s)
	else:
		var r := ColorRect.new()
		r.color = Color(0.32, 0.28, 0.22)
		r.position = rect.position
		r.size = rect.size
		_room_node.add_child(r)


func _fence(p: Vector2i) -> void:
	_solid_body(p)
	var pos := ORIGIN + Vector2(p) * CELL
	if ResourceLoader.exists(ART + "fence_tile.png"):
		var s := Sprite2D.new()
		s.texture = load(ART + "fence_tile.png")
		s.centered = false
		s.scale = Vector2.ONE * (CELL / s.texture.get_width())
		s.position = pos
		_room_node.add_child(s)
	else:
		for i in 4:
			var l := Line2D.new()
			l.width = 9.0
			l.default_color = Color(0.45, 0.32, 0.2)
			var x := pos.x + 16 + i * 32
			l.points = PackedVector2Array([Vector2(x, pos.y), Vector2(x, pos.y + CELL)])
			_room_node.add_child(l)


func _goal(p: Vector2i) -> void:
	var file := "mill_hatch.png" if room_i == 2 else "bubble.png"
	var s := _sprite(_room_node, file, _cell_pos(p), CELL * 0.9)
	if s and room_i != 2:
		s.modulate = Color(1, 1, 1, 0.8)
	var ring := PuzzleMarks.ring(_cell_pos(p), CELL * 0.42, Color(1.0, 0.95, 0.6, 0.8), 5.0)
	_room_node.add_child(ring)


func _spout(l: String, col: Color) -> void:
	var s: Dictionary = room.spouts[l]
	_solid_body(s["pos"])
	var n := Node2D.new()
	n.position = _cell_pos(s["pos"])
	n.rotation = Vector2(s["dir"]).angle()
	n.z_index = 2
	_room_node.add_child(n)
	n.draw.connect(_draw_spout.bind(n, l))
	_spout_nodes[l] = n
	_target_badge(l, _cell_pos(s["pos"]), col)


## A stone sluice mouth pointing along +x (the node is rotated to the spout's direction). The
## arrow painted on it says what the wheel has set: on (out), backwards (in) or off (a bar).
func _draw_spout(n: Node2D, l: String) -> void:
	var h := CELL * 0.5
	n.draw_rect(Rect2(-h, -h * 0.72, h * 1.45, h * 1.44), Color(0.36, 0.35, 0.33))
	n.draw_rect(Rect2(-h, -h * 0.72, h * 1.45, h * 1.44), Color(0.18, 0.17, 0.16), false, 5.0)
	# the mouth, on the side the water comes out
	n.draw_rect(Rect2(h * 0.45, -h * 0.5, h * 0.55, h * 1.0), Color(0.12, 0.12, 0.13))
	n.draw_rect(Rect2(h * 0.45, -h * 0.5, h * 0.55, h * 1.0), Color(0.5, 0.48, 0.45), false, 4.0)
	var st: int = room.spouts[l]["state"]
	if st == FlowRoom.OFF:
		n.draw_line(Vector2(-h * 0.6, 0), Vector2(h * 0.15, 0), Color(0.6, 0.6, 0.6), 12.0)
	else:
		var tip := Vector2(h * 0.25, 0) if st == FlowRoom.ON else Vector2(-h * 0.7, 0)
		var back := Vector2(-h * 0.7, 0) if st == FlowRoom.ON else Vector2(h * 0.25, 0)
		var dir := (tip - back).normalized()
		var base := tip - dir * h * 0.42
		var c := Color(0.95, 0.98, 1.0) if st == FlowRoom.ON else Color(0.5, 0.85, 1.0)
		n.draw_line(back, base, c, 11.0)
		n.draw_colored_polygon(PackedVector2Array([tip, base + Vector2(0, h * 0.3), base - Vector2(0, h * 0.3)]), c)


## A numbered, coloured badge on a spout or board; its control wears the same one.
func _target_badge(target: String, pos: Vector2, col: Color) -> void:
	if not _pair_num.has(target):
		return
	var b := PuzzleMarks.badge(_pair_num[target], col)
	b.position = pos + Vector2(CELL * 0.34, -CELL * 0.34)
	_room_node.add_child(b)
	_target_badges[target] = b


func _board(b: String, col: Color) -> void:
	var pos := _cell_pos(room.boards[b]["pos"])
	var n := Node2D.new()
	n.position = pos
	n.z_index = 2  # above the water, so the bend is visible
	_room_node.add_child(n)
	var plank := _sprite(n, "board_plate.png", Vector2.ZERO, CELL * 1.3)
	if not plank:
		var l := Line2D.new()
		l.width = 16.0
		l.default_color = Color(0.5, 0.36, 0.2)
		l.points = PackedVector2Array([Vector2(-CELL * 0.6, 0), Vector2(CELL * 0.6, 0)])
		n.add_child(l)
	_target_badge(b, pos, col)
	_board_nodes[b] = n
	_update_board(b, true)


func _update_board(b: String, instant := false) -> void:
	var n: Node2D = _board_nodes[b]
	# "/" runs bottom-left to top-right
	var target := -PI * 0.25 if room.boards[b]["shape"] == "/" else PI * 0.25
	if instant:
		n.rotation = target
	else:
		create_tween().tween_property(n, "rotation", target, 0.2).set_trans(Tween.TRANS_BACK)


func _control(c: Vector2i, col: Color) -> void:
	var t: String = room.controls[c]
	var n := Node2D.new()
	n.position = _cell_pos(c)
	_room_node.add_child(n)
	var file := "valve_wheel.png" if room.spouts.has(t) else "wood_lever.png"
	if not _sprite(n, file, Vector2.ZERO, CELL * 0.6):
		var l := Line2D.new()
		l.width = 10.0
		l.default_color = Color(0.8, 0.2, 0.15) if room.spouts.has(t) else Color(0.55, 0.38, 0.2)
		l.points = PackedVector2Array([Vector2(-25, 25), Vector2(25, -25)]) if not room.spouts.has(t) else PackedVector2Array([Vector2(-30, 0), Vector2(30, 0), Vector2(0, 0), Vector2(0, -30), Vector2(0, 30)])
		n.add_child(l)
	var ring := PuzzleMarks.ring(_cell_pos(c), CELL * 0.4, col, 6.0)
	_room_node.add_child(ring)
	n.set_meta("ring", ring)
	var b := PuzzleMarks.badge(_pair_num[t], col)
	b.position = _cell_pos(c) + Vector2(-CELL * 0.34, -CELL * 0.34)
	_room_node.add_child(b)
	_control_nodes[c] = n


## The control Blobb can reach (or the mouse is over) gets a pulsing ring, and a line to the
## spout or board it moves, whose badge pulses too.
func _pulse_controls() -> void:
	if not player or _control_nodes.is_empty():
		return
	var reach := _control_in_reach() if not _busy else Vector2i(-1, -1)
	var hover := _to_cell(get_global_mouse_position())
	var linked := reach if reach != Vector2i(-1, -1) else (hover if _control_nodes.has(hover) and not _busy else Vector2i(-1, -1))
	_linked = linked
	for c in _control_nodes:
		var ring: Line2D = _control_nodes[c].get_meta("ring")
		ring.width = 6.0 + (5.0 + 3.0 * sin(_t * 8.0) if c == linked else 0.0)
		# the one Blobb would press stands out; the others step back while one is marked
		var n: Node2D = _control_nodes[c]
		n.modulate = Color(1.25, 1.2, 1.0) if c == linked else (Color(1, 1, 1, 0.5) if linked != Vector2i(-1, -1) else Color.WHITE)
		n.scale = Vector2.ONE * (1.12 if c == linked else 1.0)
	for t in _target_badges:
		var on: bool = linked != Vector2i(-1, -1) and room.controls[linked] == t
		_target_badges[t].scale = Vector2.ONE * (1.25 + 0.15 * sin(_t * 8.0) if on else 1.0)


func _refresh_streams() -> void:
	_flow = room.streams()
	_paths.clear()
	_owner.clear()
	var letters := room.spouts.keys()
	letters.sort()
	for l in letters:
		var st: int = room.spouts[l]["state"]
		if st == FlowRoom.OFF:
			continue
		var steps := room.trace(l)
		if steps.is_empty():
			continue
		var d0: Vector2i = room.spouts[l]["dir"]
		var pts := PackedVector2Array([_cell_pos(room.spouts[l]["pos"]) + Vector2(d0) * CELL * 0.5])
		for step in steps:
			pts.append(_cell_pos(step[0]))
			if not _owner.has(step[0]):
				_owner[step[0]] = l
		var last: Array = steps[-1]
		pts.append(_cell_pos(last[0]) + Vector2(last[2]) * CELL * 0.5)
		if st == FlowRoom.BACK:
			pts.reverse()
		_paths.append({"pts": pts, "owner": l})
	for l in _spout_nodes:
		_spout_nodes[l].queue_redraw()
	_stream_node.queue_redraw()


func _scroll_streams(_delta: float) -> void:
	if _stream_node:
		_stream_node.queue_redraw()


## Each running stream is one ribbon of water from the spout to where it hits rock, with arrows
## sliding along it the way the water (and so the duck) moves. Where two streams cross, the
## arrows show whichever stream wins that cell.
func _draw_streams(n: Node2D) -> void:
	for path in _paths:
		var pts: PackedVector2Array = path["pts"]
		n.draw_polyline(pts, Color(0.3, 0.62, 0.95, 0.38), 70.0)
		for i in range(1, pts.size() - 1):
			if (pts[i] - pts[i - 1]).normalized().dot((pts[i + 1] - pts[i]).normalized()) < 0.5:
				n.draw_circle(pts[i], 35.0, Color(0.3, 0.62, 0.95, 0.38))  # round off the bend
		n.draw_polyline(pts, Color(0.75, 0.9, 1.0, 0.45), 20.0)
	for path in _paths:
		var pts: PackedVector2Array = path["pts"]
		var gap := 58.0
		var dist := fmod(_t * 170.0, gap)
		var seg := 0
		var seg_start := 0.0
		while seg < pts.size() - 1:
			var a := pts[seg]
			var b := pts[seg + 1]
			var seg_len := a.distance_to(b)
			if dist > seg_start + seg_len:
				seg_start += seg_len
				seg += 1
				continue
			var dir := (b - a).normalized()
			var p := a + dir * (dist - seg_start)
			dist += gap
			var cell := _to_cell(p)
			if not _owner.has(cell) or _owner[cell] != path["owner"]:
				continue
			var side := dir.orthogonal() * 13.0
			n.draw_polyline(PackedVector2Array([p - dir * 10.0 + side, p + dir * 8.0, p - dir * 10.0 - side]), Color(1, 1, 1, 0.9), 6.0)
	if _linked != Vector2i(-1, -1):
		var t: String = room.controls[_linked]
		var to: Vector2 = _cell_pos(room.spouts[t]["pos"]) if room.spouts.has(t) else _cell_pos(room.boards[t]["pos"])
		var from := _cell_pos(_linked)
		var col: Color = _pair_col[t]
		var dir := (to - from).normalized()
		var total := from.distance_to(to)
		var at := fmod(_t * 60.0, 36.0)
		while at < total - CELL * 0.3:
			if at > CELL * 0.3:
				n.draw_line(from + dir * at, from + dir * minf(at + 20.0, total - CELL * 0.3), col, 7.0)
			at += 36.0
		n.draw_circle(to, CELL * 0.12, col)


func _make_duck() -> Sprite2D:
	var s := _sprite(self, "rubber_duck.png", Vector2.ZERO, CELL * 0.8)
	if not s:
		s = Sprite2D.new()
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				if Vector2(x - 32, y - 34).length() < 26:
					img.set_pixel(x, y, Color(1.0, 0.85, 0.15))
		s.texture = ImageTexture.create_from_image(img)
		s.scale = Vector2.ONE * (CELL * 0.7 / 64.0)
		add_child(s)
	s.z_index = 4
	return s


func _sprite(parent: Node, file: String, pos: Vector2, size: float) -> Sprite2D:
	if not ResourceLoader.exists(ART + file):
		return null
	var s := Sprite2D.new()
	s.texture = load(ART + file)
	s.position = pos
	var k := size / maxf(s.texture.get_width(), s.texture.get_height())
	s.scale = Vector2(k, k)
	parent.add_child(s)
	return s


# ================================================================ test bot (--autoplay)

## Solves each room like a player would: swim to the next control, wait for the duck to settle,
## press. In room 3 it waits for the "backwards" rule first.
func _autoplay() -> void:
	var gen := _room_gen
	if room_i == 2:
		while not room.reverse_allowed or _busy:
			await get_tree().create_timer(0.5).timeout
	while gen == _room_gen and not _busy and not room.solved():
		while _duck_still < TICK * 2.5:
			await get_tree().create_timer(TICK).timeout
		if gen != _room_gen or _busy:
			return
		var sol := room.solve()
		if sol.is_empty():
			return
		var c: Vector2i = sol[0]
		var tw := create_tween()
		tw.tween_property(player, "global_position", _cell_pos(c) + Vector2(0, 50), 0.6)
		await tw.finished
		if _busy or gen != _room_gen:
			return
		_press(c)
		_duck_still = 0.0
		await get_tree().create_timer(TICK * 2).timeout

# ================================================================ checking from outside

## For gda (`gda game call /root/<Level> debug_state`): see scripts/debug_state.gd. Read-only.
const GDA_CALLABLE := ["debug_state", "debug_plan"]


func debug_state() -> Dictionary:
	var d := DebugState.base(player)
	d.merge(DebugState.json({"room": room_i, "duck": room.duck, "goal": room.goal, "solved": room.solved(), "spouts": room.spouts, "boards": room.boards, "reverse_allowed": room.reverse_allowed, "in_reach": _control_in_reach(), "busy_room": _busy, "done": _done}), true)
	return d


## The solver's presses from the room as it is now, and where Blobb has to be (his position) to
## use each control. For tools/playtest.py. Read-only (solve() restores the room).
func debug_plan() -> Dictionary:
	var targets := {}
	for c in room.controls:
		targets[c] = _cell_pos(c) + Vector2(0, 54)
	return DebugState.json({"presses": room.solve(), "targets": targets})
