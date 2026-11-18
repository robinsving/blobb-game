extends RefCounted
## The ch3 rooftop rooms (light is solid). Rules: scripts/beam_room.gd, mirrored by tools/solve_beams.py.
##   '#' roof   'H' chimney   'A'..'F' lamps (on a roof, or on an iron post when in a gap)
##   '.' air    'P' Blobb's start   'G' the goal   '1'..'9' cranks (each turns one lamp, see "controls")
## Each lamp shines one of its "dirs" (r l u ur ul dr dl); a crank steps it to the next one.
## 15 x 8 cells of 128 px. Gaps are 2 empty cells or fewer (jumpable) or 5 or more (not).
## Shortest solutions (crank turns): 2, 6, 8 (tests/test_beams.gd), the same under the strict and the
## generous jump model (tools/solve_beams.py), so there is no shortcut. Rooms 2 and 3 were found by a
## hill-climbing search that scored both models, then checked by hand.

const ROOMS := [
	# Room 1: one lamp. Turn it twice and it makes a bridge.
	{
		"rows": [
			"...............",
			"...............",
			"...............",
			"...........G...",
			"P.1A.......####",
			"####.......####",
			"####.......####",
			"####.......####",
		],
		"lamps": {"A": {"dirs": ["u", "ur", "r"], "start": 0}},
		"controls": {"1": "A"},
	},
	# Room 2: two lamps on posts in the gap. Crank 1 sits on lamp B and turns A; crank 2 sits on
	# lamp A and turns B. Both are needed.
	{
		"rows": [
			"...............",
			".2......1......",
			".A......B.....G",
			"P.............#",
			"#.............#",
			"#............H#",
			"#...##.......##",
			"#...##.......##",
		],
		"lamps": {"A": {"dirs": ["r", "dl", "dr"], "start": 1}, "B": {"dirs": ["u", "r", "dl"], "start": 0}},
		"controls": {"1": "A", "2": "B"},
	},
	# Room 3: three lamps; every crank is needed, and crank 3 twice over.
	{
		"rows": [
			"...............",
			".......1.......",
			"..2....C......G",
			"P.A...........#",
			"#...#....3....#",
			"#...#...##....#",
			"#...#.B.##....#",
			"#...#...##....#",
		],
		"lamps": {"A": {"dirs": ["ur", "ul", "u"], "start": 1}, "B": {"dirs": ["r", "ul", "dl"], "start": 2}, "C": {"dirs": ["ur", "r", "l"], "start": 0}},
		"controls": {"1": "A", "2": "B", "3": "C"},
	},
]
