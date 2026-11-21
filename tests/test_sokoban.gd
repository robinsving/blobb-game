extends SceneTree
## Headless rule tests for SokobanGrid and the ch1 room solutions.
## Run: godot-flatpak --headless --path . --script res://tests/test_sokoban.gd

const Rooms := preload("res://chapters/ch1/rooms.gd")
const SOLUTIONS := ["RRRRLDDRDLLRRRURR", "DRRRLLUURDLDRRRLDDLULURRRRRRDRURDRRRR"]
const DIRS := {"R": Vector2i.RIGHT, "L": Vector2i.LEFT, "U": Vector2i.UP, "D": Vector2i.DOWN}

var failures := 0


func _init() -> void:
	_test_solutions()
	_test_water_blocks_until_float()
	_test_undo()
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
