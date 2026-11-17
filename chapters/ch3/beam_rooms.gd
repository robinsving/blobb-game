extends RefCounted
## The ch3 rooftop rooms (light is solid). Rules: scripts/beam_room.gd, mirrored by tools/solve_beams.py.
##   '#' roof   'H' chimney   'A'..'F' lamps (on a roof, or on an iron post when in a gap)
##   '.' air    'P' Blobb's start   'G' the goal   '1'..'9' cranks (each turns one lamp, see "controls")
## Each lamp shines one of its "dirs" (r l u ur ul dr dl); a crank steps it to the next one.
## 15 x 8 cells of 128 px. Gaps are 2 empty cells or fewer (jumpable) or 5 or more (not).
## Shortest solutions (crank turns): 2, 6, 10 (tests/test_beams.gd). Rooms 2 and 3 were found by a
## hill-climbing search over random roofs and then checked by hand.

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
	# Room 2: two lamps. Stand on lamp A and turn B; the chimney stops B's bridge.
	{
		"rows": [
			"...............",
			"...............",
			"..............G",
			"P1H....B2...###",
			"#####...A...###",
			"#####.......###",
			"#####.......###",
			"#####.......###",
		],
		"lamps": {"A": {"dirs": ["r", "dl", "dr"], "start": 2}, "B": {"dirs": ["dr", "l", "u"], "start": 2}},
		"controls": {"1": "A", "2": "B"},
	},
	# Room 3: three lamps and two chimneys to climb (one down in the gap, one by the goal).
	{
		"rows": [
			"...............",
			"...............",
			"P1.............",
			"##..2.B.....CHG",
			"##.A......#####",
			"##........#####",
			"##.....H3.#####",
			"##.....##.#####",
		],
		"lamps": {"A": {"dirs": ["l", "dr", "ur"], "start": 0}, "B": {"dirs": ["ul", "dr", "u"], "start": 1}, "C": {"dirs": ["u", "ur", "ul"], "start": 0}},
		"controls": {"1": "A", "2": "B", "3": "C"},
	},
]
