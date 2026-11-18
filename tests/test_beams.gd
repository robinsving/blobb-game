extends SceneTree
## Headless rule tests for BeamRoom and the ch3 rooftop rooms (mirrors tools/solve_beams.py).
## Run: godot-flatpak --headless --path . --script res://tests/test_beams.gd

const Rooms := preload("res://chapters/ch3/beam_rooms.gd")
## Shortest solutions (crank turns) per room under the generous jump model, as found by
## tools/solve_beams.py. The strict model must also solve each room (it really can be done).
const SHORTEST := [2, 6, 8]

var failures := 0


func _init() -> void:
	_test_rules()
	_test_rooms()
	print("FAILED: %d" % failures if failures else "ALL TESTS PASSED")
	quit(1 if failures else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func _test_rules() -> void:
	var r := BeamRoom.from_room({
		"rows": ["......", "..H...", "P.A..G", "######"],
		"lamps": {"A": {"dirs": ["r", "u", "ul"], "start": 0}}, "controls": {},
	})
	_check(r.beam("A") == [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)], "a beam runs to the edge of the room")
	_check(r.beam("A", 1).is_empty(), "a chimney right above blocks the beam")
	_check(r.beam("A", 2) == [Vector2i(1, 1), Vector2i(0, 0)], "diagonal beams step both ways")
	var surf := r.surfaces([0])
	_check(surf.has(Vector2i(3, 5)), "light is solid: a beam is something to stand on (half a cell up)")
	_check(surf.has(Vector2i(0, 6)), "roof tops are surfaces")
	_check(r.at(Vector2i(5, 2), Vector2i(5, 6)), "standing on the roof under a cell is being in it")
	_check(r.fall(Vector2i(3, 5), r.surfaces([1])) == Vector2i(3, 6), "turning the lamp drops Blobb to the roof below")
	var gap := BeamRoom.from_room({
		"rows": ["..........", "P.A1.....G", "####.....#"],
		"lamps": {"A": {"dirs": ["u", "r"], "start": 0}}, "controls": {"1": "A"},
	})
	_check(gap.solve().size() == 1, "a five-cell gap needs the bridge (one turn)")


func _test_rooms() -> void:
	for i in Rooms.ROOMS.size():
		var spec: Dictionary = Rooms.ROOMS[i]
		var g := BeamRoom.from_room(spec, true)
		var gsol := g.solve()
		_check(gsol.size() == SHORTEST[i], "room %d: no shortcut, even with a generous jump: %d turns (got %d)" % [i + 1, SHORTEST[i], gsol.size()])
		var r := BeamRoom.from_room(spec)
		var sol := r.solve()
		_check(sol.size() >= SHORTEST[i], "room %d is solvable with the strict jump (got %d turns)" % [i + 1, sol.size()])
		var s := r.states()
		var reg := r.region(r.start_pos(s), r.surfaces(s))
		var free := false
		for p in reg:
			free = free or r.at(r.goal, p)
		_check(not free, "room %d can't be crossed without turning a lamp" % (i + 1))
