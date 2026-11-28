extends SceneTree
## Headless rule tests for SokobanGrid and the ch1 room solutions.
## Run: godot-flatpak --headless --path . --script res://tests/test_sokoban.gd

const Rooms := preload("res://chapters/ch1/rooms.gd")
const SOLUTIONS := ["RRRRLDDRDLLRRRURR", "DRRRLLUURDLDRRRLDDLULURRRRRRDRURDRRRR",
	"RRLRLRLRLRLRLRLRLDDLDRRRURDDUURULLLULDDLDRRRURDDUUUURDRRRR"]
const DIRS := {"R": Vector2i.RIGHT, "L": Vector2i.LEFT, "U": Vector2i.UP, "D": Vector2i.DOWN}

var failures := 0


func _init() -> void:
	_test_solutions()
	_test_water_blocks_until_float()
	_test_undo()
	_test_banana()
	_test_banana_room()
	print("FAILED: %d" % failures if failures else "ALL TESTS PASSED")
	quit(1 if failures else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func _test_solutions() -> void:
	for i in SOLUTIONS.size():
		var g := SokobanGrid.from_rows(Rooms.ROOMS[i])
		g.crates_float = true
		var last := {}
		for ch in SOLUTIONS[i]:
			last = g.try_move(DIRS[ch])
			if last["moved"]:
				g.banana_step()  # the level does this after every move (a no-op without a banana)
		_check(last.get("exit", false), "room %d solution reaches exit" % i)


func _test_water_blocks_until_float() -> void:
	var g := SokobanGrid.from_rows(["#####", "#PB~#", "#####"])
	var r := g.try_move(Vector2i.RIGHT)
	_check(not r["moved"] and r["water_blocked"], "crate blocked by water before floating")
	g.crates_float = true
	r = g.try_move(Vector2i.RIGHT)
	_check(r["moved"] and r["bridged"], "crate bridges water once floating")
	r = g.try_move(Vector2i.RIGHT)
	_check(r["moved"] and g.player == Vector2i(3, 1), "player walks onto bridge")


func _test_undo() -> void:
	var g := SokobanGrid.from_rows(["######", "#PB.o#", "######"])
	g.try_move(Vector2i.RIGHT)
	_check(g.crates.has(Vector2i(3, 1)), "crate pushed")
	g.undo()
	_check(g.crates.has(Vector2i(2, 1)) and g.player == Vector2i(1, 1), "undo restores state")
	_check(not g.gate_open(), "plate uncovered -> gate closed")
	g.try_move(Vector2i.RIGHT)
	g.try_move(Vector2i.RIGHT)
	_check(g.gate_open(), "plate covered -> gate open")


func _test_banana() -> void:
	var g := SokobanGrid.from_rows(["#######", "#A...P#", "#######"])
	_check(g.has_banana() and g.banana == Vector2i(1, 1), "banana read from the map")
	g.banana_step()
	_check(g.banana == Vector2i(2, 1), "banana walks right")
	g.banana_step()
	g.banana_step()  # (4,1) is next to Blobb at (5,1), with the wall behind him
	var r := g.banana_step()
	_check(r["turned"] and not r["shoved"] and g.player == Vector2i(5, 1) and g.banana_dir == -1, "banana can't shove Blobb into a wall: it turns")
	g = SokobanGrid.from_rows(["#######", "#A.P..#", "#######"])
	g.banana_step()
	r = g.banana_step()
	_check(r["shoved"] and g.player == Vector2i(4, 1) and g.banana == Vector2i(3, 1), "banana shoves Blobb one cell on and steps after him")
	r = g.try_move(Vector2i.LEFT)
	_check(not r["moved"], "Blobb can't walk into the banana")
	g = SokobanGrid.from_rows(["########", "#AB...o#", "#P.....#", "########"])
	r = g.banana_step()
	_check(r["pushed"] >= 0 and g.crates.has(Vector2i(3, 1)) and g.banana == Vector2i(2, 1), "banana pushes a crate")
	for i in 3:
		g.banana_step()
	_check(g.crates.has(Vector2i(6, 1)) and g.gate_open(), "banana pushes the crate onto the plate at the end")
	r = g.banana_step()
	_check(r["turned"] and g.crates.has(Vector2i(6, 1)), "crate against the wall: the banana turns")
	g = SokobanGrid.from_rows(["#######", "#PB.A.#", "#######"])
	g.banana_dir = -1
	g.banana_step()
	r = g.try_move(Vector2i.RIGHT)
	_check(not r["moved"], "a crate can't be pushed into the banana")
	g = SokobanGrid.from_rows(["######", "#A.B.#", "#P...#", "######"])
	g.try_move(Vector2i.RIGHT)
	g.banana_step()
	g.undo()
	_check(g.banana == Vector2i(1, 1) and g.banana_dir == 1 and g.player == Vector2i(1, 2), "undo puts the banana back too")


## Room 3 can't be done without the banana's help: Blobb never gets behind a crate in its row.
func _test_banana_room() -> void:
	var g := SokobanGrid.from_rows(Rooms.ROOMS[2])
	var last := {}
	for ch in SOLUTIONS[2]:
		last = g.try_move(DIRS[ch])  # the same moves, but the banana stands still
	_check(not last.get("exit", false), "room 3: the solution needs the banana walking")
