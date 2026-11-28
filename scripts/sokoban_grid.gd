class_name SokobanGrid
extends RefCounted
## Pure top-down box-pushing rules (no nodes), so it can be unit-tested and mirrored by tools/solve_sokoban.py.
##
## Map legend:  # wall/stump   . floor   P player   B crate   o plate   * crate on plate
##              ~ water        G gate (opens when every plate holds a crate)   E exit   ' ' void (wall)
##              A the tiny banana (floor under it): after each move Blobb makes, it takes one step
##                along its row (banana_step()). It pushes a crate ahead of it, or shoves Blobb one cell,
##                if there's room beyond; otherwise (a wall, the gate, the exit, water) it turns round.
##                Blobb can't walk into it or push a crate into it.
## Crates pushed into water sink and become walkable bridges — but only once `crates_float` is true
## (the narrators "decide" that wooden crates float). Before that, water blocks crates.

var width := 0
var height := 0
var walls := {}     # Vector2i -> true
var water := {}     # Vector2i -> true (unbridged water)
var bridges := {}   # Vector2i -> true
var plates := {}    # Vector2i -> true
var crates := {}    # Vector2i -> crate id (int)
var gate := Vector2i(-1, -1)
var exit_cell := Vector2i(-1, -1)
var player := Vector2i.ZERO
var crates_float := false
var banana := Vector2i(-1, -1)  # (-1, -1): no banana in this room
var banana_dir := 1             # +1 = right, -1 = left
var _history: Array = []


static func from_rows(rows: Array) -> SokobanGrid:
	var g := SokobanGrid.new()
	g.height = rows.size()
	var next_id := 0
	for y in rows.size():
		var row: String = rows[y]
		g.width = maxi(g.width, row.length())
		for x in row.length():
			var c := row[x]
			var p := Vector2i(x, y)
			match c:
				"#", " ":
					g.walls[p] = true
				"~":
					g.water[p] = true
				"B":
					g.crates[p] = next_id
					next_id += 1
				"o":
					g.plates[p] = true
				"*":
					g.plates[p] = true
					g.crates[p] = next_id
					next_id += 1
				"P":
					g.player = p
				"G":
					g.gate = p
				"E":
					g.exit_cell = p
				"A":
					g.banana = p
	return g


func gate_open() -> bool:
	for p in plates:
		if not crates.has(p):
			return false
	return true


func is_wall(p: Vector2i) -> bool:
	return walls.has(p) or p.x < 0 or p.y < 0 or p.x >= width or p.y >= height


## Attempts a move. Returns a result dictionary:
##   moved: bool, pushed: crate id or -1, from/to: crate cells, bridged: bool (crate sank into water),
##   water_blocked: bool (a push into water failed because crates don't float yet), exit: bool
func try_move(dir: Vector2i) -> Dictionary:
	var res := {"moved": false, "pushed": -1, "bridged": false, "water_blocked": false, "exit": false}
	var n := player + dir
	if is_wall(n) or (n == gate and not gate_open()) or n == banana:
		return res
	if water.has(n):
		res["water_blocked"] = true
		return res
	if crates.has(n):
		var t := n + dir
		if is_wall(t) or crates.has(t) or t == gate or t == exit_cell or t == banana:
			return res
		if water.has(t) and not crates_float:
			res["water_blocked"] = true
			return res
		_push_history()
		var id: int = crates[n]
		crates.erase(n)
		res["pushed"] = id
		res["from"] = n
		res["to"] = t
		if water.has(t):
			water.erase(t)
			bridges[t] = true
			res["bridged"] = true
		else:
			crates[t] = id
	else:
		_push_history()
	player = n
	res["moved"] = true
	res["exit"] = n == exit_cell
	return res


func undo() -> bool:
	if _history.is_empty():
		return false
	var s: Dictionary = _history.pop_back()
	player = s["player"]
	crates = s["crates"]
	water = s["water"]
	bridges = s["bridges"]
	banana = s["banana"]
	banana_dir = s["banana_dir"]
	return true


func can_undo() -> bool:
	return not _history.is_empty()


func _push_history() -> void:
	_history.append({"player": player, "crates": crates.duplicate(), "water": water.duplicate(), "bridges": bridges.duplicate(),
		"banana": banana, "banana_dir": banana_dir})


func has_banana() -> bool:
	return banana.x >= 0


func _banana_blocked(p: Vector2i) -> bool:
	return is_wall(p) or crates.has(p) or water.has(p) or p == gate or p == exit_cell


## The banana takes one step along its row (the level calls this after each move Blobb makes).
## Returns: moved, turned, shoved (Blobb pushed one cell on), pushed (crate id or -1), from/to.
## Mirrored by bstep() in tools/solve_sokoban.py.
func banana_step() -> Dictionary:
	var res := {"moved": false, "turned": false, "shoved": false, "pushed": -1}
	if not has_banana():
		return res
	var step := Vector2i(banana_dir, 0)
	var n := banana + step
	if is_wall(n) or water.has(n) or n == gate or n == exit_cell:
		banana_dir = -banana_dir
		res["turned"] = true
		return res
	if n == player or crates.has(n):
		var t := n + step
		if _banana_blocked(t) or t == player:
			banana_dir = -banana_dir
			res["turned"] = true
			return res
		if n == player:
			player = t
			res["shoved"] = true
		else:
			var id: int = crates[n]
			crates.erase(n)
			crates[t] = id
			res["pushed"] = id
			res["from"] = n
			res["to"] = t
	banana = n
	res["moved"] = true
	return res


## True if the player stands orthogonally next to unbridged water.
func player_near_water() -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if water.has(player + d):
			return true
	return false
