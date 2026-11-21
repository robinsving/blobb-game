class_name BeamRoom
extends RefCounted
## Pure rules for the ch3 rooftop rooms, where light is solid (chapters/ch3/beam_rooms.gd).
## Mirrors tools/solve_beams.py exactly; keep the two in sync. See that file's docstring for the
## model. Positions are (column, y2) with y2 = height in half cells (2 * row for a roof top,
## 2 * row + 1 for a beam through the middle of a row).

const DIRS := {"r": Vector2i(1, 0), "l": Vector2i(-1, 0), "u": Vector2i(0, -1), "ur": Vector2i(1, -1),
	"ul": Vector2i(-1, -1), "dr": Vector2i(1, 1), "dl": Vector2i(-1, 1)}
const LAMP_LETTERS := "ABCDEF"
const UP_MAX := 3      # half cells
const UP_DX := 2
const FLAT_DX := 3

var rows: Array = []
var width := 0
var height := 0
var start := Vector2i.ZERO
var goal := Vector2i.ZERO
var lamps := {}        # letter -> {"pos": Vector2i, "dirs": Array, "state": int}
var cranks := {}       # Vector2i -> lamp letter
var order: Array = []  # lamp letters, sorted
## The generous jump model (see tools/solve_beams.py): more than Blobb's real jump, so its
## shortest solution is a floor no real shortcut can beat. The strict one proves it's solvable.
var generous := false


static func from_room(spec: Dictionary, generous_model := false) -> BeamRoom:
	var r := BeamRoom.new()
	r.generous = generous_model
	r.rows = spec["rows"]
	r.height = r.rows.size()
	r.width = r.rows[0].length()
	for y in r.height:
		for x in r.width:
			var c: String = r.rows[y][x]
			var p := Vector2i(x, y)
			if c == "P":
				r.start = p
			elif c == "G":
				r.goal = p
			elif LAMP_LETTERS.contains(c):
				var l: Dictionary = spec["lamps"][c]
				r.lamps[c] = {"pos": p, "dirs": l["dirs"], "state": l.get("start", 0)}
			elif c.is_valid_int():
				r.cranks[p] = spec["controls"][c]
	r.order = r.lamps.keys()
	r.order.sort()
	return r


func solid(x: int, y: int) -> bool:
	if x < 0 or x >= width or y >= height:
		return true
	if y < 0:
		return false
	var c: String = rows[y][x]
	return c == "#" or c == "H" or LAMP_LETTERS.contains(c)


func dir_of(l: String, state := -1) -> Vector2i:
	var s: int = lamps[l]["state"] if state < 0 else state
	return DIRS[lamps[l]["dirs"][s]]


## The cells one lamp lights, from the lamp outwards.
func beam(l: String, state := -1) -> Array:
	var d := dir_of(l, state)
	var p: Vector2i = lamps[l]["pos"] + d
	var out := []
	while p.x >= 0 and p.x < width and p.y >= 0 and p.y < height and not solid(p.x, p.y):
		out.append(p)
		p += d
	return out


func states() -> Array:
	var s := []
	for l in order:
		s.append(lamps[l]["state"])
	return s


func set_states(s: Array) -> void:
	for i in order.size():
		lamps[order[i]]["state"] = s[i]


func surfaces(s: Array) -> Dictionary:
	var lit := {}
	for i in order.size():
		for c in beam(order[i], s[i]):
			lit[c] = true
	var out := {}
	for x in width:
		for r in range(1, height):
			if solid(x, r) and not solid(x, r - 1):
				out[Vector2i(x, 2 * r)] = true
			if lit.has(Vector2i(x, r)) and not solid(x, r - 1):
				out[Vector2i(x, 2 * r + 1)] = true
	return out


func _clear_path(a: Vector2i, b: Vector2i) -> bool:
	var top := mini(a.y, b.y)
	var row := (top - 1) / 2 if top % 2 == 1 else top / 2 - 1
	for x in range(mini(a.x, b.x) + 1, maxi(a.x, b.x)):
		if solid(x, row):
			return false
	return true


## A jump from p to q would meet another surface on the way. Light is one-way, so Blobb can jump
## up through a beam but then lands on it, and he never falls down through one. Any surface in the
## columns he moves over (not his own) from one cell above the higher end down to just above the
## lower end blocks the move (surfaces at his own height there are just more floor).
func _crosses(p: Vector2i, q: Vector2i, surf: Dictionary) -> bool:
	var top := mini(p.y, q.y) - 2
	var bottom := maxi(p.y, q.y)
	for k in surf:
		var s: Vector2i = k
		if s.x == p.x or s == q or s.x < mini(p.x, q.x) or s.x > maxi(p.x, q.x):
			continue
		if s.y >= top and s.y < bottom and not (s.y == p.y and p.y == q.y):
			return true
	return false


func moves(p: Vector2i, surf: Dictionary) -> Array:
	var out := []
	for k in surf:
		var q: Vector2i = k
		if q == p:
			continue
		var dx := absi(q.x - p.x)
		var up := p.y - q.y
		if up > UP_MAX:
			continue
		if dx == 0 and up < 0:
			continue  # he can't fall through what he stands on
		if generous:
			if dx <= (3 if up > 0 else (5 if -up >= 7 else 4)):
				out.append(q)
			continue
		var reach := UP_DX if up > 1 else FLAT_DX + maxi(0, -up) / 4
		if dx > reach:
			continue
		if dx > 0 and _crosses(p, q, surf):
			continue
		if not _clear_path(p, q):
			continue
		out.append(q)
	return out


func region(p: Vector2i, surf: Dictionary) -> Dictionary:
	var seen := {p: true}
	var queue := [p]
	while not queue.is_empty():
		var a: Vector2i = queue.pop_front()
		for b in moves(a, surf):
			if not seen.has(b):
				seen[b] = true
				queue.append(b)
	return seen


## Blobb standing at p is in this cell (so he can use a crank there, or has reached the goal).
func at(cell: Vector2i, p: Vector2i) -> bool:
	return p.x == cell.x and (p.y == 2 * cell.y + 1 or p.y == 2 * cell.y + 2)


## Where Blobb ends up if p stops being a surface: the next one below, or null (off the roofs).
func fall(p: Vector2i, surf: Dictionary) -> Variant:
	if surf.has(p):
		return p
	var best := -1
	for s in surf:
		if s.x == p.x and s.y > p.y and (best < 0 or s.y < best):
			best = s.y
	return Vector2i(p.x, best) if best >= 0 else null


func start_pos(s: Array) -> Vector2i:
	var f: Variant = fall(Vector2i(start.x, 2 * start.y + 1), surfaces(s))
	return f if f != null else Vector2i(start.x, 2 * start.y + 2)


func pressed(s: Array, l: String) -> Array:
	var out := s.duplicate()
	var i := order.find(l)
	out[i] = (out[i] + 1) % lamps[l]["dirs"].size()
	return out


## Blobb's body is in the goal cell.
func solved_by(cell: Vector2i) -> bool:
	return cell == goal


## Turns the lamp a crank controls. Returns false if p is not a crank.
func press(c: Vector2i) -> bool:
	if not cranks.has(c):
		return false
	set_states(pressed(states(), cranks[c]))
	return true


## Shortest list of crank cells to turn (in order) that lets Blobb reach the goal, or [] if none.
func solve() -> Array:
	var s0 := states()
	var p0 := start_pos(s0)
	var queue := [[s0, p0, []]]
	var seen := {[s0, p0]: true}
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var s: Array = item[0]
		var p: Vector2i = item[1]
		var path: Array = item[2]
		var reg := region(p, surfaces(s))
		for r in reg:
			if at(goal, r):
				return path
		for c in cranks:
			for r in reg:
				if not at(c, r):
					continue
				var s2 := pressed(s, cranks[c])
				var p2: Variant = fall(r, surfaces(s2))
				if p2 == null:
					continue
				var k := [s2, p2]
				if seen.has(k):
					continue
				seen[k] = true
				queue.append([s2, p2, path + [c]])
	return []
