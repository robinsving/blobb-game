extends Node2D
## Chapter 1, part 2: top-down box pushing in the clearing ("like a bird sees it").
## Two rooms. Room 2's stream can only be crossed after the narrators agree that wooden crates float.
## Dialogue: chapters/ch1/story.txt. Room layouts live in rooms.gd (verified by tools/solve_sokoban.py and tests/test_sokoban.gd).

const CELL := 96
const ROOMS: Array = preload("res://chapters/ch1/rooms.gd").ROOMS
## Top-down Blobb, best first: the round green scribble from the original drawing, then the generated pancake.
const TOPDOWN_TEXES := ["res://assets/sprites/drawn_ball.png", "res://assets/gen/ch1/blobb_topdown.png"]
const CRATE_TEX := "res://assets/gen/ch1/crate_topdown.png"
const STUMP_TEX := "res://assets/gen/ch1/stump_topdown.png"
const GROUND_TEX := "res://assets/gen/ch1/clearing_topdown_ground.png"

var room := 0
var grid: SokobanGrid
var fx: StyleFX
var board: Node2D
var water_node: Node2D
var player_node: Node2D
var player_sprite: Node2D
var crate_nodes := {}  # id -> Node2D
var origin := Vector2.ZERO
var _moving := false
var _repeat := 0.0
var _float_told := false
var _restart_told := false
var _gate_told := false
var _pancake := false
var _done := false
var _t := 0.0
var _hint: HintMarker
var _stuck_time := 0.0         # time in this room, across restarts
var _restarts := 0
var _nudged := false
const NUDGE_SECS := 90.0       # stuck this long (or 2 restarts): the legend flashes, hint key and all
var story := StoryScript.load_file("res://chapters/ch1/story.txt")


func _ready() -> void:
	set_meta("topdown", true)
	fx = StyleFX.new()
	fx.set_look("crayon", 0.0)
	add_child(fx)
	_load_room(clampi(Game.warp - 1, 0, ROOMS.size() - 1) if Game.warp > 0 else 0)  # --warp=N: room N
	_room_intro()
	if Game.debug_moves != "":
		_debug_play(Game.debug_moves)


## Test helper: plays "RRUL...|DDR..." (one move string per room, see tools/solve_sokoban.py).
func _debug_play(spec: String) -> void:
	var per_room := spec.split("|")
	for r in per_room.size():
		while room != r or Game.control_locked or _moving:
			await get_tree().process_frame
		for ch in per_room[r]:
			await get_tree().process_frame
			while Game.control_locked or _moving or Narrator.busy:
				await get_tree().process_frame
			var d: Vector2i = {"R": Vector2i.RIGHT, "L": Vector2i.LEFT, "U": Vector2i.UP, "D": Vector2i.DOWN}[ch]
			_move(d)
			await get_tree().create_timer(0.05).timeout


# ================================================================ story
# All dialogue lives in chapters/ch1/story.txt (scenes room1, room2, float, gate_open,
# restart, ending). @effects in those scenes call the fx_* methods below.

func _room_intro() -> void:
	Game.control_locked = true
	if room == 0:
		await get_tree().create_timer(0.8).timeout
		await story.play("room1", self)
	else:
		await story.play("room2", self)
	Narrator.legend("hint_push")


## retry_dir: the push that bumped into the water; Blobb tries it again once crates float.
func _float_beat(retry_dir := Vector2i.ZERO) -> void:
	_float_told = true
	await story.play("float", self)
	if retry_dir != Vector2i.ZERO:
		while _moving:
			await get_tree().process_frame
		_move(retry_dir)


func _ending() -> void:
	_done = true
	Game.control_locked = true
	Game.music("", 0.0, 3.0)
	var tw := create_tween()
	tw.tween_property(player_sprite, "rotation", 0.4, 1.5)
	fx.tint(Color(0.55, 0.6, 1.0), 0.6, 4.0)
	fx.set_look("paper", 4.0)
	await story.play("ending", self)
	await get_tree().create_timer(1.2).timeout
	Game.sfx("beep", -20.0)
	await get_tree().create_timer(2.2).timeout
	await _chapter_card()
	Game.unlock_chapter(2)
	Game.go("res://scenes/title.tscn", Color.BLACK, 1.5)


# ================================================================ story effects (@name in story.txt)

func fx_crates_float() -> void:
	grid.crates_float = true
	Game.sfx("chime", -6.0)


func fx_fade_to_black() -> void:
	Game.fade_out(Color.BLACK, 3.0)


func _chapter_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 101
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(0, 400)
	box.size = Vector2(1920, 300)
	box.add_theme_constant_override("separation", 20)
	layer.add_child(box)
	for spec in [[Game.t("chapter_1"), 44, Fonts.serif()], [Game.t("chapter_1_name"), 84, Fonts.hand()], [Game.t("chapter_end"), 36, Fonts.serif()]]:
		var l := Label.new()
		l.text = spec[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", spec[2])
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		l.modulate.a = 0.0
		box.add_child(l)
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 1.4)
		await get_tree().create_timer(1.6 if not Game.fast else 0.2).timeout
	await get_tree().create_timer(3.5 if not Game.fast else 0.5).timeout


func fx_pancake() -> void:
	_pancake = true
	Game.sfx("pop", -4.0, 0.8)
	var target := _player_scale()
	if _topdown_tex() != "":
		var s := Sprite2D.new()
		s.texture = load(_topdown_tex())
		s.material = BlobbSprite.green_material()
		s.scale = Vector2.ONE * (CELL * 1.15 / s.texture.get_width())
		target = s.scale
		player_sprite.queue_free()
		player_sprite = s
		player_node.add_child(s)
	var tw := create_tween()
	player_sprite.scale = Vector2(target.x * 1.4, target.y * 0.5)
	tw.tween_property(player_sprite, "scale", target, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ================================================================ rooms

func _load_room(i: int) -> void:
	room = i
	for c in get_children():
		if c != fx:
			c.queue_free()
	crate_nodes.clear()
	grid = SokobanGrid.from_rows(ROOMS[i])
	grid.crates_float = _float_told
	origin = Vector2(960, 610) - Vector2(grid.width, grid.height) * CELL * 0.5

	board = Node2D.new()
	board.set_script(preload("res://scripts/clearing_board.gd"))
	board.set("grid", grid)
	board.set("origin", origin)
	board.set("cell", CELL)
	add_child(board)

	for p in grid.crates:
		var n := _make_crate()
		n.position = _cell_pos(p)
		add_child(n)
		crate_nodes[grid.crates[p]] = n

	player_node = Node2D.new()
	player_node.position = _cell_pos(grid.player)
	add_child(player_node)
	if _pancake and _topdown_tex() != "":
		var s := Sprite2D.new()
		s.texture = load(_topdown_tex())
		s.material = BlobbSprite.green_material()
		s.scale = Vector2.ONE * (CELL * 1.15 / s.texture.get_width())
		player_sprite = s
	else:
		var b := BlobbSprite.new()
		b.scale = _player_scale()
		b.position = Vector2(0, -8)
		player_sprite = b
	player_node.add_child(player_sprite)


func _topdown_tex() -> String:
	for p in TOPDOWN_TEXES:
		if ResourceLoader.exists(p):
			return p
	return ""


func _player_scale() -> Vector2:
	var s := CELL * 0.95 / BlobbSprite.FRAME_W
	return Vector2(s, s * (0.75 if _pancake else 1.0))


func _make_crate() -> Node2D:
	if ResourceLoader.exists(CRATE_TEX):
		var s := Sprite2D.new()
		s.texture = load(CRATE_TEX)
		s.scale = Vector2.ONE * (CELL * 1.08 / s.texture.get_width())
		return s
	var n := Node2D.new()
	n.set_script(preload("res://scripts/crate_drawn.gd"))
	return n


func _cell_pos(p: Vector2i) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * CELL


# ================================================================ input / moves

func _process(delta: float) -> void:
	_t += delta
	if _done or _moving or Game.control_locked:
		return
	_stuck_time += delta
	if not _nudged and (_stuck_time > NUDGE_SECS or _restarts >= 2):
		_nudged = true
		Narrator.legend_nudge()
	if Input.is_action_just_pressed("hint"):
		_show_hint()
		return
	if Input.is_action_just_pressed("undo"):
		_undo()
		return
	if Input.is_action_just_pressed("restart"):
		_restart()
		return
	var dir := Vector2i.ZERO
	for a in [["left", Vector2i.LEFT], ["right", Vector2i.RIGHT], ["up", Vector2i.UP], ["down", Vector2i.DOWN]]:
		if Input.is_action_just_pressed(a[0]):
			dir = a[1]
			_repeat = 0.22
			break
	if dir == Vector2i.ZERO:
		_repeat -= delta
		if _repeat <= 0.0:
			for a in [["left", Vector2i.LEFT], ["right", Vector2i.RIGHT], ["up", Vector2i.UP], ["down", Vector2i.DOWN]]:
				if Input.is_action_pressed(a[0]):
					dir = a[1]
					_repeat = 0.12
					break
	if dir != Vector2i.ZERO:
		_move(dir)


## The next box to push (and which way), with the way to walk there, worked out from the room as
## it is now. Before the story has made crates float, the hint may be a push into the water,
## which is exactly what makes them float.
func _show_hint() -> void:
	var moves := grid.solve(true)
	if moves.is_empty():
		Narrator.hint(Game.t("hint_stuck"), 5.0)
		return
	var p := grid.player
	var trail := PackedVector2Array()
	for d in moves:
		var n: Vector2i = p + d
		if grid.crates.has(n):
			_hint = HintMarker.at(self, _cell_pos(n), CELL * 0.55, Vector2(d), trail, _hint)
			return
		trail.append(_cell_pos(n))
		p = n
	# no box left to push: just the way out
	_hint = HintMarker.at(self, _cell_pos(p), CELL * 0.55, Vector2.ZERO, trail, _hint)


func _move(dir: Vector2i) -> void:
	if is_instance_valid(_hint):
		_hint.queue_free()
	if dir.x != 0 and player_sprite is BlobbSprite:
		(player_sprite as BlobbSprite).face(dir.x)
	var was_open := grid.gate_open()
	var res := grid.try_move(dir)
	if not res["moved"]:
		if res["water_blocked"] and not _float_told:
			_float_beat(dir if res.get("pushed", -1) == -1 and grid.crates.has(grid.player + dir) else Vector2i.ZERO)
		else:
			_bump(dir)
		return
	_moving = true
	var dur := 0.13
	var tw := create_tween().set_parallel()
	tw.tween_property(player_node, "position", _cell_pos(grid.player), dur)
	if res["pushed"] >= 0:
		var crate: Node2D = crate_nodes[res["pushed"]]
		tw.tween_property(crate, "position", _cell_pos(res["to"]), dur)
		Game.sfx("push", -6.0, randf_range(0.9, 1.1))
		if res["bridged"]:
			tw.chain().tween_callback(func():
				Game.sfx("splash", -4.0)
				crate.visible = false
				board.queue_redraw())
		elif grid.plates.has(res["to"]):
			Game.sfx("plate", -4.0)
	# hop
	var hop := create_tween()
	hop.tween_property(player_sprite, "position:y", player_sprite.position.y - 10, dur * 0.5)
	hop.tween_property(player_sprite, "position:y", player_sprite.position.y, dur * 0.5)
	await tw.finished
	_moving = false
	board.queue_redraw()
	if grid.gate_open() != was_open:
		_gate_changed(grid.gate_open())
	if not _float_told and room == 1 and grid.player_near_water():
		_float_beat()
	if res["exit"]:
		_exit_room()


func _bump(dir: Vector2i) -> void:
	_moving = true
	var base := player_node.position
	var tw := create_tween()
	tw.tween_property(player_node, "position", base + Vector2(dir) * 10, 0.05)
	tw.tween_property(player_node, "position", base, 0.08)
	await tw.finished
	_moving = false


func _gate_changed(open: bool) -> void:
	Game.sfx("gate", -4.0 if open else -8.0, 1.0 if open else 0.8)
	if open and not _gate_told:
		_gate_told = true
		story.play("gate_open", self)


func _undo() -> void:
	if grid.undo():
		Game.sfx("rewind", -14.0, 1.6)
		_sync_nodes()


func _restart() -> void:
	_restarts += 1
	if is_instance_valid(_hint):
		_hint.queue_free()
	Game.sfx("rewind", -8.0)
	fx.rewind_pulse(0.7)
	while grid.undo():
		pass
	_sync_nodes()
	if not _restart_told:
		_restart_told = true
		story.play("restart", self)


func _sync_nodes() -> void:
	player_node.position = _cell_pos(grid.player)
	var alive := {}
	for p in grid.crates:
		var id: int = grid.crates[p]
		alive[id] = true
		crate_nodes[id].position = _cell_pos(p)
		crate_nodes[id].visible = true
	for id in crate_nodes:
		if not alive.has(id):
			crate_nodes[id].visible = false
	board.queue_redraw()


func _exit_room() -> void:
	Game.control_locked = true
	Narrator.legend("")
	_stuck_time = 0.0
	_restarts = 0
	_nudged = false
	if room + 1 < ROOMS.size():
		Game.sfx("whoosh", -6.0)
		await Game.fade_out(Color(0.1, 0.15, 0.08), 0.6)
		_load_room(room + 1)
		await get_tree().process_frame
		Game.fade_in(0.6)
		_room_intro()
	else:
		_ending()
