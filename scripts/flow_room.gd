class_name FlowRoom
extends RefCounted
## Pure rules for the ch2 mill puzzles (no nodes). Water streams shoot out of sluice spouts, bend off
## wooden boards and carry the rubber duck; where no stream reaches it, the duck floats up. Blobb
## can't get past the fences, so he moves the water instead: wheels open and shut spouts, levers
## flip boards. Goal: get the duck into G. Rendering/input: chapters/ch2/mill.gd. Tests: tests/test_flow.gd.
##
## Room spec (chapters/ch2/flow_rooms.gd):
##   "rows": strings, one char per cell:
##     #  rock (solid)        .  water        H  fence (Blobb can't pass; water and the duck can)
##     D  duck start         G  goal         P  Blobb start
##     A-F  sluice spouts (solid), set up in "spouts": {"A": {"dir": ">", "on": false}}
##     a-f  turnable boards, set up in "boards": {"a": "/"}       /  \  fixed boards
##     1-9  controls (water cells Blobb swims to), set up in "controls": {"1": "A"} (a spout: its
##          wheel opens/shuts it; a board: its lever flips it)
##
## Duck rules, one tick at a time: in a stream, move one cell along it (if the next cell isn't solid);
## otherwise float up one cell (if it can). Where two streams cross, the first spout (A before B) wins.
## Story rule (ch2 "backwards"): once reverse_allowed, a spout's wheel cycles off -> on -> backwards,
## and a backwards spout pulls water (and the duck) along its stream back toward itself.

const DIR := {">": Vector2i.RIGHT, "<": Vector2i.LEFT, "^": Vector2i.UP, "v": Vector2i.DOWN}
enum { OFF, ON, BACK }

var width := 0
var height := 0
var rows: Array[String] = []
var spouts := {}     # letter -> {"pos": Vector2i, "dir": Vector2i, "state": OFF|ON|BACK}
var boards := {}     # letter -> {"pos": Vector2i, "shape": "/" or "\\"}
var controls := {}   # Vector2i -> letter (spout or board)
var duck := Vector2i.ZERO
var duck_start := Vector2i.ZERO
var goal := Vector2i.ZERO
var blobb_start := Vector2i.ZERO
var reverse_allowed := false
var _board_at := {}  # Vector2i -> letter
var _spout_at := {}


static func from_room(room: Dictionary) -> FlowRoom:
	var r := FlowRoom.new()
	for row in room["rows"]:
		r.rows.append(String(row))
	r.height = r.rows.size()
	r.width = r.rows[0].length()
	var spec_spouts: Dictionary = room.get("spouts", {})
	var spec_boards: Dictionary = room.get("boards", {})
	var spec_controls: Dictionary = room.get("controls", {})
	for y in r.height:
		for x in r.width:
			var c := r.rows[y][x]
			var p := Vector2i(x, y)
			if c == "D":
				r.duck_start = p
			elif c == "G":
				r.goal = p
			elif c == "P":
				r.blobb_start = p
			elif spec_spouts.has(c):
				var s: Dictionary = spec_spouts[c]
				r.spouts[c] = {"pos": p, "dir": DIR[s["dir"]], "state": ON if s.get("on", false) else OFF}
				r._spout_at[p] = c
			elif spec_boards.has(c):
				r.boards[c] = {"pos": p, "shape": spec_boards[c]}
				r._board_at[p] = c
			elif c == "/" or c == "\\":
				var id := "fixed%d_%d" % [x, y]
				r.boards[id] = {"pos": p, "shape": c}
				r._board_at[p] = id
			elif c >= "1" and c <= "9":
				r.controls[p] = spec_controls[c]
	r.duck = r.duck_start
	return r


func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


## Solid for water and the duck: rock, spouts.
func solid(p: Vector2i) -> bool:
	return not inside(p) or rows[p.y][p.x] == "#" or _spout_at.has(p)


## Solid for Blobb: also fences and boards.
func blocks_blobb(p: Vector2i) -> bool:
	return solid(p) or rows[p.y][p.x] == "H" or _board_at.has(p)


func spout_at(p: Vector2i) -> String:
	return _spout_at.get(p, "")


func board_at(p: Vector2i) -> String:
	return _board_at.get(p, "")


## Bounce a direction off a board.  "/" turns right<->up, left<->down; "\" turns right<->down, left<->up.
static func bounce(d: Vector2i, shape: String) -> Vector2i:
	if shape == "/":
		return Vector2i(-d.y, -d.x)
	return Vector2i(d.y, d.x)


## The cells a spout's water passes through, in order: [[cell, direction it flows on in], ...]
func trace(letter: String) -> Array:
	var s: Dictionary = spouts[letter]
	var out := []
	var d: Vector2i = s["dir"]
	var p: Vector2i = s["pos"] + d
	var seen := {}
	while not solid(p) and not seen.has([p, d]):
		seen[[p, d]] = true
		var b := board_at(p)
		var arrive := d
		if b != "":
			d = bounce(d, boards[b]["shape"])
		out.append([p, arrive, d])
		p += d
	return out


## Every wet cell -> the direction the water moves there.
func streams() -> Dictionary:
	var flow := {}
	var letters := spouts.keys()
	letters.sort()
	for l in letters:
		var state: int = spouts[l]["state"]
		if state == OFF:
			continue
		for step in trace(l):
			if flow.has(step[0]):
				continue
			# backwards: the water runs the other way along the same path, toward the spout
			flow[step[0]] = step[2] if state == ON else -step[1]
	return flow


## One tick for the duck. Returns true if it moved.
func step(flow: Dictionary) -> bool:
	if duck == goal:
		return false
	var next: Vector2i = duck + (flow[duck] if flow.has(duck) else Vector2i.UP)
	if solid(next):
		return false
	duck = next
	return true


## Press the control at p. Returns false if there's nothing to press there.
func press(p: Vector2i) -> bool:
	if not controls.has(p):
		return false
	var t: String = controls[p]
	if spouts.has(t):
		var st: int = spouts[t]["state"]
		if reverse_allowed:
			spouts[t]["state"] = (st + 1) % 3
		else:
			spouts[t]["state"] = OFF if st != OFF else ON
	else:
		boards[t]["shape"] = "\\" if boards[t]["shape"] == "/" else "/"
	return true


func solved() -> bool:
	return duck == goal


func reset() -> void:
	duck = duck_start


## Runs the duck until it settles, reaches the goal or goes round in circles.
## Returns "goal", "rest" or "loop".
func settle(max_ticks := 400) -> String:
	var flow := streams()
	var seen := {}
	for i in max_ticks:
		if duck == goal:
			return "goal"
		if seen.has(duck):
			return "loop"
		seen[duck] = true
		if not step(flow):
			return "goal" if duck == goal else "rest"
	return "loop"


func _key() -> String:
	var parts := [str(duck)]
	var ls := spouts.keys()
	ls.sort()
	for l in ls:
		parts.append(str(spouts[l]["state"]))
	var bs := boards.keys()
	bs.sort()
	for b in bs:
		parts.append(boards[b]["shape"])
	return ",".join(parts)


func _snapshot() -> Dictionary:
	var sp := {}
	for l in spouts:
		sp[l] = spouts[l]["state"]
	var bo := {}
	for b in boards:
		bo[b] = boards[b]["shape"]
	return {"duck": duck, "spouts": sp, "boards": bo}


func _restore(s: Dictionary) -> void:
	duck = s["duck"]
	for l in s["spouts"]:
		spouts[l]["state"] = s["spouts"][l]
	for b in s["boards"]:
		boards[b]["shape"] = s["boards"][b]


## Shortest list of control presses (as cells) that gets the duck to the goal, letting it settle
## after each press. [] if there's none. Leaves the room as it was.
func solve(max_states := 200000) -> Array:
	var start := _snapshot()
	var outcome := settle()
	if outcome == "goal":
		_restore(start)
		return []
	var first := _snapshot()
	var queue := [[first, []]]
	var seen := {_key(): true}
	var answer := []
	var found := false
	while not queue.is_empty() and seen.size() < max_states and not found:
		var item: Array = queue.pop_front()
		for c in controls:
			_restore(item[0])
			press(c)
			var res := settle()
			if res == "loop":
				continue
			var path: Array = item[1].duplicate()
			path.append(c)
			if res == "goal":
				answer = path
				found = true
				break
			var k := _key()
			if seen.has(k):
				continue
			seen[k] = true
			queue.append([_snapshot(), path])
	_restore(start)
	return answer
