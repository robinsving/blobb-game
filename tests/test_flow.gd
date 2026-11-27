extends SceneTree
## Headless rule tests for FlowRoom and the ch2 mill rooms (mirrors tools/solve_flow.py).
## Run: godot-flatpak --headless --path . --script res://tests/test_flow.gd

const Rooms := preload("res://chapters/ch2/flow_rooms.gd")
## Shortest solutions (control presses) per room, as found by tools/solve_flow.py.
const SHORTEST := [5, 7, 13]

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
	_check(FlowRoom.bounce(Vector2i.RIGHT, "/") == Vector2i.UP, "/ turns right-moving water up")
	_check(FlowRoom.bounce(Vector2i.RIGHT, "\\") == Vector2i.DOWN, "\\ turns right-moving water down")
	_check(FlowRoom.bounce(Vector2i.LEFT, "/") == Vector2i.DOWN, "/ turns left-moving water down")
	var spec := {
		"rows": ["#####G#", "#D....#", "#A.a.1#", "#######"],
		"spouts": {"A": {"dir": ">", "on": false}}, "boards": {"a": "\\"}, "controls": {"1": "a"},
	}
	var r := FlowRoom.from_room(spec)
	_check(r.settle() == "rest" and r.duck == Vector2i(1, 1), "with no stream the duck floats up and rests under rock")
	r.spouts["A"]["state"] = FlowRoom.ON
	var flow := r.streams()
	_check(flow.get(Vector2i(2, 2)) == Vector2i.RIGHT, "stream leaves the spout")
	_check(flow.get(Vector2i(3, 2)) == Vector2i.DOWN, "board bends the stream")
	_check(not flow.has(Vector2i(4, 2)), "stream stops after bending into rock")
	r.press(Vector2i(5, 2))
	_check(r.boards["a"]["shape"] == "/", "lever flips the board")
	flow = r.streams()
	_check(flow.get(Vector2i(3, 2)) == Vector2i.UP and flow.get(Vector2i(3, 1)) == Vector2i.UP, "flipped board sends it up")
	r.spouts["A"]["state"] = FlowRoom.BACK
	flow = r.streams()
	_check(flow.get(Vector2i(3, 1)) == Vector2i.DOWN and flow.get(Vector2i(2, 2)) == Vector2i.LEFT, "backwards spout pulls water toward itself")
	var meet := FlowRoom.from_room({
		"rows": ["###G####", "#A.D..B#", "########"],
		"spouts": {"A": {"dir": ">", "on": true}, "B": {"dir": "<", "on": true}}, "boards": {}, "controls": {},
	})
	flow = meet.streams()
	_check(flow.get(Vector2i(3, 1)) == Vector2i.RIGHT and flow.get(Vector2i(4, 1)) == Vector2i.LEFT, "head-on streams meet halfway")
	_check(meet.settle() == "rest" and meet.duck == Vector2i(3, 1), "the duck stays where two streams meet head-on")
	meet.spouts["A"]["state"] = FlowRoom.OFF
	_check(meet.streams().get(Vector2i(2, 1)) == Vector2i.LEFT, "with one off, the other runs all the way")


func _test_rooms() -> void:
	for i in Rooms.ROOMS.size():
		var spec: Dictionary = Rooms.ROOMS[i]
		var r := FlowRoom.from_room(spec)
		r.reverse_allowed = spec.get("needs_reverse", false)
		var sol := r.solve()
		_check(sol.size() == SHORTEST[i], "room %d shortest solution is %d presses (got %d)" % [i + 1, SHORTEST[i], sol.size()])
		# play the answer the way the game does: press, let the duck settle
		r.settle()
		for c in sol:
			r.press(c)
			r.settle()
		_check(r.solved(), "room %d: playing the solution gets the duck to the goal" % (i + 1))
		if spec.get("needs_reverse", false):
			var r2 := FlowRoom.from_room(spec)
			_check(r2.solve().is_empty(), "room %d can't be solved before the 'backwards' rule" % (i + 1))
		var r3 := FlowRoom.from_room(spec)
		_check(r3.settle() != "goal", "room %d doesn't solve itself" % (i + 1))
